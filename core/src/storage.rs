use serde::{Deserialize, Serialize};
use std::fs;
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
}

/// Loads saved state. A file that exists but cannot be parsed is moved aside
/// (`core-state.corrupt-<ms>.json`) so the next save cannot overwrite it.
pub fn load(path: &Path, now_ms: u64) -> Option<Persisted> {
    let data = fs::read_to_string(path).ok()?;
    match serde_json::from_str::<Persisted>(&data) {
        Ok(persisted) => Some(persisted),
        Err(error) => {
            let backup = path.with_extension(format!("corrupt-{now_ms}.json"));
            eprintln!(
                "[cadence-core] unreadable state ({error}); moved to {}",
                backup.display()
            );
            let _ = fs::rename(path, &backup);
            None
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
    fs::write(&temporary, json).map_err(|e| format!("Could not write saved state: {e}"))?;
    fs::rename(&temporary, path).map_err(|e| format!("Could not replace saved state: {e}"))?;
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

        assert!(load(&path, 42).is_none());
        assert!(!path.exists());
        let backup = dir.join("core-state.corrupt-42.json");
        assert_eq!(fs::read_to_string(&backup).unwrap(), "{ not json");
        fs::remove_dir_all(&dir).unwrap();
    }
}
