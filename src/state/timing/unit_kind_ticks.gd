class_name UnitKindTicks
extends RefCounted

## Story 4-4 (AC 11): the TICK-DOMAIN twin of one `UnitKindProfile` — its attack records' derived
## tick counts, in the same order the profile authors them. Built inside `BalanceTicks.from_config()`
## and nowhere else, so the single seconds-to-ticks boundary (A1) stays single.
##
## IT CARRIES ONLY THE ATTACK LIST because a kind's own fields are all scalars — `move_speed`,
## `stop_distance`, `max_hp` and the three phase multipliers are rates, distances and factors, none
## of them durations, so none of them converts. That asymmetry is the same one `BalanceConfig`
## already has: `unit_move_speed` never had a `_ticks` twin either, "exactly as there is no
## `move_speed_ticks`".
##
## INDEX-ALIGNED WITH `UnitKindProfile.attacks`, and that alignment is the whole contract: a reader
## that has an attack INDEX (every reader passes 0 this story — selection is a Non-Goal) uses the
## same index against both objects. `attack_at()` below mirrors `UnitKindProfile.attack_at()`
## including its null-for-out-of-range answer, so the two stay one shape rather than two that could
## drift.

var attacks: Array[UnitAttackTicks] = []


## The derived tick record at `index`, or NULL when this kind has none — `UnitKindProfile.attack_at`
## verbatim, for its reason verbatim: a total function's honest default rather than a crash, so a
## kind that authors no attack simply never attacks. The two are read in pairs at every seat, so a
## divergence in their null behaviour would be a divergence in one seat's guard.
func attack_at(index: int) -> UnitAttackTicks:
	if index < 0 or index >= attacks.size():
		return null
	return attacks[index]
