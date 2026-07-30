extends TestCase

## Story 1-4 coverage: the stamina economy. Pool mechanism (fixed per-tick regen, the
## post-spend delay window and its restart-on-spend, snapshot shape), the one deduction
## path (roll only — attack and block are free), the D5 lockout precondition with the two
## explicit AC 4 pins (fallthrough + rejected-emit), D6 regen conditions (BLOCKING and the
## delay window are the ONLY suppressions), D9 start-full, CONSTRAINT C inline reads, and
## the step-5 null guard.
##
## Test balance: max 50, regen 60/s = 1.0/tick (arithmetic stays readable), delay 3 ticks,
## roll cost 10; action durations are test_action_state.gd's shape (windup 3, active 4,
## recovery 6, chain window 5, deflect 4, roll iframe 2, roll duration 5, chain length 3).


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0          # 1.0 per tick
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks
	c.roll_stamina_cost = 10.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _make_match() -> MatchState:
	var ms := MatchState.new(7, 100.0, 5.0, 50.0, 80.0)
	ms.apply_balance(_config())
	ms.drain_signals()
	return ms


## A just-pressed key is also held that tick (matches KeyboardController semantics).
func _intent(pressed_keys: Array = [], held_keys: Array = []) -> InputIntent:
	var i := InputIntent.new()
	for k in pressed_keys:
		i.pressed[k] = true
		i.held[k] = true
	for k in held_keys:
		i.held[k] = true
	return i


func _advance(ms: MatchState, p1_intent: InputIntent = null) -> void:
	var i1 := p1_intent if p1_intent != null else InputIntent.new()
	var intents: Array[InputIntent] = [i1, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


func _advance_to_recovery(ms: MatchState) -> void:
	for i in range(60):
		if ms.p1.hero.attack_phase() == &"recovery":
			return
		_advance(ms)
	assert_true(false, "recovery not reached within 60 ticks")


## ---- Pool mechanism (unit) --------------------------------------------------------------
## Unit tests drive the REAL per-tick order: tick_timers() (step 2) then advance_regen()
## (step 5). On the spend tick itself, step 2 ran before the spend started the window, so
## the spend tick is a bare advance_regen() — the window suppresses it at elapsed 0, and an
## authored delay of N ticks suppresses exactly N ticks starting with the spend tick.

func test_pool_regen_reaches_max_in_expected_ticks_and_never_overshoots() -> void:
	var pool := StaminaPool.new(SignalQueue.new(), 50.0, 50.0)
	pool.spend(10.0, 0)  # no delay
	for i in range(4):
		pool.tick_timers()
		pool.advance_regen(2.5, false)
	assert_eq(pool.get_current(), 50.0, "40 + 4 x 2.5 reaches max in exactly 4 ticks")
	pool.tick_timers()
	pool.advance_regen(2.5, false)
	assert_eq(pool.get_current(), 50.0, "regen never overshoots the maximum")


func test_pool_delay_window_suppresses_exactly_n_ticks_then_expires() -> void:
	var pool := StaminaPool.new(SignalQueue.new(), 50.0, 50.0)
	pool.spend(10.0, 3)
	pool.advance_regen(1.0, false)   # spend tick: window at elapsed 0 — tick 1 of 3
	pool.tick_timers()
	pool.advance_regen(1.0, false)   # tick 2 of 3
	pool.tick_timers()
	pool.advance_regen(1.0, false)   # tick 3 of 3
	assert_eq(pool.get_current(), 40.0, "delay of 3 suppresses exactly 3 ticks incl. the spend tick")
	pool.tick_timers()
	pool.advance_regen(1.0, false)   # window expired in step 2 — regen resumes
	assert_eq(pool.get_current(), 41.0, "regen resumes on the tick after the window expires")


func test_pool_delay_window_restarts_on_spend() -> void:
	var pool := StaminaPool.new(SignalQueue.new(), 50.0, 50.0)
	pool.spend(5.0, 3)               # 45, window 3
	pool.advance_regen(1.0, false)   # spend tick suppressed
	pool.tick_timers()
	pool.advance_regen(1.0, false)   # 2 of 3 counted
	pool.spend(5.0, 3)               # 40, window RESTARTS at elapsed 0
	pool.advance_regen(1.0, false)   # restart tick suppressed (1 of 3 again)
	pool.tick_timers()
	pool.advance_regen(1.0, false)   # 2 of 3
	pool.tick_timers()
	pool.advance_regen(1.0, false)   # 3 of 3 — the OLD window would have expired by now
	assert_eq(pool.get_current(), 40.0, "restarted window still counting — no regen")
	pool.tick_timers()
	pool.advance_regen(1.0, false)
	assert_eq(pool.get_current(), 41.0, "regen resumes only after the RESTARTED window")


func test_pool_failed_spend_does_not_restart_delay() -> void:
	var pool := StaminaPool.new(SignalQueue.new(), 50.0, 50.0)
	pool.spend(10.0, 2)              # 40, window 2
	pool.advance_regen(1.0, false)   # spend tick: 1 of 2
	pool.tick_timers()
	assert_false(pool.spend(999.0, 2), "overspend refused")
	pool.advance_regen(1.0, false)   # 2 of 2 — still counting
	assert_eq(pool.get_current(), 40.0, "refused spend did not shorten OR restart the window")
	pool.tick_timers()
	pool.advance_regen(1.0, false)   # expired — regen applies
	assert_eq(pool.get_current(), 41.0, "refused spend left the window untouched")


func test_pool_delay_counts_through_suppressed_ticks() -> void:
	var pool := StaminaPool.new(SignalQueue.new(), 50.0, 50.0)
	pool.spend(10.0, 2)
	pool.advance_regen(1.0, true)    # spend tick: window counting AND caller suppresses
	pool.tick_timers()
	pool.advance_regen(1.0, true)    # 2 of 2, caller still suppresses
	pool.tick_timers()               # window expires here
	pool.advance_regen(1.0, true)    # expired, but caller suppresses this tick too
	assert_eq(pool.get_current(), 40.0, "suppressed ticks regen nothing")
	pool.tick_timers()
	pool.advance_regen(1.0, false)
	assert_eq(pool.get_current(), 41.0, "delay is wall time — it counted through suppression")


func test_pool_stamina_changed_fires_only_on_actual_change() -> void:
	var q := SignalQueue.new()
	var pool := StaminaPool.new(q, 50.0, 50.0)
	var ev := {"n": 0}
	pool.stamina_changed.connect(func(_current: float, _maximum: float) -> void: ev.n += 1)
	pool.tick_timers()
	pool.advance_regen(1.0, false)
	q.drain()
	assert_eq(ev.n, 0, "regen at max changes nothing and emits nothing")
	pool.spend(10.0, 0)
	q.drain()
	assert_eq(ev.n, 1, "spend emits once")
	pool.tick_timers()
	pool.advance_regen(1.0, false)
	q.drain()
	assert_eq(ev.n, 2, "regen below max emits")


func test_pool_snapshot_includes_regen_delay_window() -> void:
	var pool := StaminaPool.new(SignalQueue.new(), 50.0, 50.0)
	pool.spend(10.0, 5)
	var snap: Dictionary = pool.to_snapshot()
	assert_true(snap.has("regen_delay"), "mid-count delay window is snapshotted (D8)")
	assert_eq(int(snap["regen_delay"]["duration_ticks"]), 5)
	assert_true(bool(snap["regen_delay"]["is_running"]), "window state survives the snapshot")


## ---- One deduction path (D4) ------------------------------------------------------------

func test_roll_deducts_cost_at_the_transition() -> void:
	var ms := _make_match()
	_advance(ms, _intent([&"roll"]))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "roll fired")
	assert_eq(ms.p1.stamina.get_current(), 40.0, "cost 10 deducted through the one path")


func test_attack_and_block_are_free() -> void:
	var ms := _make_match()
	_advance(ms, _intent([&"attack"]))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ATTACKING)
	assert_eq(ms.p1.stamina.get_current(), 50.0, "basic attack costs no stamina (GDD)")
	var ms2 := _make_match()
	_advance(ms2, _intent([&"block"], [&"block"]))
	assert_eq(ms2.p1.hero.action_state, HeroState.ActionState.BLOCKING)
	assert_eq(ms2.p1.stamina.get_current(), 50.0, "BLOCKING entry is free — no check, no cost")


## ---- Lockout + rejection semantics (D5, AC 4) -------------------------------------------

func test_roll_at_exactly_cost_succeeds() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(40.0, 0)  # down to 10 == cost (test setup, not a gameplay path)
	ms.drain_signals()
	_advance(ms, _intent([&"roll"]))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "exactly-affordable roll fires")
	assert_eq(ms.p1.stamina.get_current(), 0.0)


func test_roll_at_cost_minus_one_rejected_with_signal() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(41.0, 0)  # down to 9 == cost - 1
	ms.drain_signals()
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(func(action: StringName, reason: StringName) -> void:
		rejections.append([action, reason]))
	_advance(ms, _intent([&"roll"]))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"lockout is a precondition — the transition never fires")
	assert_eq(rejections, [[&"roll", &"insufficient_stamina"]], "queued action_rejected emitted")
	assert_eq(ms.p1.stamina.get_current(), 10.0,
		"nothing deducted; regen ran (a refused spend never restarts the delay)")


## AC 4 PIN (fallthrough): a stamina-rejected roll press lets a lower-priority same-tick
## block press fire on that same tick — identical semantics to the 1-3 capped-chain reject.
func test_pin_stamina_rejected_roll_falls_through_to_block_same_tick() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(41.0, 0)  # 9 < cost
	ms.drain_signals()
	_advance(ms, _intent([&"roll", &"block"], [&"block"]))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING,
		"rejected roll falls through per INPUT_PRIORITY; block fires the SAME tick")


## AC 4 PIN (rejected-emit): action_rejected is emitted for the rejected roll press even
## when the lower-priority block succeeds that tick (loss legibility is mandatory).
func test_pin_action_rejected_emitted_even_when_block_succeeds() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(41.0, 0)
	ms.drain_signals()
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(func(action: StringName, reason: StringName) -> void:
		rejections.append([action, reason]))
	_advance(ms, _intent([&"roll", &"block"], [&"block"]))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING, "block succeeded")
	assert_eq(rejections, [[&"roll", &"insufficient_stamina"]],
		"the rejected press still emitted — success of a lower-priority action hides nothing")


## AC 4 scope pin: the 1-3 capped-chain reject stays SILENT — action_rejected covers the
## stamina-rejected roll only; widening it is a separate decision, not a 1-4 detail.
func test_capped_chain_reject_stays_silent() -> void:
	var ms := _make_match()
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(func(action: StringName, reason: StringName) -> void:
		rejections.append([action, reason]))
	_advance(ms, _intent([&"attack"]))  # swing 0
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 1
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 2 (cap: 3 swings)
	assert_eq(ms.p1.hero.chain_index, 2, "at the cap")
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # rejected at the cap
	assert_eq(ms.p1.hero.chain_index, 2, "capped press dropped")
	assert_eq(rejections, [], "capped-chain reject emits NO action_rejected")


## ---- Regen conditions (D6, AC 2) --------------------------------------------------------

func test_blocking_suppresses_regen_and_release_resumes() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(20.0, 0)  # 30, no delay
	ms.drain_signals()
	_advance(ms, _intent([&"block"], [&"block"]))
	assert_eq(ms.p1.stamina.get_current(), 30.0, "no regen on the BLOCKING entry tick (D6)")
	for i in range(3):
		_advance(ms, _intent([], [&"block"]))
	assert_eq(ms.p1.stamina.get_current(), 30.0, "held block: still no regen — block costs time")
	_advance(ms)  # release -> IDLE in step 3; step 5 regenerates
	assert_eq(ms.p1.stamina.get_current(), 31.0, "regen resumes on the release tick")


func test_regen_runs_while_rolling_after_delay_expires() -> void:
	var ms := _make_match()
	_advance(ms, _intent([&"roll"]))  # tick 1: 40, delay (3 ticks) suppresses t1
	_advance(ms)                      # tick 2: delay counts
	_advance(ms)                      # tick 3: delay counts (3 of 3)
	assert_eq(ms.p1.stamina.get_current(), 40.0, "post-spend delay covers ticks 1-3 exactly")
	_advance(ms)                      # tick 4: window expired in step 2 -> regen, still mid-roll
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "still ROLLING")
	assert_eq(ms.p1.stamina.get_current(), 41.0,
		"regen runs while ROLLING — only BLOCKING and the delay window suppress (D6)")


func test_regen_runs_while_attacking() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(20.0, 0)  # 30, no delay
	ms.drain_signals()
	_advance(ms, _intent([&"attack"]))
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ATTACKING)
	assert_eq(ms.p1.stamina.get_current(), 31.0, "regen runs while ATTACKING")


func test_regen_reaches_max_end_to_end_without_overshoot() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(20.0, 0)  # 30, no delay
	ms.drain_signals()
	for i in range(19):
		_advance(ms)
	assert_eq(ms.p1.stamina.get_current(), 49.0, "1.0/tick: 19 ticks in")
	_advance(ms)
	assert_eq(ms.p1.stamina.get_current(), 50.0, "reaches max in exactly 20 ticks")
	_advance(ms)
	assert_eq(ms.p1.stamina.get_current(), 50.0, "holds at max — never overshoots")


## ---- Start full (D9, AC 5) --------------------------------------------------------------

func test_apply_balance_starts_pool_full() -> void:
	var ms := MatchState.new(7, 100.0, 5.0, 50.0, 80.0)
	ms.p1.stamina.spend(30.0, 0)  # 20 before injection
	ms.apply_balance(_config())
	ms.drain_signals()
	assert_eq(ms.p1.stamina.get_current(), 50.0, "apply_balance() sets current to the authored max")
	assert_eq(ms.p2.stamina.get_current(), 50.0, "both pools start full")


## DELIBERATE D9 consequence (review round): apply_balance() is ALSO the X3 live-reload
## seam, so a mid-match balance reload refills both pools to the authored maximum —
## unlike in-flight timing windows, resources do NOT survive a reload. Accepted in 1-4;
## story 3-1 (which separates match-start injection from reload injection) must reconcile
## this. See decision-log Session 2026-07-24/25.
func test_mid_match_reload_refills_stamina_to_max() -> void:
	var ms := _make_match()
	_advance(ms, _intent([&"roll"]))  # mid-match: 40, delay window running
	assert_eq(ms.p1.stamina.get_current(), 40.0, "mid-match spend on the books")
	ms.apply_balance(_config())       # live reload
	ms.drain_signals()
	assert_eq(ms.p1.stamina.get_current(), 50.0,
		"live reload refills stamina to the authored max (D9 applies to EVERY apply_balance)")
	assert_eq(ms.p2.stamina.get_current(), 50.0, "both players refilled")


## ---- CONSTRAINT C: inline reads at the moment of use ------------------------------------

## A reload swaps cost, regen rate, AND delay; the next spend/tick uses the new values —
## nothing was cached off balance or balance_ticks.
func test_reload_swaps_cost_rate_and_delay_at_next_use() -> void:
	var ms := _make_match()
	var cfg := _config()
	cfg.roll_stamina_cost = 5.0
	cfg.stamina_regen_per_second = 120.0        # 2.0 per tick
	cfg.stamina_regen_delay_seconds = 2.0 / 60.0  # 2 ticks
	ms.apply_balance(cfg)
	ms.drain_signals()
	_advance(ms, _intent([&"roll"]))  # tick 1: reloaded cost read inline at the transition
	assert_eq(ms.p1.stamina.get_current(), 45.0, "reloaded roll cost (5) deducted")
	_advance(ms)                      # tick 2: reloaded delay (2 ticks) covers t1-t2
	assert_eq(ms.p1.stamina.get_current(), 45.0, "reloaded 2-tick delay suppresses t1-t2")
	_advance(ms)                      # tick 3: window expired -> reloaded rate applies
	assert_eq(ms.p1.stamina.get_current(), 47.0,
		"reloaded delay (2 ticks) and regen rate (2.0/tick) both read inline")


## Story 2-3 (AC2/AC4, 2-3/R5): a DEAD hero's stamina regen is SUPPRESSED the SAME way BLOCKING
## already is (D6) — a corpse runs no economy. DIRECTIONAL: the suppression flag must include the
## DEAD state, so a corpse with headroom below max and NO regen-delay window still does not
## regenerate (a removed DEAD clause lets regen add stamina_regen_per_tick every call).
##
## SUPERSESSION de-vacuization (E2-CO/R4, executes E3-P/R4): the 2-6 step-1b freeze makes this
## branch unreachable through advance() (a DEAD hero always implies _round_over, and step 1b
## returns before step 5). So this pins the _regen_stamina CONTRACT directly, by calling it on a
## hand-constructed DEAD hero with _round_over FALSE and NO delay window (spend delay 0), so only
## the DEAD suppression — not a delay window — can hold regen back. MUTATION: delete `or state ==
## HeroState.ActionState.DEAD` from the suppression and this FAILS — the corpse regenerates.
func test_dead_hero_stamina_does_not_regen() -> void:
	var ms := _make_match()
	ms.p1.stamina.spend(20.0, 0)  # 30, NO delay window — regen would otherwise be visible every call
	ms.drain_signals()
	assert_eq(ms.p1.stamina.get_current(), 30.0, "start below max, no delay window")
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)  # forced DEAD; _round_over stays FALSE
	assert_false(bool(ms.to_snapshot()["round_over"]), "hand-constructed: DEAD with _round_over FALSE")
	for i in range(4):
		ms._regen_stamina(ms.p1)  # DIRECT call — advance()'s step 1b would skip step 5 entirely
	assert_eq(ms.p1.stamina.get_current(), 30.0,
		"DEAD: regen suppressed across every direct call (suppressed like BLOCKING)")


## ---- Step-5 null guard ------------------------------------------------------------------

func test_no_regen_without_apply_balance() -> void:
	var ms := MatchState.new(7, 100.0, 5.0, 50.0, 80.0)  # deliberately NO apply_balance
	ms.p1.stamina.spend(20.0, 0)
	ms.drain_signals()
	for i in range(3):
		_advance(ms)
	assert_eq(ms.p1.stamina.get_current(), 30.0,
		"pre-injection MatchState: step-5 regen inert, no crash")
