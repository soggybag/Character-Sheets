import Foundation
import Testing
@testable import CharacterKit

private let examples = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "examples")

private func example(_ name: String) throws -> CharacterFile {
    try CharacterFile(text: String(contentsOf: examples.appending(path: "\(name).md"), encoding: .utf8))
}

private func messages(_ analysis: RulesAnalysis) -> [String] { analysis.notes.map(\.message) }

@Suite("Rules data")
struct RulesDataTests {
    let rules = OSERuleset.classic

    @Test func loadsAllClasses() {
        #expect(rules.classes.map(\.name) == ["Cleric", "Dwarf", "Elf", "Fighter", "Halfling", "Magic-User", "Thief"])
        #expect(rules.weapons.count == 22)
    }

    @Test func everyClassHasARowPerLevel() {
        for classRules in rules.classes {
            #expect(classRules.levels.map(\.level) == Array(1...classRules.maxLevel), "\(classRules.name)")
            #expect(classRules.levels.map(\.xp) == classRules.levels.map(\.xp).sorted(), "\(classRules.name)")
        }
    }

    @Test(arguments: [("magic-user", "Magic-User"), ("Magic User", "Magic-User"), ("ELF", "Elf"), ("thief", "Thief")])
    func classNamesMatchLoosely(input: String, expected: String) {
        #expect(rules.classRules(named: input)?.name == expected)
    }

    @Test(arguments: [("Leather", "leather"), ("Leather armour", "leather"), ("chain mail", "chainmail"),
                      ("Plate mail", "plate"), ("Plate", "plate"), ("Shield", "shield")])
    func armourNamesMatchLoosely(input: String, expected: String) {
        #expect(rules.armour(named: input)?.id == expected)
    }

    @Test func nonArmourDoesNotMatch() {
        #expect(rules.armour(named: "Backpack") == nil)
        #expect(rules.armour(named: "Armour") == nil)
        #expect(rules.weapon(named: "Arrows") == nil)
    }
}

@Suite("Rules for the example characters")
struct ExampleRulesTests {
    @Test(arguments: ["Brother Cedric", "Elowen Thistledown", "Fingle the Elf", "Marlek the Magic-User",
                      "Ronk the Fighter", "the Halfling", "the Thief"])
    func savesAndAttackMatchTheRules(name: String) throws {
        let file = try example(name)
        let analysis = RulesAnalysis(file)
        for save in ["death", "wands", "paralysis", "breath", "spells"] {
            #expect(analysis.status(of: ["saves", .key(save)], in: file) == .matches, "\(name) \(save)")
        }
        let attack: NodePath = file.usesAscendingAC ? ["combat", "attackBonus"] : ["combat", "thac0"]
        #expect(analysis.status(of: attack, in: file) == .matches, "\(name)")
    }

    @Test func fingle() throws {
        let file = try example("Fingle the Elf")
        let a = RulesAnalysis(file)
        // Plate mail AC 3, DEX 17 gives -2: AC 1. The sheet says 3.
        #expect(a.status(of: ["combat", "ac"], in: file) == .overridden(rules: .int(1)))
        #expect(a.status(of: ["movement"], in: file) == .matches)               // heavy armour: 60'
        #expect(a.status(of: ["spells", "slots"], in: file) == .matches)        // [1]
        #expect(a.status(of: ["exploration", "secretDoors"], in: file) == .matches)
        #expect(a.xp == XPInfo(bonusPercent: 0, nextLevel: 4000, readyToLevelUp: false)) // STR 10: no bonus
        #expect(a.abilities["dex"]?.headline == "+2")
        #expect(a.abilities["int"]?.headline == "+1 lang")

        let bow = try #require(a.weapons.first { $0.name == "Long bow" })
        #expect(bow.melee == nil)
        #expect(bow.missile == Attack(thac0: 17, damage: "1d6"))                 // DEX +2; 1d6 by default
        #expect(bow.missile?.notation == "17 [+2]")
        #expect(bow.range == WeaponData.Range(short: 70, medium: 140, long: 210))
        let sword = try #require(a.weapons.first { $0.name == "Sword" })
        #expect(sword.melee == Attack(thac0: 19, damage: "1d6"))                 // STR 10: +0
        #expect(a.weapons.count == 2)                                             // arrows aren't a weapon
        #expect(messages(a).contains("INT 13 allows 1 more language."))
    }

    @Test func elowenUsesVariableDamage() throws {
        let a = RulesAnalysis(try example("Elowen Thistledown"))
        let sword = try #require(a.weapons.first { $0.name == "Sword" })
        #expect(sword.melee == Attack(thac0: 18, damage: "1d8+1"))               // STR 13: +1 to hit and damage
        let bow = try #require(a.weapons.first { $0.name == "Short bow" })
        #expect(bow.missile == Attack(thac0: 18, damage: "1d6"))                 // DEX 14: +1
        #expect(a.xp?.bonusPercent == 5)                                          // INT 15, STR 13
    }

    @Test func cedricUsesAscendingAC() throws {
        let file = try example("Brother Cedric")
        let a = RulesAnalysis(file)
        #expect(a.status(of: ["combat", "ac"], in: file) == .matches)           // chainmail + shield = 15
        #expect(a.xp?.bonusPercent == 10)                                         // WIS 17
        #expect(a.abilities["wis"]?.headline == "+2")
        let mace = try #require(a.weapons.first)
        #expect(mace.melee?.notation == "20 [-1]")                                // STR 6: -1
        #expect(mace.melee?.damage == "1d6-1")
        #expect(messages(a).contains("Clerics need a holy symbol to cast spells."))
        #expect(!messages(a).contains { $0.contains("normally use") })           // a mace is fine
    }

    @Test func marlek() throws {
        let file = try example("Marlek the Magic-User")
        let a = RulesAnalysis(file)
        #expect(a.status(of: ["combat", "ac"], in: file) == .overridden(rules: .int(8)))  // DEX 13
        #expect(a.status(of: ["movement"], in: file) == .matches)
        #expect(a.xp?.bonusPercent == 5)
        #expect(a.hitPointRoll == "1d4+2")
        #expect(messages(a).contains("Roll hit points: 1d4+2 per level (at least 1)."))
        #expect(messages(a).contains("INT 15 allows 1 more language."))
    }

    @Test func ronk() throws {
        let file = try example("Ronk the Fighter")
        let a = RulesAnalysis(file)
        #expect(a.status(of: ["combat", "ac"], in: file) == .matches)            // plate + shield = 2
        #expect(a.status(of: ["exploration", "openDoors"], in: file) == .matches) // STR 13: 3-in-6
        #expect(a.xp?.bonusPercent == 5)
        #expect(a.abilities["cha"]?.effects.map(\.value) == ["+1", "6", "9"])
    }

    @Test func halflingGetsMissileBonus() throws {
        let file = try example("the Halfling")
        let a = RulesAnalysis(file)
        #expect(a.status(of: ["combat", "ac"], in: file) == .matches)
        let sling = try #require(a.weapons.first { $0.name == "Sling" })
        #expect(sling.missile?.notation == "18 [+1]")                             // class +1, DEX 10
        #expect(a.xp?.bonusPercent == 0)
        #expect(messages(a).contains("No alignment chosen.") == false)
    }

    @Test func thief() throws {
        let file = try example("the Thief")
        let a = RulesAnalysis(file)
        for skill in ["climb", "traps", "hearNoise", "hide", "moveSilently", "openLocks", "pickPockets"] {
            #expect(a.status(of: ["thiefSkills", .key(skill)], in: file) == .matches, "\(skill)")
        }
        #expect(a.status(of: ["combat", "ac"], in: file) == .matches)            // leather, DEX 17
        #expect(a.status(of: ["movement"], in: file) == .matches)                // light armour: 90'
        #expect(a.xp?.bonusPercent == 10)
        #expect(a.weapons.first { $0.name == "Crossbow" }?.missile?.notation == "17 [+2]")
        let dagger = try #require(a.weapons.first { $0.name == "Dagger" })
        #expect(dagger.melee?.notation == "20 [-1]")                              // STR 6
        #expect(dagger.missile?.notation == "17 [+2]")                            // thrown: DEX 17
        #expect(messages(a).contains("No alignment chosen."))
        #expect(messages(a).contains("Roll hit points: 1d4+1 per level (at least 1)."))
    }

    @Test func namedValuesForLayouts() throws {
        let values = RulesAnalysis(try example("Fingle the Elf")).namedValues
        #expect(values["dex.mod"] == "+2")
        #expect(values["xp.next"] == "4000")
        #expect(values["rules.combat.ac"] == "1")
        #expect(values["weapons.0.missile"] == "17 [+2] 1d6")
    }
}

@Suite("Rules notes")
struct RuleNoteTests {
    private func analysis(_ header: String) throws -> RulesAnalysis {
        RulesAnalysis(try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose }\n" + header + "---\n"))
    }

    @Test func requirementsLimitsAndRestrictions() throws {
        let a = try analysis("""
        class: Elf
        level: 11
        abilityScores: { str: 10, int: 8, wis: 10, dex: 10, con: 10, cha: 10 }

        """)
        #expect(messages(a).contains("Elves need INT 9 or more (it's 8)."))
        #expect(messages(a).contains("Elves can't normally go past level 10."))
    }

    @Test func armourAndWeaponRestrictions() throws {
        let mu = try analysis("class: Magic-User\nlevel: 1\nequipment:\n  - { name: Chainmail }\n")
        #expect(messages(mu).contains("Magic-Users can't normally wear armour."))

        let thief = try analysis("class: Thief\nlevel: 1\nequipment:\n  - { name: Plate mail }\n  - { name: Shield }\n")
        #expect(messages(thief).contains("Thieves can't normally wear plate mail."))
        #expect(messages(thief).contains("Thieves can't normally use a shield."))

        let cleric = try analysis("class: Cleric\nlevel: 1\nequipment:\n  - { name: Sword }\n  - { name: Holy symbol }\n")
        #expect(messages(cleric).contains("Clerics normally use: blunt weapons only. Sword isn't one."))

        let dwarf = try analysis("class: Dwarf\nlevel: 1\nequipment:\n  - { name: Two-handed sword }\n")
        #expect(messages(dwarf).contains("Dwarves can't normally use a two-handed sword."))
    }

    @Test func unequippedArmourDoesNotCount() throws {
        let a = try analysis("""
        class: Fighter
        level: 1
        abilityScores: { dex: 10 }
        equipment:
          - { name: Plate mail }
          - { name: Leather, equipped: true }

        """)
        #expect(a.suggestions[["combat", "ac"]] == .int(7))
    }

    @Test func unknownClass() throws {
        let a = try analysis("class: Barbarian\nlevel: 1\n")
        #expect(messages(a) == ["No Classic Fantasy rules for “Barbarian”, so saves, attacks and class abilities aren't suggested."])
        #expect(Array(a.suggestions.keys) == [["movement"]])     // armour-based, so still suggested
    }

    @Test func readyToLevelUp() throws {
        let a = try analysis("class: Fighter\nlevel: 1\nxp: 2100\n")
        #expect(a.xp?.readyToLevelUp == true)
        #expect(messages(a).contains("Enough XP for level 2."))
    }

    @Test func detailedEncumbrance() throws {
        // Chainmail 400 + sword 60 + misc gear 80 + 100 coins = 640: 60'
        let a = RulesAnalysis(try CharacterFile(text: """
        ---
        formatVersion: 1
        rules: { system: ose, options: { encumbrance: detailed } }
        class: Fighter
        level: 1
        equipment:
          - { name: Chainmail }
          - { name: Sword }
          - { name: Backpack }
        money: { gp: 100 }
        ---

        """))
        #expect(a.suggestions[["movement"]] == .int(60))
    }
}

@Suite("Level up")
struct LevelUpTests {
    @Test func fingleToLevelFourUpdatesAutomaticValuesAndKeepsOverrides() throws {
        var file = try example("Fingle the Elf")
        file.setInt(3, at: ["level"])
        file[["spells", "slots"]] = nil
        file.appendInt(2, to: ["spells", "slots"])
        file.appendInt(1, to: ["spells", "slots"])
        file.setInt(14, at: ["saves", "breath"])                 // house rule: keep it

        let plan = try #require(RulesAnalysis(file).levelUpPlan(for: file))
        #expect(plan.toLevel == 4)
        #expect(plan.keptOverrides == [["saves", "breath"]])
        #expect(plan.hitPoints == .roll(sides: 6, conModifier: 1))

        file.apply(plan, hitPointRoll: 4)
        #expect(file.int(["level"]) == 4)
        #expect(file.int(["saves", "death"]) == 10)
        #expect(file.int(["saves", "spells"]) == 12)
        #expect(file.int(["saves", "breath"]) == 14)
        #expect(file.int(["combat", "thac0"]) == 17)
        #expect([file.int(["spells", "slots", 0]), file.int(["spells", "slots", 1])] == [2, 2])
        #expect(file.count(["spells", "slots"]) == 2)
        #expect(file.int(["combat", "ac"]) == 3)                  // AC doesn't change with level
        #expect(file.int(["hp", "max"]) == 11)                    // 6 + 4 + CON 1
        #expect(file.int(["hp", "current"]) == 8)                 // was 3 of 6
    }

    @Test func hitPointGainIsAtLeastOne() {
        let plan = LevelUpPlan(fromLevel: 1, toLevel: 2, changes: [], keptOverrides: [],
                               hitPoints: .roll(sides: 4, conModifier: -2))
        #expect(plan.hitPointGain(roll: 1) == 1)
    }

    @Test func fixedHitPointsAfterNinthLevel() throws {
        var file = try CharacterFile(text: """
        ---
        formatVersion: 1
        rules: { system: ose }
        class: Fighter
        level: 9
        abilityScores: { con: 18 }
        hp:
          max: 60
          current: 60
        ---

        """)
        let plan = try #require(RulesAnalysis(file).levelUpPlan(for: file))
        #expect(plan.hitPoints == .fixed(2))                      // 9d8 → 9d8+2, CON no longer counts
        file.apply(plan, hitPointRoll: nil)
        #expect(file.int(["hp", "max"]) == 62)
    }

    @Test func clericGainsSpellSlotsAtLevelTwo() throws {
        var file = try example("Brother Cedric")
        let plan = try #require(RulesAnalysis(file).levelUpPlan(for: file))
        file.apply(plan, hitPointRoll: 3)
        #expect(file.int(["spells", "slots", 0]) == 1)
        #expect(file.text().contains("spells:\n  slots: [1]\n"))
    }
}

@Suite("Filling in")
struct FillTests {
    @Test func fillMissingWritesOnlyEmptyFields() throws {
        var file = try CharacterFile(text: """
        ---
        formatVersion: 1
        rules: { system: ose }
        class: Thief
        level: 1
        abilityScores: { str: 6, int: 10, wis: 10, dex: 17, con: 13, cha: 11 }
        combat:
          ac: 4
        ---

        """)
        let filled = file.fillMissingValues(from: RulesAnalysis(file))
        #expect(file.int(["combat", "ac"]) == 4)                 // override kept (rules: 5)
        #expect(file.int(["combat", "thac0"]) == 19)
        #expect(file.int(["saves", "death"]) == 13)
        #expect(file.int(["thiefSkills", "climb"]) == 87)
        #expect(file.int(["exploration", "openDoors"]) == 1)
        #expect(file.int(["movement"]) == 120)                   // no armour listed
        #expect(filled == 1 + 5 + 7 + 4 + 1)
        // Filled values land in the standard places.
        #expect(file.text().contains("combat:\n  ac: 4\n  thac0: 19\nsaves: { death: 13, wands: 14, paralysis: 13, breath: 16, spells: 15 }\nmovement: 120\n"))
        // Doing it again changes nothing.
        #expect(file.fillMissingValues(from: RulesAnalysis(file)) == 0)
    }
}
