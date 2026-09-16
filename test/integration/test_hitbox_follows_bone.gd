extends SceneTree

## Story 5-0a (AC 3) machine contract: the hero's melee shape TRACKS THE SWORD BONE through the
## swing, and does so without introducing a second rotation source.
##
## WHY THIS FILE HAD TO EXIST BEFORE THE STORY COULD CLAIM AC 3. The at-risk measurement this
## story owes is test_contact_pipeline.gd's contact timing, and that came back byte-identical
## before and after the change. An unchanged result has TWO explanations: the geometry moved and
## the timing genuinely did not shift, or the mechanism is inert and nothing moved at all. The
## contact test cannot tell those apart. This one can, and that is its job -- `_moves` below is
## the assertion that makes the unchanged contact result meaningful rather than suspicious.
##
## The four claims, in the order they are checked:
##   (a) TRACKS -- HitboxShape's world position equals the mixamorig_Sword_joint bone's world
##       position, at several times across the attack clip.
##   (b) MOVES -- that position is genuinely different at different points of the swing. A
##       mechanism that silently no-ops (a bone that failed to resolve, a shape left at its
##       authored offset) passes (a) nowhere and passes (b) never; before 5-0a the shape was a
##       CONSTANT local z 0.9, which is exactly what this rejects.
##   (c) NO SECOND ROTATION -- the shape's own rotation stays identity and the Hitbox node's yaw
##       stays equal to the Mesh's, so the 1-7b single-yaw-source contract is intact. The story
##       flagged parenting under a BoneAttachment3D as the mechanism that would have broken it;
##       this is the check that would have caught that choice.
##   (d) YAW-INDEPENDENT OFFSET -- the shape's LOCAL position is identical under two different
##       facings. That is what proves the offset is expressed in the hero's own un-yawed frame
##       and rides the one shared yaw, rather than being re-derived per facing.
##
## INDEPENDENT ARITHMETIC ON PURPOSE. Production composes the bone chain by hand with
## get_bone_pose() (HeroActor._bone_pose_global), for the cache reason recorded there. This file
## asserts against get_bone_global_pose() -- Godot's own cached composition, which is fresh here
## because this fixture runs real frames. Checking a hand-rolled chain against a re-implementation
## of the same chain would only prove the test agrees with itself.
##
## Run: godot --headless --path . --script res://test/integration/test_hitbox_follows_bone.gd

const TICK := 1.0 / 60.0

## Story 6-7b (AC 4): drive() now also forwards the authored walk/run pair to the animation
## controller. This file drives at ZERO velocity and poses `attack` by hand, so the pair never picks
## a clip here; a fixture pair (the shipped 2.0/6.0) satisfies the signature.
const FIXTURE_WALK_SPEED := 2.0
const FIXTURE_RUN_SPEED := 6.0

## Half a millimetre. The two compositions are the same product of the same transforms in a
## different order of operations, so anything above float noise is a real disagreement.
const POS_EPS := 0.0005

## Sample points across the attack clip, as fractions of its length. 0.40 is where the sword
## reaches furthest forward (measured: the joint peaks near z 1.2 at t 0.30 of a 0.75 s clip),
## so the set deliberately straddles the swing rather than clustering at the rest pose.
const SAMPLES: Array[float] = [0.0, 0.2, 0.3, 0.4, 0.5, 0.7, 0.9]

## What the shape's local position was for every tick of every swing before this story. Named so
## the "it no longer sits still" claim is checked against the actual prior value, not a vibe.
const PRE_5_0A_STATIC_OFFSET := Vector3(0.0, 0.0, 0.9)

var _hero: HeroActor
var _player: AnimationPlayer
var _state: HeroState
var _bone := -1
var _frames := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_hero = load("res://src/actors/hero/hero.tscn").instantiate() as HeroActor
	root.add_child(_hero)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## Pose the rig at `t` seconds into the attack clip and drive one tick, exactly as the runner
## would. Returns the shape's local position so callers can compare across calls.
func _pose_and_drive(t: float, facing: Vector2) -> Vector3:
	_player.play(&"attack")
	_player.seek(t, true)
	_state.velocity = Vector3.ZERO
	_state.facing = facing
	_hero.drive(_state, TICK, FIXTURE_WALK_SPEED, FIXTURE_RUN_SPEED)
	return _hero.hitbox_shape.position


func _run_checks() -> void:
	var facing := Vector2(0.0, 1.0)
	var length: float = _player.get_animation(&"attack").length
	var seen: Array[Vector3] = []

	for fraction: float in SAMPLES:
		var t: float = fraction * length
		var local := _pose_and_drive(t, facing)
		seen.append(local)

		# (a) TRACKS: the shape is where the bone is, in world space.
		var want: Vector3 = (_hero.skeleton.global_transform
			* _hero.skeleton.get_bone_global_pose(_bone)).origin
		var got: Vector3 = _hero.hitbox_shape.global_position
		_check(got.distance_to(want) <= POS_EPS,
			"t=%.4f: HitboxShape at %s, sword bone at %s (%.5f apart, eps %.5f)"
				% [t, got, want, got.distance_to(want), POS_EPS])

		# (c) NO SECOND ROTATION, checked at every sample rather than once: the shape's own
		# basis is never written, and the Hitbox and Mesh still share the one yaw.
		_check(_hero.hitbox_shape.quaternion.is_equal_approx(Quaternion.IDENTITY),
			"t=%.4f: HitboxShape carries its own rotation %s - AC 3 moves POSITION only"
				% [t, _hero.hitbox_shape.quaternion])
		_check(is_equal_approx(_hero.hitbox.rotation.y, _hero.mesh.rotation.y),
			"t=%.4f: Hitbox yaw %.6f != Mesh yaw %.6f - the single-yaw-source contract broke"
				% [t, _hero.hitbox.rotation.y, _hero.mesh.rotation.y])

	# (b) MOVES: not a constant, and not the constant it used to be.
	var spread := 0.0
	for a: Vector3 in seen:
		for b: Vector3 in seen:
			spread = maxf(spread, a.distance_to(b))
	_check(spread > 0.5,
		("the shape's position varied by only %.4f across the whole swing - a bone-following "
		+ "hitbox sweeps; an inert one does not (samples %s)") % [spread, seen])
	for local: Vector3 in seen:
		_check(not local.is_equal_approx(PRE_5_0A_STATIC_OFFSET),
			"the shape sat at the pre-5-0a static offset %s - the mechanism did not engage"
				% PRE_5_0A_STATIC_OFFSET)

	# (d) YAW-INDEPENDENT OFFSET: same pose, quarter-turn of facing, same LOCAL position.
	var turned := Vector2(1.0, 0.0)
	for fraction: float in SAMPLES:
		var t: float = fraction * length
		var a := _pose_and_drive(t, facing)
		var b := _pose_and_drive(t, turned)
		_check(a.distance_to(b) <= POS_EPS,
			("t=%.4f: local offset differs by facing (%s vs %s) - the offset must live in the "
			+ "hero's own frame and be rotated by the ONE shared yaw, not re-derived per facing")
				% [t, a, b])


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	_state = HeroState.new(SignalQueue.new(), 100.0, 5.0)
	_player = _hero.animation_controller.animation_player
	_bone = _hero.skeleton.find_bone(HeroActor.SWORD_BONE)
	if _player == null:
		_failures.append("hero.tscn did not yield a wired AnimationController")
	elif _bone < 0:
		_failures.append("the paladin rig has no '%s' bone" % HeroActor.SWORD_BONE)
	else:
		_run_checks()

	if is_instance_valid(_hero):
		_hero.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
