class_name EffectPresentationSet
extends Resource

## Story 7-1 (AC 29, `7-1/R6`): THE AUTHORED KNOB SETS, one `EffectPresentationRow` per Scope-table row, loaded
## once by the runner and handed to `EffectPresenter`. Presentation-only: see `EffectPresentationRow`'s header.
##
## `ROW_SOUND_SLOTS` IS THE ONE SOURCE OF THE ROW LIST (`7-T1/R4`'s reflection-derived guard style): the
## presenter plays only the slots named here and `test_effect_presentation_knobs.gd` walks THIS dictionary to
## assert every row is authored -- there is no second, hand-kept list for the two to disagree with. The order
## is the Scope table's. A row with no sound slots (Boulder slow, stun/root) still has a knob set.
const ROW_SOUND_SLOTS := {
	&"vanguard": [&"summon"],
	&"culling": [&"cull", &"soul"],
	&"grave_ward": [&"ward"],
	&"raise_dead": [&"raise"],
	&"drain": [&"drain"],
	&"vampiric_aura": [&"aura", &"heal"],
	&"rocksling": [&"rock_throw", &"rock_hit"],
	&"boulder_slow": [],
	&"boom": [&"boom"],
	&"bloodhound_step": [&"hound"],
	&"fireball": [&"fire_launch", &"fire_loop", &"fire_hit"],
	&"honed_bolt": [&"bolt_charge", &"bolt_strike"],
	&"counterspell": [&"counter"],
	&"frostbite": [&"frost_arm", &"frost_hit"],
	&"corpse_bomb": [&"skull_launch", &"skull_hit"],
	&"stun_root": [],
}

## The path the runner loads. Not under `data/effects/` and not read by anything in `src/state/` (`7-1/R6`).
const AUTHORED_PATH := "res://data/presentation/effect_presentation.tres"

@export var rows: Array[EffectPresentationRow] = []


## The row authored for `row_id`, or null.
func row(row_id: StringName) -> EffectPresentationRow:
	for candidate: EffectPresentationRow in rows:
		if candidate != null and candidate.row_id == row_id:
			return candidate
	return null


## The row that presents `effect_id` (a `CardEffect.effect_id`), or null for an effect no row claims.
func row_for_effect(effect_id: StringName) -> EffectPresentationRow:
	for candidate: EffectPresentationRow in rows:
		if candidate != null and candidate.effect_ids.has(String(effect_id)):
			return candidate
	return null
