# Testing a build

The CharacterKit tests (run by `scripts/testflight.sh` before every upload)
cover the rules tables, level-up, PDF import, and that files survive edits
unchanged. This checklist covers what only a person can see: how the app
looks and behaves. It takes about 10 minutes.

Run it on the TestFlight build itself (not a debug build from Xcode) before
adding the build to the external group. Work on copies of your characters.

## Smoke test

**Launch**
- [ ] The app opens. Help → Character Sheets Help opens and reads correctly.
- [ ] App menu → About Character Sheets shows the right version and build,
      the "Designed for use with Old-School Essentials" logo (white in light
      mode, black in dark mode, not stretched, narrower than the app name),
      "Requires Old-School Essentials." and the trademark line. Licenses and
      Legal… opens the license window.
- [ ] Help → Licenses and Legal: the Old-School Essentials notices and logo,
      then the Open Game License, then Yams.

**Sample character** (Help → Open Sample Character, then save a copy)
- [ ] The sheet looks right: no clipped text, overlapping boxes, or empty
      sections that should have values.
- [ ] Type a different save or AC: the orange override dot appears.
      Clicking the dot → Use Rules Value removes it.
- [ ] Clear a box: the grey rules value comes back.
- [ ] Tab through every box without typing anything, then close. The app
      doesn't ask to save (nothing changed).
- [ ] Rules menu: switch ascending AC on and off; the combat boxes follow.
- [ ] Type the class in lower case ("thief", "dwarf", "cleric"): thief
      skills, construction tricks and spells still appear, as for "Thief".
- [ ] Edit as Text, change `variant: classic` to `variant: advanced`, Done:
      a rules note says Classic Fantasy is used where the rules match, and
      saves and attacks still fill in. Change it back: the note goes.
- [ ] Movement: Combat → Move is a third of Exploration → Move, and
      Travel is a fifth (120' → 40' per round, 24 mi per day). Change the
      rate under Exploration; both follow. The two worked-out boxes are
      outlines with no fill, so they don't look like they can be typed in.
- [ ] Basic encumbrance, wearing leather: tick Carrying treasure. The rate
      drops from 90' to 60' and all three boxes are outlined and say
      "encumbered"; the tooltip gives the unencumbered rate. Untick: back
      to 90'. With a hand-typed rate (240'), the checkbox doesn't change it.
- [ ] List leather armour and chainmail with neither ticked Equipped: AC
      and movement use chainmail, and a rules note says so. Tick leather:
      AC and movement follow it and the note goes.
- [ ] Equipment: drag a row by its ≡ handle onto another row; a line shows
      where it goes and it moves there. Right-click the handle: Move Up,
      Down, to Top and to Bottom. One ⌘Z undoes one move. Dragging a row
      into a text field doesn't type anything; dragging between two sheets
      does nothing.
- [ ] An empty box showing a grey rules value: click in it and press
      Return; the value is filled in. Tabbing out without Return leaves it
      empty. Edit → Use Rules Value (⌥⌘R) works in any box with a rules
      value, empty or overridden. A weapon's grey damage (1d6): click in
      Damage, press Return; it's filled in.
- [ ] Clear Max HP: a "Roll 3d8…" link appears under it. Roll shows each
      die and the total (CON added per die, at least 1 each); typing a total
      works too. Use sets Max HP, and Current HP if it was empty. One ⌘Z
      undoes it.
- [ ] View → Zoom In (⌘+) a few times, Zoom Out (⌘−), Actual Size (⌘0).
      All text on the sheet grows, including Notes; boxes widen to fit and
      rows wrap in a narrow window. Every open sheet follows, and the size
      is kept after relaunching. Printing is unchanged.
- [ ] With the Hightower Market list chosen (Settings → Equipment), a thief
      with a Hand crossbow and a Gambeson: the crossbow is in the Weapons
      section (1d4 with variable damage, 30 / 60 / 90'), AC is 8 and Move
      90'. Make the character a cleric: a rules note says clerics don't
      normally use a hand crossbow. Switch to the rules list: the crossbow
      leaves the Weapons section and AC goes back to 9.
- [ ] Class warnings read the same in the shop and in the rules notes
      (a cleric with a sword: "Clerics normally use blunt weapons only, not
      a sword.").
- [ ] Detailed encumbrance: add chainmail and 200 gp. The rates drop and
      say "encumbered"; the tooltip gives the coins carried. No checkbox.
- [ ] Print: Combat shows the per-round rate; Exploration shows the rate
      per turn and travel per day.

**At the table**
- [ ] Damage / Heal: type 3, press Return; HP drops by 3. Heal can't go
      above max.
- [ ] HP at 0 shows the "dead" rules note.
- [ ] The − next to an item quantity uses one, and stops at 0.
- [ ] Spells: + memorizes a copy (a Cast box appears), − forgets one, and
      the "memorized" count under the slots follows. Tick Cast; Rest clears
      it. Rename a spell: its memorized copies follow.
- [ ] Edit → Undo reverses each of these.

**Equipment**
- [ ] Add from List…: search finds items; a Magic-User sees ⚠︎ on swords and
      armour. Add Arrows: the sheet gets Arrows × 20 and 5 gp less. Add
      again: the same line goes to 40.
- [ ] Buy something costing more than the gold pieces on hand but less
      than all the money: change comes back in gp/sp/cp and the total is
      right. Something unaffordable can't be added until Pay is unticked.
- [ ] A weapon added from the list shows its damage in grey.
- [ ] Settings → Equipment → New List…: the file opens as text, with
      "Equipment list: … · No changes yet" in the status bar. Uncomment the
      Sword and Mule lines and save: Settings says "Changes 1, adds 1".
      The shop says "Prices from …", Sword costs 15 gp (rules price in its
      tooltip), and Mule is tagged House.
- [ ] Misspell an item in the list: Settings and the status bar show the
      problem, and the shop counts it. The rest of the list still applies.
- [ ] Choose `examples/equipment/Hightower Market.md`: a lucky charm costs
      2 sp and paying for it makes change. New Character shows money left
      in gp and sp. A hand crossbow shows 1d4 in grey on the sheet (with
      variable weapon damage on).
- [ ] Quit and relaunch: the same list is still chosen. Use Rules List:
      the shop is back to rules prices.
- [ ] New Character: roll gold, Buy Equipment…, buy armour and a weapon;
      gold left goes down. The created sheet has the gear, the gold left,
      and AC filled in.

**Level up**
- [ ] Give the character enough XP: Level Up… is highlighted. The changes
      listed look right; roll or type the hit die; overrides are kept.
- [ ] Level up without enough XP: the dialog warns and offers to set XP.
      Leave it unticked: the sheet shows a rules note that XP is below the
      level.
- [ ] Level Down… (arrow beside Level Up) on Elowen: saves and slots go
      back, it suggests losing 4 HP (her last roll), and offers XP 0. Level
      up again afterwards: everything comes back.
- [ ] Type a Max HP the hit dice can't give (25 for a 1st-level
      Magic-User): a rules note says so.
- [ ] Clear Max HP, then level up: the dialog asks for Max HP first (type it
      or roll the hit dice shown under Max HP).

**New character** (File → New Character…, ⌘N; File → New Blank Sheet, ⌥⌘N)
- [ ] Roll scores, pick a class (an unmet requirement shows in orange),
      adjust, roll HP and gold, Create. The new sheet matches what you chose.
- [ ] Buy equipment, Create, then open New Character again: it starts
      empty (no scores, class or equipment from last time). Same after Cancel.
- [ ] Random Character a few times: each fills every section, the class
      has no unmet requirement, adjustments show no warnings, the kit fits
      the gold and the class (no armour for a magic-user, a holy symbol for
      a cleric, thieves' tools for a thief). The name and AC style are kept.
      With a custom equipment list, the kit comes from that list.
- [ ] Roll: 4d6, drop the lowest. Each score shows four dice with the
      lowest struck through. The choice is kept after closing the window.
- [ ] Allow swapping scores: a swap button per score; swapping moves the
      score and its dice and clears adjustments. Off hides the buttons.
- [ ] Type in very poor scores (all 8 or less, or 6, 7, 6, 8, 12, 14):
      the optional sub-par rule is pointed out under the scores. With only
      one score below 7 (6, 7, 7, 8, 12, 14) it isn't.

**Import** (File → Import PDF Character Sheet…, ⇧⌘I)
- [ ] Import a filled-in sheet. The banner lists what was skipped; the
      character looks right.

**Print** (⌘P and File → Export as PDF…)
- [ ] Nothing is cut off; notes start on a new page; headings aren't left
      alone at the bottom of a page. Try Letter and A4 (File → Page Setup).

**Windows**
- [ ] Make a sheet as narrow as it goes: rows of boxes wrap, nothing is
      clipped, and there's no sideways scrolling.
- [ ] Window → Tile Character Sheets with 2, 3 and 4 sheets open.
- [ ] Window → Merge Sheets into Tabs; then turn on Open Sheets in Tabs and
      open another character: it opens as a tab.

**Party** (File → Open Party Folder…, ⇧⌘O)
- [ ] Choose a folder of characters: everyone is listed, by name, with the
      same HP, AC, attack and saves as their sheets. Non-character files are
      left out.
- [ ] Open a character from the party (double-click), take damage, save:
      the party row updates. Add, rename or delete a file in Finder: the
      list follows.
- [ ] Quit and relaunch: the party window comes back with the same folder.

**Files**
- [ ] Save, close, reopen: everything is as you left it.
- [ ] Edit as Text: change a value in the header, switch back; the sheet
      shows it. Your notes and any unknown fields are untouched.
- [ ] Open the saved file in another text editor: it's readable and tidy.

**Undo, autosave and versions**
- [ ] Type a new name, press Tab, then ⌘Z: the whole name goes back in one
      step, not one letter at a time. ⇧⌘Z puts it back. Same for Class, an
      equipment item, and a number box.
- [ ] Type in Notes, then ⌘Z while still in Notes: typing is undone a word
      or so at a time.
- [ ] Edit as Text, type something, Cancel, then ⌘Z a few times: no crash,
      and nothing from the cancelled typing comes back. Repeat with Done:
      one ⌘Z undoes the whole text edit. (Undo crashed here on 17 Oct 2026.)
- [ ] Type in a box, then click Edit as Text without pressing Return: the
      text shows the new value.
- [ ] Make a change and wait: the title bar shows "Edited", then goes
      quiet once it autosaves. Quit and relaunch: the change is there.
- [ ] Change a few things over a few minutes, then File → Revert To →
      Browse All Versions…: earlier versions are listed, and restoring one
      brings its values back on the sheet.
- [ ] Open a character, change its file in another text editor and save
      there: the sheet updates (or asks, if it has unsaved changes).
- [ ] Untitled sheets (New Character, Import): quit without saving and
      relaunch; they come back.

**Whatever's new in this build**: go through `docs/WHAT-TO-TEST.txt`.

## Each release

1. Write `docs/WHAT-TO-TEST.txt` for testers: what's new and where to look.
   Plain text, under 4,000 characters (TestFlight's limit).
2. Run `scripts/testflight.sh`. It prints the notes at the end and copies
   them to the clipboard.
3. When the build has processed, run the smoke test above on it.
4. Add the build to the external group and paste the notes into
   **What to Test**.
