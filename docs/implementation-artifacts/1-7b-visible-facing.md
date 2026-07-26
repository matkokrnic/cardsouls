---
baseline_commit: 0abd4525ba3e398c5eb0d77f2fea2e73f9025287
---

# Story 1.7b: Visible facing — mesh yaw + directional marker

Status: review

## Story

As a player,
I want the hero's body to visibly point where my attacks will land — the child mesh yawing with the same facing the melee hitbox already tracks, with an asymmetric marker so the direction can actually be seen,
so that aiming a ~0.9-unit melee reach stops being blind, every subsequent combat playtest (1-8 block/deflect above all) tests feel instead of guesswork, and the mesh becomes the truthful display of hitbox yaw — incapable of diverging from it.

**Model: 1-3c** — a small targeted story that makes existing state visible so playtesting means something. **Unlike 1-3c this is NOT throwaway:** DECISION A already names the child mesh as the permanent home for body rotation ("body/facing rotation belongs on a child mesh node", `match_state.gd` camera-basis doc block); only the marker geometry is placeholder aesthetics.

**Motivation (1-7 close-out playtest finding, decision-log Session 2026-07-26):** facing is INVISIBLE in the live game — the hero is a symmetric cube, the root never rotates (DECISION A), nothing rotates the `Mesh` child, and the only thing that yaws is the non-rendered Hitbox. The manual facing check could not be performed at all. Melee reach is ~0.9 in front of the body (HitboxShape at local z 0.9), so aim matters, yet the player has zero directional feedback.

## Acceptance Criteria

1. **Mesh yaw — single yaw source, inside `drive()` (DECISION A holds).** The `Mesh` child of `hero.tscn` yaws to `HeroState.facing` (WORLD-SPACE planar since the 1-7 R1 contract — decision-log Session 2026-07-26, its canonical home) inside `HeroActor.drive()`, exactly where the Hitbox is already yawed. The mesh MUST use the **exact same facing-to-yaw mapping the Hitbox uses** — one shared computation/value per drive call (e.g. hoist the existing `atan2(hero_state.facing.x, hero_state.facing.y)` into a single local applied to both nodes), **never a second `atan2`**. Structural goal: the visible mesh is the truthful display of hitbox yaw and cannot diverge from it. The hero **ROOT does not rotate** — root rotation stays deferred DECISION B, and `test/integration/test_root_rotation_isolation.gd` must stay green.
2. **Directional marker — asymmetry is mandatory.** A rotated symmetric cube is still invisible. Add a minimal directional marker as a **child of the `Mesh` node**, authored directly in `hero.tscn` (e.g. a small prism "nose" offset toward local forward). Local forward is **+Z** — the same direction as the hitbox reach (`HitboxShape` sits at local z 0.9; the shared yaw points local +Z along facing). Placeholder aesthetics fine; **no new assets or import pipeline** — sub-resource primitives in the scene file, like every mesh in it today.
3. **Presentation-only — golden prediction: NONE.** No changes under `src/state/`, no snapshot changes, no Input Map or `project.godot` changes, no new autoloads. The golden hash is **measured before and after the change and must be identical** — `39564e83831819d4486d6216e9030535029de1298168ebeee720ab4812705353`; ANY movement is a defect in this story, never a re-baseline (1-3c AC 4 precedent).
4. **Zero-input and per-slot behavior inherit existing semantics — no new logic.** The facing zero-guard already lives in `_resolve_movement` (`match_state.gd`: `if not dir.is_zero_approx(): player.hero.facing = Vector2(world_dir.x, world_dir.z)`) — facing freezes while movement input is zero, so the mesh **keeps its last orientation with no snap-back**, for free. The change is per-slot generic: it works for any hero actor via `drive()`; the NullController dummy simply stays at its initial facing (`Vector2.DOWN` ⇒ yaw 0, local +Z at world +Z). Neither behavior gets special-case code.
5. **Test pin — integration-level (F1/X6: scene-side facts are integration territory).** An integration test drives movement in **at least two different directions** (real Input presses, existing-suite pattern) and asserts, after each: (a) mesh yaw equals hitbox yaw (the truthful-display pin) and equals the shared mapping of `HeroState.facing` — under the fixed identity camera basis, facing equals the pressed world direction, so the expected yaw is derivable from the press; (b) root rotation stays identity throughout. After input release, mesh yaw persists (AC 4, no snap-back). The **state harness is untouched**. Invocation on this machine: state harness `godot --headless --path . --script test/run_state_tests.gd`; integration tests run individually (WSL is broken; `test/run_all.sh` does not work).

**OUT OF SCOPE (fences):** root rotation (deferred DECISION B); camera changes; root motion / authored lunge displacement (named at the 1-7 close-out, deferred not dropped — NOT this story); animation; HUD (E2); any 1-8 block/deflect content. No `src/state/` edits, no `project.godot` edits, no new autoloads (AC 3 restated as a fence).

## Tasks / Subtasks

- [x] Mesh yaw in `drive()` (AC: 1)
  - [x] Hoist the existing hitbox yaw computation into ONE shared value per drive call; apply it to both `Hitbox` and `Mesh` — no second `atan2`
  - [x] `@onready` mesh reference alongside the existing `hitbox` reference
- [x] Directional marker (AC: 2)
  - [x] Small asymmetric primitive (e.g. prism) as a child of `Mesh`, offset toward local +Z, authored directly in `hero.tscn` sub-resources — no new assets
- [x] Verification (AC: 3, 4, 5)
  - [x] Integration test: two-direction drive → mesh yaw == hitbox yaw == expected mapping of the pressed direction; root rotation identity; yaw persists after release (extend `test/integration/` — prefer extending an existing file; a NEW .gd file needs a `.uid` via editor scan before it could ever be committed)
  - [x] `test/integration/test_root_rotation_isolation.gd` still green
  - [x] State harness before AND after: 115 tests / 543 assertions green, golden hash IDENTICAL (`39564e83…5353`) — measured, never trusted
  - [x] Manual smoke check: run the main scene, walk each direction, confirm the marker visibly leads the body and the dummy never turns; record the observed behavior in the Dev Agent Record — performed by the operator at review — PASSED, see Completion Notes

## Dev Notes

- **DECISION A (locked, 1-2 close-out) is the load-bearing constraint:** the camera rig is a child of the hero root, so a rotated root folds hero rotation into the pushed camera basis. While the camera is fixed (all of E1) the root never rotates; body/facing rotation belongs on the CHILD mesh. This story is the first to actually do the sanctioned thing. Guard: `test/integration/test_root_rotation_isolation.gd`.
- **`HeroState.facing` is WORLD-SPACE planar — canonical contract at decision-log Session 2026-07-26 (1-7 review R1, operator decision).** `_resolve_movement` assigns `Vector2(world_dir.x, world_dir.z)` under the zero-guard; actor-side consumers need no basis knowledge. The hitbox yaw in `HeroActor.drive()` (`atan2(hero_state.facing.x, hero_state.facing.y)`) is already correct for it; the mesh consumes the SAME value.
- **Single yaw source is the structural point, not a style preference.** Two independent mappings could drift (one edited, one not) and the display would lie about where the hitbox aims — the exact failure this story exists to prevent. One computed value, two assignments.
- **Visuals → state is the allowed dependency direction** (1-3c precedent: overlay decodes the enum; here the mesh reads `facing`). No state-layer change is needed or permitted — the state already knows facing; this story only renders it.
- **Coverage-shape lesson from 1-7 (decision-log close-out):** the live scene runs at an identity basis, so the integration expected-yaw derivation (facing == pressed direction) is valid there; the non-identity case is already pinned headless (`test_camera_basis.gd` facing test). This story does not re-test the basis math — it pins the scene-side display of it.
- **Zero-guard inheritance:** with no movement input, `facing` simply isn't reassigned — the mesh holds its last yaw. Any mesh-side "remember last direction" logic would be a second source of truth; do not write one.
- **New-file discipline:** prefer extending existing files (`hero.gd`, `hero.tscn`, an existing `test/integration/` test). Any NEW `.gd` file needs a `.uid` sidecar via editor scan (`godot --headless --editor --quit --path .`) before it could ever be committed; verify the scan does not rewrite `hero.tscn` (1-7 Debug Log precedent: diff shapes checked before and after).
- **Runner invocation on this machine:** WSL is broken; `test/run_all.sh` is unavailable. State harness: `godot --headless --path . --script test/run_state_tests.gd`. Integration tests: individually, `godot --headless --path . --script res://test/integration/<file>.gd`.

### Project Structure Notes

- `src/actors/hero/hero.gd` (modified — hoist the shared yaw value; apply to `Hitbox` + `Mesh`; `@onready` mesh ref).
- `src/actors/hero/hero.tscn` (modified — marker primitive under `Mesh`, sub-resource only).
- `test/integration/` (extended — the AC 5 pin; prefer extending an existing test file, `.uid` duty if new).
- **No other files.** In particular: nothing under `src/state/`, no `project.godot`, no `test/state/`, no `test/state/test_determinism.gd` — the golden stands.

### Project Context Rules

- **D3/A2 untouched:** no edits under `src/state/` — no scene reference, no `Input`, no autoload, no nondeterministic source enters the state layer; this story never touches it. [Source: docs/project-context.md#Controllers & state-layer determinism]
- **Visuals → state is the allowed dependency direction:** the mesh READS `HeroState.facing`, never writes it — same direction as the hitbox yaw it joins. [Source: docs/project-context.md#HARD RULE — State / visual separation]
- **F1 untouched:** the runner remains the only `_physics_process`; the mesh yaw rides the existing `drive()` call, no new tick driver. [Source: docs/project-context.md#Single _physics_process]
- **No hardcoded gameplay numbers introduced:** the yaw is derived from `facing`; the marker geometry is scene authoring (placeholder visuals), not a gameplay number, so nothing new belongs in balance `.tres`. [Source: docs/project-context.md#Critical Don't-Miss Rules]

### References

- [Source: decision-log.md#Session 2026-07-26 — 1-7 close-out — "FACING IS INVISIBLE" playtest finding (this story's mandate); WORLD-SPACE facing contract (R1); coverage-shape lesson; root-motion constraint (out of scope here)]
- [Source: decision-log.md#Session 2026-07-23 — Story 1-2 close-out — DECISION A (root never rotates; child-mesh home for body rotation)]
- [Source: docs/game-architecture.md#Testing & Runtime Boundary (X6 — scene-side facts are integration territory); #Determinism & Replay (golden discipline)]
- [Source: 1-3c-debug-state-overlay.md — the make-state-visible story pattern (AC 4 golden-unmoved precedent)]

## Readiness Gate

- 2026-07-26: gds-check-implementation-readiness run against this story (authored earlier the same session from the 1-7 close-out playtest finding, against live source — authored-then-gated same session, report-only). Verdict **READY** — zero blocking findings; all four operator-flagged assumptions verified against actual `src/` by content (hitbox yaw mapping is the single `atan2(hero_state.facing.x, hero_state.facing.y)` line in `HeroActor.drive()`; `hero.tscn` carries `Mesh` as a scriptless MeshInstance3D sibling of `Hitbox` with `HitboxShape` at local z 0.9; the facing zero-guard is `_resolve_movement`'s `if not dir.is_zero_approx()` assignment; facing is genuinely world-space — `Vector2(world_dir.x, world_dir.z)`, pinned by `test_camera_basis.gd`). Baseline measured live at gate time: 115 state tests / 543 assertions PASS, golden `39564e83…5353` confirmed. Four advisories, no story change required:
  - **N1:** do not "helpfully" rotate `Collision` or `Hurtbox` — both are symmetric boxes on the root, deliberately unrotated; this story yaws exactly `Mesh` alongside the existing `Hitbox`, from ONE value.
  - **N2:** the integration test has no `HeroState` handle — derive expected yaw from the pressed direction under the scene's identity basis (AC 5's route); mesh-yaw == hitbox-yaw is the primary truthful-display pin; compare yaws approximately, not exactly.
  - **N3:** if the dev pass creates a new `.gd` test file, generate the `.uid` via editor scan and verify the scan does not rewrite `hero.tscn` (1-7 Debug Log precedent — it bit once).
  - **N4:** out-of-band, NOT touched in 1-7b (its fence keeps the state harness untouched): `test/state/test_contact_resolution.gd` carries a stale pre-R1 comment ("facing updates from raw intent") — only true under an identity basis since the world-space contract; the assertion itself is valid (the test runs at identity), the wording is stale; queued for a future comment-hygiene pass.

## Dev Agent Record

### Agent Model Used

Claude Fable 5 (claude-fable-5)

### Debug Log References

- Golden measured BOTH directions (AC 3, never trusted): state harness run BEFORE any edit — 115 tests / 543 assertions PASS; measured hash `39564e83831819d4486d6216e9030535029de1298168ebeee720ab4812705353` == GOLDEN. Re-run AFTER implementation — 115/543 PASS, measured hash IDENTICAL. Measurement via a scratchpad-only SceneTree script calling `test_determinism.gd`'s own `_run()` (no duplicated sequence, never committed).
- Editor scan for the new test's `.uid` (N3): `godot --headless --editor --quit --path .` generated exactly `test/integration/test_visible_facing.gd.uid` (`uid://bxjcjx04u8cat`); verified by `git status --porcelain` + full diff that the scan rewrote NOTHING else — `hero.tscn` diff contains only the authored marker sub-resource + node (1-7 Debug Log precedent).
- Integration tests run INDIVIDUALLY (WSL broken, `test/run_all.sh` unavailable): all 7 PASS — new `test_visible_facing` (right press yaw 1.570796, up press yaw 3.141593, persistence after release, root identity all three phases, mesh == hitbox exactly in all), plus `test_root_rotation_isolation` (AC 1 guard, still green), `test_hero_movement`, `test_camera_relative`, `test_live_attack`, `test_debug_overlay`, `test_contact_pipeline`.

### Completion Notes List

- AC 1 — single yaw source: `HeroActor.drive()` hoists the existing `atan2(hero_state.facing.x, hero_state.facing.y)` into ONE local `yaw`, assigned to both `hitbox.rotation.y` and `mesh.rotation.y`. Exactly one CODE occurrence of `atan2` in `src/` — the hoisted `var yaw :=` line in `hero.gd`; the only other textual match is its own doc comment (review R1 correction of the original "exactly one line" grep claim). The single-yaw-source contract holds. `@onready var mesh` added alongside the existing `hitbox` ref. Root never rotates — N1 respected: `Collision` and `Hurtbox` untouched.
- AC 2 — marker: `FacingMarker` (MeshInstance3D) authored as a child of `Mesh` in `hero.tscn`, a `PrismMesh` sub-resource (0.4 × 0.3 × 0.25) rotated so the prism apex points local +Z (the hitbox-reach direction), offset (0, 0.5, 0.65) — flush against the body box front face. Sub-resource primitives only, no new assets, no import pipeline.
- AC 3 — presentation-only, golden NONE: nothing under `src/state/`, no `project.godot` edit, no new autoload, no snapshot change. Golden measured before AND after — identical (Debug Log above).
- AC 4 — inherited semantics, zero new logic: no mesh-side facing memory written; persistence after release is pinned by the integration test's third phase (yaw holds 3.141593 across 15 zero-input frames). Per-slot generic via `drive()`; the NullController dummy stays at initial facing by the same code path.
- AC 5 — test pin: NEW `test/integration/test_visible_facing.gd` (existing single-scenario scripts each pin a different contract; a multi-phase two-direction scenario did not fit any without rewriting its documented purpose — the story's new-file route taken, `.uid` duty done per N3). Two real Input presses (`p1_move_right` → π/2, `p1_move_up` → π); per phase asserts mesh yaw == hitbox yaw (primary truthful-display pin), == expected mapping derived from the pressed direction under the identity basis (N2 — no HeroState handle), root basis identity; after release, yaw persists. Yaw comparison approximate and angle-aware (`angle_difference`, eps 0.001), per N2.
- Manual smoke check: NOT claimed at the dev pass — it cannot be performed headless. Left unticked then; performed by the operator (Matko) at review — see the following note.
- Operator playtest (2026-07-26) PASSED — the marker visibly leads the body through all eight keyboard directions; orientation persists on stop; the dummy never turns; live aim now governs damage — facing away from the dummy in range deals nothing, facing it lands hits (the exact capability this story existed to create); the marker is legible from the fixed camera. Operator note for the record: eight-way facing is a KEYBOARD limitation, not a system one — facing is continuous (world-space Vector2 through one atan2); full-360 facing arrives with analog input in story 2-2 (gamepad profiles), and the state layer already accepts analog vectors (test_analog_input_clamped_to_move_speed). No new obligation.
- N4 respected: `test/state/test_contact_resolution.gd` untouched (out of scope by design).

### File List

- `src/actors/hero/hero.gd` (modified — hoisted single `yaw` local applied to both `Hitbox` and `Mesh`; `@onready` mesh ref)
- `src/actors/hero/hero.tscn` (modified — `PrismMesh_fmark` sub-resource + `FacingMarker` node under `Mesh`)
- `test/integration/test_visible_facing.gd` (new — AC 5 integration pin)
- `test/integration/test_visible_facing.gd.uid` (new — editor-scan-generated sidecar for the new test)

## Change Log

- 2026-07-26: Story authored from the 1-7 close-out playtest finding (facing invisible in live play) on the 1-3c make-state-visible model; presentation-only, single-yaw-source contract, golden prediction NONE. Status: backlog.
- 2026-07-26: Readiness gate READY (zero blocking, four advisories N1–N4 recorded above); promoted backlog -> ready-for-dev.
- 2026-07-26: Dev pass complete (Claude Fable 5). Mesh yaw joined to the hitbox yaw via ONE hoisted value in `drive()`; `FacingMarker` prism authored under `Mesh` in `hero.tscn`; new integration pin `test_visible_facing.gd` (+`.uid`). State harness 115/543 green before and after, golden `39564e83…5353` measured IDENTICAL both directions; all 7 integration tests green individually. Manual smoke check deferred to operator at review (headless session). Status: ready-for-dev -> review.
- 2026-07-26: Review passed — operator smoke check PASSED (marker leads the body in all eight keyboard directions, yaw persists on stop, dummy never turns, live aim governs damage); R1 cosmetic fix to the AC 1 grep claim (exactly one CODE occurrence of `atan2` in `src/`; the other textual match is its own doc comment). Status stays review until close-out.
