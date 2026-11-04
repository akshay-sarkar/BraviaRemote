# Changelog

All notable changes to Bravia Remote are listed here. Versions follow [Semantic Versioning](https://semver.org).

## [1.1.0] — 2026-11-04

### Added
- **Multiple TVs.** Pair as many BRAVIAs as you like and switch between them by tapping the TV name at the top of the remote. Rename or remove TVs in Settings (swipe left on a TV).
- **Input picker.** The Input key now opens a list of HDMI and other inputs, with the names you set on the TV. The one on screen is ticked. You can still open the TV's own input menu or jump to live TV.
- **iPhone volume buttons control the TV** while the remote is open. You can turn this off in Settings.
- **Layouts sized for each iPhone.** Separate key, D‑pad and spacing sizes for the SE / mini, standard and Plus / Pro Max screens. Short screens shrink the D‑pad before anything else is scaled.
- **Dynamic Type and Bold Text.** Key labels and glyphs follow the system text size (capped so the remote still fits). Bold Text makes the glyphs heavier.
- App version shown in Settings.

### Changed
- Credentials are now stored per TV in the Keychain. Pairings from v1.0 are migrated automatically.
- "Pairing expired" now reopens pairing with that TV's IP already filled in, instead of dropping back to the empty setup screen.

## [1.0.0] — 2026-11-03

### Added
- First release: SwiftUI remote with PIN / Pre‑Shared Key pairing, Bonjour discovery, the full set of keys from the physical remote, an app launcher, voice & type, a number pad, and four poster themes.
