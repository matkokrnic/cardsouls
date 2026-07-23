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

## ---------------------------------------------------------------------------------------
## TRANSITION TABLE (story 1-3) — the single readable block. Cancellability is DATA here,
## never scattered ifs. Rows are the state/phase the hero is IN (ATTACKING is split into
## its three phases — windup/active/recovery — derived from which window is running, see
## attack_phase()); columns map an InputIntent press to the TARGET state of that edge.
## A press whose action has no entry in the current row is DROPPED, never buffered (AC 5).
##
## E1 convention (AC 3): windup and active are non-cancellable; recovery accepts attack
## (= chain, gated by the chain window + attack_chain_length) and roll (roll-cancel).
## BLOCKING/ROLLING exit on release/expiry, which are not input edges.
##
## STUNNED: row PRESENT but UNREACHABLE — zero inbound edges anywhere in E1. Entering
## STUNNED would resolve OPEN decision (a) (attacker consequence on deflect, decision-log
## Session 2026-07-22) by accident; stun stays data only. Guarded by the inbound-edge
## enumeration test in test_action_state.gd.
## CHARGING: reserved for E5 — no row, no inbound edge; deliberately absent, not stubbed.
##
## MatchState step 3 EVALUATES this table (reading balance_ticks inline, CONSTRAINT C);
## the table data itself lives here, next to the enum, per the architecture decision.
const TRANSITION_TABLE: Dictionary = {
	&"idle": {
		&"attack": ActionState.ATTACKING,
		&"roll": ActionState.ROLLING,
		&"block": ActionState.BLOCKING,
	},
	&"attacking_windup": {},    # non-cancellable
	&"attacking_active": {},    # non-cancellable
	&"attacking_recovery": {
		&"attack": ActionState.ATTACKING,  # chain — gated by chain window + chain length
		&"roll": ActionState.ROLLING,      # roll-cancel
	},
	&"blocking": {},            # exits on block release, not via an input edge
	&"rolling": {},             # exits on roll_duration expiry
	&"stunned": {},             # accepts no input — and nothing may transition IN (E1)
}

## Fixed evaluation order for same-tick simultaneous presses (deterministic tiebreak).
const INPUT_PRIORITY: Array[StringName] = [&"attack", &"roll", &"block"]

var action_state: ActionState = ActionState.IDLE
## 0-based swing index within the current attack sequence (story 1-3). Increments on a
## chain (ATTACKING -> ATTACKING); resets to 0 on ANY exit from ATTACKING to a
## non-ATTACKING state (roll-cancel included — a cancelled chain never resumes).
var chain_index: int = 0
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
	if previous == ActionState.ATTACKING:
		chain_index = 0  # any exit to a non-ATTACKING state ends the sequence for good
	action_state = new_state
	_queue.push(action_state_changed.emit.bind(previous, new_state))


## Derived attack phase. Phases are expressed by WHICH WINDOW IS RUNNING (AC 1) — no
## stored phase field, so the snapshot stays exactly the windows + chain_index. On a
## phase-boundary tick (step 2 stopped a window, step 3 has not yet started the next) all
## three are stopped; the *_done value tells the evaluator which phase just ended, derived
## from elapsed_ticks (each swing start(0)-clears its successors, so elapsed > 0 means
## "has run this swing"). Assumes phase durations >= 1 tick — seconds_to_ticks clamps any
## non-zero authored value; a 0.0-authored phase duration is a config authoring error.
func attack_phase() -> StringName:
	if windup.is_running:
		return &"windup"
	if active.is_running:
		return &"active"
	if recovery.is_running:
		return &"recovery"
	if _has_run(recovery):
		return &"attack_done"
	if _has_run(active):
		return &"active_done"
	return &"windup_done"


## Row key into TRANSITION_TABLE for the current state/phase.
func transition_row() -> StringName:
	match action_state:
		ActionState.ATTACKING:
			match attack_phase():
				&"windup", &"windup_done":
					return &"attacking_windup"
				&"active", &"active_done":
					return &"attacking_active"
				_:
					return &"attacking_recovery"
		ActionState.BLOCKING:
			return &"blocking"
		ActionState.ROLLING:
			return &"rolling"
		ActionState.STUNNED:
			return &"stunned"
		ActionState.CHARGING:
			return &"charging"  # no table row -> accepts nothing (reserved E5)
	return &"idle"


## --- Entry actions -------------------------------------------------------------------
## Tick counts are INJECTED by MatchState, read from balance_ticks at the moment of the
## transition (CONSTRAINT C) — HeroState never caches durations or a BalanceTicks ref.

## Fresh attack sequence from a non-ATTACKING state.
func enter_attack(windup_ticks: int) -> void:
	set_action_state(ActionState.ATTACKING)
	chain_index = 0
	_start_swing(windup_ticks)


## Chain: the ATTACKING -> ATTACKING table edge. A self-transition is still a transition
## and emits (AC 4) — set_action_state() no-ops on the same state, so the queued emit is
## explicit here.
func chain_attack(windup_ticks: int) -> void:
	chain_index += 1
	_start_swing(windup_ticks)
	_queue.push(action_state_changed.emit.bind(ActionState.ATTACKING, ActionState.ATTACKING))


func enter_roll(duration_ticks: int, iframe_ticks: int) -> void:
	set_action_state(ActionState.ROLLING)
	roll_duration.start(duration_ticks)
	roll_iframe.start(iframe_ticks)


func enter_block(deflect_window_ticks: int) -> void:
	set_action_state(ActionState.BLOCKING)
	deflect.start(deflect_window_ticks)


## One swing: windup starts; successor windows are start(0)-cleared so attack_phase() can
## tell "not yet run this swing" (elapsed 0) from "finished" (elapsed > 0).
func _start_swing(windup_ticks: int) -> void:
	windup.start(windup_ticks)
	active.start(0)
	recovery.start(0)
	chain.start(0)


## True if this window has run at all since its last start(). Reads via to_snapshot() so
## TimingWindow stays unchanged (story constraint); only called on phase-boundary ticks,
## so the tiny Dictionary is not a hot-path allocation.
static func _has_run(w: TimingWindow) -> bool:
	return int(w.to_snapshot()["elapsed_ticks"]) > 0


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
		"chain_index": chain_index,
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
