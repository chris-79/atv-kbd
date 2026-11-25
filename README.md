# ATV KBD

A macOS window for controlling an Apple TV from the keyboard. It speaks the same local-network protocol as the Siri Remote.

This is a personal fork of [Itsytv](https://github.com/nickustinov/itsytv-macos) by Nick Ustinov. The protocol lives in [itsytv-core](https://github.com/nickustinov/itsytv-core). MIT licensed.

## Controls

With the window focused:

| Keys | Action |
| --- | --- |
| Arrow keys | Move |
| Return | Select |
| Space | Play / Pause |
| Escape | Back |
| H | Home |
| H H | App Switcher |
| ⌘T | Type into Apple TV text fields |

In text mode, letters (including H) are typed. Arrows, Return, and Escape still navigate. ⌘T switches back.

**SWITCH** picks a different Apple TV. **CONTROLS** opens the list above; the window grows downward and the name and image stay put.

## Pairing

The Apple TV shows a four-digit PIN. Type it into the window. Credentials stay in the macOS Keychain.

If no PIN appears:

1. On the Apple TV, open **Settings → AirPlay and Apple Home**.
2. Set **Allow Access** to **Anyone on the Same Network**.
3. Set **Require Password** to **Off** until pairing finishes. It can go back on after that.
4. Open **Settings → General → Restrictions** and set **AirPlay Settings** and **Remote App Pairing** to **Allow**.

Apple TV 4th generation or later, tvOS 15+, on the same network. If AirPlay access is **Only People Sharing This Home**, the connection will not stay up. Set it to **Anyone on the Same Network**.

## AppleScript

```bash
osascript -e 'tell application "ATV KBD" to pause'
osascript -e 'tell application "ATV KBD" to play'
```

Both do nothing when there is nothing to pause or play.

## Requirements

- macOS 14 or later
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

Clone this repo and `itsytv-core` next to each other. The Xcode project uses `../itsytv-core` as a local package.

```bash
git clone https://github.com/chris-79/atv-kbd.git
git clone https://github.com/nickustinov/itsytv-core.git
cd atv-kbd
brew install xcodegen
xcodegen generate
open atv-kbd.xcodeproj
```

Run the **atv-kbd** scheme. After changing `project.yml`, run `xcodegen generate` again.

## License

MIT License (c) 2026 Nick Ustinov. See [LICENSE](LICENSE).

Protocol work informed by [pyatv](https://github.com/postlund/pyatv).
