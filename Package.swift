// swift-tools-version: 6.0
import PackageDescription

// A dependency-free test harness for the same model and layout sources the
// Bitrig app compiles. App configuration remains in Project.json.
let package = Package(
  name: "BurrowChecks",
  platforms: [.macOS(.v15), .iOS("27.1")],
  products: [.library(name: "BurrowCore", targets: ["BurrowCore"])],
  targets: [
    .target(
      name: "BurrowCore", path: "App",
      exclude: ["Assets.xcassets", "App.swift", "ContentView.swift", "Views", "Web", "Resources/WebDemo",
                "Art/BundledResource.swift", "Art/NineSlice.swift", "Art/PixelArtStore.swift",
                "Art/SpriteView.swift", "Art/BurrowSceneView.swift",
                "Design/PixelButtonStyle.swift", "Design/Theme.swift",
                "Models/PracticeSession.swift", "Pose/PoseModel.swift",
                "Ink/ChalkSound.swift", "Ink/InkChrome.swift", "Ink/InkDocument.swift",
                "Ink/InkPaperView.swift", "Ink/InkPracticeSession.swift", "Ink/InkReader.swift",
                "Ink/InkRecorder.swift", "Ink/PencilPage.swift",
                "Resources/SceneManifest.json", "Resources/UIManifest.json",
                "Resources/VT323.ttf", "Resources/PixelifySans.ttf",
                "Resources/OFL-VT323.txt", "Resources/OFL-PixelifySans.txt", "Resources/burrow.css"],
      sources: ["Models/PracticeProblem.swift", "Models/ProblemSetModel.swift",
                "Models/StruggleTracker.swift", "Models/InterventionEngine.swift",
                "Models/HintLadder.swift", "Models/BunnyBrain.swift", "Models/ScriptedBrain.swift", "Models/BunnyState.swift",
                "Pose/BurrowPose.swift", "Pose/PoseDeriver.swift", "Pose/PoseSnapshot.swift",
                "Pose/PoseProvider.swift", "Pose/LivePoseProvider.swift", "Pose/SimulatedPoseProvider.swift",
                "Design/BurrowLayout.swift", "Art/CharacterManifest.swift", "Art/SpritePlayer.swift",
                "Ink/StepJudge.swift", "Ink/InkJudgement.swift", "Ink/MathNormalizer.swift",
                "Ink/InkNudges.swift", "Ink/InkJudge.swift", "Ink/MockInkJudge.swift",
                "Ink/InkDemoAsset.swift", "Ink/InkPageLayout.swift", "Ink/InkReplaySequence.swift"],
      resources: [.copy("Resources/Problems.json"), .copy("Resources/RabbitManifest.json"), .copy("Resources/InkDemos")]
    ),
    .testTarget(name: "BurrowCoreTests", dependencies: ["BurrowCore"], path: "Tests")
  ]
)
