import AVFoundation
import SwiftUI

/// Where Bunny currently stands.
enum Spot { case corner, stage, compact }

enum Chip: String, Identifiable {
    case yesHint = "Yes, a hint"
    case another = "Another hint"
    case similar = "Show me a similar one"
    case good = "I'm good"
    var id: String { rawValue }
}

struct Bubble: Equatable {
    var id = UUID()
    var text: String
    var chips: [Chip] = []
    var autoHide: Double? = nil
}

/// The brain behind Bunny. Only a scripted brain ships (like Burrow's DEMO_MODE);
/// an LLM-backed one can conform later.
protocol BunnyBrain {
    func offerLine(pose: Pose, splitView: Bool, emptyChecks: Bool) -> String
    func hint(for problem: Problem, rung: Int) -> Problem.Hint
    func praise(afterStruggle: Bool) -> String
}

struct ScriptedBrain: BunnyBrain {
    func offerLine(pose: Pose, splitView: Bool, emptyChecks: Bool) -> String {
        let lead = emptyChecks
            ? "That Check button needs an answer first. Want a hint to get started?"
            : "Looks like this one's being stubborn. Want a hint?"
        switch pose {
        case .flat: return lead + "\nFold me up and let's work on it together."
        case .closed where !splitView: return lead + "\nOpen me up and we'll work on it together."
        default: return lead
        }
    }

    /// nudge → hint → explanation → analogous example → more direct. Never the final answer.
    func hint(for problem: Problem, rung: Int) -> Problem.Hint {
        problem.hints[min(max(rung, 0), problem.hints.count - 1)]
    }

    func praise(afterStruggle: Bool) -> String {
        afterStruggle ? "Nice—you got it! That one was stubborn and you still cracked it." : "Nice—you got it!"
    }
}

/// Struggle signals + intensity levels + hint ladder + Bunny's placement across poses.
@Observable
final class Coach {
    let player = SpritePlayer()
    let problems: ProblemSetModel
    @ObservationIgnored let brain: BunnyBrain = ScriptedBrain()

    // Bunny
    private(set) var spot: Spot = .corner
    private(set) var bubble: Bubble?
    private(set) var revealed = 0
    private(set) var focus: String?
    private(set) var jumping = false
    private(set) var level = 0

    // Context from the view
    private(set) var pose: Pose = .flat
    var splitView = false
    var speechEnabled = AppConfig.speechDefault

    // Struggle state
    @ObservationIgnored private var hintRung = -1
    @ObservationIgnored private var offerPending = false
    @ObservationIgnored private var emptyChecks = 0
    @ObservationIgnored private var hadStruggle = false
    @ObservationIgnored private var queuedAdvance = false
    @ObservationIgnored private var cooldownUntil = Date.distantPast
    @ObservationIgnored private var declineUntil = Date.distantPast
    @ObservationIgnored private var lastInput = Date.now
    @ObservationIgnored private var didGreet = false

    // Jump
    private enum Jump { case idle, sending, sent, receiving }
    @ObservationIgnored private var jump: Jump = .idle
    @ObservationIgnored private var jumpDest: Spot?

    @ObservationIgnored private var escalation: Task<Void, Never>?
    @ObservationIgnored private var typing: Task<Void, Never>?
    @ObservationIgnored private var hintTask: Task<Void, Never>?
    @ObservationIgnored private var idleTimer: Task<Void, Never>?
    @ObservationIgnored private let synth = AVSpeechSynthesizer()

    init(problems: ProblemSetModel) {
        self.problems = problems
        startIdleWatch()
    }

    // MARK: Lifecycle

    func greet() {
        guard !didGreet else { return }
        didGreet = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            player.play("wave")
            say("Hi! I'm Bunny. I'll hang out here while you work.", autoHide: 3.2)
        }
    }

    func reset() {
        escalation?.cancel()
        hintTask?.cancel()
        problems.reset()
        hintRung = -1
        offerPending = false
        emptyChecks = 0
        hadStruggle = false
        queuedAdvance = false
        cooldownUntil = .distantPast
        declineUntil = .distantPast
        focus = nil
        level = 0
        clearBubble()
        player.setState("idle")
        didGreet = false
        greet()
    }

    // MARK: Student input

    func noteInput() {
        lastInput = .now
        if player.picture.state.contains("sleepy") { player.setState("idle") }
    }

    func didCheck(_ result: CheckResult) {
        noteInput()
        switch result {
        case .empty:
            emptyChecks += 1
            if emptyChecks >= 3, canOffer { escalate() }
        case .wrong:
            emptyChecks = 0
            if hintRung >= 0 {
                player.play("idle_watch")
                say("Not quite. Look where my paw is and try that step again.", chips: ladderChips)
            } else if problems.wrongCount >= 2, canOffer {
                hadStruggle = true
                escalate()
            } else {
                player.play("idle_watch")
            }
        case .correct:
            celebrate()
        }
    }

    func tap(_ chip: Chip) {
        noteInput()
        switch chip {
        case .yesHint: deliverHint(0)
        case .another: deliverHint(hintRung + 1)
        case .similar: deliverHint(max(3, hintRung + 1))
        case .good: decline()
        }
    }

    func selectProblem(_ i: Int) {
        guard i != problems.index else { return }
        problems.select(i)
        resetProblemState()
        clearBubble()
        player.setState("idle")
    }

    // MARK: Struggle → levels (look → "?" → bubble → speech)

    private var canOffer: Bool {
        Date.now >= cooldownUntil && Date.now >= declineUntil && !offerPending && hintRung < 0 && jump == .idle
    }

    private func escalate() {
        escalation?.cancel()
        clearBubble()
        escalation = Task {
            level = 1
            player.play("idle_watch") // glance at the problem
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            level = 2
            player.setState("confused") // "?"
            try? await Task.sleep(for: .milliseconds(1300))
            guard !Task.isCancelled else { return }
            offer()
            try? await Task.sleep(for: .seconds(9))
            guard !Task.isCancelled, offerPending else { return }
            level = 4 // spoken offer
            if speechEnabled, let b = bubble { speak(b.text) }
        }
    }

    private func offer() {
        level = 3
        offerPending = true
        player.setState("listening")
        say(brain.offerLine(pose: pose, splitView: splitView, emptyChecks: emptyChecks >= 3),
            chips: [.yesHint, .good], speakIt: false)
    }

    private var ladderChips: [Chip] { hintRung >= 4 ? [.good] : [.another, .similar, .good] }

    private func deliverHint(_ rung: Int) {
        escalation?.cancel()
        offerPending = false
        level = 0
        hadStruggle = true
        cooldownUntil = .now.addingTimeInterval(45)
        hintRung = min(rung, problems.problem.hints.count - 1)
        let hint = brain.hint(for: problems.problem, rung: hintRung)
        clearBubble()
        focus = nil
        player.setState("thinking")
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            player.setState("listening") // thinking exits through aha
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            focus = hint.focus
            say(hint.text, chips: ladderChips)
        }
    }

    private func decline() {
        escalation?.cancel()
        hintTask?.cancel()
        offerPending = false
        level = 0
        declineUntil = .now.addingTimeInterval(180)
        focus = nil
        player.setState("idle")
        say("Okay! I'll be right here if you need me.", autoHide: 2.4)
    }

    private func celebrate() {
        escalation?.cancel()
        hintTask?.cancel()
        let struggled = hadStruggle || hintRung >= 0
        offerPending = false
        focus = nil
        level = 0
        player.play("celebrate")
        say(brain.praise(afterStruggle: struggled), autoHide: pose == .flat || pose == .closed ? 2.2 : nil)
        queuedAdvance = true
        Task {
            try? await Task.sleep(for: .milliseconds(2300))
            guard queuedAdvance else { return }
            if spot == .stage {
                say("Unfold me when you're ready for the next one.")
            } else {
                advanceProblem()
            }
        }
    }

    private func advanceProblem() {
        queuedAdvance = false
        problems.advance()
        resetProblemState()
        say("Next one! You've got this.", autoHide: 2.0)
    }

    private func resetProblemState() {
        escalation?.cancel()
        hintTask?.cancel()
        hintRung = -1
        offerPending = false
        emptyChecks = 0
        hadStruggle = false
        focus = nil
        level = 0
        queuedAdvance = false
    }

    private func startIdleWatch() {
        idleTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !AppConfig.isRecording, jump == .idle else { continue }
                let quiet = Date.now.timeIntervalSince(lastInput)
                if quiet > 45, canOffer, !problems.solved.contains(problems.index), bubble == nil, level == 0 {
                    hadStruggle = true
                    escalate()
                } else if quiet > 120, bubble == nil, player.picture.state == "idle" {
                    player.setState("sleepy")
                }
            }
        }
    }

    // MARK: Bubble

    private func say(_ text: String, chips: [Chip] = [], autoHide: Double? = nil, speakIt: Bool = true) {
        let b = Bubble(text: text, chips: chips, autoHide: autoHide)
        bubble = b
        revealed = 0
        typing?.cancel()
        if speakIt, speechEnabled { speak(text) }
        typing = Task {
            player.setSpeaking(true)
            let count = text.count
            while revealed < count, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(18))
                revealed = min(count, revealed + 2)
            }
            player.setSpeaking(false)
            guard let autoHide, !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(autoHide))
            if bubble?.id == b.id { withAnimation(.easeOut(duration: 0.2)) { bubble = nil } }
        }
    }

    private func clearBubble() {
        typing?.cancel()
        player.setSpeaking(false)
        bubble = nil
        synth.stopSpeaking(at: .word)
    }

    private func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text.replacingOccurrences(of: "\n", with: " "))
        u.rate = 0.5
        u.pitchMultiplier = 1.25
        synth.speak(u)
    }

    // MARK: Poses & the jump

    func spot(for pose: Pose) -> Spot {
        switch pose {
        case .flat: .corner
        case .tabletop, .book: .stage
        case .closed: .compact
        }
    }

    func poseChanged(from old: Pose?, to new: Pose) {
        pose = new
        let dest = spot(for: new)
        guard old != nil else {
            spot = dest
            return
        }
        switch jump {
        case .idle:
            if dest == spot {
                player.play("land")
            } else {
                jumpDest = dest
                startSend()
            }
        case .sending:
            jumpDest = dest
        case .sent:
            receive(at: dest)
        case .receiving:
            spot = dest
        }
    }

    /// Early cue from the hinge (fully open → partially open): start diving before the
    /// reserved regions report the new pose so the animation feels instant.
    func hingeCue() {
        guard jump == .idle, spot == .corner else { return }
        jumpDest = nil
        startSend()
    }

    private func startSend() {
        jump = .sending
        jumping = true
        synth.stopSpeaking(at: .word)
        player.speed = 1.7
        player.runSequence(player.manifest.jumpSequence.sending, hideWhenDone: true) { [weak self] in
            self?.sendFinished()
        }
    }

    private func sendFinished() {
        if let d = jumpDest {
            receive(at: d)
            return
        }
        jump = .sent
        Task {
            // The fold never settled into a new pose: come back up where we are.
            try? await Task.sleep(for: .milliseconds(1200))
            if jump == .sent { receive(at: spot(for: pose)) }
        }
    }

    private func receive(at dest: Spot) {
        jump = .receiving
        jumpDest = nil
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { spot = dest }
        player.runSequence(player.manifest.jumpSequence.receiving) { [weak self] in
            self?.arrived()
        }
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            player.releaseHold()
        }
    }

    private func arrived() {
        jump = .idle
        player.speed = 1
        jumping = false
        if queuedAdvance, spot != .stage {
            advanceProblem()
        } else if offerPending, spot == .stage {
            deliverHint(0) // folding while the offer is up means "yes"
        } else if offerPending {
            offer() // refresh the fold/open suggestion for the new pose
        } else if let b = bubble, hintRung >= 0 {
            bubble = b // conversation persists across poses
        }
    }
}
