import SwiftUI

struct WorkspaceView: View {
  var session: PracticeSession
  var size: CGSize
  var showsReplies: Bool

  var body: some View {
    let beside = size.width >= 490
    let compact = size.height < 370
    ScrollView {
      VStack(spacing: compact ? 10 : 18) {
        if beside {
          HStack(alignment: .center, spacing: 20) {
            ProblemCard(session: session, compact: compact)
              .frame(maxWidth: .infinity)
            NumberPad(session: session, compact: compact)
              .frame(width: max(206, min(290, size.width * 0.40)))
          }
        } else {
          ProblemCard(session: session, compact: true)
          NumberPad(session: session, compact: true)
        }
        if showsReplies {
          QuickReplies(session: session, horizontal: beside)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(4)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .defaultScrollAnchor(.top)
  }
}
