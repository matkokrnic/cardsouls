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
	_check(rows_checked == 16, "the Scope table has sixteen rows, walked %d" % rows_checked)
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
