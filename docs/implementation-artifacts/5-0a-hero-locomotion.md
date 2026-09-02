---
baseline_commit: 15ea83c0979b8d3448e1d46c77c4ce685b1a4b76
---

# Story 5.0a: Hero locomotion

Status: done

## What this story inherits

This is the hero half of DEBT E (decision-log Session 2026-09-01 "E4 close-out",
`:7856-7860`), on the `3-0a-rig-adoption` / `3-0b-feel-and-timing-tuning` / `4-3c-minion-rig-adoption`
rig-story precedent — each prior rig story is inherited BY NAME, not rediscovered; see Dev Notes for
exactly which ruling each borrowed mechanism follows. `E5-P/R5` (decision-log:8176-8209) ratifies this
as the FIRST of twelve E5 stories, Tier B, **at-risk**: "hero half of DEBT E (hitboxes that do not
follow bones is a contact-geometry change; measure early)." `epics.md:173-176` locks the board order —
`5-0a` opens E5 and must land before the playtest block, alongside `5-0b-pad-card-input`.

**Motivating defect**, named at the E4 close-out (`decision-log.md:7856-7860`, echoed
`:8058-8061`): since `4-6-camera-lock-on` shipped, sideways movement while locked reads as
floating/skating — facing is pinned to the locked target, but the legs keep playing the forward `run`
clip regardless of which way the hero is actually moving relative to that facing. The hero also has no
strafe or backpedal clips at all today (only `idle`/`run`/`attack`/`block`/`roll`/`death`,
`hero.tscn:59-65`), and the melee `Hitbox` is a static root-relative box (`hero.tscn:73-81`) rather than
something that tracks the sword/weapon bone — both gaps the E4 close-out named without an owner until
now (`decision-log.md:7891-7893` — "Art assignments... Hero rig DEBT E (hero half) + strafe/backpedal
clips -> `5-0a`").

## Story

As a player,
I want the hero's legs to play the clip that matches the direction I'm actually moving relative to my
facing (forward run / strafe left / strafe right / backpedal) instead of always playing `run`, and I
want the melee hitbox to travel with the weapon instead of sitting in a fixed box relative to the root,
so that sideways and backward movement while locked on reads as real strafing/backpedaling rather than
skating, and the visible reach of an attack matches where the sword actually lands.

## Acceptance Criteria

1. **Three new locomotion clips join the paladin's `AnimationLibrary`.** `strafe_left.fbx`,
   `strafe_right.fbx`, and `backpedal.fbx` are already renamed and sitting untracked in
   `assets/characters/paladin/` (Mixamo, downloaded **In Place**, per the operator's resolved mapping:
   "Sword And Shield Strafe" -> `strafe_right.fbx`, "Sword And Shield Strafe (1)" -> `strafe_left.fbx`,
   "Sword And Shield Run (2)" -> `backpedal.fbx`, confirmed running backward — the left/right assignment
   is operator-verified, not provisional). Import is clean on the `3-0a` AC2 precedent applied
   verbatim: `root_scale = 1.0`, no `BoneMap`/retarget, no hand-edited scale in any `.import`. Each
   clip's `EditorScenePostImport` hook (`strip_model_anim.gd`, already wired for the paladin's other
   six source files) applies to these three the same way, keeping the model's own bundled
   `mixamo_com` take out of the assembled library. The three clips are added into
   `paladin_anims.res` by a **headless GDScript** that loads/extends the `AnimationLibrary` and
   saves it with `ResourceSaver` — the `3-0a` assembly route, not the editor UI; editor sessions in
   this pass are authorized only for `.fbx` import and `.uid`/class-cache scans, growing the library
   from six named animations to **nine**:
   `idle`, `run`, `attack`, `block`, `roll`, `death`, `strafe_left`, `strafe_right`, `backpedal`.
   **Per-clip `mixamorig_Hips` displacement is MEASURED, not assumed** — same headless-script method
   `3-0a` AC6/R9 used (load the assembled `AnimationLibrary`, read `Animation.track_get_key_value` on
   the Hips position track, first key vs. last key) — record the table in Dev Agent Record.
   `strafe_left`/`strafe_right`/`backpedal` are movement-loop clips and are expected **net-zero** on
   the `3-0a` precedent for `idle`/`run`/`block` (a looping clip that does not return to its start
   point accumulates drift every repeat, the defect class `3-0a`/R9 fixed for `roll` and `run` by
   re-downloading In Place). **A clip found NOT net-zero is NOT a code fix** — per this pass's own
   instruction, the operator re-downloads that specific clip; do not attempt to zero the Hips track in
   the animation editor as a workaround (that route belongs to `3-0b`-class feel work, out of scope
   here, see Non-Goals). `test_rig_clips.gd` (or its successor) is extended from six to **nine**
   expected clips, with loop flags: `idle`/`run`/`block`/`strafe_left`/`strafe_right`/`backpedal` =
   loop **enabled** (all are repeating movement/idle poses); `attack`/`roll`/`death` = loop **disabled**
   (unchanged). Mutation-proven on the `3-0a` AC3 precedent: a deleted clip and a re-added
   `mixamo_com` clip must each independently fail it, proven against a SHA256-verified out-of-repo
   backup of `paladin_anims.res`, restored by copy-back, never `git checkout --`.

2. **Clip selection extends from speed-magnitude-only to DIRECTION of movement relative to facing —
   presentation-only, no new seam, no new process, no state edit.** Today `AnimationController.
   on_locomotion(speed: float)` (`animation_controller.gd:85-88`) is pushed a single scalar from
   `HeroActor.drive()` (`hero.gd:47`, `velocity.length()`) every tick, and while `IDLE` it picks `run`
   vs `idle` purely on that magnitude against `RUN_SPEED_EPS`. This AC replaces that two-way split with
   a five-way one (`idle` / `run` / `strafe_left` / `strafe_right` / `backpedal`) driven by the
   direction of `HeroState.velocity` **relative to `HeroState.facing`** — both values `drive()` already
   has in scope (`facing` is read on the same line that computes the shared yaw for the Hitbox/Mesh,
   `hero.gd:40`; `velocity` is assigned at the top of `drive()`, `hero.gd:32`). **No new seam**: the
   push still rides `HeroActor.drive()`'s existing per-tick call into `AnimationController`, the
   identical mechanism `3-0a`/R2 established for the `run` clip and `4-3c` reused for the minion's
   idle/walk split — extend the payload of the existing call (e.g. pass the velocity vector and facing,
   or a pre-resolved forward/right component pair), never add a second push or a new `_process`. **No
   new state field**: `HeroState.velocity` and `HeroState.facing` already exist and are already read by
   `drive()`; this AC adds no `BalanceConfig` field and no snapshot key. **The single-yaw-source
   contract is untouched**: `drive()` still computes exactly one `atan2(facing.x, facing.y)` and feeds
   both the Hitbox and the Mesh (`hero.gd:40-42`, `docs/game-architecture.md:1001-1004`) — direction-aware
   clip selection is a presentation READ of the same two values, not a second yaw computation, and must
   not introduce one. The angle bands that separate "forward" from "strafe" from "backpedal" (and any
   dead-zone near the boundaries) are an implementation detail, not a design decision — the four
   directions are already fixed by the epics/decision-log obligation; picking exact degree thresholds
   is dev-pass discretion, left **untuned** on the same `RUN_SPEED_EPS`/`4-3c` "adoption only needs a
   working split" precedent (feel tuning is explicitly out of scope, see Non-Goals). **Switches
   BETWEEN locomotion clips** (`idle`/`run`/`strafe_left`/`strafe_right`/`backpedal`) use a short
   fixed crossfade via `play()`'s `custom_blend` parameter — a small constant, left untuned, the
   same class of adoption-only decision as the angle bands above; a full 2D blend space is
   explicitly deferred to a future retune pass (Non-Goals). Action-state transitions
   (`attack`/`block`/`roll`/`death`) are unchanged: they keep the `3-0a`/R5 immediate-win,
   no-blend policy — this AC does not touch that path. `IDLE`-gating is
   unchanged: this only ever fires while `_state == HeroState.ActionState.IDLE` (`animation_controller.
   gd:86-87`), exactly as the current `run` push does — attack/block/roll/death still own the body
   while they persist.

3. **The hero hitbox follows bones instead of the static box — the AT-RISK contact-geometry item,
   named as such at ratification (`E5-P/R5` item 1).** Today `Hitbox` (`hero.tscn:73-81`) is an `Area3D`
   child of the `HeroActor` root at a fixed local offset (`HitboxShape` at local `z 0.9`,
   `hero.tscn:79-81`), rotated only by `HeroActor.drive()`'s single shared yaw
   (`hitbox.rotation.y = yaw`, `hero.gd:41`) — its position never otherwise moves relative to the root,
   regardless of what the arms/weapon are doing in the current attack clip. This AC makes the hitbox
   track the paladin's weapon or hand bone through the swing instead. **Golden Prediction, stated
   explicitly per the gate's instruction, not left implicit:** `test/state/test_determinism.gd` runs
   `MatchState` alone — no runner, no physics, no actor, no `Area3D` (the same structural fact every
   prior rig story's Golden Prediction measured, `3-0a`/`4-3c`) — so a bone-following hitbox is not
   reachable from that fixture at all; **predicted UNMOVED, to be MEASURED in both directions at the
   dev pass, not assumed from this reasoning alone.** The item this AC genuinely puts at risk is NOT
   the golden — it is `test/integration/test_contact_pipeline.gd`, the one integration test that reads
   real hitbox/hurtbox overlap behaviour against the runner's `_gather_contact_facts`
   (`docs/project-context.md:79`, and per this repo's own standing fact: it is parametric and
   self-reschedules kill-hits against whatever geometry actually exists). A hitbox that now sweeps with
   the weapon rather than sitting still changes WHEN, during the swing, it overlaps a hurtbox — the
   dev pass must re-run `test_contact_pipeline.gd` and report whether contact timing shifted, not
   assume the existing pass carries over unchanged. The single-yaw-source contract still applies: the
   Hitbox's yaw is still the one value `drive()` computes, whatever mechanism makes it also track the
   bone (parenting under a `BoneAttachment3D`, or a driven local transform read from the `Skeleton3D`)
   must not introduce a second, independent rotation source. `hero.tscn:77`'s
   `editor_description` documents the current fixed-offset mechanism and must be corrected to describe
   whatever this story ships.

## Non-Goals (explicit)

- **No timing/feel retuning.** Angle-band thresholds for the direction split (AC 2) and any residual
  "does this read right" feel judgment are left untuned, on the `3-0a`/`4-3c` adoption-only precedent —
  a future retune pass owns tightening them, the way `3-0b` tightened `3-0a`'s adoption-level clip
  policy. This story needs only a working four-way split, not a tuned one.
- **No 2D blend space.** Locomotion-clip switches use a small, untuned, fixed `custom_blend`
  crossfade constant (AC 2) — a full 2D blend space (blending multiple clips by movement vector) is
  explicitly deferred to a future retune pass, the same adoption-only precedent as the angle bands.
- **No new `ActionState`.** The five-way clip split (AC 2) is driven entirely by velocity direction
  relative to facing while `IDLE`; it adds no state-machine transition and no new enum value.
- **No minion changes.** The minion half of DEBT E is already discharged (`4-3c-minion-rig-adoption`,
  `done`). This story touches `src/actors/hero/` and `assets/characters/paladin/` only.
- **No card input.** `5-0b-pad-card-input` is the next board story; this one ships no Input Map change
  and no card-facing behaviour.
- **Any change under `src/state/`.** This story reads `HeroState.velocity` and `HeroState.facing`,
  both of which already exist and are already read by `HeroActor.drive()` — it adds no
  `BalanceConfig` field, no snapshot key, and no new state seam.
- **Zeroing a clip's Hips track as a fix for non-net-zero drift (AC 1).** If measurement finds a new
  clip is not net-zero, the fix is a re-download (operator-owned), not an in-editor track edit — that
  workaround belongs to feel-tuning-class work, not adoption.
- **The bone-following hitbox's exact reach/timing tuning.** AC 3 ships the mechanism (hitbox tracks a
  bone); whether its swept reach needs balance-field changes (`attack_reach`-class values) is a
  follow-up judgment, not built here unless the golden/integration measurement forces it.

## Tasks / Subtasks

- [x] Confirm the three renamed clip files (`strafe_left.fbx`, `strafe_right.fbx`, `backpedal.fbx`) in
      `assets/characters/paladin/`; import each with `root_scale = 1.0`, no manual scale correction, and
      the `EditorScenePostImport` hook already wired for the paladin's other clips (AC: 1)
- [x] Assemble the three clips into `paladin_anims.res` with a headless GDScript (load/extend the
      `AnimationLibrary`, save via `ResourceSaver`) — the `3-0a` assembly route, not the editor UI;
      the editor in this pass is authorized only for `.fbx` import and `.uid`/class-cache scans
      (`3-0a`/R3 protocol: hash `project.godot` before/after every editor session in this pass, not
      only at the bookends — `4-3c`'s own precondition finding found the editor deleting the
      `physics_ticks_per_second` pin mid-pass) (AC: 1)
- [x] Measure `mixamorig_Hips` displacement for all three new clips via the `3-0a` AC6/R9 headless
      method; record the full table in Dev Agent Record; flag any non-net-zero clip for operator
      re-download rather than editing the track (AC: 1)
- [x] Extend `test_rig_clips.gd` (or its successor) from six to nine expected clips, updated loop-flag
      table, `mixamo_com`-absence check unchanged; mutation-prove on the `3-0a` AC3 precedent (AC: 1)
- [x] Extend the per-tick push from `HeroActor.drive()` into `AnimationController` to carry direction
      information (velocity relative to facing), not just speed magnitude — same call site, same
      per-tick cadence, no new seam (AC: 2)
- [x] Implement the five-way clip selection (`idle`/`run`/`strafe_left`/`strafe_right`/`backpedal`) in
      `AnimationController`, gated on `IDLE` exactly as today's two-way split is; leave angle-band
      constants untuned but named, on the `RUN_SPEED_EPS` precedent; switch between these clips with
      a short fixed `custom_blend` crossfade (untuned constant); action-state transitions keep the
      `3-0a`/R5 no-blend policy, unchanged (AC: 2)
- [x] Add a headless or integration test asserting the direction-to-clip mapping for at least the four
      cardinal cases (forward / back / left / right, relative to a fixed facing) (AC: 2)
- [x] Make the `Hitbox` `Area3D` (or its `HitboxShape`) track the weapon/hand bone through the swing
      instead of sitting at a fixed root-relative offset; preserve the single-yaw-source contract —
      whatever mechanism is chosen must not add a second independent rotation (AC: 3)
- [x] Update `hero.tscn:77`'s `Hitbox` `editor_description` to describe the shipped bone-following
      mechanism, replacing the now-inaccurate "fixed local offset... rotated only by drive()'s yaw"
      text (AC: 3)
- [x] Measure the golden BOTH directions (before/after); confirm the hash unmoved (AC: Golden
      Prediction)
- [x] Re-run `test_contact_pipeline.gd` and report whether contact timing/outcome shifted from the
      bone-following hitbox; this is the story's real at-risk surface, not the golden (AC: 3, Golden
      Prediction)
- [x] Measure `project.godot` byte-identity both directions, per the `3-0a`/R3 protocol applied with
      the per-editor-session granularity `4-3c` established (Dev Notes)

## Dev Notes

- **This story inherits three prior rig stories by name, not by rediscovery**: `3-0a-rig-adoption`
  (asset committal, `EditorScenePostImport` substitution, the `run`-clip push mechanism, the Hips
  displacement measurement method, the `3-0a`/R3 `project.godot` hash protocol), `3-0b-feel-and-timing-
  tuning` (mid-clip excursion is a legibility question, not a correctness one — the same discipline
  applies to any excursion the three new clips carry), and `4-3c-minion-rig-adoption` (the
  idle/walk-style "push a scalar/vector from an existing per-tick call into a presentation controller,
  no new seam" pattern, and its own vertical-alignment-test precedent for a machine contract on a
  spatial claim). See each file's own Dev Notes/Golden Prediction/Live Smoke sections for the full
  reasoning; this story does not restate their content, only borrows the mechanism.
- **Golden Prediction reasoning, stated rather than assumed.** This story touches no `src/state/` file,
  adds no `BalanceConfig` field, and writes no `MatchState`/`HeroState` snapshot field — every AC is
  scoped to `assets/characters/paladin/` and `src/actors/hero/` (`hero.gd`, `animation_controller.gd`,
  `hero.tscn`). `test/state/test_determinism.gd` runs `MatchState` in isolation with no runner, no
  physics, and no actor of any kind — the identical structural fact `3-0a`'s and `4-3c`'s own Golden
  Predictions measured — so nothing this story ships is reachable from that fixture. **Predicted
  UNMOVED, to be MEASURED IN BOTH DIRECTIONS at the dev pass, not asserted from this reasoning alone**
  — this is the standing Tier B discipline (`E4-P/R9`: "a story that moves the golden is Tier A
  regardless of how much it feels like data authoring"; `E5-P/R5`: "Every Tier B [prediction] is a
  PREDICTION its own gate confirms by measurement, never a lowering"). **AC 3 is the one item at real
  risk of moving something measurable** — not the golden itself (unreachable, as above), but
  `test_contact_pipeline.gd`'s measured contact timing/outcome, since that integration test exercises
  real `Area3D` overlap geometry against the runner's `_gather_contact_facts`. Report the before/after
  there explicitly; a shift is not automatically a defect (the hitbox moving with the weapon is the
  point) but it must be a NAMED, measured change, never silently absorbed.
- **`project.godot` byte-identity**, measured in both directions per the `3-0a`/R3 protocol, hashed
  before and after every editor session in this pass (not only at the bookends) — the `3-0a`/`4-3c`
  precedent of an editor session silently deleting the `common/physics_ticks_per_second=60` pin or
  reordering `config/features` has recurred multiple times across prior rig stories; this pass's asset
  import and `AnimationLibrary` assembly (AC 1) necessarily opens the editor at least once.
- **Single yaw source is a hard invariant, not a suggestion.** `docs/game-architecture.md:1001-1004`:
  "`HeroActor.drive()` computes exactly ONE yaw... a second `atan2` anywhere is a defect." Both AC 2
  (reading facing/velocity presentation-side) and AC 3 (the bone-following hitbox) must consume the
  yaw `drive()` already computes rather than deriving their own — AC 2 needs no rotation at all (it
  reads direction as data, not as a new mesh/hitbox transform), and AC 3's bone-tracking mechanism must
  not add an independent rotation that could drift from the Hitbox/Mesh's shared yaw.

### Project Structure Notes

- `assets/characters/paladin/` — three new clip files (`strafe_left.fbx`, `strafe_right.fbx`,
  `backpedal.fbx`) plus their `.import` sidecars; `paladin_anims.res` grows from six to nine named
  animations. Same artifact shape `3-0a` established, already itemized generically in
  `docs/game-architecture.md`'s Directory Tree (amendment A5) — no further architecture amendment
  needed.
- `src/actors/hero/hero.gd` — `drive()`'s per-tick push to `AnimationController` gains a direction
  payload (velocity relative to facing), replacing the speed-only `on_locomotion(velocity.length())`
  call (`hero.gd:47`) or extending it; no new seam, no second yaw computation.
- `src/actors/hero/animation_controller.gd` — the two-way `run`/`idle` split inside the polled
  locomotion path (`on_locomotion`, `animation_controller.gd:85-88`) becomes a five-way split
  (`idle`/`run`/`strafe_left`/`strafe_right`/`backpedal`); `_CLIP` dictionary and constants extended
  as needed; still gated on `_state == IDLE`, still uses the idempotent `_play()` (never `_restart()`)
  for the polled path, on the existing `3-0a`/R2 idempotency reasoning (re-selecting the already-
  playing clip must be a no-op or it restarts from frame 0 every tick).
- `src/actors/hero/hero.tscn` — `Hitbox`/`HitboxShape` mechanism changed to track a bone instead of a
  fixed root-relative offset; `Hitbox`'s `editor_description` updated to match. `Collision`, `Mesh`,
  `Hurtbox`/`HurtboxShape`, `TelegraphController`, `CameraRig`, `AnimationController` node — all
  UNCHANGED by this story except where AC 3 requires the Hitbox's own transform mechanism to change.
- `src/state/` — UNTOUCHED, byte-identical (Golden Prediction, Non-Goals).
- `test/integration/test_rig_clips.gd` — extended from six to nine clips/loop-flags.
- `test/integration/test_contact_pipeline.gd` — re-run (not necessarily edited) to measure whether
  AC 3 shifted contact timing/outcome; report the result, do not silently assume it carries over.

### Project Context Rules

- **F1 — exactly one `_physics_process`, in `match_runner.gd`.** This story adds none; both new
  behaviours (AC 2, AC 3) are pushed/driven from the runner's existing per-tick `drive()` call.
  [Source: docs/project-context.md:39; CLAUDE.md]
- **HARD RULE — state/visual separation.** `AnimationController` and the Hitbox's bone-following
  mechanism read `HeroState.velocity`/`HeroState.facing` and the skeleton's bone transforms; neither
  writes to state, neither applies damage — the Hitbox still only REPORTS overlap facts, the runner's
  `_gather_contact_facts` still decides what a contact means. [Source: docs/project-context.md:69-73,
  79]
- **World-space facing contract / single yaw source (1-7/1-8 amendment).** `HeroActor.drive()` computes
  exactly one `atan2(facing.x, facing.y)`, feeding both Hitbox and Mesh; a second `atan2` anywhere is a
  defect. [Source: docs/game-architecture.md:997-1004]
- **`.tscn`/config edits are textual with the editor closed; the editor is explicitly authorized only
  for `.fbx` import and `.uid`/class-cache scans** — `AnimationLibrary` assembly is a headless
  GDScript (`ResourceSaver`), the `3-0a` route — under the `3-0a`/R3 protocol (hash `project.godot`
  before/after every session). [Source: CLAUDE.md; 3-0a/R3]
- **Data as Resources — no hardcoded gameplay numbers.** This story authors no new `BalanceConfig`
  field; angle-band thresholds are presentation-only untuned constants, on the `RUN_SPEED_EPS`
  precedent, not a balance field. [Source: docs/project-context.md:62-64]
- **Mutation-proof discipline.** A mutation made to prove `test_rig_clips.gd` non-vacuous is restored
  from a copy taken OUTSIDE the repo, never `git checkout --`. [Source: docs/project-context.md:134]

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:7856-7860,
  7891-7893 — the hero half of DEBT E named and assigned to `5-0a` at the E4 close-out]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8058-8061 — E4-R/R8,
  what E5 inherits, the "floating" read and hitbox-follows-bones gap restated]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8176-8209 — `E5-P/R5`,
  the twelve-story E5 list, order and tiers; item 1 names `5-0a` Tier B at-risk]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:5742-5766 — `E4-P/R9`
  story tier policy, the golden clause]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:173-176 — E5 Committed
  obligations, `5-0a` board position and content]
- [Source: docs/implementation-artifacts/3-0a-rig-adoption.md — asset committal, Hips-displacement
  measurement method (R9), `EditorScenePostImport` substitution (R10), the `run`-clip push mechanism
  (R2), `project.godot` hash protocol (R3), mutation-proof method (AC3)]
- [Source: docs/implementation-artifacts/3-0b-feel-and-timing-tuning.md — mid-clip excursion is a
  legibility question, not correctness; adoption-level clip policy (no blending, transition-wins)]
- [Source: docs/implementation-artifacts/4-3c-minion-rig-adoption.md — the "push a payload from an
  existing per-tick call, no new seam" pattern; its own vertical-alignment machine-contract precedent;
  its Golden Prediction structural argument, reused verbatim here]
- [Source: src/actors/hero/hero.gd:31-48 — `drive()`: shared yaw computation, the existing
  `on_locomotion(velocity.length())` push, `move_and_slide()`]
- [Source: src/actors/hero/animation_controller.gd — the six-clip `_CLIP` map, `on_action_state_changed`
  (evented, `_restart`), `on_locomotion` (polled, `_play`, `RUN_SPEED_EPS`)]
- [Source: src/actors/hero/hero.tscn:73-81 — the current static-box `Hitbox`/`HitboxShape` definition
  and its `editor_description`]
- [Source: src/state/hero_state.gd:82, 87 — `velocity: Vector3`, `facing: Vector2`]
- [Source: docs/game-architecture.md:997-1004 — world-space facing contract, single yaw source]
- [Source: docs/project-context.md:39, 62-64, 69-81, 100-111, 124-144 — F1, Data as Resources, HARD
  RULE state/visual separation, hitbox/hurtbox convention, folder layout, Testing Rules]
- [Source: test/integration/test_rig_clips.gd — the six-clip machine contract this story extends to
  nine]

## Golden Prediction

**Predicted UNMOVED, measured in BOTH directions at the dev pass.** This story is presentation only:
it touches no file under `src/state/`, adds no `BalanceConfig`/`BalanceTicks` field, and writes no
`MatchState`/`HeroState` snapshot field. `test/state/test_determinism.gd` runs `MatchState` in
isolation with no runner, no physics, and no actor of any kind (the identical structural fact
`3-0a`'s and `4-3c`'s own Golden Predictions measured), so nothing this story ships — the three new
clips, the direction-aware clip selection, or the bone-following hitbox — is even reachable from that
fixture.

**The real measurement obligation this story carries is `test_contact_pipeline.gd`, not the golden.**
AC 3 (hitbox follows bones) is named AT-RISK precisely because it changes contact GEOMETRY, and
`test_contact_pipeline.gd` is the one integration test that exercises real `Area3D` overlap timing
against the runner's `_gather_contact_facts` — the dev pass must re-run it and report whether contact
timing/outcome shifted, stated explicitly rather than assumed to carry over from the static-box
baseline. A shift there is not automatically a defect (that is the point of the bone-following hitbox),
but it is a NAMED, measured change per this pass's own instruction.

**`project.godot` byte-identity is ALSO measured in both directions**, hashed before and after every
editor session in this pass (asset import, `AnimationLibrary` assembly), on the `3-0a`/R3 protocol
`4-3c` already tightened to per-session granularity after repeated editor collateral across prior rig
stories.

**Files expected to legitimately change:** `assets/characters/paladin/` (three new clips,
`paladin_anims.res` grows to nine animations), `src/actors/hero/hero.gd`, `src/actors/hero/
animation_controller.gd`, `src/actors/hero/hero.tscn` (`Hitbox` mechanism + its `editor_description`).
`src/state/` is expected byte-identical.

## Live Smoke

**REQUIRED**, Tier B story touching presentation for a live-controlled actor, and the direct answer to
a defect (`4-6` live smoke's "floating" finding) that was observed live in the first place. No `.tscn`
flip needed — the shipped default already gives two live human slots.

Script, scoped to what the motivating defect actually asked to be fixed:

- While locked on (`4-6-camera-lock-on`), moving the stick/keys left or right reads as a genuine
  **strafe** (legs cross-stepping sideways), not the forward `run` clip playing while the body slides
  sideways.
- Moving backward while locked reads as a **backpedal**, not a forward run played in reverse or a
  frozen pose.
- The four-way split does not visibly "pop" or stutter at the direction boundaries during normal
  play — a rough, untuned angle band is acceptable (Non-Goals), but a clip that flickers between two
  choices on small stick movements near a boundary is worth naming as a finding, not silently accepted.
- The bone-following hitbox: does an attack's visible sword swing line up with where damage actually
  lands, better than the static box did? **Named watch item, same class as `3-0a`'s roll-ring finding
  and `4-3c`'s mid-clip-forward-step finding**: a pre-existing mismatch that was always there may
  become newly *visible* once the hitbox moves with a real swing instead of sitting still — if found,
  record it as a measured finding, not assumed a regression this story introduced.
- Watch for the new clips' Hips-track excursion reading as *detached* the way `3-0a`'s `roll` clip did
  once a real body replaced the placeholder box (`3-0a` Live Smoke Results, finding 1) — if a strafe or
  backpedal clip's mid-clip excursion makes the body appear to drift away from the character's actual
  position, name it the same way, non-blocking, feeding a future feel pass.

The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent writes
it on the operator's behalf.

### Live Smoke Results (2026-09-02, pad, flip [0,3])

All six watch items PASS, after the `5-0a/R1` strafe-swap fix (decision-log):

- Strafe reads correctly both directions while locked on. **FIRST pass had left/right visually
  swapped** — the operator's Mixamo-preview mapping was a mirror-class misread (the preview camera
  faces the character); fixed by swapping the two source files' content, re-verified correct
  in-game. See `5-0a/R1`.
- Backpedal correct while locked.
- Diagonal boundary flicker not noticeable.
- Locomotion transitions crossfade cleanly; attack/block/roll stay instant, as designed.
- Attacks land normally on the bone-following hitbox; chained swings restart correctly.
- FPS stable.

Full operator record: `docs/playtest-log.md`, entry dated 2026-09-02.

## Dev Agent Record

### Agent Model Used

Opus 5 (operator-stated)

### Debug Log References

- Suite output, both directions, captured outside the repo:
  `C:\dev\_50a-suite-before.txt` (2026-09-02 00:08:09) and `C:\dev\_50a-suite-after.txt`
  (2026-09-02 00:28:44). Counters read from the files, never through `tail`.
- Hips-displacement table: `godot --headless --path . --script res://tools/measure_hips_displacement.gd`
- Library assembly: `godot --headless --path . --script res://tools/add_paladin_locomotion.gd`

### Completion Notes List

**AC 1 — nine clips, measured.**

- Asset guard passed on entry: the three files were already correctly named
  (`strafe_left.fbx`, `strafe_right.fbx`, `backpedal.fbx`), untracked. No rename was needed;
  the operator's Mixamo mapping was already applied.
- Imported in editor session 1. The three generated `.import` sidecars are **byte-identical in
  `[params]`** to `run.fbx.import` (verified by `diff` on the `[params]` block of each):
  `root_scale = 1.0`, `apply_root_scale = true`, no hand-edited scale, `_subresources={}`.
- **Correction to the AC's own wording, recorded rather than silently absorbed.** AC 1 says the
  `EditorScenePostImport` hook `strip_model_anim.gd` is "already wired for the paladin's other
  six source files". It is not, and should not be: `grep import_script/path
  assets/characters/paladin/*.import` shows it wired on **`paladin.fbx` only** — the MODEL. The
  six clip FBXs carry `import_script/path=""`. That is the correct arrangement (the hook strips
  the AnimationPlayer the MODEL import produces; the clip imports must KEEP theirs, since that
  is where their take is lifted from). The three new sidecars match the six clip FBXs exactly,
  which is what "applies to these three the same way" actually means in effect.
- Assembly by headless GDScript, new tool `tools/add_paladin_locomotion.gd`. It **EXTENDS, never
  rebuilds** — the one structural difference from `tools/build_zombie_anims.gd`, and it is
  load-bearing: `paladin_anims.res` has not been a pure function of the six clip FBXs since
  `tools/retime_clips.gd` time-scaled `attack`/`roll` to their authored tick windows (3-0b AC3)
  and 3-0b's roll fix edited Hips key VALUES. A rebuild-from-FBX would have silently reverted
  both. Six -> nine, existing clips asserted present before the write.
- **Per-clip `mixamorig_Hips` displacement, MEASURED** off the assembled library via
  `tools/measure_hips_displacement.gd` (the 3-0a AC6/R9 method: `track_get_key_value`, first key
  vs last key, position track only). Net-zero epsilon 0.001.

| clip | len (s) | keys | net (x, y, z) | \|net\| | peak | peak planar | net-zero |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **strafe_left** | 0.6667 | 21 | (-0.0000, 0.0000, 0.0000) | 0.0000 | 0.0679 | 0.0588 | **YES** |
| **strafe_right** | 0.7000 | 21 | (-0.0000, 0.0000, 0.0000) | 0.0000 | 0.0611 | 0.0355 | **YES** |
| **backpedal** | 0.5333 | 17 | (0.0000, 0.0000, 0.0000) | 0.0000 | 0.0566 | 0.0295 | **YES** |
| idle | 2.5333 | 27 | (0.0000, 0.0000, 0.0000) | 0.0000 | 0.0115 | 0.0074 | YES |
| run | 0.7000 | 22 | (0.0000, 0.0000, -0.0000) | 0.0000 | 0.1052 | 0.0922 | YES |
| block | 1.4000 | 16 | (0.0000, 0.0000, 0.0000) | 0.0000 | 0.0059 | 0.0055 | YES |
| attack | 0.7500 | 45 | (0.0000, 0.0000, 0.0000) | 0.0000 | 0.4874 | 0.4750 | YES |
| roll | 0.5000 | 60 | (0.0000, 0.0000, 0.0000) | 0.0000 | 0.7213 | 0.0000 | YES |
| death | 3.9000 | 112 | (-0.2408, -0.6498, 0.9322) | 1.1616 | 1.1755 | 0.9964 | NO (accepted, 3-0a AC6/R9) |

  **All three new clips are net-zero. No STOP condition; no clip needs an operator re-download.**
  Two incidental cross-checks worth recording: `death`'s row reproduces 3-0a's published figures
  (-0.241 X, +0.932 Z, -0.650 Y) exactly, which validates the instrument against a known answer
  rather than only against itself; and `roll`'s peak planar now reads **0.0000** where 3-0a
  measured ~1.09, which is 3-0b's Hips-XZ fix visible in the data. The three new clips carry
  small mid-clip excursions (0.03–0.06 planar), an order below `run`'s 0.09 — nothing in the
  legibility class 3-0a flagged for `roll`.
- `test_rig_clips.gd` extended six -> nine, loop table updated (`strafe_left`/`strafe_right`/
  `backpedal` loop ENABLED; `attack`/`roll`/`death` unchanged). The count assertion is now
  DERIVED from `EXPECTED_LOOP.size()` rather than a second hand-written literal — 3-0a wrote
  "6" in two places and this story had to change both.
- **Mutation proof (AC 1), three independent adversarial mutations**, each against a SHA256-
  verified out-of-repo backup of the assembled library
  (`80a65608fb0f51333c5e5ba97fe3726be9fa326a06d6d93adfd8a92ddb49131b`), each restored by
  **copy-back, never `git checkout --`**, hash re-verified GREEN after each:

| # | mutation | result | test output |
| --- | --- | --- | --- |
| A | `strafe_left` removed from the library | **RED**, exit 1 | "expected exactly 9 clips, found 8" + "missing expected clip 'strafe_left'" |
| B | a `mixamo_com` clip re-added | **RED**, exit 1 | "forbidden clip present: 'mixamo_com'" + "expected exactly 9 clips, found 10" |
| C | `backpedal`'s `loop_mode` set to `LOOP_NONE` | **RED**, exit 1 | "clip 'backpedal' loop=false, expected loop=true" |

  Mutation C is beyond the AC's two required forms and was added deliberately: A and B both trip
  the COUNT assertion, so neither one proves the loop-flag table — the half of the contract this
  story actually extends — is non-vacuous. The mutation harness was transient (adversary, not
  deliverable) and is deleted; the committed guard is `test_rig_clips.gd`.

**AC 2 — five-way direction split.**

- `HeroActor.drive()`'s existing per-tick call now carries `(velocity, hero_state.facing)`
  instead of `velocity.length()`. Same call site, same cadence, no new seam, no new state field,
  no `BalanceConfig` field, no snapshot key, no new `_physics_process`.
- **No second `atan2`.** Direction is resolved by two dot products against the same facing
  drive() yaws with — `forward = v.x*f.x + v.z*f.y`, `right = v.x*f.y - v.z*f.x` — so no angle is
  ever formed and nothing here is written to a transform. `grep -rn atan2 src/` still returns the
  one hero yaw in `hero.gd:40`.
- Named, untuned constants on the `RUN_SPEED_EPS` precedent: `STRAFE_BAND_RATIO := 1.0` (the
  boundary on the 45-degree diagonals — four equal quadrants) and `LOCOMOTION_BLEND_SECONDS :=
  0.12` (the `custom_blend` crossfade, polled path only). Action-state transitions keep the
  3-0a/R5 no-blend policy: `_restart()` is deliberately NOT given a blend.
- Speed is now measured **planar** (x/z) rather than `Vector3.length()`. Same value today (state
  only ever writes planar movement), but a split that classified direction from x/z while
  thresholding a magnitude that included y would be answering two different questions.
- New machine contract `test/integration/test_hero_clip_selection.gd`, driven through the REAL
  path (`drive()` -> `on_locomotion()` -> `AnimationPlayer`), not the controller's front door —
  a controller that classifies perfectly while `drive()` hands it the wrong two values is the
  defect, not a passing test. Covers: the four cardinals plus rest under **two different
  facings**; the two motivating-defect cases stated explicitly; IDLE-gating (attack/roll still
  own the body while carrying velocity); and a CONTENT check that each new clip actually moves
  `mixamorig_Hips` (the 4-3c `_assert_clip_content_changes` precedent).
- **Mutation proof (AC 2), both RED, restored by copy-back:**

| # | mutation | result | what it proves |
| --- | --- | --- | --- |
| E | selection reverted to the pre-5-0a speed-only split | **RED**, exit 1 — 6 failures | the split is genuinely five-way, not `run` by another name |
| F | facing hardcoded to `(0,1)` — reads world axes, ignores facing | **RED**, exit 1 — 4 failures | the second facing block earns its place: **every facing-+Z case still passed under F**, so the first block alone would NOT have caught the 4-6 bug class this story exists to fix |

**AC 3 — the hitbox follows the weapon bone (the AT-RISK item).**

- The rig carries a **real weapon joint**: `mixamorig_Sword_joint` (bone 58, child of
  `mixamorig_RightHand`) — measured off the skeleton, not a hand-bone stand-in.
- Mechanism: `HeroActor._track_weapon_bone()` assigns `HitboxShape.position` each tick from the
  bone's live pose, expressed in the Hitbox's own local frame via `to_local()`. **POSITION
  ONLY.** The `Hitbox` `Area3D` stays a direct child of the root and keeps taking the single yaw
  `drive()` computes; the shape's own rotation is never written. The `BoneAttachment3D` route the
  AC named as an alternative was rejected for exactly this reason — it would have introduced a
  second, independent rotation source.
- Forward kinematics off `get_bone_pose()`, not `get_bone_global_pose()`, on this repo's own
  measured precedent (`tools/measure_strike_frame.gd`): the Skeleton3D GLOBAL pose cache
  refreshes at most once per frame and returns one constant outright in a frameless fixture.
- **Sub-frame lag, named rather than hidden:** `AnimationPlayer`'s default callback is IDLE, so
  bone poses are written in `_process`, after this `_physics_process`-driven read. The pose used
  is the last rendered frame's — the same class of bounded lag as the F1 one-tick gather lag the
  contact pipeline already documents and asserts.
- `hero.tscn`: `HitboxShape`'s authored transform moved from the now-false `z 0.9` to the sword
  joint's **rest position in root space** `(-0.73533, 0.417909, -0.053346)` — a truthful resting
  value, overwritten on the first `drive()` call. Three `editor_description`s corrected: `Hitbox`
  (required by the AC), `AnimationController` (said "six skinned clips" and "velocity
  magnitude"), and `FacingMarker` (cited "HitboxShape at local z 0.9"). The last two were not in
  the task list; leaving them would have shipped exactly the stale-description defect the first
  one exists to fix.
- **`test_contact_pipeline.gd` — the story's real at-risk surface. MEASURED IN BOTH DIRECTIONS,
  and the result is NO SHIFT.** The before-run was taken by temporarily restoring the three
  pristine `src/actors/hero/` files from `HEAD` (backed up to scratchpad first, restored by
  copy-back, SHA256 re-verified), so this is a measured baseline rather than a recollection:

```
BEFORE (static box):  swings=37 hits=36 kill_hits_expected=34 rounds=[1] first_atk=6 first_hit=22 frames=3440
AFTER  (bone-following): swings=37 hits=36 kill_hits_expected=34 rounds=[1] first_atk=6 first_hit=22 frames=3440
```

  Every reported counter is identical, including the derived first-hit pin
  (`first_hit 22 == first_atk 6 + windup 15 + 1`, the F1 one-tick gather lag). Contact timing did
  not move. Two runs of the before-state were taken and agreed.
- **An unchanged result has two explanations, and they had to be told apart.** Either the
  geometry moved and the timing genuinely did not shift, or the mechanism is inert and nothing
  moved at all — `test_contact_pipeline.gd` cannot distinguish those. New machine contract
  `test/integration/test_hitbox_follows_bone.gd` does, on the 4-3c vertical-alignment precedent
  for a machine contract on a spatial claim. It asserts, at seven sample points across the
  attack clip: (a) the shape's world position **equals the bone's**, checked against Godot's own
  `get_bone_global_pose()` rather than a re-implementation of production's hand-rolled chain;
  (b) the position genuinely **sweeps** (>0.5 units of spread) and never sits at the pre-5-0a
  constant `(0,0,0.9)`; (c) the shape's rotation stays identity **and** `Hitbox.rotation.y ==
  Mesh.rotation.y` at every sample (the 1-7b contract, and the check that would have caught the
  `BoneAttachment3D` route); (d) the shape's LOCAL offset is **identical under two different
  facings**, proving it lives in the hero's un-yawed frame and rides the one shared yaw.
- **Mutation proof (AC 3):** `_track_weapon_bone()` made inert -> **RED, exit 1**, 7 failures.
  Its output also prints the measured sweep: the joint travels from `(-0.398, -0.035, -0.148)`
  at rest to `(-0.067, 0.087, 1.198)` at the swing's forward peak. Restored by copy-back, GREEN.
  So the unchanged contact result above is a genuine "no shift", not an inert mechanism.
- Reach/timing tuning deliberately NOT done (Non-Goals): the `BoxShape3D` is unchanged at
  1 x 1 x 1, only its origin now moves. No balance field was touched.

**Golden Prediction — CONFIRMED, measured in both directions.**

`aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f` in BOTH suite runs. The
state-harness counters are byte-identical across the two files (`566 tests, 0 failed, 4377
assertions`), so no state test moved at all, not merely the hash. `src/state/` is byte-identical
— it does not appear in `git status`.

**`project.godot` byte-identity — CONFIRMED, per editor session, not only at the bookends.**
Hash `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004` before and after BOTH
editor sessions (session 1: `.fbx` import; session 2: `.uid`/class-cache scan). No collateral
this pass — the `physics_ticks_per_second` pin survived both, breaking the run of prior
incidents.

**Suite, both directions (counters read from the two files):**

| | state harness | integration | golden |
| --- | --- | --- | --- |
| before | 566 tests, 0 failed, 4377 assertions | 46 files, all PASS | `aa3566d7` |
| after | 566 tests, 0 failed, 4377 assertions | 48 files, all PASS | `aa3566d7` |

The `diff` of the two suite files is **exactly two added blocks**, both new PASSes
(`test_hero_clip_selection`, `test_hitbox_follows_bone`) — nothing else changed line for line.

**Deviations and follow-ups, named:**

1. `test/integration/test_chain_retrigger.gd` needed editing, which the task list did not
   anticipate: it calls `on_locomotion()` directly and did not compile against the widened
   signature. Both call sites restated in the new payload with the SAME case they always
   asserted (forward along facing, still `run`); its idempotency claim is untouched and matters
   MORE now that the polled path carries a crossfade.
2. Integration file count 46 -> 48 (named deviation, the 3-0a precedent for reporting this).
3. Two new tools committed under `tools/` (`add_paladin_locomotion.gd`,
   `measure_hips_displacement.gd`), on the `build_zombie_anims.gd` / `measure_strike_frame.gd`
   precedent. The Hips measurement is a reusable instrument rather than a one-off script, so the
   next story to add a clip re-runs it instead of rewriting it.
4. **Live Smoke is NOT done** — it is the operator's, and `docs/playtest-log.md` is written by
   hand before the commit chain. The angle bands and the crossfade are untuned by design
   (Non-Goals); boundary flicker and any clip-excursion detachment are the named watch items.
5. NO commits made this pass, per the operator's instruction; the three `.fbx` and their
   sidecars remain untracked until the chain.
6. **Live smoke overturned the operator's Mixamo-preview strafe mapping** (post-review,
   pre-close-out): the two clips read visually swapped in-game — moving right played the
   clip authored as `strafe_left` and vice versa. Root cause: the Mixamo preview camera faces
   the character, mirroring left/right relative to the character's own frame, so an
   identification made from that preview reads backwards once driven by the hero's actual
   facing. Fix was a **source-file content swap** (`strafe_left.fbx` <-> `strafe_right.fbx`,
   via a temp filename, `.import` sidecars left untouched since they are path-bound and their
   `[params]` blocks are identical) — never a key remap in `add_paladin_locomotion.gd`, which
   would have hidden the mismatch instead of correcting the truth on disk. Re-imported via one
   `--headless --editor --quit` session (`project.godot` unchanged), then
   `add_paladin_locomotion.gd` (idempotent replace) and `measure_hips_displacement.gd`
   re-run — the strafe rows' figures swapped as expected and both remain net-zero.
   `test_rig_clips`, `test_hero_clip_selection`, `test_hitbox_follows_bone`, and
   `test_clip_timing` all re-run individually and PASS. **Recorded for future stories: clip
   handedness read off an external preview tool cannot be trusted — direction is only
   judgeable driven live, in-engine, by the character's own facing.**

### File List

**Modified**

- `assets/characters/paladin/paladin_anims.res` — six -> nine animations
- `src/actors/hero/hero.gd` — widened locomotion push (AC 2); `_track_weapon_bone()` +
  `_bone_pose_global()` and the `_ready` bone resolve (AC 3)
- `src/actors/hero/animation_controller.gd` — five-way direction split, `STRAFE_BAND_RATIO`,
  `LOCOMOTION_BLEND_SECONDS`, `_locomotion_clip()` (AC 2)
- `src/actors/hero/hero.tscn` — `HitboxShape` transform + three corrected `editor_description`s
- `test/integration/test_rig_clips.gd` — six -> nine clips and loop flags (AC 1)
- `test/integration/test_chain_retrigger.gd` — two call sites restated in the widened payload
- `docs/implementation-artifacts/sprint-status.yaml` — board (corrected back to `ready-for-dev`
  per CFG/R2 by this skill's `on_complete`)
- `docs/implementation-artifacts/5-0a-hero-locomotion.md` — this record

**New**

- `assets/characters/paladin/strafe_left.fbx` + `.import`
- `assets/characters/paladin/strafe_right.fbx` + `.import`
- `assets/characters/paladin/backpedal.fbx` + `.import`
- `tools/add_paladin_locomotion.gd` + `.uid`
- `tools/measure_hips_displacement.gd` + `.uid`
- `test/integration/test_hero_clip_selection.gd` + `.uid`
- `test/integration/test_hitbox_follows_bone.gd` + `.uid`

## Change Log

| Date | Change |
| --- | --- |
| 2026-09-02 | Dev pass via `gds-dev-story`. All three ACs implemented and measured: nine-clip library, mutation-proven; five-way direction-aware clip selection off the shared yaw, no second `atan2`; bone-following hitbox, `test_contact_pipeline.gd` measured NO SHIFT in both directions. Golden `aa3566d7...` CONFIRMED unmoved both directions, `src/state/` byte-identical, `project.godot` byte-identical across both editor sessions. Suite 566/4377 state (unmoved) -> 46 -> 48 integration files. Status -> `review`. |
| 2026-09-02 | Code review: verdict PASS, one LOW deferred to the retune block (`5-0a/R2`, decision-log). |
| 2026-09-02 | Live smoke found the strafe clips visually swapped (Mixamo-preview mirror misread); fixed by a source-file content swap, re-imported, re-measured (both clips remain net-zero), re-verified correct in-game (`5-0a/R1`, decision-log). All six watch items re-confirmed PASS. Status -> `done`; board `5-0a-hero-locomotion` -> `done`. Close-out recorded in decision-log Session 2026-09-02 -- 5-0a close-out (`5-0a/R1`-`5-0a/R4`). |
