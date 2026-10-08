extends SceneTree

## Story 7-10 (AC 2, AC 7, AC 8, AC 9, AC 14, AC 15): THE UNBLOCKABLE PRESENTATION'S PURE HALF -- every new
## number is a named knob the operator tunes at smoke, so these pins assert BOUNDS AND DIRECTIONS only, never a
## value (AC 7, the 6-6b `_COUNTER_PRESENTATION` precedent). An integration file rather than a `test/state/` one
## because AC 16 keeps `test/state/` unedited and the subjects live in `src/actors/`.
##
##   1. the blink interval is a pure function of chargeup progress: slowest at 0, fastest at 1, monotonically
##      non-increasing, clamped outside [0, 1] (AC 2);
##   2. the eyes sit in FRONT of the measured head surface (Task 1) and apart (AC 1/AC 7);
##   3. the shimmer's silver is none of the three charge colours (AC 15);
##   4. RED's counter now plays well below its old 2.733x, and never below native (AC 8);
##   5. the landing arc rises to the head over the jump and comes off it over the backflip (AC 9);
##   6. the RED travel factor and contact tick are bounded and directional (OQ1);
##   7. the victim hold outlasts the longest fire-to-impact gap at the authored tuning (AC 14);
##   8. the shake decays to nothing and never exceeds its amplitude (AC 10).
##
## Run: godot --headless --path . --script res://test/integration/test_unblockable_presentation_knobs.gd

const CONFIG_PATH := "res://data/balance/balance_config.tres"
## Task 1's measured front of the head geometry along the head bone's forward axis (`tools/measure_head_visor.gd`).
const MEASURED_HEAD_FRONT := 0.1395
## The pre-7-10 RED rate (`counter_jump` 0..0.8333 + `counter_backflip` 0..1.90 over 1.0 s).
const OLD_RED_RATE := 2.7333
## How far apart in RGB the silver must sit from each charge colour.
const MIN_COLOR_DISTANCE := 0.35

var _hero: HeroActor
var _frames := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_hero = load("res://src/actors/hero/hero.tscn").instantiate() as HeroActor
	root.add_child(_hero)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _blink() -> void:
	var slow := UnblockableEyes.eyes_blink_interval(0.0)
	var fast := UnblockableEyes.eyes_blink_interval(1.0)
	_check(fast > 0.0, "1. the fastest blink interval is positive (got %.4f)" % fast)
	_check(slow > fast, "1. progress 0 blinks slower than progress 1 (%.4f vs %.4f)" % [slow, fast])
	var previous := slow
	for i in 101:
		var now := UnblockableEyes.eyes_blink_interval(float(i) / 100.0)
		_check(now <= previous + 1e-6, "1. the interval never grows with progress (at %d%%: %.4f > %.4f)"
				% [i, now, previous])
		previous = now
	_check(is_equal_approx(UnblockableEyes.eyes_blink_interval(-1.0), slow)
			and is_equal_approx(UnblockableEyes.eyes_blink_interval(2.0), fast),
			"1. progress outside [0, 1] clamps to the ends")


func _eyes() -> void:
	var offsets := UnblockableEyes.eye_offsets()
	_check(offsets.size() == 2, "2. two eyes")
	for o: Vector3 in offsets:
		var forward := o.dot(UnblockableEyes.HEAD_FORWARD.normalized())
		_check(forward > MEASURED_HEAD_FRONT, ("2. each eye sits in FRONT of the measured head surface "
				+ "(%.4f along forward, the surface is at %.4f)") % [forward, MEASURED_HEAD_FRONT])
	_check(offsets[0].distance_to(offsets[1]) > 0.01, "2. the two eyes are apart")
	_check(UnblockableEyes.EYE_CORE_SIZE > 0.0 and UnblockableEyes.EYE_HALO_SIZE >= UnblockableEyes.EYE_CORE_SIZE,
			"2. the core and halo sizes are positive, the halo at least the core")
	_check(UnblockableEyes.FLASH_SECONDS > 0.0 and UnblockableEyes.FLASH_SCALE > 1.0,
			"2. the flash lasts and swells")
	_check(UnblockableEyes.EYE_BLINK_DIM >= 0.0 and UnblockableEyes.EYE_BLINK_DIM < 1.0,
			"2. the blink's dark half is dimmer than lit")


func _shimmer() -> void:
	var cues := _hero.telegraph_controller
	var silver := ImmunityShimmer.SHIMMER_COLOR
	for profile: TelegraphProfile in [cues.charge_red_profile, cues.charge_blue_profile, cues.charge_green_profile]:
		var c := profile.color
		var d := Vector3(silver.r - c.r, silver.g - c.g, silver.b - c.b).length()
		_check(d >= MIN_COLOR_DISTANCE, "3. the immunity silver %s is not the charge colour %s (distance %.3f)"
				% [silver, c, d])
	_check(ImmunityShimmer.SHIMMER_ALPHA > 0.0 and ImmunityShimmer.SHIMMER_ALPHA <= 1.0,
			"3. the shimmer's alpha is in (0, 1]")


func _red_rate(config: BalanceConfig) -> void:
	var steps: Array = AnimationController._COUNTER_PRESENTATION[Enums.CardColor.RED]
	var total := 0.0
	for step: Dictionary in steps:
		total += float(step["to"]) - float(step["from"])
	var rate := AnimationController.counter_clip_speed(total, config.counter_busy_seconds_red)
	print("  RED rate %.4f (cut %.4f s over %.4f s)" % [rate, total, config.counter_busy_seconds_red])
	_check(rate < OLD_RED_RATE, "4. RED plays below its old %.3fx (got %.4f)" % [OLD_RED_RATE, rate])
	_check(rate >= 1.0, "4. ...and never below native (got %.4f)" % rate)
	var green: Array = AnimationController._COUNTER_PRESENTATION[Enums.CardColor.GREEN]
	var g_total := float(green[0]["to"]) - float(green[0]["from"])
	print("  GREEN rate %.4f" % AnimationController.counter_clip_speed(g_total, config.counter_busy_seconds_green))


func _lift() -> void:
	var steps: Array = AnimationController._COUNTER_PRESENTATION[Enums.CardColor.RED]
	var jump: Dictionary = steps[0]
	var flip: Dictionary = steps[1]
	_check(is_zero_approx(AnimationController.counter_lift_at(jump, float(jump["from"]))),
			"5. the arc starts on the ground")
	_check(is_equal_approx(AnimationController.counter_lift_at(jump, float(jump["to"])), 1.0),
			"5. the jump ends ON the head (lift 1.0 at its cut end)")
	_check(is_equal_approx(AnimationController.counter_lift_at(flip, float(flip["from"])), 1.0),
			"5. the backflip starts on the head")
	_check(is_zero_approx(AnimationController.counter_lift_at(flip, float(flip["to"]))),
			"5. the backflip ends on the ground")
	var previous := -1.0
	for i in 51:
		var t := lerpf(float(jump["from"]), float(jump["to"]), float(i) / 50.0)
		var now := AnimationController.counter_lift_at(jump, t)
		_check(now >= previous - 1e-6, "5. the jump's arc never falls (t=%.3f)" % t)
		previous = now
	previous = 2.0
	for i in 51:
		var t := lerpf(float(flip["from"]), float(flip["to"]), float(i) / 50.0)
		var now := AnimationController.counter_lift_at(flip, t)
		_check(now <= previous + 1e-6, "5. the backflip's arc never rises (t=%.3f)" % t)
		previous = now
	_check(is_zero_approx(AnimationController.counter_lift_at({"clip": &"x", "from": 0.0, "to": 1.0}, 0.5)),
			"5. a step without a lift lifts nothing")


func _travel(config: BalanceConfig) -> void:
	var d := config.counter_travel_distance_red
	_check(is_equal_approx(UnblockablePresentation.red_travel_scale(d * 2.0, d), 1.0),
			"6. a press beyond the travel keeps the full travel (scale 1)")
	_check(is_equal_approx(UnblockablePresentation.red_travel_scale(d * 0.5, d), 0.5),
			"6. a press at half the travel halves it")
	_check(UnblockablePresentation.red_travel_scale(1.0, d) < UnblockablePresentation.red_travel_scale(2.0, d),
			"6. a nearer press travels less")
	_check(is_equal_approx(UnblockablePresentation.red_travel_scale(1.0, 0.0), 1.0),
			"6. no authored travel leaves the velocity alone")
	_check(UnblockablePresentation.red_contact_elapsed_ticks(1, 0.5) == -1,
			"6. a window too short to travel has no contact tick")
	for duration: int in [10, 60, 90]:
		var c := UnblockablePresentation.red_contact_elapsed_ticks(duration, config.counter_travel_forward_fraction_red)
		_check(c >= 1 and c <= duration - 2, "6. the contact tick lies inside the moving ticks (%d of %d)"
				% [c, duration])
	_check(UnblockablePresentation.red_land_height(5.0, 0.0) <= UnblockablePresentation.RED_LAND_HEIGHT_MAX,
			"6. the arc height is capped")
	_check(is_zero_approx(UnblockablePresentation.red_land_height(-3.0, 0.0)), "6. the arc never goes below 0")


func _hold(config: BalanceConfig) -> void:
	var ticks := BalanceTicks.from_config(config)
	var red_contact := UnblockablePresentation.red_contact_elapsed_ticks(
			ticks.counter_busy_ticks_for(Enums.CardColor.RED), config.counter_travel_forward_fraction_red)
	var hold := UnblockablePresentation.VICTIM_HOLD_MAX_SECONDS
	_check(float(red_contact) / TimingWindow.TICK_HZ < hold,
			"7. the victim hold (%.3f s) outlasts RED's press-to-kick gap (%d ticks)" % [hold, red_contact])
	_check(UnblockablePresentation.DAGGER_FLIGHT_SECONDS < hold,
			"7. ...and GREEN's dagger flight (%.3f s)" % UnblockablePresentation.DAGGER_FLIGHT_SECONDS)
	_check(UnblockablePresentation.KNOCKDOWN_BLEND_SECONDS > 0.0, "7. the knockdown enters with a blend")
	_check(UnblockablePresentation.RED_HITSTOP_SECONDS > 0.0 and UnblockablePresentation.GREEN_HITSTOP_SECONDS > 0.0
			and UnblockablePresentation.HITSTOP_CATCHUP_SECONDS > 0.0, "7. the hitstops and the catch-up last")


func _shake() -> void:
	var total := UnblockablePresentation.ticks(UnblockablePresentation.SHAKE_SECONDS)
	_check(total > 0, "8. a shake lasts")
	for e in total:
		var o := UnblockablePresentation.shake_offset(e, total)
		_check(o.length() <= UnblockablePresentation.SHAKE_AMPLITUDE * 1.4143,
				"8. the shake never exceeds its amplitude (tick %d: %.4f)" % [e, o.length()])
	_check(UnblockablePresentation.shake_offset(total, total) == Vector2.ZERO
			and UnblockablePresentation.shake_offset(-1, total) == Vector2.ZERO,
			"8. no offset outside the shake")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	var config: BalanceConfig = load(CONFIG_PATH)
	_blink()
	_eyes()
	_shimmer()
	_red_rate(config)
	_lift()
	_travel(config)
	_hold(config)
	_shake()
	if is_instance_valid(_hero):
		_hero.queue_free()
	var ok := _failures.is_empty()
	for f in _failures:
		print("  FAILED: " + f)
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
