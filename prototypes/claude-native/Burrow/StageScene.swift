import SwiftUI

/// Geometry of Bunny's stage in source pixels, shared by the scene and the rabbit placement.
struct SceneGeometry {
    let rect: CGRect
    let s: Int

    init(rect: CGRect) {
        self.rect = rect
        s = max(2, min(Int(rect.height / 96), Int(rect.width / 150), 6))
    }

    var S: CGFloat { CGFloat(s) }
    var sw: Int { Int((rect.width / S).rounded(.up)) }
    var sh: Int { Int((rect.height / S).rounded(.up)) }
    var groundTop: Int { sh - 30 }
    var moundX: Int { max(4, sw / 2 - 150) }

    /// Where Bunny's feet go: on the grass just in front of his burrow.
    var feet: CGPoint {
        CGPoint(x: rect.minX + CGFloat(moundX + 112) * S, y: rect.minY + CGFloat(groundTop + 17) * S)
    }

    func point(_ x: Int, _ y: Int) -> CGPoint { CGPoint(x: CGFloat(x) * S, y: CGFloat(y) * S) }
}

/// A small Wonderland scene composed from scene/manifest.json pieces.
/// `parallax` (points) shifts the far layers as the hinge folds.
struct StageScene: View {
    let geo: SceneGeometry
    let parallax: CGFloat

    var body: some View {
        let art = ArtStore.shared
        ZStack(alignment: .topLeading) {
            // Sky: hard bands from the palette, pixel style.
            VStack(spacing: 0) {
                ForEach(Array(art.skyBands.enumerated()), id: \.offset) { _, c in c }
            }
            .frame(height: CGFloat(geo.groundTop - 4) * geo.S)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(art.skyBands.last ?? Theme.cream)

            layer(offset: parallax * 0.35) { ctx in
                draw(&ctx, "sun", x: geo.sw - 36, y: 10)
                draw(&ctx, "cloud_b", x: geo.sw / 5, y: 14)
                draw(&ctx, "cloud_a", x: geo.sw * 3 / 5, y: 8)
                draw(&ctx, "cloud_a", x: geo.sw - 90, y: 26)
                tile(&ctx, "hills_far", bottom: geo.groundTop - 3)
            }
            layer(offset: parallax * 0.7) { ctx in
                tile(&ctx, "hills_near", bottom: geo.groundTop + 1, shift: 37)
                draw(&ctx, "oak", x: geo.sw - 64, y: geo.groundTop - 58)
                draw(&ctx, "bush_a", x: geo.moundX + 150, y: geo.groundTop - 8)
            }
            layer(offset: 0) { ctx in
                // Grass
                var y = geo.groundTop
                while y < geo.sh + 16 {
                    tileRow(&ctx, "ground", y: y)
                    y += 16
                }
                draw(&ctx, "mound", x: geo.moundX, y: geo.groundTop - 25)
                draw(&ctx, "signpost", x: geo.sw - 40, y: geo.groundTop - 18)
                draw(&ctx, "path", x: geo.moundX + 50, y: geo.groundTop + 6)
                let flowers: [(String, Int, Int)] = [
                    ("flower_r", 18, 8), ("flower_y", 34, 14), ("flower_w", geo.moundX + 140, 12),
                    ("flower_y", geo.sw - 70, 16), ("flower_r", geo.sw - 22, 10), ("tuft_a", 60, 20),
                    ("tuft_a", geo.sw / 2 + 40, 22), ("flower_s", geo.sw / 2 + 70, 9), ("tuft_a", geo.sw - 110, 7),
                ]
                for (name, fx, fy) in flowers { draw(&ctx, name, x: fx, y: geo.groundTop + fy) }
            }
        }
        .frame(width: geo.rect.width, height: geo.rect.height, alignment: .topLeading)
        .clipped()
    }

    private func layer(offset: CGFloat, _ paint: @escaping (inout GraphicsContext) -> Void) -> some View {
        Canvas { ctx, _ in paint(&ctx) }
            .frame(width: geo.rect.width + 80, height: geo.rect.height)
            .offset(x: -40 + offset)
    }

    private func draw(_ ctx: inout GraphicsContext, _ name: String, x: Int, y: Int, frame: Int = 0) {
        guard let cg = ArtStore.shared.scenePiece(name, frame: frame) else { return }
        let p = geo.point(x, y)
        ctx.draw(Image(decorative: cg, scale: 1).interpolation(.none),
                 in: CGRect(x: p.x + 40, y: p.y, width: CGFloat(cg.width) * geo.S, height: CGFloat(cg.height) * geo.S))
    }

    private func tile(_ ctx: inout GraphicsContext, _ name: String, bottom: Int, shift: Int = 0) {
        guard let p = ArtStore.shared.scene.pieces[name] else { return }
        var x = -shift - 20
        while x < geo.sw + 40 {
            draw(&ctx, name, x: x, y: bottom - p.h)
            x += p.w
        }
    }

    private func tileRow(_ ctx: inout GraphicsContext, _ name: String, y: Int) {
        guard let p = ArtStore.shared.scene.pieces[name] else { return }
        var x = -20
        while x < geo.sw + 40 {
            draw(&ctx, name, x: x, y: y)
            x += p.w
        }
    }
}
