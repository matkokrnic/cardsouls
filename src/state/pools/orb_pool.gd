class_name OrbPool
extends RefCounted

## D1 economy pool for the three card colors (RED/BLUE/GREEN orbs). RESERVED / flag-off
## until E5 — the RPS grant/spend machinery is deferred, but the storage exists now so E5
## wiring is trivial. Layer gating happens at the economy/resolution layer, not here (a
## pool is dumb storage). Emits via SignalQueue (D5).

signal orbs_changed(red: int, blue: int, green: int)

var _red := 0
var _blue := 0
var _green := 0
var _queue: SignalQueue


func _init(queue: SignalQueue) -> void:
	_queue = queue


func get_count(color: Enums.CardColor) -> int:
	match color:
		Enums.CardColor.RED: return _red
		Enums.CardColor.BLUE: return _blue
		Enums.CardColor.GREEN: return _green
	return 0


func add(color: Enums.CardColor, amount: int) -> void:
	match color:
		Enums.CardColor.RED: _red = maxi(0, _red + amount)
		Enums.CardColor.BLUE: _blue = maxi(0, _blue + amount)
		Enums.CardColor.GREEN: _green = maxi(0, _green + amount)
	_queue.push(orbs_changed.emit.bind(_red, _blue, _green))


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
