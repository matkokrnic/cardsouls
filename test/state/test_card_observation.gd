extends TestCase

## Story 3-6 (AC 2): the CARD OBSERVATION CHANNEL — PlayerState.cards_changed, the state-side
## half of the runner's EIGHTH observation seam. One payload carries this player's hand CONTENTS
## (ids, in hand order), their deck COUNT and their discard COUNT.
##
## WHY A SIGNAL AND NOT A SNAPSHOT KEY. The hand's contents and the piles' ORDER are excluded
## from to_snapshot() by three separate rulings (3-3 AC 5, 3-5a AC 6, 3-0c AC 11's pinned
## exclusion set) and stay excluded: a StringName reaching the canonical hash orders by INTERNAL
## POINTER on this engine, which is deterministic within one process and NOT across runs. So the
## HUD cannot learn the hand by reading state — it has to be PUSHED one, and this is that push.
## Every test below therefore also asserts, directly or by the key-set pin, that nothing about
## this channel reached the snapshot.
##
## Fixture mirrors test_card_play.gd deliberately (same seed, same uniform cost, same distinct
## counts) so a payload count that came from the wrong quantity lands on a different number.

const SEED := 4242
const DECK_SIZE := 8
const HAND_SIZE := 4
const CARD_COST := 3.0
const START_MANA := 10.0


# --- The deal: the first payload -------------------------------------------------------------

## The step-6 deal is the first thing that puts cards anywhere, so it is the first thing that must
## announce them. Asserted as CONTENTS, not just a count: a payload carrying the right SIZE and
## the wrong cards would render four wrong labels and pass a count-only test.
func test_the_deal_announces_each_players_own_hand_deck_and_discard() -> void:
	var ms := _fresh_match()
	var p1_seen := _watch(ms.p1)
	var p2_seen := _watch(ms.p2)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(p1_seen.size(), 1, "the deal announces exactly once per player")
	assert_eq(p1_seen[0][0], ms.p1.hand.to_array(), "payload carries the hand CONTENTS, in hand order")
	assert_eq(p1_seen[0][1], DECK_SIZE - HAND_SIZE, "...this player's deck count (8 dealt down to 4)")
	assert_eq(p1_seen[0][2], 0, "...and their discard count, empty at the deal")
	# The per-slot channel is genuinely per-slot: P2's payload is P2's own hand, and the two hands
	# differ (both piles are shuffled against the same generator IN TURN, 3-3), so a channel that
	# handed both players P1's hand would fail here rather than pass by symmetry.
	assert_eq(p2_seen.size(), 1, "P2's own channel fired too")
	assert_eq(p2_seen[0][0], ms.p2.hand.to_array(), "...carrying P2's hand, not P1's")
	assert_ne(p1_seen[0][0], p2_seen[0][0], "the two dealt hands differ — the channels are not crossed")


## D5: queued during advance(), emitted only at drain. A consumer must never observe a
## half-advanced tick — the whole reason the HUD reads a drained signal rather than the container.
func test_the_payload_is_queued_during_advance_and_fires_only_on_drain() -> void:
	var ms := _fresh_match()
	var seen := _watch(ms.p1)
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	assert_eq(seen.size(), 0, "nothing fires mid-advance (D5)")
	ms.drain_signals()
	assert_eq(seen.size(), 1, "...and exactly once on drain")


# --- The cast and the delayed replacement ----------------------------------------------------

## A cast changes the hand and the discard in the same tick; the payload must describe the state
## AFTER the mutation, not before it. The delivery is a SEPARATE later tick on this fixture (the
## authored delay is nonzero here, unlike test_card_play.gd's zero-delay fixture), which is what
## makes "the hand is one short while a draw is in flight" observable on the channel at all.
func test_a_cast_announces_the_shortened_hand_and_the_grown_discard() -> void:
	var ms := _dealt_match()
	var played: StringName = ms.p1.hand.to_array()[1]
	var seen := _watch(ms.p1)
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_eq(seen.size(), 1, "the cast announced once")
	var payload: Array = seen[0]
	assert_false((payload[0] as Array).has(played), "the cast card is GONE from the announced hand")
	# Story 4-0 (AC 1/AC 7): the payload is FULL WIDTH and carries the EMPTY MARKER at the hole.
	# It used to be one element shorter, which is what let the HUD renumber the remaining cards.
	# The nine-consumer table binds this payload to WIDTH precisely so a renderer laying out a
	# fixed row of slots sees the hole positionally rather than compacted away.
	assert_eq((payload[0] as Array).size(), HAND_SIZE,
		"the announced hand keeps its WIDTH while the replacement is in flight")
	assert_eq((payload[0] as Array)[1], Hand.EMPTY,
		"...with the empty marker standing in the vacated slot, so slot 2 is still announced at "
		+ "index 2 (`4-0/R3`: any other marker renders visible garbage in hud_root.gd:159)")
	assert_eq(payload[2], 1, "the announced discard grew by the card just played")
	assert_eq(payload[1], DECK_SIZE - HAND_SIZE,
		"the deck has NOT moved yet — the replacement is owed, not drawn (3-5b)")


## The delivery tick is a second, later announcement. Without it the HUD would show a permanently
## short hand: the cast tick's payload would be the last word.
func test_the_delayed_delivery_announces_the_refilled_hand() -> void:
	var ms := _dealt_match()
	_advance(ms, _cast_intent(1), InputIntent.new())
	var seen := _watch(ms.p1)
	for _i in DRAW_DELAY_TICKS + 1:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(seen.size(), 1, "exactly ONE further announcement — the delivery tick, not every tick")
	assert_eq((seen[0][0] as Array).size(), HAND_SIZE, "the hand is announced full again")
	assert_eq(seen[0][1], DECK_SIZE - HAND_SIZE - 1, "...and the deck one lower: the replacement came off it")


## THE NO-POLLING PROPERTY, stated where it can bite (AC 5). A tick in which no card moved must
## announce NOTHING — a channel that re-announced every tick would work in play and would quietly
## make the HUD a per-frame recompute wearing a signal's clothes.
func test_a_tick_that_moves_no_card_announces_nothing() -> void:
	var ms := _dealt_match()
	var seen := _watch(ms.p1)
	for _i in 10:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(seen.size(), 0, "ten quiet ticks, zero announcements")


## The debug reset re-lays the whole composition, so it must re-announce — otherwise a reset would
## leave the HUD rendering the pre-reset hand for the rest of the match.
func test_the_debug_reset_re_announces_the_restored_hand() -> void:
	var ms := _dealt_match()
	_advance(ms, _cast_intent(0), InputIntent.new())
	var seen := _watch(ms.p1)
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_true(seen.size() >= 1, "the reset announced the re-dealt hand")
	var last: Array = seen[seen.size() - 1]
	assert_eq((last[0] as Array).size(), HAND_SIZE, "a full hand again")
	assert_eq(last[1], DECK_SIZE - HAND_SIZE, "deck back to its post-deal count")
	assert_eq(last[2], 0, "and the discard emptied by the re-lay")


# --- Shape of the payload ---------------------------------------------------------------------

## The payload is a COPY. A consumer that mutated it must not be able to reach into the hand —
## the same rule Deck/Hand/DiscardPile.to_array() already carry, extended across the signal
## boundary where it is easiest to lose.
func test_the_announced_hand_is_a_copy_the_consumer_cannot_mutate_state_through() -> void:
	var ms := _fresh_match()
	var seen := _watch(ms.p1)
	_advance(ms, InputIntent.new(), InputIntent.new())
	var handed: Array = seen[0][0]
	handed.clear()
	assert_eq(ms.p1.hand.occupied_count(), HAND_SIZE,
		"clearing the received array must not empty the hand")


## IDS, never CardData. The containers carry StringName for a measured reason (an object in a
## hashed container yields a per-allocation instance id); the channel out of them must not be the
## place that rule is broken.
func test_the_announced_hand_carries_string_name_ids() -> void:
	var ms := _fresh_match()
	var seen := _watch(ms.p1)
	_advance(ms, InputIntent.new(), InputIntent.new())
	for id: Variant in seen[0][0]:
		assert_true(id is StringName, "hand element is a StringName id, never a CardData reference")


## THE GOLDEN'S PREMISE, made executable. This story's Golden Prediction is UNMOVED because the
## channel adds no snapshot key: it is a live push, not a state read. If a later change quietly
## folds the hand contents into the snapshot, the golden moves AND this pin fails first, naming
## the cause.
func test_the_observation_channel_adds_no_snapshot_key() -> void:
	var ms := _dealt_match()
	var keys: Array = ms.p1.to_snapshot().keys()
	keys.sort()
	var expected: Array = [
		"deck_size", "discard_size", "hand_size", "hero", "mana", "orbs",
		"pending_draw", "pending_draw_owed", "stamina",
	]
	assert_eq(keys, expected,
		"the per-player snapshot key set is UNCHANGED by the observation channel — counts only, "
		+ "never contents (3-3 AC 5 / 3-5a AC 6 / 3-5b AC 4)")


# --- Fixture ----------------------------------------------------------------------------------

## A nonzero replacement delay, deliberately unlike test_card_play.gd's zero-delay fixture: the
## delivery has to land on a LATER tick for the cast/delivery announcements to be two distinct
## events rather than one collapsed one.
const DRAW_DELAY_SECONDS := 0.25
const DRAW_DELAY_TICKS := 15  # 0.25s at TimingWindow.TICK_HZ (60)


## Subscribes to one player's channel and returns the list the payloads land in, newest last.
## Each entry is [hand_ids, deck_count, discard_count].
func _watch(player: PlayerState) -> Array:
	var seen: Array = []
	player.cards_changed.connect(
		func(hand_ids: Array, deck_count: int, discard_count: int) -> void:
			seen.append([hand_ids, deck_count, discard_count]))
	return seen


## Injected but NOT yet dealt — the deal happens at step 6 of the first advance(), which is the
## event several tests above are watching for.
func _fresh_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	return ms


## ...and one tick further on: dealt, drained, with mana on the board to cast with.
func _dealt_match() -> MatchState:
	var ms := _fresh_match()
	_advance(ms, InputIntent.new(), InputIntent.new())
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
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


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_mana = 90.0
	c.max_stamina = 40.0
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.draw_replacement_delay_seconds = DRAW_DELAY_SECONDS
	return c


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("obs_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CARD_COST
		out[id] = c
	return out
