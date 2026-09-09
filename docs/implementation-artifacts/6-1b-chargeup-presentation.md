---
baseline_commit: 8bec2b026078607b383810433e17432fa66a0c94
---

# Story 6.1b: Chargeup Presentation

Status: ready-for-dev

> **Scope note.** THIRD E6 story (`E6-P/R2` board order), first E6 story that is presentation-only
> against a `src/state/` change that already shipped (`6-1`). Tier B by content — no `src/state/`
> file may change, and the golden/30-key snapshot set are predicted UNMOVED (measured both
> directions in the dev pass, not assumed). Carries the `6-1/R15` named finding as its FIRST item
> (`decision-log.md:9561-9566`), and is expected to discharge the "chargeup unreadable" retune
> entry in passing (`E6-P/R8` amendment (i), `epics.md:271-274`).

## What this story supersedes / measures against the brief

The operator's ratified scope (recorded below as the Acceptance Criteria) was checked against the
shipped code before this story was written. Six findings are load-bearing.

1. **The `6-1/R15` finding, restated precisely.** `6-1`'s live smoke observed the chargeup
   ANIMATION finishing before the authored `unblockable_chargeup_seconds` window (1.0s = 60 ticks,
   `data/balance/balance_config.tres:127`, `balance_ticks.gd:142`) expires — a release that looks
   late by eye, judged against the finished animation, is state-wise still an early release and
   correctly feints (`test_a_release_on_the_landing_tick_itself_still_lands`,
   `test_unblockable_hold.gd`). The state-side boundary is correct and untouched by this story;
   only the PRESENTATION under-runs the window it is meant to fill.

2. **MEASURED: which clip plays during CHARGING, and its native length.**
   `AnimationController` (`src/actors/hero/animation_controller.gd`) selects ONE of three clips by
   `charge_color` (`_CHARGE_CLIP`, `:86-90`): `swipe` (RED), `thrust` (BLUE), `jump_attack`
   (GREEN). Their measured native (`.fbx`-source) lengths are already named constants
   (`:97-99`, from `tools/measure_hips_displacement.gd`'s own `len` column):
   `SWIPE_NATIVE_SECONDS := 1.7333`, `THRUST_NATIVE_SECONDS := 2.1333`,
   `JUMP_ATTACK_NATIVE_SECONDS := 3.6667`. All three are ALREADY compressed to the authored
   1.0s window by a per-colour `custom_speed` factor (`CHARGE_CLIP_SPEED`, `:124-128`,
   `rate = native_seconds / CHARGE_ALIGNED_CHARGEUP_SECONDS`), applied ONCE at the
   `CHARGING` transition via `_restart(clip, speed)` (`:226-228`) — the clip is played at a fixed
   fast rate for its own native duration, which by construction takes exactly 1.0s of WALL TIME to
   finish playing, but front-loads the whole swing (wind-up AND strike AND follow-through) into
   that one uniform-speed pass. The `6-1/R15` "finishes early" observation is therefore not a
   ticking-rate bug — it is a READABILITY fact: the swing's OWN strike beat sits somewhere inside
   that uniform pass (not measured at the frame level by this story; see Open Questions), and once
   the visible swing motion reads as complete, a defender watching the body rather than a clock
   sees "the attack already happened" well before the authored window closes, even though the
   `AnimationPlayer` technically still has motion left to play. This is exactly why the operator's
   direction (item 2 below) is a RE-TEMPO, not a speed-constant fix: a uniform speed cannot solve a
   readability problem that is about WHICH PART of the swing is visible WHEN, only about how long
   the whole clip takes.

3. **MEASURED: there is no separate `ATTACKING` action-state for mode ②.**
   `_resolve_charge_landing` (`match_state.gd:2885-...`) is called from the `CHARGING` arm of
   `_resolve_actions` the instant `charge_window.is_running` goes false (`match_state.gd:970-972`),
   and every one of its outcomes (miss, dodge, full damage, colour-counter negation) writes
   `IDLE` or `STUNNED` directly — never `ATTACKING`. The "launch phase" the operator's scope talk
   names is therefore a PRESENTATION-INTERNAL phase inside the single `CHARGING` clip session, not
   a second `ActionState` and not a second `connect_hero_action_state_changed` transition. The
   clip must reach its own visual "impact" beat at (or just before) the exact tick the window
   naturally expires and the hero leaves `CHARGING` — there is no later seam callback to hang a
   "now play the strike" cue on.

4. **MEASURED: the feint teardown already rides the existing channel, largely for free.**
   `6-1`'s early-release exit (`match_state.gd:975-979`) writes the SAME three-part fact
   `_reset_player` uses (`set_action_state(IDLE)` / `charge_window.start(0)` /
   `charge_color = NO_TELEGRAPH_COLOR`), which fires the EXISTING `connect_hero_action_state_changed`
   seam as a `CHARGING -> IDLE` transition. Both presentation consumers already react correctly to
   that transition with ZERO new code: `AnimationController.on_action_state_changed`
   (`:158-168`) hits the `IDLE` branch of `_CLIP` and calls `_restart(&"idle")`, cutting the charge
   clip immediately; `TelegraphController.on_action_state_changed` (`telegraph_controller.gd:120-`)
   hides every telegraph shape on entry to any state it does not map, which includes `IDLE`. So
   item 4 of the operator's scope ("feint presentation derives solely from the telegraph fact
   clearing on release, consumed through the existing channel") is **already true today** — the
   ONLY risk this story introduces is regressing it: if the re-tempo mechanism replaces the
   single-shot `_restart(clip, speed)` call with a per-tick DRIVEN playhead (Open Questions), that
   per-tick drive must ITSELF stop the instant the `CHARGING -> IDLE` transition fires, or a stale
   per-tick push could re-assert a charge-clip frame after the seam has already cut to `idle`. This
   is a NEW ordering hazard the current single-shot design does not have, named here so the dev
   pass tests it directly rather than discovering it live.

5. **MEASURED: progress is computable presentation-side with the EXISTING public state surface —
   no new `src/state/` accessor is needed.** `TimingWindow` (`src/state/timing/timing_window.gd`)
   exposes `remaining_ticks()` (public) but not elapsed or duration (both private,
   `_elapsed_ticks`/`_duration_ticks`, `:12-13`). The runner already reads the AUTHORED tick count
   inline, elsewhere, per CONSTRAINT C: `MatchState.balance_ticks.unblockable_chargeup_ticks` is a
   public var (`balance_ticks.gd:88`) set once at `apply_balance()`. So
   `progress = 1.0 - float(player.charge_window.remaining_ticks()) / float(_match_state.balance_ticks.unblockable_chargeup_ticks)`,
   computed IN THE RUNNER (`src/main/match_runner.gd`, not `src/state/`) exactly the way
   `_push_charge_reach_facts` already computes a runner-side derived fact from state it reads but
   does not own (`match_runner.gd:637-689`), gives a presentation-side progress value without a
   single line of `src/state/` diff. **`src/state/` byte-identical (AC 6 below) is achievable by
   construction, not merely by discipline**, provided the dev pass takes this route rather than
   adding a `progress()`/`elapsed_ticks()` method to `TimingWindow`.

6. **MEASURED: the BC/R3 narrowing (`tools/retime_clips.gd`) does NOT reach
   `unblockable_chargeup_seconds`, and this story does not trigger it — documented, not
   triggered, per the operator's own instruction.** `tools/retime_clips.gd`'s `GOVERNED_CLIPS`
   is `[&"attack", &"roll"]` ONLY (`retime_clips.gd:31`), driven by
   `attack_windup_seconds`/`attack_active_seconds`/`attack_recovery_seconds`/`roll_duration_seconds`
   — the four fields `3-0b/R26` named as the ACCEPTED NARROWING of BC/R3
   (decision-log:1725-1737). `unblockable_chargeup_seconds` is NOT one of those four and this
   story does not retune it (Non-Goals), so `tools/retime_clips.gd` is NOT run by this story and
   its no-op-by-construction guard is expected to prove that if run. **A SEPARATE, PRE-EXISTING
   coupling already exists for the charge clips specifically**, and it is NOT `retime_clips.gd`:
   `test_the_charge_clip_speeds_still_describe_the_authored_chargeup`
   (`test/state/test_balance_authoring.gd:264-284`) reads the authored value and asserts it equals
   `AnimationController.CHARGE_ALIGNED_CHARGEUP_SECONDS`, then re-derives `CHARGE_CLIP_SPEED` from
   it and asserts the shipped dictionary matches. **This test is a candidate for direct impact by
   this story's own mechanism change** (see Open Questions) — if the dev pass's chosen shape
   retires `custom_speed`-based playback in favour of a driven playhead, `CHARGE_CLIP_SPEED` /
   `CHARGE_ALIGNED_CHARGEUP_SECONDS` may become dead constants this test still guards, or the test
   itself may need to change shape to guard the NEW mechanism's coupling instead. Either way this
   is a DEV-PASS DECISION to make and record, not pre-ruled here — but it is flagged so it is
   budgeted rather than discovered mid-pass.

## Story

As the operator closing the `6-1/R15` chargeup-readability finding and the "chargeup unreadable"
retune entry it doubles as (`E6-P/R8` amendment (i)),
I want the chargeup presentation (crouch/jump shape, a short mid-air hover at the apex, a slowed
wind-up into a held strike pose) to visually FILL the authored 1.0s chargeup window instead of
finishing early,
so that a defender judging the attack by eye — not by a clock — sees the same commitment window the
state layer is already enforcing, and an early release reads unambiguously as a feint cut out of
the wind-up rather than as "the attack already happened."

## Acceptance Criteria

**The chargeup clip fills the authored window, by construction.**

1. **For a chargeup that runs to natural completion (no release), the clip's readable "about to
   strike" pose is visibly sustained until the tick the window actually expires** — a naive
   observer watching only the body, never a clock or a HUD timer, cannot correctly guess that the
   window has closed before `_resolve_charge_landing` actually fires. Concretely: the clip's
   playhead is driven every tick from chargeup window PROGRESS
   (`elapsed_ticks / unblockable_chargeup_ticks`, computed per finding 5 above, entirely from
   EXISTING public state surface), not from a fixed `custom_speed` applied once at the `CHARGING`
   transition — so the motion structurally cannot finish before progress reaches `1.0`, for
   whatever `unblockable_chargeup_seconds` happens to be authored (this story does not retune it,
   but the mechanism must not silently assume `1.0`).

2. **The window plays as a phase map inside the ONE `CHARGING` clip session, ending at the clip's
   own STRIKE FRAME (Sekiro grammar, operator ruling):** a SLOWED wind-up into the strike pose,
   then a HELD BEAT at the inflection point (the pose visibly static for a nonzero span — this is
   what makes the threat readable), then a FAST strike portion, with the clip's own measured
   STRIKE FRAME reached at (or immediately before) the LAST VISIBLE tick of the window — the clip's
   follow-through is NOT scheduled inside the window. There is no later seam to hang a "now play
   the strike" cue on (finding 3), and the landing transition to `IDLE`/`STUNNED` cuts the clip AT
   expiry — this cut is EXPECTED and correct, not a defect this story fixes: the state layer frees
   or stuns the hero immediately, and presentation follows. **Where the held beat sits as a
   fraction of window progress, and how long it holds, are FEEL KNOBS tuned at live smoke — not
   fixed by this AC.** No new Mixamo clip and no new bone/track content: this is a re-tempo (a
   nonlinear time-remapping) of the THREE EXISTING clips (`swipe`/`thrust`/`jump_attack`), never a
   clip swap.

3. **Crouch/jump shape and a short mid-air hover at the apex (operator's feel-item list) are
   expressed through the re-tempo, not through new content.** Where each existing clip already has
   airborne or coiled motion in its native keyframes (most directly `jump_attack`'s leap), the held
   beat should land on or near that motion so the hold itself reads as the crouch/hover; where a
   clip is grounded throughout (most directly `swipe`), the same held-beat mechanism should still
   produce a readable "coiled, about to strike" pause even without literal airtime. The exact
   per-clip placement is a feel knob (AC 2) — this AC only requires that the SAME mechanism
   (slowed wind-up + held beat) is what produces the feel, not a per-clip special case bolted on
   separately for "jump" vs "swipe"/"thrust".

**The paid feint (early release) is unaffected by the retempo — verify, don't just assume, the
existing channel survives it.**

4. **An early release still cuts out of the wind-up on the exact release tick, through the EXISTING
   channel and no other.** The `CHARGING -> IDLE` transition (already firing today per finding 4)
   must still immediately: stop whatever driven playhead position the retempo left the clip at and
   cut to the `idle` clip (`AnimationController.on_action_state_changed`'s existing `IDLE` branch,
   `_restart(&"idle")`), and hide the telegraph shape
   (`TelegraphController.on_action_state_changed`'s existing unmapped-state clear). **No new
   signal, no new seam, no new snapshot read, no new consumer** — this AC is a REGRESSION PIN on
   behaviour that already ships, made explicit because the retempo mechanism (a per-tick driven
   playhead, if that is the shape chosen) introduces an ordering hazard the current single-shot
   `_restart` does not have (finding 4): a per-tick push that outlives the transition could
   re-assert a stale charge-clip frame one tick after the cut to `idle`. This AC requires that
   cannot happen, on any tick.

5. **A release AFTER the window naturally expires is a no-op for presentation, exactly as it is for
   state (`6-1` AC 1).** The fast-remainder phase (AC 2) was already playing or had already reached
   its end before the release; nothing about the retempo may introduce a NEW post-completion
   presentation effect that state's own no-op contract does not have.

**Structural constraints (no state, no new seam, no new content, no reach change).**

6. **`src/state/` is byte-identical.** `git diff --stat -- src/state/` must be empty at both the
   BEFORE and the final measurement. The progress value this story needs is derivable entirely
   from EXISTING public state surface (finding 5) — no new method, field, or export on
   `TimingWindow`, `PlayerState`, `HeroState`, or `MatchState`.

7. **No new observation seam.** `test_runner_observation_seams_are_exactly_nine`
   (`test/state/test_architecture_invariants.gd:309`) stays green, UNEDITED. If the dev pass needs
   a per-tick presentation push (the progress value, or the charge colour/window facts it is
   derived from), it rides the EXISTING direct-call pattern the runner already uses for
   per-tick presentation pushes that are not `connect_*` seams (`HeroActor.drive()` calling
   `AnimationController.on_locomotion` every tick, `_push_charge_reach_facts` reading
   `_match_state.p1`/`p2` directly every tick) — never a new `connect_` method, which is the ONLY
   thing that guard counts.

8. **No new Mixamo clip, no auto-aim, no tracking, no generous reach, no attack travel of any
   kind.** The melee hitbox mechanism (`HeroActor._track_weapon_bone()`, bone-follow on the
   existing sword joint) is UNCHANGED — this story adds no collision, targeting, or travel logic
   of any kind. That is `6-1c`'s scope entirely, together with any VFX advertising reach
   (`epics.md`/scope talk, working key `6-1c`); this story touches presentation timing only.

9. **`unblockable_chargeup_seconds`, `unblockable_stamina_cost`, and `unblockable_reach` are NOT
   retuned.** `FORMAT_VERSION` stays 8 — no new `InputIntent` field or `held` key, no new replay
   channel; this story adds no input.

**Determinism and golden.**

10. **The full suite passes** (`bash test/run_all.sh`).

11. **A new test pins the clip/window PLAYHEAD COMPOSITION** — the exact class of blindness the
    suite carried through `6-1/R15` (the 3-0b/R34 precedent: the suite is blind to the RUNTIME
    composition of a clip and its governing window unless a test is written that specifically
    reads BOTH together). At minimum: for each of the three charge clips, the progress-to-playhead
    mapping (AC 1) must be asserted to hit BOTH window endpoints — `progress == 0.0` maps to
    playhead `~= 0.0`, and `progress == 1.0` maps to playhead `~= ` that clip's measured STRIKE
    FRAME (not the clip's own end — the follow-through is not scheduled inside the window; see
    AC 2). If the mapping is factored as a pure function (no scene, no `AnimationPlayer`
    instance needed to test it), prefer a headless state-style unit test for that function plus one
    integration-level check that a live `AnimationPlayer`'s actual position tracks it during a real
    `CHARGING` session; if the mapping is inseparable from `AnimationPlayer` playback, the whole
    test lives in `test/integration/`. Either way, this test must be shown driving BOTH endpoints,
    not merely one — the `6-1/R15` finding was invisible precisely because nothing checked the LATE
    end of the window against the clip's own state.

12. **Golden Prediction is measured, both directions — see the Golden Prediction section below.**

## Non-Goals (explicitly out of scope — do not implement, do not guess a shape for later stories)

- Auto-aim, tracking, generous reach, or any attack-travel behaviour of any kind — state-side
  landing behaviour, owned by `6-1c` (working key), together with any VFX advertising reach.
- Any retune of `unblockable_chargeup_seconds`, `unblockable_stamina_cost`, or `unblockable_reach`.
- Any `src/state/` change of any kind (AC 6).
- A new Mixamo clip, a new bone/track, or new imported animation content of any kind — this is a
  re-tempo of `swipe`/`thrust`/`jump_attack` only.
- A grace window on tap, or a post-release recovery window — `6-1`'s own Non-Goals, unaffected and
  unrevisited here.
- `6-2` onward (pitch-zone work) and `6-6` (defense presentation) — separate stories.
- A general 2D blend space or any change to the FIVE locomotion clips
  (`idle`/`run`/`strafe_left`/`strafe_right`/`backpedal`) or to `attack`/`block`/`roll`/`death` —
  those are `3-0b`'s territory and untouched here; `tools/retime_clips.gd`'s governed pair
  (`attack`, `roll`) is not run by this story (finding 6).

## Golden Prediction

**PREDICTED NOT TO MOVE — measure both directions before touching any file and after the diff; do
not treat this prediction as a substitute for the measurement.**

- **Candidate cause considered and rejected:** the only way this story could move the golden is if
  its presentation-side progress read (finding 5) were, in fact, a WRITE — either a new
  `src/state/` field/method, or a runner-side call into an existing state mutator that state does
  not already receive on this path. Neither is in scope (AC 6): the progress value is derived from
  two ALREADY-PUBLIC, ALREADY-READ-ELSEWHERE state facts
  (`PlayerState.charge_window.remaining_ticks()`, `MatchState.balance_ticks.unblockable_chargeup_ticks`),
  read the same way `_push_charge_reach_facts` already reads state to derive a runner-owned fact
  without mutating anything (`match_runner.gd:637-689`). No `to_snapshot()` on any state object
  changes shape, because no state object's fields change.
- **Net prediction:** the golden hash (`GOLDEN`, `test/state/test_determinism.gd:891`, currently
  `d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d`) and the per-player snapshot
  key set (`test/state/test_card_observation.gd`,
  `test_the_observation_channel_adds_no_snapshot_key`, currently THIRTY keys per `6-1`'s own AFTER
  measurement) are both predicted to stay UNMOVED, for the structural reason that this story
  contains no `src/state/` diff at all (AC 6) — not merely because no fixture-reachable behaviour
  happens to change. If either moves, the cause is NOT presentation timing by construction — find
  and name the actual cause (most likely: an accidental `src/state/` edit slipped in, which AC 6's
  own `git diff --stat` check should have caught first) rather than attributing the move to this
  story's ratified scope.

## Tasks / Subtasks

- [ ] Read the full MEASURED findings section above and the cited line ranges in
      `animation_controller.gd`, `telegraph_controller.gd`, `match_state.gd`, `timing_window.gd`,
      `balance_ticks.gd`, `match_runner.gd`, `hero.gd`, `test_balance_authoring.gd`, and
      `tools/retime_clips.gd` BEFORE writing any code (AC: all)
- [ ] Decide the presentation-side progress channel's exact shape (Dev Notes/Open Questions): a
      per-tick push from the runner (on the `on_locomotion`/`_push_charge_reach_facts` precedent),
      vs. computing progress INSIDE `AnimationController` from data it is handed at the `CHARGING`
      transition plus its own tick counting (which would need a `_process`/local counter — check
      this does not collide with F1's single-`_physics_process` invariant, since `AnimationController`
      has none today) (AC: 1, 6, 7)
- [ ] Measure the STRIKE FRAME of each of the three charge clips (`swipe`/`thrust`/`jump_attack`)
      with the existing strike-frame measurement tool from the `4-3d` strike-alignment work
      (`tools/measure_strike_frame.gd` — that pass measured minion clips the same way) and record
      the three MEASURED values in Dev Notes (AC: 2, 11)
- [ ] Decide the progress-to-playhead mapping (Dev Notes/Open Questions): the exact shape of
      "slowed wind-up + held beat + fast remainder" as a function of progress, per clip — this is
      the operator's Sekiro-grammar ruling made executable, and the held-beat placement/duration
      are feel knobs, not fixed here (AC: 1, 2, 3)
- [ ] Decide the fate of `CHARGE_CLIP_SPEED`/`CHARGE_ALIGNED_CHARGEUP_SECONDS` and
      `test_the_charge_clip_speeds_still_describe_the_authored_chargeup`
      (`test_balance_authoring.gd:264-284`) against the chosen mapping — record whether they stay,
      are retired, or are re-shaped to guard the new mechanism's coupling to the authored value
      instead (finding 6) (AC: 9, 11). If the chosen mechanism retires `CHARGE_CLIP_SPEED` /
      `CHARGE_ALIGNED_CHARGEUP_SECONDS`, the old test must NOT survive as a guard over dead
      constants — the new composition test (AC 11) takes over the coupling-to-authored-value duty
      in the SAME pass. Guarding retired constants is the known vacuous-guard class.
- [ ] Implement the driven playhead for the three charge clips, verifying the `CHARGING -> IDLE`
      early-release cut (finding 4) is not regressed by a stale per-tick push outliving the
      transition (AC: 4)
- [ ] Write the playhead-composition test (AC 11) BEFORE declaring the mechanism done — show it RED
      against the un-retempo'd baseline (custom_speed-only playback reaching progress 1.0 well
      before the clip's own visual "impact" reads as complete) to prove it is measuring the right
      thing, per the dev-pass restore discipline (back up the mutated file to scratchpad + SHA256
      before mutating; restore by copying back, never `git checkout`)
- [ ] Confirm `git diff --stat -- src/state/` is empty at the end of the pass (AC 6)
- [ ] Confirm `test_runner_observation_seams_are_exactly_nine` stays green, UNEDITED (AC 7)
- [ ] Measure and record the BEFORE golden hash + snapshot key set; implement; measure AFTER; fill
      in the Golden Prediction section's result (AC 12)
- [ ] Run the full suite (`bash test/run_all.sh`) and record BEFORE/AFTER counts and file timestamps
      (AC 10; no machine-time cap this story — the operator's ruling is "runs until it feels
      right" — but the suite-output file timestamps are still recorded and reported at close-out
      as the measured interval)
- [ ] Live smoke with a single physical pad, flip `[0,3]` — see the Live Smoke section below

## Live Smoke

Single physical pad, flip `[0,3]` (covers both slots — modes ②/③ are pad-only, keyboard untouched).

1. **Hold-through, full window, each colour** — arm a slot, hold through the full chargeup for
   RED/BLUE/GREEN in turn: the wind-up visibly slows, a held beat is visible at the inflection
   point before the strike, and the body stays visibly MID-COMMITMENT right up to window expiry,
   with the strike landing AT expiry. Judge the immediate cut to idle/stagger on landing (the
   follow-through is not scheduled inside the window, and is not expected to play) as a WATCH ITEM
   — existing gameplay, acceptable unless it grates; a ruling on it, if needed, is later and
   separate from this item's pass/fail.
2. **Crouch/jump readability** — does the held beat read as a readable crouch/coil (grounded
   colours) or hover (`jump_attack`, GREEN) rather than as a freeze-frame glitch?
3. **Hover at the apex** — for GREEN specifically, is there a short mid-air hold that reads as
   deliberate rather than as the clip simply pausing?
4. **Held-beat readability as a THREAT** — does the paused pose communicate "about to strike" to
   an opponent watching, at each of the three colours?
5. **Early release / feint read** — release partway through the wind-up (before the held beat, and
   again during the held beat): does the cut to `idle` and the telegraph clearing (both already
   shipped by `6-1`) still read cleanly as a feint, with no stale charge-clip frame lingering for
   even one visible frame after the release?
6. **Tap** — shortest possible press: same feint read as item 5, no partial swing visible.
7. **Ordinary regression** — melee, roll, block, Basic cast, and mode ③ (defense) all look and feel
   unchanged; the shipped `6-1` hold-through/feint/refusal behaviours are all still correct by eye.
8. **fps** recorded.

## Live Smoke Results

_Not yet run — this story is authored and awaiting operator review, not cleared for a dev pass._

## Dev Notes

### Open Questions for the dev pass (named, not pre-ruled)

- **The progress-to-playhead mapping's exact shape.** "Slowed wind-up + held beat + fast
  remainder" is the operator's ruling on GRAMMAR, not on numbers. Candidate shapes include (a) a
  piecewise-linear map with three named breakpoints (wind-up end / hold end / progress end) tuned
  per clip, or (b) a single shared curve (e.g. an ease-in to a plateau to an ease-out) parameterised
  by one or two knobs reused across all three clips. Either is defensible; name the choice and why.
- **How the progress value reaches `AnimationController` each tick.** The strongest precedent is a
  per-tick push from the runner, mirroring `HeroActor.drive()`'s call to `on_locomotion` (which
  itself is called once per tick from the runner's step-5 hero drive) — but `drive()` receives
  `HeroState`, not `PlayerState` (where `charge_window` lives), so either `drive()`'s signature
  widens to take `PlayerState` too, or a NEW per-tick call site is added alongside it (on the
  `_push_charge_reach_facts` precedent, called from the runner's own tick sequence rather than
  through `HeroActor`). Name which, and why — this is a codebase-shaping choice (a signature
  change on an existing hot per-tick call vs. a new call site) and should be justified against the
  existing patterns rather than picked arbitrarily.
- **Whether `custom_speed`-based playback (`_restart(clip, speed)`) is retired for the charge
  clips specifically, or kept as the entry point with per-tick seeking layered on top.** This
  determines the fate of `CHARGE_CLIP_SPEED`/`CHARGE_ALIGNED_CHARGEUP_SECONDS` and their guarding
  test (finding 6) — record the decision either way.
- **Exact held-beat placement and duration per clip** — an explicit feel knob, tuned at live smoke,
  not fixed by this story's ACs (AC 2/3).
- **Whether the held beat should hold on a single frame (seek to a fixed time and stop advancing)
  or crawl very slowly (a very small nonzero rate)** — both would read as "held" to an eye but
  differ in cost/complexity; a dev-pass call.

The `6-1` close-out log recorded `6-1/R15` as the clip mechanically under-running the window; this
story's create pass measured the true cause (uniform-speed compression / readability under-run,
not a ticking-rate bug — finding 2). The correcting log entry rides THIS story's own close-out log
write (a citing entry, never an edit of the pushed `6-1` close-out log) — noted here so close-out
does not forget.

### Files expected to change

- `src/actors/hero/animation_controller.gd`: the progress-driven playhead mechanism for the three
  charge clips; the fate of `CHARGE_CLIP_SPEED`/`CHARGE_ALIGNED_CHARGEUP_SECONDS` (Open Questions).
- `src/main/match_runner.gd` and/or `src/actors/hero/hero.gd`: whatever call-site shape the dev
  pass picks for delivering per-tick progress (Open Questions) — presentation-only, no state
  mutation, no new `connect_*` seam (AC 7).
- `test/state/test_balance_authoring.gd`: `test_the_charge_clip_speeds_still_describe_the_authored_chargeup`
  may need to change shape or retire, per finding 6 — record which.
- A NEW test file (or an addition to an existing integration test) pinning the playhead composition
  (AC 11).
- **NOT expected to change:** any file under `src/state/` (AC 6); `project.godot`; `main.tscn`; any
  `data/` file (Non-Goals — no retune); `src/actors/hero/telegraph_controller.gd` — OUT of this
  story, full stop; if the held beat appears to need a telegraph-side cue change, the dev pass
  REPORTS it for a follow-up story instead of justifying it in-pass; `src/systems/intent_recorder.gd`/`src/systems/record_file.gd`
  (`FORMAT_VERSION` stays 8, no new input channel).

### Project Context Rules

- **HARD RULE — State/visual separation.** This entire story lives on the visuals side of that
  line: animations never decide game state, and the state layer decides what a contact/landing
  means, unchanged. [Source: CLAUDE.md; project-context.md, "HARD RULE — State / visual
  separation"]
- **F1 — single `_physics_process`.** `AnimationController` gains no `_physics_process` of its
  own; a per-tick progress push must ride the runner's existing tick sequence, never a second
  ticking source. [Source: CLAUDE.md, Load-bearing invariants]
- **CONSTRAINT C — never cache a reference that can go stale; read inline.** The authored
  `unblockable_chargeup_ticks` and the live `charge_window.remaining_ticks()` must both be read
  fresh at the point of use each tick, exactly as `_push_charge_reach_facts` already reads
  `_match_state.balance.unblockable_reach` inline. [Source: project-context.md, "Autoloads
  (singletons)"; match_state.gd's own CONSTRAINT C comments throughout]
- **Signals over polling; direct subscription is the default.** No new signal and no new
  `connect_*` seam this story (AC 7); a per-tick presentation push rides the EXISTING direct-call
  pattern (`on_locomotion`, `_push_charge_reach_facts`), not a new poll of `MatchState` from
  outside that pattern. [Source: project-context.md, "Signals over polling"]
- **Guard mechanism over guard pattern.** The new playhead-composition test (AC 11) must assert the
  mapping at BOTH window endpoints by construction, not merely spot-check one — the `6-1/R15`
  finding shipped BECAUSE nothing checked the late end. [Source: project-context.md, "Testing
  Rules"; `3-0b/R34`-class precedent]
- **Data as Resources / no hardcoded balance.** `unblockable_chargeup_seconds` stays the single
  authored source of the window duration; nothing in this story may hardcode `1.0` or `60` where
  the authored/derived value is available. [Source: project-context.md, "Data as Resources"]

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:207-208 (the `6-1b`
  line), :271-274 (the `E6-P/R8` amendment (i) retune-discharge obligation)]
- [Source: decision-log.md Session 2026-09-08 — E6 planning, `E6-P/R2` (:9301-9316), `E6-P/R8`
  and its amendment (i) (:9355-9372)]
- [Source: decision-log.md Session 2026-09-09 — `6-1` close-out, `6-1/R15` (:9561-9566), Next
  steps (:9595)]
- [Source: decision-log.md — `3-0b/R26` (:1725-1737), the BC/R3 narrowing precedent
  (`tools/retime_clips.gd`, scoped to `attack`/`roll` only, NOT the charge clips)]
- [Source: docs/implementation-artifacts/6-1-hold-to-charge.md — the state-side mechanism this
  story presents (the `CHARGING` exit arms, the three-part teardown, the paid-feint contract), and
  its own Live Smoke Results section recording the `6-1/R15` finding verbatim]
- [Source: src/actors/hero/animation_controller.gd:1-228 (full file read) — `_CHARGE_CLIP` (:86-90),
  the three native-length constants (:97-99), `CHARGE_ALIGNED_CHARGEUP_SECONDS` (:116),
  `CHARGE_CLIP_SPEED` (:124-128), `on_action_state_changed` (:158-168), `on_locomotion` (:184-187),
  `_restart` (:226-228)]
- [Source: src/actors/hero/telegraph_controller.gd:109-145 (`on_action_state_changed`, the
  CHARGING branch and the unmapped-state clear the feint already relies on)]
- [Source: src/state/match_state.gd:960-980 (`_resolve_actions`'s `CHARGING` arm — both exits, the
  timer-first ordering), :2885-... (`_resolve_charge_landing`, confirming no `ATTACKING` state for
  mode ②)]
- [Source: src/state/timing/timing_window.gd:1-49 (full file read) — `remaining_ticks()` public,
  `_elapsed_ticks`/`_duration_ticks` private, `TICK_HZ := 60.0`]
- [Source: src/state/timing/balance_ticks.gd:88 (`unblockable_chargeup_ticks`, public var), :142
  (its derivation)]
- [Source: src/main/match_runner.gd:637-689 (`_push_charge_reach_facts`, the runner-reads-state-
  without-mutating precedent this story's progress computation follows)]
- [Source: src/actors/hero/hero.gd:47-85 (`drive()`, the per-tick call site that pushes
  `on_locomotion`; the signature question in Open Questions)]
- [Source: tools/retime_clips.gd:1-31 (`GOVERNED_CLIPS := [&"attack", &"roll"]` — confirms the
  BC/R3 narrowing does not reach the charge clips)]
- [Source: test/state/test_balance_authoring.gd:264-284
  (`test_the_charge_clip_speeds_still_describe_the_authored_chargeup`, the pre-existing charge-clip
  coupling this story's mechanism change may affect — finding 6)]
- [Source: test/state/test_architecture_invariants.gd:309-332
  (`test_runner_observation_seams_are_exactly_nine`, the guard counting only `connect_*`
  declarations in `src/main/`)]
- [Source: test/state/test_determinism.gd:891 (`GOLDEN` constant); test/state/test_card_observation.gd
  (`test_the_observation_channel_adds_no_snapshot_key`, the 30-key pin per `6-1`'s own AFTER
  measurement)]
- [Source: data/balance/balance_config.tres:126-127 (`unblockable_stamina_cost = 20.0`,
  `unblockable_chargeup_seconds = 1.0`) — both UNCHANGED by this story]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
