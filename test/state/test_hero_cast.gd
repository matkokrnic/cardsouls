extends TestCase

## Story 6-5c: THE HERO CAST FRAMEWORK AND HONED BOLT, headless.
##
## THE FIXTURE AUTHORS ITS OWN NUMBERS IN-TEST and never loads `data/`, which is the standing
## `BC/R3` isolation every state test in this suite keeps: a tuning edit to `honed_bolt.tres` must
## not move a single assertion here. The ONE test that deliberately breaks that rule is the
## AUTHORING AUDIT at the bottom (AC 21), whose whole job is to read the real authored file -- and it
## is the only one, so a retune touches exactly one test and never the golden.
##
## THE CAST DURATION IS DELIBERATELY NOT THE AUTHORED 0.8 s. `CAST_TICKS` is 30 (0.5 s), a
## NON-DEFAULT value, because AC 3 asks for the strike tick to be pinned "for a non-default authored
## duration" -- at 0.8 s a boundary test could pass against a hard-coded 48 without anyone noticing.
##
## THE BOLT STUN AND THE DEFLECT STUN ARE THE SAME LENGTH HERE, exactly as they are in the shipped
## `.tres` (both 0.4 s). That collision is not an accident of the fixture, it is the reason
## `6-5c/R16` exists: a duration test cannot tell the two apart, so the discriminator has to be a
## fact the bolt's own write sets.

const SEED := 6553
const MAX_HP := 100.0
const MAX_STAMINA := 50.0
const START_MANA := 50.0
const WALK_SPEED := 4.0
const RUN_SPEED := 8.0

## The cast framework's numbers, all NON-DEFAULT so a hard-coded default cannot pass.
const CAST_TICKS := 30           # 0.5 s
const BOLT_DAMAGE := 4.0
const STUN_TICKS := 24           # 0.4 s -- the SAME length as the deflect stun below, by design
const ROOT_TICKS := 150          # 2.5 s
const KNOCKDOWN_TICKS := 150     # 2.5 s -- so STUN_TICKS is comfortably "ordinary"
const DEFLECT_STUN_TICKS := 24   # 0.4 s -- the collision `6-5c/R10` names
const GET_UP_IFRAME_TICKS := 60

const ROLL_IFRAME_TICKS := 18
const ROLL_TICKS := 30
const ROLL_COST := 10.0
const RUN_DRAIN_PER_SECOND := 6.0

const CARD_COST := 1.0
const LONG := 100000

const ID_BOLT := &"hc_bolt"
const ID_BUFF := &"hc_buff"
const ID_DEFERRED := &"hc_deferred"
const DECK: Array[StringName] = [ID_BOLT, ID_BOLT, ID_BOLT, ID_BUFF, ID_DEFERRED]

## NO SLOT CONSTANTS: the deal shuffles, so a slot is resolved from the live hand by
## `_cast_intent()` below. See that helper for why a hard-coded slot would be a luck-based test.


# ----------------------------------------------------------------- cast framework (AC 1-3, 6, 7)

## AC 1: the effect applies at the END of the cast, on a single strike tick -- NOT at the press.
## Both halves are asserted, because "applies late" and "applies at all" are different claims and a
## broken framework can satisfy either alone.
func test_a_cast_applies_at_the_strike_tick_and_not_at_the_press() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "the press itself applies NOTHING (AC 1)")
	assert_true(ms.p1.is_casting(), "...it starts a cast on the caster instead")
	_idle(ms, CAST_TICKS - 1)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "still nothing one tick before the strike")
	_idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "the bolt lands on the strike tick")
	assert_false(ms.p1.is_casting(), "...and the cast is over")


## AC 3: the strike tick is T + N for the AUTHORED N, pinned at N-1, N and N+1. The duration is
## non-default (see the header), so this cannot pass against a hard-coded 0.8 s.
func test_the_strike_tick_is_the_authored_duration_and_no_other_tick() -> void:
	for probe: int in [CAST_TICKS - 1, CAST_TICKS, CAST_TICKS + 1]:
		var ms := _make_match()
		_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
		_idle(ms, probe)
		var landed := ms.p2.hero.get_hp() < MAX_HP
		assert_eq(landed, probe >= CAST_TICKS,
			"a cast pressed on tick T with duration %d strikes on T+%d and on no earlier tick "
			% [CAST_TICKS, CAST_TICKS]
			+ "(probe T+%d: landed=%s)" % [probe, landed])


## AC 1: the duration is DATA. A `.tres` retune changes the timing with no code edit, which is
## asserted by retuning the in-test effect and measuring the new strike tick.
func test_a_retuned_cast_duration_moves_the_strike_with_no_code_edit() -> void:
	var retuned := 12
	var ms := _make_match(null, float(retuned) / 60.0)
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, retuned - 1)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "nothing at the retuned duration minus one")
	_idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "the bolt lands at the RETUNED tick")


## AC 2: buffs and every existing effect stay INSTANT. The buff applies on its own press tick and
## starts no cast -- the property that makes the framework additive rather than a retiming of
## everything.
func test_a_buff_stays_instant_and_starts_no_cast() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BUFF), InputIntent.new())
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_BLOODLUST),
		"the buff applied on its own press tick (AC 2)")
	assert_false(ms.p1.is_casting(), "...and started no cast")


## AC 2, THE SHARP HALF: the 0.8 s default is read ONLY for a cast-classified effect. Authoring a
## cast duration onto a BUFF changes nothing at all -- which is what makes the live (non-neutral)
## default safe. Proven by authoring an absurd duration and measuring bit-identical behaviour.
func test_a_non_cast_effect_never_reads_the_cast_duration() -> void:
	var quiet := _make_match()
	var loud := _make_match(null, 0.0, true, 999.0)
	_advance(quiet, _cast_intent(quiet, ID_BUFF), InputIntent.new())
	_advance(loud, _cast_intent(loud, ID_BUFF), InputIntent.new())
	assert_eq(loud.p1.is_rule_active(PlayerState.RULE_BLOODLUST),
		quiet.p1.is_rule_active(PlayerState.RULE_BLOODLUST),
		"a 999 s cast duration on a BUFF changes nothing -- the field is read only for a cast (AC 2)")
	assert_false(loud.p1.is_casting(), "...and still starts no cast")
	assert_eq(loud.p1.to_snapshot(), quiet.p1.to_snapshot(),
		"...the whole per-player snapshot is bit-identical, which is the strongest form of AC 2")


## AC 4: payment is the ordinary Mode 1 sequence AT THE PRESS -- mana spent, card out of the hand
## into the discard, replacement owed. AC 7 / `6-5c/R17`: the resolved-card record and
## `card_cast_resolved` follow the PRESS too, and the strike writes no second record.
func test_the_press_pays_the_ordinary_sequence_and_the_strike_writes_no_second_record() -> void:
	var ms := _make_match()
	var resolved: Array = []
	ms.card_cast_resolved.connect(func(slot: int, id: StringName, mode: int) -> void:
		resolved.append([slot, id, mode]))
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	assert_eq(ms.p1.mana.get_current(), START_MANA - CARD_COST, "mana is spent AT THE PRESS (AC 4)")
	assert_eq(ms.p1.discard.size(), 1, "...the card is in the discard at the press")
	assert_eq(ms.p1.pending_draw_owed.size(), 1, "...and the replacement is owed at the press")
	assert_eq(ms.p1.last_resolved_card_id, String(ID_BOLT),
		"...and the resolved-card record is written at the press (`6-5c/R17`)")
	assert_eq(resolved.size(), 1, "...with exactly one `card_cast_resolved`")
	_idle(ms, CAST_TICKS)
	assert_eq(resolved.size(), 1,
		"the STRIKE writes NO second record and emits no second signal (AC 7, `6-5c/R17`)")


## AC 6: with the spells layer CLOSED the card still resolves -- spent, discarded, replacement owed
## -- starts NO cast and applies nothing. The standing closed-layer degrade, reached through
## `starts_cast()` rather than a second check at the seat.
func test_a_closed_spells_layer_resolves_the_card_and_starts_no_cast() -> void:
	var closed := _flags()
	closed.spells = false
	var ms := _make_match(closed)
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	assert_eq(ms.p1.mana.get_current(), START_MANA - CARD_COST, "the card still RESOLVES (AC 6)")
	assert_eq(ms.p1.discard.size(), 1, "...and is still discarded")
	assert_false(ms.p1.is_casting(), "...but NO cast starts")
	_idle(ms, CAST_TICKS + 5)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "...and nothing ever strikes")


# --------------------------------------------------------------------------- interrupts (AC 5)

## AC 5 / `6-5c/R3`: ANY stun interrupts, and the cast is LOST -- nothing applies, and neither the
## mana nor the card is refunded. Driven with a DEFLECT stun, which is the cheapest of the three
## stuns to produce and is a different one from the bolt's own.
func test_a_stun_interrupts_the_cast_and_refunds_nothing() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	var mana_after_press := ms.p1.mana.get_current()
	var discard_after_press := ms.p1.discard.size()
	_idle(ms, 5)
	ms.p1.hero.start_stun(DEFLECT_STUN_TICKS, false)
	ms.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(ms, 1)
	assert_false(ms.p1.is_casting(), "a stun ENDS the cast on the tick it lands (AC 5)")
	_idle(ms, CAST_TICKS + 5)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "...nothing ever strikes")
	assert_eq(ms.p1.mana.get_current(), mana_after_press, "...the mana is NOT refunded (`6-5c/R3`)")
	assert_eq(ms.p1.discard.size(), discard_after_press, "...and the card is NOT returned")
	assert_eq(ms.p1.pending_draw_owed.size(), 1, "...the replacement is still owed")


## AC 5: DAMAGE ALONE never interrupts, including an ordinary melee hit. This is the other half of
## the interrupt rule and the one an over-eager implementation gets wrong.
func test_an_ordinary_hit_never_interrupts_a_cast() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, 5)
	ms.p1.hero.take_damage(10.0)
	ms.drain_signals()
	_idle(ms, 1)
	assert_true(ms.p1.is_casting(), "damage alone leaves the cast running (AC 5)")
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "...and it strikes on schedule")


## AC 5, `6-5c/R7`: the KNOCKDOWN of an unanswered unblockable cancels a cast, because a knockdown
## IS a stun. Written against the knockdown-length stun the landing seat produces rather than by
## driving a whole unblockable, so the test pins the RULE and not one route to it.
func test_a_knockdown_length_stun_cancels_a_cast() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, 5)
	ms.p1.hero.start_stun(KNOCKDOWN_TICKS, false)
	ms.p1.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(ms, 1)
	assert_false(ms.p1.is_casting(), "a knockdown cancels the cast (`6-5c/R7`)")
	_idle(ms, CAST_TICKS + 5)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "...and no bolt ever lands")


## AC 5: a caster killed mid-cast never strikes, read off HP rather than `DEAD` -- the
## `_apply_lifesteal` N8 argument, because `DEAD` is not written until step 8.
func test_a_caster_killed_mid_cast_never_strikes() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, 5)
	ms.p1.hero.take_damage(MAX_HP)
	ms.drain_signals()
	_idle(ms, 1)
	assert_false(ms.p1.is_casting(), "a dead caster's cast ends (AC 5)")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "...and never strikes")


# ------------------------------------------------------------------------- commitment (AC 8, 9)

## AC 8: the caster DOES NOT MOVE AT ALL, at any tuning -- a literal zero, asserted with full
## movement input held and the run key down.
func test_the_caster_does_not_move_at_all_during_the_cast() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	for _t in 5:
		_advance(ms, _move_and_run(), InputIntent.new())
		assert_eq(ms.p1.hero.velocity, Vector3.ZERO,
			"the caster is hard-rooted for the whole cast (AC 8)")


## AC 8: attack, roll and block presses are DROPPED, and dropped SILENTLY -- no `action_rejected`,
## the get-up / counter register. The card seat announces instead; that is the test below.
func test_the_casters_action_presses_are_dropped_silently() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	var rejections: Array = []
	ms.p1.hero.action_rejected.connect(func(a: StringName, r: StringName) -> void:
		rejections.append([a, r]))
	for action: StringName in [&"attack", &"roll", &"block"]:
		_advance(ms, _press(action), InputIntent.new())
		assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
			"a '%s' press during a cast changes no state (AC 8)" % action)
	assert_eq(rejections.size(), 0,
		"...and produces NO rejection cue at all -- the step-3 lock drops silently (AC 8)")
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA, "...and spends no stamina")


## AC 8, `6-5c/R6`/`R15`: NO card of ANY mode during the caster's own cast -- another cast, a buff,
## an unblockable initiation and the COLOUR COUNTER alike -- and each is refused with an ANNOUNCED
## reason. The counter arm is the clause `R15` exists to make unmissable.
func test_the_caster_cannot_play_any_card_including_the_colour_counter() -> void:
	for mode: int in [Enums.ModeKind.BASIC, Enums.ModeKind.UNBLOCKABLE, Enums.ModeKind.DEFENSE,
			Enums.ModeKind.PITCH]:
		var ms := _make_match()
		_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
		var mana_before := ms.p1.mana.get_current()
		var discard_before := ms.p1.discard.size()
		var rejections: Array = []
		ms.p1.hero.action_rejected.connect(func(a: StringName, r: StringName) -> void:
			rejections.append([a, r]))
		var press := _cast_intent(ms, ID_BUFF)
		press.card_mode = mode
		_advance(ms, press, InputIntent.new())
		assert_eq(rejections, [[&"card_cast", MatchState.REASON_CASTING]],
			"mode %d is refused with an ANNOUNCED reason during a cast (`6-5c/R6`)" % mode)
		assert_eq(ms.p1.mana.get_current(), mana_before, "...and nothing is spent")
		assert_eq(ms.p1.discard.size(), discard_before, "...and no card leaves the hand")
		assert_true(ms.p1.is_casting(), "...and the cast is NOT cancelled by the press (AC 8)")


## AC 9: nothing is buffered. A press dropped during the cast is not replayed when the cast ends --
## the tick after the strike the hero is IDLE, not swinging.
func test_a_press_dropped_during_the_cast_is_never_replayed() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	for _t in CAST_TICKS:
		_advance(ms, _press(&"attack"), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "the cast struck on schedule")
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"no dropped press is replayed when the cast ends (AC 9)")


## Review fix M2 / `6-5c/R4` (`5-2/R17`, "casting drops the block"): STARTING A CAST DROPS THE CASTER OUT
## OF BLOCKING ON THE SAME TICK, mode 3's pattern. Without the write, a block held into the press kept its
## BLOCKING arm (the step-3 cast lock sits BELOW the `match action_state` dispatch) and its mitigation for
## the whole cast. Block AND the card are pressed on the SAME tick, and the block stays held throughout.
##
## NON-VACUITY: the CONTROL is the identical block and identical contact with NO cast, and it IS mitigated
## (x0.25), so the full-damage reading below is the cast's doing and not the fixture's facing or arc.
func test_a_held_block_does_not_survive_the_start_of_a_cast() -> void:
	# CONTROL: block held, P2's swing (pressed on tick 1) lands at tick 6 -- mitigated.
	var control := _make_match()
	_advance(control, _press(&"block"), _press(&"attack"))
	assert_eq(control.p1.hero.action_state, HeroState.ActionState.BLOCKING, "control: the block engaged")
	for t in range(2, 8):
		if t == 6:
			control.push_contact([1, -1], [0, -1], 0, Vector2.DOWN, MatchState.CONTACT_STRIKE)
		_advance(control, _held_block(), InputIntent.new())
	var blocked_damage := MAX_HP - control.p1.hero.get_hp()
	assert_true(blocked_damage > 0.0, "control: the contact landed")

	# THE CAST: block and card pressed on the SAME tick, block held throughout, the same swing lands.
	var ms := _make_match()
	var press := _cast_intent(ms, ID_BOLT)
	press.pressed[&"block"] = true
	press.held[&"block"] = true
	_advance(ms, press, _press(&"attack"))
	assert_true(ms.p1.is_casting(), "the cast started on the same tick as the block press")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING,
		"the press tick drops the block (`6-5c/R4`)")
	for t in range(2, CAST_TICKS + 1):
		if t == 6:
			ms.push_contact([1, -1], [0, -1], 0, Vector2.DOWN, MatchState.CONTACT_STRIKE)
		_advance(ms, _held_block(), InputIntent.new())
		assert_ne(ms.p1.hero.action_state, HeroState.ActionState.BLOCKING,
			"a block held THROUGH the cast never re-engages (tick %d)" % t)
	assert_true(ms.p1.is_casting(), "...and the hit did not interrupt the cast (AC 5)")
	assert_eq(MAX_HP - ms.p1.hero.get_hp(), blocked_damage / control.balance.block_damage_multiplier,
		"the caster took the FULL damage of a hit during the cast, un-mitigated")


# ------------------------------------------------------------------- the bolt strike (AC 10-13)

## AC 10 / `6-5c/R1`: the bolt hits the ENEMY HERO, and lock-on and a board full of minions are both
## irrelevant. Asserted by locking P1 onto its own minion and putting minions on both boards.
## STORY 6-5d (AC 24/AC 25, `6-5d/R6`) REPLACES THIS TEST'S SUBJECT. It was
## `test_the_bolt_hits_the_enemy_hero_whatever_the_lock_and_the_board` (recorded verbatim so the old pin
## stays greppable), and it asserted `6-5c/R1`'s unaimed bolt: a lock was set and the bolt hit the enemy
## hero anyway, never a minion on either board. `6-5d/R6` SUPERSEDES that ruling -- the bolt targets the
## caster's lock-on target -- so the property is inverted here, at the same seat, with the same fixture
## shape.
##
## WHAT SURVIVES UNCHANGED IS THE CASTER'S OWN SIDE: a bolt still cannot touch the caster's own minion,
## and now for a structural reason rather than an arithmetic one -- a lock only ever addresses the
## opposing side, so no captured address can name the caster's board.
func test_the_bolt_hits_the_locked_target_and_the_opposing_hero_when_unlocked() -> void:
	var ms := _make_match()
	ms.p1.units.add(MAX_HP, 0)
	ms.p2.units.add(MAX_HP, 0)
	# LOCKED ON THE ENEMY MINION: the bolt lands on the MINION, for 4 damage through the funnel, and the
	# enemy HERO is untouched (AC 25's unit arm).
	ms.p1.lock_target_slot = 1
	ms.p1.lock_target_index = 0
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p2.units.hp_snapshot(), [MAX_HP - BOLT_DAMAGE],
		"the bolt hit the LOCKED MINION for its authored damage (AC 25, `6-5d/R8`)")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "...and the enemy hero was untouched")
	assert_eq(ms.p1.units.hp_snapshot(), [MAX_HP], "...and never the caster's own minion")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
		"...and a unit-targeted bolt stuns nobody (AC 25: no stun, no root)")
	# UNLOCKED (6-8): the target is the OPPOSING HERO (`6-5d/R7`) -- the pre-6-5d outcome, reached by the
	# other clause of the same rule.
	var ms2 := _make_match()
	ms2.p2.units.add(MAX_HP, 0)
	ms2.p1.lock_target_slot = PlayerState.UNLOCKED_SLOT
	ms2.p1.lock_target_index = TargetingService.HERO_INDEX
	_advance(ms2, _cast_intent(ms2, ID_BOLT), InputIntent.new())
	_idle(ms2, CAST_TICKS)
	assert_eq(ms2.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE,
		"an UNLOCKED caster's bolt hit the opposing HERO (AC 24, `6-5d/R7`)")
	assert_eq(ms2.p2.units.hp_snapshot(), [MAX_HP],
		"...and passed no damage to the minion standing on that board")


## Review fix M3: THE STEP-6C TWO-PASS SPLIT IS SLOT-SYMMETRIC. Every other test casts from P1, which
## cannot tell a read-then-mutate seat from a fused loop (with one cast in flight the two are identical).
## Two halves: P2 alone casting (the slot-1 mirror, `target_slot = 1 - slot` and the step-3 latch read at
## `_iframe_open_at_step3[target_slot]`), and BOTH casting so the bolts strike on the SAME tick -- where a
## fused loop lets slot 0's stun cancel slot 1's cast before it is considered.
func test_the_strike_seat_is_slot_symmetric() -> void:
	var solo := _make_match()
	_advance(solo, InputIntent.new(), _cast_intent(solo, ID_BOLT, 0, 1))
	assert_true(solo.p2.is_casting(), "P2's cast started")
	_idle(solo, CAST_TICKS)
	assert_eq(solo.p1.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "P2's bolt hit P1 (the slot-1 mirror)")
	assert_eq(solo.p2.hero.get_hp(), MAX_HP, "...and only P1")
	assert_true(solo.p1.hero.stun_is_bolt and solo.p1.root_window.is_running,
		"...stunning and rooting P1 exactly as P1's bolt does P2")
	assert_false(solo.p2.is_casting(), "...and P2's cast is over")

	var both := _make_match()
	var hits: Array = []
	both.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void: hits.append([a, t, d]))
	_advance(both, _cast_intent(both, ID_BOLT, 0, 0), _cast_intent(both, ID_BOLT, 0, 1))
	assert_true(both.p1.is_casting() and both.p2.is_casting(), "both casts started on the same tick")
	_idle(both, CAST_TICKS)
	assert_eq(both.p1.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "a simultaneous exchange: P1 is hit...")
	assert_eq(both.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "...and so is P2 -- slot 0 does not win it")
	assert_true(both.p1.hero.stun_is_bolt and both.p2.hero.stun_is_bolt, "...both bolt-stunned")
	assert_true(both.p1.root_window.is_running and both.p2.root_window.is_running, "...both rooted")
	assert_false(both.p1.is_casting() or both.p2.is_casting(), "...both casts cleared")
	assert_eq(hits, [[0, 1, BOLT_DAMAGE], [1, 0, BOLT_DAMAGE]], "...two hits announced, P1's first")


## Review fix N5 / AC 16(c): a KNOCKDOWN landing on a BOLT-STUNNED and rooted hero proceeds as the
## existing one-way escalation -- the stun becomes knockdown-length, the bolt discriminator is cleared
## (the flag must never outlive the stun that set it) -- and does NOT cut the running root short: the
## root's window only counts down its own tick.
func test_a_knockdown_over_a_bolt_stun_clears_the_discriminator_and_leaves_the_root() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_true(ms.p2.hero.stun_is_bolt and ms.p2.root_window.is_running, "setup: bolt-stunned and rooted")
	var root_before := ms.p2.root_window.remaining_ticks()
	ms.p2.hero.start_stun(KNOCKDOWN_TICKS, false)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(ms, 1)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "the hero is down")
	assert_true(ms.balance_ticks.is_knockdown_stun(ms.p2.hero.stun.duration_ticks()),
		"...at knockdown length")
	assert_false(ms.p2.hero.stun_is_bolt, "...and it is no longer a bolt stun (AC 16c)")
	assert_eq(ms.p2.root_window.remaining_ticks(), root_before - 1,
		"...the root is not cut short: it counted down its own tick and no more")


## Review fix N6: THE 6C-AFTER-6B SEAT ORDER (`6-5c/R7`) is the rule's mechanism, and the rule test above
## pokes a stun on an EARLIER tick, which is green whichever order the two seats are in. Here the
## knockdown package lands at step 6b on the caster's exact STRIKE tick: if 6c ran first the bolt would
## strike, and only then would the knockdown land.
func test_a_knockdown_landing_at_6b_cancels_the_cast_on_its_strike_tick() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS - 1)
	assert_true(ms.p1.is_casting(), "setup: the next tick is the strike tick")
	ms._landing_package_pending[1] = true   # P2's unanswered unblockable, exactly as step 3 would latch it
	_idle(ms, 1)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "the knockdown landed on the caster")
	assert_false(ms.p1.is_casting(), "...cancelling the cast (`6-5c/R7`)")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "...before it could strike")


## Review fix N4: `HeroState.start_stun` is the ONE writer of the stun window. `stun` stays publicly
## reachable, so nothing stops a later site calling `hero.stun.start(n)` and leaving `stun_is_bolt` stale
## -- the failure the field's own docstring calls impossible. A source scan (`3-0d/R20`: a mechanism guard
## where the language offers no access control): exactly one `stun.start(` in `src/`, inside `start_stun`.
func test_start_stun_is_the_only_writer_of_the_stun_window() -> void:
	var hits: Array[String] = []
	_scan_stun_writers("res://src", hits)
	assert_eq(hits, ["res://src/state/hero_state.gd"],
		"exactly one `stun.start(` exists in src/, and it is in hero_state.gd")
	var source := FileAccess.get_file_as_string("res://src/state/hero_state.gd")
	var at := source.find("stun.start(")
	var fn_start := source.find("func start_stun(")
	var fn_end := source.find("\nfunc ", fn_start + 1)
	assert_true(fn_start >= 0 and at > fn_start and (fn_end < 0 or at < fn_end),
		"...and it sits inside `start_stun`, the function that also sets the discriminator")


func _scan_stun_writers(dir_path: String, hits: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	assert_not_null(dir, "%s is readable" % dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan_stun_writers("%s/%s" % [dir_path, sub], hits)
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var path := "%s/%s" % [dir_path, file_name]
		var text := FileAccess.get_file_as_string(path)
		var from := 0
		while true:
			var i := text.find("stun.start(", from)
			if i < 0:
				break
			hits.append(path)
			from = i + 1


## AC 11 / `6-5c/R8`: THE FOUR-CASE DODGE BOUNDARY. A roll from the PREVIOUS tick dodges; a roll
## pressed ON the strike tick does not. Both are read off `_iframe_open_at_step3`, which is captured
## before any press of the tick -- so the same-tick press is not yet i-framed on either seat.
func test_only_the_step3_latch_dodges_the_bolt() -> void:
	# (a) rolled EARLY, i-frames still open on the strike tick -> DODGED.
	var early := _make_match()
	_advance(early, _cast_intent(early, ID_BOLT), InputIntent.new())
	_idle(early, CAST_TICKS - 2)
	_advance(early, InputIntent.new(), _press(&"roll"))
	_idle(early, 1)
	assert_eq(early.p2.hero.get_hp(), MAX_HP, "a roll whose i-frames cover the strike DODGES (AC 11)")
	assert_eq(early.p2.root_window.is_running, false, "...no root either")
	# (b) rolled ON the strike tick -> HIT, on neither seat's reading.
	var same := _make_match()
	_advance(same, _cast_intent(same, ID_BOLT), InputIntent.new())
	_idle(same, CAST_TICKS - 1)
	_advance(same, InputIntent.new(), _press(&"roll"))
	assert_eq(same.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE,
		"a roll pressed ON the strike tick dodges on NEITHER seat (AC 11, the `5-6` AC 7 latch)")
	# (c) rolled far too early -- i-frames long expired -> HIT.
	var late := _make_match()
	_advance(late, _cast_intent(late, ID_BOLT), InputIntent.new())
	_advance(late, InputIntent.new(), _press(&"roll"))
	_idle(late, CAST_TICKS - 1)
	assert_eq(late.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "an expired roll does not dodge (AC 11)")
	# (d) a dodged bolt emits NO hit_landed at all.
	var quiet := _make_match()
	var hits: Array = []
	quiet.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void: hits.append(d))
	_advance(quiet, _cast_intent(quiet, ID_BOLT), InputIntent.new())
	_idle(quiet, CAST_TICKS - 2)
	_advance(quiet, InputIntent.new(), _press(&"roll"))
	_idle(quiet, 1)
	assert_eq(hits, [], "a dodged bolt emits no `hit_landed` (AC 11)")


## AC 11 / `6-5c/R8`: GET-UP i-frames dodge identically -- the reason the bolt must read the step-3
## LATCH and not the bare `HeroState.is_iframe_open()`, which lacks the exit-tick term.
func test_get_up_iframes_dodge_the_bolt_exactly_as_roll_iframes_do() -> void:
	var ms := _make_match()
	# The knockdown is LONGER than the cast, so it is armed FIRST and the cast is pressed late
	# enough that the strike lands on the knockdown's own EXIT tick -- the tick whose step 2 empties
	# the stun and whose step 3 writes IDLE and arms the get-up. Counted exactly: the strike tick is
	# advance number `lead + 1 + CAST_TICKS` after the arming, and that must equal KNOCKDOWN_TICKS.
	var lead := KNOCKDOWN_TICKS - CAST_TICKS - 1
	ms.p2.hero.start_stun(KNOCKDOWN_TICKS, false)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(ms, lead)
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP,
		"a hero getting up when the bolt arrives dodges it (`6-5c/R8`)")
	# MEASURED CORRECTION (6-5c dev pass, mutation M2). This test's first draft claimed this was the
	# case the bare `HeroState.is_iframe_open()` would MISS. THAT IS FALSE AT THIS SEAT, and the
	# mutant proved it: swapping the latch for the live predicate leaves this test GREEN. The reason
	# is seat-specific and worth writing down rather than rediscovering -- the strike runs at STEP 6C,
	# AFTER step 3 has already written IDLE and ARMED `get_up_iframe`, so by the time the bolt reads
	# anything the live predicate is true too. The `_gets_up_this_tick` term is load-bearing for the
	# UNBLOCKABLE rung, which reads at step 3 BEFORE that arm runs; for the bolt it is belt-and-braces.
	#
	# WHAT THE LATCH IS STILL LOAD-BEARING FOR HERE is SEAT SYMMETRY, and that IS mutation-proven:
	# `test_only_the_step3_latch_dodges_the_bolt`'s same-tick-roll case goes RED under exactly that
	# mutant, because a roll pressed at step 3 opens `roll_iframe` before step 6c could read it live.
	# So `6-5c/R8`'s "read the latch, not the predicate" stands on the roll case, not the get-up one.
	assert_true(ms.p2.hero.get_up_iframe.is_running, "...the get-up window really did arm here")
	assert_false(ms.p2.root_window.is_running, "...and a dodged bolt writes no root")


## AC 12: block and deflect neither reduce nor negate, and a deflect neither costs the target
## stamina nor stuns the caster. True BY ABSENCE -- a bolt is not a contact fact -- and asserted so
## a future refactor that routed the bolt through the contact ladder would fail here.
func test_block_and_deflect_neither_reduce_nor_negate_the_bolt() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS - 1)
	_advance(ms, InputIntent.new(), _press(&"block"))
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE,
		"a blocking hero takes the FULL bolt damage -- the block multiplier is not applied (AC 12)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"...and the caster is never stunned by the defender's deflect window (AC 12)")


## AC 13 / `6-5c/R13`: the damage goes through the SHARED FUNNEL. Bloodlust's dealt multiplier
## applies and Vampiric Aura heals the caster from the hp ACTUALLY removed -- the standing rule for
## every later spell, so this is the test a future spell copies.
func test_the_bolt_uses_the_damage_funnel_and_lifesteal() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_BLOODLUST, LONG, 2.0, 2.0)
	ms.p1.start_rule(PlayerState.RULE_VAMPIRIC_AURA, LONG, 0.5, 0.0)
	ms.p1.hero.take_damage(20.0)
	ms.drain_signals()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE * 2.0,
		"Bloodlust DOUBLES the bolt's damage through the funnel (`6-5c/R13`)")
	assert_eq(ms.p1.hero.get_hp(), MAX_HP - 20.0 + BOLT_DAMAGE * 2.0 * 0.5,
		"...and Vampiric Aura heals the caster from the hp actually removed")


## AC 13: the bolt does NOT consume Frostbite -- a melee-only trigger. True by absence
## (`_consume_frostbite` is reached only from the contact ladder) and pinned so it stays true.
func test_the_bolt_does_not_consume_frostbite() -> void:
	var ms := _make_match()
	ms.p1.start_rule(PlayerState.RULE_FROSTBITE_ARMED, LONG, 0.5, 120.0)
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_true(ms.p1.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED),
		"the bolt leaves an armed Frostbite ARMED -- it is a melee-only trigger (AC 13)")
	assert_false(ms.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
		"...and lands no slow")


## AC 13: a LETHAL bolt ends the round on its own tick and writes NO stun and NO root onto a hero
## that just died.
func test_a_lethal_bolt_ends_the_round_and_leaves_no_stun_or_root_on_the_corpse() -> void:
	var ms := _make_match()
	ms.p2.hero.take_damage(MAX_HP - BOLT_DAMAGE)
	ms.drain_signals()
	var ended: Array = []
	ms.round_ended.connect(func(loser: int) -> void: ended.append(loser))
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ended, [1], "a lethal bolt ends the round on its OWN tick (AC 13)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.DEAD, "...the target is DEAD")
	assert_false(ms.p2.root_window.is_running, "...with NO root written onto the corpse (AC 13)")
	assert_false(ms.p2.hero.stun_is_bolt, "...and no bolt stun either")


# ------------------------------------------------------------ stun, stacking (AC 14, 15, 16, 19)

## AC 14: the stun interrupts whatever the target is doing. Three subjects in one test because the
## rule is one rule: a SWING (whose orphaned hitbox stops gathering by construction), a BLOCK, and
## an unblockable CHARGEUP (abandoned exactly as a knockdown abandons it).
func test_the_bolt_stun_interrupts_a_swing_a_block_and_a_chargeup() -> void:
	var swinging := _make_match()
	_advance(swinging, _cast_intent(swinging, ID_BOLT), InputIntent.new())
	_idle(swinging, CAST_TICKS - 1)
	_advance(swinging, InputIntent.new(), _press(&"attack"))
	assert_eq(swinging.p2.hero.action_state, HeroState.ActionState.STUNNED,
		"the bolt stun interrupts a swing (AC 14)")
	assert_false(swinging.p2.hero.is_hitbox_active(),
		"...and the orphaned hitbox stops gathering facts by construction")

	var blocking := _make_match()
	_advance(blocking, _cast_intent(blocking, ID_BOLT), InputIntent.new())
	_idle(blocking, CAST_TICKS - 1)
	_advance(blocking, InputIntent.new(), _press(&"block"))
	assert_eq(blocking.p2.hero.action_state, HeroState.ActionState.STUNNED,
		"the bolt stun drops a block (AC 14)")

	var charging := _make_match()
	_advance(charging, _cast_intent(charging, ID_BOLT), InputIntent.new())
	_idle(charging, CAST_TICKS - 1)
	charging.p2.hero.set_action_state(HeroState.ActionState.CHARGING)
	charging.p2.charge_window.start(LONG)
	charging.p2.landing_window.start(LONG)
	charging.p2.charge_color = Enums.CardColor.RED
	_idle(charging, 1)
	assert_eq(charging.p2.hero.action_state, HeroState.ActionState.STUNNED,
		"the bolt stun abandons an unblockable chargeup (AC 14)")
	assert_false(charging.p2.charge_window.is_running, "...tearing the chargeup down")
	assert_false(charging.p2.landing_window.is_running, "...and its landing window")
	assert_eq(charging.p2.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "...and its colour")


## AC 15: the bolt stun is NOT a knockdown -- it opens no get-up i-frames and is classified
## ORDINARY by the duration classifier, which only holds because the authored `stun_seconds` stays
## strictly below the authored knockdown (enforced by the authoring audit below).
func test_the_bolt_stun_is_not_a_knockdown() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_false(ms.balance_ticks.is_knockdown_stun(ms.p2.hero.stun.duration_ticks()),
		"the bolt stun classifies ORDINARY, never a knockdown (AC 15)")
	_idle(ms, STUN_TICKS)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
		"...it exits to IDLE by natural expiry, like every other stun (AC 14)")
	assert_false(ms.p2.hero.get_up_iframe.is_running, "...and opens NO get-up i-frames (AC 15)")


## `6-5c/R16`: the DISCRIMINATOR. A bolt stun sets it, a deflect stun does not, and it is cleared at
## the stun's exit -- the three facts presentation depends on, none of which a duration test could
## establish (both stuns are 0.4 s here, exactly as in the shipped `.tres`).
func test_the_bolt_stun_discriminator_is_set_cleared_and_never_set_by_a_deflect_stun() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_true(ms.p2.hero.stun_is_bolt, "a bolt stun sets the discriminator (`6-5c/R16`)")
	assert_eq(ms.p2.hero.stun.duration_ticks(), DEFLECT_STUN_TICKS,
		"...at the SAME duration a deflect stun has, which is why a duration test cannot work")
	_idle(ms, STUN_TICKS)
	assert_false(ms.p2.hero.stun_is_bolt, "...and the stun's exit clears it")

	var deflected := _make_match()
	deflected.p2.hero.start_stun(DEFLECT_STUN_TICKS, false)
	deflected.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	assert_false(deflected.p2.hero.stun_is_bolt, "a deflect stun never sets it")


## `6-5c/R16`'s NAMED COUNTER-EXAMPLE, which is why "stun running AND root armed" was refused: a
## ROOTED hero may still swing, be deflected, and enter an ORDINARY stun while its root runs. That
## hero must read `stunned`, not `dizzy`.
func test_a_rooted_hero_in_a_deflect_stun_is_not_read_as_bolt_stunned() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS + STUN_TICKS)
	assert_true(ms.p2.root_window.is_running, "the target is rooted with its bolt stun over")
	ms.p2.hero.start_stun(DEFLECT_STUN_TICKS, false)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	assert_true(ms.p2.root_window.is_running, "...a deflect stun lands while the root still runs")
	assert_false(ms.p2.hero.stun_is_bolt,
		"...and it reads ORDINARY, not a bolt stun (`6-5c/R16`'s counter-example)")


## AC 16(a) / `6-5c/R9`: a bolt on a KNOCKED-DOWN hero deals damage ONLY -- no stun, no root, and
## the running knockdown is neither restarted nor extended (the `R-STUNSTACK` floor rule).
func test_a_bolt_on_a_knocked_down_hero_deals_damage_only() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS - 1)
	ms.p2.hero.start_stun(KNOCKDOWN_TICKS, false)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	var remaining_before := ms.p2.hero.stun.remaining_ticks()
	_idle(ms, 1)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE, "the damage still lands (AC 16a)")
	assert_false(ms.p2.root_window.is_running, "...but NO root is armed (`6-5c/R9`)")
	assert_false(ms.p2.hero.stun_is_bolt, "...and the knockdown is not replaced by a bolt stun")
	assert_true(ms.p2.hero.stun.remaining_ticks() < remaining_before,
		"...the running knockdown counts on, neither restarted nor extended (the floor rule)")


## AC 16(b) / `6-5c/R12`: a bolt on a hero in an ORDINARY (deflect) stun RESTARTS the stun at the
## bolt's full length and the root follows -- the case that is NOT the floor rule.
func test_a_bolt_on_a_deflect_stunned_hero_restarts_the_stun_and_roots() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS - 1)
	ms.p2.hero.start_stun(DEFLECT_STUN_TICKS, false)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	_idle(ms, 1)
	assert_eq(ms.p2.hero.stun.remaining_ticks(), STUN_TICKS,
		"the stun RESTARTS from zero at the bolt's full length (`6-5c/R12`)")
	assert_true(ms.p2.hero.stun_is_bolt, "...it is now a BOLT stun")
	assert_true(ms.p2.root_window.is_running, "...and the root follows")


## AC 19 / `6-5c/R2`: CHOICE A (the default) -- a second bolt during the root stuns again and
## restarts the root IN FULL.
func test_a_second_bolt_during_the_root_restuns_and_restarts_it() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS + STUN_TICKS + 10)
	assert_true(ms.p2.root_window.is_running, "the target is rooted")
	var remaining_before := ms.p2.root_window.remaining_ticks()
	_advance(ms, _cast_intent(ms, ID_BOLT, 1), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE * 2.0, "the second bolt deals its damage")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "...stuns again (choice A)")
	assert_eq(ms.p2.root_window.remaining_ticks(), STUN_TICKS + ROOT_TICKS,
		"...and the root restarts IN FULL, not merely extended (was %d)" % remaining_before)


## AC 19 / `6-5c/R2`: CHOICE B -- the `.tres` switch flipped. The landing deals its damage and
## NEITHER stuns NOR extends the root. Read AT THE LANDING, never at the press.
func test_choice_b_deals_damage_and_neither_stuns_nor_extends_the_root() -> void:
	var ms := _make_match(null, 0.0, false)
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS + STUN_TICKS + 10)
	var remaining_before := ms.p2.root_window.remaining_ticks()
	_advance(ms, _cast_intent(ms, ID_BOLT, 1), InputIntent.new())
	_idle(ms, CAST_TICKS)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - BOLT_DAMAGE * 2.0, "choice B still deals damage (AC 19)")
	assert_ne(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "...but does NOT stun again")
	assert_true(ms.p2.root_window.remaining_ticks() < remaining_before,
		"...and does NOT extend the root -- it keeps counting down")


# --------------------------------------------------------------------------- the root (AC 17, 18)

## AC 17: the root starts when the STUN ENDS and lasts the authored seconds. Measured as the root's
## remaining count on the tick the stun expires, which is exactly `root_seconds` in ticks.
func test_the_root_starts_when_the_stun_ends_and_lasts_the_authored_seconds() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS + STUN_TICKS)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "the stun has just ended")
	assert_eq(ms.p2.root_window.remaining_ticks(), ROOT_TICKS,
		"...and the root has exactly `root_seconds` left at that instant (AC 17)")
	_idle(ms, ROOT_TICKS)
	assert_false(ms.p2.root_window.is_running, "...and it ends by natural expiry")


## AC 17: `root_blocks_run` -- a held run key gives WALK pace, drains no run stamina and touches no
## gait latch. All three are asserted, because they are three separate consequences of one clause.
func test_the_root_blocks_run_at_walk_pace_with_no_drain_and_no_latch() -> void:
	var ms := _rooted_match()
	var stamina_before := ms.p2.stamina.get_current()
	_advance(ms, InputIntent.new(), _move_and_run())
	assert_eq(ms.p2.hero.velocity.length(), WALK_SPEED,
		"a held run key gives WALK pace while rooted (AC 17)")
	assert_eq(ms.p2.stamina.get_current(), stamina_before, "...drains no run stamina")
	assert_false(ms.p2.hero.run_locked_out, "...and touches no gait latch")


## AC 17 / `6-5c/R14`: `root_blocks_roll` -- the press is refused with NO state change, NO stamina
## spent and NOTHING announced, and a lower-priority same-tick press is still considered (the 1-4
## fall-through, which is what makes the refusal a `return false` rather than a `return`).
func test_the_root_refuses_the_roll_silently_and_falls_through() -> void:
	var ms := _rooted_match()
	var rejections: Array = []
	ms.p2.hero.action_rejected.connect(func(a: StringName, r: StringName) -> void:
		rejections.append([a, r]))
	var stamina_before := ms.p2.stamina.get_current()
	var both := _press(&"roll")
	both.pressed[&"block"] = true
	_advance(ms, InputIntent.new(), both)
	assert_ne(ms.p2.hero.action_state, HeroState.ActionState.ROLLING,
		"a roll press while rooted changes no state (AC 17)")
	assert_eq(ms.p2.stamina.get_current(), stamina_before, "...spends NO stamina")
	assert_eq(rejections, [], "...and announces NOTHING -- no cue, no `action_rejected` (`6-5c/R14`)")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING,
		"...and the lower-priority same-tick BLOCK still fires (the 1-4 fall-through)")


## AC 17: THE TWO SWITCHES ARE INDEPENDENT. Each is flipped alone and only its own consequence
## moves -- which a single "is rooted" test would silently collapse.
func test_the_two_root_switches_are_independent() -> void:
	var run_only := _rooted_match(true, false)
	_advance(run_only, InputIntent.new(), _move_and_run())
	assert_eq(run_only.p2.hero.velocity.length(), WALK_SPEED, "blocks_run alone still walks")
	var roll_only := _rooted_match(false, true)
	_advance(roll_only, InputIntent.new(), _move_and_run())
	assert_eq(roll_only.p2.hero.velocity.length(), RUN_SPEED,
		"with blocks_run FALSE the rooted hero still RUNS (AC 17: the switches are independent)")
	var rolls := _rooted_match(true, false)
	_advance(rolls, InputIntent.new(), _press(&"roll"))
	assert_eq(rolls.p2.hero.action_state, HeroState.ActionState.ROLLING,
		"with blocks_roll FALSE the rooted hero still ROLLS (AC 17)")


## AC 18: the root removes EXACTLY run and roll. Walk, block, attack and card play all still work,
## which is the half of the rule an over-broad root would break.
func test_the_root_removes_exactly_run_and_roll() -> void:
	var walking := _rooted_match()
	_advance(walking, InputIntent.new(), _move_only())
	assert_eq(walking.p2.hero.velocity.length(), WALK_SPEED, "a rooted hero still WALKS (AC 18)")
	var blocking := _rooted_match()
	_advance(blocking, InputIntent.new(), _press(&"block"))
	assert_eq(blocking.p2.hero.action_state, HeroState.ActionState.BLOCKING, "...still BLOCKS")
	var attacking := _rooted_match()
	_advance(attacking, InputIntent.new(), _press(&"attack"))
	assert_eq(attacking.p2.hero.action_state, HeroState.ActionState.ATTACKING, "...still ATTACKS")
	var casting := _rooted_match()
	var mana_before := casting.p2.mana.get_current()
	_advance(casting, InputIntent.new(), _cast_intent(casting, ID_BUFF, 0, 1))
	assert_eq(casting.p2.mana.get_current(), mana_before - CARD_COST,
		"...and still PLAYS CARDS (AC 18)")


# ------------------------------------------------------------------ reset, freeze, debug (AC 24)

## AC 24: the debug reset clears BOTH the cast and the root -- the tenth and eleventh named
## exceptions to the reset's "nothing else" contract, for the traced reason `5-3`/`5-5`/`5-6` gave
## their own windows: step 1b freezes the clock while leaving the window armed.
func test_the_debug_reset_clears_the_cast_and_the_root() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS + STUN_TICKS + 5)
	assert_true(ms.p2.root_window.is_running, "a root is running")
	_advance(ms, _cast_intent(ms, ID_BOLT, 1), InputIntent.new())
	assert_true(ms.p1.is_casting(), "...and a cast is in flight")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_false(ms.p1.is_casting(), "the debug reset clears the cast (AC 24)")
	assert_false(ms.p2.root_window.is_running, "...and the root")
	assert_false(ms.p2.root_blocks_run, "...and both switches with it")
	assert_false(ms.p2.root_blocks_roll, "...so a stopped root can hash no stale switch")


## AC 24: the ROUND-OVER FREEZE stops both countdowns. Step 1b returns before step 2, so nothing
## ticks -- and the round-end clear means nothing is left armed to tick.
func test_round_end_clears_the_cast_and_the_root() -> void:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS + STUN_TICKS + 5)
	_advance(ms, _cast_intent(ms, ID_BOLT, 1), InputIntent.new())
	ms.p1.hero.take_damage(MAX_HP)
	_idle(ms, 1)
	assert_true(ms._round_over, "the round has ended")
	assert_false(ms.p1.is_casting(), "round end clears the cast (AC 18/AC 24)")
	assert_false(ms.p2.root_window.is_running, "...and the root, following `clear_rules`")


## AC 24: the new windows appear in the debug countdown accessor on the stun window's precedent --
## and only while RUNNING, which is what keeps the existing exact-payload assertions green.
func test_the_debug_accessor_lists_the_cast_and_root_windows_only_while_running() -> void:
	var ms := _make_match()
	assert_false(ms.debug_window_ticks_remaining()[0].has(&"cast"),
		"an idle slot lists no cast window (AC 24)")
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	assert_eq(ms.debug_window_ticks_remaining()[0][&"cast"], CAST_TICKS,
		"...a running cast is listed with its remaining ticks")
	_idle(ms, CAST_TICKS)
	assert_true(ms.debug_window_ticks_remaining()[1].has(&"root"),
		"...and the struck slot lists its root")


# ------------------------------------------------------------------ authoring audit (AC 20-22)

## AC 21: THE AUTHORING AUDIT -- the ONE test in this file that loads the REAL authored `.tres`.
## Every number the story fixes is asserted against the SPEC, not against the code that reads it.
func test_the_authored_honed_bolt_carries_its_spec_numbers() -> void:
	var bolt := _authored_effect(&"honed_bolt")
	assert_eq(bolt.cast_seconds, 0.8, "Honed Bolt casts for 0.8 s (`6-5c/R4`)")
	assert_eq(bolt.damage_amount, 4.0, "...deals 4 damage (deck-1-spec.md:35 T[4])")
	assert_eq(bolt.stun_seconds, 0.4, "...stuns for 0.4 s (T[0.4])")
	assert_eq(bolt.root_seconds, 2.5, "...roots for 2.5 s afterwards (T[2.5])")
	assert_true(bolt.root_blocks_run, "...the root blocks run (T[true])")
	assert_true(bolt.root_blocks_roll, "...and blocks roll (T[true])")
	assert_true(bolt.repeat_landing_restuns, "...and a repeat landing re-stuns: choice A (`6-5c/R2`)")
	assert_true(bolt.stun_seconds >= 0.0, "the stun duration is non-negative (AC 21)")
	assert_true(bolt.root_seconds >= 0.0, "...and so is the root")
	assert_true(bolt.cast_seconds > 0.0, "...and a CAST effect's duration is strictly positive")


## STORY 6-5d (AC 3): THE FIREBALL AUTHORING AUDIT, seated beside the bolt's for its reason verbatim --
## the numbers are asserted against the SPEC and the ruling, never against the code that reads them.
func test_the_authored_fireball_carries_its_ruled_numbers() -> void:
	var fb := _authored_effect(&"fireball")
	assert_eq(fb.damage_per_mana, 1.5, "Fireball deals 1.5 damage per mana spent (`6-5d/R2`)")
	assert_eq(fb.mana_cap, 10.0, "...capped at 10 mana per staging (`6-5d/R1`)")
	assert_true(fb.cast_seconds > 0.0, "...after a cast of strictly positive length (AC 11)")
	# THE FLIGHT PROFILE STARTS FROM THE TOTEM SHOT'S (AC 3), which is what makes "the totem-shot feel"
	# an authoring fact rather than a shared resource.
	assert_eq(fb.launch_speed, 8.0, "...launching at the totem shot's 8 m/s (AC 3)")
	assert_eq(fb.homing_turn_rate_degrees_per_second, 120.0, "...homing at 120 deg/s (AC 3)")
	assert_eq(fb.acceleration_delay_seconds, 0.4, "...accelerating after 0.4 s (AC 3)")
	assert_eq(fb.acceleration_per_second_squared, 12.0, "...at 12 m/s^2 (AC 3)")
	assert_eq(fb.max_speed, 20.0, "...to a ceiling of 20 m/s (AC 3)")
	assert_eq(fb.travel_budget, 60.0, "...and expiring at 60 m (AC 3/AC 23)")


## AC 15 / AC 21: THE AUTHORING INVARIANT THE DURATION CLASSIFIER DEPENDS ON. `stun_seconds` must
## stay strictly BELOW the authored `knockdown_stun_seconds`, or `is_knockdown_stun` would read a
## bolt stun as a knockdown -- opening get-up i-frames and playing the `knockdown` pose. This is the
## one place the authored effect and the authored balance are compared, and it is a REAL-FILE check
## on both sides deliberately: the danger is a retune of either one.
func test_the_authored_bolt_stun_stays_below_the_authored_knockdown() -> void:
	var bolt := _authored_effect(&"honed_bolt")
	var config: BalanceConfig = load("res://data/balance/balance_config.tres")
	assert_not_null(config, "the authored balance config loads")
	assert_true(bolt.stun_seconds < config.knockdown_stun_seconds,
		"the authored bolt stun (%s s) stays STRICTLY below the authored knockdown (%s s) -- "
		% [bolt.stun_seconds, config.knockdown_stun_seconds]
		+ "`BalanceTicks.is_knockdown_stun` classifies BY DURATION, so a retune that crossed this "
		+ "line would silently turn every bolt into a knockdown (AC 15)")


## AC 21 / AC 22: `honed_bolt` has LEFT the deferred table and now resolves to a real outcome; the
## other four rows are untouched and still resolve as the named no-op. AC 22: nothing here records a
## per-cast rollback shape -- 6-5f owns undo.
func test_honed_bolt_left_the_deferred_table_and_the_others_did_not() -> void:
	assert_eq(CardEffectResolver.owner_story_for(&"honed_bolt"), &"",
		"`honed_bolt` has left DEFERRED_EFFECT_OWNERS (AC 21)")
	assert_eq(CardEffectResolver.outcome(_effect(&"honed_bolt"), _flags()),
		CardEffectResolver.OUTCOME_HONED_BOLT, "...and resolves to a real outcome")
	# STORY 6-5e (AC 43): THREE OF THE FOUR HAVE NOW LEFT TOO -- `rocksling`, `boom` and `corpse_bomb` are
	# what 6-5e builds, so this list narrows to the ONE row that is still deferred. The narrowing is the
	# deferred table's mechanism working as designed (a row is retired by the story it names), and the
	# positive half of it is asserted in `test_spell_framework.gd`, which owns the table's census.
	for id: StringName in [&"counterspell"]:
		assert_ne(CardEffectResolver.owner_story_for(id), &"", "%s stays deferred (AC 21)" % id)
		assert_eq(CardEffectResolver.outcome(_effect(id), _flags()),
			CardEffectResolver.REASON_DECK1_NOT_YET_RESOLVED,
			"...and its no-op behaviour is unchanged")


## AC 1: THE FRAMEWORK NAMES NO CARD. `MatchState` never mentions `honed_bolt`; the id lives only in
## the resolver, which is the one file whose job is matching ids to meaning (D6). A source scan,
## because this is exactly the property a later cast effect's author would break by reaching for a
## literal at the seat.
func test_the_cast_framework_names_no_card_in_match_state() -> void:
	var source := FileAccess.get_file_as_string("res://src/state/match_state.gd")
	assert_ne(source, "", "match_state.gd was read")
	for id: String in ["honed_bolt", "rocksling", "corpse_bomb"]:
		assert_false(source.contains('&"%s"' % id),
			"`match_state.gd` names no card id -- '%s' belongs to the resolver alone (AC 1, D6)" % id)


## STORY 6-5d: THIS PIN IS DELIBERATELY REVERSED, AND THE REVERSAL IS THE STORY.
##
## It was `test_no_authored_pitch_effect_is_a_cast_id` (recorded verbatim so the old pin stays greppable),
## and it asserted the disjointness `_resolve_basic_cast`'s comment relied on INSTEAD of a guard: no card's
## PITCH effect was a cast id, so a pitch ACTIVATION could never reach a cast outcome through an unforked
## apply seat. FIREBALL IS EXACTLY THAT CASE -- Bloodhound Step's pitch effect and a `CAST_OUTCOMES` row --
## so the property this pinned is the property 6-5d ships the negation of.
##
## WHAT REPLACES IT IS NOT NOTHING, and that matters: the old pin's real job was making the unforked seat
## SAFE, so its successor has to assert what makes the FORKED seat safe instead. Two halves:
##   (1) the authored library is CHECKED and the castable pitch effects are exactly the expected set, so a
##       tenth card quietly making its pitch castable is still a failure here rather than a surprise; and
##   (2) `_resolve_pitch_activate` REALLY FORKS -- it asks `starts_cast` -- so a castable pitch effect
##       cannot reach `_apply_card_effect` and apply nothing, which is the silent failure the old pin
##       existed to prevent.
func test_the_authored_castable_pitch_effects_are_exactly_the_forked_set() -> void:
	var dir := DirAccess.open("res://data/cards")
	assert_not_null(dir, "the authored card library is readable")
	var checked := 0
	var castable: Array[String] = []
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var card: CardData = load("res://data/cards/%s" % file_name)
		if card == null or card.pitch_effect == null:
			continue
		checked += 1
		if CardEffectResolver.CAST_OUTCOMES.has(card.pitch_effect.effect_id):
			castable.append("%s/%s" % [card.id, card.pitch_effect.effect_id])
	assert_true(checked > 0, "at least one authored pitch effect was checked")
	castable.sort()
	assert_eq(castable, ["bloodhound_step/fireball"],
		"Story 6-5d (AC 1/AC 10): EXACTLY ONE authored pitch effect is a cast id -- Bloodhound Step's "
		+ "Fireball, the first PITCH effect in the project that starts a commitment window. A second "
		+ "one is not forbidden, but it must be added here deliberately, because the pitch apply seat's "
		+ "fork is what makes it resolve at all")
	# (2) THE FORK ITSELF, by source scan, for the reason the old pin was a source-adjacent property too:
	# a castable pitch effect reaching the unforked `_apply_card_effect` would apply NOTHING and spend the
	# orbs -- silently, with every other test still green.
	var source := FileAccess.get_file_as_string("res://src/state/match_state.gd")
	assert_ne(source, "", "match_state.gd was read")
	var activate := source.find("func _resolve_pitch_activate")
	var next_func := source.find("\nfunc ", activate + 1)
	assert_true(activate >= 0 and next_func > activate, "the activation seat was found (non-vacuity)")
	var body := source.substr(activate, next_func - activate)
	assert_true(body.contains("CardEffectResolver.starts_cast("),
		"Story 6-5d (AC 10): `_resolve_pitch_activate` FORKS on `starts_cast` -- without it a castable "
		+ "pitch effect would spend its orbs and apply nothing")


# --- helpers ---------------------------------------------------------------------------------

func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.move_speed = RUN_SPEED
	c.walk_speed = WALK_SPEED
	c.max_stamina = MAX_STAMINA
	c.max_mana = 90.0
	c.deck_size = DECK.size()
	c.hand_size = DECK.size()
	c.draw_replacement_delay_seconds = 60.0
	c.pitch_stage_timer_seconds = 60.0
	c.stamina_regen_per_second = 0.0
	c.stamina_regen_delay_seconds = 1.0
	c.run_stamina_drain_per_second = RUN_DRAIN_PER_SECOND
	c.roll_stamina_cost = ROLL_COST
	c.roll_iframe_seconds = ROLL_IFRAME_TICKS / 60.0
	c.roll_duration_seconds = ROLL_TICKS / 60.0
	c.roll_distance = 3.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 6.0 / 60.0
	c.attack_chain_window_seconds = 5.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 6.0
	c.block_damage_multiplier = 0.25
	c.deflect_stamina_cost = 8.0
	c.deflect_window_seconds = 4.0 / 60.0
	c.block_facing_arc_degrees = 180.0
	c.deflect_stun_seconds = DEFLECT_STUN_TICKS / 60.0
	c.knockdown_stun_seconds = KNOCKDOWN_TICKS / 60.0
	c.get_up_iframe_seconds = GET_UP_IFRAME_TICKS / 60.0
	c.hero_damage_to_unit = 3.0
	c.minion_retarget_interval_seconds = 1000.0
	var kinds: Array[UnitKindProfile] = [
		UnitKindFixture.melee(CardEffectResolver.KIND_MINION, 9.0, 4.0, 2, 3, 4, 2.0),
	]
	c.unit_kinds = kinds
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.melee_mana_generation = true
	f.pitch_zone = true
	f.minions = true
	f.totems = true
	f.spells = true
	return f


## `cast_override` retunes the bolt's cast duration (0.0 = this file's default); `restuns` flips the
## repeat-landing switch to choice B. Both exist so the two `.tres`-driven behaviours can be measured
## without touching `data/`.
func _make_match(flags: FeatureFlags = null, cast_override: float = 0.0,
		restuns: bool = true, buff_cast_seconds: float = 0.0) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(flags if flags != null else _flags())
	ms.inject_deck(DECK)
	ms.inject_card_costs(_costs())
	ms.inject_card_effects(_effects(cast_override, restuns, buff_cast_seconds))
	ms.inject_pitch_costs(_costs())
	ms.inject_pitch_effects(_effects(cast_override, restuns, buff_cast_seconds))
	_idle(ms, 1)   # the step-6 deal
	ms.p1.mana.add(START_MANA)
	ms.p2.mana.add(START_MANA)
	ms.drain_signals()
	return ms


## P2 rooted with its bolt stun already expired, so the root's own behaviour is what is measured
## rather than the stun's.
func _rooted_match(blocks_run: bool = true, blocks_roll: bool = true) -> MatchState:
	var ms := _make_match()
	_advance(ms, _cast_intent(ms, ID_BOLT), InputIntent.new())
	_idle(ms, CAST_TICKS + STUN_TICKS)
	ms.p2.arm_root(ROOT_TICKS, blocks_run, blocks_roll)
	ms.p2.stamina.refill()
	ms.drain_signals()
	return ms


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK:
		var c := CardCastCondition.new()
		c.mana_cost = CARD_COST
		out[id] = c
	return out


func _effects(cast_override: float = 0.0, restuns: bool = true,
		buff_cast_seconds: float = 0.0) -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	var bolt := _effect(&"honed_bolt")
	bolt.cast_seconds = cast_override if cast_override > 0.0 else CAST_TICKS / 60.0
	bolt.damage_amount = BOLT_DAMAGE
	bolt.stun_seconds = STUN_TICKS / 60.0
	bolt.root_seconds = ROOT_TICKS / 60.0
	bolt.root_blocks_run = true
	bolt.root_blocks_roll = true
	bolt.repeat_landing_restuns = restuns
	var buff := _effect(&"bloodlust")
	buff.duration_seconds = 10.0
	buff.damage_dealt_multiplier = 2.0
	buff.damage_taken_multiplier = 2.0
	# AC 2's sharp half: a cast duration authored onto a NON-cast effect must change nothing.
	if buff_cast_seconds > 0.0:
		buff.cast_seconds = buff_cast_seconds
	out[ID_BOLT] = bolt
	out[ID_BUFF] = buff
	out[ID_DEFERRED] = _effect(&"rocksling")
	return out


func _effect(effect_id: StringName) -> CardEffect:
	var e := CardEffect.new()
	e.effect_id = effect_id
	return e


## The REAL authored effect, loaded from `data/effects/` -- used ONLY by the authoring audit.
func _authored_effect(effect_id: StringName) -> CardEffect:
	var effect: CardEffect = load("res://data/effects/%s.tres" % effect_id)
	assert_not_null(effect, "the authored '%s' effect loads" % effect_id)
	return effect


## THE HAND SLOT IS RESOLVED AT RUNTIME, NEVER HARD-CODED, and that is not fussiness: the step-6
## deal SHUFFLES the injected composition through the seeded RNG, so which slot holds which id is a
## property of the seed rather than of `DECK`'s order. A hard-coded slot passes or fails by luck and
## would silently start testing a different card the day the seed or the deck size moved.
##
## `nth` picks the nth copy of `id` in hand order -- the repeat-landing tests need a SECOND bolt, and
## the first one's slot is vacated by its own cast (its replacement is owed against a 60 s delay, so
## it never arrives during a test).
func _cast_intent(ms: MatchState, id: StringName, nth: int = 0, slot_index: int = 0) -> InputIntent:
	var player: PlayerState = ms.p1 if slot_index == 0 else ms.p2
	var hand := player.hand.to_array()
	var seen := 0
	var found := -1
	for index in hand.size():
		if hand[index] != id:
			continue
		if seen == nth:
			found = index
			break
		seen += 1
	assert_true(found >= 0, "the hand holds copy %d of '%s' (hand: %s)" % [nth, id, hand])
	var i := InputIntent.new()
	i.card_slot = found
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	return i


func _press(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.pressed[action] = true
	if action == &"block":
		i.held[action] = true
	return i


func _held_block() -> InputIntent:
	var i := InputIntent.new()
	i.held[&"block"] = true
	return i


func _move_only() -> InputIntent:
	var i := InputIntent.new()
	i.move_dir = Vector2(0.0, 1.0)
	return i


func _move_and_run() -> InputIntent:
	var i := _move_only()
	i.held[&"run"] = true
	return i


func _idle(ms: MatchState, n: int) -> void:
	for _t in n:
		_advance(ms, InputIntent.new(), InputIntent.new())


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
