class_name ImmunityShimmer
extends Node3D

## Story 7-10 (S4, AC 15): THE POST-KNOCKDOWN IMMUNITY, MADE VISIBLE -- a subtle silver shimmer on a hero while
## its 7-9 `unblockable_immunity` window runs, fading with the window's remaining fraction and gone on expiry,
## death and reset. It is a child of the hero actor, and both split-screen SubViewports render the one shared
## `World3D`, so both players see it.
##
## PRESENTATION ONLY (AC 17/AC 18): built in code, no collision shape, no `Area3D`, no signal into state, no
## `_physics_process` (F1). LEVEL-TRIGGERED: the runner pushes the fraction every tick from its post-`advance()`
## poll (`set_fraction`), so the marker ends on whatever path ends the window -- the `set_root_marker` precedent --
## with no falling edge of its own to remember.
##
## SILVER, NEVER AN UNBLOCKABLE COLOUR: `SHIMMER_COLOR` is a desaturated cool white, pinned against the three
## charge colours by `test/integration/test_unblockable_presentation_knobs.gd`.

## KNOBS (feel values, tuned at smoke; tests pin bounds and directions only).
const SHIMMER_COLOR := Color(0.82, 0.86, 0.92)
## Alpha at a full window; the shimmer fades linearly to 0 with the remaining fraction.
const SHIMMER_ALPHA := 0.7
## Sparkle count, size (metres) and life (seconds), and the body-hugging box they spawn in (half extents,
## metres, around the hero root, which is the body centre).
const SHIMMER_AMOUNT := 28
const SHIMMER_SIZE := 0.1
const SHIMMER_LIFETIME := 0.6
const SHIMMER_EXTENTS := Vector3(0.32, 0.85, 0.32)
## How fast the sparkles drift upward, metres per second.
const SHIMMER_RISE_SPEED := 0.25

var _particles: GPUParticles3D
var _fraction := 0.0


func _ready() -> void:
	_particles = EffectFx.prewarm(EffectFx.emit_box(EffectFx.particles(EffectFx.TEX_STAR, SHIMMER_COLOR,
			SHIMMER_AMOUNT, SHIMMER_LIFETIME, SHIMMER_SIZE, SHIMMER_RISE_SPEED, 25.0, 0.0, false, true),
			SHIMMER_EXTENTS))
	add_child(_particles)
	set_fraction(0.0)


## The window's remaining fraction, 0 when it is not running. 0 hides; above 0 shows at that strength.
func set_fraction(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	_fraction = f
	visible = f > 0.0
	_particles.emitting = f > 0.0
	var pm := _particles.process_material as ParticleProcessMaterial
	pm.color = Color(SHIMMER_COLOR.r, SHIMMER_COLOR.g, SHIMMER_COLOR.b, SHIMMER_ALPHA * f)


## The strength last pushed -- what a test reads.
func fraction() -> float:
	return _fraction
