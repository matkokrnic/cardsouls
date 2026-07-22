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
	"attack_windup_seconds", "attack_active_seconds", "attack_recovery_seconds",
	"attack_chain_window_seconds", "attack_chain_length", "attack_damage_percent_of_max_hp",
	"block_damage_multiplier", "deflect_window_seconds",
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


func test_camera_config_tres_loads_with_framing_fields() -> void:
	var config: Variant = load("res://data/camera_config.tres")
	assert_not_null(config, "camera_config.tres loads")
	assert_true(config is CameraConfig, "camera framing is its own resource (NOT BalanceConfig)")
	for field in ["distance", "height", "pitch_degrees"]:
		assert_true(field in config, "CameraConfig has '%s'" % field)


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
