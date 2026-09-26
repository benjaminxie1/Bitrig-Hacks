import SwiftUI

struct NumberPad: View {
  var session: PracticeSession
  var compact = false
  private let rows = [["7", "8", "9", "⌫"], ["4", "5", "6", "−"], ["1", "2", "3", "/"]]

  var body: some View {
    Grid(horizontalSpacing: 6, verticalSpacing: 6) {
      ForEach(rows.indices, id: \.self) { row in
        GridRow {
          ForEach(rows[row], id: \.self) { key in keyButton(key) }
        }
      }
      GridRow {
        keyButton("0").gridCellColumns(2)
        Button { session.check() } label: {
          Text("Check")
            .font(BurrowTheme.ui(19))
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 48)
        }
        .buttonStyle(PadButtonStyle(primary: true))
        .gridCellColumns(2)
        .accessibilityIdentifier("check")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Number pad")
  }

  private func keyButton(_ key: String) -> some View {
    Button { session.enter(key) } label: {
      Text(key)
        .font(key == "⌫" ? BurrowTheme.ui(23) : BurrowTheme.digits(30))
        .frame(maxWidth: .infinity, minHeight: compact ? 44 : 48)
    }
    .buttonStyle(PadButtonStyle())
    .accessibilityLabel(key == "⌫" ? "Backspace" : key == "−" ? "Minus" : key == "/" ? "Fraction bar" : key)
    .accessibilityIdentifier("key-\(key)")
  }
}

private struct PadButtonStyle: ButtonStyle {
  var primary = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(primary ? BurrowTheme.paper : BurrowTheme.ink)
      .background {
        NineSlice(name: primary ? "button_primary" : "button", scale: 2)
          .shadow(color: BurrowTheme.ink.opacity(0.22), radius: 0, x: configuration.isPressed ? 0 : 3, y: configuration.isPressed ? 0 : 3)
      }
      .contentShape(Rectangle())
      .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? 2 : 0)
  }
}
