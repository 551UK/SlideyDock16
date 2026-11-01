# SlideyDock16

A horizontally scrolling iPhone dock for **iOS 16 rootless**, supporting **up to 100 app icons** with four icons visible at once.

- Native dock appearance and spacing
- Horizontal swiping, with paging or continuous scrolling
- Enable/disable switch and Apply & Respring under Settings → SlideyDock16
- Compatible target: rootless iOS 15–16 (Dopamine)

## Download

Get the `.deb` from [Releases](https://github.com/551UK/SlideyDock16/releases). Install it using Sileo or Zebra. Disable/uninstall Infinidock 16 Revival and any other Dock-layout tweaks first.

## Build

The [GitHub Actions workflow](.github/workflows/build-rootless.yml) builds an arm64/arm64e rootless `.deb` with Theos and publishes it to Releases. You can also run `bash build.sh` on a Mac with Theos and packaging tools installed.

The build pins the source to [Infinidock 16 Revival at ea8dd05](https://github.com/elevenY123/Infinidock16-test/commit/ea8dd05cd119b8a57ca35cd87c4161dad45db7a9), verifies its 100-app dock limit, and applies the SlideyDock16 name, package ID, and English settings before compiling. The original core was reported working on an iPhone 14 Pro with iOS 16.5; this customized build has not yet been independently device-tested.

## Credits

Original Infinidock by **chpwn**, original copyright **Xuzz Productions, LLC (2010–2014)**, public fork by **subdiox**, and iOS 16 Revival by **JaySuen**. SlideyDock16 is an independent packaging and settings customization by **551UK**. It preserves upstream BSD-style licensing and installed credits. It is not affiliated with the original developers.
