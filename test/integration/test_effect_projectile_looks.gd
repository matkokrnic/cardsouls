extends SceneTree

## Story 7-1 (AC 17 + AC 35): THE PROJECTILE LOOKS NEVER CHANGE WHAT HITS, AND THE FIREBALL NEVER READS LARGER
## THAN WHAT HITS.
##
## AC 35 (`7-1/R9`): for each projectile kind -- the totem shot (no effect id), Fireball, a Rocksling stone and a
## Corpse Bomb skull -- the shipped `projectile_actor.tscn` is instantiated and DRESSED exactly as the runner
## dresses it (`EffectPresenter.dress_projectile`), and its `Hitbox` is asserted identical to `e93dbee`'s: a
## SPHERE of radius 0.35, offset +0.7 y, `collision_layer` 4, `collision_mask` 2, `monitorable` false,
## `monitoring` true. Whatever skin a kind now wears, the hit volume is that one.
##
## AC 17 (`6-1d` honest geometry, `7-1/R9`): at the MINIMUM staging price and at `mana_cap`, the Fireball's SOLID
## core (the `FireballCore` sphere -- trail, sparks and light may extend beyond) has a world radius at or inside
## the `Hitbox` radius READ FROM THE SCENE, and its centre is the hit sphere's centre. Both ends of the range are
## read from authored data (the card hosting the X-scaled effect, its staging price, the effect's `mana_cap` and
## `damage_per_mana`) and the radii from the authored knob set -- so a retune of any of them that breaks the rule
## fails here.
##
## Run: godot --headless --path . --script res://test/integration/test_effect_projectile_looks.gd

const PROJECTILE_SCENE := preload("res://src/actors/projectiles/projectile_actor.tscn")

## `e93dbee`'s `projectile_actor.tscn` Hitbox, verbatim (`:5-6`, `:22-30`).
const E93_RADIUS := 0.35
const E93_OFFSET := Vector3(0.0, 0.7, 0.0)
const E93_LAYER := 4
const E93_MASK := 2

const KINDS: Array[StringName] = [&"", &"fireball", &"rocksling", &"corpse_bomb"]

var _failures: Array[String] = []
var _frames := 0
var _presenter: EffectPresenter


func _initialize() -> void:
	_presenter = EffectPresenter.new()
	root.add_child(_presenter)
	_presenter.setup(load(EffectPresentationSet.AUTHORED_PATH) as EffectPresentationSet, {
		Enums.CardColor.RED: load("res://data/telegraphs/charge_red.tres"),
		Enums.CardColor.BLUE: load("res://data/telegraphs/charge_blue.tres"),
		Enums.CardColor.GREEN: load("res://data/telegraphs/charge_green.tres"),
	})


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames != 2:
		return false
	var range := _fireball_range()
	_check(range.size() == 3, "found the X-scaled (Fireball) effect and its host card in data/")
	if range.size() == 3:
		_presenter.set_fireball_range(range[0], range[1], range[2])
	for kind: StringName in KINDS:
		_check_kind(kind, range)
	# The launch sounds the dressing started must be retired before quit (`EffectPresenter.stop_all_sounds`).
	_presenter.stop_all_sounds()
	OS.delay_msec(100)
	_presenter.queue_free()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
	return false


func _check_kind(kind: StringName, range: Array) -> void:
	var damages: Array[float] = [3.0]
	if kind == &"fireball" and range.size() == 3:
		damages = [range[0] * range[1], range[0] * range[2]]
	for damage: float in damages:
		var shot := PROJECTILE_SCENE.instantiate() as Node3D
		root.add_child(shot)
		shot.global_position = Vector3(3.0, 0.0, -2.0)
		_presenter.dress_projectile(shot, kind, damage)
		var label := "kind '%s' damage %.2f" % [kind, damage]
		var hitbox := shot.get_node_or_null("Hitbox") as Area3D
		var shape_node := shot.get_node_or_null("Hitbox/HitboxShape") as CollisionShape3D
		_check(hitbox != null and shape_node != null, "%s: Hitbox/HitboxShape present" % label)
		if hitbox != null and shape_node != null:
			var sphere := shape_node.shape as SphereShape3D
			_check(sphere != null, "%s: the hit shape is a SPHERE" % label)
			if sphere != null:
				_check(is_equal_approx(sphere.radius, E93_RADIUS), "%s: radius %.3f, e93dbee 0.35" % [label, sphere.radius])
			_check(shape_node.position.is_equal_approx(E93_OFFSET), "%s: offset %s, e93dbee +0.7 y" % [label, shape_node.position])
			_check(hitbox.collision_layer == E93_LAYER and hitbox.collision_mask == E93_MASK,
				"%s: layer/mask %d/%d, e93dbee 4/2" % [label, hitbox.collision_layer, hitbox.collision_mask])
			_check(not hitbox.monitorable and hitbox.monitoring, "%s: monitorable off, monitoring on" % label)
		var dressed := shot.get_node_or_null(NodePath(EffectPresenter.DRESS_NODE)) != null
		_check(dressed == (kind != &""), "%s: dressed=%s (the totem shot keeps its 5-0c look)" % [label, dressed])
		var mesh := shot.get_node_or_null("Mesh") as Node3D
		_check(mesh != null and mesh.visible == (kind == &""), "%s: default Mesh visible only for the totem shot" % label)
		if kind == &"fireball" and shape_node != null:
			_check_core(shot, shape_node, label)
		# 7-1 polish round: Fireball and the skull carry a flame envelope and a flare trail; the skull grows to the
		# hit sphere's diameter and never past it.
		if kind == &"fireball" or kind == &"corpse_bomb":
			_check(shot.find_child("FlameEnvelope", true, false) != null, "%s: a flame envelope" % label)
			_check(shot.find_child("FlareTrail", true, false) != null, "%s: a flare trail" % label)
		if kind == &"corpse_bomb" and shape_node != null:
			var dress := shot.get_node(NodePath(EffectPresenter.DRESS_NODE)) as Node3D
			var skull: Node3D = null
			for child: Node in dress.get_children():
				if child is Node3D and child.scene_file_path.ends_with("skull.glb"):
					skull = child
			var diameter := 2.0 * (shape_node.shape as SphereShape3D).radius
			_check(skull != null, "%s: the skull model is dressed" % label)
			if skull != null:
				_check(skull.scale.x <= diameter + 0.0001 and skull.scale.x >= diameter * 0.9,
					"%s: skull %.3f m grows to the hit sphere's diameter %.3f, never past it" % [label, skull.scale.x, diameter])
		shot.queue_free()


func _check_core(shot: Node3D, shape_node: CollisionShape3D, label: String) -> void:
	var core := shot.find_child("FireballCore", true, false) as MeshInstance3D
	_check(core != null, "%s: FireballCore present" % label)
	if core == null:
		return
	var sphere := core.mesh as SphereMesh
	var hit := shape_node.shape as SphereShape3D
	var scale := core.global_transform.basis.get_scale()
	var world_radius := sphere.radius * maxf(scale.x, maxf(scale.y, scale.z))
	var hit_radius := hit.radius * shape_node.global_transform.basis.get_scale().x
	_check(world_radius <= hit_radius + 0.0001,
		"%s: core radius %.4f must stay inside the hit sphere %.4f (AC 17)" % [label, world_radius, hit_radius])
	_check(core.global_position.distance_to(shape_node.global_position) < 0.0001,
		"%s: core centre %s concentric with the hit sphere %s" % [label, core.global_position, shape_node.global_position])


## [damage_per_mana, minimum staging price, mana_cap] of the X-scaled effect, found by walking the authored cards.
func _fireball_range() -> Array:
	var dir := DirAccess.open("res://data/cards/")
	if dir == null:
		return []
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var card := load("res://data/cards/" + f) as CardData
		if card == null:
			continue
		for pair: Array in [[card.basic_effect, card.cast_condition], [card.pitch_effect, card.pitch_condition]]:
			var effect := pair[0] as CardEffect
			var condition := pair[1] as CardCastCondition
			if effect != null and effect.damage_per_mana > 0.0 and condition != null:
				return [effect.damage_per_mana, condition.mana_cost, effect.mana_cap]
	return []


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
