---
baseline_commit: 5eacaf9dfa0c7c90bd6daadabde112793f47a309
---

# Story 6.8: Camera Freedom

Status: authored

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to unlock the camera and rotate it by hand when I am not locked on, cycle through every
live target on the board -- including ones behind me -- while I am locked on, and use the lock
button to unlock as well as to lock,
so that spacing and awareness work the way a Souls/Sekiro camera does now that the lock has an
off state and more than two things are ever worth aiming at.

## Acceptance Criteria

**Lock button (S2, operator scope talk 2026-09-16)**

1. The lock button (the `4-6`/`CC/R3` right-stick click, `GamepadProfile.lock_button` = R3) always
   concerns the enemy hero, and its effect depends on the CURRENT state:
   - locked on a minion or totem -> click returns the lock to the enemy hero (`4-6` AC 9, unchanged).
   - locked on the enemy hero -> click UNLOCKS.
   - unlocked -> click locks the enemy hero.
2. There is now an UNLOCKED state. `CC/R3`'s "No unlock state" (carried into `4-6` AC 10) is
   SUPERSEDED by this story (see "What this story supersedes" below) -- not by `4-6a`, which never
   touched it.

**Unlocked behaviour (S3)**

3. While unlocked, the hero's facing reverts to the pre-`4-6` rule: input-derived, following
   movement direction (`4-6` AC 2's target-derived facing applies only while locked). A neutral
   stick leaves facing unchanged; rotating the unlocked camera alone does not change facing (the
   pre-`4-6` zero-guard, `4-6` AC 2).
4. While unlocked, a neutral-stick roll goes FORWARD (the pre-`4-6` rule). `4-6/R7`'s
   away-from-target backstep applies only while locked -- there is no locked target to back away
   from.
5. While unlocked, block orientation matters again: `_is_facing`/`block_facing_arc_degrees`
   (`4-6` AC 5) read the reverted, input-derived facing, so the arc can once again be dodged by
   turning away, exactly as it could before `4-6`.
6. No lock marker renders while unlocked (`4-6a` AC 13's marker is a locked-only cue).

**Unlocked camera (S4)**

7. While unlocked, the right stick rotates the camera rig's yaw horizontally, driven by player
   input rather than by a locked target's direction (`4-6` AC 1's yaw source). Height and pitch
   stay exactly as authored (`data/camera_config.tres`, unchanged, `4-6` Non-Goals) -- this story
   adds no vertical camera freedom (see Non-Goals). Pushing the right stick right turns the view
   right (not inverted); pushing it left turns the view left (operator browser review 2026-09-16
   (readiness gate 1), G1). A headless test pins it; the dev pass proves which rig yaw sign that
   is -- the direction itself is not open.
8. Rotation speed is an authored knob (per-tick, on the `CameraConfig.lock_yaw_smoothing`
   discipline -- no `delta`/`Time`/`Engine` read, F1-safe), tuned at this story's own live smoke.
9. On UNLOCK, the camera keeps its current heading -- no snap to a default or to the direction of
   movement.
10. There is no auto-recenter: an unlocked camera holds whatever heading the player last gave it
    (or inherited from the last lock) until the player moves the stick or relocks.
11. A flick (the `4-6a` retarget gesture) is a no-op while unlocked -- there is no standing lock to
    cycle from, and flicking is a locked-only control (S5).
12. On RELOCK (unlock -> lock, or a mid-lock retarget), the camera swings onto the new lock
    direction using the existing `4-6a` smoothing (`CameraConfig.lock_yaw_smoothing`, AC 10-12 of
    that story) -- unaffected by this story.

**360 cycling while locked (S5)**

13. While locked, a horizontal flick cycles among ALL live targets of the opposing slot --
    opposing hero, plus every living minion and totem -- regardless of on-screen visibility,
    including targets currently behind the hero. This supersedes `4-6a` AC 1's on-screen-only
    candidate set (see "What this story supersedes").
14. Candidates are ordered by ANGLE AROUND THE LOCKING HERO (a full-circle bearing from the hero
    to each candidate), not by screen position. The current target is the cycling anchor by its
    bearing, not its screen X (`4-6a` AC 4's screen-X anchor is superseded for this purpose).
15. A flick RIGHT selects the candidate whose bearing is reached first when sweeping from the
    current target's bearing toward screen-right. With the locked camera looking along the lock
    direction, that is clockwise viewed from above. Testable claim: with candidates to the left
    and right of the current target on screen, the first right flick selects the nearest one by
    angle on the right side, and the first left flick selects the nearest on the left. A flick
    LEFT sweeps the other way.
16. The cycling order WRAPS: past the last candidate in a direction, cycling continues from the
    first (the opposite of `4-6a` AC 2's explicit no-wrap, which this AC supersedes).
17. Ties (two candidates at the identical bearing) break on the lower board index, the `4-6a` AC 7
    tie-break convention carried forward unchanged in mechanism. The current target holds its own
    place in the bearing-ordered circle. A candidate at exactly the current target's bearing is
    ordered against it by the same lower-board-index tie-break. One full sweep of flicks in either
    direction visits every candidate exactly once before returning to the current target (operator
    browser review 2026-09-16 (readiness gate 1), G2).
18. `4-6a` AC 3's vertical-flick no-op, with AC 6's `abs(x) > abs(y)` horizontal boundary, is
    UNCHANGED: cycling stays horizontal-only.
19. `flick_threshold` (`gamepad_profile.gd`, 0.7) is unchanged; not reopened by this story.

**Unchanged (S6)**

20. The round still starts locked on the enemy hero (`CC/R2` default/fallback target).
21. Locked-target death still snaps the lock to the enemy hero on the same tick (`4-6/R4`).
22. The DEAD early return and the round-over step-1b freeze (`2-3/R14`, `2-6/R6`) still carve out
    facing, roll-direction, and camera-yaw writes exactly as `4-6` AC 2/AC 3 established -- this
    story adds an unlocked state to the facing/roll/camera RULES, not a third carve-out.

**Keyboard parity (S7)**

23. Both keyboard slots (`KeyboardController`) implement the gamepad's lock controls: a lock key
    with the AC 1 three-way behaviour, camera-rotate-left/right keys that rotate the unlocked
    camera per AC 7-10 (no-op while locked), and cycle-left/right keys that are a horizontal flick
    per AC 13-17 (no-op while unlocked). The physical key choice is ratified (operator browser
    review 2026-09-16 (readiness gate 1)); see Dev Notes for the table. Controller stays primary
    and carries the live smokes (`CC/R4`). Closes deferred-work M5.
24. The new bindings use only PHYSICALLY UNIQUE keys -- every keyboard `InputEventKey` in
    `project.godot` today carries `"location":0`, so a binding must not rely on a location-generic
    modifier (Shift/Ctrl/Alt), or on Enter/Space, which the engine's built-in `ui_accept` also
    reads. See Dev Notes for the ratified table and the stale-binding finding it corrects.

## What this story supersedes

- **`CC/R3` "No unlock state."** `4-6`'s own controls ruling said no unlock state exists at any
  point. This story adds one (AC 2). `CC/R3`'s click-instantly-relocks clause is otherwise the
  ancestry AC 1 builds on, not discarded; its flick-picks-a-candidate clause was already
  superseded by `4-6a` AC 1's adjacent-by-screen-X cycling (decision-log Session 2026-08-31, the
  SUPERSESSION recorded alongside `4-6a/R1`, gate finding B9 -- not `4-6a/R1` itself, the
  null-anchor no-op), not this story's doing.
- **`CC/R2` "Always lock-on ... Never a free camera."** Superseded by AC 2/AC 7; its
  default/fallback-target clause stands unchanged (AC 20).
- **`4-6` Non-Goal "No free camera and no camera-rotation input route is added or revived"**
  (`4-6-camera-lock-on.md:119`). Superseded by AC 7-10.
- **`4-6a` AC 1's on-screen-only candidate set and AC 4's screen-X anchor** -- superseded by AC
  13/AC 14: candidates are no longer filtered to what's on-screen, and the anchor is no longer a
  screen coordinate.
- **`4-6a` AC 2, "no wrap."** Superseded by AC 16: cycling now wraps.
- **`4-6a` AC 5 / `4-6a/R1`, the null-screen-anchor no-op.** MOOT: the anchor is now the current
  target's BEARING, which exists for every live candidate regardless of camera visibility, so
  there is no "no anchor" case left. `4-6a` AC 3 (vertical no-op) and AC 7's tie-break MECHANISM
  (not its screen-space metric) survive.
- `LockOnResolver.adjacent_candidate` (`4-6a`'s shipped algorithm) is the function this story's dev
  pass rewrites or replaces, per `4-6a`'s own "REPLACES THE ALGORITHM AND KEEPS THE SEAT" precedent
  (`lock_on_resolver.gd:5`) -- `4-6a` replaced `4-6`'s cone the same way this story replaces it.

## Non-Goals

- **Vertical camera.** No pitch input, no camera-height control. `data/camera_config.tres`'s
  authored `height`/`pitch_degrees` and the load-once pattern (`camera_rig.gd:29-31,52`, `4-6`
  Non-Goals, `4-6a` Non-Goals) stay exactly as they are.
- **Auto-recenter.** An unlocked camera never snaps back to a default heading on its own (AC 10).
- **Separating body yaw from hitbox yaw** (the "wait, then step" turn variant `6-7b/R4` named as a
  possible future fix for the turn-in-place rotation-rate compromise). Out of scope -- this story
  does not touch `hero.gd`'s single-yaw-source contract (`4-6` AC 6) or turn-in-place at all.
- **Camera collision with arena walls.** Not built; smoke-watch only (see Live Smoke) -- if an
  unlocked camera can be rotated to clip through a wall or the arena boundary, that is recorded as
  a live-smoke finding, not fixed in this pass.
- **`4-6a`'s lock/retarget smoothing mechanism itself** (curve, ownership split at `camera_rig.gd`)
  -- unaffected; AC 12 explicitly carries it forward.
- **`TargetingService`'s evaluator** -- not reused, not touched, the standing `4-6`/`4-6a` boundary.
- **Off-screen telegraph legibility** for an unlocked or out-of-frame opposing hero -- the `4-6`
  Non-Goal (sound-only warning), untouched and, if anything, more load-bearing now that the camera
  can point away from the fight entirely.

## Golden Prediction

No value is predicted; the gate and the dev pass MEASURE the golden hash and the snapshot key set
before and after, per Tier A discipline (this story is Tier A by operator ruling S1, not by the
Tier B default the board carried into this pass -- see Dev Notes). Candidate causes, each to be
confirmed or ruled out separately, on the `4-3a/R17`/`4-4` multi-cause precedent `4-6/R2` already
used for this exact system:

1. **How "unlocked" is represented in the snapshot.** `PlayerState.lock_target_slot`/
   `lock_target_index` are already hashed (`4-6` OQ 1). Adding an unlocked value to that shape (a
   sentinel, or a new field) is a snapshot-shape change and a candidate golden mover on its own.
2. **Intent-stream growth.** Candidate record-format change (`FORMAT_VERSION` 11 -> 12,
   `record_file.gd:195`); a golden mover only if it adds hashed state. Whether a lock-toggle
   request and/or a manual camera-rotation input need a new `InputIntent`/recorded-fact channel
   depends on fitting an existing channel (the no-shim measurement discipline, the `4-6` OQ 3
   precedent, FORMAT_VERSION 5 -> 6). No value predicted, measured before/after.
3. **Facing/roll-fallback reversion while unlocked.** AC 3/AC 4 make `HeroState.facing`'s source
   and `_roll_world_direction`'s fallback CONDITIONAL on lock state for the first time (`4-6` AC 2
   made facing always target-derived) -- hashed fields (`facing`, `roll_direction`), but the golden
   fixture never unlocks: it pushes a constant non-zero lock direction every tick
   (`test_determinism.gd`'s `LOCK_DIRS`) and its one neutral roll (t17) is locked. Predicted
   structural non-mover unless the locked path itself changes (`4-6`'s own re-baseline noted
   `set_camera_basis` is called zero times, "Cause 4's non-move is structural"); measured both
   directions.

Baseline: current golden `71a7b45f...` (`6-7b` close-out, decision-log Session 2026-09-16),
`FORMAT_VERSION` 11. Both are re-measured fresh at dev-pass start per the golden-clause discipline.

## Live Smoke

Two pads, per the pad-smoke ruling (`6-7/R19`: live smokes run primarily on controller). Items:

- **Click states (S2/AC 1).** All three transitions -- unit/totem-lock click returns to hero,
  hero-lock click unlocks, unlocked click locks the hero -- fired in sequence on both pads.
- **Unlocked facing, roll, and camera (S3/S4/AC 3-12).** Does facing visibly revert to
  input-derived and roll go forward with a neutral stick while unlocked; does the right stick
  rotate the camera at the tuned rate (AC 8); does the heading hold on unlock (AC 9) and on an
  idle stick (AC 10); does relock swing smoothly onto the new target (AC 12).
- **360 cycling with targets behind the hero, including wrap (S5/AC 13-17).** Lock onto a minion,
  physically walk or turn so a totem sits behind the hero, flick to confirm it is reachable; cycle
  past the last candidate in one direction and confirm it wraps to the first rather than stopping.
  Also flick through one full sweep in a single direction and confirm every live candidate is
  visited exactly once with no back-and-forth (no ping-pong) before returning to the start (AC 17,
  G2).
- **Keyboard parity spot check (S7/AC 23-24).** Exercise all five actions (lock/unlock,
  camera-rotate-left/right, cycle-left/right) on BOTH keyboard slots, using the shipped default (no
  `main.tscn` `slot_controller_kinds` override -- both slots are KEYBOARD, `6-7/R18` precedent).
  Run the P2 numpad bindings once with NumLock on and once with NumLock off (N9, unmeasured, low
  confidence).
- **Camera/wall behaviour**, per the Non-Goals carve-out: record what an unlocked camera does near
  the arena boundary as a named finding, not a blocker.

Record all items in `docs/playtest-log.md` by the operator's own hand, per `PROC/R8`.

## Dev Notes

- **Tier: A, by operator ruling S1 (operator scope talk 2026-09-16), overriding the board's
  inherited `# Tier B` comment.** Author's rationale, not stated in the ruling itself: the unlocked
  state hands hero facing back to input inside `src/state/` (AC 3), a golden-clause trigger on its
  own; growing the intent stream (candidate cause 2 above) is a candidate value, not a decided one,
  and is not load-bearing for the tier call. Tier may be raised, never lowered, mid-story
  (`CLAUDE.md` Story tiers) -- it is fixed at Tier A here, at the story's own authoring, and stays
  there.
- **`PlayerState.lock_target_slot`/`lock_target_index`** (`player_state.gd:160-161`): today always
  a valid address, default `TargetingService.NO_TARGET_SLOT`/`HERO_INDEX` semantics at construction
  but SEEDED to the opposing hero by `MatchState` before the round starts (`4-6` Dev Notes) -- there
  is no existing "no target" runtime value distinct from "target is the hero" (`HERO_INDEX == -1 ==
  TargetingService.NO_TARGET_SLOT` are the same integer, `targeting_service.gd:59,64`). Representing
  "unlocked" needs either a new sentinel pair that is distinguishable from every valid `[slot,
  index]` address, or a separate bool. Open Question 1.
- **`LockOnResolver.adjacent_candidate`** (`src/main/lock_on_resolver.gd:80-101`): the current
  screen-X-distance algorithm, PURE and position-free, takes a screen-space `anchor: Vector2` and
  `candidate_screens: Array[Vector2]`. This story's bearing-based cycling (AC 13-17) needs a
  different pure function -- an angle-around-a-point pick rather than a screen-X pick -- most
  naturally still headlessly testable if it takes a bearing anchor and an array of candidate
  bearings rather than screen positions (mirroring `4-6a` OQ 4's "shape survives, name doesn't"
  precedent, applied to the shape itself this time since the geometry changed).
- **`_gather_flick_candidates`** (`match_runner.gd:2381-2402`): today gathers screen-projected,
  on-screen-only candidates via `_screen_position` (`null` off-screen, `match_runner.gd:2497-2499`).
  AC 13 means this gather can no longer filter on screen visibility for the cycling case -- it
  needs each candidate's WORLD position (`_target_world_position`) turned into a bearing, never a
  screen projection. The MARKER's own gather (`_lock_target_screen_position`, `:2436-2443`, `4-6a`
  AC 13) is unaffected -- a marker for an off-screen target still has nothing to draw.
- **The camera-rotation input needs a NEW right-stick reading distinct from `retarget_flick()`'s
  edge-triggered gesture** (`gamepad_controller.gd:241-259`, `controller.gd:42-50`): the flick is
  one-shot; unlocked rotation (AC 7) is continuous, closer in shape to `move_dir`. Whether it reads
  the SAME `look_axis_x`/`_y` fields (`gamepad_profile.gd:43-44`) under a different resolution
  function, or needs its own authored fields, is Open Question 2 -- no other consumer of
  `look_axis_x`/`_y` exists today (grepped), so this is free to repurpose without conflict.
- **`face_lock_direction`** (`camera_rig.gd:114-128`) is the ONLY write path to the rig's yaw
  today, shaped for "ease toward a target bearing." Unlocked rotation (AC 7-10) needs either a
  second `CameraRig` entry point or a reinterpretation of this one -- a dev-pass call, but any new
  write must land at the runner's existing per-tick seat (step 1c, `match_runner.gd:2543-2562`),
  the seat proven not to need a second `_physics_process`.
- **Keyboard binding proposal, corrected for a stale `4-6` proposal.** `4-6`'s own OQ 5 proposed
  `Q`/`Z`/`C` (P1) and `Numpad 0`/`Numpad 1`/`Numpad 3` (P2) for relock/flick-left/flick-right, but
  `Q` is now BOUND to `p1_cast_mode` (`project.godot:127-131`, added by `5-0b` after `4-6` shipped)
  -- the `4-6` proposal is stale and was never implemented, so nothing regresses, but it must not be
  copied forward as-is. Measured inventory of every bound physical key today (`project.godot`,
  grepped): P1 uses W/S/A/D (move), J/K/L (attack/block/roll), Space (run), Q (cast_mode), 1-4
  (cards), E (cast_confirm), R (debug_reset). P2 uses the arrow keys (move), `.`/`,`/`/` (attack/
  block/roll), `Numpad 0` (run, `6-7/R18`), O (cast_mode), 6-9 (cards), P (cast_confirm), `'`
  (debug_reset). Global: F1 (debug_pause), F2 (debug_step). Every one of these events carries
  `"location":0` (grepped), confirming AC 24's constraint. A non-conflicting proposal for this
  story's five new actions per slot (lock/unlock, camera-rotate-left, camera-rotate-right,
  cycle-left, cycle-right), RATIFIED (operator browser review 2026-09-16 (readiness gate 1)):

  | action | P1 | P2 |
  |---|---|---|
  | lock/unlock (the R3 click) | `T` | `Numpad 5` |
  | camera rotate left / right | `F` / `G` | `Numpad 4` / `Numpad 6` |
  | cycle left / right | `Z` / `C` | `Numpad 1` / `Numpad 3` |

  P2's lock/unlock key moved off `Numpad 0` (that key is `p2_run`, `6-7/R18`) to `Numpad 5`,
  grep-confirmed unbound in `project.godot`. The rotation and cycle keys are unchanged in spirit
  from `4-6`'s original proposal (never implemented, so not stale in the same way), with two
  rotation keys added on the same pad in the natural 4/6 left/right position. Built by this pass
  (AC 23), per the `4-6` AC 13 precedent for proposing keyboard bindings before implementing them.
- **`InputIntent`/`RecordFile` channel fit is a dev-pass measurement**, not decided here, on the
  `4-6` OQ 3/AC 14 precedent verbatim: does a lock-toggle request and/or a manual camera-rotation
  input fit inside an existing channel, or does either need a new one. If either needs one,
  `FORMAT_VERSION` bumps once, hard rejection of older records, no migration shim (the standing
  no-shim discipline every prior bump has followed).

### Project Structure Notes

- Lock-state and the cycling algorithm follow `4-6`/`4-6a`'s existing split: the STATE half (what
  "unlocked" means, where it lives on `PlayerState`) beside `hero_state.gd`/`match_state.gd`/
  `player_state.gd`; the PRESENTATION half (bearing computation, camera-rotation input reading,
  `LockOnResolver`'s algorithm) stays under `src/main/`/`src/controllers/`/`src/actors/hero/`,
  never `src/state/`. No new top-level folder is implied by anything measured above.

### Project Context Rules

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd` -- any new
  camera-rotation write must land at the runner's existing per-tick seat, not a new process
  callback.
- D3(a): `Input.*` only under `src/controllers/` -- the new camera-rotation axis read (whichever
  shape Open Question 2 settles on) follows the existing device-filtered pattern
  `GamepadController` already uses for `look_axis_x`/`_y`.
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine`, and no live scene/camera query, inside
  `src/state/` -- unlocked facing (AC 3) reads input-derived movement direction, already legal
  inside `src/state/` (it is what `4-6` AC 2 replaced); nothing this story adds needs a new
  scene/camera query from state.
- Docs and code never share a commit; commit messages are pure ASCII via `git commit -F`; shell is
  PowerShell 5.1 (no `&&`); trailer per this repo's current convention -- verify at dev-pass time
  against the live `CLAUDE.md`, since the trailer identity has changed between stories in this
  project's history (`4-6`/`4-6a`'s Opus 4.8 trailer is NOT assumed current).
- Story tier: A, fixed at authoring by operator ruling S1 (Dev Notes above) -- full gate + review +
  live smoke ritual, may be raised, never lowered (`CLAUDE.md` Story tiers).
- `PROC/R1`: two full suite runs (dev-pass start and end), mutation proofs run only the affected
  test file. `PROC/R4`: browser bookends. `PROC/R7`: state the budget and its tripwire at dev-pass
  start, since this story's own text does not fix one. `PROC/R8`: legibility/feel claims route to
  operator smoke -- see Live Smoke section above.

### References

- [Source: decision-log.md, `E6-P/R7`, `6-8-camera-freedom` seat] — the two behaviours specified.
- [Source: decision-log.md, `DP/R1` (2026-07-31)/`E4-P/R11`/`CC/R1`-`CC/R6` (2026-08-30)] —
  always-lock-on lineage: FULL-variant facing, the Sekiro control model, the delegated-mechanism
  precedent this story's Open Questions follow.
- [Source: decision-log.md, `4-6/R1`-`4-6/R7` (2026-08-30)] — camera-yaw scope, facing ownership,
  DEAD/round-over carve-outs (AC 22), neutral-roll backstep (AC 4, now lock-conditional).
- [Source: decision-log.md, `4-6a/R1`-`4-6a/R2` (2026-08-31/2026-09-01)] — null-anchor no-op (now
  moot, "What this story supersedes"), marker-lift rulings (unaffected).
- [Source: decision-log.md, Session 2026-09-16, `6-7b/R1`-`R9` close-out] — golden `71a7b45f...`,
  `FORMAT_VERSION` 11, the Tier B precedent this story departs from.
- [Source: operator scope talk 2026-09-16, rulings S1-S7] — controlling rulings, carried by
  content; numbered at close-out.
- [Source: src/main/lock_on_resolver.gd; src/main/match_runner.gd:2296-2679 (`_lock_direction`,
  `_resolve_retarget`, `_gather_flick_candidates`, `_lock_target_screen_position`,
  `_screen_position`, step 1c/2/4b/4d seats); src/actors/hero/camera_rig.gd
  (`face_lock_direction`, the sole rig-yaw write path)] — the mechanism this story's dev pass
  rewrites or extends.
- [Source: src/controllers/gamepad_controller.gd, controller.gd, gamepad_profile.gd,
  data/gamepad_profile.tres] — `relock_pressed`/`retarget_flick`, `look_axis_x`/`_y` =
  `JOY_AXIS_RIGHT_X`/`_Y`, `lock_button` = `JOY_BUTTON_RIGHT_STICK` (R3), `flick_threshold` = 0.7 —
  every right-stick consumer in the codebase (grepped).
- [Source: src/controllers/keyboard_controller.gd] — confirmed no lock/retarget on keyboard today.
- [Source: project.godot `[input]` section] — every bound physical key both slots, confirming AC
  24's `"location":0` premise and the `4-6` OQ 5 `Q`-collision finding.
- [Source: deferred-work.md:282, id M5, `_46-review.md:276`] — "Keyboard slots can no longer face
  anything but the opposing hero," disposition (b); closed by AC 23 (S7).
- [Source: src/state/player_state.gd:150-161,405; input_intent.gd:15-18,88-89;
  targeting_service.gd:59,64] — current lock-target/retarget shape, the `HERO_INDEX ==
  NO_TARGET_SLOT` coincidence Open Question 1 resolves around.
- [Source: src/systems/record_file.gd:195] — `FORMAT_VERSION := 11`, the current pin.

## Open Questions

1. **Where "unlocked" lives in state, and its exact shape** -- a new sentinel pair distinguishable
   from every valid `[slot, index]` address, or a separate bool beside `lock_target_slot`/
   `lock_target_index` -- dev-pass call, confirmed against the D3(b)/A2 boundary and the
   determinism snapshot contract, on the `4-6` OQ 1 precedent.
2. **How the manual camera heading reaches the movement basis and replay.** Whether unlocked
   rotation reads `look_axis_x`/`_y` through a new resolution function or needs its own authored
   axis fields; whether it writes `CameraRig` through a new entry point or a reinterpreted
   `face_lock_direction`; and whether the existing `capture_set_camera_basis` channel (`4-6a` OQ 5
   precedent: no new channel needed there) covers it or whether a new hashed/unhashed record
   channel is required, exactly as `4-6a` OQ 5 asked and answered for smoothing.
3. **The shape of the new intent field(s)** -- a lock-toggle request and/or a continuous rotation
   input on `InputIntent`, and whether either needs a `FORMAT_VERSION` bump (currently 11), per the
   `4-6` OQ 3/AC 14 fit-measurement discipline.
4. **What `6-7b`'s turn-in-place does while unlocked.** `6-7b/R3`'s turn-in-place triggers on
   standing-still facing changes; whether an unlocked hero's input-derived facing (AC 3) interacts
   with turn-in-place any differently than pre-`4-6` movement-derived facing did is unexamined by
   either story and must be checked, not assumed clean.
5. **The proof method for AC 15's mapping.** How the world-axis sign maps to clockwise in
   `src/main/`, and a headless test pinning that mapping. The direction itself is not open (fixed
   by AC 15).
6. **The unlocked camera's right-stick dead zone and response curve** (linear or shaped, rate at
   full deflection). Independent of `flick_threshold`, which gates only the locked-state flick edge
   (AC 19). Dev-pass call, tuned at live smoke with AC 8's rate knob.

## Tasks / Subtasks

- [ ] (S2) Add the unlocked state (OQ 1); wire the three-way click behavior (AC 1).
- [ ] (S3) Make facing and the roll neutral-fallback conditional on lock state (AC 3-5); suppress
      the lock marker while unlocked (AC 6).
- [ ] (S4) Resolve OQ 2 (manual-rotation input shape and record channel); implement unlocked
      camera rotation with an authored rate (AC 7-12).
- [ ] (S5) Replace `LockOnResolver`'s algorithm with bearing-based 360 cycling, wrapping, tie-break
      carried forward (AC 13-19); resolve OQ 5 (proof method for AC 15's clockwise mapping).
- [ ] (S6) Confirm the unchanged rules (round-start default, death-snap, DEAD/round-over carve-outs,
      `flick_threshold`) still hold under the new lock-state branch (AC 20-22).
- [ ] (S7) Implement keyboard parity in `KeyboardController` (AC 23-24): lock/unlock,
      camera-rotate-left/right, and cycle-left/right, on the ratified key table (Dev Notes). Edit
      `project.godot` on the `6-7` Task 2 discipline (diff contains only the new action blocks);
      update the `SHIPPED_INPUT_ACTIONS` pin (`test_deck_and_hand.gd:478`). Add headless tests for
      the keyboard edges.
- [ ] Resolve OQ 3 (intent/record shape, `FORMAT_VERSION`); measure golden + snapshot key set
      before/after (Golden Prediction section); operator smoke on every Live Smoke surface.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-09-16 | 0.1 | Docs-only fix pass against readiness gate 1 (`C:\dev\_6-8-gate.md`, verdict NOT READY, 6 blockers, 10 notes, 2 operator gameplay questions). Blockers B1-B6 applied: B1, AC 23 (was AC 24) now requires `KeyboardController` to IMPLEMENT the gamepad's lock controls, not merely propose them, with the physical key choice ratified up front (no operator gate before Task S7 edits `project.godot`); Task S7 rewritten to implement, add the `project.godot`/`SHIPPED_INPUT_ACTIONS` discipline, and headless edge tests; closes deferred-work M5. B2, the P2 key inventory corrected (`Numpad 0` is `p2_run`, `6-7/R18`, not Right Shift/run); P2 lock/unlock moved to `Numpad 5` (grep-confirmed unbound); key table labelled ratified. B3, AC 23 (old numbering, the self-contradictory `flick_threshold` gate for unlocked rotation) deleted and every following AC/Task/Live-Smoke/Reference renumbered (AC 24->23, AC 25->24); OQ 6 rewritten to the dead-zone/response-curve question, independent of `flick_threshold`. B4, AC 2's misattributed ruling corrected to `CC/R3` (carried into `4-6` AC 10); "What this story supersedes" gained `CC/R2`'s "Always lock-on ... Never a free camera" and `4-6`'s "No free camera" Non-Goal. B5, Golden Prediction causes 3 and 4 merged into one predicted structural non-mover (the golden fixture never unlocks, per `LOCK_DIRS` and the locked t17 roll), and cause 2 reworded as a record-format change that moves the golden only if it adds hashed state. B6, AC 15 rewritten to a testable sweep-direction claim; OQ 5 reduced to the proof method only, the direction itself no longer open. Operator gameplay answers landed: G1 adds the stick-right-turns-view-right convention to AC 7, headless-test-pinned; G2 extends AC 17 with the current-target's-own-place and no-ping-pong-sweep rule, adds the Live Smoke 360 no-ping-pong check, and disposes N2. Non-blocking notes applied: N1 (AC 18 citation corrected to `4-6a` AC 3/AC 6), N3 (Dev Notes Tier rationale re-labelled as the author's, intent-stream clause marked candidate), N5 (`CC/R3`'s flick clause named as already superseded by `4-6a/R1`, only the click clause carried as ancestry), N6 (AC 25 Enter citation corrected to the engine `ui_accept` default, also covering Space), N7 (`camera_rig.gd` load-once citation corrected to `:29-31,52`; the stale `sprint-status.yaml:139` citation removed by the N3 rewrite; `epics.md:232`'s stale Tier B note left unedited, out of scope for this file pair), N8 (keyboard Live Smoke item rewritten to both keyboard slots, all five actions, naming the shipped default -- no `slot_controller_kinds` override -- as the keyboard configuration), N9 (NumLock on/off added to the keyboard smoke item), N10 (AC 3 gained the explicit neutral-stick/zero-guard sentence). Board `story_note` rewritten to drop the N3/N4 errors; status stays `authored`, board stays `backlog`. | Claude Sonnet 5 |

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`.

### Debug Log References

### Completion Notes List

### File List
