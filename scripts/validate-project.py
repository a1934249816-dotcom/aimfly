"""Portable structural checks. Native SwiftUI compilation still requires Xcode."""

from pathlib import Path
import json
import plistlib
import re
import xml.etree.ElementTree as ET


root = Path(__file__).resolve().parent.parent
project = root / "CallJournal.xcodeproj"
pbx = (project / "project.pbxproj").read_text(encoding="utf-8")
definitions = re.findall(r"^\s*([A-F0-9]{24})(?:\s*/\*.*?\*/)?\s*=\s*\{", pbx, re.MULTILINE)
assert len(definitions) == len(set(definitions)), "Duplicate project object identifiers"
references = set(re.findall(r"\b[A-F0-9]{24}\b", pbx))
assert references == set(definitions), f"Unresolved project objects: {references - set(definitions)}"
assert "PBXFileSystemSynchronizedRootGroup" in pbx
assert "fileSystemSynchronizedGroups" in pbx
for path in [root / "CallJournal", root / "Sources/CallJournalCore"]:
    assert path.is_dir(), f"Source group is missing: {path}"
    assert any(path.glob("*.swift")), f"Source group has no Swift files: {path}"
assert pbx.count("IPHONEOS_DEPLOYMENT_TARGET = 18.0;") == 4
assert pbx.count("TARGETED_DEVICE_FAMILY = 1;") == 2
assert pbx.count("SWIFT_VERSION = 5.0;") == 2
assert pbx.count("INFOPLIST_FILE = CallJournal.xcodeproj/Info.plist;") == 2
assert pbx.count("PRODUCT_BUNDLE_IDENTIFIER = com.personal.calljournal;") == 2

with (project / "Info.plist").open("rb") as file:
    info = plistlib.load(file)
assert info["CFBundleDisplayName"] == "电话簿"
assert info["UISupportedInterfaceOrientations"] == ["UIInterfaceOrientationPortrait"]
assert info["UIApplicationSceneManifest"]["UIApplicationSupportsMultipleScenes"] is False
assert isinstance(info["UIApplicationSceneManifest"]["UISceneConfigurations"], dict)
assert not any(key.endswith("UsageDescription") for key in info), "Unexpected system permission declaration"
assert "NSAppTransportSecurity" not in info
assert "UIBackgroundModes" not in info
assert "CFBundleURLTypes" not in info

scheme = ET.parse(project / "xcshareddata/xcschemes/CallJournal.xcscheme").getroot()
for item in scheme.iter("BuildableReference"):
    assert item.attrib["BlueprintIdentifier"] == "C50000000000000000000001"
    assert item.attrib["ReferencedContainer"] == "container:CallJournal.xcodeproj"

assets = root / "CallJournal/Assets.xcassets"
icon_contents = assets / "AppIcon.appiconset/Contents.json"
assert icon_contents.is_file(), "App icon catalog is missing"
icon = json.loads(icon_contents.read_text(encoding="utf-8"))
assert icon.get("images"), "App icon catalog has no entries"
for image in icon["images"]:
    if image.get("filename"):
        assert (icon_contents.parent / image["filename"]).is_file(), "Referenced app icon image is missing"

print("Project references, iPhone settings, Info.plist, shared scheme and icon catalog: OK")
print("Native build not performed by this script; use Xcode 26 or the manual GitHub Actions workflow.")
