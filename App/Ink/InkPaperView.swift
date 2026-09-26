import SwiftUI

struct InkPaperView: View {
  var session: InkPracticeSession
  var size: CGSize
  var readOnly: Bool
  @Environment(\.accessibilityReduceMotion) private var reducedMotion

  var body: some View {
    ZStack(alignment: .topLeading) {
      BurrowTheme.paper
      Canvas { context, canvasSize in
        for row in 1...15 {
          let y = CGFloat(row) * canvasSize.height / 17
          var path = Path()
          path.move(to: CGPoint(x: 16, y: y))
          path.addLine(to: CGPoint(x: canvasSize.width - 16, y: y))
          context.stroke(path, with: .color(BurrowTheme.teal.opacity(0.09)), lineWidth: 1)
        }
      }.accessibilityHidden(true)
      if let photo = session.document.photo {
        Image(uiImage: photo).resizable().scaledToFit().frame(width: size.width, height: size.height)
          .accessibilityLabel("Imported work")
      }
      PencilPage(document: session.document, size: size, readOnly: readOnly)
      if session.document.normalizedDrawing.strokes.isEmpty && session.document.photo == nil && !session.document.isReplaying {
        VStack(alignment: .leading, spacing: 12) {
          Text("Start here.").font(BurrowTheme.digits(29))
          Text(readOnly ? "Your work will stay with you." : "Write a line, then take a breath.\nBunny is reading along.")
            .font(BurrowTheme.ui(17))
        }
        .foregroundStyle(BurrowTheme.muted.opacity(0.7)).padding(24).allowsHitTesting(false)
      }
      if let ring = session.ring {
        let frame = ring.inPage(CGRect(origin: .zero, size: size)).insetBy(dx: -10, dy: -10)
        ChalkRing(progress: session.ringProgress, seed: session.ringSeed)
          .frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY)
          .allowsHitTesting(false)
          .accessibilityLabel(session.judgement.issue.isEmpty ? "The marked step" : session.judgement.issue)
      }
      if session.noteVisible, let space = session.judgement.space,
         space.w * size.width >= 130, space.h * size.height >= 90 {
        let frame = space.inPage(CGRect(origin: .zero, size: size)).insetBy(dx: 8, dy: 8)
        VStack(alignment: .leading, spacing: 7) {
          ForEach(session.judgement.note, id: \.self) { line in
            Text(line).font(BurrowTheme.digits(21)).foregroundStyle(BurrowTheme.cream)
          }
        }
        .padding(20)
        .frame(width: min(260, frame.width), height: min(140, frame.height), alignment: .leading)
        .background { NineSlice(name: "board", scale: 2) }
        .position(x: frame.midX, y: frame.midY)
        .transition(.move(edge: .bottom).combined(with: .opacity)).allowsHitTesting(false)
      }
      if session.recording && !readOnly {
        Color.clear.contentShape(Rectangle()).frame(width: 44, height: 44)
          .onTapGesture { session.replay() }.accessibilityHidden(true)
      }
    }
    .frame(width: size.width, height: size.height)
    .overlay { Rectangle().stroke(BurrowTheme.ink.opacity(0.2), lineWidth: 1) }
    .shadow(color: BurrowTheme.ink.opacity(0.12), radius: 0, x: -3, y: 3).clipped()
    .animation(reducedMotion ? nil : .smooth(duration: 0.6), value: session.noteVisible)
  }
}

/// Source InkCoach.ringPath: 56 segments, wobble, outward drift and overshoot.
struct ChalkRing: View {
  var progress: Double
  var seed: Int
  var body: some View {
    Canvas { context, size in
      let u = Double(abs(seed) % 997) / 997
      let start = 2.2 + u * 0.9
      let sweep = Double.pi * 2 * (1.06 + u * 0.14)
      let phase = u * Double.pi * 2
      var path = Path()
      for index in 0...56 {
        let fraction = Double(index) / 56
        let t = start + sweep * fraction
        let wobble = 1 + 0.045 * sin(3 * t + phase) + 0.03 * sin(5 * t - phase)
        let drift = fraction * 2.2
        let point = CGPoint(x: size.width / 2 + (max(6, size.width / 2 - 3) * wobble + drift) * cos(t),
                            y: size.height / 2 + (max(6, size.height / 2 - 3) * wobble + drift) * sin(t))
        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
      }
      let drawn = path.trimmedPath(from: 0, to: progress)
      context.stroke(drawn, with: .color(BurrowTheme.cream.opacity(0.95)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
      context.stroke(drawn, with: .color(BurrowTheme.teal), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
      var textured = context
      textured.clip(to: drawn.strokedPath(StrokeStyle(lineWidth: 2, lineCap: .round)))
      textured.opacity = 0.3
      for x in stride(from: CGFloat(0), to: size.width, by: 16) {
        for y in stride(from: CGFloat(0), to: size.height, by: 16) {
          textured.draw(Image("ui_chalk").interpolation(.none), in: CGRect(x: x, y: y, width: 16, height: 16))
        }
      }
    }
  }
}
