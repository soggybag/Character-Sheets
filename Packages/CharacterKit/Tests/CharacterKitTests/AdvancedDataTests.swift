import Foundation
import Testing
@testable import CharacterKit

@Suite("Advanced Fantasy data")
struct AdvancedDataTests {
    let rules = OSERuleset.advanced

    @Test func loadsAndSharesTheClassicTables() {
        #expect(rules.system == "ose" && rules.variant == "advanced")
        #expect(rules.displayName == "Old-School Essentials Advanced Fantasy")
        #expect(rules.weapons.map(\.id) == OSERuleset.classic.weapons.map(\.id))
        #expect(rules.armour.map(\.id) == OSERuleset.classic.armour.map(\.id))
    }

    @Test func notOfferedUntilItHasClassesOfItsOwn() {
        let ownClasses = rules.classes.count > OSERuleset.classic.classes.count
        #expect(ownClasses == OSERuleset.all.contains { $0.variant == "advanced" })
    }

    @Test func includesTheClassicClasses() {
        for classic in OSERuleset.classic.classes {
            let advanced = rules.classes.first { $0.id == classic.id }
            #expect(advanced?.levels.map(\.xp) == classic.levels.map(\.xp), "\(classic.name)")
            #expect(advanced?.levels.map(\.saves) == classic.levels.map(\.saves), "\(classic.name)")
        }
    }

    @Test func inTheBooksOrder() {
        #expect(rules.classes.map(\.name) == [
            "Acrobat", "Assassin", "Barbarian", "Bard", "Cleric", "Drow", "Druid", "Duergar", "Dwarf", "Elf", "Fighter",
            "Gnome", "Half-Elf", "Halfling", "Half-Orc", "Illusionist", "Knight", "Magic-User", "Paladin", "Ranger",
            "Svirfneblin", "Thief"])
        #expect(rules.races.map(\.name) == [
            "Drow", "Duergar", "Dwarf", "Elf", "Gnome", "Half-Elf", "Halfling", "Half-Orc", "Human", "Svirfneblin"])
    }

    @Test(arguments: [OSERuleset.classic, OSERuleset.advanced])
    func skillsMatchTheTable(rules: OSERuleset) {
        for classRules in rules.classes {
            let keys = classRules.skills.map { Set($0.map(\.key)) }
            for row in classRules.levels {
                #expect(row.thiefSkills.map { Set($0.keys) } == keys, "\(classRules.name) \(row.level)")
            }
        }
    }

    @Test func weaponAndArmourIDsExist() {
        let weapons = Set(rules.weapons.map(\.id)), armour = Set(rules.armour.map(\.id))
        for classRules in rules.classes {
            for id in (classRules.weapons.allowed ?? []) + (classRules.weapons.forbidden ?? []) {
                #expect(weapons.contains(id), "\(classRules.name): \(id)")
            }
            for id in classRules.armour.allowed { #expect(armour.contains(id), "\(classRules.name): \(id)") }
        }
        for race in rules.races {
            for id in race.weapons?.forbidden ?? [] { #expect(weapons.contains(id), "\(race.name): \(id)") }
        }
    }

    @Test func humansCanBeAnyHumanClass() throws {
        let human = try #require(rules.raceRules(named: "human"))
        for classRules in rules.classes {
            #expect(human.maxLevel(classID: classRules.id) == (classRules.race == "Human" ? classRules.maxLevel : nil),
                    "\(classRules.name)")
        }
    }

    @Test func classicHasNoRaces() {
        #expect(OSERuleset.classic.races.isEmpty)
    }

    @Test(arguments: [OSERuleset.classic, OSERuleset.advanced])
    func everyClassHasARowPerLevel(rules: OSERuleset) {
        for classRules in rules.classes {
            #expect(classRules.levels.map(\.level) == Array(1...classRules.maxLevel), "\(classRules.name)")
            #expect(classRules.levels.map(\.xp) == classRules.levels.map(\.xp).sorted(), "\(classRules.name)")
        }
    }

    @Test func racesNameRealClassesAndLevels() {
        for race in rules.races {
            for (classID, maxLevel) in race.classes {
                let classRules = rules.classes.first { $0.id == classID }
                #expect(classRules != nil, "\(race.name): no class \(classID)")
                if let classRules { #expect((1...classRules.maxLevel).contains(maxLevel), "\(race.name) \(classID)") }
            }
        }
    }

    /// Spot checks against the book's Dwarf race.
    @Test func dwarf() throws {
        let dwarf = try #require(rules.raceRules(named: "DWARF"))
        #expect(dwarf.plural == "Dwarves" && dwarf.requirements == ["con": 9])
        #expect(dwarf.abilityModifiers == ["con": 1, "cha": -1] && dwarf.maximums.isEmpty)
        #expect(dwarf.classes == ["assassin": 9, "cleric": 8, "fighter": 10, "thief": 9])
        #expect(dwarf.maxLevel(classID: "magic-user") == nil)
        #expect(dwarf.weapons?.forbidden == ["long-bow", "two-handed-sword"])
        #expect(dwarf.infravision == 60 && dwarf.exploration?["listen"] == 2)
    }

    @Test func raceFormat() throws {
        let json = """
            {"id": "half-elf", "name": "Half-Elf", "plural": "Half-Elves",
             "requirements": {"con": 9, "int": 9}, "maximums": {}, "abilityModifiers": {},
             "languages": ["Alignment", "Common", "Elvish"], "infravision": 30,
             "features": [{"id": "x", "name": "X", "summary": "Y"}],
             "classes": {"fighter": 12}}
            """
        let race = try JSONDecoder().decode(RaceRules.self, from: Data(json.utf8))
        #expect(race.plural == "Half-Elves")
        #expect(race.maxLevel(classID: "fighter") == 12 && race.maxLevel(classID: "cleric") == nil)
        #expect(race.exploration == nil)

        let gnome = try JSONDecoder().decode(RaceRules.self, from: Data(
            json.replacingOccurrences(of: #""name": "Half-Elf", "plural": "Half-Elves","#, with: #""name": "Gnome","#).utf8))
        #expect(gnome.plural == "Gnomes")
    }
}

@Suite("Advanced Fantasy classes")
struct AdvancedClassTests {
    let rules = OSERuleset.advanced

    /// Spot checks against the book's Druid Level Progression table.
    @Test func druid() throws {
        let druid = try #require(rules.classRules(named: "druid"))
        #expect(druid.maxLevel == 14 && druid.hitDie == "d6" && druid.primeRequisites == ["wis"])
        #expect(druid.alignments == ["Neutral"])
        #expect(druid.armour.allowed == ["leather"] && druid.armour.shields)
        #expect(druid.spellcasting?.type == "divine" && druid.spellcasting?.fromLevel == 1)
        #expect(druid.features.map(\.id) == ["divine-magic", "no-metal", "energy-resistance", "identification", "druidic",
                                              "path-finding", "pass-without-trace", "charm-immunity", "shape-change",
                                              "magic-items", "druid-hierarchy", "stronghold"])
        let first = try #require(druid.row(level: 1))
        #expect(first.xp == 0 && first.thac0 == 19 && first.spells == [1])
        #expect(first.saves == ["death": 11, "wands": 12, "paralysis": 14, "breath": 16, "spells": 15])
        let fifth = try #require(druid.row(level: 5))
        #expect(fifth.xp == 12500 && fifth.thac0 == 17 && fifth.spells == [2, 2, 1, 1])
        let tenth = try #require(druid.row(level: 10))
        #expect(tenth.hd == "9d6+1" && tenth.conModifier == false && tenth.xp == 125000)
        let last = try #require(druid.row(level: 14))
        #expect(last.xp == 1_500_000 && last.thac0 == 12 && last.spells == [6, 6, 5, 5, 5])
        #expect(last.saves == ["death": 3, "wands": 5, "paralysis": 7, "breath": 8, "spells": 7])
    }

    @Test func druidsMustBeNeutral() throws {
        func notes(_ alignment: String) throws -> [String] {
            let file = try CharacterFile(text: """
                ---
                formatVersion: 1
                rules: { system: ose, variant: advanced }
                class: Druid
                level: 1
                alignment: \(alignment)
                ---

                """)
            return RulesAnalysis(file, rules: rules).notes.map(\.message)
        }
        #expect(try notes("Lawful").contains("Druids must be Neutral (this one is Lawful)."))
        #expect(try !notes("neutral").contains { $0.hasPrefix("Druids must be") })
    }

    /// Spot checks against the book's tables.
    @Test func bookSpotChecks() throws {
        func row(_ name: String, _ level: Int) throws -> ClassRules.LevelRow {
            try #require(rules.classRules(named: name)?.row(level: level))
        }
        let barbarian = try row("Barbarian", 5)
        #expect(barbarian.xp == 18500 && barbarian.thac0 == 17)
        #expect(barbarian.saves == ["death": 8, "wands": 11, "paralysis": 10, "breath": 13, "spells": 13])
        #expect(barbarian.thiefSkills == ["climb": 91, "hide": 30, "moveSilently": 37])
        let knight = try row("Knight", 13)
        #expect(knight.xp == 790_000 && knight.hd == "9d8+8" && knight.thac0 == 10)
        #expect(knight.saves == ["death": 4, "wands": 5, "paralysis": 6, "breath": 5, "spells": 8])
        #expect(try row("Bard", 1).spells == [] && row("Bard", 14).spells == [4, 4, 3, 3])
        #expect(try row("Drow", 1).spells == [1] && row("Drow", 10).xp == 600_000)
        #expect(try row("Assassin", 6).thiefSkills == ["assassination": -2, "climb": 92, "hearNoise": 3, "hide": 33, "moveSilently": 43])
        #expect(try row("Ranger", 12).thiefSkills == ["tracking": 110] && row("Ranger", 8).spells == [1])
        #expect(try row("Illusionist", 14).spells == [4, 4, 4, 4, 3, 3])
        #expect(try row("Half-Orc", 6).thiefSkills == ["hide": 36, "moveSilently": 45, "pickPockets": 45])
        #expect(try row("Svirfneblin", 8).xp == 160_000 && row("Gnome", 8).spells == [3, 3, 2, 2])

        let halfElf = try #require(rules.raceRules(named: "Half-Elf"))
        #expect(halfElf.classes.count == 11 && halfElf.maxLevel(classID: "cleric") == 5)
        let halfOrc = try #require(rules.raceRules(named: "half orc"))
        #expect(halfOrc.abilityModifiers == ["cha": -2, "con": 1, "str": 1])
    }

    @Test func onlySomeDivineCastersNeedAHolySymbol() throws {
        func needs(_ name: String) throws -> Bool { try #require(rules.classRules(named: name)?.spellcasting).needsHolySymbol }
        #expect(try needs("Cleric") && needs("Druid") && needs("Drow") && needs("Paladin"))
        #expect(try !needs("Bard") && !needs("Ranger") && !needs("Magic-User"))
    }
}
