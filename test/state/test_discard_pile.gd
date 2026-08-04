extends TestCase

## Story 3-5a (AC 6): the THIRD pure container and the Hand removal method it exists to receive
## cards from. Container-level tests only — the cast path that drives them is test_card_play.gd's.
##
## These pin the SHAPE the two existing containers already established, because the value of a
## third container is that it behaves like its siblings: ids only, a copying read accessor, and a
## count that is the only thing the snapshot ever sees.


func test_starts_empty() -> void:
	var pile := DiscardPile.new()
	assert_eq(pile.size(), 0, "a fresh pile is empty")
	assert_true(pile.is_empty(), "...and says so")
	assert_eq(pile.to_array(), [] as Array[StringName], "...and reads as an empty array")


func test_add_appends_in_discard_order() -> void:
	var pile := DiscardPile.new()
	pile.add(&"first")
	pile.add(&"second")
	pile.add(&"third")
	assert_eq(pile.size(), 3, "three cards in")
	assert_eq(pile.to_array(), [&"first", &"second", &"third"] as Array[StringName],
		"order is DISCARD order — oldest first, newest last")


## to_array returns a COPY, the Deck.to_array / Hand.to_array contract: no caller may mutate the
## pile through the read accessor. The failure this catches is a container that handed out its
## live backing array, which would let presentation rewrite match state.
func test_to_array_returns_a_copy() -> void:
	var pile := DiscardPile.new()
	pile.add(&"card")
	var view := pile.to_array()
	view.append(&"smuggled")
	view.clear()
	assert_eq(pile.size(), 1, "mutating the returned array cannot reach the pile")
	assert_eq(pile.to_array(), [&"card"] as Array[StringName], "the pile is unchanged")


func test_clear_empties_the_pile() -> void:
	var pile := DiscardPile.new()
	pile.add(&"a")
	pile.add(&"b")
	pile.clear()
	assert_eq(pile.size(), 0, "cleared")
	assert_true(pile.is_empty(), "...and empty")


# --- Hand.remove_at (AC 6) -------------------------------------------------------------------

## The method the hand did not have. Before this story Hand exposed add/clear/size/is_empty/
## to_array only, and to_array returns a DUPLICATE — so no caller could take a card OUT of a hand
## at all, which is why playing a card needed this seat.
func test_hand_remove_at_returns_and_removes_the_named_slot() -> void:
	var hand := Hand.new()
	hand.add(&"a")
	hand.add(&"b")
	hand.add(&"c")
	var got := hand.remove_at(1)
	assert_eq(got, &"b", "the removed id is RETURNED, so the caller needs no second lookup")
	assert_eq(hand.to_array(), [&"a", &"c"] as Array[StringName],
		"...and the remaining cards close up in order")
	assert_eq(hand.size(), 2, "the hand shrank by exactly one")


func test_hand_remove_at_handles_both_ends() -> void:
	var hand := Hand.new()
	hand.add(&"a")
	hand.add(&"b")
	hand.add(&"c")
	assert_eq(hand.remove_at(0), &"a", "first slot")
	assert_eq(hand.remove_at(hand.size() - 1), &"c", "last slot")
	assert_eq(hand.to_array(), [&"b"] as Array[StringName], "only the middle card is left")


## The pair the cast path relies on: a card removed from the hand and added to the pile is the
## SAME id, so "hand + discard" conserves. A mismatch here is the defect that would silently
## duplicate or vanish cards over a round.
func test_removed_card_lands_in_the_pile_unchanged() -> void:
	var hand := Hand.new()
	var pile := DiscardPile.new()
	hand.add(&"ember_lash")
	hand.add(&"frost_dart")
	pile.add(hand.remove_at(0))
	assert_eq(pile.to_array(), [&"ember_lash"] as Array[StringName], "the id crossed unchanged")
	assert_eq(hand.to_array(), [&"frost_dart"] as Array[StringName], "and left the hand")


# --- PlayerState ownership -------------------------------------------------------------------

## The pile is owned by PlayerState on the Deck/Hand precedent, and is snapshotted as a COUNT.
func test_player_state_owns_a_discard_pile_and_snapshots_its_count() -> void:
	var player := PlayerState.new(SignalQueue.new())
	assert_not_null(player.discard, "PlayerState owns a discard pile from construction")
	assert_eq(player.discard.size(), 0, "empty at construction — nothing deals into it")
	var snap := player.to_snapshot()
	assert_true(snap.has("discard_size"), "the snapshot carries discard_size")
	assert_eq(snap["discard_size"], 0, "at zero")
	player.discard.add(&"played")
	assert_eq(player.to_snapshot()["discard_size"], 1, "and it tracks the pile")
	assert_false(str(player.to_snapshot()).contains("played"),
		"the snapshot carries the COUNT only — never an id (a StringName must not reach the hash)")
