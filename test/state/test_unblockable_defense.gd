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
## Story 5-6 (AC 1/AC 5/AC 9): the two ladder stuns, authored DISTINCT from every other count this
## fixture carries ({1, 2, 6, 9, 20, 600}) and from each other, so an off-by-one or a swapped field
## lands on a wrong number rather than coinciding with a right one. The ORDER (colour counter LONGER)
## mirrors the authored `.tres` gradient the authoring audit pins, so this fixture never models a
## ladder shape the shipped config forbids.
const COLOR_COUNTER_STUN_TICKS := 14
const DEFLECT_STUN_TICKS := 5
## Story 5-6 (AC 10): the deflected attacker's punitive drain. DISTINCT from both stamina costs above
## (2.0 / 1.0) so a seat that read the wrong field lands on a different balance.
const DEFLECT_PENALTY := 7.0

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
	# Story 6-1: the commit tick must say the chargeup is STILL HELD, or step 3's new early-release
	# arm feints P2 to IDLE before step 6 ever evaluates this cast and the gate under test is never
	# reached. On the pad this is live-play truth — B stays down while X is pressed. The CLAIM and
	# every assertion below are unchanged; only the fixture now states the fact it always relied on.
	_advance(ms, InputIntent.new(),
		_defense_intent(_slot_of_color(ms.p2, Enums.CardColor.RED), [&"card_cast"]))
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


## STORY 5-6 (AC 5): THIS TEST INVERTS ON ITS ATTACKER HALF, and the inversion is the story's own
## regression fix rather than a dropped guard. `5-5` shipped it asserting the attacker is NOT stunned
## with the reason written into the message ("that decision is `5-6`'s"). That decision is now made:
## `E5-P/R1` stuns the ATTACKER on a colour-matched negation, so P1's two assertions FLIP to positive
## checks. P2's — the DEFENDER's — stay exactly as `5-5` shipped them, unchanged and still negative:
## reading the colour correctly is the reward, not a second cost.
func test_a_negation_stuns_the_attacker_and_only_the_attacker() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_true(ms.p1.hero.stun.is_running,
		"the ATTACKER IS stunned — `E5-P/R1`, the decision `5-5` deferred to this story")
	assert_eq(ms.p1.hero.stun.remaining_ticks(), COLOR_COUNTER_STUN_TICKS,
		"...for the authored colour-counter duration, converted through BalanceTicks (AC 1)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"...and the state write lands with it — the FIRST of exactly two authored inbound edges")
	assert_false(ms.p2.hero.stun.is_running, "the DEFENDER is still not stunned...")
	assert_ne(ms.p2.hero.action_state, HeroState.ActionState.STUNNED,
		"...on either half — answering in colour is the reward, not a second cost")


## STORY 5-6 (AC 5) SUPERSEDES `5-5`'s "the exit is unconditional" claim, which this test used to
## assert on both halves. It is now conditional BY OUTCOME, and the pin is that each outcome takes
## EXACTLY ONE `set_action_state` — the negation to `STUNNED` (via its own early return), everything
## else to `IDLE` (via the one trailing line). A shape that left the trailing `IDLE` unconditional and
## relied on a second, later `STUNNED` write would still satisfy the STATE assertions below, so the
## TRANSITION LOG is what actually pins it: a phantom `IDLE` the hero was never in would appear there.
func test_each_landing_outcome_takes_exactly_one_action_state_write() -> void:
	var negated := _make_match()
	_cast_defense(negated, Enums.CardColor.RED)
	var negated_log := _collect_action_states(negated.p1)
	_run_chargeup(negated, Enums.CardColor.RED)
	assert_eq(negated.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"a NEGATED chargeup ends in STUNNED, not IDLE (AC 5)")
	assert_eq(negated_log, [
			[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.CHARGING)],
			[int(HeroState.ActionState.CHARGING), int(HeroState.ActionState.STUNNED)]],
		"CHARGING -> STUNNED directly: NO phantom IDLE in between, which is what a second "
		+ "last-write-wins `set_action_state` would put on this queued channel")
	var landed := _make_match()
	var landed_log := _collect_action_states(landed.p1)
	_run_chargeup(landed, Enums.CardColor.RED)
	assert_eq(landed.p1.hero.action_state, HeroState.ActionState.IDLE,
		"...and an UNANSWERED landing still ends in IDLE — the trailing line, unchanged")
	assert_eq(landed_log, [
			[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.CHARGING)],
			[int(HeroState.ActionState.CHARGING), int(HeroState.ActionState.IDLE)]],
		"...through exactly one write, with no STUNNED anywhere on the landed path")


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
		_advance(ms, _holding(), InputIntent.new())
	ms.p2.hero.take_damage(MAX_HP)
	ms.drain_signals()
	assert_false(ms.p2.hero.is_alive(), "precondition: the defender is dead at the landing tick")
	assert_true(ms.p2.defense_window.is_running, "precondition: ...with a MATCHING window still open")
	_push_reach(ms, 0)
	_advance(ms, _holding(), InputIntent.new())
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
		_advance(ms, _holding(), InputIntent.new())
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


# --- Story 5-6 (AC 7 / AC 8): the DODGE RUNG, the ladder's middle tier -------------------------
##
## Ladder order, per Ruling 1: (a) colour match [tested above] -> if false, (b) is the DEFENDER's
## roll iframe open -> if true, damage is scaled by `dodged_unblockable_damage_multiplier` and NO orb
## is granted -> if false, (c) the unchanged full-damage + orb path.

## AC 7 at the SHIPPED authoring (`dodged_unblockable_damage_multiplier = 0.0`, Ruling 1b): a clean
## dodge is SILENT. No damage, no `hit_landed` at all (not a zero-magnitude emit), and no orb —
## the same full suppression the colour-match tier gets.
func test_an_open_iframe_dodges_the_landing_silently_at_the_shipped_multiplier() -> void:
	var ms := _make_match()
	var hits := _collect_hits(ms)
	var deflects := _collect_deflects(ms)
	_run_chargeup_dodging(ms, 0, Enums.CardColor.RED, 1)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "a DODGED unblockable deals nothing at the shipped 0.0")
	assert_eq(hits, [], "...and emits NO `hit_landed` at all — full suppression, not a zero-magnitude "
		+ "emit a consumer would render as a hit for no damage")
	assert_eq(deflects, [], "...and no `deflect_landed` either: a dodge is not a colour answer")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 0,
		"...and pays NO ORB (Ruling 1b) — `_grant_landing_orbs` is never called on this branch")


## AC 7's OTHER half, and the reason the rung is a multiply rather than a hardcoded "None": retuned
## POSITIVE, the same lines emit at the surviving magnitude with no code change. The orb suppression
## is INDEPENDENT of the damage and stays in force at any multiplier.
func test_a_retuned_dodge_multiplier_emits_at_the_surviving_magnitude() -> void:
	var config := _config()
	config.dodged_unblockable_damage_multiplier = 0.5
	var ms := _make_match_with(config)
	var hits := _collect_hits(ms)
	_run_chargeup_dodging(ms, 0, Enums.CardColor.RED, 1)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE * 0.5,
		"a retuned dodge takes HALF the full landing's damage — the multiply is real")
	assert_eq(hits.size(), 1, "...and `hit_landed` DOES emit once, at the surviving magnitude...")
	assert_eq(float(hits[0][2]), UNBLOCKABLE_DAMAGE * 0.5, "...carrying that magnitude, not the full one")
	assert_eq(ms.p1.orbs.get_count(Enums.CardColor.RED), 0,
		"...and STILL no orb: the orb suppression is Ruling 1b's, independent of the damage value")


## AC 7's ladder ORDER, asserted rather than assumed: a colour match wins even when the defender is
## ALSO mid-roll. The colour tier is checked first and returns, so the attacker is STUNNED (the
## colour tier's consequence) rather than merely dodged (which carries none).
func test_a_colour_match_outranks_an_open_iframe() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup_dodging(ms, 0, Enums.CardColor.RED, 1)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP, "either tier would negate the damage, so HP proves nothing")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"...but only the COLOUR tier stuns the attacker — so the ladder checked colour FIRST (AC 7)")
	assert_false(ms.p2.defense_window.is_running,
		"...and consumed the defense window, which the dodge rung never touches")


## AC 7's negative: NO STUN OF ANY KIND on the dodge branch. Ruling 1b names an attacker consequence
## for the COLOUR counter and none for a dodge; adding one by analogy is the failure this pins.
func test_a_dodge_stuns_nobody() -> void:
	var ms := _make_match()
	_run_chargeup_dodging(ms, 0, Enums.CardColor.RED, 1)
	assert_false(ms.p1.hero.stun.is_running, "a dodged attacker is NOT stunned (AC 7, negative)...")
	assert_ne(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "...on either half")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"...it takes the ordinary trailing IDLE exit, exactly like a miss or a full landing")
	assert_false(ms.p2.hero.stun.is_running, "and neither is the DEFENDER")


## AC 8: READ-ONLY. The dodge neither consumes nor clears `roll_iframe` — the window runs its own
## course exactly as `1-9/R3` requires for every other contact. Measured as a COMPARISON against a
## control that dodged nothing, because an absolute assertion ("the window is still running") would
## pass against an implementation that shortened it without stopping it.
func test_a_dodge_neither_consumes_nor_shortens_the_iframe_window() -> void:
	var dodged := _make_match()
	_run_chargeup_dodging(dodged, 0, Enums.CardColor.RED, 1)
	var control := _make_match()
	_run_chargeup_dodging(control, 0, Enums.CardColor.RED, 1, false)   # same roll, NO landing
	assert_true(dodged.p2.hero.roll_iframe.is_running, "the iframe window is still running...")
	assert_eq(dodged.p2.hero.roll_iframe.remaining_ticks(),
		control.p2.hero.roll_iframe.remaining_ticks(),
		"...at EXACTLY the countdown an undodged roll leaves it — not ended early, not extended (AC 8)")
	assert_eq(dodged.p2.hero.action_state, control.p2.hero.action_state,
		"...and the roll itself is untouched too")


## AC 7's CORRECTION, and the highest-value test in this file: THE OBSERVATION POINT IS SEAT-SYMMETRIC.
##
## Four cases in one test — {slot 0 charging, slot 1 charging} x {roll on the PREVIOUS tick, roll on
## the LANDING tick}. The contract: a previous-tick roll dodges on BOTH slots; a landing-tick roll
## dodges on NEITHER.
##
## WITHOUT `_iframe_open_at_step3` THIS TEST FALLS, and on exactly one of the four cases, which is
## what makes it worth its length. `advance()` runs `_resolve_actions(p1)` — timer exits INCLUDING
## the charge landing, then p1's presses — completely before `_resolve_actions(p2)`. So with a live
## `target.hero.is_iframe_open()` read: slot 0's landing resolves BEFORE p2's same-tick roll press
## (no dodge, correct), while slot 1's landing resolves AFTER p1's same-tick roll press has already
## opened its iframe (a DODGE — wrong, and seat-dependent). This is also the headless replacement for
## the Live Smoke's cut seat-symmetry flip item.
func test_the_dodge_boundary_is_identical_on_both_slots() -> void:
	for charging_slot: int in 2:
		var defending_slot := 1 - charging_slot
		var previous := _make_match()
		_run_chargeup_dodging(previous, charging_slot, Enums.CardColor.RED, 1)
		var late := _make_match()
		_run_chargeup_dodging(late, charging_slot, Enums.CardColor.RED, 0)
		var prev_defender: PlayerState = previous.p1 if defending_slot == 0 else previous.p2
		var late_defender: PlayerState = late.p1 if defending_slot == 0 else late.p2
		assert_eq(prev_defender.hero.get_hp(), MAX_HP,
			"slot %d charging: a roll from the PREVIOUS tick DODGES" % [charging_slot])
		assert_eq(late_defender.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
			("slot %d charging: a roll pressed ON the landing tick does NOT dodge — the press had "
			+ "not been resolved when step 3 observed the iframe") % [charging_slot])


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


# --- Story 5-6 (AC 13): the FIFTH reset exception ----------------------------------------------

## AC 13: a stunned hero comes out of the debug reset IDLE, un-stunned, with the window STOPPED.
## The traced defect, on the `5-3`/`5-5` shape exactly: step 1b returns BEFORE step 2's tick, so once
## `_round_over` latches a running stun STOPS COUNTING but stays ARMED — and since AC 12's timer arm
## is the only normal-play exit, an uncleared stun would serve out the previous round's punish in the
## next one.
func test_the_debug_reset_clears_a_stunned_hero_and_its_window() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "precondition: P1 is stunned")
	assert_true(ms.p1.hero.stun.is_running, "...with a live window mid-count")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"the reset clears the STUNNED state (AC 13, the fifth named exception)")
	assert_false(ms.p1.hero.stun.is_running,
		"...and STOPS the window in the same breath — one fact in two parts, exactly as the "
		+ "chargeup's three and the defense window's two are")


## L1 (5-6 fix pass, review finding, Ruling 4 / addendum A): THE RESET'S OWN CONTRACT, proven
## through a path the test above cannot exercise. The debug reset runs INSIDE `advance()`'s step 1,
## so "IDLE immediately after the reset, before any advance" is not observable through the PUBLIC
## path above — that test's `_advance()` call runs step 3's AC-12 STUNNED timer arm in the SAME
## tick, which independently re-derives IDLE from a stopped window and would mask a missing
## action-state clause (this is exactly what mutation M10 measured: removing the clause left the
## whole suite green). The `2-3/R13` DEAD-branch precedent's DIRECT-CALL idiom
## (`test_match_state.gd`'s `ms._resolve_movement(...)` calls, "DIRECT step call — no advance(), no
## step 1b") is applied here to `_reset_player` itself: call the reset seat directly and assert
## immediately, before any `advance()` — including step 3 — has a chance to run and paper over a
## missing clause. This is the reset's OWN contract: post-reset state must not depend on a LATER
## step happening to run, unlike `DEAD`'s clear in the same `if`, which has no timer arm at all to
## fall back on.
func test_the_reset_seat_itself_clears_a_stunned_hero_immediately() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "precondition: P1 is stunned")
	ms._reset_player(ms.p1)   # DIRECT call — no advance(), no step 3 timer arm to mask the clause
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"the reset seat ITSELF clears STUNNED to IDLE, immediately — not merely by the time the "
		+ "next step 3 timer arm gets a chance to re-derive it (AC 13, L1)")
	assert_false(ms.p1.hero.stun.is_running, "...and the window is stopped in the same call")


## AC 13's other half, the `5-4`/`5-5` finding applied to a third field: `_end_round` gains NO
## matching clear. The debug reset is this codebase's ONE round-boundary transition mechanism, and a
## clear inside `_end_round` would end a stun the instant the OTHER hero dies — before the round-over
## freeze displays anything.
func test_the_round_end_does_not_clear_a_stun() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_true(ms.p1.hero.stun.is_running, "precondition: a stun is in flight")
	ms.p2.hero.take_damage(MAX_HP)
	ms.drain_signals()
	# The FIRST advance still runs in full -- `_round_over` is latched at step 8, AFTER step 2's tick
	# -- so the stun counts down once more here. The freeze begins on the tick AFTER that, which is
	# the `2-3/R13` one-tick carry every other window already has.
	_advance(ms, InputIntent.new(), InputIntent.new())
	var remaining := ms.p1.hero.stun.remaining_ticks()
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p1.hero.stun.is_running, "the round ending does NOT clear the stun (AC 13)...")
	assert_eq(ms.p1.hero.stun.remaining_ticks(), remaining,
		"...and the round-over FREEZE stops it counting without disarming it — step 1b returns "
		+ "before step 2, which is the very defect the reset exception above closes")


# --- Story 5-6 (AC 15 / AC 16): a committed hero cannot cast --------------------------------------

## AC 15: `_resolve_defense_cast`'s existing CHARGING gate widens to a second state, each arm keeping
## its OWN reason. "An unblockable is committed" does not read true for a hero stunned by a deflected
## melee swing, which is why `REASON_STUNNED` exists rather than a fourth reuse.
func test_a_stunned_hero_cannot_cast_defense() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "precondition: P1 is stunned")
	var rejections := _collect_rejections(ms.p1)
	var stamina_before := ms.p1.stamina.get_current()
	var hand_before := ms.p1.hand.occupied_count()
	_advance(ms, _defense_intent(_slot_of_color(ms.p1, Enums.CardColor.BLUE)), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_STUNNED]],
		"refused with REASON_STUNNED, not REASON_UNBLOCKABLE_COMMITTED (AC 15)")
	assert_false(ms.p1.defense_window.is_running, "no window armed...")
	assert_eq(ms.p1.stamina.get_current(), stamina_before, "...no stamina spent...")
	assert_eq(ms.p1.hand.occupied_count(), hand_before, "...and the card stayed in hand")


## AC 16: THE CHARGING HOLE, closed. Until this story `_resolve_basic_cast` read `action_state`
## nowhere, so a hero mid-chargeup could summon.
func test_a_charging_hero_cannot_cast_basic() -> void:
	var ms := _make_match()
	_cast_unblockable(ms, 0, Enums.CardColor.RED)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.CHARGING, "precondition: P1 is charging")
	var rejections := _collect_rejections(ms.p1)
	var hand_before := ms.p1.hand.occupied_count()
	# Story 6-1: the confirm stays HELD on the commit tick — see `_basic_intent`. The gate under
	# test, its reason and every assertion here are unchanged.
	_advance(ms, _basic_intent(_slot_of_color(ms.p1, Enums.CardColor.BLUE), [&"card_cast"]),
		InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]],
		"refused with the reason that already reads true for a charging caster (AC 16)")
	assert_eq(ms.p1.hand.occupied_count(), hand_before, "...and the card stayed in hand")


## H1 (5-6 fix pass, review finding): THE THIRD CAST SEAT. Before this fix, `_unblockable_refusal_
## reason` gated mode (2) initiation on ROLLING/BLOCKING/ATTACKING/CHARGING but not STUNNED, and
## `_resolve_unblockable_cast`'s successful-cast path unconditionally wrote CHARGING — overwriting
## STUNNED outright, un-rooting the hero and leaving its stun window running orphaned in the
## background while the hero cast a FRESH unblockable in answer to the very commitment (a deflect,
## a color-counter negation) that stunned it. Mirrors `test_a_stunned_hero_cannot_cast_basic`/
## `_defense` exactly, plus the two observables a shared-reason assertion alone cannot see: the
## action_state staying STUNNED (a successful cast would have moved it to CHARGING) and the stun
## window still counting down, untouched rather than orphaned.
func test_a_stunned_hero_cannot_cast_unblockable() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "precondition: P1 is stunned")
	var remaining := ms.p1.hero.stun.remaining_ticks()
	var rejections := _collect_rejections(ms.p1)
	var stamina_before := ms.p1.stamina.get_current()
	var hand_before := ms.p1.hand.occupied_count()
	_advance(ms, _unblockable_intent(_slot_of_color(ms.p1, Enums.CardColor.BLUE)), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_STUNNED]],
		"refused with the SHARED REASON_STUNNED constant (AC 15/AC 16's own token), not "
		+ "REASON_UNBLOCKABLE_COMMITTED — \"committed to an unblockable\" does not describe a stunned "
		+ "caster (H1)")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"...action_state stays STUNNED — a successful cast would have overwritten it with CHARGING")
	assert_true(ms.p1.hero.stun.is_running, "...the stun window keeps running, not left orphaned")
	assert_eq(ms.p1.hero.stun.remaining_ticks(), remaining - 1,
		"...ticking down at its ordinary per-tick rate — untouched, not restarted or cleared")
	assert_false(ms.p1.charge_window.is_running, "...no chargeup window armed")
	assert_eq(ms.p1.stamina.get_current(), stamina_before, "...no stamina spent")
	assert_eq(ms.p1.hand.occupied_count(), hand_before, "...and the card stayed in hand")


## AC 16's second arm, with its own reason.
func test_a_stunned_hero_cannot_cast_basic() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	_run_chargeup(ms, Enums.CardColor.RED)
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.STUNNED, "precondition: P1 is stunned")
	var rejections := _collect_rejections(ms.p1)
	var hand_before := ms.p1.hand.occupied_count()
	_advance(ms, _basic_intent(_slot_of_color(ms.p1, Enums.CardColor.BLUE)), InputIntent.new())
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_STUNNED]],
		"refused with the SHARED REASON_STUNNED constant — one player-visible fact, one token, two "
		+ "refusal seats (AC 15/AC 16)")
	assert_eq(ms.p1.hand.occupied_count(), hand_before, "...and the card stayed in hand")


## AC 16's ORDERING, which is the half a pair of positive refusals cannot see: the state gate is the
## FIRST gate, ahead of the empty-slot check, mirroring `_resolve_defense_cast` exactly. Cast against
## a slot that is ALSO empty and the reason must be the STATE's, not the slot's — a gate seated after
## `is_slot_empty` would report the wrong fact to the player.
func test_the_basic_cast_state_gate_precedes_the_empty_slot_gate() -> void:
	var ms := _make_match()
	_cast_unblockable(ms, 0, Enums.CardColor.RED)
	var rejections := _collect_rejections(ms.p1)
	# Story 6-1: still held — see `_basic_intent`. The ORDERING claim is unchanged.
	_advance(ms, _basic_intent(HAND_SIZE + 3, [&"card_cast"]), InputIntent.new())  # out of range
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_UNBLOCKABLE_COMMITTED]],
		"the STATE gate answers first — an empty slot cast while CHARGING reports the commitment, "
		+ "not REASON_EMPTY_SLOT (AC 16)")


## THE STORY'S DEFERRED ITEM, RESOLVED BY MEASUREMENT rather than left open: an ALREADY-RUNNING
## defense window cast BEFORE the stun landed is untouched by this story and keeps ticking down at
## its ordinary step-2 rate. AC 15 only prevents ARMING a NEW one. This is `5-5` AC 11's wrong-colour
## survival applied to a second interruption, and it is asserted rather than argued from "nothing
## touches these fields" — the claim is cheap to pin and expensive to rediscover.
func test_a_stun_does_not_disturb_an_already_running_defense_window() -> void:
	var ms := _make_match()
	_cast_defense(ms, Enums.CardColor.RED)
	var remaining := ms.p2.defense_window.remaining_ticks()
	ms.p2.hero.stun.start(4)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms.drain_signals()
	_advance(ms, InputIntent.new(), InputIntent.new())
	assert_true(ms.p2.defense_window.is_running, "the in-flight window survives the stun...")
	assert_eq(ms.p2.defense_window.remaining_ticks(), remaining - 1,
		"...and counts down at its ordinary step-2 rate, neither frozen nor cut short")
	assert_eq(ms.p2.defense_color, Enums.CardColor.RED, "...with its colour intact")


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

# --- Story 6-6a (AC 3-9, AC 12): THE KNOCKDOWN -- the unanswered tier's consequence for its VICTIM --
##
## Every test in this section builds its match from `_knockdown_config()`, which authors the two 6-6a
## durations on top of `_config()`. The tests above deliberately keep `_config()` UNEDITED (knockdown
## unauthored, 0 ticks): their landings still write the one-tick STUNNED a 0-tick knockdown degrades to,
## and they stay green without edits -- the `5-5` "leave the older fixture unedited" discipline.
##
## KNOCKDOWN_STUN_TICKS is authored DISTINCT from every count above ({1, 2, 5, 6, 9, 14, 20, 600}) and
## LONGER than COLOR_COUNTER_STUN_TICKS, mirroring AC 4's authored order; GET_UP_IFRAME_TICKS likewise.
## The landing helper `_land` gives the VICTIM an intent on every tick of the exchange, cast tick
## included (t == -1), so held state such as a block is never dropped by the fixture itself.

const KNOCKDOWN_STUN_TICKS := 40
const GET_UP_IFRAME_TICKS := 11


func _knockdown_config() -> BalanceConfig:
	var c := _config()
	c.knockdown_stun_seconds = float(KNOCKDOWN_STUN_TICKS) / TimingWindow.TICK_HZ
	c.get_up_iframe_seconds = float(GET_UP_IFRAME_TICKS) / TimingWindow.TICK_HZ
	return c


func _kd_match() -> MatchState:
	return _make_match_with(_knockdown_config())


## `caster_slot` casts UNBLOCKABLE in `color` and lands it inside reach. `victim_at.call(t)` supplies the
## victim's intent for tick t: t == -1 is the cast tick, 0 .. CHARGEUP_TICKS - 1 the chargeup, and the
## landing resolves on the LAST of them. `before_landing` runs just before the landing tick's advance().
func _land(ms: MatchState, caster_slot: int, color: int, victim_at := Callable(),
		before_landing := Callable()) -> void:
	var caster: PlayerState = ms.p1 if caster_slot == 0 else ms.p2
	var hand_slot := _slot_of_color(caster, color)
	assert_true(hand_slot >= 0, "fixture: the caster holds a card of colour %d" % color)
	for t in range(-1, CHARGEUP_TICKS):
		if t >= 0:
			_push_reach(ms, caster_slot)
		if t == CHARGEUP_TICKS - 1 and before_landing.is_valid():
			before_landing.call()
		var caster_intent := _unblockable_intent(hand_slot) if t == -1 else _holding()
		var victim_intent: InputIntent = victim_at.call(t) if victim_at.is_valid() else InputIntent.new()
		if caster_slot == 0:
			_advance(ms, caster_intent, victim_intent)
		else:
			_advance(ms, victim_intent, caster_intent)


func _idle_ticks(ms: MatchState, n: int) -> void:
	for _t in n:
		_advance(ms, InputIntent.new(), InputIntent.new())


func _held(action: StringName) -> InputIntent:
	var i := InputIntent.new()
	i.held[action] = true
	return i


## AC 3: an unanswered landing knocks its VICTIM down for the authored knockdown ticks -- the
## `test_a_negation_stuns_the_attacker_and_only_the_attacker` shape, with the party reversed.
func test_an_unanswered_landing_knocks_the_victim_down_for_the_authored_ticks() -> void:
	var ms := _kd_match()
	var hits := _collect_hits(ms)
	_land(ms, 0, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED,
		"the VICTIM of an unanswered unblockable is knocked down (AC 3)")
	assert_eq(ms.p2.hero.stun.duration_ticks(), KNOCKDOWN_STUN_TICKS,
		"...for the authored knockdown duration, converted through BalanceTicks (AC 4)")
	assert_eq(ms.p2.hero.stun.remaining_ticks(), KNOCKDOWN_STUN_TICKS,
		"...started on the landing tick itself, so not one tick of it has run yet")
	assert_eq(hits, [[0, 1, UNBLOCKABLE_DAMAGE, MAX_HP - UNBLOCKABLE_DAMAGE]],
		"the full damage still lands, on the unchanged `hit_landed` payload")
	assert_eq(ms.p1.hero.action_state, HeroState.ActionState.IDLE,
		"the CASTER is never knocked down -- it takes its ordinary trailing IDLE exit")
	assert_false(ms.p1.hero.stun.is_running, "...and holds no stun of its own")


## AC 3: ONE WRITE PER OUTCOME, PER HERO. The caster's `CHARGING -> IDLE` exit is untouched and the
## victim's knockdown is a SEPARATE write on the victim -- pinned on the queued channel, where a
## replacement of the caster's line (the earlier draft's defect) would show up.
func test_the_knockdown_is_a_separate_write_on_the_victim_and_the_casters_exit_is_untouched() -> void:
	var ms := _kd_match()
	var caster_log := _collect_action_states(ms.p1)
	var victim_log := _collect_action_states(ms.p2)
	_land(ms, 0, Enums.CardColor.RED)
	assert_eq(caster_log, [
			[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.CHARGING)],
			[int(HeroState.ActionState.CHARGING), int(HeroState.ActionState.IDLE)]],
		"the caster's log is exactly 5-6's landed path: CHARGING -> IDLE, once")
	assert_eq(victim_log, [[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.STUNNED)]],
		"the victim takes exactly ONE write: IDLE -> STUNNED")


## AC 3, the other two ladder rungs: a COLOUR-COUNTERED landing and a DODGED landing knock nobody down.
func test_a_countered_or_dodged_landing_knocks_nobody_down() -> void:
	var countered := _kd_match()
	_cast_defense(countered, Enums.CardColor.RED)
	_land(countered, 0, Enums.CardColor.RED)
	assert_ne(countered.p2.hero.action_state, HeroState.ActionState.STUNNED,
		"a colour-countered landing does not knock the defender down")
	assert_eq(countered.p1.hero.action_state, HeroState.ActionState.STUNNED,
		"...(the ATTACKER takes the colour-counter stun instead, unchanged)")
	var dodged := _kd_match()
	_run_chargeup_dodging(dodged, 0, Enums.CardColor.RED, 1)
	assert_eq(dodged.p2.hero.action_state, HeroState.ActionState.ROLLING,
		"a dodged landing does not knock the roller down -- the roll runs on")


## AC 3: THE LETHAL GATE. `is_alive()` is read AFTER the damage, so a killing landing writes NO
## `STUNNED` -- step 8 writes `DEAD` alone and presentation never sees a phantom knockdown.
func test_a_lethal_landing_writes_no_knockdown() -> void:
	var ms := _kd_match()
	ms.p2.hero.take_damage(MAX_HP - UNBLOCKABLE_DAMAGE * 0.5)
	ms.drain_signals()
	var victim_log := _collect_action_states(ms.p2)
	_land(ms, 0, Enums.CardColor.RED)
	assert_false(ms.p2.hero.is_alive(), "precondition: the landing killed the victim")
	assert_eq(victim_log, [[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.DEAD)]],
		"a lethal landing writes DEAD only -- no STUNNED on the queued channel first")
	assert_false(ms.p2.hero.stun.is_running, "...and no knockdown window was started")


## AC 3: WHILE DOWN, every action is refused and the hero is rooted -- the existing `STUNNED` contract
## (`5-6/R3`) applied unedited to the third edge.
func test_a_knocked_down_hero_refuses_every_action_and_is_rooted() -> void:
	var ms := _kd_match()
	_land(ms, 0, Enums.CardColor.RED)
	var attack_index := ms.p2.hero.attack_index
	var rejections := _collect_rejections(ms.p2)
	for action: StringName in [&"attack", &"roll", &"block"]:
		var press := _press(action)
		press.move_dir = Vector2(1.0, 0.0)
		_advance(ms, InputIntent.new(), press)
		assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED,
			"a %s press while down is dropped" % action)
		assert_eq(ms.p2.hero.velocity, Vector3.ZERO, "...and the downed hero does not move")
	assert_eq(ms.p2.hero.attack_index, attack_index, "no swing was started")
	var slot := _slot_of_color(ms.p2, Enums.CardColor.RED)
	_advance(ms, InputIntent.new(), _defense_intent(slot))
	assert_eq(rejections, [[&"card_cast", MatchState.REASON_STUNNED]],
		"a card cast while down is refused with REASON_STUNNED")


# --- AC 5: the victim's prior state -----------------------------------------------------------------

func test_knockdown_from_idle() -> void:
	var ms := _kd_match()
	_land(ms, 0, Enums.CardColor.RED)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "IDLE -> knocked down")


## ATTACKING: the swing is abandoned exactly as a deflect abandons one -- `is_hitbox_active()` needs
## ATTACKING, so the orphaned windows cannot gather a fact from the downed hero.
func test_knockdown_from_attacking() -> void:
	var ms := _kd_match()
	# 6-6a review: the precondition is checked ON the landing tick (the rolling row's shape), so a
	# shortened fixture windup cannot quietly turn this row into a second IDLE row.
	var check := func() -> void:
		assert_eq(ms.p2.hero.action_state, HeroState.ActionState.ATTACKING,
			"precondition: still mid-swing on the landing tick")
	_land(ms, 0, Enums.CardColor.RED, func(t: int) -> InputIntent:
		return _press(&"attack") if t == 2 else InputIntent.new(), check)
	assert_eq(ms.p2.hero.attack_index, 0, "precondition: the victim did start a swing")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "ATTACKING -> knocked down")
	assert_false(ms.p2.hero.is_hitbox_active(), "...and the abandoned swing reports no live hitbox")
	assert_eq(ms.p2.hero.chain_index, 0, "...and its sequence ends for good")


func test_knockdown_from_blocking() -> void:
	var ms := _kd_match()
	_advance(ms, InputIntent.new(), _press(&"block"))
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.BLOCKING, "precondition: blocking")
	_land(ms, 0, Enums.CardColor.RED, func(_t: int) -> InputIntent: return _held(&"block"))
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "the block does not reduce an unblockable")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "BLOCKING -> knocked down")


## ROLLING with the iframe already CLOSED at step 3 (a still-open iframe is the dodge rung instead). The
## roll is pressed 22 ticks before the landing: iframes 18 ticks, the roll itself 30 (this fixture).
func test_knockdown_from_rolling_with_the_iframe_closed() -> void:
	var ms := _kd_match()
	_advance(ms, InputIntent.new(), _press(&"roll"))
	_idle_ticks(ms, 15)
	var check := func() -> void:
		assert_eq(ms.p2.hero.action_state, HeroState.ActionState.ROLLING,
			"precondition: still rolling on the landing tick")
		assert_false(ms.p2.hero.is_iframe_open(), "precondition: ...with the iframe already closed")
	_land(ms, 0, Enums.CardColor.RED, Callable(), check)
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "not dodged: the iframe had closed")
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "ROLLING -> knocked down")


## CHARGING: the one prior state with a real effect -- the victim ABANDONS its chargeup. The three-part
## `6-1` feint teardown runs with the write; the card and the stamina stay spent; the abandoned
## attack never lands; `_charge_reach` is left alone (`6-1d/R9`).
func test_knockdown_from_charging_abandons_the_chargeup_and_keeps_the_spend() -> void:
	var ms := _kd_match()
	var victim_slot := _slot_of_color(ms.p2, Enums.CardColor.BLUE)
	var victim_at := func(t: int) -> InputIntent:
		if t == 1:
			return _unblockable_intent(victim_slot)
		return _holding() if t > 1 else InputIntent.new()
	var before := func() -> void:
		assert_eq(ms.p2.hero.action_state, HeroState.ActionState.CHARGING,
			"precondition: the victim is mid-chargeup on the landing tick")
		ms._charge_reach[1] = MatchState.CONTACT_CHARGE_REACH_INSIDE
		ms._charge_contact_dirs[1] = Vector2(0.6, 0.8)
	_land(ms, 0, Enums.CardColor.RED, victim_at, before)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "CHARGING -> knocked down")
	assert_false(ms.p2.charge_window.is_running, "the chargeup window is cleared...")
	assert_false(ms.p2.landing_window.is_running, "...the landing window with it...")
	assert_eq(ms.p2.charge_color, PlayerState.NO_TELEGRAPH_COLOR, "...and the colour, as one fact")
	assert_eq(ms._charge_reach[1], MatchState.CONTACT_CHARGE_REACH_INSIDE,
		"`_charge_reach` is NOT part of the teardown -- cleared with the verdict, never on its own")
	assert_eq(ms._charge_contact_dirs[1], Vector2(0.6, 0.8),
		"...and neither is `_charge_contact_dirs` (6-6a review: AC 5 names both)")
	assert_eq(ms.p2.stamina.get_current(), MAX_STAMINA - UNBLOCKABLE_COST, "the stamina stays spent")
	assert_eq(ms.p2.discard.size(), 1, "...and the card stays in the discard")
	for _t in CHARGEUP_TICKS:
		_push_reach(ms, 1)
		_advance(ms, InputIntent.new(), _holding())
	assert_eq(ms.p1.hero.get_hp(), MAX_HP, "the abandoned chargeup never lands")


## STUNNED, ordinary flavor (R-STUNSTACK): a colour-counter-stunned victim is KNOCKED DOWN -- the longer
## window REPLACES the shorter one. A same-state write, so the queued channel carries nothing new.
## Forced stun, the `test_action_state.gd` idiom for a non-table entry.
func test_an_ordinary_stun_escalates_to_a_knockdown() -> void:
	var ms := _kd_match()
	var victim_log := _collect_action_states(ms.p2)
	var force_ordinary_stun := func() -> void:
		ms.p2.hero.stun.start(COLOR_COUNTER_STUN_TICKS)
		ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	_land(ms, 0, Enums.CardColor.RED, Callable(), force_ordinary_stun)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "still STUNNED...")
	assert_eq(ms.p2.hero.stun.duration_ticks(), KNOCKDOWN_STUN_TICKS,
		"...but the window is now the KNOCKDOWN's -- the ordinary stun escalated")
	assert_eq(ms.p2.hero.stun.remaining_ticks(), KNOCKDOWN_STUN_TICKS,
		"...restarted at full length, replacing the shorter window")
	assert_eq(victim_log, [[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.STUNNED)]],
		"the escalation is a same-state write: no second transition reaches the queued channel")


## AC 7 -- THE FLOOR RULE (R-STUNSTACK): a second landing on an already-DOWN hero deals its damage but
## neither restarts nor extends the running knockdown. A REAL second landing, not a forced one.
func test_a_second_landing_on_a_downed_hero_deals_damage_but_never_extends_the_knockdown() -> void:
	var ms := _kd_match()
	var hits := _collect_hits(ms)
	_land(ms, 0, Enums.CardColor.RED)
	_land(ms, 0, Enums.CardColor.BLUE)
	var elapsed := CHARGEUP_TICKS + 1
	assert_eq(hits.size(), 2, "both landings emit `hit_landed`...")
	assert_eq(ms.p2.hero.get_hp(), MAX_HP - 2.0 * UNBLOCKABLE_DAMAGE, "...and both deal their damage")
	assert_eq(ms.p2.hero.stun.duration_ticks(), KNOCKDOWN_STUN_TICKS, "the window was not restarted...")
	assert_eq(ms.p2.hero.stun.remaining_ticks(), KNOCKDOWN_STUN_TICKS - elapsed,
		"...nor extended: it ticks out on its original schedule")


# --- AC 6: same-tick semantics are SEAT-SYMMETRIC (R-PRESS) -------------------------------------------

## AC 6: two unblockables landing on the SAME tick, one per seat, BOTH land and BOTH victims go down.
## Without the deferred package, P1's knockdown would flip P2 to STUNNED before P2's own landing arm ran.
func test_simultaneous_landings_knock_both_heroes_down() -> void:
	var ms := _kd_match()
	var hits := _collect_hits(ms)
	var p1_slot := _slot_of_color(ms.p1, Enums.CardColor.RED)
	var p2_slot := _slot_of_color(ms.p2, Enums.CardColor.RED)
	_advance(ms, _unblockable_intent(p1_slot), _unblockable_intent(p2_slot))
	for _t in CHARGEUP_TICKS:
		_push_reach(ms, 0)
		_push_reach(ms, 1)
		_advance(ms, _holding(), _holding())
	for player: PlayerState in [ms.p1, ms.p2]:
		assert_eq(player.hero.action_state, HeroState.ActionState.STUNNED, "BOTH heroes are knocked down")
		assert_eq(player.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE, "...and BOTH took the damage")
	assert_eq(hits.size(), 2, "both landings resolved -- neither was cancelled by the other's write")


## AC 6 (R-PRESS): a press on the knockdown tick ALWAYS resolves first -- the action taken, its cost
## spent -- and the knockdown then overwrites the result. Asserted on BOTH seats, for a step-3 press
## (attack) and a step-6 card press (defense), because those are the two seats a naive write gets wrong.
func test_a_press_on_the_knockdown_tick_resolves_first_on_both_slots() -> void:
	for victim_slot: int in 2:
		var caster_slot := 1 - victim_slot
		var attack := _kd_match()
		var attacker: PlayerState = attack.p1 if victim_slot == 0 else attack.p2
		var attack_log := _collect_action_states(attacker)
		_land(attack, caster_slot, Enums.CardColor.RED, func(t: int) -> InputIntent:
			return _press(&"attack") if t == CHARGEUP_TICKS - 1 else InputIntent.new())
		assert_eq(attacker.hero.attack_index, 0,
			"victim slot %d: the attack pressed on the knockdown tick STARTED" % victim_slot)
		assert_eq(attacker.stamina.get_current(), MAX_STAMINA - 1.0,
			"victim slot %d: ...and spent its stamina" % victim_slot)
		assert_eq(attack_log, [
				[int(HeroState.ActionState.IDLE), int(HeroState.ActionState.ATTACKING)],
				[int(HeroState.ActionState.ATTACKING), int(HeroState.ActionState.STUNNED)]],
			"victim slot %d: ...and the knockdown then overwrote it" % victim_slot)
		var card := _kd_match()
		var caster_of_card: PlayerState = card.p1 if victim_slot == 0 else card.p2
		var card_slot := _slot_of_color(caster_of_card, Enums.CardColor.GREEN)
		_land(card, caster_slot, Enums.CardColor.RED, func(t: int) -> InputIntent:
			return _defense_intent(card_slot) if t == CHARGEUP_TICKS - 1 else InputIntent.new())
		assert_true(caster_of_card.defense_window.is_running,
			"victim slot %d: the card cast on the knockdown tick RESOLVED" % victim_slot)
		assert_eq(caster_of_card.stamina.get_current(), MAX_STAMINA - DEFENSE_COST,
			"victim slot %d: ...its stamina spent" % victim_slot)
		assert_eq(caster_of_card.discard.size(), 1, "victim slot %d: ...its card spent" % victim_slot)
		assert_eq(caster_of_card.hero.action_state, HeroState.ActionState.STUNNED,
			"victim slot %d: ...and the knockdown still landed on top" % victim_slot)


# --- AC 8 / AC 9: the get-up and its iframes ------------------------------------------------------------

## AC 8: the ordinary TIMER exit from a knockdown opens the get-up iframes, on the exact exit tick.
func test_the_timer_exit_from_a_knockdown_opens_the_get_up_iframes() -> void:
	var ms := _kd_match()
	_land(ms, 0, Enums.CardColor.RED)
	_idle_ticks(ms, KNOCKDOWN_STUN_TICKS - 1)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "still down one tick before the end")
	assert_false(ms.p2.hero.get_up_iframe.is_running, "...with no get-up window yet")
	_idle_ticks(ms, 1)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "up on the tick the window empties")
	assert_true(ms.p2.hero.get_up_iframe.is_running, "...with the get-up iframes OPEN")
	assert_eq(ms.p2.hero.get_up_iframe.remaining_ticks(), GET_UP_IFRAME_TICKS,
		"...for the authored get-up duration")
	assert_true(ms.p2.hero.is_iframe_open(),
		"...and registered wherever roll iframes are: the shared `is_iframe_open()` predicate")


## AC 8's negative: an ORDINARY stun's exit opens nothing -- the get-up belongs to the knockdown flavor.
func test_an_ordinary_stun_exit_opens_no_get_up_iframes() -> void:
	var ms := _kd_match()
	ms.p2.hero.stun.start(COLOR_COUNTER_STUN_TICKS)
	ms.p2.hero.set_action_state(HeroState.ActionState.STUNNED)
	ms.drain_signals()
	_idle_ticks(ms, COLOR_COUNTER_STUN_TICKS)
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "precondition: the stun ran out")
	assert_false(ms.p2.hero.get_up_iframe.is_running, "an ordinary stun's exit arms no get-up iframes")


## R-IFRAME-UNBLOCKABLE: the get-up iframes DODGE an unblockable landing, not only melee. The second
## landing is timed onto the second tick of the get-up window; the control authors a zero get-up window
## and the same landing knocks the hero straight back down.
func test_get_up_iframes_dodge_an_unblockable_landing() -> void:
	for authored: bool in [true, false]:
		var config := _knockdown_config()
		if not authored:
			config.get_up_iframe_seconds = 0.0
		var ms := _make_match_with(config)
		_land(ms, 0, Enums.CardColor.RED)
		_idle_ticks(ms, KNOCKDOWN_STUN_TICKS - CHARGEUP_TICKS)
		_land(ms, 0, Enums.CardColor.BLUE)
		if authored:
			assert_eq(ms.p2.hero.get_hp(), MAX_HP - UNBLOCKABLE_DAMAGE,
				"a landing inside the get-up window is DODGED -- no second damage")
			assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE,
				"...and the hero is not knocked back down")
			assert_eq(ms.p1.orbs.get_count(Enums.CardColor.BLUE), 0, "...and the dodged landing pays no orb")
		else:
			assert_eq(ms.p2.hero.get_hp(), MAX_HP - 2.0 * UNBLOCKABLE_DAMAGE,
				"control: with no get-up window the same landing hits")
			assert_eq(ms.p2.hero.action_state, HeroState.ActionState.STUNNED, "control: ...and knocks down")


## AC 9: the DEBUG-RESET exit from a knockdown arms NO get-up iframes -- reset snaps straight to IDLE.
func test_the_debug_reset_exit_from_a_knockdown_arms_no_get_up_iframes() -> void:
	var ms := _kd_match()
	_land(ms, 0, Enums.CardColor.RED)
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, reset, InputIntent.new())
	assert_eq(ms.p2.hero.action_state, HeroState.ActionState.IDLE, "the reset clears the knockdown")
	assert_false(ms.p2.hero.get_up_iframe.is_running, "...and arms NO get-up iframes")


## AC 9: THE SEVENTH NAMED RESET EXCEPTION -- an ARMED get-up window is cleared by the reset, through the
## public path and through the reset seat directly (`test_the_reset_seat_itself_clears_a_stunned_hero_
## immediately`'s idiom).
func test_the_debug_reset_clears_an_armed_get_up_iframe_window() -> void:
	var ms := _kd_match()
	_land(ms, 0, Enums.CardColor.RED)
	_idle_ticks(ms, KNOCKDOWN_STUN_TICKS)
	assert_true(ms.p2.hero.get_up_iframe.is_running, "precondition: the get-up window is armed")
	var reset := InputIntent.new()
	reset.debug_reset = true
	_advance(ms, InputIntent.new(), reset)
	assert_false(ms.p2.hero.get_up_iframe.is_running, "the reset STOPS the armed get-up window")
	var direct := _kd_match()
	_land(direct, 0, Enums.CardColor.RED)
	_idle_ticks(direct, KNOCKDOWN_STUN_TICKS)
	direct._reset_player(direct.p2)
	assert_false(direct.p2.hero.get_up_iframe.is_running, "...and the reset seat itself does, immediately")


# --- AC 12: the landing package's internal order ---------------------------------------------------------

## AC 12: the knockdown write precedes its `hit_landed` push on the ONE shared queue, so a consumer that
## mirrors the action state has already left BLOCKING when it reads the hit. Asserted on BOTH victim seats
## (6-6a review): AC 12 pins the order "on both seats", through the one deferred package loop.
## (Damage-before-write is the lethal test's pin: the `is_alive()` gate reads the post-damage hp.)
func test_the_knockdown_write_precedes_its_hit_landed_on_the_shared_queue() -> void:
	for victim_slot: int in 2:
		var ms := _kd_match()
		var victim: PlayerState = ms.p1 if victim_slot == 0 else ms.p2
		var block := _press(&"block")
		if victim_slot == 0:
			_advance(ms, block, InputIntent.new())
		else:
			_advance(ms, InputIntent.new(), block)
		var order: Array = []
		victim.hero.action_state_changed.connect(
			func(previous: HeroState.ActionState, current: HeroState.ActionState) -> void:
				order.append("state %d->%d" % [previous, current]))
		ms.hit_landed.connect(func(_a: int, _t: int, _d: float, _hp: float) -> void: order.append("hit"))
		_land(ms, 1 - victim_slot, Enums.CardColor.RED,
			func(_t: int) -> InputIntent: return _held(&"block"))
		assert_eq(order, ["state %d->%d" % [HeroState.ActionState.BLOCKING, HeroState.ActionState.STUNNED],
				"hit"],
			"victim slot %d: the knockdown write, then `hit_landed` -- in that order on the drained queue"
			% victim_slot)


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
	c.unblockable_reach_red = REACH
	c.unblockable_reach_blue = REACH
	c.unblockable_reach_green = REACH
	c.unblockable_damage_percent_of_max_hp = UNBLOCKABLE_DAMAGE
	c.unblockable_orb_grant = ORB_GRANT
	c.max_orbs_per_color = MAX_ORBS
	c.defense_stamina_cost = DEFENSE_COST
	c.defense_window_seconds = float(DEFENSE_WINDOW_TICKS) / TimingWindow.TICK_HZ
	# Story 5-6: the ladder's own numbers. `dodged_unblockable_damage_multiplier` is left at the
	# resource's 0.0 default DELIBERATELY -- that is the SHIPPED authored value (Ruling 1b), so the
	# dodge tests below assert the shipped behaviour rather than a fixture-only one, and the
	# retune-positive path gets its own test that authors the value locally.
	c.color_counter_stun_seconds = float(COLOR_COUNTER_STUN_TICKS) / TimingWindow.TICK_HZ
	c.deflect_stun_seconds = float(DEFLECT_STUN_TICKS) / TimingWindow.TICK_HZ
	c.deflect_stamina_penalty = DEFLECT_PENALTY
	return c


## Only the bit under test is parameterised; everything else stays at the resource's own defaults, so
## this fixture never silently turns another layer on. `orbs` is opened because AC 10's positive
## control needs a grant path that demonstrably pays.
func _flags(unblockable_open: bool) -> FeatureFlags:
	var f := FeatureFlags.new()
	f.unblockable = unblockable_open
	f.orbs = true
	return f


## Story 5-6: the same construction as `_make_match` against a CALLER-SUPPLIED config, so a test that
## needs one authored value changed (the dodge multiplier) does not have to duplicate the whole
## fixture or parameterise `_config()` for a one-off.
func _make_match_with(config: BalanceConfig) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(config)
	ms.inject_feature_flags(_flags(true))
	ms.inject_deck(_deck_contents())
	ms.inject_card_costs(_costs())
	ms.inject_card_colors(_colors())
	_advance(ms, InputIntent.new(), InputIntent.new())
	return ms


## Story 5-6 (AC 7): `charging_slot` casts UNBLOCKABLE in `color` and runs the whole chargeup inside
## reach, while the DEFENDER presses roll `roll_lead` ticks before the landing tick.
##
##   roll_lead == 1 -> the roll is pressed on the tick BEFORE the landing: its iframe is open when
##                     step 3 observes it, so the landing is dodged.
##   roll_lead == 0 -> the roll is pressed ON the landing tick: step 3 observed the iframe BEFORE any
##                     press of that tick was resolved, so it is NOT dodged.
##
## `land` false runs the identical roll but pushes NO reach fact, so the chargeup expires OUT of
## reach and nothing lands -- the control for AC 8's comparison.
func _run_chargeup_dodging(ms: MatchState, charging_slot: int, color: int, roll_lead: int,
		land := true) -> void:
	var defending_slot := 1 - charging_slot
	_cast_unblockable(ms, charging_slot, color)
	for t in CHARGEUP_TICKS:
		if land:
			_push_reach(ms, charging_slot)
		# The landing resolves on the LAST of these ticks, i.e. `t == CHARGEUP_TICKS - 1`.
		var roll := t == CHARGEUP_TICKS - 1 - roll_lead
		var defender_intent := _press(&"roll") if roll else InputIntent.new()
		# Story 6-1 (AC 1): the CHARGING side holds its confirm for every tick of the chargeup;
		# the DEFENDER's intent is untouched — it is rolling, not charging.
		if defending_slot == 0:
			_advance(ms, defender_intent, _holding())
		else:
			_advance(ms, _holding(), defender_intent)


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


## Story 6-1 (AC 1): A CONTINUING TICK OF A CHARGEUP — an otherwise-empty intent that keeps mode
## ②'s confirm HELD. Since 6-1 a bare `InputIntent.new()` on the CHARGING player's slot means "the
## confirm was RELEASED", i.e. a paid feint; a loop that means to run a chargeup out must say so on
## every tick. Sites where nobody is charging keep their bare intents deliberately.
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


## Story 5-6 (AC 16): a mode ① commit, for the two refusal tests. The defense/unblockable siblings
## above verbatim, differing only in the mode.
## Story 6-1: `held` gains the same seat its `_defense_intent` sibling already had, and for the same
## kind of load-bearing reason — a mode ① commit tested against a CHARGING caster must carry
## `&"card_cast"`, or step 3's early-release arm ends the chargeup before step 6 reads the gate.
func _basic_intent(slot: int, held: Array = []) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = Enums.ModeKind.BASIC
	i.card_commit = true
	for k: StringName in held:
		i.held[k] = true
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
		_advance(ms, _holding(), InputIntent.new())


func _collect_hits(ms: MatchState) -> Array:
	var out: Array = []
	ms.hit_landed.connect(func(a: int, t: int, d: float, hp: float) -> void:
		out.append([a, t, d, hp]))
	return out


func _collect_deflects(ms: MatchState) -> Array:
	var out: Array = []
	ms.deflect_landed.connect(func(a: int, t: int, c: int) -> void: out.append([a, t, c]))
	return out


## Story 5-6 (AC 5): every `action_state_changed` this player emits from the moment of subscription,
## as `[previous, current]` int pairs. The QUEUED channel is the point — a shape that wrote `IDLE`
## and then `STUNNED` in the same tick would show BOTH here, which is exactly the phantom transition
## AC 5 rejects and which a final-state assertion alone cannot see.
func _collect_action_states(player: PlayerState) -> Array:
	var out: Array = []
	player.hero.action_state_changed.connect(
		func(previous: HeroState.ActionState, current: HeroState.ActionState) -> void:
			out.append([int(previous), int(current)]))
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
