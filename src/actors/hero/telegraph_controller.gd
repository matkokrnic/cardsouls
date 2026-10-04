class_name TelegraphController
extends Node3D

## D7 cues layer (story 1-10): per-hero READ-ONLY presentation controller — it consumes
## queued state signals and drives telegraph shape + sound; it never calls a state mutator
## and never decides an outcome (dependency direction: visuals -> state, always). The
## runner wires every subscription through the four connect seams plus EventBus.round_ended
## — signal payloads only, never a state handle. Match-level payloads (hit_landed,
## deflect_landed, round_ended) arrive with THIS hero's slot BOUND as the trailing
## argument at wiring time, so the controller needs no identity of its own.
##
## NO _physics_process here (INVARIANT F1 — the scan covers all of src/); presentation
## timing rides tweens and the AudioStreamPlayer children (on the CombatCues bus, D7).
##
## Gate ruling 1-10/R1: the ActionState -> TelegraphProfile mapping lives HERE, exported,
## presentation-side — no state object ever references a TelegraphProfile. The profile's
## shape_id / sting_id name this node's children (Shapes/<shape_id>, <sting_id> player),
## so swapping a cue is a data edit, not a code edit.

@export var attack_profile: TelegraphProfile
@export var block_profile: TelegraphProfile
@export var roll_profile: TelegraphProfile

## Story 5-3 (AC 10): the CHARGING seat, colour-keyed rather than ActionState-keyed since all
## three share the one ActionState. Kept as three named exports rather than a typed array so
## each stays independently visible/re-orderable in the inspector, matching the three fields
## directly above.
@export var charge_red_profile: TelegraphProfile
@export var charge_blue_profile: TelegraphProfile
@export var charge_green_profile: TelegraphProfile

@onready var _cue_deflect: AudioStreamPlayer = $CueDeflect
@onready var _cue_hit: AudioStreamPlayer = $CueHit
@onready var _cue_reject: AudioStreamPlayer = $CueReject
@onready var _cue_round_end: AudioStreamPlayer = $CueRoundEnd
@onready var _cue_cast_success: AudioStreamPlayer = $CueCastSuccess
@onready var _spark: MeshInstance3D = $DeflectSpark
@onready var _hit_flash: MeshInstance3D = $HitFlash
## Story 5-4 (AC 17): the earn cue's shape. A SIBLING of HitFlash, deliberately NOT a child of
## $Shapes -- `on_action_state_changed` hides every child of $Shapes on EVERY transition, and the
## landing queues `set_action_state(IDLE)` in the SAME drain as the orb grant, so an OrbFlash under
## $Shapes would be switched off in the same frame it was lit. The one-shot cues (DeflectSpark,
## HitFlash) all sit outside $Shapes for exactly this reason; this joins them.
@onready var _orb_flash: MeshInstance3D = $OrbFlash
## Story 6-5c (AC 26): the TARGET-SIDE cast warning -- a held marker and a looping sound, both
## anchored on the hero being cast AT rather than on the caster, which is the whole of AC 26 ("so it
## can time the roll with the caster off-screen"). SIBLINGS of HitFlash for `OrbFlash`'s stated
## reason: `on_action_state_changed` hides every child of `$Shapes` on EVERY transition, and a target
## rolling, blocking or swinging during the cast transitions constantly -- a warning under `$Shapes`
## would blink out on the first press the target made.
@onready var _cast_warning: MeshInstance3D = $CastWarning
@onready var _cue_cast_warning: AudioStreamPlayer = $CueCastWarning
## Story 6-5c (AC 28): the root marker at the hero's FEET, held for the root and nothing else.
@onready var _root_mark: MeshInstance3D = $RootMark
## Story 6-5f (AC 26) shipped a violet COUNTERSPELL placeholder sign and sound stub here (`CounterSign`,
## `CueCounter`). Story 7-1 (AC 19) RETIRES BOTH: the blue rune circle on both heroes and the `counter` sound are
## `EffectPresenter.show_counterspell`'s, driven from the same `counterspell_resolved` connection.

## Story 5-5 (AC 13): the deflect spark's ORIGINAL hue, hoisted to a constant because it is now
## applied from TWO places -- `_ready` and, as the fallback for a colour-less parry, the widened
## `on_deflect_landed`. The value is `1-10`'s verbatim; hoisting it is what keeps a melee parry's
## cue byte-identical to what it renders today rather than approximately so.
const DEFAULT_SPARK_COLOR := Color(1.0, 0.95, 0.6, 1.0)

## Story 6-5c (AC 26/AC 28): the two new cues' hues. Amber for the incoming-cast alarm (a warning
## colour no existing cue uses) and the card's own BLUE, half-transparent, for the root ring on the
## ground. Constants here beside the spark's, not authored `TelegraphProfile`s: a profile exists to
## let one shape stand in for several colours, and neither of these ever changes colour.
const CAST_WARNING_COLOR := Color(1.0, 0.65, 0.1, 1.0)
const ROOT_MARK_COLOR := Color(0.35, 0.6, 1.0, 0.5)

## Story 7-1 (AC 18): THE REFINED CAST WARNING -- the marker now PULSES while it is held (scale between 1.0 and
## this, every `CAST_WARNING_PULSE_SECONDS`), so the alarm reads as live rather than as a static prop. Feel knobs
## beside the warning's hue; the marker, its alarm and its timing are otherwise exactly `6-5c`'s.
const CAST_WARNING_PULSE_SCALE := 1.35
const CAST_WARNING_PULSE_SECONDS := 0.25

var _profiles: Dictionary[HeroState.ActionState, TelegraphProfile] = {}
## Story 5-3 (AC 10): colour (Enums.CardColor int) -> the CHARGING-only profile. Separate from
## `_profiles` because the ActionState -> profile map is 1:1; CHARGING is 1:3, keyed by a value
## the transition signal itself does not carry (see AnimationController's twin dict + the
## match_runner read path, AC 9's analogue for AC 10).
var _charge_profiles: Dictionary[int, TelegraphProfile] = {}
var _shapes: Dictionary[StringName, MeshInstance3D] = {}
var _stings: Dictionary[StringName, AudioStreamPlayer] = {}
var _spark_tween: Tween
var _flash_tween: Tween
var _orb_flash_tween: Tween
var _cast_warning_tween: Tween
## Story 5-4 (AC 16/AC 17): the LAST orb triple this controller was told about, indexed by
## `Enums.CardColor`. EMPTY means "the priming emission has not arrived yet" -- see
## on_orbs_changed for why that distinction is the whole of AC 16.
var _orb_counts: Array[int] = []


func _ready() -> void:
	_profiles = {
		HeroState.ActionState.ATTACKING: attack_profile,
		HeroState.ActionState.BLOCKING: block_profile,
		HeroState.ActionState.ROLLING: roll_profile,
	}
	_charge_profiles = {
		Enums.CardColor.RED: charge_red_profile,
		Enums.CardColor.BLUE: charge_blue_profile,
		Enums.CardColor.GREEN: charge_green_profile,
	}
	for child in $Shapes.get_children():
		if child is MeshInstance3D:
			_shapes[StringName(child.name)] = child
	for child in get_children():
		if child is AudioStreamPlayer:
			_stings[StringName(child.name)] = child
	# Telegraph = shape + sound, never hue alone — the tint is the profile's color on a
	# distinct primitive per action. Materials are built here per-instance (unshaded so
	# the cue reads at split-screen distance; no shared sub-resource, so the two heroes
	# can never cross-tint).
	for profile: TelegraphProfile in _profiles.values():
		if profile == null:
			continue
		var shape: MeshInstance3D = _shapes.get(profile.shape_id)
		if shape != null:
			shape.material_override = _flat_material(profile.color)
	_spark.material_override = _flat_material(DEFAULT_SPARK_COLOR)
	var flash := _flat_material(Color(1.0, 0.1, 0.1, 0.4))
	flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_flash.material_override = flash
	# The orb flash is tinted PER EVENT, not in _ready: like ChargeMarker it is one physical node
	# standing in for three colours, so its material is (re)applied at each dispatch from the same
	# authored TelegraphProfile colour the charge telegraph used. No fourth colour vocabulary ships.
	_orb_flash.visible = false
	# Story 6-5c (AC 26/AC 28): both new cues rest HIDDEN and are tinted once here, from this file's
	# own flat-material helper -- neither stands in for several colours, so neither needs the
	# per-dispatch re-tint ChargeMarker and OrbFlash take. The warning is the alarm hue (amber), the
	# root marker the card's own BLUE, so a target can tell "something is coming" from "I am rooted"
	# at a glance.
	_cast_warning.material_override = _flat_material(CAST_WARNING_COLOR)
	_cast_warning.visible = false
	var root_material := _flat_material(ROOT_MARK_COLOR)
	root_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_root_mark.material_override = root_material
	_root_mark.visible = false


## Story 6-5c (AC 26): START the target-side cast warning -- pushed by the runner on the rising edge
## of the CASTER's cast window, onto the TARGET's own controller. Marker AND sound together, because
## AC 26 requires both and a cue that can be half-wired is a cue that ships half-wired.
##
## THE SOUND LOOPS (`tools/gen_cast_warning_audio.gd`) rather than being a one-shot, so it covers the
## whole cast at any authored `cast_seconds` without this file learning the duration.
func on_cast_warning_started() -> void:
	_cast_warning.visible = true
	_cue_cast_warning.play()
	if _cast_warning_tween != null:
		_cast_warning_tween.kill()
	_cast_warning.scale = Vector3.ONE
	_cast_warning_tween = create_tween().set_loops()
	_cast_warning_tween.tween_property(_cast_warning, "scale", Vector3.ONE * CAST_WARNING_PULSE_SCALE,
			CAST_WARNING_PULSE_SECONDS)
	_cast_warning_tween.tween_property(_cast_warning, "scale", Vector3.ONE, CAST_WARNING_PULSE_SECONDS)


## Story 6-5c (AC 26): END it -- on the strike tick or on an interrupt, whichever the state layer
## reached. Idempotent: the runner pushes the falling edge once, but a stop on a stopped player and a
## hide on a hidden mesh are both no-ops, so a re-push can never leave the alarm running.
func on_cast_warning_ended() -> void:
	_cast_warning.visible = false
	_cue_cast_warning.stop()
	if _cast_warning_tween != null:
		_cast_warning_tween.kill()
		_cast_warning_tween = null
	_cast_warning.scale = Vector3.ONE


## Story 6-5c (AC 28): THE ROOT MARKER at this hero's feet, pushed every tick from the runner's read
## of the `root` snapshot key. A plain visibility push rather than an edge pair, deliberately: the
## root's end is an expiry, a reset or a death, and a level-triggered push cannot leave a marker
## stranded on a hero whose root ended by a path nobody remembered to push a falling edge for.
func set_root_marker(rooted: bool) -> void:
	_root_mark.visible = rooted


## Seam callback (connect_hero_action_state_changed): show the entered action's telegraph
## shape and fire its sting. A chain re-emits ATTACKING -> ATTACKING, so every swing
## re-stings; exits to unmapped states (IDLE, DEAD) clear the shape.
##
## `charge_color` (story 5-3, AC 10): the ONLY state fed to this seam beyond what
## `action_state_changed` itself carries — read by the caller (match_runner, AC 9's read
## path) at the transition instant and forwarded here as a third argument, never stored. A
## default of `PlayerState.NO_TELEGRAPH_COLOR` keeps every OTHER caller of this seam (there is
## exactly one today) unaffected — CHARGING is the only branch that ever consults it.
func on_action_state_changed(_previous: HeroState.ActionState, current: HeroState.ActionState,
		charge_color: int = PlayerState.NO_TELEGRAPH_COLOR) -> void:
	for shape: MeshInstance3D in _shapes.values():
		shape.visible = false

	if current == HeroState.ActionState.CHARGING:
		var charge_profile: TelegraphProfile = _charge_profiles.get(charge_color)
		if charge_profile == null:
			return
		# Unlike attack/block/roll (tinted once in _ready), the charge shape is ONE shared
		# node standing in for three colours, so its material is (re)applied every dispatch.
		var charge_shape: MeshInstance3D = _shapes.get(charge_profile.shape_id)
		if charge_shape != null:
			charge_shape.material_override = _flat_material(charge_profile.color)
			charge_shape.visible = true
		var charge_sting: AudioStreamPlayer = _stings.get(charge_profile.sting_id)
		if charge_sting != null:
			charge_sting.play()
		return

	var profile: TelegraphProfile = _profiles.get(current)
	if profile == null:
		return
	var shape: MeshInstance3D = _shapes.get(profile.shape_id)
	if shape != null:
		shape.visible = true
	var sting: AudioStreamPlayer = _stings.get(profile.sting_id)
	if sting != null:
		sting.play()


## Seam callback (5-3 AC 13): S5's success-cue half. Connected DIRECTLY to the existing,
## previously-unwired `MatchState.card_cast_resolved` signal by match_runner (a plain connect,
## not a new `connect_*` wrapper — `test_runner_observation_seams_are_exactly_ten` pins the
## observation-seam family, which stood at eight when this line shipped, nine since 5-4 AC 15, ten
## since 6-3b AC 1; THIS connection adds none of them). A
## one-shot cue at CAST RESOLUTION, distinct from the ongoing CHARGING sting above.
func on_card_cast_resolved() -> void:
	_cue_cast_success.play()


## Seam callback (connect_orbs_changed, story 5-4 AC 17) -- the NINTH seam's cue consumer, bound to
## this hero's own slot at wiring. A ONE-SHOT above-head flash in the spent colour, on the HitFlash
## idiom below (show, kill any running tween, hold briefly, hide) and deliberately NOT on the
## ChargeMarker toggle-on-state-entry idiom above: earning an orb is an EVENT, not an ongoing state.
## It is a WORLD-SPACE cue on the attacker's own hero actor, so both split-screen viewports show it,
## exactly as ChargeMarker already is.
##
## THE PRIMING EMISSION IS SWALLOWED, AND THAT IS THIS FUNCTION'S LOAD-BEARING HALF (AC 16). The seam
## PRIMES ON CONNECT with the resting (0,0,0) count at match start. A cue derived naively as "fires
## on increase" against an unset previous triple would compare against implicit zeroes and misfire on
## the priming call itself -- every hero flashing at match start, before anything was earned. The
## EMPTY `_orb_counts` is the guard: the first call RECORDS and returns, and only a later call can
## flash. Pinned by test/integration/test_orb_cue_live.gd, which drives it RED by removing this guard.
##
## ONLY AN INCREASE FIRES. The round-boundary reset drops all three counts to zero through this same
## channel; a decrease and a no-change are both silent, so a reset is not an earn.
func on_orbs_changed(red: int, blue: int, green: int) -> void:
	var counts: Array[int] = [red, blue, green]
	if _orb_counts.is_empty():
		_orb_counts = counts
		return
	var earned := -1
	for i in counts.size():
		if counts[i] > _orb_counts[i]:
			earned = i
			break
	_orb_counts = counts
	if earned == -1:
		return
	# The colour vocabulary is the one already authored for the charge telegraph, read back off the
	# same profiles -- so the orb a player earns flashes in the same hue the chargeup they landed
	# was telegraphed in, with no second colour table to drift from it.
	var profile: TelegraphProfile = _charge_profiles.get(earned)
	if profile == null:
		return
	_orb_flash.material_override = _flat_material(profile.color)
	_orb_flash.visible = true
	if _orb_flash_tween != null:
		_orb_flash_tween.kill()
	_orb_flash_tween = create_tween()
	_orb_flash_tween.tween_interval(0.25)
	_orb_flash_tween.tween_callback(func() -> void: _orb_flash.visible = false)


## Seam callback (connect_hero_action_rejected): loss legibility — a press the state
## refused (E1: the stamina-gated roll, and degraded block entry per R-D1) gets an
## audible refusal instead of silence.
func on_action_rejected(_action: StringName, _reason: StringName) -> void:
	_cue_reject.play()


## Seam callback (connect_hit_landed, slot bound at wiring): hit REACTION on the hero
## that was hit — thud + red body flash, so taking damage is legible on the defender,
## not only as the attacker's number.
func on_hit_landed(_attacker_slot: int, target_slot: int, _damage: float, _target_hp: float, my_slot: int) -> void:
	if target_slot != my_slot:
		return
	_cue_hit.play()
	_hit_flash.visible = true
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.12)
	_flash_tween.tween_callback(func() -> void: _hit_flash.visible = false)


## Seam callback (connect_deflect_landed, slot bound at wiring): the story's
## FIRST-PRIORITY cue (1-8 finding: the parry was observable only as the absence of a
## number) — bright spark + metallic sting on the DEFLECTING hero.
##
## STORY 5-5 (AC 13): the payload gains a THIRD argument, the ANSWERED COLOUR, and this callback
## widens with it (`my_slot` stays the bound trailing argument). The spark is TINTED to that colour
## when it is not the sentinel -- a `5-5` colour-matched negation of an unblockable. An ORDINARY
## MELEE PARRY passes `NO_TELEGRAPH_COLOR` and keeps today's untinted cue EXACTLY as it renders now:
## the widening is additive and no existing consumer's observable behaviour changes.
##
## THE TINT ANSWERS THE PRIVACY OBJECTION RATHER THAN AVOIDING IT. The negation ALREADY reveals the
## answered colour deductively -- only a matching colour negates, so the attacker learns it the
## instant the attack vanishes, tint or no tint. What the tint stops is the cue LYING that an
## ordinary, colour-blind parry happened.
##
## THE COLOUR VOCABULARY IS THE AUTHORED `TelegraphProfile` ONE, reused from `_charge_profiles` --
## the same map the charge telegraph and the orb flash already read. No fourth colour vocabulary
## ships, and an unknown colour falls back to the default spark rather than inventing a hue.
func on_deflect_landed(_attacker_slot: int, target_slot: int, defense_color: int,
		my_slot: int) -> void:
	if target_slot != my_slot:
		return
	var profile: TelegraphProfile = _charge_profiles.get(defense_color)
	_spark.material_override = _flat_material(profile.color) if profile != null \
			else _flat_material(DEFAULT_SPARK_COLOR)
	_cue_deflect.play()
	_spark.visible = true
	_spark.scale = Vector3.ONE * 0.4
	if _spark_tween != null:
		_spark_tween.kill()
	_spark_tween = create_tween()
	_spark_tween.tween_property(_spark, "scale", Vector3.ONE * 1.6, 0.18)
	_spark_tween.tween_callback(func() -> void: _spark.visible = false)


## EventBus.round_ended (slot bound at wiring): the defeat cue plays once, anchored on
## the LOSING hero's controller so the two per-hero controllers never double it.
func on_round_ended(loser_index: int, my_slot: int) -> void:
	if loser_index != my_slot:
		return
	_cue_round_end.play()


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat
