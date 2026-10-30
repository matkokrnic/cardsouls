extends SceneTree

## Story 7-11 (R6, G4, AC 12-14): THE THREE HAND LAYOUTS, the armed rise/frame rule per layout and the arm-hint
## blink, driven on a STANDALONE HudRoot at the shipped 960x1080 half -- no match, no runner. The layout and the
## direction -> slot map are pushed exactly as the runner pushes them (`set_hand_layout`, plain values); the
## runner -> HUD half (the shipped default, the per-slot override, the keyboard ROW, the own-HUD blink) is
## `test_hand_layout_live.gd`.
##
## What is asserted is GEOMETRY and STATE (`PROC/R8`): where each card rests, which badge arm is lit, whether rects
## overlap or leave the half, whether the pulse shows. Whether a badge or the DIAMOND READS is the operator smoke.
##
## Run: godot --headless --path . --script res://test/integration/test_hand_layouts.gd

const ROW := GamepadProfile.HandLayout.ROW
const ROW_GLYPH := GamepadProfile.HandLayout.ROW_GLYPH
const DIAMOND := GamepadProfile.HandLayout.DIAMOND
const DEFAULT_MAP: Array[int] = [0, 1, 2, 3]     # left, up, down, right -> slot
const SWAPPED_MAP: Array[int] = [3, 1, 2, 0]     # left and right swapped

const CARD_EFFECTS := {
	&"card_a": [&"rocksling", &"boom"],
	&"card_b": [&"boom", &"rocksling"],
	&"card_c": [&"drain", &"vampiric_aura"],
	&"card_d": [&"grave_ward", &"raise_dead"],
}

var _hud: HudRoot
var _ok := true
var _checks := 0
var _frames := 0
var _blink_phase := 0
var _blink_clock := 0.0
var _saw_peak := false
var _saw_swell := false


func _initialize() -> void:
	_hud = HudRoot.new()
	_hud.set_effect_art(CARD_EFFECTS, load(EffectIconSet.AUTHORED_PATH) as EffectIconSet)
	root.add_child(_hud)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_ok = false
		print("FAIL: " + what)


func _card(i: int) -> Panel:
	return _hud.get_node("HandStrip/Card%d" % i) as Panel


func _local(card: Control, node: Control) -> Rect2:
	var r := node.get_global_rect()
	return Rect2(r.position - card.get_global_rect().position, r.size)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# The shipped half (`test_hud_viewports.gd`'s 1920x1080 split in two); set once the main loop runs -- a size set
		# in `_initialize` does not survive the headless window's first configure. Checked once anchors settle.
		root.size = Vector2i(960, 1080)
	if _frames == 4:
		var colors := {&"card_a": Enums.CardColor.RED, &"card_b": Enums.CardColor.BLUE,
				&"card_c": Enums.CardColor.GREEN, &"card_d": Enums.CardColor.GREEN}
		var prices := {&"card_a": [4.0, {}, 3.0, {Enums.CardColor.RED: 1}], &"card_b": [2.0, {}, 5.0, {}],
				&"card_c": [2.0, {}, 5.0, {Enums.CardColor.GREEN: 1}], &"card_d": [2.0, {}, 6.0, {}]}
		var ids := [&"card_a", &"card_b", &"card_c", &"card_d"]
		_hud.on_cards_changed(ids, 20, 0, [], colors, prices, ids)
		_check_row_default()
		_check_row_glyph()
		_check_diamond()
		_hud.set_hand_layout(ROW_GLYPH, DEFAULT_MAP)
		_check(not _hud.arm_hint_blinking(), "AC 14: the hint shows before any blink")
		_check(is_equal_approx(HudRoot.ARM_HINT_BLINK_SEC, 0.4), "G4: the blink is not one ~0.4 s pulse")
		_hud.blink_arm_hint()
		_blink_phase = 1
		_blink_clock = 0.0
	return false


func _process(delta: float) -> bool:
	if _blink_phase != 1:
		return false
	_blink_clock += delta
	if _hud.arm_hint_blinking():
		_saw_peak = true
		var badge := _card(0).get_node("DpadBadge") as Control
		_saw_swell = _saw_swell or badge.scale.x > 1.05
		var swollen := _local(_card(0), badge)   # pinned at its bottom edge; 0.01 px absorbs the scale's float error
		_check(not swollen.grow(-0.01).intersects(_face()), "S1: the swelling badge %s reaches the card face" % swollen)
		_check(_blink_clock <= HudRoot.ARM_HINT_BLINK_SEC + 0.1,
				"AC 14: the pulse is still showing at %.2f s (one ~0.4 s pulse)" % _blink_clock)
	if _blink_clock >= HudRoot.ARM_HINT_BLINK_SEC + 0.25:
		_blink_phase = 2
		_check(_saw_peak, "AC 14: blink_arm_hint showed no pulse")
		_check(_saw_swell, "AC 14: the ROW+GLYPH badges did not swell with the pulse")
		_check(not _hud.arm_hint_blinking() and not (_card(0).get_node("ArmHint") as Control).visible,
				"AC 14: the hint frame outlived its pulse")
		_check((_card(0).get_node("DpadBadge") as Control).scale == Vector2.ONE, "AC 14: a badge stayed swollen")
		print("hand_layouts: %d checks, ok=%s" % [_checks, _ok])
		print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
		quit(0 if _ok else 1)
	return false


## Nothing pushed (a keyboard / replay slot): ROW -- today's arc, no badge.
func _check_row_default() -> void:
	for i in 4:
		_check(_hud.badge_direction(i) == -1, "AC 12: default ROW shows a badge on slot %d" % i)
	_check_arc("default ROW")


## The arc (P9): outer cards at rest 0, the middle pair `ARC_RAISE_PX` higher, `CARD_GAP` apart.
func _check_arc(label: String) -> void:
	for i in 4:
		var want := Vector2(i * (HudRoot.CARD_SIZE.x + HudRoot.CARD_GAP), -HudRoot.ARC_RAISE_PX if i in [1, 2] else 0.0)
		_check(_card(i).position.is_equal_approx(want), "%s: slot %d rests at %s, want %s" % [label, i,
				_card(i).position, want])


## ROW+GLYPH: the arc unchanged plus one badge per card lighting the direction that arms it -- following the map
## (swapping left and right swaps the two outer badges); the badge sits off the card face (smoke fix S1) and draws no
## text and no texture; the armed card rises 24 px with its gold frame.
func _check_row_glyph() -> void:
	_hud.set_hand_layout(ROW_GLYPH, DEFAULT_MAP)
	_check_arc("ROW+GLYPH")
	var dirs: Array = []
	for i in 4:
		dirs.append(_hud.badge_direction(i))
	_check(dirs == [0, 1, 2, 3], "AC 12: default-map badges %s, want left/up/down/right [0, 1, 2, 3]" % [dirs])
	_hud.set_hand_layout(ROW_GLYPH, SWAPPED_MAP)
	dirs.clear()
	for i in 4:
		dirs.append(_hud.badge_direction(i))
	_check(dirs == [3, 1, 2, 0], "AC 12: left/right-swapped badges %s, want [3, 1, 2, 0]" % [dirs])
	_check_arc("ROW+GLYPH (swapped map)")
	for i in 4:
		_check_badge_geometry(i)
	_hud.set_card_selection(1, Enums.ModeKind.BASIC)
	_check(is_equal_approx(_hud.card_lift(1), HudRoot.CARD_MODE_ARMED_LIFT_PX)
			and _hud.highlight_width(1) == HudRoot.ARMED_FRAME_PX, "G4: ROW+GLYPH's armed card does not rise 24 px framed")
	_check(is_equal_approx(_hud.card_lift(0), 0.0) and _hud.highlight_width(0) == 0, "G4: an unarmed card moved")
	_hud.set_card_selection(-1, Enums.ModeKind.BASIC)
	_hud.set_hand_layout(ROW, DEFAULT_MAP)
	for i in 4:
		_check(_hud.badge_direction(i) == -1, "AC 12: an explicit ROW push still shows slot %d's badge" % i)
	_hud.set_card_selection(2, Enums.ModeKind.BASIC)
	_check(is_equal_approx(_hud.card_lift(2), HudRoot.CARD_MODE_ARMED_LIFT_PX), "G4: ROW's armed card does not rise")
	_hud.set_card_selection(-1, Enums.ModeKind.BASIC)


## Smoke fix S1: the card's FACE -- everything inside its frame band. The badge must stay off it.
func _face() -> Rect2:
	var frame := float(HudRoot.CARD_FRAME_PX)
	return Rect2(Vector2(frame, frame), HudRoot.CARD_SIZE - Vector2(frame, frame) * 2.0)


## Every laid-out HUD element besides the hand, by name, as global rects -- plus the history strip MIRRORED to the
## right edge (`history_on_left` false, the other half's place), which this standalone root never builds.
func _others() -> Array:
	var out: Array = []
	for name in ["Vitals", "OwnPitch", "OpponentPitch", "HistoryStrip", "DeckIndicator", "OrbCounters",
			"RoundOverLabel"]:
		out.append([name, (_hud.get_node(name) as Control).get_global_rect()])
	var hist := (_hud.get_node("HistoryStrip") as Control).get_global_rect()
	out.append(["HistoryStrip(right)", Rect2(_hud.size.x - hist.end.x, hist.position.y, hist.size.x, hist.size.y)])
	return out


## Smoke fix S1 (AC 12): the badge is a child of its card, OFF the card face (on the top frame band, hanging above),
## inside the half, clear of every other HUD element and every other card -- at rest and armed (it follows the rise).
func _check_badge_geometry(i: int) -> void:
	var card := _card(i)
	var badge := card.get_node("DpadBadge") as Control
	var br := _local(card, badge)
	_check(badge.get_parent() == card, "AC 12 slot %d: the badge is no longer a child of its card" % i)
	_check(not br.intersects(_face()), "S1 slot %d: the badge %s sits on the card face %s" % [i, br, _face()])
	for armed: bool in [false, true]:
		_hud.set_card_selection(i if armed else -1, Enums.ModeKind.BASIC)
		var g := badge.get_global_rect()
		var tag := "armed" if armed else "at rest"
		_check(Rect2(Vector2.ZERO, _hud.size).encloses(g), "S1 slot %d (%s): the badge %s leaves the half" % [i, tag, g])
		for o: Array in _others():
			_check(not g.intersects(o[1]), "S1 slot %d (%s): the badge %s overlaps %s %s" % [i, tag, g, o[0], o[1]])
		for j in 4:
			if j != i:
				_check(not g.intersects(_card(j).get_global_rect()),
						"S1 slot %d (%s): the badge %s overlaps card %d" % [i, tag, g, j])
		if i == 0 and not armed:
			print("S1 measured: slot 0's badge at %s in the half (card %s)" % [g, card.get_global_rect()])
	_hud.set_card_selection(-1, Enums.ModeKind.BASIC)
	var parts: Array[Control] = [card.get_node("Divider"), card.get_node("KeywordSlot"),
			card.get_node("PitchHalf/Pips")]
	for half: String in ["NormalHalf", "PitchHalf"]:
		parts.append(card.get_node("%s/Cost" % half))
		parts.append(card.get_node("%s/ArtBack" % half))
		parts.append(card.get_node("%s/Art" % half))
	for part: Control in parts:
		var pr := _local(card, part)
		_check(not br.intersects(pr), "AC 12 slot %d: the badge %s overlaps %s %s" % [i, br, part.name, pr])
	_check(badge.find_children("*", "Label", true, false).is_empty()
			and badge.find_children("*", "TextureRect", true, false).is_empty(),
			"AC 12 slot %d: the badge carries text or a texture (procedural, text-free)" % i)
	_check(card.get_index() == i and (_hud.get_node("HandStrip") as Node).get_child_count() == 4,
			"AC 12: the hand strip no longer holds exactly the four cards")


## DIAMOND (smoke fix S2): a whole alternate arrangement of the half. Each card at its direction's D-pad position (up
## over down in one column, left and right beside it at one height) -- following the map -- with the diamond flush in
## the bottom-left corner (`DIAMOND_EDGE_PX` in); the vitals in the diamond's lower-right notch (below the RIGHT card,
## right of the DOWN card); the pitch zones stacked in the bottom-right corner, own above opponent's. Everything
## inside the half and nothing overlapping anything. No badge. Back to ROW, every element returns to its ROW place.
## Then S3 per direction: `_check_diamond_armed`.
func _check_diamond() -> void:
	var row_rects := {}
	for name in ["HandStrip", "Vitals", "OwnPitch", "OpponentPitch"]:
		row_rects[name] = (_hud.get_node(name) as Control).get_global_rect()
	var vp := Rect2(Vector2.ZERO, _hud.size)
	var edge := HudRoot.DIAMOND_EDGE_PX
	for map: Array[int] in [DEFAULT_MAP, SWAPPED_MAP]:
		_hud.set_hand_layout(DIAMOND, map)
		var at: Array[Rect2] = []   # by DIRECTION
		for d in 4:
			at.append(_card(map[d]).get_global_rect())
		var left := at[0]
		var up := at[1]
		var down := at[2]
		var right := at[3]
		_check(is_equal_approx(up.position.x, down.position.x) and up.end.y <= down.position.y,
				"DIAMOND %s: up %s is not stacked over down %s" % [map, up, down])
		_check(is_equal_approx(left.position.y, right.position.y) and left.end.x <= up.position.x
				and right.position.x >= up.end.x, "DIAMOND %s: left %s / right %s do not flank the column" % [map, left, right])
		_check(left.position.y > up.position.y and left.end.y < down.end.y,
				"DIAMOND %s: the sides are not between up and down" % [map])
		_check(is_equal_approx(left.position.x, edge) and is_equal_approx(down.end.y, vp.size.y - edge),
				"S2 %s: the diamond is not flush in the bottom-left corner (left %s, down %s, edge %s)" % [map, left, down,
				edge])
		for i in 4:
			_check(_hud.badge_direction(i) == -1, "DIAMOND %s: slot %d shows a badge" % [map, i])
		var vitals := (_hud.get_node("Vitals") as Control).get_global_rect()
		var own := (_hud.get_node("OwnPitch") as Control).get_global_rect()
		var opp := (_hud.get_node("OpponentPitch") as Control).get_global_rect()
		_check(vitals.position.y >= right.end.y and vitals.position.x >= down.end.x
				and vitals.position.x < right.end.x and vitals.end.y <= vp.size.y,
				"S2 %s: the vitals %s are not in the notch below the right card %s, right of the down card %s"
				% [map, vitals, right, down])
		_check(is_equal_approx(own.position.x, opp.position.x) and own.end.y <= opp.position.y
				and is_equal_approx(opp.end.x, vp.size.x - edge) and is_equal_approx(opp.end.y, vp.size.y - edge),
				"S2 %s: the zones (own %s, opponent %s) are not stacked own-over-opponent in the bottom-right corner"
				% [map, own, opp])
		_check(own.size == row_rects["OwnPitch"].size and opp.size == row_rects["OpponentPitch"].size
				and vitals.size == row_rects["Vitals"].size, "S2 %s: DIAMOND resized the vitals or a zone" % [map])
		var glow := float(HudRoot.ARMED_GLOW_PX)
		var placed: Array = [["Vitals", vitals], ["OwnPitch", own], ["OpponentPitch", opp]]
		for a in 4:
			placed.append(["card(direction %d)" % a, at[a].grow(glow)])
		_check_placed(placed, "S2 %s" % [map])
		if map == DEFAULT_MAP:
			print("S2 measured: left %s up %s down %s right %s | vitals %s | own zone %s | opponent zone %s"
					% [left, up, down, right, vitals, own, opp])
		_check_diamond_armed(map)
	_hud.set_hand_layout(ROW, DEFAULT_MAP)
	_check_arc("ROW after DIAMOND")
	for name: String in row_rects:
		var now := (_hud.get_node(name) as Control).get_global_rect()
		_check(now.is_equal_approx(row_rects[name]), "S2: back in ROW, %s sits at %s, want its ROW place %s" % [name,
				now, row_rects[name]])


## S2: every rect in `placed` ([name, rect]) inside the half, no two of them overlapping, and none overlapping any
## other laid-out HUD element (`_others`, minus the ones `placed` re-measures).
func _check_placed(placed: Array, label: String) -> void:
	var vp := Rect2(Vector2.ZERO, _hud.size)
	var names: Array = []
	for p: Array in placed:
		names.append(p[0])
		_check(vp.encloses(p[1]), "%s: %s %s leaves the half %s" % [label, p[0], p[1], vp])
	for a in placed.size():
		for b in range(a + 1, placed.size()):
			_check(not (placed[a][1] as Rect2).intersects(placed[b][1]), "%s: %s %s overlaps %s %s" % [label,
					placed[a][0], placed[a][1], placed[b][0], placed[b][1]])
		for o: Array in _others():
			if o[0] in names:
				continue
			_check(not (placed[a][1] as Rect2).intersects(o[1]), "%s: %s %s overlaps %s %s" % [label, placed[a][0],
					placed[a][1], o[0], o[1]])


## Smoke fix S3 (G4 refined): no rise in DIAMOND. Armed by each direction in turn, the armed card is pushed OUTWARD
## `DIAMOND_ARMED_PUSH_PX` along its own direction, framed gold, undimmed; the other three rest, dimmed to
## `DIAMOND_UNARMED_DIM`; the pushed card (glow included) stays inside the half and clear of everything. Nothing
## armed: all four at rest, undimmed.
func _check_diamond_armed(map: Array[int]) -> void:
	var push := HudRoot.DIAMOND_ARMED_PUSH_PX
	var outward: Array[Vector2] = [Vector2(-push, 0.0), Vector2(0.0, -push), Vector2(0.0, push), Vector2(push, 0.0)]
	_check(is_equal_approx(push, 12.0) and is_equal_approx(HudRoot.DIAMOND_UNARMED_DIM, 0.8),
			"S3: the push / dim constants are not the ruled 12 px / 0.8")
	for d in 4:
		var armed := map[d]
		_hud.set_card_selection(armed, Enums.ModeKind.BASIC)
		for i in 4:
			if i == armed:
				_check(_hud.card_offset(i).is_equal_approx(outward[d]) and _hud.highlight_width(i) == HudRoot.ARMED_FRAME_PX
						and is_equal_approx(_hud.card_tone(i), 1.0),
						"S3 %s: direction %d's armed card is offset %s (want %s), frame %d, tone %s" % [map, d,
						_hud.card_offset(i), outward[d], _hud.highlight_width(i), _hud.card_tone(i)])
			else:
				_check(_hud.card_offset(i) == Vector2.ZERO and is_equal_approx(_hud.card_tone(i), HudRoot.DIAMOND_UNARMED_DIM)
						and _hud.highlight_width(i) == 0, "S3 %s: with direction %d armed, slot %d is offset %s, tone %s"
						% [map, d, i, _hud.card_offset(i), _hud.card_tone(i)])
		var placed: Array = [["Vitals", (_hud.get_node("Vitals") as Control).get_global_rect()],
				["OwnPitch", (_hud.get_node("OwnPitch") as Control).get_global_rect()],
				["OpponentPitch", (_hud.get_node("OpponentPitch") as Control).get_global_rect()]]
		for i in 4:
			placed.append(["card %d" % i, _card(i).get_global_rect().grow(float(HudRoot.ARMED_GLOW_PX))])
		_check_placed(placed, "S3 %s direction %d armed" % [map, d])
	_hud.set_card_selection(-1, Enums.ModeKind.BASIC)
	for i in 4:
		_check(_hud.card_offset(i) == Vector2.ZERO and is_equal_approx(_hud.card_tone(i), 1.0),
				"S3 %s: nothing armed, slot %d is offset %s, tone %s" % [map, i, _hud.card_offset(i), _hud.card_tone(i)])
