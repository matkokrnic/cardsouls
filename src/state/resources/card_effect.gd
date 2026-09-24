class_name CardEffect
extends Resource

## ONE named card effect (story 3-2, AC 1). Pure schema — src/state/resources/ is the
## "Resource SCHEMA classes (.gd) — pure data vocabulary" tier and holds no logic. A
## CardEffect says WHAT a card does in a given mode; the resolver that turns an effect_id
## into gameplay lands with the card-play story (3-5). This story authors the vocabulary
## only, and nothing reads it yet.
##
## ONE FIELD, deliberately. Modes ②/③ derive from CardData.color and carry no per-card data
## at all (Novel Pattern 6), so the only per-card effect content that exists today is WHICH
## effect. No magnitude, no duration, no flavour text: the pose_id retirement (3-0b, DEBT E
## member 4) is the standing precedent in this repo — reserved vocabulary authored ahead of
## its consumer gets carried for two epics and then deleted. When 3-5 designs the resolver
## against real effects, whatever parameters it actually needs are one export each, added
## then, against a consumer that exists.
##
## NOT in the architecture doc's schema lists (neither "Schema vs Loader" nor the Directory
## Tree name card_effect.gd) — recorded as part of the SIXTH architecture-amendment-queue
## member at this story's readiness gate; no edit to that doc here.

##
## STORY 6-5a (AC 1-3) GIVES IT ITS NUMBERS, AGAINST A CONSUMER THAT EXISTS, exactly as the paragraph
## above promised. An effect is now a STANDALONE, SHARED `.tres` under `data/effects/` that a card
## references by `ext_resource` (the per-card inlined sub-resource was the only shape until now).
##
## FLAT EXPORTS, NEVER A SUBCLASS AND NEVER A NESTED RESOURCE (AC 2). `RecordFile._card_effects`
## rebuilds every recorded effect as `CardEffect.new()` and repopulates it generically; a flat field
## round-trips through that for free, while a nested resource class would need its own
## `RecordFile._fresh_nested` whitelist row or silently vanish on replay. The numbers below exist ONLY
## for the five effects `6-5a` implements (operator ruling N11); every other effect's numbers arrive
## with its own story.
##
## A FIELD AN EFFECT DOES NOT USE KEEPS ITS NEUTRAL DEFAULT (x1.0, 0 s, 0 %), so an unused number can
## never change an outcome. Every DURATION is authored in SECONDS and converted to ticks once, at the
## moment the effect is applied (A1 -- never a float accumulator).

## Names the effect this card performs. The vocabulary is authored content (&"summon_imp",
## &"spell_ember_lash", ...), matched by the 3-5 resolver — never parsed for meaning here.
## Story 6-5a (AC 4): matched as a WHOLE id for every id that story introduces; the `summon_*` prefix
## path is unchanged.
@export var effect_id: StringName = &""

## Story 6-5a (AC 8): the effect's ONE window, in seconds. For a BUFF (Bloodlust, Vampiric Aura) it
## is how long the buff lasts; for an ARMED TRIGGER (Bloodhound Step, Frostbite) it is how long the
## trigger waits for the action that consumes it. 0 = no window.
##
## STORY 6-5b (`6-5b/R7`) GIVES IT A THIRD READING, AND DELIBERATELY DOES NOT ADD A FIELD FOR IT:
## for GRAVE WARD it is the EXTENSION added to the remaining lifetime of each corpse the caster owns
## at the moment of resolution. Still one duration in seconds converted to ticks once at the
## application (A1); what differs is only whose clock it is added to -- a rule window for the five
## 6-5a effects, a per-corpse countdown here. A `grave_ward_seconds` sibling would be a second
## spelling of "this effect's one duration" with nothing to distinguish it.
@export var duration_seconds: float = 0.0

## Story 6-5a (R3): Bloodlust's two halves -- the multiplier on damage the buffed side DEALS and the
## one on damage it TAKES. Applied by `MatchState._funnel_damage` at every damage seat.
@export var damage_dealt_multiplier: float = 1.0
@export var damage_taken_multiplier: float = 1.0

## Story 6-5a (R4): Vampiric Aura -- the fraction of the damage the caster's HERO actually removes
## from a target that heals the caster (0.5 = 50 %).
@export var lifesteal_fraction: float = 0.0

## Story 6-5a (R2): Bloodhound Step -- the next roll's DISTANCE multiplier (same duration, so it is a
## speed multiplier too) and its I-FRAME multiplier, the latter clamped to the roll's own duration.
@export var roll_distance_multiplier: float = 1.0
@export var roll_iframe_multiplier: float = 1.0

## Story 6-5a (R5): Frostbite -- the movement-speed multiplier the slow applies to the struck enemy
## hero (0.5 = 50 % speed) and how long the slow lasts, in seconds.
@export var slow_speed_multiplier: float = 1.0
@export var slow_duration_seconds: float = 0.0

## ------------------------------------------------------------------------------------------
## STORY 6-5b: THE OWN-MINION / CORPSE EFFECTS' NUMBERS. Four more FLAT exports, on the header's
## own discipline (AC 2): no subclass, no nested resource, so `RecordFile._card_effects` keeps
## round-tripping every one of them generically and `_fresh_nested` needs no new row.
## ------------------------------------------------------------------------------------------

## CULLING (`6-5b/R5`): the mana granted PER OWN MINION KILLED. Clamped by the pool's own maximum at
## the point of use, so an over-cap Culling loses the surplus rather than raising the ceiling.
@export var mana_per_kill: float = 0.0

## CULLING (`6-5b/R15`, gate B5): the MAXIMUM NUMBER of the caster's own living minions one Culling
## kills -- and pays mana for. DEFAULT 99, which is the ruling's own number ("effectively no cap")
## rather than a neutral zero, because a zero default would make an unauthored Culling kill nothing
## and read as a broken card instead of an uncapped one. Above the cap it kills in BOARD-INDEX order,
## oldest first (AC 8).
@export var kill_cap: int = 99

## DRAIN (`6-5b/R6`): the HP the caster's hero heals when the sacrifice resolves, clamped at its own
## maximum (never overhealing, AC 20).
@export var heal_amount: float = 0.0

## RAISE DEAD (`6-5b/R8`): the PERCENTAGE of the raised minion's own kind maximum HP it enters at.
## DEFAULT 100.0 for `kill_cap`'s reason -- the spec's own `T[100]%` is the identity value, and a
## neutral 0.0 would raise a minion that is dead on arrival.
@export var raise_hp_percent: float = 100.0

## Story 6-5a (AC 3): a PRESENTATION handle -- which cue presentation may play for this effect. No
## file under `src/state/` ever reads it (the header's "state carries vocabulary, presentation
## interprets it"). Empty = no cue named.
@export var visual_id: StringName = &""
