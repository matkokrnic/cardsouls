extends Node3D

## E0 Match Runner (D2). The ONE _physics_process in the project (INVARIANT F1). It OWNS the
## single MatchState (no autoload for live state), advances it in a fixed intra-tick order, and
## drives the hero actors from state. References are wired explicitly at match start.
##
## Tick order (D2 / F1): sample controllers -> gather spatial facts -> advance(intents) ->
## drive actor movement (move_and_slide, inside the actor) -> drain signals.

# E0 placeholders. These are the injection point: E3 folds them into an injected BalanceConfig
# object (see game-architecture.md "Planned (E3) — MatchState config object"). Not authored as
# .tres yet, so they live here as clearly-marked interim constants, tunable in one place.
const _SEED := 12345
const _MAX_HP := 100.0
const _MOVE_SPEED := 5.0
const _MAX_STAMINA := 50.0
const _MAX_MANA := 80.0

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

## Story 3-0b (AC 1): the match-global DEBUG step/pause reader — a NON-Controller member of
## src/controllers/ (see its own header). It is NOT one of the two slot controllers: it produces
## no InputIntent and its presses never reach advance(). Held here because D3(a) keeps Input.*
## out of this file while F1 keeps the tick gate in it.
var _debug_input := DebugInputReader.new()
var _paused := false

## Story 3-0b (AC 2): the ONE debug instrument panel, kept so the runner can push the polled
## window-countdown payload into it after each advance(). A Control reference, never a seam.
var _instrument_panel: DebugInstrumentPanel


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
	_p1_controller = _make_controller(slot_controller_kinds[0], 0)
	_p2_controller = _make_controller(slot_controller_kinds[1], 1)
	_match_state = MatchState.new(_SEED, _MAX_HP, _MOVE_SPEED, _MAX_STAMINA, _MAX_MANA)
	# DEBT A retirement (story 1-3b): inject the authored balance ONCE at match start,
	# before the first tick — advance() reads balance_ticks, so without this call live-play
	# actions are inert (MatchState's balance_ticks == null guard, kept as a permanent
	# invariant). apply_balance partially overwrites the constructor placeholders above
	# (the mana CAP stays constructor-driven — BalanceConfig has no max_mana field);
	# story 3-1 folds the constants into the config object. Mid-match reload stays DEBT B
	# (deferred).
	var balance_config: BalanceConfig = BalanceConfigService.get_config()
	Invariant.check(balance_config != null, "authored balance config missing at match start")
	_match_state.apply_balance(balance_config)
	# Story 1-5 (B3): read FeatureFlagsService ONCE at match start and inject — the ONLY
	# place state receives flags (HARD RULE: state never reads the service). Flags are
	# load-once by design: no reload path, deliberately unlike balance.
	var feature_flags: FeatureFlags = FeatureFlagsService.get_flags()
	Invariant.check(feature_flags != null, "authored feature flags missing at match start")
	_match_state.inject_feature_flags(feature_flags)
	# Story 1-7 (AC 4.3): relay MatchState's round_ended onto the global EventBus — the
	# one genuinely ownerless event. The relay lives in the RUNNER because state never
	# touches an autoload; the source signal is queued (D5), so the bus emission happens
	# at drain time, post-advance.
	_match_state.round_ended.connect(_relay_round_ended)
	# Story 2-6 (AC 1, 2-6/R5): relay the reset counterpart exactly the same way — directly in
	# _ready(), no new per-slot connect_ seam. State never touches an autoload, so the runner is
	# the one seat that bridges MatchState.round_started onto the ownerless EventBus.
	_match_state.round_started.connect(_relay_round_started)
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
		hud_viewports[slot].add_child(hud)
		huds.append(hud)
		connect_hero_hp_changed(slot, hud.on_hp_changed)
		connect_stamina_changed(slot, hud.on_stamina_changed)
		connect_mana_changed(slot, hud.on_mana_changed)
		EventBus.round_ended.connect(hud.on_round_ended.bind(slot))
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
	add_child(panel)
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
		var target_slot := _slot_of(owner_actor)
		if target_slot == -1:
			continue  # not a hero hurtbox; nothing else carries the hurtbox layer in E1
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
		_match_state.push_contact(attacker_slot, target_slot, attack_index, dir.normalized())


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
		# 2. Gather spatial facts — each rig's basis, pushed PER SLOT (SEAM CHOICE 2: never one
		#    global basis). Reading the rig is the runner's ONLY interaction with it; the runner
		#    never rotates velocity after state resolves it (AC 6, story 1-2).
		#    LOCAL basis, deliberately not global (DECISION A): the rig is a child of the hero
		#    root, and the global basis would fold a hero-root rotation into "camera forward".
		#    Guarded by test/integration/test_root_rotation_isolation.gd.
		_match_state.set_camera_basis(0, _p1_rig.basis)
		_match_state.set_camera_basis(1, _p2_rig.basis)
		#    Story 1-7: contact facts — direct query on state-flagged-active hitboxes, pushed
		#    through push_contact, the SOLE intake (1-5 obligation). See _gather_contact_facts.
		_gather_contact_facts(0, _match_state.p1, _p1_hero)
		_gather_contact_facts(1, _match_state.p2, _p2_hero)
		# 3. Advance state (enqueues signals only).
		_match_state.advance(intents)
		# 3b. Story 3-0b (AC 2): POLL the read-only debug accessor right after advance() and push
		#     the plain-integer per-slot window countdown into the instrument panel. Debug
		#     instrumentation, NOT an eighth observation seam: no signal, no state handle, and
		#     to_snapshot() is untouched, so the replay contract never learns it exists.
		_instrument_panel.set_window_countdown(_match_state.debug_window_ticks_remaining())
		# 4. Drive actor movement — each actor reads HeroState.velocity, never the intent.
		_p1_hero.drive(_match_state.p1.hero, delta)
		_p2_hero.drive(_match_state.p2.hero, delta)
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
