class_name Controller
extends RefCounted

## D3 interface: produces a pure-data InputIntent each tick. State consumes it and never
## knows the source (keyboard / gamepad / scripted AI / replay) — dummy -> PvP -> bot is a
## config swap. Returns a FRESH InputIntent per sample() (immutable-per-tick value object).

func sample() -> InputIntent:
	return InputIntent.new()  # override per implementation
