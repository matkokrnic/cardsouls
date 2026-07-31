extends SceneTree

## Story 1-7 (AC 6, integration half): the live contact pipeline in the REAL scene,
## end to end: p1 attack press -> KeyboardController -> advance -> active window ->
## runner step-2 direct query -> push_contact -> step-4 resolution -> queued hit_landed
## drained by the runner -> observed via match_runner.connect_hit_landed. Everything is
## observed through public seams (connect_*, EventBus) and signal payloads — never
## state, never runner privates.
##
## Phases:
##  1. KILL — P1 teleported into reach, auto-swings at the P2 dummy until it dies.
##     Pins: exactly ONE fact/hit per swing (hits == swings == ceil(max_hp / damage)),
##     each hit chips exactly the authored damage, the FIRST hit lands exactly
##     windup_ticks + 1 frames after the ATTACKING transition (the +1 IS the F1
##     one-tick gather lag, asserted as an expectation per the story), death raises
##     round_ended on the EventBus (the runner relay, AC 4.3) with loser_index 1.
##  2. RESET — the p1_debug_reset action (Input Map -> KeyboardController -> intent ->
##     advance) revives the round; one more swing lands at FULL restored HP.
##  3. AIM (review R1) — the hitbox actually FOLLOWS facing: still in reach, P1 turns
##     away (a movement press sets world-space facing, then releases) and a full swing
##     produces ZERO facts; turned back toward P2, the next swing lands. This is the
##     live pin that the hitbox yaw consumes state facing.
##  4. FAR — P1 teleported out of reach swings at nothing: zero facts, zero hits
##     (and every in-reach swing already exercised the self-overlap filter: the
##     attacker's own hurtbox is inside the hitbox's mask/reach every active tick —
##     an unfiltered gather would trip push_contact's strict invariant).
##
## Expected values are DERIVED from the authored balance .tres, so tuning reschedules
## the test instead of breaking it.
##
## Run: godot --headless --path . --script res://test/integration/test_contact_pipeline.gd

const DEADLINE := 5000

var _runner: Node3D
var _p1_actor: CharacterBody3D
var _p2_actor: CharacterBody3D
var _bus: Node

var _windup_ticks := 0
var _swing_ticks := 0
var _damage := 0.0
var _max_hp := 0.0
var _kill_hits := 0
## Stamina-cost corrective pass (E3-RG/R2): worst-case ticks for a drained hero to afford
## one more swing — the post-spend regen delay plus the ticks to regenerate one attack's
## cost. DERIVED from the .tres like every other expectation here, so tuning the cost or the
## regen rate reschedules this test instead of breaking it.
var _attack_refill_ticks := 0

var _frames := 0
var _phase := "kill"
var _p1_state := -1
var _swings := 0
var _first_attacking_frame := -1
var _hits: Array = []            # [frame, attacker, target, damage, target_hp]
var _round_losers: Array = []    # loser_index per EventBus round_ended
var _round_end_frame := -1
var _press_at := -1
var _release_at := -1
var _reset_at := -1
var _phase_pressed := false
var _phase_deadline := -1
var _move_action := &""
var _move_release_at := -1
var _aim_moved := false
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	var config: BalanceConfig = load("res://data/balance/balance_config.tres")
	var ticks := BalanceTicks.from_config(config)
	_windup_ticks = ticks.attack_windup_ticks
	_swing_ticks = ticks.attack_windup_ticks + ticks.attack_active_ticks + ticks.attack_recovery_ticks
	_max_hp = config.max_hp
	_damage = config.attack_damage_percent_of_max_hp / 100.0 * config.max_hp
	_kill_hits = int(ceil(config.max_hp / _damage))
	var regen_per_tick := config.stamina_regen_per_second / 60.0
	var regen_ticks: float = 0.0 if regen_per_tick <= 0.0 else ceil(config.attack_stamina_cost / regen_per_tick)
	_attack_refill_ticks = ticks.stamina_regen_delay_ticks + int(regen_ticks)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)


func _finish() -> void:
	print("contact pipeline: swings=%d hits=%d kill_hits_expected=%d rounds=%s first_atk=%d first_hit=%s frames=%d" % [
		_swings, _hits.size(), _kill_hits, _round_losers, _first_attacking_frame,
		str(_hits[0][0]) if not _hits.is_empty() else "-", _frames])
	for f in _failures:
		print("FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames >= DEADLINE:
		_failures.append("deadline reached in phase %s" % _phase)
		_finish()
		return false
	if _frames == 1:
		_runner = root.get_node("Main")
		_p1_actor = root.get_node("Main/P1Hero")
		_p2_actor = root.get_node("Main/P2Hero")
		_bus = root.get_node("/root/EventBus")
		# Into melee reach: P1 1.2 units behind P2 along +Z, default facing (0,1) -> +Z.
		_p1_actor.position = _p2_actor.position + Vector3(0, 0, -1.2)
		_runner.connect_hero_action_state_changed(0,
			func(_prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
				_p1_state = int(cur)
				if cur == HeroState.ActionState.ATTACKING:
					_swings += 1
					if _first_attacking_frame == -1:
						_first_attacking_frame = _frames)
		_runner.connect_hit_landed(
			func(attacker: int, target: int, damage: float, target_hp: float) -> void:
				_hits.append([_frames, attacker, target, damage, target_hp]))
		_bus.round_ended.connect(func(loser_index: int) -> void:
			_round_losers.append(loser_index)
			_round_end_frame = _frames)
		_press_at = 5
		return false

	if _press_at != -1 and _frames == _press_at:
		Input.action_press(&"p1_attack")
		_release_at = _frames + 2
		_press_at = -1
	if _release_at != -1 and _frames == _release_at:
		Input.action_release(&"p1_attack")
		_release_at = -1
	if _reset_at != -1 and _frames == _reset_at:
		Input.action_press(&"p1_debug_reset")
	if _reset_at != -1 and _frames == _reset_at + 2:
		Input.action_release(&"p1_debug_reset")
		_reset_at = -1
	if _move_release_at != -1 and _frames == _move_release_at:
		Input.action_release(_move_action)
		_move_release_at = -1
		_press_at = _frames + 2  # attack once the facing turn has taken effect
		_phase_pressed = true
		_phase_deadline = _frames + 2 + _swing_ticks + 60

	match _phase:
		"kill":
			# Auto-swing: re-press whenever P1 has returned to IDLE and no press is pending.
			if _round_losers.is_empty():
				if _p1_state == int(HeroState.ActionState.IDLE) and _press_at == -1 and _release_at == -1:
					_press_at = _frames + 2
			else:
				# Death observed through the EventBus relay — evaluate the kill phase.
				_check(_round_losers == [1], "EventBus round_ended relayed with loser_index 1, got %s" % str(_round_losers))
				_check(_hits.size() == _kill_hits,
					"hits to kill == ceil(max_hp/damage) == %d, got %d" % [_kill_hits, _hits.size()])
				_check(_swings == _hits.size(),
					"exactly ONE hit per swing (swings %d == hits %d)" % [_swings, _hits.size()])
				if not _hits.is_empty():
					var first: Array = _hits[0]
					_check(int(first[0]) == _first_attacking_frame + _windup_ticks + 1,
						"first hit frame %d == ATTACKING frame %d + windup %d + 1 (the F1 one-tick gather lag)" % [
							int(first[0]), _first_attacking_frame, _windup_ticks])
					for i in range(_hits.size()):
						var h: Array = _hits[i]
						_check(int(h[1]) == 0 and int(h[2]) == 1, "hit %d: P1 -> P2" % i)
						_check(absf(float(h[3]) - _damage) < 0.001, "hit %d: authored damage %s" % [i, _damage])
						var expected_hp: float = maxf(_max_hp - _damage * (i + 1), 0.0)
						_check(absf(float(h[4]) - expected_hp) < 0.001,
							"hit %d: target_hp stepped to %s" % [i, expected_hp])
					_check(absf(float(_hits[_hits.size() - 1][4])) < 0.001, "killing hit leaves 0.0 HP")
				_phase = "reset"
				_reset_at = _frames + 5
				_phase_pressed = false
				# + _attack_refill_ticks: the post-reset swing must now wait out the
				# stamina the kill phase spent (E3-RG/R2).
				_phase_deadline = _frames + 3 * _swing_ticks + 120 + _attack_refill_ticks
		"reset":
			# One more swing AFTER the live reset — pressed once P1 is back to IDLE so the
			# press can never fall into a non-cancellable window and be dropped.
			# Stamina-cost corrective pass (E3-RG/R2): RE-PRESSES until the swing actually
			# fires, the same auto-swing shape the kill phase above already uses. A single
			# press is no longer enough — the kill phase now ends with P1's stamina drained
			# (every swing costs attack_stamina_cost, and the 1-7/D-1 debug reset is
			# ROUND-scoped: HP and the round latch only, pools deliberately untouched), so
			# the first press lands on an empty bar and is REJECTED. This cannot livelock:
			# a refused spend never restarts the delay window, so regen keeps running and
			# the bar reaches the cost within _attack_refill_ticks.
			if _reset_at == -1 and _p1_state == int(HeroState.ActionState.IDLE) and _press_at == -1 and _release_at == -1:
				_press_at = _frames + 2
				_phase_pressed = true
			if _hits.size() == _kill_hits + 1:
				var h: Array = _hits[_hits.size() - 1]
				_check(absf(float(h[4]) - (_max_hp - _damage)) < 0.001,
					"post-reset hit lands at FULL restored HP (target_hp %s, expected %s)" % [h[4], _max_hp - _damage])
				_phase = "aim_away"
				_phase_pressed = false
				_aim_moved = false
				_phase_deadline = _frames + 3 * _swing_ticks + 240
			elif _frames >= _phase_deadline:
				_failures.append("post-reset swing never landed (reset did not restore the round live)")
				_finish()
		"aim_away":
			# Review R1: still IN REACH, turn facing AWAY (move_up -> world -Z) via a real
			# movement press, then swing — the yawed hitbox must find nothing.
			if not _aim_moved and _p1_state == int(HeroState.ActionState.IDLE) and _press_at == -1 and _release_at == -1:
				_move_action = &"p1_move_up"
				Input.action_press(_move_action)
				_move_release_at = _frames + 2
				_aim_moved = true
			if _phase_pressed and _frames >= _phase_deadline:
				_check(_hits.size() == _kill_hits + 1,
					"facing-away swing IN REACH produced ZERO facts and zero hits (hitbox follows facing)")
				_phase = "aim_back"
				_phase_pressed = false
				_aim_moved = false
				_phase_deadline = _frames + 3 * _swing_ticks + 240
		"aim_back":
			# Facing turned back toward P2 (move_down -> world +Z): the next swing must land.
			if not _aim_moved and _p1_state == int(HeroState.ActionState.IDLE) and _press_at == -1 and _release_at == -1:
				_move_action = &"p1_move_down"
				Input.action_press(_move_action)
				_move_release_at = _frames + 2
				_aim_moved = true
			if _hits.size() == _kill_hits + 2:
				var hb: Array = _hits[_hits.size() - 1]
				_check(int(hb[1]) == 0 and int(hb[2]) == 1, "aim-back hit is P1 -> P2")
				_phase = "far"
				_p1_actor.position = _p2_actor.position + Vector3(0, 0, -15.0)
				_phase_pressed = false
				_phase_deadline = _frames + 3 * _swing_ticks + 120
			elif _phase_pressed and _frames >= _phase_deadline:
				_failures.append("aim-back swing never landed (facing did not return toward the target)")
				_finish()
		"far":
			# A full swing at nothing: pressed from IDLE, evaluated after the swing had
			# ample time to complete.
			if not _phase_pressed and _p1_state == int(HeroState.ActionState.IDLE) and _press_at == -1 and _release_at == -1:
				_press_at = _frames + 2
				_phase_pressed = true
				_phase_deadline = _frames + 2 + _swing_ticks + 60
			if _phase_pressed and _frames >= _phase_deadline:
				_check(_hits.size() == _kill_hits + 2, "out-of-reach swing produced ZERO facts and zero hits")
				_finish()
	return false
