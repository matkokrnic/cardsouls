# Story 1.2: Camera rig + camera-relative movement as a pushed spatial fact

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player controlling a soulsborne hero,
I want "forward" to move me relative to where my camera looks, resolved from a per-slot camera basis the runner pushes into state,
so that movement feels camera-relative while the state layer stays pure and split-screen (E2) remains a config change rather than a refactor.

## Acceptance Criteria

1. The camera rig is an actor-side node on the hero scene: third-person, **fixed distance, no zoom**, pulled back slightly further than Elden Ring's default so the hero is fully visible with terrain context. Camera distance/height/pitch are balance-authored, not scene-script literals. The rig defines no `_physics_process` — the runner drives it.
2. The runner's step 2 reads each player's camera basis and pushes it into `MatchState` **indexed by player slot** (a small fixed-size array, not a single global basis). It must NOT push one shared basis.
3. In `advance()` step 1/3, `intent.move_dir` is treated as a **camera-space** direction: rotated by that player's stored basis (yaw only; camera pitch must not tilt movement) and written as world-space into `HeroState.velocity`. `HeroState.velocity` stays the actual world velocity the actor consumes; the runner never rotates it after reading.
4. When no basis has been pushed (tick 0, headless tests, controller with no camera), the stored basis defaults to identity and `move_dir` is treated as world-space — keeping all E0 state tests valid and `advance()` free of scattered null checks.
5. A headless test proves a known basis rotates a known `move_dir` to the expected world velocity (and that pitch is ignored); an integration test rotates the camera, feeds a fixed forward intent, and asserts the actor's world displacement follows the camera.
6. Neither sanctioned-shortcut defect exists in `src/`: state never reads the camera; the runner never rotates velocity after reading it.

## Tasks / Subtasks

- [ ] Build the balance-authored camera rig on the hero scene (AC: 1)
- [ ] Add the per-slot camera-basis spatial fact to runner step 2 (AC: 2)
  - [ ] Store as a fixed-size per-slot array in `MatchState`; never one global basis
- [ ] Rotate `move_dir` by the per-slot basis inside `advance()` (AC: 3)
  - [ ] Yaw only; write world-space result into `HeroState.velocity`
- [ ] Define identity-default behaviour when no basis pushed (AC: 4)
- [ ] Tests (AC: 5, 6)
  - [ ] Headless: known basis → expected world velocity; pitch ignored
  - [ ] Integration: rotate camera, forward intent, displacement follows camera

## Dev Notes

- **DECISION (b) — camera basis is per-slot from day one.** Sizing the basis fact per player slot now is what keeps E2 split-screen a config change rather than a refactor. Do **not** push one shared/global basis. [Source: stories-manual-e1.md#E1.S2 item 2]
- Camera-relative movement is a **pushed fact**, the only F1-consistent resolution. The two tempting shortcuts are both defects: **state reading the camera** breaks D3; **the runner rotating velocity after reading it** makes the field no longer the real velocity and makes replay depend on presentation state. [Source: docs/game-architecture.md#Spatial Model — Camera-relative movement is a pushed fact]
- Yaw-only rotation: the camera's pitch must never tilt movement.

### Project Structure Notes

- Rig node under `src/actors/hero/`; basis gathered in `src/main/match_runner.gd` step 2; rotation applied in `src/state/match_state.gd` `advance()`. Camera values authored in `data/balance/`.

### Project Context Rules

- **F1:** `match_runner` is the only `_physics_process`; the rig has none. [Source: docs/project-context.md#Single _physics_process]
- **D3(a)/(b):** state never touches `Input` or presentation (the camera). [Source: docs/project-context.md#Controllers & state-layer determinism]
- Camera values are balance data, not literals. [Source: docs/project-context.md#Data as Resources]

### References

- [Source: stories-manual-e1.md#E1.S2]
- [Source: docs/game-architecture.md#Spatial Model & the _physics_process boundary]
- [Source: gdd.md#Level Design Framework — Camera]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
