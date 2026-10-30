extends TestCase

## Story 7-11 (G1, R7, AC 3/AC 4/AC 15): CONTROL SCHEME v2 -- the arm's LIFETIME and the keyboard's arm model.
## NON-GOLDEN: nothing here touches the determinism sequence or src/state/; state objects are driven only
## through their public intents and seams, the way the runner drives them.
##
## THE ARM-CLEAR CHANNEL (M5) IS PROVEN ON REAL PAYLOADS: a controller is wired to `PlayerState.cards_changed`
## exactly as the runner's wrapper wires it (the emission's own BOUND `hand_ids`, never a read of state), and
## the hand is moved by real casts and stages. The fixture deck is EIGHT COPIES OF ONE ID and the draw delay is
## ZERO, so the cast tick refills the vacated slot with the SAME id inside one drain -- the case a payload-blind
## mechanism (a sample, or `hand.to_array()` read at drain time) would miss.
##
## The controllers are constructed directly and their arm set through the private seat: a GamepadController
## with no pad bound takes the neutral path on every `sample()` (which drops the arm), and the keyboard's
## `is_action_just_pressed` is frame-scoped in a frameless harness -- so arming itself is proven through the
## pure resolvers (`test_gamepad_controller.gd`, `resolve_card_keys` below), and the live keyboard path in
## `test/integration/test_card_selection_indicator.gd` / `test_arm_clear_live.gd`.

const SEED := 7110
const DECK_SIZE := 8
const HAND_SIZE := 4
const SAME_ID := &"v2_same_card"
const BOULDER_ID := &"v2_boulder"
const CARD_COST := 3.0
const PITCH_MANA := 2.0
const START_MANA := 10.0


# --- the base Controller (6-10's `test_base_controller_defaults_are_inert`, REWRITTEN for the v2 accessors) ---

func test_base_controller_defaults_are_inert() -> void:  # 7-11 M2 REWRITE (6-10 AC 20)
	var base := Controller.new()
	assert_eq(base.armed_slot(), -1, "base: nothing armed")
	base.clear_armed_slot()
	base.observe_hand_ids([&"a", Hand.EMPTY, &"c", &"d"])
	base.observe_pitch_ready(true)
	assert_eq(base.armed_slot(), -1, "base: the three v2 pushes are no-ops")
	assert_false(base.has_method("card_mode_on") or base.has_method("force_card_mode_off"),
		"base: the 6-10 card-mode accessors are gone (AC 9)")


# --- G1: the pure arm-clear rule ---

## The arm clears on the armed slot's own non-EMPTY -> EMPTY transition between two consecutive pushes, and on
## nothing else: another slot emptying, a cover (Boulder) or its removal, and a refill of an armed EMPTY slot
## all leave it. An index past either array reads EMPTY.
func test_armed_after_hand_change_clears_only_when_the_armed_card_leaves() -> void:  # 7-11 AC 3
	var full := [&"a", &"b", &"c", &"d"]
	assert_eq(Controller.armed_after_hand_change(2, full, [&"a", &"b", Hand.EMPTY, &"d"]), -1, "the armed card left: cleared")
	assert_eq(Controller.armed_after_hand_change(1, full, [&"a", &"b", Hand.EMPTY, &"d"]), 1, "ANOTHER slot emptied: kept")
	assert_eq(Controller.armed_after_hand_change(2, full, [&"a", &"b", &"x", &"d"]), 2, "a different id with no EMPTY between: kept")
	assert_eq(Controller.armed_after_hand_change(2, full, [&"a", &"b", BOULDER_ID, &"d"]), 2, "a cover (visible id changes): kept (Q1)")
	assert_eq(Controller.armed_after_hand_change(2, [&"a", &"b", BOULDER_ID, &"d"], full), 2, "the cover lifted: kept (Q1)")
	assert_eq(Controller.armed_after_hand_change(2, [&"a", &"b", Hand.EMPTY, &"d"], full), 2, "an armed EMPTY slot refilled: kept")
	assert_eq(Controller.armed_after_hand_change(2, [&"a", &"b", Hand.EMPTY, &"d"], [&"a", &"b", Hand.EMPTY, &"d"]), 2,
		"an armed EMPTY slot staying empty: kept (state refuses its plays)")
	assert_eq(Controller.armed_after_hand_change(-1, full, [Hand.EMPTY, Hand.EMPTY, Hand.EMPTY, Hand.EMPTY]), -1, "nothing armed: nothing to clear")
	assert_eq(Controller.armed_after_hand_change(3, full, [&"a", &"b"]), -1, "the hand shrank past the armed index: it left")
	assert_eq(Controller.armed_after_hand_change(3, [], full), 3, "the first push after an empty memory: nothing left")


# --- G1 on real payloads ---

## M5 / AC 3: an ACCEPTED Basic play clears the arm with a ZERO draw delay and the SAME id refilled in the same
## drain -- because the first bound payload shows the slot EMPTY. The refill is not auto-armed. Both controller
## kinds, one rule.
func test_an_accepted_play_clears_the_arm_with_zero_draw_delay_and_the_same_id() -> void:  # 7-11 AC 3, M5
	for kind: String in ["pad", "keyboard"]:
		var ms := _make_match()
		var c = _controller(kind, 1)
		var pushes := _wire(ms, c)
		assert_eq(ms.p1.hand.to_array()[1], SAME_ID, "%s: sanity, slot 1 holds the card" % kind)
		_advance(ms, _intent(Enums.ModeKind.BASIC, 1))
		assert_eq(ms.p1.mana.get_current(), START_MANA - CARD_COST, "%s: the play was ACCEPTED (mana spent)" % kind)
		assert_eq(ms.p1.hand.to_array()[1], SAME_ID, "%s: slot 1 was refilled on the cast tick with the SAME id" % kind)
		assert_true(pushes.size() >= 2, "%s: the cast tick drained a removal and a refill (%d pushes)" % [kind, pushes.size()])
		if pushes.size() >= 2:
			assert_eq(pushes[0][1], Hand.EMPTY, "%s: the first bound payload shows slot 1 EMPTY" % kind)
			assert_eq(pushes[pushes.size() - 1][1], SAME_ID, "%s: the last shows the same id back" % kind)
		assert_eq(c.armed_slot(), -1, "%s: the arm CLEARED -- the card left, though the same id is back" % kind)
		_advance(ms, InputIntent.new())
		assert_eq(c.armed_slot(), -1, "%s: the refilled card is NOT auto-armed" % kind)


## G1 / AC 3: a REFUSED play keeps the arm -- nothing leaves the hand, so no payload shows an EMPTY.
func test_a_refused_play_keeps_the_arm() -> void:  # 7-11 AC 3
	var ms := _make_match(0.0)
	var c = _controller("pad", 1)
	var pushes := _wire(ms, c)
	var reasons: Array = []
	ms.p1.hero.action_rejected.connect(func(action: StringName, reason: StringName) -> void:
		reasons.append([action, reason]))
	var before := ms.p1.hand.to_array()
	_advance(ms, _intent(Enums.ModeKind.BASIC, 1))
	assert_eq(reasons.size(), 1, "the play was REFUSED through the shipped seam (%s)" % str(reasons))
	assert_eq(ms.p1.hand.to_array(), before, "...and the hand did not move")
	assert_eq(c.armed_slot(), 1, "a refused play KEEPS the arm (G1)")
	assert_eq(pushes.size(), 0, "...no payload was pushed at all")


## AC 3: a pitch STAGE clears the arm (the card leaves its slot for the zone); a Y ACTIVATION does not (nothing
## leaves the hand) -- whether the activation is accepted or refused.
func test_a_stage_clears_the_arm_and_an_activation_keeps_it() -> void:  # 7-11 AC 3
	var ms := _make_match()
	var c = _controller("pad", 2)
	_wire(ms, c)
	_advance(ms, _intent(Enums.ModeKind.PITCH, 2))
	assert_true(ms.pitch.is_staged(0), "sanity: the stage was accepted")
	assert_eq(c.armed_slot(), -1, "a pitch stage clears the arm")
	c._armed_slot = 3
	var armed_card: StringName = ms.p1.hand.to_array()[3]
	var activate := _intent(Enums.ModeKind.PITCH, -1)
	activate.card_activate = true
	_advance(ms, activate)
	# The activation may REFILL the staged slot's hole (EMPTY -> id) -- that is not a card leaving.
	assert_eq(ms.p1.hand.to_array()[3], armed_card, "sanity: the armed slot's card is still in place")
	assert_eq(c.armed_slot(), 3, "a Y activation keeps the arm")


## Q1 (channel level): a Boulder covering the armed slot, and the cover being lifted, keep the arm -- the bound
## visible payload changes id without ever passing through EMPTY. Driven through the Hand's own cover seats and
## the real notify; the Boulder CARD's plant and the X that clears it are the operator's smoke (Live Smoke 2/8
## companions) -- reaching them headless needs a Boulder effect fixture this story does not own.
func test_a_cover_and_its_lifting_keep_the_arm() -> void:  # 7-11 AC 3 (Q1)
	var ms := _make_match()
	var c = _controller("pad", 1)
	var pushes := _wire(ms, c)
	ms.p1.hand.cover_at(1, BOULDER_ID)
	ms.p1.notify_cards_changed()
	ms.drain_signals()
	assert_eq(pushes[pushes.size() - 1][1], BOULDER_ID, "sanity: the payload is the VISIBLE layer (the cover shows)")
	assert_eq(c.armed_slot(), 1, "a cover over the armed slot keeps the arm")
	ms.p1.hand.uncover_at(1)
	ms.p1.notify_cards_changed()
	ms.drain_signals()
	assert_eq(pushes[pushes.size() - 1][1], SAME_ID, "sanity: the card underneath shows again")
	assert_eq(c.armed_slot(), 1, "lifting the cover keeps the arm -- the next X plays the card underneath")


## AC 4: round end and the debug reset reach the controller as `clear_armed_slot()` (the runner's relays,
## pinned live in test_arm_clear_live.gd); the pad's READY push feeds nothing else.
func test_clear_armed_slot_drops_the_arm_and_ready_does_not() -> void:  # 7-11 AC 4/AC 6
	for kind: String in ["pad", "keyboard"]:
		var c = _controller(kind, 2)
		c.observe_pitch_ready(true)
		assert_eq(c.armed_slot(), 2, "%s: the READY push leaves the arm" % kind)
		c.clear_armed_slot()
		assert_eq(c.armed_slot(), -1, "%s: clear_armed_slot() drops it" % kind)
	var pad = _controller("pad", -1)
	pad.observe_pitch_ready(true)
	assert_true(pad._pitch_ready, "the pad remembers the pushed READY for its Y rule")
	pad.observe_pitch_ready(false)
	assert_false(pad._pitch_ready, "...and its retraction")


# --- R7 / AC 15: the keyboard's arm model ---

## `pX_card_1..4` arm sticky with the pad's rules and `pX_cast_confirm` plays BASIC; with nothing armed the
## confirm still commits slot -1 (G3); a commit never clears the arm (G1).
func test_keyboard_card_keys_arm_sticky_and_the_confirm_commits() -> void:  # 7-11 AC 15
	var none: Array[bool] = [false, false, false, false]
	var r := KeyboardController.resolve_card_keys(_keys(2), false, -1)
	assert_eq(r["armed_slot"], 2, "card_3 arms slot 2")
	assert_false(r["card_commit"], "arming commits nothing")
	assert_eq(KeyboardController.resolve_card_keys(none, false, 2)["armed_slot"], 2, "no key: the arm is sticky")
	assert_eq(KeyboardController.resolve_card_keys(_keys(2), false, 2)["armed_slot"], 2, "re-pressing keeps it")
	assert_eq(KeyboardController.resolve_card_keys(_keys(0), false, 2)["armed_slot"], 0, "another key moves it")
	var both: Array[bool] = [true, false, false, true]
	assert_eq(KeyboardController.resolve_card_keys(both, false, -1)["armed_slot"], 3,
		"two keys on one sample: the HIGHER slot wins (the pad's AC 2 rule)")
	var play := KeyboardController.resolve_card_keys(none, true, 1)
	assert_true(play["card_commit"], "the confirm commits")
	assert_eq(play["card_slot"], 1, "...the armed slot")
	assert_eq(play["armed_slot"], 1, "...and keeps the arm (only the card leaving clears it)")
	var bare := KeyboardController.resolve_card_keys(none, true, -1)
	assert_true(bare["card_commit"], "nothing armed: the confirm STILL commits (G3)")
	assert_eq(bare["card_slot"], -1, "...carrying slot -1 for state to refuse")
	var same := KeyboardController.resolve_card_keys(_keys(3), true, -1)
	assert_eq(same["card_slot"], 3, "a key and the confirm on one sample play the newly armed slot")
	assert_eq(KeyboardController.resolve_card_keys(none, false, 1)["card_slot"], -1,
		"no commit, no card_slot: the armed slot never rides a non-commit intent (M6 dev call)")


## AC 15: the keyboard's sample() reads no modifier -- the arm model is wired through the pure resolver.
func test_keyboard_sample_reads_no_modifier() -> void:  # 7-11 AC 15, G2
	var text := FileAccess.get_file_as_string("res://src/controllers/keyboard_controller.gd")
	var start := text.find("func _sample_card_scheme(intent: InputIntent) -> void:")
	var end := text.find("static func resolve_card_keys(")
	assert_true(start != -1 and end > start, "the card-scheme region is found by both markers")
	var body := text.substr(start, end - start)
	assert_true(body.contains("resolve_card_keys(_card_pressed, Input.is_action_just_pressed(_cast_confirm), _armed_slot)"),
		"sample() hands this sample's card-key edges and the confirm edge to the pure resolver")
	assert_false(text.contains("\"cast_mode\""), "the keyboard binds no `pX_cast_mode` action")


# --- helpers ---

func _keys(index: int) -> Array[bool]:
	var out: Array[bool] = [false, false, false, false]
	out[index] = true
	return out


## A controller of `kind` with `armed` set through the private seat (see the file header for why).
func _controller(kind: String, armed: int) -> Variant:
	var c: Variant = GamepadController.new(0, GamepadProfile.new()) if kind == "pad" \
			else KeyboardController.new(&"p1")
	c._armed_slot = armed
	return c


## Wires `c` to P1's cards_changed EXACTLY as the runner's wrapper does -- the emission's bound `hand_ids` --
## primes it the way `connect_cards_changed` primes, and returns the log of every pushed payload after the
## prime (copies). The lambda captures the controller and the log, never the PlayerState.
func _wire(ms: MatchState, c: Controller) -> Array:
	var pushes: Array = []
	c.observe_hand_ids(ms.p1.hand.to_array())
	ms.p1.cards_changed.connect(func(hand_ids: Array, _deck_count: int, _discard_count: int) -> void:
		pushes.append(hand_ids.duplicate())
		c.observe_hand_ids(hand_ids))
	return pushes


func _deck_contents() -> Array[StringName]:
	var out: Array[StringName] = []
	for i in DECK_SIZE:
		out.append(SAME_ID)
	return out


func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.max_mana = 90.0
	c.max_stamina = 40.0
	c.deck_size = DECK_SIZE
	c.hand_size = HAND_SIZE
	c.max_orbs_per_color = 5
	c.pitch_stage_timer_seconds = 6 / 60.0
	# ZERO, explicitly: the vacated slot refills on the cast tick, inside the same drain (M5).
	c.draw_replacement_delay_seconds = 0.0
	return c


func _flags() -> FeatureFlags:
	var f := FeatureFlags.new()
	f.pitch_zone = true
	f.orbs = true
	return f


## A match with a dealt hand (the deal happens at step 6 of the FIRST advance) and `mana` on P1 and P2.
func _make_match(mana := START_MANA) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(_config())
	ms.inject_feature_flags(_flags())
	ms.inject_deck(_deck_contents())
	var costs: Dictionary[StringName, CardCastCondition] = {}
	var cast := CardCastCondition.new()
	cast.mana_cost = CARD_COST
	costs[SAME_ID] = cast
	ms.inject_card_costs(costs)
	var pitch_costs: Dictionary[StringName, CardCastCondition] = {}
	var pitch := CardCastCondition.new()
	pitch.mana_cost = PITCH_MANA
	pitch_costs[SAME_ID] = pitch
	ms.inject_pitch_costs(pitch_costs)
	_advance(ms, InputIntent.new())
	ms.p1.mana.add(mana)
	ms.p2.mana.add(mana)
	ms.drain_signals()
	return ms


func _intent(mode: Enums.ModeKind, slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = slot
	i.card_mode = mode
	i.card_commit = true
	return i


func _advance(ms: MatchState, p1: InputIntent) -> void:
	var intents: Array[InputIntent] = [p1, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
