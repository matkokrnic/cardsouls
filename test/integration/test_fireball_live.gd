extends SceneTree

## Story 6-5d (AC 20, AC 28, AC 36, AC 37): FIREBALL AND ITS TARGETING, IN THE LIVE SCENE.
##
## WHAT THIS FILE OWNS, and it is precisely the half `test/state/test_fireball.gd` cannot reach. That
## file proves the STATE of a Fireball -- the staging cost, the locked damage, the cast fork, the
## hero-sourced record, the target-only contact rung, every defence and the budget -- with no scene at
## all. Everything below needs a running scene and is the RUNTIME COMPOSITION blind spot `3-0b/R34`
## names: state and runner each correct, wired to each other wrongly.
##   * AC 28: THE WARNING SITS ON THE CAPTURED TARGET, and the runner resolves that address itself.
##     Both arms in ONE run, on the SAME hero, which is what makes each the other's non-vacuity:
##     cast 1 is aimed at P2's HERO and P2 shows today's marker and alarm with NO cone anywhere; cast 2
##     is aimed at a P2 MINION and P2's hero -- the body standing behind it -- shows NOTHING while a
##     placeholder cone hovers over the minion. A marker check that could not tell those apart would
##     pass on a hero-addressed marker, which is exactly the mutation this file kills.
##   * AC 28: THE CAST PROP FLIES TO THE CAPTURED TARGET, A MINION INCLUDED. The minion is kept METRES
##     from the opposing hero (asserted, `MIN_SEPARATION`), so "it flew to the minion" and "it flew to
##     the hero by slot arithmetic" are different measurements rather than the same one.
##   * AC 20 IN REAL PHYSICS. Headlessly a pass-through is a synthetic fact pushed at the seam; here the
##     Fireball's own `Hitbox` is asked for its overlaps, exactly as `_gather_projectile_facts` asks, and
##     the NON-TARGET minion it really overlaps must lose no HP and must not consume the shot.
##   * AC 36 IN THE SAME SCENE: a Combat totem's shot fired in the same match still lands on the FIRST
##     BODY it touches, which is not its target -- so pass-through is provably Fireball-only rather than
##     a rule the runner applied to every shot.
##   * AC 37: the direction-aware homing assertion `test_projectile_flight_live.gd` carries for the
##     totem's shot, carried here for the hero's (AC 37's last clause).
##
## THE CASTS ARE POKED ONTO THE PLAYER, not pressed from a hand -- `test_cast_presentation_live.gd`'s
## right-sized-poke precedent verbatim, and for its reason: `PlayerState.start_cast` is the same public
## arm the press seat calls, the strike seat downstream cannot tell how the window was armed, and driving
## a real press would make every assertion here depend on which card the shuffle dealt. The CARD IDS are
## the shipped ones (`bloodhound_step` for the PITCH map, `honed_bolt` for the BASIC one) and the
## durations are read live off the authored `.tres`, so a retune re-times this test with it.
##
## NOTHING HERE IS FRAME-COUNTED. Every phase advances on an OBSERVED EDGE (`is_casting()` falling, the
## board record dying, a measured distance) rather than on an arithmetic tick, because two casts, a
## flight, a walk and a totem windup in one run would otherwise be five constants that a `cast_seconds`
## or `move_speed` retune silently invalidates. The only hard number is `DEADLINE`, which FAILS.
##
## THE PAD FOR DETERMINISM is the one every `*_live` test in this directory relies on: with no joypad
## connected the shipped controllers emit a NEUTRAL intent every tick, so the only inputs this scene
## ever sees are the two pokes below, and a tail of quiet frames is left after the last measurement so
## nothing is asserted on the tick it happened.
##
## Run: godot --headless --path . --script res://test/integration/test_fireball_live.gd

const FIREBALL_EFFECT_PATH := "res://data/effects/fireball.tres"
const BOLT_EFFECT_PATH := "res://data/effects/honed_bolt.tres"
const FIREBALL_CARD_PATH := "res://data/cards/bloodhound_step.tres"
## The card ids the two pokes name: Bloodhound Step's PITCH effect is Fireball (AC 1), Honed Bolt's
## BASIC effect is the bolt. Asserted against the authored card at frame 2 rather than trusted.
const FIREBALL_CARD := &"bloodhound_step"
const BOLT_CARD := &"honed_bolt"
const MINION_KIND := &"minion"
const TOTEM_KIND := &"combat_totem"

## The damage the poked cast carries. A cast's damage is FROZEN AT STAGING (AC 7) and handed to the
## strike, so a poke supplies it exactly as the activation seat would; the landing must remove this
## number and no other, which is what makes the record -> funnel -> HP path live rather than assumed.
const FIREBALL_DAMAGE := 12.0

## The lane. Everything sits on z = 0 and is separated in x, so "in the way" is a fact about one axis.
const P1_X := -6.0
const P2_X := 12.0
## Where the Combat totem is first stood: far out of range of P2's hero, so it holds fire (the
## `test_projectile_flight_live.gd` hold-fire-then-in-range shape) until the totem phase re-stands it.
const TOTEM_X := -16.0
## Where the NON-TARGET minion stands -- ONE METRE in front of the caster, inside the walk-stop
## distance to the hero it acquires, so it settles there and stays on the lane.
##
## MEASURED, AND IT CORRECTED THE OBVIOUS PLACEMENT. The first fixture stood the minion at the midpoint
## of the lane, and the Fireball MISSED it (`overlap=0`): the lateral nudges that make the homing
## assertion falsifiable bend the flight by metres, so a body placed far down the lane is no longer on
## the path by the time the shot arrives. A body one metre ahead of the launch is crossed within the
## first few ticks, BEFORE the first nudge -- and the pass-through claim is about a body the shot really
## overlaps, not about where on the lane that happens.
const MINION_X := -5.0
## AC 36's geometry, laid out from the minion's SETTLED position at the totem phase (see
## `_sample_totem_wait`): the totem this far behind it, P2's hero this far in front, both on the lane.
## Their sum must stay inside the totem's authored range, which is asserted rather than assumed.
const TOTEM_STANDOFF := 4.5
const HERO_STANDOFF := 2.5
## How many consecutive frames the minion must hold still before the totem phase is laid out on its
## position -- a walking body would make the lane decay between the layout and the shot.
const STILL_FRAMES := 10

## AC 28's non-vacuity floor: the minion must stay at least this far from the opposing HERO for the
## whole of cast 2, or "the cone/prop went to the minion" would not be distinguishable from "it went
## to the hero".
const MIN_SEPARATION := 4.0
## How close the cone must sit to the body it marks, allowing for `TargetConeActor.HOVER_HEIGHT`.
const CONE_TOLERANCE := 0.35
## How close the prop must come to the marked minion to count as having flown TO it.
const PROP_TOLERANCE := 1.0
## AC 37: how much worse than its OPENING sample the final aim error may be, in radians -- the
## `test_projectile_flight_live.gd` constant and its reasoning verbatim.
const AIM_TOLERANCE := 0.01
## The lateral nudge that makes homing falsifiable, and why it STOPS: a target that keeps sidestepping
## faster than the shot can turn would never be caught, and this test also has to see the shot LAND.
## Five nudges inside the first half-second, then a clear run for the aim error to close.
const NUDGE_TICKS := 30
const NUDGE_EVERY := 6
const NUDGE_DISTANCE := 1.0

## Frames after the totem phase opens: its reach probe cadence, its 0.9 s windup and the short flight.
const TOTEM_TAIL := 160
## Quiet frames after the last measurement.
const TAIL := 12
## Smoke fix / AC 15 live check (2026-09-28): how long after the Fireball lands on the hero the
## absence of a stun/root is sampled -- at least 1.0 s at 60 Hz (`TimingWindow.TICK_HZ`), with margin.
const POST_LAND_TICKS := 65
## A hard stop. Reaching it is a FAILURE, never a pass: a phase that never opened is a phase whose
## assertions never ran. Widened from 900 for the two new phases below (a 1 s post-land sample plus a
## whole bolt-on-hero cast, its 0.4 s stun and its 2.5 s root, read live off the authored effect).
const DEADLINE := 1300

var _frames := 0
var _runner: Node = null
var _state: MatchState = null
var _failures: Array[String] = []
var _detail := ""

var _phase := "setup"
var _phase_frame := 0
var _fireball_ticks := 0
var _bolt_ticks := 0
var _range := 0.0
var _minion_hp := 0.0

## AC 28, cast 1 -- the HERO arm.
var _cast1_ticks := 0
var _cast1_marker_ticks := 0
var _cast1_alarm_ticks := 0
var _cast1_cone_seen := false
var _cast1_caster_warned := false
## Smoke fix (operator finding, 2026-09-28): the bolt prop exists ONLY for a Honed Bolt cast --
## `match_runner._push_cast_presentation` used to spawn and advance one for EVERY cast, so a Fireball
## activation showed the lightning prop land before the Fireball itself flew. Sampled for the whole of
## cast 1; cast 2 below (the real bolt) is this check's non-vacuity twin.
var _cast1_bolt_seen := false

## AC 15, live (operator addition, 2026-09-28): for at least 1 s after the Fireball LANDS on the hero,
## neither the dizzy nor the stunned clip ever plays on it, no root marker shows, and the state side
## agrees. Read paths cited from `test_cast_presentation_live.gd`: the clip off
## `AnimationController.animation_player.assigned_animation` (that file's `_sample()` comment on why
## `assigned_animation`, not `current_animation`, survives a held final frame) and the root ring off
## `TelegraphController`'s `RootMark` mesh (`_root_marker_visible`, its own read path, cited verbatim).
var _post_land_ticks := 0
var _post_land_dizzy_seen := false
var _post_land_stunned_clip_seen := false
var _post_land_root_marker_seen := false
var _post_land_stun_is_bolt_seen := false
var _post_land_action_stunned_seen := false
var _post_land_root_running_seen := false

## AC 15's non-vacuity twin: a DEDICATED bolt-on-hero cast (cast 3 -- cast 2 targets a MINION and
## cannot stun a hero at all), in the SAME run, proving the same read paths above really do show a
## POSITIVE when a bolt (not a Fireball) lands on the hero.
var _cast3_ticks := 0
var _cast3_dizzy_seen := false
var _cast3_root_marker_seen := false
var _cast3_stun_is_bolt_seen := false

## AC 13 / AC 20 / AC 37 -- the flight.
var _shot_seen := false
var _launch_gap := -1.0
var _shot_max_gap := 0.0
var _flight_ticks := 0
var _overlapped_non_target := false
var _overlap_ticks := 0
var _minion_hp_at_overlap := -1.0
var _minion_hp_after_overlap := -1.0
var _alive_ticks_after_overlap := 0
var _aim_errors: Array[float] = []
var _aim_improved := false
var _target_gap_first := -1.0
var _target_gap_last := -1.0
var _hero_hp_before_landing := -1.0
var _hero_hp_after_landing := -1.0
var _landed := false

## AC 28, cast 2 -- the UNIT arm.
var _cast2_ticks := 0
var _cone_ticks := 0
var _cone_off_target_ticks := 0
## Story 7-6 (operator ruling P21): the cone is a debug-layer cue. Ticks it was hidden with the layer shown, and the
## one mid-cast F3-off probe (the cone must hide, then show again).
var _cone_hidden_ticks := 0
var _cone_probe := ""
var _cast2_hero_marker_ticks := 0
var _cast2_hero_alarm_ticks := 0
var _cast2_min_separation := 1000.0
var _prop_seen := false
var _prop_inflight_ticks := 0
var _prop_min_gap := 1000.0
var _prop_arrived := false

## AC 36 -- the totem's shot in the same scene.
var _minion_still := 0
var _minion_last_pos := Vector3.ZERO
var _totem_phase_opened := false
var _totem_shot_index := -1
var _totem_shot_target_index := 0
var _totem_shot_consumed := false
var _units_hp_at_totem_phase := -1.0
var _units_hp_after_totem_shot := -1.0
var _p2_hp_at_totem_phase := -1.0
var _p2_hp_after_totem_shot := -1.0


func _initialize() -> void:
	var scene: PackedScene = load("res://src/main/main.tscn")
	root.add_child(scene.instantiate())


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_runner = root.get_node_or_null("Main")
		_state = _runner._match_state if _runner != null else null
		if _runner == null or _state == null:
			return _fail("missing: runner=%s state=%s" % [_runner, _state])
		# Story 7-6 (operator rulings P21/P22): the cast-target cone this file asserts is a debug-layer shape -- show it (F3).
		_runner.set_debug_layer_visible(true)
		return false

	if _frames == 2:
		return _non_vacuity()

	if _frames == 3:
		_p1_hero().global_position = Vector3(P1_X, 1.0, 0.0)
		_p2_hero().global_position = Vector3(P2_X, 1.0, 0.0)
		return false

	if _frames == 4:
		# STRAIGHT ONTO THE BOARDS rather than cast from a hand -- `test_projectile_flight_live.gd`'s
		# stated precedent: the runner spawns an actor per BOARD RECORD, so a record appended here
		# exercises exactly the spawn path a cast would, without depending on the deal.
		var totem_kind := _state.balance.kind_index_of(TOTEM_KIND)
		_state.p1.units.add(_state.balance.kind_at(totem_kind).max_hp, totem_kind)
		var minion_kind := _state.balance.kind_index_of(MINION_KIND)
		_state.p2.units.add(_state.balance.kind_at(minion_kind).max_hp, minion_kind)
		return false

	if _frames == 6:
		var totem := _unit_actor(0, 0)
		var minion := _unit_actor(1, 0)
		if totem == null or minion == null:
			return _fail("the runner spawned no actor for a board record")
		# Placed, not summoned into position: a summon stands the unit BEHIND its summoner, which would
		# leave the totem two metres from its own hero and the minion off the lane entirely.
		totem.global_position = Vector3(TOTEM_X, totem.global_position.y, 0.0)
		minion.global_position = Vector3(MINION_X, minion.global_position.y, 0.0)
		_minion_hp = _state.p2.units.hp_at(0)
		return false

	if _frames == 8:
		# CAST 1 -- the PITCH cast: a Fireball, aimed at the CAPTURED opposing HERO (`6-5d/R7`'s resting
		# address), carrying the damage a staging froze.
		_state.p1.start_cast(FIREBALL_CARD, _fireball_ticks, Enums.ModeKind.PITCH,
				1, TargetingService.HERO_INDEX, FIREBALL_DAMAGE)
		_phase = "cast1"
		_phase_frame = _frames
		return false

	if _frames > 8:
		_sample()

	# The quiet tail: nothing is asserted on the tick it happened.
	if _phase == "done" and _frames >= _phase_frame + TAIL:
		return _finish()

	if _frames >= DEADLINE:
		_check(false, "the DEADLINE was reached in phase '%s' -- a phase that never opened has "
				% _phase + "assertions that never ran")
		return _finish()
	return false


## The non-vacuity pass, up front and on the AUTHORED content -- the `test_projectile_flight_live.gd`
## idiom. A closed flag, an unpaired card or an unauthored duration would make every measurement below
## pass for the wrong reason.
func _non_vacuity() -> bool:
	if _state.flags == null or not _state.flags.spells:
		return _fail("the authored FeatureFlags has spells OFF -- no cast can strike")
	if not _state.flags.minions or not _state.flags.totems:
		return _fail("the authored FeatureFlags has minions/totems OFF -- no body to place")
	var fireball: CardEffect = load(FIREBALL_EFFECT_PATH)
	if fireball == null or fireball.cast_seconds <= 0.0 or fireball.travel_budget <= 0.0:
		return _fail("%s authors no positive cast_seconds / travel_budget" % FIREBALL_EFFECT_PATH)
	var bolt: CardEffect = load(BOLT_EFFECT_PATH)
	if bolt == null or bolt.cast_seconds <= 0.0:
		return _fail("%s authors no positive cast_seconds" % BOLT_EFFECT_PATH)
	# The PAIRING the PITCH poke depends on (AC 1): this card's pitch effect really is Fireball, so
	# `start_cast(..., PITCH, ...)` strikes a Fireball rather than resolving nothing.
	var card: CardData = load(FIREBALL_CARD_PATH)
	if card == null or card.pitch_effect == null \
			or card.pitch_effect.effect_id != fireball.effect_id:
		return _fail("%s does not author %s as its pitch effect"
				% [FIREBALL_CARD_PATH, fireball.effect_id])
	_fireball_ticks = TimingWindow.seconds_to_ticks(fireball.cast_seconds)
	_bolt_ticks = TimingWindow.seconds_to_ticks(bolt.cast_seconds)
	var totem_index := _state.balance.kind_index_of(TOTEM_KIND)
	var totem_kind: UnitKindProfile = _state.balance.kind_at(totem_index)
	var attack: UnitAttackProfile = totem_kind.attack_at(0) if totem_kind != null else null
	if attack == null or attack.projectile == null:
		return _fail("authored balance carries no `combat_totem` kind that fires a projectile")
	_range = attack.range
	if _state.balance.kind_index_of(MINION_KIND) < 0:
		return _fail("authored balance carries no `minion` kind")
	# Baseline: nothing is marked before anything is cast.
	_check(not _warning_visible(1) and not _warning_sounding(1),
		"a cast warning is already up on P2 before any cast")
	_check(_cone(0) == null and _cone(1) == null, "a target cone exists before any cast")
	_check(_bolt(0) == null and _bolt(1) == null, "a bolt prop exists before any cast")
	_check(not _root_marker_visible(0) and not _root_marker_visible(1),
		"a root marker is already up before any bolt (AC 28: never without a root)")
	return false


## One tick of observation, and the phase machine. Everything here is a READ except the two pokes and
## the deliberate target moves, so what is measured is what the runner's own push produced.
func _sample() -> void:
	match _phase:
		"cast1":
			_sample_cast1()
		"flight":
			_sample_flight()
		"cast1_aftermath":
			_sample_cast1_aftermath()
		"cast2_wait":
			if _frames >= _phase_frame + 4:
				# CAST 2 -- the BASIC cast, aimed at the CAPTURED MINION (AC 24's unit arm).
				_state.p1.start_cast(BOLT_CARD, _bolt_ticks, Enums.ModeKind.BASIC, 1, 0, 0.0)
				_phase = "cast2"
				_phase_frame = _frames
		"cast2":
			_sample_cast2()
		"cast2_tail":
			# TWO FRAMES OF PROP-ONLY SAMPLING, and they are load-bearing rather than padding. An
			# ARRIVED prop is freed ONE TICK LATE by `_push_cast_presentation` (its own note), and
			# whether this poll or the runner's push runs first within a frame is the engine's
			# business -- so the single frame on which the arrived prop is observable is the falling
			# edge under one ordering and the frame after it under the other. Both are sampled.
			_sample_prop(_unit_actor(1, 0))
			if _frames >= _phase_frame + 2:
				_phase = "cast3_wait"
				_phase_frame = _frames
		"cast3_wait":
			if _frames >= _phase_frame + 4:
				# CAST 3 -- AC 15's non-vacuity twin: a BASIC bolt cast aimed at the HERO this time,
				# not a unit, so it really lands, stuns and roots -- see the vars' own comment.
				_state.p1.start_cast(BOLT_CARD, _bolt_ticks, Enums.ModeKind.BASIC,
						1, TargetingService.HERO_INDEX, 0.0)
				_phase = "cast3"
				_phase_frame = _frames
		"cast3":
			_sample_cast3()
		"cast3_tail":
			_sample_cast3_tail()
		"totem_wait":
			_sample_totem_wait()
		"totem":
			_sample_totem()


## AC 28, THE HERO ARM: today's marker and alarm on the captured hero, for the whole cast, and NO cone
## anywhere -- a hero target must not also grow the placeholder.
func _sample_cast1() -> void:
	if _state.p1.is_casting():
		_cast1_ticks += 1
		if _warning_visible(1):
			_cast1_marker_ticks += 1
		if _warning_sounding(1):
			_cast1_alarm_ticks += 1
		if _cone(0) != null:
			_cast1_cone_seen = true
		if _warning_visible(0) or _warning_sounding(0):
			_cast1_caster_warned = true
		# Smoke fix: the bolt prop must never exist during a Fireball cast.
		if _bolt(0) != null:
			_cast1_bolt_seen = true
		return
	# The falling edge IS the strike tick (`match_runner._push_cast_presentation`'s own reading).
	_check(_state.p1.projectiles.size() == 1,
		"AC 13: the strike placed no Fireball on the caster's board (size %d)"
			% _state.p1.projectiles.size())
	if _state.p1.projectiles.size() != 1:
		_phase = "done"
		return
	var board := _state.p1.projectiles
	_check(board.is_hero_sourced_at(0), "AC 13: the placed shot is not hero-sourced")
	_check([board.target_slot_at(0), board.target_index_at(0)] == [1, TargetingService.HERO_INDEX],
		"AC 13/AC 24: the shot is not addressed at the captured hero")
	_hero_hp_before_landing = _state.p2.hero.get_hp()
	_phase = "flight"
	_phase_frame = _frames


## AC 13 / AC 20 / AC 37: the flight, measured against the shot's OWN state target -- read off the
## board record rather than assumed to be the opposing hero, so the actor and the record are compared
## with each other and not both with this file's arithmetic.
func _sample_flight() -> void:
	var board := _state.p1.projectiles
	var shot := _projectile_actor(0)
	if shot != null and board.is_alive_at(0):
		_flight_ticks += 1
		var gap_to_caster := shot.global_position.distance_to(_p1_hero().global_position)
		if not _shot_seen:
			_shot_seen = true
			# AC 13: IT LEAVES THE CASTER. Measured on the first tick the actor exists, before it has
			# had time to travel, so "launched from the hero" is a position and not an inference.
			_launch_gap = gap_to_caster
		_shot_max_gap = maxf(_shot_max_gap, gap_to_caster)
		var target: Variant = _target_position(board.target_slot_at(0), board.target_index_at(0))
		if target is Vector3:
			var to_target := Vector3((target as Vector3).x - shot.global_position.x, 0.0,
					(target as Vector3).z - shot.global_position.z)
			_target_gap_last = to_target.length()
			if _target_gap_first < 0.0:
				_target_gap_first = _target_gap_last
			if not to_target.is_zero_approx():
				_aim_errors.append(absf(shot.heading.signed_angle_to(
						to_target.normalized(), Vector3.UP)))
		# AC 20 IN REAL PHYSICS: the shot's own hitbox, asked the way `_gather_projectile_facts` asks
		# it. An overlap here IS a fact the runner pushed on this tick.
		var minion := _unit_actor(1, 0)
		if minion != null and _overlaps(shot, minion):
			if not _overlapped_non_target:
				_overlapped_non_target = true
				_minion_hp_at_overlap = _state.p2.units.hp_at(0)
			_overlap_ticks += 1
		elif _overlapped_non_target:
			# ALIVE AFTER the overlap ended, which is "not consumed" measured rather than inferred:
			# a shot the minion had absorbed would be dead here and this counter would stay at 0.
			_alive_ticks_after_overlap += 1
		if _overlapped_non_target:
			_minion_hp_after_overlap = _state.p2.units.hp_at(0)
		# The nudge that makes homing falsifiable, and only for the first stretch (see NUDGE_TICKS).
		if _flight_ticks <= NUDGE_TICKS and _flight_ticks % NUDGE_EVERY == 0:
			_p2_hero().global_position += Vector3(0.0, 0.0, NUDGE_DISTANCE)
		return
	if board.is_alive_at(0):
		return  # the record lives but its actor has not appeared yet
	# The shot has ended: landed on the captured hero, or expired. Which one is the assertion.
	_landed = true
	_hero_hp_after_landing = _state.p2.hero.get_hp()
	_phase = "cast1_aftermath"
	_phase_frame = _frames
	_post_land_ticks = 0


## AC 15, LIVE (operator addition): for at least `POST_LAND_TICKS` after the Fireball lands, neither
## the dizzy nor the stunned clip ever plays on the target hero, no root marker shows, and the state
## side agrees -- `stun_is_bolt` stays false, `action_state` never reads STUNNED, the root window
## never runs. See `_sample_cast3_tail` for this check's non-vacuity twin.
func _sample_cast1_aftermath() -> void:
	_post_land_ticks += 1
	if _dizzy_playing(1):
		_post_land_dizzy_seen = true
	if _stunned_clip_playing(1):
		_post_land_stunned_clip_seen = true
	if _root_marker_visible(1):
		_post_land_root_marker_seen = true
	if _state.p2.hero.stun_is_bolt:
		_post_land_stun_is_bolt_seen = true
	if _state.p2.hero.action_state == HeroState.ActionState.STUNNED:
		_post_land_action_stunned_seen = true
	if _state.p2.root_window.is_running:
		_post_land_root_running_seen = true
	if _post_land_ticks >= POST_LAND_TICKS:
		_phase = "cast2_wait"
		_phase_frame = _frames


## AC 28, THE UNIT ARM: the placeholder cone on the captured MINION, the hero behind it unmarked, and
## the prop flying to the minion. The same hero that WAS marked during cast 1 is the one asserted
## unmarked here, which is what makes both halves each other's non-vacuity.
func _sample_cast2() -> void:
	var minion := _unit_actor(1, 0)
	if _state.p1.is_casting():
		_cast2_ticks += 1
		if _warning_visible(1):
			_cast2_hero_marker_ticks += 1
		if _warning_sounding(1):
			_cast2_hero_alarm_ticks += 1
		var cone := _cone(0)
		if cone != null and minion != null:
			_cone_ticks += 1
			if not cone.visible:
				_cone_hidden_ticks += 1
			if _cone_probe == "":
				_runner.set_debug_layer_visible(false)
				var hidden_off := not cone.visible
				_runner.set_debug_layer_visible(true)
				_cone_probe = "ok" if hidden_off and cone.visible else "hidden_off=%s shown_on=%s" % [hidden_off, cone.visible]
			var want := minion.global_position + Vector3(0.0, TargetConeActor.HOVER_HEIGHT, 0.0)
			if cone.global_position.distance_to(want) > CONE_TOLERANCE:
				_cone_off_target_ticks += 1
		if minion != null:
			_cast2_min_separation = minf(_cast2_min_separation,
					minion.global_position.distance_to(_p2_hero().global_position))
		_sample_prop(minion)
		return
	_sample_prop(minion)
	_phase = "cast2_tail"
	_phase_frame = _frames


## AC 28: where the cast prop is, relative to the CAPTURED minion. Sampled across the falling edge too
## (see the `cast2_tail` phase).
func _sample_prop(minion: Node3D) -> void:
	var prop := _bolt(0)
	if prop == null or minion == null:
		return
	_prop_seen = true
	_prop_min_gap = minf(_prop_min_gap, prop.global_position.distance_to(minion.global_position))
	if prop.has_arrived():
		_prop_arrived = true
	else:
		_prop_inflight_ticks += 1


## AC 15's non-vacuity twin, the cast half: just counts ticks while the poked bolt-on-hero cast runs.
func _sample_cast3() -> void:
	if _state.p1.is_casting():
		_cast3_ticks += 1
		return
	_phase = "cast3_tail"
	_phase_frame = _frames


## AC 15's non-vacuity twin, the landing half: the SAME three reads `_sample_cast1_aftermath` checks
## for absence, here proven able to read true for a real bolt-on-hero stun and root.
##
## AN OBSERVED EDGE, NOT A FRAME COUNT: once `stun_is_bolt` has been seen true and the window it opened
## (the stun, then the root) has run its course, the proof is complete -- no `cast_seconds` /
## `stun_seconds` / `root_seconds` arithmetic to keep in step with a retune.
func _sample_cast3_tail() -> void:
	if _dizzy_playing(1):
		_cast3_dizzy_seen = true
	if _root_marker_visible(1):
		_cast3_root_marker_seen = true
	if _state.p2.hero.stun_is_bolt:
		_cast3_stun_is_bolt_seen = true
	if _cast3_stun_is_bolt_seen and not _state.p2.hero.stun_is_bolt \
			and not _state.p2.root_window.is_running:
		_phase = "totem_wait"
		_phase_frame = _frames


## AC 36's stage: the totem, the minion and P2's hero on one line, the minion BETWEEN the other two and
## the hero inside the totem's authored range -- so the totem's shot has a NON-TARGET body in its path.
##
## LAID OUT FROM THE MINION'S MEASURED POSITION, and only once it has HELD STILL, rather than from
## constants: where a walking body settles is the runner's business (its acquired target and the
## authored `stop_distance` decide it), and a lane computed from a guess would decay between the layout
## and the shot. THE TOTEM IS RE-STOOD here, which is a fixture placement exactly like the one at frame
## 6 -- `4-4/R12`'s "a totem never moves" is a rule about the RUNNER, owned and asserted by
## `test_projectile_flight_live.gd`, and nothing in this file reads the totem's immobility.
func _sample_totem_wait() -> void:
	var totem := _unit_actor(0, 0)
	var minion := _unit_actor(1, 0)
	if totem == null or minion == null or not _state.p2.units.is_alive_at(0):
		return
	if minion.global_position.distance_to(_minion_last_pos) <= 0.02:
		_minion_still += 1
	else:
		_minion_still = 0
	_minion_last_pos = minion.global_position
	if _minion_still < STILL_FRAMES:
		return
	if TOTEM_STANDOFF + HERO_STANDOFF > _range - 0.5:
		_check(false, "AC 36's lane (%.1f m) does not fit the totem's authored range (%.1f m)"
				% [TOTEM_STANDOFF + HERO_STANDOFF, _range])
		_phase = "done"
		_phase_frame = _frames
		return
	var m := minion.global_position
	totem.global_position = Vector3(m.x - TOTEM_STANDOFF, totem.global_position.y, m.z)
	_p2_hero().global_position = Vector3(m.x + HERO_STANDOFF, 1.0, m.z)
	_units_hp_at_totem_phase = _state.p2.units.hp_at(0)
	_p2_hp_at_totem_phase = _state.p2.hero.get_hp()
	_totem_phase_opened = true
	_phase = "totem"
	_phase_frame = _frames


func _sample_totem() -> void:
	var board := _state.p1.projectiles
	# The Fireball is index 0; the totem's shot is whatever the totem appended after it. Identified by
	# `is_hero_sourced_at` being FALSE, which is the same single discriminator the state layer uses.
	if _totem_shot_index < 0:
		for i in board.size():
			if i == 0:
				continue
			if not board.is_hero_sourced_at(i):
				_totem_shot_index = i
				_totem_shot_target_index = board.target_index_at(i)
				break
	elif not _totem_shot_consumed and not board.is_alive_at(_totem_shot_index):
		_totem_shot_consumed = true
		_units_hp_after_totem_shot = _state.p2.units.hp_at(0)
		_p2_hp_after_totem_shot = _state.p2.hero.get_hp()
		_phase = "done"
		_phase_frame = _frames
		return
	if _frames >= _phase_frame + TOTEM_TAIL:
		_phase = "done"
		_phase_frame = _frames


func _finish() -> bool:
	# ---- AC 28, the HERO arm (cast 1)
	_check(_cast1_ticks > 0, "cast 1 was never observed running")
	_check(_cast1_marker_ticks == _cast1_ticks,
		"AC 28: the captured HERO's warning marker was up for %d of %d cast-1 ticks"
			% [_cast1_marker_ticks, _cast1_ticks])
	_check(_cast1_alarm_ticks == _cast1_ticks,
		"AC 28: the captured HERO's alarm played for %d of %d cast-1 ticks"
			% [_cast1_alarm_ticks, _cast1_ticks])
	_check(not _cast1_cone_seen, "AC 28: a placeholder cone was spawned for a HERO-targeted cast")
	_check(not _cast1_caster_warned, "AC 28: the CASTER showed its own warning")

	# ---- AC 13 / AC 20 / AC 37, the flight
	_check(_shot_seen, "no Fireball actor ever appeared for the placed record")
	_check(_launch_gap >= 0.0 and _launch_gap < 1.5,
		"AC 13: the Fireball did not leave the CASTER (first gap %.3f m)" % _launch_gap)
	_check(_shot_max_gap > 5.0,
		"AC 13: the Fireball never travelled away from the caster (max gap %.2f m)" % _shot_max_gap)
	_check(_flight_ticks >= 10,
		"the Fireball was observed in flight for only %d ticks" % _flight_ticks)
	_check(_overlapped_non_target,
		"AC 20 IS VACUOUS WITHOUT THIS: the Fireball never physically overlapped the NON-TARGET "
		+ "minion, so nothing about pass-through was measured")
	_check(_minion_hp_at_overlap >= 0.0 and is_equal_approx(_minion_hp_at_overlap, _minion_hp),
		"AC 20: the non-target minion was already damaged before the pass-through (%.2f of %.2f)"
			% [_minion_hp_at_overlap, _minion_hp])
	_check(_minion_hp_after_overlap < 0.0
			or is_equal_approx(_minion_hp_after_overlap, _minion_hp_at_overlap),
		"AC 20: the non-target minion LOST HP to the Fireball (%.2f -> %.2f over %d overlap ticks)"
			% [_minion_hp_at_overlap, _minion_hp_after_overlap, _overlap_ticks])
	_check(_alive_ticks_after_overlap >= 2,
		"AC 20: the Fireball did not fly ON after the non-target minion -- only %d alive ticks were "
			% _alive_ticks_after_overlap + "seen past the overlap, so it was consumed there")
	_check(_landed, "the Fireball never ended -- neither landed nor expired")
	_check(_hero_hp_after_landing >= 0.0
			and is_equal_approx(_hero_hp_before_landing - _hero_hp_after_landing, FIREBALL_DAMAGE),
		"AC 14: the landing removed %.3f HP from the captured hero, not the carried %.3f"
			% [_hero_hp_before_landing - _hero_hp_after_landing, FIREBALL_DAMAGE])
	# AC 37: the direction-aware half, the `test_projectile_flight_live.gd` measurement verbatim -- an
	# aim error that does not grow and a last third that averages better than the first.
	if _aim_errors.size() >= 6:
		var first := _aim_errors[0]
		var last: float = _aim_errors[_aim_errors.size() - 1]
		var third := _aim_errors.size() / 3
		var early := 0.0
		var late := 0.0
		for i in third:
			early += _aim_errors[i]
			late += _aim_errors[_aim_errors.size() - 1 - i]
		early /= float(third)
		late /= float(third)
		_aim_improved = late < early and last <= first + AIM_TOLERANCE
		_detail += " aim_first=%.4f aim_last=%.4f early=%.4f late=%.4f" % [first, last, early, late]
	else:
		_detail += " aim_samples=%d (too few)" % _aim_errors.size()
	_check(_aim_improved,
		"AC 37: the Fireball's aim error toward its OWN state target did not close (see detail)")
	_check(_target_gap_first > _target_gap_last,
		"AC 18: the Fireball did not close on its state target (%.2f -> %.2f m)"
			% [_target_gap_first, _target_gap_last])

	# ---- Smoke fix (operator finding, 2026-09-28): the bolt prop exists ONLY for a Honed Bolt cast
	_check(not _cast1_bolt_seen,
		"SMOKE FIX: a BoltActor existed during the Fireball cast (cast 1) -- the bolt prop must exist "
		+ "only for a Honed Bolt cast")

	# ---- AC 15, live (operator addition, 2026-09-28): the Fireball landing wrote no stun and no root
	_check(_post_land_ticks >= POST_LAND_TICKS,
		"AC 15 was not sampled for the full post-landing window (%d of %d ticks)"
			% [_post_land_ticks, POST_LAND_TICKS])
	_check(not _post_land_dizzy_seen,
		"AC 15: the dizzy clip played on the target hero after a Fireball landing")
	_check(not _post_land_stunned_clip_seen,
		"AC 15: the stunned clip played on the target hero after a Fireball landing")
	_check(not _post_land_root_marker_seen,
		"AC 15: the root marker showed on the target hero after a Fireball landing")
	_check(not _post_land_stun_is_bolt_seen, "AC 15: a Fireball landing set stun_is_bolt")
	_check(not _post_land_action_stunned_seen, "AC 15: a Fireball landing wrote action_state STUNNED")
	_check(not _post_land_root_running_seen, "AC 15: a Fireball landing armed the root window")
	# ...and the non-vacuity twin: the same three reads really do go true for a real bolt-on-hero stun.
	_check(_cast3_ticks > 0, "cast 3 (bolt-on-hero, AC 15's non-vacuity twin) was never observed running")
	_check(_cast3_dizzy_seen,
		"AC 15 NON-VACUITY: the dizzy clip never played for a real bolt-on-hero stun -- the absence "
		+ "check above could not have failed")
	_check(_cast3_root_marker_seen,
		"AC 15 NON-VACUITY: the root marker never showed for a real bolt-on-hero root")
	_check(_cast3_stun_is_bolt_seen,
		"AC 15 NON-VACUITY: stun_is_bolt never went true for a real bolt-on-hero stun")

	# ---- AC 28, the UNIT arm (cast 2)
	_check(_cast2_ticks > 0, "cast 2 was never observed running")
	_check(_cast2_min_separation >= MIN_SEPARATION,
		"AC 28 would be undecidable: the marked minion came within %.2f m of the opposing hero, so "
			% _cast2_min_separation + "a hero-addressed marker could not be told apart")
	_check(_cone_ticks == _cast2_ticks,
		"AC 28: the placeholder cone was up for %d of %d cast-2 ticks" % [_cone_ticks, _cast2_ticks])
	_check(_cone_hidden_ticks == 0, "P21: the cone was hidden on %d ticks with the debug layer shown" % _cone_hidden_ticks)
	_check(_cone_probe == "ok", "P21: F3 off/on mid-cast did not hide/show the cone (%s)" % _cone_probe)
	_check(_cone_off_target_ticks == 0,
		"AC 28: the cone sat off the MARKED BODY on %d ticks" % _cone_off_target_ticks)
	_check(_cast2_hero_marker_ticks == 0,
		"AC 28: the hero BEHIND the marked minion showed a warning marker on %d ticks"
			% _cast2_hero_marker_ticks)
	_check(_cast2_hero_alarm_ticks == 0,
		"AC 28: the hero BEHIND the marked minion sounded its alarm on %d ticks"
			% _cast2_hero_alarm_ticks)
	_check(_prop_seen, "AC 28: no cast prop was spawned for the minion-targeted cast")
	_check(_prop_inflight_ticks >= 2,
		"AC 28: the prop was never seen in flight (%d ticks)" % _prop_inflight_ticks)
	_check(_prop_arrived, "AC 28: the prop never arrived at the captured minion")
	_check(_prop_min_gap <= PROP_TOLERANCE,
		"AC 28: the prop's closest approach to the CAPTURED MINION was %.3f m -- it flew somewhere "
			% _prop_min_gap + "else (the opposing hero was %.2f m away at its closest)"
			% _cast2_min_separation)

	# ---- AC 36, the totem's shot in the same scene
	_check(_totem_phase_opened, "the totem phase never opened -- AC 36 was not measured live")
	_check(_totem_shot_index > 0, "AC 36: the Combat totem never fired in this scene")
	_check(_totem_shot_target_index == TargetingService.HERO_INDEX,
		"AC 36 IS VACUOUS WITHOUT THIS: the totem's shot was addressed at index %d, not at the HERO, "
			% _totem_shot_target_index + "so the body it hit may simply have been its target")
	_check(_totem_shot_consumed,
		"AC 36: the totem's shot was NOT consumed by the first body it touched -- pass-through "
		+ "reached a unit-fired shot")
	_check(_units_hp_after_totem_shot >= 0.0
			and _units_hp_after_totem_shot < _units_hp_at_totem_phase,
		"AC 36: the non-target body the totem's shot struck lost no HP (%.2f -> %.2f)"
			% [_units_hp_at_totem_phase, _units_hp_after_totem_shot])
	_check(_p2_hp_after_totem_shot >= 0.0
			and is_equal_approx(_p2_hp_after_totem_shot, _p2_hp_at_totem_phase),
		"AC 36: the totem's shot reached its HERO target (%.2f -> %.2f) although a body stood in "
			% [_p2_hp_at_totem_phase, _p2_hp_after_totem_shot] + "the way")

	print("fireball_live: cast1=%d marker=%d alarm=%d cone_in_cast1=%s launch_gap=%.3f "
			% [_cast1_ticks, _cast1_marker_ticks, _cast1_alarm_ticks, _cast1_cone_seen, _launch_gap]
			+ "flight=%d overlap=%d minion_hp=%.2f->%.2f alive_after=%d landed=%s hp=%.2f->%.2f "
			% [_flight_ticks, _overlap_ticks, _minion_hp_at_overlap, _minion_hp_after_overlap,
				_alive_ticks_after_overlap, _landed, _hero_hp_before_landing,
				_hero_hp_after_landing]
			+ "cast2=%d cone=%d off=%d hero_marker=%d sep=%.2f prop_gap=%.3f arrived=%s "
			% [_cast2_ticks, _cone_ticks, _cone_off_target_ticks, _cast2_hero_marker_ticks,
				_cast2_min_separation, _prop_min_gap, _prop_arrived]
			+ "totem_shot=%d target=%d consumed=%s units_hp=%.2f->%.2f p2_hp=%.2f->%.2f "
			% [_totem_shot_index, _totem_shot_target_index, _totem_shot_consumed,
				_units_hp_at_totem_phase, _units_hp_after_totem_shot, _p2_hp_at_totem_phase,
				_p2_hp_after_totem_shot]
			+ "cast1_bolt_seen=%s post_land_dizzy=%s post_land_stunned=%s post_land_root=%s "
			% [_cast1_bolt_seen, _post_land_dizzy_seen, _post_land_stunned_clip_seen,
				_post_land_root_marker_seen]
			+ "cast3=%d cast3_dizzy=%s cast3_root=%s cast3_stun_is_bolt=%s%s"
			% [_cast3_ticks, _cast3_dizzy_seen, _cast3_root_marker_seen, _cast3_stun_is_bolt_seen,
				_detail])
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true


func _fail(message: String) -> bool:
	print(message)
	print("RESULT: FAIL")
	quit(1)
	return false


func _p1_hero() -> HeroActor:
	return _runner._p1_hero as HeroActor


func _p2_hero() -> HeroActor:
	return _runner._p2_hero as HeroActor


## Read off the runner's own arrays, so the test and the runner agree about which node is which record
## rather than searching the tree by type -- the `test_projectile_flight_live.gd` discipline.
func _unit_actor(slot: int, index: int) -> Node3D:
	var actors: Array = _runner._unit_actors[slot]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	return node as Node3D if is_instance_valid(node) else null


func _projectile_actor(index: int) -> ProjectileActor:
	var actors: Array = _runner._projectile_actors[0]
	if index < 0 or index >= actors.size():
		return null
	var node: Node = actors[index]
	return node as ProjectileActor if is_instance_valid(node) else null


func _cone(slot: int) -> TargetConeActor:
	var node: Node = _runner._target_cones[slot]
	return node as TargetConeActor if is_instance_valid(node) else null


func _bolt(slot: int) -> BoltActor:
	var node: Node = _runner._bolts[slot]
	return node as BoltActor if is_instance_valid(node) else null


## Does `shot`'s hitbox really overlap `body` right now? The runner's own gather query, asked of the
## same node -- so an overlap seen here is an overlap the runner pushed a fact for.
func _overlaps(shot: ProjectileActor, body: Node3D) -> bool:
	var hitbox := shot.get_node_or_null("Hitbox") as Area3D
	if hitbox == null:
		return false
	for area: Area3D in hitbox.get_overlapping_areas():
		if area.get_parent() == body:
			return true
	return false


func _target_position(slot: int, index: int) -> Variant:
	if index == TargetingService.HERO_INDEX:
		var hero: HeroActor = _p1_hero() if slot == 0 else _p2_hero()
		return hero.global_position if is_instance_valid(hero) else null
	var unit := _unit_actor(slot, index)
	return unit.global_position if unit != null else null


func _telegraph(slot: int) -> TelegraphController:
	var hero: HeroActor = _p1_hero() if slot == 0 else _p2_hero()
	return hero.telegraph_controller


func _warning_visible(slot: int) -> bool:
	var mesh: MeshInstance3D = _telegraph(slot).get_node_or_null("CastWarning")
	return mesh != null and mesh.visible


func _warning_sounding(slot: int) -> bool:
	var cue: AudioStreamPlayer = _telegraph(slot).get_node_or_null("CueCastWarning")
	return cue != null and cue.playing


## AC 15, live check: `test_cast_presentation_live.gd::_sample()`'s own read path, cited verbatim --
## `assigned_animation`, not `current_animation`, because a held final frame reports an EMPTY
## `current_animation` while `assigned_animation` still names the clip whose frame is being held.
func _hero_clip(slot: int) -> String:
	var hero: HeroActor = _p1_hero() if slot == 0 else _p2_hero()
	return String(hero.animation_controller.animation_player.assigned_animation)


func _dizzy_playing(slot: int) -> bool:
	return _hero_clip(slot) == "dizzy"


func _stunned_clip_playing(slot: int) -> bool:
	return _hero_clip(slot) == "stunned"


## AC 15, live check: `test_cast_presentation_live.gd::_root_marker_visible`'s read path, cited
## verbatim -- the root ring is `TelegraphController`'s `RootMark` mesh.
func _root_marker_visible(slot: int) -> bool:
	var mesh: MeshInstance3D = _telegraph(slot).get_node_or_null("RootMark")
	return mesh != null and mesh.visible
