use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Phase {
    Focus,
    ShortBreak,
    LongBreak,
}

impl Phase {
    pub fn duration_ms(self, config: &PomodoroConfig) -> u64 {
        let minutes = match self {
            Phase::Focus => config.focus_minutes,
            Phase::ShortBreak => config.short_break_minutes,
            Phase::LongBreak => config.long_break_minutes,
        };
        minutes as u64 * 60_000
    }
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase", default)]
pub struct PomodoroConfig {
    pub focus_minutes: u32,
    pub short_break_minutes: u32,
    pub long_break_minutes: u32,
    pub sessions_before_long_break: u32,
    pub auto_start_next: bool,
}

impl Default for PomodoroConfig {
    fn default() -> Self {
        Self {
            focus_minutes: 25,
            short_break_minutes: 5,
            long_break_minutes: 15,
            sessions_before_long_break: 4,
            auto_start_next: false,
        }
    }
}

impl PomodoroConfig {
    pub fn normalized(mut self) -> Self {
        self.focus_minutes = self.focus_minutes.clamp(1, 180);
        self.short_break_minutes = self.short_break_minutes.clamp(1, 60);
        self.long_break_minutes = self.long_break_minutes.clamp(1, 120);
        self.sessions_before_long_break = self.sessions_before_long_break.clamp(1, 12);
        self
    }
}

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct TimerTransition {
    pub id: u64,
    pub completed_phase: Phase,
    pub next_phase: Phase,
    pub skipped: bool,
    pub auto_started: bool,
    pub focus_minutes_added: u32,
}

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct TimerState {
    pub phase: Phase,
    pub running: bool,
    pub remaining_ms: u64,
    pub total_ms: u64,
    pub ends_at_ms: Option<u64>,
    pub completed_in_cycle: u32,
    pub cycle_length: u32,
    pub today_focus_minutes: u32,
    pub today_sessions: u32,
    pub total_sessions: u64,
    pub config: PomodoroConfig,
    pub active_task_id: Option<String>,
    pub intention: Option<String>,
    pub transition: Option<TimerTransition>,
}

/// The live part of the engine that must survive an app relaunch.
#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct EngineSnapshot {
    pub phase: Phase,
    pub running: bool,
    pub remaining_ms: u64,
    pub ends_at_ms: Option<u64>,
    pub completed_in_cycle: u32,
    pub intention: Option<String>,
    #[serde(default)]
    pub length_override_ms: Option<u64>,
}

pub fn to_value(state: TimerState) -> Value {
    serde_json::to_value(state).expect("timer state serializes")
}

pub struct PomodoroEngine {
    config: PomodoroConfig,
    phase: Phase,
    running: bool,
    remaining_ms: u64,
    ends_at_ms: Option<u64>,
    completed_in_cycle: u32,
    transition_counter: u64,
    last_transition: Option<TimerTransition>,
    active_task_id: Option<String>,
    intention: Option<String>,
    /// One-off length for the current interval; cleared when the interval ends.
    length_override_ms: Option<u64>,
}

impl PomodoroEngine {
    pub fn new(config: PomodoroConfig) -> Self {
        let config = config.normalized();
        let remaining_ms = config.focus_minutes as u64 * 60_000;
        Self {
            config,
            phase: Phase::Focus,
            running: false,
            remaining_ms,
            ends_at_ms: None,
            completed_in_cycle: 0,
            transition_counter: 0,
            last_transition: None,
            active_task_id: None,
            intention: None,
            length_override_ms: None,
        }
    }

    /// Length of the current interval: the one-off override, or the configured phase length.
    fn total_ms(&self) -> u64 {
        self.length_override_ms
            .unwrap_or_else(|| self.phase.duration_ms(&self.config))
    }

    /// Sets a one-off length for the current interval (e.g. 20 min instead of 25).
    /// Only while the timer is stopped; the interval restarts at the new length.
    /// The next interval uses the configured length again.
    pub fn set_length(&mut self, minutes: u32) {
        if self.running {
            return;
        }
        let length_ms = minutes.clamp(1, 180) as u64 * 60_000;
        self.length_override_ms =
            (length_ms != self.phase.duration_ms(&self.config)).then_some(length_ms);
        self.remaining_ms = length_ms;
        self.ends_at_ms = None;
    }

    pub fn last_transition(&self) -> Option<&TimerTransition> {
        self.last_transition.as_ref()
    }

    pub fn config(&self) -> &PomodoroConfig {
        &self.config
    }

    pub fn snapshot(&self) -> EngineSnapshot {
        EngineSnapshot {
            phase: self.phase,
            running: self.running,
            remaining_ms: self.remaining_ms,
            ends_at_ms: self.ends_at_ms,
            completed_in_cycle: self.completed_in_cycle,
            intention: self.intention.clone(),
            length_override_ms: self.length_override_ms,
        }
    }

    /// Restores a saved snapshot. A running interval whose end passed while the
    /// app was closed completes on the next `tick`.
    pub fn restore(&mut self, snapshot: EngineSnapshot) {
        self.phase = snapshot.phase;
        self.length_override_ms = snapshot.length_override_ms.map(|ms| ms.clamp(60_000, 180 * 60_000));
        let total = self.total_ms();
        self.remaining_ms = snapshot.remaining_ms.min(total);
        self.completed_in_cycle = snapshot
            .completed_in_cycle
            .min(self.config.sessions_before_long_break.saturating_sub(1));
        self.intention = snapshot.intention;
        self.ends_at_ms = snapshot.ends_at_ms.filter(|_| snapshot.running);
        self.running = self.ends_at_ms.is_some();
    }

    pub fn start(&mut self, now_ms: u64) {
        self.start_with_intention(now_ms, None);
    }

    pub fn start_with_intention(&mut self, now_ms: u64, intention: Option<String>) {
        if self.running {
            return;
        }
        let is_fresh = self.remaining_ms == self.total_ms();
        if self.phase == Phase::Focus && is_fresh {
            self.intention = intention.and_then(|value| {
                let trimmed = value.trim();
                (!trimmed.is_empty()).then(|| trimmed.to_string())
            });
        } else if self.phase != Phase::Focus {
            self.intention = None;
        }
        if self.remaining_ms == 0 {
            self.remaining_ms = self.total_ms();
        }
        self.running = true;
        self.ends_at_ms = Some(now_ms.saturating_add(self.remaining_ms));
    }

    pub fn set_active_task(&mut self, task_id: Option<String>) {
        self.active_task_id = task_id;
    }

    pub fn active_task_id(&self) -> Option<&String> {
        self.active_task_id.as_ref()
    }

    pub fn intention(&self) -> Option<&String> {
        self.intention.as_ref()
    }

    pub fn pause(&mut self, now_ms: u64) {
        if !self.running {
            return;
        }
        self.remaining_ms = self.remaining_at(now_ms);
        self.running = false;
        self.ends_at_ms = None;
    }

    pub fn toggle(&mut self, now_ms: u64) {
        if self.running {
            self.pause(now_ms);
        } else {
            self.start(now_ms);
        }
    }

    pub fn reset(&mut self) {
        self.running = false;
        self.ends_at_ms = None;
        self.length_override_ms = None;
        self.remaining_ms = self.phase.duration_ms(&self.config);
        self.intention = None;
    }

    pub fn select_phase(&mut self, phase: Phase) {
        self.phase = phase;
        self.running = false;
        self.ends_at_ms = None;
        self.length_override_ms = None;
        self.remaining_ms = phase.duration_ms(&self.config);
        self.intention = None;
    }

    pub fn configure(&mut self, config: PomodoroConfig) {
        self.config = config.normalized();
        self.completed_in_cycle = self
            .completed_in_cycle
            .min(self.config.sessions_before_long_break.saturating_sub(1));
        self.running = false;
        self.ends_at_ms = None;
        self.length_override_ms = None;
        self.remaining_ms = self.phase.duration_ms(&self.config);
        self.intention = None;
    }

    pub fn skip(&mut self, now_ms: u64, stats: &mut crate::storage::Stats) {
        self.complete_phase(now_ms, stats, true);
    }

    pub fn tick(&mut self, now_ms: u64, stats: &mut crate::storage::Stats) -> bool {
        if !self.running {
            return false;
        }
        let Some(end) = self.ends_at_ms else {
            return false;
        };
        if now_ms < end {
            return false;
        }
        self.complete_phase(now_ms, stats, false);
        true
    }

    pub fn state(&self, now_ms: u64, stats: &crate::storage::Stats) -> TimerState {
        let total_ms = self.total_ms();
        let remaining_ms = if self.running {
            self.remaining_at(now_ms)
        } else {
            self.remaining_ms
        };
        TimerState {
            phase: self.phase,
            running: self.running,
            remaining_ms,
            total_ms,
            ends_at_ms: self.ends_at_ms,
            completed_in_cycle: self.completed_in_cycle,
            cycle_length: self.config.sessions_before_long_break,
            today_focus_minutes: stats.today_focus_minutes,
            today_sessions: stats.today_sessions,
            total_sessions: stats.total_sessions,
            config: self.config.clone(),
            active_task_id: self.active_task_id.clone(),
            intention: self.intention.clone(),
            transition: self.last_transition.clone(),
        }
    }

    fn remaining_at(&self, now_ms: u64) -> u64 {
        self.ends_at_ms
            .map(|end| end.saturating_sub(now_ms))
            .unwrap_or(self.remaining_ms)
    }

    fn complete_phase(&mut self, now_ms: u64, stats: &mut crate::storage::Stats, skipped: bool) {
        let completed_phase = self.phase;
        let mut focus_minutes_added = 0;

        let next_phase = if skipped {
            match completed_phase {
                Phase::Focus => Phase::ShortBreak,
                Phase::ShortBreak | Phase::LongBreak => Phase::Focus,
            }
        } else if completed_phase == Phase::Focus {
            let minutes = ((self.total_ms() + 30_000) / 60_000) as u32;
            stats.record_focus(minutes);
            focus_minutes_added = minutes;
            self.completed_in_cycle = self.completed_in_cycle.saturating_add(1);
            if self.completed_in_cycle >= self.config.sessions_before_long_break {
                self.completed_in_cycle = 0;
                Phase::LongBreak
            } else {
                Phase::ShortBreak
            }
        } else {
            Phase::Focus
        };

        let auto_started = !skipped && self.config.auto_start_next;
        self.transition_counter = self.transition_counter.saturating_add(1);
        self.last_transition = Some(TimerTransition {
            id: self.transition_counter,
            completed_phase,
            next_phase,
            skipped,
            auto_started,
            focus_minutes_added,
        });

        self.phase = next_phase;
        self.length_override_ms = None;
        self.remaining_ms = next_phase.duration_ms(&self.config);
        self.running = auto_started;
        self.ends_at_ms = if auto_started {
            Some(now_ms.saturating_add(self.remaining_ms))
        } else {
            None
        };
        self.intention = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::Stats;

    fn stats() -> Stats {
        Stats {
            day: "2026-10-26".into(),
            ..Stats::default()
        }
    }

    #[test]
    fn starts_paused_at_full_focus_duration() {
        let engine = PomodoroEngine::new(PomodoroConfig::default());
        let state = engine.state(1_000, &stats());
        assert_eq!(state.phase, Phase::Focus);
        assert!(!state.running);
        assert_eq!(state.remaining_ms, 25 * 60_000);
    }

    #[test]
    fn focus_completion_advances_to_short_break_and_records_stats() {
        let mut engine = PomodoroEngine::new(PomodoroConfig::default());
        let mut stats = stats();
        engine.start(1_000);
        let finished = engine.tick(1_000 + 25 * 60_000, &mut stats);
        let state = engine.state(1_000 + 25 * 60_000, &stats);
        assert!(finished);
        assert_eq!(state.phase, Phase::ShortBreak);
        assert!(!state.running);
        assert_eq!(state.completed_in_cycle, 1);
        assert_eq!(stats.today_sessions, 1);
        assert_eq!(stats.today_focus_minutes, 25);
        assert_eq!(
            state.transition.as_ref().unwrap().completed_phase,
            Phase::Focus
        );
    }

    #[test]
    fn four_focus_sessions_trigger_a_long_break() {
        let config = PomodoroConfig {
            auto_start_next: true,
            ..PomodoroConfig::default()
        };
        let mut engine = PomodoroEngine::new(config);
        let mut stats = stats();
        let mut now = 0;
        for _ in 0..4 {
            engine.start(now);
            now += 25 * 60_000;
            engine.tick(now, &mut stats);
            if engine.state(now, &stats).phase == Phase::LongBreak {
                break;
            }
            engine.skip(now, &mut stats);
        }
        let state = engine.state(now, &stats);
        assert_eq!(state.phase, Phase::LongBreak);
        assert_eq!(stats.today_sessions, 4);
        assert_eq!(state.completed_in_cycle, 0);
    }

    #[test]
    fn skipped_focus_does_not_count_a_session() {
        let mut engine = PomodoroEngine::new(PomodoroConfig::default());
        let mut stats = stats();
        engine.skip(10, &mut stats);
        assert_eq!(stats.today_sessions, 0);
        assert_eq!(engine.state(10, &stats).phase, Phase::ShortBreak);
        assert!(engine.state(10, &stats).transition.unwrap().skipped);
    }

    #[test]
    fn snapshot_restores_a_running_interval() {
        let mut engine = PomodoroEngine::new(PomodoroConfig::default());
        let mut stats = stats();
        engine.start_with_intention(0, Some("Ship it".into()));
        let snapshot = engine.snapshot();

        let mut restored = PomodoroEngine::new(PomodoroConfig::default());
        restored.restore(snapshot);
        let state = restored.state(60_000, &stats);
        assert!(state.running);
        assert_eq!(state.remaining_ms, 24 * 60_000);
        assert_eq!(state.intention.as_deref(), Some("Ship it"));
        // The interval ended while the app was closed: next tick completes it.
        assert!(restored.tick(30 * 60_000, &mut stats));
        assert_eq!(stats.today_sessions, 1);
    }

    #[test]
    fn one_off_length_applies_once_and_credits_actual_minutes() {
        let mut engine = PomodoroEngine::new(PomodoroConfig::default());
        let mut stats = stats();
        engine.set_length(20);
        let state = engine.state(0, &stats);
        assert_eq!(state.total_ms, 20 * 60_000);
        assert_eq!(state.remaining_ms, 20 * 60_000);

        engine.start(0);
        engine.set_length(5); // ignored while running
        assert!(engine.tick(20 * 60_000, &mut stats));
        assert_eq!(stats.today_focus_minutes, 20);
        assert_eq!(engine.last_transition().unwrap().focus_minutes_added, 20);

        // Break, then the next focus is back to the configured 25 minutes.
        engine.skip(20 * 60_000, &mut stats);
        assert_eq!(engine.state(0, &stats).total_ms, 25 * 60_000);
    }

    #[test]
    fn pause_freezes_the_remaining_time() {
        let mut engine = PomodoroEngine::new(PomodoroConfig::default());
        engine.start(0);
        engine.pause(60_000);
        let state = engine.state(500_000, &stats());
        assert!(!state.running);
        assert_eq!(state.remaining_ms, 24 * 60_000);
    }
}
