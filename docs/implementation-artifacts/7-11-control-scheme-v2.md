---
baseline_commit: 684d7337e566d1b6d5b2dbddaa4246e7922c7638
---

# Story 7-11: Control Scheme v2

Status: done

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

- [x] Before-measurement (outside the repo): state suite (one call), integration (two calls, 600000 ms),
      golden + key count, `git diff --stat -- src/state/ project.godot src/main/main.tscn` (AC 16-19, 21)
- [x] Profile: retire `cast_button` / `card_mode_alt_button` / `card_mode_toggle` and the role fields
      v2 no longer uses; add play-role buttons, D-pad direction→slot map, hand layout enum; author
      the shipped `.tres` explicitly incl. the ROW+GLYPH default (AC 9, 10, 12)
- [x] Per-slot load in `_make_controller`, injectable root, M4 containment helper, fallback (AC 10, 11)
- [x] `project.godot`: delete `p1_cast_mode`/`p2_cast_mode` only (AC 19, G2)
- [x] `GamepadController`: pure v2 decision (arming, tie-break, plays, Y rule, slot -1 emit, priming,
      arm-clear on leave); delete HOLD/TOGGLE/suppression (AC 1-9)
- [x] `Controller` base: drop `card_mode_on`/`force_card_mode_off`; add the READY and hand-ids pushes;
      runner relays own-slot `ready` and the bound `hand_ids` (M5), wraps `connect_hero_action_rejected`
      for the own-HUD blink; round end / debug reset clear the arm via the existing relays
      (`match_runner.gd:2852,2861`); remove the knockdown poll (`:5618-5622`) (AC 3, 4, 6, 7, 14)
- [x] `KeyboardController`: arm model, no modifier, nothing-armed still emits slot -1 (AC 15)
- [x] HUD: remove row lift, armed rise/frame (G4), three layouts, glyph badges, blink; own half only
      (AC 12-14)
- [x] Tests per M2 dispositions + new tests (AC 20); mutation-prove new guards
- [x] After-measurement: full suite, golden both directions, diffs (AC 16-19, 21)
- [x] Live Smoke handed to the operator

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

Claude Opus 5.5 (`claude-opus-5-5`), gds-dev-story, **PART A of two (input layer)**, 2026-10-28. Story
Status left `ready-for-dev` and the board untouched by session rule (no completion step; skill Steps 4/9/10
board writes not executed). Nothing committed, nothing staged (`git diff --cached` empty at HALT).

PART B of two (presentation), same model, gds-dev-story, 2026-10-29: completion step and on_complete run
(story Status `review`; board back to `ready-for-dev` per the custom toml). Nothing committed, nothing staged.

### Debug Log References

All outside the repo, under `C:\dev\`:
- Suite BEFORE: `_711a-suite-before-state.txt` (22:28), `_711a-suite-before-int1.txt`, `_711a-suite-before-int2.txt`.
- Suite AFTER: `_711a-suite-after-state.txt`, `_711a-suite-after-int1.txt`, `_711a-suite-after-int2.txt` (23:17).
- Golden: `_711a-golden-before.txt`, `_711a-golden-after.txt` (script `_711a-measure.gd`).
- Integration half-runner: `_711a-int.sh` (sorted `test/integration/test_*.gd`, split at the midpoint).
- Mutation proofs: `_711a-mut\mut.py`, outputs `_711a-mut\M1.txt`..`M14.txt`, backups `M*.bak`.
- Editor pass: `_711a-editorscan.txt`. Dev iteration runs: `_711a-dev-*.txt`.
- PART B: BEFORE = A's AFTER files above (tree verified unchanged first). AFTER `_711b-suite-after-state.txt`,
  `_711b-suite-after-int1.txt`, `_711b-suite-after-int2.txt`; superseded first state run
  `_711b-suite-after-state-run1-FAIL.txt`; golden `_711b-golden-after.txt`; mutation proofs `_711b-mut\mut.py`,
  `B*.txt`/`B*.bak`, `pre-sha.txt`; editor pass `_711b-editorscan.txt`; dev runs `_711b-dev-*.txt`.
- Smoke fixes: the FINAL AFTER set is `_711b2-*` (`_711b2-suite-after-state.txt`, `-int1.txt`, `-int2.txt`, golden
  `_711b2-golden-after.txt`, `_711b2-hand-layouts-run1/2.txt`, `_711b2-unit-combat-isolated.txt`, the superseded
  `_711b2-suite-after-int1-run1-SMOKE-CONFIG.txt`); smoke mutation proofs `_711b-mut\mut2.py`, `C*.txt`/`C*.bak`.
- Review fix (2026-10-30): AFTER `_711c-suite-after-state.txt`, `_711c-suite-after-int1.txt`, `_711c-suite-after-int2.txt`;
  golden `_711c-golden-after.txt`; mutation proofs `_711c-mut\mut3.py`, `C11/D1-D3.txt`/`.bak`, `pre-sha.txt`; dev runs
  `_711c-dev-*.txt`.

### Completion Notes List

**PART A STOPPING POINT (for the PART B session).** A is complete and GREEN. B owns: the HUD presentation
(three layouts, glyph badges, armed rise/frame rule incl. G4, the ~0.4 s blink), the runner's per-slot wrap of
`connect_hero_action_rejected` for that blink (AC 14), the three HUD-file M2 dispositions
(`test_card_face.gd` REWRITE, `test_hud_viewports.gd` CONDITIONAL, `test_card_selection_indicator.gd` -- see
the pulled-forward note below), ACs 12-14, and the Live Smoke hand-off. Tasks 6, 8, 9, 10, 11 stay unchecked:
6 lacks only the blink wrap; 9 lacks only the HUD-file dispositions; 10/11 are B's close.

**Counters (read from the files).**
- State BEFORE 1597 tests / 0 failed / 26573 assertions, PASS. AFTER **1587 / 0 / 26391**, PASS (-10 = 33->25
  gamepad file, -20 toggle file, +9 v2 file, +9 override file; locomotion 1-for-1).
- Integration BEFORE half 1: 51 files, 0 failed; half 2: 51 files, **1 failed** -- `test_unit_combat_live.gd`
  printed `RESULT: PASS` then `ERROR: 1 resources still in use at exit`, the known intermittent 7-T1 leak
  (that file is in `VERBOSE_FILES` for exactly this), BEFORE any edit. AFTER **102 / 102**, 0 failed, no leak
  line (one file retired, one added).

**Golden.** BEFORE `97c9a1de7047d28ffa41e9b55dca905b6ccb542942677a096d2735c11b29da96`, P1 66 / P2 66 keys, hash ==
`GOLDEN` const. AFTER identical; the two `measure` outputs are byte-identical (`diff` empty) -- the reverse
probe of a non-mover (AC 17). `git diff -- src/state/` empty, `FORMAT_VERSION := 25`, no `InputIntent` field
(AC 16). M6's two replay tests untouched and green (AC 18). `src/main/main.tscn` diff empty.

**`project.godot`** diff = exactly the two deletions, `p1_cast_mode` (Q, 81) and `p2_cast_mode` (O, 79). Keyed
non-`ui_` actions 46 -> 44; the KEEP guard `no_physical_key_backs_two_project_actions` compares those 44, green.

**Dev calls (one line of reason each).**
- Profile field names: `dpad_{left,up,down,right}_button` + `dpad_*_slot` (0..3), `run_button` (A),
  `play_basic_button` (X), `cast_pitch_button` (Y, name KEPT -- its 6-3a test is a KEEP), `hand_layout`
  (`enum HandLayout { ROW, ROW_GLYPH, DIAMOND }`, default ROW_GLYPH); L2/R2 stay the existing trigger axes --
  every role is a binding on one mechanism, and the D-pad buttons are data so the raw index lives once (2-2/R2).
  Measured `*_button` fields: 11 (KEEP test floor `>= 8` holds).
- Override format: plain text `key = integer` lines, `#` comments, parsed by hand -- data-only; not
  `ConfigFile`, whose Variant parser can construct objects from a user-writable file.
- Fallback: ABSENT keys keep the default field by field; ANY defect (malformed line, unknown key, non-int,
  out-of-range, repeated key, colliding buttons/axes, non-permutation slot map, system button) refuses the WHOLE
  file -> shipped default, reason printed -- no half-applied file can exist.
- Loader seat: `GamepadProfile.load_for_slot(player_slot, override_root)` (static) -- headless-testable, one
  place; runner injectable `controls_override_root` on the `seed_override` precedent.
- M4 helper: `RecordFile.is_inside_root(path, root) -> bool` (static); `_outside_user_directory` calls it with
  `user://`, message unchanged -- the locked shape.
- Relay names: `Controller.observe_pitch_ready(bool)`, `observe_hand_ids(Array)`, `clear_armed_slot()` (base
  no-ops) + pure `Controller.armed_after_hand_change` -- the `observe_hand_colors` push precedent.
- `resolve_card_tick` fate: KEPT and RE-SIGNATURED (no modifier arg; D-pad arrays, run, READY added) plus a new
  pure `resolve_arm` -- the six REWRITE test names stay true; arming is separately testable.
- Play-chord order: X, Y, L2, R2, last write wins -- R2 wins any chord, B's answer under 5-7.
- `card_slot` written on COMMIT samples only (pad and keyboard) -- armed slot stays controller-local (M6).
- Fixture `fake_mode_controller.gd`: DELETED -- the new arm-clear live test drives real controllers.
- 6-10 base test landing: `test_control_scheme_v2.gd`, beside the arm-lifetime tests it describes.
- Hand-ids push uses the wrapper's BOUND `hand_ids` param; the inline `player.hand.to_array()` is not used for it.
- HUD in A: the runner no longer calls `set_card_mode`; `HudRoot.set_card_mode`/the row lift code stay for B
  (B's `test_card_face.gd` still calls it), so the armed highlight is today's frame-only, no lift.

**G1 Boulder.** Headless at the CHANNEL level (`test_a_cover_and_its_lifting_keep_the_arm`: `Hand.cover_at` /
`uncover_at` + the real notify -> bound visible payload -> arm kept). The Boulder CARD's plant and the X that
clears it are NOT headless-reachable here (needs a Boulder effect fixture) -> **named for smoke**: armed slot
covered by a Boulder stays armed; X clears the Boulder and stays armed; the next X plays the card underneath.

**M2 dispositions executed in A.** RETIRE **39** (gamepad 18, toggle 19, locomotion 1, `test_card_mode_lift` 1).
REWRITE **24 of 25**: gamepad 6, toggle 1 (-> v2 file), deck_and_hand 2, integration 15 (14-file G2 sweep incl.
the hound `_finish` loop, + `test_card_selection_indicator.gd`); remaining 1 (`test_card_face.gd`) -> B. KEEP
**27** untouched (gamepad 9, controller 12, deck_and_hand 1, data 2, architecture 1, M6 2) -- diff hunks of
`test_gamepad_controller.gd` start after line 227 and skip the KEEP pitch test. Uncounted sweep done:
`perf_20_units_live.gd` (+ its dead `CAST_MODE_RELEASE` const), `flags_off_live.gd`, `run_all.sh:29`. Fixture
deleted (+ the three retired files' `.uid`). CONDITIONAL `test_hud_viewports.gd` -> B (untouched, green).
`test_card_tint_live.gd`: `set_card_selection` unchanged -> nothing to re-verify. NEW tests **29**: gamepad file
10, `test_control_scheme_v2.gd` 8 (+1 rewrite), `test_gamepad_profile_override.gd` 9, locomotion 1
(replacement name), integration `test_arm_clear_live.gd` 1.

**PULLED FORWARD FROM B (disclosed):** `test_card_selection_indicator.gd` -- its INPUT half only (drop the
`p1_cast_mode` press; "release disarms" -> "sticky after release"). Required for A to end green once G2
deleted the action; no HUD presentation changed. B still owns any HUD-geometry rewrite of it.

**Mutation proofs (AC 20; backup + SHA256 out of repo, restore by copy, SHA verified every time):**

| # | Target | Mutation | Killed by |
|---|---|---|---|
| M1 | gamepad_controller | tie-break walks slots descending | `two_directions_on_one_sample_arm_the_higher_slot` |
| M2 | gamepad_controller | READY never activates | `y_with_a_ready_zone_activates_whatever_is_armed` |
| M3 | gamepad_controller | R2 leaves an overwritten activation set | `play_chord_resolves_in_the_order_x_y_l2_r2` |
| M4 | gamepad_controller | D-pad edges not primed on the neutral path | `replug_priming_covers_the_new_commit_edges` |
| M5 | controller | any visible change clears the arm | 3 tests in `test_control_scheme_v2.gd` |
| M6 | match_runner | hand-ids relay removed | `test_arm_clear_live.gd` |
| M7 | match_runner | READY relay unfiltered | `test_arm_clear_live.gd` |
| M8 | match_runner | round_ended relay does not clear | `test_arm_clear_live.gd` |
| M9 | gamepad_profile | refused override applied anyway | `a_defective_override_falls_back_wholesale` |
| M10 | gamepad_profile | duplicate buttons accepted | `a_defective_override_falls_back_wholesale` |
| M11 | record_file | containment without the separator | `containment_is_by_normalisation_under_the_injected_root` |
| M12 | keyboard_controller | nothing-armed confirm swallowed | `keyboard_card_keys_arm_sticky_and_the_confirm_commits` |
| M13 | controller | dormant `card_mode_on()` re-added | `the_card_mode_surface_is_deleted` |
| M14 | gamepad_controller | activation addresses the armed slot | `y_with_a_ready_zone_activates_whatever_is_armed` |

Not separately mutation-proven: the hand-ids relay being the BOUND payload rather than a live read (true by
construction -- the wrapper's own parameter; a live runner same-drain refill needs a zero authored draw delay).

**Runs beyond the two full suites (disclosed, E5-R/R5):** one editor pass (`--editor --quit`, `.uid` for the four
new scripts + parse check against the 600 s hang); four filtered dev runs (`gamepad`, `control_scheme` x3 -- one
sanity assertion in the stage/activation test was wrong twice: a stage's hole is refilled at activation, which
is not a "leave"; narrowed to the armed slot); two single-file integration dev runs; 14 mutation runs. The editor
pass also generated `.uid` files for four unrelated untracked-before assets; removed again.

**Process deviations (disclosed, PROC/R3).** `gamepad_controller.gd` (first Edit miss, my typo), `match_runner.gd`
(first miss, my malformed old_string) and `record_file.gd` (first miss) were continued by python byte-replace /
anchored line-splice per the rule. Also two python patches to files I had just created myself
(`test_control_scheme_v2.gd`: Callable/typing fixes) where no Edit had failed -- a bend of "Edit first".

**Noted, not touched:** `hud_root.gd:1494` comment names the retired `cast_basic_button` (B's HUD file);
`test_healer_strike_alignment_live.gd:8` and `test_history_and_orbs_live.gd:9` comments cite the deleted
fixture / lift test as history.

---

**PART B (presentation) -- 2026-10-29. Story COMPLETE; all tasks checked.**

**Precondition.** HEAD == origin/main == `e13329b`; `git status --short` == A's File List + story file (6 untracked),
nothing staged; `main.tscn` / `src/state/` diffs empty, `project.godot` = the two deletions -> A's AFTER files used
as the BEFORE baseline.

**Counters (read from the files).**
- State: BEFORE (A AFTER) 1587 / 0 / 26391 PASS -> AFTER **1587 / 0 / 26394** PASS (+3 assertions: the rewritten
  architecture guard). The FIRST AFTER state run failed 1 (`test_action_rejected_has_no_hud_consumer`, see the
  finding below); it is kept as `_711b-suite-after-state-run1-FAIL.txt` and superseded after the guard fix.
- Integration: BEFORE 102 / 102 -> AFTER **104 files** (two added): half 1 52 files, **1 failed**; half 2 52 files, 0
  failed. The failure is `test_camera_freedom_live.gd`: `RESULT: PASS` then `ERROR: 1 resources still in use at
  exit` -- the open `6-5b/R24` flake (`deferred-work.md:584-588`), on a file not previously listed. That test drives
  no card, refusal, blink or layout path; one isolated `--verbose` re-run (`_711b-dev-camfree-verbose.txt`) was
  clean. Not re-run as part of the suite; reported, not explained away.

**Golden (AC 17).** `97c9a1de7047d28ffa41e9b55dca905b6ccb542942677a096d2735c11b29da96`, P1 66 / P2 66,
`HASH_MATCHES_CONST=true`; `_711b-golden-after.txt` byte-identical to BOTH `_711a-golden-before.txt` and
`_711a-golden-after.txt`. `git diff -- src/state/` empty, `FORMAT_VERSION := 25`, no `InputIntent` field (AC 16);
M6 replay tests untouched (AC 18); `main.tscn` diff empty; `project.godot` diff still exactly the two deletions (AC 19).

**FINDING -- `6-3-split/R-REFUSE` (operator attention, close-out record needed).** The state guard
`test_architecture_invariants.gd::test_action_rejected_has_no_hud_consumer` pinned the seam's consumers to the
telegraph + inspector and failed ANY inline lambda; AC 14 / G3 names exactly such a lambda (the runner's per-slot
wrap). M2 did not list this test. R-REFUSE (`decision-log.md:10233`) reads "no HUD consumer of the rejection seam is
added, in either split story" -- scoped to 6-3a/b; G3 is the later operator ruling for this mechanism. Treated as
HOW (G3 locks the mechanism): REWRITE of the guard, name still true -- the consumer list gains exactly one `func`,
whose body is pinned to push `blink_arm_hint()` and no `on_*` callback, and `hud_root.gd`'s code may never name
`action_rejected` (2-4/R4). Mutation-proven (B13, B14). The close-out should record G3 as superseding R-REFUSE's
effect for the blink.

**Dev calls (one line of reason each).**
- Layout push: `HudRoot.set_hand_layout(layout: int, direction_slots: Array)` -- plain int + the profile's
  direction -> slot array (`dpad_slots()`), handed over before add_child (the `set_reel_cards` precedent), callable again.
  The HUD inverts it to slot -> direction; a non-permutation push falls back to the default map.
- Runner source: `_make_controller` keeps each pad slot's profile in `_slot_profiles[slot]` (the file is read once; the
  controller and the HUD push see the same instance). Keyboard / null / replay slots push nothing -> HUD default ROW.
- DIAMOND geometry: up over down in the centre column (down where the arc's middle pair rests, above the vitals),
  left / right flanking at mid-height, `DIAMOND_GAP` = `CARD_GAP` 8. Measured at the 960x1080 half: y 680..1012
  (332 px incl. glow), inside the half, clear of vitals / both zones / history / deck / orbs / round label.
- DIAMOND rise: **FRAME ONLY** (G4 as ruled). Measured: a 24 px rise of the DOWN card would run 16 px into the UP card
  (8 px gap). The "196 px budget" (`hud_root.gd:139`) is stale -- it is the pre-P9 648 px window's band; the arc alone
  is 206 px + 24 rise + 4 glow today. Comment corrected; the fit checks are the live layout test and the new one.
- Badge: procedural Panel + ColorRects (round dark plate, dim cross, one lit arm), `DPAD_BADGE_RECT` (89,81) 19x19
  in card space -- the free band right of the divider, clear of both arts, both costs, the pip row, the keyword slot
  and the pitch-ready rim (geometry by test); child of the card, drawn last (above a Boulder cover). Shown only in
  ROW+GLYPH. 19 px legibility = smoke.
- Blink: `HudRoot.blink_arm_hint()` (push); `ARM_HINT_BLINK_SEC` 0.4 -- every card's frame flashes white
  (`ArmHint`, a frame-band Panel per card, so ROW / DIAMOND / keyboard blink too) and ROW+GLYPH badges swell 35 %;
  one up-and-down tween, a restart kills the running one. No sound.
- Blink wrap: runner lambda on `connect_hero_action_rejected(slot, ...)` -- `action == &"card_cast"` (MEASURED: the one
  action every cast / unblockable / defense / pitch refusal in `match_state.gd` names) and that slot's
  `armed_slot() == -1`, any reason -> `hud.blink_arm_hint()` on that slot's OWN root. Captures self, an int and the
  root (a Node); no PlayerState.
- **DEAD / round-over silent by construction:** `advance` returns at `match_state.gd:721` while `_round_over`, before
  card resolution (`:954`); `_resolve_card_action` returns at `:4422` for a DEAD hero before any gate -- neither emits
  `action_rejected`, so the wrap never fires. A Y activation refused while nothing is armed blinks too (any reason).
- Removed: `set_card_mode`, `_card_mode_on`, `CARD_MODE_ROW_LIFT_PX`, `_slot_lifts`; `card_lift` now measures from the
  layout's rest. `CARD_MODE_ARMED_LIFT_PX` keeps its name and 24 px. Stale `:1494` comment fixed (X plays the normal
  half since 7-11; pitch-on-top unchanged).

**M2 -- the three HUD files.** `test_card_face.gd` REWRITE (P17 Boulder block and `_check_highlights`: no row lift,
armed rises 24 px framed; the `:525-527` "mode off + armed: no lone lift" INVERTED -- an armed card with no modifier
rises; plus a deleted-surface check). `test_hud_viewports.gd` CONDITIONAL -> **KEEP** (name + 24 px kept; untouched,
green). `test_card_selection_indicator.gd`: no further change (A's input-half rewrite stands; it reads
`highlight_width` only; green). `test_card_tint_live.gd`: `set_card_selection` shape unchanged -> nothing to re-verify
(green). **Final tally: RETIRE 39 · REWRITE 25 of 25 (+1 unlisted: the R-REFUSE guard) · KEEP 27 (+1 conditional
resolved KEEP).** NEW (B): `test_hand_layouts.gd` (standalone: ROW default, ROW+GLYPH arc + badges + map swap +
badge geometry, DIAMOND positions/fit/no-badge/frame-only, blink pulse) and `test_hand_layout_live.gd` (runner -> HUD:
shipped ROW+GLYPH end to end with an injected left/right-swap override -> P2 badges [3,1,2,0]; keyboard P1 ROW no
badge; nothing-armed refusal blinks P1 only, never P2; armed refusal does not blink; both refusals observed on state's
signal so neither check is vacuous).

**Mutation proofs (AC 20; backup + SHA256 out of repo, restore by copy, SHA verified every time; `pre-sha.txt`
re-checked OK after the last).**

| # | Target | Mutation | Killed by |
|---|---|---|---|
| B1 | hud_root | direction map ignored | `test_hand_layouts` (badge swap, DIAMOND flank) |
| B2 | hud_root | DIAMOND armed card rises | `test_hand_layouts` (G4 frame-only) -- superseded by S3; re-proven by C10/C11 |
| B3 | hud_root | armed card never rises | `test_card_face` (4 checks) -- superseded by S3; re-proven by C10/C11 |
| B4 | hud_root | badges in every layout | `test_hand_layouts` (ROW / DIAMOND no badge) |
| B5 | hud_root | DIAMOND up placed at down | `test_hand_layouts` (stacking, overlap) |
| B6 | hud_root | pulse rise leg zeroed | **SURVIVED** -- the 1 -> 0 leg still shows a pulse; the rise SHAPE is smoke-only look |
| B6b | hud_root | `blink_arm_hint` does nothing | `test_hand_layouts` (no pulse, no swell) |
| B7 | hud_root | hint frame lingers | `test_hand_layouts` |
| B8 | hud_root | dormant `set_card_mode` re-added | `test_card_face` |
| B9 | match_runner | layout push removed | `test_hand_layout_live` (P2 badges none) |
| B10 | match_runner | blink ignores the arm | `test_hand_layout_live` (armed refusal blinked) |
| B11 | match_runner | blink to the opponent's root | `test_hand_layout_live` (P1 none, P2 blinked) |
| B12 | match_runner | wrong action name | `test_hand_layout_live` |
| B13 | match_runner | wrap pushes an `on_*` callback | `test_action_rejected_has_no_hud_consumer` |
| B14 | hud_root | HUD grows an `action_rejected` consumer | `test_action_rejected_has_no_hud_consumer` |

**Runs beyond the full suites (disclosed, E5-R/R5):** one editor pass (`.uid` for the two new scripts + parse check;
it again generated `.uid`s for four unrelated untracked assets -- removed); dev runs: `test_hand_layouts` x2 (first
failed only on the viewport size: `root.size` set in `_initialize` does not survive headless; moved to frame 1),
`test_card_face` x1, `test_hand_layout_live` x1, filtered `architecture` x1, camera_freedom `--verbose` x1; 15
mutation runs. **Process:** every repo edit via the Edit tool (no failed match, no python fallback needed).

**Live Smoke (12 items)** is the operator's next step. Smoke-only here: badge legibility at 19 px, DIAMOND fit and
readability, the blink's look, the G1 Boulder items named in PART A.

**Smoke fixes (2026-10-29).** Operator smoke items 1-10 PASS; three presentation findings, operator rulings S1-S3,
applied in `src/ui/hud/hud_root.gd` (+ pins in `test/integration/test_hand_layouts.gd`, one comment in
`test_card_face.gd`). No `src/state/`, no InputIntent field, FORMAT_VERSION 25, golden unmoved. All positions are
measured at the shipped 960x1080 half (half pixels, origin top-left).

- **S1 badge off the card face.** Below the card was measured first and does NOT fit: the vitals start at y 1014,
  6 px under the arc's middle pair (bottom 1008). So the badge sits on the card's TOP frame band:
  `DPAD_BADGE_RECT = Rect2(53, -16, 22, 22)` in card space (centred on x; its bottom edge on the face's top edge,
  `CARD_FRAME_PX` = 6; hangs 16 px above the card). Measured: slot 0's badge at (265, 882) 22x22, card at (212, 898).
  Plate 22 px (was 19), arm `DPAD_BADGE_ARM_PX` 6 (was 5). Still a child of its card (follows the 24 px rise),
  procedural and text-free. The blink's swell now pivots at the badge's bottom centre, so it never reaches the face.
- **S2 DIAMOND as an alternate arrangement** (`_apply_arrangement`; ROW / ROW+GLYPH places restored exactly).
  `DIAMOND_EDGE_PX` = 24 (= `HAND_BOTTOM_PX`; the margin keeps a pushed card and its glow inside the half),
  `DIAMOND_GAP` 8, `DIAMOND_ZONE_GAP` = 16. Measured with the default map: left (24, 815), up (160, 732),
  down (160, 898), right (296, 815), all 128x158; vitals (296, 981) 264x58 (below the right card, right of the down
  card, same size as ROW); own zone (808, 724), opponent zone (808, 898), both 128x158 (bottom-right, own above
  opponent's). The history strip (y 454..698, either edge) and the corner indicators stay clear.
- **S3 DIAMOND armed emphasis** (G4 refined): no rise. The armed card is pushed outward `DIAMOND_ARMED_PUSH_PX` = 12
  along its own direction with its gold frame; the other three dim to `DIAMOND_UNARMED_DIM` = 0.8 (card panel
  modulate). Nothing armed = all at rest, undimmed. Test reads: `card_offset(i)`, `card_tone(i)`.
- **Pins** (`test_hand_layouts.gd`, 947 checks): badge outside the face rect, inside the half, clear of every other
  HUD element and card, at rest and armed, and while swelling; DIAMOND flush in the bottom-left corner, vitals in the
  notch, zones stacked, sizes unchanged, nothing inside the half overlapping (history strip also checked mirrored to
  the right edge), ROW places restored; per direction and both maps: armed offset = outward push, others at rest and
  dimmed, nothing armed = rest and undimmed.

| # | Mutation (`hud_root.gd`) | Killed by |
|---|---|---|
| C1 | badge back on the face (89, 81) | S1 face / face-part checks |
| C2 | badge swells from its centre | S1 swelling-badge check |
| C3 | diamond centre-anchored (not flush left) | S2 flush / notch / overlap |
| C4 | zone gap -40 (zones overlap) | S2 stacking + no-overlap |
| C5 | vitals run up into the right card | S2 notch + no-overlap |
| C6 | armed UP card pushed inward | S3 push + no-overlap |
| C7 | unarmed cards never dim | S3 dim |
| C8 | nothing armed still dims | S3 nothing-armed |
| C9 | own zone not restored in ROW | S2 ROW restore |
| C10 | DIAMOND armed card rises 24 | S3 push |
| C11 | the NON-diamond armed rise zeroed (review fix L4) | `test_card_face.gd` (P17 covered-slot lift, AC 21 control, G4 rise) |

All 10 killed; every restore SHA-verified (`hud_root.gd` 0f4dd12b...). Driver `C:\dev\_711b-mut\mut2.py`.

**AFTER (smoke fixes):** state 1587 / 0 / 26394 PASS (unchanged). Integration 104 files: half 1 52 / 0 failed;
half 2 52 / 1 failed: `test_unit_combat_live.gd` printed `RESULT: PASS` then `1 resources still in use at exit`, the
open `6-5b/R24` flake (the isolated `--verbose` re-run was clean). Golden `97c9a1de...29da96`, 66 / 66,
byte-identical to `_711b-golden-after.txt`. **Disclosed:** the first half-1 run (kept as
`_711b2-suite-after-int1-run1-SMOKE-CONFIG.txt`) failed 3 files because the operator's smoke setup was still in the
tree: `main.tscn` `slot_controller_kinds = [0, 3]` made P2 a gamepad in every live test, and that loaded the
operator's `user://controls/slot_2.cfg` (`hand_layout = 2`, DIAMOND). The `main.tscn` line was removed with Edit, as
the session rule (empty `main.tscn` diff) requires. The `user://` file was left in place. Dev runs: `test_hand_layouts`
x2 (the first failed only on float noise at the swollen badge's bottom edge: 6.00001 against 6), unit_combat
`--verbose` x1, 10 mutation runs.

**Review fixes (2026-10-30)** -- code review verdict APPROVE; operator ruled L1-L4 + the Debug Log nit fixed, NOTES stay
notes. No `src/state/`, no InputIntent field; golden unmoved.

- **L1** `gamepad_profile.gd`: an integer literal longer than `MAX_OVERRIDE_LITERAL` (6) is refused BEFORE `to_int()`, so
  the engine's 64-bit overflow ERROR print is gone. `test_gamepad_profile_override.gd`: new
  `test_file_shapes_crlf_empty_bom_lone_cr_and_over_long` (CRLF applies; empty / whitespace-only / CRLF-only apply as the
  default; a UTF-8 BOM file applies through the real file path; a lone-CR file is refused wholesale; the over-long literal
  is refused with the length reason) + an "over-long literal" case in the wholesale-fallback table (valid
  `hand_layout = 2` line first, as every case there). The dev run's log carries 0 `ERROR` lines.
- **L2** `apply_override_text` parses into a dictionary, applies onto an internal `duplicate()`, and copies onto `self`
  only when `binding_refusal()` is empty. New `test_a_refused_text_leaves_the_profile_untouched` (four refusal shapes ->
  every field equals its pre-call value; a coherent text still applies to that very instance).
- **L3** `test_architecture_invariants.gd::test_gamepad_slot_tests_inject_the_controls_override_root`: every file under
  `test/` that assigns a GAMEPAD slot kind (`3` or the `GAMEPAD` token) AND builds controllers (`_make_controller(` or a
  runner added to the tree) must set `controls_override_root`. Today it finds exactly the two gamepad-kind builders and
  both inject; `test_gamepad_controller.gd` sets `[3, 3]` but only derives the pad ordinal (builds nothing) and is exempt.
  Non-vacuity asserted on sample strings and `>= 2` files found. Stated limitation: a kind set through a variable evades it.
- **L4 / Debug Log nit** C11 added below; B2/B3 marked superseded by S3 and re-proven by C10/C11; Debug Log References
  name `_711b2-*` as the final smoke-fix AFTER set and `_711c-*` as the review-fix set.

Mutation proofs (restore by COPY, SHA256 verified every time, `pre-sha.txt` re-checked after the last; driver
`C:\dev\_711b-mut` -> `C:\dev\_711c-mut\mut3.py`):

| # | Target | Mutation | Killed by |
|---|---|---|---|
| C11 | hud_root | non-diamond armed rise zeroed (L4) | `test_card_face.gd` (3 FAIL lines: P17, AC 21 control, G4 rise) |
| D1 | test_hand_layout_live | `controls_override_root` line removed (L3) | `test_gamepad_slot_tests_inject_the_controls_override_root` (architecture 19 tests, 1 failed) |
| D2 | gamepad_profile | length pre-check removed (L1) | the over-long pin (profile_override 11 tests, 1 failed) |
| D3 | gamepad_profile | apply onto `self`, not a duplicate (L2) | `test_a_refused_text_leaves_the_profile_untouched` (11 tests, 1 failed) |

**AFTER (review fixes):** state **1590 / 0 / 26430** PASS (BEFORE 1587 / 0 / 26394: +3 tests, +36 assertions). Integration
104 files: half 1 52 / 0 failed, half 2 52 / 0 failed (the `6-5b/R24` leak did not show this run). Golden
`97c9a1de...29da96`, 66 / 66, `_711c-golden-after.txt` byte-identical to `_711b2-golden-after.txt`.
`git diff -- src/state/` and `main.tscn` empty, `project.godot` still the two deletions, `FORMAT_VERSION := 25`.

### File List

Modified: `data/gamepad_profile.tres`, `project.godot`, `src/controllers/controller.gd`,
`src/controllers/gamepad_controller.gd`, `src/controllers/gamepad_profile.gd`,
`src/controllers/keyboard_controller.gd`, `src/main/match_runner.gd`, `src/systems/record_file.gd`,
`test/run_all.sh`, `test/perf/flags_off_live.gd`, `test/perf/perf_20_units_live.gd`,
`test/state/test_deck_and_hand.gd`, `test/state/test_gamepad_controller.gd`, `test/state/test_locomotion_gaits.gd`,
`test/integration/test_card_selection_indicator.gd`, `test/integration/test_hole_vs_in_flight_live.gd`,
`test/integration/test_hound_spawn_live.gd`, `test/integration/test_summon_actor_live.gd`,
`test/integration/test_summon_spawn_containment_live.gd`, `test/integration/test_two_units_converge_live.gd`,
`test/integration/test_unit_aim_live.gd`, `test/integration/test_unit_approach_live.gd`,
`test/integration/test_unit_attack_live.gd`, `test/integration/test_unit_combat_live.gd`,
`test/integration/test_unit_corpse_linger_live.gd`, `test/integration/test_unit_corpse_walkthrough_live.gd`,
`test/integration/test_unit_spawn_placement_live.gd`, `test/integration/test_unit_strike_alignment_live.gd`,
`test/integration/test_unit_swing_root_live.gd`, `docs/implementation-artifacts/7-11-control-scheme-v2.md`.
PART B: `src/ui/hud/hud_root.gd`, `test/integration/test_card_face.gd`, `test/state/test_architecture_invariants.gd`,
`docs/implementation-artifacts/sprint-status.yaml` (skill board lifecycle: `last_updated`, story note);
`src/main/match_runner.gd` again.

Added: `test/state/test_control_scheme_v2.gd` (+`.uid`), `test/state/test_gamepad_profile_override.gd` (+`.uid`),
`test/integration/test_arm_clear_live.gd` (+`.uid`). PART B: `test/integration/test_hand_layouts.gd` (+`.uid`),
`test/integration/test_hand_layout_live.gd` (+`.uid`).

Deleted: `test/state/test_card_mode_toggle.gd` (+`.uid`), `test/integration/test_card_mode_lift.gd` (+`.uid`),
`test/integration/fake_mode_controller.gd` (+`.uid`).

## Change Log

- 2026-10-28 -- PART A (input layer) dev pass: control scheme v2 controllers, per-slot profile + `user://`
  override data path, runner relays and arm clears, `pX_cast_mode` removed, M2 dispositions except the HUD
  files, mutation-proven. Uncommitted; Status unchanged (`ready-for-dev`); PART B pending.
- 2026-10-29 -- PART B (presentation) dev pass: card-mode row lift removed; armed card rises 24 px framed in
  ROW / ROW+GLYPH, frame-only in DIAMOND; three hand layouts pushed per slot by the runner; procedural D-pad badges;
  own-half arm-hint blink via the runner's per-slot `action_rejected` wrap; R-REFUSE guard rewritten (finding);
  two new integration tests, 15 mutation runs. Uncommitted; Status `review`; board `ready-for-dev` (CFG/R2).
- 2026-10-29 -- Smoke fixes S1-S3 (operator rulings): D-pad badge moved off the card face onto the top frame band;
  DIAMOND re-arranges the whole half (diamond bottom-left, vitals in its notch, zones stacked bottom-right); DIAMOND
  armed card pushed outward 12 px, others dimmed to 0.8. 10 mutation runs. Uncommitted; Status stays `review`.
- 2026-10-30 -- Review fixes L1-L4 (operator rulings after code review, verdict APPROVE): override parser refuses an
  over-long literal before `to_int()` and applies atomically (a refused text leaves the profile untouched); new pins for
  CRLF / empty / BOM / lone-CR / over-long; new invariant that gamepad-kind tests inject `controls_override_root`;
  C11 + D1-D3 mutation runs; B2/B3 marked superseded; Debug Log lists the `_711b2-*` and `_711c-*` sets. Uncommitted;
  Status stays `review`.
- 2026-10-30 -- Close-out: code committed as `7029e7f` (C1), decision-log session "7-11 close-out session" (C2, rulings
  `7-11/S1`..`S3`, `7-11/G3` supersession, `7-11/L1`..`L4`); Status `done`, board `done`. Suite 1590 / 0 / 26430 + 104/104.
