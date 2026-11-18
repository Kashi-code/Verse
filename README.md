# Verse

A native iPhone music player built around lyrics that follow the song, with a fullscreen player
coloured by the album cover. Plays your own audio files; Apple Music support is optional.

Swift 6, SwiftUI, SwiftData, AVFoundation. No third-party dependencies.

## Build

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

### In the cloud (no Mac needed)

Every push to `main` runs [GitHub Actions](.github/workflows/build.yml) on a macOS runner:

1. Builds the app and runs the tests in the iOS simulator (warnings are errors).
2. Builds an unsigned `Verse.ipa` and attaches it to the run as the **Verse-ipa** artifact (kept 14 days).

### On a Mac

```sh
brew install xcodegen
xcodegen generate
open Verse.xcodeproj
```

Requires Xcode 26 or later. The deployment target is iOS 26.0; it moves to iOS 27 once CI runners ship Xcode 27.

## Install on your iPhone from Windows (free Apple ID)

1. Open the latest successful run under **Actions** on GitHub and download the **Verse-ipa** artifact.
   Unzip it to get `Verse.ipa`.
2. Install [Sideloadly](https://sideloadly.io) and iTunes (from apple.com, not the Microsoft Store version).
3. Connect the iPhone with a cable, drag `Verse.ipa` into Sideloadly, enter your Apple ID and press **Start**.
4. On the iPhone: **Settings → General → VPN & Device Management**, trust your Apple ID.
5. Turn on **Developer Mode** if iOS asks (Settings → Privacy & Security → Developer Mode).

With a free Apple ID the app stops opening after 7 days; install it again to renew it.
Apple Music and the widget's shared data need a paid Apple Developer account.

## Install on your iPhone from a Mac

Generate the project, open it in Xcode, choose your team under **Signing & Capabilities**, select your
iPhone and press Run.

## Privacy

No analytics, tracking or accounts. The only network requests go to LRCLIB (lyrics) and, if you
connect it, Apple Music.
