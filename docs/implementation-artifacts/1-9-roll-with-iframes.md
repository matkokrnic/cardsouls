# Story 1.9: Roll with i-frames

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a stamina-costing roll in the camera-relative input direction whose invulnerability is state (the hurtbox stays enabled),
so that i-frames are deterministic and headless-testable and the exact i-frame boundary is asserted on ticks.

## Acceptance Criteria

1. Roll is a transition to `ROLLING` costing stamina, direction taken from the camera-relative `move_dir` at the moment of input (falling back to the hero's facing when the stick is neutral). The roll's motion is written into `HeroState.velocity` in `advance()` step 3 — the actor never applies its own displacement.
2. Invulnerability is **state**, not a disabled node: an i-frame `TimingWindow` sets `HeroState.is_invulnerable`, and `advance()` step 4 **discards contact facts targeting an invulnerable hero. The hurtbox `Area3D` is NOT disabled** — the fact still arrives and state decides, keeping the rule headless-testable.
3. The roll's three phases come from balance: i-frames (a subset of the roll), roll duration, and recovery during which no new action is accepted. The i-frame window may open on a later tick than the roll itself; both windows are independent so the relationship is tunable.
4. The 1.3 cancellability table is enforced: roll may cancel attack recovery, may not cancel active frames, is unavailable while `STUNNED` or below the stamina cost (with `action_rejected`).
5. Headless tests: a contact during i-frames deals zero damage and one tick after i-frames deals full damage; roll direction resolves from `move_dir` and from facing when neutral; roll at insufficient stamina does not fire; roll during active frames is dropped. One integration test proves a roll actually displaces the actor in the intended world direction.

## Tasks / Subtasks

- [ ] Implement `ROLLING` transition + stamina cost; write roll motion into `HeroState.velocity` (AC: 1)
  - [ ] Direction from camera-relative `move_dir`, facing fallback on neutral
- [ ] Implement i-frames as `is_invulnerable` state; discard contact facts in step 4 (AC: 2)
  - [ ] **Do NOT disable the hurtbox `Area3D`** — the fact arrives, state decides
- [ ] Model the three independent balance-authored phases (i-frame / duration / recovery) (AC: 3)
- [ ] Enforce the 1.3 cancellability preconditions (AC: 4)
- [ ] Tests: exact i-frame boundary headless; direction; zero-stamina; drop during active; integration displacement (AC: 5)

## Dev Notes

- **DECISION (c) — roll i-frames are STATE; the hurtbox stays enabled.** Implement invulnerability as an `is_invulnerable` flag whose ticks are set by an i-frame `TimingWindow`; `advance()` step 4 discards contact facts against an invulnerable hero. Do **not** disable the hurtbox `Area3D` — the fact still arrives and state decides, which keeps the rule headless-testable and replay-safe. [Source: stories-manual-e1.md#E1.S9 item 2]
- Roll motion is written to `HeroState.velocity`; the actor consumes it (F1 — actor moves, state decides). [Source: docs/game-architecture.md#Spatial Model, F1]
- i-frame window is a subset of and independent from roll duration, so their relationship is tunable. [Source: stories-manual-e1.md#E1.S9 item 3]

### Project Structure Notes

- `src/state/hero_state.gd` (roll transition, `is_invulnerable`, phase windows); fact discard in `src/state/match_state.gd` step 4; integration displacement test in `test/integration/`.

### Project Context Rules

- **State/visual separation:** invulnerability is a state fact; visuals never gate damage. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **Integer-tick timing** for i-frames. [Source: docs/project-context.md#Deterministic timing]

### References

- [Source: stories-manual-e1.md#E1.S9]
- [Source: gdd.md#Primary Mechanics — Roll]
- [Source: docs/game-architecture.md#Spatial Model, F1]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
