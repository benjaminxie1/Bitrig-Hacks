import Foundation
import Observation

@MainActor
@Observable
final class StruggleTracker {
  private(set) var incorrectAttempts = 0
  private(set) var emptyChecks: [Double] = []
  private(set) var lastActivity = 0.0
  private(set) var hadStruggle = false

  func activity(at time: Double) { lastActivity = time }
  func wrong(at time: Double) {
    incorrectAttempts += 1
    lastActivity = time
    hadStruggle = true
  }
  func empty(at time: Double) {
    emptyChecks.append(time)
    lastActivity = time
    emptyChecks = emptyChecks.filter { time - $0 <= 20 }
    if emptyChecks.count >= 3 { hadStruggle = true }
  }
  func snapshot(at time: Double) -> Signals {
    let emptyCount = emptyChecks.filter { time - $0 <= 20 }.count
    return Signals(incorrectAttempts: incorrectAttempts, emptyChecks: emptyCount, idleSeconds: max(0, time - lastActivity))
  }
  func reset(at time: Double, incorrectAttempts: Int = 0) {
    self.incorrectAttempts = incorrectAttempts
    emptyChecks = []
    lastActivity = time
    hadStruggle = incorrectAttempts > 0
  }

  struct Signals: Equatable, Sendable {
    var incorrectAttempts: Int
    var emptyChecks: Int
    var idleSeconds: Double

    var strength: Double {
      let wrong = incorrectAttempts >= 3 ? 0.85 : incorrectAttempts >= 2 ? 0.75 : Double(incorrectAttempts) * 0.3
      let empty = emptyChecks >= 3 ? 0.85 : Double(emptyChecks) * 0.15
      return min(1, wrong + empty + (idleSeconds > 90 ? 0.45 : 0))
    }
  }
}
