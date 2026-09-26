import Foundation
import SwiftUI
import Testing
@testable import BurrowCore

struct PoseTests {
  @Test func reservedRegionHasPriorityOverSizeClass() {
    let horizontal = CGRect(x: 0, y: 290, width: 900, height: 24)
    let vertical = CGRect(x: 320, y: 0, width: 24, height: 900)
    #expect(PoseDeriver.derive(activeDivision: horizontal, horizontalSizeClass: .regular) == .tabletop)
    #expect(PoseDeriver.derive(activeDivision: horizontal, horizontalSizeClass: .compact) == .tabletop)
    #expect(PoseDeriver.derive(activeDivision: vertical, horizontalSizeClass: .regular) == .book)
    #expect(PoseDeriver.derive(activeDivision: nil, horizontalSizeClass: .regular) == .flat)
    #expect(PoseDeriver.derive(activeDivision: nil, horizontalSizeClass: .compact) == .closed)
    #expect(PoseDeriver.derive(activeDivision: nil, horizontalSizeClass: nil) == .closed)
  }

  @Test func regionsArrivingAfterFirstPassChangeLayout() {
    let live = LivePoseProvider()
    let size = CGSize(width: 900, height: 600)
    let first = live.snapshot(activeDivision: nil, occlusions: [], size: size, horizontalSizeClass: .regular)
    let fold = CGRect(x: 0, y: 271, width: 900, height: 42)
    let second = live.snapshot(activeDivision: fold, occlusions: [], size: size, horizontalSizeClass: .regular)
    #expect(first.pose == .flat)
    #expect(second.pose == .tabletop)
    let layout = BurrowLayout(snapshot: second)
    #expect(layout.stage.maxY == fold.minY)
    #expect(layout.workspace.minY == fold.maxY)
    #expect(layout.stage.intersection(fold).height == 0)
    #expect(layout.workspace.maxY == 600)
  }

  @Test func asymmetricOcclusionIsKeptClear() {
    let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
    let rightBar = CGRect(x: 758, y: 0, width: 42, height: 600)
    #expect(BurrowLayout.unoccluded(frame, avoiding: [rightBar]).maxX == 758)
    let leftBar = CGRect(x: 0, y: 0, width: 61, height: 600)
    #expect(BurrowLayout.unoccluded(frame, avoiding: [leftBar]).minX == 61)
    let camera = CGRect(x: 300, y: 0, width: 24, height: 24)
    #expect(BurrowLayout.unoccluded(frame, avoiding: [camera]).minY == 24)
  }
}

@MainActor
struct CoachingTests {
  private func problems() throws -> [PracticeProblem] {
    let url = try #require(Bundle.module.url(forResource: "Problems", withExtension: "json"))
    return try JSONDecoder().decode([PracticeProblem].self, from: Data(contentsOf: url))
  }

  @Test func wrongLoopsBuildToOfferAndEmptyChecksToSpeech() {
    let tracker = StruggleTracker()
    tracker.wrong(at: 1)
    #expect(InterventionEngine.level(for: tracker.snapshot(at: 1), now: 1) == .look)
    tracker.wrong(at: 2)
    #expect(InterventionEngine.level(for: tracker.snapshot(at: 2), now: 2) == .offer)
    let engine = InterventionEngine()
    engine.evaluate(tracker.snapshot(at: 2), at: 2)
    #expect(engine.level == .look)
    engine.evaluate(tracker.snapshot(at: 2.5), at: 2.5)
    #expect(engine.level == .question)
    engine.evaluate(tracker.snapshot(at: 3.1), at: 3.1)
    #expect(engine.level == .offer)
    tracker.reset(at: 0)
    for time in [1.0, 2.0, 3.0] { tracker.empty(at: time) }
    engine.reset()
    for time in [3.0, 3.5, 4.1, 4.7] { engine.evaluate(tracker.snapshot(at: time), at: time) }
    #expect(engine.level == .spoken)
    #expect(tracker.snapshot(at: 24).emptyChecks == 0)
  }

  @Test func declineAndCooldownBackOff() {
    let signals = StruggleTracker.Signals(incorrectAttempts: 3, emptyChecks: 3, idleSeconds: 100)
    let engine = InterventionEngine()
    engine.resolve(at: 10, declined: true)
    engine.evaluate(signals, at: 189)
    #expect(engine.level == .quiet)
    #expect(InterventionEngine.level(for: signals, now: 190, declinedUntil: engine.declinedUntil) == .spoken)
    #expect(InterventionEngine.level(for: signals, now: 30, cooldownUntil: 45) == .look)
    #expect(InterventionEngine.level(for: .init(incorrectAttempts: 0, emptyChecks: 0, idleSeconds: 91), now: 91) == .question)
  }

  @Test func ladderIsPerProblemAndNeverRunsPastDirect() throws {
    let problems = try problems()
    let ladder = HintLadder()
    #expect(ladder.next(for: problems[0]).rung == .nudge)
    #expect(ladder.next(for: problems[0]).rung == .hint)
    #expect(ladder.next(for: problems[1]).rung == .nudge)
    #expect(ladder.next(for: problems[0], similar: true).rung == .analogy)
    for _ in 0..<8 { #expect(ladder.next(for: problems[0]).rung == .direct) }
    for problem in problems {
      #expect(problem.hints.map(\.rung) == PracticeProblem.Rung.allCases)
      for hint in problem.hints {
        #expect(!hint.text.contains("x = \(Int(problem.answer))"))
      }
    }
  }

  @Test func demoAnswersAndFractionEntry() throws {
    let model = ProblemSetModel(problems: try problems())
    model.enter("3"); #expect(model.check() == .incorrect)
    model.enter("7"); #expect(model.input == "7"); #expect(model.check() == .incorrect)
    model.enter("5"); #expect(model.check() == .correct)
    model.advance(); #expect(model.selectedIndex == 1)
    #expect(model.input.isEmpty)
    #expect(PracticeProblem.value(of: "10/2") == 5)
    #expect(PracticeProblem.value(of: "−6/2") == -3)
    #expect(PracticeProblem.value(of: "1/0") == nil)
    #expect(PracticeProblem.value(of: "1/") == nil)
  }

  @Test func manifestTravelIsDeterministicAndUnderOneAndAHalfSeconds() throws {
    let url = try #require(Bundle.module.url(forResource: "RabbitManifest", withExtension: "json"))
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let manifest = try decoder.decode(CharacterManifest.self, from: Data(contentsOf: url))
    let player = SpritePlayer(manifest: manifest, seed: 42)
    var sent = false
    var received = false
    player.playSequence(manifest.jumpSequence.sending) { sent = true }
    var duration = 0.0
    while !sent && duration < 2 { player.tick(1.0 / 60); duration += 1.0 / 60 }
    #expect(sent)
    player.playSequence(manifest.jumpSequence.receiving) { received = true }
    while !received && duration < 3 { player.tick(1.0 / 60); duration += 1.0 / 60 }
    #expect(received)
    #expect(duration < 1.5)
    #expect(!player.inSequence)
    #expect(!player.hidden)
    let sameSeed = SpritePlayer(manifest: manifest, seed: 42)
    let another = SpritePlayer(manifest: manifest, seed: 42)
    for _ in 0..<20 { #expect(sameSeed.random() == another.random()) }
    player.playSequence(manifest.jumpSequence.sending) {}
    player.cancelSequence()
    #expect(!player.inSequence)
    #expect(player.current == "idle")
  }

  @Test func openingThroughAStagePoseAndReversingDoesNotLeaveStaleConversationPose() throws {
    let url = try #require(Bundle.module.url(forResource: "RabbitManifest", withExtension: "json"))
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let bunny = BunnyState(manifest: try decoder.decode(CharacterManifest.self, from: Data(contentsOf: url)), recording: true)
    let anchor = CGPoint(x: 600, y: 500)
    bunny.configure(pose: .flat, anchor: anchor, scale: 2) {}
    bunny.prepareDive()
    bunny.configure(pose: .book, anchor: anchor, scale: 3) {}
    for _ in 0..<34 { bunny.player.tick(1.0 / 60) }
    #expect(bunny.phase == .receiving)
    var arrived = false
    bunny.configure(pose: .flat, anchor: anchor, scale: 2) { arrived = true }
    #expect(bunny.pose == .flat)
    #expect(ScriptedBrain().offer(for: bunny.pose).contains("Fold me up"))
    for _ in 0..<120 { bunny.player.tick(1.0 / 60) }
    #expect(arrived)
    #expect(bunny.phase == .resting)
    #expect(!bunny.player.hidden)
  }

  @Test func closingDuringDiveKeepsConversationAndRestoresBunny() throws {
    let url = try #require(Bundle.module.url(forResource: "RabbitManifest", withExtension: "json"))
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let bunny = BunnyState(manifest: try decoder.decode(CharacterManifest.self, from: Data(contentsOf: url)), recording: true)
    bunny.configure(pose: .flat, anchor: .zero, scale: 2) {}
    bunny.message = "A hint worth keeping."
    bunny.configure(pose: .tabletop, anchor: .zero, scale: 3) {}
    bunny.configure(pose: .closed, anchor: .zero, scale: 1) {}
    #expect(bunny.pose == .closed)
    #expect(bunny.phase == .resting)
    #expect(!bunny.player.hidden)
    #expect(bunny.message == "A hint worth keeping.")
  }
}
