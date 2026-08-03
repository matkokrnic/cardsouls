class_name Deck
extends RefCounted

## Story 3-3 (AC 1): the per-player draw pile. PURE RefCounted, owned by PlayerState — no
## scene, no autoload, no wall-clock, and NO RNG OF ITS OWN. The shuffle takes MatchState's
## seeded RandomNumberGenerator as an ARGUMENT (F2/A2). That is not a style choice: measured
## on this engine, Array.shuffle() draws from the GLOBAL RNG and leaves a per-instance
## generator untouched, so a `deck.shuffle()` here would pass the suite while silently
## destroying replay. AC 8 bans the implicit-global-RNG collection APIs under src/state/
## outright (test/state/test_architecture_invariants.gd) for exactly that reason.
##
## Elements are StringName IDS — never CardData references, never bare indices (AC 5). A
## CardData reference must never enter the snapshot: the canonical hash has no object branch
## and falls through to a string conversion yielding a per-allocation instance id, which
## would fail the same-seed determinism test outright. Nothing here names CardDatabase,
## CARDS_DIR or data/cards — content arrives by INJECTION through MatchState (AC 1/AC 2).
##
## ORDER IS DELIBERATELY NOT HASH-VISIBLE: PlayerState.to_snapshot() carries the COUNT only,
## and the order stays derivable from seed plus injected composition. NEW OBLIGATION recorded
## for the intent-recorder story (3-0c): the injected composition must enter the replay record
## alongside seed and intents, or a replay would depend on the contents of data/cards/.
##
## NOT HERE, BY AC 11: no discard pile, no reshuffle path, no deck-exhaustion handling. With
## only an initial fill drawing from the pile, exhaustion is unreachable — those land in 3-5
## together with the triggers that make them reachable.

var _cards: Array[StringName] = []


## Replace the whole pile. Called ONLY from MatchState's single step-6 deal seat, on both the
## match-start and the debug-reset occasion — never from the injection call itself (ONE SEAT:
## the RNG is consumed inside advance() and nowhere else).
func set_contents(ids: Array[StringName]) -> void:
	_cards = ids.duplicate()


## Story 3-3 (AC 7): EXPLICIT in-place Fisher-Yates against the seeded generator handed in.
## The descending walk draws exactly size() - 1 times, and that draw count depends on the
## pile's SIZE ALONE, never on what is in it — the property the Golden Prediction's cause 2
## rests on. randi_range is called ON THE INSTANCE; the bare global randi_range() is what
## INVARIANT D3(b) bans, and passing the generator in is the whole point of the distinction.
func shuffle_with_rng(rng: RandomNumberGenerator) -> void:
	for i in range(_cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swapped := _cards[i]
		_cards[i] = _cards[j]
		_cards[j] = swapped


## Take the TOP card — the BACK of the array (the pile is a stack; set_contents lays the
## composition down and the shuffle permutes it, so which end is "top" is a convention, not a
## behaviour). Callers check is_empty() first: this story's ONLY caller is the hand fill,
## which stops at the authored hand_size or an exhausted pile, whichever comes first.
func draw_top() -> StringName:
	var top: StringName = _cards[_cards.size() - 1]
	_cards.remove_at(_cards.size() - 1)
	return top


func size() -> int:
	return _cards.size()


func is_empty() -> bool:
	return _cards.is_empty()


## READ accessor returning a COPY, so no caller can mutate the pile through it. Order IS
## meaningful in the return value (it is the shuffle's result, and the permutation and
## fill-from-the-top proofs need it) — which is precisely why it is absent from the snapshot.
func to_array() -> Array[StringName]:
	return _cards.duplicate()
