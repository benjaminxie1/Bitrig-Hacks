// OCR bench: synthetic handwriting for Khan-style working → the app's Vision settings → does each line
// read back as the same equation? Usage: bench [config] [pngdir]
import AppKit
import Foundation
import Vision

setvbuf(stdout, nil, _IONBF, 0)

struct RNG {
  var s: UInt64
  mutating func next() -> Double {
    s &+= 0x9E37_79B9_7F4A_7C15
    var z = s
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
  }
  mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
}

func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
struct Glyph { let w: Double; let strokes: [[CGPoint]] }
func loop(cx: Double, cy: Double, rx: Double, ry: Double, from: Double = -Double.pi / 2, turns: Double = 1.08) -> [CGPoint] {
  (0...16).map { i in let a = from - Double(i) / 16 * 2 * .pi * turns; return P(cx + rx * cos(a), cy + ry * sin(a)) }
}
// y = 0 top of a digit, 1 baseline; lowercase letters live in 0.45…1, descenders go below 1.
let glyphs: [Character: Glyph] = [
  "0": Glyph(w: 0.62, strokes: [loop(cx: 0.31, cy: 0.5, rx: 0.27, ry: 0.5)]),
  "1": Glyph(w: 0.36, strokes: [[P(0.04, 0.2), P(0.18, 0.08), P(0.28, 0.0), P(0.27, 0.5), P(0.26, 1.0)]]),
  "2": Glyph(w: 0.66, strokes: [[P(0.06, 0.22), P(0.18, 0.06), P(0.36, 0.0), P(0.54, 0.06), P(0.6, 0.22), P(0.52, 0.42), P(0.34, 0.63), P(0.14, 0.84), P(0.03, 0.99), P(0.28, 0.97), P(0.5, 0.97), P(0.66, 0.96)]]),
  "3": Glyph(w: 0.64, strokes: [[P(0.08, 0.2), P(0.2, 0.05), P(0.38, 0.0), P(0.55, 0.06), P(0.6, 0.2), P(0.5, 0.36), P(0.3, 0.46), P(0.52, 0.52), P(0.64, 0.68), P(0.58, 0.87), P(0.38, 0.99), P(0.18, 0.97), P(0.04, 0.86)]]),
  "4": Glyph(w: 0.64, strokes: [[P(0.44, 0.02), P(0.25, 0.35), P(0.05, 0.66), P(0.35, 0.66), P(0.64, 0.66)], [P(0.47, 0.3), P(0.47, 0.65), P(0.46, 1.0)]]),
  "5": Glyph(w: 0.64, strokes: [[P(0.2, 0.03), P(0.17, 0.24), P(0.14, 0.46), P(0.3, 0.4), P(0.48, 0.43), P(0.62, 0.57), P(0.62, 0.77), P(0.5, 0.94), P(0.3, 0.99), P(0.12, 0.93), P(0.04, 0.84)], [P(0.2, 0.03), P(0.4, 0.02), P(0.63, 0.0)]]),
  "6": Glyph(w: 0.62, strokes: [[P(0.52, 0.04), P(0.3, 0.12), P(0.13, 0.4), P(0.1, 0.72), P(0.26, 0.98), P(0.48, 0.95), P(0.58, 0.74), P(0.46, 0.54), P(0.22, 0.56), P(0.11, 0.72)]]),
  "7": Glyph(w: 0.62, strokes: [[P(0.04, 0.03), P(0.33, 0.03), P(0.62, 0.02), P(0.45, 0.35), P(0.32, 0.65), P(0.22, 1.0)]]),
  "8": Glyph(w: 0.6, strokes: [[P(0.5, 0.12), P(0.32, 0.0), P(0.12, 0.1), P(0.18, 0.34), P(0.45, 0.52), P(0.58, 0.76), P(0.4, 0.98), P(0.14, 0.95), P(0.07, 0.75), P(0.25, 0.52), P(0.5, 0.33), P(0.54, 0.14)]]),
  "9": Glyph(w: 0.6, strokes: [[P(0.54, 0.26), P(0.38, 0.02), P(0.14, 0.08), P(0.09, 0.3), P(0.3, 0.46), P(0.52, 0.32), P(0.55, 0.22), P(0.52, 0.6), P(0.42, 1.0)]]),
  "x": Glyph(w: 0.56, strokes: [[P(0.04, 0.42), P(0.2, 0.61), P(0.36, 0.8), P(0.52, 1.0)], [P(0.53, 0.43), P(0.34, 0.62), P(0.18, 0.8), P(0.02, 1.0)]]),
  "w": Glyph(w: 0.7, strokes: [[P(0.02, 0.45), P(0.12, 0.75), P(0.18, 1.0), P(0.28, 0.72), P(0.35, 0.55), P(0.42, 0.75), P(0.5, 1.0), P(0.6, 0.7), P(0.68, 0.44)]]),
  "y": Glyph(w: 0.58, strokes: [[P(0.04, 0.45), P(0.16, 0.72), P(0.3, 0.96)], [P(0.56, 0.44), P(0.4, 0.8), P(0.28, 1.1), P(0.18, 1.3), P(0.06, 1.28)]]),
  "g": Glyph(w: 0.58, strokes: [[P(0.52, 0.52), P(0.32, 0.45), P(0.1, 0.56), P(0.08, 0.76), P(0.24, 0.9), P(0.46, 0.82), P(0.53, 0.5), P(0.52, 0.9), P(0.5, 1.15), P(0.35, 1.32), P(0.12, 1.25)]]),
  "q": Glyph(w: 0.6, strokes: [[P(0.52, 0.52), P(0.32, 0.45), P(0.1, 0.56), P(0.08, 0.76), P(0.24, 0.9), P(0.46, 0.82), P(0.53, 0.5)], [P(0.53, 0.46), P(0.53, 0.9), P(0.52, 1.32), P(0.64, 1.22)]]),
  "f": Glyph(w: 0.5, strokes: [[P(0.5, 0.08), P(0.38, 0.0), P(0.24, 0.08), P(0.21, 0.4), P(0.2, 1.0)], [P(0.04, 0.47), P(0.24, 0.46), P(0.44, 0.45)]]),
  "+": Glyph(w: 0.6, strokes: [[P(0.3, 0.32), P(0.3, 0.58), P(0.31, 0.86)], [P(0.04, 0.6), P(0.3, 0.59), P(0.57, 0.58)]]),
  "-": Glyph(w: 0.52, strokes: [[P(0.05, 0.6), P(0.26, 0.59), P(0.48, 0.58)]]),
  "=": Glyph(w: 0.62, strokes: [[P(0.04, 0.47), P(0.3, 0.46), P(0.58, 0.45)], [P(0.05, 0.73), P(0.31, 0.72), P(0.6, 0.71)]]),
  "(": Glyph(w: 0.36, strokes: [[P(0.32, -0.02), P(0.14, 0.3), P(0.1, 0.62), P(0.16, 0.9), P(0.32, 1.12)]]),
  ")": Glyph(w: 0.36, strokes: [[P(0.04, -0.02), P(0.22, 0.3), P(0.26, 0.62), P(0.2, 0.9), P(0.04, 1.12)]]),
  "/": Glyph(w: 0.5, strokes: [[P(0.46, -0.02), P(0.26, 0.5), P(0.06, 1.05)]]),
]

func smooth(_ pts: [CGPoint]) -> [CGPoint] {
  if pts.count < 3 {
    let a = pts[0], b = pts[pts.count - 1]
    let n = max(2, Int(hypot(b.x - a.x, b.y - a.y) / 3))
    return (0...n).map { i in let t = CGFloat(i) / CGFloat(n); return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
  }
  var out: [CGPoint] = []
  let p = [pts[0]] + pts + [pts[pts.count - 1]]
  for i in 1..<(p.count - 2) {
    let (p0, p1, p2, p3) = (p[i - 1], p[i], p[i + 1], p[i + 2])
    let n = max(2, Int(hypot(p2.x - p1.x, p2.y - p1.y) / 3))
    for s in 0..<n {
      let t = CGFloat(s) / CGFloat(n), t2 = t * t, t3 = t2 * t
      func cr(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
        0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
      }
      out.append(CGPoint(x: cr(p0.x, p1.x, p2.x, p3.x), y: cr(p0.y, p1.y, p2.y, p3.y)))
    }
  }
  out.append(pts[pts.count - 1])
  return out
}

/// Handwriting in page pixels (1000 × 1400). `messy` scales the jitter (mouse-like shakiness).
func write(_ text: String, x startX: Double, baseline: Double, height H: Double, messy: Double, rng: inout RNG) -> [[CGPoint]] {
  var x = startX
  var strokes: [[CGPoint]] = []
  let drift = rng.range(-0.015, 0.015)
  for ch in text {
    if ch == " " { x += H * rng.range(0.26, 0.34); continue }
    guard let g = glyphs[ch] else { continue }
    let s = rng.range(0.93, 1.07), base = baseline + rng.range(-3, 3) * messy + (x - startX) * drift
    let rot = rng.range(-0.04, 0.04) * messy, slant = rng.range(0.08, 0.16), gh = H * s
    for raw in g.strokes {
      let placed = raw.map { p -> CGPoint in
        let jx = rng.range(-0.015, 0.015) * messy, jy = rng.range(-0.015, 0.015) * messy
        let lx = (p.x + jx) * gh + (1 - p.y) * gh * slant, ly = -(1 - (p.y + jy)) * gh
        return CGPoint(x: x + lx * cos(rot) - ly * sin(rot), y: base + lx * sin(rot) + ly * cos(rot))
      }
      // Mouse tremor: small high-frequency wobble along the smoothed path.
      strokes.append(smooth(placed).enumerated().map { i, q in
        CGPoint(x: q.x + sin(Double(i) * 1.7 + rng.range(0, 6)) * 0.9 * messy, y: q.y + cos(Double(i) * 1.3) * 0.9 * messy)
      })
    }
    x += g.w * gh + H * rng.range(0.1, 0.17)
  }
  return strokes
}

struct Config { var name: String; var renderScale: CGFloat; var widthScale: CGFloat; var perLine: Bool }

func render(_ strokes: [[CGPoint]], config: Config, crop: CGRect? = nil) -> CGImage {
  let page = crop ?? CGRect(x: 0, y: 0, width: 1000, height: 1400)
  let s = config.renderScale
  let w = Int(page.width * s), h = Int(page.height * s)
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
  ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: s, y: -s); ctx.translateBy(x: -page.minX, y: -page.minY)
  ctx.setStrokeColor(CGColor(red: 0x3B / 255.0, green: 0x2A / 255.0, blue: 0x23 / 255.0, alpha: 1))
  ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.setLineWidth(5.2 * config.widthScale)
  for st in strokes { ctx.beginPath(); ctx.addLines(between: st); ctx.strokePath() }
  return ctx.makeImage()!
}

/// Same request settings as App/Ink/InkReader.swift, lines grouped top to bottom.
func recognize(_ image: CGImage) -> [String] {
  let request = VNRecognizeTextRequest()
  request.recognitionLevel = .accurate
  request.usesLanguageCorrection = false
  request.recognitionLanguages = ["en-US"]
  request.minimumTextHeight = 0.008
  try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
  let obs = (request.results ?? []).compactMap { o -> (CGRect, String)? in
    guard let c = o.topCandidates(1).first else { return nil }
    return (o.boundingBox, c.string)
  }.sorted { $0.0.midY > $1.0.midY }
  var groups: [[(CGRect, String)]] = []
  for o in obs {
    if let i = groups.lastIndex(where: { abs($0[0].0.midY - o.0.midY) < max($0[0].0.height, o.0.height) * 0.55 }) { groups[i].append(o) }
    else { groups.append([o]) }
  }
  return groups.map { $0.sorted { $0.0.minX < $1.0.minX }.map(\.1).joined(separator: " ") }
}

// Khan-style working, one problem per page, various letters.
let pages: [(letter: Character, lines: [String])] = [
  ("w", ["-2(w-7)=18", "-2w+14=18", "-2w=4", "w=-2"]),
  ("f", ["3f+2=8-3f", "6f+2=8", "6f=6", "f=1"]),
  ("g", ["6g=48", "g=8"]),
  ("q", ["16=2q+3", "13=2q", "q=13/2"]),
  ("y", ["4y-9=3", "4y=12", "y=3"]),
  ("x", ["3x+5=20", "3x=15", "x=5"]),
]

let args = CommandLine.arguments
let configs: [Config] = [
  Config(name: "app-now (5.2px pen)", renderScale: 1, widthScale: 1, perLine: false),
  Config(name: "pen x1.8", renderScale: 1, widthScale: 1.8, perLine: false),
  Config(name: "pen x2.2", renderScale: 1, widthScale: 2.2, perLine: false),
  Config(name: "pen x2.6", renderScale: 1, widthScale: 2.6, perLine: false),
]
let pngDir = args.count > 2 ? args[2] : nil
let seeds: [UInt64] = [11, 22, 33, 44]
let messiness: [Double] = [1.0, 2.2]

for config in configs {
  var total = 0, exact = 0, semantic = 0
  var misses: [String] = []
  for messy in messiness {
    for seed in seeds {
      for (pi, page) in pages.enumerated() {
        var rng = RNG(s: seed &* 1000 &+ UInt64(pi))
        var lineStrokes: [[[CGPoint]]] = []
        for (li, line) in page.lines.enumerated() {
          let spaced = line.map { "=+-".contains($0) ? " \($0) " : String($0) }.joined()
          lineStrokes.append(write(spaced, x: 110 + rng.range(-10, 20), baseline: 260 + Double(li) * 150, height: 88, messy: messy, rng: &rng))
        }
        var read: [String]
        if config.perLine {
          read = lineStrokes.map { st in
            let pts = st.flatMap { $0 }
            let minX = pts.map(\.x).min()!, maxX = pts.map(\.x).max()!, minY = pts.map(\.y).min()!, maxY = pts.map(\.y).max()!
            let crop = CGRect(x: minX - 30, y: minY - 30, width: maxX - minX + 60, height: maxY - minY + 60)
            return recognize(render(st, config: config, crop: crop)).joined(separator: " ")
          }
        } else {
          let image = render(lineStrokes.flatMap { $0 }, config: config)
          read = recognize(image)
          if let dir = pngDir, seed == 11 {
            let url = URL(fileURLWithPath: "\(dir)/\(config.name.prefix(8))-m\(messy)-\(page.letter).png") as CFURL
            let d = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil)!
            CGImageDestinationAddImage(d, image, nil); CGImageDestinationFinalize(d)
          }
        }
        for (li, truth) in page.lines.enumerated() {
          total += 1
          let got = li < read.count ? MathNormalizer.repairLookalikes(MathNormalizer.normalize(read[li], variable: page.letter), variable: page.letter) : ""
          let squash = { (s: String) in s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "−", with: "-") }
          if squash(got) == squash(truth) { exact += 1 }
          if let a = LinearParser.parseEquation(got, variable: page.letter), let b = LinearParser.parseEquation(truth, variable: page.letter),
             a.lhs == b.lhs, a.rhs == b.rhs { semantic += 1 }
          else if misses.count < 14 { misses.append("m\(messy) \(truth) → \"\(li < read.count ? read[li] : "∅")\"") }
        }
      }
    }
  }
  print(String(format: "%-32@ same-equation %3d/%d (%.0f%%)  exact %3d/%d", config.name as NSString, semantic, total, 100.0 * Double(semantic) / Double(total), exact, total))
  for m in misses.prefix(8) { print("     miss: \(m)") }
}
