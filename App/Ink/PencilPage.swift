import SwiftUI
import PencilKit

struct PencilPage: UIViewRepresentable {
  var document: InkDocument
  var size: CGSize
  var readOnly: Bool

  func makeUIView(context: Context) -> PKCanvasView {
    let view = PKCanvasView()
    view.delegate = context.coordinator
    view.drawingPolicy = .anyInput
    view.backgroundColor = .clear
    view.isOpaque = false
    view.isScrollEnabled = false
    view.bounces = false
    view.accessibilityLabel = "Work page"
    view.accessibilityHint = "Write your working here. Fold the device to reveal Bunny's help."
    return view
  }

  func updateUIView(_ view: PKCanvasView, context: Context) {
    let coordinator = context.coordinator
    coordinator.document = document
    view.isUserInteractionEnabled = !readOnly && !document.isReplaying
    view.tool = document.tool == .pen
      ? PKInkingTool(.pen, color: UIColor(BurrowTheme.ink), width: max(1.5, size.width * 0.005))
      : PKEraserTool(.vector)
    if coordinator.revision != document.revision || coordinator.size != size {
      if document.isDrawing && coordinator.size != size {
        // Capture the live old-size stroke before changing the coordinate map.
        coordinator.canvasViewDrawingDidChange(view)
        view.drawingGestureRecognizer.isEnabled = false
        view.drawingGestureRecognizer.isEnabled = true
        document.isDrawing = false
        document.onStrokeEnd?()
      }
      coordinator.updating = true
      coordinator.size = size
      coordinator.revision = document.revision
      view.drawing = document.normalizedDrawing.transformed(using: CGAffineTransform(scaleX: size.width, y: size.height))
      coordinator.appliedDrawing = view.drawing
      coordinator.updating = false
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(document: document) }
  static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
    if coordinator.document.isDrawing {
      coordinator.canvasViewDrawingDidChange(uiView)
      coordinator.document.isDrawing = false
      coordinator.document.onStrokeEnd?()
    }
    uiView.delegate = nil
  }

  @MainActor final class Coordinator: NSObject, PKCanvasViewDelegate {
    var document: InkDocument
    var size = CGSize.zero
    var revision = -1
    var updating = false
    var appliedDrawing = PKDrawing()
    init(document: InkDocument) { self.document = document }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
      document.isDrawing = true
      document.undoStack.append(document.normalizedDrawing)
      document.onEdit?()
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      guard !updating, size.width > 0, size.height > 0 else { return }
      guard canvasView.drawing != appliedDrawing else { return }
      let normalized = canvasView.drawing.transformed(using: CGAffineTransform(scaleX: 1 / size.width, y: 1 / size.height))
      document.replace(with: normalized, userEdit: true)
      revision = document.revision
      appliedDrawing = canvasView.drawing
    }

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
      document.isDrawing = false
      document.onStrokeEnd?()
    }
  }
}
