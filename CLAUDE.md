# Cadence

Native macOS focus app: SwiftUI UI + Rust core over a JSON-over-C ABI.

## Commands

- `make run` — build Debug (Xcode pre-build compiles the Rust core) and open the app
- `make release` — Release build into `dist/Cadence.app`; `make zip` packages it
- `make test` — Rust unit tests (`core/`, uses `.cargo-home`)
- `cd core && CARGO_HOME=../.cargo-home cargo test --offline` — same, without make
- `make project` — regenerate `Cadence.xcodeproj` from `project.yml` (needs xcodegen; checked-in project is used otherwise)
- No Swift tests, no linter, no CI.

## Layout

- `core/src/lib.rs` — C ABI (`cadence_core_invoke/free/abi_version`) + command router (`timer.*`, `tasks.*`, `plan.build`)
- `core/src/timer.rs` — Pomodoro state machine; `tasks.rs` — tasks, Eisenhower quadrants, day planner; `storage.rs` — JSON persistence (`~/Library/Application Support/Cadence/core-state.json`)
- `App/Sources/CoreClient.swift` — Swift wrapper for the ABI; `AppModel.swift` — main `ObservableObject`, 4 Hz heartbeat ticks the core
- `App/Sources/YouTubePlayer.swift` — embedded WKWebView YouTube player; `BraveImporter.swift` — pulls the current video from Brave via osascript
- Views: `FocusView`, `TasksView`, `MusicView`, `SettingsView`, `ShutdownRitualView`, `IntentionCheckInView`, `MenuBarWidgetView`, `SidebarView`; shared styling in `DesignSystem.swift`

## Conventions

- Business logic lives in Rust; Swift renders state and sends intents. New commands: add to `AppCore::handle` + a `CoreClient` method.
- JSON is camelCase (`#[serde(rename_all = "camelCase", default)]`); enums are snake_case.
- Every core mutation calls `self.save()`.
- Errors surface in the UI via `AppModel.showToast(..., tint: Theme.amber)`.
- Debug launch args: `--demo-data`, `--tab=`, `--theme=`, `--show-settings`, `--video=` etc. (see `AppModel.init`).
- `README.md` is partly outdated (still describes Brave remote-control, no Tasks tab).
