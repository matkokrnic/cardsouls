class_name TelegraphProfile
extends Resource

## D7 telegraph schema (story 1-10). Standalone Resource referenced by ANY telegraphing
## action — melee included — never owned by CardData, so E5's colour telegraphs reuse this
## exact type instead of retrofitting one. Pure data vocabulary: nothing in src/state/
## logic ever references a TelegraphProfile — the ActionState -> profile mapping is
## CONTROLLER-OWNED (gate ruling 1-10/R1), exported on the presentation-side
## TelegraphController. Authored as data/telegraphs/*.tres.
##
## Telegraph = shape + sound, never hue alone (colorblind-safe, <0.5s — GDD Legibility
## Principle). shape_id / sting_id name the presentation nodes the controller drives;
## pose_id is reserved vocabulary for the animation rig (DEBT E — consumed when real
## animations land, authored now so the data contract is complete from the start).

@export var shape_id: StringName
@export var sting_id: StringName
@export var color: Color = Color.WHITE
@export var pose_id: StringName
