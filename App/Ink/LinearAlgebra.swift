import Foundation

/// Reduced rational arithmetic keeps extracted decimal/fraction solutions exact.
/// Overflow or unsupported math returns nil instead of inventing a problem.
struct Rational: Equatable, Hashable, Sendable {
  var numerator: Int64
  var denominator: Int64
  init?(_ numerator: Int64, _ denominator: Int64 = 1) {
    guard denominator != 0, numerator != .min, denominator != .min else { return nil }
    let divisor = Self.gcd(abs(numerator), abs(denominator))
    self.numerator = numerator / divisor * (denominator < 0 ? -1 : 1)
    self.denominator = abs(denominator) / divisor
  }
  static let zero = Rational(0)!
  static let one = Rational(1)!
  var isZero: Bool { numerator == 0 }
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
  var negated: Self { Self(-numerator, denominator)! }
  func adding(_ other: Self) -> Self? {
    let divisor = Self.gcd(denominator, other.denominator)
    let a = numerator.multipliedReportingOverflow(by: other.denominator / divisor)
    let b = other.numerator.multipliedReportingOverflow(by: denominator / divisor)
    let d = denominator.multipliedReportingOverflow(by: other.denominator / divisor)
    let n = a.partialValue.addingReportingOverflow(b.partialValue)
    guard !a.overflow, !b.overflow, !d.overflow, !n.overflow else { return nil }
    return Self(n.partialValue, d.partialValue)
  }
  func subtracting(_ other: Self) -> Self? { adding(other.negated) }
  func multiplied(by other: Self) -> Self? {
    let n = numerator.multipliedReportingOverflow(by: other.numerator)
    let d = denominator.multipliedReportingOverflow(by: other.denominator)
    guard !n.overflow, !d.overflow else { return nil }
    return Self(n.partialValue, d.partialValue)
  }
  func divided(by other: Self) -> Self? {
    guard other.numerator != 0 else { return nil }
    return multiplied(by: Self(other.denominator, other.numerator)!)
  }
}

/// coef·v + konst, exactly.
struct LinearForm: Equatable, Sendable {
  var coef: Rational
  var konst: Rational
  static func constant(_ value: Rational) -> Self { .init(coef: .zero, konst: value) }
  var isConstant: Bool { coef.isZero }
  func adding(_ o: Self) -> Self? {
    guard let c = coef.adding(o.coef), let k = konst.adding(o.konst) else { return nil }
    return .init(coef: c, konst: k)
  }
  var negated: Self { .init(coef: coef.negated, konst: konst.negated) }
  func scaled(by r: Rational) -> Self? {
    guard let c = coef.multiplied(by: r), let k = konst.multiplied(by: r) else { return nil }
    return .init(coef: c, konst: k)
  }
}

/// A one-variable linear equation lhs = rhs.
struct LinearEquationForm: Equatable, Sendable {
  var lhs: LinearForm
  var rhs: LinearForm
  /// The single letter used, if any.
  var variable: Character?
  /// Net coefficient after moving everything left: (a − c)v + (b − d) = 0.
  var solution: Rational? {
    guard let a = lhs.coef.subtracting(rhs.coef), !a.isZero, let b = rhs.konst.subtracting(lhs.konst) else { return nil }
    return b.divided(by: a)
  }
}

/// Recursive-descent parser for one-variable linear expressions and equations, shared by the web tab
/// (reading the problem) and the step judge (reading each handwritten line).
///
/// Accepts numbers and decimals, a single letter variable, + − * / × ·, parentheses, unary minus and
/// implicit multiplication after a number or ")" (2x, 3(x + 1), (x + 1)(2) is rejected). Refuses anything
/// that isn't linear in one letter: powers, a variable in a denominator, products of variables, two
/// different letters, stray words, trailing operators, division by zero.
enum LinearParser {
  enum Token: Equatable { case number(Rational), letter(Character), op(Character) }

  static func normalize(_ raw: String) -> String {
    raw.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: "–", with: "-")
      .replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "·", with: "*")
      .replacingOccurrences(of: "÷", with: "/")
  }

  static func tokenize(_ raw: String) -> [Token]? {
    let chars = Array(normalize(raw))
    var tokens: [Token] = []
    var i = 0
    while i < chars.count {
      let c = chars[i]
      if c.isWhitespace { i += 1; continue }
      if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
        var j = i
        var digits = ""
        while j < chars.count, chars[j].isNumber || chars[j] == "." { digits.append(chars[j]); j += 1 }
        guard let value = Rational.parse(digits) else { return nil }
        tokens.append(.number(value)); i = j; continue
      }
      if c.isLetter, c.isASCII { tokens.append(.letter(Character(c.lowercased()))); i += 1; continue }
      if "+-*/()^".contains(c) { tokens.append(.op(c)); i += 1; continue }
      return nil
    }
    return tokens
  }

  /// Parses one side. `variable` restricts which letter is allowed; otherwise the first letter wins
  /// and any second letter is refused.
  static func parse(_ raw: String, variable: Character? = nil) -> (form: LinearForm, variable: Character?)? {
    guard let tokens = tokenize(raw), !tokens.isEmpty else { return nil }
    var state = State(tokens: tokens, variable: variable)
    guard let form = state.expression(), state.index == tokens.count else { return nil }
    return (form, state.variable)
  }

  static func parseEquation(_ raw: String, variable: Character? = nil) -> LinearEquationForm? {
    let parts = normalize(raw).components(separatedBy: "=")
    guard parts.count == 2, let l = parse(parts[0], variable: variable) else { return nil }
    guard let r = parse(parts[1], variable: variable ?? l.variable) else { return nil }
    if let a = l.variable, let b = r.variable, a != b { return nil }
    return LinearEquationForm(lhs: l.form, rhs: r.form, variable: l.variable ?? r.variable)
  }

  private struct State {
    let tokens: [Token]
    var variable: Character?
    var index = 0

    init(tokens: [Token], variable: Character?) { self.tokens = tokens; self.variable = variable }

    var peek: Token? { index < tokens.count ? tokens[index] : nil }

    mutating func expression() -> LinearForm? {
      guard var value = term() else { return nil }
      while case .op(let o)? = peek, o == "+" || o == "-" {
        index += 1
        guard let next = term(), let sum = value.adding(o == "+" ? next : next.negated) else { return nil }
        value = sum
      }
      return value
    }

    mutating func term() -> LinearForm? {
      guard var value = unary() else { return nil }
      var lastWasNumberOrParen = previousEndsImplicitly
      while let token = peek {
        switch token {
        case .op("*"):
          index += 1
          guard let rhs = unary(), let product = multiply(value, rhs) else { return nil }
          value = product
        case .op("/"):
          index += 1
          guard let rhs = unary(), rhs.isConstant, !rhs.konst.isZero,
                let q = value.scaled(by: Rational.one.divided(by: rhs.konst)!) else { return nil }
          value = q
        case .letter, .op("("):
          // Implicit multiplication only after a number or a closing parenthesis: 2x, 3(x+1), (x+1)y is refused below.
          guard lastWasNumberOrParen else { return value }
          guard let rhs = power(), let product = multiply(value, rhs) else { return nil }
          value = product
        default:
          return value
        }
        lastWasNumberOrParen = previousEndsImplicitly
      }
      return value
    }

    /// True when the token just consumed was a number or ")", which may be followed by 2x / 3( style factors.
    var previousEndsImplicitly: Bool {
      guard index > 0 else { return false }
      switch tokens[index - 1] {
      case .number: return true
      case .op(")"): return true
      default: return false
      }
    }

    mutating func unary() -> LinearForm? {
      if case .op(let o)? = peek, o == "+" || o == "-" {
        index += 1
        guard let inner = unary() else { return nil }
        return o == "-" ? inner.negated : inner
      }
      return power()
    }

    mutating func power() -> LinearForm? {
      guard let base = primary() else { return nil }
      if case .op("^")? = peek { return nil }  // powers are never linear here
      return base
    }

    mutating func primary() -> LinearForm? {
      guard let token = peek else { return nil }
      switch token {
      case .number(let r):
        index += 1
        return .constant(r)
      case .letter(let c):
        if let v = variable, v != c { return nil }
        variable = c
        index += 1
        return LinearForm(coef: .one, konst: .zero)
      case .op("("):
        index += 1
        guard let inner = expression(), case .op(")")? = peek else { return nil }
        index += 1
        return inner
      default:
        return nil
      }
    }

    func multiply(_ a: LinearForm, _ b: LinearForm) -> LinearForm? {
      if a.isConstant { return b.scaled(by: a.konst) }
      if b.isConstant { return a.scaled(by: b.konst) }
      return nil  // v · v is not linear
    }
  }
}
