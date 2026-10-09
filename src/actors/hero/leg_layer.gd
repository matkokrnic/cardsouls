class_name LegLayer
extends SkeletonModifier3D

## Story 7-2 (AC 1-8, Task 1.1): THE LOWER-BODY LAYER of the upper/lower split -- presentation only, hero-local.
##
## THE MECHANISM, AND WHY THIS ONE. There is no AnimationTree anywhere in `src/` and the whole of
## `AnimationController` drives ONE `AnimationPlayer` with play/seek (pinned playheads, cut sub-ranges, held poses).
## Rebuilding that on a blend tree would rewrite every path the existing pins cover. So the action keeps playing on
## that one player exactly as before, WHOLE BODY, and this modifier -- a child of the paladin's `Skeleton3D`, run by
## the skeleton after the player has posed it -- OVERWRITES THE LOWER BODY with a locomotion clip sampled at its own
## playhead. Upper = `mixamorig_Spine` and everything under it (the player's clip); lower = `mixamorig_Hips` (ruled:
## Hips belongs to the legs) plus both `UpLeg` chains, i.e. every bone under the Hips that is not under the Spine.
##
## IT DECIDES NOTHING. `AnimationController` says which clip, at what rate, and whether the layer is on; this node only
## keeps the playhead, cross-fades between clips, ramps its weight and writes poses. Its weight is the skeleton's own
## `influence` blend, so "off" is exact: at influence 0 the skeleton keeps the player's pose untouched.
##
## IT NEVER REACHES STATE OR CONTACT. A modifier's output is applied for the render and restored afterwards (measured,
## Godot 4.6.3: `get_bone_pose_*` and `get_bone_global_pose` read the player's pose again after the frame), so the
## sword and trunk bone followers in `HeroActor.drive()` -- which feed contact facts -- never see this layer.
##
## Its clock is the render delta of `_process_modification_with_delta`, so the legs animate per frame like the player
## does; `frozen` (the hitstop, `AnimationController.set_frozen`) stops the playhead and the ramps together.

const HIPS := "mixamorig_Hips"
const SPINE := "mixamorig_Spine"
## |forward.y| above this and the chest's yaw is ill-conditioned: the facing compensation steps aside.
const STEEP_FORWARD_Y := 0.9

## The lower-body bones, resolved once from the skeleton.
var _bones := PackedInt32Array()
## The Hips and the root of the upper body (the Spine), for the F1 facing compensation.
var _hips := -1
var _spine := -1
## Animation -> [[bone, position track, rotation track, scale track], ...] for the lower-body bones it animates.
var _tracks := {}

var _clip: Animation
var _clip_name: StringName = &""
var _time := 0.0
var _rate := 1.0
## The clip being faded OUT, while a clip change cross-fades (`_xfade_left` > 0).
var _prev_clip: Animation
var _prev_time := 0.0
var _prev_rate := 1.0
var _xfade_left := 0.0
var _xfade_total := 0.0

var _target_weight := 0.0
var _weight_per_second := 0.0

## The hitstop: no playhead, cross-fade or weight ramp advances while set.
var frozen := false


func _ready() -> void:
	influence = 0.0
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var hips := skeleton.find_bone(HIPS)
	var spine := skeleton.find_bone(SPINE)
	_hips = hips
	_spine = spine
	if hips < 0:
		return
	var stack: Array[int] = [hips]
	while not stack.is_empty():
		var bone: int = stack.pop_back()
		if bone == spine:
			continue
		_bones.append(bone)
		for child: int in skeleton.get_bone_children(bone):
			stack.append(child)


## Is this bone driven by the layer? (The upper/lower partition, exposed for the test that pins it.)
func is_lower_bone(bone: int) -> bool:
	return _bones.has(bone)


## The clip the legs play right now, or `&""`.
func clip_name() -> StringName:
	return _clip_name


func playhead() -> float:
	return _time


func playback_rate() -> float:
	return _rate


## The weight the layer is ramping toward (1 = legs fully on the layer, 0 = the player's own legs).
func target_weight() -> float:
	return _target_weight


## Play `animation` (named `clip`) on the legs at `rate`. Re-selecting the clip already playing only updates its rate.
## A different clip cross-fades over `blend` seconds (0 = cut) and starts at `start`, or keeps the outgoing clip's
## playhead when `start` < 0 -- the walk cycle's phase survives a direction change, as the player's own crossfade does.
func play(clip: StringName, animation: Animation, rate: float, blend: float, start: float = -1.0) -> void:
	if animation == null:
		return
	if clip == _clip_name and _clip != null:
		_rate = rate
		return
	if _clip != null and blend > 0.0:
		_prev_clip = _clip
		_prev_time = _time
		_prev_rate = _rate
		_xfade_left = blend
		_xfade_total = blend
	else:
		_prev_clip = null
		_xfade_left = 0.0
	_time = start if start >= 0.0 else _time
	_clip = animation
	_clip_name = clip
	_rate = rate
	if _clip.length > 0.0:
		_time = fposmod(_time, _clip.length)


## Ramp the layer's weight to `weight` over `seconds` (0 = at once).
func fade_to(weight: float, seconds: float) -> void:
	_target_weight = clampf(weight, 0.0, 1.0)
	if seconds <= 0.0:
		influence = _target_weight
		_weight_per_second = 0.0
	else:
		_weight_per_second = 1.0 / seconds
	if _target_weight <= 0.0 and seconds <= 0.0:
		_clear()


func _clear() -> void:
	_clip = null
	_clip_name = &""
	_prev_clip = null
	_xfade_left = 0.0


func _process_modification_with_delta(delta: float) -> void:
	if not frozen:
		_advance(delta)
	if _clip == null or influence <= 0.0:
		return
	var skeleton := get_skeleton()
	# F1 (operator live smoke, 2026-10-09): the ACTION's own Hips and Spine, read before the legs overwrite the Hips.
	var action_hips := skeleton.get_bone_pose_rotation(_hips) if _hips >= 0 else Quaternion.IDENTITY
	var action_spine := skeleton.get_bone_pose_rotation(_spine) if _spine >= 0 else Quaternion.IDENTITY
	var w := 1.0
	if _prev_clip != null and _xfade_total > 0.0:
		w = 1.0 - _xfade_left / _xfade_total
	for row: Array in _rows(_clip):
		var bone: int = row[0]
		var pos := _sample_position(_clip, row[1], _time)
		var rot := _sample_rotation(_clip, row[2], _time)
		var scl := _sample_scale(_clip, row[3], _time)
		if w < 1.0:
			var prev := _row_for(_prev_clip, bone)
			if not prev.is_empty():
				pos = _sample_position(_prev_clip, prev[1], _prev_time).lerp(pos, w)
				rot = _sample_rotation(_prev_clip, prev[2], _prev_time).slerp(rot, w)
				scl = _sample_scale(_prev_clip, prev[3], _prev_time).lerp(scl, w)
		if row[1] >= 0:
			skeleton.set_bone_pose_position(bone, pos)
		if row[2] >= 0:
			skeleton.set_bone_pose_rotation(bone, rot)
		if row[3] >= 0:
			skeleton.set_bone_pose_scale(bone, scl)
	if _hips >= 0 and _spine >= 0:
		skeleton.set_bone_pose_rotation(_spine,
				upper_facing_spine(action_hips, action_spine, skeleton.get_bone_pose_rotation(_hips)))


## F1 (operator live smoke, 2026-10-09): THE UPPER BODY KEEPS ITS OWN FACING. The Spine is parented to the Hips, so the
## legs' Hips rotation would turn the whole upper body with it (the block pose's Hips sit ~45 deg round, the walk's do
## not: the shield pointed off the target). This returns the Spine's local rotation under the LEGS' Hips (`legs_hips`)
## such that the Spine's forward yaw about the hero's up axis (skeleton +Y, the character's own frame) is exactly what
## the action's own Hips (`action_hips`) gave it -- a pure yaw added in the skeleton frame, so the walk's pitch and roll
## (its bob and small sway) still reach the chest. Pure, so it is pinned without a scene.
static func upper_facing_spine(action_hips: Quaternion, action_spine: Quaternion, legs_hips: Quaternion) -> Quaternion:
	# Review fix F4: a chest whose forward axis is near vertical has no stable yaw -- keep the action's own Spine.
	if absf(Basis(action_hips * action_spine).z.y) > STEEP_FORWARD_Y or absf(Basis(legs_hips * action_spine).z.y) > STEEP_FORWARD_Y:
		return action_spine
	var want := _forward_yaw(action_hips * action_spine)
	var have := _forward_yaw(legs_hips * action_spine)
	var turn := Quaternion(Vector3.UP, want - have)
	return (legs_hips.inverse() * turn * legs_hips * action_spine).normalized()


## Yaw (radians) of a rotation's forward (+Z) axis about +Y.
static func _forward_yaw(q: Quaternion) -> float:
	var z := Basis(q).z
	return atan2(z.x, z.z)


func _advance(delta: float) -> void:
	if influence != _target_weight:
		if _weight_per_second <= 0.0:
			influence = _target_weight
		else:
			influence = move_toward(influence, _target_weight, _weight_per_second * delta)
		if influence <= 0.0 and _target_weight <= 0.0:
			_clear()
	if _clip == null:
		return
	_time = _wrap(_clip, _time + delta * _rate)
	if _prev_clip != null:
		_prev_time = _wrap(_prev_clip, _prev_time + delta * _prev_rate)
		_xfade_left -= delta
		if _xfade_left <= 0.0:
			_prev_clip = null
			_xfade_left = 0.0


static func _wrap(animation: Animation, t: float) -> float:
	if animation.length <= 0.0:
		return 0.0
	if animation.loop_mode == Animation.LOOP_NONE:
		return clampf(t, 0.0, animation.length)
	return fposmod(t, animation.length)


func _rows(animation: Animation) -> Array:
	if _tracks.has(animation):
		return _tracks[animation]
	var skeleton := get_skeleton()
	var rows: Array = []
	for bone: int in _bones:
		var path := NodePath("%s:%s" % [skeleton.name, skeleton.get_bone_name(bone)])
		var row := [bone,
			animation.find_track(path, Animation.TYPE_POSITION_3D),
			animation.find_track(path, Animation.TYPE_ROTATION_3D),
			animation.find_track(path, Animation.TYPE_SCALE_3D)]
		if row[1] >= 0 or row[2] >= 0 or row[3] >= 0:
			rows.append(row)
	_tracks[animation] = rows
	return rows


func _row_for(animation: Animation, bone: int) -> Array:
	for row: Array in _rows(animation):
		if row[0] == bone:
			return row
	return []


static func _sample_position(animation: Animation, track: int, t: float) -> Vector3:
	return animation.position_track_interpolate(track, t) if track >= 0 else Vector3.ZERO


static func _sample_rotation(animation: Animation, track: int, t: float) -> Quaternion:
	return animation.rotation_track_interpolate(track, t) if track >= 0 else Quaternion.IDENTITY


static func _sample_scale(animation: Animation, track: int, t: float) -> Vector3:
	return animation.scale_track_interpolate(track, t) if track >= 0 else Vector3.ONE
