extends SceneTree

## Story 7-3 (ACs 4, 14, 15, 17): ONE HELLHOUND CAST, ON THE REAL RUNNER, THROUGH THE REAL CARD.
##
## Both players are dealt a deck of nothing but the `hellhound` card (the runner's deck-list seat,
## `test/live_summon_deck.gd`'s route) and each casts it once, by input. Asserted for each cast:
##
##   AC 4   exactly TWO live hound records on the caster's board, and two actors for them;
##   AC 4   THE TWO SPAWN SPOTS ARE APART: at least the runner's own spawn clearance from each other
##          and from both heroes (the `4-3e` batch rule, measured on what was actually placed);
##   AC 17  both actors are the HOUND scene (a `HoundAnimationController`, a `Hitbox`), not the
##          zombie's;
##   AC 14  P1's hounds wear the PURPLE skin and P2's the RED one, on the mesh that is drawn;
##   AC 15  ONE spawn look and sound per cast, from the Hellhound row: after P1's cast the presenter
##          has played `hellhound/summon` once, after P2's twice, and `vanguard/summon` never;
##   AC 15  THE LOCK MARK SITS ON THE HOUND: `_lock_mark_world_position` for a hound is lifted to the
##          hound's own measured back height, inside the body the scene actually draws, and is NOT
##          the zombie's chest lift.
##
## Run: godot --headless --path . --script res://test/integration/test_hound_spawn_live.gd

const HOUND_KIND := &"hellhound"
const P1_ARM_FRAME := 4
const P2_ARM_FRAME := 40
const SETTLE_FRAMES := 14
const FINISH_FRAME := 70

## The hound's back in `idle`: 1.809 model units at the scene's 0.33 scale (measure_hellhound_rig.gd).
const HOUND_BACK_HEIGHT := 0.6

var _frames := 0
var _runner: Node
var _state: MatchState
var _effects: EffectPresenter
var _failures: Array[String] = []


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	var deck := DeckList.new()
	deck.card_ids = [&"hellhound"] as Array[StringName]
	deck.copies = [20] as Array[int]
	main.deck_list_override = deck
	main.seed_override = 12345
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_effects = _runner._effects if _runner != null else null
		if _runner == null or _state == null or _effects == null:
			return _finish("missing: runner=%s state=%s effects=%s" % [_runner, _state, _effects])
		return false
	if _frames == 2:
		_state.p1.mana.add(_state.p1.mana.get_maximum())
		_state.p2.mana.add(_state.p2.mana.get_maximum())
		_check_flank_placement()
	_cast("p1", P1_ARM_FRAME)
	_cast("p2", P2_ARM_FRAME)
	if _frames == P1_ARM_FRAME + SETTLE_FRAMES:
		_check_cast(0, _state.p1, "T_HellHound_Pe_D.tga", 1)
	if _frames == P2_ARM_FRAME + SETTLE_FRAMES:
		_check_cast(1, _state.p2, "T_HellHound_Rd_D.tga", 2)
	if _frames >= FINISH_FRAME:
		return _finish("")
	return false


## One cast of hand slot 1 by `prefix`'s keyboard, the strike-alignment test's input sequence.
func _cast(prefix: String, arm_frame: int) -> void:
	if _frames == arm_frame + 1:
		Input.action_press(StringName(prefix + "_card_1"))
	if _frames == arm_frame + 2:
		Input.action_release(StringName(prefix + "_card_1"))
	if _frames == arm_frame + 6:
		Input.action_press(StringName(prefix + "_cast_confirm"))
	if _frames == arm_frame + 8:
		Input.action_release(StringName(prefix + "_cast_confirm"))


func _check_cast(slot: int, player: PlayerState, skin_file: String, summon_sounds: int) -> void:
	var who := "P%d" % (slot + 1)
	var kind_index := _state.balance.kind_index_of(HOUND_KIND)
	_check(player.units.size() == 2, "%s: one cast put %d records on the board, want 2" % [who, player.units.size()])
	var actors: Array = _runner._unit_actors[slot]
	_check(actors.size() == 2, "%s: the runner spawned %d actors, want 2" % [who, actors.size()])
	if player.units.size() != 2 or actors.size() != 2:
		return
	var spots: Array[Vector3] = []
	for index in 2:
		_check(player.units.is_alive_at(index) and player.units.kind_index_at(index) == kind_index,
				"%s: record %d is not a live hellhound" % [who, index])
		var actor := actors[index] as UnitActor
		_check(actor != null and actor.animation is HoundAnimationController and actor.hitbox != null,
				"%s: actor %d is not the hound scene" % [who, index])
		if actor == null:
			return
		spots.append(actor.global_position)
		var mesh := actor.get_node_or_null(actor.skin_mesh_path) as MeshInstance3D
		var material := (mesh.material_override if mesh != null else null) as BaseMaterial3D
		var albedo := material.albedo_texture.resource_path.get_file() \
				if material != null and material.albedo_texture != null else ""
		_check(albedo == skin_file, "%s: hound %d wears '%s', want '%s' (AC 14)" % [who, index, albedo, skin_file])
		# AC 15: the lock mark. `_lock_mark_world_position` is what the marker projects.
		var mark: Variant = _runner._lock_mark_world_position(slot, index)
		var lift: float = (mark as Vector3).y - actor.global_position.y if mark is Vector3 else -1.0
		_check(absf(lift - HOUND_BACK_HEIGHT) < 0.01,
				"%s: hound %d's lock mark is lifted %.3f, want its back height %.2f" % [who, index, lift, HOUND_BACK_HEIGHT])
		_check(absf(lift - float(_runner.LOCK_MARK_UNIT_LIFT)) > 0.3,
				"%s: hound %d's lock mark sits at the zombie's chest lift" % [who, index])
		var top := _visual_top(actor)
		_check(lift > 0.2 and lift < top,
				"%s: hound %d's lock mark (%.3f up) is not inside its drawn body (top %.3f)" % [who, index, lift, top])
	# AC 4: the two spots avoid each other and both heroes.
	var clearance := float(_runner.SPAWN_CLEARANCE_RADIUS)
	_check(_planar(spots[0], spots[1]) >= clearance - 0.001,
			"%s: the two hounds spawned %.3f m apart, under the %.2f m clearance" % [who, _planar(spots[0], spots[1]), clearance])
	for spot: Vector3 in spots:
		for hero: Node3D in [_runner._p1_hero, _runner._p2_hero]:
			_check(_planar(spot, hero.global_position) >= clearance - 0.001,
					"%s: a hound spawned %.3f m from a hero" % [who, _planar(spot, hero.global_position)])
	# Feel pass (smoke finding 1): ONE EACH SIDE, BEHIND THE SUMMONER. Measured against the summoner
	# and its opponent as they stand: the first hound is to the summoner's LEFT as it faces its
	# opponent and the second to its RIGHT, each about the row's authored flank distance out, and both
	# behind it. (Read a few frames after the spawn, so each has already taken a step: the bands allow it.)
	var summoner: Node3D = _runner._p1_hero if slot == 0 else _runner._p2_hero
	var opponent: Node3D = _runner._p2_hero if slot == 0 else _runner._p1_hero
	var away := Vector2(summoner.global_position.x - opponent.global_position.x,
			summoner.global_position.z - opponent.global_position.z).normalized()
	var left := Vector2(-away.y, away.x)
	var flank := _effects.row(&"hellhound").knob(&"spawn_flank_distance", 0.0)
	_check(flank >= clearance * 0.5, "the hellhound row authors no usable `spawn_flank_distance` (%.2f)" % flank)
	for index in 2:
		var offset := Vector2(spots[index].x - summoner.global_position.x, spots[index].z - summoner.global_position.z)
		var side := offset.dot(left) * (1.0 if index == 0 else -1.0)
		_check(absf(side - flank) < 0.4,
				"%s: hound %d stands %.3f m to the summoner's %s, want about %.2f (one each side)"
						% [who, index, side, "left" if index == 0 else "right", flank])
		_check(offset.dot(away) > 1.2, "%s: hound %d is %.3f m behind its summoner, want it behind"
				% [who, index, offset.dot(away)])
	# AC 15: one look and one sound per cast, from the Hellhound row.
	_check(_effects.played.count(&"hellhound/summon") == summon_sounds,
			"%s: `hellhound/summon` has played %d times after %d casts"
					% [who, _effects.played.count(&"hellhound/summon"), summon_sounds])
	_check(not _effects.played.has(&"vanguard/summon"), "%s: a hound spawn played the Vanguard sound" % who)


## Feel pass (smoke finding 1): THE PLACEMENT RULE ITSELF, on the runner's own pure function, with the
## occupancy chosen here: "one each side, behind the summoner, with fallbacks when those spots are
## taken". Every expected spot is derived from the runner's own constants or from the SAME function
## called without flanks (the `4-3e` rule), so a retune of either moves the expectation with it.
func _check_flank_placement() -> void:
	var hero := Vector3(-4.0, 1.0, 2.0)
	var opponent := Vector3(6.0, 1.0, 2.0)
	var flank := 1.1
	var flanks: Array[float] = [flank, flank]
	var none: Array[float] = []
	var away := Vector2(-1.0, 0.0)
	var left := Vector2(-away.y, away.x)
	var base := Vector2(hero.x, hero.z) + away * float(_runner.SPAWN_BEHIND_DISTANCE)
	var left_spot := Vector3(base.x + left.x * flank, 0.0, base.y + left.y * flank)
	var right_spot := Vector3(base.x - left.x * flank, 0.0, base.y - left.y * flank)
	var open: Array[Vector3] = [hero, opponent]
	# (a) Both spots free: the first member takes the left, the second the right.
	var placed: Array[Vector3] = _runner._compute_spawn_positions(open, hero, opponent, 0, 2, flanks)
	_check(placed.size() == 2 and _planar(placed[0], left_spot) < 0.001 and _planar(placed[1], right_spot) < 0.001,
			"free flanks: placed %s, want the left spot %s then the right spot %s" % [placed, left_spot, right_spot])
	# (b) The left spot is taken: that member falls back to the 4-3e candidate walk -- exactly the spot
	# the walk gives one unit under the same occupancy -- and the other still takes the right.
	var left_taken: Array[Vector3] = [hero, opponent, left_spot]
	var fallback: Array[Vector3] = _runner._compute_spawn_positions(left_taken, hero, opponent, 0, 1, none)
	placed = _runner._compute_spawn_positions(left_taken, hero, opponent, 0, 2, flanks)
	_check(placed.size() == 2 and _planar(placed[0], fallback[0]) < 0.001,
			"left flank taken: the first member stands at %s, want the 4-3e candidate %s" % [placed[0], fallback[0]])
	_check(placed.size() == 2 and _planar(placed[1], right_spot) < 0.001,
			"left flank taken: the second member stands at %s, want the right spot %s" % [placed[1], right_spot])
	_check(placed.size() == 2 and _planar(placed[0], left_spot) >= float(_runner.SPAWN_CLEARANCE_RADIUS) - 0.001,
			"left flank taken: a hound was placed %.3f m from the unit standing there" % _planar(placed[0], left_spot))
	# (c) Both spots taken: both members take the 4-3e walk, exactly as a batch with no flanks does.
	var both_taken: Array[Vector3] = [hero, opponent, left_spot, right_spot]
	var plain: Array[Vector3] = _runner._compute_spawn_positions(both_taken, hero, opponent, 0, 2, none)
	placed = _runner._compute_spawn_positions(both_taken, hero, opponent, 0, 2, flanks)
	_check(placed == plain, "both flanks taken: placed %s, want the 4-3e batch %s" % [placed, plain])
	# (d) No flank authored (a zombie, a totem): the rule that stood before, to the last digit.
	var zeros: Array[float] = [0.0, 0.0]
	plain = _runner._compute_spawn_positions(open, hero, opponent, 0, 2, none)
	_check(_runner._compute_spawn_positions(open, hero, opponent, 0, 2, zeros) == plain
			and _runner._compute_spawn_positions(open, hero, opponent, 0, 2) == plain,
			"a batch with no flank distance does not place as it did before the feel pass")
	# (e) A third flanked member has no side left: it takes the walk, clear of the first two, and
	# every member is in the rear half-space.
	var three: Array[float] = [flank, flank, flank]
	placed = _runner._compute_spawn_positions(open, hero, opponent, 0, 3, three)
	_check(placed.size() == 3, "three flanked members placed %d spots" % placed.size())
	for i in placed.size():
		_check((Vector2(placed[i].x, placed[i].z) - Vector2(hero.x, hero.z)).dot(away)
				>= float(_runner.SPAWN_BEHIND_DISTANCE) - 0.001,
				"member %d of three is not behind the summoner: %s" % [i, placed[i]])
		for j in i:
			_check(_planar(placed[i], placed[j]) >= float(_runner.SPAWN_CLEARANCE_RADIUS) - 0.001,
					"members %d and %d of three stand %.3f m apart" % [j, i, _planar(placed[i], placed[j])])


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The highest point of the actor's skinned mesh above its root, from the mesh's own bounds.
func _visual_top(actor: UnitActor) -> float:
	var mesh := actor.get_node_or_null(actor.skin_mesh_path) as MeshInstance3D
	if mesh == null:
		return 0.0
	var bounds := mesh.global_transform * mesh.get_aabb()
	return bounds.end.y - actor.global_position.y


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _finish(error: String) -> bool:
	if error != "":
		_failures.append(error)
	for action: String in ["card_1", "cast_confirm"]:
		Input.action_release(StringName("p1_" + action))
		Input.action_release(StringName("p2_" + action))
	if _effects != null:
		_effects.stop_all_sounds()
	OS.delay_msec(100)
	for f in _failures:
		print("  FAILED: " + f)
	var ok := _failures.is_empty()
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return false
