# Changelog

All notable changes to Bravia Remote are listed here. Versions follow [Semantic Versioning](https://semver.org).
Each release on GitHub uses its section from this file as its release notes.

## [1.1.0] — 2026-11-04

### ✨ New features
- **Multiple TVs.** Pair as many BRAVIAs as you like and switch between them by tapping the TV name at the top of the remote. Rename or remove TVs in Settings (swipe left on a TV).
- **Input picker.** The Input key now opens a list of HDMI and other inputs, with the names you set on the TV. The one on screen is ticked. You can still open the TV's own input menu or jump to live TV.
- **iPhone volume buttons control the TV** while the remote is open. You can turn this off in Settings.
- **Layouts sized for each iPhone.** Separate key, D‑pad and spacing sizes for the SE / mini, standard and Plus / Pro Max screens.
- **Dynamic Type and Bold Text.** Key labels and glyphs follow the system text size (capped so the remote still fits). Bold Text makes the glyphs heavier.
- App version shown in Settings.

### 🐞 Bug fixes
- **PIN pairing:** the TV no longer shows "Registration cancelled" a second after the PIN appears.
- **PIN pairing:** tapping Connect twice no longer closes the PIN pop‑up on the TV.
- "Pairing expired" now reopens pairing with that TV's IP already filled in, instead of dropping back to the empty setup screen.

### 🔧 Changes
- Credentials are now stored per TV in the Keychain. Pairings from v1.0 are moved over automatically, so you don't need to pair again.

## [1.0.0] — 2026-11-03

### ✨ First release
- **Native SwiftUI remote** for Sony BRAVIA Google TVs (2021 VH21 platform and newer), working over Wi‑Fi.
- **Finds your TV automatically** on the network, or you can enter its IP address.
- **Two ways to pair:** a 4‑digit PIN or the TV's Pre‑Shared Key.
- **Every key from the physical remote:** Power, TV, Input, Settings, 123, D‑pad, volume, channel, Back, Home, Voice, Mute, Play, Pause and Guide. Arrows, volume and channel repeat while held.
- **Four poster themes:** Aurora Graphite, Midnight Signal, Crimson Night and Banana Lab, switchable from **⋯ → Theme**.
- **App launcher** listing everything installed on the TV, plus **Voice & Type** for the TV's search box and a number pad with the color keys.
