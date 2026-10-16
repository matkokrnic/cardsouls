extends Node3D
## 7-7 pre-playtest pass: a small HP bar (current / max) floating above the UNIT a player has locked, tinted with the
## LOCKING player's colour so the two players can tell whose lock it is. PRESENTATION ONLY: the runner pushes the
## world point and the two hp numbers every tick (`show_at`) or hides it (`hide_bar`); nothing here reads state.
## Heroes never get one -- their HP is on the HUD.

const SHADER := preload("res://src/actors/props/lock_hp_bar.gdshader")
## The bar's size in metres (a camera-facing quad).
const BAR_SIZE := Vector2(0.9, 0.11)
## The locking player's tint, by slot -- the 7-3 owner-skin colours (P1 purple, P2 red).
const SLOT_TINTS: Array[Color] = [Color(0.72, 0.38, 1.0), Color(1.0, 0.25, 0.2)]
## 7-7 smoke fix: each slot's bar renders on its OWN visual layer (11 for P1, 12 for P2; nothing else in the project
## sets a layer), and the runner drops the OTHER slot's layer from each view camera's cull mask -- so only the
## locking player sees their bar.
const VISUAL_LAYER_BY_SLOT: Array[int] = [1 << 10, 1 << 11]

var _material: ShaderMaterial
var _mesh: MeshInstance3D


func _init() -> void:
	name = "LockHpBar"
	var quad := QuadMesh.new()
	quad.size = BAR_SIZE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_mesh = MeshInstance3D.new()
	_mesh.name = "Bar"
	_mesh.mesh = quad
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


## Tint the bar for the slot that LOCKS with it, and put it on that slot's own visual layer (set once, at creation).
func set_locking_slot(slot: int) -> void:
	var s := clampi(slot, 0, SLOT_TINTS.size() - 1)
	_material.set_shader_parameter(&"fill_color", SLOT_TINTS[s])
	_mesh.layers = VISUAL_LAYER_BY_SLOT[s]


## The test-facing read: the visual layer mask the bar renders on.
func visual_layers() -> int:
	return _mesh.layers


## Show the bar at `world` with `hp` of `max_hp` filled.
func show_at(world: Vector3, hp: float, max_hp: float) -> void:
	global_position = world
	_material.set_shader_parameter(&"fraction", clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0)
	visible = true


func hide_bar() -> void:
	visible = false


## The test-facing read: the filled fraction last pushed.
func fraction() -> float:
	return float(_material.get_shader_parameter(&"fraction"))
