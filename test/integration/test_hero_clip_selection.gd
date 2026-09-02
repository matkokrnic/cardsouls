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
## Run: godot --headless --path . --script res://test/integration/test_hero_clip_selection.gd

## One physics tick's worth of playback, so a check cannot pass on a clip that was selected and
## then immediately stalled -- the 4-3c `_expect` precedent (test_unit_clip_selection.gd L6).
const TICK := 1.0 / 60.0

## Comfortably above AnimationController.RUN_SPEED_EPS and equal to the authored hero
## move_speed, so these are the magnitudes the game actually produces.
const SPEED := 5.0

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
	_hero.drive(_state, TICK)
	_player.advance(TICK)
	var got: StringName = _player.current_animation
	_check(got == want, "%s: expected clip '%s', got '%s'" % [label, want, got])


## The four cardinals plus rest, expressed in the hero's OWN frame and then rotated into world
## space by the caller. `forward` is along facing; `right` is along (facing.y, -facing.x), the
## same local +X drive()'s yaw produces -- stated once here rather than re-derived per case.
func _cardinals(facing: Vector2, tag: String) -> void:
	var forward := Vector3(facing.x, 0.0, facing.y) * SPEED
	var right := Vector3(facing.y, 0.0, -facing.x) * SPEED
	_expect(Vector3.ZERO, facing, &"idle", "%s: standing still" % tag)
	_expect(forward, facing, &"run", "%s: moving along facing" % tag)
	_expect(-forward, facing, &"backpedal", "%s: moving opposite facing" % tag)
	_expect(right, facing, &"strafe_right", "%s: moving to the hero's right" % tag)
	_expect(-right, facing, &"strafe_left", "%s: moving to the hero's left" % tag)


## The ONE case that made this story exist, stated as its own assertion rather than left implicit
## in the table above: locked on and moving sideways, the pre-5-0a code played `run`.
func _the_motivating_defect() -> void:
	var facing := Vector2(0.0, 1.0)          # locked on to something straight ahead (world +Z)
	_expect(Vector3(SPEED, 0.0, 0.0), facing, &"strafe_right",
		"locked on, strafing right: the pre-5-0a code played 'run' here (the skating defect)")
	_expect(Vector3(0.0, 0.0, -SPEED), facing, &"backpedal",
		"locked on, backing away: the pre-5-0a code played 'run' here (the skating defect)")


## Action states OWN the body while they persist (3-0a): the polled push must not override them,
## however fast the hero is still travelling. Unchanged by 5-0a and asserted so the widened
## payload cannot have quietly loosened the gate.
func _idle_gating() -> void:
	var facing := Vector2(0.0, 1.0)
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.IDLE, HeroState.ActionState.ATTACKING)
	_expect(Vector3(SPEED, 0.0, 0.0), facing, &"attack",
		"ATTACKING while carrying sideways velocity keeps the attack clip")
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.ATTACKING, HeroState.ActionState.ROLLING)
	_expect(Vector3(0.0, 0.0, -SPEED), facing, &"roll",
		"ROLLING while carrying backward velocity keeps the roll clip")
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.ROLLING, HeroState.ActionState.IDLE)
	_expect(Vector3(0.0, 0.0, -SPEED), facing, &"backpedal",
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
	var right := Vector3(facing.y, 0.0, -facing.x) * SPEED
	var drives := {
		&"strafe_right": right,
		&"strafe_left": -right,
		&"backpedal": Vector3(facing.x, 0.0, facing.y) * -SPEED,
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

	_state = HeroState.new(SignalQueue.new(), 100.0, SPEED)
	_player = _hero.animation_controller.animation_player
	if _player == null:
		_failures.append("hero.tscn did not yield a wired AnimationController")
	else:
		_cardinals(Vector2(0.0, 1.0), "facing world +Z")
		# The SAME five cases under a facing turned a quarter turn. Every world velocity here
		# differs from its counterpart above; every expected clip is identical.
		_cardinals(Vector2(1.0, 0.0), "facing world +X")
		_the_motivating_defect()
		_idle_gating()
		_clip_content_changes()

	if is_instance_valid(_hero):
		_hero.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
