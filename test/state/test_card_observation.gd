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


# --- The two SILENT POPS (story 4-B1 code review, D1) -----------------------------------------

## THE CONTRACT THIS CHANNEL GAINED AT 4-B1, and the bug that proved it was missing. Until 4-B1 the
## rule was "announce when a CARD moved", and both paths below consume a debt without moving one,
## so both returned silently and that was correct. 4-B1 put `pending_draw_owed` into what the
## channel's consumer RENDERS (`HudRoot.on_cards_changed` paints IN_FLIGHT_CAPTION on any blank
## slot the owed list names), which makes a debt that SHRANK an observable change in its own right.
## A silent pop leaves the vacated slot painted "..." with nothing left that will ever repaint it —
## the permanent hole rendered exactly like an in-flight slot, which is the deferred-work.md finding
## the whole story exists to discharge, reintroduced through the back door.
##
## Both paths are UNREACHABLE IN NATURAL PLAY and are tested anyway, exactly like the DEAD branches
## in test_card_play.gd / test_contact_pipeline.gd: card count is conserved and a debt always has
## its own cast card sitting in the discard for the lazy reshuffle to hand back, so the piles cannot
## both be empty while a debt is outstanding (measured: a probe driving the real machine 400 ticks
## across seven deck sizes and three delays reached the precondition zero times). Defense in depth
## for a RENDERING contract is still worth its two tests — the rendering is what broke.

## Path 1: both piles empty at the delivery. The debt is consumed, no card can be drawn, the hole
## becomes permanent — and the observer must be told, or it keeps showing a delivery in flight.
func test_the_both_empty_degrade_announces_the_consumed_debt() -> void:
	var ms := _dealt_match()
	_advance(ms, _cast_intent(1), InputIntent.new())
	_empty_both_piles(ms.p1)
	assert_false(ms.p1.pending_draw_owed.is_empty(), "fixture: a debt is outstanding before the delivery")
	var seen := _watch(ms.p1)
	for _i in DRAW_DELAY_TICKS + 1:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.pending_draw_owed.is_empty(), "the delivery consumed the debt")
	assert_eq(seen.size(), 1,
		"the consumed debt announced exactly once — the slot is now the PERMANENT hole and the "
		+ "consumer has to hear it, or it renders an in-flight delivery that will never arrive")
	assert_eq((seen[0][0] as Array)[1], Hand.EMPTY, "...announcing the hole still standing at slot 1")
	assert_eq(seen[0][1], 0, "...an empty deck")
	assert_eq(seen[0][2], 0, "...and an empty discard: nothing was drawn and nothing reshuffled")


## Path 2: the DEAD pop. Death drops the DELIVERY but still consumes the debt (AC 7, 3-5b /
## 1-9/R3), so the same silence, from the other branch. Forced-DEAD idiom, `_round_over` left FALSE.
func test_the_dead_pop_announces_the_consumed_debt() -> void:
	var ms := _dealt_match()
	_advance(ms, _cast_intent(1), InputIntent.new())
	assert_false(ms.p1.pending_draw_owed.is_empty(), "fixture: a debt is outstanding before the delivery")
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)  # forced DEAD; _round_over stays FALSE
	ms.drain_signals()  # discard the forced-DEAD action_state_changed before we start counting
	var seen := _watch(ms.p1)
	var deck_before := ms.p1.deck.size()
	for _i in DRAW_DELAY_TICKS + 1:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.pending_draw_owed.is_empty(), "a corpse still consumes its debt (AC 7)")
	assert_eq(ms.p1.deck.size(), deck_before, "...and drops the DELIVERY: no card came off the deck")
	assert_eq(seen.size(), 1, "the consumed debt announced exactly once on the DEAD path too")
	assert_eq((seen[0][0] as Array)[1], Hand.EMPTY, "...with the hole still standing at slot 1")


## Both piles emptied between the cast and the delivery — the forced step that makes path 1
## reachable at all. Kept beside its one caller rather than in the fixture block: it is a forcing
## device for an unreachable branch, not part of any natural fixture.
func _empty_both_piles(player: PlayerState) -> void:
	var nothing: Array[StringName] = []
	player.deck.set_contents(nothing)
	player.discard.clear()


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
	# DELIBERATELY EXTENDED BY STORY 4-1 (AC 9): `unit_count`, the board COUNT, on the
	# deck_size / hand_size / discard_size precedent. The pin moves because the STORY moved it --
	# this is the guard doing its job, naming the cause, exactly as its own docstring promises.
	# The claim it guards is unchanged: counts only, never contents, no identity and no position.
	#
	# DELIBERATELY EXTENDED AGAIN BY STORY 4-2 (AC 11, `4-2/R2`): `unit_targets`, each unit's
	# acquired `[slot, index]` pair. TEN -> ELEVEN, and the extension is its own deliberate change
	# with its own assertion below rather than a number quietly edited in place — a pin that drifts
	# silently is the failure this project pins against.
	#
	# DELIBERATELY EXTENDED AGAIN BY STORY 4-3a (AC 9, `4-3a/R17`): `unit_hp`, one float per unit
	# record in board-index order. ELEVEN -> TWELVE, with its own assertion below for the same
	# reason 4-2 gave — a pin that drifts silently is the failure this project pins against.
	#
	# A FLOAT PER RECORD IS THE SAME CLASS AS `hero.hp` TWO LEVELS UP, so "counts only, never
	# contents" is not weakened: no identity, no StringName, no object and no position joins the
	# hash. This key is also HOW A HOLE REACHES THE HASH (AC 7) — a dead unit is a 0.0 at a stable
	# index, so the snapshot carries WHERE the hole is, not merely that one exists.
	#
	# THE CLAIM THE PIN GUARDS IS STILL UNCHANGED, and that is why the extension is legitimate rather
	# than an erosion: a `[slot, index]` pair is COUNTS AND INDICES, the same class as
	# `pending_draw_owed`'s owed slots (`4-2/R2` cites that precedent by name). No identity, no
	# StringName, no object and no position joins the hash. AC 9's per-unit IDENTITY extension added
	# no key at all — measured, `4-2/R8`.
	#
	# DELIBERATELY EXTENDED AGAIN BY STORY 4-3b (AC 16, `4-3b/R14` as amended): the unit ATTACK
	# RHYTHM. TWELVE -> EIGHTEEN, six new keys, each with its own line below and its own assertion
	# of the COUNT — never a number quietly edited in place, which is this file's own standing
	# discipline and the reason the count is asserted separately from the set.
	#
	# THE SIX ARE A DEV-PASS MEASUREMENT AND THE STORY SAID SO. `4-3b` NAMED six contributing
	# fields — phase state, tick countdown, locked attack direction, monotonic attack counter,
	# in-reach flag, and the unit dedupe records — and deliberately declined to assert a count,
	# because the board's precedent runs BOTH ways: one array -> one key for `unit_hp`, but TWO
	# arrays fused into ONE key of pairs for `unit_targets`. The floor it claimed was thirteen with
	# no ceiling. MEASURED HERE: all six surfaced as keys, one apiece, so the count is EIGHTEEN and
	# NO named field needed a stated reason for failing to surface.
	#
	# THE CLAIM THIS PIN GUARDS IS STILL UNCHANGED, which is what makes the extension legitimate
	# rather than an erosion: ints, bools, `Vector2` headings and arrays of ints — counts, values
	# and indices. No identity, no StringName, no object and no position joins the hash. The locked
	# DIRECTION is the one that could look like an exception and is not: it is a normalised heading
	# the runner DERIVED from two positions, the same class of position-derived datum the contact
	# fact's `dir` has carried legally since 1-8, and `4-3/R2` bans state OWNING a position rather
	# than learning a direction.
	var expected: Array = [
		"deck_size", "discard_size", "hand_size", "hero", "mana", "orbs",
		"pending_draw", "pending_draw_owed",
		# Story 4-4 (AC 14-19): SEVEN more — the projectile board, in sorted position.
		"projectile_alive", "projectile_flight_ticks", "projectile_homing", "projectile_kind",
		"projectile_source", "projectile_targets", "projectile_travelled",
		"stamina",
		# Story 4-4 (AC 1/AC 10): two more — `unit_attack_cooldown` and `unit_kind`.
		"unit_attack_cooldown", "unit_attack_count", "unit_attack_dir", "unit_attack_phase",
		"unit_attack_ticks",
		"unit_count", "unit_hp", "unit_in_reach", "unit_kind", "unit_swing_dedupe", "unit_targets",
	]
	assert_eq(keys, expected,
		"the per-player snapshot key set is UNCHANGED by the observation channel — counts only, "
		+ "never contents (3-3 AC 5 / 3-5a AC 6 / 3-5b AC 4)")
	# Story 4-2: the COUNT, asserted separately from the SET, so the move from ten to eleven is a
	# named quantity in its own right. A future story that swaps one key for another would keep this
	# green and fail the set assertion above; one that adds a key silently fails BOTH.
	assert_eq(keys.size(), 27,
		"the per-player snapshot key set is TWENTY-SEVEN keys as of story 4-4 (eighteen before it). "
		+ "TWO come from the unit board: `unit_kind`, the per-record kind INDEX that makes a totem "
		+ "a distinct on-board thing (AC 1), and `unit_attack_cooldown`, the firing-cadence "
		+ "countdown (AC 10). SEVEN come from the new projectile board (AC 14-19): its target pair, "
		+ "the firing kind, the source index, liveness (which IS its dedupe), the homing flag "
		+ "AC 16's i-frame drop clears, the acceleration clock and the 60 m odometer. Every one is "
		+ "a plain int, bool or float — no StringName reaches the hash, because "
		+ "`Array[StringName].sort()` orders by internal POINTER on this engine, and no POSITION "
		+ "does either: `projectile_travelled` is a path LENGTH the state layer integrates itself")


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
