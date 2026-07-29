# Story 2.6: Legibility and feel validation instrumentation

Status: ready-for-dev

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
- Inspector and instrument panel are visually confirmed present and not overlapping gameplay-critical HUD elements.
- **R-D6 smoke acceptance is RE-INVOKED by this story** and becomes SPENT again only on a pass.
- The operator writes the `docs/playtest-log.md` entry by hand, BEFORE the commit chain — no agent writes it on the operator's behalf.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-29 | 0.1 | Gate fixes: rulings 2-6/R1..R13 applied — story rebuilt around six real blocks (round-lifecycle early-return + reset-visibility fix, per-player inspector, dodge cue, variable analog magnitude toggle, Pitch Zone A/B, one comment fix) plus the retained per-player inspector and legibility protocol; old AC2 (step/pause) and AC5 (record/replay) re-homed to future stories; old AC1 narrowed into a presentation/controller-local instrument panel; Golden Hash and Live Smoke sections added; promoted backlog -> ready-for-dev. | Claude Sonnet 5 |
