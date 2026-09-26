import SwiftUI

struct BurrowSceneView: View {
  var palette: String
  var foldProgress: Double
  var scale: Int

  var body: some View {
    Canvas { context, size in
      let store = PixelArtStore.shared
      let manifest = store.scene
      let colors = manifest.palettes[palette] ?? manifest.palettes["day"]!
      for (index, band) in manifest.skyBands.enumerated() {
        let rgb = colors[band] ?? [255, 248, 231]
        let color = Color(red: Double(rgb[0]) / 255, green: Double(rgb[1]) / 255, blue: Double(rgb[2]) / 255)
        let height = ceil(size.height / CGFloat(manifest.skyBands.count))
        context.fill(Path(CGRect(x: 0, y: CGFloat(index) * height, width: size.width, height: height)), with: .color(color))
      }
      let s = CGFloat(max(1, scale))
      let groundY = size.height - 18
      let parallax = (foldProgress * 8).rounded()
      @MainActor func draw(_ name: String, x: CGFloat, feet: CGFloat, factor: CGFloat = 1) {
        guard let image = store.scenePiece(name, palette: palette), let piece = manifest.pieces[name] else { return }
        let rect = CGRect(x: x.rounded(), y: (feet - CGFloat(piece.h) * s * factor).rounded(), width: CGFloat(piece.w) * s * factor, height: CGFloat(piece.h) * s * factor)
        context.draw(Image(decorative: image, scale: 1).interpolation(.none), in: rect)
      }
      let farWidth = CGFloat(manifest.pieces["hills_far"]!.w) * s
      for x in stride(from: -farWidth, through: size.width + farWidth, by: farWidth) {
        draw("hills_far", x: x + parallax, feet: groundY - 19 * s)
      }
      let nearWidth = CGFloat(manifest.pieces["hills_near"]!.w) * s
      for x in stride(from: -nearWidth, through: size.width + nearWidth, by: nearWidth) {
        draw("hills_near", x: x - parallax, feet: groundY - 8 * s)
      }
      draw("cloud_a", x: size.width * 0.1 + parallax, feet: size.height * 0.20)
      draw("cloud_b", x: size.width * 0.72 + parallax, feet: size.height * 0.15)
      draw(palette == "night" ? "moon" : "sun", x: size.width * 0.88, feet: 34 * s)
      draw("mound", x: size.width * 0.48 - 45 * s, feet: groundY)
      draw("door", x: size.width * 0.48 + 18 * s, feet: groundY)
      draw("signpost", x: size.width * 0.11, feet: groundY)
      draw("giant_mushroom", x: size.width * 0.84, feet: groundY)
      for x in stride(from: CGFloat(0), through: size.width, by: 32 * s) {
        draw("ground", x: x, feet: groundY + 15 * s)
      }
      for (fraction, name) in [(0.05, "flower_r"), (0.38, "flower_y"), (0.76, "flower_w"), (0.94, "flower_r")] {
        draw(name, x: size.width * fraction, feet: groundY + 3)
      }
    }
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }

  static func palette(recording: Bool, date: Date = .now) -> String {
    guard !recording else { return "day" }
    let hour = Calendar.current.component(.hour, from: date)
    switch hour {
    case 5..<11: return "morning"
    case 11..<17: return "day"
    case 17..<21: return "evening"
    default: return "night"
    }
  }
}
