# Equipment List Format — v1 (draft)

A custom equipment list is a group's changes to the rules' equipment list:
new prices, items the market doesn't sell, and house items. Like a
character, it's a UTF-8 Markdown file with a YAML header, so it can be read
and edited anywhere and shared through a folder.

The list holds **changes, not a copy**. Everything not mentioned stays as
the rules have it, so files stay short and corrections to the rules data
still reach groups that use a custom list.

See [`examples/equipment/Hightower Market.md`](../examples/equipment/Hightower%20Market.md)
for a complete file.

## Ground rules

- **Identification.** A file is an equipment list if its header has
  `formatVersion` and `kind: equipment`. It has no `rules` key, so it is
  never mistaken for a character, including by older versions of the app
  (they open it as plain text).
- **The body is notes.** The Markdown body is for the group: where the
  market is, who runs it, haggling rules. The app doesn't interpret it.
- **Mistakes are notes, not errors.** A change naming an item the rules
  don't have, or a house item with no cost, is pointed out and skipped. The
  rest of the list still applies.
- **Unknown keys are preserved**, as in character files.
- **Characters don't record which list was used.** A bought item is
  written to the sheet as usual (name, quantity, damage), so the character
  file reads the same with or without the list.

## Header

| Key | Type | Notes |
|---|---|---|
| `formatVersion` | integer | Currently `1`. Required. |
| `kind` | string | `equipment`. Required. |
| `system` | string | Ruleset id the list changes: `ose`. Required. |
| `name` | string | Shown in the shop and in Settings. If missing, the file name. |
| `prices` | percentage | Scales every rules price, e.g. `150%` for a boomtown. Items with their own `change` cost, and house items, aren't scaled. Default `100%`. |
| `remove` | list of strings | Rules items the market doesn't sell. |
| `change` | list of changes | New prices and details for rules items. |
| `add` | list of items | House items. |

### Naming rules items

`remove` and `change` name rules items the way people do. Any of these
works, ignoring case, spaces and punctuation:

- the name in the shop: `Arrows (quiver of 20)`
- the name written on a sheet: `Arrows`
- the rules data's id: `arrows`

### `remove`

```yaml
remove: [Garlic, "Holy water (vial)"]
```

Removed items aren't offered in the shop. A character who already has one
keeps it, and the sheet still recognises it (damage, weight).

### `change`

Each change names an item with `item` and gives only the fields that
differ:

| Key | Type | Notes |
|---|---|---|
| `item` | string | The rules item. Required. |
| `cost` | number or string | See **Costs** below. |
| `quantity` | integer | How many come for the cost (a quiver of 12 instead of 20). |
| `weight` | integer | In coins. |
| `notes` | string | Replaces the rules' notes in the shop. |

```yaml
change:
  - { item: Sword, cost: 15 }
  - { item: Arrows, cost: 3 }
  - { item: Plate mail, cost: 120, notes: "Made to order: a month's wait." }
```

### `add`

House items. `name`, `category` and `cost` are required; the other fields
depend on the category and are all optional.

| Key | Category | Notes |
|---|---|---|
| `name` | all | As shown in the shop and written on the sheet. |
| `category` | all | `weapons`, `armour`, `ammunition` or `gear`. |
| `cost` | all | See **Costs**. |
| `quantity` | all | How many come for the cost. |
| `weight` | all | In coins. |
| `notes` | all | Shown in the shop. |
| `damage` | weapons | e.g. `1d6`. Used when variable weapon damage is on. |
| `qualities` | weapons | From the rules: `blunt`, `brace`, `charge`, `melee`, `missile`, `reload`, `slow`, `splash`, `two-handed`. |
| `range` | weapons | `{ short, medium, long }` in feet. |
| `ac` | armour | Descending AC when worn (`7` for leather). |
| `acBonus` | armour | For shields and the like: added to AC. |
| `encumbrance` | armour | `light` or `heavy`, for basic encumbrance. |
| `usableBy` | weapons, armour | Classes that can normally use it. Without it, the shop gives no class warning. |

```yaml
add:
  - name: Hand crossbow
    category: weapons
    cost: 40
    weight: 30
    damage: 1d4
    qualities: [missile, reload]
    range: { short: 30, medium: 60, long: 90 }
  - { name: Mule, category: gear, cost: 30, notes: "Carries 2,000 coins." }
```

A house item with the same name as a rules item replaces it.

### Costs

A plain number is gold pieces. A string gives the coin: `"5 sp"`,
`"2 gp 5 sp"`, `"30 cp"`. The shop pays in any coins, making change, as it
does now.

## In the app

- **Settings → Equipment** chooses the rules list or a custom file. The
  choice is for the app, not per character.
- **New List…** saves a short starting file (a commented-out example of
  each section) and opens it to edit. Lists are edited as text, in the app
  or anywhere else.
- **The shop** shows the list's name, tags house items, shows the rules
  price beside a changed one, and counts any problems in the file. A file
  that can't be read at all leaves the shop on the rules list.
- **Settings and Edit as Text** list the problems. The status bar names the
  list and what it changes.
- **The sheet** treats house weapons and armour like the rules' own: a
  house weapon's damage is suggested and it's in the Weapons section (to-hit,
  ranges); house armour and shields count for AC and movement (and weight,
  with detailed encumbrance). `usableBy` gives the class warnings. The party
  window and the printed sheet do the same.
- **Shared lists:** keep the file in a shared folder (iCloud Drive,
  Dropbox). The app rereads it each time a shop or Settings opens.

## Decided

- **Prices and details only.** A list can't change an item's rules (a
  spear doing 1d8, plate mail at AC 2): that would make it a house rule
  affecting calculated AC and damage. House items are the way to add a
  different weapon.
- **One list for the app**, chosen in Settings. Per-folder lists (the
  plan's "campaign folders") may replace this later.
