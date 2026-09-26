import SwiftUI

struct BunnyStage: View {
  var session: PracticeSession
  var pose: BurrowPose
  var size: CGSize
  var scale: Int
  var foldProgress: Double

  var body: some View {
    ZStack(alignment: .topLeading) {
      BurrowSceneView(palette: BurrowSceneView.palette(recording: session.recording), foldProgress: foldProgress, scale: max(1, scale - 1))
        .ignoresSafeArea()
      if pose == .tabletop {
        HStack(alignment: .top, spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text("THE BURROW").font(BurrowTheme.ui(13)).tracking(2)
            Text("A little room\nto think.").font(BurrowTheme.ui(size.height < 230 ? 21 : 29))
          }
          .frame(width: max(80, size.width * 0.34), alignment: .leading)
          ScrollView {
            SpeechBubble(session: session, compact: size.height < 260)
              .padding(4)
              .frame(maxWidth: .infinity)
          }
          .scrollIndicators(.hidden)
        }
        .padding(20)
        .frame(maxHeight: max(80, size.height - 55), alignment: .top)
      } else {
        VStack(spacing: 20) {
          Text("THE BURROW").font(BurrowTheme.ui(13)).tracking(2)
          ScrollView {
            SpeechBubble(session: session, compact: size.width < 340)
              .padding(4)
              .frame(maxWidth: .infinity)
          }
          .scrollIndicators(.hidden)
          .frame(maxHeight: max(100, size.height - CGFloat(scale * 58) - 210))
          Spacer(minLength: 0)
          QuickReplies(session: session)
            .padding(10)
            .background(BurrowTheme.cream.opacity(0.94))
        }
        .padding(18)
      }
    }
    .foregroundStyle(BurrowTheme.ink)
    .frame(width: size.width, height: size.height)
    .clipped()
  }
}
