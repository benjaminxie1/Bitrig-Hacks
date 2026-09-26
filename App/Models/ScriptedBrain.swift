import Foundation

struct ScriptedBrain: BunnyBrain {
  func readInk(lines: [InkLine], problem: PracticeProblem, rung: Int, reason: InkReason) -> InkJudgement {
    InkJudge.judge(lines: lines, problem: problem, rung: rung, reason: reason)
  }
  func offer(for pose: BurrowPose) -> String {
    let base = "Looks like this one’s being stubborn. Want a hint?"
    switch pose {
    case .flat: return base + "\nFold me up and let’s work on it together."
    case .closed: return base + "\nOpen me up."
    case .tabletop, .book: return base
    }
  }

  func hint(for problem: PracticeProblem, ladder: HintLadder, similar: Bool) -> PracticeProblem.Hint {
    ladder.next(for: problem, similar: similar)
  }

  func celebration() -> String { "Nice—you got it. That was all you!" }
}
