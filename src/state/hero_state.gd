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
## Story 1-4 loss legibility (D5): a press REJECTED by a transition precondition — in E1
## the stamina-gated roll ONLY. The 1-3 capped-chain reject stays silent; widening this
## signal to cover it is a separate decision, not an implementation detail. Emitted queued,
## even when a lower-priority action succeeds the same tick. NO runner seam until the first
## consumer (1-10 — seam obligation recorded in the decision-log).
signal action_rejected(action: StringName, reason: StringName)

## Souls action states — few and timing-gated, kept as a pure enum in the state layer so
## transitions stay in the deterministic tick and under headless test (chosen over a
## scene-coupled StateMachine node). DEAD (story 1-7, D-3) is APPENDED so the existing
## snapshot int values never shift.
enum ActionState { IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING, DEAD }

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
## DEAD (story 1-7, D-3): row present, accepts nothing, zero inbound TABLE edges — entry
## is ONLY MatchState's step-8 resolution (a non-table path), exit is ONLY the D-1 debug
## reset. Guarded by the same inbound-edge enumeration test.
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
	&"dead": {},                # accepts no input — enter via step-8 resolution, exit via reset ONLY
}

## Fixed evaluation order for same-tick simultaneous presses (deterministic tiebreak).
const INPUT_PRIORITY: Array[StringName] = [&"attack", &"roll", &"block"]

var action_state: ActionState = ActionState.IDLE
## 0-based swing index within the current attack sequence (story 1-3). Increments on a
## chain (ATTACKING -> ATTACKING); resets to 0 on ANY exit from ATTACKING to a
## non-ATTACKING state (roll-cancel included — a cancelled chain never resumes).
var chain_index: int = 0
## Story 1-5 (B7b): MONOTONIC swing counter — the dedupe key. Unlike chain_index it never
## resets: every swing (fresh or chained) gets a unique index for the life of the match,
## so a stale contact fact can never collide with a later swing's record. -1 = no swing
## yet. The runner (1-7) stamps gathered facts with this value.
var attack_index: int = -1
var velocity := Vector3.ZERO   # intended velocity; the runner reads this (D3), not the intent
## WORLD-SPACE planar facing (world x, z) — story 1-7 review R1: assigned from the same
## camera-rotated world direction the velocity uses, so actor-side consumers (the hitbox
## yaw in HeroActor.drive) need no basis knowledge. Under an identity basis it equals the
## raw intent direction. Freezes while movement input is zero.
var facing := Vector2.DOWN
## Story 1-9 (1-9/R6): WORLD-SPACE unit roll direction, captured ONCE at ROLLING entry
## (camera-rotated move_dir; facing fallback when the stick is neutral — MatchState
## computes, enter_roll stores). Locked for the whole roll: _resolve_movement reads THIS
## while ROLLING instead of live input. SNAPSHOTTED (the one 1-9 snapshot delta) — it is
## read across ticks, so excluding it would be a determinism/replay hole.
var roll_direction := Vector3.ZERO
var move_speed: float          # injected (balance .tres in E3); tunable, not hardcoded-in-place

## The eight per-action D4 windows (story 1-3). windup/active/recovery are the phases of
## one attack swing; chain is the input window for ATTACKING -> ATTACKING; deflect opens at
## BLOCKING entry when the deflect cost is affordable (R-D1, story 1-8) and is read by the
## step-4 resolution with a +1 grace tick (R-N2); roll_iframe/roll_duration at ROLLING
## entry (1-9).
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

## Story 1-8 (R-N2): TRANSIENT grace marker — true only on the single tick whose step-2
## advance closed the deflect window, so a contact that physically happened on the
## window's last running tick and arrives one tick late (the F1 fact lag) still deflects
## (the dedupe-grace precedent). Write-before-read within every advance(): step 2
## recomputes it, step 4 reads it, and nothing reads it across ticks — so it is
## deliberately EXCLUDED from to_snapshot(): no determinism/replay hole, because replay
## recomputes it identically inside each tick before any consumer runs.
var _deflect_closed_this_tick := false

## Story 1-9 (1-9/R2): TRANSIENT grace marker — true only on the single tick whose step-2
## advance closed the roll_iframe window (the _deflect_closed_this_tick mirror, absorbing
## the same F1 one-tick fact lag). Write-before-read within every advance(): step 2
## recomputes it, step 4 reads it, and nothing reads it across ticks — so it is
## deliberately EXCLUDED from to_snapshot(): no determinism/replay hole, because replay
## recomputes it identically inside each tick before any consumer runs.
var _roll_iframe_closed_this_tick := false

## Story 1-5 (B7b/N2): per-swing dedupe records, keyed by attack_index. Each record is
## {"hit": Array[int] of target slots already damaged this swing, "grace": int}. grace
## semantics: -1 = the swing's active window has not closed yet (record alive); 1 = window
## closed, record lives exactly ONE more tick (absorbs the F1 one-tick fact lag — a
## contact gathered on the last active tick arrives the tick after close and is still
## legitimate); decremented in tick_timers(), erased at 0. A fact is accepted iff its
## attack_index has a record here AND its target is not already in that record's hit list.
## SNAPSHOTTED (D8): mid-swing dedupe state excluded from the snapshot would be a
## determinism/replay hole. Multiple records can be alive at once — a chain pressed on the
## first recovery tick starts a new swing while the old record is still in its grace tick.
var _swing_dedupe: Dictionary = {}


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


## Queued action_rejected emission (story 1-4, D5). Called by MatchState's step-3
## evaluation when a gated edge rejects a press; the reason vocabulary is the call site's.
func reject_action(action: StringName, reason: StringName) -> void:
	_queue.push(action_rejected.emit.bind(action, reason))


## Story 1-5 (N3): DERIVED accessor, no stored flag — same "phases are derived, not
## stored" family as attack_phase(). True iff the attack active window is running, which
## only happens during ATTACKING. Actor-side consumption (the runner gathering overlaps
## for state-flagged-active hitboxes) is 1-7 scope.
func is_hitbox_active() -> bool:
	return active.is_running


## Story 1-8 (R-N2): the deflect window as step-4 resolution judges it — running, OR
## closed by this very tick's step-2 advance (+1 grace tick). DERIVED from the window
## plus the per-tick transient; no stored deflect-consumed state exists (each deflect
## pays per landing, R-N7 — the window is never latched shut by a hit).
func is_deflect_window_open() -> bool:
	return deflect.is_running or _deflect_closed_this_tick


## Story 1-9 (1-9/R2/R3): the iframe window as step-4 resolution judges it — running, OR
## closed by this very tick's step-2 advance (+1 grace tick). Judged on the window ALONE,
## never on state == ROLLING (1-9/R3): the authoring audit bounds iframe <= duration and
## both roll windows start only in enter_roll with no early-stop path, so the window
## cannot legitimately outlive the roll — any future early-stop path must re-open that
## ruling.
func is_iframe_open() -> bool:
	return roll_iframe.is_running or _roll_iframe_closed_this_tick


## Story 1-5 (B7b): dedupe acceptance + registration, called by MatchState's step-4
## contact resolution for THIS hero as the attacker. Returns true iff the fact's
## attack_index matches a live dedupe record AND this swing has not already damaged
## target_slot — and then records the target, so a second same-swing contact returns
## false. A false return means the fact is DROPPED (stale, unknown, or duplicate).
func register_swing_hit(index: int, target_slot: int) -> bool:
	if not _swing_dedupe.has(index):
		return false
	var hit: Array = _swing_dedupe[index]["hit"]
	if target_slot in hit:
		return false
	hit.append(target_slot)
	return true


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
		ActionState.DEAD:
			return &"dead"
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


## Story 1-9 (1-9/R6): `direction` is the entry-captured world-space unit roll direction
## (MatchState computes the camera rotation and the facing fallback — policy stays in the
## evaluator; this only stores). Both windows open here and ONLY here (1-9/R3 obligation).
func enter_roll(duration_ticks: int, iframe_ticks: int, direction: Vector3) -> void:
	set_action_state(ActionState.ROLLING)
	roll_direction = direction
	roll_duration.start(duration_ticks)
	roll_iframe.start(iframe_ticks)


## Story 1-8 (R-D1): open_deflect_window carries the entry-time affordability
## PRECONDITION result — MatchState checks (policy), this only acts. The degraded path
## start(0)-clears the window so a still-running window from an earlier block press can
## never arm a block the hero could not afford. Entry itself never spends (BLOCKING
## entry is FREE — the locked 1-4 ruling).
func enter_block(deflect_window_ticks: int, open_deflect_window: bool) -> void:
	set_action_state(ActionState.BLOCKING)
	if open_deflect_window:
		deflect.start(deflect_window_ticks)
	else:
		deflect.start(0)


## One swing: windup starts; successor windows are start(0)-cleared so attack_phase() can
## tell "not yet run this swing" (elapsed 0) from "finished" (elapsed > 0). Story 1-5:
## every swing also claims the next attack_index and opens its dedupe record.
func _start_swing(windup_ticks: int) -> void:
	attack_index += 1
	_swing_dedupe[attack_index] = {"hit": [], "grace": -1}
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
## flip this order. Story 1-5: the dedupe lifetime rides the same step — expired graces
## are cleared FIRST (a grace set on tick N survives through tick N's step 4 and dies in
## tick N+1's step 2), then an active window that just closed puts the current swing's
## record into its 1-tick grace.
func tick_timers() -> void:
	var was_active := active.is_running
	var deflect_was_running := deflect.is_running
	var iframe_was_running := roll_iframe.is_running
	windup.tick()
	active.tick()
	recovery.tick()
	chain.tick()
	deflect.tick()
	# Story 1-8 (R-N2): recomputed EVERY tick — true only when THIS step-2 advance
	# closed the window (see the field's transient/no-snapshot contract).
	_deflect_closed_this_tick = deflect_was_running and not deflect.is_running
	roll_iframe.tick()
	# Story 1-9 (1-9/R2): recomputed EVERY tick — true only when THIS step-2 advance
	# closed the window (see the field's transient/no-snapshot contract).
	_roll_iframe_closed_this_tick = iframe_was_running and not roll_iframe.is_running
	roll_duration.tick()
	stun.tick()
	for index in _swing_dedupe.keys():
		var grace := int(_swing_dedupe[index]["grace"])
		if grace > 0:
			grace -= 1
			if grace == 0:
				_swing_dedupe.erase(index)
			else:
				_swing_dedupe[index]["grace"] = grace
	if was_active and not active.is_running:
		_swing_dedupe[attack_index]["grace"] = 1


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
		# Story 1-5: the ONE snapshot delta of the story (D8) — the monotonic swing
		# counter plus the live dedupe records (deep copy: the snapshot must be a value,
		# not a live handle into state).
		"swing_dedupe": {
			"attack_index": attack_index,
			"records": _swing_dedupe.duplicate(true),
		},
		"velocity": velocity,
		"facing": facing,
		# Story 1-9: the ONE snapshot delta of the story — the entry-locked roll direction.
		"roll_direction": roll_direction,
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
