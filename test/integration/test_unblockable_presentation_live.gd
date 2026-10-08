extends SceneTree

## Story 7-10 (AC 1-4, AC 9-18): THE UNBLOCKABLE PRESENTATION THROUGH THE REAL RUNNER -- `main.tscn`, the runner's
## post-`advance()` polls, the live `MatchState`, one `_physics_process` (F1). `test_counter_reactions_live.gd`'s
## shape and its reason: the edge reads and the presentation they drive are runtime COMPOSITION no state test
## reaches. THE STATE IS POKED, NOT PLAYED, on that file's precedent (a mode-3 press is not makeable headless):
## the pokes are the state layer's own seats -- the cast seat's window starts, the counter's window start, the
## knockdown package -- and everything read afterwards is produced by the runner's own next ticks.
##
## THE SEQUENCE, P1 the attacker, P2 the defender:
##   eyes     -- off at rest; a RED cast lights them on the click poll in RED, they blink faster as the chargeup
##               fills, FLASH ON THE COMMIT TICK (the tick `MatchState._is_commit_tick` names, AC 4), stay lit
##               through the flight and go OUT on the first touch; a cancel, a reset and the round-over
##               freeze put them out too (AC 1-3).
##   shimmer  -- the immunity window shows the silver marker on that hero only, fading with the remaining
##               fraction, gone on expiry (AC 15).
##   red      -- a RED counter pressed 2.5 m from a charging attacker that the counter knocks down: the BODY'S
##               velocity is the state's times gap / 4.0 (OQ1); the mesh lifts toward the head; the victim's
##               knockdown never plays before the head-contact tick and does after it; both rigs freeze for the
##               hitstop; both follower cameras shake while the rig cameras do not move; the snapshot key set
##               is the same during the hitstop as at rest (AC 9-11, AC 16-17).
##   green    -- a GREEN counter: the dagger carries a trail and arrives within `DAGGER_FLIGHT_SECONDS`; the
##               victim's knockdown never plays before the arrival and does after it (AC 12-14).
##   nodes    -- the new nodes carry no collision shape and no Area3D (AC 18).
##
## Run: godot --headless --path . --script res://test/integration/test_unblockable_presentation_live.gd

## The 6-1 input stand-in (`test_charge_telegraph_dispatch_live.gd`): a neutral intent every tick, so nothing a
## headless controller emits disturbs the poked state.
class BareController extends Controller:
	func sample() -> InputIntent:
		return InputIntent.new()


const CHECK_DELAY := 3
const BUDGET_FRAMES := 600
const QUIT_DEFER_FRAMES := 30   ## `4-3b/R29`: never quit on the frame of the last read
const COUNTER_GAP := 2.5

var _frames := 0
var _runner: Node
var _state: MatchState
var _p1: HeroActor
var _p2: HeroActor
var _phase := "rest"
var _phase_frame := 0
var _done_frame := -1
var _failures: Array[String] = []

var _lit_frame := -1
var _flash_seen := false
var _blinks: Array[int] = []
var _last_blink_count := 0
var _counter_start_frame := -1
var _contact_frame := -1
var _knockdown_frame := -1
var _saw_lift := 0.0
var _saw_freeze_both := false
var _saw_shake := false
var _shake_rotation_ok := true
var _scale_checked := false
var _rest_keys: Array = []
var _dagger_trail := false
var _dagger_arrival_frame := -1


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _clip(hero: HeroActor) -> StringName:
	return hero.animation_controller.animation_player.current_animation


func _next(phase: String) -> void:
	_phase = phase
	_phase_frame = _frames


func _fail(message: String) -> void:
	_failures.append(message)


func _fail_and_stop(message: String) -> void:
	_failures.append(message)
	_done_frame = _frames


## The cast seat's two window starts and the state write, `test_charge_telegraph_dispatch_live.gd`'s poke, at the
## AUTHORED spans so the chargeup commits on its own.
func _poke_cast(color: int, hold: bool) -> void:
	var player := _state.p1
	player.charge_color = color
	player.charge_contact = PlayerState.CHARGE_CONTACT_NONE
	if hold:
		player.charge_window.start(100000)
		player.landing_window.start(100000)
	else:
		var chargeup := _state.balance_ticks.unblockable_chargeup_ticks
		player.charge_window.start(chargeup)
		player.landing_window.start(chargeup + _state.balance_ticks.unblockable_launch_ticks_for(color))
	player.hero.set_action_state(HeroState.ActionState.CHARGING)


func _end_cast() -> void:
	_state.p1.charge_window.start(0)
	_state.p1.landing_window.start(0)
	_state.p1.hero.set_action_state(HeroState.ActionState.IDLE)


## The counter's window start plus the travel BEARING the cast seat locks at the press (defender -> attacker,
## `match_state.gd`'s counter-busy movement branch): without it the state writes no travel at all.
func _arm_counter(color: int) -> void:
	_state.p2.defense_color = color
	_state.p2.defense_window.start(_state.balance_ticks.counter_busy_ticks_for(color))
	_state._counter_travel_dirs[1] = Vector2(_p1.global_position.x - _p2.global_position.x,
			_p1.global_position.z - _p2.global_position.z).normalized()


## The knockdown package P2's landing applies -- what a landed counter does to the attacker.
func _knock_down_p1() -> void:
	_state._landing_package_pending[1] = true
	_state._apply_landing_packages()


## The snapshot's key set, top level and one level down -- what AC 16/AC 17 say presentation never moves.
func _key_set() -> Array:
	var snap := _state.to_snapshot()
	var keys: Array = []
	for k: Variant in snap.keys():
		keys.append(str(k))
		if snap[k] is Dictionary:
			for k2: Variant in (snap[k] as Dictionary).keys():
				keys.append("%s/%s" % [k, k2])
	keys.sort()
	return keys


func _settled() -> bool:
	return _state.p1.hero.action_state == HeroState.ActionState.IDLE and not _state.p1.hero.is_getting_up() \
			and not _state.p2.defense_window.is_running


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _done_frame >= 0:
		if _frames - _done_frame >= QUIT_DEFER_FRAMES:
			var ok := _failures.is_empty()
			for f in _failures:
				print("  FAILED: " + f)
			print("RESULT: %s" % ("PASS" if ok else "FAIL"))
			quit(0 if ok else 1)
			return true
		return false
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_p1 = _runner._p1_hero if _runner != null else null
		_p2 = _runner._p2_hero if _runner != null else null
		if _state == null or _p1 == null or _p2 == null or _state.balance_ticks == null:
			_fail_and_stop("setup: runner/state/heroes/balance missing")
			return false
		_runner._p1_controller = BareController.new()
		_runner._p2_controller = BareController.new()
		_next("rest")
		return false
	var since := _frames - _phase_frame
	match _phase:
		"rest":
			if since >= CHECK_DELAY:
				if _p1.eyes.phase != UnblockableEyes.Phase.OFF or _p1.eyes.visible:
					_fail("eyes: off at rest")
				for node: Node in [_p1.eyes, _p1.immunity_shimmer]:
					if not node.find_children("*", "CollisionShape3D", true, false).is_empty() \
							or not node.find_children("*", "Area3D", true, false).is_empty():
						_fail("nodes: %s carries no collision shape and no Area3D (AC 18)" % node.name)
				_rest_keys = _key_set()
				_poke_cast(Enums.CardColor.RED, false)
				_next("eyes_watch")
		"eyes_watch":
			var eyes := _p1.eyes
			if _lit_frame < 0 and eyes.phase != UnblockableEyes.Phase.OFF:
				_lit_frame = _frames
				if eyes._color != _p1.telegraph_controller.charge_red_profile.color:
					_fail("eyes: lit in the unblockable's colour (got %s)" % eyes._color)
				if _p2.eyes.phase != UnblockableEyes.Phase.OFF:
					_fail("eyes: P1's cast lights P1's eyes only")
			if eyes.blink_count > _last_blink_count:
				_blinks.append(_frames)
				_last_blink_count = eyes.blink_count
			if eyes.flash_count > 0 and not _flash_seen:
				_flash_seen = true
				# This frame reads the state AFTER the runner's last tick -- the tick whose poll flashed.
				if not _state._is_commit_tick(_state.p1):
					_fail("eyes: the flash falls on the COMMIT tick (`_is_commit_tick`) the 7-9 counter window "
							+ "is anchored to (AC 4)")
				if eyes.phase != UnblockableEyes.Phase.LIT:
					_fail("eyes: steady lit after the flash")
				var lead := _state.balance_ticks.counter_lead_ticks_for(Enums.CardColor.RED)
				if _frames - _lit_frame < lead:
					_fail("eyes: lit for at least the counter lead (%d ticks) before the flash" % lead)
				_next("eyes_flight")
			elif since > BUDGET_FRAMES:
				_fail_and_stop("eyes: no flash within %d frames" % BUDGET_FRAMES)
		"eyes_flight":
			if since == 1:
				if _blinks.size() < 3:
					_fail("eyes: they blink during the chargeup (saw %d)" % _blinks.size())
				else:
					var first_gap := _blinks[1] - _blinks[0]
					var last_gap := _blinks[_blinks.size() - 1] - _blinks[_blinks.size() - 2]
					if last_gap >= first_gap:
						_fail("eyes: the blinks get FASTER (first gap %d, last gap %d frames)"
								% [first_gap, last_gap])
				if _state.p1.hero.action_state != HeroState.ActionState.CHARGING:
					_fail_and_stop("eyes setup: the attack is still in flight one tick after the commit")
					return false
				if _p1.eyes.phase != UnblockableEyes.Phase.LIT:
					_fail("eyes: lit through the flight")
				_state.p1.charge_contact = PlayerState.CHARGE_CONTACT_TOUCHED
			elif since == CHECK_DELAY:
				if _p1.eyes.phase != UnblockableEyes.Phase.OFF:
					_fail("eyes: OUT on the first touch (AC 3)")
				_end_cast()
				_next("eyes_cancel")
		"eyes_cancel":
			if since == CHECK_DELAY:
				_poke_cast(Enums.CardColor.BLUE, true)
			elif since == CHECK_DELAY * 2:
				if _p1.eyes.phase != UnblockableEyes.Phase.BLINK:
					_fail("eyes: a second cast lights them again")
				_state._round_over = true
			elif since == CHECK_DELAY * 3:
				if _p1.eyes.visible:
					_fail("eyes: the round-over freeze puts them out (AC 3)")
				_state._round_over = false
			elif since == CHECK_DELAY * 4:
				if not _p1.eyes.visible:
					_fail("eyes: ...and only while it holds")
				_p1.clear_presentation()
				if _p1.eyes.visible or _p1.eyes.phase != UnblockableEyes.Phase.OFF:
					_fail("eyes: the reset path puts them out")
				_end_cast()
			elif since == CHECK_DELAY * 5:
				if _p1.eyes.phase != UnblockableEyes.Phase.OFF:
					_fail("eyes: a cancel (leaving CHARGING) leaves them out")
				_state.p2.hero.unblockable_immunity.start(90)
				_next("shimmer")
		"shimmer":
			if since == CHECK_DELAY:
				var f1 := _p2.immunity_shimmer.fraction()
				if not _p2.immunity_shimmer.visible or f1 <= 0.0:
					_fail("shimmer: shows while the immunity runs (AC 15)")
				if _p1.immunity_shimmer.visible:
					_fail("shimmer: ...on that hero only")
				var want := float(_state.p2.hero.unblockable_immunity.remaining_ticks()) / 90.0
				if absf(f1 - want) > 0.03:
					_fail("shimmer: fades with the remaining fraction (got %.3f, want %.3f)" % [f1, want])
			elif since == CHECK_DELAY + 30:
				if _p2.immunity_shimmer.fraction() >= 0.8:
					_fail("shimmer: it fades as the window runs down (%.3f)" % _p2.immunity_shimmer.fraction())
			elif since >= 100:
				if _p2.immunity_shimmer.visible:
					_fail("shimmer: gone on expiry")
				_next("red_setup")
		"red_setup":
			if since == 1:
				_p1.global_position = _p2.global_position + Vector3(COUNTER_GAP, 0.0, 0.0)
			elif since == CHECK_DELAY:
				_poke_cast(Enums.CardColor.RED, true)
			elif since == CHECK_DELAY * 2:
				_arm_counter(Enums.CardColor.RED)
				_counter_start_frame = _frames
				_next("red_knock")
		"red_knock":
			if since == 2:
				_knock_down_p1()
				_next("red_watch")
		"red_watch":
			_watch_red()
		"green_settle":
			if _settled():
				_next("green_setup")
			elif since > BUDGET_FRAMES:
				_fail_and_stop("green setup: the RED phase never settled")
		"green_setup":
			if since == CHECK_DELAY:
				_poke_cast(Enums.CardColor.GREEN, true)
			elif since == CHECK_DELAY * 2:
				_arm_counter(Enums.CardColor.GREEN)
				_counter_start_frame = _frames
				_knockdown_frame = -1
				_next("green_knock")
		"green_knock":
			var dagger: Node = _runner._counter_daggers[1]
			if dagger != null and is_instance_valid(dagger):
				_dagger_trail = (dagger as Node3D).get_node_or_null("Trail") is GPUParticles3D
			if since == 2:
				_knock_down_p1()
				_next("green_watch")
		"green_watch":
			_watch_green()
	return false


func _watch_red() -> void:
	var since := _frames - _phase_frame
	var window := _state.p2.defense_window
	var elapsed := window.duration_ticks() - window.remaining_ticks()
	var contact: int = _runner._red_contact_tick[1]
	# OQ1: the body's velocity is the state's scaled by gap / travel, on a moving outbound tick.
	if not _scale_checked and window.is_running and elapsed >= 2 and elapsed < contact \
			and _state.p2.hero.velocity.length() > 0.1:
		_scale_checked = true
		var want := UnblockablePresentation.red_travel_scale(COUNTER_GAP,
				_state.balance.counter_travel_distance_for(Enums.CardColor.RED))
		var got := _p2.velocity.length() / _state.p2.hero.velocity.length()
		if absf(got - want) > 0.05:
			_fail("red: the body travels at the state's velocity x gap/travel (got x%.3f, want x%.3f)" % [got, want])
		if want >= 1.0:
			_fail("red setup: the press gap must be inside the travel for the scale to show")
	_saw_lift = maxf(_saw_lift, _p2.counter_lift)
	if _p1.animation_controller.animation_player.speed_scale == 0.0 \
			and _p2.animation_controller.animation_player.speed_scale == 0.0:
		_saw_freeze_both = true
		if _key_set() != _rest_keys:
			_fail("red: the snapshot key set during the hitstop is the one at rest (AC 17)")
	# The CAMERAS themselves, never the runner's bookkeeping: a follower displaced from its rig camera is a shake.
	var moved := 0
	for pair: Array in [[_runner._p1_view_cam, _runner._p1_rig_cam], [_runner._p2_view_cam, _runner._p2_rig_cam]]:
		var view: Camera3D = pair[0]
		var rig: Camera3D = pair[1]
		if view.global_position.distance_to(rig.global_position) > 0.001:
			moved += 1
			if not view.global_transform.basis.is_equal_approx(rig.global_transform.basis):
				_shake_rotation_ok = false
	if moved == 2:
		_saw_shake = true
	if _clip(_p1) == &"knockdown" and _knockdown_frame < 0:
		_knockdown_frame = _frames
		if window.is_running and elapsed <= contact:
			_fail("red: the attacker's knockdown never plays before the head contact (elapsed %d, contact %d)"
					% [elapsed, contact])
	if _contact_frame < 0 and window.is_running and elapsed >= contact and contact > 0:
		_contact_frame = _frames
	if not window.is_running and since > CHECK_DELAY:
		if not _scale_checked:
			_fail("red: no moving outbound tick was observed")
		if _saw_lift < 0.5:
			_fail("red: the mesh lifts toward the attacker's head (max %.3f m)" % _saw_lift)
		if _saw_lift > UnblockablePresentation.RED_LAND_HEIGHT_MAX + 0.001:
			_fail("red: the lift is capped (%.3f)" % _saw_lift)
		if not _saw_freeze_both:
			_fail("red: both rigs freeze for the hitstop at the head contact (AC 10)")
		if _p1.animation_controller.animation_player.speed_scale != 1.0 \
				or _p2.animation_controller.animation_player.speed_scale != 1.0:
			_fail("red: the rigs thaw after the hitstop")
		if not _saw_shake:
			_fail("red: both follower cameras shake at the contact (AC 10)")
		if not _shake_rotation_ok:
			_fail("red: the shake is POSITIONAL -- the follower's rotation stays the rig camera's")
		if _knockdown_frame < 0:
			_fail("red: the attacker's knockdown plays after the contact (AC 11)")
		if absf(_p2.counter_lift) > 0.0001 or not is_equal_approx(_p2.counter_travel_scale, 1.0):
			_fail("red: the lift and the travel factor are back at rest after the span")
		_next("green_settle")


func _watch_green() -> void:
	var dagger: Node = _runner._counter_daggers[1]
	if dagger != null and is_instance_valid(dagger):
		if (dagger as Node3D).get_node_or_null("Trail") is GPUParticles3D:
			_dagger_trail = true
		if not dagger.find_children("*", "CollisionShape3D", true, false).is_empty() \
				or not dagger.find_children("*", "Area3D", true, false).is_empty():
			_fail("nodes: the dagger carries no collision shape and no Area3D (AC 18)")
	elif _dagger_arrival_frame < 0:
		_dagger_arrival_frame = _frames
	if _clip(_p1) == &"knockdown" and _knockdown_frame < 0:
		_knockdown_frame = _frames
		if _dagger_arrival_frame < 0:
			_fail("green: the attacker's knockdown never plays before the dagger's impact (AC 14)")
	if _frames - _phase_frame > 120:
		if not _dagger_trail:
			_fail("green: the dagger carries a trail (AC 12)")
		var bound := UnblockablePresentation.ticks(UnblockablePresentation.DAGGER_FLIGHT_SECONDS) + 2
		if _dagger_arrival_frame < 0 or _dagger_arrival_frame - _counter_start_frame > bound:
			_fail("green: the dagger arrives within %d frames of the press (arrived at +%d)"
					% [bound, _dagger_arrival_frame - _counter_start_frame])
		if _knockdown_frame < 0:
			_fail("green: the attacker's knockdown plays after the impact (AC 14)")
		_done_frame = _frames
