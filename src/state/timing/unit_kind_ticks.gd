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

## Story 7-3 (AC 7/AC 12/AC 16): the kind's own DURATIONS, which it did not have before this story
## (the header's "a kind's own fields are all scalars" was true through 7-2). Plain conversions, all
## zero for a kind that authors none of them.
##
## THE MIN/MAX PAIRS ARE THE INCLUSIVE BOUNDS OF A SEEDED DRAW (`MatchState._rng.randi_range`), so
## `from_config` orders them: `max` is never below `min`, whatever the authoring says.
var reaction_ticks: int
var get_up_ticks: int
var back_off_min_ticks: int
var back_off_max_ticks: int
var circle_min_ticks: int
var circle_max_ticks: int
## Feel pass: the stalk's and the feint's drawn bounds (ordered like the pairs above), the feint's
## undrawn retreat, and how much of a reversing circle is left when it reverses.
var stalk_min_ticks: int
var stalk_max_ticks: int
var feint_min_ticks: int
var feint_max_ticks: int
var feint_retreat_ticks: int
var circle_flip_remaining_ticks: int
## Feel pass 2: the drawn bounds of the run-on, the reposition and the retreat (ordered like the
## pairs above).
var run_on_min_ticks: int
var run_on_max_ticks: int
var reposition_min_ticks: int
var reposition_max_ticks: int
var retreat_min_ticks: int
var retreat_max_ticks: int
## Feel pass 3: the orbit's drawn bounds (ordered like the pairs above).
var orbit_min_ticks: int
var orbit_max_ticks: int
## `UnitKindProfile.circle_wobble_seconds` in ticks: the period the circle's radius breathes over.
## Actor-side motion data, like the bark interval below; no `advance()` seat reads it.
var circle_wobble_ticks: int
## `UnitKindProfile.bark_interval_seconds` in ticks. Presentation-only; no `advance()` seat reads it.
var bark_interval_ticks: int


## The derived tick record at `index`, or NULL when this kind has none — `UnitKindProfile.attack_at`
## verbatim, for its reason verbatim: a total function's honest default rather than a crash, so a
## kind that authors no attack simply never attacks. The two are read in pairs at every seat, so a
## divergence in their null behaviour would be a divergence in one seat's guard.
func attack_at(index: int) -> UnitAttackTicks:
	if index < 0 or index >= attacks.size():
		return null
	return attacks[index]
