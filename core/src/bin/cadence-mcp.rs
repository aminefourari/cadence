//! MCP server (stdio, JSON-RPC 2.0) that lets AI agents manage Cadence tasks and the timer.
//! Every tool call goes through the same command router the app uses; the state file is
//! shared and locked, and the running app picks changes up on its next tick.
//!
//! State file: $CADENCE_STATE, else ~/Library/Application Support/Cadence/core-state.json.

use std::io::{self, BufRead, Write};

use serde_json::{json, Value};

const PROTOCOL_VERSION: &str = "2025-06-18";

fn tools() -> Value {
    let id = json!({"type": "string", "description": "Task id from list_tasks."});
    let priority = json!({"type": "string", "enum": ["high", "medium", "low"]});
    let due = json!({"type": ["string", "null"],
        "description": "Deadline in local time, e.g. 2026-11-14T15:30 (an offset like +01:00 or Z is also accepted; a bare date means 23:59 that day). In update_task, null or \"\" clears it."});
    let estimate = json!({"type": "integer", "minimum": 1, "maximum": 24,
        "description": "Estimated focus blocks (Pomodoros). Prefer estimateMinutes."});
    let minutes = json!({"type": "integer", "minimum": 1, "maximum": 1440,
        "description": "Estimated time in minutes; Cadence splits it into focus blocks (rounded up) and re-splits if the focus length changes."});
    json!([
        {"name": "list_tasks", "description": "List tasks on the Cadence board (open first, then by priority). Archived tasks are hidden unless includeArchived.",
         "inputSchema": {"type": "object", "properties": {"includeArchived": {"type": "boolean"}, "includeDone": {"type": "boolean", "description": "Default true."}}}},
        {"name": "add_task", "description": "Add a task to the Cadence board.",
         "inputSchema": {"type": "object", "required": ["title"], "properties": {
            "title": {"type": "string"}, "priority": priority, "estimateMinutes": minutes, "estimateBlocks": estimate, "dueAt": due,
            "inProgress": {"type": "boolean", "description": "Put it in the In Progress column."}}}},
        {"name": "update_task", "description": "Edit a task: title, priority, estimate, due date, column (inProgress) or archived.",
         "inputSchema": {"type": "object", "required": ["id"], "properties": {
            "id": id, "title": {"type": "string"}, "priority": priority, "estimateMinutes": minutes, "estimateBlocks": estimate, "dueAt": due,
            "inProgress": {"type": "boolean"}, "archived": {"type": "boolean"}}}},
        {"name": "set_task_done", "description": "Mark a task done or not done.",
         "inputSchema": {"type": "object", "required": ["id", "done"], "properties": {"id": id, "done": {"type": "boolean"}}}},
        {"name": "delete_task", "description": "Permanently delete a task.",
         "inputSchema": {"type": "object", "required": ["id"], "properties": {"id": id}}},
        {"name": "timer_status", "description": "Current Pomodoro timer state: phase, running, remaining time, active task, today's stats.",
         "inputSchema": {"type": "object", "properties": {}}},
        {"name": "start_focus", "description": "Start (or resume) the timer, optionally on a task and with an intention.",
         "inputSchema": {"type": "object", "properties": {"taskId": id, "intention": {"type": "string"}}}},
        {"name": "pause_timer", "description": "Pause the running timer.",
         "inputSchema": {"type": "object", "properties": {}}},
        {"name": "day_plan", "description": "Time-box open tasks into focus blocks and breaks toward a daily target.",
         "inputSchema": {"type": "object", "properties": {"targetMinutes": {"type": "integer", "description": "Default 240."}}}},
        {"name": "list_sessions", "description": "Completed focus sessions (most recent last).",
         "inputSchema": {"type": "object", "properties": {"limit": {"type": "integer", "description": "Default 20."}}}}
    ])
}

/// Sends one core command; returns its data or the core's error message.
fn core(cmd: &str, mut args: Value) -> Result<Value, String> {
    args["cmd"] = json!(cmd);
    let response: Value = serde_json::from_str(&cadence_core::process_request(&args.to_string()))
        .map_err(|error| error.to_string())?;
    if response["ok"] == true {
        Ok(response["data"].clone())
    } else {
        Err(response["error"].as_str().unwrap_or("Core error").to_string())
    }
}

/// Tasks as agents see them: `dueAtMs` plus a readable local `dueAt`.
fn list() -> Result<Vec<Value>, String> {
    let mut tasks = core("tasks.list", json!({}))?.as_array().cloned().unwrap_or_default();
    for task in &mut tasks {
        if let Some(ms) = task["dueAtMs"].as_u64() {
            task["dueAt"] = json!(local_time(ms / 1000));
        }
    }
    Ok(tasks)
}

fn find_task(id: &str) -> Result<Value, String> {
    list()?
        .into_iter()
        .find(|task| task["id"] == id)
        .ok_or_else(|| "Task not found.".to_string())
}

/// Runs macOS `date`, which knows the user's time zone (including DST on that date).
fn date(args: &[&str]) -> Option<String> {
    let output = std::process::Command::new("/bin/date").args(args).output().ok()?;
    output.status.success().then(|| String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn local_time(seconds: u64) -> String {
    date(&["-r", &seconds.to_string(), "+%Y-%m-%dT%H:%M%z"]).unwrap_or_default()
}

/// "2026-11-14T15:30", "2026-11-14 15:30:00", "…Z", "…+01:00", or "2026-11-14" (23:59) → epoch ms.
fn parse_due(text: &str) -> Result<u64, String> {
    let invalid = || format!("Invalid dueAt \"{text}\". Use local time like 2026-11-14T15:30.");
    let text = text.trim().replacen(' ', "T", 1);
    let (body, offset_minutes) = if let Some(body) = text.strip_suffix('Z') {
        (body.to_string(), Some(0i64))
    } else if text.len() > 16 && matches!(text.as_bytes()[text.len() - 6], b'+' | b'-') {
        let (body, offset) = text.split_at(text.len() - 6);
        let sign = if offset.starts_with('-') { -1 } else { 1 };
        let hours: i64 = offset[1..3].parse().map_err(|_| invalid())?;
        let minutes: i64 = offset[4..6].parse().map_err(|_| invalid())?;
        (body.to_string(), Some(sign * (hours * 60 + minutes)))
    } else {
        (text, None)
    };
    let body = match body.len() {
        10 => format!("{body}T23:59:00"),
        16 => format!("{body}:00"),
        19 => body,
        _ => return Err(invalid()),
    };
    // -u reads the wall time as UTC; the offset (if any) is then applied by hand.
    let mut args = vec!["-j"];
    if offset_minutes.is_some() {
        args.push("-u");
    }
    args.extend(["-f", "%Y-%m-%dT%H:%M:%S", &body, "+%s"]);
    let seconds: i64 = date(&args).and_then(|out| out.parse().ok()).ok_or_else(invalid)?;
    // date -j silently rolls over impossible dates (Feb 30 → Mar 2); reject those.
    let round_trip = date(&[if offset_minutes.is_some() { "-u" } else { "-j" }, "-r", &seconds.to_string(), "+%Y-%m-%dT%H:%M:%S"]);
    if round_trip.as_deref() != Some(body.as_str()) {
        return Err(invalid());
    }
    let seconds = seconds - offset_minutes.unwrap_or(0) * 60;
    u64::try_from(seconds * 1000).map_err(|_| invalid())
}

/// Maps the agent-facing `dueAt` onto the core's `dueAtMs`.
fn with_due(args: &Value, mut request: Value) -> Result<Value, String> {
    match args.get("dueAt") {
        None => {}
        Some(Value::Null) => request["dueAtMs"] = Value::Null,
        Some(Value::String(text)) if text.trim().is_empty() => request["dueAtMs"] = Value::Null,
        Some(Value::String(text)) => request["dueAtMs"] = json!(parse_due(text)?),
        Some(_) => return Err("dueAt must be a string like 2026-11-14T15:30.".into()),
    }
    Ok(request)
}

fn call_tool(name: &str, args: &Value) -> Result<Value, String> {
    let pick = |keys: &[&str]| {
        let mut out = json!({});
        for key in keys {
            if let Some(value) = args.get(*key) {
                out[*key] = value.clone();
            }
        }
        out
    };
    match name {
        "list_tasks" => {
            let archived = args["includeArchived"].as_bool().unwrap_or(false);
            let done = args["includeDone"].as_bool().unwrap_or(true);
            Ok(json!(list()?
                .into_iter()
                .filter(|task| (archived || task["archived"] != true) && (done || task["done"] != true))
                .collect::<Vec<_>>()))
        }
        "add_task" => {
            let request = with_due(args, pick(&["title", "priority", "estimateMinutes", "estimateBlocks", "inProgress"]))?;
            let known: Vec<Value> = list()?.into_iter().map(|task| task["id"].clone()).collect();
            core("tasks.add", request)?;
            list()?
                .into_iter()
                .find(|task| !known.contains(&task["id"]))
                .ok_or_else(|| "Task was not added.".to_string())
        }
        "update_task" => {
            let id = args["id"].as_str().ok_or("A task id is required.")?;
            core("tasks.update", with_due(args, pick(&["id", "title", "priority", "estimateMinutes", "estimateBlocks", "inProgress", "archived"]))?)?;
            find_task(id)
        }
        "set_task_done" => {
            let id = args["id"].as_str().ok_or("A task id is required.")?;
            let want = args["done"].as_bool().ok_or("done is required.")?;
            if find_task(id)?["done"].as_bool() != Some(want) {
                core("tasks.toggle", json!({"id": id}))?;
            }
            find_task(id)
        }
        "delete_task" => {
            find_task(args["id"].as_str().ok_or("A task id is required.")?)?;
            core("tasks.delete", pick(&["id"]))?;
            Ok(json!({"deleted": args["id"]}))
        }
        "timer_status" => core("tick", json!({})),
        "start_focus" => {
            if args.get("taskId").is_some() {
                core("timer.assignTask", pick(&["taskId"]))?;
            }
            let state = core("tick", json!({}))?;
            if state["running"] == true {
                return Ok(state);
            }
            // A fresh interval takes the intention; a paused one resumes where it stopped.
            if state["remainingMs"] == state["totalMs"] {
                core("timer.start", pick(&["intention"]))
            } else {
                core("timer.resume", json!({}))
            }
        }
        "pause_timer" => core("timer.pause", json!({})),
        "day_plan" => core("plan.build", pick(&["targetMinutes"])),
        "list_sessions" => {
            let limit = args["limit"].as_u64().unwrap_or(20) as usize;
            let sessions = core("sessions.list", json!({}))?;
            let all = sessions.as_array().cloned().unwrap_or_default();
            Ok(json!(all[all.len().saturating_sub(limit)..]))
        }
        _ => Err(format!("Unknown tool: {name}")),
    }
}

fn handle(request: &Value) -> Option<Value> {
    let id = request.get("id")?.clone(); // notifications get no reply
    let result = match request["method"].as_str().unwrap_or("") {
        "initialize" => json!({
            "protocolVersion": request["params"]["protocolVersion"].as_str().unwrap_or(PROTOCOL_VERSION),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "cadence", "version": env!("CARGO_PKG_VERSION")},
            "instructions": "Manage tasks and the Pomodoro timer in the Cadence macOS app. Use list_tasks to get task ids."
        }),
        "ping" => json!({}),
        "tools/list" => json!({"tools": tools()}),
        "tools/call" => {
            let params = &request["params"];
            let name = params["name"].as_str().unwrap_or("");
            let args = params.get("arguments").cloned().unwrap_or(json!({}));
            let (text, is_error) = match call_tool(name, &args) {
                Ok(value) => (serde_json::to_string_pretty(&value).unwrap_or_default(), false),
                Err(error) => (error, true),
            };
            json!({"content": [{"type": "text", "text": text}], "isError": is_error})
        }
        method => {
            return Some(json!({"jsonrpc": "2.0", "id": id,
                "error": {"code": -32601, "message": format!("Method not found: {method}")}}))
        }
    };
    Some(json!({"jsonrpc": "2.0", "id": id, "result": result}))
}

fn state_path() -> String {
    std::env::var("CADENCE_STATE").unwrap_or_else(|_| {
        let home = std::env::var("HOME").unwrap_or_default();
        format!("{home}/Library/Application Support/Cadence/core-state.json")
    })
}

#[cfg(all(test, target_os = "macos"))] // parse_due shells out to macOS /bin/date
mod tests {
    use super::*;

    #[test]
    fn due_times_parse_in_every_accepted_shape() {
        assert_eq!(parse_due("2026-11-14T15:30Z").unwrap(), 1_794_670_200_000);
        assert_eq!(parse_due("2026-11-14T16:30:00+01:00").unwrap(), 1_794_670_200_000);
        assert_eq!(parse_due("2026-11-14T10:30-05:00").unwrap(), 1_794_670_200_000);
        let local = parse_due("2026-11-14 15:30").unwrap();
        assert_eq!(local_time(local / 1000)[..16], *"2026-11-14T15:30");
        assert_eq!(local_time(parse_due("2026-11-14").unwrap() / 1000)[..16], *"2026-11-14T23:59");
        for bad in ["tomorrow", "2026-02-30T10:00", "2026-11-14T25:00", "14/11/2026"] {
            assert!(parse_due(bad).is_err(), "{bad}");
        }
    }
}

fn main() {
    if let Err(error) = core("initialize", json!({"storagePath": state_path()})) {
        eprintln!("[cadence-mcp] {error}");
    }
    let stdout = io::stdout();
    for line in io::stdin().lock().lines() {
        let Ok(line) = line else { break };
        if line.trim().is_empty() {
            continue;
        }
        let reply = match serde_json::from_str::<Value>(&line) {
            Ok(request) => handle(&request),
            Err(error) => Some(json!({"jsonrpc": "2.0", "id": null,
                "error": {"code": -32700, "message": error.to_string()}})),
        };
        if let Some(reply) = reply {
            let mut out = stdout.lock();
            let _ = writeln!(out, "{reply}");
            let _ = out.flush();
        }
    }
}
