extends TestCase

## Arch item-4 .tres smoke: authored content loads and required fields exist. Headless
## (Resource loading, no scene/autoload/frame).

func test_feature_flags_tres_loads_with_all_layer_fields() -> void:
	var flags: Variant = load("res://data/feature_flags.tres")
	assert_not_null(flags, "feature_flags.tres loads")
	assert_true(flags is FeatureFlags)
	for field in ["melee_mana_generation", "unblockable", "orbs", "pitch_zone", "minions", "totems", "equipment"]:
		assert_true(field in flags, "FeatureFlags has '%s'" % field)


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
