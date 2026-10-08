class_name DaggerActor
extends Node3D

## Story 6-6b (AC 11): GREEN's thrown dagger -- PURE PRESENTATION. No state object, no hitbox, no
## board entry, no `push_contact`. It is launched by the runner at the throw clip's measured release
## frame, translated toward the attacker over what is left of GREEN's busy span, and freed on arrival
## or on counter teardown. It never gates or changes an outcome.
##
## WHY `ProjectileActor` IS NOT REUSED, measured rather than asserted (AC 11): that actor carries a
## gameplay `Hitbox` (`Area3D`, layer 4 / mask 2) whose own scene description says the runner gathers
## `get_overlapping_areas()` from it and pushes the result through `MatchState.push_contact`; it is
## driven by a runner-owned heading against a STATE-flagged liveness on the projectile board, and it
## is spawned off that board. A dagger with any of that would be a second damage source the ladder
## never authorised. What IS borrowed is only its idea: plain translation, no body.
##
## A SCRIPT AND NO `.tscn` (dev-pass decision, the "dagger projectile node shape" the story left
## open). The totem/projectile precedent is a scene because those actors compose a body, a collision
## shape and a hurtbox that a designer edits; this one composes NOTHING -- it is the imported model
## under a `Node3D` and a straight line. A scene file would be an empty wrapper with a uid to
## maintain, and it would invite exactly the hitbox this AC forbids being added "just like the others".
##
## NO `_physics_process` (INVARIANT F1 -- the scan covers all of `src/`): the runner advances the
## flight from its own one tick loop, the same seat that drives every other actor.

const MODEL := preload("res://assets/props/dagger/dagger.fbx")

## Story 6-6b POST-SMOKE (R-S5): how much bigger than authored the thrown dagger is drawn. At the
## model's own scale the smoke could not SEE it cross the gap -- a correctly flying prop that reads
## as nothing is the same defect as no prop at all, and "what you see must be what happens" is what
## this number restores. PRESENTATION ONLY, on the node's own transform: the dagger has no hitbox,
## no board entry and no `push_contact` (AC 11), so a scale cannot reach an outcome. Its flight
## ORIGIN is unchanged (the runner's throwing-hand height), which R-S5 keeps as it was.
const MODEL_SCALE := 2.5

## Story 7-10 (AC 12): THE TRAIL -- a world-space particle stream left behind the flying dagger, tapering as it
## goes (`EffectFx.shrink_over_life`), so the throw reads as a streak across the gap. Feel knobs: the trail's
## colour (a pale green, GREEN's family lightened so it reads on any background), particle count, size (metres)
## and life (seconds).
const TRAIL_COLOR := Color(0.75, 1.0, 0.75)
const TRAIL_AMOUNT := 40
const TRAIL_SIZE := 0.22
const TRAIL_LIFETIME := 0.25

## Metres per second along the straight line to the target, set at launch from the distance and the
## time left in the busy span, so the dagger ARRIVES with the counter rather than at a fixed speed.
var _speed := 0.0
var _target := Vector3.ZERO
var _arrived := false


func _ready() -> void:
	var model := MODEL.instantiate()
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	var trail := EffectFx.shrink_over_life(EffectFx.particles(EffectFx.TEX_WISP, TRAIL_COLOR, TRAIL_AMOUNT,
			TRAIL_LIFETIME, TRAIL_SIZE, 0.0, 0.0, 0.0, false, false))
	trail.name = "Trail"
	add_child(trail)


## Aim this dagger at `target` and cross the gap in `seconds`. A non-positive time or a zero gap
## arrives immediately, which the runner reads as "free it" on the next advance -- defined rather
## than a divide by zero.
func launch(from: Vector3, target: Vector3, seconds: float) -> void:
	global_position = from
	_target = target
	var gap := from.distance_to(target)
	_arrived = gap <= 0.0 or seconds <= 0.0
	_speed = 0.0 if _arrived else gap / seconds


## Advance one physics tick along the line. Returns true once the dagger has reached its target, at
## which point the runner frees it.
func advance(delta: float) -> bool:
	if _arrived:
		return true
	var step := _speed * delta
	var remaining := global_position.distance_to(_target)
	if step >= remaining:
		global_position = _target
		_arrived = true
		return true
	global_position += (_target - global_position).normalized() * step
	return false
