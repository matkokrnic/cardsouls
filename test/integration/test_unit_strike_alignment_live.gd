extends SceneTree

## Story 4-3d (AC 1): THE VISIBLE STRIKE LANDS WHEN THE DAMAGE DOES.
##
## THE ASSERTION IS AN EFFECT, NOT AN IDENTIFIER. It reads the minion AnimationPlayer's actual
## PLAYBACK POSITION on the tick the authored ACTIVE window opens, and requires it to sit at the
## measured STRIKE FRAME. It deliberately does not read `ATTACK_PLAYBACK_RATE`, does not read
## `speed_scale`, and does not read the clip NAME -- this project has shipped three defects where
## a guard asserted an identifier and could not see the effect (yaw-vs-yaw missed a model mounted
## backwards; a clip-name check missed seven swings playing one animation; source line order
## missed a push wrapped in a condition).
##
##   WHAT THIS GUARD STILL CANNOT SEE, stated rather than left to be discovered: it cannot see
##   whether the pose AT that playback position is really the claw-strike pose. That binding --
##   playback time 1.3000s <-> the visible strike -- comes from `tools/measure_strike_frame.gd`'s
##   bone measurement and from the operator's eye at Live Smoke, not from this file. If the clip
##   were reimported with different content at the same length, this guard would still pass.
##
## THE TARGET IS DERIVED FROM AUTHORED BALANCE READ AT RUN TIME, never from a literal copied into
## this file. `minion_attack_windup_seconds` is read off the config the runner APPLIED, so the
## coupling the controller's `ATTACK_ALIGNED_WINDUP_SECONDS` constant carries is GUARDED: retune
## the authored windup without re-deriving that constant and this file goes RED, which is the
## alarm the alignment needs and the comment alone would not give.
##
## NAMED MUTATION (AC 1, re-derived against the shipped seat): hardcode
## `UnitAnimationController._playback_rate()` to return 1.0. The clip then sits at 0.900s when the
## ACTIVE window opens instead of 1.300s -- a 0.400s miss against this file's 0.080s tolerance.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_strike_alignment_live.gd

const ARM_FRAME := 4
const CONFIRM_FRAME := 10
const CONFIRM_RELEASE_FRAME := 14
const SPAWN_CHECK_FRAME := 18
const MAX_FRAMES := 1400

## How far the measured playback position may sit from the measured strike frame. Wide enough to
## absorb the one-frame skew between the engine's idle-time animation advance and the runner's
## physics tick; FIVE TIMES narrower than the 0.400s miss the named mutation produces, so it
## cannot pass that mutation vacuously.
const TOLERANCE_SECONDS := 0.08

## How many separate swings must land inside tolerance. More than one, because the FIRST swing of
## a chain and every swing after it reach the clip by different paths (`_select`'s dedup swallows
## the second unless the WINDUP edge forces a rewind -- 4-3c's defect B1), and an alignment that
## only held for swing #1 would be the same defect wearing a new hat.
const REQUIRED_SWINGS := 3

var _frames := 0
var _runner: Node
var _state: MatchState
var _slot_chosen := false
var _armed_action := &""
var _spawned := false

var _windup_seconds := 0.0
var _strike_target := 0.0
var _rate := 0.0
var _prev_phase := UnitBoard.AttackPhase.IDLE
var _samples: Array[float] = []
var _worst := 0.0
var _detail := ""


func _initialize() -> void:
	root.add_child((load("res://src/main/main.tscn") as PackedScene).instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _finish(false, "missing: runner=%s state=%s" % [_runner, _state])
		_windup_seconds = _state.balance.minion_attack_windup_seconds
		if _windup_seconds <= 0.0:
			return _finish(false, "authored minion_attack_windup_seconds is %f -- there is no "
					% _windup_seconds + "window for the strike to land at")
	if _frames == 2:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		if not _state.flags.minions:
			return _finish(false, "the authored FeatureFlags has minions OFF -- cannot summon")
	if _frames == 3:
		_choose_a_summoning_slot()
		if not _slot_chosen:
			return _finish(false, "no summoning card in the dealt hand: %s"
					% str(_state.p1.hand.to_array()))
	if _frames == ARM_FRAME:
		Input.action_press(&"p1_cast_mode")
	if _frames == ARM_FRAME + 1:
		Input.action_press(_armed_action)
	if _frames == ARM_FRAME + 2:
		Input.action_release(_armed_action)
	if _frames == CONFIRM_FRAME:
		Input.action_press(&"p1_cast_confirm")
	if _frames == CONFIRM_FRAME + 2:
		Input.action_release(&"p1_cast_confirm")
	if _frames == CONFIRM_RELEASE_FRAME:
		Input.action_release(&"p1_cast_mode")
	if _frames == SPAWN_CHECK_FRAME:
		_spawned = _state.p1.units.size() == 1 and _unit_actor() != null
		if not _spawned:
			return _finish(false, "summon did not land: board=%d actor=%s"
					% [_state.p1.units.size(), _unit_actor()])
		# THE TARGET. Aligning the strike to the START of the ACTIVE window means the clip has
		# reached its strike frame after exactly one authored windup of real time; played at rate
		# `r` that position is `windup * r`. Both inputs are read from what SHIPPED -- the authored
		# balance above, and the rate off the LIVE controller instance rather than off the class
		# (`UnitAnimationController.ATTACK_PLAYBACK_RATE`), because a static class reference from
		# this file keeps the script alive past `quit()` and the engine then prints
		# `ERROR: 1 resources still in use at exit`, which `test/run_all.sh` fails the suite on.
		var controller: UnitAnimationController = _unit_actor().animation
		_rate = controller.ATTACK_PLAYBACK_RATE
		_strike_target = _windup_seconds * _rate
		# The coupling guard: the controller's constant must still describe the authored windup.
		if not is_equal_approx(_windup_seconds, controller.ATTACK_ALIGNED_WINDUP_SECONDS):
			return _finish(false, ("AUTHORED WINDUP MOVED: balance_config ships %.4fs but "
					+ "UnitAnimationController.ATTACK_ALIGNED_WINDUP_SECONDS is %.4fs. The "
					+ "playback rate no longer aligns the strike -- re-derive it (4-3d AC 1).")
					% [_windup_seconds, controller.ATTACK_ALIGNED_WINDUP_SECONDS])

	if _spawned:
		_sample()

	if _samples.size() >= REQUIRED_SWINGS or _frames >= MAX_FRAMES:
		return _report()
	return false


## One tick of evidence, taken on the EDGE into ACTIVE and nowhere else -- the instant the authored
## window opens is the only instant AC 1 makes a claim about.
func _sample() -> void:
	var unit := _unit_actor()
	if unit == null or not _state.p1.units.is_alive_at(0):
		return
	var phase: int = _state.p1.units.attack_phase_at(0)
	if phase == UnitBoard.AttackPhase.ACTIVE and _prev_phase != UnitBoard.AttackPhase.ACTIVE:
		var player: AnimationPlayer = unit.animation.animation_player
		# The clip must actually BE the attack clip at this instant, or "the playback position is
		# 1.30" would be a reading off whatever else happened to be playing.
		if player.current_animation != &"attack":
			_detail += " active_edge_playing='%s'(not attack);" % player.current_animation
		else:
			var position := player.current_animation_position
			_samples.append(position)
			_worst = maxf(_worst, absf(position - _strike_target))
	_prev_phase = phase


func _report() -> bool:
	var enough := _samples.size() >= REQUIRED_SWINGS
	if not enough:
		_detail += " only_%d_of_%d_swings_observed_in_%d_frames;" \
				% [_samples.size(), REQUIRED_SWINGS, _frames]
	var aligned := enough and _worst <= TOLERANCE_SECONDS
	if enough and not aligned:
		_detail += " worst_miss=%.4fs>tolerance=%.4fs;" % [_worst, TOLERANCE_SECONDS]
	var ok := aligned and _detail.is_empty()
	_teardown()
	print("unit_strike_alignment_live: windup=%.4fs rate=%.4f target=%.4fs samples=%s worst=%.4fs%s"
			% [_windup_seconds, _rate, _strike_target,
				str(_samples), _worst, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


func _finish(ok: bool, message: String) -> bool:
	print(message)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false


## Free the whole live scene BEFORE `quit()`. Every other `*_live.gd` file in this directory runs
## to a natural end and exits clean without one; this file stops the moment it has its three
## samples, which is MID-SWING with the minion's AnimationPlayer still playing, and the engine
## then reports `ERROR: 1 resources still in use at exit` (measured -- and `test/run_all.sh`
## `:32-33` fails the suite on any `^ERROR:` line, so it is a real failure and not noise).
func _teardown() -> void:
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()


func _unit_actor() -> UnitActor:
	var actors: Array = _runner._unit_actors[0]
	if actors.is_empty():
		return null
	var node: Node = actors[0]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


## The first dealt slot whose authored card carries a `summon_*` effect -- test_unit_swing_root_
## live.gd's chooser verbatim.
func _choose_a_summoning_slot() -> void:
	var db := root.get_node_or_null("/root/CardDatabase")
	if db == null:
		return
	var hand := _state.p1.hand.to_array()
	for index in hand.size():
		if _state.p1.hand.is_slot_empty(index):
			continue
		var card := db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		if String(card.basic_effect.effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON):
			var action := StringName("p1_card_%d" % (index + 1))
			if not InputMap.has_action(action):
				return
			_armed_action = action
			_slot_chosen = true
			return
