import Observation
import SwiftUI
import OSLog

@available(iOS 27.1, *)
@MainActor
@Observable
final class PoseModel {
  var overridePose: BurrowPose?
  var hinge: DeviceHinge?
  var foldProgress = 0.0
  private var targetFoldProgress = 0.0
  private var receivedHingeContext = false
  private let logger = Logger(subsystem: "Burrow", category: "Pose")
  let recording: Bool

  init(arguments: [String] = ProcessInfo.processInfo.arguments) {
    recording = arguments.contains("-recording")
    if let index = arguments.firstIndex(of: "-pose"), arguments.indices.contains(index + 1) {
      overridePose = BurrowPose(rawValue: arguments[index + 1])
    }
  }

  func snapshot(
    activeDivision: CGRect?,
    allDivision: CGRect?,
    occlusions: [CGRect],
    size: CGSize,
    horizontalSizeClass: UserInterfaceSizeClass?
  ) -> PoseSnapshot {
    if let overridePose {
      return SimulatedPoseProvider(pose: overridePose).snapshot(
        activeDivision: activeDivision,
        occlusions: occlusions,
        size: size,
        horizontalSizeClass: horizontalSizeClass
      )
    }
    // A nil context is meaningful only after the platform sends one. Before
    // then, let fresh reserved regions determine the first layout.
    if receivedHingeContext && hinge == nil && activeDivision == nil && allDivision == nil {
      return SimulatedPoseProvider(pose: horizontalSizeClass == .regular ? .flat : .closed)
        .snapshot(activeDivision: nil, occlusions: occlusions, size: size, horizontalSizeClass: horizontalSizeClass)
    }
    var result = LivePoseProvider().snapshot(
      activeDivision: activeDivision,
      occlusions: occlusions,
      size: size,
      horizontalSizeClass: horizontalSizeClass
    )
    result.inactiveDivision = allDivision
    return result
  }

  func receiveHinge(old: DeviceHinge?, new: DeviceHinge?) {
    receivedHingeContext = true
    hinge = new
    guard let new else { return }
    targetFoldProgress = min(max((180 - new.angle.degrees) / 180, 0), 1)
    logger.info("Hinge raw angle=\(new.angle.degrees, privacy: .public) status=\(String(describing: new.status), privacy: .public)")
  }

  func tick(_ dt: Double, reducedMotion: Bool) {
    let target: Double
    if let overridePose { target = overridePose == .flat ? 0 : overridePose == .closed ? 1 : 0.5 }
    else { target = targetFoldProgress }
    // Time-based smoothing handles a single simulator jump and live samples.
    foldProgress = reducedMotion ? target : foldProgress + (target - foldProgress) * (1 - exp(-dt * 12))
    if abs(foldProgress - target) < 0.001 { foldProgress = target }
  }
}
