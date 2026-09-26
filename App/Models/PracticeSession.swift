import AVFoundation
import Observation
import SwiftUI

@MainActor
@Observable
final class PracticeSession {
  let problems: ProblemSetModel
  let struggle = StruggleTracker()
  let engine = InterventionEngine()
  let hints = HintLadder()
  let bunny: BunnyState
  let recording: Bool
  var voiceEnabled: Bool {
    didSet {
      if !recording { UserDefaults.standard.set(voiceEnabled, forKey: "BurrowVoiceEnabled") }
      if !voiceEnabled { speech.stopSpeaking(at: .immediate) }
    }
  }
  var elapsed = 0.0
  private let brain: any BunnyBrain = ScriptedBrain()
  private let speech = AVSpeechSynthesizer()
  private var lastLevel = InterventionEngine.Level.quiet
  private var hintReadyAt: Double?
  private var pendingHint: PracticeProblem.Hint?
  private var advanceOnUnfold = false
  private var speakingUntil = 0.0
  private var wanderAt = 18.0
  private var settleAt: Double?
  private var attemptsByProblem: [String: Int] = [:]

  init(recording: Bool) {
    self.recording = recording
    problems = ProblemSetModel(problems: BundledResource.decode("Problems"))
    bunny = BunnyState(manifest: PixelArtStore.shared.rabbit, recording: recording)
    voiceEnabled = recording ? false : UserDefaults.standard.object(forKey: "BurrowVoiceEnabled") as? Bool ?? false
  }

  func tick(_ dt: Double, reducedMotion: Bool) {
    elapsed += dt
    bunny.player.reducedMotion = reducedMotion
    bunny.player.speaking = elapsed < speakingUntil && voiceEnabled
    bunny.player.tick(dt)
    if let ready = hintReadyAt, elapsed >= ready, let hint = pendingHint {
      hintReadyAt = nil
      pendingHint = nil
      showHint(hint)
    }
    if problems.feedback != .correct && bunny.replies != .hint {
      engine.evaluate(struggle.snapshot(at: elapsed), at: elapsed)
      if engine.level != lastLevel {
        lastLevel = engine.level
        applyLevel(engine.level)
      }
    }
    if struggle.snapshot(at: elapsed).idleSeconds > 150 && bunny.replies == .none && bunny.phase == .resting {
      bunny.player.setState("sleepy")
    }
    if let settle = settleAt, elapsed >= settle {
      settleAt = nil
      bunny.player.forceState("settle")
    }
    if elapsed > wanderAt && bunny.replies == .none && bunny.phase == .resting && !reducedMotion {
      wanderAt = elapsed + 18 + bunny.player.random() * 12
      bunny.player.forceState("hop")
      withAnimation(.smooth(duration: 0.4)) { bunny.wanderOffset = bunny.wanderOffset == 0 ? -28 : 0 }
      settleAt = elapsed + 0.42
    }
  }

  func enter(_ key: String) {
    problems.enter(key)
    struggle.activity(at: elapsed)
    if bunny.replies == .none { bunny.player.setState("idle") }
  }

  func check() {
    let alreadyCorrect = problems.feedback == .correct
    switch problems.check() {
    case .incorrect:
      struggle.wrong(at: elapsed)
      engine.evaluate(struggle.snapshot(at: elapsed), at: elapsed)
    case .empty:
      struggle.empty(at: elapsed)
      engine.evaluate(struggle.snapshot(at: elapsed), at: elapsed)
    case .correct:
      guard !alreadyCorrect else { return }
      advanceOnUnfold = true
      engine.resolve(at: elapsed, declined: false)
      bunny.guide = nil
      bunny.replies = .celebration
      bunny.message = brain.celebration()
      bunny.subtitle = "YOU FOUND YOUR WAY"
      bunny.player.forceState("celebrate")
      say(bunny.message)
    case .none: break
    }
  }

  func requestHint(similar: Bool = false, immediately: Bool = false) {
    struggle.activity(at: elapsed)
    engine.resolve(at: elapsed, declined: false)
    let hint = brain.hint(for: problems.current, ladder: hints, similar: similar)
    if immediately { showHint(hint) }
    else {
      bunny.player.setState("thinking")
      pendingHint = hint
      hintReadyAt = elapsed + 1.1
      bunny.subtitle = "LET’S THINK TOGETHER"
    }
  }

  func decline() {
    engine.resolve(at: elapsed, declined: true)
    hintReadyAt = nil
    pendingHint = nil
    bunny.replies = .none
    bunny.guide = nil
    bunny.message = "Okay—I’m here if you need me."
    bunny.subtitle = "TAKE YOUR TIME"
    bunny.player.setState("idle")
    lastLevel = .quiet
  }

  func configurePose(_ pose: BurrowPose, anchor: CGPoint, scale: Int) {
    let changed = pose != bunny.pose
    bunny.configure(pose: pose, anchor: anchor, scale: scale) { [weak self] in
      self?.arrived(at: pose)
    }
    if changed && bunny.phase == .resting { arrived(at: pose) }
    if bunny.replies == .offer { bunny.message = brain.offer(for: pose) }
  }

  func selectProblem(_ index: Int) {
    attemptsByProblem[problems.current.id] = struggle.incorrectAttempts
    problems.select(index)
    struggle.reset(at: elapsed, incorrectAttempts: attemptsByProblem[problems.current.id] ?? 0)
    engine.reset()
    lastLevel = .quiet
    hints.clearCurrent()
    pendingHint = nil
    hintReadyAt = nil
    bunny.replies = .none
    bunny.guide = nil
    bunny.message = "A fresh page. Same small steps."
    bunny.subtitle = "YOUR STUDY COMPANION"
    bunny.player.setState("idle")
    advanceOnUnfold = false
  }

  func nextProblem() {
    let remaining = problems.problems.indices.filter { !problems.solved.contains(problems.problems[$0].id) }
    if let next = remaining.first(where: { $0 > problems.selectedIndex }) ?? remaining.first {
      selectProblem(next)
    } else {
      bunny.message = "Six problems, one step at a time. Look how far you’ve come."
      bunny.subtitle = "PRACTICE COMPLETE"
      advanceOnUnfold = false
    }
  }

  private func arrived(at pose: BurrowPose) {
    if pose == .flat && advanceOnUnfold { nextProblem() }
    else if (pose == .tabletop || pose == .book) && bunny.replies == .offer {
      requestHint(immediately: true)
    }
  }

  private func showHint(_ hint: PracticeProblem.Hint) {
    bunny.message = hint.text
    bunny.subtitle = hint.rung.title.uppercased()
    bunny.guide = hint.target
    bunny.replies = .hint
    bunny.player.forceState("aha")
    bunny.player.setState("listening")
    say(hint.text)
  }

  private func applyLevel(_ level: InterventionEngine.Level) {
    switch level {
    case .quiet: break
    case .look: bunny.player.forceState("idle_watch")
    case .question:
      bunny.player.forceState("confused")
      bunny.subtitle = "A LITTLE STUCK?"
    case .offer, .spoken:
      bunny.message = brain.offer(for: bunny.pose)
      bunny.subtitle = "WE CAN WORK ON IT TOGETHER"
      bunny.replies = .offer
      bunny.player.forceState("listening")
      if level == .spoken { say(bunny.message) }
    }
  }

  private func say(_ text: String) {
    guard voiceEnabled else { return }
    speech.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
    speech.speak(utterance)
    speakingUntil = elapsed + Double(text.count) / 14
  }
}
