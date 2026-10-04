class_name EffectFx
extends RefCounted

## Story 7-1: THE SHARED BUILDING BLOCKS every effect row is made of -- a one-shot particle burst, a continuous
## emitter, a textured quad, a timed self-free, and the lightning ribbon. Static and stateless: each call builds
## a node from plain values and hands it back, so no row carries its own copy of the same particle set-up.
##
## PRESENTATION ONLY, and the reason it is safe to be generous here: nothing built by this file has a collision
## shape, an `Area3D` or a signal into state. Particles are `GPUParticles3D` (they cost nothing on the headless
## dummy renderer the suite runs on, and run on the GPU in play -- the `4-5` frame budget is per-CPU).
##
## TEXTURES: only the eleven Kenney (CC0) particle textures `tools/ingest_effect_assets.py` keeps.

const TEX_RING := preload("res://assets/vfx/circle_02.png")
const TEX_GLOW := preload("res://assets/vfx/circle_05.png")
const TEX_DEBRIS := preload("res://assets/vfx/dirt_02.png")
const TEX_FLAME := preload("res://assets/vfx/flame_04.png")
const TEX_RUNE := preload("res://assets/vfx/magic_02.png")
const TEX_CRACK := preload("res://assets/vfx/scorch_02.png")
const TEX_SMOKE := preload("res://assets/vfx/smoke_04.png")
const TEX_SPARK := preload("res://assets/vfx/spark_02.png")
const TEX_STAR := preload("res://assets/vfx/star_06.png")
const TEX_WISP := preload("res://assets/vfx/trace_04.png")
const TEX_SWIRL := preload("res://assets/vfx/twirl_02.png")


## An unshaded, vertex-coloured, alpha-blended (or additive) material for a particle or a quad.
static func material(texture: Texture2D, color: Color, additive: bool = true,
		billboard: int = BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_texture = texture
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = billboard
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	return mat


## A particle emitter. `one_shot` bursts are freed by `free_after` at the caller; continuous ones live with
## their parent. `local` false leaves a world-space trail behind a moving parent.
static func particles(texture: Texture2D, color: Color, amount: int, lifetime: float, size: float,
		speed: float, spread: float = 180.0, gravity: float = 0.0, one_shot: bool = true,
		local: bool = false, additive: bool = true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = maxf(lifetime, 0.05)
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.local_coords = local
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0.0, -gravity, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material(texture, Color.WHITE, additive)
	p.draw_pass_1 = quad
	p.emitting = true
	return p


## 7-1 polish round: spawn `p`'s particles inside a sphere of `radius` (an envelope around a core, sparks around a
## head) instead of at one point.
static func emit_sphere(p: GPUParticles3D, radius: float) -> GPUParticles3D:
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(radius, 0.001)
	return p


## 7-1 polish round: spawn `p`'s particles inside a box of half-size `extents` (a body-hugging aura).
static func emit_box(p: GPUParticles3D, extents: Vector3) -> GPUParticles3D:
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	return p


## 7-1 polish round: a continuous emitter that is FULL on its first frame (a short stun must not spend half its
## life filling up) -- the particles are simulated one lifetime ahead.
static func prewarm(p: GPUParticles3D) -> GPUParticles3D:
	p.preprocess = p.lifetime
	return p


## 7-1 polish round: each particle shrinks to nothing over its life -- what makes a world-space trail read as a
## tapering flare rather than a row of equal blobs.
static func shrink_over_life(p: GPUParticles3D) -> GPUParticles3D:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	(p.process_material as ParticleProcessMaterial).scale_curve = tex
	return p


## 7-1 polish round: a node that FOLLOWS ONE BONE of `actor`'s skeleton, parented under `parent` (so freeing the
## look frees it) -- a `BoneAttachment3D` on an EXTERNAL skeleton. Answers null when the actor has no skeleton or
## no such bone; the caller degrades to the actor root.
static func bone_follower(actor: Node, parent: Node, bone: StringName) -> BoneAttachment3D:
	var skeletons := actor.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var skeleton := skeletons[0] as Skeleton3D
	if skeleton.find_bone(bone) < 0:
		return null
	var attach := BoneAttachment3D.new()
	parent.add_child(attach)
	attach.use_external_skeleton = true
	attach.external_skeleton = attach.get_path_to(skeleton)
	attach.bone_name = bone
	return attach


## A flat textured quad: `billboard` faces the camera, otherwise it lies flat on the ground (a decal-like
## crack or rune circle).
static func quad(texture: Texture2D, color: Color, size: float, billboard: bool,
		additive: bool = true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	if not billboard:
		q.orientation = PlaneMesh.FACE_Y
	mesh.mesh = q
	mesh.material_override = material(texture, color, additive,
			BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## A soft omni light: the Fireball's ground light, a flash.
static func light(color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	return l


## Free `node` after `seconds`. The tween is bound to the node, so freeing it early (a reset) kills the tween.
static func free_after(node: Node, seconds: float) -> void:
	if not node.is_inside_tree():
		node.queue_free()
		return
	var tween := node.create_tween()
	tween.tween_interval(maxf(seconds, 0.0))
	tween.tween_callback(node.queue_free)


## A one-shot burst parented under `parent` at world `position`, freed when its particles are done.
static func burst(parent: Node, position: Vector3, texture: Texture2D, color: Color, amount: int,
		lifetime: float, size: float, speed: float, spread: float = 180.0, gravity: float = 0.0,
		additive: bool = true) -> GPUParticles3D:
	var p := particles(texture, color, amount, lifetime, size, speed, spread, gravity, true, false, additive)
	parent.add_child(p)
	p.global_position = position
	free_after(p, lifetime + 0.2)
	return p


## THE LIGHTNING RIBBON (Honed Bolt, `7-1` Scope): a jagged main channel from `top` to `bottom` plus `branches`
## forks, each segment drawn as TWO crossed quads so the bolt reads from any camera bearing in both viewports.
## The jitter is a COSMETIC stream (`rng`), never the gameplay RNG.
static func lightning_mesh(top: Vector3, bottom: Vector3, branches: int, width: float,
		rng: RandomNumberGenerator) -> ArrayMesh:
	var verts := PackedVector3Array()
	var main := _jagged(top, bottom, 10, (top - bottom).length() * 0.06, rng)
	_ribbon(verts, main, width)
	for b in branches:
		var from: Vector3 = main[rng.randi_range(1, main.size() - 3)]
		var dir := Vector3(rng.randf_range(-1.0, 1.0), -rng.randf_range(0.6, 1.4), rng.randf_range(-1.0, 1.0))
		var length := (top - bottom).length() * rng.randf_range(0.12, 0.3)
		var fork := _jagged(from, from + dir.normalized() * length, 5, length * 0.12, rng)
		_ribbon(verts, fork, width * 0.55)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _jagged(from: Vector3, to: Vector3, segments: int, jitter: float,
		rng: RandomNumberGenerator) -> PackedVector3Array:
	var points := PackedVector3Array()
	for i in segments + 1:
		var t := float(i) / segments
		var p := from.lerp(to, t)
		if i > 0 and i < segments:
			p += Vector3(rng.randf_range(-jitter, jitter), 0.0, rng.randf_range(-jitter, jitter))
		points.append(p)
	return points


static func _ribbon(verts: PackedVector3Array, points: PackedVector3Array, width: float) -> void:
	var half := width * 0.5
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		for side: Vector3 in [Vector3(half, 0.0, 0.0), Vector3(0.0, 0.0, half)]:
			verts.append_array(PackedVector3Array([a - side, a + side, b + side, a - side, b + side, b - side]))
