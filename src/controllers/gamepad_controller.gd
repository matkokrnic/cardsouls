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
## `_prev_held`'s public keys (referenced by `_LOCK_KEY`/`_CAST_BASIC_KEY` below) even though
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

## Story 5-0b (AC 3): the `_prev_held` key the cast-commit face button's edge is remembered
## under. Same reasoning as `_LOCK_KEY` directly above -- the commit press is resolved into
## `InputIntent.card_commit` here, never carried as its own intent action, so it is deliberately
## NOT a member of INTENT_ACTIONS.
const _CAST_BASIC_KEY := &"__cast_basic"

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

## Story 5-0b (AC 2/AC 9): the hand slot currently ARMED by cast mode, or -1 for none -- the
## `KeyboardController._armed_slot` precedent exactly, exposed the same way through
## `armed_slot()` below (base `Controller` returns -1). Cleared the SAME tick `cast_button` is
## released (AC 1), never carried past the tick cast mode exits.
var _armed_slot: int = -1
## Story 5-0b (AC 2): previous-tick L2/R2 axis values. Read and updated EVERY tick regardless of
## cast mode, the same reason `_prev_flick_magnitude` is unconditional -- a trigger already
## pulled past the threshold before cast mode is entered must not fire a spurious arm the instant
## cast mode begins; only a fresh CROSSING arms a slot.
var _prev_l2 := 0.0
var _prev_r2 := 0.0


## slot_gamepad_ordinal: WHICH gamepad this is among the configured GAMEPAD slots (the i-th
## GAMEPAD in slot_controller_kinds), NOT the player slot. The i-th GAMEPAD takes the i-th entry
## of Input.get_connected_joypads() — the device index comes from the connected-joypads list,
## never from the player slot (AC3; the Flip-2 live proof that slot 1 still binds the one pad).
func _init(slot_gamepad_ordinal: int, profile: GamepadProfile) -> void:
	_profile = profile
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
		# Story 5-0b: same neutral path, opposite reasoning -- these three prevs are primed HELD,
		# not cleared, because clearing them would PRIME the trigger/Basic edges: a replug with
		# L3+trigger+A already held would then read as a fresh crossing and arm-and-commit with no
		# new press. Priming HELD forces every card input to be released and freshly pressed again
		# after reconnect before it can arm or commit, matching the `_prev_held.clear()` an
		# attack/block/roll RELEASE-before-press gets, just approached from the opposite prime.
		_armed_slot = -1
		_prev_l2 = 1.0
		_prev_r2 = 1.0
		_prev_held[_CAST_BASIC_KEY] = true
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

	# Story 5-0b: sample() reads raw device state ONLY -- every decision (suppression, slot
	# arming, commit) is made by the pure resolve_card_tick() below, on the resolve_move_dir /
	# resolve_flick precedent directly below. Joypad reads are not headless-samplable (see file
	# header), so keeping the DECISION pure is what makes AC 9's coverage list reachable at all.
	var cast_held := Input.is_joy_button_pressed(_device, _profile.cast_button)
	var attack_raw := Input.is_joy_button_pressed(_device, _profile.attack_button)
	var block_raw := Input.is_joy_button_pressed(_device, _profile.block_button)
	var roll_raw := Input.is_joy_button_pressed(_device, _profile.roll_button)
	var l2_value := Input.get_joy_axis(_device, _profile.trigger_axis_left)
	var r2_value := Input.get_joy_axis(_device, _profile.trigger_axis_right)
	var basic_raw := Input.is_joy_button_pressed(_device, _profile.cast_basic_button)

	var result := resolve_card_tick(
		cast_held,
		attack_raw, _prev_held.get(&"attack", false),
		block_raw, _prev_held.get(&"block", false),
		roll_raw, _prev_held.get(&"roll", false),
		l2_value, _prev_l2,
		r2_value, _prev_r2,
		basic_raw, _prev_held.get(_CAST_BASIC_KEY, false),
		_profile.trigger_threshold,
		_armed_slot)

	intent.held[&"attack"] = result["attack_held"]
	intent.pressed[&"attack"] = result["attack_pressed"]
	intent.held[&"block"] = result["block_held"]
	intent.pressed[&"block"] = result["block_pressed"]
	intent.held[&"roll"] = result["roll_held"]
	intent.pressed[&"roll"] = result["roll_pressed"]
	if result["card_commit"]:
		intent.card_slot = result["card_slot"]
		intent.card_mode = Enums.ModeKind.BASIC
		intent.card_commit = true

	_prev_held[&"attack"] = attack_raw
	_prev_held[&"block"] = block_raw
	_prev_held[&"roll"] = roll_raw
	_prev_held[_CAST_BASIC_KEY] = basic_raw
	_prev_l2 = l2_value
	_prev_r2 = r2_value
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


## Story 5-0b (AC 1-5): the ENTIRE cast/card-scheme decision for one tick, PURE and
## headless-testable -- the `resolve_move_dir`/`resolve_flick` extraction precedent above, taken
## the rest of the way. sample() is the only Input.* reader here (D3(a)); this function is the
## DECISION, built from raw device reads it never reaches for itself, so every AC 9 case is
## reachable from a test without a real pad.
##
## Args are this tick's raw reads paired with last tick's raw reads (the `_prev_held` values, not
## the previously-emitted intent) -- exactly what sample() already tracked before this story, now
## just handed in rather than consulted inline.
##
## AC 1: cast mode is `cast_held`, a raw READ, never an edge -- releasing it exits the SAME tick
## (the caller passes this tick's read, so there is no released-edge delay to construct).
##
## AC 2: L2/L1/R1/R2 arm hand slot 0/1/2/3, the physical left-to-right order, checked in that
## order so a same-tick chord (unreachable on real hardware, reachable in a test) resolves to the
## RIGHTMOST button pressed -- the same "last write wins" resolution `KeyboardController`'s
## per-index loop already gets. `l2_pressed`/`r2_pressed` are the trigger-crossing edge
## (`resolve_trigger_edge` above); `attack`/`block` reuse the ordinary button-press edge.
##
## AC 3: the Basic face button commits the ARMED slot in one press -- no separate confirm button.
## A fresh Basic press ALWAYS raises the commit, with `card_slot = armed_slot` even when that is
## -1 (nothing armed): the state-side `empty_slot` refusal AC 3 describes is reached, not
## swallowed here -- the keyboard's parity precedent exactly (`Hand.is_slot_empty` treats a
## negative index as empty, so slot -1 lands on the same refusal a real empty slot does). B/X/Y
## are true no-ops: this function has no parameter for them at all, so they cannot arm or commit
## anything -- a no-op by omission, not a checked branch (AC 3, AC 9).
##
## AC 4/AC 5: attack/block/roll are SUPPRESSED on the returned `*_held`/`*_pressed` whenever
## `cast_held` is true this tick -- L1/R1/B are reassigned to card-slot/mode-select buttons and
## must not also throw an attack/block/roll. The `*_raw`/`prev_*_raw` pair is untouched by
## suppression, so a button already held through `cast_button`'s release produces no press edge on
## exit (the edge needs a genuine false->true transition in the RAW reads, which a still-held
## button never gives), while a fresh press the tick after release registers normally.
static func resolve_card_tick(
		cast_held: bool,
		attack_raw: bool, prev_attack_raw: bool,
		block_raw: bool, prev_block_raw: bool,
		roll_raw: bool, prev_roll_raw: bool,
		l2_value: float, prev_l2_value: float,
		r2_value: float, prev_r2_value: float,
		basic_raw: bool, prev_basic_raw: bool,
		trigger_threshold: float,
		prev_armed_slot: int) -> Dictionary:
	var attack_pressed := attack_raw and not prev_attack_raw
	var block_pressed := block_raw and not prev_block_raw
	var roll_pressed := roll_raw and not prev_roll_raw
	var l2_pressed := resolve_trigger_edge(l2_value, prev_l2_value, trigger_threshold)
	var r2_pressed := resolve_trigger_edge(r2_value, prev_r2_value, trigger_threshold)
	var basic_pressed := basic_raw and not prev_basic_raw

	var armed_slot := prev_armed_slot
	var card_slot := -1
	var card_commit := false
	if cast_held:
		if l2_pressed:
			armed_slot = 0
		if block_pressed:
			armed_slot = 1
		if attack_pressed:
			armed_slot = 2
		if r2_pressed:
			armed_slot = 3
		if basic_pressed:
			card_slot = armed_slot
			card_commit = true
	else:
		armed_slot = -1

	return {
		"armed_slot": armed_slot,
		"card_slot": card_slot,
		"card_commit": card_commit,
		"attack_held": attack_raw and not cast_held,
		"attack_pressed": attack_pressed and not cast_held,
		"block_held": block_raw and not cast_held,
		"block_pressed": block_pressed and not cast_held,
		"roll_held": roll_raw and not cast_held,
		"roll_pressed": roll_pressed and not cast_held,
	}


## Story 5-0b (AC 2): the armed slot, for the existing 3-5a HUD selection indicator -- the
## `KeyboardController.armed_slot()` precedent exactly, overriding `Controller`'s base -1.
func armed_slot() -> int:
	return _armed_slot


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
