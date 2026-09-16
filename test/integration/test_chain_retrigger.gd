extends SceneTree

## Story 3-0b (Pass 3b) machine contract: EVERY attack swing plays its own clip, restarted
## from the beginning — including the second and third swings of a chain.
##
## THE DEFECT THIS PINS. attack_chain_length = 3 with a 30-tick chain window deliberately
## lets a new swing begin before the previous one finishes, and the state layer is correct
## about it: chain_attack() explicitly re-emits ATTACKING -> ATTACKING on the action-state
## seam precisely so presentation learns of a swing that changes no state (asserted
## state-side by test_action_state.gd's queued-signal sequence, which pins [atk, atk]).
## AnimationController then dropped it TWICE over: its selector switched only when the clip
## NAME changed (a chained swing's name is already `attack`), and even without that guard
## AnimationPlayer.play() is a no-op on playback position when the named clip is already
## current and still playing. Live result: three swings, three hit flashes, two animations,
## the missing one in the middle.
##
## WHY NOTHING ELSE COULD CATCH IT: test_rig_clips.gd reads the clip INVENTORY off the packed
## scene and test_clip_timing.gd reads clip LENGTHS and track data — both are assertions about
## authored data at rest. No test in the suite drove the runtime SELECTION path, so nothing
## ever asked "which clip is playing right now, and did it restart". This file does.
##
## The whole sequence runs inside ONE _physics_process call so the tree's own per-frame
## animation stepping cannot advance the player between an act and its assertion; advance()
## is the only thing moving playback here.
##
## Run: godot --headless --path . --script res://test/integration/test_chain_retrigger.gd

## Playback position counts as "restarted" below this. advance() is exact, so this is drift
## detection rather than slack.
const AT_START_EPS := 0.0001

## How far into the clip the test advances before chaining. Must be strictly inside the clip
## (the defect only bites while the previous swing is STILL PLAYING — once a non-looping clip
## ends, current_animation empties and even the old name-guarded selector retriggered, which
## is exactly why the live bug skipped the middle swing and not the last one).
const MID_CLIP := 0.30

## Story 6-7b: the fixture walk/run pair the locomotion push now carries (see the push below).
const FIXTURE_WALK_SPEED := 2.0
const FIXTURE_RUN_SPEED := 6.0

var _hero: Node3D
var _failures: Array[String] = []
var _frames := 0


func _initialize() -> void:
	_hero = load("res://src/actors/hero/hero.tscn").instantiate()
	root.add_child(_hero)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	# AnimationController resolves its player in _ready, which needs the tree to be live.
	if _frames < 2:
		return false

	var ctl: AnimationController = _hero.get_node(^"AnimationController")
	var ap: AnimationPlayer = _hero.get_node(^"Mesh/Paladin/AnimationPlayer")
	var attacking := HeroState.ActionState.ATTACKING
	var idle := HeroState.ActionState.IDLE
	var clip_len: float = ap.get_animation(&"attack").length

	_check(MID_CLIP < clip_len,
		"test setup broken: MID_CLIP %.4f is not inside the attack clip (%.4f)" % [MID_CLIP, clip_len])

	# --- Swing 1: a fresh attack from IDLE. The case that always worked. ---
	ctl.on_action_state_changed(idle, attacking)
	_check(ap.current_animation == &"attack",
		"swing 1 did not select the attack clip (current='%s')" % ap.current_animation)
	_check(ap.current_animation_position <= AT_START_EPS,
		"swing 1 did not start at 0 (pos=%.4f)" % ap.current_animation_position)

	# --- Swing 2: the CHAIN. Same state in, same state out, clip still playing. ---
	ap.advance(MID_CLIP)
	_check(absf(ap.current_animation_position - MID_CLIP) <= AT_START_EPS,
		"setup: expected playback at %.4f, got %.4f" % [MID_CLIP, ap.current_animation_position])
	ctl.on_action_state_changed(attacking, attacking)
	_check(ap.current_animation == &"attack",
		"chained swing left clip '%s' selected instead of attack" % ap.current_animation)
	_check(ap.current_animation_position <= AT_START_EPS,
		"CHAINED SWING DID NOT RETRIGGER: playback stayed at %.4f instead of restarting at 0"
			% ap.current_animation_position)

	# --- Swing 3: chain again, this time from a different point in the clip. ---
	ap.advance(MID_CLIP * 0.5)
	ctl.on_action_state_changed(attacking, attacking)
	_check(ap.current_animation_position <= AT_START_EPS,
		"third swing did not retrigger: playback stayed at %.4f" % ap.current_animation_position)

	# --- The locomotion push must STAY idempotent. ---
	# This is the reason the name guard existed at all: on_locomotion is polled every tick
	# from HeroActor.drive(), so if the fix had been "always restart" applied to BOTH paths,
	# `run` would reset to frame 0 sixty times a second and never visibly animate. Pinning it
	# here stops a later simplification from collapsing the evented and polled paths together.
	#
	# Story 5-0a widened the push from a scalar speed to (velocity, facing). The argument below
	# is the same case this always asserted -- moving FORWARD along facing, which still selects
	# `run` -- restated in the new payload; the idempotency claim is untouched by that widening,
	# and matters MORE now that the polled path also carries a crossfade (an unguarded play()
	# every tick would restart the blend every tick and never finish it).
	#
	# Story 6-7b widened it again by the authored walk/run pair (AC 4). The pair here is a fixture
	# (the shipped 2.0/6.0), chosen so 5.0 still sits above its midpoint and still selects `run`:
	# this file pins idempotency, not the gait split (test_hero_clip_selection.gd owns that).
	ctl.on_action_state_changed(attacking, idle)
	ctl.on_locomotion(Vector3(0.0, 0.0, 5.0), Vector2(0.0, 1.0), FIXTURE_WALK_SPEED, FIXTURE_RUN_SPEED)
	_check(ap.current_animation == &"run",
		"locomotion push did not select run (current='%s')" % ap.current_animation)
	ap.advance(MID_CLIP)
	var before: float = ap.current_animation_position
	ctl.on_locomotion(Vector3(0.0, 0.0, 5.0), Vector2(0.0, 1.0), FIXTURE_WALK_SPEED, FIXTURE_RUN_SPEED)
	_check(absf(ap.current_animation_position - before) <= AT_START_EPS,
		"repeated locomotion push RESTARTED run (%.4f -> %.4f); the polled path must be idempotent"
			% [before, ap.current_animation_position])

	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("attack clip length=%.4f s; chained at %.4f s into it" % [clip_len, MID_CLIP])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
