class_name CameraRig
extends Node3D

## Actor-side camera rig (story 1-2). Third-person, FIXED framing: no zoom and no look
## input — camera rotation is OUT OF SCOPE for all of E1 (no Input Map action exists;
## tests rotate the rig programmatically). When a later story adds a look action it MUST
## flow controller -> InputIntent.aim -> runner -> rig; this node never touches the input
## singleton (D3(a)).
##
## The rig defines NO _physics_process (F1) and follows the hero via the scene tree. The
## runner's ONLY interaction with the rig is reading this node's LOCAL basis in step 2 and
## pushing it into MatchState per player slot (local, not global — DECISION A: the hero
## root must never fold its rotation into the camera basis; see set_camera_basis). This
## node is the YAW pivot; pitch lives on the child camera, so the basis the runner reads
## is yaw-only by construction (state still flattens defensively — pitch can never tilt
## movement).
##
## Framing values come from the authored camera config .tres (presentation config — NOT
## BalanceConfig, NOT X3 hot-reload), loaded ONCE at scene setup.

const CONFIG_PATH := "res://data/camera_config.tres"

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	apply_config(load(CONFIG_PATH) as CameraConfig)


## Framing is data-authored, never scene-script literals. Null-safe: a missing .tres
## leaves the scene's neutral defaults and warns rather than crashing match setup.
func apply_config(config: CameraConfig) -> void:
	if config == null:
		push_warning("CameraRig: no camera config at %s — using neutral framing" % CONFIG_PATH)
		return
	_camera.position = Vector3(0.0, config.height, config.distance)
	_camera.rotation_degrees = Vector3(config.pitch_degrees, 0.0, 0.0)
