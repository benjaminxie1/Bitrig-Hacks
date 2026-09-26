import SwiftUI
import PencilKit
import AVFoundation
import Observation

@MainActor
@Observable
final class InkPracticeSession {
  let recording: Bool
  let bunny: BunnyState
  let document = InkDocument()
  let recorder = InkRecorder()
  let problems: [PracticeProblem] = BundledResource.decode("Problems")
  private let brain: any BunnyBrain = ScriptedBrain()
  private let reader = InkReader()
  private let speaker = AVSpeechSynthesizer()
  private let chalk = ChalkSound()
  var problemIndex = 0
  var judgement = InkJudgement.empty
  var recognizedLines: [InkLine] = []
  var ring: InkBox?
  var ringProgress = 0.0
  var ringSeed = 1
  var rung = 1
  var revealed = false
  var isReading = false
  var voiceEnabled = false
  var notice: String?
  var readingSource = "On device"
  var showsConfusion = false
  var clock = 0.0
  private var lastEdit = 0.0
  private var readAt: Double?
  private var inviteAt: Double?
  private var revealAt: Double?
  private var nudgeAt: Double?
  private var boardAt: Double?
  private var wrongKey: String?
  private var readGeneration = 0
  private var readTask: Task<Void, Never>?
  private var lastReadRevision = -1
  private var celebrated = false

  var problem: PracticeProblem { problems[problemIndex] }
  var onStage: Bool { bunny.pose == .book || bunny.pose == .tabletop }
  var noteVisible: Bool { revealed && !judgement.note.isEmpty && boardAt != nil }
  var target: InkBox? { judgement.status == .off ? judgement.mark ?? judgement.box : ring }
  var statusText: String {
    if document.isReplaying { return "Writing…" }
    if isReading { return "Reading your work…" }
    if judgement.solved { return "You worked it out" }
    return "Your work, your next step"
  }

  init(recording: Bool) {
    self.recording = recording
    bunny = BunnyState(manifest: BundledResource.decode("RabbitManifest"), recording: recording)
    bunny.message = "Work it out on paper. I'm here beside you."
    document.onEdit = { [weak self] in self?.edited() }
    document.onStrokeEnd = { [weak self] in
      guard let self else { return }
      recorder.capture(document: document)
      lastEdit = clock
      readAt = clock + 1.5
    }
    recorder.onCheckpoint = { [weak self] in self?.requestRead(allowReplay: true) }
  }

  func edited() {
    lastEdit = clock
    readAt = clock + 1.5
    readGeneration += 1
    readTask?.cancel()
    isReading = false
    boardAt = nil
    judgement.note = []
    // Existing rings remain until a confident later read says the line is fixed.
  }

  func configure(layout: InkPageLayout) {
    let old = bunny.pose
    let anchor = layout.bunnyAnchor(mark: target)
    bunny.configure(pose: layout.pose, anchor: anchor, scale: layout.bunnyScale) { [weak self] in
      guard let self, onStage else { return }
      if judgement.status == .off { scheduleReveal() }
    }
    if old != layout.pose {
      requestRead()
      if onStage && bunny.phase == .resting && judgement.status == .off { scheduleReveal() }
      if layout.pose == .flat && judgement.status == .off && !revealed {
        bunny.message = "I think I spotted something. Fold me up and I'll show you."
      }
    }
  }

  func tick(_ dt: Double, reducedMotion: Bool) {
    clock += dt
    bunny.player.reducedMotion = reducedMotion
    bunny.player.tick(dt)
    recorder.tick(dt, document: document)
    if let readAt, clock >= readAt, !document.isDrawing, !document.isReplaying {
      self.readAt = nil
      requestRead()
    }
    if let inviteAt, clock >= inviteAt, judgement.status == .off && !revealed {
      self.inviteAt = nil
      if !onStage {
        bunny.message = "I think I spotted something. Fold me up and I'll show you."
        speak(bunny.message)
      }
    }
    if let revealAt, clock >= revealAt, onStage, bunny.phase == .resting {
      self.revealAt = nil
      revealed = true
      showsConfusion = false
      ring = judgement.mark ?? judgement.box
      ringProgress = reducedMotion ? 1 : 0
      ringSeed += 1
      chalk.play()
      nudgeAt = clock + (reducedMotion ? 0 : 0.68)
      bunny.player.forceState("listening")
    }
    if ring != nil { ringProgress = min(1, ringProgress + dt / 0.68) }
    if let nudgeAt, clock >= nudgeAt {
      self.nudgeAt = nil
      bunny.message = judgement.nudge
      speak(bunny.message)
    }
    if revealed && judgement.status == .off && clock - lastEdit >= 24 && boardAt == nil && !document.isReplaying {
      let note = brain.readInk(lines: recognizedLines, problem: problem, rung: rung, reason: .stall)
      if note.status == .off, note.space != nil {
        judgement.note = note.note
        judgement.space = note.space
        boardAt = clock
      }
    }
  }

  func requestRead(allowReplay: Bool = false) {
    guard !document.isDrawing, !document.isReplaying || allowReplay else { readAt = clock + 1.5; return }
    guard let image = document.image() else { return }
    readTask?.cancel()
    readGeneration += 1
    let generation = readGeneration
    let revision = document.revision
    let truth = document.groundTruth
    let source = document.groundTruthSource
    isReading = true
    readTask = Task { [weak self, reader] in
      do {
        let live = try await reader.read(image)
        guard !Task.isCancelled, let self, generation == readGeneration else { return }
        let lines = InkDemoAsset.resolve(live: live, truth: truth)
        readingSource = source == nil ? "On device" : "Reviewed demo: \(source!)"
        recorder.recordRead(lines)
        accept(lines)
        lastReadRevision = revision
        isReading = false
      } catch {
        guard !Task.isCancelled, let self, generation == readGeneration else { return }
        if let truth { accept(truth) }
        else {
          judgement.status = .unclear
          bunny.message = "I can't quite read that line. Can you write it a little bigger?"
        }
        isReading = false
      }
    }
  }

  private func accept(_ lines: [InkLine]) {
    recognizedLines = lines
    var next = brain.readInk(lines: lines, problem: problem, rung: 1, reason: .ink)
    if next.status == .off, let line = next.line {
      let key = "\(line):\(MathNormalizer.fingerprint(next.lines[line - 1]))"
      let same = key == wrongKey
      rung = same ? min(3, rung + 1) : 1
      next = brain.readInk(lines: lines, problem: problem, rung: rung, reason: .ink)
      if !same {
        wrongKey = key
        revealed = false
        ring = nil
        boardAt = nil
        showsConfusion = true
        inviteAt = clock + 1.2
        bunny.player.forceState("confused")
        if !onStage { bunny.message = "Let me follow that step." }
      }
      judgement = next
      if onStage {
        if !same || !revealed { scheduleReveal() }
        else { ring = next.mark ?? next.box; bunny.message = next.nudge }
      } else if revealed { bunny.message = next.nudge }
    } else if next.status == .ok {
      let priorLine = judgement.line
      // Do not erase a ring while its line is just being rewritten mid-step.
      let stillGrowing = priorLine.flatMap { index in next.lines.indices.contains(index - 1) ? next.lines[index - 1] : nil }
        .map(MathNormalizer.isUnfinished) ?? false
      if !stillGrowing {
        ring = nil; revealed = false; wrongKey = nil
        showsConfusion = false; inviteAt = nil; revealAt = nil; nudgeAt = nil
        boardAt = nil
      }
      judgement = next
      if next.solved && !celebrated {
        celebrated = true
        bunny.player.forceState("celebrate")
        bunny.message = "You worked it out. That was your thinking."
        speak(bunny.message)
      } else if !next.solved && !stillGrowing {
        bunny.message = "I'm following your working."
        bunny.player.setState("idle")
      }
    } else {
      judgement = next
      showsConfusion = false
      inviteAt = nil; revealAt = nil; nudgeAt = nil
      if !next.lines.isEmpty { bunny.message = next.nudge }
      bunny.player.setState("listening")
    }
  }

  private func scheduleReveal() {
    guard judgement.status == .off, !revealed else { return }
    // The sprite arrives first. Root placement follows the line's normalized
    // target; a brief settle precedes the source's 680 ms chalk-ring stroke.
    revealAt = clock + 0.35
  }

  func importPhoto(_ data: Data) {
    guard let photo = UIImage(data: data) else { notice = "That image could not be opened."; return }
    recorder.stopReplay(document: document)
    document.clear()
    document.photo = photo
    clearDiagnosis()
    edited()
    requestRead()
  }

  func newPage() {
    recorder.stopReplay(document: document)
    document.clear()
    clearDiagnosis()
    bunny.message = "Work it out on paper. I'm here beside you."
  }

  func nextProblem() {
    problemIndex = (problemIndex + 1) % problems.count
    newPage()
  }

  func replay() {
    let assets = InkRecorder.assets().filter { $0.0.problemID == problem.id && $0.0.kind == .drawing }
    guard let (asset, _) = assets.last else {
      if !recording { notice = "Record some ink first, or bundle a reviewed recording with scripts/bundle-ink.py." }
      return
    }
    clearDiagnosis()
    recorder.startReplay(asset, document: document)
  }

  func load(_ asset: InkDemoAsset, directory: URL) {
    guard let index = problems.firstIndex(where: { $0.id == asset.problemID }) else { return }
    problemIndex = index
    newPage()
    if asset.kind == .drawing { recorder.startReplay(asset, document: document) }
    else if let data = try? Data(contentsOf: directory.appendingPathComponent(asset.file)), let image = UIImage(data: data) {
      document.photo = image
      document.groundTruth = asset.truth(at: .greatestFiniteMagnitude)
      document.groundTruthSource = asset.verified ? asset.id : nil
      requestRead()
    }
  }

  private func clearDiagnosis() {
    readGeneration += 1; readTask?.cancel(); isReading = false
    judgement = .empty; recognizedLines = []; ring = nil; revealed = false
    wrongKey = nil; rung = 1; celebrated = false; showsConfusion = false
    inviteAt = nil; revealAt = nil; nudgeAt = nil; boardAt = nil; readAt = nil
    lastEdit = clock; lastReadRevision = -1
  }

  private func speak(_ text: String) {
    guard voiceEnabled else { return }
    speaker.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.rate = 0.46
    speaker.speak(utterance)
  }
}
