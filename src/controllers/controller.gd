class_name Controller
extends RefCounted

## D3 interface: produces a pure-data InputIntent each tick. State consumes it and never
## knows the source (keyboard / gamepad / scripted AI / replay) — dummy -> PvP -> bot is a
## config swap. Returns a FRESH InputIntent per sample() (immutable-per-tick value object).

func sample() -> InputIntent:
	return InputIntent.new()  # override per implementation


## Story 3-5a (AC 10): which hand slot this controller currently has ARMED, or -1 for none.
## PRESENTATION-FACING and controller-local — the runner polls it after sample() and pushes the
## plain int into the HUD's selection indicator. It is deliberately NOT on InputIntent: the
## indicator shows what the PLAYER has selected, which is a controller fact, and routing it
## through state would mean a snapshot field (and a replay contract) for a highlight.
##
## Base returns -1 so a controller with no card scheme (NullController, ReplayController) renders no
## selection rather than needing a stub each.
func armed_slot() -> int:
	return -1


## Story 7-11 (AC 4): the runner PUSHES "the round ended / the debug reset ran" -- drop the armed slot.
## Replaces 6-10's `force_card_mode_off` (there is no card mode; R2). Knockdown no longer pushes anything.
## Base is a no-op on the `observe_hand_colors` precedent so no other controller needs a stub.
func clear_armed_slot() -> void:
	pass


## Story 7-11 (G1, AC 3): this player's hand, as the BOUND `hand_ids` of each `cards_changed` emission
## (the VISIBLE layer, `Hand.EMPTY` for a hole), PUSHED by the runner's existing wrapper -- never read
## off state (D3). An armed card that LEAVES its slot (non-EMPTY -> EMPTY at the armed index) clears the
## arm, which is what makes a played or staged card disarm while a refused one stays armed. Base no-op.
func observe_hand_ids(_ids: Array) -> void:
	pass


## Story 7-11 (R3, AC 6): whether this player's OWN Pitch Zone is READY, PUSHED by the runner off the
## tenth seam (`connect_pitch_changed`, filtered to the own slot) -- a plain bool, never a state read.
## Only the pad's Y rule consumes it; base is a no-op.
func observe_pitch_ready(_ready: bool) -> void:
	pass


## Story 7-11 (G1, AC 3): the arm after one `observe_hand_ids` push, PURE so the rule is headless-testable.
## Clears ONLY on the armed slot's own non-EMPTY -> EMPTY transition between two consecutive emissions:
## the emission's payload, never a sample of state, so a same-id refill delivered in the same drain still
## shows the EMPTY in between and still clears. A cover (Boulder) or its removal changes the visible id
## without ever passing through EMPTY, so it keeps the arm (Q1). An index past either array reads EMPTY.
static func armed_after_hand_change(armed: int, prev_ids: Array, ids: Array) -> int:
	if armed < 0:
		return armed
	var was: StringName = prev_ids[armed] if armed < prev_ids.size() else Hand.EMPTY
	var now: StringName = ids[armed] if armed < ids.size() else Hand.EMPTY
	if was != Hand.EMPTY and now == Hand.EMPTY:
		return -1
	return armed


## Story 6-D1: the hand's per-slot colours (`Enums.CardColor` as int, -1 for an empty slot), PUSHED by
## the runner from the same `cards_changed` wrapper that feeds the HUD tint -- never read off state.
## Only the P1 debug keys consume it; base is a no-op so no other controller needs a stub.
func observe_hand_colors(_colors: Array[int]) -> void:
	pass


## Story 4-6 (AC 9, `CC/R3`): the right-stick CLICK EDGE -- an instant re-lock onto the opposing
## hero, regardless of what is currently locked. The ONLY way to resolve an off-screen opposing
## hero back into lock, which is why it is a distinct control from the flick and not its
## degenerate case.
##
## POLLED BY THE RUNNER, NOT CARRIED ON THE INTENT, and that is the `armed_slot()` precedent
## directly above rather than a new pattern: what the intent carries is the RESOLVED ADDRESS
## (AC 11), and resolving needs a camera the controller has no business holding. The raw gesture
## dies here; only its outcome travels inward and into the record.
##
## Base returns false so every controller with no lock scheme -- NullController, and
## ReplayController, whose recorded intent already carries the resolved address and must never be
## re-resolved -- needs no stub of its own. (Story 6-8, AC 23: KeyboardController now overrides all
## three lock accessors; 4-6 AC 13 had left the keyboard a documented proposal.)
##
## Story 6-8 (AC 1): what the click MEANS is now three-way (unit lock -> hero, hero lock -> unlock,
## unlocked -> hero), and the runner resolves that against the standing lock. This edge is still
## only "the lock control was pressed".
func relock_pressed() -> bool:
	return false


## Story 4-6 (AC 10, `CC/R3`): the right-stick FLICK -- a SCREEN-SPACE direction, or ZERO for no
## flick this tick. Screen space and stick space share the +Y-is-DOWN convention, so the raw stick
## vector IS the screen direction and no controller performs a conversion.
##
## An EDGE, like `relock_pressed()`: a held stick flicks once, not once per tick.
##
## Same base-returns-neutral reasoning as `relock_pressed()` above.
func retarget_flick() -> Vector2:
	return Vector2.ZERO


## Story 6-8 (AC 7, Open Question 2): the UNLOCKED camera's rotation axis this tick, in [-1, 1] --
## +1 turns the view fully right, -1 fully left, 0 leaves it where it is. A LEVEL, not an edge: unlike
## `retarget_flick()` the rotation is continuous, so a held input keeps turning.
##
## POLLED BY THE RUNNER, NOT CARRIED ON THE INTENT, on the `relock_pressed()` precedent above -- and
## here the reason is stronger: the rotation reaches state only as the rig basis the runner already
## pushes and records every tick (`capture_set_camera_basis`), so carrying the raw axis inward as well
## would be a second record of one fact.
##
## Base returns 0.0 for the same no-stub reasoning; ReplayController in particular must not turn a
## replayed rig from a live input.
func camera_rotate() -> float:
	return 0.0
