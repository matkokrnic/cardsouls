extends SceneTree

## Story 7-5a (AC 37, AC 50, AC 51): THE PLACEHOLDER BUFF MARKERS AND THE DISCOUNTED COST, on the real
## `main.tscn`. The state is armed directly (the mechanics themselves are covered headless in
## `test/state/test_deck_2_*.gd`); what this file checks is the PRESENTATION READ -- that after each gain,
## spend and counter the hero's marker line and the hand's cost text show the right thing, through the
## runner's existing post-`advance()` push and the existing `cards_changed` seam (no new seam: the seam
## count is pinned by `test_architecture_invariants.gd`).
##
## Each step writes state, waits two physics frames (one for the runner's tick and push, one of margin),
## then reads the hero's `BuffMarkers` line.
##
## Run: godot --headless --path . --script res://test/integration/test_buff_markers_live.gd

const SETTLE_FRAMES := 2

var _frames := 0
var _step := -1
var _step_frame := 0
var _runner: Node
var _failures: Array[String] = []
var _checks := 0
var _cost_before := ""
var _pitch_cost_before := ""


func _initialize() -> void:
	_check_text_builder()
	_runner = load("res://src/main/main.tscn").instantiate()
	_runner.seed_override = 12345
	root.add_child(_runner)


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(label)


## AC 50 [M]: the text builder, with no scene -- distinct tokens, counts, and absence at zero.
func _check_text_builder() -> void:
	_check(BuffMarkers.text_for(0, 0, 0, 0, false) == "", "nothing held: an empty line")
	_check(BuffMarkers.text_for(2, 0, 0, 0, false) == "SET 2", "two Setups read as a COUNT of 2")
	_check(BuffMarkers.text_for(1, 2, 3, 4, true) == "SET 1  EXE 2  STN 3  ENR 4  LIFE",
		"all five, each a distinct token, the four stacking ones with their counts")
	_check(BuffMarkers.text_for(0, 0, 0, 0, true) == "LIFE", "Lifechain shows while covered, with no count")
	var tokens := [BuffMarkers.TOKEN_SETUP, BuffMarkers.TOKEN_EXECUTE, BuffMarkers.TOKEN_STONESKIN,
			BuffMarkers.TOKEN_ENRAGE, BuffMarkers.TOKEN_LIFECHAIN]
	for a in tokens.size():
		for b in tokens.size():
			if a != b:
				_check(tokens[a] != tokens[b], "the five markers are distinct from one another")


func _p1() -> PlayerState:
	return _runner._match_state.p1


func _p2() -> PlayerState:
	return _runner._match_state.p2


func _line(slot: int) -> String:
	var hero: HeroActor = _runner._p1_hero if slot == 0 else _runner._p2_hero
	return hero.buff_markers.text()


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _step < 0:
		if _frames < 4:
			return false   # let _ready and the deal land
		_advance_step()
		return false
	if _frames - _step_frame < SETTLE_FRAMES:
		return false
	_read_step()
	return false


## Write the state for the next step.
func _advance_step() -> void:
	_step += 1
	_step_frame = _frames
	var p1 := _p1()
	match _step:
		0:
			pass   # the resting read
		1:
			p1.add_setup_charge(2.0)
			p1.add_setup_charge(2.0)
		2:
			p1.spend_setup_charge()   # a spend
		3:
			p1.add_execute_charge(3.0)
			p1.add_stoneskin_charge()
		4:
			p1.open_enrage(600, 2.0)
			p1.open_enrage(600, 2.0)
		5:
			p1.end_enrage_at(0)   # a counter ends that cast's own window
		6:
			p1.open_lifechain(600)
		7:
			p1.end_lifechain_at(0)
			p1.spend_setup_charge()
			p1.spend_execute_charge()
			p1.spend_stoneskin_charge()
			p1.end_enrage_at(1)
		8:
			# The discounted cost: slot 0 of P1's hand, announced through the existing seam.
			var hud: HudRoot = _runner._huds[0]
			_cost_before = hud.card_cost_text(0, 0)
			_pitch_cost_before = hud.card_cost_text(0, 1)
			p1.hand.add_discount_at(0, 1.0)
			p1.notify_cards_changed()
		9:
			p1.hand.clear_discounts()
			p1.notify_cards_changed()
		_:
			_finish()


func _read_step() -> void:
	var hud: HudRoot = _runner._huds[0]
	match _step:
		0:
			_check(_line(0) == "" and _line(1) == "", "at rest neither hero shows a marker: '%s' / '%s'"
				% [_line(0), _line(1)])
			_check(not _runner._p1_hero.buff_markers.visible, "...and the marker node is hidden")
		1:
			_check(_line(0) == "SET 2", "after two Setups P1's marker reads 2: '%s'" % _line(0))
			_check(_line(1) == "", "P2's marker is untouched by P1's charges: '%s'" % _line(1))
			_check(_runner._p1_hero.buff_markers.visible, "the marker is shown while a buff is held")
		2:
			_check(_line(0) == "SET 1", "after a spend the count drops to 1: '%s'" % _line(0))
		3:
			_check(_line(0) == "SET 1  EXE 1  STN 1", "Execute and Stoneskin join the line: '%s'" % _line(0))
		4:
			_check(_line(0) == "SET 1  EXE 1  STN 1  ENR 2", "two Enrage windows read 2: '%s'" % _line(0))
		5:
			_check(_line(0) == "SET 1  EXE 1  STN 1  ENR 1",
				"a countered Enrage drops its count step, the other window stays: '%s'" % _line(0))
		6:
			_check(_line(0).ends_with("LIFE"), "Lifechain shows while covered: '%s'" % _line(0))
		7:
			_check(_line(0) == "", "every marker disappears when its state ends: '%s'" % _line(0))
		8:
			_check(_cost_before != "" and _cost_before.is_valid_int(),
				"fixture: slot 0 shows a whole mana cost before the discount ('%s')" % _cost_before)
			var want := str(maxi(0, int(_cost_before) - 1))
			_check(hud.card_cost_text(0, 0) == want,
				"AC 37: the discounted NORMAL cost is shown (%s -> %s, got '%s')"
				% [_cost_before, want, hud.card_cost_text(0, 0)])
			if _pitch_cost_before.is_valid_int():
				var want_pitch := str(maxi(0, int(_pitch_cost_before) - 1))
				_check(hud.card_cost_text(0, 1) == want_pitch,
					"AC 37: the discounted PITCH cost is shown (%s -> %s, got '%s')"
					% [_pitch_cost_before, want_pitch, hud.card_cost_text(0, 1)])
			_check(hud.is_slot_discounted(0), "AC 50: the discounted card is MARKED")
			_check(not hud.is_slot_discounted(1), "...and an undiscounted card is not")
			_check(not (_runner._huds[1] as HudRoot).is_slot_discounted(0),
				"the OTHER seat's HUD shows no discount -- each HUD reads its own hand")
		9:
			_check(hud.card_cost_text(0, 0) == _cost_before, "the full cost returns when the discount ends")
			_check(not hud.is_slot_discounted(0), "...and so does the mark")
	_advance_step()


func _finish() -> void:
	_runner.free()
	_runner = null
	if _failures.is_empty():
		print("buff_markers: %d checks, all held" % _checks)
		print("RESULT: PASS")
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("RESULT: FAIL")
		quit(1)
