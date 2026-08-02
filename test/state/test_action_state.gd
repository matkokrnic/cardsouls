extends TestCase

## Story 1-3 coverage: the hero action-state machine. Exact-tick entry/exit per action,
## chain window + cap + reset pins, drop-not-buffer, queued signal sequence, the DEBT A
## null guard, CONSTRAINT C inline duration reads, and the STUNNED/CHARGING inbound-edge
## guard over the transition table.
##
## Test balance (authored as ticks/60.0 so the intended tick counts are explicit):
## windup 3, active 4, recovery 6, chain window 5, deflect 4, roll iframe 2,
## roll duration 5, chain length 3 swings. One attack swing = ticks 1-13
## (windup 1-3, active 4-7, recovery 8-13), IDLE on tick 14; chain window runs
## with recovery and last accepts a press on tick 12.


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


## AC 5: apply_balance in setup — the machine is fully exercised headless even though
## live play defers balance injection (DEBT A option b).
func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
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


func _advance_until_idle(ms: MatchState) -> void:
	for i in range(60):
		if ms.p1.hero.action_state == HeroState.ActionState.IDLE:
			return
		_advance(ms)
	assert_true(false, "IDLE not reached within 60 ticks")


## ---- STUNNED / CHARGING / DEAD guard (bite-verified both ways) --------------------------

## Enumerates the transition table: E1 must have ZERO inbound STUNNED edges (entering
## STUNNED would resolve OPEN decision (a) by accident) and zero inbound CHARGING edges
## (reserved E5). The STUNNED row itself must exist as data (accepts nothing); CHARGING
## must have no row at all (absent, not stubbed). Story 1-7 (D-3) extends the guard to
## DEAD: row present, accepts nothing, and ZERO inbound table edges — DEAD is entered
## only by the step-8 resolution (a non-table path) and exited only by the debug reset.
func test_table_has_no_inbound_stunned_charging_or_dead_edges() -> void:
	var rows: Dictionary = HeroState.TRANSITION_TABLE
	assert_true(rows.has(&"stunned"), "STUNNED row present (table data)")
	assert_eq((rows[&"stunned"] as Dictionary).size(), 0, "STUNNED accepts no input")
	assert_false(rows.has(&"charging"), "CHARGING row absent, not stubbed (E5)")
	assert_true(rows.has(&"dead"), "DEAD row present (story 1-7, D-3)")
	assert_eq((rows[&"dead"] as Dictionary).size(), 0, "DEAD accepts no input")
	for row_key: StringName in rows:
		var edges: Dictionary = rows[row_key]
		for action: StringName in edges:
			assert_ne(int(edges[action]), int(HeroState.ActionState.STUNNED),
				"inbound STUNNED edge forbidden in E1 (row %s, action %s)" % [row_key, action])
			assert_ne(int(edges[action]), int(HeroState.ActionState.CHARGING),
				"inbound CHARGING edge forbidden until E5 (row %s, action %s)" % [row_key, action])
			assert_ne(int(edges[action]), int(HeroState.ActionState.DEAD),
				"inbound DEAD edge forbidden — death is a step-8 resolution outcome (row %s, action %s)" % [row_key, action])


## ---- Exact-tick entry/exit --------------------------------------------------------------

func test_attack_phases_and_exit_on_exact_ticks() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # tick 1: press takes effect on tick 1
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "ATTACKING on the press tick")
	assert_eq(h.attack_phase(), &"windup")
	_advance(ms)
	_advance(ms)                        # ticks 2-3: windup
	assert_eq(h.attack_phase(), &"windup", "windup through tick 3")
	_advance(ms)                        # tick 4: windup done -> active
	assert_eq(h.attack_phase(), &"active", "active starts on tick 4")
	for i in range(3):
		_advance(ms)                    # ticks 5-7: active
	assert_eq(h.attack_phase(), &"active", "active through tick 7")
	_advance(ms)                        # tick 8: active done -> recovery + chain window
	assert_eq(h.attack_phase(), &"recovery", "recovery starts on tick 8")
	assert_true(h.chain.is_running, "chain window opens with recovery")
	for i in range(5):
		_advance(ms)                    # ticks 9-13: recovery
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "still ATTACKING on tick 13")
	_advance(ms)                        # tick 14: recovery done -> IDLE
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "IDLE exactly on tick 14 (3+4+6 swing)")
	assert_eq(h.chain_index, 0, "sequence end resets chain_index")


func test_roll_exact_ticks_and_iframe_window() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"roll"]))    # tick 1
	assert_eq(h.action_state, HeroState.ActionState.ROLLING, "ROLLING on the press tick")
	assert_true(h.roll_iframe.is_running, "iframe open on tick 1")
	_advance(ms)                        # tick 2
	assert_true(h.roll_iframe.is_running, "iframe covers tick 2")
	_advance(ms)                        # tick 3
	assert_false(h.roll_iframe.is_running, "iframe ends after exactly 2 ticks")
	_advance(ms)
	_advance(ms)                        # ticks 4-5
	assert_eq(h.action_state, HeroState.ActionState.ROLLING, "rolling through tick 5")
	_advance(ms)                        # tick 6: roll_duration done -> IDLE
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "IDLE exactly on tick 6 (5-tick roll)")


func test_block_hold_and_release_exact_ticks() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"block"]))   # tick 1
	assert_eq(h.action_state, HeroState.ActionState.BLOCKING, "BLOCKING on the press tick")
	assert_true(h.deflect.is_running, "deflect window opens at block entry")
	for i in range(4):
		_advance(ms, _intent([], [&"block"]))  # ticks 2-5: held
	assert_false(h.deflect.is_running, "deflect window (4 ticks) closed while block held")
	assert_eq(h.action_state, HeroState.ActionState.BLOCKING, "block persists past the deflect window")
	_advance(ms)                        # tick 6: released
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "IDLE on the release tick")


## ---- Cancellability / drop-not-buffer ---------------------------------------------------

func test_non_cancellable_inputs_dropped_not_buffered() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # tick 1
	_advance(ms, _intent([&"roll"]))    # tick 2: windup is non-cancellable
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "roll dropped during windup")
	_advance(ms)
	_advance(ms)                        # ticks 3-4
	_advance(ms, _intent([&"attack"]))  # tick 5: active is non-cancellable
	assert_eq(h.attack_phase(), &"active", "attack dropped during active")
	for i in range(8):
		_advance(ms)                    # ticks 6-13
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "tick 13: still the first swing")
	assert_eq(h.chain_index, 0, "a buffered attack would have chained — it did not")
	_advance(ms)                        # tick 14
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "swing ended: neither press was buffered")


## ---- Chain window, cap, and reset pins --------------------------------------------------

func test_chain_accepts_on_last_window_tick() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # tick 1
	for i in range(10):
		_advance(ms)                    # ticks 2-11
	_advance(ms, _intent([&"attack"]))  # tick 12: chain window still running (4 of 5)
	assert_eq(h.chain_index, 1, "chain accepted on the window's final running tick")
	assert_eq(h.attack_phase(), &"windup", "chained swing restarts windup")


func test_chain_dropped_after_window_closes() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # tick 1
	for i in range(11):
		_advance(ms)                    # ticks 2-12
	_advance(ms, _intent([&"attack"]))  # tick 13: chain window closed in step 2
	assert_eq(h.chain_index, 0, "press after the chain window closes is dropped")
	_advance(ms)                        # tick 14
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "no chain occurred; swing ended")


func test_chain_caps_at_attack_chain_length() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # swing 0
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 1
	assert_eq(h.chain_index, 1)
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 2 (cap: 3 swings)
	assert_eq(h.chain_index, 2)
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # rejected at the cap
	assert_eq(h.chain_index, 2, "cap reached — press dropped")
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "swing 2 continues uninterrupted")
	_advance_until_idle(ms)
	assert_eq(h.chain_index, 0, "sequence end resets chain_index")


## PIN (user decision, story 1-3): chain into attack 2, roll-cancel during recovery,
## attack again -> the new attack starts a FRESH sequence. A cancelled chain never resumes.
func test_pin_roll_cancel_resets_chain_sequence() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # swing 0
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 1 ("attack 2")
	assert_eq(h.chain_index, 1, "chained into attack 2")
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"roll"]))    # roll-cancel during recovery
	assert_eq(h.action_state, HeroState.ActionState.ROLLING, "recovery is roll-cancellable")
	assert_eq(h.chain_index, 0, "exit from ATTACKING resets the sequence")
	_advance_until_idle(ms)
	_advance(ms, _intent([&"attack"]))  # attack again
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING)
	assert_eq(h.chain_index, 0, "new attack starts a fresh sequence")
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))
	assert_eq(h.chain_index, 1, "fresh sequence can chain the full length again")


## Same-tick tiebreak pin: INPUT_PRIORITY is (attack, roll, block) — three simultaneous
## presses from IDLE fire exactly ONE transition (attack) and exactly one signal.
func test_same_tick_presses_resolve_by_input_priority() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	var log: Array = []
	h.action_state_changed.connect(func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
		log.append([int(prev), int(cur)]))
	_advance(ms, _intent([&"attack", &"roll", &"block"]))
	assert_eq(h.action_state, HeroState.ActionState.ATTACKING, "attack wins the same-tick tiebreak")
	assert_eq(log, [[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.ATTACKING)]],
		"exactly one transition, one signal")


## Gated-reject fallthrough pin: at the chain cap, the attack edge REJECTS (returns
## false) and a lower-priority same-tick roll press still fires on that same tick.
func test_capped_chain_rejection_falls_through_to_roll_same_tick() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))  # swing 0
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 1
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack"]))  # chain -> swing 2 (cap: 3 swings)
	assert_eq(h.chain_index, 2, "at the cap")
	_advance_to_recovery(ms)
	_advance(ms, _intent([&"attack", &"roll"]))  # capped chain rejects; roll must fire NOW
	assert_eq(h.action_state, HeroState.ActionState.ROLLING,
		"rejected chain falls through to roll on the same tick")
	assert_eq(h.chain_index, 0, "exit from ATTACKING resets the sequence")


## ---- Signal discipline ------------------------------------------------------------------

func test_signal_sequence_queued_and_matches_expected_list() -> void:
	var ms := _make_match()
	var h := ms.p1.hero
	var log: Array = []
	h.action_state_changed.connect(func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
		log.append([int(prev), int(cur)]))
	# D5 queue discipline observed directly: advance without draining first.
	var intents: Array[InputIntent] = [_intent([&"attack"]), InputIntent.new()]
	ms.advance(intents)
	assert_eq(log.size(), 0, "enqueued during advance(), never emitted mid-tick")
	ms.drain_signals()
	assert_eq(log.size(), 1, "emitted on drain")
	for i in range(7):
		_advance(ms)                    # ticks 2-8: reach recovery
	_advance(ms, _intent([&"attack"]))  # tick 9: chain (self-transition still emits, AC 4)
	_advance_until_idle(ms)
	_advance(ms, _intent([&"roll"]))
	_advance_until_idle(ms)
	var idle := int(HeroState.ActionState.IDLE)
	var atk := int(HeroState.ActionState.ATTACKING)
	var roll := int(HeroState.ActionState.ROLLING)
	assert_eq(log, [[idle, atk], [atk, atk], [atk, idle], [idle, roll], [roll, idle]],
		"emitted (previous, current) sequence matches the expected list exactly")


## ---- DEBT A guard / CONSTRAINT C --------------------------------------------------------

## DEBT A option (b) pin: without apply_balance (live play today), transition evaluation
## is skipped entirely — actions inert, no signals, no crash.
##
## Story 3-1 (AC 5, 3-1/R3) RE-ANCHORED: a pre-injection MatchState is now stat-less as well
## as inert, so the old fixed-value anchors (100.0 hp / 30.0 stamina) were constructor
## artefacts that no longer exist. The anchor is UNCHANGED FROM CONSTRUCTION, taken over the
## WHOLE per-player snapshot rather than one field — a stronger claim than the two constants
## it replaces, and one that cannot rot the next time a field is added.
##
## MUTATION (the round-end half, AC 5's new guard): delete `if balance_ticks == null: return`
## from _check_resolution and this FAILS on both the round_over assertion and the p1 snapshot
## — a stat-less hero sits at 0 hp, so the very first tick resolves a round end and sets the
## loser DEAD against a hero that was never given any hp to lose.
func test_null_balance_ticks_guard_actions_inert() -> void:
	var ms := MatchState.new(MatchParams.new(7))  # deliberately NO apply_balance
	var h := ms.p1.hero
	var fired := {"n": 0}
	h.action_state_changed.connect(func(_p: HeroState.ActionState, _c: HeroState.ActionState) -> void:
		fired.n += 1)
	var before: Dictionary = ms.to_snapshot()
	assert_eq(ms.p1.hero.get_max_hp(), 0.0, "stat-less at construction: no hp bound (AC 1)")
	assert_eq(ms.p1.stamina.get_maximum(), 0.0, "stat-less at construction: no stamina bound")
	assert_eq(ms.p1.mana.get_maximum(), 0.0, "stat-less at construction: no mana bound")
	for i in range(3):
		_advance(ms, _intent([&"attack"], [&"block"]))
	assert_eq(h.action_state, HeroState.ActionState.IDLE, "actions inert without injected balance")
	assert_eq(fired.n, 0, "no transitions, no signals")
	var after: Dictionary = ms.to_snapshot()
	assert_false(bool(after["round_over"]),
		"NO ROUND END: _check_resolution is gated too, or a 0-hp stat-less hero would lose on tick 1")
	assert_eq(after["p1"], before["p1"], "p1 UNCHANGED FROM CONSTRUCTION across three pressed ticks")
	assert_eq(after["p2"], before["p2"], "p2 UNCHANGED FROM CONSTRUCTION across three pressed ticks")


## CONSTRAINT C pin: an in-flight window keeps its duration across a mid-swing reload;
## the NEXT start() reads the swapped balance_ticks inline (nothing cached anywhere).
func test_mid_swing_reload_new_duration_at_next_start() -> void:
	var ms := _make_match()                 # windup = 3 ticks
	var h := ms.p1.hero
	_advance(ms, _intent([&"attack"]))      # tick 1: windup(3) in flight
	var cfg := _config()
	cfg.attack_windup_seconds = 6.0 / 60.0  # mid-swing reload: windup becomes 6
	ms.apply_balance(cfg)
	ms.drain_signals()
	_advance(ms)
	_advance(ms)                            # ticks 2-3: original 3-tick windup completes
	_advance(ms)                            # tick 4: active starts — original schedule held
	assert_eq(h.attack_phase(), &"active", "in-flight windup kept its pre-reload duration")
	_advance_until_idle(ms)
	_advance(ms, _intent([&"attack"]))      # fresh swing: start() reads swapped balance_ticks
	assert_eq(h.windup.remaining_ticks(), 6, "next start() picked up the reloaded duration")
