class_name TargetConeActor
extends Node3D

## Story 6-5d (AC 28, `6-5d/R10`): THE PLACEHOLDER TARGET CONE -- the warning marker for a cast aimed
## at a MINION OR TOTEM. PURE PRESENTATION, on `BoltActor`'s precedent and for its stated reasons: no
## state object, no hitbox, no board entry, no `push_contact`, no `.tscn` (it composes nothing a
## designer would edit), and it never gates or changes an outcome.
##
## WHY A SECOND MARKER RATHER THAN THE HERO'S. A hero carries a `TelegraphController` that owns its
## cast-warning marker and alarm; a unit actor has no such controller and no equivalent of one, and
## giving every minion one so a cast could mark it would be a presentation subsystem this story does
## not own. AC 28 asks for a placeholder cone on the unit, which is exactly what a runner-owned prop
## positioned over that unit each poll is -- the `DaggerActor` / `BoltActor` shape, third use.
##
## EXPLICITLY A PLACEHOLDER (Non-Goals: real VFX for the cone is owed to the Tier B presentation story
## after `6-5f`). What AC 28 makes non-negotiable is the DESTINATION, not the look: the marker must sit
## on the CAPTURED target and never on a non-target. Legibility is judged at operator smoke (`PROC/R8`).
##
## NO `_physics_process` (INVARIANT F1 -- the scan covers all of `src/`): the runner moves it from its
## own one tick loop, the same seat that drives every other actor.

## Placeholder-aesthetic model, the `BoltActor` doctrine verbatim ("Pure sub-resource authoring, no
## assets"): an unshaded, emissive cone hanging point-down over the marked body, so the mark reads from
## above the crowd rather than being hidden inside it. AMBER rather than either card colour -- it marks
## a TARGET, and it must not be mistaken for a colour-counter or orb cue.
const CONE_HEIGHT := 0.9
const CONE_RADIUS := 0.35
const HOVER_HEIGHT := 2.1
const CONE_COLOR := Color(1.0, 0.72, 0.2, 1.0)


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	# A cone is a cylinder with one radius at zero. Point DOWN (top wide, bottom zero) so the tip
	# indicates the body beneath it.
	cone.top_radius = CONE_RADIUS
	cone.bottom_radius = 0.0
	cone.height = CONE_HEIGHT
	mesh.mesh = cone
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CONE_COLOR
	mesh.material_override = material
	add_child(mesh)


## Sit above `target`. Called once per tick by the runner's cast-presentation poll while the cast runs;
## a marked body that moves takes its mark with it.
func hover_over(target: Vector3) -> void:
	global_position = target + Vector3(0.0, HOVER_HEIGHT, 0.0)
