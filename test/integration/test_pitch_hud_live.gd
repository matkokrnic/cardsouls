extends SceneTree

## Story 6-3b (AC 3): EACH HudRoot RENDERS ITS OWN PITCH ZONE AND THE OPPONENT'S, AND NEVER CROSSES THEM,
## through the one new delivery path -- the runner's match-level `connect_pitch_changed` seam, wired
## identically into BOTH roots with each root's own slot BOUND at wiring. The cross-wire risk is that
## own-slot filter, so both directions are asserted against a staging that is DIFFERENT on each side.
##
## WHY A SYNTHETIC REPLAY RECORD. The shipped keyboard controllers have no PITCH path, and the only PITCH
## producer (GamepadController) goes neutral without a connected joypad. So the route is:
##   [PROBE]  `main.tscn` live with default controllers and no input, ticked past the deal (step 6 of
##            the first advance()). Read both hands through `debug_hand_contents()` and the recorded
##            match-start content through `recorded_stream()`, then tear down.
##            Choose P1 hand slot `a` holding id X and P2 hand slot `b` holding id Y != X; no such pair
##            FAILS the test (never skips).
##   [RECORD] A new IntentRecorder built channel by channel as test_replay_contacts.gd's
##            `_without_contacts` does -- seed, balance event #0, flags, deck, card costs, effects and
##            colours copied from the probe -- with the PITCH-COST channel AUTHORED HERE: X costs
##            mana 0 and no orbs (READY at staging), Y costs mana 0 and RED 1 (NOT READY, orbs start
##            at 0). The same seed and deck replay the same deal (injecting pitch costs consumes no RNG).
##            Intents are neutral except tick 2, where P1 stages slot `a` and P2 stages slot `b`.
##   [REPLAY] The record assigned to `replay_record` BEFORE add_child; HUD wiring is not replay-gated.
##
## NON-VACUITY FIRST: this test's own listener on the seam must have seen owner 0 with X and owner 1
## with Y, X != Y, with DIFFERENT READY values (true for X, false for Y -- which needs the record's flags
## to carry `orbs = true`, as the probe-copied authored flags do; flags built in-test would default orbs
## OFF and read both READY, passing every id assertion vacuously), and both staged hand slots EMPTY.
## Only then the rendering assertions, both directions, plus the headless form of "no orb count is
## shown": no Label inside either zone of either root contains a digit (authored card ids carry none).
##
## Run: godot --headless --path . --script res://test/integration/test_pitch_hud_live.gd

const DEADLINE := 600
const PROBE_FRAMES := 6
const REPLAY_FRAMES := 12
const STAGE_TICK := 2
const RECORD_TICKS := 4

var _frames := 0
var _phase := "probe"
var _phase_start := 0
var _scene: Node
var _runner: Node3D
var _payloads: Array = []
var _failures: Array[String] = []

var _x: StringName
var _y: StringName
var _slot_a := -1
var _slot_b := -1


func _initialize() -> void:
	pass


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)


func _begin(record: IntentRecorder) -> void:
	var scene: Node = load("res://src/main/main.tscn").instantiate()
	if record != null:
		scene.replay_record = record
	root.add_child(scene)
	_scene = scene
	_runner = scene as Node3D
	_payloads = []
	_runner.connect_pitch_changed(
		func(slot: int, card_id: StringName, hand_slot: int, ready: bool, remaining: int,
				duration: int) -> void:
			_payloads.append([slot, card_id, hand_slot, ready, remaining, duration]))
	_phase_start = _frames


func _teardown() -> void:
	root.remove_child(_scene)
	_scene.queue_free()
	_scene = null
	_runner = null


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames >= DEADLINE:
		_failures.append("deadline reached in phase %s" % _phase)
		_finish()
		return false
	if _frames == 1:
		root.size = Vector2i(1152, 648)
		_begin(null)
		return false
	var elapsed := _frames - _phase_start
	match _phase:
		"probe":
			if elapsed < PROBE_FRAMES:
				return false
			var hands: Array = _runner.debug_hand_contents()
			var record: IntentRecorder = _runner.recorded_stream()
			_teardown()
			if not _choose_pair(hands):
				_finish()
				return false
			_phase = "replay"
			_begin(_build_record(record))
		"replay":
			if elapsed < REPLAY_FRAMES:
				return false
			_evaluate()
	return false


## X from P1's hand and Y != X from P2's, both real ids.
func _choose_pair(hands: Array) -> bool:
	var p1: Array = hands[0]
	var p2: Array = hands[1]
	for a in p1.size():
		if p1[a] == Hand.EMPTY:
			continue
		for b in p2.size():
			if p2[b] != Hand.EMPTY and p2[b] != p1[a]:
				_slot_a = a
				_slot_b = b
				_x = p1[a]
				_y = p2[b]
				return true
	_failures.append("the probed deal holds no P1 id X and P2 id Y != X: %s" % str(hands))
	return false


func _build_record(src: IntentRecorder) -> IntentRecorder:
	var out := IntentRecorder.new()
	out.capture_seed(src.replay_seed())
	out.capture_apply_balance(src.replay_balance_config(0))
	out.capture_inject_feature_flags(src.replay_feature_flags())
	out.capture_inject_deck(src.replay_deck_contents())
	out.capture_inject_card_costs(src.replay_card_costs())
	out.capture_inject_card_effects(src.replay_card_effects())
	out.capture_inject_card_colors(src.replay_card_colors())
	var ready_cost := CardCastCondition.new()
	ready_cost.mana_cost = 0.0
	var short_cost := CardCastCondition.new()
	short_cost.mana_cost = 0.0
	short_cost.orb_costs[Enums.CardColor.RED] = 1
	var pitch_costs: Dictionary[StringName, CardCastCondition] = {_x: ready_cost, _y: short_cost}
	out.capture_inject_pitch_costs(pitch_costs)
	# Story 6-5a (AC 6): the sixth content channel -- no pitch effects, which is legal.
	var pitch_effects: Dictionary[StringName, CardEffect] = {}
	out.capture_inject_pitch_effects(pitch_effects)
	for t in range(1, RECORD_TICKS + 1):
		var intents: Array[InputIntent] = [InputIntent.new(), InputIntent.new()]
		if t == STAGE_TICK:
			intents = [_stage_intent(_slot_a), _stage_intent(_slot_b)]
		out.capture_advance(intents)
	return out


func _stage_intent(hand_slot: int) -> InputIntent:
	var i := InputIntent.new()
	i.card_slot = hand_slot
	i.card_mode = Enums.ModeKind.PITCH
	i.card_commit = true
	i.card_activate = false
	return i


func _evaluate() -> void:
	# NON-VACUITY PRECONDITION, asserted first; the rendering assertions below run only if it holds.
	var own0 := _payloads.filter(func(p: Array) -> bool: return p[0] == 0 and p[1] == _x)
	var own1 := _payloads.filter(func(p: Array) -> bool: return p[0] == 1 and p[1] == _y)
	var hands: Array = _runner.debug_hand_contents()
	var pre: bool = (_x != _y and not own0.is_empty() and not own1.is_empty()
		and own0[0][3] == true and own1[0][3] == false
		and hands[0][_slot_a] == Hand.EMPTY and hands[1][_slot_b] == Hand.EMPTY)
	_check(pre, "precondition: owner 0 staged %s READY and owner 1 staged %s NOT READY, both hand slots "
		% [_x, _y] + "empty -- payloads %s, hands %s" % [str(_payloads), str(hands)])
	if pre:
		var p1_hud: Node = _scene.get_node("P1View/P1Viewport/HudRoot")
		var p2_hud: Node = _scene.get_node("P2View/P2Viewport/HudRoot")
		_assert_root(p1_hud, "P1", _x, true, _y, false, _slot_a)
		_assert_root(p2_hud, "P2", _y, false, _x, true, _slot_b)
	_teardown()
	_finish()


func _assert_root(hud: Node, who: String, own_card: StringName, own_ready: bool,
		opp_card: StringName, opp_ready: bool, own_slot: int) -> void:
	_check(_zone(hud, "OwnPitch") == [String(own_card), own_ready],
		"%s own zone shows %s / READY=%s: got %s" % [who, own_card, own_ready, _zone(hud, "OwnPitch")])
	_check(_zone(hud, "OpponentPitch") == [String(opp_card), opp_ready],
		"%s opponent zone shows %s / READY=%s: got %s" % [who, opp_card, opp_ready,
				_zone(hud, "OpponentPitch")])
	var row := _row(hud)
	_check(row[own_slot] == [String(own_card), true],
		"%s hand slot %d shows the ghost of %s: got %s" % [who, own_slot, own_card, str(row)])
	for i in row.size():
		_check(not (row[i][1] and row[i][0] == String(opp_card)),
			"%s hand slot %d shows no ghost of the opponent's %s: got %s" % [who, i, opp_card, str(row)])
	var digit := RegEx.create_from_string("[0-9]")
	for zone_name in ["OwnPitch", "OpponentPitch"]:
		for label: Label in hud.get_node(zone_name).find_children("*", "Label", true, false):
			_check(digit.search(label.text) == null,
				"%s %s label %s shows no number: \"%s\"" % [who, zone_name, label.name, label.text])


## [card caption, READY visible].
func _zone(hud: Node, zone_name: String) -> Array:
	return [(hud.get_node("%s/Card" % zone_name) as Label).text,
		(hud.get_node("%s/Ready" % zone_name) as Label).visible]


## Each hand slot as [caption, is a ghost].
func _row(hud: Node) -> Array:
	var out: Array = []
	for i in 4:
		var caption: Label = hud.get_node("HandStrip/Card%d/CardName" % i)
		out.append([caption.text, is_equal_approx(caption.modulate.a, HudRoot.GHOST_MODULATE.a)])
	return out


func _finish() -> void:
	print("pitch_hud_live: X=%s (P1 slot %d) Y=%s (P2 slot %d) payloads=%d" % [_x, _slot_a, _y, _slot_b,
		_payloads.size()])
	for f in _failures:
		print("FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
