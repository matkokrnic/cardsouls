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
const INTENT_ACTIONS: Array[StringName] = [&"attack", &"block", &"roll"]

var _up: StringName
var _down: StringName
var _left: StringName
var _right: StringName
var _action_map: Dictionary[StringName, StringName] = {}  # intent key -> Input Map action


func _init(prefix: StringName) -> void:
	_up = _action(prefix, "move_up")
	_down = _action(prefix, "move_down")
	_left = _action(prefix, "move_left")
	_right = _action(prefix, "move_right")
	for key in INTENT_ACTIONS:
		_action_map[key] = _action(prefix, key)


func sample() -> InputIntent:
	var intent := InputIntent.new()  # fresh per tick (never a reused mutable instance)
	intent.move_dir = Input.get_vector(_left, _right, _up, _down)
	for key in INTENT_ACTIONS:
		var mapped := _action_map[key]
		intent.pressed[key] = Input.is_action_just_pressed(mapped)
		intent.held[key] = Input.is_action_pressed(mapped)
	return intent


static func _action(prefix: StringName, name: String) -> StringName:
	return StringName("%s_%s" % [prefix, name])
