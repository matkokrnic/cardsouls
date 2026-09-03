extends SceneTree

## Story 5-0c (AC 2/AC 3): THE PRESENTATION-SIDE PIN this story's own Dev Notes flag as the
## suite's known blind spot — nothing in the headless state harness ever loads a `.tscn`, so a
## tint dispatch that silently no-ops (wrong node path, wrong kind name, a material that never
## lands) would pass every state test while all three totem kinds stayed the model's native teal.
##
## DIRECT BOARD INJECTION, not a card cast: `test_summon_actor_live.gd` already proves the
## resolver-to-board half of a totem summon (4-4's own coverage), so re-driving the same card/
## input plumbing here would duplicate that path for no new signal. What THIS file needs is kind
## index -> spawned actor -> tinted material, which `UnitBoard.add(max_hp, kind_index)` reaches
## directly, on the same "board growth triggers `_spawn_missing_unit_actors` next tick" property
## the runner already guarantees (`match_runner.gd:2270-2271`).
##
## Run: godot --headless --path . --script res://test/integration/test_totem_tint_live.gd

const SPAWN_CHECK_FRAME := 4

var _frames := 0
var _runner: Node
var _state: MatchState


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
		# Board order fixes the actor order (AC's own dispatch: board index -> spawn batch
		# index, `match_runner.gd:756-760`), so the expectation table below can zip against the
		# tree walk by position with no separate lookup.
		for kind_name in [&"combat_totem", &"mana_accelerator", &"stamina_accelerator"]:
			var kind_index := balance.kind_index_of(kind_name)
			if kind_index == BalanceConfig.NO_KIND_INDEX:
				print("authored balance has no kind named ", kind_name)
				print("RESULT: FAIL")
				quit(1)
				return false
			var kind := balance.kind_at(kind_index)
			_state.p1.units.add(kind.max_hp, kind_index)
	if _frames == SPAWN_CHECK_FRAME:
		var expected := {
			&"combat_totem": Color(0.85, 0.1, 0.1),
			&"mana_accelerator": Color(0.1, 0.35, 0.9),
			&"stamina_accelerator": Color(0.15, 0.75, 0.2),
		}
		var order: Array[StringName] = [
			&"combat_totem", &"mana_accelerator", &"stamina_accelerator",
		]
		var actors := _totem_actors_in_spawn_order()
		var ok := actors.size() == 3
		var detail := ""
		if not ok:
			detail += " actor_count=%d;" % actors.size()
		for i in mini(actors.size(), order.size()):
			var kind_name: StringName = order[i]
			var want: Color = expected[kind_name]
			var got: Variant = _measured_emission(actors[i])
			var matches: bool = got != null and (got as Color).is_equal_approx(want)
			if not matches:
				ok = false
				detail += " %s: want=%s got=%s;" % [kind_name, want, got]
		print("totem_tint_live: actors=%d%s" % [actors.size(), detail])
		print("RESULT: %s" % ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false


## Every `UnitActor` under `TotemActor`'s own scene shape (has a `Mesh/Totem` child — the totem
## scene AC 1 authors, never the minion one), walked in scene-tree ADD ORDER, which matches board-
## index order because `_spawn_missing_unit_actors` appends in that same order every tick
## (`match_runner.gd:729-760`).
func _totem_actors_in_spawn_order() -> Array:
	var found: Array = []
	_collect_totem_actors(root, found)
	return found


func _collect_totem_actors(node: Node, found: Array) -> void:
	if node is UnitActor and not node.is_queued_for_deletion():
		if node.get_node_or_null("Mesh/Totem") != null:
			found.append(node)
	for child in node.get_children():
		_collect_totem_actors(child, found)


## The tinted emission color this story's `_apply_totem_tint` (`match_runner.gd`) is expected to
## have set on every REAL `MeshInstance3D` (mesh != null) under the actor's `Mesh` node — `null`
## if fewer than two mesh instances contributed a color (the model mounts body + stand, so a
## partial tint or a container-only tint must read as failure, not vacuously pass), or if the
## contributing mesh instances disagree, either of which is a fresh bug this pin exists to catch.
func _measured_emission(actor: Node) -> Variant:
	var mesh_root := actor.get_node_or_null("Mesh")
	if mesh_root == null:
		return null
	var colors: Array = []
	_collect_emissions(mesh_root, colors)
	if colors.size() < 2:
		return null
	var first: Color = colors[0]
	for c in colors:
		if not (c as Color).is_equal_approx(first):
			return null
	return first


func _collect_emissions(node: Node, colors: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mat := (node as MeshInstance3D).material_override
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled:
			colors.append((mat as StandardMaterial3D).emission)
	for child in node.get_children():
		_collect_emissions(child, colors)
