class_name PitchState
extends RefCounted

## D8 sole owner of the fizzle shared-deadline. RESERVED seam — the machinery lands in E6.
## The fizzle deadline is a D4 TimingWindow owned here; every system QUERIES this object,
## none holds its own copy of fizzle time (Binding Constraint #4). Nothing is staged at E0.

var _fizzle := TimingWindow.new()  # reserved; not started until E6


func to_snapshot() -> Dictionary:
	return {"fizzle": _fizzle.to_snapshot()}
