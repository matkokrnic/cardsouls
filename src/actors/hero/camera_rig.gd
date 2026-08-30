class_name CameraRig
extends Node3D

## Actor-side camera rig (story 1-2). Third-person, framing (distance/height/pitch) FIXED and
## data-authored; no zoom.
##
## STORY 4-6 (AC 1/AC 8) CORRECTS THIS HEADER'S ROUTE SENTENCE, which had gone stale in the same
## pass that made it stale (`4-3a/R15`). It used to read "when a later story adds a look action it
## MUST flow controller -> InputIntent.aim -> runner -> rig". THAT ROUTE IS RETIRED: `CC/R2`
## SUPERSEDES free camera rotation rather than supplementing it, `InputIntent.aim` is deleted, and
## no look action exists or may be added.
##
## WHAT ROTATES THE RIG INSTEAD is the LOCK-ON YAW: the runner calls face_lock_direction() once
## per tick from the direction to this slot's locked target, at its existing per-tick seat and
## immediately BEFORE it reads this node's basis (match_runner.gd). The rig still never touches
## the input singleton (D3(a)) and still defines no _physics_process (F1) -- the yaw is a value
## PUSHED in, exactly as the framing is.
##
## The rig defines NO _physics_process (F1) and follows the hero via the scene tree. The
## runner's ONLY interaction with the rig is reading this node's LOCAL basis in step 2 and
## pushing it into MatchState per player slot (local, not global — DECISION A: the hero
## root must never fold its rotation into the camera basis; see set_camera_basis). This
## node is the YAW pivot; pitch lives on the child camera, so the basis the runner reads
## is yaw-only by construction (state still flattens defensively — pitch can never tilt
## movement). Story 4-6: that basis is no longer identity in live play, which is what makes
## camera-relative movement actually camera-relative for the first time (`3-0c/R2`).
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


## Story 4-6 (AC 1): the per-tick LOCK-ON YAW. Points this ROOT so that camera-forward (the
## rig's own -Z, which is where the child camera at +Z looks back through) lies along the
## world-space planar direction to this slot's locked target -- which frames the hero and the
## target together, the Souls/Sekiro lock-on shot.
##
## THE ROOT, NEVER THE CHILD, AND A SEPARATE WRITE FROM apply_config() (AC 1, `4-6/R1`): the
## authored framing values (distance/height/pitch) and their load-once path above are UNTOUCHED
## and stay the CHILD camera's concern. This function writes one Euler component on this node and
## nothing else, so a framing edit is still a single data/camera_config.tres change.
##
## THE YAW IS LOCAL, and that is DECISION A holding rather than being weakened. The runner pushes
## this node's LOCAL basis into state as "camera forward"; writing the world-space lock yaw into
## the LOCAL rotation is exactly what makes the pushed basis correct and keeps a (forbidden) hero
## ROOT rotation from folding into it -- guarded by test/integration/test_root_rotation_isolation.gd.
##
## A ZERO direction is NO FACT (co-located, or a target whose actor is not spawned) and leaves the
## rig where it is, the same "keep the last heading" rule the state-side facing write applies.
func face_lock_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	# atan2(-x, -y), NOT the hero's atan2(x, y): a hero's yaw points its local +Z along `facing`,
	# while the rig must point its local -Z along the same direction, so the two differ by exactly
	# the sign pair. One expression, stated once, for the same reason hero.gd computes one yaw.
	rotation.y = atan2(-direction.x, -direction.y)
