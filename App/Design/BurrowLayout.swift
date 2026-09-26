import SwiftUI

/// All rectangles are local to the root GeometryReader's safe-area bounds.
/// Reserved frames already include system margins; do not inset them again.
struct BurrowLayout: Equatable {
  var pose: BurrowPose
  var workspace: CGRect
  var stage: CGRect
  var bunnyAnchor: CGPoint
  var bunnyScale: Int
  var sidebarWidth: CGFloat

  init(snapshot: PoseSnapshot) {
    pose = snapshot.pose
    let bounds = CGRect(origin: .zero, size: snapshot.size)
    var work = bounds
    var scene = CGRect.zero
    switch pose {
    case .tabletop:
      if let fold = snapshot.division {
        scene = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, fold.minY))
        work = CGRect(x: 0, y: fold.maxY, width: bounds.width, height: max(0, bounds.maxY - fold.maxY))
      }
    case .book:
      if let fold = snapshot.division {
        work = CGRect(x: 0, y: 0, width: max(0, fold.minX), height: bounds.height)
        scene = CGRect(x: fold.maxX, y: 0, width: max(0, bounds.maxX - fold.maxX), height: bounds.height)
      }
    case .flat, .closed: break
    }
    workspace = Self.unoccluded(work, avoiding: snapshot.occlusions)
    stage = Self.unoccluded(scene, avoiding: snapshot.occlusions)
    sidebarWidth = pose == .flat && workspace.width >= 580 ? min(180, workspace.width * 0.25) : 0
    switch pose {
    case .tabletop:
      bunnyScale = max(1, min(4, Int(stage.height / 85), Int(stage.width / 210)))
      bunnyAnchor = CGPoint(x: stage.minX + stage.width * 0.24, y: stage.maxY - 20)
    case .book:
      bunnyScale = max(1, min(4, Int(stage.height / 140), Int(stage.width / 80)))
      bunnyAnchor = CGPoint(x: stage.midX, y: max(stage.minY + CGFloat(bunnyScale * 53), stage.maxY - 220))
    case .flat:
      bunnyScale = max(1, min(2, Int(workspace.height / 220)))
      bunnyAnchor = CGPoint(x: workspace.maxX - CGFloat(bunnyScale * 36) - 24, y: workspace.maxY - 22)
    case .closed:
      bunnyScale = max(1, min(2, Int(workspace.height / 230)))
      bunnyAnchor = CGPoint(x: workspace.maxX - CGFloat(bunnyScale * 34) - 12, y: workspace.maxY - 16)
    }
    bunnyAnchor.x = bunnyAnchor.x.rounded()
    bunnyAnchor.y = bunnyAnchor.y.rounded()
  }

  static func unoccluded(_ rect: CGRect, avoiding occlusions: [CGRect]) -> CGRect {
    occlusions.reduce(rect) { current, obstruction in
      let overlap = current.intersection(obstruction)
      guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return current }
      let candidates = [
        CGRect(x: current.minX, y: current.minY, width: current.width, height: max(0, overlap.minY - current.minY)),
        CGRect(x: current.minX, y: overlap.maxY, width: current.width, height: max(0, current.maxY - overlap.maxY)),
        CGRect(x: current.minX, y: current.minY, width: max(0, overlap.minX - current.minX), height: current.height),
        CGRect(x: overlap.maxX, y: current.minY, width: max(0, current.maxX - overlap.maxX), height: current.height)
      ]
      return candidates.max { $0.width * $0.height < $1.width * $1.height } ?? current
    }
  }
}
