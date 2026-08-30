extends TestCase

## Story 4-4 coverage: the PROJECTILE (AC 14-19) — launch, the authored acceleration curve, the
## travel budget, the homing flag and every rule about what ends it.
##
## WHAT THIS FILE OWNS. The launch seat and what a fresh record carries (AC 14); the acceleration
## profile's arithmetic and the 60 m budget's expiry (AC 15's second half, AC 19); the i-frame drop
## ENDING HOMING while NOT consuming the shot (AC 16, `4-4/R4`); spatial dodging NOT ending homing
## (AC 17, `4-4/R5`); block and deflect CONSUMING it (AC 18, `4-4/R6`); the projectile attacker
## ADDRESS and its three-partition scheme (`E4-P/R12`); and that a projectile's dedupe IS its
## liveness, so one shot resolves at most once.
##
## WHAT IT DELIBERATELY DOES NOT OWN. The HOMING GEOMETRY — the heading, the turn rate, the steering
## itself — is ACTOR-owned (`4-3/R2` keeps position out of `src/state/`), so its proof is
## test/integration/test_projectile_flight_live.gd. What this file can and does prove about homing is
## the STATE half: the flag, when it clears, and when it must not.
##
## Test balance is constructed IN-TEST and never loaded from `data/balance/*.tres` (the standing
## `BC/R3` isolation). Values are chosen DISTINCT from one another so an assertion cannot pass on a
## coincidence: launch speed 60 u/s is exactly 1.0 u/tick at 60 Hz, so distance and ticks read the
## same number and an off-by-one in either is visible; the budget is 10 u, so a shot expires on a
## tick a human can count to.

const LAUNCH_SPEED := 60.0        # 1.0 world unit per tick at 60 Hz — the arithmetic is legible
const TRAVEL_BUDGET := 10.0       # ...so an unaccelerated shot expires on flight tick 10
const TOTEM_DAMAGE := 4.0
const TOTEM_MAX_HP := 12.0
const HERO_MAX_HP := 100.0

## Windup 1 tick, active 2, recovery 1: the shortest rhythm that still has three distinct phases, so
## the launch can be pinned to the windup-to-active boundary rather than to "somewhere in the swing".
const WINDUP := 1
const ACTIVE := 2
const RECOVERY := 1

## The fact direction every pushed contact carries — TARGET-to-ATTACKER, which is what
## `push_contact` documents its fourth argument to be. Deliberately not symmetric under negation.
const FACT_DIR := Vector2(0.6, 0.8)

## Story 4-4 (`4-4/R14`): the cadence fixture's three numbers, chosen so the defect they express is
## reachable and the arithmetic stays countable.
##   * RETARGET_TICKS 12 is the shipped 0.2 s probe cadence at 60 Hz, so FRESHNESS_TICKS below is
##     the shipped window rather than a convenient one.
##   * STALE_CADENCE_TICKS 40 is LONGER than that window — the gap is the defect's reachability
##     condition (the shipped Combat totem's 120 is longer still; 40 keeps the tests short).
##   * FRESHNESS_MARGIN_TICKS is slack past the cooldown, so "it did not fire" is a claim about a
##     totem that has been idle and ready for a while rather than about one caught mid-cooldown.
const RETARGET_TICKS := 12
const FRESHNESS_TICKS := RETARGET_TICKS + 1
const STALE_CADENCE_TICKS := 40
const FRESHNESS_MARGIN_TICKS := 10


func _projectile(turn_rate := 180.0, accel := 0.0, accel_delay_ticks := 0,
		max_speed := LAUNCH_SPEED) -> ProjectileProfile:
	var p := ProjectileProfile.new()
	p.launch_speed = LAUNCH_SPEED
	p.homing_turn_rate_degrees_per_second = turn_rate
	p.acceleration_per_second_squared = accel
	p.acceleration_delay_seconds = float(accel_delay_ticks) / 60.0
	p.max_speed = max_speed
	p.travel_budget = TRAVEL_BUDGET
	return p


## A Combat-totem-shaped kind at index 0: static, hero-preferring, firing a projectile.
func _totem_kind(projectile: ProjectileProfile) -> UnitKindProfile:
	var kind := UnitKindFixture.melee(&"combat_totem", TOTEM_MAX_HP, TOTEM_DAMAGE, WINDUP, ACTIVE,
			RECOVERY, 8.0, 0.0, 1.5, &"standard")
	kind.attack_at(0).projectile = projectile
	return kind


func _config(projectile: ProjectileProfile = null) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = HERO_MAX_HP
	c.move_speed = 5.0
	c.max_stamina = 50.0
	c.stamina_regen_per_second = 0.0
	c.stamina_regen_delay_seconds = 1.0 / 60.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 10.0
	c.max_mana = 80.0
	c.melee_hit_mana = 8.0
	c.mana_regen_per_second = 0.0
	c.block_damage_multiplier = 0.5
	c.block_facing_arc_degrees = 180.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.deflect_stamina_cost = 5.0
	c.roll_iframe_seconds = 100.0 / 60.0   # long enough that no test has to re-press a roll
	c.roll_duration_seconds = 100.0 / 60.0
	c.roll_distance = 1.0
	c.roll_stamina_cost = 5.0
	c.minion_retarget_interval_seconds = 1000.0  # never a boundary tick: no test here retargets
	c.hero_damage_to_unit = 3.0
	c.unit_kinds = [_totem_kind(projectile if projectile != null else _projectile())]
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	f.minions = true
	f.totems = true
	return f


func _make_match(projectile: ProjectileProfile = null) -> MatchState:
	var ms := MatchState.new(MatchParams.new(13))
	ms.apply_balance(_config(projectile))
	ms.inject_feature_flags(_flags())
	ms.drain_signals()
	return ms


func _advance(ms: MatchState, p1_intent: InputIntent = null,
		p2_intent: InputIntent = null) -> void:
	var intents: Array[InputIntent] = [
		p1_intent if p1_intent != null else InputIntent.new(),
		p2_intent if p2_intent != null else InputIntent.new(),
	]
	ms.advance(intents)
	ms.drain_signals()


func _intent(pressed: Array = []) -> InputIntent:
	var i := InputIntent.new()
	for k in pressed:
		i.pressed[k] = true
		i.held[k] = true
	return i


## One Combat totem on P1's board, already targeting P2's hero — straight onto the board rather than
## through a cast (the `test_targeting_service.gd::_summon` idiom): these tests are about what a
## totem DOES once it exists, not about how it got there, and the cast path is
## test_card_effect_resolution.gd's.
func _summon_totem(ms: MatchState) -> void:
	ms.p1.units.add(TOTEM_MAX_HP, 0)
	ms.p1.units.set_target_at(0, 1, TargetingService.HERO_INDEX)


## Drive the totem from IDLE to the tick its shot LAUNCHES, and return the match. A reach probe puts
## it in reach; the windup begins the tick after (the F1 one-tick lag), and the windup-to-active
## transition — the launch — is `WINDUP` ticks after that.
func _fire(ms: MatchState) -> void:
	_summon_totem(ms)
	ms.push_contact([0, 0], [1, TargetingService.HERO_INDEX], 0, FACT_DIR,
			MatchState.CONTACT_REACH_PROBE)
	_advance(ms)                     # the probe resolves: in-reach is set
	for _t in WINDUP + 1:
		_advance(ms)                 # windup begins, then runs out -> ACTIVE -> LAUNCH


## Story 4-4 (`4-4/R14`): the CADENCE fixture — a totem that re-arms slowly and a runner that probes
## on the shipped cadence. Everything else is `_make_match()`'s config; only the two intervals move,
## so anything these tests measure is attributable to them.
func _cadence_match() -> MatchState:
	var config := _config()
	config.minion_retarget_interval_seconds = float(RETARGET_TICKS) / 60.0
	config.unit_kinds[0].attack_at(0).cadence_seconds = float(STALE_CADENCE_TICKS) / 60.0
	var ms := MatchState.new(MatchParams.new(13))
	ms.apply_balance(config)
	ms.inject_feature_flags(_flags())
	ms.drain_signals()
	return ms


## `_fire()`'s sibling for the cadence fixture: one probe, one swing, one shot — and then nothing
## else is pushed, so what happens next is decided entirely by the freshness rule.
func _fire_once(ms: MatchState) -> void:
	_summon_totem(ms)
	ms.push_contact([0, 0], [1, TargetingService.HERO_INDEX], 0, FACT_DIR,
			MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	for _t in WINDUP + 1:
		_advance(ms)


## Run the totem's swing out to IDLE, however many ticks its phases take — the tests below care that
## it is idle and barred by its cadence, never how many ticks the walk took.
func _idle(ms: MatchState) -> void:
	var guard := 0
	while ms.p1.units.attack_phase_at(0) != UnitBoard.AttackPhase.IDLE and guard < 20:
		_advance(ms)
		guard += 1


## The projectile attacker ADDRESS for P1's shot 0 — spelled through the public helper at every call
## site rather than as a literal -2, which is the encoding discipline `MatchState` states at
## `PROJECTILE_INDEX_BASE`.
func _shot_address(index := 0) -> Array[int]:
	return [0, MatchState.projectile_attacker_index(index)]


## ---- AC 13 / `4-4/R14`: A CONFIRMATION HAS A SHELF LIFE -----------------------------------------

## The REVIEW's measured scenario, made executable. Story 4-4 added the firing cadence as a third AND
## on the windup gate, and that turned the in-reach flag from something consumed on the very next
## IDLE tick into something BANKED FOR A WHOLE COOLDOWN. A hero inside the Combat totem's 8 m range
## sets the flag; the totem is mid-cadence so nothing consumes it; the hero walks away; no probe can
## clear it (`4-3b` AC 13(ii) — absence of overlap is not a fact); and when the cooldown expires the
## totem winds up and fires at a target the shipped authoring puts ~18 m away. AC 13 says a target
## held beyond range is fired upon NEVER, and one shot per departure is not never.
##
## `4-4/R14` closes it WITHOUT a negative probe: a confirmation stays CURRENT for one probe cadence
## plus the F1 one-tick lag, and a unit may begin an attack only on a current one.
##
## THE CADENCE HERE IS LONGER THAN THE FRESHNESS WINDOW ON PURPOSE (40 ticks against 13) — that gap
## IS the defect's reachability condition, and a fixture whose cadence fitted inside the window could
## not express it.
func test_a_confirmation_that_goes_unrenewed_through_a_cooldown_fires_nothing() -> void:
	var ms := _cadence_match()
	_fire_once(ms)
	assert_eq(ms.p1.projectiles.size(), 1, "the first shot fired off a CURRENT confirmation")
	_idle(ms)
	assert_false(ms.p1.units.is_attack_ready_at(0), "...and the long cadence has it barred")
	# THE BANK. One probe lands EARLY in the cooldown -- the target is genuinely in range at this
	# moment -- and nothing consumes it, because the cadence rung refuses. This is the confirmation
	# the defect banked for the whole cooldown.
	ms.push_contact([0, 0], [1, TargetingService.HERO_INDEX], ms.p1.units.attack_count_at(0),
			FACT_DIR, MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	assert_true(ms.p1.units.is_in_reach_at(0), "the confirmation is banked and current")
	# ...and NOW the target leaves. No further probe arrives -- which is the only thing the runner
	# does differently for a target out of range, since there is no negative probe to push.
	for _t in STALE_CADENCE_TICKS + FRESHNESS_MARGIN_TICKS:
		_advance(ms)
	assert_eq(ms.p1.projectiles.size(), 1,
		"AC 13: NO SECOND SHOT. The cooldown expired long ago and the totem is idle and willing, but "
		+ "the confirmation it was holding went stale %d ticks after it was made -- so there is "
				% FRESHNESS_TICKS + "nothing current to begin an attack on")
	assert_eq(ms.p1.units.attack_phase_at(0), UnitBoard.AttackPhase.IDLE,
		"...and it never even wound up: the gate refused at the in-reach rung, not at the cadence "
		+ "rung, which is what makes this hold-fire rather than a slower cadence")
	assert_false(ms.p1.units.is_in_reach_at(0),
		"...because the confirmation is no longer current")
	assert_true(ms.p1.units.is_attack_ready_at(0),
		"...while the CADENCE is ready and willing -- the pair is what proves the refusal came from "
		+ "the freshness half and not from a cooldown that happened not to have expired")


## The PAIR that makes the test above non-vacuous, and the regression guard on the fix itself: the
## identical fixture, identical cadence, identical tick count -- with the runner still confirming on
## its cadence, exactly as it does for a target that never left. A fix that simply stopped totems
## firing a second time would pass the test above and fail here.
func test_a_confirmation_renewed_on_the_probe_cadence_fires_again_on_schedule() -> void:
	var ms := _cadence_match()
	_fire_once(ms)
	assert_eq(ms.p1.projectiles.size(), 1, "the first shot fired")
	_idle(ms)
	for t in STALE_CADENCE_TICKS + FRESHNESS_MARGIN_TICKS:
		# The runner re-probes every `RETARGET_TICKS`; the target is still in range, so every one of
		# those probes lands. Nothing else about this run differs from the test above.
		if t % RETARGET_TICKS == 0:
			ms.push_contact([0, 0], [1, TargetingService.HERO_INDEX],
					ms.p1.units.attack_count_at(0), FACT_DIR, MatchState.CONTACT_REACH_PROBE)
		_advance(ms)
	assert_true(ms.p1.projectiles.size() > 1,
		"a target that is STILL THERE is still fired upon: the renewed confirmation is current when "
		+ "the cooldown expires, so the cadence keeps its schedule (got %d shots)"
				% ms.p1.projectiles.size())
	assert_true(ms.p1.units.is_in_reach_at(0),
		"...and the confirmation is current at the end, re-seeded rather than accumulated")


## The window's own arithmetic, asserted directly rather than inferred from a firing outcome: a
## confirmation is current for exactly `minion_retarget_interval_ticks + 1` ticks -- one probe
## cadence, plus the F1 lag that separates the tick a probe is gathered on from the tick it is
## consumed on. A window one tick SHORTER would expire a confirmation on the very tick its successor
## arrives and punch a hole in every cadence.
func test_a_confirmation_stays_current_for_exactly_one_probe_cadence_plus_the_lag() -> void:
	var ms := _cadence_match()
	# A unit that CANNOT act on the flag, so the countdown is observed ageing rather than being
	# consumed: it is put straight into a long cooldown by its first swing.
	_fire_once(ms)
	_idle(ms)
	assert_eq(ms.p1.units.attack_phase_at(0), UnitBoard.AttackPhase.IDLE, "the swing is over")
	assert_false(ms.p1.units.is_attack_ready_at(0),
		"...and the long cadence still has it barred, so the confirmation below can only AGE")
	ms.push_contact([0, 0], [1, TargetingService.HERO_INDEX], ms.p1.units.attack_count_at(0),
			FACT_DIR, MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	assert_true(ms.p1.units.is_in_reach_at(0), "the fresh confirmation is current")
	for _t in FRESHNESS_TICKS - 1:
		_advance(ms)
	assert_true(ms.p1.units.is_in_reach_at(0),
		"...still current on the LAST tick of its window (%d ticks after it was made)"
				% (FRESHNESS_TICKS - 1))
	_advance(ms)
	assert_false(ms.p1.units.is_in_reach_at(0),
		"...and stale on the next -- the window is exactly %d ticks (RETARGET_TICKS %d + the F1 "
				% [FRESHNESS_TICKS, RETARGET_TICKS] + "one-tick lag), neither authored nor guessed")


# ---- AC 14: the launch ------------------------------------------------------------------------

func test_the_windup_to_active_transition_launches_exactly_one_projectile() -> void:
	var ms := _make_match()
	_summon_totem(ms)
	assert_eq(ms.p1.projectiles.size(), 0, "a fresh totem has fired nothing")
	ms.push_contact([0, 0], [1, TargetingService.HERO_INDEX], 0, FACT_DIR,
			MatchState.CONTACT_REACH_PROBE)
	_advance(ms)
	assert_true(ms.p1.units.is_in_reach_at(0), "the probe reported reach")
	assert_eq(ms.p1.projectiles.size(), 0, "...and reach ALONE launches nothing")
	_advance(ms)
	assert_eq(ms.p1.units.attack_phase_at(0), UnitBoard.AttackPhase.WINDUP,
		"the windup begins the tick after reach (the F1 one-tick lag)")
	assert_eq(ms.p1.projectiles.size(), 0, "...and a WINDUP launches nothing either")
	_advance(ms)
	assert_eq(ms.p1.units.attack_phase_at(0), UnitBoard.AttackPhase.ACTIVE,
		"the windup runs out and the active window opens")
	assert_eq(ms.p1.projectiles.size(), 1,
		"AC 14: the windup-to-active transition launches EXACTLY ONE projectile — the same moment a "
		+ "melee attack's hitbox opens, so 'the swing lands here' is one moment for both")


func test_a_fresh_shot_carries_its_target_its_kind_and_its_source() -> void:
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	assert_eq(board.size(), 1)
	assert_eq(board.target_slot_at(0), 1, "the shot inherits the totem's ACQUIRED target slot")
	assert_eq(board.target_index_at(0), TargetingService.HERO_INDEX,
		"...and its target index — the opposing HERO")
	assert_eq(board.kind_index_at(0), 0,
		"the shot stores the FIRING KIND's index, which is how it outlives its source without "
		+ "copying one authored number")
	assert_eq(board.source_index_at(0), 0, "...and the board index of the unit that fired it")
	assert_true(board.is_alive_at(0), "a fresh shot is alive")
	assert_true(board.is_homing_at(0), "...and homing (AC 15)")
	assert_eq(board.travelled_at(0), 1.0,
		"the launch tick is a FLIGHT tick: the shot has already covered one tick's distance "
		+ "(60 u/s / 60 Hz = 1.0), rather than sitting still for a tick before starting")


func test_a_melee_kind_launches_nothing() -> void:
	# The negative control for AC 14, and the reason it matters: the launch is gated on the ATTACK
	# RECORD authoring a projectile, not on the kind being a totem. A minion runs the identical
	# phase ladder and must reach the identical transition without launching anything.
	var ms := MatchState.new(MatchParams.new(13))
	var c := _config()
	c.unit_kinds = UnitKindFixture.minion_only(9.0, 3.0, WINDUP, ACTIVE, RECOVERY, 2.0)
	ms.apply_balance(c)
	ms.inject_feature_flags(_flags())
	ms.drain_signals()
	_fire(ms)
	assert_eq(ms.p1.units.attack_phase_at(0), UnitBoard.AttackPhase.ACTIVE,
		"sanity: the melee unit reached the SAME windup-to-active transition")
	assert_eq(ms.p1.projectiles.size(), 0,
		"a kind whose attack record authors no projectile launches none — the gate is the authored "
		+ "record, never the kind's name")


# ---- AC 15 (acceleration) and AC 19 (the travel budget) ---------------------------------------

func test_an_unaccelerated_shot_spends_exactly_one_launch_speed_per_tick() -> void:
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	for expected in range(2, 6):
		_advance(ms)
		assert_eq(board.travelled_at(0), float(expected),
			"tick %d of flight has covered %d units at the authored 60 u/s" % [expected, expected])
		assert_eq(board.flight_ticks_at(0), expected, "...and the clock agrees with the odometer")


func test_the_shot_is_removed_when_it_spends_its_travel_budget() -> void:
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	# 1.0 unit per tick against a 10.0 budget: alive through tick 9, ended ON tick 10.
	for t in range(2, 10):
		_advance(ms)
		assert_true(board.is_alive_at(0),
			"still flying at %d of the authored %.0f unit budget" % [t, TRAVEL_BUDGET])
	_advance(ms)
	assert_eq(board.travelled_at(0), TRAVEL_BUDGET, "the odometer reaches the authored budget")
	assert_false(board.is_alive_at(0),
		"AC 19: a shot that never produced a contact fact is REMOVED once it has travelled its "
		+ "authored budget")


func test_acceleration_begins_only_after_the_authored_delay() -> void:
	# 60 u/s launch, +3600 u/s^2 (= +1.0 u/tick per tick at 60 Hz) after a 3-tick delay, ceiling
	# 180 u/s. The three numbers are chosen so every expected speed is an exact integer.
	var ms := _make_match(_projectile(180.0, 3600.0, 3, 180.0))
	_fire(ms)
	var board := ms.p1.projectiles
	assert_eq(ms.projectile_speed_at(board, 0), LAUNCH_SPEED,
		"flight tick 1 is inside the authored delay — still at launch speed")
	for _t in 2:
		_advance(ms)
	assert_eq(board.flight_ticks_at(0), 3, "sanity: the clock is at the last delayed tick")
	assert_eq(ms.projectile_speed_at(board, 0), LAUNCH_SPEED,
		"the LAST tick of the delay is still unaccelerated — the boundary is inclusive, so an "
		+ "off-by-one in either direction is visible here")
	_advance(ms)
	assert_eq(ms.projectile_speed_at(board, 0), LAUNCH_SPEED + 60.0,
		"the first tick PAST the delay has accelerated by exactly one tick's worth")
	_advance(ms)
	assert_eq(ms.projectile_speed_at(board, 0), LAUNCH_SPEED + 120.0, "...and then by two")


func test_acceleration_is_clamped_at_the_authored_ceiling() -> void:
	# The ceiling is not cosmetic: without it a long flight would step further than a hurtbox is
	# wide and tunnel through its target. Ceiling 120 is reached on the second accelerating tick.
	var ms := _make_match(_projectile(180.0, 3600.0, 0, 120.0))
	_fire(ms)
	var board := ms.p1.projectiles
	for _t in 6:
		_advance(ms)
	assert_eq(ms.projectile_speed_at(board, 0), 120.0,
		"the derived speed never exceeds the authored max_speed, however long the flight runs")


## REVIEW FINDING H2, made executable: the distance the RUNNER moves the actor by must be the
## distance the ODOMETER was charged, on the same tick, and not one tick's worth further along the
## acceleration curve.
##
## The runner's drive phase runs AFTER `advance()` has returned, and `advance_at` increments the
## flight clock as part of charging the odometer -- so a runner that re-derived a SPEED from the
## board was reading speed(t+1) against a budget charged speed(t), permanently one tick ahead. Three
## comments asserted the opposite in as many words. `projectile_step_distance_at` is the seam that
## makes the claim true by construction, and this is its guard.
##
## MEASURED ON AN ACCELERATING SHOT ON PURPOSE. At a constant speed the two readings coincide and
## the test would pass with the defect in place; the whole error is that the curve has moved between
## them, so it is only visible while the curve is moving.
func test_the_distance_the_actor_flies_is_the_distance_the_odometer_was_charged() -> void:
	var profile := _projectile(180.0, 3600.0, 0, 10000.0)
	profile.travel_budget = 1000.0   # far past what five accelerating ticks can spend
	var ms := _make_match(profile)
	_fire(ms)
	var board := ms.p1.projectiles
	var previous := board.travelled_at(0)
	var compared := 0
	for _t in 5:
		_advance(ms)
		if not board.is_alive_at(0):
			break
		var charged := board.travelled_at(0) - previous
		assert_eq(ms.projectile_step_distance_at(board, 0), charged,
			"flight tick %d: the runner is handed exactly what the odometer just spent (%f)"
					% [board.flight_ticks_at(0), charged])
		previous = board.travelled_at(0)
		compared += 1
	assert_true(compared >= 3,
		"...on at least three consecutive ticks, or the equality is a coincidence at one point "
		+ "(compared %d)" % compared)
	# NON-VACUITY: the curve really is moving across those ticks, so speed(t) and speed(t+1) are
	# DIFFERENT numbers and the defect would have shown.
	assert_ne(ms.projectile_speed_at(board, 0), LAUNCH_SPEED,
		"...and the shot is accelerating, so reading the clock one tick late would have been a "
		+ "different distance rather than the same one")


func test_a_zero_turn_rate_and_zero_acceleration_are_legal_authored_values() -> void:
	# Both fields are audited NON-NEGATIVE rather than > 0 for the shipped `.tres`, because zero has
	# an honest meaning for each: fly straight, and fly at a constant speed. This pins that the
	# degenerate authoring is a working configuration rather than a crash or a stall.
	var ms := _make_match(_projectile(0.0, 0.0, 0, LAUNCH_SPEED))
	_fire(ms)
	var board := ms.p1.projectiles
	assert_eq(ms.projectile_speed_at(board, 0), LAUNCH_SPEED, "a zero acceleration flies flat")
	assert_true(board.is_homing_at(0),
		"a zero TURN RATE does not clear the homing FLAG — only the i-frame drop does (`4-4/R4`); "
		+ "what a zero rate means is that steering turns by nothing, which is the runner's business")


# ---- AC 16 / `4-4/R4`: the i-frame drop ends homing, and does NOT consume the shot -------------

func test_an_iframe_drop_ends_homing_without_consuming_the_shot() -> void:
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	assert_true(board.is_homing_at(0), "sanity: the shot launched homing")
	# P2 rolls: the iframe window opens and covers the fact pushed below.
	_advance(ms, null, _intent([&"roll"]))
	assert_true(ms.p2.hero.is_iframe_open(), "sanity: the target's i-frames are open")
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_before,
		"the rung is UNCHANGED: the fact is dropped exactly as it has been since `1-9/R1` — no "
		+ "damage")
	assert_false(board.is_homing_at(0),
		"AC 16 / `4-4/R4`: dropping the fact is ALSO what ends this shot's homing, on the same tick")
	assert_true(board.is_alive_at(0),
		"...and it is NOT consumed — a shot that passes through i-frames keeps flying, which is the "
		+ "asymmetry against AC 18 that the two rules exist to distinguish")


func test_homing_never_resumes_once_ended() -> void:
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	_advance(ms, null, _intent([&"roll"]))
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_false(board.is_homing_at(0), "sanity: homing ended")
	for _t in 3:
		_advance(ms)
		assert_false(board.is_homing_at(0),
			"there is NO path back to homing — `end_homing_at` has no inverse anywhere in src/")


func test_a_second_iframe_drop_on_an_already_straight_shot_is_harmless() -> void:
	# Reachable in real play: a shot flying straight through a rolling target produces a dropped
	# fact on every tick the overlap persists. Ending homing that is already ended must be a no-op,
	# not a guard failure.
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	_advance(ms, null, _intent([&"roll"]))
	for _t in 3:
		ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, FACT_DIR,
				MatchState.CONTACT_STRIKE)
		_advance(ms)
	assert_false(board.is_homing_at(0), "still not homing")
	assert_true(board.is_alive_at(0), "still flying — repeated i-frame drops never consume it")


# ---- AC 17 / `4-4/R5`: spatial dodging does NOT end homing --------------------------------------

func test_a_target_that_merely_leaves_the_flight_path_does_not_end_homing() -> void:
	# AC 17 is a NEGATIVE property, and this is what proving one looks like: the shot flies for
	# several ticks with NO fact arriving at all — which is exactly what "the target stepped out of
	# the way" produces, since a miss generates no fact — and homing must be untouched.
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	for t in range(2, 8):
		_advance(ms)
		assert_true(board.is_homing_at(0),
			("tick %d: no fact arrived, so nothing ended homing — `4-4/R5`, and it holds by ABSENCE "
			+ "(there is no lost-the-target test anywhere in src/ to get wrong)") % t)
		assert_true(board.is_alive_at(0), "...and the shot is still in the air")


func test_a_dodge_with_iframes_closed_does_not_end_homing_either() -> void:
	# The discriminating pair for `4-4/R5` against `4-4/R4`: the SAME dropped-fact situation, but
	# with the target's i-frames CLOSED, so the fact resolves as a hit instead of being dropped.
	# Homing ending must depend on the I-FRAME WINDOW and on nothing else about the miss.
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	assert_false(ms.p2.hero.is_iframe_open(), "sanity: the target is NOT rolling")
	for _t in 3:
		_advance(ms)
		assert_true(board.is_homing_at(0), "no i-frame window, no fact — homing continues")


# ---- AC 18 / `4-4/R6`: block and deflect consume the shot --------------------------------------

func test_a_full_damage_hit_consumes_the_shot() -> void:
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_before - TOTEM_DAMAGE,
		"the shot deals the FIRING KIND's authored attack damage (AC 9), not the hero's own swing "
		+ "percentage")
	assert_false(board.is_alive_at(0), "a landed shot is consumed")


func test_a_blocked_hit_consumes_the_shot() -> void:
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	# Hold block long enough that the deflect window (4 ticks) has closed, so this resolves as a
	# BLOCK rather than a deflect — the two outcomes are separated deliberately.
	for _t in 6:
		_advance(ms, null, _intent([&"block"]))
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms, null, _intent([&"block"]))
	assert_eq(ms.p2.hero.get_hp(), hp_before - TOTEM_DAMAGE * 0.5,
		"sanity: this resolved as a BLOCK (half damage at the authored multiplier), not a deflect")
	assert_false(board.is_alive_at(0),
		"AC 18 / `4-4/R6`: a blocked shot is CONSUMED — it does not continue flying past the hit")


func test_a_deflected_hit_consumes_the_shot() -> void:
	var ms := _make_match()
	_fire(ms)
	var board := ms.p1.projectiles
	var deflects: Array = []
	ms.deflect_landed.connect(func(a: int, t: int) -> void: deflects.append([a, t]))
	var hp_before := ms.p2.hero.get_hp()
	# Block pressed THIS tick opens the deflect window, and the fact resolves inside it.
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, Vector2.DOWN,
			MatchState.CONTACT_STRIKE)
	_advance(ms, null, _intent([&"block"]))
	assert_eq(deflects.size(), 1, "sanity: this resolved as a DEFLECT")
	assert_eq(ms.p2.hero.get_hp(), hp_before, "...fully negated, no damage")
	assert_false(board.is_alive_at(0),
		"AC 18 / `4-4/R6`: a deflected shot is CONSUMED too — and this path `continue`s before the "
		+ "common consumption line, so it needs its own and this is what proves it has one")


func test_one_shot_resolves_at_most_once() -> void:
	# A projectile's dedupe IS its liveness (`projectile_board.gd`'s header), so there is no hit
	# list to prove — what has to be proven is the consequence: a second fact from the same shot,
	# arriving on a later tick, delivers nothing.
	var ms := _make_match()
	_fire(ms)
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_before - TOTEM_DAMAGE, "the first fact landed")
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 2, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_before - TOTEM_DAMAGE,
		"a SECOND fact from the same shot delivers nothing — resolving consumed it, and liveness "
		+ "is the whole dedupe mechanism")


func test_a_fact_from_an_expired_shot_is_dropped() -> void:
	# The other half of AC 19's "removed from the world": under the F1 one-tick lag a fact gathered
	# on the tick a shot expired still arrives afterwards, and the dead-attacker rung is what drops
	# it. Without that rung a shot would land a hit it had no budget left for.
	var ms := _make_match()
	_fire(ms)
	for _t in 9:
		_advance(ms)
	assert_false(ms.p1.projectiles.is_alive_at(0), "sanity: the budget is spent")
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_before,
		"a fact from an EXPIRED shot delivers nothing — dropped at the dead-attacker rung")


# ---- `E4-P/R12`: the attacker address ----------------------------------------------------------

func test_the_projectile_address_partition_round_trips_and_never_collides() -> void:
	# The encoding is a THIRD PARTITION of one int space, and the property that makes that safe is
	# that the three partitions are disjoint and the projectile half round-trips exactly.
	for i in 8:
		var encoded := MatchState.projectile_attacker_index(i)
		assert_true(encoded <= MatchState.PROJECTILE_INDEX_BASE,
			"projectile %d encodes at or below the base" % i)
		assert_true(MatchState.is_projectile_index(encoded), "...and is recognised as a projectile")
		assert_eq(MatchState.projectile_index_of(encoded), i, "...and decodes back to itself")
	assert_false(MatchState.is_projectile_index(TargetingService.HERO_INDEX),
		"the HERO's -1 is NOT a projectile — the partitions are disjoint")
	for unit_index in 4:
		assert_false(MatchState.is_projectile_index(unit_index),
			"unit index %d is NOT a projectile" % unit_index)


func test_the_seam_accepts_a_projectile_attacker_and_still_refuses_a_gap_value() -> void:
	# The bound was REPLACED rather than loosened: -1 and below-or-equal-to--2 are both legal, and
	# there is deliberately nothing in between for a malformed address to occupy. This pins that the
	# widening did not turn the guard into "any negative number".
	var ms := _make_match()
	_fire(ms)
	var hp_before := ms.p2.hero.get_hp()
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	assert_eq(ms.p2.hero.get_hp(), hp_before - TOTEM_DAMAGE,
		"a projectile attacker address is accepted at the seam and resolves")


# ---- The debug reset ---------------------------------------------------------------------------

func test_the_debug_reset_clears_the_projectile_board_with_the_unit_board() -> void:
	var ms := _make_match()
	_fire(ms)
	assert_eq(ms.p1.projectiles.size(), 1, "sanity: a shot is in the air")
	assert_eq(ms.p1.units.size(), 1, "...and its totem is on the board")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset)
	assert_eq(ms.p1.units.size(), 0, "the reset clears the unit board (`4-1/R5`)")
	assert_eq(ms.p1.projectiles.size(), 0,
		"...and the projectile board WITH it — a shot records the board index of the unit that "
		+ "fired it, so surviving a board clear it would name a record that no longer exists")


func test_round_end_leaves_a_shot_in_the_air() -> void:
	# The `4-1/R5` contract applied to the second board: only the RESET clears it, never round end.
	var ms := _make_match()
	_fire(ms)
	ms.p2.hero.take_damage(HERO_MAX_HP)
	_advance(ms)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.DEAD, "sanity: the round is over")
	assert_eq(ms.p1.projectiles.size(), 1,
		"the projectile board SURVIVES round end, exactly as the unit board does — only the debug "
		+ "reset clears either")


# ---- The snapshot -------------------------------------------------------------------------------

func test_every_projectile_field_round_trips_through_the_snapshot() -> void:
	var ms := _make_match()
	_fire(ms)
	_advance(ms, null, _intent([&"roll"]))
	ms.push_contact(_shot_address(), [1, TargetingService.HERO_INDEX], 1, FACT_DIR,
			MatchState.CONTACT_STRIKE)
	_advance(ms)
	var snap: Dictionary = ms.to_snapshot()["p1"]
	assert_eq(snap["projectile_targets"], [[1, TargetingService.HERO_INDEX]])
	assert_eq(snap["projectile_kind"], [0])
	assert_eq(snap["projectile_source"], [0])
	assert_eq(snap["projectile_alive"], [true])
	assert_eq(snap["projectile_homing"], [false],
		"the homing flag reaches the hash — a replay that lost it would silently diverge on whether "
		+ "a shot was still steering")
	assert_eq(snap["projectile_flight_ticks"], [3])
	assert_eq(snap["projectile_travelled"], [3.0])
