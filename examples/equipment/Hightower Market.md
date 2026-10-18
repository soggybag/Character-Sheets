---
formatVersion: 1
kind: equipment
system: ose
name: Hightower Market
remove: [Garlic, "Holy water (vial)", Plate mail]
change:
  - { item: Sword, cost: 15 }
  - { item: Arrows, cost: 3 }
  - { item: "Rations (iron, 7 days)", cost: 20, notes: Shipped in from the coast. }
  - { item: "Rope (50')", cost: "5 sp" }
add:
  - name: Hand crossbow
    category: weapons
    cost: 40
    weight: 30
    damage: 1d4
    qualities: [missile, reload]
    range: { short: 30, medium: 60, long: 90 }
    usableBy: [Fighter, Elf, Halfling, Thief, Dwarf]
  - { name: Hand crossbow bolts, category: ammunition, cost: 4, quantity: 10 }
  - { name: Gambeson, category: armour, cost: 15, weight: 150, ac: 8, encumbrance: light }
  - { name: Mule, category: gear, cost: 30, notes: "Carries 2,000 coins." }
  - { name: Lucky charm, category: gear, cost: "2 sp", notes: Sold by Old Mag at the gate. Does nothing. Probably. }
---

# Hightower Market

The only market for three days' ride. Plate mail is made to order by the
smith on Anvil Row: 120 gp and a month's wait.

Prices are for strangers. Anyone the Baroness vouches for pays rules prices.
