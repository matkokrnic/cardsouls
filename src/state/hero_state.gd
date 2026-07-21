class_name HeroState
extends RefCounted

## D1 hero state: HP, action state, intended velocity, facing, and the D4 timing windows.
## Pure RefCounted — no scene, no Input, no position (position is actor-owned, F1).
##
## MOVEMENT SEAM (D3): `velocity` is the INTENDED velocity, computed in advance() from the
## player's InputIntent. The runner reads THIS field and calls move_and_slide — it must
## never read the intent's direction and move the actor directly (that would bypass D3).

signal hp_changed(current: float, maximum: float)
signal action_state_changed(state: ActionState)

## Souls action states — few and timing-gated, kept as a pure enum in the state layer so
## transitions stay in the deterministic tick and under headless test (chosen over a
## scene-coupled StateMachine node).
enum ActionState { IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING }

var action_state: ActionState = ActionState.IDLE
var velocity := Vector3.ZERO   # intended velocity; the runner reads this (D3), not the intent
var facing := Vector2.DOWN     # planar facing
var move_speed: float          # injected (balance .tres in E3); tunable, not hardcoded-in-place

var chargeup := TimingWindow.new()
var defense := TimingWindow.new()
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


func set_action_state(new_state: ActionState) -> void:
	if new_state == action_state:
		return
	action_state = new_state
	_queue.push(action_state_changed.emit.bind(new_state))


## Advance all D4 windows one tick (called from advance() step 2).
func tick_timers() -> void:
	chargeup.tick()
	defense.tick()
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
		"chargeup": chargeup.to_snapshot(),
		"defense": defense.to_snapshot(),
		"stun": stun.to_snapshot(),
	}
