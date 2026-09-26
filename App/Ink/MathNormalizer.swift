import Foundation

enum MathNormalizer {
  /// Character-for-character substitutions preserve Vision's original token ranges.
  static func normalize(_ input: String) -> String {
    var chars = Array(input)
    for index in chars.indices {
      switch chars[index] {
      case "×", "X": chars[index] = "x"
      case "−", "–": chars[index] = "-"
      case "l", "I": chars[index] = "1"
      case "S", "O":
        if index > 0 && index + 1 < chars.count && chars[index - 1].isNumber && chars[index + 1].isNumber {
          chars[index] = chars[index] == "S" ? "5" : "0"
        }
      default: break
      }
    }
    return String(chars).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func isUnfinished(_ line: String) -> Bool {
    let text = normalize(line).trimmingCharacters(in: .whitespaces)
    guard let last = text.last else { return true }
    return "+-*/=·(".contains(last) || text.hasSuffix(".")
  }

  static func fingerprint(_ line: String) -> String {
    normalize(line).filter { !$0.isWhitespace }.lowercased()
  }
}
