# Story 2.3: Opponent slot becomes a second human

Status: ready-for-dev

## Story

As two players,
I want the opponent slot to become a second human by flipping slot 1's controller kind at the single A3 config point, with the DEAD-slot residuals fix closing behind it,
so that human-vs-human melee is achieved with no hero/actor/state edit beyond the state-gating the fix requires, and the first real feel notes get written down.

## Acceptance Criteria

1. `slot_controller_kinds` default flips `[0, 2]` -> `[0, 1]` as a single-line change at the sole configuration point (`src/main/match_runner.gd`). No hero, actor, `.tscn`, or `project.godot` edit is needed or permitted to achieve it. `ControllerKind` ordinals are untouched.
2. A DEAD slot exhibits no live behaviour, via an ASYMMETRIC fix in `_resolve_movement` (step 3) — the two writes are not the same operation: `velocity` is EXPLICITLY WRITTEN TO ZERO, every tick, for a DEAD hero (`HeroActor.drive()`, `src/actors/hero/hero.gd:26`, reads `hero_state.velocity` directly into the `CharacterBody3D` and calls `move_and_slide()` — a skipped write would leave the last live velocity in place and the corpse would keep sliding at that speed forever, exactly the bug this story exists to kill); `facing` is SKIPPED (not written) for a DEAD hero — the last value persists unchanged, and that persistence IS the freeze, storing nothing new. `_regen_stamina` (step 5) skips a DEAD hero the same way it already skips a BLOCKING one. These are functions in TWO different steps, not one gate. State-gated, never in a controller (D3a: controllers stay dumb). This story adds **NO new `HeroState` snapshot field** — `velocity` already exists in the snapshot; only its VALUE on the DEAD branch changes, and the recorded determinism sequence never kills a hero (see Golden Hash below), so this cannot move the golden by construction. If the dev pass concludes a new field is required, that is a STOP-and-ask, not an implementation detail.
3. A DEAD attacker delivers nothing: `_resolve_contacts` (step 4) gains an attacker-liveness check at the SAME rung as the existing target-side DEAD drop — PRE-DEDUPE, ahead of the iframe drop and `register_swing_hit` (the DEAD-drop family; see Dev Notes for the quoted current order). A drop placed after dedupe registration would wrongly consume the swing's one resolution against a corpse. In-flight windows (attack, roll iframe, deflect) keep ticking to expiry by design — this is deliberate behaviour, not a residual; no early-stop path is introduced, and the 1-9/R3 obligation ("both roll windows start only in `enter_roll`, no path closes them before expiry") is left intact. `attack_index` stays untouched, as always.
4. Guards ship for every residual class the fix closes (dead-slot movement, dead-slot facing, dead-slot stamina regen, dead attacker's in-flight window still delivering), plus a NEW guard pinning the shipped `slot_controller_kinds` DEFAULT ARRAY to `[0, 1]` — distinct from 2-2's ordinal-VALUE guard (see Tasks, AC1). The state harness stays green; all 8 integration tests are re-run individually after the flip and their results reported explicitly (a live P2 keyboard slot replaces the NULL dummy default that most of them exercise).
5. A live two-human smoke re-invokes the R-D6 acceptance against the committed default with no `.tscn` edit. First feel notes (spacing, attack weight, deflect timing, stamina pressure) go to `docs/playtest-log.md` by hand — this log is explicitly the input to the E3 revisit gate; E3 stays provisional until it exists.

**Exit criterion.** Two humans play a round to a real death; both slots are killable; the dead slot is inert in movement, facing, economy, and contact delivery; the golden hash is unmoved (or moved with one adjudicated, separately-caused re-baseline); R-D6 passes.

## Tasks / Subtasks

- [x] Flip `slot_controller_kinds` default `[0, 2]` -> `[0, 1]` at the sole config point; add a NEW guard pinning the shipped DEFAULT ARRAY to `[0, 1]` — distinct from 2-2's `test_controller_kind_ordinals_pinned` (`test/state/test_architecture_invariants.gd:50`), which already pins the four ordinal VALUES and needs no change here (AC: 1) — landed as `test_slot_controller_kinds_default_is_p1_p2`
- [x] Guard `_resolve_movement` (step 3) for a DEAD hero: EXPLICITLY WRITE `velocity` to zero every tick (never skip — `HeroActor.drive()` reads it directly), SKIP the `facing` write (last value persists, the freeze); guard `_regen_stamina` (step 5) to skip a DEAD hero — no new snapshot field (AC: 2)
- [x] Add an attacker-liveness check in `_resolve_contacts` (step 4) at the same PRE-DEDUPE rung as the existing target-side DEAD drop, ahead of the iframe drop; verify no window is stopped or cleared early (AC: 3) — 1-9/R3 obligation confirmed intact
- [x] Add guards: dead-slot zero velocity, dead-slot frozen facing, dead-slot no stamina regen, dead attacker's in-flight window delivers nothing (no damage/hit_landed/mana/signal); add the new `slot_controller_kinds` default-array guard (AC: 4) — five new tests total
- [x] Re-run all 8 integration tests individually after the flip; report each result explicitly (AC: 4) — all 8 PASS individually
- [x] Run the live two-human smoke per the Live Smoke section below; write prose feel notes in `docs/playtest-log.md` (AC: 5) — operator smoke PASS, no findings

## Dev Notes

- **Primary deliverable.** This story's reason for existing is the DEAD-slot residuals fix (named gap from 1-7, live-confirmed at the 2-1 smoke), not the config flip alone — the flip is what makes the residuals reachable by a human-driven slot for the first time.
- **X5 / replay reroute.** Record/replay of a two-human round (an `InputIntent` stream replayed through a `ReplayController`) does NOT belong to this story. It is re-homed to the story that lands `IntentRecorder`, which already inherits the four-field contact fact (1-8 D-4 supersession) and the second half of DEBT B (reload events in the intent stream) — one stream contract, taken together. 2-3 does not build a recorder or a replay controller.
- **HUD deferral.** Per-player HUD (subscription, half-width layout) stays with 2-4; nothing here. "No HUD reads the opponent's `PlayerState`" is already covered by the locked observation seam (signals/payloads only, consumers never hold a state handle) — 2-3 has nothing further to enforce on this point.
- **No match-setup selection scene/resource.** `slot_controller_kinds` is the ONLY configuration point (constraint A3, `1-6-training-dummy-null-controller.md` and this log's A3 amendment). A selection affordance (pre-match scene or config resource choosing each slot's kind) would be a second authoring surface and is explicitly out of scope. Deferred to its own story when E7 (scripted bot) is in view.
- **Integration re-verification (AC4).** The default flip changes what most of the 8 integration tests actually exercise on slot 1 (a live keyboard slot instead of the NULL dummy). Headless probably yields a neutral intent for an unpressed keyboard slot, but that is an assumption to prove, not a fact to assume — run and report each of the 8 individually.
- **Why velocity and facing differ (do not "simplify" this to one skip).** `velocity` is READ every frame by `HeroActor.drive()` (`src/actors/hero/hero.gd:26`) and driven straight into `move_and_slide()` — a stale nonzero value keeps moving the body forever, so it must be actively rewritten to zero every tick a hero is DEAD. `facing` is only ever read to compute a yaw for display (`hero.gd:34`) and is never re-derived from anything else — leaving its last value in place is inert by construction, so skipping the write is sufficient and correct. Same DEAD condition, two different write disciplines because the two fields are consumed differently downstream.
- **No new snapshot field (hard constraint).** The DEAD-slot fix touches only EXISTING fields — `velocity` (now explicitly zeroed on the DEAD branch) and `facing` (write skipped) in `_resolve_movement`, plus the regen call skipped in `_regen_stamina` — for a DEAD hero. `HeroState.to_snapshot()` gains no field. A new stored field would move the golden hash (1-9 `roll_direction` precedent); this fix does not need one and must not add one. If a new field looks necessary at dev time, STOP and ask — it is a design-shape question, not an implementation detail.
- **Ladder rung order, quoted so the dev pass does not guess.** `_resolve_contacts` (`match_state.gd:353-387`) currently runs, per fact, in this order: target DEAD drop first (`if target.hero.action_state == HeroState.ActionState.DEAD: continue`), then the iframe drop (`if target.hero.is_iframe_open(): continue`), then dedupe accept (`register_swing_hit`), then the BLOCKING/facing ladder (deflect -> block), then full damage. The attacker-side DEAD check joins the FIRST rung — before the iframe drop, before dedupe — the same DEAD-drop family the code comment already names, not a new one.
- **Scope fences.** 2-4 (per-player HUD), 2-5 (face-down opponent hand), 2-6 (legibility/feel instrumentation) are untouched by this story. E3 stays under its HOLD gate (revisit after first E1/E2 playtest) — nothing here pulls E3 forward. DEBT E (animation-gated feel register) items stay parked; AC5's feel notes are playtest prose only, never animation work.
- **New named gap (not this story's scope).** `MatchState.advance()` has no early return on `_round_over` — the surviving hero keeps moving after the round ends. This will be VISIBLE on the first two-human smoke (a NULL dummy never exhibited it). Named and parked here; owner decided at the E2 retrospective. Do not fix it as a side effect of the DEAD-slot work — it is a different condition (`_round_over`, match-level) from a single slot's `ActionState.DEAD`.
- **Label note.** This story's config-point seam is **architecture amendment A3** (the label `match_runner.gd` and `null_controller.gd` comments already use), not "DECISION (a)". The story-local "(a)" label previously here was stale and collided with the decision log's own **OPEN decision (a)** — "Attacker consequence on basic-attack deflect / STUNNED" (Session 2026-07-22), which is a DIFFERENT, still-open design question with no bearing on this story. 2-3 does not touch it; it stays open.

### Inherited locked constraints (guardrails, restated so this story doesn't re-break them)

- **DECISION A + SINGLE YAW SOURCE.** Hero root never rotates; one yaw computation feeds both Hitbox and Mesh; never a second `atan2`. This story only SKIPS the `facing` write for a DEAD hero in `_resolve_movement` (velocity is handled differently — explicitly zeroed, see Dev Notes) — the yaw mapping itself is untouched, and no separate frozen value is ever computed or stored.
- **D3(a).** `Input.*` reads only under `src/controllers/`. The DEAD-slot gating is a `MatchState` (state-layer) concern — controllers stay dumb, per R-e; no controller may suppress or filter intent based on liveness.
- **F1.** Exactly one `_physics_process`, in `match_runner.gd`. Unaffected by this story.
- **Observation seams.** The four locked seams (`connect_hero_action_state_changed`, `connect_hero_action_rejected`, `connect_hit_landed`, `connect_deflect_landed`) plus `EventBus.round_ended` are the only sanctioned channels out of state. Nothing new is added here.
- **CONSTRAINT C.** Every balance read stays inline at the point of use (`ms.balance.*` / `ms.balance_ticks.*`); never cache a `BalanceTicks` or `BalanceConfig` reference across a reload.
- **`attack_index` never resets.** Monotonic for the life of the match (1-6 pin); the DEAD-attacker fix must not touch it.

### Project Structure Notes

- Config flip at `src/main/match_runner.gd`'s `slot_controller_kinds` export.
- DEAD-slot gating and the attacker-side ladder extension, entirely in `src/state/match_state.gd`: the zero-velocity write and the facing-write skip in `_resolve_movement` (step 3, asymmetric — see Dev Notes), the regen skip in `_regen_stamina` (step 5), and the attacker-liveness check in `_resolve_contacts` (step 4). No `src/state/hero_state.gd` edit — nothing new is stored.
- Feel notes at `docs/playtest-log.md` (hand-written, not generated).

### Project Context Rules

- **Controller abstraction:** dummy -> PvP -> bot is a config swap. [Source: gdd.md#Controls; epics.md#Sequencing invariants]
- **Determinism / replay (X5):** seed + intents reproduce the round; this story does not build the replay path (see X5 reroute above). [Source: docs/game-architecture.md#Determinism & Replay]

### References

- [Source: stories-manual-e2.md#E2.S3]
- [Source: stories-manual-e3.md#Revisit gate]
- [Source: epics.md#E1; #E2; #E7]
- [Source: decision-log.md — 1-7 close-out NAMED GAP (DEAD-slot residuals); 1-8 close-out R-D6; 1-9 close-out R-D6 SPENT; 2-3 readiness gate, this session]

## Golden Hash

- **Current:** `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, unmoved since 1-9.
- **Prediction: NONE, measured in BOTH directions** — the recorded determinism sequence never kills a hero (P1 ends 108 HP, P2 ends 117 HP, MAX_HP 120), so the DEAD branch is never entered by the golden path; and `slot_controller_kinds` is runner-side config absent from `MatchState.to_snapshot()`, so the flip cannot touch the hash by construction. If the hash moves at all, that is a FINDING (the gating leaked into a live branch reachable by the golden sequence), to be investigated, never baselined away.
- **Discipline:** measured in both directions; all non-golden tests proven green first; at most ONE re-baseline, with separately named causes if it happens; intermediate hashes come from the determinism test's own failure output; isolation runs are sanctioned for attribution; never re-baselined without an operator ruling.

## Live Smoke

- **R-D6 re-invoked** (SPENT since 2-1; not re-invoked by 2-2, whose both flips ran the pad against the NULL dummy). This story is the true candidate: a PERMANENT `KEYBOARD_P2` default means two live, killable human slots.
- **No flip line required.** After the default flip lands, the script default IS `[0, 1]` — the smoke exercises the COMMITTED default with zero manual `.tscn` edits. This removes both the blank-line-residue hazard (2-2 process note) and the baked-flip hazard (the recurring editor-collateral pattern) entirely.
- **Optional second run.** Any run against a different configuration is OPTIONAL and only then requires the manual line, with the full ritual: editor closed for the entire edit, textual edit immediately below the `script =` line of the `Main` node with no blank line, `git diff` after the edit AND after the removal.
- Both viewports observed; both slots exercised as killable; dead-slot behaviour (movement, facing, stamina, attacker-side window delivery) watched live.
- The known-and-parked post-round-over gap (see Dev Notes) is named here so it is NOT reported as a new defect if seen during the smoke.
- If the smoke produces findings, the operator writes the `docs/playtest-log.md` entry BEFORE the commit chain.

## Dev Agent Record

### Agent Model Used

Dev pass: claude-opus-4-8. Commit chain: claude-sonnet-5.

### Debug Log References

### Completion Notes List

- Suite `151/690` -> `156/714`. All 8 integration tests re-run individually after the flip, all PASS, diagnostics bit-identical to baseline — 7 of the 8 rely on the default and now build a live `KEYBOARD_P2` on slot 1, proving empirically that an unpressed keyboard yields a neutral intent under the headless harness.
- Golden UNMOVED, measured in BOTH directions: the reverse measurement temporarily disabled the DEAD gates and the file was restored byte-for-byte, SHA256-verified. The reverse run also showed all four behavioural guards FAIL without the gates — proving them load-bearing, not merely inert insurance.
- Live smoke: PASS, no findings, zero editor collateral (see `docs/playtest-log.md`, 2026-07-28 entry).

### File List

- `src/main/match_runner.gd` — EDITED. `slot_controller_kinds` default flipped `[0, 2]` -> `[0, 1]` at the sole A3 config point (AC 1)
- `src/state/match_state.gd` — EDITED. DEAD-slot movement gate in `_resolve_movement` (velocity zeroed, facing write skipped), regen suppression in `_regen_stamina`, attacker-side DEAD drop in `_resolve_contacts` at the pre-dedupe rung (AC 2, 3)
- `test/state/test_architecture_invariants.gd` — EDITED. Added `test_slot_controller_kinds_default_is_p1_p2` (AC 1, 4)
- `test/state/test_match_state.gd` — EDITED. Added `test_dead_hero_velocity_zeroed_every_tick`, `test_dead_hero_facing_frozen` (AC 2, 4)
- `test/state/test_stamina_economy.gd` — EDITED. Added `test_dead_hero_stamina_does_not_regen` (AC 2, 4)
- `test/state/test_contact_resolution.gd` — EDITED. Added `test_dead_attacker_in_flight_window_delivers_nothing` (AC 3, 4)
- `test/integration/test_camera_relative.gd` — EDITED. Comment/header updates only — the test's explicit `[0, 1]` override now matches the shipped default but is retained on purpose; no behavioural change (AC 1)

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-28 | 0.1 | Dev pass: `slot_controller_kinds` default flipped to `[0, 1]`; DEAD-slot residuals closed (velocity zero, facing freeze, stamina suppression, attacker-side contact drop); five new guard tests. Golden unmoved, measured both directions; suite 151/690 -> 156/714 + 8 integration green. Live smoke PASS, no findings. NOT committed. | claude-opus-4-8 |
