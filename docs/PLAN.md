# Character Sheets — Plan & Roadmap

## Vision

A small, fast, native Mac app for keeping tabletop RPG characters. A character is
a plain Markdown file with a YAML header that you own, can read in any text
editor, sync anywhere, and keep in git. The app feels like a quiet text editor
that knows the rules: it suggests numbers and points out oddities, but it never
stops you from doing what your table actually does.

First ruleset: **Old-School Essentials** (Classic Fantasy, then Advanced Fantasy).

## Problems we're solving

Learned from converting real characters off the fillable OSE PDF sheet:

- **Data is written twice and drifts apart.** Fingle's arrows are 20 on page 1
  and 16 on page 2. Each fact should live in one place.
- **Derived values are slow to work out and easy to get wrong.** Fingle's AC
  leaves out the DEX bonus, and Cedric's +10% XP bonus was never filled in.
  The app should work these out, but let you override them.
- **Blank boxes leave you guessing.** Neither sheet has movement or
  exploration odds filled in, so you'd have to look them up mid-game.
- **Two different PDF versions for descending and ascending AC.** Here it's a
  single per-character option.
- **Free text goes in cramped boxes.** Backstory, clues and description need
  room, so they go in the Markdown body.

## Principles

Use these to settle scope arguments. If a feature breaks one, it waits.

1. **The file is the product.** It must be readable and editable without the app,
   and the app must never lose data it doesn't understand.
2. **Suggest, never enforce.** Calculated values are defaults. Any value can be
   overridden, and rule problems show up as quiet notes, never as errors or blocks.
3. **Uncluttered.** One window per character. It reads like a document, not a
   form. No accounts, no network, no telemetry.
4. **Native and light.** SwiftUI, a document-based app, one small dependency
   (Yams). It launches instantly.
5. **Rules are data.** Class tables, saves, XP and so on live in bundled data
   files. Adding a ruleset should mostly mean adding data.

## What "success" means

Nothing guarantees success. What we can do is define it concretely and remove
the usual reasons side projects die: too much scope, no real users, and a
format that keeps changing.

- **v0.5:** You use it for your own characters at a real table for a month, and
  you prefer it to paper or PDF.
- **v1.0:** Five or more other OSE players use it for a campaign arc without
  losing data, and the file format hasn't needed a breaking change.
- **Long term:** Adding a second ruleset takes weeks, not a rewrite.

### Tactics

- **Dogfood from day one.** Keep your real characters in this format, even
  before the app can edit them.
- **Freeze the format early.** Version it (`formatVersion`), write it down
  (`FILE-FORMAT.md`), and test that every file round-trips byte-for-byte.
- **Thin vertical slices.** Each milestone ends with something you can use at
  the table. Never spend months on infrastructure.
- **A "Not now" list** (below). Write ideas down so they don't get built yet.
- **Recruit testers early.** The OSE community (Necrotic Gnome's Discord,
  r/osr) is small, friendly and full of people who like plain text and
  old-school tools. Ask for feedback at M3, not at 1.0.
- **Test the rules tables.** A unit test per class checks saves, THAC0, XP and
  hit dice at every level against the published tables.

## Architecture sketch

```
CharacterSheetsApp (SwiftUI, DocumentGroup)
├── CharacterDocument      FileDocument: split front matter / body, read & write
├── Model
│   ├── Character          Codable struct mirroring the YAML header
│   └── RawFrontMatter     keeps unknown keys so nothing is ever dropped
├── Rules
│   ├── Ruleset            protocol: derived values, notes, level-up advice
│   ├── OSEClassic         implementation backed by data tables
│   └── Data/ose/*.json    classes, saves, XP, ability modifiers, spells per day
└── Views
    ├── SheetView          the main uncluttered sheet
    ├── NotesEditor        Markdown body
    └── Inspector          rules notes, derived-value explanations
```

Decisions:

- **Platform:** macOS 15 (Sequoia) and later. That covers the current release
  plus two older ones, including the last Intel-capable release (macOS 26).
  Newer APIs (e.g. Liquid Glass on 26+) go behind `if #available`. Test in a
  macOS 15 VM before each release. Keep views simple so an iPad build later
  is cheap.
- **File extension:** plain `.md`, so files open in Obsidian, iA Writer, VS Code
  and so on. The app recognises a character file by its `formatVersion` and
  `rules` keys.
- **YAML writing:** use our own emitter with a fixed key order and the
  documented style, so saving in the app produces clean, stable diffs. Yams
  handles parsing.
- **Distribution:** start with a notarised direct download (fast iteration).
  Decide on the Mac App Store at 1.0. The app is sandbox-friendly either way.

## Roadmap

### M0: Foundations (now)
- [x] File format spec (`docs/FILE-FORMAT.md`)
- [x] Sample character (`examples/`)
- [x] JSON Schema for validating the header (`schema/`)
- [x] OSE Classic data tables (now in CharacterKit `Resources/ose/`): 7 classes, ability modifiers, armour,
      encumbrance, checked against the SRD
- [x] Weapons, ammunition and adventuring gear lists, checked against the SRD
- [x] Convert real characters from the PDF sheets: all 7 classes covered
      (Elowen is the made-up sample; the other 6 are real)
- [x] Map the three fillable-PDF layouts for the importer (`docs/PDF-IMPORT.md`)

### M1: Open & save
- [x] Xcode project, document-based app, `.md` registered as an alternate
      editor (doesn't take over Markdown files from other apps)
- [x] `CharacterKit` package: parse front matter + body; unknown keys, key
      order, block/flow style and quoting preserved; our own YAML writer
- [x] Round-trip tests: all example files are rewritten byte for byte (24 tests)
- [x] Minimal editor: raw text with a status bar (character / not a character
      / YAML error with line number)

### M2: The sheet
- [x] Save through `CharacterKit`; files that don't parse open as text and
      save exactly as typed
- [x] Clean sheet layout: identity, ability scores, combat, saves,
      exploration (+ thief skills), languages, spells, equipment, money
- [x] Inline editing of every field; class and alignment suggestions; per-
      character Rules menu (ascending AC converts AC and THAC0 for you)
- [x] Notes area (the Markdown body)
- [x] "Edit as Text" for anything the sheet doesn't show; unknown keys and
      header comments are pointed out
- [ ] Check undo/redo, autosave and versions by hand (they come from the
      document architecture). Undo is currently per keystroke in text fields
- [ ] Polish pass after using it at the table

### M3: Rules assist ← first outside testers
- [x] Rules engine in CharacterKit (`RulesAnalysis`), tested against every
      example character: modifiers, saves, THAC0/attack bonus, AC from worn
      armour, movement (all three encumbrance options), XP bonus and next
      level, exploration odds, thief skills, spell slots
- [x] Weapons: to-hit as "THAC0 [bonus]" for melee (STR) and missile (DEX,
      halfling +1), damage (1d6, or the weapon's die with variable damage), ranges
- [x] Override markers (value differs from the rules) with "Use Rules Value";
      empty fields show the rules value in grey; Rules → Fill In Missing Values
- [x] Rules notes: class requirements, level limits, armour, shield and weapon
      restrictions, holy symbol, unused languages, HP to roll, XP to level up
- [x] Level-up helper: shows every change, keeps overrides, rolls HP (fixed
      gains after 9th level), then applies
- [x] Calculated values have stable names (`namedValues`) for custom layouts
- [ ] Layout pass with your sheet design (see Later: custom layouts)

### M4: At the table
- [x] Fast HP tracking (damage / heal, healing stops at max), spell "cast"
      checkboxes with Rest, "use one" for ammo and torches
- [x] Print (⌘P) and File → Export as PDF…: a one-page sheet, then the notes
      (Letter or A4 from Page Setup)
- [x] New-character flow (File → New Character…, ⌥⌘N): roll 3d6 in order,
      pick a class (unmet requirements shown, not enforced), optional score
      adjustments, hit points, starting gold. Rolls show every die and can be
      typed in from real dice.
- [x] **Import PDF character sheets** (PDFKit form fields; three layouts,
      see `docs/PDF-IMPORT.md`). Opens the result as a new document to review.

### M5: Ship 1.0
- [x] TestFlight setup: signing team, export compliance, upload script
      (`scripts/testflight.sh`, see `docs/RELEASING.md`)
- [x] Placeholder app icon (`scripts/make-placeholder-icon.swift`)
- [ ] Final app icon
- [x] About window attributions; Help → Open Game License
- [x] Help window (shown on first launch) explaining the sheet and the file
      format; Help → Open Sample Character; Help → Send Feedback…
- [ ] Beta with testers; layout pass from their feedback
- [ ] Final app name, App Store listing, simple website, announce to the
      OSE community

### Between betas
- [x] Party view: File → Open Party Folder… lists everyone in a folder (HP,
      AC, attack, saves, XP) and updates as files change. Read-only.
- [ ] OSE Advanced Fantasy: waiting on permission from Necrotic Gnome. The
      pre-2026 Player's Tome reserves its class and race sections as Product
      Identity; a Creative Commons SRD is announced for early 2027.

### Later
- Quick Look preview. Deferred: character files are plain `.md`, so a
  preview extension would take over every Markdown file's preview.
- Dice roller on the sheet: optional at most. Players prefer to see real
  rolls; the app only rolls in character creation and level-up.
- **Custom sheet layouts:** a layout file (likely YAML or JSON) that places
  fields by path (`saves.death`) and calculated values by name (`str.mod`,
  `weapons.0.melee`, from `RulesAnalysis.namedValues`). Import a layout to
  get a different sheet; the character file doesn't change.
- iPad version
- More rulesets: Basic Fantasy, B/X variants, 5e (SRD 5.2, CC-BY-4.0)
- Retainers and hirelings as linked character files

## Not now

Anything here needs a strong case before it moves up:
- Accounts, cloud sync service, or online sharing (iCloud Drive / Dropbox already work)
- Bestiary, encounter builder, or DM tools
- Full rules text or spell descriptions inside the app
- Plugins / user-scripted rules
- Electron, web, or Windows versions

## Risks

| Risk | Mitigation |
|---|---|
| Scope creep stalls the project | Principles + "Not now" list. Each milestone is usable on its own. |
| Saving reformats files that users edited by hand (comments lost, key order changed) | Our own emitter with fixed order. Document that YAML comments go in the notes body. Preserve unknown keys. |
| YAML gotchas (`no` → false, indentation) | Emitter quotes strings when needed. The app shows a friendly parse error with the line number instead of refusing to open the file. |
| Rules tables contain typos | Unit tests against the published tables for every class and level. |
| Licensing | Ship numbers and short text written by us. Use the OSE SRD under OGL 1.0a with the required notices. Never use "OSE" or "D&D" as product branding. Check the license terms again before release. |
| PDF import meets sheet layouts we haven't seen | Detect the layout from its field names. Import whatever maps, list what didn't, and never fail outright. |
| Format needs to change | `formatVersion` plus a migration step on load. The app writes only the newest version. |

## Open decisions

- App name (avoid "OSE" and "D&D" in it). The bundle id is
  `com.mitchellhudson.CharacterSheets`; the signing team is still to set.
- Whether to sign up for Necrotic Gnome's third-party license. Without
  it the app must not claim compatibility with Old-School Essentials
  (OGL section 7), so the ruleset is labelled "Classic Fantasy".
- Free, paid, or pay-what-you-want
