mod storage;
mod tasks;
mod timer;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};

use storage::Stats;
use tasks::{build_plan, ordered_tasks, FocusSession, Priority, Task};
use timer::{Phase, PomodoroConfig, PomodoroEngine};

struct AppCore {
    engine: PomodoroEngine,
    stats: Stats,
    tasks: Vec<Task>,
    sessions: Vec<FocusSession>,
    storage_path: Option<PathBuf>,
}

impl AppCore {
    fn new() -> Self {
        Self {
            engine: PomodoroEngine::new(PomodoroConfig::default()),
            stats: Stats::default(),
            tasks: Vec::new(),
            sessions: Vec::new(),
            storage_path: None,
        }
    }

    fn initialize(&mut self, request: &Value) -> Result<Value, CoreFailure> {
        let day = request
            .get("day")
            .and_then(Value::as_str)
            .unwrap_or("1970-01-01")
            .to_string();
        let path = request
            .get("storagePath")
            .and_then(Value::as_str)
            .filter(|path| !path.is_empty())
            .map(PathBuf::from);

        let now = now_ms(request);
        if let Some(path) = &path {
            if let Some(persisted) = storage::load(path, now) {
                self.engine = PomodoroEngine::new(persisted.config);
                if let Some(snapshot) = persisted.timer {
                    self.engine.restore(snapshot);
                }
                self.stats = persisted.stats;
                self.tasks = persisted.tasks;
                self.sessions = persisted.sessions;
                if let Some(active_id) = persisted.active_task_id {
                    if self
                        .tasks
                        .iter()
                        .any(|task| task.id == active_id && !task.done)
                    {
                        self.engine.set_active_task(Some(active_id));
                    }
                }
            }
        }
        self.storage_path = path;
        self.stats.for_day(&day);
        self.save();
        Ok(timer::to_value(self.engine.state(now, &self.stats)))
    }

    fn handle(&mut self, request: Value) -> Result<Value, CoreFailure> {
        let command = request
            .get("cmd")
            .and_then(Value::as_str)
            .ok_or_else(|| CoreFailure::new("bad_request", "Missing command."))?
            .to_string();

        if command == "initialize" {
            return self.initialize(&request);
        }

        let now = now_ms(&request);
        if let Some(day) = request.get("day").and_then(Value::as_str) {
            let before = self.stats.day.clone();
            self.stats.for_day(day);
            if before != self.stats.day {
                self.save();
            }
        }

        match command.as_str() {
            "tick" => {
                self.tick_once(now);
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.start" => {
                self.tick_once(now);
                let intention = request
                    .get("intention")
                    .and_then(Value::as_str)
                    .map(str::to_string);
                self.engine.start_with_intention(now, intention);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.resume" => {
                self.tick_once(now);
                self.engine.start(now);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.pause" => {
                self.tick_once(now);
                self.engine.pause(now);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.toggle" => {
                self.tick_once(now);
                self.engine.toggle(now);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.reset" => {
                self.tick_once(now);
                self.engine.reset();
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.skip" => {
                self.tick_once(now);
                self.engine.skip(now, &mut self.stats);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.select" => {
                self.tick_once(now);
                let phase = request
                    .get("phase")
                    .cloned()
                    .ok_or_else(|| CoreFailure::new("bad_request", "A phase is required."))
                    .and_then(|value| {
                        serde_json::from_value::<Phase>(value)
                            .map_err(|_| CoreFailure::new("bad_request", "Unknown timer phase."))
                    })?;
                self.engine.select_phase(phase);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.setLength" => {
                let minutes = request
                    .get("minutes")
                    .and_then(Value::as_u64)
                    .ok_or_else(|| CoreFailure::new("bad_request", "Minutes are required."))?;
                self.tick_once(now);
                self.engine.set_length(minutes.min(180) as u32);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.configure" => {
                let config = request
                    .get("config")
                    .cloned()
                    .ok_or_else(|| {
                        CoreFailure::new("bad_request", "A timer configuration is required.")
                    })
                    .and_then(|value| {
                        serde_json::from_value::<PomodoroConfig>(value).map_err(|error| {
                            CoreFailure::new(
                                "bad_request",
                                format!("Invalid timer configuration: {error}"),
                            )
                        })
                    })?;
                self.engine.configure(config);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "timer.assignTask" => {
                let task_id = request
                    .get("taskId")
                    .and_then(Value::as_str)
                    .map(str::to_string);
                if let Some(id) = &task_id {
                    let valid = self
                        .tasks
                        .iter()
                        .any(|task| &task.id == id && !task.done && !task.archived);
                    if !valid {
                        return Err(CoreFailure::new(
                            "bad_request",
                            "That task is no longer available.",
                        ));
                    }
                }
                self.engine.set_active_task(task_id);
                self.save();
                Ok(timer::to_value(self.engine.state(now, &self.stats)))
            }
            "tasks.list" => Ok(json!(ordered_tasks(&self.tasks))),
            "sessions.list" => Ok(json!(self.sessions)),
            "tasks.add" => self.task_add(&request, now),
            "tasks.update" => self.task_update(&request),
            "tasks.reorder" => self.task_reorder(&request),
            "tasks.toggle" => self.task_toggle(&request, now),
            "tasks.delete" => self.task_delete(&request),
            "tasks.clearOpen" => self.clear_open_tasks(),
            "plan.build" => self.build_plan_value(&request, now),
            _ => Err(CoreFailure::new(
                "unknown_command",
                format!("Unknown command: {command}"),
            )),
        }
    }

    fn tick_once(&mut self, now: u64) {
        let previous_phase = self.engine.state(now, &self.stats).phase;
        let active_task_id = self.engine.active_task_id().cloned();
        let intention = self.engine.intention().cloned();
        if !self.engine.tick(now, &mut self.stats) {
            return;
        }
        if previous_phase == Phase::Focus {
            self.log_focus_completion(now, active_task_id, intention);
        }
        self.save();
    }

    fn log_focus_completion(
        &mut self,
        now: u64,
        active_task_id: Option<String>,
        intention: Option<String>,
    ) {
        let minutes = self
            .engine
            .last_transition()
            .map(|transition| transition.focus_minutes_added)
            .unwrap_or(self.engine.config().focus_minutes);
        let mut task_title = None;
        let mut priority = None;
        if let Some(task_id) = active_task_id.clone() {
            if let Some(task) = self.tasks.iter_mut().find(|task| task.id == task_id) {
                task.completed_blocks = task.completed_blocks.saturating_add(1);
                task.focused_minutes = task.focused_minutes.saturating_add(minutes);
                task.last_focused_at_ms = Some(now);
                task_title = Some(task.title.clone());
                priority = Some(task.priority);
                if !task.done {
                    task.in_progress = true;
                }
            }
        }
        self.sessions.push(FocusSession {
            id: new_id("session", now),
            task_id: active_task_id,
            task_title,
            priority,
            intention,
            minutes,
            completed_at_ms: now,
            day: self.stats.day.clone(),
        });
    }

    fn task_add(&mut self, request: &Value, now: u64) -> Result<Value, CoreFailure> {
        let title = request
            .get("title")
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|title| !title.is_empty())
            .ok_or_else(|| CoreFailure::new("bad_request", "A task title is required."))?
            .to_string();
        let priority = parse_priority(request).unwrap_or_default();
        let in_progress = request.get("inProgress").and_then(Value::as_bool).unwrap_or(false);
        let position = self.tasks.iter().map(|task| task.position + 1).max().unwrap_or(0);
        let estimate_blocks = request
            .get("estimateBlocks")
            .and_then(Value::as_u64)
            .unwrap_or(1)
            .clamp(1, 24) as u32;
        self.tasks.push(Task {
            id: new_id("task", now),
            title,
            priority,
            estimate_blocks,
            created_at_ms: now,
            in_progress,
            position,
            ..Task::default()
        });
        self.save();
        Ok(json!(ordered_tasks(&self.tasks)))
    }

    fn task_update(&mut self, request: &Value) -> Result<Value, CoreFailure> {
        let id = request
            .get("id")
            .and_then(Value::as_str)
            .ok_or_else(|| CoreFailure::new("bad_request", "A task id is required."))?;
        let Some(task) = self.tasks.iter_mut().find(|task| task.id == id) else {
            return Err(CoreFailure::new("not_found", "Task not found."));
        };
        if let Some(title) = request
            .get("title")
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|title| !title.is_empty())
        {
            task.title = title.to_string();
        }
        if let Some(priority) = parse_priority(request) {
            task.priority = priority;
        }
        if let Some(estimate) = request.get("estimateBlocks").and_then(Value::as_u64) {
            task.estimate_blocks = (estimate.clamp(1, 24) as u32).max(task.completed_blocks);
        }
        if let Some(in_progress) = request.get("inProgress").and_then(Value::as_bool) {
            task.in_progress = in_progress;
        }
        if let Some(archived) = request.get("archived").and_then(Value::as_bool) {
            task.archived = archived;
        }
        let archived_id = task.archived.then(|| task.id.clone());
        if archived_id.is_some() && self.engine.active_task_id() == archived_id.as_ref() {
            self.engine.set_active_task(None);
        }
        self.save();
        Ok(json!(ordered_tasks(&self.tasks)))
    }

    /// Sets manual order: each listed id gets its index as position.
    fn task_reorder(&mut self, request: &Value) -> Result<Value, CoreFailure> {
        let ids = request
            .get("ids")
            .and_then(Value::as_array)
            .ok_or_else(|| CoreFailure::new("bad_request", "A list of task ids is required."))?;
        for (index, id) in ids.iter().filter_map(Value::as_str).enumerate() {
            if let Some(task) = self.tasks.iter_mut().find(|task| task.id == id) {
                task.position = index as i64;
            }
        }
        self.save();
        Ok(json!(ordered_tasks(&self.tasks)))
    }

    fn task_toggle(&mut self, request: &Value, now: u64) -> Result<Value, CoreFailure> {
        let id = request
            .get("id")
            .and_then(Value::as_str)
            .ok_or_else(|| CoreFailure::new("bad_request", "A task id is required."))?
            .to_string();
        let (is_done, task_id) = {
            let Some(task) = self.tasks.iter_mut().find(|task| task.id == id) else {
                return Err(CoreFailure::new("not_found", "Task not found."));
            };
            if task.done {
                task.done = false;
                task.completed_at_ms = None;
                task.completed_day = None;
            } else {
                task.done = true;
                task.completed_at_ms = Some(now);
                task.completed_day = Some(self.stats.day.clone());
            }
            (task.done, task.id.clone())
        };
        if is_done && self.engine.active_task_id() == Some(&task_id) {
            self.engine.set_active_task(None);
        }
        self.save();
        Ok(json!(ordered_tasks(&self.tasks)))
    }

    fn task_delete(&mut self, request: &Value) -> Result<Value, CoreFailure> {
        let id = request
            .get("id")
            .and_then(Value::as_str)
            .ok_or_else(|| CoreFailure::new("bad_request", "A task id is required."))?
            .to_string();
        self.tasks.retain(|task| task.id != id);
        if self.engine.active_task_id() == Some(&id) {
            self.engine.set_active_task(None);
        }
        self.save();
        Ok(json!(ordered_tasks(&self.tasks)))
    }

    fn clear_open_tasks(&mut self) -> Result<Value, CoreFailure> {
        let active_id = self.engine.active_task_id().cloned();
        let active_was_open = active_id
            .as_ref()
            .and_then(|id| self.tasks.iter().find(|task| &task.id == id))
            .map(|task| !task.done)
            .unwrap_or(false);
        self.tasks.retain(|task| task.done);
        if active_was_open {
            self.engine.set_active_task(None);
        }
        self.save();
        Ok(json!(ordered_tasks(&self.tasks)))
    }

    fn build_plan_value(&self, request: &Value, now: u64) -> Result<Value, CoreFailure> {
        let target_minutes = request
            .get("targetMinutes")
            .and_then(Value::as_u64)
            .unwrap_or(240)
            .min(1440) as u32;
        let buffer_minutes = request
            .get("bufferMinutes")
            .and_then(Value::as_u64)
            .unwrap_or(5)
            .min(60) as u32;
        let plan = build_plan(
            &self.tasks,
            self.engine.config(),
            now,
            target_minutes,
            buffer_minutes,
        );
        serde_json::to_value(plan)
            .map_err(|error| CoreFailure::new("serialization", error.to_string()))
    }

    fn save(&self) {
        let Some(path) = &self.storage_path else {
            return;
        };
        let payload = storage::Persisted {
            config: self.engine.config().clone(),
            stats: self.stats.clone(),
            tasks: self.tasks.clone(),
            sessions: self.sessions.clone(),
            active_task_id: self.engine.active_task_id().cloned(),
            timer: Some(self.engine.snapshot()),
        };
        if let Err(error) = storage::save(path, &payload) {
            eprintln!("[cadence-core] {error}");
        }
    }
}

fn parse_priority(request: &Value) -> Option<Priority> {
    request
        .get("priority")
        .cloned()
        .and_then(|value| serde_json::from_value(value).ok())
}

#[derive(Debug)]
struct CoreFailure {
    code: &'static str,
    message: String,
}

impl CoreFailure {
    fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }
}

static ID_SEQUENCE: AtomicU64 = AtomicU64::new(1);

fn new_id(prefix: &str, now: u64) -> String {
    format!(
        "{prefix}-{now}-{}",
        ID_SEQUENCE.fetch_add(1, Ordering::Relaxed)
    )
}

fn now_ms(request: &Value) -> u64 {
    request
        .get("nowMs")
        .and_then(Value::as_u64)
        .unwrap_or_else(|| {
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|duration| duration.as_millis() as u64)
                .unwrap_or(0)
        })
}

static CORE: OnceLock<Mutex<AppCore>> = OnceLock::new();

fn core() -> &'static Mutex<AppCore> {
    CORE.get_or_init(|| Mutex::new(AppCore::new()))
}

fn response_ok(data: Value) -> String {
    json!({ "ok": true, "data": data }).to_string()
}

fn response_error(code: &str, message: &str) -> String {
    json!({ "ok": false, "code": code, "error": message }).to_string()
}

fn process_request(raw: &str) -> String {
    let request: Value = match serde_json::from_str(raw) {
        Ok(value) => value,
        Err(error) => return response_error("bad_json", &format!("Invalid request: {error}")),
    };
    let mut core = core()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    match core.handle(request) {
        Ok(data) => response_ok(data),
        Err(failure) => response_error(failure.code, &failure.message),
    }
}

/// # Safety
/// request must point to a valid, null-terminated UTF-8 string for the duration of the call.
/// The returned pointer must be released with cadence_core_free.
#[no_mangle]
pub unsafe extern "C" fn cadence_core_invoke(request: *const c_char) -> *mut c_char {
    let response = catch_unwind(AssertUnwindSafe(|| {
        if request.is_null() {
            return response_error("null_request", "No request was provided.");
        }
        let raw = CStr::from_ptr(request).to_string_lossy();
        process_request(&raw)
    }))
    .unwrap_or_else(|_| response_error("panic", "The native core stopped unexpectedly."));

    CString::new(response)
        .unwrap_or_else(|_| {
            CString::new(response_error("encoding", "Response encoding failed.")).unwrap()
        })
        .into_raw()
}

/// # Safety
/// pointer must be a value returned by cadence_core_invoke that has not already been freed.
#[no_mangle]
pub unsafe extern "C" fn cadence_core_free(pointer: *mut c_char) {
    if !pointer.is_null() {
        drop(CString::from_raw(pointer));
    }
}

#[no_mangle]
pub extern "C" fn cadence_core_abi_version() -> u32 {
    2
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn envelope_round_trip() {
        let raw = r#"{"cmd":"tick","nowMs":1000,"day":"2026-10-26"}"#;
        let parsed: Value = serde_json::from_str(&process_request(raw)).unwrap();
        assert_eq!(parsed["ok"], true);
        assert_eq!(parsed["data"]["phase"], "focus");
    }

    /// Swift decodes these keys (App/Sources/Models.swift `TimerState`, `FocusSession`).
    /// If this fails, update the Swift models in the same change.
    #[test]
    fn json_contract_matches_swift_models() {
        let mut core = AppCore::new();
        let state = core
            .handle(json!({"cmd": "tick", "nowMs": 1_000, "day": "2026-10-26"}))
            .unwrap();
        let mut keys: Vec<&str> = state.as_object().unwrap().keys().map(String::as_str).collect();
        keys.sort_unstable();
        assert_eq!(
            keys,
            [
                "activeTaskId", "completedInCycle", "config", "cycleLength", "endsAtMs",
                "intention", "phase", "remainingMs", "running", "todayFocusMinutes",
                "todaySessions", "totalMs", "totalSessions", "transition",
            ]
        );
        let mut config: Vec<&str> =
            state["config"].as_object().unwrap().keys().map(String::as_str).collect();
        config.sort_unstable();
        assert_eq!(
            config,
            [
                "autoStartNext", "focusMinutes", "longBreakMinutes",
                "sessionsBeforeLongBreak", "shortBreakMinutes",
            ]
        );

        core.sessions.push(FocusSession::default());
        let sessions = core
            .handle(json!({"cmd": "sessions.list", "nowMs": 1_000, "day": "2026-10-26"}))
            .unwrap();
        let mut session: Vec<&str> =
            sessions[0].as_object().unwrap().keys().map(String::as_str).collect();
        session.sort_unstable();
        assert_eq!(
            session,
            [
                "completedAtMs", "day", "id", "intention", "minutes", "priority", "taskId",
                "taskTitle",
            ]
        );
    }

    #[test]
    fn focus_completion_updates_the_active_task_and_logs_intention() {
        let day = "2026-10-26";
        let mut core = AppCore::new();
        let added = core
            .handle(json!({
                "cmd": "tasks.add",
                "title": "Draft the API specification",
                "priority": "high",
                "estimateBlocks": 3,
                "nowMs": 500,
                "day": day
            }))
            .unwrap();
        let task_id = added[0]["id"].as_str().unwrap().to_string();
        core.handle(json!({
            "cmd": "timer.assignTask",
            "taskId": task_id,
            "nowMs": 600,
            "day": day
        }))
        .unwrap();
        core.handle(json!({
            "cmd": "timer.start",
            "intention": "A clear endpoint contract",
            "nowMs": 1_000,
            "day": day
        }))
        .unwrap();
        core.handle(json!({
            "cmd": "tick",
            "nowMs": 1_000 + 25 * 60_000,
            "day": day
        }))
        .unwrap();

        let tasks = core
            .handle(json!({"cmd": "tasks.list", "nowMs": 2_000, "day": day}))
            .unwrap();
        assert_eq!(tasks[0]["completedBlocks"], 1);
        assert_eq!(tasks[0]["focusedMinutes"], 25);
        assert_eq!(core.sessions.len(), 1);
        assert_eq!(
            core.sessions[0].intention.as_deref(),
            Some("A clear endpoint contract")
        );
        assert_eq!(core.sessions[0].task_id.as_deref(), Some(task_id.as_str()));
        assert_eq!(tasks[0]["inProgress"], true);
    }

    #[test]
    fn reorder_and_archive_tasks() {
        let day = "2026-10-26";
        let mut core = AppCore::new();
        for (index, title) in ["a", "b"].iter().enumerate() {
            core.handle(json!({"cmd": "tasks.add", "title": title, "nowMs": index, "day": day}))
                .unwrap();
        }
        let ids: Vec<String> = core.tasks.iter().map(|task| task.id.clone()).collect();
        core.handle(json!({"cmd": "tasks.reorder", "ids": [ids[1], ids[0]], "nowMs": 5, "day": day}))
            .unwrap();
        let tasks = core.handle(json!({"cmd": "tasks.list", "nowMs": 5, "day": day})).unwrap();
        assert_eq!(tasks[0]["title"], "b");

        core.handle(json!({"cmd": "timer.assignTask", "taskId": ids[0], "nowMs": 6, "day": day}))
            .unwrap();
        core.handle(json!({"cmd": "tasks.update", "id": ids[0], "archived": true, "nowMs": 7, "day": day}))
            .unwrap();
        assert!(core.tasks.iter().find(|task| task.id == ids[0]).unwrap().archived);
        assert!(core.engine.active_task_id().is_none());
    }
}
