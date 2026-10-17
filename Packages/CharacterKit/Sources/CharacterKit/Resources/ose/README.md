# Classic Fantasy rules data

Data tables the app uses to suggest derived values. Transcribed from the
OSE SRD (OGL 1.0a, see `LICENSE-OGL.md`) and checked row by row against it.

Numbers and short summaries only. Full rules and spell text are not included.

| File | Contents |
|---|---|
| `ruleset.json` | Alignments, languages, save names, character creation rules, combat and exploration defaults |
| `abilities.json` | Ability score modifier tables and prime requisite XP modifiers |
| `classes-classic.json` | The 7 Classic Fantasy classes: requirements, restrictions, features, and a row per level |
| `equipment.json` | Weapons (with qualities and ranges), ammunition, adventuring gear, armour, and encumbrance tables |

## Conventions

- **Ability tables** (`abilities.json`) list one value per entry in `ranges`.
  For example, STR 14 falls in range `[13, 15]` (index 4), so `melee[4]` = +1.
- **X-in-6 chances** are stored as the X: `listen: 2` means 2-in-6.
  Percentages are stored as whole numbers.
- **THAC0** is stored. Ascending attack bonus = `19 - thac0`, and ascending
  AC = `19 - descending AC`.
- **Hit dice**: `hd` is the table's text (`"9d8+2"`). `conModifier: false` marks
  levels where CON no longer adds hit points.
- **Spell slots**: `spells[0]` is 1st-level spells. Levels with no spells omit
  the key.
- **XP modifier**: `"standard"` uses the prime requisite table in
  `abilities.json`. Classes with two prime requisites list rules instead; the
  first matching rule wins. `all` needs every score at or above its minimum;
  `any` needs at least one.
- **Exploration**: class values replace the defaults in `ruleset.json`.
  Open doors comes from STR.
- **Equipment ids** are lowercase slugs (`war-hammer`). Class weapon
  restrictions (`allowed` / `forbidden`) refer to these ids. Costs are in gp;
  weights are in coins, and `null` means the item's weight isn't tracked.
  Missile ranges are the far end of each band, in feet.
- **Buying**: `itemName` is how an item is written on a sheet when it's
  bought ("Arrows" for "Arrows (quiver of 20)"); `quantity` is how many come
  for the cost. A weapon with `soldAs` (torch, burning oil, holy water) is
  bought as that gear entry, so the shop lists it once.
- **Weapon damage**: every PC attack does 1d6 unless the character's
  `variableWeaponDamage` option is on.
- **Features** are short summaries in our own words. `minLevel` means the
  feature is gained at that level.

These tables feed suggestions only. The app never blocks a character that
breaks them (see "Suggest, never enforce" in `docs/PLAN.md`).
