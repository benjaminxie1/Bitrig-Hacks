import SwiftUI

struct SpriteView: View {
  var player: SpritePlayer
  var scale: Int
  var facesLeading = false
  var cosmeticHoleFrame: Int?

  var body: some View {
    ZStack(alignment: .topLeading) {
      if let image = PixelArtStore.shared.frame(
        state: cosmeticHoleFrame == nil ? player.current : "hole_open",
        index: cosmeticHoleFrame ?? player.frame
      ) {
        pixelImage(image)
      }
      if player.showsMouth, let image = PixelArtStore.shared.frame(state: "overlay_mouth", index: player.mouthFrame) {
        pixelImage(image).offset(y: CGFloat(player.headDY * scale))
      }
      if player.showsBlink, let image = PixelArtStore.shared.frame(state: "overlay_blink", index: player.blinkFrame) {
        pixelImage(image).offset(y: CGFloat(player.headDY * scale))
      }
    }
    .frame(width: CGFloat(64 * scale), height: CGFloat(58 * scale))
    .scaleEffect(x: facesLeading ? -1 : 1, y: 1)
    .opacity(player.hidden ? 0 : 1)
    .accessibilityLabel("Bunny")
    .accessibilityValue(player.current.replacingOccurrences(of: "_", with: " "))
    .accessibilityAddTraits(.isImage)
    .allowsHitTesting(false)
  }

  private func pixelImage(_ image: CGImage) -> some View {
    Image(decorative: image, scale: 1)
      .resizable()
      .interpolation(.none)
      .frame(width: CGFloat(64 * scale), height: CGFloat(58 * scale))
  }
}
