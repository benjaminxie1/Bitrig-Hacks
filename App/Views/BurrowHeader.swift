import SwiftUI

struct BurrowHeader: View {
  @Bindable var session: PracticeSession
  var compact = false
  var recording: Bool
  var openDebug: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      brand
      Spacer(minLength: 4)
      if !compact {
        Text("RIVERSIDE\nLEARNING")
          .font(BurrowTheme.ui(13))
          .lineSpacing(1)
          .foregroundStyle(BurrowTheme.muted)
          .multilineTextAlignment(.trailing)
      }
      Toggle(isOn: $session.voiceEnabled) {
        Image(session.voiceEnabled ? "scene_speaker_on" : "scene_speaker_off")
          .interpolation(.none)
          .frame(width: 33, height: 27)
          .frame(width: 44, height: 44)
      }
      .toggleStyle(.button)
      .buttonStyle(.plain)
      .accessibilityLabel("Bunny’s voice")
      .accessibilityValue(session.voiceEnabled ? "On" : "Off")
    }
    .foregroundStyle(BurrowTheme.ink)
  }

  @ViewBuilder private var brand: some View {
    if recording { title }
    else { title.onTapGesture(count: 3, perform: openDebug) }
  }

  private var title: some View {
    HStack(spacing: 7) {
      Image("icons_icon128")
        .resizable().interpolation(.none)
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
      Text("burrow").font(BurrowTheme.ui(compact ? 27 : 32))
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}
