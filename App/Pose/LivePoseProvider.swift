import CoreGraphics
import SwiftUI

struct LivePoseProvider: PoseProvider {
  func snapshot(
    activeDivision: CGRect?,
    occlusions: [CGRect],
    size: CGSize,
    horizontalSizeClass: UserInterfaceSizeClass?
  ) -> PoseSnapshot {
    PoseSnapshot(
      pose: PoseDeriver.derive(activeDivision: activeDivision, horizontalSizeClass: horizontalSizeClass),
      division: activeDivision,
      occlusions: occlusions,
      size: size,
      isSimulated: false
    )
  }
}
