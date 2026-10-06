extends SceneTree

## Story 7-6 (D1, R6, R7; AC 23, 26, 28, 29): the live runner's two new PUBLIC RELAYS and the world-orb halos.
##
## [relays] `_relay_card_cast_resolved` / `_relay_counterspell_resolved` are connected to their MatchState
##   signals, and what they put on EventBus reaches BOTH HudRoots' history strips: a NORMAL resolution enters as
##   the card's normal effect, a PITCH one as its pitch effect with the pitch flag; a mode-2 (unblockable) or
##   mode-3 (defence) resolution enters NOWHERE (AC 23's admission rule); a counter strikes the countered
##   player's newest entry in both strips. Driven by calling the relays the way test_card_mode_lift.gd calls
##   `_relay_round_ended` -- the MatchState side of each connection is asserted by `is_connected`.
## [orbs] each hero carries an `OrbHalo` whose shown count per colour equals that hero's live orb counts after
##   the ninth seam delivers them (AC 28); the other hero's halo does not move; the HUD's own orb counters
##   still read the same counts (AC 29).
##
## Run: godot --headless --path . --script res://test/integration/test_history_and_orbs_live.gd

var _frames := 0
var _main: Node
var _p1_hud: HudRoot
var _p2_hud: HudRoot
var _ok := true
var _orb_frame := -1


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _fail(msg: String) -> void:
	_ok = false
	print("FAIL: " + msg)


func _any_cue_playing() -> bool:
	for player in root.find_children("*", "AudioStreamPlayer", true, false):
		if (player as AudioStreamPlayer).playing:
			return true
	for player in root.find_children("*", "AudioStreamPlayer3D", true, false):
		if (player as AudioStreamPlayer3D).playing:
			return true
	return false


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_main = root.get_node("Main")
		_p1_hud = root.get_node("Main/P1View/P1Viewport/HudRoot")
		_p2_hud = root.get_node("Main/P2View/P2Viewport/HudRoot")
		_check_relays()
		var p1: PlayerState = _main._match_state.p1
		p1.orbs.add(Enums.CardColor.RED, 2)
		p1.orbs.add(Enums.CardColor.GREEN, 1)
		_orb_frame = _frames
	if _orb_frame > 0 and _frames == _orb_frame + 3:
		_check_orbs()
		_phase = 1
		_phase_frame = _frames
		(_main._match_state.p1 as PlayerState).orbs.add(Enums.CardColor.RED, -1)
	if _phase > 0 and _frames > _phase_frame:
		_run_halo_phases()
	if _phase == DONE and (not _any_cue_playing() or _frames >= _phase_frame + 900):
		print("history_and_orbs: ok=%s" % _ok)
		print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
		quit(0 if _ok else 1)
	return false


## 7-6 review fix (operator ruling F7): the halo past its first grant -- a DECREASE, a mid-round DEBUG RESET and a
## ROUND RESTART (a kill, then the reset that starts the next round), each read off the live nodes against the live
## pools. The reset is the real `p1_debug_reset` press through `advance()` (`test_debug_instruments.gd`'s path).
const DONE := 99
var _phase := 0
var _phase_frame := 0
## P5's probe: a stand-alone halo on a stand-in hero the test can move freely (a live hero's position is the
## runner's to drive).
var _probe_anchor: Node3D
var _probe: OrbHalo
var _offsets_a: Array = []
var _gap_a := 0.0
var _gap_min := 0.0
var _min_body_gap := INF
var _gap_max := 0.0


func _start_wisp_probe() -> void:
	_probe_anchor = Node3D.new()
	_probe_anchor.name = "WispProbeHero"
	root.add_child(_probe_anchor)
	_probe_anchor.global_position = Vector3(30.0, 1.0, 30.0)
	_probe = OrbHalo.new()
	_probe.setup([Color.RED, Color.BLUE, Color.GREEN] as Array[Color])
	_probe_anchor.add_child(_probe)
	_probe.on_orbs_changed(2, 1, 0)


## 7-6 POLISH 2 (operator ruling P10): a wisp has NO COLLISION OF ANY KIND -- no CollisionObject3D (Area3D or physics
## body), CollisionShape3D or CollisionPolygon3D anywhere under any OrbHalo: both live heroes' halos and the probe's
## (which holds wisps right now, so the scan is not vacuous).
func _check_no_collision() -> void:
	var halos: Array = [_probe, _main._p1_hero.get_node("OrbHalo"), _main._p2_hero.get_node("OrbHalo")]
	var wisps := 0
	for halo: Node in halos:
		wisps += halo.find_children("Wisp*", "Node3D", false, false).size()
		for kind in ["CollisionObject3D", "CollisionShape3D", "CollisionPolygon3D"]:
			var found := halo.find_children("*", kind, true, false)
			if not found.is_empty():
				_fail("P10: %s under %s has collision: %s" % [kind, halo.get_path(), found])
	if wisps == 0:
		_fail("P10: the collision scan saw no wisps (vacuous)")


func _offsets() -> Array:
	var out: Array = []
	for w: Node3D in _probe.visible_wisps():
		out.append(w.global_position - _probe_anchor.global_position)
	return out


## The distance between the first two wisps -- constant for a rigid ring, varying for free drift.
func _gap() -> float:
	var ws := _probe.visible_wisps()
	return ws[0].global_position.distance_to(ws[1].global_position)


func _flat_distance(w: Node3D) -> float:
	var d := w.global_position - _probe_anchor.global_position
	return Vector2(d.x, d.z).length()


func _halos() -> Array:
	return [(_main._p1_hero.get_node("OrbHalo") as OrbHalo).shown_counts(),
			(_main._p2_hero.get_node("OrbHalo") as OrbHalo).shown_counts()]


func _live() -> Array:
	var out: Array = []
	for p: PlayerState in [_main._match_state.p1, _main._match_state.p2]:
		out.append([p.orbs.get_count(Enums.CardColor.RED), p.orbs.get_count(Enums.CardColor.BLUE),
				p.orbs.get_count(Enums.CardColor.GREEN)])
	return out


func _next(phase: int) -> void:
	_phase = phase
	_phase_frame = _frames


func _run_halo_phases() -> void:
	var since := _frames - _phase_frame
	# 7-6 POLISH 3 (operator ruling P16): through the whole probe -- drift AND the 4 m catch-up -- no wisp is ever
	# inside its hero's body radius; they go AROUND the body, not through it.
	if _phase == 7 or _phase == 8 or (_phase == 9 and since >= 1):
		for w: Node3D in _probe.visible_wisps():
			_min_body_gap = minf(_min_body_gap, _flat_distance(w))
	var p1: PlayerState = _main._match_state.p1
	var p2: PlayerState = _main._match_state.p2
	match _phase:
		1:  # the decrease (2,0,1) -> (1,0,1)
			if since == 3:
				if _halos() != _live() or _live()[0] != [1, 0, 1]:
					_fail("F7: after a decrease the halos show %s, live %s (want P1 [1, 0, 1])" % [_halos(), _live()])
				p2.orbs.add(Enums.CardColor.BLUE, 2)
				Input.action_press(&"p1_debug_reset")
				_next(2)
		2:  # mid-round DEBUG RESET: both pools to zero, both halos with them
			if since == 1:
				Input.action_release(&"p1_debug_reset")
			elif since == 4:
				if _live() != [[0, 0, 0], [0, 0, 0]]:
					_fail("F7 fixture: the debug reset left orbs %s (vacuous)" % [_live()])
				if _halos() != [[0, 0, 0], [0, 0, 0]]:
					_fail("F7: after a debug reset the halos show %s" % [_halos()])
				p2.orbs.add(Enums.CardColor.BLUE, 2)
				_next(3)
		3:  # a post-reset grant still lands on the right hero
			if since == 3:
				if _halos() != _live() or _live()[1] != [0, 2, 0]:
					_fail("F7: after the reset a grant shows %s, live %s" % [_halos(), _live()])
				p2.hero.take_damage(p2.hero.get_hp() + 1000.0)
				_next(4)
		4:  # ROUND RESTART: wait for the kill to end the round, then the reset starts the next one
			var over := bool(_main._match_state.to_snapshot().get("round_over", false))
			if over:
				Input.action_press(&"p1_debug_reset")
				_next(5)
			elif since > 120:
				_fail("F7 fixture: the kill never ended the round")
				_next(DONE)
		5:
			if since == 1:
				Input.action_release(&"p1_debug_reset")
			elif since == 4:
				if bool(_main._match_state.to_snapshot().get("round_over", true)):
					_fail("F7 fixture: the reset did not start a new round")
				if _halos() != [[0, 0, 0], [0, 0, 0]] or _halos() != _live():
					_fail("F7: after a round restart the halos show %s, live %s" % [_halos(), _live()])
				p1.orbs.add(Enums.CardColor.GREEN, 3)
				_next(6)
		6:
			if since == 3:
				if _halos() != _live() or _live()[0] != [0, 0, 3]:
					_fail("F7: in the restarted round a grant shows %s, live %s" % [_halos(), _live()])
				print("halo phases: final halos=%s live=%s" % [_halos(), _live()])
				_start_wisp_probe()
				_next(7)
		7:  # 7-6 POLISH (operator ruling P5): an exact count, top_level wisps, IRREGULAR drift (spacing varies)
			if since == 2:
				if _probe.shown_counts() != [2, 1, 0] or _probe.visible_wisps().size() != 3:
					_fail("P5: the probe halo shows %s, want [2, 1, 0]" % [_probe.shown_counts()])
				for w: Node3D in _probe.visible_wisps():
					if not w.top_level:
						_fail("P5: a wisp is carried rigidly by its hero (not top_level)")
				_check_no_collision()
				_offsets_a = _offsets()
				_gap_a = _gap()
				_gap_min = _gap_a
				_gap_max = _gap_a
			elif since > 2 and since < 120:
				_gap_min = minf(_gap_min, _gap())
				_gap_max = maxf(_gap_max, _gap())
			elif since == 120:
				var b := _offsets()
				var moved := 0
				for i in b.size():
					if (b[i] as Vector3).distance_to(_offsets_a[i]) > 0.05:
						moved += 1
				if moved < b.size():
					_fail("P5: only %d of %d wisps drifted in 120 frames" % [moved, b.size()])
				if _gap_max - _gap_min < 0.05:
					_fail("P5: the wisps keep a fixed spacing (%.3f..%.3f over 120 frames) -- a rigid ring"
							% [_gap_min, _gap_max])
				print("wisps: spacing %.3f..%.3f over 120 frames" % [_gap_min, _gap_max])
				_probe_anchor.global_position += Vector3(4.0, 0.0, 0.0)  # the 'hero' jumps 4 m
				_next(8)
		8:  # INERTIA: one frame after the jump every wisp lags; then they all catch up
			if since == 1:
				for w: Node3D in _probe.visible_wisps():
					if _flat_distance(w) < 2.0:
						_fail("P5: a wisp kept up with a 4 m jump in one frame (%.2f m) -- no inertia" % _flat_distance(w))
			elif since > 1:
				var reach := OrbHalo.ORBIT_RADIUS + OrbHalo.RADIUS_WOBBLE + 0.3
				var caught := true
				for w: Node3D in _probe.visible_wisps():
					if _flat_distance(w) > reach:
						caught = false
				if caught:
					print("wisps: caught up %d frames after a 4 m jump; closest to the body axis %.3f m" % [since,
							_min_body_gap])
					# The forcing case: the hero steps ONTO a wisp (its flat position), so that wisp starts inside the
					# body and must be carried out, not left inside.
					var w0: Node3D = _probe.visible_wisps()[0]
					_probe_anchor.global_position = Vector3(w0.global_position.x, _probe_anchor.global_position.y,
							w0.global_position.z)
					_next(9)
					return
					_next(DONE)
				elif since > 600:
					_fail("P5: the wisps never caught up with their hero")
					_next(DONE)
		9:
			if since == 30:
				print("wisps: closest to the body axis %.3f m (body radius %.2f m)" % [_min_body_gap, OrbHalo.BODY_RADIUS])
				if _min_body_gap < OrbHalo.BODY_RADIUS - 0.001:
					_fail("P16: a wisp passed through its hero's body (%.3f m < %.2f m)" % [_min_body_gap,
							OrbHalo.BODY_RADIUS])
				_next(DONE)


func _check_relays() -> void:
	var ms: Object = _main._match_state
	if not ms.card_cast_resolved.is_connected(_main._relay_card_cast_resolved):
		_fail("AC 26: MatchState.card_cast_resolved is not relayed")
	if not ms.counterspell_resolved.is_connected(_main._relay_counterspell_resolved):
		_fail("AC 26: MatchState.counterspell_resolved is not relayed")
	for hud: HudRoot in [_p1_hud, _p2_hud]:
		if not hud.history_rows().is_empty():
			_fail("a strip holds entries before any resolution: %s" % [hud.history_rows()])
	# Normal (mode 1) by P1, pitch (mode 4) by P2 -- Deck 1's Rocksling is rocksling / boom.
	_main._relay_card_cast_resolved(0, &"rocksling", Enums.ModeKind.BASIC)
	_main._relay_card_cast_resolved(1, &"rocksling", Enums.ModeKind.PITCH)
	# Modes 2 and 3 and an unknown card never enter.
	_main._relay_card_cast_resolved(0, &"honed_bolt", Enums.ModeKind.UNBLOCKABLE)
	_main._relay_card_cast_resolved(1, &"frostbite", Enums.ModeKind.DEFENSE)
	_main._relay_card_cast_resolved(0, &"no_such_card", Enums.ModeKind.BASIC)
	var want := [[1, &"boom", true, false], [0, &"rocksling", false, false]]
	for hud: HudRoot in [_p1_hud, _p2_hud]:
		if hud.history_rows() != want:
			_fail("AC 23: %s strip %s, want %s" % [hud.get_parent().name, hud.history_rows(), want])
	# P1 counters P2: P2's newest entry is struck in BOTH strips.
	_main._relay_counterspell_resolved(0, 1)
	for hud: HudRoot in [_p1_hud, _p2_hud]:
		var rows := hud.history_rows()
		if rows.size() != 2 or rows[0][3] != true or rows[1][3] != false:
			_fail("AC 23: the counter did not strike P2's entry in %s: %s" % [hud.get_parent().name, rows])
	# Own vs opponent: P1's strip shows its own entry flush and P2's indented; P2's strip the mirror image.
	var p1_e0 := _p1_hud.get_node("HistoryStrip/Entry0") as Control  # P2's boom (opponent for P1)
	var p2_e0 := _p2_hud.get_node("HistoryStrip/Entry0") as Control  # P2's boom (own for P2)
	if bool(p1_e0.get_meta(&"own")) or not bool(p2_e0.get_meta(&"own")):
		_fail("R6: own/opponent entries are told apart by the wrong slot")
	_check_boulder_and_counter()


## 7-6 review fix (operator ruling F1): a Boulder CLEAR never enters either strip (not a played card, `6-5f/R7`),
## so a counter strikes the real card; and a counter whose card already left the strip strikes nothing.
func _check_boulder_and_counter() -> void:
	_main._relay_round_started()  # the real clear seat: both strips empty
	# P1 plays Drain (recorded), then clears a Boulder (never recorded); P2 counters P1.
	_main._relay_card_cast_resolved(0, &"drain", Enums.ModeKind.BASIC)
	_main._relay_card_cast_resolved(0, &"boulder", Enums.ModeKind.BASIC)
	for hud: HudRoot in [_p1_hud, _p2_hud]:
		if hud.history_rows() != [[0, &"drain", false, false]]:
			_fail("F1: a Boulder clear entered %s's strip: %s" % [hud.get_parent().name, hud.history_rows()])
	_main._relay_counterspell_resolved(1, 0)
	for hud: HudRoot in [_p1_hud, _p2_hud]:
		if hud.history_rows() != [[0, &"drain", false, true]]:
			_fail("F1: the counter after a Boulder clear did not strike Drain in %s: %s"
					% [hud.get_parent().name, hud.history_rows()])
	# P2 plays Rocksling, then P1 resolves five effects: Rocksling leaves the strip. P1 counters P2 -> nothing struck.
	_main._relay_round_started()
	_main._relay_card_cast_resolved(1, &"rocksling", Enums.ModeKind.BASIC)
	for id: StringName in [&"drain", &"bloodhound_step", &"frostbite", &"ruin_vanguard", &"grave_ward"]:
		_main._relay_card_cast_resolved(0, id, Enums.ModeKind.BASIC)
	_main._relay_counterspell_resolved(0, 1)
	for hud: HudRoot in [_p1_hud, _p2_hud]:
		var rows := hud.history_rows()
		var struck := rows.filter(func(r: Array) -> bool: return bool(r[3]))
		if rows.size() != 5 or not struck.is_empty() or rows.any(func(r: Array) -> bool: return int(r[0]) == 1):
			_fail("F1: a counter whose card left the strip struck something in %s: %s" % [hud.get_parent().name, rows])
	_main._relay_round_started()


func _check_orbs() -> void:
	var p1: PlayerState = _main._match_state.p1
	var p2: PlayerState = _main._match_state.p2
	var halos: Array = []
	for hero_node: Node3D in [_main._p1_hero, _main._p2_hero]:
		var halo := hero_node.get_node_or_null("OrbHalo") as OrbHalo
		if halo == null:
			_fail("R7: hero %s carries no OrbHalo" % hero_node.name)
			return
		halos.append(halo)
	var p1_live := [p1.orbs.get_count(Enums.CardColor.RED), p1.orbs.get_count(Enums.CardColor.BLUE),
			p1.orbs.get_count(Enums.CardColor.GREEN)]
	var p2_live := [p2.orbs.get_count(Enums.CardColor.RED), p2.orbs.get_count(Enums.CardColor.BLUE),
			p2.orbs.get_count(Enums.CardColor.GREEN)]
	if p1_live == [0, 0, 0]:
		_fail("the fixture granted P1 no orbs (vacuous): %s" % [p1_live])
	var shown1: Array = (halos[0] as OrbHalo).shown_counts()
	var shown2: Array = (halos[1] as OrbHalo).shown_counts()
	if shown1 != p1_live:
		_fail("AC 28: P1's halo shows %s, live counts %s" % [shown1, p1_live])
	if shown2 != p2_live:
		_fail("AC 28: P2's halo shows %s, live counts %s" % [shown2, p2_live])
	var counters: Array = []
	for i in 3:
		counters.append(int((_p1_hud.get_node("OrbCounters/Orb%d/OrbCount%d" % [i, i]) as Label).text))
	if counters != p1_live:
		_fail("AC 29: P1's HUD orb counters read %s, live %s" % [counters, p1_live])
	print("orbs: p1 live=%s halo=%s hud=%s | p2 live=%s halo=%s" % [p1_live, shown1, counters, p2_live, shown2])
