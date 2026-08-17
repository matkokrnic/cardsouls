extends TestCase

## Arch item-4 .tres smoke: authored content loads and required fields exist. Headless
## (Resource loading, no scene/autoload/frame).

func test_feature_flags_tres_loads_with_all_layer_fields() -> void:
	var flags: Variant = load("res://data/feature_flags.tres")
	assert_not_null(flags, "feature_flags.tres loads")
	assert_true(flags is FeatureFlags)
	for field in ["melee_mana_generation", "unblockable", "orbs", "pitch_zone", "minions", "totems", "equipment"]:
		assert_true(field in flags, "FeatureFlags has '%s'" % field)


## Every E1 melee field authored in story 1-1 (AC 1/4). Kept in sync with BalanceConfig.
const E1_BALANCE_FIELDS: Array[String] = [
	"max_hp", "move_speed",
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
	"unit_move_speed", "unit_stop_distance",
	# Story 4-3a (AC 1/AC 2, `4-3a/R8`): the unit's authored MAXIMUM HP and the DEDICATED FLAT
	# damage one hero swing takes off it. Neither carries the `_seconds` suffix, so half (b) of the
	# reflection guard below leaves them alone; half (a) fails until they are listed here.
	#
	# THE FLAT FIELD IS THE WHOLE POINT OF `4-3a/R8` AND NOT A DUPLICATE OF
	# `attack_damage_percent_of_max_hp`: that field is a percentage of the TARGET's own maximum, so
	# reusing it against a unit's own authored maximum would make hits-to-kill a CONSTANT (34, at
	# the authored 3.0%) for every possible authored unit maximum, and `unit_max_hp` would be
	# cosmetic. A flat value is what makes the authored maximum decide anything.
	"unit_max_hp", "unit_damage_per_hit",
	# Story 4-3b (AC 1): the unit ATTACK RHYTHM. The three durations DO carry the `_seconds` suffix,
	# so half (b) below demands a stem-matched `_ticks` twin filled by `BalanceTicks.from_config()`
	# for each — that is the whole reason AC 1 spells the three identifiers out rather than leaving
	# the naming to the dev pass. `minion_attack_reach_distance` carries no suffix and is left alone
	# by half (b), exactly like `unit_stop_distance` above; half (a) fails until it is listed here.
	"minion_attack_windup_seconds", "minion_attack_active_seconds",
	"minion_attack_recovery_seconds", "minion_attack_reach_distance",
	# Story 4-3c1 (AC 1/AC 3, `4-3c/R19`): the minion's own three attack-phase move-speed
	# multipliers. None carries the `_seconds` suffix, so half (b) below leaves them alone exactly
	# as it leaves `minion_attack_reach_distance` alone; half (a) fails until all three are listed
	# HERE, BY HAND — this literal is not derived from anything, which is the reason the story
	# spells the task out rather than assuming the reflective guard would supply them.
	"minion_attack_windup_move_speed_multiplier", "minion_attack_active_move_speed_multiplier",
	"minion_attack_recovery_move_speed_multiplier",
	"block_damage_multiplier", "deflect_window_seconds", "block_facing_arc_degrees",
	"roll_iframe_seconds", "roll_duration_seconds", "roll_distance",
	"stun_seconds",
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
