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
