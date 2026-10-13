#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
mkdir -p qa-output
xcrun simctl list runtimes --json > qa-output/runtimes.json
xcrun simctl list devicetypes --json > qa-output/devicetypes.json
read -r runtime device_type < <(python3 - <<'PY'
import json
from pathlib import Path
runtimes = [v for v in json.loads(Path('qa-output/runtimes.json').read_text())['runtimes']
            if v.get('isAvailable') and v.get('name', '').startswith('iOS 26')]
if not runtimes:
    raise SystemExit('No iOS 26 simulator runtime available')
runtime = max(runtimes, key=lambda v: tuple(map(int, v['version'].split('.'))))
types = json.loads(Path('qa-output/devicetypes.json').read_text())['devicetypes']
device = next((v for v in types if v['name'] == 'iPhone 17 Pro Max'), None)
if device is None:
    device = next(v for v in types if v['name'] == 'iPhone 16 Pro Max')
print(runtime['identifier'], device['identifier'])
PY
)
device_id="$(xcrun simctl create 'CallJournal UI Check' "$device_type" "$runtime")"
xcrun simctl boot "$device_id"
xcrun simctl bootstatus "$device_id" -b
xcodebuild -project CallJournal.xcodeproj -scheme CallJournal -configuration Debug \
    -sdk iphonesimulator -destination "id=$device_id" -derivedDataPath qa-output/DerivedData \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build > qa-output/simulator-build.log 2>&1
xcrun simctl install "$device_id" qa-output/DerivedData/Build/Products/Debug-iphonesimulator/CallJournal.app
data_container="$(xcrun simctl get_app_container "$device_id" com.personal.calljournal data)"
mkdir -p "$data_container/Library/Application Support/CallJournal"
cp 'Examples/示例资料库.json' "$data_container/Library/Application Support/CallJournal/phone-journal.json"
xcrun simctl ui "$device_id" appearance light
xcrun simctl status_bar "$device_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcrun simctl launch "$device_id" com.personal.calljournal
sleep 4
xcrun simctl io "$device_id" screenshot qa-output/iPhone-Recents.png
printf 'Simulator launch and screenshot completed\n'
