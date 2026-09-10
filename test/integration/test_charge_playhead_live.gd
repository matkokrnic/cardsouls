extends SceneTree

## Story 6-1b (AC 11, finding 6): THE PLAYHEAD-COMPOSITION PIN, live half. `test_hero_clip_
## selection.gd`'s precedent (drive through the REAL path, not the controller's front door):
## every assertion here goes HeroActor.animation_controller.on_action_state_changed /
## on_charge_progress -> a REAL AnimationPlayer, ticking a REAL TimingWindow the way
## MatchState/match_runner do, off the LIVE authored `unblockable_chargeup_seconds`
## (`data/balance/balance_config.tres`) rather than a fixture duration.
##
## THIS IS ALSO WHERE FINDING 6's COUPLING DUTY LANDS NOW, restated rather than replicated: the
## retired `test_the_charge_clip_speeds_still_describe_the_authored_chargeup` proved a retune of
## `unblockable_chargeup_seconds` REQUIRED re-deriving an animation-side constant. The new
## mechanism needs no such re-derivation — progress is unitless (0..1) and the mapping never reads
## a duration — so THIS test reads the authored value LIVE and keeps passing across a retune,
## proving the "no re-derivation needed" claim instead of merely asserting it.
##
## AC 11's two-endpoint discipline: every session below asserts the playhead sits at ~0.0 on
## CHARGING entry AND at the measured STRIKE FRAME on the window's last tick — the `6-1/R15`
## finding was invisible precisely because nothing checked the LATE end.
##
## Run: godot --headless --path . --script res://test/integration/test_charge_playhead_live.gd

const EPS := 0.02
const CONFIG_PATH := "res://data/balance/balance_config.tres"

var _hero: HeroActor
var _player: AnimationPlayer
var _frames := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_hero = load("res://src/actors/hero/hero.tscn").instantiate() as HeroActor
	root.add_child(_hero)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## Drives one full CHARGING session for one colour/clip, ticking a real TimingWindow exactly like
## MatchState.advance() does, and checks the playhead against charge_playhead_seconds at EVERY
## tick (not merely the two endpoints AC 11 strictly requires) so a mid-session drift fails here
## too.
func _drive_session(color: int, clip: StringName, strike_frame: float, total_ticks: int) -> void:
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.IDLE, HeroState.ActionState.CHARGING, color)
	_check(_player.current_animation == clip,
		"CHARGING with colour %d selected '%s', got '%s'" % [color, clip, _player.current_animation])
	_check(absf(_player.current_animation_position) < EPS,
		"%s: entering CHARGING must start the playhead at ~0.0, got %.4f"
			% [clip, _player.current_animation_position])

	var window := TimingWindow.new()
	window.start(total_ticks)
	for _t in total_ticks:
		window.tick()
		var progress := 1.0 - float(window.remaining_ticks()) / float(total_ticks)
		_hero.animation_controller.on_charge_progress(color, progress)
		var knobs: Dictionary = AnimationController._CHARGE_HOLD_KNOBS[color]
		var want := AnimationController.charge_playhead_seconds(
			progress, strike_frame, knobs["hold_start"], knobs["hold_end"], knobs["hold_fraction"])
		_check(absf(_player.current_animation_position - want) < EPS,
			"%s: tick with progress %.4f expected playhead %.4f, got %.4f"
				% [clip, progress, want, _player.current_animation_position])
	_check(absf(_player.current_animation_position - strike_frame) < EPS,
		"%s: the LAST tick before expiry must land on the measured strike frame %.4f, got %.4f"
			% [clip, strike_frame, _player.current_animation_position])

	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.CHARGING, HeroState.ActionState.IDLE)


## AC 4 regression pin: a per-tick push arriving AFTER the CHARGING -> IDLE cut must be a no-op
## and never re-assert a stale charge-clip frame, the finding-4 ordering hazard the retempo's
## driven playhead introduces that the old single-shot _restart never had.
func _early_release_leaves_no_stale_frame() -> void:
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.IDLE, HeroState.ActionState.CHARGING, Enums.CardColor.RED)
	_hero.animation_controller.on_charge_progress(Enums.CardColor.RED, 0.9)
	_hero.animation_controller.on_action_state_changed(
		HeroState.ActionState.CHARGING, HeroState.ActionState.IDLE)
	_hero.animation_controller.on_charge_progress(Enums.CardColor.RED, 0.95)
	_check(_player.current_animation == &"idle",
		"a charge-progress push arriving after the CHARGING->IDLE cut must be a no-op, got '%s'"
			% _player.current_animation)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	_player = _hero.animation_controller.animation_player
	if _player == null:
		_failures.append("hero.tscn did not yield a wired AnimationController")
	else:
		var config: BalanceConfig = load(CONFIG_PATH)
		var ticks := BalanceTicks.from_config(config)
		var total := ticks.unblockable_chargeup_ticks
		_drive_session(Enums.CardColor.RED, &"swipe",
			AnimationController.SWIPE_STRIKE_FRAME_SECONDS, total)
		_drive_session(Enums.CardColor.BLUE, &"thrust",
			AnimationController.THRUST_STRIKE_FRAME_SECONDS, total)
		_drive_session(Enums.CardColor.GREEN, &"jump_attack",
			AnimationController.JUMP_ATTACK_STRIKE_FRAME_SECONDS, total)
		_early_release_leaves_no_stale_frame()

	if is_instance_valid(_hero):
		_hero.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
