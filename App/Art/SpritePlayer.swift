import Foundation
import Observation

/// Native port of Burrow's manifest-driven player: transition chains, one-shots,
/// reverse sequences, weighted idle variants, and independent face overlays.
@MainActor
@Observable
final class SpritePlayer {
  let manifest: CharacterManifest
  private(set) var current = "idle"
  private(set) var frame = 0
  private(set) var blinkFrame = -1
  private(set) var mouthFrame = 0
  private(set) var inSequence = false
  var speaking = false
  var reducedMotion = false
  var hidden = false
  private var requested = "idle"
  private var pending: String?
  private var chain: [String] = []
  private var steps: [CharacterManifest.Step] = []
  private var sequenceCompletion: (() -> Void)?
  private var reverse = false
  private var looping = true
  private var ended = false
  private var accumulator = 0.0
  private var elapsed = 0.0
  private var blinkAccumulator = 0.0
  private var blinkTimer = 3.0
  private var variantTimer = 5.0
  private var sequenceSpeed = 1.0
  private var waitingStep = false
  private var randomState: UInt64

  init(manifest: CharacterManifest, seed: UInt64) {
    self.manifest = manifest
    randomState = seed
    scheduleVariant()
  }

  var definition: CharacterManifest.StateDefinition {
    manifest.states[current]!
  }

  var headDY: Int { definition.headDy?.element(at: frame) ?? 0 }
  var showsBlink: Bool { definition.overlays?.contains("blink") == true && blinkFrame >= 0 }
  var showsMouth: Bool { definition.overlays?.contains("mouth") == true && speaking }

  func random() -> Double {
    randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
    return Double(randomState >> 11) / Double(UInt64.max >> 11)
  }

  func setState(_ name: String) {
    let next = manifest.states[name] == nil ? "idle" : name
    if inSequence { requested = next; return }
    if !chain.isEmpty || (current != requested) || (!looping && !ended) {
      pending = next
      return
    }
    guard next != requested else { return }
    chain = []
    if let exit = manifest.states[requested]?.exit { chain.append(exit) }
    if let enter = manifest.states[next]?.enter { chain.append(enter) }
    requested = next
    advance()
  }

  func forceState(_ name: String) {
    guard !inSequence else { requested = name; return }
    chain = []
    pending = nil
    requested = manifest.states[name] == nil ? "idle" : name
    if let enter = manifest.states[requested]?.enter { chain = [enter] }
    advance()
  }

  func playSequence(_ sequence: [CharacterManifest.Step], completion: @escaping () -> Void) {
    inSequence = true
    hidden = false
    chain = []
    pending = nil
    steps = sequence
    sequenceCompletion = completion
    // The original round trip takes ~2.4 s. A common speed multiplier preserves
    // the manifest's relative timing while fitting the requested <1.5 s handoff.
    sequenceSpeed = 2.25
    advanceSequence()
  }

  func cancelSequence() {
    inSequence = false
    hidden = false
    steps = []
    sequenceCompletion = nil
    sequenceSpeed = 1
    waitingStep = false
    forceState("idle")
  }

  func tick(_ dt: Double) {
    guard !hidden else { return }
    elapsed += dt
    if waitingStep && elapsed >= 0.13 {
      advanceSequence()
    } else if !ended && (!reducedMotion || inSequence || !looping) {
      accumulator += dt * sequenceSpeed
      let interval = 1 / max(definition.fps, 1)
      while accumulator >= interval && !ended {
        accumulator -= interval
        let next = frame + (reverse ? -1 : 1)
        if next < 0 || next >= definition.frames {
          if looping {
            frame = reverse ? definition.frames - 1 : 0
          } else {
            finishState()
            break
          }
        } else { frame = next }
      }
    }
    tickOverlays(dt)
    if !inSequence && current == "idle" && requested == "idle" && !reducedMotion {
      variantTimer -= dt
      if variantTimer <= 0 {
        let variants = definition.variants ?? []
        var choice = random() * variants.reduce(0) { $0 + $1.weight }
        for variant in variants {
          choice -= variant.weight
          if choice < 0 {
            show(variant.state)
            break
          }
        }
        scheduleVariant()
      }
    }
  }

  private func advance() {
    if !chain.isEmpty { show(chain.removeFirst()); return }
    show(requested)
    if let pending {
      self.pending = nil
      if pending != requested { setState(pending) }
    }
  }

  private func show(_ name: String, reverse: Bool = false, loop: Bool? = nil) {
    current = manifest.states[name] == nil ? "idle" : name
    self.reverse = reverse
    looping = loop ?? definition.loop
    frame = reverse ? max(0, definition.frames - 1) : 0
    accumulator = 0
    elapsed = 0
    ended = false
    if current == "idle" { scheduleVariant() }
  }

  private func finishState() {
    ended = true
    if inSequence { advanceSequence(); return }
    if !chain.isEmpty || current != requested { advance(); return }
    if definition.hold == true {
      if let pending {
        self.pending = nil
        setState(pending)
      }
      return
    }
    let next = pending ?? "idle"
    pending = nil
    requested = next
    if let enter = manifest.states[next]?.enter { chain = [enter] }
    advance()
  }

  private func advanceSequence() {
    waitingStep = false
    if !steps.isEmpty {
      let step = steps.removeFirst()
      if steps.isEmpty && manifest.states[step.state]?.loop == true {
        finishSequence()
      } else {
        waitingStep = step.loop == true
        show(step.state, reverse: step.reverse == true, loop: waitingStep)
      }
    } else { finishSequence() }
  }

  private func finishSequence() {
    inSequence = false
    sequenceSpeed = 1
    show(requested)
    let completion = sequenceCompletion
    sequenceCompletion = nil
    completion?()
  }

  private func scheduleVariant() {
    let gap = manifest.idleVariantGap
    variantTimer = gap[0] + random() * (gap[1] - gap[0])
  }

  private func tickOverlays(_ dt: Double) {
    mouthFrame = Int(elapsed * 10) % 3
    guard !reducedMotion else { blinkFrame = -1; return }
    if blinkFrame < 0 {
      blinkTimer -= dt
      if blinkTimer <= 0 {
        blinkTimer = 2 + random() * 3
        if definition.overlays?.contains("blink") == true {
          blinkFrame = 0
          blinkAccumulator = 0
        }
      }
    } else {
      blinkAccumulator += dt
      let blink = manifest.states["overlay_blink"]!
      if blinkAccumulator >= 1 / max(blink.fps, 1) {
        blinkAccumulator = 0
        blinkFrame += 1
        if blinkFrame >= blink.frames { blinkFrame = -1 }
      }
    }
  }
}

private extension Array {
  func element(at index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
