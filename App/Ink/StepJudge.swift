import Foundation
import CoreFoundation

/// Swift port of Burrow shared/src/steps.ts. Verdicts contain the student's
/// text and coarse categories only, never a corrected value.
enum StepJudge {
  static func splitWorking(_ working: String) -> [String] {
    working.components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
  }

  /// One side of a working line via the shared LinearParser: parentheses, like terms, fractions and
  /// decimals are fine; powers, variable denominators, stray words or a second letter are refused.
  static func parseLinearSide(_ raw: String, variable: Character? = nil) -> LinearSide? {
    guard let side = LinearParser.parse(raw, variable: variable) else { return nil }
    let result = LinearSide(coef: side.form.coef.doubleValue, konst: side.form.konst.doubleValue)
    return result.coef.isFinite && result.konst.isFinite ? result : nil
  }

  static func parseWorkingLine(_ raw: String, variable: Character? = nil) -> ParsedStep? {
    guard let equation = LinearParser.parseEquation(raw, variable: variable) else { return nil }
    return ParsedStep(lhs: LinearSide(coef: equation.lhs.coef.doubleValue, konst: equation.lhs.konst.doubleValue),
                      rhs: LinearSide(coef: equation.rhs.coef.doubleValue, konst: equation.rhs.konst.doubleValue))
  }

  static func holds(_ line: ParsedStep, at solution: Double) -> Bool {
    abs(line.lhs.coef * solution + line.lhs.konst - line.rhs.coef * solution - line.rhs.konst) < 0.000001
  }

  static func categorize(_ line: ParsedStep, solution: Double) -> StepCategory {
    var variants = Array(repeating: line, count: 4)
    variants[0].lhs.coef *= -1
    variants[1].lhs.konst *= -1
    variants[2].rhs.coef *= -1
    variants[3].rhs.konst *= -1
    return variants.contains { holds($0, at: solution) } ? .sign : .arithmetic
  }

  static func judge(problem: PracticeProblem?, working: String) -> WorkingJudgement {
    guard let problem, problem.coefficient != 0, problem.answer.isFinite else { return .unjudged }
    var result = WorkingJudgement(judged: true, steps: [], firstWrongStep: nil, solved: false, planStep: 0)
    var constantCleared = false
    for (index, line) in splitWorking(working).enumerated() {
      guard let parsed = parseWorkingLine(line, variable: problem.letter) else {
        result.steps.append(StepVerdict(step: index + 1, line: line, ok: nil))
        continue
      }
      let ok = holds(parsed, at: problem.answer)
      result.steps.append(StepVerdict(step: index + 1, line: line, ok: ok,
        category: ok ? nil : categorize(parsed, solution: problem.answer)))
      if !ok {
        if result.firstWrongStep == nil { result.firstWrongStep = index + 1 }
      } else if parsed.lhs.konst == 0 && parsed.rhs.coef == 0 && parsed.lhs.coef != 0 {
        constantCleared = true
        if parsed.lhs.coef == 1 { result.solved = true }
      }
    }
    result.planStep = result.solved ? (abs(problem.coefficient) != 1 ? 2 : 1) : constantCleared ? 1 : 0
    return result
  }

  /// Also ports the upstream boundary sanitizer, without adding a remote provider.
  static func parseJudgement(_ raw: [String: Any]?, working: String, planLength: Int) -> WorkingJudgement {
    func number(_ value: Any?) -> Double? {
      guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
      return value.doubleValue
    }
    let lines = splitWorking(working)
    guard let raw, raw["judged"] as? Bool == true,
          let values = raw["steps"] as? [[String: Any]], !lines.isEmpty else { return .unjudged }
    var byStep: [Int: StepVerdict] = [:]
    for value in values {
      guard let number = number(value["step"]), number.isFinite, number.rounded() == number,
            number >= 1, number <= Double(lines.count) else { continue }
      let step = Int(number)
      let ok = value["ok"] as? Bool
      byStep[step] = StepVerdict(step: step, line: lines[step - 1], ok: ok,
        category: ok == false ? StepCategory(rawValue: value["category"] as? String ?? "") ?? .unknown : nil)
    }
    let steps = lines.enumerated().map { byStep[$0.offset + 1] ?? StepVerdict(step: $0.offset + 1, line: $0.element, ok: nil) }
    let first = steps.first { $0.ok == false }?.step
    let progress = number(raw["planStep"]).flatMap { value -> Int? in
      guard value.isFinite, value.rounded() == value else { return nil }
      return Int(min(Double(planLength), max(0, value)))
    }
    return WorkingJudgement(judged: true, steps: steps, firstWrongStep: first,
      solved: raw["solved"] as? Bool == true && first == nil, planStep: progress)
  }
}

struct LinearSide: Equatable, Sendable { var coef: Double; var konst: Double }
struct ParsedStep: Equatable, Sendable { var lhs: LinearSide; var rhs: LinearSide }
enum StepCategory: String, Codable, CaseIterable, Sendable { case sign, arithmetic, reasoning, unknown }
struct StepVerdict: Codable, Equatable, Sendable {
  var step: Int
  var line: String
  var ok: Bool?
  var category: StepCategory?
}
struct WorkingJudgement: Codable, Equatable, Sendable {
  var judged: Bool
  var steps: [StepVerdict]
  var firstWrongStep: Int?
  var solved: Bool
  var planStep: Int?
  static var unjudged: Self { .init(judged: false, steps: [], firstWrongStep: nil, solved: false, planStep: nil) }
}
