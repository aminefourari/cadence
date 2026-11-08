# Cadence audit: findings

Audited 2026-11-08 at standard depth. All of `core/src` and `AppModel`, `CoreClient`, `YouTubePlayer`, `BraveImporter`, `NotificationManager`, and `CadenceApp` were read in full. The other views were skimmed. Not audited: `DesignSystem.swift` (rendering and perf details), `SettingsView`, `scripts/generate_icon.py`.
Baseline: `cargo test` passes 9/9. There are no Swift tests and no CI, and the folder is **not a git repo**.

## Problems, ordered by leverage

| # | Finding | Category | Impact | Effort | Risk | Evidence |
|---|---|---|---|---|---|---|
| 1 | **Volume slider stops working after the first change.** Top-level `const p=` is injected through `evaluateJavaScript` more than once on the same page, so every later call throws `SyntaxError: duplicate variable 'p'`. The next status poll then moves the slider back. I reproduced this in JavaScriptCore. | bug | High | S | Low | `App/Sources/YouTubePlayer.swift:235`, `:379` |
| 2 | **A running session is lost on quit, crash, or relaunch.** `Persisted` stores the config, stats, and tasks, but not the phase, `ends_at_ms`, `remaining_ms`, `completed_in_cycle`, or the intention. After relaunch the user always gets a fresh 25-minute focus and the cycle count goes back to 0. | bug/UX | High | M | Med | `core/src/storage.rs:36-43`, `core/src/lib.rs:47-62` |
| 3 | **A corrupt or unreadable state file is silently overwritten with defaults.** `load()` returns `None` on any parse error, and `initialize` then calls `save()` right away, which wipes all tasks, history, and stats. | data loss | High | S | Low | `core/src/storage.rs:45-48`, `core/src/lib.rs:63-65` |
| 4 | **Notifications depend on the in-app 4 Hz timer.** When the window is closed, App Nap can throttle that timer, so the "focus complete" banner and chime can arrive late. A `UNTimeIntervalNotificationTrigger` scheduled at start, or a `ProcessInfo.beginActivity` while the timer runs, would fix it. | bug | Med | S | Low | `App/Sources/AppModel.swift:271-295`, `NotificationManager.swift:34-50` |
| 5 | **No version control.** The folder has no `.git`, even though a `.gitignore` exists. Nothing can be reverted, and an 11 MB `background-test.png` sits in the root. | DX | High | S | None | repo root |
| 6 | **The README describes an older app.** It says "does not embed a second player" (it now embeds a WKWebView), lists `music.rs` and `music.*` commands (neither exists), says ⌘2 opens Music (it is now ⌘3, ⌘2 is Tasks), and never mentions Tasks, the planner, the intention check-in, the shutdown ritual, or the menu bar widget. | docs | Med | S | None | `README.md` vs `CadenceApp.swift:45-62`, `core/src/lib.rs:1-3` |
| 7 | **The UI and core disagree on small things.** The task editor caps estimates at 12 blocks while the core allows 24. The delete dialog says focus history is removed, but sessions are kept. | polish | Low | S | Low | `TasksView.swift:686`, `TasksView.swift:55`, `core/src/lib.rs:313-324` |
| 8 | **No Swift-side tests.** `CoreClient` JSON decoding against the Rust output is untested, so a serde rename in Rust only shows up at runtime. One Rust test that snapshots the `TimerState` JSON keys would catch most of this. | tests | Med | S | None | `core/src/lib.rs:513-562` |

Considered and rejected:
- The 4 Hz heartbeat crossing the FFI with JSON costs very little at this size.
- `sessions` grows without limit, but years of use is about 1 MB.
- `assignTask` pausing the timer is by design.

## Direction: features worth weighing

1. **History and stats view.** This is the best payoff for the least work. The core already logs a `FocusSession` for every completed block, with its task, quadrant, intention, minutes, and day (`core/src/lib.rs:197-206`), but nothing in the UI reads it. Possible views: a week heatmap or bar chart, streaks, minutes per quadrant, and "what I intended vs. did". It needs one `sessions.list` command plus one view, and Swift Charts ships with the system. Effort M.
2. **Music follows the timer.** Pause YouTube automatically when a break starts and resume it when focus starts, or play a separate "break" video. Both the player and `handleTransition` already exist, so this is a hook in `AppModel.applyTimer` plus a setting. Effort S.
3. **Focus guard during sessions.** Turn on a macOS Focus mode through a Shortcuts URL, or warn when distracting apps or sites come to the front while a focus block runs. This is valuable, but it adds permissions and can feel intrusive. Effort M–L.
4. **Plan → calendar.** Export the generated day plan (`plan.build`) as an `.ics` file or write it to Calendar through EventKit, so the time-boxed day shows up next to meetings. You could also go the other way and read busy blocks so the planner works around meetings. Effort M (export) / L (two-way).

Recommended order: 5 (git) → 1, 3 (quick bugs) → 2 (session restore) → 4 → direction #1.
