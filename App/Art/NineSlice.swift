import SwiftUI

struct NineSlice: View {
  var name: String
  var scale: Int = 3

  var body: some View {
    Canvas { context, size in
      guard let piece = PixelArtStore.shared.ui.pieces[name],
            let source = UIImage(named: "ui_" + URL(fileURLWithPath: piece.file).deletingPathExtension().lastPathComponent)?.cgImage else { return }
      context.withCGContext { cg in
        cg.interpolationQuality = .none
        let edges = piece.slice.values.map(CGFloat.init)
        let w = CGFloat(piece.size[0]), h = CGFloat(piece.size[1])
        let xs = [0, edges[3], w - edges[1], w]
        let ys = [0, edges[0], h - edges[2], h]
        let dx = [0, edges[3] * CGFloat(scale), size.width - edges[1] * CGFloat(scale), size.width]
        let dy = [0, edges[0] * CGFloat(scale), size.height - edges[2] * CGFloat(scale), size.height]
        for row in 0..<3 {
          for col in 0..<3 {
            let sourceRect = CGRect(x: xs[col], y: ys[row], width: xs[col + 1] - xs[col], height: ys[row + 1] - ys[row])
            let target = CGRect(x: dx[col], y: dy[row], width: max(0, dx[col + 1] - dx[col]), height: max(0, dy[row + 1] - dy[row]))
            guard let part = source.cropping(to: sourceRect), !target.isEmpty else { continue }
            cg.saveGState()
            cg.translateBy(x: target.minX, y: target.maxY)
            cg.scaleBy(x: 1, y: -1)
            cg.draw(part, in: CGRect(origin: .zero, size: target.size))
            cg.restoreGState()
          }
        }
      }
    }
    .accessibilityHidden(true)
  }
}
