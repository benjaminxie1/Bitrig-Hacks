import Foundation

/// Port of judgeInkMock's three-beat rehearsal. Live unreadable ink never uses
/// this mock: only an explicitly selected debug rehearsal may fabricate lines.
enum MockInkJudge {
  static func judge(_ input: InkJudgeInput) -> InkJudgement {
    let box = InkBox(x: 0.248, y: 0.398, w: 0.064, h: 0.027)
    let mark = InkBox(x: 0.287, y: 0.398, w: 0.025, h: 0.026)
    let space = InkBox(x: 0.224, y: 0.465, w: 0.576, h: 0.452)
    var result = InkJudgement.empty
    result.confidence = 0.9
    result.space = space
    result.status = .ok
    if input.locate != nil {
      result.lines = ["3x + 5 = 20", "3x = 25"]
      result.box = box; result.mark = mark
    } else if input.reason == .stall || input.seq % 3 == 1 {
      result.lines = ["3x + 5 = 20", "3x = 25"]
      result.status = .off; result.line = 2; result.box = box; result.mark = mark
      result.issue = InkNudges.issue(category: .arithmetic)
      result.nudge = InkNudges.text(category: .arithmetic, rung: min(3, max(1, input.rung)), lines: result.lines)
      if input.reason == .stall {
        result.note = ["Taking away:", "y + 2 = 9", "y = 9 - 2"]
        result.nudge = "Here is a similar one to try."
      }
    } else if input.seq % 3 == 0 {
      result.lines = ["3x + 5 = 20"]
    } else {
      result.lines = ["3x + 5 = 20", "3x = 15", "x = 5"]
      result.confidence = 0.95; result.solved = true
    }
    return result
  }
}
