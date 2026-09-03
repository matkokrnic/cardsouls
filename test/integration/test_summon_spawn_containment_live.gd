extends SceneTree

## Story 5-0d fix pass (F1, review-driven scope widening): A SUMMON CAST NEAR A WALL LANDS INSIDE
## THE RING, NOT INSIDE OR PAST IT.
##
## THE GAP THIS PINS (the story's own corrected AC 6 note): the rear-arc search's ring-0 candidate
## IS the base spot -- `hero_position + away * SPAWN_BEHIND_DISTANCE` (2.5 units) -- and with no
## occupants nearby it is accepted immediately, no crowding required. A hero standing within 2.5
## units of a wall (measured along the away-from-opponent axis) therefore had its very first
## candidate land at or past the wall, unguarded by anything this story's ring wall does (the spawn
## path sets `global_position` directly, bypassing `move_and_slide()` entirely -- AC 6/Non-Goals).
## `match_runner._spawn_missing_unit_actors` now clamps the accepted candidate back inside the ring
## before it is used, so this is proven at the runner boundary, the same boundary the gap lived at.
##
## PATTERN: `test_unit_spawn_placement_live.gd`'s real Input Map -> KeyboardController -> runner
## chain (arm-then-confirm), applied to a hero PINNED AT THE WEST WALL rather than left at its
## authored spawn.
##
## Run: godot --headless --path . --script res://test/integration/test_summon_spawn_containment_live.gd

## 1 unit off the West wall's inner face (`x = -20`), well inside `SPAWN_BEHIND_DISTANCE` (2.5) of
## it -- the ring-0 base spot for a hero here lands at `x = -19 - 2.5 = -21.5`, inside the wall's
## own collision volume (`x` in `[-21, -20]`), the exact band the story's corrected AC 6 note names.
const HERO_PINNED_AT := Vector3(-19.0, 1.0, 0.0)

const ARM_FRAME := 6
const CONFIRM_FRAME := 12
const RELEASE_FRAME := 16
const REPORT_FRAME := 40

var _frames := 0
var _runner: Node
var _state: MatchState
var _armed_action := &""
var _slot_chosen := false
var _detail := ""

var _spawn: Vector3 = Vector3.INF
var _contained := false


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
	if _frames == 2:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		if not _state.flags.minions:
			return _fail("the authored FeatureFlags has minions OFF -- this test cannot summon")
		var p1_hero: Node3D = _runner._p1_hero
		p1_hero.global_position = HERO_PINNED_AT
	if _frames == 3:
		_slot_chosen = _choose_a_summoning_slot()
		if not _slot_chosen:
			return _fail("no summoning card in the dealt hand: %s" % str(_state.p1.hand.to_array()))

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
	if _frames == RELEASE_FRAME:
		Input.action_release(&"p1_cast_mode")

	# Sampled the frame the actor first exists, before it has walked anywhere -- same discipline as
	# test_unit_spawn_placement_live.gd, so a later corrective walk cannot mask an out-of-ring spawn.
	if _spawn == Vector3.INF and _live_actors() >= 1:
		_spawn = _actor_at(0).global_position
		var bound: float = _runner.SPAWN_CONTAINMENT_BOUND
		_contained = absf(_spawn.x) <= bound + 0.01 and absf(_spawn.z) <= bound + 0.01
		if not _contained:
			_detail += " out_of_ring(spawn=%s bound=%.3f);" % [str(_spawn), bound]

	if _frames == REPORT_FRAME:
		return _report()
	return false


func _live_actors() -> int:
	var total := 0
	for unit: Node in _runner._unit_actors[0]:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			total += 1
	return total


func _actor_at(index: int) -> Node3D:
	var actors: Array = _runner._unit_actors[0]
	if index >= actors.size():
		return null
	var unit: Node = actors[index]
	return unit as Node3D if is_instance_valid(unit) else null


func _report() -> bool:
	var ok := _slot_chosen and _spawn != Vector3.INF and _contained
	if _spawn == Vector3.INF:
		_detail += " never_spawned(board=%d actors=%d);" % [_state.p1.units.size(), _live_actors()]
	print("summon_spawn_containment_live: hero=%s spawn=%s contained=%s%s" % [
		str(HERO_PINNED_AT), str(_spawn), _contained, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	quit(1)
	return false


## The first dealt slot whose authored card carries a `summon_*` effect -- verbatim from
## test_unit_spawn_placement_live.gd.
func _choose_a_summoning_slot() -> bool:
	var db := root.get_node_or_null("/root/CardDatabase")
	if db == null:
		return false
	var hand := _state.p1.hand.to_array()
	for index in hand.size():
		if _state.p1.hand.is_slot_empty(index):
			continue
		var card := db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		var effect_id: StringName = card.basic_effect.effect_id
		var is_summon := String(effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON)
		var is_totem := CardEffectResolver.SUMMON_KINDS.has(effect_id)
		if is_summon and not is_totem:
			var action := StringName("p1_card_%d" % (index + 1))
			if not InputMap.has_action(action):
				return false
			_armed_action = action
			return true
	return false
