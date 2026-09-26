import Foundation

/// Each bundled drawing/photo must have this sidecar. Checkpoints let a replay
/// reveal only lines already written, never its final transcript in advance.
struct InkDemoAsset: Codable, Sendable {
  var id: String
  var title: String
  var problemID: String
  var kind: Kind
  var file: String
  var verified: Bool
  var checkpoints: [Checkpoint]
  var frames: [Frame]
  var continues: String? = nil

  enum Kind: String, Codable, Sendable { case drawing, photo }
  struct Checkpoint: Codable, Sendable {
    var time: Double
    var lines: [InkLine]
  }
  struct Frame: Codable, Sendable {
    var time: Double
    /// A full normalized PKDrawing snapshot preserves undo/eraser edits too.
    var drawing: Data
  }

  func truth(at time: Double) -> [InkLine]? {
    guard verified else { return nil }
    return checkpoints.last { $0.time <= time }?.lines ?? []
  }

  static func resolve(live: [InkLine], truth: [InkLine]?) -> [InkLine] {
    guard let truth else { return live }
    // Boxes come from the reviewed item as well as text. OCR segmentation can
    // otherwise move the ring even when its transcript happens to agree.
    return truth
  }
}
