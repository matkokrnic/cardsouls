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

## Story 4-6a (AC 10): the authored yaw-chase rate, read once in apply_config. 1.0 -- the shipped
## 4-6 snap -- is the initializer deliberately, so a missing or unreadable .tres degrades to the
## previous behaviour rather than to a camera that cannot turn (see CameraConfig.lock_yaw_smoothing).
##
## Review M5 warning: never author 0.0. An authored 0.0 freezes BOTH the camera yaw AND the
## camera-relative movement basis at whatever the first heading was, for the whole match --
## because the same pushed basis this yaw writes is what movement reads. 1.0 is the 4-6 instant
## snap; shipped default is 0.25 (`data/camera_config.tres`).
var _lock_yaw_smoothing := 1.0

## Story 4-6a (AC 10): has this rig ever been given a heading? The FIRST one snaps and every later
## one eases -- see face_lock_direction. Not derivable from `rotation.y` itself: zero is a legal
## heading, not an absence of one.
var _has_heading := false


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
	# Story 4-6a (AC 10): the yaw-chase rate rides in on the SAME authored resource and the SAME
	# load-once path as the framing above. Clamped rather than trusted: this multiplies an angle
	# every tick, and a value outside [0,1] would overshoot or wind the rig instead of easing it.
	_lock_yaw_smoothing = clampf(config.lock_yaw_smoothing, 0.0, 1.0)


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
## STORY 4-6a (AC 10/AC 11/AC 12) ADDS THE SMOOTHING, AND ADDS IT HERE RATHER THAN AT THE RUNNER'S
## step 1c -- which is Open Question 2's answer, and the one shape that satisfies AC 11.
##
## AC 11 NAMES THE HAZARD: step 1c computes ONE direction per slot and feeds TWO consumers -- this
## rig yaw (presentation, and through the pushed basis, hashed movement) and
## `MatchState.set_lock_direction` (the facing fact gating the INSTANT block arc). Low-pass
## filtering `lock_dirs` itself at the runner would smooth BOTH at once and put a lag on the block
## arc, which is gameplay. So the split is made by OWNERSHIP instead of by a second runner
## variable: the runner still computes and pushes ONE raw per-tick value, `set_lock_direction`
## still receives it untouched and INSTANT, and the smoothing lives entirely inside this function,
## on this node's own `rotation.y`. The two consumers stop sharing a value because this one keeps
## its own state; the runner did not have to learn about smoothing at all.
##
## STILL NO `_physics_process` (F1, AC 12): the runner calls this once per tick, so the per-tick
## fraction IS the clock. Nothing here reads `delta`, `Time` or `Engine`.
##
## THE KNOWN AND ACCEPTED CONSEQUENCE, stated so it is never read as a bug: the runner pushes THIS
## node's basis into state as "camera forward", so a smoothed yaw means a smoothed basis, and
## camera-relative movement follows the smoothed camera during a transition. That is what cameras
## do -- the alternative (movement snapping to a heading the player cannot see yet) is the actual
## defect. It moves no recorded semantics: the basis is captured and replayed through the existing
## `capture_set_camera_basis` channel exactly as before (`3-0c` AC 8), so a recording made with
## smoothing replays bit-for-bit and no new record channel is implied (story Open Question 5).
##
## THE FIRST HEADING SNAPS, every later one eases. A rig that has never been aimed has no heading
## to ease FROM -- easing from the scene's arbitrary zero would swing the camera across the arena
## at match start, which is a startup artefact rather than the on-lock transition AC 10 asks to
## soften. It is also what keeps "the rig frames its target" true from tick one.
func face_lock_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	# atan2(-x, -y), NOT the hero's atan2(x, y): a hero's yaw points its local +Z along `facing`,
	# while the rig must point its local -Z along the same direction, so the two differ by exactly
	# the sign pair. One expression, stated once, for the same reason hero.gd computes one yaw.
	var target_yaw := atan2(-direction.x, -direction.y)
	if not _has_heading or _lock_yaw_smoothing >= 1.0:
		rotation.y = target_yaw
		_has_heading = true
		return
	# lerp_angle, never a raw lerp: yaw wraps, and interpolating 3.1 -> -3.1 numerically would
	# spin the camera the long way round the arena on the one transition most likely to happen
	# mid-fight (a target crossing directly behind the hero).
	rotation.y = lerp_angle(rotation.y, target_yaw, _lock_yaw_smoothing)
