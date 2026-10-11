extends SceneTree

## Story 7-3, post-smoke feel pass (smoke finding 2): THE GRAVE WARD LOOK ON A HOUND'S CORPSE, on the
## real runner and the shipped hound scene. The operator: Grave Ward "does not work" on hound corpses.
##
## DIAGNOSED: the state extension was never broken (pinned through the card in
## `test/state/test_hellhound.gd`). The LOOK was: `EffectPresenter` followed a corpse's `mixamorig_Hips`
## bone, the Hellhound's rig has none (its hips are `Pelvis`), and the look fell back to the corpse's
## ROOT -- half a metre from where the dead hound's body actually lies.
##
## A hound and a zombie are put on P1's board, killed, left to fall, and their corpses extended the
## way Grave Ward extends them. EVERY ASSERTION IS AN EFFECT, read off the corpse actors:
##
##   ON THE BODY     the look's anchor sits on the corpse's own hips bone (the hound's `Pelvis`, the
##                   zombie's `mixamorig_Hips`), within a hand's width -- and for the hound that bone
##                   is measurably NOT at the root, so a look left on the root fails this;
##   THE GLOW        the corpse's drawn mesh wears the ward's overlay; the look's own meshes do not;
##   THE GHOSTS      the row's authored number of ghosts circle above the anchor;
##   LEVEL-TRIGGERED when the extension is taken back (what a Counterspell's reversal writes), the
##                   look and the overlay are gone;
##   NOT BEFORE      a corpse nobody warded has no look.
##
## STATE IS POKED DIRECTLY for the summons, the kills, the extension and its reversal
## (`test_effect_presentation_live.gd`'s "right-sized poke"): what is under test is the presenter.
##
## Run: godot --headless --path . --script res://test/integration/test_hound_corpse_ward_live.gd

const KILL_FRAME := 10
const WARD_FRAME := 110
const CHECK_FRAME := 125
const UNWARD_FRAME := 126
const FINAL_FRAME := 140

## How far (planar) the look's anchor may sit from the corpse's hips bone.
const ON_BODY := 0.12

var _frames := 0
var _runner: Node
var _state: MatchState
var _effects: EffectPresenter
var _failures: Array[String] = []
var _corpse_ticks := 0


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
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
	var units := _state.p1.units
	if _frames == 3:
		var hound := _state.balance.kind_index_of(&"hellhound")
		var zombie := _state.balance.kind_index_of(&"minion")
		units.add(_state.balance.kind_at(hound).max_hp, hound)
		units.add(_state.balance.kind_at(zombie).max_hp, zombie)
	if _frames == KILL_FRAME:
		_corpse_ticks = _state.balance_ticks.corpse_lifetime_ticks
		units.kill_at(0, _corpse_ticks)
		units.kill_at(1, _corpse_ticks)
	if _frames == WARD_FRAME:
		for index in 2:
			_check(units.has_corpse_at(index), "fixture: record %d left a corpse" % index)
			_check(_corpse(index) != null and _corpse(index).get_node_or_null("GraveWardGlow") == null,
					"corpse %d wears the Grave Ward look before any ward" % index)
		# `MatchState._apply_grave_ward`'s own write, per corpse.
		for index: int in units.corpse_indices():
			units.extend_corpse_at(index, 600)
	if _frames == CHECK_FRAME:
		_check_look(0, &"Pelvis", "the hound's corpse", true)
		_check_look(1, &"mixamorig_Hips", "the zombie's corpse", false)
	if _frames == UNWARD_FRAME:
		# What a Counterspell's reversal of the ward writes: the lifetime back, the mark off.
		for index in 2:
			units.restore_corpse_at(index, units.corpse_ticks_at(index) - 600, false)
	if _frames == FINAL_FRAME:
		for index in 2:
			var corpse := _corpse(index)
			_check(corpse != null, "corpse %d was freed while its lifetime ran" % index)
			if corpse == null:
				continue
			_check(corpse.get_node_or_null("GraveWardGlow") == null
					or corpse.get_node("GraveWardGlow").is_queued_for_deletion(),
					"corpse %d keeps the Grave Ward look after the extension was taken back" % index)
			for mesh: MeshInstance3D in _body_meshes(corpse):
				_check(mesh.material_overlay == null, "corpse %d's body keeps the ward overlay after the reversal" % index)
		return _finish("")
	return false


func _check_look(index: int, bone_name: StringName, what: String, bone_off_root: bool) -> void:
	var units := _state.p1.units
	var corpse := _corpse(index)
	_check(corpse != null, "%s has no actor" % what)
	if corpse == null:
		return
	_check(units.is_corpse_extended_at(index), "%s is not marked extended in state" % what)
	var glow := corpse.get_node_or_null("GraveWardGlow") as Node3D
	_check(glow != null, "%s wears no Grave Ward look" % what)
	if glow == null:
		return
	var skeletons := corpse.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var bone := skeleton.find_bone(bone_name) if skeleton != null else -1
	_check(bone >= 0, "%s has no `%s` bone" % [what, bone_name])
	if bone < 0:
		return
	var hips := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	var anchor := glow.get_node_or_null("HipsAnchor") as Node3D
	_check(anchor != null, "%s's look has no anchor" % what)
	if anchor == null:
		return
	var off_root := _planar(hips, corpse.global_position)
	if bone_off_root:
		_check(off_root > 0.3,
				"fixture: %s's `%s` lies only %.3f m from its root -- the test cannot tell the body from the root"
						% [what, bone_name, off_root])
	_check(_planar(anchor.global_position, hips) < ON_BODY,
			"%s's Grave Ward look sits %.3f m from its `%s` (which lies %.3f m from the root): not on the body"
					% [what, _planar(anchor.global_position, hips), bone_name, off_root])
	_check(absf(anchor.global_position.y - hips.y) < ON_BODY,
			"%s's look is anchored %.3f m above its `%s`" % [what, anchor.global_position.y - hips.y, bone_name])
	# The glow: the drawn body wears the overlay.
	var body := _body_meshes(corpse)
	_check(not body.is_empty(), "%s draws no body mesh" % what)
	for mesh: MeshInstance3D in body:
		_check(mesh.material_overlay != null and mesh.get_meta(&"effect_overlay", &"") == &"grave_ward",
				"%s's body mesh `%s` does not wear the ward's overlay" % [what, mesh.name])
		_check(mesh.visible, "%s's body mesh `%s` is hidden" % [what, mesh.name])
	# The ghosts: the row's number of them, above the anchor.
	var row := _effects.row(&"grave_ward")
	var ghosts := glow.get_node_or_null("HipsAnchor/Ghosts") as Node3D
	_check(ghosts != null and ghosts.get_child_count() == maxi(row.count, 1),
			"%s has %d ghosts, the row authors %d" % [what, ghosts.get_child_count() if ghosts != null else -1, row.count])
	if ghosts != null:
		_check(ghosts.global_position.y > anchor.global_position.y + 0.5,
				"%s's ghosts are not above its body (%.3f against %.3f)" % [what, ghosts.global_position.y, anchor.global_position.y])
		_check(_planar(ghosts.global_position, hips) < ON_BODY,
				"%s's ghosts circle a point %.3f m from its body" % [what, _planar(ghosts.global_position, hips)])


## The meshes that draw the corpse itself: every MeshInstance3D that is not part of the look.
func _body_meshes(corpse: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for node: Node in corpse.find_children("*", "MeshInstance3D", true, false):
		var walk := node
		var is_look := false
		while walk != null and walk != corpse:
			if walk.name == &"GraveWardGlow":
				is_look = true
			walk = walk.get_parent()
		if not is_look:
			out.append(node as MeshInstance3D)
	return out


func _corpse(index: int) -> UnitActor:
	var actors: Array = _runner._unit_actors[0]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	return node as UnitActor


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _finish(error: String) -> bool:
	if error != "":
		_failures.append(error)
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
