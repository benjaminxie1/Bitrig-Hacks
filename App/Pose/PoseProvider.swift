import CoreGraphics
import SwiftUI

protocol PoseProvider {
  func snapshot(
    activeDivision: CGRect?,
    occlusions: [CGRect],
    size: CGSize,
    horizontalSizeClass: UserInterfaceSizeClass?
  ) -> PoseSnapshot
}
