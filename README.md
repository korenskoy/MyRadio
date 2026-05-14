# MyRadio

A native macOS internet radio client powered by the
[radio-browser.info](https://www.radio-browser.info/) community catalog.

Built with SwiftUI for macOS 26.4 (Tahoe) and later.

## Features

- Browse 40k+ stations from the radio-browser.info catalog
- Discover, Top Voted, Most Popular, Countries, and Map tabs
- Full-text search across stations
- Favorites and play history
- Add custom stations from a stream URL or import M3U/PLS playlists
- Mini-player mode
- Sleep timer with macOS notification on expiry
- Light / Dark / Auto theme that follows the system accent color
- Now Playing integration (media keys, Control Center)
- Built-in update check via the GitHub Releases atom feed

## Requirements

- macOS 26.4 (Tahoe) or later
- Apple silicon or Intel Mac

## Install

1. Download the latest `MyRadio-X.Y.dmg` from the
   [Releases page](https://github.com/korenskoy/MyRadio/releases).
2. Open the DMG and drag `MyRadio.app` to `/Applications`.
3. Eject the DMG.

### Gatekeeper: first launch

MyRadio is not currently signed with an Apple Developer ID and is not
notarized. macOS Gatekeeper will block the first launch with a message like
*"MyRadio.app cannot be opened because the developer cannot be verified"* or
*"MyRadio.app is damaged and can't be opened."*

This is expected. Pick **one** of the workarounds below.

**Option A — System Settings (recommended):**

1. Try to open `MyRadio.app` once. macOS will refuse and show a dialog.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the *Security* section. You will see
   *"MyRadio.app was blocked to protect your Mac."*
4. Click **Open Anyway**, then confirm in the next dialog.

**Option B — Terminal (one-liner):**

```bash
sudo xattr -cr /Applications/MyRadio.app
```

This clears all extended attributes — including the quarantine flag that
triggers Gatekeeper. Run it once after installing; subsequent launches work
normally.

If you'd rather build from source, see below — locally built binaries don't
get the quarantine attribute and launch without prompts.

## Build from source

Requires Xcode 16 or later (the project uses
`PBXFileSystemSynchronizedRootGroup`, an Xcode 16+ feature).

```bash
# Debug build
xcodebuild -project MyRadio.xcodeproj -scheme MyRadio -configuration Debug build

# Build, package, and bump build number into dist/MyRadio-X.Y.dmg
./scripts/build-dmg.sh
```

The DMG is unsigned and unnotarized — fine for personal use, but anyone
downloading it will need the Gatekeeper workaround above.

## Dependencies

- [RadioBrowserKit](https://github.com/PankajGaikar/RadioBrowserKit) —
  Swift client for the radio-browser.info API. Pinned via Swift Package
  Manager.

## License

[MIT](LICENSE) © 2026 Anton Korenskoy

Powered by the [radio-browser.info](https://www.radio-browser.info/)
community API. MyRadio is not affiliated with any broadcaster.
