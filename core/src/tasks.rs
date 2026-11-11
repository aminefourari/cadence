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
    /// Optional deadline (date and time), epoch milliseconds.
    pub due_at_ms: Option<u64>,
    /// Time estimate when given in minutes; `estimate_blocks` is derived from it
    /// and re-derived when the focus length changes.
    pub estimate_minutes: Option<u32>,
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
            due_at_ms: None,
            estimate_minutes: None,
        }
    }
}

/// Focus blocks needed for `minutes` of work, rounded up, 1–24.
pub fn blocks_for(minutes: u32, focus_minutes: u32) -> u32 {
    minutes.div_ceil(focus_minutes.max(1)).clamp(1, 24)
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
    /// A focus block that ends after its task's deadline.
    pub late: bool,
}

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct DayPlan {
    pub blocks: Vec<PlanBlock>,
    /// Minutes planned from here on.
    pub focus_minutes: u32,
    /// Focus already done today (including a running block), counted toward the target.
    pub done_minutes: u32,
    pub target_minutes: u32,
    pub start_at_ms: u64,
    pub end_at_ms: u64,
}

/// Where the plan picks up from the timer.
#[derive(Clone, Debug, Default)]
pub struct PlanStart {
    /// Now, or the end of the running interval.
    pub at_ms: u64,
    pub done_minutes: u32,
    /// Focus blocks finished in the current cycle (decides short vs long breaks).
    pub completed_in_cycle: u32,
    /// The plan starts right after a focus block, so it opens with a break.
    pub after_focus: bool,
    /// Task of the running focus block; that block is already under way.
    pub running_task_id: Option<String>,
}

pub fn ordered_tasks(tasks: &[Task]) -> Vec<Task> {
    let mut ordered = tasks.to_vec();
    ordered.sort_by_key(|task| (task.done, task.priority.rank(), task.position, task.created_at_ms));
    ordered
}

/// Time-boxes open tasks into focus blocks and breaks until the day's target is met.
/// Order: earliest deadline first, then undated tasks by priority.
pub fn build_plan(
    tasks: &[Task],
    config: &PomodoroConfig,
    start: &PlanStart,
    target_minutes: u32,
    buffer_minutes: u32,
) -> DayPlan {
    let step_ms = 5 * 60_000u64;
    let mut cursor = start.at_ms.div_ceil(step_ms) * step_ms;
    let plan_start = cursor;
    let target_minutes = target_minutes.min(24 * 60);
    let budget = target_minutes.saturating_sub(start.done_minutes);
    let buffer_ms = buffer_minutes.min(60) as u64 * 60_000;
    let focus_minutes_each = config.focus_minutes.max(1);

    let mut ordered = tasks
        .iter()
        .filter(|task| !task.done && !task.archived)
        .collect::<Vec<_>>();
    ordered.sort_by_key(|task| {
        (
            task.due_at_ms.is_none(),
            task.due_at_ms.unwrap_or(u64::MAX),
            task.priority.rank(),
            !task.in_progress,
            task.position,
            task.created_at_ms,
        )
    });
    let slots = ordered.into_iter().flat_map(|task| {
        let mut remaining = task.remaining_blocks();
        if start.running_task_id.as_ref() == Some(&task.id) {
            remaining = remaining.saturating_sub(1);
        }
        std::iter::repeat_n(task, remaining as usize)
    });

    let mut blocks: Vec<PlanBlock> = Vec::new();
    let mut planned = 0u32;
    let mut cycle = start.completed_in_cycle;
    let mut needs_break = start.after_focus;
    for task in slots {
        if planned + focus_minutes_each > budget {
            break;
        }
        if needs_break {
            cursor += buffer_ms;
            let (kind, minutes) = if cycle > 0 && cycle % config.sessions_before_long_break.max(1) == 0 {
                ("long_break", config.long_break_minutes)
            } else {
                ("short_break", config.short_break_minutes)
            };
            let end = cursor + minutes as u64 * 60_000;
            blocks.push(PlanBlock {
                id: format!("break-{}", blocks.len() + 1),
                kind: kind.into(),
                task_id: None,
                task_title: None,
                priority: None,
                start_at_ms: cursor,
                end_at_ms: end,
                minutes,
                late: false,
            });
            cursor = end;
        }
        let end = cursor + focus_minutes_each as u64 * 60_000;
        blocks.push(PlanBlock {
            id: format!("focus-{}", blocks.len() + 1),
            kind: "focus".into(),
            task_id: Some(task.id.clone()),
            task_title: Some(task.title.clone()),
            priority: Some(task.priority),
            start_at_ms: cursor,
            end_at_ms: end,
            minutes: focus_minutes_each,
            late: task.due_at_ms.is_some_and(|due| end > due),
        });
        cursor = end;
        planned += focus_minutes_each;
        cycle += 1;
        needs_break = true;
    }

    DayPlan {
        blocks,
        focus_minutes: planned,
        done_minutes: start.done_minutes,
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
        let plan = build_plan(&tasks, &config, &PlanStart::default(), 100, 5);
        assert_eq!(plan.blocks[0].task_id.as_deref(), Some("now"));
        assert_eq!(plan.blocks[0].kind, "focus");
        assert_eq!(plan.blocks[1].kind, "short_break");
        assert!(plan.blocks[1].start_at_ms > plan.blocks[0].end_at_ms);
    }

    #[test]
    fn long_break_after_four_focus_blocks() {
        let tasks = vec![task("deep", 5, Priority::High)];
        let config = PomodoroConfig::default();
        let plan = build_plan(&tasks, &config, &PlanStart::default(), 180, 0);
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
        let plan = build_plan(&tasks, &PomodoroConfig::default(), &PlanStart::default(), 100, 5);
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

    const MIN: u64 = 60_000;

    #[test]
    fn deadlines_come_first_and_misses_are_flagged() {
        let mut later = task("later", 1, Priority::High);
        later.due_at_ms = Some(600 * MIN);
        let mut soon = task("soon", 2, Priority::Low);
        soon.due_at_ms = Some(40 * MIN);
        let undated = task("undated", 1, Priority::High);
        let tasks = vec![undated, later, soon];
        let plan = build_plan(&tasks, &PomodoroConfig::default(), &PlanStart::default(), 600, 0);
        let order: Vec<_> = plan.blocks.iter().filter_map(|b| b.task_id.as_deref()).collect();
        assert_eq!(order, ["soon", "soon", "later", "undated"]);
        // soon: 0–25 on time, second block 30–55 ends after its 40-minute deadline.
        assert!(!plan.blocks[0].late);
        assert!(plan.blocks[2].late);
    }

    #[test]
    fn never_ends_on_a_break_and_counts_focus_already_done() {
        let tasks = vec![task("a", 10, Priority::High)];
        let start = PlanStart { done_minutes: 50, ..PlanStart::default() };
        let plan = build_plan(&tasks, &PomodoroConfig::default(), &start, 120, 5);
        assert_eq!(plan.focus_minutes, 50, "120 target - 50 done leaves room for 2 blocks");
        assert_eq!(plan.blocks.last().unwrap().kind, "focus");
        assert_eq!(plan.blocks.len(), 3);
    }

    #[test]
    fn a_running_block_is_not_planned_twice() {
        let tasks = vec![task("a", 2, Priority::High)];
        let start = PlanStart {
            at_ms: 20 * MIN,
            after_focus: true,
            completed_in_cycle: 4,
            running_task_id: Some("a".into()),
            ..PlanStart::default()
        };
        let plan = build_plan(&tasks, &PomodoroConfig::default(), &start, 600, 0);
        let kinds: Vec<_> = plan.blocks.iter().map(|b| b.kind.as_str()).collect();
        assert_eq!(kinds, ["long_break", "focus"], "opens with the break after the running 4th block");
        assert_eq!(plan.blocks[0].start_at_ms, 20 * MIN);
    }
}
