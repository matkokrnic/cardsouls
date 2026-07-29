# Story 2.6: Legibility and feel validation instrumentation

Status: done

## Story

As a solo developer running playtests,
I want the post-round-over movement freeze fixed, a per-player state inspector, a dodge cue driven off the existing roll telegraph, a variable-analog-magnitude toggle, a Pitch-Zone placement A/B, one stale comment corrected, and a written telegraph-legibility protocol,
so that a match actually stops when a round ends, a playtest can inspect a player's live pools and action state, and HUD/feel variants can be compared without a code edit or a `.tscn` edit.

## Acceptance Criteria

1. **[BLOCKING] Round lifecycle.** `MatchState.advance()` gains a new step 1b, immediately AFTER the existing step-1 debug-reset ingestion and BEFORE step 2 (timer advance): while `_round_over` is true, step 1b returns from `advance()` immediately, skipping steps 2 through 8 for that tick — the surviving hero stops moving once the round is over. The tick counter (`_tick`) still increments every tick, frozen or not, so a reset landing on tick N stays deterministic. Because step 1 (reset ingestion) runs BEFORE the new step 1b, a debug reset and a frozen tick landing in the SAME `advance()` call resume movement resolution that same tick — no hoist of the check ahead of the reset. A new no-argument `round_started` signal is declared on `MatchState` (mirroring `round_ended`) and pushed, queued, unconditionally by `_apply_debug_reset()` on every reset. It is relayed to a new `EventBus.round_started` signal by `match_runner.gd` exactly the way `round_ended` already is (no new per-slot `connect_round_started` runner method — direct wiring in `_ready()`, matching the existing `round_ended` shape). The signal carries NO prime-on-connect: a HUD consumer must receive an actual event, never a value synthesized at connect time. `HudRoot` gains `on_round_started()`, the single CLEAR seat for the round-over label (hiding it); `on_round_ended` remains the single SET seat. Two properties are pinned by new tests, each demonstrated to FAIL under the wrong implementation before being fixed: (a) once `_round_over` is true, no hero's velocity or action state changes on any later tick absent a reset (fails if step 1b is missing); (b) a round-over tick followed by a debug-reset tick resolves movement again on that same reset tick (fails if the round-over check is hoisted ahead of the reset, the ordering R6 forbids); (c) the label-clear guard is proven non-vacuous by first driving it to VISIBLE via `round_ended`, then firing `round_started` and asserting it becomes hidden — not merely asserting the label's untouched initial state.
2. **Per-player state inspector (old AC3, retained, narrowed).** A new `StateInspector`, one instance per `SubViewport` (mirroring `HudRoot`'s per-player construction and wiring), displays: the player's current action-state name (`connect_hero_action_state_changed`), HP/stamina/mana current-and-maximum (the three existing economy seams), and the reason for the player's most recent rejected action (`connect_hero_action_rejected`) — the seven existing observation seams, no eighth. It reads signals only: no state mutation, no `_process`/`_physics_process`, no `.tscn` edit, built in code under `src/ui/debug/`. It does NOT display any active-`TimingWindow` countdown — that capability is DEFERRED to the future rig story; streaming raw window ticks every tick would be a firehose through the D5 queued-drain path and would hand the state layer's internals to presentation.
3. **Dodge cue.** A roll reads visibly as a DODGE: `TelegraphController`'s existing `ActionState -> TelegraphProfile` mapping (story 1-10, `connect_hero_action_state_changed`) carries a distinct roll/dodge shape+sound, not a shared placeholder. No new signal is added anywhere: the contact-resolution iframe drop (`MatchState`, step 4) continues to emit nothing when a hit is negated by `roll_iframe`, and the dodge cue is driven purely by the hero ENTERING `ActionState.ROLLING` — never by whether a hit was actually negated. The mapping stays exactly where it already lives (exported on `TelegraphController`, presentation-side); no state object is touched.
4. **Variable analog magnitude, toggle only.** `GamepadProfile` gains one new authored field, `normalize_move_magnitude: bool = true` — `true` (the shipped default) is today's behaviour: above the deadzone, `GamepadController.resolve_move_dir` normalizes the stick vector to unit length. `false` passes the stick's actual magnitude through, clamped to length 1.0, so a partial deflection yields a partial `move_dir` magnitude instead of binary-speed movement. The switch is flipped at runtime through a new global debug instrument panel (`src/ui/debug/`) that mutates the field directly on the shared `GamepadProfile` resource instance already read fresh every tick by `sample()` — no reload/injection seam is needed. It is NOT a `FeatureFlags` member. The panel mutates the field IN MEMORY ONLY: it never calls `ResourceSaver` and never persists the `.tres` back to disk in any form — a debug switch must not overwrite authored data, and the toggle reverts to the authored default on the next launch. `src/state/` is untouched by this AC: the resulting magnitude lives inside the recorded `move_dir` of the `InputIntent` itself, so replay stays safe with no new recorded field. This AC delivers the toggle only — no verdict on whether variable magnitude feels better is rendered; that judgement is animation-gated and belongs to the future rig story.
5. **Pitch Zone A/B.** The same debug instrument panel gains a second switch that moves BOTH viewports' Pitch Zone placeholder (`HudRoot._build_pitch_zone()`) together between its current dead-centre anchor and a second, left-of-the-vitals-bars anchor. The TOGGLE is SHARED (one switch, not per-player) purely for A/B COMPARABILITY — both viewports must show the SAME candidate placement at once for the comparison across a playtest session to mean anything. This decides NOTHING about whether the eventual Pitch Zone MECHANIC itself is shared between players or owned per-player — that remains OPEN, reserved for E6, and 2-6 does not touch it. The left-of-bars anchor is computed independently of `OpponentHandStrip` (2-5's face-down row): it must not anchor to that row, which is provisional and may be deleted in epic 3. Placeholder geometry only — the pitch state carries no content until E6. This AC delivers the toggle and the FIRST reading only; no verdict on which placement is better is recorded in this story.
6. **Comment hygiene.** Exactly one stale comment is corrected: `test/state/test_contact_resolution.gd`, the `facing updates from raw intent` comment on `test_authored_zero_multiplier_is_full_root_but_facing_untouched` (currently line 225) — inaccurate since the 1-7 review R1 world-space-planar facing decision: facing is derived from the runner's camera-rotated `world_dir`, not literally the raw `InputIntent.move_dir`; this test's zero-rotation fixture only makes the two coincide. No other file is touched for comment hygiene this story — the other stale-comment sites previously suspected were already fixed in commit `843e33a`.
7. **Telegraph legibility protocol (old AC4, retained).** A repeatable legibility procedure — play at half width, sound on, use a naive observer, record whether the action was identified before it resolved — is written into a NEW, separate docs file (not `docs/playtest-log.md`, which only the operator writes by hand). The protocol is run once against E1's existing melee telegraphs (attack/block/roll shapes+stings, story 1-10) as its rehearsal, so it exists and is trusted before E5's colour telegraphs need it.
8. **Live smoke.** The R-D6 live-smoke acceptance is RE-INVOKED by this story: a live two-human smoke on the shipped default configuration (`slot_controller_kinds = [0, 1]`, no manual `.tscn` edit). The smoke specifically exercises Block 1 — a round ends, the surviving hero is observed to STOP moving (confirming the fix; previously it kept moving), a debug reset is issued, the round-over label clears, and the match is observed to CONTINUE (movement resolves again for both heroes). The operator's own `docs/playtest-log.md` entry for 2-6, written by hand before the commit chain begins, is required regardless of whether the smoke produced findings — no agent writes it.

## Tasks / Subtasks

- [ ] **BLOCKING — must land and pass live smoke before any other task is worked.** Add `MatchState.round_started`, the step-1b round-over early return (positioned AFTER the existing reset-ingestion step, never hoisted ahead of it), and push `round_started` unconditionally from `_apply_debug_reset()`; relay it through `match_runner.gd` to `EventBus.round_started` exactly like `round_ended`; add `HudRoot.on_round_started()` as the label's single clear seat (AC: 1)
- [ ] Add the three new-guard tests (fails-without-fix for the early return, fails-under-hoisted-order for the reset interaction, fails-if-vacuous for the label clear) (AC: 1)
- [ ] Build `StateInspector` in `src/ui/debug/`, one per `SubViewport`, wired to the seven existing seams only, no window countdown (AC: 2)
- [ ] Author/confirm a distinct roll/dodge `TelegraphProfile` on `TelegraphController`; verify no new signal is introduced anywhere on the iframe-drop path (AC: 3)
- [ ] Add `normalize_move_magnitude` to `GamepadProfile`; update `GamepadController.resolve_move_dir` to branch on it; build the debug instrument panel and wire its magnitude switch to mutate the shared profile instance directly (AC: 4)
- [ ] Add the instrument panel's second switch moving both viewports' Pitch Zone placeholder between the dead-centre and left-of-bars anchors, independent of `OpponentHandStrip` (AC: 5)
- [ ] Correct the single stale comment in `test/state/test_contact_resolution.gd` (AC: 6)
- [ ] Write the telegraph-legibility protocol into a new docs file; run it once against E1's melee cues (AC: 7)
- [ ] Run the live two-human smoke on the shipped default config, exercising Block 1 explicitly; confirm the operator's hand-written `docs/playtest-log.md` entry exists before the commit chain (AC: 8)

## Dev Notes

- This story is a MERGE, not a replacement, of the original Set-B story (authored 2026-07-22, before any E1/E2 code existed) with the six real defects/gaps found in the shipped E1/E2 code. Old AC3 (per-player inspector) and old AC4 (legibility protocol) survive, narrowed. Old AC1 (FeatureFlags overlay) is narrowed into the debug instrument panel (AC 4/5) — it never touches `FeatureFlags`. Old AC2 (deterministic step/pause) and old AC5 (record/replay + mid-round balance hot-reload) are RE-HOMED out of this story (2-6/R2, R3, below) — see the decision log for this session.
- Block 1 RETIRES two previously-parked named gaps with ONE fix: the 2-3/R10 gap ("post-round-over live match" — the surviving hero keeps moving after the round ends) and the 2-4 close-out MICRO-DECISION 1 (the round-over label survives a debug reset because nothing signals the reset). Both were deliberately left unowned for "the E2 retrospective, ONE owner" — 2-6 is that owner, and both close together because they share one root cause: nothing in the round lifecycle emits a signal on RESET, only on END.
- Golden CANNOT prove Block 1: the recorded determinism sequence never reaches a round-over (P1 ends 108/120 HP, P2 ends 117/120 HP — see `test_determinism.gd`), so Block 1's correctness rests entirely on the new dedicated tests plus the live smoke, never on the golden hash.
- Any guard proven non-vacuous by temporarily removing the fix must be restored from a copy taken OUTSIDE the repo, verified byte-for-byte via SHA256 — never via `git checkout --`, which would wipe the whole uncommitted dev pass (the 2-4/2-5 precedent).

### 2-6/R1 — scope is a merge, not a replacement

Final 2-6 = the six blocks above (round lifecycle, inspector, dodge cue, analog magnitude, Pitch Zone A/B, comment hygiene) plus the per-player inspector (old AC3) and the legibility protocol (old AC4), both retained and narrowed. Old AC1 is narrowed into the instrument panel (2-6/R4). Old AC2 and AC5 leave the story entirely (2-6/R2, R3).

### 2-6/R2 — record/replay re-homed, not deleted

Old AC5 (end-to-end split-screen record/replay via `IntentRecorder`/`ReplayController`, including mid-round balance hot-reload) moves in full to the future story that lands `IntentRecorder` — the story that already inherits the four-field contact-fact contract (1-8's supersession) and the second half of DEBT B (reload events recorded into the intent stream, `decision-log.md` Session 2026-07-22 Story 1-1 close-out). One stream contract, one owner. That story does not exist yet; no story file is created for it here — the re-homing is recorded in the decision log only.

### 2-6/R3 — deterministic step/pause re-homed, not deleted

Old AC2 (pause the runner, advance N fixed ticks) moves to the future animation/rig story. It requires new `project.godot` Input Map actions (a project.godot edit, reviewed per CLAUDE.md), and its value as a debugging tool only arrives once real animations exist to step through. Recorded in the decision log; no story file created here.

### 2-6/R4 — old AC1 narrowed into the instrument panel

The instrument panel (AC 4, AC 5) may flip ONLY presentation-local and controller-local switches — never a `FeatureFlags` member. `FeatureFlags` stays load-once and runtime-immutable (unchanged from its 1-5 injection contract). Reason: flags appear neither in `MatchState.to_snapshot()` nor in the recorded intent stream, so mutating one at runtime would be a silent replay hole — a recorded round could not be reproduced if a flag it depended on had been flipped mid-session and never recorded anywhere.

### 2-6/R5, R6 — round lifecycle: seat, ordering, and the guard shape

Reset visibility ships as `EventBus.round_started` (already anticipated, undeclared, in `event_bus.gd`'s header comment: "match_started, round_started, round_ended"), never `round_reset`, and never a new per-slot runner `connect_` method — it is wired exactly like `round_ended` already is, directly in `match_runner.gd._ready()`. The label's SET (`on_round_ended`) and its CLEAR (`on_round_started`) live at exactly one seat each, both on `HudRoot`. NO prime-on-connect: the label starts hidden, and a primed emission at connect time would make the clear-guard's test pass even if the real hide-on-event wiring were never built — the same shape of vacuous guard the 2-5/R10 styling-direction fix exists to warn against. The step-1b guard sits AFTER step 1 (reset ingestion), never hoisted ahead of it: the tick counter still increments while frozen, and a reset landing on the same tick the round ended must resume movement resolution that same tick, not one tick later.

### 2-6/R7 — no eighth seam

The per-player inspector displays only what the seven existing seams already carry. The active-window countdown from old AC3 is DEFERRED to the rig story: streaming raw `TimingWindow` ticks every tick would be a firehose through the D5 queued-drain path, effectively handing the state layer's internals to presentation.

### 2-6/R8 — variable analog magnitude lives on the gamepad profile, not FeatureFlags

The switch is an authored field on `GamepadProfile` — the same resource that already owns the button mapping and the deadzone — not a `FeatureFlags` member. Replay stays safe because the resulting magnitude is folded into the recorded `move_dir`, never recorded as a separate flag. State code is untouched. No verdict on feel is rendered here; that judgement is animation-gated (rig story).

### 2-6/R9 — Pitch Zone A/B is placeholder-only, and decides nothing about the shared-vs-per-player mechanic

The pitch state carries no content until E6; this AC delivers layout comparison only. The A/B must not anchor to `OpponentHandStrip` (2-5), which is provisional and may be deleted in epic 3. The instrument-panel TOGGLE is shared (one switch moves both viewports together) purely for A/B COMPARABILITY — a meaningful placement comparison needs both viewports showing the same candidate at once. This is NOT a decision about whether the eventual Pitch Zone mechanic itself is shared between players or owned per-player: that question stays OPEN, parked for E6, untouched by this story.

### 2-6/R10 — comment hygiene, one line only

`test/state/test_contact_resolution.gd`'s `facing updates from raw intent` comment predates the 1-7 review R1 world-space-planar facing decision and is now imprecise (facing derives from camera-rotated `world_dir`, not literally raw intent — the fixture's zero camera rotation just makes the two values coincide). Do not roam to other files; the previously-suspected stale-comment sites were already fixed in `843e33a`.

### 2-6/R11 — the legibility protocol's file, and the standing playtest-log rule

The protocol is written to its own new docs file, never into `docs/playtest-log.md`. That log is written only by the operator's own hand (established at every prior story's Live Smoke section); an AC may require an operator playtest-log entry, but no AC may have an agent produce one.

### 2-6/R12 — process: live smoke re-invoked; golden prediction NONE, both directions

The R-D6 live-smoke acceptance is re-invoked by this story because Block 1's symptoms are live-only (see the Golden Hash section below — the fixture never reaches a round-over). Golden prediction is NONE for all six blocks, measured in BOTH directions at the dev pass.

### 2-6/R13 — architecture amendment queue

The standing architecture amendment queue already carried FIVE members (per the 2-4/R1 entry): the 2-4 observation-seam amendment (the locked seam family grew from four to seven), the world-space facing contract, `null_controller.gd` in the Directory Tree, the A3 stale-label cleanup, and the gamepad exception to "named actions, never raw". It grows by a SIXTH here: the new `EventBus.round_started` signal plus the seam-registry text documenting it. Queued, NOT edited into `docs/game-architecture.md` this pass.

### Project Structure Notes

- `src/state/match_state.gd` — new `round_started` signal, step 1b early return, `_apply_debug_reset()` pushes `round_started`.
- `src/systems/event_bus.gd` — declare `signal round_started()` (already anticipated in its header comment).
- `src/main/match_runner.gd` — relay `MatchState.round_started -> EventBus.round_started` (mirrors `_relay_round_ended`); wire both `StateInspector` and the new instrument panel; wire `HudRoot.on_round_started`.
- `src/ui/hud/hud_root.gd` — new `on_round_started()` (label clear seat).
- `src/ui/debug/` — two new files: the per-player `StateInspector` and the global debug instrument panel (magnitude switch + Pitch-Zone A/B switch). No `.tscn` edits anywhere.
- `src/controllers/gamepad_profile.gd` — new `normalize_move_magnitude: bool = true` field.
- `src/controllers/gamepad_controller.gd` — `resolve_move_dir` branches on the new field.
- `src/actors/hero/telegraph_controller.gd` (+ `data/telegraphs/`) — distinct roll/dodge profile if not already distinct.
- `test/state/test_match_state.gd` — new round-lifecycle tests (extends the existing round_ended/reset tests already there).
- `test/state/test_contact_resolution.gd` — the one comment fix.
- `test/integration/` — inspector/instrument-panel presence + per-slot-bind assertions; the 8-file integration baseline may grow by one file, a dev-pass decision.

### Project Context Rules

- **Debug tools read signals only, never mutate.** [Source: docs/game-architecture.md#Debug Tools]
- **Feature flags loaded once at startup, runtime-immutable; the instrument panel is not a FeatureFlags mechanism.** [Source: docs/project-context.md#HARD RULE — Feature flags]
- **No `MatchState` autoload; the runner owns the single instance and drains its signal queue (D5).** [Source: docs/game-architecture.md#MatchState Ownership]
- **Signal-driven UI, no per-frame recompute.** [Source: docs/project-context.md#Signals over polling]

### References

- [Source: stories-manual-e2.md#E2.S6]
- [Source: docs/game-architecture.md#Debug Tools; #Event System; #Instrumentation wiring; #Architectural Boundaries]
- [Source: docs/project-context.md#HARD RULE — Feature flags]
- [Source: decision-log.md — Session 2026-07-29, Story 2-6 readiness gate]
- [Source: decision-log.md — Session 2026-07-28, Story 2-3 close-out (2-3/R10); Story 2-4 close-out (MICRO-DECISION 1)]

## Golden Hash

- **Current:** `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, unmoved since story 1-9.
- **Prediction: NONE for all six blocks, to be MEASURED IN BOTH DIRECTIONS during the dev pass.**
- **Golden CANNOT prove Block 1.** The recorded determinism sequence never reaches a round-over (P1 ends 108/120 HP, P2 ends 117/120 HP), so the round-over/reset/`round_started` behaviour is never exercised on the golden path. Block 1 rests entirely on its own dedicated tests (AC 1) and the live smoke (AC 8) — never on the golden hash.
- **What would move the hash:** any new `MatchState.to_snapshot()` field (e.g. a persisted "round started" flag), or any state-layer change beyond the step-1b control-flow guard itself. Everything else in this story (inspector, dodge cue, gamepad profile field, HUD layout switches, comments) touches no state code and no snapshot field.
- **Baseline to hold:** 156 state tests / 715 assertions plus 8 integration files run INDIVIDUALLY (2-5 baseline).

## Live Smoke

- Runs on the shipped default `slot_controller_kinds = [0, 1]` (two live killable humans) — no flip line, no manual `.tscn` edit of any kind.
- **Block 1, explicitly exercised:** a round ends; the SURVIVING hero is observed to STOP moving (previously it kept moving — this is the regression this story fixes); a debug reset is issued; the round-over label clears; the match is observed to CONTINUE — both heroes' movement resolves again.
- Inspector and instrument panel are visually confirmed present and not overlapping gameplay-critical HUD elements. **`DebugInstrumentPanel` is the first WINDOW-GLOBAL Control since the retired 1-3c debug overlay (2-6 close-out micro-decision, N3)** — it sits at the full-window top-centre, straddling the split seam; the smoke must confirm it occludes NEITHER the per-viewport HUD (bars, hands, pitch, round label) NOR gameplay in either half.
- **AC 4 (variable analog magnitude) CANNOT be verified in this smoke (N1).** The shipped default is two KEYBOARD slots, so no `GamepadController` exists to read `normalize_move_magnitude`, and there is no connected pad; exercising the toggle's EFFECT would require both a gamepad and a `.tscn` slot flip, which AC 8 forbids. The smoke confirms only that the magnitude switch is present and toggles; its gameplay effect is deferred to the future rig story (where the feel verdict also lives). The switch's wiring — that the panel's `load()` and a `GamepadController`'s read resolve to the SAME shared resource instance — is content-verified headlessly by `test_panel_and_controller_share_the_same_profile_instance` (DEBT B adjacency), not left an assumption.
- **R-D6 smoke acceptance is RE-INVOKED by this story** and becomes SPENT again only on a pass.
- The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent writes it on the operator's behalf.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8 (`claude-opus-4-8`).

### Debug Log References

- **Baseline (before changes):** 156 state tests / 715 assertions, golden `338172010a…21da2` green; 8 integration files individually green.
- **Block 1 mutation proofs** (each restored from an OUT-OF-REPO scratchpad copy, SHA256-verified byte-for-byte — never `git checkout --`):
  - Proof A — step-1b guard removed → `test_round_over_freezes_resolution_until_reset` FAILS (also `test_dead_hero_velocity_zeroed_every_tick`, which now relies on step 1b). Restored `match_state.gd` to SHA `9b13f7ca…`.
  - Proof B — only the two velocity-zero writes removed (return kept) → the freeze test, the dead-velocity test, and test (b)'s "halted before reset" assertion FAIL (velocity drifts). Restored `match_state.gd` to SHA `9b13f7ca…`.
  - Proof (b) — guard hoisted ahead of the reset (R6-forbidden) → `test_debug_reset_on_frozen_tick_resolves_same_tick` (and the other reset-after-round-over tests) FAIL. Restored to SHA `9b13f7ca…`.
  - Proof (c) — `HudRoot.on_round_started` made a no-op → both `test_round_lifecycle_label` tests FAIL (label driven visible stays visible). Restored `hud_root.gd` to SHA `a60371cf…`.
- **Review pass — D1 relay proofs (the two previously-unproven links, each mutation SHA256-restored from an out-of-repo copy):**
  - Mutation A — `_queue.push(round_started.emit)` removed from `_apply_debug_reset` → the new state test `test_round_started_pushed_once_per_debug_reset` FAILS (signal never fires); ONLY that test fails. Restored `match_state.gd` to SHA `9b13f7ca…`.
  - Mutation B — `_match_state.round_started.connect(_relay_round_started)` removed from `match_runner.gd` → the integration proof FAILS (`label_cleared_via_advance=false`, `bus_round_started=0` — the label stays visible and the relay never fires), while the state test still PASSES (push is independent of the relay). Restored `match_runner.gd` to SHA `24559041…`.
  - The integration proof now clears the round-over label THROUGH a real `p1_debug_reset` press → `advance()` → runner relay (never `bus.round_started.emit()`); a counter on `EventBus.round_started` confirms the relay fired from the runner.
- **Review pass — N2 telegraph-distinctness bite:** `roll.tres` `shape_id` mutated to `AttackCone` (sharing attack's shape) → `test_roll_profile_is_a_distinct_shape_and_sound` FAILS. Restored `data/telegraphs/roll.tres` to SHA `cddc29dc…`. (Distinctness is symmetric — no directional invariant to pin, unlike 2-5's back-heavier-than-front.)
- **Live-smoke fixes (S1/S2) — panel placement DERIVED from measured geometry.** A temporary scaffold measured every HudRoot child + both StateInspectors at the shipped 1152×648 (each SubViewport 576×648, screen-mapped through the container origins). Root cause: the panel's outer Control had size 0, so its box's centre anchor resolved against a zero rect at the origin → box at x=−150 (title clipped to "TRUMENTS") overlapping the top-left deck + StateInspector. Fix: the outer Control fills the window (`PRESET_FULL_RECT`); the box is centred in the EMPTY band `y[354,452]` (between the round-over label bottom 354 and the vitals top 452, clear full-width in both viewports) → measured `InstrumentBox = (426, 359, 300, 89)`. Machine-checked by a new assertion in `test_debug_instruments.gd` (box fully inside the window AND intersecting no HudRoot child / StateInspector in either viewport). **Bite proof:** removing the `PRESET_FULL_RECT` fix → box at `(−150, 35)` → `panel_layout=false`, integration FAILS. Restored `debug_instrument_panel.gd` to SHA `eb1a2108…`. Temp scaffolds deleted.
- **Golden, measured BOTH directions:** `test_state_matches_golden` PASSED at baseline and PASSES after all changes — hash unmoved at `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`. As predicted (NONE), the recorded sequence never reaches a round-over, so the golden cannot and does not prove Block 1.
- **Final suite (after review pass):** 164 state tests / 759 assertions / 0 failed; 9 integration files individually green (8 baseline + new `test_debug_instruments.gd`). (The +2 state tests over the first pass are the D1 relay state test and the N1 shared-instance test.)
- **.uid / editor-scan collateral check:** editor scan produced only the six new `.uid` files for the six new `.gd` files. No `.tscn`, `project.godot`, or `.tres` was modified — none of the known collateral signatures (setting reorders, engine-default pin deletion, uid attribute churn, scene renormalization) appeared.

### Completion Notes List

- **AC 1 (BLOCKING) — round lifecycle. DONE.** `MatchState.round_started` (no-arg) declared; step-1b early return seated AFTER step-1 reset ingestion and BEFORE step 2; `_apply_debug_reset()` pushes `round_started` queued and unconditionally; `match_runner._relay_round_started` relays it to a new `EventBus.round_started`, wired directly in `_ready()` like `round_ended` (no new per-slot `connect_` seam, no prime-on-connect); `HudRoot.on_round_started()` is the single CLEAR seat, `on_round_ended` stays the single SET. Three tests with mutation proofs (above). **The relay is now proven END TO END (review D1):** a state test pins the queue push (`test_round_started_pushed_once_per_debug_reset` — fires exactly once per reset), and the integration test drives the label CLEAR through a real `p1_debug_reset` → `advance()` → runner relay (never `bus.emit`), with mutation proofs for BOTH links (remove the push → state test fails; remove the relay connect → integration fails).
- **OPERATOR MICRO-DECISION (for close-out):** round-over freeze halts both heroes (velocity zeroed every frozen tick); R13's one-tick carry preserved; facing skipped per the asymmetry rule. — Ruled by the operator this pass after the dev pass surfaced an irreducible conflict: Block 1's step-1b freeze skips `_resolve_movement`, so 2-3/R14's every-tick corpse-velocity-zeroing no longer runs and a hero moving at the kill instant would slide (the runner drives `velocity` into `move_and_slide()` regardless of the early return). Resolution: step 1b zeroes BOTH heroes' velocity on every frozen tick (the 2-3/R14 reason honoured in step 1b instead of step 3) and skips facing (display-only). 2-3/R13's one-tick carry survives — the kill tick resolves at step 3, the freeze begins the next tick. The `_end_round`-zeroing alternative was rejected (it would erase R13's carry).
- **2-3 DEAD-residual rulings SUPERSEDED by the 2-6 freeze (review D2).** Block 1 retires the "post-round-over live match" (2-6/R5+R6), so a DEAD hero always implies `_round_over` and step 1b returns before steps 2–8. Every 2-3 DEAD-residual branch is therefore UNREACHABLE via `advance()`: the `_resolve_movement` DEAD velocity-zero + facing-skip (2-3/R5/R13/R14), the `_regen_stamina` DEAD suppression (2-3/R5), and both fact drops in `_resolve_contacts` (DEAD-target 1-7, DEAD-attacker 2-3/R6). Their guarding tests now prove the FREEZE, not the DEAD branch — annotated `STORY 2-6 SUPERSESSION` in place: `test_dead_hero_velocity_zeroed_every_tick`, `test_dead_hero_facing_frozen`, `test_dead_hero_stamina_does_not_regen`, `test_dead_attacker_in_flight_window_delivers_nothing`, `test_dead_hero_row_accepts_no_input`, and the rewritten `test_no_corpse_mana_farming_under_round_over_freeze`. **This code is NOT changed in this story** — the branches are left in place as defensive dead code, and the decision is deferred (below).
- **ARCHITECTURE AMENDMENT QUEUE grows 6 → 7 (review D2).** New member (SEVENTH): *"2-3 DEAD-residual branches (`_resolve_movement` DEAD velocity/facing, `_regen_stamina` DEAD suppression, both `_resolve_contacts` fact drops) are unreachable under the 2-6 round-over freeze — decide removal vs retention."* Forcing point: the **E2 close-out docs commit**. The sixth member (`EventBus.round_started` + seam-registry text, 2-6/R13) stands; this seventh joins it. Queued, NOT edited into `docs/game-architecture.md` this pass.
- **AC 2 — per-player StateInspector. DONE.** `src/ui/debug/state_inspector.gd`, one per SubViewport, wired to FIVE existing observation seams (action-state, HP/stamina/mana, action_rejected) — no eighth seam, no TimingWindow countdown, no `_process`/`_physics_process`, no `.tscn`. Per-slot binding proven in the integration test (rolling P1 shows ROLLING on P1's inspector only).
- **AC 3 — dodge cue. MOOT — no work to perform (review N2).** The roll telegraph was ALREADY a distinct shape+sound as of story 1-10 (`RollDisc` underfoot + `StingRoll` + yellow, vs attack cone/red and block shield/blue), so 1-10/R2's "distinct dodge cue" deferral had nothing left to defer — 2-6 only CONFIRMS and pins it. No code or data change. The iframe drop in `_resolve_contacts` step 4 emits nothing (1-9/R5) and the cue is driven purely by entering `ActionState.ROLLING` via the existing seam — no new signal anywhere. Pinned by `test_telegraph_profiles.gd`, whose distinctness assertion is proven to BITE by mutation (roll sharing attack's shape fails it); distinctness is symmetric, so there is no directional invariant to pin.
- **AC 4 — variable analog magnitude toggle. DONE.** `GamepadProfile.normalize_move_magnitude: bool = true`; `GamepadController.resolve_move_dir` gains a defaulted third arg and branches (false = pass magnitude through, clamped to 1.0). The instrument panel flips the field on the shared in-memory resource instance ONLY — never `ResourceSaver`, never a `.tres` write. `src/state/` untouched; `data/gamepad_profile.tres` untouched (default is the shipped value). Pinned by `test_variable_magnitude_passes_partial_deflection_through`. **N1:** the panel's `load()` and a `GamepadController`'s `_profile` are content-verified to be the SAME cached resource instance (`test_panel_and_controller_share_the_same_profile_instance`) — the toggle's reach is proven, not assumed. NOT verifiable in the live smoke (default is two keyboards, no pad, `.tscn` flip forbidden by AC 8) — recorded in the Live Smoke section.
- **AC 5 — Pitch Zone A/B. DONE.** `HudRoot.set_pitch_zone_placement(left_of_bars)` moves the placeholder between dead-centre (A) and a left-of-vitals-bars anchor (B) derived from the vitals column geometry (centre−180), independent of `OpponentHandStrip`. The instrument panel's one SHARED switch moves BOTH viewports together (A/B comparability). Decides nothing about the E6 mechanic. Proven in the integration test.
- **AC 6 — comment hygiene. DONE.** Exactly one line corrected in `test/state/test_contact_resolution.gd` (`facing updates from raw intent` → camera-rotated `world_dir`, 1-7 R1). No other file touched for comments.
- **AC 7 — legibility protocol. DONE.** Written to the new `docs/legibility-protocol.md` (never `docs/playtest-log.md`). The E1-melee rehearsal is set up (the three cues enumerated) with a results template; the empirical rehearsal run itself is operator-owned at the live smoke — the agent does not assert a reading it did not observe.
- **AC 8 — live smoke. OPERATOR-OWNED, NOT RUN THIS PASS.** A live two-human smoke on the shipped default (`[KEYBOARD_P1, KEYBOARD_P2]`) cannot be run headlessly; it and the hand-written `docs/playtest-log.md` entry are the operator's, before the commit chain. The smoke should specifically confirm: a round ends → the surviving hero STOPS moving (now halted) → debug reset → the round-over label clears → the match CONTINUES; and it is the run of the AC 7 rehearsal.
- **Integration file decision:** added ONE new integration file, `test/integration/test_debug_instruments.gd` (baseline 8 → 9), covering the AC 1 label wiring round-trip, the AC 2 inspector presence + per-slot binding, and the AC 4/5 panel switches — none had a home in the existing files.
- **Architecture amendment (2-6/R13):** the new `EventBus.round_started` signal + its seam-registry text is queued for the next `docs/game-architecture.md` amendment, NOT edited in this pass. (The queue also gains the seventh member from review D2 — see above.)
- **CLOSE-OUT MICRO-DECISION (review N3): `DebugInstrumentPanel` is the first WINDOW-GLOBAL Control since the retired 1-3c debug overlay.** Every other presentation node since (HudRoot, StateInspector) is per-viewport under a SubViewport; the instrument panel is intentionally one window-global Control (added as a top-level child of the runner root) because both its switches are window-global (the magnitude toggle mutates one shared resource; the Pitch Zone A/B is a single shared switch by design, 2-6/R9). Legitimate and intentional; recorded here, and the live smoke must confirm it occludes neither HUD nor gameplay.
- **LIVE-SMOKE FIX S1/S2 — panel no longer occludes the HUD or clips off-screen.** The panel's outer Control was size 0, so its box's centre anchor collapsed to the origin (box at x=−150 — title clipped to "TRUMENTS", overlapping the top-left deck/reshuffle and the StateInspector). Fixed: the outer Control now fills the window and the box is centred in the measured EMPTY band `y[354,452]` (between the round-over label and the vitals bars). Placement DERIVED from measured geometry, not guessed, and now MACHINE-CHECKED (`test_debug_instruments.gd`: box inside the window AND overlapping no HudRoot child / StateInspector in either viewport), with a bite proof.
- **LIVE-SMOKE FIX S3 — legibility protocol corrected + naive-observer deviation recorded.** The stale "temporary `KEYBOARD_P2` flip" note is replaced: since story 2-3 the shipped default is `[KEYBOARD_P1, KEYBOARD_P2]`, so P2 acts with no flip and no `.tscn` edit. Added: a SOLO run cannot satisfy the naive-observer requirement — it is a DRY RUN of the procedure, not a cue verdict; the definitive legibility judgement is animation-gated (rig story, DEBT E "legibility under 0.5 s"). Deviation requirement recorded: any run without a naive observer must say so in its result table.

### File List

Source — modified:
- `src/state/match_state.gd` — `round_started` signal; step-1b round-over freeze (halt both heroes, return); `_apply_debug_reset()` pushes `round_started`.
- `src/systems/event_bus.gd` — `signal round_started()` declared.
- `src/main/match_runner.gd` — relay `round_started` → `EventBus.round_started`; wire `HudRoot.on_round_started`; construct + wire the per-viewport `StateInspector`s and the global `DebugInstrumentPanel`.
- `src/ui/hud/hud_root.gd` — `on_round_started()` clear seat; `_pitch_panel` member + `set_pitch_zone_placement()`.
- `src/controllers/gamepad_profile.gd` — `normalize_move_magnitude: bool = true`.
- `src/controllers/gamepad_controller.gd` — `resolve_move_dir` branches on the magnitude policy; call site passes the profile field.

Source — new:
- `src/ui/debug/state_inspector.gd` (+ `.uid`) — per-player read-only state inspector.
- `src/ui/debug/debug_instrument_panel.gd` (+ `.uid`) — global debug instrument panel (magnitude switch + Pitch Zone A/B switch).

Tests — modified:
- `test/state/test_match_state.gd` — Block 1 tests (a) freeze/halt + (b) reset-same-tick + helpers; the D1 state relay test `test_round_started_pushed_once_per_debug_reset`; SUPERSESSION annotations on `test_dead_hero_velocity_zeroed_every_tick` and `test_dead_hero_facing_frozen`.
- `test/state/test_contact_pipeline.gd` — the two post-round-over tests rewritten to the freeze semantics (D3: the reset test now carries the exact-40 stamina bite); SUPERSESSION annotations on `test_no_corpse_mana_farming_under_round_over_freeze` and `test_dead_hero_row_accepts_no_input`.
- `test/state/test_contact_resolution.gd` — the one comment-hygiene line (AC 6); SUPERSESSION annotation on `test_dead_attacker_in_flight_window_delivers_nothing`.
- `test/state/test_stamina_economy.gd` — SUPERSESSION annotation on `test_dead_hero_stamina_does_not_regen` (D2).
- `test/state/test_gamepad_controller.gd` — variable-analog-magnitude test (AC 4) + the N1 shared-instance content test.

Tests — new:
- `test/state/test_round_lifecycle_label.gd` (+ `.uid`) — Block 1 test (c), the label CLEAR/SET seats, non-vacuous.
- `test/state/test_telegraph_profiles.gd` (+ `.uid`) — AC 3 roll/dodge distinctness pin.
- `test/integration/test_debug_instruments.gd` (+ `.uid`) — AC 1/2/4/5 live-scene integration.

Docs — new:
- `docs/legibility-protocol.md` — AC 7 telegraph legibility protocol + E1-melee rehearsal setup.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-29 | 0.1 | Gate fixes: rulings 2-6/R1..R13 applied — story rebuilt around six real blocks (round-lifecycle early-return + reset-visibility fix, per-player inspector, dodge cue, variable analog magnitude toggle, Pitch Zone A/B, one comment fix) plus the retained per-player inspector and legibility protocol; old AC2 (step/pause) and AC5 (record/replay) re-homed to future stories; old AC1 narrowed into a presentation/controller-local instrument panel; Golden Hash and Live Smoke sections added; promoted backlog -> ready-for-dev. | Claude Sonnet 5 |
