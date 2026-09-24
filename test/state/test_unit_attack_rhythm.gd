extends TestCase

## Story 4-3b coverage: the unit as ATTACKER — the windup/active/recovery rhythm, the reach trigger
## that starts it, the direction it locks, the cleave it registers, and the canonical order several
## attackers resolve in.
##
## WHAT THIS FILE OWNS, per AC: the phase progression at the authored tick counts (AC 1); the CLEAVE
## and its canonical sort-on-insertion (AC 4); the cross-attacker canonical ORDER (AC 5); no stamina
## and no resource cost (AC 11, negative guard); the direction LOCK and the complete-into-empty-air
## path (AC 12); the whole reach trigger — never a free-running cycle, a probe applying zero damage,
## the back-to-back cycle with no throttle remainder, and the acquired-target scoping (AC 13); and
## the round trip of every new field through `to_snapshot()` (AC 16).
##
## WHAT IT DELIBERATELY DOES NOT OWN. The PROBE'S CADENCE is a RUNNER property — the throttle is a
## runner-local counter over `minion_retarget_interval_ticks` and a headless MatchState has no
## runner to run it — so the "one probe per interval, not one per tick" pin lives in
## test/integration/test_unit_combat_live.gd, together with AC 2 (a real hitbox overlap), AC 6 (the
## GATHER-time friendly-fire filter) and AC 17's live half. The attacker-kind dispatch of AC 14/15 is
## test_contact_resolution.gd's and test_unit_damage_and_death.gd's.
##
## Test balance is constructed IN-TEST and never loaded from `data/balance/*.tres` (the BC/R3
## isolation). The three minion durations are 3 / 4 / 6 ticks and are DELIBERATELY ALL DIFFERENT and
## deliberately unlike the hero's 5 / 7 / 9 in the same fixture: a phase-progression test whose
## durations coincided would pass against an implementation that read the wrong field.

const UNIT_WINDUP := 3
const UNIT_ACTIVE := 4
const UNIT_RECOVERY := 6
const UNIT_CYCLE := UNIT_WINDUP + UNIT_ACTIVE + UNIT_RECOVERY

const UNIT_MAX_HP := 9.0
const UNIT_DAMAGE := 3.0

## The fact direction every probe below carries: TARGET-to-ATTACKER, which is what `push_contact`
## documents its fourth argument to be. The locked attack direction must therefore come back NEGATED
## (AC 12's "PRECISION, measured" clause), and this value is deliberately NOT symmetric under
## negation so the two cannot be confused.
const PROBE_DIR := Vector2(0.6, 0.8)
const LOCKED_DIR := Vector2(-0.6, -0.8)


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 0.0     # AC 11's negative guard needs a pool that cannot drift
	c.stamina_regen_delay_seconds = 1.0 / 60.0
	c.attack_windup_seconds = 5.0 / 60.0
	c.attack_active_seconds = 7.0 / 60.0
	c.attack_recovery_seconds = 9.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 10.0
	c.attack_stamina_cost = 5.0
	c.roll_stamina_cost = 5.0
	c.deflect_stamina_cost = 8.0
	c.max_mana = 80.0
	c.melee_hit_mana = 8.0
	c.mana_regen_per_second = 0.0        # AC 11's negative guard, mana half
	c.block_damage_multiplier = 0.5
	c.block_facing_arc_degrees = 180.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.minion_retarget_interval_seconds = 1000.0  # never a boundary tick: no test here retargets
	# Story 4-4 (AC 6/AC 9): the six flat fields this block used to set are PER KIND now. Every value
	# is still an in-test literal (the `BC/R3` isolation, unchanged) — what moved is the SHAPE, and
	# `UnitKindFixture` owns the shape so twelve fixtures do not each hand-roll two resources.
	# `hero_damage_to_unit` is the hero-attacker half of the old `unit_damage_per_hit`; the unit
	# half rides the kind's attack record.
	c.unit_kinds = UnitKindFixture.minion_only(UNIT_MAX_HP, UNIT_DAMAGE, UNIT_WINDUP, UNIT_ACTIVE,
			UNIT_RECOVERY, 2.0)  # reach read by the RUNNER only; inert in a headless fixture
	c.hero_damage_to_unit = UNIT_DAMAGE
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	f.minions = true
	return f


func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(11))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags())
	ms.drain_signals()
	return ms


func _intent(pressed_keys: Array = [], held_keys: Array = []) -> InputIntent:
	var i := InputIntent.new()
	for k in pressed_keys:
		i.pressed[k] = true
		i.held[k] = true
	for k in held_keys:
		i.held[k] = true
	return i


func _advance(ms: MatchState, p1_intent: InputIntent = null,
		p2_intent: InputIntent = null) -> void:
	var intents: Array[InputIntent] = [
		p1_intent if p1_intent != null else InputIntent.new(),
		p2_intent if p2_intent != null else InputIntent.new(),
	]
	ms.advance(intents)
	ms.drain_signals()


## One unit on P1's board that has ACQUIRED the given target. Straight onto the board rather than
## through a cast, the `test_targeting_service.gd::_summon` idiom: these tests are about what a unit
## DOES once it exists, and the step-6 cast seat has its own coverage elsewhere.
func _summon_p1(ms: MatchState, target: Array[int] = [1, -1]) -> int:
	var index := ms.p1.units.size()
	ms.p1.units.add(UNIT_MAX_HP, 0)
	ms.p1.units.set_target_at(index, target[0], target[1])
	return index


## Push one REACH PROBE from P1's unit `index` against `target`, then advance. The flag is set at
## step 4 of THIS tick, so the windup can only begin on the NEXT one (the F1 lag the Dev Notes name).
func _probe(ms: MatchState, index: int, target: Array[int] = [1, -1],
		dir: Vector2 = PROBE_DIR) -> void:
	ms.push_contact([0, index], target, ms.p1.units.attack_count_at(index), dir,
			MatchState.CONTACT_REACH_PROBE)
	_advance(ms)


func _phase(ms: MatchState, index := 0) -> int:
	return ms.p1.units.attack_phase_at(index)


## ---- AC 1: the phase progression at the AUTHORED tick counts ---------------------------------

## AC 1's core, walked tick by tick against three DIFFERENT authored durations, so an implementation
## that read the wrong field (or the hero's) fails rather than coincides.
##
## THE TICK ARITHMETIC, stated so the numbers below are checkable rather than transcribed: a windup
## begun at step 3 of tick T sets its countdown AFTER tick T's step-2 decrement, so the countdown
## reaches zero at tick T + windup and the phase moves THERE. End-of-tick phases are therefore
## WINDUP for `windup` ticks, then ACTIVE for `active`, then RECOVERY for `recovery`.
func test_a_unit_walks_windup_then_active_then_recovery_at_the_authored_ticks() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.IDLE, "a freshly summoned unit is IDLE")
	_probe(ms, 0)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.IDLE,
		"the probe's own tick does NOT start the windup — the flag is set at step 4 and read at "
		+ "step 3 of the NEXT tick (the F1 one-tick lag applies to a probe exactly as to a strike)")
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.WINDUP, "the windup begins one tick after reach")
	for i in UNIT_WINDUP - 1:
		_advance(ms)
		assert_eq(_phase(ms), UnitBoard.AttackPhase.WINDUP,
			"still winding up %d tick(s) in (authored windup is %d)" % [i + 2, UNIT_WINDUP])
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.ACTIVE,
		"the ACTIVE window opens exactly `minion_attack_windup_ticks` ticks after the windup began")
	for i in UNIT_ACTIVE - 1:
		_advance(ms)
		assert_eq(_phase(ms), UnitBoard.AttackPhase.ACTIVE,
			"still active %d tick(s) in (authored active is %d)" % [i + 2, UNIT_ACTIVE])
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.RECOVERY,
		"RECOVERY opens exactly `minion_attack_active_ticks` ticks after the window did")
	for i in UNIT_RECOVERY - 1:
		_advance(ms)
		assert_eq(_phase(ms), UnitBoard.AttackPhase.RECOVERY,
			"still recovering %d tick(s) in (authored recovery is %d)" % [i + 2, UNIT_RECOVERY])
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.IDLE,
		"and it returns to IDLE — with no further reach fact it stops there rather than cycling")


## The counter is MONOTONIC and it is the UNIT'S OWN — never the owner hero's (`4-3b/R12`). Both
## directions in one test: the unit's counter advances per swing, and the owner hero's `attack_index`
## does not move at all, which is the measured reason the unit could not share it (the hero's counter
## is snapshotted, so driving it from unit swings would move hero-observed values).
func test_the_swing_counter_is_the_units_own_and_the_heros_never_moves() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	var hero_index_before := ms.p1.hero.attack_index
	assert_eq(ms.p1.units.attack_count_at(0), 0, "a unit that has never swung is at zero")
	_probe(ms, 0)
	_advance(ms)
	assert_eq(ms.p1.units.attack_count_at(0), 1, "the first windup advances the unit's own counter")
	# Refresh inside the active window so the next cycle begins the instant recovery ends.
	for _t in UNIT_WINDUP - 1:
		_advance(ms)
	_probe(ms, 0)
	for _t in UNIT_ACTIVE + UNIT_RECOVERY:
		_advance(ms)
	assert_eq(ms.p1.units.attack_count_at(0), 2, "...and the second swing advances it again")
	assert_eq(ms.p1.hero.attack_index, hero_index_before,
		"the OWNER HERO's attack_index never moved — a unit does not share it (`4-3b/R12`), and it "
		+ "is snapshotted, so driving it from unit swings would be an unnamed golden cause")


## ---- AC 13: the reach trigger -----------------------------------------------------------------

## AC 13's NON-VACUOUS HALF, and the one a free-running implementation fails EXACTLY here: a unit
## with an acquired target and NO reach fact never leaves IDLE, no matter how long it stands there.
##
## Driven for three full cycles' worth of ticks, so "it just had not got there yet" is excluded.
func test_a_unit_with_no_reach_fact_never_leaves_idle() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	for _t in UNIT_CYCLE * 3:
		_advance(ms)
		assert_eq(_phase(ms), UnitBoard.AttackPhase.IDLE,
			"a unit with an acquired target but no reach fact NEVER winds up — the trigger is the "
			+ "fact, never a free-running cycle and never an 'arrived' flag (AC 13, `4-3b/R17a`)")
	assert_false(ms.p1.units.is_in_reach_at(0), "...and its in-reach flag was never set")
	# THE POSITIVE TWIN, so the assertion above is not "this fixture can never wind up at all".
	_probe(ms, 0)
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.WINDUP,
		"...and one reach fact is all it takes, so the negative above is a statement about the "
		+ "TRIGGER rather than about this fixture")


## AC 13: A PROBE APPLIES NOTHING. It is dropped at the very top of the ladder — no damage, no
## dedupe registration, no confirmed hit and therefore no mana, and no signal — and its ONLY effect
## is the flag. Measured against a target that a STRIKE would visibly damage.
func test_a_reach_probe_applies_no_damage_no_mana_and_no_signal() -> void:
	var ms := _make_match()
	_summon_p1(ms, [1, 0])
	ms.p2.units.add(UNIT_MAX_HP, 0)
	var hp_before := ms.p2.units.hp_at(0)
	var mana_before := ms.p1.mana.get_current()
	var hits: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, h: float) -> void:
		hits.append([a, t, d, h]))
	_probe(ms, 0, [1, 0])
	assert_eq(ms.p2.units.hp_at(0), hp_before,
		"a REACH PROBE applies ZERO damage — it is dropped ahead of every resolution rung")
	assert_eq(ms.p1.mana.get_current(), mana_before,
		"...generates no mana, because it never reaches the confirmed-hits list")
	assert_eq(hits.size(), 0, "...and emits no signal")
	assert_true(ms.p1.units.is_in_reach_at(0),
		"...while its ONE effect DID happen: the in-reach flag is set (so the three negatives "
		+ "above are not simply a fact that failed to arrive)")
	# ------------------------------------------------------------------------------------------
	# THE SECOND PHASE IS WHAT MAKES THIS NON-VACUOUS, and it was added because the first phase
	# alone did NOT fall under mutation (M9: the probe drop deleted). An IDLE unit has no open
	# dedupe record, so a probe that fell through the drop would be refused by the REGISTRAR one
	# rung later and still apply nothing -- the test passed for the wrong reason.
	#
	# So the probe is repeated MID-ACTIVE-WINDOW, against an address this swing has not yet
	# registered. Now every rung below the drop would ACCEPT it, and only the drop itself stands
	# between the probe and real damage. M9 falls here.
	# ------------------------------------------------------------------------------------------
	ms.p2.units.add(UNIT_MAX_HP, 0)                     # a second, un-hit address at [1, 1]
	_advance(ms)                                     # the windup begins
	for _t in UNIT_WINDUP:
		_advance(ms)
	assert_true(ms.p1.units.is_hitbox_active_at(0),
		"sanity: the unit's window is open, so a live dedupe record exists")
	var bystander_hp := ms.p2.units.hp_at(1)
	ms.push_contact([0, 0], [1, 1], ms.p1.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(1), bystander_hp,
		"a PROBE arriving mid-swing against an address the swing has NOT yet registered still "
		+ "applies nothing — it is dropped at the TOP of the ladder, ahead of the dead-target drop "
		+ "and the registrar, and never reaches `_resolve_unit_contact` (AC 13, `4-3b/R17b`)")
	# ...and the PAIR: the identical fact marked as a STRIKE DOES land, so the zero above is about
	# the KIND MARKER and not about that address being unreachable.
	ms.push_contact([0, 0], [1, 1], ms.p1.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(1), bystander_hp - UNIT_DAMAGE,
		"...while the SAME fact marked CONTACT_STRIKE lands, which is what makes the drop above a "
		+ "statement about the marker rather than about the address")


## AC 13's BACK-TO-BACK PIN, and the one that fails against the rejected idle-only variant: the tick
## gap between two consecutive swings is EXACTLY windup + active + recovery, with NO throttle
## remainder added.
##
## RUN WITH THE REFRESHING FACT INSIDE THE ACTIVE WINDOW, because that is the arrangement the refresh
## hole lives in: the fact's KIND is decided by PHASE, so a throttle tick landing inside an active
## window produces a STRIKE rather than a probe. An implementation that refreshed the flag only from
## PROBES would find the flag clear when recovery ended and would stall until the next probe — the
## same jitter the flag exists to remove, merely less often.
func test_two_consecutive_swings_are_exactly_one_cycle_apart_with_no_throttle_remainder() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	_probe(ms, 0)
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.WINDUP, "sanity: swing one has begun")
	var first_swing := ms.p1.units.attack_count_at(0)
	var ticks := 0
	var second_swing_at := -1
	# Drive two cycles' worth of ticks, refreshing ONCE from inside the active window and never
	# again, and record the tick the counter advances on.
	for _t in UNIT_CYCLE * 2:
		if _phase(ms) == UnitBoard.AttackPhase.ACTIVE and ms.p1.units.attack_count_at(0) == first_swing:
			# A STRIKE, not a probe — this is what the same overlap produces while the window is open.
			ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), PROBE_DIR,
					MatchState.CONTACT_STRIKE)
		_advance(ms)
		ticks += 1
		if second_swing_at == -1 and ms.p1.units.attack_count_at(0) > first_swing:
			second_swing_at = ticks
	assert_eq(second_swing_at, UNIT_CYCLE,
		("the second swing begins EXACTLY %d ticks after the first (windup %d + active %d + "
		+ "recovery %d) — no throttle remainder, no idle-only stall")
				% [UNIT_CYCLE, UNIT_WINDUP, UNIT_ACTIVE, UNIT_RECOVERY])
	assert_eq(_phase(ms), UnitBoard.AttackPhase.IDLE,
		"...and with no third refresh the unit stops after the second cycle rather than free-running")


## AC 13's SCOPING PIN, stated explicitly in the AC because it does NOT follow from AC 4 read alone:
## a cleave through a BYSTANDER must NOT refresh the flag. AC 4 deliberately lets one swing damage
## entities the unit never aimed at; letting one of them refresh "in reach" would keep a unit
## swinging at a target it has actually lost.
##
## THE PAIR that makes it non-vacuous is the identical fact against the ACQUIRED target, which MUST
## set it — otherwise this test would pass against an implementation whose flag never sets at all.
func test_only_a_fact_against_the_acquired_target_refreshes_the_flag() -> void:
	var ms := _make_match()
	_summon_p1(ms, [1, -1])          # the unit has acquired P2's HERO
	ms.p2.units.add(UNIT_MAX_HP, 0)     # ...and a bystander unit stands beside it
	ms.push_contact([0, 0], [1, 0], 0, PROBE_DIR, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_false(ms.p1.units.is_in_reach_at(0),
		"a fact against a BYSTANDER does not refresh in-reach — only the ACQUIRED target does "
		+ "(AC 13), or a unit would keep swinging at a target it has lost")
	ms.push_contact([0, 0], [1, -1], 0, PROBE_DIR, MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_true(ms.p1.units.is_in_reach_at(0),
		"...and the SAME fact against the acquired target DOES, so the negative above is about "
		+ "SCOPE rather than about a flag that never sets")


## AC 13's consequence (ii), made executable: absence of overlap is NOT a fact and CANNOT clear the
## flag. Consumption at windup start is the ONLY clearing path, and a dev pass must not go looking
## for a negative probe.
func test_the_flag_is_cleared_by_the_windup_alone_and_by_nothing_else() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	_probe(ms, 0)
	assert_true(ms.p1.units.is_in_reach_at(0), "the probe set it")
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.WINDUP, "the windup began...")
	assert_false(ms.p1.units.is_in_reach_at(0), "...and CONSUMED the flag")
	# Many ticks with no fact of any kind: nothing re-sets it and nothing else clears it either.
	for _t in UNIT_CYCLE:
		_advance(ms)
		assert_false(ms.p1.units.is_in_reach_at(0),
			"nothing but a fact sets the flag — there is no negative probe and no decay timer")


## ---- AC 12: the direction lock -----------------------------------------------------------------

## AC 12's three claims in one walk, because they are one mechanism: the locked direction is the
## NEGATED `dir` of the flag-setting fact; it does not move when a later fact reports a different
## direction after the windup has begun; and the freeze IS the lock (no sixth field).
func test_the_attack_direction_is_the_negated_fact_dir_and_freezes_at_windup_start() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	_probe(ms, 0, [1, -1], PROBE_DIR)
	assert_eq(ms.p1.units.attack_dir_at(0), LOCKED_DIR,
		"the direction is the fact's TARGET-to-ATTACKER `dir` NEGATED (`match_state.push_contact` "
		+ "documents the field, and an un-negated store would lock a BACKWARDS swing)")
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.WINDUP, "the windup has begun, so the value is now frozen")
	# The target 'moves': a later fact reports a completely different direction. Under AC 12 this
	# must NOT re-aim the swing — late-locking tracking is deferred to per-kind movesets (`4-3b/R9`).
	var moved := Vector2(-0.8, 0.6)
	for _t in UNIT_WINDUP + UNIT_ACTIVE - 1:
		ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), moved,
				MatchState.CONTACT_STRIKE)
		_advance(ms)
		assert_eq(ms.p1.units.attack_dir_at(0), LOCKED_DIR,
			"the locked direction does NOT track the target once the windup has begun — that is "
			+ "the whole point of the lock (AC 12)")
	# ...and once the ACTIVE window has shut, the direction is free to refresh again. THE FREEZE
	# COVERS WINDUP AND ACTIVE, NOT RECOVERY, and the story did not settle which -- see
	# `MatchState._mark_reach_from_fact` for the measurement (a continuously in-reach unit is never
	# IDLE at a fact-resolution seat, so freezing through recovery would freeze the direction
	# FOREVER and contradict AC 12's own "up to one throttle interval stale" consequence).
	_advance(ms)
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.RECOVERY, "sanity: the window has shut")
	ms.push_contact([0, 0], [1, -1], 0, moved, MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	assert_eq(ms.p1.units.attack_dir_at(0), -moved,
		"a unit whose swing can no longer land DOES track the latest fact — the freeze is the "
		+ "LOCK, not a permanent write-once, which is what makes a sixth 'is locked' field "
		+ "unnecessary AND what keeps the staleness bounded at one throttle interval as AC 12 says")


## AC 12 / `4-3b/R18`: a swing whose target DIES mid-windup COMPLETES INTO EMPTY AIR. There is no
## cancel path, because a cancel would be a second way a swing can end, against the no-interruption
## Non-Goal.
##
## THE POSITIVE HALF FIRST so the negative means something: an identical run where the target
## SURVIVES lands real damage. Without it, "lands nothing" would also pass against a unit that never
## attacked at all.
func test_a_swing_whose_target_dies_mid_windup_runs_to_completion_and_lands_nothing() -> void:
	# --- the run where the target survives.
	var alive := _make_match()
	_summon_p1(alive, [1, 0])
	alive.p2.units.add(UNIT_MAX_HP, 0)
	_probe(alive, 0, [1, 0])
	_advance(alive)
	for _t in UNIT_WINDUP:
		_advance(alive)
	assert_eq(_phase(alive), UnitBoard.AttackPhase.ACTIVE, "sanity: the window is open")
	alive.push_contact([0, 0], [1, 0], alive.p1.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(alive)
	assert_eq(alive.p2.units.hp_at(0), UNIT_MAX_HP - UNIT_DAMAGE,
		"the control run LANDS: this fact would have applied damage")

	# --- the run where the target dies during the windup.
	var ms := _make_match()
	_summon_p1(ms, [1, 0])
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_probe(ms, 0, [1, 0])
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.WINDUP, "the swing is committed")
	ms.p2.units.apply_damage_at(0, UNIT_MAX_HP, 0)   # the target dies mid-windup
	assert_false(ms.p2.units.is_alive_at(0), "sanity: it is dead before the window opens")
	for _t in UNIT_WINDUP:
		_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.ACTIVE,
		"the swing did NOT cancel — its windows run to completion into empty air (`4-3b/R18`)")
	ms.push_contact([0, 0], [1, 0], ms.p1.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), 0.0, "...and it lands NOTHING on the corpse")
	# UNIT_ACTIVE - 2, not - 1: the advance that RESOLVED the strike above already consumed one
	# of the window's ticks, so two remain before the boundary.
	for _t in UNIT_ACTIVE - 2:
		_advance(ms)
		assert_eq(_phase(ms), UnitBoard.AttackPhase.ACTIVE,
			"the window stays open for its full authored length over a dead target")
		assert_eq(ms.p1.units.attack_count_at(0), 1,
			"...and it is still the SAME swing — nothing restarted it and nothing cut it short")
	_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.RECOVERY,
		"...and it runs out into RECOVERY rather than stalling or cancelling (`4-3b/R18`): there "
		+ "is no cancel path, because a cancel would be a second way a swing can end")


## ---- AC 4: the cleave, and its canonical order -------------------------------------------------

## AC 4: one unit swing over THREE targets in the same active window registers three addresses and
## no address twice. The dedupe still does its actual job — the same address cannot be hit twice by
## the same swing — while a swing that overlaps several targets resolves against each of them.
func test_one_unit_swing_cleaves_three_targets_and_registers_none_of_them_twice() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	ms.p2.units.add(UNIT_MAX_HP, 0)
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_probe(ms, 0)
	_advance(ms)
	for _t in UNIT_WINDUP:
		_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.ACTIVE, "sanity: the window is open")
	var swing := ms.p1.units.attack_count_at(0)
	# Three DISTINCT addresses, each pushed TWICE — so the cleave and the dedupe are measured by the
	# same run rather than by two.
	for address: Array in [[1, -1], [1, 0], [1, 1], [1, -1], [1, 0], [1, 1]]:
		ms.push_contact([0, 0], [address[0], address[1]] as Array[int], swing, PROBE_DIR,
				MatchState.CONTACT_STRIKE)
	var hero_hp_before := ms.p2.hero.get_hp()
	_advance(ms)
	assert_eq(ms.p2.units.hp_at(0), UNIT_MAX_HP - UNIT_DAMAGE,
		"unit 0 took exactly ONE hit from this swing, not two")
	assert_eq(ms.p2.units.hp_at(1), UNIT_MAX_HP - UNIT_DAMAGE,
		"...and so did unit 1, which a non-cleaving dedupe would have skipped entirely")
	assert_true(ms.p2.hero.get_hp() < hero_hp_before,
		"...and the hero was hit too — three addresses, one swing (AC 4)")
	var records := ms.p1.unit_dedupe.snapshot()
	assert_eq(records.size(), 1, "one live record, for this unit's current swing")
	assert_eq(records[0][3], [[1, -1], [1, 0], [1, 1]],
		"the hit list holds all THREE addresses and each exactly once")


## AC 4's ORDER half, and the reason it exists: the append order into the hit list is
## HASH-SIGNIFICANT (the list is snapshotted), and the arrival order is whatever the runner's physics
## overlap query happened to produce — a query that pins no ordering. Sorting on INSERTION (the
## `4-3a/R22` precedent followed rather than reinvented) makes the stored state itself canonical.
##
## MEASURED AS A PERMUTATION: the same three overlaps fed in REVERSED order produce an IDENTICAL
## stored hit list. An append-order implementation passes the test above and fails this one.
func test_the_same_overlaps_in_reversed_order_store_an_identical_hit_list() -> void:
	var forward := _dedupe_after_cleave([[1, -1], [1, 0], [1, 1]])
	var reversed := _dedupe_after_cleave([[1, 1], [1, 0], [1, -1]])
	assert_eq(forward, reversed,
		"the stored hit list is CANONICAL, not arrival-ordered — an unpinned physics query order "
		+ "would otherwise decide a hashed value (`4-3a/R22`)")
	assert_eq(forward[0][3], [[1, -1], [1, 0], [1, 1]],
		"...and the canonical order is `[slot, index]` ASCENDING, so the equality above is not two "
		+ "runs agreeing on a wrong answer")


## One unit swing over three addresses in the given order, returning the dedupe snapshot.
func _dedupe_after_cleave(addresses: Array) -> Array:
	var ms := _make_match()
	_summon_p1(ms)
	ms.p2.units.add(UNIT_MAX_HP, 0)
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_probe(ms, 0)
	_advance(ms)
	for _t in UNIT_WINDUP:
		_advance(ms)
	var swing := ms.p1.units.attack_count_at(0)
	for address: Array in addresses:
		ms.push_contact([0, 0], [address[0], address[1]] as Array[int], swing, PROBE_DIR,
				MatchState.CONTACT_STRIKE)
	_advance(ms)
	return ms.p1.unit_dedupe.snapshot()


## ---- AC 5: canonical order ACROSS attackers ----------------------------------------------------

## AC 5, PINNED NON-VACUOUSLY: the same SET of facts fed in DIFFERENT orders produces an identical
## resolution AND an identical `to_snapshot()` hash. A test that only fed them in one order would
## prove nothing.
##
## THE FIXTURE HAD TO BE BUILT SO ORDER ACTUALLY DECIDES A HASHED VALUE, and the first attempt at
## this test did NOT -- it fed two UNITS, and mutation-proving it (M4: the canonical sort removed)
## showed it still PASSED. The reason is worth recording: deflect changes nothing about the
## ATTACKER (AC 10 opens no stun edge), registration happens BEFORE the deflect branch for both, and
## a unit-sourced confirmation pays no mana either way -- so "unit 0 was deflected" and "unit 1 was
## deflected" are the SAME hashed state, and the equality was vacuous.
##
## WHAT DISCRIMINATES IS MIXING ATTACKER KINDS. P1's HERO and P1's UNIT both land on P2 in one tick,
## and P2 is BLOCKING with enough stamina for exactly ONE deflect. Deflect spends PER FACT, so
## whichever fact resolves FIRST is fully negated and the second degrades to blocked damage -- and a
## blocked HERO hit is a CONFIRMED hit that PAYS MANA (AC 7 keeps the unit's out of that list). So:
##   * hero first -> the hero's fact is negated, the unit's is blocked  -> NO mana.
##   * unit first -> the unit's fact is negated, the hero's is blocked  -> MANA.
## Mana is hashed. The order therefore decides a hashed value, and the canonical sort is what makes
## both feeds agree. M4 falls against this fixture.
func test_facts_from_several_attackers_resolve_identically_in_any_fed_order() -> void:
	var forward := _mixed_attacker_hash(false)
	var reversed := _mixed_attacker_hash(true)
	assert_eq(forward["hash"], reversed["hash"],
		"the same facts fed in either order reach an IDENTICAL snapshot hash — the resolution "
		+ "order is CANONICAL (slot ascending, then board index ascending, so a hero's -1 sorts "
		+ "ahead of every unit on its own board), never the fed order")
	assert_eq(forward["mana"], reversed["mana"],
		"...and the same MANA, named rather than left to the hash — this is the value the fed order "
		+ "would otherwise decide")
	assert_eq(int(forward["deflects"]), 1,
		"sanity: EXACTLY ONE of the two facts deflected. With two deflects or none the order would "
		+ "decide nothing and this test would be vacuous — which is exactly what its first version "
		+ "was, until M4 exposed it")
	assert_eq(int(reversed["deflects"]), 1, "...in both feeds")
	assert_true(float(forward["hp"]) < 100.0,
		"...and the OTHER fact really did land blocked damage, so both facts were resolved")
	assert_eq(float(forward["mana"]), 0.0,
		"...and under the CANONICAL order it is the HERO's fact that is negated (its address "
		+ "`[0, -1]` sorts ahead of the unit's `[0, 0]`), so no mana is paid — the concrete outcome "
		+ "the sort selects, asserted rather than left implicit")


## P1's HERO and P1's UNIT both landing on P2 in the same tick, fed in the given order.
func _mixed_attacker_hash(reversed: bool) -> Dictionary:
	var ms := _make_match()
	_summon_p1(ms)
	# Enough stamina for exactly ONE deflect, so the second fact must fall through to a block.
	ms.p2.stamina.spend(ms.p2.stamina.get_current() - _config().deflect_stamina_cost, 0)
	# Tick 1 arms BOTH attackers: the unit's reach probe, and the hero's attack press. The authored
	# windows (hero windup 5, unit windup 3 + one tick of F1 lag on the probe) put the hero's active
	# window and the unit's over the same tick 6.
	ms.push_contact([0, 0], [1, -1], 0, PROBE_DIR, MatchState.CONTACT_REACH_PROBE)
	_advance(ms, _intent([&"attack"]))
	for _t in 5:
		_advance(ms)
	assert_true(ms.p1.hero.is_hitbox_active(), "sanity: the HERO's window is open")
	assert_true(ms.p1.units.is_hitbox_active_at(0), "sanity: and the UNIT's is open on the same tick")
	var deflects: Array = []
	ms.deflect_landed.connect(func(a: int, t: int, _c: int) -> void: deflects.append([a, t]))
	var mana_before := ms.p1.mana.get_current()
	# DOWN is dead ahead of P2's default facing, so the block/deflect ladder is actually reached
	# rather than falling through the arc gate.
	var facts := [
		[[0, -1] as Array[int], ms.p1.hero.attack_index],
		[[0, 0] as Array[int], ms.p1.units.attack_count_at(0)],
	]
	if reversed:
		facts.reverse()
	for fact: Array in facts:
		ms.push_contact(fact[0], [1, -1], int(fact[1]), Vector2.DOWN, MatchState.CONTACT_STRIKE)
	# P2 PRESSES block on the resolving tick: step 3 enters BLOCKING and opens the deflect window
	# BEFORE step 4 drains the queue, so both facts meet an open window and one deflect's worth of
	# stamina. That is what makes WHICH fact resolves first decide the outcome.
	_advance(ms, null, _intent([&"block"]))
	return {
		"hash": CanonicalHash.of(ms.to_snapshot()),
		"hp": ms.p2.hero.get_hp(),
		"mana": ms.p1.mana.get_current() - mana_before,
		"deflects": deflects.size(),
	}


## ---- AC 11: no stamina, no resource ------------------------------------------------------------

## AC 11's negative guard: a FULL unit attack cycle leaves BOTH players' stamina and mana pools
## numerically untouched. The rhythm itself is the only limiter — never a `StaminaPool.spend` and
## never any other economy gate.
##
## THE FIXTURE MAKES THE GUARD FALLIBLE: both regen rates are authored to ZERO, so a pool that moves
## at all moved because something SPENT or GRANTED, not because it drifted back up. And the swing
## really does LAND (asserted below), so this is not a cycle that quietly did nothing.
func test_a_full_unit_attack_cycle_spends_no_stamina_and_generates_no_mana() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	var p1_stamina := ms.p1.stamina.get_current()
	var p2_stamina := ms.p2.stamina.get_current()
	var p1_mana := ms.p1.mana.get_current()
	var p2_mana := ms.p2.mana.get_current()
	var hero_hp := ms.p2.hero.get_hp()
	_probe(ms, 0)
	_advance(ms)
	for _t in UNIT_WINDUP:
		_advance(ms)
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	for _t in UNIT_ACTIVE + UNIT_RECOVERY:
		_advance(ms)
	# The landed strike was against the ACQUIRED target, so it REFRESHED the flag and a second
	# windup began the instant recovery ended (AC 13's back-to-back cycle). The counter is what
	# proves a whole cycle ran; the phase would read WINDUP, not IDLE.
	assert_eq(ms.p1.units.attack_count_at(0), 2, "sanity: a whole cycle ran and the next began")
	assert_true(ms.p2.hero.get_hp() < hero_hp,
		"sanity: and the swing LANDED, so the four equalities below are about a real attack")
	assert_eq(ms.p1.stamina.get_current(), p1_stamina,
		"the attacking side spends NO stamina to swing (AC 11) — unlike a hero, whose swing is "
		+ "charged at the step-3 transition")
	assert_eq(ms.p2.stamina.get_current(), p2_stamina,
		"...and the defending side spends none either (it neither blocked nor deflected here)")
	assert_eq(ms.p1.mana.get_current(), p1_mana,
		"...and the unit's landed hit generates NO mana for its owner (AC 7)")
	assert_eq(ms.p2.mana.get_current(), p2_mana, "...and none for the target either")


## ---- AC 16: the snapshot round trip ------------------------------------------------------------

## AC 16: every new field round-trips through `to_snapshot()`. Measured MID-SWING, with values that
## are all DISTINCT from their empty defaults, so a key that was emitted but never filled fails here.
func test_every_new_unit_attack_field_round_trips_through_the_snapshot() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_probe(ms, 0)
	# Story 4-4 (`4-4/R14`): the in-reach key is a COUNTDOWN OF FRESH TICKS now, so it is sampled
	# HERE as well -- non-zero, on the tick the probe landed and before the next advance's windup
	# consumes it. Without this rung the assertion below would be the only one, and 0 is that key's
	# empty default: a key emitted but never filled would pass it. The pair is what keeps AC 16's
	# round trip non-vacuous for this key.
	assert_ne(ms.p1.to_snapshot()["unit_in_reach"], [0],
		"the confirmation reaches the snapshot as a LIVE tick count before it is consumed")
	_advance(ms)
	for _t in UNIT_WINDUP:
		_advance(ms)
	ms.push_contact([0, 0], [1, 0], ms.p1.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	var snap := ms.p1.to_snapshot()
	assert_eq(snap["unit_attack_phase"], [UnitBoard.AttackPhase.ACTIVE],
		"the phase reaches the snapshot, mid-swing and non-default")
	assert_eq(snap["unit_attack_ticks"], [UNIT_ACTIVE - 1],
		"...and the countdown, at its real mid-window value rather than zero")
	assert_eq(snap["unit_attack_dir"], [LOCKED_DIR],
		"...and the locked direction, as a Vector2 CanonicalHash has a branch for")
	assert_eq(snap["unit_attack_count"], [1], "...and the unit's own monotonic swing counter")
	assert_eq(snap["unit_in_reach"], [0],
		"...and the in-reach countdown, here CONSUMED by the windup (`4-4/R14` made this key an INT "
		+ "count of fresh ticks rather than a bool; it is the one cause of the golden's third "
		+ "re-baseline). Its live non-zero value is asserted above, before the windup ate it")
	assert_eq(snap["unit_swing_dedupe"], [[0, 1, -1, [[1, 0]]]],
		"...and the dedupe record: board index, swing counter, grace -1 (window open) and the one "
		+ "address this swing has registered")
	# ...and the hash actually consumes all six: CanonicalHash must have a branch for every type.
	assert_true(CanonicalHash.of(snap).length() == 64,
		"the whole payload hashes — no type in it falls through CanonicalHash's branches")


## ---- Review fix pass (4-3b, F2): the dead-attacker dedupe leak -------------------------------

## A unit killed during its OWN ACTIVE window would otherwise leave its swing-dedupe record open
## FOREVER: `_advance_unit_attacks` skips dead units entirely, so the phase transition that calls
## `close()` never runs for a corpse, and `tick()`'s own `grace <= 0: continue` guard means it never
## touches a still-open (`grace == -1`) record either. `UnitSwingDedupe.discard()` is called from
## `_resolve_unit_contact`, the one place death is already known, to close that hole.
##
## PROVEN NON-VACUOUSLY, past the point a single tick-later check could pass by accident: the record
## must be gone the instant death lands, AND it must still be gone many ticks later — a mutation that
## only delays the erasure (routes it through the normal `close()` + one-tick grace instead of an
## outright discard) would still pass an assertion made one tick after death, so this test drives well
## past that window before its second assertion.
func test_a_unit_killed_during_its_own_active_window_has_its_dedupe_record_discarded() -> void:
	var ms := _make_match()
	_summon_p1(ms, [1, 0])              # P1 unit 0 targets P2 unit 0
	ms.p2.units.add(UNIT_MAX_HP, 0)        # P2 unit 0, the eventual killer
	ms.p2.units.set_target_at(0, 0, 0)  # P2 unit 0 targets P1 unit 0
	ms.push_contact([0, 0], [1, 0], ms.p1.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_REACH_PROBE)
	ms.push_contact([1, 0], [0, 0], ms.p2.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_REACH_PROBE)
	_advance(ms)  # both reach flags set (still IDLE, F1 lag)
	_advance(ms)  # both windups begin
	for _t in UNIT_WINDUP:
		_advance(ms)
	assert_eq(_phase(ms), UnitBoard.AttackPhase.ACTIVE, "sanity: P1 unit 0's own window is open")
	assert_eq(ms.p2.units.attack_phase_at(0), UnitBoard.AttackPhase.ACTIVE,
		"sanity: P2 unit 0's window is open on the same tick (identical authored rhythm)")
	assert_eq(ms.p1.unit_dedupe.size(), 1,
		"sanity: P1 unit 0's own swing opened a live dedupe record")
	# Bring P1 unit 0 to exactly one hit from death, then land the killing blow through a REAL
	# contact resolution from P2's unit -- never a direct apply_damage_at -- so `_resolve_unit_contact`,
	# the seat this fix lives in, is the code path that actually kills it.
	ms.p1.units.apply_damage_at(0, UNIT_MAX_HP - UNIT_DAMAGE, 0)
	assert_true(ms.p1.units.is_alive_at(0), "sanity: still alive, one hit from death")
	ms.push_contact([1, 0], [0, 0], ms.p2.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_false(ms.p1.units.is_alive_at(0), "sanity: the killing blow landed and P1 unit 0 is dead")
	assert_eq(ms.p1.unit_dedupe.size(), 0,
		"the dead unit's OWN dedupe record is gone the instant death is known -- left open, it would "
		+ "never close, because `_advance_unit_attacks` skips this now-dead index for the rest of the "
		+ "match and can never reach the close() call that would otherwise erase it")
	for _t in UNIT_CYCLE * 2:
		_advance(ms)
	assert_eq(ms.p1.unit_dedupe.size(), 0,
		"...and it stays gone across many further ticks -- the leak this guards against is a record "
		+ "that survives forever, not merely one that closes a tick late")


## The DEBUG RESET clears the rhythm with the board, in the same seat and under the same named
## exception. A record surviving a board clear would key an index that no longer names the unit it
## was opened for.
func test_the_debug_reset_clears_the_rhythm_with_the_board() -> void:
	var ms := _make_match()
	_summon_p1(ms)
	_probe(ms, 0)
	_advance(ms)
	for _t in UNIT_WINDUP:
		_advance(ms)
	ms.push_contact([0, 0], [1, -1], ms.p1.units.attack_count_at(0), PROBE_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_true(ms.p1.unit_dedupe.size() > 0, "sanity: there is a live record to clear")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset)
	assert_eq(ms.p1.units.size(), 0, "the board is emptied by the reset (`4-1/R5`)")
	assert_eq(ms.p1.unit_dedupe.size(), 0,
		"...and the dedupe records go with it — they key BOARD INDICES, so a survivor would key an "
		+ "index that no longer names the unit it was opened for")
	var snap := ms.p1.to_snapshot()
	assert_eq(snap["unit_attack_phase"], [], "...and every rhythm array is empty in the snapshot")
	assert_eq(snap["unit_swing_dedupe"], [], "...including the records")
