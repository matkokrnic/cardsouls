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

@onready var _cue_deflect: AudioStreamPlayer = $CueDeflect
@onready var _cue_hit: AudioStreamPlayer = $CueHit
@onready var _cue_reject: AudioStreamPlayer = $CueReject
@onready var _cue_round_end: AudioStreamPlayer = $CueRoundEnd
@onready var _spark: MeshInstance3D = $DeflectSpark
@onready var _hit_flash: MeshInstance3D = $HitFlash

var _profiles: Dictionary[HeroState.ActionState, TelegraphProfile] = {}
var _shapes: Dictionary[StringName, MeshInstance3D] = {}
var _stings: Dictionary[StringName, AudioStreamPlayer] = {}
var _spark_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	_profiles = {
		HeroState.ActionState.ATTACKING: attack_profile,
		HeroState.ActionState.BLOCKING: block_profile,
		HeroState.ActionState.ROLLING: roll_profile,
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
	_spark.material_override = _flat_material(Color(1.0, 0.95, 0.6, 1.0))
	var flash := _flat_material(Color(1.0, 0.1, 0.1, 0.4))
	flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_flash.material_override = flash


## Seam callback (connect_hero_action_state_changed): show the entered action's telegraph
## shape and fire its sting. A chain re-emits ATTACKING -> ATTACKING, so every swing
## re-stings; exits to unmapped states (IDLE, DEAD) clear the shape.
func on_action_state_changed(_previous: HeroState.ActionState, current: HeroState.ActionState) -> void:
	for shape: MeshInstance3D in _shapes.values():
		shape.visible = false
	var profile: TelegraphProfile = _profiles.get(current)
	if profile == null:
		return
	var shape: MeshInstance3D = _shapes.get(profile.shape_id)
	if shape != null:
		shape.visible = true
	var sting: AudioStreamPlayer = _stings.get(profile.sting_id)
	if sting != null:
		sting.play()


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
func on_deflect_landed(_attacker_slot: int, target_slot: int, my_slot: int) -> void:
	if target_slot != my_slot:
		return
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
