class_name OrbHalo
extends Node3D

## Story 7-6 (R7, AC 27/AC 28): THE WORLD ORBS -- one glowing wisp per orb a hero holds, in that orb's colour.
##
## 7-6 POLISH (operator ruling P5, 2026-10-05): SOFT WISPS, NOT A RING. Each orb is a soft glow (the 7-1 Kenney
## `circle_05` glow quad, with a small bright additive core) that drifts IRREGULARLY around its hero -- its own
## orbit speed, radius and height wobble, derived from its index so nothing is random -- and FOLLOWS WITH INERTIA:
## every wisp is `top_level`, so it is not dragged rigidly by the hero; each frame it eases toward its drifting
## target beside the hero (an exponential approach at its own `follow_rate`), so it lags behind a moving hero and
## catches up when the hero stops. That per-frame drift is the one reason this presenter has a `_process` --
## presentation only, in `src/actors/` (the `_process` ban is `src/ui/`'s; F1 bans only `_physics_process`).
##
## PUBLIC BY CONSTRUCTION, NOT BY A CROSS-SLOT READ (M4). The halo is a child of its own hero in the ONE shared
## `World3D` both SubViewports render, so both halves see both heroes' wisps without any viewport learning the
## other player's counts through a seam. It is wired, like `TelegraphController`'s earn cue, to its OWN hero's
## `connect_orbs_changed` -- the ninth seam's third consumer, no new seam.
##
## PRESENTATION ONLY: it holds no state handle and decides nothing; the COUNT is exact -- exactly `_counts[c]`
## visible wisps of colour c, re-laid only when a payload arrives.

## The drift envelope, relative to the hero's root (body centre; the feet are ~1 m below it): mean orbit radius
## and its wobble, mean height and its bob, in metres.
const ORBIT_RADIUS := 0.62
const RADIUS_WOBBLE := 0.16
const ORBIT_HEIGHT := 0.3
const HEIGHT_BOB := 0.18
## Angular drift in rad/s -- each wisp gets its own speed inside this band, so the group never moves as a ring.
const DRIFT_SPEED_MIN := 0.45
const DRIFT_SPEED_MAX := 1.05
## How fast a wisp closes on its target, per second (exponential approach) -- each wisp its own rate in this band.
const FOLLOW_RATE_MIN := 2.2
const FOLLOW_RATE_MAX := 3.6
## The glow and its core, in metres. The glow is ALPHA-blended in the orb's hue (an additive glow washes out on the
## light arena floor -- seen at the polish capture); the small core is additive and lightened, so it burns bright.
## 7-6 POLISH 2 (operator ruling P10): smaller (0.85/0.26 -> 0.5/0.16) for the closer P11 camera. NO COLLISION OF ANY
## KIND: a wisp is a Node3D holding two MeshInstance3D quads -- no CollisionObject3D, Area3D, body or shape, pinned
## by test_history_and_orbs_live.gd.
const GLOW_SIZE := 0.5
const CORE_SIZE := 0.16
## A slow brightness breath, so a still wisp still reads as alive.
## 7-6 POLISH 3 (operator ruling P16): the hero's BODY RADIUS (horizontal, metres). No wisp is ever inside it: each
## frame a wisp that drift or catch-up would carry inside is pushed back out radially, so it slides AROUND the body
## instead of through it. Presentation only -- still no collision of any kind (the P10 pin).
const BODY_RADIUS := 0.42
const PULSE_SPEED := 2.3
const PULSE_DEPTH := 0.25

const _TEX_GLOW := preload("res://assets/vfx/circle_05.png")
## The golden-ratio conjugate: index -> a well-spread fraction in [0, 1), the wisps' only "randomness".
const _PHI := 0.6180339887

var _colors: Array[Color] = []
## One pooled wisp list per colour, index-aligned with `Enums.CardColor` (RED, BLUE, GREEN).
var _wisps: Array = [[], [], []]
var _counts: Array[int] = [0, 0, 0]
var _time := 0.0


func _init() -> void:
	name = "OrbHalo"


## The three hues, index-aligned with `Enums.CardColor` (the hero's own charge-telegraph colours, so the wisps,
## the HUD counter and the charge flash read as one colour). Call before add_child.
func setup(colors: Array[Color]) -> void:
	_colors = colors


## Seam callback (`connect_orbs_changed`, this hero's own slot; primed on connect with the resting 0,0,0).
func on_orbs_changed(red: int, blue: int, green: int) -> void:
	_counts = [red, blue, green]
	_layout()


## How many orbs of each colour are currently shown -- the AC 28 read, off the live nodes.
func shown_counts() -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	for c in 3:
		for wisp: Node3D in _wisps[c]:
			if wisp.visible:
				out[c] += 1
	return out


## Every visible wisp, in layout order -- the test-facing read for the drift/inertia checks.
func visible_wisps() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in 3:
		for wisp: Node3D in _wisps[c]:
			if wisp.visible:
				out.append(wisp)
	return out


## Show exactly `_counts[c]` wisps of each colour. A newly shown wisp appears AT its target (no fly-in from the
## world origin); an already-shown one keeps its position and simply drifts to its new place in the order.
func _layout() -> void:
	if not is_inside_tree():
		return
	var k := 0
	for c in 3:
		var pool: Array = _wisps[c]
		var want := maxi(0, _counts[c])
		while pool.size() < want:
			pool.append(_make_wisp(c, pool.size()))
		for n in pool.size():
			var wisp: Node3D = pool[n]
			var shown := n < want
			if shown:
				wisp.set_meta(&"order", k)
				if not wisp.visible:
					wisp.global_position = _outside_body(_target(k))
				k += 1
			wisp.visible = shown


func _ready() -> void:
	_layout()


func _process(delta: float) -> void:
	_time += delta
	# Walks the pools directly (no per-frame array): only shown wisps move.
	for pool: Array in _wisps:
		for wisp: Node3D in pool:
			if not wisp.visible:
				continue
			var k := int(wisp.get_meta(&"order", 0))
			var rate := lerpf(FOLLOW_RATE_MIN, FOLLOW_RATE_MAX, fmod(k * _PHI * 3.0, 1.0))
			wisp.global_position = _outside_body(wisp.global_position.lerp(_target(k), 1.0 - exp(-rate * delta)))
			var pulse := 1.0 - PULSE_DEPTH * (0.5 + 0.5 * sin(_time * PULSE_SPEED + k * 1.7))
			(wisp.get_child(0) as GeometryInstance3D).transparency = 1.0 - pulse


## P16: `point` pushed out to `BODY_RADIUS` from the hero's vertical axis when it is inside it (height kept), so a
## wisp's path bends around the body. A point exactly on the axis leaves along +X.
func _outside_body(point: Vector3) -> Vector3:
	var centre := global_position
	var flat := Vector2(point.x - centre.x, point.z - centre.z)
	if flat.length() >= BODY_RADIUS:
		return point
	var dir := flat.normalized() if flat.length() > 0.0001 else Vector2.RIGHT
	return Vector3(centre.x + dir.x * BODY_RADIUS, point.y, centre.z + dir.y * BODY_RADIUS)


## Wisp `k`'s drifting target in world space: its own angle advancing at its own speed, a wobbling radius and a
## bobbing height, all around the hero's CURRENT position. Deterministic from `k` and the halo's own clock.
func _target(k: int) -> Vector3:
	var f := fmod((k + 1) * _PHI, 1.0)
	var speed := lerpf(DRIFT_SPEED_MIN, DRIFT_SPEED_MAX, f)
	var angle := TAU * f + _time * speed
	var radius := ORBIT_RADIUS + RADIUS_WOBBLE * sin(_time * (0.7 + f) + k * 2.1)
	var height := ORBIT_HEIGHT + HEIGHT_BOB * sin(_time * (1.1 + 0.6 * f) + k * 1.3)
	return global_position + Vector3(cos(angle) * radius, height, sin(angle) * radius)


## One wisp: a `top_level` Node3D (so the hero does not carry it rigidly) holding a soft glow and a small bright
## additive core, both camera-facing quads built by the 7-1 `EffectFx.quad` block.
func _make_wisp(c: int, n: int) -> Node3D:
	var hue: Color = _colors[c] if c < _colors.size() else Color.WHITE
	var wisp := Node3D.new()
	wisp.name = "Wisp%d_%d" % [c, n]
	wisp.top_level = true
	wisp.visible = false
	add_child(wisp)
	var glow := EffectFx.quad(_TEX_GLOW, Color(hue.r, hue.g, hue.b, 0.9), GLOW_SIZE, true, false)
	glow.name = "Glow"
	wisp.add_child(glow)
	var core := EffectFx.quad(_TEX_GLOW, hue.lightened(0.6), CORE_SIZE, true, true)
	core.name = "Core"
	wisp.add_child(core)
	return wisp
