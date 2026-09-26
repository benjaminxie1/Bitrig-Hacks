import CoreGraphics
import SwiftUI

enum PoseDeriver {
  static func derive(activeDivision: CGRect?, horizontalSizeClass: UserInterfaceSizeClass?) -> BurrowPose {
    if let activeDivision {
      return activeDivision.width > activeDivision.height ? .tabletop : .book
    }
    return horizontalSizeClass == .regular ? .flat : .closed
  }
}
