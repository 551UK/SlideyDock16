#!/usr/bin/env python3
"""Adapt the pinned BSD-licensed Infinidock 16 source for SlideyDock16."""
from pathlib import Path
import plistlib
import sys

if len(sys.argv) != 2:
    raise SystemExit("Usage: python3 scripts/prepare.py SOURCE_DIR")
root = Path(sys.argv[1]).resolve()
if not (root / "Tweak.xm").is_file() or not (root / "LICENSE").is_file():
    raise SystemExit("Not a complete Infinidock16 source tree")

OLD_ID = "dev.infinidock16.revival"
NEW_ID = "uk.551.slideydock16"

def change(relative, replacements):
    path = root / relative
    value = path.read_text(encoding="utf-8")
    for old, new in replacements:
        if old not in value:
            raise RuntimeError(f"Expected value missing from {relative}: {old!r}")
        value = value.replace(old, new)
    path.write_text(value, encoding="utf-8")

core = (root / "Tweak.xm").read_text(encoding="utf-8")
assert "static const NSUInteger IF16MaximumDockIcons = 100;" in core, "Upstream icon limit has changed"
assert "static const NSUInteger IF16DefaultIconsPerPage = 4;" in core, "Upstream visible-icon count has changed"
change("Tweak.xm", [(OLD_ID, NEW_ID)])

change("control", [
    ("Package: " + OLD_ID, "Package: " + NEW_ID),
    ("Name: Infinidock 16 Revival", "Name: SlideyDock16"),
    ("Description: Scroll beyond four Dock icons on iOS 15/16. An unofficial rootless revival of chpwn's classic Infinidock with paging and continuous scrolling modes.",
     "Description: Sliding native Dock with up to 100 apps; four visible icons, page snapping or continuous scrolling on iOS 15/16."),
    ("Maintainer: JaySuen", "Maintainer: 551UK"),
    ("Author: chpwn, subdiox, JaySuen", "Author: chpwn, subdiox, JaySuen, 551UK"),
    ("Conflicts: com.subdiox.infinidock", "Conflicts: com.subdiox.infinidock, " + OLD_ID),
])
control = root / "control"
data = control.read_text(encoding="utf-8")
data = "\n".join(line for line in data.splitlines() if not line.startswith(("Icon: ", "SileoDepiction: ", "Homepage: ")))
data += "\nHomepage: https://github.com/551UK/SlideyDock16\n"
control.write_text(data, encoding="utf-8")

# Preserve the upstream BSD license and CREDITS in the installed package.
old_docs = root / "layout/usr/share/doc" / OLD_ID
new_docs = root / "layout/usr/share/doc" / NEW_ID
if not old_docs.is_dir():
    raise RuntimeError("Original attribution and license are missing")
old_docs.rename(new_docs)

change("preferences/layout/Library/PreferenceLoader/Preferences/Infinidock16.plist", [
    ("Infinidock 16 修复版", "SlideyDock16")
])

plist = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>items</key><array>
<dict><key>cell</key><string>PSGroupCell</string><key>label</key><string>SlideyDock16</string><key>footerText</key><string>Swipe left or right across the Dock. Up to 100 apps, with four icons visible at once.</string></dict>
<dict><key>cell</key><string>PSSwitchCell</string><key>defaults</key><string>uk.551.slideydock16</string><key>key</key><string>Enabled</string><key>default</key><true/><key>label</key><string>Enable SlideyDock16</string></dict>
<dict><key>cell</key><string>PSGroupCell</string><key>label</key><string>Scrolling Mode</string><key>footerText</key><string>Pages snap to groups of icons. Continuous lets scrolling stop between icons.</string></dict>
<dict><key>cell</key><string>PSSegmentCell</string><key>defaults</key><string>uk.551.slideydock16</string><key>key</key><string>PagingEnabled</string><key>default</key><true/><key>validValues</key><array><true/><false/></array><key>validTitles</key><array><string>Pages</string><string>Continuous</string></array></dict>
<dict><key>cell</key><string>PSGroupCell</string><key>footerText</key><string>Settings take effect after a respring. Disable any other tweak that changes the Dock layout.</string></dict>
<dict><key>cell</key><string>PSButtonCell</string><key>action</key><string>respring:</string><key>label</key><string>Apply and Respring</string></dict>
<dict><key>cell</key><string>PSGroupCell</string><key>label</key><string>Credits</string><key>footerText</key><string>Based on Infinidock 16 Revival (JaySuen), built on the work of chpwn and subdiox. BSD-2-Clause. Unofficial customization by 551UK.</string></dict>
<dict><key>cell</key><string>PSButtonCell</string><key>action</key><string>openRevivalSource:</string><key>label</key><string>View Original Source and Credits</string></dict>
</array></dict></plist>
"""
prefs = root / "preferences/Resources/Root.plist"
prefs.write_text(plist, encoding="utf-8")
with prefs.open("rb") as f:
    assert len(plistlib.load(f)["items"]) == 8
print("SlideyDock16 English settings, metadata, and 100-icon limit verified")
