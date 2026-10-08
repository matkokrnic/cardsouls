extends TestCase

## Story 6-9: mode ② is CLICK AND COMMIT. The press spends the card and the stamina and carries the
## attack to its landing; there is nothing to hold and nothing to cancel. This file owns the half
## `test_unblockable_hold.gd` used to own from the other side -- that file asserted what a RELEASE
## did, and the release is gone with the arm that read it.
##
## WHY A NEW FILE, on the retired file's own precedent: what is under test here is that NO INPUT
## reaches a committed chargeup. Every other mode ② file is organised around a chargeup that runs
## out (initiation's spend-and-root chain, orbs' grant-at-expiry faucet, defense's colour ladder,
## tracking's frozen line); this file drives the INPUT space against that chargeup and asserts it
## changes nothing.
##
## NOTHING HERE WRITES A HELD `card_cast` KEY, and that is the point rather than an omission: no
## controller produces it any more (AC 7) and no state arm reads it. The repo-wide search in AC 7 is
## the guard that it is gone; a test asserting on the token would put it back.
##
## FIXTURE SHAPE. Every quantity is distinct from its sibling fixtures' (24, 6 and 4 ticks of
## chargeup are taken elsewhere): chargeup 16 ticks, a 5-tick RED launch span so the commit and the
## landing are DIFFERENT ticks and "stays CHARGING until the landing" has a span to be true across,
## stamina 50 with a 20 cost, damage 10 % of 100 hp, regen 6 ticks of delay at a real rate so AC 3(f)
## is observable rather than inferred, draw delay 40 ticks so a vacated slot stays a visible hole.
##
## THE REACH FACT IS PUSHED BY HAND through the real `push_contact` seam, exactly as the sibling
## fixtures do -- these tests drive no runner.

const SEED := 6969
const DECK_SIZE := 8
const HAND_SIZE := 4
const CARD_COST := 3.0
const START_MANA := 30.0
const MAX_HP := 100.0
const MAX_STAMINA := 50.0
const UNBLOCKABLE_COST := 20.0
const DEFENSE_COST := 4.0
const CHARGEUP_TICKS := 16
const LAUNCH_TICKS := 5
const COUNTER_BUSY_TICKS := 22
const REGEN_DELAY_TICKS := 6
const DRAW_DELAY_TICKS := 40
const UNBLOCKABLE_DAMAGE := 10.0   # 10 % of 100.0 max hp
const REACH := 8.0

## The planar TARGET -> ATTACKER direction the runner would compute (the 1-8 convention).
const FACT_DIR := Vector2(0.0, 1.0)

## The tick the attack lands on, counted from the commit tick: the chargeup window plus the
## colour's launch span.
const LANDING_AT := CHARGEUP_TICKS + LAUNCH_TICKS


# --- AC 1: a press commits ---------------------------------------------------------------------

## AC 1: the same cast, driven two ways that could not differ more in input -- one whose every
## post-commit intent is BARE, one whose every post-commit intent holds every LIVE held key and
## carries a full move vector -- resolves identically. Same landing tick, same hp, same orb, same
## stamina, same card bookkeeping, same `hit_landed`.
##
## THIS IS THE STORY'S BEFORE-CLAIM. Against `6-1`'s release arm the bare run FEINTS on the tick
## after the commit and the two runs diverge on every one of these facts; the mutation proof drives
## exactly that.
func test_a_bare_run_and_a_hold_everything_run_resolve_identically() -> void:
	var bare := _run_to_the_landing(func(_t: int) -> InputIntent: return InputIntent.new())
	var holding := _run_to_the_landing(func(_t: int) -> InputIntent: return _everything_held())
	# The loud run HOLDS every live key and carries a full move vector on every tick INCLUDING the
	# landing tick (AC 1's words). It does not also PRESS: a press is an edge, and on the landing
	# tick -- after step 3 has written IDLE -- an edge legitimately starts the NEXT action, which
	# would be this comparison measuring the input layer rather than the attack. AC 2's rows 3, 4
	# and 6 drive the presses, against the ticks where the claim is about the chargeup.
	assert_eq(bare["landed_on"], LANDING_AT,
		"the bare run lands on the authored tick -- nothing after the press was needed")
	assert_eq(holding["landed_on"], bare["landed_on"],
		"...and the hold-everything run lands on the SAME tick")
	for fact: String in ["hp", "stamina", "orbs", "hand", "discard", "owed", "hits"]:
		assert_eq(holding[fact], bare[fact],
			"%s is identical across the two runs: no input after the press reaches the attack" % fact)
	assert_eq(bare["hp"], MAX_HP - UNBLOCKABLE_DAMAGE, "...and the attack really LANDED (non-vacuity)")


# --- AC 2: nothing cancels it from input ---------------------------------------------------------

## AC 2's table, all seven rows. Rows 1-6 are STAYS -- the hero is still CHARGING on every tick
## through to the landing -- and row 7, the debug reset, is an EXIT.
##
## THE EXIT ROW IS WHAT MAKES THE TABLE NON-VACUOUS: without a row that legitimately leaves
## CHARGING, "stays CHARGING" would be satisfied by a `_resolve_actions` that did nothing at all.
## It is asserted here, beside the stays, rather than in a test of its own for exactly that reason.
##
## ONE TEST WITH ROWS rather than a test per row (dev-pass choice): the rows share one claim and one
## drive, the failure message names the row, and a table keeps the stays and the exit in the same
## place where the vacuity argument lives.
func test_no_input_row_ends_the_chargeup_and_the_debug_reset_does() -> void:
	for row: Array in _input_rows():
		var label: String = row[0]
		var make: Callable = row[1]
		var ms := _make_match()
		_advance(ms, _unblockable_intent(0), InputIntent.new())
		for t in LANDING_AT - 1:
			_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
			_advance(ms, make.call(t), InputIntent.new())
			assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
				"%s, tick %d: still CHARGING -- this input does not end the attack" % [label, t])
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, make.call(LANDING_AT - 1), InputIntent.new())
		assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
			"%s: ...and the LANDING is what ends it, on the authored tick, for the authored damage"
				% label)
		# WHAT THE HERO DOES ON THAT TICK ONCE IT IS IDLE AGAIN IS THE ROW'S OWN BUSINESS: step 3
		# resolves the landing and step 6 is live input again, so a pressed roll rolls and a pressed
		# cast starts a new chargeup. Asserting IDLE here would assert that the input layer had been
		# ignored, which is the opposite of what this story claims.

	# ROW 7, THE EXIT: the debug reset DOES leave CHARGING, on the same tick it is carried.
	var reset_ms := _make_match()
	_advance(reset_ms, _unblockable_intent(0), InputIntent.new())
	for _t in 4:
		_advance(reset_ms, InputIntent.new(), InputIntent.new())
	assert_eq(reset_ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"precondition: four ticks in, still charging")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(reset_ms, reset, InputIntent.new())
	assert_ne(reset_ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"row 7: the debug reset DOES leave CHARGING (`_reset_player`) -- the row that keeps the "
		+ "twenty rows above from being satisfied by an arm that does nothing at all")
	assert_false(reset_ms.p1.charge_window.is_running, "...tearing the chargeup window down with it")


## AC 2 row 6, the refusal half: a SECOND card press while charging is refused with
## `REASON_UNBLOCKABLE_COMMITTED`, in every mode, and the hero does not leave CHARGING. The stay is
## asserted by the table above (row 6 drives the same presses); what this adds is the REASON.
func test_a_second_card_press_is_refused_with_the_committed_reason_in_every_mode() -> void:
	for mode: int in [Enums.ModeKind.UNBLOCKABLE, Enums.ModeKind.BASIC, Enums.ModeKind.DEFENSE,
			Enums.ModeKind.PITCH]:
		var ms := _make_match()
		_advance(ms, _unblockable_intent(0), InputIntent.new())
		var rejections := _collect_rejections(ms.p1)
		var discard_before := ms.p1.discard.size()
		var stamina_before := ms.p1.stamina.get_current()
		_advance(ms, _card_intent(1, mode), InputIntent.new())
		assert_eq(rejections, [[&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]],
			"mode %d: refused, with the reason that already reads true for a committed caster" % mode)
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
			"mode %d: ...and the refusal does not end the chargeup either" % mode)
		assert_eq(ms.p1.discard.size(), discard_before, "mode %d: no second card was played" % mode)
		assert_eq(ms.p1.stamina.get_current(), stamina_before,
			"mode %d: ...and nothing was spent for it" % mode)


# --- AC 3: the costs, and exactly one verdict ---------------------------------------------------

## AC 3: the press is where the card and the stamina go, and the attack always resolves. Driven with
## bare intents the whole way, which under `6-1` would have refunded nothing but also landed nothing.
func test_the_press_pays_and_the_attack_resolves_exactly_once() -> void:
	var ms := _make_match()
	var landed := _collect_hits(ms)
	var played := _dealt(ms, 0)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA - UNBLOCKABLE_COST,
		"the stamina went at the PRESS")
	assert_eq(ms.p1.discard.to_array(), [played] as Array[StringName], "...and so did the card")
	for _t in LANDING_AT:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(landed.size(), 1, "EXACTLY ONE landing verdict was announced")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "...and it dealt the authored damage")
	assert_false(ms.p1.hand.occupied_ids().has(played), "the card did not come back to the hand")
	assert_eq(ms.p1.pending_draw_owed, [0] as Array[int],
		"...and the replacement is still owed to the vacated slot: nothing was reversed")
	# Well past the landing, with the same bare intents: no second verdict exists to find.
	for _t in 10:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(landed.size(), 1, "...and no later tick announces a second one")


# --- AC 5: the telegraph rests at the landing ----------------------------------------------------

## AC 5: the `telegraph` snapshot fact returns to `[-1, 0]` because the hero LEAVES CHARGING at the
## landing -- the state gate hiding the colour by construction -- and not because anything cleared
## it on a release. The three explicit clears that remain are non-input edges (AC 2's other exits).
func test_the_telegraph_rests_after_the_landing() -> void:
	var ms := _make_match()
	var played := _dealt(ms, 0)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.to_snapshot()["p1"]["telegraph"],
		[int(_colors()[played]), CHARGEUP_TICKS],
		"precondition: the colour is resident and the chargeup is counting down")
	for _t in LANDING_AT:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "the landing resolved")
	assert_eq(ms.to_snapshot()["p1"]["telegraph"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
		"the telegraph rests at [-1, 0] after the landing (AC 5)")
	assert_eq(int(ms.to_snapshot()["p1"]["landing"]), 0, "...and the landing key rests with it")


# --- AC 2's other three exits still work ---------------------------------------------------------

## The COUNTER exit: a matching colour armed before the commit judges the attack, knocks the attacker
## down and tears the chargeup down with it (`6-6b`, untouched by this story -- driven here only to
## prove the exit still exists once the input-driven one is gone).
func test_the_colour_counter_still_ends_a_committed_chargeup() -> void:
	var ms := _make_match()
	var color := _colors()[_dealt(ms, 0)]
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var defense_slot := _slot_of_color(ms.p2, color)
	assert_true(defense_slot >= 0, "fixture: P2 holds the matching colour")
	_advance(ms, InputIntent.new(), _card_intent(defense_slot, Enums.ModeKind.DEFENSE))
	for _t in CHARGEUP_TICKS:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
		if ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			break
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"the counter judged the committed attack and knocked the attacker down")
	assert_false(ms.p1.charge_window.is_running, "...tearing the chargeup down")
	assert_false(ms.p1.landing_window.is_running, "...and the landing window with it")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "...and the defender took nothing")


## The KNOCKDOWN exit: P2's own unblockable lands on a CHARGING P1, which abandons P1's chargeup with
## NO landing verdict -- the surviving in-match path that ends a paid chargeup for nothing, and the
## one `6-9/R3` re-points the tracking suite's middle reading at.
func test_a_knockdown_still_abandons_a_committed_chargeup() -> void:
	var ms := _make_match()
	var landed := _collect_hits(ms)
	_advance(ms, InputIntent.new(), _unblockable_intent(0))
	# BOUNDED, like every drive here: a loop that can spin forever is useless as a mutation proof,
	# because a broken build hangs the harness instead of reporting.
	for _t in LANDING_AT:
		if ms.p2.landing_window.remaining_ticks() <= CHARGEUP_TICKS - 2:
			break
		_push_reach(ms, 1, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p2.landing_window.remaining_ticks() <= CHARGEUP_TICKS - 2,
		"fixture: P2's attack is close enough to its landing to catch P1 mid-chargeup")
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var stamina_after_the_press := ms.p1.stamina.get_current()
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"precondition: P1 is charging with P2's attack already in the air")
	for _t in LANDING_AT:
		if ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			break
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_push_reach(ms, 1, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"P1 was knocked down mid-chargeup: the abandonment, not a landing")
	assert_false(ms.p1.charge_window.is_running, "...the chargeup window is cleared")
	assert_false(ms.p1.landing_window.is_running, "...the landing window with it")
	assert_eq(ms.p1.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "...and the colour rests")
	assert_eq(ms.p1.stamina.get_current(), stamina_after_the_press,
		"the abandoned attack's spend stays spent -- an abandonment is not a refund")
	assert_eq(landed.size(), 1,
		"exactly ONE landing verdict was announced, and it was P2's: P1's attack never resolved")


## The RESET exit, in its three parts. The debug reset is asserted as an exit by AC 2's table; what
## this adds is the teardown `_reset_player` performs, which is the fact a mutation could half-do.
func test_the_debug_reset_tears_a_committed_chargeup_down_in_all_three_parts() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.charge_window.is_running, "precondition: the window is live...")
	assert_ne(ms.p1.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "...and the colour is resident")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "part 1: the state")
	assert_false(ms.p1.charge_window.is_running,
		"part 2: the WINDOW is stopped -- not merely hidden by the state gate, which the snapshot "
		+ "alone could not tell apart")
	assert_false(ms.p1.landing_window.is_running, "part 2b: ...and the landing window with it")
	assert_eq(ms.p1.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "part 3: the colour rests")
	assert_eq(ms.to_snapshot()["p1"]["telegraph"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
		"...and the hashed fact rests with them")


# --- AC 3(f): the NEW claim ----------------------------------------------------------------------

## Story 6-9 Task 3(f), `6-9/R7`: a NEW claim, not a surviving one. `_regen_stamina` reads
## `action_state` fresh at step 5 with no latch, and step 3 has already written IDLE on the landing
## tick, so regen resumes ON THE LANDING TICK rather than one tick later. The retired hold suite
## asserted this of the RELEASE tick; no suite asserts it of the landing, and
## `test_unblockable_initiation.gd`'s `test_stamina_does_not_regenerate_while_charging` covers only
## the suppression half.
##
## NON-VACUOUS BY CONTRAST: the control tick immediately before the landing, with the regen delay
## long served out, yields nothing at all -- so the movement on the landing tick is the state write
## and not the delay expiring.
func test_stamina_regen_resumes_on_the_landing_tick_itself() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in LANDING_AT - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"precondition: one tick before the landing, still charging")
	var charging_reading := ms.p1.stamina.get_current()
	assert_eq(charging_reading, MAX_STAMINA - UNBLOCKABLE_COST,
		"CONTROL: the whole chargeup, with the regen delay (6 ticks) served out many ticks ago, "
		+ "has regenerated NOTHING -- the suppression is CHARGING and not the delay")
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "...this tick carried the landing")
	assert_true(ms.p1.stamina.get_current() > charging_reading,
		"...and regen resumed ON it: step 3 wrote IDLE before step 5 read the state, so there is no "
		+ "dead frame after a landing (`6-9/R7`, a NEW claim)")


# --- helpers ------------------------------------------------------------------------------------

## AC 2's rows 1-6, as (label, intent-for-tick) pairs. Row 7 (the debug reset) is driven separately
## because it is an EXIT and cannot be asserted by the same loop.
func _input_rows() -> Array:
	var rows: Array = []
	rows.append(["row 1: a bare intent", func(_t: int) -> InputIntent: return InputIntent.new()])
	for key: StringName in [&"attack", &"block", &"roll", &"run"]:
		rows.append(["row 2: held %s" % key, func(_t: int) -> InputIntent:
			var i := InputIntent.new()
			i.held[key] = true
			return i])
	for key: StringName in [&"attack", &"block", &"roll"]:
		rows.append(["row 3: pressed %s" % key, func(_t: int) -> InputIntent:
			var i := InputIntent.new()
			i.pressed[key] = true
			return i])
	rows.append(["row 4: the hold-everything chord",
		func(_t: int) -> InputIntent: return _everything_chord()])
	for dir: Vector2 in [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0),
			Vector2(0.0, -1.0), Vector2(1.0, 1.0).normalized()]:
		rows.append(["row 5: move_dir %s" % dir, func(_t: int) -> InputIntent:
			var i := InputIntent.new()
			i.move_dir = dir
			return i])
	for mode: int in [Enums.ModeKind.UNBLOCKABLE, Enums.ModeKind.BASIC, Enums.ModeKind.DEFENSE,
			Enums.ModeKind.PITCH]:
		rows.append(["row 6: a second card press, mode %d" % mode,
			func(_t: int) -> InputIntent: return _card_intent(1, mode)])
	return rows


## Every LIVE held key down at once and a full move vector (AC 1's loud run).
func _everything_held() -> InputIntent:
	var i := InputIntent.new()
	for key: StringName in [&"attack", &"block", &"roll", &"run"]:
		i.held[key] = true
	i.move_dir = Vector2(1.0, 0.0)
	return i


## AC 2 row 4: rows 2 and 3 at once -- every held key AND every press, the loudest single tick the
## input layer can produce for a player who has already committed.
func _everything_chord() -> InputIntent:
	var i := _everything_held()
	for key: StringName in [&"attack", &"block", &"roll"]:
		i.pressed[key] = true
	return i


## Cast on slot 0 and drive to the landing with `make` supplying every post-commit intent, inside
## reach throughout. Returns the tick the landing resolved on and the facts AC 1 compares.
func _run_to_the_landing(make: Callable) -> Dictionary:
	var ms := _make_match()
	var hits := _collect_hits(ms)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var landed_on := -1
	# The stamina reading is taken while the hero is STILL COMMITTED, one tick before the landing:
	# that is the attack's own spend. On the landing tick itself the hero is IDLE again at step 5,
	# and a run-and-move intent legitimately suppresses regen there (`6-7` AC 8) -- the input layer
	# working on the tick after the attack, not the attack being changed.
	var stamina_while_committed := 0.0
	for t in LANDING_AT + 5:
		stamina_while_committed = ms.p1.stamina.get_current()
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, make.call(t), InputIntent.new())
		if landed_on < 0 and ms.p1.hero.action_state != HeroState.ActionState.CHARGING:
			landed_on = t + 1
			break
	return {
		"landed_on": landed_on,
		"hp": ms.p2.hero.get_hp(),
		"stamina": stamina_while_committed,
		"orbs": ms.to_snapshot()["p1"]["orbs"],
		"hand": ms.p1.hand.to_array(),
		"discard": ms.p1.discard.to_array(),
		"owed": ms.p1.pending_draw_owed,
		"hits": hits,
	}


func _unblockable_intent(slot: int) -> InputIntent:
	return _card_intent(slot, Enums.ModeKind.UNBLOCKABLE)


func _card_intent(slot: int, mode: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = mode as Enums.ModeKind
	i.card_commit = true
	return i


func _collect_rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(a: StringName, r: StringName) -> void: out.append([a, r]))
	return out


func _collect_hits(ms: MatchState) -> Array:
	var out: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void:
		out.append([a, t, d, hp]))
	return out


## The runner's every-tick charge-reach push, by hand and through the real seam.
func _push_reach(ms: MatchState, slot: int, kind: int) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	ms.push_contact([slot, TargetingService.HERO_INDEX],
		[1 - slot, TargetingService.HERO_INDEX], player.hero.attack_index, FACT_DIR, kind)


func _dealt(ms: MatchState, slot: int) -> StringName:
	return ms.p1.hand.to_array()[slot]


func _slot_of_color(player: PlayerState, color: int) -> int:
	var ids := player.hand.to_array()
	var map := _colors()
	for i in ids.size():
		if ids[i] != Hand.EMPTY and int(map.get(ids[i], -1)) == color:
			return i
	return -1


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("commit_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CARD_COST
		out[id] = c
	return out


## ONE COLOUR ACROSS THE WHOLE DECK, the retired hold file's fixture decision for its own reason:
## what this file needs from colour is only that an armed window and a charge can be made to MATCH
## whatever the deal produced, which a monochrome deck makes a property of the composition instead
## of the seed.
func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id in _deck_contents():
		out[id] = Enums.CardColor.RED
	return out


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = 90.0
	c.max_stamina = MAX_STAMINA
	# AC 2's row 5 needs movement to be a real input rather than a no-op knob: with the authored
	# default of 0.0 a move vector could not steer anything even if the state layer let it.
	c.move_speed = 4.0
	c.walk_speed = 4.0
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
	c.counter_busy_seconds_red = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_blue = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_green = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	# Story 7-9 (AC 6, `7-9/R16`): the counter LEAD, authored AT the busy span so the busy span stays the
	# binding edge and the counter-exit test below still proves the EXIT, not the window's front edge.
	# Unauthored (0), its press a whole chargeup before the commit would be too early -- the gate's named
	# expected mover (`:206-212`). The lead's own edge is pinned in `test_unblockable_tempo.gd`.
	c.counter_lead_seconds_red = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_lead_seconds_blue = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_lead_seconds_green = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.draw_replacement_delay_seconds = float(DRAW_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_launch_seconds_red = float(LAUNCH_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_launch_seconds_blue = float(LAUNCH_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_launch_seconds_green = float(LAUNCH_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = UNBLOCKABLE_DAMAGE
	c.defense_stamina_cost = DEFENSE_COST
	return c


## The pitch layer is OPEN deliberately: AC 2's row 6 drives a PITCH commit too, and with the flag
## closed that row would be refused by the LAYER gate and would prove nothing about the commitment.
func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.unblockable = true
	f.pitch_zone = true
	return f


func _make_match() -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors())
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	ms.drain_signals()
	return ms


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
