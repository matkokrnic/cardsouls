---
baseline_commit: b91152e716978caba9351564ce952d4144d42799
---

# Story 7.10: Unblockable presentation

Status: done

Tier **B** (HUD/presentation only). Authored 2026-10-08 against HEAD == origin/main == `b91152e`, tree clean. Scope is the
operator's brief of 8.10.2026 (`7-8/R20` routes the eye-blink telegraph and the counter polish here; `6-6b` deferred
"GREEN pop out of the air", "dagger hit" and the "pause on the head before the rebound" close here). Tier B stands only
while the golden and the snapshot key set stay unmoved: see Golden Prediction and Open Question 1. Numbers marked TEMP are
placeholders the operator tunes at smoke. No R-labels here; they are assigned at close-out.

## Story

As the defender of an unblockable, I want to see the attacker's eyes light, blink faster and flash, so that I can time a
counter by reading the attacker, as in Sekiro. As either player, I want a RED counter to land visibly on the head with weight
and a GREEN counter to visibly hit with a dagger, and I want the post-knockdown immunity to be visible, so that every
outcome of an unblockable is legible on both screens.

## Acceptance Criteria

Behaviour only; mechanism is in Dev Notes and Open Questions. `[M]` machine-checkable, `[S]` live smoke. Every new number is
a named knob; tests pin bounds and directions only.

**S1 Attacker's eyes**

1. **[S]** The attacker's head shows two emissive points at the visor in the unblockable's colour. They are off whenever no
   unblockable is active for that hero (rest, melee, spells, defence).
2. **[M]** Eyes light on the click tick, blink faster across the whole chargeup as a pure function of chargeup progress
   (progress 0 slowest, 1 fastest; the interval shrinks monotonically). Retuning `unblockable_chargeup_seconds` re-fits it with
   no edit. Pinned as a static function on bounds and monotonicity.
3. **[M]** On the launch tick (the commit) one strong flash, then steady lit through the flight. Eyes go off on the first
   touch (counted or dropped), cancel, knockdown, bolt stun, death, round end, debug reset.
4. **[M]** Alignment with 7-9 is recorded in Measured Facts M3 and pinned: the flash tick equals the commit tick the counter
   window is anchored to (`_is_commit_tick`), the window opens `counter_lead_seconds` (0.25 s) before it, and the eyes-off edge
   equals the end of the judged span (first touch). Where the lit span and the span in which a defence is merely accepted
   differ, the difference is stated (M3) and not hidden.
5. **[S]** Placeholder audio: a short tick on each blink and a sharp sting on the flash, from assets already in the repo or
   `C:\dev\_sonniss\part1`. File choices are listed in Dev Notes so the operator can swap them by hand.
6. **[S]** The ChargeMarker orb, the per-colour charge clip and the existing stings are untouched. Whether the orb is now
   redundant is judged at smoke and recorded; it is not removed here.
   *(Close-out note: the smoke call is moot. The operator reports the ChargeMarker orb has not been visible in play for some
   time. Cause: `7-6/P21` moved every telegraph shape into the F3 debug layer. `ChargeMarker` is a child of
   `TelegraphController/Shapes` (`src/actors/hero/hero.tscn:203`), and `TelegraphController.set_cues_shown(false)` hides the
   whole node (`src/actors/hero/telegraph_controller.gd:104-106`, `visible = shown`), which the runner applies to both heroes
   (`src/main/match_runner.gd:844`) with the layer hidden by default. The dispatch still sets `charge_shape.visible = true`
   (`telegraph_controller.gd:218`), but under a hidden parent it never draws. It shows only with F3. Nothing in 7-10 changed
   it.)*
7. **[S]** Readable from the opponent's camera at a typical fight distance (4 to 6 m). Eye size, brightness, blink interval
   range and flash length are named knobs.

**S2 RED counter**

8. **[M]** Playback rate of the RED sequence is well below today's 2.733x native (M4). Target at most 1.6x (TEMP); the dev
   measures what the cuts allow and states the achieved rate. `counter_busy_seconds_red` stays 1.0 s. If no cut table reaches
   the target without breaking the join with the state travel, that is Open Question 2 and is reported, not worked around.
9. **[S]** The defender visibly lands feet-first on the attacker's head at near and far range, then backflips off. The feet
   reach head height at contact (a presentation arc; the clip alone lifts the hips about 0.64 m, M4).
10. **[S]** On head contact: presentation-only hitstop on both rigs (about 0.1 s, knob), a bright flash and impact burst at
    the head, a heavy placeholder thud, a small camera shake on both cameras. Game logic never pauses; the tick count and the
    snapshot during the hitstop are the same as without it.
11. **[S]** The attacker enters the knockdown from the kick with a short blend and never before the kick lands.

**S3 GREEN counter**

12. **[S]** The dagger is clearly visible: trail, size knob, fast flight. It arrives within a bounded time of the counter.
13. **[S]** On impact: spark burst, presentation-only hitstop on the attacker (knob), placeholder thud.
14. **[M, live]** The attacker's falling starts at the dagger's impact and never before; the hold of the attacker's pose is
    bounded by a knob (default at least the longest gap in M4, so it never releases early). It enters the knockdown with a
    blend, not a pop. Closes `6-6b`'s "GREEN pop out of the air" and "dagger hit".

**S4 Immunity marker**

15. **[M]** While the hero's 7-9 `unblockable_immunity` window runs, a subtle silver shimmer/outline shows on that hero, never
    in an unblockable colour (pinned against the three charge colours), fading with the remaining fraction, gone on expiry,
    death and reset. Visible on both players' screens.

**Cross-cutting**

16. **[M]** Golden, `FORMAT_VERSION` 21 and the snapshot key sets are byte-unmoved (Golden Prediction); `test/state/` and
    `src/state/` are not edited; the F1 / D3(a) / D3(b) invariants hold; no new `connect_*` (the family stays at ten).
17. **[M]** Presentation state (hold timers, shake, hitstop, eye blink, landing arc, travel factor) is never read by anything in `src/state/` and never reaches `to_snapshot()`; it reaches the recorder only indirectly, as the geometry of a contact fact gathered from bone-tracked shapes during a LANDED counter's arc, hitstop or victim hold, which the recorder captures as gathered, so a replay of a recorded match feeds the same contacts and produces the same presentation inputs. *(Amended at close-out per review T3; the original sentence said "never reaches ... the recorder".)*
18. **[M]** New nodes have no `_physics_process` (F1), no collision shape, no signal into state. Hitstop and shake are
    advanced from the runner's single tick loop.
19. **[S]** Live Smoke below passes.

## Measured Facts

Verified by reading HEAD `b91152e` this session (path:line, then what it says). The repo wins over the brief.

- **M1 Counter fire tick and travel.** The press arms the busy window at `match_state.gd:6129` and locks the travel bearing
  from the pushed hero-to-hero fact at `:6146`. The attacker's judgement is the first branch of its CHARGING arm
  (`:1825`, `_resolve_color_counter` `:6882`); it reads the defender's step-3 capture, so a counter FIRES on
  `max(commit tick, press tick + 1)` and never after the first touch (`:6912`). A press up to 15 ticks (0.25 s) before the
  commit fires ON the commit tick; a press during the flight fires one tick after the press. The attacker is hard-rooted for the
  whole chargeup (`:7357`) and the launch moves it only after the commit, so for a pre-commit press it stands where it clicked; for
  a flight press it stops where the flight had got to and falls there (STUNNED is hard-rooted, `:7380`).
  **Travel is a FIXED distance, not distance-aware:** `counter_travel_distance_for` (`balance_config.gd:671`) is RED 4.0,
  BLUE 6.0 (`balance_config.tres:159-160`); the branch at `match_state.gd:7476-7490` divides it by the leg length and uses the
  bearing locked at the press. RED goes out for `round(0.305 * 59) = 18` of the 59 moving ticks (0.30 s), then back the same
  4.0 (net zero, ends where it pressed). Consequence, by arithmetic (the engine was not run): the jump lands on the head only
  when the gap at the press is 4.0 m. A flight press at 1.5 m overshoots by 2.5 m (passes through, `hero.gd` pass-through
  exception); a pre-commit press at 8 m stops 4 m short. BLUE's slide is solid and stops at the collider, so it overshoots
  never and falls short beyond 6 m. The state cannot do better: no distance crosses the seam (`match_runner.gd:1186` comment,
  `4-3/R2`). **TIER-A FLAG: no, conditional on Open Question 1.**
- **M2 Head and glow.** The rig's head joints are `mixamorig_Head` and `mixamorig_HeadTop_End` (same `mixamorig_` spelling
  as `SWORD_BONE`, `hero.gd:46`; `tools/measure_torso_envelope.gd:28` already lists both), and the FBX carries a `Helmet`
  mesh. The visor-level offset from the head joint and whether the helmet's geometry occludes a point at it were NOT measured:
  that needs the engine and a new measuring tool, which this authoring pass forbids (no engine, no new file). It is the
  dev's first task (Task 1). **There is no glow:** no `WorldEnvironment` or `Environment` exists in `main.tscn` or any
  `.tscn/.tres`, and `project.godot` sets none, so emissive material will NOT bloom. Both cameras live in SubViewports
  (`main.tscn:101,113`). Brightness has to come from an unshaded additive quad or an OmniLight, or from a per-camera
  `Environment` (that is a scene change, see Open Question 3).
- **M3 How presentation learns each moment, and the 7-9 alignment.** No seam is needed: `match_runner._push_charge_progress`
  (`:1247`, called at `:4095`) already polls every CHARGING hero each tick after `advance()` and has the colour
  (`player.charge_color`), the progress (landing window remaining, remapped at commit), chargeup running
  (`charge_window.is_running`, false from the commit tick on), first contact (`player.charge_contact != NONE`, the hit-once
  memory), and cancel (`action_state != CHARGING`, which the poll already treats as "push nothing"). Colour reaches the
  controllers also via `on_action_state_changed(..., charge_color)` (`on_action_state_changed`, `animation_controller.gd`, 5-3). The
  `connect_*` family is **ten** (`match_runner.gd:2058-2960`, counted by `func connect_`). Alignment with 7-9: eyes lit
  click..first touch; the legal-to-defend span is the same left edge (the click tick excluded for both seats) and extends
  PAST a dropped touch (R5 keeps it open on `TOUCHED`), while the judged/successful span starts 0.25 s BEFORE the flash
  (`counter_lead_seconds_*`, `balance_config.tres:152-154`) and ends at the first touch like the eyes. So the lit span is
  longer than the success window by exactly the first 0.75 s of the chargeup, equal at its right edge, and one dropped-touch
  flight longer than the legal span's end is not covered (eyes already off).
- **M4 Counter presentation today.** `_COUNTER_PRESENTATION` (`animation_controller.gd:382`): RED `counter_jump` 0..0.8333 +
  `counter_backflip` 0..1.9000 = 2.7333 s of clip over a 1.0 s span, rate 2.733 (`counter_clip_speed` `:410`); GREEN
  `counter_throw` 0.6646..1.3444 = 0.6798 s over 0.5 s, rate 1.36; BLUE 1.4134 s over 0.8 s. RED head contact = forward-leg end =
  elapsed tick 18 (0.30 s), which at 2.733 is 0.82 s of clip, i.e. the end of the jump cut. The clip alone lifts the Hips from
  0.892 to 1.531 (apex at 0.406 s), 0.64 m, not head height (about 1.8 m). The dagger (`dagger_actor.gd`) is `MODEL_SCALE` 2.5,
  launched at the PRESS (release fraction 0, `animation_controller.gd:403`) from the defender to the attacker's position AT THE
  PRESS at height 1.2 (`match_runner.gd:193`), crossing in the whole busy span (0.5 s = 30 ticks), no trail. **Tick gap:** the
  attacker is STUNNED from the fire tick (press+k, k = 1..15, or press+1) and the dagger arrives at press+30, so the attacker
  falls 29 ticks (0.48 s) early after a flight press and 15 ticks (0.25 s) early after a pre-commit press at the edge of the
  lead. RED: the kick lands at press+19 while the attacker fell at press+k, a 4 to 18 tick lead.
- **M5 Immunity.** `HeroState.unblockable_immunity` (`hero_state.gd:163`), a `TimingWindow` armed at step 2 when
  `get_up_iframe` closes (`match_state.gd:6956`), 1.5 s (`balance_config.tres:132`), read at `:6220`. HASHED
  (`hero_state.gd:619`). It is a separate window from `get_up_iframe` (`:147`, 2.0333 s); the two run back to back. Presentation
  reads `player.hero.unblockable_immunity.is_running` and `remaining_ticks()` / `duration_ticks()` directly in the runner poll,
  the `_push_counter_presentation` precedent, no seam.
- **M6 Two-rig hitstop in presentation.** Feasible without touching state: `HeroActor.drive` (`hero.gd:117`) copies
  `hero_state.velocity` into `move_and_slide()` each tick, so the root keeps moving; the rig is the child `Mesh`. Hold the
  `AnimationPlayer` (speed 0, the 6-1b pinned-playhead technique) and offset `Mesh` by minus the root's displacement since the
  hitstop began, then ease the offset to zero (the catch-up). The bone-tracked hit shapes (`_track_weapon_bone`,
  `_track_trunk_bone`) read the skeleton transform, so they follow the held mesh for 6 ticks; accepted and noted for smoke.
  **No camera-shake API exists** (grep `shake` over `src/` is empty). `camera_rig.gd` owns pose; the rig is a child of the hero
  root (DECISION A), so a shake is a presentation offset on the camera node itself, never on the root.
- **M7 Reusable 7-1 pieces.** `EffectFx` (`effect_fx.gd`): `burst`, `particles` (world-space trail via `local=false`,
  `shrink_over_life` makes it read as a trail, `:105`), `quad`, `light`, `free_after`, `bone_follower` (`:120`, a
  `BoneAttachment3D` on a named bone), eleven Kenney textures (`spark_02`, `star_06`, `circle_05`, `trace_04`, `smoke_04`
  suit sparks/trail/flash). Sounds in the repo: `assets/audio/cue_hit.wav`, `cue_reject.wav`, `sting_attack.wav`,
  `effects/sfx_rock_hit.wav`, `sfx_boom.wav`, `sfx_counter.wav`, `sfx_fire_hit.wav` (listen and pick; thud candidates
  `sfx_rock_hit`/`sfx_boom`, tick candidate `sting_attack` trimmed or `cue_reject`, sting `sfx_counter`).

## Tasks / Subtasks

- [x] **Task 1 (AC 1, 4, 7; M2)** Measure the head: attach point and visor offset on `mixamorig_Head`, helmet occlusion, in a
  throwaway-free way (extend the `tools/measure_torso_envelope.gd` precedent as a committed tool/test). Decide the glow route
  (quad/OmniLight vs `Environment`, Open Question 3). Record the numbers in the dev record.
- [x] **Task 2 (AC 1-7)** Eyes: a presentation node on the head bone, a pure static `eyes_blink_interval(progress)` and a
  flash/lit/off driver fed from `_push_charge_progress`'s existing inputs; tick and sting audio; named knobs in one place.
  - [x] Clear on every exit listed in AC 3 (the reset and round-end paths included).
  - [x] Test: monotonic interval, flash tick == commit tick, off on first touch / cancel (against a stubbed state).
- [x] **Task 3 (AC 8, 9; OQ 1, 2)** RED: re-cut the table, mesh arc to head height, per-colour rate pinned by direction only.
- [x] **Task 4 (AC 10, 11, 13, 14)** One shared "contact moment" presentation: hitstop on a rig (hold + offset + catch-up),
  camera shake on a camera node, hold-then-blend of the victim's pose to the impact tick, impact burst/flash/thud. RED's
  impact tick is the forward-leg end, GREEN's is the dagger's arrival.
- [x] **Task 5 (AC 12, 14)** GREEN: dagger trail and size knob; launch/arrival timed so impact lands within the hold bound.
- [x] **Task 6 (AC 15)** Immunity shimmer on the hero, silver, fade by remaining fraction, both viewports.
- [x] **Task 7 (AC 16-18)** Before/after: golden, snapshot key sets (46 player, 21 hero, 6 top-level), `FORMAT_VERSION` 21,
  `src/state/` diff empty. Suite and integration run once at the end; Live Smoke ritual.

## Dev Notes

- **Read first:** `animation_controller.gd` 330-430 and 880-1010 (cut table, rate, resume), `match_runner.gd` 1247-1400 (the
  two polls and the dagger), `hero.gd` (pass-through, drive, bone tracking), `effect_fx.gd`, `dagger_actor.gd`,
  `telegraph_controller.gd` (ChargeMarker, per-event re-tint). Do NOT read `match_state.gd` beyond M1/M5 lines; it is not edited.
- **Where things live:** new presentation nodes under the hero scene or built in code like `EffectFx` (no `.tscn` is required;
  `dagger_actor.gd` is the precedent). Hold/hitstop/shake state is runner-local like `_counter_armed` (`match_runner.gd:184`).
- **Colour:** read `charge_color` and map through the existing `TelegraphProfile` colours (`telegraph_controller.gd`); no fourth
  vocabulary. The silver of S4 must differ from all three (test).
- **Blink function:** progress in, interval out; chargeup length never appears. Progress is the remapped value the
  charge poll computes before commit; the flash is keyed to `charge_window.is_running` going false, not to a time.
- **Victim hold:** the victim's STUNNED clip start is deferred by presentation; the state has long since written STUNNED, so
  the hero is hard-rooted and cannot act. The hold ends at impact or at the knob, whichever is first, and the knockdown clip
  then blends in (`_play`, not `_restart`; compare the BLOCKING->IDLE blend at `animation_controller.gd` 6-6a AC 13).
- **Hitstop seam:** the offset trick in M6 must reset on every end path (reset, death, round end) like `_free_counter_dagger`.
- **Previous-story intelligence (7-9):** the counter window is anchored at the commit; the 7-9 numbers are TEMP and 7-7 owns
  them; a change that adds a seat or makes an action refusable moves the golden (`SC/R6`), which presentation never does.
- **Git intelligence:** last five commits are 7-9 close-out docs/board; presentation precedents are 7-1 (effects) and 7-6.
- **Project rules that bite:** F1 (one `_physics_process`, in `match_runner.gd`), D3(a) `Input.*` only in controllers, D3(b)/A2
  no global RNG/`Time`/`OS`/`Engine` in `src/state/` (cosmetic randomness in presentation uses a local `RandomNumberGenerator`
  like 7-1's lightning stream); CONSTRAINT C (read config inline, never cache); no per-frame dictionary allocations in hot loops;
  docs and code never share a commit; golden/snapshot unmoved is what makes this Tier B.

## Golden Prediction

Golden `9d5d4fad...` (`test_determinism.gd:1336`), `RecordFile.FORMAT_VERSION` 21 (`record_file.gd:369`), snapshot key sets
(counted on HEAD from their pins): 46 player keys (`test_draw_delay_and_reshuffle.gd:62`), 21 hero keys
(`test_debug_window_countdown.gd`), 6 top-level. **All predicted UNMOVED.** Everything in this story is presentation: it reads
existing public facts (`charge_window`, `landing_window`, `charge_contact`, `defense_window`, `unblockable_immunity`,
`action_state`) after `advance()` and writes nothing to `src/state/`. The proof is a before/after of the three numbers above
plus an empty `git diff -- src/state`. **What would move it:** only Open Question 1 option (b), a pushed distance fact for the
counter travel (a new recorder channel, `FORMAT_VERSION` 22, the story becomes Tier A with the full ritual). Tier stays B in
the board; if the operator picks (b), re-tier explicitly (raise only, never lower).

## Open Questions

1. **Distance-aware RED/BLUE landing (M1).** (a) **Presentation rescale (recommended):** `HeroActor` scales the state's
   out-and-back velocity so the forward leg ends at the attacker's real position (head contact), the back leg the same
   factor; state keeps supplying timing and bearing. No state change, golden unmoved. Cost: the actor's displacement stops
   equalling the authored 4.0/6.0, so the defender can end farther or nearer than today, and a too-early press (counter not
   judged) would also jump at the attacker; that is a "what the game is" change and the operator's call. (b) A state
   fact: the runner pushes the distance, the state scales its velocity. Tier A, `FORMAT_VERSION` 22. (c) Keep fixed distances
   and only fix the visuals: RED lands on the head only at 4.0 m. AC 9 asks for (a) or (b); the dev stops and asks before
   choosing, per Agent autonomy.
2. **RED rate versus the state's forward leg (AC 8).** The jump cut must end at 0.30 s of the span (the forward leg), so at rate
   `r` the jump gets `0.30 r` s of clip and the backflip `0.70 r` s. At r = 1.6 that is a 0.48 s take-off and a 1.12 s flip, shorter
   than the measured full flip (1.90 s). Levers: the cuts, `counter_travel_forward_fraction_red` (a `.tres` knob, not a 7-9
   number), `counter_busy_seconds_red` (the operator's, stays 1.0). Recommendation: re-cut first; if the flip reads cut off,
   the operator raises the busy span or the forward fraction in the `.tres` at smoke. Report the achieved rate.
3. **Glow (M2).** No `Environment` exists. Recommended: an additive billboard quad plus a small OmniLight per eye (no scene or
   project change). A per-camera `Environment` with glow would be a scene edit with a look-wide effect and needs a ruling.
4. **Hit-stop on a rig that is travelling (M6).** The offset-and-catch-up is a visual approximation; if it reads as a
   teleport at smoke, the fallback is hitstop on the AnimationPlayer only (no offset). Decided at smoke.

## Live Smoke

Solo `[0,3]`: P1 keyboard casts with X/V/B, the operator defends on the pad and watches P1's eyes from P2's screen. Record
verdicts in the story's dev record, not in `docs/playtest-log.md` (close-out owns that).

1. Eyes off at rest. On cast: colour is the unblockable's, blink accelerates, flash at launch, lit through the flight, off at contact.
2. Pressing on the anticipated flash counters reliably; the tick and the sting are audible.
3. RED: the jump reads, lands on the head at near AND far range, hitstop + flash + thud, rebound, the attacker falls without a pop.
4. GREEN: dagger visible with a trail, the hit is felt, the attacker falls at impact and not before, no pop.
5. Knocked down by an unblockable: the silver immunity marker on the get-up, fading over about 1.5 s; an unblockable cast into it
   passes through; the marker is gone afterwards.
6. Regression (melee, spells, roll, normal knockdown) and frame rate stable in both viewports.
7. BLUE travel, only if touched.

### Live Smoke Results

Operator, solo `[0,3]`, 2026-10-09 (P1 casts with X/V/B, operator defends on the pad). Every item PASS (full entry in
`docs/playtest-log.md`, 2026-10-09). Item 7 was not exercised: BLUE is untouched.

1. PASS. Eyes light in the unblockable's colour, blink faster, flash at the launch, go out on the touch; all three colours.
2. PASS. A press on the anticipated flash counters reliably.
3. PASS. RED: freeze, flash, hit and camera shake work; the jump and rebound have a better rhythm. A FAILED RED has no
   jump onto the head and the operator eats the hit (review F1 as fixed).
4. PASS. GREEN: the dagger shows with a trail, the hit is felt, the attacker falls on the hit.
5. PASS. The silver immunity shimmer is visible and fades; an unblockable passes through.
6. PASS. Regression and frame rate OK.

Operator notes (none blocking): RED tempo feels slightly slow; the eye tick sound reads like bubbles; the eye flash could be
more striking; the orb above the head has not been visible for some time (moved out earlier, not this story's topic, see
the AC 6 note). Overall: "super".

## Project Context Rules

Presentation is a consumer: it polls existing public facts after `advance()` and never holds a state handle (`4-3/R2`: no
world position crosses into state); all authored numbers are `.tres`/named constants; hot loops allocate nothing; the
observation seam family stays at ten; the shell is PowerShell 5.1 or Git Bash with `GODOT=/c/Godot/godot.exe` for
`run_all.sh`.

## References

- `docs/implementation-artifacts/7-9-unblockable-tempo.md` (R4/R8 window, R1 immunity, M4, M13)
- GDD decision-log: `7-8/R20` (routing), `7-9/R8` (flash on the commit), `6-6b` deferred items
- `docs/game-architecture.md` (presentation seams), `docs/project-context.md` (CONSTRAINT C, F1, D3)

## Dev Agent Record

### Agent Model Used

Claude (dev pass 2026-10-08, single session, no subagents). Commits carry the repo-constant trailer (`6-1c/R7`).

### Debug Log References

- Suite before: `C:\dev\_710-suite-before.txt` (22:53:50) -- 1289 tests / 0 failed / 13187 assertions; 79/79 integration PASS.
- Suite after: `C:\dev\_710-suite-after.txt` (23:20:18) -- 1289 / 0 / 13187; 81/81 integration PASS (79 + the 2 new files).
- Head measurement: `C:\dev\_710-head-measure.txt` (`tools/measure_head_visor.gd`, final run).
- Full record: `C:\dev\_710-dev.md`.

### Completion Notes List

**Operator rulings on the Open Questions (from the dev prompt, recorded here per operator ruling):**

- **OQ1 -- per operator ruling:** distance-aware RED landing rescales the BODY. `HeroActor.drive()` applies
  `hero_state.velocity * counter_travel_scale` (`src/actors/hero/hero.gd`); the runner locks
  `k = min(1, gap_at_press / counter_travel_distance_red)` at the counter's rising edge from the actor-side planar gap
  and sets it every running tick while the defender is IDLE (both legs, same k, net zero). No state edit. F1/D3 do
  not forbid it (the actor still has no `_physics_process` and reads no input), so the **body route was taken**, not
  the mesh-only fallback. BLUE untouched. A press with gap > 4.0 m keeps k = 1 and lands short (smoke watch).
- **OQ2 -- per operator ruling:** busy stays 1.0 s. `counter_jump` has no crouch to trim (feet off the ground by
  t=0.067), so its cut keeps 0..0.7667 (the settle after the landing trimmed); `counter_backflip`'s crouch (0..0.68)
  and recovery (1.5..2.1667) are trimmed: 0.68..1.5. Achieved **RED rate 1.587x** (was 2.733x; the TEMP 1.6x target is
  met). `counter_travel_forward_fraction_red` 0.305 -> **0.49** in `data/balance/balance_config.tres` so the
  jump/backflip join (0.483 s) meets the forward-leg end (elapsed tick 29 = 0.483 s); its only guard is the (0, 1)
  bound in `test_balance_authoring.gd`, so no test/state edit. **GREEN rate unchanged at 1.360x** (cut untouched).
- **OQ3 -- per operator ruling:** no WorldEnvironment/Environment. The eyes are unshaded additive billboard quads (a core
  and a halo each); the flash is a scale burst plus a brief OmniLight3D.
- **OQ4 -- per operator ruling:** the hitstop holds the mesh at the root's position and eases it back over
  `HITSTOP_CATCHUP_SECONDS` (0.12 s); smoke watch, nothing further.

**Task 1 (measured).** `tools/measure_head_visor.gd`, CPU-skinned in the idle rest frame: skeleton unscaled (metres);
`mixamorig_Head` at model (-0.083, 1.379, 0.081), `HeadTop_End` at y 1.554 (feet at 0). The head geometry (2732
vertices whose dominant bind is Head/HeadTop_End) spans -0.092..+0.183 m along the head's up axis; its front surface
along head-forward is 0.107..**0.1395** m across all bands, sideways about +-0.09 m. The eyes sit at forward **0.155**
(0.0155 in front of every head vertex at their height, so the helmet cannot occlude them from a camera in front -- the
opponent's), up 0.075, +-0.035 sideways, in the head-bone frame via `EffectFx.bone_follower`. Finding: the FBX mesh
names do not describe their geometry (the helmet is in the meshes named `..._Sword`/`..._Shield`; the 85-vertex mesh
named `..._Helmet` is bound to `Shield_joint`). Glow route: quads + OmniLight (OQ3). Clip tables from the same tool:
`counter_jump` feet leave by 0.067, apex hips 1.531 at 0.40, land 0.733-0.767; `counter_backflip` crouch to hips 0.598
at 0.333, take-off ~0.70, feet peak 1.764 at 1.033, land 1.333, recovery to 1.9+.

**Task 2 (eyes).** `UnblockableEyes` (`src/actors/hero/unblockable_eyes.gd`) on the head bone, built in
`HeroActor._ready`, NOT under `TelegraphController` (the F3 debug layer). The runner poll `_push_unblockable_markers`
(after `_push_charge_progress`) drives it per tick: lit = CHARGING and `charge_contact == NONE`; progress =
`1 - remaining/duration` of `charge_window`; FLASH when `charge_window.is_running` goes false while lit. Round over
suppresses at step 4d off the existing `round_over` read; the debug reset clears via `HeroActor.clear_presentation()`
from `_relay_round_started`. Colour from the hero's own charge `TelegraphProfile`s. ChargeMarker, the charge clips and
the stings are untouched (AC 6); whether the orb is now redundant is a smoke call.

**Tasks 3/4/5 (counter contact).** Runner-local bookkeeping beside `_counter_armed`: `_begin_counter_contact` (press:
arm the victim hold if the other hero is CHARGING; RED: lock k, the arc height = attacker `HeadTop_End` world y minus
the defender's feet, clamped to 2.2 m, and the contact tick), `_drive_counter_contact` (each running tick: k; lift =
height x `counter_lift_fraction()`, read off the PLAYHEAD; on the contact tick with a held victim: hitstop on both
rigs, impact burst/flash/light at the head, thud, shake on both follower cameras), `_drive_victim_hold` (release at
impact + hitstop, or at `VICTIM_HOLD_MAX_SECONDS`), `_end_counter_contact` (falling edge/re-cast: back to rest, release
or disarm), `_green_dagger_impact` (dagger arrival: hitstop on the attacker, sparks, thud). The victim hold lives in
`AnimationController`: the STUNNED transition is held (its clip remembered) and cross-faded in by
`release_victim_hold` through `_play_stun(..., blend)`; the state is STUNNED from the fire tick exactly as before.
Hitstop = `AnimationPlayer.speed_scale` 0 (`set_frozen`) + the mesh offset in `HeroActor`, counted in `drive()`
calls. The shake is positional on `_p1_view_cam`/`_p2_view_cam` after step 4b's copy; the rigs and their bases are
never written (camera-basis and root-rotation guards green and unedited). Dagger: world-space trail, flight
`min(span, 0.22 s)`, aimed at the trunk bone.

**Task 6 (immunity).** `ImmunityShimmer` (`src/actors/hero/immunity_shimmer.gd`): silver star particles in a body box,
alpha = 0.7 x the remaining fraction of `unblockable_immunity`, level-triggered from the same poll.

**Task 7 (before/after).** Golden pin `9d5d4fad...` (`test_determinism.gd:1336`): `test_state_matches_golden` [ok]
before and after. `FORMAT_VERSION` 21 (`src/systems/record_file.gd:369`) unchanged; its tests [ok] in both runs. Key
sets: 46 player (`test_draw_delay_and_reshuffle.gd` pin), 21 hero -- **recounted mechanically** with comments stripped
from `test_debug_window_countdown.gd:107-127`: 21 names, 21 unique -- and 6 top-level, all pinned and [ok] in both
runs. Both directions: the sorted list of 1289 state-harness result lines is identical before vs after (0 lines only
before, 0 only after). `git diff -- src/state test/state` is empty. No new `connect_*` (the family test is [ok]); the
F1/D3 invariant tests are [ok]. **The Live Smoke is the operator's** (post-dev, the 7-9 precedent) and has not been run.

**Mutation table (measured; each ran only the affected file and was restored by copy-back with a SHA-256 match, never
`git checkout`).**

| # | File | Mutation | Test | Result |
|---|---|---|---|---|
| M1 | hero.gd | drop `* counter_travel_scale` | live | FAIL: body x1.000, want x0.625 |
| M2 | animation_controller.gd | victim hold disabled (`if false and ...`) | live | FAIL: knockdown at elapsed 3 < contact 29; no freeze; no shake; GREEN knockdown before impact |
| M3 | match_runner.gd | eyes gate ignores `charge_contact` | live | FAIL: eyes not OUT on first touch |
| M4 | unblockable_eyes.gd | flash on `progress >= 0.95` | live | FAIL: flash not on the commit tick |
| M5 | unblockable_eyes.gd | blink lerp inverted | knobs + live | FAIL: interval grows; blinks slow down (gap 6 -> 13) |
| M6 | match_runner.gd | shimmer always pushed 0.0 | live | FAIL: not shown, fraction 0 vs 0.967 |
| M7 | immunity_shimmer.gd | silver = RED (0.95, 0.1, 0.1) | knobs | FAIL: distance 0.000 |
| M8 | animation_controller.gd | `set_frozen` never freezes | live | FAIL: rigs never freeze |
| M9 | match_runner.gd | shake also rotates P1's follower | live | FAIL: shake not positional |
| M10 | match_runner.gd | dagger flight cap 99 s | live | FAIL: arrived at +30 > 15 frames |
| M11 | dagger_actor.gd | trail freed | live | FAIL: no trail |
| M12 | animation_controller.gd | backflip cut to 2.65 | knobs | FAIL: RED rate 2.7367 >= 2.733 |

**Knob list (every new number; tune at smoke with no suite run -- the tests pin bounds and directions only):**

- `src/actors/hero/unblockable_eyes.gd` -- placement `EYE_FORWARD_M` :38 (0.155), `EYE_HEIGHT_M` :39 (0.075),
  `EYE_HALF_SEPARATION_M` :40 (0.035); size `EYE_CORE_SIZE` :42 (0.07), `EYE_HALO_SIZE` :43 (0.22); brightness
  `EYE_BRIGHTNESS` :45 (1.6), `EYE_HALO_ALPHA` :46 (0.55), `EYE_BLINK_DIM` :49 (0.15); blink `BLINK_INTERVAL_SLOW` :52
  (0.45 s), `BLINK_INTERVAL_FAST` :53 (0.07 s), `BLINK_CURVE` :54 (1.6), `BLINK_ON_FRACTION` :56 (0.5); flash
  `FLASH_SECONDS` :58 (0.2), `FLASH_SCALE` :59 (3.0), `FLASH_LIGHT_ENERGY` :60 (6.0), `FLASH_LIGHT_RANGE` :61 (3.0);
  sound `TICK_VOLUME_DB` :63 (-8), `STING_VOLUME_DB` :64 (0). Measured, not knobs: `HEAD_FORWARD/UP/SIDE` :31-33.
- `src/actors/effects/unblockable_presentation.gd` -- `RED_LAND_HEIGHT_MAX` :26 (2.2 m); `RED_HITSTOP_SECONDS` :31
  (0.1), `GREEN_HITSTOP_SECONDS` :32 (0.08), `HITSTOP_CATCHUP_SECONDS` :35 (0.12, OQ4), `VICTIM_HOLD_MAX_SECONDS` :39
  (0.6), `KNOCKDOWN_BLEND_SECONDS` :41 (0.15); `DAGGER_FLIGHT_SECONDS` :46 (0.22); impact `IMPACT_SPARK_AMOUNT_RED` :50
  (48), `IMPACT_SPARK_AMOUNT_GREEN` :51 (28), `IMPACT_SPARK_SIZE` :52 (0.16), `IMPACT_SPARK_SPEED` :53 (5.5),
  `IMPACT_SPARK_LIFETIME` :54 (0.35), `IMPACT_FLASH_SIZE_RED` :55 (1.4), `IMPACT_FLASH_SIZE_GREEN` :56 (0.7),
  `IMPACT_FLASH_SECONDS` :57 (0.15), `IMPACT_LIGHT_ENERGY` :58 (8), `IMPACT_LIGHT_RANGE` :59 (4); sound
  `RED_THUD_VOLUME_DB` :63 (2), `GREEN_HIT_VOLUME_DB` :64 (0); shake `SHAKE_SECONDS` :69 (0.2), `SHAKE_AMPLITUDE` :70
  (0.07 m), `SHAKE_FREQUENCY_HZ` :71 (27). Structural: `HERO_FEET_Y` :23 (-1.0, the Mesh grounding offset).
- `src/actors/hero/immunity_shimmer.gd` -- `SHIMMER_COLOR` :18, `SHIMMER_ALPHA` :20 (0.7), `SHIMMER_AMOUNT` :23 (28),
  `SHIMMER_SIZE` :24 (0.1), `SHIMMER_LIFETIME` :25 (0.6), `SHIMMER_EXTENTS` :26, `SHIMMER_RISE_SPEED` :28 (0.25).
- `src/actors/props/dagger_actor.gd` -- `TRAIL_COLOR` :39, `TRAIL_AMOUNT` :40 (40), `TRAIL_SIZE` :41 (0.22),
  `TRAIL_LIFETIME` :42 (0.25); the dagger's size stays `MODEL_SCALE` :33 (2.5).
- `src/actors/hero/animation_controller.gd` -- the RED cut and lift at :404-407 (`counter_jump` 0..0.7667, lift
  Vector4(0, 0, 0.7333, 1); `counter_backflip` 0.68..1.5, lift Vector4(0.70, 1, 1.3333, 0)).
- `src/actors/hero/hero.gd` -- `HEAD_TOP_FALLBACK_Y` :76 (0.55, used only by a rig without `HeadTop_End`).
- `data/balance/balance_config.tres` -- `counter_travel_forward_fraction_red` :161 (0.49; moves with the jump cut).

**Placeholder sounds (byte copies; swap by hand):** `assets/audio/effects/sfx_eye_tick.wav` <- `assets/audio/sting_attack.wav`
(each blink); `sfx_eye_flash.wav` <- `effects/sfx_counter.wav` (the commit flash); `sfx_counter_kick_thud.wav` <-
`effects/sfx_boom.wav` (RED head contact); `sfx_dagger_hit.wav` <- `effects/sfx_rock_hit.wav` (GREEN dagger hit).
Nothing was taken from `C:\dev\_sonniss\part1` (its candidates are 4-40 MB multi-hit takes that would need trimming).

**Deviations and notes.**

1. Task 1 took THREE headless launches, not one: launch 2 switched the head filter to a mesh-name one after misreading
   launch 1's per-mesh counts; that filter was wrong (the FBX names are scrambled) and shipped in the feat commit.
   Launch 3 verified the corrected bind filter, committed separately as `fix(7-10)`. The eye numbers come from launches
   1 and 3, which agree.
2. One tool call ran TWO engine launches back to back (the two new test files, re-run after a post-suite comment edit
   and naming the fallback constant) -- against the one-launch-per-call rule. Both PASS.
3. The commit chain gained a code-side commit (`fix(7-10)`, the tool only) beyond the planned promote -> assets ->
   feat -> docs.
4. Presentation now moves contact geometry: the RED lift and the hitstop's mesh hold carry the bone-tracked hit shapes
   with the picture (M6 accepted this for the hitstop; the lift extends it to the arc), and the scaled velocity moves
   the defender's root. All of it is actor-side; replay reads recorded facts, so determinism is unaffected. Flagged
   for smoke and review.
5. The victim hold is armed on any counter press against a CHARGING hero; a non-counter stun inside that span (rare) is
   held too, bounded by `VICTIM_HOLD_MAX_SECONDS`.
6. The skill's transient board writes (in-progress, then review) were not made; the on_complete end state (board
   `ready-for-dev`, story file `review`) was written directly.

### File List

- `src/actors/hero/unblockable_eyes.gd` (+ `.uid`) -- new
- `src/actors/hero/immunity_shimmer.gd` (+ `.uid`) -- new
- `src/actors/effects/unblockable_presentation.gd` (+ `.uid`) -- new
- `src/actors/hero/hero.gd` -- modified
- `src/actors/hero/animation_controller.gd` -- modified
- `src/actors/props/dagger_actor.gd` -- modified
- `src/main/match_runner.gd` -- modified
- `data/balance/balance_config.tres` -- modified (`counter_travel_forward_fraction_red`)
- `tools/measure_head_visor.gd` (+ `.uid`) -- new
- `test/integration/test_unblockable_presentation_knobs.gd` (+ `.uid`) -- new
- `test/integration/test_unblockable_presentation_live.gd` (+ `.uid`) -- new
- `assets/audio/effects/sfx_eye_tick.wav`, `sfx_eye_flash.wav`, `sfx_counter_kick_thud.wav`, `sfx_dagger_hit.wav`
  (+ `.import` each) -- new
- `docs/implementation-artifacts/7-10-unblockable-presentation.md`, `docs/implementation-artifacts/sprint-status.yaml`

## Change Log

| Date | Change |
|---|---|
| 2026-10-08 | promoted 2026-10-08 after operator review; Open Questions 1-4 resolved in the dev prompt, recorded in the Dev Agent Record |
| 2026-10-08 | dev pass: eyes, RED/GREEN contact moment, victim hold, immunity shimmer, RED re-cut (1.587x); Status -> review |
| 2026-10-08 | code review round 1 (`0e43bed`): F1 HIGH + F2 MED + F3/F4 LOW fixed; verdict APPROVE AFTER FIX |
| 2026-10-09 | close-out: Live Smoke 1-6 PASS, 7 not exercised (operator); AC 17 amended, AC 6 orb note; Status -> done |
