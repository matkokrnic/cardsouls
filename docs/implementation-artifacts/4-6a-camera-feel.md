---
baseline_commit: 3af5cacea972be3a5298805bb4b2885f03abf383
---

# Story 4.6a: Camera Feel

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want retarget cycling that follows my on-screen layout, a camera that doesn't snap on
lock/retarget, and a marker on my current target,
so that lock-on feels controllable and readable, per the 4-6 live controller smoke.

## Acceptance Criteria

**(a) Retarget cycling replaces the cone pick**

1. `LockOnResolver.best_candidate`'s 120-degree alignment cone plus proximity tie-break
   (`src/main/lock_on_resolver.gd`) is REPLACED by adjacent-by-screen-X cycling relative to the
   CURRENT target: a horizontal flick selects the on-screen candidate immediately adjacent to the
   current target's screen X, in the flicked direction, among the same candidate set
   `_gather_flick_candidates` (`match_runner.gd:1877`) already gathers (opposing hero + living
   units, board-index order). Ruling authority: `sprint-status.yaml` 4-6a `story_notes`
   (2026-08-31). Playtest-log 31.8. item DODATNO is the operator's own QUESTION this ruling
   answers, not a restated conclusion — he described the current best-match behavior and asked
   whether literal left/right-by-screen-position would suit better, hedged and inviting input; the
   `story_notes` entry is the separate, later ruling.
2. No wrap: a flick past the leftmost/rightmost on-screen candidate is a no-op — the standing lock
   is left unchanged, delivered the same way AC 10 of `4-6` already delivers a no-op (no retarget
   request sent).
3. A purely vertical flick is a no-op — cycling is horizontal-only.
4. `_gather_flick_candidates` must expose the CURRENT target's screen X as the cycling anchor.
   TODAY it EXCLUDES the current target from the candidate list entirely — the exclusion code is
   at `match_runner.gd:1887-1889`, and its doc comment at `:1870-1871` names the reason ("THE
   CURRENT TARGET IS EXCLUDED, which is what makes a flick a SWITCH") — that exclusion must be
   revisited so the anchor is available without the current target being returned as its own pick.
5. If the CURRENT target's screen position is `null` (`_screen_position`,
   `match_runner.gd:1904-1913`, behind the camera or outside the viewport rect — the anchor has
   nothing to be adjacent to), a flick is a no-op, delivered the AC 2 way: standing lock unchanged,
   no retarget request sent. Mirrors the already-coded hero-anchor guard
   (`match_runner.gd:1849-1851`). Operator ruling `4-6a/R1` (decision-log, 2026-08-31); the click
   remains the only route back to an off-frame opposing hero (`CC/R3`).
6. The horizontal/vertical boundary: a flick is horizontal, and eligible to cycle, when
   `abs(x) > abs(y)`; otherwise it is the AC 3 vertical no-op. Within the horizontal case, the SIGN
   of `x` picks the cycling direction (screen and stick share the +Y-down convention,
   `controller.gd:43`). The threshold constant that gates the flick at all (AC 8) stays dev-pass
   terrain; this is the rule that decides which axis a given flick belongs to.
7. Among candidates on the flick side (smallest screen-X DISTANCE from the anchor, in the flicked
   direction), that smallest distance wins; on an EQUAL screen-X distance, the LOWER board-index
   candidate wins — the same total order `_gather_flick_candidates` already gathers in
   (hero-then-units, board-index order, `4-3b/R5`), carrying forward the tie-break the replaced
   resolver enforced (`lock_on_resolver.gd:40-44`).
8. `flick_threshold` (`gamepad_profile.gd:56`, `0.7`) is UNCHANGED — the smoke named it no retune
   signal (`story_notes`, `sprint-status.yaml:121`, "flick_threshold 0.7 felt right at the smoke,
   no retune signal"). Not reopened.
9. `test/state/test_lock_on.gd`'s three pick tests (`test_the_flick_picks_the_best_aligned_candidate`,
   `test_the_flick_breaks_an_alignment_tie_on_screen_proximity`,
   `test_the_flick_finds_nothing_outside_its_cone`), plus
   `test_a_candidate_on_top_of_the_hero_is_skipped` (`:262-266`, whose subject moves from the hero
   anchor to the current-target anchor under the new contract), plus mutation row M-G in `4-6`'s
   Dev Agent Record ("remove the resolver's proximity tie-break") are REWRITTEN for the new
   contract — cone/alignment/proximity assertions no longer describe the resolver.

**(b) Camera smoothing on lock/retarget transitions**

10. Camera transitions smooth on lock and retarget (operator ruling, playtest-log 31.8. item 6:
    "flick radi ali cini mi se da je pre grub/nagao ... trebalo bi ga svakako smoothati" —
    typo-corrected from the log's "nagaoa"). The curve/mechanism is an Open Question, not decided
    here.
11. NAMED CENTRAL DESIGN SURFACE (`story_notes`, 2026-08-31): at runner step 1c
   (`match_runner.gd:1949-1968`) ONE computation, `_lock_direction(slot)`
   (`match_runner.gd:1812-1825`), feeds BOTH consumers today — `_p1_rig.face_lock_direction()` /
   `_p2_rig.face_lock_direction()`, whose yaw becomes the pushed camera basis
   (`match_runner.gd:2001-2004` -> `MatchState.set_camera_basis`) and therefore the HASHED
   `HeroState.velocity` (`4-6/R2`); and `_match_state.set_lock_direction()`
   (`match_runner.gd:2010-2013`), the facing fact gating the INSTANT block arc (`4-6` AC 5,
   `_is_facing`/`block_facing_arc_degrees`). Smoothing the rig-yaw consumer changes a RECORDED
   fact and the live movement mapping — `4-6/R2`'s own precedent, a non-identity basis moves
   `world_dir`. The facing/block consumer must stay INSTANT (block arc is gameplay). This story's
   job is to name the split as required; which computation is smoothed, and how the two consumers
   stop sharing one `lock_dirs` value, is Open Question 2, not decided here.
12. Whatever mechanism is chosen must not add a second `_physics_process` (F1) and must not disturb
    `_lock_direction`'s `Vector2.ZERO` "no fact" semantics for the facing consumer (`4-6` AC 2,
    Dev Notes).

**(c) Locked-target marker**

13. An on-screen marker renders on the current locked target (operator ruling, playtest-log 31.8.
    item 6: "svakako bi dodao marker tockicu na neprijatelju koji je trenutno targetan kako i je u
    elden ringu / dark soulsu / sekiru" — typo-corrected from the log's "neprijatlelju"). Pure
    presentation UI. `HudRoot`'s own documented pattern
    draws a line between corner-anchored, own-tempo panels (vitals, hand row, deck count —
    `hud_root.gd`'s "Focal / Periphery" doc comment) and WORLD-SPACE cues, which `2-4/R12` rules
    are explicitly NOT `HudRoot` elements (the P4 telegraph cue). The marker tracks a moving
    world target, so whether it is a `HudRoot`-owned Control (screen-projected via `unproject`,
    the pattern `_screen_position` at `match_runner.gd:1904` already implements) or a separate
    world-space node is Open Question 3 — but under EITHER answer, the marker must be visible only
    in its OWNING slot's viewport (P1's marker never renders in P2's view or vice versa). A
    `HudRoot`-owned Control satisfies this by construction (`hud_root.gd:4-6`, one instance per
    SubViewport). If the world-space branch is taken instead, `main.tscn`'s two SubViewports today
    share one root `World3D` (neither declares `own_world_3d`; no `cull_mask` exists in the file),
    so a world-space marker node needs its own cull-mask/layer discipline to stay per-viewport —
    named here as an obligation on that branch, not as a precedent (`2-4/R12`'s carve-out
    classifies the world-space cue as a category; it never built one, so there is no implemented
    pattern to follow).
14. The marker follows whichever candidate is currently locked (hero or unit), matching
    `PlayerState.lock_target_slot`/`lock_target_index` each tick, and relocates or clears on the
    same tick the lock already snaps under `4-6/R4`/`4-6/R5` (locked-unit death; round-over
    freeze) — no additional lag beyond whatever this story's own render path adds.

**Replay and tier**

15. The replay contract stays UNTOUCHED (`CC/R5`): the record still carries only the resolved
    retarget OUTCOME (`intent.retarget_slot`/`retarget_index`, captured immediately before
    `_recorder.capture_advance`, per `4-6`'s Dev Agent Record "AC 11's replay claim"). Cycling (a)
    changes WHICH address the resolver picks, not how the pick reaches the record or how a replay
    consumes it — no change to `intent_recorder.gd`, `record_file.gd`, or `FORMAT_VERSION`
    (currently 6) is implied by (a) alone. Whether smoothing (b) needs a new hashed/unhashed
    record channel depends entirely on which side of AC 11's split it lands on — Open Question 5.
16. Tier is expected B by the golden clause: cycling (a) and the marker (c) are presentation code
    outside `src/state/`, touching neither the golden nor the snapshot key set if scoped
    correctly. RISK NAMED, not resolved: if smoothing (b) is implemented on the value reaching
    `set_camera_basis`/the rig, it lands on the exact live-basis path `4-6/R2` already proved
    moves `world_dir` and the hashed velocity — any measured golden move demotes this story to
    Tier A immediately, per the golden clause's own "fixed at the gate, may be raised, never
    lowered" rule (`CLAUDE.md` Story tiers). Prediction and escalation mechanism: see Golden
    Prediction section below. The gate (and, if Tier B holds, the dev pass) must
    measure golden + snapshot key set before/after, per Tier B's own discipline.

## Golden Prediction (inverse form -- this is the Tier B escalation clause)

**Prediction: the golden hash and the 28-key snapshot set do NOT move.** Both are measured, not
assumed, per Tier B's "golden clause is decisive" rule (`E4-P/R9`).

- **Golden hash, authoritative source:** `test/state/test_determinism.gd:678`,
  `const GOLDEN := "aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f"`, asserted at
  `:1076`. Recorded at HEAD `60b95d3` (gate baseline), before this story's dev pass, as the BEFORE
  value.
- **Snapshot key set, authoritative source:** `test/state/test_card_observation.gd` and
  `test/state/test_draw_delay_and_reshuffle.gd:349`, the same pinned key set `4-6` left unmoved.
  Recorded at HEAD `60b95d3` as the BEFORE set.

**The escalation clause itself:** the dev pass runs the full suite before touching any file and
after the diff is complete, and records both values in the Dev Agent Record. If either differs
from the BEFORE value recorded here, STOP and escalate — do not re-baseline, do not proceed as
Tier B (AC 16). This is not hypothetical: AC 11 names the exact live-basis path `4-6/R2` already
proved moves the hash if smoothing lands on it.

## Live Smoke

Per `PROC/R8` (applies to both tiers): any AC hinging on on-screen legibility goes to operator
smoke at first render, before any further machine pass on that surface. Three surfaces qualify —

- **The marker (AC 13/14):** does the dot read as marking the correct enemy, at first render.
- **The smoothing feel (AC 10):** the operator's own verdict — "pre grub/nagao" resolved or not —
  no machine test can return this.
- **Cycling on a bunched-up board:** the stacked-approach case from playtest-log 31.8. item 11
  that motivated AC 7's tie-break, exercised live once the tie-break is implemented.

Record all three in `docs/playtest-log.md` by the operator's own hand.

## Budget (`PROC/R7`)

This story states its own budget, being materially larger than `4-B1`'s ~1 h baseline: 16 ACs,
three surfaces (resolver algorithm, camera smoothing, marker node), five Open Questions. Budget:
**~3 h**, counted as dev pass plus code review agent-side wall clock (operator smoke, browser
ruling turns, and close-out doc/commit work excluded, per `PROC/R7`'s own accounting). TRIPWIRE: on
crossing the budget, STOP AND REPORT the remaining work to the operator — never push through.
Scaling the work down is the operator's call.

## Non-Goals

- `flick_threshold` retuning — smoke verdict was no signal (AC 8); not reopened here.
- Off-screen telegraph legibility, the `4-6` Non-Goal (sound-only warning) — unrelated, untouched.
- `TargetingService`'s evaluator — not reused, not touched, same boundary `4-6`'s Non-Goals drew.
- No wrap-around and no vertical cycling — explicit ruling, restated here for the dev pass (AC 2,
  AC 3).
- `InputIntent.aim`'s retirement (`4-6` OQ 2, DELETED) is not reopened or repurposed here.
- Right-stick CLICK / instant re-lock onto the opposing hero (`CC/R3`, `4-6` AC 9) is unchanged —
  this story touches the FLICK's candidate pick only. AC 1 supersedes CC/R3's flick clause itself
  ("best on-screen candidate in that screen-space direction"); the click clause is what survives.
  Recorded in the decision-log as `4-6a/R1`'s companion supersession note.

## Dev Notes

- **Baseline measured for this story (repo, before any change):** HEAD
  `3af5cacea972be3a5298805bb4b2885f03abf383` == `origin/main`, clean tree, then re-measured at HEAD
  `60b95d3` (this story's own authoring commit): `4-6`'s closing numbers DO hold — 565 state /
  4370 assertions / 0 failed, 44 integration all PASS, golden `aa3566d7...` reproduces. Re-run
  `bash test/run_all.sh` fresh at dev-pass start regardless and record actual counts as the
  authoritative BEFORE.
- **`LockOnResolver.best_candidate`'s current interface** (`src/main/lock_on_resolver.gd`): parallel
  `Array[Vector2]` of candidate screens plus a `hero_screen` anchor and a `flick` direction, returns
  an index or `-1`. Whether that SIGNATURE survives the algorithm swap (anchor becomes the current
  target's screen position rather than the hero's; selection becomes "adjacent by screen X" rather
  than "best aligned within a cone") is Open Question 4 — a dev-pass call, not decided here.
- **`_gather_flick_candidates`'s current exclusion** (`match_runner.gd:1877-1897`) builds
  `candidates` from the opposing hero plus living units, then drops the CURRENT lock's address
  before returning `addresses`/`screens`. The anchor this story needs is exactly the position that
  drop discards — the dev pass must expose it (e.g. compute it once, alongside, without adding it
  back into the pickable set) rather than re-including it and filtering post-hoc in the resolver.
- **Camera-smoothing tension, restated with its full citation chain:** step 1c
  (`match_runner.gd:1949-1968`, comment "ONE COMPUTATION, TWO CONSUMERS") computes `lock_dirs` once
  per tick and feeds the rig yaw (`face_lock_direction`, writing the rig ROOT's `rotation.y` at
  `camera_rig.gd:73` — NOT consumed by `apply_config`'s child camera, which owns only the authored
  distance/height/pitch framing, `camera_rig.gd:55-58`) and the state-facing push
  (`set_lock_direction`, `match_runner.gd:2010-2013`) from the same value, in that documented
  order, because "the rig yaw
  is what MAKES the basis non-identity" and a push above that line would ship stale orientation
  into hashed movement. Any smoothing that low-pass-filters `lock_dirs` itself would smooth BOTH
  consumers at once, reintroducing the coupling `4-6`'s own AC 2 deliberately broke ("AC 2 breaks
  that coupling for facing only"). The dev pass owns splitting the two reads, not this story.
- **`resolve_flick`/`retarget_flick`** (`gamepad_controller.gd:125-174`, `controller.gd:38-49`)
  stay structurally unaffected: still an edge-triggered unit screen-space `Vector2`. Cycling
  changes what the RUNNER does with it (left/right against the anchor's screen X, not an alignment
  scan) — no change to the controller layer or `GamepadProfile`'s authored fields.
- **Marker placement precedent:** `_screen_position` (`match_runner.gd:1904-1913`) already
  unprojects a world point into a slot's own viewport, `null` when off-screen — the operation the
  marker needs every tick. `HudRoot` already receives per-tick plain-value pushes outside any
  signal (`set_card_selection`, `match_runner.gd:1937-1938`, `3-5a` AC 10) — candidate pattern IF
  the marker is `HudRoot`-owned; `2-4/R12`'s world-space carve-out is the candidate pattern if not
  (Open Question 3).
- **Replay untouched, per `4-6`'s Dev Agent Record:** `_resolve_retarget` runs immediately before
  `_recorder.capture_advance(intents)`, live-branch only — the record carries the gesture's
  OUTCOME; scope (a) does not change that seat or the replay fork.
- **Anchor-lift asymmetry (review M1/M3):** the flick's cycling anchor is projected from the
  post-review lifted mark position while every other candidate is still projected from the actor
  root, an accepted screen-X asymmetry of at most a fraction of a pixel that only matters in the
  sub-pixel near-tie case named at M3 — not fixed here, since fixing it means lifting every
  candidate too, a wider surface than this story needs.
- **`lock_yaw_smoothing = 0.0` warning (review M5):** an authored 0.0 is not a safe "no smoothing"
  value — it freezes both the camera yaw and the camera-relative movement basis at the first
  heading for the whole match, so never author it; 1.0 is the correct instant-snap value.

### Project Structure Notes

- `LockOnResolver` stays a pure static helper beside the runner (`src/main/`), unchanged location
  — only its algorithm changes, per `4-6`'s own Project Structure Notes precedent (no new folder).
- Camera smoothing and the marker are presentation: under `src/actors/hero/` (rig-adjacent, if the
  smoothing lives on the rig), `src/controllers/` (if the smoothing lives on the runner's read of a
  controller-provided value), or `src/ui/hud/` (if the marker joins `HudRoot`) — never
  `src/state/`. No new top-level folder is implied by anything measured above.

### Project Context Rules

- F1: exactly one `func _physics_process` in `src/`, in `match_runner.gd` — smoothing/marker
  presentation nodes must not add a second.
- D3(a): `Input.*` only under `src/controllers/` — unaffected by this story; no new input reads.
- D3(b)/A2: no global RNG / `Time` / `OS` / `Engine`, and no live scene/camera query, inside
  `src/state/` — this story's changes are presentation-side by construction (a) and (c); (b) must
  be checked against this boundary once its mechanism is chosen (Open Question 2).
- Docs and code never share a commit; commit messages are pure ASCII via `git commit -F`; shell is
  PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Story tier: expected B by the golden clause, fixed at the gate — see AC 16 and the Golden
  Prediction section for the named demotion risk. May be raised, never lowered, mid-story
  (`CLAUDE.md` Story tiers).
- `PROC/R1`: two full suite runs (dev-pass start and end). `PROC/R2`: two-layer review, with a
  mandatory layer-completion line and a Dev Agent Record evidence audit. `PROC/R3`: use the Edit
  fallback on em-dash/tab-bearing files — this story's own artifacts qualify. `PROC/R4`: exactly
  three browser bookends. `PROC/R7`: the budget tripwire — see Budget section above. `PROC/R8`:
  legibility claims route to operator smoke — see Live Smoke section above.

### References

- [Source: sprint-status.yaml, `4-6a-camera-feel` `story_notes` (2026-08-31), line 121] — the
  operator's three ruled pieces (a)/(b)/(c), `flick_threshold` no-retune verdict, board ordering.
- [Source: 4-6-camera-lock-on.md, Status `done`] — shipped ACs 1-14, Dev Agent Record (Open
  Question decisions, golden ladder, mutation table, File List) for every mechanism this modifies.
- [Source: decision-log.md, `CC/R1`-`CC/R6` (2026-08-30)] — controls model (`CC/R3`, superseded in
  its flick clause only by AC 1, see `4-6a/R1`'s companion note), delegated-mechanism precedent
  (`CC/R5`) this story's Open Questions follow.
- [Source: decision-log.md, `4-6/R1`-`4-6/R7` (2026-08-30)] — camera-yaw scope, the live-basis
  second golden cause (`4-6/R2`), the D3(b)/A2 mechanism (`4-6/R6`) smoothing must not violate.
- [Source: decision-log.md, `4-6a/R1` (2026-08-31)] — the null-anchor no-op ruling (AC 5) and its
  companion `CC/R3` supersession note.
- [Source: docs/playtest-log.md, entry `31.8.`] — the operator's own words: cycling behavior
  question (item DODATNO), smoothing verdict and marker request (item 6). The `flick_threshold`
  non-finding (AC 8) is sourced from `sprint-status.yaml:121` `story_notes`, not this log.
- [Source: src/main/lock_on_resolver.gd] — current cone/proximity pick being replaced (AC 1);
  `:40-44`, the tie-break AC 7 carries forward.
- [Source: src/main/match_runner.gd:1812-1825, 1836-1913, 1949-2013] — `_lock_direction`,
  `_resolve_retarget`, `_gather_flick_candidates`, `_screen_position`, and the step-1c seat.
- [Source: src/controllers/gamepad_controller.gd:125-174, src/controllers/controller.gd:38-49,
  src/controllers/gamepad_profile.gd:56] — flick edge/threshold, structurally unaffected.
- [Source: src/ui/hud/hud_root.gd:1-40, 1930-1938 in match_runner.gd] — HUD construction pattern,
  per-tick plain-value push precedent (`set_card_selection`), and the `2-4/R12` world-space
  carve-out the marker's placement question turns on.
- [Source: src/main/main.tscn:37-57] — the two SubViewports AC 13's per-viewport marker claim
  measures against (no `own_world_3d`, no `cull_mask`, one shared `World3D`).
- [Source: test/state/test_lock_on.gd:220-290] — the three pick tests, the hero-anchor skip test
  (`:262-266`), and edge/click tests this story rewrites vs. leaves alone.

## Open Questions

1. **Cycling anchor exposure.** How `_gather_flick_candidates`/`LockOnResolver` expose the current
   target's screen X as an anchor without it re-entering the pickable set — dev-pass call.
2. **Smoothing mechanism, curve, and the step-1c split** (AC 10-12) — this story's central design
   surface: which of the two `lock_dirs` consumers gets smoothed, and how they stop sharing one
   computed value. Not decided here.
3. **Marker node type and ownership** — a `HudRoot`-owned screen-projected Control (following
   `set_card_selection`'s push pattern) vs. a separate world-space node (following `2-4/R12`'s
   carve-out) — dev-pass call.
4. **`LockOnResolver.best_candidate`'s signature** — whether the parallel-array/index-return shape
   survives the algorithm swap, or a screen-X-sorted shape fits the new pick better — dev-pass call.
5. **Whether smoothing needs a new record channel** — entirely dependent on Open Question 2's
   answer; a rig-only smooth likely stays inside the existing camera-basis seam, a facing-side
   smooth would be a new finding requiring its own measurement.

## Tasks / Subtasks

- [x] (a) Expose the current-target screen-X anchor (OQ 1); swap `LockOnResolver.best_candidate`'s
      algorithm (AC 1, AC 5-7); rewrite the affected tests (AC 9).
- [x] (b) Resolve OQ 2 (smoothing mechanism, curve, step-1c split); implement, respecting AC 12.
- [x] (c) Resolve OQ 3 (marker node type); implement the marker (AC 13-14).
- [x] Measure golden + snapshot key set before/after (Golden Prediction section, AC 16); operator
      smoke on the three Live Smoke surfaces before further machine passes on them.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`. Dev pass executed by
Claude Opus 5 via `gds-dev-story` (2026-08-31).

### Debug Log References

Full dev-pass log: `C:\dev\_46a-dev.md`. Suite captures: `C:\dev\_46a_logs\suite_before.txt`,
`C:\dev\_46a_logs\suite_after.txt`.

### Open Question decisions (all five, decided in this pass)

**OQ 1 -- cycling anchor exposure. `_gather_flick_candidates` RETURNS the anchor.** Its signature
becomes `-> Variant`: it still fills `addresses`/`screens` as out-parameters and still skips the
current target when filling them (AC 4's exclusion is unchanged in effect), and it now computes the
current target's screen position on its own line and returns it. Returning it rather than adding a
third out-parameter is what keeps "the anchor is not a candidate" true BY CONSTRUCTION -- there is
no array it could accidentally be appended to. Returns `null` when there is no anchor, which the
caller turns into AC 5's no-op.

**OQ 2 -- smoothing mechanism and the step-1c split. Smoothed INSIDE `CameraRig`, on the rig's own
`rotation.y`; the runner is untouched.** The split AC 11 requires is made by OWNERSHIP rather than
by a second runner variable: step 1c still computes ONE raw `lock_dirs` value per slot,
`_match_state.set_lock_direction` still receives it untouched and INSTANT (the block arc keeps zero
lag, AC 11), and `face_lock_direction` eases toward it using state it keeps itself. The two
consumers stop sharing a value because one of them now has memory -- the runner never had to learn
that smoothing exists. Curve: a per-tick `lerp_angle` toward the target bearing by an authored
fraction (`CameraConfig.lock_yaw_smoothing`, authored 0.25). Per TICK, not per second, which is why
no `delta`, `Time` or `Engine` is read and no second `_physics_process` appears (F1, AC 12).
`Vector2.ZERO` still returns early untouched (AC 12). The FIRST heading a rig receives snaps whole
(a rig with no heading has nothing to ease from; easing from scene-zero would swing the camera
across the arena at match start -- and would break `4-6`'s own frame-5 framing check, proven by
mutation M-L below).

**OQ 3 -- marker node type. A `HudRoot`-owned `Control` (a fully-rounded `Panel`), NOT a
world-space node.** AC 13 required per-viewport visibility under either branch, and this branch
delivers it by construction (one `HudRoot` per SubViewport, each handed only its own slot's point).
The world-space branch would have needed fresh cull-mask/layer discipline invented for it, because
`main.tscn`'s two SubViewports share one root `World3D` -- machinery whose only job would be to
re-establish a property this branch cannot lose. Pushed per tick by the runner as a plain value,
the `set_card_selection` pattern (`3-5a` AC 10): no signal, no state handle, no new `connect_*`, so
the observation-seam family stays at EIGHT.

**OQ 4 -- resolver signature. The parallel-array/index-return SHAPE survives; the NAME does not.**
`best_candidate` -> `adjacent_candidate`, and `hero_screen` -> `anchor`. The shape is what keeps the
function a pure geometric pick that never learns what an address is, so it was kept. The name was
not: there is no ranking left to be "best" at, and a stale name on a replaced algorithm is how a
reader ends up trusting a cone that is no longer there. `MIN_ALIGNMENT` is deleted.

**OQ 5 -- record channel. NONE needed, and none added.** The smoothing lands on the rig yaw, which
reaches state only through the pushed camera basis -- already captured and replayed by
`capture_set_camera_basis` since `3-0c` AC 8. A recording made with smoothing replays bit-for-bit
through the existing channel. `intent_recorder.gd`, `record_file.gd` and `FORMAT_VERSION` (6) are
untouched, so AC 15 holds in full.

### Golden Prediction verdict: HELD -- both values measured, neither moved

| Value | BEFORE (measured, dev-pass start) | AFTER (measured, diff complete) |
| --- | --- | --- |
| Golden hash | `aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f` | `aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f` |
| Snapshot key set | 28 keys, `EXPECTED_PLAYER_SNAPSHOT_KEYS` | 28 keys, unchanged (`git diff` on both owning test files is EMPTY) |
| State suite | 565 tests / 4370 assertions / 0 failed | 566 tests / 4377 assertions / 0 failed |
| Integration | 44 files, all PASS | 46 files, all PASS (2 added) |
| `run_all.sh` exit | 0 | 0 |

The hash is not merely unedited, it REPRODUCES: `test_determinism.gd`'s assertion at `:1076` passed
in both full runs. **No escalation triggered; the story stays Tier B.** The structural reason the
AC 16 risk did not fire: nothing under `src/state/` was touched at all (see File List), and the
golden fixture has no runner in it -- it pushes its own bases -- so a rig-side smooth cannot reach
it. The LIVE consequence `4-6/R2` names is real and is documented rather than avoided: a smoothed
rig basis means camera-relative movement follows the smoothed camera during a transition. That is
what cameras do; the alternative (movement snapping to a heading the player cannot see yet) is the
actual defect. It moves no recorded semantics.

### Mutation-proof table

Provenance: every row was run in THIS pass, against the full state harness or the named integration
file. Targets were backed up to the scratchpad with SHA256 BEFORE mutating and restored by COPY,
never `git checkout`, per the standing discipline -- all four post-restore hashes verified identical
to their pre-mutation values.

| Row | Mutation | Caught by | Result |
| --- | --- | --- | --- |
| **M-G** (re-derived; replaces `4-6`'s "remove the resolver's proximity tie-break", whose subject no longer exists) | tie-break strictness `gap < best_gap` -> `gap <= best_gap` (higher index wins the tie) | `test_the_cycling_tie_breaks_on_the_lower_board_index` | 1 failed |
| M-H | adjacency direction `gap < best_gap` -> `gap > best_gap` (furthest instead of adjacent) | `test_the_flick_cycles_to_the_adjacent_candidate_by_screen_x` | 1 failed |
| M-I | direction filter `gap <= 0.0` -> `gap < 0.0` (co-X candidates become reachable both ways) | `test_a_candidate_on_the_anchors_own_screen_x_is_not_reachable` | 1 failed |
| M-J | horizontal rule `absf(x) <= absf(y)` -> `<` (an exact diagonal cycles) | `test_a_vertical_or_diagonal_flick_never_cycles` | 1 failed |
| M-K | smoothing removed entirely (always snap) | `test_camera_smoothing_live.gd` | FAIL |
| M-L | first-heading snap removed (ease from scene-zero) | `test_camera_smoothing_live.gd` AND `test_lock_on_live.gd` (4-6's own framing check) | FAIL, both |
| M-M | `lerp_angle` -> `lerpf` (wrap taken the long way round) | `test_camera_smoothing_live.gd` | FAIL, landed at 1.500 rad instead of 3.071 |
| M-N | marker centring offset dropped (`- LOCK_MARKER_SIZE * 0.5`) | `test_lock_marker_live.gd` | FAIL, off by 9.9 px |
| M-O | marker push made one-shot (the runner's per-tick re-push deleted) | `test_lock_marker_live.gd` | FAIL |

### Named gaps and findings

1. **AC 5's null-anchor no-op is covered by INSPECTION, not by a machine test.** The guard lives in
   `_resolve_retarget`, a runner private with no seam; staging "the current target is behind this
   slot's camera" in the live scene means fighting the always-locked camera that exists to prevent
   exactly that. The resolver-side tests deliberately do NOT cover it either, and say so: only the
   CALLER can tell "no anchor" apart from "no candidate". Flagged rather than papered over.
2. **AC 7's wording is ambiguous and was implemented on its operative reading.** Read literally
   ("two candidates share the CURRENT TARGET's screen X"), both such candidates have zero offset
   from the anchor, are excluded by the strict direction filter, and the tie-break would be
   unreachable -- a vacuous AC. It is implemented on the reading that is both non-vacuous and
   mechanically sound: candidates at the same screen-X DISTANCE from the anchor tie, and the lower
   board index wins. That is the operative content the guardrail names ("lower-board-index
   tie-break") and it is the bunched-board case from playtest-log 31.8. item 11. Recorded for the
   operator; no ruling reopened.
3. **A marker "it moves when you walk" assertion would have been vacuous, and was not written.**
   Measured, not assumed: under `CC/R2`'s always-locked camera the rig yaws to frame the target, so
   forty frames of sideways sprint moved the marker 1.1 px -- inside the test's own noise band. The
   per-tick liveness claim is made the strong way instead (clear the marker directly, then prove the
   runner restores it correctly on the very next tick; mutation M-O).
4. **`CameraConfig.lock_yaw_smoothing` defaults to 1.0, breaking that file's "defaults are zero on
   purpose" doctrine, deliberately.** Zero here would mean "the camera never turns", which is not a
   conspicuously-wrong default but a broken game that looks like a deliberate one; 1.0 degrades to
   the shipped 4-6 snap. The reasoning is stated at the field.

### Live Smoke -- HANDED OFF, not iterated on (`PROC/R8`)

Three surfaces are the operator's and were left to the operator once the mechanics were
machine-proven: the **marker's legibility** at first render (size/colour/placement -- a 14 px bone
dot with a dark rim, `HudRoot.LOCK_MARKER_SIZE`), the **smoothing feel** (is "pre grub/nagao"
resolved at `lock_yaw_smoothing = 0.25`? -- a one-line `data/camera_config.tres` edit retunes it,
with no code and no test change), and **cycling on a bunched board**. Record all three in
`docs/playtest-log.md` by the operator's own hand.

### Post-review micro-fixes

Two live-smoke-driven commits made after code review APPROVE, both presentation-only:

- **854c0d4** — lock marker lifted onto the target's body by half the authored body box (unit
  0.6, totem 0.7, hero 0, unchanged). Smoke verdict: hero and totem read right; the minion marker
  sat at crotch height, too low.
- **3a2ecc4** — minion (unit) lift re-derived from the measured skinned-model AABB (~2.062 m real
  height), marker now at ~3/4 of that from the ground (`LOCK_MARK_UNIT_LIFT = 1.53`); totem and
  hero left unchanged by operator ruling (both already read correctly). Marker additionally hidden
  during the round-over freeze, via the existing `round_over` snapshot key; `test_lock_marker_live`
  extended to cover it.

Both fixes are presentation-only: `src/state/` untouched, golden `aa3566d7...` and the 28-key
snapshot set both measured unmoved, suite `566/4377/0` + 46 integration files, all PASS.

**Recorded deviation from `PROC/R1`:** this v2 pass ran the full suite THREE times (baseline run
twice — the first capture was truncated — then once after the diff), not exactly twice as `PROC/R1`
states. Named rather than silently absorbed.

### Live Smoke Results (2026-08-31 / 2026-09-01, pad on P2, flip [0,3])

All three `PROC/R8` feel surfaces PASS: yaw smoothing at `lock_yaw_smoothing = 0.25` reads as
resolved ("pre grub/nagao" no longer applies), adjacent left/right cycling on a bunched pile reads
correctly, and `4-6a/R1`'s relock-from-off-frame no-op holds at the stick. The marker v2 lift
(3a2ecc4) confirmed correctly placed on minion, totem, and hero; the round-over hide (also 3a2ecc4)
confirmed.

**Deferred, non-blocking:** the marker dot drifts slightly outside the minion's silhouette during
the walk gait, because the lift is a fixed offset while the animated body moves under it. A
bone-attached marker is the obvious future fix; not pursued here (presentation polish, not an AC).

### Completion Notes List

- All 16 ACs implemented; all four tasks complete. `src/state/` untouched -- Tier B holds, measured.
- No new `class_name` was introduced (both `LockOnResolver` and `CameraConfig` already existed), so
  no editor class-cache scan and no `project.godot` collateral check was needed; `project.godot` is
  unmodified.
- Invariants re-checked at close: **F1** -- `grep -rn "func _physics_process" src/` returns exactly
  one hit, in `match_runner.gd`. **D3(a)** -- the only `Input.` hits outside `src/controllers/` are
  two doc comments in `match_runner.gd` (`:117`, `:1961`), both pre-existing. **D3(b)/A2** -- zero
  RNG / `Time` / `OS` / `Engine` hits in `src/state/`.
- Replay contract untouched (AC 15): no change to `intent_recorder.gd`, `record_file.gd` or
  `FORMAT_VERSION`.
- `flick_threshold` (0.7) untouched (AC 8); the controller layer and `GamepadProfile` are unmodified.

### File List

Modified:
- `src/main/lock_on_resolver.gd` -- cone/proximity pick REPLACED by adjacent-by-screen-X cycling;
  `best_candidate` -> `adjacent_candidate`, `MIN_ALIGNMENT` deleted (AC 1-3, AC 6, AC 7).
- `src/main/match_runner.gd` -- `_gather_flick_candidates` returns the anchor (AC 4); the
  hero-screen guard replaced by the null-anchor no-op (AC 5); new `_lock_target_screen_position`
  helper shared by the anchor and the marker; new step 4d marker push (AC 13, AC 14).
- `src/actors/hero/camera_rig.gd` -- per-tick `lerp_angle` yaw smoothing with a first-heading snap
  (AC 10-12); reads the authored rate in `apply_config`.
- `src/actors/hero/camera_config.gd` -- new authored `lock_yaw_smoothing` field.
- `data/camera_config.tres` -- authored `lock_yaw_smoothing = 0.25`.
- `src/ui/hud/hud_root.gd` -- `LOCK_MARKER_SIZE`, `_lock_marker`, `_build_lock_marker()`,
  `set_lock_marker()` (AC 13, AC 14).
- `test/state/test_lock_on.gd` -- the four pick tests REWRITTEN for the cycling contract; five tests
  replace four (AC 9).

Added:
- `test/integration/test_camera_smoothing_live.gd` -- the smoothing MECHANISM (AC 10-12).
- `test/integration/test_lock_marker_live.gd` -- the marker's per-viewport, on-target, hide and
  per-tick-liveness claims (AC 13, AC 14).

Not modified, stated because a reader would reasonably expect otherwise: `src/state/**` (nothing at
all), `project.godot`, `src/controllers/**`, `intent_recorder.gd`, `record_file.gd`,
`test/state/test_determinism.gd`, `test/state/test_draw_delay_and_reshuffle.gd`,
`test/state/test_card_observation.gd`.

## Change Log

| Date | Change |
| --- | --- |
| 2026-08-31 | Dev pass via `gds-dev-story`. All 16 ACs implemented; OQ 1-5 decided and recorded. Golden Prediction HELD -- golden `aa3566d7...` and the 28-key snapshot set both measured unmoved before and after; Tier B stands, no escalation. Suite 565/4370 -> 566/4377 state, 44 -> 46 integration, 0 failed throughout. Nine mutation rows including the re-derived M-G. Status -> `review`; the three Live Smoke surfaces are handed to the operator. |
