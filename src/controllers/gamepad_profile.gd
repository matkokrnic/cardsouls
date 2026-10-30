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
## fraction of full deflection. AUTHORED here rather than hardcoded for the reason `deadzone` is
## (`normalize_move_magnitude`, its former live sibling, was retired by story 6-7 AC 12 -- see
## below): it is input FEEL, it belongs to the load-once controller-owned profile, and it is
## deliberately OUTSIDE BalanceConfig and the X3 hot-reload path (2-2/R2).
##
## DELIBERATELY WELL ABOVE `deadzone`. The deadzone answers "is the stick being touched"; this
## answers "did the player mean to switch targets", and a retarget triggered by a resting thumb is
## worse than one that needs a deliberate shove. The flick is an EDGE (see GamepadController), so
## this is the threshold the stick must CROSS, not one it must be held past.
@export var flick_threshold: float = 0.7

## RETIRED by story 6-7 (AC 12): open decision (c), variable analog magnitude, is CLOSED --
## `6-7/R8`'s ruling is "two gaits are the answer to the question (c) was asking," gait is now a
## discrete authored run-key choice (walk/run), never a function of stick deflection.
## `normalize_move_magnitude` (2-6 AC 4, 2-6/R8) is gone; `resolve_move_dir` always normalizes
## above the deadzone again (the pre-2-6 behaviour, keyboard parity).

## Story 7-11 (R2, AC 9): CONTROL SCHEME v2 -- no held modifier and no card mode. The 5-0b/6-10 fields
## `cast_button` (L3), `card_mode_alt_button` (D-pad Down, 7-7), `card_mode_toggle` (HOLD/TOGGLE) and the
## in-mode confirms `cast_basic_button` (A), `cast_unblockable_button` (B), `cast_defense_button` (X) are
## DELETED, not dormant: v2 is one scheme. Every role below is a binding on the same mechanism, so a
## per-slot override (7-11 R5, `load_for_slot` below) is a remap and never a second input path.

## Story 7-11 (R1, AC 1): the four ARMING buttons, one per D-pad direction, in the fixed direction order
## left / up / down / right (`DIRECTION_COUNT`). A press EDGE arms the hand slot that direction maps to
## (the `dpad_*_slot` map directly below). Authored the 2-2 way -- JoyButton-typed, NAMED defaults -- so the
## raw index of each direction lives exactly once, as data.
@export var dpad_left_button: JoyButton = JOY_BUTTON_DPAD_LEFT
@export var dpad_up_button: JoyButton = JOY_BUTTON_DPAD_UP
@export var dpad_down_button: JoyButton = JOY_BUTTON_DPAD_DOWN
@export var dpad_right_button: JoyButton = JOY_BUTTON_DPAD_RIGHT

## Story 7-11 (R1, AC 1/AC 10): the DIRECTION -> HAND SLOT map, as code indexes 0..3 (`Hand`, `card_slot`;
## the player's slots 1..4). Default left 0, up 1, down 2, right 3. Remappable data: swapping two values
## swaps which direction arms which card. A valid map is a permutation of 0..3 (`binding_refusal`).
@export_range(0, 3) var dpad_left_slot: int = 0
@export_range(0, 3) var dpad_up_slot: int = 1
@export_range(0, 3) var dpad_down_slot: int = 2
@export_range(0, 3) var dpad_right_slot: int = 3

## Story 7-11 (R2, AC 8): A held is RUN, always -- 6-7's bare-A gait without the "outside cast mode" clause
## (there is no cast mode). Its own field: before v2 the run read rode `cast_basic_button`.
@export var run_button: JoyButton = JOY_BUTTON_A

## Story 7-11 (R2, AC 5): X plays the armed card as mode ① BASIC, one press, no modifier.
@export var play_basic_button: JoyButton = JOY_BUTTON_X

## Story 6-3a (AC 1): the FOURTH face button, Y, and the mode it carries -- mode ④ PITCH. Story 7-11 (R3):
## with the own Pitch Zone READY, Y ACTIVATES it; otherwise Y STAGES the armed card. The rule lives in
## `GamepadController.resolve_card_tick`, not here.
##
## Authoring this field is what retires `5-7`'s "no button maps to Y" guard (`6-3-split/R-Y`): that
## guard existed for exactly one fact, and this line makes it false by construction.
@export var cast_pitch_button: JoyButton = JOY_BUTTON_Y

## Story 7-11 (R6): the HUD hand layout for this slot. DATA ONLY in the input layer -- no input code path
## reads it (G5); the HUD branches on it by design. ROW is the pre-7-11 row, ROW_GLYPH adds a D-pad
## direction badge per card, DIAMOND places the four cards at the D-pad positions.
enum HandLayout { ROW, ROW_GLYPH, DIAMOND }
@export var hand_layout: HandLayout = HandLayout.ROW_GLYPH

## Story 5-0b (AC 2): how far L2/R2 must be pushed before a trigger counts as PRESSED, as a
## fraction of full pull. Godot's `JoyButton` enum has no dedicated trigger entries — L2/R2 report
## as axes, the same family `flick_threshold` already reads for the right stick — so this is the
## threshold that axis value must CROSS this tick (having been below it last tick). Story 7-11 (R2):
## the crossing is now a PLAY -- L2 = mode ③ DEFENSE, R2 = mode ② UNBLOCKABLE -- once per pull.
@export var trigger_threshold: float = 0.5

## Story 5-0b (AC 2): the axis indices L2/R2 report on, authored for the same reason
## `move_axis_x`/`look_axis_x` are — the raw joypad index lives EXACTLY ONCE, as authored data,
## per this resource's own header discipline (2-2/R2). Not named in the story's field list
## because trigger reads are new to this resource; kept authored rather than an inline
## `JOY_AXIS_TRIGGER_LEFT`/`_RIGHT` literal in `GamepadController` for the same reason every other
## raw index on this file already is.
@export var trigger_axis_left: JoyAxis = JOY_AXIS_TRIGGER_LEFT
@export var trigger_axis_right: JoyAxis = JOY_AXIS_TRIGGER_RIGHT


## Story 7-11 (R1): the D-pad directions, in the order every per-direction array below is indexed by.
const DIRECTION_COUNT := 4

## Story 7-11 (R5, AC 10/AC 11): THE PER-SLOT PROFILE. The shipped default, and the directory a player's
## override file lives in (`slot_<N>.cfg`, N = the PLAYER slot 1 or 2, never the pad ordinal).
const DEFAULT_PATH := "res://data/gamepad_profile.tres"
const OVERRIDE_ROOT := "user://controls"

## Story 7-11 (AC 11): the fields an override file may set, grouped by how a value is range-checked. All
## are integers; the floats (deadzone, thresholds) are not overridable in 7-11.
const OVERRIDE_BUTTON_KEYS: Array[String] = [
	"attack_button", "block_button", "roll_button", "lock_button", "run_button", "play_basic_button",
	"cast_pitch_button", "dpad_left_button", "dpad_up_button", "dpad_down_button", "dpad_right_button",
]
const OVERRIDE_AXIS_KEYS: Array[String] = [
	"move_axis_x", "move_axis_y", "look_axis_x", "look_axis_y", "trigger_axis_left", "trigger_axis_right",
]
const OVERRIDE_SLOT_KEYS: Array[String] = ["dpad_left_slot", "dpad_up_slot", "dpad_down_slot", "dpad_right_slot"]
const OVERRIDE_LAYOUT_KEY := "hand_layout"
## Review fix L1: the longest integer literal an override value may be (the largest valid value is two digits).
const MAX_OVERRIDE_LITERAL := 6
const _SYSTEM_BUTTONS: Array[int] = [JOY_BUTTON_BACK, JOY_BUTTON_GUIDE, JOY_BUTTON_START]


## Story 7-11 (R1): the arming buttons, in direction order (left, up, down, right).
func dpad_buttons() -> Array[JoyButton]:
	return [dpad_left_button, dpad_up_button, dpad_down_button, dpad_right_button]


## Story 7-11 (R1): the hand slot each direction arms, in the same direction order.
func dpad_slots() -> Array[int]:
	return [dpad_left_slot, dpad_up_slot, dpad_down_slot, dpad_right_slot]


## Story 7-11 (R5, AC 10/AC 11): this player slot's profile -- its OWN instance (a duplicate of the
## shipped default, so editing one slot can never move the other), overlaid with the slot's override
## file when one is present and valid. Read once, at controller construction.
##
## `override_root` is injectable so no test touches the real `user://`. The override path is contained
## under the RESOLVED root by `RecordFile.is_inside_root` (`3-0d/R22`), never by a prefix test.
##
## FALLBACK (the AC 11 dev call): keys ABSENT from the file keep the default, field by field; ANY defect --
## a malformed line, an unknown key, a non-integer or out-of-range value, a repeated key, or a result whose
## bindings collide -- refuses the WHOLE file and the slot gets the shipped default, with the reason printed.
## Never a crash, and never a half-applied file. The file is data only: never a `.tres` through
## `ResourceLoader` from a user-writable path (a resource can embed script).
static func load_for_slot(player_slot: int, override_root: String = OVERRIDE_ROOT,
		default_path: String = DEFAULT_PATH) -> GamepadProfile:
	var profile := (load(default_path) as GamepadProfile).duplicate() as GamepadProfile
	var path := override_path(override_root, player_slot)
	if not RecordFile.is_inside_root(path, override_root):
		print("[gamepad] slot %d: override path %s is not inside %s -- shipped default"
			% [player_slot, path, override_root])
		return profile
	if not FileAccess.file_exists(path):
		print("[gamepad] slot %d: no override at %s -- shipped default" % [player_slot, path])
		return profile
	var candidate := profile.duplicate() as GamepadProfile
	var reason := candidate.apply_override_text(FileAccess.get_file_as_string(path))
	if reason != "":
		print("[gamepad] slot %d: override %s refused (%s) -- shipped default" % [player_slot, path, reason])
		return profile
	print("[gamepad] slot %d: override %s applied" % [player_slot, path])
	return candidate


## Story 7-11 (R5): `<root>/slot_<N>.cfg`.
static func override_path(override_root: String, player_slot: int) -> String:
	return "%s/slot_%d.cfg" % [override_root.trim_suffix("/"), player_slot]


## Story 7-11 (AC 11): overlay an override file's text onto THIS profile. Returns "" when applied, else the
## reason it was refused -- and a refusal leaves this profile EXACTLY as it was (review fix L2).
##
## FORMAT: one `key = integer` per line; blank lines and lines starting with `#` are ignored. Keys are the
## field names in the OVERRIDE_* lists above. Parsed by hand rather than through ConfigFile, whose
## Variant parser can construct objects.
func apply_override_text(text: String) -> String:
	var seen: Dictionary = {}
	var parsed: Dictionary = {}
	var line_number := 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var eq := line.find("=")
		if eq <= 0:
			return "line %d is not `key = value`" % line_number
		var key := line.substr(0, eq).strip_edges()
		var value := line.substr(eq + 1).strip_edges()
		if seen.has(key):
			return "line %d repeats `%s`" % [line_number, key]
		seen[key] = true
		if not value.is_valid_int():
			return "line %d: `%s` is not an integer" % [line_number, value]
		# Review fix L1: no valid value is longer than a few digits, and `to_int()` of an overflowing literal
		# prints an engine ERROR -- refuse it before the conversion.
		if value.length() > MAX_OVERRIDE_LITERAL:
			return "line %d: `%s` is not a plausible value (longer than %d characters)" \
					% [line_number, key, MAX_OVERRIDE_LITERAL]
		var v := value.to_int()
		var limit := _override_limit(key)
		if limit == 0:
			return "line %d: unknown key `%s`" % [line_number, key]
		if v < 0 or v >= limit:
			return "line %d: `%s` = %d is out of range [0, %d)" % [line_number, key, v, limit]
		parsed[key] = v
	# Review fix L2: the values land on a duplicate first and reach `self` only when the whole text is coherent,
	# so a refused text leaves this profile exactly as it was.
	var work := duplicate() as GamepadProfile
	for key: String in parsed:
		work.set(key, parsed[key])
	var reason := work.binding_refusal()
	if reason == "":
		for key: String in parsed:
			set(key, parsed[key])
	return reason


## Story 7-11 (AC 11): "" if this profile's bindings are coherent, else why not. Every button role is
## pairwise distinct and none is a system button (the 2-2 review-D1 rule, widened from three roles to all);
## the six axes are pairwise distinct; the direction map is a permutation of the four hand slots.
func binding_refusal() -> String:
	var buttons: Dictionary = {}
	for key: String in OVERRIDE_BUTTON_KEYS:
		var b: int = get(key)
		if b in _SYSTEM_BUTTONS:
			return "`%s` is a system button (%d)" % [key, b]
		if buttons.has(b):
			return "`%s` and `%s` share button %d" % [buttons[b], key, b]
		buttons[b] = key
	var axes: Dictionary = {}
	for key: String in OVERRIDE_AXIS_KEYS:
		var a: int = get(key)
		if axes.has(a):
			return "`%s` and `%s` share axis %d" % [axes[a], key, a]
		axes[a] = key
	var slots: Dictionary = {}
	for key: String in OVERRIDE_SLOT_KEYS:
		var s: int = get(key)
		if slots.has(s):
			return "`%s` and `%s` both arm slot %d" % [slots[s], key, s]
		slots[s] = key
	return ""


## The exclusive upper bound for an override key's value, or 0 for a key that is not overridable.
static func _override_limit(key: String) -> int:
	if key in OVERRIDE_BUTTON_KEYS:
		return JOY_BUTTON_SDL_MAX
	if key in OVERRIDE_AXIS_KEYS:
		return JOY_AXIS_SDL_MAX
	if key in OVERRIDE_SLOT_KEYS:
		return DIRECTION_COUNT
	if key == OVERRIDE_LAYOUT_KEY:
		return HandLayout.size()
	return 0
