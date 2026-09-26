import PencilKit
import UIKit
import Observation

@MainActor
@Observable
final class InkDocument {
  static let renderSize = CGSize(width: 1000, height: 1400)
  /// PKDrawing transformed into a 1 × 1 page. Points and brush widths travel
  /// together through inverse transforms; display sizing never rewrites ink.
  var normalizedDrawing = PKDrawing()
  var photo: UIImage?
  var tool = InkTool.pen
  var revision = 0
  var isDrawing = false
  var isReplaying = false
  var groundTruth: [InkLine]?
  var groundTruthSource: String?
  var undoStack: [PKDrawing] = []
  var onEdit: (() -> Void)?
  var onStrokeEnd: (() -> Void)?

  var canUndo: Bool { !undoStack.isEmpty && !isReplaying }

  func replace(with drawing: PKDrawing, userEdit: Bool) {
    normalizedDrawing = drawing
    revision += 1
    if userEdit {
      // Truth applies only to the exact bundled page, never subsequent user ink.
      groundTruth = nil
      groundTruthSource = nil
      onEdit?()
    }
  }

  func undo() {
    guard let previous = undoStack.popLast() else { return }
    replace(with: previous, userEdit: true)
    onStrokeEnd?()
  }

  func clear() {
    normalizedDrawing = PKDrawing()
    photo = nil
    groundTruth = nil
    groundTruthSource = nil
    undoStack = []
    revision += 1
  }

  func image() -> CGImage? {
    let size = Self.renderSize
    let drawing = normalizedDrawing.transformed(using: CGAffineTransform(scaleX: size.width, y: size.height))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    var result: CGImage?
    UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
      let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        if let photo {
          let frame = Self.photoRect(imageSize: photo.size, pageSize: size)
          photo.draw(in: frame)
        }
        drawing.image(from: CGRect(origin: .zero, size: size), scale: 1).draw(at: .zero)
      }
      result = image.cgImage
    }
    return result
  }

  static func photoRect(imageSize: CGSize, pageSize: CGSize) -> CGRect {
    let scale = min(pageSize.width / max(1, imageSize.width), pageSize.height / max(1, imageSize.height))
    let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    return CGRect(x: (pageSize.width - size.width) / 2, y: (pageSize.height - size.height) / 2,
                  width: size.width, height: size.height)
  }
}

enum InkTool: String, CaseIterable, Identifiable {
  case pen, eraser
  var id: Self { self }
  var title: String { rawValue.capitalized }
}
