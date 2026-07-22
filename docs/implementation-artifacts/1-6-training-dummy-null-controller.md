# Story 1.6: Second player slot as the training dummy (controller config swap)

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a solo developer tuning hitboxes,
I want the training dummy to be a full second `PlayerState` + `HeroActor` driven by a `NullController` selected at one config point,
so that dummy → PvP → bot is a controller swap and nothing in hero/actor/state ever branches on "is this the dummy."

## Acceptance Criteria

1. The opponent is a **full second `PlayerState` + `HeroActor`**, identical in every respect to P1, driven by a `NullController` (`src/controllers/null_controller.gd`) returning a fresh empty `InputIntent` each tick. Nothing in the hero, actor, or `advance()` may branch on "is this the dummy" — the dummy is a controller choice and nothing else.
2. Controller assignment per slot is a single configuration point in `match_runner` (a small exported/injected slot → controller-kind setup), so E2 replaces `NullController` with `KeyboardController("p2")`/`GamepadController` and E7 with `ScriptedController`, each a one-line change.
3. The invariants survive: after adding the second slot, `func _physics_process`, `Input.`, and state-purity greps still pass; the second actor acquires no `_physics_process`; the runner drives both actors' movement in step 4 in fixed slot order P1 → P2.
4. The dummy has a reset affordance for tuning: a `debug`-flag action (`src/ui/debug/`) restoring HP and clearing action state through a **state-layer method** — the debug UI calls a method, it never writes fields.
5. The determinism regression extends to two populated slots: N ticks from a fixed seed with a fixed intent list for both slots reproduces the golden hash, and slot ordering is stable (the key-order-independence guardrail still holds).

## Tasks / Subtasks

- [ ] Add `NullController` returning a fresh empty `InputIntent` each tick (AC: 1)
- [ ] Instantiate a full second `PlayerState` + `HeroActor`, identical to P1 (AC: 1)
  - [ ] Verify no "is dummy" branch exists in hero/actor/advance()
- [ ] Add the single per-slot controller-kind config point in `match_runner` (AC: 2)
- [ ] Re-run the three invariant greps; confirm P1→P2 fixed movement order (AC: 3)
- [ ] Add the debug reset affordance calling a state-layer reset method (AC: 4)
- [ ] Extend determinism regression to two populated slots (AC: 5)

## Dev Notes

- **DECISION (a) — the dummy is a second full `PlayerState` + `HeroActor` driven by `NullController`, NOT a special dummy type.** No code anywhere branches on the opponent being a dummy; "dummy" is purely the controller choice. This is what makes E2 (second human) and E7 (bot) config swaps. [Source: stories-manual-e1.md#E1.S6 item 1]
- The per-slot controller config point is the seam E2.S3 and E7 extend; shape it as data now. [Source: docs/game-architecture.md#D3; epics.md#Sequencing invariants]
- Debug reset calls a state method; the debug UI never mutates fields (D5 direction). [Source: docs/game-architecture.md#Debug Tools; #Architectural Boundaries]

### Project Structure Notes

- `src/controllers/null_controller.gd`; second slot wired in `src/main/match_runner.gd`; reset UI under `src/ui/debug/`; reset method on `src/state/`.
- Note: the architecture tree lists an `actors/dummy/` seam, but per DECISION (a) the dummy is the **standard `HeroActor`** driven by `NullController`, not a distinct dummy actor type.

### Project Context Rules

- **F1 / D3(a)(b):** greps must still pass after the second slot. [Source: docs/project-context.md#Single _physics_process; #Controllers & state-layer determinism]
- **Controller abstraction:** nothing branches on "is this a human." [Source: gdd.md#Controls — Input architecture]

### References

- [Source: stories-manual-e1.md#E1.S6]
- [Source: epics.md#E1; #E2; #E7]
- [Source: docs/game-architecture.md#D3; #Novel Pattern 3]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
