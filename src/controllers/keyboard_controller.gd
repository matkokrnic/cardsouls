class_name KeyboardController
extends Controller

## D3 keyboard controller. Takes a prefix ("p1" / "p2") so split-screen (E2) needs no remap
## and no second class — one class, two instances reading p1_* / p2_* Input Map actions.
##
## INVARIANT D3(a): this is one of the ONLY sites where Input.* may appear. State and actor
## code never touch the Input singleton (grep-checkable — matches only under src/controllers/).

## Intent keys are PREFIX-FREE (story 1-3): the state layer reads &"attack" / &"block" /
## &"roll" and never knows which player slot or Input Map action produced them. The
## p1_/p2_ prefix is this controller's PRIVATE mapping to the Input Map.
const INTENT_ACTIONS: Array[StringName] = [&"attack", &"block", &"roll", &"run"]

## Story 3-5a (AC 1): the hand size this scheme binds keys for. PRESENTATION-LOCAL CONSTANT, the
## HudRoot card-row precedent (2-5/R1) — the hand is four at all times per the GDD, and reading
## the authored hand_size here would make the controller depend on balance data it has no other
## reason to see. If hand size ever varies (OPEN decision (e), carried by 3-3), this constant and
## the Input Map entries move together.
const CARD_SLOTS := 4

var _up: StringName
var _down: StringName
var _left: StringName
var _right: StringName
var _debug_reset: StringName
var _action_map: Dictionary[StringName, StringName] = {}  # intent key -> Input Map action

## Story 3-5a (AC 1): THE MODE-SELECT SCHEME, and it lives entirely here. The state layer
## receives three plain values (slot, mode, commit) and knows nothing about how they were
## produced — so replacing this scheme wholesale touches no file outside src/controllers/,
## which is the property test_architecture_invariants.gd::test_card_scheme_only_in_controllers
## exists to keep true.
##
## THE SCHEME, keyboard only this story:
##   HOLD  pX_cast_mode        enter cast mode
##   PRESS pX_card_1 .. _4     arm that hand slot (the selection indicator lights)
##   PRESS pX_cast_confirm     commit the armed slot, mode BASIC
##   RELEASE pX_cast_mode      exit instantly and disarm
##
## Story 5-7 (AC 12): the two TEMPORARY confirm keys `5-3` and `5-5` added here (`pX_cast_unblockable`
## for UNBLOCKABLE, `pX_cast_defense` for DEFENSE) are GONE -- branch, field, action-string line and
## Input Map action each, exactly the four-part inventory both stories named for this one. The pad
## scheme's B and X confirm those two modes now, so the keyboard stand-ins have no job left. The
## arm-then-confirm sequence itself is untouched: only the two redundant confirm keys left.
##
## PROVISIONAL, NOT SETTLED. The card-mode-select UX is an open high-P4 question (GDD §Controls);
## this is ONE scheme implemented so the layer can be played at all, and the live smoke exists to
## judge its feel. Note what the smoke CANNOT judge: exactly one mode is reachable in E3, so
## whether MODE selection survives real-time pressure is not answered here — its forcing point
## moves to E5, when the other modes land.
##
## WHY ARM-THEN-CONFIRM rather than press-a-card-to-cast: AC 1 requires slot, mode and commit to
## reach state as three separate things, and AC 10's selection indicator has nothing to show
## unless an ARMED state exists between the two presses. The two-step is the thing being
## smoke-tested, not an accident of the binding.
##
## NO MODE KEY IS BOUND, deliberately. Only Mode ① resolves in E3; binding keys for the other
## three would author input for guarded stubs, so `card_mode` is always BASIC here and the mode
## half of the scheme arrives with the modes themselves in E5.
##
## _armed_slot is CONTROLLER-LOCAL state carried between ticks. That does not weaken the D3
## value-object contract above: sample() still returns a FRESH InputIntent every tick and never
## a reused mutable instance — what persists is this controller's private selection, not the
## intent.
var _cast_mode: StringName
var _cast_confirm: StringName
var _card_actions: Array[StringName] = []
var _armed_slot: int = -1

## Story 6-8 (AC 23/AC 24): THE LOCK CONTROLS, keyboard parity with the pad (closes deferred-work M5).
## Five Input Map actions per prefix, bound to physically unique keys (the ratified table: P1 T / F G
## / Z C, P2 Numpad 5 / Numpad 4 6 / Numpad 1 3):
##   PRESS pX_lock                         the R3 click -- three-way, resolved by the runner (AC 1)
##   HOLD  pX_camera_left / _camera_right  rotate the UNLOCKED camera (AC 7-10), a level in [-1, 1]
##   PRESS pX_cycle_left / _cycle_right    a horizontal flick (AC 13-17), an edge
## The runner applies rotation only while unlocked and cycling only while locked, exactly as for
## the pad, so a key pressed in the wrong state is a no-op without this controller knowing the state.
##
## SAMPLED IN sample(), read back through the accessors -- the GamepadController discipline, so an
## edge fires once per sample however many times the runner asks.
var _lock: StringName
var _camera_left: StringName
var _camera_right: StringName
var _cycle_left: StringName
var _cycle_right: StringName
var _lock_pressed := false
var _flick := Vector2.ZERO
var _camera_rotate := 0.0

## Story 6-D1 (DEBUG, the `p1_debug_reset` precedent): P1-only keys that cast mode 2 (UNBLOCKABLE) with
## the FIRST card of a colour in hand, so one operator can smoke colour counters alone (keyboard P1
## attacks, pad P2 counters). NOT a replacement for the ordinary cast keys 5-7 deleted.
##
## Story 6-9 (AC 10): A PRESS IS A SINGLE TAP. `6-D1`'s press-AND-HOLD -- a `DEBUG_HOLD_TICKS`
## auto-hold of the `card_cast` held key, which existed only to carry the tap past `6-1`'s release arm --
## is GONE with the arm it served. One tap commits the attack and the state layer never reads a key
## again. The intent fields are the pad path's own (slot / mode / commit).
var _debug_actions: Dictionary[int, StringName] = {}  # Enums.CardColor -> Input Map action (P1 only)
var _hand_colors: Array[int] = []
var _debug_prev: Dictionary = {}  # Enums.CardColor -> was down last sample


func _init(prefix: StringName) -> void:
	_up = _action(prefix, "move_up")
	_down = _action(prefix, "move_down")
	_left = _action(prefix, "move_left")
	_right = _action(prefix, "move_right")
	_debug_reset = _action(prefix, "debug_reset")
	for key in INTENT_ACTIONS:
		_action_map[key] = _action(prefix, key)
	_cast_mode = _action(prefix, "cast_mode")
	_cast_confirm = _action(prefix, "cast_confirm")
	for i in CARD_SLOTS:
		_card_actions.append(_action(prefix, "card_%d" % (i + 1)))
	_lock = _action(prefix, "lock")
	_camera_left = _action(prefix, "camera_left")
	_camera_right = _action(prefix, "camera_right")
	_cycle_left = _action(prefix, "cycle_left")
	_cycle_right = _action(prefix, "cycle_right")
	if prefix == &"p1":
		_debug_actions[Enums.CardColor.RED] = &"p1_debug_unblockable_red"
		_debug_actions[Enums.CardColor.BLUE] = &"p1_debug_unblockable_blue"
		_debug_actions[Enums.CardColor.GREEN] = &"p1_debug_unblockable_green"


func sample() -> InputIntent:
	var intent := InputIntent.new()  # fresh per tick (never a reused mutable instance)
	intent.move_dir = Input.get_vector(_left, _right, _up, _down)
	for key in INTENT_ACTIONS:
		var mapped := _action_map[key]
		intent.pressed[key] = Input.is_action_just_pressed(mapped)
		intent.held[key] = Input.is_action_pressed(mapped)
	# Story 1-7 (D-2): the debug reset is an edge (just-pressed), prefix-mapped like every
	# action, carried on the intent rather than any out-of-band channel.
	intent.debug_reset = Input.is_action_just_pressed(_debug_reset)
	_sample_card_scheme(intent)
	_sample_debug_unblockable(intent)
	_sample_lock_controls()
	return intent


## Story 6-D1: one commit per press. A press with no card of that colour in hand does nothing (no
## substitute slot, no refusal). Since `6-9` the commit is the whole of it: there is nothing to hold.
func _sample_debug_unblockable(intent: InputIntent) -> void:
	var fired := -1
	for color: int in _debug_actions:
		# The edge is taken here from the level (`_debug_prev`, the GamepadController shape) rather than
		# `is_action_just_pressed`, so it is a property of successive samples, not of the engine frame.
		var down := Input.is_action_pressed(_debug_actions[color])
		if down and not _debug_prev.get(color, false) and fired < 0:
			fired = color
		_debug_prev[color] = down
	if fired >= 0:
		var slot := _hand_colors.find(fired)
		if slot >= 0:
			intent.card_slot = slot
			intent.card_mode = Enums.ModeKind.UNBLOCKABLE
			intent.card_commit = true


func observe_hand_colors(colors: Array[int]) -> void:
	_hand_colors = colors


## Story 6-8 (AC 23): the three lock readings for this tick. Input.* is read here and nowhere else in
## the lock half (D3(a)); the decisions are the pure functions below.
func _sample_lock_controls() -> void:
	_lock_pressed = Input.is_action_just_pressed(_lock)
	_flick = resolve_cycle_keys(Input.is_action_just_pressed(_cycle_left),
			Input.is_action_just_pressed(_cycle_right), _lock_pressed)
	_camera_rotate = resolve_rotate_keys(Input.is_action_pressed(_camera_left),
			Input.is_action_pressed(_camera_right))


## Story 6-8 (AC 23): the cycle keys as a FLICK, PURE so the edge policy is headless-testable. A
## fresh press of one key is a unit horizontal flick in that direction -- the same `Vector2(+/-1, 0)`
## a pad flick past `flick_threshold` normalises to, so `LockOnResolver` cannot tell the two apart.
## Both pressed on the same tick name no direction and are a no-op. The lock key wins the tick, the
## pad's R3-suppresses-the-flick rule (`GamepadController.resolve_flick`) kept at parity.
static func resolve_cycle_keys(left_pressed: bool, right_pressed: bool, lock_pressed: bool) -> Vector2:
	if lock_pressed or left_pressed == right_pressed:
		return Vector2.ZERO
	return Vector2(1.0, 0.0) if right_pressed else Vector2(-1.0, 0.0)


## Story 6-8 (AC 23): the rotate keys as the unlocked camera's axis, PURE for the same reason. Held
## right is +1 (view turns right, AC 7), held left -1, both or neither 0 -- the digital case of
## `GamepadController.resolve_camera_rotate`, at full rate while held.
static func resolve_rotate_keys(left_held: bool, right_held: bool) -> float:
	return (1.0 if right_held else 0.0) - (1.0 if left_held else 0.0)


## The card half of sample(), kept in its own function so the scheme is one readable block and
## swapping it is one edit. Writes only InputIntent's three card fields.
##
## RELEASING THE MODIFIER EXITS INSTANTLY — the selection is dropped the same tick, so the escape
## out of a cast into a roll costs no extra press. That is the operator's stated intent for the
## pad layout and it is honoured here on the keyboard.
##
## NO ACTION NAME CROSSES THE BOUNDARY: the Input Map action `pX_card_2` is resolved to the plain
## index 1 inside this loop, so the per-player prefix cannot leak into the intent (AC 11) — not
## by a strip step that could rot, but because no name is carried at all.
func _sample_card_scheme(intent: InputIntent) -> void:
	if not Input.is_action_pressed(_cast_mode):
		_armed_slot = -1
		return
	for i in _card_actions.size():
		if Input.is_action_just_pressed(_card_actions[i]):
			_armed_slot = i
	intent.card_slot = _armed_slot
	# Story 5-7 (AC 12): the keyboard scheme is back to ONE confirm key and ONE mode. `5-3`'s
	# `pX_cast_unblockable` and `5-5`'s `pX_cast_defense` branches are deleted -- both were declared
	# TEMPORARY by their own stories, both existed only so a human could reach modes ② and ③ before
	# a pad button could, and the pad's B and X now do that (`5-7` AC 1). BASIC is once again the
	# only mode this controller produces.
	intent.card_mode = Enums.ModeKind.BASIC
	# A commit with nothing armed still reaches state and is REFUSED there (empty_slot),
	# rather than being swallowed here: the refusal is player-facing feedback and belongs
	# on the shipped action_rejected seam, not in the controller.
	intent.card_commit = Input.is_action_just_pressed(_cast_confirm)


## Story 3-5a (AC 10): the armed slot, for the PRESENTATION-side selection indicator — read by
## the runner after sample() and pushed into the HUD. -1 = nothing armed. This is controller
## state, not match state: it never enters InputIntent's snapshot-excluded contract differently
## from the fields above, and the HUD receives a plain int, never this object.
func armed_slot() -> int:
	return _armed_slot


## Story 6-8 (AC 23): the lock key's edge, sampled in sample(). See `Controller.relock_pressed`.
func relock_pressed() -> bool:
	return _lock_pressed


## Story 6-8 (AC 23): the cycle keys' flick, sampled in sample(). See `Controller.retarget_flick`.
func retarget_flick() -> Vector2:
	return _flick


## Story 6-8 (AC 23): the rotate keys' axis, sampled in sample(). See `Controller.camera_rotate`.
func camera_rotate() -> float:
	return _camera_rotate


static func _action(prefix: StringName, name: String) -> StringName:
	return StringName("%s_%s" % [prefix, name])
