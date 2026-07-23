class_name InputIntent
extends RefCounted

## D3 pure per-tick value object. A Controller produces one of these each tick; the
## state layer consumes it and never knows the source (keyboard / gamepad / AI / replay).
##
## LIFETIME (decided E0 item 3): a Controller returns a FRESH InputIntent per sample() —
## an immutable-per-tick value. It is never a reused mutable instance, so the X5 recorder
## (which retains a reference each tick) can never hold N aliases of one ever-changing
## object. Do NOT mutate-and-return a cached instance.
##
## This is INPUT, not persistent state — it is captured separately in the X5 intent
## stream and is deliberately excluded from the to_snapshot() determinism contract.

## KEY CONTRACT (story 1-3): pressed/held keys are PREFIX-FREE action names — &"attack",
## &"block", &"roll". The p1_/p2_ Input Map prefix is the producing controller's private
## business and must never leak into the intent; the state layer's transition table reads
## these keys slot-agnostically.
var move_dir := Vector2.ZERO                    # normalized-ish planar move, this tick
var aim := Vector2.ZERO                         # facing/aim, this tick
var pressed: Dictionary[StringName, bool] = {}  # action -> just-pressed this tick
var held: Dictionary[StringName, bool] = {}     # action -> currently held


func is_pressed(action: StringName) -> bool:
	return pressed.get(action, false)


func is_held(action: StringName) -> bool:
	return held.get(action, false)
