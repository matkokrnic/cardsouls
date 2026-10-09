extends Node3D

## E0 Match Runner (D2). The ONE _physics_process in the project (INVARIANT F1). It OWNS the
## single MatchState (no autoload for live state), advances it in a fixed intra-tick order, and
## drives the hero actors from state. References are wired explicitly at match start.
##
## Tick order (D2 / F1): sample controllers -> gather spatial facts -> advance(intents) ->
## drive actor movement (move_and_slide, inside the actor) -> drain signals.

# Story 3-1 (AC 3): the four E0 tunable placeholders (_MAX_HP, _MOVE_SPEED, _MAX_STAMINA,
# _MAX_MANA) are DELETED — data/balance/balance_config.tres is their single source of truth and
# apply_balance() their single injection path, so a runner constant could only be a second value
# to disagree with the authored one.
#
# The seed is match-scoped, injected once at construction, and never re-applied by apply_balance()
# (E3-RG/R9) — it does NOT belong in the hot-reloadable BalanceConfig, where a reload would re-seed the
# RNG mid-match and blow a determinism hole. Story 7-4 (AC 16-19, `7-4/R13`/`R15`) RETIRED the `_SEED`
# constant that used to live here: the runner now resolves a per-launch seed (`_resolve_seed`), with the
# load-once `data/seed_pin.tres` knob and the `seed_override` test seat as the ways to fix it.

## Story 1-6 (AC 2): THE single per-slot controller-kind config point. Slot 0 = P1, slot
## 1 = P2. Swapping a slot's kind here is the ONLY edit dummy -> PvP -> bot needs — E2 (2-3)
## swapped slot 1 NULL -> KEYBOARD_P2, E7 -> a scripted kind — a one-line change, never a
## hero/actor/state edit (dummy identity is a controller choice, arch amendment A3). Slot 1
## ships KEYBOARD_P2 as of 2-3; NULL remains an available kind (the 1-6 training dummy) but
## is no longer the shipped default. The second slot itself has existed and been driven
## since E0 — this story SWAPPED its driver, it does not add a slot.
enum ControllerKind { KEYBOARD_P1, KEYBOARD_P2, NULL, GAMEPAD }

@export var slot_controller_kinds: Array[ControllerKind] = [
	ControllerKind.KEYBOARD_P1,  # slot 0 — P1 (local keyboard)
	ControllerKind.KEYBOARD_P2,  # slot 1 — P2 (local keyboard; 2-3 A3 flip NULL -> KEYBOARD_P2)
]

@onready var _p1_hero: HeroActor = $P1Hero
@onready var _p2_hero: HeroActor = $P2Hero
@onready var _p1_rig: CameraRig = $P1Hero/CameraRig
@onready var _p2_rig: CameraRig = $P2Hero/CameraRig
# Story 2-1: the rig's CHILD camera (framed by CameraRig.apply_config — distance/height/pitch)
# is the follow SOURCE; its global transform is mirrored onto the per-slot SubViewport follower
# camera each tick (step 4b). The rig cameras stay basis-only render-wise (no `current`).
@onready var _p1_rig_cam: Camera3D = $P1Hero/CameraRig/Camera3D
@onready var _p2_rig_cam: Camera3D = $P2Hero/CameraRig/Camera3D
# Story 2-1: the two split-screen follower cameras, one per SubViewport (main.tscn). Presentation
# only — driven by the runner in step 4b, never their own _physics_process (F1).
@onready var _p1_view_cam: Camera3D = $P1View/P1Viewport/P1Camera
@onready var _p2_view_cam: Camera3D = $P2View/P2Viewport/P2Camera

var _match_state: MatchState
var _p1_controller: Controller
var _p2_controller: Controller

## Story 3-0c (X5, AC 12): the ONE runner-owned recorder — a plain object called directly at the
## capture points below, NOT an eighth observation seam (no signal, no connect_ method, no state
## handle). It is a PASSIVE TAP: nothing it captures is ever read back into the tick.
var _recorder := IntentRecorder.new()

## Story 3-0d (AC 7): the last index SAVE has written to, in THIS session. Each press writes its
## OWN file (RecordFile.path_for), so two saves sit side by side and the second being longer than
## the first is directly observable. NOT recording state: the recorder is never consulted about
## it, never reset by it, and a session that never saves behaves identically.
##
## STARTS AT 0 EVERY SESSION, AND THAT USED TO BE THE DEFECT (`3-0d/R30`): a fresh session's first
## SAVE wrote `path_for(1)` again, silently destroying whatever a PRIOR session had already
## written there — measured live, against the operator, taking the only recording that had ever
## exercised the contact channel with it. `save_recorded_stream()` no longer trusts this counter
## alone: it asks `RecordFile.first_free_index(_save_index + 1)`, which checks the FILESYSTEM, so
## SAVE never overwrites an existing record — not two presses in one session, and not the first
## press of a session that follows one that already wrote there.
var _save_index := 0

## Story 3-0c (AC 9): set to a captured record BEFORE this node enters the tree to run the match
## FROM THAT RECORD instead of from live services and live hardware. Reachable only from a test
## in this story — the operator surface (start/stop/load, user:// persistence, the live reload
## trigger) is `3-0d`'s, per `3-0c/R5`.
##
## Replay guarantees STATE identity, not VISUAL identity: actor positions come from
## move_and_slide() and may drift between a recording and its replay. That is tolerable precisely
## because the ONLY physics-to-state channel is the contact fact, and the contact fact is
## recorded — anything a divergent position could do to the tick has to travel through
## push_contact, which replay supplies from the record rather than from the scene.
##
## Story 3-0d (`3-0d/R20`): THIS MEMBER IS AN ENTRY POINT, NOT A MODE SWITCH, AND THAT IS NOW
## STRUCTURAL. It is READ EXACTLY ONCE — in `_ready()`, into `_replay_record` below — and never
## again. Every later consumer (the per-tick fork, the live reload refusal) reads the PRIVATE
## field, so assigning this member mid-session HAS NO EFFECT: not because something catches the
## assignment, but because nothing reads what it changed. Three rounds of review defeated the
## source scan that used to police this by inspection; the property is carried by construction
## now (see test/integration/test_replay_entry_is_inert.gd, which is the mechanism).
var replay_record: IntentRecorder = null

## Story 3-0d (`3-0d/R20`): THE CONSUMED RECORD — the value `replay_record` held at `_ready()`,
## which is the only moment a replay can be entered. Everything downstream reads this. Restoring
## any consumer to the public member above is what makes the inertness test go red.
var _replay_record: IntentRecorder = null
## Ticks replayed so far — the cursor the recorded facts, bases and reload events are keyed by.
## Story 4-3b (AC 13, `4-3b/R17b`): the REACH-PROBE cadence counter. RUNNER-LOCAL and PRIVATE,
## reading the SAME authored `minion_retarget_interval_ticks` the state layer's own throttled
## targeting reads -- rather than a new public tick accessor on MatchState, whose `_tick` is private
## and surfaced only inside `to_snapshot()`. Incremented once per TICKING frame in the live gather
## branch only: a replay drains recorded facts and never gathers, so this counter is never consulted
## there and cannot desync a replay from its recording. Reset to 0 by `_relay_round_started` on a
## debug reset (review fix pass F3a).
##
## ONE COUNTER, SHARED ACROSS BOTH SLOTS (review fix pass F3b, documented rather than changed):
## `_gather_unit_facts` reads this same field for slot 0 and slot 1 both, so both players' minions
## probe on the same tick rather than each slot carrying its own phase. Deterministic and harmless
## today -- nothing depends on the two slots probing on staggered ticks -- so this is a NAMED
## coupling, not an oversight, for the next person who touches it.
var _probe_counter := 0

var _replay_tick := 0

## Story 3-0b (AC 1): the match-global DEBUG step/pause reader — a NON-Controller member of
## src/controllers/ (see its own header). It is NOT one of the two slot controllers: it produces
## no InputIntent and its presses never reach advance(). Held here because D3(a) keeps Input.*
## out of this file while F1 keeps the tick gate in it.
var _debug_input := DebugInputReader.new()
var _paused := false
## Story 6-10 (AC 9a): per-slot "was knocked down last frame", runner-local presentation memory for the
## step 1b poll, so card mode is dropped on the knockdown's RISING edge only -- a player may click L3 again
## while still down (Open Question 3) without being forced off every frame.
var _was_knocked_down: Array[bool] = [false, false]

## Story 3-0b (AC 2): the ONE debug instrument panel, kept so the runner can push the polled
## window-countdown payload into it after each advance(). A Control reference, never a seam.
var _instrument_panel: DebugInstrumentPanel

## Story 3-5a (AC 10): the two per-viewport HUD roots, kept so the runner can push each slot's
## armed-card selection into its own root after sampling. A Control reference, never a seam —
## the DebugInstrumentPanel member directly above is the same pattern.
var _huds: Array[HudRoot] = []

## Story 7-6 (operator rulings P20-P22, 2026-10-06): THE DEBUG LAYER, the one thing F3 toggles -- the instrument
## panel, both StateInspectors, both HUDs' orb counters and every telegraph SHAPE (both heroes' TelegraphControllers
## and the cast-target cone; P22 keeps every telegraph sound on). Hidden by default. Presentation only: nothing here reaches `advance()`.
var _debug_layer_visible := false
var _inspectors: Array[StateInspector] = []

## Story 4-1 (AC 7): the grey-box unit scene and the actors spawned from it, per slot. The SCENE
## REFERENCE LIVES HERE AND ONLY HERE -- src/state/ never holds one (UnitBoard is a pure
## RefCounted count), which is the HeroActor precedent: state decides that a unit EXISTS, the
## runner decides what that looks like and where it stands.
const UNIT_SCENE := preload("res://src/actors/minions/unit_actor.tscn")

## Story 4-4 (AC 3): the TOTEM scene — the same `CharacterBody3D` + `Collision` + `Hurtbox` pattern
## with the `Hitbox` deleted, mounting the SAME `unit_actor.gd` script. See `totem_actor.tscn`'s own
## description for why that is what "no second collision or damage-detection pattern is authored"
## means in practice.
const TOTEM_SCENE := preload("res://src/actors/minions/totem_actor.tscn")

## Story 4-4 (AC 14): the PROJECTILE scene — a plain `Node3D` carrying one `Hitbox` on the existing
## layer 3 / mask 2 convention, and no body collision.
const PROJECTILE_SCENE := preload("res://src/actors/projectiles/projectile_actor.tscn")

## Spawned actors per slot, index-aligned with nothing in state -- the board is a COUNT, so the
## runner's own array length is the whole of the correspondence. Freed together off the
## round_started relay (AC 8).
var _unit_actors: Array[Array] = [[], []]

## Story 4-4 (AC 14): spawned PROJECTILE actors per slot, index-aligned with `PlayerState.projectiles`
## the same way `_unit_actors` is with the unit board — position in the array IS the board index, so
## the runner's array index and the state layer's projectile identity are ONE number rather than two
## that could drift.
##
## GROWS ONLY, exactly like `_unit_actors`, and for the ruling that governs it: `ProjectileBoard.add`
## is an unconditional append that never fills a hole (`4-3a/R9`'s reasoning applied to a second
## container), so a freed shot leaves a `null` at a stable index and nothing is compacted. The
## arrays are emptied WHOLE by the debug reset, off the same `round_started` relay that empties
## `_unit_actors`.
var _projectile_actors: Array[Array] = [[], []]

## Story 6-6b (AC 10/AC 11): the counter presentation's runner-local bookkeeping -- whether each slot's
## `defense` snapshot key was running at the END of the previous tick (so a rising and a falling edge
## can be told apart), and each slot's in-flight dagger prop or null. Presentation only: neither
## reaches `to_snapshot()`, and a replay reproduces both by reproducing the key they are read from.
##
## POST-REVIEW FIX PASS (finding P2, ruling R-P2): plus the COLOUR and the REMAINING TICKS the key
## carried at the end of the previous tick, because "running" alone cannot see a RE-CAST. A press on
## the window's very last tick expires the old window at step 2 and starts a new one at step 6, so this
## poll -- which runs once, after `advance()` -- reads `running` on both sides of it and would fire
## neither edge, holding the old colour's paused frame over the whole new span.
var _counter_armed: Array[bool] = [false, false]
var _counter_color: Array[int] = [PlayerState.NO_TELEGRAPH_COLOR, PlayerState.NO_TELEGRAPH_COLOR]
var _counter_remaining: Array[int] = [0, 0]
var _counter_daggers: Array = [null, null]

## Story 7-10 (S2/S3, AC 8-14): the counter's CONTACT MOMENT, runner-local beside `_counter_armed` and for its
## reason -- presentation bookkeeping that never reaches `to_snapshot()` or the recorder, reproduced by a replay
## because every input is a state fact or an actor position read after `advance()`. Indexed by the COUNTERING
## slot unless named otherwise:
##   `_counter_landed` -- the state said this counter LANDED (`deflect_landed` carrying a colour). Review fix
##       (operator ruling): the arc, the body scale, the victim hold and the contact moment are for a landed
##       counter ONLY; until then -- and for good on a failed one -- the counter is 6-6b's (full travel, no arc);
##   `_red_travel_scale` / `_red_back_scale` / `_red_land_height` -- RED's forward- and back-leg body factors
##       and arc height, LOCKED AT THE LANDING from the actor-side gap left and the attacker's head (OQ1);
##   `_red_lift_floor` -- the arc fraction at the first landed tick, so the arc rises from the ground (-1 unset);
##   `_red_contact_tick` -- the window-elapsed tick of RED's head contact (`red_contact_elapsed_ticks`);
##   `_counter_impacted` -- this counter's impact has been shown;
##   `_victim_hold_ticks` -- indexed by the VICTIM's slot: ticks its pose has been held;
##   `_shake_elapsed` / `_shake_total` -- indexed by the CAMERA's slot: the running shake, -1 when none.
var _counter_landed: Array[bool] = [false, false]
var _red_travel_scale: Array[float] = [1.0, 1.0]
var _red_back_scale: Array[float] = [1.0, 1.0]
var _red_lift_floor: Array[float] = [-1.0, -1.0]
var _red_land_height: Array[float] = [0.0, 0.0]
var _red_contact_tick: Array[int] = [-1, -1]
var _counter_impacted: Array[bool] = [false, false]
var _victim_hold_ticks: Array[int] = [0, 0]
var _shake_elapsed: Array[int] = [-1, -1]
var _shake_total: Array[int] = [0, 0]

## Story 6-6b (AC 11): how high off the hero root the thrown dagger flies, in metres -- roughly chest
## height on this rig, so it reads as thrown rather than slid along the floor. A presentation constant
## beside `LOCK_MARK_TOTEM_LIFT`, never a `BalanceConfig` field: nothing in state knows this prop
## exists.
const DAGGER_THROW_HEIGHT := 1.2

## Story 6-5c (AC 25/AC 26): the cast presentation's runner-local bookkeeping -- whether each slot's
## `cast` snapshot key was in flight at the END of the previous tick (so a rising and a falling edge
## can be told apart), how many ticks the cast runs for, how far into it we are, on which tick the
## bolt leaves the sword, and each slot's in-flight bolt prop or null. Presentation only, exactly as
## `_counter_armed` and `_counter_daggers` above are: nothing here reaches `to_snapshot()`, and a
## replay reproduces all of it by reproducing the key it is read from.
##
## TICKS, NOT SECONDS, and that is what AC 25's arrival pin rests on: the strike lands N ticks after
## the press and the bolt is given the same integer N, so "the bolt arrives on the strike tick" is an
## equality of counts rather than a float comparison that could drift a tick either way.
##
## NO RE-CAST CASE (the `R-P2` problem the counter has): a caster cannot press a second cast while
## casting -- every card press is refused for the whole window (AC 8, `6-5c/R6`) -- so `is_casting()`
## always falls before it can rise again, and "running on both sides of a restart" is unreachable.
var _cast_armed: Array[bool] = [false, false]
var _cast_total_ticks: Array[int] = [0, 0]
var _cast_elapsed_ticks: Array[int] = [0, 0]
var _cast_launch_ticks: Array[int] = [0, 0]
var _bolts: Array = [null, null]

## Story 6-5d (AC 28, `6-5d/R10`): THE CAPTURED TARGET, CACHED ON THE RISING EDGE, and the cone prop for
## a unit target.
##
## IT IS CACHED FOR THE SAME REASON `_cast_total_ticks` IS. The address lives on `PlayerState` only while
## the cast does -- `clear_cast()` resets it -- and this poll still has work to do on the FALLING edge
## (ending the warning, freeing the prop), which is the tick the state has already cleared it. Reading
## the live member there would find the resting address and end the warning on the wrong body.
##
## A COPY OF A STATE FACT, NEVER A SECOND SOURCE OF IT: it is written only on the rising edge, from
## `cast_target_slot` / `cast_target_index`, which the state layer froze at the press. Presentation reads
## values, never internals -- the standing discipline for this whole poll.
var _cast_target_slots: Array[int] = [-1, -1]
var _cast_target_indices: Array[int] = [-1, -1]
var _target_cones: Array = [null, null]

## Smoke fix (6-5d, operator finding 2026-09-28): THE BOLT PROP EXISTS ONLY FOR A HONED BOLT CAST.
## Cached on the rising edge, the `_cast_target_slots` footing exactly: `MatchState.cast_outcome`
## resolves through the resolver (D6), never a card id named here, and the answer is frozen for the
## same reason the captured target is -- the cast's own mode is gone from `PlayerState` after the
## strike clears it, and this poll still has bolt bookkeeping to do on ticks after that (the arrived
## check above, the falling-edge free). Before this fix EVERY cast spawned and flew a lightning bolt
## regardless of outcome, so a Fireball activation showed the bolt prop landing (harmlessly -- state
## never read it) alongside the actual Fireball.
var _cast_shows_bolt: Array[bool] = [false, false]

## Story 7-1 (AC 23): the cast's resolver outcome, cached on the rising edge beside `_cast_shows_bolt` and for its
## reason -- the clip choice (Fireball / Rocksling / Honed Bolt's `cast`) is made once, on the press.
var _cast_outcomes: Array[StringName] = [&"", &""]

## Story 7-1 (AC 6-22): THE EFFECT PRESENTER -- every Deck 1 effect's look and sound. A runner-owned
## presentation node, handed plain values and scene nodes by the polls and the two sanctioned direct connects
## below; it holds no state handle (AC 5) and nothing it does reaches `advance()` (AC 4).
var _effects: EffectPresenter

## Story 7-1 (AC 30, `7-1/R4`): `"<card id>:<mode>"` -> the `CardEffect.effect_id` that resolution ran, derived
## load-once from `CardDatabase` (the `card_colors_by_id` HUD precedent: static authored content, read on both
## the live and the replay path, never injected and never recorded). It is how a `card_cast_resolved` payload
## finds its knob row and whether its own sound silences the generic cue.
var _effect_id_by_card_mode: Dictionary = {}

## Story 7-1 (AC 19, `7-1/R3`): A RUNNER-LOCAL COPY OF EACH PLAYER'S REVERSAL RECORD AS IT STOOD AT THE END OF
## THE PREVIOUS TICK. `_apply_counterspell` clears the countered packet before `counterspell_resolved` is queued,
## so the returned-item set is unreadable at the signal; this copy is what the "returned flashes blue" look reads.
## Copied only when the packet changed (an element-wise compare, no per-tick allocation). Presentation only: it
## never reaches `to_snapshot()` and a replay reproduces it by reproducing the packet.
var _prev_reversal_kind: Array[int] = [PlayerState.REVERSAL_NONE, PlayerState.REVERSAL_NONE]
var _prev_reversal_indices: Array = [[], []]
var _prev_reversal_a: Array = [[], []]
var _prev_reversal_b: Array = [[], []]
## 7-1 polish (smoke bug 1): each player's `last_resolved_card_tick` as it stood at the end of the previous tick.
## A resolution WROTE the reversal packet only if it went through `record_resolved_card` this tick, which moves
## that tick; an unblockable or defence resolution emits `card_cast_resolved` WITHOUT it, leaving the previous
## card's packet live -- so `_present_cast_resolved` shows a packet-driven look only when the tick moved.
var _prev_resolved_tick: Array[int] = [PlayerState.NO_RESOLVED_TICK, PlayerState.NO_RESOLVED_TICK]

## Story 7-1 (AC 16, `7-1/R2`): the hero-spell shots this tick's `advance()` ended, read BEFORE the drain
## (position, target, effect id, budget spent) and given their ending look AFTER it, once the drain has said
## how many deflects and hits each hero took and whether a Counterspell hit the owner. Paired by count.
var _ended_shots: Array = []
var _shot_hits: Array[int] = [0, 0]
var _shot_deflects: Array[int] = [0, 0]
var _shot_vanish: Array[bool] = [false, false]

## Story 7-1 review fix (F1): a record spawned with a RAISE SOURCE is either Raise Dead's minion or a minion a
## Counterspell RESTORED -- state re-adds a restored kill as a new record carrying its old index as
## `raised_from` (`_restore_killed_minion_at`), the very marker Raise Dead writes. The two cannot be told apart at
## the spawn poll (before the drain), so the spawn is NOTED here as `[slot, board index]` and given its look
## after the drain (`_resolve_raised_spawns`), the `7-1/R2` note-then-resolve shape. `_restored_sources` holds the
## `[slot, index]` minion addresses this tick's Counterspell returned, read from the `7-1/R3` previous-tick copy.
var _raised_spawns: Array = []
var _restored_sources: Array = []

## Story 7-1 (AC 11): each hero's hp at the end of the last poll, so a lifesteal HEAL (hp rising while Vampiric
## Aura runs) can be seen without a new seam; and whether a Drain resolved this tick (its heal is Drain's, not
## the aura's).
var _prev_hp: Array[float] = [0.0, 0.0]
var _drained_this_tick: Array[bool] = [false, false]

## Story 6-5c (AC 25): how high off the hero root the bolt leaves the raised sword, in metres --
## `DAGGER_THROW_HEIGHT`'s twin, and MEASURED rather than picked: `tools/measure_cast_clip_frames.gd`
## puts the sword's peak 1.0423 m above the Hips, the rig's Hips sit ~0.91 m above the model root,
## and `hero.tscn`'s Mesh node carries a -1.0 grounding offset -- so the raised sword tip is ~0.95 m
## above the hero ROOT (which is the body CENTRE, not the feet). A presentation constant, never a
## `BalanceConfig` field: nothing in state knows this prop exists.
const BOLT_LAUNCH_HEIGHT := 0.95

## Story 4-3e: WHERE A SUMMONED UNIT STANDS. Actor-owned position (`4-1/R12`), chosen by the
## runner and computed FRESH AT CAST TIME from the summoning hero's LIVE position: a spot BEHIND
## that hero, on the side away from the opponent (AC 1). This REPLACES the frozen per-slot row
## (`UNIT_ROW_X`/`UNIT_ROW_SPACING`/`UNIT_ROW_Z_START`), which was never hero-relative -- it only
## looked that way while both heroes stood on their authored spawns, and drifted apart from the
## hero the moment either one moved (heroes move freely since 1-2).
##
## THE COMMENT THAT STOOD HERE MADE TWO CLAIMS, BOTH FALSE, and 4-3e's AC 6(a) exists to correct
## them rather than let a stale citation keep shipping:
##   * "no gameplay reads it" -- false since 4-3. Contact facts and the reach probe are computed
##     from ACTOR POSITIONS, so the distance from the spawn spot to the hero (and to the opponent)
##     decides how long a minion runs before its first strike. Placement is a gameplay input.
##   * "4-3 replaces it with real placement" -- false. 4-3 never touched spawn placement; these
##     constants were the ONLY placement mechanism from 4-1 until this story.
##
## GEOMETRY, NOT BALANCE, so these stay `const` here rather than moving into balance_config.tres.
##
## `SPAWN_BEHIND_DISTANCE` MUST EXCEED `SPAWN_CLEARANCE_RADIUS` (4-3e Task 2): otherwise the base
## spot sits inside the summoning hero's own clearance and ring 0 is rejected on every single cast.
const SPAWN_BEHIND_DISTANCE := 2.5
## How close a candidate may come to an occupant (either hero, any live unit actor of either slot,
## or an earlier member of the same batch) before it counts as OCCUPIED. Derived, not tuned: a
## unit body box is 0.6 wide (inradius 0.3) and a hero's is 1.0 (inradius 0.5), so 0.8 is the
## touching distance of the worst pair and 0.9 carries a small margin over it.
const SPAWN_CLEARANCE_RADIUS := 0.9
## The FIXED POSITIVE STEP between rings of the outward search. Constant, never adaptive and never
## shrinking -- that is what makes the radius grow WITHOUT BOUND, which together with the finiteness
## of the occupants is the whole termination argument (4-3e AC 2). One unit body width.
const SPAWN_RING_STEP := 0.6
## Angular spacing of the candidates within one ring, and the ring's half-width. HALF-WIDTH PI/2
## IS THE REAR HALF-SPACE (AC 1): every candidate sits at |angle| <= 90 degrees off the away-from-
## opponent axis, so a candidate's displacement from the hero always has a NON-POSITIVE component
## along hero->opponent. A ring is therefore a rear ARC, never a full circle, and a crowded rear
## pushes the unit FURTHER BEHIND rather than around into the fighting space.
const SPAWN_ARC_STEP_RADIANS := PI / 6.0
const SPAWN_ARC_HALF_WIDTH_RADIANS := PI / 2.0
## Below this, hero->opponent is too short to give a reliable direction (the AC 3 case: a hero
## summoning while standing on the opponent). AC 1's ruling then governs: the arc's axis is the
## slot's FIXED away-from-centre axis, P1 toward -x and P2 toward +x.
const SPAWN_DEGENERATE_DIRECTION_EPSILON := 0.05
## The ground-level constant the runner has spawned units onto since 4-1 (the literal `0.0` that
## used to sit inline in `_spawn_missing_unit_actors`). NOT a raycast and NOT any physics query --
## a ground query inside the placement helper would break its purity (AC 9) and no `src/main/`
## guard would catch it. "Behind the hero" is PLANAR: the hero's `.y` is read for NOTHING, because
## the two roots disagree about what y means (hero root = body CENTRE at y 1, unit root = FEET).
const SPAWN_GROUND_Y := 0.0
## Story 5-0d fix pass (F1): the ARENA'S half-extent (`main.tscn`'s `Ground` `BoxShape3D`,
## `size = Vector3(40, 1, 40)`) and the largest half-extent of the two spawnable actor bodies
## (`totem_actor.tscn`'s `BoxShape3D_totembody`, `size = Vector3(0.8, 1.4, 0.8)`, half-extent 0.4 --
## bigger than `unit_actor.tscn`'s 0.3, so one shared margin is safe for either kind). Used only to
## CLAMP an already-accepted candidate back inside the ring (see `_compute_spawn_positions`) -- the
## rear-arc search itself is untouched, so 4-3e's "behind the hero" semantics are preserved for
## every candidate that already lands inside the ring; only a candidate that would have landed at
## or past the wall is pulled back to the ring's edge.
const SPAWN_ARENA_HALF_EXTENT := 20.0
const SPAWN_CONTAINMENT_MARGIN := 0.4
const SPAWN_CONTAINMENT_BOUND := SPAWN_ARENA_HALF_EXTENT - SPAWN_CONTAINMENT_MARGIN


func _ready() -> void:
	# TICK_HZ must equal the physics tick rate, or every seconds_to_ticks() is silently wrong.
	# Checked in the RUNNER (not state — state never reads ProjectSettings; D3(b)).
	var phys := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	Invariant.check(int(TimingWindow.TICK_HZ) == phys,
		"TimingWindow.TICK_HZ (%d) must equal physics_ticks_per_second (%d)" % [int(TimingWindow.TICK_HZ), phys])

	# Story 1-6 (AC 2/3): controllers come from the single per-slot config point above —
	# P2 defaults to NullController (training dummy). Fixed two-slot rig; a mis-sized config
	# is a programming error (Invariant.check, export-surviving — X1).
	Invariant.check(slot_controller_kinds.size() == 2,
		"slot_controller_kinds must have exactly 2 entries (P1, P2), got %d" % slot_controller_kinds.size())
	# Story 3-0c (AC 9): in replay mode BOTH slots are driven by the record. A ReplayController is
	# a plain Controller, so this is the 1-6 per-slot config point being used, not bypassed —
	# "dummy -> PvP -> bot -> replay is a config swap" is the D3 promise, honoured here.
	# Story 3-0d (`3-0d/R20`): THE ONE READ OF THE PUBLIC `replay_record`, IN THE WHOLE FILE. Replay
	# is a mode chosen BEFORE the node enters the tree, so this is the moment — and the only moment
	# — at which the choice is meaningful. Consuming it into a private field here is what makes a
	# mid-session assignment INERT BY CONSTRUCTION rather than merely forbidden by a scan.
	_replay_record = replay_record
	var replaying := _replay_record != null
	_p1_controller = ReplayController.new(_replay_record, 0) if replaying \
			else _make_controller(slot_controller_kinds[0], 0)
	_p2_controller = ReplayController.new(_replay_record, 1) if replaying \
			else _make_controller(slot_controller_kinds[1], 1)
	# Story 3-0c (AC 3): ONE seed value, read once and used twice — the record's when replaying,
	# the resolved launch seed otherwise (story 7-4, `_resolve_seed`). Never a second,
	# independently-read seed: what is captured is literally what reaches MatchParams, so a game dealt
	# from a random draw replays identically.
	var seed_value := _replay_record.replay_seed() if replaying else _resolve_seed()
	if not replaying:
		_recorder.capture_seed(seed_value)
	_seed_in_use = seed_value
	_match_state = MatchState.new(MatchParams.new(seed_value))
	# DEBT A retirement (story 1-3b): inject the authored balance ONCE at match start,
	# before the first tick — advance() reads balance_ticks, so without this call live-play
	# actions are inert (MatchState's balance_ticks == null guard, kept as a permanent
	# invariant). Story 3-1: this call is no longer a PARTIAL overwrite of constructor
	# placeholders — it is now the ONLY thing that gives either hero hp, move speed, or pool
	# bounds, so the match is stat-less until it runs (AC 3/AC 4). Mid-match reload stays
	# DEBT B (deferred): nothing calls apply_balance() a second time in live play.
	# Story 3-0c (AC 4, `3-0c/R4`): THIS call site is RELOAD EVENT #0 — the reload channel already
	# has the right shape for it, so the match-start injection needs no sixth channel of its own.
	# On replay the values come from the record and BalanceConfigService is never read, which is
	# what makes a recording survive a tuning pass.
	var balance_config: BalanceConfig = _replay_record.replay_balance_config(0) if replaying \
			else BalanceConfigService.get_config()
	Invariant.check(balance_config != null, "authored balance config missing at match start")
	if not replaying:
		_recorder.capture_apply_balance(balance_config)
	_match_state.apply_balance(balance_config)
	# Story 1-5 (B3): read FeatureFlagsService ONCE at match start and inject — the ONLY
	# place state receives flags (HARD RULE: state never reads the service). Flags are
	# load-once by design: no reload path, deliberately unlike balance.
	# Story 3-0c (AC 7, `3-0c/R3`): flags are a CAPTURE CHANNEL, which is not runtime mutation —
	# they stay load-once and runtime-immutable, FeatureFlagsService still has no reload path, and
	# a replay injects the RECORDED flags rather than reading the service.
	var feature_flags: FeatureFlags = _replay_record.replay_feature_flags() if replaying \
			else FeatureFlagsService.get_flags()
	Invariant.check(feature_flags != null, "authored feature flags missing at match start")
	if not replaying:
		_recorder.capture_inject_feature_flags(feature_flags)
	_match_state.inject_feature_flags(feature_flags)
	# Story 3-3 (AC 2/AC 4): deck CONTENT injection — the inject_feature_flags precedent
	# directly above (once at match start, content only, no reload path). The runner is the ONLY
	# reader of CardDatabase and the ONLY production caller of this seam: no file under
	# src/state/ may name the autoload (AC 8, machine-checked in test_architecture_invariants),
	# so the composition is derived HERE and plain StringName ids cross the boundary. deck_size
	# is read inline off the already-loaded authored config (CONSTRAINT C). An empty result is
	# rejected AT THE SEAM (AC 10), so there is deliberately no second check here.
	#
	# Story 3-0c (AC 5/AC 6): both content channels are captured here, in this order, and the
	# ORDER ITSELF enters the record. On replay the recorder re-injects in the recorded order and
	# refuses an unsound one — the cost seam's totality check reads _deck_contents, so
	# costs-before-deck would validate against an empty composition and pass vacuously.
	#
	# STATE AND DETERMINISM never read CardDatabase under replay: without this channel a recording
	# would silently depend on the contents of data/cards/, which change without a trace. That is
	# the invariant, and it is about the simulation only.
	#
	# Story 6-0 sharpened the wording, because PRESENTATION is a different matter and the blanket
	# claim this comment used to make ("replay never reads CardDatabase") had become false. The HUD
	# tint reads static database content at wiring time, on BOTH paths, and under replay it
	# therefore reflects TODAY's database rather than the recorded one. That is accepted and
	# deliberate, on the same footing as the caption: a replay already renders recorded ids with
	# today's presentation. The one visible consequence, documented rather than guarded: a recorded
	# id that no longer exists in today's database has no colour entry, so its swatch stays hidden
	# while the caption still shows the id. Presentation drifts with the database; the simulation
	# does not, and nothing in the golden or the replay record depends on the tint.
	if replaying:
		Invariant.check(_replay_record.replay_inject_content(_match_state),
			"recorded content order is unsound — the cast-cost totality check would be vacuous")
	else:
		# Story 6-5a (AC 11): the composition now comes from an AUTHORED DECK LIST (`DeckList`), not a
		# walk of the whole library. `deck_size` stays authored and is pinned equal to the list's copy
		# sum by `test_card_authoring.gd` (`6-5a/R9`); it is no longer what decides the composition.
		var deck_contents := _derive_deck_contents(_active_deck_list())
		# 6-5a REVIEW N7: INJECT FIRST, CAPTURE SECOND -- the one place in this block where the two are
		# in that order, and deliberately. `inject_deck` is where the EMPTY-composition check lives
		# (`match_state.gd`, AC 10); capturing before it meant a degraded run wrote a replayable-LOOKING
		# record naming an empty deck and only then complained. The record now exists only for a
		# composition the state layer accepted. The CAPTURE ORDER of the channels is untouched -- deck is
		# still the first channel captured -- so `SOUND_CONTENT_ORDER` and the replay are unaffected.
		_match_state.inject_deck(deck_contents)
		_recorder.capture_inject_deck(deck_contents)
		# Story 3-5a (AC 4): cast-cost injection, the same shape and the same seat as the deck
		# injection directly above. ORDER MATTERS and is not stylistic — the seam validates that
		# the map is TOTAL over the injected composition, so the composition must already be in.
		var card_costs := _derive_card_costs()
		_recorder.capture_inject_card_costs(card_costs)
		_match_state.inject_card_costs(card_costs)
		# Story 4-1 (AC 2, `4-1/R8`): card EFFECTS, the THIRD content channel, injected LAST. The
		# order deck -> costs -> effects is RULED, not stylistic, and it is load-bearing at both
		# ends: inject_card_effects()'s totality check reads the injected composition, so
		# effects-before-deck would validate against an empty one and pass vacuously, and
		# IntentRecorder.SOUND_CONTENT_ORDER pins this same order into the record.
		#
		# The derive+inject PAIR travels together in this NON-REPLAY branch and nowhere else
		# (`4-1/R3`): live play always injects, a replay never re-derives -- it takes the effects
		# the record carries, through replay_inject_content() in the branch above.
		var card_effects := _derive_card_effects()
		_recorder.capture_inject_card_effects(card_effects)
		_match_state.inject_card_effects(card_effects)
		# Story 5-2 (AC 4, `5-2/R1`): card COLOURS, the FOURTH content channel, injected LAST.
		# The order deck -> costs -> effects -> colours is load-bearing at the same end as the
		# other three: `inject_card_colors()`'s totality check reads the injected composition,
		# so colours-before-deck would validate against an empty one and pass vacuously, and
		# `IntentRecorder.SOUND_CONTENT_ORDER` pins this same order into the record. The
		# derive+inject pair travels together in this NON-REPLAY branch and nowhere else: a
		# replay takes the colours the record carries, through `replay_inject_content()`.
		var card_colors := _derive_card_colors()
		_recorder.capture_inject_card_colors(card_colors)
		_match_state.inject_card_colors(card_colors)
		# Story 6-2 (AC 2/AC 16): PITCH COSTS, the FIFTH content channel, injected LAST -- the order the
		# record's `SOUND_CONTENT_ORDER` pins. Its seam checks nothing against the composition, so its
		# position is not load-bearing for totality; the derive+inject pair travels in this NON-REPLAY
		# branch and nowhere else, and a replay takes the pitch costs the record carries.
		var pitch_costs := _derive_pitch_costs()
		_recorder.capture_inject_pitch_costs(pitch_costs)
		_match_state.inject_pitch_costs(pitch_costs)
		# Story 6-5a (AC 6): PITCH EFFECTS, the SIXTH content channel, injected LAST -- the pitch-cost
		# pair directly above followed verbatim, in the order `SOUND_CONTENT_ORDER` pins.
		var pitch_effects := _derive_pitch_effects()
		_recorder.capture_inject_pitch_effects(pitch_effects)
		_match_state.inject_pitch_effects(pitch_effects)
	# Story 1-7 (AC 4.3): relay MatchState's round_ended onto the global EventBus — the
	# one genuinely ownerless event. The relay lives in the RUNNER because state never
	# touches an autoload; the source signal is queued (D5), so the bus emission happens
	# at drain time, post-advance.
	_match_state.round_ended.connect(_relay_round_ended)
	# Story 2-6 (AC 1, 2-6/R5): relay the reset counterpart exactly the same way — directly in
	# _ready(), no new per-slot connect_ seam. State never touches an autoload, so the runner is
	# the one seat that bridges MatchState.round_started onto the ownerless EventBus.
	_match_state.round_started.connect(_relay_round_started)
	# Story 3-5b (AC 6): the vulnerable-window relay, wired here for the same reason and in the
	# same shape as the two above — one line in _ready(), no new per-slot connect_ seam, so the
	# observation-seam family (seven at 2-6/R7, nine as of 5-4/R4) is untouched. State owns the
	# signal; the bus is the runner's to reach.
	_match_state.reshuffle_vulnerable_window_opened.connect(
			_relay_reshuffle_vulnerable_window_opened)
	# Story 7-6 (D1): the two public cast-resolution relays, the same shape as the three above -- one line each,
	# no new per-slot connect_ seam (the family stays ten) and no new inline consumer. Both HudRoots subscribe to
	# the bus below. `_effect_id_by_card_mode` is filled by `_setup_effect_presenter` at the end of `_ready`,
	# before the first tick can queue a resolution.
	_match_state.card_cast_resolved.connect(_relay_card_cast_resolved)
	_match_state.counterspell_resolved.connect(_relay_counterspell_resolved)
	# Story 2-4 (2-4/R3): the throwaway 1-3c debug overlay is RETIRED here — E2 replaces it
	# with the real HUD. One HudRoot per viewport, constructed in code and added under each
	# SubViewport (the overlay's code-construction pattern, reparented per-viewport instead of
	# to the runner root — the HUD must be per-viewport, not one global overlay). No main.tscn
	# edit, no new .tscn, no camera, no reparented gameplay node (2-4/R6). Each root is wired
	# ONLY to its own slot's three economy seams (2-4/R7 no-opponent-read: it is handed only
	# this player's payloads and structurally cannot reach the opponent) plus the ownerless
	# EventBus.round_ended (2-4/R4: the four combat seams stay owned by TelegraphController and
	# are NOT re-consumed here). The three economy seams PRIME ON CONNECT, so the bars render
	# full immediately — add_child fires the root's _ready (parent SubViewport is already in
	# the tree) BEFORE these connects, so the bars exist when the priming call lands.
	var hud_viewports: Array[SubViewport] = [$P1View/P1Viewport, $P2View/P2Viewport]
	var huds: Array[HudRoot] = []
	# Story 6-0 (AC 2/AC 3/AC 4): the same TOTAL id->colour map _derive_card_colors() builds for
	# the state-injection channel (line ~330, non-replay only), built AGAIN here so it is
	# available under BOTH replay and live play -- this read is CardDatabase content, static and
	# load-once with no live/replay divergence risk (unlike the _card_colors MatchState injects,
	# which this HUD wrapper does not touch). Held as a local, captured by the cards_changed
	# wrapper lambda below -- a plain Dictionary carries no reference-cycle risk the way a
	# PlayerState capture did (4-B1 code review, see the lambda's own comment).
	var card_colors_by_id := _derive_card_colors()
	# Story 6-5b (AC 23, operator ruling on this story's one open question): the HAND-ROW PRICE MAP,
	# DERIVED LOAD-ONCE on the `card_colors_by_id` precedent one line up -- built here so it is
	# available under BOTH replay and live play, held as a local and captured by the cards_changed
	# wrapper below (a plain Dictionary carries no reference-cycle risk, that lambda's own comment).
	#
	# PRICES ARE STATIC AUTHORED DATA. They never enter game state, never enter the record and are NOT
	# a `FORMAT_VERSION` cause: `CardData.cast_condition` / `pitch_condition` are content no tick
	# mutates, so there is no live/replay divergence to protect against and nothing for a capture
	# channel to carry. That is the whole reason AC 23 costs this story no state -- unlike the injected
	# `_card_costs` map, which state DOES consume and which therefore IS recorded.
	var card_prices_by_id := _derive_card_prices()
	# Story 7-6 (R2, D2): the card -> [normal effect, pitch effect] pairing and the effect icon table, both
	# load-once static content on the `card_prices_by_id` precedent -- the HUD keys its art by EFFECT id.
	var card_effect_ids := _derive_card_effect_ids()
	var effect_icons := load(EffectIconSet.AUTHORED_PATH) as EffectIconSet
	for slot: int in 2:
		var hud := HudRoot.new()
		hud.set_effect_art(card_effect_ids, effect_icons)
		# Story 7-6 POLISH 2 (P13): the slot reel spins through THIS player's own deck -- the authored composition
		# (both slots play the active deck list today), never the draw order or the next card.
		hud.set_reel_cards(_active_deck_list().card_ids)
		# Story 7-6 (R6): the play-history strip rides this half's OUTER edge -- P1's half is the left one.
		hud.history_on_left = slot == 0
		# Story 3-6 (AC 4): the authored vulnerable-window duration, handed over BEFORE add_child
		# on the `gamepad_profile` static-handoff precedent. The HUD renders the reshuffle
		# flag from the ownerless EventBus event plus this number and NOTHING else — it never reads
		# the window's tick count, which stays write-only unhashed state (3-5b/R20, 3-6/R3). Read
		# inline off the already-loaded authored config (CONSTRAINT C).
		hud.reshuffle_vulnerable_window_seconds = balance_config.reshuffle_vulnerable_window_seconds
		hud_viewports[slot].add_child(hud)
		huds.append(hud)
		connect_hero_hp_changed(slot, hud.on_hp_changed)
		connect_stamina_changed(slot, hud.on_stamina_changed)
		connect_mana_changed(slot, hud.on_mana_changed)
		# Story 5-4 (AC 18-20): the NINTH seam's HUD consumer, bound to this root's own slot
		# exactly like the three economy seams above (2-4/R7 no-opponent-read). It PRIMES ON
		# CONNECT with the resting (0,0,0), so the reserved orb region renders real zeroes from
		# frame one rather than a placeholder, and updates live from the landing seat afterwards.
		connect_orbs_changed(slot, hud.on_orbs_changed)
		# Story 3-6 (AC 2): the eighth seam's ONE production consumer, bound to this root's own
		# slot exactly like the three economy seams above (2-4/R7 no-opponent-read).
		# Story 4-B1 (AC 1): wrapped rather than passed bare, so this player's OWN
		# `pending_draw_owed` rides alongside the seam's three existing values without a new
		# signal, a new seam, or a src/state/ change. Read INLINE at the moment the seam fires
		# (CONSTRAINT C, never cached) -- the wrapper's own 3-arg signature matches what
		# connect_cards_changed primes with, so priming is unaffected.
		#
		# THE LAMBDA CAPTURES NO PlayerState (4-B1 code review). It used to capture one, and that
		# was a reference CYCLE, not a style point: PlayerState is RefCounted, the lambda is stored
		# in that same PlayerState's own `cards_changed` connection list, and the capture closed the
		# loop -- leaked at exit. Resolving p1/p2 INSIDE the body captures only `self` (a Node, not
		# ref-counted) and `slot`, and it makes CONSTRAINT C literally true of the OBJECT as well as
		# the field rather than merely asserted. `.duplicate()` for the same reason the 4-0 review
		# patched the snapshot key: a UI layer is handed a copy, never a live handle into state.
		var slot_index := slot
		connect_cards_changed(slot, func(hand_ids: Array, deck_count: int, discard_count: int) -> void:
			var player: PlayerState = _match_state.p1 if slot_index == 0 else _match_state.p2
			# Story 6-0 (AC 2): card_colors_by_id rides this SAME wrapper -- no new connect_* seam
			# (this wrapper adds no member to the family test_architecture_invariants.gd pins). Reused, not
			# re-derived: the local built once above this loop, read inline here (CONSTRAINT C).
			# Story 7-6 (R4): plus the CARD layer beneath any Boulder cover (`hand_ids` is the visible layer),
			# read inline here exactly like `pending_draw_owed` -- this player's own hand, a fresh copy.
			hud.on_cards_changed(hand_ids, deck_count, discard_count,
					player.pending_draw_owed.duplicate(), card_colors_by_id, card_prices_by_id,
					player.hand.to_array())
			# Story 6-D1 (debug): the same hand + colour map the HUD tint reads, forwarded to the
			# controller as plain ints (-1 = empty slot). No state handle crosses; base is a no-op.
			var hand_colors: Array[int] = []
			for id: StringName in hand_ids:
				hand_colors.append(card_colors_by_id.get(id, -1))
			(_p1_controller if slot_index == 0 else _p2_controller).observe_hand_colors(hand_colors))
		EventBus.round_ended.connect(hud.on_round_ended.bind(slot))
		# Story 6-3b (AC 1/AC 3): the TENTH seam's HUD consumer. Match-level, so BOTH roots receive BOTH
		# zones and each binds its OWN slot to tell them apart -- the on_round_ended bind directly above,
		# second time. No priming: both zones are empty until the first staging.
		connect_pitch_changed(hud.on_pitch_changed.bind(slot))
		# Story 3-6 (AC 4): the reshuffle flag. BOTH viewports subscribe to the SAME ownerless bus
		# event (E3-RG/R3 — "this player's deck ran out" is a match-wide public fact), each binding
		# its OWN slot so it can render the event against itself: the round_ended wiring directly
		# below, second time. A plain bus connect, not a seam — the family stayed at eight here
		# (5-4 later moved it to nine with connect_orbs_changed; this line still adds none).
		EventBus.reshuffle_vulnerable_window_opened.connect(
				hud.on_reshuffle_vulnerable_window_opened.bind(slot))
		# Story 2-6 (AC 1): the label's single CLEAR seat — a debug reset hides it on BOTH
		# viewports. No-argument and slot-independent (the reset is ownerless), so no .bind(slot).
		EventBus.round_started.connect(hud.on_round_started)
		# Story 7-6 (D1, R6): the play-history strip. BOTH roots subscribe to the two public bus relays, each
		# binding its OWN slot to tell its entries from the opponent's -- the reshuffle wiring above, verbatim.
		EventBus.card_effect_resolved.connect(hud.on_card_effect_resolved.bind(slot))
		EventBus.card_effect_countered.connect(hud.on_card_effect_countered.bind(slot))
	# Story 2-6 (AC 2): per-player debug StateInspector, one per SubViewport (the HudRoot
	# per-viewport pattern). READ-ONLY: wired to FIVE of the existing observation seams (no eighth),
	# each bound to its own slot; the three economy seams prime on connect so its bars render at once.
	for slot: int in 2:
		var inspector := StateInspector.new()
		hud_viewports[slot].add_child(inspector)
		_inspectors.append(inspector)
		connect_hero_action_state_changed(slot, inspector.on_action_state_changed)
		connect_hero_action_rejected(slot, inspector.on_action_rejected)
		connect_hero_hp_changed(slot, inspector.on_hp_changed)
		connect_stamina_changed(slot, inspector.on_stamina_changed)
		connect_mana_changed(slot, inspector.on_mana_changed)
	# Story 2-6 (AC 4/5): the ONE global debug instrument panel. Added as a top-level Control child
	# of the runner root so it renders over the whole window (its controls are window-global). It
	# flips only presentation/controller-local switches (2-6/R4): the magnitude switch mutates the
	# SHARED gamepad profile IN MEMORY (load() returns the resource-cache instance the gamepad
	# controllers also read — never persisted). Story 6-3b retired its Pitch Zone placement switch with
	# the dead-centre pitch panel it moved; the panel holds no HudRoot reference any more.
	var panel := DebugInstrumentPanel.new()
	panel.gamepad_profile = load("res://data/gamepad_profile.tres") as GamepadProfile
	# Story 3-0d (AC 7, `3-0d/R13`): the panel's TWO runner-reaching controls — SAVE and RELOAD.
	# Each handed its own Callable before add_child, the gamepad_profile precedent
	# generalised: the panel receives a way to ASK, never the recorder itself, never a state
	# handle and never the BalanceConfigService reference. No start control and no load control
	# ship (`3-0d/R1`, `3-0d/R2`), and no Input Map action is added — both are mouse-only, exactly
	# like the one switch beside them.
	panel.save_record = save_recorded_stream
	panel.reload_balance = trigger_live_balance_reload
	# Story 4-B1 (AC 2/AC 3, `4-B1/R1`): the panel's FIFTH control and its THIRD runner-reaching
	# seam, same Callable-handoff shape as the two directly above -- a read accessor, not a
	# push, so the panel calls it only from its own toggle handler.
	panel.reveal_opponent_hand = debug_hand_contents
	# Story 7-4 (AC 18): the seed this match was dealt from -- a one-time fact, handed over before add_child
	# on the `gamepad_profile` precedent and rendered by the panel, so it shows and hides with the F3 layer.
	panel.seed_value = _seed_in_use
	add_child(panel)
	# Story 7-6 POLISH (operator ruling P12, 2026-10-06; discharges 4-B1's "DebugInstrumentPanel ergonomics"
	# deferral): the panel is HIDDEN by default and toggled by F3 (`debug_toggle_instruments`, step 0 below). While
	# hidden the HUD may use its space; shown, it may overlay the HUD. P20/P21 widened F3 to the whole debug layer:
	# the default is applied once, after the heroes are wired (`set_debug_layer_visible`, below).
	# Story 3-5a (AC 10): kept for the per-tick selection-indicator push in _physics_process.
	_huds = huds
	# Story 3-0b (AC 2): kept for the per-tick countdown push in _physics_process step 3b.
	_instrument_panel = panel
	# Story 1-10 (AC 3/4): each hero's telegraph controller — the FIRST consumer of the
	# two seams landed below (connect_hero_action_rejected, connect_deflect_landed) and a
	# parallel consumer of the existing two. Signal payloads only, never a state handle;
	# match-level payloads (hit/deflect/round end) get this hero's slot BOUND at wiring,
	# so the controller itself carries no identity. EventBus.round_ended is the one
	# non-seam channel (global, ownerless — D5).
	for slot: int in 2:
		var actor: HeroActor = _p1_hero if slot == 0 else _p2_hero
		var cues: TelegraphController = actor.telegraph_controller
		var anim: AnimationController = actor.animation_controller
		# Story 5-3 (AC 9/10): CHARGING's clip/telegraph choice needs the COLOUR, which the
		# action-state transition signal itself never carries (previous, current only). These
		# two wrapping lambdas are the new read path: a one-time read of the `telegraph`
		# snapshot fact (5-2) at the transition instant, via _charge_color_for_slot below. NOT
		# a new connect_* wrapper (the seam family was at eight here; 5-4 moved it to nine, and
			# this read path still adds none) and NOT a captured
		# PlayerState (4-B1 review precedent: PlayerState is RefCounted and a reference
		# captured into a Callable stored inside that same PlayerState's own signal-connection
		# list is a reference cycle) -- slot is re-resolved to a PlayerState by
		# _charge_color_for_slot on every call instead, exactly like every other per-slot
		# lookup in this file.
		connect_hero_action_state_changed(slot,
				func(previous: HeroState.ActionState, current: HeroState.ActionState) -> void:
					cues.on_action_state_changed(previous, current,
							_charge_color_for_slot(slot, current)))
		connect_hero_action_rejected(slot, cues.on_action_rejected)
		connect_hit_landed(cues.on_hit_landed.bind(slot))
		connect_deflect_landed(cues.on_deflect_landed.bind(slot))
		# Story 5-4 (AC 17): the earn cue, the NINTH seam's SECOND consumer. Bound to this
		# hero's own slot exactly like the four combat seams above, and it needs no slot argument
		# of its own because the channel is already per-slot. The controller derives "a colour
		# went UP" by diffing successive payloads and deliberately swallows the PRIMING call (see
		# TelegraphController.on_orbs_changed) -- pinned by test/integration/test_orb_cue_live.gd
		# (AC 16), because wiring order x controller state is runtime COMPOSITION that no
		# state-level test reaches (`3-0b/R34`).
		connect_orbs_changed(slot, cues.on_orbs_changed)
		# Story 7-6 (R7, AC 27/AC 28): the WORLD ORBS -- a halo child of this hero in the shared World3D, so both
		# halves see it by construction. The ninth seam's third consumer, bound to this hero's OWN slot like the
		# earn cue directly above; no cross-slot read and no new seam. Its hues are this hero's own charge
		# telegraph colours (the 7-1 "no second colour table" rule).
		var halo := OrbHalo.new()
		halo.setup([cues.charge_red_profile.color, cues.charge_blue_profile.color,
				cues.charge_green_profile.color] as Array[Color])
		actor.add_child(halo)
		connect_orbs_changed(slot, halo.on_orbs_changed)
		EventBus.round_ended.connect(cues.on_round_ended.bind(slot))
		# Story 5-3 (AC 13): S5's success-cue half. card_cast_resolved is an EXISTING state-owned
		# signal (both _resolve_basic_cast's and _resolve_unblockable_cast's success paths already
		# emit it) with no listener before this story. A direct connect, not a new connect_* wrapper
		# -- test_runner_observation_seams_are_exactly_ten pins the family (at eight when this
			# line shipped, nine since 5-4 AC 15, ten since 6-3b AC 1) (2-6/R7 amended
		# by 3-6/R2) and this adds no eleventh.
		#
		# THIS IS A NEW CONNECTION SHAPE, NAMED AS ONE (5-3 review correction; this comment used to
		# claim it mirrored the EventBus carve-out, and it does not). That precedent is a relay onto
		# an OWNERLESS GLOBAL BUS: MatchState.reshuffle_vulnerable_window_opened is relayed to
		# EventBus (`:346`, `_relay_reshuffle_vulnerable_window_opened`) and the CONSUMERS subscribe
		# to the bus (`:399`), never to state. Here a PRESENTATION CONSUMER is wired straight to a
		# MatchState signal with no bus and no seam -- the first of its kind in this file. It is
		# sound (read-only, per-slot guarded, dependency direction unchanged: visuals -> state) and
		# the operator has ruled that it STANDS. It is recorded as a candidate for the architecture
		# amendment queue rather than quietly filed under an existing precedent, because a third and
		# fourth of these would be a de-facto ninth seam family nobody voted for.
		# Story 6-5a (AC 7): the signal carries a third argument, the resolved MODE; this cue ignores it.
		# Story 7-1 (AC 6-22/AC 30, `7-1/R4`): the SAME site, its body widened -- no new connect. The resolution
		# is handed to the effect presenter first, and the generic success cue stays the FALLBACK: it plays only
		# when the resolved effect has no own resolution sound.
		_match_state.card_cast_resolved.connect(func(cast_slot: int, card_id: StringName,
				mode: int) -> void:
			if cast_slot == slot:
				if not _present_cast_resolved(cast_slot, card_id, mode):
					cues.on_card_cast_resolved())
		# Story 6-5f (AC 26, `6-5f/R35`): the COUNTERSPELL placeholder cue, on BOTH heroes. The SECOND
		# connection of the shape named two comments up, wired the same way and for the same reason -- a
		# PLAIN `connect` to a `MatchState` signal, read-only, per-slot guarded, dependency direction
		# unchanged. `test_runner_observation_seams_are_exactly_ten` is untouched: no eleventh
		# `connect_*` wrapper ships.
		#
		# THE CANDIDATE-FOR-THE-AMENDMENT-QUEUE NOTE ABOVE IS HEREBY THE SECOND OF THE "third and fourth
		# would be a de-facto seam family nobody voted for" it warns about. Recorded, not quietly filed:
		# this story does not open the seam-family question, and the next such connection should.
		#
		# BOTH SLOTS FIRE, WHICH IS AC 26's "on both heroes", and the guard is an `or` rather than an
		# equality: the cue is one sign on the caster and one on the countered player, so a hero whose slot
		# is EITHER payload member plays it. A Counterspell cannot name the same slot twice (the victim is
		# `1 - slot` by construction), so no hero can double-fire it.
		#
		# Story 7-1 (AC 19): the SAME site, its body re-pointed -- no new connect. The violet placeholder is retired;
		# the blue rune circle on BOTH heroes, the returned-item flash and the `counter` sound are the effect
		# presenter's, fired ONCE per reversal (the caster's iteration of this two-slot loop).
		_match_state.counterspell_resolved.connect(func(caster_slot: int,
				countered_slot: int) -> void:
			if caster_slot == slot:
				_present_counterspell(caster_slot, countered_slot))
		# Story 3-0a: the rig animation controller shares the action-state seam -- the five
		# ActionState-driven clips (idle/attack/block/roll/death), now six with CHARGING (5-3).
		# The locomotion clips are NOT wired here: HeroActor.drive() pushes them per-tick from
		# velocity (3-0a/R2). Read-only, no state handle, mirroring the telegraph wiring.
		#
		# Story 6-6a (AC 8-11): the rig closure forwards THREE more runner-computed values on
		# `charge_color`'s exact shape -- the stun flavor and its hold span (the STUNNED pose), and whether
		# the get-up iframes were just armed (the get-up clip on the timer exit only). Still one closure,
		# still no new seam; the telegraph closure above is unchanged.
		connect_hero_action_state_changed(slot,
				func(previous: HeroState.ActionState, current: HeroState.ActionState) -> void:
					anim.on_action_state_changed(previous, current,
							_charge_color_for_slot(slot, current), _stun_flavor_for_slot(slot),
							_stun_seconds_for_slot(slot), _get_up_armed_for_slot(slot)))
		# Story 6-6a (AC 1/AC 2/AC 5/AC 12): the rig controller becomes the SECOND consumer of the existing
		# `hit_landed` seam, beside `cues.on_hit_landed` above -- this grows the seam's CONSUMER count, not
		# the `connect_*` family (still ten). The signal's payload is NOT widened (TelegraphController's
		# bound handler has fixed arity); the closure forwards the four arguments, this hero's slot, and
		# the runner-computed stun flavor/span the AC 5 escalation re-check needs. The controller gates on
		# `target_slot == slot` itself, exactly as the telegraph handler does.
		#
		# 6-6a review (D2): plus whether THIS hit was actually BLOCKED, read from the state layer while the
		# hit is being emitted (`MatchState.hit_landed_was_blocked`), so `block_impact` plays for a blocked
		# hit only and never for a full-damage hit from outside the block arc.
		connect_hit_landed(func(attacker_slot: int, target_slot: int, damage: float,
				target_hp: float) -> void:
			anim.on_hit_landed(attacker_slot, target_slot, damage, target_hp, slot,
					_stun_flavor_for_slot(slot), _stun_seconds_for_slot(slot),
					_match_state.hit_landed_was_blocked()))
	_setup_effect_presenter()
	# Story 7-10 review fix (T1): the counter's contact moment waits for the state's LANDED fact -- a consumer of the
	# existing `deflect_landed` seam (a seam CALL, the `_setup_effect_presenter` precedent; the family stays at ten).
	connect_deflect_landed(_on_counter_deflect_landed)
	# Story 7-6 (P20/P21): the debug layer starts hidden.
	set_debug_layer_visible(false)


## Story 7-6 (operator rulings P20/P21, 2026-10-06): show or hide the WHOLE debug layer -- the one seat the F3 edge
## (step 0) calls. Everything it touches keeps updating while hidden, so showing it mid-match shows live values.
## Not touched: the deck indicator, the lock marker, every telegraph sound (P22), the world orbs and every 7-1 effect.
func set_debug_layer_visible(shown: bool) -> void:
	_debug_layer_visible = shown
	_instrument_panel.visible = shown
	for inspector: StateInspector in _inspectors:
		inspector.visible = shown
	for hud: HudRoot in _huds:
		hud.set_debug_layer_visible(shown)
	for hero: HeroActor in [_p1_hero, _p2_hero]:
		if is_instance_valid(hero):
			hero.telegraph_controller.set_cues_shown(shown)
	for cone: Variant in _target_cones:
		if is_instance_valid(cone):
			(cone as Node3D).visible = shown


## Story 7-1 (AC 6-22, AC 27, AC 29): build the effect presenter and hand it its two inputs -- the AUTHORED knob
## set (`7-1/R6`'s presentation-only home) and the existing colour vocabulary, the three charge
## `TelegraphProfile`s the hero's telegraph controller already exports (AC 27: no second colour table).
##
## TWO MORE CONSUMERS OF EXISTING SEAMS, NO NEW SEAM (AC 3): `connect_hit_landed` / `connect_deflect_landed` are
## seam CALLS, the `anim.on_hit_landed` precedent above -- the family of `connect_*` declarations stays at ten and
## no raw `_match_state.<signal>.connect(` site is added. They count, per hero, the hits and deflects a tick's
## drain announced, which is all `7-1/R2`'s shot-ending read needs.
func _setup_effect_presenter() -> void:
	_effects = EffectPresenter.new()
	_effects.name = "EffectPresenter"
	add_child(_effects)
	var cues: TelegraphController = _p1_hero.telegraph_controller
	_effects.setup(load(EffectPresentationSet.AUTHORED_PATH) as EffectPresentationSet, {
		Enums.CardColor.RED: cues.charge_red_profile,
		Enums.CardColor.BLUE: cues.charge_blue_profile,
		Enums.CardColor.GREEN: cues.charge_green_profile,
	})
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null:
			continue
		for pair: Array in [[Enums.ModeKind.BASIC, card.basic_effect, card.cast_condition],
				[Enums.ModeKind.PITCH, card.pitch_effect, card.pitch_condition]]:
			var effect := pair[1] as CardEffect
			if effect == null:
				continue
			_effect_id_by_card_mode["%s:%d" % [id, pair[0]]] = effect.effect_id
			# The X-scaled shot (Fireball, AC 16/AC 17): its growth range is authored data -- damage per mana,
			# the card's staging price as the minimum X, and the mana cap.
			if effect.damage_per_mana > 0.0:
				var condition := pair[2] as CardCastCondition
				_effects.set_fireball_range(effect.damage_per_mana,
						condition.mana_cost if condition != null else 0.0, effect.mana_cap)
	connect_hit_landed(_on_effect_hit_landed)
	connect_deflect_landed(_on_effect_deflect_landed)


## Story 6-5a (AC 11): the AUTHORED deck both players draw from until a second deck exists -- Deck 1.
const DECK_LIST_PATH := "res://data/decks/deck_1.tres"

## Story 6-5a (AC 13): THE DECK-LIST SEAT a live test uses instead of fixed-seed luck. Set BEFORE the
## runner enters the tree (its `_ready` derives the composition), and read nowhere else; null -- every
## shipped path -- means `DECK_LIST_PATH`. Both players still receive ONE injected composition.
var deck_list_override: DeckList = null

## Story 7-4 (AC 19, `7-4/R15`): THE SEED SEAT a headless test uses to fix the deal -- the
## `deck_list_override` precedent directly above: set BEFORE the runner enters the tree, read once in
## `_ready` (through `_resolve_seed`) and nowhere else. 0 = unset. Every live test that depends on the
## dealt hand sets it to 12345, the seed the runner shipped as a constant before this story.
var seed_override: int = 0

## Story 7-4 (AC 17): the load-once pin knob's path. See `SeedPin`.
const SEED_PIN_PATH := "res://data/seed_pin.tres"

## Story 7-4 (AC 18): the seed this match was dealt from (whichever source won), for the F3 label. Written
## once in `_ready`. Tests read the seed where it is recorded, `_recorder.replay_seed()` (AC 16).
var _seed_in_use := 0


## Story 7-4 (AC 16-19, `7-4/R13`/`R15`): the LAUNCH SEED when not replaying (the replay record's seed
## outranks all of this at the one call site). Precedence: `seed_override` > the `data/seed_pin.tres` pin >
## a fresh random draw. THE DRAW LIVES HERE, outside `src/state/`, on a local generator that is used once
## and dropped -- the gameplay RNG is still only `MatchState`'s, seeded from the value returned. A draw of 0
## is redrawn, so a seed shown on the F3 layer can always be copied into the pin (where 0 means unset).
func _resolve_seed() -> int:
	if seed_override != 0:
		return seed_override
	var pin := load(SEED_PIN_PATH) as SeedPin
	if pin != null and pin.pinned_seed != 0:
		return pin.pinned_seed
	var draw := RandomNumberGenerator.new()
	draw.randomize()
	var value := 0
	while value == 0:
		value = draw.randi()
	return value


## 6-5a REVIEW N7: the shipped list is ONE `.tres` behind one `load()`, and a failed load or a type
## mismatch answers `null` -- which `_derive_deck_contents` used to turn into an empty composition, in
## silence. Before this story the composition came from the whole `CardDatabase`, so no single file could
## do that. The seam is LOUD now: `Invariant.check` names the path, and the empty composition it would
## otherwise produce can no longer reach the recorder (see the capture order at the injection seat).
func _active_deck_list() -> DeckList:
	if deck_list_override != null:
		return deck_list_override
	var loaded := load(DECK_LIST_PATH) as DeckList
	Invariant.check(loaded != null,
		"the authored deck list failed to load as a DeckList (%s) -- a missing file, a failed export "
				% DECK_LIST_PATH + "remap, or a type mismatch; the match has no composition")
	return loaded


## Story 6-5a (AC 11): the deck COMPOSITION, expanded from an authored `DeckList` IN LIST ORDER -- entry
## by entry, each id repeated its `copies` times. This REPLACES story 3-3's provisional walk of the whole
## library in sorted-id order up to each card's `max_copies`: the nine fixture cards stay authored in
## data/cards/ and are simply not listed (R1). List order is what makes the result deterministic --
## the pre-shuffle order feeds the seeded shuffle, which is why the list is ordered and never a
## Dictionary. A card the library does not hold is SKIPPED rather than injected, so a mistyped id can
## never reach a hand; an empty result is caught loudly at the injection seam (3-3 AC 10), not here.
##
## THIS IS STILL NOT THE DECKBUILDING SEAT, and it lives in the RUNNER because it is the one place
## allowed to read CardDatabase (3-3 AC 2) -- src/state/ may not so much as name it (3-3 AC 8).
## 6-5a REVIEW N6: THE EXPANSION IS NOW LOUD AT EVERY WAY IT CAN DEGRADE. Each of the three silent
## shrinks below produced a deck SHORTER than the authored `deck_size` with no runtime complaint, and
## `deck_size` is read by nothing at runtime -- it is pinned only against the list's COPY SUM, never
## against the expanded result, so nothing downstream would have noticed:
##   * a MISALIGNED list -- `mini()` dropped the tail of the longer array;
##   * an id the LIBRARY does not hold -- `continue`d past;
##   * a ZERO or NEGATIVE `copies` entry -- `for _copy in <= 0` iterates zero times.
## The shipped list is guarded at authoring time by `test_card_authoring.gd`, but the
## `deck_list_override` seat bypasses that guard entirely, so the hole is reachable. The checks are
## seated HERE, where every list arrives. The skip and the `mini()` STAY beneath them: `Invariant.check`
## is `push_error` + `assert` and the assert is stripped in an exported build, so the loop must still be
## safe to run after a violated check -- and the totality check on the result is the backstop that
## cannot be walked past silently in a dev build.
##
## NO `max_copies` CHECK HERE, deliberately (operator ruling): `test/live_summon_deck.gd` ships twenty
## copies of a `max_copies = 3` card through the override seat ON PURPOSE. The copy cap is an AUTHORING
## rule, audited where authored decks live; this seam only requires a composition that is what the list
## says it is.
func _derive_deck_contents(deck_list: DeckList) -> Array[StringName]:
	var out: Array[StringName] = []
	Invariant.check(deck_list != null, "no deck list to expand -- the match would start with no deck")
	if deck_list == null:
		return out
	Invariant.check(deck_list.card_ids.size() == deck_list.copies.size(),
		"deck list arrays are index-aligned and must agree in length: %d ids vs %d copy counts"
				% [deck_list.card_ids.size(), deck_list.copies.size()])
	var expected := 0
	for index in mini(deck_list.card_ids.size(), deck_list.copies.size()):
		var id: StringName = deck_list.card_ids[index]
		var copies: int = deck_list.copies[index]
		Invariant.check(CardDatabase.has_card(id),
			"deck list names '%s', which the card library does not hold" % id)
		Invariant.check(copies > 0,
			"deck list entry '%s' asks for %d copies -- a deck entry contributes at least one" % [id, copies])
		# Counted BEFORE the skip, so the totality check below is a real backstop: a skipped id makes
		# the expansion short of the sum, and that is exactly what it is there to catch.
		expected += maxi(copies, 0)
		if not CardDatabase.has_card(id):
			continue
		for _copy in copies:
			out.append(id)
	Invariant.check(out.size() == expected,
		"the expanded composition is %d cards, not the %d the list's copy counts sum to"
				% [out.size(), expected])
	return out


## Story 3-5a (AC 4): the injected CAST-COST map, derived here for the same reason the deck
## composition is — the runner is the ONE place allowed to read CardDatabase (3-3 AC 2), and no
## file under src/state/ may so much as name it (3-3 AC 8). The state layer receives plain ids
## mapped to CardCastCondition resources and never learns where they came from.
##
## The WHOLE library is mapped, not just the ids the composition happens to use: the map is
## content, deriving it costs one pass, and a narrower map would have to be re-derived the moment
## deckbuilding (E4/E5+) lets a composition change. A card with no authored cast_condition is
## SKIPPED rather than mapped to null, which is what gives the seam's totality check something
## real to catch — a composition card missing its cost fails loudly at match start instead of
## refusing every cast with `unknown_card` at play time.
func _derive_card_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null or card.cast_condition == null:
			continue
		out[id] = card.cast_condition
	return out


## Story 4-1 (AC 2): the injected CARD-EFFECT map -- `_derive_card_costs()` directly above,
## followed VERBATIM, for the same reason it exists: the runner is the ONE place allowed to read
## CardDatabase (3-3 AC 2), and no file under src/state/ may so much as name it (3-3 AC 8). The
## state layer receives plain ids mapped to CardEffect resources and never learns where they came
## from.
##
## The WHOLE library is mapped, not just the ids the composition happens to use -- the sibling's
## own rationale, quoted because it is the reason and not a preference: "a narrower map would have
## to be re-derived the moment deckbuilding lets a composition change".
##
## A card with no authored `basic_effect` is SKIPPED rather than mapped to null, which is what
## gives inject_card_effects()'s totality check something real to catch: a composition card
## missing its effect fails LOUDLY at match start instead of silently landing every one of its
## casts on CardEffectResolver.REASON_NO_EFFECT_ENTRY at play time. All nine authored cards carry
## one today.
func _derive_card_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null or card.basic_effect == null:
			continue
		out[id] = card.basic_effect
	return out


## Story 5-2 (AC 4, `5-2/R1`): the injected CARD-COLOUR map -- `_derive_card_effects()` directly
## above, followed VERBATIM, and for the same reason it exists: the runner is the ONE place allowed
## to read CardDatabase (3-3 AC 2), and no file under src/state/ may so much as name it (3-3 AC 8).
## The state layer receives plain ids mapped to a plain enum and never learns where they came from,
## so `src/state/` still never reads a `CardData` (`card_data.gd:5`) even though it now knows what
## colour a card is.
##
## THE WHOLE LIBRARY IS MAPPED, not just the ids the composition happens to use -- the siblings'
## rationale unchanged: a narrower map would have to be re-derived the moment deckbuilding lets a
## composition change.
##
## NOTHING IS SKIPPED HERE, unlike `_derive_card_effects` one function up, and the difference is in
## the DATA rather than in the policy: `basic_effect` is a nullable Resource a card may legitimately
## not author, while `color` is a non-nullable enum with a value on every card by construction. So
## the map is total over the library automatically, and `inject_card_colors`'s totality check has
## nothing to catch short of a genuinely absent card.
func _derive_card_colors() -> Dictionary[StringName, Enums.CardColor]:
	var out: Dictionary[StringName, Enums.CardColor] = {}
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null:
			continue
		out[id] = card.color
	return out


## Story 6-5b (AC 23, operator ruling): the HAND-ROW PRICE MAP -- `_derive_card_colors()` followed
## verbatim, over BOTH cost resources instead of `CardData.color`, and for the same reason: the runner
## is the ONE place allowed to read `CardDatabase` (`src/ui/` never does, `6-0` AC 3).
##
## ONE ROW PER CARD: `[mode-1 mana, mode-1 orbs, mode-4 mana, mode-4 orbs, pitch speed]`, read straight off
## `cast_condition` and `pitch_condition` -- the two resources AC 23 names. Story 7-4 (AC 14, `7-4/R12`)
## appended the FIFTH element, the pitch side's `Enums.PitchSpeed` as an int (instant for a card with no pitch
## condition): the HUD's hourglass and hollow sorcery pips read it here, for the whole library -- so the
## opponent's zone card gets its marker from the same derive. A reader treats a missing fifth element as
## instant, so a four-element fixture row still renders. The orb halves are handed
## over AS AUTHORED (`Dictionary[Enums.CardColor, int]`); the HUD sorts them by colour ordinal before
## rendering, because this project's standing rule is that a `orb_costs` iteration order is never a
## contract (`card_cast_condition.gd`).
##
## A MISSING CONDITION CONTRIBUTES A ZERO PRICE, NOT A SKIPPED CARD, and the asymmetry with
## `_derive_pitch_costs` (which SKIPS a card with no authored pitch condition) is deliberate. That map
## feeds the STATE seam, where a missing entry is a meaningful refusal (`REASON_NO_PITCH_COST`); this
## one feeds a LABEL, where a card present in the hand with half its row missing would render half a
## price and read as a bug. A card with no pitch condition honestly costs nothing to stage.
##
## IT ENTERS NO CAPTURE CHANNEL AND NO SNAPSHOT (see the call site): static authored content, read
## once at load, rendered. `_derive_card_colors`' HUD-wrapper twin, not its injection twin.
func _derive_card_prices() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null:
			continue
		var cast_mana := card.cast_condition.mana_cost if card.cast_condition != null else 0.0
		var cast_orbs: Dictionary = card.cast_condition.orb_costs \
				if card.cast_condition != null else {}
		var pitch_mana := card.pitch_condition.mana_cost if card.pitch_condition != null else 0.0
		var pitch_orbs: Dictionary = card.pitch_condition.orb_costs \
				if card.pitch_condition != null else {}
		var pitch_speed := int(card.pitch_condition.pitch_speed) if card.pitch_condition != null \
				else int(Enums.PitchSpeed.INSTANT)
		out[id] = [cast_mana, cast_orbs, pitch_mana, pitch_orbs, pitch_speed]
	return out


## Story 7-6 (R2, D2, AC 11): the HUD's CARD -> EFFECT PAIRING -- `_derive_card_prices()` followed verbatim
## over `basic_effect` / `pitch_effect`, for its reason: the runner is the one place allowed to read
## `CardDatabase`. One row per card: `[normal effect id, pitch effect id]`, `&""` for an absent half. The HUD
## keys art by the EFFECT id, so a re-paired effect brings its art along. Static authored content, never
## injected and never recorded.
func _derive_card_effect_ids() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null:
			continue
		out[id] = [card.basic_effect.effect_id if card.basic_effect != null else &"",
				card.pitch_effect.effect_id if card.pitch_effect != null else &""]
	return out


## Story 6-2 (AC 1/AC 2): the injected PITCH-COST map -- `_derive_card_costs()` followed verbatim, over
## `CardData.pitch_condition` instead of `cast_condition`, for the same reason: the runner is the ONE
## place allowed to read CardDatabase. The WHOLE library is mapped; a card with no authored pitch
## condition is SKIPPED rather than mapped to null -- and unlike the Mode ① map, nothing downstream
## demands totality: that card simply refuses to stage (`MatchState.REASON_NO_PITCH_COST`).
func _derive_pitch_costs() -> Dictionary[StringName, CardCastCondition]:
	var out: Dictionary[StringName, CardCastCondition] = {}
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null or card.pitch_condition == null:
			continue
		out[id] = card.pitch_condition
	return out


## Story 6-5a (AC 6): the injected PITCH-EFFECT map -- `_derive_card_effects()` followed verbatim over
## `CardData.pitch_effect`, the WHOLE library walked by `CardDatabase.sorted_ids()`. A card with no pitch
## effect authored is SKIPPED, and nothing downstream demands totality (`_derive_pitch_costs`'s rule).
func _derive_pitch_effects() -> Dictionary[StringName, CardEffect]:
	var out: Dictionary[StringName, CardEffect] = {}
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null or card.pitch_effect == null:
			continue
		out[id] = card.pitch_effect
	return out


## Story 5-2 (AC 17, `5-2/R6`): THE UNTETHERED CHARGE-REACH FACT -- pushed EVERY TICK, for every
## slot whose hero is `CHARGING`, carrying an EXPLICIT inside/outside answer in the fact's KIND.
##
## IT IS NOT `_push_reach_probe` AND MUST NOT REUSE ITS CADENCE (`5-2/R6`, measured). That probe
## fires on `_probe_counter % minion_retarget_interval_ticks == 0` -- 1 tick in 12 at the authored
## 0.2 s -- and the state side tolerates the gap only through `is_in_reach_at`'s freshness window,
## which means "confirmed RECENTLY". A landing check resolves on ONE exact tick and has no such
## tolerance to spend, so this fact is produced on every ticking frame instead. The cost is bounded
## by construction: at most two rows per tick, and only while a chargeup is actually running.
##
## THE COMPARISON IS DONE HERE because the runner owns positions and `src/state/` owns none
## (`4-3/R2`); what crosses inward is the RELATION, exactly as the fact's `dir` has carried
## position-DERIVED data since 1-8. The reach is read INLINE off the config the runner already
## applied (CONSTRAINT C) -- never `BalanceConfigService`, never cached on this node, which during a
## replay would measure reach at the AUTHORED value instead of the RECORDED one.
##
## STORY 6-1c (AC 5, `6-1c/R3`): THE RADIUS IS PER COLOUR, AND IT IS STILL ONLY A KIND. The one
## `unblockable_reach` circle became `unblockable_reach_for(charge_color)` -- the charging player's
## own colour selects the swipe's, the thrust's or the jump's radius -- and what crosses inward is
## unchanged: the INSIDE/OUTSIDE kind and the planar direction, both from positions only. The
## per-colour ARC 6-1c judged in state retired with story 7-8 (`7-8/R8`), and this function still
## never reads `HeroState.facing` -- the 1-8/R-B3 split `_gather_contact_facts` states below.
##
## PUSHED THROUGH THE LAUNCH TOO: the hero stays `CHARGING` from the cast to the landing (the launch
## is a phase of it, not a state), so the fact the landing reads is measured on the landing tick
## itself, after the launch has carried the attacker.
##
## PLANAR (XZ) CENTRE-TO-CENTRE, the same geometry `_push_reach_probe` and `_lock_direction` use, so
## every distance this file measures is one geometry compared against different authored numbers
## rather than several geometries that could disagree.
##
## STORY 6-1d (AC 1/AC 3): CENTRE-TO-CENTRE NO LONGER DECIDES CONTACT -- it decides the AUTHORED
## BOUND and the AUTO-AIM DIRECTION, which is all it was ever honest about. Whether damage may be
## credited is now the blade-vs-body OVERLAP below. The direction fact is unchanged in every
## respect, still computed FROM POSITIONS ONLY and still never reading `HeroState.facing` (AC 3):
## the arc comparison stays state policy exactly as `6-1c` left it.
##
## A DEGENERATE CO-LOCATION PUSHES NOTHING (the `push_contact` zero-direction rule verbatim), and
## the LATCH is what makes that harmless rather than a lost hit: state keeps the previous tick's
## answer, and two heroes close enough to be co-located were inside reach on the tick before.
##
## HERO-TO-HERO ONLY (Ruling 8). Minions are neither targets nor obstacles for this attack, and that
## is structural here -- this function cannot address one.
func _push_charge_reach_facts() -> void:
	if _match_state.balance == null:
		return
	# Story 6-1d review fix (`6-1d/R9`): THE ROUND-OVER FREEZE PUSHES NOTHING. Step 1b returns before
	# step 2 for the whole freeze, so a committed hero keeps its contact window OPEN while the rig keeps
	# sweeping -- without this gate a frozen match would go on latching verdicts from geometry no one
	# played. Nothing is recorded either, so a replay sees the same silence. The snapshot read is
	# `_huds`' lock-marker precedent in `_physics_process`, and it is taken only while a chargeup runs.
	if _match_state.p1.hero.action_state != HeroState.ActionState.CHARGING \
			and _match_state.p2.hero.action_state != HeroState.ActionState.CHARGING:
		return
	if bool(_match_state.to_snapshot().get("round_over", false)):
		return
	for slot: int in 2:
		var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
		if player.hero.action_state != HeroState.ActionState.CHARGING:
			continue
		var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
		var enemy: HeroActor = _p2_hero if slot == 0 else _p1_hero
		if not is_instance_valid(hero) or not is_instance_valid(enemy):
			continue
		var to_attacker := hero.global_position - enemy.global_position
		var planar := Vector2(to_attacker.x, to_attacker.z)
		if planar.is_zero_approx():
			continue
		# STORY 6-1d (AC 1/AC 2/AC 4): THE KIND IS HONEST GEOMETRY NOW, not a centre-to-centre
		# radius. Three conjuncts, in the order that makes the cheap ones refuse first:
		#
		#   (i)  THE CONTACT WINDOW (AC 4) -- `PlayerState.is_contact_window_open()`, the SAME call
		#        `push_contact` makes on the other side of the seam, so the two layers cannot
		#        disagree about which ticks count. `HeroState.is_hitbox_active()` is deliberately
		#        NOT consulted and grows no CHARGING branch (`6-1d/R1`): it is melee's own phase
		#        gate, mode ② is not a swing, and the launch phase needs a gate of its own.
		#   (ii) THE AUTHORED PER-COLOUR REACH, kept as a PRE-FILTER (AC 2). It is an UPPER BOUND
		#        and nothing else: a configuration the blade can physically touch but which sits
		#        outside this colour's authored reach is NOT a hit. Pre- rather than post-filtering
		#        costs the overlap query nothing when the answer is already no, and it mirrors the
		#        gate order the landing itself reads.
		#   (iii)THE OVERLAP (AC 1) -- melee's own `get_overlapping_areas()` query, run against the
		#        defender's REAL `Hurtbox` shape. No authored blade curve, no body-radius constant:
		#        the geometry is the `Shape3D` the scene already carries (`6-1d/R1`, Fact 5).
		#
		# WHAT LEAVES THIS FUNCTION IS STILL A KIND (D3(b)/A2, the `1-8/R-B3` shape unchanged): the
		# runner measures, state decides. No distance, no angle and no world position crosses.
		var reach := _match_state.balance.unblockable_reach_for(player.charge_color)
		var kind := MatchState.CONTACT_CHARGE_REACH_INSIDE \
				if player.is_contact_window_open() and planar.length() <= reach \
						and _blade_overlaps_body(hero, enemy) \
				else MatchState.CONTACT_CHARGE_REACH_OUTSIDE
		var attacker_address: Array[int] = [slot, TargetingService.HERO_INDEX]
		var target_address: Array[int] = [1 - slot, TargetingService.HERO_INDEX]
		var fact_dir := planar.normalized()
		# The fact carries the charging hero's own swing counter. It keys nothing -- a charge-reach
		# fact never registers a dedupe hit -- but every field is filled honestly rather than with a
		# placeholder a later reader could mistake for something it is not, which is the rule
		# `_push_reach_probe` states for the same field.
		_recorder.capture_push_contact(attacker_address, target_address,
				player.hero.attack_index, fact_dir, kind)
		_match_state.push_contact(attacker_address, target_address,
				player.hero.attack_index, fact_dir, kind)


## Story 6-1d (AC 1): DOES THE TRACKED BLADE ACTUALLY TOUCH THAT HERO'S BODY?
##
## MELEE'S EXACT QUERY, SHARED RATHER THAN COPIED IN SPIRIT (`6-1d/R1`): the same `Area3D`
## (`HeroActor.hitbox`, whose child shape `_track_weapon_bone()` reparks on the paladin's
## `mixamorig_Sword_joint` every tick since 5-0a), the same `get_overlapping_areas()` call, and the
## same `get_parent()` identity resolution `_gather_contact_facts` uses. What it does NOT share is
## melee's phase gate -- see the caller.
##
## THE DEFENDER'S BODY IS ITS `Hurtbox`'s OWN `Shape3D`, read where it lives: this asks the physics
## server whether the two authored boxes overlap, so no inradius constant is derived and no
## body-radius field is authored. The hero's `Hurtbox` is the only `Area3D` on it that this hitbox's
## mask can see (the `Hitbox` itself is `monitorable = false`), so the identity test alone is the
## whole filter.
##
## ONE-TICK LAG, THE STANDING ONE: this runs in frame step 2, so the overlap reflects tick N-1's
## physics flush -- `_gather_contact_facts`' own contract, inherited unchanged rather than a new
## lag class.
func _blade_overlaps_body(attacker: HeroActor, defender: HeroActor) -> bool:
	for area: Area3D in attacker.hitbox.get_overlapping_areas():
		if area.get_parent() == defender:
			return true
	return false


## Story 6-1b (AC 1/AC 6/AC 7, finding 5): THE PRESENTATION-SIDE CHARGE PROGRESS PUSH -- a NEW
## call site on this function's own precedent (AC 7: a direct per-tick call, never a `connect_*`
## seam), but seated AFTER `advance()` rather than beside `_push_charge_reach_facts`'s
## before-advance seat, because progress needs the JUST-TICKED `remaining_ticks()` (CONSTRAINT C:
## read inline, never cached) and the FRESH post-advance() `action_state` -- both writes this same
## `advance()` call already made.
##
## READING `action_state` HERE (not the AnimationController's own `_state`, which only updates
## when the queued seam signal drains later this same frame) is what makes the chargeup-end
## ordering hazard (finding 4) impossible rather than merely guarded: `HeroState.set_action_state`
## flips the field SYNCHRONOUSLY, so on the very tick a chargeup ends -- landing, counter, knockdown
## or reset -- this poll already reads the new state and pushes nothing for that slot.
##
## `drive()` (HeroState only) is NOT widened to carry this: `charge_window` lives on PlayerState,
## and a new call site here costs nothing `_push_charge_reach_facts` one function up doesn't
## already pay for the reach fact.
##
## STORY 6-1c (AC 9/AC 11): THE LAUNCH PROGRESS CHANNEL EXTENDS THIS PUSH ACROSS THE LAUNCH. The hero
## stays `CHARGING` through the commit and the launch, so this same gate keeps pushing after the
## chargeup closes, and the progress now runs over the whole attack off the LANDING window
## (`AnimationController.charge_attack_progress`): the strike swing plays during the launch and
## progress 1.0 falls on the landing tick. The `6-1b/R6` guarantee carries over UNCHANGED because it
## is keyed to the SAME edge -- the landing exit writes `IDLE`/`STUNNED` synchronously on the
## tick the landing window closes, so this poll already reads a non-`CHARGING` state there and
## pushes nothing stale; the knockdown abandonment, the counter teardown and the reset stop the
## landing window in the same breath as they leave `CHARGING` (`6-9` retired the fourth, the
## release).
func _push_charge_progress() -> void:
	if _match_state.balance_ticks == null:
		return
	var chargeup_ticks := _match_state.balance_ticks.unblockable_chargeup_ticks
	for slot: int in 2:
		var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
		if player.hero.action_state != HeroState.ActionState.CHARGING:
			continue
		var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
		if not is_instance_valid(hero):
			continue
		var launch_ticks := _match_state.balance_ticks.unblockable_launch_ticks_for(
				player.charge_color)
		if chargeup_ticks + launch_ticks <= 0:
			continue
		var progress := AnimationController.charge_attack_progress(
				player.landing_window.remaining_ticks(), chargeup_ticks, launch_ticks)
		# Story 6-1d (AC 8): the SWING-AT-COMMIT knob, read INLINE off balance every tick
		# (CONSTRAINT C) and OFF by default. The branch is what makes AC 8's "OFF reproduces today's
		# behaviour exactly" structural rather than arithmetic: with the knob closed this line is
		# not reached and the value pushed is byte-for-byte the one `6-1c` pushed. The remap needs
		# the COMMIT FRACTION, which only this seat knows (the two spans), and the clip's `hold_end`,
		# which only the controller knows -- hence the composition here rather than inside either.
		if _match_state.balance != null and _match_state.balance.unblockable_swing_at_commit:
			progress = AnimationController.charge_commit_anchored_progress(progress,
					float(chargeup_ticks) / float(chargeup_ticks + launch_ticks),
					AnimationController.charge_hold_end_for(player.charge_color))
		hero.animation_controller.on_charge_progress(player.charge_color, progress)


## Story 7-10 (S1, AC 1-4; S4, AC 15): THE ATTACKER'S EYES AND THE IMMUNITY MARKER, polled per tick.
##
## THE EYES' GATE IS THE WHOLE OF AC 3, read off existing public facts: lit while the hero is CHARGING and nothing
## has touched yet (`charge_contact == CHARGE_CONTACT_NONE`, the hit-once memory), so the first touch -- counted
## or dropped -- a cancel, a knockdown, a bolt stun, a death and a debug reset all put them out by leaving
## `CHARGING` or by the touch; round end is the runner's own `round_over` suppression (step 4d). The FLASH is
## `charge_window.is_running` going false while lit -- the commit tick `_is_commit_tick` names, on which the 7-9
## counter window is anchored (AC 4). Progress is the chargeup's own (`1 - remaining / duration` of the
## `charge_window`), so the blink accelerando re-fits any `unblockable_chargeup_seconds` (AC 2).
##
## THE SHIMMER is `unblockable_immunity`'s remaining fraction, 0 when it is not running (AC 15) -- level-
## triggered, so expiry, death and reset end it with no falling edge to remember.
##
## THE SHAKES' CLOCKS advance here, once per ticking frame, and the offset is applied at step 4b.
func _push_unblockable_markers() -> void:
	for slot: int in 2:
		var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
		var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
		if is_instance_valid(hero):
			var lit := player.hero.action_state == HeroState.ActionState.CHARGING \
					and player.charge_contact == PlayerState.CHARGE_CONTACT_NONE
			var window := player.charge_window
			var progress := 1.0
			if window.duration_ticks() > 0:
				progress = 1.0 - float(window.remaining_ticks()) / float(window.duration_ticks())
			hero.eyes.drive(lit, player.charge_color, window.is_running, progress)
			var immunity := player.hero.unblockable_immunity
			var fraction := 0.0
			if immunity.is_running and immunity.duration_ticks() > 0:
				fraction = float(immunity.remaining_ticks()) / float(immunity.duration_ticks())
			hero.immunity_shimmer.set_fraction(fraction)
		if _shake_elapsed[slot] >= 0:
			_shake_elapsed[slot] += 1
			if _shake_elapsed[slot] >= _shake_total[slot]:
				_shake_elapsed[slot] = -1


## Story 7-10 (AC 10): the shake's offset for `slot`'s viewport camera this frame, in world space along the
## camera's own right and up -- POSITIONAL ONLY, applied to the SubViewport follower after it copies the rig
## camera, so the rig (whose LOCAL basis is the pushed movement basis) and the camera's rotation are untouched.
func _shake_world_offset(slot: int, camera: Camera3D) -> Vector3:
	if _shake_elapsed[slot] < 0:
		return Vector3.ZERO
	var o := UnblockablePresentation.shake_offset(_shake_elapsed[slot], _shake_total[slot])
	return camera.global_transform.basis.x * o.x + camera.global_transform.basis.y * o.y


## Story 6-6b (AC 10/AC 11/AC 14): THE COUNTER PRESENTATION POLL -- the same seat and shape as
## `_push_charge_progress` directly above: a POLL right after `advance()`, plain values only, no
## signal, no state handle held, no new `connect_*`, so the observation-seam family STAYS AT TEN.
##
## WHAT IT READS IS THE `defense` SNAPSHOT KEY AND NOTHING ELSE (AC 10). `[colour, remaining_ticks]`
## while a counter window runs, `[-1, 0]` at rest -- so a RISING edge of that key is the PRESS and a
## FALLING edge is the end of the busy span. That is the whole legibility channel for the press half:
## the answered colour rides the existing `deflect_landed` seam, and the attacker's fall rides
## `action_state_changed` plus the flavour read (AC 14). Nothing new was needed and nothing new was
## added.
##
## POST-REVIEW FIX PASS (finding P4, ruling R-P4): it reads THE KEY'S OWN THREE FACTS DIRECTLY --
## `defense_window.is_running`, `defense_color`, `remaining_ticks()` -- instead of building two whole
## player snapshots per tick to pull one entry out of them. That is `_push_charge_progress`'s precedent
## verbatim (it reads `charge_color` and `landing_window.remaining_ticks()` the same way), and it is
## the same fact: `player_state.gd`'s `defense` key IS those three fields, resting value included. The
## per-frame dictionary construction it replaces was a hot-loop allocation `project-context.md` forbids
## by name, and the `.get(..., default)` it replaces silently answered "no counter" forever if the key
## were ever renamed.
##
## THE EDGE IS TRACKED HERE, in a two-element runner-local latch, rather than inferred from the
## controller's own state: the controller is a pure consumer and must not have to remember whether it
## was told. `_counter_armed` is presentation bookkeeping -- it never reaches `to_snapshot()` and a
## replay reproduces it by reproducing the key.
##
## GREEN SPAWNS THE DAGGER (AC 11) at the throw clip's measured release offset into the span, flown
## from the DEFENDER to the ATTACKER over what is left of it. It is freed on arrival or on the
## falling edge, whichever comes first, so a counter torn down early leaves nothing behind.
func _push_counter_presentation() -> void:
	if _match_state.balance_ticks == null:
		return
	for slot: int in 2:
		var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
		var window: TimingWindow = player.defense_window
		var running := window.is_running
		var color := player.defense_color if running else PlayerState.NO_TELEGRAPH_COLOR
		var remaining := window.remaining_ticks() if running else 0
		var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
		# R-P2: a RE-CAST is a NEW PRESS even though `running` never went false -- detected as the
		# COLOUR changing or the remaining count RISING, which only a fresh `start()` can do (a window
		# otherwise counts down monotonically). The falling-then-rising order is preserved exactly:
		# the old presentation is ended and its dagger freed before the new one begins.
		var restarted := running and _counter_armed[slot] \
				and (color != _counter_color[slot] or remaining > _counter_remaining[slot])
		if _counter_armed[slot] and (not running or restarted):
			if is_instance_valid(hero):
				hero.animation_controller.on_counter_ended()
			_set_counter_pass_through(slot, false)
			_free_counter_dagger(slot)
			_end_counter_contact(slot)
			_counter_armed[slot] = false
		if running and not _counter_armed[slot]:
			var busy_seconds := float(
					_match_state.balance_ticks.counter_busy_ticks_for(color)) / TimingWindow.TICK_HZ
			if is_instance_valid(hero):
				hero.animation_controller.on_counter_started(color, busy_seconds)
			_set_counter_pass_through(slot, color == Enums.CardColor.RED)
			_begin_counter_contact(slot, color, window.duration_ticks())
			_spawn_counter_dagger(slot, color, busy_seconds)
		# Story 7-10 (AC 9-11, OQ1): RED's landing factor and arc ride every running tick, and the head contact
		# fires on its elapsed tick; the victim's held pose is released once its impact has played out.
		if running:
			_drive_counter_contact(slot, color, window.duration_ticks() - remaining)
		# R-P1/P3: and every running tick pushes HOW FAR INTO THE SPAN it is, which is what lets a
		# counter interrupted by a swing, a roll or the cast's own block drop rejoin its sequence at
		# the right frame instead of dying on the transition. `duration_ticks()` survives the window's
		# own stop, so the subtraction is the elapsed count on every tick the window runs.
		if running and is_instance_valid(hero):
			hero.animation_controller.on_counter_progress(
					float(window.duration_ticks() - remaining) / TimingWindow.TICK_HZ)
		_counter_armed[slot] = running
		_counter_color[slot] = color
		_counter_remaining[slot] = remaining
		_advance_counter_dagger(slot)


## Story 6-6b POST-SMOKE (R-S1): RED'S COUNTER PASSES THROUGH THE ATTACKER'S BODY, for the length of
## the span and no longer. Armed on the same rising edge that starts the presentation and cleared on
## the same falling edge that ends it -- including the falling edge a RE-CAST synthesises (R-P2), so
## a RED counter replaced mid-span by another colour gives its collision back with its clip.
##
## PRESENTATION, DELIBERATELY: the state layer writes RED's out-and-back velocity knowing nothing
## about bodies (`4-3/R2`), and this is what lets that velocity actually happen -- the jump arrives
## ON the attacker instead of stopping a metre short on its collision box. RED ONLY (R-S2 keeps
## BLUE's slide solid, which is how it stops on arrival), so every other colour pushes `false` and
## the call is a no-op for a hero that never had an exception.
func _set_counter_pass_through(slot: int, enabled: bool) -> void:
	var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
	var other: HeroActor = _p2_hero if slot == 0 else _p1_hero
	if not is_instance_valid(hero):
		return
	hero.set_body_pass_through(other, enabled)


## Story 6-6b (AC 11): the dagger's launch. GREEN only -- the other two colours throw nothing, which
## is a property of this gate rather than of an empty model.
##
## THE FLIGHT IS DEFENDER -> ATTACKER, read from the two hero ACTORS' own positions, which is where
## every other presentation-side position in this file comes from (`4-2/R14`: no position ever travels
## inward). Lifted to roughly chest height so it reads as thrown rather than slid along the floor.
func _spawn_counter_dagger(slot: int, color: int, busy_seconds: float) -> void:
	if color != Enums.CardColor.GREEN:
		return
	var thrower: HeroActor = _p1_hero if slot == 0 else _p2_hero
	var target: HeroActor = _p2_hero if slot == 0 else _p1_hero
	if not is_instance_valid(thrower) or not is_instance_valid(target):
		return
	_free_counter_dagger(slot)
	var dagger := DaggerActor.new()
	add_child(dagger)
	_counter_daggers[slot] = dagger
	var lift := Vector3(0.0, DAGGER_THROW_HEIGHT, 0.0)
	# Story 7-10 (AC 12): a FAST flight, capped at `DAGGER_FLIGHT_SECONDS` (or what is left of the span, if that
	# is shorter), aimed at the attacker's TRUNK bone rather than a fixed height off its root, so it visibly hits.
	var flight := minf(busy_seconds - AnimationController.counter_release_seconds(color, busy_seconds),
			UnblockablePresentation.DAGGER_FLIGHT_SECONDS)
	dagger.launch(thrower.global_position + lift, target.trunk_world(), flight)


func _advance_counter_dagger(slot: int) -> void:
	var dagger: DaggerActor = _counter_daggers[slot]
	if not is_instance_valid(dagger):
		return
	if dagger.advance(1.0 / TimingWindow.TICK_HZ):
		# Story 7-10 (AC 13/AC 14): GREEN's impact IS the dagger's arrival -- shown only on a victim whose
		# pose is being held, i.e. a counter that landed.
		_green_dagger_impact(slot, dagger.global_position)
		_free_counter_dagger(slot)


## Story 7-10 (S2/S3): THE COUNTER'S PRESS, for the contact moment. Resets this slot's bookkeeping and, for RED,
## derives the head-contact tick from the window's own duration -- and NOTHING ELSE. Review fix (T1, operator
## ruling): the press does not know whether the counter will land (a press too early, or the wrong colour, is
## judged and REFUSED on a later tick), so the arc, the body scale and the victim hold wait for the state's own
## landed fact (`_on_counter_deflect_landed`); a counter that never lands stays 6-6b's counter throughout.
func _begin_counter_contact(slot: int, color: int, duration_ticks: int) -> void:
	_counter_landed[slot] = false
	_counter_impacted[slot] = false
	_red_travel_scale[slot] = 1.0
	_red_back_scale[slot] = 1.0
	_red_lift_floor[slot] = -1.0
	_red_land_height[slot] = 0.0
	_red_contact_tick[slot] = -1
	if color != Enums.CardColor.RED or _match_state.balance == null:
		return
	_red_contact_tick[slot] = UnblockablePresentation.red_contact_elapsed_ticks(duration_ticks,
			_match_state.balance.counter_travel_forward_fraction_red)


## Story 7-10 review fix (T1/T2): THE COUNTER LANDED -- the state's own fact, `deflect_landed` carrying the answered
## colour (`MatchState._resolve_color_counter`; the melee/unit parry carries `NO_TELEGRAPH_COLOR` and is ignored).
## A consumer of the EXISTING seam, the `_on_effect_deflect_landed` precedent: no new `connect_*`.
##
## SAME-TICK ORDER: the landing queues `deflect_landed` BEFORE the attacker's `CHARGING -> STUNNED` write, and both
## drain in that order on the fire tick, so the victim hold armed here catches exactly this counter's knockdown --
## never a stun from another source (a bolt, a minion, a totem) during a failed counter's span (T2).
##
## RED'S BODY AND ARC are locked here, after the fire tick's own drive: the defender has already made `done` of
## the forward leg at 6-6b's full travel, so the factor for what is LEFT of the leg lands the body on the
## attacker (rooted from this tick, STUNNED), and the back leg returns the whole forward distance -- net zero.
func _on_counter_deflect_landed(attacker_slot: int, defender_slot: int, defense_color: int) -> void:
	if defense_color == PlayerState.NO_TELEGRAPH_COLOR:
		return
	if (attacker_slot != 0 and attacker_slot != 1) or defender_slot != 1 - attacker_slot:
		return
	var defender: PlayerState = _match_state.p1 if defender_slot == 0 else _match_state.p2
	var hero: HeroActor = _p1_hero if defender_slot == 0 else _p2_hero
	var other: HeroActor = _p1_hero if attacker_slot == 0 else _p2_hero
	if not defender.defense_window.is_running or not is_instance_valid(hero) or not is_instance_valid(other):
		return
	_counter_landed[defender_slot] = true
	other.animation_controller.arm_victim_hold()
	_victim_hold_ticks[attacker_slot] = 0
	if defense_color != Enums.CardColor.RED or _match_state.balance == null or _red_contact_tick[defender_slot] < 1:
		return
	var distance := _match_state.balance.counter_travel_distance_for(Enums.CardColor.RED)
	if distance <= 0.0:
		return
	var forward := _red_contact_tick[defender_slot]
	var elapsed := defender.defense_window.duration_ticks() - defender.defense_window.remaining_ticks()
	var done := distance * float(mini(elapsed, forward)) / float(forward)
	var left := distance - done
	var gap := Vector2(other.global_position.x - hero.global_position.x,
			other.global_position.z - hero.global_position.z).length()
	_red_travel_scale[defender_slot] = 1.0 if left <= 0.0 \
			else UnblockablePresentation.red_travel_scale(gap, left)
	_red_back_scale[defender_slot] = (done + left * _red_travel_scale[defender_slot]) / distance
	_red_land_height[defender_slot] = UnblockablePresentation.red_land_height(other.head_top_world().y,
			hero.global_position.y)


## Story 7-10: one running tick of a counter's contact moment. `elapsed` is the window's elapsed tick count.
## Review fix (T1): a counter the state has not (yet) landed gets none of it -- 6-6b's travel, no arc, no impact.
func _drive_counter_contact(slot: int, color: int, elapsed: int) -> void:
	var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
	var other: HeroActor = _p2_hero if slot == 0 else _p1_hero
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	if not is_instance_valid(hero) or not is_instance_valid(other):
		return
	if color == Enums.CardColor.RED:
		if not _counter_landed[slot]:
			hero.counter_travel_scale = 1.0
			hero.counter_lift = 0.0
		else:
			# The factor applies to the counter's own travel only: a hero the counter has lost the body to (a stun,
			# a swing) moves at its own velocity, unscaled. Forward vs back leg on the state's own boundary
			# (`elapsed <= forward_ticks` is outbound).
			var leg_scale := _red_travel_scale[slot] if elapsed <= _red_contact_tick[slot] else _red_back_scale[slot]
			hero.counter_travel_scale = leg_scale \
					if player.hero.action_state == HeroState.ActionState.IDLE else 1.0
			# The arc rises FROM THE GROUND at the landing: what is left of the jump's rise is re-spread over 0..1,
			# so a counter judged mid-jump does not pop the body up. From the head contact on, the plain fraction.
			var fraction := hero.animation_controller.counter_lift_fraction()
			if _red_lift_floor[slot] < 0.0:
				_red_lift_floor[slot] = fraction
			var floor_at := _red_lift_floor[slot]
			if elapsed < _red_contact_tick[slot] and floor_at < 0.999:
				fraction = clampf((fraction - floor_at) / (1.0 - floor_at), 0.0, 1.0)
			hero.counter_lift = _red_land_height[slot] * fraction
		if _counter_landed[slot] and elapsed == _red_contact_tick[slot] and not _counter_impacted[slot] \
				and other.animation_controller.is_holding_victim():
			_counter_impacted[slot] = true
			hero.begin_hitstop(UnblockablePresentation.RED_HITSTOP_SECONDS)
			other.begin_hitstop(UnblockablePresentation.RED_HITSTOP_SECONDS)
			UnblockablePresentation.spawn_impact(self, other.head_top_world(), _charge_color_of(color), true)
			UnblockablePresentation.play_sound(self, UnblockablePresentation.RED_THUD_SOUND,
					UnblockablePresentation.RED_THUD_VOLUME_DB)
			_start_shake(0)
			_start_shake(1)
	elif color == Enums.CardColor.GREEN and _counter_landed[slot] and not _counter_impacted[slot] \
			and not is_instance_valid(_counter_daggers[slot]):
		# Review fix: a press made up to the full lead before the commit lands AFTER the fast dagger has arrived;
		# its impact is then shown on the first tick the state has landed it, at the attacker's trunk.
		_green_dagger_impact(slot, other.trunk_world())
	_drive_victim_hold(slot)


## Story 7-10 (AC 11/AC 14): the victim of `slot`'s counter holds its pose from the fire tick until the impact has
## played out (its hitstop over), or until `VICTIM_HOLD_MAX_SECONDS`, whichever comes first -- then its knockdown
## cross-fades in. Never before the impact: the bound is at least the longest fire-to-impact gap.
func _drive_victim_hold(slot: int) -> void:
	var other: HeroActor = _p2_hero if slot == 0 else _p1_hero
	if not is_instance_valid(other) or not other.animation_controller.is_holding_victim():
		return
	var victim := 1 - slot
	_victim_hold_ticks[victim] += 1
	var impact_done := _counter_impacted[slot] and not other.is_in_hitstop()
	if impact_done or _victim_hold_ticks[victim] \
			>= UnblockablePresentation.ticks(UnblockablePresentation.VICTIM_HOLD_MAX_SECONDS):
		other.animation_controller.release_victim_hold(UnblockablePresentation.KNOCKDOWN_BLEND_SECONDS,
				float(_victim_hold_ticks[victim]) / TimingWindow.TICK_HZ)


## Story 7-10: the counter's span is over (or re-cast) -- the body's travel factor and arc go back to rest, and a
## victim hold still pending is released (its impact can no longer come) or disarmed (it never fired).
func _end_counter_contact(slot: int) -> void:
	var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
	var other: HeroActor = _p2_hero if slot == 0 else _p1_hero
	if is_instance_valid(hero):
		hero.counter_travel_scale = 1.0
		hero.counter_lift = 0.0
	if is_instance_valid(other):
		if other.animation_controller.is_holding_victim():
			other.animation_controller.release_victim_hold(UnblockablePresentation.KNOCKDOWN_BLEND_SECONDS,
					float(_victim_hold_ticks[1 - slot]) / TimingWindow.TICK_HZ)
		else:
			other.animation_controller.disarm_victim_hold()
	_counter_landed[slot] = false
	_red_travel_scale[slot] = 1.0
	_red_back_scale[slot] = 1.0
	_red_lift_floor[slot] = -1.0
	_red_land_height[slot] = 0.0
	_red_contact_tick[slot] = -1


## Story 7-10 (AC 13): GREEN's dagger hit -- sparks where it arrived, a hitstop on the attacker, a thud.
func _green_dagger_impact(slot: int, at: Vector3) -> void:
	var other: HeroActor = _p2_hero if slot == 0 else _p1_hero
	if _counter_impacted[slot] or not is_instance_valid(other) \
			or not other.animation_controller.is_holding_victim():
		return
	_counter_impacted[slot] = true
	other.begin_hitstop(UnblockablePresentation.GREEN_HITSTOP_SECONDS)
	UnblockablePresentation.spawn_impact(self, at, _charge_color_of(Enums.CardColor.GREEN), false)
	UnblockablePresentation.play_sound(self, UnblockablePresentation.GREEN_HIT_SOUND,
			UnblockablePresentation.GREEN_HIT_VOLUME_DB)


## Story 7-10: the authored charge colour for `color`, off the hero's telegraph profiles (no fourth vocabulary).
func _charge_color_of(color: int) -> Color:
	var cues: TelegraphController = _p1_hero.telegraph_controller
	match color:
		Enums.CardColor.RED:
			return cues.charge_red_profile.color
		Enums.CardColor.BLUE:
			return cues.charge_blue_profile.color
		Enums.CardColor.GREEN:
			return cues.charge_green_profile.color
	return Color.WHITE


## Story 7-10 (AC 10): start a camera shake on `slot`'s viewport camera.
func _start_shake(slot: int) -> void:
	_shake_total[slot] = UnblockablePresentation.ticks(UnblockablePresentation.SHAKE_SECONDS)
	_shake_elapsed[slot] = 0


func _free_counter_dagger(slot: int) -> void:
	var dagger: DaggerActor = _counter_daggers[slot]
	if is_instance_valid(dagger):
		dagger.queue_free()
	_counter_daggers[slot] = null


## Story 6-5c (AC 25/AC 26/AC 28): THE CAST PRESENTATION POLL -- the cast pose and its bolt on the
## CASTER, the warning marker and sound on the TARGET, and the root marker on whoever is rooted.
## `_push_counter_presentation`'s seat and shape verbatim: a plain read of the `cast` and `root`
## facts right after `advance()`, no signal, no state handle, no new `connect_*`, so the
## observation-seam family stays at TEN and `6-5c/R16` is satisfied without a new seam.
##
## IT READS, IT NEVER DECIDES (the HARD RULE). Every timing below is derived FROM the state layer's
## own window: the pose's sub-range, the tick the bolt launches and the tick it lands are all
## functions of `cast_window`'s tick count, so nothing here can move the strike and a `cast_seconds`
## retune retimes the whole show with no edit in this file (AC 25).
##
## THE EDGES, AND WHY THE FALLING ONE IS THE STRIKE TICK. `is_casting()` is true from the press until
## step 6c clears it, and step 6c is where the strike happens -- so the tick this poll first reads
## `false` IS the strike tick (or the interrupt tick, which clears the same field, `6-5c/R3`). The
## bolt is therefore given exactly `total - launch` ticks of flight and lands in the same push that
## sees the falling edge, which is what AC 25's headless pin asserts.
##
## AN ARRIVED BOLT IS FREED ONE TICK LATE, on purpose: freed in the push that lands it, the landing
## frame would never be drawn and the bolt would simply vanish a metre up. It is also what lets the
## AC 25 test observe the arrival at the instant `hit_landed` drains.
func _push_cast_presentation() -> void:
	for slot: int in 2:
		var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
		var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
		var other: HeroActor = _p2_hero if slot == 0 else _p1_hero
		var casting := player.is_casting()
		var landed: BoltActor = _bolts[slot]
		if is_instance_valid(landed) and landed.has_arrived():
			_free_bolt(slot)
		if _cast_armed[slot]:
			_cast_elapsed_ticks[slot] += 1
			# Story 7-1 (AC 23/AC 24): the spell clip's pose, from the window's own elapsed ticks -- on the strike
			# tick this is `cast_seconds`, which `AnimationController.spell_cast_pose` puts on the release frame.
			if is_instance_valid(hero):
				hero.animation_controller.on_cast_progress(
						float(_cast_elapsed_ticks[slot]) / TimingWindow.TICK_HZ)
			if _cast_shows_bolt[slot]:
				if _cast_elapsed_ticks[slot] == _cast_launch_ticks[slot]:
					_spawn_bolt(slot, hero)
				elif _cast_elapsed_ticks[slot] > _cast_launch_ticks[slot]:
					_advance_bolt(slot)
			# Story 6-5d (AC 28): the cone follows its marked unit every tick, so a walking minion takes
			# its mark with it -- `BoltActor`'s own live-target reasoning applied to a marker.
			_hover_target_cone(slot)
		if casting and not _cast_armed[slot]:
			# THE WHOLE COUNT IS READ ON THE RISING EDGE, where the window has not yet been ticked
			# once (step 2 runs before the step-6 press that started it), so `remaining_ticks()` is
			# the cast's full length -- the same reading `_push_counter_presentation` takes of its own
			# window on the tick it arms.
			var total := player.cast_window.remaining_ticks()
			var cast_seconds := float(total) / TimingWindow.TICK_HZ
			_cast_armed[slot] = true
			_cast_total_ticks[slot] = total
			_cast_elapsed_ticks[slot] = 0
			_cast_launch_ticks[slot] = clampi(int(round(
					AnimationController.cast_launch_seconds(cast_seconds) * TimingWindow.TICK_HZ)),
					0, total)
			# Story 6-5d (AC 28, `6-5d/R10`): THE CAPTURED TARGET IS READ HERE, on the rising edge, and
			# cached -- see `_cast_target_slots`. This is what replaces the slot arithmetic the whole of
			# this poll used to assume (`other` = the opposing hero, for both the warning and the prop).
			_cast_target_slots[slot] = player.cast_target_slot
			_cast_target_indices[slot] = player.cast_target_index
			# Smoke fix (6-5d): THE OUTCOME CLASSIFICATION IS THE RESOLVER'S (D6), read through the one
			# pure query -- see `_cast_shows_bolt`. Cached here, on the same rising edge as the target,
			# for the same reason: the cast's mode is gone from `PlayerState` once the strike clears it.
			# Story 7-1 (AC 23): the same one read now also chooses the CAST CLIP -- Fireball and Rocksling get
			# their own, Honed Bolt keeps `cast`.
			_cast_outcomes[slot] = _match_state.cast_outcome(player)
			_cast_shows_bolt[slot] = _cast_outcomes[slot] == CardEffectResolver.OUTCOME_HONED_BOLT
			if is_instance_valid(hero):
				hero.animation_controller.on_cast_started(cast_seconds, _cast_outcomes[slot])
			# Story 7-1 (AC 18): `bolt_charge` runs on the caster for the cast.
			if _cast_shows_bolt[slot] and _effects != null:
				_effects.start_bolt_charge(slot)
			# THE WARNING GOES ON THE CAPTURED TARGET, AND ON NOTHING ELSE (AC 28: "the marker never
			# appears on a non-target"). A HERO target gets today's marker and alarm, unchanged -- which
			# is every cast by an unlocked caster or one locked on the hero, i.e. the whole of the
			# pre-6-5d behaviour. A MINION OR TOTEM target gets the placeholder cone instead, and the
			# hero's marker is deliberately NOT armed: a cast aimed at a minion must not alarm the hero
			# behind it.
			if _cast_target_indices[slot] == TargetingService.HERO_INDEX:
				if is_instance_valid(other):
					other.telegraph_controller.on_cast_warning_started()
			else:
				_spawn_target_cone(slot)
			# A launch on the press tick itself (a tuning whose raise lands at offset 0) has no later
			# tick to be spawned on, so it is spawned here.
			if _cast_shows_bolt[slot] and _cast_launch_ticks[slot] == 0:
				_spawn_bolt(slot, hero)
		elif _cast_armed[slot] and not casting:
			_cast_armed[slot] = false
			_free_target_cone(slot)
			# Review N2's readable interrupt, hoisted so the clip and the lightning both read it (Story 7-1): a
			# struck spell cast plays its follow-through, an interrupted one does not.
			var interrupted := player.hero.action_state == HeroState.ActionState.STUNNED \
					or player.hero.action_state == HeroState.ActionState.DEAD \
					or not player.hero.is_alive()
			if is_instance_valid(hero):
				hero.animation_controller.on_cast_ended(not interrupted)
			if is_instance_valid(other):
				other.telegraph_controller.on_cast_warning_ended()
			if _effects != null:
				_effects.stop_bolt_charge(slot)
			# AN INTERRUPTED CAST TAKES ITS BOLT WITH IT (AC 5 / `6-5c/R3`: nothing applies). An
			# ARRIVED bolt is left alone -- that one is a strike, and it is freed next tick above.
			# Review N2: EXCEPT when the caster reads STUNNED or DEAD -- the readable half of
			# `_cast_is_interrupted`. An interrupt on the exact strike tick has already ticked the prop
			# to ARRIVED, but nothing struck, so it must not land visibly.
			var in_flight: BoltActor = _bolts[slot]
			# Story 7-1 (AC 18): THE STRIKE IS SEEN ON THE STRIKE TICK -- branching lightning and a flash where the
			# bolt landed, on this falling edge, only for a bolt that arrived and was not interrupted.
			if _effects != null and is_instance_valid(in_flight) and in_flight.has_arrived() and not interrupted:
				_effects.show_lightning(in_flight.global_position)
			if is_instance_valid(in_flight) and (interrupted or not in_flight.has_arrived()):
				_free_bolt(slot)
		if is_instance_valid(hero):
			hero.telegraph_controller.set_root_marker(_root_in_force(player))


## Story 6-5c (AC 28): IS A ROOT IN FORCE ON THIS PLAYER RIGHT NOW? `root_window` spans the stun AND
## the root as one window (`player_state.gd`), so "the root is in force" is that window running with
## the stun already over -- which the STUNNED state itself answers, because the bolt stun is the only
## thing that can be running inside the first part of that window.
##
## A CORPSE SHOWS NOTHING. A hero killed by the bolt (or by anything else while rooted) keeps a
## running window through the round-over freeze, and a ring under a falling corpse reads as a bug --
## the `set_lock_marker` round-over fix's own argument, applied to the second world-space marker.
func _root_in_force(player: PlayerState) -> bool:
	return player.root_window.is_running \
			and player.hero.action_state != HeroState.ActionState.STUNNED \
			and player.hero.action_state != HeroState.ActionState.DEAD


## Story 6-5c (AC 25): the bolt's launch -- from the caster's raised sword to the target, with exactly
## the ticks left between this tick and the strike. Read from the ACTORS' own positions, which is where
## every other presentation-side position in this file comes from (`4-2/R14`: no position ever travels
## inward).
##
## STORY 6-5d (AC 28, `6-5d/R10`): IT FLIES TO THE CAPTURED TARGET, MINION OR TOTEM INCLUDED. The `other`
## parameter is gone: the destination is resolved from the cached captured address through
## `_target_world_position`, the SAME helper the projectile actors already aim with, so the prop and a
## Fireball cannot disagree about where a cast is pointed. `6-5d/R10` accepts a placeholder look and not a
## wrong destination, which is why this is the one presentation change the story treats as load-bearing.
##
## NO TARGET POSITION MEANS NO PROP. A captured target whose actor is gone (a minion killed during the
## cast) resolves to null here, and a prop is simply not spawned -- which matches the state layer exactly:
## that bolt hits nothing (AC 26) and that Fireball flies straight past (AC 21/AC 22).
func _spawn_bolt(slot: int, hero: HeroActor) -> void:
	if not is_instance_valid(hero):
		return
	var target: Variant = _cast_target_position(slot)
	if not (target is Vector3):
		return
	_free_bolt(slot)
	var bolt := BoltActor.new()
	add_child(bolt)
	_bolts[slot] = bolt
	bolt.launch(hero.global_position + Vector3(0.0, BOLT_LAUNCH_HEIGHT, 0.0),
			target as Vector3, _cast_total_ticks[slot] - _cast_launch_ticks[slot])


func _advance_bolt(slot: int) -> void:
	var bolt: BoltActor = _bolts[slot]
	if not is_instance_valid(bolt):
		return
	var target: Variant = _cast_target_position(slot)
	if not (target is Vector3):
		return
	bolt.advance(target as Vector3)


## Story 6-5d (AC 28): where slot `slot`'s in-flight cast is pointed, or null when that body has no
## actor. The cached captured address resolved through the runner's ONE address-to-position helper.
func _cast_target_position(slot: int) -> Variant:
	return _target_world_position(_cast_target_slots[slot], _cast_target_indices[slot])


## Story 6-5d (AC 28): the placeholder cone for a cast aimed at a MINION OR TOTEM. See
## `TargetConeActor` for why a unit target gets a prop rather than the hero's telegraph marker.
func _spawn_target_cone(slot: int) -> void:
	_free_target_cone(slot)
	var cone := TargetConeActor.new()
	cone.visible = _debug_layer_visible  # Story 7-6 (P21): a spell target warning is a debug-layer cue
	add_child(cone)
	_target_cones[slot] = cone
	_hover_target_cone(slot)


func _hover_target_cone(slot: int) -> void:
	var cone: TargetConeActor = _target_cones[slot]
	if not is_instance_valid(cone):
		return
	var target: Variant = _cast_target_position(slot)
	if target is Vector3:
		cone.hover_over(target as Vector3)


func _free_target_cone(slot: int) -> void:
	var cone: TargetConeActor = _target_cones[slot]
	if is_instance_valid(cone):
		cone.queue_free()
	_target_cones[slot] = null


func _free_bolt(slot: int) -> void:
	var bolt: BoltActor = _bolts[slot]
	if is_instance_valid(bolt):
		bolt.queue_free()
	_bolts[slot] = null


## Story 7-1 (AC 7/AC 10/AC 14/AC 30, `7-1/R4`): A CARD RESOLVED -- hand its look to the presenter, and answer
## whether the effect's OWN sound silences the generic cast-success cue (the caller plays that cue otherwise).
##
## WHAT IT DID IS READ FROM THE STATE'S OWN RECORD, never from a card name: the caster's reversal packet was
## written by this very resolution inside `advance()` (`record_resolved_card` clears it at the press), so its KIND
## says what happened and its indices say to whom -- Culling's killed minions, Drain's sacrifice, Boom's count.
## Read at drain time, before anything else can rewrite it. The effect id only selects the knob row.
func _present_cast_resolved(slot: int, card_id: StringName, mode: int) -> bool:
	if _effects == null:
		return false
	var effect_id: StringName = _effect_id_by_card_mode.get("%s:%d" % [card_id, mode], &"")
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
	var opponent: HeroActor = _p2_hero if slot == 0 else _p1_hero
	# 7-1 polish (smoke bug 1): THE PACKET IS THIS RESOLUTION'S ONLY IF THIS RESOLUTION WROTE IT. A mode-2/mode-3
	# resolution skips `record_resolved_card`, so the packet still holds the last BASIC/PITCH card's -- reading it
	# replayed that card's look (Drain, Boom) on every unblockable initiation.
	var kind := player.reversal_kind if player.last_resolved_card_tick != _prev_resolved_tick[slot] \
			else PlayerState.REVERSAL_NONE
	match kind:
		PlayerState.REVERSAL_CULLING:
			var sources: Array[Vector3] = []
			var culled: Array[Node3D] = []
			for index: int in player.reversal_indices:
				var source: Variant = _target_world_position(slot, index)
				if source is Vector3:
					sources.append(source as Vector3)
					culled.append(_actor_at(slot, index))
			_effects.show_culling(sources, culled, hero)
		PlayerState.REVERSAL_DRAIN:
			if not player.reversal_indices.is_empty():
				var source: Variant = _target_world_position(slot, player.reversal_indices[0])
				if source is Vector3:
					_effects.show_drain(source as Vector3, hero)
			_drained_this_tick[slot] = true
		PlayerState.REVERSAL_BOOM:
			_effects.show_boom(opponent, player.reversal_indices.size())
		PlayerState.REVERSAL_VAMPIRIC_AURA:
			# 7-1 polish round: the buff gesture. Both buffs resolve instantly, so it plays only on a hero standing
			# still (`AnimationController.play_gesture`).
			if is_instance_valid(hero):
				hero.animation_controller.play_gesture(
						AnimationController.gesture_clip(CardEffectResolver.OUTCOME_VAMPIRIC_AURA))
		PlayerState.REVERSAL_FROSTBITE:
			if is_instance_valid(hero):
				hero.animation_controller.play_gesture(
						AnimationController.gesture_clip(CardEffectResolver.OUTCOME_FROSTBITE))
	_effects.play_resolution_sound(effect_id)
	return _effects.silences_generic_cue(effect_id)


## Story 7-1 (AC 19, `7-1/R3`): A REAL REVERSAL -- the blue rune circle on both heroes, and a blue flash on
## whatever it RETURNED, read from the runner's previous-tick copy of the countered player's packet (the live one
## is already cleared). Kills restored (Culling, Drain, a cast's killing damage, Corpse Bomb's conversions) flash
## the restored minion; refunded hero hp (Boom; a cast's damage on a hero) flashes that hero. A kind that returns
## nothing (a timed buff, a summon) shows the circles alone.
func _present_counterspell(caster_slot: int, countered_slot: int) -> void:
	_shot_vanish[countered_slot] = true
	if _effects == null:
		return
	var returned: Array = []
	var indices: Array = _prev_reversal_indices[countered_slot]
	var tags: Array = _prev_reversal_a[countered_slot]
	var slots: Array = _prev_reversal_b[countered_slot]
	match _prev_reversal_kind[countered_slot]:
		PlayerState.REVERSAL_CULLING, PlayerState.REVERSAL_DRAIN, PlayerState.REVERSAL_RAISE_DEAD:
			for index: Variant in indices:
				returned.append(_actor_at(countered_slot, int(index)))
				_restored_sources.append([countered_slot, int(index)])
		PlayerState.REVERSAL_BOOM:
			returned.append(_p1_hero if caster_slot == 0 else _p2_hero)
		PlayerState.REVERSAL_HONED_BOLT, PlayerState.REVERSAL_FIREBALL, PlayerState.REVERSAL_ROCKSLING, \
		PlayerState.REVERSAL_CORPSE_BOMB:
			for i: int in indices.size():
				if i >= tags.size() or i >= slots.size():
					break
				var tag := int(tags[i])
				if tag == PlayerState.PART_DAMAGE or tag == PlayerState.PART_CONVERTED:
					returned.append(_actor_at(int(slots[i]), int(indices[i])))
					if int(indices[i]) != TargetingService.HERO_INDEX:
						_restored_sources.append([int(slots[i]), int(indices[i])])
	# A KILLED minion's old actor is already gone (its corpse was consumed by the restore and freed before this
	# drain), so `_actor_at` answers null for it and the flash lands on its NEW record instead -- see
	# `_resolve_raised_spawns`, which reads `_restored_sources`.
	# 7-1 polish round: the caster swings `cast_counterspell` (lead-in cut so the peak lands
	# `COUNTERSPELL_LEAD_SECONDS` after this tick) and its rune circle bursts from the sword at that peak; a hero
	# not standing still plays no gesture, and its circle bursts from the ground at the same beat.
	var caster: HeroActor = _p1_hero if caster_slot == 0 else _p2_hero
	var countered: HeroActor = _p1_hero if countered_slot == 0 else _p2_hero
	var gesture := AnimationController.gesture_clip(CardEffectResolver.OUTCOME_COUNTERSPELL)
	var swung := is_instance_valid(caster) and caster.animation_controller.play_gesture(gesture)
	_effects.show_counterspell(caster, countered, returned, swung, AnimationController.gesture_beat_delay(gesture))


## The actor at `[slot, index]` (`index == HERO_INDEX` is that slot's hero), or null.
func _actor_at(slot: int, index: int) -> Node3D:
	if slot != 0 and slot != 1:
		return null
	if index == TargetingService.HERO_INDEX:
		return _p1_hero if slot == 0 else _p2_hero
	var actors: Array = _unit_actors[slot]
	if index < 0 or index >= actors.size() or not is_instance_valid(actors[index]):
		return null
	return actors[index] as Node3D


## Story 7-1 (AC 16, `7-1/R2`): the two seam consumers that count, per hero, what this tick's drain announced.
func _on_effect_hit_landed(_attacker_slot: int, target_slot: int, _damage: float, _target_hp: float) -> void:
	if target_slot == 0 or target_slot == 1:
		_shot_hits[target_slot] += 1


func _on_effect_deflect_landed(_attacker_slot: int, target_slot: int, _defense_color: int) -> void:
	if target_slot == 0 or target_slot == 1:
		_shot_deflects[target_slot] += 1


## Story 7-1 (AC 16, `7-1/R2`): GIVE EVERY HERO-SPELL SHOT THAT ENDED THIS TICK ITS ENDING LOOK, after the drain.
## The read is `7-1/R2`'s, in its own order: a deflect announced for the shot's hero target -> SCATTER; hp lost by
## that target -> IMPACT; a Counterspell against the shot's owner -> VANISH; the travel budget spent -> FIZZLE;
## anything else that ended it (a minion or totem target, which announces no hit) -> IMPACT. Several shots ending
## on one target in one tick are PAIRED BY COUNT; which shot gets which look is arbitrary, and a misread only a
## state fact could fix belongs to a later Tier A story (`7-1/R2`).
func _resolve_ended_shots() -> void:
	if _effects != null:
		for shot: Array in _ended_shots:
			var owner := int(shot[0])
			var target_slot := int(shot[3])
			var on_hero := int(shot[4]) == TargetingService.HERO_INDEX and (target_slot == 0 or target_slot == 1)
			var how := EffectPresenter.End.IMPACT
			if on_hero and _shot_deflects[target_slot] > 0:
				_shot_deflects[target_slot] -= 1
				how = EffectPresenter.End.SCATTER
			elif on_hero and _shot_hits[target_slot] > 0:
				_shot_hits[target_slot] -= 1
			elif _shot_vanish[owner]:
				how = EffectPresenter.End.VANISH
			elif bool(shot[5]):
				how = EffectPresenter.End.FIZZLE
			_effects.end_projectile(shot[2] as Vector3, StringName(shot[1]), how)
	_ended_shots.clear()
	for slot: int in 2:
		_shot_hits[slot] = 0
		_shot_deflects[slot] = 0
		_shot_vanish[slot] = false


## Story 7-1 (AC 16): did this shot end by spending its whole travel budget? `travelled_at` against the authored
## profile's `travel_budget` (`ProjectileBoard.advance_at`'s own expiry rule, read, never re-decided).
func _shot_expired(board: ProjectileBoard, index: int) -> bool:
	var profile := _match_state.projectile_profile_at(board, index)
	return profile != null and profile.travel_budget > 0.0 \
			and board.travelled_at(index) >= profile.travel_budget - 0.001


## Story 7-1 (AC 11/13/15/20/22/28/32): THE PER-HERO PERSISTENT LOOKS, LEVEL-TRIGGERED every frame from public
## reads -- the `_root_in_force` / `set_root_marker` shape. Every look is OFF on a corpse and through the whole
## round-over freeze (DEAD and the freeze are set together by `_end_round`), so nothing lingers past its state.
## Also the lifesteal heal: hp rising while Vampiric Aura runs, and not Drain's own heal, shows droplets.
func _push_effect_presentation() -> void:
	if _effects == null:
		return
	var freeze := _match_state.p1.hero.action_state == HeroState.ActionState.DEAD \
			or _match_state.p2.hero.action_state == HeroState.ActionState.DEAD
	for slot: int in 2:
		var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
		var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
		var on := not freeze and is_instance_valid(hero)
		var aura := on and player.is_rule_active(PlayerState.RULE_VAMPIRIC_AURA)
		_effects.update_hero(slot, hero, aura,
				on and player.is_rule_active(PlayerState.RULE_BLOODHOUND_ARMED),
				on and player.is_rule_active(PlayerState.RULE_ROLL_BOOST)
						and player.hero.action_state == HeroState.ActionState.ROLLING,
				on and player.is_rule_active(PlayerState.RULE_FROSTBITE_ARMED),
				on and player.is_rule_active(PlayerState.RULE_FROSTBITE_SLOW),
				player.hand.cover_count() if on else 0,
				on and _stun_flavor_for_slot(slot) == AnimationController.STUN_FLAVOR_BOLT,
				on and _root_in_force(player))
		var hp := player.hero.get_hp()
		if aura and hp > _prev_hp[slot] + 0.0001 and not _drained_this_tick[slot]:
			_effects.heal_droplets(hero)
		_prev_hp[slot] = hp
		_drained_this_tick[slot] = false


## Story 7-1 (AC 19, `7-1/R3`): refresh the previous-tick copy of each reversal packet, at the END of the frame --
## so during the NEXT frame's drain it still holds what the packet was before that tick's `advance()`.
func _copy_reversal_records() -> void:
	for slot: int in 2:
		var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
		_prev_resolved_tick[slot] = player.last_resolved_card_tick
		if player.reversal_kind == _prev_reversal_kind[slot] \
				and player.reversal_indices == _prev_reversal_indices[slot] \
				and player.reversal_a == _prev_reversal_a[slot] \
				and player.reversal_b == _prev_reversal_b[slot]:
			continue
		_prev_reversal_kind[slot] = player.reversal_kind
		(_prev_reversal_indices[slot] as Array).assign(player.reversal_indices)
		(_prev_reversal_a[slot] as Array).assign(player.reversal_a)
		(_prev_reversal_b[slot] as Array).assign(player.reversal_b)


## Story 7-1 (AC 6/AC 9): a minion actor just spawned -- a Vanguard summon emerges from a green crack at once. A
## record with a RAISE SOURCE is only NOTED (review fix F1): Raise Dead's minion and a Counterspell-restored one
## carry the same marker, and which it was is known only after the drain (`_resolve_raised_spawns`). Read from the
## record (`raised_from_at`, the `_raised_spot` read), and only for the melee scene: a totem (no `Hitbox`) is not a
## Deck 1 summon and gets neither.
func _present_unit_spawn(unit: UnitActor, player: PlayerState, slot: int, index: int) -> void:
	if _effects == null or unit.hitbox == null:
		return
	if player.units.raised_from_at(index) == UnitBoard.NO_RAISE_SOURCE:
		_effects.show_vanguard(unit.global_position)
	else:
		_raised_spawns.append([slot, index])


## Story 7-1 review fix (F1, AC 9/AC 19): GIVE EACH RAISED-FROM SPAWN OF THIS TICK ITS LOOK, after the drain. A
## spawn whose `[slot, raised_from]` is a minion this tick's Counterspell returned is a RESTORE: no pillar, and the
## blue "returned" flash on its NEW actor (a restore gets the flash only, no emerge look). Anything else is Raise
## Dead: the pillar. Both lists are emptied every frame.
func _resolve_raised_spawns() -> void:
	if _effects != null:
		for spawn: Array in _raised_spawns:
			var slot := int(spawn[0])
			var index := int(spawn[1])
			var actor := _actor_at(slot, index)
			if actor == null:
				continue
			var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
			if _restored_sources.has([slot, player.units.raised_from_at(index)]):
				_effects.flash_returned(actor)
			else:
				_effects.show_raise(actor.global_position)
	_raised_spawns.clear()
	_restored_sources.clear()


## Story 3-0c (X5): the record this runner has captured so far. READ-ONLY ACCESS to a
## runner-owned plain object — NOT an observation seam and deliberately not a `connect_`
## method (AC 13 pins that family at seven then; nine as of 5-4/R4): no signal, no callback, no
## state handle. A replay is
## started by assigning `replay_record` before this node enters the tree; persisting a record to
## `user://` and the operator control that starts and stops one are `3-0d`'s (`3-0c/R5`).
##
## In replay mode this stays EMPTY: a replay re-recording its own source would produce a copy of
## the record it is already reading, so the tap has nothing to add.
func recorded_stream() -> IntentRecorder:
	return _recorder


## Story 3-0d (AC 7): WRITE THE RECORD SO FAR TO `user://`. Returns the path written, or "" with
## a warning if the record was refused — a replay's tap is empty by construction, so "nothing to
## save" is a legitimate session state to report rather than an Invariant.check.
##
## RECORDING CONTINUES AFTERWARDS, and that is structural rather than promised: nothing here
## touches `_recorder`, which is never reassigned anywhere in this file. SAVE is a SNAPSHOT of an
## always-on stream (AC 6), and a second press writes a strictly longer record to its own path.
##
## `3-0d/R30`: THE PATH IS THE FIRST FREE ONE, NOT `_save_index + 1` NAMED BLIND. `_save_index`
## alone used to pick the path directly and started at 0 every session, so a new session's first
## SAVE collided with whatever a prior session had already written. `RecordFile.first_free_index`
## checks the filesystem before a byte is written, so SAVE can never overwrite an existing record.
func save_recorded_stream() -> String:
	var index := RecordFile.first_free_index(_save_index + 1)
	var path := RecordFile.path_for(index)
	var error := RecordFile.save_record(_recorder, path)
	if error != "":
		push_warning("record NOT saved: %s" % error)
		return ""
	_save_index = index
	print("record saved: %s (%d ticks)" % [path, _recorder.tick_count()])
	return path


## Story 3-0d (AC 2), DEBT B's BOTH-HALVES-TOGETHER RULE (decision-log:130-133): THE LIVE
## MID-MATCH BALANCE RELOAD. Re-reads the authored .tres — which only re-reads anything because
## of AC 1's CACHE_MODE_IGNORE, the cache half — and re-applies it to live state through the SAME
## apply_balance() seam the match-start injection uses, CAPTURED FIRST on the SAME reload channel
## `3-0c` shipped. No second injection path and no ninth capture channel (AC 3): this is reload
## event N on the existing `{"tick": int, "values": Dictionary}` stream, which has always
## supported N events (intent_recorder.gd:49-53).
##
## The capture is gated on `not replaying` exactly as the match-start call is, and on NOTHING
## ELSE — recording is ALWAYS-ON from tick 0 (AC 6), so there is no "is a recording active" state
## to branch on. In replay mode the whole trigger is refused: a replay applies the RECORDED
## reload events, and re-reading the on-disk .tres mid-replay is precisely the divergence
## `3-0c`'s AC 4 exists to prevent.
##
## OPERATOR SURFACE (`3-0d/R13`): the DebugInstrumentPanel's RELOAD control, wired below. The dev
## pass that first shipped this trigger flagged a contract conflict here — AC 7 pinned the panel
## at EXACTLY ONE new control (SAVE), while the Live Smoke asked the operator to trigger a live
## reload from the panel, which needs a second. The operator ruled (`3-0d/R13`): AC 7's "exactly
## one" was never protecting a COUNT, it was protecting against a LOAD control (`3-0d/R2`), and
## that protection is carried independently of button count. AC 7 was reformulated from a count
## into an exact SET, {SAVE, RELOAD}, and the panel gained its second control.
##
## CORRECTED (`3-0d/R20`): the sentence above used to say the protection is carried "by AC 11's
## `replay_record` source scan". THAT SCAN IS DELETED — it was evaded three times, and a text scan
## over source cannot carry a design invariant. What carries it now is that `replay_record` is
## CONSUMED ONCE into `_replay_record` (see the member's own comment) and nothing reads the public
## member again, so a load control would have nothing to flip.
func trigger_live_balance_reload() -> void:
	if _replay_record != null:
		push_warning("live balance reload refused: a replay applies the RECORDED reload events")
		return
	BalanceConfigService.reload()
	var config := BalanceConfigService.get_config()
	Invariant.check(config != null, "authored balance config missing at live reload")
	_recorder.capture_apply_balance(config)
	# Review fix MAJOR-1 (6-5d): the refusal reason is SURFACED here, not discarded -- the neighbouring
	# replay refusal three lines above already does this, and a refused reload with nothing read here
	# is observably silent to the operator (no log line, no HUD), which is the failure class M6 was
	# filed against. Guarded by a source scan, `test_trigger_live_balance_reload_reads_apply_balances_return_value`.
	var refusal := _match_state.apply_balance(config)
	if refusal != "":
		push_warning(refusal)


## Story 4-B1 (AC 2/AC 3, `4-B1/R1`): the DebugInstrumentPanel's READ ACCESSOR for both players'
## hand contents — a Callable the panel CALLS on demand (its own toggle handler), not a push seam
## and not a poll: no new `connect_*`, no per-tick call from `_physics_process`, and
## `test_runner_observation_seams_are_exactly_ten` is untouched by THIS seat (the family was at
## eight when this line shipped; 5-4 AC 15 moved it to nine via connect_orbs_changed).
## The same "hand the panel a way to ASK" shape as `save_recorded_stream` /
## `trigger_live_balance_reload` above, generalised from an action to a read.
##
## Read INLINE at call time (CONSTRAINT C) — both hands come straight off the live containers via
## their own `to_array()` copies, nothing is cached here or on the panel, and nothing here mutates
## state. Debug-only (`4-B1/R2`): its only PRODUCTION caller is the panel's CheckButton handler,
## reachable by a manual mouse press alone — no Input Map action, no FeatureFlags read, and it
## never fires in the shipped default configuration unless the operator toggles it. Story 6-3b's
## integration test (test_pitch_hud_live.gd) also calls it, to read which hand slots staging emptied.
func debug_hand_contents() -> Array:
	return [_match_state.p1.hand.to_array(), _match_state.p2.hand.to_array()]


## Story 1-6 (AC 2): map a configured slot kind to a concrete Controller — the ONE place a
## kind becomes an instance. Extended (never branched around) by 2-2/2-3 (gamepad / second
## keyboard) and E7 (scripted). NullController is the training-dummy driver.
func _make_controller(kind: ControllerKind, slot: int) -> Controller:
	match kind:
		ControllerKind.KEYBOARD_P1:
			return KeyboardController.new(&"p1")
		ControllerKind.KEYBOARD_P2:
			return KeyboardController.new(&"p2")
		ControllerKind.NULL:
			return NullController.new()
		ControllerKind.GAMEPAD:
			# Story 2-2 (2-2/R4): the i-th GAMEPAD slot binds the i-th connected joypad. The
			# ordinal is a PURE function of the config — the count of GAMEPAD slots BEFORE this one
			# (2-2 review D3), NOT the player slot and NOT a mutable counter — so re-wiring the
			# slots (2-3, DEBT B reload) can never bind the wrong device and there is no counter to
			# reset. The profile is the load-once authored mapping (data/gamepad_profile.tres),
			# the camera_config pattern.
			return GamepadController.new(
				_gamepad_ordinal_for_slot(slot), load("res://data/gamepad_profile.tres") as GamepadProfile)
	Invariant.check(false, "unknown controller kind: %d" % kind)
	return NullController.new()


## Story 2-2 (2-2/R4, review D3): the gamepad ordinal for a slot = how many GAMEPAD slots precede
## it in slot_controller_kinds. A PURE function of the config, so _make_controller stays
## idempotent and order-independent: the i-th GAMEPAD binds the i-th connected joypad exactly as
## R4 states, with no state to reset between wirings.
func _gamepad_ordinal_for_slot(slot: int) -> int:
	var ordinal := 0
	for i in slot:
		if slot_controller_kinds[i] == ControllerKind.GAMEPAD:
			ordinal += 1
	return ordinal


## Story 5-3 (AC 9): the ONE new read path CHARGING's colour needs. Not a `connect_*` seam
## (no signal, no subscriber) -- a plain synchronous read of the `telegraph` fact `5-2`
## publishes on `to_snapshot()`, taken only at the instant of a CHARGING transition (colour is
## fixed for the whole window, so a one-time read at entry suffices -- no per-tick poll).
## Re-derives `player` from `slot` on every call rather than accepting one as a parameter, the
## same anti-cycle shape this file already uses throughout (see the wiring loop above): a
## PlayerState handed to and captured by a caller's closure risks exactly the reference cycle
## the 4-B1 review fix removed.
func _charge_color_for_slot(slot: int, current: HeroState.ActionState) -> int:
	if current != HeroState.ActionState.CHARGING:
		return PlayerState.NO_TELEGRAPH_COLOR
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	var telegraph: Array = player.to_snapshot().get("telegraph", [PlayerState.NO_TELEGRAPH_COLOR, 0])
	return int(telegraph[0])


## Story 6-6a (AC 11): the STUNNED flavor for the rig controller -- `_charge_color_for_slot`'s shape, a
## plain synchronous read taken when the queued signal is CONSUMED. `STUN_FLAVOR_NONE` unless the hero is
## STUNNED; otherwise the running stun window's own duration through `BalanceTicks.is_knockdown_stun`,
## the SAME classifier the state layer's floor rule and get-up arming use (CONSTRAINT C: `balance_ticks`
## read inline, never cached). Read at consumption rather than carried on the signal because the AC 5
## escalation is a same-state write that emits nothing -- the next `hit_landed` is what re-reads it.
func _stun_flavor_for_slot(slot: int) -> int:
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	var ticks := _match_state.balance_ticks
	if player.hero.action_state != HeroState.ActionState.STUNNED or ticks == null:
		return AnimationController.STUN_FLAVOR_NONE
	if ticks.is_knockdown_stun(player.hero.stun.duration_ticks()):
		return AnimationController.STUN_FLAVOR_KNOCKDOWN
	# Story 6-5c (AC 27, `6-5c/R16`): THE BOLT FLAVOR, computed HERE from post-`advance()` state on
	# this function's own established shape -- a plain synchronous read at signal-consumption time,
	# NO new signal, NO new seam and NO new `MatchState` intake, which is exactly what R16 requires.
	#
	# BELOW the knockdown test, deliberately. The two are not mutually exclusive in principle, and
	# the KNOCKDOWN wins: `R-STUNSTACK`'s one-way escalation means a knockdown landing over a bolt
	# stun replaces it, and the pose must follow the stun the body is actually in. In practice the
	# bolt's own write can never be knockdown-length (the authoring audit pins `stun_seconds` below
	# `knockdown_stun_seconds`, AC 15), so this ordering is belt-and-braces rather than load-bearing
	# -- but getting it the other way round would make a retune that crossed that line silently play
	# `dizzy` over a knockdown.
	#
	# `stun_is_bolt` IS THE DISCRIMINATOR AND NOTHING ELSE WOULD DO: the deflect stun and the bolt
	# stun are both authored 0.4 s, so `is_knockdown_stun` classifies both ORDINARY and duration is
	# structurally incapable of telling them apart (`6-5c/R10`).
	if player.hero.stun_is_bolt:
		return AnimationController.STUN_FLAVOR_BOLT
	return AnimationController.STUN_FLAVOR_ORDINARY


## Story 6-6a (AC 10): the running stun window's snapshotted span in seconds, for the held pose's tempo.
func _stun_seconds_for_slot(slot: int) -> float:
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	return float(player.hero.stun.duration_ticks()) / TimingWindow.TICK_HZ


## Story 6-6a (AC 8/AC 9, Open Question 9): whether the state layer ARMED the get-up iframes ON THIS TICK
## -- the discriminator between the knockdown's TIMER exit (which starts the window in the same step-3 arm
## that writes IDLE) and the debug reset's identical `STUNNED -> IDLE` write (which stops it). Read at
## consumption. "This tick" is `running with nothing elapsed`: step 2 ticks every window before step 3
## can start one, so elapsed 0 on a running window happens only on its start tick. That is what keeps an
## ORDINARY stun's exit from playing `get_up` while an earlier get-up window is still running (a hero
## deflected mid-get-up-iframes, say). The window is at least one tick long whenever it was armed (the
## authoring audit pins `get_up_iframe_seconds > 0`).
func _get_up_armed_for_slot(slot: int) -> bool:
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	var window := player.hero.get_up_iframe
	return window.is_running and window.remaining_ticks() == window.duration_ticks()


## Read-only subscription seam (story 1-3b): consumers (HUD, integration tests) observe
## hero action transitions through the owning state object's typed signal — the D5 queued
## channel, drained by the runner after advance(). The runner wires the subscription so no
## consumer ever holds a MatchState handle. slot: 0 = P1, 1 = P2.
func connect_hero_action_state_changed(slot: int, callback: Callable) -> void:
	# Slot guard (story 1-3c — retires the decision-log first-consumer obligation).
	# Invariant.check, NOT a bare assert: a bare assert strips in export builds (X1).
	# Before this guard, any slot != 0 silently mapped to p2.
	Invariant.check(slot == 0 or slot == 1, "hero slot must be 0 or 1, got %d" % slot)
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	player.hero.action_state_changed.connect(callback)


## Read-only subscription seam (story 1-7, N1) for the MatchState-owned hit_landed —
## mirrors connect_hero_action_state_changed: the runner wires the subscription so no
## consumer ever holds a MatchState handle. Match-level (attacker AND target ride the
## payload), so there is no slot argument. Payload: (attacker_slot, target_slot, damage,
## target_hp — the target's remaining HP after the damage).
func connect_hit_landed(callback: Callable) -> void:
	_match_state.hit_landed.connect(callback)


## Read-only subscription seam (story 1-10, AC 3 — retires the 1-4 gate seam
## obligation): per-slot wrap of the HeroState-owned action_rejected, mirroring
## connect_hero_action_state_changed including the slot guard. Payload:
## (action, reason). slot: 0 = P1, 1 = P2.
func connect_hero_action_rejected(slot: int, callback: Callable) -> void:
	Invariant.check(slot == 0 or slot == 1, "hero slot must be 0 or 1, got %d" % slot)
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	player.hero.action_rejected.connect(callback)


## Read-only subscription seam (story 1-10, AC 3 — retires the 1-8 R-D4 seam
## obligation): match-level wrap of the MatchState-owned deflect_landed, mirroring
## connect_hit_landed (attacker AND target ride the payload, so no slot argument).
## Payload: (attacker_slot, target_slot).
func connect_deflect_landed(callback: Callable) -> void:
	_match_state.deflect_landed.connect(callback)


## Read-only subscription seam (story 6-3b, AC 1) — THE TENTH, and the THIRD amendment to the family
## `2-6/R7` froze at seven (`E6-P/R8`(2): the pitch HUD gets a new member of this family, never a second
## MatchState direct-connect). Match-level wrap of the MatchState-owned pitch_changed, mirroring
## connect_hit_landed exactly: the OWNER slot rides the payload, so there is no slot argument, and a
## consumer that needs "is this zone mine" binds its own slot at wiring. Payload: (slot, card_id,
## hand_slot, ready, remaining_ticks, duration_ticks, fresh_orbs) -- story 7-4 (AC 15) WIDENED the payload
## with a sorcery's sockets rather than adding a seam, so the family stays at ten.
##
## DOES NOT PRIME, the hit_landed family's rule: both zones are empty when consumers wire in _ready(),
## before the first advance(), so the empty render is the consumer's construction default.
func connect_pitch_changed(callback: Callable) -> void:
	_match_state.pitch_changed.connect(callback)


## Story 6-10 (AC 9): push "card mode ended" to both controllers. Base no-op except the pad's TOGGLE scheme.
func _force_card_mode_off_all() -> void:
	if _p1_controller != null:
		_p1_controller.force_card_mode_off()
	if _p2_controller != null:
		_p2_controller.force_card_mode_off()


## Story 1-7 (AC 4.3): MatchState.round_ended -> EventBus.round_ended. Runner-owned
## because src/state/ never touches an autoload.
func _relay_round_ended(loser_index: int) -> void:
	EventBus.round_ended.emit(loser_index)
	# Story 7-1 (AC 32): nothing transient lingers into the round-over freeze.
	if _effects != null:
		_effects.clear_transient()
	# Story 6-10 (AC 9b): the round ending drops card mode on both pads, on this EXISTING relay.
	_force_card_mode_off_all()


## Story 2-6 (AC 1, 2-6/R5): MatchState.round_started -> EventBus.round_started. Runner-owned
## for the same reason as _relay_round_ended: src/state/ never touches an autoload. No-argument
## — the reset is a whole-match event, not per-player.
func _relay_round_started() -> void:
	EventBus.round_started.emit()
	# Story 6-10 (AC 9c): the debug reset (the only thing that fires round_started) drops card mode too.
	_force_card_mode_off_all()
	# Story 4-1 (AC 8): the DEBUG RESET clears each player's UnitBoard (MatchState._reset_player,
	# the one named exception to that function's "NOTHING else" contract), and the grey-box actors
	# go with it. Wired onto THIS EXISTING RELAY deliberately -- no new EventBus event and no new
	# observation seam ship for it, which is what AC 8 asks for. `_end_round` is untouched, so the
	# board survives the round-over freeze and only a reset clears it.
	_free_unit_actors()
	# Story 7-1 (AC 32): the debug reset takes every effect look and sound with it, and the presentation
	# bookkeeping that would otherwise read the cleared match.
	if _effects != null:
		_effects.clear_all()
	_ended_shots.clear()
	_raised_spawns.clear()
	_restored_sources.clear()
	# Story 7-10: the unblockable presentation goes back to rest -- eyes, shimmer, hitstop, lift, travel factor,
	# victim hold and the shakes (the `_free_counter_dagger` discipline on every end path).
	for slot: int in 2:
		var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
		if is_instance_valid(hero):
			hero.clear_presentation()
			hero.animation_controller.disarm_victim_hold()
		_counter_landed[slot] = false
		_counter_impacted[slot] = false
		_victim_hold_ticks[slot] = 0
		_shake_elapsed[slot] = -1
	for slot: int in 2:
		_prev_reversal_kind[slot] = PlayerState.REVERSAL_NONE
		_prev_resolved_tick[slot] = PlayerState.NO_RESOLVED_TICK
		(_prev_reversal_indices[slot] as Array).clear()
		(_prev_reversal_a[slot] as Array).clear()
		(_prev_reversal_b[slot] as Array).clear()
	# Review fix pass (4-3b, F3a): the REACH-PROBE cadence counter is RUNNER-LOCAL (state has no
	# seat for it), so the debug reset -- a src/state/ event -- cannot clear it directly; this is
	# the one relay `round_started` fires only FROM a debug reset (`match_state.gd:1215`), so it is
	# the reset seat for runner-local state generally and the counter belongs with the actors above.
	# Without this, a reset leaves the cadence carrying an ARBITRARY PHASE from the previous run
	# rather than restarting it at tick zero. REPLAY IS UNAFFECTED: this counter only gates which
	# tick GATHERS a probe fact (`_gather_unit_facts`'s `probing` read); replay drains previously
	# TAPPED facts and never gathers, so the drifted phase is never consulted there and cannot
	# desync a replay from its recording.
	_probe_counter = 0


## Story 4-1 (AC 7): bring slot `slot`'s spawned actors up to `count`. See the call site for why
## this only ever grows.
##
## STORY 4-3e CHANGES WHERE, NOT WHETHER. The growth mechanism is untouched -- purely additive,
## never reusing a freed index, so `4-3a/R13`'s dead-unit HOLE convention is undisturbed. What
## changes is that the three inline row constants are gone and the batch's positions come from
## `_compute_spawn_positions` below.
##
## THIS FUNCTION BUILDS THE OCCUPANCY LIST; the helper never reads the scene tree (AC 9). Both
## heroes go in it (AC 3 -- summoning while standing ON the opponent is blessed, and that is exactly
## when "behind me" lands inside a body; heroes are `CharacterBody3D` on the same default layer 1
## as units, so an uncleared candidate is a real interpenetration), and so does every LIVE unit
## actor of BOTH slots. `null` holes are filtered out HERE, with the same `is_instance_valid()`
## guard every other loop in this file uses -- which is why the helper never has to remember to
## ignore one, and why the ORDER of the list is the only thing left that could vary between runs.
##
## Heroes are dereferenced unguarded, the same way step 5's `_p1_hero.drive(...)` does at the bottom
## of the same tick: they are `@onready` scene children of main.tscn, not optional. A guarded
## early-return here would be worse than the crash it dodges -- it would silently skip a spawn the
## board has already recorded, desynchronising `_unit_actors` from the board index-for-index.
func _spawn_missing_unit_actors(slot: int, count: int) -> void:
	var actors: Array = _unit_actors[slot]
	var batch_size := count - actors.size()
	if batch_size <= 0:
		return
	var occupied: Array[Vector3] = [_p1_hero.global_position, _p2_hero.global_position]
	for other_slot: int in 2:
		for unit: Node in _unit_actors[other_slot]:
			if is_instance_valid(unit):
				occupied.append((unit as Node3D).global_position)
	var hero_position: Vector3 = _p1_hero.global_position if slot == 0 else _p2_hero.global_position
	var opponent_position: Vector3 = _p2_hero.global_position if slot == 0 else _p1_hero.global_position
	# Story 4-4 (AC 3/AC 4): the SPAWN RULE IS UNCHANGED — AC 4 asks for exactly that, and 4-3e's own
	# AC 1 already scoped it to "minion or totem". What this story adds is WHICH SCENE the batch
	# instantiates, chosen from AUTHORED DATA rather than from a kind name: a kind whose attack
	# record authors a projectile, or which authors no attack at all, has no melee hitbox to author
	# and gets `TOTEM_SCENE`; a kind with a melee attack gets `UNIT_SCENE`. So AC 3's "no totem kind
	# authors a Hitbox" is an authoring consequence rather than a hardcoded list, and a future melee
	# totem or ranged minion needs no edit here.
	#
	# THE BATCH INDEX IS THE BOARD INDEX. `actors.size()` before each append is the record this
	# actor belongs to, which is what lets the scene be chosen per-record; the array stays
	# index-aligned with the board exactly as it has since 4-1.
	var spots := _compute_spawn_positions(occupied, hero_position, opponent_position, slot,
			batch_size)
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	for spot: Vector3 in spots:
		var index := actors.size()
		var unit := _unit_scene_for(player, index).instantiate() as UnitActor
		add_child(unit)
		# Story 6-5b (AC 14, `6-5b/R8`): A RAISED MINION LANDS ON ITS CORPSE, not on the hero-relative
		# rear-arc spot Ruin Vanguard's summons use. The record says WHICH corpse it came from (a board
		# INDEX -- `6-5b/R1` keeps position out of state entirely), and the position is read HERE, off
		# that corpse's own ACTOR, which is the only thing that has ever known where it lies.
		#
		# THE READ IS SAFE BECAUSE OF THIS FUNCTION'S SEAT, and that ordering is AC 14's last clause:
		# the spawn poll (3c) runs BEFORE `_free_dead_unit_actors` (3c-bis), so the corpse whose
		# position this reads is still in the tree on the very tick state consumed it. Reversing those
		# two call sites would place every raised minion at the fallback spot instead.
		#
		# IT FALLS BACK TO THE BATCH SPOT rather than to the origin when the corpse's actor is already
		# gone -- a hole from an earlier free, or a record raised in a fixture that never spawned
		# actors. A raised minion standing behind its summoner is wrong-but-playable; one standing at
		# world zero is a bug that looks like a feature.
		unit.global_position = _raised_spot(slot, player, index, spot)
		_apply_totem_tint(unit, player, index)
		_present_unit_spawn(unit, player, slot, index)
		actors.append(unit)


## Story 6-5b (AC 14): where the record at `index` actually stands -- the position of the corpse it was
## raised from, or `fallback` (its ordinary batch spot) for every record nobody raised.
##
## ITS OWN FUNCTION so the spawn loop reads as one line and the fallback ladder is stated once. Every
## rung answers the same question ("do I have a real position to copy") and the last one is honest
## about not having it.
func _raised_spot(slot: int, player: PlayerState, index: int, fallback: Vector3) -> Vector3:
	var source := player.units.raised_from_at(index)
	if source == UnitBoard.NO_RAISE_SOURCE:
		return fallback
	var actors: Array = _unit_actors[slot]
	if source < 0 or source >= actors.size():
		return fallback
	var corpse: Node = actors[source]
	if not is_instance_valid(corpse):
		return fallback
	return (corpse as Node3D).global_position


## Story 4-4 (AC 3): which actor scene the board record at `index` should be instantiated from,
## decided from AUTHORED DATA and never from a kind NAME.
##
## THE TEST IS "DOES THIS KIND SWING A MELEE ATTACK". A melee attack needs the `Hitbox` the runner's
## gather pass queries; a projectile attack does not (it fires an entity that carries its own), and
## a kind with no attack at all needs one even less. Both of the latter therefore get the scene with
## no `Hitbox`, which is AC 3's requirement stated as the property that actually decides it.
##
## AN UNRESOLVABLE KIND FALLS TO `UNIT_SCENE`, the fuller of the two: a record whose kind an X3
## reload has removed still exists on the board and still has to be visible and blockable, and the
## scene with more nodes degrades more gracefully than the one with fewer.
func _unit_scene_for(player: PlayerState, index: int) -> PackedScene:
	var balance := _match_state.balance
	if balance == null or not player.units.has_index(index):
		return UNIT_SCENE
	var kind := balance.kind_at(player.units.kind_index_at(index))
	if kind == null:
		return UNIT_SCENE
	var attack := kind.attack_at(0)
	if attack == null or attack.projectile != null:
		return TOTEM_SCENE
	return UNIT_SCENE


## Story 5-0c (AC 2/AC 3): per-kind totem tint, NAMED CONSTANTS in presentation code rather than a
## new `data/*.tres` resource — ruled in Dev Notes (review fix 2026-09-02) because AC 6's
## touched-files list does not include `data/`, and a small color table gains nothing a `.tres`
## profile would need until per-kind totem model VARIANTS become real (Non-Goals).
const _TOTEM_TINT_BY_KIND := {
	&"combat_totem": Color(0.85, 0.1, 0.1),
	&"mana_accelerator": Color(0.1, 0.35, 0.9),
	&"stamina_accelerator": Color(0.15, 0.75, 0.2),
}


## Story 5-0c (AC 2/AC 3): tints the already-spawned totem's model per kind. Reads the SAME kind
## name `_unit_scene_for` resolves from, at the SAME spawn call site — no new `src/state/` read
## (the kind index/name already flows through `UnitBoard.kind_index_at`, 4-4's own field).
## Presentation-only and degrade-gracefully by construction: any unresolved kind (a totem-shaped
## record whose kind index falls to `NO_KIND_INDEX`, or a MINION spawn, whose `_unit_scene_for`
## never gives it a `Mesh/Totem` child) leaves the model at its native teal rather than throwing,
## the same "never disappears or throws for lack of a tint" spirit `_unit_scene_for`'s own header
## states applies here too.
##
## THE TINT MEASURED THEN APPLIED (AC 3): the imported `totem.glb` material carries a SEPARATE
## emission texture (the rune glow mask) distinct from its albedo texture (the crystal body),
## measured by loading the imported scene and inspecting `BaseMaterial3D.get_texture()` per slot —
## so this tints ONLY the `emission` color on a per-instance DUPLICATE of the model's own material,
## leaving the albedo (crystal body) texture untouched: red/blue/green runes, crystal body
## unchanged, the AC's preferred reading rather than its single-texture fallback.
func _apply_totem_tint(unit: UnitActor, player: PlayerState, index: int) -> void:
	var balance := _match_state.balance
	if balance == null or not player.units.has_index(index):
		return
	var kind := balance.kind_at(player.units.kind_index_at(index))
	if kind == null or not _TOTEM_TINT_BY_KIND.has(kind.kind_name):
		return
	var mesh_root := unit.get_node_or_null("Mesh")
	if mesh_root == null:
		return
	_tint_mesh_recursive(mesh_root, _TOTEM_TINT_BY_KIND[kind.kind_name])


## Story 5-0c (AC 3): walks every `MeshInstance3D` under the totem model instance — the imported
## `totem.glb` mounts the obelisk body and its stand as two separate mesh instances sharing one
## material, measured after import — and gives each its OWN duplicated material so tinting one
## totem's model can never bleed into another's shared resource.
func _tint_mesh_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_instance := node as MeshInstance3D
		var base_material := mesh_instance.get_active_material(0)
		var tinted: StandardMaterial3D
		if base_material is StandardMaterial3D:
			tinted = (base_material as StandardMaterial3D).duplicate()
		else:
			tinted = StandardMaterial3D.new()
		tinted.emission_enabled = true
		tinted.emission = color
		mesh_instance.material_override = tinted
	for child in node.get_children():
		_tint_mesh_recursive(child, color)


## Story 4-3e (AC 1, 2, 4, 8, 9): the ORDERED LIST OF `batch_size` WORLD POSITIONS one growth batch
## of slot `slot`'s units lands on. ONE CALL PER BATCH, not one per member.
##
## A PURE FUNCTION OF ITS ARGUMENTS, and that is a REQUIREMENT rather than a happy accident (AC 9).
## It reads no scene tree, holds no node reference, spawns nothing and mutates no runner field. No
## RNG, no `Time`/`OS`/`Engine`, no frame counter, no scene-tree iteration order, and no dependence
## on the ORDER of `occupied` -- the clearance test below is a CONJUNCTION over the whole list, so
## order-independence holds by construction rather than by care.
##
##   WHAT NO GUARD HERE COVERS, said plainly: D3(b)/A2's machine scan for `randf`/`randi`/`Time`/
##   `OS`/`Engine` reads `src/state/` ONLY. This file is `src/main/` and is NOT scanned by it. A
##   `randf()` added below would trip NOTHING; `test_unit_spawn_purity.gd`'s repeat-call assertion
##   would catch it only probabilistically and would very likely miss a frame-counter read
##   entirely. The rest of AC 9's purity list is held by CODE REVIEW, not by a test.
##
## THE SEARCH. The base spot is `SPAWN_BEHIND_DISTANCE` behind the hero along the away-from-opponent
## axis. From there the walk visits RINGS: ring 0 is the base spot alone; ring k (k >= 1) holds
## `2 * arc_steps + 1` candidates at radius `k * SPAWN_RING_STEP`, swept outward from the axis in a
## fixed deterministic order (0, +1 step, -1 step, +2 steps, -2 steps, ...) out to +/- 90 degrees.
## The FIRST candidate clear of every occupant AND of every batch member already placed in this call
## wins, and the walk stops there.
##
## IT TERMINATES, and the argument is the reason there is NO candidate cap and NO fallback branch
## (writing either would be dead code): the radius strictly increases BETWEEN rings by a fixed
## positive step, without bound, while each ring holds finitely many candidates; the occupants are
## finitely many and each blocks only a bounded neighbourhood; so some ring at a finite radius is
## entirely free and the walk halts at or before it, having visited finitely many candidates. The
## rear-arc restriction does not affect this -- a rear arc far enough out is still eventually free.
## There is NO arena test and NO [-20, 20] check: nothing about the floor bounds placement.
##
## EVERY ACCEPTED CANDIDATE IS IN THE REAR HALF-SPACE (AC 1), which is what makes "behind" win over
## proximity: a candidate's displacement from the HERO is `-(SPAWN_BEHIND_DISTANCE + r*cos(angle))`
## along hero->opponent, and `cos(angle) >= 0` for every `|angle| <= 90` degrees, so that component
## is at most `-SPAWN_BEHIND_DISTANCE` and never positive. A crowded rear pushes the unit FURTHER
## BEHIND; a unit never appears between the summoning hero and its opponent.
##
## MEMBERS ARE PLACED ONE AT A TIME and each clears the ones already placed, so members 2..N cannot
## land inside a hero or a live unit. They still read as ONE CLUSTER rather than a scatter, because
## every member's search starts from the SAME base spot and takes the first free candidate -- the
## later members simply sit a ring or two further out. AT `d3854ff` `batch_size` IS ALWAYS 1 through
## play (one `units.add()` per resolved cast, one `card_commit` per player per tick, and two
## same-tick casts are different slots spawned through separate calls); the loop is written for N
## because multi-summon cards are planned, and correctness for N > 1 is carried by review.
func _compute_spawn_positions(occupied: Array[Vector3], hero_position: Vector3,
		opponent_position: Vector3, slot: int, batch_size: int) -> Array[Vector3]:
	var placed: Array[Vector3] = []
	if batch_size <= 0:
		return placed
	var away := _rear_direction(hero_position, opponent_position, slot)
	var lateral := Vector2(-away.y, away.x)
	var base := Vector2(hero_position.x, hero_position.z) + away * SPAWN_BEHIND_DISTANCE
	# roundi, not int/truncation: the ratio is integral for today's constants, but truncating a
	# float division would silently narrow the rear arc if a future retune landed just under an
	# integer (e.g. 2.999999999999998 truncating to 2 instead of rounding to 3).
	var arc_steps := roundi(SPAWN_ARC_HALF_WIDTH_RADIANS / SPAWN_ARC_STEP_RADIANS)
	for _member: int in batch_size:
		var ring := 0
		while true:
			var radius := SPAWN_RING_STEP * float(ring)
			var candidates := 1 if ring == 0 else 2 * arc_steps + 1
			var accepted := Vector2.ZERO
			var found := false
			for index: int in candidates:
				var candidate := _ring_candidate(base, away, lateral, radius, index)
				if _spot_is_clear(candidate, occupied, placed):
					accepted = candidate
					found = true
					break
			if found:
				# AC 8: the y is the GROUND CONSTANT, never the hero's. Only x/z are computed.
				# 5-0d fix pass (F1): clamp the accepted candidate back inside the arena ring --
				# the rear-arc search has no arena awareness (AC 6/Non-Goals, unchanged here), so a
				# hero standing near a wall can otherwise accept a candidate at or past it (see the
				# story's corrected AC 6 note). This is a floor on the OUTPUT, not a change to the
				# search itself.
				var contained_x := clampf(accepted.x, -SPAWN_CONTAINMENT_BOUND, SPAWN_CONTAINMENT_BOUND)
				var contained_z := clampf(accepted.y, -SPAWN_CONTAINMENT_BOUND, SPAWN_CONTAINMENT_BOUND)
				placed.append(Vector3(contained_x, SPAWN_GROUND_Y, contained_z))
				break
			ring += 1
	return placed


## The unit vector pointing AWAY from the opponent, in the planar x/z frame. The hero's `.y` and the
## opponent's `.y` are read for nothing.
##
## THE DEGENERATE CASE HAS A DEFINED ANSWER (AC 1, and it is a requirement rather than latitude):
## when the two heroes are effectively on top of one another -- the case AC 3 explicitly blesses --
## hero->opponent carries no reliable direction, so the axis becomes the SLOT'S FIXED
## AWAY-FROM-CENTRE axis: P1 places toward -x, P2 toward +x. This governs the whole rear ARC, not
## merely the base spot.
func _rear_direction(hero_position: Vector3, opponent_position: Vector3, slot: int) -> Vector2:
	var toward := Vector2(opponent_position.x - hero_position.x,
			opponent_position.z - hero_position.z)
	if toward.length() < SPAWN_DEGENERATE_DIRECTION_EPSILON:
		return Vector2(-1.0, 0.0) if slot == 0 else Vector2(1.0, 0.0)
	return -toward.normalized()


## Candidate `index` of the ring at `radius` around `base`, in the fixed order 0, +1, -1, +2, -2,
## ... steps off the away axis. Every index maps to `|angle| <= SPAWN_ARC_HALF_WIDTH_RADIANS`, which
## is what keeps the ring a REAR ARC (AC 1).
func _ring_candidate(base: Vector2, away: Vector2, lateral: Vector2,
		radius: float, index: int) -> Vector2:
	var angle := SPAWN_ARC_STEP_RADIANS * float((index + 1) / 2)
	if index % 2 == 0:
		angle = -angle
	return base + (away * cos(angle) + lateral * sin(angle)) * radius


## Is `spot` far enough from EVERY occupant and EVERY batch member already placed to not spawn
## overlapping one? A conjunction over both whole lists -- which is precisely why the answer cannot
## depend on the order of either (AC 9).
func _spot_is_clear(spot: Vector2, occupied: Array[Vector3], placed: Array[Vector3]) -> bool:
	for other: Vector3 in occupied:
		if Vector2(other.x, other.z).distance_to(spot) < SPAWN_CLEARANCE_RADIUS:
			return false
	for other: Vector3 in placed:
		if Vector2(other.x, other.z).distance_to(spot) < SPAWN_CLEARANCE_RADIUS:
			return false
	return true


## Story 4-3a (AC 11, `4-3a/R13`): FREE the actor of every unit whose record has died, and leave a
## HOLE in its place so the array index stays aligned with the board index.
##
## WITHOUT THIS THE KILLED MINION STAYS A VISIBLE, SOLID GREY BOX FOREVER, contradicting this
## story's own "removed from the board": the spawn loop only ever GROWS, and the only existing free
## path is the debug reset. Measured before it was written.
##
## A HOLE, NOT A REMOVAL, for the same reason the RECORD keeps its index (AC 7 / `4-3a/R2`):
## `erase()` here would shift every later actor down one and silently re-point
## `_target_world_position` and `_address_of` at the WRONG unit. `null` at a stable index is what
## keeps `actors[i]` and board index `i` the same number. Every consumer already tolerates it --
## `_aim_unit_actors`, `_approach_unit_actors` and `_target_world_position` all guard with
## `is_instance_valid()`, which is false for `null`, and `_address_of`'s `find()` never matches it.
##
## `queue_free()`, never `free()`, per project-context -- and this is NOT the pooling question
## (`4-5` owns that, gated on the 60fps-at-16-units criterion).
##
## POLLED, NOT SIGNALLED. This reads the board right after `advance()`, the same shape and seat as
## the spawn poll above and the aim/approach polls below: no signal, no state handle held, no new
## `connect_*` -- so the observation-seam family stays where it is and needs no amendment. That is
## also why `hit_landed` is not emitted for a unit (`4-3a/R12`): DEATH is the observable event, and
## this is where presentation observes it.
## STORY 4-3d (AC 2/3/4) CHANGES THE TIMING, NOT THE OUTCOME: the actor is no longer freed on the
## tick death is observed -- it LINGERS as a corpse for 10 s (600 ticks at the 60 Hz pin) and is
## freed at the end of that. Everything above still holds; the hole still appears at the same
## index, it just appears 600 ticks later.
##
## THE TIMER IS NOT HERE. `4-3d` (AC 3) ruled that it lived on the ACTOR
## (`UnitActor._linger_ticks`), because a runner-local parallel array keyed by index would survive
## the debug reset that clears `_unit_actors`.
##
## STORY 6-5b (AC 2/AC 25) SUPERSEDES THAT RULING: THE TIMER IS STATE'S. `6-5b/R1` makes the corpse a
## piece of GAME STATE -- Grave Ward extends its lifetime and Raise Dead consumes it, so a countdown
## living on a presentation node could not be reached by either, and two countdowns would be two
## answers to "is this corpse still here". `UnitActor.LINGER_TICKS` and `_linger_ticks` are DELETED,
## not kept alongside (the `attack_move_speed_multiplier` half-migration precedent).
##
## 4-3d's ORIGINAL OBJECTION IS ANSWERED RATHER THAN OVERRULED: the state-side countdown lives at the
## dead unit's own BOARD INDEX (`6-5b/R17`), and the debug reset clears the board and the corpses in
## the same `UnitBoard.clear()` call -- so there is no parallel structure to leak and no reset-relay
## wiring to remember. The thing 4-3d could not put on the board was a timer nobody owned; this one is
## owned by the record it belongs to.
##
## WHAT THIS FUNCTION DOES NOW IS READ AND REACT (AC 25), in three steps per dead index:
##   1. FIRST OBSERVATION of death: `begin_corpse_linger()` (idempotent) disables collision, deferred
##      out of this physics callback exactly as before.
##   2. EVERY tick including the first: hand the actor state's remaining lifetime and extended mark.
##      The actor counts NOTHING (AC 2) -- it reacts to the value it is handed, which is what drives
##      the Grave Ward tint (AC 24).
##   3. FREE ON THE TRANSITION out of corpse-hood, by EITHER route (AC 25): the lifetime reached zero,
##      or Raise Dead consumed the corpse this very tick. One test (`has_corpse_at`) covers both,
##      which is what makes "the actor is freed exactly when the corpse leaves state" one condition
##      rather than two that could disagree.
##
## THE ORDERING AGAINST RAISE DEAD IS LOAD-BEARING AND LIVES AT THE CALL SITE (AC 14): the spawn poll
## runs BEFORE this function, so a minion raised this tick reads its corpse's actor position while
## that actor is still in the tree, and only then is the corpse freed here.
##
## A KIND THAT LEAVES NO CORPSE IS FREED ON THE DEATH TICK, and that is a REPORTED behaviour change
## rather than an oversight: `6-5b/R10` gives totems no corpse, so `has_corpse_at` is false the instant
## a totem dies and step 3 fires immediately. Through 4-3d a dead totem lingered the full 10 s like a
## minion. Nothing in the story asks for a totem linger and nothing reads one; it is named here
## because it is the one visible consequence of R10 that no AC states.
##
## THIS SEAT IS STILL INSIDE THE RUNNER'S `ticking` GATE, and it still matters, for a different half of
## the same reason: the AGEING now happens inside `advance()` (which the pause does not call at all),
## and the FREEING happens here (which the pause does not reach). A corpse held under the debug pause
## neither ages nor disappears.
func _free_dead_unit_actors(slot: int, player: PlayerState) -> void:
	var actors: Array = _unit_actors[slot]
	for index: int in actors.size():
		if player.units.is_alive_at(index):
			continue
		var unit: Node = actors[index]
		if not is_instance_valid(unit):
			continue
		var corpse := unit as UnitActor
		if not corpse.is_lingering():
			corpse.begin_corpse_linger()
		# Story 6-5b (AC 2): the actor is handed state's remaining lifetime and mark, every tick.
		corpse.on_corpse_state(player.units.corpse_ticks_at(index), player.units.is_corpse_extended_at(index))
		# Story 7-1 (AC 8) SUPERSEDES 6-5b's AC 24 tint, which tinted a child named `Mesh` the shipped rigged
		# minion does not have -- so nothing showed (`6-5b` smoke). The GRAVE WARD LOOK (green glow on the body,
		# ghosts circling above) is LEVEL-TRIGGERED from the board's own mark every tick, so a Counterspell that
		# removes the extension removes the glow, and the corpse leaving state frees it with the actor below.
		if _effects != null:
			_effects.set_grave_ward(corpse, player.units.is_corpse_extended_at(index))
		if not player.units.has_corpse_at(index):
			corpse.queue_free()
			actors[index] = null


## Story 4-2 (`4-2/R13`): point slot `slot`'s spawned boxes at whatever their records say they
## acquired. Presentation only — see the call site.
##
## READ THROUGH THE SINGLE-INT ACCESSORS, never `target_at()`: this runs every physics frame for every
## spawned unit, and `target_at()` allocates a pair per call (the project-context Performance Rule on
## per-frame allocations in hot paths). A no-target slot means the unit has acquired nothing yet, and
## it is LEFT ALONE rather than reset to a default heading — "pointing where it last looked" is the
## honest reading, and on a fresh unit that is simply its spawn heading.
##
## An actor array can be SHORTER than the board for one frame (the board grows inside advance(), the
## spawn happens just above), so the loop is bounded by the ACTORS and the board index is checked
## against the board — neither side is assumed to have caught up with the other.
func _aim_unit_actors(slot: int, player: PlayerState) -> void:
	var actors: Array = _unit_actors[slot]
	for index: int in actors.size():
		if not player.units.has_index(index):
			continue
		var unit: Node = actors[index]
		if not is_instance_valid(unit):
			continue
		# Story 4-3c (AC 4): THE RIG PUSH, AND IT COMES FIRST -- the operator's ordering ruling
		# (`4-3c/R15`), and the one line order in this file that is a machine contract rather than
		# a style choice. It is UNCONDITIONAL for every actor index this loop reaches: it sits
		# above the liveness gate below, never inside it and never behind it.
		#
		# IT CANNOT BE HOISTED HIGHER, and that is not a weakening of the ruling. The two guards
		# above are structural -- `has_index` bounds the board read, `is_instance_valid` is what
		# makes `unit` a node at all -- and there is no controller to push to until the second one
		# has passed. AC 4's own wording is the exact one: "for every actor index the loop
		# REACHES". The TASK line's "unconditionally first in the loop body" read literally would
		# put this above the line that defines `unit`, which is unimplementable.
		#
		# WHY THE ORDER MATTERS, and why nothing in THIS story can see it break. A liveness check
		# placed ahead of this push would also skip the push for a dead unit, and the presentation
		# controller would never be told the unit died. In 4-3c that is invisible: a dead unit's
		# actor is freed by `_free_dead_unit_actors` earlier in the same frame, so this loop never
		# reaches a dead index. In 4-3d, where the corpse LINGERS, a controller that never received
		# the push would freeze on whatever clip it last held -- a corpse stuck in a half-raised
		# claw instead of playing `death`. The clip-selection test proves liveness-before-phase
		# INSIDE the controller and is structurally blind to this ordering; the source-order
		# assertion in test/integration/test_unit_clip_selection.gd is the only guard that sees it.
		#
		# The velocity read is the PREVIOUS tick's, not this one's: `_approach_unit_actors` (the
		# only writer of a unit actor's velocity) runs later in the same `_physics_process`. One
		# frame of staleness at 60 Hz cannot change which side of the walk/idle epsilon a unit
		# falls on for any meaningful span, and it is recorded rather than left to be rediscovered.
		#
		# STORY 4-4 (AC 3/AC 5): GUARDED, because a TOTEM SCENE CARRIES NO ANIMATION CONTROLLER. A
		# totem is a static structure authored at speed 0 (`4-4/R12`) with no walk clip to select,
		# no swing to play and no death animation, so `totem_actor.tscn` authors no rig and
		# `UnitActor.animation` reads null there. The ORDERING RULING (`4-3c/R15`) is untouched by
		# this guard: the push is still unconditionally first for every actor that HAS a controller,
		# and an actor with none has nothing that could be left frozen on a stale clip.
		var rig: UnitAnimationController = (unit as UnitActor).animation
		if rig != null:
			rig.on_unit_tick(player.units.is_alive_at(index),
					player.units.attack_phase_at(index), (unit as UnitActor).velocity.length())
		# Story 4-3c (AC 4, `4-3c/R4`): THE AIM LIVENESS GATE, which this seat had none of. Today
		# it is invisible for the reason above (the corpse's actor is already freed), but the seat
		# is wrong on its own: `attack_phase_at` below is FROZEN for a dead unit -- nothing resets
		# it to IDLE on death -- so without this a lingering corpse would be aimed from a stale
		# locked swing direction as though it were still mid-attack. It ships HERE rather than in
		# 4-3d because a seat 4-3d did not change should not become 4-3d's obligation to fix.
		#
		# IT GATES THE AIM DECISION ONLY, NEVER THE PUSH ABOVE. A dead unit is LEFT AT ITS
		# LAST-AIMED HEADING, which is `aim_along`/`aim_at`'s own established answer for a unit
		# with no usable direction -- "still pointing where it last looked" reads honestly, and a
		# corpse has no target to acquire.
		if not player.units.is_alive_at(index):
			continue
		# Story 5-0c (second corrective fix pass, operator-ruled on live smoke 2026-09-02): A
		# TOTEM NEVER ROTATES -- it is a static structure, and this holds for the combat totem
		# too, which still FIRES IN ALL DIRECTIONS (state-side, `ProjectileActor.heading` and its
		# targeting are entirely independent of this node's rotation -- see the projectile
		# doc-comments) but must not visually track. Detected by the SAME `Mesh/Totem` scene shape
		# `_apply_totem_tint` and its live test already key on, deliberately not `_unit_scene_for`'s
		# TOTEM_SCENE/UNIT_SCENE resolution (that reads authored kind data one spawn-tick earlier;
		# this is a rig-shape check, symmetrical with the animation-controller guard above). A
		# MINION never carries this child and is never skipped; an unresolvable kind degrades to
		# `UNIT_SCENE`, which also never carries it, so this never throws and never over-reaches.
		if unit.get_node_or_null("Mesh/Totem") != null:
			continue
		# Story 4-3b (AC 12): A UNIT THAT IS SWINGING IS AIMED FROM ITS LOCKED DIRECTION, not at its
		# live target. The direction locks at windup start and must NOT be recomputed -- that is the
		# whole point of the lock -- and the unit's Hitbox is a CHILD of the root this yaw turns, so
		# continuing to aim at the target through a windup would swing the hitbox after a target that
		# stepped aside. That is precisely the late-locking tracking `4-3b/R9` defers to per-kind
		# movesets; a swing that misses because the target moved is the intended summon-tier feel.
		#
		# THE STATE LAYER DECIDED IT, THIS READS THE ANSWER -- the same told-the-answer relationship
		# the acquired target pair below already has. A unit that has never had a fact against its
		# target carries a zero heading, and `aim_along` KEEPS the current rotation for it rather
		# than snapping to an arbitrary one (its own no-direction precedent).
		if player.units.attack_phase_at(index) != UnitBoard.AttackPhase.IDLE:
			(unit as UnitActor).aim_along(player.units.attack_dir_at(index))
			continue
		var target_slot := player.units.target_slot_at(index)
		if target_slot == TargetingService.NO_TARGET_SLOT:
			continue
		var target_index := player.units.target_index_at(index)
		var target_position: Variant = _target_world_position(target_slot, target_index)
		if target_position is Vector3:
			(unit as UnitActor).aim_at(target_position)


## Story 4-3 (AC 1/AC 3, `4-3/R8`): walk slot `slot`'s spawned boxes toward whatever their records
## say they acquired. THE RUNNER READS, THE ACTOR MOVES — see the call site in the drive phase for
## why it sits there and not in `_aim_unit_actors`.
##
## THE SAME LOOP SHAPE AS `_aim_unit_actors`, INCLUDING EVERY REASON IT HAS: read through the
## single-int accessors and never `target_at()` (which allocates a pair per call, per the
## project-context Performance Rule on per-frame allocations in hot paths); a no-target slot is LEFT
## ALONE rather than sent to a default heading; the actor array can be one frame SHORTER than the
## board, so the loop is bounded by the ACTORS and the index checked against the BOARD; and a null
## world position (an out-of-range index or a freed instance) means the box holds its position for
## that frame (`4-3/R15`).
##
## RECOMPUTED EVERY FRAME, NOT CACHED TO THE THROTTLE BOUNDARY (`4-3/R16`). The Performance Rule
## throttles target ACQUISITION scans, and this is not one — the pair is already decided, and this
## is a node lookup from a fixed pair. Caching it to the retarget boundary would lag by up to
## `minion_retarget_interval_ticks` (12 at the authored 0.2 s) and walk the unit toward where the
## hero used to be.
func _approach_unit_actors(slot: int, player: PlayerState, delta: float) -> void:
	# CONSTRAINT C: read at point of use, off the config the runner already applied — never a field
	# on this node, never a copy on the actor, never BalanceConfigService (`4-3/R11`).
	var balance := _match_state.balance
	if balance == null:
		return
	var actors: Array = _unit_actors[slot]
	for index: int in actors.size():
		if not player.units.has_index(index):
			continue
		# Story 4-3a (AC 7, `4-3a/R14`): THE APPROACH LIVENESS SEAT — the second of the two this
		# story names. This loop drove EVERY index unconditionally through 4-3; a dead unit's record
		# becomes "no longer walking" only because this line is here. It is NOT made redundant by the
		# corpse's actor being freed just after `advance()`: the seats are separate by ruling, the
		# predicate is the board's own (`is_alive_at`, never a re-derived `hp > 0` — the guard would
		# otherwise consult a copy), and a hole that outlived its free would otherwise be walked.
		if not player.units.is_alive_at(index):
			continue
		var unit: Node = actors[index]
		if not is_instance_valid(unit):
			continue
		var target_slot := player.units.target_slot_at(index)
		if target_slot == TargetingService.NO_TARGET_SLOT:
			# Story 4-3c (AC 4, `4-3c/R5`, path list corrected `4-3c/R12`, AMENDED `4-3c1/R3`):
			# THE FIRST OF EXACTLY TWO SKIP PATHS THAT MUST STOP THE ACTOR RATHER THAN JUST NOT
			# MOVING IT.
			#
			# THE LIST IS NO LONGER THE WHOLE STORY: there are now THREE places a unit's velocity
			# ends up zero, and only the two named here are SKIP paths. The third (`4-3c1/R3`) is
			# swing commitment -- decided at the `approach()` call site below, where the authored
			# phase multiplier (0.0 while WINDUP/ACTIVE/RECOVERY) is folded into the speed, and
			# WRITTEN inside `approach()` itself. It is a different shape from these two and must
			# NOT be folded into this list: it does not skip anything, it drives the unit normally
			# at a speed that happens to be zero, and unlike both paths here it DOES call
			# `move_and_slide()` (`unit_actor.gd:151`). A unit rooted mid-swing is being DRIVEN;
			# these two are being STOPPED.
			#
			# `4-3c/R12`'s OWN CITED COORDINATES NO LONGER RESOLVE: it cites `match_runner.gd:776-777`
			# and `:780` for the two writes, which are lines in a version of this file that has since
			# moved. The two writes it names are the two below in this function -- identified by what
			# they are, not by the ruling's line numbers, which are stale and recorded as such rather
			# than silently re-derived.
			#
			# `CharacterBody3D.velocity` is a PERSISTENT physics property -- it holds whatever it
			# was last set to across ticks, and Godot does not implicitly zero it between frames.
			# `approach()` is the only writer, so a unit that moved and then STOPPED acquiring a
			# resolvable target keeps its last nonzero velocity forever. Before 4-3c that was
			# merely untidy (nothing read it); now the rig controller reads exactly this value to
			# split `walk` from `idle`, so a stale value would play the walk clip on a
			# standing-still minion indefinitely.
			#
			# This is the same "holds still rather than drifting" contract `UnitActor.approach()`
			# already applies for its own within-`stop_distance` case, extended to the paths that
			# never reach `approach()` at all. It writes the ACTOR's own built-in physics property
			# -- no `src/state/` write, no snapshot field, and `move_and_slide()` is deliberately
			# NOT called: the unit is being stopped, not driven.
			#
			# THE OTHER THREE SKIPS IN THIS LOOP ARE NOT ON THIS LIST AND MUST NOT BE ADDED TO IT:
			# `balance == null` is an early RETURN for the whole slot before the per-actor loop
			# starts (there is no single actor to zero), and the `has_index`/`is_alive_at`
			# continues both run BEFORE `unit` is assigned (no node reference exists yet).
			(unit as UnitActor).velocity = Vector3.ZERO
			continue
		var target_index := player.units.target_index_at(index)
		var target_position: Variant = _target_world_position(target_slot, target_index)
		if target_position is Vector3:
			# Story 4-3c1 (AC 2, `4-3c/R19`, seat `4-3c1/R1`): SWING COMMITMENT — the unit's own
			# attack phase scales the speed it is driven at, so a unit that has committed to a swing
			# plants its feet for the whole of it (authored 0.0 = full root, mirroring the hero) and
			# runs at the ordinary `unit_move_speed` only while IDLE.
			#
			# THE THIRD VELOCITY-ZEROING PATH IS DECIDED ON THIS LINE (`4-3c1/R3`) and written inside
			# `approach()` — see the amended path list below. The multiplier is read INLINE here, off
			# the same config handle the rest of this loop reads (CONSTRAINT C): never cached to a
			# field on this node, never copied onto the actor. `match_state` only EXPOSES the rule --
			# a unit's velocity is actor-owned, so the scaling has to happen where the speed is
			# passed in, not inside the state layer that computed the factor.
			# Story 4-4 (AC 5/AC 6, `4-4/R12`): THE SPEED AND STOP DISTANCE ARE PER KIND NOW, read
			# through this unit's own kind index off the same replay-aware config handle
			# (CONSTRAINT C / `4-3/R11` unchanged). AC 5's "all three totem kinds are authored with
			# a movement speed of 0 and never leave their spawn position" is delivered HERE and by
			# authoring alone: a kind authoring `move_speed = 0.0` reaches `approach()` with a zero
			# speed, which zeroes the velocity and moves nothing. There is no is-a-totem branch
			# anywhere in this loop, which is what makes AC 5 a data fact rather than a code fact.
			var kind_index := player.units.kind_index_at(index)
			var kind := balance.kind_at(kind_index)
			if kind == null:
				# An X3 reload shortened `unit_kinds` under a live record. Stop rather than walk at
				# an invented speed — the same "holds still" answer both skip paths above give, and
				# for the same reason: `CharacterBody3D.velocity` is persistent, so a skipped write
				# would leave the unit gliding on its last speed forever.
				(unit as UnitActor).velocity = Vector3.ZERO
				continue
			var phase_multiplier := _match_state.unit_attack_phase_multiplier(
					player.units.attack_phase_at(index), kind_index)
			(unit as UnitActor).approach(target_position,
					kind.move_speed * phase_multiplier,
					kind.stop_distance, delta)
		else:
			# The SECOND of the two SKIP paths (`4-3c/R12`, amended `4-3c1/R3` -- the swing-commitment
			# zeroing above is a third zeroing but not a third member of THIS list, for the reason
			# recorded there), and the reason the list is a list rather
			# than "every `continue`": this one is not a `continue` at all. It is the implicit
			# fall-through when `_target_world_position` returns null -- an out-of-range index or a
			# freed instance -- where the `if` above simply does not match and the iteration ends.
			# It reaches `approach()` no more than the `NO_TARGET_SLOT` path above does and leaves
			# exactly the same stale velocity behind, so it takes the same fix. The unit holding
			# its position for that frame (`4-3/R15`) is unchanged; what changes is that it now
			# also holds its STILLNESS.
			(unit as UnitActor).velocity = Vector3.ZERO


## The `[slot, index]` pair resolved to a world position, and this is the ONLY place that translation
## happens. `index == -1` is that slot's HERO (AC 11's encoding); `>= 0` is that slot's unit actor at
## the same board index the state layer used, which is what makes the runner's array index and the
## state's identity the same number rather than two that could drift.
##
## Returns null when the addressed actor does not exist — a target acquired on a tick whose actor the
## runner has not spawned yet. The caller skips, so the box keeps its heading for that frame.
func _target_world_position(target_slot: int, target_index: int) -> Variant:
	if target_index == TargetingService.HERO_INDEX:
		var hero: HeroActor = _p1_hero if target_slot == 0 else _p2_hero
		return hero.global_position if is_instance_valid(hero) else null
	var actors: Array = _unit_actors[target_slot]
	if target_index < 0 or target_index >= actors.size():
		return null
	var unit: Node = actors[target_index]
	return (unit as Node3D).global_position if is_instance_valid(unit) else null


## Story 4-1 (AC 8): free every spawned unit actor, both slots. `queue_free()` (never `free()`) on
## nodes in the tree, per project-context; the arrays are cleared in the same pass so a second
## reset cannot reach a freed instance.
func _free_unit_actors() -> void:
	for slot: int in 2:
		var actors: Array = _unit_actors[slot]
		for unit: Node in actors:
			if is_instance_valid(unit):
				unit.queue_free()
		actors.clear()
		# Story 4-4 (AC 14): the PROJECTILE actors are freed in the SAME seat, and the pairing
		# mirrors the state side exactly — `MatchState._reset_player` clears `units` and
		# `projectiles` together, so the two arrays must be emptied together or the reset would
		# leave shots in the air belonging to records that no longer exist. One reset, one teardown.
		var shots: Array = _projectile_actors[slot]
		for shot: Node in shots:
			if is_instance_valid(shot):
				shot.queue_free()
		shots.clear()


## Story 3-5b (AC 6): MatchState.reshuffle_vulnerable_window_opened ->
## EventBus.reshuffle_vulnerable_window_opened. The two relays above, third time — runner-owned
## because src/state/ never touches an autoload, and a plain relay rather than a connect_ seam
## because the payload is a match-wide public fact carrying its own slot.
func _relay_reshuffle_vulnerable_window_opened(slot: int) -> void:
	EventBus.reshuffle_vulnerable_window_opened.emit(slot)


## Story 7-6 (D1, AC 23/AC 25/AC 26): MatchState.card_cast_resolved -> EventBus.card_effect_resolved. The three
## relays above, fourth time, and for their reason: state never touches an autoload, and a played effect is a
## PUBLIC match-wide fact (R6) both viewports' history strips read -- so it rides the ownerless bus rather than a
## per-slot seam read cross-slot. The relay is also the strip's ADMISSION RULE: only a NORMAL (mode 1) or PITCH
## (mode 4) resolution is relayed, and what crosses is the EFFECT that ran (the `_effect_id_by_card_mode`
## load-once map 7-1 already derives), never the card id or any hand content (AC 25). A pair the map does not
## carry relays nothing rather than a guessed effect.
##
## 7-6 review fix (operator ruling F1, 2026-10-05): A BOULDER CLEAR IS NOT RELAYED. It is not a played card
## (`6-5f/R7`: the state never writes it to the resolved-card record, so it is never Counterspell's target), and
## the test is the state's OWN classification -- `CardEffectResolver.BOULDER_OUTCOMES`, the table
## `clears_cover()` reads -- so the strip and the record can never disagree about what was played. With that, a
## counter striking the countered player's newest entry always strikes the card that was reversed.
func _relay_card_cast_resolved(slot: int, card_id: StringName, mode: int) -> void:
	if mode != Enums.ModeKind.BASIC and mode != Enums.ModeKind.PITCH:
		return
	var effect_id: StringName = _effect_id_by_card_mode.get("%s:%d" % [card_id, mode], &"")
	if effect_id == &"":
		return
	if CardEffectResolver.BOULDER_OUTCOMES.has(effect_id):
		return
	EventBus.card_effect_resolved.emit(slot, effect_id, mode == Enums.ModeKind.PITCH)


## Story 7-6 (D1, AC 23/AC 26): MatchState.counterspell_resolved -> EventBus.card_effect_countered, the fifth
## relay. Only the COUNTERED player crosses: the strip strikes that player's newest entry, and the caster's
## Counterspell arrives on its own through `_relay_card_cast_resolved`.
func _relay_counterspell_resolved(_caster_slot: int, countered_slot: int) -> void:
	EventBus.card_effect_countered.emit(countered_slot)


## Read-only subscription seam (story 2-4, AC 1/2 — 2-4/R1 amendment to the locked seam
## family, FOUR -> SEVEN): per-slot wrap of the HeroState-owned hp_changed, mirroring
## connect_hero_action_state_changed including the slot guard. Payload: (current, maximum).
## PRIMES ON CONNECT (2-4/R2): invokes the callback ONCE, immediately, with the current
## (hp, max_hp) before returning — so a consumer connecting in _ready renders a full bar
## without waiting for the first damage, and `maximum` is never withheld. slot: 0 = P1, 1 = P2.
func connect_hero_hp_changed(slot: int, callback: Callable) -> void:
	Invariant.check(slot == 0 or slot == 1, "hero slot must be 0 or 1, got %d" % slot)
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	player.hero.hp_changed.connect(callback)
	callback.call(player.hero.get_hp(), player.hero.get_max_hp())


## Read-only subscription seam (story 2-4, AC 1/2 — 2-4/R1): per-slot wrap of the
## StaminaPool-owned stamina_changed, same slot guard and (current, maximum) payload as
## connect_hero_hp_changed. PRIMES ON CONNECT (2-4/R2). slot: 0 = P1, 1 = P2.
func connect_stamina_changed(slot: int, callback: Callable) -> void:
	Invariant.check(slot == 0 or slot == 1, "hero slot must be 0 or 1, got %d" % slot)
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	player.stamina.stamina_changed.connect(callback)
	callback.call(player.stamina.get_current(), player.stamina.get_maximum())


## Read-only subscription seam (story 2-4, AC 1/2 — 2-4/R1): per-slot wrap of the
## ManaPool-owned mana_changed, same slot guard and (current, maximum) payload. PRIMES ON
## CONNECT (2-4/R2). The mana bar is LIVE from E1 (2-4/R13): mana starts at 0/max and moves
## on every CONFIRMED melee hit (blocked hits included, 1-8 ruling) via the step-5 melee-hit
## seat. slot: 0 = P1, 1 = P2.
func connect_mana_changed(slot: int, callback: Callable) -> void:
	Invariant.check(slot == 0 or slot == 1, "hero slot must be 0 or 1, got %d" % slot)
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	player.mana.mana_changed.connect(callback)
	callback.call(player.mana.get_current(), player.mana.get_maximum())


## Read-only subscription seam (story 3-6, AC 2) — THE EIGHTH, and the ONE amendment to the family
## `2-6/R7` froze at seven (`3-6/R2`, operator-approved). Per-slot wrap of the PlayerState-owned
## cards_changed, mirroring connect_hero_hp_changed exactly: same slot guard, same
## no-state-handle discipline, same PRIME ON CONNECT (2-4/R2). Payload: (hand ids in hand order,
## deck count, discard count).
##
## IT HAD TO BE A NEW SEAM RATHER THAN A REUSED ONE. The HUD cannot read the hand off the
## snapshot — contents and pile order are excluded from it by 3-3 AC 5 / 3-5a AC 6 and pinned
## excluded by 3-0c AC 11 — and none of the seven existing seams carries a card fact. The
## alternative shapes were both worse: a runner-side POLL of the containers after advance() (the
## 3-0b countdown shape) would make the HUD's card row a per-frame recompute, which AC 5 forbids;
## and the ownerless EventBus is for match-wide PUBLIC facts, which a player's own hand is not.
##
## PRIMING IS EMPTY AND THAT IS CORRECT: the deal happens at step 6 of the FIRST advance(), so a
## consumer connecting in _ready() primes with an empty hand and a zero deck, then receives the
## real payload one tick later. An empty row until the first tick is a visible truth about the
## match, not a bar that looks correct by construction (the 2-4/R2 rationale, unchanged).
##
## OWN SLOT ONLY (`3-6/R7`): deck and discard counts are PRIVATE. The consumer is bound to one
## slot's channel and the payload carries no slot index, so a HUD is structurally incapable of
## reading the opponent's counts — the same property that made deleting the opponent hand row the
## right call rather than repointing it. The one public card fact, the reshuffle window, rides the
## ownerless EventBus instead.
func connect_cards_changed(slot: int, callback: Callable) -> void:
	Invariant.check(slot == 0 or slot == 1, "hero slot must be 0 or 1, got %d" % slot)
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	player.cards_changed.connect(callback)
	callback.call(player.hand.to_array(), player.deck.size(), player.discard.size())


## Read-only subscription seam (story 5-4, AC 15) — THE NINTH, and the SECOND amendment to the
## family `2-6/R7` froze at seven (`3-6/R2` made it eight). A LINE-FOR-LINE clone of
## connect_mana_changed directly above: same slot guard, same pool-owned source signal, same
## no-state-handle discipline, same PRIME ON CONNECT (2-4/R2). Payload: this player's three orb
## counts (red, blue, green).
##
## A POOL-OWNED SOURCE SIGNAL IS THE NORM FOR THIS SHAPE, not a novelty — mana and stamina both work
## exactly this way, and `OrbPool.orbs_changed` already existed for it. What is NEW is only that
## something finally consumes it.
##
## THE ALTERNATIVE SHAPE IS EXPLICITLY REFUSED: no `MatchState.orb_granted` signal is built and no
## second direct presentation-to-MatchState connect is added. `E5-C/R2` and `E6-C/R2` resolved the
## direct-connect question: the exception is an enumerated list of exactly two members,
## `card_cast_resolved` and `counterspell_resolved` (`E6-C/R2`), and a third is allowed only if the
## same story adds it to both `game-architecture.md`'s list and the RAW allow-list in
## `test_architecture_invariants.gd`. This is a seam, counted as one.
##
## BOTH new consumers ride THIS channel: the HUD's own-slot orb counters (AC 18-20) and the
## TelegraphController earn cue (AC 17), which derives "a colour went up" by diffing successive
## payloads. That makes the priming call a REAL hazard rather than a theoretical one — a naive
## increase test fires on the priming (0,0,0) at match start — which is why the diff's first-call
## guard is pinned by its own integration test (AC 16).
##
## OWN SLOT ONLY (`2-4/R7` / `3-6/R7`): the consumer is bound to one slot's channel at construction
## and the payload carries no slot index, so a HUD is structurally incapable of reading the
## opponent's orb counts.
##
## THE ARCH DOC IS NOT EDITED BY THIS STORY. `docs/game-architecture.md:371-372` still reads "there
## are now eight"; that amendment is QUEUED for the E5 close-out flush, joining `5-3/R4`'s existing
## member, so several E5 amendments land together. The pinning TEST
## (test_architecture_invariants.gd) IS moved to nine in this story's own commit — it is
## load-bearing and must stay accurate. Nothing disappears quietly.
func connect_orbs_changed(slot: int, callback: Callable) -> void:
	Invariant.check(slot == 0 or slot == 1, "hero slot must be 0 or 1, got %d" % slot)
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	player.orbs.orbs_changed.connect(callback)
	callback.call(player.orbs.get_count(Enums.CardColor.RED),
			player.orbs.get_count(Enums.CardColor.BLUE),
			player.orbs.get_count(Enums.CardColor.GREEN))


## Story 1-7 (AC 2): step-2 contact-fact gathering for one attacker slot. Direct query
## (get_overlapping_areas), NEVER area_entered — signal firing order is not guaranteed
## and would make replay order-dependent. Queries ONLY while the state flags the hitbox
## active, stamps the attacker's attack_index AT GATHER time (never at resolution), and
## identity-filters self-overlaps (the overlapping area's owning actor != the attacker)
## BEFORE pushing — fact SELECTION, not rule evaluation, which keeps push_contact's
## strict attacker != target invariant intact (B5, operator decision; both heroes share
## hero.tscn, so the attacker's own hurtbox IS in the hitbox's mask every swing). Facts
## reflect tick N-1's physics flush (F1 one-tick lag — absorbed by the dedupe grace).
func _gather_contact_facts(attacker_slot: int, player: PlayerState, actor: HeroActor) -> void:
	var hero := player.hero
	if not hero.is_hitbox_active():
		return
	var attack_index := hero.attack_index
	for area: Area3D in actor.hitbox.get_overlapping_areas():
		var owner_actor := area.get_parent()
		if owner_actor == actor:
			continue  # self-overlap — filtered at gather, the invariant stays strict
		# Story 4-3a (AC 4): THE DROP THAT USED TO SIT HERE IS DELIBERATELY OPENED. Through 4-3 this
		# read `_slot_of(owner_actor)` and discarded every overlap whose slot was -1 -- which is
		# precisely what made a unit INVISIBLE to the contact pipeline. Identity resolution is now
		# EXTENDED (never replaced: `_slot_of` is untouched below, so heroes resolve exactly as they
		# did) to hand back a full `[slot, index]` TARGET ADDRESS, so a unit hurtbox resolves to a real
		# board index instead of being dropped.
		#
		# NO LAYER WAS AUTHORED FOR THIS (`4-3a/R11`, decided by Matko). The unit hurtbox sits on the
		# EXISTING layer 2 "hurtbox", which the hero Hitbox's mask already includes -- so it is visible
		# to this very query with NO edit to `hero.tscn` and NO edit to `project.godot`; both stay
		# byte-identical, and nothing other than the hero hitbox masks layer 2.
		var address := _address_of(owner_actor)
		var target_slot := address[0]
		if target_slot == -1:
			continue  # a hurtbox this runner cannot address -- neither hero nor a spawned unit
		# Story 4-3a (AC 6, `4-3a/R21b`): NO FRIENDLY FIRE. A hero's hitbox does not damage a unit
		# owned by that hero's OWN slot. This is the identity filter directly above extended from
		# "not myself" to "not my side", and it sits at GATHER time rather than as a state-side check
		# for a structural reason: `push_contact` asserts that attacker and target slots DIFFER, so a
		# same-slot fact reaching that seam would trip the invariant rather than resolve to nothing.
		# Fact SELECTION, not rule evaluation -- the same category as the self-overlap filter above.
		if target_slot == attacker_slot:
			continue
		# Story 1-8 (R-B3): the fourth fact field — world-space planar direction from the
		# TARGET to the ATTACKER, FROM POSITIONS ONLY. The runner reports the spatial
		# fact; it never reads HeroState.facing and never computes a relative angle —
		# the arc comparison is state policy (step 4). Degenerate co-location has no
		# direction — dropped at gather (fact SELECTION, like the identity filter above).
		var target_actor := owner_actor as Node3D
		var to_attacker := actor.global_position - target_actor.global_position
		var dir := Vector2(to_attacker.x, to_attacker.z)
		if dir.is_zero_approx():
			continue
		# Story 3-0c (AC 9): the fact is TAPPED here, at the one place it is produced, and pushed
		# unchanged. This whole function is what replay mode suppresses — regenerating facts
		# through physics on replay was REJECTED at 1-7's gate (D-4) because it would hang
		# replay soundness on Jolt bit-determinism.
		var fact_dir := dir.normalized()
		# Story 4-3b (AC 3): the ATTACKER is an ADDRESS now, and a hero's is `[slot, -1]` -- the
		# same `4-2/R2` convention the target has used since 4-3a, so this call resolves to the
		# identical PlayerState and the identical hashed outcomes the bare int produced. Stated
		# literally rather than derived through `_address_of`: a hero attacker is never anything
		# else here, and deriving it would be indirection with one possible answer. Kind is
		# CONTACT_STRIKE -- a hero's hitbox produces landed swings and nothing else; the REACH
		# PROBE is a unit-only fact (AC 13).
		var attacker_address: Array[int] = [attacker_slot, TargetingService.HERO_INDEX]
		_recorder.capture_push_contact(attacker_address, address, attack_index, fact_dir,
			MatchState.CONTACT_STRIKE)
		_match_state.push_contact(attacker_address, address, attack_index, fact_dir,
			MatchState.CONTACT_STRIKE)


## Story 4-3b (AC 2/AC 3/AC 5/AC 6): step-2 contact-fact gathering for one slot's UNITS -- the
## `_gather_contact_facts` sibling directly above, and deliberately its SHAPE rather than a branch
## inside it: the attacker loop, the active-window gate and the attack-index source all differ, and
## the two would share only the per-overlap body.
##
## THE SAME PIPELINE A HERO'S SWING USES, WHICH IS AC 2's WHOLE POINT. A unit's hitbox is a real
## `Area3D` queried with `get_overlapping_areas()` while state flags ITS OWN active window open, and
## the result enters through `push_contact`, the sole intake. There is deliberately NO abstract
## cadence that damages the acquired target without an overlap: an abstract resolution is an
## UNAVOIDABLE hit, which is the mob-feel finding `4-3` already made one layer up, repeating at the
## minion's own attack if this story took the shortcut. A unit whose window is open but whose hitbox
## touches nothing therefore deals nothing.
##
## THE ACTIVE-WINDOW GATE IS THE BOARD'S OWN PREDICATE, `is_hitbox_active_at` -- never a re-derived
## `phase == ACTIVE` inline, on the `is_alive_at` precedent (`4-3a/R14`): a guard consulting a copy
## is guarding the copy.
##
## THE LOOP SHAPE IS `_aim_unit_actors`' VERBATIM, including every reason it has: bounded by the
## ACTORS (the array can be one frame shorter than the board), the index checked against the BOARD,
## `is_instance_valid()` guarded, and the liveness seat consulted -- a corpse's actor now LINGERS
## for 10 s after `advance()` rather than being freed there (story 4-3d, AC 2/3), so this loop
## reaches corpses for up to 600 ticks; but a unit killed between gathers must not still be
## swinging. The lingering corpse is additionally collision-disabled (4-3d AC 4), so even the
## overlap query below has nothing to return for it.
##
## NO FRIENDLY FIRE, FILTERED AT GATHER TIME BY OWNER SLOT (AC 6, `4-3b/R3`/`R16`) -- never by
## collision layer, and never on the resolution ladder. The structural reason is `push_contact`'s
## own invariant: it asserts `attacker_slot != target_slot`, and under the headless runner
## `Invariant.check` does NOT halt the process on violation -- it push_errors, then `assert()`
## aborts only the current call (push_contact returns without effect) and the engine keeps
## running (measured: test/run_all.sh's own PASS/FAIL grep is what turns an INVARIANT VIOLATED
## line into a failed run, not an engine halt). So a same-slot fact must never reach that seam at
## all and a ladder-side check would be dead code behind a firing invariant, not a build halt.
## This is the identity filter of the hero pass extended from "not myself" to "not my side", and
## it covers BOTH the unit's own summoner and its own siblings.
##
## THE ATTACK INDEX IS THE UNIT'S OWN monotonic counter, stamped AT GATHER TIME exactly as the hero's
## is -- never the owner hero's, which is the `4-3b/R12` measurement made concrete.
##
## STRIKES AND PROBES ARE GATHERED IN ONE WALK OVER THE BOARD, and that is AC 5's canonical
## order rather than a tidiness choice. Two separate passes -- every unit's strikes, then every
## unit's probes -- produce a within-slot sequence like `strike(unit 1), probe(unit 0)`, which is
## a board-index INVERSION inside one tick. Measured at this dev pass: two such inversions
## appeared across a 489-tick live run and test_unit_attack_live.gd's gather-order pin caught
## them. One loop, one unit at a time, both fact kinds together, is what makes the order
## ascending by construction.
func _gather_unit_facts(attacker_slot: int, player: PlayerState) -> void:
	var balance := _match_state.balance
	var ticks := _match_state.balance_ticks
	if balance == null or ticks == null:
		return
	# The probe's THROTTLE, evaluated once per slot rather than per unit: it is a cadence over
	# ticks, not a per-unit budget, and re-deriving it inside the loop would read the same
	# answer N times.
	var probing := _probe_counter % ticks.minion_retarget_interval_ticks == 0
	var actors: Array = _unit_actors[attacker_slot]
	for index: int in actors.size():
		if not player.units.has_index(index):
			continue
		if not player.units.is_alive_at(index):
			continue
		var unit: Node = actors[index]
		if not is_instance_valid(unit):
			continue
		var attacker_address: Array[int] = [attacker_slot, index]
		var attack_index := player.units.attack_count_at(index)
		var unit_actor := unit as UnitActor
		# Story 4-4 (AC 6/AC 9/AC 10/AC 13): THE REACH IS PER KIND AND PER ATTACK RECORD — the
		# successor to the single flat `balance.minion_attack_reach_distance`. It is read here,
		# inside the per-unit loop, because it now VARIES per unit; the probe THROTTLE stays hoisted
		# above the loop because it does not (`minion_retarget_interval_seconds` stays shared, by
		# the operator ruling the story's Dev Notes record).
		#
		# THE SAME AUTHORED NUMBER SERVES A MELEE REACH AND A FIRING RANGE (AC 13's 8 m on the
		# shipped Combat totem), because both answer the same question of the ALREADY-ACQUIRED
		# target: may this attack begin? That is `4-4/R10`'s post-selection gate — nothing here
		# re-selects by distance and no NEAREST ordering mode is consulted.
		#
		# A KIND WITH NO ATTACK NEVER PROBES, so the two accelerator totems produce no facts at all
		# (AC 3: they never attack). That is an authoring fact, not a kind-name branch.
		var attack := _unit_attack_profile(balance, player, index)
		if probing and attack != null:
			_push_reach_probe(attacker_slot, player, index, unit_actor, attacker_address,
					attack_index, attack.range)
		if not player.units.is_hitbox_active_at(index):
			continue
		# Story 4-4 (AC 3/AC 14): THE MELEE PASS IS SKIPPED FOR A KIND THAT FIRES A PROJECTILE, and
		# this line is what "the Combat totem attacks only via its projectile" means at the gather
		# seat. Without it a Combat totem standing beside a hero would deal melee damage during its
		# active window — at its 8 m FIRING range the hitbox overlaps nothing, so the defect would be
		# invisible until someone walked up to a totem, which is exactly the kind of hole a live
		# smoke finds and a unit test does not.
		#
		# THE NULL GUARD IS THE SAME RULE FROM THE OTHER SIDE: `totem_actor.tscn` authors no
		# `Hitbox` (AC 3), so a totem's actor has none to query. Two expressions of one fact, and
		# they cannot disagree because the scene is CHOSEN from the same authored data this tests
		# (`_unit_scene_for`).
		#
		# REVIEW FIX (4-4, H1): `attack` ITSELF may be null here, and this line used to
		# dereference it. `_unit_attack_profile` answers null for the two authored misses its
		# own docstring names -- an X3 reload that shortened `unit_kinds` under a live record,
		# and a kind authoring an empty attack list -- and the probe read above is guarded for
		# exactly that, while this one was not. It is REACHABLE rather than theoretical:
		# `MatchState._advance_unit_attacks` `continue`s on the same miss, which FREEZES the
		# unit in whatever phase it holds, so a unit caught mid-ACTIVE keeps
		# `is_hitbox_active_at` true forever and this line then threw on Nil every physics
		# frame from then on. Ordered FIRST so the miss is answered before either of the two
		# facts below is asked for; a null attack skips the melee pass for the same reason a
		# projectile attack does -- there is no authored swing to gather for.
		if attack == null or attack.projectile != null or unit_actor.hitbox == null:
			continue
		for area: Area3D in unit_actor.hitbox.get_overlapping_areas():
			var owner_actor := area.get_parent()
			if owner_actor == unit_actor:
				continue  # self-overlap -- this unit's own hurtbox is inside its own hitbox's mask
			var address := _address_of(owner_actor)
			var target_slot := address[0]
			if target_slot == -1:
				continue  # a hurtbox this runner cannot address -- neither hero nor a spawned unit
			if target_slot == attacker_slot:
				continue  # AC 6: never the summoner, never a sibling
			var to_attacker := unit_actor.global_position - (owner_actor as Node3D).global_position
			var dir := Vector2(to_attacker.x, to_attacker.z)
			if dir.is_zero_approx():
				continue  # degenerate co-location has no direction -- dropped at gather
			var fact_dir := dir.normalized()
			_recorder.capture_push_contact(attacker_address, address, attack_index, fact_dir,
					MatchState.CONTACT_STRIKE)
			_match_state.push_contact(attacker_address, address, attack_index, fact_dir,
					MatchState.CONTACT_STRIKE)


## Story 4-4 (AC 14): bring slot `slot`'s spawned projectile actors up to its board's record count —
## `_spawn_missing_unit_actors`'s shape, and the same poll-right-after-`advance()` seat.
##
## THE LAUNCH POSITION IS THE FIRING UNIT'S, which is the one thing a fresh shot needs that its own
## record cannot carry: position is actor-owned (`4-3/R2`), so the record stores the SOURCE BOARD
## INDEX and this is where that is spent. A source whose actor is already gone — killed and freed in
## the same frame it fired — falls back to the OWNER HERO's position rather than the world origin:
## the shot is a real thing that must appear somewhere plausible, and origin would fling it across
## the arena from a corner.
##
## THE LAUNCH HEADING IS AIMED AT THE TARGET, at no turn-rate limit (see
## `ProjectileActor.launch_toward`): a turn rate describes how a shot changes course, and a shot that
## has not yet flown has no course to change. A shot with no resolvable target keeps the scene's
## default heading and flies straight until its budget expires — the honest behaviour, and
## unreachable in shipped play, where the windup that produced it could only begin because a reach
## probe reported the acquired target in range.
##
## IDENTICAL LIVE AND REPLAY BY CONSTRUCTION, the `_spawn_missing_unit_actors` property verbatim:
## this reads the BOARD, not the cast and not the attack — whatever put the record there reaches this
## line the same way, so there is no second spawn path to keep in agreement with the first.
func _spawn_missing_projectile_actors(slot: int, player: PlayerState) -> void:
	var actors: Array = _projectile_actors[slot]
	var board := player.projectiles
	while actors.size() < board.size():
		var index := actors.size()
		var shot := PROJECTILE_SCENE.instantiate() as ProjectileActor
		add_child(shot)
		shot.global_position = _projectile_launch_position(slot, board.source_index_at(index))
		var target_position: Variant = _target_world_position(
			board.target_slot_at(index), board.target_index_at(index))
		if target_position is Vector3:
			shot.launch_toward((target_position as Vector3) - shot.global_position)
		# Story 7-1 (AC 12/AC 16/AC 21): the shot's LOOK by its effect id -- Fireball's core, a Rocksling stone, a
		# Corpse Bomb skull (whose minion glows as it leaves). The scene and its `Hitbox` are unchanged (AC 35); a
		# totem shot has no effect id and keeps `5-0c`'s look.
		if _effects != null:
			var effect_id := StringName(board.effect_id_at(index))
			_effects.dress_projectile(shot, effect_id, board.damage_at(index))
			# A spell shot that names a BOARD INDEX as its source left a minion (Corpse Bomb's skull); a hero's
			# own shot carries `HERO_INDEX` there (`add_hero_shot`), and a totem shot has no effect id.
			if effect_id != &"" and board.source_index_at(index) >= 0:
				_effects.skull_source_glow(_actor_at(slot, board.source_index_at(index)))
		actors.append(shot)


## Where a shot fired by the unit at `source_index` on slot `slot` first appears. See
## `_spawn_missing_projectile_actors` for why the owner hero is the fallback.
##
## STORY 6-5d: THE HERO BRANCH LAUNCHES FROM THE CASTER'S FEET, AND THAT IS A DEFECT FIX RATHER THAN A
## PREFERENCE -- found by `test/integration/test_fireball_live.gd`, which is the runtime-composition
## blind spot `3-0b/R34` names: state and runner each correct, wired to each other wrongly.
##
## THE TWO ROOT CONVENTIONS DISAGREE. A unit's root is its FEET (`unit_actor.tscn`: "the runner spawns
## units at y 0"); a hero's root is its body CENTRE (`hero.tscn`: the 1x2x1 body box spans root y
## [-1,+1]). `projectile_actor.tscn` offsets its Hitbox +0.7 in y "to fly at roughly chest height on
## both a hero and a totem" -- i.e. calibrated against the FEET convention. Launched from a hero's ROOT
## the sphere therefore sat a whole metre high, spanning y 1.35..2.05, and a minion's hurtbox spans
## 0..1.2: MEASURED, a Fireball flew 0.15 m OVER a minion's head and could never overlap one at all.
## Nothing headless could see it -- a pass-through and a landing are both synthetic facts at the seam --
## and AC 19's "the shot always lands on a minion or totem" was live-unreachable.
##
## READ FROM THE AUTHORED BODY BOX, never a literal 1.0: a hero mesh or box resize retunes this with it,
## and the number that matters is the one the scene actually declares. The fallback for a unit-fired shot
## whose source is already freed lands on the same expression, which is the better answer there too --
## that shot was a unit's, at unit height.
func _projectile_launch_position(slot: int, source_index: int) -> Vector3:
	var actors: Array = _unit_actors[slot]
	if source_index >= 0 and source_index < actors.size():
		var source: Node = actors[source_index]
		if is_instance_valid(source):
			return (source as Node3D).global_position
	var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
	var position := hero.global_position
	return Vector3(position.x, _hero_ground_y(hero), position.z)


## Story 6-5d: the y of `hero`'s FEET -- its root lowered by half the authored body box, which is the
## height convention a unit actor's root already sits at. A hero with no such box (impossible on
## `hero.tscn`, answered rather than asserted for the runner's standing total-function posture) keeps
## its root height.
func _hero_ground_y(hero: HeroActor) -> float:
	var collision := hero.get_node_or_null("Collision") as CollisionShape3D
	if collision == null:
		return hero.global_position.y
	var box := collision.shape as BoxShape3D
	if box == null:
		return hero.global_position.y
	return hero.global_position.y - box.size.y * 0.5


## Story 4-4 (AC 15/AC 16/AC 19): steer and move slot `slot`'s live projectiles — the DRIVE-phase
## seat, beside `_approach_unit_actors` and for its reason (`game-architecture.md` names this phase
## "drive actor movement", and this is a move).
##
## THE STATE LAYER DECIDES WHETHER TO STEER; THIS ASKS AND OBEYS. `is_homing_at` is the flag AC 16's
## i-frame drop clears, and when it reads false this simply stops calling `steer_toward` — so
## "keeps its last heading and travels in a straight line" is the ABSENCE of an update rather than a
## second movement mode, and there is no straight-line branch to fall out of step with the homing one
## (`4-4/R5`: nothing here ends homing, and a target leaving the flight path is not an event).
##
## THE DISTANCE IS THE STATE LAYER'S OWN, read through `MatchState.projectile_step_distance_at` —
## literally the number `_advance_projectiles` charged the 60 m odometer with on the tick that just
## completed, so the distance flown and the distance spent are one number rather than two curves that
## drift apart over a long flight.
##
## IT USED TO READ A SPEED INSTEAD, AND THAT WAS REVIEW FINDING H2. This seat called
## `projectile_speed_at(board, index)` after `advance()` had returned, and the flight clock had
## already been incremented by then — so the actor flew at speed(t+1) while the odometer had been
## charged speed(t), permanently one tick ahead on the acceleration curve. Three comments (this one,
## and two in `match_state.gd`) asserted the opposite in as many words. Asking for the SPENT DISTANCE
## makes the claim true by construction rather than by comment.
##
## A DEAD SHOT IS NOT DRIVEN. Its actor is freed later in the same frame; driving it first would move
## a corpse one last tick and could produce a contact fact the state layer would then drop at the
## dead-attacker rung — work done to be discarded.
func _drive_projectiles(slot: int, player: PlayerState) -> void:
	var actors: Array = _projectile_actors[slot]
	var board := player.projectiles
	for index: int in actors.size():
		if not board.is_alive_at(index):
			continue
		var node: Node = actors[index]
		if not is_instance_valid(node):
			continue
		var shot := node as ProjectileActor
		if board.is_homing_at(index):
			var target_position: Variant = _target_world_position(
				board.target_slot_at(index), board.target_index_at(index))
			if target_position is Vector3:
				# Story 6-5d (Open Question 4): asked of the STATE LAYER, which is now the only place the
				# authored curve is resolved. The runner-side twin this line used to call could only ever
				# resolve a shot through a unit KIND INDEX, so a hero-sourced Fireball (authored on a
				# `CardEffect`, not on a kind) would have steered at a null profile -- i.e. not at all.
				var profile := _match_state.projectile_profile_at(board, index)
				if profile != null:
					shot.steer_toward(target_position as Vector3,
							profile.homing_turn_rate_degrees_per_second)
		shot.advance_flight_by(_match_state.projectile_step_distance_at(board, index))


## Story 4-4 (AC 14): the CONTACT GATHER for slot `slot`'s live projectiles — the
## `_gather_unit_facts` hitbox pass, applied to a shot.
##
## THE SAME DIRECT `get_overlapping_areas()` QUERY, never `area_entered`: signal firing order is not
## guaranteed and would make replay order-dependent (the 1-7 `D-4` reasoning, unchanged).
##
## GATED ON THE STATE LAYER'S LIVENESS rather than on a phase, which is the one structural difference
## from the unit pass: a shot has no active window — it is live from launch until it is consumed or
## its budget expires, and that IS the window.
##
## THE ATTACKER ADDRESS IS THE PROJECTILE PARTITION (`E4-P/R12`,
## `MatchState.projectile_attacker_index`), so the fact carries the shot's own identity rather than
## its source unit's — which is what lets a shot resolve after its totem is dead. Same-slot overlaps
## are filtered at GATHER time exactly as they are for units, so a shot can never hit its own side
## and a self-contact fact never reaches the seam.
##
## THE `attack_index` IS THE SHOT'S FLIGHT CLOCK, and it keys nothing: a projectile's dedupe IS its
## liveness (`projectile_board.gd`'s header), so no record is opened under this number. It is filled
## honestly rather than with a placeholder a later reader could mistake for a swing counter.
func _gather_projectile_facts(attacker_slot: int, player: PlayerState) -> void:
	var actors: Array = _projectile_actors[attacker_slot]
	var board := player.projectiles
	for index: int in actors.size():
		if not board.is_alive_at(index):
			continue
		var node: Node = actors[index]
		if not is_instance_valid(node):
			continue
		var shot := node as ProjectileActor
		var attacker_address: Array[int] = [attacker_slot,
				MatchState.projectile_attacker_index(index)]
		var attack_index := board.flight_ticks_at(index)
		for area: Area3D in (shot.get_node("Hitbox") as Area3D).get_overlapping_areas():
			var owner_actor := area.get_parent()
			var address := _address_of(owner_actor)
			if address[0] == -1:
				continue  # a hurtbox this runner cannot address
			if address[0] == attacker_slot:
				continue  # a shot never hits its own side
			var to_attacker := shot.global_position - (owner_actor as Node3D).global_position
			var dir := Vector2(to_attacker.x, to_attacker.z)
			if dir.is_zero_approx():
				continue  # degenerate co-location has no direction -- dropped at gather
			var fact_dir := dir.normalized()
			_recorder.capture_push_contact(attacker_address, address, attack_index, fact_dir,
					MatchState.CONTACT_STRIKE)
			_match_state.push_contact(attacker_address, address, attack_index, fact_dir,
					MatchState.CONTACT_STRIKE)


## Story 4-4 (AC 18/AC 19): free the actor of any shot the state layer has ended — consumed by a
## contact, or expired against its 60 m budget. AC 19's "removed from the world" made literal.
##
## NO LINGER, unlike a corpse (`4-3d`). A minion's corpse lingers because a dead body is a thing a
## player expects to see fall and lie there; a projectile that has landed or run out of budget has no
## such reading — it should simply be gone, which is what "removed from the world" asks for.
##
## A `null` HOLE IS LEFT AT THE INDEX rather than the array being compacted, for the reason the unit
## array leaves one: the index IS the state layer's identity for that shot, so compacting would
## re-point every later record's actor.
func _free_dead_projectile_actors(slot: int, player: PlayerState) -> void:
	var actors: Array = _projectile_actors[slot]
	for index: int in actors.size():
		if player.projectiles.is_alive_at(index):
			continue
		var node: Node = actors[index]
		if not is_instance_valid(node):
			continue
		# Story 7-1 (AC 16, `7-1/R2`): a hero-spell shot's END is noted here, while its actor and record still
		# say where it was, at whom it flew and whether it ran out of budget; its look is chosen after the drain.
		var effect_id := player.projectiles.effect_id_at(index)
		if _effects != null and effect_id != "":
			var shape := node.get_node_or_null("Hitbox/HitboxShape") as Node3D
			_ended_shots.append([slot, effect_id,
					shape.global_position if shape != null else (node as Node3D).global_position,
					player.projectiles.target_slot_at(index), player.projectiles.target_index_at(index),
					_shot_expired(player.projectiles, index)])
		node.queue_free()
		actors[index] = null


## STORY 6-5d (Open Question 4) DELETED `_projectile_profile`, the runner-side twin of
## `MatchState._projectile_profile_at`, and the deletion is the point rather than a tidy-up. The twin
## resolved a shot's profile through its unit KIND INDEX -- the only source a shot had before this story
## -- so it could not have learned the hero-sourced EFFECT path without being taught the same lookup
## twice, which is exactly the duplicated copy `projectile_speed_at`'s docstring already forbade ("the
## state layer's ONE expression of the authored curve, so nothing outside it may keep a duplicated copy
## that a retune could desynchronise"). `_drive_projectiles` now asks
## `MatchState.projectile_profile_at`, which is public for this reason and exempt as a pure query.


## Story 4-4 (AC 6/AC 9): the attack record governing the unit at `index` on `player`'s board, or
## NULL when it has none. The runner-side twin of the resolution
## `MatchState._advance_unit_attacks` does with the tick-domain records, and it is a helper rather
## than three inline lines because two seats in this file need the same answer.
##
## READ INLINE OFF THE CONFIG HANDLE THE CALLER ALREADY RESOLVED (CONSTRAINT C / `4-3/R11`): the
## `balance` argument is `_match_state.balance`, the replay-aware handle — never
## `BalanceConfigService`, which during a replay would measure reach at the AUTHORED value instead
## of the RECORDED one.
##
## NULL ON EVERY MISS, and each miss is a real authored state rather than an error: a kind index no
## longer in the authored list (an X3 reload that shortened it), and a kind that authors an empty
## attack list (the two accelerator totems, AC 3). Both mean the same thing to every caller — this
## unit has no attack — so they get the same answer rather than two.
func _unit_attack_profile(balance: BalanceConfig, player: PlayerState,
		index: int) -> UnitAttackProfile:
	var kind := balance.kind_at(player.units.kind_index_at(index))
	if kind == null:
		return null
	return kind.attack_at(0)


## Story 4-3b (AC 13, `4-3b/R17a`/`R17b`): THE THROTTLED REACH PROBE. One kind-marked fact per unit
## whose ACQUIRED TARGET is within the authored reach, on the SAME cadence the minion retargeting
## already uses, off the SAME authored field -- `minion_retarget_interval_ticks`, 12 ticks at the
## authored 0.2 s. No new balance field is authored for it, so the audited field list and its guard
## are untouched.
##
## WHY A FACT AT ALL, AND WHY IT IS LEGAL UNDER `4-3/R2` (measured at the readiness gate, not
## assumed): a unit begins its windup ONLY when its target is in reach, that decision happens inside
## `advance()`, and state cannot derive a distance because POSITION IS ACTOR-OWNED. `4-3/R2` closed
## unit position ownership and affirmed that "`push_contact` remains the only inward intake" -- and
## the contact fact's `dir` field has carried position-DERIVED spatial data through that very intake
## since 1-8. A narrow "this unit's reach volume overlaps its acquired target" relation on the
## EXISTING intake therefore falls INSIDE the ruling: it pays no new intake, and it delivers neither
## a position nor a velocity. State learns a RELATION, not a location.
##
## THROTTLED, AND THE THROTTLE IS THE POINT. A strike fact exists only during an active window; an
## UNTHROTTLED probe would exist on every tick a unit stands in range -- up to 16 rows/tick,
## ~960 rows/second at `4-5`'s 16-unit criterion, against today's sparse per-swing bursts. On the
## existing 12-tick interval that falls to ~1.33 rows/tick, ~80 rows/second: a 12x reduction.
##
## GATHERED REGARDLESS OF THE UNIT'S PHASE, AND AN IDLE-ONLY NARROWING IS REJECTED (`4-3b/R17b`).
## An idle-only probe would leave a unit finishing recovery waiting up to a full interval for the
## next probe, so the effective cycle would be windup+active+recovery+up-to-one-interval, JITTERING
## with where the swing happened to land relative to the cadence -- meaning AC 1's authored durations
## would not describe the observed attack rate. A performance decision must not silently retune
## combat. Nothing is lost by dropping the narrowing: the THROTTLE, not the idle test, is what buys
## the reduction.
##
## THE CADENCE IS A RUNNER-LOCAL COUNTER, and that is deliberate rather than lazy: `MatchState._tick`
## is PRIVATE, surfaced only inside `to_snapshot()`, and a new public tick accessor is NOT taken for
## this. It is replay-safe for exactly the reason today's overlap facts are -- the fact is TAPPED
## here and REPLAYED FROM THE RECORD, never regenerated through physics on replay (the `3-0c` AC 9
## fork), so a replay never runs this function at all and never consults this counter.
##
## THE INTERVAL AND THE REACH ARE READ INLINE (CONSTRAINT C) off the config the runner already
## applied -- never `BalanceConfigService`, never cached on this node or on an actor, which during a
## replay would measure reach at the AUTHORED value instead of the RECORDED one.
func _push_reach_probe(attacker_slot: int, player: PlayerState, index: int, unit: UnitActor,
		attacker_address: Array[int], attack_index: int, reach: float) -> void:
	var target_slot := player.units.target_slot_at(index)
	if target_slot == TargetingService.NO_TARGET_SLOT:
		return
	if target_slot == attacker_slot:
		return  # own-side targets are impossible today (`4-2/R3`); never push a self-contact
	var target_index := player.units.target_index_at(index)
	var target_position: Variant = _target_world_position(target_slot, target_index)
	if not (target_position is Vector3):
		return  # an actor the runner has not spawned (or has freed) -- no measurable relation
	var to_attacker := unit.global_position - (target_position as Vector3)
	var dir := Vector2(to_attacker.x, to_attacker.z)
	# PLANAR (XZ) centre-to-centre, the SAME geometry `unit_stop_distance` is measured in, so
	# "has it arrived" and "is it in reach" are one geometry compared against two authored
	# numbers rather than two geometries that could disagree. The authoring audit requires
	# reach >= stop distance for exactly that reason.
	if dir.length() > reach:
		return
	if dir.is_zero_approx():
		return  # degenerate co-location has no direction -- the seam rejects a zero fact
	# The probe carries the unit's CURRENT attack counter. It keys nothing (a probe never
	# registers a dedupe hit), but the fact's shape is the seam's and every field is filled
	# honestly rather than with a placeholder a later reader could mistake for a real swing.
	var target_address: Array[int] = [target_slot, target_index]
	var fact_dir := dir.normalized()
	_recorder.capture_push_contact(attacker_address, target_address, attack_index, fact_dir,
			MatchState.CONTACT_REACH_PROBE)
	_match_state.push_contact(attacker_address, target_address, attack_index, fact_dir,
			MatchState.CONTACT_REACH_PROBE)


## Story 4-3a (AC 4): the overlapping area's owning actor resolved to a `[slot, index]` TARGET
## ADDRESS -- `4-2/R2`'s convention, the same one `unit_board.gd` uses for what a unit has ACQUIRED,
## so the contact fact's target and a unit's acquired target are ONE addressing scheme.
##
## `[-1, -1]` means UNADDRESSABLE and the caller drops the overlap, which is the old `_slot_of == -1`
## drop preserved for everything that is genuinely neither a hero nor a spawned unit.
##
## HEROES ARE RESOLVED BY `_slot_of` AND NOTHING ELSE, deliberately: that function is EXTENDED by
## this one rather than replaced, so hero-vs-hero identity resolution is bit-for-bit the code it was
## before this story -- the regression pin AC 3 names rests on that.
##
## A UNIT IS FOUND BY IDENTITY IN THE PER-SLOT ACTOR ARRAY, and its position in that array IS its
## board index (AC 4 / `4-3a/R13`) -- the same number the state layer uses, which is what keeps the
## runner's array index and the state's identity one fact rather than two that could drift. `find()`
## compares by reference and skips the `null` HOLES a freed corpse leaves behind (a freed actor is
## never the argument here: it is gone from the tree, so its hurtbox cannot be in an overlap result).
func _address_of(owner_actor: Node) -> Array[int]:
	var hero_slot := _slot_of(owner_actor)
	if hero_slot != -1:
		return [hero_slot, TargetingService.HERO_INDEX]
	for slot: int in 2:
		var index: int = (_unit_actors[slot] as Array).find(owner_actor)
		if index != -1:
			return [slot, index]
	return [-1, -1]


func _slot_of(actor: Node) -> int:
	if actor == _p1_hero:
		return 0
	if actor == _p2_hero:
		return 1
	return -1


## Story 4-6 (AC 1/AC 2, `4-6/R6`): the world-space PLANAR direction from this slot's hero to
## whatever that slot has locked, as a unit `Vector2` in the (x, z) convention `HeroState.facing`
## and the contact fact's `dir` already use.
##
## FROM POSITIONS ONLY, exactly as `_gather_contact_facts` computes `target_to_attacker`: the
## runner reports the spatial fact and state decides what it means. The ADDRESS comes from state
## (`PlayerState.lock_target_*`); turning it into a world position is done HERE, through the same
## `_target_world_position` the unit aim/approach loops use, so there is one address-to-position
## mapping in this file rather than two.
##
## Vector2.ZERO IS "NO FACT", and it has three causes, all of them handled the same way by both
## consumers (facing keeps its last value, the rig keeps its heading): an unspawned or freed target
## actor (`_target_world_position` returns null), a degenerate co-located target (the
## `push_contact` zero-direction drop verbatim), and a hero actor that is no longer valid.
func _lock_direction(slot: int) -> Vector2:
	var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
	if not is_instance_valid(hero):
		return Vector2.ZERO
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	# Story 6-8 (AC 7): an UNLOCKED slot has no target, so no direction -- the ZERO "no fact". State
	# ignores the lock direction while unlocked anyway (AC 3); returning ZERO here is what keeps the
	# sentinel address from ever being walked to an actor.
	if not player.is_locked():
		return Vector2.ZERO
	var target_position: Variant = _target_world_position(
		player.lock_target_slot, player.lock_target_index)
	if target_position == null:
		return Vector2.ZERO
	var to_target: Vector3 = (target_position as Vector3) - hero.global_position
	var planar := Vector2(to_target.x, to_target.z)
	if planar.is_zero_approx():
		return Vector2.ZERO
	return planar.normalized()


## Story 6-5b (AC 18/AC 22, `6-5b/R6`): WHICH of slot `slot`'s own living minions its hero is FACING
## most directly -- the board index Drain will sacrifice, or `MatchState.NO_DRAIN_TARGET` for none.
##
## THE SELECTION LIVES HERE AND CANNOT LIVE IN STATE. It needs the hero's world position and every
## minion actor's world position, and `src/state/` owns no position and may not query the scene
## (D3(b)/A2, `4-3/R2`). The runner computes and pushes; state receives the already-resolved answer
## through `push_drain_target` and never recomputes it (`_apply_drain`). `_lock_direction` directly
## below is the same shape of computation -- two actor positions in, one plain fact out.
##
## THE RULE, AND ITS TIE-BREAKS IN ORDER (AC 18): smallest ANGLE between the hero's facing and the
## hero-to-minion direction wins; equal angle, smaller DISTANCE wins; equal angle and distance, LOWER
## BOARD INDEX wins. The angle comparison is done on the COSINE (the dot product of two unit vectors),
## which is monotonically DECREASING in the angle -- so "smallest angle" is "largest cosine", and no
## `acos` is called: it would spend a transcendental per minion per tick to order values the dot
## product already orders, and it loses precision near zero angle exactly where the tie-break matters.
##
## THE INDEX TIE-BREAK IS THE LOOP ORDER, not a comparison: the walk is ascending and a candidate must
## be STRICTLY better to replace the incumbent, so the lowest index survives an exact tie in both
## keys. That is also why both comparisons carry an epsilon -- with exact float equality, two minions
## the operator placed symmetrically would be ordered by the last bit of a square root.
##
## TOTEMS ARE EXCLUDED HERE TOO, and the state side re-validates it: `_apply_drain`'s
## `_is_own_minion` check means a totem index pushed by a stale or wrong gather cannot be sacrificed,
## so this filter decides the CHOICE while state decides the LEGALITY. Two layers agreeing, with the
## authoritative one last.
##
## `facing` IS WORLD-SPACE PLANAR (`R1`, locked), so it is compared directly against a world-space
## planar direction with no basis in between. A zero facing or a co-located minion has no direction
## and contributes nothing -- the `push_contact` / `_lock_direction` zero-direction rule verbatim.
const DRAIN_ANGLE_EPSILON := 0.0001
const DRAIN_DISTANCE_EPSILON := 0.0001

func _gather_drain_target(slot: int, player: PlayerState) -> int:
	var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
	if not is_instance_valid(hero):
		return MatchState.NO_DRAIN_TARGET
	var facing := player.hero.facing
	if facing.is_zero_approx():
		return MatchState.NO_DRAIN_TARGET
	var balance := _match_state.balance
	if balance == null:
		return MatchState.NO_DRAIN_TARGET
	var minion_kind := balance.kind_index_of(CardEffectResolver.KIND_MINION)
	var actors: Array = _unit_actors[slot]
	# THE CANDIDATE LIST IS BUILT HERE AND THE CHOICE IS MADE BELOW, and the split is what makes the
	# rule testable at all: everything in this loop touches the scene tree and the board, and nothing
	# in `_select_drain_target` touches either.
	var candidates: Array = []
	for index: int in actors.size():
		if not player.units.is_alive_at(index):
			continue
		if player.units.kind_index_at(index) != minion_kind:
			continue
		var unit: Node = actors[index]
		if not is_instance_valid(unit):
			continue
		var spot: Vector3 = (unit as Node3D).global_position
		candidates.append([index, Vector2(spot.x, spot.z)])
	var origin := hero.global_position
	return _select_drain_target(facing, Vector2(origin.x, origin.z), candidates)


## Story 6-5b (AC 18/AC 22, `6-5b/R6`): THE ANGLE RULE ITSELF -- which of `candidates` a hero at
## `hero_xz` facing `facing` is looking at most directly. `candidates` is `[[board_index, xz], ...]`,
## ASCENDING BY INDEX, as `_gather_drain_target` above builds it.
##
## A PURE FUNCTION OF ITS ARGUMENTS, and that is a REQUIREMENT rather than a happy accident, for
## `_compute_spawn_positions`' stated reason: it reads no scene tree, holds no node reference, touches
## no board and mutates no runner field. That is what lets AC 22's tie-break matrix be driven directly
## against hand-placed positions on a bare runner instance, with no scene and no frame
## (test/integration/test_drain_selection.gd, the `test_unit_spawn_purity.gd` precedent).
##
## THE RULE, AND ITS TIE-BREAKS IN ORDER (AC 18): smallest ANGLE between the hero's facing and the
## hero-to-minion direction wins; equal angle, smaller DISTANCE wins; equal angle and distance, LOWER
## BOARD INDEX wins.
##
## THE COMPARISON IS ON THE COSINE -- the dot product of two unit vectors -- which is monotonically
## DECREASING in the angle, so "smallest angle" is "largest cosine". No `acos` is called: it would
## spend a transcendental per minion per tick to order values the dot product already orders, and it
## loses precision near zero angle exactly where the tie-break matters.
##
## THE INDEX TIE-BREAK IS THE LOOP ORDER, not a comparison: the walk is ascending and a candidate must
## be STRICTLY better to replace the incumbent, so the lowest index survives an exact tie in both keys.
## That is also why both comparisons carry an epsilon -- with exact float equality, two minions the
## operator placed symmetrically would be ordered by the last bit of a square root.
func _select_drain_target(facing: Vector2, hero_xz: Vector2, candidates: Array) -> int:
	if facing.is_zero_approx():
		return MatchState.NO_DRAIN_TARGET
	var heading := facing.normalized()
	var best := MatchState.NO_DRAIN_TARGET
	var best_cosine := -2.0     # below every real cosine, so the first candidate always takes
	var best_distance := 0.0
	for candidate: Array in candidates:
		var to_minion: Vector2 = (candidate[1] as Vector2) - hero_xz
		var distance := to_minion.length()
		# A CO-LOCATED MINION HAS NO DIRECTION and contributes nothing -- the `push_contact` /
		# `_lock_direction` zero-direction rule verbatim, rather than an arbitrary heading.
		if distance <= 0.0:
			continue
		var cosine := heading.dot(to_minion / distance)
		var better_angle := cosine > best_cosine + DRAIN_ANGLE_EPSILON
		var same_angle_closer := cosine > best_cosine - DRAIN_ANGLE_EPSILON \
				and distance < best_distance - DRAIN_DISTANCE_EPSILON
		if best == MatchState.NO_DRAIN_TARGET or better_angle or same_angle_closer:
			best = int(candidate[0])
			best_cosine = cosine
			best_distance = distance
	return best


## Story 6-8 (AC 7-AC 10/AC 12): the step-1c RIG seat for one slot -- the ONE place the runner
## decides what turns a camera this tick, so the two rig write paths can never both fire.
##
## LOCKED: `face_lock_direction` with the step-1c direction, exactly as 4-6/4-6a shipped it -- which
## is also AC 12's relock swing, since a rig that already has a heading EASES onto a new one.
## UNLOCKED: `rotate_free_yaw` with this slot's controller rotation axis (Open Question 2). Nothing
## else writes the unlocked rig: no snap on unlock (AC 9) and no recenter (AC 10) fall out of there
## being no other call.
##
## WHICH STATE: the STANDING lock, read before this tick's advance() -- the same read `_lock_direction`
## makes one line up, so the rig and the direction pushed into state agree about whether this slot
## is locked. A click takes effect in state this tick and on the rig from the next, the one-tick
## F1 order every pushed fact already has.
##
## THE ROTATION IS NOT RECORDED AS INPUT and does not need to be: the rig's yaw reaches state only
## through the basis pushed at step 2, and that basis is captured by `capture_set_camera_basis` and
## replayed by `replay_push_camera_bases` exactly as the smoothed lock yaw is (4-6a Open Question 5).
## In replay the controller is a `ReplayController`, whose base `camera_rotate()` is 0.0, so the
## replayed rig does not turn -- presentation, which replay does not promise to reproduce.
func _aim_rig(slot: int, rig: CameraRig, lock_dir: Vector2, controller: Controller) -> void:
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	if player.is_locked():
		rig.face_lock_direction(lock_dir)
	else:
		rig.rotate_free_yaw(controller.camera_rotate())


## Story 4-6 (AC 9/AC 10/AC 11): turn one slot's right-stick gesture into a retarget ADDRESS on
## that slot's intent. Writes nothing when there is no gesture, and nothing when a flick finds no
## candidate -- the no-op is delivered by sending no request at all, which leaves the standing
## lock untouched state-side.
##
## CLICK BEATS FLICK, checked first. The controller already suppresses a flick on a click tick;
## stating the precedence at both layers costs one branch and means neither can silently disagree
## with the other.
##
## Story 6-8 (AC 1): THE CLICK IS THREE-WAY, and the runner resolves which way against the STANDING
## lock -- the lock state after last tick, which is exactly what the player is looking at -- and
## stamps only the outcome, the `CC/R5` result-not-gesture rule unchanged. Locked on a minion or
## totem, or unlocked: the opposing hero. Locked on the opposing hero: the UNLOCKED sentinel address.
##
## Story 6-8 (AC 11): a flick while UNLOCKED is a no-op -- there is no standing lock to cycle from.
func _resolve_retarget(slot: int, intent: InputIntent, controller: Controller) -> void:
	var opposing := 1 - slot
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	if controller.relock_pressed():
		if player.lock_target_slot == opposing \
				and player.lock_target_index == TargetingService.HERO_INDEX:
			intent.retarget_slot = PlayerState.UNLOCKED_SLOT
		else:
			intent.retarget_slot = opposing
		intent.retarget_index = TargetingService.HERO_INDEX
		return
	var flick := controller.retarget_flick()
	if flick.is_zero_approx() or not player.is_locked():
		return
	var addresses: Array[Array] = []
	var bearings: Array[float] = []
	var current := _gather_cycle_candidates(slot, opposing, addresses, bearings)
	if current == -1:
		return
	var pick := LockOnResolver.cycle_candidate(flick, bearings, current)
	if pick == -1:
		return
	intent.retarget_slot = addresses[pick][0]
	intent.retarget_index = addresses[pick][1]


## Story 6-8 (AC 13/AC 14): the 360-degree candidate set for a flick -- the OPPOSING HERO plus every
## LIVING unit on the opposing board (minions and totems alike, which are one board), gathered
## hero-then-units in board-index order so `LockOnResolver.cycle_candidate`'s index tie-break is the
## lower-board-index rule (AC 17, the `4-3b/R5` total order).
##
## REPLACES 4-6a's `_gather_flick_candidates`. Two things changed and both are the story's: nothing
## is filtered on SCREEN VISIBILITY any more (a target behind the hero is a candidate, AC 13), and
## the CURRENT TARGET IS INCLUDED rather than excluded, because in a bearing circle it holds its own
## place (AC 17). Each candidate becomes a BEARING around this slot's hero from WORLD positions,
## never a screen projection; no camera is read.
##
## OPPOSING SLOT ONLY, unchanged: a player locks onto things that can be fought.
##
## RETURNS the current target's index into `bearings`, or -1 when it has none -- its actor is not
## spawned, or it is co-located with the hero so it has no bearing. The caller turns that into a
## no-op. A candidate whose actor is unspawned or co-located is skipped the same way; it has no place
## in a circle of bearings.
func _gather_cycle_candidates(slot: int, opposing: int, addresses: Array[Array],
		bearings: Array[float]) -> int:
	var hero: HeroActor = _p1_hero if slot == 0 else _p2_hero
	if not is_instance_valid(hero):
		return -1
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	var opponent: PlayerState = _match_state.p1 if opposing == 0 else _match_state.p2
	var candidates: Array[Array] = [[opposing, TargetingService.HERO_INDEX]]
	var actors: Array = _unit_actors[opposing]
	for index: int in actors.size():
		if opponent.units.has_index(index) and opponent.units.is_alive_at(index):
			candidates.append([opposing, index])
	var current := -1
	for address: Array in candidates:
		var world: Variant = _target_world_position(address[0], address[1])
		if world == null:
			continue
		var offset: Vector3 = (world as Vector3) - hero.global_position
		var planar := Vector2(offset.x, offset.z)
		if planar.is_zero_approx():
			continue
		if address[0] == player.lock_target_slot and address[1] == player.lock_target_index:
			current = addresses.size()
		addresses.append(address)
		bearings.append(LockOnResolver.bearing_of(planar))
	return current


## Story 4-6a (AC 13/AC 14): where this slot's CURRENT locked target sits in this slot's own
## viewport, or null when it is nowhere visible there. Story 6-8 (AC 14) leaves this function ONE
## CALL SITE, the on-screen MARKER (step 4d, after 4b): the flick's cycling anchor is now the current
## target's BEARING (`_gather_cycle_candidates`), so 4-6a's second call site and review M1's
## marker-versus-pick offset are gone with it.
##
## THE ADDRESS COMES FROM STATE, THE POSITION IS COMPUTED HERE, and no position ever travels inward
## (`4-2/R14`, the `_aim_unit_actors` rule verbatim). Reads `PlayerState.lock_target_*` fresh on
## every call, which is the whole of AC 14's "follows whichever candidate is currently locked": a
## lock that snaps under `4-6/R4` (locked-unit death) relocates this the same tick, and one that
## addresses a freed or unspawned actor returns null so the marker clears rather than lingering on
## a corpse.
##
## Live-smoke micro-fix (4-6a, operator smoke 2026-08-31): reads `_lock_mark_world_position`
## rather than `_target_world_position` directly, so the point projected here sits on the target's
## BODY rather than its ORIGIN. (4-6a review M3's lifted-anchor asymmetry no longer exists: story 6-8
## measures the cycling anchor as a planar bearing from actor roots, where a vertical lift has no
## effect.)
func _lock_target_screen_position(slot: int, view_cam: Camera3D) -> Variant:
	if not is_instance_valid(view_cam):
		return null
	var player: PlayerState = _match_state.p1 if slot == 0 else _match_state.p2
	# Story 6-8 (AC 6): the marker is a LOCKED-ONLY cue. Unlocked, there is nothing to mark, and the
	# null hides it through the same path an off-screen target already takes.
	if not player.is_locked():
		return null
	var world: Variant = _lock_mark_world_position(player.lock_target_slot, player.lock_target_index)
	if world == null:
		return null
	return _screen_position(view_cam, world as Vector3)


## Live-smoke micro-fix (4-6a, operator smoke 2026-08-31): the world point the lock MARKER projects -- `_target_world_position`'s
## answer LIFTED onto the target's body, because that function's answer is the actor ROOT, and the
## roots disagree about where the body is. `hero.tscn`'s root is already the body CENTRE
## (`hero.tscn:49`'s "GROUNDING OFFSET" note), so a hero target needs no lift. `unit_actor.tscn` and
## `totem_actor.tscn` both root at the FEET (`unit_actor.tscn:19`, `totem_actor.tscn:16`). A minion
## (has a `Hitbox`, `unit_actor.tscn:29`) and a totem (deleted `Hitbox`, `totem_actor.tscn:9`) share
## the one script, so the `Hitbox` presence already used by `_unit_scene_for` (line 773) to pick the
## scene at spawn time is read again here to tell them apart at mark time.
##
## `_target_world_position` ITSELF IS UNTOUCHED: the unit aim/approach loops and `_lock_direction`'s
## facing (which discards Y for its planar direction) all still walk actors to their ROOT, not a
## point above it -- lifting that shared function would move minions toward a point in the air.
##
## Live-smoke micro-fix v2 (4-6a, operator smoke 2026-08-31, verdict: minion too low): v1 lifted the
## minion by HALF ITS AUTHORED COLLISION BOX (0.6 = 1.2 / 2) rather than by anything read off the
## actual skinned model, and `unit_actor.tscn:46`'s own description already says the model's
## on-screen size was never decided -- `skeletonzombie.fbx` renders far taller than the 1.2 m
## placeholder box the lift was borrowed from, so half of it lands at the minion's CROTCH. Measured
## once by instancing `unit_actor.tscn` headless and merging the `get_aabb()` of every
## `VisualInstance3D` under it EXCEPT primitive gizmo meshes (there are none on this scene -- the
## filter matters for `hero.tscn`'s telegraph cones/discs, not this one): the skinned mesh spans
## world y [-0.016, 2.046] off its own root, i.e. a real height of ~2.062 m with its feet already
## essentially at the root. `LOCK_MARK_UNIT_LIFT` is now ~3/4 of that real height (souls-standard
## chest, `2/3..3/4`, closer to `3/4` per operator ruling) measured from the ground, i.e.
## `-0.016 + 0.75 * 2.062 ~= 1.53` -- the minion is the one this pass corrects, so it is the only one
## re-derived from the model.
##
## `LOCK_MARK_TOTEM_LIFT` is UNCHANGED: totem smoke verdict was "looks right", the totem carries no
## skinned model to mismeasure (`totem_actor.tscn`'s `Mesh` IS the authored `BoxMesh_totem`, so the
## collision box already equals the real visual box), and the operator ruling requires the totem not
## to visibly move -- touching a value that already matches its own real geometry would be a
## regression, not a fix.
const LOCK_MARK_UNIT_LIFT := 1.53  ## skeletonzombie.fbx real AABB height ~2.062, ~3/4 from the ground (see above).
const LOCK_MARK_TOTEM_LIFT := 0.7  ## totem_actor.tscn body box height 1.4, half (totem_actor.tscn:13) -- unchanged, smoke-verified correct.

func _lock_mark_world_position(target_slot: int, target_index: int) -> Variant:
	var world: Variant = _target_world_position(target_slot, target_index)
	if world == null or target_index == TargetingService.HERO_INDEX:
		return world
	var unit: Node = (_unit_actors[target_slot] as Array)[target_index]
	var lift := LOCK_MARK_TOTEM_LIFT
	if unit is UnitActor and (unit as UnitActor).hitbox != null:
		lift = LOCK_MARK_UNIT_LIFT
	return (world as Vector3) + Vector3.UP * lift


## Story 4-6 (AC 10): unproject a world point into this slot's own viewport, or null when it is
## not visible there -- behind the camera, or outside the viewport rectangle. PRESENTATION ONLY;
## nothing it returns reaches `src/state/` except through the resolved ADDRESS the caller stamps
## on the intent.
func _screen_position(view_cam: Camera3D, world: Vector3) -> Variant:
	if view_cam.is_position_behind(world):
		return null
	var point := view_cam.unproject_position(world)
	var viewport := view_cam.get_viewport()
	if viewport == null:
		return null
	if not viewport.get_visible_rect().has_point(point):
		return null
	return point


func _physics_process(delta: float) -> void:
	# 0. Story 3-0b (AC 1): the DEBUG step/pause gate. Read through the controller-layer
	#    DebugInputReader (D3(a) — Input.* may not appear in this file), never as an intent:
	#    these presses do not enter InputIntent, the recorded intent stream, or advance(). Pause
	#    must survive the ABSENCE of ticking, which an intent consumed inside advance() cannot —
	#    the deliberate divergence from the intent-carried debug_reset. Both reads are EDGES, so
	#    a held key neither re-toggles the pause nor auto-fires steps: one tick per press.
	if _debug_input.pause_pressed():
		_paused = not _paused
	# 7-6 POLISH (P12): the instrument panel's show/hide edge, read the same way and for the same reason.
	# P20/P21: the same edge toggles the whole debug layer.
	if _debug_input.instruments_toggle_pressed():
		set_debug_layer_visible(not _debug_layer_visible)
	var ticking := not _paused or _debug_input.step_pressed()
	# 1. Sample controllers -> InputIntent per player (the ONLY place Input is read — D3).
	#    Sampled every frame, paused or not: sampling is not one of the three things AC 1
	#    freezes, and Godot's just-pressed edges are frame-scoped either way.
	var intents: Array[InputIntent] = [_p1_controller.sample(), _p2_controller.sample()]
	# 1b. Story 3-5a (AC 10): push each slot's ARMED CARD into its own HUD. Read off the
	#     CONTROLLER, not off state — the indicator shows what the player has SELECTED, which is
	#     a controller fact that never enters the tick or the snapshot. Same
	#     runner-polls-then-pushes-plain-values shape as the 3-0b window countdown (step 3b), so
	#     this is not a new observation seam (no member added to the pinned family): no signal, no state
	#     handle, plain ints only.
	#     OUTSIDE the `ticking` gate deliberately — the selection must stay visible and
	#     responsive while the debug pause is held, exactly as camera follow (4b) does.
	# Story 6-10 (AC 9a): knockdown drops card mode on its rising edge. The same `_stun_flavor_for_slot`
	# read the rig closure already uses (no new seam, no new connect), polled here rather than driven from
	# the action-state signal because the ordinary-to-knockdown escalation is a same-state write that emits
	# nothing. An ordinary stun never triggers it (AC 9a).
	for knock_slot: int in 2:
		var knocked := _stun_flavor_for_slot(knock_slot) == AnimationController.STUN_FLAVOR_KNOCKDOWN
		if knocked and not _was_knocked_down[knock_slot]:
			(_p1_controller if knock_slot == 0 else _p2_controller).force_card_mode_off()
		_was_knocked_down[knock_slot] = knocked
	# Story 6-10 (AC 16/AC 20): the card-mode lift rides the same poll-and-push, own HUD only.
	_huds[0].set_card_mode(_p1_controller.card_mode_on())
	_huds[1].set_card_mode(_p2_controller.card_mode_on())
	_huds[0].set_card_selection(_p1_controller.armed_slot(), Enums.ModeKind.BASIC)
	_huds[1].set_card_selection(_p2_controller.armed_slot(), Enums.ModeKind.BASIC)
	# Story 3-0b (AC 1): steps 2, 3 and 4 — gather, advance, drive — are THE freeze. While paused
	# nothing gathers, nothing advances, nothing drives; a single step runs this block exactly
	# once, in the unchanged per-tick order. Contact-fact gathering freezes WITH advance and drive
	# (not outside them): facts are per-tick observations of the CURRENT arrangement, so
	# accumulating a whole pause's worth and draining them into one step would corrupt the very
	# tick being instrumented. The camera-basis push rides inside the gate too — it is a state
	# write, and pushing it while paused is provably inert (the step tick re-pushes the live basis
	# before advance() reads it). Camera FOLLOW (step 4b) stays outside: the operator must be able
	# to look around while paused.
	if ticking:
		# 1c. Story 4-6 (AC 1/AC 2): THE LOCK-ON GATHER, and it comes BEFORE the fork and before
		#     the basis push for a reason that is a machine contract, not a style choice. The rig
		#     yaw is what MAKES the basis non-identity, so a push seated above this line would ship
		#     last tick's orientation into this tick's movement resolution -- one frame of camera
		#     lag folded into a HASHED value.
		#
		#     ONE COMPUTATION, TWO CONSUMERS. The same per-slot direction yaws the rig
		#     (presentation, AC 1) and is pushed into state as the facing fact (AC 2, `4-6/R6`);
		#     deriving it twice would be two answers to one question. It is computed from the two
		#     ACTOR POSITIONS this runner already owns -- state decides WHAT is locked, the runner
		#     turns that address into a direction, and no position ever travels inward
		#     (`4-2/R14`, the `_aim_unit_actors` rule verbatim).
		#
		#     THE YAW RUNS IN REPLAY TOO, on purpose: it is presentation, and replay guarantees
		#     STATE identity rather than VISUAL identity (see `replay_record` above). What replay
		#     does NOT do is push this live direction into state -- it drains the RECORDED one in
		#     the fork below, exactly as it does for the camera basis.
		var lock_dirs: Array[Vector2] = [_lock_direction(0), _lock_direction(1)]
		_aim_rig(0, _p1_rig, lock_dirs[0], _p1_controller)
		_aim_rig(1, _p2_rig, lock_dirs[1], _p2_controller)
		# Story 3-0c (AC 9): the REPLAY FORK. In replay mode the runner performs NO Area3D overlap
		# query and pushes NO live camera basis — it pushes the recorded bases and drains the
		# recorded facts for this tick instead, in recorded push order. Everything downstream
		# (advance, drive, follow, drain) is bit-for-bit the same code path, which is what makes
		# replay a source swap rather than a second simulation.
		#
		# Story 3-0d (`3-0d/R20`): the fork reads the PRIVATE `_replay_record`, consumed once in
		# _ready(). Assigning the PUBLIC member mid-session cannot flip this branch, cannot inject a
		# recorded reload/basis/fact into a live match, and cannot silently stop recording — the
		# three consequences `3-0d/R2` names — because this line does not read what it changed.
		if _replay_record != null:
			_replay_tick += 1
			_replay_record.replay_apply_reloads_before(_match_state, _replay_tick)
			_replay_record.replay_push_camera_bases(_match_state, _replay_tick)
			# Story 4-6 (AC 2): the LOCK-DIRECTION channel drains here, beside the bases and for
			# the identical reason -- it is derived from actor POSITIONS, and positions come from
			# move_and_slide() and may drift between a recording and its replay. A replay that
			# re-derived it from the live scene would diverge on the hashed `HeroState.facing` the
			# first time a hero stood a hair off where it stood before.
			_replay_record.replay_push_lock_directions(_match_state, _replay_tick)
			# Story 6-5b (AC 18): the DRAIN-TARGET channel drains here, beside the lock directions and
			# for the identical reason -- it is chosen from actor POSITIONS and a hero FACING, and
			# positions come from move_and_slide() and may drift between a recording and its replay. A
			# replay that re-derived it from the live scene would sacrifice a DIFFERENT minion than the
			# recorded match did, and diverge the hashed board from that tick onward.
			_replay_record.replay_push_drain_targets(_match_state, _replay_tick)
			_replay_record.replay_push_contacts(_match_state, _replay_tick)
		else:
			# 2. Gather spatial facts — each rig's basis, pushed PER SLOT (SEAM CHOICE 2: never one
			#    global basis). Reading the rig is the runner's ONLY interaction with it; the runner
			#    never rotates velocity after state resolves it (AC 6, story 1-2).
			#    LOCAL basis, deliberately not global (DECISION A): the rig is a child of the hero
			#    root, and the global basis would fold a hero-root rotation into "camera forward".
			#    Guarded by test/integration/test_root_rotation_isolation.gd.
			#    Story 3-0c (AC 8): TAPPED per slot per tick. Today the pushed basis is always
			#    identity in live play, but its value is read during movement resolution and
			#    reaches the HASHED HeroState.velocity — a replay that did not restore it could
			#    diverge the moment a look action ships (`3-0c/R2`).
			_recorder.capture_set_camera_basis(0, _p1_rig.basis)
			_match_state.set_camera_basis(0, _p1_rig.basis)
			_recorder.capture_set_camera_basis(1, _p2_rig.basis)
			_match_state.set_camera_basis(1, _p2_rig.basis)
			# Story 4-6 (AC 2, `4-6/R6`): the LOCK DIRECTION, pushed and tapped in the SAME seat
			# and the same order as the basis directly above -- the confirmed mechanism, a pushed
			# per-tick fact through the `set_camera_basis` / `push_contact` seam family, never a
			# live scene query from inside `src/state/`. Gathered at 1c above, where the rig yaw
			# that this basis now carries was written from the very same value.
			_recorder.capture_set_lock_direction(0, lock_dirs[0])
			_match_state.set_lock_direction(0, lock_dirs[0])
			_recorder.capture_set_lock_direction(1, lock_dirs[1])
			_match_state.set_lock_direction(1, lock_dirs[1])
			# Story 6-5b (AC 18, `6-5b/R6`): the DRAIN TARGET, gathered, tapped and pushed in this same
			# step-2 seat and the same per-slot order as the lock direction directly above -- the
			# confirmed mechanism for a position-derived fact entering state, never a scene read from
			# inside `src/state/`. Pushed EVERY ticking frame rather than only on a cast tick, for the
			# basis's own reason: a seat that fires conditionally on a press is a seat the record can be
			# missing a row for, and the one consumer (`_apply_drain`) reads the latch only when a Drain
			# actually resolves.
			for drain_slot: int in 2:
				var drain_target := _gather_drain_target(drain_slot,
						_match_state.p1 if drain_slot == 0 else _match_state.p2)
				_recorder.capture_push_drain_target(drain_slot, drain_target)
				_match_state.push_drain_target(drain_slot, drain_target)
			# Story 5-2 (AC 17, `5-2/R6`): the CHARGE-REACH fact, gathered and tapped in this
			# same step-2 seat and BEFORE advance() -- which is the whole of AC 17's ordering
			# requirement: state never pulls from the runner mid-advance(), so the fact the
			# step-3(a) landing check reads must already be in. It rides `push_contact` and the
			# existing contacts channel, so a replay restores it through
			# `replay_push_contacts` above with no new channel and no row-shape change.
			_push_charge_reach_facts()
			#    Story 1-7: contact facts — direct query on state-flagged-active hitboxes, pushed
			#    through push_contact, the SOLE intake (1-5 obligation). See _gather_contact_facts.
			# Story 4-3b (AC 5): THE CANONICAL CROSS-ATTACKER GATHER ORDER, and the unit pass's
			# FIXED SEAT relative to the two hero gathers, stated here at that seat as AC 5
			# requires. The order is SLOT ASCENDING, THEN BOARD INDEX ASCENDING -- the `4-2/R3`
			# tie-break this project already established for minion targeting -- and a hero's
			# address is `[slot, -1]`, so a slot's HERO precedes every unit on that slot's board
			# by the same comparison rather than by a convention stated twice.
			#
			# IT MATTERS BECAUSE DEFLECT SPENDS STAMINA PER FACT: with two minions landing on one
			# hero in one tick the first fact resolved is deflected and the second falls through to
			# blocked damage once the stamina runs out (the accepted `4-3b/R19` drain). Which minion
			# is which must not be decided by unpinned physics-query order.
			#
			# THE PROPERTY IS ALSO ENFORCED STATE-SIDE, and this seat is not what AC 5 rests on:
			# `MatchState._canonical_contact_order()` sorts the queue by the same total order before
			# resolving, so facts fed in ANY order resolve identically. Gathering canonically here
			# keeps the RECORD's own row order canonical too, and means a reader of this file sees
			# the intended order at the place it is produced.
			#
			# THE PROBE PASS RIDES ITS OWN THROTTLE, not this frame count -- see
			# `_gather_unit_reach_probes`. The counter advances once per TICKING frame, here, so the
			# cadence is measured in ticks rather than in frames the 3-0b pause gate skipped.
			#
			# ADVANCED BEFORE THE FIRST GATHER BELOW (review fix pass F3c, documented rather than
			# changed): `_gather_unit_facts` reads `_probe_counter % minion_retarget_interval_ticks
			# == 0` to decide whether THIS tick probes, and the increment above always runs first --
			# so the very first ticking frame reads 1, not 0, and never probes. A one-tick phase
			# shift with no functional consequence (the cadence still fires once every
			# `minion_retarget_interval_ticks`, merely starting one tick later than a reader counting
			# from zero would expect), named here so it does not read as an off-by-one.
			_probe_counter += 1
			_gather_contact_facts(0, _match_state.p1, _p1_hero)
			_gather_unit_facts(0, _match_state.p1)
			_gather_projectile_facts(0, _match_state.p1)
			_gather_contact_facts(1, _match_state.p2, _p2_hero)
			_gather_unit_facts(1, _match_state.p2)
			# Story 4-4 (AC 14): the PROJECTILE pass takes its seat INSIDE the canonical gather
			# order, after that slot's hero and units. `4-3b/R5`'s order is slot ascending then
			# attacker INDEX ascending, and a projectile's index is at or below -2 — so gathering
			# projectiles LAST within a slot does NOT match the sort order, and deliberately so: the
			# sort is enforced state-side by `_canonical_contact_order()`, which re-orders whatever
			# this seat produces, and reading hero-then-units-then-projectiles here follows the
			# order a reader thinks in rather than the order the comparator happens to yield. The
			# state-side sort is what AC 5 rests on; this seat only has to be deterministic.
			_gather_projectile_facts(1, _match_state.p2)
			# Story 3-0c (AC 2): the X5 intent tap. Seated HERE, immediately before advance(),
			# and NOT at the sample step the architecture doc's pre-code sketch draws it at
			# (`3-0c/R10` — that text is candidate design, not authority): 3-0b's pause gate
			# samples every frame but advances only on ticking ones, so a tap at the sample step
			# would record intents that no tick ever consumed and desync the stream from its own
			# tick indices. One capture, one advance, always in that order.
			# Story 4-6 (AC 11, `CC/R5`): RESOLVE each slot's click/flick into a `[slot, index]`
			# ADDRESS and stamp it onto that slot's intent -- IMMEDIATELY BEFORE the X5 tap, so
			# what the record carries is the OUTCOME of the gesture and never the raw stick
			# deflection. That ordering is the whole of AC 11's replay claim: a recorded flick
			# re-applies as the target it actually chose, not as a direction re-resolved against a
			# camera and a board arrangement that no longer exist.
			#
			# LIVE BRANCH ONLY. In replay the recorded intent ALREADY carries the resolved
			# address, and ReplayController's inherited neutral accessors would overwrite it with
			# "no request" if this ran there -- so the guard is structural (this is inside the
			# `else`), not a flag.
			_resolve_retarget(0, intents[0], _p1_controller)
			_resolve_retarget(1, intents[1], _p2_controller)
			_recorder.capture_advance(intents)
		# 3. Advance state (enqueues signals only).
		_match_state.advance(intents)
		# 3b. Story 3-0b (AC 2): POLL the read-only debug accessor right after advance() and push
		#     the plain-integer per-slot window countdown into the instrument panel. Debug
		#     instrumentation, NOT an eighth observation seam: no signal, no state handle, and
		#     to_snapshot() is untouched, so the replay contract never learns it exists.
		_instrument_panel.set_window_countdown(_match_state.debug_window_ticks_remaining())
		# 3a-bis. Story 6-1b: the charge-progress poll, same seat and shape as 3b directly above --
		#     a POLL right after advance(), no signal, no state handle, no new `connect_*` (AC 7).
		_push_charge_progress()
		# 3a-bis'. Story 7-10 (S1/S4): the unblockable EYES and the IMMUNITY shimmer, and the camera shakes'
		#     clocks -- the same seat and shape as 3a-bis directly above: plain reads after advance(), no signal,
		#     no state handle, no new `connect_*`.
		_push_unblockable_markers()
		# 3a-ter. Story 6-6b (AC 10/AC 11): the COUNTER presentation poll, the same seat and shape
		#     as 3a-bis directly above -- a read of the `defense` snapshot key right after advance(),
		#     no signal, no state handle, no new `connect_*`, so the observation-seam family stays at
		#     TEN (AC 14). It owns the dagger prop's whole life as well: spawned on the rising edge of
		#     a GREEN counter, advanced here, freed on arrival or on the falling edge.
		_push_counter_presentation()
		# 3a-quater. Story 6-5c (AC 25/AC 26/AC 28): the CAST presentation poll -- the same seat and
		#     shape as 3a-ter directly above, reading the `cast` and `root` facts right after
		#     advance(). It owns the bolt prop's whole life as well: spawned at the measured raise
		#     beat, advanced here, and landed on the tick the state layer strikes.
		_push_cast_presentation()
		# 3c. Story 4-1 (AC 7): SPAWN one grey-box actor per unit record the board has gained. Read
		#     off the state-owned COUNT right after advance(), the step-3b poll directly above in
		#     shape and seat: no signal, no state handle held, no new `connect_*` -- so the
		#     observation-seam family gains no member and needs no further amendment.
		#
		#     IDENTICAL LIVE AND REPLAY BY CONSTRUCTION (AC 10). This reads the board, not the
		#     effect map and not the cast: whatever put the record there -- a live cast resolving
		#     through CardEffectResolver, or the same cast re-resolving from a replayed intent
		#     against the record's own injected effects -- reaches this line the same way. There is
		#     no second spawn path to keep in agreement with the first.
		#
		#     GROWS ONLY. The board shrinks on exactly one path (the debug reset), and the actors
		#     are freed there by the round_started relay, so a shrink never has to be inferred from
		#     a count going down.
		_spawn_missing_unit_actors(0, _match_state.p1.units.size())
		_spawn_missing_unit_actors(1, _match_state.p2.units.size())
		# 3c-bis. Story 4-3a (AC 11, `4-3a/R13`): FREE the actor of any unit that died in the
		#     advance() directly above, leaving a HOLE at its index. Seated immediately after the
		#     spawn poll and before aim/approach, so a unit killed this tick is gone this tick and no
		#     later loop in this same frame drives a corpse. Same poll shape as 3b/3c/3d: plain board
		#     reads, no signal, no state handle, no new `connect_*`.
		_free_dead_unit_actors(0, _match_state.p1)
		_free_dead_unit_actors(1, _match_state.p2)
		# 3c-ter. Story 4-4 (AC 14/AC 18/AC 19): the PROJECTILE poll pair — spawn an actor for every
		#     record the board gained in the advance() above, then free the actor of every shot that
		#     advance() ended (consumed by a contact, or expired against its 60 m budget). Same poll
		#     shape and same seat family as 3b/3c/3c-bis/3d: plain board reads, no signal, no state
		#     handle, no new `connect_*`, so the observation-seam family gains no member.
		#
		#     SPAWN BEFORE FREE, and the order is load-bearing exactly as it is for units above: a
		#     shot fired and consumed inside one advance() — a totem firing point-blank into a
		#     hero's hurtbox — must still get an actor before that actor is freed, or the array
		#     would fall out of index-alignment with the board and every later shot would be driven
		#     as the wrong record.
		_spawn_missing_projectile_actors(0, _match_state.p1)
		_spawn_missing_projectile_actors(1, _match_state.p2)
		_free_dead_projectile_actors(0, _match_state.p1)
		_free_dead_projectile_actors(1, _match_state.p2)
		# 3d. Story 4-2 (`4-2/R13`): AIM each grey box at the target state acquired for it. PURELY
		#     PRESENTATIONAL, and it is the live smoke's whole visible signal — with movement out of
		#     scope (`4-2/R4`) a unit that never moves gives a human nothing to watch, so the box
		#     rotates instead.
		#
		#     THE SAME SEAT AND SHAPE AS 3b AND 3c DIRECTLY ABOVE: a POLL right after advance(), plain
		#     values only, no signal, no state handle held, no new `connect_*` — so the observation-seam
		#     family gains no member and needs no further amendment (`4-2/R15`'s own stated
		#     consequence). Nothing here decides a target; the decision was made inside advance() by
		#     TargetingService, and this reads the answer.
		#
		#     STATE DECIDES, PRESENTATION REACTS (the HARD RULE): the `[slot, index]` pair is a pair of
		#     plain ints, and turning it into a world position is done HERE, from node positions the
		#     runner already owns — no position ever travels inward (`4-2/R14` keeps position
		#     actor-owned).
		_aim_unit_actors(0, _match_state.p1)
		_aim_unit_actors(1, _match_state.p2)
		# 4. Drive actor movement — each actor reads HeroState.velocity, never the intent.
		#    Story 6-7b (AC 4): plus the AUTHORED walk/run speed pair, so the rig's animation
		#    controller can split the walk family from the run family on the pair's MIDPOINT. Read
		#    INLINE off `_match_state.balance` (CONSTRAINT C) -- the replay-aware handle 4a below
		#    explains, so a replay or a live RELOAD retunes the split with the movement it presents.
		#    Plain floats only; no config reference reaches the actor. A missing config (nothing
		#    applied yet) pushes a zero pair, whose zero midpoint degrades to the run family.
		var drive_balance := _match_state.balance
		var walk_speed := drive_balance.walk_speed if drive_balance != null else 0.0
		var run_speed := drive_balance.move_speed if drive_balance != null else 0.0
		_p1_hero.drive(_match_state.p1.hero, delta, walk_speed, run_speed)
		_p2_hero.drive(_match_state.p2.hero, delta, walk_speed, run_speed)
		# 4a. Story 4-3 (AC 1/AC 3, `4-3/R10`): WALK each grey box toward the target it acquired.
		#     THE DRIVE PHASE IS THE SEAT, deliberately not step 3d's `_aim_unit_actors` loop —
		#     `game-architecture.md:965-971` names this phase "drive actor movement
		#     (move_and_slide)", and this is a move. Merging the two loops would save one
		#     `_target_world_position` call per unit per frame and is filed in `deferred-work.md`;
		#     it is not taken here, because the phase a call sits in is the documented contract and
		#     an allocation-free lookup is the cheap half.
		#
		#     THE CONFIG IS READ INLINE, AT POINT OF USE, AND IT IS THE REPLAY-AWARE ONE
		#     (CONSTRAINT C, `4-3/R11`): `_match_state.balance` is whatever `apply_balance()` last
		#     received — the record's config during replay, the authored one live, and the freshly
		#     reloaded one after a live RELOAD press. `BalanceConfigService.get_config()` here would
		#     walk units at the AUTHORED speed during a replay of a recording made before a tuning
		#     pass, which is exactly the divergence `3-0c`'s AC 4 exists to prevent. Nothing caches
		#     it: not this file, and not a `UnitActor` field.
		_approach_unit_actors(0, _match_state.p1, delta)
		_approach_unit_actors(1, _match_state.p2, delta)
		# 4c. Story 4-4 (AC 15): STEER AND MOVE the live projectiles. The drive phase is the seat for
		#     the reason 4a states — `game-architecture.md` names this phase "drive actor movement",
		#     and this is a move. It takes no `delta`: a projectile advances by the state layer's own
		#     derived per-tick distance so the actor and the 60 m odometer stay one arithmetic, which
		#     an engine delta would immediately break.
		_drive_projectiles(0, _match_state.p1)
		_drive_projectiles(1, _match_state.p2)
	# 4b. Split-screen camera follow (story 2-1, ruling 2-1/R1). Copy each hero rig CAMERA's
	#     framed global transform onto its SubViewport follower camera — AFTER drive() so it
	#     reflects this tick's move_and_slide. Presentation-only: a deterministic function of
	#     the tick, snapshot-excluded, running INSIDE the one runner _physics_process (F1 holds —
	#     no viewport/camera/container carries its own _physics_process). Mirroring the rig's
	#     CHILD camera (not the rig root) carries the authored camera_config framing
	#     (distance/height/pitch) through to the half-width viewport, so AC4 reframing stays a
	#     single-source data/camera_config.tres edit — the follower needs no framing of its own,
	#     and its default projection matches the rig camera's (both plain Camera3D defaults).
	_p1_view_cam.global_transform = _p1_rig_cam.global_transform
	_p2_view_cam.global_transform = _p2_rig_cam.global_transform
	# Story 7-10 (AC 10): the counter's camera shake, on the FOLLOWERS only (never the rig -- DECISION A).
	_p1_view_cam.global_position += _shake_world_offset(0, _p1_view_cam)
	_p2_view_cam.global_position += _shake_world_offset(1, _p2_view_cam)
	# 4d. Story 4-6a (AC 13/AC 14): push each slot's LOCKED-TARGET MARKER position into that slot's
	#     own HUD -- a screen point, or null when the target is not visible in that viewport and the
	#     marker must hide. Same runner-polls-then-pushes-plain-values shape as the 3-5a card
	#     selection (step 1b) and the 3-0b window countdown (step 3b): no signal, no state handle,
	#     no new `connect_*`, so the observation-seam family gains no member.
	#
	#     SEATED AFTER 4b, NOT BESIDE 1b, and the ordering is the point: `_screen_position`
	#     unprojects through the SubViewport's FOLLOWER camera, and 4b is the line that gives that
	#     camera this tick's transform. Pushing above it would mark where the target was through
	#     last tick's camera -- one frame of lag on a cue whose whole job is to sit on the enemy.
	#
	#     OUTSIDE THE `ticking` GATE, like camera follow directly above and the card selection at
	#     1b: the operator must be able to look around while the 3-0b debug pause is held and still
	#     see what is locked. The lock ADDRESS is frozen while paused (advance() is what moves it),
	#     so this is a re-projection of an unchanged fact, never a state read that could drift.
	#
	#     PER-VIEWPORT BY CONSTRUCTION (AC 13): each `HudRoot` lives inside its own SubViewport
	#     (`hud_root.gd:4-6`) and is handed only its own slot's point, so P1's marker cannot render
	#     in P2's view. That is the `HudRoot`-owned branch of Open Question 3, taken precisely
	#     because it needs no cull-mask discipline on the two SubViewports that share one `World3D`.
	#
	#     Live-smoke micro-fix v2 (4-6a, operator smoke 2026-08-31, low-priority finding): HIDDEN
	#     outright while the round-over freeze holds (`MatchState.to_snapshot()`'s own `round_over`
	#     key, the one flag every state test already reads this way -- no new state accessor, no
	#     src/state/ edit). Unfrozen, a dead hero's corpse falls while this marker kept floating at
	#     its last live height, which reads as the marker pointing at nothing. `round_over` latches
	#     for the whole freeze and only `MatchState.reset()` clears it, so this cannot flicker mid-
	#     freeze -- it hides once, on the tick the round ends, same as the corpse starting to fall.
	var round_over: bool = bool(_match_state.to_snapshot().get("round_over", false))
	_huds[0].set_lock_marker(null if round_over else _lock_target_screen_position(0, _p1_view_cam))
	_huds[1].set_lock_marker(null if round_over else _lock_target_screen_position(1, _p2_view_cam))
	# Story 7-10 (AC 3): round end puts the unblockable eyes out, off the same `round_over` read -- a hero frozen
	# mid-charge by the round-over freeze shows no lit eyes.
	_p1_hero.eyes.set_suppressed(round_over)
	_p2_hero.eyes.set_suppressed(round_over)
	# 5. Drain queued signals AFTER advance returns (D5).
	_match_state.drain_signals()
	# 6. Story 7-1: the effect presentation reads that need the drain -- the shot endings (paired against the
	#    hits, deflects and Counterspells it announced, `7-1/R2`), the per-hero persistent looks and lifesteal
	#    droplets, and the end-of-tick copy of the reversal packets (`7-1/R3`). Plain reads, no new seam.
	#    Review fix F1: the raised-from spawns first, while this tick's Counterspell sources are still held.
	_resolve_raised_spawns()
	_resolve_ended_shots()
	_push_effect_presentation()
	_copy_reversal_records()
