import Foundation

struct CharacterManifest: Decodable {
  var cell: [Int]
  var idleVariantGap: [Double]
  var wanderGap: [Double]
  var wanderHops: [Int]
  var states: [String: StateDefinition]
  var jumpSequence: JumpSequence

  struct StateDefinition: Decodable {
    var file: String
    var frames: Int
    var fps: Double
    var loop: Bool
    var headDy: [Int]?
    var overlays: [String]?
    var hold: Bool?
    var enter: String?
    var exit: String?
    var variants: [Variant]?
    var move: [Double]?
  }

  struct Variant: Decodable {
    var state: String
    var weight: Double
  }

  struct JumpSequence: Decodable {
    var sending: [Step]
    var receiving: [Step]
  }

  struct Step: Decodable {
    var state: String
    var reverse: Bool?
    var loop: Bool?
  }
}
