import Foundation

/// One character's sheet at a glance, for the party view. Each number is the
/// stored value, or the rules value when nothing is stored (as the sheet shows it).
public struct PartyMember: Identifiable, Sendable {
    public let url: URL
    public let name: String
    public let className: String?
    public let level: Int?
    public let currentHP: Int?
    public let maxHP: Int?
    public let ac: Int?
    /// THAC0, or the attack bonus when the character uses ascending AC.
    public let attack: Int?
    public let ascendingAC: Bool
    /// Keyed by save (`death`, `wands`, `paralysis`, `breath`, `spells`).
    public let saves: [String: Int]
    public let xp: Int?
    public let readyToLevelUp: Bool
    /// The rules warnings on this character's sheet.
    public let warnings: [String]

    public var id: URL { url }

    public static let saveKeys = ["death", "wands", "paralysis", "breath", "spells"]

    public init(file: CharacterFile, url: URL, equipmentList: EquipmentList? = nil) {
        let analysis = RulesAnalysis(file, equipmentList: equipmentList)
        func number(_ path: NodePath) -> Int? { analysis.value(at: path, in: file) }
        self.url = url
        name = file.name ?? url.deletingPathExtension().lastPathComponent
        className = file.string(["class"]).flatMap { $0.isEmpty ? nil : $0 }
        level = file.int(["level"])
        currentHP = file.int(["hp", "current"])
        maxHP = number(["hp", "max"])
        ac = number(["combat", "ac"])
        ascendingAC = file.usesAscendingAC
        attack = number(ascendingAC ? ["combat", "attackBonus"] : ["combat", "thac0"])
        var saves: [String: Int] = [:]
        for key in Self.saveKeys {
            saves[key] = number(["saves", .key(key)])
        }
        self.saves = saves
        xp = file.int(["xp"])
        readyToLevelUp = analysis.xp?.readyToLevelUp ?? false
        warnings = analysis.notes.filter { $0.kind == .warning }.map(\.message)
    }

    /// The characters in a folder (not its subfolders), by name. Markdown
    /// files that aren't characters, and files that can't be read, are left out.
    public static func load(folder: URL, equipmentList: EquipmentList? = nil) -> [PartyMember] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return urls
            .filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }
            .compactMap { url -> PartyMember? in
                guard let text = try? String(contentsOf: url, encoding: .utf8),
                      let file = try? CharacterFile(text: text), file.isCharacter else { return nil }
                return PartyMember(file: file, url: url, equipmentList: equipmentList)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
