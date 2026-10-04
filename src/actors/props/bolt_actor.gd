class_name BoltActor
extends Node3D

## Story 6-5c (AC 25): HONED BOLT'S VISIBLE BOLT -- PURE PRESENTATION, on `DaggerActor`'s precedent
## and for its stated reasons. No state object, no hitbox, no board entry, no `push_contact`, no
## `.tscn` (it composes nothing a designer would edit). It never gates or changes an outcome: the
## state layer's step-6c strike is what damages, stuns and roots, and this prop only has to ARRIVE
## on the same tick.
##
## IT COUNTS TICKS, WHERE THE DAGGER COUNTS SECONDS, and that difference is the whole reason this is
## a second prop rather than a reuse. `DaggerActor.advance(delta)` walks a float speed toward a
## float target and arrives "about when" the counter ends -- fine for a prop nothing pins. AC 25
## pins THIS prop's arrival to the state's STRIKE TICK and a headless test asserts it, so the flight
## is an integer count: `total_ticks` advances, then arrival, with no accumulated float error that
## could land it a tick early or late.
##
## TWO LEGS (AC 25's "leaves the raised sword into the sky, then crashes down on the target"): the
## RISE from the caster's raised sword to an apex above the target, then the FALL straight down onto
## the target. The apex is recomputed from the target's LIVE position every tick, so a bolt cast at
## a walking hero still lands on it -- which is honest, because the state layer's bolt cannot miss.
##
## NO `_physics_process` (INVARIANT F1 -- the scan covers all of `src/`): the runner advances the
## flight from its own one tick loop, the same seat that drives every other actor.

## How high above the target the bolt turns over, in metres. High enough that the fall reads as
## coming out of the sky rather than as a lob, and low enough to stay inside a split-screen frame.
const SKY_HEIGHT := 9.0

## How much of the flight is spent RISING. Under half, so the crash-down -- the half a target has to
## read and roll away from -- is the longer and more legible leg.
const RISE_FRACTION := 0.4

## Story 7-1 (AC 18) RETIRES THE PLACEHOLDER SHAFT (`6-5c`'s unshaded blue cylinder). What flies now is the
## bolt's CHARGE -- a crackling blue mote that rises off the sword into the sky and drops onto the target, on the
## unchanged tick-counted two-leg flight below -- and the STRIKE itself is `EffectPresenter.show_lightning`'s
## branching lightning and flash, spawned by the runner on the strike tick. Timing is untouched: this prop still
## arrives on the state's strike tick (`test_cast_presentation_live.gd`).
const MOTE_SIZE := 0.7
const MOTE_COLOR := Color(0.6, 0.85, 1.0, 1.0)

var _from := Vector3.ZERO
var _total_ticks := 0
var _rise_ticks := 0
var _ticks := 0
var _arrived := false


func _ready() -> void:
	add_child(EffectFx.quad(EffectFx.TEX_GLOW, MOTE_COLOR, MOTE_SIZE, true))
	add_child(EffectFx.particles(EffectFx.TEX_SPARK, MOTE_COLOR, 10, 0.25, 0.45, 1.0, 180.0, 0.0, false, false))


## Start the flight at `from`, bound for `target`, arriving after exactly `total_ticks` advances.
## A non-positive count arrives immediately, which the runner reads as "it is already there" --
## defined rather than a division by zero.
func launch(from: Vector3, target: Vector3, total_ticks: int) -> void:
	_from = from
	_total_ticks = maxi(total_ticks, 0)
	_rise_ticks = clampi(int(round(float(_total_ticks) * RISE_FRACTION)), 1, maxi(_total_ticks - 1, 1))
	_ticks = 0
	_arrived = _total_ticks <= 0
	global_position = from if not _arrived else target


## Advance exactly one tick toward `target`'s CURRENT position. Returns true on the tick the bolt
## lands -- which is the tick the state layer strikes on (AC 25).
func advance(target: Vector3) -> bool:
	if _arrived:
		return true
	_ticks += 1
	var apex := target + Vector3(0.0, SKY_HEIGHT, 0.0)
	if _ticks >= _total_ticks:
		global_position = target
		_arrived = true
		return true
	if _ticks <= _rise_ticks:
		global_position = _from.lerp(apex, float(_ticks) / float(_rise_ticks))
	else:
		global_position = apex.lerp(target,
				float(_ticks - _rise_ticks) / float(_total_ticks - _rise_ticks))
	return false


## Has this bolt landed? Read by the runner, which frees it on the tick AFTER arrival so the landing
## frame is actually drawn, and by the AC 25 test, which asserts it is true at the instant the state
## layer's own `hit_landed` fires.
func has_arrived() -> bool:
	return _arrived
