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
## Principle). shape_id / sting_id name the presentation nodes the controller drives:
## Shapes/<shape_id> and the <sting_id> AudioStreamPlayer, both children of
## TelegraphController. Every field here therefore NAMES SOMETHING THAT EXISTS.
##
## Story 3-0b (AC10, DEBT E member 4): `pose_id` is RETIRED, not wired. It was authored in
## 1-10 as reserved vocabulary "consumed when the animation rig lands"; the rig landed in
## 3-0a and no honest consumer emerged. The clip selection it would have fed is
## AnimationController._CLIP — ONE ActionState -> clip mapping covering all five
## seam-driven states. Routing it through pose_id instead would have required a SECOND
## copy of the ActionState -> TelegraphProfile mapping (which 1-10/R1 rules is owned by
## TelegraphController and lives there alone) plus a pose -> clip indirection, and would
## still have covered only the three TELEGRAPHING states — IDLE and DEAD have no telegraph
## profile and never will, so _CLIP survives regardless. That is two selection mechanisms
## replacing one, split on a line (telegraphing vs not) that has nothing to do with
## animation. The field is removed rather than carried a second time; if a future story
## genuinely needs pose vocabulary, re-adding one export is cheaper than the dead contract.

@export var shape_id: StringName
@export var sting_id: StringName
@export var color: Color = Color.WHITE
