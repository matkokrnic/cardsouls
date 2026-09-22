extends RefCounted

## Story 6-5a (AC 13): THE SUMMON-BEARING TEST DECK the live minion tests are re-pointed at.
##
## Deck 1 carries three summons (Ruin Vanguard) in twenty, so a four-card opening hand holds one only about
## half the time, and each live test's seed is fixed -- whether it deals a summon is luck, and measured
## on Deck 1 these tests' seeds do not. Rather than lean on fixed-seed luck, each re-pointed test hands
## the runner this list through its deck-list seat (`match_runner.gd` `deck_list_override`, set BEFORE
## the runner enters the tree): twenty Ruin Vanguards, so every card dealt to either player summons a
## minion. Both players still receive ONE injected composition, as in live play.
##
## A TEST FIXTURE, NOT AUTHORED CONTENT: it is built in code rather than as a `.tres` under data/decks/,
## so `test_card_authoring.gd`'s per-entry `copies <= max_copies` audit (which covers authored decks)
## never sees it, and it is exempt by construction rather than by a skip list.

const CARD_ID := &"ruin_vanguard"
const COPIES := 20


static func all_summons() -> DeckList:
	var deck := DeckList.new()
	deck.card_ids = [CARD_ID] as Array[StringName]
	deck.copies = [COPIES] as Array[int]
	return deck
