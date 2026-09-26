import SwiftUI

/// Mirrors the tokens in extension/public/burrow.css.
enum Theme {
    static let ink = Color(hex: 0x3B2A23)
    static let cream = Color(hex: 0xFFF8E7)
    static let paper = Color(hex: 0xFFFDF5)
    static let teal = Color(hex: 0x2F8F83)
    static let tealDeep = Color(hex: 0x236E65)
    static let gold = Color(hex: 0xF2C14E)
    static let goldDeep = Color(hex: 0xB57F2C)
    static let red = Color(hex: 0xD9534F)
    static let muted = Color(hex: 0x7A6458)
    static let chalk = Color(hex: 0xF4F1E4)
    static let shadow = Color(red: 59 / 255, green: 42 / 255, blue: 35 / 255).opacity(0.25)

    static func pixel(_ size: CGFloat) -> Font { .custom("Pixelify Sans", size: size) }
    static func digits(_ size: CGFloat) -> Font { .custom("VT323", size: size) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
    init(rgba: [Double]) {
        self.init(red: rgba[0] / 255, green: rgba[1] / 255, blue: rgba[2] / 255, opacity: rgba.count > 3 ? rgba[3] / 255 : 1)
    }
}

extension View {
    /// The 3px hard drop shadow from burrow.css.
    func hardShadow(_ d: CGFloat = 3) -> some View {
        shadow(color: Theme.shadow, radius: 0, x: d, y: d)
    }
}
