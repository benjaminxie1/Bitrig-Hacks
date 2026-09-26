import SwiftUI

enum BurrowTheme {
  static let ink = Color(hex: 0x3B2A23)
  static let cream = Color(hex: 0xFFF8E7)
  static let paper = Color(hex: 0xFFFDF5)
  static let teal = Color(hex: 0x2F8F83)
  static let tealDeep = Color(hex: 0x236E65)
  static let gold = Color(hex: 0xF2C14E)
  static let goldDeep = Color(hex: 0xB57F2C)
  static let red = Color(hex: 0xD9534F)
  static let muted = Color(hex: 0x7A6458)

  static func ui(_ size: CGFloat) -> Font {
    .custom("PixelifySans-Regular", size: size, relativeTo: .body)
  }

  static func digits(_ size: CGFloat) -> Font {
    .custom("VT323-Regular", size: size, relativeTo: .title)
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255
    )
  }
}
