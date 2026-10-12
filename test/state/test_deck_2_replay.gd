extends TestCase

## Story 7-5a, PART B (AC 53, on the `6-5e` AC 41 precedent): A RECORDED MATCH EXERCISING THE NEW MECHANICS,
## WITH THE TWO SEATS ON DIFFERENT DECKS, SAVED AND RELOADED, REPLAYS TO THE IDENTICAL FINAL HASH AND RECORD.
##
## THE RUN, in order (P1 on the "tall" list, P2 on the "wide" one):
##   1. P1 plays SETUP, then lands an unblockable -- the doubled orb grant.
##   2. P1 pitches EXECUTE and a MELEE hit consumes it; pitches it again and an UNBLOCKABLE consumes it.
##   3. P1 pitches STONESKIN and it absorbs P2's unblockable.
##   4. P1 plays BLOODMAGIC, pitches ENRAGE, plays MANABLOSSOM and then a DISCOUNTED card, plays MANAPULATION.
##   5. P2 summons two minions and pitches LIFECHAIN; P1's hit on P2 is split onto both minions.
##   6. P1 plays SETUP again and P2's COUNTERSPELL removes the charge.
##
## THIS FILE PLAYS THE RUNNER'S ROLE, capturing on every channel beside the call it taps. It reads the LIVE
## state to choose a hand slot and to decide how long to wait -- sound for a replay BECAUSE the chosen slot
## and the waited ticks travel in the recorded intent stream: the replay presses what was pressed.
##
## Every card is dealt out (hand size == deck size), so no step depends on what a seed happened to deal,
## and nothing here writes state directly: orbs are EARNED by landings and mana by the authored regen.

const F := preload("res://test/deck_2_fixture.gd")
const SEED := 75053
const RECORD_PATH := "user://test_deck_2_replay.rec"
const RESAVED_PATH := "user://test_deck_2_replay_resaved.rec"
const HAND := 14
const MANA_REGEN_PER_TICK := 0.2
## A pool cap far above anything this run reaches (the pool fills by regen while the run waits), so no gain or
## regen is ever clamped and every mana reading below is the card's exact effect. At the fixture's own cap of 10
## the pool sat AT the cap through most of the run and silently clamped the gains the old readings reported.
const POOL_CAP := 1000.0
const WAIT_LIMIT := 600

## P1, the "tall" list: Setup / Execute, Stoneskin, Bloodmagic / Enrage, Manablossom, Manapulation.
const P1_DECK: Array[StringName] = [
	F.SETUP, F.SETUP, F.SETUP, F.SETUP, F.PLAIN, F.PLAIN, F.PLAIN, F.STONE, F.STONE,
	F.BLOOD, F.BLOOD, F.BLOOD, F.BLOSSOM, F.PULATION,
]
## P2, the "wide" list: the summon / Lifechain card, the Counterspell card, and filler.
const P2_DECK: Array[StringName] = [
	F.CHAIN, F.CHAIN, F.CHAIN, F.CHAIN, F.COUNTER, F.COUNTER, F.PLAIN, F.PLAIN, F.PLAIN,
	F.PLAIN, F.PLAIN, F.PLAIN, F.PLAIN, F.PLAIN,
]

var _ms: MatchState
var _record: IntentRecorder
## A ONE-ELEMENT ARRAY, not an int member, because the `counterspell_resolved` lambda must not capture this
## test object: `self` holds `_ms`, and `_ms`'s connection list would hold a lambda holding `self` -- a
## reference cycle that leaks at exit (the 4-B1 review's lesson, applied to a test).
var _counters: Array = [0]


## AC 53, the primary: the run, SAVED and RELOADED, replays from that file alone to the identical hash --
## and the reloaded record, saved again, is the identical file.
func test_a_saved_and_reloaded_deck_2_run_replays_to_the_identical_hash_and_record() -> void:
	var evidence := _record_the_run()
	var live_hash := CanonicalHash.of(_ms.to_snapshot())
	assert_true(_record.tick_count() > 100, "the record carries a real run (%d ticks)" % _record.tick_count())
	assert_eq(RecordFile.save_record(_record, RECORD_PATH), "", "the record was written to disk")
	var result := RecordFile.load_record(RECORD_PATH)
	assert_not_null(result["record"], "...and it loads back: %s" % str(result["error"]))
	var loaded: IntentRecorder = result["record"]
	if loaded == null:
		return
	assert_eq(loaded.replay_seat_deck_contents(0), P1_DECK, "the record carries seat 1's own composition")
	assert_eq(loaded.replay_seat_deck_contents(1), P2_DECK, "...and seat 2's DIFFERENT one")
	assert_eq(CanonicalHash.of(_replay(loaded).to_snapshot()), live_hash,
		"AC 53: a replay driven from the SAVED AND RELOADED record alone is bit-identical")
	# THE RECORD IS IDENTICAL TOO: what was loaded, saved again, is the same file byte for byte.
	assert_eq(RecordFile.save_record(loaded, RESAVED_PATH), "", "the reloaded record was written again")
	assert_eq(FileAccess.get_file_as_bytes(RESAVED_PATH), FileAccess.get_file_as_bytes(RECORD_PATH),
		"AC 53: the record survives save -> load -> save unchanged")
	# The falsifying half. Without the contacts no unblockable lands and no orb is ever earned; without the
	# intents nothing is pressed; with the two seats' decks SWAPPED the recorded slots name other cards.
	for channel: String in ["contacts", "intents", "swapped_decks"]:
		assert_ne(CanonicalHash.of(_replay(loaded, channel).to_snapshot()), live_hash,
			"dropping / corrupting `%s` must DIVERGE this replay" % channel)
	assert_true(bool(evidence["ran"]), "the run reached its end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESAVED_PATH))


## AC 53's other half: the recorded run must actually DO each thing, or a bit-identical replay would be
## proving something about a sequence of refusals. Every clause is measured on the LIVE run as it passed.
func test_the_deck_2_run_really_exercises_every_new_mechanic() -> void:
	var e := _record_the_run()
	assert_eq(int(e["setup_orbs"]), 2 * F.ORB_GRANT, "Setup, then an unblockable that LANDS: the doubled grant")
	assert_almost_eq(float(e["execute_melee_damage"]), F.HIT_DAMAGE * F.EXECUTE_MULTIPLIER, 0.0001,
		"Execute consumed by a MELEE hit: 3 becomes 9")
	assert_eq(int(e["execute_after_melee"]), 0, "...and the charge is gone")
	assert_almost_eq(float(e["execute_unblockable_damage"]), F.UNBLOCKABLE_DAMAGE * F.EXECUTE_MULTIPLIER, 0.0001,
		"Execute consumed by an UNBLOCKABLE: 10 becomes 30")
	assert_eq(int(e["stoneskin_before"]), 1, "P1 held a Stoneskin charge")
	assert_eq(float(e["stoneskin_damage"]), 0.0, "...and it ABSORBED P2's unblockable")
	assert_eq(int(e["stoneskin_after"]), 0, "...which consumed it")
	assert_true(bool(e["stoneskin_knockdown"]), "...while P1 was still knocked down")
	assert_eq(float(e["bloodmagic_hp"]), F.BLOOD_HP, "Bloodmagic took its HP price")
	assert_almost_eq(float(e["bloodmagic_mana"]), F.BLOOD_MANA, 0.0001, "...and gave its authored mana")
	assert_eq(int(e["enrage_windows"]), 1, "Enrage opened a window")
	assert_almost_eq(float(e["blossom_play_cost"]), F.PLAIN_MANA - F.BLOSSOM_DISCOUNT, 0.0001,
		"Manablossom, then a DISCOUNTED card played for 1 less")
	assert_eq(int(e["stagings"]), 4, "exactly four successful stagings were counted: Execute twice, Stoneskin, Enrage")
	assert_almost_eq(float(e["manapulation_mana"]), F.PULATION_MANA * 4.0, 0.0001,
		"Manapulation granted its authored mana for each of them")
	assert_eq(int(e["lifechain_minions"]), 2, "Lifechain was pitched with TWO minions alive")
	assert_true(float(e["lifechain_minion_0"]) > 0.0 and float(e["lifechain_minion_1"]) > 0.0,
		"...and BOTH took a share of the hit")
	assert_almost_eq(float(e["lifechain_hero"]), float(e["lifechain_minion_0"]), 0.0001,
		"...equal to the hero's own share")
	assert_eq(int(e["counter_before"]), 1, "P1 held the Setup charge its last play added")
	assert_eq(int(e["counter_after"]), 0, "...and P2's COUNTERSPELL removed it")
	assert_eq(int(e["counters_resolved"]), 1, "exactly one Counterspell resolved in the run")
	assert_eq([_ms.p1.stagings_this_round > 0, _ms.p2.stagings_this_round > 0], [true, true],
		"both seats' own staging counts are non-resting on the hashed final state")


# ---------------------------------------------------------------- the run

func _record_the_run() -> Dictionary:
	_record = IntentRecorder.new()
	_counters = [0]
	var counters := _counters
	var params := MatchParams.new(SEED)
	_record.capture_seed(params.seed_value)
	_ms = MatchState.new(params)
	var config := F.config()
	config.hand_size = HAND
	config.deck_size = HAND
	config.mana_regen_per_second = MANA_REGEN_PER_TICK * TimingWindow.TICK_HZ
	config.max_mana = POOL_CAP
	_record.capture_apply_balance(config)
	_ms.apply_balance(config)
	var flags := F.flags()
	_record.capture_inject_feature_flags(flags)
	_ms.inject_feature_flags(flags)
	# The six content channels, in `SOUND_CONTENT_ORDER` -- the deck channel PER SEAT.
	_record.capture_inject_seat_decks(P1_DECK, P2_DECK, ["tall", "wide"] as Array[String])
	_ms.inject_seat_decks(P1_DECK, P2_DECK)
	_record.capture_inject_card_costs(F.costs())
	_ms.inject_card_costs(F.costs())
	_record.capture_inject_card_effects(F.basic_effects())
	_ms.inject_card_effects(F.basic_effects())
	_record.capture_inject_card_colors(F.colors())
	_ms.inject_card_colors(F.colors())
	_record.capture_inject_pitch_costs(F.pitch_costs())
	_ms.inject_pitch_costs(F.pitch_costs())
	_record.capture_inject_pitch_effects(F.pitch_effects())
	_ms.inject_pitch_effects(F.pitch_effects())
	_ms.counterspell_resolved.connect(func(_caster: int, _countered: int) -> void: counters[0] += 1)
	var e: Dictionary = {"ran": false}
	_tick()   # the deal
	# 1. SETUP, then an unblockable that lands.
	_settle()
	_card(0, F.SETUP, Enums.ModeKind.BASIC)
	var red_before := _ms.p1.orbs.get_count(Enums.CardColor.RED)
	_unblockable(0, F.PLAIN)
	e["setup_orbs"] = _ms.p1.orbs.get_count(Enums.CardColor.RED) - red_before
	# 2. EXECUTE consumed by a melee hit...
	_settle()
	_pitch(0, F.SETUP)
	_settle()
	e["execute_melee_damage"] = _melee(0)
	e["execute_after_melee"] = _ms.p1.execute_charges
	# ...and by an unblockable.
	_settle()
	_pitch(0, F.SETUP)
	_settle()
	var hp_before := _ms.p2.hero.get_hp()
	_unblockable(0, F.PLAIN)
	e["execute_unblockable_damage"] = hp_before - _ms.p2.hero.get_hp()
	# 3. STONESKIN absorbing an unblockable. P1 earns the green orb with a green card first.
	_settle()
	_unblockable(0, F.STONE)
	_settle()
	_pitch(0, F.STONE)
	_settle()
	e["stoneskin_before"] = _ms.p1.stoneskin_charges
	hp_before = _ms.p1.hero.get_hp()
	_unblockable(1, F.PLAIN)
	e["stoneskin_damage"] = hp_before - _ms.p1.hero.get_hp()
	e["stoneskin_after"] = _ms.p1.stoneskin_charges
	e["stoneskin_knockdown"] = _ms.p1.hero.action_state == HeroState.ActionState.STUNNED
	# 4. BLOODMAGIC, ENRAGE, MANABLOSSOM + a discounted play, MANAPULATION.
	_settle()
	_unblockable(0, F.BLOOD)
	_settle()
	_pitch(0, F.BLOOD)
	e["enrage_windows"] = _ms.p1.active_enrage_count()
	# Every card reading below is taken across ONE tick, and that tick also regenerates mana. The regen is
	# MEASURED, not assumed: one recorded idle tick right before each reading gives this pool's exact gain per
	# tick, and the reading takes exactly that out. POOL_CAP is far above the pool, so no clamp hides part of the
	# regen or of the gain.
	# Bloodmagic straight after the pitch (the staging just spent 2).
	var regen := _regen_per_tick()
	hp_before = _ms.p1.hero.get_hp()
	var mana_before := _ms.p1.mana.get_current()
	_card(0, F.BLOOD, Enums.ModeKind.BASIC)
	e["bloodmagic_hp"] = hp_before - _ms.p1.hero.get_hp()
	e["bloodmagic_mana"] = _ms.p1.mana.get_current() - mana_before - regen
	_settle()
	_card(0, F.BLOSSOM, Enums.ModeKind.BASIC)
	regen = _regen_per_tick()
	mana_before = _ms.p1.mana.get_current()
	_card(0, F.PLAIN, Enums.ModeKind.BASIC)
	e["blossom_play_cost"] = mana_before - _ms.p1.mana.get_current() + regen
	e["stagings"] = _ms.p1.stagings_this_round
	regen = _regen_per_tick()
	mana_before = _ms.p1.mana.get_current()
	# Manablossom's discount is still on this card, so what it costs is its price less that discount.
	var pulation_slot := _ms.p1.hand.to_array().find(F.PULATION)
	var pulation_paid := maxf(0.0, float(F.costs()[F.PULATION].mana_cost) - _ms.p1.hand.discount_at(pulation_slot))
	_card(0, F.PULATION, Enums.ModeKind.BASIC)
	# What the card cost went out and one tick of regen came in.
	e["manapulation_mana"] = _ms.p1.mana.get_current() - mana_before - regen + pulation_paid
	# 5. P2 summons two minions, earns a green orb, pitches LIFECHAIN; P1's hit is split.
	_settle()
	_card(1, F.CHAIN, Enums.ModeKind.BASIC)
	_settle()
	_card(1, F.CHAIN, Enums.ModeKind.BASIC)
	_settle()
	_unblockable(1, F.CHAIN)
	_settle()
	_pitch(1, F.CHAIN)
	e["lifechain_minions"] = _ms.p2.units.living_indices().size()
	var minion_0 := _ms.p2.units.hp_at(0)
	var minion_1 := _ms.p2.units.hp_at(1)
	e["lifechain_hero"] = _melee(0)
	e["lifechain_minion_0"] = minion_0 - _ms.p2.units.hp_at(0)
	e["lifechain_minion_1"] = minion_1 - _ms.p2.units.hp_at(1)
	# 6. P2 earns a blue orb and stages its COUNTERSPELL; P1 plays SETUP; P2 activates.
	_settle()
	_unblockable(1, F.COUNTER)
	_settle()
	_card(1, F.COUNTER, Enums.ModeKind.PITCH)
	_settle()
	_card(0, F.SETUP, Enums.ModeKind.BASIC)
	e["counter_before"] = _ms.p1.setup_charges
	_tick(null, F.activate_intent())
	e["counter_after"] = _ms.p1.setup_charges
	e["counters_resolved"] = _counters[0]
	for _t in 5:
		_tick()
	e["ran"] = true
	return e


# ---------------------------------------------------------------- the runner's role

## One recorded tick: the contact facts are captured and pushed, then the intents captured and advanced.
func _tick(p1: InputIntent = null, p2: InputIntent = null, contacts: Array = []) -> void:
	for fact: Array in contacts:
		var attacker: Array[int] = [int(fact[0]), -1]
		var target: Array[int] = [int(fact[1]), -1]
		_record.capture_push_contact(attacker, target, int(fact[2]), F.FACT_DIR, int(fact[3]))
		_ms.push_contact(attacker, target, int(fact[2]), F.FACT_DIR, int(fact[3]))
	var intents: Array[InputIntent] = [p1 if p1 != null else InputIntent.new(),
			p2 if p2 != null else InputIntent.new()]
	_record.capture_advance(intents)
	_ms.advance(intents)
	_ms.drain_signals()


func _seat(index: int) -> PlayerState:
	return _ms.p1 if index == 0 else _ms.p2


func _act(index: int, intent: InputIntent, contacts: Array = []) -> void:
	if index == 0:
		_tick(intent, null, contacts)
	else:
		_tick(null, intent, contacts)


## Idle (recorded) ticks until both heroes are free to act, no post-get-up immunity is running, and both
## pools hold enough mana for any one step of the run.
func _settle() -> void:
	for _t in WAIT_LIMIT:
		var free := true
		for player: PlayerState in [_ms.p1, _ms.p2]:
			if player.hero.action_state != HeroState.ActionState.IDLE or player.hero.is_getting_up() \
					or player.hero.unblockable_immunity.is_running or player.is_casting() \
					or player.mana.get_current() < 6.0:
				free = false
		if free:
			return
		_tick()
	assert_true(false, "the run settled within %d ticks" % WAIT_LIMIT)


## Seat `index` presses card `id` in `mode`, from whichever hand slot holds it.
func _card(index: int, id: StringName, mode: Enums.ModeKind) -> void:
	var slot := _seat(index).hand.to_array().find(id)
	assert_true(slot >= 0, "the run: seat %d still holds '%s'" % [index + 1, id])
	_act(index, F.card_intent(maxi(slot, 0), mode))


## Seat `index` stages `id` and activates it on the next tick (the orb must already be banked).
func _pitch(index: int, id: StringName) -> void:
	_card(index, id, Enums.ModeKind.PITCH)
	assert_true(_ms.pitch.is_staged(index), "the run: seat %d staged '%s'" % [index + 1, id])
	_act(index, F.activate_intent())
	assert_false(_ms.pitch.is_staged(index), "the run: seat %d activated '%s'" % [index + 1, id])


## Seat `index` initiates an unblockable with card `id` and carries it to its end, pushing an INSIDE reach
## fact on every tick of the flight -- recorded, like every other fact.
func _unblockable(index: int, id: StringName) -> void:
	_card(index, id, Enums.ModeKind.UNBLOCKABLE)
	var player := _seat(index)
	assert_eq(player.hero.action_state, HeroState.ActionState.CHARGING,
		"the run: seat %d's unblockable press was accepted" % (index + 1))
	for _t in F.CHARGEUP_TICKS + F.LAUNCH_TICKS + 4:
		if player.hero.action_state != HeroState.ActionState.CHARGING:
			break
		_tick(null, null, [[index, 1 - index, player.hero.attack_index, MatchState.CONTACT_CHARGE_REACH_INSIDE]])


## Seat `index`'s hero lands one melee hit on the other hero; returns the hp that hero lost.
func _melee(index: int) -> float:
	var defender := _seat(1 - index)
	_act(index, F.press(&"attack"))
	_tick()
	_tick()
	var before := defender.hero.get_hp()
	_tick(null, null, [[index, 1 - index, _seat(index).hero.attack_index, MatchState.CONTACT_STRIKE]])
	return before - defender.hero.get_hp()


## One recorded idle tick; returns the mana seat 1's pool gained in it -- the regen per tick, measured.
func _regen_per_tick() -> float:
	var before := _ms.p1.mana.get_current()
	_tick()
	var gained := _ms.p1.mana.get_current() - before
	assert_true(gained > 0.0 and _ms.p1.mana.get_current() + 2.0 * gained < POOL_CAP,
		"the regen probe ran on a pool below its cap (gained %s at %s)" % [gained, _ms.p1.mana.get_current()])
	return gained


## The SECOND, independent MatchState -- driven only by the record. `corrupt` withholds or alters one thing.
func _replay(record: IntentRecorder, corrupt := "") -> MatchState:
	var ms := MatchState.new(MatchParams.new(record.replay_seed()))
	ms.apply_balance(record.replay_balance_config(0))
	ms.inject_feature_flags(record.replay_feature_flags())
	if corrupt == "swapped_decks":
		ms.inject_seat_decks(record.replay_seat_deck_contents(1), record.replay_seat_deck_contents(0))
		ms.inject_card_costs(record.replay_card_costs())
		ms.inject_card_effects(record.replay_card_effects())
		ms.inject_card_colors(record.replay_card_colors())
		ms.inject_pitch_costs(record.replay_pitch_costs())
		ms.inject_pitch_effects(record.replay_pitch_effects())
	else:
		assert_true(record.replay_inject_content(ms), "the recorded content order replays")
	for tick in range(1, record.tick_count() + 1):
		if corrupt != "contacts":
			record.replay_push_contacts(ms, tick)
		var intents: Array[InputIntent] = [record.replay_intent(tick, 0), record.replay_intent(tick, 1)]
		if corrupt == "intents":
			intents = [InputIntent.new(), InputIntent.new()]
		ms.advance(intents)
		ms.drain_signals()
	return ms
