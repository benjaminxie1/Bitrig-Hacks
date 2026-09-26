import Foundation
import Testing
@testable import BurrowCore

struct InkTests {
  let problem = PracticeProblem(id: "p1", title: "Problem 1", coefficient: 3, constant: 5,
    rightSide: 20, equation: "3x + 5 = 20", focusTerm: "+ 5", hints: [])

  // Every case from upstream shared/src/steps.test.ts is covered below.
  @Test func parsesCoefficientsConstantsFractionsAndUnaryMinus() {
    #expect(StepJudge.parseLinearSide("3x + 5") == LinearSide(coef: 3, konst: 5))
    #expect(StepJudge.parseLinearSide("20 - 5") == LinearSide(coef: 0, konst: 15))
    #expect(StepJudge.parseLinearSide("-x") == LinearSide(coef: -1, konst: 0))
    #expect(StepJudge.parseLinearSide("15/3") == LinearSide(coef: 0, konst: 5))
    #expect(StepJudge.parseLinearSide("2*x - 1") == LinearSide(coef: 2, konst: -1))
    #expect(StepJudge.parseLinearSide("−2x") == LinearSide(coef: -2, konst: 0))
  }

  @Test func rejectsNonlinearAndMalformedExpressions() {
    for text in ["x^2 + 1", "3x 5", "", "1/0", "x+", "*"] { #expect(StepJudge.parseLinearSide(text) == nil) }
    #expect(StepJudge.parseWorkingLine("just thinking out loud") == nil)
    #expect(StepJudge.parseWorkingLine("3x + 5 = 20 = 15") == nil)
  }

  @Test func acceptsCorrectDerivation() {
    let result = StepJudge.judge(problem: problem, working: "3x + 5 = 20\n3x = 15\nx = 15/3\nx = 5")
    #expect(result.judged && result.solved && result.firstWrongStep == nil)
    #expect(result.steps.allSatisfy { $0.ok == true })
  }

  @Test func detectsFirstSignAndArithmeticSlips() {
    let sign = StepJudge.judge(problem: problem, working: "3x + 5 = 20\n3x = -15\nx = -5")
    #expect(sign.firstWrongStep == 2 && sign.steps[1].category == .sign && !sign.solved)
    let arithmetic = StepJudge.judge(problem: problem, working: "3x + 5 = 20\n3x = 25\nx = 25/3")
    #expect(arithmetic.firstWrongStep == 2 && arithmetic.steps[1].category == .arithmetic)
    #expect(arithmetic.steps[2].ok == false)
  }

  @Test func skipsUnparseableAndDeclinesUnsupportedProblem() {
    let result = StepJudge.judge(problem: problem, working: "first I move the 5\n3x = 15\nx = 5")
    #expect(result.steps[0].ok == nil && result.firstWrongStep == nil && result.solved)
    #expect(!StepJudge.judge(problem: nil, working: "x = 5").judged)
  }

  @Test func verdictContainsNoCorrectedValues() throws {
    var step = try #require(StepJudge.judge(problem: problem, working: "3x = 25").steps.first)
    step.line = ""
    let json = String(decoding: try JSONEncoder().encode(step), as: UTF8.self)
    #expect(!json.contains("15") && !json.contains("\"5\""))
  }

  @Test func reportsPlanProgress() {
    #expect(StepJudge.judge(problem: problem, working: "3x + 5 = 20").planStep == 0)
    #expect(StepJudge.judge(problem: problem, working: "3x + 5 = 20\n3x = 15").planStep == 1)
    #expect(StepJudge.judge(problem: problem, working: "3x + 5 = 20\n3x = 15\nx = 5").planStep == 2)
  }

  @Test func remoteShapeDiscardsModelTextAndClampsProgress() throws {
    let raw: [String: Any] = ["judged": true, "solved": true, "planStep": 99,
      "steps": [["step": 1, "ok": true], ["step": 2, "ok": false, "category": "it should say photosynthesis",
      "line": "LEAK", "fix": "LEAK"], ["step": 9, "ok": false]]]
    let working = "plants make food from light\n\nso they need soil to eat\nthe answer is soil"
    let result = StepJudge.parseJudgement(raw, working: working, planLength: 3)
    let json = String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
    #expect(!json.contains("LEAK") && !json.contains("photosynthesis"))
    #expect(result.steps.map(\.line) == StepJudge.splitWorking(working))
    #expect(result.steps[1].ok == false && result.steps[1].category == .unknown)
    #expect(result.steps[2].ok == nil && result.firstWrongStep == 2 && !result.solved && result.planStep == 3)
    #expect(!StepJudge.parseJudgement(nil, working: "a\nb", planLength: 2).judged)
    #expect(!StepJudge.parseJudgement(["judged": false, "steps": []], working: "a\nb", planLength: 2).judged)
    #expect(!StepJudge.parseJudgement(["judged": true, "steps": []], working: "", planLength: 2).judged)
  }

  @Test func normalizesOCRWithoutChangingTokenLengths() {
    #expect(MathNormalizer.normalize("3X − l = 2O3") == "3x - 1 = 203")
    #expect(MathNormalizer.normalize("1S2 + I – 4×") == "152 + 1 - 4x")
    #expect(MathNormalizer.normalize("S + O") == "S + O")
    for unfinished in ["3x =", "3x = 20 -", "x = 15/", "3x +", "x = 5."] {
      #expect(MathNormalizer.isUnfinished(unfinished))
    }
    #expect(!MathNormalizer.isUnfinished("3x = 25"))
  }

  private func lines(_ text: [String], confidence: Double = 0.99) -> [InkLine] {
    text.enumerated().map { index, value in
      InkLine(text: value, box: InkBox(x: 0.1, y: 0.1 + Double(index) * 0.12, w: 0.7, h: 0.05),
        tokens: value.components(separatedBy: " ").enumerated().map { column, token in
          InkToken(text: token, box: InkBox(x: 0.1 + Double(column) * 0.1, y: 0.1 + Double(index) * 0.12, w: 0.08, h: 0.05))
        }, confidence: confidence)
    }
  }

  @Test func boxesChangedNumberAndNeverJudgesUnfinishedLastLine() {
    let input = lines(["3x + 5 = 20", "3x = 25"])
    let result = InkJudge.judge(lines: input, problem: problem, rung: 1)
    #expect(result.status == .off && result.line == 2)
    #expect(result.mark == input[1].tokens.last?.box)
    #expect(result.box == input[1].box)
    for last in ["3x =", "3x = 20 -", "3x = 15/"] {
      #expect(InkJudge.judge(lines: lines(["3x + 5 = 20", last]), problem: problem, rung: 1).status == .ok)
    }
  }

  @Test func uncertaintyCannotAccuseOrClaimSolved() {
    #expect(InkJudge.judge(lines: lines(["3x = 25"], confidence: 0.4), problem: problem, rung: 1).status == .unclear)
    #expect(InkJudge.judge(lines: lines(["3y + x = 25"]), problem: problem, rung: 1).status == .unclear)
    #expect(!InkJudge.judge(lines: lines(["3x = 25", "x = 5"]), problem: problem, rung: 1).solved)
    #expect(!InkJudge.judge(lines: lines(["x = 5", "x ="]), problem: problem, rung: 1).solved)
    #expect(InkJudge.judge(lines: lines(["3x = 15", "x = 5"]), problem: problem, rung: 1).solved)
  }

  @Test func nudgesRespectRungAndNeverBorrowNumbersForAnalogies() {
    let text = ["3x + 5 = 20", "3x = 25"]
    for category in StepCategory.allCases {
      for rung in 1...3 {
        let nudge = InkNudges.text(category: category, rung: rung, lines: text)
        #expect(nudge.split(separator: " ").count < 15)
        #expect(!nudge.contains("!") && !nudge.contains("—") && !nudge.contains("-"))
        #expect(!nudge.contains("x = 5") && !nudge.contains("15"))
        if rung == 3 { #expect(Set(InkNudges.numbers(in: nudge)).isDisjoint(with: [3, 5, 20, 25])) }
      }
    }
  }

  @Test func stallBoardUsesEmptySpaceAndOnlyOffGetsNote() throws {
    let input = lines(["3x + 5 = 20", "3x = 25"])
    let result = InkJudge.judge(lines: input, problem: problem, rung: 2, reason: .stall)
    let space = try #require(result.space)
    #expect(!result.note.isEmpty)
    #expect(input.allSatisfy { !$0.box.rect.intersects(space.rect) })
    #expect(InkJudge.judge(lines: lines(["3x ="]), problem: problem, rung: 1, reason: .stall).note.isEmpty)
  }

  @Test func flatAndBookKeepIdenticalPaperAndUniformTabletopCoordinates() {
    let fold = CGRect(x: 460, y: 0, width: 24, height: 650)
    let size = CGSize(width: 940, height: 650)
    let flat = InkPageLayout(snapshot: .init(pose: .flat, division: nil, occlusions: [], size: size, isSimulated: false, inactiveDivision: fold))
    let book = InkPageLayout(snapshot: .init(pose: .book, division: fold, occlusions: [], size: size, isSimulated: false, inactiveDivision: fold))
    #expect(flat.page == book.page)
    #expect(flat.page.maxX <= fold.minX)
    let table = InkPageLayout(snapshot: .init(pose: .tabletop, division: CGRect(x: 0, y: 440, width: 650, height: 24),
      occlusions: [], size: CGSize(width: 650, height: 940), isSimulated: false))
    #expect(table.page.minY > 464)
    #expect(abs(table.page.height / table.page.width - flat.page.height / flat.page.width) < 0.00001)
    let box = InkBox(x: 0.3, y: 0.2, w: 0.1, h: 0.05)
    #expect(abs(box.inPage(table.page).width / table.page.width - 0.1) < 0.00001)
  }

  @Test func exactInkWireShapeAndReviewedDemoFallback() throws {
    let result = MockInkJudge.judge(.init(seq: 1, rung: 2))
    let data = try JSONEncoder().encode(result)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["confidence"] != nil && object["rung"] == nil)
    #expect(result.status == .off && result.line == 2)
    #expect(MockInkJudge.judge(.init(seq: 2)).solved)
    let truth = lines(["3x + 5 = 20", "3x = 25"])
    #expect(InkDemoAsset.resolve(live: lines(["3x = 2S"]), truth: truth) == truth)
    #expect(InkDemoAsset.resolve(live: truth, truth: nil) == truth)
  }
}
