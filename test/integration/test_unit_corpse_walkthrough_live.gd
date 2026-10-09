extends SceneTree

## Story 4-3d (AC 4, and AC 3's debug-reset half): A LINGERING CORPSE IS INERT TO PHYSICS -- the
## hero WALKS THROUGH IT, the hero's hitbox query does not SEE it, no contact fact is recorded
## against it -- and the debug reset clears it like everything else.
##
## EVERY ASSERTION IS AN EFFECT, and each one is PAIRED against a live unit so it cannot pass for
## the wrong reason:
##
##   WALK-THROUGH is a POSITION DELTA, never a `collision_layer`/`disabled` property read. The
##     hero is driven at a LIVE unit first and must be STOPPED SHORT of it; then driven at the
##     CORPSE from the same distance and must END UP PAST it. A build with no collision at all
##     would fail the first half; a build with AC 4 skipped fails the second.
##
##   THE HURTBOX is `get_overlapping_areas()` on the hero's real hitbox: the LIVE unit's Hurtbox
##     must be in that list and the CORPSE's must not. A query that returned nothing at all --
##     because the hitbox was not monitoring, or nothing was in range -- fails the live half.
##
##   THE RECORDER's contact channel must carry no fact addressed to the dead index across the
##     linger, which is the cleanliness requirement AC 4 exists for (gameplay is not at risk --
##     `match_state.gd`'s dead-target drop already discards such a fact -- so hp cannot be the
##     instrument). THIS ONE ASSERTION IS NOT LIVE-PAIRED (REVIEW FIX PASS, 2026-08-26): a total-
##     fact counter was tried and removed -- in this file's own scenario P1 never swings again
##     after the kill, so the channel is genuinely empty after death whether the query is honest or
##     silently broken, and a counter that always reads 0 either way is not a pairing. See
##     `_count_facts_against_corpse()` for the measurement.
##
##   THE DEBUG RESET is asserted as a CONFIRMATION, not a change site: `_free_unit_actors` frees
##     every entry in `_unit_actors[slot]` unconditionally, live or corpse, so a lingering corpse
##     is already covered. This file proves that by test rather than by reading the loop, and it
##     checks the TREE for orphaned `UnitActor` nodes, not just the arrays -- an array cleared
##     while the node stayed parented is exactly the leak a parallel-array timer would cause.
##
## NAMED MUTATIONS, re-derived against the shipped seat:
##   AC 4 walk-through -- delete the `$Collision.disabled = true` line from
##     `UnitActor.disable_all_collision()`. The hero is blocked by the corpse and
##     `_passed_corpse` is false.
##   AC 4 collision -- disable only `$Hitbox`, leave `$Collision`/`$Hurtbox` live. The corpse's
##     Hurtbox comes back in `get_overlapping_areas()` and `_corpse_seen_by_hitbox` fires. (The
##     three ARE independently toggleable -- measured: `Collision` is a CollisionShape3D with its
##     own `disabled`, `Hurtbox`'s live property is `monitorable`, `Hitbox`'s is `monitoring`.)
##   AC 3 reset -- add a liveness skip to `MatchRunner._free_unit_actors` so it stops freeing
##     corpses unconditionally. The corpse survives `round_started` and `_orphans_after_reset`
##     is non-zero.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_corpse_walkthrough_live.gd

const P1_ARM_FRAME := 4
const P1_CONFIRM_FRAME := 10
const P1_CONFIRM_RELEASE_FRAME := 14
const P2_ARM_FRAME := 18
const P2_CONFIRM_FRAME := 24
const P2_CONFIRM_RELEASE_FRAME := 28
const SPAWN_CHECK_FRAME := 32
const PLACE_FRAME := 36
const SWING_MARGIN_TICKS := 6
const MAX_SWINGS := 12
const REACH_DISTANCE := 0.95
const SIDE_OFFSET := 0.35
const MAX_FRAMES := 2000

## The walk-through probe. The obstacle is parked this far along +x from the hero, the hero is
## then driven right for enough frames to cover DRIVE_TRAVEL units -- far more than enough to pass a
## 0.6-wide body, and far more than enough to be visibly stopped by one.
##
## Story 6-7b (Task 7, the `M3` correction): this was `DRIVE_FRAMES := 40`, sized in a comment
## against "the authored 5.0 move speed" -- a literal tied to a tempo `R1` retuned to 6.0. The TRAVEL
## is the property the probe needs, so it is the constant now, and the frame count is re-derived
## from the authored run speed READ LIVE off the applied config (`_drive_frames`). At 5.0 that
## reproduces the old 40 frames exactly (ceil(3.3 * 60 / 5.0) = 40); no margin was widened.
const OBSTACLE_GAP := 1.2
const DRIVE_TRAVEL := 3.3
## How far PAST the obstacle's own x the hero must end up for "walked through" to be true, and how
## far SHORT of it for "blocked" to be true. Both are outside the two bodies' combined half-widths
## (0.3 + 0.3), so neither verdict can be produced by resting against the obstacle.
const PAST_MARGIN := 0.4
const BLOCKED_MARGIN := 0.4
## Where the friendly unit is parked while the CORPSE probe runs, so it cannot block the hero and
## be mistaken for the corpse doing it.
const PARKING_LOT := Vector3(40.0, 0.0, 40.0)

## Pinned-to-composition was the defect, found when deck_size 20 -> 24 at the 4-4 live smoke: a
## fixed seed no longer guarantees a summoning card lands in the frame-3 hand. Reshuffle through
## the same debug-reset input path a player uses instead of pinning the deal. Since story 7-4 the runner
## draws a NEW seed every launch, so this file fixes it with `seed_override = 12345` (`7-4/R15`); from that
## fixed seed the RNG advances deterministically each reshuffle, so the retry sequence is identical on
## every run.
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
var _spawned := false

var _swing_period := 0
var _next_swing_frame := 0
var _swings := 0
var _killed := false

## The probe state machine: 0 park+kill, 1 blocked-by-live, 2 walk-through-corpse, 3 hitbox query,
## 4 reset, 5 done.
var _stage := 0
var _stage_frame := 0
var _obstacle_x := 0.0

var _blocked_by_live := false
var _live_probe_dx := 0.0
var _passed_corpse := false
var _corpse_probe_dx := 0.0
var _live_seen_by_hitbox := false
var _corpse_seen_by_hitbox := false
var _hitbox_query_ran := false
var _facts_against_corpse := 0
var _last_counted_tick := -1
var _actors_after_reset := -1
var _orphans_after_reset := -1
var _detail := ""


func _initialize() -> void:
	var runner: Node = (load("res://src/main/main.tscn") as PackedScene).instantiate()
	# Story 7-4 (`7-4/R15`): this test reads or acts on the DEALT hand, so it fixes the deal at the seed the
	# runner shipped as a constant before 7-4 -- set BEFORE the runner enters the tree.
	runner.seed_override = 12345
	root.add_child(runner)


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
		if not _choose_summon_slot(_state.p1, "p1") or not _choose_summon_slot(_state.p2, "p2"):
			_reshuffling = true
			_reshuffle_tick = 0
			return false
	if _frames == P1_ARM_FRAME:
		Input.action_press(&"p1_cast_mode")
	if _frames == P1_ARM_FRAME + 1:
		Input.action_press(_p1_action)
	if _frames == P1_ARM_FRAME + 2:
		Input.action_release(_p1_action)
	if _frames == P1_CONFIRM_FRAME:
		Input.action_press(&"p1_cast_confirm")
	if _frames == P1_CONFIRM_FRAME + 2:
		Input.action_release(&"p1_cast_confirm")
	if _frames == P1_CONFIRM_RELEASE_FRAME:
		Input.action_release(&"p1_cast_mode")
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
		_spawned = _state.p1.units.size() == 1 and _state.p2.units.size() == 1 \
				and _live() != null and _victim() != null
		if not _spawned:
			return _finish(false, "spawn failed: p1=%d p2=%d live=%s victim=%s"
					% [_state.p1.units.size(), _state.p2.units.size(), _live(), _victim()])
		_next_swing_frame = PLACE_FRAME + 1

	if _spawned and not _killed:
		_park_victim()
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
				_killed = not _state.p2.units.is_alive_at(0)
				# THE FACT COUNT STARTS HERE, not at tick 0: every fact addressed to `[1, 0]`
				# BEFORE this point is a real hero swing landing on a LIVE minion, which is the
				# system working. Only facts recorded against the DEAD index are AC 4's concern.
				_last_counted_tick = (_runner._recorder as IntentRecorder).tick_count()
				if not _killed:
					return _finish(false, "the victim never died in %d swings" % _swings)
				_stage = 1
				_stage_frame = _frames

	if _killed:
		_count_facts_against_corpse()
		_run_stage()

	if _stage >= 5 or _frames >= MAX_FRAMES:
		return _report()
	return false


func _run_stage() -> void:
	var hero: Node3D = _runner._p1_hero
	var elapsed := _frames - _stage_frame
	match _stage:
		1:  # --- BLOCKED BY A LIVE UNIT: the pair that makes stage 2 mean something. ---
			var live := _live()
			if live == null:
				_detail += " friendly_unit_gone_before_blocked_probe;"
				_advance_stage()
				return
			if elapsed == 1:
				_obstacle_x = hero.global_position.x + OBSTACLE_GAP
		# STORY 4-6 (AC 1): `p1_move_up` -- CAMERA-FORWARD -- is what world +X is now, and the
		# swap is this story's cause (b) landing on an existing fixture rather than a fix. The rig
		# yaws every tick to frame the locked target, the default lock is the opposing hero, and
		# main.tscn parks P1 at x -3 and P2 at x +3 -- so camera-forward IS +X, and `p1_move_right`
		# is camera-RIGHT, which is now perpendicular to it. Measured, not assumed: with the rig
		# fixed this pressed `p1_move_right`; test_camera_relative.gd is the file that pins the new
		# mapping end-to-end.
				Input.action_press(&"p1_move_up")
				# Story 6-7 (Task 6(d) shape): also hold `p1_run` -- MOVE_SPEED is now the RUN speed,
				# and the drive length (`_drive_frames`, from DRIVE_TRAVEL) is sized against it.
				# Without this the
				# hero WALKS at half that speed and both this stage's and stage 2's probes under-run.
				Input.action_press(&"p1_run")
			# Re-parked every frame: the friendly unit is walking toward its own target, and an
			# obstacle that wandered off would make "blocked" unfalsifiable.
			live.global_position = Vector3(_obstacle_x, 0.0, hero.global_position.z)
			if elapsed >= _drive_frames():
				Input.action_release(&"p1_move_up")
				Input.action_release(&"p1_run")
				_live_probe_dx = hero.global_position.x - _obstacle_x
				_blocked_by_live = _live_probe_dx < -BLOCKED_MARGIN
				if not _blocked_by_live:
					_detail += " live_unit_did_not_block(dx=%.3f);" % _live_probe_dx
				_advance_stage()
		2:  # --- WALK THROUGH THE CORPSE, from the same geometry. ---
			var corpse := _corpse()
			if corpse == null:
				_detail += " corpse_gone_before_walkthrough_probe;"
				_advance_stage()
				return
			if elapsed == 1:
				var live2 := _live()
				if live2 != null:
					live2.global_position = PARKING_LOT
				_obstacle_x = hero.global_position.x + OBSTACLE_GAP
				corpse.global_position = Vector3(_obstacle_x, 0.0, hero.global_position.z)
				Input.action_press(&"p1_move_up")
				# Story 6-7 (Task 6(d) shape): also hold `p1_run` -- see stage 1's identical note.
				Input.action_press(&"p1_run")
			if elapsed >= _drive_frames():
				Input.action_release(&"p1_move_up")
				Input.action_release(&"p1_run")
				_corpse_probe_dx = hero.global_position.x - _obstacle_x
				_passed_corpse = _corpse_probe_dx > PAST_MARGIN
				if not _passed_corpse:
					_detail += " hero_did_not_pass_corpse(dx=%.3f);" % _corpse_probe_dx
				_advance_stage()
		3:  # --- THE HITBOX QUERY: the live hurtbox is seen, the corpse's is not. ---
			var corpse3 := _corpse()
			var live3 := _live()
			if corpse3 == null or live3 == null:
				_detail += " hitbox_probe_missing_subject;"
				_advance_stage()
				return
			# Both parked inside the hero's own HitboxShape volume -- the same placement the kill
			# above used (along the hero's FACING at REACH_DISTANCE, offset sideways), because
			# that placement is already proven to put a hurtbox inside the swept box. Placing them
			# at the hero's own origin does NOT: the shape sits forward at local z 0.9 and the
			# only thing the query returns there is the hero's OWN Hurtbox (measured -- one area,
			# neither unit).
			var facing: Vector2 = _state.p1.hero.facing
			if facing.is_zero_approx():
				facing = Vector2(0.0, 1.0)
			facing = facing.normalized()
			var forward := Vector3(facing.x, 0.0, facing.y)
			var side := Vector3(facing.y, 0.0, -facing.x)
			var base := hero.global_position + forward * REACH_DISTANCE
			base.y = 0.0
			corpse3.global_position = base + side * SIDE_OFFSET
			live3.global_position = base - side * SIDE_OFFSET
			if elapsed >= 4:
				var hitbox: Area3D = (_runner._p1_hero as HeroActor).hitbox
				var areas := hitbox.get_overlapping_areas()
				_live_seen_by_hitbox = areas.has(live3.get_node(^"Hurtbox"))
				_corpse_seen_by_hitbox = areas.has(corpse3.get_node(^"Hurtbox"))
				_hitbox_query_ran = true
				if not _live_seen_by_hitbox:
					_detail += (" live_hurtbox_not_seen(query returned %d areas -- the negative "
							+ "half would be vacuous);") % areas.size()
				if _corpse_seen_by_hitbox:
					_detail += " corpse_hurtbox_still_detectable;"
				_advance_stage()
		4:  # --- THE DEBUG RESET clears a lingering corpse like everything else. ---
			if elapsed == 1:
				Input.action_press(&"p1_debug_reset")
			if elapsed == 3:
				Input.action_release(&"p1_debug_reset")
			if elapsed >= 10:
				_actors_after_reset = (_runner._unit_actors[0] as Array).size() \
						+ (_runner._unit_actors[1] as Array).size()
				# THE TREE, not just the arrays: a corpse tracked in a parallel structure could be
				# cleared from the array and left parented, which is a leak the array cannot see.
				var orphans := root.find_children("*", "UnitActor", true, false)
				var alive_orphans := 0
				for node: Node in orphans:
					if is_instance_valid(node) and not node.is_queued_for_deletion():
						alive_orphans += 1
				_orphans_after_reset = alive_orphans
				if _actors_after_reset != 0:
					_detail += " actors_after_reset=%d;" % _actors_after_reset
				if _orphans_after_reset != 0:
					_detail += " orphaned_unit_actors_after_reset=%d;" % _orphans_after_reset
				_advance_stage()


func _advance_stage() -> void:
	_stage += 1
	_stage_frame = _frames


## AC 4's recording-cleanliness half: across the whole linger, the recorder's contact channel must
## carry no fact ADDRESSED to the dead unit.
##
## REVIEW FIX PASS (2026-08-26): this file used to claim the zero-facts assertion below was
## "paired against the total fact count so 'zero' cannot simply mean nothing was ever gathered'" --
## MEASURED FALSE. In this scenario P1 never swings again after the kill (the walkthrough/hitbox/
## reset stages that follow move units and query overlaps directly, never press `p1_attack`), so
## the recorder's contact channel is genuinely empty for every tick after death regardless of
## whether the query is broken -- a total-fact counter here would read 0 whether the guard is
## honest or vacuous, which is not a pairing, it is a second copy of the same blind spot. No
## honest pairing is available at this seat, so the counter is deleted rather than kept alongside
## a comment describing a guard that was never there. `_hitbox_query_ran` immediately below still
## proves the query itself executed and returned a non-empty set for the LIVE pair (stage 3), which
## is the closest thing this file has to "the channel is not silently dead" -- it just does not
## extend that proof to the post-death recorder ticks this function counts.
func _count_facts_against_corpse() -> void:
	var recorder: IntentRecorder = _runner._recorder
	# Counted per TICK, not per frame: the recorder's tick only advances on ticking frames, so
	# re-reading `contacts_at(tick_count())` every frame would multiply-count the same rows.
	# Row layout is `[attacker_slot, attacker_index, target_slot, target_index, ...]`
	# (`IntentRecorder.capture_push_contact`), so `[2], [3]` is the TARGET address.
	var tick := recorder.tick_count()
	while _last_counted_tick < tick:
		_last_counted_tick += 1
		for row: Array in recorder.contacts_at(_last_counted_tick):
			if int(row[2]) == 1 and int(row[3]) == 0:
				_facts_against_corpse += 1


func _park_victim() -> void:
	var hero: Node3D = _runner._p1_hero
	var victim := _victim()
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


func _report() -> bool:
	if not _hitbox_query_ran:
		_detail += " hitbox_query_never_ran;"
	if _facts_against_corpse > 0:
		_detail += " %d_facts_recorded_against_the_corpse;" % _facts_against_corpse
	var ok := _spawned and _killed and _blocked_by_live and _passed_corpse \
			and _hitbox_query_ran and _live_seen_by_hitbox and not _corpse_seen_by_hitbox \
			and _facts_against_corpse == 0 \
			and _actors_after_reset == 0 and _orphans_after_reset == 0
	print(("unit_corpse_walkthrough_live: swings=%d blocked_by_live=%s(dx=%.3f) "
			+ "passed_corpse=%s(dx=%.3f) live_seen=%s corpse_seen=%s corpse_facts=%d "
			+ "actors_after_reset=%d orphans_after_reset=%d%s")
			% [_swings, _blocked_by_live, _live_probe_dx, _passed_corpse, _corpse_probe_dx,
				_live_seen_by_hitbox, _corpse_seen_by_hitbox, _facts_against_corpse,
				_actors_after_reset, _orphans_after_reset, _detail])
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
		if _choose_summon_slot(_state.p1, "p1") and _choose_summon_slot(_state.p2, "p2"):
			_reshuffling = false
			return false
		_reshuffle_attempts += 1
		if _reshuffle_attempts >= RESHUFFLE_MAX_ATTEMPTS:
			return _finish(false, "no summoning card dealt to both players (after %d reshuffle attempts)"
					% _reshuffle_attempts)
		_reshuffle_tick = 0
	return false


func _teardown() -> void:
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()


func _actor(slot: int) -> UnitActor:
	var actors: Array = _runner._unit_actors[slot]
	if actors.is_empty():
		return null
	var node: Node = actors[0]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


## P1's unit -- alive throughout, the pair for every negative claim.
func _live() -> UnitActor:
	return _actor(0)


## P2's unit while it still lives.
func _victim() -> UnitActor:
	return _actor(1)


## The same node once it is dead -- named separately because the claims about it are different.
func _corpse() -> UnitActor:
	return _actor(1)


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


## Story 6-7b (Task 7): frames of held run input that cover DRIVE_TRAVEL at the AUTHORED run speed,
## read inline off the config the runner applied (the `test_unit_approach_live.gd` precedent).
func _drive_frames() -> int:
	var run_speed := maxf(_state.balance.move_speed, 0.0001)
	return ceili(DRIVE_TRAVEL * maxf(Engine.physics_ticks_per_second, 1.0) / run_speed)
