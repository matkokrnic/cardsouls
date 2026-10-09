extends SceneTree

## Story 7-6 (R1-R6, R8; AC 5, 7-12, 14-17, 21-23, 25, 30-32): the redesigned own-hand CARD FACE, the
## affordability states, the Boulder cover's highlight suppression, the play-history strip and the HP display,
## driven on a STANDALONE HudRoot -- no match, no runner. The payloads are hand-built exactly as the runner's
## wrappers shape them, so each property is pinned against a known input rather than whatever a seed deals.
##
## What is asserted is GEOMETRY and STATE (`PROC/R8`): which rects exist, where, and whether they overlap;
## which texture, text, modulate and highlight each slot carries. Whether the face READS at half width is the
## operator smoke (AC 6, 13, 18, 20, 22, 24, 32).
##
## THE FIXTURE CARDS ARE FAKE IDS ON REAL EFFECTS. `card_a` and `card_b` carry the SAME two effects in opposite
## halves -- AC 11's re-pairing, in one payload. The art table is the real authored one.
##
## Run: godot --headless --path . --script res://test/integration/test_card_face.gd

const RED := Enums.CardColor.RED
const BLUE := Enums.CardColor.BLUE
const GREEN := Enums.CardColor.GREEN
const COLORLESS := Enums.CardColor.COLORLESS

const CARD_EFFECTS := {
	&"card_a": [&"rocksling", &"boom"],
	&"card_b": [&"boom", &"rocksling"],
	&"card_c": [&"drain", &"vampiric_aura"],
	&"card_d": [&"grave_ward", &"raise_dead"],
	&"boulder": [&"boulder_discard", &""],
}

var _hud: HudRoot
var _icons: EffectIconSet
var _ok := true
var _checks := 0
var _frames := 0
var _colors := {}
var _prices := {}


func _initialize() -> void:
	_icons = load(EffectIconSet.AUTHORED_PATH) as EffectIconSet
	_colors = {&"card_a": RED, &"card_b": BLUE, &"card_c": GREEN, &"card_d": GREEN, &"boulder": COLORLESS}
	_prices = {
		&"card_a": [4.0, {}, 3.0, {RED: 1}],
		&"card_b": [2.0, {}, 5.0, {BLUE: 1}],
		&"card_c": [2.0, {}, 5.0, {GREEN: 1, RED: 1}],
		&"card_d": [2.0, {}, 6.0, {RED: 2}],
		&"boulder": [2.0, {}, 0.0, {}],
	}
	_hud = HudRoot.new()
	_hud.set_effect_art(CARD_EFFECTS, _icons)
	root.add_child(_hud)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_ok = false
		print("FAIL: " + what)


func _hand(ids: Array, under: Array = [], owed: Array = []) -> void:
	_hud.on_cards_changed(ids, 20, 0, owed, _colors, _prices, under if not under.is_empty() else ids)


func _card(i: int) -> Panel:
	return _hud.get_node("HandStrip/Card%d" % i) as Panel


func _half(i: int, h: int) -> Control:
	return _card(i).get_node("NormalHalf" if h == 0 else "PitchHalf") as Control


## A descendant's rect in its CARD's own space.
func _local(card: Control, node: Control) -> Rect2:
	var r := node.get_global_rect()
	return Rect2(r.position - card.get_global_rect().position, r.size)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_run()
	elif _frames == 3:
		_check_stale_fizzle()
		# Review fix (m5): the flash-restart check, clocked on the IDLE delta the tweens themselves advance by (not
		# wall time -- early headless frames carry large deltas). Restart at the first flash's half-life, then check
		# the moment the first tween is no longer valid: unkilled, that is when its `hide` has just run.
		_flash_phase = 1
		_flash_clock = 0.0
		_hud._flash_slot(3)
	elif _flash_phase > 0:
		var flash := _card(3).get_node("PlayFlash") as Control
		if _flash_phase == 1 and _flash_clock >= HudRoot.PLAY_FLASH_SECONDS * 0.5:
			_flash_phase = 2
			_first_flash = _hud._tweens[flash.get_instance_id()]
			_hud._flash_slot(3)
		elif _flash_phase == 2 and not _first_flash.is_valid():
			# The FIRST tween is over (killed by the restart, or -- unkilled -- finished with its `hide`); the second
			# is mid-fade, so the slot must still be showing.
			_check(flash.visible and flash.modulate.a > 0.0,
					"m5: a restarted flash was hidden by the first flash's tween (alpha %.2f)" % flash.modulate.a)
			# 7-6 POLISH (operator ruling P4): a FRESH flash on slot 0 -- full strength, glowing, held, and still
			# showing at 0.5 s of tween time (the pre-polish flash was gone at 0.4 s).
			_hud._flash_slot(0)
			var flash0 := _card(0).get_node("PlayFlash") as Control
			var glow := (flash0.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size
			_check(is_equal_approx(flash0.modulate.a, 1.0) and glow > 0,
					"P4: the flash does not start at full strength with a glow (alpha %.2f, glow %d)" % [flash0.modulate.a, glow])
			_flash_phase = 3
			_flash_clock = 0.0
		elif _flash_phase == 3 and _flash_clock >= 0.04 and not _held_checked:
			_held_checked = true
			var flash0 := _card(0).get_node("PlayFlash") as Control
			_check(flash0.modulate.a > 0.95, "P4: the flash is not held at full strength (alpha %.2f at %.2f s)"
					% [flash0.modulate.a, _flash_clock])
		elif _flash_phase == 3 and _flash_clock >= 0.5:
			var flash0 := _card(0).get_node("PlayFlash") as Control
			_check(flash0.visible and flash0.modulate.a > 0.1,
					"P4: the flash is gone by %.2f s (alpha %.2f) -- not longer than before" % [_flash_clock, flash0.modulate.a])
			_start_reel_check()
	elif _reel_phase == 1:
		_seen_reel_art[(_card(1).get_node("Reel/ReelArt") as TextureRect).texture] = true
		if _reel_clock >= 0.6:
			_finish_reel_check()
	return false


## 7-6 POLISH 2 (operator ruling P13): THE SLOT REEL. A slot waiting for its replacement spins through this player's
## deck art (several different arts over 0.6 s), a blank (not owed) slot never spins, and the delivered card LANDS:
## the reel stops and hides, the face shows the real card, and the card settles from a touch large. Knob off = no reel.
var _reel_phase := 0
var _reel_clock := 0.0
var _seen_reel_art := {}


func _start_reel_check() -> void:
	_flash_phase = 0
	_hud.set_reel_cards([&"card_a", &"card_b", &"card_c", &"card_d"])
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])
	_hand([&"card_a", Hand.EMPTY, Hand.EMPTY, &"card_d"], [], [1])   # slot 1 owed, slot 2 a dead hole
	_check(_hud.is_slot_reeling(1) and (_card(1).get_node("Reel") as Control).visible, "P13: an owed slot does not spin")
	_check(not _hud.is_slot_reeling(2), "P13: a permanently empty (not owed) slot spins")
	_check(not (_card(1).get_node("CardName") as Control).visible, "P13: the in-flight glyph shows over the reel")
	_reel_phase = 1
	_reel_clock = 0.0


func _finish_reel_check() -> void:
	_reel_phase = 0
	_check(_seen_reel_art.size() >= 3, "P13: the reel did not spin (%d distinct arts in 0.6 s)" % _seen_reel_art.size())
	_hand([&"card_a", &"card_c", Hand.EMPTY, &"card_d"])   # the payload delivers card_c into slot 1
	_check(not _hud.is_slot_reeling(1) and not (_card(1).get_node("Reel") as Control).visible,
			"P13: the reel kept spinning after the card arrived")
	_check((_half(1, 0).get_node("Art") as TextureRect).texture == _icons.texture_for(&"drain"),
			"P13: the slot did not land on the delivered card")
	_check(_card(1).scale.x > 1.0, "P13: the landing has no settle")
	# The knob: off, an owed slot shows no reel.
	_icons.slot_reel_enabled = false
	_hand([&"card_a", Hand.EMPTY, Hand.EMPTY, &"card_d"], [], [1])
	_check(not _hud.is_slot_reeling(1), "P13: the reel spins with its knob off")
	_icons.slot_reel_enabled = true
	print("card_face: %d checks, ok=%s" % [_checks, _ok])
	print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)


var _held_checked := false


func _process(delta: float) -> bool:
	if _flash_phase > 0:
		_flash_clock += delta
	if _reel_phase > 0:
		_reel_clock += delta
	return false


var _flash_phase := 0
var _flash_clock := 0.0
var _first_flash: Tween


## F2: the fizzle in `_check_play_flash` cleared the zone last frame and nothing resolved; its memory must be gone.
func _check_stale_fizzle() -> void:
	var flash2 := _card(2).get_node("PlayFlash") as Control
	_hud.on_card_effect_resolved(0, &"vampiric_aura", true, 0)
	_check(not flash2.visible, "F2: a stale fizzle slot flashed on a later own pitch resolution")
	_hud.on_round_started()


func _run() -> void:
	_hud.on_mana_changed(0.0, 10.0)
	_hud.on_orbs_changed(0, 0, 0)
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])
	_check_face_structure()
	_check_effect_keyed_art()
	_check_affordability()
	_check_swap_moves_nothing()
	_check_colour_never_under_a_cost()
	_check_boulder()
	_check_highlights()
	_check_history()
	_check_pitch_zone_art()
	_check_pitch_speeds()
	_check_hp_display()
	_check_icon_files_and_credits()
	# LAST: its fizzle half leaves the zone-clear memory for `_check_stale_fizzle` on the next frame, and no own
	# resolution may run in between (any own resolution also drops it, which would make that check vacuous).
	_check_play_flash()


## AC 5 / AC 7: two EQUAL halves split by a visible divider; art + cost on top, art + cost + one pip per
## required orb (in that orb's colour) below; an EMPTY reserved keyword node top-right.
func _check_face_structure() -> void:
	for i in 4:
		var card := _card(i)
		var top := _half(i, 0)
		var bottom := _half(i, 1)
		var divider := card.get_node_or_null("Divider") as Control
		_check(top != null and bottom != null and divider != null, "slot %d: halves/divider missing" % i)
		if top == null or bottom == null or divider == null:
			continue
		var tr := _local(card, top)
		var br := _local(card, bottom)
		var dr := _local(card, divider)
		_check(is_equal_approx(tr.size.y, br.size.y) and tr.size.y > 0.0,
				"AC 5 slot %d: halves unequal (%s vs %s)" % [i, tr.size.y, br.size.y])
		_check(divider.visible and dr.size.y > 0.0 and tr.end.y <= dr.position.y + 0.01
				and dr.end.y <= br.position.y + 0.01, "AC 5 slot %d: the divider is not between the halves" % i)
		for h in 2:
			var half := _half(i, h)
			var art := half.get_node("Art") as TextureRect
			var cost := half.get_node("Cost") as Label
			_check(art.texture != null, "AC 5 slot %d half %d: no art" % [i, h])
			_check(cost.text != "", "AC 5 slot %d half %d: no cost" % [i, h])
			var ar := _local(card, art)
			_check(is_equal_approx(ar.size.x, ar.size.y), "R1 slot %d half %d: art slot not square" % [i, h])
		_check(_local(card, top.get_node("Art") as Control).size
				== _local(card, bottom.get_node("Art") as Control).size, "R1 slot %d: the two arts differ in size" % i)
		var keyword := card.get_node_or_null("KeywordSlot") as Control
		_check(keyword != null, "AC 7 slot %d: no reserved slot" % i)
		if keyword != null:
			var kr := _local(card, keyword)
			_check(keyword.get_class() == "Control" and keyword.get_child_count() == 0,
					"AC 7 slot %d: the reserved slot renders content (%s, %d children)" % [i, keyword.get_class(),
					keyword.get_child_count()])
			_check(kr.get_center().x > card.size.x * 0.5 and kr.get_center().y < tr.end.y,
					"AC 7 slot %d: the reserved slot is not top-right (%s)" % [i, kr])
	# The pips: card_c needs one RED and one GREEN (sorted by ordinal), card_d two RED.
	_check(_pips(2) == [RED, GREEN], "AC 5: card_c's pips %s, want [RED, GREEN]" % [_pips(2)])
	_check(_pips(3) == [RED, RED], "AC 5: card_d's pips %s, want [RED, RED]" % [_pips(3)])
	_check(_pips(0) == [RED], "AC 5: card_a's pips %s, want [RED]" % [_pips(0)])
	var pip := _visible_pips(2)[1] as Panel
	_check((pip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == HudRoot.ORB_COLORS[GREEN],
			"AC 5: a GREEN pip is not drawn in the green orb colour")


func _visible_pips(i: int) -> Array:
	var out: Array = []
	for pip: Node in _half(i, 1).get_node("Pips").get_children():
		if (pip as Control).visible:
			out.append(pip)
	return out


func _pips(i: int) -> Array:
	var out: Array = []
	for pip: Node in _visible_pips(i):
		out.append(int(pip.get_meta(&"orb_color")))
	return out


## AC 11: the art is the EFFECT's -- card_a and card_b carry the same two effects in opposite halves, and each
## half shows its own effect's icon.
func _check_effect_keyed_art() -> void:
	var rocksling := _icons.texture_for(&"rocksling")
	var boom := _icons.texture_for(&"boom")
	_check(rocksling != null and boom != null and rocksling != boom, "AC 11: the icon table lacks rocksling/boom")
	_check((_half(0, 0).get_node("Art") as TextureRect).texture == rocksling, "AC 11: card_a top is not rocksling")
	_check((_half(0, 1).get_node("Art") as TextureRect).texture == boom, "AC 11: card_a bottom is not boom")
	_check((_half(1, 0).get_node("Art") as TextureRect).texture == boom, "AC 11: re-paired card_b top is not boom")
	_check((_half(1, 1).get_node("Art") as TextureRect).texture == rocksling,
			"AC 11: re-paired card_b bottom is not rocksling")


## AC 14-16 / 7-6 POLISH (operator ruling P2): each HALF is shown payable (full colour + its glowing rim) exactly
## when its own mana cost is affordable, dimmed and desaturated otherwise -- the two halves independently. No
## affordability state moves a card. Pips fill by count (F3).
func _affordable_row(h: int) -> Array:
	return [_hud.is_half_affordable(0, h), _hud.is_half_affordable(1, h), _hud.is_half_affordable(2, h),
			_hud.is_half_affordable(3, h)]


func _check_affordability() -> void:
	_hud.on_mana_changed(0.0, 10.0)
	_check(_affordable_row(0) == [false, false, false, false] and _affordable_row(1) == [false, false, false, false],
			"P2: a half reads payable at mana 0: %s %s" % [_affordable_row(0), _affordable_row(1)])
	var half := _half(0, 0)
	_check(half.modulate != Color.WHITE and half.modulate.r < 0.7,
			"P2: an unpayable half is not dimmed (%s)" % half.modulate)
	var back_style := (half.get_node("ArtBack") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	var dim_sat := back_style.bg_color.s
	_hud.on_mana_changed(2.0, 10.0)
	_check(_affordable_row(0) == [false, true, true, true], "P2: normal halves at mana 2 (costs 4,2,2,2): %s"
			% [_affordable_row(0)])
	_hud.on_mana_changed(3.0, 10.0)
	# card_a: normal 4 NOT payable, pitch 3 payable -- the halves are independent.
	_check(not _hud.is_half_affordable(0, 0) and _hud.is_half_affordable(0, 1), "P2: card_a at mana 3 (normal no, pitch yes)")
	# card_b: normal 2 payable, pitch 5 not.
	_check(_hud.is_half_affordable(1, 0) and not _hud.is_half_affordable(1, 1), "P2: card_b at mana 3 (normal yes, pitch no)")
	_hud.on_mana_changed(10.0, 10.0)
	_check(_affordable_row(0) == [true, true, true, true] and _affordable_row(1) == [true, true, true, true],
			"P2: a half reads unpayable at mana 10: %s %s" % [_affordable_row(0), _affordable_row(1)])
	_check(half.modulate == Color.WHITE and (half.get_node("Rim") as Control).visible,
			"P2: a payable half is not full colour with its rim")
	_check(back_style.bg_color.s > dim_sat + 0.2, "P2: the unpayable art backing was not desaturated (%.2f vs %.2f)"
			% [dim_sat, back_style.bg_color.s])
	for i in 4:
		_check(is_equal_approx(_hud.card_lift(i), 0.0), "P2: affordability moved slot %d (lift %s)" % [i, _hud.card_lift(i)])
	# 7-6 POLISH 2 (operator ruling P8): the card-colour frame is PERMANENT, as thick as the armed frame, and never
	# dimmed with an unpayable half (it lives outside the halves).
	_hud.on_mana_changed(0.0, 10.0)
	var swatch := _card(0).get_node("ColorSwatch") as Panel
	var sw_style := swatch.get_theme_stylebox("panel") as StyleBoxFlat
	_check(swatch.visible and sw_style.get_border_width(SIDE_TOP) == HudRoot.ARMED_FRAME_PX
			and sw_style.border_color == HudRoot.ORB_COLORS[RED],
			"P8: card_a's colour frame is not a %d px RED frame (%d, %s)" % [HudRoot.ARMED_FRAME_PX,
			sw_style.get_border_width(SIDE_TOP), sw_style.border_color])
	_check(not _hud.is_half_affordable(0, 0) and swatch.modulate == Color.WHITE and _card(0).modulate == Color.WHITE,
			"P8: the colour frame dims with an unpayable half")
	# 7-6 POLISH 2 (operator ruling P9): THE ARC -- slots 2 and 3 (indices 1, 2) rest ARC_RAISE_PX above slots 1 and 4.
	_check(is_equal_approx(_card(0).position.y, 0.0) and is_equal_approx(_card(3).position.y, 0.0)
			and is_equal_approx(_card(1).position.y, -HudRoot.ARC_RAISE_PX)
			and is_equal_approx(_card(2).position.y, -HudRoot.ARC_RAISE_PX) and HudRoot.ARC_RAISE_PX > 0.0,
			"P9: the hand is not an arc (ys %s %s %s %s)" % [_card(0).position.y, _card(1).position.y,
			_card(2).position.y, _card(3).position.y])
	_hud.on_mana_changed(0.0, 10.0)
	_hud.on_orbs_changed(1, 0, 0)
	_check(_pip_lit(2) == [true, false], "AC 16: card_c pips at orbs (1,0,0): %s" % [_pip_lit(2)])
	# Review fix (operator ruling F3): pips FILL BY COUNT -- one red orb lights only the FIRST of two red pips.
	_check(_pip_lit(3) == [true, false], "F3: card_d's two RED pips at one red orb: %s" % [_pip_lit(3)])
	_hud.on_orbs_changed(2, 0, 0)
	_check(_pip_lit(3) == [true, true], "F3: card_d's two RED pips at two red orbs: %s" % [_pip_lit(3)])
	_check(_pip_lit(2) == [true, false], "F3: card_c (RED, GREEN) at orbs (2,0,0): %s" % [_pip_lit(2)])
	_hud.on_orbs_changed(0, 0, 1)
	_check(_pip_lit(2) == [false, true], "AC 16: card_c pips at orbs (0,0,1): %s" % [_pip_lit(2)])
	_check(_pip_lit(0) == [false], "AC 16: card_a pip at orbs (0,0,1): %s" % [_pip_lit(0)])
	# 7-6 POLISH 2 (operator ruling P7): every pip is drawn in its FULL orb colour; a missing orb is a HOLLOW RING
	# with a thick outline, a held one a filled circle.
	var ring := _visible_pips(0)[0] as Panel
	var ring_style := ring.get_theme_stylebox("panel") as StyleBoxFlat
	_check(not ring_style.draw_center and ring_style.get_border_width(SIDE_TOP) >= 3
			and ring_style.border_color == HudRoot.ORB_COLORS[RED] and ring.self_modulate == Color.WHITE,
			"P7: a missing RED orb is not a full-colour hollow ring (center %s, width %d, %s, modulate %s)"
			% [ring_style.draw_center, ring_style.get_border_width(SIDE_TOP), ring_style.border_color, ring.self_modulate])
	_check(_pip_lit(3) == [false, false], "F3: card_d's RED pips at no red orb: %s" % [_pip_lit(3)])
	_hud.on_orbs_changed(0, 0, 0)
	# Review fix (operator ruling F5): the mana NUMBER is the floor, so it and the lift never disagree.
	var mana_label := _hud.get_node("Vitals/MANARow/MANABar/MANAValue") as Label
	for m: float in [0.0, 0.5, 1.5, 1.99, 2.0, 2.4, 3.99, 4.0]:
		_hud.on_mana_changed(m, 10.0)
		var shown := int(mana_label.text.get_slice("/", 0))
		_check(shown == int(floorf(m + HudRoot.AFFORD_EPSILON)), "F5: mana %s displays %s, want the floor" % [m, mana_label.text])
		# card_b costs 2: shown >= 2 exactly when its normal half reads payable (P2).
		_check((shown >= 2) == _hud.is_half_affordable(1, 0), "F5: mana %s shows %d but card_b (cost 2) payable=%s"
				% [m, shown, _hud.is_half_affordable(1, 0)])
	_hud.on_mana_changed(0.0, 10.0)


func _pip_lit(i: int) -> Array:
	var out: Array = []
	for pip: Node in _visible_pips(i):
		# P7: held = a FILLED circle (draw_center), missing = a hollow ring.
		out.append(((pip as Control).get_theme_stylebox("panel") as StyleBoxFlat).draw_center)
	return out


## AC 10: a different card drawn into a slot changes no child's rect, size or anchor -- only textures/text.
func _check_swap_moves_nothing() -> void:
	_hud.on_mana_changed(0.0, 10.0)
	var before := _layout_of(_card(1))
	_hand([&"card_a", &"card_c", &"card_c", &"card_d"])
	var after := _layout_of(_card(1))
	_check(before == after, "AC 10: swapping slot 1's card moved a child")
	_check((_half(1, 0).get_node("Art") as TextureRect).texture == _icons.texture_for(&"drain"),
			"AC 10: the swap did not change the art")
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])


func _layout_of(card: Control) -> Array:
	var out: Array = []
	for node: Node in card.find_children("*", "Control", true, false):
		var c := node as Control
		out.append([c.name, c.position, c.size, c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom])
	return out


## AC 8: the card's colour (frame bands, art backings, the Boulder frame) never shares a rect with a cost.
func _check_colour_never_under_a_cost() -> void:
	for i in 4:
		_check_slot_colour_vs_costs(i)


func _check_slot_colour_vs_costs(i: int) -> void:
	var card := _card(i)
	var coloured: Array[Rect2] = []
	var swatch := card.get_node("ColorSwatch") as Panel
	if swatch.visible:
		coloured.append_array(_frame_bands(_local(card, swatch), swatch.get_theme_stylebox("panel") as StyleBoxFlat))
	for h in 2:
		var back := _half(i, h).get_node("ArtBack") as Control
		if back.visible:
			coloured.append(_local(card, back))
		var rim := _half(i, h).get_node("Rim") as Panel
		if rim.visible:
			coloured.append_array(_frame_bands(_local(card, rim), rim.get_theme_stylebox("panel") as StyleBoxFlat))
	var cover := card.get_node("BoulderCover") as Panel
	if cover.visible:
		coloured.append_array(_frame_bands(_local(card, cover), cover.get_theme_stylebox("panel") as StyleBoxFlat))
		coloured.append(_local(card, cover.get_node("ArtBack") as Control))
	var costs: Array[Control] = [_half(i, 0).get_node("Cost"), _half(i, 1).get_node("Cost")]
	if cover.visible:
		costs.append(cover.get_node("Cost") as Control)
	_check(not coloured.is_empty(), "AC 8 slot %d: no coloured rect found (vacuous)" % i)
	for cost: Control in costs:
		if not cost.is_visible_in_tree() or (cost as Label).text == "":
			continue
		var cr := _local(card, cost)
		for col: Rect2 in coloured:
			_check(not cr.intersects(col), "AC 8 slot %d: cost %s %s overlaps colour %s" % [i, cost.get_path(), cr, col])


## The four border bands a StyleBoxFlat draws inside `rect` (border grows inward).
func _frame_bands(rect: Rect2, style: StyleBoxFlat) -> Array[Rect2]:
	var l := float(style.get_border_width(SIDE_LEFT))
	var t := float(style.get_border_width(SIDE_TOP))
	var r := float(style.get_border_width(SIDE_RIGHT))
	var b := float(style.get_border_width(SIDE_BOTTOM))
	return [Rect2(rect.position, Vector2(l, rect.size.y)),
			Rect2(Vector2(rect.end.x - r, rect.position.y), Vector2(r, rect.size.y)),
			Rect2(rect.position, Vector2(rect.size.x, t)),
			Rect2(Vector2(rect.position.x, rect.end.y - b), Vector2(rect.size.x, b))]


## AC 9 / R4 / AC 20-21's headless half: a Boulder over card_a in slot 0 -- grey frame (not an orb colour),
## its own art and cost on the cover, card_a faint beneath, and its slot carries no highlight.
func _check_boulder() -> void:
	_hand([&"boulder", &"card_b", &"card_c", &"card_d"], [&"card_a", &"card_b", &"card_c", &"card_d"])
	var card := _card(0)
	var swatch_style := (card.get_node("ColorSwatch") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	_check(swatch_style.border_color == HudRoot.COLORLESS_SWATCH and swatch_style.bg_color == HudRoot.COLORLESS_SWATCH,
			"AC 9: Boulder's frame is not COLORLESS_SWATCH (%s)" % swatch_style.border_color)
	_check(not HudRoot.ORB_COLORS.has(swatch_style.border_color), "AC 9: Boulder's frame is an orb colour")
	var cover := card.get_node("BoulderCover") as Panel
	_check(cover.visible, "R4: no Boulder cover on the covered slot")
	_check(((cover.get_theme_stylebox("panel")) as StyleBoxFlat).border_color == HudRoot.COLORLESS_SWATCH,
			"AC 9: the cover's frame is not COLORLESS_SWATCH")
	_check((cover.get_node("Art") as TextureRect).texture == _icons.texture_for(&"boulder_discard"),
			"R4: the cover does not show Boulder's own art")
	_check((cover.get_node("Cost") as Label).text == "2", "R4: the cover does not show Boulder's cost")
	_check((_half(0, 0).get_node("Art") as TextureRect).texture == _icons.texture_for(&"rocksling")
			and _half(0, 0).modulate.a < 1.0 and _half(0, 0).modulate.a > 0.0,
			"R4: the covered card_a is not faintly visible beneath")
	_check_slot_colour_vs_costs(0)
	# P2 on a covered slot: the Boulder's own cost dims or lights the COVER.
	_hud.on_mana_changed(0.0, 10.0)
	_check(cover.modulate != Color.WHITE, "P2: an unpayable Boulder cover is not dimmed")
	_hud.on_mana_changed(2.0, 10.0)
	_check(cover.modulate == Color.WHITE, "P2: a payable Boulder cover is dimmed")
	_hud.on_mana_changed(0.0, 10.0)
	# AC 21 / 7-6 POLISH 3 (operator ruling P17): a Boulder-covered slot ARMS EXACTLY LIKE ANY OTHER CARD -- its frame
	# turns gold and, in card mode, it takes the row lift and rises to the armed lift.
	_hud.set_card_selection(0, Enums.ModeKind.BASIC)
	_check(_hud.highlight_width(0) == HudRoot.ARMED_FRAME_PX, "P17: the armed covered slot shows no gold frame")
	_hud.set_card_mode(true)
	_check(_hud.highlight_width(0) == HudRoot.ARMED_FRAME_PX
			and is_equal_approx(_hud.card_lift(0), HudRoot.CARD_MODE_ARMED_LIFT_PX),
			"P17: the armed covered slot is not lifted and gold-framed (lift %s)" % _hud.card_lift(0))
	_check(is_equal_approx(_hud.card_lift(1), HudRoot.CARD_MODE_ROW_LIFT_PX),
			"AC 21 control: an uncovered slot did not take the row lift")
	_hud.set_card_selection(1, Enums.ModeKind.BASIC)
	_check(_hud.highlight_width(1) == HudRoot.ARMED_FRAME_PX and is_equal_approx(_hud.card_lift(1),
			HudRoot.CARD_MODE_ARMED_LIFT_PX), "AC 21 control: an uncovered armed slot has no frame or lift")
	_hud.set_card_mode(false)
	_hud.set_card_selection(-1, Enums.ModeKind.BASIC)
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])
	_check(not (_card(0).get_node("BoulderCover") as Control).visible, "R4: the cover outlived the uncover")


## AC 17 / 7-6 POLISH (operator ruling P3): card mode lifts the whole row a little, the armed card clearly higher
## with a strong frame drawn outside the card; lifts only while card mode is on (a card never lifts alone), the
## frame whenever armed. All of it is independent of affordability (P2): the three states stay distinguishable.
func _check_highlights() -> void:
	_hud.on_mana_changed(10.0, 10.0)
	for i in 4:
		_check(is_equal_approx(_hud.card_lift(i), 0.0) and _hud.highlight_width(i) == 0,
				"P3: slot %d lifted or framed with mode off and nothing armed" % i)
	_hud.set_card_mode(true)
	for i in 4:
		_check(is_equal_approx(_hud.card_lift(i), HudRoot.CARD_MODE_ROW_LIFT_PX) and _hud.highlight_width(i) == 0,
				"P3: card mode did not lift slot %d by the row lift (%s)" % [i, _hud.card_lift(i)])
	_hud.set_card_selection(2, Enums.ModeKind.BASIC)
	_check(is_equal_approx(_hud.card_lift(2), HudRoot.CARD_MODE_ARMED_LIFT_PX)
			and _hud.highlight_width(2) == HudRoot.ARMED_FRAME_PX, "P3: the armed card is not lifted high and framed")
	_check(HudRoot.CARD_MODE_ARMED_LIFT_PX >= 3.0 * HudRoot.CARD_MODE_ROW_LIFT_PX,
			"P3: the armed lift is not clearly higher than the row lift")
	for i in [0, 1, 3]:
		_check(is_equal_approx(_hud.card_lift(i), HudRoot.CARD_MODE_ROW_LIFT_PX) and _hud.highlight_width(i) == 0,
				"P3: unarmed slot %d is not at the row lift without a frame" % i)
	# AC 17: payable (P2) and armed (P3) co-exist on one card without collapsing into one look.
	_check(_hud.is_half_affordable(2, 0) and _hud.highlight_width(2) > 0, "AC 17: a payable card cannot also be armed")
	# 7-6 POLISH 3 (operator ruling P14): ONE frame per card, CARD_FRAME_PX thick in the card's own colour; arming turns
	# THAT frame gold with a glow -- no second frame node exists.
	var armed_style := (_card(2).get_node("ColorSwatch") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	_check(armed_style.border_color == HudRoot.ARMED_FRAME_COLOR and armed_style.get_border_width(SIDE_TOP)
			== HudRoot.CARD_FRAME_PX and armed_style.shadow_size > 0, "P14: the armed card's own frame is not gold")
	var plain_style := (_card(1).get_node("ColorSwatch") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	_check(plain_style.border_color != HudRoot.ARMED_FRAME_COLOR and plain_style.get_border_width(SIDE_TOP)
			== HudRoot.CARD_FRAME_PX and HudRoot.CARD_FRAME_PX >= 6, "P14: an unarmed card's frame is not its own %d px frame"
			% HudRoot.CARD_FRAME_PX)
	for i in 4:
		_check(_card(i).get_node_or_null("Highlight") == null, "P14: slot %d still carries a second frame node" % i)
	# The 6-10 hold shape: mode off with a slot still armed -- the frame alone, no lone lift.
	_hud.set_card_mode(false)
	_check(_hud.highlight_width(2) == HudRoot.ARMED_FRAME_PX and is_equal_approx(_hud.card_lift(2), 0.0),
			"P3: mode off + armed must show the frame and no lone lift (lift %s)" % _hud.card_lift(2))
	_hud.set_card_selection(-1, Enums.ModeKind.BASIC)
	for i in 4:
		_check(is_equal_approx(_hud.card_lift(i), 0.0) and _hud.highlight_width(i) == 0, "P3: slot %d did not return to rest" % i)
	_hud.on_mana_changed(0.0, 10.0)


## R5 / AC 22's headless half: a card leaving its slot for the in-flight look starts that slot's flash.
func _check_play_flash() -> void:
	var flash := _card(2).get_node("PlayFlash") as Control
	_check(not flash.visible, "R5: a flash is showing before any play")
	_hand([&"card_a", &"card_b", Hand.EMPTY, &"card_d"], [], [2])
	_check(flash.visible and flash.modulate.a > 0.0, "R5: casting from slot 2 did not flash it")
	_check(not (_card(1).get_node("PlayFlash") as Control).visible, "R5: an unplayed slot flashed")
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])
	_reset_flashes()
	# Review fix (operator ruling F2), in the LIVE drain order: stage card_c from slot 2 (hand hole, then the zone),
	# then ACTIVATE (zone clear, then the owed-slot hand payload, then the own pitch resolution off the bus).
	var flash2 := _card(2).get_node("PlayFlash") as Control
	_hand([&"card_a", &"card_b", Hand.EMPTY, &"card_d"])
	_hud.on_pitch_changed(0, &"card_c", 2, false, 100, 100, {}, 0)
	_hud.on_pitch_changed(0, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 100, {}, 0)
	_hand([&"card_a", &"card_b", Hand.EMPTY, &"card_d"], [], [2])
	_hud.on_card_effect_resolved(0, &"vampiric_aura", true, 0)
	_check(flash2.visible and flash2.modulate.a > 0.0, "F2: a pitch activation did not flash the slot it was staged from")
	_check(not (_card(1).get_node("PlayFlash") as Control).visible, "F2: the activation flashed another slot")
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])
	_reset_flashes()
	# F2: a FIZZLE -- the same zone clear and owed slot, but no resolution -- never flashes.
	_hand([&"card_a", &"card_b", Hand.EMPTY, &"card_d"])
	_hud.on_pitch_changed(0, &"card_c", 2, false, 100, 100, {}, 0)
	_hud.on_pitch_changed(0, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 100, {}, 0)
	_hand([&"card_a", &"card_b", Hand.EMPTY, &"card_d"], [], [2])
	_check(not flash2.visible, "F2: a fizzle flashed its slot")
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])
	# ...and a LATER own pitch resolution (next frame, after the drain is over) does not flash that stale slot:
	# `_physics_process` runs `_check_stale_fizzle` on frame 3.
	# F1's consequence: a Boulder CLEAR (covered -> uncovered, no owed slot) is not a played card and never flashes.
	_hand([&"boulder", &"card_b", &"card_c", &"card_d"], [&"card_a", &"card_b", &"card_c", &"card_d"])
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])
	_check(not (_card(0).get_node("PlayFlash") as Control).visible, "F1: a Boulder clear flashed its slot")
	_reset_flashes()


func _reset_flashes() -> void:
	for i in 4:
		(_card(i).get_node("PlayFlash") as Control).visible = false


## AC 23 / AC 25 / R6: at most five, newest on top; the opponent's entries distinct; a counter strikes the
## countered player's newest entry; the bus carries only the public facts.
func _check_history() -> void:
	var seq := [[0, &"rocksling"], [1, &"boom"], [0, &"drain"], [1, &"fireball"], [0, &"culling"],
			[1, &"frostbite"], [0, &"counterspell"]]
	for s: Array in seq:
		_hud.on_card_effect_resolved(int(s[0]), s[1], false, 0)
	var rows := _hud.history_rows()
	_check(rows.size() == HudRoot.HISTORY_SIZE and HudRoot.HISTORY_SIZE == 5,
			"AC 23: history holds %d entries, want 5" % rows.size())
	var want := [&"counterspell", &"frostbite", &"culling", &"fireball", &"drain"]
	var got := []
	for r: Array in rows:
		got.append(r[1])
	_check(got == want, "AC 23: newest-on-top order %s, want %s" % [got, want])
	var strip := _hud.get_node("HistoryStrip") as Control
	var e0 := strip.get_node("Entry0") as Panel   # own (slot 0)
	var e1 := strip.get_node("Entry1") as Panel   # opponent (slot 1)
	_check(e0.visible and e1.visible and e0.position.y < e1.position.y, "AC 23: newest entry is not on top")
	_check((e0.get_node("Icon") as TextureRect).texture == _icons.texture_for(&"counterspell"),
			"R6: an entry does not show its resolved effect's art")
	var own_rim := (e0.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	var opp_rim := (e1.get_theme_stylebox("panel") as StyleBoxFlat).border_color
	_check(own_rim != opp_rim and not is_equal_approx(e0.position.x, e1.position.x),
			"AC 24 (structural half): the opponent's entry looks like the viewer's own")
	_hud.on_card_effect_countered(1, 0)
	rows = _hud.history_rows()
	_check(rows[1][3] == true and rows[0][3] == false and rows[3][3] == false,
			"R6: the counter did not strike exactly slot 1's newest entry: %s" % [rows])
	_check((e1.get_node("Strike") as CanvasItem).visible and not (e0.get_node("Strike") as CanvasItem).visible,
			"R6: the struck entry shows no strike line")
	_hud.on_card_effect_resolved(1, &"fireball", true, 0)
	_check((strip.get_node("Entry0").get_node("PitchMark") as Control).visible, "R6: a pitch entry has no pitch mark")
	# AC 25: the bus's two relays carry exactly the public facts.
	var bus: GDScript = load("res://src/systems/event_bus.gd")
	var args := {}
	for s in bus.get_script_signal_list():
		var names: Array = []
		for a: Dictionary in s.args:
			names.append(String(a.name))
		args[String(s.name)] = names
	_check(args.get("card_effect_resolved", []) == ["slot", "effect_id", "is_pitch"],
			"AC 25: card_effect_resolved carries %s" % [args.get("card_effect_resolved", [])])
	_check(args.get("card_effect_countered", []) == ["slot"],
			"AC 25: card_effect_countered carries %s" % [args.get("card_effect_countered", [])])
	# Review fix (m5): an OWN entry landing on Entry0 while an opponent pop runs there is shown at rest.
	_hud.on_card_effect_resolved(1, &"boom", false, 0)
	_check(e0.scale.x > 1.0, "m5 control: an opponent entry did not pop")
	_hud.on_card_effect_resolved(0, &"drain", false, 0)
	_check(e0.scale == Vector2.ONE and e0.self_modulate == Color.WHITE,
			"m5: the own entry inherited the opponent's pop (scale %s)" % [e0.scale])
	_hud.on_round_started()
	_check(_hud.history_rows().is_empty() and not e0.visible, "R6: a reset did not clear the strip")


## Review fix (operator ruling F4): the pitch zone shows the staged card's PITCH effect art and no words -- own and
## opponent zone alike; an empty zone shows none.
func _check_pitch_zone_art() -> void:
	_hud.on_pitch_changed(0, &"card_a", 0, false, 100, 100, {}, 0)   # own: card_a's pitch half is boom
	_hud.on_pitch_changed(1, &"card_b", 1, false, 100, 100, {}, 0)   # opponent: card_b's pitch half is rocksling
	for z: Array in [["OwnPitch", &"boom"], ["OpponentPitch", &"rocksling"]]:
		var zone := _hud.get_node(z[0]) as Control
		var art := zone.get_node_or_null("Art") as TextureRect
		_check(art != null and art.visible and art.texture == _icons.texture_for(z[1]),
				"F4: %s does not show %s's art" % [z[0], z[1]])
		for label: Label in zone.find_children("*", "Label", true, false):
			_check(not label.is_visible_in_tree() or label.text == "" or label.name == "Ready",
					"F4: %s renders words: %s \"%s\"" % [z[0], label.name, label.text])
	_hud.on_pitch_changed(0, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 100, {}, 0)
	_hud.on_pitch_changed(1, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 100, {}, 0)
	_check((_hud.get_node("OwnPitch/Art") as TextureRect).texture == null, "F4: an empty zone still shows art")


## Story 7-4 (AC 12-14): the SORCERY look. The price rows gain their fifth element (speed) for this check only --
## card_d (two RED) becomes a sorcery; every other card keeps a four-element row, which must read INSTANT. In
## hand: the hourglass marks only the sorcery's pitch half, and its pips stay HOLLOW even with the bank full of
## red, while the instant card_a's red pip still lights. In the zone: the hourglass plus one socket per required
## orb, filled only by the payload's EARNED count, in the own and the opponent zone alike; an instant shows neither.
func _check_pitch_speeds() -> void:
	var sorcery_prices := _prices.duplicate()
	sorcery_prices[&"card_d"] = (_prices[&"card_d"] as Array) + [int(Enums.PitchSpeed.SORCERY)]
	sorcery_prices[&"card_a"] = (_prices[&"card_a"] as Array) + [int(Enums.PitchSpeed.INSTANT)]
	_hud.on_cards_changed([&"card_a", &"card_b", &"card_c", &"card_d"], 20, 0, [], _colors, sorcery_prices,
			[&"card_a", &"card_b", &"card_c", &"card_d"])
	for i in 4:
		var glass := _half(i, 1).get_node_or_null("Hourglass") as Control
		_check(glass != null and glass.visible == (i == 3),
				"AC 12: slot %d hourglass visible=%s, want %s" % [i, glass.visible if glass != null else null, i == 3])
	_hud.on_orbs_changed(2, 0, 0)
	_check(_pip_lit(3) == [false, false], "AC 14: a SORCERY's pips light from the bank: %s" % [_pip_lit(3)])
	_check(_pip_lit(0) == [true], "AC 14: an INSTANT's pip does not light from the bank: %s" % [_pip_lit(0)])
	_hud.on_orbs_changed(0, 0, 0)
	# The zones: own card_d with nothing earned, opponent card_d with one earned, then an instant.
	_hud.on_pitch_changed(0, &"card_d", 3, false, 100, 100, {RED: 0}, 0)
	_hud.on_pitch_changed(1, &"card_d", 3, false, 100, 100, {RED: 1}, 0)
	for z: Array in [["OwnPitch", [false, false]], ["OpponentPitch", [true, false]]]:
		var zone := _hud.get_node(z[0]) as Control
		_check((zone.get_node("Hourglass") as Control).visible, "AC 12: %s shows no hourglass for a sorcery" % z[0])
		var filled: Array = []
		for socket: Node in zone.get_node("Sockets").get_children():
			if (socket as Control).visible:
				filled.append(((socket as Control).get_theme_stylebox("panel") as StyleBoxFlat).draw_center)
		_check(filled == z[1], "AC 13: %s sockets %s, want %s" % [z[0], filled, z[1]])
		_check_socket_geometry(zone, z[0])
	# 7-4 SMOKE FIX, ROUND 2: a READY sorcery. READY shares the band with the sockets, so they never overlap a visible
	# READY label; where the rects meet, the row hides while READY shows.
	_hud.on_pitch_changed(0, &"card_d", 3, true, 100, 100, {RED: 2}, 0)
	var ready_zone := _hud.get_node("OwnPitch") as Control
	_check((ready_zone.get_node("Ready") as Control).visible, "SMOKE FIX: a READY sorcery shows READY")
	_check_socket_geometry(ready_zone, "OwnPitch (READY)")
	_hud.on_pitch_changed(0, &"card_a", 0, true, 100, 100, {}, 0)
	var own := _hud.get_node("OwnPitch") as Control
	var any_socket := false
	for socket: Node in own.get_node("Sockets").get_children():
		any_socket = any_socket or (socket as Control).visible
	_check(not (own.get_node("Hourglass") as Control).visible and not any_socket,
			"AC 12/13: an INSTANT in the zone shows an hourglass or sockets")
	_hud.on_pitch_changed(0, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 100, {}, 0)
	_hud.on_pitch_changed(1, PitchState.NO_CARD, PitchState.NO_HAND_SLOT, false, 0, 100, {}, 0)
	_check(not (own.get_node("Hourglass") as Control).visible, "AC 12: an EMPTY zone shows an hourglass")
	_hand([&"card_a", &"card_b", &"card_c", &"card_d"])


## 7-4 SMOKE FIX, ROUNDS 2-3 (operator smoke). Checks for every SHOWN socket:
## - it lies below the countdown bar, off the art square, inside the zone;
## - it is larger than a hand pip;
## - it never overlaps a visible READY label;
## - while EMPTY, its ring is `HudRoot.ZONE_SOCKET_RING_PX` thick, thicker than the hand's `PIP_RING_PX` (round 3).
## For the row: its left edge equals the bar's left edge (no centring). Geometry and style only (`PROC/R8`).
func _check_socket_geometry(zone: Control, label: String) -> void:
	var zone_rect := zone.get_global_rect()
	var bar_rect := (zone.get_node("Countdown") as Control).get_global_rect()
	var ready := zone.get_node("Ready") as Control
	var art_rect := (zone.get_node("Art") as Control).get_global_rect()
	var row := zone.get_node("Sockets") as Control
	_check(is_equal_approx(row.get_global_rect().position.x, bar_rect.position.x),
			"SMOKE FIX: %s socket row starts at x %.1f, the bar at %.1f" % [label, row.get_global_rect().position.x,
					bar_rect.position.x])
	for socket: Node in row.get_children():
		var sc := socket as Control
		if not sc.is_visible_in_tree():
			continue
		var r := sc.get_global_rect()
		var style := sc.get_theme_stylebox("panel") as StyleBoxFlat
		if not style.draw_center:
			_check(style.border_width_left == HudRoot.ZONE_SOCKET_RING_PX
					and HudRoot.ZONE_SOCKET_RING_PX > HudRoot.PIP_RING_PX,
					"SMOKE FIX: %s empty %s ring is %d px, want ZONE_SOCKET_RING_PX %d (> PIP_RING_PX %d)"
							% [label, sc.name, style.border_width_left, HudRoot.ZONE_SOCKET_RING_PX, HudRoot.PIP_RING_PX])
		_check(r.position.y >= bar_rect.end.y, "SMOKE FIX: %s %s %s is not below the bar %s" % [label, sc.name, r, bar_rect])
		_check(not r.intersects(art_rect), "SMOKE FIX: %s %s overlaps the art %s" % [label, sc.name, art_rect])
		_check(zone_rect.encloses(r), "SMOKE FIX: %s %s %s leaves the zone %s" % [label, sc.name, r, zone_rect])
		_check(r.size.x > HudRoot.PIP_SIZE and r.size.y > HudRoot.PIP_SIZE,
				"SMOKE FIX: %s %s %s is not larger than a hand pip (%.0f)" % [label, sc.name, r.size, HudRoot.PIP_SIZE])
		_check(not (ready.is_visible_in_tree() and r.intersects(ready.get_global_rect())),
				"SMOKE FIX: %s %s overlaps the visible READY label" % [label, sc.name])


## AC 30 / AC 31: a living hero never reads 0 (ceiling); a dead one reads 0.
func _check_hp_display() -> void:
	var label := _hud.get_node("Vitals/HPRow/HPBar/HPValue") as Label
	# 7-6 POLISH 3/4 (operator rulings P18, P19): thinner bars; each number sits INSIDE its bar near the RIGHT end,
	# white with a thick dark outline and NO background plate.
	var hp_bar := _hud.get_node("Vitals/HPRow/HPBar") as Control
	var bar_rect := hp_bar.get_global_rect()
	var label_rect := label.get_global_rect()
	_check(hp_bar.custom_minimum_size.y < 18.0, "P18: the bars are not thinner (%s px)" % hp_bar.custom_minimum_size.y)
	# Horizontally inside the bar, right of its centre, and vertically centred on it. The label's LINE BOX (18 px at
	# this font size) is taller than the 15 px bar; the glyphs themselves sit within it.
	_check(label.get_parent() == hp_bar and label_rect.position.x >= bar_rect.position.x
			and label_rect.end.x <= bar_rect.end.x and label_rect.get_center().x > bar_rect.get_center().x
			and absf(label_rect.get_center().y - bar_rect.get_center().y) <= 1.0,
			"P19: the HP number is not inside its bar right of centre (%s in %s)" % [label_rect, bar_rect])
	_check(not label.has_theme_stylebox_override("normal") and label.get_theme_constant("outline_size") >= 5
			and label.get_theme_color("font_color") == Color.WHITE,
			"P19: the HP number has a plate, a thin outline or a non-white face")
	for c: Array in [[0.4, "1/100"], [0.0, "0/100"], [99.2, "100/100"], [50.0, "50/100"], [7.5, "8/100"]]:
		_hud.on_hp_changed(float(c[0]), 100.0)
		_check(label.text == c[1], "AC 30/31: hp %s displays %s, want %s" % [c[0], label.text, c[1]])


## AC 12 / AC 32: every Deck 1 effect plus Boulder's has a game-icons.net file credited in CREDITS.txt with the
## licence; the three hand-authored icons are the ones the table points at, and their game-icons versions stay.
func _check_icon_files_and_credits() -> void:
	var deck := load("res://data/decks/deck_1.tres") as DeckList
	var effects: Array[StringName] = [&"boulder_discard"]
	for id: StringName in deck.card_ids:
		var card := load("res://data/cards/%s.tres" % id) as CardData
		for e: CardEffect in [card.basic_effect, card.pitch_effect]:
			if e != null and not effects.has(e.effect_id):
				effects.append(e.effect_id)
	_check(effects.size() == 15, "AC 12: Deck 1 + Boulder name %d effects, want 15" % effects.size())
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.txt")
	for e: StringName in effects:
		var path := "res://assets/art/icons/game_icons/%s.svg" % e
		_check(ResourceLoader.exists(path), "AC 12: %s missing" % path)
		var line := ""
		for l: String in credits.split("\n"):
			if l.strip_edges().begins_with("%s.svg -- " % e):
				line = l
		# Review fix (N10): the line also names its AUTHOR -- `"<icon name>" by <author>, game-icons.net`.
		var author := line.get_slice("\" by ", 1).get_slice(",", 0).strip_edges() if line.contains("\" by ") else ""
		_check(line.contains("game-icons.net") and line.contains("CC BY 3.0") and author != "",
				"AC 12: no CREDITS line naming the author, game-icons.net and CC BY 3.0 for %s" % e)
		_check(_icons.texture_for(e) != null, "R2: the icon table has no art for %s" % e)
	for e: StringName in [&"rocksling", &"honed_bolt", &"corpse_bomb"]:
		_check(_icons.icon_paths.get(e, "") == "res://assets/art/icons/authored/%s.svg" % e,
				"AC 32: %s does not show its hand-authored icon" % e)
		_check(ResourceLoader.exists("res://assets/art/icons/game_icons/%s.svg" % e),
				"AC 32: %s's game-icons.net version is gone" % e)
	# 7-6 POLISH (operator ruling P6): Honed Bolt's hand-authored icon is a LIGHTNING BOLT, not an arrow. Read off the
	# SVG's own header line (geometry cannot say "lightning"); the two other hand-authored icons are untouched.
	var bolt_header := FileAccess.get_file_as_string("res://assets/art/icons/authored/honed_bolt.svg").split("\n")[1]
	_check(bolt_header.contains("lightning") and not bolt_header.contains("crossbow"),
			"P6: honed_bolt.svg is not the lightning bolt: %s" % bolt_header)
