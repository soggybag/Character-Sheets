import Foundation
import Testing
import Yams
@testable import CharacterKit

@Suite("Equipment list")
struct EquipmentListTests {
    private let example = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "examples/equipment/Hightower Market.md")

    private func list(_ header: String) throws -> EquipmentList {
        try EquipmentList(text: "---\nformatVersion: 1\nkind: equipment\nsystem: ose\n\(header)\n---\n")
    }

    @Test func readsTheExample() throws {
        let text = try String(contentsOf: example, encoding: .utf8)
        #expect(EquipmentList.isEquipmentList(text))
        let list = try EquipmentList(text: text)
        #expect(list.name == "Hightower Market")
        #expect(list.removals == ["Garlic", "Holy water (vial)", "Plate mail"])
        #expect(list.changes.map(\.item) == ["Sword", "Arrows", "Rations (iron, 7 days)", "Rope (50')"])
        #expect(list.changes[0].price == 1500)
        #expect(list.changes[2].notes == "Shipped in from the coast.")
        #expect(list.changes[3].price == 50)
        #expect(list.additions.map(\.name) == ["Hand crossbow", "Hand crossbow bolts", "Gambeson", "Mule", "Lucky charm"])
        let crossbow = list.additions[0]
        #expect(crossbow.category == .weapons && crossbow.price == 4000 && crossbow.damage == "1d4")
        #expect(crossbow.qualities == ["missile", "reload"])
        #expect(crossbow.range == WeaponData.Range(short: 30, medium: 60, long: 90))
        #expect(crossbow.usableBy.count == 5)
        #expect(list.additions[2].ac == 8 && list.additions[2].encumbrance == "light")
        #expect(list.additions[4].price == 20)
        #expect(list.body.hasPrefix("\n# Hightower Market"))
        #expect(list.allProblems().isEmpty, "\(list.allProblems())")
    }

    @Test func isNeverACharacter() throws {
        let text = try String(contentsOf: example, encoding: .utf8)
        #expect(try !CharacterFile(text: text).isCharacter)
        #expect(!EquipmentList.isEquipmentList("---\nformatVersion: 1\nrules: { system: ose }\n---\n"))
        #expect(throws: EquipmentListError.notAnEquipmentList) {
            try EquipmentList(text: "---\nformatVersion: 1\nrules: { system: ose }\n---\n")
        }
        #expect(throws: EquipmentListError.unreadable(.noFrontMatter)) { try EquipmentList(text: "# Notes") }
    }

    @Test(arguments: [
        ("15", 1500), ("0", 0), ("2.5", 250), ("\"5 sp\"", 50), ("\"2 gp 5 sp\"", 250), ("\"2gp, 5sp\"", 250),
        ("\"30 cp\"", 30), ("\"1 pp\"", 500), ("\"1 ep\"", 50), ("\"3 GP\"", 300),
    ])
    func costs(_ yaml: String, _ copper: Int) throws {
        let node = try #require(try Yams.compose(yaml: yaml))
        #expect(EquipmentList.price(node) == copper)
    }

    @Test(arguments: ["\"five gold\"", "\"5\u{00A0}zz\"", "-3", "\"\"", "\"5 sp 3\""])
    func notCosts(_ yaml: String) throws {
        let node = try #require(try Yams.compose(yaml: yaml))
        #expect(EquipmentList.price(node) == nil)
    }

    @Test func priceScale() throws {
        #expect(try list("prices: 150%").priceScale == 150)
        #expect(try list("prices: 80").priceScale == 80)
        #expect(try list("").priceScale == 100)
        let bad = try list("prices: lots")
        #expect(bad.priceScale == 100 && bad.problems.count == 1)
    }

    @Test func badEntriesAreSkippedAndDescribed() throws {
        let list = try list("""
            remove: Garlic
            change:
              - Sword
              - { cost: 3 }
              - { item: Sword, cost: lots, quantity: some }
            add:
              - { name: Mule, cost: 30 }
              - { name: Cart, category: vehicles, cost: 100 }
              - { name: Charm, category: gear }
              - { name: Pike, category: weapons, cost: 9, qualities: [melee, pointy], range: 30 }
              - { name: Fur coat, category: armour, cost: 5, ac: 8, encumbrance: medium }
              - { category: gear, cost: 1 }
            """)
        // Kept: the Sword change (without its bad fields), Pike and Fur coat.
        #expect(list.removals.isEmpty)
        #expect(list.changes.count == 1 && list.changes[0].price == nil && list.changes[0].quantity == nil)
        #expect(list.additions.map(\.name) == ["Pike", "Fur coat"])
        #expect(list.additions[0].qualities == ["melee"] && list.additions[0].range == nil)
        #expect(list.additions[1].encumbrance == nil)
        #expect(list.problems.count == 12, "\(list.problems)")
        #expect(list.problems.contains("Mule: give a category (weapons, armour, ammunition or gear). Skipped."))
        #expect(list.problems.contains("Pike: “pointy” isn't a weapon quality."))
    }

    @Test func otherRulesets() throws {
        let list = try EquipmentList(text: "---\nformatVersion: 1\nkind: equipment\nsystem: bfrpg\n---\n")
        #expect(list.problems == ["This list is for the “bfrpg” rules; only OSE is supported."])
    }

    @Test func namesMatchTheWayPeopleWriteThem() throws {
        let items = OSERuleset.classic.shopItems
        for name in ["Arrows (quiver of 20)", "arrows", "ARROWS"] {
            #expect(EquipmentList.rulesItem(named: name, in: items)?.id == "arrows", "\(name)")
        }
        #expect(EquipmentList.rulesItem(named: "Leather armour", in: items)?.id == "leather")
        #expect(EquipmentList.rulesItem(named: "rope-50", in: items)?.name == "Rope (50')")
        #expect(EquipmentList.rulesItem(named: "Rope", in: items) == nil)
    }

    @Test func rulesProblems() throws {
        let list = try list("""
            remove: [Garlic, Swrod]
            change: [{ item: Hand crossbow, cost: 30 }]
            add: [{ name: Sling staff, category: weapons, cost: 2, usableBy: [Fighter, Ranger] }]
            """)
        #expect(list.problems.isEmpty)
        #expect(list.allProblems() == [
            "remove: the rules have no “Swrod”.",
            "change: the rules have no “Hand crossbow”. To sell it, add it as a house item.",
            "Sling staff: usableBy has “Ranger”, which isn't a class.",
        ])
    }

    // MARK: In the shop

    private func hightower() throws -> EquipmentList {
        try EquipmentList(text: String(contentsOf: example, encoding: .utf8))
    }

    @Test func withoutAListTheShopIsTheRules() throws {
        let rules = OSERuleset.classic
        #expect(rules.shopItems(with: nil) == rules.shopItems)
        #expect(rules.shopItems.allSatisfy { $0.origin == .rules && $0.price % 100 == 0 })
        #expect(rules.shopItems.first { $0.id == "sword" }?.price == 1000)
    }

    @Test func aListChangesTheShop() throws {
        let items = OSERuleset.classic.shopItems(with: try hightower())
        func item(_ id: String) throws -> ShopItem { try #require(items.first { $0.id == id }, "\(id)") }
        for removed in ["garlic", "holy-water-vial", "plate"] {
            #expect(!items.contains { $0.id == removed }, "\(removed)")
        }
        #expect(try item("sword").price == 1500 && item("sword").origin == .changed(rulesPrice: 1000))
        #expect(try item("arrows").price == 300 && item("arrows").quantity == 20)
        #expect(try item("rope-50").price == 50)
        #expect(try item("rations-iron-7-days").details == "Shipped in from the coast.")
        #expect(try item("dagger").origin == .rules && item("dagger").price == 300)

        let crossbow = try item("house:handcrossbow")
        #expect(crossbow.origin == .house && crossbow.category == .weapons && crossbow.price == 4000)
        #expect(crossbow.details == "1d4, missile, reload")
        #expect(try item("house:gambeson").details == "AC 8 [11], light")
        #expect(try item("house:mule").details == "Carries 2,000 coins.")
        #expect(try item("house:luckycharm").price == 20)
        // Still grouped and sorted.
        let weapons = items.filter { $0.category == .weapons }.map(\.name)
        #expect(weapons == weapons.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func houseItemRestrictions() throws {
        let rules = OSERuleset.classic
        let items = rules.shopItems(with: try hightower())
        let crossbow = try #require(items.first { $0.id == "house:handcrossbow" })
        let mule = try #require(items.first { $0.id == "house:mule" })
        #expect(rules.restriction(of: crossbow, for: rules.classRules(named: "Thief")) == nil)
        #expect(rules.restriction(of: crossbow, for: rules.classRules(named: "Cleric")) == "Clerics don't normally use a hand crossbow.")
        #expect(rules.restriction(of: mule, for: rules.classRules(named: "Cleric")) == nil)
    }

    @Test func priceScaleSkipsChangedAndHouseItems() throws {
        let list = try list("""
            prices: 150%
            change: [{ item: Sword, cost: 12 }]
            add: [{ name: Mule, category: gear, cost: 30 }]
            """)
        let items = OSERuleset.classic.shopItems(with: list)
        #expect(items.first { $0.id == "sword" }?.price == 1200)
        #expect(items.first { $0.id == "dagger" }?.price == 450)
        #expect(items.first { $0.id == "dagger" }?.origin == .changed(rulesPrice: 300))
        #expect(items.first { $0.id == "house:mule" }?.price == 3000)
    }

    @Test func aHouseItemReplacesTheRulesOne() throws {
        let list = try list("add: [{ name: Sword, category: weapons, cost: 12, damage: 1d10, qualities: [melee] }]")
        let swords = OSERuleset.classic.shopItems(with: list).filter { $0.name == "Sword" }
        #expect(swords.count == 1 && swords[0].origin == .house && swords[0].details == "1d10, melee")
    }

    @Test func payingInSilver() throws {
        let charm = try #require(OSERuleset.classic.shopItems(with: try hightower()).first { $0.id == "house:luckycharm" })
        var file = try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose }\nmoney: { gp: 1 }\n---\n")
        let bought = file.buy(charm, pay: true)
        #expect(bought)
        #expect(Purse(file) == Purse(sp: 8))
        #expect(Purse.priceText(250) == "2 gp, 5 sp" && Purse.priceText(0) == "free")

        var character = NewCharacter()
        character.gold = 10
        character.buy(charm, count: 3)
        #expect(character.moneyLeft == Purse(gp: 9, sp: 4))
        let made = character.makeFile()
        #expect(made.int(["money", "gp"]) == 9 && made.int(["money", "sp"]) == 4 && made.int(["money", "cp"]) == nil)
    }

    @Test func theStartingFileReadsCleanly() throws {
        for name in ["My Market", "No", "Yes: the market", "Mag's #1 stall"] {
            let list = try EquipmentList(text: EquipmentList.template(name: name))
            #expect(list.name == name)
            #expect(list.allProblems().isEmpty, "\(list.allProblems())")
            #expect(list.summary == "No changes yet")
            #expect(list.body.contains("# \(name)"))
        }
    }

    // MARK: On the sheet

    private func sheet(_ className: String, variable: Bool = true, items: String) throws -> CharacterFile {
        try CharacterFile(text: """
            ---
            formatVersion: 1
            rules: { system: ose, options: { variableWeaponDamage: \(variable) } }
            class: \(className)
            level: 1
            abilityScores: { str: 10, int: 10, wis: 10, dex: 10, con: 10, cha: 10 }
            equipment: \(items)
            ---

            """)
    }

    @Test func houseItemsCountOnTheSheet() throws {
        let list = try hightower()
        let file = try sheet("Thief", items: "[{ name: Hand crossbow }, { name: Gambeson }]")

        // Without the list they're unknown items.
        let plain = RulesAnalysis(file)
        #expect(plain.weapons.isEmpty && plain.itemDamage.isEmpty)
        #expect(plain.suggestions[["combat", "ac"]] == .int(9) && plain.movement?.rate == 120)

        let analysis = RulesAnalysis(file, equipmentList: list)
        let crossbow = try #require(analysis.weapons.first)
        #expect(crossbow.name == "Hand crossbow" && crossbow.melee == nil)
        #expect(crossbow.missile?.damage == "1d4" && crossbow.missile?.thac0 == 19)
        #expect(crossbow.range == WeaponData.Range(short: 30, medium: 60, long: 90))
        #expect(analysis.itemDamage == [0: "1d4"])
        // Gambeson: AC 8, light armour.
        #expect(analysis.suggestions[["combat", "ac"]] == .int(8) && analysis.movement?.rate == 90)
        #expect(!analysis.notes.contains { $0.kind == .warning })

        let fixedDamage = RulesAnalysis(try sheet("Thief", variable: false, items: "[{ name: Hand crossbow }]"),
                                        equipmentList: list)
        #expect(fixedDamage.itemDamage == [0: "1d6"])
    }

    @Test func houseItemsFollowTheirUsableBy() throws {
        let analysis = RulesAnalysis(try sheet("Cleric", items: "[{ name: Hand crossbow }, { name: Gambeson }]"),
                                     equipmentList: try hightower())
        let warnings = analysis.notes.filter { $0.kind == .warning }.map(\.message)
        // The crossbow lists its classes; the gambeson lists none, so anyone may wear it.
        #expect(warnings == ["Clerics don't normally use a hand crossbow."])
    }

    @Test func aHouseShieldGivesItsBonus() throws {
        let list = try list("add: [{ name: Tower shield, category: armour, cost: 20, acBonus: 2 }]")
        let analysis = RulesAnalysis(try sheet("Fighter", items: "[{ name: Tower shield }, { name: Shield }]"),
                                     equipmentList: list)
        #expect(analysis.suggestions[["combat", "ac"]] == .int(7))
    }

    @Test func theShopAndTheSheetAgree() throws {
        let rules = OSERuleset.classic
        let cleric = rules.classRules(named: "Cleric")
        let magicUser = rules.classRules(named: "Magic-User")
        func shop(_ id: String, _ classRules: ClassRules?) throws -> String? {
            try rules.restriction(of: #require(rules.shopItems.first { $0.id == id }), for: classRules)
        }
        func sheet(_ className: String, _ item: String) throws -> [String] {
            RulesAnalysis(try self.sheet(className, items: "[{ name: \(item) }]")).notes
                .filter { $0.kind == .warning }.map(\.message)
        }
        #expect(try sheet("Cleric", "Sword") == [shop("sword", cleric)])
        #expect(try sheet("Magic-User", "Leather") == [shop("leather", magicUser)])
        #expect(try sheet("Magic-User", "Shield") == [shop("shield", magicUser)])
    }

    @Test func summaryAndHouseItemLookup() throws {
        let list = try hightower()
        #expect(list.summary == "Removes 3, changes 4, adds 5")
        #expect(try self.list("prices: 150%").summary == "Rules prices at 150%")
        #expect(list.houseItem(named: "hand crossbow")?.damage == "1d4")
        #expect(list.houseItem(named: "Sword") == nil)
    }
}
