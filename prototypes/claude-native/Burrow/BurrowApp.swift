import SwiftUI

@main
struct BurrowApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden(false)
        }
    }
}

/// Launch arguments:
/// - `-recording`: no debug UI, day scene, no speech, seeded randomness, fixed timers.
/// - `-pose flat|tabletop|book|closed`: force a simulated pose (backup for recording).
/// - `-speech`: turn spoken lines on (off by default in recording mode).
enum AppConfig {
    static let arguments = ProcessInfo.processInfo.arguments
    static let isRecording = arguments.contains("-recording")
    static let forcedPose: Pose? = {
        guard let i = arguments.firstIndex(of: "-pose"), i + 1 < arguments.count else { return nil }
        return Pose(rawValue: arguments[i + 1])
    }()
    static let speechDefault = arguments.contains("-speech") || !isRecording
}

/// SplitMix64, so every recording take hops and fidgets the same way.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}

enum RNG {
    static var shared = SeededRandom(seed: AppConfig.isRecording ? 20260926 : UInt64(Date().timeIntervalSince1970))
    static func next() -> Double { shared.next() }
}
