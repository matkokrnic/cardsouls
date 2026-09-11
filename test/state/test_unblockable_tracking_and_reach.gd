extends TestCase

## Story 6-1c: mode (2) TRACKING, COMMIT, LAUNCH and HONEST REACH -- the headless half.
##
## WHAT THIS FILE PINS, AC by AC:
##   AC 1  -- while the chargeup runs, facing tracks the ENEMY HERO through the charge-reach fact
##            even when this slot is LOCKED ONTO A MINION (the override, not the lock).
##   AC 2  -- the instant the chargeup window closes the attack is COMMITTED: facing stops re-reading
##            the aim and holds, no release feints, no move input steers.
##   AC 3  -- a defender who leaves the frozen line after the commit is MISSED; one who enters it
##            after the commit is HIT. The freeze is on direction, not on a defender.
##   AC 4  -- the launch carries the attacker along the frozen line at a per-colour FIXED distance.
##   AC 5  -- the arc comparison is STATE policy against the frozen direction, per colour.
##   AC 6  -- the colour-counter and dodge rungs still answer through the ONE landing seat.
##   AC 9  -- the launch progress the runner pushes keys off the LANDING edge: strictly below 1.0 on
##            every tick the hero is still charging, exactly 1.0 on the landing tick, never frozen.
##
## FIXTURE SHAPE. The chargeup is 24 ticks, and each colour's launch span is DISTINCT (RED 6, BLUE 9,
## GREEN 12) and so is its travel distance, so a colour lookup that returned the wrong colour's value
## lands on a wrong number rather than a coincidentally right one. The arcs are in-test literals
## chosen to straddle the directions each test pushes -- they are NOT the authored feel knobs, which
## no test reads (BC/R3; the story's Live Smoke note: operator tuning never requires a suite run).
##
## ONE COLOUR PER MATCH. `_make_match(color)` injects every deck card as that colour, so the dealt
## hand's colour is a property of the fixture rather than of the seeded shuffle.
##
## THE REACH FACT IS PUSHED BY HAND through the real `push_contact` seam before `advance()`, exactly
## as `5-2`'s fixture does -- these tests drive no runner, and the direction each push carries is the
## geometry under test.

const SEED := 6163
const DECK_SIZE := 8
const HAND_SIZE := 4
const MAX_HP := 100.0
const MAX_STAMINA := 40.0
const UNBLOCKABLE_COST := 20.0
const CHARGEUP_TICKS := 24
const REGEN_DELAY_TICKS := 12
const DRAW_DELAY_TICKS := 30
const UNBLOCKABLE_DAMAGE := 10.0   # 10 % of 100.0 max hp
const REACH := 8.0

const LAUNCH_TICKS := {
	Enums.CardColor.RED: 6,
	Enums.CardColor.BLUE: 9,
	Enums.CardColor.GREEN: 12,
}
const LAUNCH_DISTANCE := {
	Enums.CardColor.RED: 1.2,
	Enums.CardColor.BLUE: 1.8,
	Enums.CardColor.GREEN: 3.0,
}
const ARC_DEGREES := {
	Enums.CardColor.RED: 120.0,
	Enums.CardColor.BLUE: 40.0,
	Enums.CardColor.GREEN: 360.0,
}

## The planar TARGET -> ATTACKER direction for a defender straight "north" of the attacker (the
## 1-8 convention), and the facing it must produce: its negation.
const DIR_AHEAD := Vector2(0.0, 1.0)
## A defender straight to the attacker's side of the committed line: 90 degrees off it.
const DIR_SIDE := Vector2(1.0, 0.0)
## The lock direction of the minion the attacker is locked onto -- pointing somewhere the enemy hero
## is NOT, so a facing that followed the lock is distinguishable from one that followed the aim.
const MINION_DIR := Vector2(-0.6, 0.8)
const UNIT_MAX_HP := 30.0


# --- AC 1: tracking OVERRIDES a minion lock (6-1c/R1) -----------------------------------------

## The regression pin 6-1c/R1 requires: the hero-to-hero case alone cannot tell the override from
## the lock (both point at the enemy hero), so this hero is LOCKED ONTO A MINION, its pushed lock
## direction points at that minion, and the enemy hero MOVES around it every tick of the chargeup.
## Facing must follow the enemy hero on every tick and never the lock -- while the lock itself stays
## on the minion, because auto-aim overrides where the hero FACES, not what it has locked.
func test_charging_facing_tracks_the_enemy_hero_every_tick_over_a_minion_lock() -> void:
	var ms := _make_match(Enums.CardColor.RED)
	ms.p2.units.add(UNIT_MAX_HP, 0)
	_advance(ms, _retarget_intent(1, 0), InputIntent.new())
	assert_eq([ms.p1.lock_target_slot, ms.p1.lock_target_index], [1, 0],
		"sanity: P1 is locked onto P2's MINION, not onto the enemy hero")
	ms.set_lock_direction(0, MINION_DIR)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: charging")
	for t in CHARGEUP_TICKS - 1:
		var aim := DIR_AHEAD.rotated(0.05 * float(t + 1))
		ms.set_lock_direction(0, MINION_DIR)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, aim)
		_advance(ms, _holding(), InputIntent.new())
		assert_true(ms.p1.hero.facing.is_equal_approx(-aim),
			"tick %d: facing tracks the ENEMY HERO's live heading %s, got %s" % [t, -aim,
				ms.p1.hero.facing])
		assert_false(ms.p1.hero.facing.is_equal_approx(MINION_DIR),
			"tick %d: facing is NOT the minion lock direction -- the override wins" % t)
	assert_eq([ms.p1.lock_target_slot, ms.p1.lock_target_index], [1, 0],
		"the LOCK itself is untouched by the chargeup -- still on the minion")


# --- AC 2: the commit freeze ------------------------------------------------------------------

## AC 2: facing is captured at the charge -> launch transition and held for the whole launch, while
## the enemy hero keeps moving and the minion lock keeps pushing. Asserted on EVERY launch tick.
func test_facing_freezes_at_the_commit_and_ignores_every_later_aim() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_AHEAD)
	assert_eq(ms.p1.hero.facing, -DIR_AHEAD, "sanity: tracked the enemy hero up to the commit")
	for t in _launch(Enums.CardColor.BLUE) - 1:
		ms.set_lock_direction(0, MINION_DIR)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		_advance(ms, _holding(), InputIntent.new())
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
			"launch tick %d: still in the attack" % t)
		assert_eq(ms.p1.hero.facing, -DIR_AHEAD,
			"launch tick %d: facing HELD at the committed direction, not re-aimed" % t)


## AC 2: "no further re-aim or steering from any input". A release of the cast confirm AFTER the
## commit is not a feint -- the attack still lands on the authored tick -- and full move input does
## not bend the launch velocity off the frozen line.
##
## Code review 6-1c: the velocity is compared against the FROZEN-LINE vector the launch must carry
## (the colour's authored distance over its authored span, along the committed facing), not against
## a capture taken under the same constant move input -- a steered launch would equal such a capture
## on every tick and pass.
func test_after_the_commit_a_release_does_not_feint_and_input_does_not_steer() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge(ms, DIR_AHEAD)
	var span_seconds := float(_launch(Enums.CardColor.GREEN)) / TimingWindow.TICK_HZ
	var speed := float(LAUNCH_DISTANCE[Enums.CardColor.GREEN]) / span_seconds
	var committed_velocity := Vector3(-DIR_AHEAD.x, 0.0, -DIR_AHEAD.y) * speed
	for t in _launch(Enums.CardColor.GREEN) - 1:
		var released := InputIntent.new()
		released.move_dir = Vector2(1.0, 0.0)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, released, InputIntent.new())
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
			"launch tick %d: a RELEASE after the commit does not feint" % t)
		assert_true(ms.p1.hero.velocity.is_equal_approx(committed_velocity),
			"launch tick %d: move input does not steer the launch -- velocity %s, want the frozen line %s"
				% [t, ms.p1.hero.velocity, committed_velocity])
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"the released attack still LANDS on the authored landing tick")


## AC 2 boundary, the other side (code review 6-1c): a release ON the commit tick itself -- the tick
## step 2 closes the chargeup window -- is already ignored. `_cast_and_charge` holds through that
## tick and the test above releases only from the tick after it, so without this the sharpest edge
## of the `charge_window.is_running` conjunct in the CHARGING arm was unpinned.
func test_a_release_on_the_commit_tick_itself_is_ignored() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_true(ms.p1.charge_window.is_running, "sanity: one chargeup tick still to run")
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_false(ms.p1.charge_window.is_running, "sanity: this tick closed the chargeup (the commit)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"a release on the commit tick is ignored -- the attack is already committed")
	assert_true(ms.p1.landing_window.is_running, "...and the launch runs on")
	for _t in _launch(Enums.CardColor.BLUE):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"the attack released on its commit tick still lands on the authored landing tick")


## AC 2 boundary: a release on the LAST chargeup tick still feints (the chargeup is not yet over),
## and the feint tears the landing window down with the chargeup -- one fact, cleared together.
func test_a_release_before_the_commit_still_feints_and_clears_the_landing_window() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 2:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"a release while the chargeup still runs is a feint")
	assert_false(ms.p1.landing_window.is_running, "the feint stopped the landing window")
	assert_eq(int(ms.to_snapshot()["p1"]["landing"]), 0, "...and the snapshot rests")
	for _t in _launch(Enums.CardColor.BLUE) + 2:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "a feinted attack never lands later")


# --- AC 3: dodging after the commit whiffs; entering the line after it is hit ------------------

## AC 3, first sentence: the defender was dead ahead at the commit and has stepped to the side (still
## well inside the RADIUS -- the kind stays INSIDE) by the landing. Against the frozen direction that
## is 90 degrees off a 40-degree thrust: a MISS. The cost stays paid, like every miss.
func test_a_defender_who_leaves_the_frozen_line_after_the_commit_is_missed() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_AHEAD)
	_run_launch(ms, Enums.CardColor.BLUE, DIR_SIDE)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "the attack resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "a sidestep after the commit WHIFFS (AC 3)")


## The same sidestep BEFORE the commit is tracked: the hero re-aims, commits onto the new line, and
## lands. This is what makes the whiff above a property of the COMMIT rather than of the arc alone.
func test_the_same_sidestep_before_the_commit_is_tracked_and_hit() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_SIDE)
	_run_launch(ms, Enums.CardColor.BLUE, DIR_SIDE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"a defender who moved BEFORE the commit is simply tracked and hit")


## AC 3, second sentence: the defender was OFF the line at the commit (to the side) and steps INTO
## the frozen line during the launch. Inside it at the landing: HIT -- the freeze is on direction,
## not a lock on the defender.
func test_a_defender_who_enters_the_frozen_line_after_the_commit_is_hit() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_AHEAD)
	for _t in _launch(Enums.CardColor.BLUE) - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		_advance(ms, _holding(), InputIntent.new())
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"a defender INSIDE the frozen line at the landing is hit, wherever it was at the commit")


# --- AC 4: launch travel ----------------------------------------------------------------------

## AC 4: the launch is a velocity along the FROZEN direction at the colour's authored distance over
## its authored span -- on exactly the launch ticks, never on a chargeup tick, never on the landing
## tick -- and the per-tick displacement sums to the authored distance. Per colour, so each colour's
## own pair is read (the three fixtures differ in both numbers).
func test_the_launch_travels_the_colours_fixed_distance_along_the_frozen_line() -> void:
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		var ms := _make_match(color)
		_cast_and_charge(ms, DIR_AHEAD)
		var travelled := Vector3.ZERO
		var moving_ticks := 0
		# The commit tick itself is the first launch tick: `_cast_and_charge` stops ON it.
		travelled += ms.p1.hero.velocity / TimingWindow.TICK_HZ
		moving_ticks += 1 if not ms.p1.hero.velocity.is_zero_approx() else 0
		for _t in _launch(color) - 1:
			# The enemy hero is somewhere else entirely: travel does not ADAPT to it.
			_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
			_advance(ms, _holding(), InputIntent.new())
			travelled += ms.p1.hero.velocity / TimingWindow.TICK_HZ
			moving_ticks += 1 if not ms.p1.hero.velocity.is_zero_approx() else 0
		assert_eq(moving_ticks, _launch(color),
			"colour %d: the hero moves on exactly its %d launch ticks" % [color, _launch(color)])
		var want := Vector3(-DIR_AHEAD.x, 0.0, -DIR_AHEAD.y) * float(LAUNCH_DISTANCE[color])
		assert_true(travelled.is_equal_approx(want),
			"colour %d: travelled %s along the frozen line, want %s" % [color, travelled, want])
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "landed")
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO,
			"colour %d: no launch velocity survives the landing tick" % color)


## AC 4 / `5-2/R5`: the CHARGEUP is still hard-rooted -- the launch velocity starts at the commit
## and not one tick earlier.
func test_the_chargeup_stays_hard_rooted_up_to_the_commit() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for t in CHARGEUP_TICKS - 1:
		var moving := _holding()
		moving.move_dir = Vector2(1.0, 0.0)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, moving, InputIntent.new())
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO, "chargeup tick %d: rooted" % t)
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, _holding(), InputIntent.new())
	assert_false(ms.p1.hero.velocity.is_zero_approx(), "the commit tick is the first launch tick")


# --- AC 5: per-colour arc, state policy against the frozen direction ---------------------------

## AC 5: each colour's arc is judged against the frozen committed direction, in state. Directions
## just inside and just outside each colour's in-test half-arc; GREEN (radial) is hit from straight
## BEHIND. The kind is INSIDE in every case, so only the arc decides.
func test_each_colour_judges_its_own_arc_against_the_committed_direction() -> void:
	var cases := [
		[Enums.CardColor.RED, 55.0, true], [Enums.CardColor.RED, 65.0, false],
		[Enums.CardColor.BLUE, 15.0, true], [Enums.CardColor.BLUE, 25.0, false],
		[Enums.CardColor.GREEN, 180.0, true],
	]
	for case: Array in cases:
		var ms := _make_match(case[0])
		_cast_and_charge(ms, DIR_AHEAD)
		var off := DIR_AHEAD.rotated(deg_to_rad(case[1]))
		_run_launch(ms, case[0], off)
		var want := MAX_HP - UNBLOCKABLE_DAMAGE if case[2] else MAX_HP
		assert_eq(ms.p2.hero.get_hp(), want,
			"colour %d, defender %.0f deg off the committed line: %s"
				% [case[0], case[1], "HIT" if case[2] else "MISS"])


## AC 5: the RADIUS is still the runner's KIND. An OUTSIDE landing never lands, even dead ahead on a
## radial colour -- the arc can only NARROW what the radius admits, never widen it.
func test_the_arc_never_widens_an_outside_kind() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge(ms, DIR_AHEAD)
	for _t in _launch(Enums.CardColor.GREEN):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "OUTSIDE the radius is a miss, arc or no arc")


# --- AC 6: the single seat --------------------------------------------------------------------

## AC 6: a colour-matched defense still NEGATES through the same seat after a launch (the attacker
## is stunned, the defender unhurt) -- and a defender OUTSIDE the arc is simply missed, with its
## defense window left RUNNING (not consumed): the arc gates the whole ladder, it does not bypass it.
func test_the_colour_counter_still_answers_through_the_one_landing_seat() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_AHEAD)
	ms.p2.defense_window.start(100)
	ms.p2.defense_color = Enums.CardColor.BLUE
	_run_launch(ms, Enums.CardColor.BLUE, DIR_AHEAD)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "negated: no damage")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "the attacker is stunned")
	assert_false(ms.p2.defense_window.is_running, "the answering window was consumed")

	var missed := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(missed, DIR_AHEAD)
	missed.p2.defense_window.start(100)
	missed.p2.defense_color = Enums.CardColor.BLUE
	_run_launch(missed, Enums.CardColor.BLUE, DIR_SIDE)
	assert_eq(missed.p1.hero.action_state, HeroState.ActionState.IDLE, "a whiff is not a counter")
	assert_true(missed.p2.defense_window.is_running,
		"a whiffed attack never reached the ladder, so the defense window is NOT consumed")


# --- AC 9: the launch progress channel keys off the landing edge -------------------------------

## AC 9 / AC 11 / Fact 7. The runner pushes charge progress only while `action_state == CHARGING`,
## computed by `AnimationController.charge_attack_progress` from the landing window. Driven here
## through the REAL state tick with that exact gate: on every tick the hero is still charging the
## progress is STRICTLY below 1.0 and STRICTLY rising (the launch never freezes on a pose); the
## commit tick sits at C / (C + L); and the tick the hero leaves CHARGING is exactly the landing tick,
## on which the landing window reads 0 remaining -- i.e. the progress the SAME formula gives there is
## exactly 1.0, and the damage lands on that tick and not one earlier.
func test_launch_progress_is_below_one_until_the_landing_tick_and_one_exactly_on_it() -> void:
	var color := Enums.CardColor.BLUE
	var ms := _make_match(color)
	var c := ms.balance_ticks.unblockable_chargeup_ticks
	var l := ms.balance_ticks.unblockable_launch_ticks_for(color)
	assert_eq([c, l], [CHARGEUP_TICKS, _launch(color)], "sanity: the tick domain carries both spans")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var previous := _pushed_progress(ms, c, l)
	assert_eq(previous, 0.0, "the cast tick pushes progress 0.0")
	var landing_tick := -1
	for t in range(1, c + l + 3):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
		if ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			landing_tick = t
			break
		var progress := _pushed_progress(ms, c, l)
		assert_true(progress < 1.0, "tick %d: still charging, progress %.4f < 1.0" % [t, progress])
		assert_true(progress > previous, "tick %d: progress rises (%.4f > %.4f) -- never frozen"
			% [t, progress, previous])
		assert_eq(ms.p2.hero.get_hp(), MAX_HP, "tick %d: no damage before the landing tick" % t)
		if t == c:
			assert_true(is_equal_approx(progress, float(c) / float(c + l)),
				"the COMMIT tick sits at C / (C + L), got %.4f" % progress)
		previous = progress
	assert_eq(landing_tick, c + l, "the hero leaves CHARGING on exactly cast + C + L")
	assert_eq(ms.p1.landing_window.remaining_ticks(), 0, "the landing window has closed")
	assert_eq(AnimationController.charge_attack_progress(0, c, l), 1.0,
		"...so the formula's value on the landing tick is exactly 1.0 -- the strike frame")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "and the damage lands ON that tick")


## AC 9 with NO launch span (the pre-6-1c shape): the landing tick is the chargeup-close tick, so
## the 6-1b/R6 contract is re-verified unchanged -- the hero leaves CHARGING on exactly cast + C.
func test_with_a_zero_launch_the_landing_is_the_chargeup_close_edge_as_before() -> void:
	var ms := _make_match(Enums.CardColor.BLUE, false)
	assert_eq(ms.balance_ticks.unblockable_launch_ticks_for(Enums.CardColor.BLUE), 0, "sanity")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for t in CHARGEUP_TICKS - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "tick %d" % t)
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "lands on the chargeup close")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "...and hits")


# --- snapshot and teardown --------------------------------------------------------------------

## The landing window is hashed: `landing` counts the ticks to the landing from the cast (C + L) and
## rests at 0 afterwards.
func test_the_landing_key_counts_down_to_the_landing_and_rests() -> void:
	var ms := _make_match(Enums.CardColor.RED)
	assert_eq(int(ms.to_snapshot()["p1"]["landing"]), 0, "resting value before any cast")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(int(ms.to_snapshot()["p1"]["landing"]), CHARGEUP_TICKS + _launch(Enums.CardColor.RED),
		"the cast tick reads C + L")
	_cast_rest(ms, Enums.CardColor.RED)
	assert_eq(int(ms.to_snapshot()["p1"]["landing"]), 0, "rests after the landing")


## A debug reset mid-launch clears the landing window with the rest of the chargeup fact, so a
## launch frozen by a round-over can never land inside the next round (the 5-3 reset contract).
func test_a_debug_reset_mid_launch_clears_the_landing_window() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge(ms, DIR_AHEAD)
	assert_true(ms.p1.landing_window.is_running, "sanity: mid-launch")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "the reset clears the attack")
	assert_false(ms.p1.landing_window.is_running, "...and stops its landing window")
	for _t in _launch(Enums.CardColor.GREEN) + 2:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "nothing lands after the reset")


## AC 7: a hero killed MID-LAUNCH in natural play takes the ROUND-OVER freeze (step 1b, `2-6/R6`),
## unchanged: death is set at step 8 together with `_round_over`, so from the next tick step 1b zeroes
## velocity, skips the facing write and returns before step 3 -- the launch never lands.
##
## Code review 6-1c: this test was named for the DEAD carve-out, but on this path the DEAD branch of
## `_resolve_movement` is never reached (step 1b returns first); removing that branch left it green.
## Renamed to what it pins, and the landing assertion now runs past the authored landing tick -- it
## used to check the HP two ticks into a twelve-tick launch, before any landing was possible. The
## DEAD rung itself is pinned mid-launch by the forced-DEAD test below.
func test_a_hero_killed_mid_launch_takes_the_round_over_freeze() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge(ms, DIR_AHEAD)
	ms.p1.hero.take_damage(MAX_HP)
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
	_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.DEAD, "died mid-launch")
	assert_true(bool(ms.to_snapshot()["round_over"]), "sanity: natural death latches the round over")
	var facing := ms.p1.hero.facing
	for _t in _launch(Enums.CardColor.GREEN) + 2:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		_advance(ms, _holding(), InputIntent.new())
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO, "a corpse does not keep launching")
		assert_eq(ms.p1.hero.facing, facing, "a corpse's facing holds")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "and the dead hero's launch never lands")


## AC 7: the DEAD carve-out (`2-3/R14`) itself, mid-launch, by the codebase's forced-DEAD idiom
## (`set_action_state(DEAD)` with `_round_over` left FALSE) -- the only way to reach that branch,
## since natural death always latches the round over first. The DEAD return at the top of
## `_resolve_movement` must win over the new CHARGING launch branch: velocity zero, facing held even
## while the lock keeps pushing a direction, and no landing past the authored landing tick.
func test_a_forced_dead_hero_mid_launch_takes_the_dead_carve_out() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge(ms, DIR_AHEAD)
	var facing := ms.p1.hero.facing
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)
	for _t in _launch(Enums.CardColor.GREEN) + 2:
		ms.set_lock_direction(0, MINION_DIR)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		var moving := _holding()
		moving.move_dir = Vector2(1.0, 0.0)
		_advance(ms, moving, InputIntent.new())
		assert_false(bool(ms.to_snapshot()["round_over"]), "sanity: the forced idiom keeps the round live")
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO, "a DEAD hero does not keep launching")
		assert_eq(ms.p1.hero.facing, facing, "a DEAD hero's facing holds, lock or no lock")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "and the DEAD hero's launch never lands")


# --- helpers ----------------------------------------------------------------------------------

func _launch(color: int) -> int:
	return int(LAUNCH_TICKS[color])


## What the runner's `_push_charge_progress` would push for slot 0 at the end of this tick, gate
## included: nothing (-1.0 here) unless the hero is CHARGING.
func _pushed_progress(ms: MatchState, c: int, l: int) -> float:
	if ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
		return -1.0
	return AnimationController.charge_attack_progress(ms.p1.landing_window.remaining_ticks(), c, l)


## Cast on slot 0 and run the chargeup out to (and including) the COMMIT tick, pushing `aim` on every
## tick. On return the chargeup window has just closed and the hero is committed: this call's last
## tick is the first launch tick.
func _cast_and_charge(ms: MatchState, aim: Vector2) -> void:
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, aim)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: committed, not landed")
	assert_false(ms.p1.charge_window.is_running, "sanity: the chargeup window has closed")


## Run the rest of the launch (after `_cast_and_charge`) through the landing tick, pushing INSIDE with
## the defender's direction `defender` on every tick.
func _run_launch(ms: MatchState, color: int, defender: Vector2) -> void:
	for _t in _launch(color):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, defender)
		_advance(ms, _holding(), InputIntent.new())


## Cast and run an attack all the way out, dead ahead.
func _cast_rest(ms: MatchState, color: int) -> void:
	for _t in CHARGEUP_TICKS + _launch(color):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("tr_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = 3.0
		out[id] = c
	return out


func _colors(color: int) -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id in _deck_contents():
		out[id] = color as Enums.CardColor
	return out


func _config(with_launch: bool) -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = 90.0
	c.max_stamina = MAX_STAMINA
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.stamina_regen_per_second = 6.0
	c.stamina_regen_delay_seconds = float(REGEN_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.roll_stamina_cost = 5.0
	c.attack_stamina_cost = 5.0
	c.deflect_stamina_cost = 5.0
	c.attack_windup_seconds = 0.5
	c.attack_active_seconds = 0.1
	c.attack_recovery_seconds = 0.2
	c.roll_duration_seconds = 0.5
	c.roll_iframe_seconds = 0.2
	c.roll_distance = 3.0
	c.deflect_window_seconds = 0.1
	c.color_counter_stun_seconds = 1.0
	c.draw_replacement_delay_seconds = float(DRAW_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = 10.0
	c.unblockable_arc_degrees_red = ARC_DEGREES[Enums.CardColor.RED]
	c.unblockable_arc_degrees_blue = ARC_DEGREES[Enums.CardColor.BLUE]
	c.unblockable_arc_degrees_green = ARC_DEGREES[Enums.CardColor.GREEN]
	if with_launch:
		c.unblockable_launch_seconds_red = float(_launch(Enums.CardColor.RED)) / TimingWindow.TICK_HZ
		c.unblockable_launch_seconds_blue = float(_launch(Enums.CardColor.BLUE)) / TimingWindow.TICK_HZ
		c.unblockable_launch_seconds_green = float(_launch(Enums.CardColor.GREEN)) / TimingWindow.TICK_HZ
		c.unblockable_launch_distance_red = LAUNCH_DISTANCE[Enums.CardColor.RED]
		c.unblockable_launch_distance_blue = LAUNCH_DISTANCE[Enums.CardColor.BLUE]
		c.unblockable_launch_distance_green = LAUNCH_DISTANCE[Enums.CardColor.GREEN]
	return c


func _make_match(color: int, with_launch := true) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config(with_launch))
	var f := FeatureFlags.new()
	f.unblockable = true
	ms.inject_feature_flags(f)
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors(color))
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	return ms


func _holding() -> InputIntent:
	var i := InputIntent.new()
	i.held[&"card_cast"] = true
	return i


func _unblockable_intent(slot: int) -> InputIntent:
	var i := _holding()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.UNBLOCKABLE
	i.card_commit = true
	return i


func _retarget_intent(slot: int, index: int) -> InputIntent:
	var i := InputIntent.new()
	i.retarget_slot = slot
	i.retarget_index = index
	return i


## The runner's every-tick charge-reach push, by hand and through the real seam, carrying `dir` as
## the planar TARGET -> ATTACKER direction.
func _push_reach_dir(ms: MatchState, slot: int, kind: int, dir: Vector2) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	ms.push_contact([slot, TargetingService.HERO_INDEX],
		[1 - slot, TargetingService.HERO_INDEX], player.hero.attack_index, dir, kind)


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
