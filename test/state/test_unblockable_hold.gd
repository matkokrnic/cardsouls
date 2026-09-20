extends TestCase

## Story 6-1: mode ② HOLD-THROUGH-CHARGEUP and the PAID FEINT. The chargeup's THIRD exit path
## (`5-2/R3` named two: natural expiry and death) and the first one that reads a LIVE INTENT
## instead of a timer — the Sekiro shape carried as debt since `5-3/R6` and ruled at `5-7/R6`.
##
## WHY A NEW FILE, on the `test_orbs_economy.gd` / `test_unblockable_defense.gd` sibling precedent
## that both of those files named when they made the same call: what is under test here is a
## RELEASE — an input fact that arrives DURING a duration and ends it early. Every existing mode ②
## file is organised around a chargeup that RUNS OUT (initiation's spend-and-root chain, orbs'
## grant-at-expiry faucet, defense's colour ladder at the landing), and all three now hold the
## confirm through their loops precisely so they keep asserting what they always asserted. Leaving
## them saying that, unedited in their claims, buys a free regression that the hold changed nothing
## about the landing path; this file owns the other half — what happens when the hold STOPS.
##
## FIXTURE SHAPE. Every quantity is distinct from every other and from the sibling fixtures' (24,
## 6 and 4 ticks of chargeup are already taken), so an off-by-one lands on a wrong number rather
## than coinciding with a right one: chargeup 16 ticks, stamina 50 with a 20 cost (so a feint's
## "spent once" is an unmistakable 30), damage 10 % of 100 hp, regen 6 ticks of delay at a real
## rate so AC 2's "regen resumes ON the release tick" is observable rather than inferred, draw
## delay 40 ticks so a vacated hand slot stays a visible HOLE for the whole of every test here.
##
## THE HOLD IS THE `BLOCKING` PRECEDENT AND IT IS EXPRESSED THE SAME WAY: `held[&"card_cast"]`,
## the prefix-free key `GamepadController` writes from the mode ② confirm's raw state. A bare
## `InputIntent.new()` on a charging player's slot is therefore a RELEASE, which is why `_holding()`
## exists and why the tests that mean "still holding" say so on every tick.
##
## THE REACH FACT IS PUSHED BY HAND through the real `push_contact` seam, exactly as `5-2`'s
## fixture does — these tests drive no runner.

const SEED := 6161
const DECK_SIZE := 8
const HAND_SIZE := 4
const CARD_COST := 3.0
const START_MANA := 30.0
const MAX_HP := 100.0
const MAX_STAMINA := 50.0
const UNBLOCKABLE_COST := 20.0
const DEFENSE_COST := 4.0
const CHARGEUP_TICKS := 16
## Story 6-6b (AC 1/AC 2), POST-SMOKE (R-S6): the counter's ONE count. The `5-5` one-size
## `DEFENSE_WINDOW_TICKS` and the ELIGIBILITY span that briefly superseded it are both retired with
## their fields; the window this file arms is the colour's BUSY span, and the WHOLE of it answers.
## DISTINCT from every other count here ({4, 6, 16, 40}).
const COUNTER_BUSY_TICKS := 24
## How far ahead of the judged tick the one countering test presses. Any lead the busy span outlives
## answers identically now (R-S6); this one is small so the test is about the counter, not a boundary.
const COUNTER_PRESS_LEAD_TICKS := 5
const REGEN_DELAY_TICKS := 6
const DRAW_DELAY_TICKS := 40
const UNBLOCKABLE_DAMAGE := 10.0   # 10 % of 100.0 max hp
const REACH := 8.0

## The planar TARGET -> ATTACKER direction the runner would compute (the 1-8 convention).
const FACT_DIR := Vector2(0.0, 1.0)


# --- AC 1: the hold-through path is UNCHANGED -------------------------------------------------

## AC 1's regression half, and the reason every other assertion in this file is about a CHANGE
## rather than about mode ② being broken: holding the confirm for the whole authored window lands
## exactly what it landed before this story — same tick, same damage, same IDLE exit.
func test_holding_the_confirm_through_the_whole_chargeup_lands_as_before() -> void:
	var ms := _make_match()
	var landed := _collect_hits(ms)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"still CHARGING one tick before the authored end — the hold carried it the whole way")
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"IDLE on the exact authored tick (AC 20 of 5-2, unmoved)")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "and the attack LANDED")
	assert_eq(landed.size(), 1, "...announcing exactly one hit_landed")


## AC 1's last sentence, and the whole reason the timer is read BEFORE the release inside the arm:
## the chargeup is COMPLETE on the tick its window stops running, so a release observed on that
## same tick must land, not feint. Driven at the exact boundary — held for every tick but the
## expiry one, released ON it.
func test_a_release_on_the_landing_tick_itself_still_lands() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, _holding(), InputIntent.new())
	# The release lands on the SAME tick the window expires: the landing wins.
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"releasing ON the completion tick is a no-op, not a feint (AC 1) — the timer arm is "
		+ "checked first, so there is no tick on which both are true and the release wins")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "and the hero exits normally")


## The other half of AC 1's no-op claim: once the attack has launched, the confirm's state is
## nobody's business. Released for MANY ticks after the landing, nothing further happens.
func test_releasing_after_the_chargeup_completed_changes_nothing() -> void:
	var ms := _make_match()
	_run_chargeup_held(ms)
	# NON-VACUITY: the landing must actually have happened, or "nothing further happens" is a claim
	# about a chargeup that ended early — which is the opposite of what this test is about.
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"precondition: held to completion, the attack LANDED")
	var hp_after := ms.p2.hero.get_hp()
	for _t in 10:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), hp_after,
		"a release AFTER the landing resolves nothing further — there is no chargeup left to end")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "the hero stays IDLE")


# --- AC 2: the paid feint ---------------------------------------------------------------------

## AC 2's fourth bullet: the hero is back under normal control ON THE RELEASE TICK ITSELF, not one
## tick later. Asserted at both boundaries — still CHARGING on the last held tick, IDLE on the very
## next advance, which is the one that carried the release.
func test_an_early_release_returns_the_hero_to_idle_on_the_release_tick() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in 5:
		_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"precondition: five ticks in, still charging, still held")
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"IDLE on the release tick itself (AC 2) — step 3 resolves the exit within that advance")


## AC 2's third bullet: the telegraph fact clears in ALL THREE of its parts, the `_reset_player`
## shape reused for a new trigger. Asserted part by part AND through the snapshot, because a
## half-done teardown (state cleared, window left running) is exactly the defect `5-3`'s own review
## found on the round-over path — the snapshot alone would not catch it, since `telegraph` is gated
## on the action state and would rest either way.
func test_an_early_release_clears_the_telegraph_fact_in_all_three_parts() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	_advance(ms, _holding(), InputIntent.new())
	assert_true(ms.p1.charge_window.is_running, "precondition: the window is live...")
	assert_ne(ms.p1.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "...and the colour is resident")
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "part 1: the state")
	assert_false(ms.p1.charge_window.is_running,
		"part 2: the WINDOW is stopped — not merely hidden by the state gate. A cleared state over "
		+ "a live window is the `5-3` defect, and it is unobservable from the snapshot alone")
	assert_eq(ms.p1.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "part 3: the colour rests")
	assert_eq(ms.to_snapshot()["p1"]["telegraph"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
		"...and the hashed fact rests with them, so nothing stale can reach the golden")


## AC 2's second bullet, and the word PAID in "paid feint": the card and the 20 stamina stay spent.
## Every refund route is asserted shut separately, because they are separate mutations and one
## surviving refund would make the feint free.
func test_an_early_release_is_paid_the_card_and_the_stamina_stay_spent() -> void:
	var ms := _make_match()
	var played := _dealt(ms, 0)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var stamina_after_cast := ms.p1.stamina.get_current()
	assert_eq(stamina_after_cast, MAX_STAMINA - UNBLOCKABLE_COST,
		"precondition: the 20 was taken at the cast (5-2 AC 6, untouched by this story)")
	_advance(ms, InputIntent.new(), InputIntent.new())
	# NON-VACUITY: without this line the whole test passes against a build that has no early-release
	# exit at all — "nothing was refunded" is trivially true of a chargeup still running. The claim
	# is that the FEINT happened AND cost full price, so the feint has to be asserted too.
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"precondition: the release really did end the chargeup")
	assert_eq(ms.p1.stamina.get_current(), stamina_after_cast,
		"the feint credits NO stamina back — the release is not an undo")
	assert_false(ms.p1.hand.occupied_ids().has(played), "the card did NOT come back to the hand")
	assert_eq(ms.p1.discard.to_array(), [played] as Array[StringName],
		"...and it is still in the discard, that card and only that card")
	assert_eq(ms.p1.pending_draw_owed, [0] as Array[int],
		"the replacement is still owed to the vacated slot — the feint reverses no bookkeeping")


## AC 2's first bullet: the attack resolves into NOTHING. Driven well past the tick the landing
## would have resolved on, INSIDE reach the entire way, so the only thing standing between the
## enemy and the damage is the feint itself.
func test_a_feint_lands_nothing_even_though_the_enemy_was_in_reach_throughout() -> void:
	var ms := _make_match()
	var landed := _collect_hits(ms)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in 4:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, _holding(), InputIntent.new())
	for _t in CHARGEUP_TICKS + 4:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"no damage, ever — the landing check never ran, because `_resolve_charge_landing` is not "
		+ "reached from the release arm at all")
	assert_eq(landed, [], "and no hit_landed was emitted")


## AC 2 / `6-1/R7`: a feint against an ARMED, COLOUR-MATCHING mode 3 window answers nothing and
## CONSUMES nothing -- the window is left running to self-expire, and no window-clearing code exists
## on this path. The pairing is what makes the claim non-vacuous: the same fixture that leaves the
## window untouched on a feint COUNTERS on a chargeup that is held out.
##
## STORY 6-6b (AC 6) MAKES THIS THE FEINT BAIT, which is a stronger claim than `6-1` could make. The
## counter is judged only once the chargeup window has STOPPED, so a feinted chargeup never reaches a
## judged tick at all -- and the defender has already paid the card, the stamina and (new) the whole
## BUSY span for a counter that answered nothing. That is the bait the counter presentation exists to
## make possible, and it is structural: `_resolve_color_counter` returns at its first line while the
## chargeup still runs.
func test_a_feint_neither_consumes_nor_is_answered_by_an_armed_defense_window() -> void:
	var ms := _make_match()
	var deflects := _collect_deflects(ms)
	var color := _arm_matching_defense(ms)
	_cast_unblockable_of_color(ms, color)
	var remaining := ms.p2.defense_window.remaining_ticks()
	_advance(ms, _holding(), InputIntent.new())
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE, "precondition: the feint fired")
	assert_true(ms.p2.defense_window.is_running,
		"the defender's window is STILL OPEN -- a feint consumes nothing (`6-1/R7`)")
	assert_eq(ms.p2.defense_window.remaining_ticks(), remaining - 2,
		"...and it counted down at its ordinary step-2 rate across both ticks, neither cut short "
		+ "nor frozen: nothing on the feint path touches it")
	assert_eq(deflects, [], "no deflect_landed -- the chargeup never reached a judged tick")
	assert_eq(ms.p1.hero.get_hp(), MAX_HP, "and the attacker takes no damage from a counter...")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"...and is NOT knocked down: the judgement is gated on the chargeup having STOPPED, and a "
		+ "feint stops it by leaving CHARGING instead (6-6b AC 6)")
	assert_eq(ms.p2.stamina.get_current(), MAX_STAMINA - DEFENSE_COST,
		"the baited defender still paid its stamina...")
	assert_eq(ms.p2.discard.size(), 1, "...and its card")


## The pairing above's other half: the identical fixture, held to completion AND pressed inside the
## eligibility span, DOES counter. Without this the test above would pass against a build where mode
## 3 never worked at all.
##
## WHERE THE PRESS SITS (6-6b, POST-SMOKE R-S6): anywhere whose busy span is still RUNNING at the
## judged tick. The dev pass parked it a few ticks ahead to sit inside the then-live eligibility
## head; that head is gone, so it is parked a few ticks ahead simply because a press on the judged
## tick itself is too late (step 6 resolves after step 3) and this test is about neither boundary.
func test_the_same_fixture_does_counter_a_chargeup_that_is_held_out() -> void:
	var ms := _make_match()
	var deflects := _collect_deflects(ms)
	var color: Enums.CardColor = _colors()[ms.p2.hand.to_array()[_first_occupied(ms.p2)]]
	_cast_unblockable_of_color(ms, color)
	var press_at := CHARGEUP_TICKS - 1 - COUNTER_PRESS_LEAD_TICKS
	for t in CHARGEUP_TICKS:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		var defender_intent := InputIntent.new()
		if t == press_at:
			defender_intent = _defense_intent(_first_occupied(ms.p2))
		_advance(ms, _holding(), defender_intent)
	assert_eq(deflects.size(), 1,
		"NON-VACUITY: held out and pressed inside the eligibility span, the SAME fixture counters "
		+ "the SAME colour -- so the test above is about the feint and not about a counter that "
		+ "never fires")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"...knocking the attacker down (6-6b AC 4)")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "...and sparing the defender")
	assert_true(ms.p2.defense_window.is_running,
		"...while the window itself is NOT consumed: nothing consumes it any more (6-6b AC 5)")


## AC 2's fourth bullet, regen half: `_regen_stamina` reads the action state fresh at step 5, and
## step 3 has already written IDLE, so regen resumes ON the release tick rather than one tick
## later. Non-vacuous by contrast — the same pool over the same ticks WHILE STILL HELD does not
## move at all, which is the suppression this test is distinguishing itself from.
func test_stamina_regen_resumes_on_the_release_tick_itself() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	# Serve out the regen delay while still charging, so the delay cannot be mistaken for the
	# suppression: by the last of these ticks the only thing holding the faucet shut is CHARGING.
	for _t in REGEN_DELAY_TICKS + 2:
		_advance(ms, _holding(), InputIntent.new())
	var held_reading := ms.p1.stamina.get_current()
	_advance(ms, _holding(), InputIntent.new())
	assert_eq(ms.p1.stamina.get_current(), held_reading,
		"CONTROL: one more HELD tick past the regen delay still yields nothing (AC 14 of 5-2)")
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.stamina.get_current() > held_reading,
		"...and the very next tick, which carried the RELEASE, regenerates — step 3 wrote IDLE "
		+ "before step 5 read it, so there is no one-tick dead frame after a feint")


# --- AC 3: the tap ----------------------------------------------------------------------------

## AC 3: the shortest OBSERVABLE press — commit on tick N, released by tick N+1's sample — is the
## same paid feint as any other early release. No grace window, no minimum hold, no partial hit.
## (A press and release BETWEEN two samples produces no edge at all and so no cast; that is an
## input-sampling fact of `GamepadController`, not a state-layer grace, and is not what this pins.)
func test_a_one_tick_tap_is_the_same_paid_feint() -> void:
	var ms := _make_match()
	var landed := _collect_hits(ms)
	var played := _dealt(ms, 0)
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING,
		"precondition: the commit tick entered CHARGING as it always has")
	_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"one held tick is the floor, and the release exits on the very next tick (AC 3)")
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA - UNBLOCKABLE_COST,
		"the tap is PAID — the shortest feint costs exactly what the longest one does")
	assert_eq(ms.p1.discard.to_array(), [played] as Array[StringName], "...and the card is gone")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "no partial hit — a tap is not a weaker attack")
	assert_eq(landed, [], "...and nothing was announced")


# --- AC 4: no recovery window -----------------------------------------------------------------

## AC 4: the instant the hero is IDLE it is fully controllable — no lockout, no root, no refusal.
## Both halves are asserted on the SAME tick the release resolved: a full move input produces real
## velocity (the hard root is gone, `5-2` AC 11 having pinned it as an exact zero while charging),
## and a roll press on the next tick is honoured rather than refused.
func test_no_recovery_window_follows_a_feint() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in 3:
		var moving_held := _holding()
		moving_held.move_dir = Vector2(1.0, 0.0)
		_advance(ms, moving_held, InputIntent.new())
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO,
			"precondition: hard-rooted while the confirm is held (5-2 AC 11)")
	var releasing := InputIntent.new()
	releasing.move_dir = Vector2(1.0, 0.0)
	_advance(ms, releasing, InputIntent.new())
	assert_ne(ms.p1.hero.velocity, Vector3.ZERO,
		"movement answers ON the release tick — the root ends with the state, and nothing "
		+ "replaces it")
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(a: StringName, r: StringName) -> void: rejections.append([a, r]))
	var rolling := InputIntent.new()
	rolling.pressed[&"roll"] = true
	rolling.held[&"roll"] = true
	_advance(ms, rolling, InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.ROLLING,
		"and an ordinary action is honoured immediately after — no post-feint lockout (AC 4)")
	assert_eq(rejections, [], "...with nothing refused on the way")


# --- AC 7: the initiation gates are untouched -------------------------------------------------

## AC 7: a feint returns the hero to IDLE, and an IDLE hero may cast again — but the S6 gate is
## untouched, so a hero still CHARGING may not. Both directions in one test, because the
## interesting claim is that the feint moved the FIRST one without moving the second.
func test_a_feint_frees_the_next_cast_while_the_charging_gate_stays_shut() -> void:
	var ms := _make_match()
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(
		func(a: StringName, r: StringName) -> void: rejections.append([a, r]))
	# Mid-chargeup, the S6 gate still refuses a second commit — unchanged by this story.
	_advance(ms, _unblockable_intent(1), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]],
		"the S6 gate is untouched: a CHARGING hero cannot initiate a second unblockable (AC 7)")
	assert_eq(ms.p1.discard.size(), 1, "...and only the first card was ever played")
	# Release, then cast again from IDLE: accepted, and paid for a second time.
	_advance(ms, InputIntent.new(), InputIntent.new())
	rejections.clear()
	_advance(ms, _unblockable_intent(1), InputIntent.new())
	assert_eq(rejections, [], "after the feint the hero is IDLE and the next cast is accepted")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "...entering a NEW chargeup")
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA - 2.0 * UNBLOCKABLE_COST,
		"...paid AGAIN, in full: a feint buys no discount on the attack that follows it")


# --- helpers ----------------------------------------------------------------------------------

## Story 6-1 (AC 1): A CONTINUING TICK OF A CHARGEUP — an otherwise-empty intent that keeps mode
## ②'s confirm HELD. A bare `InputIntent.new()` on a charging player's slot is a RELEASE, which is
## the entire subject of this file; every loop here that means "still holding" says so explicitly.
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


func _defense_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.DEFENSE
	i.card_commit = true
	return i


## P2 casts a mode ③ window on whatever colour its hand can actually supply, and the colour is
## RETURNED rather than assumed -- no assertion here may depend on what the seeded shuffle did.
##
## Story 6-6b: this arms the window on ITS OWN TICK, which is now a TIMING statement and not just a
## setup step -- the counter answers only inside the window's short ELIGIBILITY head. A caller that
## needs the window to still be eligible at the attacker's commit has to arm it LATE instead, which
## `test_the_same_fixture_does_counter_a_chargeup_that_is_held_out` does inline (its `press_at`
## arithmetic) rather than through this helper.
func _arm_matching_defense(ms: MatchState) -> Enums.CardColor:
	var slot := _first_occupied(ms.p2)
	assert_true(slot >= 0, "fixture: P2 holds a card to cast")
	var color: Enums.CardColor = _colors()[ms.p2.hand.to_array()[slot]]
	_advance(ms, InputIntent.new(), _defense_intent(slot))
	assert_eq(ms.p2.defense_color, int(color), "fixture: the window carries the colour it cast")
	return color


## P1 casts the hand slot that actually holds `color`, so the charge and the armed window MATCH.
func _cast_unblockable_of_color(ms: MatchState, color: Enums.CardColor) -> void:
	var map := _colors()
	var hand := ms.p1.hand.to_array()
	for i in hand.size():
		if hand[i] != Hand.EMPTY and map.get(hand[i], -1) == color:
			_advance(ms, _unblockable_intent(i), InputIntent.new())
			assert_eq(ms.p1.charge_color, int(color), "fixture: the cast colour became resident")
			return
	assert_true(false, "fixture: P1 holds no card of colour %s" % color)


func _first_occupied(player: PlayerState) -> int:
	var ids := player.hand.to_array()
	for i in ids.size():
		if ids[i] != Hand.EMPTY:
			return i
	return -1


## Cast on slot 0 and hold the confirm for the whole authored window, inside reach throughout.
func _run_chargeup_held(ms: MatchState) -> void:
	_advance(ms, _unblockable_intent(0), InputIntent.new())
	for _t in CHARGEUP_TICKS:
		_push_reach(ms, 0, MatchState.CONTACT_CHARGE_REACH_INSIDE)
		_advance(ms, _holding(), InputIntent.new())


## The runner's every-tick charge-reach push, by hand and through the real seam.
func _push_reach(ms: MatchState, slot: int, kind: int) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	ms.push_contact([slot, TargetingService.HERO_INDEX],
		[1 - slot, TargetingService.HERO_INDEX], player.hero.attack_index, FACT_DIR, kind)


func _collect_hits(ms: MatchState) -> Array:
	var out: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void:
		out.append([a, t, d, hp]))
	return out


func _collect_deflects(ms: MatchState) -> Array:
	var out: Array = []
	ms.deflect_landed.connect(func(a: int, t: int, c: int) -> void: out.append([a, t, c]))
	return out


func _dealt(ms: MatchState, slot: int) -> StringName:
	return ms.p1.hand.to_array()[slot]


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("hold_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = CARD_COST
		out[id] = c
	return out


## ONE COLOUR ACROSS THE WHOLE DECK, and that is a fixture decision with a reason: the colour
## comparison is `5-5`'s subject and is pinned there against a deck that spans colours. What THIS
## file needs from colour is only that an armed window and a charge can be made to MATCH regardless
## of what the deal produced — a monochrome deck makes that a property of the composition instead
## of the seed, which is the same correction `test_unblockable_defense.gd`'s own fixture recorded.
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
	# AC 4 needs movement to be OBSERVABLE, and the resource's own default is 0.0 — a fixture that
	# left it there would have made "fully controllable on the release tick" pass or fail on the
	# authored speed rather than on the root. Measured during this dev pass, not assumed.
	c.move_speed = 4.0
	# Story 6-7 (`6-7/R11`): authored EQUAL TO move_speed -- no call site here presses `&"run"`,
	# so AC 4's "movement is observable on release" assertion holds unchanged.
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
	c.counter_busy_seconds_red = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_blue = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.counter_busy_seconds_green = float(COUNTER_BUSY_TICKS) / TimingWindow.TICK_HZ
	c.attack_recovery_seconds = 0.2
	c.roll_duration_seconds = 0.5
	c.roll_iframe_seconds = 0.2
	c.roll_distance = 3.0
	c.deflect_window_seconds = 0.1
	c.draw_replacement_delay_seconds = float(DRAW_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = UNBLOCKABLE_DAMAGE
	c.defense_stamina_cost = DEFENSE_COST
	return c


func _flags(unblockable_open := true) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.unblockable = unblockable_open
	return f


func _make_match(unblockable_open := true) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags(unblockable_open))
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
