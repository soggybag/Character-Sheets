import Foundation

/// The Classic Fantasy rules tables, loaded from the bundled JSON.
public struct OSERuleset: Sendable {
    public let classes: [ClassRules]
    public let weapons: [WeaponData]
    public let armour: [ArmourData]
    public let ammunition: [AmmunitionData]
    public let gear: [GearData]
    let abilities: AbilityTables
    let encumbrance: EquipmentTables.Encumbrance
    let info: RulesetInfo

    /// The bundled tables. They're checked by the test suite, so loading
    /// can't fail in a shipped build.
    public static let classic: OSERuleset = {
        do {
            return try OSERuleset(bundle: .module)
        } catch {
            fatalError("Bundled OSE rules data is invalid: \(error)")
        }
    }()

    init(bundle: Bundle) throws {
        func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "ose") else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "ose/\(name).json"])
            }
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        }
        classes = try load("classes-classic", as: ClassesFile.self).classes
        let equipment = try load("equipment", as: EquipmentTables.self)
        weapons = equipment.weapons
        armour = equipment.armour
        ammunition = equipment.ammunition
        gear = equipment.gear
        encumbrance = equipment.encumbrance
        abilities = try load("abilities", as: AbilityTables.self)
        info = try load("ruleset", as: RulesetInfo.self)
    }

    /// The Open Game License and copyright notices for the bundled rules data.
    public static var licenseText: String {
        guard let url = Bundle.module.url(forResource: "LICENSE-OGL", withExtension: "md", subdirectory: "ose"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("The OGL text is missing from the bundle.")
        }
        return text
    }

    public var alignments: [String] { info.alignments }
    public var creation: CreationRules { info.creation }

    /// `rules.system` in the files these rules are for, e.g. `ose`.
    public var system: String { info.id }
    /// `rules.variant`, e.g. `classic`.
    public var variant: String { info.variant }
    /// e.g. "Old-School Essentials Classic Fantasy".
    public var displayName: String { "Old-School Essentials " + info.displayName }

    // MARK: Finding the rules for a file

    /// Every ruleset built into the app. Advanced Fantasy goes here.
    public static let all: [OSERuleset] = [.classic]

    /// The built-in rules for a system and variant, ignoring case. A
    /// missing variant means the system's first one (Classic Fantasy for
    /// `ose`).
    public static func named(system: String?, variant: String?) -> OSERuleset? {
        guard let system = system?.lowercased(), !system.isEmpty else { return nil }
        let matching = all.filter { $0.system == system }
        guard let variant = variant?.lowercased(), !variant.isEmpty else { return matching.first }
        return matching.first { $0.variant == variant }
    }

    /// Finds a class by name or id, ignoring case and punctuation
    /// ("Magic-User", "magic user", "magicuser").
    public func classRules(named name: String) -> ClassRules? {
        let key = Self.matchKey(name)
        guard !key.isEmpty else { return nil }
        return classes.first { Self.matchKey($0.name) == key || Self.matchKey($0.id) == key }
    }

    /// The weapon an equipment item refers to, if any.
    public func weapon(named name: String) -> WeaponData? {
        let key = Self.matchKey(name)
        guard !key.isEmpty else { return nil }
        return weapons.first { Self.matchKey($0.name) == key || Self.matchKey($0.id) == key }
    }

    /// The armour (or shield) an equipment item refers to, if any.
    /// "Leather", "Leather armour" and "leather armor" all match.
    public func armour(named name: String) -> ArmourData? {
        var key = Self.matchKey(name)
        for suffix in ["armour", "armor"] where key.hasSuffix(suffix) && key.count > suffix.count {
            key.removeLast(suffix.count)
        }
        guard !key.isEmpty else { return nil }
        return armour.first { Self.matchKey($0.name) == key || Self.matchKey($0.id) == key }
    }

    /// Whether an equipment item is ammunition ("Arrows", "Crossbow bolts").
    /// The packaging in the table's names ("(quiver of 20)") is ignored.
    public func isAmmunition(_ name: String) -> Bool {
        let key = Self.matchKey(name)
        guard !key.isEmpty else { return false }
        return ammunition.contains { ammo in
            let plain = ammo.name.split(separator: "(").first.map(String.init) ?? ammo.name
            return Self.matchKey(plain) == key || Self.matchKey(ammo.id) == key
        }
    }

    /// Lowercased letters and digits only.
    static func matchKey(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains).map(Character.init))
    }
}
