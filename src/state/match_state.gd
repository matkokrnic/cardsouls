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

	# 1. Ingest intents        [E1: parse attack/block/roll presses into intended actions]
	# 2. Advance D4 timers
	p1.hero.tick_timers()
	p2.hero.tick_timers()
	# 3. Resolve actions       intended velocity from move_dir (P1 then P2)
	_resolve_movement(p1, p1_intent)
	_resolve_movement(p2, p2_intent)
	# 4. Resolve contacts      [E1 hitbox->contact seam — none at E0]
	# 5. Resource generation   [D6/E3 seam — melee-hit / passive mana]
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


func _resolve_movement(player: PlayerState, intent: InputIntent) -> void:
	var dir := intent.move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()  # analog safety; never speed up past move_speed
	# Planar arena: intent XY -> world XZ. This is the field the runner reads (D3).
	player.hero.velocity = Vector3(dir.x, 0.0, dir.y) * player.hero.move_speed
	if not dir.is_zero_approx():
		player.hero.facing = dir


func _apply_balance_to_player(player: PlayerState, config: BalanceConfig) -> void:
	player.hero.set_max_hp(config.max_hp)
	player.hero.move_speed = config.move_speed
	player.stamina.set_maximum(config.max_stamina)


func _check_resolution() -> void:
	if _round_over:
		return
	if not p1.hero.is_alive():
		_round_over = true
		_queue.push(round_ended.emit.bind(0))
	elif not p2.hero.is_alive():
		_round_over = true
		_queue.push(round_ended.emit.bind(1))
