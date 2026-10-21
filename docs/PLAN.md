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

## Architecture

As built (checked in code review 1, 21 Oct 2026):

```
Packages/CharacterKit        Swift package, no AppKit (builds for iOS)
├── CharacterFile            YAML header kept as a node tree (order, style,
│   Paths, Layout,           unknown keys survive) + Markdown body;
│   YAMLWriter               path-based reads and writes; our own emitter
├── Rules/
│   ├── OSERuleset           Classic Fantasy tables from Resources/ose/*.json
│   ├── RulesData            decoded classes, abilities, equipment
│   ├── RulesAnalysis        suggestions, notes, weapons, movement; never
│   │                        changes the file
│   └── LevelUp              level up and down plans, applied to the file
├── Creation/                NewCharacter, RandomCharacter, Dice
├── Shop, EquipmentList      buying, prices in copper, custom lists
├── Spells, TableActions,    spell rows, HP and "use one", party summaries
│   Party
└── Import/                  PDF character sheets
App (SwiftUI, macOS)
├── CharacterDocument        FileDocument: a sheet, or plain text
├── CharacterWindow(s)       one window per file; tiling and tabs
├── Sheet/                   SheetView, sections, components, zoom, level up
├── NewCharacter/, Shop/, Party/, Settings/, Help/, Print/
```

Rules are data plus `RulesAnalysis`. A file's `rules.system` and
`rules.variant` pick its ruleset (`CharacterFile.ruleset`, from
`OSERuleset.all`); rules the app doesn't have fall back to Classic Fantasy
with a note. Advanced Fantasy is added by loading its data as a second
`OSERuleset` and listing it in `OSERuleset.all`.

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
- [x] Undo is one step per field edit, not per keystroke: text fields
      write to the document on Return or leaving the field, like the number
      fields. Notes and Edit as Text have their own typing undo while you're
      in them (the shared one crashed after Edit as Text → Cancel).
- [x] Check undo/redo, autosave and versions by hand (`docs/TESTING.md`,
      "Undo, autosave and versions")
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
- [x] Calculated values have stable names (`namedValues`) for custom layouts.
      Removed in code review 1 (21 Oct 2026) as unused; it's in git history
      (`RulesAnalysis.namedValues`, before cleanup-small) for when custom
      layouts start.
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
- [x] **Equipment from the rules:** "Add from list…" beside Add item opens
      the ruleset's weapons, armour, ammunition and adventuring gear
      (search, cost, damage or AC, weight). Choosing one fills in the name,
      quantity (a quiver is 20 arrows) and damage, marks items the class
      can't use, and offers to pay for it from the character's money,
      making change. The same list as a shopping step in New Character,
      spending the rolled gold. Free-text items stay as they are.
- [x] **Sheet windows:** as narrow as 500 points (rows of boxes wrap).
      Window → Tile Character Sheets, Merge Sheets into Tabs, and an Open
      Sheets in Tabs setting.
- [x] **Custom equipment lists:** a plain file (Markdown with a header,
      like a character) listing changes from the rules: new prices, removed
      items, house items. Settings → Equipment chooses the rules list or a
      custom file; New List… starts one to edit. The shop marks house items
      and prices. Groups share the file through a shared folder.
      Format drafted in `docs/EQUIPMENT-FORMAT.md`, with an example in
      `examples/equipment/`. Parser, copper prices, and Settings →
      Equipment done and checked by hand.
- [ ] **Random character and house rules in New Character:** a Random
      Character button rolls everything (the best class for the scores,
      adjustments that reach a better XP bonus without losing a modifier,
      a starting kit from the shop), then everything can be changed. House
      rules, remembered between characters: roll 4d6 and drop the lowest,
      and swap scores. The thief's "can't lower STR" from the class data is
      now pointed out. Sub-par characters (optional rule) are pointed out,
      and the random roll uses that rule and the 1st-level HP reroll.
      Sub-par: every score below 9, or two or more below 7 (checked
      against the rules site).
- [ ] **Rearrange equipment:** drag rows by a handle, or right-click it
      for Move Up / Down / to Top / to Bottom.
- [ ] **Rules values within reach:** Return in an empty box fills in the
      grey rules value; Edit → Use Rules Value (⌥⌘R) for the box being
      typed in. (Right-clicking a box shows the text field's own menu.)
- [ ] **Zoom:** View → Zoom In / Zoom Out / Actual Size (⌘+ ⌘− ⌘0) for
      the sheet's text, 85%–200%, for every sheet, remembered. Fonts and box
      widths scale together (sharp text, same layout).
- [ ] **Roll Max HP** from the sheet when it's empty: every hit die at the
      current level, dice shown, or a typed total. Return fills a weapon's
      grey damage.
- [ ] **Movement where it's used:** Combat shows the encounter rate (feet
      per round); Exploration shows the rate per turn and overland travel
      (miles a day). Both are worked out from the one stored rate. When the
      load slows the character, the rates are outlined and say
      "encumbered", with the unencumbered rate in the tooltip. Basic
      encumbrance gets a Carrying treasure checkbox (`carryingTreasure` in
      the file); a rate that followed the rules follows the checkbox. The
      printed sheet matches.
- [ ] OSE Advanced Fantasy: Necrotic Gnome offered special permission
      (21 Oct 2026) for the class names and advancement tables. The
      Creative Commons SRD (early 2027) will only be the B/X material, so it
      won't add these classes. Next: confirm the scope with them (see Open
      decisions), get their permission note, then add the classes.
- [ ] **Use the third-party license** (decided 21 Oct 2026, see Open
      decisions). Done, to check by hand: a new About window (logo,
      "Requires Old-School Essentials", trademark line, "independent app"
      note); Help → Licenses and Legal (was Open Game License) with the same
      notices, then the OGL and Yams; Help and the website name the game; the
      logo is in the asset catalogue and `site/images/`. Still to do: the App
      Store listing (description says Old-School Essentials and "Requires
      Old-School Essentials"; subtitle may say OSE), and after release a
      promo code for Necrotic Gnome (summon@necroticgnome.com).

### Later
- Quick Look preview. Deferred: character files are plain `.md`, so a
  preview extension would take over every Markdown file's preview.
- Dice roller on the sheet: optional at most. Players prefer to see real
  rolls; the app only rolls in character creation and level-up.
- **Custom sheet layouts:** a layout file (likely YAML or JSON) that places
  fields by path (`saves.death`) and calculated values by name (`str.mod`,
  `weapons.0.melee`; bring back `RulesAnalysis.namedValues` from git). Import a layout to
  get a different sheet; the character file doesn't change.
- iPad version
- More rulesets: Basic Fantasy, B/X variants, 5e (SRD 5.2, CC-BY-4.0)
- Retainers and hirelings as linked character files
- **Campaign folders:** a party folder's own `Equipment.md` (and later
  other house rules) applies automatically to characters opened from it.
  Needs folder access, which the party view already has.

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
| Licensing | Ship numbers and short text written by us. Use the OSE SRD under OGL 1.0a with the required notices, and Necrotic Gnome's third-party license for the name and logo (`App/Help/Legal.swift` has its required text). Never put "OSE", "Old-School Essentials" or "D&D" in the app's name ("OSE" may go in the App Store subtitle). Check the license terms again before release. |
| PDF import meets sheet layouts we haven't seen | Detect the layout from its field names. Import whatever maps, list what didn't, and never fail outright. |
| Format needs to change | `formatVersion` plus a migration step on load. The app writes only the newest version. |

## Open decisions

- App name (avoid "OSE" and "D&D" in it). The bundle id is
  `com.mitchellhudson.CharacterSheets`; the signing team is still to set.
- **Decided (21 Oct 2026): use Necrotic Gnome's third-party license**
  (v1.7, in `docs/Old-School Essentials Third Party License-…/`). Their
  answers removed the open questions. Without the license the app couldn't
  claim compatibility with Old-School Essentials (OGL section 7), which is
  why the ruleset is labelled "Classic Fantasy" for now. The license is
  free and needs no approval. It allows:
  - "Old-School Essentials" in the app, Help, listing and website, and
    classes, spells and rules referred to by name
  - "OSE" in a subtitle (App Store subtitle), never in the app's name
  - the "Designed for use with Old-School Essentials" logo

  It requires:
  - nothing that implies the app is official or approved, and our own
    look
  - their trademark line in the legal text (About, the license window,
    website)
  - a copy for Necrotic Gnome after release (a promo code)

  Questions asked by email to summon@necroticgnome.com, answered by
  their customer support on 21 Oct 2026:
  1. *Does it cover an app, and where do the logo and "Requires" line
     go?* Yes. An about page or legal page is a good place for the logo.
  2. *Can the SRD's class tables ship as data?* Yes, that's correct
     under the license. (The advancement tables are in the Character
     Classes section, not Player Characters.)
  3. *Advanced Fantasy before the Creative Commons SRD?* That SRD will
     only be the B/X material, so it won't add the classes. They're happy
     to give special permission for **class names and advancement
     tables**, and will send a suggested permission note once we confirm
     that's what we want.

  Still to settle with them: whether that permission also covers the
  short facts the app uses for Classic Fantasy classes (requirements,
  prime requisites, XP modifiers, armour and weapons allowed, languages,
  infravision, level limits, and races' ability limits). Without them,
  the Advanced Fantasy classes get tables only, and the player types
  restrictions themselves. Reply drafted 21 Oct 2026, not sent yet.
- Free, paid, or pay-what-you-want
