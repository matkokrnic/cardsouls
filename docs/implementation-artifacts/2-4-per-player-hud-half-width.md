# Story 2.4: Per-player HUD root in real half-width space

Status: ready-for-dev

## Story

As a player,
I want a signal-driven HUD occupying its real half-width space with every E3-E6 element already reserved at its true footprint, fed by three new per-slot economy observation seams and nothing more,
so that CardSouls discovers whether the full HUD fits the space at all, before those elements have content, without re-consuming the combat seams TelegraphController already owns.

## Acceptance Criteria

1. `match_runner.gd` gains three new per-slot observation seams -- `connect_hero_hp_changed(slot, cb)`, `connect_stamina_changed(slot, cb)`, `connect_mana_changed(slot, cb)` -- wrapping the existing `HeroState.hp_changed`, `StaminaPool.stamina_changed`, `ManaPool.mana_changed` signals. Payload for all three is `(current: float, maximum: float)`. Each carries the same slot guard as `connect_hero_action_state_changed` (`Invariant.check(slot == 0 or slot == 1, ...)`). This is an AMENDMENT to the locked observation seam family (FOUR -> SEVEN, plus `EventBus.round_ended`), recorded in the decision log as CANONICAL this session; the `game-architecture.md` text edit is deferred into the standing arch amendment queue, not made here.
2. Each of the three new seams PRIMES on connect: at the moment `connect_hero_hp_changed` / `connect_stamina_changed` / `connect_mana_changed` is called, the seam invokes the callback ONCE, immediately, with the current `(current, maximum)` value -- before returning, and independent of any future signal emission. Without this, a consumer connecting in `_ready` sees nothing until the first change and the HUD bars render empty until first damage/spend.
3. One HUD root per viewport (`src/ui/hud/`) is a `Control` constructed in code and added as a child of each `SubViewport` (`$P1View/P1Viewport`, `$P2View/P2Viewport`) at true half width. No `main.tscn` edit. No new `.tscn` file. No camera added, no gameplay node reparented, `data/camera_config.tres` untouched.
4. HP, stamina, and mana bars are signal-driven consumers of AC1's three seams only -- no `_process` polling, no per-frame economy recompute. The mana bar exists now and is LIVE from E1: it moves on every confirmed melee hit -- including a BLOCKED hit, which is still a confirmed hit per the 1-8 ruling -- via the step-5 melee-hit mana seat (`_generate_mana`, story 1-5, `balance.melee_hit_mana`, gated on `FeatureFlags.melee_mana_generation`). This is EXPECTED smoke behaviour, not a finding. Each HUD root is wired with ONLY its own slot's economy callbacks -- pinned by a test -- so the HUD is structurally incapable of reaching the opponent's payloads (no state handle, no opponent slot argument ever passed to that root's binds).
5. The regions E3-E6 will fill are reserved, sized, and laid out as empty placeholders occupying their real footprint: the 4-card hand strip, three orb counters, the Pitch Zone slot with its timer, and deck/reshuffle indicators. None of these consumes a signal in this story.
6. P4 is applied to the layout: elements that matter under reaction pressure (stamina, incoming telegraph placeholder, pitch timer placeholder) sit near the centre of attention; elements consulted at the player's own tempo (deck count, orb totals) sit at the periphery. The rationale is written into the HUD root as a comment.
7. `src/main/debug_state_overlay.gd` and `test/integration/test_debug_overlay.gd` (plus their `.uid` companions) are deleted; the overlay's instantiation and seam wiring are removed from `match_runner._ready`. A new integration test proves the same class of property in the live scene -- per-viewport HUD nodes exist under BOTH SubViewports. The integration suite baseline stays at 8 (it does not drop to 7).
8. 2-4 consumes exactly: the three new economy seams (AC1, for the bars) plus `EventBus.round_ended` (a minimal per-viewport round-over label). It does NOT connect `connect_hit_landed`, `connect_deflect_landed`, `connect_hero_action_state_changed`, or `connect_hero_action_rejected` anywhere in the HUD wiring -- those four seams stay fully owned by `TelegraphController`. The story's Dev Notes carry a per-element -> channel table naming every HUD element's channel and every consumed channel's element.
9. `test/state/test_architecture_invariants.gd`'s `test_cues_layer_never_calls_state_mutators` gains an existence guard for the HUD root file (`src/ui/hud/hud_root.gd`), mirroring the existing `telegraph_controller.gd` existence guard (`controller_found`) -- so a rename or a move out of `src/ui/` cannot silently narrow scan coverage.
10. Legibility is confirmed at real size: a screenshot at final half-width resolution (never full-width) in which every reserved element is identifiable, plus a check that no element is clipped by the split boundary or the pulled-back camera's arena view.

## Tasks / Subtasks

- [x] Add `connect_hero_hp_changed(slot, cb)`, `connect_stamina_changed(slot, cb)`, `connect_mana_changed(slot, cb)` to `src/main/match_runner.gd`, each wrapping `player.hero.hp_changed` / `player.stamina.stamina_changed` / `player.mana.mana_changed` on the correct `PlayerState` (`_match_state.p1`/`_match_state.p2`), with the same slot guard as `connect_hero_action_state_changed` (AC: 1)
- [x] Prime each of the three seams on connect: call the connecting callback once with `player.hero.get_hp()`/`get_max_hp()`, `player.stamina.get_current()`/`get_maximum()`, `player.mana.get_current()`/`get_maximum()` respectively, immediately after `.connect(callback)` (AC: 2)
- [x] Add `src/ui/hud/hud_root.gd` -- a `Control`, constructed in code, no companion `.tscn` (AC: 3)
- [x] In `match_runner._ready`, instantiate one `HudRoot` per viewport and `add_child` it under `$P1View/P1Viewport` and `$P2View/P2Viewport` respectively; verify `main.tscn` carries zero diff, no camera is added, no gameplay node is reparented, `data/camera_config.tres` is untouched (AC: 3)
- [x] Implement HP/stamina/mana bars inside `hud_root.gd` as signal-driven consumers of AC1's three seams only; no `_process` override for economy state (AC: 4)
- [x] Wire each `HudRoot` instance's bar callbacks through `connect_hero_hp_changed(slot, ...)`/`connect_stamina_changed(slot, ...)`/`connect_mana_changed(slot, ...)` bound to that viewport's own slot only; add a test pinning that each HUD root is wired with only its own slot's economy callbacks (AC: 4)
- [x] Reserve + lay out the 4-card hand strip, 3 orb counters, Pitch Zone slot+timer, deck/reshuffle indicators as empty placeholder `Control`s at their real footprint, no signal wiring (AC: 5)
- [x] Apply the P4 centre/periphery layout inside `hud_root.gd`; comment the rationale in the script (AC: 6)
- [x] Delete `src/main/debug_state_overlay.gd` and `src/main/debug_state_overlay.gd.uid` (AC: 7)
- [x] Remove the overlay's instantiation (`DebugStateOverlay.new()`), its `connect_hero_action_state_changed` binds, and its `connect_hit_landed` bind from `match_runner._ready` (AC: 7)
- [x] Delete `test/integration/test_debug_overlay.gd` and its `.uid` companion (AC: 7)
- [x] Add `test/integration/test_hud_viewports.gd` proving per-viewport HUD nodes exist under BOTH `SubViewport`s in the live scene; confirm the integration suite still globs to 8 files (AC: 7)
- [x] After `src/ui/hud/hud_root.gd` and `test/integration/test_hud_viewports.gd` exist, generate their `.uid` companions via `godot --headless --editor --quit --path .` (the editor is never opened by hand); then run a per-diff collateral check -- `git status` plus `git diff` on every file the scan touched, classifying each diff individually. Blanket revert is RETIRED; collateral is always sorted per-diff. Known collateral signature to watch for: reorder + deletion of the `physics_ticks_per_second=60` pin + uid attributes + scene renormalization (AC: 7)
- [x] Wire a minimal per-viewport round-over label via `EventBus.round_ended.connect(root.on_round_ended.bind(slot))`, mirroring the `TelegraphController` precedent (`cues.on_round_ended.bind(slot)`); connect no other combat seam in HUD wiring (AC: 8)
- [x] Write the per-element -> channel table into Dev Notes (below) (AC: 8)
- [x] Extend `test_cues_layer_never_calls_state_mutators` in `test/state/test_architecture_invariants.gd` with an existence assertion for `src/ui/hud/hud_root.gd`, matching the `controller_found` pattern used for `telegraph_controller.gd` (AC: 9)
- [x] Screenshot at final half-width resolution; verify no clipping by the split boundary or the pulled-back camera's arena view (AC: 10)

## Dev Notes

- **Split-screen is a constraint, not a feature.** A HUD built full-width then squeezed is a HUD designed twice; every element gets its true half-width footprint now. [Source: stories-manual-e2.md#Epic goal; epics.md#Sequencing invariants]
- Reserving E3-E6 regions now is the point -- this is the layer where CardSouls discovers whether the full HUD fits at all. This reserves footprint for E4 (orbs) and E6 (pitch) elements **without building those systems** -- placeholders only. [Source: stories-manual-e2.md#E2.S4 item 3]
- HUD is signal-driven per D5: subscribes, never polls, never writes. [Source: docs/game-architecture.md#D5]

### Per-element -> channel table (2-4/R4)

| HUD element | Channel | Notes |
|---|---|---|
| HP bar (per slot) | `connect_hero_hp_changed(slot, cb)` | new seam (2-4/R1); primed on connect (2-4/R2) |
| Stamina bar (per slot) | `connect_stamina_changed(slot, cb)` | new seam (2-4/R1); primed on connect (2-4/R2) |
| Mana bar (per slot) | `connect_mana_changed(slot, cb)` | new seam (2-4/R1); primed on connect (2-4/R2); LIVE from E1 -- moves on every confirmed melee hit, blocked hits included (1-8 ruling), via the step-5 melee-hit mana seat (story 1-5) |
| Round-over label (per viewport) | `EventBus.round_ended` | minimal text only; the 2-3/R10 named gap is visible here -- see Live Smoke |
| 4-card hand strip | none -- reserved footprint only | E3 (draw) / 2-5 (face-down rendering) scope; no data consumed |
| 3 orb counters | none -- reserved footprint only | E4/E5 scope; no data consumed |
| Pitch Zone slot + timer | none -- reserved footprint only | E6 scope; the centre "incoming telegraph" cue is a world-space cue, not a HUD element; both are positional placeholders only |
| Deck / reshuffle indicators | none -- reserved footprint only | E3 scope; no data consumed |

`connect_hit_landed`, `connect_deflect_landed`, `connect_hero_action_state_changed`, and `connect_hero_action_rejected` are NOT consumed anywhere in this story's HUD wiring -- those four seams stay fully owned by `TelegraphController`. Double-consuming them would recreate the retired overlay's job and blur the "telegraph owns combat events" line (2-4/R4).

### Observation seam amendment (2-4/R1)

The locked observation seam family goes from FOUR (`connect_hero_action_state_changed`, `connect_hero_action_rejected`, `connect_hit_landed`, `connect_deflect_landed`) to SEVEN, plus `EventBus.round_ended`, with the addition of `connect_hero_hp_changed`, `connect_stamina_changed`, `connect_mana_changed`. This is an AMENDMENT, recorded as CANONICAL in the decision log this session. The `game-architecture.md` text edit for this amendment is NOT made in this story -- it folds into the standing arch amendment queue (world-space facing contract, `null_controller.gd` in the Directory Tree, A3 stale-label cleanup, the gamepad exception to "named actions, never raw"). Rejected alternatives: a per-slot per-tick snapshot push (unnecessary -- the signals already exist; invites an opponent-read shape; risks a new state field and thus the golden), and any direct state read by the HUD (banned-token scan, no-handle rule).

### Debug overlay retirement (2-4/R3)

2-4 owns the retirement, not a later story. Nothing is inherited from the overlay: its `action_state_changed` role is already covered by `TelegraphController`; its `hit_landed` HP readout is superseded by the HUD HP bar. The overlay's `on_hero_transition` swing-count display and its `on_hit_landed` label have no HUD equivalent in this story and are not reconstructed -- they were combat-cue debug output, not economy display.

### Construction (2-4/R6)

The HUD root is a `Control` constructed in code and added as a child of each `SubViewport` -- the same CODE-CONSTRUCTION pattern the retired overlay used (`DebugStateOverlay.new()` then `add_child()`), reparented to a per-viewport `SubViewport` instead of the runner root, since the HUD must be per-viewport rather than a single global overlay. No edit to `main.tscn`. No new `.tscn` file -- a new scene would need hand-written content plus uid injection and carries editor-collateral risk for no benefit here. If the dev pass wants a scene file, that is a deviation raised at review, never a silent choice. Adds no camera, reparents no gameplay node, does not touch `data/camera_config.tres` (the sole framing source) -- any of those would violate the locked 2-1 topology.

### No-opponent-read is structural (2-4/R7)

The runner binds each HUD root only to its own slot's callbacks (the telegraph precedent), so the HUD is handed only its own player's payloads and structurally cannot reach the opponent. Pinned by test: each HUD root is wired with only its slot's economy callbacks. A comment is not enforcement. This is the habit that protects the E3 private hand.

### `_process` stays a story-level constraint (2-4/R9)

F1 bans only `_physics_process`; `project-context.md` explicitly permits `_process` for UI. The HUD is event-driven, but that discipline is review-checked, NOT machine-enforced -- no new invariant test is added for it.

### Named gap surfaces here, is not owned (2-4/R5)

The round-over label makes the open 2-3/R10 gap visible: `MatchState.advance()` has no early return on `_round_over`, so the label will say the round ended while the survivor still moves. 2-4 does NOT take ownership -- owner is decided at the E2 retrospective. This is EXPECTED, PRE-KNOWN behaviour for the Live Smoke below, not a new finding.

### Scope fences (2-4/R12)

2-5 owns all face-up/face-down hand logic (2-4 reserves footprint only). 2-6 owns the telegraph legibility protocol and the state inspector -- AC10 here is HUD-LAYOUT legibility and does not satisfy or partially satisfy DEBT E member 4. The centre "incoming telegraph" is a world-space cue, not a HUD element, and the pitch timer is E6 -- both positional placeholders only. E3 HOLD stands: no hand array read, no card widget. The mana bar is LIVE from E1 (2-4/R13, AC4) -- that liveness is unrelated to this fence and does not weaken it.

### Project Structure Notes

- `src/ui/hud/hud_root.gd` -- the HUD root `Control`, constructed in code, one instance per viewport.
- Three new seams on `src/main/match_runner.gd`: `connect_hero_hp_changed`, `connect_stamina_changed`, `connect_mana_changed`.
- `src/main/debug_state_overlay.gd` and `test/integration/test_debug_overlay.gd` (plus `.uid` companions) are DELETED this story; `test/integration/test_hud_viewports.gd` is ADDED.

### Project Context Rules

- **Signal-driven HUD:** no per-frame economy recompute. [Source: docs/project-context.md#Signals over polling; #Performance Rules]
- **P4 / Reactor-Actor:** reaction-critical info central; own-tempo info peripheral. [Source: gdd.md#P4; #Reactor / Actor principle]

### References

- [Source: stories-manual-e2.md#E2.S4]
- [Source: gdd.md#Legibility Principle; #Asset Requirements -- UI/HUD]
- [Source: docs/game-architecture.md#D5]
- [Source: decision-log.md -- 2-3 close-out NAMED GAP (post-round-over live match); 2-4 readiness gate, this session]

## Golden Hash

- **Current:** `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, unmoved since 1-9.
- **Prediction: NONE, measured in BOTH directions.** `src/ui/` files, the three new runner-side seam wrappers, and the overlay deletion touch no snapshot field -- the seams read existing pool/hero getters and re-emit existing signals; nothing is cached or newly stored. What would move it: any state-side drift -- a cached readout, a per-tick snapshot struct in state, a "round over" flag persisted into `to_snapshot()` (the 1-9 `roll_direction` precedent, and exactly why 2-3 implemented the facing-freeze by NOT writing).
- **Baseline to record:** golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, suite 156 state tests / 714 assertions + 8 integration (run INDIVIDUALLY).
- **Discipline:** measured in both directions; movement is stop-and-report, never a re-baseline.

## Live Smoke

- Runs on the shipped default `slot_controller_kinds = [0, 1]` (two live killable humans) -- no flip line, no manual `.tscn` edit of any kind.
- Measured in the HALF viewport, never full-width -- half-width legibility is the reason split-screen was pulled forward to E2.
- Must include an explicit legibility judgement (every reserved element identifiable, nothing clipped by the split boundary or the camera's arena view).
- The known-and-parked 2-3/R10 "post-round-over live match" gap is named here so it is NOT reported as a new finding: the round-over label will read while the surviving hero keeps moving.
- **R-D6 smoke acceptance is RE-INVOKED by this story** (live smoke against killable human slots) and becomes SPENT again only on a pass.
- If the smoke produces findings, the operator writes the `docs/playtest-log.md` entry BEFORE the commit chain.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.8

### Debug Log References

### Completion Notes List

- Golden measured in BOTH directions: `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` before this commit chain (baseline, unchanged since 1-9) and again after -- unmoved. Suite 156 tests / 715 assertions (156/714 -> 156/715, the new `hud_root.gd` existence guard in `test_architecture_invariants.gd` is the added assertion), all 8 integration tests run INDIVIDUALLY and PASS, including `test_hud_viewports.gd` replacing the retired `test_debug_overlay.gd` (baseline held at 8, did not drop to 7).
- `.uid` scan: after `hud_root.gd` / `test_hud_viewports.gd` were added, the scan produced exactly 2 new `.uid` files (`src/ui/hud/hud_root.gd.uid`, `test/integration/test_hud_viewports.gd.uid`) plus the 2 expected deletions (`debug_state_overlay.gd.uid`, `test_debug_overlay.gd.uid`). Zero collateral elsewhere in the tree -- no `main.tscn` diff, no `physics_ticks_per_second` reorder, no `camera_config.tres` touch. Verified this session via `git diff --stat -- '*.uid'` against the full repo, not just the touched paths.
- Review pass this session (D1): the `connect_hero_hp_changed` / `connect_stamina_changed` / `connect_mana_changed` prime-on-connect calls were temporarily stripped from `match_runner.gd` and `test_hud_viewports.gd` was re-run -- it FAILED (`primed_ok=false`), proving the AC2 priming guard actually bites rather than passing vacuously. `match_runner.gd` was then restored via `git checkout` and its SHA256 (`c22e79d2...`) verified byte-for-byte identical to the pre-mutation file. No further review findings surfaced -- `EventBus.round_ended` payload order was independently cross-checked against `signal round_ended(loser_index: int)` in `event_bus.gd` and the `.bind(slot)` pattern matches the existing `TelegraphController.on_round_ended` precedent exactly.
- AC10 (legibility at real half-width size) was verified via the operator's own live smoke against the shipped two-human default, not an agent-taken screenshot -- this session ran headless only (no editor, no game launch), per chain instructions. See `docs/playtest-log.md` (2026-07-28 entry, operator's own hand) and the decision-log close-out for the recorded findings (pitch-zone centring, card-icon size).
- Live smoke (operator, second two-human smoke): HUD confined to its own half in both viewports, priming live (HP/stamina full, mana empty at start), mana rises on confirmed hits, win/lose labels render and persist through a debug reset (see decision-log MICRO-DECISION 1), fps fine, zero manual `.tscn` edits, zero collateral. Two findings recorded, both deferred (see decision-log): pitch-zone centring (S1) and card-slot legibility pending real art (S2).

### File List

- Modified: `src/main/match_runner.gd` -- three new per-slot economy seams; debug overlay wiring replaced with per-viewport `HudRoot` construction.
- Modified: `test/state/test_architecture_invariants.gd` -- `hud_root.gd` existence guard added to `test_cues_layer_never_calls_state_mutators`.
- Added: `src/ui/hud/hud_root.gd` (+ `.uid`) -- the per-viewport HUD root.
- Added: `test/integration/test_hud_viewports.gd` (+ `.uid`) -- replaces `test_debug_overlay.gd`; proves per-viewport HUD existence, prime-on-connect, and per-slot binding asymmetry.
- Deleted: `src/main/debug_state_overlay.gd` (+ `.uid`) -- retired (2-4/R3).
- Deleted: `test/integration/test_debug_overlay.gd` (+ `.uid`) -- retired, superseded by `test_hud_viewports.gd`.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-28 | 1.0 | Dev pass: three primed per-slot economy seams, code-constructed per-viewport HudRoot, debug overlay retired, live smoke passed with two findings deferred to E2 retro. | Claude Opus 4.8 |
