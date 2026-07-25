class_name MatchState
extends RefCounted

## D1/D2 root of the pure state layer. Owns the two PlayerStates, the reserved PitchState,
## the shared SignalQueue, and the single seeded gameplay RNG (F2). Pure RefCounted — no
## scene, no Input, no autoload, no wall-clock. The runner owns THIS object (no autoload
## for live state) and is the only thing that calls advance()/drain_signals().
##
## D2: advance(intents) is the ONE ordered call site that advances gameplay time. It only
## ENQUEUES signals; the runner drains them after it returns (D5).

## Owned by MatchState, relayed to the EventBus autoload by the runner (state never touches
## an autoload). loser_index: 0 = P1, 1 = P2.
signal round_ended(loser_index: int)

var p1: PlayerState
var p2: PlayerState
var pitch: PitchState        # reserved fizzle-deadline owner (D8), machinery in E6

## Injected via apply_balance() (story 1-1). `balance` holds the non-duration authored
## values; `balance_ticks` holds every `*_seconds` field pre-converted to integer ticks —
## the ONLY form in which those durations may be read inside advance() (A1).
var balance: BalanceConfig
var balance_ticks: BalanceTicks

var _queue: SignalQueue
var _rng: RandomNumberGenerator  # the ONLY randomness source in the state layer (F2/A2)
var _tick := 0
var _round_over := false

## Per-slot camera basis (story 1-2) — an input-like PUSHED spatial fact, same category as
## InputIntent: the runner reads each rig and pushes it here in step 2. Fixed two-slot
## array, one per player — NEVER a single global basis (SEAM CHOICE 2: split-screen stays a
## config change). EXCLUDED from to_snapshot() like the intent stream; while the camera is
## fixed (all of E1) the basis is deterministic, so X5 replay is unaffected. Defaults to
## identity: with no basis pushed (tick 0, headless tests) move_dir is world-space (AC 4).
var _camera_bases: Array[Basis] = [Basis.IDENTITY, Basis.IDENTITY]


## E0 constructs both players symmetrically (mirror match). When BalanceConfig lands (E3)
## these values arrive from the injected config; they are never hardcoded in-place here.
func _init(
	seed_value: int,
	max_hp: float,
	move_speed: float,
	max_stamina: float,
	max_mana: float,
) -> void:
	_queue = SignalQueue.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	p1 = PlayerState.new(_queue, max_hp, move_speed, max_stamina, max_mana)
	p2 = PlayerState.new(_queue, max_hp, move_speed, max_stamina, max_mana)
	pitch = PitchState.new()


## The single ordered dispatch (D2). intents = [p1_intent, p2_intent]. Enqueues signals
## only — never emits. Player order is fixed P1 -> P2 for determinism.
func advance(intents: Array[InputIntent]) -> void:
	var p1_intent := intents[0]
	var p2_intent := intents[1]
	_tick += 1

	# 1. Ingest intents        [no-op — attack/block/roll presses are read directly by the
	#                           step-3 transition evaluation]
	# 2. Advance D4 timers   (hero windows + each pool's regen-delay window — every window
	#    advances here, step 5 reads the result; unguarded like the hero timers, since a
	#    pre-injection MatchState never started a delay window)
	p1.hero.tick_timers()
	p2.hero.tick_timers()
	p1.stamina.tick_timers()
	p2.stamina.tick_timers()
	# 3. Resolve actions       per slot P1 -> P2: action transitions FIRST (a press on
	#    tick N takes effect on tick N), then intended velocity from move_dir. Transitions
	#    never read or write velocity — action/movement coupling lands in 1-5/1-9.
	_resolve_actions(p1, p1_intent)
	_resolve_movement(p1, p1_intent, 0)
	_resolve_actions(p2, p2_intent)
	_resolve_movement(p2, p2_intent, 1)
	# 4. Resolve contacts      [E1 hitbox->contact seam — none at E0]
	# 5. Resource generation   stamina regen (story 1-4), P1 -> P2. Implemented DIRECTLY —
	#    the D6 evaluator/rule schema is DEBT D (deferred, not abandoned; the 1-5 mana hook
	#    is the reconcile trigger). Same single null guard rationale as step 3: a
	#    pre-injection MatchState stays inert, no scattered checks below.
	if balance_ticks != null:
		_regen_stamina(p1)
		_regen_stamina(p2)
	# 6. Card / economy        [E3 card play/draw; E6 pitch resolution]
	# 7. Board update          [E4 minion/totem throttled-tick seam]
	# 8. Resolution check
	_check_resolution()


## X3 hot-reload seam (story 1-1): the runner passes the (re)loaded BalanceConfig here.
## Re-injects bounds set_maximum-style (re-clamp + re-signal, queued per D5) and
## re-converts every `*_seconds` duration ONCE via BalanceTicks. A TimingWindow already
## in flight keeps its original duration; the new tick counts take effect at its next
## start() (D4/A1). Player order fixed P1 -> P2 for determinism.
func apply_balance(config: BalanceConfig) -> void:
	balance = config
	balance_ticks = BalanceTicks.from_config(config)
	_apply_balance_to_player(p1, config)
	_apply_balance_to_player(p2, config)


## Runner step-2 push (story 1-2). slot: 0 = P1, 1 = P2 — out-of-range is a programming
## error (fixed-size fact; the array index asserts). State never reads the camera; it only
## receives this pushed value.
##
## LOAD-BEARING (DECISION A): while the camera is fixed (all of E1) the hero ROOT must
## never be rotated — body/facing rotation belongs on a child mesh node. The rig is a
## child of the hero root, so a rotated root would fold hero rotation into this pushed
## basis and break camera-relative "forward" (and the identity short-circuit in
## _resolve_movement). The runner therefore pushes the rig's LOCAL basis, guarded by
## test_root_rotation_isolation.gd; a story that needs a rotating root must decouple the
## rig from hero rotation deliberately (deferred DECISION B).
func set_camera_basis(slot: int, camera_basis: Basis) -> void:
	_camera_bases[slot] = camera_basis


## Emit all queued signals. Called by the runner AFTER advance() returns (D5).
func drain_signals() -> void:
	_queue.drain()


func to_snapshot() -> Dictionary:
	return {
		"tick": _tick,
		"rng_state": _rng.state,   # captured so the determinism hash catches RNG desync
		"round_over": _round_over,
		"p1": p1.to_snapshot(),
		"p2": p2.to_snapshot(),
		"pitch": pitch.to_snapshot(),
	}


## Step-3 transition evaluation (story 1-3). EVALUATES HeroState.TRANSITION_TABLE — the
## table data lives on HeroState next to the enum; this is only the evaluator. Durations
## are read from balance_ticks.<field> inline at the moment a transition fires and passed
## into the window's start() (CONSTRAINT C: never cache the BalanceTicks object — a
## running window keeps its old duration across a reload; the next start() picks up the
## new one, guarded by test_balance_config.gd).
func _resolve_actions(player: PlayerState, intent: InputIntent) -> void:
	# DEBT A deferral (story 1-3, deliberate): the runner never calls apply_balance() yet,
	# so in live play balance_ticks is null and actions are INERT until the follow-up
	# story wires apply_balance at match start + re-baselines the golden (both DEBT A
	# halves together). This is THE one guard — no scattered null checks below it.
	if balance_ticks == null:
		return
	var hero := player.hero
	# (a) Timer-driven progression/exits — windows were advanced in step 2; read results.
	match hero.action_state:
		HeroState.ActionState.ATTACKING:
			match hero.attack_phase():
				&"windup_done":
					hero.active.start(balance_ticks.attack_active_ticks)
				&"active_done":
					hero.recovery.start(balance_ticks.attack_recovery_ticks)
					hero.chain.start(balance_ticks.attack_chain_window_ticks)
				&"attack_done":
					hero.set_action_state(HeroState.ActionState.IDLE)
		HeroState.ActionState.ROLLING:
			if not hero.roll_duration.is_running:
				hero.set_action_state(HeroState.ActionState.IDLE)
		HeroState.ActionState.BLOCKING:
			if not intent.is_held(&"block"):
				hero.set_action_state(HeroState.ActionState.IDLE)
	# (b) Input-driven edges from the current table row. A press with no entry in the row
	# is dropped, never buffered (AC 5). Fixed INPUT_PRIORITY order = deterministic
	# same-tick tiebreak; at most one transition fires per tick.
	var row := hero.transition_row()
	if not HeroState.TRANSITION_TABLE.has(row):
		return
	var edges: Dictionary = HeroState.TRANSITION_TABLE[row]
	for action: StringName in HeroState.INPUT_PRIORITY:
		if intent.is_pressed(action) and edges.has(action) and _try_transition(player, edges[action]):
			return


## Fire one table edge. Returns false when a gated edge rejects — the chain cap (silent,
## story 1-3) or the roll stamina precondition (emits action_rejected, story 1-4) — so a
## lower-priority same-tick press may still be considered.
func _try_transition(player: PlayerState, target: HeroState.ActionState) -> bool:
	var hero := player.hero
	match target:
		HeroState.ActionState.ATTACKING:
			if hero.action_state == HeroState.ActionState.ATTACKING:
				# Chain edge: only inside the chain window and below the authored cap.
				# attack_chain_length is a COUNT, not a duration — it lives on balance,
				# not balance_ticks; read inline under the same no-caching rule.
				if not hero.chain.is_running or hero.chain_index + 1 >= balance.attack_chain_length:
					return false
				hero.chain_attack(balance_ticks.attack_windup_ticks)
			else:
				hero.enter_attack(balance_ticks.attack_windup_ticks)
		HeroState.ActionState.ROLLING:
			# THE one stamina deduction path (D4, story 1-4) — roll only in E1: basic
			# attack is FREE by GDD design (gdd.md:139/:319 — it is the 1-5 mana faucet),
			# and BLOCKING entry is free (block costs TIME via the D6 regen suppression).
			# Deflect joins this path in 1-8. Cost and delay are read inline at the moment
			# of the transition (CONSTRAINT C). Insufficient stamina is a PRECONDITION
			# (D5): the edge rejects and falls through per INPUT_PRIORITY, and the queued
			# action_rejected keeps the loss legible even if a lower-priority press fires.
			if not player.stamina.spend(
					balance.roll_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				hero.reject_action(&"roll", &"insufficient_stamina")
				return false
			hero.enter_roll(balance_ticks.roll_duration_ticks, balance_ticks.roll_iframe_ticks)
		HeroState.ActionState.BLOCKING:
			hero.enter_block(balance_ticks.deflect_window_ticks)
	return true


## Step-5 stamina regen (story 1-4). The per-tick amount is read inline from balance_ticks
## (CONSTRAINT C); the pool owns the mechanism (fixed add + post-spend delay window), THIS
## is the policy seat (D6): regen is suppressed while the hero is BLOCKING — block entry is
## free, so block must cost time or holding it would be free and P2 ("aggression is
## economy") unenforced. Every other action state regenerates.
func _regen_stamina(player: PlayerState) -> void:
	player.stamina.advance_regen(
		balance_ticks.stamina_regen_per_tick,
		player.hero.action_state == HeroState.ActionState.BLOCKING)


func _resolve_movement(player: PlayerState, intent: InputIntent, slot: int) -> void:
	var dir := intent.move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()  # analog safety; never speed up past move_speed
	# move_dir is CAMERA-space (story 1-2): rotated to world by the slot's pushed basis,
	# yaw only. Identity (nothing pushed — AC 4) short-circuits to the exact E0 planar
	# mapping (intent XY -> world XZ), a true no-op so headless tests and the determinism
	# golden are untouched. velocity stays the REAL world velocity the runner reads (D3);
	# the runner never rotates it afterwards (AC 6).
	var world_dir: Vector3
	if _camera_bases[slot] == Basis.IDENTITY:
		world_dir = Vector3(dir.x, 0.0, dir.y)
	else:
		world_dir = _camera_relative_dir(dir, _camera_bases[slot])
	player.hero.velocity = world_dir * player.hero.move_speed
	if not dir.is_zero_approx():
		player.hero.facing = dir


## Yaw-only camera-space -> world mapping (AC 3): the basis' right/back columns are
## flattened onto XZ and renormalized, so camera pitch mathematically cannot tilt or
## shrink movement. Degenerate columns (camera looking straight up/down) fall back to the
## world-space mapping rather than producing NaNs.
static func _camera_relative_dir(dir: Vector2, camera_basis: Basis) -> Vector3:
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z)
	var back := Vector3(camera_basis.z.x, 0.0, camera_basis.z.z)
	if right.is_zero_approx() or back.is_zero_approx():
		return Vector3(dir.x, 0.0, dir.y)
	return right.normalized() * dir.x + back.normalized() * dir.y


func _apply_balance_to_player(player: PlayerState, config: BalanceConfig) -> void:
	player.hero.set_max_hp(config.max_hp)
	player.hero.move_speed = config.move_speed
	player.stamina.set_maximum(config.max_stamina)
	# D9 (story 1-4): start FULL at the authored maximum. Scope limit: this does NOT touch
	# the constructor/apply_balance double-injection quirk — that remains story 3-1.
	player.stamina.refill()


func _check_resolution() -> void:
	if _round_over:
		return
	if not p1.hero.is_alive():
		_round_over = true
		_queue.push(round_ended.emit.bind(0))
	elif not p2.hero.is_alive():
		_round_over = true
		_queue.push(round_ended.emit.bind(1))
