import AVFoundation

/// Ports the original chalk cue's three pitches and envelope.
@MainActor
final class ChalkSound {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private var ready = false

  func play() {
    let rate = 44100.0
    let notes = [(1319.0, 0.03), (1760.0, 0.03), (1568.0, 0.05)]
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate * 0.12)),
          let samples = buffer.floatChannelData?[0] else { return }
    var cursor = 0
    for (frequency, seconds) in notes {
      for index in 0..<Int(seconds * rate) {
        let t = Double(index) / rate
        let envelope = min(1, t / 0.005) * exp(-t / seconds * 6)
        samples[cursor] = Float((sin(t * frequency * .pi * 2) >= 0 ? 1.0 : -1.0) * 0.04 * envelope)
        cursor += 1
      }
    }
    buffer.frameLength = AVAudioFrameCount(cursor)
    if !ready {
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: format)
      ready = true
    }
    do {
      if !engine.isRunning { try engine.start() }
      player.scheduleBuffer(buffer)
      player.play()
    } catch { /* Text and ring remain complete when simulator audio is unavailable. */ }
  }
}
