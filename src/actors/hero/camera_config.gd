class_name CameraConfig
extends Resource

## Camera framing (story 1-2): third-person distance/height/pitch for the hero CameraRig.
## PRESENTATION config — deliberately NOT part of BalanceConfig and NOT on the X3
## hot-reload path. Authored as data/camera_config.tres (data-as-resources) and loaded
## ONCE at match setup, like FeatureFlags. Defaults are zero on purpose: framing numbers
## are authored in the .tres, never in code or scene-script literals.

@export var distance: float = 0.0        # metres behind the hero pivot (fixed — no zoom)
@export var height: float = 0.0          # metres above the hero pivot
@export var pitch_degrees: float = 0.0   # downward camera tilt; must never tilt movement

## Story 4-6a (AC 10): how fast the lock-on YAW chases its target bearing -- the fraction of the
## remaining angle the rig closes each TICK. 1.0 is the 4-6 behaviour verbatim (snap, no
## smoothing); smaller is lazier. The smoke verdict this answers was "flick radi ali cini mi se da
## je pre grub/nagao ... trebalo bi ga svakako smoothati" (playtest-log 31.8. item 6).
##
## PER TICK, NOT PER SECOND, and that is the whole reason this number is safe to have. The runner
## calls face_lock_direction() exactly once per physics tick, so a per-tick fraction needs no
## `delta` and no wall clock -- which is what lets the rig smooth without acquiring a
## `_physics_process` (F1) and keeps the value it feeds into the pushed camera basis a pure
## function of the tick index, exactly as A1 requires of anything reaching a hashed path.
##
## THIS ONE DEFAULTS TO 1.0, BREAKING THIS FILE'S "defaults are zero on purpose" RULE, deliberately:
## the zero-default doctrine exists so an unauthored framing number is visibly wrong rather than
## plausibly wrong, but 0.0 HERE means "the camera never turns at all", which is not a conspicuous
## default -- it is a broken game that looks like a deliberate one. 1.0 degrades to the shipped 4-6
## snap, the correct neutral. The authored value still lives in the .tres like every other field.
##
## ITS FEEL IS AN OPERATOR SMOKE SURFACE (`PROC/R8`), not a number this pass may declare correct;
## authoring it here rather than as a script literal is what makes retuning it a one-line .tres
## edit at the smoke, with no code change and no test change.
@export_range(0.0, 1.0) var lock_yaw_smoothing: float = 1.0

## Story 6-8 (AC 8): how fast the UNLOCKED camera turns under a full right-stick deflection (or a
## held rotate key), in DEGREES PER TICK. Per tick for `lock_yaw_smoothing`'s reason verbatim: the
## runner calls `CameraRig.rotate_free_yaw()` once per physics tick, so no `delta` and no wall clock
## are needed (F1), and the basis it feeds stays a pure function of the tick index (A1).
##
## ZERO DEFAULT, per this file's doctrine and NOT `lock_yaw_smoothing`'s exception: an unauthored 0
## is a camera that conspicuously does not turn when unlocked -- visibly wrong, the case the doctrine
## exists for -- while locked play is unaffected. The authored value lives in the .tres.
##
## ITS FEEL IS AN OPERATOR SMOKE SURFACE (`PROC/R8`, story 6-8 Live Smoke): the shipped number is a
## starting point for tuning, not a value this pass may declare correct.
@export var free_yaw_degrees_per_tick: float = 0.0
