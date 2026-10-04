class_name EffectPresenter
extends Node3D

## Story 7-1 (AC 6-22, AC 27-32): THE DECK 1 EFFECT PRESENTATION -- every Scope row's look and sound, built
## here and driven by the runner from the hooks the story's trigger map names.
##
## IT READS, IT NEVER DECIDES (the HARD RULE, AC 4). The runner reads public fields and pure queries after
## `advance()` and hands this node PLAIN VALUES -- positions, counts, booleans, effect ids -- and scene nodes to
## anchor a look on (a hero or unit ACTOR, never a state object). No `PlayerState`, `MatchState` or board is
## stored here or passed in (AC 5). Nothing built here has a collision shape, an `Area3D` or a signal into
## state, so no contact, timing window, outcome or replay record can depend on it.
##
## NO `_physics_process` (F1). Timing rides tweens and particle lifetimes; the persistent looks are
## LEVEL-TRIGGERED from the runner's per-tick poll (`update_hero`, `set_grave_ward`), so an effect ends on
## whatever path ends its state -- expiry, a Counterspell, death, a reset -- without a falling edge of its own
## to remember (the `set_root_marker` precedent, AC 32).
##
## WORLD-SPACE ON THE ACTOR (AC 28): every persistent look is a child of the hero or unit actor it belongs to,
## and both split-screen SubViewports render the one shared `World3D`, so the opponent's viewport shows it too.
##
## KNOBS (AC 29) come from the authored `EffectPresentationSet`; COLOUR (AC 27) from the charge
## `TelegraphProfile`s the runner hands over in `setup` -- the one existing colour vocabulary.

## How a hero-spell shot ended, as the runner read it per `7-1/R2` (AC 16).
enum End { IMPACT, SCATTER, VANISH, FIZZLE }

const ROCK_SCENE := preload("res://assets/models/rock/rock.glb")
const SKULL_SCENE := preload("res://assets/models/skull/skull.glb")
const ROCK_ALBEDO := preload("res://assets/models/rock/rock_basecolor.jpg")
const ROCK_NORMAL := preload("res://assets/models/rock/rock_normal.png")
const ROCK_ROUGHNESS := preload("res://assets/models/rock/rock_roughness.jpg")
const FIREBALL_CORE_SHADER := preload("res://src/actors/effects/fireball_core.gdshader")

## The sound a row plays AT RESOLUTION from `play_resolution_sound` -- the rows whose resolution has no visual
## event of its own to carry the sound (the others play theirs from the event: `show_culling`, `show_drain`, ...).
const RESOLUTION_SLOT := {
	&"grave_ward": &"ward",
	&"raise_dead": &"raise",
	&"vampiric_aura": &"aura",
	&"bloodhound_step": &"hound",
	&"frostbite": &"frost_arm",
}

## Node names of the looks this presenter parents onto actors. Tests find them by these names.
const GRAVE_WARD_NODE := &"GraveWardGlow"
const DRESS_NODE := &"EffectDress"
## The Grave Ward look's path, built once -- `set_grave_ward` runs per corpse per tick.
const _GRAVE_WARD_PATH := ^"GraveWardGlow"
## The meta key under which a Boulder crust keeps its rock pieces, so the per-tick count push walks a cached list.
const _CRUST_PIECES_META := &"crust_pieces"

## The hero root is the body CENTRE (`hero.tscn`, "GROUNDING OFFSET"): feet at -1.0, head top at about +0.9.
const HERO_FEET_Y := -1.0
const HERO_LEGS_Y := -0.6
const HERO_HEAD_Y := 1.15

## 7-1 polish round: the bones the looks follow. The sword joint is the one the hero's Hitbox follows (`5-0a`); the
## legs carry the Boulder crust; the Hips anchor a corpse's Grave Ward look (Mixamo names, both rigs).
const SWORD_BONE := &"mixamorig_Sword_joint"
const HIPS_BONE := &"mixamorig_Hips"
## Shins first, then thighs: the crust climbs the legs as the Boulder count rises.
const LEG_BONES: Array[StringName] = [
	&"mixamorig_LeftLeg", &"mixamorig_RightLeg", &"mixamorig_LeftUpLeg", &"mixamorig_RightUpLeg",
]

var knobs: EffectPresentationSet
var _vocabulary: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _rock_material: StandardMaterial3D
## Fireball growth inputs (AC 16/17), from authored data the runner reads: damage per mana, the minimum staging
## price and the mana cap. Zero span degrades to the minimum core.
var _fireball_dpm := 1.0
var _fireball_min_mana := 0.0
var _fireball_cap := 1.0
## Per-slot persistent hero looks, name -> node, and the last level pushed (for rising edges).
var _hero_nodes: Array[Dictionary] = [{}, {}]
var _frozen_last: Array[bool] = [false, false]
var _bolt_charge: Array = [null, null]
## Every looped player on a dressed shot, so a round end can silence them (AC 32).
var _loops: Array = []
## EVERY player this presenter started (one-shots, loops on shots, the bolt charge), pruned as they free, so
## `stop_all_sounds` can stop them all.
var _players: Array = []
## Sequence tweens bound to this presenter rather than to a child node (Boom's explosion run), so teardown can
## kill them: a presenter-bound tween survives `queue_free` of the children (review fix P7, AC 32).
var _tweens: Array[Tween] = []
## The last few "row/slot" sounds played, newest last -- what an integration test reads to prove a sound fired.
var played: Array[StringName] = []
const PLAYED_CAP := 64


## Wire the knobs and the colour vocabulary (`Enums.CardColor` int -> `TelegraphProfile`).
func setup(knob_set: EffectPresentationSet, vocabulary: Dictionary) -> void:
	knobs = knob_set
	_vocabulary = vocabulary
	_rng.seed = 7071
	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_texture = ROCK_ALBEDO
	_rock_material.normal_enabled = true
	_rock_material.normal_texture = ROCK_NORMAL
	_rock_material.roughness_texture = ROCK_ROUGHNESS
	_rock_material.metallic = 0.0


func set_fireball_range(damage_per_mana: float, min_mana: float, mana_cap: float) -> void:
	_fireball_dpm = damage_per_mana if damage_per_mana > 0.0 else 1.0
	_fireball_min_mana = min_mana
	_fireball_cap = mana_cap


func row(row_id: StringName) -> EffectPresentationRow:
	return knobs.row(row_id) if knobs != null else null


func row_for_effect(effect_id: StringName) -> EffectPresentationRow:
	return knobs.row_for_effect(effect_id) if knobs != null and effect_id != &"" else null


## The row's colour from the vocabulary (AC 27). A COLORLESS row (or an unknown colour) answers `fallback`.
func color_of(r: EffectPresentationRow, fallback: Color = Color(0.8, 0.75, 0.7)) -> Color:
	if r == null:
		return fallback
	var profile: Variant = _vocabulary.get(int(r.card_color))
	if profile is TelegraphProfile:
		return (profile as TelegraphProfile).color
	return fallback


## ---------------------------------------------------------------------------------------------- sound

## Play one row slot. Non-positional on the `CombatCues` bus, the standing cue shape (AC 30). `parent` binds the
## player's life to a node (a shot's loop dies with the shot); `looped` restarts it until that parent is freed.
func play_sound(row_id: StringName, slot: StringName, parent: Node = null,
		looped: bool = false) -> AudioStreamPlayer:
	var r := row(row_id)
	if r == null or not (EffectPresentationSet.ROW_SOUND_SLOTS.get(row_id, []) as Array).has(slot):
		return null
	var stream: Variant = r.sounds.get(slot)
	if not (stream is AudioStream):
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"CombatCues"
	player.volume_db = float(r.volume_db.get(slot, 0.0))
	player.pitch_scale = float(r.pitch.get(slot, 1.0))
	(parent if parent != null else self).add_child(player)
	if looped:
		player.finished.connect(player.play)
		var live: Array[AudioStreamPlayer] = []
		for loop: Variant in _loops:
			if is_instance_valid(loop):
				live.append(loop as AudioStreamPlayer)
		_loops = live
		_loops.append(player)
	else:
		player.finished.connect(player.queue_free)
	player.play()
	if _players.size() > 32:
		var live: Array = []
		for p: Variant in _players:
			if is_instance_valid(p):
				live.append(p)
		_players = live
	_players.append(player)
	played.append(StringName("%s/%s" % [row_id, slot]))
	if played.size() > PLAYED_CAP:
		played.pop_front()
	return player


## `7-1/R4`: the generic cast-success cue is the FALLBACK -- silenced for an effect whose row says it has its
## own resolution sound, kept for every effect no row claims.
func silences_generic_cue(effect_id: StringName) -> bool:
	var r := row_for_effect(effect_id)
	return r != null and r.silences_generic_cue


## The resolution-time sound of the rows that have no visual event to carry it.
func play_resolution_sound(effect_id: StringName) -> void:
	var r := row_for_effect(effect_id)
	if r == null or not RESOLUTION_SLOT.has(r.row_id):
		return
	play_sound(r.row_id, RESOLUTION_SLOT[r.row_id])


## ---------------------------------------------------------------------------------------------- events

## VANGUARD (AC 6): a green crack in the ground where the minion emerges, dust and sparks. `size` = crack
## width (m), `count` = particles per burst, `duration` = how long the crack stays.
func show_vanguard(position: Vector3) -> void:
	var r := row(&"vanguard")
	if r == null:
		return
	var color := color_of(r)
	var crack := EffectFx.quad(EffectFx.TEX_CRACK, color * Color(1, 1, 1, 0.9), r.size, false)
	add_child(crack)
	crack.global_position = position + Vector3(0.0, 0.03, 0.0)
	crack.rotation.y = _rng.randf_range(0.0, TAU)
	_fade_out(crack, r.duration)
	EffectFx.burst(self, position + Vector3(0.0, 0.2, 0.0), EffectFx.TEX_SMOKE, Color(0.55, 0.5, 0.42, 0.8),
			r.count, r.duration, r.size * 0.6, 2.0, 60.0, 1.5, false)
	EffectFx.burst(self, position + Vector3(0.0, 0.2, 0.0), EffectFx.TEX_STAR, color, r.count, r.duration * 0.6,
			0.18, 4.0, 45.0, 6.0)
	play_sound(&"vanguard", &"summon")


## RAISE DEAD (AC 9): a green pillar rises from the consumed corpse's spot; the raised minion (already standing
## there, `_raised_spot`) appears inside it. `size` = pillar radius, `knob height` = pillar height.
## 7-1 POLISH ROUND: before the pillar, a GREEN LIGHTNING STRIKE (Honed Bolt's ribbon) hits the corpse; the pillar
## starts rising `knob strike_lead` seconds later. `knob strike_height/strike_branches/strike_width/
## strike_seconds/strike_energy` shape the strike.
func show_raise(position: Vector3) -> void:
	var r := row(&"raise_dead")
	if r == null:
		return
	var color := color_of(r)
	_strike(position, color, r.knob(&"strike_height", 8.0), int(r.knob(&"strike_branches", 4.0)),
			r.knob(&"strike_width", 0.16), r.knob(&"strike_seconds", 0.3), r.knob(&"strike_energy", 6.0))
	var lead := r.knob(&"strike_lead", 0.1)
	if lead <= 0.0:
		_raise_pillar(position, r, color)
		return
	var wait := create_tween()
	wait.tween_interval(lead)
	wait.tween_callback(_raise_pillar.bind(position, r, color))
	_track(wait)


func _raise_pillar(position: Vector3, r: EffectPresentationRow, color: Color) -> void:
	var pillar := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = r.size * 0.7
	cylinder.bottom_radius = r.size
	cylinder.height = r.knob(&"height", 3.0)
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	pillar.mesh = cylinder
	var mat := EffectFx.material(EffectFx.TEX_GLOW, color * Color(1, 1, 1, 0.55), true,
			BaseMaterial3D.BILLBOARD_DISABLED)
	pillar.material_override = mat
	add_child(pillar)
	pillar.global_position = position + Vector3(0.0, cylinder.height * 0.5, 0.0)
	pillar.scale = Vector3(1.0, 0.05, 1.0)
	var tween := pillar.create_tween()
	tween.tween_property(pillar, "scale", Vector3.ONE, r.duration * 0.35)
	tween.tween_interval(r.duration * 0.35)
	tween.tween_property(mat, "albedo_color:a", 0.0, r.duration * 0.3)
	tween.tween_callback(pillar.queue_free)
	EffectFx.burst(self, position + Vector3(0.0, 0.3, 0.0), EffectFx.TEX_WISP, color, r.count, r.duration,
			0.4, 3.0, 15.0, -1.0)


## CULLING (AC 7): each culled minion flares in green fire, and one soul per minion flies to the caster.
## `cull` once; `soul` per soul. `size` = flare size, `duration` = flare life, `knob soul_flight` = seconds.
## 7-1 POLISH ROUND: the flare is as pronounced as Drain's -- each culled minion's body takes Drain's full-body flash
## (`knob flash` seconds) and a flash light (`intensity`), on top of the fire burst. `culled[i]` is `sources[i]`'s
## actor, or null.
func show_culling(sources: Array[Vector3], culled: Array[Node3D], caster: Node3D) -> void:
	var r := row(&"culling")
	if r == null or sources.is_empty():
		return
	var color := color_of(r)
	play_sound(&"culling", &"cull")
	for i in sources.size():
		var source := sources[i]
		if i < culled.size() and is_instance_valid(culled[i]):
			_overlay_flash(_skin_of(culled[i]), color, r.knob(&"flash", 0.25))
		_flash_light(source + Vector3(0.0, 0.8, 0.0), color, r.intensity, 4.0, r.duration)
		EffectFx.burst(self, source + Vector3(0.0, 0.6, 0.0), EffectFx.TEX_FLAME, color, r.count, r.duration,
				r.size, 1.5, 25.0, -2.0)
		EffectFx.burst(self, source + Vector3(0.0, 0.8, 0.0), EffectFx.TEX_GLOW, color.lightened(0.3),
				maxi(r.count / 2, 1), r.duration * 0.7, r.size * 1.3, 0.8, 180.0, 0.0)
		_fly(source + Vector3(0.0, 0.9, 0.0), caster, Vector3.ZERO, r.knob(&"soul_flight", 0.35),
				EffectFx.TEX_GLOW, color, r.knob(&"soul_size", 0.35))
		play_sound(&"culling", &"soul")


## DRAIN (AC 10): a green thread from the sacrificed minion to the caster for `duration` (~0.4 s), the minion
## crumbles, the caster flashes. `size` = thread width.
func show_drain(source: Vector3, caster: Node3D) -> void:
	var r := row(&"drain")
	if r == null or not is_instance_valid(caster):
		return
	var color := color_of(r)
	var thread := MeshInstance3D.new()
	add_child(thread)
	var from := source + Vector3(0.0, 0.8, 0.0)
	var to := caster.global_position
	var mesh := ImmediateMesh.new()
	thread.mesh = mesh
	thread.material_override = EffectFx.material(null, color, true, BaseMaterial3D.BILLBOARD_DISABLED)
	var verts := PackedVector3Array()
	EffectFx._ribbon(verts, PackedVector3Array([from, from.lerp(to, 0.5) + Vector3(0, 0.4, 0), to]), r.size)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in verts:
		mesh.surface_add_vertex(v)
	mesh.surface_end()
	EffectFx.free_after(thread, r.duration)
	EffectFx.burst(self, source + Vector3(0.0, 0.5, 0.0), EffectFx.TEX_DEBRIS, Color(0.45, 0.42, 0.35, 1.0),
			r.count, 0.7, 0.35, 2.5, 70.0, 6.0, false)
	_overlay_flash(_hero_skin(caster), color, r.knob(&"flash", 0.25))
	play_sound(&"drain", &"drain")


## VAMPIRIC AURA (AC 11): one lifesteal heal = droplets flowing into the hero; `heal` per heal.
## `knob droplet_count`, `knob droplet_flight`, `knob droplet_size` (7-1 polish round: bigger, brighter, and a
## soak burst on the hero as they land).
func heal_droplets(hero: Node3D) -> void:
	var r := row(&"vampiric_aura")
	if r == null or not is_instance_valid(hero):
		return
	var color := color_of(r).lightened(0.25)
	var flight := r.knob(&"droplet_flight", 0.35)
	for i in int(r.knob(&"droplet_count", 6.0)):
		var start := hero.global_position + Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(0.2, 1.4),
				_rng.randf_range(-1.2, 1.2))
		_fly(start, hero, Vector3.ZERO, flight * _rng.randf_range(0.8, 1.2), EffectFx.TEX_GLOW, color,
				r.knob(&"droplet_size", 0.18))
	var soak := create_tween()
	soak.tween_interval(flight)
	soak.tween_callback(_heal_soak.bind(hero, color, r))
	_track(soak)
	play_sound(&"vampiric_aura", &"heal")


func _heal_soak(hero: Variant, color: Color, r: EffectPresentationRow) -> void:
	if not is_instance_valid(hero):
		return
	var at := (hero as Node3D).global_position
	EffectFx.burst(self, at, EffectFx.TEX_GLOW, color, 10, 0.35, r.knob(&"droplet_size", 0.18) * 2.5, 1.5)
	_flash_light(at, color, r.intensity * 2.0, 3.0, 0.25)


## BOOM (AC 14): one rock explosion on the opponent per detonated Boulder, `spacing` seconds apart; `boom` per
## explosion. `size` = explosion size.
func show_boom(target: Node3D, count: int) -> void:
	var r := row(&"boom")
	if r == null or count <= 0 or not is_instance_valid(target):
		return
	var tween := create_tween()
	for i in count:
		if i > 0:
			tween.tween_interval(maxf(r.spacing, 0.01))
		tween.tween_callback(_boom_once.bind(target, r))
	_track(tween)


func _boom_once(target: Variant, r: EffectPresentationRow) -> void:
	if not is_instance_valid(target):
		return
	var at := (target as Node3D).global_position + Vector3(_rng.randf_range(-0.4, 0.4), 0.2, _rng.randf_range(-0.4, 0.4))
	var color := color_of(r)
	EffectFx.burst(self, at, EffectFx.TEX_DEBRIS, Color(0.55, 0.5, 0.45, 1.0), r.count, r.duration, r.size * 0.4,
			5.0, 80.0, 9.0, false)
	EffectFx.burst(self, at, EffectFx.TEX_SMOKE, color, r.count / 2, r.duration * 1.3, r.size, 1.5, 180.0, 0.0)
	_flash_light(at, color, r.intensity * 3.0, 4.0, 0.15)
	_spawn_rock_chunks(at, maxi(3, r.count / 5), 0.12)
	play_sound(&"boom", &"boom")


## HONED BOLT (AC 18): the bolt's charge sound runs for the cast, on the CASTER.
func start_bolt_charge(slot: int) -> void:
	stop_bolt_charge(slot)
	_bolt_charge[slot] = play_sound(&"honed_bolt", &"bolt_charge")


func stop_bolt_charge(slot: int) -> void:
	var player: Variant = _bolt_charge[slot]
	if is_instance_valid(player):
		(player as AudioStreamPlayer).queue_free()
	_bolt_charge[slot] = null


## HONED BOLT (AC 18): branching lightning from the sky with a flash, on the strike tick -- the runner calls this
## from the falling edge of the cast window, the tick the state layer strikes. `size` = sky height, `count` =
## branches, `duration` = how long the bolt is drawn, `intensity` = flash light energy.
func show_lightning(target: Vector3) -> void:
	var r := row(&"honed_bolt")
	if r == null:
		return
	_strike(target, color_of(r), r.size, r.count, r.knob(&"width", 0.18), r.duration, r.intensity)
	play_sound(&"honed_bolt", &"bolt_strike")


## The branching sky strike with its flash, sparks and ground ring -- Honed Bolt's look, shared with Raise Dead's
## green strike (7-1 polish round). `height` = sky height, `branches`, `width`, `seconds` drawn, `energy` = flash.
func _strike(target: Vector3, color: Color, height: float, branches: int, width: float, seconds: float,
		energy: float) -> void:
	var bolt := MeshInstance3D.new()
	bolt.name = &"LightningStrike"
	bolt.mesh = EffectFx.lightning_mesh(target + Vector3(0.0, height, 0.0), target, branches, width, _rng)
	var mat := EffectFx.material(null, Color(0.85, 0.95, 1.0) * color.lightened(0.5), true,
			BaseMaterial3D.BILLBOARD_DISABLED)
	bolt.material_override = mat
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bolt)
	var tween := bolt.create_tween()
	tween.tween_interval(seconds * 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, seconds * 0.5)
	tween.tween_callback(bolt.queue_free)
	_flash_light(target + Vector3(0.0, 1.5, 0.0), color.lightened(0.4), energy, 9.0, seconds)
	EffectFx.burst(self, target, EffectFx.TEX_SPARK, color, 18, 0.4, 0.5, 6.0, 80.0, 4.0)
	EffectFx.burst(self, target + Vector3(0.0, 0.05, 0.0), EffectFx.TEX_RING, color, 1, 0.35, 2.5, 0.0, 0.0, 0.0)


## COUNTERSPELL (AC 19): a blue rune circle on BOTH heroes, and whatever the reversal returned flashes blue.
## `size` = rune circle diameter, `duration` = its hold, `knob flash` = the returned flash.
##
## 7-1 POLISH ROUND (smoke: "no rune circle at all, only the blue flashes"). MEASURED CAUSE: the circle was ONE
## quad of `magic_02.png` -- mean alpha 0.048, its only opaque structure a ~1 px octagon line (about 1 cm across a
## 2.4 m circle) -- drawn ADDITIVE in the card's dark blue (0.15, 0.35, 0.95) onto the light ground, where adding a
## little blue to an already bright surface changes almost nothing. It was built and placed correctly (0.04 m
## above the feet), and simply could not be seen. Now: a layered circle -- two OPAQUE-blended rings in the card
## blue, a filled glow and the rune pattern brightened on top -- plus a blue light on the ground.
##
## And the caster's circle is the swing's: `swung` = the caster is playing `cast_counterspell`, whose peak lands
## `beat_delay` seconds after this tick. At that beat the circle BURSTS outward from the sword (a ring, sparks and a
## flash at the bone's live position) and SETTLES down to the caster's feet as the ground circle. A caster who
## did not swing (not standing still) bursts from the ground at the same beat. The COUNTERED hero shows its ground
## circle at once, as before. `knob burst_size`, `burst_seconds`, `settle_seconds`, `light_energy`,
## `fill_alpha`.
func show_counterspell(caster: Node3D, countered: Node3D, returned: Array, swung: bool,
		beat_delay: float) -> void:
	var r := row(&"counterspell")
	if r == null:
		return
	var color := color_of(r)
	if is_instance_valid(countered) and countered != caster:
		_rune_circle(countered, r, color, null)
	if is_instance_valid(caster):
		# Parented under this presenter, so a teardown before the beat (`clear_transient`) frees it too.
		var sword: Node3D = EffectFx.bone_follower(caster, self, SWORD_BONE) if swung else null
		if beat_delay <= 0.0:
			_counter_burst(caster, sword, r, color)
		else:
			var wait := create_tween()
			wait.tween_interval(beat_delay)
			wait.tween_callback(_counter_burst.bind(caster, sword, r, color))
			_track(wait)
	for actor: Variant in returned:
		if is_instance_valid(actor):
			_overlay_flash(_skin_of(actor as Node3D), color, r.knob(&"flash", 0.35))
	play_sound(&"counterspell", &"counter")


## The swing's peak: the burst at the sword (or the caster's feet when there is no sword to read), then the circle
## settling from there to the ground.
func _counter_burst(caster: Variant, sword: Variant, r: EffectPresentationRow, color: Color) -> void:
	var from_sword := is_instance_valid(sword)
	var origin := Vector3.ZERO
	if from_sword:
		origin = (sword as Node3D).global_position
		(sword as Node).queue_free()
	if not is_instance_valid(caster):
		return
	var hero := caster as Node3D
	if not from_sword:
		origin = hero.global_position + Vector3(0.0, HERO_FEET_Y + 0.05, 0.0)
	var burst_seconds := r.knob(&"burst_seconds", 0.25)
	var ring := EffectFx.quad(EffectFx.TEX_RING, color.lightened(0.4), 1.0, true)
	ring.name = &"CounterBurst"
	add_child(ring)
	ring.global_position = origin
	ring.scale = Vector3.ONE * 0.2
	var grow := ring.create_tween().set_parallel()
	grow.tween_property(ring, "scale", Vector3.ONE * r.knob(&"burst_size", 1.8), burst_seconds) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	grow.tween_property(ring.material_override, "albedo_color:a", 0.0, burst_seconds)
	grow.chain().tween_callback(ring.queue_free)
	EffectFx.burst(self, origin, EffectFx.TEX_SPARK, color.lightened(0.3), r.count * 3, 0.4, 0.25, 5.0, 180.0, 2.0)
	_flash_light(origin, color.lightened(0.3), r.knob(&"light_energy", 3.0) * 1.5, 5.0, burst_seconds)
	_rune_circle(hero, r, color, hero.to_local(origin))


## THE GROUND RUNE CIRCLE under `hero`, `r.size` across, held `r.duration` then faded. `from_local` (a hero-local
## point, or null) is where it bursts from: it starts there small and settles to the feet over `settle_seconds`.
func _rune_circle(hero: Node3D, r: EffectPresentationRow, color: Color, from_local: Variant) -> Node3D:
	var circle := Node3D.new()
	circle.name = &"CounterRune"
	hero.add_child(circle)
	var layers: Array[MeshInstance3D] = [
		EffectFx.quad(EffectFx.TEX_GLOW, Color(color.r, color.g, color.b, r.knob(&"fill_alpha", 0.35)),
				r.size * 1.1, false, false),
		EffectFx.quad(EffectFx.TEX_RING, color, r.size, false, false),
		EffectFx.quad(EffectFx.TEX_RING, color.lightened(0.35), r.size * 0.66, false, false),
		EffectFx.quad(EffectFx.TEX_RUNE, color.lightened(0.6), r.size * 0.95, false, true),
	]
	for i in layers.size():
		layers[i].position.y = 0.005 * i
		circle.add_child(layers[i])
	var light := EffectFx.light(color.lightened(0.2), r.knob(&"light_energy", 3.0), r.size * 1.2)
	light.position = Vector3(0.0, 0.5, 0.0)
	circle.add_child(light)
	var ground := Vector3(0.0, HERO_FEET_Y + 0.04, 0.0)
	var settle := r.knob(&"settle_seconds", 0.2) if from_local is Vector3 else 0.0
	if settle > 0.0:
		circle.position = from_local as Vector3
		circle.scale = Vector3.ONE * 0.15
		var drop := circle.create_tween().set_parallel()
		drop.tween_property(circle, "position", ground, settle).set_ease(Tween.EASE_IN)
		drop.tween_property(circle, "scale", Vector3.ONE, settle).set_ease(Tween.EASE_OUT)
	else:
		circle.position = ground
	var spin := circle.create_tween()
	spin.tween_property(circle, "rotation:y", TAU * 0.5, settle + r.duration)
	var fade := circle.create_tween().set_parallel()
	var fade_seconds := maxf(r.duration * 0.4, 0.05)
	for layer: MeshInstance3D in layers:
		fade.tween_property(layer.material_override, "albedo_color:a", 0.0, fade_seconds) \
				.set_delay(settle + r.duration * 0.6)
	fade.tween_property(light, "light_energy", 0.0, fade_seconds).set_delay(settle + r.duration * 0.6)
	fade.chain().tween_callback(circle.queue_free)
	return circle


## COUNTERSPELL (AC 19, review fix F1): the blue "returned" flash on a minion a Counterspell RESTORED -- its new
## actor, which did not exist yet when `show_counterspell` ran. The flash only: a restore has no emerge look.
func flash_returned(actor: Node3D) -> void:
	var r := row(&"counterspell")
	if r == null or not is_instance_valid(actor):
		return
	_overlay_flash(_skin_of(actor), color_of(r), r.knob(&"flash", 0.35))


## ---------------------------------------------------------------------------------------------- projectiles

## Dress a freshly spawned shot by its effect id: Fireball, Rocksling stone or Corpse Bomb skull. A shot with no
## row (the totem shot, `5-0c`) is left exactly as it spawned. THE HITBOX IS NEVER TOUCHED (AC 4/AC 35): the
## default `Mesh` is hidden and the look is parented beside it, concentric with `Hitbox/HitboxShape`.
func dress_projectile(shot: Node3D, effect_id: StringName, damage: float) -> void:
	var r := row_for_effect(effect_id)
	if r == null or not is_instance_valid(shot):
		return
	var mesh := shot.get_node_or_null("Mesh") as Node3D
	if mesh != null:
		mesh.visible = false
	var centre := _hit_centre_local(shot)
	var dress := Node3D.new()
	dress.name = DRESS_NODE
	shot.add_child(dress)
	dress.position = centre
	match r.row_id:
		&"fireball":
			_dress_fireball(dress, r, damage)
			play_sound(&"fireball", &"fire_launch")
			play_sound(&"fireball", &"fire_loop", shot, true)
		&"rocksling":
			var rock := _rock_instance(r.size)
			dress.add_child(rock)
			_spin(rock, r.knob(&"spin_seconds", 0.6))
			var dust := EffectFx.particles(EffectFx.TEX_SMOKE, Color(0.6, 0.55, 0.45, 0.6), r.count,
					0.6, 0.35, 0.3, 30.0, -0.5, false, false, false)
			dress.add_child(dust)
			play_sound(&"rocksling", &"rock_throw")
		&"corpse_bomb":
			# 7-1 polish round: the skull grows to the hit sphere's DIAMETER (`size`, capped there, so it never
			# reads larger than what hits), inside a blue-flame envelope (`knob envelope_scale` x its size), and
			# leaves the Fireball's flare trail in blue.
			var color := color_of(r)
			var skull_size := minf(r.size, 2.0 * _hit_radius(shot))
			var skull := SKULL_SCENE.instantiate() as Node3D
			skull.scale = Vector3.ONE * skull_size
			dress.add_child(skull)
			_tint_all(skull, color, 0.6)
			var envelope := skull_size * r.knob(&"envelope_scale", 0.75)
			_flame_envelope(dress, color, envelope, r.count)
			var flame := EffectFx.particles(EffectFx.TEX_FLAME, color, r.count, 0.45, skull_size * 1.6,
					0.6, 25.0, -2.0, false, false)
			dress.add_child(flame)
			dress.add_child(_flare_trail(color, envelope, r))
			play_sound(&"corpse_bomb", &"skull_launch")


## FIREBALL (AC 16/AC 17): no model -- a glowing core with moving noise (`fireball_core.gdshader`), a particle
## flame trail, sparks and a small light on the ground. THE CORE GROWS WITH MANA INVESTED, inside the hit sphere.
func _dress_fireball(dress: Node3D, r: EffectPresentationRow, damage: float) -> void:
	var color := color_of(r)
	var radius := fireball_core_radius(damage, _fireball_dpm, _fireball_min_mana, _fireball_cap, r)
	var core := MeshInstance3D.new()
	core.name = &"FireballCore"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	core.mesh = sphere
	var shader := ShaderMaterial.new()
	shader.shader = FIREBALL_CORE_SHADER
	shader.set_shader_parameter(&"edge_color", color)
	shader.set_shader_parameter(&"energy", r.intensity)
	core.material_override = shader
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dress.add_child(core)
	# 7-1 polish round: the FLAME ENVELOPE around the solid core grows with X too, to about twice the old ball at
	# max X (`knob envelope_min_radius/envelope_max_radius`). It is flame and glow, not solid -- the solid core
	# above stays inside the hit sphere (`7-1/R9`, AC 17) -- and a flare trail follows it in flight.
	var envelope := fireball_envelope_radius(damage, _fireball_dpm, _fireball_min_mana, _fireball_cap, r)
	_flame_envelope(dress, color, envelope, r.count)
	dress.add_child(_flare_trail(color, envelope, r))
	var trail := EffectFx.particles(EffectFx.TEX_FLAME, color, r.count, 0.35, radius * 3.0, 0.4, 20.0,
			-1.5, false, false)
	dress.add_child(trail)
	var sparks := EffectFx.particles(EffectFx.TEX_STAR, color.lightened(0.3), maxi(r.count / 4, 1), 0.3, 0.12,
			2.5, 180.0, 3.0, false, false)
	dress.add_child(sparks)
	var ground := EffectFx.light(color, r.knob(&"light_energy", 1.5), r.knob(&"light_range", 2.5))
	ground.name = &"GroundLight"
	dress.add_child(ground)
	ground.position = Vector3(0.0, -dress.position.y + 0.25, 0.0)


## AC 17's rule as a pure function: the SOLID core's radius for a shot of `damage`, growing linearly with the
## mana invested from the minimum staging price (`core_min_radius`) to the mana cap (`core_max_radius`). The
## test pins both ends against the scene's `Hitbox` radius, so a retune of either knob that breaks the size
## honesty rule fails the suite.
static func fireball_core_radius(damage: float, damage_per_mana: float, min_mana: float, mana_cap: float,
		r: EffectPresentationRow) -> float:
	return lerpf(r.knob(&"core_min_radius", 0.15), r.knob(&"core_max_radius", 0.3),
			fireball_growth(damage, damage_per_mana, min_mana, mana_cap))


## 7-1 polish round: the flame ENVELOPE's radius on the same X growth -- not solid, so not bound by AC 17.
static func fireball_envelope_radius(damage: float, damage_per_mana: float, min_mana: float, mana_cap: float,
		r: EffectPresentationRow) -> float:
	return lerpf(r.knob(&"envelope_min_radius", 0.32), r.knob(&"envelope_max_radius", 0.65),
			fireball_growth(damage, damage_per_mana, min_mana, mana_cap))


## Where a shot of `damage` sits between the minimum staging price (0) and the mana cap (1).
static func fireball_growth(damage: float, damage_per_mana: float, min_mana: float, mana_cap: float) -> float:
	var mana := damage / damage_per_mana if damage_per_mana > 0.0 else min_mana
	var span := mana_cap - min_mana
	return clampf((mana - min_mana) / span, 0.0, 1.0) if span > 0.0 else 0.0


## 7-1 polish round: a burning envelope of `radius` around a shot's centre -- flame licks spawned inside the sphere
## and a soft glow behind them, both riding the shot (local).
func _flame_envelope(dress: Node3D, color: Color, radius: float, count: int) -> void:
	var licks := EffectFx.particles(EffectFx.TEX_FLAME, color, count, 0.3, radius * 1.3, 0.5, 180.0, -1.0,
			false, true)
	licks.name = &"FlameEnvelope"
	dress.add_child(EffectFx.prewarm(EffectFx.emit_sphere(licks, radius * 0.6)))
	var glow := EffectFx.quad(EffectFx.TEX_GLOW, color, radius * 2.2, true)
	glow.name = &"EnvelopeGlow"
	dress.add_child(glow)


## 7-1 polish round: the FLARE TRAIL a shot leaves in flight -- world-space glow motes that taper to nothing over
## `knob trail_seconds`, sized from the envelope.
func _flare_trail(color: Color, radius: float, r: EffectPresentationRow) -> GPUParticles3D:
	var trail := EffectFx.particles(EffectFx.TEX_GLOW, color.lightened(0.25), int(r.knob(&"trail_amount", 48.0)),
			r.knob(&"trail_seconds", 0.45), radius * 1.6, 0.1, 180.0, 0.0, false, false)
	trail.name = &"FlareTrail"
	return EffectFx.shrink_over_life(trail)


## The shot's hit-sphere radius, read off `Hitbox/HitboxShape` (0.35 when unreadable).
static func _hit_radius(shot: Node3D) -> float:
	var shape := shot.get_node_or_null("Hitbox/HitboxShape") as CollisionShape3D
	var sphere := shape.shape as SphereShape3D if shape != null else null
	return sphere.radius if sphere != null else 0.35


## A shot ended (AC 16, `7-1/R2`): the ending look at its last hit-centre position.
func end_projectile(position: Vector3, effect_id: StringName, how: int) -> void:
	var r := row_for_effect(effect_id)
	if r == null:
		return
	var color := color_of(r)
	if how == End.VANISH:
		var vanish := row(&"counterspell")
		EffectFx.burst(self, position, EffectFx.TEX_RUNE, color_of(vanish, color), 3, 0.4, 0.9, 0.5)
		return
	if how == End.FIZZLE:
		EffectFx.burst(self, position, EffectFx.TEX_SMOKE, Color(0.5, 0.5, 0.5, 0.5), 6, 0.6, 0.5, 0.6, 180.0,
				0.0, false)
		return
	match r.row_id:
		&"fireball":
			if how == End.SCATTER:
				EffectFx.burst(self, position, EffectFx.TEX_FLAME, color, r.count / 2, 0.35, 0.3, 7.0, 180.0, 4.0)
				EffectFx.burst(self, position, EffectFx.TEX_STAR, color.lightened(0.3), 16, 0.3, 0.15, 8.0)
			else:
				# 7-1 polish round: a BIGGER explosion -- `size` is its flame size; a hot core flash, a shockwave
				# ring on the ground (`knob shockwave_size`) and a stronger light.
				EffectFx.burst(self, position, EffectFx.TEX_FLAME, color, r.count * 2, 0.6, r.size, 5.0, 180.0, -1.0)
				EffectFx.burst(self, position, EffectFx.TEX_GLOW, color.lightened(0.5), r.count / 2, 0.3,
						r.size * 1.2, 2.0, 180.0, 0.0)
				EffectFx.burst(self, position, EffectFx.TEX_SMOKE, Color(0.25, 0.2, 0.18, 0.7), 16, 1.1,
						r.size * 1.3, 1.5, 180.0, -0.5, false)
				EffectFx.burst(self, position, EffectFx.TEX_STAR, color.lightened(0.3), 24, 0.5, 0.2, 9.0, 180.0, 6.0)
				_shockwave(Vector3(position.x, 0.05, position.z), color, r.knob(&"shockwave_size", 4.0), 0.4)
				_flash_light(position, color, r.knob(&"light_energy", 1.5) * 5.0, 8.0, 0.3)
				play_sound(&"fireball", &"fire_hit")
		&"rocksling":
			var spread := 180.0 if how == End.SCATTER else 70.0
			EffectFx.burst(self, position, EffectFx.TEX_DEBRIS, Color(0.55, 0.5, 0.45, 1.0), r.count, r.duration,
					0.3, 4.0, spread, 9.0, false)
			_spawn_rock_chunks(position, 4, r.size * 0.35)
			# AC 12: `rock_hit` per HIT -- a deflected stone (SCATTER) throws its debris silently (review fix P15).
			if how != End.SCATTER:
				play_sound(&"rocksling", &"rock_hit")
		&"corpse_bomb":
			EffectFx.burst(self, position, EffectFx.TEX_DEBRIS, Color(0.92, 0.9, 0.82, 1.0), r.count, r.duration,
					0.28, 5.0, 180.0, 8.0, false)
			EffectFx.burst(self, position, EffectFx.TEX_FLAME, color, r.count / 2, 0.4, 0.6, 2.0)
			play_sound(&"corpse_bomb", &"skull_hit")


## CORPSE BOMB (AC 21): each converted minion glows blue as its skull flies out of it.
func skull_source_glow(minion: Node3D) -> void:
	var r := row(&"corpse_bomb")
	if r == null or not is_instance_valid(minion):
		return
	_overlay_flash(_skin_of(minion), color_of(r), r.duration)
	EffectFx.burst(self, minion.global_position + Vector3(0.0, 0.8, 0.0), EffectFx.TEX_FLAME, color_of(r),
			r.count / 2, r.duration, 0.6, 1.5, 30.0, -2.0)


## ---------------------------------------------------------------------------------------------- persistent

## GRAVE WARD (AC 8): the corpse glows green with ghosts circling above it, LEVEL-TRIGGERED every tick from
## `UnitBoard.is_corpse_extended_at` -- so a Counterspell that removes the extension removes the glow, and the
## corpse leaving state frees it with the actor. `size` = glow radius, `count` = ghosts, `knob orbit_radius`,
## `knob orbit_height`, `knob orbit_seconds`.
func set_grave_ward(corpse: Node3D, extended: bool) -> void:
	if not is_instance_valid(corpse):
		return
	var existing := corpse.get_node_or_null(_GRAVE_WARD_PATH)
	if extended == (existing != null):
		return
	if existing != null:
		_clear_overlay(_skin_of(corpse), &"grave_ward")
		existing.queue_free()
		return
	var r := row(&"grave_ward")
	if r == null:
		return
	var color := color_of(r)
	_set_overlay(_skin_of(corpse), color, r.knob(&"overlay_alpha", 0.3), &"grave_ward")
	var glow := Node3D.new()
	glow.name = GRAVE_WARD_NODE
	corpse.add_child(glow)
	# 7-1 POLISH ROUND (smoke: "glow and ghosts sometimes sit off the corpse"): the death clip carries the body
	# away from the actor root, so the look now FOLLOWS THE CORPSE'S HIPS BONE -- position only (a
	# `RemoteTransform3D` off a hips `BoneAttachment3D`), so the ghosts' orbit stays level on a body lying down. A
	# corpse with no readable hips keeps the look on its root. The ground glow is a DECAL projected straight down
	# from the hips (`size` = its radius), so it lands on the floor under the body at whatever height the hips are.
	var anchor := Node3D.new()
	anchor.name = &"HipsAnchor"
	glow.add_child(anchor)
	var hips := EffectFx.bone_follower(corpse, glow, HIPS_BONE)
	if hips != null:
		var follow := RemoteTransform3D.new()
		follow.update_rotation = false
		follow.update_scale = false
		hips.add_child(follow)
		follow.remote_path = follow.get_path_to(anchor)
	else:
		anchor.position = Vector3(0.0, 0.3, 0.0)
	var pool := Decal.new()
	pool.texture_albedo = EffectFx.TEX_GLOW
	pool.texture_emission = EffectFx.TEX_GLOW
	pool.emission_energy = r.intensity
	pool.modulate = color
	pool.size = Vector3(r.size * 2.0, 3.0, r.size * 2.0)
	anchor.add_child(pool)
	var light := EffectFx.light(color, r.intensity, r.size * 3.0)
	light.position = Vector3(0.0, 0.3, 0.0)
	anchor.add_child(light)
	var pivot := Node3D.new()
	pivot.name = &"Ghosts"
	pivot.position = Vector3(0.0, r.knob(&"orbit_height", 1.6), 0.0)
	anchor.add_child(pivot)
	var radius := r.knob(&"orbit_radius", 0.7)
	var ghost_size := r.knob(&"ghost_size", 0.6)
	for i in maxi(r.count, 1):
		var ghost := EffectFx.quad(EffectFx.TEX_WISP, Color(color.r, color.g, color.b, 0.8), ghost_size, true)
		var core := EffectFx.quad(EffectFx.TEX_GLOW, Color(color.r, color.g, color.b, 0.6), ghost_size * 0.5, true)
		ghost.add_child(core)
		var angle := TAU * float(i) / float(maxi(r.count, 1))
		ghost.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		pivot.add_child(ghost)
	var orbit := pivot.create_tween().set_loops()
	orbit.tween_property(pivot, "rotation:y", TAU, r.knob(&"orbit_seconds", 2.5)).from(0.0)


## THE PER-HERO PERSISTENT LOOKS (AC 11, 13, 15, 20, 22, 28), pushed every tick by the runner as plain levels.
## Each look is built on its first true and freed on its first false, so nothing lingers past its state.
func update_hero(slot: int, hero: Node3D, aura: bool, mist: bool, roll_trail: bool, frost_weapon: bool,
		frozen_legs: bool, boulders: int, stun_sparks: bool, shackles: bool) -> void:
	if not is_instance_valid(hero):
		return
	_toggle(slot, hero, &"Aura", aura)
	_toggle(slot, hero, &"Mist", mist)
	_toggle(slot, hero, &"RollTrail", roll_trail)
	_toggle(slot, hero, &"FrostWeapon", frost_weapon)
	_toggle(slot, hero, &"FrozenLegs", frozen_legs)
	_toggle(slot, hero, &"StunSparks", stun_sparks)
	_toggle(slot, hero, &"Shackles", shackles)
	_toggle(slot, hero, &"BoulderCrust", boulders > 0)
	var crust: Variant = _hero_nodes[slot].get(&"BoulderCrust")
	if is_instance_valid(crust):
		_set_crust(crust as Node3D, boulders)
	# Frostbite (AC 20): `frost_hit` on the CONSUMING hit -- the rising edge of the slow on its target.
	if frozen_legs and not _frozen_last[slot]:
		play_sound(&"frostbite", &"frost_hit")
	_frozen_last[slot] = frozen_legs


## The look named `look` on `slot`'s hero, or null -- for tests.
func hero_look(slot: int, look: StringName) -> Node3D:
	var node: Variant = _hero_nodes[slot].get(look)
	return node as Node3D if is_instance_valid(node) else null


func _toggle(slot: int, hero: Node3D, look: StringName, on: bool) -> void:
	var node: Variant = _hero_nodes[slot].get(look)
	var present := is_instance_valid(node)
	if on == present:
		return
	if present:
		_hero_nodes[slot].erase(look)
		# Bloodhound's mist and roll trail are WORLD-SPACE particles left behind the hero: on the falling edge
		# they stop emitting and are freed once their last particle has lived out (review fix P13), so the
		# trail dissipates instead of vanishing.
		if node is GPUParticles3D and (look == &"Mist" or look == &"RollTrail"):
			var trail := node as GPUParticles3D
			trail.emitting = false
			EffectFx.free_after(trail, trail.lifetime)
		else:
			(node as Node).queue_free()
		return
	var built := _build_hero_look(look, hero)
	if built != null:
		built.name = look
		_hero_nodes[slot][look] = built


func _build_hero_look(look: StringName, hero: Node3D) -> Node3D:
	match look:
		&"Aura":
			# VAMPIRIC AURA: a green aura on the body for the rule's whole run. `size` = aura radius, `count` =
			# particles, `intensity` = glow energy.
			var r := row(&"vampiric_aura")
			if r == null:
				return null
			# 7-1 POLISH ROUND ("clearly more visible"): besides the rising swirl, glowing motes hug the WHOLE BODY
			# (a box the hero's size, `knob body_motes` of them, `knob mote_size`), a ground ring under the feet and
			# a stronger light; all in the card green lightened so they read against the model.
			var color := color_of(r).lightened(0.2)
			var node := Node3D.new()
			hero.add_child(node)
			var swirl := EffectFx.particles(EffectFx.TEX_SWIRL, color, r.count, 1.2, r.size * 0.8, 0.8,
					20.0, -1.0, false, true)
			swirl.position = Vector3(0.0, HERO_FEET_Y + 0.2, 0.0)
			node.add_child(EffectFx.prewarm(swirl))
			var motes := EffectFx.particles(EffectFx.TEX_GLOW, color, int(r.knob(&"body_motes", 40.0)), 0.9,
					r.knob(&"mote_size", 0.3), 0.4, 15.0, -0.6, false, true)
			motes.position = Vector3(0.0, -0.1, 0.0)
			node.add_child(EffectFx.prewarm(EffectFx.emit_box(motes, Vector3(0.35, 0.8, 0.35))))
			var ring := EffectFx.quad(EffectFx.TEX_RING, color, r.size * 1.6, false, false)
			ring.position = Vector3(0.0, HERO_FEET_Y + 0.03, 0.0)
			node.add_child(ring)
			var spin := ring.create_tween().set_loops()
			spin.tween_property(ring, "rotation:y", TAU, 3.0).from(0.0)
			var light := EffectFx.light(color, r.intensity, r.size * 2.5)
			node.add_child(light)
			return node
		&"Mist", &"RollTrail":
			# BLOODHOUND STEP: red mist behind the hero while the window runs (world-space particles left
			# behind as the hero moves); the boosted roll leaves a denser trail for that roll only.
			var r := row(&"bloodhound_step")
			if r == null:
				return null
			var trail := look == &"RollTrail"
			var p := EffectFx.particles(EffectFx.TEX_WISP if trail else EffectFx.TEX_SMOKE, color_of(r),
					r.count * (2 if trail else 1), r.duration * (1.5 if trail else 1.0), r.size,
					0.2, 30.0, -0.3, false, false, not trail)
			hero.add_child(p)
			p.position = Vector3(0.0, HERO_LEGS_Y + 0.2, 0.0)
			return p
		&"FrostWeapon":
			# FROSTBITE: the weapon is frosted while the trigger is armed -- a glow and glints riding the
			# paladin's sword joint (the bone the Hitbox already follows, `5-0a`).
			var r := row(&"frostbite")
			if r == null:
				return null
			# 7-1 POLISH ROUND (smoke: "barely visible"): an ICE-WHITE look -- the card blue lightened (`knob
			# ice_lighten`) -- around the whole blade rather than a dot at the joint: glints spawned through a
			# sphere of `knob weapon_radius`, a frost mist trailing the swing, a glow and an ice-blue light
			# (`intensity`).
			var attach := _bone_attachment(hero, SWORD_BONE)
			var ice := color_of(r).lightened(r.knob(&"ice_lighten", 0.55))
			var reach := r.knob(&"weapon_radius", 0.45)
			var glints := EffectFx.particles(EffectFx.TEX_STAR, ice, r.count * 2, 0.6, r.size * 0.3, 0.3,
					180.0, 0.0, false, false)
			attach.add_child(EffectFx.prewarm(EffectFx.emit_sphere(glints, reach)))
			var mist := EffectFx.particles(EffectFx.TEX_SMOKE, Color(ice.r, ice.g, ice.b, 0.55), r.count, 0.5,
					r.size * 0.6, 0.15, 180.0, 0.3, false, false, false)
			attach.add_child(EffectFx.emit_sphere(mist, reach * 0.8))
			var glow := EffectFx.quad(EffectFx.TEX_GLOW, ice, r.size * 2.0, true)
			attach.add_child(glow)
			var light := EffectFx.light(ice, r.intensity, reach * 4.0)
			attach.add_child(light)
			return attach
		&"FrozenLegs":
			# FROSTBITE: on the consuming hit the target's legs freeze for as long as the slow runs.
			var r := row(&"frostbite")
			if r == null:
				return null
			return _leg_shell(hero, color_of(r), 0.45, EffectFx.TEX_STAR, r.count)
		&"BoulderCrust":
			# BOULDER SLOW: stone crust on the legs; the amount follows the live Boulder count (`_set_crust`).
			var r := row(&"boulder_slow")
			if r == null:
				return null
			var crust := Node3D.new()
			hero.add_child(crust)
			var pieces := maxi(r.count, 1) * int(r.knob(&"max_boulders", 4.0))
			var cached: Array[Node3D] = []
			crust.set_meta(_CRUST_PIECES_META, cached)
			# 7-1 POLISH ROUND (smoke: "the pieces hover around the target"): the pieces now SIT ON THE LEGS --
			# each one rides a leg bone (`EffectFx.bone_follower`), placed around the bone's own axis (`knob
			# leg_radius` out from it) along its length. The first half of the pieces alternate on the two shins,
			# the second half on the thighs, so more Boulders climb the legs. No skeleton: the old ring at the feet.
			var bones: Array[Node3D] = []
			for bone: StringName in LEG_BONES:
				var follower := EffectFx.bone_follower(hero, crust, bone)
				if follower == null:
					bones.clear()
					break
				bones.append(follower)
			var leg_radius := r.knob(&"leg_radius", 0.08)
			for i in pieces:
				var rock := _rock_instance(r.size * _rng.randf_range(0.8, 1.25))
				rock.rotation = Vector3(_rng.randf_range(0, TAU), _rng.randf_range(0, TAU), 0.0)
				rock.visible = false
				if bones.is_empty():
					var angle := TAU * float(i) / float(pieces) * 2.0 + _rng.randf_range(-0.3, 0.3)
					var ring := 0.32 + 0.04 * float(i % 3)
					rock.position = Vector3(cos(angle) * ring, HERO_FEET_Y + 0.1 + 0.22 * float(i % 3),
							sin(angle) * ring)
					crust.add_child(rock)
				else:
					var upper := 2 if i >= pieces / 2 else 0
					var on_leg := (i % (pieces / 2)) / 2 if pieces >= 2 else 0
					var per_leg := maxi(pieces / 4, 1)
					var around := TAU * float(on_leg) / float(per_leg) + _rng.randf_range(-0.4, 0.4)
					var along := lerpf(0.08, 0.34, float(on_leg) / float(per_leg))
					rock.position = Vector3(cos(around) * leg_radius, along, sin(around) * leg_radius)
					bones[upper + i % 2].add_child(rock)
				cached.append(rock)
			return crust
		&"StunSparks":
			# STUN (AC 22): the dizzy clip stays; sparks above the head for a bolt stun.
			# 7-1 POLISH ROUND: brighter and bigger so the short stun reads (`knob spark_size`, `knob
			# spark_count`, a flash light of `intensity`), and FULL ON ITS FIRST FRAME (prewarmed). Still
			# level-triggered: freed the tick the stun ends, never extended past it.
			var r := row(&"stun_root")
			if r == null:
				return null
			var bright := color_of(r).lightened(0.5)
			var sparks := EffectFx.particles(EffectFx.TEX_SPARK, bright, int(r.knob(&"spark_count", 24.0)), 0.35,
					r.knob(&"spark_size", 0.55), 1.6, 90.0, 0.0, false, true)
			sparks.position = Vector3(0.0, HERO_HEAD_Y, 0.0)
			hero.add_child(EffectFx.prewarm(EffectFx.emit_sphere(sparks, 0.25)))
			var light := EffectFx.light(bright, r.intensity, 2.5)
			sparks.add_child(light)
			return sparks
		&"Shackles":
			# ROOT (AC 22): blue electric shackles around the legs while the root is in force.
			var r := row(&"stun_root")
			if r == null:
				return null
			var node := Node3D.new()
			hero.add_child(node)
			for i in 2:
				var ring := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = r.size * 0.55
				torus.outer_radius = r.size * 0.62
				ring.mesh = torus
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.albedo_color = color_of(r).lightened(0.3)
				ring.material_override = mat
				ring.position = Vector3(0.0, HERO_FEET_Y + 0.25 + 0.3 * i, 0.0)
				node.add_child(ring)
				var spin := ring.create_tween().set_loops()
				spin.tween_property(ring, "rotation:y", TAU * (1 if i == 0 else -1), 0.8).from(0.0)
			var crackle := EffectFx.particles(EffectFx.TEX_SPARK, color_of(r), r.count, 0.25, 0.35, 0.8, 180.0,
					0.0, false, true)
			crackle.position = Vector3(0.0, HERO_LEGS_Y, 0.0)
			node.add_child(crackle)
			return node
	return null


func _set_crust(crust: Node3D, boulders: int) -> void:
	var r := row(&"boulder_slow")
	var per := maxi(r.count, 1) if r != null else 1
	var show := boulders * per
	# The pieces list cached at build time (review fix P6): `get_children()` would allocate an Array every tick.
	var pieces: Array[Node3D] = crust.get_meta(_CRUST_PIECES_META)
	for i in pieces.size():
		pieces[i].visible = i < show


## ---------------------------------------------------------------------------------------------- teardown

## AC 32: the round ended -- every transient look and every looped sound stops; the persistent looks are
## switched off by the runner's poll, which pushes "off" for the whole round-over freeze.
func clear_transient() -> void:
	stop_all_sounds()
	for slot in 2:
		stop_bolt_charge(slot)
	# A presenter-bound sequence (Boom) is not a child, so freeing the children would not stop it (review fix P7).
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	for child in get_children():
		child.queue_free()


## Remember a presenter-bound sequence tween so `clear_transient` can kill it; finished ones are pruned here.
func _track(tween: Tween) -> void:
	var live: Array[Tween] = []
	for t: Tween in _tweens:
		if t != null and t.is_valid():
			live.append(t)
	_tweens = live
	_tweens.append(tween)


## AC 32: STOP every effect sound this presenter started -- one-shots, the loops riding on shots, the bolt charge.
## A loop's restart is disconnected first so `finished` cannot start it again.
##
## A STOPPED PLAYBACK IS RETIRED BY THE AUDIO MIXER ON A LATER MIX AND CLEANED UP BY THE MAIN LOOP'S PER-FRAME
## AUDIO UPDATE, so anything that tears the scene down (a test's `quit()`) and wants no "resources still in use at
## exit" report must call this a frame -- or an `OS.delay_msec` -- before it goes: a sound still playing when the
## nodes are freed is stopped too late for that cleanup to run (measured at this pass; the
## `test_cast_success_cue_live.gd` stop-then-wait remedy is the same finding).
func stop_all_sounds() -> void:
	for p: Variant in _players:
		if not is_instance_valid(p):
			continue
		var player := p as AudioStreamPlayer
		if player.finished.is_connected(player.play):
			player.finished.disconnect(player.play)
		player.stop()
	_players.clear()
	_loops.clear()


## AC 32: the debug reset -- everything, persistent looks included (their actors may be freed with it).
func clear_all() -> void:
	clear_transient()
	for slot in 2:
		for node: Variant in _hero_nodes[slot].values():
			if is_instance_valid(node):
				(node as Node).queue_free()
		_hero_nodes[slot].clear()
		_frozen_last[slot] = false


## ---------------------------------------------------------------------------------------------- helpers

## A glowing mote flying from `from` to `target`'s live position over `seconds`, then gone.
func _fly(from: Vector3, target: Node3D, offset: Vector3, seconds: float, texture: Texture2D, color: Color,
		size: float) -> void:
	var mote := EffectFx.quad(texture, color, size, true)
	add_child(mote)
	mote.global_position = from
	var trail := EffectFx.particles(texture, color, 10, 0.3, size * 0.6, 0.1, 10.0, 0.0, false, false)
	mote.add_child(trail)
	var tween := mote.create_tween()
	tween.tween_method(_fly_step.bind(mote, from, target, offset), 0.0, 1.0, maxf(seconds, 0.01))
	tween.tween_callback(mote.queue_free)


func _fly_step(t: float, mote: Variant, from: Vector3, target: Variant, offset: Vector3) -> void:
	if not is_instance_valid(mote):
		return
	var node := mote as Node3D
	var to := ((target as Node3D).global_position + offset) if is_instance_valid(target) else node.global_position
	var arc := Vector3(0.0, sin(t * PI) * 0.8, 0.0)
	node.global_position = from.lerp(to, t * t) + arc


func _flash_light(position: Vector3, color: Color, energy: float, light_range: float, seconds: float) -> void:
	var light := EffectFx.light(color, energy, light_range)
	add_child(light)
	light.global_position = position
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, maxf(seconds, 0.01))
	tween.tween_callback(light.queue_free)


## A flat ring on the ground at `position`, expanding to `size` across and fading over `seconds`.
func _shockwave(position: Vector3, color: Color, size: float, seconds: float) -> void:
	# Opaque-blended, not additive: the ground is light, and adding colour to it barely shows (the rune finding).
	var ring := EffectFx.quad(EffectFx.TEX_RING, color, 1.0, false, false)
	add_child(ring)
	ring.global_position = position
	ring.scale = Vector3.ONE * 0.2
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * size, seconds).set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring.material_override, "albedo_color:a", 0.0, seconds)
	tween.chain().tween_callback(ring.queue_free)


func _fade_out(node: MeshInstance3D, seconds: float) -> void:
	var mat := node.material_override as StandardMaterial3D
	var tween := node.create_tween()
	tween.tween_interval(seconds * 0.6)
	if mat != null:
		tween.tween_property(mat, "albedo_color:a", 0.0, seconds * 0.4)
	tween.tween_callback(node.queue_free)


func _spin(node: Node3D, seconds: float) -> void:
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "rotation", Vector3(TAU, TAU * 0.5, 0.0), maxf(seconds, 0.05)).from(Vector3.ZERO)


## The real rock model, scaled so its longest extent is `size` metres, wearing the 1024 px rock textures.
func _rock_instance(size: float) -> Node3D:
	var rock := ROCK_SCENE.instantiate() as Node3D
	var aabb := _aabb_of(rock)
	var longest := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var holder := Node3D.new()
	holder.add_child(rock)
	if longest > 0.0:
		rock.scale = Vector3.ONE * (size / longest)
		rock.position = -aabb.get_center() * (size / longest)
	for mesh: Node in rock.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = _rock_material
	return holder


func _spawn_rock_chunks(position: Vector3, count: int, size: float) -> void:
	for i in count:
		var chunk := _rock_instance(size * _rng.randf_range(0.6, 1.2))
		add_child(chunk)
		chunk.global_position = position
		var to := position + Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(0.3, 1.0), _rng.randf_range(-1.2, 1.2))
		var tween := chunk.create_tween()
		tween.tween_property(chunk, "global_position", to, 0.25).set_ease(Tween.EASE_OUT)
		tween.tween_property(chunk, "global_position:y", position.y - 0.1, 0.3).set_ease(Tween.EASE_IN)
		tween.tween_property(chunk, "scale", Vector3.ZERO, 0.3)
		tween.tween_callback(chunk.queue_free)


static func _aabb_of(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := _relative_transform(mesh, root) * mesh.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var t := node.transform
	var walk := node.get_parent()
	while walk != null and walk != root and walk is Node3D:
		t = (walk as Node3D).transform * t
		walk = walk.get_parent()
	return t


## The shot's hit-centre, in the shot's local frame -- read off `Hitbox/HitboxShape`, so the look is concentric
## with the hit sphere by construction (AC 17) and a moved hitbox moves the look with it.
static func _hit_centre_local(shot: Node3D) -> Vector3:
	var shape := shot.get_node_or_null("Hitbox/HitboxShape") as Node3D
	return shape.position if shape != null else Vector3(0.0, 0.7, 0.0)


func _bone_attachment(hero: Node3D, bone: StringName) -> Node3D:
	var skeletons := hero.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		var fallback := Node3D.new()
		hero.add_child(fallback)
		return fallback
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	(skeletons[0] as Node).add_child(attach)
	return attach


func _leg_shell(hero: Node3D, color: Color, radius: float, texture: Texture2D, count: int) -> Node3D:
	var node := Node3D.new()
	hero.add_child(node)
	var shell := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.8
	cylinder.bottom_radius = radius
	cylinder.height = 0.8
	shell.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.45).lightened(0.35)
	shell.material_override = mat
	shell.position = Vector3(0.0, HERO_FEET_Y + 0.4, 0.0)
	node.add_child(shell)
	var glints := EffectFx.particles(texture, color.lightened(0.4), count, 0.6, 0.15, 0.2, 180.0, 0.0,
			false, true)
	glints.position = Vector3(0.0, HERO_LEGS_Y, 0.0)
	node.add_child(glints)
	return node


## The meshes that ARE the body: a hero's `Mesh` model subtree, or every mesh of a unit except looks this
## presenter parented onto it.
func _skin_of(actor: Node3D) -> Array[MeshInstance3D]:
	if actor is HeroActor:
		return _hero_skin(actor)
	var out: Array[MeshInstance3D] = []
	for node: Node in actor.find_children("*", "MeshInstance3D", true, false):
		if _is_effect_look(node, actor):
			continue
		out.append(node as MeshInstance3D)
	return out


func _hero_skin(hero: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if not is_instance_valid(hero):
		return out
	var model := hero.get_node_or_null("Mesh")
	if model == null:
		return out
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).mesh is PrimitiveMesh:
			continue  # FacingMarker and friends -- markers, not the body
		out.append(node as MeshInstance3D)
	return out


func _is_effect_look(node: Node, actor: Node) -> bool:
	var walk := node
	while walk != null and walk != actor:
		if walk.name == GRAVE_WARD_NODE or walk.name == DRESS_NODE:
			return true
		walk = walk.get_parent()
	return false


## A coloured additive OVERLAY pass on each body mesh -- `material_overlay`, never the mesh's own material, so
## the base look is untouched and the overlay can be removed exactly. Tagged so a flash can restore the ward.
func _set_overlay(meshes: Array[MeshInstance3D], color: Color, alpha: float, tag: StringName) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	for mesh: MeshInstance3D in meshes:
		mesh.material_overlay = mat
		mesh.set_meta(&"effect_overlay", tag)


func _clear_overlay(meshes: Array[MeshInstance3D], tag: StringName) -> void:
	for mesh: MeshInstance3D in meshes:
		if mesh.get_meta(&"effect_overlay", &"") == tag:
			mesh.material_overlay = null
			mesh.remove_meta(&"effect_overlay")


func _overlay_flash(meshes: Array[MeshInstance3D], color: Color, seconds: float) -> void:
	var previous: Array = []
	for mesh: MeshInstance3D in meshes:
		previous.append([mesh, mesh.material_overlay, mesh.get_meta(&"effect_overlay", &"")])
	_set_overlay(meshes, color, 0.55, &"flash")
	var tween := create_tween()
	tween.tween_interval(maxf(seconds, 0.01))
	tween.tween_callback(_restore_overlays.bind(previous))


func _restore_overlays(previous: Array) -> void:
	for entry: Array in previous:
		var mesh: Variant = entry[0]
		if not is_instance_valid(mesh):
			continue
		var m := mesh as MeshInstance3D
		if m.get_meta(&"effect_overlay", &"") != &"flash":
			continue
		m.material_overlay = entry[1]
		if entry[2] == &"":
			m.remove_meta(&"effect_overlay")
		else:
			m.set_meta(&"effect_overlay", entry[2])


func _tint_all(root: Node3D, color: Color, alpha: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)
	_set_overlay(meshes, color, alpha, &"tint")
