import Foundation
import Vision
import CoreGraphics

/// Runs off the main actor. Only the page raster enters Vision; Bunny's ring,
/// scene, bubbles and chalkboard are never included in the recognized image.
actor InkReader {
  func read(_ image: CGImage) throws -> [InkLine] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US"]
    request.minimumTextHeight = 0.008
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let fragments: [InkLine] = (request.results ?? []).compactMap { observation in
      guard let candidate = observation.topCandidates(1).first else { return nil }
      let text = candidate.string
      let regex = try! NSRegularExpression(pattern: #"[+-]?\d+(?:\.\d+)?|[a-zA-Z×]+|[=+\-−–*/·]"#)
      let tokens: [InkToken] = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
        guard let range = Range(match.range, in: text),
              let box = try? candidate.boundingBox(for: range) else { return nil }
        return InkToken(text: MathNormalizer.normalize(String(text[range])), box: Self.topLeft(box.boundingBox))
      }
      return InkLine(text: MathNormalizer.normalize(text), box: Self.topLeft(observation.boundingBox),
        tokens: tokens, confidence: Double(candidate.confidence))
    }
    return Self.groupLines(fragments)
  }

  private static func topLeft(_ rect: CGRect) -> InkBox {
    InkBox(x: rect.minX, y: 1 - rect.maxY, w: rect.width, h: rect.height)
  }

  private static func groupLines(_ fragments: [InkLine]) -> [InkLine] {
    var groups: [[InkLine]] = []
    for fragment in fragments.sorted(by: { $0.box.y < $1.box.y }) {
      if let index = groups.lastIndex(where: { group in
        let box = group[0].box.rect
        return abs(box.midY - fragment.box.rect.midY) < max(box.height, fragment.box.h) * 0.55
      }) { groups[index].append(fragment) }
      else { groups.append([fragment]) }
    }
    return groups.map { group in
      let sorted = group.sorted { $0.box.x < $1.box.x }
      let rect = sorted.dropFirst().reduce(sorted[0].box.rect) { $0.union($1.box.rect) }
      return InkLine(text: sorted.map(\.text).joined(separator: " "), box: InkBox(rect),
        tokens: sorted.flatMap(\.tokens), confidence: sorted.map(\.confidence).min() ?? 0)
    }.sorted { $0.box.y < $1.box.y }
  }
}
