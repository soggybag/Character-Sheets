import Testing
@testable import CharacterKit

@Suite("Shop")
struct ShopTests {
    private let rules = OSERuleset.classic
    private func item(_ id: String) throws -> ShopItem { try #require(rules.shopItems.first { $0.id == id }) }

    private func file(_ header: String) throws -> CharacterFile {
        try CharacterFile(text: "---\nformatVersion: 1\nrules: { system: ose, variant: classic }\n\(header)\n---\n")
    }

    @Test func listIsGroupedAndHasNoDuplicates() throws {
        let items = rules.shopItems
        #expect(Set(items.map(\.id)).count == items.count)
        #expect(items.first?.category == .weapons)
        #expect(items.last?.category == .gear)
        #expect(!items.contains { $0.id == "torch" || $0.id == "oil-flask-burning" })
        #expect(items.count(where: { $0.id == "holy-water-vial" }) == 1)
        #expect(try item("sword").details == "1d8, melee")
        #expect(try item("leather").itemName == "Leather armour" && item("plate").itemName == "Plate mail")
        #expect(try item("leather").details == "AC 7 [12], light")
        #expect(try item("arrows").itemName == "Arrows" && item("arrows").quantity == 20)
        #expect(try item("holy-water-vial").details.hasPrefix("1d8 thrown"))
    }

    @Test func everyListedItemIsRecognisedOnTheSheet() throws {
        // What the sheet calls an item must match the rules data it came from.
        for item in rules.shopItems {
            switch item.category {
            case .weapons: #expect(rules.weapon(named: item.itemName)?.id == item.id, "\(item.itemName)")
            case .armour: #expect(rules.armour(named: item.itemName)?.id == item.id, "\(item.itemName)")
            case .ammunition: #expect(rules.isAmmunition(item.itemName), "\(item.itemName)")
            case .gear: break
            }
        }
    }

    @Test func restrictions() throws {
        let cleric = rules.classRules(named: "Cleric")
        let magicUser = rules.classRules(named: "Magic-User")
        let fighter = rules.classRules(named: "Fighter")
        #expect(try rules.restriction(of: item("sword"), for: cleric) != nil)
        #expect(try rules.restriction(of: item("mace"), for: cleric) == nil)
        #expect(try rules.restriction(of: item("leather"), for: magicUser) == "Magic-Users can't wear armour.")
        #expect(try rules.restriction(of: item("shield"), for: magicUser) != nil)
        #expect(try rules.restriction(of: item("dagger"), for: magicUser) == nil)
        #expect(try rules.restriction(of: item("plate"), for: fighter) == nil)
        #expect(try rules.restriction(of: item("torches"), for: magicUser) == nil)
        #expect(try rules.restriction(of: item("sword"), for: nil) == nil)
    }

    @Test func payingMakesChange() {
        let purse = Purse(pp: 1, gp: 37, sp: 12, cp: 40)
        #expect(purse.paying(1500) == Purse(pp: 1, gp: 22, sp: 12, cp: 40))
        // 40 gp: all the gold, then 12 sp and 40 cp (1.6 gp), then break the platinum.
        #expect(purse.paying(4000) == Purse(pp: 0, gp: 3, sp: 6, cp: 0))   // 43.6 gp − 40
        #expect(Purse(gp: 1).paying(20) == Purse(gp: 0, sp: 8, cp: 0))
        #expect(Purse(ep: 1).paying(30) == Purse(sp: 2))
        #expect(purse.paying(purse.totalCP) == Purse())
        #expect(purse.paying(purse.totalCP + 1) == nil)
        #expect(Purse(gp: 2, sp: 5).description == "2 gp, 5 sp")
        #expect(Purse().description == "no money")
    }

    @Test func buyingAddsAndPays() throws {
        var ronk = try file("class: Fighter\nequipment:\n  - { name: Arrows, qty: 3 }\nmoney: { pp: 0, gp: 9, sp: 0 }")
        #expect(try ronk.buy(item("arrows"), pay: true))
        #expect(ronk.int(["equipment", 0, "qty"]) == 23)
        #expect(try ronk.buy(item("short-bow"), pay: true) == false)   // 25 gp, has 4
        #expect(ronk.count(["equipment"]) == 1)
        #expect(ronk.int(["money", "gp"]) == 4)
        #expect(try ronk.buy(item("short-bow"), pay: false))
        #expect(ronk.string(["equipment", 1, "name"]) == "Short bow")
        #expect(ronk.int(["equipment", 1, "qty"]) == nil)
        #expect(try ronk.buy(item("rope-50"), count: 2, pay: true))
        #expect(ronk.int(["equipment", 2, "qty"]) == 2)
        #expect(ronk.int(["money", "gp"]) == 2 && ronk.int(["money", "pp"]) == 0 && ronk.int(["money", "cp"]) == nil)
        #expect(try ronk.buy(item("garlic"), pay: true) == false)
        #expect(try ronk.buy(item("sling-stones"), pay: true))
    }
}
