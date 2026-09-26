import CoreGraphics

struct PoseSnapshot: Equatable {
  var pose: BurrowPose
  var division: CGRect?
  var occlusions: [CGRect]
  var size: CGSize
  var isSimulated: Bool
  var inactiveDivision: CGRect? = nil
}
