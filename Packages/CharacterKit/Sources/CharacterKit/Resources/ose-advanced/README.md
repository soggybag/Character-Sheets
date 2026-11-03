# Advanced Fantasy rules data

**Not Open Game Content.** The Advanced Fantasy races and classes aren't in
the OSE SRD. Necrotic Gnome gave permission (email, 3 Nov 2026) to include
their names, advancement tables and short facts per race and class, on
condition the app's legal text says "Permission to include details of
non-SRD races and classes granted by Necrotic Gnome." (`Legal.nonSRD` in
`App/Help/Legal.swift`). That permission is for this app only: the files in
this folder can't be reused under the OGL. Transcribe from the books by
hand, numbers and short summaries in our own words only. Never copy the
PDFs or their text here.

The abilities and equipment tables are shared with Classic Fantasy (they're
in `../ose`, named in `ruleset.json`'s `files`). The conventions in
`../ose/README.md` apply here too.

| File | Contents |
|---|---|
| `ruleset.json` | As Classic Fantasy's, with `variant: advanced`, plus `files.races` |
| `classes.json` | Every Advanced Fantasy class: the human classes and the race-classes (Drow, Gnome, …) for the race-as-class option. Same format as `classes-classic.json` |
| `races.json` | Races for the separate race and class option |

To check against the books before filling in: the alignments, languages,
saves and creation rules in `ruleset.json` are copied from Classic Fantasy.

## Classes

As `../ose/classes-classic.json`. `plural` is optional, for names where
adding "s" is wrong (`"plural": "Half-Elves"`). `race` is the race in the
race-as-class option (`Human` for the human classes).

## Races

The Dwarf in `races.json` shows every field. The fields:

- **`requirements`** and **`maximums`** are the lowest and highest scores
  the race allows, after `abilityModifiers`. `{}` means none.
- **`abilityModifiers`** are added to the rolled scores.
- **`exploration`** replaces the class's value when it's better. Keys as
  for classes.
- **`weapons`** (optional) limits weapons on top of the class's rule.
- **`classes`** maps each class id the race may take to its highest level.
  A class that isn't listed isn't allowed. Referee's-option notes ("may
  only be NPCs") go in a feature.
- **`plural`** is optional, as for classes.
