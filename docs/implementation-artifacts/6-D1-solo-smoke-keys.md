# Story 6-D1: Solo Smoke Keys

Status: done

## Story

As the operator smoking colour counters alone,
I want three P1 keyboard keys that cast an unblockable of a chosen colour and hold it through the
chargeup,
so that keyboard P1 attacks while pad P2 counters, without needing a second player.

Tier B, DEBUG. On the `p1_debug_reset` precedent: `debug` in the action name, keyboard-only, P1-only,
no pad change. 5-7's deletion of the ordinary keyboard cast keys stands; these are not a replacement
for them.

## Acceptance Criteria

1. Three Input Map actions `p1_debug_unblockable_red` / `_blue` / `_green`, each on one physically
   unique key (X / V / B), `"location":0`, no modifier. No P2 counterpart exists.
2. A press casts mode 2 (UNBLOCKABLE) with the FIRST card of that colour in P1's hand:
   `card_slot` = that slot, `card_mode` = UNBLOCKABLE, `card_commit` = true, on that tick.
3. The press is press-AND-HOLD: `held[card_cast]` is true for `DEBUG_HOLD_TICKS` (120 = 2.0 s at
   60 Hz, longer than the authored 1.0 s chargeup) whether or not the key is released. Releasing does
   not feint.
4. If the hand holds no card of that colour, nothing happens: no commit, no substitute slot, no hold.
5. A held key commits once (edge taken from successive samples), not once per tick.
6. Nothing new crosses to state: same InputIntent fields, no new intent field, FORMAT_VERSION 11,
   golden `d437432f` unmoved. `project.godot` diff is exactly the three new actions.
7. Hand colours reach the controller through the runner's `cards_changed` wrapper (the HUD tint
   route), never a state handle.
8. The input-map pin (`SHIPPED_INPUT_ACTIONS`) and the physical-key collision guard stay green.

## Measured Facts

- Before this story `KeyboardController` hardcoded `card_mode = BASIC` in its arm-then-confirm scheme
  and produced no other mode (5-7 AC 12 deleted the temporary confirm keys).
- The pad's B confirm (mode 2) sets `card_slot`, `card_mode = UNBLOCKABLE`, `card_commit`, and
  `held[card_cast]` = B's raw state (`GamepadController.resolve_card_tick`). The debug press mirrors
  those four fields.
- Hand colours: `HudRoot.on_cards_changed` receives `hand_ids` plus a total id->colour map inside the
  runner's `cards_changed` wrapper. The same wrapper now also calls `Controller.observe_hand_colors`
  with per-slot colours (-1 = empty). Base is a no-op, so no other controller changed.
- `unblockable_chargeup_seconds = 1.0` (`balance_config.tres`); physics rate 60 Hz.
- Physical keycodes already bound in `project.godot`: 32 39 44 46 47 49-52 54-57 65 67-71 74-76 79-84
  87 90 plus arrows/numpad/enter. Free and chosen: X (88), V (86), B (66).
- Godot `is_action_just_pressed` is frame-scoped and the state harness never advances a frame, so the
  edge is derived from `is_action_pressed` across samples (`_debug_prev`), the `GamepadController`
  shape.

## Tasks

- [x] Three actions in `project.godot` (X / V / B).
- [x] `KeyboardController`: P1-only debug actions, edge, hold counter; `Controller.observe_hand_colors`.
- [x] Runner wrapper forwards hand colours.
- [x] Unit tests, input-map pin updated, mutation proofs.

## Dev Agent Record

Model: Claude Sonnet 5.

Deviations from the requested flow: `gds-quick-dev` not loaded (the pass was small and fully
specified by the story text). The code edits were made BEFORE the before-claim suite run; they were
backed up outside the repo with SHA-256, the four source files reverted to HEAD, the before-claim run
taken on the clean tree, and the files restored and SHA-verified. The before numbers are therefore
clean.

Suite (state harness call, then integration call, each foreground, output under `C:\dev\`):

| run | state | integration |
|---|---|---|
| before (`_6D1-suite-before-*.txt`) | 915 / 0 / 7604 | 66/66 |
| after (`_6D1-suite-after-*.txt`) | 920 / 0 / 7755 | 66/66 |

Golden `d437432f` unmoved (`test_determinism` green; keyboard never touches the fixture).

Mutation proofs (backup outside the repo, restore by copy-back, SHA-256 verified after each):

| # | claim | mutation | failing test |
|---|---|---|---|
| M1 | first card of the colour | `find` -> `rfind` | `test_debug_key_casts_first_card_of_colour_unblockable` |
| M2 | mode is UNBLOCKABLE | -> BASIC | same |
| M3 | hold outlasts chargeup | `DEBUG_HOLD_TICKS` 120 -> 30 | `test_debug_key_holds_card_cast_after_release_for_the_debug_duration` |
| M4 | no card -> neutral | slot guard removed | `test_debug_key_with_no_card_of_that_colour_is_neutral` |
| M5 | P1 only | prefix guard removed | `test_debug_keys_are_p1_only` |
| M6 | ratified key | red moved X -> N | `test_debug_keys_ship_on_their_physical_keys` |
| M7 | action set pinned | green action renamed | `test_shipped_input_map_action_set_is_exactly_pinned` (+2) |
| M8 | one commit per press | prev-edge guard removed | `test_debug_key_casts_first_card_of_colour_unblockable` |
| M9 | hold is applied | `card_cast` write removed | first test + hold test |

Commits: code `b58c407`; docs (this file, board row) follows it.

## Live Smoke (operator, solo)

Config `[0, 3]` (P1 keyboard, P2 pad). P1's hand must hold the colour pressed.

- [x] X / V / B cast RED / BLUE / GREEN unblockable from P1 with one tap; the chargeup completes and
      launches with the key already released.
- [x] Pad P2 counters with the matching colour card.
- [x] Pressing a colour P1's hand does not hold does nothing.

Result: operator's solo check PASS (2026-09-20), recorded in `docs/playtest-log.md`: X/V/B each cast an
unblockable of the colour from one tap and hold the chargeup; the counters were smoked solo with the pad.
