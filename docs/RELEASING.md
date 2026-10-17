# Releasing to TestFlight

## One-time setup

1. **Xcode account.** Xcode → Settings → Accounts: signed in with the
   developer account (team `753UQ7TNXJ`).
2. **App record.** In [App Store Connect](https://appstoreconnect.apple.com)
   → Apps → **+** → New App:
   - Platform: macOS
   - Name: must be unique on the App Store, and must not use "OSE",
     "Old-School Essentials" or "D&D". "Character Sheets" is probably taken.
     The name can change before 1.0.
   - Bundle ID: `com.mitchellhudson.CharacterSheets`. If it isn't in the
     list, run `scripts/testflight.sh` once (Xcode registers it), or add it
     under Certificates, Identifiers & Profiles.
   - SKU: anything, e.g. `charactersheets`.
3. **Test information.** App Store Connect → TestFlight → Test Information:
   a short description, what to test, and the feedback email.

## Each build

```sh
scripts/testflight.sh
```

This runs the CharacterKit tests, archives a universal Release build with a
new build number (UTC date and time, e.g. `202610161530`), and uploads it.
`--no-upload` archives and exports without uploading.

Before uploading, update `docs/WHAT-TO-TEST.txt`; the script prints it and
copies it to the clipboard for TestFlight's **What to Test**. Run the smoke
test in `docs/TESTING.md` on the processed build before external testers
get it.

The marketing version is `MARKETING_VERSION` in the project (currently 0.1).
Export compliance is answered in `Config/Info.plist`
(`ITSAppUsesNonExemptEncryption = NO`: the app uses no encryption).

## Inviting testers

- **Internal testers** (people added to your App Store Connect team, up to
  100) can install a build as soon as it finishes processing.
- **External testers** (anyone, by email or public link, up to 10,000) need
  the first build of each version to pass Beta App Review, usually within a
  day. Create a group under TestFlight → External Testing, add the build,
  then share the public link.

Testers install **TestFlight** from the Mac App Store, open the invite, and
get updates automatically. Builds expire after 90 days.

## Feedback

Help → Send Feedback… opens an email to the address in
`App/Help/HelpViews.swift` with the app and macOS versions filled in.
TestFlight's own feedback (screenshots and comments) also appears in App
Store Connect.
