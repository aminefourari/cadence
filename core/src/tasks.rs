use serde::{Deserialize, Serialize};

use crate::timer::PomodoroConfig;

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum Priority {
    // Aliases migrate the old Eisenhower quadrants stored before priorities existed.
    #[serde(alias = "urgent_important")]
    High,
    #[default]
    #[serde(alias = "important_not_urgent", alias = "urgent_not_important")]
    Medium,
    #[serde(alias = "neither")]
    Low,
}

impl Priority {
    pub fn rank(self) -> u8 {
        match self {
            Priority::High => 0,
            Priority::Medium => 1,
            Priority::Low => 2,
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase", default)]
pub struct Task {
    pub id: String,
    pub title: String,
    #[serde(alias = "quadrant")]
    pub priority: Priority,
    pub estimate_blocks: u32,
    pub completed_blocks: u32,
    pub focused_minutes: u32,
    pub done: bool,
    pub created_at_ms: u64,
    pub completed_at_ms: Option<u64>,
    pub completed_day: Option<String>,
    pub last_focused_at_ms: Option<u64>,
    /// Board column: To Do (false) or In Progress (true). Done is `done`.
    pub in_progress: bool,
    pub archived: bool,
    /// Manual order on the board; lower first.
    pub position: i64,
}

impl Default for Task {
    fn default() -> Self {
        Self {
            id: String::new(),
            title: String::new(),
            priority: Priority::Medium,
            estimate_blocks: 1,
            completed_blocks: 0,
            focused_minutes: 0,
            done: false,
            created_at_ms: 0,
            completed_at_ms: None,
            completed_day: None,
            last_focused_at_ms: None,
            in_progress: false,
            archived: false,
            position: 0,
        }
    }
}

impl Task {
    pub fn remaining_blocks(&self) -> u32 {
        self.estimate_blocks.saturating_sub(self.completed_blocks)
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
#[serde(rename_all = "camelCase", default)]
pub struct FocusSession {
    pub id: String,
    pub task_id: Option<String>,
    pub task_title: Option<String>,
    #[serde(alias = "quadrant")]
    pub priority: Option<Priority>,
    pub intention: Option<String>,
    pub minutes: u32,
    pub completed_at_ms: u64,
    pub day: String,
}

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct PlanBlock {
    pub id: String,
    pub kind: String,
    pub task_id: Option<String>,
    pub task_title: Option<String>,
    pub priority: Option<Priority>,
    pub start_at_ms: u64,
    pub end_at_ms: u64,
    pub minutes: u32,
}

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct DayPlan {
    pub blocks: Vec<PlanBlock>,
    pub focus_minutes: u32,
    pub target_minutes: u32,
    pub start_at_ms: u64,
    pub end_at_ms: u64,
}

pub fn ordered_tasks(tasks: &[Task]) -> Vec<Task> {
    let mut ordered = tasks.to_vec();
    ordered.sort_by_key(|task| (task.done, task.priority.rank(), task.position, task.created_at_ms));
    ordered
}

pub fn build_plan(
    tasks: &[Task],
    config: &PomodoroConfig,
    now_ms: u64,
    target_minutes: u32,
    buffer_minutes: u32,
) -> DayPlan {
    let step_ms = 5 * 60_000u64;
    let mut cursor = if now_ms % step_ms == 0 {
        now_ms
    } else {
        (now_ms / step_ms + 1) * step_ms
    };
    let plan_start = cursor;
    let target_minutes = target_minutes.min(24 * 60);
    let buffer_ms = buffer_minutes.min(60) as u64 * 60_000;

    let mut ordered = ordered_tasks(tasks)
        .into_iter()
        .filter(|task| !task.done && !task.archived && task.remaining_blocks() > 0)
        .collect::<Vec<_>>();
    ordered.sort_by_key(|task| {
        (task.priority.rank(), !task.in_progress, task.position, task.created_at_ms)
    });

    let total_blocks = ordered
        .iter()
        .map(|task| task.remaining_blocks() as u64)
        .sum::<u64>();
    let mut scheduled_blocks = 0u64;
    let mut focus_minutes = 0u32;
    let mut blocks: Vec<PlanBlock> = Vec::new();
    let mut break_index = 0u32;
    let focus_length = config.focus_minutes.max(1) as u64;

    'tasks: for task in &ordered {
        for _ in 0..task.remaining_blocks() {
            if focus_minutes > 0 && focus_minutes + config.focus_minutes > target_minutes {
                break 'tasks;
            }

            let focus_start = cursor;
            let focus_end = focus_start + focus_length * 60_000;
            blocks.push(PlanBlock {
                id: format!("focus-{}", blocks.len() + 1),
                kind: "focus".into(),
                task_id: Some(task.id.clone()),
                task_title: Some(task.title.clone()),
                priority: Some(task.priority),
                start_at_ms: focus_start,
                end_at_ms: focus_end,
                minutes: config.focus_minutes,
            });
            cursor = focus_end;
            focus_minutes = focus_minutes.saturating_add(config.focus_minutes);
            scheduled_blocks += 1;
            break_index += 1;

            if focus_minutes >= target_minutes || scheduled_blocks >= total_blocks {
                break 'tasks;
            }

            cursor = cursor.saturating_add(buffer_ms);
            let (kind, minutes) = if break_index % config.sessions_before_long_break.max(1) == 0 {
                ("long_break", config.long_break_minutes)
            } else {
                ("short_break", config.short_break_minutes)
            };
            let break_start = cursor;
            let break_end = break_start + minutes as u64 * 60_000;
            blocks.push(PlanBlock {
                id: format!("break-{}", blocks.len() + 1),
                kind: kind.into(),
                task_id: None,
                task_title: None,
                priority: None,
                start_at_ms: break_start,
                end_at_ms: break_end,
                minutes,
            });
            cursor = break_end;
        }
    }

    DayPlan {
        blocks,
        focus_minutes,
        target_minutes,
        start_at_ms: plan_start,
        end_at_ms: cursor,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn task(id: &str, blocks: u32, priority: Priority) -> Task {
        Task {
            id: id.into(),
            title: format!("Task {id}"),
            priority,
            estimate_blocks: blocks,
            created_at_ms: 1,
            ..Task::default()
        }
    }

    #[test]
    fn plan_prioritizes_high_priority_and_adds_breaks() {
        let tasks = vec![
            task("later", 2, Priority::Low),
            task("now", 2, Priority::High),
        ];
        let config = PomodoroConfig::default();
        let plan = build_plan(&tasks, &config, 0, 100, 5);
        assert_eq!(plan.blocks[0].task_id.as_deref(), Some("now"));
        assert_eq!(plan.blocks[0].kind, "focus");
        assert_eq!(plan.blocks[1].kind, "short_break");
        assert!(plan.blocks[1].start_at_ms > plan.blocks[0].end_at_ms);
    }

    #[test]
    fn long_break_after_four_focus_blocks() {
        let tasks = vec![task("deep", 5, Priority::High)];
        let config = PomodoroConfig::default();
        let plan = build_plan(&tasks, &config, 0, 180, 0);
        let kinds: Vec<&str> = plan
            .blocks
            .iter()
            .map(|block| block.kind.as_str())
            .collect();
        assert!(kinds.contains(&"long_break"));
    }

    #[test]
    fn plan_skips_archived_tasks() {
        let mut archived = task("archived", 2, Priority::High);
        archived.archived = true;
        let tasks = vec![archived, task("kept", 1, Priority::Low)];
        let plan = build_plan(&tasks, &PomodoroConfig::default(), 0, 100, 5);
        assert!(plan.blocks.iter().all(|block| block.task_id.as_deref() != Some("archived")));
    }

    #[test]
    fn legacy_quadrant_migrates_to_priority() {
        let task: Task = serde_json::from_str(r#"{"id":"a","quadrant":"urgent_important"}"#).unwrap();
        assert_eq!(task.priority, Priority::High);
        let task: Task = serde_json::from_str(r#"{"id":"b","quadrant":"neither"}"#).unwrap();
        assert_eq!(task.priority, Priority::Low);
        let session: FocusSession =
            serde_json::from_str(r#"{"id":"s","quadrant":"urgent_not_important"}"#).unwrap();
        assert_eq!(session.priority, Some(Priority::Medium));
    }
}
