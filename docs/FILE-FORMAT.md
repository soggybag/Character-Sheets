# Character File Format — v1

A character is a UTF-8 Markdown file (`.md`) made of two parts:

1. A **YAML front matter header** between two `---` lines, holding the
   structured sheet.
2. A **Markdown body**: free-form notes, backstory and session log. The app
   never interprets the body; it only edits and displays it.

See [`examples/Elowen Thistledown.md`](../examples/Elowen%20Thistledown.md) for
a complete file, and [`schema/character.schema.json`](../schema/character.schema.json)
for a machine-checkable definition of the header.

## Ground rules

- **Identification.** A file is a character file if its header has
  `formatVersion` and `rules.system`. Other Markdown files are left alone.
- **Unknown keys are preserved.** Anything the app doesn't recognise, at any
  level, is kept and written back unchanged. You can add your own fields.
- **Missing keys are fine.** Every field except `formatVersion` and `rules` is
  optional. A character with no `name` is shown by its file name. The app fills in what it can calculate when it displays
  the sheet.
- **Stable output.** When the app saves, it writes keys in the order listed
  below, with unknown keys after the known ones in their original order. Short
  maps and lists use flow style (`{ ... }`, `[ ... ]`). YAML comments in the
  header are not preserved (and anchors/aliases are expanded), so put
  commentary in the body.
- **Versioning.** `formatVersion` changes only for breaking changes. The app
  migrates older files when it opens them and always writes the newest version.

## Derived values and overrides

Some stored fields can be calculated from the rules: `combat`, `saves`,
`movement`, `exploration` and `spells.slots`. They are stored anyway, so the
file is complete and useful without the app.

There are **no override flags**. Instead:

- If a stored value **matches** what the rules give, it is *automatic*. The app
  updates it when something changes (for example, on level-up).
- If a stored value **differs** from the rules, it is an *override* (a house
  rule, a magic item, a GM ruling). The app keeps it, marks it subtly, and
  offers "Use rules value". It never changes it silently.
- If a field is **missing**, the app shows the rules value and writes it on the
  next save.

This means hand edits always win, and the file never needs extra metadata.

## Fields

| Key | Type | Notes |
|---|---|---|
| `formatVersion` | integer | Currently `1`. Required. |
| `rules.system` | string | Ruleset id. `ose` for Old-School Essentials. Required. |
| `rules.variant` | string | OSE: `classic` or `advanced`. |
| `rules.options.ascendingAC` | bool | If `true`, `combat.ac` is ascending and `combat.attackBonus` replaces `thac0`. Default `false`. |
| `rules.options.encumbrance` | string | `none`, `basic` or `detailed`. Default `basic`. |
| `rules.options.variableWeaponDamage` | bool | If `true`, attacks use each weapon's damage die; otherwise every PC attack does 1d6. Default `false`. |
| `name` | string | Character name. If missing, the app uses the file name. |
| `player` | string | Player name. |
| `title` | string | Optional title or epithet ("Baroness of Hightower"). |
| `portrait` | string | Optional image path, relative to the character file (`portraits/fingle.png`). |
| `class` | string | e.g. `Elf`, `Magic-User`. In Classic, race-as-class. |
| `race` | string | Advanced Fantasy only (`Human`, `Dwarf`, …). |
| `level` | integer | 1 or higher. |
| `alignment` | string | `Lawful`, `Neutral` or `Chaotic` (free text allowed). |
| `xp` | integer | Total experience points. |
| `abilityScores` | map | `str`, `int`, `wis`, `dex`, `con`, `cha` as integers. |
| `hp.max` / `hp.current` | integer | Hit points. |
| `hp.rolls` | list of integers | Hit die result per level, before CON. Optional history. |
| `combat.ac` | integer | Armour class (descending unless `ascendingAC`). |
| `combat.thac0` | integer | Descending style. |
| `combat.attackBonus` | integer | Ascending style. |
| `saves` | map | `death`, `wands`, `paralysis`, `breath`, `spells`: target numbers. |
| `movement` | integer | Base movement rate in feet per turn (encounter rate = ÷3). |
| `exploration` | map | X-in-6 chances: `listen`, `secretDoors`, `openDoors`, `findTraps`, `constructionTricks` (dwarves). |
| `thiefSkills` | map | Percentages: `climb`, `hide`, `moveSilently`, `openLocks`, `pickPockets`, `traps` (find/remove treasure traps); `hearNoise` is X-in-6. |
| `languages` | list of strings | |
| `spells.slots` | list of integers | Slots per spell level; index 0 = level 1. |
| `spells.spellbook` | list of `{ name, level }` | Spells known (arcane) or available (divine). |
| `spells.memorized` | list of `{ name, cast }` | Prepared today; `cast: true` once used. |
| `equipment` | list of items | Each item: `name` (required), `qty`, `weight` (coins), `equipped`, `damage`, `notes`. The app matches item names to the ruleset's equipment list (case-insensitive) to suggest damage, weight and cost; unmatched items are just free text. |
| `money` | map | `pp`, `gp`, `ep`, `sp`, `cp` as integers. |

## YAML tips for hand-editing

- Quote strings that contain `: `, `#`, a leading `'`/`"`, or that look like
  booleans or numbers (`"Yes"`, `"No"`, `"1e"`). When unsure, quote.
- Use spaces, not tabs, for indentation.
- Inside `{ ... }` and `[ ... ]`, a comma separates entries, so quote names
  that contain commas: `{ name: "Rope, 50'" }`.
