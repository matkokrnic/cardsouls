extends TestCase

## Story 3-2 (AC 3 / AC 6 / AC 7): the authored starter card set and the schema shape.
##
## The existing recursive sweep (test_data_resources.gd::test_every_data_tres_loads) already
## proves every card .tres LOADS, with no edit — and load-only is not enough: it would pass a
## set of nine identical cards, a set with duplicate ids, or a copies cap that makes a 20-card
## deck unbuildable. This file asserts the CONTENT. Headless (Resource loading only, no scene,
## no autoload, no frame) — the autoload's own boot is covered by
## test/integration/test_card_database.gd, which the state harness structurally cannot do.

const CARDS_DIR := "res://data/cards/"

## Three colours x {2, 3, 5} mana (3-2 AC 3, operator's sealed nine-card decision).
const EXPECTED_COUNT := 9
const EXPECTED_MANA_COSTS: Array[float] = [2.0, 3.0, 5.0]

## GDD §A, "Deck & hand.": deck 20 cards; max copies per card 2-3, configurable per card in
## data. Per-CARD data, not a BalanceConfig field (the ruling 3-1's gate assigned to 3-2).
const DECK_SIZE := 20
const MIN_COPIES := 2
const MAX_COPIES := 3

## The complete authored export surface of CardData. Pinned EXACTLY: a field added here
## without a story that asks for it fails this test, which is what makes AC 7's negative guard
## below hold for spellings nobody thought to ban.
const CARD_DATA_FIELDS: Array[String] = [
	"id", "color", "basic_effect", "pitch_effect", "cast_condition", "max_copies",
]


func test_nine_cards_load_as_card_data() -> void:
	var cards := _load_cards()
	assert_eq(cards.size(), EXPECTED_COUNT, "data/cards/ holds exactly nine authored cards")
	for card in cards:
		assert_true(card is CardData, "every card .tres casts to CardData")


func test_card_data_exports_exactly_the_authored_field_set() -> void:
	var declared := _script_property_names(CardData.new())
	declared.sort()
	var expected := CARD_DATA_FIELDS.duplicate()
	expected.sort()
	assert_eq(declared, expected, "CardData exports exactly the six authored fields")


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
	assert_eq(seen.size(), EXPECTED_COUNT, "nine distinct ids")


func test_colours_are_card_color_enum_values_three_per_colour() -> void:
	var counts := {Enums.CardColor.RED: 0, Enums.CardColor.BLUE: 0, Enums.CardColor.GREEN: 0}
	for card in _load_cards():
		assert_true(counts.has(card.color),
			"card '%s' colour is an Enums.CardColor value (never a second colour enum)" % card.id)
		counts[card.color] = int(counts[card.color]) + 1
	assert_eq(int(counts[Enums.CardColor.RED]), 3, "three RED cards")
	assert_eq(int(counts[Enums.CardColor.BLUE]), 3, "three BLUE cards")
	assert_eq(int(counts[Enums.CardColor.GREEN]), 3, "three GREEN cards")


func test_each_colour_prices_one_card_at_each_tier() -> void:
	var by_colour := {}
	for card in _load_cards():
		assert_not_null(card.cast_condition, "card '%s' authors a cast condition" % card.id)
		# The literal-not-a-field-name ruling, made executable: a price is a NUMBER on the
		# condition, not the name of a BalanceConfig field the way
		# ResourceGenerationRule.amount_field is. A "fix" to a field name fails here.
		assert_eq(typeof(card.cast_condition.mana_cost), TYPE_FLOAT,
			"card '%s' mana_cost is a literal float" % card.id)
		var costs: Array = by_colour.get(card.color, [])
		costs.append(card.cast_condition.mana_cost)
		by_colour[card.color] = costs
	for colour in by_colour:
		var costs: Array = by_colour[colour]
		costs.sort()
		assert_eq(costs, EXPECTED_MANA_COSTS,
			"colour %d prices one card at each of 2 / 3 / 5 mana" % colour)


func test_copies_cap_is_in_bounds_and_a_twenty_card_deck_is_constructible() -> void:
	var total := 0
	for card in _load_cards():
		assert_true(card.max_copies >= MIN_COPIES and card.max_copies <= MAX_COPIES,
			"card '%s' max_copies %d is in the GDD's 2-3 band" % [card.id, card.max_copies])
		total += card.max_copies
	assert_true(total >= DECK_SIZE,
		"the nine cards allow a %d-card deck (copies available: %d)" % [DECK_SIZE, total])


## Mode ① is what this story authors. Mode ④ (Pitch) is reserved for E6 and stays UNAUTHORED,
## and orbs are spent "exclusively to pay a Pitch Effect (Mode ④) cost. No other use" (GDD §D)
## — so a Mode ① orb price would be a design change, not an authoring detail.
## STORY 4-1 (AC 3, `4-1/R4`): THE MACHINE HALF OF THE GOLDEN-DISCIPLINE RULING. `effect_id` is
## now a determinism-relevant class of change carrying review burden, exactly as a card's
## `mana_cost` already does -- but the gate measured the golden deck as SYNTHETIC with in-test
## costs, so AC 3 claims no measurable golden move from a .tres edit and standing `BC/R3`
## isolation holds. What IS machine-checkable is the AUTHORING: every authored `effect_id` must
## carry a prefix the resolver recognises.
##
## THE PREFIXES ARE READ OFF CardEffectResolver, NEVER RE-TYPED HERE. A literal copy would let the
## resolver rename a prefix and leave this test asserting the old spelling -- green while every
## authored card had silently become an unknown-prefix refusal. This is the same
## derived-not-transcribed discipline RecordFile.REQUIRED_KEYS carries.
##
## THE STANDING BOUND THIS SETS: a TENTH card authored with a third prefix fails HERE, at
## authoring time, instead of failing silently at play time as a card that costs mana, discards,
## and does nothing.
func test_every_authored_effect_id_carries_a_prefix_the_resolver_recognises() -> void:
	var cards := _load_cards()
	assert_eq(cards.size(), EXPECTED_COUNT, "sanity: the scan visited all nine cards")
	var prefixes := [CardEffectResolver.PREFIX_SUMMON, CardEffectResolver.PREFIX_SPELL]
	var offenders: Array[String] = []
	var summons := 0
	var spells := 0
	for card in cards:
		assert_not_null(card.basic_effect,
			"every card authors a Mode (1) effect -- inject_card_effects is TOTAL over the deck")
		var id := String(card.basic_effect.effect_id)
		assert_false(id.is_empty(), "%s authors a non-empty effect_id" % card.id)
		if id.begins_with(CardEffectResolver.PREFIX_SUMMON):
			summons += 1
		elif id.begins_with(CardEffectResolver.PREFIX_SPELL):
			spells += 1
		else:
			offenders.append("%s -> %s" % [card.id, id])
	assert_eq(offenders.size(), 0,
		("every authored effect_id must begin with one of %s (an unrecognised prefix resolves to "
		+ "CardEffectResolver.REASON_UNKNOWN_EFFECT_PREFIX -- a card that costs mana and does "
		+ "nothing): %s") % [prefixes, ", ".join(offenders)])
	# The MEASURED split the story records (six summons, three spells) and the resolver's own
	# reachability claim rests on: AC 6(ii) is declared NOT naturally reachable precisely because
	# these two numbers add up to nine.
	assert_eq(summons, 6, "six authored cards summon")
	assert_eq(spells, 3, "...and three are spells (`4-1/R3`: no authored card is a third kind)")


func test_basic_mode_only_pitch_and_orbs_left_unauthored() -> void:
	for card in _load_cards():
		assert_not_null(card.basic_effect, "card '%s' authors a basic effect" % card.id)
		assert_true(card.basic_effect.effect_id != &"",
			"card '%s' basic effect names a real effect" % card.id)
		assert_null(card.pitch_effect, "card '%s' leaves pitch_effect unauthored (E6)" % card.id)
		assert_eq(card.cast_condition.orb_costs.size(), 0,
			"card '%s' pays no orbs for Mode ① — orbs are pitch-only (GDD §D)" % card.id)


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


## Script-declared properties only — @export vars and plain vars, never the inherited Resource
## surface (resource_name, script, ...).
func _script_property_names(obj: Object) -> Array[String]:
	var out: Array[String] = []
	for p in obj.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(String(p.name))
	return out
