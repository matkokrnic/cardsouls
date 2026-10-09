class_name SeedPin
extends Resource

## Story 7-4 (AC 17, `7-4/R13`): THE SHUFFLE-SEED PIN KNOB -- `data/seed_pin.tres`, LOAD-ONCE, read only by
## the runner (`MatchRunner._resolve_seed`) at match start and never again.
##
## HOMED IN `src/main/`, BESIDE ITS ONE READER, and deliberately NOT a `BalanceConfig` field: the balance
## config is hot-reloadable, and a reload that re-seeded the RNG mid-match is the determinism hole
## `E3-RG/R9` keeps the seed out of it for. Not in `main.tscn` either -- pinning a seed for a playtest is
## one edit to this resource, with no scene diff.
##
## THE RUNNER'S PRECEDENCE (`7-4/R15`): a replay record's seed > the runner's `seed_override` (headless
## tests) > this pin > a fresh random draw per launch. Whatever wins is the seed the recorder captures, so a
## game played on a random seed still replays identically.

## The seed to deal every launch with. 0 means UNSET: a new random seed is drawn each launch.
@export var pinned_seed: int = 0
