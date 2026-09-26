import Foundation
import PencilKit
import Observation

@MainActor
@Observable
final class InkRecorder {
  var isRecording = false
  var elapsed = 0.0
  var frames: [InkDemoAsset.Frame] = []
  var checkpoints: [InkDemoAsset.Checkpoint] = []
  var lastSavedURL: URL?
  var message: String?
  var replayAsset: InkDemoAsset?
  var replayTime = 0.0
  var onCheckpoint: (() -> Void)?
  private var nextFrame = 0
  private var strokeStart = 0.0
  private var replayFrom = PKDrawing()
  private var replayTo = PKDrawing()
  private var replayDuration = 0.0
  private var replayTruthTime = 0.0

  func begin(document: InkDocument) {
    isRecording = true
    elapsed = 0
    frames = [.init(time: 0, drawing: document.normalizedDrawing.dataRepresentation())]
    checkpoints = []
    message = "Recording ink. Draw, pause between lines, then choose Stop recording ink."
  }

  func capture(document: InkDocument) {
    guard isRecording else { return }
    frames.append(.init(time: elapsed, drawing: document.normalizedDrawing.dataRepresentation()))
  }

  func recordRead(_ lines: [InkLine]) {
    guard isRecording else { return }
    checkpoints.append(.init(time: frames.last?.time ?? elapsed, lines: lines))
  }

  func finish(document: InkDocument, problemID: String) throws {
    guard isRecording else { return }
    capture(document: document)
    isRecording = false
    let id = "ink-\(Int(Date.now.timeIntervalSince1970))"
    let directory = Self.directory.appendingPathComponent(id, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let filename = "\(id).pkdrawing"
    try document.normalizedDrawing.dataRepresentation().write(to: directory.appendingPathComponent(filename), options: .atomic)
    let asset = InkDemoAsset(id: id, title: "My recorded ink", problemID: problemID,
      kind: .drawing, file: filename, verified: false, checkpoints: checkpoints, frames: frames)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(asset).write(to: directory.appendingPathComponent("\(id).ink.json"), options: .atomic)
    lastSavedURL = directory
    message = "Ink saved. Review its transcript and boxes before bundling it as ground truth."
  }

  static var directory: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("InkRecordings", isDirectory: true)
  }

  static func assets() -> [(InkDemoAsset, URL)] {
    var urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
    if let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) {
      urls += enumerator.compactMap { $0 as? URL }.filter { $0.lastPathComponent.hasSuffix(".ink.json") }
    }
    return urls.filter { $0.lastPathComponent.hasSuffix(".ink.json") }.compactMap { url in
      guard let data = try? Data(contentsOf: url), let asset = try? JSONDecoder().decode(InkDemoAsset.self, from: data) else { return nil }
      return (asset, url.deletingLastPathComponent())
    }.sorted { $0.0.id < $1.0.id }
  }

  func startReplay(_ asset: InkDemoAsset, document: InkDocument) {
    guard asset.kind == .drawing, !asset.frames.isEmpty else { return }
    isRecording = false
    replayAsset = asset
    replayTime = 0
    nextFrame = 0
    strokeStart = 0
    replayDuration = 0
    document.clear()
    document.isReplaying = true
    document.groundTruthSource = asset.verified ? asset.id : nil
    advance(document: document)
  }

  func stopReplay(document: InkDocument) {
    replayAsset = nil
    document.isReplaying = false
  }

  func tick(_ dt: Double, document: InkDocument) {
    if isRecording { elapsed += dt }
    guard let asset = replayAsset else { return }
    replayTime += dt
    let progress = min(1, (replayTime - strokeStart) / max(0.01, replayDuration))
    if replayTo.strokes.count > replayFrom.strokes.count, progress < 1 {
      var strokes = replayFrom.strokes
      let additions = Array(replayTo.strokes.dropFirst(replayFrom.strokes.count))
      let total = additions.reduce(0) { $0 + max(0.1, $1.path.last?.timeOffset ?? 0.1) }
      var budget = total * progress
      for var stroke in additions {
        let duration = max(0.1, stroke.path.last?.timeOffset ?? 0.1)
        if budget >= duration { strokes.append(stroke); budget -= duration }
        else {
          let points = stroke.path.filter { $0.timeOffset <= budget }
          if points.count > 1 {
            stroke.path = PKStrokePath(controlPoints: points, creationDate: stroke.path.creationDate)
            strokes.append(stroke)
          }
          break
        }
      }
      document.replace(with: PKDrawing(strokes: strokes), userEdit: false)
    } else if progress >= 1 {
      document.replace(with: replayTo, userEdit: false)
      document.groundTruth = asset.truth(at: replayTruthTime)
      onCheckpoint?()
      if nextFrame >= asset.frames.count {
        replayAsset = nil
        document.isReplaying = false
        document.onStrokeEnd?()
      } else { advance(document: document) }
    }
  }

  private func advance(document: InkDocument) {
    guard let asset = replayAsset, nextFrame < asset.frames.count else { return }
    let frame = asset.frames[nextFrame]
    replayFrom = document.normalizedDrawing
    replayTo = (try? PKDrawing(data: frame.drawing)) ?? replayFrom
    let previousTime = nextFrame > 0 ? asset.frames[nextFrame - 1].time : 0
    // Preserve writing time, but cap pauses for a natural, repeatable take.
    replayDuration = min(3.0, max(0.12, frame.time - previousTime))
    strokeStart = replayTime
    replayTruthTime = frame.time
    nextFrame += 1
  }
}
