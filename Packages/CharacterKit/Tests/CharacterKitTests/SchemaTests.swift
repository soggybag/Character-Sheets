import Foundation
import Testing
@testable import CharacterKit

/// The repo's JSON schema for character files.
private let schemaURL = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "schema/character.schema.json")

@Suite("Schema")
struct SchemaTests {
    /// The `properties` of the schema object at a path pattern
    /// (`spells.memorized.*`), following list items and `$ref`s.
    private func properties(at pattern: String, in schema: [String: Any]) -> Set<String>? {
        let defs = schema["$defs"] as? [String: Any] ?? [:]
        func resolve(_ node: [String: Any]) -> [String: Any] {
            guard let ref = node["$ref"] as? String, let name = ref.split(separator: "/").last else { return node }
            return defs[String(name)] as? [String: Any] ?? node
        }
        var node = schema
        for step in pattern.split(separator: ".") {
            if step == "*" {
                guard let items = node["items"] as? [String: Any] else { return nil }
                node = resolve(items)
            } else {
                guard let child = (node["properties"] as? [String: Any])?[String(step)] as? [String: Any] else { return nil }
                node = resolve(child)
            }
        }
        return (node["properties"] as? [String: Any]).map { Set($0.keys) }
    }

    /// Every key the app knows and writes is in the schema, and the schema
    /// has no keys the app doesn't know: they drift apart otherwise.
    @Test func schemaMatchesTheKeysTheAppWrites() throws {
        let schema = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any])
        for (pattern, keys) in Layout.keyOrders {
            let inSchema = try #require(properties(at: pattern, in: schema), "No object in the schema at “\(pattern)”")
            #expect(inSchema == Set(keys), "“\(pattern)”: only in the schema \(inSchema.subtracting(keys).sorted()), only in the app \(Set(keys).subtracting(inSchema).sorted())")
        }
    }
}
