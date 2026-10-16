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
| `rules/ose/` | OSE Classic rules data (JSON) |
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

Signing is set to "Sign to Run Locally" with a placeholder bundle id
(`com.example.CharacterSheets`). Set your team and a real bundle id before
distributing.
