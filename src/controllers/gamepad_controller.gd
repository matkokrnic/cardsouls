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

## Story 4-6: the `_prev_held` key the R3 edge is remembered under. A PRIVATE key that never
## reaches an InputIntent -- the lock click is not an intent action (AC 11 sends the RESOLVED
## ADDRESS inward instead), so it is deliberately NOT a member of INTENT_ACTIONS and the
## prefix-free intent-key contract is untouched. It rides the same dictionary because that
## dictionary is exactly "what was held last tick" and a second one would be a second answer to
## the same question.
const _LOCK_KEY := &"__lock"

var _device: int = NO_DEVICE
var _profile: GamepadProfile
var _button_map: Dictionary[StringName, int] = {}
## Previous-tick held state per intent key. Raw device buttons have no engine-tracked
## "just pressed" (unlike named actions), so the pressed EDGE is derived from this — attack and
## roll are edge-triggered downstream. Controller-private, never state; the emitted InputIntent
## stays a fresh per-tick value.
var _prev_held: Dictionary[StringName, bool] = {}

## Story 4-6 (AC 9/AC 10): the two RIGHT-STICK edges, sampled in sample() and read back by the
## runner in the same frame. Controller-private, never state, and never on the InputIntent -- what
## reaches the intent is the RESOLVED ADDRESS the runner computes from these (AC 11), which is why
## these are polled the way `armed_slot()` is rather than carried.
##
## SAMPLED IN sample() AND NOT IN THE ACCESSORS, deliberately: an accessor that read the device
## would report a different answer depending on how many times the runner called it, and edges
## must fire exactly once per sample. This is the `_prev_held` discipline directly above, applied
## to a button and a magnitude instead of three buttons.
var _lock_pressed := false
var _flick := Vector2.ZERO
## Previous-tick right-stick magnitude. Raw axes have no engine-tracked edge, so the FLICK edge is
## "crossed the authored threshold this tick, having been below it last tick" -- a held stick
## therefore flicks ONCE, not once per tick, which is the same one-press-one-action rule attack
## and roll get from `_prev_held`.
var _prev_flick_magnitude := 0.0


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
		# Story 4-6: the right-stick edges are cleared on the SAME neutral path and for the same
		# reason -- a pad unplugged mid-flick must not deliver that flick on reconnect. The
		# magnitude memory resets to 0.0 so a stick still deflected at reconnect re-arms the edge
		# rather than being read as "already past the threshold, no crossing".
		_lock_pressed = false
		_flick = Vector2.ZERO
		_prev_flick_magnitude = 0.0
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
	intent.move_dir = resolve_move_dir(raw, _profile.deadzone, _profile.normalize_move_magnitude)
	for key in INTENT_ACTIONS:
		var held := Input.is_joy_button_pressed(_device, _button_map[key])
		intent.held[key] = held
		intent.pressed[key] = held and not _prev_held.get(key, false)
		_prev_held[key] = held
	_sample_lock_controls()
	return intent


## Story 4-6 (AC 9/AC 10, `CC/R3`): the two right-stick edges, derived here and read back by the
## runner through `relock_pressed()` / `retarget_flick()` below. Split out of sample() rather than
## inlined so the intent-building above stays the 2-2 shape a reader already knows.
##
## THE CLICK IS EXCLUSIVE. A press of R3 is a re-lock onto the opposing hero (AC 9) and suppresses
## any flick the same thumb produced pushing the stick in -- pressing R3 deflects the stick, which
## would otherwise fire a spurious retarget in whatever direction the thumb rolled. The runner
## honours the same precedence (click checked first), so the rule is stated once at each layer and
## the two cannot disagree about which wins.
func _sample_lock_controls() -> void:
	var lock_held := Input.is_joy_button_pressed(_device, _profile.lock_button)
	_lock_pressed = lock_held and not _prev_held.get(_LOCK_KEY, false)
	_prev_held[_LOCK_KEY] = lock_held
	var raw := Vector2(
		Input.get_joy_axis(_device, _profile.look_axis_x),
		Input.get_joy_axis(_device, _profile.look_axis_y))
	_flick = resolve_flick(raw, _prev_flick_magnitude, _profile.flick_threshold, _lock_pressed)
	_prev_flick_magnitude = raw.length()


## Story 4-6 (AC 10): the FLICK EDGE policy, factored out as a PURE function for the reason
## `resolve_move_dir` below is -- joypad axes are not headless-samplable, so a policy left inline
## is a policy no test can reach. Same shape, same file, same discipline as 2-2's own extraction.
##
## THE EDGE: the stick must have CROSSED the authored threshold this tick, having been below it
## last, so a held deflection flicks ONCE rather than once per tick. Y is read DIRECTLY, no
## inversion -- the 2-2 review-D2 argument verbatim, and here it is load-bearing twice over,
## because SCREEN space is +Y-down too and the raw stick vector therefore already IS the screen
## direction the resolver wants (see `Controller.retarget_flick`).
##
## `lock_pressed` SUPPRESSES the flick: pressing R3 deflects the stick with the same thumb, and
## without this a re-lock would also fire a spurious retarget in whatever direction the thumb
## rolled. AC 9 beating AC 10 is therefore structural rather than a matter of call order.
static func resolve_flick(raw: Vector2, prev_magnitude: float, threshold: float,
		lock_pressed: bool) -> Vector2:
	if lock_pressed:
		return Vector2.ZERO
	if raw.length() < threshold or prev_magnitude >= threshold:
		return Vector2.ZERO
	return raw.normalized()


## Story 4-6 (AC 9): the click edge sampled by `_sample_lock_controls`. See Controller's base
## declaration for why this is polled rather than carried on the intent.
func relock_pressed() -> bool:
	return _lock_pressed


## Story 4-6 (AC 10): the flick edge sampled by `_sample_lock_controls`, as a unit SCREEN-SPACE
## direction, or ZERO for no flick this tick.
func retarget_flick() -> Vector2:
	return _flick


## Deadzone + magnitude policy (2-2/R5, extended by 2-6/R8), factored out as a PURE function so
## the contract is headless-testable without a physical pad (joypad axes are not
## headless-samplable). Below the deadzone -> ZERO always. Above it, the magnitude policy is the
## authored GamepadProfile.normalize_move_magnitude, passed in so this stays pure:
##   normalize == true  (shipped default) -> the stick DIRECTION at unit length (2-2/R5 binary
##                        speed, keyboard parity).
##   normalize == false -> the stick's actual magnitude, clamped to length 1.0 — a partial
##                        deflection yields a partial move_dir magnitude (variable analog speed).
## The clamp reuses the analog-safety rule already in _resolve_movement (never exceed unit length,
## so downstream never speeds past move_speed). The default keeps every 2-arg caller unchanged.
static func resolve_move_dir(raw: Vector2, deadzone: float, normalize_magnitude := true) -> Vector2:
	if raw.length() < deadzone:
		return Vector2.ZERO
	if normalize_magnitude or raw.length() > 1.0:
		return raw.normalized()
	return raw
