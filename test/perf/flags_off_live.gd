extends SceneTree

## Story 4-5 (AC 12): E4's SECOND exit criterion -- "flags toggle cleanly" -- as a live run.
##
## The story allows an existing test to discharge this by citation instead. There is none: the
## nearest is `test/state/test_targeting_service.gd`, which proves the EVALUATOR answers
## `REASON_MINIONS_FLAG_CLOSED` with the flag closed. That is a pure-function fact about a static
## evaluator; it says nothing about whether the real scene comes up, ticks, and plays a clean match
## with the layer switched off, which is what the exit criterion claims.
##
## Run (real renderer, like its sibling harness -- a clean match is partly a rendering claim):
##   /c/Godot/godot_console.exe --path . --script res://test/perf/flags_off_live.gd
##
## NON-VACUOUS IN BOTH DIRECTIONS, which is why it reads the flags rather than assuming them: it
## derives its expectation from the FeatureFlags the service actually loaded. With `minions` and
## `totems` OFF it requires that repeated summon casts put NOTHING on either board -- a run that
## silently summoned anyway would fail here rather than pass quietly. With them ON it requires the
## opposite, so the file cannot pass by doing nothing whichever way the shipped `.tres` is set.
##
## WHAT "CLEAN" MEANS HERE, stated before the run rather than after: the scene instantiates, the
## runner ticks for the whole window, both heroes stay alive and the match never enters round-over,
## the cast path returns REFUSALS rather than throwing, and the process exits 0. Engine-level
## errors are not caught in-process -- the caller greps the run's output for `SCRIPT ERROR` /
## `ERROR:`, exactly as `test/run_all.sh` does for every other live test.

const WARMUP_FRAMES := 20
const RUN_FRAMES := 420
## Three full cast cycles per side, spaced out -- one refusal could be a fluke of a hand with no
## summon card in it, and the claim is about the LAYER being off, not about one press.
const CAST_STARTS := [40, 140, 240, 340]
const CAST_CYCLE_LENGTH := 13

var _frames := 0
var _runner: Node
var _state: MatchState
var _db: Node
var _cast_t: Array[int] = [-1, -1]
var _cast_action: Array[StringName] = [&"", &""]

var _minions_on := false
var _totems_on := false
var _max_units := 0
var _casts := 0
var _round_over_seen := false
var _hero_died := false


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	var runner := scene.instantiate()
	# Story 7-4 (`7-4/R15`): this test reads or acts on the DEALT hand, so it fixes the deal at the seed the
	# runner shipped as a constant before 7-4 -- set BEFORE the runner enters the tree.
	runner.seed_override = 12345
	root.add_child(runner)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_db = root.get_node_or_null("/root/CardDatabase")
		if _runner == null or _state == null or _db == null:
			print("flags_off_live: missing runner=%s state=%s db=%s" % [_runner, _state, _db])
			print("RESULT: FAIL")
			quit(1)
			return true
		_minions_on = _state.flags.minions
		_totems_on = _state.flags.totems
		return false

	# The economy is not the subject -- a refused cast must be refused by the FLAG, not by a mana
	# shortage that would make the whole run vacuous.
	_state.p1.mana.add(9999.0)
	_state.p2.mana.add(9999.0)

	if _frames > WARMUP_FRAMES:
		_max_units = maxi(_max_units, _state.p1.units.size() + _state.p2.units.size())
		if bool(_state.to_snapshot().get("round_over", false)):
			_round_over_seen = true
		if not _state.p1.hero.is_alive() or not _state.p2.hero.is_alive():
			_hero_died = true
		_drive_casts()

	if _frames >= RUN_FRAMES:
		_report()
		return true
	return false


func _drive_casts() -> void:
	for slot in 2:
		if _cast_t[slot] < 0:
			if CAST_STARTS.has(_frames):
				_begin_cast(slot)
			continue
		_cast_t[slot] += 1
		var t := _cast_t[slot]
		var p := "p1" if slot == 0 else "p2"
		if t == 1:
			Input.action_press(_cast_action[slot])
		elif t == 3:
			Input.action_release(_cast_action[slot])
		elif t == 6:
			Input.action_press(StringName("%s_cast_confirm" % p))
		elif t == 8:
			Input.action_release(StringName("%s_cast_confirm" % p))
		elif t == 10:
			Input.action_release(StringName("%s_cast_mode" % p))
		elif t >= CAST_CYCLE_LENGTH:
			_cast_t[slot] = -1


func _begin_cast(slot: int) -> void:
	var index := _first_summoning_slot(slot)
	if index < 0:
		return
	var p := "p1" if slot == 0 else "p2"
	var action := StringName("%s_card_%d" % [p, index + 1])
	if not InputMap.has_action(action):
		return
	_cast_action[slot] = action
	_cast_t[slot] = 0
	_casts += 1
	Input.action_press(StringName("%s_cast_mode" % p))


func _first_summoning_slot(slot: int) -> int:
	var player: PlayerState = _state.p1 if slot == 0 else _state.p2
	var hand: Array = player.hand.to_array()
	for index in hand.size():
		if player.hand.is_slot_empty(index):
			continue
		var card := _db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		if String(card.basic_effect.effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON):
			return index
	return -1


func _report() -> void:
	var layers_off := not _minions_on and not _totems_on
	# The expectation is DERIVED from the flags the service loaded, not assumed -- see the header.
	var population_ok := (_max_units == 0) if layers_off else (_max_units > 0)
	var clean := _casts > 0 and not _round_over_seen and not _hero_died and population_ok
	print("flags_off_live: minions=%s totems=%s casts=%d max_unit_records=%d round_over=%s hero_died=%s"
		% [_minions_on, _totems_on, _casts, _max_units, _round_over_seen, _hero_died])
	print("flags_off_live: expectation for these flags = %s"
		% ("NO unit ever reaches a board" if layers_off else "units DO reach a board"))
	print("RESULT: %s" % ("PASS" if clean else "FAIL"))
	quit(0 if clean else 1)
