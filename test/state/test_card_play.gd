extends TestCase

## Story 3-5a: Mode ① card play — the cast gate, the one-tick resolution, the discard, and the
## two refusal contracts (LIVE-tick rejection through the shipped seam; SILENT drop on a frozen
## or DEAD tick).
##
## Fixture shape: every card costs the SAME 3.0 mana, so no test has to predict which id the
## shuffle put in which slot — the arithmetic is identical whichever card is cast. Counts are
## chosen distinct from each other (deck 8, hand 4, cost 3.0, mana 10.0) so an off-by-one that
## read the wrong quantity lands on a different number instead of coinciding with one.

const SEED := 4242
const DECK_SIZE := 8
const HAND_SIZE := 4
const CARD_COST := 3.0
const START_MANA := 10.0


# --- AC 5: one-tick Basic resolution --------------------------------------------------------

## The whole of AC 5 in one tick, asserted as four separate facts because they are four separate
## mutations and a partial resolution must not read as a pass: the mana is spent, the card leaves
## the hand, it lands in the discard, and a replacement is drawn IMMEDIATELY.
##
## STILL TRUE AFTER STORY 3-5b, and deliberately so. 3-5b replaces the instant refill with a timer
## plus a debt — but this fixture's `_config()` authors no `draw_replacement_delay_seconds`, so
## the delay derives to ZERO ticks and the delivery fires inside the cast tick. That is 3-5b's own
## ruled degrade (AC 3, "unless the derived delay is zero ticks"), and keeping this test green at
## a zero price is what proves the degrade is exact rather than approximately similar.
func test_basic_cast_spends_discards_and_refills_in_one_tick() -> void:
	var ms := _make_match()
	var before_hand := ms.p1.hand.to_array()
	var played_expected: StringName = before_hand[1]
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(ms.p1.mana.get_current(), START_MANA - CARD_COST,
		"the price was spent through the pool (10.0 - 3.0)")
	assert_false(ms.p1.hand.occupied_ids().has(played_expected),
		"the cast card LEFT the hand — slot 1's id is gone")
	assert_eq(ms.p1.discard.to_array(), [played_expected] as Array[StringName],
		"...and landed in the discard, that card and only that card")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE,
		"INSTANT refill: the hand is back to full on the SAME tick (AC 5, no delay)")
	# Story 4-0 (AC 4): and the refill landed in SLOT 1 — the slot the cast vacated — not at the
	# end. At a zero derived delay the vacate and the refill happen inside one tick, so this is
	# the tightest possible statement of the story: the slot never observably held a hole, and
	# every other slot is byte-for-byte what it was.
	assert_false(ms.p1.hand.is_slot_empty(1), "slot 1 was refilled in place")
	var after_hand := ms.p1.hand.to_array()
	for i in HAND_SIZE:
		if i == 1:
			continue
		assert_eq(after_hand[i], before_hand[i],
			"slot %d is byte-for-byte unchanged by a cast of slot 1 (AC 1)" % i)
	assert_eq(ms.p1.deck.size(), DECK_SIZE - HAND_SIZE - 1,
		"the replacement came off the deck (4 dealt, 1 drawn -> 3 left)")


## The seam AC 5 names, pinned as an actual emission with its payload — a resolution that mutated
## the containers but queued nothing would leave the E4+ consumer with no event to bind to.
## Queued per D5: nothing fires until drain_signals().
func test_basic_cast_queues_the_resolution_signal() -> void:
	var ms := _make_match()
	var seen: Array = []
	ms.card_cast_resolved.connect(func(slot: int, id: StringName) -> void: seen.append([slot, id]))
	var expected: StringName = ms.p1.hand.to_array()[0]
	var intents: Array[InputIntent] = [_cast_intent(0), InputIntent.new()]
	ms.advance(intents)
	assert_eq(seen.size(), 0, "queued, not fired mid-advance (D5)")
	ms.drain_signals()
	assert_eq(seen, [[0, expected]], "fires once on drain, carrying the casting slot and the card")


## The conservation property the third container has to satisfy: nothing is invented and nothing
## is lost. deck + hand + discard must stay a permutation of the injected composition across a
## cast — the failure mode a remove-without-discard (or a discard-without-remove) produces.
##
## STORY 3-5b (AC 11) ADDS THE FOURTH TERM: **deck + hand + discard + in-flight**. The first three
## stay a PERMUTATION — the replacement is drawn AT DELIVERY, so a pending draw holds no card in
## limbo and invents none — and the fourth is a COUNT that closes the HAND: while a draw is owed
## the hand is one short, and `hand + owed == hand_size` is what records that. On THIS fixture the
## derived delay is zero (see _config), so the term is settled inside each cast tick; it is
## exercised with a live debt in test_draw_delay_and_reshuffle.gd, across a reshuffle and across
## the both-empty degrade.
func test_cast_conserves_the_injected_multiset() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(2), InputIntent.new())
	_advance(ms, _cast_intent(0), InputIntent.new())
	var all: Array[StringName] = []
	all.append_array(ms.p1.deck.to_array())
	all.append_array(ms.p1.hand.occupied_ids())
	all.append_array(ms.p1.discard.to_array())
	all.sort()
	var expected := _deck_contents()
	expected.sort()
	assert_eq(all, expected,
		"deck + hand + discard is a permutation of the injected composition after two casts")
	assert_eq(ms.p1.discard.size(), 2, "both casts reached the discard")
	assert_eq(ms.p1.hand.occupied_count() + ms.p1.pending_draw_owed.size(), HAND_SIZE,
		"the IN-FLIGHT term closes the hand: occupied + owed == hand_size (3-5b AC 11, re-pointed "
		+ "to occupancy by `4-0/R1` — bound to WIDTH this identity would invert)")


## The debug reset restores the FULL composition to the deck, so the discard must be emptied with
## the hand or the conservation property above breaks on the first reset after a cast.
func test_debug_reset_empties_the_discard() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(0), InputIntent.new())
	assert_eq(ms.p1.discard.size(), 1, "sanity: a card is in the discard before the reset")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.discard.size(), 0, "the reset emptied the discard")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE, "...and re-dealt a full hand")
	assert_eq(ms.p1.deck.size(), DECK_SIZE - HAND_SIZE, "...from the full composition")


# --- AC 7: LIVE-tick rejection through the SHIPPED seam --------------------------------------

## AC 7: an unaffordable cast is refused through the ALREADY-SHIPPED action_rejected signal —
## the same per-slot seam that carries the insufficient-stamina roll rejection — with a card
## action name and a reason token. No new signal and no new seam: this test binds the EXISTING
## one. Nothing may move: an unaffordable cast that still discarded the card would be worse than
## one that did nothing.
func test_unaffordable_cast_is_rejected_through_the_shipped_seam() -> void:
	var ms := _make_match(1.0)  # 1.0 mana against a 3.0 price
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	_advance(ms, _cast_intent(0), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_INSUFFICIENT_MANA]],
		"refused on the shipped action_rejected seam with a card action name and a reason")
	assert_eq(ms.p1.mana.get_current(), 1.0, "nothing was spent")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE, "the card stayed in the hand")
	assert_eq(ms.p1.discard.size(), 0, "nothing reached the discard")


## A commit with NO slot armed (the resting -1) is a refusal, not a silent cast of slot 0 — the
## failure mode a `card_slot` defaulting to 0 would produce, which would make a stray confirm
## press throw away a card.
func test_commit_with_no_armed_slot_is_rejected() -> void:
	var ms := _make_match()
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	var intent := InputIntent.new()
	intent.card_commit = true  # card_slot left at its resting -1
	_advance(ms, intent, InputIntent.new())
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_EMPTY_SLOT]],
		"a commit with nothing armed is refused, never a cast of slot 0")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE, "the hand is untouched")


## A slot beyond the hand is the same refusal. Pinned separately from the -1 case because they
## reach the bound from opposite sides and a one-sided check would pass one of them.
func test_out_of_range_slot_is_rejected() -> void:
	var ms := _make_match()
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	_advance(ms, _cast_intent(HAND_SIZE), InputIntent.new())  # one past the last slot
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_EMPTY_SLOT]],
		"a slot past the end of the hand is refused")
	assert_eq(ms.p1.discard.size(), 0, "nothing was played")


## No commit, no cast. The armed slot alone must never resolve anything — arming is a controller
## affordance and only the commit edge is a cast.
func test_arming_without_committing_casts_nothing() -> void:
	var ms := _make_match()
	var intent := InputIntent.new()
	intent.card_slot = 0  # armed but NOT committed
	_advance(ms, intent, InputIntent.new())
	assert_eq(ms.p1.mana.get_current(), START_MANA, "no spend")
	assert_eq(ms.p1.discard.size(), 0, "no discard — arming is not casting")


# --- AC 8: the DEAD and FROZEN contracts -----------------------------------------------------

## AC 8, first half: a DEAD player cannot cast, and the refusal is SILENT — a corpse gets no
## rejection feedback, matching the DEAD branches at steps 3, 4 and 5, none of which signal.
##
## Uses the established forced-DEAD idiom (`set_action_state(DEAD)` with _round_over left FALSE),
## because DEAD and _round_over are set TOGETHER by _end_round and the step-1b freeze would
## otherwise return before step 6 — the guard is defense in depth in exactly the same family as
## its step-3/4/5 siblings, and this is how each of those is pinned too.
##
## MUTATION: delete the DEAD check in _resolve_card_action and this FAILS — the corpse casts.
func test_dead_player_cannot_cast() -> void:
	var ms := _make_match()
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)  # forced DEAD; _round_over stays FALSE
	_advance(ms, _cast_intent(0), InputIntent.new())
	assert_eq(ms.p1.mana.get_current(), START_MANA, "a corpse spends nothing")
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE, "a corpse plays no card")
	assert_eq(ms.p1.discard.size(), 0, "nothing reached the discard")
	assert_eq(rejections, [], "and it is SILENT — the DEAD family signals nothing")


## AC 8, second half, and the ruled frozen-tick contract: a cast committed on a round-over frozen
## tick is DROPPED SILENTLY — no state change AND no signal, explicitly including no
## action_rejected. Both halves are asserted because a test that only checked state would pass
## against an accidental emission, which is exactly the silent-swallow guard being non-vacuous.
##
## This is consistent with every other intent during the freeze: step 1b returns before step 2,
## so nothing is ingested at all and attack/block/roll are dropped the same way.
##
## MUTATION: delete the `return` in step 1b and this FAILS — the cast resolves on a frozen tick.
func test_cast_on_a_frozen_tick_is_dropped_silently() -> void:
	var ms := _make_match()
	ms.p2.hero.take_damage(999.0)
	_advance(ms, InputIntent.new(), InputIntent.new())  # the kill tick — round is now over
	assert_true(bool(ms.to_snapshot()["round_over"]), "sanity: the round really is frozen")
	# `tick` is EXCLUDED from the comparison, and only `tick`: frozen ticks still advance the
	# counter by design (step 1b increments before it returns, so a reset landing on tick N stays
	# deterministic — 2-6/R6). Everything else must be bit-identical.
	var before := ms.to_snapshot()
	before.erase("tick")
	var signals: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: signals.append([action, reason]))
	ms.card_cast_resolved.connect(
		func(slot: int, id: StringName) -> void: signals.append([slot, id]))
	_advance(ms, _cast_intent(0), InputIntent.new())
	var after := ms.to_snapshot()
	after.erase("tick")
	assert_eq(after, before,
		"NO state change: the snapshot is bit-identical across the frozen tick (tick aside)")
	assert_eq(signals, [], "NO signal — not a resolution and not even a rejection")


# --- AC 2: the guarded stubs -----------------------------------------------------------------

## Story 5-2 (AC 9, `5-2/R8`): the modes that have a REAL resolution arm in
## `MatchState._resolve_card_action`, and therefore may legally be named in `src/`. Everything else
## is a guarded stub and the scan below fails on it.
const REACHABLE_MODES: Array[String] = ["BASIC", "UNBLOCKABLE"]


## AC 2's negative-path test: the modes beyond Basic are UNREACHABLE in E3.
##
## Proven by SOURCE SCAN rather than by calling the stub, deliberately: the stub is an
## `Invariant.check(false, ...)`, which routes through assert() and PRINTS AND CONTINUES at exit 0
## (3-0c/R15) rather than aborting — so run_all.sh's grep gate, not a process crash, is what would
## turn calling the stub into a suite failure, and for the wrong reason (a deliberate trigger, not
## a genuine defect). The reachability question is "can anything in src/ ever put an
## UNREACHABLE mode value on an intent" — and that is exactly what this scans for.
##
## NARROWED BY STORY 5-2 (AC 9, `5-2/R8`) -- THE ONE DELIBERATE PIN EDIT OF THAT STORY, and it is
## FORCED rather than chosen: `5-2` gives `UNBLOCKABLE` a real resolution arm in
## `MatchState._resolve_card_action`, which trips this scan the instant it lands. The guard is
## NARROWED, never deleted and never weakened past the one mode that shipped: `DEFENSE` (mode 3, a
## `5-5` story) and `PITCH` (mode 4, E6) still FAIL here, and the test's job is unchanged -- it
## still answers "can anything in src/ put an UNREACHABLE mode on an intent", against a set of
## unreachable modes that is now two instead of three.
##
## DO NOT CONFLATE THIS WITH `5-2`'s OTHER PIN (`5-2/R8` says so in as many words). Two different
## tests were in play for two different reasons: `test_action_state.gd:82-95`'s
## zero-inbound-CHARGING assertion was EXPECTED to move and does NOT (entry is a direct
## `set_action_state` at the cast seat, so `TRANSITION_TABLE` gains no row -- AC 7/AC 8), while
## THIS one was not named at authoring time and must.
##
## MUTATION: write `Enums.ModeKind.PITCH` (or `.DEFENSE`) anywhere under src/ and this FAILS.
func test_only_shipped_modes_are_reachable() -> void:
	var re := RegEx.create_from_string("Enums\\.ModeKind\\.([A-Z_]+)")
	var offenders: Array[String] = []
	var scanned := 0
	var references := 0
	for path in _gd_files("res://src/"):
		scanned += 1
		var n := 0
		for line in _code_lines(path):
			n += 1
			for m in re.search_all(line):
				references += 1
				if not REACHABLE_MODES.has(m.get_string(1)):
					offenders.append("%s:%d %s" % [path, n, line.strip_edges()])
	assert_true(scanned > 0, "the scan must actually visit files")
	assert_true(references > 0,
		"src/ must REFERENCE ModeKind somewhere — otherwise this guard is vacuous")
	assert_eq(offenders.size(), 0,
		"an UNREACHABLE mode is authored in src/ (DEFENSE is `5-5`'s, PITCH is E6's, and both are "
		+ "still guarded stubs): %s" % ", ".join(offenders))


## The other half of the narrowing, asserted rather than left implicit: the permitted set is
## EXACTLY the two modes that have shipped a resolution arm. A story that widened this list without
## shipping the arm would be caught by `test_the_mode_dispatch_carries_a_guard` below; a story that
## shipped an arm without widening it is caught by the scan above. This assertion is what keeps the
## list itself from quietly growing to four and turning the scan vacuous.
func test_the_reachable_mode_set_is_exactly_basic_and_unblockable() -> void:
	assert_eq(REACHABLE_MODES, ["BASIC", "UNBLOCKABLE"] as Array[String],
		"exactly TWO of the four modes resolve today: BASIC (3-5a) and UNBLOCKABLE (5-2). "
		+ "Widening this list is how a mode becomes reachable, and it may only be widened by the "
		+ "story that ships that mode's resolution arm")


## STORY 4-0 (AC 7, second part): the ORDER of the two lines is PINNED, by content. The hole is
## refused at the empty-slot guard BEFORE `_card_costs.get(id)` is ever reached, which is what
## makes "a hole is never evaluated for affordability" true on the STATE side BY CONSTRUCTION
## rather than by a map lookup that happens to miss. AC 7's HUD half is a forward constraint on
## the first story to render cost or greying; this half ships now and is guarded now.
##
## Pinned as an ordering rather than as a behaviour because the behaviour (no mana spent on a
## refused hole) is already asserted live in test_draw_delay_and_reshuffle.gd — this catches the
## refactor that keeps the refusal but moves the lookup above it, where a future affordability
## read would silently start consulting the marker.
func test_the_empty_slot_guard_precedes_the_cost_lookup() -> void:
	var guard_line := -1
	var lookup_line := -1
	var n := 0
	for line in _code_lines("res://src/state/match_state.gd"):
		n += 1
		if guard_line < 0 and line.contains("player.hand.is_slot_empty(hand_slot)"):
			guard_line = n
		if lookup_line < 0 and line.contains("_card_costs.get(id)"):
			lookup_line = n
	assert_true(guard_line > 0,
		"_resolve_basic_cast must refuse an empty slot via Hand.is_slot_empty — the single test "
		+ "that folds the WIDTH bound and the hole into ONE reason (AC 3)")
	assert_true(lookup_line > 0, "...and must still look the cost up (guard would be vacuous)")
	assert_true(guard_line < lookup_line,
		"the empty-slot guard must come BEFORE the cost lookup (%d vs %d): a hole must never "
		% [guard_line, lookup_line]
		+ "reach the cost map at all (AC 7)")


## The stub branch must actually EXIST — the other half of the guard above, which would pass
## vacuously against a dispatch that silently ignored an unknown mode instead of refusing it.
func test_the_mode_dispatch_carries_a_guard() -> void:
	# Two tokens on two lines — the guard is written across a call and its message string, and
	# _code_lines strips comments, so both halves are asserted separately rather than on one line.
	var has_check := false
	var has_message := false
	for line in _code_lines("res://src/state/match_state.gd"):
		if line.contains("Invariant.check(false"):
			has_check = true
		if line.contains("guarded stub"):
			has_message = true
	assert_true(has_check,
		"match_state.gd's mode dispatch must guard its non-BASIC branch with Invariant.check(false")
	assert_true(has_message, "...and say what it is guarding")


# --- AC 4: the injection seam ----------------------------------------------------------------

## AC 4: the cost map never reaches the snapshot. The hard constraint underneath this is that its
## StringName KEYS must never enter the hash — Array[StringName].sort() orders by internal
## POINTER on this engine, so a StringName key would hash deterministically within one process
## while replay was already broken across runs, and no in-process test could catch it.
func test_injected_costs_never_reach_the_snapshot() -> void:
	var ms := _make_match()
	var text := str(ms.to_snapshot())
	for id in _deck_contents():
		assert_false(text.contains(str(id)),
			"card id %s must not appear anywhere in the snapshot (counts only)" % id)
	assert_true(ms.to_snapshot()["p1"].has("discard_size"),
		"the snapshot carries the discard COUNT and nothing else about the pile")


## AC 6: the ONE new snapshot key, and it is a COUNT. Pinned by name and by type so a later story
## cannot quietly widen it into ids or per-card structure.
func test_snapshot_gains_exactly_the_discard_count() -> void:
	var ms := _make_match()
	var p1: Dictionary = ms.to_snapshot()["p1"]
	assert_true(p1["discard_size"] is int, "discard_size is an int COUNT, not a list")
	assert_eq(p1["discard_size"], 0, "empty before any cast")
	_advance(ms, _cast_intent(0), InputIntent.new())
	assert_eq(int(ms.to_snapshot()["p1"]["discard_size"]), 1, "and it counts the played card")


## AC 4: both seam checks are still THERE, on the condition they exist for.
##
## Their FIRING cannot be tested — Invariant.check routes through assert(), which PRINTS AND
## CONTINUES at exit 0 rather than aborting (3-0c/R15), and run_all.sh greps for "INVARIANT
## VIOLATED" so a deliberately triggered one would fail the suite for the wrong reason. What IS
## provable is presence at the seam: delete either and this fails. The mechanism and this reasoning
## are inherited verbatim
## from test_deck_and_hand.gd::test_injection_seam_rejects_an_empty_injected_deck.
##
## Declared honestly in the dev record as NOT mutation-proven in the firing sense.
func test_cost_injection_seam_keeps_both_guards() -> void:
	var in_seam := false
	var seam_found := false
	var non_empty_guard := false
	var totality_guard := false
	for line in _code_lines("res://src/state/match_state.gd"):
		if line.begins_with("func inject_card_costs("):
			in_seam = true
			seam_found = true
			continue
		if in_seam and line.begins_with("func "):
			break
		if in_seam and line.contains("Invariant.check") and line.contains("is_empty()"):
			non_empty_guard = true
		if in_seam and line.contains("Invariant.check") and line.contains("costs.has("):
			totality_guard = true
	assert_true(seam_found,
		"match_state.gd must still declare inject_card_costs (a rename un-guards this)")
	assert_true(non_empty_guard,
		"inject_card_costs must Invariant.check that the injected map is non-empty")
	assert_true(totality_guard,
		"inject_card_costs must Invariant.check that the map is TOTAL over the composition")


# --- helpers ---------------------------------------------------------------------------------

func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("play_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CARD_COST
		out[id] = c
	return out


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_mana = 90.0
	c.max_stamina = 40.0
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	return c


## A match with a dealt hand and mana on the board. The deal happens at step 6 of the FIRST
## advance(), so one tick is run here and the mana is granted after it — the pool starts empty by
## ManaPool's own contract and the flywheel is not what these tests are exercising.
func _make_match(mana := START_MANA) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	ms.p1.mana.add(mana)
	ms.p2.mana.add(mana)
	ms.drain_signals()
	return ms


func _cast_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()


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
