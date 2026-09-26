import CoreGraphics
import Observation

@MainActor
@Observable
final class BunnyState {
  let player: SpritePlayer
  var message = "One small step at a time."
  var subtitle = "YOUR STUDY COMPANION"
  var replies = Replies.none
  var guide: PracticeProblem.Target?
  var hasArrived = false
  var phase = TravelPhase.resting
  var departureAnchor = CGPoint.zero
  var departureScale = 2
  var lastAnchor = CGPoint.zero
  var lastScale = 2
  var pose = BurrowPose.closed
  var wanderOffset = 0.0
  private var destination: BurrowPose?
  private var onArrival: (() -> Void)?

  init(manifest: CharacterManifest, recording: Bool) {
    player = SpritePlayer(manifest: manifest, seed: recording ? 0xB0770 : UInt64.random(in: 1...UInt64.max))
  }

  func configure(pose next: BurrowPose, anchor: CGPoint, scale: Int, arrival: @escaping () -> Void) {
    if !hasArrived {
      pose = next
      hasArrived = true
      player.forceState("wave")
    } else if next != pose {
      let wasStage = pose == .tabletop || pose == .book
      let becomesStage = next == .tabletop || next == .book
      let crossesOuterDisplay = next == .closed || pose == .closed
      // Conversation logic follows the latest layout immediately; only the
      // sprite's departure/arrival is delayed by travel animation.
      pose = next
      if crossesOuterDisplay {
        cancelTravel()
      } else if wasStage != becomesStage {
        // A reversal during receiving starts a new trip from this region.
        // Otherwise there would be a queued destination with no layout pass
        // left to start it, leaving Bunny's logical pose behind the screen.
        if phase == .receiving { cancelTravel() }
        destination = next
        onArrival = arrival
        if phase == .resting { prepareDive() }
        if phase == .waiting { receive() }
      } else if phase != .resting {
        onArrival = arrival
        if phase != .receiving { destination = next }
        if phase == .waiting { receive() }
      }
    }
    lastAnchor = anchor
    lastScale = scale
  }

  func cancelTravel() {
    player.cancelSequence()
    phase = .resting
    destination = nil
    onArrival = nil
  }

  func cancelEarlyDive() {
    if destination == nil && phase != .resting && phase != .receiving { cancelTravel() }
  }

  func prepareDive() {
    guard phase == .resting, hasArrived else { return }
    departureAnchor = lastAnchor
    departureScale = lastScale
    wanderOffset = 0
    phase = .sending
    player.playSequence(player.manifest.jumpSequence.sending) { [weak self] in
      guard let self else { return }
      phase = .waiting
      player.hidden = true
      if destination != nil { receive() }
    }
  }

  private func receive() {
    guard destination != nil else { return }
    self.destination = nil
    phase = .receiving
    player.playSequence(player.manifest.jumpSequence.receiving) { [weak self] in
      guard let self else { return }
      phase = .resting
      let arrival = onArrival
      onArrival = nil
      arrival?()
    }
  }

  enum TravelPhase: Equatable { case resting, sending, waiting, receiving }
  enum Replies: Equatable { case none, offer, hint, celebration }
}
