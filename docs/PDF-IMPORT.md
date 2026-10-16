# PDF Character Sheet Import

**File → Import PDF Character Sheet…** (⇧⌘I) turns a filled-in fillable PDF
into a character file. It reads the form fields with PDFKit
(`PDFDocument` → page annotations → `fieldName` / `widgetStringValue`), maps
them to the format, and opens the result as a new, unsaved document for you to
check.

Built from 9 real PDFs (`~/Documents/Game/OSR/OSE/OSE Characters/`). Most were
produced by `pdf-lib`, which suggests they came from an online character
generator, so other players' files will likely use the same layouts.

Code: `Packages/CharacterKit/Sources/CharacterKit/Import/`. Tests use the
form-field values of the 9 PDFs, saved as JSON in
`Tests/CharacterKitTests/Fixtures/pdf-fields/`, and also read the real PDFs
when they're on the machine.

> Don't copy the PDFs into the repo. The sheets contain Necrotic Gnome and
> James V. West artwork. Tests should load them from a local path and skip if
> they're missing, or use small form-only PDFs we make ourselves.

## Detecting the layout

| Layout | Detect by | Fields | AC style |
|---|---|---|---|
| **A**: Character Record Sheet, descending AC (2 pages) | has `THAC0`…`THAC9` | 63 | descending |
| **B**: Character Record Sheet, ascending AC (2 pages) | field names end in ` 2` (`Name 2`, `STR 2`) | 54 | ascending |
| **C**: Illustrated sheet by James V. West (1 page) | has `Current HP` and `Portrait` | 36 | ascending |

For layout B, strip the trailing ` 2` from field names before mapping. Some
fields (`STR Melee Mod`, `DEX Missile Mod`, `GP`, `XP`) have no suffix even on B.

## Field mapping

| Format key | A | B (after stripping ` 2`) | C |
|---|---|---|---|
| `name` | `Name` | `Name` | `Name` |
| `title` | `Title` | `Title` | `Title` |
| `class` | `Character Class` | `Character Class` | `Character Class` |
| `alignment` | `Alignment` | `Alignment` | `Alignment` |
| `level` | `Level` | `Level` | `Level` |
| `xp` | `XP` | `XP` | `XP` |
| `abilityScores.*` | `STR` `INT` `WIS` `DEX` `CON` `CHA` | same | same |
| `saves.*` | `Death Save` `Wands Save` `Paralysis Save` `Breath Save` `Spells Save` | same | same |
| `hp.max` | `Max HP` | `Max HP` | `Max HP` |
| `hp.current` | `HP` (may be `"6/3"`, meaning max/current) | `HP` | `Current HP` |
| `combat.ac` | `AC` (may be `"3 [16]"`, so take the first number) | `AC` | `AC` |
| `combat.thac0` / `attackBonus` | `THAC0` | `Attack Bonus` | `Attack Bonus` |
| `movement` | `Exporation Movement` (sic) | same | `Move` |
| `exploration.*` | `Listen at Door` `Open Stuck Door` `Find Secret Door` `Find Room Trap` | same | — |
| `languages` | `Languages` (comma list) | `Languages` | — |
| `money.*` | `PP` `GP` `EP` `SP` `CP` | same | `GP` (others not fillable) |
| equipment | `Weapons and Armour`, `Equipment`, `Magic Items`, `Treasure` | same | `Weapons and Armour`, `Equipment` |
| spells | `Abilities, Skills, Weapons`, `Notes` | same | `Abilities` |
| body: description | — | `Description` | `Description`, `Portrait` (added unless already in the description) |
| body: notes | `Notes` | `Notes` | — |

Ignore fields the rules can recalculate: `THAC1`–`THAC9`, ability modifiers
(`STR Melee Mod`, `DEX AC Mod`, …), `Unarmoured AC`, `XP for Next Level`,
`PR XP Bonus`, encumbrance totals, `Literacy`. If one disagrees with the rules,
the app's usual override notes will show it.

## Parsing free text

The generator writes structured text into free-form boxes:

```
Weapons: Long bow, Arrows (20), Sword
Armour: Chainmail, Shield
Abilities: Arcane Magic, Detect Secret Doors, ...
Spells: Sleep
```

- Split `Weapons:` / `Armour:` lines on commas, and each entry becomes an
  equipment item (`equipped: true` for weapons and armour). Treat
  `Armour: Unarmoured` as no armour.
- A trailing `(N)` with a plain number is a quantity: `Torches (6)` →
  `{ name: Torches, qty: 6 }`. Leave other parentheses alone:
  `Rations (iron, 7 days)`, `Caltrops (bag of 20)`.
- Line breaks can fall mid-item (`Arrows\n(16)`), so join the lines before
  splitting.
- If the armour entry is just numbers (`3 [16] 60 500`), match it against the
  armour table by AC, cost and weight (here: plate mail).
- `Abilities:` is class features. Drop it, because the rules data supplies them.
- `Spells:` (in the abilities box or in `Notes`) fills the spell book and
  memorized spells. At 1st level each spell gets `level: 1`; at higher
  levels the sheet doesn't say, so `level` is left out.
- Missing XP is written as `0`. Movement, exploration and thief skills are
  only imported when the sheet has them; otherwise the rules suggest them.
- Fields with a value that weren't imported (and aren't derived values) are
  listed in a banner above the new character.
- Languages: drop duplicates and the literal word `Alignment` (it means the
  alignment language, which is already listed by name).
- Remaining text from `Notes` and `Description` goes into the Markdown body.

## Data quirks seen in the samples

| Quirk | Example | Handling |
|---|---|---|
| Name missing | "the Halfling", "the Thief" | Leave `name` out; the app shows the file name |
| Alignment missing | the Thief | Leave it out; the app adds a rules note |
| HP blank | Marlek, the Thief | Leave `hp` out; the app suggests rolling (e.g. 1d4+2) |
| Trailing commas / blanks | `"Neutral, Common, "`, `", Common"` | Trim, drop empty entries |
| Name with trailing newline | `"Brother Cedric\n"` | Trim all values |
| Checkbox values | `Literacy: /Yes` | Ignored (derived) |
| Same character, different layouts | Cedric ×3, Halfling ×2 | Good test cases: each layout should give the same character |
| Off-list gear | Chalk, Bedroll, Chisel, Quill | Kept as free-text items |
