---
formatVersion: 1
rules:
  system: ose
  variant: classic
  options:
    ascendingAC: false
    encumbrance: basic
    variableWeaponDamage: true
name: Elowen Thistledown
player: Sam
class: Elf
level: 2
alignment: Neutral
xp: 4625
abilityScores: { str: 13, int: 15, wis: 9, dex: 14, con: 11, cha: 10 }
hp:
  max: 9
  current: 7
  rolls: [5, 4]
combat:
  ac: 5
  thac0: 19
saves: { death: 12, wands: 13, paralysis: 13, breath: 15, spells: 15 }
movement: 90
exploration: { listen: 2, secretDoors: 2, openDoors: 3, findTraps: 1 }
languages: [Alignment, Common, Elvish, Gnoll, Hobgoblin, Orcish, Dwarvish]
spells:
  slots: [2]
  spellbook:
    - { name: Sleep, level: 1 }
    - { name: Magic Missile, level: 1 }
  memorized:
    - { name: Sleep, cast: true }
    - { name: Magic Missile, cast: false }
equipment:
  - { name: Sword, damage: 1d8, equipped: true }
  - { name: Short bow, damage: 1d6, equipped: true }
  - { name: Arrows, qty: 17 }
  - { name: Leather armour, equipped: true }
  - { name: Shield, equipped: true }
  - { name: Backpack }
  - { name: Torches, qty: 4 }
  - { name: Iron rations, qty: 5 }
  - { name: "Rope (50')" }
  - { name: Silver key, notes: Found in the crypt under Brackenmoor }
money: { pp: 0, gp: 37, ep: 0, sp: 12, cp: 40 }
---

# Notes

Youngest daughter of a minor elven house. Left home to find her brother
Caelan, last seen heading toward the Brackenmoor barrows.

## Session log

**Session 3:** Cleared the upper crypt. Slept four skeletons... which did
nothing, because skeletons. Found a silver key on the altar.

**Session 4:** Owes Brother Aldo 20 gp for healing. Party voted to go back for
the locked door below the altar.
