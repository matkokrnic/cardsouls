extends TestCase

## Story 1-7 coverage — the deltas over the 1-5 substrate (which test_contact_resolution.gd
## already pins and this file deliberately does NOT re-test): the queued hit_landed signal
## (payload + D5 discipline + ordering after hp_changed + silence on dropped facts), the
## DEAD terminal state (step-8 entry, input-proof row, post-death fact-drop closing the
## corpse-mana-farming defect), and the D-1 round-scoped intent-carried debug reset
## (HP + latch + DEAD->IDLE only; pools, windows, and attack_index untouched).
##
## Test balance: the test_contact_resolution.gd shape (windup 3, active 4, recovery 6,
## chain window 5, chain length 3 — one swing = windup t1-3, active t4-7, recovery t8-13,
## IDLE t14), damage 6% / melee_hit_mana 8.0, roll cost 10 / delay 3 ticks / regen 1.0
## per tick. Kill tests author damage 100% so ONE confirmed hit kills.


func _config(damage_percent := 6.0) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 60.0           # 1.0 per tick
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks
	c.roll_stamina_cost = 10.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = damage_percent
	c.attack_windup_move_speed_multiplier = 0.0
	c.attack_active_move_speed_multiplier = 0.0
	c.attack_recovery_move_speed_multiplier = 0.0
	c.melee_hit_mana = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


func _make_match(damage_percent := 6.0) -> MatchState:
	var ms := MatchState.new(7, 100.0, 5.0, 50.0, 80.0)
	ms.apply_balance(_config(damage_percent))
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	ms.inject_feature_flags(f)
	ms.drain_signals()
	return ms


## A just-pressed key is also held that tick (matches KeyboardController semantics).
func _intent(pressed_keys: Array = [], held_keys: Array = [], reset := false) -> InputIntent:
	var i := InputIntent.new()
	for k in pressed_keys:
		i.pressed[k] = true
		i.held[k] = true
	for k in held_keys:
		i.held[k] = true
	i.debug_reset = reset
	return i


func _advance(ms: MatchState, p1_intent: InputIntent = null, p2_intent: InputIntent = null) -> void:
	var i1 := p1_intent if p1_intent != null else InputIntent.new()
	var i2 := p2_intent if p2_intent != null else InputIntent.new()
	var intents: Array[InputIntent] = [i1, i2]
	ms.advance(intents)
	ms.drain_signals()


## Press attack on tick 1, then advance through tick `through_tick` (inclusive).
func _attack_and_advance_through(ms: MatchState, through_tick: int) -> void:
	_advance(ms, _intent([&"attack"]))  # tick 1
	for t in range(2, through_tick + 1):
		_advance(ms)


func _advance_until_idle(ms: MatchState) -> void:
	for i in range(60):
		if ms.p1.hero.action_state == HeroState.ActionState.IDLE:
			return
		_advance(ms)
	assert_true(false, "IDLE not reached within 60 ticks")


## Kill P2 through the REAL pipeline: swing 0 confirmed at 100% damage (active t4-7,
## fact pushed at t4, resolved t5). Leaves: P2 DEAD at 0 HP, P1 at 8 mana, tick at 5.
func _kill_p2(ms: MatchState) -> void:
	_attack_and_advance_through(ms, 4)
	ms.push_contact(0, 1, ms.p1.hero.attack_index, Vector2.DOWN)
	_advance(ms)  # tick 5: 100% damage -> 0 HP -> step 8: DEAD + round_ended


## ---- hit_landed (AC 3) ------------------------------------------------------------------

func test_hit_landed_queued_with_payload() -> void:
	var ms := _make_match()
	var hits: Array = []
	ms.hit_landed.connect(func(attacker: int, target: int, damage: float, target_hp: float) -> void:
		hits.append([attacker, target, damage, target_hp]))
	_attack_and_advance_through(ms, 4)
	ms.push_contact(0, 1, ms.p1.hero.attack_index, Vector2.DOWN)
	# Advance WITHOUT draining to observe the D5 queue discipline directly.
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	assert_eq(hits.size(), 0, "hit_landed is QUEUED during advance, never emitted mid-tick")
	ms.drain_signals()
	assert_eq(hits, [[0, 1, 6.0, 94.0]],
		"payload: attacker slot, target slot, damage (6% of 100), target REMAINING HP")


func test_hit_landed_drains_after_targets_hp_changed() -> void:
	var ms := _make_match()
	var order: Array = []
	ms.p2.hero.hp_changed.connect(func(_c: float, _m: float) -> void: order.append("hp"))
	ms.hit_landed.connect(func(_a: int, _t: int, _d: float, _hp: float) -> void: order.append("hit"))
	_attack_and_advance_through(ms, 4)
	ms.push_contact(0, 1, ms.p1.hero.attack_index, Vector2.DOWN)
	_advance(ms)
	assert_eq(order, ["hp", "hit"],
		"FIFO drain: damage queues hp_changed first, then hit_landed — consumers see HP moved before the hit event")


func test_dropped_duplicate_fact_emits_no_hit_landed() -> void:
	var ms := _make_match()
	var hits := {"n": 0}
	ms.hit_landed.connect(func(_a: int, _t: int, _d: float, _hp: float) -> void: hits.n += 1)
	_attack_and_advance_through(ms, 4)
	ms.push_contact(0, 1, ms.p1.hero.attack_index, Vector2.DOWN)
	_advance(ms)  # tick 5: confirmed
	ms.push_contact(0, 1, ms.p1.hero.attack_index, Vector2.DOWN)
	_advance(ms)  # tick 6: same swing, same target -> dedupe drops it
	assert_eq(hits.n, 1, "hit_landed fires per CONFIRMED hit only — dropped facts emit nothing")


## ---- DEAD terminal state (AC 4.1 / 4.2) -------------------------------------------------

func test_death_enters_dead_via_step8_and_signals_through_the_seam() -> void:
	var ms := _make_match(100.0)
	var p2_log: Array = []
	ms.p2.hero.action_state_changed.connect(
		func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
			p2_log.append([int(prev), int(cur)]))
	_kill_p2(ms)
	assert_eq(ms.p2.hero.get_hp(), 0.0, "one 100% hit kills")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.DEAD, "step-8 resolution entered DEAD")
	assert_true(bool(ms.to_snapshot()["round_over"]), "round latch set")
	assert_eq(p2_log, [[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.DEAD)]],
		"death announced through the SAME queued action_state_changed channel (locked seam)")


## Story 1-7 (D-3): the DEAD transition-table row (`&"dead": {}`) accepts no input — entry is
## ONLY MatchState's step-8 resolution, exit is ONLY the D-1 debug reset. A press on a dead hero
## fires no table edge and emits no signal. DIRECTIONAL: attack, roll, AND block presses are all
## dropped, and the state stays DEAD (an edge added to the dead row would transition it out).
##
## SUPERSESSION de-vacuization (E2-CO/R4, executes E3-P/R4): the 2-6 step-1b freeze makes this
## unreachable through advance() (a DEAD hero implies _round_over, and step 1b returns before step
## 3 runs _resolve_actions). So this pins the _resolve_actions CONTRACT directly, by calling it on
## a hand-constructed DEAD hero with _round_over FALSE and live presses. MUTATION: add any edge to
## the `&"dead"` row (e.g. `&"attack": ActionState.ATTACKING`) and this FAILS — the press
## transitions the corpse out of DEAD.
func test_dead_hero_row_accepts_no_input() -> void:
	var ms := _make_match()
	ms.p2.hero.set_action_state(HeroState.ActionState.DEAD)  # forced DEAD; _round_over stays FALSE
	ms.drain_signals()  # discard the forced-DEAD action_state_changed before we start counting
	assert_false(bool(ms.to_snapshot()["round_over"]), "hand-constructed: DEAD with _round_over FALSE")
	var fired := {"n": 0}
	ms.p2.hero.action_state_changed.connect(
		func(_p: HeroState.ActionState, _c: HeroState.ActionState) -> void: fired.n += 1)
	ms._resolve_actions(ms.p2, _intent([&"attack"]), 1)          # DIRECT calls — no advance(), no step 1b
	ms._resolve_actions(ms.p2, _intent([&"roll"]), 1)
	ms._resolve_actions(ms.p2, _intent([&"block"], [&"block"]), 1)
	ms.drain_signals()
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.DEAD, "dead row accepts no table edge")
	assert_eq(fired.n, 0, "no transitions, no signals — presses on a dead hero are dropped")


## Story 1-7 (D-3) / 2-3: the step-4 DEAD-TARGET fact drop — a contact aimed at a DEAD target is
## dropped PRE-DEDUPE (no damage, no hit_landed, no confirmed hit, so no step-5 mana), closing the
## corpse-mana-farming defect found at the 1-7 gate. Sits on the SAME pre-dedupe rung as the
## DEAD-attacker drop (test_dead_attacker_in_flight_window_delivers_nothing).
##
## SUPERSESSION de-vacuization (E2-CO/R4, executes E3-P/R4): the 2-6 step-1b freeze makes this
## unreachable through advance() (a DEAD target implies _round_over, and step 1b returns before
## step 4 drains the queue). The live-match anti-farming guarantee is SEPARATELY pinned by
## test_round_over_freezes_resolution_until_reset in test_match_state.gd; this test pins the
## OTHER, otherwise-unguarded half — the _resolve_contacts DEAD-target drop CONTRACT — directly.
## A live attacker (a live swing record) and a hand-constructed DEAD target with _round_over
## FALSE, resolved by calling _resolve_contacts() directly and feeding its result to the step-5
## mana seat. MUTATION: delete the `if target ... DEAD: continue` drop and this FAILS — the fact
## resolves into damage, a hit_landed, and a confirmed hit.
##
## RENAMED from test_no_corpse_mana_farming_under_round_over_freeze: the old name described the
## step-1b freeze, which this test no longer exercises (E2-CO/R4 ruled all six SUPERSESSION tests
## repoint to their DEAD branch; see the SDV decision-log record).
func test_dead_target_fact_dropped_no_corpse_mana() -> void:
	var ms := _make_match(100.0)
	ms.p1.hero.enter_attack(3)                               # P1 alive, ATTACKING, live swing record
	var atk := ms.p1.hero.attack_index
	ms.p2.hero.set_action_state(HeroState.ActionState.DEAD)  # DEAD target; _round_over stays FALSE
	ms.drain_signals()
	assert_false(bool(ms.to_snapshot()["round_over"]),
		"hand-constructed: DEAD target with _round_over FALSE")
	var hits := {"n": 0}
	ms.hit_landed.connect(func(_a: int, _t: int, _d: float, _hp: float) -> void: hits.n += 1)
	var deflects := {"n": 0}
	ms.deflect_landed.connect(func(_a: int, _t: int) -> void: deflects.n += 1)
	var hp_before := ms.p2.hero.get_hp()
	var mana_before := ms.p1.mana.get_current()
	ms.push_contact(0, 1, atk, Vector2.DOWN)                 # a fact from the live attacker at the DEAD target
	var confirmed := ms._resolve_contacts()                 # DIRECT step call — no advance(), no step 1b
	ms._generate_mana(confirmed)                            # the step-5 seat, fed the step-4 result
	ms.drain_signals()
	assert_eq(confirmed.size(), 0, "DEAD-target fact is not a confirmed hit — nothing for step 5")
	assert_eq(ms.p2.hero.get_hp(), hp_before, "no damage — a fact at a dead target delivers nothing")
	assert_eq(ms.p1.mana.get_current(), mana_before, "no mana (flag ON, but no confirmed hit)")
	assert_eq(hits.n, 0, "no hit_landed for a dead target")
	assert_eq(deflects.n, 0, "no deflect_landed for a dead target")
	assert_eq(ms.p1.hero.attack_index, atk,
		"attack_index untouched — dropped PRE-dedupe (register_swing_hit never reached)")
	assert_true(bool(ms.p1.hero.to_snapshot()["swing_dedupe"]["records"].has(atk)),
		"the swing's dedupe record is intact — the corpse-aimed fact never consumed the swing's resolution")


## ---- Debug reset (AC 5, D-1/D-2) --------------------------------------------------------

func test_debug_reset_is_round_scoped_and_nothing_else() -> void:
	# Story 2-6: the reset now lands on a FROZEN tick (the round is over). The reset is step 1, so
	# it clears the latch BEFORE step 1b consults it and steps 2-8 resolve again that same tick
	# (2-6/R6). The pre-2-6 flow set up a mid-delay stamina reading via post-kill live rolls,
	# impossible under the freeze; instead P1 rolls (spending stamina) BEFORE the kill, so the
	# "pools untouched" (D-2) bite lands on STAMINA — the half that would move if the reset ever
	# poked the D9 apply_balance refill. P2 is killed via take_damage (not P1's swing) so P1 stays
	# cleanly mid-roll into the freeze.
	var ms := _make_match(100.0)
	_advance(ms, _intent([&"roll"]))            # tick 1: P1 rolls -> stamina 50->40, ROLLING; delay suppresses ticks 1-3
	assert_eq(ms.p1.stamina.get_current(), 40.0, "roll spent 10 stamina before death")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING, "P1 mid-roll")
	var index_before := ms.p1.hero.attack_index  # P1 never attacked -> attack_index 0
	ms.p2.hero.take_damage(999.0)               # arm P2's death
	ms.p1.hero.take_damage(30.0)                # damage P1 too, so the HP-restore assertion bites
	_advance(ms)                                # tick 2: P2 dies at step 8 -> round over; delay covers tick 2 so stamina stays 40
	assert_true(bool(ms.to_snapshot()["round_over"]), "round over after P2's death")
	assert_eq(ms.p1.stamina.get_current(), 40.0, "stamina still 40 (regen delay suppresses ticks 1-3)")
	assert_eq(ms.p1.hero.get_hp(), 70.0, "P1 at 70 before the reset (the HP-restore assertion must bite)")
	var p2_log: Array = []
	ms.p2.hero.action_state_changed.connect(
		func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
			p2_log.append([int(prev), int(cur)]))
	_advance(ms, _intent([], [], true))         # tick 3: ROUND-SCOPED reset on the frozen tick
	assert_eq(ms.p1.hero.get_hp(), 100.0, "all slots restored: P1 HP back to max")
	assert_eq(ms.p2.hero.get_hp(), 100.0, "all slots restored: P2 HP back to max")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "DEAD -> IDLE on reset")
	assert_false(bool(ms.to_snapshot()["round_over"]), "round latch cleared")
	assert_eq(p2_log, [[int(HeroState.ActionState.DEAD), int(HeroState.ActionState.IDLE)]],
		"revival announced through the same queued seam")
	assert_eq(ms.p1.hero.attack_index, index_before, "attack_index NEVER resets (pinned dedupe contract)")
	assert_eq(ms.p1.stamina.get_current(), 40.0,
		"POOLS UNTOUCHED (D-2): stamina still EXACTLY 40 — the reset refilled nothing (bites the D9 apply_balance refill)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING,
		"a LIVE hero's action state untouched: still mid-roll through the reset (windows untouched)")
	_advance_until_idle(ms)                     # roll finishes normally — proves play resumed
	_advance(ms, _intent([&"attack"]))
	assert_eq(ms.p1.hero.attack_index, index_before + 1, "next swing continues the monotonic count")


func test_debug_reset_leaves_live_swing_and_windows_untouched() -> void:
	var ms := _make_match()
	_advance(ms, _intent([&"attack"]))          # tick 1: windup 1-3
	_advance(ms, _intent([], [], true))         # tick 2: reset mid-windup
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ATTACKING, "live swing keeps swinging")
	assert_eq(ms.p1.hero.attack_phase(), &"windup", "phase timeline undisturbed")
	_advance(ms)
	_advance(ms)                                # ticks 3-4
	assert_eq(ms.p1.hero.attack_phase(), &"active", "active still starts on tick 4 — windows untouched")
	assert_eq(ms.p1.hero.get_hp(), 100.0)
	assert_eq(ms.p2.hero.get_hp(), 100.0)


func test_debug_reset_from_either_slot_intent() -> void:
	var ms := _make_match(100.0)
	_kill_p2(ms)
	_advance(ms, null, _intent([], [], true))   # P2's intent carries the reset
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "any slot's intent triggers the round-scoped reset")
	assert_eq(ms.p2.hero.get_hp(), 100.0)
	assert_false(bool(ms.to_snapshot()["round_over"]))
