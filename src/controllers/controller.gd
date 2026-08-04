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
