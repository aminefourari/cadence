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
    let estimate = json!({"type": "integer", "minimum": 1, "maximum": 24,
        "description": "Estimated focus blocks (Pomodoros)."});
    json!([
        {"name": "list_tasks", "description": "List tasks on the Cadence board (open first, then by priority). Archived tasks are hidden unless includeArchived.",
         "inputSchema": {"type": "object", "properties": {"includeArchived": {"type": "boolean"}, "includeDone": {"type": "boolean", "description": "Default true."}}}},
        {"name": "add_task", "description": "Add a task to the Cadence board.",
         "inputSchema": {"type": "object", "required": ["title"], "properties": {
            "title": {"type": "string"}, "priority": priority, "estimateBlocks": estimate,
            "inProgress": {"type": "boolean", "description": "Put it in the In Progress column."}}}},
        {"name": "update_task", "description": "Edit a task: title, priority, estimate, column (inProgress) or archived.",
         "inputSchema": {"type": "object", "required": ["id"], "properties": {
            "id": id, "title": {"type": "string"}, "priority": priority, "estimateBlocks": estimate,
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

fn find_task(id: &str) -> Result<Value, String> {
    core("tasks.list", json!({}))?
        .as_array()
        .and_then(|tasks| tasks.iter().find(|task| task["id"] == id).cloned())
        .ok_or_else(|| "Task not found.".to_string())
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
            let tasks = core("tasks.list", json!({}))?;
            Ok(json!(tasks
                .as_array()
                .into_iter()
                .flatten()
                .filter(|task| (archived || task["archived"] != true) && (done || task["done"] != true))
                .collect::<Vec<_>>()))
        }
        "add_task" => {
            let before = core("tasks.list", json!({}))?;
            let after = core("tasks.add", pick(&["title", "priority", "estimateBlocks", "inProgress"]))?;
            let known: Vec<&Value> = before.as_array().into_iter().flatten().map(|task| &task["id"]).collect();
            after
                .as_array()
                .and_then(|tasks| tasks.iter().find(|task| !known.contains(&&task["id"])).cloned())
                .ok_or_else(|| "Task was not added.".to_string())
        }
        "update_task" => {
            let id = args["id"].as_str().ok_or("A task id is required.")?;
            core("tasks.update", pick(&["id", "title", "priority", "estimateBlocks", "inProgress", "archived"]))?;
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
