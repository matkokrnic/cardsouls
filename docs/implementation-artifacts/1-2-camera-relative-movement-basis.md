# Story 1.2: Camera rig + camera-relative movement as a pushed spatial fact

Status: ready-for-dev

## Story

As a player controlling a soulsborne hero,
I want "forward" to move me relative to where my camera looks, resolved from a per-slot camera basis the runner pushes into state,
so that movement feels camera-relative while the state layer stays pure and split-screen (E2) remains a config change rather than a refactor.

## Acceptance Criteria

1. The camera rig is an actor-side node on the hero scene: third-person, **fixed distance, no zoom**, pulled back slightly further than Elden Ring's default so the hero is fully visible with terrain context. Camera distance/height/pitch are data-authored in a dedicated camera config resource (see Dev Notes — deliberately **not** `BalanceConfig`), never scene-script literals. The rig defines no `_physics_process` and follows the hero via the scene tree; the runner's only interaction with the rig is reading its basis and pushing it into `MatchState` in step 2 (per the single-`_physics_process` invariant F1).
2. The runner's step 2 reads each player's camera basis and pushes it into `MatchState` **indexed by player slot** (a small fixed-size array, not a single global basis). It must NOT push one shared basis.
3. In `_resolve_movement`, dispatched in step 3 of `MatchState.advance()` (`src/state/match_state.gd`), `intent.move_dir` is treated as a **camera-space** direction: rotated by that player's stored basis (yaw only; camera pitch must not tilt movement) and written as world-space into `HeroState.velocity`. `HeroState.velocity` stays the actual world velocity the actor consumes; the runner never rotates it after reading.
4. When no basis has been pushed (tick 0, headless tests, controller with no camera), the stored basis defaults to identity and `move_dir` is treated as world-space — keeping all E0 state tests valid and `advance()` free of scattered null checks.
5. A headless test proves a known basis rotates a known `move_dir` to the expected world velocity (and that pitch is ignored); an integration test rotates the camera, feeds a fixed forward intent, and asserts the actor's world displacement follows the camera. A smoke test asserts the authored camera config `.tres` loads and its values reach the rig.
6. Neither sanctioned-shortcut defect exists in `src/`: state never reads the camera; the runner never rotates velocity after reading it.

## Tasks / Subtasks

- [ ] Build the camera rig on the hero scene (AC: 1)
  - [ ] Create the camera config resource: a small `Resource` script + authored `.tres` under `data/` holding the camera framing values (distance/height/pitch), loaded **once** at match setup
- [ ] Add the per-slot camera-basis spatial fact to runner step 2 (AC: 2)
  - [ ] Store as a fixed-size per-slot array in `MatchState`; never one global basis
- [ ] Rotate `move_dir` by the per-slot basis inside `advance()` (AC: 3)
  - [ ] Yaw only; write world-space result into `HeroState.velocity`
- [ ] Define identity-default behaviour when no basis pushed (AC: 4)
- [ ] Tests (AC: 5, 6)
  - [ ] Headless: known basis → expected world velocity; pitch ignored
  - [ ] Integration: rotate camera, forward intent, displacement follows camera
  - [ ] Smoke: authored camera config `.tres` loads; its values reach the rig

## Dev Notes

- **SEAM CHOICE 2 — camera basis is per-slot from day one.** Sizing the basis fact per player slot now is what keeps E2 split-screen a config change rather than a refactor. Do **not** push one shared/global basis. [Source: stories-manual-e1.md#E1.S2 item 2]
- Camera-relative movement is a **pushed fact**, the only F1-consistent resolution. The two tempting shortcuts are both defects: **state reading the camera** breaks D3; **the runner rotating velocity after reading it** makes the field no longer the real velocity and makes replay depend on presentation state. [Source: docs/game-architecture.md#Spatial Model — Camera-relative movement is a pushed fact]
- Yaw-only rotation: the camera's pitch must never tilt movement.
- **Camera framing is presentation config, not combat balance.** Distance/height/pitch live in a dedicated camera config resource (own small script + authored `.tres` under `data/`, per the data-as-resources convention), loaded **once** at match setup — deliberately outside `BalanceConfig` and outside the X3 hot-reload path (load-once). This keeps story 1-1's "all E1 melee fields" claim intact.
- **Camera rotation input is OUT OF SCOPE for this story and for E1.** The GDD Input Map defines no camera-look action and the camera orientation is fixed; the basis changes only programmatically (tests push non-identity bases). When a later story introduces a look action, it MUST flow controller → `InputIntent.aim` → runner → rig; the rig never reads `Input.*` directly (invariant D3(a)).
- **Snapshot/determinism contract:** the per-slot camera basis is an input-like pushed fact — the same category as `InputIntent` — and is **EXCLUDED from `to_snapshot()`**. The default is identity (AC 4), so the existing golden-hash determinism regression is unchanged and must **NOT** be re-baselined. While the camera is fixed (all of E1) the basis is deterministic, so the X5 replay contract is unaffected; once camera look becomes input-driven, that input enters the recorded intent stream, keeping replays reproducible.

### Project Structure Notes

- Rig node under `src/actors/hero/`; basis gathered in `src/main/match_runner.gd` step 2; rotation applied in `_resolve_movement` in `src/state/match_state.gd`. Camera framing values authored as a dedicated camera config `.tres` under `data/` (not `data/balance/` — presentation config, see Dev Notes).

### Project Context Rules

- **F1:** `match_runner` is the only `_physics_process`; the rig has none. [Source: docs/project-context.md#Single _physics_process]
- **D3(a)/(b):** state never touches `Input` or presentation (the camera). [Source: docs/project-context.md#Controllers & state-layer determinism]
- Camera values are authored `.tres` data, not literals. [Source: docs/project-context.md#Data as Resources]

### References

- [Source: stories-manual-e1.md#E1.S2]
- [Source: docs/game-architecture.md#Spatial Model & the _physics_process boundary]
- [Source: gdd.md#Level Design Framework — Camera]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
