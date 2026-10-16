extends SceneTree

## Story 7-5b smoke fix 2 (S14, the Stars of Ruin shape): AN ELEMENTAL FURY VOLLEY LEAVES IN A FAN, BLOOMS, THEN
## CONVERGES ON THE OPPOSING HERO -- in the real `main.tscn`, both seats on Deck 2, against the AUTHORED
## `elemental_fury.tres` (read at run time, never copied here).
##
## P1 holds one orb of each colour and faces P2; the volley is fired through the state's own resolution seat
## (`MatchState._apply_elemental_fury`: the record, the first shot and the owed volley exactly as an activation
## writes them), so the runner's fan reads a real record. Asserted, geometry and facts:
##   FAN       the three shots' LAUNCH headings, against P1's facing, are -arc, 0 and +arc (`fan_arc_degrees`): they
##             differ by the authored arc, one per shot in launch order;
##   BLOOM     while state still flies a shot at its `launch_speed` (the delay before the acceleration, read off the
##             distance state charges each tick), its heading turns no more per tick than
##             `bloom_turn_rate_degrees_per_second` allows -- it flies nearly straight, so the fan opens;
##   CONVERGE  after the bloom a SIDE shot turns sharply -- some tick turns it more than twice the bloom's allowance
##             (the effect's own `homing_turn_rate_degrees_per_second`);
##   LAND      all three land on the hero, read off state: P2 loses the red shot's damage, P2 is slowed (blue) and
##             P1, hurt beforehand, gains the green heal.
##
## NAMED MUTATIONS: an arc of 0 (the three headings are one); the bloom ignored (the side shots turn at the strong
## rate from launch, past the bloom's allowance).
##
## Run: godot --headless --path . --script res://test/integration/test_fury_flight_live.gd

const FURY := &"elemental_fury"
const FURY_PATH := "res://data/effects/elemental_fury.tres"
const SHOTS := 3
const FIRE_FRAME := 5
const MAX_FRAMES := 600
const ANGLE_EPS_DEGREES := 1.0
## A tick's turn may exceed the bloom allowance by this much (radians) for float noise; a step this close (m/s) to the
## launch speed is still at it.
const TURN_EPS := 0.0005
const SPEED_EPS := 0.0001
const HURT := 20.0
const SETTLE_FRAMES := 10

var _frames := 0
var _done_frame := -1
var _runner: Node
var _state: MatchState
var _authored: CardEffect
var _facing := Vector3.ZERO
var _p1_hp := 0.0
var _p2_hp := 0.0
## Per shot index: [launch angle (deg), last heading, max bloom step, max later step, bloom ticks seen].
var _shots := {}
var _stopping := -1
var _failures: Array[String] = []


func _initialize() -> void:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	var deck_2 := load("res://data/decks/deck_2.tres") as DeckList
	var seats: Array[DeckList] = [deck_2, deck_2]
	main.seat_deck_list_overrides = seats
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _stopping >= 0:
		_stopping += 1
		if _stopping >= 3:
			_finish()
		return false
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_authored = load(FURY_PATH) as CardEffect
		if _state == null or _authored == null:
			return _end("missing runner, state or the authored effect")
		if _authored.fan_arc_degrees <= 0.0 or _authored.bloom_turn_rate_degrees_per_second <= 0.0:
			return _end("the authored effect has no fan or no bloom")
		_state.p1.hero.take_damage(HURT)
		_state.p1.orbs.reset_all()
		for color: int in [Enums.CardColor.RED, Enums.CardColor.BLUE, Enums.CardColor.GREEN]:
			_state.p1.orbs.add(color, 1)
		return false
	if _frames == FIRE_FRAME:
		var to_p2: Vector3 = (_runner._p2_hero as Node3D).global_position - (_runner._p1_hero as Node3D).global_position
		_facing = Vector3(to_p2.x, 0.0, to_p2.z).normalized()
		_state.p1.hero.facing = Vector2(_facing.x, _facing.z)
		_p1_hp = _state.p1.hero.get_hp()
		_p2_hp = _state.p2.hero.get_hp()
		var effect: CardEffect = _state._effects_by_effect_id.get(FURY)
		if effect == null:
			return _end("the match injected no `elemental_fury` effect (Deck 2 seats)")
		_state._apply_elemental_fury(_state.p1, effect, 0)
		return false
	if _frames > FIRE_FRAME:
		_track()
	var done := _shots.size() >= SHOTS
	for index: int in _shots:
		done = done and not _state.p1.projectiles.is_alive_at(index)
	if done and _done_frame < 0:
		_done_frame = _frames
	# A few frames after the last landing, so every landing's look and sound has started before they are stopped.
	if (_done_frame > 0 and _frames >= _done_frame + SETTLE_FRAMES) or _frames >= MAX_FRAMES:
		return _end("")
	return false


## Each live Fury shot's heading this frame: its launch angle on first sight, then its per-tick turn by phase.
func _track() -> void:
	var board := _state.p1.projectiles
	var actors: Array = _runner._projectile_actors[0]
	for index: int in actors.size():
		if index >= board.size() or StringName(board.effect_id_at(index)) != FURY or not is_instance_valid(actors[index]):
			continue
		var heading: Vector3 = (actors[index] as ProjectileActor).heading
		if not _shots.has(index):
			_shots[index] = [rad_to_deg(_facing.signed_angle_to(heading, Vector3.UP)), heading, 0.0, 0.0, 0]
			continue
		if not board.is_alive_at(index):
			continue
		var entry: Array = _shots[index]
		var step := (entry[1] as Vector3).angle_to(heading)
		entry[1] = heading
		# The turn just seen was steered on the step state charged as it reads now (the drive follows the advance), and
		# the shot blooms while that step is still its launch speed.
		var speed: float = _state.projectile_step_distance_at(board, index) * TimingWindow.TICK_HZ
		if speed <= _authored.launch_speed + SPEED_EPS:
			entry[2] = maxf(float(entry[2]), step)
			entry[4] = int(entry[4]) + 1
		else:
			entry[3] = maxf(float(entry[3]), step)


func _end(message: String) -> bool:
	if message != "":
		_failures.append(message)
	elif _state != null:
		_judge()
	_stop_sounds()
	_stopping = 0
	return false


## Every sound stopped -- the presenter's and the cues' -- so none is freed while it plays (a leak at exit).
func _stop_sounds() -> void:
	if _runner != null and _runner._effects != null:
		_runner._effects.stop_all_sounds()
	for type: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for node in root.find_children("*", type, true, false):
			node.call(&"stop")


func _judge() -> void:
	_check(_shots.size() == SHOTS, "saw %d Fury shots, want %d" % [_shots.size(), SHOTS])
	var indices: Array = _shots.keys()
	indices.sort()
	var arc := _authored.fan_arc_degrees
	var bloom_step := deg_to_rad(_authored.bloom_turn_rate_degrees_per_second) / TimingWindow.TICK_HZ
	var side_after := 0.0
	for i: int in indices.size():
		var entry: Array = _shots[indices[i]]
		var want := -arc + 2.0 * arc * float(i) / float(SHOTS - 1)
		_check(absf(float(entry[0]) - want) < ANGLE_EPS_DEGREES,
				"FAN: shot %d left at %.2f degrees from the caster's facing, want %.2f" % [i, entry[0], want])
		_check(int(entry[4]) > 0, "BLOOM: shot %d was never seen inside its bloom" % i)
		_check(float(entry[2]) <= bloom_step + TURN_EPS,
				"BLOOM: shot %d turned %.3f degrees in one bloom tick, past the bloom's %.3f"
						% [i, rad_to_deg(entry[2]), rad_to_deg(bloom_step)])
		if i != 1:
			side_after = maxf(side_after, float(entry[3]))
	_check(side_after > 2.0 * bloom_step,
			"CONVERGE: after the bloom no side shot turned more than %.3f degrees in a tick (max %.3f) -- it never converged"
					% [rad_to_deg(2.0 * bloom_step), rad_to_deg(side_after)])
	_check(is_equal_approx(_state.p2.hero.get_hp(), _p2_hp - _authored.damage_amount),
			"LAND: P2 went %.2f -> %.2f, want the red shot's %.1f" % [_p2_hp, _state.p2.hero.get_hp(), _authored.damage_amount])
	_check(_state.p2.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW), "LAND: the blue shot did not slow P2")
	_check(is_equal_approx(_state.p1.hero.get_hp(), _p1_hp + _authored.heal_amount),
			"LAND: P1 went %.2f -> %.2f, want the green heal +%.1f" % [_p1_hp, _state.p1.hero.get_hp(), _authored.heal_amount])


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _finish() -> void:
	for f in _failures:
		print("  FAILED: " + f)
	var angles: Array = []
	for index: int in _shots:
		angles.append("%.2f" % float(_shots[index][0]))
	print("fury_flight_live: frames=%d launch_angles=%s" % [_frames, angles])
	var ok := _failures.is_empty()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	_stop_sounds()
	var main := root.get_node_or_null("Main")
	if main != null:
		main.free()
	quit(0 if ok else 1)
