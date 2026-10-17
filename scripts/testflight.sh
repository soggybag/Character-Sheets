#!/bin/bash
# Archives the app and uploads it to App Store Connect for TestFlight.
#
#   scripts/testflight.sh            # build number = UTC date and time
#   scripts/testflight.sh --no-upload  # archive and export only
#
# Needs: Xcode signed in to the developer account (Settings → Accounts), and
# an app record in App Store Connect for com.mitchellhudson.CharacterSheets.
set -euo pipefail
cd "$(dirname "$0")/.."

upload=true
[[ "${1:-}" == "--no-upload" ]] && upload=false

# Every upload needs a new, increasing build number.
build=$(date -u +%Y%m%d%H%M)
out="build/testflight/$build"
mkdir -p "$out"

echo "→ Running CharacterKit tests"
(cd Packages/CharacterKit && swift test --quiet)

echo "→ Archiving build $build"
xcodebuild -project "Character Sheets.xcodeproj" -scheme "Character Sheets" \
    -configuration Release -destination "generic/platform=macOS" \
    -archivePath "$out/Character Sheets.xcarchive" \
    -allowProvisioningUpdates \
    CURRENT_PROJECT_VERSION="$build" \
    archive | grep -E "error:|warning:|ARCHIVE" || true
[[ -d "$out/Character Sheets.xcarchive" ]] || { echo "Archive failed"; exit 1; }

options=scripts/ExportOptions-TestFlight.plist
if ! $upload; then
    options="$out/ExportOptions.plist"
    sed 's|<string>upload</string>|<string>export</string>|' scripts/ExportOptions-TestFlight.plist > "$options"
fi

echo "→ $($upload && echo Uploading || echo Exporting)"
xcodebuild -exportArchive \
    -archivePath "$out/Character Sheets.xcarchive" \
    -exportOptionsPlist "$options" \
    -exportPath "$out/export" \
    -allowProvisioningUpdates

if $upload; then
    echo "✓ Uploaded build $build. It appears in App Store Connect → TestFlight after processing (about 10–30 minutes)."
    notes=docs/WHAT-TO-TEST.txt
    if [[ -f "$notes" ]]; then
        pbcopy < "$notes"
        echo
        echo "What to Test (copied to the clipboard; see docs/TESTING.md):"
        echo
        cat "$notes"
    fi
else
    echo "✓ Exported to $out/export"
fi
