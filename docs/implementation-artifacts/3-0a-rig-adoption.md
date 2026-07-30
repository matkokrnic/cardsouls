# Story 3.0a: Rig adoption

Status: backlog

## Story

As a solo developer building CardSouls,
I want `hero.tscn` to carry a real skinned paladin model and an `AnimationPlayer` with six Mixamo animations driven by `ActionState`,
so that the two heroes read as fighting characters instead of placeholder boxes — with zero changes under `src/state/` and DECISION A (the hero root never rotates) left intact.

## Acceptance Criteria

1. **Assets committed to the repo.** `assets/characters/paladin/` contains `paladin.fbx` plus the six animation clips `idle.fbx`, `run.fbx`, `attack.fbx`, `block.fbx`, `roll.fbx`, `death.fbx` and three PNG textures, committed **directly to git** — no LFS, ~11.4 MB total. Source and licence are recorded in this story's Dev Notes: Mixamo, commercial use permitted.

2. **Import is clean — no manual corrections.** The model imports at `root_scale = 1.0` (hero ≈ 1.8 units tall); no asset requires a `BoneMap` or retargeting (the same skeleton throughout); no `.import` file carries a hand-edited scale. Scale is **never** corrected on a node or in code — if the hero is the wrong size, the fix is the source asset, never a compensating transform.

3. **`hero.tscn` carries the paladin and a six-clip `AnimationPlayer`.** The placeholder `Mesh` node (the `BoxMesh_6plks` box body) is **DELETED, not hidden**. The scene gains the skinned paladin and an `AnimationPlayer` holding **exactly six** animations named `idle`, `run`, `attack`, `block`, `roll`, `death`; loop **enabled** for `idle`/`run`/`block`, **disabled** for `attack`/`roll`/`death`. The model's own `mixamo_com` T-pose clip (the single Mixamo take embedded in `paladin.fbx`) must **NOT** end up in this `AnimationPlayer` — "exactly six" means six; the exclusion route is named in Dev Notes. The `.tscn` edit is made **TEXTUALLY with the Godot editor CLOSED** (standing repo rule), with `git diff` checked after every edit.

4. **`animation_controller.gd` — presentation only.** A new `src/actors/hero/animation_controller.gd` listens on the action-state seam (`match_runner.connect_hero_action_state_changed` → the hero's `action_state_changed(previous, current)` signal) and plays the matching clip. It follows `telegraph_controller.gd`'s pattern: a per-hero read-only node in `hero.tscn`, exposed on `HeroActor`, wired by the runner at match start — signal payloads only, never a state handle, never a mutator call, no `_physics_process` (F1). **Locomotion source.** The enum has **no `MOVING`/locomotion `ActionState`** (`IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING, DEAD`) — a running hero is `IDLE` with non-zero velocity. So the **five ActionState-driven clips — `idle`, `attack`, `block`, `roll`, `death` — are selected from the seam**, and the sixth, `run`, is selected **presentation-locally from the hero's own velocity magnitude while the state is `IDLE`** (the actor's `CharacterBody3D.velocity`, set each tick by `drive()`). This adds **no new seam, no state handle, and no eighth observation seam**. The velocity threshold is **NOT authored or tuned in this story** (that is 3-0b); adoption needs only a working selection. `DEFLECT` is **not** an `ActionState` and gets no branch of its own — the block pose covers it. `STUNNED` is not mapped (zero inbound edges). `src/state/` is **byte-identical** at the end of the pass — a checkable claim, not a promise.

5. **DECISION A survives.** `test/integration/test_root_rotation_isolation.gd` stays green; yaw keeps its **single seat** — the one `atan2(hero_state.facing.x, hero_state.facing.y)` in `HeroActor.drive()` (`src/actors/hero/hero.gd`), assigned to both the hitbox and the mesh, is unchanged and no second `atan2` is introduced. The paladin hangs on the **same child node the placeholder hung on** (the yaw sink `drive()` rotates); the hero **root never rotates**. If the skinned model needs its own wrapper node, that is recorded as a micro-decision in the Dev Agent Record.

6. **Zero root motion.** None of the six clips translates the mesh relative to its parent. `roll` and `run` required an **In Place** re-download from Mixamo to achieve this; the other four were clean as first downloaded — recorded in Dev Notes as history so the files are explained.

7. **Golden Prediction: NONE, measured in BOTH directions (seventh time).** The rig touches no `src/state/`, so no snapshot may move: `test_state_matches_golden` stays green at `338172010a…21da2` before **and** after. The suite stays at the Debug-Log baseline (164 state tests / 760 assertions / 0 failed; 9 integration files individually green) — or every deviation is named separately.

## Tasks / Subtasks

- [ ] Commit the rig assets under `assets/characters/paladin/` — `paladin.fbx`, the six clips, three PNGs, no LFS — with the code chain (NOT this docs commit); record Mixamo source + commercial licence in Dev Notes (AC: 1)
- [ ] Verify the import: `root_scale = 1.0`, ≈1.8 units tall, one skeleton (no BoneMap / retarget), no hand-edited scale in any `.import` (AC: 2)
- [ ] Edit `hero.tscn` TEXTUALLY, editor CLOSED: delete the placeholder `Mesh` node; add the skinned paladin and an `AnimationPlayer` with the six named clips; set loop on `idle`/`run`/`block`, off on `attack`/`roll`/`death`; `git diff` after every edit (AC: 3)
- [ ] Add `src/actors/hero/animation_controller.gd` following the `telegraph_controller.gd` pattern; wire it through `connect_hero_action_state_changed` in the runner; select `idle`/`attack`/`block`/`roll`/`death` from the seam and `run` from the actor's velocity magnitude while `IDLE` (no new seam, no state handle, no eighth seam); no `DEFLECT`/`STUNNED` branch; prove `src/state/` byte-identical (AC: 4)
- [ ] Confirm DECISION A: `test_root_rotation_isolation.gd` green; single `atan2` seat in `drive()` untouched; paladin on the placeholder's yaw-sink node; record any wrapper-node micro-decision (AC: 5)
- [ ] Confirm zero root motion on all six clips; note the `roll`/`run` In-Place re-download history in Dev Notes (AC: 6)
- [ ] Measure golden BOTH directions (before/after); confirm hash unmoved and the suite at baseline, or name every deviation (AC: 7)

## Dev Notes

- **Mixamo animation durations do NOT line up with the authored tick windows** (the attack window, `roll_duration`). This is expected and is left untouched in adoption — reconciling clip length against authored timing is **3-0b**'s work (the feel-and-timing-tuning story, DEBT E). This story adopts the substrate; it renders no verdict on feel, legibility, or timing.
- **Opening the Godot editor deletes the `common/physics_ticks_per_second=60` pin from `project.godot` and reorders `config/features`.** This is not a fault — it is expected editor collateral, the **fifth recorded incident**. Check `git status` after every editor scan and **restore `project.godot`**; that pin is what holds the deterministic tick at 60. No `project.godot` change of any kind belongs in this story.
- **The rig assets are currently untracked** (`assets/characters/` in `git status`). They are committed **with the code chain**, not with the docs commit that creates this story file.
- **Source and licence (AC 1):** the paladin model, its skeleton, and the six clips come from **Mixamo**; commercial use is permitted. Recorded here so the provenance travels with the story.
- **The action-state seam (AC 4):** the runner exposes `connect_hero_action_state_changed(slot: int, callback: Callable)` (`src/main/match_runner.gd`), which connects the callback to the owning `HeroState.action_state_changed(previous, current)` signal — the D5 queued channel drained after `advance()`. `telegraph_controller.gd` (`src/actors/hero/telegraph_controller.gd`, a `Node3D` child of `HeroActor`, exposed as `actor.telegraph_controller`, constructed in `hero.tscn` and wired by the runner's per-slot loop in `_ready()`) is the pattern `animation_controller.gd` follows: a read-only presentation consumer with no identity and no `_physics_process`.
- **The one clip chosen by something other than `ActionState` (AC 4):** `run`. Every other clip maps 1:1 from an `ActionState` through the seam; `run` is the sole exception, chosen presentation-locally from the hero actor's velocity magnitude (`CharacterBody3D.velocity`, set each tick in `HeroActor.drive()` — `hero.gd:26`) while the state is `IDLE`, because `HeroState.ActionState` has no `MOVING` member (`hero_state.gd:27`). No new seam, no state handle, no eighth observation seam. The threshold value is 3-0b's to tune; adoption only needs the selection to work.
- **Keeping the model's `mixamo_com` T-pose out of the hero's six clips (AC 3):** `paladin.fbx` embeds a single Mixamo take named `mixamo.com` (confirmed in the source FBX; Godot sanitizes the dot to give the clip `mixamo_com`). The supported route the engine offers is the model's own import setting `animation/import` in `paladin.fbx.import` (`[params]`, currently `true`): set it to **`false`** so the model imports mesh + skeleton only — no `AnimationPlayer`, no `mixamo_com` — and the six clips come from the six separate animation FBX files, assembled into one hero `AnimationPlayer`. (The imported `.scn` is RSCC-compressed, so the clip name is not greppable in the cache; the source take name plus `animation/import=true` are the content evidence.) This `.import` change lands with the code/asset chain, not with this docs commit.
- **The placeholder being deleted (AC 3/5):** today `hero.tscn` carries `[node name="Mesh" type="MeshInstance3D" parent="."]` with `mesh = SubResource("BoxMesh_6plks")` (a 1×2×1 box), plus a `FacingMarker` child. `HeroActor.drive()` yaws this node via `mesh.rotation.y = yaw` — it is the display yaw sink, and `@onready var mesh: MeshInstance3D = $Mesh` in `hero.gd` reads it. Whatever carries the paladin must remain that same yaw sink so `drive()`'s single `atan2` still drives the visible body; adjusting the `$Mesh` reference / type in `hero.gd` is in-scope (it is `src/actors/`, not `src/state/`).
- **DEBT E is triggered but NOT paid here.** This story lands the rig substrate and the DECISION-A / zero-root-motion / golden guards only. The five DEBT E judgments (timing, multiplier legibility, lunge root motion, legibility under 0.5 s, OPEN decision (c)), plus deterministic step/pause and the window countdown, all belong to **3-0b**.

### Non-goals (hard)

These belong to 3-0b (feel-and-timing-tuning) and MUST NOT appear in this story: tuning of durations, speeds, or multipliers; any legibility judgment; deterministic step/pause; the window countdown; blend spaces; new Input Map actions; **any** `project.godot` change.

### Project Structure Notes

- `assets/characters/paladin/` — new asset directory (the untracked `assets/characters/` becomes this), committed with the code chain.
- `src/actors/hero/hero.tscn` — placeholder `Mesh` deleted; skinned paladin + six-clip `AnimationPlayer` added; textual edit, editor closed.
- `src/actors/hero/animation_controller.gd` — NEW, per-hero presentation node following the `telegraph_controller.gd` pattern.
- `src/actors/hero/hero.gd` — `$Mesh` yaw-sink reference adjusted if the paladin's node name/type differs; `drive()`'s single `atan2` seat unchanged.
- `src/main/match_runner.gd` — wire the new `animation_controller` through `connect_hero_action_state_changed`, mirroring the telegraph controller wiring.
- `src/state/` — UNTOUCHED, byte-identical (AC 4/7).

### Project Context Rules

- **`Input.*` only under `src/controllers/`; no global RNG / `Time` / `OS` / `Engine` in `src/state/`.** [Source: docs/game-architecture.md — invariants D3, A2]
- **Exactly one `_physics_process` in `src/`, in `match_runner.gd` (F1).** The new `animation_controller.gd` adds none. [Source: docs/game-architecture.md — invariant F1]
- **Presentation reads state through the runner-wired signal seams; visuals → state is the only allowed dependency direction — never a state handle, never a mutator.** [Source: docs/project-context.md — Signals over polling; Architectural Boundaries]
- **`.tscn` edits are textual with the editor closed; `git status` is checked after any editor scan and `project.godot` restored.** [Source: CLAUDE.md — Git discipline; standing repo rule]

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md — E3 committed obligations (rig-adoption / feel-and-timing DEBT E split, E3-P/R2)]
- [Source: docs/implementation-artifacts/sprint-status.yaml — story_notes: 3-0a-rig-adoption]
- [Source: docs/implementation-artifacts/2-6-legibility-feel-instrumentation.md — 2-6/R3 (deterministic step/pause re-homed to the rig story), 2-6/R7 (window countdown deferred)]
- [Source: src/actors/hero/hero.gd; src/actors/hero/hero.tscn; src/actors/hero/telegraph_controller.gd — DECISION A, single-yaw seat, telegraph pattern]
- [Source: src/main/match_runner.gd#connect_hero_action_state_changed — the action-state seam]
- [Source: test/integration/test_root_rotation_isolation.gd — DECISION A guard]
- [Source: test/state/test_determinism.gd — golden hash constant]

## Golden Hash

- **Current:** `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, unmoved since story 1-9.
- **Prediction: NONE, to be MEASURED IN BOTH DIRECTIONS during the dev pass (the seventh time this prediction is made).** The rig is entirely presentation + assets; it touches no `src/state/` and adds no `MatchState.to_snapshot()` field, so no snapshot may move.
- **Baseline to hold:** 164 state tests / 760 assertions / 0 failed, plus 9 integration files run INDIVIDUALLY, all green (measured at story creation; golden green). Any deviation is named separately at the dev pass — the suite does not silently drift.

## Live Smoke

- Runs on the shipped default configuration (`slot_controller_kinds = [0, 1]`, two live killable humans) — **no `.tscn` flip, no manual edit of any kind**. The shipped default is already two keyboard slots, so both heroes act without a flip.
- **What is checked:**
  - All six animations fire on the correct `ActionState`s (idle / run / attack / block / roll / death).
  - The corpse **stays down** — the `death` clip holds (loop off), no re-idle.
  - **DEFLECT visually borrows the block pose without a snap** — a deflect reads as a block, since `DEFLECT` has no clip of its own.
  - **60 fps holds with two skinned characters** on screen at once.
- **R-D6 acceptance is RE-INVOKED** (live killable human slots) and becomes SPENT again only on a pass.
- The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent writes it on the operator's behalf.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-30 | 0.1 | Story created (backlog): rig-adoption ACs 1-7, Golden Hash + Live Smoke sections, DECISION-A / zero-root-motion / golden guards; locomotion source named (no `MOVING` state — `run` chosen from velocity while `IDLE`); `mixamo_com` T-pose exclusion route named. | Claude Opus 4.8 |
