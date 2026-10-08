class_name UnblockablePresentation
extends RefCounted

## Story 7-10 (S2/S3, AC 8-14): THE COUNTER'S CONTACT MOMENT -- the knobs and the pure helpers the runner's counter
## poll uses to make a landed colour counter legible: RED's distance-aware landing on the head, the hitstop on the
## rigs, the impact burst/flash/thud, the camera shake, the victim's held pose, and GREEN's fast dagger.
##
## ONE PLACE FOR EVERY NEW NUMBER (AC 7, the operator's knob list): each is a named constant here (or on the node
## it shapes -- `UnblockableEyes`, `ImmunityShimmer`, `DaggerActor`, `AnimationController._COUNTER_PRESENTATION`),
## tuned at smoke with no suite run; the tests pin bounds and directions only.
##
## PRESENTATION ONLY (AC 16-18): static, stateless, never handed a state object. The runner reads public facts
## after `advance()` and passes plain values; everything here builds nodes with no collision shape, no `Area3D` and
## no signal into state, and no value computed here reaches `to_snapshot()` or the recorder. The hitstop and the
## shake are advanced from the runner's one tick loop (F1).

## ------------------------------------------------------------------------------------------------- RED landing
## Open Question 1 (operator ruling): the DEFENDER'S BODY lands on the attacker. The applied velocity of a RED
## counter is scaled by `red_travel_scale` (gap at the press over the authored RED travel), both legs by the same
## factor so the net stays zero. A press farther than the travel lands short (smoke watch, not fixed here).

## The hero root is the body centre (`hero.tscn` Mesh grounding offset): the feet are this far below it.
const HERO_FEET_Y := -1.0
## The highest the RED landing arc may lift the defender's feet, metres above its own feet -- a cap for an
## attacker whose held pose is airborne (GREEN's jump attack) so the arc never launches off the screen.
const RED_LAND_HEIGHT_MAX := 2.2

## ---------------------------------------------------------------------------------------- hitstop and the hold
## Presentation-only hitstop at the contact moment (AC 10/AC 13): the rigs' AnimationPlayers freeze and the mesh
## is held where it was while the root keeps moving; game logic never pauses.
const RED_HITSTOP_SECONDS := 0.1
const GREEN_HITSTOP_SECONDS := 0.08
## Open Question 4 (operator ruling): after a hitstop the mesh eases back onto the moving root over this long.
## Smoke watch: if it reads as a teleport, the fallback is hitstop on the AnimationPlayer only.
const HITSTOP_CATCHUP_SECONDS := 0.12
## The longest the VICTIM'S pose is held before its knockdown plays (AC 14): at least the longest fire-to-impact
## gap (RED, press to forward-leg end, 29 ticks = 0.48 s at the shipped `counter_travel_forward_fraction_red`), so
## the hold never releases before the impact.
const VICTIM_HOLD_MAX_SECONDS := 0.6
## The cross-fade into the victim's knockdown once the hold releases -- a blend, never a pop (AC 11/AC 14).
const KNOCKDOWN_BLEND_SECONDS := 0.15

## ----------------------------------------------------------------------------------------------------- dagger
## GREEN's dagger crosses the gap in at most this long (AC 12: fast, arriving within a bounded time of the
## counter); a busy span shorter than this caps it.
const DAGGER_FLIGHT_SECONDS := 0.22

## ---------------------------------------------------------------------------------------------- impact looks
## The burst, flash quad and brief light at the contact point (AC 10/AC 13). RED is the big one.
const IMPACT_SPARK_AMOUNT_RED := 48
const IMPACT_SPARK_AMOUNT_GREEN := 28
const IMPACT_SPARK_SIZE := 0.16
const IMPACT_SPARK_SPEED := 5.5
const IMPACT_SPARK_LIFETIME := 0.35
const IMPACT_FLASH_SIZE_RED := 1.4
const IMPACT_FLASH_SIZE_GREEN := 0.7
const IMPACT_FLASH_SECONDS := 0.15
const IMPACT_LIGHT_ENERGY := 8.0
const IMPACT_LIGHT_RANGE := 4.0
## Placeholder sounds (`assets/audio/effects/`, copies the operator swaps by hand) and their levels.
const RED_THUD_SOUND := preload("res://assets/audio/effects/sfx_counter_kick_thud.wav")
const GREEN_HIT_SOUND := preload("res://assets/audio/effects/sfx_dagger_hit.wav")
const RED_THUD_VOLUME_DB := 2.0
const GREEN_HIT_VOLUME_DB := 0.0

## ------------------------------------------------------------------------------------------------ camera shake
## RED's head contact shakes BOTH cameras (AC 10): a positional offset on each SubViewport FOLLOWER camera only --
## never the rig, whose LOCAL basis is the pushed movement basis (DECISION A). Decays linearly to zero.
const SHAKE_SECONDS := 0.2
const SHAKE_AMPLITUDE := 0.07
const SHAKE_FREQUENCY_HZ := 27.0


## The RED travel scale for a gap of `gap` metres at the press against the authored travel `distance`: the
## forward leg then ends at the attacker. Never above 1 (a far press keeps today's full travel and lands short).
static func red_travel_scale(gap: float, distance: float) -> float:
	if distance <= 0.0:
		return 1.0
	return clampf(gap / distance, 0.0, 1.0)


## The elapsed tick of a RED counter's window on which the forward leg ends -- the HEAD CONTACT. The state
## layer's own arithmetic (`match_state.gd` counter-busy movement branch), re-derived from the same two inputs it
## reads, the window's duration and the authored forward fraction: the moving ticks are 1..duration-1, and the
## forward leg is `round(fraction * moving)` of them clamped inside. -1 when the window is too short to travel.
static func red_contact_elapsed_ticks(duration_ticks: int, forward_fraction: float) -> int:
	var moving := duration_ticks - 1
	if moving < 2:
		return -1
	return clampi(int(round(forward_fraction * float(moving))), 1, moving - 1)


## The arc height for RED's landing: the attacker's head top above the defender's feet at the press, clamped.
static func red_land_height(head_top_y: float, defender_root_y: float) -> float:
	return clampf(head_top_y - (defender_root_y + HERO_FEET_Y), 0.0, RED_LAND_HEIGHT_MAX)


## The camera shake's offset in the camera's own (right, up) plane, `elapsed` ticks into a shake of `total`
## ticks. Deterministic (no RNG): two incommensurate sines, decaying linearly to zero at the end.
static func shake_offset(elapsed: int, total: int) -> Vector2:
	if total <= 0 or elapsed >= total or elapsed < 0:
		return Vector2.ZERO
	var t := float(elapsed) / TimingWindow.TICK_HZ
	var decay := 1.0 - float(elapsed) / float(total)
	var w := TAU * SHAKE_FREQUENCY_HZ
	return Vector2(sin(w * t), cos(w * 1.37 * t)) * SHAKE_AMPLITUDE * decay


## Seconds to whole ticks, at least one for any positive duration (the presentation twin of
## `TimingWindow.seconds_to_ticks`, which is state's own).
static func ticks(seconds: float) -> int:
	return 0 if seconds <= 0.0 else maxi(1, int(round(seconds * TimingWindow.TICK_HZ)))


## The impact look at world `position`: a spark burst, a swelling flash quad and a brief light, all freed on
## their own. `big` is RED's head contact; GREEN's dagger hit is the small one.
static func spawn_impact(parent: Node, position: Vector3, color: Color, big: bool) -> void:
	EffectFx.burst(parent, position, EffectFx.TEX_SPARK, color.lerp(Color.WHITE, 0.4),
			IMPACT_SPARK_AMOUNT_RED if big else IMPACT_SPARK_AMOUNT_GREEN, IMPACT_SPARK_LIFETIME,
			IMPACT_SPARK_SIZE, IMPACT_SPARK_SPEED, 180.0, 6.0)
	var flash := EffectFx.quad(EffectFx.TEX_STAR, color.lerp(Color.WHITE, 0.6),
			IMPACT_FLASH_SIZE_RED if big else IMPACT_FLASH_SIZE_GREEN, true)
	parent.add_child(flash)
	flash.global_position = position
	flash.scale = Vector3.ONE * 0.4
	var light := EffectFx.light(color.lerp(Color.WHITE, 0.5), IMPACT_LIGHT_ENERGY, IMPACT_LIGHT_RANGE)
	flash.add_child(light)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE, IMPACT_FLASH_SECONDS)
	tween.parallel().tween_property(light, "light_energy", 0.0, IMPACT_FLASH_SECONDS)
	tween.tween_callback(flash.queue_free)


## A one-shot placeholder sound on the `CombatCues` bus, freed when it ends.
static func play_sound(parent: Node, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"CombatCues"
	player.volume_db = volume_db
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
