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

- [ ] Restructure `main.tscn` into two `SubViewportContainer`+`SubViewport` pairs sharing one world; no gameplay node reparented (AC: 1)
- [ ] Keep camera follow in runner step 4; no viewport/camera `_physics_process` (AC: 2)
- [ ] Extend `test/integration/test_camera_relative.gd` to cover slot 1 independently, verifying the two-entry basis already at HEAD (AC: 3)
- [ ] VERIFY integration-test node paths (`test/integration/test_camera_relative.gd`, `test_root_rotation_isolation.gd`, `test_hero_movement.gd`) still resolve after the scene work; under the ruled topology they should be unchanged — update only if a path actually moved, and list any touched test in the File List (AC: 2, 3)
- [ ] Re-validate half-width framing; adjust `data/camera_config.tres` values or log a finding (AC: 4)
- [ ] Measure frame time both viewports live; record baseline in `docs/playtest-log.md` (AC: 5)

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

### Debug Log References

### Completion Notes List

### File List

- `test/integration/test_camera_relative.gd` — to be EXTENDED for two-slot coverage (AC 3), currently P1-only
