import Foundation
import Observation

@MainActor
@Observable
final class InterventionEngine {
  private(set) var level = Level.quiet
  private(set) var cooldownUntil = 0.0
  private(set) var declinedUntil = 0.0
  private var goal = Level.quiet
  private var nextStepAt = 0.0
  private(set) var offerActive = false

  static func level(for signals: StruggleTracker.Signals, now: Double, cooldownUntil: Double = 0, declinedUntil: Double = 0) -> Level {
    if now < declinedUntil { return .quiet }
    let strength = signals.strength
    let raw = strength < 0.25 ? 0 : strength < 0.45 ? 1 : strength < 0.6 ? 2 : strength < 0.8 ? 3 : 4
    return Level(rawValue: now < cooldownUntil ? min(raw, 1) : raw)!
  }

  func evaluate(_ signals: StruggleTracker.Signals, at time: Double) {
    if offerActive {
      if Self.level(for: signals, now: time, declinedUntil: declinedUntil) == .spoken && goal != .spoken {
        goal = .spoken
        nextStepAt = time + 0.55
      }
      if goal == .spoken && time >= nextStepAt { level = .spoken }
      return
    }
    let desired = Self.level(for: signals, now: time, cooldownUntil: cooldownUntil, declinedUntil: declinedUntil)
    if desired.rawValue > goal.rawValue {
      goal = desired
      if level == .quiet { level = .look }
      nextStepAt = time + 0.45
    }
    if time >= nextStepAt && level.rawValue < goal.rawValue {
      level = Level(rawValue: level.rawValue + 1)!
      nextStepAt = time + 0.55
      if level == .offer {
        offerActive = true
        cooldownUntil = time + 45
      }
    }
  }

  func resolve(at time: Double, declined: Bool) {
    offerActive = false
    level = .quiet
    goal = .quiet
    cooldownUntil = time + (declined ? 180 : 45)
    if declined { declinedUntil = time + 180 }
  }

  func reset() {
    level = .quiet
    goal = .quiet
    offerActive = false
    cooldownUntil = 0
    declinedUntil = 0
  }

  enum Level: Int, Comparable, Sendable {
    case quiet, look, question, offer, spoken
    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
  }
}
