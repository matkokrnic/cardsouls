class_name ManaPool
extends RefCounted

## D1 economy pool: owns its value, bounds, and typed signal. Mana starts empty and is
## built by the flywheel (melee-hit / passive generation, D6). Emits via SignalQueue (D5).

signal mana_changed(current: float, maximum: float)

var _current: float
var _maximum: float
var _queue: SignalQueue


func _init(queue: SignalQueue, maximum: float, current: float) -> void:
	_queue = queue
	_maximum = maximum
	_current = clampf(current, 0.0, maximum)


func add(amount: float) -> void:
	var v := clampf(_current + amount, 0.0, _maximum)
	if is_equal_approx(v, _current):
		return
	_current = v
	_queue.push(mana_changed.emit.bind(_current, _maximum))


## Spend if affordable; returns false and changes nothing otherwise.
func spend(amount: float) -> bool:
	if amount > _current:
		return false
	add(-amount)
	return true


## Story 3-4 (AC 4): the PASSIVE regen mechanism — StaminaPool.advance_regen's shape, minus
## the post-spend delay window. The missing window is a SEALED design decision, not an
## oversight: mana has no spender until 3-2/3-5, so a delay analogous to stamina's would be
## dead machinery built speculatively; it arrives with the first spender if it is wanted.
## The pool owns the MECHANISM only — the amount and the `suppressed` policy (MatchState:
## DEAD suppresses, BLOCKING deliberately does NOT, D6) arrive per call, so this never sees
## an action state or a BalanceTicks object (CONSTRAINT C), exactly like the stamina twin.
##
## refill() STAYS ABSENT and must remain so: ManaPool's contract is that mana starts empty
## and is built by the flywheel, pinned by
## test_balance_config.gd::test_mid_match_reload_sets_mana_maximum_but_never_refills. This
## method adds a per-tick TRICKLE; it is not a back door to that.
func advance_regen(amount_per_tick: float, suppressed: bool) -> void:
	if suppressed:
		return
	add(amount_per_tick)


func get_current() -> float:
	return _current


func get_maximum() -> float:
	return _maximum


## X3 hot-reload: re-inject bounds, re-clamp + re-signal if the max shrank.
func set_maximum(maximum: float) -> void:
	_maximum = maximum
	add(0.0)


func to_snapshot() -> Dictionary:
	return {"current": _current, "maximum": _maximum}
