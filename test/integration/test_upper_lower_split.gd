extends SceneTree

## Story 7-2 machine contract, on the test_hero_reaction_clips.gd shape: THE UPPER/LOWER SPLIT and the other rig
## edges this story adds, driven through the real hero scene's AnimationController.
##
## WHAT IS PINNED, case by case:
##   * the PARTITION -- the `LegLayer` drives `mixamorig_Hips` and both UpLeg chains and nothing under the Spine.
##   * AC 1 -- a hero walking into BLOCK keeps the block on the body and the walk on the legs, at the stride's own
##     phase; a standing block is whole body; releasing the block while walking hands the walk back at that phase.
##   * AC 2 -- `block_impact` on a walking blocker keeps the legs walking.
##   * AC 3 -- `hit_react` while running: legs on the run clip at its phase, then the run handed back when it ends;
##     standing: whole body.
##   * AC 4/AC 8 -- a gesture plays while MOVING (upper body) and is not cut by movement; standing it is whole body;
##     during a whole-body action (a roll, a cast) it is DROPPED.
##   * AC 6 -- a struck spell's follow-through keeps the upper body while the hero walks off.
##   * AC 7/AC 8 -- entering any whole-body state from a split leaves NO layer on the same call.
##   * AC 5 (amended) / AC 6 -- a struck Rocksling follows through from the release at native rate, upper body while
##     the hero walks off.
##   * AC 1 (amended, live smoke F1) -- FACING: under block, for walk, walk_backpedal, walk_strafe_left,
##     walk_strafe_right and a walk -> strafe direction change, the chest's forward yaw relative to the root matches
##     the block clip standing still (read off the clip's own tracks), within `FACING_TOLERANCE_DEG`.
##   * AC 10 -- P19: the lift -> throw junction is a cross-fade, not a cut.
##   * AC 11 -- the stun ENTRY and the ordinary stun EXIT blend.
##   * the hitstop freezes the legs' layer with the body.
##   * RENDERED: inside `skeleton_updated` (the one point a modifier's output is visible -- measured, it is restored
##     after the frame), the legs carry the walk clip and the spine the block clip.
##
## Run: godot --headless --path . --script res://test/integration/test_upper_lower_split.gd

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
const DEAD := HeroState.ActionState.DEAD

const LOWER := ["mixamorig_Hips", "mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", "mixamorig_LeftFoot",
		"mixamorig_RightToeBase"]
const UPPER := ["mixamorig_Spine", "mixamorig_Spine2", "mixamorig_Head", "mixamorig_LeftHand", "mixamorig_RightArm"]
## AC 11's probe candidates -- the stun-edge evidence is read on whichever of these moves most between the two clips.
const STUN_PROBE_BONES := ["mixamorig_Spine2", "mixamorig_Head", "mixamorig_LeftArm", "mixamorig_RightArm",
		"mixamorig_LeftForeArm", "mixamorig_RightForeArm", "mixamorig_Spine"]

var _hero: HeroActor
var _anim: AnimationController
var _player: AnimationPlayer
var _legs: LegLayer
var _skeleton: Skeleton3D
var _state: HeroState
var _frames := 0
var _failures: Array[String] = []

var _render_phase := 0
var _render_samples := 0
var _freeze_playhead := -1.0


func _initialize() -> void:
	_hero = load("res://src/actors/hero/hero.tscn").instantiate() as HeroActor
	root.add_child(_hero)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _transition(previous: HeroState.ActionState, current: HeroState.ActionState,
		charge_color: int = PlayerState.NO_TELEGRAPH_COLOR,
		flavor: int = AnimationController.STUN_FLAVOR_NONE, seconds: float = 0.0) -> void:
	_anim.on_action_state_changed(previous, current, charge_color, flavor, seconds, false)


func _hit(blocked: bool = false) -> void:
	_anim.on_hit_landed(1, 0, 5.0, 95.0, 0, AnimationController.STUN_FLAVOR_NONE, 0.0, blocked)


## One drive() tick with this velocity: the real locomotion push, then one tick of playback.
func _drive(velocity: Vector3) -> void:
	_state.velocity = velocity
	_state.facing = FACING
	_hero.drive(_state, TICK, WALK_SPEED, RUN_SPEED)
	_player.advance(TICK)


func _walk() -> Vector3:
	return Vector3(FACING.x, 0.0, FACING.y) * WALK_SPEED


func _run() -> Vector3:
	return Vector3(FACING.x, 0.0, FACING.y) * RUN_SPEED


## Through a whole-body state first, so every case starts with the legs' layer off (its weight only ramps in
## rendered frames, which the synchronous cases do not run).
func _settle_idle() -> void:
	_transition(IDLE, ROLLING)
	_transition(ROLLING, IDLE)
	_anim.on_cast_ended(false)
	for _t in 3:
		_drive(Vector3.ZERO)


## `snapped`: the split started on an EVENT, so the weight is already full on the same call (no ramp to wait for).
func _split_on(tag: String, clip: StringName, snapped: bool = false) -> void:
	_check(_legs.target_weight() >= 1.0 and (not snapped or _legs.influence >= 1.0),
		"%s: the legs are on the layer (target %.2f, influence %.2f)" % [tag, _legs.target_weight(), _legs.influence])
	_check(_legs.clip_name() == clip, "%s: the legs play '%s' (got '%s')" % [tag, clip, _legs.clip_name()])


func _whole_body(tag: String) -> void:
	_check(_legs.target_weight() <= 0.0, "%s: the legs are NOT on the layer (target %.2f)" % [tag,
			_legs.target_weight()])


## The partition: Hips + both UpLeg chains, nothing under the Spine.
func _partition() -> void:
	for bone_name: String in LOWER:
		var bone := _skeleton.find_bone(bone_name)
		_check(bone >= 0 and _legs.is_lower_bone(bone), "partition: %s is on the legs' layer" % bone_name)
	for bone_name: String in UPPER:
		var bone := _skeleton.find_bone(bone_name)
		_check(bone >= 0 and not _legs.is_lower_bone(bone), "partition: %s is NOT on the legs' layer" % bone_name)


## AC 1: block-walk, the standing block, and the release while walking.
func _block_walk() -> void:
	_settle_idle()
	for _t in 10:
		_drive(_walk())
	_check(_player.current_animation == &"walk", "fixture: a walking hero plays 'walk' (got '%s')"
			% _player.current_animation)
	var phase := _player.current_animation_position
	_transition(IDLE, BLOCKING)
	_check(_player.current_animation == &"block", "AC 1: block ENTRY is still the instant cut to 'block'")
	_split_on("AC 1 block entry while walking", &"walk", true)
	_check(absf(_legs.playhead() - phase) < 0.001,
		"AC 1: the legs keep the stride's phase through the cut (%.4f vs %.4f)" % [_legs.playhead(), phase])
	for _t in 5:
		_drive(_walk())
	_check(_player.current_animation == &"block", "AC 1: the body keeps 'block' while walking (got '%s')"
			% _player.current_animation)
	_split_on("AC 1 block-walk", &"walk")
	_drive(Vector3.ZERO)
	_whole_body("AC 1 blocker stops")
	_drive(_walk())
	_split_on("AC 1 blocker walks again", &"walk")
	var legs_at := _legs.playhead()
	_transition(BLOCKING, IDLE)
	_check(_player.current_animation == &"walk" and absf(_player.current_animation_position - legs_at) < 0.001,
		"AC 1/AC 8: a block released while walking hands 'walk' back at the legs' phase (got '%s' @ %.4f vs %.4f)"
			% [_player.current_animation, _player.current_animation_position, legs_at])
	_whole_body("AC 8 after the block-walk ends")
	_settle_idle()
	_transition(IDLE, BLOCKING)
	_check(_player.current_animation == &"block", "AC 1: a standing block plays 'block'")
	_whole_body("AC 1 standing block")
	_check(_legs.influence <= 0.0, "AC 1: a standing block has no layer weight (%.2f)" % _legs.influence)


## AC 2: a blocked hit on a walking blocker; and a `block_impact` taken STANDING that the hero then walks out of --
## the legs come onto the layer under the impact itself, not only under the block pose.
func _block_impact_walk() -> void:
	_settle_idle()
	_drive(_walk())
	_transition(IDLE, BLOCKING)
	_drive(_walk())
	_hit(true)
	_check(_player.current_animation == &"block_impact", "AC 2: a walking blocker plays block_impact (got '%s')"
			% _player.current_animation)
	_drive(_walk())
	_split_on("AC 2 block_impact while walking", &"walk")
	_settle_idle()
	_transition(IDLE, BLOCKING)
	_hit(true)
	_whole_body("AC 2 block_impact standing")
	_drive(_walk())
	_check(_player.current_animation == &"block_impact", "AC 2: the impact keeps the upper body as the hero walks")
	_split_on("AC 2 walking off under block_impact", &"walk")


## AC 3: hit_react while running and standing.
func _hit_react_run() -> void:
	_settle_idle()
	for _t in 10:
		_drive(_run())
	_check(_player.current_animation == &"run", "fixture: a running hero plays 'run'")
	var phase := _player.current_animation_position
	_hit()
	_check(_player.current_animation == &"hit_react", "AC 3: a running hero plays hit_react on the body")
	_split_on("AC 3 hit_react while running", &"run", true)
	_check(absf(_legs.playhead() - phase) < 0.001, "AC 3: the legs keep the run's phase (%.4f vs %.4f)"
			% [_legs.playhead(), phase])
	for _t in 10:
		_drive(_run())
	_check(_player.current_animation == &"hit_react", "AC 3: hit_react keeps the body while running")
	_split_on("AC 3 hit_react mid-play", &"run")
	_player.advance(_player.get_animation(&"hit_react").length)
	var legs_at := _legs.playhead()
	_drive(_run())
	_check(_player.current_animation == &"run", "AC 3/AC 8: once hit_react ends the run resumes (got '%s')"
			% _player.current_animation)
	_check(absf(_player.current_animation_position - legs_at) < 0.05,
		"AC 8: ...at the legs' phase, not from frame 0 (%.4f vs %.4f)" % [_player.current_animation_position, legs_at])
	_whole_body("AC 8 after hit_react ends")
	_settle_idle()
	_hit()
	_check(_player.current_animation == &"hit_react", "AC 3: a standing hero plays hit_react")
	_whole_body("AC 3 standing hit_react")


## AC 4/AC 8: gestures moving, standing, and dropped during a whole-body action.
func _gestures() -> void:
	_settle_idle()
	_drive(_run())
	_check(_anim.play_gesture(&"cast_buff"), "AC 4: a MOVING hero plays the buff gesture")
	_check(_player.current_animation == &"cast_buff", "AC 4: ...on the body as cast_buff")
	_split_on("AC 4 gesture while running", &"run", true)
	for _t in 5:
		_drive(_run())
	_check(_player.current_animation == &"cast_buff", "AC 4: movement no longer cuts the gesture (got '%s')"
			% _player.current_animation)
	_settle_idle()
	_drive(_walk())
	_check(_anim.play_gesture(&"cast_counterspell"), "AC 4: a walking hero plays the Counterspell swing")
	_split_on("AC 4 counterspell while walking", &"walk")
	_settle_idle()
	_check(_anim.play_gesture(&"cast_buff"), "AC 4: a standing hero plays the gesture")
	_whole_body("AC 4 standing gesture")
	_settle_idle()
	_transition(IDLE, ROLLING)
	_check(not _anim.play_gesture(&"cast_buff"), "AC 8: a gesture resolving during a ROLL is dropped")
	_check(_player.current_animation == &"roll", "AC 8: ...and the roll keeps the whole body")
	_settle_idle()
	_anim.on_cast_started(0.8, CardEffectResolver.OUTCOME_HONED_BOLT)
	_check(not _anim.play_gesture(&"cast_buff"), "AC 8: a gesture resolving during a CAST is dropped")
	_anim.on_cast_ended(false)


## Review fix F1 (AC 7/AC 8): the knockdown get-up plays in IDLE but is WHOLE BODY. A gesture resolving mid-get-up is
## DROPPED -- it does not replace `get_up` -- and a moving hero gets no split.
func _get_up_gesture() -> void:
	_settle_idle()
	_drive(_run())
	_anim.on_action_state_changed(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_KNOCKDOWN,
			2.5, false)
	_anim.on_action_state_changed(STUNNED, IDLE, PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_NONE,
			0.0, true)
	_check(_player.current_animation == &"get_up", "F1 fixture: the get-up is playing (got '%s')" % _player.current_animation)
	for _t in 3:
		_drive(_run())
	_check(not _anim.play_gesture(&"cast_buff"), "F1: a gesture resolving during the get-up is dropped")
	_check(not _anim.play_gesture(&"cast_counterspell"), "F1: ...and so is the Counterspell swing")
	_check(_player.current_animation == &"get_up", "F1: the get-up keeps the body (got '%s')" % _player.current_animation)
	_whole_body("F1 get-up with a moving hero")
	_check(_legs.influence <= 0.0, "F1: no layer weight under the get-up (%.2f)" % _legs.influence)


## Review fix F4: a chest whose forward axis is near vertical has no stable yaw, so the compensation keeps the action's own Spine.
func _steep_facing() -> void:
	var legs_hips := Quaternion(Vector3.UP, deg_to_rad(45.0))
	var steep := Quaternion(Vector3.RIGHT, deg_to_rad(80.0))
	_check(LegLayer.upper_facing_spine(Quaternion.IDENTITY, steep, legs_hips).is_equal_approx(steep),
		"F4: a steep chest (80 deg pitch) keeps the action's own Spine")
	var gentle := Quaternion(Vector3.RIGHT, deg_to_rad(20.0))
	_check(not LegLayer.upper_facing_spine(Quaternion.IDENTITY, gentle, legs_hips).is_equal_approx(gentle),
		"F4: a gentle chest (20 deg pitch) is still compensated (non-vacuous)")


## Review fix F2: THE LAYER NEVER REACHES THE CONTACT FACTS. Called from the physics tick with the split on and at
## least one rendered frame behind it: the poses `HeroActor.drive()` reads for the sword and trunk followers (the same
## forward kinematics, `_bone_pose_global`) -- and Hips/Spine -- equal the AnimationPlayer's own pose, i.e. what they
## would be with the layer at influence 0. A modifier's output must be gone by the time the physics tick runs.
func _contact_poses_untouched() -> void:
	_check(_legs.influence >= 1.0 and _legs.clip_name() == &"walk", "F2 fixture: the split is on (influence %.2f, '%s')"
			% [_legs.influence, _legs.clip_name()])
	var clip := _player.get_animation(_player.current_animation)
	var at := _player.current_animation_position
	var names := {}
	for bone: int in [_hero._sword_bone, _hero._trunk_bone, _skeleton.find_bone("mixamorig_Hips"),
			_skeleton.find_bone("mixamorig_Spine")]:
		_check(bone >= 0, "F2: a contact bone resolved")
		var actual: Transform3D = _hero._bone_pose_global(bone)
		var want := Transform3D.IDENTITY
		var chain: Array[int] = []
		var b := bone
		while b >= 0:
			chain.push_front(b)
			b = _skeleton.get_bone_parent(b)
		for link in chain:
			want = want * _action_pose(clip, link, at)
		var name := _skeleton.get_bone_name(bone)
		var off := actual.origin.distance_to(want.origin)
		var turn := _angle(actual.basis.get_rotation_quaternion(), want.basis.get_rotation_quaternion())
		names[name] = true
		_check(off < 0.001 and turn < 0.01, "F2: %s as drive() reads it is the player's own pose, not the layer's (%.4f m, %.4f rad)"
				% [name, off, turn])
	_check(names.size() == 4, "F2: four distinct contact bones were checked (vacuous)")


## The AnimationPlayer's own local pose of `bone` in `clip` at `at` (rest where the clip does not key it).
func _action_pose(clip: Animation, bone: int, at: float) -> Transform3D:
	var path := NodePath("Skeleton3D:" + _skeleton.get_bone_name(bone))
	var rest := _skeleton.get_bone_rest(bone)
	var pos := rest.origin
	var rot := rest.basis.get_rotation_quaternion()
	var scl := rest.basis.get_scale()
	var t := clip.find_track(path, Animation.TYPE_POSITION_3D)
	if t >= 0:
		pos = clip.position_track_interpolate(t, at)
	t = clip.find_track(path, Animation.TYPE_ROTATION_3D)
	if t >= 0:
		rot = clip.rotation_track_interpolate(t, at)
	t = clip.find_track(path, Animation.TYPE_SCALE_3D)
	if t >= 0:
		scl = clip.scale_track_interpolate(t, at)
	return Transform3D(Basis(rot).scaled(scl), pos)



## AC 7/AC 8: every whole-body state, entered from a live split, leaves no layer on the same call.
func _whole_body_wins() -> void:
	var rows := {
		ROLLING: [PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_NONE],
		ATTACKING: [PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_NONE],
		CHARGING: [Enums.CardColor.RED, AnimationController.STUN_FLAVOR_NONE],
		STUNNED: [PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_KNOCKDOWN],
		DEAD: [PlayerState.NO_TELEGRAPH_COLOR, AnimationController.STUN_FLAVOR_NONE],
	}
	for state: HeroState.ActionState in rows:
		_settle_idle()
		_drive(_run())
		_hit()
		_split_on("AC 8 fixture before state %d" % state, &"run", true)
		var row: Array = rows[state]
		_transition(IDLE, state, row[0], row[1], 2.5)
		_whole_body("AC 8 state %d entered mid-flinch" % state)
		_check(_legs.influence <= 0.0, "AC 8: state %d leaves NO layer weight on the next frame (%.2f)"
				% [state, _legs.influence])


## AC 6: the follow-through keeps the upper body while the hero walks off.
func _follow_through() -> void:
	_settle_idle()
	_anim.on_cast_started(0.8, CardEffectResolver.OUTCOME_FIREBALL)
	_anim.on_cast_progress(0.8)
	_anim.on_cast_ended(true)
	for _t in 3:
		_drive(_run())
	_check(_player.current_animation == &"cast_fireball", "AC 6: the follow-through keeps playing as the hero walks off")
	_split_on("AC 6 follow-through while running", &"run")


## AC 5 (amended) / AC 6: a struck Rocksling's throw follows through from the release at native rate, and keeps the
## upper body while the hero walks off. Stones 2 and 3 have no swing (the live pin is test_animation_polish_live.gd).
func _rocksling_follow_through() -> void:
	_settle_idle()
	_anim.on_cast_started(0.8, CardEffectResolver.OUTCOME_ROCKSLING)
	_anim.on_cast_progress(0.8)
	_anim.on_cast_ended(true)
	var release := AnimationController.ROCKSLING_THROW_RELEASE_SECONDS
	_check(_player.current_animation == &"cast_rocksling_throw" and _player.get_playing_speed() > 0.5
			and absf(_player.current_animation_position - release) < 0.001,
		"AC 5/AC 6: the strike starts the throw's follow-through at the release, at native rate (%.4f)"
			% _player.current_animation_position)
	for _t in 3:
		_drive(_run())
	_check(_player.current_animation == &"cast_rocksling_throw", "AC 6: the throw keeps playing as the hero walks off")
	_split_on("AC 6 Rocksling follow-through while running", &"run")


func _track_rotation(clip: StringName, bone_name: String, at: float) -> Quaternion:
	var anim := _player.get_animation(clip)
	var track := anim.find_track(NodePath("Skeleton3D:" + bone_name), Animation.TYPE_ROTATION_3D)
	return anim.rotation_track_interpolate(track, at) if track >= 0 else Quaternion.IDENTITY


func _bone_rotation(bone_name: String) -> Quaternion:
	return _skeleton.get_bone_pose_rotation(_skeleton.find_bone(bone_name))


func _angle(a: Quaternion, b: Quaternion) -> float:
	return 2.0 * acos(clampf(absf(a.dot(b)), 0.0, 1.0))


## AC 10, P19: one tick after the junction the arm is still between the lift and the throw.
func _junction() -> void:
	_settle_idle()
	_anim.on_cast_started(0.8, CardEffectResolver.OUTCOME_ROCKSLING)
	var switched := false
	var bone := "mixamorig_RightArm"
	for i in 49:
		var elapsed := float(i) / 60.0
		var before := _player.current_animation
		_anim.on_cast_progress(elapsed)
		_player.advance(TICK)
		if before == &"cast_rocksling_lift" and _player.current_animation == &"cast_rocksling_throw" and not switched:
			switched = true
			var pure := _track_rotation(&"cast_rocksling_throw", bone, _player.current_animation_position)
			_check(_angle(_bone_rotation(bone), pure) > 0.05,
				"AC 10: one tick after the junction the arm is BLENDING, not cut onto the throw (%.4f rad off)"
					% _angle(_bone_rotation(bone), pure))
	_check(switched, "fixture: the cast crossed the lift -> throw junction")
	var pure_end := _track_rotation(&"cast_rocksling_throw", bone, _player.current_animation_position)
	_check(_angle(_bone_rotation(bone), pure_end) < 0.01, "AC 10: the junction blend has finished well before the release")
	_anim.on_cast_progress(0.8)
	_check(absf(_player.current_animation_position - AnimationController.ROCKSLING_THROW_RELEASE_SECONDS) < 0.001,
		"AC 10: the release frame still lands on the strike")
	_anim.on_cast_ended(false)


## AC 11: the stun entry and the ordinary exit blend (one tick in, the pose is not yet the new clip's).
func _stun_edges() -> void:
	var bone := "mixamorig_Spine2"
	for flavor: int in [AnimationController.STUN_FLAVOR_ORDINARY, AnimationController.STUN_FLAVOR_KNOCKDOWN,
			AnimationController.STUN_FLAVOR_BOLT]:
		_settle_idle()
		_player.advance(0.6)
		var idle_poses := {}
		for candidate: String in STUN_PROBE_BONES:
			idle_poses[candidate] = _bone_rotation(candidate)
		_transition(IDLE, STUNNED, PlayerState.NO_TELEGRAPH_COLOR, flavor, 1.0)
		var clip := _player.current_animation
		_player.advance(TICK)
		# The probe bone is the one whose pose differs MOST between idle and this clip, so the evidence is never a
		# rounding argument (the bolt's `dizzy` keeps the chest near idle).
		var widest := -1.0
		for candidate: String in STUN_PROBE_BONES:
			var gap := _angle(idle_poses[candidate],
					_track_rotation(clip, candidate, _player.current_animation_position))
			if gap > widest:
				widest = gap
				bone = candidate
		var idle_pose: Quaternion = idle_poses[bone]
		var pure := _track_rotation(clip, bone, _player.current_animation_position)
		_check(_angle(idle_pose, pure) > 0.05, "fixture: flavor %d's pose is distinguishable from idle (%s)"
				% [flavor, bone])
		_check(_angle(_bone_rotation(bone), pure) > 0.01,
			"AC 11: entering '%s' BLENDS -- one tick in the pose is not yet the clip's (%.4f rad off)"
				% [clip, _angle(_bone_rotation(bone), pure)])
		_player.advance(AnimationController.STUN_ENTRY_BLEND_SECONDS)
		pure = _track_rotation(clip, bone, _player.current_animation_position)
		_check(_angle(_bone_rotation(bone), pure) < 0.01, "AC 11: ...and the entry blend is short (done in %.2f s)"
				% AnimationController.STUN_ENTRY_BLEND_SECONDS)
	_player.advance(0.3)
	var stun_pose := _bone_rotation(bone)
	_transition(STUNNED, IDLE)
	_player.advance(TICK)
	var pure_idle := _track_rotation(&"idle", bone, _player.current_animation_position)
	_check(_angle(stun_pose, pure_idle) > 0.05, "fixture: the stun pose is distinguishable from idle")
	_check(_angle(_bone_rotation(bone), pure_idle) > 0.01,
		"AC 11: leaving a stun for idle BLENDS (%.4f rad off idle one tick in)" % _angle(_bone_rotation(bone), pure_idle))


## One tick of grace (AnimationController resolves its player in _ready), then the synchronous cases, then the
## frame-driven ones: the rendered pose and the hitstop.
func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	if _frames == 2:
		_anim = _hero.animation_controller
		_player = _anim.animation_player if _anim != null else null
		_legs = _anim.leg_layer() if _anim != null else null
		_skeleton = _hero.skeleton
		_state = HeroState.new(SignalQueue.new(), 100.0, RUN_SPEED)
		if _player == null or _legs == null:
			_failures.append("hero.tscn did not yield a wired AnimationController with a LegLayer")
			return _finish()
		_partition()
		_block_walk()
		_block_impact_walk()
		_hit_react_run()
		_gestures()
		_get_up_gesture()
		_steep_facing()
		_whole_body_wins()
		_follow_through()
		_rocksling_follow_through()
		_junction()
		_stun_edges()
		# The rendered case: a hero blocking while walking, left to the engine's own frames.
		_settle_idle()
		_drive(_walk())
		_transition(IDLE, BLOCKING)
		_drive(_walk())
		_skeleton.skeleton_updated.connect(_on_skeleton_updated)
		_render_phase = 1
		return false
	if _render_phase == 1 and _frames >= 10:
		_check(_render_samples > 0, "RENDERED: skeleton_updated never fired with the split on (vacuous)")
		_contact_poses_untouched()
		_render_phase = 2
		_anim.set_frozen(true)
		_freeze_playhead = _legs.playhead()
		return false
	if _render_phase == 2 and _frames >= 16:
		_check(_legs.frozen and is_equal_approx(_legs.playhead(), _freeze_playhead),
			"HITSTOP: the legs' layer is frozen with the body (%.4f -> %.4f)" % [_freeze_playhead, _legs.playhead()])
		_anim.set_frozen(false)
		_render_phase = 3
		return false
	if _render_phase == 3 and _frames >= 22:
		_check(not _legs.frozen and _legs.playhead() != _freeze_playhead, "HITSTOP: ...and thaws with it")
		_render_phase = 4
		_facing_case = 0
		_start_facing_case()
		return false
	if _render_phase == 4:
		var row: Array = FACING_CASES[_facing_case]
		var since := _frames - _facing_frame
		if row[2] != Vector3.ZERO and since == FACING_SWITCH_FRAME:
			# The direction change: the legs cross-fade to the new clip while the block stays up.
			_drive(row[2])
		if since >= FACING_FRAMES:
			_end_facing_case()
			_facing_case += 1
			if _facing_case >= FACING_CASES.size():
				return _finish()
			_start_facing_case()
	return false


## AC 1 amended (F1): the cases -- [label, legs' velocity, velocity after the switch (ZERO = none), legs' clip].
## Facing is +Z throughout (the lock-on target straight ahead), so these are forward, backward, both strafes, and a
## walk that turns into a strafe mid-case.
const FACING_CASES := [
	["walk", Vector3(0.0, 0.0, 2.0), Vector3.ZERO, &"walk"],
	["walk_backpedal", Vector3(0.0, 0.0, -2.0), Vector3.ZERO, &"walk_backpedal"],
	["walk_strafe_left", Vector3(-2.0, 0.0, 0.0), Vector3.ZERO, &"walk_strafe_left"],
	["walk_strafe_right", Vector3(2.0, 0.0, 0.0), Vector3.ZERO, &"walk_strafe_right"],
	["walk -> walk_strafe_right", Vector3(0.0, 0.0, 2.0), Vector3(2.0, 0.0, 0.0), &"walk"],
]
const FACING_FRAMES := 40
const FACING_SWITCH_FRAME := 10
## The chest may differ from the block standing still by the walk's own bob and sway, never by the legs' turn.
const FACING_TOLERANCE_DEG := 5.0
var _facing_case := 0
var _facing_frame := 0
var _facing_worst := 0.0
var _facing_samples := 0


func _start_facing_case() -> void:
	var row: Array = FACING_CASES[_facing_case]
	_settle_idle()
	_drive(row[1])
	_transition(IDLE, BLOCKING)
	_drive(row[1])
	_check(_legs.clip_name() == row[3], "F1 fixture %s: the legs play '%s' (got '%s')" % [row[0], row[3],
			_legs.clip_name()])
	_facing_frame = _frames
	_facing_worst = 0.0
	_facing_samples = 0


func _end_facing_case() -> void:
	var row: Array = FACING_CASES[_facing_case]
	print("F1 facing %s: worst chest yaw error %.2f deg over %d frames" % [row[0], _facing_worst, _facing_samples])
	_check(_facing_samples > 0, "F1 %s: no rendered sample (vacuous)" % row[0])
	_check(_facing_worst <= FACING_TOLERANCE_DEG,
		"F1 %s: the chest turns with the legs -- %.2f deg off the standing block (tolerance %.1f)"
			% [row[0], _facing_worst, FACING_TOLERANCE_DEG])


## Yaw (degrees) of a rotation's forward (+Z) axis, about the skeleton's +Y -- the hero's own frame.
static func _yaw_deg(q: Quaternion) -> float:
	var z := Basis(q).z
	return rad_to_deg(atan2(z.x, z.z))


## The chest's rotation relative to the root, composed down the chain from the given per-bone local rotations.
func _chest(hips: Quaternion, spine: Quaternion, spine1: Quaternion, spine2: Quaternion) -> Quaternion:
	return hips * spine * spine1 * spine2


func _sample_facing() -> void:
	if _legs.influence < 1.0:
		return
	var rendered := _chest(_bone_rotation("mixamorig_Hips"), _bone_rotation("mixamorig_Spine"),
			_bone_rotation("mixamorig_Spine1"), _bone_rotation("mixamorig_Spine2"))
	var clip := _player.current_animation
	var at := _player.current_animation_position
	var standing := _chest(_track_rotation(clip, "mixamorig_Hips", at), _track_rotation(clip, "mixamorig_Spine", at),
			_track_rotation(clip, "mixamorig_Spine1", at), _track_rotation(clip, "mixamorig_Spine2", at))
	var error := absf(wrapf(_yaw_deg(rendered) - _yaw_deg(standing), -180.0, 180.0))
	_facing_worst = maxf(_facing_worst, error)
	_facing_samples += 1


func _on_skeleton_updated() -> void:
	if _render_phase == 4:
		_sample_facing()
		return
	if _render_phase != 1 or _legs.influence < 1.0 or _legs.clip_name() != &"walk":
		return
	_render_samples += 1
	var leg := _angle(_bone_rotation("mixamorig_LeftUpLeg"),
			_track_rotation(&"walk", "mixamorig_LeftUpLeg", _legs.playhead()))
	var spine := _angle(_bone_rotation("mixamorig_Spine1"),
			_track_rotation(_player.current_animation, "mixamorig_Spine1", _player.current_animation_position))
	_check(leg < 0.01, "RENDERED: the left thigh carries the walk clip (%.4f rad off)" % leg)
	_check(spine < 0.01, "RENDERED: the spine carries the block clip (%.4f rad off)" % spine)


func _finish() -> bool:
	if _skeleton != null and _skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
		_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
	if is_instance_valid(_hero):
		_hero.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
