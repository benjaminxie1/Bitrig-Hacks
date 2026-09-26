import SwiftUI

struct RootView: View {
    @State private var problems: ProblemSetModel
    @State private var coach: Coach
    @State private var poseModel = PoseModel()
    @State private var showDebug = false
    @State private var lastStageFeet: CGPoint?
    @State private var lastStageScale = 4
    @Environment(\.horizontalSizeClass) private var hSize

    init() {
        let p = ProblemSetModel()
        _problems = State(initialValue: p)
        _coach = State(initialValue: Coach(problems: p))
    }

    var body: some View {
        GeometryReader { proxy in
            // Reserved regions arrive after the first layout pass: read them every pass, never cache.
            let liveDivision = proxy.reservedRegions(kind: .division).first(where: \.isActive)?.frame
            let occlusions = proxy.reservedRegions(kind: .occlusion)
            let livePose = PoseLogic.derive(division: liveDivision, regularWidth: hSize == .regular)
            let pose = poseModel.override ?? livePose
            let division = poseModel.override == nil ? liveDivision : PoseLogic.syntheticDivision(for: pose, in: proxy.size)
            let layout = PoseLayout(pose: pose, size: proxy.size, safe: proxy.safeAreaInsets, division: division)
            let topClear = occlusions.filter { $0.frame.minY < 1 }.map(\.frame.maxY).max() ?? 0

            ZStack(alignment: .topLeading) {
                Theme.cream.ignoresSafeArea()
                content(layout, topClear: topClear)
                BunnyLayer(coach: coach, layout: layout, stage: stageGeometry(layout),
                           lastStageFeet: lastStageFeet, lastStageScale: lastStageScale, topClear: topClear)
                if showDebug && !AppConfig.isRecording {
                    DebugMenu(poseModel: poseModel, coach: coach, livePose: livePose, pose: pose,
                              division: liveDivision, size: proxy.size, show: $showDebug)
                }
            }
            .animation(.smooth(duration: 0.45), value: pose)
            .onChange(of: pose, initial: true) { old, new in
                coach.poseChanged(from: old == new ? nil : old, to: new)
            }
            .onChange(of: stageGeometry(layout)?.feet) { _, feet in
                if let feet, let g = stageGeometry(layout) {
                    lastStageFeet = feet
                    lastStageScale = BunnyLayer.stageScale(g)
                }
            }
            .onChange(of: hSize == .compact && poseModel.hingeAvailable && poseModel.hingeStatus != .closed, initial: true) { _, v in
                coach.splitView = v
            }
        }
        .ignoresSafeArea()
        .onHingeChange { old, new in
            poseModel.hingeAvailable = new.hinge != nil
            guard let hinge = new.hinge else { return }
            poseModel.hingeStatus = hinge.status
            // The simulator may jump straight to the final angle; animate it ourselves.
            withAnimation(.easeInOut(duration: 0.6)) { poseModel.angle = hinge.angle.degrees }
            if old.hinge?.status == .fullyOpen && hinge.status == .partiallyOpen {
                coach.hingeCue()
            }
        }
        .onAppear { coach.greet() }
        .persistentSystemOverlays(.hidden)
    }

    private func stageGeometry(_ layout: PoseLayout) -> SceneGeometry? {
        guard layout.pose == .tabletop || layout.pose == .book else { return nil }
        return SceneGeometry(rect: layout.stage)
    }

    // MARK: Layouts per pose

    @ViewBuilder
    private func content(_ layout: PoseLayout, topClear: CGFloat) -> some View {
        switch layout.pose {
        case .flat: flat(layout, topClear: topClear)
        case .tabletop: tabletop(layout)
        case .book: book(layout)
        case .closed: closed(layout, topClear: topClear)
        }
    }

    private func header(compact: Bool = false) -> some View {
        HeaderBar(problems: problems, compact: compact) {
            if !AppConfig.isRecording { showDebug.toggle() }
        }
    }

    private func pad(_ h: CGFloat, spacing: CGFloat = 10) -> some View {
        NumberPad(onKey: { k in
            coach.noteInput()
            problems.key(k)
        }, onBackspace: {
            coach.noteInput()
            problems.backspace()
        }, onCheck: {
            let r = withAnimation(.spring(duration: 0.3)) { problems.check() }
            coach.didCheck(r)
        }, keyHeight: h, spacing: spacing)
    }

    private func flat(_ layout: PoseLayout, topClear: CGFloat) -> some View {
        let r = layout.safeInset(layout.work)
        let listWidth = min(330, r.width * 0.3)
        return VStack(spacing: 22) {
            header()
            HStack(alignment: .top, spacing: 26) {
                ProblemList(problems: problems) { coach.selectProblem($0) }
                    .frame(width: listWidth)
                VStack(spacing: 26) {
                    ProblemCard(problems: problems, focus: coach.focus, size: 84)
                    AnswerRow(problems: problems, focus: coach.focus, size: 60)
                    pad(62)
                        .frame(maxWidth: 420)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, max(12, topClear - r.minY + 8))
        .padding(.bottom, 16)
        .frame(width: r.width, height: r.height, alignment: .top)
        .offset(x: r.minX, y: r.minY)
    }

    private func tabletop(_ layout: PoseLayout) -> some View {
        let stage = layout.stage
        let work = layout.safeInset(layout.work)
        let keyH = min(58, (work.height - 40) / 4 - 10)
        return ZStack(alignment: .topLeading) {
            if let g = stageGeometry(layout) {
                StageScene(geo: g, parallax: CGFloat(180 - poseModel.angle) * 0.3)
                    .frame(width: stage.width, height: stage.height)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            HStack(alignment: .center, spacing: 28) {
                VStack(spacing: 18) {
                    ProblemCard(problems: problems, focus: coach.focus, size: 64)
                    AnswerRow(problems: problems, focus: coach.focus, size: 50)
                }
                .frame(maxWidth: .infinity)
                pad(keyH, spacing: 8)
                    .frame(width: min(380, work.width * 0.42))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .frame(width: work.width, height: work.height)
            .offset(x: work.minX, y: work.minY)
        }
    }

    private func book(_ layout: PoseLayout) -> some View {
        let stage = layout.stage
        let work = layout.safeInset(layout.work)
        return ZStack(alignment: .topLeading) {
            if let g = stageGeometry(layout) {
                StageScene(geo: g, parallax: CGFloat(180 - poseModel.angle) * 0.3)
                    .frame(width: stage.width, height: stage.height)
                    .offset(x: stage.minX)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            VStack(spacing: 18) {
                header(compact: true)
                ProblemCard(problems: problems, focus: coach.focus, size: 58)
                AnswerRow(problems: problems, focus: coach.focus, size: 46)
                pad(min(56, work.height / 11), spacing: 8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(width: work.width, height: work.height)
            .offset(x: work.minX, y: work.minY)
        }
    }

    private func closed(_ layout: PoseLayout, topClear: CGFloat) -> some View {
        let r = layout.safeInset(layout.work)
        return VStack(spacing: 14) {
            header(compact: true)
            Color.clear.frame(height: BunnyLayer.compactStripHeight) // Bunny's strip
            ProblemCard(problems: problems, focus: coach.focus, size: 50)
            AnswerRow(problems: problems, focus: coach.focus, size: 42)
            pad(min(54, (r.height - 420) / 4 - 8), spacing: 8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, max(8, topClear - r.minY + 6))
        .padding(.bottom, 8)
        .frame(width: r.width, height: r.height, alignment: .top)
        .offset(x: r.minX, y: r.minY)
    }
}

// MARK: - Bunny + bubble (one shared coordinate space for the whole screen)

struct BunnyLayer: View {
    let coach: Coach
    let layout: PoseLayout
    let stage: SceneGeometry?
    let lastStageFeet: CGPoint?
    let lastStageScale: Int
    let topClear: CGFloat

    static let compactStripHeight: CGFloat = 132

    static func stageScale(_ g: SceneGeometry) -> Int {
        max(2, min(Int(g.rect.height * 0.5 / 58), 6))
    }

    private var scale: Int {
        switch coach.spot {
        case .corner: 3
        case .compact: 2
        case .stage: stage.map(Self.stageScale) ?? lastStageScale
        }
    }

    private var feet: CGPoint {
        let size = layout.size, safe = layout.safe
        switch coach.spot {
        case .corner:
            return CGPoint(x: size.width - safe.trailing - 96, y: size.height - max(safe.bottom, 12) - 10)
        case .compact:
            let top = max(safe.top, topClear) + 8 + 58 + 14
            return CGPoint(x: safe.leading + 16 + 56, y: top + Self.compactStripHeight - 8)
        case .stage:
            return stage?.feet ?? lastStageFeet ?? CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }

    var body: some View {
        let s = CGFloat(scale)
        let m = coach.player.manifest
        let f = feet
        ZStack(alignment: .topLeading) {
            Color.clear.allowsHitTesting(false)
            SpriteView(player: coach.player, scale: scale)
                .offset(x: f.x - CGFloat(m.cellWidth) * s / 2, y: f.y - SpritePlayer.feetRow * s)
                .allowsHitTesting(false)
            if let bubble = coach.bubble, !coach.jumping {
                placedBubble(bubble, feet: f, s: s)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
    }

    @ViewBuilder
    private func placedBubble(_ bubble: Bubble, feet f: CGPoint, s: CGFloat) -> some View {
        let size = layout.size, safe = layout.safe
        switch coach.spot {
        case .corner:
            let w: CGFloat = 380
            BubbleView(coach: coach, bubble: bubble, tail: .down)
                .frame(width: w)
                .alignmentGuide(.top) { $0[.bottom] }
                .offset(x: size.width - safe.trailing - 24 - w, y: f.y - 50 * s)
                .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
        case .stage where layout.pose == .book:
            let r = stage?.rect ?? .zero
            let w = min(420, r.width - 48)
            BubbleView(coach: coach, bubble: bubble, tail: .down)
                .frame(width: w)
                .alignmentGuide(.top) { $0[.bottom] }
                .offset(x: r.midX - w / 2, y: f.y - 52 * s)
                .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
        case .stage, .compact:
            let x = f.x + 22 * s
            let w = min(coach.spot == .compact ? 320 : 480, size.width - safe.trailing - 18 - x)
            let topLimit = max(safe.top, topClear) + 10
            BubbleView(coach: coach, bubble: bubble, tail: .leading)
                .frame(width: w)
                .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                .offset(x: x, y: max(f.y - 34 * s, topLimit + 70))
                .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
        }
    }
}

struct BubbleView: View {
    enum Tail { case down, leading }
    let coach: Coach
    let bubble: Bubble
    let tail: Tail

    var body: some View {
        let text = String(bubble.text.prefix(coach.revealed))
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                Text(bubble.text).opacity(0) // reserve final size so the bubble doesn't grow while typing
                Text(text)
            }
            .font(Theme.pixel(19))
            .foregroundStyle(Theme.ink)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            if !bubble.chips.isEmpty {
                FlowChips(chips: bubble.chips) { coach.tap($0) }
                    .opacity(coach.revealed >= bubble.text.count ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: coach.revealed >= bubble.text.count)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(NineSlice(piece: "bubble", scale: 3))
        .overlay(alignment: tail == .down ? .bottomTrailing : .leading) {
            PixelImage(path: "ui/bubble_tail.png", scale: 3)
                .rotationEffect(tail == .down ? .zero : .degrees(90))
                .offset(x: tail == .down ? -60 : -13, y: tail == .down ? 9 : 0)
        }
        .hardShadow()
        .id(bubble.id)
    }
}

private struct FlowChips: View {
    let chips: [Chip]
    let onTap: (Chip) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { buttons }
            VStack(alignment: .leading, spacing: 8) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        ForEach(chips) { chip in
            Button { onTap(chip) } label: {
                Text(chip.rawValue)
                    .font(Theme.pixel(16).weight(.semibold))
                    .fixedSize()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
            }
            .buttonStyle(PixelButtonStyle(piece: chip == .good ? "button_quiet" : (chip == .yesHint ? "button_primary" : "button"),
                                          textColor: chip == .yesHint ? Theme.cream : Theme.ink))
        }
    }
}

// MARK: - Debug menu (triple-tap the header; hidden in -recording)

struct DebugMenu: View {
    let poseModel: PoseModel
    let coach: Coach
    let livePose: Pose
    let pose: Pose
    let division: CGRect?
    let size: CGSize
    @Binding var show: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Debug").font(Theme.pixel(20).weight(.bold))
                Spacer()
                Button("Close") { show = false }.font(Theme.pixel(16))
            }
            Text("live: \(livePose.rawValue) · shown: \(pose.rawValue)")
            Text("hinge: \(poseModel.statusTitle) \(Int(poseModel.angle))°")
            Text("division: \(division.map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))×\(Int($0.height))" } ?? "none")")
            Text("size: \(Int(size.width))×\(Int(size.height))")
            HStack(spacing: 6) {
                chip("Live", poseModel.override == nil) { poseModel.override = nil }
                ForEach(Pose.allCases) { p in chip(p.title, poseModel.override == p) { poseModel.override = p } }
            }
            HStack(spacing: 6) {
                chip(coach.speechEnabled ? "Speech on" : "Speech off", coach.speechEnabled) { coach.speechEnabled.toggle() }
                chip("Reset demo", false) {
                    coach.reset()
                    show = false
                }
            }
        }
        .font(Theme.digits(20))
        .foregroundStyle(Theme.ink)
        .padding(20)
        .frame(width: 520)
        .background(NineSlice(piece: "scroll", scale: 3))
        .hardShadow()
        .padding(.top, 90)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func chip(_ title: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.pixel(14)).padding(.horizontal, 10).padding(.vertical, 7)
        }
        .buttonStyle(PixelButtonStyle(piece: on ? "button_primary" : "button_quiet", textColor: on ? Theme.cream : Theme.ink))
    }
}

#Preview("Flat") { RootView() }
