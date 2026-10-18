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
      and the acknowledgments.

**Sample character** (Help → Open Sample Character, then save a copy)
- [ ] The sheet looks right: no clipped text, overlapping boxes, or empty
      sections that should have values.
- [ ] Type a different save or AC: the orange override dot appears.
      Clicking the dot → Use Rules Value removes it.
- [ ] Clear a box: the grey rules value comes back.
- [ ] Tab through every box without typing anything, then close. The app
      doesn't ask to save (nothing changed).
- [ ] Rules menu: switch ascending AC on and off; the combat boxes follow.

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
