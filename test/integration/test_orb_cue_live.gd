extends SceneTree

## Story 5-4 (AC 16): THE PRIME-ON-CONNECT FALSE-FIRE, pinned. This is the `3-0b/R34` blind spot
## named literally -- the headless suite asserts state and authored data, never runtime COMPOSITION,
## and the earn cue IS composition: wiring order (match_runner connects the ninth seam, which PRIMES
## immediately) crossed with controller state (TelegraphController's remembered previous triple).
## No state-level test reaches it, because none of them loads a .tscn or builds a MatchRunner.
##
## THE DEFECT THIS EXISTS TO CATCH. `connect_orbs_changed` primes on connect with the resting
## (0,0,0). A flash derived naively as "fires when a count went up" compares that first payload
## against an unset previous triple -- implicit zeroes -- and, depending on how the diff is written,
## fires at match start before anything has been earned. The guard is that the FIRST call RECORDS
## and returns. Both halves are proven here, because either alone is passable by a broken build:
##   (a) NO flash on the priming emission -- passable on its own by a cue that never fires at all;
##   (b) a flash DOES fire on a real subsequent increase -- passable on its own by a cue that fires
##       on everything, priming included.
##
## AND A THIRD, which is what makes (b) about an INCREASE rather than about any change at all: a
## DECREASE (the round-boundary reset dropping the pool to zero) must NOT flash. A reset is not an
## earn, and both viewports would otherwise strobe on every press of R.
##
## THE ORB POOL IS DRIVEN DIRECTLY, not through a card cast: running a real chargeup here would
## duplicate test_orbs_economy.gd's own state-level coverage for no new signal. What THIS file needs
## is the seam -> controller -> node path, reached by adding to the live `PlayerState.orbs` the
## runner already wired -- the queued `orbs_changed` push is drained by `MatchState.advance()`,
## called every tick from match_runner's one `_physics_process` (F1), so a frame gap after each poke
## lets the real dispatch run for real (the test_charge_telegraph_dispatch_live.gd idiom).
##
## CROSS-SLOT, on that same file's discipline: P1's earn must leave P2's flash dark. The per-slot
## seam binding in match_runner.gd is what makes that true and a cross-wired seam is exactly the
## class of bug it exists to prevent.
##
## MUTATION (recorded in the story's Dev Agent Record): delete the `_orb_counts.is_empty()` early
## return in TelegraphController.on_orbs_changed and case (a) goes RED.
##
## Run: godot --headless --path . --script res://test/integration/test_orb_cue_live.gd

const CHECK_DELAY := 2  ## frames between a poke and reading its result (test_totem_tint_live precedent)
const FLASH_PATH := "OrbFlash"
## The one-shot hold is a wall-clock tween (0.25 s); headless frames cost no wall-clock time, so the
## settle check polls with a REAL delay rather than counting frames. Budget = 4x the authored hold.
const SETTLE_POLL_MSEC := 10
const SETTLE_POLL_BUDGET := 100

var _frames := 0
var _runner: Node
var _state: MatchState
var _hero: HeroActor
var _p2_hero: HeroActor
var _player: PlayerState
var _phase := "prime"
var _phase_frame := 0
var _failures: Array[String] = []
var _seen_tints: Array = []
var _settle_polls := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _flash(hero: HeroActor) -> MeshInstance3D:
	var node: Variant = hero.telegraph_controller.get_node_or_null(FLASH_PATH)
	if node == null:
		_failures.append("OrbFlash node not found on %s" % hero.name)
		return null
	return node as MeshInstance3D


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_hero = _runner._p1_hero if _runner != null else null
		_p2_hero = _runner._p2_hero if _runner != null else null
		_player = _state.p1 if _state != null else null
		if _runner == null or _state == null or _hero == null or _p2_hero == null or _player == null:
			print("missing: runner=%s state=%s hero=%s p2_hero=%s player=%s"
					% [_runner, _state, _hero, _p2_hero, _player])
			print("RESULT: FAIL")
			quit(1)
			return false
		_phase_frame = _frames
		return false

	# (a) THE PRIMING EMISSION ALREADY HAPPENED -- at match start, inside the runner's wiring loop,
	# several frames before this check. The pool is still resting at (0,0,0) and no flash may be up.
	if _phase == "prime" and _frames - _phase_frame >= CHECK_DELAY:
		if _player.orbs.get_count(Enums.CardColor.RED) != 0:
			_failures.append("setup: P1's orb pool is not resting at zero, so the priming case is not clean")
		var flash := _flash(_hero)
		if flash != null and flash.visible:
			_failures.append("(a) OrbFlash is LIT after the priming emission -- the cue fired on a "
					+ "connect, not on an earn")
		_phase = "earn"
		_phase_frame = _frames
		return false

	# (b) A REAL INCREASE. The queued orbs_changed is drained by advance() next tick and the seam
	# carries it to the controller, exactly as a landing's grant would.
	if _phase == "earn" and _frames - _phase_frame >= 1:
		var flash := _flash(_hero)
		if flash != null and flash.visible:
			_failures.append("(b) OrbFlash was ALREADY lit before the earn -- a pass would prove nothing")
		_player.orbs.add(Enums.CardColor.BLUE, 1)
		_phase = "earned"
		_phase_frame = _frames
		return false

	if _phase == "earned" and _frames - _phase_frame >= CHECK_DELAY:
		var flash := _flash(_hero)
		if flash == null or not flash.visible:
			_failures.append("(b) no OrbFlash after a REAL increase -- the cue never fires at all")
		elif flash.material_override is StandardMaterial3D:
			# OBSERVED, not expected: whatever the production dispatch actually tinted it. BLUE was
			# earned, so a RED or GREEN tint here is a colour mis-map, not a pass.
			var tint: Color = (flash.material_override as StandardMaterial3D).albedo_color
			_seen_tints.append(tint)
			if tint.b <= tint.r or tint.b <= tint.g:
				_failures.append("(b) BLUE was earned but OrbFlash is tinted %s" % tint)
		else:
			_failures.append("(b) OrbFlash carries no StandardMaterial3D after the earn")
		# CROSS-SLOT: P1's earn is P1's alone.
		var p2_flash := _flash(_p2_hero)
		if p2_flash != null and p2_flash.visible:
			_failures.append("(b) P1's earn lit P2's OrbFlash -- the seam is cross-wired")
		_phase = "settle"
		_phase_frame = _frames
		return false

	# The one-shot tween must put the flash away again; a cue that latches on is a hero wearing a lit
	# orb for the rest of the match (the ChargeMarker finding, one cue over).
	#
	# POLLED WITH A REAL DELAY, not waited out in frames: the hold is a TWEEN, and a tween measures
	# WALL-CLOCK seconds while headless frames advance at no wall-clock cost -- a frame COUNT alone
	# would read the flash as still lit no matter how large the count (this file measured exactly
	# that before the delay went in). The budget below is four times the authored hold, so a pass
	# means the tween finished, not that the poll gave up.
	if _phase == "settle":
		var flash := _flash(_hero)
		if flash == null or not flash.visible:
			_phase = "decrease"
			_phase_frame = _frames
			return false
		_settle_polls += 1
		if _settle_polls > SETTLE_POLL_BUDGET:
			_failures.append("OrbFlash is STILL lit %.1f s after the one-shot -- it latched on"
					% (SETTLE_POLL_BUDGET * SETTLE_POLL_MSEC / 1000.0))
			_phase = "decrease"
			_phase_frame = _frames
			return false
		OS.delay_msec(SETTLE_POLL_MSEC)
		return false

	# (c) A DECREASE IS NOT AN EARN. reset_all() is what the debug reset calls, through the same
	# channel; the cue must stay dark.
	if _phase == "decrease" and _frames - _phase_frame >= 1:
		_player.orbs.reset_all()
		_phase = "decreased"
		_phase_frame = _frames
		return false

	if _phase == "decreased" and _frames - _phase_frame >= CHECK_DELAY:
		if _player.orbs.get_count(Enums.CardColor.BLUE) != 0:
			_failures.append("(c) setup: the reset did not actually clear the pool")
		var flash := _flash(_hero)
		if flash != null and flash.visible:
			_failures.append("(c) OrbFlash fired on a DECREASE -- a reset is not an earn")
		_report()
		return false

	return false


func _report() -> void:
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("tints seen: %s" % [_seen_tints])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
