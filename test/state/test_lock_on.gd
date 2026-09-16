extends TestCase

## Story 4-6 (camera lock-on) — the STATE half, headless. Everything the lock does inside
## `advance()`: where it rests, how a retarget enters, when it snaps off a dead target, and how it
## survives a debug reset. Plus the two PURE presentation policies this story ships —
## `LockOnResolver.cycle_candidate` (the flick's CYCLING pick: 4-6's cone, replaced by 4-6a's
## screen-X adjacency, replaced by 6-8's bearing-based 360 cycling) and
## `GamepadController.resolve_flick` (the flick EDGE) — both of which are static functions over
## plain values precisely so they can be proven here rather than only at a live smoke.
##
## WHAT IS NOT HERE, and where it is instead: the FACING WRITE that the lock feeds is pinned in
## test_camera_basis.gd (it is a movement-seam property, and that file owns the seam); the roll
## BACKSTEP (`4-6/R7`) is in test_roll_iframes.gd beside the roll it modifies; the RIG YAW and the
## live camera basis are integration-only and live in test/integration/test_camera_relative.gd and
## test_lock_on_live.gd; the RECORD CHANNEL is in test_replay_identity.gd and test_record_file.gd.

const UNIT_MAX_HP := 6.0
const UNIT_DAMAGE := 6.0   # exactly lethal in ONE hero hit, so the snap lands on a known tick
const HERO_INDEX := TargetingService.HERO_INDEX


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = 5.0
	c.max_stamina = 100.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 10.0
	c.block_facing_arc_degrees = 180.0
	c.roll_duration_seconds = 5.0 / 60.0
	c.roll_distance = 3.0
	c.unit_kinds = UnitKindFixture.minion_only(UNIT_MAX_HP, UNIT_DAMAGE, 0, 0, 0, 2.0)
	c.hero_damage_to_unit = UNIT_DAMAGE
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.minions = true
	return f


func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(7))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags())
	ms.drain_signals()
	return ms


func _intent(pressed_keys: Array = []) -> InputIntent:
	var i := InputIntent.new()
	for k in pressed_keys:
		i.pressed[k] = true
		i.held[k] = true
	return i


func _retarget_intent(slot: int, index: int) -> InputIntent:
	var i := InputIntent.new()
	i.retarget_slot = slot
	i.retarget_index = index
	return i


func _advance(ms: MatchState, p1_intent: InputIntent = null,
		p2_intent: InputIntent = null) -> void:
	var intents: Array[InputIntent] = [
		p1_intent if p1_intent != null else InputIntent.new(),
		p2_intent if p2_intent != null else InputIntent.new(),
	]
	ms.advance(intents)
	ms.drain_signals()


func _lock(player: PlayerState) -> Array:
	return [player.lock_target_slot, player.lock_target_index]


# ---------------------------------------------------------------- CC/R2: the resting lock

## `CC/R2` / AC 2: the default and fallback target is ALWAYS the opposing hero, and it is set at
## CONSTRUCTION rather than on the first tick — so a MatchState that has never advanced, and one
## that never receives a lock direction at all, still holds a real address rather than a sentinel.
func test_a_fresh_match_is_already_locked_on_the_opposing_hero() -> void:
	var ms := _make_match()
	assert_eq(_lock(ms.p1), [1, HERO_INDEX], "P1 starts locked on P2's hero")
	assert_eq(_lock(ms.p2), [0, HERO_INDEX], "P2 starts locked on P1's hero — per slot, not global")
	_advance(ms)
	assert_eq(_lock(ms.p1), [1, HERO_INDEX], "...and a tick with no retarget changes nothing")
	assert_eq(_lock(ms.p2), [0, HERO_INDEX])


## AC 2/AC 4: the lock is a SNAPSHOT KEY, in the `unit_targets` shape — one key holding a
## `[slot, index]` pair of plain ints. It is hashed because it crosses ticks and decides where the
## hero faces; the DIRECTION to the target is deliberately NOT here (it is a pushed runner fact).
func test_the_lock_reaches_the_snapshot_as_a_slot_index_pair() -> void:
	var ms := _make_match()
	var snap: Dictionary = ms.p1.to_snapshot()
	assert_true(snap.has("lock_target"), "the lock is a snapshot key")
	assert_eq(snap["lock_target"], [1, HERO_INDEX], "...carrying the resting opposing-hero address")
	for half in (snap["lock_target"] as Array):
		assert_true(half is int, "both halves are plain ints — counts and indices, never identities")
	ms.set_lock_direction(0, Vector2(0.6, 0.8))
	_advance(ms)
	var text := str(ms.p1.to_snapshot()["lock_target"])
	assert_false(text.contains("0.6"),
		"the pushed DIRECTION does not reach the snapshot through this key — only the address does")


# ---------------------------------------------------------------- AC 9/AC 10/AC 11: retargeting

## AC 11: the retarget enters as a RESOLVED ADDRESS on the intent and takes effect on the tick it
## was pressed — the same tick-N rule attack/block/roll presses get, which is what AC 9's
## "instantly" means at this layer.
func test_a_retarget_on_the_intent_takes_effect_the_same_tick() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_advance(ms, _retarget_intent(1, 0))
	assert_eq(_lock(ms.p1), [1, 0], "P1 is locked onto P2's unit 0 at the end of the very tick it asked")
	assert_eq(_lock(ms.p2), [0, HERO_INDEX], "...and the OTHER slot's lock is untouched: per player")


## AC 9: a re-lock is just a retarget whose address is the opposing hero, so the click needs no
## second mechanism — and it works FROM a unit lock, which is the case it exists for (the opposing
## hero has gone off screen and a flick cannot reach it).
func test_a_relock_returns_to_the_opposing_hero_from_a_unit_lock() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_advance(ms, _retarget_intent(1, 0))
	assert_eq(_lock(ms.p1), [1, 0], "sanity: locked onto the unit first")
	_advance(ms, _retarget_intent(1, HERO_INDEX))
	assert_eq(_lock(ms.p1), [1, HERO_INDEX], "the click's address puts the hero back in lock")


## AC 10: a flick that found no candidate is expressed by sending NO
## REQUEST — `retarget_slot` at its resting NO_RETARGET. The standing lock must survive that
## untouched, which is what makes the no-op a no-op rather than a silent reset.
func test_a_tick_with_no_request_leaves_the_standing_lock_alone() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_advance(ms, _retarget_intent(1, 0))
	var resting := InputIntent.new()
	assert_eq(resting.retarget_slot, InputIntent.NO_RETARGET,
		"sanity: a fresh intent really does request nothing")
	for _t in 5:
		_advance(ms, resting)
	assert_eq(_lock(ms.p1), [1, 0], "five quiet ticks later the unit lock is still held")


# ---------------------------------------------------------------- 6-8 AC 1/AC 2: the UNLOCKED state

## Story 6-8 (AC 1/AC 2, Open Questions 1 and 3): the unlock request is the SENTINEL ADDRESS on the
## existing retarget pair, `[PlayerState.UNLOCKED_SLOT, HERO_INDEX]`, applied at the same seat on
## the same tick -- and the lock then HOLDS that sentinel. A hero address relocks from it.
##
## THE SNAPSHOT SHAPE IS UNCHANGED (Golden Prediction cause 1): still one `lock_target` key holding
## two plain ints, so an unlocked player adds no key to the hashed set.
##
## MUTATION PROOF: delete the UNLOCKED_SLOT branch in `_is_applicable_retarget` and the request is
## rejected as malformed -- the first assertion reads the standing `[1, -1]`.
func test_the_unlock_address_unlocks_and_a_hero_address_relocks() -> void:
	var ms := _make_match()
	_advance(ms, _retarget_intent(PlayerState.UNLOCKED_SLOT, HERO_INDEX))
	assert_eq(_lock(ms.p1), [PlayerState.UNLOCKED_SLOT, HERO_INDEX], "P1 unlocked on the tick it asked")
	assert_false(ms.p1.is_locked(), "...and reads as unlocked")
	assert_true(ms.p2.is_locked(), "the other slot is untouched: per player")
	var snap: Dictionary = ms.p1.to_snapshot()
	assert_eq(snap["lock_target"], [PlayerState.UNLOCKED_SLOT, HERO_INDEX],
		"the unlocked state is the SAME key with the sentinel pair -- no new snapshot key")
	for _t in 4:
		_advance(ms)
	assert_false(ms.p1.is_locked(), "quiet ticks leave it unlocked: `_validate_lock` does not snap it")
	_advance(ms, _retarget_intent(1, HERO_INDEX))
	assert_eq(_lock(ms.p1), [1, HERO_INDEX], "a hero address relocks from the unlocked state")
	assert_true(ms.p1.is_locked())


## Story 6-8 (AC 2): the sentinel is EXACT. Only `[UNLOCKED_SLOT, HERO_INDEX]` unlocks; the same slot
## with a unit index is still the malformed request 5-1a rejects, so "unlock" has one spelling.
func test_only_the_exact_sentinel_pair_unlocks() -> void:
	var ms := _make_match()
	_advance(ms, _retarget_intent(PlayerState.UNLOCKED_SLOT, 0))
	assert_eq(_lock(ms.p1), [1, HERO_INDEX], "[-2, 0] is rejected and the standing lock holds")
	assert_true(ms.p1.is_locked())


## Story 6-8 (AC 20): the round still starts LOCKED -- a debug reset while unlocked restores the
## opposing-hero lock with everything else the reset restores.
func test_a_debug_reset_relocks_an_unlocked_player() -> void:
	var ms := _make_match()
	_advance(ms, _retarget_intent(PlayerState.UNLOCKED_SLOT, HERO_INDEX))
	assert_false(ms.p1.is_locked(), "sanity: unlocked")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset)
	assert_eq(_lock(ms.p1), [1, HERO_INDEX], "the reset round starts locked on the opposing hero")


## Story 6-8 (AC 22): the round-over freeze makes an unlock request inert exactly as it does a
## retarget -- no third carve-out, the step-1b return reaches the lock seat first.
func test_an_unlock_request_is_inert_once_the_round_is_over() -> void:
	var ms := _make_match()
	ms.p2.hero.take_damage(ms.p2.hero.get_max_hp())
	_advance(ms)
	_advance(ms, _retarget_intent(PlayerState.UNLOCKED_SLOT, HERO_INDEX))
	assert_true(ms.p1.is_locked(), "a frozen tick never reaches the lock seat")


# ------------------------------------------- 5-1a AC 1/AC 2: the malformed address is REJECTED

## Story 5-1a (AC 1/AC 2 half (a), `4-6` finding M3) — THE BEHAVIOURAL HALF.
##
## Through 4-6 this seat reported a malformed address with two `Invariant.check`s and then assigned
## it on the very next line, unconditionally. `Invariant.check` is `push_error` + `assert`, and
## `assert` is STRIPPED in an exported build, so an exported build logged the violation and then
## wrote the malformed address straight into the hashed `lock_target` key.
##
## WHY A PASS HERE ATTRIBUTES THE REJECTION TO THE BRANCH AND TO NOTHING ELSE: an `assert` cannot
## skip an assignment in ANY build — it aborts or it does nothing — so an observation that the lock
## target did NOT move can only be a branch declining to write. This test therefore reads the same
## with assertions compiled in or stripped, which is what makes AC 2's export claim machine-backed
## at the level a headless suite can reach it (the seat's freedom from `Invariant.check` is pinned
## by the scan below).
##
## MUTATION PROOF: remove the `_is_applicable_retarget` branch and assign unconditionally — this
## goes RED on the first malformed address, reading `[2, 0]` where `[1, 0]` was held.
##
## THE PAIR, in both directions: a WELL-FORMED address is applied before the loop and another is
## applied after it, so "unchanged" is never the seat simply refusing everything.
func test_a_malformed_retarget_address_is_rejected_and_the_standing_lock_is_untouched() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_advance(ms, _retarget_intent(1, 0))
	assert_eq(_lock(ms.p1), [1, 0], "sanity: a WELL-FORMED address IS applied at this seat")
	for malformed: Array in [
		[2, 0],     # a slot outside {0, 1} — the first 4-6 Invariant.check's own condition
		[7, 3],
		[-2, 0],    # negative, and NOT the NO_RETARGET resting value, so it is a real request
		[1, -2],    # a well-formed slot with an index below HERO_INDEX (-1)
		[0, -99],
	]:
		_advance(ms, _retarget_intent(malformed[0], malformed[1]))
		assert_true(ms.p2.units.is_alive_at(0),
			"sanity: the locked unit is still alive, so an unchanged lock is not a liveness snap")
		assert_eq(_lock(ms.p1), [1, 0],
			("%s is REJECTED: the lock target ends the tick at its PRE-CALL value, so nothing was "
			+ "written to the hashed `lock_target` key on this tick (AC 1)") % str(malformed))
		assert_eq(_lock(ms.p2), [0, HERO_INDEX],
			"...and the other slot's lock is untouched too")
	# THE RUN CONTINUES CLEAN: a rejection is a declined write, never a halt, and the very next
	# well-formed address still lands.
	_advance(ms, _retarget_intent(1, HERO_INDEX))
	assert_eq(_lock(ms.p1), [1, HERO_INDEX],
		"the match ran on through five rejections and the next GOOD address is applied normally")


## Story 5-1a (AC 2 half (b), `5-1a/R9`) — THE SOURCE SCAN, the `test_targeting_service.gd:161-167`
## idiom. Two claims a behavioural test cannot make on its own:
##
## 1. The `_resolve_lock` seat carries NO `Invariant.check`. Not "one that never fires" — none at
##    all. Keeping one was never an option: `test/run_all.sh` greps both harnesses for
##    `INVARIANT VIOLATED` and fails the WHOLE suite on a hit, so the test above and a retained
##    check cannot both be green.
## 2. Both halves of the address are assigned ONLY under the guard — after it, and indented deeper
##    than it. This is the pin that makes the export claim re-checkable by a machine on every
##    future run rather than an inspection someone did once (no export build exists in this repo).
##
## MUTATION PROOF: dedent either assignment back to the function's own indent (an unconditional
## assignment, the 4-6 shape) and the indent assertion fails; add an `Invariant.check` back to the
## seat and the first assertion fails.
func test_the_lock_seat_carries_no_invariant_check_and_guards_both_assignments() -> void:
	var body := _function_body("res://src/state/match_state.gd", "func _resolve_lock(")
	assert_true(body.size() > 0, "the seat's body was read (a guard over nothing is vacuous)")
	var guard_line := -1
	var guard_indent := -1
	for i in body.size():
		var line: String = body[i]
		assert_false(line.contains("Invariant."),
			("`5-1a/R9`: the lock seat carries NO Invariant.check — it is `push_error` + a stripped "
			+ "`assert`, and run_all.sh fails the suite on the print: %s") % line.strip_edges())
		if guard_line < 0 and line.contains("if ") and line.contains("_is_applicable_retarget("):
			guard_line = i
			guard_indent = _indent_width(line)
	assert_true(guard_line >= 0,
		"the seat opens with the well-formedness branch, by name — the guard AC 1 rests on")
	var assignments := 0
	for i in body.size():
		var line: String = body[i]
		if not (line.contains("player.lock_target_slot =")
				or line.contains("player.lock_target_index =")):
			continue
		assignments += 1
		assert_true(i > guard_line,
			"the address assignment comes AFTER the guard: %s" % line.strip_edges())
		assert_true(_indent_width(line) > guard_indent,
			("...and is indented INSIDE it, so it is reachable only when the guard passes — an "
			+ "unconditional assignment at the seat's own indent is the 4-6 defect: %s")
					% line.strip_edges())
	assert_eq(assignments, 2,
		"BOTH halves of the address are assigned at this seat (slot and index), and the loop above "
		+ "put both of them under the guard — a half moved out would drop this count or fail above")


# ---------------------------------------------------------------- AC 3: the corpse-free snap

## AC 3 (`4-6/R4`, `4-6/R5`): a locked UNIT that dies releases the lock IMMEDIATELY, the SAME TICK,
## back to the opposing hero — no corpse-hold window, even though the corpse itself lingers on the
## board for several ticks (`4-3d`).
##
## SAME TICK IS THE WHOLE CLAIM, and it is why the assertion is taken on the kill tick rather than
## the one after: validating only at step 1c would leave the end-of-tick snapshot — the hashed one
## — pointing at a corpse for exactly one tick, which is a one-tick corpse-hold window under
## another name.
##
## MUTATION PROOF: delete the step-4b `_validate_lock` pair and this fails on the first assertion,
## reading `[1, 0]`; the tick-after assertion below would still pass, which is precisely why both
## are here.
func test_a_locked_units_death_snaps_the_lock_to_the_opposing_hero_on_the_kill_tick() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_advance(ms, _retarget_intent(1, 0))
	assert_eq(_lock(ms.p1), [1, 0], "sanity: locked onto the living unit")
	# P1 swings and a fact lands on the unit for exactly lethal damage.
	_advance(ms, _intent([&"attack"]))
	for _t in 3:
		_advance(ms)                       # windup t2-t4, active from t5
	ms.push_contact([0, HERO_INDEX], [1, 0], ms.p1.hero.attack_index, Vector2(-1, 0),
			MatchState.CONTACT_STRIKE)
	_advance(ms)                           # the KILL tick: step 4 kills, step 4b re-validates
	assert_false(ms.p2.units.is_alive_at(0), "sanity: the fact really did kill the unit")
	assert_eq(_lock(ms.p1), [1, HERO_INDEX],
		"the lock is back on the opposing hero at the END of the kill tick — no corpse hold")
	assert_eq(ms.p2.units.size(), 1,
		"...while the CORPSE is still on the board: the snap is about the lock, not the board")
	_advance(ms)
	assert_eq(_lock(ms.p1), [1, HERO_INDEX], "and it stays there")


## AC 3's other half, stated as its own test because it is a different mechanism: a lock whose
## board INDEX no longer exists at all — the debug reset clears the board — is invalid for the same
## reason a dead one is, and `has_index` is what catches it before `is_alive_at` can read past the
## cleared arrays.
func test_a_lock_onto_a_board_index_the_reset_deleted_returns_to_the_opposing_hero() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_advance(ms, _retarget_intent(1, 0))
	assert_eq(_lock(ms.p1), [1, 0], "sanity: locked onto a unit that exists")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset)
	assert_eq(ms.p2.units.size(), 0, "sanity: the reset cleared the board")
	assert_eq(_lock(ms.p1), [1, HERO_INDEX], "the lock did not survive the board it addressed")
	assert_eq(_lock(ms.p2), [0, HERO_INDEX], "both slots are back at the `CC/R2` default")


## AC 3: with the opposing HERO locked and dead, the round is over and step 1b's freeze makes lock
## resolution inert — the tick returns before the lock seat is reached, so nothing turns and
## nothing re-targets. Asserted rather than assumed, because "inert" is a claim about a seat's
## POSITION and a later re-seat would silently break it.
func test_lock_resolution_is_inert_once_the_round_is_over() -> void:
	var ms := _make_match()
	ms.p2.units.add(UNIT_MAX_HP, 0)
	ms.p2.hero.take_damage(ms.p2.hero.get_max_hp())
	_advance(ms)                            # step 8 ends the round on this tick
	var frozen := _lock(ms.p1)
	_advance(ms, _retarget_intent(1, 0))    # a click the frozen tick must not act on
	assert_eq(_lock(ms.p1), frozen,
		"a round-over tick never reaches the lock seat, so even an explicit retarget is inert")


# ------------------------------------------------- 6-8 AC 13-AC 18: BEARING-BASED 360 CYCLING

## Story 6-8 REPLACED THIS BLOCK'S SUBJECT a second time, on 4-6a's own precedent. Through 4-6a these
## tests described `LockOnResolver.adjacent_candidate`: adjacency by SCREEN X from the current
## target's screen position, on-screen candidates only, no wrap. That algorithm no longer exists, so
## no assertion about screen X, the no-wrap rule (superseded by AC 16) or the excluded current target
## (superseded by AC 17) is carried forward. What IS carried forward: the horizontal-only axis rule
## (AC 18) and the lower-board-index tie-break mechanism (AC 17).
##
## The successor subject is `LockOnResolver.cycle_candidate` over BEARINGS around the locking hero,
## with the current target included, plus `LockOnResolver.bearing_of` (the world-offset-to-bearing
## map). The bearing's link to SCREEN-RIGHT is a camera fact and is pinned against the real rig in
## test/integration/test_camera_freedom_live.gd (Open Question 5).

## A bearing in degrees, via the real map, so every fixture below is built from world OFFSETS and a
## wrong `bearing_of` fails here rather than hiding behind hand-written radians.
func _bearings_of(offsets: Array) -> Array[float]:
	var out: Array[float] = []
	for o: Vector2 in offsets:
		out.append(LockOnResolver.bearing_of(o))
	return out


## A world offset at `degrees` clockwise from -Z, `distance` from the hero.
func _at(degrees: float, distance: float) -> Vector2:
	return Vector2(sin(deg_to_rad(degrees)), -cos(deg_to_rad(degrees))) * distance


## Open Question 5, the WORLD half: -Z is 0, +X a quarter turn, +Z a half, -X three quarters -- one
## full clockwise circle viewed from above with -Z up the page. Always in [0, TAU).
func test_bearing_of_sweeps_clockwise_from_minus_z() -> void:
	assert_almost_eq(LockOnResolver.bearing_of(Vector2(0.0, -1.0)), 0.0, 1e-6, "-Z is bearing 0")
	assert_almost_eq(LockOnResolver.bearing_of(Vector2(1.0, 0.0)), PI / 2.0, 1e-6, "+X is a quarter turn")
	assert_almost_eq(LockOnResolver.bearing_of(Vector2(0.0, 1.0)), PI, 1e-6, "+Z is a half turn")
	assert_almost_eq(LockOnResolver.bearing_of(Vector2(-1.0, 0.0)), 1.5 * PI, 1e-6,
		"-X is three quarters -- never negative, the circle is [0, TAU)")
	assert_almost_eq(LockOnResolver.bearing_of(Vector2(-0.001, -1.0)), TAU, 0.01,
		"a hair left of -Z wraps to just under TAU rather than going negative")


## AC 15's testable claim, verbatim: with candidates to the left and right of the current target, the
## first RIGHT flick selects the nearest one by angle on the right, and the first LEFT flick the
## nearest on the left -- not the furthest and not the closest in space.
##
## MUTATION PROOF: flip `step`'s sign in `cycle_candidate` and both assertions read the other side.
func test_a_right_flick_takes_the_nearest_bearing_clockwise_and_left_the_nearest_counterclockwise() -> void:
	# The current target straight ahead (-Z); candidates at +30, +100 (right) and -20, -90 (left).
	var bearings := _bearings_of([
		Vector2(0.0, -5.0),                          # 0: current, bearing 0
		_at(100.0, 2.0),      # 1: +100 deg, NEAR in space, far in angle
		_at(30.0, 9.0),       # 2: +30 deg, far in space
		_at(-20.0, 9.0),      # 3: -20 deg
		_at(-90.0, 1.0),      # 4: -90 deg
	])
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 0.0), bearings, 0), 2,
		"a RIGHT flick takes the nearest bearing clockwise (+30), not the nearest body (+100)")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(-1.0, 0.0), bearings, 0), 3,
		"a LEFT flick takes the nearest bearing counter-clockwise (-20)")


## AC 13: a candidate BEHIND the hero is reachable -- there is no visibility filter in the pick, and
## the circle has no hole at the back. 4-6a could not express this at all.
func test_a_target_behind_the_hero_is_reachable() -> void:
	var bearings := _bearings_of([Vector2(0.0, -4.0), Vector2(0.3, 4.0)])  # current ahead; one behind
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 0.0), bearings, 0), 1,
		"the target directly behind is the next one clockwise")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(-1.0, 0.0), bearings, 0), 1,
		"...and, with only two, the next one counter-clockwise as well")


## AC 16: the order WRAPS. From the last candidate clockwise, a right flick continues from the first.
func test_cycling_wraps_past_the_last_candidate() -> void:
	var bearings := _bearings_of([Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0)])  # 0, 90, 180
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 0.0), bearings, 2), 0,
		"right from the last bearing (180) wraps to the first (0) instead of stopping")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(-1.0, 0.0), bearings, 0), 2,
		"left from the first wraps to the last")


## AC 17 / G2: one full sweep in EITHER direction visits every candidate exactly once and returns to
## the start -- including two candidates at an identical bearing AND one at the current target's own
## bearing. The tie-break is the lower board index (the gather's array order), in both roles.
##
## MUTATION PROOF: drop the `a < b` tie-break (return false on equal bearings) and the sort no longer
## gives a total order on ties, so the sweep either repeats or skips a tied candidate.
func test_a_full_sweep_visits_every_candidate_once_through_ties_and_the_current_bearing() -> void:
	var bearings := _bearings_of([
		Vector2(1.0, 0.0),    # 0: bearing 90 -- the CURRENT target
		Vector2(0.0, -1.0),   # 1: bearing 0
		Vector2(3.0, 0.0),    # 2: bearing 90 -- the current target's OWN bearing, higher index
		Vector2(0.0, 2.0),    # 3: bearing 180
		Vector2(0.0, 5.0),    # 4: bearing 180 -- tied with 3, higher index
	])
	for step: Vector2 in [Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]:
		var visited: Array[int] = []
		var at := 0
		for _i in bearings.size():
			var next := LockOnResolver.cycle_candidate(step, bearings, at)
			assert_true(next != -1, "a sweep with other candidates never no-ops")
			if next == -1:
				break
			visited.append(next)
			at = next
		assert_eq(at, 0, "after N flicks the sweep is back on the start (%s)" % str(step))
		var sorted_visits := visited.duplicate()
		sorted_visits.sort()
		assert_eq(sorted_visits, [0, 1, 2, 3, 4],
			"every candidate visited exactly once, no ping-pong (%s): %s" % [str(step), str(visited)])
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 0.0), bearings, 0), 2,
		"the co-bearing candidate is the current target's clockwise successor: lower index first")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 0.0), bearings, 3), 4,
		"of two tied bearings, the lower index comes first clockwise")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(-1.0, 0.0), bearings, 4), 3,
		"...and the higher index steps back to it counter-clockwise")


## AC 18 (4-6a AC 3/AC 6, unchanged): horizontal-only by magnitude, strict toward the no-op. Plus the
## two degenerate inputs: nothing to cycle to, and no valid current target.
func test_vertical_diagonal_lone_and_anchorless_flicks_are_no_ops() -> void:
	var bearings := _bearings_of([Vector2(0.0, -1.0), Vector2(1.0, 0.0)])
	assert_eq(LockOnResolver.cycle_candidate(Vector2(0.0, -1.0), bearings, 0), -1, "a purely UP flick")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(0.0, 1.0), bearings, 0), -1, "a purely DOWN flick")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 1.0), bearings, 0), -1,
		"an exact diagonal is |x| == |y|: the no-op")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 0.9), bearings, 0), 1,
		"a hair past 45 degrees IS horizontal")
	assert_eq(LockOnResolver.cycle_candidate(Vector2.ZERO, bearings, 0), -1, "a zero flick")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 0.0), _bearings_of([Vector2(0.0, -1.0)]), 0),
		-1, "the current target alone: its own successor is itself, and that is not a retarget")
	assert_eq(LockOnResolver.cycle_candidate(Vector2(1.0, 0.0), bearings, -1), -1,
		"no current target in the circle (unspawned or co-located): no anchor, no pick")


# ---------------------------------------------------------------- AC 10: the flick EDGE

## The flick is an EDGE: the stick must CROSS the authored threshold. A held deflection retargets
## ONCE, which is the same one-press-one-action rule attack and roll get from `_prev_held`.
func test_the_flick_edge_fires_once_per_crossing() -> void:
	var threshold := 0.7
	var pushed := Vector2(0.0, -1.0)
	assert_eq(GamepadController.resolve_flick(pushed, 0.0, threshold, false), Vector2(0.0, -1.0),
		"crossing the threshold from rest fires, as a unit SCREEN-space direction")
	assert_eq(GamepadController.resolve_flick(pushed, 1.0, threshold, false), Vector2.ZERO,
		"...and holding it there does NOT fire again")
	assert_eq(GamepadController.resolve_flick(Vector2(0.0, -0.5), 0.0, threshold, false),
		Vector2.ZERO, "a deflection below the threshold is not a flick")
	assert_eq(GamepadController.resolve_flick(pushed, 0.69, threshold, false), Vector2(0.0, -1.0),
		"...and one that was just below last tick fires the moment it crosses")


## AC 9 beats AC 10: pressing R3 deflects the stick with the same thumb, so a click suppresses the
## flick it would otherwise have produced.
func test_a_lock_click_suppresses_the_flick_it_would_have_produced() -> void:
	assert_eq(GamepadController.resolve_flick(Vector2(1.0, 0.0), 0.0, 0.7, true), Vector2.ZERO,
		"the click wins, so a re-lock never also fires a spurious retarget")


# ---------------------------------------------------------------- Source-scan fixture (5-1a AC 2b)

## Code portion of each line (everything before the first '#'), so a comment cannot false-positive.
## The `test_targeting_service.gd` helper verbatim — the idiom AC 2 half (b) names.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		var hash_idx := line.find("#")
		if hash_idx >= 0:
			line = line.substr(0, hash_idx)
		out.append(line)
	return out


## The code lines of ONE function body: everything after the line beginning with `signature`, up to
## the next line that is non-blank at indent zero (the next top-level declaration). Comment-only
## lines are already blanked by `_code_lines`, so a docstring between functions cannot end the body
## early and cannot be scanned as code.
##
## Scoped to the ONE seat deliberately: a whole-file scan for `Invariant.` would fail on the
## fifteen-plus legitimate checks elsewhere in match_state.gd, which `5-1a/R7` explicitly leaves
## alone.
func _function_body(path: String, signature: String) -> Array[String]:
	var out: Array[String] = []
	var inside := false
	for line in _code_lines(path):
		if not inside:
			inside = line.begins_with(signature)
			continue
		if line.strip_edges() != "" and _indent_width(line) == 0:
			break
		out.append(line)
	return out


func _indent_width(line: String) -> int:
	var n := 0
	while n < line.length() and (line[n] == "\t" or line[n] == " "):
		n += 1
	return n
