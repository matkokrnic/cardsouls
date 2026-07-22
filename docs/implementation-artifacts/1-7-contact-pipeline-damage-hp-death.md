# Story 1.7: Contact pipeline — hitbox facts → damage → HP → death

Status: backlog

## Story

As a player,
I want swinging at the dummy to reduce its HP by a data-authored amount and kill it at zero, with damage decided exclusively in `advance()` from runner-pushed facts,
so that the contact pipeline is deterministic and replay-safe with its scene wiring isolated to integration tests.

## Acceptance Criteria

1. `Hitbox` and `Hurtbox` `Area3D` nodes are added to the hero scene with an explicit collision-layer/mask convention documented in the scene and in `project-context.md`. Neither node contains gameplay logic; neither applies damage.
2. The runner gathers facts in step 2 by **direct query** (`get_overlapping_areas()` on state-flagged-active hitboxes), never `area_entered` signals (their firing order is not guaranteed). Contact facts (attacker slot, target slot, attack index) are pushed onto the queue consumed by `advance()` step 4.
3. `advance()` step 4 resolves contacts only: applies damage from balance (as a percentage of max HP per the chip-damage rule), honours the per-swing dedupe from 1.5, and routes the confirmed hit into the melee→mana hook. It queues `hp_changed` and a `hit_landed` signal carrying enough info for presentation to react.
4. Death is handled in `advance()` step 8 (resolution check): at HP ≤ 0 the hero enters a terminal state, further contacts are ignored, and `round_ended` is raised through `EventBus`. Demo scope is a single round — no restart flow beyond the 1.6 debug reset.
5. Testing splits deliberately: damage arithmetic, dedupe, death threshold, and signal order are **headless** tests fed synthetic contact facts; the actual `Area3D` wiring (an active hitbox over a hurtbox produces exactly one fact per swing; facts lag movement by a constant one tick) is an **integration** test. The one-tick lag is recorded as an asserted expectation, not a comment.

## Tasks / Subtasks

- [ ] Add `Hitbox`/`Hurtbox` `Area3D` nodes + documented layer/mask convention (AC: 1)
- [ ] Gather contact facts by direct query in runner step 2; push to queue (AC: 2)
- [ ] Resolve damage in `advance()` step 4 (balance %, dedupe, mana hook, signals) (AC: 3)
- [ ] Implement death in step 8; raise `round_ended` via `EventBus` (AC: 4)
- [ ] Tests (AC: 5)
  - [ ] Headless: arithmetic, dedupe, death threshold, signal order (synthetic facts)
  - [ ] Integration: one fact per swing; assert the constant one-tick fact→movement lag

## Dev Notes

- Direct query over `area_entered`: async signal firing order is not guaranteed and would make replay order-dependent. [Source: docs/game-architecture.md#D2 contacts note]
- `advance()` step 4 is the **only** place damage is decided; actors REPORT, state DECIDES. [Source: docs/game-architecture.md#Spatial Model]
- The one-tick fact→movement lag is a documented, constant, replay-safe relationship — assert it. [Source: docs/game-architecture.md#Spatial Model — Documented phase]
- This is the story where coverage moves partly to integration tests (X6). [Source: docs/game-architecture.md#Testing & Runtime Boundary]

### Project Structure Notes

- Nodes on `src/actors/hero/`; fact gather in `src/main/match_runner.gd`; resolution in `src/state/match_state.gd`; `round_ended` on `src/systems/event_bus.gd`. Integration test in `test/integration/`.

### Project Context Rules

- **`round_ended` is a genuinely ownerless global event** → `EventBus`, not a per-entity signal. [Source: docs/project-context.md#Signals over polling]
- Chip damage ~5–8% HP keeps chip a credible finisher (kill-source rule). [Source: gdd.md#Win/Loss Conditions]

### References

- [Source: stories-manual-e1.md#E1.S7]
- [Source: docs/game-architecture.md#D2; #Spatial Model; #Testing & Runtime Boundary]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
