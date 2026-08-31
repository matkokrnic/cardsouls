---
baseline_commit: 3af5cacea972be3a5298805bb4b2885f03abf383
---

# Story 4.6a: Camera Feel

Status: ready-for-dev

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
7. Tie-break: when two candidates share the current target's screen X exactly, the LOWER
   board-index candidate wins — the same total order `_gather_flick_candidates` already gathers in
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

- [ ] (a) Expose the current-target screen-X anchor (OQ 1); swap `LockOnResolver.best_candidate`'s
      algorithm (AC 1, AC 5-7); rewrite the affected tests (AC 9).
- [ ] (b) Resolve OQ 2 (smoothing mechanism, curve, step-1c split); implement, respecting AC 12.
- [ ] (c) Resolve OQ 3 (marker node type); implement the marker (AC 13-14).
- [ ] Measure golden + snapshot key set before/after (Golden Prediction section, AC 16); operator
      smoke on the three Live Smoke surfaces before further machine passes on them.

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`.

### Debug Log References

### Completion Notes List

### File List

## Change Log
