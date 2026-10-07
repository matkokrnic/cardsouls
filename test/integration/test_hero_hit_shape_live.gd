extends SceneTree

## Story 7-8 (AC 11/AC 12, `7-8/R9`): THE HERO HIT SHAPE, proved LIVE against `hero.tscn` with real frames,
## in IDLE and MID-ROLL (the `test_honest_hit_geometry_live.gd` precedent: the real runner, the real rig,
## `HeroActor.drive()` reparking the shape every tick).
##
## WHAT IS PROVED, on every judged frame:
##   * TRACKING -- the `Hurtbox` shape sits HURTBOX_DROP below the paladin's trunk bone (`TRUNK_BONE`),
##     i.e. it follows the trunk, including through the roll's sideways trunk excursion. Measured
##     against the pose the shape was COMPUTED from: `drive()` reads the pose the last rendered frame
##     produced and the animation then advances in `_process` (the stated `_track_weapon_bone` sub-frame
##     lag), so this callback compares the shape with the trunk offset it read ONE callback earlier,
##     body-relative (the body itself moves between the two). Mid-roll the trunk travels ~0.2 m per
##     frame, which is why a same-frame comparison would measure the lag rather than the tracking;
##   * ON THE TORSO -- a small probe at the trunk bone overlaps the hero's `Hurtbox` area;
##   * INSIDE THE OLD BOX, OFF THE TRUNK -- a probe placed inside the old 1 x 2 x 1 box (proved by its
##     overlapping the body `Collision`, which keeps that box, AC 12) but well clear of the trunk does NOT
##     overlap the `Hurtbox` area. That is the whole of AC 11's geometric claim: grazing the air beside the
##     hero no longer reaches the volume every hit consumer reads.
##
## THE PROBES ARE PHYSICS-SERVER QUERIES (`intersect_shape` on the live space), asked from this script's
## own physics callback -- the state the last physics step left, the same state every consumer's
## `get_overlapping_areas()` reads. The mid-roll window is identified off the REAL roll clip's playhead,
## and the case also requires the trunk bone to be measurably out of the root's planar position there, so
## it cannot pass on a frame where the roll has not yet moved the trunk.
##
## MUTATION: point `Hurtbox/HurtboxShape` back at the body box (`BoxShape3D_qp0e8`) and this goes RED --
## the off-trunk probe inside the old box overlaps it.
##
## Run: godot --headless --path . --script res://test/integration/test_hero_hit_shape_live.gd

class RollOnceController extends Controller:
	var roll_next := false

	func sample() -> InputIntent:
		var intent := InputIntent.new()
		if roll_next:
			intent.pressed[&"roll"] = true
			intent.held[&"roll"] = true
			roll_next = false
		return intent


## The probe sphere's radius: small next to every margin below, so a hit or a miss is the shape's.
const PROBE_R := 0.04
## How far INSIDE the old box's 0.5 half-extent the off-trunk probe stays, so it is inside by a margin
## and its overlap with the body box is not a grazing coincidence.
const BOX_INSET := 0.05
## The off-trunk probe must clear the hit shape's radius by at least this much, planar -- the bound that
## keeps one tick of sub-frame lag from deciding the result.
const CLEAR_MARGIN := 0.12
## TRACKING tolerance, body-relative against the pose the shape was computed from: float slack only.
const TRACK_EPS := 0.01
## The roll clip's mid-window, as a fraction of its length.
const MID_ROLL := Vector2(0.4, 0.6)
## The trunk bone must be at least this far (planar) from the root for a frame to count as mid-roll
## excursion -- measured 0.29-0.31 m at the clip's middle (tools/measure_torso_envelope.gd).
const MIN_EXCURSION := 0.15
const IDLE_SETTLE := 20
const IDLE_CHECKS := 10
const DEADLINE := 400

var _frames := 0
var _runner: Node
var _hero: HeroActor
var _anim: AnimationPlayer
var _holder: RollOnceController
var _failures: Array[String] = []
var _phase := "idle"
var _idle_checked := 0
var _roll_checked := 0
var _roll_frame := -1
## The trunk bone's body-relative offset as read in the PREVIOUS callback -- the pose this frame's shape
## was computed from. INF until the first read.
var _prev_offset := Vector3(INF, INF, INF)


func _initialize() -> void:
	root.add_child((load("res://src/main/main.tscn") as PackedScene).instantiate())


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_hero = _runner._p1_hero if _runner != null else null
		if _hero == null:
			_failures.append("main scene did not yield a runner and a P1 hero")
			return _report()
		_anim = _hero.get_node("Mesh/Paladin/AnimationPlayer") as AnimationPlayer
		_holder = RollOnceController.new()
		_runner._p1_controller = _holder
		return false
	if _frames > DEADLINE:
		_failures.append("deadline: phase %s, %d idle and %d mid-roll frames judged"
			% [_phase, _idle_checked, _roll_checked])
		return _report()
	var offset := _trunk_world() - _hero.global_position
	var judged_offset := _prev_offset
	_prev_offset = offset
	if judged_offset.x == INF:
		return false
	if _phase == "idle":
		if _frames < IDLE_SETTLE:
			return false
		_judge("idle frame %d" % _frames, judged_offset)
		_idle_checked += 1
		if _idle_checked >= IDLE_CHECKS:
			_phase = "roll"
			_holder.roll_next = true
			_roll_frame = _frames
		return false
	if _phase == "roll":
		if _frames - _roll_frame > 3 and _anim.current_animation != &"roll" and _roll_checked > 0:
			return _report()
		if _anim.current_animation != &"roll":
			return false
		var f := _anim.current_animation_position / maxf(_anim.current_animation_length, 1e-6)
		if f < MID_ROLL.x or f > MID_ROLL.y:
			return false
		var spine := _trunk_world()
		var excursion := Vector2(spine.x - _hero.global_position.x, spine.z - _hero.global_position.z)
		if excursion.length() < MIN_EXCURSION:
			return false
		_judge("mid-roll frame %d (playhead %.2f, trunk %.2f m off the root)"
			% [_frames, f, excursion.length()], judged_offset)
		_roll_checked += 1
		return false
	return false


## One frame's three claims. `offset` is the trunk bone's body-relative position the shape was computed
## from (the previous callback's read).
func _judge(label: String, offset: Vector3) -> void:
	var shape := _hero.hurtbox_shape
	var cyl := shape.shape as CylinderShape3D
	# Not a cylinder: recorded, and the probes still run -- so a hit shape reverted to the body box is
	# caught by the geometry below and not only by this type check.
	_check(cyl != null, "%s: the hero hit shape is not its own cylinder (%s)" % [label, shape.shape])
	var radius := cyl.radius if cyl != null else 0.0
	var centre := shape.global_position
	# TRACKING: the shape follows the trunk bone, HURTBOX_DROP below it, body-relative.
	var want := _hero.global_position + offset - Vector3(0.0, HeroActor.HURTBOX_DROP, 0.0)
	_check(centre.distance_to(want) <= TRACK_EPS,
		"%s: the hit shape sits %.3f m from the trunk bone's tracked point (tolerance %.2f)"
			% [label, centre.distance_to(want), TRACK_EPS])
	# ON THE TORSO: the trunk bone as the shape last saw it.
	var torso := centre + Vector3(0.0, HeroActor.HURTBOX_DROP, 0.0)
	_check(_overlaps_hurtbox(torso), "%s: a probe ON the torso (%v) does not overlap the hurtbox"
		% [label, torso])
	# INSIDE THE OLD BOX, OFF THE TRUNK: the old box's corner column farthest from the shape's axis, at
	# the shape's own height clamped into the box.
	var root_pos := _hero.global_position
	var half := 0.5 - BOX_INSET
	var y := clampf(centre.y, root_pos.y - 1.0 + BOX_INSET, root_pos.y + 1.0 - BOX_INSET)
	var best := Vector3.ZERO
	var best_d := -1.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(root_pos.x + sx * half, y, root_pos.z + sz * half)
			var d := Vector2(p.x - centre.x, p.z - centre.z).length()
			if d > best_d:
				best_d = d
				best = p
	_check(best_d >= radius + PROBE_R + CLEAR_MARGIN,
		"%s: sanity -- no corner of the old box clears the hit shape by the margin (%.3f)" % [label, best_d])
	_check(_overlaps_body(best),
		"%s: sanity -- the off-trunk probe %v is not inside the body box, so it proves nothing" % [label, best])
	_check(not _overlaps_hurtbox(best),
		"%s: a probe inside the old 1x2x1 box but %.2f m off the trunk axis overlaps the hurtbox (AC 11)"
			% [label, best_d])


func _trunk_world() -> Vector3:
	var idx := _hero.skeleton.find_bone(HeroActor.TRUNK_BONE)
	return _hero.skeleton.global_transform * _hero._bone_pose_global(idx).origin


func _query(at: Vector3, mask: int, areas: bool) -> Array[Dictionary]:
	var sphere := SphereShape3D.new()
	sphere.radius = PROBE_R
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = mask
	q.collide_with_areas = areas
	q.collide_with_bodies = not areas
	return _hero.get_world_3d().direct_space_state.intersect_shape(q, 16)


func _overlaps_hurtbox(at: Vector3) -> bool:
	for hit in _query(at, 2, true):
		if hit["collider"] == _hero.hurtbox:
			return true
	return false


func _overlaps_body(at: Vector3) -> bool:
	for hit in _query(at, 1, false):
		if hit["collider"] == _hero:
			return true
	return false


func _report() -> bool:
	_check(_idle_checked >= IDLE_CHECKS, "only %d idle frames judged" % _idle_checked)
	_check(_roll_checked > 0, "no mid-roll frame was judged -- the roll case would pass vacuously")
	print("judged %d idle and %d mid-roll frames" % [_idle_checked, _roll_checked])
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
