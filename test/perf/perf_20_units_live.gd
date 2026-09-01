extends SceneTree

## Story 4-5 (AC 1/AC 2/AC 3): THE 20-UNIT FRAME-TIME MEASUREMENT HARNESS.
##
## This is TOOLING, not a test -- it has no pass/fail assertion of its own, it produces the
## numbers `4-5/R1`'s criterion is applied to. It lives under `test/perf/` rather than
## `test/integration/` precisely so `test/run_all.sh` (which globs `test/integration/test_*.gd`)
## never picks it up: it needs a real renderer, a real window, and a full minute of wall clock.
##
## Run (NOT --headless -- the renderer is half of what is being measured):
##   /c/Godot/godot_console.exe --path . --script res://test/perf/perf_20_units_live.gd
##
## OPEN QUESTION 1, RESOLVED (the harness mechanism, and how the heroes stay clear of the fight).
## The alternatives the story named were a DebugInstrumentPanel trigger, a live balance reload to
## cheapen summon costs, and a `test/`-tools scene driving the runner. This takes the THIRD, in the
## exact shape `test/integration/test_summon_actor_live.gd` established: a `--script` SceneTree
## that loads the real `main.tscn` and drives the whole chain through REAL Input Map presses ->
## KeyboardController -> the runner's single `_physics_process`. Chosen because it is the only one
## of the three that adds NO shipping surface at all -- the panel trigger would put a
## measurement-only control on a player-facing debug panel, and the balance-reload route would
## need the authored `.tres` costs edited for the duration of a run. Nothing under `src/` changes
## for the measurement to happen (AC 1, AC 13).
##
## NO `src/state/` TOUCH AND NO NEW STATE INTAKE. The state reads/writes here all go through
## EXISTING public API that `test_summon_actor_live.gd` already uses from a test seat:
## `mana.add()` / `stamina.add()` (that file tops mana up for the same reason -- the economy is
## not this measurement's subject), `hero.heal()`, and read-only board queries. No accessor is
## added, no signal is subscribed, no file under `src/state/` is edited.
##
## HOW THE HEROES ARE KEPT CLEAR (AC 1's named risk, "if 20 hostile units end rounds too fast to
## measure"). They are not moved -- they are made UNKILLABLE for the duration by healing them to
## full every tick. Moving them out of reach would make the minions walk away from each other and
## understate the load; healing keeps 20 hostile units permanently engaged on two stationary
## targets, which is the WORST case for the thing being measured, and it keeps `round_over` from
## ever latching and freezing the run mid-measurement. The heroes issue no intents beyond the
## casts below.
##
## OPEN QUESTION 2, RESOLVED (the frame-time read source). BOTH forms AC 2 offers, so neither has
## to be trusted alone:
##   (i) vsync is DISABLED AT RUNTIME here (`DisplayServer.window_set_vsync_mode`) with
##       `Engine.max_fps = 0` -- at runtime and not in `project.godot`, which this story must not
##       edit -- and WALL frame time is sampled in `_process` off `Time.get_ticks_usec()`. This is
##       the PRIMARY number the criterion is applied to: it is the whole cost of a frame, including
##       everything the engine does that no monitor attributes to a script.
##  (ii) the engine's own time monitors (`TIME_PROCESS` + `TIME_PHYSICS_PROCESS`, plus the
##       measured GPU render time) are sampled on the same frames as a CROSS-CHECK, so a wall
##       number inflated by something outside the engine's control cannot silently fail the story.
## A run whose wall p95 sits exactly on 16.67 ms would be the signature of vsync surviving the
## disable; the two series disagreeing is what would expose it.

# --- Population targets ------------------------------------------------------------------------

## `4-5/R1` (operator, 2026-09-01): 20 concurrent units, minions + totems, BOTH PLAYERS COMBINED.
## LIVING units -- a dead unit's record stays on the append-only board as a hole (`4-3a/R13`), so
## counting `size()` would let corpses stand in for the population the criterion names.
const TARGET_UNITS := 20
## Combat totems wanted per side before the build phase stops preferring them. AC 2 requires the
## totems to be FIRING, not merely present; two per side keeps projectiles in the air continuously
## rather than in the gaps of one totem's cadence. Not a floor the run blocks on -- the shuffle
## decides what reaches the hand, and the achieved count is reported.
const TOTEM_TARGET_PER_SIDE := 2
## The build phase gives up after this many physics frames and reports the population it reached,
## rather than spinning forever (AC 1's HALT-and-report path).
const BUILD_TIMEOUT_FRAMES := 5400
## The measured window: 3600 physics ticks = 60 s at 60 Hz. Longer than an observed round, and the
## heroes cannot die, so the population stays at ~20 for its whole length (see OQ 1 above).
const MEASURE_TICKS := 3600
## Frames spent settling before anything is measured (scene up, first draws dealt, shaders warm).
const WARMUP_FRAMES := 30

## THE HEROES ARE CLOSED TO THIS SEPARATION (metres, each side of x = 0) once, at build start, by
## writing the ACTOR's own position -- position is actor-owned (`4-3/R2`), so this is a
## presentation-layer write from a test seat and no state field learns of it.
##
## WHY IT IS NECESSARY, measured rather than assumed. The first run of this harness put 21 units on
## the board and measured a minute of NOTHING: zero deaths, zero projectiles. The diagnostic above
## shows why, and it is shipped-content behaviour rather than a harness bug -- the `standard`
## priority authored for every summoned unit is `prefer_hero = false` with the first-living-index
## ordering, so EVERY minion on a side acquires the opposing board's index 0 and walks at it. The
## two walls meet in the middle, jam against each other's collision bodies, and never come within
## `stop_distance` of a target that stands BEHIND the enemy line; nobody swings, so nobody dies.
## Meanwhile each Combat totem had acquired the enemy HERO, which at the untouched spawn separation
## sits ~11.5 m away -- outside the authored 8 m firing range -- so no totem ever fired.
##
## Closing the heroes puts the enemy hero inside totem range and collapses the arena onto the
## crowd, which is what makes AC 2's "combat totems FIRING" and AC 1's death stream real.
const HERO_ENGAGE_X := 2.0

## Both heroes SWING CONTINUOUSLY while the harness runs (see `_drive_attacks`). Without it nothing
## kills a unit -- the minions cannot reach the target they acquired, and the projectiles are aimed
## at heroes this harness keeps unkillable -- so the measured event stream would carry spawns and
## no deaths, and AC 1 asks for both. A hero swing is also the ONLY death source in shipped play
## that a stationary observer can drive, and it costs stamina the harness is already topping up.
const ATTACK_PERIOD := 10
const ATTACK_HOLD := 3

# --- Cast timing -------------------------------------------------------------------------------
# Presses are HELD across several frames rather than pulsed for one, for the reason
# test_summon_actor_live.gd records: this script's callback and the runner's are two separate
# callbacks in an unspecified order, so a one-frame pulse can be released before the runner ever
# samples the just_pressed edge.

const CAST_ARM_PRESS := 1
const CAST_ARM_RELEASE := 3
const CAST_CONFIRM_PRESS := 6
const CAST_CONFIRM_RELEASE := 8
const CAST_MODE_RELEASE := 10
const CAST_CYCLE_LENGTH := 13

var _frames := 0
var _runner: Node
var _state: MatchState
var _db: Node

var _phase := &"warmup"
var _measure_start_frame := 0

# Per-slot cast state machine. -1 = idle.
var _cast_t: Array[int] = [-1, -1]
var _cast_action: Array[StringName] = [&"", &""]

# --- Sample series -----------------------------------------------------------------------------

var _last_usec := 0
var _wall_ms: Array[float] = []
var _engine_ms: Array[float] = []
var _gpu_ms: Array[float] = []
## Every viewport whose GPU time is summed into `_gpu_ms` -- root plus both player SubViewports.
var _gpu_viewports: Array[RID] = []
## Parallel to `_wall_ms`: whether a unit SPAWN or DEATH resolved on the tick this frame carried.
var _event_flags: Array[bool] = []
var _event_this_frame := false
## Parallel to `_wall_ms`: whether a PHYSICS TICK ran on this rendered frame. With vsync off the
## engine renders far above 60 Hz, so only some frames carry a tick -- and separating the two
## populations is what turns "the engine time monitors read higher than the wall clock" from a
## contradiction into an explanation (the physics monitor reports the cost of a 60 Hz STEP, not of
## a rendered frame).
var _tick_flags: Array[bool] = []
var _tick_this_frame := false
## Spawn/death events, SPLIT BY PHASE. `_observe_events()` runs from the first tick onward -- the
## `_prev_*` cursors have to stay current through warmup and build or the first measured tick would
## report the whole build phase as one spawn burst -- but the build phase's own events belong to
## reaching the population, NOT to the measured stream. Counting them together made
## `spawn_events` a lifetime total sitting in a block of window-scoped numbers, which is how a
## report of "64 spawn events in the measured stream" came to include the 21 units the build phase
## put on the board (21 build + 43 measured = 64).
var _spawn_events := 0
var _death_events := 0
var _build_spawn_events := 0
var _build_death_events := 0
var _projectile_event_frames := 0
var _projectile_events_this_frame := false

var _prev_live: Array[int] = [0, 0]
var _prev_size: Array[int] = [0, 0]
var _prev_proj_size: Array[int] = [0, 0]

## Population and board-growth samples, taken once per measured tick (AC 10's observation).
var _live_samples: Array[int] = []
var _board_size_samples: Array[int] = []
var _proj_live_samples: Array[int] = []

var _build_frames := 0
var _casts_attempted: Array[int] = [0, 0]

## The measured window, overridable from the command line for a short diagnostic run:
##   godot --path . --script res://test/perf/perf_20_units_live.gd -- ticks=600 diag=120
## The DEFAULT is the story's number; the override exists so a harness iteration does not cost a
## full minute of wall clock, and the run reports which value it used.
var _measure_ticks := MEASURE_TICKS
var _diag_every := 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("ticks="):
			_measure_ticks = maxi(1, int(arg.substr(6)))
		elif arg.begins_with("diag="):
			_diag_every = maxi(0, int(arg.substr(5)))
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())
	# AC 3: the RESOLUTION is FORCED here rather than inherited from whatever size the window
	# manager happened to give the run. Two runs of this harness on the same machine reported
	# 1920x1111 and 1152x648 and therefore two different GPU loads; a measurement the story has to
	# be reproducible from cannot have its pixel count decided by the desktop.
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	# OQ 2 (i): vsync off AT RUNTIME, never in project.godot (which this story does not edit).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# OQ 2 (ii): ask the renderer to measure its own GPU time.
	#
	# THE ROOT VIEWPORT IS NOT WHERE THE SCENE IS DRAWN. `main.tscn` renders each player's 3D view
	# into its own `SubViewport` (`P1View/P1Viewport`, `P2View/P2Viewport`, a `Camera3D` in each);
	# the root window viewport only COMPOSITES those two textures and the HUD on top. Measurement is
	# per-viewport-RID, so instrumenting the root alone reports the compositing pass and excludes
	# essentially all of the work this story is about -- both camera passes over ~20 skinned units.
	# All three are instrumented and summed, so "the frame is GPU-clear" is a claim about the
	# renderer's actual load rather than about a blit.
	_gpu_viewports.append(root.get_viewport_rid())
	for path: String in ["Main/P1View/P1Viewport", "Main/P2View/P2Viewport"]:
		var vp := root.get_node_or_null(NodePath(path)) as SubViewport
		if vp != null:
			_gpu_viewports.append(vp.get_viewport_rid())
		else:
			print("WARNING: %s not found -- its GPU time is NOT in gpu_ms" % path)
	for rid: RID in _gpu_viewports:
		RenderingServer.viewport_set_measure_render_time(rid, true)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	# WALL frame time: the interval between consecutive rendered frames, with vsync disabled.
	var now := Time.get_ticks_usec()
	var wall := float(now - _last_usec) / 1000.0
	_last_usec = now
	# EVENT ATTRIBUTION IS OBSERVED HERE, NOT IN `_physics_process`, AND THE DIFFERENCE IS ONE TICK.
	# A `SceneTree` subclass's `_physics_process` is the MainLoop callback, which the engine runs
	# BEFORE it propagates the physics notification to nodes -- so the runner's `_physics_process`
	# (the one that instantiates and frees units) always runs AFTER this script's. Polling the board
	# at the top of a tick therefore reads the state the runner left at the END OF THE PREVIOUS one:
	# a spawn or death resolved on tick N was flagged onto the frame carrying tick N+1, one frame
	# after the frame that actually paid for `instantiate()` / `queue_free()`. `_process` runs after
	# every physics step of the same engine iteration, so observing here attributes the cost to the
	# frame that bore it. This is the number `4-5/R1`'s ~33 ms half is decided on -- see the review
	# note in the story record for the measured size of the correction.
	if _tick_this_frame:
		_observe_events()
	if _phase == &"measure":
		_wall_ms.append(wall)
		var engine_ms := (Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		_engine_ms.append(engine_ms)
		var gpu := 0.0
		for rid: RID in _gpu_viewports:
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_gpu_ms.append(gpu)
		_event_flags.append(_event_this_frame)
		_tick_flags.append(_tick_this_frame)
		if _projectile_events_this_frame:
			_projectile_event_frames += 1
	_event_this_frame = false
	_projectile_events_this_frame = false
	_tick_this_frame = false
	return false


func _physics_process(_delta: float) -> bool:
	_frames += 1
	_tick_this_frame = true
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		_db = root.get_node_or_null("/root/CardDatabase")
		if _runner == null or _state == null or _db == null:
			print("HARNESS ABORT: runner=%s state=%s db=%s" % [_runner, _state, _db])
			quit(1)
			return true
		if not _state.flags.minions or not _state.flags.totems:
			# Non-vacuity, up front: with either layer off every summon below degrades to a refusal
			# and the run would measure an empty arena while reporting a number.
			print("HARNESS ABORT: authored FeatureFlags has minions=%s totems=%s -- cannot reach 20 units"
				% [_state.flags.minions, _state.flags.totems])
			quit(1)
			return true
		return false

	# The economy is topped up every tick and the heroes are healed every tick. See OQ 1 above:
	# neither is what this story measures, and both are existing public API called from a test seat.
	_state.p1.mana.add(9999.0)
	_state.p2.mana.add(9999.0)
	_state.p1.stamina.add(9999.0)
	_state.p2.stamina.add(9999.0)
	_state.p1.hero.heal(9999.0)
	_state.p2.hero.heal(9999.0)

	if _phase == &"warmup":
		if _frames >= WARMUP_FRAMES:
			_close_the_heroes()
			_phase = &"build"
		return false

	if _phase == &"build":
		_build_frames += 1
		_drive_casts()
		_drive_attacks()
		if _live_total() >= TARGET_UNITS:
			_phase = &"measure"
			_measure_start_frame = _frames
			print("build complete at frame %d: live=%d totems=[%d,%d] casts=[%d,%d]" % [
				_frames, _live_total(), _combat_totems(0), _combat_totems(1),
				_casts_attempted[0], _casts_attempted[1]])
		elif _build_frames >= BUILD_TIMEOUT_FRAMES:
			print("HARNESS ABORT: build timed out at %d live units after %d frames (target %d)"
				% [_live_total(), _build_frames, TARGET_UNITS])
			quit(1)
			return true
		return false

	# --- measure -------------------------------------------------------------------------------
	# THE FREEZE GUARD. Healing to full every tick prevents death by attrition, but not a single
	# tick that lands more than a hero's full HP at once -- and `_round_over` is LATCHED
	# (`match_state.advance()` returns early forever after) and cleared only by the debug reset,
	# which this harness never presses. A run that froze would keep filling the window with
	# frozen-arena frames and print a very good-looking number. `_round_over` and hero DEAD are set
	# together by `_end_round`, so hero liveness is the cheap equivalent test -- cheap matters,
	# because this runs inside the tick the wall clock is timing.
	if not _state.p1.hero.is_alive() or not _state.p2.hero.is_alive():
		print("HARNESS ABORT: a hero died at frame %d despite per-tick healing -- the round froze and"
			% _frames + " the measured window would be frozen-arena frames. No number reported.")
		quit(1)
		return true

	# The population is HELD at ~20 by re-summoning as units die: deaths are part of the measured
	# spawn/death event stream, not an excuse to let the count decay (AC 1).
	_drive_casts()
	_drive_attacks()
	_live_samples.append(_live_total())
	_board_size_samples.append(_state.p1.units.size() + _state.p2.units.size())
	_proj_live_samples.append(
		_state.p1.projectiles.living_indices().size() + _state.p2.projectiles.living_indices().size())
	var elapsed := _frames - _measure_start_frame
	if _diag_every > 0 and elapsed % _diag_every == 0:
		_print_diag(elapsed)
	if elapsed >= _measure_ticks:
		_report()
		quit(0)
		return true
	return false


## A live picture of what the 20 units are actually DOING, printed on request. Written because the
## first run of this harness reported 21 standing units, zero deaths and zero projectiles for a
## whole minute -- a population that is present but inert measures the wrong thing, and no
## aggregate at the end of the run could have shown that.
func _print_diag(elapsed: int) -> void:
	var parts: Array[String] = []
	for slot in 2:
		var player: PlayerState = _state.p1 if slot == 0 else _state.p2
		var live: Array[int] = player.units.living_indices()
		var in_reach := 0
		var attacking := 0
		var hp_total := 0.0
		for index: int in live:
			if player.units.is_in_reach_at(index):
				in_reach += 1
			if player.units.attack_phase_at(index) != 0:
				attacking += 1
			hp_total += player.units.hp_at(index)
		var first_target := "-"
		if not live.is_empty():
			first_target = str(player.units.target_at(live[0]))
		parts.append("p%d live=%d reach=%d atk=%d hp=%.0f proj=%d/%d hero_hp=%.0f tgt0=%s pos0=%s" % [
			slot + 1, live.size(), in_reach, attacking, hp_total,
			player.projectiles.living_indices().size(), player.projectiles.size(),
			player.hero.get_hp(), first_target, _first_unit_position(slot)])
	print("t=%d  %s  |  %s" % [elapsed, parts[0], parts[1]])


## LIVENESS IS PART OF THE READING, and leaving it out is how this print was misread once already.
## The loop used to walk actor slots 0..4 filtered only on `is_instance_valid`, which are the OLDEST
## board indices and therefore the ones most likely to be DEAD: a corpse stays a valid actor for 600
## ticks after death (`match_runner._free_dead_unit_actors`), its collision is disabled the tick it
## dies, and `_approach_unit_actors` skips dead indices so its velocity is never driven and stays
## exactly 0.0. A pile of corpses therefore prints as bodies 0.1-0.2 m apart at v0.0 -- which is
## indistinguishable from the AC 11 flicker evidence unless the print says which it is. Living units
## come FIRST and are tagged `L`; corpses are tagged `D` and kept visible rather than filtered, since
## whether the overlap is corpses or live bodies is precisely the question AC 11 is asking.
func _first_unit_position(slot: int) -> String:
	var player: PlayerState = _state.p1 if slot == 0 else _state.p2
	var actors: Array = _runner._unit_actors[slot]
	var live_out: Array[String] = []
	var dead_out: Array[String] = []
	for index: int in actors.size():
		var actor: Variant = actors[index]
		if not is_instance_valid(actor):
			continue
		if not player.units.has_index(index):
			continue
		var alive: bool = player.units.is_alive_at(index)
		if alive and live_out.size() >= 5:
			continue
		if not alive and dead_out.size() >= 3:
			continue
		var p: Vector3 = (actor as Node3D).global_position
		var v: Vector3 = (actor as CharacterBody3D).velocity
		var cell := "%s%d:k%d@(%.1f,%.1f)v%.2f" % [
			"L" if alive else "D", index, player.units.kind_index_at(index), p.x, p.z, v.length()]
		if alive:
			live_out.append(cell)
		else:
			dead_out.append(cell)
	return " ".join(live_out + dead_out)


## Spawn and death events, per slot, off the boards the runner itself polls. A spawn is the board
## GROWING (it is append-only); a death is the living count falling by more than the growth.
func _observe_events() -> void:
	for slot in 2:
		var player: PlayerState = _state.p1 if slot == 0 else _state.p2
		var size: int = player.units.size()
		var live: int = player.units.living_indices().size()
		var spawned: int = maxi(0, size - _prev_size[slot])
		var died: int = maxi(0, (_prev_live[slot] + spawned) - live)
		if spawned > 0 or died > 0:
			_event_this_frame = true
			if _phase == &"measure":
				_spawn_events += spawned
				_death_events += died
			else:
				_build_spawn_events += spawned
				_build_death_events += died
		var proj_size: int = player.projectiles.size()
		if proj_size != _prev_proj_size[slot]:
			_projectile_events_this_frame = true
		_prev_size[slot] = size
		_prev_live[slot] = live
		_prev_proj_size[slot] = proj_size


func _live_total() -> int:
	return _state.p1.units.living_indices().size() + _state.p2.units.living_indices().size()


func _combat_totems(slot: int) -> int:
	var player: PlayerState = _state.p1 if slot == 0 else _state.p2
	var kind := _state.balance.kind_index_of(CardEffectResolver.KIND_COMBAT_TOTEM)
	var total := 0
	for index: int in player.units.living_indices():
		if player.units.kind_index_at(index) == kind:
			total += 1
	return total


## The real arm-then-confirm scheme, in the order the controller requires it: the cast-mode
## modifier is HELD, the card key arms the slot while it is down, and cast_confirm commits.
func _drive_casts() -> void:
	for slot in 2:
		if _cast_t[slot] < 0:
			if _live_total() < TARGET_UNITS:
				_begin_cast(slot)
			continue
		_cast_t[slot] += 1
		var t := _cast_t[slot]
		var p := "p1" if slot == 0 else "p2"
		if t == CAST_ARM_PRESS:
			Input.action_press(_cast_action[slot])
		elif t == CAST_ARM_RELEASE:
			Input.action_release(_cast_action[slot])
		elif t == CAST_CONFIRM_PRESS:
			Input.action_press(StringName("%s_cast_confirm" % p))
		elif t == CAST_CONFIRM_RELEASE:
			Input.action_release(StringName("%s_cast_confirm" % p))
		elif t == CAST_MODE_RELEASE:
			Input.action_release(StringName("%s_cast_mode" % p))
		elif t >= CAST_CYCLE_LENGTH:
			_cast_t[slot] = -1


## Close the two heroes onto the middle of the arena, once. See HERO_ENGAGE_X for why the
## untouched separation measures an inert arena.
func _close_the_heroes() -> void:
	for slot in 2:
		var hero: Node3D = _runner._p1_hero if slot == 0 else _runner._p2_hero
		var p := hero.global_position
		p.x = -HERO_ENGAGE_X if slot == 0 else HERO_ENGAGE_X
		p.z = 0.0
		hero.global_position = p


## Both heroes swing on a fixed cadence, but NEVER while that slot has a cast in flight: the cast
## scheme holds `cast_mode` down for ten frames and an attack press underneath it is a different
## gesture from the one the controller is being asked to read.
func _drive_attacks() -> void:
	for slot in 2:
		var action := StringName("p%d_attack" % (slot + 1))
		if _cast_t[slot] >= 0:
			Input.action_release(action)
			continue
		var phase := _frames % ATTACK_PERIOD
		if phase == 0:
			Input.action_press(action)
		elif phase == ATTACK_HOLD:
			Input.action_release(action)


func _begin_cast(slot: int) -> void:
	var index := _choose_slot(slot)
	if index < 0:
		return
	var p := "p1" if slot == 0 else "p2"
	var action := StringName("%s_card_%d" % [p, index + 1])
	if not InputMap.has_action(action):
		return
	_cast_action[slot] = action
	_cast_t[slot] = 0
	_casts_attempted[slot] += 1
	Input.action_press(StringName("%s_cast_mode" % p))


## Which hand slot to arm. A COMBAT-TOTEM card wins while this side is under its totem target (AC 2
## needs totems FIRING, and the shuffle must not decide whether they are there); otherwise the
## first summoning card; otherwise ANY castable card, purely to cycle a hand of nothing but spells
## back into summons.
func _choose_slot(slot: int) -> int:
	var player: PlayerState = _state.p1 if slot == 0 else _state.p2
	var hand: Array = player.hand.to_array()
	var want_totem := _combat_totems(slot) < TOTEM_TARGET_PER_SIDE
	var first_summon := -1
	var first_any := -1
	for index in hand.size():
		if player.hand.is_slot_empty(index):
			continue
		var card := _db.get_card(hand[index]) as CardData
		if card == null or card.basic_effect == null:
			continue
		if first_any < 0:
			first_any = index
		var effect_id: StringName = card.basic_effect.effect_id
		if not String(effect_id).begins_with(CardEffectResolver.PREFIX_SUMMON):
			continue
		if first_summon < 0:
			first_summon = index
		if want_totem and effect_id == &"summon_combat_totem":
			return index
	if first_summon >= 0:
		return first_summon
	return first_any


# --- Reporting ---------------------------------------------------------------------------------

func _report() -> void:
	var out := {
		"story": "4-5-pooling-60fps-exit",
		"criterion": "4-5/R1: 20 concurrent units (minions + totems, both players); projectiles neither counted nor capped; no hard cap",
		"machine": _machine_facts(),
		"population": {
			"target_units": TARGET_UNITS,
			"live_min": _min_int(_live_samples),
			"live_avg": _avg_int(_live_samples),
			"live_max": _max_int(_live_samples),
			"combat_totems_p1": _combat_totems(0),
			"combat_totems_p2": _combat_totems(1),
			"board_records_start": _board_size_samples[0],
			"board_records_end": _board_size_samples[_board_size_samples.size() - 1],
			"projectiles_live_avg": _avg_int(_proj_live_samples),
			"projectiles_live_max": _max_int(_proj_live_samples),
			# MEASURED-WINDOW ONLY. The build phase's own events are reported beside them, never
			# folded in -- see the `_spawn_events` declaration.
			"spawn_events": _spawn_events,
			"death_events": _death_events,
			"build_spawn_events": _build_spawn_events,
			"build_death_events": _build_death_events,
			"casts_attempted": _casts_attempted,
			"build_frames": _build_frames,
		},
		"frames": {
			"measured_ticks": _measure_ticks,
			"measured_ticks_achieved": _live_samples.size(),
			"rendered_frames": _wall_ms.size(),
			"event_frames": _count_true(_event_flags),
			"projectile_event_frames": _projectile_event_frames,
		},
		"wall_ms": _series_stats(_wall_ms),
		"engine_ms": _series_stats(_engine_ms),
		"gpu_ms": _series_stats(_gpu_ms),
		"physics_frames": _split_by_tick(),
		"worst_event_frame_ms": _worst_flagged(_wall_ms, _event_flags),
		"worst_event_frame_engine_ms": _worst_flagged(_engine_ms, _event_flags),
		# The INDEX makes the ~33 ms half auditable: it can be read against `wall_ms.max_index` to
		# see whether the worst frame anywhere in the run was an event frame or a separate outlier.
		"worst_event_frame_index": _worst_flagged_index(_wall_ms, _event_flags),
		"trend": _trend(),
	}
	var text := JSON.stringify(out, "  ")
	var path := "user://perf_4_5_run.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
	print("=== 4-5 PERF RESULT ===")
	print(text)
	print("=== written to: %s ===" % ProjectSettings.globalize_path(path))


func _machine_facts() -> Dictionary:
	var size := DisplayServer.window_get_size()
	return {
		"cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"),
		"window_size": [size.x, size.y],
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"godot": Engine.get_version_info().get("string", "?"),
		"os": OS.get_name(),
	}


func _series_stats(series: Array[float]) -> Dictionary:
	if series.is_empty():
		return {"n": 0}
	var sorted := series.duplicate()
	sorted.sort()
	var total := 0.0
	for v: float in series:
		total += v
	var max_index := 0
	var over_16 := 0
	var over_33 := 0
	for i in series.size():
		if series[i] > series[max_index]:
			max_index = i
		# The criterion's two thresholds, counted rather than inferred from a percentile: one 60 Hz
		# frame (1/60 s) and the ~33 ms spawn/death ceiling.
		if series[i] > 1000.0 / 60.0:
			over_16 += 1
		if series[i] > 33.3:
			over_33 += 1
	return {
		"n": series.size(),
		"avg": total / float(series.size()),
		"p50": _percentile(sorted, 0.50),
		"p95": _percentile(sorted, 0.95),
		"p99": _percentile(sorted, 0.99),
		"max": sorted[sorted.size() - 1],
		"max_index": max_index,
		"over_16_67": over_16,
		"over_33_3": over_33,
	}


func _percentile(sorted: Array[float], q: float) -> float:
	var rank := int(ceil(q * float(sorted.size()))) - 1
	return sorted[clampi(rank, 0, sorted.size() - 1)]


## Rendered frames that CARRIED a 60 Hz physics tick, against those that did not. The difference
## between the two averages is the marginal cost of one full tick -- gather, `advance()`, drive,
## drain -- at the measured population, which is the number the 60 Hz budget actually has to hold.
func _split_by_tick() -> Dictionary:
	var with_total := 0.0
	var with_count := 0
	var without_total := 0.0
	var without_count := 0
	var with_max := 0.0
	for i in mini(_wall_ms.size(), _tick_flags.size()):
		if _tick_flags[i]:
			with_total += _wall_ms[i]
			with_count += 1
			with_max = maxf(with_max, _wall_ms[i])
		else:
			without_total += _wall_ms[i]
			without_count += 1
	# THE CRITERION'S OWN POPULATION, computed rather than bounded by argument. A vsync-locked 60 Hz
	# build renders only tick-carrying frames, so `wall_ms.p95` -- a percentile over a series that is
	# ~3/4 tick-free frames -- is not the p95 `4-5/R1`'s sustained half is about. The story record
	# reached the same verdict by bounding it ("only N frames exceed 16.67 ms and 5% of 3600 is
	# 180"), which is sound but is an argument where a number was available.
	var with_sorted: Array[float] = []
	for i in mini(_wall_ms.size(), _tick_flags.size()):
		if _tick_flags[i]:
			with_sorted.append(_wall_ms[i])
	with_sorted.sort()
	return {
		"with_tick_n": with_count,
		"with_tick_avg_ms": with_total / float(maxi(with_count, 1)),
		"with_tick_max_ms": with_max,
		"with_tick_p50_ms": _percentile(with_sorted, 0.50) if with_count > 0 else -1.0,
		"with_tick_p95_ms": _percentile(with_sorted, 0.95) if with_count > 0 else -1.0,
		"with_tick_p99_ms": _percentile(with_sorted, 0.99) if with_count > 0 else -1.0,
		"without_tick_n": without_count,
		"without_tick_avg_ms": without_total / float(maxi(without_count, 1)),
		"marginal_tick_cost_ms": (with_total / float(maxi(with_count, 1)))
			- (without_total / float(maxi(without_count, 1))),
	}


## -1.0 when NO frame carried an event, never 0.0. A 0.0 here reads as "the worst spawn/death frame
## was instant" and passes the ~33 ms clause trivially -- which is exactly what an inert arena would
## have reported, and run 1 of this harness produced precisely that arena (zero deaths, zero
## projectiles for a full minute). The sentinel makes an empty event stream unmistakable.
func _worst_flagged(series: Array[float], flags: Array[bool]) -> float:
	var worst := -1.0
	for i in mini(series.size(), flags.size()):
		if flags[i] and series[i] > worst:
			worst = series[i]
	return worst


func _worst_flagged_index(series: Array[float], flags: Array[bool]) -> int:
	var worst := -1.0
	var at := -1
	for i in mini(series.size(), flags.size()):
		if flags[i] and series[i] > worst:
			worst = series[i]
			at = i
	return at


## AC 10: the board-growth observation. The unit board is APPEND-ONLY (`4-3a/R9`), so the question
## is whether per-tick cost drifts upward as dead records accumulate. First quarter of the measured
## window against the last, same population, same totems firing.
func _trend() -> Dictionary:
	var n := _wall_ms.size()
	if n < 8:
		return {}
	var q := n / 4
	return {
		"early_wall_avg": _avg_range(_wall_ms, 0, q),
		"late_wall_avg": _avg_range(_wall_ms, n - q, n),
		"early_engine_avg": _avg_range(_engine_ms, 0, q),
		"late_engine_avg": _avg_range(_engine_ms, n - q, n),
		"board_records_start": _board_size_samples[0],
		"board_records_end": _board_size_samples[_board_size_samples.size() - 1],
	}


func _avg_range(series: Array[float], from: int, to: int) -> float:
	var total := 0.0
	var count := 0
	for i in range(from, mini(to, series.size())):
		total += series[i]
		count += 1
	return total / float(maxi(count, 1))


func _avg_int(series: Array[int]) -> float:
	if series.is_empty():
		return 0.0
	var total := 0
	for v: int in series:
		total += v
	return float(total) / float(series.size())


func _min_int(series: Array[int]) -> int:
	if series.is_empty():
		return 0
	var out := 1 << 30
	for v: int in series:
		out = mini(out, v)
	return out


func _max_int(series: Array[int]) -> int:
	var out := 0
	for v: int in series:
		out = maxi(out, v)
	return out


func _count_true(flags: Array[bool]) -> int:
	var total := 0
	for f: bool in flags:
		if f:
			total += 1
	return total
