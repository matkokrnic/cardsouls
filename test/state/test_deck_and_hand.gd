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
	# Story 4-0 (AC 1/AC 2): the hand is FIXED-WIDTH and the width comes FROM THE CALLER. A fresh
	# Hand has width 0 — it has never been dealt to — and `clear(width)` is what establishes one.
	# `Hand.add` is gone: appending against a pre-filled width would write PAST it.
	assert_eq(hand.size(), 0, "a never-dealt hand has width 0 (`4-0/R2`)")
	hand.clear(3)
	assert_eq(hand.size(), 3, "clear(width) establishes the WIDTH...")
	assert_eq(hand.occupied_count(), 0, "...holding nothing yet")
	hand.fill_at(1, top)
	assert_eq(hand.size(), 3, "a fill does not change the width")
	assert_eq(hand.occupied_count(), 1)
	assert_eq(hand.to_array(), [Hand.EMPTY, top, Hand.EMPTY] as Array[StringName],
		"...and lands in the NAMED slot, holes either side")
	hand.clear(0)
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
	assert_eq(ms.p1.hand.occupied_count(), HAND, "hand filled to the authored hand_size")
	# Story 4-0 (AC 5): every slot occupied, none left a hole, immediately after a deal. The
	# authoring audit keeps hand_size <= deck_size, so the fill never reaches the is_empty() floor.
	assert_eq(ms.p1.hand.size(), HAND, "...across the full authored WIDTH")
	for i in HAND:
		assert_false(ms.p1.hand.is_slot_empty(i), "deal left no hole at slot %d" % i)
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
	assert_eq(ms.p2.hand.occupied_count(), HAND, "the deal is per-player, fixed P1 -> P2")
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
	assert_eq(ms.p1.hand.occupied_count(), HAND)
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
	assert_eq(ms.p1.hand.occupied_count(), HAND, "the reset refilled the hand (AC 9's second occasion)")
	assert_eq(ms.p1.deck.size(), CONTENTS.size() - HAND,
		"and restored the FULL composition first — the cards in hand are not simply gone")
	assert_ne(ms.p1.deck.to_array(), first_pile,
		"the reset RESHUFFLED — it did not just hand back the same pile")
	var all := ms.p1.deck.to_array()
	all.append_array(ms.p1.hand.occupied_ids())
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
## routes through assert(), which cannot be caught in-process — it PRINTS AND CONTINUES at exit 0
## rather than aborting (3-0c/R15), and run_all.sh greps for "INVARIANT VIOLATED", so a
## deliberately triggered one would fail the suite for the wrong reason. What IS provable is that
## the check is still THERE, at the seam, on the emptiness condition: delete it and this fails.
## Same mechanism as the source scans
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
##
## NARROWED BY STORY 3-5a, which is the owner this fence names. 3-5 split into 3-5a (the TRIGGER)
## and 3-5b (what the trigger makes reachable), and the two halves land separately:
##   - `discard` is DROPPED from the ban — 3-5a ships the discard pile, because a card that leaves
##     the hand has to go somewhere the same tick it is played.
##   - `reshuffle`, `exhaust`, `vulnerab` and `draw_replacement` STAY BANNED, and this fence is
##     now 3-5b's.
##
## NARROWED AGAIN BY STORY 3-5b, the owner named directly above, which is the legitimate
## introducer of three of the four tokens (Fence Inventory, 3-5b):
##   - `reshuffle`, `vulnerab` and `draw_replacement` — THE BAN DIES. The lazy reshuffle, the
##     vulnerable window and the authored draw-replacement delay all ship in this story.
##   - `exhaust` — STAYS BANNED, and this half is the whole surviving fence. Exhaustion is
##     expressible as `is_empty()`, which is already how 3-5a and 3-5b both express it: nothing in
##     src/ needs an "exhausted" concept, a flag or a state, and a story that reaches for one is
##     modelling the floor instead of just reading the pile. Both the vacuity assertion and the
##     regex self-test are RETAINED, so a typo cannot silently disarm a fence that has just been
##     narrowed (3-5b AC 14).
##
## RENAMED with the narrowing, from `test_no_reshuffle_exhaustion_or_draw_delay_surface_ships` —
## the old name is recorded here verbatim so the 3-5b Fence Inventory stays greppable, and the new
## one does not claim to ban three tokens that now ship legitimately.
func test_no_deck_exhaustion_surface_ships() -> void:
	var re := RegEx.create_from_string("(exhaust)")
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
	assert_true(re.search("var _deck_exhausted := false") != null,
		"the pattern must match what it bans — a regex typo must not silently disarm this")
	assert_null(re.search("if player.deck.is_empty():"),
		"...and must NOT match the sanctioned form — exhaustion is expressible as is_empty()")
	assert_eq(offenders.size(), 0,
		"a deck-exhaustion surface shipped in src/ (the pile is read with is_empty(), never "
		+ "modelled as a flag or a state): %s" % ", ".join(offenders))


## NARROWED BY STORY 3-5a, the owner this fence names. 3-5a IS the cast-evaluator consumer, so
## `CardCastCondition` is dropped from the ban — it now legitimately appears in CastEvaluator, in
## MatchState's injected cost map, and in the runner that derives it.
##
## `CardEffect` STAYS BANNED, and that is not an oversight of this pass: 3-5a resolves a cast and
## emits the CARD ID, never a CardEffect. Nothing evaluates or applies an effect anywhere in
## src/, so the fence still has a real subject — the first story to resolve effect CONTENT
## retires it deliberately, exactly as this one retired the cast half.
##
## NARROWED AGAIN BY STORY 4-1, WHICH IS THE STORY THE CLAUSE DIRECTLY ABOVE NAMES. 4-1 resolves
## effect CONTENT: CardEffectResolver reads `effect_id`, MatchState holds the injected map,
## IntentRecorder and RecordFile carry it on the third content channel, and the runner derives
## it. `CardEffect` is therefore DROPPED from the ban, exactly as 3-5a dropped
## `CardCastCondition` when it became that token's legitimate consumer -- the fence is NARROWED
## to what is still unconsumed, never deleted, so the Fence Inventory keeps a real subject.
##
## The RENAME follows the same discipline as the EventBus fence below: a name asserting "no
## consumer ships" must not go on asserting it about a token that now has one. The old name is
## recorded here verbatim so the Fence Inventory stays greppable:
## `test_no_card_effect_consumer_ships`.
##
## `pitch_effect` IS WHAT REMAINS BANNED, and it has a real subject for exactly the reason
## `CardEffect` did until this story: CardData.pitch_effect is Mode (4), reserved for E6,
## authored null on every one of the nine cards, and read by NOTHING. 4-1 consumes `basic_effect`
## alone -- the resolver never so much as names the pitch field -- so a pitch consumer appearing
## in src/ before E6 designs the pitch mode is still exactly the drift this fence exists to
## catch. The E6 story that builds the pitch mode retires it deliberately, as this one did the
## basic half.
func test_no_pitch_effect_consumer_ships() -> void:
	var re := RegEx.create_from_string("(pitch_effect)")
	var offenders: Array[String] = []
	var scanned := 0
	for path in _gd_files("res://src/"):
		if path.ends_with("/card_data.gd"):
			continue          # the schema DECLARES the field; declaring is not consuming
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) != null:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/ scan found no .gd files (guard would be vacuous)")
	# NON-VACUITY, two ways. The pattern must MATCH the form it bans, and must NOT match the
	# Mode (1) read story 4-1 legitimately ships -- a regex that caught both would be failing
	# green against this story's own resolver rather than against a real pitch consumer.
	assert_true(re.search("var effect: CardEffect = card.pitch_effect") != null,
		"the pattern must match what it bans -- a regex typo must not silently disarm this")
	assert_null(re.search("out[id] = card.basic_effect"),
		"...and must NOT match the sanctioned Mode (1) read that story 4-1 ships")
	assert_eq(offenders.size(), 0,
		"a PITCH-effect consumer shipped in src/ (Mode (4) is E6's; 4-1 consumes basic_effect "
		+ "alone): %s" % ", ".join(offenders))


## DELIBERATELY UPDATED BY STORY 3-5b, two signals -> three (AC 6, Fence Inventory), and RENAMED
## with it from `test_event_bus_still_carries_exactly_the_two_declared_signals` — a name carrying
## a count must not go on asserting a different one. The old name is recorded here verbatim so the
## Fence Inventory stays greppable.
##
## 3-3's AC 11 pinned the set at two precisely SO THAT this could not happen quietly: the
## vulnerable-window event was already ruled to be an ownerless bus event on the
## round_started/round_ended precedent (E3-RG/R3), and 3-5b is the story that ruling named. The
## story naming this test is the record that the change was intended rather than drifted into.
func test_event_bus_still_carries_exactly_the_three_declared_signals() -> void:
	var bus: GDScript = load("res://src/systems/event_bus.gd")
	var names: Array[String] = []
	for s in bus.get_script_signal_list():
		names.append(String(s.name))
	names.sort()
	assert_eq(names, ["reshuffle_vulnerable_window_opened", "round_ended", "round_started"],
		"EventBus carries exactly the three declared signals (3-5b AC 6 added the third)")


## NARROWED BY STORY 3-5a, the owner this fence names — and it is now story 3-5a's OWN AC 12
## negative guard rather than a leftover.
##
## `card` is DROPPED from the ban: 3-5a ships p1_card_1..4 / p2_card_1..4 plus the cast modifier
## and confirm, under the Input Map discipline AC 11 sets out (textual edit, editor closed,
## SHA256 before and after, diff reviewed).
##
## `pitch` and `stage` STAY BANNED, and that is AC 12 exactly: the staging verb belongs to the
## pitch zone, which is an E6 flag and is OFF, so a reserved action with no consumer must not
## ship — the retired-pose-id precedent. (There was nothing to DELETE: no pitch or stage action
## has ever existed in project.godot, so AC 12 is discharged as a pure negative guard, which is
## this test.) `play`, `draw`, `discard` and `hand` stay banned too — 3-5a binds a cast modifier,
## four card slots and a confirm, and nothing else.
func test_no_pitch_stage_or_other_reserved_card_action_ships() -> void:
	var offenders: Array[String] = []
	for action: StringName in InputMap.get_actions():
		var name := String(action)
		if name.begins_with("ui_"):
			continue
		for token in ["play", "draw", "pitch", "discard", "hand", "stage"]:
			if name.contains(token):
				offenders.append(name)
	assert_eq(offenders.size(), 0,
		"a reserved pitch/stage (or other unshipped card) Input Map action exists (AC 12): %s"
				% ", ".join(offenders))


## Story 3-5a (AC 11): the actions this story DOES ship, pinned positively. The negative guard
## above cannot tell "correctly added" from "never added", so the pair is what makes the Input
## Map edit checkable in both directions — a lost or renamed bind fails here.
##
## "BOTH PLAYERS" NAMES THE 3-5a CARD SCHEME ONLY. Story 5-7 (AC 13) retired the two TEMPORARY,
## single-player confirm keys that used to make `SHIPPED_INPUT_ACTIONS` below asymmetric
## (`p1_cast_unblockable` from 5-3, `p2_cast_defense` from 5-5) -- the pad's B and X confirm those
## two modes now, so the keyboard scheme is symmetric again and this test is unchanged by that.
func test_card_scheme_input_actions_ship_for_both_players() -> void:
	var missing: Array[String] = []
	for prefix in ["p1", "p2"]:
		var expected: Array[String] = ["%s_cast_mode" % prefix, "%s_cast_confirm" % prefix]
		for i in 4:
			expected.append("%s_card_%d" % [prefix, i + 1])
		for action in expected:
			if not InputMap.has_action(action):
				missing.append(action)
	assert_eq(missing.size(), 0,
		"card-scheme Input Map actions missing (AC 11): %s" % ", ".join(missing))


## Story 3-0c (AC 14, `3-0c/R11`): THE SHIPPED INPUT MAP ACTION SET, PINNED BY EXACT EQUALITY.
##
## This story adds NO action, and the way that is checked is not a "no record/replay-named
## action" scan — the repo's own labelled precedent directly above says why that would be
## vacuous: "The negative guard above cannot tell 'correctly added' from 'never added', so the
## pair is what makes the Input Map edit checkable in both directions." A negative scan for names
## nobody has proposed is a guard against nothing.
##
## So the whole project action set is pinned instead, and an ADDED action fails exactly as loudly
## as a removed or renamed one. Godot's built-in `ui_*` navigation is excluded: it ships with the
## engine, is not this project's to pin, and deliberately shares keys with gameplay actions
## already (p2_move_* are the arrow keys — see test_debug_step_pause.gd's collision scan, which
## excludes them for the same reason).
const SHIPPED_INPUT_ACTIONS: Array[String] = [
	"debug_pause", "debug_step",
	"p1_attack", "p1_block", "p1_card_1", "p1_card_2", "p1_card_3", "p1_card_4",
	"p1_cast_confirm", "p1_cast_mode", "p1_debug_reset",
	"p1_move_down", "p1_move_left", "p1_move_right", "p1_move_up", "p1_roll",
	# Story 6-8 (AC 23/AC 24): the five keyboard LOCK CONTROLS per slot JOIN the list -- this story
	# ships their consumer (`KeyboardController`), on the same `3-0c/R11` discipline. Ratified table:
	# P1 `T` lock, `F`/`G` camera left/right, `Z`/`C` cycle left/right.
	"p1_lock", "p1_camera_left", "p1_camera_right", "p1_cycle_left", "p1_cycle_right",
	# Story 6-7 (AC 3): `p1_run`/`p2_run` JOIN the list -- the ONE `project.godot` edit this story
	# makes (`p1_run` = Space, `p2_run` = NUMPAD 0, `6-7/R18`), on the same `3-0c/R11` pin
	# discipline: the story that ships the consumer is the story that moves the list.
	"p1_run",
	"p2_attack", "p2_block", "p2_card_1", "p2_card_2", "p2_card_3", "p2_card_4",
	# Story 5-7 (AC 13): `p1_cast_unblockable` (5-3) and `p2_cast_defense` (5-5) LEAVE this list,
	# because this is the story that retires their consumers -- the pad's B and X confirm modes ②
	# and ③ now, so both TEMPORARY keyboard keys and their Input Map actions are deleted. The pin
	# working exactly as `3-0c/R11` built it, run in reverse: the story that ships the consumer is
	# the story that moves the list, and so is the story that retires it. This story adds NO action,
	# so the set only shrinks.
	"p2_cast_confirm", "p2_cast_mode", "p2_debug_reset",
	"p2_move_down", "p2_move_left", "p2_move_right", "p2_move_up", "p2_roll",
	"p2_run",
	# Story 6-8: P2 `Numpad 5` lock, `Numpad 4`/`Numpad 6` camera left/right, `Numpad 1`/`Numpad 3`
	# cycle left/right.
	"p2_lock", "p2_camera_left", "p2_camera_right", "p2_cycle_left", "p2_cycle_right",
]


func test_shipped_input_map_action_set_is_exactly_pinned() -> void:
	var shipped: Array[String] = []
	for action: StringName in InputMap.get_actions():
		var name := String(action)
		if name.begins_with("ui_"):
			continue
		shipped.append(name)
	shipped.sort()
	var expected := SHIPPED_INPUT_ACTIONS.duplicate()
	expected.sort()
	assert_eq(shipped, expected,
		"the project's Input Map action set moved. An action is a project.godot edit and belongs "
		+ "to the story that ships its consumer — 3-0c ships none (its replay mode is reachable "
		+ "only from a test, never from a key)")


## Story 5-5 (AC 15.1, REVIEW FIX — caught by the operator's eye, not by any prior gate): a
## permanent guard against a physical key silently backing TWO project actions. Godot allows this
## without complaint — `p2_cast_defense` once shipped on physical keycode 76 (`L`), already
## `p1_roll`'s own key, so every P2 defense confirm would ALSO roll the P1 hero. The gate that
## authored `p2_cast_defense` measured "L is free" against the CARD scheme only and never
## cross-checked the combat rows; this test widens the scope to EVERY shipped action, project-wide,
## so the next new key collides here instead of at the keyboard. `p2_cast_defense` itself is gone
## as of `5-7` (its keyboard confirm was retired alongside `p1_cast_unblockable`), but the guard it
## provoked stays — it is project-wide and permanent, not scoped to the action that first found it.
##
## `test_debug_step_pause.gd::test_debug_keys_collide_with_no_other_project_binding` is the
## PRECEDENT this generalises — that one scopes to `debug_pause`/`debug_step` against everything
## else; this one has no privileged side, because ANY two actions colliding is the same bug.
## `ui_*` is excluded for the identical reason that test excludes it: Godot's built-in navigation
## deliberately shares keys with gameplay actions already (`p2_move_*` are the arrow keys, which
## are also `ui_*`), so a scan including it would assert a rule this project does not hold.
func test_no_physical_key_backs_two_project_actions() -> void:
	var owner_of: Dictionary = {}   # physical_keycode -> first action seen holding it
	var collisions: Array[String] = []
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var code: int = (event as InputEventKey).physical_keycode
				if owner_of.has(code) and owner_of[code] != action:
					collisions.append("%s vs %s (physical_keycode %d)" % [action, owner_of[code], code])
				else:
					owner_of[code] = action
	assert_eq(collisions.size(), 0,
		"a physical key backs more than one action (AC 15.1): %s" % ", ".join(collisions))


## Story 3-5b (AC 2): THE GUARD THAT KEEPS OPEN DECISION (b) OPEN.
##
## A `TimingWindow` cannot exist without a duration, so `reshuffle_vulnerable_window_seconds` IS
## authored — but what "vulnerable" COSTS is still undecided (decision-log Session 2026-07-22,
## open decision (b), carried untouched by every story since). The mechanism that keeps it
## genuinely open rather than closed by construction is this: if NOTHING READS the window, nothing
## has priced it. A damage path, a mitigation path or an action-state path that consulted it would
## silently decide the open question; this fence makes that impossible to do by accident.
##
## READS ARE BANNED; the two WRITES that make the window exist at all are allowed and enumerated.
## `tick()` is a write, not a read — a window nobody advances is a window permanently open, which
## is a different bug — and `start()` is the reshuffle itself. Everything else is an offender,
## including `is_running`, `remaining_ticks()` and `to_snapshot()`: those three are exactly how a
## consumer would price it, and the third is additionally why the window is NOT a snapshot key.
##
## The pattern is anchored on the FIELD ACCESS (`.vulnerable_window`), not the bare word, so the
## authored balance field and the signal name — which share the vocabulary and are legitimately
## everywhere — cannot false-positive. Both directions of that are self-tested below.
## TWO patterns, and the second exists because the first has a measured blind spot. The ACCESS
## pattern is anchored on a leading dot, so it sees every read through a handle
## (`player.`, `p1.`, `target.`) — which is every consumer OUTSIDE PlayerState — but NOT an
## UNQUALIFIED self-read inside player_state.gd itself, where the field is named bare. That hole
## was found by mutation (adding `"vulnerable_window": vulnerable_window.to_snapshot()` to the
## snapshot passed this guard while correctly failing the AC 4 key-set pin), so the READ pattern
## below closes it: the three state-reading forms are banned outright, dot or no dot, anywhere
## under src/.
const VULNERABLE_WINDOW_WRITER := "res://src/state/match_state.gd"
const VULNERABLE_WINDOW_ALLOWED_FORMS: Array[String] = [
	".vulnerable_window.start(", ".vulnerable_window.tick()",
]


func test_nothing_in_src_reads_the_reshuffle_vulnerable_window() -> void:
	var read := RegEx.create_from_string(
		"vulnerable_window\\.(is_running|remaining_ticks|to_snapshot)")
	assert_true(read.search("\tvar v := vulnerable_window.to_snapshot()") != null,
		"the READ pattern must catch an UNQUALIFIED self-read — the access pattern below cannot")
	assert_true(read.search("\tif p1.vulnerable_window.is_running:") != null,
		"...and a qualified one")
	assert_null(read.search("\tplayer.vulnerable_window.start(ticks)"),
		"...while leaving the sanctioned WRITES alone")
	var read_offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		var rn := 0
		for line in _code_lines(path):
			rn += 1
			if read.search(line) != null:
				read_offenders.append("%s:%d %s" % [path, rn, line.strip_edges()])
	assert_eq(read_offenders.size(), 0,
		"the vulnerable window's STATE is read somewhere in src/ — is_running/remaining_ticks are "
		+ "how a consumer prices it, and to_snapshot is why it is not a hash key: %s"
				% ", ".join(read_offenders))
	var re := RegEx.create_from_string("\\.vulnerable_window\\b")
	# The pattern must match what it exists to catch...
	assert_true(re.search("\tif target.vulnerable_window.is_running:") != null,
		"the pattern must catch a READ of the window — a regex typo must not disarm this")
	assert_true(re.search("\tplayer.vulnerable_window.start(ticks)") != null,
		"...and the write it allows, or the allow-list would never be consulted")
	# ...and must NOT match the two things that share its vocabulary, or the fence would be
	# unimplementable and would get relaxed rather than kept.
	assert_null(re.search("\tbalance.reshuffle_vulnerable_window_seconds"),
		"the authored BALANCE FIELD is not the window and must not trip this")
	assert_null(re.search("\t_queue.push(reshuffle_vulnerable_window_opened.emit.bind(slot))"),
		"the SIGNAL is the window's public face and must not trip this")
	var scanned := 0
	var hits := 0
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) == null:
				continue
			hits += 1
			var allowed := false
			if path == VULNERABLE_WINDOW_WRITER:
				for form in VULNERABLE_WINDOW_ALLOWED_FORMS:
					if line.contains(form):
						allowed = true
			if not allowed:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/ scan found no .gd files (guard would be vacuous)")
	assert_true(hits > 0,
		"src/ must TOUCH the vulnerable window somewhere — otherwise this guard is vacuous")
	assert_eq(offenders.size(), 0,
		"something in src/ READS the reshuffle vulnerable window — open decision (b) would be "
		+ "closed by construction rather than by a ruling: %s" % ", ".join(offenders))


## Story 3-5b (AC 7): NO EARLY-STOP PATH SHIPS. 1-9/R3 stays locked — an in-flight window "is NOT
## stopped or shortened ... it simply resolves to nothing" — and death drops the DELIVERY, not the
## window. This scan is what keeps that a property of the code rather than of the current author's
## intent: the pending-draw window may only be STARTED, TICKED and READ, never stopped, cleared or
## force-closed by writing `is_running`.
##
## `pending_draw_owed` is deliberately NOT matched (the `\b` after `pending_draw` sees the
## underscore and fails): the DEBT is a different thing from the WINDOW, and the debug reset
## legitimately zeroes it (AC 9). Self-tested in both directions below.
##
## Note that `start(0)` is the sanctioned KILL — the debug reset uses it — and is allowed on
## purpose: it goes through the one shipped API instead of a bespoke abort, which is precisely what
## makes "no early-stop path" checkable at all.
const PENDING_DRAW_WRITER := "res://src/state/match_state.gd"
const PENDING_DRAW_ALLOWED_FORMS: Array[String] = [
	".pending_draw.start(", ".pending_draw.tick()", ".pending_draw.is_running",
]
const PENDING_DRAW_BANNED_FORMS: Array[String] = [
	".pending_draw.stop(", ".pending_draw.clear(",
	".pending_draw.is_running =", ".pending_draw.is_running=",
]


func test_nothing_in_src_stops_or_clears_the_pending_draw_window() -> void:
	var re := RegEx.create_from_string("\\.pending_draw\\b")
	assert_true(re.search("\tplayer.pending_draw.stop()") != null,
		"the pattern must catch an early stop — a regex typo must not disarm this")
	assert_null(re.search("\tplayer.pending_draw_owed.clear()"),
		"the DEBT is not the window: the debug reset zeroes it legitimately (AC 9)")
	for banned in ["\tplayer.pending_draw.stop()", "\tplayer.pending_draw.clear()",
			"\tplayer.pending_draw.is_running = false"]:
		var caught := false
		for form in PENDING_DRAW_BANNED_FORMS:
			if banned.contains(form):
				caught = true
		assert_true(caught, "the ban list must catch `%s`" % banned.strip_edges())
	var scanned := 0
	var hits := 0
	var offenders: Array[String] = []
	for path in _gd_files("res://src/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			if re.search(line) == null:
				continue
			hits += 1
			var allowed := false
			if path == PENDING_DRAW_WRITER:
				for form in PENDING_DRAW_ALLOWED_FORMS:
					if line.contains(form):
						allowed = true
			for form in PENDING_DRAW_BANNED_FORMS:
				if line.contains(form):
					allowed = false
			if not allowed:
				offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "src/ scan found no .gd files (guard would be vacuous)")
	assert_true(hits > 0,
		"src/ must TOUCH the pending-draw window somewhere — otherwise this guard is vacuous")
	assert_eq(offenders.size(), 0,
		"an early-stop / abort path against the pending-draw window shipped in src/ (1-9/R3: an "
		+ "in-flight window resolves to nothing, it is never cut short): %s" % ", ".join(offenders))


## Story 4-0 (AC 1, `4-0/R2`): the hand's WIDTH is established at the DEAL SEAT and nowhere else.
## `Hand` never learns of BalanceConfig, never holds a config reference and never names
## `hand_size` — the seat reads `balance.hand_size` INLINE at the moment of use (CONSTRAINT C)
## and passes the width in. This is what keeps a never-dealt Hand at width 0 without a special
## case, and it is what stops a hot balance reload from half-applying to a hand already in flight.
##
## Guarded structurally rather than trusted to review, because the tempting shortcut — caching a
## BalanceConfig on the container so it can size itself — would violate CONSTRAINT C silently and
## still pass every behavioural test in this suite.
func test_hand_never_names_hand_size_or_the_balance_config() -> void:
	var banned := ["hand_size", "BalanceConfig", "BalanceTicks", "BalanceConfigService"]
	var offenders: Array[String] = []
	var n := 0
	var lines := 0
	for line in _code_lines("res://src/state/hand.gd"):
		n += 1
		lines += 1
		for token in banned:
			if line.contains(token):
				offenders.append("hand.gd:%d %s" % [n, line.strip_edges()])
	assert_true(lines > 0, "hand.gd scan read no code lines (guard would be vacuous)")
	assert_eq(offenders.size(), 0,
		"Hand must not name hand_size or any balance type — the WIDTH arrives from the deal seat "
		+ "(`4-0/R2`, CONSTRAINT C): %s" % ", ".join(offenders))
	# ...and the seat really does pass one in, read inline. The other half of the same rule.
	var seat := false
	for line in _code_lines("res://src/state/match_state.gd"):
		if line.contains("player.hand.clear(balance.hand_size)"):
			seat = true
	assert_true(seat,
		"_deal_player must establish the width with `hand.clear(balance.hand_size)`, reading the "
		+ "authored value INLINE rather than from a cached config (CONSTRAINT C)")


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
