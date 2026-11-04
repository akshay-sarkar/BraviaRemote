# Bravia Remote (iOS)

A native SwiftUI remote for Sony BRAVIA TVs on the 2021 **VH21** Google TV platform (X80J/X85J/X90J/A80J and similar). It sends commands over Wi‑Fi using Sony's local REST API and IRCC, with PIN pairing.

## Features
- Finds the TV automatically with Bonjour (`_googlecast._tcp`). You can also type the IP address.
- Pairs with a 4‑digit PIN or the TV's Pre‑Shared Key (IP control). The auth cookie and PIN are kept in the Keychain, and the cookie renews itself when it expires (about every 14 days).
- **4 themes** with original poster backgrounds: Aurora Graphite, Midnight Signal, Crimson Night and Banana Lab. Switch themes from the **⋯ → Theme** menu or in Settings. Your choice is remembered.
- Main screen: Power · TV · Input · Settings · 123 · VOL± / D‑pad + OK / CH± · Back · Voice · Mute · Home · Play · Pause · Guide. The keys sit low, within thumb reach, and the poster shows at the top.
- The arrows and the volume and channel keys repeat while you hold them.
- The Voice key opens a box that sends text to the TV's search. Tap the iPhone keyboard's 🎤 to dictate.
- 123 opens a number pad with Guide, Info and the color keys.
- Apps open from **⋯ → All apps**. That screen has quick buttons for YouTube, Netflix, Disney+ and Prime Video.
- The ⋯ menu has the full app list and extra keys the physical remote doesn't have (rewind, fast‑forward, stop, subtitles…).
- Gets the TV's own button codes on connect, and uses the standard Sony codes if that fails
- Haptics, dark UI, and VoiceOver labels

## TV setup (one time)
1. **Settings › Network & Internet › Remote device settings › Control remotely → On**
2. In the same menu, set **Authentication → Normal** (PIN).
3. Optional: **Settings › Network & Internet › Remote Start → On** lets the app turn the TV on from standby.
4. Put the iPhone and the TV on the same Wi‑Fi network.

## Build & run
Requires **Xcode 16 or newer** (the project uses synchronized folders) and iOS 17+.

1. Open `BraviaRemote.xcodeproj`.
2. Select the **BraviaRemote** target › *Signing & Capabilities* › choose your Team. A free Apple ID works. If the bundle ID is taken, change it.
3. Choose your iPhone and press **Run**.
4. On the first launch, allow **Local Network** access when iOS asks. Pick your TV and enter the PIN it shows.

> The Simulator can reach the TV, but the Bonjour list may be empty there. Use the manual IP field instead.

## Project layout
```
BraviaRemote/
├─ BraviaRemoteApp.swift        App entry; switches between setup and the remote
├─ RemoteViewModel.swift        State, command queue, pairing flow, errors
├─ Services/
│  ├─ BraviaClient.swift        REST + IRCC client (actRegister PIN auth, cookie renew)
│  ├─ RemoteKey.swift           Key names and fallback IRCC codes
│  ├─ TVDiscovery.swift         NWBrowser Bonjour discovery and IPv4 lookup
│  └─ KeychainStore.swift
└─ Views/
   ├─ RemoteView.swift          Main remote
   ├─ SetupView.swift           Discovery, IP entry, PIN pairing
   ├─ Sheets.swift              Apps, Keyboard, Number pad, Settings
   ├─ Theme.swift               AppTheme tokens, poster background, themed keys/rockers/D-pad, theme picker
   ├─ Components.swift          RemoteButton (press/repeat), shared key views, toast
   └─ RemoteIcons.swift         Custom glyphs: Input, Guide, volume wedge, OK cross-hair
```

## API reference (what the app calls)
| Purpose | Endpoint | Method |
|---|---|---|
| Pair / renew | `POST /sony/accessControl` | `actRegister` (401 → TV shows PIN; then `Authorization: Basic base64(":PIN")` → `Set-Cookie: auth=…`) |
| Button press | `POST /sony/IRCC` | SOAP `X_SendIRCC` |
| Button codes | `POST /sony/system` | `getRemoteControllerInfo` |
| Power | `POST /sony/system` | `getPowerStatus`, `setPowerStatus` |
| TV info | `POST /sony/system` | `getSystemInformation` |
| Apps | `POST /sony/appControl` | `getApplicationList`, `setActiveApp` |
| Text | `POST /sony/appControl` | `setTextForm` |

## Troubleshooting
- **TV doesn't show a PIN**:
  - Make sure the TV is on, not in standby.
  - Go to **Remote device settings › Deregister remote device** and remove old entries. The TV only shows a PIN for apps it doesn't already know, and each pairing attempt now uses a new app ID.
  - If **IP control › Authentication** is set to **Pre‑Shared Key** only, the TV never shows a PIN. Choose *Pre‑Shared Key* in the app instead.
- **Pre‑Shared Key setup**: on the TV go to **Settings › Network & Internet › Home network › IP control**. Set **Authentication** to **Normal and Pre‑Shared Key** and set a key, for example `0000`. Enter the same key in the app.
- **"Couldn't reach the TV"**: check the IP address. Also check **iOS Settings › Bravia Remote › Local Network** is on.
- **403 / "TV refused the request"**: **Control remotely** is off on the TV.
- **Power on does nothing**: turn on **Remote Start**. If the TV is fully off and Remote Start is off, it isn't on the network to receive commands.
- **Pairing expired**: open Settings › Forget this TV, then pair again.
