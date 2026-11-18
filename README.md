# Verse

A native iPhone music streaming app with a glassy look where the cover colours flow through the
screen, and karaoke-style lyrics that light up word by word.

Music comes from two legal catalogs, merged into one experience:

- **Audius** – full songs from independent artists, free, no account needed.
- **Apple Music catalog** – popular songs as 30-second previews (courtesy of Apple). Full Apple Music
  songs need MusicKit, which needs a paid Apple Developer account and an Apple Music subscription.

Swift 6, SwiftUI, SwiftData, AVFoundation. No third-party dependencies.

## Audius API key

1. Create a free key at https://api.audius.co/plans.
2. Local builds: copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (git-ignored) and paste
   the key after `AUDIUS_API_KEY =`.
3. GitHub builds: store it as the `AUDIUS_API_KEY` Actions secret (`gh secret set AUDIUS_API_KEY`).

The key is a public client key and ends up inside the app. Never put an Audius API secret or bearer
token in the app.

## Build

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

### In the cloud (no Mac needed)

Every push to `main` runs [GitHub Actions](.github/workflows/build.yml) on a macOS runner:

1. Builds the app and runs the tests in the iOS simulator (warnings are errors).
2. Takes screenshots of the main screens on bundled sample data (**Screenshots** artifact).
3. Builds an unsigned `Verse.ipa` and attaches it to the run as the **Verse-ipa** artifact (kept 14 days).

### On a Mac

```sh
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # then add your key
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

No analytics, tracking or accounts of our own. Network requests go only to Audius, Apple (catalog and
previews) and LRCLIB (lyrics). Music from Audius; previews provided courtesy of Apple Music.
