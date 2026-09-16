extends SceneTree

## Story 5-0a (AC 2) machine contract: the hero's locomotion clip is chosen from the direction
## of movement RELATIVE TO FACING, not from speed alone and not from world axes.
##
## WHAT DEFECT THIS PINS. Until 5-0a, HeroActor.drive() pushed a scalar `velocity.length()` and
## AnimationController split `run` vs `idle` on it. That was right while facing followed
## movement. Story 4-6 pinned facing to the locked target instead, so from that point a hero
## moving sideways or backwards was moving one way while facing another -- and got the forward
## `run` clip anyway. The legs said "running forward" while the body slid sideways: the
## floating/skating read the E4 close-out named (decision-log:7856-7860) and handed to this
## story.
##
## DRIVEN THROUGH THE REAL PATH, not the controller's front door. Every assertion here goes
## HeroActor.drive() -> AnimationController.on_locomotion() -> AnimationPlayer, because the
## claim under test spans that whole push: a controller that classifies perfectly while drive()
## hands it the wrong two values is the defect, not a passing test. (This is why the file runs
## in `_physics_process` -- drive() ends in move_and_slide(), which belongs in the physics step.)
##
## RELATIVE, NOT ABSOLUTE, is the point of the second block. The four cardinals are asserted
## twice, under two DIFFERENT facings, with the world velocity that means "left" rotated to
## match. A controller that read world axes and ignored facing passes the first block and fails
## the second -- and a world-axis reading is precisely the bug class 4-6 introduced.
##
## STORY 6-7b (AC 4/AC 5) ADDS THE GAIT FAMILY. The same split now runs twice over: a pushed planar
## speed under the MIDPOINT of the authored walk/run pair plays the WALK family (`walk`,
## `walk_backpedal`, `walk_strafe_right`, `walk_strafe_left`), at or above it the RUN family as
## before. `_walk_cardinals` drives the walk tempo under both facings; `_tier_boundary` proves the
## boundary TRACKS THE PAIR by driving two different pairs and one magnitude strictly between their
## midpoints, which must land walk under one pair and run under the other -- a threshold baked into
## the controller passes one pair and fails the other by construction. The authored pair itself is
## READ LIVE from the .tres (the AC 2 property), never pinned here.
##
## Run: godot --headless --path . --script res://test/integration/test_hero_clip_selection.gd

## One physics tick's worth of playback, so a check cannot pass on a clip that was selected and
## then immediately stalled -- the 4-3c `_expect` precedent (test_unit_clip_selection.gd L6).
const TICK := 1.0 / 60.0

## Story 6-7b: the authored config the walk/run pair is read from, LIVE (never a literal copy). Both
## tempos are comfortably above AnimationController.RUN_SPEED_EPS, and they are the magnitudes the
## game actually produces: the run tempo is `move_speed`, the walk tempo is `walk_speed`.
const AUTHORED_BALANCE := "res://data/balance/balance_config.tres"

## Story 6-7b (AC 5): the SECOND pair the tier-boundary case drives, beside the authored one. Chosen
## so its midpoint (6.0) sits clear of the authored midpoint and both of its tempos differ from the
## authored tempos; `_tier_boundary` refuses to run (fails loudly) if a retune ever makes the two
## midpoints collide.
const OTHER_PAIR_WALK_SPEED := 3.0
const OTHER_PAIR_RUN_SPEED := 9.0

const RUN_FAMILY := {
	&"forward": &"run", &"back": &"backpedal", &"right": &"strafe_right", &"left": &"strafe_left",
}
const WALK_FAMILY := {
	&"forward": &"walk", &"back": &"walk_backpedal",
	&"right": &"walk_strafe_right", &"left": &"walk_strafe_left",
}

var _walk_speed := 0.0
var _run_speed := 0.0
## The pair drive() forwards on the NEXT `_expect` -- the authored pair, except while
## `_tier_boundary` swaps in its own.
var _drive_walk_speed := 0.0
var _drive_run_speed := 0.0

var _hero: HeroActor
var _player: AnimationPlayer
var _state: HeroState
var _frames := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_hero = load("res://src/actors/hero/hero.tscn").instantiate() as HeroActor
	root.add_child(_hero)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## Drive one tick with this world velocity and facing, then assert which clip is playing.
func _expect(velocity: Vector3, facing: Vector2, want: StringName, label: String) -> void:
	_state.velocity = velocity
	_state.facing = facing
	_hero.drive(_state, TICK, _drive_walk_speed, _drive_run_speed)
	_player.advance(TICK)
	var got: StringName = _player.current_animation
	_check(got == want, "%s: expected clip '%s', got '%s'" % [label, want, got])


## The four cardinals plus rest, expressed in the hero's OWN frame and then rotated into world
## space by the caller. `forward` is along facing; `right` is along (facing.y, -facing.x), the
## same local +X drive()'s yaw produces -- stated once here rather than re-derived per case.
##
## Story 6-7b: parameterised by tempo and family, so the SAME five cases run at the run tempo
## (5-0a's table, unchanged in shape) and at the walk tempo (AC 4) without a second copy.
func _cardinals(facing: Vector2, tag: String, speed: float = -1.0,
		family: Dictionary = RUN_FAMILY) -> void:
	if speed < 0.0:
		speed = _run_speed
	var forward := Vector3(facing.x, 0.0, facing.y) * speed
	var right := Vector3(facing.y, 0.0, -facing.x) * speed
	_expect(Vector3.ZERO, facing, &"idle", "%s: standing still" % tag)
	_expect(forward, facing, family[&"forward"], "%s: moving along facing" % tag)
	_expect(-forward, facing, family[&"back"], "%s: moving opposite facing" % tag)
	_expect(right, facing, family[&"right"], "%s: moving to the hero's right" % tag)
	_expect(-right, facing, family[&"left"], "%s: moving to the hero's left" % tag)


## Story 6-7b (AC 4): at the AUTHORED WALK TEMPO the four cardinals resolve to the walk family, under
## the same two facings as the run table -- so the family split is also relative, not world-axis.
func _walk_cardinals() -> void:
	_cardinals(Vector2(0.0, 1.0), "walk tempo, facing world +Z", _walk_speed, WALK_FAMILY)
	_cardinals(Vector2(1.0, 0.0), "walk tempo, facing world +X", _walk_speed, WALK_FAMILY)


## Story 6-7b (AC 4): the walk/run boundary as the AC states it -- the midpoint of the pair.
static func _midpoint(walk_speed: float, run_speed: float) -> float:
	return (walk_speed + run_speed) * 0.5


## Story 6-7b (AC 5): THE TIER BOUNDARY TRACKS THE AUTHORED PAIR. Under EACH of two different pairs,
## that pair's own walk tempo plays the walk family and its own run tempo the run family (all four
## directions); then ONE magnitude strictly between the two pairs' midpoints must play the walk
## family under the pair whose midpoint is higher and the run family under the other. A threshold
## hardcoded into the controller -- at either midpoint, or anywhere else -- cannot satisfy both.
func _tier_boundary() -> void:
	var facing := Vector2(0.0, 1.0)
	var pairs := [
		[_walk_speed, _run_speed, "authored pair"],
		[OTHER_PAIR_WALK_SPEED, OTHER_PAIR_RUN_SPEED, "other pair"],
	]
	# The oracle is the AC's own formula, computed HERE -- never `AnimationController.gait_threshold`,
	# the function under test (a mutated threshold must not also move the expected answer; found by
	# this story's own mutation pass).
	var midpoint_a := _midpoint(_walk_speed, _run_speed)
	var midpoint_b := _midpoint(OTHER_PAIR_WALK_SPEED, OTHER_PAIR_RUN_SPEED)
	if absf(midpoint_a - midpoint_b) < 0.5:
		_failures.append(("tier boundary: the authored midpoint %.3f and the other pair's %.3f are too "
			+ "close to separate -- move OTHER_PAIR_* so the between-midpoints probe means something")
			% [midpoint_a, midpoint_b])
		return
	for pair in pairs:
		_drive_walk_speed = pair[0]
		_drive_run_speed = pair[1]
		_cardinals(facing, "%s (%.2f/%.2f) at its walk tempo" % [pair[2], pair[0], pair[1]],
			pair[0], WALK_FAMILY)
		_cardinals(facing, "%s (%.2f/%.2f) at its run tempo" % [pair[2], pair[0], pair[1]],
			pair[1], RUN_FAMILY)
	# The probe: halfway between the two midpoints, so strictly above one and below the other.
	var probe := (midpoint_a + midpoint_b) * 0.5
	var forward := Vector3(facing.x, 0.0, facing.y) * probe
	for pair in pairs:
		_drive_walk_speed = pair[0]
		_drive_run_speed = pair[1]
		var midpoint := _midpoint(pair[0], pair[1])
		var want: StringName = &"walk" if probe < midpoint else &"run"
		# Reset through idle so the probe is a real selection, not a leftover from the loop above.
		_expect(Vector3.ZERO, facing, &"idle", "tier boundary: reset before the %s probe" % pair[2])
		_expect(forward, facing, want,
			"tier boundary: speed %.3f under the %s (midpoint %.3f) must play '%s'"
				% [probe, pair[2], midpoint, want])
	_drive_walk_speed = _walk_speed
	_drive_run_speed = _run_speed


## The ONE case that made this story exist, stated as its own assertion rather than left implicit
## in the table above: locked on and moving sideways, the pre-5-0a code played `run`.
func _the_motivating_defect() -> void:
	var facing := Vector2(0.0, 1.0)          # locked on to something straight ahead (world +Z)
	_expect(Vector3(_run_speed, 0.0, 0.0), facing, &"strafe_right",
		"locked on, strafing right: the pre-5-0a code played 'run' here (the skating defect)")
	_expect(Vector3(0.0, 0.0, -_run_speed), facing, &"backpedal",
		"locked on, backing away: the pre-5-0a code played 'run' here (the skating defect)")


## Action states OWN the body while they persist (3-0a): the polled push must not override them,
## however fast the hero is still travelling. Unchanged by 5-0a and asserted so the widened
## payload cannot have quietly loosened the gate.
func _idle_gating() -> void:
	var facing := Vector2(0.0, 1.0)
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.IDLE, HeroState.ActionState.ATTACKING)
	_expect(Vector3(_run_speed, 0.0, 0.0), facing, &"attack",
		"ATTACKING while carrying sideways velocity keeps the attack clip")
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.ATTACKING, HeroState.ActionState.ROLLING)
	_expect(Vector3(0.0, 0.0, -_run_speed), facing, &"roll",
		"ROLLING while carrying backward velocity keeps the roll clip")
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.ROLLING, HeroState.ActionState.IDLE)
	_expect(Vector3(0.0, 0.0, -_run_speed), facing, &"backpedal",
		"back to IDLE: the direction split resumes")


## CONTENT, not just naming -- the guard whose absence would let an empty or mis-retargeted clip
## pass every name and loop check in this file and in test_rig_clips.gd. For each of the three
## clips 5-0a adds, drive the controller to select it, advance real playback, and assert the
## model's mixamorig_Hips bone pose actually MOVES. (The 4-3c `_assert_clip_content_changes`
## precedent, applied to this story's own new clips.)
func _clip_content_changes() -> void:
	var skeleton := _hero.skeleton
	var bone := skeleton.find_bone("mixamorig_Hips")
	if bone < 0:
		_failures.append("content check: mixamorig_Hips bone missing from Skeleton3D")
		return
	var facing := Vector2(0.0, 1.0)
	var right := Vector3(facing.y, 0.0, -facing.x) * _run_speed
	var walk_right := Vector3(facing.y, 0.0, -facing.x) * _walk_speed
	var walk_forward := Vector3(facing.x, 0.0, facing.y) * _walk_speed
	# Story 6-7b: the four walk-family clips join 5-0a's three (the turn pair's content check lives
	# in test_hero_turn_in_place.gd, which is where they are selected).
	var drives := {
		&"strafe_right": right,
		&"strafe_left": -right,
		&"backpedal": Vector3(facing.x, 0.0, facing.y) * -_run_speed,
		&"walk": walk_forward,
		&"walk_backpedal": -walk_forward,
		&"walk_strafe_right": walk_right,
		&"walk_strafe_left": -walk_right,
	}
	for clip: StringName in drives:
		# A clean pass through `idle` first, so each drive is a real switch rather than a no-op
		# against whatever the previous one left selected.
		_expect(Vector3.ZERO, facing, &"idle", "content check: reset to idle before '%s'" % clip)
		_expect(drives[clip], facing, clip, "content check: select '%s'" % clip)
		_player.seek(0.0, true)
		var before: Transform3D = skeleton.get_bone_pose(bone)
		var length: float = _player.get_animation(clip).length
		_player.advance(length * 0.5)
		var after: Transform3D = skeleton.get_bone_pose(bone)
		_check(not before.is_equal_approx(after),
			("content check: clip '%s' - mixamorig_Hips pose did not change after advancing "
			+ "%.4fs; an empty or wrong-content clip would pass every naming and loop guard "
			+ "but fail here") % [clip, length * 0.5])


## One tick of grace before asserting: a node added to the tree from _initialize() does NOT get
## _ready() called there (measured, 4-3c) -- readiness propagation waits for the first processed
## frame, and AnimationController resolves its exported AnimationPlayer path in _ready.
func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	var authored: BalanceConfig = load(AUTHORED_BALANCE)
	if authored == null or authored.walk_speed <= AnimationController.RUN_SPEED_EPS \
			or authored.move_speed <= authored.walk_speed:
		_failures.append("authored balance must carry RUN_SPEED_EPS < walk_speed < move_speed (got %s)"
			% ["no config" if authored == null
				else "%.3f / %.3f" % [authored.walk_speed, authored.move_speed]])
	else:
		_walk_speed = authored.walk_speed
		_run_speed = authored.move_speed
		_drive_walk_speed = _walk_speed
		_drive_run_speed = _run_speed
	_state = HeroState.new(SignalQueue.new(), 100.0, _run_speed)
	_player = _hero.animation_controller.animation_player
	if _player == null:
		_failures.append("hero.tscn did not yield a wired AnimationController")
	elif _failures.is_empty():
		_cardinals(Vector2(0.0, 1.0), "facing world +Z")
		# The SAME five cases under a facing turned a quarter turn. Every world velocity here
		# differs from its counterpart above; every expected clip is identical.
		_cardinals(Vector2(1.0, 0.0), "facing world +X")
		_the_motivating_defect()
		_idle_gating()
		_walk_cardinals()
		_tier_boundary()
		_clip_content_changes()

	if is_instance_valid(_hero):
		_hero.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
