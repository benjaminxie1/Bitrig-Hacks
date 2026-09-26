import Foundation

enum InkReplaySequence {
  static func canContinue(_ asset: InkDemoAsset, completedID: String?, pageSourceID: String?) -> Bool {
    guard let predecessor = asset.continues else { return false }
    // User edits invalidate pageSourceID. An interrupted replay never earns
    // completedID, so metadata cannot resume an incomplete or edited page.
    return predecessor == completedID && predecessor == pageSourceID
  }

  static func ordered(_ assets: [InkDemoAsset], problemID: String) -> [InkDemoAsset] {
    let drawings = assets.filter { $0.problemID == problemID && $0.kind == .drawing }
    // Named problem takes form the recording sequence; generic sample pages
    // remain available separately in the debug menu.
    let named = drawings.filter { $0.id.hasPrefix(problemID + "-") }
    return (named.isEmpty ? drawings : named).sorted { $0.id < $1.id }
  }

  static func next(in assets: [InkDemoAsset], after id: String?) -> InkDemoAsset? {
    guard !assets.isEmpty else { return nil }
    guard let id, let index = assets.firstIndex(where: { $0.id == id }) else { return assets[0] }
    return assets[(index + 1) % assets.count]
  }
}
