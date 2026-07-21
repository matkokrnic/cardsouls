class_name TimingWindow
extends RefCounted

## D4 fairness-core primitive. A single pure state-layer timer/window that COUNTS
## INTEGER PHYSICS TICKS (A1) — never an accumulated float. Replay determinism (F2/X5)
## must not depend on delta being exactly 1/60, nor drift via float addition over long
## windows. Every chargeup / defense-window / stun / fizzle is this one type, advanced
## one tick per call in advance() step 2 (D2). No engine Timer/SceneTreeTimer nodes.

const TICK_HZ := 60.0

var _duration_ticks := 0
var _elapsed_ticks := 0
var is_running := false


## Convert a configured seconds duration to a tick count. Done ONCE at balance load /
## X3 reload, never per tick. round() (not floor/ceil); any non-zero duration clamps to
## >= 1 tick so a sub-tick window still opens rather than never firing.
static func seconds_to_ticks(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	return maxi(1, int(round(seconds * TICK_HZ)))


## Snapshots the duration. A window already running keeps its duration across a balance
## hot-reload — the new value is picked up only at the next start() (D4/A1).
func start(duration_ticks: int) -> void:
	_duration_ticks = duration_ticks
	_elapsed_ticks = 0
	is_running = duration_ticks > 0


## Advance one physics tick. Magnitude-free by design (no delta).
func tick() -> void:
	if not is_running:
		return
	_elapsed_ticks += 1
	if _elapsed_ticks >= _duration_ticks:
		is_running = false


func remaining_ticks() -> int:
	return maxi(0, _duration_ticks - _elapsed_ticks)


func to_snapshot() -> Dictionary:
	return {
		"duration_ticks": _duration_ticks,
		"elapsed_ticks": _elapsed_ticks,
		"is_running": is_running,
	}
