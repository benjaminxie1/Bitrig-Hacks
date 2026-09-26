import SwiftUI
import PhotosUI

struct InkHeader: View {
  @Bindable var session: InkPracticeSession
  var compact = false
  var openDebug: () -> Void
  var body: some View {
    HStack(spacing: 8) {
      Group {
        if session.recording { brand }
        else { brand.onTapGesture(count: 3, perform: openDebug).accessibilityAction(named: "Open demo menu", openDebug) }
      }
      Spacer(minLength: 0)
      Toggle(isOn: $session.voiceEnabled) {
        Image(session.voiceEnabled ? "scene_speaker_on" : "scene_speaker_off")
          .interpolation(.none).frame(width: 44, height: 44)
      }
      .toggleStyle(.button).buttonStyle(.plain).accessibilityLabel("Bunny's voice")
    }
    .foregroundStyle(BurrowTheme.ink)
  }
  private var brand: some View {
    HStack(spacing: 7) {
      Image("icons_icon128").resizable().interpolation(.none).frame(width: 28, height: 28).accessibilityHidden(true)
      Text("burrow").font(BurrowTheme.ui(compact ? 25 : 30))
    }
    .contentShape(Rectangle()).accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
  }
}

struct InkTools: View {
  @Bindable var session: InkPracticeSession
  @Binding var selection: PhotosPickerItem?
  var compact = false
  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        ForEach(InkTool.allCases) { tool in
          Toggle(isOn: Binding(get: { session.document.tool == tool }, set: { if $0 { session.document.tool = tool } })) {
            HStack(spacing: 5) {
              if tool == .pen {
                Image("ui_chalk").resizable().interpolation(.none).frame(width: 16, height: 16).accessibilityHidden(true)
              }
              Text(tool.title)
            }
          }
          .toggleStyle(.button)
          .buttonStyle(PixelButtonStyle(kind: session.document.tool == tool ? "button_primary" : "button", compact: true))
          .accessibilityLabel(tool.title)
        }
        Button("Undo") { session.document.undo() }
          .buttonStyle(PixelButtonStyle(kind: "button_quiet", compact: true))
          .disabled(!session.document.canUndo)
        PhotosPicker(selection: $selection, matching: .images) { Text("Import") }
          .buttonStyle(PixelButtonStyle(kind: "button_quiet", compact: true))
          .accessibilityLabel("Import a photo of your work")
      }.padding(.trailing, 3).padding(.bottom, 3)
    }
    .scrollIndicators(.hidden).disabled(session.document.isReplaying)
  }
}

struct InkProblemCard: View {
  var problem: PracticeProblem
  var index: Int
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("RIVERSIDE LEARNING").font(BurrowTheme.ui(12)).tracking(1).foregroundStyle(BurrowTheme.muted)
      Text("A little algebra").font(BurrowTheme.ui(23)).foregroundStyle(BurrowTheme.ink)
      Text(problem.equation).font(BurrowTheme.digits(39)).minimumScaleFactor(0.6).lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("Find x. Show your working.").font(BurrowTheme.ui(17)).foregroundStyle(BurrowTheme.muted)
    }
    .padding(22).frame(maxWidth: .infinity, alignment: .leading)
    .background { NineSlice(name: "scroll", scale: 2) }
  }
}

struct InkBubble: View {
  var text: String
  var subtitle: String?
  var compact = false
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      if let subtitle {
        Text(subtitle.uppercased()).font(BurrowTheme.ui(11)).foregroundStyle(BurrowTheme.tealDeep)
      }
      Text(text).font(BurrowTheme.ui(compact ? 17 : 21))
        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("bunny-message")
    }
    .foregroundStyle(BurrowTheme.ink)
    .padding(compact ? 13 : 17).frame(maxWidth: .infinity, alignment: .leading)
    .background { NineSlice(name: "bubble", scale: 2).shadow(color: BurrowTheme.ink.opacity(0.12), radius: 0, x: 3, y: 3) }
    .accessibilityElement(children: .combine)
  }
}
