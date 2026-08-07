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


# --- Hand.remove_at (AC 6; RESHAPED BY STORY 4-0) --------------------------------------------

## Build a Hand the way the deal seat does: a width from the caller, then indexed in-place fills.
## `Hand.add` no longer exists — an appending method against a pre-filled width would write PAST
## it — so every fixture here constructs through the shipped surface.
func _hand_of(ids: Array[StringName]) -> Hand:
	var hand := Hand.new()
	hand.clear(ids.size())
	for i in ids.size():
		hand.fill_at(i, ids[i])
	return hand


## The method the hand did not have. Before 3-5a, Hand exposed add/clear/size/is_empty/to_array
## only, and to_array returns a DUPLICATE — so no caller could take a card OUT of a hand at all,
## which is why playing a card needed this seat.
##
## STORY 4-0 INVERTS WHAT THIS TEST ASSERTS, and the old assertion is the bug. It read "the
## remaining cards close up in order" and "the hand shrank by exactly one" — that closing-up is
## the `Array.remove_at` shift that renamed slot 2 to slot 1 under the player's fingers after
## every cast. The removal is now an IN-PLACE HOLE WRITE: only the named slot changes, and the
## width does not move at all.
func test_hand_remove_at_leaves_a_hole_and_moves_no_other_slot() -> void:
	var hand := _hand_of([&"a", &"b", &"c"] as Array[StringName])
	var got := hand.remove_at(1)
	assert_eq(got, &"b", "the removed id is RETURNED, so the caller needs no second lookup")
	assert_eq(hand.to_array(), [&"a", Hand.EMPTY, &"c"] as Array[StringName],
		"...and the remaining cards DO NOT close up — slot 2 is still slot 2 (AC 1)")
	assert_eq(hand.size(), 3, "the WIDTH did not move")
	assert_eq(hand.occupied_count(), 2, "...only the occupancy did")
	assert_true(hand.is_slot_empty(1), "the vacated slot reports as a hole")
	assert_false(hand.is_slot_empty(0), "...and its neighbours do not")
	assert_false(hand.is_slot_empty(2))


func test_hand_remove_at_handles_both_ends() -> void:
	var hand := _hand_of([&"a", &"b", &"c"] as Array[StringName])
	assert_eq(hand.remove_at(0), &"a", "first slot")
	assert_eq(hand.remove_at(hand.size() - 1), &"c", "last slot")
	assert_eq(hand.to_array(), [Hand.EMPTY, &"b", Hand.EMPTY] as Array[StringName],
		"only the middle card is left — AT ITS ORIGINAL INDEX, with holes either side")
	assert_eq(hand.occupied_ids(), [&"b"] as Array[StringName],
		"the occupancy view filters the holes out; the width view above keeps them")


## Story 4-0 (AC 1/AC 4): the fill is the removal's exact inverse — the vacated slot, and only it,
## comes back. This is the property the whole story exists to deliver, at the container level.
func test_hand_fill_at_refills_the_vacated_slot_and_nothing_else() -> void:
	var hand := _hand_of([&"a", &"b", &"c"] as Array[StringName])
	hand.remove_at(1)
	hand.fill_at(1, &"z")
	assert_eq(hand.to_array(), [&"a", &"z", &"c"] as Array[StringName],
		"the replacement landed in the vacated slot, not at the end")
	assert_eq(hand.size(), 3)
	assert_eq(hand.occupied_count(), 3)


## Story 4-0: writing over an OCCUPIED slot would silently destroy a card, so `fill_at` guards
## against it — and so does `remove_at` against a hole. Both are Invariant.check, which ABORTS
## rather than returns, so they are proven the way every other Invariant in this repo is proven:
## by a source scan of the shipped seat (the inject_deck / inject_card_costs idiom). Triggering
## one at runtime would take the harness down with it.
##
## The POSITIVE half runs for real below, which is what keeps this from being a scan of a guard
## that guards nothing: a fill into a genuine hole is permitted and lands.
func test_hand_guards_the_fill_and_the_removal_and_permits_the_legitimate_fill() -> void:
	var hand := _hand_of([&"a", &"b"] as Array[StringName])
	assert_false(hand.is_slot_empty(0), "sanity: slot 0 is occupied")
	hand.remove_at(0)
	hand.fill_at(0, &"z")
	assert_eq(hand.to_array(), [&"z", &"b"] as Array[StringName],
		"a fill into a HOLE is permitted and lands in that exact slot")
	# The two guards, by content.
	var src := FileAccess.get_file_as_string("res://src/state/hand.gd")
	assert_true(src.contains("Invariant.check(_cards[index] == EMPTY,"),
		"fill_at must Invariant.check that the target slot is a HOLE — a fill over an occupied "
		+ "slot would silently destroy a card")
	assert_true(src.contains("Invariant.check(not is_slot_empty(index),"),
		"remove_at must Invariant.check OCCUPANCY, not merely the bound: under fixed width every "
		+ "index below the width is in range, so a bound-only check goes silently VACUOUS")
	assert_false(src.contains("_cards.remove_at("),
		"Array.remove_at must not survive anywhere in Hand — the left-shift it performs IS the "
		+ "defect this story removes (AC 1)")


## Story 4-0 (AC 7, `4-0/R3`): the marker's VALUE, pinned as a literal rather than referenced
## symbolically. Every other site in the suite reads `Hand.EMPTY`, so all of them follow the
## constant wherever it goes — which means NONE of them can catch the constant itself changing.
## A marker of `&"__empty__"` survived the whole state suite during the dev pass; this is the
## assertion that closes that hole.
##
## The value is FORCED by hud_root.gd:159. That line is
## `_own_card_labels[i].text = str(hand_ids[i]) if i < hand_ids.size() else ""`, and against a
## fixed-width payload its `else ""` branch is DEAD — so the caption of a vacated slot is
## literally `str(marker)`. Any marker but the empty StringName renders VISIBLE GARBAGE in the
## hole, which is exactly the defect 3-6 AC 1 shipped to prevent: "a caption left behind is a
## card the player can see and cannot cast."
func test_the_empty_marker_is_the_empty_string_name_and_renders_as_a_blank_caption() -> void:
	assert_eq(Hand.EMPTY, &"", "the marker IS the empty StringName (`4-0/R3`)")
	assert_eq(str(Hand.EMPTY), "",
		"...so hud_root.gd's `str(hand_ids[i])` caption renders BLANK for a hole — the HUD needs "
		+ "no code change for this story, and that claim is true only because of this value")
	assert_eq(String(Hand.EMPTY).length(), 0, "no whitespace hiding in it either")


## Story 4-0 (AC 2): is_empty() means "no OCCUPIED slots", never `_cards.is_empty()`. Once the
## backing array is pre-filled to its width it is never empty again, so the bare array read would
## be permanently false and silently wrong. A width-0 hand — the never-dealt state — is empty too.
func test_hand_is_empty_means_no_occupied_slots_not_a_zero_width_array() -> void:
	var hand := _hand_of([&"a", &"b"] as Array[StringName])
	assert_false(hand.is_empty(), "two cards held")
	hand.remove_at(0)
	assert_false(hand.is_empty(), "one card still held, against a still-full width")
	hand.remove_at(1)
	assert_true(hand.is_empty(), "no OCCUPIED slots — even though the array is still 2 wide")
	assert_eq(hand.size(), 2, "...which is exactly the case a bare _cards.is_empty() would miss")
	assert_true(Hand.new().is_empty(), "and a never-dealt hand, width 0, is empty as well")


## The pair the cast path relies on: a card removed from the hand and added to the pile is the
## SAME id, so "hand + discard" conserves. A mismatch here is the defect that would silently
## duplicate or vanish cards over a round.
func test_removed_card_lands_in_the_pile_unchanged() -> void:
	var hand := _hand_of([&"ember_lash", &"frost_dart"] as Array[StringName])
	var pile := DiscardPile.new()
	pile.add(hand.remove_at(0))
	assert_eq(pile.to_array(), [&"ember_lash"] as Array[StringName], "the id crossed unchanged")
	assert_eq(hand.occupied_ids(), [&"frost_dart"] as Array[StringName], "and left the hand")
	assert_eq(hand.to_array(), [Hand.EMPTY, &"frost_dart"] as Array[StringName],
		"...leaving a HOLE where it was, not a shorter hand")


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
