# Cadence audit: findings

Second audit, 2026-11-13, at `c19d864` (v1.7.2), standard depth. The Rust core, `cadence-mcp`, `AppModel`, `CoreClient`, `Updater`, `YouTubePlayer`, `BraveImporter`, `FocusGuard`, `NotificationManager` and CI were read in full. The views were only skimmed.

The first audit (2026-11-08) is fully shipped except calendar export, which this round adds.

## Fixed in this round

| # | Finding | Fix |
|---|---|---|
| 1 | After a write from `cadence-mcp`, the app reloads and rebuilds the engine, which restarts transition ids at 0. The app then ignores the next completions (no toast, no chime, no refresh). | `PomodoroEngine::continue_transitions_from` keeps the ids increasing. Test: `transition_ids_keep_increasing_after_an_external_reload`. |
| 2 | An older process (for example a `cadence-mcp` still running from before an update) drops fields it doesn't know when it saves. That erases data written by the newer version. | `#[serde(flatten)] extra` on every persisted struct. Test: `unknown_fields_survive_a_round_trip`. |
| 3 | The 4 Hz heartbeat republishes the model every tick, so every view re-renders 4×/s. | The timer is published only when the visible second changes, and the date only by the minute. |
| 4 | A save without fsync can leave a truncated file after a crash. That file is then moved aside without telling the user, and save failures are silent. | fsync of the file and the folder. `storageWarning` in the timer state, shown as a toast. |
| 5 | Focus completed through MCP while the app is closed is logged under the wrong day. | `cadence-mcp` sends today's local date with every command. |
| 6 | The daily target lives in UserDefaults, and MCP shells out to `defaults read` to get it. | The target is persisted in the core (`plan.setTarget`) and moved over from UserDefaults once at launch. |
| 7 | The release workflow uses actions pinned only by tag while the signing secrets are in scope. | Actions are pinned to commit SHAs. |
| 8 | The video ID from Brave reaches the embed URL without validation. | It goes through `YouTubeURL.extractVideoID`. |

## Features added

- App Intents: Start Focus, Pause Timer and Add Task, available in Shortcuts, Siri and Spotlight (`CadenceIntents.swift`).
- A reminder notification 1 hour before a task's deadline.
- Day plan export to Calendar (`plan.ics`, an iCalendar file with focus blocks only).
- New MCP tools: `skip_interval`, `reset_timer`, `set_interval_length`, `reorder_tasks`, `focus_summary`.

## Considered and rejected

- The 4 Hz file lock and stat on every tick cost very little at this size.
- Two processes generating the same task id is not a real risk: it needs the same millisecond and the same sequence number.
- Leftover updater temp folders: the OS cleans them up.
- Two-way calendar sync (reading busy times back): costly, deferred until the export proves useful.
