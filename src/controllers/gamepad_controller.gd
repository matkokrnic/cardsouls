class_name GamepadController
extends Controller

## D3 gamepad controller (story 2-2). The SECOND Controller implementation. Reads
## DEVICE-FILTERED joypad state directly — Input.get_joy_axis(device, ...) and
## Input.is_joy_button_pressed(device, ...) — one of the ONLY sites where Input.* may appear
## (INVARIANT D3(a); this file lives under src/controllers/). Button/axis mapping and the
## deadzone are AUTHORED DATA in a load-once, controller-owned GamepadProfile (2-2/R2); no raw
## joypad constant appears inline here.
##
## It emits the IDENTICAL InputIntent shape as KeyboardController — the runner cannot tell them
## apart (the source-agnostic advance() contract, AC5). Intent keys are PREFIX-FREE (story 1-3):
## the state reads &"attack" / &"block" / &"roll" and never learns the source. 360-degree facing
## arrives for free: the analog move_dir already flows through _resolve_movement like any move
## vector; this controller adds no facing code and no atan2.
##
## Above the deadzone the stick vector is NORMALIZED to unit length before it becomes move_dir
## (2-2/R5): a partial stick deflection is binary-speed movement, NOT a fraction of move_speed —
## keyboard parity in a local match where one player may be on a keyboard.

## Same prefix-free intent keys as KeyboardController.
const INTENT_ACTIONS: Array[StringName] = [&"attack", &"block", &"roll"]

## No physical joypad bound: never-connected at construction (assigned ordinal has no matching
## connected joypad), or the assigned device is not currently connected (disconnected mid-match).
## sample() short-circuits to a neutral intent through this ONE shared path — no crash, no pause
## (AC3b). Device index is assigned ONCE at construction and never re-assigned; connectivity is
## re-checked each tick so a replug at the same index restores control for free.
const NO_DEVICE := -1

var _device: int = NO_DEVICE
var _profile: GamepadProfile
var _button_map: Dictionary[StringName, int] = {}
## Previous-tick held state per intent key. Raw device buttons have no engine-tracked
## "just pressed" (unlike named actions), so the pressed EDGE is derived from this — attack and
## roll are edge-triggered downstream. Controller-private, never state; the emitted InputIntent
## stays a fresh per-tick value.
var _prev_held: Dictionary[StringName, bool] = {}


## slot_gamepad_ordinal: WHICH gamepad this is among the configured GAMEPAD slots (the i-th
## GAMEPAD in slot_controller_kinds), NOT the player slot. The i-th GAMEPAD takes the i-th entry
## of Input.get_connected_joypads() — the device index comes from the connected-joypads list,
## never from the player slot (AC3; the Flip-2 live proof that slot 1 still binds the one pad).
func _init(slot_gamepad_ordinal: int, profile: GamepadProfile) -> void:
	_profile = profile
	_button_map = {
		&"attack": profile.attack_button,
		&"block": profile.block_button,
		&"roll": profile.roll_button,
	}
	var pads := Input.get_connected_joypads()
	if slot_gamepad_ordinal >= 0 and slot_gamepad_ordinal < pads.size():
		_device = pads[slot_gamepad_ordinal]
		# REQUIRED by the Live Smoke: name the device actually bound, so the smoke record is
		# truthful about which pad drove the slot.
		print("[gamepad] slot ordinal %d -> device %d (%s)"
			% [slot_gamepad_ordinal, _device, Input.get_joy_name(_device)])
	else:
		_device = NO_DEVICE
		print("[gamepad] slot ordinal %d -> NO DEVICE (%d joypad(s) connected)"
			% [slot_gamepad_ordinal, pads.size()])


func sample() -> InputIntent:
	var intent := InputIntent.new()  # fresh per tick (never a reused mutable instance)
	# The ONE shared neutral path: no device was ever bound, OR the bound device is not
	# currently connected (disconnected mid-match). No crash, no pause — just a neutral intent.
	if _device == NO_DEVICE or not Input.get_connected_joypads().has(_device):
		_prev_held.clear()  # so a button held across a reconnect does not fire a stale edge
		return intent
	# Y SIGN (2-2 review D2), verified by content + test, NOT an accident: raw Y is read
	# DIRECTLY, no inversion. JOY_AXIS_LEFT_Y is positive-DOWN, so a stick pushed UP reads a
	# NEGATIVE Y; KeyboardController does Input.get_vector(_left, _right, _up, _down), whose
	# signature is get_vector(neg_x, pos_x, neg_y, pos_y) — so its _up is the NEGATIVE-Y arg and
	# keyboard "up" is ALSO -Y. The two conventions coincide, so an inversion would MISMATCH the
	# keyboard, not fix it. Pinned by test_gamepad_stick_up_matches_keyboard_up (compares to the
	# keyboard's actual output, not a chosen literal).
	var raw := Vector2(
		Input.get_joy_axis(_device, _profile.move_axis_x),
		Input.get_joy_axis(_device, _profile.move_axis_y))
	intent.move_dir = resolve_move_dir(raw, _profile.deadzone)
	for key in INTENT_ACTIONS:
		var held := Input.is_joy_button_pressed(_device, _button_map[key])
		intent.held[key] = held
		intent.pressed[key] = held and not _prev_held.get(key, false)
		_prev_held[key] = held
	return intent


## Deadzone + unit normalization (2-2/R5), factored out as a PURE function so the
## below-threshold-zero / above-threshold-unit-length contract is headless-testable without a
## physical pad (joypad axes are not headless-samplable). Below the deadzone -> ZERO; at or above
## -> the stick DIRECTION at unit length, so partial deflection is not fractional-speed movement.
static func resolve_move_dir(raw: Vector2, deadzone: float) -> Vector2:
	if raw.length() < deadzone:
		return Vector2.ZERO
	return raw.normalized()
