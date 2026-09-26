import SwiftUI

/// Draws the rabbit's current frame plus blink/mouth overlays (offset by head_dy)
/// at a whole-number scale with nearest-neighbour sampling.
struct SpriteView: View {
    let player: SpritePlayer
    let scale: Int

    var body: some View {
        let m = player.manifest
        let p = player.picture
        let s = CGFloat(scale)
        let size = CGSize(width: CGFloat(m.cellWidth) * s, height: CGFloat(m.cellHeight) * s)
        ZStack(alignment: .topLeading) {
            if !p.hidden {
                cell(p.state, p.frame, size)
                if p.mouth >= 0 { cell("overlay_mouth", p.mouth, size).offset(y: CGFloat(p.headDy) * s) }
                if p.blink >= 0 { cell("overlay_blink", p.blink, size).offset(y: CGFloat(p.headDy) * s) }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func cell(_ state: String, _ frame: Int, _ size: CGSize) -> some View {
        let m = player.manifest
        if let def = m.states[state],
           let cg = ArtStore.shared.crop("characters/rabbit/" + def.file,
                                         CGRect(x: frame * m.cellWidth, y: 0, width: m.cellWidth, height: m.cellHeight)) {
            Image(decorative: cg, scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: size.width, height: size.height)
        }
    }
}

extension SpritePlayer {
    /// Feet end at row 53 of the 64x58 cell; anchor bottom-center there.
    static let feetRow: CGFloat = 53
}

/// A 9-slice piece from ui/manifest.json, stretched with crisp edges.
struct NineSlice: View {
    let piece: String
    var scale: Int = 3

    var body: some View {
        let p = ArtStore.shared.ui.pieces[piece]!
        let s = CGFloat(scale)
        let i = p.insets
        Image(uiImage: ArtStore.shared.upscaled("ui/" + p.file, by: scale))
            .resizable(capInsets: EdgeInsets(top: CGFloat(i[0]) * s, leading: CGFloat(i[3]) * s,
                                             bottom: CGFloat(i[2]) * s, trailing: CGFloat(i[1]) * s),
                       resizingMode: .stretch)
            .interpolation(.none)
    }
}

/// A single non-sliced pixel image at a whole-number scale.
struct PixelImage: View {
    let path: String
    var scale: Int = 3

    var body: some View {
        if let cg = ArtStore.shared.image(path) {
            Image(decorative: cg, scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: CGFloat(cg.width * scale), height: CGFloat(cg.height * scale))
        }
    }
}

/// Button style drawn with the repo's 9-slice buttons.
struct PixelButtonStyle: ButtonStyle {
    var piece = "button"
    var scale = 3
    var textColor = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(textColor)
            .background(NineSlice(piece: piece, scale: scale))
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.06 : 0)
    }
}

/// Gold corner brackets + a bobbing paw: Bunny's "look here" that never crosses the fold.
struct GuideBrackets: ViewModifier {
    let active: Bool
    var scale = 3

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                GeometryReader { g in
                    let pad: CGFloat = 8
                    ZStack {
                        corner("tl").position(x: -pad + 10, y: -pad + 10)
                        corner("tr").position(x: g.size.width + pad - 10, y: -pad + 10)
                        corner("bl").position(x: -pad + 10, y: g.size.height + pad - 10)
                        corner("br").position(x: g.size.width + pad - 10, y: g.size.height + pad - 10)
                        PawMarker(scale: scale).position(x: g.size.width / 2, y: -pad - 22)
                    }
                }
                .allowsHitTesting(false)
                .transition(.scale(scale: 1.3).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.4), value: active)
    }

    private func corner(_ c: String) -> some View {
        PixelImage(path: "ui/guide/corner_\(c)_gold.png", scale: scale)
    }
}

private struct PawMarker: View {
    let scale: Int
    @State private var bob = false

    var body: some View {
        PixelImage(path: "ui/guide/paw.png", scale: scale)
            .offset(y: bob ? -6 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { bob = true }
            }
    }
}

extension View {
    func guide(_ active: Bool, scale: Int = 3) -> some View { modifier(GuideBrackets(active: active, scale: scale)) }
}
