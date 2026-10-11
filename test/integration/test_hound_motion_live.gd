extends SceneTree

## Story 7-3 (ACs 7, 9, 12, 14, 16, 17): THE HOUND'S BODY AND RIG FOLLOW WHAT STATE DECIDES, on the
## real runner and the shipped hound scene. One P1 hound against a standing P2 hero.
##
## EVERY ASSERTION IS AN EFFECT: where the actor is, which way it faces, and where its
## AnimationPlayer's playhead sits -- read on the tick state changes phase. The run is driven by the
## phases as they happen, not by frame numbers, so the seeded back-off and circle durations may be
## anything.
##
##   THE LEAP (AC 9, `7-3/R21`)  The first attack from range is entry 1. The hound is ROOTED through
##     the windup. While it winds up, the target is moved 3 m sideways: the leap then travels ALONG
##     THE LOCKED DIRECTION, not at the live target (it is not homing), covers real ground, and ENDS
##     CLOSER to its target than it began. On the tick ACTIVE opens the `leap` clip is at its
##     measured take-off mark (AC 17). Rooted again through recovery.
##   BACK-OFF (AC 12, AC 18)  With the target put 1.5 m in front of it, the hound moves AWAY from it
##     while still facing it, playing `walk_backwards`, and BARKS as it starts: the `hellhound/bark`
##     slot, on a positional player parented to the hound itself.
##   CIRCLE (AC 12)  It goes round the target the way state drew (`circle_dir_at`), ends near the
##     authored radius, and plays the matching strafe clip.
##   THE BITE (AC 9, `4-3c1`)  With the target held inside the close band as the circle ends, the next
##     attack is entry 0, the hound does NOT move through any of its three phases, and on the tick
##     ACTIVE opens the `attack` clip is at its measured strike mark (AC 17).
##   HIT (AC 7)  A record put into REACT stands still and plays `hit`.
##   GET-UP (AC 14, AC 16)  The hound is killed (its corpse keeps the owner's skin and plays `death`),
##     then a record is raised from that corpse the way Raise Dead adds one. The new actor stands
##     where the corpse lay, FACING THE WAY IT LAY (the target having moved a quarter-turn round it
##     in between), in the owner's skin; for the whole lockout it does not move or turn and plays
##     `death` BACKWARDS; when the lockout ends it is on its feet.
##
## STATE IS POKED DIRECTLY for the summon, the target's position, the reaction, the kill and the
## raise -- `test_effect_presentation_live.gd`'s "right-sized poke": what is under test is the
## runner's read of state and the actor's motion, not the card and contact plumbing that produces
## the state (pinned in `test/state/test_hellhound.gd`).
##
## Run: godot --headless --path . --script res://test/integration/test_hound_motion_live.gd

const HOUND_KIND := &"hellhound"
const MAX_FRAMES := 2400

## The controller's measured marks, restated (tools/measure_hellhound_rig.gd).
const BITE_STRIKE := 18.0 / 30.0
const LEAP_STRIKE := 4.0 / 30.0
## One frame of skew between the engine's idle-time animation advance and the physics tick
## (`test_unit_strike_alignment_live.gd`'s tolerance and reason).
const MARK_TOLERANCE := 0.08
## A rooted body may settle by a hair on `move_and_slide`; it may not travel.
const ROOTED := 0.05
## How long before the circle ends the target is brought inside the close band, in ticks. Longer
## than the reach-probe cadence, so a probe confirms the band before the hound re-engages.
const CLOSE_IN_TICKS := 24

const A_IDLE := UnitBoard.AttackPhase.IDLE
const A_WINDUP := UnitBoard.AttackPhase.WINDUP
const A_ACTIVE := UnitBoard.AttackPhase.ACTIVE
const A_RECOVERY := UnitBoard.AttackPhase.RECOVERY
const B_ENGAGE := UnitBoard.BehaviorPhase.ENGAGE
const B_BACK_OFF := UnitBoard.BehaviorPhase.BACK_OFF
const B_CIRCLE := UnitBoard.BehaviorPhase.CIRCLE
const B_REACT := UnitBoard.BehaviorPhase.REACT
const B_GET_UP := UnitBoard.BehaviorPhase.GET_UP

var _frames := 0
var _runner: Node
var _state: MatchState
var _effects: EffectPresenter
var _failures: Array[String] = []
var _log: Array[String] = []

var _stage := "summon"
var _stage_frames := 0
var _index := 0
var _kind_index := -1
var _kind: UnitKindProfile
var _prev_attack: int = A_IDLE
var _prev_behavior: int = B_ENGAGE

var _mark := Vector3.ZERO      # where the hound stood when the current measurement began
var _last_here := Vector3.ZERO
var _has_last_here := false
var _locked := Vector2.ZERO    # the direction state locked for the leap
var _live_dir := Vector2.ZERO  # the direction to the live target when the leap took off
var _start_distance := 0.0
var _leap_travel := 0.0
var _start_angle := 0.0
var _circle_dir := 0
var _circle_measured := false
var _saw_clip := false
var _saw_bark := false
var _corpse_position := Vector3.ZERO
var _corpse_yaw := 0.0
var _get_up_ticks := 0
var _get_up_frames := 0


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	main.seed_override = 12345
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_effects = _runner._effects if _runner != null else null
		if _runner == null or _state == null or _effects == null:
			return _finish("missing: runner=%s state=%s effects=%s" % [_runner, _state, _effects])
		_kind_index = _state.balance.kind_index_of(HOUND_KIND)
		_kind = _state.balance.kind_at(_kind_index)
		if _kind == null:
			return _finish("authored balance carries no `hellhound` kind")
		_get_up_ticks = _state.balance_ticks.kind_ticks_at(_kind_index).get_up_ticks
		# Feel pass: this run walks ONE path -- back-off, then a plain circle -- and wants the bark it
		# asserts. The live kind is told so, in this process only: every back-off ends in a circle that
		# does not reverse, and the first back-off barks. The other three options, the reversal and the
		# bark's chance are pinned in test_hellhound.gd, test_hound_feel_live.gd and
		# test_hound_clip_selection.gd.
		_kind.circle_weight = 1.0
		_kind.stalk_weight = 0.0
		_kind.feint_weight = 0.0
		_kind.re_engage_weight = 0.0
		_kind.circle_flip_chance = 0.0
		_kind.bark_chance = 1.0
		# Feel pass 2: and every attack ends in a back-off, every back-off in that circle (the press,
		# the run-on, the reposition and the retreat are pinned in test_hellhound.gd and
		# test_hound_pressure_live.gd).
		_kind.press_weight = 0.0
		_kind.run_on_weight = 0.0
		_kind.reposition_weight = 0.0
		_kind.retreat_weight = 0.0
		return false
	_stage_frames += 1
	if _step():
		return _finish("")
	if _frames >= MAX_FRAMES:
		return _finish("stuck in stage '%s' at frame %d" % [_stage, _frames])
	return false


func _enter(stage: String) -> void:
	_log.append("%s@%d" % [stage, _frames])
	_stage = stage
	_stage_frames = 0


## One frame of the run. Returns true when every stage has passed.
func _step() -> bool:
	var units := _state.p1.units
	if _stage == "summon":
		units.add(_kind.max_hp, _kind_index)
		_enter("clear")
		return false
	var hound := _actor(_index)
	if hound == null:
		return false
	if _stage == "clear":
		# The hound spawned behind its own hero, which now stands in its lane to the enemy
		# (`test_unit_strike_alignment_live.gd`'s `4-3e` finding). The hero is moved well aside ONCE
		# the hound exists -- moving it first would only move the spawn with it.
		_runner._p1_hero.global_position += Vector3(0.0, 0.0, 9.0)
		_enter("approach")
		return false
	var attack := units.attack_phase_at(_index)
	var behavior := units.behavior_phase_at(_index)
	var attack_edge := attack != _prev_attack
	var behavior_edge := behavior != _prev_behavior
	_prev_attack = attack
	_prev_behavior = behavior
	var here := hound.global_position
	# The position one sample ago. A phase edge is seen one drive AFTER state entered the phase, so the
	# body has already made that phase's first move; `before` is where it stood at the end of the
	# phase that just closed.
	var before := _last_here if _has_last_here else here
	_last_here = here
	_has_last_here = true
	var target_node: Node3D = _runner._p2_hero
	var target := target_node.global_position
	var player: AnimationPlayer = hound.animation.animation_player

	match _stage:
		"approach":
			if attack_edge and attack == A_WINDUP:
				_check(units.attack_choice_at(_index) == 1,
						"the first attack from range is entry %d, want 1 (the leap)" % units.attack_choice_at(_index))
				_mark = here
				_locked = units.attack_dir_at(_index)
				_start_distance = _planar(here, target)
				# Feel pass 2: how far the leap is to carry the hound -- to where its (standing) target
				# is as the windup begins, plus the authored overshoot, inside the authored band.
				var leap := _kind.attack_at(1)
				# (Feel pass 3: the overshoot is a share of that distance, never under its floor.)
				_leap_travel = clampf(_start_distance + maxf(leap.travel_overshoot,
						_start_distance * leap.travel_overshoot_fraction), leap.travel_min_distance,
						leap.travel_max_distance)
				# The target steps 3 m aside while the hound winds up.
				target_node.global_position += Vector3(-_locked.y, 0.0, _locked.x) * 3.0
				_start_distance = _planar(here, target_node.global_position)
				_enter("leap_windup")
		"leap_windup":
			if attack_edge and attack == A_ACTIVE:
				_check(_planar(before, _mark) < ROOTED,
						"the hound moved %.3f m during the leap's windup" % _planar(before, _mark))
				_check(player.current_animation == &"leap"
						and absf(player.current_animation_position - LEAP_STRIKE) <= MARK_TOLERANCE,
						"when the leap's ACTIVE window opens the rig plays '%s' at %.4f, want 'leap' at %.4f"
								% [player.current_animation, player.current_animation_position, LEAP_STRIKE])
				_mark = before
				_live_dir = Vector2(target.x - here.x, target.z - here.z).normalized()
				_enter("leap_active")
		"leap_active":
			if attack_edge and attack == A_RECOVERY:
				var moved := Vector2(here.x - _mark.x, here.z - _mark.z)
				_check(moved.length() > 1.5, "the leap carried the hound %.3f m, want real travel" % moved.length())
				# Feel pass 2: LEAP THROUGH. The distance was fixed when the windup began: past where
				# the target then stood, by the authored overshoot.
				_check(absf(moved.length() - _leap_travel) < 0.15,
						"the leap carried the hound %.3f m, want %.3f (the distance to its target as the windup began, plus the overshoot, inside the band)"
								% [moved.length(), _leap_travel])
				_check(_leap_travel > _start_distance - 3.5,
						"fixture: the leap was meant to pass its target (travel %.3f)" % _leap_travel)
				if moved.length() > 0.0:
					var along_locked := moved.normalized().dot(_locked.normalized())
					var along_live := moved.normalized().dot(_live_dir)
					_check(along_locked > 0.995,
							"the leap did not follow the locked direction (cos %.4f)" % along_locked)
					_check(along_live < 0.98,
							"the leap went at the LIVE target (cos %.4f): it homed" % along_live)
				_check(_planar(here, target) < _start_distance - 0.5,
						"the leap ended %.3f m from its target and began %.3f m from it: not closer"
								% [_planar(here, target), _start_distance])
				_mark = here
				_enter("leap_recovery")
		"leap_recovery":
			if attack_edge and attack == A_IDLE:
				_check(_planar(before, _mark) < ROOTED,
						"the hound moved %.3f m during the leap's recovery" % _planar(before, _mark))
				_check(behavior == B_BACK_OFF, "after its attack the hound is in behaviour %d, want BACK_OFF" % behavior)
				# The target is put 1.5 m in front of the hound, so the back-off has room to show.
				var ahead := -hound.global_transform.basis.z
				target_node.global_position = Vector3(here.x + ahead.x * 1.5, target.y, here.z + ahead.z * 1.5)
				_start_distance = 1.5
				_saw_clip = false
				_enter("back_off")
		"back_off":
			if behavior == B_BACK_OFF:
				_saw_clip = _saw_clip or player.current_animation == &"walk_backwards"
				# AC 18: the bark that starts a back-off is a positional player ON the hound.
				_saw_bark = _saw_bark or not hound.find_children("*", "AudioStreamPlayer3D", false, false).is_empty()
			if behavior_edge and behavior != B_BACK_OFF:
				_check(behavior == B_CIRCLE, "after the back-off the hound is in behaviour %d, want CIRCLE" % behavior)
				_check(_planar(here, target) > _start_distance + 0.3,
						"the back-off took the hound from %.3f m to %.3f m: it did not back away"
								% [_start_distance, _planar(here, target)])
				_check(_facing(hound, target) > 0.9,
						"the hound backing off does not face its target (cos %.4f)" % _facing(hound, target))
				_check(_saw_clip, "a hound backing off never played `walk_backwards`")
				_check(_saw_bark and _effects.played.has(&"hellhound/bark"),
						"a hound starting to back off did not bark from where it stands (AC 18): node=%s played=%s"
								% [_saw_bark, _effects.played.has(&"hellhound/bark")])
				_start_angle = _angle(here, target)
				_circle_dir = units.circle_dir_at(_index)
				_circle_measured = false
				_saw_clip = false
				_enter("circle")
		"circle":
			if behavior == B_CIRCLE and not _circle_measured:
				var want: StringName = &"walk_left" if _circle_dir == UnitBoard.CIRCLE_CLOCKWISE else &"walk_right"
				_saw_clip = _saw_clip or player.current_animation == want
				if units.behavior_ticks_at(_index) <= CLOSE_IN_TICKS:
					_circle_measured = true
					var swept := angle_difference(_start_angle, _angle(here, target))
					_check(_circle_dir != UnitBoard.CIRCLE_NONE, "state drew no circle direction")
					_check(swept * float(_circle_dir) > 0.15,
							"the hound swept %.3f rad round its target with circle_dir %d: wrong way or not at all"
									% [swept, _circle_dir])
					# Feel pass: the radius is the hound's OWN (its temperament) and it breathes; the
					# runner's own figure for this hound at this moment is what it is held to.
					var want_radius: float = _runner._circle_radius(_kind, 0, _index, units.behavior_ticks_at(_index),
							_runner._circle_wobble_ticks(_state.p1, _index))
					_check(absf(_planar(here, target) - want_radius) < 0.6,
							"the hound circles at %.3f m, its own radius now is %.3f (authored %.2f)"
									% [_planar(here, target), want_radius, _kind.circle_radius])
					_check(absf(want_radius - _kind.circle_radius) < _kind.circle_radius * 0.4,
							"the hound's own radius %.3f is nowhere near the authored %.2f" % [want_radius, _kind.circle_radius])
					_check(_facing(hound, target) > 0.9,
							"the circling hound does not face its target (cos %.4f)" % _facing(hound, target))
					_check(_saw_clip, "a hound circling %d never played `%s`" % [_circle_dir, want])
			if _circle_measured and attack == A_IDLE:
				# Hold the target inside the close band until the hound re-engages.
				var ahead := -hound.global_transform.basis.z
				var close := _kind.attack_at(0).range - 0.2
				target_node.global_position = Vector3(here.x + ahead.x * close, target.y, here.z + ahead.z * close)
			if attack_edge and attack == A_WINDUP:
				_check(_circle_measured, "the hound attacked before its circle could be measured")
				_check(units.attack_choice_at(_index) == 0,
						"with its target in the close band the attack is entry %d, want 0 (the bite)"
								% units.attack_choice_at(_index))
				_mark = here
				_enter("bite")
		"bite":
			if attack_edge and attack == A_ACTIVE:
				_check(player.current_animation == &"attack"
						and absf(player.current_animation_position - BITE_STRIKE) <= MARK_TOLERANCE,
						"when the bite's ACTIVE window opens the rig plays '%s' at %.4f, want 'attack' at %.4f"
								% [player.current_animation, player.current_animation_position, BITE_STRIKE])
				_check(_planar(before, _mark) < ROOTED,
						"the hound moved %.3f m during its bite's windup (rooted)" % _planar(before, _mark))
				_mark = before
				_locked = units.attack_dir_at(_index)
			if attack_edge and attack == A_RECOVERY:
				# Feel pass 2: THE BITE LUNGES. During ACTIVE, and only then, the body goes forward
				# along the locked heading by at most the authored lunge (its target's body may stop
				# it short; an unobstructed lunge is measured in test_hound_pressure_live.gd).
				var lunged := Vector2(here.x - _mark.x, here.z - _mark.z)
				var lunge := _kind.attack_at(0).travel_max_distance
				_check(lunged.length() > 0.1 and lunged.length() <= lunge + 0.03,
						"the bite lunged %.3f m during its ACTIVE window, want more than 0.1 and at most the authored %.2f"
								% [lunged.length(), lunge])
				if lunged.length() > 0.1:
					_check(lunged.normalized().dot(_locked.normalized()) > 0.9,
							"the lunge did not go along the locked heading (cos %.4f)"
									% lunged.normalized().dot(_locked.normalized()))
				_mark = here
			if attack_edge and attack == A_IDLE:
				_check(_planar(before, _mark) < ROOTED,
						"the hound moved %.3f m during its bite's recovery (rooted)" % _planar(before, _mark))
				# AC 7: a reaction, written the way `_begin_unit_reaction` writes it.
				units.set_behavior_at(_index, UnitBoard.BehaviorPhase.REACT, 30)
				# The target is put 4 m off, well outside the hound's stop distance: a reacting hound
				# that was still being walked at its target would visibly set off after it.
				var ahead := -hound.global_transform.basis.z
				target_node.global_position = Vector3(here.x + ahead.x * 4.0, target.y, here.z + ahead.z * 4.0)
				_enter("react")
		"react":
			if _stage_frames == 2:
				_mark = here
			if _stage_frames == 20:
				_check(behavior == B_REACT, "the poked reaction is not running (behaviour %d)" % behavior)
				_check(_planar(here, _mark) < ROOTED,
						"a reacting hound moved %.3f m" % _planar(here, _mark))
				_check(player.current_animation == &"hit",
						"a reacting hound plays '%s', want 'hit'" % player.current_animation)
				units.kill_at(_index, 600)
				_enter("corpse")
		"corpse":
			if _stage_frames == 6:
				_check(_skin(hound) == "T_HellHound_Pe_D.tga",
						"the corpse wears '%s', want the owner's purple skin (AC 14)" % _skin(hound))
				_check(player.current_animation == &"death" and player.get_playing_speed() >= 0.0,
						"the corpse plays '%s' at rate %.3f, want 'death' forwards"
								% [player.current_animation, player.get_playing_speed()])
				_corpse_position = here
				_corpse_yaw = hound.global_rotation.y
				# The target walks a quarter of the way round the corpse before it is raised: a get-up
				# that turned to face its target would no longer lie the way the corpse lay.
				var ahead := -hound.global_transform.basis.z
				target_node.global_position = Vector3(here.x - ahead.z * 3.0, target.y, here.z + ahead.x * 3.0)
				# Raise Dead's own two writes (`_apply_raise_dead`): consume the corpse, add the record
				# raised from it under its kind's get-up lockout.
				units.consume_corpse_at(_index)
				units.add(_kind.max_hp, _kind_index, _index, _get_up_ticks)
				_index = units.size() - 1
				_prev_attack = A_IDLE
				_prev_behavior = B_GET_UP
				_get_up_frames = 0
				_enter("get_up")
		"get_up":
			if _stage_frames == 1:
				return false
			if behavior == B_GET_UP:
				_get_up_frames += 1
				if _get_up_frames == 1:
					_check(_planar(here, _corpse_position) < 0.01,
							"the raised hound stands %.3f m from its corpse" % _planar(here, _corpse_position))
					_check(_skin(hound) == "T_HellHound_Pe_D.tga",
							"the raised hound wears '%s', want the owner's purple skin (AC 14)" % _skin(hound))
					_check(hound.animation is HoundAnimationController, "the raised hound is not the hound scene")
				_check(absf(angle_difference(hound.global_rotation.y, _corpse_yaw)) < 0.01,
						"a hound getting up faces %.3f rad, its corpse lay at %.3f" % [hound.global_rotation.y, _corpse_yaw])
				_check(_planar(here, _corpse_position) < ROOTED,
						"a hound getting up moved %.3f m" % _planar(here, _corpse_position))
				_check(attack == A_IDLE, "a hound getting up is in attack phase %d" % attack)
				# The reversed clip is fitted to the lockout, and the engine advances it on idle frames,
				# not on ticks: it may reach its first frame and stop a few ticks before the lockout's
				# last one. That is the clip having finished, and only that late is it accepted.
				var finished := player.assigned_animation == &"death" and not player.is_playing() \
						and _get_up_frames >= _get_up_ticks - 6
				if _get_up_frames > 2 and not finished:
					_check(player.current_animation == &"death" and player.get_playing_speed() < 0.0,
							"a hound getting up plays '%s' at rate %.3f, want 'death' backwards"
									% [player.current_animation, player.get_playing_speed()])
			elif _get_up_frames > 0:
				_check(absi(_get_up_frames - _get_up_ticks) <= 2,
						"the get-up was seen for %d frames, the authored lockout is %d ticks" % [_get_up_frames, _get_up_ticks])
				_check(player.current_animation != &"death",
						"a hound that has got up still plays 'death'")
				return true
			elif _stage_frames > 10:
				_check(false, "the raised record never entered GET_UP (behaviour %d)" % behavior)
				return true
	return false


func _actor(index: int) -> UnitActor:
	var actors: Array = _runner._unit_actors[0]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The hound's bearing from its target, the angle a clockwise circle (seen from above) increases.
func _angle(hound_position: Vector3, target: Vector3) -> float:
	return atan2(hound_position.z - target.z, hound_position.x - target.x)


## Cosine between the way the actor faces (its -Z) and the planar direction to `target`.
func _facing(hound: UnitActor, target: Vector3) -> float:
	var forward := -hound.global_transform.basis.z
	var to_target := Vector2(target.x - hound.global_position.x, target.z - hound.global_position.z)
	if to_target.is_zero_approx():
		return 1.0
	return Vector2(forward.x, forward.z).normalized().dot(to_target.normalized())


func _skin(hound: UnitActor) -> String:
	var mesh := hound.get_node_or_null(hound.skin_mesh_path) as MeshInstance3D
	var material := (mesh.material_override if mesh != null else null) as BaseMaterial3D
	if material == null or material.albedo_texture == null:
		return ""
	return material.albedo_texture.resource_path.get_file()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _finish(error: String) -> bool:
	if error != "":
		_failures.append(error)
	if _effects != null:
		_effects.stop_all_sounds()
	OS.delay_msec(100)
	for f in _failures:
		print("  FAILED: " + f)
	print("hound_motion_live: stages %s, finished at frame %d" % [_log, _frames])
	var ok := _failures.is_empty()
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false
