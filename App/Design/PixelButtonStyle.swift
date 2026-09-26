import SwiftUI

struct PixelButtonStyle: ButtonStyle {
  var kind: String = "button"
  var compact = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(BurrowTheme.ui(compact ? 16 : 19))
      .foregroundStyle(kind == "button_primary" || kind == "button_alert" ? BurrowTheme.paper : BurrowTheme.ink)
      .padding(.horizontal, compact ? 13 : 18)
      .padding(.vertical, compact ? 10 : 12)
      .frame(minHeight: 44)
      .background {
        NineSlice(name: kind, scale: 2)
          .shadow(color: BurrowTheme.ink.opacity(0.25), radius: 0, x: configuration.isPressed ? 0 : 3, y: configuration.isPressed ? 0 : 3)
      }
      .contentShape(Rectangle())
      .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
  }
}
