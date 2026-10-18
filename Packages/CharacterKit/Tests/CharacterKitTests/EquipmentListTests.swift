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
}
