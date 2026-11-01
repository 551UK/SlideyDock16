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
# Visible icons is independent of the 100-icon dock capacity.
# Patch every geometry and paging site in the pinned upstream source.
source = (root / "Tweak.xm").read_text(encoding="utf-8")
insertion_point = "static void IF16WriteDiagnostics("
assert source.count(insertion_point) == 1
visible_icons_function = """static NSUInteger IF16IconsPerPage(void) {
    static NSUInteger visibleIcons = IF16DefaultIconsPerPage;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        id value = IF16PreferenceValue(@"VisibleIconsPerPage");
        visibleIcons = ([value respondsToSelector:@selector(integerValue)] &&
                        [value integerValue] == 5) ? 5 : 4;
    });
    return visibleIcons;
}

"""
source = source.replace(insertion_point, visible_icons_function + insertion_point, 1)
before_diagnostics, after_diagnostics = source.split(insertion_point, 1)
assert after_diagnostics.count("IF16DefaultIconsPerPage") == 6, "Upstream icon layout has changed"
after_diagnostics = after_diagnostics.replace("IF16DefaultIconsPerPage", "IF16IconsPerPage()")
source = before_diagnostics + insertion_point + after_diagnostics
source = source.replace(
    "four fixed-width slots per scroll page",
    "four or five fixed-width slots per scroll page"
)
source = source.replace(
    'report[@"PagingEnabled"] = @(IF16PagingEnabled());',
    'report[@"PagingEnabled"] = @(IF16PagingEnabled());\n    report[@"VisibleIconsPerPage"] = @(IF16IconsPerPage());'
)
source = source.replace('report[@"Build"] = @"1.0.0-1";', 'report[@"Build"] = @"1.1.0-1";')
assert source.count("IF16DefaultIconsPerPage") == 2, "Default icon count must remain the fallback"
assert source.count("IF16IconsPerPage()") == 7, "All six layout sites and diagnostics must use the setting"
(root / "Tweak.xm").write_text(source, encoding="utf-8")

change("Tweak.xm", [(OLD_ID, NEW_ID)])

change("control", [
    ("Version: 1.0.0-1", "Version: 1.1.0-1"),
    ("Package: " + OLD_ID, "Package: " + NEW_ID),
    ("Name: Infinidock 16 Revival", "Name: SlideyDock16"),
    ("Description: Scroll beyond four Dock icons on iOS 15/16. An unofficial rootless revival of chpwn's classic Infinidock with paging and continuous scrolling modes.",
     "Description: Sliding native Dock with up to 100 apps; selectable four or five visible icons, paging or continuous scrolling on iOS 15/16."),
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
<dict><key>cell</key><string>PSGroupCell</string><key>label</key><string>SlideyDock16</string><key>footerText</key><string>Swipe left or right across the Dock. Up to 100 apps, with 4 or 5 icons visible at once.</string></dict>
<dict><key>cell</key><string>PSSwitchCell</string><key>defaults</key><string>uk.551.slideydock16</string><key>key</key><string>Enabled</string><key>default</key><true/><key>label</key><string>Enable SlideyDock16</string></dict>
<dict><key>cell</key><string>PSGroupCell</string><key>label</key><string>Visible Dock Icons</string><key>footerText</key><string>Choose 4 or 5 icons across the Dock at once. You can still add up to 100 apps and swipe to see more.</string></dict>
<dict><key>cell</key><string>PSSegmentCell</string><key>defaults</key><string>uk.551.slideydock16</string><key>key</key><string>VisibleIconsPerPage</string><key>default</key><integer>4</integer><key>validValues</key><array><integer>4</integer><integer>5</integer></array><key>validTitles</key><array><string>4 Icons</string><string>5 Icons</string></array></dict>
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
    assert len(plistlib.load(f)["items"]) == 10
print("SlideyDock16 settings (4/5 visible icons), metadata, and 100-icon capacity verified")
