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
	# Story 6-1d (AC 7): the launch speed is FRONT-LOADED now, so the vector to compare against is
	# the colour's authored travel share for THAT launch tick rather than one constant -- computed
	# from the authored distance and the tick span, never captured from the run under test.
	for t in _launch(Enums.CardColor.GREEN) - 1:
		var released := InputIntent.new()
		released.move_dir = Vector2(1.0, 0.0)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, released, InputIntent.new())
		var want := _launch_velocity(Enums.CardColor.GREEN, t + 1, DIR_AHEAD)
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
			"launch tick %d: a RELEASE after the commit does not feint" % t)
		assert_true(ms.p1.hero.velocity.is_equal_approx(want),
			"launch tick %d: move input does not steer the launch -- velocity %s, want the frozen line %s"
				% [t, ms.p1.hero.velocity, want])
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
##
## STORY 6-1d (`6-1d/R13`, R3-superseded fixture): the chargeup and the COMMIT tick now push OUTSIDE,
## and INSIDE only from the sidestep onward. The old fixture reported an INSIDE contact
## dead ahead on the commit tick, which R3 made a real in-arc touch -- and R13 makes an in-arc touch
## absorbing, so that fixture would test a hit. The claim is unchanged and not weakened: with the ONLY
## contact off the line, the authored arc decides.
func test_a_defender_who_leaves_the_frozen_line_after_the_commit_is_missed() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
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
##
## STORY 6-1d (`6-1d/R13`, R3-superseded fixture): the chargeup and the COMMIT tick now push OUTSIDE;
## the launch then pushes INSIDE, but already at the case's off angle -- there is no sidestep here,
## every launch push lands on the same line. The old fixture reported an INSIDE contact dead ahead
## on the commit tick, which R3 made a real in-arc touch -- and R13 makes an in-arc touch absorbing,
## so that fixture would test a hit. The claim is unchanged and not weakened: with the ONLY
## contact off the line, the authored arc decides.
func test_each_colour_judges_its_own_arc_against_the_committed_direction() -> void:
	var cases := [
		[Enums.CardColor.RED, 55.0, true], [Enums.CardColor.RED, 65.0, false],
		[Enums.CardColor.BLUE, 15.0, true], [Enums.CardColor.BLUE, 25.0, false],
		[Enums.CardColor.GREEN, 180.0, true],
	]
	for case: Array in cases:
		var ms := _make_match(case[0])
		_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
		var off := DIR_AHEAD.rotated(deg_to_rad(case[1]))
		_run_launch(ms, case[0], off)
		var want := MAX_HP - UNBLOCKABLE_DAMAGE if case[2] else MAX_HP
		assert_eq(ms.p2.hero.get_hp(), want,
			"colour %d, defender %.0f deg off the committed line: %s"
				% [case[0], case[1], "HIT" if case[2] else "MISS"])


## AC 5: the CONTACT VERDICT is still the runner's KIND. An OUTSIDE landing never lands, even dead
## ahead on a radial colour -- the arc can only NARROW what the geometry admits, never widen it.
##
## STORY 6-1d: the fixture now pushes OUTSIDE from the COMMIT TICK on, not only across the launch.
## Before 6-1d only the landing tick's kind was read, so the commit tick's push was free; contact is
## latched across the whole committed flight now, so an attack that must touch NOTHING has to say so
## on every evaluated tick. The claim under test is unchanged and is not weakened: no touch, no hit,
## whatever the arc says.
func test_the_arc_never_widens_an_outside_kind() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	for _t in _launch(Enums.CardColor.GREEN):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "OUTSIDE the radius is a miss, arc or no arc")


# --- AC 6: the single seat --------------------------------------------------------------------

## AC 6: a colour-matched defense still NEGATES through the same seat after a launch (the attacker
## is stunned, the defender unhurt) -- and a defender OUTSIDE the arc is simply missed, with its
## defense window left RUNNING (not consumed): the arc gates the whole ladder, it does not bypass it.
##
## STORY 6-1d (`6-1d/R13`, R3-superseded fixture): the chargeup and the COMMIT tick now push OUTSIDE,
## and INSIDE only from the sidestep onward (the `missed` half). The old fixture reported an INSIDE contact
## dead ahead on the commit tick, which R3 made a real in-arc touch -- and R13 makes an in-arc touch
## absorbing, so that fixture would test a hit. The claim is unchanged and not weakened: with the ONLY
## contact off the line, the authored arc decides.
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
	_cast_and_charge_kind(missed, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
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


# --- STORY 6-1d: continuous contact, the committed window, and the front-loaded launch ---------

## Story 6-1d AC 6, the SUPERSESSION of `6-1c` AC 3, stated as the behaviour change it is: the
## defender is touched on the FIRST launch tick and has cleared the blade by the landing tick. Before
## 6-1d only the landing tick's answer was read, so this was a guaranteed miss; contact is latched
## across the whole committed flight now, so it is a HIT.
##
## GREEN, whose authored-in-test arc is radial (360), so the ARC cannot be what decides -- only the
## contact verdict can. The chargeup and the commit tick push OUTSIDE, so nothing pre-commit and
## nothing at the commit contributes: the ONLY touch in the whole attack is that one launch tick.
func test_a_defender_touched_on_one_launch_tick_is_hit_even_after_it_clears_the_blade() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	for t in _launch(Enums.CardColor.GREEN):
		var kind := MatchState.CONTACT_CHARGE_REACH_INSIDE if t == 0 \
				else MatchState.CONTACT_CHARGE_REACH_OUTSIDE
		_push_reach_dir(ms, 0, kind, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"touched on ONE committed tick and clear at the landing: a HIT (AC 6 supersedes 6-1c AC 3)")


## Story 6-1d AC 6, the SURVIVING half of `6-1c`'s guarantee, and the pair that stops the test above
## from passing against an implementation that simply always lands: clear the blade's path on EVERY
## evaluated tick and it is still a MISS. Same colour, same radial arc, same fixture -- the single
## difference is that no tick reports a touch.
func test_a_defender_clear_on_every_evaluated_tick_is_still_missed() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	for _t in _launch(Enums.CardColor.GREEN):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"clear on every evaluated tick is still a MISS -- 'checked every tick' is not 'always hits'")


## Story 6-1d AC 4: THE CONTACT WINDOW OPENS AT THE COMMIT AND NEVER EARLIER. The defender is in
## contact for the ENTIRE feintable chargeup -- every tick but the last -- and clear from the commit
## tick onwards. An attack the attacker could still have cancelled credits nothing, so this is a MISS.
##
## MUTATION: delete the `is_contact_window_open()` clearing arm in `MatchState.push_contact` (leaving
## `INSIDE` unconditionally absorbing) and this test goes RED -- the chargeup's touches would latch
## and the attack would land.
func test_contact_during_the_feintable_chargeup_credits_nothing() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_true(ms.p1.charge_window.is_running, "sanity: still feintable, the commit is next tick")
	for _t in _launch(Enums.CardColor.GREEN) + 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"a blade already in motion during the FEINTABLE chargeup credits nothing (AC 4)")


## Story 6-1d AC 4/AC 5, the store's REAPING, proven directly rather than by consequence (the `6-1d`
## N4 hazard: a landing record that is opened and never erased). There is no record to erase -- the
## verdict is one int per slot, and every pre-commit push CLEARS it -- so the property to prove is
## that it rests at `REACH_UNKNOWN` outside a committed flight, whatever happened before.
##
## Three readings: while touches arrive throughout the FEINTABLE chargeup (nothing is credited and
## nothing accumulates), after a FEINT -- the path that resolves no landing at all, so the one most
## likely to leak a record -- and after a LANDED attack, where a single further push with no attack
## in flight puts the store back at rest.
func test_the_contact_verdict_rests_at_unknown_outside_a_committed_flight() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	# Two short of the chargeup's close, so the release below lands on the LAST FEINTABLE tick: a
	# release on the commit tick itself is ignored (`6-1c` AC 2), which would make this no feint.
	for t in CHARGEUP_TICKS - 2:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
		assert_eq(ms._charge_reach[0], MatchState.REACH_UNKNOWN,
			"chargeup tick %d: touches arrive but nothing is credited yet" % t)
	# The feint: release while the chargeup still runs. No landing resolves at all, and the one
	# committed-window push this attack ever got (the commit tick's) is all the store can hold.
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: feinted")
	assert_false(ms.p1.landing_window.is_running, "sanity: the feint tore the landing window down")
	# ...and the very next push with nothing in flight puts it back at rest. There is no record to
	# erase and no counter to reap: the clearing arm runs on every push outside a committed flight.
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms._charge_reach[0], MatchState.REACH_UNKNOWN,
		"a feinted attack leaves nothing behind that a later push does not clear")
	# The same, after a LANDED attack rather than a feinted one. Idle first: the feinted cast's
	# stamina stays spent (`E5-P/R4`), so the pool has to regenerate before a second one is affordable.
	for _t in 200:
		_advance(ms, InputIntent.new(), InputIntent.new())
	_cast_and_charge(ms, DIR_AHEAD)
	_run_launch(ms, Enums.CardColor.GREEN, DIR_AHEAD)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "sanity: the second attack landed")
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms._charge_reach[0], MatchState.REACH_UNKNOWN,
		"a landed flight's verdict does not survive it either")


## Story 6-1d AC 5: EXACTLY ONE RESOLUTION PER SWING. Every committed tick reports contact, and the
## attack still resolves once -- one `hit_landed`, one damage instalment, one orb grant.
func test_contact_on_every_committed_tick_still_resolves_exactly_once() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	var landed: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, _hp: float) -> void: landed.append([a, t, d]))
	_cast_and_charge(ms, DIR_AHEAD)
	_run_launch(ms, Enums.CardColor.GREEN, DIR_AHEAD)
	assert_eq(landed.size(), 1,
		"%d committed ticks of contact resolve exactly ONE landing, got %d"
			% [_launch(Enums.CardColor.GREEN) + 1, landed.size()])
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "...and exactly one damage instalment")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "...through the one exit")


## Story 6-1d AC 7: the launch travel is FRONT-LOADED -- strictly more distance covered on each tick
## than on the next -- while the TOTAL stays the colour's authored distance exactly. Both halves
## matter: the ramp alone could be delivered by a launch that travels further overall (a stealth
## reach buff, which AC 2 forbids), and the total alone is what `6-1c` already shipped.
func test_the_launch_travel_is_front_loaded_and_still_sums_to_the_authored_distance() -> void:
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		var ms := _make_match(color)
		_cast_and_charge(ms, DIR_AHEAD)
		var steps: Array[float] = [ms.p1.hero.velocity.length() / TimingWindow.TICK_HZ]
		var travelled := ms.p1.hero.velocity / TimingWindow.TICK_HZ
		for _t in _launch(color) - 1:
			_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
			_advance(ms, _holding(), InputIntent.new())
			steps.append(ms.p1.hero.velocity.length() / TimingWindow.TICK_HZ)
			travelled += ms.p1.hero.velocity / TimingWindow.TICK_HZ
		for i in steps.size() - 1:
			assert_true(steps[i] > steps[i + 1],
				"colour %d: launch tick %d covered %.5f, tick %d covered %.5f -- the profile must "
					% [color, i, steps[i], i + 1, steps[i + 1]] + "fall, not flatten or rise")
		var flat := float(LAUNCH_DISTANCE[color]) / float(_launch(color))
		assert_true(steps[0] > flat,
			"colour %d: the first launch tick must cover MORE than the flat share (%.5f vs %.5f)"
				% [color, steps[0], flat])
		var want := Vector3(-DIR_AHEAD.x, 0.0, -DIR_AHEAD.y) * float(LAUNCH_DISTANCE[color])
		assert_true(travelled.is_equal_approx(want),
			"colour %d: the redistributed travel still sums to %s, got %s" % [color, want, travelled])


## Story 6-1d AC 7, P6 ADOPTED (`6-1c/R12`): the launch speed derives from the TICK span, not from
## the authored `*_seconds` float. The two agree only while the authored span is tick-aligned, so
## this fixture authors one that is NOT: 0.105 s rounds to 6 ticks (0.1 s), and a speed divided by
## 0.105 would leave the hero short of the authored distance after those 6 ticks.
##
## MUTATION: restore `unblockable_launch_seconds_for(...)` as the divisor and this goes RED at
## roughly 95 % of the distance -- which is exactly the overshoot/undershoot class P6 names.
func test_the_launch_speed_derives_from_the_tick_span_not_the_seconds_float() -> void:
	var c := _config(false)
	c.unblockable_launch_seconds_red = 0.105   # 6.3 ticks -> 6, deliberately NOT tick-aligned
	c.unblockable_launch_distance_red = 2.4
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(c)
	var f := FeatureFlags.new()
	f.unblockable = true
	ms.inject_feature_flags(f)
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors(Enums.CardColor.RED))
	var boot: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(boot)
	ms.drain_signals()
	var ticks := TimingWindow.seconds_to_ticks(0.105)
	assert_eq(ticks, 6, "sanity: the fixture's span really is off the tick grid")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	var travelled := ms.p1.hero.velocity / TimingWindow.TICK_HZ
	for _t in ticks - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
		travelled += ms.p1.hero.velocity / TimingWindow.TICK_HZ
	assert_true(absf(travelled.length() - 2.4) < 0.0001,
		"a span off the tick grid still travels the authored 2.4, got %.5f" % travelled.length())


# --- 6-1d review fix: the arc and the verdict are one measurement (`6-1d/R8`) -----------------

## `6-1d/R8`, the HIT direction. BLUE's in-test arc is 40 degrees, NARROW on purpose: GREEN's radial 360
## short-circuits the arc and cannot see which bearing it was judged against, which is exactly why the
## dev pass's AC 6 pair did not catch this. The defender is touched ONCE, 10 degrees off the frozen line
## (inside the arc), on the first launch tick after the commit, then strafes 90 degrees off it and is
## never touched again. The arc is judged against the bearing AT THE CONTACT, so this is a HIT -- AC 6's
## supersession delivered for a narrow colour too.
##
## MUTATION: point `_is_in_charge_arc` back at the every-push `_charge_reach_dirs` and this goes RED --
## the landing judges the defender's last, out-of-arc bearing and misses.
func test_a_narrow_arc_judges_the_bearing_at_contact_so_a_strafe_after_the_touch_is_hit() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	var in_arc := DIR_AHEAD.rotated(deg_to_rad(10.0))
	for t in _launch(Enums.CardColor.BLUE):
		if t == 0:
			_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, in_arc)
		else:
			_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_SIDE)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: the attack resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"touched INSIDE the 40-degree arc, then strafed out of it: judged at the contact, a HIT")


## `6-1d/R8`, the MISS direction -- the mirror the review named. The blade touches the defender while it
## is 90 degrees off the frozen line (OUTSIDE BLUE's arc), and the defender then walks INTO the arc,
## untouched, by the landing. A touch that was never inside the arc when it happened credits nothing:
## the arc can still only REMOVE a hit, and the bearing it removes it by is the contact's own.
##
## MUTATION: point `_is_in_charge_arc` back at `_charge_reach_dirs` and this goes RED -- the landing
## judges the last, in-arc bearing and lands a hit no in-arc contact ever earned.
func test_a_narrow_arc_judges_the_bearing_at_contact_so_drifting_in_after_the_touch_is_missed() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	for t in _launch(Enums.CardColor.BLUE):
		if t == 0:
			_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		else:
			_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: the attack resolved")
	assert_eq(ms._charge_reach[0], MatchState.CONTACT_CHARGE_REACH_INSIDE,
		"sanity: the contact verdict itself is INSIDE -- only the arc can refuse this one")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"touched OUTSIDE the 40-degree arc, then drifted into it untouched: a MISS")


# --- 6-1d review fix 2: an in-arc contact is absorbing (`6-1d/R13`) ---------------------------

## `6-1d/R13` (a), the case "last contact" got wrong. BLUE (in-test arc 40). The defender is touched 10
## degrees off the line on LAUNCH TICK 0 -- the commit tick itself, the first push inside the contact
## window -- and is still overlapping the blade, but 90 degrees off it, on EVERY later tick through the
## landing. One in-arc contact is enough: a HIT.
##
## The commit tick is used on purpose: its push arrives before that tick's `advance()`. The sanity
## assert on the facing pins the measured ordering the rule's comment names -- the commit tick's push
## does not re-aim the frozen line.
##
## MUTATION: always overwrite the bearing on an `INSIDE` push (the R8 behaviour) and this goes RED --
## the landing judges the last, out-of-arc touch and misses.
func test_an_in_arc_touch_on_the_commit_tick_survives_later_out_of_arc_touches() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	var in_arc := DIR_AHEAD.rotated(deg_to_rad(10.0))
	_charge_to_the_commit_tick(ms)
	for t in 1 + _launch(Enums.CardColor.BLUE):
		var dir := in_arc if t == 0 else DIR_SIDE
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, dir)
		_advance(ms, _holding(), InputIntent.new())
		if t == 0:
			assert_eq(ms.p1.hero.facing, -DIR_AHEAD, "sanity: the frozen line is the pre-commit aim")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: the attack resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"touched IN arc on the commit tick, then out of arc on every later tick: a HIT")


## `6-1d/R13` (b): ANY in-arc contact wins, not the first. The commit tick touches the defender 90
## degrees off the line (out of arc), a later launch tick touches it 10 degrees off (in arc), and every
## other tick touches it out of arc again -- so neither the first nor the last contact is in arc.
##
## MUTATION: always overwrite the bearing on an `INSIDE` push and this goes RED (the last touch is out
## of arc).
func test_any_in_arc_touch_during_the_flight_is_a_hit() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	var in_arc := DIR_AHEAD.rotated(deg_to_rad(10.0))
	_charge_to_the_commit_tick(ms)
	for t in 1 + _launch(Enums.CardColor.BLUE):
		var dir := in_arc if t == 3 else DIR_SIDE
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, dir)
		_advance(ms, _holding(), InputIntent.new())
		if t == 0:
			assert_eq(ms.p1.hero.facing, -DIR_AHEAD, "sanity: the frozen line is the pre-commit aim")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: the attack resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"out of arc first, in arc on one later tick, out of arc last: a HIT")


## `6-1d/R13` (c), the surviving half: touched on every tick from the commit through the landing, but
## ALWAYS 90 degrees off BLUE's 40-degree line. The verdict is `INSIDE` and the arc refuses it -- the
## arc can still only REMOVE a hit, and an absorbing in-arc latch never widens one.
##
## MUTATION: make every `INSIDE` flight land (skip the arc) and this goes RED.
func test_a_flight_touched_only_out_of_arc_still_misses() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_charge_to_the_commit_tick(ms)
	for _t in 1 + _launch(Enums.CardColor.BLUE):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: the attack resolved")
	assert_eq(ms._charge_reach[0], MatchState.CONTACT_CHARGE_REACH_INSIDE,
		"sanity: every tick touched -- only the arc can refuse this one")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "touched only out of arc on every tick: a MISS")


# --- 6-1d review fix: the latch's clearing is owned (`6-1d/R9`) --------------------------------

## `6-1d/R9`: the `C == 1` cross-arena free hit is dead. With a ONE-TICK chargeup the first push of an
## attack already lands inside the contact window, so no pre-commit push ever runs the clearing arm.
## Attack #1 lands with the verdict latched `INSIDE`; attack #2 is flown with the defender reported
## OUTSIDE on every evaluated tick. The stale verdict must not survive into it.
##
## MUTATION: delete the two clears at the CAST SEAT (`_resolve_unblockable_cast`) and this goes RED --
## attack #2 lands full damage off attack #1's absorbing `INSIDE`.
func test_a_one_tick_chargeup_does_not_inherit_the_previous_attacks_verdict() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	var c := _config(true)
	c.unblockable_chargeup_seconds = 1.0 / TimingWindow.TICK_HZ
	ms.apply_balance(c)
	assert_eq(ms.balance_ticks.unblockable_chargeup_ticks, 1, "sanity: a ONE-tick chargeup")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: attack #1 cast")
	for _t in 1 + _launch(Enums.CardColor.GREEN):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: attack #1 resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "sanity: attack #1 landed")
	assert_eq(ms._charge_reach[0], MatchState.CONTACT_CHARGE_REACH_INSIDE,
		"sanity: attack #1 left its verdict latched INSIDE -- the stale value under test")
	for _t in 200:
		_advance(ms, InputIntent.new(), InputIntent.new())
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: attack #2 cast")
	for _t in 1 + _launch(Enums.CardColor.GREEN):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: attack #2 resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"attack #2 measured OUTSIDE on every evaluated tick and must MISS, not inherit attack #1's hit")


## `6-1d/R9`: the verdict and its bearing are part of the chargeup's one fact, so the debug reset clears
## them beside the windows and the colour. Read directly: after a landed attack nothing else touches the
## store, so only the reset can put it back at rest.
##
## MUTATION: delete the two clears in `_reset_player` and this goes RED.
func test_the_debug_reset_clears_the_contact_verdict_and_its_bearing() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_AHEAD)
	_run_launch(ms, Enums.CardColor.BLUE, DIR_AHEAD)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "sanity: landed")
	assert_eq(ms._charge_reach[0], MatchState.CONTACT_CHARGE_REACH_INSIDE, "sanity: latched INSIDE")
	assert_eq(ms._charge_contact_dirs[0], DIR_AHEAD, "sanity: the contact bearing was latched with it")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms._charge_reach[0], MatchState.REACH_UNKNOWN, "the reset clears the verdict")
	assert_eq(ms._charge_contact_dirs[0], Vector2.ZERO, "...and the bearing latched with it")


# --- 6-1d review fix: the launch index comes from the window (`6-1d/R10`) ----------------------

## `6-1d/R10`: a balance hot-reload MID-FLIGHT that shortens this colour's launch span cannot pin the
## launch index. The running windows keep the durations they snapshotted at the cast, so the flight
## still moves on exactly its original 12 launch ticks, still front-loaded, and still sums to the
## authored distance -- AC 7's arithmetic re-proven across the reload rather than only before it.
##
## MUTATION: read the span live again (`balance_ticks.unblockable_launch_ticks_for(...)`, index
## `launch_ticks - landing_window.remaining_ticks()`) and this goes RED -- the raw index goes negative,
## the clamp pins it at the ramp's peak share and the travel runs to several times the authored distance.
func test_a_mid_flight_span_retune_cannot_pin_the_launch_index() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge(ms, DIR_AHEAD)
	var steps: Array[float] = [ms.p1.hero.velocity.length() / TimingWindow.TICK_HZ]
	var travelled := ms.p1.hero.velocity / TimingWindow.TICK_HZ
	var retuned := _config(true)
	retuned.unblockable_launch_seconds_green = 3.0 / TimingWindow.TICK_HZ
	ms.apply_balance(retuned)
	assert_eq(ms.balance_ticks.unblockable_launch_ticks_for(Enums.CardColor.GREEN), 3,
		"sanity: the reloaded span really is shorter than the running flight's 12")
	var moving_ticks := 1
	while ms.p1.hero.action_state == HeroState.ActionState.CHARGING and moving_ticks < 100:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
		if ms.p1.hero.velocity.is_zero_approx():
			continue
		moving_ticks += 1
		steps.append(ms.p1.hero.velocity.length() / TimingWindow.TICK_HZ)
		travelled += ms.p1.hero.velocity / TimingWindow.TICK_HZ
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: the flight landed")
	assert_eq(moving_ticks, _launch(Enums.CardColor.GREEN),
		"the flight moves on its ORIGINAL %d launch ticks across the reload, got %d"
			% [_launch(Enums.CardColor.GREEN), moving_ticks])
	for i in steps.size() - 1:
		assert_true(steps[i] > steps[i + 1],
			"launch tick %d covered %.5f, tick %d covered %.5f -- still front-loaded across the reload"
				% [i, steps[i], i + 1, steps[i + 1]])
	var want := Vector3(-DIR_AHEAD.x, 0.0, -DIR_AHEAD.y) * float(LAUNCH_DISTANCE[Enums.CardColor.GREEN])
	assert_true(travelled.is_equal_approx(want),
		"the reloaded flight still travels the authored %s, got %s" % [want, travelled])


# --- helpers ----------------------------------------------------------------------------------

func _launch(color: int) -> int:
	return int(LAUNCH_TICKS[color])


## Story 6-1d (AC 7): the velocity the FRONT-LOADED launch profile must produce on launch tick
## `index` (0 = the commit tick), along the frozen direction whose TARGET -> ATTACKER fact is `aim`.
## Computed from the authored distance and the TICK span rather than captured from the run under
## test, so a flattened profile fails here -- but the ramp FORMULA is the production expression
## transcribed, so a formula wrong the same way in both places would pass. The ramp's SHAPE is
## pinned independently by `test_the_launch_travel_is_front_loaded_and_still_sums_to_the_authored_
## distance` (strictly decreasing steps, a first step above the flat share, the authored total).
func _launch_velocity(color: int, index: int, aim: Vector2) -> Vector3:
	var l := _launch(color)
	var share := 2.0 - float(2 * index + 1) / float(l)
	var flat := float(LAUNCH_DISTANCE[color]) * TimingWindow.TICK_HZ / float(l)
	return Vector3(-aim.x, 0.0, -aim.y) * (flat * share)


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
	_cast_and_charge_kind(ms, aim, MatchState.CONTACT_CHARGE_REACH_INSIDE)


## `_cast_and_charge` with the pushed KIND chosen by the caller. Story 6-1d made the kind pushed on
## the COMMIT TICK load-bearing -- it is the first tick inside the contact window, so a test that
## wants an attack which never touches anything has to say so from that tick on, not only during the
## launch (`6-1d` AC 6: contact latches across the whole committed flight).
func _cast_and_charge_kind(ms: MatchState, aim: Vector2, kind: int) -> void:
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS:
		_push_reach_dir(ms, 0, kind, aim)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: committed, not landed")
	assert_false(ms.p1.charge_window.is_running, "sanity: the chargeup window has closed")


## Cast on slot 0 and run the FEINTABLE chargeup only, aiming dead ahead and touching nothing, stopping
## one tick short of the commit: the caller's next push is the commit tick's (`6-1d/R13`).
func _charge_to_the_commit_tick(ms: MatchState) -> void:
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, _holding(), InputIntent.new())
	assert_true(ms.p1.charge_window.is_running, "sanity: still feintable, the commit is the next tick")


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
