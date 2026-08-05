extends Node

## Autoload. Loads the BalanceConfig .tres and exposes it. Unlike FeatureFlags,
## balance is HOT-RELOADABLE at runtime (X3): reload() re-reads the .tres so the
## Match Runner can re-apply values to live state mid-match without restarting —
## reload() -> MatchState.apply_balance(get_config()) re-injects bounds and
## re-converts durations (story 1-1). State receives BalanceConfig by INJECTION
## and never reads this autoload.
##
## The schema (src/state/resources/balance_config.gd) and the authored .tres
## exist since E1 story 1-1; reload() remains a safe no-op if the file is absent.
##
## Story 3-0d (AC 1): DEBT B's CACHE HALF IS CLOSED HERE. reload() used a plain load(), which
## hands back the RESOURCE-CACHE instance on every call after the first — so a mid-session edit
## to the authored .tres was silently ignored and "hot-reload" reloaded nothing
## (decision-log:130, "on-disk hot-reload is a no-op without CACHE_MODE_IGNORE"). See reload().

const CONFIG_PATH := "res://data/balance/balance_config.tres"

var _config: BalanceConfig


func _ready() -> void:
	reload()


## Re-reads the balance .tres (X3 hot-reload). Safe no-op if the file is absent.
##
## Story 3-0d (AC 1): CACHE_MODE_IGNORE, deliberately NOT a plain load(). A plain load() returns
## the cached instance every call after the first, so this method could not re-read anything —
## the whole point of a hot-reload. MEASURED on Godot 4.6.3 against the shipped .tres: plain
## load() twice -> the SAME instance; CACHE_MODE_IGNORE twice -> DIFFERENT instances carrying
## EQUAL values. That reference identity is what test_balance_config.gd asserts, so this line
## reverting to load() fails the suite rather than silently un-hot-reloading balance.
func reload() -> void:
	if not ResourceLoader.exists(CONFIG_PATH):
		push_warning("BalanceConfigService: no balance config at %s" % CONFIG_PATH)
		return
	_config = ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as BalanceConfig


func get_config() -> BalanceConfig:
	return _config
