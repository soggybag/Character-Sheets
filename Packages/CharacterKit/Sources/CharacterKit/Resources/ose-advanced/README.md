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

```json
{
  "id": "dwarf",
  "name": "Dwarf",
  "plural": "Dwarves",
  "requirements": { "con": 9 },
  "maximums": { "cha": 17 },
  "abilityModifiers": { "con": 1, "cha": -1 },
  "languages": ["Alignment", "Common", "Dwarvish"],
  "infravision": 60,
  "exploration": { "listen": 2 },
  "features": [
    { "id": "detect-construction-tricks", "name": "Detect construction tricks", "summary": "…" }
  ],
  "classes": { "cleric": 10, "fighter": 10, "thief": 9 }
}
```

(The numbers above show the shape only.)

- **`requirements`** and **`maximums`** are the lowest and highest scores
  the race allows, after `abilityModifiers`.
- **`abilityModifiers`** are added to the rolled scores.
- **`exploration`** replaces the class's value when it's better.
- **`classes`** maps each class id the race may take to its highest level.
  A class that isn't listed isn't allowed.
- **`plural`** is optional, as for classes.
