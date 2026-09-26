import Foundation

/// The homework problem found on a web page: one linear equation in one variable.
/// Parsing and solving go through LinearParser, the same parser the step judge uses for each
/// handwritten line, so the page and the working always agree. Anything non-linear is refused.
struct LinearEquation: Equatable, Sendable {
  var form: LinearEquationForm
  var variable: String
  var text: String
  var solution: Rational? { form.solution }

  /// ax + b = c when the right side is a constant (so 3x + 5 = 20 stays recognisable as p1);
  /// otherwise everything moves left: (a − c)x + (b − d) = 0.
  var coefficient: Rational {
    form.rhs.isConstant ? form.lhs.coef : form.lhs.coef.subtracting(form.rhs.coef) ?? form.lhs.coef
  }
  var constant: Rational {
    form.rhs.isConstant ? form.lhs.konst : form.lhs.konst.subtracting(form.rhs.konst) ?? form.lhs.konst
  }
  var rightSide: Rational { form.rhs.isConstant ? form.rhs.konst : .zero }

  static func detect(in raw: String) -> Self? {
    for candidate in candidates(in: normalizeTeX(raw)) {
      guard let form = LinearParser.parseEquation(candidate) ?? crossMultiplied(candidate),
            let v = form.variable, form.solution != nil else { continue }
      return Self(form: form, variable: String(v), text: display(candidate))
    }
    return nil
  }

  /// k/(linear) = c, as in Khan's "rational equations intro": cross-multiplied to k = c·(linear), which is
  /// the first step a student writes. Only accepted when the solution keeps the denominator non-zero.
  static func crossMultiplied(_ candidate: String) -> LinearEquationForm? {
    let sides = LinearParser.normalize(candidate).components(separatedBy: "=")
    guard sides.count == 2 else { return nil }
    let fraction = #"^\s*\(?\s*([^()/]+?)\s*\)?\s*/\s*\((.+)\)\s*$"#
    for (fractionSide, otherSide) in [(sides[0], sides[1]), (sides[1], sides[0])] {
      guard let match = fractionSide.range(of: fraction, options: .regularExpression) else { continue }
      let part = String(fractionSide[match])
      guard let regex = try? NSRegularExpression(pattern: fraction),
            let m = regex.firstMatch(in: part, range: NSRange(part.startIndex..., in: part)),
            let numRange = Range(m.range(at: 1), in: part), let denRange = Range(m.range(at: 2), in: part),
            let numerator = LinearParser.parse(String(part[numRange])), numerator.form.isConstant,
            let denominator = LinearParser.parse(String(part[denRange])), let v = denominator.variable,
            let other = LinearParser.parse(otherSide, variable: v), other.form.isConstant,
            let scaled = denominator.form.scaled(by: other.form.konst) else { continue }
      let form = LinearEquationForm(lhs: numerator.form, rhs: scaled, variable: v)
      guard let x = form.solution, let atX = denominator.form.coef.multiplied(by: x)?.adding(denominator.form.konst),
            !atX.isZero else { return nil }
      return form
    }
    return nil
  }

  /// Equation-shaped spans around each "=": digits, operators, parentheses and lone letters.
  /// A letter touching another letter belongs to a word ("Solve", "for") and ends the span.
  /// If a span doesn't parse, leading words are dropped one at a time ("is a 3x + 5 = 20").
  static func candidates(in text: String) -> [String] {
    var spans: [String] = []
    for line in text.components(separatedBy: .newlines) where line.contains("=") {
      let chars = Array(line)
      func isWordLetter(_ i: Int) -> Bool {
        chars[i].isLetter && ((i > 0 && chars[i - 1].isLetter) || (i + 1 < chars.count && chars[i + 1].isLetter))
      }
      func isMath(_ i: Int) -> Bool {
        let c = chars[i]
        return !isWordLetter(i) && (c.isNumber || c.isLetter || c.isWhitespace || "+-*/().=^".contains(c))
      }
      for (eq, c) in chars.enumerated() where c == "=" {
        var lo = eq, hi = eq
        while lo > 0, isMath(lo - 1) { lo -= 1 }
        while hi + 1 < chars.count, isMath(hi + 1) { hi += 1 }
        let span = String(chars[lo...hi]).trimmingCharacters(in: .whitespaces)
        let words = span.split(separator: " ", omittingEmptySubsequences: true)
        for drop in 0..<max(1, words.count) {
          let tail = words.dropFirst(drop).joined(separator: " ")
          if tail.contains("="), !spans.contains(tail) { spans.append(tail) }
        }
      }
    }
    return spans
  }

  static func display(_ candidate: String) -> String {
    candidate.replacingOccurrences(of: #"\((\d+(?:\.\d+)?)\)"#, with: "$1", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: "-", with: "−")
      .trimmingCharacters(in: .whitespaces)
  }

  static func normalizeTeX(_ input: String) -> String {
    var result = input.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
    // \frac{a}{b} keeps its grouping: (a)/(b).
    result = result.replacingOccurrences(of: #"\\(?:d|t)?frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}"#, with: "($1)/($2)", options: .regularExpression)
    for command in [#"\left"#, #"\right"#, #"\("#, #"\)"#, #"\["#, #"\]"#, "$", #"\,"#, #"\!"#, #"\;"#] {
      result = result.replacingOccurrences(of: command, with: "")
    }
    result = result.replacingOccurrences(of: #"\cdot"#, with: "*").replacingOccurrences(of: #"\times"#, with: "*")
      .replacingOccurrences(of: #"\div"#, with: "/").replacingOccurrences(of: "{", with: "(").replacingOccurrences(of: "}", with: ")")
    return result
  }

  var problem: PracticeProblem {
    let isP1 = coefficient == Rational(3)! && constant == Rational(5)! && rightSide == Rational(20)! && variable == "x"
    return PracticeProblem(id: isP1 ? "p1" : "web:\(coefficient.text):\(constant.text):\(rightSide.text):\(variable)",
      title: "Web practice", coefficient: coefficient.doubleValue, constant: constant.doubleValue,
      rightSide: rightSide.doubleValue, equation: text, focusTerm: "", hints: [], variable: variable)
  }

  static func extract(primary: String, tex: [String], visibleText: String) -> Self? {
    if let equation = detect(in: primary) { return equation }
    for annotation in tex { if let equation = detect(in: annotation) { return equation } }
    return detect(in: visibleText)
  }
}
