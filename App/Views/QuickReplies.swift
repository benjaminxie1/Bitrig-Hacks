import SwiftUI

struct QuickReplies: View {
  var session: PracticeSession
  var horizontal = false

  var body: some View {
    if horizontal {
      ScrollView(.horizontal) {
        HStack(spacing: 8) { replies }
          .padding(.bottom, 4)
          .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
    } else {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 8) { replies }
        VStack(spacing: 8) { replies }
      }
    }
  }

  @ViewBuilder private var replies: some View {
    switch session.bunny.replies {
    case .offer:
      Button("Yes, a hint") { session.requestHint() }
        .buttonStyle(PixelButtonStyle(kind: "button_primary", compact: true))
      decline
    case .hint:
      Button("Another hint") { session.requestHint() }
        .buttonStyle(PixelButtonStyle(kind: "button_primary", compact: true))
      Button("Show me a similar one") { session.requestHint(similar: true) }
        .buttonStyle(PixelButtonStyle(compact: true))
      decline
    case .celebration:
      Button("Next problem") { session.nextProblem() }
        .buttonStyle(PixelButtonStyle(kind: "button_primary", compact: true))
    case .none:
      Button("A little hint?") { session.requestHint() }
        .buttonStyle(PixelButtonStyle(kind: "button_quiet", compact: true))
    }
  }

  private var decline: some View {
    Button("I’m good") { session.decline() }
      .buttonStyle(PixelButtonStyle(kind: "button_quiet", compact: true))
  }
}
