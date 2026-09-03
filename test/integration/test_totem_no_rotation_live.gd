extends SceneTree

## Story 5-0c (second corrective fix pass, operator-ruled on live smoke 2026-09-02): pins that A
## TOTEM NEVER VISUALLY ROTATES -- overturning `4-4`'s 2026-08-30 smoke verdict ("totem
## self-rotation, accepted as shipped"), which was passed on the grey-box placeholder, not the real
## model. `_aim_unit_actors` (`match_runner.gd`) now skips `aim_at`/`aim_along` for any actor under
## the totem scene shape (`Mesh/Totem`), while a MINION actor is never skipped -- both halves are
## asserted here, non-vacuously, the same "prove the skip is real AND the skip does not over-reach"
## shape `test_totem_tint_live.gd`'s own header argues for a headless-blind-spot pin.
##
## DIRECT BOARD INJECTION, not a card cast: same reason `test_totem_tint_live.gd` gives -- the
## resolver-to-board half of a summon is `test_summon_actor_live.gd`'s coverage already, and this
## file only needs kind index -> spawned actor -> observed yaw over time.
##
## Run: godot --headless --path . --script res://test/integration/test_totem_no_rotation_live.gd

const SPAWN_CHECK_FRAME := 4
## Comfortably more than the authored 0.2 s / 12-tick retarget interval past the spawn check, so at
## least one targeting boundary has certainly passed for the minion (`test_unit_aim_live.gd`'s own
## margin).
const AIM_CHECK_FRAME := 40
## Yaw tolerance in radians -- float-noise-only, `test_unit_aim_live.gd`'s own constant.
const YAW_EPSILON := 0.01

var _frames := 0
var _runner: Node
var _state: MatchState

var _totem: Node3D
var _minion: Node3D
var _totem_spawn_yaw := 0.0
var _minion_spawn_yaw := 0.0
var _detail := ""


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			print("missing: runner=%s state=%s" % [_runner, _state])
			print("RESULT: FAIL")
			quit(1)
			return false
	if _frames == 2:
		var balance: BalanceConfig = _state.balance
		for kind_name in [&"combat_totem", &"minion"]:
			var kind_index := balance.kind_index_of(kind_name)
			if kind_index == BalanceConfig.NO_KIND_INDEX:
				print("authored balance has no kind named ", kind_name)
				print("RESULT: FAIL")
				quit(1)
				return false
			var kind := balance.kind_at(kind_index)
			_state.p1.units.add(kind.max_hp, kind_index)
	if _frames == SPAWN_CHECK_FRAME:
		_totem = _find_totem_actor(root)
		_minion = _find_non_totem_unit_actor(root)
		if _totem == null or _minion == null:
			_detail += " missing totem=%s minion=%s;" % [_totem, _minion]
			print("totem_no_rotation_live:%s" % _detail)
			print("RESULT: FAIL")
			quit(1)
			return false
		_totem_spawn_yaw = _totem.global_rotation.y
		_minion_spawn_yaw = _minion.global_rotation.y
	if _frames == AIM_CHECK_FRAME:
		var hero: Node3D = _runner._p2_hero
		var totem_still := absf(angle_difference(_totem.global_rotation.y, _totem_spawn_yaw)) \
				<= YAW_EPSILON
		if not totem_still:
			_detail += " totem_rotated(spawn=%.4f now=%.4f);" % [
				_totem_spawn_yaw, _totem.global_rotation.y]
		var minion_aimed := false
		if hero == null:
			_detail += " missing hero;"
		else:
			var planar := Vector2(hero.global_position.x - _minion.global_position.x,
					hero.global_position.z - _minion.global_position.z)
			var expected := atan2(planar.x, planar.y) + PI
			minion_aimed = absf(angle_difference(_minion.global_rotation.y, expected)) \
					<= YAW_EPSILON
			# NON-VACUITY: the minion must actually have moved off its spawn heading, or an aim
			# step that did nothing would still pass this check.
			var minion_moved := absf(angle_difference(_minion.global_rotation.y,
					_minion_spawn_yaw)) > YAW_EPSILON
			if not minion_moved:
				minion_aimed = false
				_detail += " minion_never_turned(yaw=%.4f spawn=%.4f);" % [
					_minion.global_rotation.y, _minion_spawn_yaw]
			elif not minion_aimed:
				_detail += " minion_yaw=%.4f expected=%.4f;" % [
					_minion.global_rotation.y, expected]
		var ok := totem_still and minion_aimed
		print("totem_no_rotation_live: totem_still=%s minion_aimed=%s%s" % [
			totem_still, minion_aimed, _detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## Same `Mesh/Totem` scene-shape test `test_totem_tint_live.gd` keys on.
func _find_totem_actor(node: Node) -> Node3D:
	if node is UnitActor and not node.is_queued_for_deletion():
		if node.get_node_or_null("Mesh/Totem") != null:
			return node
	for child in node.get_children():
		var found := _find_totem_actor(child)
		if found != null:
			return found
	return null


## The minion counterpart: a live `UnitActor` that does NOT carry the totem scene shape.
func _find_non_totem_unit_actor(node: Node) -> Node3D:
	if node is UnitActor and not node.is_queued_for_deletion():
		if node.get_node_or_null("Mesh/Totem") == null:
			return node
	for child in node.get_children():
		var found := _find_non_totem_unit_actor(child)
		if found != null:
			return found
	return null
