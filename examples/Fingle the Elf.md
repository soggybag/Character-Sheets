---
formatVersion: 1
rules:
  system: ose
  variant: classic
  options:
    ascendingAC: false
    encumbrance: basic
name: Fingle
class: Elf
level: 1
alignment: Chaotic
xp: 0
abilityScores: { str: 10, int: 13, wis: 10, dex: 17, con: 15, cha: 10 }
hp:
  max: 6
  current: 3
combat:
  ac: 3
  thac0: 19
saves: { death: 12, wands: 13, paralysis: 13, breath: 15, spells: 15 }
movement: 60
exploration: { listen: 2, secretDoors: 2, openDoors: 2, findTraps: 1 }
languages: [Chaotic, Common, Elvish, Gnoll, Hobgoblin, Orcish]
spells:
  slots: [1]
  spellbook:
    - { name: Sleep, level: 1 }
  memorized:
    - { name: Sleep, cast: false }
equipment:
  - { name: Plate mail, equipped: true }
  - { name: Long bow, equipped: true }
  - { name: Arrows, qty: 16 }
  - { name: Sword, equipped: true }
  - { name: "Rations (iron, 7 days)" }
  - { name: Backpack }
money: { gp: 5 }
---

# Notes

> Above the golems path, where stone meets stone, seek the door that is not.
