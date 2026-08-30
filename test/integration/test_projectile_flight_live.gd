extends SceneTree

## Story 4-4 (AC 3, AC 5, AC 13, AC 14, AC 15): THE COMBAT TOTEM AND ITS SHOT, IN THE LIVE SCENE.
##
## WHAT THIS FILE OWNS, and it is precisely the half `test/state/test_projectile_flight.gd` cannot
## reach. That file proves the STATE of a projectile — the launch seat, the acceleration arithmetic,
## the budget, the homing FLAG and every rule about what ends it — with no scene at all. Everything
## below needs a running scene and could not be asserted headlessly:
##   * AC 14: the shot is a DISTINCT ENTITY IN THE WORLD that TRAVELS. A `ProjectileActor` node
##     appears in the tree at the totem's position and its `global_position` MOVES over successive
##     ticks. Headlessly a projectile is a row in a container and "travels" is unfalsifiable.
##   * AC 15: HOMING GEOMETRY. The heading is actor-owned (`4-3/R2` keeps position out of
##     `src/state/`), so the only place "its heading updates toward the target's current position"
##     can be measured is here — against a target that MOVES while the shot is in flight.
##   * AC 5 / `4-4/R12`: the totem NEVER LEAVES ITS SPAWN POSITION while alive. Headlessly a totem
##     has no position to stay at.
##   * AC 3: the totem's actor authors NO `Hitbox` and DOES author `Collision` and `Hurtbox` — a
##     scene-tree fact, not a state one.
##   * AC 13 / `4-4/R10`: HOLD FIRE OUT OF RANGE. The reach probe is a RUNNER measurement against
##     the kind's authored 8 m range, so the post-selection gate can only be exercised live.
##
## THE TOTEM IS PLACED STRAIGHT ONTO THE BOARD rather than cast from a hand, and that is deliberate
## rather than a shortcut: the cast path is `test_card_effect_resolution.gd`'s and
## `test_unit_attack_live.gd`'s, and driving it here would make every assertion below depend on
## which card the shuffle dealt. The runner spawns an actor per BOARD RECORD (AC 10 of story 4-1 —
## "identical live and replay by construction ... this reads the board, not the cast"), so a record
## appended directly exercises exactly the same spawn path a cast would.
##
## NON-VACUITY IS ASSERTED UP FRONT, the `test_summon_actor_live.gd` idiom: the authored flags must
## have `totems` ON and the authored config must carry a `combat_totem` kind that actually fires a
## projectile. With either missing every assertion below would "pass" for the wrong reason.

var _frames := 0
var _runner: Node = null
var _state: MatchState = null

var _totem_spawn := Vector3.ZERO
var _shot_first_position := Vector3.ZERO
var _shot_last_position := Vector3.ZERO
var _shot_seen := false
var _shot_moved := false
var _shot_steered := false
var _totem_never_moved := true
var _totem_has_no_hitbox := false
var _totem_has_body_and_hurtbox := false
var _held_fire_out_of_range := true
var _fired_in_range := false
var _range := 0.0
var _detail := ""

## Bearings sampled from the shot's successive positions. HOMING IS PROVEN AS A BEARING CHANGE
## TOWARD THE TARGET rather than as "it eventually hit", because a straight shot fired at a target
## that then walks INTO the line would also hit. The target is moved LATERALLY below precisely so a
## non-homing shot would miss.
var _bearings: Array[float] = []

## The tick the totem is put on the board. Late enough that the runner has finished `_ready()` and
## the first physics frames have settled.
const PLACE_FRAME := 4
## The target is moved OUT of range first, so the hold-fire gate is measured before the shot.
const OUT_OF_RANGE_FRAMES := 20
## Then in range, so the totem may fire.
const IN_RANGE_FRAME := 26
## Long enough for the whole flight at the authored profile.
const LAST_FRAME := 210


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _fail("missing: runner=%s state=%s" % [_runner, _state])
		return false
	if _frames == 2:
		# NON-VACUITY, up front. `flags.totems` is read for the first time by this story, so a
		# closed flag would silently degrade every summon below into a no-op.
		if _state.flags == null or not _state.flags.totems:
			return _fail("the authored FeatureFlags has totems OFF -- this test cannot summon one")
		var kind_index := _state.balance.kind_index_of(&"combat_totem")
		var kind: UnitKindProfile = _state.balance.kind_at(kind_index)
		var attack: UnitAttackProfile = kind.attack_at(0) if kind != null else null
		if attack == null or attack.projectile == null:
			return _fail("authored balance carries no `combat_totem` kind that fires a projectile")
		if kind.move_speed != 0.0:
			return _fail("the authored combat_totem move_speed is %f, not the 0.0 `4-4/R12` rules"
					% kind.move_speed)
		_range = attack.range
		return false
	if _frames == 3:
		# Park P2's hero FAR from where the totem will stand, so the first stretch measures the
		# hold-fire gate rather than the shot.
		_p2_hero().global_position = Vector3(_range + 10.0, 1.0, 0.0)
		_p1_hero().global_position = Vector3(-2.0, 1.0, 0.0)
		return false
	if _frames == PLACE_FRAME:
		var kind_index := _state.balance.kind_index_of(&"combat_totem")
		var kind: UnitKindProfile = _state.balance.kind_at(kind_index)
		_state.p1.units.add(kind.max_hp, kind_index)
		# The acquired target is written directly for the same reason the record is: the throttled
		# targeting tick would supply it, and waiting for a boundary would only add latency to a
		# test that is not about targeting.
		_state.p1.units.set_target_at(0, 1, TargetingService.HERO_INDEX)
		return false
	if _frames == PLACE_FRAME + 2:
		var totem := _totem_actor()
		if totem == null:
			return _fail("the runner spawned no actor for the board record")
		_totem_spawn = totem.global_position
		# AC 3, measured on the SCENE rather than inferred: the totem authors Collision and Hurtbox
		# and does NOT author a Hitbox.
		_totem_has_no_hitbox = totem.get_node_or_null("Hitbox") == null
		_totem_has_body_and_hurtbox = totem.get_node_or_null("Collision") != null \
				and totem.get_node_or_null("Hurtbox") != null
		return false

	if _frames > PLACE_FRAME + 2 and _state.p1.units.size() > 0:
		# AC 5 / `4-4/R12`: the totem NEVER leaves its spawn position while alive.
		var totem := _totem_actor()
		if totem != null and totem.global_position.distance_to(_totem_spawn) > 0.001:
			_totem_never_moved = false

	# AC 13 / `4-4/R10`: while the acquired target is BEYOND the authored range, the totem must
	# never fire, however long it stays there.
	if _frames > PLACE_FRAME + 2 and _frames < IN_RANGE_FRAME:
		if _state.p1.projectiles.size() > 0:
			_held_fire_out_of_range = false

	if _frames == IN_RANGE_FRAME:
		# Walk the target INTO range. Nothing else changes.
		#
		# MEASURED FROM THE TOTEM'S ACTUAL SPAWN, not from the world origin: 4-3e places a summoned
		# unit BEHIND its summoner on the side away from the opponent, so the totem stands a couple
		# of metres further from P2 than P1's hero does. A position picked against the origin would
		# leave the totem out of its own 8 m range and the test would fail for a reason that has
		# nothing to do with the projectile.
		_p2_hero().global_position = Vector3(_totem_spawn.x + _range - 2.0, 1.0, 0.0)
		return false

	if _frames > IN_RANGE_FRAME:
		if _state.p1.projectiles.size() > 0:
			_fired_in_range = true
		var shot := _projectile_actor()
		if shot != null:
			if not _shot_seen:
				_shot_seen = true
				_shot_first_position = shot.global_position
				_shot_last_position = shot.global_position
			else:
				if shot.global_position.distance_to(_shot_last_position) > 0.001:
					_shot_moved = true
				_shot_last_position = shot.global_position
			# THE HOMING MEASUREMENT. The target is nudged laterally every few ticks while the shot
			# is in the air, and the shot's BEARING is sampled. A straight shot's bearing is
			# constant; a homing one's changes to follow. Comparing bearings rather than "did it
			# hit" is what makes this test fail on a shot that flies straight into a target that
			# happened to walk into the line.
			_bearings.append(shot.heading.signed_angle_to(Vector3.FORWARD, Vector3.UP))
			if _frames % 6 == 0:
				var hero := _p2_hero()
				hero.global_position += Vector3(0.0, 0.0, 1.2)

	# `SceneTree._physics_process` QUITS THE LOOP WHEN IT RETURNS TRUE, so every "keep going" path in
	# this file returns FALSE. Stated because it inverts the usual reading of a boolean return and is
	# the one thing about this harness that is easy to get backwards.
	if _frames >= LAST_FRAME:
		return _finish()
	return false


func _finish() -> bool:
	# A bearing SPREAD is the homing signal: the shot turned while it flew. The threshold is small
	# (about 1.7 degrees) because the authored turn rate is finite and the flight is short — what is
	# being refuted is "the heading never changed at all", not "it turned a lot".
	if _bearings.size() >= 3:
		var lo := _bearings[0]
		var hi := _bearings[0]
		for b in _bearings:
			lo = minf(lo, b)
			hi = maxf(hi, b)
		_shot_steered = absf(hi - lo) > 0.03
		_detail += " bearing_spread=%.4f rad over %d samples" % [absf(hi - lo), _bearings.size()]
	var travelled := _shot_first_position.distance_to(_shot_last_position)
	_detail += " travelled=%.3f" % travelled
	var ok := _totem_has_no_hitbox and _totem_has_body_and_hurtbox and _totem_never_moved \
			and _held_fire_out_of_range and _fired_in_range and _shot_seen and _shot_moved \
			and _shot_steered
	print("projectile_flight_live: no_hitbox=%s body_and_hurtbox=%s totem_static=%s "
			% [_totem_has_no_hitbox, _totem_has_body_and_hurtbox, _totem_never_moved]
			+ "held_fire_out_of_range=%s fired_in_range=%s shot_seen=%s shot_moved=%s steered=%s%s"
			% [_held_fire_out_of_range, _fired_in_range, _shot_seen, _shot_moved, _shot_steered,
				_detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	quit(1)
	return false


func _p1_hero() -> Node3D:
	return _runner.get_node("P1Hero") as Node3D


func _p2_hero() -> Node3D:
	return _runner.get_node("P2Hero") as Node3D


## P1's totem actor, read off the runner's own array so the test and the runner agree about which
## node is which record rather than searching the tree by type.
func _totem_actor() -> Node3D:
	var actors: Array = _runner._unit_actors[0]
	if actors.is_empty():
		return null
	var node: Node = actors[0]
	return node as Node3D if is_instance_valid(node) else null


## The FIRST live projectile actor on P1's side, read off the runner's array for `_totem_actor`'s
## reason. Returns null once the shot has been consumed or expired and its actor freed.
func _projectile_actor() -> ProjectileActor:
	var actors: Array = _runner._projectile_actors[0]
	for node: Node in actors:
		if is_instance_valid(node):
			return node as ProjectileActor
	return null
