extends Node3D

## E0 Match Runner (D2). The ONE _physics_process in the project (INVARIANT F1). It OWNS the
## single MatchState (no autoload for live state), advances it in a fixed intra-tick order, and
## drives the hero actors from state. References are wired explicitly at match start.
##
## Tick order (D2 / F1): sample controllers -> gather spatial facts -> advance(intents) ->
## drive actor movement (move_and_slide, inside the actor) -> drain signals.

# E0 placeholders. These are the injection point: E3 folds them into an injected BalanceConfig
# object (see game-architecture.md "Planned (E3) — MatchState config object"). Not authored as
# .tres yet, so they live here as clearly-marked interim constants, tunable in one place.
const _SEED := 12345
const _MAX_HP := 100.0
const _MOVE_SPEED := 5.0
const _MAX_STAMINA := 50.0
const _MAX_MANA := 80.0

@onready var _p1_hero: HeroActor = $P1Hero
@onready var _p2_hero: HeroActor = $P2Hero

var _match_state: MatchState
var _p1_controller: Controller
var _p2_controller: Controller


func _ready() -> void:
	# TICK_HZ must equal the physics tick rate, or every seconds_to_ticks() is silently wrong.
	# Checked in the RUNNER (not state — state never reads ProjectSettings; D3(b)).
	var phys := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	Invariant.check(int(TimingWindow.TICK_HZ) == phys,
		"TimingWindow.TICK_HZ (%d) must equal physics_ticks_per_second (%d)" % [int(TimingWindow.TICK_HZ), phys])

	_p1_controller = KeyboardController.new(&"p1")
	_p2_controller = KeyboardController.new(&"p2")
	_match_state = MatchState.new(_SEED, _MAX_HP, _MOVE_SPEED, _MAX_STAMINA, _MAX_MANA)


func _physics_process(delta: float) -> void:
	# 1. Sample controllers -> InputIntent per player (the ONLY place Input is read — D3).
	var intents: Array[InputIntent] = [_p1_controller.sample(), _p2_controller.sample()]
	# 2. Gather spatial facts — none at E0 (no hitboxes/sensors yet).
	# 3. Advance state (enqueues signals only).
	_match_state.advance(intents)
	# 4. Drive actor movement — each actor reads HeroState.velocity, never the intent.
	_p1_hero.drive(_match_state.p1.hero, delta)
	_p2_hero.drive(_match_state.p2.hero, delta)
	# 5. Drain queued signals AFTER advance returns (D5).
	_match_state.drain_signals()
