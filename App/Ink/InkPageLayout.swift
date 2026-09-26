import CoreGraphics

/// One immutable page coordinate system survives every display and pose.
/// The flat page uses the inactive fold, so book folding never reallocates it.
struct InkPageLayout: Equatable {
  static let aspect = 1.4
  var pose: BurrowPose
  var paperRegion: CGRect
  var companionRegion: CGRect
  var page: CGRect
  var isHorizontal: Bool

  init(snapshot: PoseSnapshot) {
    pose = snapshot.pose
    let bounds = CGRect(origin: .zero, size: snapshot.size)
    let fold = snapshot.division ?? snapshot.inactiveDivision
    isHorizontal = fold.map { $0.width > $0.height } ?? false
    if pose == .closed {
      paperRegion = bounds
      companionRegion = .zero
    } else if let fold, isHorizontal {
      paperRegion = CGRect(x: 0, y: fold.maxY, width: bounds.width, height: max(0, bounds.maxY - fold.maxY))
      companionRegion = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, fold.minY))
    } else {
      let left = fold?.minX ?? bounds.midX - 9
      let right = fold?.maxX ?? bounds.midX + 9
      paperRegion = CGRect(x: 0, y: 0, width: max(0, left), height: bounds.height)
      companionRegion = CGRect(x: right, y: 0, width: max(0, bounds.maxX - right), height: bounds.height)
    }
    paperRegion = BurrowLayout.unoccluded(paperRegion, avoiding: snapshot.occlusions)
    companionRegion = BurrowLayout.unoccluded(companionRegion, avoiding: snapshot.occlusions)
    // The same vertical chrome allowance is used while flat and in book pose.
    // The drawing never resizes merely because the facing page becomes a stage.
    let reservedTop: CGFloat = pose == .closed ? 52 : 46
    let reservedBottom: CGFloat = pose == .closed ? 155 : isHorizontal ? 54 : 14
    let available = CGRect(x: paperRegion.minX + 12, y: paperRegion.minY + reservedTop,
      width: max(1, paperRegion.width - 24), height: max(1, paperRegion.height - reservedTop - reservedBottom))
    let width = min(available.width, available.height / Self.aspect)
    let height = width * Self.aspect
    page = CGRect(x: isHorizontal || pose == .closed ? available.midX - width / 2 : available.maxX - width,
                  y: available.minY, width: width, height: height)
  }

  func bunnyAnchor(mark: InkBox?) -> CGPoint {
    let scale = CGFloat(bunnyScale)
    if pose == .flat {
      return CGPoint(x: companionRegion.maxX - 38 * scale - 12, y: companionRegion.maxY - 16)
    }
    let target = mark?.inPage(page)
    if isHorizontal {
      let x = min(companionRegion.maxX - 36 * scale, max(companionRegion.minX + 36 * scale, target?.midX ?? companionRegion.midX))
      return CGPoint(x: x, y: companionRegion.maxY - 18)
    }
    // Align the rabbit's face with the marked line; feet remain at row 53.
    let faceY = min(companionRegion.maxY - 70, max(companionRegion.minY + 110, target?.midY ?? companionRegion.midY))
    return CGPoint(x: companionRegion.minX + 38 * scale + 12, y: faceY + 25 * scale)
  }

  var bunnyScale: Int {
    max(1, min(pose == .flat ? 2 : 3, Int(companionRegion.width / 150), Int(companionRegion.height / 170)))
  }
}
