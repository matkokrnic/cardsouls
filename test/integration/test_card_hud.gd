extends SceneTree

## Story 3-6: the CARD HUD, driven end to end through the live scene — the runner's eighth
## observation seam -> HudRoot.on_cards_changed -> real card captions and a real deck count, plus
## the reshuffle flag's raise-and-self-clear.
##
## WHY AN INTEGRATION TEST. The suite's standing blind spot is that it proves state contracts and
## authored data AT REST but is blind to "the seam fires and the consumer swallows it". The state
## half of this channel is fully proven headless (test_card_observation.gd); a unit test on
## HudRoot would prove the labels can be written and would still pass if the runner never wired
## the seam, wired it to the wrong slot, or wired it after construction. This drives the real
## chain, against the real authored composition, and would catch all three.
##
## NOTHING HERE HARDCODES AN AUTHORED NUMBER (BC/R3): the deck count is asserted to be a real
## count that replaced the placeholder, never "16", so a tuning edit to deck_size or hand_size
## moves this test's expectations with it instead of breaking it. The one authored value it does
## read — the vulnerable-window duration — is read FROM the config, not written down here.
##
## STATED LIMIT, so it is not overclaimed: the reshuffle flag is exercised by emitting the
## ownerless bus event, which is exactly the contract AC 4 gives the HUD ("renders from
## EventBus.reshuffle_vulnerable_window_opened alone"). The runner's MatchState -> EventBus relay
## upstream of it is 3-5b's one-line wiring and is NOT what this test proves; driving a real
## exhaustion through the live scene would need thousands of frames of fed mana and would prove
## the economy, not the render.
##
## Run: godot --headless --path . --script res://test/integration/test_card_hud.gd
## (read ${PIPESTATUS[0]} / set -o pipefail so grep can't mask the exit code.)

const CONFIG_PATH := "res://data/balance/balance_config.tres"
const OBSERVE_FRAME := 4
const FLAG_FRAME := 8

var _frames := 0
var _p1_hud: Node
var _p2_hud: Node
var _clear_deadline := 0

var _huds_exist := false
var _opponent_row_deleted := false
var _captions_populated := false
var _hands_differ := false
var _deck_count_live := false
var _vacated_slot_cleared := false
var _refill_rewrote_the_slot := false
var _flag_hidden_initially := false
var _flag_raised_both_ways := false
var _flag_cleared_itself := false
var _detail := ""


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_p1_hud = root.get_node_or_null("Main/P1View/P1Viewport/HudRoot")
		_p2_hud = root.get_node_or_null("Main/P2View/P2Viewport/HudRoot")
		_huds_exist = _p1_hud != null and _p2_hud != null
		if not _huds_exist:
			print("HUD roots missing: p1=%s p2=%s" % [_p1_hud, _p2_hud])
			print("RESULT: FAIL")
			quit(1)
			return false
		# AC 1: the opponent row is DELETED, not hidden. get_node_or_null finds hidden nodes too,
		# so this is a deletion assertion rather than a visibility one.
		_opponent_row_deleted = (_p1_hud.get_node_or_null("OpponentHandStrip") == null
			and _p2_hud.get_node_or_null("OpponentHandStrip") == null)
		# The flag is not shown until an event says so — a flag that starts visible would make the
		# raise assertion below pass without the event ever being handled.
		_flag_hidden_initially = (not _flag_label(_p1_hud).visible) and (not _flag_label(_p2_hud).visible)
	if _frames == OBSERVE_FRAME:
		# The deal lands at step 6 of the FIRST advance() and is announced on the same tick, so by
		# now both roots have received a real payload through the seam.
		var p1_captions := _captions(_p1_hud)
		var p2_captions := _captions(_p2_hud)
		# AC 1/AC 6: every slot of the own row carries a real card id as text — the row is face-up
		# and READABLE, which is the whole claim. An empty caption means the seam never arrived or
		# the payload never reached the labels.
		_captions_populated = _all_non_empty(p1_captions) and _all_non_empty(p2_captions)
		if not _captions_populated:
			_detail += " p1_captions=%s p2_captions=%s;" % [p1_captions, p2_captions]
		# AC 2 / 2-4/R7, the per-slot binding proof by ASYMMETRY (the stamina-bar mechanism in
		# test_hud_viewports.gd): both piles are laid from the SAME composition and shuffled
		# against the SAME generator IN TURN, so the two dealt hands differ. A root wired to the
		# wrong slot — or both roots wired to slot 0 — renders two identical rows and fails here.
		_hands_differ = p1_captions != p2_captions
		# AC 4: the deck read-out is live, not the "DECK --" placeholder, and carries a positive
		# count. Parsed rather than compared to a literal, so authored tuning cannot break it.
		_deck_count_live = _deck_count(_p1_hud) > 0 and _deck_count(_p2_hud) > 0
		if not _deck_count_live:
			_detail += " deck_text=%s/%s;" % [_deck_label(_p1_hud).text, _deck_label(_p2_hud).text]
	if _frames == OBSERVE_FRAME + 1:
		# THE VACATED SLOT (AC 1). While a replacement draw is in flight the hand is SHORT, and the
		# emptied slot must clear — a caption left behind is a card the player can see and cannot
		# cast, which is worse than an empty slot. Driven by handing the callback a shortened
		# payload DIRECTLY rather than by casting: a real cast needs mana the flywheel takes
		# thousands of ticks to build, and what is under test here is the label rule, not the
		# economy. The seam-to-callback path itself is proven by the deal assertions above.
		var live := _captions(_p1_hud)
		var short_hand: Array[StringName] = [
			StringName(live[0]), StringName(live[1]), StringName(live[2])]
		_p1_hud.on_cards_changed(short_hand, 7, 1)
		var after := _captions(_p1_hud)
		_vacated_slot_cleared = after.size() == 4 and after[3] == "" and after[2] == live[2]
		if not _vacated_slot_cleared:
			_detail += " after_short=%s;" % [after]
		# ...and refilling writes it back, so the clear is not a one-way trip.
		_p1_hud.on_cards_changed(_to_ids(live), 6, 1)
		_refill_rewrote_the_slot = _captions(_p1_hud) == live
	if _frames == FLAG_FRAME:
		# AC 4: ONE ownerless event, BOTH viewports, each rendering it against its own slot. Slot 0
		# is vulnerable: P1 must read it as its own, P2 as the opponent's. Two roots showing the
		# SAME text would mean the slot binding was dropped.
		# Reached through the tree, not the autoload identifier — a `--script` SceneTree run does
		# not resolve autoload globals at compile time (test_contact_pipeline.gd's mechanism).
		var bus := root.get_node("/root/EventBus")
		bus.reshuffle_vulnerable_window_opened.emit(0)
	if _frames == FLAG_FRAME + 1:
		var p1_flag := _flag_label(_p1_hud)
		var p2_flag := _flag_label(_p2_hud)
		_flag_raised_both_ways = (p1_flag.visible and p2_flag.visible
			and p1_flag.text != "" and p2_flag.text != "" and p1_flag.text != p2_flag.text)
		if not _flag_raised_both_ways:
			_detail += " p1_flag=%s/%s p2_flag=%s/%s;" % [
				p1_flag.visible, p1_flag.text, p2_flag.visible, p2_flag.text]
		# AC 4: it must turn itself OFF, seeded by the AUTHORED duration — read from the config,
		# never written down here. The margin covers the timer landing on a later frame boundary.
		var config := load(CONFIG_PATH) as BalanceConfig
		_clear_deadline = _frames + int(ceil(config.reshuffle_vulnerable_window_seconds * 60.0)) + 12
	if _clear_deadline > 0 and _frames == _clear_deadline:
		_flag_cleared_itself = (not _flag_label(_p1_hud).visible) and (not _flag_label(_p2_hud).visible)
		var ok: bool = (_huds_exist and _opponent_row_deleted and _captions_populated
			and _hands_differ and _deck_count_live and _vacated_slot_cleared
			and _refill_rewrote_the_slot and _flag_hidden_initially
			and _flag_raised_both_ways and _flag_cleared_itself)
		print("card_hud: huds=%s opp_row_deleted=%s captions=%s hands_differ=%s deck_live=%s vacated_cleared=%s refill_rewrote=%s flag_hidden_initially=%s flag_raised=%s flag_cleared=%s%s" % [
			_huds_exist, _opponent_row_deleted, _captions_populated, _hands_differ,
			_deck_count_live, _vacated_slot_cleared, _refill_rewrote_the_slot,
			_flag_hidden_initially, _flag_raised_both_ways, _flag_cleared_itself, _detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## The four own-row card captions, in row order. Read purely off the live scene tree.
func _captions(hud: Node) -> Array[String]:
	var out: Array[String] = []
	var strip := hud.get_node_or_null("HandStrip")
	if strip == null:
		return out
	for card in strip.get_children():
		var label := card.get_node_or_null("CardName") as Label
		out.append("" if label == null else label.text)
	return out


func _to_ids(captions: Array[String]) -> Array[StringName]:
	var out: Array[StringName] = []
	for c in captions:
		out.append(StringName(c))
	return out


func _all_non_empty(captions: Array[String]) -> bool:
	if captions.size() != 4:
		return false
	for c in captions:
		if c.strip_edges() == "":
			return false
	return true


func _deck_label(hud: Node) -> Label:
	return hud.get_node("DeckIndicator/DeckColumn/DeckCount") as Label


func _flag_label(hud: Node) -> Label:
	return hud.get_node("DeckIndicator/DeckColumn/ReshuffleFlag") as Label


## The number the deck read-out is showing, or -1 while it is still the placeholder.
func _deck_count(hud: Node) -> int:
	var text := _deck_label(hud).text
	var digits := text.get_slice(" ", 1)
	return int(digits) if digits.is_valid_int() else -1
