extends TestCase

## Story 3-2 (AC 3 / AC 6 / AC 7): the authored starter card set and the schema shape.
##
## The existing recursive sweep (test_data_resources.gd::test_every_data_tres_loads) already
## proves every card .tres LOADS, with no edit — and load-only is not enough: it would pass a
## set of nine identical cards, a set with duplicate ids, or a copies cap that makes a 20-card
## deck unbuildable. This file asserts the CONTENT. Headless (Resource loading only, no scene,
## no autoload, no frame) — the autoload's own boot is covered by
## test/integration/test_card_database.gd, which the state harness structurally cannot do.
##
## STORY 6-5a (AC 13-16) REPOINTS THE CONTENT ASSERTIONS AT DECK 1, and every rewrite is named as one
## where it happens. The library is now SIXTEEN cards: Deck 1's seven plus the nine 3-2 fixtures, which
## stay authored and loadable but are DORMANT -- not in the deck list (`6-5a/R1`). `_load_cards()` still
## sweeps the whole directory; the Deck 1 assertions filter it through the authored `DeckList`, and a
## SEPARATE, named test keeps proving the nine fixtures exist, load, and are excluded.

const CARDS_DIR := "res://data/cards/"
const EFFECTS_DIR := "res://data/effects/"
const DECK_1_PATH := "res://data/decks/deck_1.tres"
const BALANCE_PATH := "res://data/balance/balance_config.tres"

## REWRITTEN BY STORY 6-5a (AC 13): was `EXPECTED_COUNT := 9` (the sealed nine-card set). The content
## assertions below describe DECK 1's seven; the whole library is sixteen.
const EXPECTED_COUNT := 7
## STORY 6-5e (AC 6a, `6-5e/R25`/G6): 16 -> 17. `boulder.tres` arrives -- a COLOURLESS card that is in no
## deck, is never drawn, dealt or discarded, and can only ever enter a hand as the consequence of a landed
## Rocksling stone (ruling 7). It is authored data under `data/cards/` like any other card, which is why it
## is counted here at all rather than living somewhere special.
const LIBRARY_COUNT := 17

## Story 6-5e (AC 6a, `6-5e/R25`/G6): THE BOULDER, NAMED AS AN EXEMPTION rather than given a fake priced
## pitch condition. Ruling 7 gives it NO Mode ④ at all -- no pitch effect, no pitch cost, no orb price --
## so the two library-wide censuses below (`test_basic_mode_only_pitch_and_orbs_left_unauthored`'s
## every-card-authors-a-priced-pitch loop, and the dormant-fixture prefix loop) each skip exactly this id
## and nothing else.
##
## A NAMED EXEMPTION, NOT A WIDENED PREDICATE, and the difference is what `6-5e/R25` ruled: authoring
## `pitch_condition` with an empty `orb_costs` to satisfy the census would have made the card lie about
## having a Mode ④, and loosening the census to "or no pitch cost at all" would have stopped catching the
## regression it exists for (a Deck 1 card's orb price silently emptying). One id, listed, greppable.
const NO_PITCH_MODE_IDS: Array[StringName] = [&"boulder"]

## Story 6-5a (R1): the nine 3-2 fixture cards -- still authored, never in Deck 1.
const FIXTURE_IDS: Array[StringName] = [
	&"bramble_snare", &"ember_lash", &"frost_dart", &"hellforge_totem", &"imp_summoner",
	&"storm_kite", &"thornback_guardian", &"tidal_wardstone", &"verdant_wardstone",
]

## Story 6-5a (AC 14): DECK 1, the full 20-card multiset, in list order. Six uniques x 3 plus one x 2
## (`deck-1-spec.md:12`); the 2-copy card is Honed Bolt by operator ruling (6-5a dev pass, N12).
const DECK_1_IDS: Array[StringName] = [
	&"ruin_vanguard", &"grave_ward", &"drain", &"rocksling", &"bloodhound_step", &"honed_bolt",
	&"frostbite",
]
const DECK_1_COPIES: Array[int] = [3, 3, 3, 3, 3, 2, 3]

## Story 6-5a (AC 13/AC 15): each Deck 1 card's colour, Mode ① price and Mode ④ price, per
## `deck-1-spec.md` §1-7 and the operator's amendments. id -> [colour, basic mana, pitch mana, orb price].
const DECK_1_PRICES: Dictionary = {
	&"ruin_vanguard": [Enums.CardColor.GREEN, 3.0, 3.0, {Enums.CardColor.GREEN: 1}],
	&"grave_ward": [Enums.CardColor.GREEN, 2.0, 6.0, {Enums.CardColor.RED: 2}],
	&"drain": [Enums.CardColor.GREEN, 2.0, 5.0, {Enums.CardColor.GREEN: 1, Enums.CardColor.RED: 1}],
	&"rocksling": [Enums.CardColor.RED, 4.0, 3.0, {Enums.CardColor.RED: 1}],
	# Story 6-5d (AC 3, `6-5d/R9`/`R19`): the Mode ④ mana moves 4.0 -> 3.0. The 4 was BLOODLUST's fixed
	# price and it left Deck 1 with Bloodlust; 3 is FIREBALL's own MINIMUM -- the floor below which the
	# staging is refused, not a price, since a Fireball spends `min(pool, mana_cap)`. The orb price,
	# colour and Mode ① price are unchanged.
	&"bloodhound_step": [Enums.CardColor.RED, 2.0, 3.0, {Enums.CardColor.RED: 1}],
	&"honed_bolt": [Enums.CardColor.BLUE, 4.0, 4.0, {Enums.CardColor.BLUE: 1}],
	&"frostbite": [Enums.CardColor.BLUE, 4.0, 5.0, {Enums.CardColor.BLUE: 1}],
}

## Story 6-5a (AC 15): each Deck 1 card's two effect ids, [normal, pitch].
const DECK_1_EFFECTS: Dictionary = {
	&"ruin_vanguard": [&"summon_ruin_vanguard", &"culling"],
	&"grave_ward": [&"grave_ward", &"raise_dead"],
	&"drain": [&"drain", &"vampiric_aura"],
	&"rocksling": [&"rocksling", &"boom"],
	# Story 6-5d (AC 1): THE PAIRING SWAP. Bloodhound Step's PITCH effect is FIREBALL -- the Deck 1
	# pairing `deck-1-spec.md`'s 2026-09-22 amendment already specified. Bloodlust survives as an effect
	# FILE (destined for deck 2) and its field-for-field pin below is untouched (AC 2); what changed is
	# only that no Deck 1 card references it any more.
	&"bloodhound_step": [&"bloodhound_step", &"fireball"],
	&"honed_bolt": [&"honed_bolt", &"counterspell"],
	&"frostbite": [&"frostbite", &"corpse_bomb"],
}

## GDD §A, "Deck & hand.": max copies per card 2-3, configurable per card in data. Per-CARD data, not a
## BalanceConfig field (the ruling 3-1's gate assigned to 3-2).
const MIN_COPIES := 2
const MAX_COPIES := 3

## The complete authored export surface of CardData. Pinned EXACTLY: a field added here
## without a story that asks for it fails this test, which is what makes AC 7's negative guard
## below hold for spellings nobody thought to ban.
## Story 6-5a (AC 13): UNCHANGED, and named so a rewrite pass does not touch it -- 6-5a adds CardEFFECT
## fields, not CardData ones.
const CARD_DATA_FIELDS: Array[String] = [
	"id", "color", "basic_effect", "pitch_effect", "cast_condition", "max_copies",
	# Story 6-2 (AC 1, `E6-P/R9`): the Mode ④ COST seat, the SEVENTH authored field -- the "story that
	# asks for it" this pin's own header demands.
	"pitch_condition",
]


## REWRITTEN BY STORY 6-5a (AC 13/AC 14): was `test_nine_cards_load_as_card_data` (exactly nine cards in
## the library). Now: the library holds sixteen CardData, and DECK 1's seven are among them.
func test_deck_1_seven_cards_load_as_card_data() -> void:
	var cards := _load_cards()
	assert_eq(cards.size(), LIBRARY_COUNT,
		"data/cards/ holds seventeen authored cards: Deck 1's seven, the nine dormant fixtures, and "
		+ "6-5e's Boulder -- which belongs to no deck at all")
	for card in cards:
		assert_true(card is CardData, "every card .tres casts to CardData")
	var deck := _deck_cards()
	assert_eq(deck.size(), EXPECTED_COUNT, "all seven Deck 1 cards are authored in data/cards/")


## Story 6-5a (R1, AC 12/AC 13): THE NINE FIXTURES, MACHINE-CHECKED DORMANT. They still exist, still load
## as CardData, and are NOT in Deck 1's list -- R1 made executable rather than only documented.
func test_the_nine_fixture_cards_stay_authored_loadable_and_out_of_deck_1() -> void:
	var by_id := {}
	for card in _load_cards():
		by_id[card.id] = card
	var list := _deck_list()
	for id in FIXTURE_IDS:
		assert_true(by_id.has(id), "fixture card '%s' is still authored in data/cards/" % id)
		assert_true(by_id.get(id) is CardData, "...and still loads as CardData")
		assert_false(list.card_ids.has(id), "...and is NOT in Deck 1's list (R1: dormant)")


func test_card_data_exports_exactly_the_authored_field_set() -> void:
	var declared := _script_property_names(CardData.new())
	declared.sort()
	var expected := CARD_DATA_FIELDS.duplicate()
	expected.sort()
	assert_eq(declared, expected, "CardData exports exactly the seven authored fields")


## AC 7, the negative guard, stated as its own test so the failure message names the RULE.
## Unblockable damage is PER-COLOUR — "Full (per-COLOR value, not per-card)", GDD §C — a fixed
## value in balance that does not exist yet, gated behind FeatureFlags.unblockable for a later
## epic. A per-card damage number would be a second source of truth for a per-colour value.
## Matched on SUBSTRING so a near-miss spelling (unblockable_damage, damage_percent,
## per_color_damage) is caught too, not just the two exact names.
func test_card_data_carries_no_damage_or_unblockable_field() -> void:
	var banned := ["damage", "unblockable"]
	var offenders: Array[String] = []
	for name in _script_property_names(CardData.new()):
		for token in banned:
			if name.to_lower().contains(token):
				offenders.append(name)
				break  # one field, one offence — `unblockable_damage` matches both tokens
	assert_eq(offenders.size(), 0,
		"CardData must carry no damage/unblockable field (it is per-COLOUR balance, AC 7): %s"
				% ", ".join(offenders))


## LOAD-BEARING FOR STORY 4-0 (AC 7, `4-0/R3`) — re-pointed, not merely inherited. The empty
## StringName is the HAND'S EMPTY-SLOT MARKER (`Hand.EMPTY`), so the `card.id != &""` assertion
## below is what makes the marker/card-id collision IMPOSSIBLE BY CONSTRUCTION rather than
## unlikely: an authored card with an empty id would be indistinguishable from a hole, and would
## be silently unremovable, uncastable and invisible in the HUD at once.
##
## The guard already shipped before 4-0; this comment is the record that it now has a SECOND
## owner, so a future pass cannot weaken or delete it without meeting that AC. Do not relax the
## id assertion here without reading `Hand.EMPTY` first.
##
## (The gate's ratification named `test_balance_authoring.gd`; by content that file loads only the
## BalanceConfig and cannot reach data/cards/, so the audit stays where the authored cards
## actually are. Recorded as a correction, not a scope change.)
##
## REWRITTEN BY STORY 6-5a (AC 13): the distinct-id count is the whole library's SIXTEEN (was nine) --
## uniqueness is a library property, and Deck 1's ids must not collide with a dormant fixture's.
func test_every_id_is_non_empty_and_unique() -> void:
	var seen := {}
	var dupes: Array[String] = []
	for card in _load_cards():
		assert_true(card.id != Hand.EMPTY,
			"every card authors a non-empty id — and `&\"\"` is the hand's HOLE MARKER, so an "
			+ "empty id would be a card indistinguishable from an empty slot (4-0 AC 7)")
		if seen.has(card.id):
			dupes.append(String(card.id))
		seen[card.id] = true
	assert_eq(dupes.size(), 0, "card ids are unique across the set: %s" % ", ".join(dupes))
	assert_eq(seen.size(), LIBRARY_COUNT, "seventeen distinct ids")


## REWRITTEN BY STORY 6-5a (AC 13): was three cards per colour across the nine fixtures. Deck 1 is
## GREEN 3 / RED 2 / BLUE 2 (`deck-1-spec.md` §1-7), and each card's own colour is pinned per id.
##
## RENAMED BY THE 6-5a REVIEW FIX PASS (N12). Old name, recorded verbatim so the pin stays greppable:
## `test_colours_are_card_color_enum_values_three_per_colour`. The rewrite above had already replaced
## "three per colour" with GREEN 3 / RED 2 / BLUE 2, so the name asserted the opposite of the body --
## the rename-and-record convention this diff uses at `test_no_pitch_effect_consumer_ships`.
func test_deck_1_colours_are_card_color_values_green_3_red_2_blue_2() -> void:
	var counts := {Enums.CardColor.RED: 0, Enums.CardColor.BLUE: 0, Enums.CardColor.GREEN: 0}
	for card in _deck_cards():
		assert_true(counts.has(card.color),
			"card '%s' colour is an Enums.CardColor value (never a second colour enum)" % card.id)
		counts[card.color] = int(counts[card.color]) + 1
		assert_eq(int(card.color), int(DECK_1_PRICES[card.id][0]),
			"card '%s' is authored in its Deck 1 colour" % card.id)
	assert_eq(int(counts[Enums.CardColor.GREEN]), 3, "three GREEN Deck 1 cards")
	assert_eq(int(counts[Enums.CardColor.RED]), 2, "two RED Deck 1 cards")
	assert_eq(int(counts[Enums.CardColor.BLUE]), 2, "two BLUE Deck 1 cards")


## REWRITTEN BY STORY 6-5a (AC 13/AC 15) -- a DELIBERATE DEPARTURE from 3-2's "sealed nine-card decision"
## (one card per colour at each of 2 / 3 / 5 mana). Deck 1 prices 2-4 mana per the spec's authored
## brackets, so the one-per-tier SHAPE no longer holds; this now pins each Deck 1 card's actual Mode ①
## and Mode ④ price, mana and orbs. The literal-not-a-field-name check is kept as it was.
##
## RENAMED BY THE 6-5a REVIEW FIX PASS (N12). Old name, recorded verbatim:
## `test_each_colour_prices_one_card_at_each_tier`. It no longer checks tiers at all -- the 2/3/5 shape
## is retired in the paragraph above -- so the name named a rule the body had stopped asserting.
##
## NON-VACUOUS ON A SHRUNK LIST (N11): it iterates the `DECK_1_IDS` LITERAL rather than `_deck_cards()`,
## which is derived FROM the deck list -- an emptied or shortened list used to pass this test green,
## because every per-card assertion simply had nothing to run against. `_card_for` fails loudly on an id
## the library no longer holds.
func test_each_deck_1_card_is_priced_at_its_authored_mode_1_and_mode_4_prices() -> void:
	for id in DECK_1_IDS:
		var card := _card_for(id)
		if card == null:
			continue
		assert_not_null(card.cast_condition, "card '%s' authors a cast condition" % card.id)
		assert_not_null(card.pitch_condition, "card '%s' authors a pitch condition" % card.id)
		if card.cast_condition == null or card.pitch_condition == null:
			continue
		# The literal-not-a-field-name ruling, made executable: a price is a NUMBER on the
		# condition, not the name of a BalanceConfig field the way
		# ResourceGenerationRule.amount_field is. A "fix" to a field name fails here.
		assert_eq(typeof(card.cast_condition.mana_cost), TYPE_FLOAT,
			"card '%s' mana_cost is a literal float" % card.id)
		var expected: Array = DECK_1_PRICES[card.id]
		assert_eq(card.cast_condition.mana_cost, float(expected[1]),
			"card '%s' Mode ① costs its Deck 1 mana" % card.id)
		assert_eq(card.pitch_condition.mana_cost, float(expected[2]),
			"card '%s' Mode ④ costs its Deck 1 mana" % card.id)
		assert_eq(card.pitch_condition.orb_costs, expected[3],
			"card '%s' Mode ④ costs its Deck 1 orbs" % card.id)


## Story 7-4 (AC 2, ruling 7): THE DECK 1 PITCH SPEEDS, pinned by card. Ruling 7 names the pitch EFFECTS; the
## speed is authored on the card holding each (C2): Culling, Vampiric Aura and Counterspell are instant;
## Raise Dead, Boom, Fireball and Corpse Bomb are sorcery. Iterates the literal, so a shrunk list fails.
const DECK_1_PITCH_SPEEDS := {
	&"ruin_vanguard": Enums.PitchSpeed.INSTANT,  # Culling
	&"drain": Enums.PitchSpeed.INSTANT,  # Vampiric Aura
	&"honed_bolt": Enums.PitchSpeed.INSTANT,  # Counterspell
	&"grave_ward": Enums.PitchSpeed.SORCERY,  # Raise Dead
	&"rocksling": Enums.PitchSpeed.SORCERY,  # Boom
	&"bloodhound_step": Enums.PitchSpeed.SORCERY,  # Fireball
	&"frostbite": Enums.PitchSpeed.SORCERY,  # Corpse Bomb
}


func test_each_deck_1_card_authors_its_ruled_pitch_speed() -> void:
	assert_eq(DECK_1_PITCH_SPEEDS.size(), DECK_1_IDS.size(), "the speed table covers every Deck 1 card")
	for id: StringName in DECK_1_IDS:
		var card := _card_for(id)
		if card == null or card.pitch_condition == null:
			assert_true(false, "Deck 1 card '%s' loads with a pitch condition" % id)
			continue
		assert_true(DECK_1_PITCH_SPEEDS.has(id), "card '%s' has a ruled speed" % id)
		assert_eq(card.pitch_condition.pitch_speed, DECK_1_PITCH_SPEEDS.get(id, -1),
			"card '%s' pitch speed is its ruled speed (ruling 7)" % id)


## Story 7-4 (AC 1/AC 2): EVERY CARD OUTSIDE DECK 1 READS INSTANT -- the fixtures and totems author no speed, and
## an unauthored speed is the enum's zero value. Also pins that zero value itself: a fresh condition is instant.
func test_every_card_outside_deck_1_reads_instant_and_unauthored_is_instant() -> void:
	assert_eq(CardCastCondition.new().pitch_speed, Enums.PitchSpeed.INSTANT,
		"a condition that authors no speed reads INSTANT")
	var outside := 0
	for card in _load_cards():
		if DECK_1_IDS.has(card.id):
			continue
		outside += 1
		if card.pitch_condition != null:
			assert_eq(card.pitch_condition.pitch_speed, Enums.PitchSpeed.INSTANT,
				"card '%s' (outside Deck 1) reads instant" % card.id)
		if card.cast_condition != null:
			assert_eq(card.cast_condition.pitch_speed, Enums.PitchSpeed.INSTANT,
				"card '%s' authors nothing on its Mode ① condition" % card.id)
	assert_true(outside > 0, "the library holds cards outside Deck 1 (non-vacuity)")


## REWRITTEN BY STORY 6-5a (AC 13): was a local `DECK_SIZE := 20` against the nine cards' summed
## `max_copies`. It now reads the LIVE authored `BalanceConfig.deck_size`, so it cannot silently drift
## from balance again, and the deck it proves constructible is Deck 1's list.
func test_copies_cap_is_in_bounds_and_a_twenty_card_deck_is_constructible() -> void:
	var deck_size := _authored_deck_size()
	var total := 0
	for card in _load_cards():
		assert_true(card.max_copies >= MIN_COPIES and card.max_copies <= MAX_COPIES,
			"card '%s' max_copies %d is in the GDD's 2-3 band" % [card.id, card.max_copies])
	for card in _deck_cards():
		total += card.max_copies
	assert_true(total >= deck_size,
		"Deck 1's cards allow a %d-card deck (copies available: %d)" % [deck_size, total])


## Story 6-5a (AC 13, `6-5a/R9`): THE DECK SIZE IS THE LIST'S COPY SUM, and the authored
## `BalanceConfig.deck_size` must agree with it -- two sources of one number, pinned equal.
func test_the_authored_deck_size_equals_the_deck_list_copy_sum() -> void:
	var list := _deck_list()
	var sum := 0
	for copies in list.copies:
		sum += copies
	assert_eq(sum, 20, "Deck 1 is twenty cards (provisional data)")
	assert_eq(_authored_deck_size(), sum,
		"BalanceConfig.deck_size agrees with Deck 1's copy sum -- one number, never two that disagree")


## Story 6-5a (AC 14, OQ4 / `6-5a/R10`): THE DECK LIST'S COMPOSITION -- exactly Deck 1's seven ids AND
## their copy counts (the full multiset, not just the set of ids), each entry within its card's
## `max_copies`, and the composition it expands to (list order, `copies` each -- the runner's
## `_derive_deck_contents`) holding no fixture id.
func test_the_deck_list_is_exactly_deck_1() -> void:
	var list := _deck_list()
	assert_eq(list.card_ids, DECK_1_IDS, "Deck 1 lists exactly its seven ids, in order")
	assert_eq(list.copies, DECK_1_COPIES, "...each with its copy count (six x3, Honed Bolt x2)")
	assert_eq(list.card_ids.size(), list.copies.size(), "the two index-aligned arrays agree in length")
	var by_id := {}
	for card in _load_cards():
		by_id[card.id] = card
	var expanded: Array[StringName] = []
	for index in list.card_ids.size():
		var id: StringName = list.card_ids[index]
		var card: CardData = by_id.get(id)
		assert_not_null(card, "listed card '%s' exists in the library" % id)
		if card != null:
			assert_true(list.copies[index] <= card.max_copies,
				"'%s' lists %d copies, within its max_copies %d" % [id, list.copies[index], card.max_copies])
		for _copy in list.copies[index]:
			expanded.append(id)
	assert_eq(expanded.size(), 20, "the expanded composition is twenty cards")
	for id in FIXTURE_IDS:
		assert_false(expanded.has(id), "the built deck holds no fixture id ('%s')" % id)


## STORY 4-1 (AC 3, `4-1/R4`): THE MACHINE HALF OF THE GOLDEN-DISCIPLINE RULING. `effect_id` is
## now a determinism-relevant class of change carrying review burden, exactly as a card's
## `mana_cost` already does -- but the gate measured the golden deck as SYNTHETIC with in-test
## costs, so AC 3 claims no measurable golden move from a .tres edit and standing `BC/R3`
## isolation holds. What IS machine-checkable is the AUTHORING: every authored `effect_id` must
## carry a prefix the resolver recognises.
##
## THE STANDING BOUND THIS SETS: a card authored with an id the resolver does not recognise fails
## HERE, at authoring time, instead of failing silently at play time as a card that costs mana,
## discards, and does nothing.
##
## REWRITTEN BY STORY 6-5a (AC 13/AC 4/AC 15): was "every authored effect_id starts `summon_`/`spell_`,
## six summons, three spells" over the nine fixtures. Deck 1 introduces the WHOLE-ID vocabulary: its
## fourteen effects are ONE summon (Ruin Vanguard, the unchanged `summon_*` path), FOUR buffs matched by
## whole id, and NINE whole-id no-ops naming their owning story -- and none takes the `spell_` prefix.
## The fixtures keep the original prefix guard, so a dormant card can never become an unknown id either.
##
## THE VOCABULARY IS READ OFF CardEffectResolver, NEVER RE-TYPED HERE -- the derived-not-transcribed
## discipline this test has always carried.
func test_every_authored_effect_id_carries_a_prefix_the_resolver_recognises() -> void:
	var summons := 0
	var buffs := 0
	## Story 6-5b: the FOUR own-minion / corpse effects, counted in their own bucket -- they were four
	## of 6-5a's nine deferred no-ops and their rows LEFT `DEFERRED_EFFECT_OWNERS` when this story gave
	## them real outcomes, so counting them as deferred would now be counting them twice wrong.
	var own_minion := 0
	## Story 6-5c: the CAST bucket, its own for `own_minion`'s stated reason -- `honed_bolt` was one of
	## 6-5a's nine deferred no-ops and its row LEFT `DEFERRED_EFFECT_OWNERS` when this story gave it a
	## real outcome, so counting it as deferred would be counting it twice wrong.
	var cast := 0
	## Story 6-5e: the OPPOSING-HAND bucket, its own for `cast`'s stated reason -- `boom` was one of 6-5a's
	## nine deferred no-ops and its row LEFT `DEFERRED_EFFECT_OWNERS` when this story gave it a real
	## outcome, so counting it as deferred would be counting it twice wrong.
	var opposing_hand := 0
	## Story 6-5f: the RETROACTIVE bucket, its own for `opposing_hand`'s stated reason -- `counterspell` was
	## the last of 6-5a's nine deferred no-ops and its row LEFT `DEFERRED_EFFECT_OWNERS` when this story gave
	## it a real outcome, so counting it as deferred would be counting it twice wrong.
	var retroactive := 0
	var deferred := 0
	var offenders: Array[String] = []
	for card in _deck_cards():
		for effect: CardEffect in [card.basic_effect, card.pitch_effect]:
			assert_not_null(effect, "Deck 1 card '%s' authors both of its effects" % card.id)
			if effect == null:
				continue
			var id := effect.effect_id
			if String(id).begins_with(CardEffectResolver.PREFIX_SUMMON):
				summons += 1
			elif CardEffectResolver.BUFF_OUTCOMES.has(id):
				buffs += 1
			# Story 6-5b: read off the resolver's own new table, for the derived-not-transcribed reason
			# the buff arm directly above is read off `BUFF_OUTCOMES`.
			elif CardEffectResolver.OWN_MINION_OUTCOMES.has(id):
				own_minion += 1
			# Story 6-5c: read off the resolver's own cast table, for the same derived-not-transcribed
			# reason the two arms above are read off theirs.
			elif CardEffectResolver.CAST_OUTCOMES.has(id):
				cast += 1
			# Story 6-5e: read off the resolver's own opposing-hand table, for the derived-not-transcribed
			# reason all three arms above are read off theirs.
			elif CardEffectResolver.OPPOSING_HAND_OUTCOMES.has(id):
				opposing_hand += 1
			# Story 6-5f: read off the resolver's own retroactive table, for the derived-not-transcribed
			# reason all four arms above are read off theirs.
			elif CardEffectResolver.COUNTERSPELL_OUTCOMES.has(id):
				retroactive += 1
			elif CardEffectResolver.owner_story_for(id) != &"":
				deferred += 1
			else:
				offenders.append("%s -> %s" % [card.id, id])
			assert_false(String(id).begins_with(CardEffectResolver.PREFIX_SPELL),
				"no Deck 1 effect takes the `spell_` prefix -- it would resolve as the fixture no-op")
	assert_eq(offenders.size(), 0,
		"every Deck 1 effect id is one the resolver recognises by whole id or summon prefix: %s"
				% ", ".join(offenders))
	assert_eq(summons, 1, "ONE Deck 1 effect summons (Ruin Vanguard)")
	# Story 6-5d (AC 1, `6-5d/R23`): FOUR -> THREE. Bloodlust was the fourth and has left Deck 1; the
	# census moves with the pairing swap, which is what makes this a measured bucket rather than a
	# transcribed number.
	assert_eq(buffs, 3,
		"Story 6-5d: THREE are buffs -- Vampiric Aura, Bloodhound Step, Frostbite. Bloodlust was the "
		+ "fourth until 6-5d swapped Bloodhound Step's pitch to Fireball; its effect FILE is unchanged "
		+ "and still pinned below, it is simply no longer referenced by a Deck 1 card")
	# Story 6-5e (AC 29-33): FOUR -> FIVE. CORPSE BOMB joins this bucket rather than the cast bucket the
	# 6-5d message predicted for it -- `6-5e/R17` gives it no cast frame, so it resolves on its activation
	# tick like Culling and shares the family's `NEEDS_OWN_LIVING_MINION` precondition unchanged.
	assert_eq(own_minion, 5,
		"Story 6-5e: FIVE are the own-minion / corpse effects -- 6-5b's Culling, Grave Ward, Raise Dead "
		+ "and Drain, plus Corpse Bomb, which kills every living own minion and leaves each a normal "
		+ "corpse through the same death seat (AC 30)")
	# Story 6-5d (AC 1, `6-5d/R23`): ONE -> TWO. FIREBALL joined the cast bucket exactly as 6-5c's own
	# message predicted it would -- "by adding a `CAST_OUTCOMES` row, with no edit to the window or the
	# strike" -- and it is the FIRST cast id that is a card's PITCH effect rather than its basic one.
	# Story 6-5e (AC 7-11a): TWO -> THREE. ROCKSLING joined the cast bucket exactly as 6-5c's and 6-5d's
	# own messages predicted it would -- "by adding a `CAST_OUTCOMES` row alone". CORPSE BOMB did NOT: the
	# prediction named it as a third cast, and `6-5e/R17` ruled it resolves entirely on its activation tick
	# with no cast frame at all, so it is an OWN-MINION outcome instead. The measured bucket is what
	# corrected the prediction, which is the point of counting rather than transcribing.
	assert_eq(cast, 3,
		"Story 6-5e: THREE are CASTS -- Honed Bolt, Fireball and Rocksling. Corpse Bomb was predicted "
		+ "as the fourth and is NOT one: `6-5e/R17` gives it no cast frame, so it resolves as an "
		+ "own-minion outcome on its activation tick")
	assert_eq(opposing_hand, 1,
		"Story 6-5e: ONE reads the OPPOSING hand -- Boom, the only effect in the game that does, which "
		+ "is why it gets its own resolver table and its own board-gate requirement (`6-5e/R27`)")
	# Story 6-5f (AC 4-23): the FIFTH family bucket -- ONE effect is RETROACTIVE. It is deliberately not a
	# row in the opposing-hand bucket above: Counterspell reads the opposing player's last resolved card and
	# the record of what it did, never their hand, so filing it there would make that bucket's name false
	# for half its members (the resolver argues the same at `COUNTERSPELL_OUTCOMES`).
	assert_eq(retroactive, 1,
		"Story 6-5f: ONE is RETROACTIVE -- Counterspell, the only effect in the game that acts on a "
		+ "resolution that has already happened, which is why it gets its own resolver table and its own "
		+ "board-gate requirement (`6-5f/R10`)")
	assert_eq(deferred, 0,
		"...and NOTHING is still a named no-op owned by a later story. ONE before this story "
		+ "(`counterspell`, which 6-5f builds), FOUR before 6-5e, FIVE before 6-5c and NINE before "
		+ "6-5b, each of which retired exactly the rows naming itself -- the deferred table's "
		+ "mechanism working as designed, now run to completion, and the reason this count is asserted "
		+ "separately from the buckets above it")
	for card in _fixture_cards():
		# Story 6-5e (AC 6a): BOULDER IS EXEMPT FROM THE PREFIX RULE, named rather than accommodated. Its
		# `boulder_discard` is a WHOLE-ID resolver row (`BOULDER_OUTCOMES`), which is the same vocabulary
		# every Deck 1 effect uses -- the summon_/spell_ prefixes are the DORMANT FIXTURES' convention, and
		# Boulder is not a dormant fixture: it is live content that simply belongs to no deck.
		if NO_PITCH_MODE_IDS.has(card.id):
			assert_true(CardEffectResolver.BOULDER_OUTCOMES.has(card.basic_effect.effect_id),
				"'%s' is exempt from the prefix rule because the resolver knows it by WHOLE id" % card.id)
			continue
		var id := String(card.basic_effect.effect_id)
		assert_true(id.begins_with(CardEffectResolver.PREFIX_SUMMON)
				or id.begins_with(CardEffectResolver.PREFIX_SPELL),
			"dormant fixture '%s' still carries a summon_/spell_ prefix (%s)" % [card.id, id])


## Story 6-5a (AC 15): each Deck 1 card references the RIGHT two effects, by id.
##
## NON-VACUOUS ON A SHRUNK LIST (6-5a REVIEW N11): the `DECK_1_IDS` literal, not `_deck_cards()`, for
## the reason given at `test_each_deck_1_card_is_priced_at_its_authored_mode_1_and_mode_4_prices`.
func test_each_deck_1_card_references_its_two_effects() -> void:
	for id in DECK_1_IDS:
		var card := _card_for(id)
		if card == null:
			continue
		var expected: Array = DECK_1_EFFECTS[card.id]
		if card.basic_effect != null:
			assert_eq(card.basic_effect.effect_id, expected[0], "'%s' normal effect" % card.id)
		if card.pitch_effect != null:
			assert_eq(card.pitch_effect.effect_id, expected[1], "'%s' pitch effect" % card.id)


## REWRITTEN BY STORY 6-5a (AC 13): was `assert_null(card.pitch_effect)` on EVERY card. Deck 1 authors
## all seven pitch effects, so the assertion splits: Deck 1 cards author one, the dormant fixtures still
## do not. Everything else is unchanged -- Mode ① pays no orbs, every card authors a pitch COST, and each
## pitch cost carries a real, positive orb price (the per-card `M3` form).
func test_basic_mode_only_pitch_and_orbs_left_unauthored() -> void:
	for card in _load_cards():
		assert_not_null(card.basic_effect, "card '%s' authors a basic effect" % card.id)
		assert_true(card.basic_effect.effect_id != &"",
			"card '%s' basic effect names a real effect" % card.id)
		if DECK_1_IDS.has(card.id):
			assert_not_null(card.pitch_effect,
				"Deck 1 card '%s' authors its pitch effect (story 6-5a)" % card.id)
		else:
			assert_null(card.pitch_effect,
				"dormant fixture '%s' still leaves pitch_effect unauthored" % card.id)
		assert_eq(card.cast_condition.orb_costs.size(), 0,
			"card '%s' pays no orbs for Mode ① — orbs are pitch-only (GDD §D)" % card.id)
		# Story 6-5e (AC 6a, `6-5e/R25`/G6): THE NAMED EXEMPTION. Boulder has NO Mode ④ at all (ruling 7),
		# so it authors no pitch cost and no orb price -- and it says so HERE, by id, rather than authoring
		# a fake priced pitch condition to satisfy a census. The two assertions below are what it is exempt
		# from; everything above (a real basic effect, a non-empty id, no Mode ① orb cost) still applies to
		# it unchanged, which is what keeps the exemption narrow.
		if NO_PITCH_MODE_IDS.has(card.id):
			assert_null(card.pitch_condition,
				("'%s' authors NO pitch cost at all -- ruling 7 gives it no Mode 4, and a placeholder "
					+ "price would be the card lying about having one") % card.id)
			continue
		assert_not_null(card.pitch_condition,
			"card '%s' authors a pitch COST (story 6-2, AC 1a)" % card.id)
		if card.pitch_condition != null:
			# PER-CARD, not library-wide (`M3`): a library-wide `priced_in_orbs > 0` survives a SINGLE
			# card's price regressing to empty (`pitch_condition` stays non-null, only `orb_costs` empties)
			# because some other card still counts. Asserted here, inside the loop that already visits
			# every card, so one card's regression fails on that card alone.
			assert_true(card.pitch_condition.orb_costs.size() > 0,
				("card '%s' authors an orb price for its pitch cost (AC 1a) -- the typed `orb_costs` "
				+ "dictionary really parses out of the .tres rather than loading silently empty") % card.id)
			for color: Variant in card.pitch_condition.orb_costs:
				assert_true(Enums.CardColor.values().has(int(color)) and int(card.pitch_condition.orb_costs[color]) > 0,
					"card '%s' prices its pitch in real colours, positive counts" % card.id)


## Story 6-5a (AC 1/AC 15): AN EFFECT IS A NAMED, SHARED FILE. All fourteen Deck 1 effects are standalone
## `CardEffect` resources under `data/effects/`, one file per effect id (the filename mirrors the id by
## convention), and every Deck 1 card holds its effects BY REFERENCE to those files -- never an inlined
## sub-resource.
func test_every_deck_1_effect_is_a_shared_file_under_data_effects() -> void:
	var files := _effect_files()
	# Story 6-5d (AC 1/AC 2): FOURTEEN -> FIFTEEN. `fireball.tres` arrives and `bloodlust.tres` STAYS --
	# that is the whole shape of AC 2, and why this count grows by one rather than holding: Bloodlust is
	# still an authored, loading, field-for-field-unchanged effect file (pinned below), it is simply no
	# longer paired with a Deck 1 card. The directory holds effect FILES, not deck pairings.
	# Story 6-5e (AC 6a): FIFTEEN -> SIXTEEN. `boulder_discard.tres` arrives -- Boulder's own basic effect,
	# the sixteenth file. It is not a Deck 1 effect and never will be (Boulder is in no deck), which is the
	# same "the directory holds effect FILES, not deck pairings" reading `bloodlust.tres` already rests on.
	assert_eq(files.size(), 16,
		"data/effects/ holds sixteen effect files: the fourteen Deck 1 effects, bloodlust.tres (6-5d "
		+ "unpaired it from Deck 1 without deleting, AC 2), and 6-5e's boulder_discard.tres")
	for file_name in files:
		var effect := load(EFFECTS_DIR + file_name) as CardEffect
		assert_not_null(effect, "%s loads as a CardEffect" % file_name)
		if effect != null:
			assert_eq(String(effect.effect_id) + ".tres", file_name,
				"%s authors the effect id its filename names" % file_name)
	for card in _deck_cards():
		for effect: CardEffect in [card.basic_effect, card.pitch_effect]:
			if effect == null:
				continue
			assert_eq(effect.resource_path, EFFECTS_DIR + String(effect.effect_id) + ".tres",
				"'%s' references %s as the SHARED file, not an inlined copy" % [card.id, effect.effect_id])


## Story 6-5a (AC 15, R2, N11): THE FIVE IMPLEMENTED EFFECTS' NUMBERS, exactly as the spec authors them --
## except Bloodhound Step's, which R2 supersedes (3.0 distance, 2.0 i-frames). And N11's other half: the
## NINE deferred effects author NO number at all -- every flat export sits at its neutral default, so a
## deferred effect's numbers arrive with its own story.
func test_the_five_implemented_effects_carry_their_spec_numbers_and_the_rest_carry_none() -> void:
	var bloodlust := _effect(&"bloodlust")
	assert_eq(bloodlust.duration_seconds, 10.0, "Bloodlust lasts 10 s")
	assert_eq(bloodlust.damage_dealt_multiplier, 2.0, "...2x damage dealt")
	assert_eq(bloodlust.damage_taken_multiplier, 2.0, "...2x damage taken")
	var aura := _effect(&"vampiric_aura")
	assert_eq(aura.duration_seconds, 15.0, "Vampiric Aura lasts 15 s")
	assert_eq(aura.lifesteal_fraction, 0.5, "...healing 50% of hero damage")
	var bloodhound := _effect(&"bloodhound_step")
	assert_eq(bloodhound.duration_seconds, 5.0, "Bloodhound Step stays armed 5 s")
	assert_eq(bloodhound.roll_distance_multiplier, 3.0, "...3x roll distance (R2, not the spec's 1.5)")
	assert_eq(bloodhound.roll_iframe_multiplier, 2.0, "...2x i-frames, clamped to the roll (R2)")
	var frostbite := _effect(&"frostbite")
	assert_eq(frostbite.duration_seconds, 6.0, "Frostbite stays armed 6 s")
	assert_eq(frostbite.slow_speed_multiplier, 0.5, "...slowing to 50% speed")
	assert_eq(frostbite.slow_duration_seconds, 4.0, "...for 4 s")
	var neutral := CardEffect.new()
	for id: StringName in CardEffectResolver.DEFERRED_EFFECT_OWNERS.keys() + [&"summon_ruin_vanguard"]:
		var effect := _effect(id)
		for name in _script_property_names(neutral):
			if name == "effect_id":
				continue
			assert_eq(effect.get(name), neutral.get(name),
				"'%s' authors no %s (N11: numbers arrive with its own story)" % [id, name])


## Story 6-5b: THE FOUR OWN-MINION / CORPSE EFFECTS' NUMBERS, exactly as `deck-1-spec.md` authors them.
##
## THIS TEST EXISTS BECAUSE COVERAGE WOULD OTHERWISE HAVE VANISHED SILENTLY, and the story's own
## broken-test table named it in advance. The N11 loop in the test directly above iterates
## `DEFERRED_EFFECT_OWNERS.keys()` and asserts each deferred effect authors NO number; when culling,
## grave_ward, raise_dead and drain left that table, they left that loop too -- so their `.tres` files
## would have been unasserted in either direction, and a number silently reverting to its default
## would have failed nothing.
##
## THE NUMBERS ARE PINNED AGAINST THE SPEC, not against the code that reads them: 2 mana per kill, a
## 20 s Grave Ward extension, 100 % max HP on a raise, 10 HP of Drain heal, and Culling's `kill_cap` of
## 99 (`6-5b/R15`).
##
## TWO OF THE FIVE CANNOT BE PROVEN BY DELETING THEIR `.tres` LINE, and that is stated rather than
## left for a reviewer to discover: `kill_cap` (99) and `raise_hp_percent` (100.0) are authored at
## values that EQUAL their ruled script defaults, so removing the line leaves the assertion green.
## They are mutation-proven by CHANGING the authored value instead -- which is the honest proof for a
## pin whose job is "the authored number is still the spec's number". The other three default to 0.0
## and fail on deletion.
func test_the_four_own_minion_effects_carry_their_spec_numbers() -> void:
	var culling := _effect(&"culling")
	assert_eq(culling.mana_per_kill, 2.0, "Culling grants 2 mana per minion killed")
	assert_eq(culling.kill_cap, 99,
		"...up to a kill_cap of 99 (`6-5b/R15`, the spec's 'effectively no cap')")
	var grave_ward := _effect(&"grave_ward")
	assert_eq(grave_ward.duration_seconds, 20.0,
		"Grave Ward adds 20 s to each of the caster's corpses (`6-5b/R7` -- an ADDITIVE per-corpse "
		+ "extension, not the per-player timed rule deck-1-spec.md originally worded)")
	var raise_dead := _effect(&"raise_dead")
	assert_eq(raise_dead.raise_hp_percent, 100.0, "Raise Dead raises at 100% of max HP")
	var drain := _effect(&"drain")
	assert_eq(drain.heal_amount, 10.0, "Drain heals the caster 10 HP")
	# ...and each of the four still authors NOTHING it does not use, which is the half of N11 that
	# survives their leaving the deferred table. Checked against a neutral CardEffect field by field,
	# skipping only the fields the assertions above have just pinned.
	var neutral := CardEffect.new()
	var authored := {
		&"culling": ["mana_per_kill", "kill_cap"],
		&"grave_ward": ["duration_seconds"],
		&"raise_dead": ["raise_hp_percent"],
		&"drain": ["heal_amount"],
	}
	for id: StringName in authored:
		var effect := _effect(id)
		for name in _script_property_names(neutral):
			if name == "effect_id" or (authored[id] as Array).has(name):
				continue
			assert_eq(effect.get(name), neutral.get(name),
				"'%s' authors no %s -- an effect uses the numbers it needs and no others" % [id, name])


## Story 6-5a (AC 2): EVERY EFFECT NUMBER IS A FLAT EXPORT ON CardEffect ITSELF -- no field holds an
## Object (a nested resource would need a `RecordFile._fresh_nested` row or vanish on replay), and the
## Deck 1 effects are plain CardEffects, never a subclass.
func test_card_effect_numbers_are_flat_exports_with_no_nested_resource() -> void:
	var effect := CardEffect.new()
	for p in effect.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_ne(int(p.type), TYPE_OBJECT,
				"CardEffect.%s is a flat value, not a nested resource (AC 2)" % p.name)
	for file_name in _effect_files():
		var loaded := load(EFFECTS_DIR + file_name) as Resource
		assert_eq((loaded.get_script() as Script).resource_path,
			"res://src/state/resources/card_effect.gd",
			"%s is a plain CardEffect, never a subclass (AC 2)" % file_name)


## Story 6-5a (AC 3): `visual_id` exists, defaults empty, and NO file under src/state/ reads it beyond the
## schema that declares it -- state carries vocabulary, presentation interprets it.
func test_visual_id_is_a_presentation_handle_state_never_reads() -> void:
	var effect := CardEffect.new()
	assert_eq(typeof(effect.visual_id), TYPE_STRING_NAME, "visual_id is a StringName")
	assert_eq(effect.visual_id, &"", "...defaulting empty")
	var readers: Array[String] = []
	for path in _gd_files_under("res://src/state/"):
		if path.ends_with("resources/card_effect.gd"):
			continue
		if FileAccess.get_file_as_string(path).contains("visual_id"):
			readers.append(path)
	assert_eq(readers, [] as Array[String], "no src/state/ file reads visual_id: %s" % str(readers))


## AC 2's "same shape ResourceGenerationRule.required_flag uses", checked rather than asserted
## in prose: both are StringName, both default empty (= always open).
func test_required_flag_mirrors_the_resource_rule_shape() -> void:
	var condition := CardCastCondition.new()
	var rule := ResourceGenerationRule.new()
	assert_eq(typeof(condition.required_flag), typeof(rule.required_flag),
		"CardCastCondition.required_flag has ResourceGenerationRule.required_flag's type")
	assert_eq(typeof(condition.required_flag), TYPE_STRING_NAME, "required_flag is a StringName")
	assert_eq(condition.required_flag, &"", "empty default = always open")
	for card in _load_cards():
		assert_eq(card.cast_condition.required_flag, &"",
			"card '%s' Mode ① cast is ungated" % card.id)


## Sorted, single-directory, extension-filtered — the same discipline the loader uses, so this
## file's set and CardDatabase's set cannot diverge on enumeration order.
func _load_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var card := load(CARDS_DIR + file_name) as CardData
		if card != null:
			out.append(card)
	return out


## Story 6-5a: the authored Deck 1 list.
func _deck_list() -> DeckList:
	return load(DECK_1_PATH) as DeckList


## 6-5a REVIEW N11: one Deck 1 card BY ID, looked up in the library rather than filtered out of the
## deck list. This is what makes a per-card test iterate the `DECK_1_IDS` LITERAL and therefore fail --
## rather than pass with nothing to check -- if the authored list ever shrinks. A missing card is a
## loud failure here, and the `null` return lets the caller skip the body it cannot run.
func _card_for(id: StringName) -> CardData:
	for card in _load_cards():
		if card.id == id:
			return card
	assert_true(false, "Deck 1 card '%s' is authored in data/cards/" % id)
	return null


## Story 6-5a (AC 13): the library filtered BY THE DECK LIST -- the cards Deck 1 actually holds.
func _deck_cards() -> Array[CardData]:
	var ids := _deck_list().card_ids
	var out: Array[CardData] = []
	for card in _load_cards():
		if ids.has(card.id):
			out.append(card)
	return out


func _fixture_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for card in _load_cards():
		if FIXTURE_IDS.has(card.id):
			out.append(card)
	return out


func _effect_files() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(EFFECTS_DIR)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			out.append(file_name)
	out.sort()
	return out


func _effect(id: StringName) -> CardEffect:
	return load(EFFECTS_DIR + String(id) + ".tres") as CardEffect


func _authored_deck_size() -> int:
	return (load(BALANCE_PATH) as BalanceConfig).deck_size


## STORY 6-5d (AC 3): NO NUMBER IN `src/` IS A LITERAL FOR ANY OF FIREBALL'S AUTHORED VALUES.
##
## A SOURCE SCAN, because this is exactly the property a later pass breaks by reaching for a convenient
## constant at a seat: the cap, the per-mana damage and the whole flight profile must be read from the
## `.tres` INLINE at the point of use (CONSTRAINT C), never copied into the state layer. Scoped to
## `src/state/`, which is where every reader of these numbers lives.
##
## COMMENTS ARE STRIPPED before matching (`_code_lines`' job), so the doc blocks that legitimately QUOTE
## the authored values -- `card_effect.gd`'s field docs, `projectile_board.gd`'s header -- are not
## offenders. A number in a comment is documentation; a number in an expression is a copy.
##
## TWO VALUES ARE DELIBERATELY NOT BANNED, recorded rather than silently omitted:
##   * `60.0` -- `TimingWindow.TICK_HZ` is 60, so the travel budget's value collides with the project's
##     clock and banning it would fail on tick arithmetic that has nothing to do with a projectile.
##   * `0.4` -- the acceleration delay collides with `honed_bolt`'s authored `stun_seconds`, and more
##     importantly with ordinary multipliers; too weak a discriminator to be evidence.
## The remaining five are specific enough that a match is a real finding.
func test_no_fireball_number_is_a_literal_in_the_state_layer() -> void:
	var banned := ["1.5", "10.0", "8.0", "120.0", "12.0", "20.0"]
	var scanned := 0
	var offenders: Array[String] = []
	for path in _gd_files_under("res://src/state/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			for literal in banned:
				# A boundary on each side, so `120.0` does not match inside `1120.05` and `10.0` does not
				# match inside `110.0`.
				var re := RegEx.create_from_string(
					"(^|[^0-9.])" + literal.replace(".", "\\.") + "([^0-9]|$)")
				if re.search(line) != null:
					offenders.append("%s:%d [%s] %s" % [path, n, literal, line.strip_edges()])
	assert_true(scanned > 0, "src/state/ scan found no .gd files (guard would be vacuous)")
	# NON-VACUITY: the pattern must match what it bans, or a regex typo would disarm this silently.
	var probe := RegEx.create_from_string("(^|[^0-9.])1\\.5([^0-9]|$)")
	assert_true(probe.search("var x := 1.5") != null,
		"the pattern must match what it bans -- a regex typo must not quietly empty this guard")
	assert_false(probe.search("var x := 11.53") != null, "...and must not match a longer number")
	assert_eq(offenders.size(), 0,
		"Story 6-5d (AC 3): a Fireball number appears as a LITERAL in the state layer -- every one of "
		+ "them must be read from the authored `.tres` inline at the point of use: %s"
				% ", ".join(offenders))


## The code lines of `path` with comments and blank lines removed, so a number QUOTED in a doc block is
## never mistaken for a number used in an expression.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := String(raw)
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		var hash_at := line.find("#")
		if hash_at >= 0:
			line = line.substr(0, hash_at)
		if line.strip_edges() == "":
			continue
		out.append(line)
	return out


func _gd_files_under(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root + f)
	for d in dir.get_directories():
		out.append_array(_gd_files_under(root + d + "/"))
	return out


## Script-declared properties only — @export vars and plain vars, never the inherited Resource
## surface (resource_name, script, ...).
func _script_property_names(obj: Object) -> Array[String]:
	var out: Array[String] = []
	for p in obj.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(String(p.name))
	return out
