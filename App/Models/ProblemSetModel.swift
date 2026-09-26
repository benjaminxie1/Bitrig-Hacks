import Foundation
import Observation

@MainActor
@Observable
final class ProblemSetModel {
  let problems: [PracticeProblem]
  var selectedIndex = 0
  var input = ""
  var feedback = Feedback.none
  var solved: Set<String> = []
  private var replaceOnNextDigit = false
  private var drafts: [String: String] = [:]

  init(problems: [PracticeProblem]) { self.problems = problems }

  var current: PracticeProblem { problems[selectedIndex] }
  var complete: Bool { solved.count == problems.count }

  func enter(_ key: String) {
    if key == "⌫" {
      if !input.isEmpty { input.removeLast() }
      replaceOnNextDigit = false
    } else {
      if replaceOnNextDigit { input = ""; replaceOnNextDigit = false }
      guard input.count < 12 else { return }
      if key == "−" {
        if input.hasPrefix("−") { input.removeFirst() }
        else { input = "−" + input }
      } else if key == "/" {
        if !input.isEmpty && !input.contains("/") && input != "−" { input += "/" }
      } else { input += key }
    }
    feedback = .none
    drafts[current.id] = input
  }

  @discardableResult
  func check() -> Feedback {
    if input.isEmpty || input == "−" {
      feedback = .empty
    } else if current.accepts(input) {
      solved.insert(current.id)
      feedback = .correct
    } else { feedback = .incorrect }
    replaceOnNextDigit = feedback != .empty
    return feedback
  }

  func select(_ index: Int) {
    guard problems.indices.contains(index) else { return }
    drafts[current.id] = input
    selectedIndex = index
    input = drafts[current.id] ?? ""
    feedback = solved.contains(current.id) ? .correct : .none
    replaceOnNextDigit = feedback == .correct
  }

  func advance() {
    if let next = problems.indices.first(where: { !solved.contains(problems[$0].id) && $0 > selectedIndex }) {
      select(next)
    } else if let next = problems.indices.first(where: { !solved.contains(problems[$0].id) }) {
      select(next)
    }
  }

  enum Feedback: String, Equatable {
    case none, empty, incorrect, correct
    var title: String {
      switch self {
      case .none: "Take your time. You’ve got this."
      case .empty: "Enter an answer first."
      case .incorrect: "Not quite. Try another step."
      case .correct: "Correct! You worked it out."
      }
    }
  }
}
