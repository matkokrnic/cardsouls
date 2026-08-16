extends SceneTree

## Defect B1 guard (4-3c fix pass): a CHAINED attacker's second swing must RE-TRIGGER the attack
## clip, not ride the first swing's playback.
##
## WHY test_unit_clip_selection.gd CANNOT CATCH THIS, which is the whole point of a second file.
## That test asserts a single selection's clip NAME. The clip name is `attack` for swing #1 and
## `attack` for swing #7 -- it never changes, so a name assertion is GREEN for the entire defect.
## A test that only ever drives ONE swing passes while seven swings play one animation.
##
## THE MEASURED DEFECT. Live, the phase cycle is WINDUP 54 ticks (0.9s) -> ACTIVE 12 (0.2s) ->
## RECOVERY 48 (0.8s) -> WINDUP, with ZERO IDLE ticks between chained swings; seven swings ran as
## one continuous 743-tick non-IDLE stretch. The controller selected on the LEVEL `phase != IDLE`,
## so selection fired once for all seven and the dedup in `_select` swallowed every re-trigger.
## The clip played to completion (~2.654s of 2.6667s) and then HELD its final, near-neutral pose
## for ~9.7s while real swings and real damage continued underneath.
##
## NAMED MUTATION: revert the controller's re-trigger condition to a plain `phase != IDLE` (drop
## the `_prev_phase` WINDUP edge / the `force` argument) -- the "swing #2 did not re-trigger"
## assertion below must go RED.
##
## The assertion is on PLAYBACK RESTARTING (`current_animation_position` dropping back toward 0),
## never on the clip name, for the reason in the second paragraph.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_attack_retrigger.gd

## Mid-clip point to advance to during swing #1, well inside the 2.6667s attack clip.
const MID_CLIP := 1.0

var _failures: Array[String] = []
var _unit: Node
var _controller: UnitAnimationController
var _player: AnimationPlayer


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _run() -> void:
	_controller = _unit.get_node(^"AnimationController") as UnitAnimationController
	if _controller == null or _controller.animation_player == null:
		_failures.append("unit_actor.tscn did not yield a wired AnimationController")
		return
	_player = _controller.animation_player

	# --- SWING #1: IDLE -> WINDUP. This edge already worked before the fix (the selection
	# genuinely changed from `idle` to `attack`), so it is the control, not the target.
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.IDLE, 0.0)
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.WINDUP, 0.0)
	_check(_player.current_animation == &"attack",
		"swing #1 WINDUP: expected clip 'attack', got '%s'" % _player.current_animation)
	_check(_player.current_animation_position < 0.001,
		"swing #1 WINDUP: expected playback at frame 0, got %.4f" % _player.current_animation_position)

	# Let swing #1 play into the middle of the clip, then walk the REST of the live cycle:
	# ACTIVE, then RECOVERY, with NO IDLE tick anywhere -- exactly the measured shape.
	_player.advance(MID_CLIP)
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.ACTIVE, 0.0)
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.RECOVERY, 0.0)
	var before: float = _player.current_animation_position
	_check(before > MID_CLIP * 0.5,
		("swing #1 did not accumulate playback: position %.4f after advancing %.2fs "
		+ "- the test cannot prove a restart if nothing ever ran") % [before, MID_CLIP])

	# --- SWING #2: RECOVERY -> WINDUP with NO IDLE between. THE TARGET. The selection does not
	# change here (it is `attack` on both sides), so only an EDGE-driven re-trigger can restart it.
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.WINDUP, 0.0)
	var after: float = _player.current_animation_position
	_check(after < before,
		("DEFECT B1: swing #2 did not re-trigger the attack clip. Playback ran on from %.4f to "
		+ "%.4f across a RECOVERY->WINDUP transition with no IDLE between; a chained attacker "
		+ "plays ONE animation for all its swings and then holds its final pose.") % [before, after])
	_check(after < 0.001,
		"DEFECT B1: swing #2 restarted but not from frame 0 - playback position %.4f" % after)

	# The clip NAME is identical on both sides of that transition. Asserted explicitly so the
	# reason this file exists beside test_unit_clip_selection.gd cannot be lost.
	_check(_player.current_animation == &"attack",
		"swing #2 WINDUP: expected clip 'attack', got '%s'" % _player.current_animation)

	# --- The re-trigger is EDGE-driven, not per-tick. Holding WINDUP must NOT rewind, or the clip
	# would sit pinned at frame 0 for all 54 windup ticks and nothing would visibly animate.
	_player.advance(0.25)
	var held_before: float = _player.current_animation_position
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.WINDUP, 0.0)
	_check(_player.current_animation_position >= held_before,
		("a HELD WINDUP rewound the clip (%.4f -> %.4f) - the re-trigger is level-driven, not "
		+ "edge-driven, and the attack would never advance past frame 0")
		% [held_before, _player.current_animation_position])


## One frame, for the same measured reason test_unit_clip_selection.gd records: a node added to
## the tree from inside `_initialize()` does NOT get `_ready()` called there, so the controller's
## exported AnimationPlayer path would still be unresolved.
func _initialize() -> void:
	_unit = load("res://src/actors/minions/unit_actor.tscn").instantiate()
	root.add_child(_unit)


func _process(_delta: float) -> bool:
	_run()
	if is_instance_valid(_unit):
		_unit.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
