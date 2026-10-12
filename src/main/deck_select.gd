class_name DeckSelect
extends Resource

## Story 7-5a (AC 9, `7-5a/R26`): THE PER-SEAT DECK KNOB -- `data/deck_select.tres`, LOAD-ONCE, read only by
## the runner (`MatchRunner._resolve_seat_decks`) at match start and never again. It says which authored
## deck list each seat plays; there is no menu.
##
## HOMED IN `src/main/`, BESIDE ITS ONE READER, on `SeedPin`'s own reasoning: the balance config is
## hot-reloadable, and a reload that changed a seat's deck mid-match would re-point a composition the deal
## already laid down. Not in `main.tscn` either -- pitting Deck 2 against Deck 1 for a smoke is one edit to
## this resource, with no scene diff.
##
## THE RUNNER'S PRECEDENCE (`7-5a/R26`): a replay record's compositions > a test override
## (`deck_list_override` / `seat_deck_list_overrides`) > this setting > the default (both seats Deck 1).
## A MISSING FILE MEANS THE DEFAULT. A value naming a deck that does not exist REFUSES TO START THE MATCH
## with a named error -- loud over silent, never a quiet fall back to Deck 1.

## The deck each seat plays, by NAME: `seat_decks[0]` is player 1's, `seat_decks[1]` player 2's. A name is
## the file stem of a `DeckList` under `data/decks/` (`&"deck_2"` is `res://data/decks/deck_2.tres`).
@export var seat_decks: Array[StringName] = [&"deck_1", &"deck_1"]
