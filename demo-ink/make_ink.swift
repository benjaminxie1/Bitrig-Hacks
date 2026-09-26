// Generates handwritten demo ink for Burrow as InkDemoAsset sidecars (.ink.json + .pkdrawing),
// plus preview PNGs and animated GIFs. Page space is 1000 x 1400 (InkPageLayout.aspect = 1.4);
// drawings are stored normalized to a 1 x 1 page, exactly like InkDocument.normalizedDrawing.
//
// Usage: swiftc -O make_ink.swift -o make_ink && ./make_ink <outdir>
import AppKit
import Foundation
import ImageIO
import PencilKit
import UniformTypeIdentifiers

let pageSize = CGSize(width: 1000, height: 1400)
let inkColor = NSColor(srgbRed: 0x3B / 255, green: 0x2A / 255, blue: 0x23 / 255, alpha: 1)
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "out")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// MARK: - Seeded randomness (same output every run)

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
var rng = RNG(s: 20260926)

// MARK: - Glyphs: strokes in a box where y = 0 is the top of a digit and y = 1 the baseline.

struct Glyph { let w: Double; let strokes: [[CGPoint]] }
func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

func zeroStroke() -> [CGPoint] {
    (0...16).map { i in
        let t = Double(i) / 16 * (2 * .pi + 0.35)
        let a = -Double.pi / 2 - 0.15 - t
        let shrink = 1 - 0.06 * Double(i) / 16
        return P(0.31 + 0.27 * shrink * cos(a), 0.5 + 0.5 * shrink * sin(a))
    }
}

let glyphs: [Character: Glyph] = [
    "3": Glyph(w: 0.64, strokes: [[P(0.08, 0.2), P(0.2, 0.05), P(0.38, 0.0), P(0.55, 0.06), P(0.6, 0.2), P(0.5, 0.36),
                                   P(0.3, 0.46), P(0.52, 0.52), P(0.64, 0.68), P(0.58, 0.87), P(0.38, 0.99), P(0.18, 0.97), P(0.04, 0.86)]]),
    "x": Glyph(w: 0.56, strokes: [[P(0.04, 0.42), P(0.2, 0.61), P(0.36, 0.8), P(0.52, 1.0)],
                                  [P(0.53, 0.43), P(0.34, 0.62), P(0.18, 0.8), P(0.02, 1.0)]]),
    "+": Glyph(w: 0.6, strokes: [[P(0.3, 0.32), P(0.3, 0.58), P(0.31, 0.86)], [P(0.04, 0.6), P(0.3, 0.59), P(0.57, 0.58)]]),
    "=": Glyph(w: 0.62, strokes: [[P(0.04, 0.47), P(0.3, 0.46), P(0.58, 0.45)], [P(0.05, 0.73), P(0.31, 0.72), P(0.6, 0.71)]]),
    "5": Glyph(w: 0.64, strokes: [[P(0.2, 0.03), P(0.17, 0.24), P(0.14, 0.46), P(0.3, 0.4), P(0.48, 0.43), P(0.62, 0.57),
                                   P(0.62, 0.77), P(0.5, 0.94), P(0.3, 0.99), P(0.12, 0.93), P(0.04, 0.84)],
                                  [P(0.2, 0.03), P(0.4, 0.02), P(0.63, 0.0)]]),
    "2": Glyph(w: 0.66, strokes: [[P(0.06, 0.22), P(0.18, 0.06), P(0.36, 0.0), P(0.54, 0.06), P(0.6, 0.22), P(0.52, 0.42),
                                   P(0.34, 0.63), P(0.14, 0.84), P(0.03, 0.99), P(0.28, 0.97), P(0.5, 0.97), P(0.66, 0.96)]]),
    "0": Glyph(w: 0.62, strokes: [zeroStroke()]),
    "1": Glyph(w: 0.36, strokes: [[P(0.04, 0.2), P(0.18, 0.08), P(0.28, 0.0), P(0.27, 0.5), P(0.26, 1.0)]]),
]

// MARK: - Handwriting

/// One pen stroke in page pixels, with its glyph index so tokens can be boxed exactly.
struct PenStroke {
    var points: [CGPoint]
    var glyph: Int
    var duration: Double { max(0.12, length / 520) }
    var length: Double { zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) } }
}

struct WrittenGlyph { let char: Character; var strokes: [PenStroke]; var bounds: CGRect }

/// Catmull-Rom through the control points, sampled every ~3px.
func smooth(_ pts: [CGPoint]) -> [CGPoint] {
    guard pts.count > 2 else {
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

/// Writes `text` with its baseline at `baseline`, starting at `x`. Returns glyphs in order (spaces skipped).
func write(_ text: String, x startX: Double, baseline: Double, height H: Double, firstGlyph: Int) -> [WrittenGlyph] {
    var x = startX
    var out: [WrittenGlyph] = []
    let drift = rng.range(-0.012, 0.012) // whole-line tilt
    for ch in text {
        if ch == " " { x += H * rng.range(0.26, 0.34); continue }
        guard let g = glyphs[ch] else { continue }
        let s = rng.range(0.94, 1.06) * (ch == "x" ? 1.0 : 1.0)
        let base = baseline + rng.range(-3, 3) + (x - startX) * drift
        let rot = rng.range(-0.035, 0.035)
        let slant = 0.13
        let gh = H * s
        var strokes: [PenStroke] = []
        var bounds = CGRect.null
        for raw in g.strokes {
            let placed = raw.map { p -> CGPoint in
                let jx = rng.range(-0.012, 0.012), jy = rng.range(-0.012, 0.012)
                let lx = (p.x + jx) * gh + (1 - p.y) * gh * slant
                let ly = -(1 - (p.y + jy)) * gh
                let rx = lx * cos(rot) - ly * sin(rot), ry = lx * sin(rot) + ly * cos(rot)
                return CGPoint(x: x + rx, y: base + ry)
            }
            let pts = smooth(placed)
            for p in pts { bounds = bounds.union(CGRect(x: p.x, y: p.y, width: 0.1, height: 0.1)) }
            strokes.append(PenStroke(points: pts, glyph: firstGlyph + out.count))
        }
        out.append(WrittenGlyph(char: ch, strokes: strokes, bounds: bounds.insetBy(dx: -4, dy: -4)))
        x += g.w * gh + H * rng.range(0.1, 0.16)
    }
    return out
}

/// Width a string will take (approximate, used to align "=" signs down the page).
func advance(before char: Character, in text: String, height H: Double) -> Double {
    var x = 0.0
    for ch in text {
        if ch == char { return x }
        if ch == " " { x += H * 0.3; continue }
        x += (glyphs[ch]?.w ?? 0.5) * H + H * 0.13
    }
    return x
}

// MARK: - PencilKit

func pkStroke(_ s: PenStroke) -> PKStroke {
    let n = s.points.count
    let pts = s.points.enumerated().map { i, p -> PKStrokePoint in
        let u = Double(i) / Double(max(1, n - 1))
        let eased = 0.5 - 0.5 * cos(u * .pi) // slower at the ends, like a real pen
        let width = 5.2 * (0.82 + 0.3 * sin(u * .pi)) // a touch heavier mid-stroke
        return PKStrokePoint(location: p, timeOffset: eased * s.duration, size: CGSize(width: width, height: width),
                             opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
    }
    return PKStroke(ink: PKInk(.pen, color: inkColor), path: PKStrokePath(controlPoints: pts, creationDate: Date(timeIntervalSince1970: 1_790_450_000)))
}

let normalize = CGAffineTransform(scaleX: 1 / pageSize.width, y: 1 / pageSize.height)
func normalizedDrawing(_ strokes: [PenStroke]) -> PKDrawing {
    PKDrawing(strokes: strokes.map(pkStroke)).transformed(using: normalize)
}

// MARK: - Ground truth (InkLine / InkToken / InkBox)

struct Box: Codable { var x, y, w, h: Double }
struct Token: Codable { var text: String; var box: Box }
struct Line: Codable { var text: String; var box: Box; var tokens: [Token]; var confidence: Double }
struct Checkpoint: Codable { var time: Double; var lines: [Line] }
struct Frame: Codable { var time: Double; var drawing: Data }
struct Asset: Codable {
    var id, title, problemID, kind, file: String
    var verified: Bool
    var checkpoints: [Checkpoint]
    var frames: [Frame]
}

func box(_ r: CGRect) -> Box {
    Box(x: r.minX / pageSize.width, y: r.minY / pageSize.height, w: r.width / pageSize.width, h: r.height / pageSize.height)
}

/// Tokens follow InkReader's regex: numbers, letter runs, and single operators.
func line(_ text: String, _ gs: [WrittenGlyph]) -> Line {
    var tokens: [Token] = []
    var i = 0
    var current = "", rect = CGRect.null, kind = -1
    func flush() { if !current.isEmpty { tokens.append(Token(text: current, box: box(rect))) }; current = ""; rect = .null; kind = -1 }
    for ch in text where ch != " " {
        let k = ch.isNumber ? 0 : ch.isLetter ? 1 : 2
        if k != kind || k == 2 { flush() }
        kind = k
        current.append(ch)
        rect = rect.union(gs[i].bounds)
        i += 1
    }
    flush()
    let all = gs.reduce(CGRect.null) { $0.union($1.bounds) }.insetBy(dx: -6, dy: -6)
    return Line(text: text, box: box(all), tokens: tokens, confidence: 0.97)
}

// MARK: - Timeline

struct Timeline {
    var strokes: [PenStroke] = []
    var frames: [Frame] = []
    var checkpoints: [Checkpoint] = []
    var t = 0.0

    mutating func snapshot() { frames.append(Frame(time: (t * 100).rounded() / 100, drawing: normalizedDrawing(strokes).dataRepresentation())) }

    mutating func writeGlyphs(_ gs: [WrittenGlyph]) {
        var lastGlyph = -1
        for g in gs {
            for s in g.strokes {
                t += (lastGlyph == s.glyph ? rng.range(0.06, 0.1) : rng.range(0.12, 0.2))
                t += s.duration
                strokes.append(s)
                snapshot()
                lastGlyph = s.glyph
            }
        }
    }

    mutating func checkpoint(_ lines: [Line]) { checkpoints.append(Checkpoint(time: frames.last?.time ?? 0, lines: lines)) }
}

// MARK: - Script: 3x + 5 = 20

let H = 92.0
let left = 120.0
let eqX = left + advance(before: "=", in: "3x + 5 = 20", height: H)

let text1 = "3x + 5 = 20"
let l1 = write(text1, x: left, baseline: 270, height: H, firstGlyph: 0)
let eq1 = l1.first { $0.char == "=" }!.bounds.minX + 4
let text2 = "3x = 25"
let l2 = write(text2, x: eq1 - advance(before: "=", in: text2, height: H), baseline: 460, height: H, firstGlyph: 100)
let line1 = line(text1, l1)
let line2wrong = line(text2, l2)

// Asset A: the mistake.
var a = Timeline()
a.snapshot() // empty page at t = 0
a.t = 0.4
a.writeGlyphs(l1)
a.checkpoint([line1])
a.t += 1.3 // pause, look back at the line, carry on
a.writeGlyphs(l2)
a.checkpoint([line1, line2wrong])

// Asset B: the fix, continuing from A's page.
var b = Timeline()
b.strokes = a.strokes
b.snapshot()
b.checkpoint([line1, line2wrong])
// Erase "25": drop its strokes (the eraser removes whole strokes in vector mode).
let wrongDigits = Set(l2.enumerated().filter { $0.element.char.isNumber && $0.offset >= 3 }.map { 100 + $0.offset })
b.t += 1.6
b.strokes.removeAll { wrongDigits.contains($0.glyph) }
b.snapshot()
let l2head = Array(l2.prefix(3)) // "3", "x", "="
b.checkpoint([line1, line(text2.replacingOccurrences(of: " 25", with: ""), l2head)])
// Write "15" where the 25 was.
let startFix = l2[3].bounds.minX + 4
let fixDigits = write("15", x: startFix, baseline: 460, height: H, firstGlyph: 200)
b.t += 0.5
b.writeGlyphs(fixDigits)
let line2fixed = line("3x = 15", l2head + fixDigits)
b.checkpoint([line1, line2fixed])
// Final line: x = 5.
let text3 = "x = 5"
let l3 = write(text3, x: eq1 - advance(before: "=", in: text3, height: H), baseline: 650, height: H, firstGlyph: 300)
b.t += 1.2
b.writeGlyphs(l3)
b.checkpoint([line1, line2fixed, line(text3, l3)])

// MARK: - Output

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

func save(_ tl: Timeline, id: String, title: String) throws {
    let file = "\(id).pkdrawing"
    try normalizedDrawing(tl.strokes).dataRepresentation().write(to: outDir.appendingPathComponent(file))
    let asset = Asset(id: id, title: title, problemID: "p1", kind: "drawing", file: file, verified: true,
                      checkpoints: tl.checkpoints, frames: tl.frames)
    try encoder.encode(asset).write(to: outDir.appendingPathComponent("\(id).ink.json"))
    print("\(id): \(tl.frames.count) frames, \(tl.checkpoints.count) checkpoints, \(String(format: "%.1f", tl.t)) s")
}
try save(a, id: "p1-a-mistake", title: "3x + 5 = 20 · sign slip on line 2")
try save(b, id: "p1-b-fix", title: "3x + 5 = 20 · fix line 2 and finish")

// MARK: - Previews

func paper(_ ctx: CGContext, _ size: CGSize, scale: CGFloat) {
    ctx.setFillColor(NSColor(srgbRed: 1, green: 0.992, blue: 0.96, alpha: 1).cgColor)
    ctx.fill(CGRect(origin: .zero, size: size))
    ctx.setStrokeColor(NSColor(srgbRed: 0.62, green: 0.78, blue: 0.86, alpha: 0.55).cgColor)
    ctx.setLineWidth(1.2 * scale)
    var y = 180.0
    while y < pageSize.height { ctx.move(to: CGPoint(x: 0, y: (pageSize.height - y) * scale)); ctx.addLine(to: CGPoint(x: size.width, y: (pageSize.height - y) * scale)); y += 95 }
    ctx.strokePath()
    ctx.setStrokeColor(NSColor(srgbRed: 0.85, green: 0.45, blue: 0.45, alpha: 0.5).cgColor)
    ctx.move(to: CGPoint(x: 80 * scale, y: 0)); ctx.addLine(to: CGPoint(x: 80 * scale, y: size.height)); ctx.strokePath()
}

/// Renders page-pixel strokes (partial strokes allowed) into a bitmap, y-down page space.
func render(_ strokes: [PenStroke], scale: CGFloat, overlays: ((CGContext) -> Void)? = nil) -> CGImage {
    let size = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    paper(ctx, size, scale: scale)
    let drawing = PKDrawing(strokes: strokes.map(pkStroke))
    let img = drawing.image(from: CGRect(origin: .zero, size: pageSize), scale: scale)
    var r = CGRect(origin: .zero, size: size)
    if let cg = img.cgImage(forProposedRect: &r, context: nil, hints: nil) { ctx.draw(cg, in: CGRect(origin: .zero, size: size)) }
    if let overlays {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: scale, y: -scale) // y-down page space
        overlays(ctx)
        ctx.restoreGState()
    }
    return ctx.makeImage()!
}

func writePNG(_ img: CGImage, _ name: String) {
    let url = outDir.appendingPathComponent(name) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

func rect(_ b: Box) -> CGRect { CGRect(x: b.x * pageSize.width, y: b.y * pageSize.height, width: b.w * pageSize.width, height: b.h * pageSize.height) }

/// Chalk-style ring like pip-inkmark: a slightly wobbly, overshooting ellipse.
func chalkRing(_ ctx: CGContext, around r: CGRect) {
    let c = CGPoint(x: r.midX, y: r.midY), rx = r.width / 2 + 22, ry = r.height / 2 + 16
    ctx.setStrokeColor(NSColor(srgbRed: 0.96, green: 0.95, blue: 0.9, alpha: 1).cgColor)
    ctx.setLineCap(.round)
    for (w, color) in [(13.0, NSColor(srgbRed: 0.36, green: 0.29, blue: 0.25, alpha: 0.35)), (8.0, NSColor(srgbRed: 0.93, green: 0.79, blue: 0.3, alpha: 1))] {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(w)
        ctx.beginPath()
        for i in 0...60 {
            let a = -2.2 + Double(i) / 60 * (2 * .pi + 0.5)
            let wob = 1 + 0.04 * sin(a * 3)
            let p = CGPoint(x: c.x + rx * wob * cos(a), y: c.y + ry * wob * sin(a) - Double(i) * 0.12)
            i == 0 ? ctx.move(to: p) : ctx.addLine(to: p)
        }
        ctx.strokePath()
    }
}

func debugBoxes(_ ctx: CGContext, _ lines: [Line]) {
    for l in lines {
        ctx.setStrokeColor(NSColor.systemTeal.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(2); ctx.setLineDash(phase: 0, lengths: [8, 6])
        ctx.stroke(rect(l.box))
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setStrokeColor(NSColor.systemPink.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1.5)
        for t in l.tokens { ctx.stroke(rect(t.box)) }
    }
}

let s: CGFloat = 0.6
let mark = line2wrong.tokens.first { $0.text == "25" }!.box
writePNG(render(a.strokes, scale: s), "p1-a-mistake.png")
writePNG(render(a.strokes, scale: s) { ctx in chalkRing(ctx, around: rect(mark)) }, "p1-a-mistake-ring.png")
writePNG(render(a.strokes, scale: s) { ctx in debugBoxes(ctx, [line1, line2wrong]) }, "p1-a-mistake-truth.png")
writePNG(render(b.strokes, scale: s), "p1-b-fix.png")
writePNG(render(b.strokes, scale: s) { ctx in debugBoxes(ctx, b.checkpoints.last!.lines) }, "p1-b-fix-truth.png")

/// Animated GIF of the replay (strokes appear point by point at their recorded pace).
func gif(_ tl: Timeline, name: String, startStrokes: [PenStroke] = [], ring: CGRect? = nil, ringUntil: Double = 0) {
    // Rebuild stroke start times from the frame timeline.
    var starts: [(PenStroke, Double)] = []
    var removedAt: Double? = nil
    var prevCount = 0, prevTime = 0.0
    var shown = startStrokes.isEmpty ? [PenStroke]() : startStrokes
    var timeline: [(Double, [PenStroke], PenStroke?, Double)] = [] // (time, base, drawing stroke, start)
    _ = shown; _ = starts; _ = removedAt; _ = prevCount; _ = prevTime; _ = timeline
    let fps = 12.0
    let total = tl.t + 1.5
    let url = outDir.appendingPathComponent(name) as CFURL
    let count = Int(total * fps)
    let dest = CGImageDestinationCreateWithURL(url, UTType.gif.identifier as CFString, count, nil)!
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    // Decode frames back into page-pixel strokes to replay exactly what the app will.
    let frames = tl.frames.map { f -> (Double, PKDrawing) in (f.time, (try! PKDrawing(data: f.drawing)).transformed(using: normalize.inverted())) }
    for i in 0..<count {
        let t = Double(i) / fps
        guard let idx = frames.lastIndex(where: { $0.0 <= t }) else { continue }
        var strokes = frames[idx].1.strokes
        if idx + 1 < frames.count {
            let (t1, next) = frames[idx + 1]
            if next.strokes.count > strokes.count, let add = next.strokes.last {
                let dur = add.path.last?.timeOffset ?? 0.2
                let local = dur - (t1 - t)
                if local > 0 {
                    var partial = add
                    let pts = add.path.filter { $0.timeOffset <= local }
                    if pts.count > 1 { partial.path = PKStrokePath(controlPoints: pts, creationDate: add.path.creationDate); strokes.append(partial) }
                }
            }
        }
        let size = CGSize(width: pageSize.width * 0.45, height: pageSize.height * 0.45)
        let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        paper(ctx, size, scale: 0.45)
        let img = PKDrawing(strokes: strokes).image(from: CGRect(origin: .zero, size: pageSize), scale: 0.45)
        var r = CGRect(origin: .zero, size: size)
        if let cg = img.cgImage(forProposedRect: &r, context: nil, hints: nil) { ctx.draw(cg, in: CGRect(origin: .zero, size: size)) }
        if let ring, t < ringUntil {
            ctx.saveGState(); ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 0.45, y: -0.45)
            chalkRing(ctx, around: ring); ctx.restoreGState()
        }
        CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary)
    }
    CGImageDestinationFinalize(dest)
}
gif(a, name: "p1-a-mistake.gif")
// In the fix replay, the ring shows until the corrected "15" is complete (the moment the line reads correctly).
gif(b, name: "p1-b-fix.gif", ring: rect(mark), ringUntil: b.checkpoints[2].time)
print("previews written to \(outDir.path)")
