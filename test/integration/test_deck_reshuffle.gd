extends SceneTree

## Story 3-5b (AC 12): the HEADLESS PROOF of deck exhaustion, the lazy reshuffle, the vulnerable
## window and the both-empty degrade — driven against the AUTHORED balance config, end to end, in
## a fixed-tick loop.
##
## WHY THIS IS THE WHOLE VERIFICATION STORY, and why it is required rather than optional: Live
## Smoke is NOT REQUIRED for 3-5b because the story ships NO PLAYER-FACING SURFACE. AT THE TIME
## 3-5b SHIPPED the HUD card row rendered the presentation-local constant 4 and never read the
## hand (hud_root.gd, 2-5/R1), the deck readout was the literal placeholder "DECK -- / RESH" wired
## to nothing, and the vulnerable window had no renderer at all. A human at the keyboard therefore
## could not observe one claim below. Headless was not the cheap proof here — it was the only one.
## (Story 3-6 has since given all three a renderer. That does not retroactively make these claims
## observable: what this test proves is exhaustion ARITHMETIC against authored numbers, which no
## HUD shows.)
##
## WHAT MAKES THIS AN INTEGRATION TEST rather than a second state test: it runs against
## `data/balance/balance_config.tres` — the WHOLE shipped config, authored values and all —
## instead of an in-test literal, and it is PARAMETRIC off that config (the test_contact_pipeline
## precedent). A legitimate tuning edit to deck_size, hand_size or either new duration moves this
## test's expectations WITH it rather than breaking it. The state harness deliberately cannot do
## this: every state test builds its balance in-test precisely so authored tuning can never break
## the unit suite (BC/R3), which leaves "the AUTHORED numbers actually reach exhaustion" unproven
## anywhere else.
##
## `advance()` takes no delta by design (A1) — one call IS one fixed 1/60 s tick — so the loop
## below is the fixed-delta loop the story asks for, without a frame or an autoload in sight.
##
## CARD IDENTITY IS SYNTHETIC AND PRICES ARE ZERO, deliberately. Nothing here is a claim about
## card content or the mana economy: those are proven in test_card_database.gd,
## test_deck_injection.gd and test_card_play.gd. Pricing the fixture would force this test to
## hand-feed mana across a thousand ticks, which would prove less, not more.
##
## Run: godot --headless --path . --script res://test/integration/test_deck_reshuffle.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const CONFIG_PATH := "res://data/balance/balance_config.tres"
const SEED := 20260804

var _notes: Array[String] = []
var _vulnerable_events: Array = []


func _initialize() -> void:
	var config := load(CONFIG_PATH) as BalanceConfig
	var authored_ok := _check_authored(config)
	var exhaustion_ok := false
	var reshuffle_ok := false
	var rng_ok := false
	var event_ok := false
	var degrade_ok := false
	if authored_ok:
		var result := _drive_to_exhaustion_and_reshuffle(config)
		exhaustion_ok = bool(result["exhaustion"])
		reshuffle_ok = bool(result["reshuffle"])
		rng_ok = bool(result["rng"])
		event_ok = bool(result["event"])
		degrade_ok = _check_both_empty_degrade(config)

	var ok := authored_ok and exhaustion_ok and reshuffle_ok and rng_ok and event_ok and degrade_ok
	print("deck_reshuffle: authored=%s exhaustion=%s reshuffle=%s rng=%s event=%s degrade=%s | %s" % [
		authored_ok, exhaustion_ok, reshuffle_ok, rng_ok, event_ok, degrade_ok,
		"; ".join(_notes)])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


## The authored values must be LIVE in the tick domain, not merely present in the file. A delay
## that derived to 0 ticks would make every check below pass against 3-5a's instant refill, and a
## zero vulnerable window would close on the tick it opened — both are exactly the "ships
## invisible in the build" failure the bespoke authoring bounds exist to catch, verified here a
## second time through the conversion boundary that actually feeds the seats.
func _check_authored(config: BalanceConfig) -> bool:
	if config == null:
		_notes.append("authored balance config failed to load")
		return false
	var ticks := BalanceTicks.from_config(config)
	var ok := true
	if ticks.draw_replacement_delay_ticks <= 0:
		_notes.append("authored draw_replacement_delay_seconds derives to %d ticks — the delay is not live"
				% ticks.draw_replacement_delay_ticks)
		ok = false
	if ticks.reshuffle_vulnerable_window_ticks <= 0:
		_notes.append("authored reshuffle_vulnerable_window_seconds derives to %d ticks"
				% ticks.reshuffle_vulnerable_window_ticks)
		ok = false
	if config.hand_size >= config.deck_size:
		_notes.append("authored hand_size %d leaves no pile to drain" % config.hand_size)
		ok = false
	return ok


## The main drive. One cast per cycle, each cycle exactly `delay` ticks long, so every cycle moves
## ONE card from the pile to the hand and ONE from the hand to the discard. `deck_size -
## hand_size` cycles therefore empty the pile exactly, and the NEXT delivery is the one with
## nothing to draw from.
func _drive_to_exhaustion_and_reshuffle(config: BalanceConfig) -> Dictionary:
	var ticks := BalanceTicks.from_config(config)
	var delay := ticks.draw_replacement_delay_ticks
	var pile := config.deck_size - config.hand_size
	var ms := _make_match(config)
	ms.reshuffle_vulnerable_window_opened.connect(
		func(slot: int) -> void: _vulnerable_events.append(slot))

	# One PLAIN cycle first, measured on its own: a delivery that draws from a non-empty pile must
	# consume no RNG. Without this half, "the reshuffle moved rng_state" is unfalsifiable.
	var rng_before_plain: Variant = ms.to_snapshot()["rng_state"]
	_cast_and_settle(ms, delay)
	var rng_after_plain: Variant = ms.to_snapshot()["rng_state"]
	var rng_ok: bool = rng_after_plain == rng_before_plain
	if not rng_ok:
		_notes.append("a PLAIN delivery draw moved rng_state — draw_top() must consume nothing")

	for _i in pile - 1:
		_cast_and_settle(ms, delay)

	# EXHAUSTION. The pile is empty, every replacement so far was served, and the discard holds
	# exactly what the hand cycled through. This is the state 3-5a already reached SILENTLY (the
	# `is_empty()` floor) — reached here on the authored numbers, which is the story's reframe.
	var exhaustion_ok := true
	if ms.p1.deck.size() != 0:
		_notes.append("pile not empty after %d casts: %d left" % [pile, ms.p1.deck.size()])
		exhaustion_ok = false
	if ms.p1.discard.size() != pile:
		_notes.append("discard holds %d, expected %d" % [ms.p1.discard.size(), pile])
		exhaustion_ok = false
	if ms.p1.hand.size() != config.hand_size:
		_notes.append("hand short at exhaustion: %d, expected %d" % [ms.p1.hand.size(), config.hand_size])
		exhaustion_ok = false
	if not _vulnerable_events.is_empty():
		_notes.append("the vulnerable event fired before any reshuffle: %s" % [_vulnerable_events])
		exhaustion_ok = false

	# THE RESHUFFLE. One more cast; its delivery finds the pile empty and folds the discard back.
	var rng_before_reshuffle: Variant = ms.to_snapshot()["rng_state"]
	_cast_and_settle(ms, delay)
	var reshuffle_ok := true
	if ms.p1.discard.size() != 0:
		_notes.append("discard not folded back: %d left" % ms.p1.discard.size())
		reshuffle_ok = false
	if ms.p1.deck.size() != pile:
		_notes.append("reshuffled pile holds %d, expected %d" % [ms.p1.deck.size(), pile])
		reshuffle_ok = false
	if ms.p1.hand.size() != config.hand_size:
		_notes.append("hand not refilled after the reshuffle: %d" % ms.p1.hand.size())
		reshuffle_ok = false
	if ms.p1.pending_draw_owed != 0:
		_notes.append("a debt survived the reshuffling delivery: %d" % ms.p1.pending_draw_owed)
		reshuffle_ok = false
	# Conservation across the reshuffle (AC 11), on the authored composition.
	if not _is_conserved(ms, config):
		reshuffle_ok = false
	# P2 never cast: the reshuffle is this player's own discard and nothing else.
	if ms.p2.deck.size() != pile or ms.p2.hand.size() != config.hand_size \
			or ms.p2.discard.size() != 0:
		_notes.append("P2's piles moved (%d/%d/%d) — the reshuffle is not owner-scoped" % [
			ms.p2.deck.size(), ms.p2.hand.size(), ms.p2.discard.size()])
		reshuffle_ok = false

	# rng_state MOVED across the reshuffle — the reverse half of the golden's cause C4, which is
	# a vacuous claim without a measurement showing the generator CAN move here.
	if ms.to_snapshot()["rng_state"] == rng_before_reshuffle:
		_notes.append("rng_state did NOT move across the reshuffle — the Fisher-Yates did not run")
		rng_ok = false

	# THE EVENT: exactly once, carrying the vulnerable player's slot, with the window open on that
	# player alone for the authored duration.
	var event_ok := true
	if _vulnerable_events != [0]:
		_notes.append("vulnerable events = %s, expected exactly [0]" % [_vulnerable_events])
		event_ok = false
	if not ms.p1.vulnerable_window.is_running:
		_notes.append("the vulnerable window is not open on the reshuffling player")
		event_ok = false
	if ms.p2.vulnerable_window.is_running:
		_notes.append("the vulnerable window opened on the OPPONENT too")
		event_ok = false

	return {
		"exhaustion": exhaustion_ok,
		"reshuffle": reshuffle_ok,
		"rng": rng_ok,
		"event": event_ok,
	}


## AC 10, and it is CONSTRUCTED DIRECTLY rather than driven to — the same reason the state test
## gives. With `deck + hand + discard` conserved, a delivery finding both piles empty would need
## the hand to hold the entire composition, which forces successful draws to exceed casts; that is
## impossible, so the case is unreachable in natural play and the degrade ships as defense in
## depth. What matters is that it DEGRADES: no crash, no invented card, the debt consumed, and no
## vulnerable window opened against nothing.
func _check_both_empty_degrade(config: BalanceConfig) -> bool:
	var ms := _make_match(config)
	var events: Array = []
	ms.reshuffle_vulnerable_window_opened.connect(func(slot: int) -> void: events.append(slot))
	ms.p1.deck.set_contents([] as Array[StringName])
	ms.p1.discard.clear()
	ms.p1.pending_draw_owed = 1
	ms.p1.pending_draw.start(0)
	var hand_before := ms.p1.hand.size()
	_tick(ms)
	var ok := true
	if ms.p1.pending_draw_owed != 0:
		_notes.append("the owed draw was not consumed by the degrade: %d" % ms.p1.pending_draw_owed)
		ok = false
	if ms.p1.hand.size() != hand_before:
		_notes.append("the degrade invented a card: hand %d -> %d" % [hand_before, ms.p1.hand.size()])
		ok = false
	if ms.p1.vulnerable_window.is_running or not events.is_empty():
		_notes.append("a vulnerable window opened with nothing to reshuffle")
		ok = false
	return ok


## deck + hand + discard is still a permutation of the injected composition (AC 11's first three
## terms), and the in-flight COUNT closes the hand (its fourth).
func _is_conserved(ms: MatchState, config: BalanceConfig) -> bool:
	var all := ms.p1.deck.to_array()
	all.append_array(ms.p1.hand.to_array())
	all.append_array(ms.p1.discard.to_array())
	all.sort()
	var expected := _composition(config.deck_size)
	expected.sort()
	var ok := true
	if all != expected:
		_notes.append("conservation broken: %d cards accounted for, expected %d"
				% [all.size(), expected.size()])
		ok = false
	if ms.p1.hand.size() + ms.p1.pending_draw_owed != config.hand_size:
		_notes.append("the in-flight term does not close the hand: %d + %d != %d"
				% [ms.p1.hand.size(), ms.p1.pending_draw_owed, config.hand_size])
		ok = false
	return ok


func _composition(size: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in size:
		out.append(StringName("reshuffle_card_%03d" % i))
	return out


func _costs(size: int) -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in _composition(size):
		out[id] = CardCastCondition.new()  # mana_cost 0.0 — see the header
	return out


func _make_match(config: BalanceConfig) -> MatchState:
	var ms := MatchState.new(MatchParams.new(SEED))
	ms.apply_balance(config)
	ms.inject_deck(_composition(config.deck_size))
	ms.inject_card_costs(_costs(config.deck_size))
	_tick(ms)  # the step-6 deal
	return ms


func _tick(ms: MatchState) -> void:
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()


## One cast-to-delivery cycle: the cast tick plus exactly the authored delay, which lands the
## delivery on the last of those ticks.
func _cast_and_settle(ms: MatchState, delay: int) -> void:
	var cast := InputIntent.new()
	cast.card_slot = 0
	cast.card_mode = Enums.ModeKind.BASIC
	cast.card_commit = true
	var intents: Array[InputIntent] = [cast, InputIntent.new()]
	ms.advance(intents)
	ms.drain_signals()
	for _t in delay:
		_tick(ms)
