extends SceneTree

## Story 7-1 (AC 29/AC 27/AC 30, `7-1/R6`): EVERY SCOPE ROW HAS AN AUTHORED KNOB SET, and the knob home is
## presentation-only.
##
## THE ROW LIST IS DERIVED FROM ONE SOURCE (`7-T1/R4`'s guard style): `EffectPresentationSet.ROW_SOUND_SLOTS`,
## the same dictionary `EffectPresenter.play_sound` refuses any unlisted slot against. There is no second,
## hand-kept list here -- a row added to the Scope with no authored set, or a sound slot named with no stream,
## fails this file.
##
## Asserted, per row: a row exists in the authored set; its size and count are positive (a row whose look would
## draw at zero size has no authored knob set in any meaningful sense); every sound slot it names has an
## `AudioStream`; its colour selects an entry of the existing vocabulary (`Enums.CardColor`, AC 27); every effect
## id it claims is a real authored `CardEffect.effect_id`; a row that silences the generic cue has a sound of its
## own (`7-1/R4`). And the home: the authored file is not under `data/effects/`, and no `src/state/` file names
## the knob classes (`7-1/R6`).
##
## Run: godot --headless --path . --script res://test/integration/test_effect_presentation_knobs.gd

const EFFECTS_DIR := "res://data/effects/"

var _failures: Array[String] = []


func _initialize() -> void:
	var knob_set := load(EffectPresentationSet.AUTHORED_PATH) as EffectPresentationSet
	_check(knob_set != null, "the authored knob set loads as EffectPresentationSet")
	_check(not EffectPresentationSet.AUTHORED_PATH.begins_with(EFFECTS_DIR),
		"the knob set must not live under data/effects/ (7-1/R6)")
	var effect_ids := _authored_effect_ids()
	_check(effect_ids.size() > 0, "found authored CardEffect ids (guard would be vacuous)")
	var rows_checked := 0
	if knob_set != null:
		for row_id: StringName in EffectPresentationSet.ROW_SOUND_SLOTS:
			rows_checked += 1
			var row := knob_set.row(row_id)
			if row == null:
				_failures.append("Scope row '%s' has no authored knob set" % row_id)
				continue
			_check(row.size > 0.0, "row '%s': size must be authored > 0" % row_id)
			_check(row.count > 0, "row '%s': count must be authored > 0" % row_id)
			_check(row.duration >= 0.0 and row.spacing >= 0.0, "row '%s': no negative duration/spacing" % row_id)
			_check(int(row.card_color) >= 0 and int(row.card_color) <= int(Enums.CardColor.COLORLESS),
				"row '%s': card_color must be an Enums.CardColor" % row_id)
			var slots: Array = EffectPresentationSet.ROW_SOUND_SLOTS[row_id]
			for slot: StringName in slots:
				_check(row.sounds.get(slot) is AudioStream, "row '%s': sound slot '%s' has no stream" % [row_id, slot])
			for key: Variant in row.sounds:
				_check(slots.has(key), "row '%s': authored sound '%s' is not a slot of this row" % [row_id, key])
			for id: String in row.effect_ids:
				_check(effect_ids.has(id), "row '%s': effect id '%s' is not an authored CardEffect" % [row_id, id])
			if row.silences_generic_cue:
				_check(not slots.is_empty(), "row '%s' silences the generic cue but has no sound" % row_id)
		_check(knob_set.rows.size() == EffectPresentationSet.ROW_SOUND_SLOTS.size(),
			"the authored set has exactly one row per Scope row (%d vs %d)"
					% [knob_set.rows.size(), EffectPresentationSet.ROW_SOUND_SLOTS.size()])
	# Story 7-3 (AC 15): sixteen -> seventeen, the `hellhound` row (its spawn sound and its bark).
	# Story 7-5b (AC 23): seventeen -> twenty, the `healer`, `elemental_fury` and `wrath_of_god` rows.
	_check(rows_checked == 20, "the Scope table has twenty rows, walked %d" % rows_checked)
	# Story 7-3, feel pass: THE HELLHOUND ROW'S NEW KNOBS ARE AUTHORED AND BOUNDED (the presentation
	# half of the authoring audit; the kind's own numbers are bounded in test_balance_authoring.gd).
	# Each band is the condition under which the knob still does its job.
	var hound := knob_set.row(&"hellhound") if knob_set != null else null
	if hound != null:
		for knob: StringName in [&"blend_seconds", &"spawn_flank_distance", &"stalk_rate",
				&"locomotion_rate_min", &"locomotion_rate_max", &"heading_forward_degrees",
				&"heading_hold_degrees"]:
			_check(hound.extra.has(knob), "row 'hellhound': knob '%s' is not authored" % knob)
		var blend := hound.knob(&"blend_seconds", -1.0)
		_check(blend > 0.0 and blend <= 0.3,
				"row 'hellhound': blend_seconds %.3f must be in (0, 0.3] -- a crossfade, and shorter than a bite's windup" % blend)
		var flank := hound.knob(&"spawn_flank_distance", -1.0)
		_check(flank >= 0.5 and flank <= 2.5,
				"row 'hellhound': spawn_flank_distance %.2f must be in [0.5, 2.5] -- two spots a spawn clearance apart, beside the summoner" % flank)
		var stalk := hound.knob(&"stalk_rate", -1.0)
		_check(stalk > 0.0 and stalk < 1.0, "row 'hellhound': stalk_rate %.2f must slow the idle (0 < rate < 1)" % stalk)
		var rate_min := hound.knob(&"locomotion_rate_min", -1.0)
		var rate_max := hound.knob(&"locomotion_rate_max", -1.0)
		_check(rate_min > 0.0 and rate_min <= 1.0 and rate_max >= 1.0 and rate_max <= 4.0,
				"row 'hellhound': the locomotion rate bounds %.2f..%.2f must bracket 1.0 inside (0, 4]" % [rate_min, rate_max])
		var sector := hound.knob(&"heading_forward_degrees", -1.0)
		var hold := hound.knob(&"heading_hold_degrees", -1.0)
		_check(sector >= 30.0 and sector <= 60.0 and hold >= 0.0 and hold <= 20.0 and sector + hold < 90.0 - hold,
				"row 'hellhound': heading sectors %.0f deg held %.0f deg -- forward and backward must be 30 to 60 wide, held by at most 20, and leave the two sides room"
						% [sector, hold])
		_check(float(hound.volume_db.get(&"bark", 0.0)) <= -12.0,
				"row 'hellhound': the bark plays at %.1f dB, want -12 or quieter (the live smoke)"
						% float(hound.volume_db.get(&"bark", 0.0)))
		# Feel pass 2: THE HOUND'S VOICES. Every voice has an authored volume inside its band, every
		# voice but the yelp has two or three variants (and the yelp none: no file was supplied), every
		# variant slot belongs to a voice, and the six voice knobs are authored and bounded.
		var voices: Array = EffectPresentationSet.ROW_VOICES.get(&"hellhound", [])
		_check(voices == [&"growl", &"bark", &"bite", &"leap", &"yelp", &"death"],
				"row 'hellhound': the voice list is %s" % [voices])
		var bands := {&"growl": [-30.0, -16.0], &"bark": [-24.0, -12.0], &"bite": [-16.0, -4.0],
				&"leap": [-18.0, -6.0], &"yelp": [-18.0, -6.0], &"death": [-16.0, -4.0]}
		var variant_slots := 0
		for voice: StringName in voices:
			_check(hound.volume_db.has(voice), "row 'hellhound': voice '%s' has no authored volume" % voice)
			var db := float(hound.volume_db.get(voice, 99.0))
			_check(db >= float(bands[voice][0]) and db <= float(bands[voice][1]),
					"row 'hellhound': voice '%s' plays at %.1f dB, outside its band %s" % [voice, db, bands[voice]])
			var variants := 0
			for slot: StringName in EffectPresentationSet.ROW_SOUND_SLOTS[&"hellhound"]:
				if String(slot).begins_with("%s_" % voice):
					variants += 1
					var stream := hound.sounds.get(slot) as AudioStream
					_check(stream != null and stream.resource_path.begins_with("res://assets/audio/effects/hellhound/"),
							"row 'hellhound': variant '%s' is not a file under assets/audio/effects/hellhound/" % slot)
			variant_slots += variants
			if voice == &"yelp":
				_check(variants == 0, "row 'hellhound': the yelp has %d variants; no file was supplied for it" % variants)
			else:
				_check(variants >= 2 and variants <= 3, "row 'hellhound': voice '%s' has %d variants, want 2 or 3" % [voice, variants])
		_check(variant_slots + 1 == (EffectPresentationSet.ROW_SOUND_SLOTS[&"hellhound"] as Array).size(),
				"row 'hellhound': a sound slot is neither the summon nor a variant of a voice")
		_check(float(hound.volume_db.get(&"growl", 0.0)) < float(hound.volume_db.get(&"bark", 0.0))
				and float(hound.volume_db.get(&"bark", 0.0)) < float(hound.volume_db.get(&"bite", 0.0)),
				"row 'hellhound': the growl is quieter than the bark, and the bark than the bite's snap")
		for bound: Array in [[&"voice_distance", 10.0, 60.0], [&"voice_cap", 1.0, 2.0],
				[&"voice_pitch_spread", 0.02, 0.25], [&"voice_pitch_variation", 0.0, 0.1],
				[&"growl_interval_seconds", 2.0, 20.0], [&"growl_chance", 0.05, 0.75]]:
			_check(hound.extra.has(bound[0]), "row 'hellhound': knob '%s' is not authored" % bound[0])
			var value := hound.knob(bound[0], -1.0)
			_check(value >= float(bound[1]) and value <= float(bound[2]),
					"row 'hellhound': %s %.3f is outside [%.2f, %.2f]" % [bound[0], value, bound[1], bound[2]])
		_check(hound.knob(&"voice_cap", 0.0) == floorf(hound.knob(&"voice_cap", 0.0)), "row 'hellhound': voice_cap is a whole number")
		_check(EffectPresentationSet.UNCAPPED_VOICES == ([&"bite", &"yelp"] as Array[StringName]),
				"the voices the cap leaves alone are %s, want the bite's snap and the yelp" % [EffectPresentationSet.UNCAPPED_VOICES])
		_check(not ResourceLoader.exists("res://assets/audio/effects/sfx_hound_bark.tres"),
				"the synthesized placeholder bark is still in the tree")
	# Story 7-5b smoke fix 1 (S3, S4, S5, S8): THE HEALER ROW'S KNOBS ARE AUTHORED AND BOUNDED, each band the
	# condition under which the knob still does its job.
	var healer := knob_set.row(&"healer") if knob_set != null else null
	_check(healer != null, "the `healer` row is authored")
	if healer != null:
		for bound: Array in [[&"blend_seconds", 0.05, 0.3], [&"cast_seconds", 0.5, 2.0],
				[&"shoot_face_hold_seconds", 0.2, 1.5], [&"heal_thread_seconds", 0.1, 1.0],
				[&"heal_thread_width", 0.01, 0.2], [&"heal_flash_seconds", 0.1, 1.0], [&"heal_hand_size", 0.1, 1.0],
				[&"heal_sparkle_count", 4.0, 64.0], [&"heal_sparkle_seconds", 0.2, 2.0],
				# Smoke fix 2 (S15a): a dead zone that still lets the body face its owner (0) or ever turn (90), and a
				# re-aim rate that still turns (0) without spinning its turn clip into a blur.
				[&"turn_dead_zone_degrees", 5.0, 45.0], [&"reaim_turn_rate_degrees_per_second", 30.0, 360.0]]:
			_check(healer.extra.has(bound[0]), "row 'healer': knob '%s' is not authored" % bound[0])
			var value := healer.knob(bound[0], -1.0)
			_check(value >= float(bound[1]) and value <= float(bound[2]),
					"row 'healer': %s %.3f is outside [%.2f, %.2f]" % [bound[0], value, bound[1], bound[2]])
		var rate_min := healer.knob(&"locomotion_rate_min", -1.0)
		var rate_max := healer.knob(&"locomotion_rate_max", -1.0)
		_check(rate_min > 0.0 and rate_min <= 1.0 and rate_max >= 1.0 and rate_max <= 4.0,
				"row 'healer': the locomotion rate bounds %.2f..%.2f must bracket 1.0 inside (0, 4]" % [rate_min, rate_max])
		# The walk/idle HYSTERESIS: two thresholds, the exit strictly below the enter, both well under a walk.
		var enter := healer.knob(&"walk_enter_speed", -1.0)
		var exit := healer.knob(&"walk_exit_speed", -1.0)
		_check(exit > 0.0 and exit < enter and enter < 1.5,
				"row 'healer': walk_exit_speed %.2f and walk_enter_speed %.2f must be a band 0 < exit < enter < 1.5 m/s"
						% [exit, enter])
	# Story 7-5b smoke fix 2 (S13): THE WRATH OF GOLD LOOK'S KNOBS ARE AUTHORED AND BOUNDED -- the wave expands in about
	# a quarter second and fades in about half (the ruling's numbers), its edge sheet is about a metre, the shake may
	# be OFF (0) but is short, and the gold is a colour.
	var wrath := knob_set.row(&"wrath_of_god") if knob_set != null else null
	_check(wrath != null, "the `wrath_of_god` row is authored")
	if wrath != null:
		for bound: Array in [[&"wave_seconds", 0.1, 0.5], [&"afterglow_seconds", 0.2, 1.0], [&"wall_height", 0.5, 2.0],
				[&"shake_seconds", 0.0, 0.6], [&"shake_amplitude", 0.0, 0.3], [&"column_height", 1.0, 12.0],
				[&"glow_size_min", 0.0, 1.0], [&"glow_size_max", 0.2, 2.0], [&"hit_seconds", 0.1, 1.0],
				[&"gold_r", 0.0, 1.0], [&"gold_g", 0.0, 1.0], [&"gold_b", 0.0, 1.0],
				[&"ring_alpha_start", 0.1, 1.0], [&"ring_alpha_end", 0.1, 1.0]]:
			_check(wrath.extra.has(bound[0]), "row 'wrath_of_god': knob '%s' is not authored" % bound[0])
			var value := wrath.knob(bound[0], -1.0)
			_check(value >= float(bound[1]) and value <= float(bound[2]),
					"row 'wrath_of_god': %s %.3f is outside [%.2f, %.2f]" % [bound[0], value, bound[1], bound[2]])
		_check(wrath.knob(&"glow_size_max", 0.0) > wrath.knob(&"glow_size_min", 0.0),
				"row 'wrath_of_god': the hand light must GROW over the windup (glow_size_max > glow_size_min)")
		_check(wrath.knob(&"ring_alpha_end", 0.0) > wrath.knob(&"ring_alpha_start", 0.0),
				"row 'wrath_of_god': the ring must BRIGHTEN toward the pulse (ring_alpha_end > ring_alpha_start)")
	for path: String in _gd_files("res://src/state/"):
		var text := FileAccess.get_file_as_string(path)
		for token: String in ["EffectPresentation", "EffectPresenter", "data/presentation"]:
			_check(not text.contains(token), "%s names %s -- the knobs are presentation-only (7-1/R6)" % [path, token])
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _authored_effect_ids() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(EFFECTS_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			var effect := load(EFFECTS_DIR + f) as CardEffect
			if effect != null:
				out.append(String(effect.effect_id))
	return out


func _gd_files(root_dir: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root_dir)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root_dir + f)
	for d in dir.get_directories():
		out.append_array(_gd_files(root_dir + d + "/"))
	return out
