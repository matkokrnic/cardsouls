class_name GamepadProfile
extends Resource

## Gamepad button/axis mapping + stick deadzone (story 2-2, ruling 2-2/R2). AUTHORED DATA in
## the camera_config.tres pattern: load-once presentation/feel, deliberately OUTSIDE
## BalanceConfig and the X3 hot-reload path — but CONTROLLER-owned (input-hardware mapping,
## not camera framing), so its script lives under src/controllers/ (the "a resource script
## lives in its owner's domain folder" precedent ratified in 2-2/A7). Authored as
## data/gamepad_profile.tres.
##
## This is the narrow, recorded exception to "named actions, never raw" (project-context.md):
## the raw joypad indices live EXACTLY ONCE — as the authored values in the .tres. The exports
## are typed with the engine's JoyButton / JoyAxis enums and DEFAULT to NAMED constants (2-2
## review D1), so a wrong integer cannot be authored by accident (the first draft's block=5 was
## JOY_BUTTON_GUIDE, a SYSTEM button, not a shoulder) and the inspector shows names, not magic
## numbers.
##
## Scheme (operator ruling, 2-2 review D1) — the Sekiro line CardSouls is on: attack = R1 (RB),
## block/deflect = L1 (LB), dodge = B. Playtesters arrive with that muscle memory and are
## instrumentation, not an audience. Authored against the SDL/Godot X-input mapping (2-2/A6),
## valid only with the F310 switch in X mode; in D (DirectInput) mode the same physical button
## reports a different index and the profile is silently wrong — verified live at smoke.

@export var move_axis_x: JoyAxis = JOY_AXIS_LEFT_X               # left stick horizontal
@export var move_axis_y: JoyAxis = JOY_AXIS_LEFT_Y               # left stick vertical (+Y is DOWN)
@export var attack_button: JoyButton = JOY_BUTTON_RIGHT_SHOULDER  # R1 — attack
@export var block_button: JoyButton = JOY_BUTTON_LEFT_SHOULDER    # L1 — block / deflect
@export var roll_button: JoyButton = JOY_BUTTON_B                 # B  — dodge / roll
@export var deadzone: float = 0.2   # stick magnitude below which move_dir resolves to ZERO

## Story 4-6 (AC 12, `CC/R3`): the RIGHT STICK and the STICK CLICK. NEW authored fields -- before
## this story this resource covered the left stick and three face/shoulder buttons and nothing
## else, so these are additions, not a rename or a widening of anything that existed.
##
## Same discipline as their neighbours above: typed with the engine's JoyAxis / JoyButton enums and
## defaulted to NAMED constants (2-2 review D1), so the inspector shows names rather than magic
## numbers and a wrong integer cannot be authored by accident. Read the same DEVICE-FILTERED way
## GamepadController already reads the left stick and the three buttons -- no Input Map action is
## added (the 2-2 precedent, and D3(a) keeps the read in that one file).
##
## JOY_BUTTON_RIGHT_STICK is R3, the right stick pressed IN -- the Souls/Sekiro lock button, which
## is the muscle memory the 2-2 scheme note says playtesters arrive with.
@export var look_axis_x: JoyAxis = JOY_AXIS_RIGHT_X               # right stick horizontal
@export var look_axis_y: JoyAxis = JOY_AXIS_RIGHT_Y               # right stick vertical (+Y is DOWN)
@export var lock_button: JoyButton = JOY_BUTTON_RIGHT_STICK       # R3 - re-lock onto the opposing hero

## Story 4-6 (AC 10): how far the right stick must be pushed before it counts as a FLICK, as a
## fraction of full deflection. AUTHORED here rather than hardcoded for the reason `deadzone` and
## `normalize_move_magnitude` are: it is input FEEL, it belongs to the load-once controller-owned
## profile, and it is deliberately OUTSIDE BalanceConfig and the X3 hot-reload path (2-2/R2).
##
## DELIBERATELY WELL ABOVE `deadzone`. The deadzone answers "is the stick being touched"; this
## answers "did the player mean to switch targets", and a retarget triggered by a resting thumb is
## worse than one that needs a deliberate shove. The flick is an EDGE (see GamepadController), so
## this is the threshold the stick must CROSS, not one it must be held past.
@export var flick_threshold: float = 0.7

## Story 2-6 (AC 4, 2-6/R8): variable-analog-magnitude toggle. TRUE (shipped default) = today's
## behaviour — above the deadzone the stick vector is normalized to unit length, so a partial
## deflection is binary-speed movement (keyboard parity, 2-2/R5). FALSE = the stick's actual
## magnitude passes through (clamped to length 1.0), so a partial deflection yields a partial
## move_dir magnitude. An AUTHORED field on this same load-once resource that already owns the
## mapping and deadzone — NOT a FeatureFlags member (2-6/R4): replay stays safe because the
## resulting magnitude is folded into the recorded InputIntent.move_dir, never a separate flag.
## The debug instrument panel flips this IN MEMORY on the shared instance only — never persisted.
@export var normalize_move_magnitude: bool = true
