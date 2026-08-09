class_name UnitBoard
extends RefCounted

## Story 4-1 (AC 4): the per-player BOARD — the collection `docs/game-architecture.md` D9
## reserved for this story ("PlayerState will gain a `units`/board collection with its first
## consumer, story 4-1"). The FOURTH pure container, alongside Deck, Hand and DiscardPile and
## built to the same shape as all three: PURE RefCounted, owned by PlayerState, no RNG, no
## SignalQueue, no scene reference, and nothing here names CardDatabase, CARDS_DIR or
## data/cards.
##
## ONE RECORD PER RESOLVED `summon_*` CAST, APPENDED IN CAST ORDER. The single writer is
## MatchState's step-6 cast dispatch, through CardEffectResolver's verdict — the same
## "one seat, inside the ordered dispatch" rule the three sibling containers carry.
##
## A RECORD CARRIES NOTHING, AND THAT IS THE STORY'S RULING RATHER THAN AN OMISSION. Three
## separate clauses empty it: `4-1/R12` ships the record POSITIONLESS (position stays
## actor-owned, the hero precedent unchanged — hero_state.gd:5); the ratified TOTEM CLAUSE
## ships it with NO type/kind field, so uniform `summon_*` treatment does not pre-commit
## `4-4`'s totem/minion differentiation; and the story's Deferred section removes AI,
## targeting, HP, damage and death (4-2/4-3). What is left of "a unit record" is EXISTENCE,
## in cast order — and the honest representation of N contentless records appended in order
## is N.
##
## SO THIS IS A COUNT, DELIBERATELY, AND THE ALTERNATIVE IS THE ANTI-PRECEDENT THE STORY
## NAMES. An Array of per-unit ids or structs would be reserved vocabulary authored ahead of
## its consumer — which is exactly `card_effect.gd` itself, the precedent `E4-P/R2` names as
## the one "to avoid repeating without cause" (authored at 3-2, carried unconsumed until this
## story). `4-2`'s gate rules on position ownership with `TargetingService` as a real
## consumer; whatever content a unit then needs is added THERE, against something that reads
## it.
##
## SNAPSHOTTED AS A COUNT (PlayerState.to_snapshot's "unit_count"), the deck_size /
## hand_size / discard_size precedent verbatim — no identity, no effect id, no position
## reaches the hash (AC 9).

var _count := 0


## The ONE way a unit enters the board. Called from MatchState's step-6 cast dispatch, once
## per resolved `summon_*` cast. Takes no argument because a record carries nothing — see the
## header.
func add() -> void:
	_count += 1


## Emptied by the DEBUG RESET ONLY, never by round end (`4-1/R5`): the board persists through
## the round-over freeze rather than blinking out at the instant of death, matching how every
## other piece of round-crossing state already behaves. MatchState._reset_player is the one
## caller; MatchState._end_round is deliberately untouched.
func clear() -> void:
	_count = 0


func size() -> int:
	return _count


func is_empty() -> bool:
	return _count == 0
