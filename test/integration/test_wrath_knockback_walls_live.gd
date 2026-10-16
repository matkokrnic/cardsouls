extends SceneTree

## Story 7-5b (AC 19): A WRATH KNOCKBACK STOPS AT THE ARENA WALL -- all four walls, for a hero and for a unit,
## against the REAL `main.tscn` collision geometry.
##
## STATE DECIDES, THE ACTOR MOVES, THE WALL STOPS (Dev Notes "Knockback is state-decided and actor-moved").
## Per wall, a headless `MatchState` (the bodies fixture) lands a REAL Wrath pulse on P2's hero and on one of
## P2's walking units, with the ring fact's bearing chosen so the slide points straight at that wall. Then,
## frame by frame, a probe `hero.tscn` body takes the state's hero velocity and a probe `unit_actor.tscn` body
## takes the state's unit slide through `UnitActor.travel` -- the two calls the runner's drive makes -- and
## each `move_and_slide()`s into the wall, while the state advances one tick per frame. The real P1/P2 heroes
## of `main.tscn` are left alone, far from the probes (the `test_arena_edge_live.gd` pattern).
##
## PASS, per wall and per body: the body moved TOWARD the wall by at least half the unobstructed slide (it was
## really pushed), its unobstructed slide would have carried it BEYOND the wall face (so the wall is what
## stopped it -- non-vacuity), it ends AGAINST the wall (within a small margin of its own half-extent from the
## face), never beyond it on any frame, and never lifted off the floor.
##
## Run: godot --headless --path . --script res://test/integration/test_wrath_knockback_walls_live.gd

const Fx := preload("res://test/deck_2_bodies_fixture.gd")

const FACE := 20.0
const HERO_HALF := 0.5
const UNIT_HALF := 0.3
const BOUND_EPSILON := 0.05
## Where each probe starts: 2 m (centre) inside the wall face, so the 4 m slide would end 2 m beyond it.
const START_INSET := 2.0
const SLIDE_FRAMES := Fx.KNOCKBACK_TICKS + 4

## Each wall: [name, the planar AWAY direction (the slide's), the axis it is measured on (0 = x, 1 = z),
## and the side's sign].
const WALLS := [
	["west", Vector2(-1, 0), 0, -1.0],
	["east", Vector2(1, 0), 0, 1.0],
	["north", Vector2(0, 1), 1, 1.0],
	["south", Vector2(0, -1), 1, -1.0],
]

var _phase := -1
var _frame := 0
var _ms: MatchState
var _hero: CharacterBody3D
var _unit: CharacterBody3D
var _unit_index := -1
var _hero_y := 0.0
var _unit_y := 0.0
var _hero_start := 0.0
var _unit_start := 0.0
var _hero_free_travel := 0.0
var _unit_free_travel := 0.0
var _failures: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _physics_process(_delta: float) -> bool:
	if _phase == -1 or _frame >= SLIDE_FRAMES:
		if _phase >= 0:
			_judge()
		_phase += 1
		if _phase >= WALLS.size():
			_finish()
			return false
		_start_wall()
		return false
	_frame += 1
	# The state's own answers, moved exactly as the runner's drive moves them.
	_hero.velocity = _ms.p2.hero.velocity
	_hero.move_and_slide()
	var slide := _ms.p2.units.knockback_velocity_at(_unit_index)
	_hero_free_travel += _ms.p2.hero.velocity.length() / TimingWindow.TICK_HZ
	_unit_free_travel += slide.length() / TimingWindow.TICK_HZ
	(_unit as UnitActor).travel(slide, slide.length())
	_check_bounds()
	Fx.D.idle(_ms, 1)
	return false


func _start_wall() -> void:
	var wall: Array = WALLS[_phase]
	var away: Vector2 = wall[1]
	var axis: int = wall[2]
	var side: float = wall[3]
	_frame = 0
	_hero_free_travel = 0.0
	_unit_free_travel = 0.0
	_ms = Fx.make()
	_unit_index = Fx.add_unit(_ms, 1, Fx.KIND_WALKER)
	Fx.cast_wrath(_ms, 0)
	# The ring fact carries the body-to-CASTER bearing; the slide goes the other way, at the wall.
	Fx.run_windup(_ms, 0, [[TargetingService.HERO_INDEX, -away], [_unit_index, -away]])
	if _hero != null:
		_hero.queue_free()
		_unit.queue_free()
	_hero = load("res://src/actors/hero/hero.tscn").instantiate()
	_unit = load("res://src/actors/minions/unit_actor.tscn").instantiate()
	root.add_child(_hero)
	root.add_child(_unit)
	var inset := FACE - START_INSET
	# The two probes stand 8 m apart along the wall, well clear of each other and of the match's heroes.
	if axis == 0:
		_hero.position = Vector3(side *inset, 1.0, 8.0)
		_unit.position = Vector3(side *inset, 0.0, -8.0)
	else:
		_hero.position = Vector3(8.0, 1.0, side *inset)
		_unit.position = Vector3(-8.0, 0.0, side *inset)
	_hero_y = _hero.position.y
	_unit_y = _unit.position.y
	_hero_start = side *inset
	_unit_start = side *inset


func _coord(body: Node3D, axis: int) -> float:
	return body.global_position.x if axis == 0 else body.global_position.z


func _check_bounds() -> void:
	var wall: Array = WALLS[_phase]
	var axis: int = wall[2]
	var side: float = wall[3]
	for pair: Array in [[_hero, HERO_HALF, _hero_y, "hero"], [_unit, UNIT_HALF, _unit_y, "unit"]]:
		var body: Node3D = pair[0]
		var past := side *_coord(body, axis) - (FACE - float(pair[1]))
		if past > BOUND_EPSILON:
			_failures.append("%s %s went BEYOND the wall at frame %d (%.3f past its limit)" % [
				wall[0], pair[3], _frame, past])
		if body.global_position.y > float(pair[2]) + BOUND_EPSILON:
			_failures.append("%s %s was LIFTED off the floor at frame %d (y %.3f)" % [
				wall[0], pair[3], _frame, body.global_position.y])


func _judge() -> void:
	var wall: Array = WALLS[_phase]
	var axis: int = wall[2]
	var side: float = wall[3]
	for pair: Array in [[_hero, HERO_HALF, _hero_start, _hero_free_travel, "hero"],
			[_unit, UNIT_HALF, _unit_start, _unit_free_travel, "unit"]]:
		var body: Node3D = pair[0]
		var at := _coord(body, axis)
		var moved := side *(at - float(pair[2]))
		var limit := FACE - float(pair[1])
		if float(pair[3]) <= START_INSET:
			_failures.append("%s %s: the unobstructed slide (%.3f m) would not reach the wall -- vacuous" % [
				wall[0], pair[4], float(pair[3])])
		if moved < START_INSET * 0.5:
			_failures.append("%s %s: barely moved (%.3f m) -- the knockback did not push it" % [
				wall[0], pair[4], moved])
		if absf(side *at - limit) > 0.1:
			_failures.append("%s %s: ended %.3f from the wall face, not against it" % [
				wall[0], pair[4], absf(FACE - side *at)])
	print("wrath_knockback_walls_live: %s hero=(%.3f) unit=(%.3f) free=(%.3f, %.3f)" % [
		wall[0], _coord(_hero, axis), _coord(_unit, axis), _hero_free_travel, _unit_free_travel])


func _finish() -> void:
	for failure in _failures:
		print("  FAIL: " + failure)
	var ok := _failures.is_empty()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
