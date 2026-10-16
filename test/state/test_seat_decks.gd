extends TestCase

## Story 7-5a, PART A (AC 7, 8, 10, 11, 13, 14, 15): PER-SEAT DECKS AND THE TEMPORARY REFUSAL, headless.
##
## THE DEAL. Each seat draws from its own injected composition; both piles are shuffled from the ONE
## seeded generator in the fixed order P1 then P2 (`7-5a/R32`). The reference deal below is rebuilt in the
## test from two plain `Deck`s and one generator, so "two seats on one list deal exactly as before this
## story" is checked against the shuffle itself rather than against the code under test.
##
## THE REFUSAL (7-5a) IS GONE (story 7-5b AC 1): Healer (normal), Elemental Fury and Wrath of God (pitch)
## resolve and stage like any card, and the block below pins that inversion; the other half of each card,
## and modes 2 and 3, still work. The fixture authors its own cards and effect ids in-test (`BC/R3`).

const SEED := 4242
const HAND_SIZE := 4
const START_MANA := 20.0
const PITCH_MANA := 3.0
const BASIC_MANA := 2.0

## Two different compositions of different SIZES, so a seat reading the other seat's list fails on count.
const LIST_A: Array[StringName] = [&"a_0", &"a_1", &"a_2", &"a_3", &"a_4", &"a_5", &"a_6", &"a_7"]
const LIST_B: Array[StringName] = [&"b_0", &"b_1", &"b_2", &"b_3", &"b_4", &"b_5", &"b_6", &"b_7", &"b_8", &"b_9"]

## The refusal fixture's cards: id -> [basic effect id, pitch effect id]. `plain` is an ordinary card.
const REFUSAL_CARDS: Dictionary = {
	&"t_healer": [&"healer", &"stoneskin"],
	&"t_blossom": [&"manablossom", &"elemental_fury"],
	&"t_pulation": [&"manapulation", &"wrath_of_god"],
	&"t_plain": [&"spell_plain", &"spell_plain_pitch"],
}


# ---------------------------------------------------------------- AC 7 / AC 8: the deal

## AC 7's machine check: the ONE-LIST form and the per-seat form given the same list twice are the same
## deal -- every pile, every hand, card for card -- and both are the reference shuffle (P1's pile first,
## then P2's, off one generator).
func test_two_seats_on_one_list_deal_exactly_as_the_one_list_form_does() -> void:
	var one_list := _dealt(func(ms: MatchState) -> void: ms.inject_deck(LIST_A))
	var per_seat := _dealt(func(ms: MatchState) -> void: ms.inject_seat_decks(LIST_A, LIST_A))
	var reference := _reference_deal(LIST_A, LIST_A)
	for seat in 2:
		var a: PlayerState = one_list.p1 if seat == 0 else one_list.p2
		var b: PlayerState = per_seat.p1 if seat == 0 else per_seat.p2
		assert_eq(b.deck.to_array(), a.deck.to_array(), "seat %d: the same pile, in the same order" % (seat + 1))
		assert_eq(b.hand.to_array(), a.hand.to_array(), "seat %d: the same hand, slot for slot" % (seat + 1))
		assert_eq(a.deck.to_array(), reference[seat]["deck"], "seat %d: the pile is the reference shuffle" % (seat + 1))
		assert_eq(a.hand.to_array(), reference[seat]["hand"], "seat %d: the hand is the reference deal" % (seat + 1))
	assert_eq(CanonicalHash.of(per_seat.to_snapshot()), CanonicalHash.of(one_list.to_snapshot()),
		"...and the two matches hash identically")
	assert_ne(one_list.p1.hand.to_array(), one_list.p2.hand.to_array(),
		"non-vacuity: the two seats really are dealt different orders off the one generator")


## AC 7: two seats on DIFFERENT lists receive different compositions, each a permutation of ITS OWN list,
## still off one generator in the fixed order -- so the reference deal built the same way reproduces both.
func test_two_seats_on_different_lists_each_deal_their_own_composition() -> void:
	var ms := _dealt(func(m: MatchState) -> void: m.inject_seat_decks(LIST_A, LIST_B))
	assert_eq(_sorted(_all_cards(ms.p1)), _sorted(LIST_A), "P1 holds exactly list A (deck + hand)")
	assert_eq(_sorted(_all_cards(ms.p2)), _sorted(LIST_B), "P2 holds exactly list B (deck + hand)")
	assert_eq(ms.p1.to_snapshot()["deck_size"], LIST_A.size() - HAND_SIZE, "P1's pile is A's size less a hand")
	assert_eq(ms.p2.to_snapshot()["deck_size"], LIST_B.size() - HAND_SIZE, "P2's pile is B's size less a hand")
	var reference := _reference_deal(LIST_A, LIST_B)
	assert_eq(ms.p1.deck.to_array(), reference[0]["deck"], "P1's pile is shuffled FIRST off the one generator")
	assert_eq(ms.p2.deck.to_array(), reference[1]["deck"], "P2's pile is shuffled SECOND off the SAME generator")
	# No second RNG: P1's deal does not depend on which list P2 plays.
	var same_list := _dealt(func(m: MatchState) -> void: m.inject_seat_decks(LIST_A, LIST_A))
	assert_eq(ms.p1.deck.to_array(), same_list.p1.deck.to_array(),
		"P1's shuffle is the same whatever P2's list is -- P1 draws first from the one generator")


## AC 7/AC 54's deal half: the debug reset re-lays EACH seat's own composition (the reset re-arms the deal).
func test_a_debug_reset_redeals_each_seat_from_its_own_list() -> void:
	var ms := _dealt(func(m: MatchState) -> void: m.inject_seat_decks(LIST_A, LIST_B))
	var reset := InputIntent.new()
	reset.debug_reset = true
	ms.advance([reset, InputIntent.new()])
	ms.drain_signals()
	assert_eq(_sorted(_all_cards(ms.p1)), _sorted(LIST_A), "after a reset P1 still holds exactly list A")
	assert_eq(_sorted(_all_cards(ms.p2)), _sorted(LIST_B), "after a reset P2 still holds exactly list B")


## AC 8/AC 11: the recorder's one-list capture and its per-seat capture, and a replay injecting from each.
## A one-list record replays as one list on both seats; a per-seat record puts each list on its own seat.
func test_the_recorder_carries_one_composition_per_seat_and_replays_each_onto_its_seat() -> void:
	var one := IntentRecorder.new()
	one.capture_inject_deck(LIST_A)
	assert_eq(one.replay_seat_deck_contents(0), LIST_A, "a one-list capture is seat 1's composition")
	assert_eq(one.replay_seat_deck_contents(1), LIST_A, "...and seat 2's, the same ids")
	assert_eq(one.replay_deck_contents(), LIST_A, "`replay_deck_contents()` still answers (seat 1's)")
	assert_eq(one.replay_deck_names(), ["", ""] as Array[String], "a one-list capture names no deck")
	var seated := IntentRecorder.new()
	seated.capture_inject_seat_decks(LIST_A, LIST_B, ["deck_a", "deck_b"] as Array[String])
	assert_eq(seated.replay_seat_deck_contents(0), LIST_A, "seat 1's list")
	assert_eq(seated.replay_seat_deck_contents(1), LIST_B, "seat 2's DIFFERENT list")
	assert_eq(seated.replay_deck_names(), ["deck_a", "deck_b"] as Array[String], "the two names, in seat order")
	assert_eq(seated.content_order(), [IntentRecorder.CHANNEL_DECK] as Array[StringName],
		"the per-seat capture is ONE entry on the existing deck channel")
	# The replay side: the same seed and the recorded compositions reproduce the live deal on each seat.
	var live := _dealt(func(m: MatchState) -> void: m.inject_seat_decks(LIST_A, LIST_B))
	var replayed := _dealt(func(m: MatchState) -> void:
		m.inject_seat_decks(seated.replay_seat_deck_contents(0), seated.replay_seat_deck_contents(1)))
	assert_eq(replayed.p1.hand.to_array(), live.p1.hand.to_array(), "the replay deals P1 the live hand")
	assert_eq(replayed.p2.hand.to_array(), live.p2.hand.to_array(), "...and P2 the live hand")
	assert_eq(CanonicalHash.of(replayed.to_snapshot()), CanonicalHash.of(live.to_snapshot()),
		"...and hashes identically")


## 3-3 AC 10, per seat: the PER-SEAT seam rejects an empty composition for EITHER seat. A source scan, the
## `test_deck_and_hand.gd::test_injection_seam_rejects_an_empty_injected_deck` shape -- an
## `Invariant.check` cannot be exercised from the harness (it is `push_error` + `assert`).
func test_the_per_seat_seam_rejects_an_empty_composition_for_either_seat() -> void:
	var in_seam := false
	var guarded := false
	var seam_found := false
	for raw in FileAccess.get_file_as_string("res://src/state/match_state.gd").split("\n"):
		var line := String(raw)
		if line.begins_with("func inject_seat_decks("):
			in_seam = true
			seam_found = true
			continue
		if in_seam and line.begins_with("func "):
			break
		if in_seam and line.contains("Invariant.check") and line.contains("p1_contents.is_empty()") \
				and line.contains("p2_contents.is_empty()"):
			guarded = true
	assert_true(seam_found, "match_state.gd declares inject_seat_decks (a rename un-guards this)")
	assert_true(guarded, "inject_seat_decks must Invariant.check BOTH seats' compositions are non-empty")


# ---------------------------------------------------------------- AC 13-15 (7-5a), INVERTED by 7-5b AC 1

## STORY 7-5b (AC 1): THE TEMPORARY REFUSAL IS GONE, AND THIS BLOCK NOW PINS ITS ABSENCE rather than asserting
## a dead rule. The three 7-5a refusal tests are inverted in place: the same fixture and the same presses,
## and every one of them now RESOLVES (Healer) or STAGES (Elemental Fury, Wrath of God) with the ordinary
## spend -- `not_available_yet` is heard by nobody.

## AC 1: HEALER (normal) is no longer refused -- the press resolves, the mana is paid, the card is discarded
## and its replacement is owed, exactly as any Mode 1 cast.
func test_healer_normal_now_resolves_and_is_never_refused() -> void:
	var ms := _refusal_match()
	var slot := _slot_of(ms, &"t_healer")
	var rejections := _rejections(ms.p1)
	var resolved := _resolved(ms)
	_advance(ms, _intent(slot, Enums.ModeKind.BASIC))
	assert_true(rejections.is_empty(), "the press is not refused (no `not_available_yet`): %s" % [rejections])
	assert_eq(resolved, [[0, &"t_healer", Enums.ModeKind.BASIC]], "the Healer press resolves")
	assert_eq(ms.p1.mana.get_current(), START_MANA - BASIC_MANA, "its mana is paid")
	assert_eq(ms.p1.discard.size(), 1, "the card is discarded")
	assert_eq(ms.p1.pending_draw_owed, [slot] as Array[int], "its replacement is owed")


## AC 1: ELEMENTAL FURY and WRATH OF GOD are no longer refused AT STAGING -- the card enters the zone and
## its staging mana is paid.
func test_elemental_fury_and_wrath_of_god_now_stage_and_are_never_refused() -> void:
	for card_id: StringName in [&"t_blossom", &"t_pulation"]:
		var ms := _refusal_match()
		var slot := _slot_of(ms, card_id)
		var rejections := _rejections(ms.p1)
		_advance(ms, _intent(slot, Enums.ModeKind.PITCH))
		assert_true(rejections.is_empty(), "%s: staging is not refused: %s" % [card_id, rejections])
		assert_eq(ms.pitch.staged_card_id(0), card_id, "%s: the card is in the pitch zone" % card_id)
		assert_eq(ms.p1.mana.get_current(), START_MANA - PITCH_MANA, "%s: its staging mana is paid" % card_id)


## AC 1: with the gate gone, a BROKE caster hears the ordinary price refusal for the same two presses --
## the refusal ladder is the one every other card meets.
func test_a_broke_caster_now_hears_the_ordinary_price_refusal() -> void:
	var ms := _refusal_match()
	ms.p1.mana.add(-START_MANA)
	ms.drain_signals()
	var rejections := _rejections(ms.p1)
	_advance(ms, _intent(_slot_of(ms, &"t_healer"), Enums.ModeKind.BASIC))
	_advance(ms, _intent(_slot_of(ms, &"t_blossom"), Enums.ModeKind.PITCH))
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_INSUFFICIENT_MANA],
			[&"card_cast", CastEvaluator.REASON_INSUFFICIENT_MANA]],
		"both presses answer `insufficient_mana` to a caster with no mana at all")


## AC 14: THE OTHER HALF OF EACH CARD WORKS. Healer's card still STAGES (Stoneskin), and Manablossom's and
## Manapulation's cards still PLAY (their normal halves): mana spent, card gone, resolution announced.
func test_the_other_half_of_each_refused_card_works_normally() -> void:
	var staged := _refusal_match()
	var staged_rejections := _rejections(staged.p1)
	_advance(staged, _intent(_slot_of(staged, &"t_healer"), Enums.ModeKind.PITCH))
	assert_true(staged_rejections.is_empty(), "staging Healer's card (Stoneskin) is not refused")
	assert_eq(staged.pitch.staged_card_id(0), &"t_healer", "...it is in the zone")
	assert_eq(staged.p1.mana.get_current(), START_MANA - PITCH_MANA, "...and its staging mana is paid")
	for card_id: StringName in [&"t_blossom", &"t_pulation"]:
		var ms := _refusal_match()
		var rejections := _rejections(ms.p1)
		var resolved := _resolved(ms)
		_advance(ms, _intent(_slot_of(ms, card_id), Enums.ModeKind.BASIC))
		assert_true(rejections.is_empty(), "%s: the normal half is not refused" % card_id)
		assert_eq(resolved, [[0, card_id, Enums.ModeKind.BASIC]], "%s: the play resolves" % card_id)
		assert_eq(ms.p1.discard.size(), 1, "%s: the card is discarded" % card_id)


## AC 13's last sentence: MODES 2 AND 3 of the three cards still work -- a refused half does not make the
## card unusable as an unblockable.
func test_modes_two_and_three_of_a_refused_card_still_work() -> void:
	for card_id: StringName in [&"t_healer", &"t_blossom", &"t_pulation"]:
		var ms := _refusal_match()
		var rejections := _rejections(ms.p1)
		_advance(ms, _intent(_slot_of(ms, card_id), Enums.ModeKind.UNBLOCKABLE))
		assert_true(rejections.is_empty(), "%s: an unblockable initiated with the card is not refused" % card_id)
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "%s: the hero is charging" % card_id)
		# Mode 3, from the OTHER seat, answering that chargeup with the same card.
		var answers := _rejections(ms.p2)
		ms.advance([InputIntent.new(), _intent(_slot_of_player(ms.p2, card_id), Enums.ModeKind.DEFENSE)])
		ms.drain_signals()
		assert_true(answers.is_empty(), "%s: a colour defence cast with the card is not refused" % card_id)
		assert_true(ms.p2.defense_window.is_running, "%s: the defence window opened" % card_id)


## AC 1 (inverting 7-5a AC 15): A HEALER PRESS NOW WRITES THE LAST-RESOLVED RECORD like any resolution --
## it is the card a Counterspell would answer.
func test_a_healer_press_now_becomes_the_last_resolved_card() -> void:
	var ms := _refusal_match()
	_advance(ms, _intent(_slot_of(ms, &"t_plain"), Enums.ModeKind.BASIC))
	assert_eq(String(ms.p1.to_snapshot()["last_resolved_card"][0]), "t_plain",
		"sanity: the plain card resolved first and is the record")
	_advance(ms, _intent(_slot_of(ms, &"t_healer"), Enums.ModeKind.BASIC))
	assert_eq(String(ms.p1.to_snapshot()["last_resolved_card"][0]), "t_healer",
		"the Healer press overwrites the record -- it resolved")


## AC 1: THE REFUSAL TABLE IS EMPTY -- the mechanism stays (`is_unavailable` and both seats are untouched),
## and no effect id answers it any more, the three 7-5b halves included.
func test_the_refusal_table_is_empty_and_no_id_is_unavailable() -> void:
	assert_eq(CardEffectResolver.UNAVAILABLE_EFFECT_OWNERS.size(), 0, "the table is EMPTY (AC 1)")
	for id: StringName in [&"healer", &"elemental_fury", &"wrath_of_god", &"stoneskin", &"spell_plain"]:
		assert_false(CardEffectResolver.is_unavailable(_effect(id)), "'%s' is not a refused half" % id)
	assert_false(CardEffectResolver.is_unavailable(null), "a missing effect entry is not a refused half")


# ---------------------------------------------------------------- fixtures

func _dealt(inject: Callable) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	var config := BalanceConfig.new()
	config.max_hp = 100.0
	config.hand_size = HAND_SIZE
	ms.apply_balance(config)
	inject.call(ms)
	ms.advance([InputIntent.new(), InputIntent.new()])
	ms.drain_signals()
	return ms


## The deal rebuilt from first principles: one generator, P1's pile shuffled first, then P2's; each hand
## filled from the TOP of its pile, slot 0 first.
func _reference_deal(p1_list: Array[StringName], p2_list: Array[StringName]) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var out: Array = []
	for list: Array[StringName] in [p1_list, p2_list]:
		var deck := Deck.new()
		deck.set_contents(list)
		deck.shuffle_with_rng(rng)
		var hand: Array[StringName] = []
		for _slot in HAND_SIZE:
			hand.append(deck.draw_top())
		out.append({"deck": deck.to_array(), "hand": hand})
	return out


func _all_cards(player: PlayerState) -> Array:
	var out: Array = []
	out.append_array(player.deck.to_array())
	out.append_array(player.hand.occupied_ids())
	return out


func _sorted(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in ids:
		out.append(String(id))
	out.sort()
	return out


func _effect(effect_id: StringName) -> CardEffect:
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	return effect


## Both seats hold one copy of each refusal-fixture card, so every card is in the dealt hand (4 wide).
func _refusal_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	var config := BalanceConfig.new()
	config.max_hp = 100.0
	config.max_mana = START_MANA
	config.max_stamina = 40.0
	config.hand_size = HAND_SIZE
	config.deck_size = HAND_SIZE
	config.unblockable_stamina_cost = 2.0
	config.defense_stamina_cost = 2.0
	config.unblockable_chargeup_seconds = 30.0 / TimingWindow.TICK_HZ
	config.counter_busy_seconds_red = 20.0 / TimingWindow.TICK_HZ
	config.pitch_stage_timer_seconds = 600.0 / TimingWindow.TICK_HZ
	config.pitch_countdown_push_interval_seconds = 1000.0 / TimingWindow.TICK_HZ
	config.draw_replacement_delay_seconds = 600.0 / TimingWindow.TICK_HZ
	ms.apply_balance(config)
	var flags := FeatureFlags.new()
	flags.pitch_zone = true
	flags.unblockable = true
	flags.spells = true
	flags.orbs = true
	ms.inject_feature_flags(flags)
	var ids: Array[StringName] = []
	var costs: Dictionary[StringName, CardCastCondition] = {}
	var effects: Dictionary[StringName, CardEffect] = {}
	var colors: Dictionary[StringName, Enums.CardColor] = {}
	var pitch_costs: Dictionary[StringName, CardCastCondition] = {}
	var pitch_effects: Dictionary[StringName, CardEffect] = {}
	for id: StringName in REFUSAL_CARDS:
		ids.append(id)
		var cost := CardCastCondition.new()
		cost.mana_cost = BASIC_MANA
		costs[id] = cost
		var pitch_cost := CardCastCondition.new()
		pitch_cost.mana_cost = PITCH_MANA
		pitch_cost.orb_costs[Enums.CardColor.RED] = 1
		pitch_costs[id] = pitch_cost
		effects[id] = _effect((REFUSAL_CARDS[id] as Array)[0])
		pitch_effects[id] = _effect((REFUSAL_CARDS[id] as Array)[1])
		colors[id] = Enums.CardColor.RED
	ms.inject_deck(ids)
	ms.inject_card_costs(costs)
	ms.inject_card_effects(effects)
	ms.inject_card_colors(colors)
	ms.inject_pitch_costs(pitch_costs)
	ms.inject_pitch_effects(pitch_effects)
	ms.advance([InputIntent.new(), InputIntent.new()])
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	ms.drain_signals()
	return ms


func _slot_of(ms: MatchState, card_id: StringName) -> int:
	return _slot_of_player(ms.p1, card_id)


func _slot_of_player(player: PlayerState, card_id: StringName) -> int:
	var slot := player.hand.to_array().find(card_id)
	assert_true(slot >= 0, "fixture: '%s' is in the dealt hand %s" % [card_id, player.hand.to_array()])
	return maxi(slot, 0)


func _intent(slot: int, mode: Enums.ModeKind) -> InputIntent:
	var intent := InputIntent.new()
	intent.card_slot = slot
	intent.card_mode = mode
	intent.card_commit = true
	return intent


func _advance(ms: MatchState, p1_intent: InputIntent) -> void:
	ms.advance([p1_intent, InputIntent.new()])
	ms.drain_signals()


func _rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out


func _resolved(ms: MatchState) -> Array:
	var out: Array = []
	ms.card_cast_resolved.connect(
		func(slot: int, card_id: StringName, mode: int) -> void: out.append([slot, card_id, mode]))
	return out


func _without_tick(snapshot: Dictionary) -> Dictionary:
	var out := snapshot.duplicate(true)
	out.erase("tick")
	return out
