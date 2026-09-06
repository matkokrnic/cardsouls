class_name OrbPool
extends RefCounted

## D1 economy pool for the three card colors (RED/BLUE/GREEN orbs). The storage shipped ahead of
## its machinery ("RESERVED / flag-off until E5"); story 5-4 is the GRANT half arriving, and the
## SPEND half (`CastEvaluator._orbs_affordable`, mode (4) Pitch) is still E6. Layer gating happens
## at the economy/resolution layer, not here (a pool is dumb storage). Emits via SignalQueue (D5).
##
## STORY 5-4 (AC 8): the pool gains an authored per-colour MAXIMUM, on the `ManaPool._maximum`
## precedent -- ADAPTED, not copied. Two deliberate divergences from the mana twin:
##   * `_max` is SENTINEL-DEFAULTED to `NO_MAXIMUM` (-1), the same "no such thing" sentinel family
##     as `PlayerState.NO_TELEGRAPH_COLOR`, and -1 means "no bound" rather than "bound at zero". A
##     pre-injection OrbPool is therefore genuinely UNBOUNDED, not inert: it is constructed by
##     `PlayerState._init` before any balance exists, and test_economy_and_hero.gd /
##     test_cast_evaluator.gd both exercise that real pre-injection behaviour (they add orbs to a
##     pool nothing injected a bound into and expect them to be THERE). Injection always supplies
##     the real non-negative bound, so `_max` reads -1 only before the very first apply_balance.
##   * `to_snapshot()` does NOT carry the maximum, where `ManaPool.to_snapshot()` DOES (AC 12).
##     Deliberate: mana's maximum is itself injectable/reloadable content a replay must reproduce
##     identically, while this bound is a fixed authored constant with no reload path this story
##     adds. It is authored CONFIG, not state, and never enters the determinism hash.

signal orbs_changed(red: int, blue: int, green: int)

## Story 5-4 (AC 8): "no bound has been injected yet", NOT "bounded at zero". Same sentinel family
## as `PlayerState.NO_TELEGRAPH_COLOR` and `BalanceConfig.NO_KIND_INDEX` -- every reader tests the
## NAME, never a bare -1.
const NO_MAXIMUM := -1

var _red := 0
var _blue := 0
var _green := 0
## The authored per-colour ceiling, applied to each colour INDEPENDENTLY. `NO_MAXIMUM` until the
## first `set_maximum` (i.e. the first `MatchState.apply_balance`).
var _max := NO_MAXIMUM
var _queue: SignalQueue


func _init(queue: SignalQueue) -> void:
	_queue = queue


func get_count(color: Enums.CardColor) -> int:
	match color:
		Enums.CardColor.RED: return _red
		Enums.CardColor.BLUE: return _blue
		Enums.CardColor.GREEN: return _green
	return 0


## Story 5-4 (AC 8): CLAMPED PER COLOUR, INDEPENDENTLY, and SHORT-CIRCUITED ON NO CHANGE.
##
## The short circuit mirrors `ManaPool.add`'s own (`mana_pool.gd:22-23`) exactly, and it is
## load-bearing rather than tidy: `set_maximum` below re-clamps all three colours by calling this
## with a zero amount, so without it a single injection would push up to three spurious
## `orbs_changed` events per player into the observation channel `match_runner.connect_orbs_changed`
## opened for the HUD and the earn cue. An earn cue derived from "a count went up" would be
## unaffected, but a channel that reports changes that did not happen is wrong the moment anything
## consumes it.
##
## `NO_MAXIMUM` is UNBOUNDED, not zero-bounded (see the header): the pre-injection pool still
## accumulates, it simply has no ceiling to hit. The floor is 0 in both branches -- a pool cannot
## go negative, which is what makes the E6 spend path's future `add(-n)` safe by construction.
##
## An unrecognised colour is a genuine NO-OP: it reaches the `_` arm and returns without signalling,
## rather than falling through to an emit that reports a change nothing made.
func add(color: Enums.CardColor, amount: int) -> void:
	var current := get_count(color)
	var updated := current + amount
	updated = clampi(updated, 0, _max) if _max >= 0 else maxi(0, updated)
	if updated == current:
		return
	match color:
		Enums.CardColor.RED: _red = updated
		Enums.CardColor.BLUE: _blue = updated
		Enums.CardColor.GREEN: _green = updated
		_: return
	_queue.push(orbs_changed.emit.bind(_red, _blue, _green))


## Story 5-4 (AC 8/AC 10): re-inject the authored per-colour bound. The `ManaPool.set_maximum ->
## add(0.0)` re-clamp idiom, once per colour and in a FIXED order (determinism): a shrunk bound
## re-clamps every colour's CURRENT count down into it and signals ONCE per colour that actually
## moved, while a colour already inside the bound signals nothing (the short circuit above).
##
## NEVER A REFILL -- the mana contract, not the stamina one. Orbs start at their pre-injection value
## re-clamped into the new bound. A match start still yields EMPTY orbs because a fresh PlayerState
## constructs its OrbPool at all-zero, not because injection zeroes it.
func set_maximum(max_count: int) -> void:
	_max = max_count
	add(Enums.CardColor.RED, 0)
	add(Enums.CardColor.BLUE, 0)
	add(Enums.CardColor.GREEN, 0)


func get_maximum() -> int:
	return _max


## Activating a Pitch Effect resets ALL three colors to 0, not just the spent color
## (TDD 8.2 — an easy-to-break invariant). E6 resolution calls this.
func reset_all() -> void:
	if _red == 0 and _blue == 0 and _green == 0:
		return
	_red = 0
	_blue = 0
	_green = 0
	_queue.push(orbs_changed.emit.bind(_red, _blue, _green))


func to_snapshot() -> Dictionary:
	return {"red": _red, "blue": _blue, "green": _green}
