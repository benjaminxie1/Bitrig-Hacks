import Foundation

@MainActor
protocol BunnyBrain {
  func offer(for pose: BurrowPose) -> String
  func hint(for problem: PracticeProblem, ladder: HintLadder, similar: Bool) -> PracticeProblem.Hint
  func celebration() -> String
  func readInk(lines: [InkLine], problem: PracticeProblem, rung: Int, reason: InkReason) -> InkJudgement
}
