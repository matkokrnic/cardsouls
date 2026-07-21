class_name SignalQueue
extends RefCounted

## D5 timing discipline: signals raised during advance() are ENQUEUED here (a bound
## emit Callable), then DRAINED after advance() returns (runner step 5). Nothing emits
## mid-tick, so no presentation consumer can ever observe half-advanced state.
##
## Transient plumbing — NOT persistent state, so it deliberately has no to_snapshot()
## (excluded from the determinism hash; see arch Determinism & Replay).

var _pending: Array[Callable] = []


func push(emitter: Callable) -> void:
	_pending.append(emitter)


func drain() -> void:
	var batch := _pending
	_pending = []  # swap-out first: re-entrant safe if an emit pushes again
	for emit_call in batch:
		emit_call.call()


func is_empty() -> bool:
	return _pending.is_empty()
