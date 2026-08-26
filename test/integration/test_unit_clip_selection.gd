extends SceneTree

## Story 4-3c (AC 4) machine contract. It had TWO parts; story 4-3d deleted the second (below):
##
## PART A -- SELECTION, inside the controller. UnitAnimationController.on_unit_tick() picks
## the right one of the four clips, and picks it in the right ORDER: liveness is checked
## BEFORE phase.
##   NAMED MUTATION (4-3c/R6): swapping the liveness check below the phase check must turn the
##   killed-mid-swing case RED. That case exists because MatchState._advance_unit_attacks skips
##   dead units, so a unit killed mid-windup/active/recovery keeps its frozen attack_phase
##   FOREVER -- nothing ever resets it to IDLE on death. A phase-first controller would show a
##   corpse still swinging.
##
## PART B IS DELETED BY STORY 4-3d (`4-3d/R17`) AND REPLACED, NOT EXTENDED.
##
## It asserted SOURCE ORDER -- that the controller push in `MatchRunner._aim_unit_actors` sits
## above that loop's liveness gate (`4-3c/R15`), by reading line numbers and indentation out of
## the runner's own text. It said so itself, in its own header: "the ordering is pinned the only
## way it can be pinned TODAY", and "when 4-3d ships the corpse linger, a behavioural test becomes
## possible".
##
## 4-3d SHIPPED THE CORPSE LINGER. The behavioural test is now possible, and it lives in
## test/integration/test_unit_corpse_linger_live.gd (`_reference_pose`): a lingering corpse must
## HOLD THE POSE THE `death` CLIP ENDS ON, and must not hold the pose the `attack` clip ends on --
## the half-raised claw a push seated behind the liveness gate produces. That is the effect this
## file's line-order assertion was standing in for, and an effect assertion sees things the source
## read never could (a rename, a refactor into a helper, a push that runs but is handed the wrong
## liveness value). This project has now shipped three defects where a guard asserted an
## identifier -- or source order -- and could not see the effect; this is the third one being
## retired rather than kept alongside its replacement.
##
## Run: godot --headless --path . --script res://test/integration/test_unit_clip_selection.gd

var _failures: Array[String] = []
var _unit: Node
var _controller: UnitAnimationController
var _player: AnimationPlayer


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


## Push a tick and assert which clip the controller selected as a result. Advances one
## physics-tick's worth of playback (1/60s, the runner's own tick length) BEFORE reading
## `current_animation` (L6 FIX PASS) -- every prior version of this check read the player
## exactly one instruction after `play()`, which cannot distinguish a correctly SELECTED clip
## from one that was selected and then immediately stalled or reset; advancing means something
## actually has to keep playing for the check to stay true.
func _expect(alive: bool, phase: int, speed: float, want: StringName, label: String) -> void:
	_controller.on_unit_tick(alive, phase, speed)
	_player.advance(1.0 / 60.0)
	var got: StringName = _player.current_animation
	_check(got == want, "%s: expected clip '%s', got '%s'" % [label, want, got])


## M4 FIX PASS: a CONTENT assertion, the guard whose absence let defect B1 ship. Every check
## above this point pins the clip NAME the controller selects; nothing pins that the selected
## clip actually MOVES anything. A reimport yielding an empty clip, or one whose tracks got
## stripped/retargeted onto the wrong skeleton, would pass every naming/loop/ordering guard in
## this file and in test_unit_rig_clips.gd. For each of the four clips this drives the
## controller to select it, advances real playback time, and asserts the model's
## `mixamorig_Hips` bone pose actually CHANGES as a result.
func _assert_clip_content_changes() -> void:
	var skeleton: Skeleton3D = _unit.get_node_or_null(^"SkeletonZombie/Skeleton3D") as Skeleton3D
	if skeleton == null:
		_failures.append("content check: SkeletonZombie/Skeleton3D missing")
		return
	var bone := skeleton.find_bone("mixamorig_Hips")
	if bone < 0:
		_failures.append("content check: mixamorig_Hips bone missing from Skeleton3D")
		return

	# [alive, phase, speed, expected clip] -- one drive per clip, in AC 4's own selection order.
	var drives: Array = [
		[true, UnitBoard.AttackPhase.IDLE, 0.0, &"idle"],
		[true, UnitBoard.AttackPhase.IDLE, 3.0, &"walk"],
		[true, UnitBoard.AttackPhase.WINDUP, 0.0, &"attack"],
		[false, UnitBoard.AttackPhase.RECOVERY, 0.0, &"death"],
	]
	for d: Array in drives:
		# A clean edge into IDLE first, so an attack drive always sees the WINDUP re-trigger
		# edge (`_prev_phase`) fire rather than silently no-op against whatever the previous
		# drive left selected.
		_controller.on_unit_tick(true, UnitBoard.AttackPhase.IDLE, 0.0)
		_controller.on_unit_tick(d[0], d[1], d[2])
		var clip: StringName = d[3]
		if _player.current_animation != clip:
			_failures.append("content check: expected '%s' selected, got '%s'" % [clip, _player.current_animation])
			continue
		_player.seek(0.0, true)
		var before: Transform3D = skeleton.get_bone_pose(bone)
		var length: float = _player.get_animation(clip).length
		_player.advance(length * 0.5)
		var after: Transform3D = skeleton.get_bone_pose(bone)
		_check(not before.is_equal_approx(after),
			("content check: clip '%s' - mixamorig_Hips pose did not change after advancing "
			+ "%.4fs (before %s, after %s); an empty or wrong-content clip would pass every "
			+ "naming/loop guard but fail here") % [clip, length * 0.5, before, after])


func _part_a() -> void:
	_controller = _unit.get_node(^"AnimationController") as UnitAnimationController
	if _controller == null or _controller.animation_player == null:
		_failures.append("unit_actor.tscn did not yield a wired AnimationController")
		return
	_player = _controller.animation_player

	# --- Resting pose on _ready, so a unit that never moves and never swings still animates. ---
	_check(_player.current_animation == &"idle",
		"on _ready expected 'idle', got '%s'" % _player.current_animation)

	# --- The idle/walk split, off the actor's own velocity magnitude. ---
	_expect(true, UnitBoard.AttackPhase.IDLE, 0.0, &"idle", "alive, IDLE, still")
	_expect(true, UnitBoard.AttackPhase.IDLE, 3.0, &"walk", "alive, IDLE, moving at unit_move_speed")
	_expect(true, UnitBoard.AttackPhase.IDLE, 0.0, &"idle", "alive, IDLE, stopped again")

	# --- ONE attack clip across the WHOLE cycle, not three. ---
	_expect(true, UnitBoard.AttackPhase.WINDUP, 0.0, &"attack", "alive, WINDUP")
	_expect(true, UnitBoard.AttackPhase.ACTIVE, 0.0, &"attack", "alive, ACTIVE")
	_expect(true, UnitBoard.AttackPhase.RECOVERY, 0.0, &"attack", "alive, RECOVERY")
	# A swinging unit that is also moving still swings -- phase beats the locomotion split.
	_expect(true, UnitBoard.AttackPhase.ACTIVE, 3.0, &"attack", "alive, ACTIVE, moving")
	_expect(true, UnitBoard.AttackPhase.IDLE, 0.0, &"idle", "alive, back to IDLE")

	# --- THE MUTATION TARGET (4-3c/R6): killed MID-SWING plays `death`, not `attack`. ---
	# The phase is deliberately NOT idle in these three: a dead unit's phase is frozen at
	# whatever it held on the kill tick, so this is the real shape of the data, not a contrived
	# one. A controller that checked phase before liveness returns 'attack' for all three.
	_expect(false, UnitBoard.AttackPhase.WINDUP, 0.0, &"death", "killed mid-WINDUP")
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.IDLE, 0.0)
	_expect(false, UnitBoard.AttackPhase.ACTIVE, 0.0, &"death", "killed mid-ACTIVE")
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.IDLE, 0.0)
	_expect(false, UnitBoard.AttackPhase.RECOVERY, 0.0, &"death", "killed mid-RECOVERY")
	# Liveness also beats the locomotion split, for the same reason.
	_controller.on_unit_tick(true, UnitBoard.AttackPhase.IDLE, 0.0)
	_expect(false, UnitBoard.AttackPhase.IDLE, 3.0, &"death", "dead while carrying stale velocity")

	_assert_clip_content_changes()

	# --- The corpse HOLDS its final pose; the polled push must not re-trigger `death`. ---
	# 4-3d depends on this directly (its corpse lingers for ten seconds). `death` does not loop,
	# so once it ends the AnimationPlayer's current_animation goes EMPTY while the final pose
	# stays on screen. A controller comparing against current_animation (the hero's idempotent
	# _play, which is safe there because its polled path chooses only between two LOOPING clips)
	# would see "" != "death" and restart the clip on the very next tick, looping a corpse's
	# death forever. Advancing past the clip's end and pushing again is what pins that.
	_player.advance(_player.get_animation(&"death").length + 0.5)
	_controller.on_unit_tick(false, UnitBoard.AttackPhase.RECOVERY, 0.0)
	_check(_player.current_animation != &"death",
		"a finished `death` clip was RE-TRIGGERED by the polled push - a corpse would loop its death forever")


## PART A NEEDS EXACTLY ONE FRAME, and the reason is worth recording rather than rediscovering:
## a node added to the tree from inside `_initialize()` does NOT get its `_ready()` called there
## (measured: `is_node_ready()` is still false immediately after `add_child`) -- the SceneTree
## root is not itself ready yet, so readiness propagation waits for the first processed frame.
## The controller resolves its exported AnimationPlayer path in `_ready`, so every Part A
## assertion would read a null player if it ran in `_initialize`. Deferring to `_process` is the
## same shape the `*_live.gd` integration tests already use for their own frame-dependent work.
##
## Part B is gone (see the header): its replacement is a behavioural assertion in
## test_unit_corpse_linger_live.gd, so nothing in this file reads source text any more.
func _initialize() -> void:
	_unit = load("res://src/actors/minions/unit_actor.tscn").instantiate()
	root.add_child(_unit)


func _process(_delta: float) -> bool:
	_part_a()
	if is_instance_valid(_unit):
		_unit.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
