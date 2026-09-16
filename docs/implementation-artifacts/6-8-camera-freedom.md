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
2. There is now an UNLOCKED state. `CC/R2`'s "no unlock state exists at any point" is SUPERSEDED
   by this story (see "What this story supersedes" below) -- not by `4-6a`, which never touched it.

**Unlocked behaviour (S3)**

3. While unlocked, the hero's facing reverts to the pre-`4-6` rule: input-derived, following
   movement direction (`4-6` AC 2's target-derived facing applies only while locked).
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
   adds no vertical camera freedom (see Non-Goals).
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
15. A flick RIGHT cycles to the next candidate in the on-screen-right rotational direction from
    the current target's bearing; a flick LEFT cycles the other way. ("On-screen-right rotational
    direction" pins which of the two angular senses around the circle -- e.g. clockwise as viewed
    from above with the camera's current forward -- a screen-space convention the dev pass must
    fix and test against; see Open Questions.)
16. The cycling order WRAPS: past the last candidate in a direction, cycling continues from the
    first (the opposite of `4-6a` AC 2's explicit no-wrap, which this AC supersedes).
17. Ties (two candidates at the identical bearing) break on the lower board index, the `4-6a` AC 7
    tie-break convention carried forward unchanged in mechanism.
18. `4-6a` AC 1's vertical-flick-is-a-no-op rule (AC 3 of that story) is UNCHANGED: cycling stays
    horizontal-only.
19. `flick_threshold` (`gamepad_profile.gd`, 0.7) is unchanged; not reopened by this story.

**Unchanged (S6)**

20. The round still starts locked on the enemy hero (`CC/R2` default/fallback target).
21. Locked-target death still snaps the lock to the enemy hero on the same tick (`4-6/R4`).
22. The DEAD early return and the round-over step-1b freeze (`2-3/R14`, `2-6/R6`) still carve out
    facing, roll-direction, and camera-yaw writes exactly as `4-6` AC 2/AC 3 established -- this
    story adds an unlocked state to the facing/roll/camera RULES, not a third carve-out.
23. `flick_threshold` = 0.7 stays the gate for whether a stick deflection counts as a flick at all,
    whether that flick is then read as a retarget-cycle (locked) or a camera-rotate magnitude
    (unlocked) -- see Open Questions for whether unlocked camera rotation reuses this gate or an
    authored rate of its own.

**Keyboard parity (S7)**

24. Both keyboard slots (`KeyboardController`) get a lock/unlock key, camera-rotate-left and
    camera-rotate-right keys, and cycle-left and cycle-right keys -- proposals only (documentation
    deliverables, the `4-6` AC 13 precedent), not implemented. Controller stays primary and
    carries the live smokes (`CC/R4`).
25. Proposed bindings use only PHYSICALLY UNIQUE keys -- every keyboard `InputEventKey` in
    `project.godot` today carries `"location":0`, so a binding must not rely on a location-generic
    modifier (Shift/Ctrl/Alt) or on Enter, which already exist elsewhere in the map with the same
    ambiguity. See Dev Notes for the specific proposal and the stale-binding finding it corrects.

## What this story supersedes

- **`CC/R3` "No unlock state."** `4-6`'s own controls ruling said no unlock state exists at any
  point. This story adds one (AC 2). `CC/R3`'s click-instantly-relocks and flick-picks-a-candidate
  clauses are otherwise the ancestry AC 1/AC 13 build on, not discarded.
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
  authored `height`/`pitch_degrees` and the load-once pattern (`camera_rig.gd:26-27`, `4-6`
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
2. **Intent-stream growth.** `FORMAT_VERSION` is currently 11 (`record_file.gd:195`). A lock-toggle
   request and a manual camera-rotation input both look like candidates for new `InputIntent`/
   recorded-fact channels (the `4-6` OQ 3 precedent, FORMAT_VERSION 5 -> 6) -- whether either needs
   one depends on fitting an existing channel (the no-shim measurement discipline). 12 is a
   candidate value, not a decided one.
3. **Facing/roll-fallback reversion while unlocked.** AC 3/AC 4 make `HeroState.facing`'s source
   and `_roll_world_direction`'s fallback CONDITIONAL on lock state for the first time (`4-6` AC 2
   made facing always target-derived). Both are hashed -- a confirmed behavioural mover, isolated
   from cause 1 per the `4-6` cause-splitting precedent.
4. **Whether the golden fixture ever retargets or unlocks.** `4-6`'s own re-baseline noted
   `test_determinism.gd` calls `set_camera_basis` zero times, never exercising the live camera-yaw
   path ("Cause 4's non-move is structural"). Whether the fixture's scripted inputs ever unlock or
   360-cycle is a fact to MEASURE -- if not, cause 3 may be a non-mover the same way.

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
- **Keyboard parity spot check (S7/AC 24-25).** Confirm the proposed keys do not collide with any
  existing bound action on either keyboard slot, even though the scheme itself is not built.
- **Camera/wall behaviour**, per the Non-Goals carve-out: record what an unlocked camera does near
  the arena boundary as a named finding, not a blocker.

Record all items in `docs/playtest-log.md` by the operator's own hand, per `PROC/R8`.

## Dev Notes

- **Tier: A, per operator scope talk ruling S1 (2026-09-16), overriding the board's inherited
  `# Tier B` comment.** Reason stated in the ruling: the unlocked state hands hero facing back to
  input inside `src/state/` (AC 3) and adds a new request to the intent stream (candidate cause 2
  above) -- both are golden-clause triggers on their own, independent of the sprint-status note's
  earlier "AT RISK of Tier A" hedge (`sprint-status.yaml:139`, pre-dating this scope talk). Tier may
  be raised, never lowered, mid-story (`CLAUDE.md` Story tiers) -- it is fixed at Tier A here, at
  the story's own authoring, and stays there.
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
  block/roll), Right Shift (run), O (cast_mode), 6-9 (cards), P (cast_confirm), `'` (debug_reset).
  Global: F1 (debug_pause), F2 (debug_step). Every one of these events carries `"location":0`
  (grepped), confirming AC 25's constraint. A non-conflicting proposal for this story's five new
  actions per slot (lock/unlock, camera-rotate-left, camera-rotate-right, cycle-left, cycle-right):

  | action | P1 | P2 |
  |---|---|---|
  | lock/unlock (the R3 click) | `T` | `Numpad 0` |
  | camera rotate left / right | `F` / `G` | `Numpad 4` / `Numpad 6` |
  | cycle left / right | `Z` / `C` | `Numpad 1` / `Numpad 3` |

  P2's numpad half is unchanged in spirit from `4-6`'s original (never implemented, so not stale in
  the same way) with two rotation keys added on the same pad in the natural 4/6 left/right position.
  Not built, by AC 24's own wording -- a documentation deliverable, per the `4-6` AC 13 precedent.
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
  25's `"location":0` premise and the `4-6` OQ 5 `Q`-collision finding.
- [Source: deferred-work.md:282, id M5, `_46-review.md:276`] — "Keyboard slots can no longer face
  anything but the opposing hero," the gap AC 24 addresses; disposition (b), open until this story.
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
5. **The exact screen-space convention for AC 15's "on-screen-right rotational direction."** Which
   of the two angular senses around the hero a rightward flick selects, pinned against the existing
   `4-6a` adjacency test conventions (which used screen-X sign, not a rotational sense) -- do not
   assume the two conventions agree; state and test the mapping explicitly.
6. **Whether unlocked camera rotation reuses `flick_threshold` (0.7) as its input gate**, or needs
   its own authored deadzone/rate -- the two are different questions (flick is an edge-triggered
   gesture; unlocked rotation is continuous), named in AC 23 but not settled.

## Tasks / Subtasks

- [ ] (S2) Add the unlocked state (OQ 1); wire the three-way click behavior (AC 1).
- [ ] (S3) Make facing and the roll neutral-fallback conditional on lock state (AC 3-5); suppress
      the lock marker while unlocked (AC 6).
- [ ] (S4) Resolve OQ 2 (manual-rotation input shape and record channel); implement unlocked
      camera rotation with an authored rate (AC 7-12).
- [ ] (S5) Replace `LockOnResolver`'s algorithm with bearing-based 360 cycling, wrapping, tie-break
      carried forward (AC 13-19); resolve OQ 5 (rotational-direction convention).
- [ ] (S6) Confirm the unchanged rules (round-start default, death-snap, DEAD/round-over carve-outs,
      `flick_threshold`) still hold under the new lock-state branch (AC 20-23).
- [ ] (S7) Write the keyboard binding proposal into the story's own Dev Agent Record, verified
      non-colliding against `project.godot` (AC 24-25) -- not implemented.
- [ ] Resolve OQ 3 (intent/record shape, `FORMAT_VERSION`); measure golden + snapshot key set
      before/after (Golden Prediction section); operator smoke on every Live Smoke surface.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`.

### Debug Log References

### Completion Notes List

### File List
