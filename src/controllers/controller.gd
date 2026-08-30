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
## Base returns -1 so a controller with no card scheme — NullController, and GamepadController
## until its own profile lands — renders no selection rather than needing a stub each.
func armed_slot() -> int:
	return -1


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
## Base returns false so every controller with no right-stick scheme -- NullController,
## KeyboardController (AC 13 leaves keyboard a documented PROPOSAL), and ReplayController, whose
## recorded intent already carries the resolved address and must never be re-resolved -- needs no
## stub of its own.
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
