class_name Invariant
extends RefCounted

## X1: an invariant guard that SURVIVES export. Godot strips assert() in release builds, so a
## bare assert gives exported playtest builds no check at all — not a softer one. This routes
## through a normal runtime branch (`if not condition`) that survives export.
##
## E0: dev-mode fail-fast — push_error (which survives export) plus assert() for an editor halt.
## Playtest-mode Log.error+continue arrives with the Log util (X2).

static func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("INVARIANT VIOLATED: " + message)
		assert(condition, message)
