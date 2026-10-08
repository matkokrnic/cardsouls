extends TestCase

## Story 6-1c: mode (2) TRACKING, COMMIT, LAUNCH and HONEST REACH -- the headless half.
##
## WHAT THIS FILE PINS, AC by AC:
##   AC 1  -- while the chargeup runs, facing tracks the ENEMY HERO through the charge-reach fact
##            even when this slot is LOCKED ONTO A MINION (the override, not the lock).
##   AC 2  -- the instant the chargeup window closes the attack is COMMITTED: facing stops re-reading
##            the aim and holds, no move input steers. (Since `6-9` there is no release to feint
##            with either: the press commits the attack.)
##   AC 3  -- one who enters the frozen line after the commit is HIT. The freeze is on direction,
##            not on a defender. (Its MISS half -- leaving the line -- retired with the arc at story 7-8,
##            `7-8/R8`: a counted touch hits whatever the attacker's facing, AC 6.)
##   AC 4  -- the launch carries the attacker along the frozen line at a per-colour FIXED distance.
##   AC 5  -- (RETIRED at story 7-8, `7-8/R8`: there is no arc.) The surviving claim is that an
##            `OUTSIDE` fact never lands.
##   AC 6  -- the dodge rung still answers through the ONE landing seat. Story 6-6b RE-SEATED the
##            colour half: the counter is judged in the attacker's own CHARGING arm at the COMMIT
##            and on every pre-contact launch tick, never at the landing, so what this file pins
##            about it now is the two consequences AC 5 RULED rather than left to smoke.
##   AC 9  -- the launch progress the runner pushes keys off the LANDING edge: strictly below 1.0 on
##            every tick the hero is still charging, exactly 1.0 on the landing tick, never frozen.
##
## FIXTURE SHAPE. The chargeup is 24 ticks, and each colour's launch span is DISTINCT (RED 6, BLUE 9,
## GREEN 12) and so is its travel distance, so a colour lookup that returned the wrong colour's value
## lands on a wrong number rather than a coincidentally right one. No authored feel knob is read
## (BC/R3; operator tuning never requires a suite run).
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
## Story 6-6b (AC 1/AC 2), POST-SMOKE (R-S6): the counter's ONE count -- the busy span, the whole of
## which is the counter window. The eligibility span that stood beside it is retired with its field.
## DISTINCT from every count this fixture already carries ({6, 8, 9, 12, 24, 30}).
const COUNTER_BUSY_TICKS := 20

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
		_advance(ms, InputIntent.new(), InputIntent.new())
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
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
			"launch tick %d: still in the attack" % t)
		assert_eq(ms.p1.hero.facing, -DIR_AHEAD,
			"launch tick %d: facing HELD at the committed direction, not re-aimed" % t)


## AC 2: "no further re-aim or steering from any input". Full move input after the commit does not
## bend the launch velocity off the frozen line, and the attack still lands on the authored tick.
##
## Story 6-9 REFRAMED this test off the RELEASE it used to be written around. Its subject was never
## the release: it is that NO INPUT reaches the launch. The intents it drives are bare, which under
## `6-1` was a release and is now simply an ordinary tick -- the assertions are unchanged.
##
## Code review 6-1c: the velocity is compared against the FROZEN-LINE vector the launch must carry
## (the colour's authored distance over its authored span, along the committed facing), not against
## a capture taken under the same constant move input -- a steered launch would equal such a capture
## on every tick and pass.
func test_after_the_commit_no_input_steers_the_launch() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge(ms, DIR_AHEAD)
	# Story 6-1d (AC 7): the launch speed is FRONT-LOADED now, so the vector to compare against is
	# the colour's authored travel share for THAT launch tick rather than one constant -- computed
	# from the authored distance and the tick span, never captured from the run under test.
	for t in _launch(Enums.CardColor.GREEN) - 1:
		var steering := InputIntent.new()
		steering.move_dir = Vector2(1.0, 0.0)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, steering, InputIntent.new())
		var want := _launch_velocity(Enums.CardColor.GREEN, t + 1, DIR_AHEAD)
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
			"launch tick %d: input after the commit does not end the attack" % t)
		assert_true(ms.p1.hero.velocity.is_equal_approx(want),
			"launch tick %d: move input does not steer the launch -- velocity %s, want the frozen line %s"
				% [t, ms.p1.hero.velocity, want])
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"the attack still LANDS on the authored landing tick")


## AC 2 boundary, the other side (code review 6-1c): the tick step 2 CLOSES the chargeup window is
## the sharpest edge the old `charge_window.is_running` conjunct had, and it is still worth driving
## explicitly -- the attack must carry on across it and land on the authored tick.
##
## Story 6-9 REFRAMED: under `6-1` this drove a RELEASE on that tick and pinned that it was ignored.
## The conjunct and the release are both gone; what the tick has to prove now is that the commit
## edge itself is not an exit, which the same drive asserts.
func test_the_commit_tick_itself_is_not_an_exit() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.charge_window.is_running, "sanity: one chargeup tick still to run")
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_false(ms.p1.charge_window.is_running, "sanity: this tick closed the chargeup (the commit)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"the commit tick is not an exit -- the attack is already committed")
	assert_true(ms.p1.landing_window.is_running, "...and the launch runs on")
	for _t in _launch(Enums.CardColor.BLUE):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"the attack still lands on the authored landing tick")


# --- AC 3: dodging after the commit whiffs; entering the line after it is hit ------------------

## The same sidestep BEFORE the commit is tracked: the hero re-aims, commits onto the new line, and
## lands.
func test_the_same_sidestep_before_the_commit_is_tracked_and_hit() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_SIDE)
	_run_launch(ms, Enums.CardColor.BLUE, DIR_SIDE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"a defender who moved BEFORE the commit is simply tracked and hit")


## AC 3, second sentence: the defender was OFF the line at the commit (to the side) and steps INTO
## the frozen line during the launch: HIT -- the freeze is on direction, not a lock on the defender.
## (Story 7-8: the hit now lands on the first counted touch, `7-8/R1`, so the side touches already hit.)
func test_a_defender_who_enters_the_frozen_line_after_the_commit_is_hit() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_AHEAD)
	for _t in _launch(Enums.CardColor.BLUE) - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"a defender touched after the commit is hit, wherever it was at the commit")


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
			_advance(ms, InputIntent.new(), InputIntent.new())
			travelled += ms.p1.hero.velocity / TimingWindow.TICK_HZ
			moving_ticks += 1 if not ms.p1.hero.velocity.is_zero_approx() else 0
		assert_eq(moving_ticks, _launch(color),
			"colour %d: the hero moves on exactly its %d launch ticks" % [color, _launch(color)])
		var want := Vector3(-DIR_AHEAD.x, 0.0, -DIR_AHEAD.y) * float(LAUNCH_DISTANCE[color])
		assert_true(travelled.is_equal_approx(want),
			"colour %d: travelled %s along the frozen line, want %s" % [color, travelled, want])
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "landed")
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO,
			"colour %d: no launch velocity survives the landing tick" % color)


## AC 4 / `5-2/R5`: the CHARGEUP is still hard-rooted -- the launch velocity starts at the commit
## and not one tick earlier.
func test_the_chargeup_stays_hard_rooted_up_to_the_commit() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for t in CHARGEUP_TICKS - 1:
		var moving := InputIntent.new()
		moving.move_dir = Vector2(1.0, 0.0)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, moving, InputIntent.new())
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO, "chargeup tick %d: rooted" % t)
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_false(ms.p1.hero.velocity.is_zero_approx(), "the commit tick is the first launch tick")


# --- Story 7-8 (`7-8/R8`, AC 6): no arc -- a counted touch hits whatever the facing ----------------

## Story 7-8 AC 6, REPLACING 6-1c's arc pair (`test_a_defender_who_leaves_the_frozen_line_after_the_
## commit_is_missed`, `test_each_colour_judges_its_own_arc_against_the_committed_direction`) and 6-1d's
## five arc tests: the colour arc retired (`7-8/R8`). Every colour, every bearing -- dead ahead, the
## old narrow arcs' edges, square to the side, straight behind -- the defender is touched once after
## the commit and the hit lands on that tick, whatever the frozen facing says.
func test_a_counted_touch_hits_whatever_the_attackers_facing() -> void:
	for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
		for degrees: float in [0.0, 25.0, 65.0, 90.0, 180.0]:
			var ms := _make_match(color)
			_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
			assert_eq(ms.p1.hero.facing, -DIR_AHEAD, "sanity: committed dead ahead")
			_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE,
					DIR_AHEAD.rotated(deg_to_rad(degrees)))
			_advance(ms, InputIntent.new(), InputIntent.new())
			assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
				"colour %d, touched %.0f deg off the committed line: HIT on the touch tick (AC 6)"
					% [color, degrees])


## AC 5 (unchanged): the CONTACT is still the runner's KIND. A flight whose every committed tick
## reports `OUTSIDE` never lands, on the radial colour too. Renamed at story 7-8 from
## `test_the_arc_never_widens_an_outside_kind`: there is no arc left to widen anything.
func test_an_outside_fact_on_every_tick_never_lands() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	for _t in _launch(Enums.CardColor.GREEN):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: the attack resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "no touch, no hit")


# --- AC 6: the single seat --------------------------------------------------------------------

## Story 6-6b (AC 3/AC 5): THE TWO RULED CONSEQUENCES OF THE NEW SEAT, recorded as decisions here
## rather than left to be discovered at the live smoke. This file is their home because it already
## owns the fixture that can express "the attack would have missed": the arc, the reach kind and the
## pushed direction are all under a test's control here and nowhere else.
##
## (a) A DEFENDER ALREADY IN REACH AT THE COMMIT IS STILL COUNTERED. The commit tick's own push
##     latches `INSIDE` before the judgement runs, and AC 3's ruling DISCARDS it -- so this half goes
##     RED against an implementation that consults `_charge_reach` on the commit tick.
## (b) A CORRECT PRESS AGAINST AN ATTACK THAT WOULD HAVE MISSED STILL KNOCKS THE ATTACKER DOWN. With
##     the landing rung retired the counter no longer waits for a landing to answer, so an attack
##     flying wide is countered exactly as one that would have connected. That FOLLOWS from AC 3 as
##     ruled; AC 5 names it so it is a decision rather than a surprise.
##
## THE WINDOW IS INJECTED ONE TICK SHORT OF THE COMMIT, through `_charge_to_the_commit_tick`, so the
## step-2 tick of the commit tick itself puts the window at elapsed 1 -- the first count any
## judgement can ever read, and comfortably inside this fixture's eligibility span.
##
## AND IT IS NOT CONSUMED, on either half: nothing consumes a counter window any more (AC 5).
func test_a_counter_at_the_commit_beats_reach_and_beats_a_whiff_alike() -> void:
	for would_hit: bool in [true, false]:
		var ms := _make_match(Enums.CardColor.BLUE)
		_charge_to_the_commit_tick(ms)
		ms.p2.defense_window.start(COUNTER_BUSY_TICKS)
		ms.p2.defense_color = Enums.CardColor.BLUE
		ms.drain_signals()
		# The COMMIT tick: dead ahead and INSIDE (the attack would connect), or off the line and
		# OUTSIDE (it is flying wide and would whiff).
		var kind := MatchState.CONTACT_CHARGE_REACH_INSIDE if would_hit \
				else MatchState.CONTACT_CHARGE_REACH_OUTSIDE
		var dir := DIR_AHEAD if would_hit else DIR_SIDE
		_push_reach_dir(ms, 0, kind, dir)
		_advance(ms, InputIntent.new(), InputIntent.new())
		var label := "would hit" if would_hit else "would whiff"
		if would_hit:
			assert_eq(ms._charge_reach[0], MatchState.CONTACT_CHARGE_REACH_INSIDE,
				"%s: precondition: the commit tick's own push HAS latched INSIDE" % label)
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
			"%s: the counter lands at the COMMIT and knocks the attacker down (6-6b AC 3/AC 5)"
					% label)
		assert_eq(ms.p2.hero.get_hp(), MAX_HP, "%s: ...the defender is unhurt" % label)
		assert_false(ms.p1.charge_window.is_running, "%s: ...the attack is torn down..." % label)
		assert_false(ms.p1.landing_window.is_running, "%s: ...both windows..." % label)
		assert_eq(ms.p1.charge_color, PlayerState.NO_TELEGRAPH_COLOR,
			"%s: ...and its colour, as one fact" % label)
		assert_true(ms.p2.defense_window.is_running,
			"%s: ...and the answering window is NOT consumed -- nothing consumes it (AC 5)" % label)


# --- AC 9: the launch progress channel keys off the landing edge -------------------------------

## AC 9 / AC 11 / Fact 7. The runner pushes charge progress only while `action_state == CHARGING`,
## computed by `AnimationController.charge_attack_progress` from the landing window. Driven here
## through the REAL state tick with that exact gate: on every tick the hero is still charging the
## progress is STRICTLY below 1.0 and STRICTLY rising (the launch never freezes on a pose); the
## commit tick sits at C / (C + L); and the tick the hero leaves CHARGING is exactly the landing tick,
## on which the landing window reads 0 remaining -- i.e. the progress the SAME formula gives there is
## exactly 1.0.
##
## STORY 7-8 (`7-8/R1`): the damage lands on the TOUCH tick now, not on the landing tick, so the fixture
## reports a touch on the LANDING TICK ONLY -- which also pins that the last flight tick is still a
## counted contact tick. It used to push `INSIDE` on every tick and assert no damage before the landing,
## which 7-8 supersedes (the touch on the commit tick would hit there).
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
		var kind := MatchState.CONTACT_CHARGE_REACH_INSIDE if t == c + l \
				else MatchState.CONTACT_CHARGE_REACH_OUTSIDE
		_push_reach_dir(ms, 0, kind, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			landing_tick = t
			break
		var progress := _pushed_progress(ms, c, l)
		assert_true(progress < 1.0, "tick %d: still charging, progress %.4f < 1.0" % [t, progress])
		assert_true(progress > previous, "tick %d: progress rises (%.4f > %.4f) -- never frozen"
			% [t, progress, previous])
		assert_eq(ms.p2.hero.get_hp(), MAX_HP, "tick %d: no touch yet, no damage" % t)
		if t == c:
			assert_true(is_equal_approx(progress, float(c) / float(c + l)),
				"the COMMIT tick sits at C / (C + L), got %.4f" % progress)
		previous = progress
	assert_eq(landing_tick, c + l, "the hero leaves CHARGING on exactly cast + C + L")
	assert_eq(ms.p1.landing_window.remaining_ticks(), 0, "the landing window has closed")
	assert_eq(AnimationController.charge_attack_progress(0, c, l), 1.0,
		"...so the formula's value on the landing tick is exactly 1.0 -- the strike frame")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"a touch on the LANDING tick still counts, and lands on that tick")


## AC 9 with NO launch span (the pre-6-1c shape): the landing tick is the chargeup-close tick, so
## the 6-1b/R6 contract is re-verified unchanged -- the hero leaves CHARGING on exactly cast + C.
func test_with_a_zero_launch_the_landing_is_the_chargeup_close_edge_as_before() -> void:
	var ms := _make_match(Enums.CardColor.BLUE, false)
	assert_eq(ms.balance_ticks.unblockable_launch_ticks_for(Enums.CardColor.BLUE), 0, "sanity")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for t in CHARGEUP_TICKS - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "tick %d" % t)
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
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
	# Story 7-8: the commit tick reports NO touch -- under `7-8/R1` a commit-tick touch would hit right
	# there, before the death this test is about. Every touch below comes after the death.
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	ms.p1.hero.take_damage(MAX_HP)
	# Story 7-8: no touch on the death tick either -- its step 3 still runs the CHARGING arm before
	# step 8 writes DEAD, so a touch there would be an ordinary same-tick trade, not a corpse's hit.
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_SIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.DEAD, "died mid-launch")
	assert_true(bool(ms.to_snapshot()["round_over"]), "sanity: natural death latches the round over")
	var facing := ms.p1.hero.facing
	for _t in _launch(Enums.CardColor.GREEN) + 2:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
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
	# Story 7-8: no touch on the commit tick, for the sibling's reason directly above.
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	var facing := ms.p1.hero.facing
	ms.p1.hero.set_action_state(HeroState.ActionState.DEAD)
	for _t in _launch(Enums.CardColor.GREEN) + 2:
		ms.set_lock_direction(0, MINION_DIR)
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_SIDE)
		var moving := InputIntent.new()
		moving.move_dir = Vector2(1.0, 0.0)
		_advance(ms, moving, InputIntent.new())
		assert_false(bool(ms.to_snapshot()["round_over"]), "sanity: the forced idiom keeps the round live")
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO, "a DEAD hero does not keep launching")
		assert_eq(ms.p1.hero.facing, facing, "a DEAD hero's facing holds, lock or no lock")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "and the DEAD hero's launch never lands")


# --- STORY 6-1d: continuous contact, the committed window, and the front-loaded launch ---------

## Story 6-1d AC 6, the SUPERSESSION of `6-1c` AC 3, stated as the behaviour change it is: the
## defender is touched on the FIRST launch tick and has cleared the blade by the landing tick. Before
## 6-1d only the landing tick's answer was read, so this was a guaranteed miss. Since story 7-8 the hit
## lands ON that touch tick (`7-8/R1`), which makes it a HIT by a different route.
##
## The chargeup and the commit tick push OUTSIDE, so nothing pre-commit and nothing at the commit
## contributes: the ONLY touch in the whole attack is that one launch tick.
func test_a_defender_touched_on_one_launch_tick_is_hit_even_after_it_clears_the_blade() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_cast_and_charge_kind(ms, DIR_AHEAD, MatchState.CONTACT_CHARGE_REACH_OUTSIDE)
	for t in _launch(Enums.CardColor.GREEN):
		var kind := MatchState.CONTACT_CHARGE_REACH_INSIDE if t == 0 \
				else MatchState.CONTACT_CHARGE_REACH_OUTSIDE
		_push_reach_dir(ms, 0, kind, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
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
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"clear on every evaluated tick is still a MISS -- 'checked every tick' is not 'always hits'")


## Story 6-1d AC 4: THE CONTACT WINDOW OPENS AT THE COMMIT AND NEVER EARLIER. The defender is in
## contact for the ENTIRE chargeup -- every tick but the last -- and clear from the commit tick
## onwards. A touch before the attack has launched credits nothing, so this is a MISS.
##
## MUTATION: delete the `is_contact_window_open()` clearing arm in `MatchState.push_contact` (leaving
## `INSIDE` unconditionally absorbing) and this test goes RED -- the chargeup's touches would latch
## and the attack would land.
func test_contact_during_the_chargeup_credits_nothing() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.charge_window.is_running, "sanity: still charging, the commit is next tick")
	for _t in _launch(Enums.CardColor.GREEN) + 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"a blade already in motion during the CHARGEUP credits nothing (AC 4)")


## Story 6-1d AC 4/AC 5, the store's REAPING, proven directly rather than by consequence (the `6-1d`
## N4 hazard: a landing record that is opened and never erased). There is no record to erase -- the
## verdict is one int per slot, and every pre-commit push CLEARS it -- so the property to prove is
## that it rests at `REACH_UNKNOWN` outside a committed flight, whatever happened before.
##
## Three readings: while touches arrive throughout the CHARGEUP (nothing is credited and nothing
## accumulates), after a chargeup ABANDONED with no landing verdict -- the path that resolves no
## landing at all, so the one most likely to leak a record -- and after a LANDED attack, where a
## single further push with no attack in flight puts the store back at rest.
##
## STORY 6-9, RULING `6-9/R3`: the middle reading used to execute a FEINT, which no input can
## produce any more. It is re-reached through the KNOCKDOWN ABANDONMENT -- P2's own unblockable
## landing on P1 mid-chargeup -- which is a real in-match path that ends a paid chargeup with no
## landing verdict, exactly the condition this reading tests. The debug reset would reach the same
## state and is deliberately NOT used: it is an operator tool, and the claim would stop being
## testable in play.
func test_the_contact_verdict_rests_at_unknown_outside_a_committed_flight() -> void:
	var ms := _make_match(Enums.CardColor.GREEN)
	# P2 casts FIRST, so that its landing falls while P1 is still mid-chargeup. P1 is cast in once
	# P2's landing is CHARGEUP_TICKS - 2 ticks away: P1 then charges for 24 and is knocked down on
	# its 22nd chargeup tick, with its own landing still two ticks out.
	_advance(ms, InputIntent.new(), _unblockable_intent(0))
	# BOUNDED: a drive that can spin forever is useless as a mutation proof -- a broken build would
	# hang the harness instead of reporting.
	for _t in CHARGEUP_TICKS + _launch(Enums.CardColor.GREEN):
		if ms.p2.landing_window.remaining_ticks() <= CHARGEUP_TICKS - 2:
			break
		_push_reach_dir(ms, 1, MatchState.CONTACT_CHARGE_REACH_INSIDE, -DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p2.landing_window.remaining_ticks() <= CHARGEUP_TICKS - 2,
		"fixture: P2's attack is close enough to its landing to catch P1 mid-chargeup")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"precondition: P1 is charging, with P2's attack already in the air")
	var readings := 0
	for _t in CHARGEUP_TICKS:
		if ms.p1.hero.action_state != HeroState.ActionState.CHARGING \
				or not ms.p1.charge_window.is_running:
			break
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_push_reach_dir(ms, 1, MatchState.CONTACT_CHARGE_REACH_INSIDE, -DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if ms.p1.hero.action_state == HeroState.ActionState.CHARGING:
			readings += 1
			assert_eq(ms._charge_reach[0], MatchState.REACH_UNKNOWN,
				"chargeup tick: touches arrive but nothing is credited yet")
	assert_true(readings > 0,
		"the conditional reading above actually executed (a drift that skips it must not go green)")
	# The abandonment: P2's landing knocked P1 down mid-chargeup. No landing verdict resolves for
	# P1 at all, and the one committed-window push its attack ever got is all the store could hold.
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"sanity: P1 was KNOCKED DOWN mid-chargeup -- the abandonment, not a landing")
	assert_false(ms.p1.charge_window.is_running, "sanity: the abandonment tore the chargeup down")
	assert_false(ms.p1.landing_window.is_running, "sanity: ...and the landing window with it")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "sanity: P1's own attack never landed on P2")
	# ...and the very next push with nothing in flight puts it back at rest. There is no record to
	# erase and no counter to reap: the clearing arm runs on every push outside a committed flight.
	_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms._charge_reach[0], MatchState.REACH_UNKNOWN,
		"an abandoned attack leaves nothing behind that a later push does not clear")
	# The same, after a LANDED attack rather than an abandoned one. Idle first: the abandoned cast's
	# stamina stays spent (`E5-P/R4`), so the pool has to regenerate before a second one is
	# affordable -- and P1's stun has to run out.
	for _t in 300:
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
			_advance(ms, InputIntent.new(), InputIntent.new())
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
		_advance(ms, InputIntent.new(), InputIntent.new())
	var travelled := ms.p1.hero.velocity / TimingWindow.TICK_HZ
	for _t in ticks - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
		travelled += ms.p1.hero.velocity / TimingWindow.TICK_HZ
	assert_true(absf(travelled.length() - 2.4) < 0.0001,
		"a span off the tick grid still travels the authored 2.4, got %.5f" % travelled.length())


# --- 6-1d review fix: the latch's clearing is owned (`6-1d/R9`) --------------------------------

## `6-1d/R9`: the `C == 1` cross-arena free hit is dead. With a ONE-TICK chargeup the first push of an
## attack already lands inside the contact window, so no pre-commit push ever runs the clearing arm.
## Attack #1 lands with the fact left `INSIDE`; attack #2 is flown with the defender reported OUTSIDE
## on every evaluated tick. The stale fact must not survive into it.
##
## STORY 7-8 (`7-8/R10`): the fact is this tick's now, so attack #2's first push overwrites the stale
## value whatever the cast seat does; the claim stands, and the cast-seat clear is defence in depth.
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
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: attack #1 resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "sanity: attack #1 landed")
	assert_eq(ms._charge_reach[0], MatchState.CONTACT_CHARGE_REACH_INSIDE,
		"sanity: attack #1 left its fact INSIDE -- the stale value under test")
	for _t in 200:
		_advance(ms, InputIntent.new(), InputIntent.new())
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: attack #2 cast")
	for _t in 1 + _launch(Enums.CardColor.GREEN):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "sanity: attack #2 resolved")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"attack #2 measured OUTSIDE on every evaluated tick and must MISS, not inherit attack #1's hit")


## `6-1d/R9`: the contact fact is part of the chargeup's one fact, so the debug reset clears it beside
## the windows and the colour. Read directly: after a landed attack nothing else touches the store, so
## only the reset can put it back at rest. Story 7-8 (`7-8/R8`) retired the bearing latched with it;
## renamed from `test_the_debug_reset_clears_the_contact_verdict_and_its_bearing`.
##
## MUTATION: delete the clear in `_reset_player` and this goes RED.
func test_the_debug_reset_clears_the_contact_fact() -> void:
	var ms := _make_match(Enums.CardColor.BLUE)
	_cast_and_charge(ms, DIR_AHEAD)
	_run_launch(ms, Enums.CardColor.BLUE, DIR_AHEAD)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "sanity: landed")
	assert_eq(ms._charge_reach[0], MatchState.CONTACT_CHARGE_REACH_INSIDE, "sanity: the fact is INSIDE")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms._charge_reach[0], MatchState.REACH_UNKNOWN, "the reset clears the fact")


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
		_advance(ms, InputIntent.new(), InputIntent.new())
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
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "sanity: committed, not landed")
	assert_false(ms.p1.charge_window.is_running, "sanity: the chargeup window has closed")


## Cast on slot 0 and run the CHARGEUP only, aiming dead ahead and touching nothing, stopping
## one tick short of the commit: the caller's next push is the commit tick's (`6-1d/R13`).
func _charge_to_the_commit_tick(ms: MatchState) -> void:
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_OUTSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.charge_window.is_running, "sanity: still charging, the commit is the next tick")


## Run the rest of the launch (after `_cast_and_charge`) through the landing tick, pushing INSIDE with
## the defender's direction `defender` on every tick.
func _run_launch(ms: MatchState, color: int, defender: Vector2) -> void:
	for _t in _launch(color):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, defender)
		_advance(ms, InputIntent.new(), InputIntent.new())


## Cast and run an attack all the way out, dead ahead.
func _cast_rest(ms: MatchState, color: int) -> void:
	for _t in CHARGEUP_TICKS + _launch(color):
		_push_reach_dir(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE, DIR_AHEAD)
		_advance(ms, InputIntent.new(), InputIntent.new())


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
	c.counter_busy_seconds_red = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_blue = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_green = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	# Story 7-9 (AC 6, `7-9/R16`): the counter LEAD, authored AT the busy span so the busy span stays the
	# binding edge here and this file's counter claims (the commit-tick ordering, not the window's front
	# edge) keep testing what they were written to test. Unauthored, the lead is 0 and every pre-commit
	# window -- this file injects one a tick before the commit -- is too early. The lead's own edge is pinned
	# in `test_unblockable_tempo.gd`.
	c.counter_lead_seconds_red = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_lead_seconds_blue = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_lead_seconds_green = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.roll_distance = 3.0
	c.deflect_window_seconds = 0.1
	c.draw_replacement_delay_seconds = float(DRAW_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = 10.0
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


func _unblockable_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
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
