extends TestCase

## Story 3-3: deck, hand, draw. The pure-state half — the Deck/Hand containers, the
## Fisher-Yates against MatchState's seeded generator, the ONE step-6 deal seat, and the
## negative guards on everything this story deliberately does NOT ship.
##
## Headless like every state test: RefCounted objects built directly, no autoload, no frame.
## That is also why deck CONTENT here is opaque in-test ids — data/cards/ is unreachable from
## this harness by design, which is the same reason the golden's fixture authors its own.

const SEED := 4242
const OTHER_SEED := 9001
## Distinct ids, so a shuffle's result and a fill's provenance are both observable. Deliberately
## nothing the card library contains: content reaches state ONLY through the injection seam.
const CONTENTS: Array[StringName] = [
	&"c00", &"c01", &"c02", &"c03", &"c04", &"c05",
	&"c06", &"c07", &"c08", &"c09", &"c10", &"c11",
]
const HAND := 5


## ---- Containers (AC 1, AC 5) ------------------------------------------------------------

func test_deck_and_hand_are_pure_refcounted_holding_string_name_ids() -> void:
	var deck := Deck.new()
	var hand := Hand.new()
	assert_true(deck is RefCounted, "Deck is a pure RefCounted — no Node, no scene, no autoload")
	assert_true(hand is RefCounted, "Hand is a pure RefCounted")
	assert_eq(deck.size(), 0, "a fresh deck is empty — content arrives only by injection")
	assert_true(deck.is_empty())
	deck.set_contents(CONTENTS)
	assert_eq(deck.size(), CONTENTS.size())
	var top: Variant = deck.draw_top()
	assert_true(top is StringName, "deck elements are StringName IDS, never CardData or indices")
	hand.add(top)
	assert_eq(hand.size(), 1)
	hand.clear()
	assert_eq(hand.size(), 0)


func test_read_accessors_hand_out_copies_not_the_backing_array() -> void:
	# The pile must not be mutable through a read. Deck.to_array()/Hand.to_array() exist so the
	# permutation and fill-from-the-top proofs have something to see; they must not be a hole.
	var deck := Deck.new()
	deck.set_contents(CONTENTS)
	var view := deck.to_array()
	view.clear()
	assert_eq(deck.size(), CONTENTS.size(), "clearing the returned array must not empty the deck")
	var source := CONTENTS.duplicate()
	var deck2 := Deck.new()
	deck2.set_contents(source)
	source.clear()
	assert_eq(deck2.size(), CONTENTS.size(), "set_contents copies — the caller's array is not aliased")


## ---- The shuffle (AC 7) ------------------------------------------------------------------

func test_shuffle_same_seed_gives_identical_order() -> void:
	assert_eq(_shuffled(SEED), _shuffled(SEED),
		"same seed, same Fisher-Yates walk, same order — the whole point of the injected generator")


func test_shuffle_different_seed_gives_different_order() -> void:
	assert_ne(_shuffled(SEED), _shuffled(OTHER_SEED),
		"a different seed must reorder the pile (a no-op shuffle would pass the same-seed test alone)")


func test_shuffle_result_is_a_permutation_of_the_input_multiset() -> void:
	var got := _shuffled(SEED)
	got.sort()
	var expected := CONTENTS.duplicate()
	expected.sort()
	assert_eq(got, expected, "nothing invented, nothing lost, nothing duplicated")


func test_shuffle_preserves_duplicates_as_a_multiset() -> void:
	# A real composition holds several copies of the same id (max_copies), so the permutation
	# property must hold for a MULTISET, not just a set of distinct elements.
	var multi: Array[StringName] = [&"a", &"a", &"a", &"b", &"b", &"c"]
	var deck := Deck.new()
	deck.set_contents(multi)
	deck.shuffle_with_rng(_rng(SEED))
	var got := deck.to_array()
	got.sort()
	var expected := multi.duplicate()
	expected.sort()
	assert_eq(got, expected, "three a's in, three a's out")


func test_shuffle_draws_exactly_size_minus_one_times() -> void:
	# The property the golden's cause 2 rests on: the draw count depends on the pile's SIZE
	# alone, never on its contents. Measured by comparing a shuffle's generator against a
	# reference generator advanced by hand the predicted number of times.
	var rng := _rng(SEED)
	var deck := Deck.new()
	deck.set_contents(CONTENTS)
	deck.shuffle_with_rng(rng)
	var reference := _rng(SEED)
	for i in range(CONTENTS.size() - 1, 0, -1):
		reference.randi_range(0, i)
	assert_eq(rng.state, reference.state,
		"exactly size - 1 draws — the count that makes deck_size alone the golden's cause 2")


func test_empty_and_single_card_piles_shuffle_without_drawing() -> void:
	for pile: Array[StringName] in [[] as Array[StringName], [&"only"] as Array[StringName]]:
		var rng := _rng(SEED)
		var before := rng.state
		var deck := Deck.new()
		deck.set_contents(pile)
		deck.shuffle_with_rng(rng)
		assert_eq(rng.state, before, "a pile of %d draws zero times" % pile.size())
		assert_eq(deck.size(), pile.size())


## ---- The ONE seat: shuffle and fill happen inside advance() (AC 7, AC 9) -----------------

func test_injection_alone_deals_nothing_and_consumes_no_rng() -> void:
	# THE one-seat proof. inject_deck is CONTENT ONLY: it must not lay a pile down, must not
	# fill a hand, and must not consume one bit of the seeded generator. If the deal ever
	# migrates into the injection call, "the RNG is consumed only inside advance()" stops being
	# true and replay breaks silently — which is exactly what this catches.
	var ms := _match(SEED, HAND)
	var before: Dictionary = ms.to_snapshot()
	assert_eq(ms.p1.deck.size(), 0, "injection lays down nothing")
	assert_eq(ms.p1.hand.size(), 0, "injection fills nothing")
	_tick(ms)
	assert_eq(ms.p1.deck.size(), CONTENTS.size() - HAND, "the deal ran INSIDE advance()")
	assert_ne(ms.to_snapshot()["rng_state"], before["rng_state"],
		"the seeded RNG moved only once advance() ran")


func test_hand_fills_to_hand_size_from_the_top_of_the_shuffled_deck() -> void:
	var ms := _match(SEED, HAND)
	_tick(ms)
	assert_eq(ms.p1.hand.size(), HAND, "hand filled to the authored hand_size")
	assert_eq(ms.p1.deck.size(), CONTENTS.size() - HAND, "deck holds deck_size - hand_size")
	# Provenance: the dealt cards are the LAST HAND entries of the shuffled pile, in draw order
	# (the top is the back — Deck.draw_top). Reconstruct the shuffle independently and compare.
	var shuffled := _shuffled(SEED)
	var expected: Array[StringName] = []
	for i in HAND:
		expected.append(shuffled[shuffled.size() - 1 - i])
	assert_eq(ms.p1.hand.to_array(), expected,
		"the hand is the TOP of the shuffled pile, in draw order — not the bottom, not unshuffled")
	var remaining := shuffled.slice(0, shuffled.size() - HAND)
	assert_eq(ms.p1.deck.to_array(), remaining, "and the pile is exactly what the hand left behind")


func test_both_players_are_dealt_and_get_different_orders_from_one_seed() -> void:
	var ms := _match(SEED, HAND)
	_tick(ms)
	assert_eq(ms.p2.hand.size(), HAND, "the deal is per-player, fixed P1 -> P2")
	assert_eq(ms.p2.deck.size(), CONTENTS.size() - HAND)
	assert_ne(ms.p1.deck.to_array(), ms.p2.deck.to_array(),
		"two deals off ONE generator in turn — different orders without a second RNG existing")


func test_deal_happens_once_and_is_not_repeated_on_later_ticks() -> void:
	var ms := _match(SEED, HAND)
	_tick(ms)
	var pile := ms.p1.deck.to_array()
	var rng_after_deal: Variant = ms.to_snapshot()["rng_state"]
	for _t in 5:
		_tick(ms)
	assert_eq(ms.p1.deck.to_array(), pile, "the latch is one-shot — no redeal on later ticks")
	assert_eq(ms.p1.hand.size(), HAND)
	assert_eq(ms.to_snapshot()["rng_state"], rng_after_deal,
		"and no further RNG is consumed — nothing else in advance() draws")


func test_hand_size_zero_deals_a_pile_but_fills_nothing() -> void:
	var ms := _match(SEED, 0)
	_tick(ms)
	assert_eq(ms.p1.deck.size(), CONTENTS.size(), "the pile is still laid down and shuffled")
	assert_eq(ms.p1.hand.size(), 0, "...and the fill is a no-op at hand_size 0")


func test_a_match_with_no_injected_deck_stays_inert() -> void:
	# The pre-injection family: a MatchState that never received a deck must tick normally with
	# empty containers, exactly as one that never received balance is inert.
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config(HAND))
	var before: Dictionary = ms.to_snapshot()
	_tick(ms)
	assert_eq(ms.p1.deck.size(), 0)
	assert_eq(ms.p1.hand.size(), 0)
	assert_eq(ms.to_snapshot()["rng_state"], before["rng_state"], "and no RNG is consumed")


## ---- The debug-reset occasion (AC 9) -----------------------------------------------------

func test_debug_reset_restores_the_full_composition_and_refills_the_hand() -> void:
	var ms := _match(SEED, HAND)
	_tick(ms)
	var first_pile := ms.p1.deck.to_array()
	assert_eq(ms.p1.deck.size(), CONTENTS.size() - HAND)
	_tick(ms, true)
	assert_eq(ms.p1.hand.size(), HAND, "the reset refilled the hand (AC 9's second occasion)")
	assert_eq(ms.p1.deck.size(), CONTENTS.size() - HAND,
		"and restored the FULL composition first — the cards in hand are not simply gone")
	assert_ne(ms.p1.deck.to_array(), first_pile,
		"the reset RESHUFFLED — it did not just hand back the same pile")
	var all := ms.p1.deck.to_array()
	all.append_array(ms.p1.hand.to_array())
	all.sort()
	var expected := CONTENTS.duplicate()
	expected.sort()
	assert_eq(all, expected, "post-reset deck + hand is the injected multiset again")


func test_debug_reset_reshuffles_on_the_reset_tick_not_one_tick_later() -> void:
	# The step-1-then-step-6 ordering: the latch is armed at step 1 and consumed at step 6 of the
	# SAME advance(). A seat that read the latch before step 1 would deal one tick late.
	var ms := _match(SEED, HAND)
	_tick(ms)
	var before := ms.p1.deck.to_array()
	_tick(ms, true)
	assert_ne(ms.p1.deck.to_array(), before, "the reset tick itself redealt")


func test_reset_before_any_injection_deals_nothing() -> void:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config(HAND))
	var before: Dictionary = ms.to_snapshot()
	_tick(ms, true)
	assert_eq(ms.p1.deck.size(), 0, "no composition to lay down — the latch is left alone")
	assert_eq(ms.to_snapshot()["rng_state"], before["rng_state"])


## ---- The snapshot contract (AC 5) --------------------------------------------------------

func test_snapshot_carries_counts_only_never_identities_or_order() -> void:
	var ms := _match(SEED, HAND)
	_tick(ms)
	var snap: Dictionary = ms.p1.to_snapshot()
	assert_eq(snap["deck_size"], CONTENTS.size() - HAND, "deck_size is a COUNT")
	assert_eq(snap["hand_size"], HAND, "hand_size is a COUNT")
	assert_true(snap["deck_size"] is int and snap["hand_size"] is int,
		"plain ints — never an array of ids, never a CardData reference")
	# ORDER must be invisible: two matches whose piles are provably in different orders must
	# still produce the same PlayerState snapshot. This is what keeps deck order out of the
	# replay contract while leaving it derivable from seed plus composition.
	var other := _match(OTHER_SEED, HAND)
	_tick(other)
	assert_ne(ms.p1.deck.to_array(), other.p1.deck.to_array(), "sanity: the two piles differ")
	assert_eq(ms.p1.to_snapshot(), other.p1.to_snapshot(),
		"...yet the snapshots are identical — order is NOT hash-visible (AC 5)")


## ---- AC 10: the empty-deck check at the injection seam ------------------------------------

## SOURCE-LEVEL by necessity, and the reason is worth stating rather than hiding: Invariant.check
## routes through assert(), which cannot be caught in-process — a behavioural test would abort
## the harness, and run_all.sh greps for "INVARIANT VIOLATED", so even a surviving one would fail
## the suite for the wrong reason. What IS provable is that the check is still THERE, at the
## seam, on the emptiness condition: delete it and this fails. Same mechanism as the source scans
## in test_architecture_invariants.gd, and the comment-stripping reader is duplicated from it on
## purpose (two files, two scopes; a shared helper has no honest home until a third asks).
func test_injection_seam_rejects_an_empty_injected_deck() -> void:
	var in_seam := false
	var guarded := false
	var seam_found := false
	for line in _code_lines("res://src/state/match_state.gd"):
		if line.begins_with("func inject_deck("):
			in_seam = true
			seam_found = true
			continue
		if in_seam and line.begins_with("func "):
			break
		if in_seam and line.contains("Invariant.check") and line.contains("is_empty()"):
			guarded = true
	assert_true(seam_found, "match_state.gd must still declare inject_deck (a rename un-guards this)")
	assert_true(guarded,
		"inject_deck must Invariant.check that the injected content is non-empty (AC 10)")


## ---- AC 11: the negative guard ------------------------------------------------------------

## Everything this story deliberately does NOT ship, machine-checked rather than trusted to
## review. Discard, reshuffle-on-exhaustion, the vulnerable window and the draw-on-play delay all
## move to 3-5 TOGETHER WITH THEIR TRIGGERS — with only an initial fill drawing from the pile,
## exhaustion is unreachable and a discard pile would be permanently empty. A speculative
## half-implementation here would be dead code guarding nothing.
func test_no_discard_reshuffle_exhaustion_or_draw_delay_surface_ships() -> void:
	var re := RegEx.create_from_string("(discard|reshuffle|exhaust|vulnerab|draw_replacement)")
	var offenders: Array[String] = []
	var scanned := 0
	for path in _gd_files("res://src/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/ scan found no .gd files (guard would be vacuous)")
	assert_true(re.search("func _reshuffle_deck() -> void:") != null,
		"the pattern must match what it bans — a regex typo must not silently disarm this")
	assert_eq(offenders.size(), 0,
		"3-5 surface shipped early in src/ (AC 11 — no discard, reshuffle, exhaustion handling, "
		+ "vulnerable window or draw-replacement delay): %s" % ", ".join(offenders))


func test_no_card_effect_or_cast_evaluator_consumer_ships() -> void:
	# CardEffect and CardCastCondition exist as story 3-2 VOCABULARY under src/state/resources/.
	# What must not exist yet is a CONSUMER: nothing may evaluate a cast or apply an effect (AC
	# 11 — that is 3-5's). So the tokens are legal in their own declaring files and nowhere else.
	var re := RegEx.create_from_string("(CardEffect|CardCastCondition)")
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		if path.ends_with("/card_effect.gd") or path.ends_with("/card_cast_condition.gd") \
				or path.ends_with("/card_data.gd"):
			continue
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_eq(offenders.size(), 0,
		"a card effect / cast evaluator consumer shipped (AC 11 — that is story 3-5): %s"
				% ", ".join(offenders))


func test_event_bus_still_carries_exactly_the_two_declared_signals() -> void:
	# AC 11: no EventBus signal ships here. The vulnerable-window event IS ruled to be an
	# ownerless bus event on the round_started/round_ended precedent (E3-RG/R3) — that ruling
	# stays binding on 3-5, which owns the trigger. Pinning the SET is what makes "no signal
	# shipped" checkable; a later story that legitimately adds one updates this deliberately.
	var bus: GDScript = load("res://src/systems/event_bus.gd")
	var names: Array[String] = []
	for s in bus.get_script_signal_list():
		names.append(String(s.name))
	names.sort()
	assert_eq(names, ["round_ended", "round_started"],
		"EventBus signal set is unchanged by this story (AC 11)")


func test_no_card_input_action_ships() -> void:
	# AC 11: no project.godot Input Map entry. Scoped to the tokens THIS story could have added
	# rather than pinning the whole action list, which would break on every unrelated input story.
	var offenders: Array[String] = []
	for action: StringName in InputMap.get_actions():
		var name := String(action)
		if name.begins_with("ui_"):
			continue
		for token in ["card", "play", "draw", "pitch", "discard", "hand"]:
			if name.contains(token):
				offenders.append(name)
	assert_eq(offenders.size(), 0,
		"a card-related Input Map action shipped (AC 11): %s" % ", ".join(offenders))


func test_hand_and_deck_expose_no_play_or_discard_path() -> void:
	# The containers themselves must not have grown 3-5's surface. Method-level, so a helper
	# added "for later" bites here instead of shipping quietly.
	var banned := ["discard", "play", "reshuffle", "refill", "exhaust"]
	var offenders: Array[String] = []
	for script_path in ["res://src/state/deck.gd", "res://src/state/hand.gd"]:
		var script: GDScript = load(script_path)
		for m in script.get_script_method_list():
			for token in banned:
				if String(m.name).contains(token):
					offenders.append("%s::%s" % [script_path.get_file(), m.name])
	assert_eq(offenders.size(), 0,
		"Deck/Hand grew a 3-5 method (AC 11): %s" % ", ".join(offenders))


## ---- helpers ------------------------------------------------------------------------------

## Balance built IN-TEST, the _golden_config principle: nothing here loads
## data/balance/balance_config.tres, so a playtest edit can never break these assertions.
## max_hp is authored non-zero for one reason only — a stat-less hero is dead on the first
## resolution check, which would freeze advance() at step 1b before step 6 was ever reached.
func _config(hand_size: int) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.deck_size = CONTENTS.size()
	c.hand_size = hand_size
	return c


func _match(seed_value: int, hand_size: int) -> MatchState:
	var ms := MatchState.new(MatchParams.new(seed_value))
	ms.apply_balance(_config(hand_size))
	ms.inject_deck(CONTENTS)
	ms.drain_signals()
	return ms


func _tick(ms: MatchState, debug_reset := false) -> void:
	var i1 := InputIntent.new()
	if debug_reset:
		i1.debug_reset = true
	var intents: Array[InputIntent] = [i1, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## CONTENTS shuffled against a generator seeded exactly as MatchState seeds its own — an
## INDEPENDENT reconstruction of the first deal, so the fill-provenance assertions compare
## against a value derived separately rather than against the code under test.
func _shuffled(seed_value: int) -> Array[StringName]:
	var deck := Deck.new()
	deck.set_contents(CONTENTS)
	deck.shuffle_with_rng(_rng(seed_value))
	return deck.to_array()


func _gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root + f)
	for d in dir.get_directories():
		out.append_array(_gd_files(root + d + "/"))
	return out


# Code portion of each line (everything before the first '#'), so comments can't false-positive.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		var hash_idx := line.find("#")
		if hash_idx >= 0:
			line = line.substr(0, hash_idx)
		out.append(line)
	return out
