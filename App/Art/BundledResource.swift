import Foundation

enum BundledResource {
  static func decode<Value: Decodable>(_ name: String, as type: Value.Type = Value.self) -> Value {
    guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
      preconditionFailure("Missing bundled resource: \(name).json")
    }
    do {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return try decoder.decode(type, from: Data(contentsOf: url))
    } catch {
      preconditionFailure("Invalid bundled resource \(name): \(error)")
    }
  }
}
