import SwiftUI

enum Pose: String, CaseIterable, Identifiable {
    case flat, tabletop, book, closed
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Pure pose derivation from reserved regions. Never from interface orientation.
enum PoseLogic {
    /// - Parameters:
    ///   - division: frame of the *active* division region (margins included), if any.
    ///   - regularWidth: horizontal size class is `.regular`.
    static func derive(division: CGRect?, regularWidth: Bool) -> Pose {
        if let d = division {
            return d.width > d.height ? .tabletop : .book
        }
        return regularWidth ? .flat : .closed
    }

    /// A stand-in division frame for the simulated provider (Previews, `-pose`, debug menu).
    static func syntheticDivision(for pose: Pose, in size: CGSize) -> CGRect? {
        switch pose {
        case .tabletop: CGRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
        case .book: CGRect(x: size.width / 2 - 20, y: 0, width: 40, height: size.height)
        default: nil
        }
    }
}

/// Screen regions for a pose, in the root (full-screen) coordinate space.
/// Nothing is ever placed inside `division`.
struct PoseLayout {
    let pose: Pose
    let size: CGSize
    let safe: EdgeInsets
    let division: CGRect?

    /// Region for Bunny's stage (top in tabletop, trailing in book).
    var stage: CGRect {
        guard let d = division else { return .zero }
        switch pose {
        case .tabletop: return CGRect(x: 0, y: 0, width: size.width, height: d.minY)
        case .book: return CGRect(x: d.maxX, y: 0, width: size.width - d.maxX, height: size.height)
        default: return .zero
        }
    }

    /// Region for the problem + pad (bottom in tabletop, leading in book, everything otherwise).
    var work: CGRect {
        guard let d = division else { return CGRect(origin: .zero, size: size) }
        switch pose {
        case .tabletop: return CGRect(x: 0, y: d.maxY, width: size.width, height: size.height - d.maxY)
        case .book: return CGRect(x: 0, y: 0, width: d.minX, height: size.height)
        default: return CGRect(origin: .zero, size: size)
        }
    }

    /// `rect` minus whichever safe-area insets it touches (insets can be asymmetric).
    func safeInset(_ rect: CGRect) -> CGRect {
        let top = rect.minY <= 0.5 ? safe.top : 0
        let bottom = rect.maxY >= size.height - 0.5 ? safe.bottom : 0
        let leading = rect.minX <= 0.5 ? safe.leading : 0
        let trailing = rect.maxX >= size.width - 0.5 ? safe.trailing : 0
        return CGRect(x: rect.minX + leading, y: rect.minY + top,
                      width: max(0, rect.width - leading - trailing), height: max(0, rect.height - top - bottom))
    }
}

/// Live pose + hinge state. The simulated override powers `-pose` and the debug menu.
@Observable
final class PoseModel {
    var override: Pose? = AppConfig.forcedPose
    var hingeAvailable = false
    var hingeStatus: DeviceHinge.Status?
    /// Hinge angle in degrees (180 = flat). Animated by the view when the simulator jumps.
    var angle: Double = 180

    var statusTitle: String {
        guard let s = hingeStatus else { return "no hinge" }
        switch s {
        case .closed: return "closed"
        case .partiallyOpen: return "partially open"
        case .fullyOpen: return "fully open"
        default: return "unknown"
        }
    }
}
