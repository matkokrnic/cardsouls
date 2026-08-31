---
baseline_commit: 3af5cacea972be3a5298805bb4b2885f03abf383
---

# Story 4.6a: Camera Feel

Status: authored

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
   units, board-index order). Operator ruling, `sprint-status.yaml` 4-6a `story_notes`
   (2026-08-31); playtest-log 31.8. item "DODATNO ... shuffle lock on nije samo ljevo desno ...
   nego doslovno vrtis ljevo desno kako su trenutno orjentirani u prikazu".
2. No wrap: a flick past the leftmost/rightmost on-screen candidate is a no-op — the standing lock
   is left unchanged, delivered the same way AC 10 of `4-6` already delivers a no-op (no retarget
   request sent).
3. A purely vertical flick is a no-op — cycling is horizontal-only.
4. `_gather_flick_candidates` must expose the CURRENT target's screen X as the cycling anchor.
   TODAY it EXCLUDES the current target from the candidate list entirely
   (`match_runner.gd:1887-1889`, "THE CURRENT TARGET IS EXCLUDED, which is what makes a flick a
   SWITCH") — that exclusion must be revisited so the anchor is available without the current
   target being returned as its own pick.
5. `flick_threshold` (`gamepad_profile.gd:56`, `0.7`) is UNCHANGED — the smoke named it no retune
   signal (`story_notes`, playtest-log 31.8. item 6, "flick_threshold 0.7 stays"). Not reopened.
6. `test/state/test_lock_on.gd`'s three pick tests (`test_the_flick_picks_the_best_aligned_candidate`,
   `test_the_flick_breaks_an_alignment_tie_on_screen_proximity`,
   `test_the_flick_finds_nothing_outside_its_cone`) plus mutation row M-G in `4-6`'s Dev Agent
   Record ("remove the resolver's proximity tie-break") are REWRITTEN for the new contract —
   cone/alignment/proximity assertions no longer describe the resolver.

**(b) Camera smoothing on lock/retarget transitions**

7. Camera transitions smooth on lock and retarget (operator ruling, playtest-log 31.8. item 6:
   "flick radi ali cini mi se da je pre grub/nagao ... trebalo bi ga svakako smoothati"). The
   curve/mechanism is an Open Question, not decided here.
8. NAMED CENTRAL DESIGN SURFACE (`story_notes`, 2026-08-31): at runner step 1c
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
9. Whatever mechanism is chosen must not add a second `_physics_process` (F1) and must not disturb
   `_lock_direction`'s `Vector2.ZERO` "no fact" semantics for the facing consumer (`4-6` AC 2,
   Dev Notes).

**(c) Locked-target marker**

10. An on-screen marker renders on the current locked target (operator ruling, playtest-log 31.8.
    item 6: "svakako bi dodao marker tockicu na neprijatelju koji je trenutno targetan kako i je u
    elden ringu / dark soulsu / sekiru"). Pure presentation UI. `HudRoot`'s own documented pattern
    draws a line between corner-anchored, own-tempo panels (vitals, hand row, deck count —
    `hud_root.gd`'s "Focal / Periphery" doc comment) and WORLD-SPACE cues, which `2-4/R12` rules
    are explicitly NOT `HudRoot` elements (the P4 telegraph cue). The marker tracks a moving
    world target, so whether it is a `HudRoot`-owned Control (screen-projected via `unproject`,
    the pattern `_screen_position` at `match_runner.gd:1904` already implements) or a separate
    world-space node is Open Question 3.
11. The marker follows whichever candidate is currently locked (hero or unit), matching
    `PlayerState.lock_target_slot`/`lock_target_index` each tick, and relocates or clears on the
    same tick the lock already snaps under `4-6/R4`/`4-6/R5` (locked-unit death; round-over
    freeze) — no additional lag beyond whatever this story's own render path adds.

**Replay and tier**

12. The replay contract stays UNTOUCHED (`CC/R5`): the record still carries only the resolved
    retarget OUTCOME (`intent.retarget_slot`/`retarget_index`, captured immediately before
    `_recorder.capture_advance`, per `4-6`'s Dev Agent Record "AC 11's replay claim"). Cycling (a)
    changes WHICH address the resolver picks, not how the pick reaches the record or how a replay
    consumes it — no change to `intent_recorder.gd`, `record_file.gd`, or `FORMAT_VERSION`
    (currently 6) is implied by (a) alone. Whether smoothing (b) needs a new hashed/unhashed
    record channel depends entirely on which side of AC 8's split it lands on — Open Question 5.
13. Tier is expected B by the golden clause: cycling (a) and the marker (c) are presentation code
    outside `src/state/`, touching neither the golden nor the snapshot key set if scoped
    correctly. RISK NAMED, not resolved: if smoothing (b) is implemented on the value reaching
    `set_camera_basis`/the rig, it lands on the exact live-basis path `4-6/R2` already proved
    moves `world_dir` and the hashed velocity — any measured golden move demotes this story to
    Tier A immediately, per the golden clause's own "fixed at the gate, may be raised, never
    lowered" rule (`CLAUDE.md` Story tiers). The gate (and, if Tier B holds, the dev pass) must
    measure golden + snapshot key set before/after, per Tier B's own discipline.

## Non-Goals

- `flick_threshold` retuning — smoke verdict was no signal (AC 5); not reopened here.
- Off-screen telegraph legibility, the `4-6` Non-Goal (sound-only warning) — unrelated, untouched.
- `TargetingService`'s evaluator — not reused, not touched, same boundary `4-6`'s Non-Goals drew.
- No wrap-around and no vertical cycling — explicit ruling, restated here for the dev pass (AC 2,
  AC 3).
- `InputIntent.aim`'s retirement (`4-6` OQ 2, DELETED) is not reopened or repurposed here.
- Right-stick CLICK / instant re-lock onto the opposing hero (`CC/R3`, `4-6` AC 9) is unchanged —
  this story touches the FLICK's candidate pick only.

## Dev Notes

- **Baseline measured for this story (repo, before any change):** HEAD
  `3af5cacea972be3a5298805bb4b2885f03abf383` == `origin/main`, clean tree. Run
  `bash test/run_all.sh` fresh at dev-pass start and record actual counts; do not assume `4-6`'s
  closing numbers (565 state / 44 integration) still hold — `4-6` review-fix and playtest-notes
  commits landed after that pass.
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
  per tick and feeds the rig yaw (`face_lock_direction`, consumed by `apply_config`'s child camera
  at `camera_rig.gd:67` onward) and the state-facing push (`set_lock_direction`,
  `match_runner.gd:2010-2013`) from the same value, in that documented order, because "the rig yaw
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
- Story tier: expected B by the golden clause, fixed at the gate — see AC 13 for the named
  demotion risk. May be raised, never lowered, mid-story (`CLAUDE.md` Story tiers).

### References

- [Source: sprint-status.yaml, `4-6a-camera-feel` `story_notes` (2026-08-31)] — the operator's
  three ruled pieces (a)/(b)/(c), `flick_threshold` no-retune verdict, board ordering.
- [Source: 4-6-camera-lock-on.md, Status `done`] — shipped ACs 1-14, Dev Agent Record (Open
  Question decisions, golden ladder, mutation table, File List) for every mechanism this modifies.
- [Source: decision-log.md, `CC/R1`-`CC/R6` (2026-08-30)] — controls model (`CC/R3`),
  delegated-mechanism precedent (`CC/R5`) this story's Open Questions follow.
- [Source: decision-log.md, `4-6/R1`-`4-6/R7` (2026-08-30)] — camera-yaw scope, the live-basis
  second golden cause (`4-6/R2`), the D3(b)/A2 mechanism (`4-6/R6`) smoothing must not violate.
- [Source: docs/playtest-log.md, entry `31.8.`] — the operator's own words: cycling behavior
  question (item DODATNO), smoothing verdict and marker request (item 6), `flick_threshold`
  non-finding (item 6).
- [Source: src/main/lock_on_resolver.gd] — current cone/proximity pick being replaced (AC 1).
- [Source: src/main/match_runner.gd:1812-1825, 1836-1913, 1949-2013] — `_lock_direction`,
  `_resolve_retarget`, `_gather_flick_candidates`, `_screen_position`, and the step-1c seat.
- [Source: src/controllers/gamepad_controller.gd:125-174, src/controllers/controller.gd:38-49,
  src/controllers/gamepad_profile.gd:56] — flick edge/threshold, structurally unaffected.
- [Source: src/ui/hud/hud_root.gd:1-40, 1930-1938 in match_runner.gd] — HUD construction pattern,
  per-tick plain-value push precedent (`set_card_selection`), and the `2-4/R12` world-space
  carve-out the marker's placement question turns on.
- [Source: test/state/test_lock_on.gd:220-291] — the three pick tests and edge/click tests this
  story rewrites vs. leaves alone.

## Open Questions

1. **Cycling anchor exposure.** How `_gather_flick_candidates`/`LockOnResolver` expose the current
   target's screen X as an anchor without it re-entering the pickable set — dev-pass call.
2. **Smoothing mechanism, curve, and the step-1c split** (AC 7-9) — this story's central design
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

## Dev Agent Record

### Agent Model Used

Claude Sonnet 5 (claude-sonnet-5), story authored via `gds-create-story`.

### Debug Log References

### Completion Notes List

### File List
