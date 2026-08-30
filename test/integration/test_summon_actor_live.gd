extends SceneTree

## Story 4-1 (AC 7 / AC 8): THE GREY-BOX UNIT, DRIVEN THROUGH THE REAL RUNNER — the half of this
## story the headless state suite structurally cannot see.
##
## test_card_effect_resolution.gd proves the STATE contract: a resolved `summon_*` cast appends a
## unit record, a reset clears the board, round end does not. All of that is true of a `UnitBoard`
## with no actor anywhere near it, which is precisely the failure mode this file exists to catch —
## the story's player-facing claim is that something VISIBLE appears, and a board count nobody
## renders would satisfy every state test while the screen stayed empty.
##
## So this drives the whole chain: real Input Map presses -> KeyboardController -> the runner's
## single _physics_process -> MatchState.advance() -> the resolver -> UnitBoard -> the runner's
## spawn step -> a real UnitActor in the real scene tree. Nothing is hand-built, and the actor is
## counted by walking the tree rather than by asking the runner what it thinks it spawned.
##
## THE SLOT IS CHOSEN, NOT ASSUMED. Six of the nine authored cards summon and three are spells, so
## a fixed slot would pass or fail on what the shuffle did. The dealt hand is read, CardDatabase is
## consulted for each id's authored effect, and the FIRST summoning slot is the one armed — which
## also makes the test state its own subject in the output line.
##
## Run: godot --headless --path . --script res://test/integration/test_summon_actor_live.gd

## Presses are HELD for several frames rather than pulsed for one, for the reason
## test_hole_vs_in_flight_live.gd records: the runner's _physics_process and this script's are two
## separate callbacks in an unspecified order, so a one-frame pulse can be released before the
## runner ever samples the just_pressed edge.
const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const CONFIRM_RELEASE_FRAME := 14
const SPAWN_CHECK_FRAME := 18
## Deliberately far from the spawn check: AC 7's claim is that the unit REMAINS after the cast
## resolves, and a unit that appeared and vanished a few frames later would pass an immediate
## assertion.
const PERSIST_CHECK_FRAME := 70
const RESET_FRAME := 74
const RESET_RELEASE_FRAME := 78
const CLEARED_CHECK_FRAME := 90

var _frames := 0
var _runner: Node
var _state: MatchState
var _armed_slot := -1
var _armed_action := &""

var _slot_chosen := false
var _spawned := false
var _persisted := false
var _board_cleared := false
var _actors_freed := false
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
		# NON-VACUITY, up front: the minion layer must actually be ON in the authored flags, or
		# every summon below degrades to REASON_MINIONS_FLAG_CLOSED and the empty board at the end
		# would "pass" a weaker test for entirely the wrong reason.
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
	# The real arm-then-confirm scheme, in the order the controller requires it: the cast-mode
	# modifier is HELD, the card key arms the slot while it is down, and cast_confirm commits.
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
		# AC 7: the record reached the board AND an actor reached the tree. Both halves asserted,
		# because either alone is the bug — a board with no actor is the invisible feature, an
		# actor with no board record is a spawn that state never authorised.
		_spawned = _state.p1.units.size() == 1 and _live_unit_actors() == 1
		if not _spawned:
			_detail += " board=%d actors=%d;" % [_state.p1.units.size(), _live_unit_actors()]
	if _frames == PERSIST_CHECK_FRAME:
		# AC 7: it REMAINS. Fifty frames after the cast resolved, with the replacement draw long
		# since delivered, the unit is still standing.
		_persisted = _state.p1.units.size() == 1 and _live_unit_actors() == 1
		if not _persisted:
			_detail += " persist_board=%d persist_actors=%d;" % [
				_state.p1.units.size(), _live_unit_actors()]
	if _frames == RESET_FRAME:
		Input.action_press(&"p1_debug_reset")
	if _frames == RESET_RELEASE_FRAME:
		Input.action_release(&"p1_debug_reset")
	if _frames == CLEARED_CHECK_FRAME:
		# AC 8: the reset cleared the board, and the runner freed the matching actors off the
		# EXISTING round_started relay. Both halves again — a board cleared while the grey boxes
		# stayed on screen is the same class of bug in the other direction.
		_board_cleared = _state.p1.units.is_empty() and _state.p2.units.is_empty()
		_actors_freed = _live_unit_actors() == 0
		if not (_board_cleared and _actors_freed):
			_detail += " cleared_board=%d/%d cleared_actors=%d;" % [
				_state.p1.units.size(), _state.p2.units.size(), _live_unit_actors()]
		var ok := _slot_chosen and _spawned and _persisted and _board_cleared and _actors_freed
		print("summon_actor_live: slot=%d spawned=%s persisted=%s board_cleared=%s actors_freed=%s%s" % [
			_armed_slot, _spawned, _persisted, _board_cleared, _actors_freed, _detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## The first dealt slot whose authored card carries a `summon_*` effect. The library is reached
## through the AUTOLOAD NODE rather than the `CardDatabase` global identifier: this file IS the
## `--script` main loop, so it is compiled before the autoloads register and the bare identifier
## does not resolve at compile time. The state layer never reads the library at all, which is why
## this lookup lives in the test rather than anywhere near src/state/.
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
			_armed_slot = index
			_armed_action = StringName("p1_card_%d" % (index + 1))
			_slot_chosen = InputMap.has_action(_armed_action)
			return


## Every live UnitActor in the scene, counted by WALKING THE TREE rather than by reading the
## runner's own bookkeeping array — a runner that appended to its array and forgot to add_child
## would otherwise report success while nothing was on screen.
func _live_unit_actors() -> int:
	return _count_unit_actors(root)


func _count_unit_actors(node: Node) -> int:
	var total := 0
	if node is UnitActor and not node.is_queued_for_deletion():
		total += 1
	for child in node.get_children():
		total += _count_unit_actors(child)
	return total
