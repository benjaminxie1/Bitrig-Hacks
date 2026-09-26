import SwiftUI

struct GuideMarker: View {
  var body: some View {
    ZStack {
      corner("tl", alignment: .topLeading)
      corner("tr", alignment: .topTrailing)
      corner("bl", alignment: .bottomLeading)
      corner("br", alignment: .bottomTrailing)
    }
    .overlay(alignment: .bottomTrailing) {
      Image("ui_guide_paw")
        .resizable().interpolation(.none)
        .frame(width: 27, height: 24)
        .offset(x: 13, y: 14)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func corner(_ name: String, alignment: Alignment) -> some View {
    Image("ui_guide_corner_\(name)_gold")
      .resizable().interpolation(.none)
      .frame(width: 14, height: 14)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
  }
}
