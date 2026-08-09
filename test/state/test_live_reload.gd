extends TestCase

## Story 3-0d (AC 2 / AC 3 / AC 9): THE LIVE MID-MATCH BALANCE RELOAD — DEBT B's trigger half,
## landing on the SAME reload channel `3-0c` already shipped.
##
## The fixture plays the RUNNER's role exactly as test_replay_identity.gd's does: a MatchState and
## an IntentRecorder driven side by side, capturing on the channel beside each call. The live
## trigger is then that same pair receiving ONE more `capture_apply_balance` + `apply_balance`
## pair mid-run — which is all match_runner.gd::trigger_live_balance_reload does, pinned by the
## source scan at the bottom of this file so the runner's real call site cannot drift from the
## shape proven here.
##
## GOLDEN ISOLATION: every config below is built IN-TEST (the _golden_config discipline, BC/R3),
## so nothing here can move the determinism golden and a tuning pass cannot move these numbers.

const RUNNER := "res://src/main/match_runner.gd"
const RECORDER := "res://src/systems/intent_recorder.gd"

const SEED := 9091
## Ticks driven before the live trigger fires. The recorded event's tick is the number of ticks
## ALREADY captured, so the assertion below reads TRIGGER_AFTER_TICKS directly.
const TRIGGER_AFTER_TICKS := 7
const TICKS := 12

const MOVE_SPEED := 6.5
## The reload's ONE moved value on the hero side — distinct from MOVE_SPEED so "the reload reached
## live state" is a different number rather than a coincidence.
const RETUNED_MOVE_SPEED := 13.25
const MAX_STAMINA := 40.0
const RETUNED_MAX_STAMINA := 55.0
const MAX_MANA := 60.0
const DECK_IDS: Array[StringName] = [&"reload_card_a", &"reload_card_b", &"reload_card_c"]

## AC 3: the channel set as SHIPPED — measured by content at this story's pass. 3-0d's live
## trigger added NONE: it is a second CALL to capture_apply_balance, not a ninth method.
##
## DELIBERATELY MOVED 8 -> 9 BY STORY 4-1 (`4-1/R1`, `4-1/R9`). `capture_inject_card_effects` is
## the ninth channel, and it ships because MatchState gained a ninth INTAKE
## (`inject_card_effects`) -- which is the only sanctioned reason a channel may appear, since the
## set is DERIVED from that surface and not enumerated by choice (`3-0c/R2`). The pin moves with
## the story that moves the surface; it is not widened to stop noticing.
const SHIPPED_CAPTURE_CHANNELS := 9


# ---------------------------------------------------------------- AC 2

## AC 2: a live trigger is RELOAD EVENT #1 on the existing channel — same shape, same method, no
## second injection path. Event #0 is the match-start injection at tick 0; the live one carries
## the tick it landed after.
func test_a_live_trigger_becomes_reload_event_1_on_the_existing_channel() -> void:
	var driven := _drive_with_a_live_trigger()
	var record: IntentRecorder = driven["record"]
	var ms: MatchState = driven["state"]
	assert_eq(record.reload_event_count(), 2,
		"reload event #0 (match start) plus the ONE live trigger — and nothing else grew")
	assert_eq(record.reload_event_tick(0), 0,
		"event #0 lands at tick 0, before the first tick, exactly as it always has")
	assert_eq(record.reload_event_tick(1), TRIGGER_AFTER_TICKS,
		"the live event carries the tick it was applied after — the trigger point")
	assert_eq(record.tick_count(), TICKS,
		"the trigger did not disturb the tick stream: every driven tick is still recorded")
	# The values that ride the event are the RELOADED ones, by value.
	assert_eq(record.replay_balance_config(1).move_speed, RETUNED_MOVE_SPEED,
		"the recorded event carries the reloaded values, not the match-start ones")
	assert_eq(record.replay_balance_config(0).move_speed, MOVE_SPEED,
		"...and event #0 still carries the ORIGINAL ones — the channel appends, never overwrites")
	# ...and it REACHED live state, or the trigger would be a recording of nothing.
	assert_eq(ms.p1.hero.move_speed, RETUNED_MOVE_SPEED,
		"the live reload reached state through apply_balance(): move_speed is the retuned value")
	assert_eq(ms.p2.hero.move_speed, RETUNED_MOVE_SPEED, "...on BOTH players, per-pool contract")


## AC 2, the half that makes "the SAME channel" mean something: the replay side needs NO new code
## to consume a live trigger. `replay_apply_reloads_before` already walks events 1.. and applies
## the one whose tick matches `tick - 1` — so the live event lands on the replay's tick
## TRIGGER_AFTER_TICKS + 1 and on no other tick.
func test_the_replay_side_consumes_the_live_event_with_no_new_code() -> void:
	var driven := _drive_with_a_live_trigger()
	var record: IntentRecorder = driven["record"]
	var replayed := _match_from_record(record)
	assert_eq(replayed.p1.hero.move_speed, MOVE_SPEED, "the replay starts on event #0's values")
	record.replay_apply_reloads_before(replayed, TRIGGER_AFTER_TICKS)
	assert_eq(replayed.p1.hero.move_speed, MOVE_SPEED,
		"...and nothing is applied on the tick BEFORE the recorded one")
	record.replay_apply_reloads_before(replayed, TRIGGER_AFTER_TICKS + 1)
	assert_eq(replayed.p1.hero.move_speed, RETUNED_MOVE_SPEED,
		"the live event is applied on exactly the tick it was recorded before — the existing "
		+ "reload walk needed no change to consume it")
	record.replay_apply_reloads_before(replayed, TRIGGER_AFTER_TICKS + 2)
	assert_eq(replayed.p1.hero.move_speed, RETUNED_MOVE_SPEED,
		"...and it is not re-applied on any later tick")


# ---------------------------------------------------------------- AC 3

## AC 3: THE RECORDER GAINS NO NINTH CHANNEL. The live trigger is a second CALL to the existing
## capture_apply_balance, and a ninth `capture_*` would be a scope violation this counts.
##
## Counted from the SCRIPT's own method list rather than by grepping `func capture_`, so a channel
## added by any means (including one inherited or defined out of the obvious form) is caught.
## RENAMED BY STORY 4-1 (`4-1/R9`) from `test_the_recorder_still_ships_exactly_eight_capture_
## channels` — a test name carrying a COUNT must not go on asserting a different one, the
## `test_event_bus_still_carries_exactly_the_two_declared_signals` precedent from 3-5b. The old
## name is recorded here verbatim so the pin stays greppable.
func test_the_recorder_still_ships_exactly_nine_capture_channels() -> void:
	var script: GDScript = load(RECORDER)
	var channels: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		var name := String(method["name"])
		if name.begins_with("capture_"):
			channels.append(name)
	channels.sort()
	assert_eq(channels, [
		"capture_advance", "capture_apply_balance", "capture_inject_card_costs",
		"capture_inject_card_effects", "capture_inject_deck", "capture_inject_feature_flags",
		"capture_push_contact", "capture_seed", "capture_set_camera_basis",
	], "the channel set is the EIGHT `3-0c` shipped plus story 4-1's card-effect channel")
	assert_eq(channels.size(), SHIPPED_CAPTURE_CHANNELS,
		"a TENTH capture channel is a scope violation, and this is where it fails")


# ---------------------------------------------------------------- AC 9

## AC 9: the live trigger is a GENUINE call to the unchanged per-pool seam, not a special-cased
## partial reload. With stamina spent below max, a live reload REFILLS it to the new maximum —
## the same behaviour test_stamina_economy.gd::test_mid_match_reload_refills_stamina_to_max proves
## for apply_balance() generally (D9), now proven for the LIVE trigger specifically.
##
## RATIFIED AS CORRECT, NOT TOLERATED (`3-0d/R10`): a mid-match retune visibly tops stamina up.
## The other two pools are asserted here too, because "the contract is exercised UNCHANGED" is a
## claim about all three: mana keeps its earned value under a new bound, hp is preserved and never
## re-healed. A live trigger that reloaded only "some" of the config fails one of these three.
func test_a_live_reload_refills_stamina_and_leaves_mana_and_hp_alone() -> void:
	var driven := _drive(TRIGGER_AFTER_TICKS)
	var record: IntentRecorder = driven["record"]
	var ms: MatchState = driven["state"]
	ms.p1.stamina.spend(25.0, 0)
	ms.p1.mana.add(9.0)
	ms.p1.hero.take_damage(30.0)
	ms.drain_signals()
	assert_eq(ms.p1.stamina.get_current(), MAX_STAMINA - 25.0, "stamina is BELOW max before the reload")
	assert_eq(ms.p1.mana.get_current(), 9.0, "...mana carries an EARNED value")
	assert_eq(ms.p1.hero.get_hp(), 70.0, "...and the hero is wounded")
	_live_reload(record, ms, _retuned_config())
	assert_eq(ms.p1.stamina.get_maximum(), RETUNED_MAX_STAMINA, "the new bound is injected")
	assert_eq(ms.p1.stamina.get_current(), RETUNED_MAX_STAMINA,
		"stamina REFILLS to the new maximum on a live reload — the unconditional refill() in "
		+ "_apply_balance_to_player, ratified as correct (`3-0d/R10`)")
	assert_eq(ms.p1.mana.get_current(), 9.0,
		"mana is NEVER refilled by a reload — the earned value survives (3-1/R2)")
	assert_eq(ms.p1.hero.get_hp(), 70.0,
		"hp is PRESERVED, never re-healed: the first-injection heal is gated and this is not one")
	assert_eq(ms.p2.stamina.get_current(), RETUNED_MAX_STAMINA,
		"...and the reload is per-pool for BOTH players, not just the one that spent")


# ---------------------------------------------------------------- the runner's own call site

## AC 2, the falsifying half for the SHIPPED trigger rather than for this fixture's imitation of
## it: match_runner.gd must re-read the service and CAPTURE BEFORE IT APPLIES, in one seat.
##
## Without this scan the tests above would pass against a runner whose trigger applied balance
## without recording it — the exact silent divergence between a recording and its replay that
## DEBT B's both-halves-together rule exists to prevent (decision-log:130-133).
func test_the_runner_trigger_re_reads_the_service_and_captures_before_it_applies() -> void:
	var lines := _code_lines(RUNNER)
	var reload_calls: Array[int] = []
	var captures: Array[int] = []
	var applies: Array[int] = []
	for i in lines.size():
		if lines[i].contains("BalanceConfigService.reload("):
			reload_calls.append(i)
		if lines[i].contains("_recorder.capture_apply_balance("):
			captures.append(i)
		if lines[i].contains("_match_state.apply_balance("):
			applies.append(i)
	assert_eq(reload_calls.size(), 1,
		"exactly ONE seat re-reads BalanceConfigService — the live trigger. A second is a second "
		+ "injection path, which AC 2 refuses")
	assert_eq(captures.size(), 2,
		"capture_apply_balance is called TWICE in the runner: reload event #0 at match start and "
		+ "the live trigger. A third call site, or a missing one, is a channel change")
	assert_eq(applies.size(), 2, "...and apply_balance is called exactly as often")
	# ORDER, per call site: the capture must precede the apply, so a record can never be missing an
	# event that state already received.
	for index in 2:
		assert_true(captures[index] < applies[index],
			"capture_apply_balance must come BEFORE apply_balance at call site %d — a recording "
					% index + "that lags state by one event is a replay that diverges")
	# The live seat re-reads the service, and it is the SAME seat that captures: the reload call
	# must sit between the match-start capture and the live capture's own apply.
	assert_true(reload_calls[0] > captures[0],
		"the service re-read belongs to the LIVE trigger, not to match start (match start reads "
		+ "get_config() only — re-reading there would re-load the .tres before the first tick)")
	assert_true(reload_calls[0] < captures[1] and captures[1] < applies[1],
		"the live seat runs reload() -> capture_apply_balance() -> apply_balance(), in that order")


# ---------------------------------------------------------------- the driven pair

## Match start in the RUNNER's order (match_runner.gd:113-172): seed -> balance -> flags -> deck
## -> costs, each captured beside the call it taps.
func _match_start() -> Dictionary:
	var record := IntentRecorder.new()
	var params := MatchParams.new(SEED)
	record.capture_seed(params.seed_value)
	var ms := MatchState.new(params)
	var config := _config()
	record.capture_apply_balance(config)
	ms.apply_balance(config)
	var flags := FeatureFlags.new()
	# Story 4-1: the minion layer ON, so the recorded effects channel is exercised by a resolver
	# that actually appends rather than one gated shut.
	flags.minions = true
	record.capture_inject_feature_flags(flags)
	ms.inject_feature_flags(flags)
	record.capture_inject_deck(DECK_IDS)
	ms.inject_deck(DECK_IDS)
	var costs := _costs()
	record.capture_inject_card_costs(costs)
	ms.inject_card_costs(costs)
	# Story 4-1 (`4-1/R1`, `4-1/R8`): the THIRD content channel, captured and injected LAST -- the
	# order deck -> costs -> effects the live runner produces and SOUND_CONTENT_ORDER pins.
	var effects := _effects()
	record.capture_inject_card_effects(effects)
	ms.inject_card_effects(effects)
	ms.drain_signals()
	return {"record": record, "state": ms}


func _drive(ticks: int) -> Dictionary:
	var driven := _match_start()
	for _t in ticks:
		_tick(driven)
	return driven


## The full sequence AC 2 asserts against: TRIGGER_AFTER_TICKS ticks, one live trigger, then the
## rest of the run — so the trigger is provably mid-match rather than at either end.
func _drive_with_a_live_trigger() -> Dictionary:
	var driven := _drive(TRIGGER_AFTER_TICKS)
	_live_reload(driven["record"], driven["state"], _retuned_config())
	for _t in TICKS - TRIGGER_AFTER_TICKS:
		_tick(driven)
	return driven


## THE TRIGGER'S SHAPE, and the only thing match_runner.gd::trigger_live_balance_reload adds to
## it is reading the config off the re-read service instead of taking it as an argument (pinned by
## the source scan above): capture FIRST, then apply.
func _live_reload(record: IntentRecorder, ms: MatchState, config: BalanceConfig) -> void:
	record.capture_apply_balance(config)
	ms.apply_balance(config)
	ms.drain_signals()


func _tick(driven: Dictionary) -> void:
	var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
	(driven["record"] as IntentRecorder).capture_advance(intents)
	var ms: MatchState = driven["state"]
	ms.advance(intents)
	ms.drain_signals()


## A SECOND, independent match built from the record's match-start channels alone — the replay
## side's starting point, used to prove the reload walk consumes the live event.
func _match_from_record(record: IntentRecorder) -> MatchState:
	var ms := MatchState.new(MatchParams.new(record.replay_seed()))
	ms.apply_balance(record.replay_balance_config(0))
	ms.inject_feature_flags(record.replay_feature_flags())
	assert_true(record.replay_inject_content(ms), "the recorded content order replays")
	ms.drain_signals()
	return ms


# ---------------------------------------------------------------- fixture content

func _config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = 100.0
	c.move_speed = MOVE_SPEED
	c.max_stamina = MAX_STAMINA
	c.max_mana = MAX_MANA
	c.deck_size = DECK_IDS.size()
	c.hand_size = 2
	return c


## The reload's config: two moved values, one hero-side (move_speed) and one pool-side
## (max_stamina), so AC 2's "it reached state" and AC 9's "the pools were re-injected" are
## separate observations rather than one number seen twice.
func _retuned_config() -> BalanceConfig:
	var c := _config()
	c.move_speed = RETUNED_MOVE_SPEED
	c.max_stamina = RETUNED_MAX_STAMINA
	return c


## Story 4-1 (`4-1/R1`): the effect map for this fixture's composition -- `_costs()`'s twin,
## built in-test over the same opaque ids. Every id carries a `summon_` prefix so the channel is
## exercised by a resolver that actually appends a unit record.
func _effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id in DECK_IDS:
		var e := CardEffect.new()
		e.effect_id = StringName("summon_%s" % id)
		out[id] = e
	return out


func _costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id in DECK_IDS:
		var c := CardCastCondition.new()
		c.mana_cost = 3.0
		out[id] = c
	return out


# Code portion of each line (everything before the first '#'), so comments can't false-positive.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line()
		var hash_idx := line.find("#")
		if hash_idx >= 0:
			line = line.substr(0, hash_idx)
		out.append(line)
	return out
