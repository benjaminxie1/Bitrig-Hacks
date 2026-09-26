import Foundation

enum BurrowPose: String, CaseIterable, Identifiable {
  case flat
  case tabletop
  case book
  case closed

  var id: String { rawValue }
  var title: String { rawValue.capitalized }
}
