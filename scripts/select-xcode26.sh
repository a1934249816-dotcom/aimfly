#!/bin/bash
set -euo pipefail

# Select a stable 26.x installation even if the runner's default moves to 27.
selected="$(python3 - <<'PY'
import glob
import pathlib
import plistlib

candidates = []
for path in glob.glob('/Applications/Xcode*.app'):
    info_path = pathlib.Path(path) / 'Contents/Info.plist'
    try:
        with info_path.open('rb') as file:
            version = str(plistlib.load(file)['CFBundleShortVersionString'])
        pieces = version.split('.')
        if pieces[0] == '26' and all(piece.isdigit() for piece in pieces):
            if 'beta' not in path.lower() and 'preview' not in path.lower():
                candidates.append((tuple(map(int, pieces)), path))
    except (OSError, KeyError, ValueError, plistlib.InvalidFileException):
        continue
if not candidates:
    raise SystemExit('No stable Xcode 26 found on this runner. Check the runner image and choose a supported Xcode 26 installation.')
print(max(candidates)[1])
PY
)"
sudo xcode-select --switch "$selected/Contents/Developer"
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
