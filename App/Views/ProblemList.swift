import SwiftUI

struct ProblemList: View {
  var session: PracticeSession

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text("YOUR PRACTICE")
          .font(BurrowTheme.ui(13)).tracking(1)
          .foregroundStyle(BurrowTheme.muted)
          .padding(.vertical, 10)
        Text("Small steps.\nBig things.")
          .font(BurrowTheme.ui(27))
          .padding(.bottom, 15)
        ForEach(Array(session.problems.problems.enumerated()), id: \.element.id) { index, problem in
          Button { session.selectProblem(index) } label: {
            HStack(spacing: 8) {
              Text(session.problems.solved.contains(problem.id) ? "✓" : String(format: "%02d", index + 1))
                .font(BurrowTheme.digits(25))
                .foregroundStyle(BurrowTheme.tealDeep)
              VStack(alignment: .leading, spacing: 4) {
                Text(problem.title).font(BurrowTheme.ui(16))
                Text(problem.equation).font(BurrowTheme.digits(21))
              }
              Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .background {
              if index == session.problems.selectedIndex { NineSlice(name: "bubble_teal", scale: 2) }
              else { BurrowTheme.paper.opacity(0.55) }
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Problem \(index + 1), \(problem.equation)")
          .accessibilityValue(session.problems.solved.contains(problem.id) ? "Completed" : index == session.problems.selectedIndex ? "Selected" : "Not completed")
        }
        Text("\(session.problems.solved.count) OF \(session.problems.problems.count) COMPLETE")
          .font(BurrowTheme.ui(12))
          .foregroundStyle(BurrowTheme.muted)
          .padding(.top, 12)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .scrollIndicators(.hidden)
    .foregroundStyle(BurrowTheme.ink)
  }
}
