extends TestCase

## Arch item-4 .tres smoke: authored content loads and required fields exist. Headless
## (Resource loading, no scene/autoload/frame).

func test_feature_flags_tres_loads_with_all_layer_fields() -> void:
	var flags: Variant = load("res://data/feature_flags.tres")
	assert_not_null(flags, "feature_flags.tres loads")
	assert_true(flags is FeatureFlags)
	for field in ["melee_mana_generation", "unblockable", "orbs", "pitch_zone", "minions", "totems", "equipment"]:
		assert_true(field in flags, "FeatureFlags has '%s'" % field)


## Story 5-4 (AC 14): THE SHIPPED DEFAULT IS OPEN. A layer flag is turned on once its own mechanism
## ships (the `unblockable` / `minions` / `totems` precedent), and this asserts the AUTHORED resource
## rather than the script default -- a `.tres` that quietly lost the line would otherwise fall back
## to `feature_flags.gd`'s `false` with nothing failing, shipping E5's payout half dark.
##
## MEASURED BLAST RADIUS, stated rather than assumed: no authored card carries an `orb_costs` entry
## (pinned at test_card_authoring.gd, referenced not edited), so opening this flag changes NOTHING
## for `CastEvaluator._orbs_affordable`. Only the 5-4 grant path newly fires in real play.
func test_feature_flags_tres_opens_the_orbs_layer() -> void:
	var flags: Variant = load("res://data/feature_flags.tres")
	assert_not_null(flags, "feature_flags.tres loads")
	assert_true(flags is FeatureFlags)
	if not (flags is FeatureFlags):
		return
	assert_true((flags as FeatureFlags).orbs,
		"data/feature_flags.tres must ship orbs = true — its mechanism landed in 5-4")


## Every E1 melee field authored in story 1-1 (AC 1/4). Kept in sync with BalanceConfig.
const E1_BALANCE_FIELDS: Array[String] = [
	"max_hp", "move_speed",
	# Story 6-7 (AC 13): the two-gait system's three new fields, hand-maintained same as every
	# sibling in this list -- `attack_stamina_cost`/`block_facing_arc_degrees` shipped unaudited
	# before this file's own history (below) forced the point once already.
	"walk_speed", "run_stamina_drain_per_second", "run_resume_stamina_percent",
	"max_stamina", "stamina_regen_per_second", "stamina_regen_delay_seconds",
	"roll_stamina_cost", "deflect_stamina_cost",
	# FOUND BY STORY 3-5b's reflective guard below, on its first run, and repaired here:
	# `attack_stamina_cost` (the stamina-cost corrective pass, E3-RG/R2) and
	# `block_facing_arc_degrees` (story 1-8, R-D2) both shipped WITHOUT ever being added to this
	# hand-maintained list, so neither was covered by the non-negativity loop. Nothing failed,
	# which is precisely the hole AC 13 exists to close — two live tunables were unaudited for
	# four and eleven stories respectively.
	"attack_stamina_cost",
	"attack_windup_seconds", "attack_active_seconds", "attack_recovery_seconds",
	"attack_chain_window_seconds", "attack_chain_length", "attack_damage_percent_of_max_hp",
	"attack_windup_move_speed_multiplier", "attack_active_move_speed_multiplier",
	"attack_recovery_move_speed_multiplier", "attack_lunge_distance",
	# Story 3-1 (AC 2/AC 6): the mana set — max_mana and mana_regen_per_second are NEW here,
	# melee_hit_mana was already present and is only RE-AUTHORED (never a second field).
	"max_mana", "melee_hit_mana", "mana_regen_per_second",
	# Story 3-3 (AC 6): the deck/hand COUNTS. deck_size is read by the RUNNER (it sizes the
	# composition it injects), hand_size by the state layer at the step-6 deal seat.
	# Story 3-5b (AC 1/AC 2): the two card DURATIONS, arriving WITH their consumers exactly as
	# 3-3's note here said they would — the delay between a played card and its replacement, and
	# the window a reshuffle leaves its owner vulnerable for. Both carry a BESPOKE authored > 0.0
	# bound in test_balance_authoring.gd on top of the `>= 0.0` loop below, because `field in
	# config` and `>= 0.0` BOTH pass on the 0.0 script default — which would ship the story
	# invisible in the build.
	"deck_size", "hand_size",
	"draw_replacement_delay_seconds", "reshuffle_vulnerable_window_seconds",
	# Story 4-2 (AC 7, `4-2/R5`): the retarget cadence joins the audited set. Listed here because
	# half (a) of the reflection guard below fails otherwise — which is the guard working: a new
	# BalanceConfig tunable that nothing audits ships unaudited, and this file is what forbids that.
	"minion_retarget_interval_seconds",
	# Story 4-3 (AC 2, `4-3/R9`): the approach RATE and the stop DISTANCE. Neither carries the
	# `_seconds` suffix, so half (b) of the reflection guard below leaves them alone (they have no
	# `BalanceTicks` counterpart by design) — but half (a) fails until they are listed here, which
	# is the guard working exactly as 3-5b built it to.
	# Story 4-4 (AC 6/AC 11): ELEVEN ENTRIES LEFT THIS LIST — `unit_move_speed`,
	# `unit_stop_distance`, `unit_max_hp`, `unit_damage_per_hit`, `minion_attack_windup_seconds`,
	# `minion_attack_active_seconds`, `minion_attack_recovery_seconds`,
	# `minion_attack_reach_distance` and the three `minion_attack_*_move_speed_multiplier`s. They are
	# per-KIND now, and reflection half (a) below would fail on any that stayed listed here (the list
	# is audited in BOTH directions). Their successors are audited by the PER-KIND guard at the
	# bottom of this file, which is AC 11's actual requirement rather than a like-for-like swap.
	#
	# `hero_damage_to_unit` is NOT one of the eleven and is NOT a survivor of `unit_damage_per_hit`:
	# it is the HERO-attacker half of a field that always had two different readers (see its comment
	# on BalanceConfig and `MatchState._damage_against_unit`), so it stays a flat global and is
	# audited here.
	"hero_damage_to_unit",
	# Story 4-4 (AC 20/AC 21): the two accelerator faucets' numbers. `ResourceGenerationRule` forbids
	# a rule carrying its own amount, so the Mana Accelerator's amount and cadence live here and the
	# authored `.tres` names the first of them. The Stamina Accelerator's factor is applied at the
	# regen seat and has no rule at all (no `STAMINA` resource exists through that seam — the story's
	# B8 correction), so it is a plain global too. The cadence carries the `_seconds` suffix, so half
	# (b) below demands a stem-matched `mana_accelerator_interval_ticks` on `BalanceTicks`.
	"mana_accelerator_mana", "mana_accelerator_interval_seconds",
	# Story 5-1 (AC 7, `5-1/R2`): the stamina field is RENAMED to `stamina_accelerator_regen_step`
	# and its semantics change from a direct multiplier to the additive term in `1 + N x step`. Its
	# multiplicative predecessor is GONE from the codebase rather than left as an unread sibling, so
	# this hand-maintained list drops that entry and adds this one — the list is audited in BOTH
	# directions, so a stale entry fails reflection half (a) exactly as a missing one fails half (b).
	"stamina_accelerator_regen_step",
	"block_damage_multiplier", "deflect_window_seconds", "block_facing_arc_degrees",
	"roll_iframe_seconds", "roll_duration_seconds", "roll_distance",
	# Story 5-6 (AC 1/AC 3): `stun_seconds` RENAMED to `color_counter_stun_seconds` and joined by
	# `deflect_stun_seconds` -- one duration per tier of the three-tier ladder that stuns. BOTH carry
	# the `_seconds` suffix, so reflection half (b) independently demands stem-matched
	# `color_counter_stun_ticks` / `deflect_stun_ticks` twins on `BalanceTicks`, and it would demand
	# them even if this list had never been touched. Both also carry a BESPOKE authored `> 0.0` bound
	# PLUS a directional `>` bound in test_balance_authoring.gd, whose `stun_seconds` exemption AC 4
	# REMOVES: the field is no longer data-only, so a zero is no longer inert.
	"color_counter_stun_seconds", "deflect_stun_seconds",
	# Story 6-6a (AC 4/AC 8): the knockdown stun and the get-up iframes, on the two stun lines above's
	# precedent -- both `_seconds`, so half (b) demands the `knockdown_stun_ticks` /
	# `get_up_iframe_ticks` twins independently. The knockdown joins the bespoke three-way TICK order
	# bound in test_balance_authoring.gd; the get-up iframes carry their own `> 0` bound there.
	"knockdown_stun_seconds", "get_up_iframe_seconds",
	# Story 5-6 (AC 2/AC 3): the deflected ATTACKER's stamina penalty (distinct from the DEFENDER's
	# `deflect_stamina_cost` above) and the dodge rung's damage multiplier. Neither carries the
	# `_seconds` suffix, so half (b) leaves them alone -- a penalty and a multiplier are not
	# durations. `deflect_stamina_penalty` carries a bespoke `> 0.0` bound in test_balance_authoring.gd
	# (a zero silently disarms `E5-P/R1`); `dodged_unblockable_damage_multiplier` carries only a
	# bespoke `<= 1.0` upper bound there, because 0.0 IS its ratified authored value and the `>= 0.0`
	# half is exactly what the non-negative loop below already asserts -- cited rather than duplicated.
	"deflect_stamina_penalty", "dodged_unblockable_damage_multiplier",
	# Story 5-2 (AC 6/AC 10/AC 17/AC 18): the FOUR unblockable-initiation tunables. Listed here
	# because reflection half (a) below fails otherwise -- which is the guard working: a new
	# BalanceConfig tunable that nothing audits ships unaudited. Only ONE of the four carries the
	# `_seconds` suffix, so half (b) demands a stem-matched `unblockable_chargeup_ticks` on
	# `BalanceTicks` and leaves the other three alone (they have no tick-domain counterpart by
	# design -- a cost, a distance and a percentage are not durations). All four also carry a
	# BESPOKE authored > 0.0 bound in test_balance_authoring.gd on top of the `>= 0.0` loop below,
	# for `draw_replacement_delay_seconds`'s reason: `field in config` and `>= 0.0` BOTH pass on the
	# 0.0 script default, which would ship the whole story invisible in the build.
	"unblockable_stamina_cost", "unblockable_chargeup_seconds",
	"unblockable_damage_percent_of_max_hp",
	# Story 6-1c (AC 4/AC 5): `unblockable_reach` REMOVED and replaced by FOUR per-colour triplets --
	# reach, arc, launch distance, launch span. The three spans carry the `_seconds` suffix, so half
	# (b) below independently demands their stem-matched `unblockable_launch_ticks_*` twins on
	# `BalanceTicks`. Non-negativity is all this loop asks of them; the positive/arc bounds are
	# test_balance_authoring.gd's.
	"unblockable_reach_red", "unblockable_reach_blue", "unblockable_reach_green",
	"unblockable_arc_degrees_red", "unblockable_arc_degrees_blue", "unblockable_arc_degrees_green",
	"unblockable_launch_distance_red", "unblockable_launch_distance_blue",
	"unblockable_launch_distance_green",
	"unblockable_launch_seconds_red", "unblockable_launch_seconds_blue",
	"unblockable_launch_seconds_green",
	# Story 5-4 (AC 3/AC 9): the orb GRANT (per landed unblockable) and the per-colour CONTAINER cap.
	# Listed here because reflection half (a) below fails otherwise -- the guard working, as for the
	# 5-2 four directly above. Neither carries the `_seconds` suffix, so half (b) leaves them alone
	# (a count and a ceiling are not durations). Both are INTs, which the reflection scan covers
	# alongside floats, and both carry a BESPOKE authored `> 0` bound in test_balance_authoring.gd on
	# top of the `>= 0` loop below: `field in config` and `>= 0` BOTH pass on the 0 script default,
	# and a 0 grant or a 0 cap ships the whole orb economy invisible in the build.
	"unblockable_orb_grant", "max_orbs_per_color",
	# Story 5-5 (AC 6/AC 14): the TWO mode ③ tunables -- the FIFTH stamina seat's cost, and the
	# reaction window's duration. Listed here because reflection half (a) below fails otherwise, the
	# guard working exactly as it did for the 5-2 four and the 5-4 two above.
	#
	# ONLY ONE OF THE TWO CARRIES THE `_seconds` SUFFIX, so half (b) independently demands a
	# stem-matched `defense_window_ticks` on `BalanceTicks` -- and it would demand it even if this
	# list had never been touched, which is why AC 14 calls the named list only HALF of this file's
	# obligation. `defense_stamina_cost` has no suffix and no tick-domain counterpart by design (a
	# cost is not a duration). BOTH carry a BESPOKE authored `> 0` bound in test_balance_authoring.gd
	# on top of the `>= 0.0` loop below: a 0.0 cost makes the defense free, and a 0.0 window derives
	# 0 ticks, never runs, and makes every defense cast negate nothing -- the story shipped invisible.
	"defense_stamina_cost", "defense_window_seconds",
	# Story 6-2 (AC 9/AC 17): the Pitch Zone countdown. Its `_seconds` suffix makes half (b) below demand a
	# stem-matched `pitch_stage_timer_ticks` on BalanceTicks; half (a) demands this entry. The optional
	# orb-clear BOOL (`pitch_stage_clears_orbs`) is NOT listed and does not need to be: reflection below
	# collects only TYPE_FLOAT / TYPE_INT properties, so a bool is invisible to both halves by
	# construction -- the `unblockable_swing_at_commit` precedent. It carries a bespoke > 0 bound in
	# test_balance_authoring.gd, for the `defense_window_seconds` reason.
	"pitch_stage_timer_seconds",
	# Story 6-3b (AC 5): the pitch HUD's countdown push cadence -- a MODULO DIVISOR on the
	# `mana_accelerator_interval_seconds` shape. Its `_seconds` suffix makes half (b) below demand the
	# stem-matched `pitch_countdown_push_interval_ticks` on BalanceTicks; half (a) demands this entry.
	# A bespoke authored `> 0` bound lives in test_balance_authoring.gd.
	"pitch_countdown_push_interval_seconds",
]


func test_balance_config_tres_has_every_e1_field_non_negative() -> void:
	var config: Variant = load("res://data/balance/balance_config.tres")
	assert_not_null(config, "balance_config.tres loads")
	assert_true(config is BalanceConfig)
	for field in E1_BALANCE_FIELDS:
		assert_true(field in config, "BalanceConfig has '%s'" % field)
		assert_true(float(config.get(field)) >= 0.0, "'%s' is non-negative" % field)


## Story 3-5b (AC 13): the REFLECTIVE completeness guard, and the reason it has to exist is that
## both lists it checks are HAND-MAINTAINED. `E1_BALANCE_FIELDS` above is a literal
## `const Array[String]`, and `test_balance_config.gd::test_conversion_covers_every_seconds_field`
## is a literal dictionary of nine fields — so before this test, a field added to `BalanceConfig`
## and forgotten in either place failed NOTHING. It would simply never be audited and never be
## converted, and the first symptom would be a duration silently reading 0 ticks in the tick
## ladder. This story adds two fields and is the forcing point.
##
## (a) EVERY script-declared float/int property must appear in E1_BALANCE_FIELDS. Reflection is
##     what makes the list impossible to under-fill: the loop above proves each LISTED field
##     exists, this proves each EXISTING field is listed. Two directions, one contract.
## (b) EVERY `*_seconds` property must have a value DERIVED by `BalanceTicks.from_config()` —
##     checked by authoring one distinctive value across all of them and reading the tick-domain
##     counterpart back, so a field with a `*_ticks` twin that `from_config` forgets to fill fails
##     here (an unassigned int reads 0, not 30).
##
## MUTATION, both halves: drop `draw_replacement_delay_seconds` from E1_BALANCE_FIELDS and (a)
## fails; delete its `from_config` line and (b) fails.
func test_balance_config_field_lists_are_complete_by_reflection() -> void:
	var declared: Array[String] = []
	for p in BalanceConfig.new().get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var kind := int(p["type"])
		if kind != TYPE_FLOAT and kind != TYPE_INT:
			continue
		declared.append(String(p["name"]))
	assert_true(declared.size() > 0,
		"reflection found no BalanceConfig fields (the guard would be vacuous)")
	assert_true(declared.has("draw_replacement_delay_seconds"),
		"sanity: reflection sees this story's own new field, so the scan is real")
	# (a) every declared tunable is audited by the list above.
	var unlisted: Array[String] = []
	for name in declared:
		if not E1_BALANCE_FIELDS.has(name):
			unlisted.append(name)
	assert_eq(unlisted.size(), 0,
		"BalanceConfig field missing from E1_BALANCE_FIELDS — it ships unaudited: %s"
				% ", ".join(unlisted))
	# (b) every declared duration is converted by BalanceTicks.from_config().
	var probe := BalanceConfig.new()
	var durations: Array[String] = []
	for name in declared:
		if name.ends_with("_seconds"):
			durations.append(name)
			probe.set(name, 0.5)  # 0.5 s * 60 Hz = 30 ticks, distinct from every default
	assert_true(durations.size() > 0, "no *_seconds fields found (half (b) would be vacuous)")
	var ticks := BalanceTicks.from_config(probe)
	var underived: Array[String] = []
	for name in durations:
		var twin := name.substr(0, name.length() - "_seconds".length()) + "_ticks"
		if not (twin in ticks) or int(ticks.get(twin)) != 30:
			underived.append(name)
	assert_eq(underived.size(), 0,
		"*_seconds field with no derived value out of BalanceTicks.from_config() — it would read "
		+ "0 ticks in the tick ladder and never fire: %s" % ", ".join(underived))


## Story 4-4 (AC 11): the PER-KIND ARM of the guard above, and the reason it exists rather than the
## eleven removed entries simply being deleted from `E1_BALANCE_FIELDS`.
##
## AC 11 does not ask for the audit to shrink. It asks that the three named files "are all updated
## to match the per-kind field set", because "per-kind durations must still cross the
## seconds-to-ticks boundary through the single named `BalanceTicks.from_config()` point". The guard
## above reflects over `BalanceConfig` ONLY, so the moment a duration moved onto `UnitAttackProfile`
## it left that guard's sight — and a `windup_seconds` that `from_config()` forgot to convert would
## read 0 ticks in the tick ladder with nothing failing, which is exactly the hole story 3-5b built
## the reflective guard to close in the first place.
##
## THE THREE PER-KIND SCHEMAS ARE AUDITED THE SAME TWO WAYS:
##   (a) every script-declared float/int on each is LISTED below, hand-maintained and checked in
##       both directions, exactly as `E1_BALANCE_FIELDS` is.
##   (b) every `*_seconds` property on them is DERIVED by `BalanceTicks.from_config()` — probed by
##       authoring one distinctive value across all of them and reading the tick-domain counterpart
##       back out of the per-kind structure, so a field the conversion forgets reads 0, not 30.
##
## MUTATION, both halves: drop `cadence_seconds` from `UNIT_ATTACK_FIELDS` and (a) fails; delete its
## line in `BalanceTicks._kind_ticks` and (b) fails.
const UNIT_KIND_FIELDS: Array[String] = [
	"move_speed", "stop_distance", "max_hp",
	"attack_windup_move_speed_multiplier", "attack_active_move_speed_multiplier",
	"attack_recovery_move_speed_multiplier",
]

const UNIT_ATTACK_FIELDS: Array[String] = [
	"windup_seconds", "active_seconds", "recovery_seconds", "cadence_seconds",
	"range", "damage",
]

const PROJECTILE_FIELDS: Array[String] = [
	"launch_speed", "homing_turn_rate_degrees_per_second", "acceleration_delay_seconds",
	"acceleration_per_second_squared", "max_speed", "travel_budget",
]

## Half (a) for the three per-kind schemas: reflection finds every declared tunable, and each must
## be listed above. StringName and Resource properties (`kind_name`, `priority_name`, `attacks`,
## `projectile`) are NOT tunables and are skipped by the same float/int filter the `BalanceConfig`
## guard uses.
func test_per_kind_schema_field_lists_are_complete_by_reflection() -> void:
	_assert_declared_fields_listed(UnitKindProfile.new(), UNIT_KIND_FIELDS, "UnitKindProfile")
	_assert_declared_fields_listed(UnitAttackProfile.new(), UNIT_ATTACK_FIELDS, "UnitAttackProfile")
	_assert_declared_fields_listed(ProjectileProfile.new(), PROJECTILE_FIELDS, "ProjectileProfile")


## Half (b): every per-kind `*_seconds` field crosses the seconds-to-ticks boundary at the single
## named point. 0.5 s x 60 Hz = 30 ticks, distinct from every default, so an unconverted field
## (which reads 0) is unmistakable.
func test_per_kind_durations_are_converted_by_from_config() -> void:
	var projectile := ProjectileProfile.new()
	var attack := UnitAttackProfile.new()
	attack.projectile = projectile
	var kind := UnitKindProfile.new()
	kind.kind_name = &"probe"
	kind.attacks = [attack]
	var config := BalanceConfig.new()
	config.unit_kinds = [kind]
	# Author 0.5 across every `*_seconds` the two nested schemas declare, found by reflection rather
	# than by hand, so a NEW duration added to either schema is covered the day it is added.
	var attack_durations := _declared_seconds(attack)
	var projectile_durations := _declared_seconds(projectile)
	assert_true(attack_durations.size() > 0,
		"no *_seconds on UnitAttackProfile (half (b) would be vacuous)")
	assert_true(projectile_durations.size() > 0,
		"no *_seconds on ProjectileProfile (half (b) would be vacuous)")
	for name in attack_durations:
		attack.set(name, 0.5)
	for name in projectile_durations:
		projectile.set(name, 0.5)
	var ticks := BalanceTicks.from_config(config)
	var derived := ticks.kind_ticks_at(0)
	assert_not_null(derived,
		"from_config() derived no tick record set for an authored kind — the per-kind conversion "
		+ "is not index-aligned with BalanceConfig.unit_kinds")
	var record := derived.attack_at(0)
	assert_not_null(record, "from_config() derived no tick record for an authored attack")
	# The four attack durations, named explicitly: the derived twin does not carry the `_seconds`
	# stem verbatim (`windup_seconds` -> `windup_ticks`), so the stem rewrite the BalanceConfig guard
	# uses applies here too, and every one of them must read 30.
	var underived: Array[String] = []
	for pair in [["windup_seconds", record.windup_ticks], ["active_seconds", record.active_ticks],
			["recovery_seconds", record.recovery_ticks],
			["cadence_seconds", record.cadence_ticks],
			["acceleration_delay_seconds", record.projectile_acceleration_delay_ticks]]:
		if int(pair[1]) != 30:
			underived.append(String(pair[0]))
	assert_eq(underived.size(), 0,
		"per-kind *_seconds field with no derived value out of BalanceTicks.from_config() — it "
		+ "would read 0 ticks in the tick ladder and never fire: %s" % ", ".join(underived))
	# COMPLETENESS: every reflected duration above is one of the five asserted, so a NEW `*_seconds`
	# field added to either schema fails HERE rather than silently escaping the arithmetic pin.
	var asserted := ["windup_seconds", "active_seconds", "recovery_seconds", "cadence_seconds",
			"acceleration_delay_seconds"]
	var unasserted: Array[String] = []
	for name in attack_durations + projectile_durations:
		if not asserted.has(name):
			unasserted.append(name)
	assert_eq(unasserted.size(), 0,
		"per-kind *_seconds field with no arithmetic assertion above — add its derived twin to the "
		+ "pairs list or it converts unaudited: %s" % ", ".join(unasserted))


func _assert_declared_fields_listed(probe: Resource, listed: Array[String], label: String) -> void:
	var declared := _declared_tunables(probe)
	assert_true(declared.size() > 0, "reflection found no %s fields (the guard would be vacuous)" % label)
	var unlisted: Array[String] = []
	for name in declared:
		if not listed.has(name):
			unlisted.append(name)
	assert_eq(unlisted.size(), 0,
		"%s field missing from its audit list — it ships unaudited: %s" % [label, ", ".join(unlisted)])
	var stale: Array[String] = []
	for name in listed:
		if not declared.has(name):
			stale.append(name)
	assert_eq(stale.size(), 0,
		"%s audit list names a field the schema no longer declares: %s" % [label, ", ".join(stale)])


func _declared_tunables(probe: Resource) -> Array[String]:
	var out: Array[String] = []
	for p in probe.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var kind := int(p["type"])
		if kind != TYPE_FLOAT and kind != TYPE_INT:
			continue
		out.append(String(p["name"]))
	return out


func _declared_seconds(probe: Resource) -> Array[String]:
	var out: Array[String] = []
	for name in _declared_tunables(probe):
		if name.ends_with("_seconds"):
			out.append(name)
	return out


func test_camera_config_tres_loads_with_framing_fields() -> void:
	var config: Variant = load("res://data/camera_config.tres")
	assert_not_null(config, "camera_config.tres loads")
	assert_true(config is CameraConfig, "camera framing is its own resource (NOT BalanceConfig)")
	for field in ["distance", "height", "pitch_degrees"]:
		assert_true(field in config, "CameraConfig has '%s'" % field)


func test_gamepad_profile_tres_loads_with_mapping_fields() -> void:  # Story 2-2 (2-2/R2)
	var profile: Variant = load("res://data/gamepad_profile.tres")
	assert_not_null(profile, "gamepad_profile.tres loads")
	assert_true(profile is GamepadProfile,
		"input mapping is its own controller-owned resource (NOT BalanceConfig, 2-2/R2)")
	for field in ["move_axis_x", "move_axis_y", "attack_button", "block_button", "roll_button", "deadzone"]:
		assert_true(field in profile, "GamepadProfile has '%s'" % field)


func test_gamepad_profile_buttons_distinct_and_not_system() -> void:  # Story 2-2 (review D1)
	# The first draft authored block=5, which is JOY_BUTTON_GUIDE — a SYSTEM button, not a
	# shoulder. Make that exact class of error bite: the three action buttons must be pairwise
	# DISTINCT and none may be a system button (GUIDE / START / BACK).
	var profile: GamepadProfile = load("res://data/gamepad_profile.tres")
	assert_ne(profile.attack_button, profile.block_button, "attack != block")
	assert_ne(profile.block_button, profile.roll_button, "block != roll")
	assert_ne(profile.attack_button, profile.roll_button, "attack != roll")
	var system := [JOY_BUTTON_GUIDE, JOY_BUTTON_START, JOY_BUTTON_BACK]
	for b in [profile.attack_button, profile.block_button, profile.roll_button]:
		assert_false(b in system, "action button %d must not be a system button (GUIDE/START/BACK)" % b)


func test_every_data_tres_loads() -> void:
	var paths := _find_tres("res://data/")
	assert_true(paths.size() >= 1, "at least one .tres exists in data/")
	for p in paths:
		assert_not_null(load(p), "loads %s" % p)


func _find_tres(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".tres"):
			out.append(root + f)
	for d in dir.get_directories():
		out.append_array(_find_tres(root + d + "/"))
	return out


## Story 6-2 (AC 2a): THE PITCH ZONE LAYER SHIPS OPEN, asserted against the AUTHORED resource -- the
## `orbs` pin directly above's sibling, and the `5-2/R14` precedent ("THE LAYER GOES ON IN AUTHORED DATA
## WITH THE STORY THAT BUILDS IT"). A `.tres` that lost the line would fall back to `feature_flags.gd`'s
## `false` with every test still green, because the tests inject their own FeatureFlags -- a second
## closed gate the wiring story (6-4) would have to remember to open.
##
## MEASURED BLAST RADIUS, stated rather than assumed: no live path produces `card_mode == PITCH` yet
## (6-4 wires the input), so opening the flag changes no live behaviour today.
func test_feature_flags_tres_opens_the_pitch_zone_layer() -> void:
	var flags: Variant = load("res://data/feature_flags.tres")
	assert_not_null(flags, "feature_flags.tres loads")
	assert_true(flags is FeatureFlags)
	if not (flags is FeatureFlags):
		return
	assert_true((flags as FeatureFlags).pitch_zone,
		"data/feature_flags.tres must ship pitch_zone = true -- its staging mechanism landed in 6-2")
