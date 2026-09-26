import CoreGraphics
import SwiftUI

struct SimulatedPoseProvider: PoseProvider {
  var pose: BurrowPose

  func snapshot(
    activeDivision: CGRect?,
    occlusions: [CGRect],
    size: CGSize,
    horizontalSizeClass: UserInterfaceSizeClass?
  ) -> PoseSnapshot {
    let gap: CGFloat = 18
    let division: CGRect? = switch pose {
    case .tabletop:
      CGRect(x: 0, y: size.height / 2 - gap / 2, width: size.width, height: gap)
    case .book:
      CGRect(x: size.width / 2 - gap / 2, y: 0, width: gap, height: size.height)
    case .flat, .closed:
      nil
    }
    return PoseSnapshot(pose: pose, division: division, occlusions: occlusions, size: size, isSimulated: true,
      inactiveDivision: division ?? (pose == .flat ? CGRect(x: size.width / 2 - gap / 2, y: 0, width: gap, height: size.height) : nil))
  }
}
