extends SceneTree

## Story 6-6a machine contract, on the test_hero_clip_selection.gd shape: the hero's DEFENSE REACTION
## clips are selected by AnimationController from the mirrored action state and the runner-forwarded
## values, and the two paths (evented transitions, polled locomotion) do not fight over them.
##
## WHAT IS PINNED, case by case:
##   * AC 2 -- `hit_react` plays ONLY on an IDLE hero; ATTACKING / ROLLING / CHARGING / STUNNED keep
##     their clip, and a hit on the OTHER slot changes nothing.
##   * AC 2 -- THE LOCOMOTION YIELD: `hit_react` and `get_up` survive the per-tick `drive()` push, even
##     with the hero moving, until they finish; then locomotion resumes.
##   * AC 12 -- a BLOCKED hit on a BLOCKING hero plays `block_impact`; an unblocked one (outside the arc,
##     6-6a review D2) plays nothing.
##   * AC 10/AC 11 -- STUNNED plays `stunned` for the ordinary flavor and `knockdown` for the knockdown,
##     HELD (the clip stops on its last frame and is not looping), at the Open Question 2 tempo rule.
##   * AC 8/AC 9 -- `get_up` on `STUNNED -> IDLE` only when the runner forwards `get_up_armed`; an
##     unarmed exit (the debug reset's) plays plain `idle`.
##   * AC 5/AC 7/AC 11 -- the ESCALATION: a forwarded knockdown on a hit switches an ordinary `stunned`
##     to `knockdown`; a second knockdown hit on a hero already showing `knockdown` does not restart it.
##   * AC 13 -- block ENTRY and `block -> attack` are instant cuts, block EXIT to IDLE blends. Measured on
##     the model's `mixamorig_Hips` height one tick after the transition, because the clip NAME is the
##     same either way: `block` holds the hips at 0.6915 and `idle` at 0.8056 (6-6a Hips table), so a
##     cut lands next to the new clip's height and a 0.25 s crossfade is still next to the old one's.
##
## Run: godot --headless --path . --script res://test/integration/test_hero_reaction_clips.gd

const TICK := 1.0 / 60.0
const RUN_SPEED := 6.0
const WALK_SPEED := 2.0
const FACING := Vector2(0.0, 1.0)

const IDLE := HeroState.ActionState.IDLE
const ATTACKING := HeroState.ActionState.ATTACKING
const BLOCKING := HeroState.ActionState.BLOCKING
const ROLLING := HeroState.ActionState.ROLLING
const STUNNED := HeroState.ActionState.STUNNED
const CHARGING := HeroState.ActionState.CHARGING

var _hero: HeroActor
var _anim: AnimationController
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


func _transition(previous: HeroState.ActionState, current: HeroState.ActionState,
		charge_color: int = PlayerState.NO_TELEGRAPH_COLOR,
		flavor: int = AnimationController.STUN_FLAVOR_NONE, seconds: float = 0.0,
		armed: bool = false) -> void:
	_anim.on_action_state_changed(previous, current, charge_color, flavor, seconds, armed)


func _hit(target_slot: int = 0, flavor: int = AnimationController.STUN_FLAVOR_NONE,
		seconds: float = 0.0, blocked: bool = false) -> void:
	_anim.on_hit_landed(1 - target_slot, target_slot, 5.0, 95.0, 0, flavor, seconds, blocked)


## One drive() tick with this velocity: the real locomotion push, then one tick of playback.
func _drive(velocity: Vector3) -> void:
	_state.velocity = velocity
	_state.facing = FACING
	_hero.drive(_state, TICK, WALK_SPEED, RUN_SPEED)
	_player.advance(TICK)


func _settle_idle() -> void:
	_transition(STUNNED, IDLE)
	for _t in 3:
		_drive(Vector3.ZERO)


## AC 2: hit_react on IDLE only, and only for this hero's own slot.
func _hit_react_scoping() -> void:
	_settle_idle()
	_hit(1)
	_check(_player.current_animation == &"idle",
		"a hit on the OTHER slot must not play hit_react here (got '%s')" % _player.current_animation)
	_hit(0)
	_check(_player.current_animation == &"hit_react",
		"a hit on an IDLE hero plays hit_react (got '%s')" % _player.current_animation)
	var holds := {
		ATTACKING: [&"attack", PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_NONE],
		ROLLING: [&"roll", PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_NONE],
		CHARGING: [&"swipe", Enums.CardColor.RED, AnimationController.STUN_FLAVOR_NONE],
		STUNNED: [&"stunned", PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_ORDINARY],
	}
	for state: HeroState.ActionState in holds:
		_settle_idle()
		var row: Array = holds[state]
		_transition(IDLE, state, row[1], row[2], 1.0)
		_hit(0, row[2], 1.0)
		_check(_player.assigned_animation == row[0],
			"a hit during state %d must not replace '%s' with hit_react (got '%s')"
			% [state, row[0], _player.assigned_animation])


## AC 12: a BLOCKED hit on a BLOCKING hero plays block_impact. 6-6a review D2: a hit the runner forwards
## as NOT blocked (full damage from outside the arc) plays nothing -- the block pose stays, and it is not
## `hit_react` either (a BLOCKING hero is not IDLE-family, AC 2).
func _block_impact() -> void:
	_settle_idle()
	_transition(IDLE, BLOCKING)
	_hit(0, AnimationController.STUN_FLAVOR_NONE, 0.0, false)
	_check(_player.current_animation == &"block",
		"an UNBLOCKED hit on a BLOCKING hero (outside the arc) keeps 'block' -- no block_impact, no hit_react (got '%s')"
		% _player.current_animation)
	_hit(0, AnimationController.STUN_FLAVOR_NONE, 0.0, true)
	_check(_player.current_animation == &"block_impact",
		"a BLOCKED hit on a BLOCKING hero plays block_impact (got '%s')" % _player.current_animation)


## AC 2: the one-shots survive the per-tick push while they play, then locomotion takes over again.
func _locomotion_yield() -> void:
	var moving := Vector3(FACING.x, 0.0, FACING.y) * RUN_SPEED
	for case: String in ["hit_react", "get_up"]:
		_settle_idle()
		if case == "hit_react":
			_hit(0)
		else:
			_transition(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR,
				AnimationController.STUN_FLAVOR_KNOCKDOWN, 2.5)
			_transition(STUNNED, IDLE, PlayerState.NO_TELEGRAPH_COLOR,
				AnimationController.STUN_FLAVOR_NONE, 0.0, true)
		for _t in 10:
			_drive(moving)
		_check(_player.current_animation == StringName(case),
			"'%s' must not be stolen by the locomotion push mid-play (got '%s')"
			% [case, _player.current_animation])
		var length := _player.get_animation(StringName(case)).length
		_player.advance(length)
		_drive(moving)
		_check(_player.current_animation == &"run",
			"once '%s' has finished, locomotion resumes (got '%s')" % [case, _player.current_animation])


## AC 8/AC 9: get_up only on an ARMED STUNNED -> IDLE; the unarmed (reset) exit is plain idle.
func _get_up_gate() -> void:
	_settle_idle()
	_transition(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_KNOCKDOWN, 2.5)
	_transition(STUNNED, IDLE)
	_check(_player.current_animation == &"idle",
		"an UNARMED exit from a knockdown (the debug reset) plays idle, not get_up (got '%s')"
		% _player.current_animation)
	_transition(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_KNOCKDOWN, 2.5)
	_transition(STUNNED, IDLE, PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_NONE, 0.0, true)
	_check(_player.current_animation == &"get_up",
		"an ARMED exit (the knockdown's timer exit) plays get_up (got '%s')" % _player.current_animation)


## AC 10/AC 11 + Open Question 2: the three flavors' poses, their tempo, and the HOLD.
func _stun_poses() -> void:
	var rows := [
		[AnimationController.STUN_FLAVOR_ORDINARY, 1.0, &"stunned"],
		[AnimationController.STUN_FLAVOR_ORDINARY, 0.4, &"stunned"],
		[AnimationController.STUN_FLAVOR_KNOCKDOWN, 2.5, &"knockdown"],
	]
	for row: Array in rows:
		_settle_idle()
		_transition(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR, row[0], row[1])
		var clip: StringName = row[2]
		_check(_player.current_animation == clip,
			"flavor %d over %.2fs plays '%s' (got '%s')" % [row[0], row[1], clip, _player.current_animation])
		var length := _player.get_animation(clip).length
		var want_speed := AnimationController.held_clip_speed(length, row[1])
		_check(absf(_player.get_playing_speed() - want_speed) < 0.001,
			"'%s' over %.2fs plays at %.3f (got %.3f)" % [clip, row[1], want_speed, _player.get_playing_speed()])
		_check(_player.get_animation(clip).loop_mode == Animation.LOOP_NONE, "'%s' is not a loop" % clip)
		_player.advance(float(row[1]) + 0.2)
		_check(not _player.is_playing() and _player.assigned_animation == clip,
			"after the whole stun '%s' is HELD on its final frame, not restarted (playing=%s, assigned='%s')"
			% [clip, _player.is_playing(), _player.assigned_animation])
	_check(is_equal_approx(AnimationController.held_clip_speed(0.7, 0.4), 0.7 / 0.4),
		"a clip longer than its stun is sped up to finish on the exit tick")
	_check(is_equal_approx(AnimationController.held_clip_speed(0.7, 1.0), 1.0),
		"a clip shorter than its stun plays native and holds -- never slowed")
	# STORY 6-5c (AC 27, `6-5c/R10`/`R16`, Open Question 8): THE THIRD FLAVOR. EXTENDED, NOT
	# WEAKENED -- the two ORDINARY rows above are untouched, including the 0.4 s one whose duration
	# the bolt stun COLLIDES with. That collision is the whole reason the flavor exists: both stuns
	# are authored 0.4 s, so `is_knockdown_stun` classifies both ORDINARY and no timing test could
	# tell them apart. The discriminator is `HeroState.stun_is_bolt`, and this is its consumer.
	#
	# IT IS ASSERTED SEPARATELY FROM THE ROW LOOP, deliberately, because it deliberately does NOT
	# follow `held_clip_speed`: `dizzy` is 4.2667 s against a 0.4 s stun, and the hold rule would run
	# it at 10.67x. Open Question 8 named cutting as the alternative and the dev pass took it, so
	# this plays a SUB-RANGE at NATIVE rate. Asserting it through the row loop would have asserted
	# the wrong rule.
	_settle_idle()
	_transition(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_BOLT, 0.4)
	_check(_player.current_animation == &"dizzy",
		"the BOLT flavor plays 'dizzy', not 'stunned' (got '%s')" % _player.current_animation)
	_check(absf(_player.get_playing_speed() - 1.0) < 0.001,
		"...at NATIVE rate, never the 10.67x the hold rule would give (got %.3f)"
		% _player.get_playing_speed())
	_check(_player.get_animation(&"dizzy").loop_mode == Animation.LOOP_NONE,
		"...and 'dizzy' is a one-shot, so the pose can be held rather than restarting mid-stun")
	_check(absf(_player.current_animation_position - AnimationController.DIZZY_CUT_START) < 0.05,
		"...seeked to the measured cut start %.2f (got %.3f)"
		% [AnimationController.DIZZY_CUT_START, _player.current_animation_position])
	# ...and the deflect stun's own pose is BIT-IDENTICAL, which is the story's Non-Goal made
	# machine-checkable: changing `stunned` or `hit_react` is out of scope.
	_settle_idle()
	_transition(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_ORDINARY, 0.4)
	_check(_player.current_animation == &"stunned",
		"a 0.4s ORDINARY stun still plays 'stunned' -- the bolt flavor took its own pose and left "
		+ "this one untouched (got '%s')" % _player.current_animation)


## AC 5/AC 7/AC 11: the escalation switches the pose; a second knockdown hit never restarts it.
func _escalation_and_floor() -> void:
	_settle_idle()
	_transition(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_ORDINARY, 1.0)
	_hit(0, AnimationController.STUN_FLAVOR_ORDINARY, 1.0)
	_check(_player.assigned_animation == &"stunned", "an ordinary-flavor hit leaves 'stunned' in place")
	_hit(0, AnimationController.STUN_FLAVOR_KNOCKDOWN, 2.5)
	_check(_player.current_animation == &"knockdown",
		"the ESCALATION is visible: a knockdown-flavor hit on a stunned hero switches to knockdown (got '%s')"
		% _player.current_animation)
	_player.advance(0.5)
	var position := _player.current_animation_position
	_hit(0, AnimationController.STUN_FLAVOR_KNOCKDOWN, 2.5)
	_check(_player.current_animation == &"knockdown" and is_equal_approx(_player.current_animation_position, position),
		"the FLOOR: a second knockdown hit does not restart the hold (position %.3f -> %.3f)"
		% [position, _player.current_animation_position])


func _hips_y(skeleton: Skeleton3D, bone: int) -> float:
	return skeleton.get_bone_pose_position(bone).y


## AC 13: entry cut, block -> attack cut, exit blend -- measured on the Hips height.
func _block_transitions() -> void:
	var skeleton := _hero.skeleton
	var bone := skeleton.find_bone("mixamorig_Hips")
	if bone < 0:
		_failures.append("block transitions: mixamorig_Hips bone missing")
		return
	var block_y := _first_hips_y(&"block")
	var idle_y := _first_hips_y(&"idle")
	var attack_y := _first_hips_y(&"attack")
	_check(absf(block_y - idle_y) > 0.05, "fixture: block and idle hips heights are distinguishable")
	_settle_idle()
	_player.advance(0.5)
	_transition(IDLE, BLOCKING)
	_player.advance(TICK)
	_check(absf(_hips_y(skeleton, bone) - block_y) < 0.02,
		"block ENTRY is an instant cut: one tick in, the hips are at block height (%.4f vs %.4f)"
		% [_hips_y(skeleton, bone), block_y])
	_player.advance(0.5)
	_transition(BLOCKING, IDLE)
	_player.advance(TICK)
	var y := _hips_y(skeleton, bone)
	_check(absf(y - block_y) < absf(y - idle_y),
		"block EXIT blends: one tick in, the hips are still nearer block height (%.4f; block %.4f, idle %.4f)"
		% [y, block_y, idle_y])
	_check(_player.current_animation == &"idle", "...into idle")
	_player.advance(0.5)
	_transition(IDLE, BLOCKING)
	_player.advance(0.5)
	_transition(BLOCKING, ATTACKING)
	_player.advance(TICK)
	_check(absf(_hips_y(skeleton, bone) - attack_y) < absf(_hips_y(skeleton, bone) - block_y),
		"block -> attack stays an instant cut: one tick in, the hips are at attack height (%.4f; attack %.4f, block %.4f)"
		% [_hips_y(skeleton, bone), attack_y, block_y])
	# 6-6a review: `block -> roll` is the other half of `3-0b/R24`'s "must stay instant" pair, and each
	# nearer-than comparison needs its own distinguishability guard, as block/idle has above.
	var roll_y := _first_hips_y(&"roll")
	_check(absf(block_y - attack_y) > 0.05, "fixture: block and attack hips heights are distinguishable")
	_check(absf(block_y - roll_y) > 0.05, "fixture: block and roll hips heights are distinguishable")
	_settle_idle()
	_transition(IDLE, BLOCKING)
	_player.advance(0.5)
	_transition(BLOCKING, ROLLING)
	_player.advance(TICK)
	_check(absf(_hips_y(skeleton, bone) - roll_y) < absf(_hips_y(skeleton, bone) - block_y),
		"block -> roll stays an instant cut: one tick in, the hips are at roll height (%.4f; roll %.4f, block %.4f)"
		% [_hips_y(skeleton, bone), roll_y, block_y])


func _first_hips_y(clip: StringName) -> float:
	var anim := _player.get_animation(clip)
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D \
				and String(anim.track_get_path(t)).ends_with("mixamorig_Hips"):
			return (anim.track_get_key_value(t, 0) as Vector3).y
	_failures.append("clip '%s' has no Hips position track" % clip)
	return 0.0


## One tick of grace: AnimationController resolves its AnimationPlayer in _ready, which a node added
## from _initialize() only gets on the first processed frame (4-3c measurement).
func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	_anim = _hero.animation_controller
	_player = _anim.animation_player if _anim != null else null
	_state = HeroState.new(SignalQueue.new(), 100.0, RUN_SPEED)
	if _player == null:
		_failures.append("hero.tscn did not yield a wired AnimationController")
	else:
		_hit_react_scoping()
		_block_impact()
		_locomotion_yield()
		_get_up_gate()
		_stun_poses()
		_escalation_and_floor()
		_block_transitions()
	if is_instance_valid(_hero):
		_hero.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
