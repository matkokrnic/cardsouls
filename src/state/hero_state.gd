class_name HeroState
extends RefCounted

## D1 hero state: HP, action state, intended velocity, facing, and the D4 timing windows.
## Pure RefCounted — no scene, no Input, no position (position is actor-owned, F1).
##
## MOVEMENT SEAM (D3): `velocity` is the INTENDED velocity, computed in advance() from the
## player's InputIntent. The runner reads THIS field and calls move_and_slide — it must
## never read the intent's direction and move the actor directly (that would bypass D3).

signal hp_changed(current: float, maximum: float)
## Story 1-3 migration: was single-arg (state); now carries (previous, current) so the
## presentation layer (1-10) and HUD (E2) can react to edges, not just arrivals. This is
## the ONLY channel telling visuals what the hero is doing.
signal action_state_changed(previous: ActionState, current: ActionState)

## Souls action states — few and timing-gated, kept as a pure enum in the state layer so
## transitions stay in the deterministic tick and under headless test (chosen over a
## scene-coupled StateMachine node).
enum ActionState { IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING }

var action_state: ActionState = ActionState.IDLE
var velocity := Vector3.ZERO   # intended velocity; the runner reads this (D3), not the intent
var facing := Vector2.DOWN     # planar facing
var move_speed: float          # injected (balance .tres in E3); tunable, not hardcoded-in-place

## The eight per-action D4 windows (story 1-3). windup/active/recovery are the phases of
## one attack swing; chain is the input window for ATTACKING -> ATTACKING; deflect opens at
## BLOCKING entry (consumed in 1-8); roll_iframe/roll_duration at ROLLING entry (1-9).
## stun is owned and advanced but NEVER start()ed by any E1 path — see TRANSITION TABLE.
## Durations are always injected by MatchState from balance_ticks at start() time
## (CONSTRAINT C) — HeroState never sees a BalanceTicks object.
var windup := TimingWindow.new()
var active := TimingWindow.new()
var recovery := TimingWindow.new()
var chain := TimingWindow.new()
var deflect := TimingWindow.new()
var roll_iframe := TimingWindow.new()
var roll_duration := TimingWindow.new()
var stun := TimingWindow.new()

var _hp: float
var _max_hp: float
var _queue: SignalQueue


func _init(queue: SignalQueue, max_hp: float, move_speed_value: float) -> void:
	_queue = queue
	_max_hp = max_hp
	_hp = max_hp
	move_speed = move_speed_value


func take_damage(amount: float) -> void:
	_set_hp(_hp - amount)


func heal(amount: float) -> void:
	_set_hp(_hp + amount)


func is_alive() -> bool:
	return _hp > 0.0


func get_hp() -> float:
	return _hp


func get_max_hp() -> float:
	return _max_hp


## X3 hot-reload: re-inject the HP bound (set_maximum-style: re-clamp + re-signal if the
## max shrank) — same pattern as the economy pools.
func set_max_hp(maximum: float) -> void:
	_max_hp = maximum
	_set_hp(_hp)


func set_action_state(new_state: ActionState) -> void:
	if new_state == action_state:
		return
	var previous := action_state
	action_state = new_state
	_queue.push(action_state_changed.emit.bind(previous, new_state))


## Advance all D4 windows one tick (called from advance() step 2). ORDER CONTRACT (AC 2):
## timers advance FIRST (step 2), transitions read the advanced result (step 3) — never
## flip this order.
func tick_timers() -> void:
	windup.tick()
	active.tick()
	recovery.tick()
	chain.tick()
	deflect.tick()
	roll_iframe.tick()
	roll_duration.tick()
	stun.tick()


func _set_hp(value: float) -> void:
	var v := clampf(value, 0.0, _max_hp)
	if is_equal_approx(v, _hp):
		return
	_hp = v
	_queue.push(hp_changed.emit.bind(_hp, _max_hp))


func to_snapshot() -> Dictionary:
	return {
		"hp": _hp,
		"max_hp": _max_hp,
		"action_state": int(action_state),
		"velocity": velocity,
		"facing": facing,
		"move_speed": move_speed,
		"windup": windup.to_snapshot(),
		"active": active.to_snapshot(),
		"recovery": recovery.to_snapshot(),
		"chain": chain.to_snapshot(),
		"deflect": deflect.to_snapshot(),
		"roll_iframe": roll_iframe.to_snapshot(),
		"roll_duration": roll_duration.to_snapshot(),
		"stun": stun.to_snapshot(),
	}
