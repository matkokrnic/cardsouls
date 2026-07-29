extends TestCase

## Story 2-6 (AC 3): the dodge cue reads as a DISTINCT dodge — the roll TelegraphProfile carries
## its own shape+sound, not a placeholder shared with attack or block. Story 1-10 already authored
## RollDisc / StingRoll (a flat underfoot disc + its own sting, distinct from AttackCone/StingAttack
## and BlockShield/StingBlock); 2-6 CONFIRMS it and pins it so a regression to a shared cue bites.
## The mapping stays presentation-side (TelegraphController, exported), no state object references
## a profile (1-10/R1), and no new signal rides the iframe-drop path — the cue is driven purely by
## the hero ENTERING ActionState.ROLLING through the existing connect_hero_action_state_changed
## seam (the iframe negation in _resolve_contacts step 4 still emits nothing, 1-9/R5).
##
## Directionality (2-5 styling-assertion lesson): telegraph distinctness is SYMMETRIC — there is
## no directional invariant to pin like 2-5's face-down-back-is-heavier-than-face-up-front; the
## guarded property is simply "no cue shares another cue's shape or sting". The assertions below
## are proven NON-VACUOUS by mutation: making the roll cue share attack's shape_id fails
## test_roll_profile_is_a_distinct_shape_and_sound (verified this dev pass, SHA256-restored .tres).

const ATTACK := "res://data/telegraphs/attack.tres"
const BLOCK := "res://data/telegraphs/block.tres"
const ROLL := "res://data/telegraphs/roll.tres"


func test_roll_profile_is_a_distinct_shape_and_sound() -> void:
	var attack: TelegraphProfile = load(ATTACK)
	var block: TelegraphProfile = load(BLOCK)
	var roll: TelegraphProfile = load(ROLL)
	assert_true(attack != null and block != null and roll != null, "all three profiles load")
	# Telegraph = shape + sound (never hue alone). The roll's shape AND sting must differ from BOTH
	# other cues — a shared placeholder would collide on one of these.
	assert_true(roll.shape_id != &"" and roll.sting_id != &"", "roll authors a real shape + sting")
	assert_true(roll.shape_id != attack.shape_id, "roll shape distinct from attack")
	assert_true(roll.shape_id != block.shape_id, "roll shape distinct from block")
	assert_true(roll.sting_id != attack.sting_id, "roll sting distinct from attack")
	assert_true(roll.sting_id != block.sting_id, "roll sting distinct from block")
	# And the other two are distinct from each other too — all three cues are mutually distinguishable.
	assert_true(attack.shape_id != block.shape_id, "attack and block shapes also distinct")
	assert_true(attack.sting_id != block.sting_id, "attack and block stings also distinct")
