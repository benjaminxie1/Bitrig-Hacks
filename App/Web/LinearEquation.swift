import Foundation

/// Reduced rational arithmetic keeps extracted decimal/fraction solutions exact.
/// Overflow or unsupported math returns nil instead of inventing a problem.
struct Rational: Equatable, Sendable {
  var numerator: Int64
  var denominator: Int64
  init?(_ numerator: Int64, _ denominator: Int64 = 1) {
    guard denominator != 0, numerator != .min, denominator != .min else { return nil }
    let divisor = Self.gcd(abs(numerator), abs(denominator))
    self.numerator = numerator / divisor * (denominator < 0 ? -1 : 1)
    self.denominator = abs(denominator) / divisor
  }
  var doubleValue: Double { Double(numerator) / Double(denominator) }
  var text: String { denominator == 1 ? "\(numerator)" : "\(numerator)/\(denominator)" }
  static func gcd(_ a: Int64, _ b: Int64) -> Int64 {
    var a = a, b = b
    while b != 0 { (a, b) = (b, a % b) }
    return max(1, a)
  }
  static func parse(_ text: String) -> Self? {
    let parts = text.replacingOccurrences(of: " ", with: "").components(separatedBy: "/")
    if parts.count == 2, let a = parse(parts[0]), let b = parse(parts[1]) { return a.divided(by: b) }
    guard parts.count == 1 else { return nil }
    let decimals = text.components(separatedBy: ".")
    if decimals.count == 1, let integer = Int64(text) { return Rational(integer) }
    guard decimals.count == 2, decimals[1].count <= 8,
          let integer = Int64(text.replacingOccurrences(of: ".", with: "")) else { return nil }
    return Rational(integer, Int64(pow(10, Double(decimals[1].count))))
  }
  func subtracting(_ other: Self) -> Self? {
    let divisor = Self.gcd(denominator, other.denominator)
    let a = numerator.multipliedReportingOverflow(by: other.denominator / divisor)
    let b = other.numerator.multipliedReportingOverflow(by: denominator / divisor)
    let denominator = denominator.multipliedReportingOverflow(by: other.denominator / divisor)
    let numerator = a.partialValue.subtractingReportingOverflow(b.partialValue)
    guard !a.overflow, !b.overflow, !denominator.overflow, !numerator.overflow else { return nil }
    return Self(numerator.partialValue, denominator.partialValue)
  }
  func divided(by other: Self) -> Self? {
    guard other.numerator != 0 else { return nil }
    let g1 = Self.gcd(abs(numerator), abs(other.numerator))
    let g2 = Self.gcd(denominator, other.denominator)
    let n = (numerator / g1).multipliedReportingOverflow(by: other.denominator / g2)
    let d = (denominator / g2).multipliedReportingOverflow(by: other.numerator / g1)
    guard !n.overflow, !d.overflow else { return nil }
    return Self(n.partialValue, d.partialValue)
  }
}

struct LinearEquation: Equatable, Sendable {
  var coefficient: Rational
  var constant: Rational
  var rightSide: Rational
  var variable: String
  var text: String
  var solution: Rational? { rightSide.subtracting(constant)?.divided(by: coefficient) }

  /// Extends Burrow hints.ts EQ_RE with decimals and fractions. Still ax+b=c,
  /// with one variable, never powers, systems or nonlinear expressions.
  static func detect(in raw: String) -> Self? {
    let text = normalizeTeX(raw)
    let number = #"(?:\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?)"#
    let pattern = #"(?<![\w^/])(-?\s*"# + number + #"?|\+?)\s*\*?\s*([a-z])\s*(?:([+-])\s*("# + number + #"))?\s*=\s*([+-]?\s*"# + number + #")(?![\w./^])"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
    let ns = text as NSString
    for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      func value(_ index: Int) -> String {
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : ns.substring(with: range).replacingOccurrences(of: " ", with: "")
      }
      let coefficientText = value(1)
      let a = coefficientText.isEmpty || coefficientText == "+" ? Rational(1) : coefficientText == "-" ? Rational(-1) : Rational.parse(coefficientText)
      let b = value(4).isEmpty ? Rational(0) : Rational.parse((value(3) == "-" ? "-" : "") + value(4))
      guard let a, let b, let c = Rational.parse(value(5)), a.numerator != 0 else { continue }
      // Do not accept a linear-looking suffix of a nonlinear equation.
      let before = ns.substring(to: match.range.location).components(separatedBy: .newlines).last ?? ""
      let after = ns.substring(from: match.range.location + match.range.length).components(separatedBy: .newlines).first ?? ""
      if before.contains("=") || before.contains("^") || after.trimmingCharacters(in: .whitespaces).first.map({ "+-*/=^".contains($0) }) == true { continue }
      let result = Self(coefficient: a, constant: b, rightSide: c, variable: value(2).lowercased(),
        text: ns.substring(with: match.range).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression))
      if result.solution != nil { return result }
    }
    return nil
  }

  static func normalizeTeX(_ input: String) -> String {
    var result = input.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
      .replacingOccurrences(of: "×", with: "x").replacingOccurrences(of: "·", with: "*")
    result = result.replacingOccurrences(of: #"\\(?:d?frac)\s*\{([^{}]+)\}\s*\{([^{}]+)\}"#, with: "$1/$2", options: .regularExpression)
    for command in [#"\left"#, #"\right"#, #"\("#, #"\)"#, #"\["#, #"\]"#, "$", #"\,"#, #"\!"#] {
      result = result.replacingOccurrences(of: command, with: "")
    }
    result = result.replacingOccurrences(of: #"\cdot"#, with: "*").replacingOccurrences(of: #"\times"#, with: "*")
    return result
  }

  var problem: PracticeProblem {
    let isP1 = coefficient == Rational(3) && constant == Rational(5) && rightSide == Rational(20) && variable == "x"
    return PracticeProblem(id: isP1 ? "p1" : "web:\(coefficient.text):\(constant.text):\(rightSide.text):\(variable)",
      title: "Web practice", coefficient: coefficient.doubleValue, constant: constant.doubleValue,
      rightSide: rightSide.doubleValue, equation: text, focusTerm: "", hints: [])
  }

  static func extract(primary: String, tex: [String], visibleText: String) -> Self? {
    if let equation = detect(in: primary) { return equation }
    for annotation in tex { if let equation = detect(in: annotation) { return equation } }
    return detect(in: visibleText)
  }
}
