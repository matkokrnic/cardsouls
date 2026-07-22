---
baseline_commit: 6452e896bd478b9919fa66f8bfb43729164e696c
---

# Story 1.2: Camera rig + camera-relative movement as a pushed spatial fact

Status: review

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

- [x] Build the camera rig on the hero scene (AC: 1)
  - [x] Create the camera config resource: a small `Resource` script + authored `.tres` under `data/` holding the camera framing values (distance/height/pitch), loaded **once** at match setup
- [x] Add the per-slot camera-basis spatial fact to runner step 2 (AC: 2)
  - [x] Store as a fixed-size per-slot array in `MatchState`; never one global basis
- [x] Rotate `move_dir` by the per-slot basis inside `advance()` (AC: 3)
  - [x] Yaw only; write world-space result into `HeroState.velocity`
- [x] Define identity-default behaviour when no basis pushed (AC: 4)
- [x] Tests (AC: 5, 6)
  - [x] Headless: known basis → expected world velocity; pitch ignored
  - [x] Integration: rotate camera, forward intent, displacement follows camera
  - [x] Smoke: authored camera config `.tres` loads; its values reach the rig

## Dev Notes

- **SEAM CHOICE 2 — camera basis is per-slot from day one.** Sizing the basis fact per player slot now is what keeps E2 split-screen a config change rather than a refactor. Do **not** push one shared/global basis. [Source: stories-manual-e1.md#E1.S2 item 2]
- Camera-relative movement is a **pushed fact**, the only F1-consistent resolution. The two tempting shortcuts are both defects: **state reading the camera** breaks D3; **the runner rotating velocity after reading it** makes the field no longer the real velocity and makes replay depend on presentation state. [Source: docs/game-architecture.md#Spatial Model — Camera-relative movement is a pushed fact]
- Yaw-only rotation: the camera's pitch must never tilt movement.
- **Camera framing is presentation config, not combat balance.** Distance/height/pitch live in a dedicated camera config resource (own small script + authored `.tres` under `data/`, per the data-as-resources convention), loaded **once** at match setup — deliberately outside `BalanceConfig` and outside the X3 hot-reload path (load-once). This keeps story 1-1's "all E1 melee fields" claim intact.
- **Camera rotation input is OUT OF SCOPE for this story and for E1.** The GDD Input Map defines no camera-look action and the camera orientation is fixed; the basis changes only programmatically (tests push non-identity bases). When a later story introduces a look action, it MUST flow controller → `InputIntent.aim` → runner → rig; the rig never reads `Input.*` directly (invariant D3(a)).
- **Snapshot/determinism contract:** the per-slot camera basis is an input-like pushed fact — the same category as `InputIntent` — and is **EXCLUDED from `to_snapshot()`**. The default is identity (AC 4), so the existing golden-hash determinism regression is unchanged and must **NOT** be re-baselined. While the camera is fixed (all of E1) the basis is deterministic, so the X5 replay contract is unaffected; once camera look becomes input-driven, that input enters the recorded intent stream, keeping replays reproducible.
- **DECISION A (review follow-up, load-bearing):** while the camera is fixed (all of E1) the hero ROOT must never be rotated — body/facing rotation belongs on a child mesh node — because the rig is a child of the root and root rotation would fold into the pushed camera basis, breaking camera-relative "forward"; the runner reads the rig's LOCAL basis and `test/integration/test_root_rotation_isolation.gd` enforces the isolation. A later story needing a rotating root must decouple the rig deliberately (deferred DECISION B).

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

Claude Fable 5 (claude-fable-5) via Claude Code / gds-dev-story.

### Debug Log References

- Full suite green: `bash test/run_all.sh` → state harness 43 tests / 155 assertions PASS (7 new: 6 in `test_camera_basis.gd` + 1 smoke in `test_data_resources.gd`); both integration tests PASS (`test_camera_relative.gd` new, `test_hero_movement.gd` unchanged and still green).
- **Golden hash unchanged and NOT re-baselined:** `test_determinism.gd` has a zero diff, `GOLDEN` remains `253ab157993a57520409e09378822f62814a2bb9c668bb79fe08fd327ec2c832`, and `test_state_matches_golden` passes against it. The identity path is a structural short-circuit to the exact E0 expression, not an epsilon-equal rewrite.
- One test-authoring bug found and fixed during implementation (not a product bug): in `SceneTree --script` mode, `_ready` fires only after `_initialize` returns, so the integration smoke check initially read the rig camera before `apply_config` ran. Moved the smoke read into the frame loop (frame 5, alongside the input press, which already had the same constraint).
- **Review follow-up (DECISION A) — bite verified both directions:** `test_root_rotation_isolation.gd` was run against the original `global_transform.basis` push first and FAILED as required (root yaw 60° bled into movement: dx=−2.165, dz=−1.250 — exactly the forward vector rotated by the root yaw); after switching the runner to the rig's LOCAL basis it PASSES (dx=0.000000, dz=−2.500000 — fully isolated).

### Completion Notes List

- **AC 1:** `CameraRig` (`src/actors/hero/camera_rig.gd`, Node3D) added to `hero.tscn` with a child `Camera3D`. The rig is the YAW pivot; pitch is applied to the child camera, so the basis the runner reads is yaw-only by construction (state still flattens defensively). No `_physics_process`; follows the hero via the scene tree. Framing (distance 6.0 / height 3.0 / pitch −20° — first-guess, presentation-tunable) is authored in `data/camera_config.tres` via `CameraConfig` (`src/actors/hero/camera_config.gd`, zero defaults so no framing literal lives in code), loaded once at scene setup by the rig itself — keeping "the runner's only interaction with the rig is reading its basis" literally true.
- **AC 2:** runner step 2 pushes each rig's LOCAL basis (`_p1_rig.basis`/`_p2_rig.basis` — see DECISION A) via `MatchState.set_camera_basis(slot, basis)` into a fixed two-slot `Array[Basis]` (out-of-range slot hard-errors). Never one shared/global basis.
- **AC 3:** `_resolve_movement(player, intent, slot)` rotates `move_dir` by the slot's basis, yaw-only (`_camera_relative_dir` flattens the basis right/back columns onto XZ and renormalizes — pitch mathematically cannot tilt or shrink movement; a degenerate straight-down basis falls back to world-space instead of NaN). `HeroState.velocity` remains the real world velocity; the runner/actor consume it untouched.
- **AC 4:** identity basis short-circuits to the exact E0 expression `Vector3(dir.x, 0.0, dir.y)` — bit-identical pass-through, which is why the golden cannot move (proven by the unchanged passing golden test).
- **AC 5:** headless (`test_camera_basis.gd`): known yaw basis → expected world velocity; pitched basis → identical velocity, `velocity.y == 0`; per-slot isolation (P2 stays world-space when only slot 0 is pushed); degenerate-pitch fallback; snapshot-exclusion (snapshot deep-equal before/after pushing bases). Integration (`test_camera_relative.gd`): rig rotated 90° yaw **programmatically**, `p1_move_up` held → hero displaces along world −X (camera forward) with no −Z drift; plus the rig smoke (authored `.tres` values present on the rig camera). `.tres` load smoke added to `test_data_resources.gd`.
- **AC 6:** no state code references the camera (state only receives pushed `Basis` values); the runner assigns nothing to velocity — `HeroActor.drive()` still copies `hero_state.velocity` verbatim. `Input.*` unchanged (controllers only); no Input Map action, keybind, or `project.godot` edit anywhere in the diff.
- **Scene note (flagging for review):** the old fixed global `Main/Camera3D` was **removed** from `main.tscn` and P1's rig camera is made `current` via an editable-children instance override — AC 1 makes the rig *the* game camera, and leaving two camera systems would have left the authored framing unrendered. This is the one judgment call beyond the literal task text; scene diff is 6 lines and easy to revert if you'd rather keep the old camera this story.
- **Facing note:** `HeroState.facing` still stores the raw intent-space direction (pre-rotation), as before — rotating facing was not tasked and would have touched the snapshot. Worth a look when a later story consumes facing for attacks.
- **Parked debts honored:** no `apply_balance` wiring, no balance injection, no cached `BalanceTicks` reference, no reload trigger — the 1-1 debts in the decision log stay parked. `sprint-status.yaml` untouched (its locked lifecycle has no in-progress/review states; board flips are Matko's manual step).
- **DECISION A (review follow-up):** the runner pushes the rig's **LOCAL** basis (`_p1_rig.basis`), not `global_transform.basis` — the rig is a child of the hero root, and the global read would fold a (forbidden while the camera is fixed) root rotation into "camera forward". Constraint documented at the `set_camera_basis` seam, in the rig header, and in Dev Notes (Dev Notes line added at Matko's explicit direction); enforced by the new integration guard, which exercises the REAL runner push path. Rig-decoupling for a future rotating root is deferred (DECISION B). Note the local read also makes the identity fast-path exact by definition (no parent-transform float chain).

### File List

- `src/actors/hero/camera_config.gd` (new, + `.uid` — `CameraConfig` resource script)
- `src/actors/hero/camera_rig.gd` (new, + `.uid` — `CameraRig` node script)
- `src/actors/hero/hero.tscn` (modified — CameraRig + Camera3D nodes added)
- `src/main/main.tscn` (modified — global Camera3D removed; P1 rig camera `current = true` via instance override)
- `src/main/match_runner.gd` (modified — rig refs; step 2 pushes per-slot bases)
- `src/state/match_state.gd` (modified — `_camera_bases`, `set_camera_basis`, slot-aware `_resolve_movement`, `_camera_relative_dir`)
- `data/camera_config.tres` (new — authored framing values)
- `test/state/test_camera_basis.gd` (new, + `.uid` — 6 headless tests)
- `test/state/test_data_resources.gd` (modified — camera config smoke test)
- `test/integration/test_camera_relative.gd` (new, + `.uid` — rig smoke + camera-follow displacement)
- `test/integration/test_root_rotation_isolation.gd` (new, + `.uid` — DECISION A guard: root rotation must not bleed into the pushed basis)
- `docs/implementation-artifacts/1-2-camera-relative-movement-basis.md` (this story record)

## Change Log

- 2026-07-23: Story 1-2 implemented — CameraRig + CameraConfig `.tres` (presentation config, load-once, not X3), per-slot camera basis pushed by runner step 2, yaw-only camera-relative `move_dir` rotation with exact identity pass-through. 7 new headless tests + 1 new integration test; full suite green; determinism golden byte-identical (not re-baselined). Status → review.
- 2026-07-23: Review follow-up (DECISION A) — runner pushes the rig's LOCAL basis so hero-root rotation can never fold into the camera basis; constraint documented at the seam + Dev Notes; new integration guard `test_root_rotation_isolation.gd` (bite verified: FAILS on a global-basis push, PASSES on local). Golden still byte-identical.
