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
## swaps slot 1 NULL -> KEYBOARD_P2, E7 -> a scripted kind — a one-line change, never a
## hero/actor/state edit (dummy identity is a controller choice, arch amendment A3). P2
## DEFAULTS to NULL (the training dummy, story 1-6); the second slot itself has existed and
## been driven since E0 — this story SWAPS its driver, it does not add a slot.
enum ControllerKind { KEYBOARD_P1, KEYBOARD_P2, NULL }

@export var slot_controller_kinds: Array[ControllerKind] = [
	ControllerKind.KEYBOARD_P1,  # slot 0 — P1 (local keyboard)
	ControllerKind.NULL,         # slot 1 — P2 (training dummy; 2-3 -> KEYBOARD_P2)
]

@onready var _p1_hero: HeroActor = $P1Hero
@onready var _p2_hero: HeroActor = $P2Hero
@onready var _p1_rig: CameraRig = $P1Hero/CameraRig
@onready var _p2_rig: CameraRig = $P2Hero/CameraRig

var _match_state: MatchState
var _p1_controller: Controller
var _p2_controller: Controller


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
	_p1_controller = _make_controller(slot_controller_kinds[0])
	_p2_controller = _make_controller(slot_controller_kinds[1])
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
	# Story 1-3c: throwaway debug overlay (see its FENCE — E2 replaces it with the real
	# HUD). Wired through the public seams below like any consumer; it receives signal
	# payloads only, never a state handle.
	var overlay := DebugStateOverlay.new()
	add_child(overlay)
	connect_hero_action_state_changed(0, overlay.on_hero_transition.bind(0))
	connect_hero_action_state_changed(1, overlay.on_hero_transition.bind(1))
	# Story 1-7 (AC 3): the overlay is hit_landed's FIRST consumer — still throwaway.
	connect_hit_landed(overlay.on_hit_landed)
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


## Story 1-6 (AC 2): map a configured slot kind to a concrete Controller — the ONE place a
## kind becomes an instance. Extended (never branched around) by 2-2/2-3 (gamepad / second
## keyboard) and E7 (scripted). NullController is the training-dummy driver.
func _make_controller(kind: ControllerKind) -> Controller:
	match kind:
		ControllerKind.KEYBOARD_P1:
			return KeyboardController.new(&"p1")
		ControllerKind.KEYBOARD_P2:
			return KeyboardController.new(&"p2")
		ControllerKind.NULL:
			return NullController.new()
	Invariant.check(false, "unknown controller kind: %d" % kind)
	return NullController.new()


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
	# 1. Sample controllers -> InputIntent per player (the ONLY place Input is read — D3).
	var intents: Array[InputIntent] = [_p1_controller.sample(), _p2_controller.sample()]
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
	# 4. Drive actor movement — each actor reads HeroState.velocity, never the intent.
	_p1_hero.drive(_match_state.p1.hero, delta)
	_p2_hero.drive(_match_state.p2.hero, delta)
	# 5. Drain queued signals AFTER advance returns (D5).
	_match_state.drain_signals()
