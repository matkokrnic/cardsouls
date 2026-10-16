extends SceneTree

## Story 7-5b (AC 10): THE HEALER'S VISIBLE RELEASE LANDS WHEN THE SHOT SPAWNS -- `test_unit_strike_alignment_live.gd`'s
## shape for the Healer's `shoot` clip, in the real `main.tscn`.
##
## A Healer is put on P1's board (the summon seat's own `add()`; the card path is the state suite's), and P1's
## controller is swapped for a double that commits ONE unblockable press, twice, some seconds apart (the
## `fake_mode_controller.gd` precedent). On the tick each Healer shot SPAWNS in state (P1's projectile board
## grows), the Healer's AnimationPlayer must be playing `shoot` at its measured RELEASE FRAME, within tolerance.
##
## THE ASSERTION IS AN EFFECT, NOT AN IDENTIFIER: the playback POSITION on the spawn tick, not the rate constant.
## The release frame (0.9000 s of clip time) comes from `tools/measure_healer_rig.gd`; that binding to the
## visible gesture is the operator's eye at the Live Smoke, not this file's.
##
## THE DELAY IS READ FROM THE AUTHORED BALANCE AT RUN TIME (`shot_delay_seconds`), never copied: the controller
## fits its rate from the pushed countdown, and this file checks the fitted rate against `release / delay`.
##
## ALSO: the shot leaves from the Healer actor (AC 8, `add_minion_shot`): the projectile actor stands within
## half a metre of the Healer, planar, on its spawn frame.
##
## SMOKE FIX 1 (S8): on the spawn tick the Healer FACES THE OPPOSING HERO it shoots at, STILL does halfway through
## the row's `shoot_face_hold_seconds` (the clip's follow-through), and once the hold and the turn back have passed
## it FACES ITS OWNER again. The two directions are checked to differ (the case is exercised, not assumed). Since
## smoke fix 2 (S15a) the turn back is a RE-AIM, at the row's `reaim_turn_rate_degrees_per_second`, so its window
## is derived from that knob (a 90-degree turn plus a margin), never copied.
##
## NAMED MUTATION: play `shoot` at rate 1.0. On the spawn tick the clip then sits at 0.400 s instead of 0.900 s,
## a 0.5 s miss against this file's 0.08 s tolerance.
##
## Run: godot --headless --path . --script res://test/integration/test_healer_strike_alignment_live.gd

const TOLERANCE_SECONDS := 0.08
const REQUIRED_SHOTS := 2
const LAUNCH_TOLERANCE := 0.5
const MAX_FRAMES := 900
## Frames between the two presses: the first chargeup and its shot are long over, and the hand has refilled.
const PRESS_GAP_FRAMES := 240
## S8: facing is "toward" above this cosine. The turn back is judged after the face hold, once a 90-degree re-aim
## at the row's `reaim_turn_rate_degrees_per_second` (smoke fix 2, S15a) has had time, plus this margin.
const FACING_DOT := 0.9
const TURN_BACK_DEGREES := 90.0
const TURN_BACK_MARGIN_FRAMES := 15
## S8: the owner is put this far to the Healer's SIDE (square to the line to the opposing hero, inside the follow
## band, so the Healer stands) -- at spawn the two heroes are in one line from it and the turn would prove nothing.
const OWNER_SIDE := 5.0


## Commits ONE unblockable press of hand slot `slot` on its next sample, then samples nothing.
class PressOnce extends Controller:
	var slot := -1

	func sample() -> InputIntent:
		var intent := InputIntent.new()
		if slot >= 0:
			intent.card_slot = slot
			intent.card_mode = Enums.ModeKind.UNBLOCKABLE
			intent.card_commit = true
			slot = -1
		return intent


var _frames := 0
var _runner: Node
var _state: MatchState
var _press: PressOnce
var _healer_index := -1
var _delay := 0.0
var _release := 0.0
var _next_press_frame := -1
var _shots_seen := 0
var _samples: Array[float] = []
var _rates: Array[float] = []
var _worst := 0.0
var _detail := ""
var _stopping := -1
var _face_hold_frames := 0
var _turn_back_frames := 0
var _back_check_frame := -1
var _faced_target := 0
var _faced_owner := 0
var _owner_placed := false
var _hold_check_frame := -1
var _held_target := 0


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _stopping >= 0:
		_stopping += 1
		if _stopping >= 3:
			_finish()
		return false
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _state == null:
			return _fail("missing runner or state")
		var kind_index: int = _state.balance.kind_index_of(&"healer")
		var kind: UnitKindProfile = _state.balance.kind_at(kind_index)
		if kind == null or kind.shot_delay_seconds <= 0.0:
			return _fail("the authored balance carries no Healer kind with a shot delay")
		_delay = kind.shot_delay_seconds
		_state.p1.units.add(kind.max_hp, kind_index)
		_healer_index = _state.p1.units.size() - 1
		_press = PressOnce.new()
		_runner._p1_controller = _press
		_next_press_frame = 30
		var row: EffectPresentationRow = _runner._effects.row(&"healer") if _runner._effects != null else null
		_face_hold_frames = int(round(row.knob(&"shoot_face_hold_seconds", 0.0) * TimingWindow.TICK_HZ)) if row != null else 0
		var reaim: float = row.knob(&"reaim_turn_rate_degrees_per_second", 0.0) if row != null else 0.0
		if reaim <= 0.0:
			return _fail("the authored `healer` row carries no `reaim_turn_rate_degrees_per_second`")
		_turn_back_frames = int(ceil(TURN_BACK_DEGREES / reaim * TimingWindow.TICK_HZ)) + TURN_BACK_MARGIN_FRAMES
		return false
	var healer := _healer_actor()
	if healer != null and _release == 0.0:
		_release = (healer.animation as HealerAnimationController).SHOOT_RELEASE_SECONDS
	# Placed before EACH press, and again as the face hold ends: an unblockable's launch (at its chargeup's end,
	# inside the hold) carries the owner toward the opposing hero, back into one line with it.
	if _frames == _back_check_frame - _turn_back_frames:
		_owner_placed = false
	if healer != null and not _owner_placed:
		_owner_placed = true
		var line := _to(healer, _runner._p2_hero)
		var side := Vector2(-line.y, line.x)
		if absf(healer.global_position.x + side.x * OWNER_SIDE) > absf(healer.global_position.x - side.x * OWNER_SIDE):
			side = -side
		var owner: Node3D = _runner._p1_hero
		owner.global_position = Vector3(healer.global_position.x + side.x * OWNER_SIDE, owner.global_position.y,
				healer.global_position.z + side.y * OWNER_SIDE)
	if _frames == _next_press_frame:
		var slot := _first_card_slot()
		if slot < 0:
			_next_press_frame += 30
		else:
			# An unblockable press costs its card's mana; a press refused for it owes no shot (AC 7).
			_state.p1.mana.add(_state.p1.mana.get_maximum())
			_press.slot = slot
			_next_press_frame = -1
			_owner_placed = false
	var shots: int = _state.p1.projectiles.size()
	if shots > _shots_seen:
		_shots_seen = shots
		_sample(healer)
		if _facing(healer, _runner._p2_hero) > FACING_DOT:
			_faced_target += 1
		else:
			_detail += " shot_%d_spawned_facing_%.2f_not_the_target;" % [shots - 1, _facing(healer, _runner._p2_hero)]
		_back_check_frame = _frames + _face_hold_frames + _turn_back_frames
		_hold_check_frame = _frames + int(_face_hold_frames * 0.5)
		if _samples.size() < REQUIRED_SHOTS:
			_next_press_frame = _frames + PRESS_GAP_FRAMES
	if _frames == _hold_check_frame and healer != null:
		if _facing(healer, _runner._p2_hero) > FACING_DOT:
			_held_target += 1
		else:
			_detail += " mid_hold_facing_%.2f_not_the_target;" % _facing(healer, _runner._p2_hero)
	if _frames == _back_check_frame and healer != null:
		var apart := _to(healer, _runner._p1_hero).dot(_to(healer, _runner._p2_hero))
		if apart > FACING_DOT:
			_detail += " owner_and_target_in_one_direction(%.2f)_S8_not_exercised;" % apart
		elif _facing(healer, _runner._p1_hero) > FACING_DOT:
			_faced_owner += 1
		else:
			_detail += " not_back_on_the_owner_%.2f;" % _facing(healer, _runner._p1_hero)
	if (_samples.size() >= REQUIRED_SHOTS and _faced_owner >= REQUIRED_SHOTS) or _frames >= MAX_FRAMES:
		_stopping = 0
		if _runner._effects != null:
			_runner._effects.stop_all_sounds()
		# S8's turn-back check ends this file about a second after the press, inside the unblockable's own eye-flash
		# sound (not the presenter's): a sound still playing when the scene is freed leaks its stream (measured).
		for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for node in root.find_children("*", type, true, false):
				node.call(&"stop")
	return false


## One spawn tick's evidence: the clip, its position, the fitted rate, and where the shot left from.
func _sample(healer: UnitActor) -> void:
	if healer == null:
		_detail += " spawn_without_healer_actor;"
		return
	var controller := healer.animation as HealerAnimationController
	var player := controller.animation_player
	if player.current_animation != &"shoot":
		_detail += " spawn_tick_playing='%s'(not shoot);" % player.current_animation
		return
	var position := player.current_animation_position
	_samples.append(position)
	_rates.append(controller.shoot_rate)
	_worst = maxf(_worst, absf(position - _release))
	var want_rate := _release / _delay
	if absf(controller.shoot_rate - want_rate) > 0.001:
		_detail += " rate=%.4f!=release/delay=%.4f;" % [controller.shoot_rate, want_rate]
	var shot_index := _shots_seen - 1
	var actors: Array = _runner._projectile_actors[0]
	if shot_index >= actors.size() or not is_instance_valid(actors[shot_index]):
		_detail += " no_projectile_actor_for_shot_%d;" % shot_index
		return
	var shot := actors[shot_index] as Node3D
	var apart := Vector2(shot.global_position.x - healer.global_position.x,
			shot.global_position.z - healer.global_position.z).length()
	if apart > LAUNCH_TOLERANCE:
		_detail += " shot_%d_left_%.3fm_from_the_healer;" % [shot_index, apart]


## The planar unit direction from `from` to `to`.
func _to(from: Node3D, to: Node3D) -> Vector2:
	return Vector2(to.global_position.x - from.global_position.x, to.global_position.z - from.global_position.z).normalized()


## How squarely `healer` faces `who` (its -Z forward against the direction to them; 1 = straight at them).
func _facing(healer: Node3D, who: Node3D) -> float:
	if healer == null or who == null:
		return -1.0
	var forward := -healer.global_transform.basis.z
	return Vector2(forward.x, forward.z).normalized().dot(_to(healer, who))


func _finish() -> void:
	var enough := _samples.size() >= REQUIRED_SHOTS
	if not enough:
		_detail += " only_%d_of_%d_shots_in_%d_frames;" % [_samples.size(), REQUIRED_SHOTS, _frames]
	if _face_hold_frames <= 0:
		_detail += " the_healer_row_authors_no_shoot_face_hold_seconds;"
	if _faced_target < REQUIRED_SHOTS or _held_target < REQUIRED_SHOTS or _faced_owner < REQUIRED_SHOTS:
		_detail += " faced_the_target_%d_held_%d_turned_back_%d_of_%d;" \
				% [_faced_target, _held_target, _faced_owner, REQUIRED_SHOTS]
	if enough and _worst > TOLERANCE_SECONDS:
		_detail += " worst_miss=%.4fs>tolerance=%.4fs;" % [_worst, TOLERANCE_SECONDS]
	var ok := enough and _detail.is_empty()
	print("healer_strike_alignment_live: delay=%.4fs release=%.4fs samples=%s rates=%s worst=%.4fs%s"
			% [_delay, _release, str(_samples), str(_rates), _worst, _detail])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	_teardown()
	quit(0 if ok else 1)


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	_teardown()
	quit(1)
	return false


## Free the live scene before `quit()`: this file stops with the Healer's AnimationPlayer mid-clip
## (`test_unit_strike_alignment_live.gd`'s measured reason).
func _teardown() -> void:
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()


func _healer_actor() -> UnitActor:
	if _runner == null or _healer_index < 0:
		return null
	var actors: Array = _runner._unit_actors[0]
	if _healer_index >= actors.size() or not is_instance_valid(actors[_healer_index]):
		return null
	return actors[_healer_index] as UnitActor


func _first_card_slot() -> int:
	for index in _state.p1.hand.size():
		if not _state.p1.hand.is_slot_empty(index):
			return index
	return -1
