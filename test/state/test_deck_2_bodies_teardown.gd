extends TestCase

## Story 7-5b (AC 25): EVERY NEW HASHED FACT IS CLEARED AT BOTH TEARDOWN SEATS -- `_end_round` and
## `_reset_player` -- one test per fact, each in BOTH directions (`test_deck_2_teardown.gd`'s shape). The
## new facts (Dev Agent Record): the per-player `volley` and `knockback` keys, the `cast` key's frozen pulse
## radius, the `reversal` key's per-part amounts, the board's `unit_heal_ticks`, `unit_heal_count`,
## `unit_shot_owed` and `unit_knockback`, and the projectile board's `projectile_color`.
##
## THE BOARD FACTS REST DIFFERENTLY AT THE TWO SEATS, and that is `4-1/R5`: round end leaves every record on
## the board (so each per-record fact rests IN PLACE -- a zero, a -1, a stopped slide), while the reset
## empties the board (so the key is the empty list a fresh match carries).
##
## EACH TEST arms the fact through real play, proves the key is NOT at rest, then ends the round (the other
## seat's hero dies) and asserts rest, and repeats on a second match with the debug reset.

const Fx := preload("res://test/deck_2_bodies_fixture.gd")
const F := preload("res://test/deck_2_fixture.gd")

const RESTING_CAST := ["", 0, PlayerState.NO_CAST_EFFECT_MODE, TargetingService.NO_TARGET_SLOT,
		TargetingService.HERO_INDEX, 0.0, 0.0]
const RESTING_REVERSAL := [PlayerState.REVERSAL_NONE, [], [], [], [], 0.0, 0.0, []]


func test_the_volley_clears_at_both_seats() -> void:
	_check(0, "volley", _arm_volley, ["", [], 0], ["", [], 0])


func test_the_hero_knockback_clears_at_both_seats() -> void:
	_check(1, "knockback", _arm_pulse_on_hero, [0, Vector2.ZERO, 0.0], [0, Vector2.ZERO, 0.0])


## The pending pulse is the CAST, and its frozen radius rides the cast key: round end and the reset both
## end the cast (no pulse crosses either).
func test_the_pending_pulse_and_its_radius_clear_at_both_seats() -> void:
	_check(0, "cast", _arm_windup, RESTING_CAST, RESTING_CAST)


func test_the_per_part_reversal_amounts_clear_at_both_seats() -> void:
	_check(0, "reversal", _arm_pulse_on_hero, RESTING_REVERSAL, RESTING_REVERSAL)
	var probe := Fx.make()
	_arm_pulse_on_hero(probe)
	var packet: Array = probe.p1.to_snapshot()["reversal"]
	assert_eq(packet[7], [Fx.WRATH_DAMAGE], "non-vacuity: the armed packet carries the per-part amount")


func test_the_heal_clock_clears_at_both_seats() -> void:
	_check(0, "unit_heal_ticks", _arm_heal_clock, [0], [])


func test_the_heal_count_clears_at_both_seats() -> void:
	_check(0, "unit_heal_count", _arm_one_heal, [0], [])


## An OWED HEALER SHOT never crosses a round end or a reset.
func test_an_owed_healer_shot_clears_at_both_seats() -> void:
	_check(0, "unit_shot_owed", _arm_owed_shot, [UnitBoard.NO_SHOT_OWED], [])


func test_a_units_knockback_clears_at_both_seats() -> void:
	_check(1, "unit_knockback", _arm_unit_slide, [[0, Vector2.ZERO, 0.0]], [])


func test_a_projectiles_colour_clears_at_both_seats() -> void:
	_check(0, "projectile_color", _arm_red_projectile, [ProjectileBoard.NO_COLOR], [])


# ---------------------------------------------------------------- arming

func _arm_volley(ms: MatchState) -> void:
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.stage(ms, 0, Fx.FURY, 2)
	F.set_orbs(ms, ms.p1, 2, 1, 0)
	F.activate(ms, 0)


func _arm_red_projectile(ms: MatchState) -> void:
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.stage(ms, 0, Fx.FURY, 2)
	F.set_orbs(ms, ms.p1, 1, 1, 0)
	F.activate(ms, 0)


func _arm_windup(ms: MatchState) -> void:
	Fx.cast_wrath(ms, 0, 1)


func _arm_pulse_on_hero(ms: MatchState) -> void:
	Fx.cast_wrath(ms, 0)
	Fx.run_windup(ms, 0, [[TargetingService.HERO_INDEX, Vector2.LEFT]])


func _arm_unit_slide(ms: MatchState) -> void:
	var walker := Fx.add_unit(ms, 1, Fx.KIND_WALKER)
	Fx.cast_wrath(ms, 0)
	Fx.run_windup(ms, 0, [[walker, Vector2.LEFT]])


func _arm_heal_clock(ms: MatchState) -> void:
	Fx.summon_healer(ms, 0)
	F.idle(ms, 3)


func _arm_one_heal(ms: MatchState) -> void:
	Fx.summon_healer(ms, 0)
	F.set_hp(ms, ms.p1, 50.0)
	for _t in Fx.HEAL_INTERVAL_TICKS:
		Fx.advance_with_ranges(ms, [[0, 0]])


func _arm_owed_shot(ms: MatchState) -> void:
	Fx.summon_healer(ms, 0)
	F.press_unblockable(ms, 0)


# ---------------------------------------------------------------- the two directions

## Arm with `arm` on two matches; end the round on one (the OTHER seat's hero dies, so `side`'s own facts are
## the ones round end must clear) and reset the other; assert `side`'s `key` rests at `ended_rest` and
## `reset_rest` respectively.
func _check(side: int, key: String, arm: Callable, ended_rest: Variant, reset_rest: Variant) -> void:
	var ended := Fx.make()
	arm.call(ended)
	assert_ne(F.seat(ended, side).to_snapshot()[key], ended_rest,
		"`%s`: armed before round end (non-vacuity)" % key)
	F.seat(ended, 1 - side).hero.take_damage(F.MAX_HP)
	F.idle(ended, 1)
	assert_true(ended.to_snapshot()["round_over"], "`%s`: the round ended" % key)
	assert_eq(F.seat(ended, side).to_snapshot()[key], ended_rest, "`%s` is cleared by `_end_round`" % key)
	var reset := Fx.make()
	arm.call(reset)
	assert_ne(F.seat(reset, side).to_snapshot()[key], reset_rest,
		"`%s`: armed before the reset (non-vacuity)" % key)
	var intent := InputIntent.new()
	intent.debug_reset = true
	F.act(reset, 0, intent)
	assert_false(reset.to_snapshot()["round_over"], "`%s`: the reset left the round live" % key)
	assert_eq(F.seat(reset, side).to_snapshot()[key], reset_rest, "`%s` is cleared by the debug reset" % key)
