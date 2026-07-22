# Story 1.3: Hero action-state machine + action timing windows

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want every melee action to be a transition in one explicit table driven by integer-tick timing windows,
so that combat is deterministic, headless-testable, and the presentation layer learns what the hero is doing through a single queued signal.

## Acceptance Criteria

1. `ActionState { IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING }` lives on `HeroState` as a pure enum plus an explicit transition table evaluated in `advance()` step 3 from `InputIntent` + active `TimingWindow`s. `CHARGING` is reserved for E5 and is unreachable in E1 — the transition is absent, not stubbed as a fake path.
2. `HeroState` owns its per-action windows as `TimingWindow` instances (windup, active, recovery, chain window, block/deflect window, roll i-frame, roll duration, stun), all advanced in `advance()` step 2, one tick per call, **before** any transition is evaluated. The order (timers advance first, transitions read the result) is written down in the file.
3. Cancellability is data on the transition table, not scattered `if`s: which states accept a new attack, roll, block, or nothing. E1 convention: recovery is roll-cancellable, active frames are not, `STUNNED` accepts no input. Any deviation is a playtest decision; the table stays one readable block.
4. Every transition emits a queued `action_state_changed(previous, current)` pushed to the `SignalQueue` (never emitted mid-tick). This is the single hook the presentation layer (1.10) and HUD (E2) subscribe to.
5. Headless tests drive fixed intent sequences over N ticks: each action reaches and leaves its states on the exact expected tick; inputs during a non-cancellable window are dropped rather than buffered; the emitted signal sequence (after `drain_signals()`) matches the expected list.

## Tasks / Subtasks

- [ ] Implement `ActionState` enum + transition table on `HeroState` (AC: 1, 3)
  - [ ] Leave `CHARGING` transition absent (E5); express cancellability as table data
- [ ] Own the per-action `TimingWindow`s; advance them in step 2 before transitions (AC: 2)
  - [ ] Comment the timers-first / transitions-read order in the file
- [ ] Emit queued `action_state_changed(previous, current)` on every transition (AC: 4)
- [ ] Headless tests (AC: 5)
  - [ ] Exact-tick entry/exit; non-cancellable inputs dropped; signal sequence matches

## Dev Notes

- Pure enum + transition table chosen over a scene `StateMachine` (scene-coupled, `_process`-driven, cannot be tested headless — would violate D1/X6). [Source: docs/game-architecture.md#Hero Action-State Representation]
- Timers advance in `advance()` step 2; transitions resolve in step 3 reading the advanced result. Never flip this order. [Source: docs/game-architecture.md#D2]
- `action_state_changed` is the **only** channel telling visuals what the hero is doing — no other code path may. [Source: stories-manual-e1.md#E1.S3 item 4]

### Project Structure Notes

- `src/state/hero_state.gd` (enum + table), windows via `src/state/timing/timing_window.gd`, signals via the shared `SignalQueue`.

### Project Context Rules

- **Queued signals (D5):** enqueue during `advance()`, drain after; no state-to-state signals. [Source: docs/project-context.md#Signals over polling]
- **Entity state** is a pure enum + transitions in the state layer, never a scene `StateMachine`. [Source: docs/game-architecture.md#Standard Patterns]

### References

- [Source: stories-manual-e1.md#E1.S3]
- [Source: docs/game-architecture.md#Hero Action-State Representation; #D2; #D4]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
