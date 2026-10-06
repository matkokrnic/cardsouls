class_name DebugInputReader
extends RefCounted

## Story 3-0b (AC 1): the match-global DEBUG step/pause reader.
##
## A deliberate NON-`Controller` member of src/controllers/ (sanctioned by the operator at the
## 3-0b readiness gate — every other member of this folder is a `Controller` implementing
## `sample()`). It does NOT implement sample(), does NOT return an InputIntent, and returns
## PLAIN BOOLEANS the runner polls. That shape is the point: step/pause is a DEBUG input, not
## an intent. It never enters InputIntent, never enters the recorded intent stream, and never
## passes through advance() — a deliberate divergence from `debug_reset` (which IS
## intent-carried, per its own 1-7/D-2 ruling), because pause must survive the ABSENCE of
## ticking, and an intent consumed inside advance() cannot.
##
## It lives here, and only here, because INVARIANT D3(a) confines `Input.*` to src/controllers/
## (machine-checked by test_architecture_invariants.gd::test_input_only_in_controllers) and the
## runner is where the gate must sit (INVARIANT F1 — the one _physics_process). This is the only
## routing that satisfies both without pretending step/pause is an intent.
##
## Both actions are MATCH-GLOBAL: no p1_/p2_ prefix, unlike every gameplay action and unlike
## the per-slot debug_reset. A pause belongs to the match, not to a player.

const PAUSE_ACTION := &"debug_pause"
const STEP_ACTION := &"debug_step"
## Story 7-6 POLISH (operator ruling P12, 2026-10-06): F3 shows / hides the DebugInstrumentPanel (hidden by default).
const TOGGLE_INSTRUMENTS_ACTION := &"debug_toggle_instruments"


## Edge, not level: one toggle per physical press, so holding the key cannot flip pause every
## tick. The runner owns the paused flag; this only reports the press.
func pause_pressed() -> bool:
	return Input.is_action_just_pressed(PAUSE_ACTION)


## Edge, not level (AC 1: "one tick per press, no key-repeat auto-fire") — holding the step key
## advances exactly one tick, not one per frame.
func step_pressed() -> bool:
	return Input.is_action_just_pressed(STEP_ACTION)


## 7-6 POLISH (P12): the instrument panel's show/hide edge -- presentation only, never an intent.
func instruments_toggle_pressed() -> bool:
	return Input.is_action_just_pressed(TOGGLE_INSTRUMENTS_ACTION)
