import Foundation
import Testing
@testable import BurrowCore

/// Real Khan Academy linear-equation forms: the web tab must find the right problem (or refuse),
/// and the step judge must read working in the problem's own letter.
@Suite struct KhanHomeworkTests {
  func form(_ s: String, _ v: Character? = nil) -> LinearForm? { LinearParser.parse(s, variable: v)?.form }
  func r(_ n: Int64, _ d: Int64 = 1) -> Rational { Rational(n, d)! }

  @Test func parsesDistributionLikeTermsFractionsAndDecimals() {
    #expect(form("−2(w−7)") == LinearForm(coef: r(-2), konst: r(14)))
    #expect(form("−f+2+4f") == LinearForm(coef: r(3), konst: r(2)))
    #expect(form("8−3f") == LinearForm(coef: r(-3), konst: r(8)))
    #expect(form("w/3 + 2") == LinearForm(coef: r(1, 3), konst: r(2)))
    #expect(form("0.5x - 1.25") == LinearForm(coef: r(1, 2), konst: r(-5, 4)))
    #expect(form("3(x + 1)/2") == LinearForm(coef: r(3, 2), konst: r(3, 2)))
    #expect(form("-(y+4)") == LinearForm(coef: r(-1), konst: r(-4)))
  }

  @Test func refusesAnythingNonlinearOrMalformed() {
    for text in ["2/(2q+3)", "x^2 + 1", "x*x", "3x 5", "x + y", "Solve", "x+", "*", "", "1/0", "2 3", "(x+1"] {
      #expect(form(text) == nil, "\(text) should be refused")
    }
    #expect(form("w + 1", "x") == nil)  // wrong letter for this problem
  }

  @Test func detectsKhanProblemsAndRefusesNonlinearOnes() throws {
    let two = try #require(LinearEquation.detect(in: "−2(w−7)=18"))
    #expect(two.variable == "w" && two.solution == r(-2))
    let both = try #require(LinearEquation.detect(in: "−f+2+4f=8−3f"))
    #expect(both.variable == "f" && both.solution == r(1))
    #expect(LinearEquation.detect(in: "6g=48")?.solution == r(8))
    #expect(LinearEquation.detect(in: "(2)/(2q+3)=18")?.solution == r(-13, 9))  // cross-multiplied
    #expect(LinearEquation.detect(in: #"\frac{w}{3}+2=5"#)?.solution == r(9))
    #expect(LinearEquation.detect(in: #"\frac{2}{2q+3}=18"#)?.solution == r(-13, 9))
    #expect(LinearEquation.detect(in: "x^2 + 1 = 5") == nil)
    #expect(LinearEquation.detect(in: "(x)/(x+1)=2") == nil)  // variable on top and bottom
    #expect(LinearEquation.detect(in: "20 = 3x + 5")?.solution == r(5))
  }

  @Test func findsTheEquationInsideSentences() throws {
    let riverside = "Solve for x, showing each step of your working:\n3x + 5 = 20\nYour working"
    #expect(LinearEquation.detect(in: riverside)?.problem.id == "p1")
    #expect(LinearEquation.detect(in: "Solve for x: 3x + 5 = 20")?.problem.id == "p1")
    #expect(LinearEquation.detect(in: "The answer is a 2x - 3 = 7 problem")?.solution == r(5))
    #expect(LinearEquation.detect(in: "w = ?") == nil)
  }

  @Test func judgesWorkingInTheProblemsLetter() throws {
    let problem = try #require(LinearEquation.detect(in: "−2(w−7)=18")).problem
    #expect(problem.letter == "w" && problem.answer == -2)
    let good = StepJudge.judge(problem: problem, working: "−2(w−7)=18\n−2w+14=18\n−2w=4\nw=−2")
    #expect(good.judged && good.firstWrongStep == nil && good.solved)
    let slip = StepJudge.judge(problem: problem, working: "−2(w−7)=18\n−2w−14=18\n−2w=32")
    #expect(slip.firstWrongStep == 2 && slip.steps[1].category == .sign)
    // Working in another letter isn't this problem's working.
    #expect(StepJudge.parseWorkingLine("x = −2", variable: "w") == nil)
  }

  @Test func bothSidesProblemJudgesAndSolves() throws {
    let problem = try #require(LinearEquation.detect(in: "−f+2+4f=8−3f")).problem
    #expect(abs(problem.answer - 1) < 1e-9)
    let good = StepJudge.judge(problem: problem, working: "−f+2+4f=8−3f\n3f+2=8−3f\n6f=6\nf=1")
    #expect(good.firstWrongStep == nil && good.solved)
  }

  @Test func letterAwareNormalizer() {
    #expect(MathNormalizer.normalize("W = -2", variable: "w") == "w = -2")
    #expect(MathNormalizer.normalize("3X + 5 = 2O", variable: "x") == MathNormalizer.normalize("3X + 5 = 2O"))
    #expect(MathNormalizer.normalize("2l + 1 = 7", variable: "l") == "2l + 1 = 7")
  }
}

@Suite struct KhanRationalAndCopyTests {
  @Test func rationalIntroIsCrossMultiplied() throws {
    let eq = try #require(LinearEquation.detect(in: "(2)/(2q+3)=(1)/(8)"))
    #expect(eq.variable == "q" && eq.solution == Rational(13, 2)!)
    #expect(eq.text == "2/(2q+3)=1/8")
    let problem = eq.problem
    // The student's first real step, 16 = 2q + 3, is linear and holds.
    let judged = StepJudge.judge(problem: problem, working: "16 = 2q + 3\n13 = 2q\nq = 13/2")
    #expect(judged.firstWrongStep == nil && judged.solved)
    #expect(LinearEquation.detect(in: "(2)/(2q+3)=(1)/(0)") == nil)
  }

  @Test func copyingTheProblemIsNeverUnclear() {
    let problem = LinearEquation.detect(in: "(2)/(2q+3)=(1)/(8)")!.problem
    let box = InkBox(x: 0.1, y: 0.1, w: 0.5, h: 0.05)
    let lines = [InkLine(text: "2/(2q+3) = 1/8", box: box, tokens: [], confidence: 0.9),
                 InkLine(text: "16 = 2q + 3", box: InkBox(x: 0.1, y: 0.2, w: 0.5, h: 0.05), tokens: [], confidence: 0.9)]
    let verdict = InkJudge.judge(lines: lines, problem: problem, rung: 1)
    #expect(verdict.status == .ok)
  }
}

@Suite struct HandwritingRepairTests {
  @Test func lookalikeDigitsBecomeTheLetterOnlyWhenTheLineWouldBeFalse() {
    #expect(MathNormalizer.repairLookalikes("69=48", variable: "g") == "6g=48")
    #expect(MathNormalizer.repairLookalikes("9 = 8", variable: "g") == "g = 8")
    #expect(MathNormalizer.repairLookalikes("16=29+3", variable: "q") == "16=2q+3")
    #expect(MathNormalizer.repairLookalikes("13= 20", variable: "q") == "13= 2q")
    // True arithmetic and lines that already use the letter are never touched.
    #expect(MathNormalizer.repairLookalikes("20-5=15", variable: "g") == "20-5=15")
    #expect(MathNormalizer.repairLookalikes("g=9", variable: "g") == "g=9")
    #expect(MathNormalizer.repairLookalikes("x=9", variable: "x") == "x=9")
  }

  @Test func cyrillicLookalikesReadAsMath() {
    #expect(MathNormalizer.normalize("У=З", variable: "y") == "y=3")
    #expect(MathNormalizer.normalize("4у = 12", variable: "y") == "4y = 12")
  }
}
