extends TestCase

## Story 5-5: mode ③ — UNBLOCKABLE DEFENSE, the ANSWER half of the RGB read exchange. The dispatch
## arm and its one state refusal, the window a cast opens, the landing intercept that negates a
## colour match, and the round-boundary clear.
##
## WHY A NEW FILE rather than extending `test_unblockable_initiation.gd` (the story's Open Question
## asks the dev pass to name the choice, and this is the answer): on the
## `test_orbs_economy.gd`/`test_unblockable_initiation.gd` sibling precedent exactly. Leaving both
## older files UNEDITED buys a free regression that costs nothing — `test_unblockable_initiation.gd`
## never casts mode ③, so every landing it asserts still runs with no defense window in play and its
## numbers stay unmoved; `test_orbs_economy.gd`'s grants are likewise all undefended. The cost is one
## duplicated mode-② fixture, which is the cheaper of the two, `5-4`'s own finding applied again.
##
## FIXTURE SHAPE. Every quantity is distinct from every other so an off-by-one lands on a wrong
## number rather than coinciding with a right one: chargeup 6 ticks against a defense window of 20
## (so ONE window comfortably spans TWO consecutive chargeups, which is what AC 11's survival claim
## needs), unblockable cost 2.0 and defense cost 1.0 out of 40 stamina (so a long sequence never runs
## dry and the two spends are never confusable), damage 10 % of 100 hp so repeated landings cannot
## kill, orb grant 2 against a cap of 9 so no assertion here is ever answered by the clamp, and a
## draw delay of 1 tick so the hand refills between casts.
##
## THE COLOURS ALTERNATE BY DECK INDEX (the `5-2` fixture's own device) and every cast helper SELECTS
## its hand slot by READING what was actually dealt. That is what makes "a RED defense answers a RED
## charge and neither of the other two" a claim about the colour comparison rather than about which
## card the seeded shuffle happened to put in slot 0.
##
## THE REACH FACT IS PUSHED BY HAND through the real `push_contact` seam, exactly as `5-2`'s fixture
## does — these tests drive no runner.

const SEED := 5555
## DECK_SIZE == HAND_SIZE IS THE WHOLE POINT, and it is a MEASURED correction rather than a style
## choice. A four-card hand dealt off a larger deck is SHUFFLE-DEPENDENT in its colours: the first
## attempt here used twelve cards cycling three colours and the seeded deal handed P2 no GREEN at
## all, so every GREEN row of the blind-spot pin failed on the fixture rather than on the code.
## Dealing the ENTIRE deck makes colour coverage a property of the COMPOSITION instead of the seed —
## two of each colour, always all three in hand, no seed to re-measure if anything upstream changes
## the shuffle. This is the same "measured, not guessed" finding `5-2`'s fixture recorded when a
## single odd-one-out card left its dealt hand monochrome.
const DECK_SIZE := 6
const HAND_SIZE := 6
const MAX_HP := 100.0
const MAX_STAMINA := 40.0
const UNBLOCKABLE_COST := 2.0
const DEFENSE_COST := 1.0
const CHARGEUP_TICKS := 6
const DEFENSE_WINDOW_TICKS := 20
## LONGER THAN ANY TEST HERE RUNS, deliberately: dealing the whole deck (above) leaves the deck
## EMPTY, so a replacement delivery would trigger a RESHUFFLE that folds the discard back into the
## deck — and every "the card is gone" assertion would then be answered by the card coming back.
## Parking the debt beyond every test's horizon keeps the discard observable without weakening any
## claim: AC 7's obligation is that a replacement is OWED and its window in flight, which is asserted
## directly, not that it is delivered (`3-5b` owns delivery and tests it in its own file).
const DRAW_DELAY_TICKS := 600
const UNBLOCKABLE_DAMAGE := 10.0   # 10 % of 100.0 max hp
const REACH := 8.0
const ORB_GRANT := 2
const MAX_ORBS := 9

## The planar TARGET -> ATTACKER direction the runner would compute (the 1-8 convention).
const FACT_DIR := Vector2(0.0, 1.0)

## The three colours, named once so the blind-spot pin can loop them.
const COLORS: Array[int] = [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]


# --- AC 1: the dispatch arm -------------------------------------------------------------------

## AC 1: a DEFENSE commit reaches a REAL resolution arm. A guarded-stub hit would print
## `INVARIANT VIOLATED`, which run_all.sh's grep gate fails the whole suite on — so the observable
## proof that the arm exists is that the cast has an EFFECT: the window opens on the cast tick.
func test_a_defense_commit_reaches_a_real_arm_and_opens_the_window() -> void:
	var ms := _make_match()
	assert_false(ms.p2.defense_window.is_running, "precondition: no window before the cast")
	_cast_defense(ms, Enums.CardColor.RED)
	assert_true(ms.p2.defense_window.is_running,
		"the window opens on the very tick the defense cast resolved (AC 2)")
	assert_eq(ms.p2.defense_window.remaining_ticks(), DEFENSE_WINDOW_TICKS,
		"...at the authored duration, converted through BalanceTicks (AC 14)")


## AC 1's other half: the `_` catch-all still guards, now over exactly ONE unreached mode. PITCH is
## E6's and must still trip the stub rather than silently resolving.
func test_pitch_is_still_the_one_guarded_mode() -> void:
	assert_eq(Enums.ModeKind.size(), 4, "ModeKind is still four members (`3-5a` sized it)")
	assert_eq(int(Enums.ModeKind.DEFENSE), 2, "DEFENSE is ordinal 2, which AC 1's dispatch relies on")
	assert_eq(int(Enums.ModeKind.PITCH), 3, "...and PITCH, the one mode with no arm, is ordinal 3")


# --- AC 2: the window, its home and its tick seat ----------------------------------------------

## AC 2: the window counts down at step 2, ONE tick per advance() (A1), and expires on its own with
## nothing else changing. This also covers the story's CUT AC — "a window that expires with no
## landing simply ends" — which the gate reduced to a note precisely because it restates
## `TimingWindow`'s contract; asserting it here costs one test and closes the note.
func test_the_window_ticks_down_once_per_advance_and_simply_expires() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	for i in DEFENSE_WINDOW_TICKS:
		assert_eq(ms.p2.defense_window.remaining_ticks(), DEFENSE_WINDOW_TICKS - i,
			"one integer tick per advance() — never a float accumulator (A1)")
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_false(ms.p2.defense_window.is_running, "the window simply ENDS when nothing answers it")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
		"...and expiry is not an event: no state change, no rooting, nothing to clean up")


## AC 2: the window is PER-PLAYER and seated on `PlayerState`, not on `HeroState`. The negative half
## is structural and worth pinning: `HeroState` still carries exactly its eight windows and gains no
## ninth named `defense` (the story's superseded item 1).
func test_the_window_is_per_player_and_hero_state_gains_none() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	assert_true(ms.p2.defense_window.is_running, "precondition: the caster's window is open")
	assert_false(ms.p1.defense_window.is_running, "the OPPOSING window is untouched — per-player")
	var hero_members: Array[String] = []
	for p in HeroState.new(SignalQueue.new(), 1.0, 1.0).get_property_list():
		hero_members.append(String(p["name"]))
	assert_false(hero_members.has("defense"),
		"`HeroState` owns no `defense` window and gains none — this is a CARD-LAYER duration, "
		+ "seated beside `charge_window` on PlayerState (`5-2/R9`'s reasoning verbatim)")


# --- AC 3: the layer gate ----------------------------------------------------------------------

## AC 3: the gate is the SAME `flags.unblockable` mode ② reads — no new FeatureFlags field — and a
## closed layer refuses with the borrowed `REASON_FLAG_CLOSED`, spending nothing.
func test_a_closed_unblockable_layer_closes_mode_three_too() -> void:
	var ms := _make_match(false)
	var rejections := _collect_rejections(ms.p2)
	var hand_before := ms.p2.hand.to_array()
	_cast_defense(ms, Enums.CardColor.RED)
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_FLAG_CLOSED]],
		"a closed `unblockable` layer closes mode ③: defending only matters where an unblockable "
		+ "exists to defend against (AC 3)")
	assert_false(ms.p2.defense_window.is_running, "no window opened")
	assert_eq(ms.p2.stamina.get_current(), MAX_STAMINA, "nothing was spent")
	assert_eq(ms.p2.hand.to_array(), hand_before, "the hand is untouched")


## AC 3: a NULL `flags` reads as CLOSED — the graceful-degradation direction every layer gate in
## this file takes, never the permissive one.
func test_no_flags_injected_reads_as_closed() -> void:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors())
	_advance(ms, InputIntent.new(), InputIntent.new())
	var rejections := _collect_rejections(ms.p2)
	_advance(ms, InputIntent.new(), _defense_intent(0))
	assert_eq(rejections, [[&"card_cast", CastEvaluator.REASON_FLAG_CLOSED]],
		"a layer that cannot be VERIFIED open stays shut")


# --- AC 4: exactly one state refusal ------------------------------------------------------------

## AC 4 (operator ruling): CHARGING is the ONE state-based refusal, and it reuses
## `REASON_UNBLOCKABLE_COMMITTED` verbatim rather than inventing a reason.
func test_a_charging_hero_cannot_cast_defense() -> void:
	var ms := _make_match()
	# P2 charges first, then tries to defend on a later tick of its own chargeup.
	_cast_unblockable(ms, 1, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.CHARGING, "precondition: CHARGING")
	var rejections := _collect_rejections(ms.p2)
	var stamina_before := ms.p2.stamina.get_current()
	_advance(ms, InputIntent.new(), _defense_intent(_slot_of_color(ms.p2, Enums.CardColor.RED)))
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]],
		"a CHARGING hero is refused, on the sibling constant mode ② already uses for this exact "
		+ "state — an unblockable IS committed, which is why this hero cannot also defend (AC 4)")
	assert_false(ms.p2.defense_window.is_running, "no window opened")
	assert_eq(ms.p2.stamina.get_current(), stamina_before, "and nothing was spent")


## AC 4's positive half, and the one that carries the ruling's weight: ROLLING, BLOCKING and
## ATTACKING are ALL allowed. The defender must be able to answer mid-swing, mid-roll and mid-block.
func test_rolling_blocking_and_attacking_heroes_may_all_defend() -> void:
	for state: StringName in [&"roll", &"block", &"attack"]:
		var ms := _make_match()
		_advance(ms, InputIntent.new(), _press(state))
		assert_ne(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
			"precondition: the `%s` press entered a committed state" % state)
		var rejections := _collect_rejections(ms.p2)
		# `block` is HELD state, so the cast tick must keep holding it or the hero leaves BLOCKING
		# for a reason unrelated to this story. `attack` and `roll` are edges and need no hold.
		_cast_defense(ms, Enums.CardColor.RED, [&"block"] if state == &"block" else [])
		assert_eq(rejections, [],
			"a hero mid-`%s` may still cast DEFENSE — AC 4 refuses CHARGING and NOTHING else"
					% state)
		assert_true(ms.p2.defense_window.is_running, "...and the window really opened")


# --- AC 5: the one state write, and everything it must not touch --------------------------------

## AC 5: a BLOCKING hero's block DROPS on the cast tick. This is the first real, non-vacuous
## exercise of `5-2/R17` — mode ① never calls `set_action_state` at all, and mode ②'s CHARGING write
## is unreachable from a blocking hero because `_unblockable_refusal_reason` refuses the cast
## outright while BLOCKING. Mode ③ is the FIRST cast that is not state-gated against BLOCKING.
func test_casting_defense_drops_an_active_block() -> void:
	var ms := _make_match()
	_advance(ms, InputIntent.new(), _press(&"block"))
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING, "precondition: BLOCKING")
	# The block key stays HELD across the cast tick, which is what makes this non-vacuous: releasing
	# it would drop the block on its own and prove nothing about the cast.
	_cast_defense(ms, Enums.CardColor.RED, [&"block"])
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
		"the block drops on the SAME tick the defense cast commits, with the key STILL HELD "
		+ "(`5-2/R17`, ratified — and given its first real exercise by this story)")


## AC 5: an ATTACKING hero stays ATTACKING across the cast tick, with the swing's `active` window,
## its `chain_index` and its dedupe record ALL untouched. The claim is "untouched by construction"
## — the cast path reads and writes none of these fields — and AC 5 requires it TESTED rather than
## argued, which is the discipline `5-4` learned to apply.
func test_an_attacking_hero_keeps_its_swing_across_a_defense_cast() -> void:
	var ms := _make_match()
	_advance(ms, InputIntent.new(), _press(&"attack"))
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.ATTACKING, "precondition: ATTACKING")
	var phase_before := ms.p2.hero.attack_phase()
	var chain_before := ms.p2.hero.chain_index
	var index_before := ms.p2.hero.attack_index
	var swing_before: Dictionary = ms.p2.hero.to_snapshot()["swing_dedupe"]
	_cast_defense(ms, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.ATTACKING,
		"the swing is NOT interrupted — the card is spent and the window opens, and the swing "
		+ "finishes on its own contract exactly as if no card had been cast (AC 5)")
	assert_eq(ms.p2.hero.chain_index, chain_before, "`chain_index` untouched")
	assert_eq(ms.p2.hero.attack_index, index_before, "`attack_index` untouched")
	assert_eq(ms.p2.hero.to_snapshot()["swing_dedupe"], swing_before, "the dedupe record untouched")
	assert_true(ms.p2.hero.to_snapshot()["windup"]["is_running"]
			or ms.p2.hero.to_snapshot()["active"]["is_running"],
		"the swing's own windows are still running (phase was %s)" % phase_before)
	assert_true(ms.p2.defense_window.is_running, "...and the defense window opened anyway")


## AC 5: a ROLLING hero stays ROLLING with its roll windows intact, on the same claim and the same
## discipline as the swing case directly above.
func test_a_rolling_hero_keeps_its_roll_across_a_defense_cast() -> void:
	var ms := _make_match()
	_advance(ms, InputIntent.new(), _press(&"roll"))
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.ROLLING, "precondition: ROLLING")
	var direction_before := ms.p2.hero.roll_direction
	_cast_defense(ms, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.ROLLING, "the roll is NOT interrupted")
	assert_true(ms.p2.hero.roll_duration.is_running, "its duration window still runs")
	assert_true(ms.p2.hero.roll_iframe.is_running, "...and so do its i-frames")
	assert_eq(ms.p2.hero.roll_direction, direction_before, "the roll direction is untouched")
	assert_true(ms.p2.defense_window.is_running, "...and the defense window opened anyway")


## AC 5's NEGATIVE half, folded in from the cut AC 6: the cast introduces NO new action state and no
## rooting or slowing of its own. From IDLE the caster is still IDLE on the very next tick.
func test_the_cast_introduces_no_action_state_of_its_own() -> void:
	assert_eq(HeroState.ActionState.size(), 7,
		"`HeroState.ActionState` gains NO member — no `DEFENDING` state exists, and `IDLE` is the "
		+ "target of the BLOCKING transition rather than a new state (AC 5)")
	assert_false(HeroState.TRANSITION_TABLE.has(&"defending"),
		"...and `TRANSITION_TABLE` gains no row: the card layer drives the one edge directly, not "
		+ "an inbound press the table maps (`5-2/R7`'s reasoning verbatim)")
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
		"a cast from IDLE leaves the hero IDLE — never rooted, never slowed, free immediately")
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "...and still IDLE the next tick")


# --- AC 6: the fifth stamina seat ---------------------------------------------------------------

## AC 6: the spend goes through the pool at the authored bespoke cost.
func test_the_cast_spends_the_authored_defense_stamina_cost() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	assert_eq(ms.p2.stamina.get_current(), MAX_STAMINA - DEFENSE_COST,
		"the FIFTH stamina seat spent its own bespoke cost — never the unblockable's")
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA, "the OPPOSING pool is untouched")


## AC 6: the `1-4` FALLTHROUGH shape, never deflect's degrade — an unaffordable commit refuses and
## NOTHING is spent, NOTHING else mutates. There is no degraded defense to fall back to.
func test_an_unaffordable_defense_refuses_and_spends_nothing() -> void:
	var ms := _make_match()
	ms.p2.stamina.spend(MAX_STAMINA, 0)
	ms.drain_signals()
	assert_eq(ms.p2.stamina.get_current(), 0.0, "precondition: the pool is empty")
	var rejections := _collect_rejections(ms.p2)
	var hand_before := ms.p2.hand.to_array()
	_cast_defense(ms, Enums.CardColor.RED)
	assert_eq(rejections, [[&"card_cast", &"insufficient_stamina"]],
		"the shipped vocabulary verbatim — the same fact about the same pool the roll and attack "
		+ "seats already report")
	assert_false(ms.p2.defense_window.is_running, "no window opened")
	assert_eq(ms.p2.hand.to_array(), hand_before, "the card stayed in the hand")
	assert_eq(ms.p2.discard.size(), 0, "...and nothing reached the discard")
	assert_eq(ms.p2.pending_draw_owed, [] as Array[int], "...and no replacement is owed")


# --- AC 7: the card is always consumed ----------------------------------------------------------

## AC 7 (R-D, "the card is always consumed") in one tick, as separate facts because they are
## separate mutations and a partial resolution must not read as a pass. `_resolve_unblockable_cast`'s
## ordering mirrored exactly.
func test_the_cast_discards_the_card_and_owes_a_replacement() -> void:
	var ms := _make_match()
	var slot := _slot_of_color(ms.p2, Enums.CardColor.RED)
	var played_expected: StringName = ms.p2.hand.to_array()[slot]
	var announcements: Array = []
	ms.p2.cards_changed.connect(
		func(_ids: Array[StringName], _d: int, _x: int) -> void: announcements.append(true))
	var resolved: Array = []
	ms.card_cast_resolved.connect(
		func(s: int, id: StringName) -> void: resolved.append([s, id]))
	_advance(ms, InputIntent.new(), _defense_intent(slot))
	assert_false(ms.p2.hand.occupied_ids().has(played_expected), "the card LEFT the hand")
	assert_eq(ms.p2.discard.to_array(), [played_expected] as Array[StringName],
		"...and landed in the discard, that card and only that card")
	assert_eq(ms.p2.pending_draw_owed, [slot] as Array[int],
		"a replacement is OWED, to the slot the cast vacated")
	assert_true(ms.p2.pending_draw.is_running, "...and its window is in flight")
	assert_eq(announcements.size(), 1, "notify_cards_changed() fired exactly once")
	assert_eq(resolved, [[1, played_expected]], "card_cast_resolved queued for the casting slot")


## AC 7's load-bearing word is UNCONDITIONAL: the card is gone whether the defense ever answers
## anything or not. Proven against the MISS case, which is the one a conditional implementation
## would get wrong — the window simply expires and the card must still be spent.
func test_the_card_is_consumed_even_when_the_window_answers_nothing() -> void:
	var ms := _make_match()
	var before_discard := ms.p2.discard.size()
	_cast_defense(ms, Enums.CardColor.RED)
	for _t in DEFENSE_WINDOW_TICKS + 2:
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_false(ms.p2.defense_window.is_running, "the window expired unanswered")
	assert_eq(ms.p2.discard.size(), before_discard + 1,
		"the card is STILL discarded — consumption is unconditional on what happens later (AC 7)")


# --- AC 8: the colour ---------------------------------------------------------------------------

## AC 8: the colour is copied off the SAME injected `_card_colors` map mode ② already reads.
func test_the_defense_colour_is_the_cast_cards_own_colour() -> void:
	for color in COLORS:
		var ms := _make_match()
		_cast_defense(ms, color)
		assert_eq(ms.p2.defense_color, color,
			"the window carries THIS card's colour, read from the injected map (AC 8)")


## AC 8: a missing map entry degrades to `NO_TELEGRAPH_COLOR`, never to an invented colour. The
## sentinel family `5-2`/`5-4` already established, seen from a third end — unreachable in live play
## (`inject_card_colors`'s totality check closes it at the seam) and reachable only in a fixture that
## injects no colours, where inventing RED would be a lie the snapshot would then carry.
func test_a_missing_colour_entry_degrades_to_the_sentinel() -> void:
	var ms := _make_match(true, false)
	_advance(ms, InputIntent.new(), _defense_intent(0))
	assert_true(ms.p2.defense_window.is_running, "the cast still resolved")
	assert_eq(ms.p2.defense_color, PlayerState.NO_TELEGRAPH_COLOR,
		"...carrying NO COLOUR rather than an invented one (AC 8)")


# --- AC 9 / AC 10: the negation -----------------------------------------------------------------

## AC 10 (R-C) in full, and the POSITIVE CONTROL AC 10 explicitly owes is the first half of this
## same test: the SAME fixture first shows an UNDEFENDED landing DOES damage and DOES grant, so the
## "no damage, no grant" half below is measured against a path that demonstrably could have paid.
## Without it, "no orb grant" could pass against a fixture whose pool sat at zero either way — the
## `5-4` blind spot this story is required not to reproduce.
func test_a_colour_match_negates_completely_against_a_positive_control() -> void:
	# (a) POSITIVE CONTROL: no window at all. The landing does everything.
	var control := _make_match()
	var control_hits := _collect_hits(control)
	_run_chargeup(control, Enums.CardColor.RED)
	assert_eq(control.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"CONTROL: an undefended landing really does damage")
	assert_eq(control_hits.size(), 1, "CONTROL: ...and really does emit hit_landed")
	assert_eq(control.p1.orbs.get_count(Enums.CardColor.RED), ORB_GRANT,
		"CONTROL: ...and really does grant the attacker an orb of the charge's colour")

	# (b) THE CLAIM: the same landing, answered in the same colour, does NONE of the three.
	var ms := _make_match()
	var hits := _collect_hits(ms)
	var deflects := _collect_deflects(ms)
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "ZERO damage — take_damage was never called (R-C)")
	assert_eq(hits.size(), 0, "no hit_landed — the enemy was never hurt")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 0,
		"NO ORB GRANT — the attacker earns nothing, because there is no landing to pay for (R-C)")
	assert_eq(deflects, [[0, 1, Enums.CardColor.RED]],
		"deflect_landed fires once, on the existing seam, carrying the ANSWERED COLOUR (AC 13)")


## AC 10: the window is CONSUMED by a successful defense — one fact in two parts, cleared together
## on the exact `start(0)` / `= NO_TELEGRAPH_COLOR` pairing the debug reset uses.
func test_a_successful_defense_consumes_the_window_and_its_colour() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_false(ms.p2.defense_window.is_running, "the window is STOPPED")
	assert_eq(ms.p2.defense_color, PlayerState.NO_TELEGRAPH_COLOR, "...and its colour reset WITH it")


## AC 10's negative claim (R-C): NO STUN of any kind on either party. `HeroState.stun` is not started
## on either hero, and `STUNNED` stays the zero-inbound-edge row it has been since E1.
func test_a_negation_stuns_nobody() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_false(ms.p1.hero.stun.is_running, "the ATTACKER is not stunned (that decision is `5-6`'s)")
	assert_false(ms.p2.hero.stun.is_running, "...and neither is the DEFENDER")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "no STUNNED state on either")
	assert_ne(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "hero, from either direction")


## AC 9: the attacker's own chargeup ALWAYS ends the same way. The unconditional exit to IDLE runs on
## every outcome, negated or not — which is why the intercept is an `if/else` rather than an early
## return.
func test_the_attacker_exits_charging_whether_negated_or_not() -> void:
	var negated := _make_match()
	_cast_defense(negated, Enums.CardColor.RED)
	_run_chargeup(negated, Enums.CardColor.RED)
	assert_eq(negated.p1.hero.action_state, HeroState.ActionState.IDLE,
		"a NEGATED chargeup still ends in IDLE")
	var landed := _make_match()
	_run_chargeup(landed, Enums.CardColor.RED)
	assert_eq(landed.p1.hero.action_state, HeroState.ActionState.IDLE,
		"...and so does a LANDED one — the exit is unconditional (AC 9)")


## AC 9's FOURTH PATH: a DEAD defender never negates. The window is never consulted, whatever it
## holds, and the observable consequence is that an open, colour-MATCHING window produces no
## `deflect_landed` and is not consumed.
##
## THE MECHANISM IS TWO LAYERS AND THIS TEST NAMES BOTH RATHER THAN CLAIMING THE NARROWER ONE, which
## is a MEASURED correction to a first draft that used `set_action_state(DEAD)` alone. That idiom is
## the shipped one for the forced-DEAD family, but `HeroState.is_alive()` is measured HP-BASED
## (`hero_state.gd:171-172` — `return _hp > 0.0`), so a DEAD *action state* over positive hp sails
## straight through the reach+alive gate and the negation fires. The honest way to reach the path is
## to take the hp to zero, and at zero the ROUND-OVER FREEZE also engages (step 1b returns before
## step 3), so a dead defender is answered TWICE: by the freeze in natural play, and by the branch's
## own `is_alive()` gate as defense in depth — exactly the family `_resolve_charge_landing`'s header
## describes. Either way the colour check is never reached, which is the AC 9 claim.
func test_a_dead_defender_never_negates() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	var hits := _collect_hits(ms)
	var deflects := _collect_deflects(ms)
	# Cast the chargeup, run it to ONE tick short of landing, then kill the defender outright.
	_cast_unblockable(ms, 0, Enums.CardColor.RED)
	for _t in CHARGEUP_TICKS - 1:
		_push_reach(ms, 0)
		_advance(ms, InputIntent.new(), InputIntent.new())
	ms.p2.hero.take_damage(MAX_HP)
	ms.drain_signals()
	assert_false(ms.p2.hero.is_alive(), "precondition: the defender is dead at the landing tick")
	assert_true(ms.p2.defense_window.is_running, "precondition: ...with a MATCHING window still open")
	_push_reach(ms, 0)
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(hits.size(), 0, "a dead target takes no hit")
	assert_eq(deflects.size(), 0,
		"...and emits NO deflect either — a corpse's open, colour-matching window negates nothing, "
		+ "because the colour check is never reached (AC 9's fourth path)")
	assert_true(ms.p2.defense_window.is_running,
		"...and the window is not consumed by a landing it never answered")


## REVIEW FIX (MED, sentinel-vs-sentinel): a degraded defense (colour `NO_TELEGRAPH_COLOR`) must
## never answer a degraded chargeup (colour `NO_TELEGRAPH_COLOR`) -- two failures do not make a
## parry. Reached by DIRECT STATE MANIPULATION (the SDV precedent), because
## `inject_card_colors`'s own totality check (`Invariant.check`, assert()-backed) closes this at
## the seam in every DEBUG build and would trip the harness grep if a fixture tried to reach it
## through an injected map with a missing entry on BOTH sides. The landing must resolve as an
## ORDINARY HIT -- full damage, `hit_landed`, orb grant -- not a negation.
func test_a_degraded_defense_never_answers_a_degraded_chargeup() -> void:
	var ms := _make_match()
	var hits := _collect_hits(ms)
	var deflects := _collect_deflects(ms)
	_cast_defense(ms, Enums.CardColor.RED)
	ms.p2.defense_color = PlayerState.NO_TELEGRAPH_COLOR
	_cast_unblockable(ms, 0, Enums.CardColor.RED)
	ms.p1.charge_color = PlayerState.NO_TELEGRAPH_COLOR
	for _t in CHARGEUP_TICKS:
		_push_reach(ms, 0)
		_advance(ms, InputIntent.new(), InputIntent.new())
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
		"two degraded sentinels do NOT negate -- full damage lands (review fix)")
	assert_eq(hits.size(), 1, "...hit_landed fires as an ordinary hit")
	assert_eq(deflects.size(), 0, "...and no deflect is reported")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 0,
		"...and no orb of the ORIGINAL colour is granted, because the charge's own colour was "
		+ "overwritten to the sentinel before the landing (the orb grant reads whatever colour "
		+ "the charge carries at landing time, not what it carried at cast time)")


# --- AC 11: a wrong colour neither defends nor consumes -----------------------------------------

## AC 11 (R-B), first half: a DIFFERENT colour does not defend. The attack resolves exactly as it
## would with no defense in play.
func test_a_wrong_colour_window_does_not_defend() -> void:
	var ms := _make_match()
	var hits := _collect_hits(ms)
	_cast_defense(ms, Enums.CardColor.BLUE)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "FULL damage — the colour missed")
	assert_eq(hits.size(), 1, "...hit_landed fires as usual")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), ORB_GRANT, "...and the orb is granted")


## AC 11, second half, and the one the story owes a FALLING MUTATION for: a wrong-colour landing does
## NOT CONSUME the window. It stays running, ticking at its own step-2 rate, and goes on to answer a
## LATER same-colour landing before it expires.
##
## THE MUTATION THIS IS BUILT TO CATCH: move the window consumption OUT of the colour-match branch
## and ONTO the landing branch unconditionally. Such an implementation checks colour correctly and
## passes every other assertion in this file — the wrong-colour landing still deals full damage, the
## same-colour one still negates — while silently destroying the survival property. The SECOND half
## of this test is what goes RED against it.
func test_a_wrong_colour_landing_leaves_the_window_running_to_answer_a_later_one() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	var opened_at := ms.p2.defense_window.remaining_ticks()
	# (a) a BLUE charge lands into a RED window: full damage, and the window must SURVIVE.
	_run_chargeup(ms, Enums.CardColor.BLUE)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "precondition: the BLUE hit landed")
	assert_true(ms.p2.defense_window.is_running,
		"the window SURVIVES a wrong-colour landing — nothing about it touches the window (AC 11)")
	assert_eq(ms.p2.defense_color, Enums.CardColor.RED, "...and keeps its colour")
	assert_eq(ms.p2.defense_window.remaining_ticks(), opened_at - (CHARGEUP_TICKS + 1),
		"...having advanced by exactly the ticks that elapsed and not one more — only the per-tick "
		+ "`.tick()` call ever moves it")
	# (b) the SAME window answers a LATER same-colour landing, before it expires.
	var hp_before := ms.p2.hero.get_hp()
	var deflects := _collect_deflects(ms)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.get_hp(), hp_before,
		"the SURVIVING window answers the second, same-colour attempt — zero further damage")
	assert_eq(deflects, [[0, 1, Enums.CardColor.RED]], "...and reports the negation once")
	assert_false(ms.p2.defense_window.is_running, "...and is consumed THIS time")


# --- The BLIND-SPOT PIN: three colours, three assertions, one fixture ----------------------------

## The pin the story owes (3-0b/R34's family): the negation fires for a MATCHING colour and does NOT
## fire for either of the other two. ONE fixture varying only `defense_color` against a fixed
## `charge_color`, so the only thing that can move an assertion is the colour comparison itself.
##
## THE STATED MUTATION THAT MUST GO RED: replace AC 9's guard
## `target.defense_window.is_running and target.defense_color == player.charge_color` with a
## colour-blind `target.defense_window.is_running` (drop the comparison entirely). The two
## wrong-colour rows below turn RED against it, which is what proves the colour check is
## LOAD-BEARING rather than merely present.
func test_only_a_matching_colour_negates() -> void:
	for charge_color in COLORS:
		for defense_color in COLORS:
			var ms := _make_match()
			_cast_defense(ms, defense_color)
			_run_chargeup(ms, charge_color)
			var matched := charge_color == defense_color
			assert_eq(ms.p2.hero.get_hp(), MAX_HP if matched else MAX_HP - UNBLOCKABLE_DAMAGE,
				"charge %d vs defense %d: %s" % [charge_color, defense_color,
					"a MATCH negates" if matched else "a MISMATCH lands in full"])
			assert_eq(ms.p1.orbs.get_count(charge_color as Enums.CardColor),
				0 if matched else ORB_GRANT,
				"charge %d vs defense %d: the orb grant follows the same one answer"
						% [charge_color, defense_color])


# --- AC 12: the fourth reset exception ----------------------------------------------------------

## AC 12: the debug reset clears BOTH fields, in the same seat and on the same shape as the chargeup
## clear beside it. A window frozen mid-count by the round-over freeze must not carry into the next
## round, where a card played in the round before could negate a brand-new attack.
func test_the_debug_reset_clears_the_defense_window_and_its_colour() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	assert_true(ms.p2.defense_window.is_running, "precondition: a window is in flight")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, InputIntent.new(), reset)
	assert_false(ms.p2.defense_window.is_running, "the window is STOPPED by the reset (AC 12)")
	assert_eq(ms.p2.defense_color, PlayerState.NO_TELEGRAPH_COLOR, "...and the colour cleared WITH it")
	assert_false(ms.p1.defense_window.is_running, "the reset is match-wide: BOTH players cleared")


## AC 12's other half: `_end_round` gains NO matching clear. The `5-4` orb finding applied to a
## second field — a clear inside `_end_round` would end a still-open defense the instant the OTHER
## hero dies, before the round-over freeze displays anything.
func test_the_round_end_does_not_clear_the_defense_window() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	ms.p1.hero.take_damage(MAX_HP)
	ms.drain_signals()
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p2.defense_window.is_running,
		"the round ending does NOT clear the window — the debug reset is this codebase's one "
		+ "round-boundary transition mechanism (AC 12)")


# --- AC 14 / AC 16: the tick conversion and the snapshot key ------------------------------------

## AC 14: the `*_seconds` field crosses into the tick domain at the ONE boundary, and the reflective
## probe in test_data_resources.gd demands exactly this twin.
func test_the_window_duration_converts_at_the_one_boundary() -> void:
	var ticks := BalanceTicks.from_config(_config())
	assert_eq(ticks.defense_window_ticks, DEFENSE_WINDOW_TICKS,
		"defense_window_seconds -> defense_window_ticks, derived once at balance load (A1)")


## AC 16: the new per-player snapshot key, in both of its states. Its SHAPE is the `telegraph`
## precedent verbatim; its GATE is deliberately different (`.is_running`, not an action state),
## because mode ③ owns no action state to gate on.
func test_the_defense_snapshot_key_reports_the_window_and_rests_at_the_sentinel() -> void:
	var ms := _make_match()
	assert_eq(ms.p2.to_snapshot()["defense"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
		"RESTING value is the sentinel and a zero — the shape every tick of every match carries")
	_cast_defense(ms, Enums.CardColor.BLUE)
	assert_eq(ms.p2.to_snapshot()["defense"], [Enums.CardColor.BLUE, DEFENSE_WINDOW_TICKS],
		"...and while running it is [colour, remaining_ticks], in TICKS and never seconds")
	_run_chargeup(ms, Enums.CardColor.BLUE)
	assert_eq(ms.p2.to_snapshot()["defense"], [PlayerState.NO_TELEGRAPH_COLOR, 0],
		"a consumed window reports the resting value again — a stale colour is unrepresentable "
		+ "because the key is derived from `.is_running` rather than from a flag to remember")


## AC 16: no card IDENTITY crosses into the hash through the new key. The counts-and-indices rule
## every container key in `player_state.gd` follows, checked from the defense side.
func test_no_card_identity_reaches_the_snapshot_through_the_defense_key() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	var text := str(ms.to_snapshot())
	for id in _deck_contents():
		assert_false(text.contains(str(id)),
			"card id %s must not appear in the snapshot — the COLOUR crosses, the id does not" % id)


# --- helpers ------------------------------------------------------------------------------------

func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(StringName("def_card_%02d" % i))
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _deck_contents():
		var c := CardCastCondition.new()
		c.mana_cost = 0.0
		out[id] = c
	return out


## Colours CYCLE through all three by deck index, and the deck is dealt ENTIRE (see DECK_SIZE), so
## the hand holds exactly TWO of every colour whatever the seeded shuffle does. That is what lets
## every test here SELECT the colour it needs rather than assert against whatever was dealt — and the
## SECOND of each colour is load-bearing too: `test_a_charging_hero_cannot_cast_defense` spends one
## RED to enter CHARGING and must still have a RED left to be refused on.
func _colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	var ids := _deck_contents()
	for i in ids.size():
		out[ids[i]] = COLORS[i % COLORS.size()] as Enums.CardColor
	return out


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = MAX_HP
	c.max_mana = 90.0
	c.max_stamina = MAX_STAMINA
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.stamina_regen_per_second = 0.0   # no regen: every spend stays visible for the whole test
	c.stamina_regen_delay_seconds = 1.0
	c.roll_stamina_cost = 1.0
	c.attack_stamina_cost = 1.0
	c.deflect_stamina_cost = 1.0
	c.attack_windup_seconds = 0.5
	c.attack_active_seconds = 0.2
	c.attack_recovery_seconds = 0.3
	c.attack_chain_window_seconds = 0.2
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 5.0
	c.roll_duration_seconds = 0.5
	c.roll_iframe_seconds = 0.3
	c.roll_distance = 3.0
	c.deflect_window_seconds = 0.1
	c.block_facing_arc_degrees = 180.0
	c.draw_replacement_delay_seconds = float(DRAW_DELAY_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_stamina_cost = UNBLOCKABLE_COST
	c.unblockable_chargeup_seconds = float(CHARGEUP_TICKS) / TimingWindow.TICK_HZ
	c.unblockable_reach = REACH
	c.unblockable_damage_percent_of_max_hp = UNBLOCKABLE_DAMAGE
	c.unblockable_orb_grant = ORB_GRANT
	c.max_orbs_per_color = MAX_ORBS
	c.defense_stamina_cost = DEFENSE_COST
	c.defense_window_seconds = float(DEFENSE_WINDOW_TICKS) / TimingWindow.TICK_HZ
	return c


## Only the bit under test is parameterised; everything else stays at the resource's own defaults, so
## this fixture never silently turns another layer on. `orbs` is opened because AC 10's positive
## control needs a grant path that demonstrably pays.
func _flags(unblockable_open: bool) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.unblockable = unblockable_open
	f.orbs = true
	return f


func _make_match(unblockable_open := true, inject_colors := true) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags(unblockable_open))
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	if inject_colors:
		ms.inject_card_colors(_colors())
	_advance(ms, InputIntent.new(), InputIntent.new())   # step-6 deal happens here
	return ms


## The hand slot holding a card of `color`, READ off the dealt hand rather than assumed. Returns -1
## if the colour is absent, which every caller's assertion would then fail loudly on.
func _slot_of_color(player: PlayerState, color: int) -> int:
	var ids := player.hand.to_array()
	var map := _colors()
	for i in ids.size():
		if ids[i] != &"" and map.has(ids[i]) and int(map[ids[i]]) == color:
			return i
	return -1


## `held` matters for exactly one case and it is load-bearing rather than cosmetic: BLOCKING is held
## STATE, so a cast tick that dropped the block key would leave the hero IDLE for a reason that has
## nothing to do with this story — and `test_casting_defense_drops_an_active_block` would then pass
## vacuously, proving the key release rather than the cast.
func _defense_intent(slot: int, held: Array = []) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.DEFENSE
	i.card_commit = true
	for k: StringName in held:
		i.held[k] = true
	return i


func _unblockable_intent(slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.UNBLOCKABLE
	i.card_commit = true
	return i


func _press(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.pressed[action] = true
	i.held[action] = true
	return i


## P2 casts DEFENSE in `color`, on the slot that actually holds one.
func _cast_defense(ms: MatchState, color: int, held: Array = []) -> void:
	var slot := _slot_of_color(ms.p2, color)
	assert_true(slot >= 0, "fixture: the hand holds a card of colour %d" % color)
	_advance(ms, InputIntent.new(), _defense_intent(slot, held))


## `slot` casts UNBLOCKABLE in `color`, on the slot that actually holds one.
func _cast_unblockable(ms: MatchState, slot: int, color: int) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	var hand_slot := _slot_of_color(player, color)
	assert_true(hand_slot >= 0, "fixture: the hand holds a card of colour %d" % color)
	var intent := _unblockable_intent(hand_slot)
	if slot == 0:
		_advance(ms, intent, InputIntent.new())
	else:
		_advance(ms, InputIntent.new(), intent)


## The runner's every-tick charge-reach push, by hand and through the real seam.
func _push_reach(ms: MatchState, slot: int) -> void:
	var player: PlayerState = ms.p1 if slot == 0 else ms.p2
	ms.push_contact([slot, TargetingService.HERO_INDEX],
		[1 - slot, TargetingService.HERO_INDEX], player.hero.attack_index, FACT_DIR,
		MatchState.CONTACT_CHARGE_REACH_INSIDE)


## P1 casts UNBLOCKABLE in `color` and the whole chargeup runs out INSIDE reach, so the landing
## really resolves. Costs CHARGEUP_TICKS + 1 ticks in total.
func _run_chargeup(ms: MatchState, color: int) -> void:
	_cast_unblockable(ms, 0, color)
	for _t in CHARGEUP_TICKS:
		_push_reach(ms, 0)
		_advance(ms, InputIntent.new(), InputIntent.new())


func _collect_hits(ms: MatchState) -> Array:
	var out: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void:
		out.append([a, t, d, hp]))
	return out


func _collect_deflects(ms: MatchState) -> Array:
	var out: Array = []
	ms.deflect_landed.connect(func(a: int, t: int, c: int) -> void: out.append([a, t, c]))
	return out


func _collect_rejections(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_rejected.connect(
		func(action: StringName, reason: StringName) -> void: out.append([action, reason]))
	return out


func _advance(ms: MatchState, p1: InputIntent, p2: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, p2]
	ms.advance(intents)
	ms.drain_signals()
