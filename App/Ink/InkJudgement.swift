import Foundation
import CoreGraphics

/// Exact shared/src/ink.ts verdict shape. Rung belongs to InkJudgeInput and
/// the session, not to the upstream InkJudgement JSON.
struct InkJudgement: Codable, Equatable, Sendable {
  var lines: [String]
  var status: InkStatus
  var line: Int?
  var box: InkBox?
  var mark: InkBox?
  var issue: String
  var nudge: String
  var confidence: Double
  var solved: Bool
  var note: [String]
  var space: InkBox?

  static var empty: Self {
    .init(lines: [], status: .unclear, line: nil, box: nil, mark: nil,
          issue: "", nudge: "", confidence: 0, solved: false, note: [], space: nil)
  }
}

enum InkStatus: String, Codable, Sendable { case ok, off, unclear }
enum InkReason: String, Codable, Sendable { case ink, pause, stall }
struct InkJudgeInput: Codable, Sendable {
  var frame = ""
  var context: String?
  var contextTitle = ""
  var contextUrl = ""
  var previousLines: [String] = []
  var seq = 0
  var reason = InkReason.ink
  var rung = 1
  var lastWrongLine: String?
  var locate: String?
}

/// Top-left origin, fractions of the page, not fractions of the device.
struct InkBox: Codable, Equatable, Sendable {
  var x: Double
  var y: Double
  var w: Double
  var h: Double
  var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }

  init(x: Double, y: Double, w: Double, h: Double) {
    self.x = x; self.y = y; self.w = w; self.h = h
  }
  init(_ rect: CGRect) { self.init(x: rect.minX, y: rect.minY, w: rect.width, h: rect.height) }
  func inPage(_ page: CGRect) -> CGRect {
    CGRect(x: page.minX + x * page.width, y: page.minY + y * page.height, width: w * page.width, height: h * page.height)
  }
  var isValid: Bool {
    [x, y, w, h].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && w > 0 && h > 0 && x + w <= 1.001 && y + h <= 1.001
  }
}

struct InkToken: Codable, Equatable, Sendable {
  var text: String
  var box: InkBox
}
struct InkLine: Codable, Equatable, Sendable {
  var text: String
  var box: InkBox
  var tokens: [InkToken]
  var confidence: Double
}
