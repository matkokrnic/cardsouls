extends SceneTree

## Story 3-0c (AC 9), integration: REPLAY MODE SUPPRESSES THE RUNNER'S OWN CONTACT-FACT GATHERING
## and drains RECORDED facts into push_contact, keyed by tick index.
##
## This cannot be decided in the state harness. `_gather_contact_facts` reads
## `actor.hitbox.get_overlapping_areas()` and raw `global_position` deltas (`3-0c/R1`), so the
## claim is about the LIVE runner in the LIVE scene or it is about nothing.
##
## THE PROOF FORM, and what it does and does not cover. "Zero Area3D overlap queries" is not
## directly countable on this engine: a GDScript override of a native method is a PARSE ERROR
## under this project's warnings-as-errors setting (measured), and Godot exposes no per-query
## performance monitor for an Area3D overlap list. So the query is proven absent BY ITS ONLY
## OBSERVABLE CONSEQUENCE — a gathered fact reaching push_contact — in BOTH directions, against
## the SAME physical arrangement:
##
##   [A LIVE] P1 teleported into reach of P2 and swung. The gather runs, facts are pushed, a hit
##     lands, and the runner's own recorder captures the whole stream. This is the non-vacuity
##     half: it establishes that this arrangement genuinely produces overlap-gathered facts.
##   [B REPLAY, OUT OF REACH] The SAME record replayed with P1 teleported 15 units AWAY. No
##     overlap is physically possible — yet the recorded hits still land, identically and in
##     order. The facts came from the record, not from the scene.
##   [C REPLAY, IN REACH, FACT CHANNEL STRIPPED] The same record with its contact channel removed
##     and NOTHING ELSE changed, replayed with P1 back in reach and swinging exactly as in [A].
##     ZERO hits. A runner that had queried the hitbox would have found the same overlap phase [A]
##     found and pushed the same facts.
##
## What [C] does NOT cover: a query whose result is discarded without reaching push_contact.
## Nothing in the codebase does that — `_gather_contact_facts` is the sole caller and pushes
## everything it selects — so the uncovered case is a query that could only waste time, never one
## that could desync a replay.
##
## Run: godot --headless --path . --script res://test/integration/test_replay_contacts.gd

const DEADLINE := 3000
## Long enough for a full swing plus its recovery at any plausible authored window.
const PHASE_FRAMES := 110
const ATTACK_PRESS_FRAME := 6
const REACH := Vector3(0, 0, -1.2)     # P1 behind P2 along +Z, default facing (0,1) -> +Z
const OUT_OF_REACH := Vector3(0, 0, -15.0)

var _frames := 0
var _phase := "live"
var _phase_start := 0
var _scene: Node
var _runner: Node3D

var _record: IntentRecorder
var _stripped: IntentRecorder
var _hits: Array = []
var _attacking := 0
var _live_hits: Array = []
var _far_hits: Array = []
var _stripped_hits: Array = []
var _live_attacking := 0
var _stripped_attacking := 0
var _recorded_facts := 0
var _recorded_ticks := 0
var _failures: Array[String] = []


## The scene is built on the first PHYSICS FRAME, not in _initialize(): add_child() runs _ready()
## synchronously only once the tree is processing, and the runner's connect_* seams read
## _match_state, which _ready() is what creates.
func _initialize() -> void:
	pass


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures.append(label)


func _begin(record: IntentRecorder, offset: Vector3) -> void:
	var scene: Node = load("res://src/main/main.tscn").instantiate()
	if record != null:
		# Story 3-0c (AC 9): assigned BEFORE the node enters the tree, so _ready() builds the whole
		# match from the record — seed, reload event #0, flags and content — instead of from the
		# live services, and both slots are driven by ReplayControllers.
		scene.replay_record = record
	root.add_child(scene)
	_scene = scene
	_runner = scene as Node3D
	var p1: Node3D = scene.get_node("P1Hero")
	var p2: Node3D = scene.get_node("P2Hero")
	p1.position = p2.position + offset
	_hits = []
	_attacking = 0
	_runner.connect_hit_landed(
		func(attacker: int, target: int, damage: float, target_hp: float) -> void:
			_hits.append([attacker, target, snappedf(damage, 0.0001), snappedf(target_hp, 0.0001)]))
	_runner.connect_hero_action_state_changed(0,
		func(_prev: HeroState.ActionState, cur: HeroState.ActionState) -> void:
			if cur == HeroState.ActionState.ATTACKING:
				_attacking += 1)
	_phase_start = _frames


func _teardown() -> void:
	root.remove_child(_scene)
	_scene.queue_free()
	_scene = null
	_runner = null


## A copy of `src` with the CONTACT channel — and nothing else — removed. Built through the public
## capture API, so the stripped record is a genuine record rather than a mutated internal.
func _without_contacts(src: IntentRecorder) -> IntentRecorder:
	var out := IntentRecorder.new()
	out.capture_seed(src.replay_seed())
	out.capture_apply_balance(src.replay_balance_config(0))
	out.capture_inject_feature_flags(src.replay_feature_flags())
	out.capture_inject_deck(src.replay_deck_contents())
	out.capture_inject_card_costs(src.replay_card_costs())
	# Story 4-1 (`4-1/R1`): the third content channel is copied too — this helper strips the
	# CONTACT channel "and nothing else", so a channel silently dropped here would make the
	# resulting record malformed rather than merely contact-less.
	out.capture_inject_card_effects(src.replay_card_effects())
	# Story 5-2 (`5-2/R1`): and the FOURTH, for the identical reason -- this helper strips the
	# CONTACT channel "and nothing else".
	out.capture_inject_card_colors(src.replay_card_colors())
	for t in range(1, src.tick_count() + 1):
		for push: Array in src.camera_pushes_at(t):
			out.capture_set_camera_basis(int(push[0]), push[1] as Basis)
		out.capture_advance(src.intents_at(t))
	return out


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames >= DEADLINE:
		_failures.append("deadline reached in phase %s" % _phase)
		_finish()
		return false
	if _frames == 1:
		_begin(null, REACH)
		return false
	var elapsed := _frames - _phase_start
	# The live phase is the only one that touches hardware: the replay phases are driven entirely
	# by ReplayControllers, so a key press there would reach nothing.
	if _phase == "live":
		if elapsed == ATTACK_PRESS_FRAME:
			Input.action_press(&"p1_attack")
		elif elapsed == ATTACK_PRESS_FRAME + 2:
			Input.action_release(&"p1_attack")
	if elapsed < PHASE_FRAMES:
		return false

	match _phase:
		"live":
			_record = _runner.recorded_stream()
			_live_hits = _hits.duplicate()
			_live_attacking = _attacking
			_recorded_ticks = _record.tick_count()
			for t in range(1, _recorded_ticks + 1):
				_recorded_facts += _record.contacts_at(t).size()
			_teardown()
			_phase = "far"
			_begin(_record, OUT_OF_REACH)
		"far":
			_far_hits = _hits.duplicate()
			_teardown()
			_stripped = _without_contacts(_record)
			_phase = "stripped"
			_begin(_stripped, REACH)
		"stripped":
			_stripped_hits = _hits.duplicate()
			_stripped_attacking = _attacking
			_teardown()
			_evaluate()
	return false


func _evaluate() -> void:
	# [A] non-vacuity: the live arrangement genuinely gathered facts through an Area3D overlap
	# query and landed a hit. Everything below is a comparison against this.
	_check(_live_attacking >= 1, "live phase: P1 actually swung (got %d ATTACKING transitions)" % _live_attacking)
	_check(_recorded_facts > 0, "live phase: the gather produced facts and the recorder captured them (got %d)" % _recorded_facts)
	_check(_live_hits.size() >= 1, "live phase: a gathered fact was CONFIRMED as a hit (got %d)" % _live_hits.size())
	_check(_recorded_ticks >= PHASE_FRAMES - 2,
		"the record carries a tick per ticking frame (got %d over %d frames)" % [_recorded_ticks, PHASE_FRAMES])
	# [B] the facts reaching push_contact are exactly the RECORDED ones, in recorded tick order —
	# proven with the heroes 15 units apart, where no overlap query could produce them.
	_check(_far_hits == _live_hits,
		"replay OUT OF REACH reproduced the recorded hits exactly and in order: got %s, recorded %s"
				% [str(_far_hits), str(_live_hits)])
	# [C] the runner performed NO overlap query: the identical in-reach arrangement, with P1
	# swinging exactly as in [A], produced nothing once the fact channel was stripped.
	_check(_stripped_attacking == _live_attacking,
		"stripped phase: P1 swung the same number of times as live (%d vs %d) — the arrangement "
		% [_stripped_attacking, _live_attacking] + "really is the one that gathered facts in [A]")
	_check(_stripped_hits.is_empty(),
		"replay IN REACH with the fact channel stripped produced ZERO hits — the runner never "
		+ "queried the hitbox: got %s" % str(_stripped_hits))
	_finish()


func _finish() -> void:
	print("replay contacts: recorded_ticks=%d recorded_facts=%d live_hits=%d far_hits=%d stripped_hits=%d swings=%d/%d" % [
		_recorded_ticks, _recorded_facts, _live_hits.size(), _far_hits.size(),
		_stripped_hits.size(), _live_attacking, _stripped_attacking])
	for f in _failures:
		print("FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
