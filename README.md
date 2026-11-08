# Cadence

<p align="left"><img src="docs/icon-preview.png" width="86" alt="Cadence app icon" /></p>

**A native macOS focus player.** A Pomodoro timer with a music tab that controls the YouTube video you already have playing in Brave.

Cadence is deliberately split down the middle: the interface is SwiftUI, while the timer state machine, persistence, and browser bridge are all Rust. The app talks to the Rust core over a tiny JSON-over-C ABI.

![Cadence focus screen](docs/screenshots/focus.jpg)

## What's inside

- **Focus** — 25/5/15 Pomodoro intervals, a long break every four focus sessions, configurable durations, session rhythm, and daily focus stats.
- **Music** — a now-playing view for the YouTube tab in Brave. Play/pause, skip, seek, change volume, search YouTube, or jump back into Brave.
- **Native notifications** — a system banner plus a calm chime when an interval ends.
- **Automatic Brave connection** — opening Music checks Brave immediately and retries in the background. Cadence also detects missing automation permission, a stopped Brave, or Brave's Apple Events JavaScript setting being off.
- **Keyboard-first** — start, pause, reset, skip, and switch tabs without leaving the keyboard.

![Cadence music screen](docs/screenshots/music.jpg)

## Requirements

- macOS 14 or newer (Apple Silicon)
- Xcode 16 or newer with Swift 5.9+
- Rust (install from [rustup.rs](https://rustup.rs)) — Cargo must be available at `~/.cargo/bin` or on `PATH`
- Brave Browser, for the music tab
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — optional, because `Cadence.xcodeproj` is checked in

## Run it

```bash
make run
```

Or open `Cadence.xcodeproj` in Xcode and press **Run**. The Xcode pre-build phase compiles the Rust core automatically.

To build a standalone Release app:

```bash
make release
open dist/Cadence.app
```

## Connect YouTube in Brave

Cadence does not embed a second player and does not ask for a YouTube API key. It drives the YouTube tab that is already open in Brave through AppleScript and JavaScript.

1. Open a YouTube video in Brave.
2. In Brave's menu bar, go to **View → Developer → Allow JavaScript from Apple Events**.
3. In Cadence, open **Music**. Cadence checks Brave automatically and connects to the YouTube tab.
4. When macOS asks whether Cadence may control Brave Browser, choose **Allow**.
   If you miss the prompt, enable it later in **System Settings → Privacy & Security → Automation**.

Cadence re-checks Brave automatically while the Music tab is open, including after you change permissions or the Brave setting. There is no need to press refresh. If multiple YouTube tabs exist, Cadence uses the active YouTube tab in the front window, or the first YouTube tab it finds.

### What the music controls do

| Control | Action |
| --- | --- |
| Play / pause | Toggles the HTML5 video in the YouTube tab |
| Previous | YouTube previous button, or seeks to 0 when unavailable |
| Next | YouTube next button |
| Scrubber | Sets the video's currentTime |
| Volume | Sets the video's volume and unmutes when volume is raised |
| Search | Opens YouTube search results in Brave |
| Show / Reveal | Brings Brave to the front |

## A closer look

<p align="center">
  <img src="docs/screenshots/focus-running.jpg" width="48%" alt="A focus interval running" />
  <img src="docs/screenshots/settings.jpg" width="48%" alt="Cadence preferences" />
</p>

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘ 1` | Focus tab |
| `⌘ 2` | Music tab |
| `⌘ ↩` | Start / pause the timer |
| `⌘ R` | Reset the current interval |
| `⌘ →` | Skip to the next interval |
| `⌘ ,` | Preferences |
| `⌘ ⇧ R` | Refresh the Brave connection |

## Architecture

```text
┌──────────────────────────────────────────────┐
│ SwiftUI                                      │
│                                              │
│  AppModel   FocusView   MusicView            │
│  SettingsView   DesignSystem                 │
│                  │                           │
│           CoreClient (C ABI + JSON)          │
└──────────────────┼───────────────────────────┘
                   │ cadence_core_invoke()
┌──────────────────▼───────────────────────────┐
│ Rust core — libcadence_core.a                │
│                                              │
│  timer.rs      Pomodoro state machine        │
│  storage.rs    preferences + daily stats     │
│  music.rs      AppleScript / YouTube bridge  │
└──────────────────┬───────────────────────────┘
                   │ osascript
┌──────────────────▼───────────────────────────┐
│ Brave Browser → active YouTube tab           │
└──────────────────────────────────────────────┘
```

### The ABI

The entire native interface is three C functions in `App/Bridge/CadenceCore.h`:

```c
char *cadence_core_invoke(const char *request);
void  cadence_core_free(char *pointer);
uint32_t cadence_core_abi_version(void);
```

Requests and responses are JSON. Commands include `initialize`, `tick`, `timer.start`, `timer.toggle`, `timer.configure`, `music.probe`, `music.status`, `music.toggle`, `music.seek`, `music.setVolume`, and `music.openSearch`.

The Rust core owns:

- the interval state machine and transitions
- auto-advancing after a completed interval
- the four-session long-break cycle
- daily/all-time stats and preferences
- all Brave detection, AppleScript execution, and YouTube DOM interaction

SwiftUI only renders state and sends intents.

## Project layout

```text
App/
  Bridge/              C header + Swift bridging header
  Sources/             SwiftUI app, models, Rust client, views
  Resources/           asset catalog and app icon
  Info.plist
  Cadence.entitlements
core/
  src/lib.rs           C ABI + command routing
  src/timer.rs         Pomodoro engine and unit tests
  src/storage.rs       Preferences and stats persistence
  src/music.rs         Brave/YouTube bridge
  Cargo.toml
scripts/
  generate_icon.py     Rebuilds the app icon asset catalog
docs/screenshots/      README screenshots
project.yml            XcodeGen project definition
Cadence.xcodeproj      Ready-to-open Xcode project
```

## Data

Preferences and daily stats live at:

```text
~/Library/Application Support/Cadence/core-state.json
```

The current version intentionally keeps in-flight intervals in memory; if you quit and relaunch, the timer starts paused at the beginning of the current interval while your stats and interval settings are preserved.

## Tests

```bash
make test
```

This runs the Rust unit tests for the timer state machine, long-break cycle, pause semantics, skipped sessions, and the FFI command envelope.

To rebuild the app icon (requires Python 3 + Pillow):

```bash
python3 scripts/generate_icon.py
```

## Notes and limitations

- **Not sandboxed.** Apple Events automation and direct browser control require the non-sandboxed build used here. The app is ad-hoc signed for local use, not notarized. If you distribute it, sign and notarize it with your own Developer ID.
- **One YouTube tab at a time.** Cadence controls the active YouTube tab (or the first YouTube tab it finds in Brave).
- **DOM-dependent.** The music controls use YouTube's player button selectors. If YouTube changes its DOM, `core/src/music.rs` is the place to update.
- **Brave's JavaScript toggle is required.** This is a Brave security setting and cannot be enabled by Cadence automatically.
- The app is built for Apple Silicon. Add an `x86_64` Rust target (and update `ARCHS`) if you need Intel support.

Built with SwiftUI and a Rust core.
