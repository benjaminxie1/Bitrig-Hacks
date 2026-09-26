import SwiftUI

/// Swift port of extension/src/components/pet/player.ts: a manifest-driven state machine.
/// Transitions (`enter`/`exit`) finish before the target shows, one-shots fall back to idle
/// unless they `hold`, idle picks weighted variants, and `jump_sequence` steps run in order.
@Observable
final class SpritePlayer {
    struct Picture: Equatable {
        var state = "idle"
        var frame = 0
        var headDy = 0
        var blink = -1
        var mouth = -1
        var hidden = false
    }

    private(set) var picture = Picture()
    /// Playback speed multiplier (the jump runs faster so the pose change feels snappy).
    @ObservationIgnored var speed: Double = 1

    @ObservationIgnored let manifest: CharacterManifest
    @ObservationIgnored private var shown: Shown
    @ObservationIgnored private var target = "idle"
    @ObservationIgnored private var chain: [String] = []
    @ObservationIgnored private var pending: String?
    @ObservationIgnored private var inSequence = false
    @ObservationIgnored private var hidden = false

    @ObservationIgnored private var seqSteps: [JumpStep] = []
    @ObservationIgnored private var seqIndex = 0
    @ObservationIgnored private var seqHolding = false
    @ObservationIgnored private var seqReleased = false
    @ObservationIgnored private var seqHideWhenDone = false
    @ObservationIgnored private var seqDone: (() -> Void)?

    @ObservationIgnored private var speaking = false
    @ObservationIgnored private var mouthFrame = 0
    @ObservationIgnored private var mouthAcc = 0.0
    @ObservationIgnored private var blinkFrame = -1
    @ObservationIgnored private var blinkAcc = 0.0
    @ObservationIgnored private var blinkTimer = 3.0
    @ObservationIgnored private var variantTimer = -1.0
    @ObservationIgnored private var variantsEnabled = true
    @ObservationIgnored private var loop: Task<Void, Never>?

    private struct Shown {
        var name: String
        var def: StateDef
        var frame: Int
        var acc: Double
        var reverse: Bool
        var loop: Bool
        var ended: Bool
    }

    init(manifest: CharacterManifest = ArtStore.shared.rabbit) {
        self.manifest = manifest
        let idle = manifest.states["idle"]!
        shown = Shown(name: "idle", def: idle, frame: 0, acc: 0, reverse: false, loop: true, ended: false)
        blinkTimer = gap(2, 5)
        scheduleVariant()
        start()
    }

    private func start() {
        loop = Task { [weak self] in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                let now = ContinuousClock.now
                let dt = Double((now - last).components.attoseconds) / 1e18 + Double((now - last).components.seconds)
                last = now
                self?.tick(min(dt, 0.1))
            }
        }
    }

    // MARK: Requests

    func has(_ name: String) -> Bool { manifest.states[name] != nil }

    /// Ask for a state. Transitions and one-shots finish first; the latest request wins.
    func setState(_ name: String) {
        let next = has(name) ? name : "idle"
        if inSequence {
            target = next
            pending = nil
            return
        }
        if busy() {
            pending = next
            return
        }
        if next == target { return }
        transitionTo(next)
    }

    /// Replay a one-shot even if it is already the target (celebrate twice, wave on demand).
    func play(_ name: String) {
        guard !inSequence, let def = manifest.states[name] else { return }
        chain = []
        pending = nil
        target = def.loop || def.hold == true ? name : "idle"
        show(name, reverse: false, loop: def.loop)
        if !def.loop && def.hold != true { target = "idle" }
    }

    /// Runs manifest steps in order. A step with `loop: true` plays until `releaseHold()`.
    func runSequence(_ steps: [JumpStep], hideWhenDone: Bool = false, onDone: (() -> Void)? = nil) {
        inSequence = true
        chain = []
        pending = nil
        hidden = false
        seqSteps = steps
        seqIndex = -1
        seqHolding = false
        seqReleased = false
        seqHideWhenDone = hideWhenDone
        seqDone = onDone
        nextSequenceStep()
        publish()
    }

    func releaseHold() {
        if seqHolding {
            seqHolding = false
            nextSequenceStep()
        } else {
            seqReleased = true
        }
    }

    func setHidden(_ value: Bool) {
        hidden = value
        publish()
    }

    func setSpeaking(_ value: Bool) {
        speaking = value
        if !value { mouthFrame = 0 }
    }

    func setVariantsEnabled(_ value: Bool) {
        variantsEnabled = value
    }

    // MARK: Time

    private func tick(_ rawDt: Double) {
        let dt = rawDt * speed
        if !hidden && !shown.ended {
            let step = 1 / max(shown.def.fps, 1)
            shown.acc += dt
            while shown.acc >= step {
                shown.acc -= step
                var nf = shown.frame + (shown.reverse ? -1 : 1)
                if nf < 0 || nf >= shown.def.frames {
                    if shown.loop {
                        nf = (nf + shown.def.frames) % shown.def.frames
                    } else {
                        onEnded()
                        break
                    }
                }
                shown.frame = nf
            }
        }
        tickBlink(rawDt)
        tickMouth(rawDt)
        tickVariant(rawDt)
        publish()
    }

    private func publish() {
        let allows = { (o: String) in self.shown.def.overlays?.contains(o) == true }
        var p = Picture()
        p.state = shown.name
        p.frame = shown.frame
        p.headDy = shown.def.headDy?[safe: shown.frame] ?? 0
        p.blink = blinkFrame >= 0 && allows("blink") ? blinkFrame : -1
        p.mouth = speaking && allows("mouth") ? mouthFrame : -1
        p.hidden = hidden
        if p != picture { picture = p }
    }

    // MARK: Internals

    private func busy() -> Bool {
        if !chain.isEmpty { return true }
        if shown.name != target { return true }
        if shown.loop { return false }
        return !shown.ended
    }

    private func transitionTo(_ next: String) {
        let from = manifest.states[target]
        let to = manifest.states[next]
        chain = []
        if shown.name == target, let exit = from?.exit, has(exit) { chain.append(exit) }
        if let enter = to?.enter, has(enter) { chain.append(enter) }
        target = next
        advance()
    }

    private func advance() {
        if !chain.isEmpty {
            show(chain.removeFirst(), reverse: false, loop: false)
            return
        }
        let def = manifest.states[target]!
        show(target, reverse: false, loop: def.loop)
        flushPending()
    }

    private func resume() {
        let def = manifest.states[target]!
        chain = def.enter.flatMap { has($0) ? [$0] : nil } ?? []
        advance()
    }

    private func flushPending() {
        let p = pending
        pending = nil
        if let p, p != target { setState(p) }
    }

    private func nextSequenceStep() {
        seqIndex += 1
        guard seqIndex < seqSteps.count else { return finishSequence() }
        let step = seqSteps[seqIndex]
        let name = has(step.state) ? step.state : "idle"
        let def = manifest.states[name]!
        if step.loop == true {
            show(name, reverse: step.reverse == true, loop: true)
            if seqReleased {
                // Show at least one beat of the waiting pose so the ears are seen.
                seqHolding = true
                seqReleased = false
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(260))
                    self?.releaseHold()
                }
            } else {
                seqHolding = true
            }
            return
        }
        if def.loop && seqIndex == seqSteps.count - 1 { return finishSequence() }
        show(name, reverse: step.reverse == true, loop: false)
    }

    private func finishSequence() {
        inSequence = false
        if seqHideWhenDone { hidden = true }
        resume()
        let done = seqDone
        seqDone = nil
        done?()
    }

    private func onEnded() {
        shown.ended = true
        if inSequence {
            nextSequenceStep()
            return
        }
        if !chain.isEmpty { return advance() }
        if shown.name != target { return advance() }
        if shown.def.hold == true { return flushPending() }
        target = "idle"
        show("idle", reverse: false, loop: true)
        flushPending()
    }

    private func show(_ name: String, reverse: Bool, loop: Bool) {
        let def = manifest.states[name]!
        shown = Shown(name: name, def: def, frame: reverse ? max(0, def.frames - 1) : 0, acc: 0, reverse: reverse, loop: loop, ended: false)
        if name == "idle" { scheduleVariant() }
    }

    private func gap(_ lo: Double, _ hi: Double) -> Double { lo + RNG.next() * max(0, hi - lo) }

    private func tickBlink(_ dt: Double) {
        guard let def = manifest.states["overlay_blink"] else { return }
        if blinkFrame < 0 {
            blinkTimer -= dt
            if blinkTimer > 0 { return }
            blinkTimer = gap(2, 5)
            blinkFrame = 0
            blinkAcc = 0
            return
        }
        blinkAcc += dt
        let step = 1 / max(def.fps, 1)
        while blinkAcc >= step {
            blinkAcc -= step
            blinkFrame += 1
            if blinkFrame >= def.frames {
                blinkFrame = -1
                break
            }
        }
    }

    private func tickMouth(_ dt: Double) {
        guard speaking else { return }
        mouthAcc += dt
        if mouthAcc >= 0.11 {
            mouthAcc = 0
            let pattern = [1, 2, 1, 0, 2, 1, 0]
            mouthFrame = pattern[Int(RNG.next() * Double(pattern.count)) % pattern.count]
        }
    }

    private func scheduleVariant() {
        if let g = manifest.idleVariantGap, g.count == 2 { variantTimer = gap(g[0], g[1]) } else { variantTimer = -1 }
    }

    private func tickVariant(_ dt: Double) {
        guard variantsEnabled, !inSequence, variantTimer >= 0, shown.name == "idle", target == "idle", chain.isEmpty else { return }
        let variants = (manifest.states["idle"]?.variants ?? []).filter { has($0.state) && $0.weight > 0 }
        guard !variants.isEmpty else { return }
        variantTimer -= dt
        if variantTimer > 0 { return }
        let total = variants.reduce(0) { $0 + $1.weight }
        var pick = RNG.next() * total
        var chosen = variants.last!.state
        for v in variants {
            pick -= v.weight
            if pick < 0 { chosen = v.state; break }
        }
        show(chosen, reverse: false, loop: false)
        variantTimer = -1
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
