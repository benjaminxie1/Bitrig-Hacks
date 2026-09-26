import SwiftUI
import PhotosUI

@available(iOS 27.1, *)
struct ContentView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.accessibilityReduceMotion) private var reducedMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var poseModel = PoseModel()
  @State private var homework = HomeworkTabModel(recording: ProcessInfo.processInfo.arguments.contains("-recording"))
  @State private var session = InkPracticeSession(recording: ProcessInfo.processInfo.arguments.contains("-recording"))
  @State private var showsDebugMenu = false
  @State private var photoSelection: PhotosPickerItem?

  var body: some View {
    GeometryReader { proxy in
      let active = proxy.reservedRegions(kind: .division).first?.frame
      let all = proxy.reservedRegions(kind: .division, options: .includeInactive).first?.frame
      let snapshot = poseModel.snapshot(activeDivision: active, allDivision: all,
        occlusions: proxy.reservedRegions(kind: .occlusion).map(\.frame),
        size: proxy.size, horizontalSizeClass: horizontalSizeClass)
      let layout = InkPageLayout(snapshot: snapshot)
      ZStack(alignment: .topLeading) {
        BurrowTheme.cream.ignoresSafeArea()
        if layout.pose == .closed {
          closedPage(layout)
        } else {
          workPage(layout)
          facingPage(layout)
          rabbit(layout)
            .mask {
              Path { path in
                path.addRect(layout.paperRegion)
                path.addRect(layout.companionRegion)
              }
            }
            .allowsHitTesting(false)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .coordinateSpace(name: "BurrowWorkspace")
      .onChange(of: layout, initial: true) { _, value in session.configure(layout: value) }
      .onChange(of: session.target) { _, _ in session.configure(layout: layout) }
      .onHingeChange { old, new in
        poseModel.receiveHinge(old: old.hinge, new: new.hinge)
        guard poseModel.overridePose == nil else { return }
        if old.hinge?.status == .fullyOpen && new.hinge?.status == .partiallyOpen && session.bunny.pose == .flat {
          session.bunny.prepareDive()
        }
        if new.hinge?.status == .fullyOpen || new.hinge?.status == .closed { session.bunny.cancelEarlyDive() }
      }
    }
    .preferredColorScheme(.light)
    .task(id: scenePhase) {
      guard scenePhase == .active else { return }
      let clock = ContinuousClock()
      var previous = clock.now
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(33))
        guard !Task.isCancelled else { break }
        let now = clock.now
        let elapsed = previous.duration(to: now)
        previous = now
        let dt = session.recording ? 1.0 / 30 : min(0.1, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
        session.tick(dt, reducedMotion: reducedMotion)
        poseModel.tick(dt, reducedMotion: reducedMotion)
      }
    }
    .onChange(of: photoSelection) { _, item in
      guard let item else { return }
      Task {
        do {
          if let data = try await item.loadTransferable(type: Data.self) { session.importPhoto(data) }
          else { session.notice = "That photo could not be loaded. Try another image." }
        } catch { session.notice = "That photo could not be loaded. Try another image." }
        photoSelection = nil
      }
    }
    .confirmationDialog("RABBITHELPER demo", isPresented: $showsDebugMenu, titleVisibility: .visible) {
      ForEach(BurrowPose.allCases) { pose in Button(pose.title) { poseModel.overridePose = pose } }
      Button("Use Device Pose") { poseModel.overridePose = nil }
      Button(session.recorder.isRecording ? "Stop recording ink" : "Record ink") {
        if session.recorder.isRecording {
          do {
            try session.recorder.finish(document: session.document, problemID: session.problem.id)
            session.notice = session.recorder.message
          } catch { session.notice = "The ink recording could not be saved: \(error.localizedDescription)" }
        } else {
          session.recorder.begin(document: session.document)
        }
      }
      Button("Replay ink") { session.replay() }
      ForEach(InkRecorder.assets(), id: \.0.id) { asset, directory in
        Button(asset.title) { session.load(asset, directory: directory) }
      }
      Button("Reset demo") { session.problemIndex = 0; session.newPage() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Record your strokes, then review the saved sidecar before bundling. \(session.readingSource)")
    }
    .alert("RABBITHELPER", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) {
      Button("OK") { session.notice = nil }
    } message: { Text(session.notice ?? "") }
  }

  private func header(compact: Bool = false) -> some View {
    InkHeader(session: session, compact: compact) { showsDebugMenu = true }
  }

  private func workPage(_ layout: InkPageLayout) -> some View {
    ZStack(alignment: .topLeading) {
      HStack {
        Text("YOUR WORK").font(BurrowTheme.ui(13)).tracking(1)
        Spacer()
        if layout.isHorizontal { Text(session.problem.equation).font(BurrowTheme.digits(22)); Spacer() }
        Text("\(session.problemIndex + 1) / \(session.problems.count)").font(BurrowTheme.ui(13))
      }
      .foregroundStyle(BurrowTheme.muted)
      .frame(width: max(0, layout.paperRegion.width - 32), height: 40)
      .position(x: layout.paperRegion.midX, y: layout.paperRegion.minY + 22)
      InkPaperView(session: session, size: layout.page.size, readOnly: false)
        .position(x: layout.page.midX, y: layout.page.midY)
      InkTools(session: session, selection: $photoSelection, compact: true)
        .frame(width: max(0, layout.paperRegion.width - 24), height: 48)
        .position(x: layout.paperRegion.midX, y: layout.paperRegion.maxY - 25)
    }
  }

  private func facingPage(_ layout: InkPageLayout) -> some View {
    let stage = layout.pose == .book || layout.pose == .tabletop
    let region = layout.companionRegion
    return ZStack(alignment: .topLeading) {
      if stage {
        BurrowSceneView(palette: BurrowSceneView.palette(recording: session.recording),
          foldProgress: poseModel.foldProgress, scale: max(1, layout.bunnyScale))
          .frame(width: region.width, height: region.height).clipped()
      }
      if !stage {
        VStack(alignment: .leading, spacing: 10) {
          header(compact: region.width < 400)
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
              HomeworkTab(model: homework) { session.adopt($0) }
                .frame(height: max(280, min(520, region.height * 0.5)))
              Text("Write your next step on the page.\nFold to bring Bunny beside your work.")
                .font(BurrowTheme.ui(18)).foregroundStyle(BurrowTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
              if session.judgement.solved {
                Button("Next problem") { session.nextProblem() }
                  .buttonStyle(PixelButtonStyle(kind: "button_primary"))
              }
            }.padding(3).frame(maxWidth: .infinity)
          }
        }
        .padding(16)
        .frame(width: region.width, height: max(100, region.height - min(170, region.height * 0.42)))
      } else {
        VStack(alignment: .leading, spacing: 16) {
          header(compact: region.width < 400)
          if !layout.isHorizontal {
            Text(session.problem.equation).font(BurrowTheme.digits(29)).foregroundStyle(BurrowTheme.ink)
          }
        }
        .padding(16).frame(width: region.width, height: region.height, alignment: .topLeading)
      }
      if stage { stageBubble(layout) }
      else {
        InkBubble(text: session.bunny.message, subtitle: session.statusText, compact: region.width < 350)
          .frame(width: max(90, region.width - CGFloat(layout.bunnyScale * 64) - 36))
          .position(x: max(45, (region.width - CGFloat(layout.bunnyScale * 64) - 36) / 2 + 14),
                    y: max(90, region.height - 86))
      }
    }
    .frame(width: region.width, height: region.height).clipped()
    .position(x: region.midX, y: region.midY)
  }

  private func stageBubble(_ layout: InkPageLayout) -> some View {
    let region = layout.companionRegion
    let anchor = layout.bunnyAnchor(mark: session.target)
    let isHorizontal = layout.isHorizontal
    let width = min(isHorizontal ? region.width - 32 : region.width - CGFloat(layout.bunnyScale * 61) - 26, 340)
    let x = isHorizontal ? region.width / 2 : region.width - max(80, width) / 2 - 12
    let y = isHorizontal ? min(115, region.height * 0.35) : min(region.height - 140, max(170, anchor.y - region.minY - CGFloat(layout.bunnyScale * 33)))
    return InkBubble(text: session.bunny.message, subtitle: session.judgement.solved ? "YOUR THINKING" : "ONE SMALL STEP", compact: true)
      .frame(width: max(80, width)).position(x: x, y: y)
  }

  private func closedPage(_ layout: InkPageLayout) -> some View {
    let pageWidth = min(max(100, layout.paperRegion.width - 36), max(140, (layout.paperRegion.height - 260) / InkPageLayout.aspect))
    return ScrollView {
      VStack(spacing: 14) {
        header(compact: true)
        Text(session.problem.equation).font(BurrowTheme.digits(28))
        InkPaperView(session: session,
          size: CGSize(width: pageWidth, height: pageWidth * InkPageLayout.aspect),
          readOnly: true)
        HStack(alignment: .center, spacing: 10) {
          InkBubble(text: session.bunny.message, subtitle: nil, compact: true)
          SpriteView(player: session.bunny.player, scale: 1)
        }
        Text("Open me up to keep writing.")
          .font(BurrowTheme.ui(19)).foregroundStyle(BurrowTheme.tealDeep)
      }
      .padding(16).frame(maxWidth: .infinity)
    }
    .frame(width: layout.paperRegion.width, height: layout.paperRegion.height)
    .position(x: layout.paperRegion.midX, y: layout.paperRegion.midY)
  }

  private func rabbit(_ layout: InkPageLayout) -> some View {
    let sending = session.bunny.phase == .sending
    let anchor = sending ? session.bunny.departureAnchor : layout.bunnyAnchor(mark: session.target)
    let scale = sending ? session.bunny.departureScale : layout.bunnyScale
    let cosmetic = session.bunny.phase == .resting && layout.pose == .flat && poseModel.foldProgress > 0.01
    return SpriteView(player: session.bunny.player, scale: scale, facesLeading: true,
      cosmeticHoleFrame: cosmetic ? min(2, Int(poseModel.foldProgress * 6)) : nil)
      .overlay(alignment: .topTrailing) {
        if session.showsConfusion && !session.onStage {
          Text("?").font(BurrowTheme.digits(25)).padding(7)
            .background { NineSlice(name: "bubble", scale: 2) }
            .offset(x: 5, y: -14).accessibilityLabel("Bunny spotted something")
        }
      }
      .position(x: anchor.x, y: anchor.y - CGFloat(24 * scale))
      .animation(reducedMotion || session.bunny.phase != .resting ? nil : .smooth(duration: 0.3), value: anchor)
  }
}
