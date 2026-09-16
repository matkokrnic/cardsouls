---
baseline_commit: 4f8536b2f8167f69ad8f30e693e6bb87c6bbf37a
---

# Story 6.7b: Locomotion Presentation

Status: done

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

   **Amended 2026-09-16 (operator live smoke).** Operator live smoke (item 6) retuned further, past
   the dev pass's `2.0`/`6.0`: FINAL tempo is `move_speed = 5.5`, `walk_speed = 2.2` — HEAD (pre-story)
   carried `5.0`/`2.5`. `data/balance/balance_config.tres`'s hero block (`:87-88`) is the only edit;
   minion `move_speed = 3.0` and the `0.0` totem/accelerator entries are untouched, same as `R1`. The
   `BC/R3` isolation still holds: golden `71a7b45f…` re-measured unmoved under the smoke-tuned values
   (Dev Agent Record, this pass), no test edit needed for the values themselves.
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

   **Amended 2026-09-16 (operator live smoke).** Operator smoke finding (item 4): standing still
   under lock, the hero played turn steps when the target circled near or fast, but with the target
   FAR (a low angular rate) the body rotated in the idle pose instead — a slide, not a step. Cause:
   `TURN_MIN_FACING_CROSS` (~sin(0.5 deg) per tick, ~30 deg/s at 60 Hz) doubled as the de-facto
   MINIMUM SELECTABLE ROTATION RATE, so a low-angular-rate target never cleared it. Operator ruling
   (option (a)): turn steps play for ANY sustained in-place rotation above a small noise floor — the
   floor is now a named knob far below realistic lock rotation rates (`TURN_MIN_FACING_CROSS :=
   0.00087`, ~sin(0.05 deg) per tick, ~3 deg/s at 60 Hz, operator re-smoke tuned) — and the 3-tick hold
   (`TURN_MIN_HOLD_TICKS`)
   stays unchanged. AC 8's amendment below covers HOW the clip then plays at a rate that matches the
   actual rotation instead of a fixed 1.0x. A new test (`test_hero_turn_in_place.gd::
   _slow_sustained_rotation_selects_turn`) proves a 5 deg/s sustained rotation — a BEHAVIOURAL
   requirement, not derived from the floor knob — selects a turn clip once the hold clears; the
   existing sub-threshold case (`_no_turn_cases`) keeps reading `TURN_MIN_FACING_CROSS` directly and
   needed no edit.
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

   **Amended 2026-09-16 (operator live smoke).** At the smoke-tuned tempo (AC 1 amendment,
   `move_speed = 5.5`, `walk_speed = 2.2`): the run family plays at `5.5 / RUN_FAMILY_NATIVE_SPEED
   (5.0) = 1.1x`; the walk family plays at `2.2 / WALK_FAMILY_NATIVE_SPEED (1.82) = 1.2088x` (~1.21x)
   — `WALK_FAMILY_NATIVE_SPEED` itself is unchanged from the dev pass's measured `1.82` (Task 6; not
   part of this smoke pass's retune). Any remaining harshness in the walk-to-idle or idle-to-walk
   transition comes from the INSTANT velocity change under the fixed `LOCOMOTION_BLEND_SECONDS`
   crossfade (retuned `0.12 -> 0.25` this same smoke pass, item 6), not from the per-clip rate above,
   and is deferred to a future retune block rather than fixed here.

   **Turn playback rate, retired fixed knob (operator live smoke item 4, ruling option (a)).**
   `TURN_CLIP_SPEED := 1.0` is RETIRED. The two turn clips now play at `rotation_rate /
   TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC`, clamped to `[TURN_MIN_PLAYBACK_RATE,
   TURN_MAX_PLAYBACK_RATE]` — new named knobs beside `RUN_FAMILY_NATIVE_SPEED`/
   `WALK_FAMILY_NATIVE_SPEED`, same precedent. `rotation_rate` is derived from the per-tick facing
   cross term already computed by `_track_facing` (small-angle approximation: the cross term IS the
   sine of the per-tick yaw change for unit facings, so for the small angles a lock-driven turn
   produces, `rotation_rate_deg_per_sec ≈ rad_to_deg(|cross|) * Engine.physics_ticks_per_second`) —
   still no second `atan2`, `DECISION A` intact. `TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC := 106.4165`,
   MEASURED (`tools/measure_hips_displacement.gd`'s rotation table): `turn_right` source Hips yaw
   99.318 deg / 0.9333 s = 106.4159 deg/s, `turn_left` 99.319 deg / 0.9333 s = 106.4170 deg/s — the
   two agree to 0.001 deg/s, so one constant serves both. Starting knobs: `TURN_MIN_PLAYBACK_RATE :=
   0.6` (operator re-smoke tuned; so very slow turns still read as stepping, not frozen),
   `TURN_MAX_PLAYBACK_RATE := 2.0` (caps a fast snap-turn's clip rate); both are smoke knobs, not
   pinned by any test, on the same "not headless-tested, a feel knob" footing as this AC's other
   rates. A rate update re-issues `play()` on the already-playing turn clip exactly as the family
   clips already do (`_play`'s `_PLAYBACK_SPEED_EPS` guard, unchanged) — measured (this pass,
   `test_hero_turn_in_place.gd`) to update the rate without restarting the clip or moving its
   playhead, same semantics `_play`'s own header already documents for the family clips. A new test
   (`test_hero_turn_in_place.gd::_rate_proportional_to_rotation_rate`) asserts the RATIO of two
   in-clamp-range playing speeds equals the ratio of their rotation rates, never a knob value.
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

## Live Smoke Results

Config: two GAMEPAD slots (`slot_controller_kinds = [3, 3]`) per the flip instructions above; no
deviation from the config section was reported by the operator.

1. PASS: walk slower, no foot slide ("maybe a touch too slow", retuned, see 6).
2. PASS: run faster, feet follow the ground ("maybe slightly too fast", retuned, see 6).
3. PASS: strafe/backpedal clips correct while orbiting.
4. FAIL, then fix pass, then re-smoke:
   - Round 1: turn steps played only near or fast; far targets slid in the idle pose.
   - Fix: steps for any sustained rotation, rate proportional.
   - Re-smoke: works continuously but looked odd ("slightly worse than before").
   - Tune: `TURN_MIN_PLAYBACK_RATE` `0.25 -> 0.6`, floor -> `0.00087`. Operator: better. Accepted.
5. PASS with note: transitions felt rough; blend `0.12 -> 0.25`. Remaining harshness is the instant
   velocity change -> retune block.
6. Tempo: operator tried `2.5`/`5.5`, final `2.2` walk / `5.5` run.
7. Watch confirmed: walking block slides; operator prefers no slide but accepts it (no animation) ->
   deferred.
8. PASS: fps stable.

Final knob values: `TURN_MIN_PLAYBACK_RATE := 0.6`, `TURN_MIN_FACING_CROSS := 0.00087`,
`TURN_MAX_PLAYBACK_RATE := 2.0`, `LOCOMOTION_BLEND_SECONDS := 0.25`, hero `move_speed = 5.5`,
`walk_speed = 2.2`.

## Tasks / Subtasks

- [x] Task 1 (AC 1): Retune `data/balance/balance_config.tres` HERO block only; measure golden
  before/after.
- [x] Task 2 (AC 2): Make `test_hero_movement.gd` read `move_speed` live.
- [x] Task 3 (AC 3, AC 7): Extend `tools/add_paladin_locomotion.gd`'s `NEW_CLIPS`/`EXISTING_CLIPS`
  for the six new clips; measure each turn clip's Hips ROTATION track's yaw component (Fact M8),
  record its pre-fix sign against the file name (mismatch = `R4` source-file swap), and neutralise
  ONLY that yaw in the library tool (sway/tilt untouched, source FBX untouched) or STOP; extend
  `test_rig_clips.gd`'s `EXPECTED_LOOP` (all six loop `true`).
- [x] Task 4 (AC 4, AC 5): Add a pushed-speed-vs-authored-MIDPOINT family dispatch to
  `AnimationController`'s clip-selection path (`(walk_speed + move_speed) / 2`, walk vs. run
  family), reading the authored pair per CONSTRAINT C; extend `test_hero_clip_selection.gd` with
  walk-tempo cardinals and the two-pair tier-boundary case (each pair's own tempos, plus a
  between-midpoints probe).
- [x] Task 5 (AC 6): Add turn-in-place detection — previous-tick facing memory updated on EVERY
  push (including non-IDLE ticks); turn-clip selection gated to IDLE + near-zero velocity only,
  past a named minimum yaw-change held for a named minimum tick count; new integration test for
  both directions, the sign-mapping proof (AC 6(a)), the no-turn cases, and the post-action
  spurious-turn case (AC 6(b)).
- [x] Task 6 (AC 8): Add per-clip native-speed constants for the eight walk+run family clips
  (`pushed_speed / native_speed` custom play rate, never `AnimationPlayer.speed_scale`); state
  the walk native-speed starting value; add a separate fixed named rate knob (default `1.0`) for
  `turn_left`/`turn_right`, unscaled by pushed speed; live smoke tunes both against foot slide and
  turn feel.
- [x] Task 7 (`M3` correction): Enumerate every `test/integration/*.gd` file that drives hero
  movement through the real runner against the AUTHORED `.tres` and asserts position, reach,
  distance, or timing; report each as measured-green-under-`R1` or fixed. Known candidate:
  `test_unit_corpse_walkthrough_live.gd`'s `DRIVE_FRAMES := 40` (sized against a 5.0-move-speed
  comment). Allowed fix = read the authored value live or re-derive the frame count — never widen
  a tolerance.
- [x] Task 8: Full suite before/after, `src/state/` diff-empty check, golden both directions,
  suite-file timestamps.
- [x] Task 9 (AC 9): Live smoke per the section above.

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
- 0.3 — dev pass (2026-09-16, Opus 5): Tasks 1-8 implemented; Task 9 (live smoke) left open for the
  operator. Walk-strafe and turn source files swapped per `R4` (operator ruling in-session: controller
  left/right convention). Golden `71a7b45f…` unmoved both directions; `src/state/` untouched. Status
  -> review.
- 0.4 — fix pass (2026-09-16, Sonnet 5): operator live smoke item 4 (turn-in-place slide at low
  angular rate) fixed per operator ruling (a): `TURN_MIN_FACING_CROSS` lowered to a true noise floor,
  turn playback rate now proportional to the measured rotation rate (`TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC`,
  measured, replaces the retired `TURN_CLIP_SPEED`), clamped to new `TURN_MIN_PLAYBACK_RATE`/
  `TURN_MAX_PLAYBACK_RATE` knobs. Operator smoke-tuned final tempo/blend values (`move_speed 5.5`,
  `walk_speed 2.2`, `LOCOMOTION_BLEND_SECONDS 0.25`) carried forward unchanged (AC 1/AC 8 amendments).
  Two new tests in `test_hero_turn_in_place.gd`; golden `71a7b45f…` re-measured unmoved; `src/state/`
  untouched. Status stays `review` (operator instruction).
- 0.5 — close-out chain (2026-09-16, Sonnet 5): dev-pass record and live smoke results recorded (Task
  9 -> [x]); `_rate_proportional_to_rotation_rate` rewritten to derive its rates from the clamp knobs
  (M10 re-proved RED); AC 1/AC 6/AC 8 amendment text corrected to the operator's re-smoke-tuned final
  values (`TURN_MIN_PLAYBACK_RATE 0.6`, `TURN_MIN_FACING_CROSS 0.00087`) and the AC 8 amendment moved
  out of the original sentence it had interrupted. Full suite green (854 state / 62 integration).
  Status -> done (board close-out, C4).

## Dev Agent Record

### Agent Model Used

Opus 5 (operator-stated)

### Debug Log References

- **Skill activation.** `python3 _bmad/scripts/resolve_customization.py` FAILED (`Python was not found` — no
  `python3` on PATH); the identical command under `C:\Python312\python` resolved the workflow block
  (prepend/append empty; `persistent_facts` = project-context.md; `on_complete` = the CFG/R5 board
  revert). Resolved by the script, not by hand.
- **Preconditions (all matched):** HEAD = origin/main = `1693629`; `git status --short` = exactly the six
  untracked FBX; no godot process.
- **Suite outputs (outside the repo; counts read by opening the files):**

  | Run | File | START | END (file mtime) | Result |
  |---|---|---|---|---|
  | before, state | `C:\dev\_6-7b-suite-before-state.txt` | 2026-09-16 15:47:11 | 15:47:25 | 854 tests, 0 failed, 6965 assertions — RESULT PASS |
  | before, integration | `C:\dev\_6-7b-suite-before-int.txt` | 15:47:31 | 15:51:50 | 60 files, 60 PASS — INTEGRATION ALL PASS |
  | after, state | `C:\dev\_6-7b-suite-after-state.txt` | 16:12:02 | 16:12:12 | 854 tests, 0 failed, 6965 assertions — RESULT PASS |
  | after, integration | `C:\dev\_6-7b-suite-after-int.txt` | 16:12:18 | 16:16:38 | 61 files, 61 PASS — INTEGRATION ALL PASS |

  Two full runs only (before/after), each state and integration as separate foreground calls with a
  600000 ms timeout; nothing backgrounded, no batching needed. Tier B instrument (dev pass only):
  15:47:11 -> 16:16:38 = 29m27s.
- **Editor/import sessions (`godot --headless --editor --quit --path .`), `project.godot` SHA256
  `62b2aa15…ab829f` before and after EVERY session, `git diff -- project.godot` = 0 lines each time:**
  1. Import of the six FBX. Six `.fbx.import` sidecars generated; their `[params]` blocks are
     byte-identical to `run.fbx.import`'s (checked with `diff`; `import_script/path=""`, no strip hook).
     No textures extracted. Side effect: the scan also wrote `.uid` files for eleven PRE-EXISTING
     files that had none (listed in the chat report / `git status`) — not this story's files, left
     untouched and unstaged.
  2. Re-import after the `R4` source-file swap (below). `project.godot` unchanged; the four swapped
     sidecars still byte-identical in `[params]`.
  3. Class-cache/uid scan for the new `test/integration/test_hero_turn_in_place.gd` (its `.uid` created).
     `project.godot` unchanged.
- **Golden (scratch probe `print_golden.gd`, outside the repo: instantiates `test_determinism.gd`, prints
  `_run()` beside `GOLDEN`):** before any edit `71a7b45f1a54…595fcb1` MATCH; after the full story (R1
  applied, `.tres` SHA `93ba1d6f…`) `71a7b45f…` MATCH; with R1 reverted (pre-R1 backup copied in, SHA
  `1e3f7639…`) `71a7b45f…` MATCH; R1 restored from its backup, SHA re-confirmed `93ba1d6f…` (match YES).
  `test/state/test_determinism.gd::test_state_matches_golden` also green in both suite runs.
- **`git diff --stat -- src/state/`:** empty (0 lines). `FORMAT_VERSION` = 11 (`src/systems/record_file.gd:195`).
  No `to_snapshot()` member added (no state file touched).
- **Scratch instruments (session scratchpad, not committed):** `probe_rig.gd` / `probe_axes.gd` (skeleton
  transform and bone rest positions), `probe_foot_speed.gd` (planted-toe slide speed/direction per clip),
  `probe_play_speed.gd` (AnimationPlayer re-play semantics), `mut.sh` + snippet files (mutation harness).

#### Fix pass (2026-09-16, Sonnet 5, operator live smoke item 4)

- **Preconditions.** HEAD = origin/main = `1693629`; `git status --short` matched
  `C:\dev\_6-7b-review-pre.txt` exactly (15 M + 26 ??); `src/main/main.tscn` unmodified; no godot
  process. `move_speed`/`walk_speed` mismatched the prompt's stated `5.5`/`2.5` (actual `5.5`/`2.2`) —
  raised and corrected by the operator in-session: `2.2` is the smoke-tuned FINAL value, the prompt's
  "`2.5`, unchanged from HEAD" was the reviewer's error; HEAD itself carried `2.5` and the uncommitted
  pass already moved it to `2.2`. `LOCOMOTION_BLEND_SECONDS := 0.25` matched.
- **Suite outputs (outside the repo; counts read by opening the files), single full run:**

  | Run | File | START | END (file mtime) | Result |
  |---|---|---|---|---|
  | state | `C:\dev\_6-7b-fix-suite-state.txt` | 2026-09-16 18:38:55 | 18:43:46 | 854 tests, 0 failed, 6965 assertions — RESULT PASS |
  | integration | `C:\dev\_6-7b-fix-suite-int.txt` | 18:43:54 | 18:48:05 | 62 files, 62 PASS — INTEGRATION ALL PASS |

  State and integration run as separate foreground calls, 600000 ms timeout each; one full run only
  (this is a fix pass on top of an already-reviewed tree, not a before/after retune).
- **Golden (scratch probe `print_golden.gd`, outside the repo, same method as the dev pass — instantiates
  `test_determinism.gd`, prints `_run()` beside `GOLDEN`):** `71a7b45f1a54…595fcb1` MATCH, run after the
  fix pass's edits (smoke-tuned `.tres` values already in place, animation_controller.gd's turn-rate
  fix applied). `test/state/test_determinism.gd::test_state_matches_golden` also green in the suite run
  above.
- **`git diff --stat -- src/state/`:** empty (0 lines) — this pass touches
  `src/actors/hero/animation_controller.gd`, `test/integration/test_hero_turn_in_place.gd`, and this
  story file only; no `src/state/` file touched.
- **Mutation proofs (M10, M11 below):** target `src/actors/hero/animation_controller.gd` backed up to
  `C:\dev\_6-7b-fix-mut\animation_controller.gd.orig` before any mutation, SHA256 `9666f80f…`; each
  mutation applied by exact byte replace (`C:\Python312\python`), only `test_hero_turn_in_place.gd`
  run, target restored by copy in the same Bash call, SHA256 re-confirmed `9666f80f…` both times.
  `git checkout --` never used.
- **Integration count (dev BEFORE/AFTER vs. this pass).** The story's own Debug Log table above states
  "60 files" (before) and "61 files" (after), but re-counting `--- test/integration` lines in the
  actual saved files shows `C:\dev\_6-7b-suite-before-int.txt` = **61** files and
  `C:\dev\_6-7b-suite-after-int.txt` = **62** files — the story's own "60"/"61" prose figures are
  undercounts by one each (no such total line is machine-printed in either file; they were typed
  summaries). Diffing the file LISTS (not just counts) between before and after shows exactly one
  addition: `test/integration/test_hero_turn_in_place.gd` (new this story, Task 5) — no other file
  appeared or disappeared. The review's own file, `C:\dev\_6-7b-review-suite-int.txt`, lists the same
  62 files as the after-run, byte-for-byte identical file list (its stated "62" is correct). This
  fix pass's own run, `C:\dev\_6-7b-fix-suite-int.txt`, also lists the same 62 files — this pass adds
  no new integration test FILE (the two new tests live inside the existing
  `test_hero_turn_in_place.gd`).

### Per-clip measurement table (post-swap values only)

`tools/measure_hips_displacement.gd` (extended this story with the rotation/yaw table), run after the
final library build. Yaw about skeleton +Y by swing-twist; + = toward model +X = the controller's
"right". "src" = the Mixamo take in the FBX (pre-fix); "lib" = `paladin_anims.res` (post-fix).
Direction column: `probe_foot_speed.gd`, travel direction of the body implied by the planted foot.

| Clip | len (s) | Hips net translation (x,y,z) | net_zero | src net yaw (sign vs name) | lib net yaw / peak | max swing diff lib vs src | max Hips pos diff lib vs src | travel dir (model) |
|---|---|---|---|---|---|---|---|---|
| `walk` | 1.1000 | (0.0000, -0.0000, 0.0000) | YES | 0.000 (none) | 0.000 / 9.649 (untouched) | 0.00000° | 0.000000 | +Z (forward) — correct |
| `walk_backpedal` | 1.2667 | (0.0000, -0.0000, 0.0000) | YES | -0.000 (none) | -0.000 / 12.219 (untouched) | 0.00000° | 0.000000 | -Z (back) — correct |
| `walk_strafe_left` | 1.1333 | (0.0000, -0.0000, -0.0000) | YES | 0.000 (none) | 0.000 / 15.298 (untouched) | 0.00000° | 0.000000 | -X — matches `strafe_left` |
| `walk_strafe_right` | 1.3000 | (-0.0000, 0.0000, -0.0000) | YES | 0.000 (none) | 0.000 / 21.530 (untouched) | 0.00000° | 0.000000 | +X — matches `strafe_right` |
| `turn_left` | 0.9333 | (-0.0000, -0.0000, -0.0006) | YES (0.0006 < 0.001) | **-99.319** -> `-X(left)`, matches name | **0.000 / 0.000** | 0.00001° | 0.000000 | n/a (turn) |
| `turn_right` | 0.9333 | (0.0006, 0.0000, -0.0001) | YES (0.0006 < 0.001) | **+99.318** -> `+X(right)`, matches name | **-0.000 / 0.000** | 0.00000° | 0.000000 | n/a (turn) |

Both turn clips start on the idle stance's own Hips yaw (-54.457°, measured on `idle` key 0) and the
library holds that yaw at every key. Turn clips' Hips peak planar excursion 0.2555 / 0.2979 (mid-clip,
net zero) — smoke-watch data, not a defect. No translation drift on any of the six: no re-download STOP.

### Mutation table (MEASURED)

Harness: target copied outside the repo + SHA256, mutation applied by exact byte replace, ONLY the
affected test file run, target restored by copy in the SAME Bash call, SHA256 re-confirmed. `git
checkout --` never used. 14 rows; every restore matched.

| # | AC | Mutation (target) | Test run | Result | Restore SHA match |
|---|---|---|---|---|---|
| M1 | 2 | `_move_speed = 5.0` literal instead of the live read (`test_hero_movement.gd`) | `test_hero_movement.gd` | RED (exit 1; printed `authored move_speed=5.000000 … velocity_from_state=false` against the actual 6.0 velocity) | YES `ba4dcd6b…` |
| M2 | 3 | `turn_left` loop flag `false` in `EXPECTED_LOOP` (`test_rig_clips.gd`) | `test_rig_clips.gd` | RED: `clip 'turn_left' loop=true, expected loop=false` | YES `fc18f263…` |
| M3 | 4 | walk-family swap disabled (`if false and …`) (`animation_controller.gd`) | `test_hero_clip_selection.gd` | RED: 21 FAILED lines — every walk-tempo cardinal (both facings), the tier-boundary walk cases and the walk-clip content selections got run-family names | YES `7b54d5ad…` |
| M4 | 5 | **hardcoded threshold** `gait_threshold` -> `return 4.0` (the shipped midpoint) | `test_hero_clip_selection.gd` | RED: `speed 5.000 under the other pair (midpoint 6.000) must play 'walk' … got 'run'` | YES |
| M4b | 5 | hardcoded threshold `return 6.0` (the other pair's midpoint) | `test_hero_clip_selection.gd` | RED: `speed 5.000 under the authored pair (midpoint 4.000) must play 'run' … got 'walk'` | YES |
| M4c | 4 | bare `walk_speed` threshold instead of the midpoint | `test_hero_clip_selection.gd` | RED: 20 FAILED lines — walk-tempo cardinals and tier-boundary walk cases flip to the run family | YES |
| M4d | 5 | hardcoded literal INLINED at the call site (`planar.length() < 4.0`), `gait_threshold` intact | `test_hero_clip_selection.gd` | RED: other-pair probe got 'run' | YES |
| M5 | 6(a) | turn sign mapping inverted | `test_hero_turn_in_place.gd` | RED: `turning toward local +X … expected 'turn_right', got 'turn_left'` (and the reverse) | YES |
| M6 | 6(b) | **facing memory advanced on IDLE ticks only** (`_track_facing` moved below the IDLE gate) | `test_hero_turn_in_place.gd` | RED: `post-action: back in IDLE … tick 0: expected idle, got 'turn_right' (a spurious turn off a stale previous facing)` | YES |
| M7 | 6 | hold guard removed (turn on the first qualifying tick) | `test_hero_turn_in_place.gd` | RED: ticks 1-2 got a turn clip, expected idle | YES |
| M8 | 6 | stand-still gate removed (turn while moving) | `test_hero_turn_in_place.gd` | RED: `turning while walking forward … expected walk, got 'turn_right'` | YES |
| M8b | 6 | minimum yaw change ignored (`absf(cross) > 0.0`) | `test_hero_turn_in_place.gd` | RED: sub-threshold turning selected `turn_right` | YES |
| M9 | 7 | `YAW_NEUTRALISED_CLIPS = []` in the library tool; tool re-run (library rebuilt) | `test_hero_turn_in_place.gd` | RED: `library Hips yaw still moves 99.3195 deg` (both clips) | YES tool `0bb4e906…`, library `712bd4cb…` |
| M9b | 7 | neutraliser writes `twist_0` (drops the swing); tool re-run | `test_hero_turn_in_place.gd` | RED: `library Hips SWING differs from the source by 10.66178 deg` (both clips) | YES tool + library |
| M10 | 8 | `_turn_playback_rate` -> `return 1.0` (fixed turn rate, no scaling — fix-pass 2026-09-16) | `test_hero_turn_in_place.gd` | RED: `rate proportionality: rotation-rate ratio 2.0000, playing-speed ratio 1.0000 (speeds 1.0000 / 1.0000 measured)` | YES `9666f80f…` |
| M11 | 6 | `TURN_MIN_FACING_CROSS` restored to the retired `0.0087` (~sin 0.5°, fix-pass 2026-09-16) | `test_hero_turn_in_place.gd` | RED: `slow sustained rotation (5.0 deg/s): tick 3..7 of turning (hold 3) expected 'turn_right', got 'idle'` | YES `9666f80f…` |

**Mutation-pass finding (fixed, disclosed):** the FIRST M4/M4b runs went RED for the WRONG reason —
`_tier_boundary` computed its expected midpoints with `AnimationController.gait_threshold`, the function
under test, so the mutation moved the oracle too and the test failed on its own "midpoints too close"
guard instead of on the probe. The test now computes the midpoint itself (`_midpoint`, the AC's formula);
M4/M4b re-run after the fix are the rows above, and M4d (inlined literal) was added. Not run: a mutation
of the Task 7 corpse re-derivation (not a new test), and a physical source-FBX swap against the turn
anchor (needs an editor re-import session; the anchor's own assertions are covered by
`_sign_mapping_against_known_rotation`'s source-yaw checks).

### Task 7 table — integration tests driving hero movement on the authored `.tres`

Enumerated by grep over `test/integration/*.gd` for `p1_move_*`/`p1_run` presses and `move_speed`/`walk_speed`
reads, then read. "Green" = measured PASS in `C:\dev\_6-7b-suite-after-int.txt` (R1 applied).

| File | Drives the hero? What does it assert? | In/out | Verdict |
|---|---|---|---|
| `test_hero_movement.gd` | run-held move; asserts `|velocity| == move_speed` (literal 5.0) | IN | **FIXED** (AC 2): live read off the applied config; green |
| `test_unit_corpse_walkthrough_live.gd` | run-held drive of `DRIVE_FRAMES := 40` sized in a comment to "the authored 5.0" | IN | **FIXED** (re-derived frame count): `DRIVE_TRAVEL := 3.3` + `_drive_frames()` from live `move_speed` (40 at 5.0, 33 at 6.0); no margin widened. Measured: blocked dx -0.742 (unchanged), passed-corpse dx 1.000 (HEAD's file under R1: 1.800); green |
| `test_unit_approach_live.gd` | walks the hero; window sized from `walk_speed` read live (`6-7/R11`) | IN | measured green, no edit |
| `test_contact_pipeline.gd` | move press to turn facing; reach set by teleport; parametric kill schedule | IN | measured green, no edit |
| `test_camera_relative.gd` | move_up both slots; asserts direction sign, `x > 0.1`, `|z| < 0.05` — no tempo literal | IN | measured green, no edit |
| `test_root_rotation_isolation.gd` | move_up; asserts `x > 0.1`, `|z| < 0.05` | IN | measured green, no edit |
| `test_step_pause.gd` | move_up; per-tick displacement MEASURED in-test, never a speed literal | IN | measured green, no edit |
| `test_roll_displacement.gd` | move press before a roll; asserts roll distance/speed (roll fields, not `move_speed`) | IN | measured green, no edit |
| `test_visible_facing.gd` | move presses; asserts facing follows | IN | measured green, no edit |
| `test_lock_on_live.gd` | move_right; asserts rig still framing | IN | measured green, no edit |
| `test_lock_marker_live.gd` | move_right; asserts marker on target. A COMMENT reads "~3 m from where the first check was made" (not asserted) | IN | measured green, no edit (stale comment noted, not a pin) |
| `test_hud_viewports.gd` | move_up to give a roll a direction; asserts HUD payload routing | OUT (no position/reach/timing assertion) | measured green |
| `test_debug_instruments.gd` | move_up + roll; asserts inspector labels | OUT (same) | measured green |
| `test_record_save_control.gd` | move_up + roll; pins stamina `38/50` (roll cost, not tempo) and tick counts | OUT (no movement-tempo dependency) | measured green |
| `test_hero_clip_selection.gd`, `test_hero_turn_in_place.gd` | drive `HeroActor.drive()` directly, no runner; authored pair read live | OUT (no runner) | green |
| `test_replay_entry_is_inert.gd`, `test_replay_verifier_tool.gd` | in-test `BalanceConfig` literals (`7.0`/`11.0`) | OUT (not authored) | green |
| `test_two_units_converge_live.gd`, `test_unit_swing_root_live.gd`, `test_projectile_flight_live.gd` | minion/totem KIND speeds (untouched minion `3.0`, totem `0.0`) | OUT (not hero tempo) | green |

### Completion Notes List

1. **Task 1 (AC 1).** `data/balance/balance_config.tres` HERO block only: `move_speed 5.0 -> 6.0`,
   `walk_speed 2.5 -> 2.0` (git diff: exactly those two lines; minion `3.0` and the `0.0` entries
   untouched). Golden measured unmoved both directions (Debug Log). AC 1 names no test; the golden pin
   is `test/state/test_determinism.gd::test_state_matches_golden` (green before and after).
2. **Task 2 (AC 2).** `test/integration/test_hero_movement.gd::_physics_process` reads
   `Main._match_state.balance.move_speed` at frame 5 (the `test_unit_approach_live.gd:150` precedent),
   refusing loudly on a missing/zero value; `const MOVE_SPEED := 5.0` deleted. Measured PASS at 6.0
   (`authored move_speed=6.000000`); mutation M1.
3. **Task 3 (AC 3, AC 7).** `tools/add_paladin_locomotion.gd` extended on its own pattern: the twelve
   library clips are `EXISTING_CLIPS`, the six are `NEW_CLIPS` (all loop `true`), library 12 -> 18. Yaw
   neutralisation `_neutralise_hips_yaw` for `turn_left`/`turn_right` only: swing-twist about +Y, every
   key rewritten `twist_0 * swing` — swing quaternion kept as-is, position track never read or written,
   source FBX untouched; a clip with no Hips rotation track makes the tool refuse to save (the AC 7 STOP
   path). Measured pre/post in the per-clip table (yaw ±99.32° -> 0.000; swing diff <= 0.00001°;
   position diff 0). `tools/measure_hips_displacement.gd` gained the rotation table (Fact M8) with a
   source-vs-library comparison (swing angle via 2·asin, because `angle_to` reads ~0.05–0.09° of float32
   noise on identical data — measured). Tests: `test/integration/test_rig_clips.gd::_initialize`
   (`EXPECTED_LOOP` eighteen entries, count derived; M2) and
   `test/integration/test_hero_turn_in_place.gd::_turn_clips_carry_no_yaw` (net/peak yaw <= 0.01°, swing
   <= 0.001°, position <= 1e-5 vs source; M9, M9b).
   **R4 source-file swap (operator ruling in-session).** Headless measurement: the controller's local +X,
   which its strafe split names "right", is the rig's `mixamorig_LeftHand` side (rest x +0.657, RightHand
   -0.656, toes at +Z) — anatomically the hero's LEFT. The shipped run strafes follow the controller's
   convention (`strafe_right` travels +X, measured); the downloaded `walk_strafe_left` travelled +X and
   `turn_left` turned +99° toward +X (anatomical naming). Operator chose "Option 1: controller
   convention": `walk_strafe_left.fbx <-> walk_strafe_right.fbx` and `turn_left.fbx <-> turn_right.fbx`
   swapped via a temp name (SHA256 before/after recorded in chat), sidecars untouched, re-imported
   (editor session 2), library rebuilt, all four re-measured — table above is post-swap only.
   `walk`/`walk_backpedal` measured correct (+Z / -Z), no swap.
   **NAMING FINDING (recorded, NOT renamed, per operator):** 5-0a's L/R strafe swap (`5-0a/R1`, recorded
   as "a Mixamo-preview mirror misread") was most likely this anatomical inversion of the controller's
   local +X naming, not a preview mirror: the Mixamo files are named anatomically correctly, and the
   controller calls anatomical left "right". No rename in this story.
4. **Task 4 (AC 4, AC 5).** HOW chosen: a WIDENED PUSH. `MatchRunner` step 4 reads
   `_match_state.balance.walk_speed/move_speed` inline (CONSTRAINT C; the replay/reload-aware handle,
   `4-3/R11` precedent) and passes two plain floats through `HeroActor.drive(hero_state, delta,
   walk_speed, run_speed)` to `AnimationController.on_locomotion(velocity, facing, walk_speed,
   run_speed)`. Reason: a presentation-local `BalanceConfigService` read would diverge from the
   record's config during replay. No `src/state/` change, no new seam, no config reference held.
   `static func gait_threshold(walk, run) = (walk + run) * 0.5`; `_locomotion_clip` runs the unchanged
   dot-product split, then swaps to the walk family (`_WALK_FAMILY`) below the midpoint (`<` walk,
   `>=` run). Tests: `test/integration/test_hero_clip_selection.gd::_walk_cardinals` (four cardinals + rest,
   two facings, authored walk tempo read live; M3, M4c) and `::_tier_boundary` (authored 2.0/6.0 and
   other 3.0/9.0 pairs, each pair's tempos x four directions, probe 5.0 between midpoints 4.0/6.0; M4,
   M4b, M4d). Existing five-case table `::_cardinals` (two facings), `::_the_motivating_defect`,
   `::_idle_gating` stay green, now at the authored run tempo read live instead of the old `SPEED := 5.0`
   literal; `::_clip_content_changes` extended to the four walk clips.
   Signature fallout (fixture pair 2.0/6.0, no behaviour change): `test/integration/test_chain_retrigger.gd`
   (its 5.0 forward push still selects `run`) and `test/integration/test_hitbox_follows_bone.gd`
   (zero velocity).
5. **Task 5 (AC 6).** `_track_facing` (cross term `prev.x*cur.y - prev.y*cur.x`, no angle/atan2) runs
   BEFORE the IDLE gate on every push; returns the held sign after `TURN_MIN_HOLD_TICKS` same-signed
   ticks at `|cross| >= TURN_MIN_FACING_CROSS`. Turn selection only when IDLE AND planar speed <=
   `RUN_SPEED_EPS`; negative cross (toward local +X, "right") -> `turn_right`. Knobs, untuned:
   `TURN_MIN_FACING_CROSS := 0.0087` (~sin 0.5°/tick, ~30°/s at 60 Hz), `TURN_MIN_HOLD_TICKS := 3`.
   Tests in `test/integration/test_hero_turn_in_place.gd`: `::_sign_mapping_against_known_rotation` (both
   directions under two starting facings; ticks < hold read idle; anchored to each clip's SOURCE Hips yaw
   sign; M5, M7), `::_no_turn_cases` (unchanged facing; sub-threshold turning; turning while walking ->
   `walk`; M8, M8b), `::_no_spurious_turn_after_action` (mid-turn -> ROLLING with further facing change
   -> facing held -> IDLE: no turn; M6), `::_turn_clip_content` (Hips pose animates).
6. **Task 6 (AC 8).** `RUN_FAMILY_NATIVE_SPEED := 5.0` (story-stated), `WALK_FAMILY_NATIVE_SPEED := 1.82`
   — **MEASURED from the clip** as a starting value: planted-toe slide speed `walk` 1.4097 vs `run` 3.8648
   on the same method, calibrated to run's 5.0 (5.0 x 1.4097 / 3.8648 = 1.824). At 2.0 walk plays 1.10x;
   run at 6.0 plays 1.20x. `TURN_CLIP_SPEED := 1.0`. Rate goes through `play(clip, blend, speed)` only;
   `AnimationPlayer.speed_scale` is never written (grep: comments only). Measured on Godot 4.6.3:
   re-issuing `play()` on the playing clip with a new speed updates the rate without moving the
   playhead (0.2 -> advance 0.1 at 2x -> 0.4), so `_play` re-issues on a rate change > 0.01. `idle`,
   and every evented `_restart` clip, unchanged. Not test-pinned by design (AC 8). Per-clip slide speeds
   for the smoke (raw probe units, run-calibrated in brackets): backpedal 4.06 [5.26], strafe_left 3.17
   [4.11], strafe_right 3.24 [4.19], walk_backpedal 1.06 [1.37], walk_strafe_left 1.15 [1.48],
   walk_strafe_right 1.02 [1.31] — strafes/backpedals are natively slower than their family's forward
   clip, so they may slide slightly at the family rate (family-level constant per AC 8).
7. **Task 7.** Table above. Two files FIXED (hero_movement: live read; corpse_walkthrough: re-derived
   frame count), no tolerance widened; every other in-scope file measured green under R1.
8. **Task 8 (AC 10).** Suites before/after, golden both directions, `src/state/` diff empty,
   FORMAT_VERSION 11, timestamps — Debug Log.
9. **Task 9 (AC 9) NOT ticked** — the live smoke is the operator's, after review.
10. **Deviations from the gds-dev-story skill.** (a) Tests were written alongside/after the
    implementation, not RED-first; non-vacuity is shown by the mutation table instead. (b) Step 9's
    "all tasks [x]" gate is not met because Task 9 stays open by operator instruction; Status set to
    `review` regardless, as instructed. (c) `python3` unavailable; resolver run under
    `C:\Python312\python`. (d) The skill's Step 4 wrote the board to `in-progress` (a value outside
    the CFG/R2 lifecycle set), which on_complete does not mention; it is overwritten by Step 9's
    `review` and then reverted to `ready-for-dev` by on_complete, so the board ends unchanged.
11. **Smoke-watch notes.** A one-tick facing SNAP (instant re-lock to a target on the other side) never
    reaches the 3-tick hold, so it plays NO turn clip by construction — smoke item 4 should use a
    circling target, not a re-lock, to see a turn. Turn clips play at 1.0 with their Hips planar
    excursion 0.26–0.30 mid-clip. Walk native 1.82 is the first knob to judge (item 1). Walking block
    slides (Non-Goal). Strafe/backpedal clips are natively slower than their family's forward clip.
12. **Fix pass (2026-09-16, operator live smoke item 4, AC 6/AC 8).** `TURN_MIN_FACING_CROSS` lowered
    from `0.0087` (~30 deg/s) to `0.00029089` (~1 deg/s) — a true noise floor, not a de-facto minimum
    rotation rate; `TURN_MIN_HOLD_TICKS` unchanged. `TURN_CLIP_SPEED` retired; the two turn clips now
    play at `rotation_rate / TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC` (measured `106.4165` deg/s off
    `tools/measure_hips_displacement.gd`'s existing rotation table, both clips agreeing to 0.001
    deg/s), clamped to new knobs `TURN_MIN_PLAYBACK_RATE := 0.25` / `TURN_MAX_PLAYBACK_RATE := 2.0`.
    `rotation_rate` comes from `_track_facing`'s existing per-tick cross term (new `_last_cross`
    member, small-angle approximation, no second `atan2`, `DECISION A` intact). Re-issuing `play()`
    on a rate change re-uses the family clips' own idempotent `_play`/`_PLAYBACK_SPEED_EPS` path
    unchanged — a rate update does not restart the clip (measured, this pass). Tests added to
    `test_hero_turn_in_place.gd`: `_slow_sustained_rotation_selects_turn` (5 deg/s, a behavioural
    requirement, selects a turn after the hold) and `_rate_proportional_to_rotation_rate` (two
    in-clamp-range rotation rates' playing-speed ratio matches their rate ratio, tolerance 0.01).
    Mutations M10 (fixed rate) and M11 (floor reverted) both RED — mutation table above. Operator
    smoke-tuned tempo/blend values (`move_speed 5.5`, `walk_speed 2.2`, `LOCOMOTION_BLEND_SECONDS
    0.25`) required no further code change beyond what the dev pass already made live-read
    (`gait_threshold`, `_drive_frames()`); re-checked green under the new values (Debug Log). No
    `src/state/` change; golden unmoved; full suite green (854 state / 62 integration).

### File List

- `data/balance/balance_config.tres` (modified — R1, two values)
- `src/actors/hero/animation_controller.gd` (modified)
- `src/actors/hero/hero.gd` (modified — `drive()` widened push)
- `src/main/match_runner.gd` (modified — step 4 passes the authored pair)
- `tools/add_paladin_locomotion.gd` (modified)
- `tools/measure_hips_displacement.gd` (modified — rotation/yaw table)
- `assets/characters/paladin/paladin_anims.res` (modified — 12 -> 18 clips)
- `assets/characters/paladin/walk.fbx` + `.fbx.import` (new — FBX operator-supplied, sidecar generated)
- `assets/characters/paladin/walk_backpedal.fbx` + `.fbx.import` (new)
- `assets/characters/paladin/walk_strafe_left.fbx` + `.fbx.import` (new — content swapped, R4)
- `assets/characters/paladin/walk_strafe_right.fbx` + `.fbx.import` (new — content swapped, R4)
- `assets/characters/paladin/turn_left.fbx` + `.fbx.import` (new — content swapped, R4)
- `assets/characters/paladin/turn_right.fbx` + `.fbx.import` (new — content swapped, R4)
- `test/integration/test_hero_turn_in_place.gd` + `.gd.uid` (new)
- `test/integration/test_hero_clip_selection.gd` (modified)
- `test/integration/test_hero_movement.gd` (modified)
- `test/integration/test_rig_clips.gd` (modified)
- `test/integration/test_unit_corpse_walkthrough_live.gd` (modified)
- `test/integration/test_chain_retrigger.gd` (modified — signature)
- `test/integration/test_hitbox_follows_bone.gd` (modified — signature)
- `docs/implementation-artifacts/sprint-status.yaml` (skill lifecycle writes; ends at `ready-for-dev` + story note via on_complete)
- `docs/implementation-artifacts/6-7b-locomotion-presentation.md` (this record)

Fix pass (2026-09-16) additions (no new files):
- `src/actors/hero/animation_controller.gd` (modified again — turn playback rate fix)
- `test/integration/test_hero_turn_in_place.gd` (modified again — two new tests)

#### Chain (C1) (2026-09-16, Sonnet 5, close-out chain)

- `::_rate_proportional_to_rotation_rate` rewritten: the two rotation rates are now DERIVED from
  `TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC` and the two clamp knobs at 25%/75% of the clamp span
  (`101.1`/`175.6` deg/s under the shipped `0.6`/`2.0` clamp) instead of the fixed `40.0`/`80.0`
  literals, which had fallen below the retuned `0.6` clamp floor (`0.6 x 106.4165 = 63.85`). Still
  asserts only the playing-speed ratio against the rotation-rate ratio, never a knob value. Comment
  above `TURN_NATIVE_ROTATION_RATE_DEG_PER_SEC`/`TURN_MIN_FACING_CROSS` corrected to state the final
  values (floor `0.00087`, ~3 deg/s; `TURN_MIN_PLAYBACK_RATE` `0.6`, operator re-smoke).
- M10 re-proof (`_turn_playback_rate -> return 1.0`) on the rewritten test: RED —
  `rate proportionality: rotation-rate ratio 1.7368, playing-speed ratio 1.0000 (speeds 1.0000 /
  1.0000 measured)`. Target backed up + SHA256 outside the repo before mutation, restored by copy,
  SHA re-confirmed after.
- Suite outputs (outside the repo; counts read by opening the files), single full run:

  | Run | File | START (file ctime) | END (file mtime) | Result |
  |---|---|---|---|---|
  | state | `C:\dev\_6-7b-chain-suite-state.txt` | 2026-09-16 20:02:11 | 20:02:22 | 854 tests, 0 failed, 6965 assertions — RESULT PASS |
  | integration | `C:\dev\_6-7b-chain-suite-int.txt` | 20:02:26 | 20:06:32 | 62 files, 62 PASS — INTEGRATION ALL PASS |

  State and integration run as separate foreground calls, 600000 ms timeout each; nothing
  backgrounded while waiting.
