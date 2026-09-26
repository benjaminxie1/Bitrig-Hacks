import SwiftUI
import UIKit

/// Loads the Burrow art straight from the bundled `Art` folder (a copy of extension/public),
/// so the manifests are read at runtime exactly like the extension does.
final class ArtStore {
    static let shared = ArtStore()

    let root: URL
    let rabbit: CharacterManifest
    let ui: UIManifest
    let scene: SceneManifest

    private var images: [String: CGImage] = [:]
    private var crops: [String: CGImage] = [:]
    private var upscaled: [String: UIImage] = [:]

    private init() {
        let root = Bundle.main.url(forResource: "Art", withExtension: nil)!
        self.root = root
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        func load<T: Decodable>(_ path: String) -> T {
            let data = try! Data(contentsOf: root.appending(path: path))
            return try! decoder.decode(T.self, from: data)
        }
        rabbit = load("characters/rabbit/manifest.json")
        ui = load("ui/manifest.json")
        scene = load("scene/manifest.json")
    }

    func image(_ path: String) -> CGImage? {
        if let hit = images[path] { return hit }
        guard let img = UIImage(contentsOfFile: root.appending(path: path).path)?.cgImage else { return nil }
        images[path] = img
        return img
    }

    func crop(_ path: String, _ rect: CGRect) -> CGImage? {
        let key = "\(path)#\(rect)"
        if let hit = crops[key] { return hit }
        guard let img = image(path)?.cropping(to: rect) else { return nil }
        crops[key] = img
        return img
    }

    /// Nearest-neighbour upscale at render time so resizable 9-slices stay crisp.
    func upscaled(_ path: String, by scale: Int) -> UIImage {
        let key = "\(path)@\(scale)"
        if let hit = upscaled[key] { return hit }
        guard let cg = image(path) else { return UIImage() }
        let size = CGSize(width: cg.width * scale, height: cg.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let out = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: size))
        }
        upscaled[key] = out
        return out
    }

    // MARK: Scene

    var timeOfDay: String {
        if AppConfig.isRecording { return "day" }
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case 5..<10: return "morning"
        case 10..<17: return "day"
        case 17..<20: return "evening"
        default: return "night"
        }
    }

    func scenePiece(_ name: String, frame: Int = 0) -> CGImage? {
        guard let p = scene.pieces[name], let file = scene.atlas.files[timeOfDay] else { return nil }
        return crop("scene/" + file, CGRect(x: p.x + frame * p.w, y: p.y, width: p.w, height: p.h))
    }

    var skyBands: [Color] {
        let palette = scene.palettes[timeOfDay] ?? [:]
        return scene.skyBands.compactMap { palette[$0].map { Color(rgba: $0) } }
    }
}

// MARK: - Manifests

nonisolated struct CharacterManifest: Decodable, Sendable {
    let cell: [Int]
    let jumpSequence: JumpSequence
    let idleVariantGap: [Double]?
    let states: [String: StateDef]

    var cellWidth: Int { cell[0] }
    var cellHeight: Int { cell[1] }

    struct JumpSequence: Decodable, Sendable {
        let sending: [JumpStep]
        let receiving: [JumpStep]
    }
}

nonisolated struct JumpStep: Decodable, Sendable {
    let state: String
    var reverse: Bool? = nil
    var loop: Bool? = nil
}

nonisolated struct StateDef: Decodable, Sendable {
    let file: String
    let frames: Int
    let fps: Double
    let loop: Bool
    let headDy: [Int]?
    let overlays: [String]?
    let hold: Bool?
    let enter: String?
    let exit: String?
    let variants: [Variant]?

    struct Variant: Decodable, Sendable {
        let state: String
        let weight: Double
    }
}

nonisolated struct UIManifest: Decodable, Sendable {
    let pieces: [String: Piece]

    struct Piece: Decodable, Sendable {
        let file: String
        let size: [Int]
        /// top, right, bottom, left
        let insets: [Int]

        enum CodingKeys: String, CodingKey { case file, size, slice }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            file = try c.decode(String.self, forKey: .file)
            size = try c.decode([Int].self, forKey: .size)
            if let one = try? c.decode(Int.self, forKey: .slice) {
                insets = [one, one, one, one]
            } else {
                insets = try c.decode([Int].self, forKey: .slice)
            }
        }
    }
}

nonisolated struct SceneManifest: Decodable, Sendable {
    let atlas: Atlas
    let pieces: [String: Piece]
    let skyBands: [String]
    let palettes: [String: [String: [Double]]]

    struct Atlas: Decodable, Sendable {
        let files: [String: String]
    }

    struct Piece: Decodable, Sendable {
        let x: Int, y: Int, w: Int, h: Int, frames: Int
    }
}
