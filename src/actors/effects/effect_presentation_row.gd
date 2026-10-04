class_name EffectPresentationRow
extends Resource

## Story 7-1 (AC 27/AC 29, `7-1/R6`): ONE SCOPE ROW'S KNOB SET -- every size, duration, count, volume and
## pitch the row's look and sound read, authored in `data/presentation/effect_presentation.tres` so the
## post-smoke polish round changes VALUES ONLY.
##
## PRESENTATION-ONLY, BY HOME AND BY READER (`7-1/R6`): this class lives under `src/actors/effects/`, the
## authored set under `data/presentation/`, and nothing under `src/state/` names either. It is never injected
## into `MatchState`, never captured by the recorder and never hashed -- a knob edit cannot move the golden.
##
## COLOUR IS NOT A HUE HERE (AC 27, `7-1/R1`): `card_color` SELECTS an entry of the existing authored colour
## vocabulary -- the three charge `TelegraphProfile`s, the `on_orbs_changed` precedent -- so there is no second
## colour table to drift from it. `COLORLESS` (Boulder, `6-5e/R26`) draws in its material's own colour.
##
## THE GENERIC FIELDS cover what every row has (a size, a duration, a count, a spacing, an intensity); `extra`
## carries the few row-specific knobs by name (the Fireball core radii, the Grave Ward orbit), read through
## `knob()` with a default so a missing key degrades instead of throwing.

## The Scope-table row this set belongs to -- one of `EffectPresentationSet.ROW_SOUND_SLOTS`' keys.
@export var row_id: StringName = &""

## The `CardEffect.effect_id`s this row presents. A resolved card whose effect id is listed here is this row's.
@export var effect_ids: PackedStringArray = PackedStringArray()

## Which entry of the colour vocabulary this row draws in (`Enums.CardColor`).
@export var card_color: Enums.CardColor = Enums.CardColor.COLORLESS

## The row's main size, in metres (a radius, a height or a scale -- the row's own doc in the presenter says which).
@export var size: float = 1.0

## The row's main duration, in seconds (a flash, a flight, a fade).
@export var duration: float = 0.5

## The row's main count (particles per burst, ghosts, branches, stone pieces per Boulder).
@export var count: int = 8

## Seconds between the items of a sequence (Boom's explosions). Zero for rows with no sequence.
@export var spacing: float = 0.0

## Emission energy / light energy multiplier.
@export var intensity: float = 1.0

## `7-1/R4`: an effect with its OWN resolution sound does not also play the generic cast-success cue; the
## generic cue stays the fallback for every effect that has none. Authored per row so smoke can reverse it.
@export var silences_generic_cue: bool = false

## Sound slot (`EffectPresentationSet.ROW_SOUND_SLOTS`) -> stream. One stream may serve two slots (AC 30).
@export var sounds: Dictionary = {}

## Sound slot -> volume in dB (missing = 0 dB).
@export var volume_db: Dictionary = {}

## Sound slot -> pitch scale (missing = 1.0). How one file serves two slots "at different pitch".
@export var pitch: Dictionary = {}

## Row-specific named knobs (see the presenter's per-row docs for each key).
@export var extra: Dictionary = {}


## A row-specific knob by name, or `fallback` when the authored set does not carry it.
func knob(key: StringName, fallback: float) -> float:
	return float(extra.get(key, fallback))
