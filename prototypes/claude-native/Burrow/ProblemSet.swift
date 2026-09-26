import Foundation
import Observation

nonisolated struct ProblemFile: Decodable, Sendable {
    let title: String
    let course: String
    let problems: [Problem]
}

nonisolated struct Problem: Decodable, Sendable {
    struct Token: Decodable, Sendable, Hashable {
        let text: String
        var id: String? = nil
    }
    struct Hint: Decodable, Sendable {
        let text: String
        let focus: String
    }
    let tokens: [Token]
    let answer: String
    let hints: [Hint]

    var display: String { tokens.map(\.text).joined(separator: " ") }
}

enum CheckResult { case empty, wrong, correct }
enum Feedback: Equatable { case none, correct, wrong }

@Observable
final class ProblemSetModel {
    let file: ProblemFile
    var index = 0
    var entry = ""
    var feedback: Feedback = .none
    var solved: Set<Int> = []
    var wrongCounts: [Int: Int] = [:]
    /// Bumps on every check so the feedback can re-animate even when it repeats.
    var checkCount = 0

    init() {
        let url = Bundle.main.url(forResource: "Problems", withExtension: "json")!
        file = try! JSONDecoder().decode(ProblemFile.self, from: Data(contentsOf: url))
    }

    var problem: Problem { file.problems[index] }
    var wrongCount: Int { wrongCounts[index, default: 0] }

    func key(_ k: String) {
        if feedback != .correct { feedback = .none }
        guard entry.count < 6 else { return }
        switch k {
        case "−": if entry.isEmpty { entry = "−" }
        case "/": if !entry.isEmpty, !entry.contains("/"), entry != "−" { entry += "/" }
        default: entry += k
        }
    }

    func backspace() {
        if feedback != .correct { feedback = .none }
        if !entry.isEmpty { entry.removeLast() }
    }

    func check() -> CheckResult {
        checkCount += 1
        guard !entry.isEmpty, entry != "−" else { return .empty }
        if Self.value(entry) == Self.value(problem.answer), Self.value(entry) != nil {
            feedback = .correct
            solved.insert(index)
            return .correct
        }
        feedback = .wrong
        wrongCounts[index, default: 0] += 1
        return .wrong
    }

    func advance() {
        index = (index + 1) % file.problems.count
        entry = ""
        feedback = .none
    }

    func select(_ i: Int) {
        index = i
        entry = ""
        feedback = .none
    }

    func reset() {
        index = 0
        entry = ""
        feedback = .none
        solved = []
        wrongCounts = [:]
    }

    /// Compares answers as rationals so 5/2 == 10/4.
    static func value(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: "−", with: "-")
        let parts = t.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 { return n / d }
        return Double(t)
    }
}
