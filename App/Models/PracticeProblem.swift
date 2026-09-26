import Foundation

struct PracticeProblem: Codable, Identifiable, Equatable, Sendable {
  var id: String
  var title: String
  var coefficient: Double
  var constant: Double
  var rightSide: Double
  var equation: String
  var focusTerm: String
  var hints: [Hint]

  var answer: Double { (rightSide - constant) / coefficient }

  func accepts(_ input: String) -> Bool {
    guard let value = Self.value(of: input) else { return false }
    return abs(value - answer) < 0.000_001
  }

  static func value(of input: String) -> Double? {
    let parts = input.replacingOccurrences(of: "−", with: "-").split(separator: "/", omittingEmptySubsequences: false)
    guard let first = parts.first, let numerator = Double(first), numerator.isFinite else { return nil }
    if parts.count == 1 { return numerator }
    guard parts.count == 2, let denominator = Double(parts[1]), denominator != 0, denominator.isFinite else { return nil }
    return numerator / denominator
  }

  struct Hint: Codable, Equatable, Sendable {
    var rung: Rung
    var text: String
    var target: Target
  }

  enum Rung: String, Codable, CaseIterable, Sendable {
    case nudge, hint, explanation, analogy, direct
    var title: String {
      switch self {
      case .nudge: "A little nudge"
      case .hint: "One step at a time"
      case .explanation: "Keep it balanced"
      case .analogy: "A similar problem"
      case .direct: "Your turn"
      }
    }
  }

  enum Target: String, Codable, Sendable {
    case term, answer
  }
}
