class_name StaminaPool
extends RefCounted

## D1 economy pool: owns its value, its bounds, and its own typed signal. Pure RefCounted;
## emits via the shared SignalQueue (D5) so nothing fires mid-advance().
##
## Story 1-4: also owns the regen MECHANISM — a fixed per-tick amount plus the post-spend
## delay window (integer ticks, D4/A1). POLICY stays with the caller: amounts, delay
## durations, and any state-based suppression (D6 BLOCKING) arrive per call from
## MatchState — the pool never sees action states or a BalanceTicks object (CONSTRAINT C).

signal stamina_changed(current: float, maximum: float)

var _current: float
var _maximum: float
var _queue: SignalQueue
## Post-spend regen-delay window, restarted by every successful spend(). Snapshotted —
## a mid-count window excluded from the snapshot would be a determinism/replay hole (D8).
var _regen_delay := TimingWindow.new()


func _init(queue: SignalQueue, maximum: float, current: float) -> void:
	_queue = queue
	_maximum = maximum
	_current = clampf(current, 0.0, maximum)


func add(amount: float) -> void:
	var v := clampf(_current + amount, 0.0, _maximum)
	if is_equal_approx(v, _current):
		return
	_current = v
	_queue.push(stamina_changed.emit.bind(_current, _maximum))


## Spend if affordable; returns false and changes nothing otherwise (a refused spend does
## NOT restart the delay window). Every successful spend restarts the regen-delay window;
## the caller reads regen_delay_ticks inline from balance_ticks at the moment of the spend
## (CONSTRAINT C). 0 ticks = no delay (legitimate tuning, the window never runs). NO
## default on purpose: every deduction path (roll now, deflect in 1-8) must state its
## delay explicitly — a forgotten argument is a compile error, not a silent no-delay.
func spend(amount: float, regen_delay_ticks: int) -> bool:
	if amount > _current:
		return false
	add(-amount)
	_regen_delay.start(regen_delay_ticks)
	return true


## Advance the regen-delay window one tick. Called in advance() step 2 alongside the
## hero's D4 windows (ORDER CONTRACT: timers advance FIRST, step 5 reads the advanced
## result) — mirrors HeroState.tick_timers(). Inert while no window is running.
func tick_timers() -> void:
	_regen_delay.tick()


## Step-5 regen (story 1-4): apply the fixed per-tick amount unless the post-spend delay
## window is still counting or the caller suppresses this tick. The window was advanced in
## step 2 (tick_timers) like every other D4 window — this only READS the advanced result,
## so an authored delay of N ticks suppresses exactly N ticks starting with the spend tick.
## `suppressed` carries the caller's policy (MatchState: hero is BLOCKING, D6) — the pool
## only implements the mechanism; the window counts through suppressed ticks (wall time).
func advance_regen(amount_per_tick: float, suppressed: bool) -> void:
	if _regen_delay.is_running or suppressed:
		return
	add(amount_per_tick)


## D9 (story 1-4): apply_balance() starts the pool FULL at the authored maximum.
func refill() -> void:
	add(_maximum)


func get_current() -> float:
	return _current


func get_maximum() -> float:
	return _maximum


## X3 hot-reload: re-inject bounds, re-clamp + re-signal if the max shrank.
func set_maximum(maximum: float) -> void:
	_maximum = maximum
	add(0.0)


func to_snapshot() -> Dictionary:
	return {
		"current": _current,
		"maximum": _maximum,
		"regen_delay": _regen_delay.to_snapshot(),
	}
