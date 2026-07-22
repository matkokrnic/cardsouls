# Story 1.5: Basic attack chain

Status: backlog

## Story

As a player,
I want a souls-style basic attack chain whose hitbox lifetime and per-swing dedupe live in state and which calls a melee→mana hook on hit,
so that the attack is deterministic, replay-safe, and the E3 flywheel plugs in with no combat-code change.

## Acceptance Criteria

1. The attack chain is state: an attack index advances while input lands inside the chain window during recovery, capped at `attack_chain_length`, resetting to zero when the window expires. No links, juggles, or cancels — souls-style chains only.
2. The hitbox is **state data**: `HeroState` carries `is_hitbox_active` (plus the chain index for later per-swing tuning), true only during the active window. The actor reads this flag; the actor never decides when it can hit.
3. Basic attack costs no resource but generates mana on hit: on a confirmed contact, call the economy evaluator with `source: &"melee_hit"`. In E1 no such rule is authored, so the call is a no-op (E3 authors the `.tres`). Do not branch on a feature flag inside the hook — the absence of a rule is the graceful degradation.
4. Per-swing contact deduplication is in state: one swing damages a given target at most once, tracked on the attack instance and cleared when the active window closes.
5. Headless tests: chain advances only inside the window and caps correctly; `is_hitbox_active` is true for exactly the active-window ticks; the same target contacted twice in one swing takes damage once; the economy hook is invoked once per confirmed hit.

## Tasks / Subtasks

- [ ] Implement the state-side chain index (advance in window / cap / reset) (AC: 1)
- [ ] Expose `is_hitbox_active` + chain index as `HeroState` data (AC: 2)
- [ ] Call `EconomyEvaluator.apply(..., &"melee_hit", ...)` on confirmed contact (AC: 3)
  - [ ] No feature-flag branch in the hook; no authored rule in E1 (no-op)
- [ ] Track per-swing dedupe on the attack instance; clear on active-window close (AC: 4)
- [ ] Headless tests (AC: 5)

## Dev Notes

- Solving hitbox lifetime and dedupe **in state** (not by enabling/disabling an `Area3D`) keeps them headless-testable and replay-safe. The actual `Area3D` overlap wiring arrives in 1.7. [Source: stories-manual-e1.md#E1.S5 items 2,4]
- The melee→mana **hook** lands now as a call site; E3 authors the `melee_hit` rule and the flywheel starts. Not branching on a flag inside the hook is deliberate — the missing rule *is* the graceful degradation. [Source: docs/game-architecture.md#D6; #Novel Pattern 5]
- No combo system — chains, not links. [Source: gdd.md#F Real-Time Combat — No traditional combo system]

### Project Structure Notes

- `src/state/hero_state.gd` (chain index, `is_hitbox_active`, dedupe set), `src/state/economy/economy_evaluator.gd` hook.

### Project Context Rules

- **State/visual separation:** hitboxes report contact; state decides damage. The flag lives on state, not the scene. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **advance() takes no delta;** timing is ticks. [Source: docs/project-context.md#Deterministic timing]

### References

- [Source: stories-manual-e1.md#E1.S5]
- [Source: gdd.md#Primary Mechanics — Basic Attack; #F]
- [Source: docs/game-architecture.md#D2 steps 3–5; #Novel Pattern 5]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
