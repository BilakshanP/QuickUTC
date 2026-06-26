# QuickUTC

A lightweight macOS menu bar app that displays the current time in any timezone.

## Features

- **Menu bar clock** — always visible with customizable label format
- **Multiple timezones** — track as many as you need
- **City search** — find timezones by city name, country, or abbreviation (e.g. "Mumbai", "NYC", "JST")
- **Label styles** — choose between UTC offset, city name, abbreviation, or all combined
- **Launch at login** — starts automatically with your Mac
- **Zero dependencies** — pure SwiftUI + system frameworks

## Installation

1. Open `QuickUTC.xcodeproj` in Xcode
2. Build (⌘B)
3. Product → Show Build Folder in Finder
4. Drag `QuickUTC.app` to `/Applications`
5. Launch from Spotlight (⌘Space → "QuickUTC")

The app registers itself as a Login Item on first launch.

## Requirements

- macOS 13.0+
- Xcode 15+

## License

MIT
