---
baseline_commit: 4f8536b2f8167f69ad8f30e693e6bb87c6bbf37a
---

# Story 6.7b: Locomotion Presentation

Status: ready-for-dev

> **Scope note.** Board order item 8 of eleven (decision-log Session 2026-09-08, `E6-P/R2`). Tier
> B by content: presentation-only against `6-7`'s already-shipped state-side two-gait system.
> Gated on its own asset prerequisite (`E6-P/R10`) — the six Mixamo FBXs now sit untracked in
> `assets/characters/paladin/` (walk, walk_strafe_left, walk_strafe_right, walk_backpedal,
> turn_left, turn_right), satisfying it. `E6-P/R8` amendment (ii): walk and turn-in-place
> animations are the PRESENTATION HALF of the locomotion system, not a deferred item.
> Tempo retune (`R1` below) is the one authored-data exception — `walk_speed`/`move_speed` are
> `BalanceConfig` fields, isolated from both the golden and the unit suite (`BC/R3`); the golden is
> predicted unmoved and measured both directions (Golden Prediction below).

## Measured Facts

1. **M1 — the clip-selection function and its per-tick inputs.**
   `AnimationController._locomotion_clip(velocity: Vector3, facing: Vector2) -> StringName`
   (`src/actors/hero/animation_controller.gd:352-362`) is the ONE seat, called from
   `on_locomotion(velocity, facing)` (`:339-342`), itself called unconditionally every tick from
   `HeroActor.drive()` (`src/actors/hero/hero.gd:84`) with `hero_state.velocity` and
   `hero_state.facing` — the same two values `drive()` already reads to yaw the Hitbox/Mesh
   (DECISION A single-yaw-source, `hero.gd:57-68`). `on_locomotion` early-returns unless
   `_state == HeroState.ActionState.IDLE` (`:340-341`); `_locomotion_clip` itself reads no gait,
   no lock state, no balance — only the pushed vector and facing. Gait (walk vs run) is NOT a
   fact this function receives today; it has no way to distinguish the two families.
2. **M2 — the library build/extend tool and the current clip count/loop matrix.**
   `tools/add_paladin_locomotion.gd` is the extend-never-rebuild tool (5-0a precedent): it loads
   `assets/characters/paladin/paladin_anims.res`, asserts `EXISTING_CLIPS` are present untouched,
   then for each entry in `NEW_CLIPS` (a `{name: loop_bool}` map) loads the matching source FBX,
   lifts its single `mixamo_com` take, renames/loops it, and re-saves the library
   (`:40-113`). `test/integration/test_rig_clips.gd:23-28`'s `EXPECTED_LOOP` currently pins
   TWELVE clips: `idle/run/block/strafe_left/strafe_right/backpedal` loop `true`;
   `attack/roll/death/swipe/jump_attack/thrust` loop `false`. Six untracked FBXs
   (`walk`, `walk_strafe_left`, `walk_strafe_right`, `walk_backpedal`, `turn_left`, `turn_right`)
   satisfy `E6-P/R10` and are this story's new `NEW_CLIPS` entries, taking the library to
   EIGHTEEN.
3. **M3 — every reader of authored hero `move_speed`/`walk_speed`, and the retune's blast radius.**
   Authored at `data/balance/balance_config.tres:87-88` (the HERO `[resource]` block, distinct
   from `Resource_kind_minion.move_speed = 3.0` at `:39` and the two `0.0` totem/accelerator
   entries at `:51/:63/:75` — R1 touches ONLY `:87-88`). `BalanceConfig.move_speed`/`walk_speed`
   (`src/state/resources/balance_config.gd:16,19`) are read live at exactly one seat each: `6-7`'s
   `_resolve_movement` gait branch (`match_state.gd`, RUN reads `player.hero.move_speed`, WALK
   reads `balance.walk_speed`, plus the AC-16 BLOCKING-forces-walk carve-out). **Two literal test
   pins tied to the authored pair, both R1 must not silently break:**
   `test/integration/test_hero_movement.gd:25` (`const MOVE_SPEED := 5.0`, asserted at `:57`
   against a run-held hero) and `test/integration/test_unit_approach_live.gd:150`
   (`_hero_speed = maxf(_state.balance.walk_speed, 0.0001)`, ALREADY reading the authored value
   live — `6-7/R11` fixed this one already, unaffected by this story's retune). Every
   `test/state/*.gd` fixture asserting a hero speed (`test_match_state.gd`, `test_camera_basis.gd`,
   `test_contact_resolution.gd`, `test_roll_iframes.gd`, `test_action_state.gd`,
   `test_unblockable_hold.gd`, `test_replay_identity.gd`, `test_determinism.gd`'s
   `_golden_config()`, `test_record_file.gd`, `test_live_reload.gd`) authors its OWN in-test
   `move_speed`/`walk_speed` per `6-7/R11` — the standing `BC/R3` isolation confirmed for this
   retune: none of these fixtures loads the authored `.tres`, so `R1`'s edit reaches none of them.
   Nothing derives from `move_speed` beyond the gait branch and the attack lunge
   (`attack_lunge_distance`, its own separate field, untouched) — no camera or chargeup coupling
   found by content.
   **Correction: the `BC/R3` isolation above holds for `test/state/` only.**
   `test/integration/*.gd` files run the real `MatchRunner` against the AUTHORED `.tres` and are
   NOT isolated by it — `6-7` lost `test_hero_movement.gd` and `test_unit_approach_live.gd` to
   exactly this blind spot (both named above, both already fixed by that story's own `R11`/this
   story's Task 2). A further, UNFIXED candidate:
   `test/integration/test_unit_corpse_walkthrough_live.gd:63-67` sizes `DRIVE_FRAMES := 40`
   against a comment reading "the authored 5.0 move speed" — a literal tied to the pre-`R1`
   value, unmeasured against the post-retune 6.0. The dev pass task below enumerates every such
   file, not only this one named candidate.
4. **M4 — golden isolation, both directions.** `test_determinism.gd:1019`'s
   `GOLDEN := "71a7b45f…"` is built from `_golden_config()` (`:1223`), an in-test
   `BalanceConfig` literal, never `data/balance/balance_config.tres`. **Golden Prediction: R1's
   two-number edit does NOT move the golden** — the dev pass measures both directions (edit
   applied / reverted) to confirm, the standing `BC/R3` discipline every prior tuning-only pass
   has followed. R2-R4 (library/controller/tool changes) touch no `src/state/` file and add no
   snapshot field, so they carry the same prediction for an unrelated, structural reason (Fact
   M6/R5 below).
5. **M5 — every path that changes facing while the hero is stationary in IDLE.**
   `MatchState._resolve_movement` (`match_state.gd:3966-3972`) writes `player.hero.facing` from
   `_lock_directions[slot]` (lock-on target direction) EVERY TICK the CHARGING carve-out doesn't
   apply — including ticks where the hero's velocity is zero (an IDLE hero locked onto a
   circling target). This is the ONLY facing writer besides the CHARGING aim-override two lines
   above it; both run inside the same function `on_locomotion` already receives velocity/facing
   from, every tick, unconditionally.
6. **M6 — the animation controller already receives facing/yaw per tick; no state change needed
   either way.** `on_locomotion(velocity, facing)` fires every tick regardless of whether the
   hero is moving (Fact M1) — turn detection is a matter of `AnimationController` remembering the
   PREVIOUS tick's `facing` and comparing, entirely presentation-side (a new instance var on the
   controller, never a `HeroState` field). `src/state/` needs no new push, no new seam, and no
   new snapshot member for this story (satisfies `R5`).
7. **M7 — none of the six clips is `BC/R3`-governed.** `tools/retime_clips.gd:34`:
   `GOVERNED_CLIPS := [&"attack", &"roll"]`. All six new clips (walk family + both turn clips)
   sit outside it — no retime is triggered by this story, confirmed by content, matching the
   `6-1c`/`6-1b` precedent for clips added outside that list.
8. **M8 (new) — Hips ROTATION is unmeasured by any existing tool.**
   `tools/measure_hips_displacement.gd:20-21,49-53` reads `Skeleton3D:mixamorig_Hips`
   `TYPE_POSITION_3D` tracks ONLY ("rotation/scale are irrelevant to translation drift" — that
   story's own scope, 5-0a). `R3` below needs the Hips ROTATION track's authored yaw per turn
   clip, which no existing instrument reports. The dev pass either extends this measurement (a
   `TYPE_ROTATION_3D` pass on the same track name, same tool-precedent shape) or writes a sibling
   script; either is a HOW choice, not a design one.

## Story

As a player,
I want the hero to visibly walk, run, and turn in place instead of sliding at one speed with no
turning animation,
so that the two-gait system `6-7` shipped state-side reads correctly on screen (`E6-P/R8`
amendment (ii)).

## Acceptance Criteria

1. **[headless-provable, data-only]** `data/balance/balance_config.tres`'s HERO block (`:87-88`)
   retunes `walk_speed` `2.5 -> 2.0` and `move_speed` `5.0 -> 6.0`. No other value in the file
   changes (minion `move_speed = 3.0` at `:39` and the two `0.0` totem/accelerator entries stay as
   they are — hero walk stays below minion approach speed on purpose, `R1`). Per the standing
   `BC/R3` isolation (Fact M4), no golden re-baseline is expected; the dev pass measures the
   golden unmoved in both directions, per every prior tuning-only pass's discipline.
2. **[headless-provable]** `test/integration/test_hero_movement.gd` reads the authored `move_speed`
   from `data/balance/balance_config.tres` LIVE instead of the pinned literal
   `const MOVE_SPEED := 5.0` (Fact M3) — the test loads/derives the value the same way
   `test_unit_approach_live.gd:150` already does for `walk_speed`, so a future tempo retune is a
   one-line `.tres` edit with no test-file edit, matching `walk_speed`'s existing property.
3. **[headless-provable]** The paladin `AnimationLibrary` gains the walk family
   (`walk`, `walk_strafe_left`, `walk_strafe_right`, `walk_backpedal`) and both turn clips
   (`turn_left`, `turn_right`) via `tools/add_paladin_locomotion.gd`, extended on its existing
   `NEW_CLIPS`/`EXISTING_CLIPS` pattern (Fact M2) — never rebuilt from FBX. `test_rig_clips.gd`'s
   `EXPECTED_LOOP` gains all six, ALL loop `true` (walk family on the run family's own precedent;
   `turn_left`/`turn_right` RULED `true` — lock-driven rotation is continuous, and a one-shot
   would freeze on its end pose mid-turn, Dev Notes). Library count assertion moves twelve -> eighteen.
4. **[headless-provable]** Family selection is keyed on the PUSHED PLANAR SPEED, not a new gait
   fact (`R5`/Fact M1: the controller receives no gait today and gains none). In IDLE the pushed
   speed is discrete — zero, walk (`walk_speed`), or run (`move_speed`) — so the threshold is the
   MIDPOINT of the authored pair, `(walk_speed + move_speed) / 2`: below it selects the walk
   family, above it selects the run family (Dev Notes: the pushed velocity length is a float and
   can land a hair above `walk_speed` itself, which would wrongly flip a walking hero to the run
   family under a bare `walk_speed` threshold); the existing direction-relative dot-product split
   (`_locomotion_clip`, Fact M1) then picks the member of whichever family, unchanged. The
   midpoint is computed from the AUTHORED `walk_speed`/`move_speed` pair (CONSTRAINT C: read at
   point of use, or received via the existing per-tick push — never a cached `BalanceConfig`
   reference), NEVER a hardcoded literal — HOW the controller learns the pair (a widened push
   payload, or a presentation-local read) is the dev pass's choice, bounded by no `src/state/`
   change and no new seam. A new integration test (on `test_hero_clip_selection.gd`'s `_cardinals`
   shape) drives this at walk-tempo speed and asserts the four cardinals resolve to the
   walk-family names.
5. **[headless-provable]** At run-tempo speed the existing run family plays unchanged
   (regression-only — `test_hero_clip_selection.gd`'s existing five-case table stays green). A new
   test asserts the TIER BOUNDARY itself, driven under TWO DIFFERENT authored `walk_speed`/
   `move_speed` pairs (not only the shipped 2.0/6.0): under EACH pair, that pair's own walk tempo
   resolves to the walk family and that pair's own run tempo resolves to the run family; AND a
   single velocity magnitude chosen strictly between the two pairs' MIDPOINTS resolves to the walk
   family under one pair and the run family under the other — proving selection tracks each
   pair's authored midpoint rather than a value baked into the controller (a hardcoded threshold
   passes one pair and fails the other by construction, which is exactly what this test is built
   to catch).
6. **[headless-provable]** While the hero is IDLE with near-zero planar velocity (Fact M1's
   `RUN_SPEED_EPS` threshold) AND its pushed `facing` changes tick-to-tick beyond a named,
   untuned minimum yaw-change (the flicker-guard knob, Dev Notes) held for a named minimum number
   of ticks (a short hold, so a slow-circling lock target does not alternate turn/idle tick by
   tick), `turn_left` or `turn_right` plays, selected by the SIGN of the yaw change — never by
   forming a second angle (Dev Notes: the sign-only test avoids a second `atan2`, preserving the
   single-yaw-source contract, `DECISION A`/`1-7b`). Below the threshold, or while velocity is
   above `RUN_SPEED_EPS` (moving), `idle` (or the moving clip) plays and no turn clip is selected —
   turning is IDLE-only by construction, satisfying the Non-Goal below without a separate guard.
   **(a)** The cross-term sign's mapping to `turn_left`/`turn_right` is PROVEN by a test against a
   known rotation direction, never assumed from the formula alone. **(b)** The previous-facing
   memory updates on EVERY push, including non-IDLE ticks — `on_locomotion` early-returns outside
   IDLE today (Fact M1), so the remembered facing must still advance on those ticks, or
   re-entering IDLE after a roll/attack with a changed facing fires a spurious turn against a
   stale previous-facing value. A new integration test drives: two consecutive facings under zero
   velocity (both turn directions); the no-turn cases (facing unchanged; facing changed while
   moving); and (b)'s case — a facing change DURING a non-IDLE action followed by a return to IDLE
   with no further facing change, asserting no spurious turn fires.
7. **[headless-provable, or a reported STOP]** Each turn clip's authored `mixamorig_Hips`
   ROTATION track is measured (Fact M8) for its accumulated YAW (rotation about the vertical
   axis) and that yaw is neutralised IN THE LIBRARY TOOL (`tools/add_paladin_locomotion.gd`,
   never the source FBX) so the clip does not add body rotation on top of `HeroActor.drive()`'s
   single yaw write (`DECISION A`) — the `3-0b` roll-Hips precedent (position-track zeroing)
   extended to a rotation track's yaw component ONLY, leaving the rest of the Hips motion (sway,
   tilt) untouched. Measured before/after: net yaw ~0 post-fix, every other axis unchanged from
   the pre-fix track. Each clip's PRE-neutralisation yaw SIGN is also recorded and checked against
   its file name (`turn_left` should rotate one way, `turn_right` the other); a mismatch is a
   file-swap defect, fixed per `R4` (source-file swap, never a code-side correction), not absorbed
   into the neutralisation step. The left/right sign convention itself is proven by a test against
   a known rotation (AC 6(a)), not assumed. If yaw neutralisation is not achievable at the
   library-tool level, the dev pass STOPS and reports the specific measured obstruction instead of
   shipping a double-rotating turn — there is no In-Place-re-download fallback (In Place strips
   TRANSLATION, not rotation, so it cannot fix this).
8. **[not headless-tested, a named feel knob]** The EIGHT walk-and-run-family clips (`walk`,
   `walk_strafe_left`, `walk_strafe_right`, `walk_backpedal`, `run`, `strafe_left`,
   `strafe_right`, `backpedal`) each play at a PER-CLIP custom speed computed as
   `pushed_speed / family_native_speed` — named native-speed constants (on the
   `RUN_SPEED_EPS`/`STRAFE_BAND_RATIO` precedent, not inlined), so playback rate follows future
   tempo retunes automatically instead of needing a retune of its own. This applies to the RUN
   family too: `move_speed`'s native speed is 5.0 (the pre-`R1` value — the run family already
   plays correctly AT that speed today), so at the retuned 6.0 it plays at 1.2x and keeps today's
   foot match; the walk family's native speed is a STATED STARTING VALUE (measured from the clip
   if cheap, otherwise authored as a first guess), tuned against `walk_speed = 2.0` by the live
   smoke. **`turn_left`/`turn_right` are NOT speed-scaled** — they are selected exactly when
   pushed speed is ~0 (AC 6), so the `pushed_speed / native_speed` formula would freeze them; each
   plays at its own FIXED named rate knob, default `1.0`, untouched by gait or tempo. `idle`
   playback is unchanged (native, no custom speed, as today). **`AnimationPlayer.speed_scale`
   MUST NOT be used** — it is GLOBAL and would also retime `attack`/`roll`/every charge clip,
   including the `BC/R3`-governed pair (`GOVERNED_CLIPS`, Fact M7) and the `6-1b` chargeup
   playhead (`animation_controller.gd:313-323`, which drives its own `seek()` and would desync
   under a global scale change). Every custom speed here — the eight family clips' computed rate
   and the two turn clips' fixed rate alike — applies via `play()`'s own speed parameter, scoped
   to these TEN locomotion clips only; `idle`/`attack`/`roll`/`block`/`death`/charge playback is
   unaffected. Not pinned by any test (`6-1b` precedent: feel knobs never require a suite run);
   the live smoke judges the walk native-speed starting value and the turn fixed-rate knob.
9. **[smoke-only]** Live smoke per the Live Smoke section below.
10. **[headless-provable]** Full suite green before and after; `src/state/` byte-identical (a
    `git diff --stat -- src/state/` run before commit, reported empty); no new `to_snapshot()`
    member; `FORMAT_VERSION` unmoved at 11; golden `71a7b45f…` measured UNMOVED in both directions
    (Fact M4); suite-file timestamps (before/after) measured and reported per the Tier B machine-
    time convention (`R6`).

## Non-Goals

- **Walking while blocking.** BLOCKING already forces `walk_speed` (`6-7/R10`); this story does
  not touch the block pose, and a walking block will visibly slide (a per-bone blend is needed,
  not built here). Named as a live-smoke watch item, not fixed.
- **Rate-limited turning while MOVING.** Turning is IDLE-only (AC 6); a moving hero's body facing
  a locked target with no matching turn animation is unchanged behaviour from today and is out of
  scope — it is a gameplay/feel change, not a presentation wiring one.
- **Camera work** (`6-8-camera-freedom`).
- **Minions** — this story is the paladin's rig only.
- **Any retune beyond `R1`'s two numbers.** `STRAFE_BAND_RATIO`, `LOCOMOTION_BLEND_SECONDS`,
  `run_stamina_drain_per_second`, and every other `6-7` threshold are untouched unless the walk
  family MEASURABLY needs one of them changed to read correctly (report it if so — do not absorb
  it silently). AC 8's per-clip native-speed constants are PRESENTATION knobs, not a balance
  retune — they live beside `RUN_SPEED_EPS`/`STRAFE_BAND_RATIO` in `AnimationController`, never in
  `BalanceConfig`.

## Golden Prediction

**Golden hash: predicted UNMOVED, both directions.** Two independent reasons, each on its own
prior-story precedent: (1) `R1`'s retune is authored-data-only, isolated from the golden by the
standing `BC/R3` property (Fact M4) — `test_determinism.gd`'s `_golden_config()` never reads
`data/balance/balance_config.tres`; (2) every other change in this story (library contents,
controller clip-selection logic, the tool script) lives entirely in `src/actors/` and `tools/`,
never `src/state/`, and adds no `HeroState`/`MatchState` snapshot member — nothing for
`to_snapshot()`'s hash chain to see. The dev pass measures the golden before and after the FULL
story (not just `R1` in isolation) to confirm both predictions hold together, on the `E3-RG/R2`
discipline every prior E6 story has followed. `FORMAT_VERSION` stays 11 — no `RecordFile`
round-trip shape changes.

## Live Smoke

Config per `6-7/R19`: **two gamepads**, both runner slots flipped to `ControllerKind.GAMEPAD`
(`slot_controller_kinds = [3, 3]`, text-edited into `main.tscn` with the editor closed, `git diff`
reported verbatim, reverted wholesale after — `main.tscn` carries no other intentional change this
story). The dev pass imports the six FBX files via the editor's own scan — `git diff -- project.godot`
is run and reviewed after EVERY editor/import session in this story, not only after the smoke's
own `main.tscn` edit. `project.godot` is NEVER reverted wholesale (it carries `6-7`'s
`p1_run`/`p2_run` binds) — any diff found is sorted PER-DIFF, on the physics-pin-deletion incident
class (the standing hazard project-context.md and prior close-outs both name).

Cover, in order:
1. Walking is the default with no run key held — visibly slower than before (2.0 vs. the prior
   2.5), no visible foot slide at the new speed (AC 8's knob).
2. Holding A on either pad produces the run family at the new, faster 6.0 speed.
3. Strafing and backpedaling play the correct side/direction clip at BOTH tempos (walk and run).
4. Turning in place: lock on, let the target circle (or manually re-lock to a target on the other
   side) while standing still — the correct-side turn clip plays, with no double rotation (the
   body doesn't spin faster/slower than the model's own turn animation implies — AC 7's
   neutralisation, judged by eye against the fixed facing).
5. Walk<->run transitions are soft (the existing `LOCOMOTION_BLEND_SECONDS` crossfade); action-
   state entries (attack/block/roll) remain an instant cut, unaffected.
6. Tempo feel verdict: is 2.0/6.0 right, or does it need a further (out-of-scope-here, reported)
   retune?
7. Blocking-while-walking slide (Non-Goal) — confirm it is as expected, not a surprise defect.
8. FPS stable, no stutter from the larger library or the new per-tick facing-delta check.
9. The turn clip plays on the CORRECT SIDE (`turn_left` for a leftward yaw change, `turn_right`
   for rightward) — AC 7's file-name/sign cross-check, judged live as the last line of defence
   behind the headless sign test.
10. `walk` and `walk_backpedal` play in the CORRECT DIRECTION at walk tempo (forward vs. backward,
    `R4`'s unverified file-name mapping) — if wrong, the fix is a source-file swap, never a code
    change.
11. The run family's FOOT MATCH at the retuned 6.0 speed (AC 8's native-speed rate keeping the
    same visual foot-plant cadence the pre-`R1` 5.0 run had).

## Tasks / Subtasks

- [ ] Task 1 (AC 1): Retune `data/balance/balance_config.tres` HERO block only; measure golden
  before/after.
- [ ] Task 2 (AC 2): Make `test_hero_movement.gd` read `move_speed` live.
- [ ] Task 3 (AC 3, AC 7): Extend `tools/add_paladin_locomotion.gd`'s `NEW_CLIPS`/`EXISTING_CLIPS`
  for the six new clips; measure each turn clip's Hips ROTATION track's yaw component (Fact M8),
  record its pre-fix sign against the file name (mismatch = `R4` source-file swap), and neutralise
  ONLY that yaw in the library tool (sway/tilt untouched, source FBX untouched) or STOP; extend
  `test_rig_clips.gd`'s `EXPECTED_LOOP` (all six loop `true`).
- [ ] Task 4 (AC 4, AC 5): Add a pushed-speed-vs-authored-MIDPOINT family dispatch to
  `AnimationController`'s clip-selection path (`(walk_speed + move_speed) / 2`, walk vs. run
  family), reading the authored pair per CONSTRAINT C; extend `test_hero_clip_selection.gd` with
  walk-tempo cardinals and the two-pair tier-boundary case (each pair's own tempos, plus a
  between-midpoints probe).
- [ ] Task 5 (AC 6): Add turn-in-place detection — previous-tick facing memory updated on EVERY
  push (including non-IDLE ticks); turn-clip selection gated to IDLE + near-zero velocity only,
  past a named minimum yaw-change held for a named minimum tick count; new integration test for
  both directions, the sign-mapping proof (AC 6(a)), the no-turn cases, and the post-action
  spurious-turn case (AC 6(b)).
- [ ] Task 6 (AC 8): Add per-clip native-speed constants for the eight walk+run family clips
  (`pushed_speed / native_speed` custom play rate, never `AnimationPlayer.speed_scale`); state
  the walk native-speed starting value; add a separate fixed named rate knob (default `1.0`) for
  `turn_left`/`turn_right`, unscaled by pushed speed; live smoke tunes both against foot slide and
  turn feel.
- [ ] Task 7 (`M3` correction): Enumerate every `test/integration/*.gd` file that drives hero
  movement through the real runner against the AUTHORED `.tres` and asserts position, reach,
  distance, or timing; report each as measured-green-under-`R1` or fixed. Known candidate:
  `test_unit_corpse_walkthrough_live.gd`'s `DRIVE_FRAMES := 40` (sized against a 5.0-move-speed
  comment). Allowed fix = read the authored value live or re-derive the frame count — never widen
  a tolerance.
- [ ] Task 8: Full suite before/after, `src/state/` diff-empty check, golden both directions,
  suite-file timestamps.
- [ ] Task 9 (AC 9): Live smoke per the section above.

## Dev Notes

- **No `src/state/` change of any kind (`R5`).** Family selection (AC 4/AC 5) is keyed on the
  pushed planar speed against the MIDPOINT of the authored `walk_speed`/`move_speed` pair,
  `(walk_speed + move_speed) / 2` — not a bare `walk_speed` threshold, because the pushed
  velocity length is a float and can land a hair above `walk_speed` itself (floating-point
  residue on a walking tick), which would wrongly flip a walking hero to the run family. That
  dispatch itself is RULED, not a dev-pass choice. What remains HOW: whether the controller reads
  the authored pair via a widened per-tick push (`on_locomotion` gaining two more floats) or a
  presentation-local read at point of use (CONSTRAINT C forbids caching either way) — so long as
  no `src/state/` file changes and no snapshot key is added.
- **Turn detection stays off `DECISION A`'s single-yaw-source contract.** Compute the SIGN of the
  facing change without forming a second angle — e.g. a cross-like term
  `prev.x*cur.y - prev.y*cur.x` (positive/negative gives the turn direction) compared against a
  named minimum-magnitude knob, held for a named minimum tick count (the flicker guard, AC 6),
  before selecting a turn clip, on the existing controller's own "two projections, never an
  angle" style (`animation_controller.gd:36-44`). No `atan2` call belongs in this controller. The
  remembered previous facing is updated on EVERY `on_locomotion` push, IDLE or not (AC 6(b)) —
  only the TURN-CLIP SELECTION is IDLE-gated, not the memory update feeding it.
- **Hips rotation neutralisation (AC 7) is the one AC where mechanism is placed by a ruling**, not
  left to the dev pass: measure first (extend or sibling `tools/measure_hips_displacement.gd` for
  rotation tracks — YAW component only), then zero ONLY that yaw component in the library tool
  (the `3-0b` roll-Hips precedent, extended from a position track to a rotation track's yaw axis),
  leaving sway/tilt untouched. The source FBX is never edited. There is no In-Place-re-download
  fallback — In Place strips translation, not rotation, so it cannot neutralise an accumulated
  yaw; report a STOP if the library-tool fix is not viable.
- **Turn clip loop flags are RULED `true`, not measured.** Lock-driven rotation is continuous —
  the hero may need to keep turning for as long as the lock target keeps circling — and a one-shot
  clip would freeze on its final pose mid-turn while the yaw delta kept firing. This is the walk
  family's own precedent applied to the turn pair, not a pattern-match on the name.
- **File-name mapping is unverified (`R4`), fix by source-file swap only.** `walk` vs.
  `walk_backpedal` and the L/R pair were assigned from Mixamo download order and the Mixamo
  preview mirrors left/right (`5-0a/R1` precedent). If the dev pass or live smoke finds a mapping
  wrong, the fix is swapping the SOURCE FILES via a temp rename — `.import` sidecars are path-
  bound, so a code-side fix is wrong. `turn_left`/`turn_right` are operator-verified DIFFERENT
  files (SHA256) — not verified to be a correctly-mirrored pair.

### Project Structure Notes

- Touches: `src/actors/hero/animation_controller.gd` (edit), `tools/add_paladin_locomotion.gd`
  (edit), `data/balance/balance_config.tres` (edit, two values), `test/integration/
  test_hero_movement.gd` (edit), `test/integration/test_rig_clips.gd` (edit),
  `test/integration/test_hero_clip_selection.gd` (edit — new cases) or a new sibling file if the
  dev pass judges the walk-tier/tier-boundary/turn cases don't fit the existing file's shape.
  Possibly a new/extended `tools/measure_*` script for AC 7's rotation measurement.
- No new folder, no new autoload, no new seam.

### Project Context Rules

- Static typing, `snake_case.gd` naming, and the existing headless test-harness pattern
  (`test/integration/*.gd extends SceneTree`) apply throughout — no GUT, per project-context.md.
- `Input.*` untouched (D3) — this story adds no controller code.
- The HARD RULE (state/visual separation) is exactly what `R5` restates for this story: the
  animation layer reads state, never decides it.

### References

- [Source: src/actors/hero/animation_controller.gd:1-384 (clip-selection machinery, Fact M1/M6)]
- [Source: tools/add_paladin_locomotion.gd:1-114 (extend pattern, Fact M2)]
- [Source: data/balance/balance_config.tres:87-88 (hero block, Fact M3/AC 1)]
- [Source: test/integration/test_hero_movement.gd:22-57 (literal speed pin, AC 2)]
- [Source: test/integration/test_unit_approach_live.gd:150 (already-live walk_speed precedent)]
- [Source: test/integration/test_rig_clips.gd:1-29 (loop-matrix pattern, AC 3)]
- [Source: test/integration/test_hero_clip_selection.gd:1-167 (direction-split test pattern, AC 4/5)]
- [Source: src/state/match_state.gd:3966-3977 (facing writer, Fact M5)]
- [Source: tools/measure_hips_displacement.gd:1-31 (position-only measurement, Fact M8/AC 7)]
- [Source: tools/retime_clips.gd:34 (GOVERNED_CLIPS, Fact M7)]
- [Source: src/actors/hero/hero.gd:57-84 (DECISION A single yaw source, drive())]
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:9301-9401
  (`E6-P/R2`, `R7`-`R10`, amendment (ii))]
- [Source: docs/implementation-artifacts/6-7-locomotion-gaits.md (state-side two-gait system this
  story presents)]
- [Source: test/integration/test_unit_corpse_walkthrough_live.gd:63-67 (`DRIVE_FRAMES` literal
  tied to pre-`R1` move speed, Task 7)]

## Change Log

- 0.1 — authored (2026-09-16).
- 0.2 — browser review fixes F1-F11 applied, promoted to ready-for-dev (2026-09-16) (+ amend A1-A3).

## Dev Agent Record

### Agent Model Used

(unassigned — story not yet handed to a dev pass)

### Debug Log References

### Completion Notes List

### File List
