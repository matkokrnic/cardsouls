class_name EffectIconSet
extends Resource

## Story 7-6 (R2, D2, AC 11/AC 12/AC 32): THE EFFECT ART TABLE -- one icon per `CardEffect.effect_id`.
##
## ART BELONGS TO THE EFFECT, NOT THE CARD (R2). The key is the effect's own id, so re-pairing an effect onto a
## different card (or into the other half of the same card) carries its icon along with no new authoring, and a
## new deck adds rows only for its new effects. Which card currently pairs an effect is the runner's load-once
## derivation (`card id -> [normal effect id, pitch effect id]`), never this table's business.
##
## PRESENTATION-ONLY AUTHORED DATA (AC 4): it lives under `data/presentation/` beside 7-1's knob set, not under
## `data/effects/`, and nothing in `src/state/` reads it -- so it can reach neither the record nor the hash. The
## `CardEffect.visual_id` field (`card_effect.gd`) was deliberately NOT reused: writing it would have edited the
## fifteen effect resources the state layer injects, which is exactly the channel the golden prediction names.
##
## A ROW IS A PATH STRING, NOT AN `ext_resource`, so swapping an icon is ONE LINE (D4): the hand-authored
## Rocksling / Honed Bolt / Corpse Bomb SVGs are the shown rows, and their game-icons.net versions stay in
## `assets/art/icons/game_icons/` -- pointing a row back at one is editing that row's path and nothing else.

## The path the runner loads.
const AUTHORED_PATH := "res://data/presentation/effect_icons.tres"

@export var icon_paths: Dictionary[StringName, String] = {}

## 7-6 POLISH 2 (operator ruling P13): the slot reel's one authored on/off knob -- while a hand slot waits for its
## replacement it spins through this player's deck art. Default on.
@export var slot_reel_enabled: bool = true

var _cache: Dictionary = {}


## The icon authored for `effect_id`, or null when the table has no row for it (or the row fails to load). A
## missing icon renders as an empty art slot rather than a guessed one.
func texture_for(effect_id: StringName) -> Texture2D:
	if _cache.has(effect_id):
		return _cache[effect_id] as Texture2D
	var path: String = icon_paths.get(effect_id, "")
	var texture: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cache[effect_id] = texture
	return texture
