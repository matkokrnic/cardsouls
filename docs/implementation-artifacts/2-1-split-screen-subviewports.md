# Story 2.1: Two `SubViewport`s and the split-screen rig

Status: backlog

## Story

As a player,
I want two side-by-side viewports rendering the one shared arena, each following its own hero at the authored camera framing,
so that combat feel and <0.5s telegraph legibility can be judged in the real half-width viewport at 60 FPS.

## Acceptance Criteria

1. `main.tscn` is restructured into a split-screen root: two `SubViewportContainer` + `SubViewport` pairs side by side, each hosting its own `Camera3D` following its own hero, with the shared 3D world rendered into both. The world and actors are not duplicated.
2. The F1 boundary holds: no viewport, camera, or container acquires a `_physics_process`. The runner drives camera follow in step 4 (after `advance()`, before signals drain), so camera position is a deterministic function of the tick.
3. The per-slot camera-basis fact from 1.2 extends to genuinely two entries: slot 0 reads camera 0, slot 1 reads camera 1, gathered in step 2 in fixed slot order. A player's movement is relative to their own camera and unaffected by the other camera's rotation.
4. Camera framing is re-checked at half width against the GDD (fixed distance, no zoom, pulled back slightly further than Elden Ring's default, hero fully visible with terrain context). Balance-authored camera values are adjusted; if the pulled-back framing does not survive half width, that is logged in `decision-log.md`, not silently zoomed.
5. Frame budget is measured with both viewports live: frame time over a full melee exchange confirms the 60 FPS target (~16.6 ms). The measured number is recorded in `docs/playtest-log.md` as the baseline for later epics.

## Tasks / Subtasks

- [ ] Restructure `main.tscn` into two `SubViewportContainer`+`SubViewport` pairs sharing one world (AC: 1)
- [ ] Keep camera follow in runner step 4; no viewport/camera `_physics_process` (AC: 2)
- [ ] Extend the per-slot camera basis to two live entries, fixed slot order (AC: 3)
- [ ] Re-validate half-width framing; adjust balance values or log a finding (AC: 4)
- [ ] Measure frame time both viewports live; record baseline in `docs/playtest-log.md` (AC: 5)

## Dev Notes

- **One `MatchState`, two views** — split-screen does not duplicate state. One match, one `advance()`, one signal queue; the split is two `SubViewport`s + two HUD roots subscribing to different players' signals. [Source: stories-manual-e2.md#Before you start]
- This story realizes DECISION (b): the per-slot camera basis built in 1.2 now genuinely carries two entries — a config change, not a refactor, exactly because it was sized per slot from day one. [Source: stories-manual-e1.md#E1.S2; stories-manual-e2.md#E2.S1 item 3]
- Half-width framing is the viewport E5's telegraphs must read in; a framing that fails here is a finding, not a silent zoom. [Source: gdd.md#Level Design Framework — Camera]

### Project Structure Notes

- `src/main/` root scene / `main.tscn`; camera follow in `match_runner.gd` step 4; two cameras on the hero scenes.

### Project Context Rules

- **F1:** runner is the only `_physics_process`. [Source: docs/project-context.md#Single _physics_process]
- **60 FPS** with both viewports (~16.6 ms). [Source: docs/project-context.md#Performance Rules]

### References

- [Source: stories-manual-e2.md#E2.S1]
- [Source: docs/game-architecture.md#Engine-Provided Architecture; #Spatial Model]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
