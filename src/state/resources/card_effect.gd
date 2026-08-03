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

## Names the effect this card performs. The vocabulary is authored content (&"summon_imp",
## &"spell_ember_lash", ...), matched by the 3-5 resolver — never parsed for meaning here.
@export var effect_id: StringName = &""
