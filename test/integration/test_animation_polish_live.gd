extends SceneTree

## Story 7-2: the two runner-side halves of the animation polish, on the LIVE runner (`main.tscn`) -- the wiring no
## hero-only fixture can see.
##
## PART A -- AC 9, THE GESTURE FOR EVERY INSTANT EFFECT. `MatchRunner._present_cast_resolved` reads the caster's
## reversal kind and plays `AnimationController.gesture_for_reversal(kind)`. Pinned: the mapping itself (every kind with
## no clip of its own -> `cast_buff`; the three cast spells and NONE -> nothing), and that the runner's resolution path
## really plays it on the caster's rig for each of them.
##
## PART B -- AC 5 (AMENDED, operator live smoke 2026-10-09): STONES 2 AND 3 HAVE NO SWING. A real Rocksling cast on
## the live state: from the strike on, the caster's throw follows through at native rate and NO later stone re-seeks
## or restarts it -- frame over frame through every stone's spawn tick (read off the state's own owed count), the
## throw's playhead only moves forward and the clip keeps playing.
##
## Run: godot --headless --path . --script res://test/integration/test_animation_polish_live.gd

const DEADLINE := 600
const TAIL := 8

var _frames := 0
var _main: Node
var _state: MatchState
var _failures: Array[String] = []

var _cast_frame := -1
var _prev_owed := 0
var _armed := false
var _launches := 0
var _later_spawns_seen := 0
var _last_position := -1.0
var _done_frame := -1


func _initialize() -> void:
	root.add_child((load("res://src/main/main.tscn") as PackedScene).instantiate())


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _p1_anim() -> AnimationController:
	return (_main._p1_hero as HeroActor).animation_controller


## PART A.
func _gestures() -> void:
	var want_buff := [PlayerState.REVERSAL_VANGUARD, PlayerState.REVERSAL_CULLING, PlayerState.REVERSAL_GRAVE_WARD,
		PlayerState.REVERSAL_RAISE_DEAD, PlayerState.REVERSAL_DRAIN, PlayerState.REVERSAL_BOOM,
		PlayerState.REVERSAL_VAMPIRIC_AURA, PlayerState.REVERSAL_BLOODHOUND, PlayerState.REVERSAL_FROSTBITE,
		PlayerState.REVERSAL_CORPSE_BOMB]
	var want_none := [PlayerState.REVERSAL_NONE, PlayerState.REVERSAL_HONED_BOLT, PlayerState.REVERSAL_FIREBALL,
		PlayerState.REVERSAL_ROCKSLING]
	for kind: int in want_buff:
		_check(AnimationController.gesture_for_reversal(kind) == &"cast_buff",
			"AC 9: reversal kind %d plays cast_buff (got '%s')" % [kind, AnimationController.gesture_for_reversal(kind)])
	for kind: int in want_none:
		_check(AnimationController.gesture_for_reversal(kind) == &"",
			"AC 9: reversal kind %d plays no gesture (got '%s')" % [kind, AnimationController.gesture_for_reversal(kind)])
	var p1: PlayerState = _state.p1
	var player := _p1_anim().animation_player
	var saved_tick := p1.last_resolved_card_tick
	for kind: int in want_buff + want_none:
		player.play(&"idle")
		p1.reversal_kind = kind
		# THIS resolution wrote the packet -- the runner's own "is it this resolution's" test.
		p1.last_resolved_card_tick = int(_main._prev_resolved_tick[0]) + 1000
		_main._present_cast_resolved(0, &"", Enums.ModeKind.BASIC)
		var played := player.current_animation == &"cast_buff"
		_check(played == want_buff.has(kind),
			"AC 9: the runner's resolution path for kind %d %s the gesture (clip '%s')"
				% [kind, "plays" if want_buff.has(kind) else "does not play", player.current_animation])
	p1.reversal_kind = PlayerState.REVERSAL_NONE
	p1.last_resolved_card_tick = saved_tick
	player.play(&"idle")


## PART B: arm a real Rocksling cast the way the press seat does.
func _start_rocksling() -> void:
	var effect: CardEffect = load("res://data/effects/rocksling.tres")
	_check(effect.boulders_per_cast >= 2, "fixture: the authored Rocksling fires more than one stone")
	_state.p1.start_cast(&"rocksling", TimingWindow.seconds_to_ticks(effect.cast_seconds), Enums.ModeKind.BASIC,
			1, TargetingService.HERO_INDEX, 0.0)


func _watch_burst() -> void:
	var p1: PlayerState = _state.p1
	var player := _p1_anim().animation_player
	var owed := p1.burst_remaining if p1.has_pending_burst() else 0
	var throwing := player.current_animation == &"cast_rocksling_throw"
	if owed > 0 and _prev_owed == 0 and not _armed:
		_armed = true
		_launches += 1
		_check(throwing and player.get_playing_speed() > 0.5
				and player.current_animation_position >= AnimationController.ROCKSLING_THROW_RELEASE_SECONDS - 0.001,
			"AC 5/AC 6: the strike starts the throw's follow-through from the release at native rate (%s @ %.4f x%.2f)"
				% [player.current_animation, player.current_animation_position, player.get_playing_speed()])
	elif _armed and owed < _prev_owed:
		_launches += 1
		_later_spawns_seen += 1
		if owed == 0:
			_done_frame = _frames
	if _armed and _done_frame < 0 or _armed and _frames <= _done_frame:
		# THE PIN: through every later stone's spawn the throw is never re-seeked back nor restarted.
		_check(throwing, "AC 5: stone %d's tick took the body off the throw (%s)" % [_launches, player.current_animation])
		_check(player.current_animation_position >= _last_position - 0.0001,
			"AC 5: the throw's playhead jumped BACK on stone %d's tick (%.4f -> %.4f) -- a later stone re-seeked it"
				% [_launches, _last_position, player.current_animation_position])
		_check(player.get_playing_speed() > 0.5, "AC 5: the throw keeps playing at native rate (x%.2f)"
				% player.get_playing_speed())
		_last_position = player.current_animation_position
	_prev_owed = owed


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_main = root.get_node("Main")
		_state = _main._match_state
		_gestures()
		_start_rocksling()
		_cast_frame = _frames
		return false
	if _cast_frame > 0 and _done_frame < 0:
		_watch_burst()
	if _done_frame > 0 and _frames == _done_frame + 2:
		var player := _p1_anim().animation_player
		_check(player.current_animation == &"cast_rocksling_throw" and player.get_playing_speed() > 0.5,
			"AC 5/AC 6: after the last stone the throw follows through at native rate")
	if _done_frame > 0 and _frames >= _done_frame + TAIL or _frames >= DEADLINE:
		return _finish()
	return false


func _finish() -> bool:
	var effect: CardEffect = load("res://data/effects/rocksling.tres")
	_check(_launches == effect.boulders_per_cast,
		"AC 5: every stone's launch was observed (%d of %d)" % [_launches, effect.boulders_per_cast])
	_check(_later_spawns_seen == effect.boulders_per_cast - 1,
		"AC 5: every later stone's spawn tick was observed (vacuous otherwise) -- %d" % _later_spawns_seen)
	print("animation_polish_live: launches=%d later_spawns=%d done_frame=%d" % [_launches, _later_spawns_seen,
			_done_frame])
	if _main != null and _main._effects != null:
		_main._effects.stop_all_sounds()
	OS.delay_msec(100)
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
	return true
