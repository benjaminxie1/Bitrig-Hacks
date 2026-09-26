import UIKit

@MainActor
final class PixelArtStore {
  static let shared = PixelArtStore()
  let rabbit: CharacterManifest = BundledResource.decode("RabbitManifest")
  let scene: SceneManifest = BundledResource.decode("SceneManifest")
  let ui: UIManifest = BundledResource.decode("UIManifest")
  private var frames: [String: [CGImage]] = [:]

  private init() {
    for (name, state) in rabbit.states {
      let asset = "characters_rabbit_" + URL(fileURLWithPath: state.file).deletingPathExtension().lastPathComponent
      guard let image = UIImage(named: asset)?.cgImage else { continue }
      frames[name] = (0..<state.frames).compactMap { index in
        image.cropping(to: CGRect(x: index * rabbit.cell[0], y: 0, width: rabbit.cell[0], height: rabbit.cell[1]))
      }
    }
  }

  func frame(state: String, index: Int) -> CGImage? {
    guard let frames = frames[state], !frames.isEmpty else { return nil }
    return frames[min(max(index, 0), frames.count - 1)]
  }

  func scenePiece(_ name: String, palette: String) -> CGImage? {
    let key = palette + "/" + name
    if let cached = frames[key]?.first { return cached }
    guard let piece = scene.pieces[name],
          let atlas = UIImage(named: "scene_scene_" + palette)?.cgImage,
          let image = atlas.cropping(to: CGRect(x: piece.x, y: piece.y, width: piece.w, height: piece.h)) else { return nil }
    frames[key] = [image]
    return image
  }
}

struct SceneManifest: Decodable {
  var pieces: [String: Piece]
  var palettes: [String: [String: [Int]]]
  var skyBands: [String]
  var paletteHours: [String: Double]

  struct Piece: Decodable {
    var x: Int
    var y: Int
    var w: Int
    var h: Int
    var frames: Int
  }
}

struct UIManifest: Decodable {
  var pieces: [String: Piece]

  struct Piece: Decodable {
    var file: String
    var size: [Int]
    var slice: Slice
  }

  enum Slice: Decodable {
    case uniform(Int)
    case edges([Int])

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let value = try? container.decode(Int.self) { self = .uniform(value) }
      else { self = .edges(try container.decode([Int].self)) }
    }

    var values: [Int] {
      switch self {
      case .uniform(let value): [value, value, value, value]
      case .edges(let values): values
      }
    }
  }
}
