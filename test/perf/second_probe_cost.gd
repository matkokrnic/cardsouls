extends SceneTree

## Story 7-3 (T1, the Performance Rule in project-context.md): WHAT THE SECOND REACH PROBE COSTS.
##
## TOOLING, NOT A TEST -- no pass/fail, and `test/run_all.sh` (which globs
## `test/integration/test_*.gd`) never picks it up. `perf_20_units_live.gd`'s posture, but HEADLESS:
## what is measured is script time inside one runner function, not a frame.
##
## A hound authors two attacks, so on every probing tick `MatchRunner._gather_unit_facts` measures
## its target against TWO ranges where a zombie's is measured against one (`7-3/R20`). This puts
## twenty hounds on P1's board, lets them acquire their target, and then times EXACTLY THE WORK THE
## SECOND PROBE ADDS for those twenty -- the second attack record's lookup and one
## `_push_reach_probe` call each -- on the worst tick, the one in every
## `minion_retarget_interval_ticks` on which every unit probes. The whole of `_gather_unit_facts`
## for the same twenty is timed beside it for scale.
##
## A FIRST VERSION COMPARED TWENTY HOUNDS WITH TWENTY ZOMBIES and is not used: the zombies' gather
## came out DEARER (620 usec against 398), because that function also queries hitboxes for units
## mid-swing and the two sides were in different phases. The difference of two whole-function
## timings measures the fight, not the probe.
##
## Run: godot --headless --path . --script res://test/perf/second_probe_cost.gd

const UNITS := 20
const SETTLE_FRAME := 40
const CALLS := 2000

var _frames := 0
var _runner: Node
var _state: MatchState


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	main.seed_override = 12345
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state
		return false
	if _frames == 2:
		var hound := _state.balance.kind_index_of(&"hellhound")
		for i in UNITS:
			_state.p1.units.add(_state.balance.kind_at(hound).max_hp, hound)
		return false
	if _frames < SETTLE_FRAME:
		return false
	var interval: int = _state.balance_ticks.minion_retarget_interval_ticks
	# Measured FIRST: every gather appends its facts to the recorder, so a later measurement runs against a
	# recorder that has grown by thousands of rows (the first version of this order read 2047 usec).
	var fresh_usec := _time_gather_fresh_only()
	var probe_usec := _time_second_probes()
	var gather_usec := _time_gather()
	print("second_probe_cost: %d hounds, %d repetitions, probe throttle forced open" % [UNITS, CALLS])
	print("  the second probe alone, all %d hounds: %.2f usec per probing tick = %.3f usec per hound"
			% [UNITS, probe_usec, probe_usec / UNITS])
	print("  the whole gather pass for the same hounds: %.2f usec per probing tick" % gather_usec)
	print("  amortized over the %d-tick probe cadence: %.3f usec per frame (frame budget 16667 usec)"
			% [interval, probe_usec / interval])
	# 7-3 review fix (F2, ruled): leading kinds probe on EVERY tick they could wind up (feel pass 2), the
	# throttle notwithstanding. The worst case is every hound engaging, so every hound pushes both probes
	# every tick: `_probe_counter` is left on a non-probing tick, so only the fresh-aim rule opens the gate.
	print("  EVERY-TICK RATE (fresh aim, throttle closed, all %d hounds engaging): the whole gather pass %.2f usec per tick = %.3f usec per hound"
			% [UNITS, fresh_usec, fresh_usec / UNITS])
	print("  that is %.2f%% of the 16667 usec frame budget, against %.3f%% amortized at the throttled rate"
			% [fresh_usec / 166.67, probe_usec / interval / 166.67])
	var board := _state.p1.units
	var engaging := 0
	for index in board.size():
		if board.is_engaging_at(index) and board.target_slot_at(index) != TargetingService.NO_TARGET_SLOT:
			engaging += 1
	print("  hounds engaging with a target at the measurement: %d of %d" % [engaging, board.size()])
	_runner.free()
	quit(0)
	return false


## Mean microseconds of the second probe's own work for every hound on P1's board, on one tick.
func _time_second_probes() -> float:
	var player := _state.p1
	var actors: Array = _runner._unit_actors[0]
	var start := Time.get_ticks_usec()
	for i in CALLS:
		for index: int in actors.size():
			var attacker_address: Array[int] = [0, index]
			var second: UnitAttackProfile = _runner._unit_second_attack_profile(_state.balance, player, index)
			if second != null:
				_runner._push_reach_probe(0, player, index, actors[index] as UnitActor, attacker_address,
						player.units.attack_count_at(index), second, MatchState.CONTACT_REACH_PROBE_SECOND)
	return float(Time.get_ticks_usec() - start) / CALLS


## Mean microseconds of one whole `_gather_unit_facts` call for P1 on a probing tick.
func _time_gather() -> float:
	_runner._probe_counter = 0
	var start := Time.get_ticks_usec()
	for i in CALLS:
		_runner._gather_unit_facts(0, _state.p1)
	return float(Time.get_ticks_usec() - start) / CALLS


## Mean microseconds of one whole `_gather_unit_facts` call for P1 on a tick the throttle keeps CLOSED:
## only a leading kind's fresh-aim rule pushes probes (both bands), so this is the every-tick cost.
func _time_gather_fresh_only() -> float:
	var interval: int = _state.balance_ticks.minion_retarget_interval_ticks
	_runner._probe_counter = 1 % interval
	# A tenth of the repetitions: each call appends ~40 rows to the recorder, and a recorder grown by
	# tens of thousands of rows makes every later call dearer than a real tick's.
	var calls := CALLS / 10
	var start := Time.get_ticks_usec()
	for i in calls:
		_runner._gather_unit_facts(0, _state.p1)
	return float(Time.get_ticks_usec() - start) / calls
