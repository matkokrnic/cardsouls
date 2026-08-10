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
# _SEED survives as the RUNNER-SIDE SOURCE for MatchParams and nothing else (E3-RG/R9): the seed
# is match-scoped, injected once at construction, and never re-applied by apply_balance() — it
# does NOT belong in the hot-reloadable BalanceConfig, where a reload would re-seed the RNG
# mid-match and blow a determinism hole. It stays a constant here until a story needs a per-match
# seed source (a menu, a replay file).
const _SEED := 12345

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
var _replay_tick := 0

## Story 3-0b (AC 1): the match-global DEBUG step/pause reader — a NON-Controller member of
## src/controllers/ (see its own header). It is NOT one of the two slot controllers: it produces
## no InputIntent and its presses never reach advance(). Held here because D3(a) keeps Input.*
## out of this file while F1 keeps the tick gate in it.
var _debug_input := DebugInputReader.new()
var _paused := false

## Story 3-0b (AC 2): the ONE debug instrument panel, kept so the runner can push the polled
## window-countdown payload into it after each advance(). A Control reference, never a seam.
var _instrument_panel: DebugInstrumentPanel

## Story 3-5a (AC 10): the two per-viewport HUD roots, kept so the runner can push each slot's
## armed-card selection into its own root after sampling. A Control reference, never a seam —
## the DebugInstrumentPanel member directly above is the same pattern.
var _huds: Array[HudRoot] = []

## Story 4-1 (AC 7): the grey-box unit scene and the actors spawned from it, per slot. The SCENE
## REFERENCE LIVES HERE AND ONLY HERE -- src/state/ never holds one (UnitBoard is a pure
## RefCounted count), which is the HeroActor precedent: state decides that a unit EXISTS, the
## runner decides what that looks like and where it stands.
const UNIT_SCENE := preload("res://src/actors/minions/unit_actor.tscn")

## Spawned actors per slot, index-aligned with nothing in state -- the board is a COUNT, so the
## runner's own array length is the whole of the correspondence. Freed together off the
## round_started relay (AC 8).
var _unit_actors: Array[Array] = [[], []]

## Where a slot's grey-box units stand. Actor-owned position (`4-1/R12`), chosen by the runner:
## a row BEHIND each hero's spawn (P1 at x -3, P2 at x +3 in main.tscn) so a summoned unit is
## visible in that player's own viewport without standing in the fighting space between them.
## Legibility placement only -- no gameplay reads it, and 4-3 replaces it with real placement.
const UNIT_ROW_X: Array[float] = [-5.5, 5.5]
const UNIT_ROW_SPACING := 1.4
const UNIT_ROW_Z_START := -2.1


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
	# the runner constant otherwise. Never a second, independently-read seed: what is captured is
	# literally what reaches MatchParams.
	var seed_value := _replay_record.replay_seed() if replaying else _SEED
	if not replaying:
		_recorder.capture_seed(seed_value)
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
	# costs-before-deck would validate against an empty composition and pass vacuously. Replay
	# never reads CardDatabase: without this channel a recording would silently depend on the
	# contents of data/cards/, which change without a trace.
	if replaying:
		Invariant.check(_replay_record.replay_inject_content(_match_state),
			"recorded content order is unsound — the cast-cost totality check would be vacuous")
	else:
		var deck_contents := _derive_deck_contents(balance_config.deck_size)
		_recorder.capture_inject_deck(deck_contents)
		_match_state.inject_deck(deck_contents)
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
	# frozen seven-seam family (2-6/R7) is untouched. State owns the signal; the bus is the
	# runner's to reach.
	_match_state.reshuffle_vulnerable_window_opened.connect(
			_relay_reshuffle_vulnerable_window_opened)
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
	for slot: int in 2:
		var hud := HudRoot.new()
		# Story 3-6 (AC 4): the authored vulnerable-window duration, handed over BEFORE add_child
		# on the `gamepad_profile` / `huds` static-handoff precedent. The HUD renders the reshuffle
		# flag from the ownerless EventBus event plus this number and NOTHING else — it never reads
		# the window's tick count, which stays write-only unhashed state (3-5b/R20, 3-6/R3). Read
		# inline off the already-loaded authored config (CONSTRAINT C).
		hud.reshuffle_vulnerable_window_seconds = balance_config.reshuffle_vulnerable_window_seconds
		hud_viewports[slot].add_child(hud)
		huds.append(hud)
		connect_hero_hp_changed(slot, hud.on_hp_changed)
		connect_stamina_changed(slot, hud.on_stamina_changed)
		connect_mana_changed(slot, hud.on_mana_changed)
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
			hud.on_cards_changed(hand_ids, deck_count, discard_count,
					player.pending_draw_owed.duplicate()))
		EventBus.round_ended.connect(hud.on_round_ended.bind(slot))
		# Story 3-6 (AC 4): the reshuffle flag. BOTH viewports subscribe to the SAME ownerless bus
		# event (E3-RG/R3 — "this player's deck ran out" is a match-wide public fact), each binding
		# its OWN slot so it can render the event against itself: the round_ended wiring directly
		# below, second time. A plain bus connect, not a seam — the family stays at eight.
		EventBus.reshuffle_vulnerable_window_opened.connect(
				hud.on_reshuffle_vulnerable_window_opened.bind(slot))
		# Story 2-6 (AC 1): the label's single CLEAR seat — a debug reset hides it on BOTH
		# viewports. No-argument and slot-independent (the reset is ownerless), so no .bind(slot).
		EventBus.round_started.connect(hud.on_round_started)
	# Story 2-6 (AC 2): per-player debug StateInspector, one per SubViewport (the HudRoot
	# per-viewport pattern). READ-ONLY: wired to FIVE of the existing observation seams (no eighth),
	# each bound to its own slot; the three economy seams prime on connect so its bars render at once.
	for slot: int in 2:
		var inspector := StateInspector.new()
		hud_viewports[slot].add_child(inspector)
		connect_hero_action_state_changed(slot, inspector.on_action_state_changed)
		connect_hero_action_rejected(slot, inspector.on_action_rejected)
		connect_hero_hp_changed(slot, inspector.on_hp_changed)
		connect_stamina_changed(slot, inspector.on_stamina_changed)
		connect_mana_changed(slot, inspector.on_mana_changed)
	# Story 2-6 (AC 4/5): the ONE global debug instrument panel. Added as a top-level Control child
	# of the runner root so it renders over the whole window (both switches are window-global). It
	# flips only presentation/controller-local switches (2-6/R4): the magnitude switch mutates the
	# SHARED gamepad profile IN MEMORY (load() returns the resource-cache instance the gamepad
	# controllers also read — never persisted), the Pitch Zone A/B switch moves both viewports'
	# placeholder together via HudRoot.set_pitch_zone_placement.
	var panel := DebugInstrumentPanel.new()
	panel.gamepad_profile = load("res://data/gamepad_profile.tres") as GamepadProfile
	panel.huds = huds
	# Story 3-0d (AC 7, `3-0d/R13`): the panel's TWO runner-reaching controls — SAVE and RELOAD.
	# Each handed its own Callable before add_child, the gamepad_profile / huds precedent
	# generalised: the panel receives a way to ASK, never the recorder itself, never a state
	# handle and never the BalanceConfigService reference. No start control and no load control
	# ship (`3-0d/R1`, `3-0d/R2`), and no Input Map action is added — both are mouse-only, exactly
	# like the two switches beside them.
	panel.save_record = save_recorded_stream
	panel.reload_balance = trigger_live_balance_reload
	# Story 4-B1 (AC 2/AC 3, `4-B1/R1`): the panel's FIFTH control and its THIRD runner-reaching
	# seam, same Callable-handoff shape as the two directly above -- a read accessor, not a
	# push, so the panel calls it only from its own toggle handler.
	panel.reveal_opponent_hand = debug_hand_contents
	add_child(panel)
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
		connect_hero_action_state_changed(slot, cues.on_action_state_changed)
		connect_hero_action_rejected(slot, cues.on_action_rejected)
		connect_hit_landed(cues.on_hit_landed.bind(slot))
		connect_deflect_landed(cues.on_deflect_landed.bind(slot))
		EventBus.round_ended.connect(cues.on_round_ended.bind(slot))
		# Story 3-0a: the rig animation controller shares the action-state seam — the five
		# ActionState-driven clips (idle/attack/block/roll/death). The sixth, `run`, is NOT
		# wired here: HeroActor.drive() pushes it per-tick from velocity (3-0a/R2). Read-only,
		# no state handle, mirroring the telegraph wiring.
		connect_hero_action_state_changed(slot, actor.animation_controller.on_action_state_changed)


## Story 3-3 (AC 4): PROVISIONAL FIXTURE deck composition — walk CardDatabase's explicitly
## SORTED ids, take up to each card's `max_copies`, stop when deck_size is reached. Sorted-id
## order makes the result deterministic by construction: it can never depend on filesystem
## enumeration order, and adding a card changes the composition only in the way the data says.
## `max_copies` gains its FIRST consumer here.
##
## THIS IS NOT THE DECKBUILDING SEAT. Real deck selection is E4/E5 or later; this exists so the
## card system has a deck to draw from at all, and it lives in the RUNNER because it is the one
## place allowed to read CardDatabase (AC 2) — src/state/ may not so much as name it (AC 8).
##
## The library can be SMALLER than deck_size, in which case the walk simply stops when it runs
## out of copies; the shipped nine cards carry 24 authorable copies against a deck_size of 20.
## The genuinely broken case — an empty card set, e.g. a directory that degraded to empty under
## export remap — is caught loudly at the injection seam (AC 10), not swallowed here.
func _derive_deck_contents(deck_size: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CardDatabase.sorted_ids():
		var card := CardDatabase.get_card(id) as CardData
		if card == null:
			continue
		for _copy in card.max_copies:
			if out.size() >= deck_size:
				return out
			out.append(id)
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


## Story 3-0c (X5): the record this runner has captured so far. READ-ONLY ACCESS to a
## runner-owned plain object — NOT an eighth observation seam and deliberately not a `connect_`
## method (AC 13 pins that family at seven): no signal, no callback, no state handle. A replay is
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
	_match_state.apply_balance(config)


## Story 4-B1 (AC 2/AC 3, `4-B1/R1`): the DebugInstrumentPanel's READ ACCESSOR for both players'
## hand contents — a Callable the panel CALLS on demand (its own toggle handler), not a push seam
## and not a poll: no new `connect_*`, no per-tick call from `_physics_process`, and
## `test_runner_observation_seams_are_exactly_eight` is untouched (the seam family stays at eight).
## The same "hand the panel a way to ASK" shape as `save_recorded_stream` /
## `trigger_live_balance_reload` above, generalised from an action to a read.
##
## Read INLINE at call time (CONSTRAINT C) — both hands come straight off the live containers via
## their own `to_array()` copies, nothing is cached here or on the panel, and nothing here mutates
## state. Debug-only (`4-B1/R2`): this method's only caller is the panel's CheckButton handler,
## reachable by a manual mouse press alone — no Input Map action, no FeatureFlags read, and it
## never fires in the shipped default configuration unless the operator toggles it.
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


## Story 1-7 (AC 4.3): MatchState.round_ended -> EventBus.round_ended. Runner-owned
## because src/state/ never touches an autoload.
func _relay_round_ended(loser_index: int) -> void:
	EventBus.round_ended.emit(loser_index)


## Story 2-6 (AC 1, 2-6/R5): MatchState.round_started -> EventBus.round_started. Runner-owned
## for the same reason as _relay_round_ended: src/state/ never touches an autoload. No-argument
## — the reset is a whole-match event, not per-player.
func _relay_round_started() -> void:
	EventBus.round_started.emit()
	# Story 4-1 (AC 8): the DEBUG RESET clears each player's UnitBoard (MatchState._reset_player,
	# the one named exception to that function's "NOTHING else" contract), and the grey-box actors
	# go with it. Wired onto THIS EXISTING RELAY deliberately -- no new EventBus event and no new
	# observation seam ship for it, which is what AC 8 asks for. `_end_round` is untouched, so the
	# board survives the round-over freeze and only a reset clears it.
	_free_unit_actors()


## Story 4-1 (AC 7): bring slot `slot`'s spawned actors up to `count`. See the call site for why
## this only ever grows.
func _spawn_missing_unit_actors(slot: int, count: int) -> void:
	var actors: Array = _unit_actors[slot]
	while actors.size() < count:
		var unit := UNIT_SCENE.instantiate() as UnitActor
		add_child(unit)
		unit.global_position = Vector3(UNIT_ROW_X[slot],
				0.0, UNIT_ROW_Z_START + UNIT_ROW_SPACING * actors.size())
		actors.append(unit)


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
func _free_dead_unit_actors(slot: int, player: PlayerState) -> void:
	var actors: Array = _unit_actors[slot]
	for index: int in actors.size():
		if player.units.is_alive_at(index):
			continue
		var unit: Node = actors[index]
		if not is_instance_valid(unit):
			continue
		unit.queue_free()
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
			continue
		var target_index := player.units.target_index_at(index)
		var target_position: Variant = _target_world_position(target_slot, target_index)
		if target_position is Vector3:
			(unit as UnitActor).approach(target_position, balance.unit_move_speed,
					balance.unit_stop_distance, delta)


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


## Story 3-5b (AC 6): MatchState.reshuffle_vulnerable_window_opened ->
## EventBus.reshuffle_vulnerable_window_opened. The two relays above, third time — runner-owned
## because src/state/ never touches an autoload, and a plain relay rather than a connect_ seam
## because the payload is a match-wide public fact carrying its own slot.
func _relay_reshuffle_vulnerable_window_opened(slot: int) -> void:
	EventBus.reshuffle_vulnerable_window_opened.emit(slot)


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
		_recorder.capture_push_contact(attacker_slot, address, attack_index, fact_dir)
		_match_state.push_contact(attacker_slot, address, attack_index, fact_dir)


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


func _physics_process(delta: float) -> void:
	# 0. Story 3-0b (AC 1): the DEBUG step/pause gate. Read through the controller-layer
	#    DebugInputReader (D3(a) — Input.* may not appear in this file), never as an intent:
	#    these presses do not enter InputIntent, the recorded intent stream, or advance(). Pause
	#    must survive the ABSENCE of ticking, which an intent consumed inside advance() cannot —
	#    the deliberate divergence from the intent-carried debug_reset. Both reads are EDGES, so
	#    a held key neither re-toggles the pause nor auto-fires steps: one tick per press.
	if _debug_input.pause_pressed():
		_paused = not _paused
	var ticking := not _paused or _debug_input.step_pressed()
	# 1. Sample controllers -> InputIntent per player (the ONLY place Input is read — D3).
	#    Sampled every frame, paused or not: sampling is not one of the three things AC 1
	#    freezes, and Godot's just-pressed edges are frame-scoped either way.
	var intents: Array[InputIntent] = [_p1_controller.sample(), _p2_controller.sample()]
	# 1b. Story 3-5a (AC 10): push each slot's ARMED CARD into its own HUD. Read off the
	#     CONTROLLER, not off state — the indicator shows what the player has SELECTED, which is
	#     a controller fact that never enters the tick or the snapshot. Same
	#     runner-polls-then-pushes-plain-values shape as the 3-0b window countdown (step 3b), so
	#     this is not an eighth observation seam: no signal, no state handle, plain ints only.
	#     OUTSIDE the `ticking` gate deliberately — the selection must stay visible and
	#     responsive while the debug pause is held, exactly as camera follow (4b) does.
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
			#    Story 1-7: contact facts — direct query on state-flagged-active hitboxes, pushed
			#    through push_contact, the SOLE intake (1-5 obligation). See _gather_contact_facts.
			_gather_contact_facts(0, _match_state.p1, _p1_hero)
			_gather_contact_facts(1, _match_state.p2, _p2_hero)
			# Story 3-0c (AC 2): the X5 intent tap. Seated HERE, immediately before advance(),
			# and NOT at the sample step the architecture doc's pre-code sketch draws it at
			# (`3-0c/R10` — that text is candidate design, not authority): 3-0b's pause gate
			# samples every frame but advances only on ticking ones, so a tap at the sample step
			# would record intents that no tick ever consumed and desync the stream from its own
			# tick indices. One capture, one advance, always in that order.
			_recorder.capture_advance(intents)
		# 3. Advance state (enqueues signals only).
		_match_state.advance(intents)
		# 3b. Story 3-0b (AC 2): POLL the read-only debug accessor right after advance() and push
		#     the plain-integer per-slot window countdown into the instrument panel. Debug
		#     instrumentation, NOT an eighth observation seam: no signal, no state handle, and
		#     to_snapshot() is untouched, so the replay contract never learns it exists.
		_instrument_panel.set_window_countdown(_match_state.debug_window_ticks_remaining())
		# 3c. Story 4-1 (AC 7): SPAWN one grey-box actor per unit record the board has gained. Read
		#     off the state-owned COUNT right after advance(), the step-3b poll directly above in
		#     shape and seat: no signal, no state handle held, no new `connect_*` -- so the
		#     observation-seam family stays at EIGHT and needs no 3-6/R2-style amendment.
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
		# 3d. Story 4-2 (`4-2/R13`): AIM each grey box at the target state acquired for it. PURELY
		#     PRESENTATIONAL, and it is the live smoke's whole visible signal — with movement out of
		#     scope (`4-2/R4`) a unit that never moves gives a human nothing to watch, so the box
		#     rotates instead.
		#
		#     THE SAME SEAT AND SHAPE AS 3b AND 3c DIRECTLY ABOVE: a POLL right after advance(), plain
		#     values only, no signal, no state handle held, no new `connect_*` — so the observation-seam
		#     family stays at EIGHT and needs no `3-6/R2`-style amendment (`4-2/R15`'s own stated
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
		_p1_hero.drive(_match_state.p1.hero, delta)
		_p2_hero.drive(_match_state.p2.hero, delta)
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
	# 5. Drain queued signals AFTER advance returns (D5).
	_match_state.drain_signals()
