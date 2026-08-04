extends TestCase

## Story 3-5b: the delayed replacement draw, deck exhaustion, the lazy reshuffle and the
## vulnerable window. The pure-state half — the timer plus debt counter, the step-2 tick /
## step-6 delivery split, the reshuffle inside the one existing RNG seat, and the four contracts
## the story rules around the edges (death, the frozen tick, the debug reset, both piles empty).
##
## REFRAME, and it is the thing to hold onto while reading these tests (`3-5b/R1`): exhaustion
## was ALREADY REACHABLE in shipped 3-5a code — `_resolve_basic_cast` drew a replacement on every
## cast and stopped silently at `is_empty()`, so the hand shrank below full and never recovered.
## This story REPLACES that silent floor. The delay does not make the pile run out; it changes
## WHEN the replacement arrives, and the reshuffle is what gives the floor a way back up.
##
## Headless like every state test: RefCounted objects built directly, no autoload, no frame. Deck
## content is opaque in-test ids and balance is built in-test — data/cards/ and
## data/balance/*.tres are both unreachable from this harness by design, so a content or tuning
## edit can never break an assertion here.
##
## FIXTURE SHAPE. Every card costs the same 1.0 mana, so no test has to predict which id the
## shuffle put in which slot. The counts are chosen DISTINCT from one another (deck 10, hand 4,
## pile 6, delay 4 ticks, reload delay 9 ticks, vulnerable window 7 ticks) so an off-by-one that
## read the wrong quantity lands on a different number instead of coinciding with one.

const SEED := 4242
const DECK_SIZE := 10
const HAND_SIZE := 4
## What the deal leaves in the pile, and therefore how many casts drain it. Named rather than
## repeated so the exhaustion tests say what they mean.
const PILE := DECK_SIZE - HAND_SIZE
const CARD_COST := 1.0
const START_MANA := 80.0
const DELAY_TICKS := 4
## AC 15's reload value — deliberately different from DELAY_TICKS in BOTH directions of the
## comparison it feeds (an in-flight window must keep 4, the next start() must pick up 9).
const RELOAD_DELAY_TICKS := 9
const VULNERABLE_TICKS := 7

## AC 4: the exact key set PlayerState.to_snapshot() emits after this story, sorted. Two keys are
## NEW here; the other seven are its predecessors'. Pinned as a literal so a third key cannot
## ship quietly — that is the whole job of this constant.
const EXPECTED_PLAYER_SNAPSHOT_KEYS: Array[String] = [
	"deck_size", "discard_size", "hand_size", "hero", "mana", "orbs",
	"pending_draw", "pending_draw_owed", "stamina",
]

## The all-zero TimingWindow snapshot — a window that was never started, and equally a window the
## debug reset killed. Named because three tests compare against it.
const IDLE_WINDOW := {"duration_ticks": 0, "elapsed_ticks": 0, "is_running": false}


# --- AC 3: the timer, the debt, and the step-2 / step-6 split --------------------------------

## The core of AC 3 in one test, in both directions: the replacement is NOT drawn on the cast
## tick, it is still absent one tick before the authored delay, and it arrives ON it. A test that
## only checked "it eventually arrives" would pass against an instant draw.
func test_the_replacement_arrives_at_the_authored_tick_and_not_one_tick_earlier() -> void:
	var ms := _make_match()
	_cast(ms)
	assert_eq(ms.p1.hand.size(), HAND_SIZE - 1,
		"the replacement is NOT drawn on the cast tick — the hand is one short")
	assert_eq(ms.p1.deck.size(), PILE, "...and the pile has not been touched")
	assert_eq(ms.p1.discard.size(), 1, "the card itself still left the hand on the cast tick")
	assert_eq(ms.p1.pending_draw_owed, 1, "one replacement is OWED")
	assert_true(ms.p1.pending_draw.is_running, "...and its window is in flight")
	for _t in DELAY_TICKS - 1:
		_tick(ms)
	assert_eq(ms.p1.hand.size(), HAND_SIZE - 1, "still short ONE TICK before the authored delay")
	assert_eq(ms.p1.pending_draw_owed, 1)
	_tick(ms)
	assert_eq(ms.p1.hand.size(), HAND_SIZE, "the card arrives ON the authored tick")
	assert_eq(ms.p1.deck.size(), PILE - 1, "...off the pile")
	assert_eq(ms.p1.pending_draw_owed, 0, "and the debt is settled")
	assert_false(ms.p1.pending_draw.is_running, "the window is not restarted with nothing owed")


## A derived delay of ZERO ticks degrades EXACTLY to 3-5a's instant refill. This is the property
## the golden's cause C3(a) rests on — the mechanism priced at zero must be indistinguishable
## from the behaviour it replaced — and it is what makes the delivery's seat (after the cast
## dispatch, inside step 6) load-bearing rather than arbitrary: seated before it, a zero-delay
## replacement would arrive one tick LATE.
func test_a_zero_derived_delay_degrades_to_the_instant_refill() -> void:
	var ms := _make_match(0)
	assert_eq(ms.balance_ticks.draw_replacement_delay_ticks, 0, "sanity: the delay derives to 0")
	_cast(ms)
	assert_eq(ms.p1.hand.size(), HAND_SIZE,
		"0 ticks -> the replacement arrives on the CAST TICK, exactly as 3-5a drew it")
	assert_eq(ms.p1.deck.size(), PILE - 1, "the pile paid for it in the same tick")
	assert_eq(ms.p1.pending_draw_owed, 0, "the debt was settled inside the same advance()")
	assert_eq(ms.p1.to_snapshot()["pending_draw"], IDLE_WINDOW,
		"and nothing is left in flight to hash")


## AC 3's second pinned direction: several draws in flight deliver ONE CARD PER EXPIRY, never a
## batch. Also pins "hand_size is permitted to reach 0" — the hand really is allowed to empty,
## which is what makes the debt counter (rather than a boolean) necessary.
func test_four_casts_in_flight_deliver_four_cards_one_per_expiry() -> void:
	var ms := _make_match()
	for _i in HAND_SIZE:
		_cast(ms)
	assert_eq(ms.p1.hand.size(), 0, "hand_size is PERMITTED to reach 0 (AC 3)")
	assert_eq(ms.p1.discard.size(), HAND_SIZE, "every card played reached the discard")
	assert_eq(ms.p1.pending_draw_owed, HAND_SIZE, "four debts — a COUNT, not a queue of cards")
	var arrivals: Array[int] = []
	for _t in DELAY_TICKS * (HAND_SIZE + 1):
		var before := ms.p1.hand.size()
		_tick(ms)
		if ms.p1.hand.size() > before:
			assert_eq(ms.p1.hand.size(), before + 1, "exactly ONE card per delivery, never a batch")
			arrivals.append(ms.p1.hand.size())
	assert_eq(arrivals, [1, 2, 3, 4], "four cards, one per expiry, in order")
	assert_eq(ms.p1.pending_draw_owed, 0)
	assert_eq(ms.p1.deck.size(), PILE - HAND_SIZE, "all four came off the pile")


## AC 3: NO new rejection reason and NO new refusal path ships — mana remains the only throttle.
## A cast committed with a draw already in flight resolves normally and simply owes a second one.
## MUTATION: gate _resolve_basic_cast on `pending_draw_owed == 0` and this FAILS in both halves.
func test_a_cast_is_not_gated_on_a_pending_draw() -> void:
	var ms := _make_match()
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: rejections.append([action, reason]))
	_cast(ms)
	_cast(ms)
	assert_eq(rejections, [],
		"no rejection — a pending draw gates nothing, and no new reason token ships")
	assert_eq(ms.p1.discard.size(), 2, "the second cast resolved with a draw still in flight")
	assert_eq(ms.p1.pending_draw_owed, 2, "...and simply owed a second replacement")


# --- AC 4: the snapshot ----------------------------------------------------------------------

## AC 4: the key set is EXACTLY the expected set. Asserting the whole set (rather than "has the
## two new keys") is the only form that catches a THIRD key shipping quietly — including the
## vulnerable window, which is deliberately NOT hashed (see PlayerState for why: nothing reads
## it, so it cannot change an outcome or desync a replay).
func test_the_player_snapshot_key_set_is_exactly_the_expected_set() -> void:
	var ms := _make_match()
	var keys: Array = ms.p1.to_snapshot().keys()
	keys.sort()
	assert_eq(keys, EXPECTED_PLAYER_SNAPSHOT_KEYS,
		"PlayerState.to_snapshot() gained exactly pending_draw and pending_draw_owed")
	assert_false(keys.has("vulnerable_window"),
		"the vulnerable window is NOT a snapshot key — nothing reads it, so nothing can desync on it")


## The two new keys' SHAPES, pinned by value across a cast: the window rides as the shipped
## TimingWindow.to_snapshot() dictionary (the StaminaPool regen_delay precedent) and the debt
## rides as a plain int COUNT. No card identity in either — the failure mode a StringName in the
## hash produces is silent and un-catchable in-process (Array[StringName].sort() orders by
## internal POINTER on this engine).
func test_the_pending_draw_keys_carry_a_window_and_an_int_debt_only() -> void:
	var ms := _make_match()
	var before: Dictionary = ms.p1.to_snapshot()
	assert_eq(before["pending_draw"], IDLE_WINDOW, "idle before any cast")
	assert_true(before["pending_draw_owed"] is int, "the debt is a plain int COUNT")
	assert_eq(before["pending_draw_owed"], 0)
	_cast(ms)
	var after: Dictionary = ms.p1.to_snapshot()
	assert_eq(after["pending_draw"],
		{"duration_ticks": DELAY_TICKS, "elapsed_ticks": 0, "is_running": true},
		"the window is snapshotted mid-flight — it CROSSES tick boundaries, which is why it is hashed")
	assert_eq(after["pending_draw_owed"], 1)
	var text := str(after)
	for id in _deck_contents():
		assert_false(text.contains(str(id)),
			"no card IDENTITY enters the snapshot through the new keys (%s)" % id)


# --- AC 5 / AC 6: exhaustion, the lazy reshuffle, and the vulnerable window -------------------

## The story's central replacement: the pile really does run down, and the delivery that finds it
## empty folds the discard back in instead of stopping silently. Pinned in stages so a partial
## implementation cannot read as a pass — the pile empties, the hand is STILL full at that point
## (every draw was served), and only the NEXT delivery reshuffles.
func test_a_delivery_from_an_empty_deck_reshuffles_this_players_discard() -> void:
	var ms := _make_match()
	for _i in PILE:
		_cast_and_settle(ms)
	assert_eq(ms.p1.deck.size(), 0, "the pile is EMPTY — the floor 3-5a shipped, reached")
	assert_eq(ms.p1.discard.size(), PILE, "...and every drawn card's predecessor is in the discard")
	assert_eq(ms.p1.hand.size(), HAND_SIZE, "the hand is still full: no draw was refused on the way")
	_cast(ms)
	assert_eq(ms.p1.discard.size(), PILE + 1, "the seventh cast lands with nothing to draw from")
	assert_eq(ms.p1.deck.size(), 0, "and the reshuffle is LAZY — nothing happens at deck_size == 0")
	for _t in DELAY_TICKS:
		_tick(ms)
	assert_eq(ms.p1.discard.size(), 0, "at DELIVERY time the discard was folded back into the deck")
	assert_eq(ms.p1.deck.size(), PILE, "...and the delivery then drew from it (7 in, 1 out)")
	assert_eq(ms.p1.hand.size(), HAND_SIZE, "so the hand came back to full")
	assert_eq(ms.p1.pending_draw_owed, 0)


## AC 5 / the golden's cause C4 REVERSE HALF, and the story says it is required: C4 claims
## rng_state is a non-mover for the recorded cast, which is a vacuous claim unless a reshuffle is
## shown to MOVE it somewhere. Both directions in one test — a plain delivery draw consumes
## nothing (draw_top takes no generator), the reshuffle consumes the seeded RNG.
func test_a_reshuffle_moves_rng_state_and_a_plain_delivery_draw_does_not() -> void:
	var ms := _make_match()
	var before_plain: Variant = ms.to_snapshot()["rng_state"]
	_cast_and_settle(ms)
	assert_eq(ms.p1.hand.size(), HAND_SIZE, "sanity: that delivery really drew a card")
	assert_eq(ms.to_snapshot()["rng_state"], before_plain,
		"a PLAIN delivery draw consumes NO rng — draw_top() takes no generator")
	for _i in PILE - 1:
		_cast_and_settle(ms)
	assert_eq(ms.p1.deck.size(), 0, "sanity: the pile is empty and the next delivery must reshuffle")
	var before_reshuffle: Variant = ms.to_snapshot()["rng_state"]
	_cast_and_settle(ms)
	assert_ne(ms.to_snapshot()["rng_state"], before_reshuffle,
		"the RESHUFFLE consumed the seeded generator — inside advance(), in the one step-6 seat (F2)")


## AC 6: the window opens on the reshuffling player and the event is QUEUED (D5), not emitted
## mid-advance, carrying that player's slot index. Pinned at three separate moments so an
## emission that fired early (at exhaustion, or at the cast) cannot pass.
func test_the_reshuffle_opens_the_window_and_queues_the_owner_slot_event() -> void:
	var ms := _make_match()
	var seen: Array = []
	ms.reshuffle_vulnerable_window_opened.connect(func(slot: int) -> void: seen.append(slot))
	for _i in PILE:
		_cast_and_settle(ms)
	assert_eq(seen, [], "the pile emptying is not the event — nothing has drawn from empty yet")
	assert_false(ms.p1.vulnerable_window.is_running, "and no window is open")
	_cast(ms)
	for _t in DELAY_TICKS - 1:
		_tick(ms)
	assert_eq(seen, [], "...and not on the cast either — only the DELIVERY reshuffles")
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	assert_eq(seen, [], "queued, not fired mid-advance (D5)")
	ms.drain_signals()
	assert_eq(seen, [0], "fires ONCE on drain, carrying the vulnerable player's slot index")
	assert_true(ms.p1.vulnerable_window.is_running, "the window is open on the reshuffling player")
	assert_eq(ms.p1.vulnerable_window.remaining_ticks(), VULNERABLE_TICKS,
		"...for the authored duration, read inline at the reshuffle (CONSTRAINT C)")
	assert_false(ms.p2.vulnerable_window.is_running, "...and on that player ALONE")


## AC 5: the reshuffle draws from THIS player's own discard only. P2 casts nothing at all here,
## so any leakage — a shared pile, an opponent read, a re-derivation from the injected
## composition — shows as a moved count on P2.
func test_a_reshuffle_touches_only_the_reshuffling_players_piles() -> void:
	var ms := _make_match()
	for _i in PILE + 1:
		_cast_and_settle(ms)
	assert_eq(ms.p1.discard.size(), 0, "sanity: P1 reshuffled")
	assert_eq(ms.p2.deck.size(), PILE, "P2's pile is untouched — it never cast and never drew")
	assert_eq(ms.p2.hand.size(), HAND_SIZE, "P2's hand is untouched")
	assert_eq(ms.p2.discard.size(), 0, "P2's discard is untouched")
	assert_eq(ms.p2.pending_draw_owed, 0, "P2 owes nothing")
	# And the reshuffled pile is exactly the cards P1 played — never a fresh composition off the
	# injected content, which would invent cards P1 had not yet cycled through.
	var p1_all := ms.p1.deck.to_array()
	p1_all.append_array(ms.p1.hand.to_array())
	p1_all.append_array(ms.p1.discard.to_array())
	p1_all.sort()
	var expected := _deck_contents()
	expected.sort()
	assert_eq(p1_all, expected, "P1 still holds exactly the injected multiset, no more and no less")


# --- AC 7: death drops the DELIVERY, never the window ----------------------------------------

## AC 7 / 1-9/R3, which stays locked: NO early-stop path ships. A DEAD player's in-flight window
## ticks out NORMALLY and the delivery is discarded at step 6 — the 1-9/R1 fact-drop idiom
## applied literally. The debt is still consumed, so a player who came back would not be handed a
## backlog.
##
## Uses the repo's established forced-DEAD idiom (`set_action_state(DEAD)` with _round_over left
## FALSE), because DEAD and _round_over are set together by _end_round (3-5/R6) and the step-1b
## freeze would otherwise return before step 2. The guard is defense in depth in exactly the same
## family as the DEAD branches at steps 3, 4, 5 and 6, and this is how each of those is pinned.
##
## MUTATION: delete the DEAD check in _deliver_pending_draw and this FAILS — the corpse is dealt
## a card.
func test_a_dead_player_ticks_the_window_out_and_the_delivery_is_dropped() -> void:
	var ms := _make_match()
	_cast(ms)
	var deck_before := ms.p1.deck.size()
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)  # forced DEAD; _round_over stays FALSE
	for _t in DELAY_TICKS:
		_tick(ms)
	assert_false(ms.p1.pending_draw.is_running,
		"the window ticked out NORMALLY — it was never stopped or shortened (1-9/R3)")
	assert_eq(ms.p1.pending_draw_owed, 0, "the debt was consumed at the delivery")
	assert_eq(ms.p1.deck.size(), deck_before, "...but the DELIVERY was DROPPED — no card left the pile")
	assert_eq(ms.p1.hand.size(), HAND_SIZE - 1, "a corpse is not handed a card")


# --- AC 8: the frozen round-over tick ---------------------------------------------------------

## AC 8, stated explicitly rather than inherited silently: no window advances during the
## round-over freeze, because step 1b returns BEFORE step 2. Advancing MANY ticks (not one) is
## what makes this catch a seat that drifted below the freeze.
##
## MUTATION: move the pending-draw tick above the `if _round_over` return and this FAILS.
func test_the_pending_draw_window_does_not_tick_on_a_frozen_round_over_tick() -> void:
	var ms := _make_match()
	_cast(ms)
	ms.p2.hero.take_damage(999.0)
	_tick(ms)  # the KILL tick — still a live tick, so the window legitimately advances by one
	assert_true(bool(ms.to_snapshot()["round_over"]), "sanity: the round really is frozen")
	var frozen_at := ms.p1.pending_draw.remaining_ticks()
	assert_eq(frozen_at, DELAY_TICKS - 1, "sanity: exactly one live tick was spent")
	for _t in DELAY_TICKS * 3:
		_tick(ms)
	assert_eq(ms.p1.pending_draw.remaining_ticks(), frozen_at,
		"the window did not advance one tick across the whole freeze")
	assert_eq(ms.p1.pending_draw_owed, 1, "and nothing was ever delivered")
	assert_eq(ms.p1.hand.size(), HAND_SIZE - 1)


# --- AC 9: the debug reset kills a pending draw ------------------------------------------------

## AC 9: the reset KILLS the draw and the card is NOT restored — because it was never taken. The
## seat re-lays the full injected composition and clears the discard, so conservation is restored
## by construction and 3-3's AC 9 post-reset count pin stays green with no special case.
##
## MUTATION: delete the two kill lines in _deal_player and this FAILS — the debt survives the
## reset and delivers a card out of a freshly dealt pile.
func test_a_debug_reset_kills_a_pending_draw_and_keeps_the_post_reset_counts() -> void:
	var ms := _make_match()
	_cast(ms)
	_cast(ms)
	assert_eq(ms.p1.pending_draw_owed, 2, "sanity: two draws in flight")
	assert_true(ms.p1.pending_draw.is_running)
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.pending_draw_owed, 0, "the reset killed the DEBT")
	assert_false(ms.p1.pending_draw.is_running, "...and the window with it")
	assert_eq(ms.p1.to_snapshot()["pending_draw"], IDLE_WINDOW,
		"back to all-zeros, so a reset leaves nothing of the draw in the hash")
	assert_eq(ms.p1.hand.size(), HAND_SIZE, "3-3 AC 9's post-reset counts, unchanged by this story")
	assert_eq(ms.p1.deck.size(), DECK_SIZE - HAND_SIZE)
	assert_eq(ms.p1.discard.size(), 0)
	var all := ms.p1.deck.to_array()
	all.append_array(ms.p1.hand.to_array())
	all.sort()
	var expected := _deck_contents()
	expected.sort()
	assert_eq(all, expected, "conservation restored by construction — the full composition is back")
	# The reset must not leave the draw armed for a LATER tick either.
	for _t in DELAY_TICKS * 2:
		_tick(ms)
	assert_eq(ms.p1.hand.size(), HAND_SIZE, "no delayed delivery arrives after the reset")
	assert_eq(ms.p1.deck.size(), DECK_SIZE - HAND_SIZE)


# --- AC 10: deck AND discard both empty --------------------------------------------------------

## AC 10: a NO-OP DEGRADE, never a crash. No Invariant.check ships on this path — reachability
## depends on authored balance numbers, and a crash path reachable from authored data is not
## acceptable.
##
## THE CASE IS CONSTRUCTED DIRECTLY, and the story says it must be. Driving casts cannot reach it:
## with `d + h + c` conserved, a delivery finding `d == 0 and c == 0` requires `h` to hold the
## whole composition, which forces successful draws to exceed casts — impossible. So the degrade
## is UNREACHABLE in natural play, in the same family as the DEAD branches, and it is built by
## hand here exactly the way those are built by the forced-DEAD idiom. That is a stronger reason
## for the no-op than the story's own (a crash guard on an unreachable path is dead weight that
## would fire only after some later story made it reachable).
##
## MUTATION: replace the `discard.is_empty()` return with a draw and this FAILS on an index error.
func test_both_piles_empty_degrades_to_a_no_op_and_opens_no_window() -> void:
	var ms := _make_match()
	var signals: Array = []
	ms.reshuffle_vulnerable_window_opened.connect(func(slot: int) -> void: signals.append(slot))
	# Construct the case: both piles empty, one draw owed and due this tick.
	ms.p1.deck.set_contents([] as Array[StringName])
	ms.p1.discard.clear()
	ms.p1.pending_draw_owed = 1
	ms.p1.pending_draw.start(0)
	var hand_before := ms.p1.hand.size()
	_tick(ms)
	assert_eq(ms.p1.pending_draw_owed, 0, "the owed draw was CONSUMED — it does not retry forever")
	assert_eq(ms.p1.hand.size(), hand_before, "no card was invented — the hand simply stays short")
	assert_eq(ms.p1.deck.size(), 0)
	assert_eq(ms.p1.discard.size(), 0)
	assert_false(ms.p1.vulnerable_window.is_running,
		"NO vulnerable window opens — there was nothing to reshuffle")
	assert_eq(signals, [], "...and no event is announced")


# --- AC 11: the conservation property gains a fourth term --------------------------------------

## AC 11: **deck + hand + discard + in-flight**. The first three terms stay a PERMUTATION of the
## injected composition — the card is drawn at delivery, so nothing is held in limbo — and the
## fourth term is a COUNT that closes the HAND: `hand + owed == hand_size` while a draw is owed.
## Both halves are asserted, because the multiset half alone would pass against a delivery that
## never fired and the count half alone would pass against a card conjured out of nothing.
func test_conservation_holds_with_the_in_flight_term_across_a_reshuffle() -> void:
	var ms := _make_match()
	for _i in PILE:
		_cast_and_settle(ms)
	_cast(ms)  # the cast whose delivery must reshuffle — checked mid-flight and after
	_assert_conserved(ms, "with a draw in flight over an EMPTY pile")
	for _t in DELAY_TICKS:
		_tick(ms)
	assert_eq(ms.p1.discard.size(), 0, "sanity: the reshuffle happened")
	_assert_conserved(ms, "across the reshuffle")


## The same property over the AC 10 degrade, where the hand is legitimately SHORT and stays that
## way: the multiset is still whole (the missing cards are simply not in any pile) and the count
## identity is what records the shortfall. Constructed directly, for the reason AC 10's own test
## states.
func test_conservation_holds_across_the_both_empty_degrade() -> void:
	var ms := _make_match()
	for _i in HAND_SIZE:
		_cast(ms)
	assert_eq(ms.p1.hand.size(), 0, "sanity: the hand emptied")
	_assert_conserved(ms, "with four draws in flight and an empty hand")
	# Now strip both piles, leaving the four debts owed against nothing.
	var stranded := ms.p1.deck.size() + ms.p1.discard.size()
	ms.p1.deck.set_contents([] as Array[StringName])
	ms.p1.discard.clear()
	for _t in DELAY_TICKS * (HAND_SIZE + 1):
		_tick(ms)
	assert_eq(ms.p1.pending_draw_owed, 0, "every debt was consumed against the degrade")
	assert_eq(ms.p1.hand.size(), 0, "and the hand stayed short — hand_size may reach 0")
	assert_true(stranded > 0, "sanity: cards really were removed, so this is not a vacuous run")


# --- AC 15: in-flight windows survive a mid-match apply_balance --------------------------------

## AC 15 / the per-pool reload contract / CONSTRAINT C, for the pending-draw window: a window
## already running keeps its ORIGINAL duration and the new tick count takes effect at its next
## start(). The test_mid_match_reload_refills_stamina_to_max idiom.
##
## MUTATION: cache `balance_ticks` in a field at match start and read the delay from the cached
## object, and the final assertion FAILS — the next start() would still use the old count.
func test_the_pending_draw_window_survives_a_mid_match_apply_balance() -> void:
	var ms := _make_match()
	_cast(ms)
	assert_eq(ms.p1.pending_draw.remaining_ticks(), DELAY_TICKS)
	_tick(ms)
	assert_eq(ms.p1.pending_draw.remaining_ticks(), DELAY_TICKS - 1, "one tick spent")
	ms.apply_balance(_config(RELOAD_DELAY_TICKS))
	ms.drain_signals()
	assert_eq(ms.balance_ticks.draw_replacement_delay_ticks, RELOAD_DELAY_TICKS,
		"the reloaded count is live on balance_ticks")
	assert_eq(ms.p1.pending_draw.remaining_ticks(), DELAY_TICKS - 1,
		"the IN-FLIGHT window keeps its original duration across the reload")
	for _t in DELAY_TICKS - 1:
		_tick(ms)
	assert_eq(ms.p1.hand.size(), HAND_SIZE, "...and delivered on the ORIGINAL schedule")
	_cast(ms)
	assert_eq(ms.p1.pending_draw.remaining_ticks(), RELOAD_DELAY_TICKS,
		"the NEXT start() picks up the reloaded count (CONSTRAINT C, read inline)")


## The same contract for the OTHER new window — AC 15 says BOTH survive, and the vulnerable
## window's duration is read inline at the reshuffle for the same reason.
func test_the_vulnerable_window_survives_a_mid_match_apply_balance() -> void:
	var ms := _make_match()
	for _i in PILE + 1:
		_cast_and_settle(ms)
	assert_true(ms.p1.vulnerable_window.is_running, "sanity: a reshuffle opened the window")
	var remaining := ms.p1.vulnerable_window.remaining_ticks()
	assert_true(remaining > 0 and remaining <= VULNERABLE_TICKS)
	var reloaded := _config()
	reloaded.reshuffle_vulnerable_window_seconds = float(VULNERABLE_TICKS * 2) / 60.0
	ms.apply_balance(reloaded)
	ms.drain_signals()
	assert_eq(ms.balance_ticks.reshuffle_vulnerable_window_ticks, VULNERABLE_TICKS * 2,
		"the reloaded count is live")
	assert_eq(ms.p1.vulnerable_window.remaining_ticks(), remaining,
		"the in-flight vulnerable window keeps its ORIGINAL duration")


# --- helpers -----------------------------------------------------------------------------------

## Deliberately nothing the card library contains: content reaches state ONLY through the
## injection seam, and this harness cannot reach data/cards/ at all.
func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("delay_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CARD_COST
		out[id] = c
	return out


## Balance built IN-TEST, the _golden_config principle: nothing here loads
## data/balance/balance_config.tres, so a playtest edit can never break these assertions.
## max_hp is authored non-zero because a stat-less hero is dead on the first resolution check,
## which would freeze advance() at step 1b before step 6 was ever reached.
func _config(delay_ticks := DELAY_TICKS) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_mana = 90.0
	c.max_stamina = 40.0
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.draw_replacement_delay_seconds = float(delay_ticks) / 60.0
	c.reshuffle_vulnerable_window_seconds = float(VULNERABLE_TICKS) / 60.0
	return c


## A match with a dealt hand and mana on the board. The deal happens at step 6 of the FIRST
## advance(), so one tick is run here and the mana granted after it — the pool starts empty by
## ManaPool's own contract and the flywheel is not what these tests exercise.
func _make_match(delay_ticks := DELAY_TICKS) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config(delay_ticks))
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	_tick(ms)
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	ms.drain_signals()
	return ms


func _tick(ms: MatchState) -> void:
	_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()


## P1 commits a cast of hand slot 0 — always slot 0, because the hand shrinks under it and slot 0
## is the one index guaranteed to exist while the hand is non-empty.
func _cast(ms: MatchState) -> void:
	var i := InputIntent.new()
	i.card_slot = 0
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	_advance(ms, i, InputIntent.new())


## One full cast-to-delivery cycle: the cast tick plus exactly the authored delay, which lands
## the delivery on the last of those ticks. Each cycle moves ONE card from the pile to the hand
## and ONE from the hand to the discard, so PILE cycles empty the pile exactly.
func _cast_and_settle(ms: MatchState) -> void:
	_cast(ms)
	for _t in DELAY_TICKS:
		_tick(ms)


## AC 11's two halves in one place: the three containers are a permutation of the injected
## composition, and the fourth (in-flight) term closes the hand back to hand_size.
func _assert_conserved(ms: MatchState, occasion: String) -> void:
	var all := ms.p1.deck.to_array()
	all.append_array(ms.p1.hand.to_array())
	all.append_array(ms.p1.discard.to_array())
	all.sort()
	var expected := _deck_contents()
	expected.sort()
	assert_eq(all, expected,
		"deck + hand + discard is a PERMUTATION of the injected composition %s" % occasion)
	assert_eq(ms.p1.hand.size() + ms.p1.pending_draw_owed, HAND_SIZE,
		"the IN-FLIGHT term closes the hand: hand + owed == hand_size %s" % occasion)
