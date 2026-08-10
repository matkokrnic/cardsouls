extends SceneTree

## Story 4-2 (`4-2/R13`): THE GREY BOX ROTATES TO FACE ITS ACQUIRED TARGET, driven through the real
## runner — the machine half of the live smoke's visible signal.
##
## WHY THIS EXISTS AS A MACHINE TEST AT ALL, given the smoke is the operator's: the headless state
## suite structurally cannot see it. test_targeting_service.gd proves the STATE contract (a `[slot,
## index]` pair is stored at a throttle boundary), and every word of that is true of a match with no
## actor anywhere near it — which is exactly the failure mode `4-1`'s own smoke lesson names. The
## rotation is GEOMETRY, and geometry is machine-checkable (`PROC/R8` permits precisely this and bars
## only on-screen text fit), so the operator's smoke is left to judge legibility rather than to
## discover that nothing rotated.
##
## Drives the whole chain: real Input Map presses -> KeyboardController -> the runner's single
## _physics_process -> advance() step 6 (the summon) -> advance() step 7 (the throttled targeting
## tick) -> the runner's aim step -> a real UnitActor's yaw in the real scene tree.
##
## THE AUTHORED CADENCE IS USED, NOT AN OVERRIDE: `data/balance/balance_config.tres` authors 0.2 s
## (12 ticks), so a boundary is never more than 12 frames away. The wait below is generous rather
## than exact, because the point is that a boundary ARRIVES — its precise phase is
## test_targeting_service.gd's business.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_aim_live.gd

## Presses are HELD for several frames rather than pulsed for one, for the reason
## test_summon_actor_live.gd records: the runner's _physics_process and this script's are two separate
## callbacks in an unspecified order, so a one-frame pulse can be released before the runner ever
## samples the just_pressed edge.
const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const CONFIRM_RELEASE_FRAME := 14
const SPAWN_CHECK_FRAME := 18
## Comfortably more than the authored 12-tick interval past the spawn check, so at least one boundary
## has certainly passed.
const AIM_CHECK_FRAME := 40
## Yaw tolerance in radians. The comparison is against a yaw recomputed from the two node positions,
## so this absorbs float noise only — it is not a "close enough" allowance for a different heading.
const YAW_EPSILON := 0.01
## The heading a UnitActor has if NOTHING ever aims it: `unit_actor.tscn` authors no rotation on its
## root and the runner's spawn step writes `global_position` only, so an unaimed box sits at yaw 0.
##
## THIS IS THE NON-VACUITY BASELINE, and it replaces the obvious-looking alternative of sampling the
## yaw right after the spawn — which does not work, and the reason is worth recording: the authored
## cadence is 12 ticks, so a boundary can pass between the cast and any post-spawn sample, and the
## "before" reading is then already the aimed one. Measured doing exactly that (rotated=false while
## aimed=true). The authored default is a fixed fact and cannot be raced.
const UNAIMED_YAW := 0.0

var _frames := 0
var _runner: Node
var _state: MatchState
var _armed_slot := -1
var _armed_action := &""

var _slot_chosen := false
var _spawned := false
var _acquired_hero := false
var _aimed := false
var _rotated := false
var _detail := ""


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			print("missing: runner=%s state=%s" % [_runner, _state])
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == 2:
		# Mana, so the cast is affordable — the economy is not what this test is about.
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		# NON-VACUITY, up front, the test_summon_actor_live.gd idiom: with the minion layer off every
		# summon degrades and every assertion below would "pass" a weaker test for the wrong reason.
		if not _state.flags.minions:
			print("the authored FeatureFlags has minions OFF — this test cannot summon")
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == 3:
		_choose_a_summoning_slot()
		if not _slot_chosen:
			print("no summoning card in the dealt hand: %s" % str(_state.p1.hand.to_array()))
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == ARM_FRAME:
		Input.action_press(&"p1_cast_mode")
	if _frames == ARM_FRAME + 1:
		Input.action_press(_armed_action)
	if _frames == ARM_FRAME + 2:
		Input.action_release(_armed_action)
	if _frames == CONFIRM_FRAME:
		Input.action_press(&"p1_cast_confirm")
	if _frames == CONFIRM_FRAME + 2:
		Input.action_release(&"p1_cast_confirm")
	if _frames == CONFIRM_RELEASE_FRAME:
		Input.action_release(&"p1_cast_mode")
	if _frames == SPAWN_CHECK_FRAME:
		var unit := _first_unit_actor()
		_spawned = _state.p1.units.size() == 1 and unit != null
		if not _spawned:
			_detail += " board=%d actor=%s;" % [_state.p1.units.size(), unit]
	if _frames == AIM_CHECK_FRAME:
		var unit := _first_unit_actor()
		# P2's hero: the OPPOSING side from P1's unit, which is the only side `4-2/R3` allows.
		var hero: Node3D = _runner._p2_hero
		if unit == null or hero == null:
			_detail += " missing unit=%s hero=%s;" % [unit, hero]
		else:
			# STATE first: the pair the runner is supposed to be rendering. P2's board is empty, so
			# `standard`'s units-first ordering falls through to the opposing HERO (slot 1, index -1).
			_acquired_hero = _state.p1.units.target_slot_at(0) == 1 \
					and _state.p1.units.target_index_at(0) == TargetingService.HERO_INDEX
			if not _acquired_hero:
				_detail += " pair=[%d,%d];" % [
					_state.p1.units.target_slot_at(0), _state.p1.units.target_index_at(0)]
			# PRESENTATION second: the yaw actually on the node, against the yaw recomputed here from
			# the two world positions. Recomputed rather than hardcoded, because the hero moves and
			# the row placement is the runner's private choice.
			var planar := Vector2(hero.global_position.x - unit.global_position.x,
					hero.global_position.z - unit.global_position.z)
			var expected := atan2(planar.x, planar.y) + PI
			_aimed = absf(angle_difference(unit.global_rotation.y, expected)) <= YAW_EPSILON
			if not _aimed:
				_detail += " yaw=%.4f expected=%.4f;" % [unit.global_rotation.y, expected]
			# NON-VACUITY of the yaw check, in BOTH halves. (i) the box must have moved off the
			# UNAIMED heading the scene authors, or an aim step that did nothing would pass; and
			# (ii) the EXPECTED heading must itself differ from unaimed, or (i) would be asserting
			# something the geometry could not produce anyway.
			_rotated = absf(angle_difference(unit.global_rotation.y, UNAIMED_YAW)) > YAW_EPSILON \
					and absf(angle_difference(expected, UNAIMED_YAW)) > YAW_EPSILON
			if not _rotated:
				_detail += " never_turned(yaw=%.4f expected=%.4f unaimed=%.4f);" % [
					unit.global_rotation.y, expected, UNAIMED_YAW]
		var ok := _slot_chosen and _spawned and _acquired_hero and _aimed and _rotated
		print("unit_aim_live: slot=%d spawned=%s acquired_hero=%s aimed=%s rotated=%s%s" % [
			_armed_slot, _spawned, _acquired_hero, _aimed, _rotated, _detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## The first dealt slot whose authored card carries a `summon_*` effect — test_summon_actor_live.gd's
## chooser verbatim, including its reason for reaching the library through the autoload NODE (this
## file IS the `--script` main loop, compiled before the autoloads register).
func _choose_a_summoning_slot() -> void:
	var db := root.get_node_or_null("/root/CardDatabase")
	if db == null:
		return
	var hand := _state.p1.hand.to_array()
	for index in hand.size():
		if _state.p1.hand.is_slot_empty(index):
			continue
		var card := db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		if String(card.basic_effect.effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON):
			_armed_slot = index
			_armed_action = StringName("p1_card_%d" % (index + 1))
			_slot_chosen = InputMap.has_action(_armed_action)
			return


## The first live UnitActor found by WALKING THE TREE rather than by reading the runner's bookkeeping
## array — the test_summon_actor_live.gd reason: a runner that appended to its array and forgot to
## add_child would otherwise report success with nothing on screen.
func _first_unit_actor() -> UnitActor:
	return _find_unit_actor(root)


func _find_unit_actor(node: Node) -> UnitActor:
	if node is UnitActor and not node.is_queued_for_deletion():
		return node
	for child in node.get_children():
		var found := _find_unit_actor(child)
		if found != null:
			return found
	return null
