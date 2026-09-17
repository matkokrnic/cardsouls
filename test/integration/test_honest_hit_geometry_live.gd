extends SceneTree

## Story 6-1d (AC 1/AC 2/AC 4/AC 5/AC 6): HONEST HIT GEOMETRY -- the live half, and the POSITIVE
## half of what `test_unblockable_reach_live.gd` now asserts negatively.
##
## Everything here runs through the REAL runner: `_push_charge_reach_facts` running melee's own
## `get_overlapping_areas()` query against the defender's real `Hurtbox` shape, `HeroActor.drive()`
## reparking the `HitboxShape` on the paladin's sword joint every tick (5-0a), `advance()` carrying
## the launch, and `_resolve_charge_landing` resolving once. A headless fixture cannot reach any of
## that -- it pushes the KIND by hand, which is precisely the thing under test here.
##
## FOUR CASES PER COLOUR, each a full chargeup -> commit -> launch -> landing:
##   touch  -- the defender stands where the launch brings the blade onto its body. HIT, latched
##             INSIDE, and EXACTLY ONE damage instalment however many ticks reported contact (AC 1,
##             AC 5).
##   clamp  -- the SAME layout, run against a config whose per-colour reach has been clamped below
##             body contact. MISS: the authored reach is an UPPER BOUND on honest geometry and can
##             only ever REMOVE a hit (AC 2, proved by a test rather than by a `.tres` diff). The
##             authored resource on disk is never touched -- the clamp is a `duplicate()` applied to
##             the live state for one case and dropped again.
##   charge -- the defender is pressed against the attacker for the FEINTABLE chargeup (the blade is
##             already visibly in motion there) and leaves well before the commit. MISS: the contact
##             window opens AT the commit and never earlier (AC 4). The case asserts that a real
##             overlap WAS observed during the chargeup, so it cannot pass vacuously.
##   flee   -- the defender is touched during the launch and then teleports clear, with launch ticks
##             still to run, so the LAST evaluated tick is clean. HIT (AC 6, the deliberate
##             supersession of `6-1c` AC 3: touched at any evaluated tick is no longer a guaranteed
##             miss). The teleport is triggered off an OBSERVED contact rather than a tick count, so
##             the case fails loudly instead of passing vacuously if contact never happened.
##   frozen -- `6-1d/R9`: the defender is parked clear, the attacker commits, and the round is then
##             forced over mid-launch with the defender moved onto the blade. The round-over freeze
##             holds the contact window open while the rig keeps its pose, and the runner must push
##             NOTHING: the verdict never becomes INSIDE although real overlap is observed. A debug
##             reset then ends the frozen flight and must leave the verdict at REACH_UNKNOWN.
##
## THE LAYOUT IS DERIVED, NEVER PINNED (the `test_contact_pipeline.gd` precedent): the standing
## distance is the colour's authored launch travel plus one body width, and every case is skipped
## with a printed note rather than failing if a retune moves the authored reach below that. Feel
## knobs stay editable without a suite edit (`6-1b`/`6-1c` precedent).
##
## THE CHARGEUP IS POKED, NOT CAST (the `test_unblockable_reach_live.gd` precedent): colour, the two
## windows the cast seat starts, and CHARGING -- with P1's controller replaced by a stand-in that
## HOLDS the cast confirm so the chargeup is not feinted. The cast seat is covered headless.
##
## Run: godot --headless --path . --script res://test/integration/test_honest_hit_geometry_live.gd

class HoldingController extends Controller:
	## `6-1d/R9` frozen case: one debug reset on the next sample, then back to holding.
	var reset_next := false

	func sample() -> InputIntent:
		var intent := InputIntent.new()
		intent.held[&"card_cast"] = true
		intent.debug_reset = reset_next
		reset_next = false
		return intent


const CONFIG_PATH := "res://data/balance/balance_config.tres"
## One body width. The hero `Collision`/`HurtboxShape` box is 1 x 2 x 1 (hero.tscn), so two heroes
## standing this far apart are just touching -- the layout where a blade swung between them must
## connect, and the closest an honest one ever gets.
const BODY := 1.0
## Where the defender is parked when it must be nowhere near the blade: clear of the launch, clear
## of the body, and clear of the authored radius too, so no case can leak into another.
const CLEAR := 4.0
## The clamped reach for the AC 2 case -- far below body contact, so geometry alone would land it.
const CLAMPED_REACH := 0.2
const SETTLE := 3
const AFTER := 2
const DEADLINE := 6000
const HP_EPS := 1e-3
const P1_START := Vector3(-6.0, 0.0, 0.0)
## `6-1d/R9` frozen case: frames the round-over freeze is observed for, then frames the reset settles.
const FROZEN_FRAMES := 20
const RESET_SETTLE := 3

var _frames := 0
var _runner: Node
var _state: MatchState
var _p1_actor: HeroActor
var _p2_actor: HeroActor
var _config: BalanceConfig
var _clamped: BalanceConfig
var _ticks: BalanceTicks
var _failures: Array[String] = []

var _cases: Array = []   # [colour, kind] with kind in {"touch", "clamp", "charge", "flee"}
var _case_index := 0
var _phase := "setup"
var _phase_frame := 0
var _hp_before := 0.0
var _cast_pos := Vector3.ZERO
var _saw_overlap := false
var _fled := false
var _contact_ticks := 0
var _y := 0.0
var _holder: HoldingController
var _frozen_frame := -1
var _frozen_inside := false


func _initialize() -> void:
	root.add_child((load("res://src/main/main.tscn") as PackedScene).instantiate())
	_config = load(CONFIG_PATH)
	_ticks = BalanceTicks.from_config(_config)
	# The AC 2 clamp: the AUTHORED resource duplicated in memory with its three reaches pulled below
	# body contact. Nothing on disk changes, and the duplicate is applied to the live state for one
	# case only.
	_clamped = _config.duplicate()
	_clamped.unblockable_reach_red = CLAMPED_REACH
	_clamped.unblockable_reach_blue = CLAMPED_REACH
	_clamped.unblockable_reach_green = CLAMPED_REACH
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		for kind in ["touch", "clamp", "charge", "flee", "frozen"]:
			_cases.append([color, kind])


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_p1_actor = _runner._p1_hero if _runner != null else null
		_p2_actor = _runner._p2_hero if _runner != null else null
		if _state == null or _p1_actor == null or _p2_actor == null:
			_failures.append("main scene did not yield a runner, a MatchState and two heroes")
			_report()
			return true
		_holder = HoldingController.new()
		_runner._p1_controller = _holder
		_y = _p1_actor.position.y
		return false
	if _phase == "draining":
		if _frames - _phase_frame >= SETTLE:
			_report()
			return true
		return false
	if _frames > DEADLINE:
		_failures.append("deadline: stuck in case %d phase %s" % [_case_index, _phase])
		_finish()
		return false
	if _case_index >= _cases.size():
		_finish()
		return false
	var color: int = _cases[_case_index][0]
	var kind: String = _cases[_case_index][1]
	var label := "colour %d %s" % [color, kind]
	var travel := _config.unblockable_launch_distance_for(color)
	var reach := _config.unblockable_reach_for(color)
	var player := _state.p1

	if _phase == "setup":
		# The authored reach must still admit body contact, or the fixture has nothing to say. A
		# retune below that reschedules the case with a note instead of failing (BC/R3).
		if reach < BODY:
			print("  note: %s authored reach %.2f is below one body width -- case not run"
				% [label, reach])
			_case_index += 1
			return false
		_state.apply_balance(_clamped if kind == "clamp" else _config)
		# `6-1d/R11`: P2 starts every case at full HP. Six cases are EXPECTED to land, and no HP regen
		# exists, so an authored damage retune could otherwise kill P2 mid-run -- the round-over freeze
		# would then hold P1 in CHARGING forever and the run would burn to DEADLINE instead of judging.
		_state.p2.hero.heal(_state.p2.hero.get_max_hp())
		# Story 6-6a: a case that LANDS now knocks P2 down (AC 3), and the get-up that follows opens
		# iframes that dodge an unblockable (R-IFRAME-UNBLOCKABLE) -- so a later case's landing could be
		# answered by an earlier case's knockdown rather than by its own geometry (measured: both
		# `flee` cases after a `touch` landed inside the get-up window). Every case therefore starts P2
		# UP and UNPROTECTED, on the full-HP line's reasoning directly above.
		if _state.p2.hero.action_state == HeroState.ActionState.STUNNED:
			_state.p2.hero.set_action_state(HeroState.ActionState.IDLE)
		_state.p2.hero.stun.start(0)
		_state.p2.hero.get_up_iframe.start(0)
		_p1_actor.position = P1_START + Vector3(0.0, _y, 0.0)
		# "charge" parks the defender against the attacker for the chargeup; every other case parks
		# it where the LAUNCH will bring the blade onto it.
		var d := BODY if kind == "charge" else travel + BODY
		if kind == "frozen":
			d = travel + reach + CLEAR
		_p2_actor.position = P1_START + Vector3(d, _y, 0.0)
		_phase = "settle"
		_phase_frame = _frames
		return false

	if _phase == "settle" and _frames - _phase_frame >= SETTLE:
		_hp_before = _state.p2.hero.get_hp()
		_cast_pos = _p1_actor.position
		_saw_overlap = false
		_fled = false
		_contact_ticks = 0
		_frozen_frame = -1
		_frozen_inside = false
		# The cast seat's three writes, in its order.
		player.charge_color = color
		player.charge_window.start(_ticks.unblockable_chargeup_ticks)
		player.landing_window.start(_ticks.unblockable_chargeup_ticks
				+ _ticks.unblockable_launch_ticks_for(color))
		player.hero.set_action_state(HeroState.ActionState.CHARGING)
		_phase = "charging"
		_phase_frame = _frames
		return false

	if _phase == "charging":
		if _frames - _phase_frame < 2:
			return false  # let the seam drain the CHARGING transition into the controller
		if kind == "frozen":
			_step_frozen(label, player)
			return false
		if player.hero.action_state == HeroState.ActionState.CHARGING:
			if _blade_overlaps():
				_saw_overlap = true
				# Counted INDEPENDENTLY of the runner's latch, by asking the physics server the same
				# question ourselves -- so the AC 5 claim below is about real overlapping ticks and
				# not about how long a sticky latch stayed set.
				_contact_ticks += 1
			if kind == "charge" and player.charge_window.remaining_ticks() <= 6 and not _fled:
				# Well before the commit: the blade has been inside the body for most of the
				# feintable chargeup and the defender is gone with ticks to spare.
				_fled = true
				_check(_saw_overlap, "%s: the defender never actually overlapped the blade during "
					% label + "the chargeup -- the case would pass vacuously")
				_p2_actor.position = _cast_pos + Vector3(travel + reach + CLEAR, 0.0, 0.0)
			if kind == "flee" and not _fled and not player.charge_window.is_running \
					and _state._charge_reach[0] == MatchState.CONTACT_CHARGE_REACH_INSIDE \
					and player.landing_window.remaining_ticks() >= 3:
				# Touched at an evaluated tick, with evaluated ticks still to run: clear away, so
				# the LAST tick the check runs on reports nothing at all.
				_fled = true
				_p2_actor.position = _cast_pos + Vector3(travel + reach + CLEAR, 0.0, 0.0)
			return false
		# First frame after the landing.
		var hit := _state.p2.hero.get_hp() < _hp_before - HP_EPS
		var latched: int = _state._charge_reach[0]
		var damage := _config.unblockable_damage_percent_of_max_hp / 100.0 \
				* _state.p2.hero.get_max_hp()
		match kind:
			"touch":
				_check(hit, "%s: the launch brought the blade onto the body and nothing landed "
					% label + "(AC 1) -- latched kind %d, %d contact tick(s)"
						% [latched, _contact_ticks])
				_check(latched == MatchState.CONTACT_CHARGE_REACH_INSIDE,
					"%s: the runner latched kind %d, want INSIDE" % [label, latched])
				# AC 5: many ticks reported contact, ONE resolution came out of it.
				_check(_contact_ticks > 1, "%s: only %d tick reported contact -- AC 5's "
					% [label, _contact_ticks] + "many-ticks-one-landing claim is untested here")
				_check(absf((_hp_before - _state.p2.hero.get_hp()) - damage) < HP_EPS,
					"%s: %d contact ticks took %.3f hp, want exactly ONE instalment of %.3f (AC 5)"
						% [label, _contact_ticks, _hp_before - _state.p2.hero.get_hp(), damage])
			"clamp":
				_check(not hit, "%s: the authored reach was clamped to %.2f -- below body contact "
					% [label, CLAMPED_REACH] + "-- and a geometrically reachable defender still "
					+ "landed. Reach must be an UPPER BOUND that can only REMOVE a hit (AC 2)")
				_check(latched == MatchState.CONTACT_CHARGE_REACH_OUTSIDE,
					"%s: the runner latched kind %d, want OUTSIDE" % [label, latched])
				# `6-1d/R11`: non-vacuity -- the blade really did reach the body, so the MISS above is
				# the clamp refusing a real contact rather than geometry that never touched.
				_check(_contact_ticks > 0, "%s: the blade never overlapped the body -- the clamp "
					% label + "had nothing to refuse and the case would pass vacuously")
			"charge":
				_check(_fled, "%s: never reached the pre-commit teleport" % label)
				_check(not hit, "%s: contact during the FEINTABLE chargeup credited damage -- the "
					% label + "contact window must open AT the commit and never earlier (AC 4)")
			"flee":
				_check(_fled, "%s: never observed a contact tick with launch ticks left to flee "
					% label + "-- the case cannot judge AC 6")
				if _fled:
					_check(hit, "%s: the defender was touched at an evaluated tick and cleared the "
						% label + "blade before the landing -- that is a HIT since 6-1d (AC 6 "
						+ "supersedes 6-1c AC 3), latched kind %d" % latched)
		_phase = "after"
		_phase_frame = _frames
		return false

	if _phase == "after":
		if _frames - _phase_frame >= AFTER:
			_case_index += 1
			_phase = "setup"
		return false
	return false


## `6-1d/R9`: the round-over freeze pushes no charge-reach fact, and the debug reset clears the verdict.
func _step_frozen(label: String, player: PlayerState) -> void:
	if _frozen_frame < 0:
		if player.charge_window.is_running or player.hero.action_state != HeroState.ActionState.CHARGING:
			return
		# Committed, launch running, parked clear so far: force the round over and put the defender
		# on the blade -- its body centre just beyond the tracked blade shape, along the line from the
		# attacker's centre, so the hurtbox box contains the blade wherever this colour's pose left it.
		_check(_state._charge_reach[0] != MatchState.CONTACT_CHARGE_REACH_INSIDE,
			"%s: sanity -- the parked defender was already latched INSIDE before the freeze" % label)
		_state._end_round(_state.p2, 1)
		var blade: Vector3 = _p1_actor.hitbox_shape.global_position
		var out := Vector3(blade.x - _p1_actor.global_position.x, 0.0,
				blade.z - _p1_actor.global_position.z)
		out = out.normalized() if not out.is_zero_approx() else Vector3(1.0, 0.0, 0.0)
		_p2_actor.global_position = Vector3(blade.x, _p2_actor.global_position.y, blade.z) \
				+ out * (BODY * 0.4)
		# `6-1d/R14` (review2 LOW-B): the overlap check above only proves the blade shape touches
		# the body -- it says nothing about the runner's OTHER conjunct, the reach pre-filter. A
		# retune that shrinks reach below this placement would make the overlap-vacuity check pass
		# for the wrong reason (the runner would have refused on reach, never reaching the arc gate
		# this case exists to prove). Assert the placement is still inside reach too.
		var reach := _config.unblockable_reach_for(player.charge_color)
		var planar := Vector2(_p2_actor.global_position.x - _p1_actor.global_position.x,
				_p2_actor.global_position.z - _p1_actor.global_position.z)
		_check(planar.length() <= reach,
			"%s: sanity -- the frozen placement (%.2f) is outside colour %d's authored reach "
				% [label, planar.length(), player.charge_color]
				+ "(%.2f), so a real runner would refuse on reach alone and the overlap proof "
					% reach + "would be vacuous")
		_frozen_frame = _frames
		return
	var since := _frames - _frozen_frame
	if since <= FROZEN_FRAMES:
		_check(player.is_contact_window_open(),
			"%s: sanity -- the freeze should hold the contact window OPEN (frame %d)" % [label, since])
		if since > 2 and _blade_overlaps():
			_contact_ticks += 1
		if _state._charge_reach[0] == MatchState.CONTACT_CHARGE_REACH_INSIDE:
			_frozen_inside = true
		if since == FROZEN_FRAMES:
			_check(_contact_ticks > 0, "%s: the blade never overlapped the body during the freeze "
				% label + "-- the gate had nothing to refuse and the case would pass vacuously")
			_check(not _frozen_inside, "%s: the runner latched INSIDE during the round-over freeze "
				% label + "from geometry no one played (`6-1d/R9`), %d overlapping frame(s)"
					% _contact_ticks)
			_holder.reset_next = true
		return
	if since < FROZEN_FRAMES + RESET_SETTLE:
		return
	_check(player.hero.action_state != HeroState.ActionState.CHARGING,
		"%s: sanity -- the debug reset should have ended the frozen flight" % label)
	_check(_state._charge_reach[0] == MatchState.REACH_UNKNOWN,
		"%s: the debug reset left the verdict at kind %d, want REACH_UNKNOWN (`6-1d/R9`)"
			% [label, _state._charge_reach[0]])
	_phase = "after"
	_phase_frame = _frames


## The runner's own question, asked independently here so a case can prove it was not vacuous: does
## the attacker's tracked blade volume overlap the defender's hurtbox RIGHT NOW?
func _blade_overlaps() -> bool:
	for area: Area3D in _p1_actor.hitbox.get_overlapping_areas():
		if area.get_parent() == _p2_actor:
			return true
	return false


## The `test_unblockable_reach_live.gd` teardown, for its measured reason: every CHARGING transition
## starts a charge sting, and a still-playing AudioStreamPlayer torn down on the frame it stops leaks
## its mixer playback resource across quit() (an `ERROR:` line run_all.sh fails on).
func _finish() -> void:
	# Leave the live state on the AUTHORED config, never on the clamped duplicate.
	if _state != null and _config != null:
		_state.apply_balance(_config)
	for actor: Node in [_p1_actor, _p2_actor]:
		if is_instance_valid(actor):
			for node in actor.find_children("*", "AudioStreamPlayer", true, false):
				(node as AudioStreamPlayer).stop()
	OS.delay_msec(100)
	_phase = "draining"
	_phase_frame = _frames


func _report() -> void:
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
