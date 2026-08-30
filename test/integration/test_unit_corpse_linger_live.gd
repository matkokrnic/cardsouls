extends SceneTree

## Story 4-3d (AC 2, AC 3, AC 5): A KILLED MINION'S ACTOR LINGERS AS A CORPSE FOR TEN SECONDS,
## the linger is TICK-COUNTED so the debug pause freezes it, and the `death` clip plays once and
## HOLDS its final pose for the rest of that span.
##
## EVERY ASSERTION HERE IS AN EFFECT. Retention is `is_instance_valid` on the actor at a counted
## tick, never a read of a timer field's presence. The pause is the counter FAILING TO MOVE across
## real frames, never a read of `_paused`. The held pose is the model's own BONE TRANSFORM not
## changing, never a read of the `loop` flag. This project has shipped three defects where a guard
## asserted an identifier and could not see the effect.
##
##   WHAT THIS FILE CANNOT SEE: it cannot see that the held pose is a fallen corpse rather than
##   some other frozen posture -- only that the pose stopped changing and that it is not the pose
##   the unit held while alive. "It looks like a body on the ground" is the operator's eye at Live
##   Smoke.
##
## AC 5's GUARD IS THE BONE POSE, NOT THE PLAYBACK POSITION, and that is a correction to the AC's
## own wording rather than a weakening of it. MEASURED (and already recorded in
## test_unit_clip_selection.gd, which asserts it from the other side): when a NON-LOOPING clip
## ends, Godot's AnimationPlayer STOPS -- `current_animation` clears to "" -- while the final pose
## stays on screen.
##
## CORRECTED AT THE REVIEW FIX PASS (2026-08-26): this file previously also claimed
## `current_animation_position` returns 0 once the clip ends, and used that as the reason a
## playback-position guard could never pass. Re-measured, independently: FALSE. The position stays
## PINNED at the clip's own length (`death` is 4.6000s), not 0. `current_animation` clearing to ""
## is the only half of the original claim that holds.
##
## THE BONE POSE STILL SHIPPED, and not because the position guard is impossible -- because the
## pose is the STRONGER claim: a pinned position would read correct even if something other than
## the held frame were driving what is actually on screen, and AC 5 is about the visible pose, not
## the player's internal clock. The visible effect AC 5 actually asks about is that THE POSE DOES
## NOT MOVE, which is what this file measures.
##
## NAMED MUTATIONS, re-derived against the shipped seat:
##   AC 2/3 retention -- revert `MatchRunner._free_dead_unit_actors` to free on the tick death is
##     observed. The corpse is gone hundreds of ticks before 599 and `_max_alive_linger` never
##     reaches it.
##   AC 3 pause -- drive `UnitActor.advance_corpse_linger()` off a wall-clock delta instead of the
##     tick count (or move the runner's call outside its `ticking` gate). The counter advances
##     across the paused span and `_counter_moved_while_paused` fires.
##   AC 5 hold -- re-enable `loop` on the `death` clip in tools/build_zombie_anims.gd's CLIPS map
##     and rebuild the library. The pose keeps changing after the clip's end and `_pose_held` is
##     false.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_corpse_linger_live.gd

const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const CONFIRM_RELEASE_FRAME := 14
const P2_ARM_FRAME := 18
const P2_CONFIRM_FRAME := 24
const P2_CONFIRM_RELEASE_FRAME := 28
const SPAWN_CHECK_FRAME := 32
const PLACE_FRAME := 36
const SWING_MARGIN_TICKS := 6
const MAX_SWINGS := 12
const REACH_DISTANCE := 0.95
const SIDE_OFFSET := 0.35
const MAX_FRAMES := 3000

## Where in the linger the pause probe runs, and how many REAL frames it holds for. Early enough
## that the corpse is nowhere near expiry, long enough that a wall-clock timer would visibly move.
const PAUSE_AT_TICK := 120
const PAUSE_FRAMES := 40

## How far the runner's ticking-frame count from death to free may sit from the corpse's own
## counter. Two frames of lag at each end of the paused span is the measured cost of the pause
## being an EDGE read one frame behind this callback.
const TICK_COUNT_TOLERANCE := 5

## Pinned-to-composition was the defect, found when deck_size 20 -> 24 at the 4-4 live smoke: a
## fixed seed no longer guarantees a summoning card lands in the frame-3 hand. Reshuffle through
## the same debug-reset input path a player uses instead of pinning the deal; the RNG advances
## deterministically each reshuffle, so the retry sequence is identical on every run.
const RESHUFFLE_MAX_ATTEMPTS := 12
const RESHUFFLE_SETTLE_TICKS := 10

var _reshuffling := false
var _reshuffle_tick := 0
var _reshuffle_attempts := 0

var _frames := 0
var _runner: Node
var _state: MatchState
var _p1_action := &""
var _p2_action := &""
var _slots_chosen := false
var _spawned := false

var _swing_period := 0
var _next_swing_frame := 0
var _swings := 0
var _done_swinging := false

## AC 2/3 evidence.
var _linger_started := false
var _max_alive_linger := -1
var _freed_at_linger := -1
var _hole_at_same_index := false
var _frames_since_death := 0
var _paused_frames := 0
var _first_seen_tick := 0

## AC 3 pause evidence.
var _pause_phase := 0
var _pause_press_frame := 0
var _pause_probe_done := false
var _pause_entry_tick := -1
var _counter_moved_while_paused := false
var _corpse_vanished_while_paused := false

## AC 5 held-pose evidence.
var _alive_pose := Transform3D()
var _have_alive_pose := false
var _clip_end_pose := Transform3D()
var _have_clip_end_pose := false
var _pose_moved_after_clip_end := false
var _death_clip_length := 0.0
var _other_clip_selected_after_death := false

var _detail := ""


func _initialize() -> void:
	root.add_child((load("res://src/main/main.tscn") as PackedScene).instantiate())


func _physics_process(_delta: float) -> bool:
	if _reshuffling:
		return _drive_reshuffle()
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _finish(false, "missing: runner=%s state=%s" % [_runner, _state])
		var ticks := _state.balance_ticks
		_swing_period = ticks.attack_windup_ticks + ticks.attack_active_ticks \
				+ ticks.attack_recovery_ticks + SWING_MARGIN_TICKS
	if _frames == 2:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		_state.p2.mana.add(_state.p2.mana.get_maximum())
		if not _state.flags.minions:
			return _finish(false, "the authored FeatureFlags has minions OFF -- cannot summon")
	if _frames == 3:
		_slots_chosen = _choose_summon_slot(_state.p2, "p2")
		if not _slots_chosen:
			_reshuffling = true
			_reshuffle_tick = 0
			return false
	# P2 summons the unit P1's hero will kill.
	if _frames == P2_ARM_FRAME:
		Input.action_press(&"p2_cast_mode")
	if _frames == P2_ARM_FRAME + 1:
		Input.action_press(_p2_action)
	if _frames == P2_ARM_FRAME + 2:
		Input.action_release(_p2_action)
	if _frames == P2_CONFIRM_FRAME:
		Input.action_press(&"p2_cast_confirm")
	if _frames == P2_CONFIRM_FRAME + 2:
		Input.action_release(&"p2_cast_confirm")
	if _frames == P2_CONFIRM_RELEASE_FRAME:
		Input.action_release(&"p2_cast_mode")
	if _frames == SPAWN_CHECK_FRAME:
		_spawned = _state.p2.units.size() == 1 and _corpse() != null
		if not _spawned:
			return _finish(false, "summon did not land: board=%d actor=%s"
					% [_state.p2.units.size(), _corpse()])
		var clip_player: AnimationPlayer = _corpse().animation.animation_player
		_death_clip_length = clip_player.get_animation(&"death").length
		_next_swing_frame = PLACE_FRAME + 1

	if _spawned and not _linger_started and not _done_swinging:
		_park_victim()
		_capture_alive_pose()

	# --- Swing until the victim dies. ---
	if _next_swing_frame > 0 and _frames == _next_swing_frame:
		Input.action_press(&"p1_attack")
		_swings += 1
	if _next_swing_frame > 0 and _frames == _next_swing_frame + 2:
		Input.action_release(&"p1_attack")
		if _state.p2.units.is_alive_at(0) and _swings < MAX_SWINGS:
			_next_swing_frame = _frames + _swing_period
		else:
			_next_swing_frame = 0
			_done_swinging = true

	if _done_swinging:
		_watch_corpse()

	if _freed_at_linger >= 0 or _frames >= MAX_FRAMES:
		return _report()
	return false


## The victim is parked inside the hero's hitbox volume every frame until it dies -- the approach
## step would otherwise walk it out of reach mid-kill. test_unit_combat_live.gd's placement.
func _park_victim() -> void:
	var hero: Node3D = _runner._p1_hero
	var victim := _corpse()
	if hero == null or victim == null:
		return
	var facing: Vector2 = _state.p1.hero.facing
	if facing.is_zero_approx():
		facing = Vector2(0.0, 1.0)
	facing = facing.normalized()
	var forward := Vector3(facing.x, 0.0, facing.y)
	var side := Vector3(facing.y, 0.0, -facing.x)
	var base := hero.global_position + forward * REACH_DISTANCE
	base.y = 0.0
	victim.global_position = base + side * SIDE_OFFSET


## The pose a LIVE unit held, kept as AC 5's non-vacuity pair: "the pose stopped changing" proves
## nothing unless the held pose is different from the one it held before it died.
func _capture_alive_pose() -> void:
	var pose: Variant = _hips_pose()
	if pose != null:
		_alive_pose = pose
		_have_alive_pose = true


## Everything after the kill: the linger count, the pause probe, and the held pose.
func _watch_corpse() -> void:
	var corpse := _corpse()
	if corpse == null:
		if _pause_phase == 2:
			# Vanishing DURING the pause is the wall-clock failure in its most visible form: the
			# corpse aged out while the game was frozen for inspection.
			_corpse_vanished_while_paused = true
			_detail += " corpse_vanished_while_paused;"
		if _linger_started and _freed_at_linger < 0:
			# It was here last frame and is gone now -- the free landed on the tick AFTER the last
			# one we saw it alive at. That is the whole retention claim, expressed as a count.
			_freed_at_linger = _max_alive_linger + 1
			var actors: Array = _runner._unit_actors[1]
			_hole_at_same_index = actors.size() == 1 and actors[0] == null
		return
	if not corpse.is_lingering():
		return
	var tick: int = corpse._linger_ticks
	if not _linger_started:
		_linger_started = true
		# The counter is ALREADY RUNNING when this watcher first sees it: the kill lands mid-swing
		# and `_done_swinging` is only set when that swing's key is released, a few frames later.
		# The span this file counts is therefore `first_seen -> LINGER_TICKS`, not `0 -> 600`.
		_first_seen_tick = tick
	_max_alive_linger = maxi(_max_alive_linger, tick)
	# THE INDEPENDENT TICK COUNT. `_max_alive_linger` reads the corpse's OWN counter, so it cannot
	# tell a counter that counts ticks from one that counts something else and merely stops at the
	# same number. This counts the runner's TICKING FRAMES from death to free from the outside,
	# and `_report` requires the two to agree. Under a wall-clock linger these diverge immediately
	# in a headless run, which is uncapped and nothing like 60 Hz of real time.
	_frames_since_death += 1
	if _pause_phase >= 1 and _pause_phase <= 3:
		_paused_frames += 1

	# --- AC 3: the debug pause must FREEZE the count, not merely leave the corpse alive. ---
	# The pause is an EDGE read (DebugInputReader.pause_pressed), so each toggle is a press held
	# for two frames and then released: PRESS to pause, hold PAUSE_FRAMES of real frames, PRESS
	# again to resume. A held key would neither re-toggle nor auto-fire, but releasing keeps the
	# next press an edge.
	if _pause_phase == 0 and tick >= PAUSE_AT_TICK:
		_pause_phase = 1
		_pause_press_frame = _frames
		Input.action_press(&"debug_pause")
	elif _pause_phase == 1:
		if _frames == _pause_press_frame + 2:
			Input.action_release(&"debug_pause")
			_pause_phase = 2
			# THE BASELINE IS TAKEN HERE, NOT AT THE PRESS, and the two-tick gap is measured
			# rather than fudged: this SceneTree callback runs AFTER the runner's own
			# `_physics_process` for the frame, so a press issued on frame F is first read by
			# `DebugInputReader.pause_pressed()` on frame F+1, and the corpse legitimately ages
			# one more tick before the freeze takes hold. Baselining after the freeze is what
			# makes the assertion "the counter does not move WHILE PAUSED" rather than "the
			# counter never moves near the press".
			_pause_entry_tick = tick
	elif _pause_phase == 2:
		# THE ASSERTION: real frames are passing and the corpse's own counter is NOT moving.
		if tick != _pause_entry_tick and not _counter_moved_while_paused:
			_counter_moved_while_paused = true
			_detail += " counter_moved_while_paused(%d->%d);" % [_pause_entry_tick, tick]
		if _frames >= _pause_press_frame + PAUSE_FRAMES:
			_pause_probe_done = true
			_pause_phase = 3
			_pause_press_frame = _frames
			Input.action_press(&"debug_pause")
	elif _pause_phase == 3 and _frames == _pause_press_frame + 2:
		Input.action_release(&"debug_pause")
		_pause_phase = 4

	# --- AC 5: the `death` clip plays once and the pose then stops moving. ---
	var player: AnimationPlayer = corpse.animation.animation_player
	if player.current_animation != &"" and player.current_animation != &"death":
		_other_clip_selected_after_death = true
		_detail += " clip_'%s'_selected_after_death;" % player.current_animation
	var pose: Variant = _hips_pose()
	if pose != null and float(tick) / 60.0 > _death_clip_length + 0.2:
		if not _have_clip_end_pose:
			_clip_end_pose = pose
			_have_clip_end_pose = true
		elif not (_clip_end_pose as Transform3D).is_equal_approx(pose):
			_pose_moved_after_clip_end = true


func _report() -> bool:
	var retained := _max_alive_linger == UnitActor.LINGER_TICKS - 1 \
			and _freed_at_linger == UnitActor.LINGER_TICKS
	if not retained:
		_detail += " retention(max_alive=%d freed_at=%d expected %d/%d);" \
				% [_max_alive_linger, _freed_at_linger,
					UnitActor.LINGER_TICKS - 1, UnitActor.LINGER_TICKS]
	if not _hole_at_same_index:
		_detail += " no_hole_at_index_0;"
	# The corpse's own counter and an outside count of ticking frames must agree, to within the
	# two-frame lag the pause edge costs at each end of the paused span.
	var ticking_frames := _frames_since_death - _paused_frames
	var expected_ticks := UnitActor.LINGER_TICKS - _first_seen_tick
	var tick_counted := absi(ticking_frames - expected_ticks) <= TICK_COUNT_TOLERANCE
	if not tick_counted:
		_detail += (" linger_is_not_tick_counted(the corpse counted %d ticks from first sight to "
				+ "free, the runner ran %d ticking frames);") % [expected_ticks, ticking_frames]
	var paused_ok := _pause_probe_done and not _counter_moved_while_paused \
			and not _corpse_vanished_while_paused
	if not _pause_probe_done:
		_detail += " pause_probe_never_ran;"
	var pose_held := _have_alive_pose and _have_clip_end_pose \
			and not _pose_moved_after_clip_end \
			and not (_alive_pose as Transform3D).is_equal_approx(_clip_end_pose)
	if not _have_clip_end_pose:
		_detail += " never_sampled_past_clip_end;"
	if _pose_moved_after_clip_end:
		_detail += " pose_kept_moving_after_clip_end(death clip is looping?);"
	if _have_alive_pose and _have_clip_end_pose \
			and (_alive_pose as Transform3D).is_equal_approx(_clip_end_pose):
		_detail += " held_pose_equals_living_pose(AC 5 would be vacuous);"
	# --- The Part B replacement: WHICH clip's end pose is the corpse holding? ---
	var death_ref: Variant = _reference_pose(&"death")
	var attack_ref: Variant = _reference_pose(&"attack")
	var plays_death := false
	if not _have_clip_end_pose or death_ref == null or attack_ref == null:
		_detail += " could_not_build_reference_poses;"
	else:
		var held := _clip_end_pose as Transform3D
		plays_death = held.is_equal_approx(death_ref as Transform3D)
		if not plays_death:
			_detail += " held_pose_is_not_the_death_clip's_end;"
		if held.is_equal_approx(attack_ref as Transform3D):
			_detail += " held_pose_IS_the_attack_clip's_end(4-3c/R15 ordering broken -- the "
			_detail += "corpse was never told it died);"
		if (death_ref as Transform3D).is_equal_approx(attack_ref as Transform3D):
			_detail += " death_and_attack_end_poses_are_identical(this comparison is vacuous);"

	var ok := _spawned and retained and _hole_at_same_index and paused_ok and pose_held \
			and plays_death and tick_counted and not _other_clip_selected_after_death
	print(("unit_corpse_linger_live: swings=%d linger_started=%s max_alive=%d freed_at=%d "
			+ "hole=%s pause_ok=%s(entry_tick=%d) pose_held=%s plays_death=%s ticking_frames=%d death_clip=%.4fs%s")
			% [_swings, _linger_started, _max_alive_linger, _freed_at_linger, _hole_at_same_index,
				paused_ok, _pause_entry_tick, pose_held, plays_death, ticking_frames, _death_clip_length, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	_teardown()
	quit(0 if ok else 1)
	return false


func _finish(ok: bool, message: String) -> bool:
	print(message)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	_teardown()
	quit(0 if ok else 1)
	return false


## Drives one press/release/settle cycle of the debug reset, then re-checks the dealt hand.
## Bounded so a build that never deals a summoning card still fails, rather than hanging.
func _drive_reshuffle() -> bool:
	_reshuffle_tick += 1
	if _reshuffle_tick == 1:
		Input.action_press(&"p1_debug_reset")
	if _reshuffle_tick == 3:
		Input.action_release(&"p1_debug_reset")
	if _reshuffle_tick == RESHUFFLE_SETTLE_TICKS:
		_slots_chosen = _choose_summon_slot(_state.p2, "p2")
		if _slots_chosen:
			_reshuffling = false
			return false
		_reshuffle_attempts += 1
		if _reshuffle_attempts >= RESHUFFLE_MAX_ATTEMPTS:
			return _finish(false, "no summoning card dealt to p2 (after %d reshuffle attempts)"
					% _reshuffle_attempts)
		_reshuffle_tick = 0
	return false


func _teardown() -> void:
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()


## THE BEHAVIOURAL REPLACEMENT FOR test_unit_clip_selection.gd's DELETED PART B (`4-3d/R17`).
##
## Part B asserted SOURCE ORDER -- that the controller push in `MatchRunner._aim_unit_actors` sits
## above that loop's liveness gate (`4-3c/R15`) -- because in 4-3c nothing behavioural could see
## it: a dead unit's actor was freed the same frame, so the loop never reached a corpse. THIS
## STORY'S LINGER IS WHAT MAKES IT VISIBLE, and this is the effect it was always standing in for.
##
## THE ASSERTION: the pose the corpse HOLDS is the pose the `death` clip ends on, and is NOT the
## pose the `attack` clip ends on. Both references are produced by driving a THROWAWAY unit
## instance's own AnimationPlayer to each clip's end and reading the same bone -- so this compares
## poses, not clip names, and a corpse frozen in a half-raised claw (the exact defect a push
## behind the liveness gate produces) fails it.
##
##   NAMED MUTATION: move the `on_unit_tick(...)` push in `MatchRunner._aim_unit_actors` BELOW
##   that loop's `if not player.units.is_alive_at(index): continue` gate. The corpse is never told
##   it died, keeps the `attack` selection, and holds the ATTACK clip's final pose instead.
##
##   WHAT IT STILL CANNOT SEE: it cannot see an ordering defect on a unit that was IDLE when it
##   died -- such a corpse would freeze on `idle`, whose final pose this comparison does not
##   name. The victim here is killed while attacking, which is the case the ruling is about.
func _reference_pose(clip: StringName) -> Variant:
	var probe := (load("res://src/actors/minions/unit_actor.tscn") as PackedScene).instantiate()
	root.add_child(probe)
	var skeleton: Skeleton3D = probe.get_node_or_null(^"SkeletonZombie/Skeleton3D") as Skeleton3D
	var player: AnimationPlayer = probe.get_node_or_null(^"SkeletonZombie/AnimationPlayer")
	if skeleton == null or player == null:
		probe.free()
		return null
	var bone := skeleton.find_bone("mixamorig_Hips")
	if bone < 0:
		probe.free()
		return null
	player.play(clip)
	player.advance(player.get_animation(clip).length + 0.5)
	var pose := skeleton.get_bone_pose(bone)
	probe.free()
	return pose


## The model's `mixamorig_Hips` bone pose -- the same bone test_unit_clip_selection.gd's content
## check reads, and the one every clip in this library animates.
func _hips_pose() -> Variant:
	var unit := _corpse()
	if unit == null:
		return null
	var skeleton: Skeleton3D = unit.get_node_or_null(^"SkeletonZombie/Skeleton3D") as Skeleton3D
	if skeleton == null:
		return null
	var bone := skeleton.find_bone("mixamorig_Hips")
	if bone < 0:
		return null
	return skeleton.get_bone_pose(bone)


## P2's unit -- alive it is the victim, dead it is the corpse. `null` for a freed instance and for
## a `null` hole alike, which is exactly what the retention claim is about.
func _corpse() -> UnitActor:
	var actors: Array = _runner._unit_actors[1]
	if actors.is_empty():
		return null
	var node: Node = actors[0]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


func _choose_summon_slot(player: PlayerState, prefix: String) -> bool:
	var db := root.get_node_or_null("/root/CardDatabase")
	if db == null:
		return false
	var hand := player.hand.to_array()
	for index in hand.size():
		if player.hand.is_slot_empty(index):
			continue
		var card := db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		# Story 4-4 (AC 1): MINION-summoning cards ONLY. Before this story every `summon_*` id
		# resolved to one uniform unit, so any of them served. Three of them now summon TOTEMS --
		# which stand still (`4-4/R12`), carry no animation rig, and in the Combat totem's case fire
		# a projectile instead of swinging -- so a test that measures MINION behaviour must not have
		# its subject chosen by the shuffle. The exclusion reads the resolver's OWN table rather than
		# a second list of totem ids, so the two can never disagree.
		var effect_id: StringName = card.basic_effect.effect_id
		var is_summon := String(effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON)
		var is_totem := CardEffectResolver.SUMMON_KINDS.has(effect_id)
		if is_summon and not is_totem:
			var action := StringName("%s_card_%d" % [prefix, index + 1])
			if not InputMap.has_action(action):
				return false
			if prefix == "p1":
				_p1_action = action
			else:
				_p2_action = action
			return true
	return false
