use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

use crate::tasks::{FocusSession, Task};
use crate::timer::PomodoroConfig;

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
}

pub fn load(path: &Path) -> Option<Persisted> {
    let data = fs::read_to_string(path).ok()?;
    serde_json::from_str::<Persisted>(&data).ok()
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
