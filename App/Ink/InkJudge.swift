import Foundation
import CoreGraphics

enum InkJudge {
  static let minimumConfidence = 0.7

  static func judge(lines: [InkLine], problem: PracticeProblem, rung: Int, reason: InkReason = .ink) -> InkJudgement {
    var result = InkJudgement.empty
    result.lines = lines.map { MathNormalizer.normalize($0.text) }
    result.space = largestEmptySpace(around: lines.map(\.box))
    guard !lines.isEmpty else { return result }
    result.status = .ok
    result.confidence = lines.map(\.confidence).min() ?? 0
    let working = StepJudge.judge(problem: problem, working: result.lines.joined(separator: "\n"))
    guard working.judged else { result.status = .unclear; return result }
    for (index, line) in lines.enumerated() {
      let normalized = result.lines[index]
      if index == lines.count - 1 && MathNormalizer.isUnfinished(normalized) { continue }
      guard line.confidence >= minimumConfidence, line.box.isValid,
            let parsed = StepJudge.parseWorkingLine(normalized) else {
        result.status = .unclear
        result.nudge = "I can't quite read that line. Can you write it a little bigger?"
        return result
      }
      // The parser deliberately accepts a single variable, never mixed-variable work.
      let variables = Set(normalized.filter { $0.isLetter }.map { $0.lowercased() })
      guard variables.isSubset(of: ["x"]) else {
        result.status = .unclear
        result.nudge = "I can't quite read that line. Can you write it a little bigger?"
        return result
      }
      if !StepJudge.holds(parsed, at: problem.answer) {
        let category = StepJudge.categorize(parsed, solution: problem.answer)
        result.status = .off
        result.line = index + 1
        result.box = line.box
        result.mark = mark(in: line, previous: index > 0 ? lines[index - 1] : nil)
        result.issue = InkNudges.issue(category: category)
        result.nudge = InkNudges.text(category: category, rung: rung, lines: result.lines)
        if reason == .stall {
          result.note = InkNudges.note(category: category)
          result.nudge = "Here is a question about that step."
        }
        return result
      }
    }
    // Upstream's judge remembers any earlier solved line. The ink contract is
    // stricter: only a correct, complete final line counts as finishing.
    if let last = result.lines.last, let parsed = StepJudge.parseWorkingLine(last) {
      result.solved = parsed.lhs.coef == 1 && parsed.lhs.konst == 0 && parsed.rhs.coef == 0
        && StepJudge.holds(parsed, at: problem.answer)
    }
    return result
  }

  static func mark(in line: InkLine, previous: InkLine?) -> InkBox {
    let candidates = line.tokens.filter {
      $0.box.isValid && $0.text.contains(where: \.isNumber)
    }
    guard let previous else { return line.box }
    let prior = previous.tokens.map { MathNormalizer.fingerprint($0.text) }
    let changed = candidates.filter { !prior.contains(MathNormalizer.fingerprint($0.text)) }
    if changed.count == 1 { return changed[0].box }
    // Ambiguity is deliberately resolved to the line, never a guessed digit.
    return line.box
  }

  /// Maximal axis-aligned empty rectangle, with a small clearance around ink.
  static func largestEmptySpace(around boxes: [InkBox]) -> InkBox? {
    let obstacles = boxes.filter(\.isValid).map { $0.rect.insetBy(dx: -0.025, dy: -0.02) }
    let xs = ([0.05, 0.95] + obstacles.flatMap { [max(0.05, $0.minX), min(0.95, $0.maxX)] }).sorted()
    let ys = ([0.06, 0.94] + obstacles.flatMap { [max(0.06, $0.minY), min(0.94, $0.maxY)] }).sorted()
    var best = CGRect.zero
    for left in xs {
      for right in xs where right > left {
        for top in ys {
          for bottom in ys where bottom > top {
            let rect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
            if rect.width * rect.height > best.width * best.height &&
                !obstacles.contains(where: { $0.intersects(rect.insetBy(dx: 0.00001, dy: 0.00001)) }) { best = rect }
          }
        }
      }
    }
    return best.width >= 0.3 && best.height >= 0.18 ? InkBox(best) : nil
  }
}
