# Character Sheets

A small native Mac app for tabletop RPG characters, stored as Markdown files
with a YAML header. Starting with Old-School Essentials (Classic Fantasy).

- Plan and roadmap: [`docs/PLAN.md`](docs/PLAN.md)
- File format: [`docs/FILE-FORMAT.md`](docs/FILE-FORMAT.md)
- PDF import notes: [`docs/PDF-IMPORT.md`](docs/PDF-IMPORT.md)

## Layout

| Path | What |
|---|---|
| `App/` | The macOS app (SwiftUI, document-based). Files added here are picked up by Xcode automatically. |
| `Config/` | Info.plist (document types) and entitlements |
| `Packages/CharacterKit/` | Reading and writing character files. No UI; shared with a future iPad app. |
| `Packages/CharacterKit/Sources/CharacterKit/Resources/ose/` | OSE Classic rules data (JSON), bundled with the app |
| `schema/` | JSON Schema for the file header |
| `examples/` | Example characters. Also test fixtures: every file must round-trip byte for byte. |

## Build and test

Requires Xcode 16 or later. The app runs on macOS 15+.

```sh
# App
open "Character Sheets.xcodeproj"        # then Run (⌘R)

# CharacterKit tests (or choose the CharacterKit scheme in Xcode and press ⌘U)
cd Packages/CharacterKit && swift test
```

The bundle id is `com.mitchellhudson.CharacterSheets`. Signing is set to
"Sign to Run Locally"; set your development team before distributing.

Third-party notices (Yams, MIT; OSE SRD rules data, OGL 1.0a) appear in
the About window from `App/Credits.html`. The full OGL text ships in the
CharacterKit resource bundle.
