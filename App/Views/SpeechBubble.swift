import SwiftUI

struct SpeechBubble: View {
  var session: PracticeSession
  var compact = false
  var showsSubtitle = true

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if showsSubtitle {
        Text(session.bunny.subtitle)
          .font(BurrowTheme.ui(compact ? 11 : 13))
          .tracking(1)
          .foregroundStyle(BurrowTheme.tealDeep)
      }
      Text(session.bunny.message)
        .font(BurrowTheme.ui(compact ? 17 : 22))
        .foregroundStyle(BurrowTheme.ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("bunny-message")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(compact ? 14 : 20)
    .background {
      NineSlice(name: "bubble", scale: compact ? 2 : 3)
        .shadow(color: BurrowTheme.ink.opacity(0.15), radius: 0, x: 3, y: 3)
    }
    .overlay(alignment: .bottomTrailing) {
      Image("ui_bubble_tail").resizable().interpolation(.none)
        .frame(width: 14, height: 8)
        .offset(x: -24, y: 6)
    }
    .accessibilityElement(children: .combine)
  }
}
