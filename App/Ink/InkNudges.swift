import Foundation

enum InkNudges {
  static func text(category: StepCategory, rung: Int, lines: [String]) -> String {
    let table: [StepCategory: [String]] = [
      .sign: ["How did the sign change in this step?", "Check the sign of the term you moved."],
      .arithmetic: ["Could you check the calculation in this step?", "Look at the number after the equals sign and check the operation."],
      .reasoning: ["Does this step keep both sides balanced?", "Check whether the same operation happened on both sides."],
      .unknown: ["Could you take another look at this step?", "Compare this line with the one just above it."]
    ]
    if rung < 3 { return table[category]![max(0, rung - 1)] }
    // Choose numbers absent from the student's work, including their answer.
    let used = Set(lines.flatMap { numbers(in: $0) })
    let a = (2...40).first { !used.contains($0) && !used.contains($0 + 7) } ?? 41
    let b = a + 7
    switch category {
    case .arithmetic: return "For y + \(a) = \(b), compare \(b) minus \(a) with \(b) plus \(a)."
    case .sign: return "In y + \(a) = \(b), moving positive \(a) changes its sign."
    case .reasoning, .unknown: return "For y + \(a) = \(b), subtract \(a) from both sides."
    }
  }

  static func note(category: StepCategory) -> [String] {
    switch category {
    case .sign: ["Check the sign:", "Which term moved?", "What changed with it?"]
    case .arithmetic: ["Check the operation:", "Read the line above.", "What changed here?"]
    case .reasoning, .unknown: ["Keep the balance:", "Compare both sides.", "What changed here?"]
    }
  }

  static func issue(category: StepCategory) -> String {
    switch category {
    case .sign: "A sign needs another look"
    case .arithmetic: "A calculation needs another look"
    case .reasoning: "The balance needs another look"
    case .unknown: "This step needs another look"
    }
  }

  static func numbers(in text: String) -> [Int] {
    let regex = try! NSRegularExpression(pattern: #"\d+"#)
    let ns = text as NSString
    return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
      .compactMap { Int(ns.substring(with: $0.range)) }
  }
}
