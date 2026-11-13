use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};
use std::fs;
use std::io::Write;
use std::path::Path;

use crate::tasks::{FocusSession, Task};
use crate::timer::{EngineSnapshot, PomodoroConfig};

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
#[serde(rename_all = "camelCase", default)]
pub struct Stats {
    pub day: String,
    pub today_focus_minutes: u32,
    pub today_sessions: u32,
    pub total_focus_minutes: u64,
    pub total_sessions: u64,
    /// Fields written by a newer Cadence; kept so an older process never erases them.
    #[serde(flatten)]
    pub extra: Map<String, Value>,
}

impl Stats {
    pub fn for_day(&mut self, day: &str) {
        if self.day != day {
            self.day = day.to_string();
            self.today_focus_minutes = 0;
            self.today_sessions = 0;
        }
    }

    pub fn record_focus(&mut self, minutes: u32) {
        self.today_focus_minutes = self.today_focus_minutes.saturating_add(minutes);
        self.today_sessions = self.today_sessions.saturating_add(1);
        self.total_focus_minutes = self.total_focus_minutes.saturating_add(minutes as u64);
        self.total_sessions = self.total_sessions.saturating_add(1);
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
#[serde(rename_all = "camelCase", default)]
pub struct Persisted {
    pub config: PomodoroConfig,
    pub stats: Stats,
    pub tasks: Vec<Task>,
    pub sessions: Vec<FocusSession>,
    pub active_task_id: Option<String>,
    pub timer: Option<EngineSnapshot>,
    /// Daily focus target for the day plan; None until the user sets one.
    pub daily_target_minutes: Option<u32>,
    #[serde(flatten)]
    pub extra: Map<String, Value>,
}

/// Loads saved state: `Ok(None)` when there is no file. A file that exists but cannot be
/// parsed is moved aside (`core-state.corrupt-<ms>.json`) so the next save cannot overwrite
/// it; the error says where it went.
pub fn load(path: &Path, now_ms: u64) -> Result<Option<Persisted>, String> {
    let Ok(data) = fs::read_to_string(path) else {
        return Ok(None);
    };
    match serde_json::from_str::<Persisted>(&data) {
        Ok(persisted) => Ok(Some(persisted)),
        Err(error) => {
            let backup = path.with_extension(format!("corrupt-{now_ms}.json"));
            eprintln!(
                "[cadence-core] unreadable state ({error}); moved to {}",
                backup.display()
            );
            let _ = fs::rename(path, &backup);
            Err(format!(
                "Your saved data couldn't be read, so Cadence started fresh. The old file was kept at {}.",
                backup.display()
            ))
        }
    }
}

pub fn save(path: &Path, payload: &Persisted) -> Result<(), String> {
    let parent = path
        .parent()
        .ok_or_else(|| "Storage path has no parent folder".to_string())?;
    fs::create_dir_all(parent).map_err(|e| format!("Could not create app data folder: {e}"))?;

    let json = serde_json::to_string_pretty(payload)
        .map_err(|e| format!("Could not encode saved state: {e}"))?;
    let temporary = path.with_extension("json.tmp");
    // fsync before the rename: otherwise a crash can leave a renamed but empty file.
    let mut file =
        fs::File::create(&temporary).map_err(|e| format!("Could not write saved state: {e}"))?;
    file.write_all(json.as_bytes())
        .and_then(|_| file.sync_all())
        .map_err(|e| format!("Could not write saved state: {e}"))?;
    fs::rename(&temporary, path).map_err(|e| format!("Could not replace saved state: {e}"))?;
    if let Ok(dir) = fs::File::open(parent) {
        let _ = dir.sync_all();
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn corrupt_state_is_moved_aside_not_overwritten() {
        let dir = std::env::temp_dir().join(format!("cadence-test-{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("core-state.json");
        fs::write(&path, "{ not json").unwrap();

        assert!(load(&path, 42).unwrap_err().contains("core-state.corrupt-42.json"));
        assert!(!path.exists());
        let backup = dir.join("core-state.corrupt-42.json");
        assert_eq!(fs::read_to_string(&backup).unwrap(), "{ not json");
        fs::remove_dir_all(&dir).unwrap();
    }

    /// A newer Cadence may add fields; an older process (e.g. a long-running cadence-mcp)
    /// that loads and saves the file must keep them.
    #[test]
    fn unknown_fields_survive_a_round_trip() {
        let raw = r#"{"futureTop":1,"stats":{"futureStat":"s"},"config":{"focusMinutes":30,"futureConfig":true},
            "tasks":[{"id":"a","title":"t","futureTask":[1,2]}],
            "sessions":[{"id":"s","minutes":25,"futureSession":{"x":1}}],
            "timer":{"phase":"focus","running":false,"remainingMs":1,"completedInCycle":0,"futureTimer":7}}"#;
        let persisted: Persisted = serde_json::from_str(raw).unwrap();
        let saved = serde_json::to_value(&persisted).unwrap();
        assert_eq!(saved["futureTop"], 1);
        assert_eq!(saved["stats"]["futureStat"], "s");
        assert_eq!(saved["config"]["futureConfig"], true);
        assert_eq!(saved["tasks"][0]["futureTask"][1], 2);
        assert_eq!(saved["sessions"][0]["futureSession"]["x"], 1);
        assert_eq!(saved["timer"]["futureTimer"], 7);
    }
}
