extends TestCase

## Story 6-7 coverage: the two-gait system (walk/run), review follow-up Finding 1. Every
## `[headless-provable]` AC the Senior Developer Review found untested: walk/run speed per
## action state (AC 6, with the ROLLING/CHARGING/STUNNED carve-outs), the per-tick drain
## amount and its authored-value arrival at exact empty (AC 7/AC 9, the story's own MUST),
## the running-suppression regen disjunct (AC 8), automatic next-tick resume at `>=`
## threshold (AC 10), the attack/roll cancel+resume rule (AC 11), BLOCKING-forces-walk
## (AC 16), the regen-delay seat (AC 17), the pad `run_held` pure function (AC 4), and the
## `run_stamina_drain_per_tick` derivation (AC 2). Also covers Finding 2's regression: the
## pulse-running exploit that let a player dodge the R6 latch by releasing run on the tick
## the drain empties the pool.
##
## Test balance mirrors the `test_stamina_economy.gd` shape: readable round numbers per
## test, NOT the authored `.tres` values -- EXCEPT the one test AC 7/AC 9 word as a MUST
## (`test_authored_drain_reaches_exact_empty_and_sets_latch_same_tick`), which uses the
## authored `max_stamina = 50.0` / `run_stamina_drain_per_second = 10.0` verbatim, per the
## story's own text: "an AC proven only with in-test round numbers passes while the shipped
## build fails".


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.walk_speed = 2.5
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0          # 1.0 per tick, readable
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks, readable
	c.run_stamina_drain_per_second = 60.0       # 1.0 per tick, readable
	c.run_resume_stamina_percent = 20.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	c.roll_distance = 1.5
	return c


func _make_match(config: BalanceConfig = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(config if config != null else _config())
	ms.drain_signals()
	return ms


## A just-pressed key is also held that tick (matches KeyboardController semantics), plus an
## optional move_dir -- the test_stamina_economy.gd shape widened with the move_dir field
## test_match_state.gd's `_move_intent` carries separately.
func _intent(pressed_keys: Array = [], held_keys: Array = [], move_dir := Vector2.ZERO) -> InputIntent:
	var i := InputIntent.new()
	for k in pressed_keys:
		i.pressed[k] = true
		i.held[k] = true
	for k in held_keys:
		i.held[k] = true
	i.move_dir = move_dir
	return i


func _advance(ms: MatchState, p1_intent: InputIntent = null) -> void:
	var i1 := p1_intent if p1_intent != null else InputIntent.new()
	var intents: Array[InputIntent] = [i1, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


func _running(move_dir := Vector2(1, 0)) -> InputIntent:
	return _intent([], [&"run"], move_dir)


## ---- AC 6: walk/run per state, and the carve-outs gait never touches ---------------------

func test_walk_2_5_with_no_run_key_and_run_5_0_with_it() -> void:
	var ms := _make_match()
	_advance(ms, _intent([], [], Vector2(1, 0)))
	assert_almost_eq(ms.p1.hero.velocity.length(), 2.5, 1e-4, "AC 6: walk is the default gait")
	var ms2 := _make_match()
	_advance(ms2, _running(Vector2(1, 0)))
	assert_almost_eq(ms2.p1.hero.velocity.length(), 5.0, 1e-4, "AC 6: run key held moves at move_speed")


## Fact M1 / AC 6: STUNNED, ROLLING and CHARGING are hard-rooted or entry-locked and gait
## must never reach them, run key or not -- direct `_resolve_movement` calls, the DEAD-branch
## contract-test precedent (test_match_state.gd), since the transition table itself accepts no
## inbound edge into STUNNED/CHARGING and this pins the CONTRACT, not the entry path.
func test_stunned_rolling_charging_carve_outs_ignore_the_run_key() -> void:
	var ms := _make_match()
	var run_intent := _running(Vector2(1, 0))

	ms.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms._resolve_movement(ms.p1, run_intent, 0)
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3.ZERO),
		"STUNNED stays hard-rooted at zero regardless of the run key")

	var ms2 := _make_match()
	ms2.p1.hero.set_action_state(HeroState.ActionState.CHARGING)
	ms2.p1.charge_window.start(10)
	ms2._resolve_movement(ms2.p1, run_intent, 0)
	assert_true(ms2.p1.hero.velocity.is_equal_approx(Vector3.ZERO),
		"CHARGING (chargeup running) stays hard-rooted at zero regardless of the run key")

	var ms3 := _make_match()
	ms3.p1.hero.set_action_state(HeroState.ActionState.ROLLING)
	ms3.p1.hero.roll_direction = Vector3(1, 0, 0)
	var expected_roll_speed: float = ms3.balance.roll_distance / ms3.balance.roll_duration_seconds
	ms3._resolve_movement(ms3.p1, run_intent, 0)
	assert_almost_eq(ms3.p1.hero.velocity.length(), expected_roll_speed, 1e-4,
		"ROLLING uses the entry-locked roll speed, unaffected by the run key")
	ms3.p1.hero.roll_direction = Vector3(1, 0, 0)
	ms3._resolve_movement(ms3.p1, _intent([], [], Vector2(1, 0)), 0)  # no run key at all
	assert_almost_eq(ms3.p1.hero.velocity.length(), expected_roll_speed, 1e-4,
		"ROLLING's speed is identical with or without the run key held")


## ---- AC 7 / AC 9: the authored-value MUST test -------------------------------------------

## THE authored-value evidence AC 7's `6-7/R16` note and AC 9 both word as a MUST: in-test
## round numbers that happen to reach exact 0.0 would pass while the shipped build (whose
## `StaminaPool.add()` tolerance sticks on a ~1e-13 residual under a raw `> 0.0` reading)
## never does. `max_stamina = 50.0`, `run_stamina_drain_per_second = 10.0` are the AUTHORED
## values verbatim (`data/balance/balance_config.tres`), driven for >= 300 ticks from a full
## bar -- direct `_resolve_movement` calls, isolating the drain from `_regen_stamina` (a
## separate seat, AC 8's own test below), on the DEAD-branch direct-call precedent.
##
## MUTATION (corrected `6-7/R1`: a `> 0.0` reading for clause (5) does NOT fail this test --
## the pool's sub-epsilon residual (`1.649e-13`) still reads `is_zero_approx` true, so both
## this test's assertions pass under that mutation too, and clause (5)'s own unmutated
## `is_zero_approx` still empties correctly). The mutation this test actually kills: remove the
## post-drain latch set (`match_state.gd:3907-3921`, the same-tick half of Finding 2's fix) --
## `run_locked_out` is then false on tick 300 and the second assertion below fails.
func test_authored_drain_reaches_exact_empty_and_sets_latch_same_tick() -> void:
	var c := _config()
	c.max_stamina = 50.0
	c.run_stamina_drain_per_second = 10.0
	c.run_resume_stamina_percent = 20.0
	var ms := _make_match(c)
	var intent := _running(Vector2(1, 0))
	for i in range(300):
		ms._resolve_movement(ms.p1, intent, 0)
	assert_true(is_zero_approx(ms.p1.stamina.get_current()),
		"300 ticks of continuous running at the authored 10.0/s drain from a 50.0 max reaches"
		+ " an honest is_zero_approx empty, not a sub-epsilon residual")
	assert_true(ms.p1.hero.run_locked_out,
		"AC 9 / Finding 2 fix: the R6 latch is set on the SAME tick the drain empties the pool")


## ---- Finding 2 regression: the pulse-running exploit -------------------------------------

## Red-green evidence (recorded in Completion Notes, corrected `6-7/R2`): run against the
## pre-fix `_resolve_movement` (the drain's `spend()` call with no post-drain latch check),
## the failure was `assert_true(ms.p1.hero.run_locked_out)` at the emptying-tick check below --
## the PRE-drain latch set still fires on tick 11 (stamina exactly 0.0, still pursuing), so tick
## 12's re-hold WALKS with or without the fix and cannot distinguish the two builds. The payload
## the original exploit actually turns on is later: let the regen-delay window elapse so the bar
## holds a NON-ZERO amount still below the resume threshold, THEN re-hold run. Pre-fix that
## produced RUN (both `stamina_empty` and `run_locked_out` false); with the fix the latch set on
## the emptying tick is already held, so it WALKS. This test's tail (ticks 12-14) is the payload
## tick; see the Debug Log for the counts of the red-green run that proves it.
func test_release_run_on_the_emptying_tick_cannot_bypass_the_latch() -> void:
	var c := _config()
	c.max_stamina = 10.0
	c.run_stamina_drain_per_second = 60.0   # 1.0/tick -- exactly 10 ticks to empty
	c.run_resume_stamina_percent = 20.0     # resume threshold = 2.0
	# stamina_regen_delay_seconds stays at _config()'s default (3.0 / 60.0 -- 3 ticks), so the
	# drain spend on tick 10 restarts a 3-tick window covering ticks 10-12; regen resumes tick 13.
	var ms := _make_match(c)
	var running := _running(Vector2(1, 0))
	for i in range(10):
		_advance(ms, running)  # tick 10: drains to exactly 0.0, restarts the regen-delay window
	assert_true(is_zero_approx(ms.p1.stamina.get_current()), "setup: drained to empty on tick 10")
	assert_true(ms.p1.hero.run_locked_out,
		"the latch is already set from the emptying tick itself, before any release can dodge it")
	_advance(ms)  # tick 11: run RELEASED -- the exploit window Finding 2 named
	assert_true(ms.p1.hero.run_locked_out,
		"releasing run the tick after empty must not clear or have skipped the latch")
	_advance(ms)  # tick 12: still inside the 3-tick delay window restarted by tick 10's spend
	assert_true(is_zero_approx(ms.p1.stamina.get_current()),
		"setup: still inside the regen-delay window, no regen yet")
	_advance(ms)  # tick 13: window elapsed -- one regen tick fires
	assert_almost_eq(ms.p1.stamina.get_current(), 1.0, 1e-4,
		"setup: the payload state -- bar now holds a non-zero amount still below the 2.0 resume"
		+ " threshold, the one state the pre-drain latch set does NOT already cover")
	_advance(ms, running)  # tick 14: re-hold run at the payload tick
	assert_almost_eq(ms.p1.hero.velocity.length(), 2.5, 1e-4,
		"pulse-running exploit closed: re-holding run at a non-zero, below-threshold bar WALKS,"
		+ " never RUNS -- pre-fix this exact sequence produced RUN")


## ---- AC 8: regen suppressed while actually running; not suppressed while locked-out-walking

func test_regen_suppressed_while_running_but_not_while_locked_out_and_walking() -> void:
	var c := _config()
	c.run_stamina_drain_per_second = 6.0    # 0.1/tick -- small, so drain alone is observable
	c.stamina_regen_per_second = 60.0        # 1.0/tick
	c.stamina_regen_delay_seconds = 0.0      # isolate the AC 8 disjunct from the delay window
	var ms := _make_match(c)
	ms.p1.stamina.spend(10.0, 0)  # 40.0, headroom below max, no delay
	ms.drain_signals()
	_advance(ms, _running(Vector2(1, 0)))
	assert_almost_eq(ms.p1.stamina.get_current(), 39.9, 1e-4,
		"AC 8: actually running suppresses regen -- only the drain moved the pool")

	var ms2 := _make_match(c)
	ms2.p1.stamina.spend(10.0, 0)  # 40.0
	ms2.drain_signals()
	ms2.p1.hero.run_locked_out = true
	_advance(ms2, _running(Vector2(1, 0)))
	assert_almost_eq(ms2.p1.stamina.get_current(), 41.0, 1e-4,
		"AC 8: latched-and-walking (run held, but not actually running) does NOT suppress regen"
		+ " -- the bar must be free to cross the resume threshold")


## ---- AC 10: automatic resume next tick at >= threshold, no re-press ----------------------

func test_run_resumes_automatically_next_tick_at_or_above_threshold_no_repress() -> void:
	var c := _config()
	c.max_stamina = 50.0
	c.run_resume_stamina_percent = 20.0  # threshold = 10.0
	c.stamina_regen_per_second = 60.0     # 1.0/tick
	c.stamina_regen_delay_seconds = 0.0
	c.run_stamina_drain_per_second = 0.0  # isolate the resume mechanic from drain
	var ms := _make_match(c)
	ms.p1.stamina.spend(41.0, 0)  # 9.0, just below the 10.0 threshold
	ms.drain_signals()
	ms.p1.hero.run_locked_out = true
	var running := _running(Vector2(1, 0))
	_advance(ms, running)  # the crossing tick: regen 9 -> 10 (>= threshold)
	assert_almost_eq(ms.p1.hero.velocity.length(), 2.5, 1e-4,
		"the crossing tick's OWN movement resolves before this tick's regen clears the latch")
	assert_false(ms.p1.hero.run_locked_out,
		"the latch clears the same tick stamina reaches (>=) the threshold")
	_advance(ms, running)  # next tick: same run key held throughout, no fresh press
	assert_almost_eq(ms.p1.hero.velocity.length(), 5.0, 1e-4,
		"AC 10: run resumes automatically the tick after the crossing, no re-press required")


## ---- AC 11: attack/roll entry cancels running; resumes on the first IDLE tick after ------

func test_attack_entry_cancels_drain_and_running_resumes_the_first_idle_tick() -> void:
	var c := _config()
	c.run_stamina_drain_per_second = 60.0  # 1.0/tick, observable if drain wrongly continued
	c.stamina_regen_per_second = 0.0        # isolate: only drain may move the pool here
	var ms := _make_match(c)
	var running := _running(Vector2(1, 0))
	_advance(ms, running)  # tick 1: running, drains 1.0
	var before_attack := ms.p1.stamina.get_current()
	assert_almost_eq(before_attack, 49.0, 1e-4, "setup: draining while running")
	_advance(ms, _intent([&"attack"], [&"run"], Vector2(1, 0)))  # ATTACKING entered, run held
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ATTACKING)
	var stamina_at_entry := ms.p1.stamina.get_current()
	var resumed := false
	for i in range(30):
		_advance(ms, running)
		if ms.p1.hero.action_state == HeroState.ActionState.IDLE:
			assert_almost_eq(ms.p1.hero.velocity.length(), 5.0, 1e-4,
				"AC 11: run resumes on the first IDLE tick after the action ends, no re-press")
			resumed = true
			break
		assert_almost_eq(ms.p1.stamina.get_current(), stamina_at_entry, 1e-4,
			"AC 11(i): drain stays stopped for the whole action, run key held throughout")
	assert_true(resumed, "the attack must return to IDLE within 30 ticks at this config")


func test_roll_entry_cancels_drain_and_running_resumes_the_first_idle_tick() -> void:
	var c := _config()
	c.run_stamina_drain_per_second = 60.0
	c.stamina_regen_per_second = 0.0
	var ms := _make_match(c)
	var running := _running(Vector2(1, 0))
	_advance(ms, running)  # tick 1: running, drains 1.0
	assert_almost_eq(ms.p1.stamina.get_current(), 49.0, 1e-4, "setup: draining while running")
	_advance(ms, _intent([&"roll"], [&"run"], Vector2(1, 0)))  # ROLLING entered, run held
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING)
	var stamina_at_entry := ms.p1.stamina.get_current()
	var resumed := false
	for i in range(30):
		_advance(ms, running)
		if ms.p1.hero.action_state == HeroState.ActionState.IDLE:
			assert_almost_eq(ms.p1.hero.velocity.length(), 5.0, 1e-4,
				"AC 11: run resumes on the first IDLE tick after the roll ends, no re-press")
			resumed = true
			break
		assert_almost_eq(ms.p1.stamina.get_current(), stamina_at_entry, 1e-4,
			"AC 11(i): drain stays stopped for the whole roll, run key held throughout")
	assert_true(resumed, "the roll must return to IDLE within 30 ticks at this config")


## ---- AC 16: BLOCKING forced to walk speed, no drain, no latch, run key or not ------------

func test_blocking_forces_walk_speed_with_no_drain_and_no_latch_while_run_is_held() -> void:
	var c := _config()
	c.run_stamina_drain_per_second = 60.0  # 1.0/tick -- must never apply while BLOCKING
	var ms := _make_match(c)
	var block_and_run := _intent([&"block"], [&"block", &"run"], Vector2(1, 0))
	_advance(ms, block_and_run)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING)
	assert_almost_eq(ms.p1.hero.velocity.length(), 2.5, 1e-4,
		"AC 16: BLOCKING moves at walk speed regardless of the run key")
	assert_eq(ms.p1.stamina.get_current(), 50.0, "no drain while blocking, run held or not")
	assert_false(ms.p1.hero.run_locked_out, "BLOCKING never sets the R6 latch")
	for i in range(3):
		_advance(ms, block_and_run)
	assert_eq(ms.p1.stamina.get_current(), 50.0, "still no drain across a held BLOCKING+run hold")
	assert_false(ms.p1.hero.run_locked_out)


## ---- AC 17: regen resumes exactly at last-running-tick + 47 further ticks ----------------

func test_regen_resumes_exactly_at_last_running_tick_plus_47_further_ticks() -> void:
	var c := _config()
	c.run_stamina_drain_per_second = 0.0        # isolate the delay-window timing from drain
	c.stamina_regen_per_second = 60.0            # 1.0/tick
	c.stamina_regen_delay_seconds = 48.0 / 60.0  # the authored 48-tick window
	var ms := _make_match(c)
	ms.p1.stamina.spend(10.0, 0)  # headroom below max, no delay from this setup spend
	ms.drain_signals()
	var running := _running(Vector2(1, 0))
	_advance(ms, running)  # the LAST actually-running tick -- restarts the 48-tick window
	var before := ms.p1.stamina.get_current()
	for i in range(46):
		_advance(ms)
	assert_eq(ms.p1.stamina.get_current(), before,
		"46 further ticks in: still inside the window (one tick before the 47-tick mark)")
	_advance(ms)  # the 47th further tick -- the review's traced count, still suppressed
	assert_eq(ms.p1.stamina.get_current(), before,
		"AC 17: last-running-tick + 47 further ticks is still the window's final suppressed tick")
	_advance(ms)  # the tick that follows -- window expired
	assert_eq(ms.p1.stamina.get_current(), before + 1.0,
		"AC 17: regen resumes exactly on the tick after last-running-tick + 47 further ticks")


## ---- AC 4 (pad half): resolve_card_tick's run_held, bare A vs. under cast_held -----------

func test_resolve_card_tick_run_held_true_on_bare_a_false_under_cast_held() -> void:
	var bare := GamepadController.resolve_card_tick(false,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, false,  # basic_raw pressed, cast NOT held
		false, false, false, false, false, false, 0.5, -1)
	assert_true(bare["run_held"], "AC 4: bare A (basic_raw) outside cast_held drives running")

	var cast := GamepadController.resolve_card_tick(true,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		true, false,  # basic_raw pressed, but cast_held true this time
		false, false, false, false, false, false, 0.5, -1)
	assert_false(cast["run_held"],
		"AC 4: the same bare A held while cast_held is true never drives running")

	var idle := GamepadController.resolve_card_tick(false,
		false, false, false, false, false, false,
		0.0, 0.0, 0.0, 0.0,
		false, false,  # basic_raw not held at all
		false, false, false, false, false, false, 0.5, -1)
	assert_false(idle["run_held"], "no A held, no running")


## ---- AC 2: run_stamina_drain_per_tick derivation, the stamina_regen_per_tick shape -------

func test_run_stamina_drain_per_tick_is_derived_from_per_second_at_tick_hz() -> void:
	var c := _config()
	c.run_stamina_drain_per_second = 15.0
	var t := BalanceTicks.from_config(c)
	assert_eq(t.run_stamina_drain_per_tick, 0.25, "15/s at 60 Hz -> 0.25 per tick, derived at load")
