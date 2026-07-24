extends SceneTree

## Story 1-3b AC 4: live-path proof that DEBT A is dead in the actual game, not just in
## headless setups. Drives the real main scene and asserts a simulated p1 attack press puts
## the hero into ATTACKING through the FULL live chain: BalanceConfigService .tres ->
## runner apply_balance at match start -> KeyboardController -> MatchState.advance ->
## transition -> queued action_state_changed drained by the runner (D5).
##
## The transition is observed via the queued `action_state_changed` signal — the
## D5-sanctioned channel, wired through the runner's read-only subscription seam — NEVER by
## reaching into the runner's private _match_state: the signal arriving proves the queue
## drain path end-to-end, not just that a state field changed.
##
## Run: godot --headless --path . --script res://test/integration/test_live_attack.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const MAX_FRAMES := 120  # 2 s at 60 Hz — generous vs. any sane authored windup

var _runner: Node3D
var _transitions: Array = []
var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	_runner = root.get_node("Main")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# Wire AFTER the tree is live (the runner's _ready — where MatchState is created — fires
	# once the main loop starts, so subscribing in _initialize races scene setup), and
	# BEFORE the press so no transition can be missed.
	if _frames == 1:
		_runner.connect_hero_action_state_changed(0,
			func(prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
				_transitions.append([int(prev), int(cur)]))
	if _frames == 3:
		Input.action_press(&"p1_attack")
	if _frames == 5:
		Input.action_release(&"p1_attack")
	if not _transitions.is_empty() or _frames >= MAX_FRAMES:
		var expected := [int(HeroState.ActionState.IDLE), int(HeroState.ActionState.ATTACKING)]
		var ok: bool = not _transitions.is_empty() and _transitions[0] == expected
		print("live attack press: transitions=%s after %d frames" % [_transitions, _frames])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
