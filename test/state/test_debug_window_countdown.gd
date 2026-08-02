extends TestCase

## Story 3-0b (AC 2): the read-only DEBUG window-countdown accessor on MatchState —
## MatchState.debug_window_ticks_remaining(). Per slot, the remaining ticks of the action
## windows that are currently RUNNING, as COMPUTED PLAIN INTEGERS derived from
## TimingWindow.remaining_ticks().
##
## The AC's two standing obligations are asserted here, not just described:
##   - PLAIN VALUES, NO HANDLE. Every key is a StringName and every value an int; nothing in
##     the payload is an Object, and the returned Dictionary is a fresh value each call, so a
##     consumer cannot mutate state through it (test_countdown_payload_is_a_value_not_a_handle).
##   - THE SNAPSHOT NEVER LEARNS THE INSTRUMENT EXISTS. to_snapshot()'s key set is pinned
##     top-level and per-hero, and the accessor is proven not to mutate the snapshot at all —
##     the replay contract is untouched (test_snapshot_shape_is_untouched_by_the_instrument).
##
## Window durations below are authored in TICKS (n/60.0) so the expected countdowns are read
## straight off the config: windup 3, active 4, recovery 6, chain 5, deflect 4, iframe 2, roll 5.

const SEED := 4242
const MAX_HP := 100.0
const MOVE_SPEED := 5.0
const MAX_STAMINA := 100.0
const MAX_MANA := 50.0


func test_countdown_is_empty_for_both_slots_before_any_action() -> void:
	var ms := _make_match()
	_advance(ms, [], [])
	var payload := ms.debug_window_ticks_remaining()
	assert_eq(payload.size(), 2, "one entry per slot, P1 then P2")
	assert_eq(payload[0], {}, "an idle hero has no running window")
	assert_eq(payload[1], {}, "an idle hero has no running window")


func test_countdown_reports_the_running_attack_window_per_slot() -> void:
	var ms := _make_match()
	_advance(ms, [&"attack"], [])
	var payload := ms.debug_window_ticks_remaining()
	assert_eq(payload[0], {&"windup": 3}, "P1 attacked: windup running with its full 3 ticks left")
	assert_eq(payload[1], {}, "P2 did nothing — its slot stays empty (the payload is PER SLOT)")


func test_countdown_decrements_one_tick_at_a_time_and_follows_the_phase() -> void:
	var ms := _make_match()
	_advance(ms, [&"attack"], [])
	var readings: Array[Dictionary] = [ms.debug_window_ticks_remaining()[0]]
	for _i in 4:
		_advance(ms, [], [])
		readings.append(ms.debug_window_ticks_remaining()[0])
	assert_eq(readings[0], {&"windup": 3}, "entry tick: 3 ticks of windup remain")
	assert_eq(readings[1], {&"windup": 2}, "one tick later: 2")
	assert_eq(readings[2], {&"windup": 1}, "one tick later: 1")
	assert_eq(readings[3], {&"active": 4}, "windup closed; step 3 opened active with 4 left")
	assert_eq(readings[4], {&"active": 3}, "active counts down the same way")


func test_countdown_reports_every_running_window_not_just_one() -> void:
	var ms := _make_match()
	# P1 rolls (roll_duration AND roll_iframe open together); P2 blocks (deflect window).
	_advance(ms, [&"roll"], [&"block"])
	var payload := ms.debug_window_ticks_remaining()
	assert_eq(payload[0], {&"iframe": 2, &"roll": 5}, "both roll windows are reported")
	assert_eq(payload[1], {&"deflect": 4}, "the blocker's deflect window is reported")


func test_countdown_values_are_plain_integers_and_carry_no_object() -> void:
	var ms := _make_match()
	_advance(ms, [&"attack"], [&"block"])
	var payload := ms.debug_window_ticks_remaining()
	var checked := 0
	for slot: int in 2:
		var windows: Dictionary = payload[slot]
		assert_false(windows.is_empty(), "slot %d must have a running window for this to bite" % slot)
		for key: Variant in windows:
			assert_eq(typeof(key), TYPE_STRING_NAME, "window names are plain StringNames")
			assert_eq(typeof(windows[key]), TYPE_INT, "remaining ticks are plain ints")
			assert_false(windows[key] is Object, "no object handle rides the payload")
			checked += 1
	assert_true(checked >= 2, "at least one window per slot was actually inspected")


func test_countdown_payload_is_a_value_not_a_handle() -> void:
	var ms := _make_match()
	_advance(ms, [&"attack"], [])
	var first := ms.debug_window_ticks_remaining()
	first[0][&"windup"] = 999
	first[0][&"injected"] = 1
	var second := ms.debug_window_ticks_remaining()
	assert_eq(second[0], {&"windup": 3},
		"mutating the returned payload cannot reach state — a fresh value is built per call")


func test_snapshot_shape_is_untouched_by_the_instrument() -> void:
	var ms := _make_match()
	_advance(ms, [&"attack"], [&"block"])
	var before := CanonicalHash.of(ms.to_snapshot())
	var payload := ms.debug_window_ticks_remaining()
	assert_false(payload.is_empty(), "the accessor actually ran")
	assert_eq(CanonicalHash.of(ms.to_snapshot()), before,
		"a READ-ONLY accessor must not move the snapshot hash")
	var top: Array = ms.to_snapshot().keys()
	top.sort()
	assert_eq(top, ["p1", "p2", "pitch", "rng_state", "round_over", "tick"],
		"to_snapshot() gains NO instrument key — the replay contract never learns it exists")
	var hero: Array = ms.to_snapshot()["p1"]["hero"].keys()
	hero.sort()
	assert_eq(hero, ["action_state", "active", "chain", "chain_index", "deflect", "facing", "hp",
			"max_hp", "move_speed", "recovery", "roll_direction", "roll_duration", "roll_iframe",
			"stun", "swing_dedupe", "velocity", "windup"],
		"the hero snapshot is unchanged — the countdown is instrumentation, not state")


func _make_match() -> MatchState:
	var ms := MatchState.new(SEED, MAX_HP, MOVE_SPEED, MAX_STAMINA, MAX_MANA)
	ms.apply_balance(_config())
	ms.drain_signals()
	return ms


## Durations authored in TICKS (n/60.0) so every expected countdown above is read off this
## config directly. Costs are low enough that no press in this file is refused for stamina.
func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.move_speed = MOVE_SPEED
	c.max_stamina = MAX_STAMINA
	c.stamina_regen_per_second = 0.0
	c.stamina_regen_delay_seconds = 1.0 / 60.0
	c.roll_stamina_cost = 1.0
	c.attack_stamina_cost = 1.0
	c.deflect_stamina_cost = 1.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 10.0
	c.attack_windup_move_speed_multiplier = 0.0
	c.attack_active_move_speed_multiplier = 0.0
	c.attack_recovery_move_speed_multiplier = 0.0
	c.melee_hit_mana = 5.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.block_damage_multiplier = 0.25
	c.block_facing_arc_degrees = 180.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	c.roll_distance = 3.0
	return c


func _advance(ms: MatchState, p1_press: Array, p2_press: Array) -> void:
	var intents: Array[InputIntent] = [_intent(p1_press), _intent(p2_press)]
	ms.advance(intents)
	ms.drain_signals()


## A just-pressed key is also held that tick (KeyboardController semantics).
func _intent(pressed: Array) -> InputIntent:
	var i := InputIntent.new()
	for k: StringName in pressed:
		i.pressed[k] = true
		i.held[k] = true
	return i
