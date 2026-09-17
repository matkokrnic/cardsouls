extends TestCase

## Story 1-8 coverage: facing-gated block mitigation + the deflect window with the +1
## resolution grace tick (R-N2), the R-D1 entry precondition / spend-at-landing split,
## and the R-D4 outcome semantics (both outcomes register the swing-hit; blocked =
## confirmed hit with full mana; deflected = fully negated, deflect_landed only).
##
## Test balance: the test_contact_resolution.gd shape (windup 3, active 4, recovery 6 —
## one swing = windup t1-3, active t4-7), damage 6% of 100 = 6.0 per hit,
## melee_hit_mana 8.0, plus the defense values: block_damage_multiplier 0.25,
## deflect_stamina_cost 8.0, deflect window 4 ticks, block_facing_arc_degrees 180.
##
## Deflect-window timeline (block pressed t1): enter_block starts the 4-tick window in
## t1 step 3; it RUNS through resolutions t1-t4, closes in t5's step 2, and t5 is the
## +1 GRACE tick (a t4 physics contact arriving one tick late still deflects); t6 is
## the first outside tick. P2 never moves in these tests, so its facing stays the
## Vector2.DOWN default: a DOWN fact direction is dead ahead, UP is directly behind.


## Story 5-6 (AC 9/AC 10): the deflected attacker's stun length and punitive stamina drain.
const DEFLECT_STUN_TICKS := 11
const DEFLECT_PENALTY := 13.0


func _config(deflect_window_seconds := 4.0 / 60.0, deflect_cost := 8.0,
		stamina_max := 50.0) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = stamina_max
	c.stamina_regen_per_second = 60.0           # 1.0 per tick
	c.stamina_regen_delay_seconds = 3.0 / 60.0  # 3 ticks
	c.roll_stamina_cost = 10.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.attack_windup_move_speed_multiplier = 0.0
	c.attack_active_move_speed_multiplier = 0.0
	c.attack_recovery_move_speed_multiplier = 0.0
	# Story 3-1 (AC 1/AC 3): the mana CAP is authored data now that the constructor carries none.
	# 80.0 is what this fixture's MatchState.new used to supply, so behaviour is unchanged.
	c.max_mana = 80.0
	c.melee_hit_mana = 8.0
	c.block_damage_multiplier = 0.25
	c.deflect_stamina_cost = deflect_cost
	c.deflect_window_seconds = deflect_window_seconds
	c.block_facing_arc_degrees = 180.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	# Story 5-6 (AC 9/AC 10): the deflect's consequence for its ATTACKER. Both authored DISTINCT from
	# every other count and magnitude this fixture carries ({2, 3, 4, 5, 6} ticks; 6.0 / 8.0 / 10.0 /
	# 50.0 / 80.0) so a seat that read the wrong field lands on a different value rather than
	# coinciding with a right one. `deflect_stamina_penalty` is deliberately LARGER than
	# `deflect_stamina_cost` so the two can never be confused in an assertion.
	c.deflect_stun_seconds = float(DEFLECT_STUN_TICKS) / TimingWindow.TICK_HZ
	c.deflect_stamina_penalty = DEFLECT_PENALTY
	return c


func _make_match(config: BalanceConfig = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(config if config != null else _config())
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	ms.inject_feature_flags(f)
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


static func _in_ranges(t: int, ranges: Array) -> bool:
	for r: Array in ranges:
		if t >= int(r[0]) and t <= int(r[1]):
			return true
	return false


## Drive both slots through `through_tick`. p1_press: tick -> pressed actions.
## p2_block_ranges: [[from, to], ...] inclusive tick spans with block held (press fires
## on each span's first tick). contacts: tick -> [[attacker, target, index, dir], ...],
## pushed BEFORE that tick's advance (the runner's step-2 position).
func _play(ms: MatchState, through_tick: int, p1_press := {}, p2_block_ranges := [],
		contacts := {}) -> void:
	for t in range(1, through_tick + 1):
		var i1 := _intent(p1_press.get(t, []))
		var held := _in_ranges(t, p2_block_ranges)
		var pressed2: Array = [&"block"] if held and not _in_ranges(t - 1, p2_block_ranges) else []
		var held2: Array = [&"block"] if held else []
		var i2 := _intent(pressed2, held2)
		for fact: Array in contacts.get(t, []):
			ms.push_contact([fact[0], -1], [fact[1], -1], fact[2], fact[3], MatchState.CONTACT_STRIKE)
		var intents: Array[InputIntent] = [i1, i2]
		ms.advance(intents)
		ms.drain_signals()


func _collect_deflects(ms: MatchState, into: Array) -> void:
	# Story 5-5 (AC 13): the payload gained a THIRD argument (the answered colour). The lambda widens
	# to match -- a callable narrower than the signal errors at emit -- but this helper still appends
	# the PAIR, so every assertion built on it stays a free, unedited regression. The colour itself is
	# asserted once, deliberately, by test_a_melee_parry_reports_no_colour below.
	ms.deflect_landed.connect(func(attacker: int, target: int, _color: int) -> void:
		into.append([attacker, target]))


func _collect_hits(ms: MatchState, into: Array) -> void:
	ms.hit_landed.connect(func(attacker: int, target: int, damage: float, hp: float) -> void:
		into.append([attacker, target, damage, hp]))


## ---- Deflect window boundary, both sides on exact ticks (AC 2, AC 9) --------------------

func test_contact_inside_window_deflects_fully() -> void:
	var ms := _make_match()
	var deflects: Array = []
	var hits: Array = []
	_collect_deflects(ms, deflects)
	_collect_hits(ms, hits)
	_play(ms, 4, {1: [&"attack"]}, [[1, 10]], {4: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p2.hero.get_hp(), 100.0, "deflect negates ALL damage")
	assert_eq(ms.p2.stamina.get_current(), 42.0, "deflect cost 8 spent AT LANDING (50 - 8)")
	assert_eq(ms.p1.mana.get_current(), 0.0, "a deflected contact generates NO mana")
	assert_eq(deflects, [[0, 1]], "deflect_landed queued with (attacker, target)")
	assert_eq(hits.size(), 0, "no hit_landed on a deflect — deflect_landed is the only signal")


## Story 5-5 (AC 13): the melee parry's HALF of the widened payload. This negation is colour-blind by
## construction, so it reports `NO_TELEGRAPH_COLOR` -- an explicit "no colour to report" sentinel,
## not a fourth invented value, and the token reused a fourth context over. It is what keeps today's
## UNTINTED spark rendering exactly as it does now: the widening is additive, and no existing
## consumer's observable behaviour changes.
##
## ASSERTED ONCE, HERE, rather than by widening `_collect_deflects`: that helper deliberately keeps
## appending the PAIR so every assertion built on it stays an unedited free regression.
func test_a_melee_parry_reports_no_colour() -> void:
	var ms := _make_match()
	var payloads: Array = []
	ms.deflect_landed.connect(func(a: int, t: int, c: int) -> void: payloads.append([a, t, c]))
	_play(ms, 4, {1: [&"attack"]}, [[1, 10]], {4: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(payloads, [[0, 1, PlayerState.NO_TELEGRAPH_COLOR]],
		"a melee parry carries the SENTINEL as its third argument (AC 13) — a colour-blind "
		+ "negation has no colour to report, and inventing one would make the cue lie")


func test_contact_on_grace_tick_still_deflects() -> void:
	var ms := _make_match()
	var deflects: Array = []
	_collect_deflects(ms, deflects)
	# t5 = the window closed in THIS tick's step 2 (+1 grace, R-N2): a t4 physics
	# contact arriving one tick late per F1 still deflects.
	_play(ms, 5, {1: [&"attack"]}, [[1, 10]], {5: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p2.hero.get_hp(), 100.0, "grace-tick contact still deflects — no damage")
	assert_eq(ms.p2.stamina.get_current(), 42.0, "grace-tick deflect still pays the cost")
	assert_eq(deflects, [[0, 1]], "grace-tick deflect emits deflect_landed")


func test_contact_first_tick_past_grace_is_an_ordinary_block() -> void:
	var ms := _make_match()
	var deflects: Array = []
	var hits: Array = []
	_collect_deflects(ms, deflects)
	_collect_hits(ms, hits)
	_play(ms, 6, {1: [&"attack"]}, [[1, 10]], {6: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p2.hero.get_hp(), 98.5, "block: damage x 0.25 (6.0 -> 1.5)")
	assert_eq(ms.p2.stamina.get_current(), 50.0, "an ordinary block spends nothing")
	assert_eq(ms.p1.mana.get_current(), 8.0, "a blocked hit is CONFIRMED: full flat mana to the attacker")
	assert_eq(deflects.size(), 0, "no deflect past the grace tick")
	assert_eq(hits, [[0, 1, 1.5, 98.5]], "hit_landed carries the REDUCED damage and remaining HP")


## ---- Facing gate (AC 1, AC 9, R-D3) -----------------------------------------------------

func test_back_facing_block_takes_full_damage() -> void:
	var ms := _make_match()
	# Attacker directly BEHIND the target (facing DOWN, fact dir UP): outside the arc.
	_play(ms, 6, {1: [&"attack"]}, [[1, 10]], {6: [[0, 1, 0, Vector2.UP]]})
	assert_eq(ms.p2.hero.get_hp(), 94.0, "back-facing block does not apply — full 6.0 damage")
	assert_eq(ms.p1.mana.get_current(), 8.0, "full hit is confirmed as usual")


func test_back_facing_inside_window_takes_full_damage() -> void:
	var ms := _make_match()
	var deflects: Array = []
	_collect_deflects(ms, deflects)
	_play(ms, 4, {1: [&"attack"]}, [[1, 10]], {4: [[0, 1, 0, Vector2.UP]]})
	assert_eq(ms.p2.hero.get_hp(), 94.0, "no parry from behind (R-D3): full damage despite the open window")
	assert_eq(ms.p2.stamina.get_current(), 50.0, "no deflect, no spend")
	assert_eq(deflects.size(), 0, "no deflect_landed from behind")


func test_facing_arc_half_width_both_sides_of_the_boundary() -> void:
	# Facing DOWN, arc 180 -> half-width 90 deg. A direction just AHEAD of perpendicular
	# is inside; just BEHIND it is outside. (The exact arc/2 ray is measure-zero float
	# rounding and deliberately not pinned — see _is_facing.)
	var inside := _make_match()
	_play(inside, 6, {1: [&"attack"]}, [[1, 10]], {6: [[0, 1, 0, Vector2(1.0, 0.01)]]})
	assert_eq(inside.p2.hero.get_hp(), 98.5, "just inside the half-arc: mitigated")
	var outside := _make_match()
	_play(outside, 6, {1: [&"attack"]}, [[1, 10]], {6: [[0, 1, 0, Vector2(1.0, -0.01)]]})
	assert_eq(outside.p2.hero.get_hp(), 94.0, "just outside the half-arc: full damage")


## Story 6-6a review (D2): `hit_landed_was_blocked()` answers, from INSIDE each `hit_landed` handler,
## whether THAT hit took the block branch -- so `block_impact` can be chosen for blocked hits only. A hit
## on a blocker from BEHIND (the facing arc fails, full damage) is on a BLOCKING hero but NOT blocked, and
## must read false; so must a hit on a hero that is not blocking at all. Outside an emission it is false.
##
## MUTATION PROOF: raise `blocked` on the BLOCKING test alone (dropping the `_is_facing` half) and the
## back-facing row reads true.
func test_hit_landed_reports_whether_that_hit_was_blocked() -> void:
	var rows := [
		["in the arc, past the grace tick", [[1, 10]], Vector2.DOWN, 1.5, true],
		["from behind, while blocking", [[1, 10]], Vector2.UP, 6.0, false],
		["not blocking at all", [], Vector2.DOWN, 6.0, false],
	]
	for row: Array in rows:
		var ms := _make_match()
		var seen: Array = []
		# The handler captures `ms` and sits in `ms`'s own connection list -- a reference cycle -- so it is
		# disconnected once the play is over.
		var record := func(_a: int, _t: int, damage: float, _hp: float) -> void:
			seen.append([damage, ms.hit_landed_was_blocked()])
		ms.hit_landed.connect(record)
		_play(ms, 6, {1: [&"attack"]}, row[1], {6: [[0, 1, 0, row[2]]]})
		ms.hit_landed.disconnect(record)
		assert_eq(seen, [[row[3], row[4]]],
			"%s: one hit_landed at %.1f damage, read as blocked == %s" % [row[0], row[3], row[4]])
		assert_false(ms.hit_landed_was_blocked(), "%s: ...and false again once the emission is over" % row[0])


## Story 6-8 (AC 5): WHILE UNLOCKED THE BLOCK ARC CAN BE DODGED BY TURNING AWAY again, because
## `_is_facing` reads the input-derived facing rather than one pinned to the lock. The attack comes
## from BEHIND P2's resting facing (DOWN; fact dir UP) in all three matches, and P2 is pushed a lock
## direction pointing AT the attacker in all three:
##   locked               -> facing tracks the lock onto the attacker -> blocked (98.5)
##   unlocked, turned away -> the lock fact is ignored, facing stays DOWN -> full damage (94.0)
##   unlocked, facing it   -> the same arc, facing the attacker -> blocked (98.5)
##
## MUTATION PROOF: delete the `elif not player.is_locked()` facing branch and the unlocked-turned-away
## match blocks, reading 98.5.
func test_an_unlocked_block_can_be_turned_away_from_and_a_facing_one_still_blocks() -> void:
	var locked := _make_match()
	locked.set_lock_direction(1, Vector2.UP)
	_play(locked, 6, {1: [&"attack"]}, [[1, 10]], {6: [[0, 1, 0, Vector2.UP]]})
	assert_eq(locked.p2.hero.get_hp(), 98.5, "locked: facing tracks the attacker, the block mitigates")
	var away := _make_match()
	away.set_lock_direction(1, Vector2.UP)
	away.p2.lock_target_slot = PlayerState.UNLOCKED_SLOT
	away.p2.lock_target_index = TargetingService.HERO_INDEX
	_play(away, 6, {1: [&"attack"]}, [[1, 10]], {6: [[0, 1, 0, Vector2.UP]]})
	assert_eq(away.p2.hero.get_hp(), 94.0, "unlocked and turned away: the hit from behind lands in full")
	var facing := _make_match()
	facing.set_lock_direction(1, Vector2.UP)
	facing.p2.lock_target_slot = PlayerState.UNLOCKED_SLOT
	facing.p2.lock_target_index = TargetingService.HERO_INDEX
	facing.p2.hero.facing = Vector2.UP
	_play(facing, 6, {1: [&"attack"]}, [[1, 10]], {6: [[0, 1, 0, Vector2.UP]]})
	assert_eq(facing.p2.hero.get_hp(), 98.5, "unlocked and facing the attacker: blocked")


## ---- R-D1 entry precondition / degrade path (AC 3, AC 9) --------------------------------

func test_entry_check_neither_spends_nor_restarts_regen_delay() -> void:
	var ms := _make_match()
	_play(ms, 1, {}, [[1, 10]])
	assert_eq(ms.p2.stamina.get_current(), 50.0, "BLOCKING entry is FREE — precondition check only")
	var delay: Dictionary = ms.p2.stamina.to_snapshot()["regen_delay"]
	assert_false(bool(delay["is_running"]), "entry never restarts the regen-delay window")


func test_insufficient_stamina_degrades_to_plain_block_with_rejection() -> void:
	var ms := _make_match(_config(4.0 / 60.0, 8.0, 5.0))  # pool max 5 < cost 8
	var rejections: Array = []
	var deflects: Array = []
	ms.p2.hero.action_rejected.connect(func(action: StringName, reason: StringName) -> void:
		rejections.append([action, reason]))
	_collect_deflects(ms, deflects)
	_play(ms, 4, {1: [&"attack"]}, [[1, 10]], {4: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING,
		"DEGRADE, not fallthrough: the block edge still fired")
	assert_eq(rejections, [[&"deflect", &"insufficient_stamina"]],
		"the rejection names deflect — the thing denied")
	assert_eq(ms.p2.hero.get_hp(), 98.5, "in-would-be-window contact resolves as a plain block (6.0 x 0.25)")
	assert_eq(deflects.size(), 0, "the window never opened")
	assert_eq(ms.p2.stamina.get_current(), 5.0, "nothing spent anywhere on the degraded path")


func test_degraded_entry_clears_a_stale_window_from_an_earlier_block() -> void:
	# Rapid re-block: an affordable press opens a LONG (20-tick) window; stamina then
	# drops below cost; a degraded re-press INSIDE the old span must start(0)-clear the
	# stale window rather than inherit it — window open must always mean window armed.
	var ms := _make_match(_config(20.0 / 60.0, 40.0))  # 20-tick window, cost 40
	_play(ms, 2, {}, [[1, 1]])                # t1: press (50 >= 40, window runs t1-20); t2: release
	assert_true(ms.p2.hero.is_deflect_window_open(), "long window still open after release")
	# Two rolls drop the pool below the deflect cost: t3 (-10, then delay t3-5 + regen
	# t6-8 -> 43) and t9 (-10 -> 33; regen t12-14 -> 36 < 40).
	_play_p2(ms, _intent([&"roll"]))          # t3
	for t in range(4, 9):
		_play_p2(ms)                          # roll runs t3-7, IDLE t8
	_play_p2(ms, _intent([&"roll"]))          # t9
	for t in range(10, 15):
		_play_p2(ms)                          # roll ends, regen t12-14
	assert_eq(ms.p2.stamina.get_current(), 36.0, "pool below the 40 cost at re-press time")
	var rejections: Array = []
	ms.p2.hero.action_rejected.connect(func(action: StringName, reason: StringName) -> void:
		rejections.append([action, reason]))
	_play_p2(ms, _intent([&"block"], [&"block"]))  # t15: degraded re-press, inside t1-20
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING, "block itself entered")
	assert_eq(rejections, [[&"deflect", &"insufficient_stamina"]], "window denied, loss legible")
	assert_false(ms.p2.hero.is_deflect_window_open(),
		"degraded entry start(0)-cleared the stale t1 window — it would otherwise run through t20")


func _play_p2(ms: MatchState, p2_intent: InputIntent = null) -> void:
	var i2 := p2_intent if p2_intent != null else InputIntent.new()
	var intents: Array[InputIntent] = [InputIntent.new(), i2]
	ms.advance(intents)
	ms.drain_signals()


## ---- R-D4 outcome registration: one resolution per swing per target (AC 4, AC 9) --------

func test_repeated_fact_same_swing_after_deflect_cannot_re_resolve() -> void:
	var ms := _make_match()
	var deflects: Array = []
	var hits: Array = []
	_collect_deflects(ms, deflects)
	_collect_hits(ms, hits)
	# t4: deflected. t6: the SAME swing's fact again, now past the window — without
	# R-D4 registration this would land as a blocked hit (the B4a hole).
	_play(ms, 7, {1: [&"attack"]}, [[1, 10]],
		{4: [[0, 1, 0, Vector2.DOWN]], 6: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p2.hero.get_hp(), 100.0, "a deflected swing's later facts are DROPPED — no damage ever")
	assert_eq(ms.p2.stamina.get_current(), 42.0, "one deflect, one spend")
	assert_eq(deflects.size(), 1, "one deflect_landed only")
	assert_eq(hits.size(), 0, "no hit_landed either — the swing is fully resolved")
	assert_eq(ms.p1.mana.get_current(), 0.0, "and no mana")


func test_repeated_fact_same_swing_after_block_damages_once() -> void:
	var ms := _make_match()
	_play(ms, 7, {1: [&"attack"]}, [[1, 10]],
		{6: [[0, 1, 0, Vector2.DOWN]], 7: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p2.hero.get_hp(), 98.5, "a blocked swing damages a given target at most once")
	assert_eq(ms.p1.mana.get_current(), 8.0, "and pays mana once")


## ---- R-N7: second swing inside one window, insufficient remaining stamina ---------------

func test_second_swing_in_same_window_degrades_to_block_when_pool_short() -> void:
	var config := _config(20.0 / 60.0, 30.0)  # 20-tick window, cost 30
	# STORY 5-6 (AC 9): THIS TEST NEEDS ITS ATTACKER BACK ON ITS FEET BY t9, so it authors a SHORT
	# 2-tick stun instead of the file's 11. The t4 deflect now STUNS P1 (AC 9), and at the file's
	# default length P1 would still be stunned at t9: the press would be dropped by the empty
	# `stunned` row, swing 1 would never exist, and its t12 fact would drop at dedupe — the test would
	# pass its first two assertions and measure NOTHING about R-N7.
	#
	# THE SUBJECT IS UNCHANGED AND SO IS EVERY NUMBER BELOW. R-N7 is a claim about the DEFENDER's pool
	# being short on a second deflect inside one window; how quickly the attacker recovers between its
	# two swings is fixture scaffolding, not the rule. The one visible difference is that swing 1 is
	# now a FRESH swing from IDLE rather than a chain from recovery — `attack_index` still increments
	# to 1, so the t12 fact addresses it exactly as before.
	config.deflect_stun_seconds = 2.0 / 60.0
	var ms := _make_match(config)
	var deflects: Array = []
	var hits: Array = []
	_collect_deflects(ms, deflects)
	_collect_hits(ms, hits)
	# Block held t1-20 (window runs t1-20). Swing 0 (attack t1): active t4-7, deflected
	# at t4 (50 - 30 = 20 left), P1 stunned t4-t6 and IDLE from t7. Attack t9 -> swing 1:
	# active t12-15; its t12 contact is INSIDE the still-open window but 20 < 30 — the
	# spend fails and the contact degrades to an ordinary block (graceful, R-N7).
	_play(ms, 13, {1: [&"attack"], 9: [&"attack"]}, [[1, 20]],
		{4: [[0, 1, 0, Vector2.DOWN]], 12: [[0, 1, 1, Vector2.DOWN]]})
	assert_eq(deflects, [[0, 1]], "first swing deflected")
	assert_eq(ms.p2.stamina.get_current(), 20.0, "only the first deflect paid")
	assert_eq(ms.p2.hero.get_hp(), 98.5, "second swing degraded to a block (6.0 x 0.25)")
	assert_eq(hits.size(), 1, "the degraded contact is a confirmed (blocked) hit")
	assert_eq(ms.p1.mana.get_current(), 8.0, "and pays its mana")


## ---- Story 5-6 (AC 9 / AC 10 / AC 11): the deflect's consequence for its ATTACKER --------
##
## The SECOND of `STUNNED`'s two authored inbound edges (the first is the colour-counter negation,
## test_unblockable_defense.gd). `4-3b/R7`'s negative guard — deflecting a MINION stuns nothing —
## sits directly below, RE-RUN UNEDITED as this story's own proof that the hero-only gate holds.

## AC 9: a deflected HERO attacker is stunned for the authored duration and drained by the authored
## penalty, both read inline from the injected balance (CONSTRAINT C). The DEFENDER is untouched
## beyond the deflect cost it already paid.
func test_a_deflected_hero_attacker_is_stunned_and_drained() -> void:
	# REGEN OFF for this one, so the stamina assertion is the PENALTY and nothing else. With the
	# file's default 1.0/tick the pool sits clamped at its maximum until the penalty lands and then
	# regains a point in the same tick's step 5 -- true, but it would make this assertion read as an
	# off-by-one rather than as the penalty. The regen INTERACTION is the next test's subject.
	var config := _config()
	config.stamina_regen_per_second = 0.0
	var ms := _make_match(config)
	var before := ms.p1.stamina.get_current()
	_play(ms, 5, {1: [&"attack"]}, [[1, 10]], {5: [[0, 1, 0, Vector2.DOWN]]})
	assert_true(ms.p1.hero.stun.is_running, "the deflected ATTACKER is stunned (AC 9)...")
	assert_eq(ms.p1.hero.stun.remaining_ticks(), DEFLECT_STUN_TICKS,
		"...for the authored deflect duration, converted through BalanceTicks (AC 1)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"...with the state write landing in the same breath")
	assert_eq(ms.p1.stamina.get_current(), before - DEFLECT_PENALTY,
		"...and drained by deflect_stamina_penalty — NOT deflect_stamina_cost, which is a different "
		+ "field the DEFENDER pays (AC 2)")
	assert_false(ms.p2.hero.stun.is_running, "the DEFENDER is not stunned...")
	assert_ne(ms.p2.hero.action_state, HeroState.ActionState.STUNNED,
		"...on either half: deflecting is the reward, not a cost")


## AC 10, THE HALF A MAGNITUDE ASSERTION CANNOT SEE: the drain is `add(-x)`, not `spend(...)`, and
## the two differ on exactly two observable points. Both are asserted, because either one alone would
## pass against the wrong mechanism in some fixture.
##   (i) AN UNAFFORDABLE PENALTY STILL APPLIES, floored at zero. `spend()` REFUSES outright when the
##       amount exceeds the balance and changes nothing — so a stamina-starved attacker would escape
##       the penalty entirely, the exact opposite of `E5-P/R1`'s intent.
##  (ii) IT DOES NOT RESTART THE REGEN DELAY. Only `spend()` does. The penalty is a consequence, not
##       a cost, so it moves the current balance and leaves the regen cadence alone.
func test_the_deflect_penalty_is_a_punitive_drain_not_a_refusable_spend() -> void:
	var no_regen := _config()
	no_regen.stamina_regen_per_second = 0.0
	var poor := _make_match(no_regen)
	poor.p1.stamina.spend(poor.p1.stamina.get_current() - 1.0, 0)   # 1.0 left, far under the penalty
	poor.drain_signals()
	_play(poor, 5, {1: [&"attack"]}, [[1, 10]], {5: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(poor.p1.stamina.get_current(), 0.0,
		"an UNAFFORDABLE penalty still applies, floored at zero (AC 10) -- `spend()` would have "
		+ "refused and left 1.0, letting a poor attacker escape the punish entirely")
	# (ii) THE REGEN CADENCE, on the file's DEFAULT config (1.0/tick, 3-tick post-spend delay). The
	# pool sits clamped at its 50.0 maximum until t5, where the penalty lands at step 4 and that
	# tick's regen at step 5: 50 - 13 + 1 = 38, then 39 at t6. UNDER `spend()` BOTH READINGS WOULD BE
	# 37.0 -- the spend would restart the 3-tick delay and suppress regen across t5-t7 -- so either
	# assertion alone distinguishes the two mechanisms, and both are pinned.
	var ms := _make_match()
	_play(ms, 5, {1: [&"attack"]}, [[1, 10]], {5: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p1.stamina.get_current(), 38.0,
		"t5: the penalty (13) AND that tick's regen (+1) both land, off a pool clamped at 50")
	_play(ms, 1)   # ONE further tick (`_play` counts ticks to run, not an absolute tick index)
	assert_eq(ms.p1.stamina.get_current(), 39.0,
		"t6: regen runs the very NEXT tick too -- the penalty did not restart the 3-tick regen "
		+ "delay, which is what `add()` buys over `spend()` (AC 10); `spend()` reads 37.0 at both")


## AC 11: THE ORPHANED-SWING HOLE, closed at the SOURCE. The stun replaces ATTACKING while the swing's
## `active` window is still running, and that window is deliberately never early-stopped (`1-9/R3`) —
## so before this story a hitbox query against it would still have gathered contact facts from a hero
## the game was simultaneously punishing for that very swing.
##
## THE ASSERTION IS ON `is_hitbox_active()` BECAUSE THAT PREDICATE IS THE WHOLE GATE: it is the ONLY
## question `match_runner.gd::_gather_contact_facts` asks before querying overlaps, and it has exactly
## one consumer. A false predicate is the fact being dropped at the SOURCE — no fact is produced at
## all, which is strictly stronger than a fact dropped downstream at dedupe.
##
## THE DEDUPE FACT IS RESTATED rather than relied on, because it is what would MASK a missing fix:
## the deflected fact already consumed this swing's dedupe record for that target, so a second fact
## from the orphaned window would be refused downstream anyway — against THAT target. The source-level
## drop is what protects every OTHER target the orphaned window could still reach.
func test_a_stunned_attackers_orphaned_active_window_reports_no_hitbox() -> void:
	var ms := _make_match()
	_play(ms, 5, {1: [&"attack"]}, [[1, 10]], {5: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "precondition: stunned at t5")
	assert_true(ms.p1.hero.active.is_running,
		"precondition: the swing's ACTIVE window is STILL RUNNING (t4-7) — never early-stopped, "
		+ "`1-9/R3` intact")
	assert_false(ms.p1.hero.is_hitbox_active(),
		"the orphaned window reports NO hitbox, so the runner never queries it and no further fact "
		+ "is produced AT THE SOURCE (AC 11)")
	assert_false(ms.p1.hero.register_swing_hit(ms.p1.hero.attack_index, 1, -1),
		"...and the dedupe record for this swing/target was already consumed by the deflected fact — "
		+ "restated so it is clear this test does NOT rely on it: dedupe protects only the target "
		+ "already hit, while the source-level drop protects every other")


## AC 11's control, and it is what makes the assertion above non-vacuous: on the very same fixture
## with NO deflect, the same window at the same tick DOES report a live hitbox.
func test_an_undeflected_attackers_active_window_still_reports_a_hitbox() -> void:
	var ms := _make_match()
	_play(ms, 5, {1: [&"attack"]})
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ATTACKING, "no deflect, still ATTACKING")
	assert_true(ms.p1.hero.active.is_running, "the same window at the same tick...")
	assert_true(ms.p1.hero.is_hitbox_active(), "...reports a live hitbox (AC 11 gates on the STATE)")


## M1 (5-6 fix pass, review finding, ACCEPTED + PINNED on the `2-3/R13` DEAD-velocity precedent):
## the two `STUNNED` entry points root the hero on DIFFERENT ticks. The color-counter stun is
## written inside `_resolve_actions` (step 3), strictly BEFORE that same player's step-3
## `_resolve_movement` call, so AC 14's hard root takes effect the SAME tick the stun is entered —
## rooted same-tick. The melee-deflect stun, by contrast, is written inside `_resolve_contacts`
## (step 4), which runs strictly AFTER both players' step-3 `_resolve_movement` calls for that tick
## — so a hero mid-swing keeps THAT tick's attack-lunge velocity for one full extra tick, and the
## hard root only takes effect on the FOLLOWING tick's `_resolve_movement`. This is INTENTIONAL, not
## a defect: zeroing velocity at the step-4 entry point would smear the rooting decision into a
## THIRD function (`_resolve_contacts` reaching into a field `_resolve_movement` owns), and it is
## invisible at 60 Hz — the same shape this codebase already accepts for `DEAD`'s one-tick carry
## (`2-3/R13`, `test_round_over_freezes_resolution_until_reset` pins it the identical way: nonzero
## velocity on the kill tick, zeroed the tick after). The color-counter entry is the ASYMMETRIC
## sibling: it roots same-tick because step 3 (where it is written) runs BEFORE that tick's own
## `_resolve_movement`, not because it is more careful — the ordering, not the mechanism, is what
## differs.
##
## `attack_lunge_distance` IS AUTHORED NONZERO LOCALLY, ONLY HERE: the file's shared `_config()`
## leaves it at its declared default (0.0, no lunge), which is why no other test in this file can
## see this asymmetry — a zero lunge makes the residual velocity zero too, indistinguishable from an
## already-rooted hero. A nonzero lunge is the only way to observe the carry at all.
func test_a_melee_deflect_stun_carries_one_ticks_residual_lunge_velocity_then_zeroes() -> void:
	var config := _config()
	config.attack_lunge_distance = 3.0
	var ms := _make_match(config)
	_play(ms, 4, {1: [&"attack"]}, [[1, 10]], {4: [[0, 1, 0, Vector2.DOWN]]})
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"precondition: deflected and stunned on entry (t4), same fixture as the AC 9 test above")
	assert_false(ms.p1.hero.velocity.is_zero_approx(),
		"the ENTRY tick keeps this tick's attack-lunge velocity — step 4's stun write ran strictly "
		+ "AFTER this tick's own step-3 _resolve_movement, so the hard root has not applied yet "
		+ "(the 2-3/R13 shape, M1)")
	_play(ms, 1)   # ONE further tick (_play counts ticks to run, not an absolute tick index)
	assert_true(ms.p1.hero.velocity.is_equal_approx(Vector3.ZERO),
		"...and is a literal zero on the very NEXT tick's _resolve_movement, once STUNNED is live "
		+ "for that tick's own step 3")


## ---- D5 queue discipline (AC 2) ---------------------------------------------------------

func test_deflect_landed_is_queued_never_emitted_mid_advance() -> void:
	var ms := _make_match()
	var deflects: Array = []
	_collect_deflects(ms, deflects)
	_play(ms, 3, {1: [&"attack"]}, [[1, 10]])
	ms.push_contact([0, -1], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	var intents: Array[InputIntent] = [InputIntent.new(), _intent([], [&"block"])]
	ms.advance(intents)  # t4: deflect resolves — signal must stay queued
	assert_eq(deflects.size(), 0, "deflect_landed is QUEUED during advance (D5)")
	ms.drain_signals()
	assert_eq(deflects, [[0, 1]], "and drains after advance returns")


## ---- R-B5: hot-reload meaning (AC 7) ----------------------------------------------------

func test_reload_keeps_inflight_window_and_next_block_picks_up_new_ticks() -> void:
	var ms := _make_match()  # window 4 ticks
	var deflects: Array = []
	_collect_deflects(ms, deflects)
	# Phase 1 — in-flight window keeps its duration: block pressed t1 (window t1-4,
	# grace t5); reload to an 8-tick window MID-BLOCK at t3; the t6 contact must still
	# resolve as an ordinary BLOCK (an 8-tick rescale would have deflected it).
	_play(ms, 2, {1: [&"attack"]}, [[1, 6]])
	ms.apply_balance(_config(8.0 / 60.0))  # X3 seam, mid-match (D9 refill included)
	ms.drain_signals()
	_play_range(ms, 3, 5, {}, [[1, 6]])
	ms.push_contact([0, -1], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_play_range(ms, 6, 6, {}, [[1, 6]])
	assert_eq(deflects.size(), 0, "in-flight window kept its 4 ticks across the reload")
	assert_eq(ms.p2.hero.get_hp(), 98.5, "t6 contact blocked (1-1 reload principle)")
	# Phase 2 — the NEXT enter_block reads the new balance_ticks: re-press at t14
	# (new window t14-21 + grace t22; the OLD 4-tick length would have closed by t18).
	# Fresh P1 swing at t14: windup t14-16, active t17-20; contact at t20.
	_play_range(ms, 7, 13, {}, [])
	_play_range(ms, 14, 19, {14: [&"attack"]}, [[14, 21]])
	ms.push_contact([0, -1], [1, -1], ms.p1.hero.attack_index, Vector2.DOWN, MatchState.CONTACT_STRIKE)
	_play_range(ms, 20, 20, {}, [[14, 21]])
	assert_eq(deflects, [[0, 1]], "next enter_block picked up the reloaded 8-tick window (t20 deflects)")


## Advance ticks [from, to] with the same shape _play uses (press fires on a range's
## first tick even when entered mid-run).
func _play_range(ms: MatchState, from_tick: int, to_tick: int, p1_press := {},
		p2_block_ranges := []) -> void:
	for t in range(from_tick, to_tick + 1):
		var i1 := _intent(p1_press.get(t, []))
		var held := _in_ranges(t, p2_block_ranges)
		var pressed2: Array = [&"block"] if held and not _in_ranges(t - 1, p2_block_ranges) else []
		var i2 := _intent(pressed2, [&"block"] if held else [])
		var intents: Array[InputIntent] = [i1, i2]
		ms.advance(intents)
		ms.drain_signals()


## ================================================================================================
## STORY 4-3b (AC 9 / AC 10): the hero's defensive ladder against a MINION's attack.
## ================================================================================================

func _config_4_3b() -> BalanceConfig:
	var c := _config()
	# Story 4-4 (AC 6/AC 9): per-kind now. Same in-test literals, new shape (see UnitKindFixture).
	c.unit_kinds = UnitKindFixture.minion_only(9.0, 3.0, 2, 3, 4, 2.0)
	c.hero_damage_to_unit = 3.0
	c.minion_retarget_interval_seconds = 1000.0
	return c


## P1 gets one unit in its ACTIVE window, through the real reach trigger and phase ladder.
func _p1_unit_into_active_4_3b(ms: MatchState) -> void:
	ms.p1.units.add(9.0, 0)
	ms.p1.units.set_target_at(0, 1, -1)
	ms.push_contact([0, 0], [1, -1], 0, Vector2.DOWN, MatchState.CONTACT_REACH_PROBE)
	_step(ms, {})
	_step(ms, {})
	for _t in 2:
		_step(ms, {})


func _match_4_3b() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config_4_3b())
	var f := FeatureFlags.new()
	f.minions = true
	ms.inject_feature_flags(f)
	ms.drain_signals()
	return ms


## One tick with the given per-slot pressed actions.
func _step(ms: MatchState, presses: Dictionary) -> void:
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	for slot: int in presses:
		for action: StringName in presses[slot]:
			intents[slot].pressed[action] = true
			intents[slot].held[action] = true
	ms.advance(intents)
	ms.drain_signals()


## AC 9: the hero's defensive ladder applies to a minion's attack UNCHANGED. Three rungs, three
## measurements, all against the SAME unit-sourced fact, plus an undefended control so each
## reduction is measured against what the attack would otherwise have done.
func test_the_hero_defensive_ladder_applies_unchanged_to_a_unit_attack() -> void:
	# (i) UNDEFENDED control -- the full damage a unit attack does.
	var undefended := _match_4_3b()
	_p1_unit_into_active_4_3b(undefended)
	var full_before := undefended.p2.hero.get_hp()
	undefended.push_contact([0, 0], [1, -1], undefended.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_step(undefended, {})
	var full_damage := full_before - undefended.p2.hero.get_hp()
	assert_true(full_damage > 0.0, "sanity: an undefended unit attack lands full damage")

	# (ii) DEFLECT: fully negated, deflect_landed queued, the cost spent.
	var deflecting := _match_4_3b()
	_p1_unit_into_active_4_3b(deflecting)
	var deflects: Array = []
	deflecting.deflect_landed.connect(func(a: int, t: int, _c: int) -> void: deflects.append([a, t]))
	var stamina_before := deflecting.p2.stamina.get_current()
	var hp_before := deflecting.p2.hero.get_hp()
	deflecting.push_contact([0, 0], [1, -1], deflecting.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_step(deflecting, {1: [&"block"]})
	assert_eq(deflecting.p2.hero.get_hp(), hp_before,
		"DEFLECT fully negates a minion's attack, exactly as it does a hero's (AC 9)")
	assert_eq(deflects.size(), 1, "...and queues deflect_landed")
	assert_eq(deflects[0][0], 0,
		"...whose attacker payload is the BARE SLOT, unwidened (`4-3b/R15`)")
	assert_true(deflecting.p2.stamina.get_current() < stamina_before,
		"...and spends the deflect cost at LANDING, the shipped per-fact policy")

	# (iii) BLOCK without the stamina to deflect: the multiplier applies.
	var blocking := _match_4_3b()
	_p1_unit_into_active_4_3b(blocking)
	blocking.p2.stamina.spend(blocking.p2.stamina.get_current(), 0)
	var block_before := blocking.p2.hero.get_hp()
	blocking.push_contact([0, 0], [1, -1], blocking.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_step(blocking, {1: [&"block"]})
	var blocked_damage := block_before - blocking.p2.hero.get_hp()
	assert_true(blocked_damage > 0.0, "BLOCK reduces rather than negates...")
	assert_true(blocked_damage < full_damage,
		"...and the reduction is real, measured against the undefended control (AC 9)")


## AC 10 (`4-3b/R7`), a NEGATIVE GUARD: deflecting a minion does NOT stun it, for now. The `stun`
## field keeps ZERO inbound edges and this story does not open one; the open decision on stun stays
## open.
##
## MEASURED AS A COMPARISON RATHER THAN AS AN ABSOLUTE: the deflected unit's phase state and
## countdown must sit EXACTLY where the undeflected case leaves them. An absolute assertion
## ("the unit is in RECOVERY") would pass against an implementation that stunned BOTH.
func test_deflecting_a_minion_leaves_its_rhythm_exactly_where_an_undeflected_swing_does() -> void:
	var deflected := _rhythm_after_swing(true)
	var undeflected := _rhythm_after_swing(false)
	assert_eq(deflected["deflects"], 1, "sanity: the deflected run really did deflect...")
	assert_eq(undeflected["deflects"], 0, "...and the control run really did not")
	assert_eq(deflected["phase"], undeflected["phase"],
		"a deflected minion's PHASE is exactly where an undeflected swing leaves it — no stun edge "
		+ "opens (AC 10, `4-3b/R7`)")
	assert_eq(deflected["ticks"], undeflected["ticks"],
		"...and so is its COUNTDOWN, to the tick: nothing was frozen, extended or cut short")
	assert_eq(deflected["count"], undeflected["count"],
		"...and its swing counter, so the rhythm was not restarted either")
	# STORY 5-6 (AC 9): THE ASSERTION THAT MAKES THE HERO-ONLY GATE FALL. The three above are about
	# the UNIT, and a unit has no `ActionState` or `stun` field to enter -- so they stay green even
	# against an implementation that dropped `attacker_index == HERO_INDEX` entirely, because that
	# implementation would stun the OWNING HERO instead (`attacker` is the PlayerState either way).
	# `4-3b/R7` is a claim about the minion's swing being unpunished, and punishing its owner would
	# violate it just as surely.
	assert_false(deflected["owner_stunned"],
		"deflecting a MINION does not stun its OWNER'S HERO either (AC 9's `HERO_INDEX` gate) -- "
		+ "`attacker` is the PlayerState for a unit-sourced fact too, so without that gate the hero "
		+ "behind the minion would take the punish for a swing it never made")
	assert_eq(deflected["owner_stamina"], undeflected["owner_stamina"],
		"...and its owner's STAMINA is exactly where an undeflected swing leaves it: no penalty either")


## One unit swing against P2, deflected or not, reported as the unit's rhythm state a few ticks on.
func _rhythm_after_swing(deflect: bool) -> Dictionary:
	var ms := _match_4_3b()
	_p1_unit_into_active_4_3b(ms)
	var deflects: Array = []
	ms.deflect_landed.connect(func(a: int, t: int, _c: int) -> void: deflects.append([a, t]))
	if not deflect:
		# The control run must differ ONLY in whether the fact was deflected, so P2 still BLOCKS --
		# it simply cannot afford the deflect and the hit degrades to a block.
		ms.p2.stamina.spend(ms.p2.stamina.get_current(), 0)
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_step(ms, {1: [&"block"]})
	_step(ms, {})
	return {
		"phase": ms.p1.units.attack_phase_at(0),
		"ticks": ms.p1.units.attack_ticks_at(0),
		"count": ms.p1.units.attack_count_at(0),
		"deflects": deflects.size(),
		# Story 5-6 (AC 9): the OWNER's own state, so the hero-only gate is measurable from here.
		"owner_stunned": ms.p1.hero.stun.is_running
				or ms.p1.hero.action_state == HeroState.ActionState.STUNNED,
		"owner_stamina": ms.p1.stamina.get_current(),
	}
