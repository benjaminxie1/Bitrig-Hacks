import SwiftUI

/// Custom pixel header (no NavigationStack toolbar). Triple-tap opens the debug menu.
struct HeaderBar: View {
    let problems: ProblemSetModel
    var compact = false
    var onTripleTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            PixelImage(path: "scene/carrot.png", scale: compact ? 2 : 3)
            VStack(alignment: .leading, spacing: 0) {
                Text(problems.file.course)
                    .font(Theme.pixel(compact ? 12 : 14))
                    .foregroundStyle(Theme.cream.opacity(0.85))
                Text(problems.file.title)
                    .font(Theme.pixel(compact ? 17 : 21).weight(.semibold))
                    .foregroundStyle(Theme.cream)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                ForEach(0..<problems.file.problems.count, id: \.self) { i in
                    Rectangle()
                        .fill(problems.solved.contains(i) ? Theme.gold : Theme.cream.opacity(i == problems.index ? 0.9 : 0.35))
                        .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                }
            }
        }
        .padding(.horizontal, compact ? 16 : 22)
        .padding(.vertical, compact ? 9 : 12)
        .background(NineSlice(piece: "bubble_teal", scale: 3))
        .hardShadow()
        .contentShape(Rectangle())
        .onTapGesture(count: 3) { onTripleTap() }
    }
}

/// The chalkboard with the equation. Terms can carry gold guide brackets.
struct ProblemCard: View {
    let problems: ProblemSetModel
    let focus: String?
    var size: CGFloat = 72

    var body: some View {
        VStack(spacing: 6) {
            Text("Problem \(problems.index + 1) · Solve for x")
                .font(Theme.pixel(size * 0.25))
                .foregroundStyle(Theme.chalk.opacity(0.75))
            HStack(spacing: size * 0.22) {
                ForEach(Array(problems.problem.tokens.enumerated()), id: \.offset) { _, token in
                    Text(token.text)
                        .font(Theme.digits(size))
                        .foregroundStyle(Theme.chalk)
                        .fixedSize()
                        .padding(.horizontal, 4)
                        .guide(focus != nil && focus == token.id)
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 36)
        .padding(.top, 22)
        .padding(.bottom, 38)
        .frame(maxWidth: .infinity)
        .background(NineSlice(piece: "board", scale: 4))
        .hardShadow()
        .id(problems.index)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }
}

/// "x = [ answer ]" plus Correct / Not quite feedback. Never raises the system keyboard.
struct AnswerRow: View {
    let problems: ProblemSetModel
    let focus: String?
    var size: CGFloat = 56

    @State private var shake = false

    var body: some View {
        HStack(spacing: 14) {
            Text("x =")
                .font(Theme.digits(size))
                .foregroundStyle(Theme.ink)
            HStack(spacing: 2) {
                Text(problems.entry.isEmpty ? " " : problems.entry)
                    .font(Theme.digits(size))
                    .foregroundStyle(Theme.ink)
                Cursor(height: size * 0.7)
            }
            .padding(.horizontal, 18)
            .frame(minWidth: size * 2.6, minHeight: size * 1.25, alignment: .leading)
            .background(NineSlice(piece: "bubble", scale: 3))
            .guide(focus == "answer")
            .offset(x: shake ? -8 : 0)
            feedback
                .frame(minWidth: 110, alignment: .leading)
        }
        .onChange(of: problems.checkCount) {
            guard problems.feedback == .wrong else { return }
            withAnimation(.spring(duration: 0.08, bounce: 0).repeatCount(4, autoreverses: true)) { shake = true }
            Task {
                try? await Task.sleep(for: .milliseconds(340))
                shake = false
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch problems.feedback {
        case .correct:
            Label("Correct!", systemImage: "checkmark")
                .labelStyle(.titleOnly)
                .font(Theme.pixel(size * 0.46).weight(.bold))
                .foregroundStyle(Theme.tealDeep)
                .transition(.scale.combined(with: .opacity))
        case .wrong:
            Text("Not quite")
                .font(Theme.pixel(size * 0.46).weight(.bold))
                .foregroundStyle(Theme.red)
                .transition(.scale.combined(with: .opacity))
        case .none:
            Color.clear.frame(width: 1, height: 1)
        }
    }
}

private struct Cursor: View {
    let height: CGFloat
    @State private var on = true
    var body: some View {
        Rectangle()
            .fill(Theme.ink)
            .frame(width: 4, height: height)
            .opacity(on ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) { on = false }
            }
    }
}

/// Pixel-art number pad built from the repo's 9-slice buttons.
struct NumberPad: View {
    let onKey: (String) -> Void
    let onBackspace: () -> Void
    let onCheck: () -> Void
    var keyHeight: CGFloat = 64
    var spacing: CGFloat = 10

    var body: some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            GridRow { digit("7"); digit("8"); digit("9"); key("⌫", piece: "button_quiet", action: onBackspace) }
            GridRow { digit("4"); digit("5"); digit("6"); key("−", piece: "button_quiet") { onKey("−") } }
            GridRow { digit("1"); digit("2"); digit("3"); key("/", piece: "button_quiet") { onKey("/") } }
            GridRow {
                digit("0")
                Button(action: onCheck) {
                    Text("Check")
                        .font(Theme.pixel(keyHeight * 0.4).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: keyHeight)
                }
                .buttonStyle(PixelButtonStyle(piece: "button_primary", textColor: Theme.cream))
                .gridCellColumns(3)
            }
        }
    }

    private func digit(_ d: String) -> some View {
        key(d, piece: "button") { onKey(d) }
    }

    private func key(_ label: String, piece: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.digits(keyHeight * 0.72))
                .frame(maxWidth: .infinity, minHeight: keyHeight)
        }
        .buttonStyle(PixelButtonStyle(piece: piece))
    }
}

/// Flat-only: the practice set on the leading side.
struct ProblemList: View {
    let problems: ProblemSetModel
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Practice set")
                .font(Theme.pixel(20).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 4)
            ForEach(Array(problems.file.problems.enumerated()), id: \.offset) { i, p in
                Button { onSelect(i) } label: {
                    HStack(spacing: 10) {
                        Text("\(i + 1)")
                            .font(Theme.pixel(16).weight(.bold))
                            .frame(width: 22)
                        Text(p.display)
                            .font(Theme.digits(28))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer(minLength: 4)
                        if problems.solved.contains(i) {
                            Text("✓").font(Theme.pixel(18).weight(.bold)).foregroundStyle(Theme.tealDeep)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(Theme.ink)
                }
                .buttonStyle(PixelButtonStyle(piece: i == problems.index ? "button" : "button_quiet"))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
        .background(NineSlice(piece: "scroll", scale: 3))
        .hardShadow()
    }
}
