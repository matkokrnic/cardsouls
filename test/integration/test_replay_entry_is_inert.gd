extends SceneTree

## Story 3-0d (`3-0d/R20` part 2): A MID-SESSION ASSIGNMENT TO `replay_record` IS INERT — PROVEN
## BEHAVIOURALLY, ON A LIVE RUNNER, BECAUSE THAT IS THE ONLY PLACE THE CLAIM MEANS ANYTHING.
##
## WHY THIS TEST EXISTS AT ALL. Two source scans used to police this property by inspection: one
## asserting `replay_record` was assigned nowhere in `src/`, one enumerating the debug panel's
## runner-reaching `Callable` members. Three review rounds defeated them — `set()`/`set_deferred()`/
## indexed writes tallied as READS; `(replay_record) = null` classified as an "argument read" by the
## very whitelist meant to close that; six panel declaration forms outside the pattern; a line
## reader that truncated at a `#` inside a string literal; and `.tscn`-embedded GDScript never read
## at all. A complete, wired LOAD control shipped past both with the suite green.
##
## `3-0d/R20`: **A TEXT SCAN OVER SOURCE CANNOT CARRY A DESIGN INVARIANT.** The property is made
## STRUCTURALLY IMPOSSIBLE instead of DETECTABLE. `MatchRunner` CONSUMES `replay_record` exactly
## once, in `_ready()`, into a private `_replay_record`; the per-tick fork, the live-reload refusal
## and every other consumer read only the private field. A mid-session assignment then has no
## effect — not because it is caught, but because nothing reads what it changed.
##
## SO THIS TEST DOES THE FORBIDDEN THING AND MEASURES THAT NOTHING HAPPENS. It assigns a POISONED
## record — one whose recorded reload event #1 would slam `max_hp` to an unmistakable value on the
## first replayed tick, and which carries a recorded contact fact and camera basis for that tick —
## to the public member of a runner that is MID-MATCH, then keeps playing and checks:
##
##   [THE FORK DOES NOT FLIP] `max_hp` in live state is still the AUTHORED value, READ BEFORE THE
##     RELOAD TRIGGER BELOW FIRES. A flipped fork runs `replay_apply_reloads_before(state, 1)` on
##     its very next tick, which applies recorded event #1 — the single most visible thing a
##     wrongly-entered replay does to a live match. The reading's PLACEMENT is load-bearing and was
##     found by mutation at this pass: the live reload trigger re-applies the authored balance, so
##     a reading taken only after it stayed silent while the fork was genuinely flipped.
##   [RECORDING CONTINUES] the recorder's tick count keeps advancing one per ticking frame.
##     `capture_advance` lives in the `else` branch a flipped fork skips, so entering replay
##     mid-session SILENTLY STOPS RECORDING (`3-0d/R2`) — the failure mode that leaves no trace.
##   [THE LIVE RELOAD TRIGGER STILL WORKS] `trigger_live_balance_reload()` refuses outright in
##     replay mode. It still fires, so that consumer reads the private field too.
##
## ~~A FOURTH READING, `_after_max_hp` AT THE FINAL FRAME, USED TO SIT BESIDE THE THIRD.~~ **IT IS
## DELETED AT `3-0d/R25`, AND IT IS DELETED RATHER THAN KEPT BECAUSE IT WAS VACUOUS — IN THE ONE
## FILE THAT IS THE MECHANISM, WHICH IS THE WORST PLACE FOR A VACUOUS ASSERTION.** It was the
## UN-FIXED TWIN of the defect the previous pass caught for the earlier reading, and it survived
## that pass for the same reason it was written: it LOOKS like reinforcement ("...and still is at
## the end of the run"). It is not. MEASURED at `3-0d/R25` by re-running the falsifying mutation:
## with the fork restored to the public member, this run prints
## `max_hp authored=100.000000 before=100.000000 poisoned-check=1234.000000 after=100.000000` —
## the poisoned value is genuinely in live state at POISON_CHECK_FRAME and GONE by MEASURE_FRAME,
## because TRIGGER_FRAME sits between them and the trigger re-applies the AUTHORED balance. The
## assertion therefore held while the fork was flipped and could not fail for the reason it named.
## Keeping a vacuous assertion as "extra confidence" is what `3-0d/R20` calls a guard believed to
## hold that does not; the two readings that DO fire (poisoned-check, and the frozen tick count)
## are the whole tripwire, and they are enough.
##
## THE TRIPWIRE IS ONE CHANNEL WIDE, AND THAT IS STATED RATHER THAN IMPLIED (`3-0d/R25`). The
## poisoned record drives all THREE replay channels, but only ONE of them is observable here:
##   * THE RELOAD EVENT is observable — `max_hp` goes to POISON_MAX_HP. This is the tripwire.
##   * THE CONTACT FACT produces NOTHING. `_resolve_contacts` calls
##     `attacker.hero.register_swing_hit(...)`, which returns false when the attacker has no
##     registered swing (`hero_state.gd:228-230`), and the poison record's attacker is IDLE — the
##     fact is DROPPED at resolution, no damage, no `hit_landed`. Verified by content.
##   * THE CAMERA BASIS is INERT. A basis only rotates a non-zero `move_dir`, and both live
##     keyboards press nothing in a headless run, so the recorded basis changes no observable.
## Making the other two observable was WEIGHED AND REJECTED at `3-0d/R25`: it would mean authoring
## a swinging attacker and pressed intents into a test whose claim is about a FORK, for a second
## and third witness to a thing one witness already proves loudly. The claim is verified, stated,
## and left alone.
##
## FALSIFYING CHANGE, obvious and real: restore ANY consumer to the public member — the per-tick
## `if replay_record != null:` fork above all — and this test goes red. That is what makes it the
## mechanism rather than a description of one. Proven by mutation at this pass.
##
## WHAT THIS TEST DOES NOT COVER, and what does: the LEGITIMATE pre-tree assignment, which is how
## replay is entered and must keep working. That is `test/integration/test_replay_contacts.gd`,
## which assigns `replay_record` BEFORE the runner enters the tree and asserts a real replay. Both
## run in this suite; the pair is the whole contract — pre-tree works, mid-session does nothing.
##
## Run: godot --headless --path . --script res://test/integration/test_replay_entry_is_inert.gd

## Unmistakable, and nothing like the authored value — a poisoned reload landing in live state is
## the loudest single symptom of a wrongly-entered replay.
const POISON_MAX_HP := 1234.0
const POISON_SEED := 99999

const BASELINE_FRAME := 4
const ASSIGN_FRAME := 8
## MEASURED BEFORE THE TRIGGER, and that ordering is load-bearing rather than incidental: the live
## reload trigger re-applies the AUTHORED balance, so a poisoned max_hp that a flipped fork had
## already applied would be scrubbed back to the authored value before any later reading saw it.
## Found by mutation at this pass — the first version of this test took its only max_hp reading
## AFTER the trigger and stayed silent while the fork was genuinely flipped.
const POISON_CHECK_FRAME := 10
const TRIGGER_FRAME := 12
const MEASURE_FRAME := 24
const DONE_FRAME := 26

var _frames := 0
var _runner: Node
var _failures: Array[String] = []
var _hp_probe: Dictionary = {}

var _authored_max_hp := -1.0
var _before_max_hp := -1.0
var _poisoned_max_hp := -1.0
var _after_max_hp := -1.0
var _before_ticks := -1
var _after_ticks := -1
var _before_frame := -1
var _after_frame := -1
var _before_reloads := -1
var _after_reloads := -1
var _assigned := false


func _initialize() -> void:
	root.add_child(load("res://src/main/main.tscn").instantiate())


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node("Main")
		_authored_max_hp = _max_hp("authored", _capture_authored)
	if _frames == BASELINE_FRAME:
		# NON-VACUITY: the poisoned value must not be what live state already carries, or "max_hp
		# did not change" would be satisfied by a fork that flipped and applied it.
		_check(_authored_max_hp != POISON_MAX_HP,
			"the poisoned max_hp (%f) differs from the authored one (%f), so the assertion below "
					% [POISON_MAX_HP, _authored_max_hp] + "can actually fail")
		_check(_authored_max_hp > 0.0, "live state carries an authored max_hp (got %f)" % _authored_max_hp)
	if _frames == ASSIGN_FRAME:
		_before_max_hp = _max_hp("before", _capture_before)
		_before_ticks = _runner.recorded_stream().tick_count()
		_before_reloads = _runner.recorded_stream().reload_event_count()
		_before_frame = _frames
		# THE FORBIDDEN ASSIGNMENT, made in the plainest possible form — a bare assignment to the
		# public member, mid-match, on a runner whose two slots are live keyboards. Under the
		# deleted source scan this exact line was the thing being hunted; it is now simply inert.
		_runner.replay_record = _poison_record()
		_assigned = true
	if _frames == POISON_CHECK_FRAME:
		_poisoned_max_hp = _max_hp("poisoned", _capture_poisoned)
	if _frames == TRIGGER_FRAME:
		# The live reload trigger refuses outright IN REPLAY MODE. It must still fire, which is how
		# this test reaches that consumer as well as the per-tick fork.
		_runner.trigger_live_balance_reload()
	if _frames == MEASURE_FRAME:
		_after_max_hp = _max_hp("after", _capture_after)
		_after_ticks = _runner.recorded_stream().tick_count()
		_after_reloads = _runner.recorded_stream().reload_event_count()
		_after_frame = _frames
	if _frames >= DONE_FRAME:
		_evaluate()
	return false


## A record built to be MAXIMALLY DISRUPTIVE if it were ever consumed: reload event #1 stamped at
## tick 0 (so `replay_apply_reloads_before` applies it on replayed tick 1, the first one), plus a
## recorded camera basis and a recorded contact fact for that same tick, so every channel the
## replay fork drains has something to inject.
func _poison_record() -> IntentRecorder:
	var record := IntentRecorder.new()
	record.capture_seed(POISON_SEED)
	var poison := _poison_config()
	record.capture_apply_balance(poison)   # event #0 — match start, applied by the caller
	record.capture_apply_balance(poison)   # event #1 at tick 0 — applied on replayed tick 1
	record.capture_inject_feature_flags(FeatureFlags.new())
	var deck: Array[StringName] = [&"poison_card"]
	record.capture_inject_deck(deck)
	var costs: Dictionary[StringName, CardCastCondition] = {}
	costs[&"poison_card"] = CardCastCondition.new()
	record.capture_inject_card_costs(costs)
	# Story 4-1 (`4-1/R1`): the third content channel — a v2 record without it is malformed at the
	# capture seam, and this fixture's whole point is that it is a WELL-FORMED record that must
	# nonetheless never be replayed.
	var effects: Dictionary[StringName, CardEffect] = {}
	var poison_effect := CardEffect.new()
	poison_effect.effect_id = &"summon_poison"
	effects[&"poison_card"] = poison_effect
	record.capture_inject_card_effects(effects)
	# Story 5-2 (`5-2/R1`): the fourth content channel — a v7 record without it is malformed at the
	# capture seam, and this fixture's whole point is that it is a WELL-FORMED record that must
	# nonetheless never be replayed.
	var colors: Dictionary[StringName, Enums.CardColor] = {}
	colors[&"poison_card"] = Enums.CardColor.GREEN
	record.capture_inject_card_colors(colors)
	# Story 6-2 (AC 16): the fifth content channel — a v9 record without it is malformed at the capture
	# seam. An EMPTY map is a legal capture for this channel (AC 2), which is all a record that must never
	# be replayed needs.
	var pitch_costs: Dictionary[StringName, CardCastCondition] = {}
	record.capture_inject_pitch_costs(pitch_costs)
	record.capture_set_camera_basis(0, Basis(Vector3.UP, deg_to_rad(90.0)))
	record.capture_push_contact([0, -1], [1, -1], 0, Vector2(-1, 0), MatchState.CONTACT_STRIKE)
	for _tick in 4:
		var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
		record.capture_advance(intents)
	return record


## The poisoned config, built from IN-TEST LITERALS rather than read off BalanceConfigService — the
## standing golden-isolation discipline (authored balance is isolated from the tests, so a tuning
## pass moves no test), and the autoload is not compile-visible to a `--script` SceneTree anyway.
## Every field is set because `apply_balance` swaps the WHOLE BalanceTicks object; only `max_hp`
## carries the poison, which is what makes the observation below a single named number.
func _poison_config() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.max_hp = POISON_MAX_HP
	c.move_speed = 7.0
	c.max_stamina = 30.0
	c.stamina_regen_per_second = 60.0
	c.stamina_regen_delay_seconds = 2.0 / 60.0
	c.roll_stamina_cost = 8.0
	c.attack_stamina_cost = 4.0
	c.attack_windup_seconds = 3.0 / 60.0
	c.attack_active_seconds = 4.0 / 60.0
	c.attack_recovery_seconds = 5.0 / 60.0
	c.attack_chain_window_seconds = 4.0 / 60.0
	c.attack_chain_length = 3
	c.attack_damage_percent_of_max_hp = 20.0
	c.max_mana = 60.0
	c.melee_hit_mana = 12.0
	c.deck_size = 1
	c.hand_size = 1
	c.block_damage_multiplier = 0.5
	c.deflect_window_seconds = 3.0 / 60.0
	c.block_facing_arc_degrees = 180.0
	c.roll_iframe_seconds = 2.0 / 60.0
	c.roll_duration_seconds = 5.0 / 60.0
	return c


## P1's max_hp, read through the runner's own primed observation seam (`connect_hero_hp_changed`
## invokes its callback once, immediately, with the current pair) — so this test reads live state
## through a shipped seam and never holds a MatchState handle.
##
## One DISTINCT method per reading, not one method bound three ways: Godot's connect() dedups on
## the callable's method, so a `.bind()`d re-connect is refused as already connected.
func _max_hp(tag: String, probe: Callable) -> float:
	_hp_probe[tag] = -1.0
	_runner.connect_hero_hp_changed(0, probe)
	return _hp_probe[tag]


func _capture_authored(_current: float, maximum: float) -> void:
	_hp_probe["authored"] = maximum


func _capture_before(_current: float, maximum: float) -> void:
	_hp_probe["before"] = maximum


func _capture_poisoned(_current: float, maximum: float) -> void:
	_hp_probe["poisoned"] = maximum


func _capture_after(_current: float, maximum: float) -> void:
	_hp_probe["after"] = maximum


func _evaluate() -> void:
	_check(_assigned, "the mid-session assignment was actually made")
	# [THE FORK DOES NOT FLIP]
	_check(_before_max_hp == _authored_max_hp,
		"live state carried the authored max_hp before the assignment (%f vs %f)"
				% [_before_max_hp, _authored_max_hp])
	_check(_poisoned_max_hp == _authored_max_hp,
		"THE FORK DID NOT FLIP: %d ticking frames after `replay_record` was assigned mid-match — and "
				% (POISON_CHECK_FRAME - ASSIGN_FRAME)
		+ "BEFORE the live reload trigger can scrub it — live max_hp is still the AUTHORED %f, not "
				% _authored_max_hp
		+ "the recorded %f that a replayed tick 1 applies. Got %f"
				% [POISON_MAX_HP, _poisoned_max_hp])
	# ~~_check(_after_max_hp == _authored_max_hp, "...and still is at the end of the run")~~ —
	# DELETED AT `3-0d/R25` as VACUOUS; the docstring says why, and `_after_max_hp` is still MEASURED
	# and PRINTED below so the value stays visible to a human without pretending to be a guard.
	# [RECORDING CONTINUES]
	_check(_after_ticks - _before_ticks == _after_frame - _before_frame,
		"RECORDING CONTINUED at one tick per ticking frame across the assignment: %d ticks over %d "
				% [_after_ticks - _before_ticks, _after_frame - _before_frame]
		+ "frames. A flipped fork skips the `else` branch capture_advance lives in and the count "
		+ "would have FROZEN at %d — the failure mode that leaves no trace (`3-0d/R2`)" % _before_ticks)
	_check(_before_ticks > 0, "...and the stream was already running before it (%d ticks)" % _before_ticks)
	# [THE LIVE RELOAD TRIGGER STILL WORKS]
	_check(_before_reloads == 1,
		"before the trigger the stream carries only the match-start reload event (got %d)"
				% _before_reloads)
	_check(_after_reloads == _before_reloads + 1,
		"THE LIVE RELOAD TRIGGER STILL FIRED after the assignment (%d -> %d events). It refuses "
				% [_before_reloads, _after_reloads]
		+ "outright in replay mode, so this consumer reads the consumed private record too")
	_finish()


func _finish() -> void:
	print("replay entry inertness: max_hp authored=%f before=%f poisoned-check=%f after=%f (poison=%f)"
			% [_authored_max_hp, _before_max_hp, _poisoned_max_hp, _after_max_hp, POISON_MAX_HP])
	print("recording: ticks %d->%d over frames %d->%d  reload_events %d->%d" % [
		_before_ticks, _after_ticks, _before_frame, _after_frame, _before_reloads, _after_reloads])
	for f in _failures:
		print("FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
