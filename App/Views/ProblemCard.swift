import SwiftUI

struct ProblemCard: View {
  var session: PracticeSession
  var compact = false

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 8 : 14) {
      HStack {
        Text("PROBLEM \(session.problems.selectedIndex + 1) / \(session.problems.problems.count)")
          .font(BurrowTheme.ui(13))
          .tracking(1)
        Spacer(minLength: 4)
        Text("ALGEBRA I").font(BurrowTheme.ui(12))
      }
      .foregroundStyle(BurrowTheme.muted)
      if !compact {
        Text("Find your next step.").font(BurrowTheme.ui(22))
      }
      equation
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 0 : 8)
      HStack(spacing: 8) {
        Text("x =").font(BurrowTheme.digits(32))
        Text(session.problems.input.isEmpty ? "?" : session.problems.input)
          .font(BurrowTheme.digits(32))
          .foregroundStyle(session.problems.input.isEmpty ? BurrowTheme.muted : BurrowTheme.ink)
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          .padding(.horizontal, 12)
          .background(BurrowTheme.paper)
          .overlay { Rectangle().strokeBorder(BurrowTheme.teal.opacity(0.45), lineWidth: 2) }
          .overlay { if session.bunny.guide == .answer { GuideMarker().padding(-4) } }
          .accessibilityLabel("Answer")
          .accessibilityValue(session.problems.input.isEmpty ? "Empty. Use the number pad." : session.problems.input)
          .accessibilityIdentifier("answer")
      }
      Text(session.problems.feedback.title)
        .font(BurrowTheme.ui(compact ? 15 : 17))
        .foregroundStyle(session.problems.feedback == .incorrect ? BurrowTheme.red : session.problems.feedback == .correct ? BurrowTheme.tealDeep : BurrowTheme.muted)
        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
        .accessibilityIdentifier("feedback")
    }
    .foregroundStyle(BurrowTheme.ink)
    .padding(compact ? 18 : 24)
    .frame(maxWidth: .infinity)
    .background {
      NineSlice(name: "scroll", scale: 3)
        .shadow(color: BurrowTheme.ink.opacity(0.12), radius: 0, x: 3, y: 3)
    }
  }

  private var equation: some View {
    HStack(spacing: 8) {
      Text("\(Int(session.problems.current.coefficient))x")
      Text(session.problems.current.focusTerm)
        .padding(5)
        .overlay { if session.bunny.guide == .term { GuideMarker() } }
      Text("= \(Int(session.problems.current.rightSide))")
    }
    .font(BurrowTheme.digits(compact ? 34 : 44))
    .lineLimit(1)
    .minimumScaleFactor(0.65)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(session.problems.current.equation)
  }
}
