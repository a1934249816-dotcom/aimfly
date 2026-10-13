#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if ! xcodebuild -version | head -n 1 | grep -Eq '^Xcode 26([.]|$)'; then
    echo 'Select Xcode 26 before building (bash scripts/select-xcode26.sh).' >&2
    exit 1
fi

python3 scripts/validate-project.py
xcodebuild \
    -project CallJournal.xcodeproj \
    -scheme CallJournal \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build/DerivedData \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    build

app_path="$project_root/build/DerivedData/Build/Products/Release-iphoneos/CallJournal.app"
if [[ ! -d "$app_path" || ! -f "$app_path/CallJournal" ]]; then
    echo 'Expected compiled iPhone app was not produced.' >&2
    exit 1
fi

# tempfile prevents leftover payload files from entering a rebuilt IPA.
python3 - "$app_path" "$project_root/build/CallJournal-unsigned.ipa" <<'PY'
import pathlib
import shutil
import subprocess
import sys
import tempfile

app_path, ipa_path = map(pathlib.Path, sys.argv[1:])
with tempfile.TemporaryDirectory(prefix='calljournal-payload-') as staging:
    payload = pathlib.Path(staging) / 'Payload'
    payload.mkdir()
    shutil.copytree(app_path, payload / 'CallJournal.app')
    temporary_ipa = pathlib.Path(staging) / 'CallJournal-unsigned.ipa'
    subprocess.run(['/usr/bin/ditto', '-c', '-k', '--keepParent', str(payload), str(temporary_ipa)], check=True)
    ipa_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(temporary_ipa, ipa_path)
print(f'Unsigned IPA: {ipa_path}')
print('Re-sign with your own Apple Account before installing on an iPhone.')
PY
