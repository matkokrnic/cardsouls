---
baseline_commit: 684d7337e566d1b6d5b2dbddaa4246e7922c7638
---

# Story 7-11: Control Scheme v2

Status: ready-for-dev

> **Scope note.** `epic-7` story, **Tier A** (operator ruling R10, 2026-10-28 scope talk; `E4-P/R9` —
> raised by ruling, the golden is still predicted UNMOVED). Source: the 2026-10-17 three-player
> playtest (`docs/playtest-log.md:722`, the 2026-10-17 entry), where the L3-held card mode was the
> biggest complaint. The decision-log entry for that session (`decision-log.md:12920-12928`) records
> only the tuning numbers; rulings R1-R10 and the scope-talk rulings G1-G5 (2026-10-28, after the
> readiness gate) are recorded only here until the close-out. All citations measured at `684d733`.

## Story

As a player on a pad,
I want to pick a card with one D-pad tap and play it with one button, with no held modifier,
so that playing cards never takes my hands off attack, block, roll and run.

## Operator Rulings (2026-10-28) — carried as given

- **R1 Arming.** A D-pad TAP (press edge) arms hand slot 1..4. Sticky: the armed slot stays armed
  until the armed card is played (X/Y/R2/L2) or another direction is tapped (refined by G1: until it
  LEAVES its slot); re-tapping the armed direction keeps it armed. Free, silent, SECRET (own HUD half only). Default map left=1, up=2,
  down=3, right=4 — data in the profile, remappable. Two directions in one frame: deterministic
  tie-break pinned by test (5-0b/5-7 chord precedent). Playing the armed card clears the arm (no
  auto-arm of the refilled card, 4-0 refill-in-place). Round end clears it; knockdown does not.
- **R2 Play buttons, no modifier, no card mode.** X = play armed (mode ① BASIC), Y = pitch (mode ④),
  R2 = unblockable (mode ②), L2 = defense by colour (mode ③). L1/R1/A/B/R3 and sticks keep today's
  NON-card meaning; A and B lose their card-mode meanings. L3 and the D-pad-down modifier disappear,
  and with them `card_mode_toggle` (6-10), the card-mode hand lift, and the attack/block/roll
  suppression that existed only under the held mode. The old scheme is NOT kept behind a switch.
- **R3 Y rule.** Pitch zone READY → Y activates the staged pitch; otherwise Y pitches the armed card.
- **R4 Nothing armed.** X/R2/L2 (and Y without a READY zone) emit nothing — no commit reaches state —
  and the own HUD half blinks the D-pad hint. Armed but EMPTY slot: the commit IS emitted and the
  existing state-side empty-slot refusal handles it (5-7 precedent). (Mechanism per G3: the felt
  behaviour stands, but the nothing-armed commit IS emitted and state refuses it.)
- **R5 Profile per SLOT + `user://` persistence.** A per-slot override file is loaded when present,
  else the `.tres` default. A layout is a remap of the same mechanism expressed as data — never a
  second input mechanism. 7-11 ships the data path only; the editing UI is 7-12. Tests never touch
  the real `user://` — the path is injectable.
- **R6 HUD hand layout**, a 3-way switch in the per-slot profile: ROW (today), ROW+GLYPH (a D-pad
  direction badge on each card), DIAMOND (cards at the four D-pad positions). Default ROW+GLYPH;
  tests pin the default, DIAMOND is smoke-covered only. Glyphs procedural (drawn or font glyph), no
  new binary assets; card faces stay text-free (7-6). The armed card keeps a visible highlight on
  the own half; the pitch-ready cue (7-7 pre-playtest) is untouched.
- **R7 Keyboard parity.** Keys 1..4 arm (sticky, same rules); the keyboard keeps exactly the card
  modes it has today, converted to the arm model — no new keyboard modes.
- **R8 State untouched.** `src/state/` byte-identical; intent fields reused as they are;
  `FORMAT_VERSION` stays 25; golden UNMOVED both directions. A needed state change or new intent
  field is an operator scope question: STOP and report.
- **R9 Replay.** Measured below (M6): what a pre-7-11 recording means after 7-11, and the pinning test.
- **R10 Tier A, full ritual.** Suite as state (one foreground call) + integration (two foreground
  calls, timeout 600000 ms), outputs written outside the repo.

## Measured for this story (create pass, 2026-10-28, at `684d733`)

### M1 — Today's pad scheme and the current → v2 table

One `GamepadProfile` (`src/controllers/gamepad_profile.gd`), shipped as `data/gamepad_profile.tres`.
Decision logic is the pure `GamepadController.resolve_card_tick` (`gamepad_controller.gd:410-496`);
`sample()` only reads raw device state (`:134-259`; `:181-259` is the half after the neutral path).

| Input | Today (field, cite) | v2 |
|---|---|---|
| L3 | `cast_button` (`gamepad_profile.gd:69`, `.tres:17` = 7): card mode, HOLD = raw level, TOGGLE = press edge flips (`gamepad_controller.gd:193,197,523-540`) | no card meaning; field retired |
| D-pad Down | `card_mode_alt_button` (`gamepad_profile.gd:74`, not authored in `.tres` → default), OR-ed into L3 (`gamepad_controller.gd:196`) | arms slot 3 |
| D-pad Left / Up / Right | unbound (no other `DPAD` read in `src/`) | arm slots 1 / 2 / 4 |
| `card_mode_toggle` | HOLD/TOGGLE switch (`gamepad_profile.gd:83`, absent from `.tres` → HOLD) | retired |
| L2 (axis) | in mode only: arms slot index 0 (`gamepad_controller.gd:439-440`); outside mode: nothing | DEFENSE play (mode ③) |
| R2 (axis) | in mode only: arms slot index 3 (`:445-446`); outside mode: nothing | UNBLOCKABLE play (mode ②) |
| L1 | `block_button` (`gamepad_profile.gd:27`); in mode: arms index 1, block suppressed (`:441-442,480-481`) | block only |
| R1 | `attack_button` (`:26`); in mode: arms index 2, attack suppressed (`:443-444,478-479`) | attack only |
| A | `cast_basic_button` (`:89`): run when held outside mode (`gamepad_controller.gd:488`); BASIC confirm in mode (`:456-459`) | run only |
| B | `roll_button` (`:28`) roll; `cast_unblockable_button` (`:109`) UNBLOCKABLE confirm in mode (`:460-463`) | roll only |
| X | `cast_defense_button` (`:110`): DEFENSE confirm in mode (`:448-451`); outside: nothing | BASIC play (mode ①) |
| Y | `cast_pitch_button` (`:119`): in mode STAGE armed (`:452-455`); outside ACTIVATE (`:464-470`) | READY zone → activate; else stage armed (R3) |
| R3, sticks | lock / flick / camera rotate / move (`:43-45`, `gamepad_controller.gd:271-283`) | unchanged |

**Displaced actions:** none — L2/R2 only arm a slot today, inside card mode; A and B lose only their
in-mode confirms (run and roll untouched). **Slot numbering:** R1's slots 1..4 are code indexes 0..3
(`Hand`, `card_slot`): left→0, up→1, down→2, right→3. **Y guard:** the 5-7 "no field carries
`JOY_BUTTON_Y`" guard was retired at 6-3a (`6-3-split/R-Y`, `test_gamepad_controller.gd:314-322`); its
replacement (`:323-341`) stays TRUE → KEEP; re-measure its `>= 8` button-field floor (`:330`) against
the v2 field list. **Chords today:** arming L2, L1, R1, R2, last write wins (`:350-354`, `:438-446`);
confirms X, Y, A, B, last write wins (`:405-409`, `:447-463`).

### M2 — Pinned pad/keyboard/HUD tests: disposition

RETIRE = the NAME asserts a now-false claim (deleted; the replacement gets a new name); REWRITE = name
still true, body changes; KEEP = untouched. The dev pass re-verifies each against its body first.

**`test/state/test_gamepad_controller.gd`** (33)
- KEEP 9: `no_pad_connected_yields_neutral_intent`, `below_deadzone_resolves_to_zero_vector`, `above_deadzone_normalized_to_unit_length`,
  `gamepad_stick_up_matches_keyboard_up`, `analog_intent_and_keyboard_intent_produce_identical_snapshots`,
  `gamepad_ordinal_is_pure_function_of_config`, `resolve_camera_rotate_dead_zone_linear_and_signed`,
  `resolve_trigger_edge_requires_crossing_not_holding`, `cast_pitch_button_reads_y_on_the_default_and_the_shipped_profile`.
- REWRITE 6: `replug_priming_covers_the_new_commit_edges` (prime X/Y/L2/R2/D-pad), `resolve_card_tick_produces_exactly_the_live_held_keys`,
  `card_scheme_and_lock_on_paths_are_disjoint` (markers `:719-744` move), `sample_carries_y_and_card_activate_into_the_intent`;
  per G3 `resolve_card_tick_basic_always_commits_on_fresh_press` (`:277`) and
  `resolve_card_tick_mode_confirms_commit_empty_slot_rather_than_swallow` (`:394`) — X/R2/L2, no modifier, slot -1.
- RETIRE 18: `resolve_card_tick_arms_slots_left_to_right`, `resolve_card_tick_same_tick_chord_resolves_rightmost`,
  `resolve_card_tick_trigger_already_held_does_not_rearm`, `resolve_card_tick_b_commits_unblockable_and_x_commits_defense`,
  `mode_confirms_do_nothing_outside_cast_mode`, `resolve_card_tick_same_tick_confirm_chord_resolves_rightmost`,
  `mode_confirm_exit_edge_sequences`, `mode_confirms_add_no_suppression_rule`, `arming_chord_is_untouched_by_the_new_confirm_buttons`,
  `resolve_card_tick_suppresses_attack_block_roll_while_cast_held`, `resolve_card_tick_restores_attack_block_roll_the_tick_after_release`,
  `resolve_card_tick_clears_armed_slot_the_same_tick_cast_releases`, `resolve_card_tick_exit_edge_sequences`,
  `y_inside_cast_mode_stages_the_armed_slot`, `bare_y_outside_cast_mode_activates`, `card_activate_is_raised_only_by_a_bare_y`,
  `four_confirm_chord_resolves_in_the_order_x_y_a_b`, `replug_priming_covers_the_pitch_edge_on_both_sides_of_the_modifier`.

**`test_card_mode_toggle.gd`** (20, 6-10): RETIRE 19 (HOLD/TOGGLE, L3 edge memory, `force_card_mode_off`, slot -1
under TOGGLE); REWRITE 1 `base_controller_defaults_are_inert` (v2 base accessors; lands in `test_controller.gd` or
the new v2 file, dev call); the file goes. **`test_locomotion_gaits.gd`**: RETIRE 1
`resolve_card_tick_run_held_true_on_bare_a_false_under_cast_held` (`:339`) → "bare A held → `run_held`, always". **`test_controller.gd`** (12):
KEEP all. **`test_deck_and_hand.gd`**: REWRITE 2 (G2) `card_scheme_input_actions_ship_for_both_players`
(`:517-527`) and `shipped_input_map_action_set_is_exactly_pinned` (`:579`; `SHIPPED_INPUT_ACTIONS` loses
`p1_cast_mode`/`p2_cast_mode`, `:546,566`); KEEP 1 `no_physical_key_backs_two_project_actions` (`:611-625`, 5-5/R8;
still compares several dozen keyed actions, has no floor — the dev reports the measured count, no test edit).
**`test_data_resources.gd`**: KEEP 2 (`:489`, `:498`). **`test_architecture_invariants.gd`**: KEEP
`test_card_scheme_only_in_controllers` (`:683`, tokens `:678-680`; non-vacuity met by `cast_confirm`/`card_N`).

**Integration**: RETIRE 1 `test_card_mode_lift.gd` (its round-end/reset half re-pinned by the arm-clear test, AC 4).
REWRITE 16: `test_card_selection_indicator.gd` (`:73-91` "releasing the modifier disarms" → sticky),
`test_card_face.gd` (`:476-530`; `:525-527` "mode off + armed: no lift" inverted by G4), and the G2 SWEEP — each
press/release of the removed `pX_cast_mode` BREAKS, so drop it and drive `pX_card_N` + `pX_cast_confirm` in
`test_hole_vs_in_flight_live`, `test_hound_spawn_live` (`:75,85` and the `_finish` loop `:232`), `test_summon_actor_live`,
`test_unit_combat_live`, `test_unit_corpse_walkthrough_live`, `test_unit_corpse_linger_live`, `test_unit_swing_root_live`,
`test_unit_strike_alignment_live`, `test_unit_attack_live`, `test_unit_spawn_placement_live`, `test_unit_approach_live`,
`test_unit_aim_live`, `test_summon_spawn_containment_live`, `test_two_units_converge_live`. Same sweep, uncounted:
`test/perf/perf_20_units_live.gd:461,504`, `flags_off_live.gd:109,125`, `test/run_all.sh:29` (`VERBOSE_FILES`
names the retired file). Fixture `fake_mode_controller.gd` (sole consumer `test_card_mode_lift.gd:27`): REWRITE if
the arm-clear test uses it, else DELETE (dev call). CONDITIONAL (G4) `test_hud_viewports.gd:263`: KEEP if
`CARD_MODE_ARMED_LIFT_PX` keeps name and 24 px. Re-verify `test_card_tint_live.gd:211,217` if `set_card_selection` changes.

**Totals: RETIRE 39 · REWRITE 25 (+1 fixture, +1 conditional) · KEEP 27** (incl. M6's two). New tests: see AC.

### M3 — Keyboard today

`KeyboardController._sample_card_scheme` (`keyboard_controller.gd:204-221`): HOLD `pX_cast_mode`, PRESS `pX_card_1..4`
arms, PRESS `pX_cast_confirm` commits BASIC; release disarms (`:205-207`). BASIC is the only mode (`:212-217`); a
confirm with nothing armed still commits slot -1 (`:218-221`). The P1 debug keys (`:145-160`, 6-D1) are untouched.
Keys are **Input Map actions**: P1 `Q`/`1-4`/`E`, P2 `O`/`6-9`/`P` (`project.godot:151-210`); R7 reads the existing
`pX_card_N` / `pX_cast_confirm`. **G2:** `pX_cast_mode` is REMOVED (5-7 precedent) — the `project.godot` diff is exactly
the two deletions (`:151-155` Q=81, `:181-185` O=79); Q and O are freed, not reassigned; nothing is added. The 5-5/R8
guard (`test_deck_and_hand.gd:611`) stays green and non-vacuous (M2). D3(a): the pad reads raw device buttons, no pad action.

### M4 — Profile per slot

`_make_controller` (`match_runner.gd:2680-2698`) loads `res://data/gamepad_profile.tres` for **every** GAMEPAD slot
(`:2695-2696`) — one resource serves both seats; keyboard slots have no profile. `slot_controller_kinds` (`:30`), ordinal
by `_gamepad_ordinal_for_slot` (`:2705-2710`). The debug panel's handoff (`:784`) stores the profile but reads no field
(`debug_instrument_panel.gd:64`) — untouched. `user://` precedent: `RecordFile` only (`record_file.gd:452,546`;
containment `_outside_user_directory` `:789-797`, `3-0d/R22`; `project-context.md:173`). That helper is private and
hard-codes the root to `user://` (`:790`), so it would refuse an injected test root. **Locked shape:** lift the
normalisation into a static helper with a `root` parameter; `RecordFile`'s guard calls it with `user://`, unchanged.

**Override file (named here):** `user://controls/slot_<N>.cfg`, N = 1 or 2 (player slot, not pad ordinal), read once at
`_make_controller` time, root injectable; the test root sits outside both `user://` and the repo tree (dev names it).
Format is a dev call, data only — never a `.tres`/`.res` through `ResourceLoader` from a user-writable path (a resource
can embed script). Missing, malformed, or a binding duplicating another role's button (the distinctness guard
`test_data_resources.gd:498-508` covers only attack/block/roll) → the shipped default with a printed reason, never a crash.

### M5 — HUD

Hand row: `_build_hand_row` (`hud_root.gd:1452-1469`), card x = `i * (CARD_SIZE.x + CARD_GAP)`, arc raise on indices 1-2
(`:1479`, `:1794-1795`). Lift knobs `CARD_MODE_ROW_LIFT_PX` 6.0 / `CARD_MODE_ARMED_LIFT_PX` 24.0 (`:240-241`), armed gold
frame + glow (`:244-246`), applied in `_apply_selection` (`:1779-1790`) from `set_card_selection` (`:1761`) and
`set_card_mode` (`:1769`), pushed every frame outside the ticking gate (`match_runner.gd:5624-5627`). Pitch-ready cue
`_own_card_pitch_ready` (`hud_root.gd:351`, built `:1558`, shown `:863-867`) — untouched. Height budget (`:139`):
8 + 158 + 24 + 4 = 194 of 196 — a ROW+GLYPH badge sits inside the card rect or the 2 px headroom (geometry by test).

**Arm-clear channel for G1 (measured).** `cards_changed(hand_ids, deck_count, discard_count)` (`player_state.gd:31`) has
no per-slot field; `hand_ids` is the VISIBLE layer, BOUND at push time (`:1454-1455`). Today's controller push is colours
(`match_runner.gd:740-745`) — useless for G1 (a same-colour or same-id refill looks unchanged). **Do NOT use** the
wrapper's inline `player.hand.to_array()` (`:739`): read live at drain, it shows a same-drain refill at both emissions.
Every card-layer removal is `remove_at` (`match_state.gd:4636,6683,7033,7172`), each followed by its own notify
(`:4774,6697,7075,7234`) before any refill; refill exists only at the deal (`:4380`) and the pending-draw delivery
(`:8577`, notify `:8583`); covers and discounts notify but never change the card layer. **Mechanism (dev call):** the
runner wrapper also pushes the bound `hand_ids` (plain `Array[StringName]`); the controller clears the arm when an
emission's id at the armed slot goes non-EMPTY → EMPTY — the event's own payload, never a sample landing in the empty
window, so a same-id refill still clears. A headless test pins it with a ZERO draw delay (script default
`balance_config.gd:134`; refill on the cast tick, `match_state.gd:976-979`) and the same id refilled.

**Refusal channel for G3 (measured).** `HeroState.action_rejected(action, reason)` (`hero_state.gd:21`, `reject_action`
`:284-285`); reason `CastEvaluator.REASON_EMPTY_SLOT` (`cast_evaluator.gd:32`) for slot -1 on all four seats
(`match_state.gd:4568-4569,6623-6624,6990-6991,7151-7152`; pinned by `test_card_play.gd:143`); runner seam
`connect_hero_action_rejected` (`match_runner.gd:2808-2811`). The HUD may NOT subscribe (`2-4/R4`, `hud_root.gd:16-17`):
the runner wraps the seam per slot and, on an own `&"card_cast"` refusal while that slot's `armed_slot() == -1`, pushes
a plain blink to that slot's OWN HUD. Keyed on ANY reason — the get-up/counter/cast gates (`match_state.gd:4433-4468`)
and the flag/charging/stunned/covered gates answer first. DEAD or round-over: silent (`:4422-4423`), no blink.

**READY channel for R3 (the controller must not read state):** `pitch_changed(slot, card_id, hand_slot, ready, …)`
(`match_state.gd:53-54`), the runner's tenth seam `connect_pitch_changed` (`match_runner.gd:2832-2833`), wired to both
HUDs (`:750`); it fires on stage, activate, expiry, debug reset, an orb grant in a staged window, and the countdown
throttle (`match_state.gd:49-52,971-974`). The runner relays the OWN slot's `ready` to that slot's controller on the
`observe_hand_colors` precedent (`controller.gd:42`, wired `match_runner.gd:745`) — plain bool; the seam is match-level,
so the wrapper filters `slot == own` (`hud_root.gd:598`) and captures no `PlayerState` (4-B1, `match_runner.gd:719-725`).
A stale TRUE between throttle refreshes (`match_state.gd:964-974`) at worst reaches the not-ready refusal; the arm is
unaffected. Y on a staged, not-READY zone with a card armed now stages it and is refused `REASON_PITCH_ZONE_OCCUPIED`
(`:6626-6627`) where a bare Y gave `pitch_not_ready` — same outcome, new reason, not a regression.

### M6 — Intent / replay (R9)

`RecordFile.FORMAT_VERSION := 25` (`record_file.gd:441`). `IntentRecorder.copy_intent` (`intent_recorder.gd:717-731`)
copies the ten `InputIntent` fields verbatim per tick per slot. Card mode entry/exit was never an intent field
(`card_mode_on()` is controller-local, `controller.gd:24-29`); the recorder sees only resolved intents. **Meaning after
7-11:** a v25 record made before 7-11 replays bit-identically — `ReplayController` feeds recorded intents and runs no
controller scheme. Pinned by `test_intent_recorder.gd::test_all_ten_input_intent_fields_round_trip_per_tick_per_slot`
(`:248`) and `test_replay_identity.gd::test_a_driven_run_replays_from_the_record_alone_to_a_bit_identical_hash` (`:675`)
— both KEEP, unedited. No record fixture is tracked (`decision-log.md:12897`). State reads `card_slot` only under the
commit guard (`match_state.gd:4420,4475-4496`), never in the snapshot; the keyboard writes it every in-mode tick today
(`keyboard_controller.gd:211`) and the record serialises it per tick (`record_file.gd:906`). So the armed slot may stay
controller-local with `card_slot` set only on commit ticks (dev call; forward-compatible with lockstep secrecy) — v2
records then differ in bytes from pre-7-11 ones for identical play, replay unaffected.

## Acceptance Criteria

Marks: **[M]** headless-tested (state harness or integration), **[S]** smoke-only.

**Arming (R1, G1)**
1. [M] A D-pad press edge arms the slot the profile maps to that direction (default left/up/down/right
   → slots 1/2/3/4). Holding a direction arms once. Re-tapping the armed direction keeps it armed;
   tapping another direction moves the arm. Arming emits no commit and no sound.
2. [M] Two directions pressed on the same sample resolve to exactly one armed slot by a fixed rule
   pinned by test — applied precedent (5-0b): evaluated in slot order, last write wins, so the
   HIGHER slot index wins, independent of the direction map.
3. [M] (G1) The arm clears when the armed card LEAVES its hand slot, by the M5 arm-clear mechanism —
   never on commit emission. A refused play (not enough mana, not ready, any refusal) keeps the arm.
   An accepted play or a pitch stage clears it; the refilled card is NOT auto-armed, and a refill of
   the SAME card id still clears (zero-delay test, M5). A Y ACTIVATION does not clear it (nothing
   leaves). Boulder (scope-talk ruling Q1): the arm SURVIVES a Boulder covering the armed slot and
   SURVIVES the X that clears that Boulder; the next X plays the card underneath.
4. [M] Round end clears the arm on both seats; a debug reset (`round_started`) clears it too.
   Knockdown and ordinary stun do NOT clear it. A pad disconnect clears it (the existing neutral path,
   `gamepad_controller.gd:138-173`) and primes every v2 edge HELD so a replug fires nothing.

**Play buttons (R2, R3, R4, G3)**
5. [M] X / R2 / L2 / Y(stage) with a slot armed emit `card_commit` with `card_slot` = armed slot and
   `card_mode` BASIC / UNBLOCKABLE / DEFENSE / PITCH respectively (`card_activate` false). R2 and L2
   use the existing trigger-crossing edge (`resolve_trigger_edge`, `:333-334`). A same-sample chord
   of play buttons resolves to at most one commit by a fixed order pinned by test.
6. [M] Y with the own pitch zone READY (M5 channel) emits PITCH, `card_activate` true, `card_slot` -1,
   whatever is armed. Otherwise Y follows AC 5 / AC 7.
7. [M] (G3) Nothing armed: X, R2, L2, and Y without a READY zone still emit the commit with
   `card_slot` -1 (`5-0b/R1` — the controller never swallows); state's empty-slot refusal answers it.
   An armed slot that is EMPTY likewise emits, and state refuses it.
8. [M] L1/R1/A/B/R3 and both sticks behave exactly as today with no suppression at any time: R1
   attacks, L1 blocks, B rolls, A held runs, R3 locks. L3 and D-pad Down have no card meaning.
9. [M] `card_mode_toggle`, `cast_button`, `card_mode_alt_button`, `card_mode_on()`,
   `force_card_mode_off()` and the HOLD/TOGGLE logic are deleted, not dormant (R2: one scheme).

**Profile and persistence (R5)**
10. [M] Each GAMEPAD slot gets its own profile instance: the slot's override file if present and valid,
    else the shipped `.tres`. Editing one slot's file changes only that slot. Role→button bindings,
    direction→slot map and hand layout are all profile data; no INPUT code path branches on a layout
    name (G5 — the HUD branches on the hand-layout enum by design).
11. [M] The override root is injectable; no test reads or writes the real `user://`, and the test
    root is outside both `user://` and the repo. The override path is globalised, simplified and
    contained under the resolved injected root plus separator (`project-context.md:173`, `3-0d/R22`)
    through the M4 locked helper. A missing, malformed, partially-filled or duplicate-binding file
    falls back field-by-field or wholesale (dev call, stated in Completion Notes) without crashing.

**HUD (R6, R4, G3, G4)**
12. [M] Hand layout is ROW / ROW+GLYPH / DIAMOND from the slot's profile; the shipped default is
    ROW+GLYPH, pinned by test on the shipped `.tres`. ROW is today's geometry. ROW+GLYPH adds a
    procedural D-pad direction badge per card that follows the profile's direction map. DIAMOND places
    the four cards at the D-pad positions ([S] fit and legibility). Keyboard slots render ROW;
    keyboard layout data waits for 7-12. Card faces stay text-free; no new binary asset.
13. [M] The armed card shows a visible highlight on the own half only; the opponent's half shows
    nothing of it (secret). The card-mode row lift is gone. In ROW and ROW+GLYPH the armed card rises
    24 px with its gold frame; in DIAMOND the frame alone marks it ([S] fit). The pitch-ready cue is
    unchanged.
14. [M] (G3, Q2) A nothing-armed press (AC 7) reaches state and plays the existing reject sound like
    any refused cast; alongside it the own half — only — blinks the D-pad hint, pushed by the
    runner's per-slot wrap of `connect_hero_action_rejected` (M5; the HUD never subscribes, `2-4/R4`),
    keyed on any reason while `armed_slot() == -1`, silent when DEAD / round-over (stated in
    Completion Notes). The blink is one ~0.4 s pulse, no new sound, a presentation constant ([S] look).

**Keyboard (R7)**
15. [M] `pX_card_1..4` press arms that slot with AC 1-4's rules (sticky; no modifier).
    `pX_cast_confirm` plays BASIC; with nothing armed it still emits the slot -1 commit, state refuses
    it and the own half blinks (AC 14). No other keyboard mode is added. The 6-D1 P1 debug keys behave
    as today.

**State, golden, replay (R8, R9)**
16. [M] `git diff -- src/state/` is empty; `FORMAT_VERSION` 25; no `InputIntent` field added.
17. [M] Golden `97c9a1de…29da96` with 66 per-player snapshot keys, measured before AND after, both
    directions (the reverse probe of a non-mover: the dev pass reports the before/after `measure`
    output identical).
18. [M] M6's two replay tests pass unedited.

**Invariants, tests, ritual (R10)**
19. [M] F1, D3(a), D3(b)/A2 suites green. The `project.godot` diff is exactly the two `pX_cast_mode`
    deletions (G2); the `src/main/main.tscn` diff is empty.
20. [M] Every M2 RETIRE is deleted, every REWRITE lands, and each new pure function (arming, play
    resolution, Y rule, tie-breaks, priming, arm-clear) has a headless test; each new guard is
    mutation-proven (restore from an out-of-repo copy, never `git checkout`).
21. [M] (R10) Tier A ritual: suite before and after as state (one foreground call) + integration
    (two foreground calls, timeout 600000 ms), outputs written outside the repo.

## Golden Prediction

**PREDICTED UNMOVED, both directions.** Everything in scope lives in `src/controllers/`, `src/ui/`,
`src/main/match_runner.gd` presentation pushes and `data/`. The scheme reaches state only through the
four existing intent card fields; the golden is driven by synthesized intents, not controllers. If it
moves, the cause is not the scheme by construction — find it and report; do not re-baseline (R8).

## Non-Goals

Pause/rematch menu and the controls-editing UI (7-12); camera pitch when not locked (6-8 amendment);
card type icons (7-6 follow-up); counter-ready cue (its own story); any balance number;
minion-spam punishment; Deck 2 visuals; netcode.

## What this story supersedes

- By ID (`decision-log.md`): `5-0b/R3` (`:8308-8310`, provisional mapping) and the GDD open item
  "card-mode-select UX" (`:94`; `:9000-9001`; `gamepad_profile.gd:103-104`) — answered by R1-R2,
  pending this story's smoke; the `5-0b` accepted finding "commit does not disarm the slot" (`:8320`)
  → G1; `5-7/R1` (`:8996`, dedicated B/X fields); `5-7/R2` (`:9003`, X-A-B chord); `6-3a/R2`
  (`:10326`, X,Y,A,B order); `6-10/R1`, `R2`, `R5`, `R6`, `R8` (both schemes removed), `R10`(1) (base
  methods) and (5) (lift), `R11` (knockdown poll), `R16` (HOLD/TOGGLE choice and smoke 8b discharged)
  (`:11053-11097`); `6-10/R3` knockdown forced-off REVERSED (AC 4) — its disconnect / round-end /
  reset clears re-homed onto the arm; `6-10/R4` replaced by G1; `7-6/P3` (`:12456`, lift amounts and
  "never lifts alone").
- By story text: `5-0b` AC 1-5 (held L3, L2/L1/R1/R2 arming, A confirm, suppression); `5-7` AC 1/9;
  `6-3a` AC 2 (Y on both sides of the modifier → R3); `6-7` AC 4's "suppressed under cast_held" half
  (bare-A run kept); `7-7` pre-playtest `card_mode_alt_button`; `3-5a` keyboard HOLD modifier (R7).
- KEPT: `5-0b/R1` (`:8300`) and `5-7/R5` (`:9018`) — the slot -1 commit is still emitted (G3);
  `7-6/P14` frame, `7-6/P17` covered slot arms. CONSTRAINT: `2-4/R4` (HUD never consumes `action_rejected`).

## Resolved rulings (2026-10-28)

Scope-talk rulings 2026-10-28, given after the readiness gate (labels local; numbered at close-out).
- **G1** The arm clears when the armed card actually leaves its slot, not on commit emission; a refused
  play keeps it (AC 3, mechanism M5). **Q1** Boulder: the arm survives the cover and the X that clears it.
- **G2** `pX_cast_mode` is removed (M3, AC 19); Q and O freed, not reassigned.
- **G3** State's refusal signal exists (M5): the controller emits slot -1, state refuses, the own half
  blinks (AC 7, 14, 15). **Q2** The existing reject sound plays; the blink adds no sound.
- **G4** Armed card rises 24 px in ROW and ROW+GLYPH, frame only in DIAMOND (AC 13); blink one ~0.4 s
  pulse, no sound, a presentation constant (AC 14); keyboard hand = ROW (AC 12).
- **G5** No INPUT code path branches on a layout name (AC 10). **G6** File is UTF-8, no BOM.
No open question remains. Implementation choices (not questions): profile field names and role
mapping; the override file format (data-only, AC 11); relay method names (READY, hand ids, blink);
whether `resolve_card_tick` is replaced or re-signatured; glyph technique; where the 6-10 base test lands.

## Deferred

- Keyboard layout/remap data (7-12, G4).
- Architecture-amendment candidate for the E7 close-out: per-slot controller profiles with a
  `user://` override are a new seam.

## Tasks / Subtasks

- [ ] Before-measurement (outside the repo): state suite (one call), integration (two calls, 600000 ms),
      golden + key count, `git diff --stat -- src/state/ project.godot src/main/main.tscn` (AC 16-19, 21)
- [ ] Profile: retire `cast_button` / `card_mode_alt_button` / `card_mode_toggle` and the role fields
      v2 no longer uses; add play-role buttons, D-pad direction→slot map, hand layout enum; author
      the shipped `.tres` explicitly incl. the ROW+GLYPH default (AC 9, 10, 12)
- [ ] Per-slot load in `_make_controller`, injectable root, M4 containment helper, fallback (AC 10, 11)
- [ ] `project.godot`: delete `p1_cast_mode`/`p2_cast_mode` only (AC 19, G2)
- [ ] `GamepadController`: pure v2 decision (arming, tie-break, plays, Y rule, slot -1 emit, priming,
      arm-clear on leave); delete HOLD/TOGGLE/suppression (AC 1-9)
- [ ] `Controller` base: drop `card_mode_on`/`force_card_mode_off`; add the READY and hand-ids pushes;
      runner relays own-slot `ready` and the bound `hand_ids` (M5), wraps `connect_hero_action_rejected`
      for the own-HUD blink; round end / debug reset clear the arm via the existing relays
      (`match_runner.gd:2852,2861`); remove the knockdown poll (`:5618-5622`) (AC 3, 4, 6, 7, 14)
- [ ] `KeyboardController`: arm model, no modifier, nothing-armed still emits slot -1 (AC 15)
- [ ] HUD: remove row lift, armed rise/frame (G4), three layouts, glyph badges, blink; own half only
      (AC 12-14)
- [ ] Tests per M2 dispositions + new tests (AC 20); mutation-prove new guards
- [ ] After-measurement: full suite, golden both directions, diffs (AC 16-19, 21)
- [ ] Live Smoke handed to the operator

## Live Smoke

Shipped defaults unless named. Verdict per item; headline = worst item (`E6-R/R9`).

**Solo [0,3]** (P1 keyboard, P2 pad):
1. Pad: tap each D-pad direction — the matching card shows armed, no sound; re-tap keeps it; another
   direction moves it; hold a direction — no flicker.
2. Pad: armed → X plays it (BASIC); refilled card is NOT armed. Armed + not enough mana → X is
   refused and the card STAYS armed; X again once mana arrives plays it (G1).
3. Pad: armed pitchable card, zone empty → Y stages it.
4. Pad: with a staged card READY → Y activates it, the armed card stays armed.
5. Pad: armed → R2 casts unblockable; armed → L2 defends by colour; L1 held + L2 counters (6-10 8b).
6. Pad: nothing armed → X / R2 / L2 / Y (zone not READY) are refused with the usual reject sound and
   the own half blinks the hint. A diagonal D-pad tap arms exactly one slot, the higher.
7. Pad: R1/L1/B/A-held/R3 attack/block/roll/run/lock with a card armed — none suppressed; L3 does nothing.
8. Pad: get knocked down while armed — still armed after; end a round — arm cleared.
9. Keyboard: keys 1-4 arm (sticky), E plays BASIC; nothing armed + E → reject sound + blink. Q (P1)
   and O (P2) do nothing (G2).

**Two-pad [3,3]:** 10. P1 arms and re-arms — P2's half shows nothing of it; and the reverse.

**Layouts:** 11. Set P2's profile to DIAMOND, then ROW — both render, cards readable, glyphs follow the map.

**Persistence:** 12. Edit `user://controls/slot_2.cfg` (e.g. swap left/right slots), restart — P2
follows the edit, P1 unchanged; delete the file, restart — defaults return.

## Dev Notes

- **Tier A ritual.** Suite twice (open, close), mutation proofs per file only (`PROC/R1`); one engine
  launch per tool call, no `run_in_background`/`ScheduleWakeup`/`timeout` wrapper (`E6-R/R4-R5`);
  Edit tool first, python byte-replace on first miss, never PowerShell `-join` (`PROC/R3`).
- **STOP condition (R8):** any need to touch `src/state/`, add an `InputIntent` field, or bump
  `FORMAT_VERSION` → stop and report to the operator.
- **Pure decision, impure read.** Keep `sample()` the only `Input.*` reader and the decision a static
  pure function (the `resolve_card_tick` / `resolve_flick` precedent, `gamepad_controller.gd:186-189`)
  so every AC is reachable headless; joypad reads are not headless-samplable.
- **Edges.** Raw buttons have no engine "just pressed"; edges come from `_prev_held` (`:69-75`). D-pad
  directions get their own private keys there; the neutral path primes all play/arm edges HELD
  (`:149-172` reasoning).
- **Signals over polling / no state handle.** READY, hand ids and the blink arrive by push; the HUD keeps receiving
  plain values (`set_card_selection` shape), per own HUD only (secret; `match_runner.gd:5626-5627`).
- **`user://`** through the M4 helper (AC 11), never `begins_with`. **Text fit is smoke-only** (`PROC/R8`).
- **Commit shape:** docs and code never share a commit; trailer `Co-Authored-By: Claude Sonnet 5
  <noreply@anthropic.com>` (`6-1c/R7`); ASCII via `git commit -F` with a tempfile outside the repo.

### Files expected to change (illustrative)

`src/controllers/{gamepad_profile,gamepad_controller,keyboard_controller,controller}.gd`, `data/gamepad_profile.tres`,
`src/main/match_runner.gd` (profile load, READY / hand-ids relays, arm clears, pushes, blink wrap), `src/ui/hud/hud_root.gd`,
`src/systems/record_file.gd` (M4 helper), `project.godot` (the two G2 deletions only), `test/run_all.sh:29`, tests per M2.
**Not:** `src/state/**`, `src/main/main.tscn`.

### Baselines of record (`684d733`)

Golden `97c9a1de7047d28ffa41e9b55dca905b6ccb542942677a096d2735c11b29da96`, 66 per-player keys
(`decision-log.md:12897,12925`); suite state 1597 / 0 failed / 26573 assertions, integration 102/102
(`decision-log.md:12926`); `FORMAT_VERSION` 25.

### References

- `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md` — `5-0b/R3-R5` (:8309-8327),
  6-10 close-out (:11049-11096), 7-5b golden (:12897), 7-7 post-playtest (:12920-12928)
- `docs/project-context.md` — D3, signals, testing rules (:126-149), `user://` (:173)
- `docs/game-architecture.md:300` — D3 Controller Abstraction (read that section only)
- `docs/implementation-artifacts/7-6-hud-and-card-presentation.md` — card face, lift history

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
