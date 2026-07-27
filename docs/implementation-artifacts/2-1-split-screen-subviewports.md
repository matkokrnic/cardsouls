# Story 2.1: Two `SubViewport`s and the split-screen rig

Status: ready-for-dev

## Story

As a player,
I want two side-by-side viewports rendering the one shared arena, each following its own hero at the authored camera framing,
so that combat feel and <0.5s telegraph legibility can be judged in the real half-width viewport at 60 FPS.

## Acceptance Criteria

1. `main.tscn` gains two `SubViewportContainer` + `SubViewport` pairs, side by side, each rendering the one shared gameplay world and hosting only a follower `Camera3D`. All gameplay nodes — heroes, arena, lights — stay under `Main`; nothing is reparented into a `SubViewport`. Each hero's `CameraRig` (`hero.tscn` unchanged) remains the per-slot basis source the runner reads in step 2 (AC3). The world and actors are not duplicated, only rendered twice. (Engine world-sharing mechanics — how a `SubViewport` renders a world it does not own — are a dev-pass detail; the binding constraint is that no gameplay node moves.) (Verification: scene diff review + visual check.)
2. The F1 boundary holds: no viewport, camera, or container acquires a `_physics_process`. The runner drives camera follow in step 4 (after `advance()`, before signals drain): each rig's global transform is copied onto its follower `Camera3D` — presentation-only, a deterministic function of the tick, snapshot-excluded. (Verification: F1 invariant test — `test/state/test_architecture_invariants.gd` — plus review.)
3. The per-slot camera-basis fact from 1.2 already carries two live entries at HEAD: the runner pushes `_p1_rig.basis` / `_p2_rig.basis` in step 2, and `_camera_bases` holds two entries (snapshot-excluded). 2-1 VERIFIES this — no basis-gathering code changes — and adds two-slot integration coverage by extending `test/integration/test_camera_relative.gd` (currently P1-only) to assert slot 1 independently. A player's movement is relative to their own camera and unaffected by the other camera's rotation. (Verification: extended integration test.)
4. Camera framing is re-checked at half width against the GDD (fixed distance, no zoom, pulled back slightly further than Elden Ring's default, hero fully visible with terrain context). Camera framing values live in `data/camera_config.tres` — a presentation config, loaded once, deliberately outside `BalanceConfig` and the X3 hot-reload path — and are adjusted there if half-width framing needs it; if the pulled-back framing does not survive half width, that is logged in `decision-log.md`, never silently zoomed. (Verification: visual live-run.)
5. Frame budget is measured with both viewports live: frame time over a full melee exchange confirms the 60 FPS target (~16.6 ms). The measured number is recorded in `docs/playtest-log.md` as the baseline for later epics. (Verification: live performance measurement during the smoke.)

## Tasks / Subtasks

- [x] Restructure `main.tscn` into two `SubViewportContainer`+`SubViewport` pairs sharing one world; no gameplay node reparented (AC: 1)
- [x] Keep camera follow in runner step 4; no viewport/camera `_physics_process` (AC: 2)
- [x] Extend `test/integration/test_camera_relative.gd` to cover slot 1 independently, verifying the two-entry basis already at HEAD (AC: 3)
- [x] VERIFY integration-test node paths (`test/integration/test_camera_relative.gd`, `test_root_rotation_isolation.gd`, `test_hero_movement.gd`) still resolve after the scene work; under the ruled topology they should be unchanged — update only if a path actually moved, and list any touched test in the File List (AC: 2, 3)
- [x] Re-validate half-width framing; adjust `data/camera_config.tres` values or log a finding (AC: 4) — pending operator live smoke (visual judgment; headless cannot decide framing)
- [x] Measure frame time both viewports live; record baseline in `docs/playtest-log.md` (AC: 5) — pending operator live smoke

## Golden Prediction

**NONE** — `_camera_bases` is EXCLUDED from `to_snapshot()` (`match_state.gd`), camera framing lives entirely in `data/camera_config.tres`, and this story touches no `advance()` state math. Hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` is measured BEFORE the first edit and AFTER the last, in BOTH directions; it must be identical. Any movement is a stop-and-report, never a re-baseline. Precedents: 1-6, 1-7b, 1-10.

## Live Smoke (single-use acceptance, gate ruling 2-1/R2)

The spent R-D6 acceptance is RE-INVOKED for THIS story only, consumed on use — needed to live-verify the P2-side camera and AC5's full melee exchange in split-screen.

- The flip is a temporary `KEYBOARD_P2` on runner slot 1, performed by TEXT-EDITING the `slot_controller_kinds` line in `src/main/main.tscn`. The Godot editor stays CLOSED for the entire smoke.
- Revert is a text edit back, or per-diff sorting. A blanket `git checkout -- src/main/main.tscn` is FORBIDDEN in this story — the file carries intentional changes (the split-screen restructure); any `project.godot` collateral is also sorted per-diff, never blanket-reverted.
- AC5 is pinned to this smoke: sustained 60 fps with no perceptible drops on the dev machine through a full melee exchange in split-screen.

## Dev Notes

- **One `MatchState`, two views** — split-screen does not duplicate state. One match, one `advance()`, one signal queue; the split is two `SubViewport`s + two HUD roots subscribing to different players' signals. [Source: stories-manual-e2.md#Before you start]
- This story realizes SEAM CHOICE 2 (the per-slot camera-basis push named in `match_runner.gd`'s step-2 comment and `match_state.gd`): the basis built in 1.2 was sized per slot from day one, so split-screen genuinely activating slot 1 is a config change, not a refactor. [Source: stories-manual-e1.md#E1.S2; stories-manual-e2.md#E2.S1 item 3]
- Half-width framing is the viewport E5's telegraphs must read in; a framing that fails here is a finding, not a silent zoom. [Source: gdd.md#Level Design Framework — Camera]
- Disposition of the existing `current = true` override on P1's `Camera3D` (`main.tscn`, under `P1Hero/CameraRig`) is a dev-pass detail: the two `SubViewportContainer`s cover the full window regardless of which node (if any) is flagged `current` outside them.
- **E2 collateral rule.** The moment `main.tscn` carries intentional changes (this story's restructure), collateral is sorted per-diff — the blanket revert pair `git checkout -- src/main/main.tscn project.godot` is retired for this story and stays retired unless a later E2 story explicitly reinstates it.

### Project Structure Notes

- `src/main/` root scene / `main.tscn`; camera follow in `match_runner.gd` step 4; each hero keeps its existing `CameraRig` (`hero.tscn` unchanged) as the per-slot basis source; two follower `Camera3D` nodes live under the two new `SubViewport`s, one per slot — not on the hero scenes.

### Project Context Rules

- **F1:** runner is the only `_physics_process`. [Source: docs/project-context.md#Single _physics_process]
- **60 FPS** with both viewports (~16.6 ms). [Source: docs/project-context.md#Performance Rules]

### References

- [Source: stories-manual-e2.md#E2.S1]
- [Source: docs/game-architecture.md#Engine-Provided Architecture; #Spatial Model]
- [Source: decision-log.md#Session 2026-07-27 — Story 2-1 readiness gate (operator decisions)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8

### Debug Log References

- Golden BEFORE first edit == golden AFTER last edit == `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` (state harness `test_determinism` green in both directions; `GOLDEN` constant in `test/state/test_determinism.gd` untouched). Prediction NONE held.
- State harness both passes: `142 tests, 0 failed, 645 assertions` (includes F1/`test_architecture_invariants`).
- All 8 integration tests PASS individually post-edit. Extended `test_camera_relative`: `P1 dx=-2.500002 dz=0.000000  P2 dx=2.500002 dz=0.000000 (smoke_ok=true, p1_followed=true, p2_followed=true)` — P1 follows its +90° rig yaw to world −X, P2 follows its −90° rig yaw to world +X (opposite axes → the two per-slot bases are distinct and independent).

### Completion Notes List

- **Topology (ruling 2-1/R1).** No gameplay node reparented. `Sun`, `Ground`, `P1Hero`, `P2Hero` stay direct children of `Main`. Two `SubViewportContainer` (`P1View` anchored left half `0..0.5`, `P2View` right half `0.5..1.0`, both `stretch = true`) each hold a `SubViewport` hosting only a follower `Camera3D`. Each `CameraRig` stays a child of its hero (`hero.tscn` untouched) and remains the step-2 basis source. Node-path verification: `test_root_rotation_isolation.gd` and `test_hero_movement.gd` (`Main/P1Hero`, `Main/P1Hero/CameraRig`) resolve unchanged and were NOT modified.
- **World-sharing mechanism (the declared KAKO freedom).** The two `SubViewport`s keep `own_world_3d = false` (the default), so they inherit the root window's `World3D` — the same world `Main`'s gameplay nodes register into. No world is duplicated and no `world_3d` is wired by script: the follower cameras render the shared world purely by living in `SubViewport`s that inherit it. Chosen over an explicit `world_3d` assignment because the gameplay lives in the root window's world (not inside a `SubViewport`), so inheritance is the natural, script-free fit for "render a world you do not own."
- **Camera follow (step 4b).** The runner mirrors each rig's CHILD camera global transform (`_p1_rig_cam` / `_p2_rig_cam`, i.e. `CameraRig/Camera3D`) onto the follower — NOT the rig root's transform. The rig root sits at the hero origin; the authored `camera_config` framing (distance/height/pitch) is applied by `CameraRig.apply_config` to the child camera's LOCAL transform, so only the child camera's GLOBAL transform carries the pulled-back framing. Copying it keeps `data/camera_config.tres` the single framing source for both the rig camera and the follower — AC4 reframing stays a one-file `.tres` edit with no follower-specific values. (The literal ruling phrase "rig's global transform" is read this way so AC4 framing survives; a rig-root copy would drop it.) Follower default projection matches the rig camera's (both plain `Camera3D` defaults, fov 75).
- **`current = true` disposition (dev-pass detail per Dev Notes).** Removed the old `current = true` override on P1's rig `Camera3D` and the now-orphaned `[editable path="P1Hero"]`. Set `current = true` on the two follower cameras instead. Rationale: the split-screen followers are now the intended render path and their containers fully occlude the root window; the rig cameras are pure basis sources, so privileging P1's rig camera as an explicit full-window root render was redundant work behind the opaque containers. Heroes are now symmetric (both plain `hero.tscn` instances). No integration test depends on the `current` flag (they read camera transforms only), and all 8 still pass.
- **`render_target_update_mode = 4` (ALWAYS) on both `SubViewport`s.** Guarantees continuous rendering in the split (both viewports are always visible anyway, so the delta vs the WHEN_VISIBLE default is negligible) — avoids any risk of a stale/black half during the live smoke.
- **F1 held.** No new `_physics_process` anywhere; the follow runs inside the runner's existing one. No script on any viewport/container/camera node. No new `.gd` file created.
- **AC4 / AC5 pending operator live smoke.** `data/camera_config.tres` was NOT touched — half-width framing is a visual judgment headless cannot make. If the pulled-back framing fails at half width, that is a finding for the operator (recorded here, not in `decision-log.md`). Frame-time baseline (`docs/playtest-log.md`) is the operator's live measurement. `src/state/` and `project.godot` were NOT touched (pre-declared STOP tripwires — none tripped).
- **Operator live smoke results (AC4/AC5 closed).** Both viewports render side by side; P1 camera-relative correct; half-width framing PASS — hero fully visible with terrain context, the pulled-back framing survives, NO `camera_config.tres` change needed; no camera jitter; sustained 60 fps through a full melee exchange with a live `KEYBOARD_P2` flip; flip applied and reverted by TEXT EDIT with the editor closed the whole time; post-revert diff verified to the intentional set. Live observation: a DEAD hero can still move — the known NAMED GAP "DEAD-slot residuals" (1-7), now confirmed live; fix trigger remains story 2-3.

### File List

- `src/main/main.tscn` — restructured: two `SubViewportContainer`+`SubViewport`+follower `Camera3D` pairs added; P1 rig-camera `current = true` override and `[editable path="P1Hero"]` removed (AC 1)
- `src/main/match_runner.gd` — added follower + rig-camera `@onready` refs and step-4b camera follow; no new `_physics_process` (AC 2)
- `test/integration/test_camera_relative.gd` — EXTENDED for independent slot-1 coverage via the per-slot config point, verifying the two-entry basis already at HEAD (AC 3)

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-27 | 0.1 | Dev pass: split-screen `SubViewport` restructure, runner step-4b camera follow, two-slot `test_camera_relative` extension. Golden unmoved; suite 142/645 + 8 integration green. AC4/AC5 pending operator live smoke. NOT committed. | claude-opus-4-8 |
