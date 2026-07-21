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
