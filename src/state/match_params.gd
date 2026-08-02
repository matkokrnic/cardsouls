class_name MatchParams
extends RefCounted

## Story 3-1 (AC 1): the MATCH-SCOPED construction parameters — everything MatchState needs
## at birth that is NOT a tunable. Pure RefCounted data, injected ONCE at construction and
## never re-applied.
##
## Deliberately NOT a Resource and deliberately NOT part of BalanceConfig (E3-RG/R9,
## locked): BalanceConfig is the X3 hot-reloadable schema that apply_balance() re-applies,
## and a reload that re-seeded the RNG mid-match is a determinism hole. The two objects are
## separated by LIFETIME, not by subject matter — this one is fixed for the whole match, the
## other is re-injectable at any time.
##
## MatchState consumes the seed into its RNG and does NOT retain this object, so there is no
## stored seed for a later call to re-apply — the "never re-seeded" rule is structural rather
## than conventional.

## The gameplay RNG seed (F2). The runner's _SEED feeds this; headless tests pass their own.
var seed_value: int


func _init(value: int) -> void:
	seed_value = value
