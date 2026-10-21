# Code review

A periodic check of the whole project. A review finds problems and records
them here; it doesn't change behaviour. Fixes happen afterwards in small
branches, one theme at a time.

## When

- Before each 1.x release, and before 1.0.
- After a big feature lands (a new ruleset, iOS work).
- Otherwise every few TestFlight builds, or when a file has grown past
  about 600 lines.

## How

1. **Automated pass.** Build with warnings shown, run the tests, build
   CharacterKit for iOS, check the examples and schema (see Automated
   checks). Anything these find is a finding.
2. **Read through by area**, using the checklist below. Areas: CharacterKit
   (file, rules, creation, shop, import), the sheet, other windows (New
   Character, Party, Shop, Settings, Help), printing, scripts and docs.
3. **Record findings** in the log at the end: what, where (file:line),
   why it matters, and how big the fix is (S/M/L). Mark each as **fix
   now**, **next time**, or **leave** (with the reason).
4. **Agree the list** before fixing anything.
5. **Fix in themed branches** (e.g. `cleanup-dead-code`,
   `ruleset-protocol`), tests first where behaviour is involved. Anything
   that changes the UI is hand-tested before it's ticked off.
6. **Close the review** with the date, the build it covered, and what's
   left for next time.

## Automated checks

- `xcodebuild … build` with no new warnings (the app and CharacterKit).
- `swift test` in `Packages/CharacterKit`: all pass, and how long they take.
- CharacterKit builds for iOS:
  `xcodebuild -scheme CharacterKit -destination "generic/platform=iOS" build`
  in `Packages/CharacterKit`. A failure means Mac-only code crept in.
- Every file in `examples/` opens and saves back unchanged (round trip).
- `schema/character.schema.json` matches `docs/FILE-FORMAT.md` and the
  keys the code reads and writes.
- Unused code: compiler warnings, plus a search for declarations with no
  references (or Periphery, if installed).

## Checklist

### Leftovers
- Code nothing calls: functions, types, properties, enum cases, debug
  hooks, old parameters with one value.
- Comments that describe old behaviour; TODOs that are done or stale.
- Files and assets no longer used (images, fixtures, examples, scripts).
- Settings keys (UserDefaults) the app no longer reads.

### Tests
- Tests for code that's gone, or that only test Swift or a library.
- Overlapping tests that check the same thing; slow tests.
- Gaps: rules and file logic that lives in the app (views) instead of
  CharacterKit, so it can't be tested. Moving it is usually the fix.
- Fixtures still match the current file format.

### Data safety (the app's first promise)
- A file opened and saved without changes comes back byte for byte.
- Unknown keys, comments in notes, and hand formatting survive edits.
- No write happens without a user action (tabbing, opening, analysis).
- Undo: one step per edit, and an undo never registers as a new edit.
- Security-scoped access is started and stopped in pairs.

### Structure and the future
- **Rulesets.** How much assumes OSE Classic Fantasy (`OSERuleset.classic`,
  hard-coded class names and alignments in the app, "ose" strings)?
  Advanced Fantasy and other rulesets need one place to plug in.
- **Single source of truth.** The same fact or helper in two places (class
  lists, sign formatting, legal text, defaults).
- **Where logic lives.** Views should show and edit; rules, calculations
  and file changes belong in CharacterKit.
- **Size.** Files and views that do too much (`Sections.swift`,
  `Components.swift`, `NewCharacterView.swift`, `RulesAnalysis.swift`).
- **Performance.** Work repeated on every redraw (e.g. building a
  `RulesAnalysis` more than once per change), file watching, large parties.
- **Concurrency.** Swift 6 strictness, main-actor use, no warnings
  silenced without a reason.

### iOS and iPad readiness
- CharacterKit stays free of AppKit (checked automatically above).
- In the app, list each AppKit use (panels, alerts, `NSWorkspace`,
  `NSTextView`, printing, window tabbing and tiling, `NSSound`) and whether
  it's behind a small wrapper that an iOS version could replace.
- Layout that assumes a mouse, hover tooltips, right-click, or a wide
  window; keyboard shortcuts with no on-screen way in.
- Menu commands that would need a toolbar or context menu on iPad.

### Users
- Accessibility: VoiceOver labels on icon-only buttons and custom boxes,
  keyboard reachability, contrast in dark mode, Zoom at 200%.
- Error messages say what happened and what to do.
- Wording matches Help and the docs; Help covers every feature.
- Localization readiness (later): user-facing strings in one form.

### Licensing and legal
- No rules or spell text copied from Old-School Essentials; summaries in
  our own words.
- `App/Help/Legal.swift`, About, Licenses and Legal, the website and the
  App Store text still say what the third-party license requires.
- The logo is shown as supplied and smaller than the app's name.
- OGL notices and third-party licenses (Yams) are complete.

### Project hygiene
- Docs that have drifted: `PLAN.md` ticks, `FILE-FORMAT.md`,
  `TESTING.md`, `RELEASING.md`, Help.
- Dependencies (Yams) up to date; the minimum macOS still right.
- Scripts still work (`testflight.sh`, the icon script).
- Build settings: version numbers, entitlements no wider than needed.

## Review log

### 1 — 21 Oct 2026, build 202610211603 (main at f4c1451)

**Automated checks.** Clean build with no warnings. 164 tests pass in
2.2 s. CharacterKit builds for iOS. Every example and the Help sample
character round-trip byte for byte. The schema has drifted (A1).

Sizes: app 4,540 lines, CharacterKit 3,595, tests 2,144.

Decisions: **now** = this cleanup; **next** = next review or when the code
is touched; **leave** = no change, with the reason.

#### Automated
- **A1** `schema/character.schema.json` lacks `carryingTreasure` and
  `spells.memorized[].level`, and no test ties it to the keys the code
  writes (`Layout.keyOrders`). Fix the schema and add that test. S, now.

#### Leftovers
- **L1** `RulesAnalysis.swift`, `wornArmour()`: two doc comments, the old
  one stale. `Components.swift`: the `Binding` helpers' doc comment is
  split by a `//` comment. S, now.
- **L2** `docs/PLAN.md` "Architecture sketch" describes a design that
  wasn't built (a `Character` struct, a `Ruleset` protocol, an
  Inspector). Replace it with the real structure. S, now.
- **L3** `RulesAnalysis.namedValues`: only a test uses it, and it was
  written ahead for custom layouts. Remove it with its test; git keeps it
  for when layouts start. S, now.
- **L4** Rules data decoded but never shown: class `features` summaries
  and `minLevel`, `infravision`, encumbrance `maxLoad`. Not dead code:
  see S8. Leave until S8 is decided.
- **L5** Fixture `the Halfling-1.json` is used only by
  `realPDFsWhenPresent`, which reads PDFs from your Documents folder and
  passes without them. Keep it, and say so in the test. S, now.

#### Tests
- **T1** Dice tests are split between `CreationTests` and
  `RandomCharacterTests` (keep-highest). Move them into one Dice suite.
  S, now.
- **T2** Logic in the app that tests can't reach: `Movement` (encumbered,
  explanations), `ParseStatus` (the Edit as Text status bar), and a house
  weapon's damage (`rulesDamage`). Move each into CharacterKit and test
  it. M, now (goes with S3 and S5).
- **T3** Class restriction messages are tested twice, in Shop and Rules.
  They merge with S4.

#### Data safety
- **D1** Security-scoped file access is started but never stopped:
  Settings → Edit starts it on every click, and reopening a party folder
  starts it again each time. Pair them up. S, now.
- **D2** Undo said to flip between two values (tester report, 19 Oct).
  Reading the code doesn't explain it. Needs steps to reproduce.
  Open.
- Checked and fine: setters skip writes when nothing changed; round
  trips; unknown keys; safety tests.

#### Structure and the future
- **S1** The ruleset is hard-wired. `RulesAnalysis`, `NewCharacter` and
  the shop default to `OSERuleset.classic` and never read the file's
  `rules.system` or `rules.variant`. The app also keeps its own lists of
  classes, alignments and spellcasting classes (the `OSE` enum in
  `SheetView.swift`). Advanced Fantasy needs one lookup from a file to
  its rules, used everywhere, with the `OSE` enum replaced by the rules
  data. M, now (before Advanced Fantasy).
- **S2** The sheet and printout decide what to show by comparing class
  names (`== "Thief"`, `== "Dwarf"`). A class typed in lower case gets the
  rules but not the boxes. Ask the class's rules instead. S, now (with S1).
- **S3** The custom equipment list is invisible to the rules. A house
  weapon's damage is worked out in a view, and the Weapons section
  (to-hit, ranges) leaves house weapons out. Give the analysis the list.
  M, now (with T2).
- **S4** Class restriction messages are written in two places
  (`Shop.restriction` and `RulesAnalysis`), and their wording differs.
  One source. S, now.
- **S5** Duplicated helpers: "+1"/"−1" formatting in about 10 places
  (CharacterKit's `signed` isn't public); "stored value, or the rules
  value" in both `PartyMember` and `PrintedSheet`; Party's name fallback
  next to `CharacterFile.name`. S, now.
- **S6** `Sections.swift` (812 lines, 15 types) and `Components.swift`
  (543) are too big to find things in. Split by section. M, mechanical;
  next (after the fixes above, to keep their diffs readable).
- **S7** Settings keys are spread over five files, two of them as bare
  strings. One place. S, next.
- **S8** Class abilities (back-stab, infravision, the rest) are in the
  data but never shown on the sheet. A product question: add a Class
  Abilities section, or trim the data. Into the plan.

#### iOS and iPad
- **I1** CharacterKit is ready. 15 app files use AppKit:
  - **Shared SwiftUI versions exist:** file panels (`fileImporter`,
    `fileExporter`), `NSAlert` (`.alert`), `NSSound.beep` (a small
    helper), Show in Finder and the mail link.
  - **Mac-only:** window tiling and tabs, the Settings scene. Leave out
    on iOS.
  - **Need an iOS version:** the Notes and text editor (`NSTextView`),
    printing.
  Recommendation: no iOS work yet. When touching a panel or alert, use
  the SwiftUI version, which works on the Mac too. Next.
- **I2** Information that's only in hover tooltips (`.help`), such as
  rules explanations and the encumbered rate, and actions only on
  right-click, such as moving equipment. iPad has neither. Note for the
  iOS layout pass. Leave.

#### Users
- **U1** About 16 status icons have no VoiceOver label: party warnings,
  ready to level up, rules note icons. S, next.

#### Licensing
- Passed: no rules text; notices in `Legal.swift`, About, Licenses and
  Legal, and the website; the logo is unaltered and smaller than the
  name.

#### Hygiene
- **H1** `scripts/testflight.sh` builds whatever is in the working tree,
  committed or not, and doesn't record the commit. Warn about uncommitted
  changes and print the commit hash. S, now.
- **H2** Check Yams for updates before 1.0. Leave until release.

**Fixed in `cleanup-small` (21 Oct 2026):** A1 (schema, plus a test
that fails when the schema and the app's keys differ), L1, L2, L3, L5,
T1, D1 (`App/ScopedAccess.swift`), H1. No visible change in the app.

**Left for next time:** S6, S7, I1, U1, H2, D2 (once there are steps to
reproduce it), and S8 (a plan decision).
