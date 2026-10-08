class_name UnblockableEyes
extends Node3D

## Story 7-10 (S1, AC 1-7): THE ATTACKER'S EYES -- two emissive points at the visor in the unblockable's colour,
## lit on the click tick, blinking faster as the chargeup fills, one strong flash on the commit, steady through
## the flight, off on the first touch or on any exit from the attack. The defender reads the attacker's face to
## time a counter, Sekiro's tell.
##
## PRESENTATION ONLY (AC 17/AC 18). A child of a `BoneAttachment3D` on `mixamorig_Head` (`EffectFx.bone_follower`),
## built in code, with no collision shape, no `Area3D` and no signal into state. NO `_physics_process` (F1): the
## runner pushes one `drive()` per tick from its post-`advance()` poll, so the blink clock is the tick count and a
## replay of the same state facts replays the same blinks. NOT under `TelegraphController`, whose shapes are the
## F3 debug layer (`7-6` P21/P22): the eyes are a real cue and always render.
##
## GLOW (Open Question 3, operator ruling): there is no `WorldEnvironment`, so nothing blooms. Brightness comes
## from UNSHADED ADDITIVE billboard quads (a hot core and a soft halo per eye) and, on the flash only, a short
## scale burst and a brief `OmniLight3D`.
##
## WHERE THE EYES SIT, MEASURED (Task 1, `tools/measure_head_visor.gd`, idle rest frame): the head geometry's
## front surface lies 0.136-0.140 m along the head bone's forward axis for every height band from 0.09 below to
## 0.16 above the joint, the head spans about +-0.09 m sideways, and the skeleton is unscaled (metres). The
## eyes sit `EYE_FORWARD_M` along that axis -- in front of every head vertex at their height, so the depth test
## cannot hide them from a camera in front of the hero (the opponent's view) -- `EYE_HEIGHT_M` up and
## `EYE_HALF_SEPARATION_M` to each side. The three axes are the bone-frame directions the tool printed for model
## forward, up and side; a re-rigged head re-measures them with the same tool.

## The bone the eyes follow.
const HEAD_BONE := &"mixamorig_Head"

## MEASURED head-bone-frame axes (`tools/measure_head_visor.gd`: "head-space forward / up / side").
const HEAD_FORWARD := Vector3(0.250678, 0.159537, 0.954834)
const HEAD_UP := Vector3(0.037415, 0.983994, -0.174232)
const HEAD_SIDE := Vector3(0.967347, -0.079401, -0.240697)

## KNOBS (AC 7: eye size, brightness, blink interval range and flash length are named; tests pin bounds and
## directions only, so the operator tunes these at smoke with no suite run).
## Placement, metres in the head-bone frame. Forward = measured front 0.1395 + a 0.0155 margin.
const EYE_FORWARD_M := 0.155
const EYE_HEIGHT_M := 0.075
const EYE_HALF_SEPARATION_M := 0.035
## Size of each eye's hot core and soft halo quad, metres (read at 4-6 m in a half-width viewport).
const EYE_CORE_SIZE := 0.07
const EYE_HALO_SIZE := 0.22
## Brightness: the core's colour multiplier (additive, so above 1 reads hotter) and the halo's alpha.
const EYE_BRIGHTNESS := 1.6
const EYE_HALO_ALPHA := 0.55
## How lit an eye is in the OFF half of a blink (0 = fully dark). Kept above zero so the eyes never vanish
## between blinks and the defender never loses the tell.
const EYE_BLINK_DIM := 0.15
## The blink interval range, seconds per full on/off cycle: `BLINK_INTERVAL_SLOW` at chargeup progress 0,
## `BLINK_INTERVAL_FAST` at progress 1, shaped by `BLINK_CURVE` (> 1 keeps it slow longer and rushes the end).
const BLINK_INTERVAL_SLOW := 0.45
const BLINK_INTERVAL_FAST := 0.07
const BLINK_CURVE := 1.6
## The lit share of each blink cycle.
const BLINK_ON_FRACTION := 0.5
## The commit flash: how long it lasts, how far the quads swell, and the brief light's energy and range.
const FLASH_SECONDS := 0.2
const FLASH_SCALE := 3.0
const FLASH_LIGHT_ENERGY := 6.0
const FLASH_LIGHT_RANGE := 3.0
## Sound levels (placeholders, `assets/audio/effects/sfx_eye_*.wav`).
const TICK_VOLUME_DB := -8.0
const STING_VOLUME_DB := 0.0

const TICK_SOUND := preload("res://assets/audio/effects/sfx_eye_tick.wav")
const STING_SOUND := preload("res://assets/audio/effects/sfx_eye_flash.wav")

enum Phase { OFF, BLINK, LIT }
## What one `drive()` call produced, for the sounds and for the tests.
enum Event { NONE, LIGHT, BLINK, FLASH, OUT }

## Colour vocabulary, `Enums.CardColor` int -> Color, from the hero's own charge `TelegraphProfile`s (no fourth
## colour table).
var colors: Dictionary = {}
var phase: Phase = Phase.OFF
## How many flashes and blinks this node has shown -- a test reads them to find the flash tick and the
## blink cadence.
var flash_count := 0
var blink_count := 0
var _suppressed := false
var _color := Color.WHITE
var _blink_clock := 0.0
var _flash_ticks_left := 0
var _cores: Array[MeshInstance3D] = []
var _halos: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _tick_player: AudioStreamPlayer
var _sting_player: AudioStreamPlayer


## THE BLINK CLOCK, a pure function of chargeup PROGRESS (AC 2): seconds per blink cycle, `BLINK_INTERVAL_SLOW`
## at 0 and `BLINK_INTERVAL_FAST` at 1, monotonically non-increasing between. The chargeup's LENGTH never enters,
## so retuning `unblockable_chargeup_seconds` re-fits the whole accelerando with no edit here.
static func eyes_blink_interval(progress: float) -> float:
	var p := pow(clampf(progress, 0.0, 1.0), BLINK_CURVE)
	return lerpf(BLINK_INTERVAL_SLOW, BLINK_INTERVAL_FAST, p)


## The eye offsets in the head-bone frame, left then right.
static func eye_offsets() -> Array[Vector3]:
	var centre := HEAD_FORWARD * EYE_FORWARD_M + HEAD_UP * EYE_HEIGHT_M
	return [centre - HEAD_SIDE * EYE_HALF_SEPARATION_M, centre + HEAD_SIDE * EYE_HALF_SEPARATION_M]


func _ready() -> void:
	for offset: Vector3 in eye_offsets():
		var halo := EffectFx.quad(EffectFx.TEX_GLOW, Color.WHITE, EYE_HALO_SIZE, true)
		halo.position = offset
		add_child(halo)
		_halos.append(halo)
		var core := EffectFx.quad(EffectFx.TEX_GLOW, Color.WHITE, EYE_CORE_SIZE, true)
		core.position = offset
		add_child(core)
		_cores.append(core)
	_light = EffectFx.light(Color.WHITE, FLASH_LIGHT_ENERGY, FLASH_LIGHT_RANGE)
	_light.position = HEAD_FORWARD * EYE_FORWARD_M + HEAD_UP * EYE_HEIGHT_M
	add_child(_light)
	_tick_player = _sound(TICK_SOUND, TICK_VOLUME_DB)
	_sting_player = _sound(STING_SOUND, STING_VOLUME_DB)
	_show(0.0, 1.0, false)


func _sound(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"CombatCues"
	player.volume_db = volume_db
	add_child(player)
	return player


## ONE TICK of the eyes, pushed by the runner after `advance()`. `lit` is the whole AC 3 gate -- the hero is
## CHARGING an unblockable and nothing has touched yet -- computed by the caller from state facts; `chargeup_running`
## is `charge_window.is_running` (false from the commit tick on), and `progress` is the chargeup's own progress.
## The FLASH is keyed to `chargeup_running` going false while lit, never to a time (Dev Notes).
func drive(lit: bool, color: int, chargeup_running: bool, progress: float) -> Event:
	if not lit:
		if phase == Phase.OFF:
			return Event.NONE
		_go_dark()
		return Event.OUT
	var event := Event.NONE
	if phase == Phase.OFF:
		_color = colors.get(color, Color.WHITE)
		_blink_clock = 0.0
		phase = Phase.BLINK if chargeup_running else Phase.LIT
		event = Event.LIGHT
	elif phase == Phase.BLINK and not chargeup_running:
		phase = Phase.LIT
		_flash_ticks_left = maxi(1, int(round(FLASH_SECONDS * TimingWindow.TICK_HZ)))
		flash_count += 1
		_sting_player.play()
		event = Event.FLASH
	elif phase == Phase.BLINK:
		_blink_clock += 1.0 / TimingWindow.TICK_HZ
		var interval := eyes_blink_interval(progress)
		if _blink_clock >= interval:
			_blink_clock = fmod(_blink_clock, interval)
			blink_count += 1
			_tick_player.play()
			event = Event.BLINK
	_render(progress)
	return event


## Round-over (or any freeze the runner names) hides the eyes without forgetting the phase. Level-triggered
## every frame from the runner, so a frozen charging hero shows no lit eyes over its corpse-filled arena.
func set_suppressed(suppressed: bool) -> void:
	if suppressed == _suppressed:
		return
	_suppressed = suppressed
	visible = not suppressed and phase != Phase.OFF


## Every end path the runner knows (debug reset): dark at once, the flash and the sounds cut.
func clear() -> void:
	_go_dark()
	_tick_player.stop()
	_sting_player.stop()


func _go_dark() -> void:
	phase = Phase.OFF
	_flash_ticks_left = 0
	_blink_clock = 0.0
	_show(0.0, 1.0, false)


func _render(progress: float) -> void:
	if phase == Phase.BLINK:
		var on := _blink_clock < eyes_blink_interval(progress) * BLINK_ON_FRACTION
		_show(1.0 if on else EYE_BLINK_DIM, 1.0, false)
		return
	if _flash_ticks_left > 0:
		var total := maxi(1, int(round(FLASH_SECONDS * TimingWindow.TICK_HZ)))
		var t := float(_flash_ticks_left) / float(total)
		_flash_ticks_left -= 1
		_show(1.0, lerpf(1.0, FLASH_SCALE, t), true, t)
		return
	_show(1.0, 1.0, false)


func _show(level: float, scale_factor: float, light_on: bool, light_level: float = 0.0) -> void:
	visible = level > 0.0 and not _suppressed
	var core_color := Color(_color.r * EYE_BRIGHTNESS, _color.g * EYE_BRIGHTNESS, _color.b * EYE_BRIGHTNESS,
			level)
	var halo_color := Color(_color.r, _color.g, _color.b, level * EYE_HALO_ALPHA)
	for core in _cores:
		(core.material_override as StandardMaterial3D).albedo_color = core_color
		core.scale = Vector3.ONE * scale_factor
	for halo in _halos:
		(halo.material_override as StandardMaterial3D).albedo_color = halo_color
		halo.scale = Vector3.ONE * scale_factor
	if _light != null:
		_light.visible = light_on
		_light.light_color = _color
		_light.light_energy = FLASH_LIGHT_ENERGY * light_level
