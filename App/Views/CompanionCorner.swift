import SwiftUI

struct CompanionCorner: View {
  var session: PracticeSession
  var scale: Int
  var compact: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          SpeechBubble(session: session, compact: true, showsSubtitle: !compact)
          QuickReplies(session: session, horizontal: true)
        }
        .padding(4)
        .frame(maxWidth: .infinity)
      }
      .scrollIndicators(.hidden)
      Color.clear.frame(width: CGFloat(64 * scale) + (compact ? 0 : 12))
    }
  }
}
