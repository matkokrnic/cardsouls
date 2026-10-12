extends TestCase

## Story 7-5a, PART B (AC 26, AC 38, AC 54): EVERY NEW HASHED PER-PLAYER FACT IS CLEARED AT BOTH TEARDOWN
## SEATS -- `_end_round` and `_reset_player` -- one test per fact, each in BOTH directions. The `6-5a` B1
## lesson made a standing check: round-crossing hashed state that one seat forgets leaves a reset match
## and a fresh match at different resting snapshots.
##
## THE NINE FACTS (story Dev Notes): the staging count, Setup charges, the per-attack Setup carry, Execute
## charges, Stoneskin charges, the Enrage window list, the Lifechain window list, the per-slot Manablossom
## discount, and the per-cast reversal data (the packet's new kinds and its second scalar).
##
## EACH TEST arms the fact on P1 through real play, proves the snapshot key is NOT at rest, then ends the
## round (P2 dies) and asserts rest, and repeats on a second match with the debug reset.

const F := preload("res://test/deck_2_fixture.gd")

## key -> resting value, as a fresh dealt match snapshots it.
const RESTING := {
	"stagings": 0,
	"setup": [0, 0.0],
	"charge_setup": 0.0,
	"execute": [0, 0.0],
	"stoneskin": 0,
	"enrage": [],
	"lifechain": [],
	"hand_discount": [0.0, 0.0, 0.0, 0.0],
	"reversal": [PlayerState.REVERSAL_NONE, [], [], [], [], 0.0, 0.0],
}


## The resting table is not a transcription: it IS what a fresh dealt match snapshots.
func test_the_resting_values_are_what_a_fresh_match_snapshots() -> void:
	var fresh := F.make().p1.to_snapshot()
	for key: String in RESTING:
		assert_true(fresh.has(key), "the per-player snapshot carries `%s`" % key)
		assert_eq(fresh.get(key), RESTING[key], "`%s` rests at %s" % [key, RESTING[key]])


func test_the_staging_count_clears_at_both_seats() -> void:
	_check("stagings", func(ms: MatchState) -> void: F.stage(ms, 0, F.PLAIN))


func test_setup_charges_clear_at_both_seats() -> void:
	_check("setup", func(ms: MatchState) -> void: F.play(ms, 0, F.SETUP))


func test_the_setup_carry_clears_at_both_seats() -> void:
	_check("charge_setup", func(ms: MatchState) -> void:
		F.play(ms, 0, F.SETUP)
		F.press_unblockable(ms, 0))


func test_execute_charges_clear_at_both_seats() -> void:
	_check("execute", func(ms: MatchState) -> void: F.pitch(ms, 0, F.SETUP))


func test_stoneskin_charges_clear_at_both_seats() -> void:
	_check("stoneskin", func(ms: MatchState) -> void: F.pitch(ms, 0, F.STONE))


func test_the_enrage_windows_clear_at_both_seats() -> void:
	_check("enrage", func(ms: MatchState) -> void: F.pitch(ms, 0, F.BLOOD))


func test_the_lifechain_windows_clear_at_both_seats() -> void:
	_check("lifechain", func(ms: MatchState) -> void: F.pitch(ms, 0, F.CHAIN))


func test_the_manablossom_discounts_clear_at_both_seats() -> void:
	_check("hand_discount", func(ms: MatchState) -> void:
		F.put(ms.p1, 1, F.PLAIN)
		F.play(ms, 0, F.BLOSSOM))


## The ninth fact: the per-cast reversal data. Bloodmagic is the kind that writes BOTH scalars, so it is
## the one that proves the packet's new seventh element is cleared with the rest.
func test_the_reversal_data_of_a_new_half_clears_at_both_seats() -> void:
	_check("reversal", func(ms: MatchState) -> void:
		F.set_mana(ms, ms.p1, 2.0)
		F.play(ms, 0, F.BLOOD))
	var probe := F.make()
	F.set_mana(probe, probe.p1, 2.0)
	F.play(probe, 0, F.BLOOD)
	var packet: Array = probe.p1.to_snapshot()["reversal"]
	assert_eq([int(packet[0]), float(packet[5]), float(packet[6])],
		[PlayerState.REVERSAL_BLOODMAGIC, F.BLOOD_MANA, F.BLOOD_HP],
		"non-vacuity: the armed packet really carries the kind and BOTH scalars")


## The whole of AC 54 at once, the B1 shape: after every fact is armed together, a reset match and a fresh
## match sit at the SAME resting value on every one of the nine keys.
func test_a_reset_match_and_a_fresh_match_rest_identically_on_all_nine_keys() -> void:
	var ms := F.make()
	F.stage(ms, 0, F.PLAIN)
	ms.pitch.clear(0)
	# TWO Setups: the press at the end spends one (arming the carry) and one stays held.
	F.play(ms, 0, F.SETUP)
	F.play(ms, 0, F.SETUP)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.pitch(ms, 0, F.SETUP)
	F.pitch(ms, 0, F.STONE)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.pitch(ms, 0, F.BLOOD)
	F.pitch(ms, 0, F.CHAIN)
	F.set_mana(ms, ms.p1, F.MAX_MANA)
	F.put(ms.p1, 2, F.PLAIN)
	F.play(ms, 0, F.BLOSSOM)
	F.press_unblockable(ms, 0)
	var armed := ms.p1.to_snapshot()
	for key: String in RESTING:
		assert_ne(armed.get(key), RESTING[key], "non-vacuity: `%s` is armed before the reset" % key)
	_reset(ms)
	var after := ms.p1.to_snapshot()
	var fresh := F.make().p1.to_snapshot()
	for key: String in RESTING:
		assert_eq(after.get(key), fresh.get(key), "after a reset `%s` equals a fresh match's" % key)


# ---------------------------------------------------------------- the two directions

## Arm the fact with `arm` on two matches; end the round on one and reset the other; assert rest on both.
func _check(key: String, arm: Callable) -> void:
	var ended := F.make()
	arm.call(ended)
	assert_ne(ended.p1.to_snapshot()[key], RESTING[key], "`%s`: armed before round end (non-vacuity)" % key)
	ended.p2.hero.take_damage(F.MAX_HP)
	F.idle(ended, 1)
	assert_true(ended.to_snapshot()["round_over"], "`%s`: the round ended" % key)
	assert_eq(ended.p1.to_snapshot()[key], RESTING[key], "`%s` is cleared by `_end_round`" % key)
	var reset := F.make()
	arm.call(reset)
	assert_ne(reset.p1.to_snapshot()[key], RESTING[key], "`%s`: armed before the reset (non-vacuity)" % key)
	_reset(reset)
	assert_false(reset.to_snapshot()["round_over"], "`%s`: the reset left the round live" % key)
	assert_eq(reset.p1.to_snapshot()[key], RESTING[key], "`%s` is cleared by the debug reset" % key)


func _reset(ms: MatchState) -> void:
	var intent := InputIntent.new()
	intent.debug_reset = true
	F.act(ms, 0, intent)
