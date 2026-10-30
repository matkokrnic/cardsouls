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

## Same prefix-free intent keys as KeyboardController -- kept here as the documented shape of
## `_prev_held`'s public keys (referenced by `_LOCK_KEY`/`_PLAY_BASIC_KEY` below) even though
## `resolve_card_tick` (Story 5-0b) now takes attack/block/roll as named parameters rather than
## looping this array.
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

## Story 7-11 (AC 5): the `_prev_held` key X's BASIC play edge is remembered under. Same reasoning as
## `_LOCK_KEY` directly above -- the press is resolved into `InputIntent.card_commit` here, never carried
## as its own intent action, so it is deliberately NOT a member of INTENT_ACTIONS. (5-0b's A-button
## `_CAST_BASIC_KEY`, 5-7's B/X keys and 6-10's L3 key are gone with the meanings they remembered.)
const _PLAY_BASIC_KEY := &"__play_basic"
## Story 6-3a (AC 2): the `_prev_held` key the PITCH (Y) edge is remembered under. ONE key serves both of
## Y's meanings (stage, activate): they are one physical press edge, and which meaning it carries is
## decided by the pushed READY bool inside `resolve_card_tick` (7-11 R3), not by a second memory.
const _CAST_PITCH_KEY := &"__cast_pitch"
## Story 7-11 (AC 1): the `_prev_held` keys the four D-pad ARMING edges are remembered under, in the
## profile's direction order (left, up, down, right). Private, never intent actions.
const _DPAD_KEYS: Array[StringName] = [&"__dpad_left", &"__dpad_up", &"__dpad_down", &"__dpad_right"]
## Story 7-11 (AC 2): how many hand slots the arming tie-break walks, in ascending index order.
const HAND_SLOTS := 4

var _device: int = NO_DEVICE
var _profile: GamepadProfile
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
## Story 6-8 (AC 7): the unlocked camera's rotation axis, sampled in sample() with the two edges
## above and read back through `camera_rotate()`. A level, not an edge.
var _camera_rotate := 0.0

## Story 5-0b (AC 2/AC 9): the hand slot currently ARMED, or -1 for none -- the
## `KeyboardController._armed_slot` precedent exactly, exposed the same way through
## `armed_slot()` below (base `Controller` returns -1). Story 7-11 (R1, G1): STICKY -- set by a D-pad
## tap, kept through every play press, and cleared only when the armed card LEAVES its slot
## (`observe_hand_ids`), by `clear_armed_slot()` (round end, debug reset) and by the neutral path.
var _armed_slot: int = -1
## Story 5-0b (AC 2): previous-tick L2/R2 axis values, read and updated EVERY tick -- only a fresh
## CROSSING fires (7-11: a DEFENSE / UNBLOCKABLE play), never a trigger held past the threshold.
var _prev_l2 := 0.0
var _prev_r2 := 0.0
## Story 7-11 (R3): the own Pitch Zone's READY, as last pushed by the runner (`observe_pitch_ready`).
var _pitch_ready := false
## Story 7-11 (G1): the previous `hand_ids` push, the "before" side of the arm-clear transition.
var _hand_ids: Array = []
## Story 7-11 (AC 1): the profile's arming buttons and direction -> slot map, read ONCE at construction
## (the load-once profile), and the per-sample D-pad reads, written in place -- no per-tick allocation.
var _dpad_buttons: Array[JoyButton] = []
var _dpad_slots: Array[int] = []
var _dpad_raw: Array[bool] = [false, false, false, false]
var _dpad_prev: Array[bool] = [false, false, false, false]


## slot_gamepad_ordinal: WHICH gamepad this is among the configured GAMEPAD slots (the i-th
## GAMEPAD in slot_controller_kinds), NOT the player slot. The i-th GAMEPAD takes the i-th entry
## of Input.get_connected_joypads() — the device index comes from the connected-joypads list,
## never from the player slot (AC3; the Flip-2 live proof that slot 1 still binds the one pad).
func _init(slot_gamepad_ordinal: int, profile: GamepadProfile) -> void:
	_profile = profile
	_dpad_buttons = profile.dpad_buttons()
	_dpad_slots = profile.dpad_slots()
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
		# Story 6-8: an unplugged pad must not keep turning the camera at its last deflection.
		_camera_rotate = 0.0
		# Story 5-0b / 7-11 (AC 4): same neutral path, opposite reasoning -- the card-input prevs are primed
		# HELD, not cleared, because clearing them would PRIME the edges: a replug with a D-pad direction,
		# X, Y or a trigger already down would read as a fresh press and arm or play with no new press.
		# Priming HELD forces every card input to be released and freshly pressed again after reconnect,
		# matching the `_prev_held.clear()` an attack/block/roll RELEASE-before-press gets, just approached
		# from the opposite prime. A disconnect also drops the arm (7-11 AC 4).
		_armed_slot = -1
		_prev_l2 = 1.0
		_prev_r2 = 1.0
		_prev_held[_PLAY_BASIC_KEY] = true
		_prev_held[_CAST_PITCH_KEY] = true
		for key: StringName in _DPAD_KEYS:
			_prev_held[key] = true
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

	# Story 5-0b / 7-11: sample() reads raw device state ONLY -- every card decision (arming, the four
	# plays, the Y rule) is made by the pure resolve_card_tick() below, on the resolve_move_dir /
	# resolve_flick precedent. Joypad reads are not headless-samplable, so keeping the DECISION pure is
	# what makes the scheme's coverage reachable at all. No modifier is read (7-11 R2).
	var attack_raw := Input.is_joy_button_pressed(_device, _profile.attack_button)
	var block_raw := Input.is_joy_button_pressed(_device, _profile.block_button)
	var roll_raw := Input.is_joy_button_pressed(_device, _profile.roll_button)
	var run_raw := Input.is_joy_button_pressed(_device, _profile.run_button)
	var l2_value := Input.get_joy_axis(_device, _profile.trigger_axis_left)
	var r2_value := Input.get_joy_axis(_device, _profile.trigger_axis_right)
	var basic_raw := Input.is_joy_button_pressed(_device, _profile.play_basic_button)
	# Story 6-3a (AC 2): Y, through its own authored field the same way.
	var pitch_raw := Input.is_joy_button_pressed(_device, _profile.cast_pitch_button)
	for i in _DPAD_KEYS.size():
		_dpad_raw[i] = Input.is_joy_button_pressed(_device, _dpad_buttons[i])
		_dpad_prev[i] = _prev_held.get(_DPAD_KEYS[i], false)

	var result := resolve_card_tick(
		attack_raw, _prev_held.get(&"attack", false),
		block_raw, _prev_held.get(&"block", false),
		roll_raw, _prev_held.get(&"roll", false),
		run_raw,
		_dpad_raw, _dpad_prev, _dpad_slots,
		l2_value, _prev_l2,
		r2_value, _prev_r2,
		basic_raw, _prev_held.get(_PLAY_BASIC_KEY, false),
		pitch_raw, _prev_held.get(_CAST_PITCH_KEY, false),
		_pitch_ready,
		_profile.trigger_threshold,
		_armed_slot)

	intent.held[&"attack"] = result["attack_held"]
	intent.pressed[&"attack"] = result["attack_pressed"]
	intent.held[&"block"] = result["block_held"]
	intent.pressed[&"block"] = result["block_pressed"]
	intent.held[&"roll"] = result["roll_held"]
	intent.pressed[&"roll"] = result["roll_pressed"]
	# Story 6-7 (AC 4): the impure write, mirroring attack/block/roll directly above -- the VALUE
	# is computed in the pure resolve_card_tick() above; this write is the only impure step.
	intent.held[&"run"] = result["run_held"]
	# Story 7-11 (M6 dev call): the card fields are written on COMMIT samples only -- the armed slot
	# stays controller-local (secret; forward-compatible with lockstep), and state reads `card_slot`
	# only under the commit guard anyway.
	if result["card_commit"]:
		intent.card_slot = result["card_slot"]
		# Story 5-7 (AC 15): the mode the fired play button selected -- no new InputIntent field.
		intent.card_mode = result["card_mode"]
		intent.card_commit = true
		# Story 6-3a (AC 2/AC 4): the tenth InputIntent field. Without this line the resolver computes
		# an activation and it never reaches state -- every READY-zone Y would stage instead.
		intent.card_activate = result["card_activate"]

	_prev_held[&"attack"] = attack_raw
	_prev_held[&"block"] = block_raw
	_prev_held[&"roll"] = roll_raw
	_prev_held[_PLAY_BASIC_KEY] = basic_raw
	_prev_held[_CAST_PITCH_KEY] = pitch_raw
	for i in _DPAD_KEYS.size():
		_prev_held[_DPAD_KEYS[i]] = _dpad_raw[i]
	_prev_l2 = l2_value
	_prev_r2 = r2_value
	# Story 7-11 (G1): a play press never clears the arm -- only the armed card leaving its slot does
	# (`observe_hand_ids`), so a REFUSED play keeps it armed.
	_armed_slot = result["armed_slot"]

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
	# Story 6-8 (AC 7, Open Question 2): the SAME right-stick X read, resolved a second way. Both
	# readings are always produced; the runner applies the flick only while locked (AC 11) and the
	# rotation only while unlocked, so the one stick never does both in a tick.
	_camera_rotate = resolve_camera_rotate(raw.x, _profile.deadzone)


## Story 6-8 (AC 7, Open Questions 2 and 6): the unlocked camera's rotation axis from the right
## stick's raw X, PURE for the `resolve_flick` reason (joypad axes are not headless-samplable).
##
## OPEN QUESTION 6'S ANSWER: an AXIAL dead zone on X alone, reusing the profile's authored `deadzone`
## (the stick-at-rest threshold every other stick read here already uses -- no new profile field),
## then a LINEAR response rescaled so the output starts at 0 just past the dead zone and reaches
## +/-1 at full deflection. Axial rather than radial so a thumb resting slightly up or down does not
## eat horizontal travel; linear because the feel knob is the RATE (`CameraConfig
## .free_yaw_degrees_per_tick`, AC 8), tuned at smoke, and a curve would be a second knob on the
## same feel. Independent of `flick_threshold` (AC 19), which gates only the locked flick edge.
##
## THE SIGN IS THE STICK'S: +X (pushed right) returns positive, which `CameraRig.rotate_free_yaw`
## turns into a view that turns right (AC 7). Y is ignored -- no vertical camera (Non-Goals).
static func resolve_camera_rotate(raw_x: float, deadzone: float) -> float:
	var magnitude := absf(raw_x)
	if magnitude <= deadzone or deadzone >= 1.0:
		return 0.0
	return signf(raw_x) * clampf((magnitude - deadzone) / (1.0 - deadzone), 0.0, 1.0)


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


## Story 5-0b (AC 2): the TRIGGER-CROSSING edge policy for L2/R2, factored out as a PURE function
## on the `resolve_flick` precedent directly above -- joypad axes are not headless-samplable, so a
## policy left inline is a policy no test can reach. Same "must be CROSSED this tick, having been
## below it last tick" discipline: a trigger held past the threshold arms its slot ONCE, not once
## per tick it stays pulled.
static func resolve_trigger_edge(value: float, prev_value: float, threshold: float) -> bool:
	return value >= threshold and prev_value < threshold


## Story 7-11 (R1, AC 1/AC 2): the ARMING decision, PURE. `dpad_raw` / `prev_dpad_raw` are this and the
## last sample's reads of the four direction buttons and `dpad_slots` the profile's direction -> slot map,
## all in direction order (left, up, down, right). A press EDGE arms the mapped slot; a held direction
## arms once; re-tapping the armed direction leaves it armed; with no fresh press the previous arm is
## returned unchanged (arming is STICKY, R1).
##
## THE TIE-BREAK (AC 2, the 5-0b "last write wins" precedent): slots are evaluated in ascending index
## order and the last write wins, so two directions pressed on one sample arm the HIGHER slot index --
## whatever the direction map says.
static func resolve_arm(dpad_raw: Array[bool], prev_dpad_raw: Array[bool], dpad_slots: Array[int],
		prev_armed_slot: int) -> int:
	var armed := prev_armed_slot
	for slot in HAND_SLOTS:
		for i in dpad_raw.size():
			if dpad_slots[i] == slot and dpad_raw[i] and not prev_dpad_raw[i]:
				armed = slot
	return armed


## Story 5-0b, RE-SIGNATURED by story 7-11 (R1-R4, G3, AC 1-8): the ENTIRE card-scheme decision for one
## sample, PURE and headless-testable -- the `resolve_move_dir`/`resolve_flick` extraction precedent.
## sample() is the only Input.* reader here (D3(a)); this function is the DECISION, built from raw device
## reads it never reaches for itself. Args are this sample's raw reads paired with last sample's
## (`_prev_held`), plus the pushed READY bool and the current arm.
##
## ARMING FIRST (`resolve_arm` above), so a direction and a play pressed on the same sample play the newly
## armed slot.
##
## THE FOUR PLAYS, NO MODIFIER (R2): X -> mode ① BASIC, Y -> mode ④ PITCH, L2 -> mode ③ DEFENSE, R2 -> mode
## ② UNBLOCKABLE. X and Y are button press edges; L2/R2 are the trigger-crossing edge
## (`resolve_trigger_edge`). Each commits `card_slot` = the armed slot.
##
## THE Y RULE (R3): with the own Pitch Zone READY (`pitch_ready`, pushed by the runner) Y ACTIVATES it --
## `card_activate` true and `card_slot` -1, whatever is armed. Otherwise Y STAGES the armed card.
##
## NOTHING ARMED (G3, `5-0b/R1` kept): every play still commits, carrying `card_slot` -1 -- the controller
## never swallows a commit; state's empty-slot refusal answers it, as it does an armed-but-EMPTY slot.
##
## THE CHORD (AC 5): play presses on one sample resolve to AT MOST ONE commit, in the fixed order X, Y,
## L2, R2 with the last write winning -- so R2 (UNBLOCKABLE) wins any chord it is in, the answer B gave
## every chord under 5-7. `card_commit` is one bool and `card_mode` one value: one commit by construction.
##
## NO SUPPRESSION (AC 8): attack/block/roll/run are this sample's raw reads and press edges, always. And a
## play never clears the arm (G1): the returned `armed_slot` is the arming result alone.
static func resolve_card_tick(
		attack_raw: bool, prev_attack_raw: bool,
		block_raw: bool, prev_block_raw: bool,
		roll_raw: bool, prev_roll_raw: bool,
		run_raw: bool,
		dpad_raw: Array[bool], prev_dpad_raw: Array[bool], dpad_slots: Array[int],
		l2_value: float, prev_l2_value: float,
		r2_value: float, prev_r2_value: float,
		basic_raw: bool, prev_basic_raw: bool,
		pitch_raw: bool, prev_pitch_raw: bool,
		pitch_ready: bool,
		trigger_threshold: float,
		prev_armed_slot: int) -> Dictionary:
	var armed_slot := resolve_arm(dpad_raw, prev_dpad_raw, dpad_slots, prev_armed_slot)
	var basic_pressed := basic_raw and not prev_basic_raw
	var pitch_pressed := pitch_raw and not prev_pitch_raw
	var defense_pressed := resolve_trigger_edge(l2_value, prev_l2_value, trigger_threshold)
	var unblockable_pressed := resolve_trigger_edge(r2_value, prev_r2_value, trigger_threshold)

	var card_slot := -1
	var card_commit := false
	var card_mode := Enums.ModeKind.BASIC
	var card_activate := false
	# The four plays, in the chord order X, Y, L2, R2 -- last write wins.
	if basic_pressed:
		card_slot = armed_slot
		card_mode = Enums.ModeKind.BASIC
		card_commit = true
	if pitch_pressed:
		card_mode = Enums.ModeKind.PITCH
		card_commit = true
		card_activate = pitch_ready
		card_slot = -1 if pitch_ready else armed_slot
	if defense_pressed:
		card_slot = armed_slot
		card_mode = Enums.ModeKind.DEFENSE
		card_commit = true
		card_activate = false
	if unblockable_pressed:
		card_slot = armed_slot
		card_mode = Enums.ModeKind.UNBLOCKABLE
		card_commit = true
		card_activate = false

	return {
		"armed_slot": armed_slot,
		"card_slot": card_slot,
		"card_commit": card_commit,
		"card_mode": card_mode,
		"card_activate": card_activate,
		"attack_held": attack_raw,
		"attack_pressed": attack_raw and not prev_attack_raw,
		"block_held": block_raw,
		"block_pressed": block_raw and not prev_block_raw,
		"roll_held": roll_raw,
		"roll_pressed": roll_raw and not prev_roll_raw,
		# Story 6-7 (AC 4) / 7-11 (AC 8): A held is RUN, always -- a HOLD fact like the three above.
		"run_held": run_raw,
	}


## Story 5-0b (AC 2): the armed slot, for the existing 3-5a HUD selection indicator -- the
## `KeyboardController.armed_slot()` precedent exactly, overriding `Controller`'s base -1.
func armed_slot() -> int:
	return _armed_slot


## Story 7-11 (AC 4): round end / debug reset. See Controller's base declaration.
func clear_armed_slot() -> void:
	_armed_slot = -1


## Story 7-11 (G1, AC 3): the armed card leaving its slot clears the arm. See Controller's base declaration.
func observe_hand_ids(ids: Array) -> void:
	_armed_slot = armed_after_hand_change(_armed_slot, _hand_ids, ids)
	_hand_ids = ids.duplicate()


## Story 7-11 (R3): the own Pitch Zone's READY, for the Y rule. See Controller's base declaration.
func observe_pitch_ready(is_ready: bool) -> void:
	_pitch_ready = is_ready


## Story 4-6 (AC 9): the click edge sampled by `_sample_lock_controls`. See Controller's base
## declaration for why this is polled rather than carried on the intent.
func relock_pressed() -> bool:
	return _lock_pressed


## Story 4-6 (AC 10): the flick edge sampled by `_sample_lock_controls`, as a unit SCREEN-SPACE
## direction, or ZERO for no flick this tick.
func retarget_flick() -> Vector2:
	return _flick


## Story 6-8 (AC 7): the rotation axis sampled by `_sample_lock_controls`.
func camera_rotate() -> float:
	return _camera_rotate


## Deadzone policy (2-2/R5), factored out as a PURE function so the contract is
## headless-testable without a physical pad (joypad axes are not headless-samplable). Below the
## deadzone -> ZERO. Above it, ALWAYS normalized to unit length (2-2/R5 binary speed, keyboard
## parity) -- story 6-7 (AC 12) retires the variable-magnitude toggle open decision (c) opened
## (`2-6/R8`); gait (walk/run) is now the discrete, authored answer to that question, never a
## function of stick deflection.
static func resolve_move_dir(raw: Vector2, deadzone: float) -> Vector2:
	if raw.length() < deadzone:
		return Vector2.ZERO
	return raw.normalized()
