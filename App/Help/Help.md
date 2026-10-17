# Welcome to Character Sheets

Character Sheets keeps old-school characters in plain text files and fills in
the rules for you, without getting in your way.

## Getting started

- **File → New Character…** (⌘N) rolls up a 1st-level character: 3d6 in
  order, a class, hit points and gold. Roll in the app or type in your own
  dice. **File → New Blank Sheet** (⌥⌘N) starts an empty sheet instead.
- **File → Import PDF Character Sheet…** (⇧⌘I) turns a filled-in fillable PDF
  sheet into a character.
- **File → Open…** (⌘O) opens a character file. Any Markdown file with a
  character header works.
- **Help → Open Sample Character** shows a finished character to explore.

## How the sheet works

- Values the rules can work out (saves, THAC0 or attack bonus, AC, skills,
  spell slots) are filled in for you. Empty boxes show the rules value in
  grey; choose **Rules → Fill In Missing Values** to write them all in.
- Type any value you like. If it differs from the rules, a small orange dot
  marks it as your override (a magic item, a house rule). Click the dot for
  **Use Rules Value**. Overrides are never changed behind your back.
- **Rules Notes** at the top point out things worth knowing, like a class
  restriction or hit points still to roll. They're suggestions only.
- **Level Up…** shows every change, lets you roll or type the hit die, and
  keeps your overrides. If the character doesn't have the XP for the new
  level (the referee awarded it), it offers to set XP to match. If Max HP is
  empty, it asks for it first. **Level Down…**, in the arrow beside Level Up,
  handles a lost level (energy drain): the rules values go back, and you
  choose the hit points lost and whether XP drops.
- The **Rules** menu in the toolbar switches ascending AC, variable weapon
  damage and encumbrance for this character.
- **At the table:** type an amount in **Damage / Heal** and press Return to
  take damage, or use − and +. The − next to a quantity uses one torch or
  arrow.
- **Spells** are one list: the spell book, with how many copies of each are
  memorized today (− and +) and a **Cast** box for each copy. **Rest** clears
  the Cast boxes. A memorized spell that isn't in the book (a cleric's
  prayers) gets a row of its own.
- **File → Open Party Folder…** (⇧⌘O) shows every character in a folder at
  a glance: hit points, AC, attack, saves and XP. It updates as files are
  saved. Double-click a character to open the sheet.
- **File → Print** (⌘P) prints a one-page sheet followed by your notes.
  **File → Export as PDF…** saves the same thing as a PDF.

## Your files

Each character is a Markdown file: a header with the sheet, then your notes.
You can open it in any text editor, keep it in iCloud Drive or Dropbox, and
put it under version control.

```
---
formatVersion: 1
rules:
  system: ose
  variant: classic
name: Fingle
class: Elf
level: 1
abilityScores: { str: 10, int: 13, wis: 10, dex: 17, con: 15, cha: 10 }
---

# Notes

Above the golem's path, seek the door that is not.
```

- Click **Edit as Text** in the toolbar to edit the file directly.
- Fields the app doesn't know about are kept as they are, so you can add your
  own.
- Clearing a field removes it from the file. Put comments in the notes, not
  the header, because comments in the header aren't kept.

## Feedback

This is an early test version. If something is confusing, wrong or missing,
choose **Help → Send Feedback…**. Every report helps.
