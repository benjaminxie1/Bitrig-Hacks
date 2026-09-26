import Foundation
import Observation

@MainActor
@Observable
final class HintLadder {
  private(set) var positions: [String: Int] = [:]
  private(set) var current: PracticeProblem.Hint?

  func next(for problem: PracticeProblem, similar: Bool = false) -> PracticeProblem.Hint {
    let requested = similar ? 3 : positions[problem.id, default: 0]
    let index = min(max(requested, 0), problem.hints.count - 1)
    let hint = problem.hints[index]
    positions[problem.id] = min(index + 1, problem.hints.count - 1)
    current = hint
    return hint
  }

  func clearCurrent() { current = nil }
  func reset() { positions = [:]; current = nil }
}
