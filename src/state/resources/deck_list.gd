class_name DeckList
extends Resource

## Story 6-5a (AC 11, OQ4 / `6-5a/R10`): ONE AUTHORED DECK -- which cards, how many copies of each, in
## which order. Pure schema, like every file in src/state/resources/: no logic, and nothing under
## src/state/ reads it. The RUNNER expands it into the plain `Array[StringName]` composition that
## `MatchState.inject_deck` has always taken, so the state layer's deck seam is unchanged in shape.
##
## CONTENT, NOT BALANCE. Which cards a deck holds is authored content (the `CardData.max_copies`
## per-card-not-per-balance precedent), so it is its own resource under `data/decks/` rather than a
## `BalanceConfig` field. `BalanceConfig.deck_size` is KEPT and an authoring test pins it equal to the
## list's copy sum (`6-5a/R9`), so the two can never silently disagree.
##
## AN ORDERED LIST, NEVER A DICTIONARY. The expanded composition's PRE-SHUFFLE order feeds the seeded
## shuffle, and a Dictionary's iteration order is not something this project lets decide anything.
## Two INDEX-ALIGNED arrays rather than a nested entry resource, so no new nested class exists that
## would need a `RecordFile._fresh_nested` row (the record carries the expanded ids, never this list).
## Entry `i` is `copies[i]` copies of `card_ids[i]`; the two arrays are pinned equal in length by
## `test_card_authoring.gd`, which also pins each entry's copies <= that card's `max_copies`.

@export var card_ids: Array[StringName] = []
@export var copies: Array[int] = []
