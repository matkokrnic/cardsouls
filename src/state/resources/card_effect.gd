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

## ------------------------------------------------------------------------------------------
## STORY 6-5c: THE HERO-CAST / HONED BOLT NUMBERS. Seven more FLAT exports, on the header's own
## discipline (AC 2, `6-5c/R19`): no subclass, no nested resource, so `RecordFile._card_effects`
## keeps round-tripping every one of them generically and `_fresh_nested` needs no new row.
##
## FOUR NAMES ARE THE SPEC'S, VERBATIM (`6-5c/R19`): `stun_seconds`, `root_seconds`,
## `root_blocks_run` and `root_blocks_roll` are the names `deck-1-spec.md:35` fixes, used
## unchanged so the authored card and the spec cannot drift into two vocabularies. THREE ARE NEW
## and the dev pass records them here, which is the other half of that ruling: `cast_seconds`,
## `damage_amount`, `repeat_landing_restuns`.
##
## `damage_amount` follows `heal_amount` (its exact twin one family up: a flat absolute magnitude
## this effect applies to a hero). `cast_seconds` follows `slow_duration_seconds`/`duration_seconds`
## -- a `*_seconds` duration converted to ticks once at the point of use (A1).
## `repeat_landing_restuns` follows `root_blocks_run` / `root_blocks_roll`, the two spec-fixed
## booleans it sits beside, rather than the project-wide `is_`/`has_`/`can_` prefix: within ONE
## effect's vocabulary a third boolean spelled a different way reads as a different KIND of fact,
## and these three are one kind -- switches on what this effect's outcome does.

## CAST DURATION, in seconds: how long the caster is committed between the press and the strike
## (AC 1). 0.8 IS A LIVE DEFAULT, NOT A NEUTRAL ONE, and it is the one place this file departs
## from its own "a field an effect does not use keeps its neutral default" rule -- by ruling
## (`6-5c/R4`, and Discrepancy 4 of the story). It is SAFE only because it is read ONLY for an
## effect `CardEffectResolver.starts_cast()` classifies as a cast: every buff, every summon and
## every still-deferred effect never reaches the read at all, so an unused 0.8 cannot change an
## outcome (AC 2). Do not add a reader that consults it for a non-cast effect.
@export var cast_seconds: float = 0.8

## The ABSOLUTE HP this effect's strike removes from its target (AC 13, default authored 4 on
## `honed_bolt`). Neutral default 0.0: an effect that does not strike removes nothing. Applied
## through `MatchState._funnel_damage`, so Bloodlust's multipliers and Vampiric Aura's lifesteal
## both reach it (`6-5c/R13`, the standing rule for every later spell).
@export var damage_amount: float = 0.0

## THE SPEC'S OWN NAME (`deck-1-spec.md:35`, T[0.4]): how long the struck hero is STUNNED after the
## damage (AC 14). Neutral default 0.0 -- no stun. It must stay strictly BELOW the authored
## `knockdown_stun_seconds`, because `BalanceTicks.is_knockdown_stun` tells a knockdown from an
## ordinary stun BY DURATION and would otherwise misread a bolt stun as a knockdown (AC 15); the
## authoring audit enforces that against the real `.tres` pair (AC 21).
@export var stun_seconds: float = 0.0

## THE SPEC'S OWN NAME (T[2.5]): how long the root lasts AFTER the stun ends (AC 17). Neutral
## default 0.0 -- no root.
@export var root_seconds: float = 0.0

## THE SPEC'S OWN NAMES (T[true], T[true]): what the root takes away, as two INDEPENDENT switches
## (AC 17). `root_blocks_run` makes a held run key give walk pace, drain no run stamina and touch
## no gait latch; `root_blocks_roll` makes a roll press refused silently -- no state change, no
## stamina, no `action_rejected` (`6-5c/R14`). Walk, block, deflect, the colour counter, attacking
## and card play are untouched by either (AC 18).
##
## DEFAULT TRUE, NOT NEUTRAL-FALSE, and the reason is `kill_cap`'s verbatim: these are the
## ruling's own numbers, and an unauthored root that took nothing away would read as a broken card
## rather than a switched-off one. Neither is read at all unless a root is actually armed, so a
## non-rooting effect is unaffected by the default.
@export var root_blocks_run: bool = true
@export var root_blocks_roll: bool = true

## THE REPEAT-LANDING SWITCH (AC 19, `6-5c/R2`). TRUE is choice A, the DEFAULT: a second landing
## while the target is still bolt-stunned or rooted stuns it again and restarts the root in full.
## FALSE is choice B: the landing deals its damage and neither stuns nor extends the root. A
## `.tres` value read AT THE LANDING, never at the press, so flipping it retunes an in-flight match
## on the next bolt with no code edit.
##
## AC 16(a)'s KNOCKDOWN FLOOR TAKES PRECEDENCE OVER BOTH settings: a bolt on a knocked-down hero
## deals damage only, whatever this says (`R-STUNSTACK`, `6-5c/R9`).
@export var repeat_landing_restuns: bool = true

## Story 6-5a (AC 3): a PRESENTATION handle -- which cue presentation may play for this effect. No
## file under `src/state/` ever reads it (the header's "state carries vocabulary, presentation
## interprets it"). Empty = no cue named.
@export var visual_id: StringName = &""
