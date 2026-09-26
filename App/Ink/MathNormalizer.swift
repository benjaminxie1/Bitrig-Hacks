import Foundation

enum MathNormalizer {
  /// Character-for-character substitutions preserve Vision's original token ranges.
  static func normalize(_ input: String) -> String {
    var chars = Array(input)
    for index in chars.indices {
      switch chars[index] {
      case "×", "X": chars[index] = "x"
      case "−", "–", "—": chars[index] = "-"
      // Vision sometimes answers handwritten math with Cyrillic look-alikes.
      case "З", "з": chars[index] = "3"
      case "У", "у": chars[index] = "y"
      case "Х", "х": chars[index] = "x"
      case "О": chars[index] = "0"
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

  /// Same substitutions, aware of the problem's letter: an uppercase form of that letter reads as the
  /// letter itself (W → w on a w problem), and the l → 1 fix is skipped when the letter is l.
  static func normalize(_ input: String, variable: Character) -> String {
    guard variable != "x" else { return normalize(input) }
    let upper = Character(variable.uppercased())
    var chars = Array(input)
    for index in chars.indices where chars[index] == upper { chars[index] = variable }
    if variable == "l" {
      let base = Array(normalize(String(chars)))
      // Put back the letter l wherever normalize turned it into 1.
      return String(zip(chars, base).map { original, mapped in original == "l" ? "l" : mapped })
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return normalize(String(chars))
  }

  /// Handwritten g and q read as 9 (b as 6, z as 2, s as 5, o as 0, t as 7). When a line has no letter at
  /// all and reads as a false numeric statement ("69 = 48"), it's almost certainly a misread, and reporting
  /// it would accuse the student of a mistake they didn't make. Try the problem's letter in place of its
  /// look-alike digit, fewest swaps and leftmost first, and keep the first reading that parses as a linear
  /// equation in that letter. True numeric lines (20 − 5 = 15) and lines that contain the letter are left alone.
  static func repairLookalikes(_ line: String, variable: Character) -> String {
    let lookalike: [Character: Set<Character>] = ["g": ["9"], "q": ["9", "0"], "b": ["6"], "z": ["2"], "s": ["5"], "o": ["0"], "t": ["7"]]
    guard let digits = lookalike[variable], !line.contains(variable),
          let equation = LinearParser.parseEquation(line), equation.variable == nil,
          equation.lhs.konst != equation.rhs.konst else { return line }
    let chars = Array(line)
    let spots = chars.indices.filter { digits.contains(chars[$0]) }
    guard !spots.isEmpty, spots.count <= 4 else { return line }
    var combos: [[Int]] = spots.map { [$0] }
    for i in spots.indices { for j in spots.indices where j > i { combos.append([spots[i], spots[j]]) } }
    for combo in combos {
      var candidate = chars
      for i in combo { candidate[i] = variable }
      let text = String(candidate)
      if let parsed = LinearParser.parseEquation(text, variable: variable), parsed.variable == variable { return text }
    }
    return line
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
