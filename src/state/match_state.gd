class_name MatchState
extends RefCounted

## D1/D2 root of the pure state layer. Owns the two PlayerStates, the reserved PitchState,
## the shared SignalQueue, and the single seeded gameplay RNG (F2). Pure RefCounted — no
## scene, no Input, no autoload, no wall-clock. The runner owns THIS object (no autoload
## for live state) and is the only thing that calls advance()/drain_signals().
##
## D2: advance(intents) is the ONE ordered call site that advances gameplay time. It only
## ENQUEUES signals; the runner drains them after it returns (D5).

## Owned by MatchState, relayed to the EventBus autoload by the runner (state never touches
## an autoload). loser_index: 0 = P1, 1 = P2. Re-arms when the debug reset clears the
## round latch (story 1-7, D-1): fires once per DEATH, not once per match.
signal round_ended(loser_index: int)

## Story 2-6 (AC 1, 2-6/R5/R6): the RESET counterpart to round_ended — a no-argument, ownerless
## round-lifecycle event (a debug reset is a whole-match event, not per-player, the round_ended
## analogy inverted). Pushed QUEUED and UNCONDITIONALLY by _apply_debug_reset() on EVERY debug
## reset (D5), relayed by the runner to EventBus.round_started exactly the way round_ended is.
## The single CLEAR trigger for the round-over label (HudRoot.on_round_started); round_ended
## stays the single SET. No prime-on-connect: a HUD consumer must receive an actual reset event.
signal round_started()

## Story 1-7 (N1): MatchState-owned two-player event (the round_ended analogy — a hit has
## an attacker AND a target, so it is not per-hero). Queued in step 4 when a contact is
## CONFIRMED, drained by the runner after advance() (D5). target_hp is the target's
## REMAINING HP after the damage. Consumers subscribe through the runner seam
## (match_runner.connect_hit_landed) and never hold a MatchState handle.
signal hit_landed(attacker_slot: int, target_slot: int, damage: float, target_hp: float)

## Story 1-8 (R-D4): MatchState-owned two-player event (the hit_landed precedent — a
## deflect has an attacker AND a target). Queued in step 4 when a contact resolves as a
## DEFLECT (fully negated: no damage, no hit_landed, no mana), drained by the runner
## after advance() (D5). NO runner connect seam in 1-8 — the FIRST consumer (1-10
## CombatCues) inherits the seam obligation, the action_rejected precedent.
signal deflect_landed(attacker_slot: int, target_slot: int)

## Story 3-5a (AC 5): a Mode ① cast RESOLVED — queued in step 6 after the mana is spent, the
## card has left the hand for the discard, and the replacement has been drawn. Payload is the
## casting slot and the card that resolved.
##
## DELIBERATELY UNCONSUMED IN E3, and that is the correct state rather than a gap: the story's
## Dev Notes rule that "a resolved cast queuing an unconsumed signal is the correct E3 state; a
## fake placeholder actor is not". Nothing binds it — there is NO runner connect_ seam and no
## presentation consumer — so the seven locked observation seams are still seven and this is
## NOT an eighth. The FIRST consumer inherits the seam obligation, exactly as action_rejected
## (1-4 -> 1-10) and deflect_landed (1-8 -> 1-10) each did.
##
## CARRIES THE CARD ID, NOT A CardEffect. The injected map is COSTS (AC 4), so the state layer
## never receives a card's effect content and cannot emit it without a second injected map
## built for a signal that has no listener — speculative machinery of exactly the kind the
## pose_id retirement precedent exists to prevent. A consumer that needs the effect resolves
## `id -> CardEffect` on the presentation side, where CardDatabase is already readable.
signal card_cast_resolved(slot: int, card_id: StringName)

## Story 3-5b (AC 6): a player's discard has just been folded back into their deck and they are
## VULNERABLE for the authored window. Queued in step 6 at the reshuffle, drained by the runner
## after advance() (D5) and RELAYED onto the ownerless EventBus — the round_started /
## round_ended mechanism exactly (E3-RG/R3), because "this player's deck ran out" is a match-wide
## public fact rather than a per-entity state change.
##
## NOT AN EIGHTH OBSERVATION SEAM. The frozen family (2-6/R7) is per-slot CONNECT-seam
## observation and stays at SEVEN connect_* methods on the runner; this rides the bus, where
## round_started and round_ended already live, and the runner bridges it in _ready() with a plain
## relay and no new seam. The payload is the vulnerable player's SLOT INDEX and nothing else —
## no card, no count, no window handle.
signal reshuffle_vulnerable_window_opened(slot: int)

var p1: PlayerState
var p2: PlayerState
var pitch: PitchState        # reserved fizzle-deadline owner (D8), machinery in E6

## Injected via apply_balance() (story 1-1). `balance` holds the non-duration authored
## values; `balance_ticks` holds every `*_seconds` field pre-converted to integer ticks —
## the ONLY form in which those durations may be read inside advance() (A1).
var balance: BalanceConfig
var balance_ticks: BalanceTicks

## Story 1-5 (B3): the injected FeatureFlags — the first flag consumer in state. The
## runner reads FeatureFlagsService ONCE at match start and injects here; state NEVER
## reads the service (HARD RULE). Load-once, no reload path — deliberately unlike
## balance. EXCLUDED from to_snapshot(): flags are CONFIG, not state (the 1-2
## camera-basis analog), so the golden hash never depends on the flag object. Null
## (pre-injection, most headless tests) closes every flag-gated path — inert, like the
## balance null guards.
var flags: FeatureFlags

var _queue: SignalQueue
var _rng: RandomNumberGenerator  # the ONLY randomness source in the state layer (F2/A2)
var _tick := 0
var _round_over := false

## Per-slot camera basis (story 1-2) — an input-like PUSHED spatial fact, same category as
## InputIntent: the runner reads each rig and pushes it here in step 2. Fixed two-slot
## array, one per player — NEVER a single global basis (SEAM CHOICE 2: split-screen stays a
## config change). EXCLUDED from to_snapshot() like the intent stream; while the camera is
## fixed (all of E1) the basis is deterministic, so X5 replay is unaffected. Defaults to
## identity: with no basis pushed (tick 0, headless tests) move_dir is world-space (AC 4).
var _camera_bases: Array[Basis] = [Basis.IDENTITY, Basis.IDENTITY]

## Story 1-5 (B7): queued contact facts, drained deterministically in advance() step 4.
## Input-like PUSHED facts, same category as InputIntent and the camera basis: plain
## recordable data (three ints per fact — X5 replay records them alongside intents; the
## actual recording is RE-HOMED to the story that lands IntentRecorder, 1-7 gate D-4;
## this seam's only obligation is staying recordable), EXCLUDED from to_snapshot()
## like the intent stream. In live play the runner pushes facts in frame step 2, so they
## reflect tick N-1's post-movement physics flush (F1 one-tick lag — absorbed by the
## dedupe grace tick, see HeroState._swing_dedupe).
var _contact_queue: Array[Dictionary] = []

## Story 3-3 (AC 2): the injected deck COMPOSITION — plain StringName ids, retained so the
## step-6 deal seat can lay a fresh pile down on BOTH of its occasions (match start and debug
## reset) without a discard pile to recover cards from. EXCLUDED from to_snapshot() for the
## same reason `flags` is: this is injected CONTENT, not state (the snapshot carries COUNTS
## only, AC 5). NEW OBLIGATION for the intent-recorder story (3-0c): this composition must
## enter the replay record alongside seed and intents, or a replay silently depends on the
## contents of data/cards/, which change without a trace.
var _deck_contents: Array[StringName] = []

## Story 3-3 (AC 7/AC 9): the one-shot latch that arms the step-6 deal. Set by the injection
## seam (match start) and re-set by _apply_debug_reset(); cleared when the seat actually runs.
## EXCLUDED from to_snapshot(): it is consumed inside the same advance() that armed it whenever
## balance is present, and it is derivable from the replay record (seed + injection + intents)
## in the one case where it is not.
var _deck_deal_pending := false

## Story 3-5a (AC 4): the injected per-card CAST COSTS, id -> CardCastCondition. ONE MATCH-WIDE
## MAP, not a per-player pair: 3-3 locked that both players receive the same injected
## composition through one seam, so a per-player cost map would be two copies of one fact.
## Asymmetric decks (and with them asymmetric costs) arrive with real deckbuilding in E4/E5+;
## until then this shape is an INHERITED CONSEQUENCE, not a defect.
##
## EXCLUDED FROM to_snapshot(), by the _deck_contents / _deck_deal_pending precedent: this is
## injected CONTENT, not evolving state, and it never changes after match start. That exclusion
## is also what makes its StringName KEYS safe. Keys of this kind must NEVER reach the snapshot:
## CanonicalHash sorts dictionary keys, and Array[StringName].sort() was MEASURED on this engine
## (4.6.3) to order by INTERNAL POINTER rather than lexicographically — deterministic within one
## process, NOT across runs or builds. Both determinism tests run in a single process, so a
## StringName key inside the hash would pass green while replay was already broken and no guard
## in the suite would catch it.
##
## NEW OBLIGATION for the intent-recorder story (3-0c), the twin of the one _deck_contents
## already carries: this map must enter the replay record alongside seed, intents and the
## injected composition, or a replay silently depends on the contents of data/cards/.
var _card_costs: Dictionary[StringName, CardCastCondition] = {}


## Story 3-1 (AC 1/AC 3): construction takes ONE match-scoped params object and nothing
## else. The five positional floats are gone — max_hp, move_speed, max_stamina and max_mana
## now arrive ONLY through apply_balance() (BalanceConfig is their single source of truth),
## and the seed arrives here, once, never re-applied. Both players are therefore constructed
## STAT-LESS (AC 5 / 3-1/R3): a MatchState that never received apply_balance() has zeroed
## bounds and is inert — no regen, no contact resolution, no round end.
func _init(params: MatchParams) -> void:
	_queue = SignalQueue.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = params.seed_value
	p1 = PlayerState.new(_queue)
	p2 = PlayerState.new(_queue)
	pitch = PitchState.new()


## The single ordered dispatch (D2). intents = [p1_intent, p2_intent]. Enqueues signals
## only — never emits. Player order is fixed P1 -> P2 for determinism.
func advance(intents: Array[InputIntent]) -> void:
	var p1_intent := intents[0]
	var p2_intent := intents[1]
	_tick += 1

	# 1. Ingest intents        debug reset only (story 1-7, D-2): intent-carried so the
	#    mutation stays inside the ordered dispatch (D2) and rides the recorded intent
	#    stream for free once the X5 recorder lands. Attack/block/roll presses are still
	#    read directly by the step-3 transition evaluation.
	if p1_intent.debug_reset or p2_intent.debug_reset:
		_apply_debug_reset()
	# 1b. Round-over freeze (story 2-6, AC 1, 2-6/R6 — the 2-3/R10 named gap's owner): once the
	#    round is over, HALT both heroes and return, skipping steps 2 through 8 for this tick, so
	#    the surviving hero stops moving instead of gliding on. Seated AFTER step 1 (reset
	#    ingestion), NEVER hoisted ahead of it (the R6 ordering): a debug reset landing on the SAME
	#    tick the round is frozen cleared _round_over just above, so movement resolution resumes
	#    THAT tick, not one tick later. _tick already incremented at the top, so frozen ticks still
	#    advance the counter — a reset landing on tick N stays deterministic.
	#    Velocity is zeroed on EVERY frozen tick (2-6 operator ruling, close-out micro-decision):
	#    the runner reads HeroState.velocity into move_and_slide() every physics frame regardless
	#    of this early return, so a skipped write would leave the corpse (or any hero moving at the
	#    kill instant) sliding at its last live speed forever — exactly the 2-3/R14 residual, now
	#    honoured HERE instead of the step-3 DEAD branch. This is the standing 2-3 asymmetry rule
	#    applied unchanged: a field read downstream must be WRITTEN, a display-only field may be
	#    SKIPPED, so facing is left untouched and its last value persists (2-3/R14). The 2-3/R13
	#    one-tick carry is intact: on the KILL tick movement resolves at step 3 and DEAD is set at
	#    step 8, so the freeze only begins the NEXT tick — the corpse still carries its final
	#    velocity for exactly that one tick before step 1b zeroes it. Golden CANNOT prove this: the
	#    recorded sequence never reaches a round-over (story Dev Notes / test_determinism).
	if _round_over:
		p1.hero.velocity = Vector3.ZERO
		p2.hero.velocity = Vector3.ZERO
		return
	# 2. Advance D4 timers   (hero windows + each pool's regen-delay window — every window
	#    advances here, step 5 reads the result; unguarded like the hero timers, since a
	#    pre-injection MatchState never started a delay window)
	p1.hero.tick_timers()
	p2.hero.tick_timers()
	p1.stamina.tick_timers()
	p2.stamina.tick_timers()
	# Story 3-5b (AC 3/AC 8): the pending-draw window and its vulnerable-window sibling advance
	# HERE, beside every other D4 timer, and step 6 reads the result — the StaminaPool
	# _regen_delay idiom verbatim (ticked at step 2, consumed at step 5). Seating the tick here
	# buys AC 8's frozen-tick contract for FREE: step 1b returns above, so a round-over tick
	# never reaches this line and no window advances during the freeze. Unguarded like its
	# neighbours — a pre-injection MatchState never started either window.
	p1.pending_draw.tick()
	p2.pending_draw.tick()
	p1.vulnerable_window.tick()
	p2.vulnerable_window.tick()
	# 3. Resolve actions       per slot P1 -> P2: action transitions FIRST (a press on
	#    tick N takes effect on tick N), then intended velocity from move_dir. Transitions
	#    never write velocity — both halves of the 1-3 coupling deferral now live in
	#    _resolve_movement (1-5 attack commitment; 1-9 roll override reading the
	#    entry-locked roll_direction, captured here in step 3 at the ROLLING transition).
	_resolve_actions(p1, p1_intent, 0)
	_resolve_movement(p1, p1_intent, 0)
	_resolve_actions(p2, p2_intent, 1)
	_resolve_movement(p2, p2_intent, 1)
	# 4. Resolve contacts      (story 1-5) drain the queued facts in push order: dedupe/
	#    liveness acceptance -> damage -> record confirmed hits for step 5. Damage and
	#    dedupe ONLY here — mana is step 5's seat, keeping the documented D2 order
	#    truthful (N4).
	var confirmed_hits := _resolve_contacts()
	# 5. Resource generation   stamina regen (story 1-4) then mana — melee-hit AND the
	#    passive tick (story 3-4), P1 -> P2. Stamina is still DIRECT; mana is now the D6
	#    EVALUATOR path (DEBT D's extraction, re-triggered at E3 exactly as the 1-5
	#    resolution said it would be): _generate_mana asks EconomyEvaluator for each
	#    authored rule's amount and applies it to the pool. Same single null guard rationale
	#    as step 3: a pre-injection MatchState stays inert, no scattered checks below.
	if balance_ticks != null:
		_regen_stamina(p1)
		_regen_stamina(p2)
		_generate_mana(confirmed_hits)
	# 6. Card / economy        the DECK DEAL seat (story 3-3, AC 7/AC 9) — the ONE seat, serving
	#    BOTH occasions: match start (armed by the injection seam) and the debug reset (armed at
	#    step 1 THIS tick, so a reset's reshuffle lands on the reset tick, not one later). Seated
	#    HERE rather than in inject_deck() so "the seeded RNG is consumed only inside advance()"
	#    stays provable (F2) — and because the debug reset is an intent in the recorded stream,
	#    the reset-time reshuffle is replay-safe for free.
	#    [E3 card play/draw — 3-5; E6 pitch resolution]
	#    Story 3-5a (AC 2/AC 9): the CAST dispatch shares this one seat, seated AFTER the deal so
	#    a cast committed on the very first tick has a hand to cast FROM. Card actions are READ
	#    HERE, never ingested at step 1 (step 1 ingests the debug reset and nothing else) —
	#    matching the E2-CO/R3 precedent already applied to move_dir/attack/block/roll. Fixed
	#    P1 -> P2 order, like every other per-player loop in this function.
	_deal_pending_decks()
	_resolve_card_action(p1, p1_intent, 0)
	_resolve_card_action(p2, p2_intent, 1)
	#    Story 3-5b (AC 3/AC 5): the PENDING-DRAW DELIVERY, third and last in this one seat, and
	#    the ordering is load-bearing in both directions. AFTER the cast dispatch, because a
	#    derived delay of ZERO ticks must still refill on the cast tick (TimingWindow.start(0)
	#    leaves is_running false, so the delivery below fires immediately) — that is what makes a
	#    zero delay degrade EXACTLY to 3-5a's instant refill instead of arriving one tick late,
	#    and it is what lets the golden isolate the delay's SEAT from its authored CONTENT.
	#    INSIDE step 6, because a delivery may need to reshuffle, and the reshuffle must consume
	#    the seeded RNG in the SAME seat _deal_pending_decks() already occupies — F2 ("the seeded
	#    RNG is consumed only inside advance()") stays provable by inspection, and machine-checked
	#    since AC 16. A naive "tick and draw together at step 2" would have opened a second seat.
	_deliver_pending_draw(p1, 0)
	_deliver_pending_draw(p2, 1)
	# 7. Board update          [E4 minion/totem throttled-tick seam]
	# 8. Resolution check
	_check_resolution()


## X3 hot-reload seam (story 1-1): the runner passes the (re)loaded BalanceConfig here.
## Re-injects bounds set_maximum-style (re-clamp + re-signal, queued per D5) and
## re-converts every `*_seconds` duration ONCE via BalanceTicks. A TimingWindow already
## in flight keeps its original duration; the new tick counts take effect at its next
## start() (D4/A1). Player order fixed P1 -> P2 for determinism.
##
## Story 3-1 (AC 4, 3-1/R2): this is ALSO match start now that the constructor carries no
## stats, and the two occasions differ in exactly one place — hp. FIRST injection is
## detected from `balance == null` (a DERIVED fact, no new field to keep in sync, and
## nothing else writes `balance`); it is passed down rather than re-derived per player so
## both players are read from the same decision.
func apply_balance(config: BalanceConfig) -> void:
	var first_injection := balance == null
	balance = config
	balance_ticks = BalanceTicks.from_config(config)
	_apply_balance_to_player(p1, config, first_injection)
	_apply_balance_to_player(p2, config, first_injection)


## Story 1-5 (B3): one-time flag injection at match start. Runner-only, exactly once —
## flags have NO reload path (deliberately unlike apply_balance); state never reads
## FeatureFlagsService.
func inject_feature_flags(value: FeatureFlags) -> void:
	flags = value


## Story 3-3 (AC 2): the deck-content INJECTION SEAM — the inject_feature_flags precedent
## above, followed exactly: runner-only, ONCE at match start, CONTENT ONLY, and NO reload path
## (deliberately unlike apply_balance). This is the ONLY way deck content reaches src/state/;
## no file under src/state/ may name CardDatabase, CARDS_DIR or data/cards (AC 1/AC 8), so the
## runner reads the autoload, derives the composition (AC 4) and hands plain StringName ids in.
##
## CONTENT ONLY, NEVER THE DEAL: the ids are retained here and the shuffle + fill happen at the
## step-6 seat inside advance(). Calling this does not consume one bit of the seeded RNG — the
## property test_injection_alone_deals_nothing_and_consumes_no_rng pins.
##
## AC 10: an EMPTY injected deck is a programming error, ENFORCED AT THE SEAM (Invariant.check,
## the push_contact precedent — a plain static class, export-surviving, no autoload). This is
## the DETECTOR the ownerless export-packaging remap risk flag gained instead of an owner: a
## data/cards/ that degrades to empty under export remap becomes a LOUD failure at match start
## rather than a silently empty deck nobody notices.
func inject_deck(contents: Array[StringName]) -> void:
	Invariant.check(not contents.is_empty(), "injected deck content must be non-empty (empty card set or a failed export remap?)")
	_deck_contents = contents.duplicate()
	_deck_deal_pending = true


## Story 3-5a (AC 4): the CAST-COST injection seam — the inject_deck precedent directly above,
## followed exactly: runner-only, ONCE at match start, CONTENT ONLY, and NO reload path
## (deliberately unlike apply_balance). This is the ONLY way cast costs reach src/state/; no
## file under src/state/ may name CardDatabase, CARDS_DIR or data/cards, so the runner reads the
## autoload, derives the map and hands plain ids + CardCastCondition resources in.
##
## MUST BE CALLED AFTER inject_deck(). The second check below reads _deck_contents, so the
## ordering is not a style preference — it is what makes the check mean anything. The runner
## calls the two in that order and test_card_play.gd pins the guard.
##
## TWO checks, both Invariant.check at the seam (the inject_deck / push_contact precedent — a
## plain static class, export-surviving, no autoload):
##   1. NON-EMPTY, the inject_deck rationale verbatim: a data/cards/ that degrades to empty
##      under an export remap becomes a LOUD failure at match start rather than a match in
##      which every cast silently refuses with `unknown_card`.
##   2. TOTAL OVER THE COMPOSITION: every id that can ever reach a hand has a cost entry. A
##      hand is filled only from the deck, and the deck is laid down only from the injected
##      composition, so this check makes an unknown id AT CAST TIME structurally unreachable —
##      which is precisely why CastEvaluator carries no live crash guard for it (AC 4's
##      "unreachable rather than a new crash guard").
func inject_card_costs(costs: Dictionary[StringName, CardCastCondition]) -> void:
	Invariant.check(not costs.is_empty(),
		"injected cast costs must be non-empty (empty card set or a failed export remap?)")
	for id in _deck_contents:
		Invariant.check(costs.has(id),
			"injected deck id %s has no cast cost entry — inject_card_costs must be total over the composition" % id)
	_card_costs = costs.duplicate()


## Story 1-5 (B7): the contact intake seam — 1-7's real runner-gathered facts MUST enter
## through this same call, never a second path. Plain recordable data (X5): attacker
## slot, target slot, the attacker's HeroState.attack_index at gather time, and (story
## 1-8, R-B3 — the FOUR-field fact, superseding the original three-int shape) the
## world-space planar direction from the TARGET to the ATTACKER, computed by the runner
## FROM POSITIONS ONLY. The runner reports the spatial fact; state alone compares it
## against the target's facing (the arc gate is step-4 policy). Queued here, drained in
## advance() step 4. Headless tests feed synthetic facts through this API. A malformed
## fact is a programming error, ENFORCED at the seam (review R1 — Invariant.check, a
## plain static class, no autoload): slots must be 0 or 1, a self-contact is malformed
## in 1v1 (operator decision; 1-7's gate revisits if real gathering ever needs
## otherwise), and a zero direction is directionless — no spatial fact.
func push_contact(attacker_slot: int, target_slot: int, attack_index: int,
		target_to_attacker: Vector2) -> void:
	Invariant.check(attacker_slot == 0 or attacker_slot == 1,
		"contact attacker_slot must be 0 or 1, got %d" % attacker_slot)
	Invariant.check(target_slot == 0 or target_slot == 1,
		"contact target_slot must be 0 or 1, got %d" % target_slot)
	Invariant.check(attacker_slot != target_slot,
		"self-contact fact is malformed in 1v1 (attacker == target == %d)" % attacker_slot)
	Invariant.check(not target_to_attacker.is_zero_approx(),
		"contact target_to_attacker direction must be non-zero (no spatial fact)")
	_contact_queue.append({
		"attacker": attacker_slot,
		"target": target_slot,
		"attack_index": attack_index,
		"dir": target_to_attacker,
	})


## Runner step-2 push (story 1-2). slot: 0 = P1, 1 = P2 — out-of-range is a programming
## error (fixed-size fact; the array index asserts). State never reads the camera; it only
## receives this pushed value.
##
## LOAD-BEARING (DECISION A): while the camera is fixed (all of E1) the hero ROOT must
## never be rotated — body/facing rotation belongs on a child mesh node. The rig is a
## child of the hero root, so a rotated root would fold hero rotation into this pushed
## basis and break camera-relative "forward" (and the identity short-circuit in
## _resolve_movement). The runner therefore pushes the rig's LOCAL basis, guarded by
## test_root_rotation_isolation.gd; a story that needs a rotating root must decouple the
## rig from hero rotation deliberately (deferred DECISION B).
func set_camera_basis(slot: int, camera_basis: Basis) -> void:
	_camera_bases[slot] = camera_basis


## Emit all queued signals. Called by the runner AFTER advance() returns (D5).
func drain_signals() -> void:
	_queue.drain()


func to_snapshot() -> Dictionary:
	return {
		"tick": _tick,
		"rng_state": _rng.state,   # captured so the determinism hash catches RNG desync
		"round_over": _round_over,
		"p1": p1.to_snapshot(),
		"p2": p2.to_snapshot(),
		"pitch": pitch.to_snapshot(),
	}


## Story 3-0b (AC 2): READ-ONLY DEBUG accessor — per slot, the remaining ticks of the action
## windows that are currently RUNNING, as COMPUTED PLAIN INTEGERS derived from
## TimingWindow.remaining_ticks(). Slot order is fixed [P1, P2]; window order within a slot is
## HeroState's declaration order. A window that is not running is ABSENT (the AC's "active
## windows"), so the payload is small — at most two or three entries per slot in practice.
##
## This is DEBUG INSTRUMENTATION, NOT an eighth observation seam: the runner POLLS it after
## advance() and pushes the plain payload into DebugInstrumentPanel. No signal, no state handle,
## no mutator — presentation receives VALUES, never internals, the same discipline the seven
## seams already follow (the standing "hands the state layer's internals to presentation"
## objection is answered by the return type: ints keyed by name). to_snapshot() is deliberately
## NOT extended, so the replay contract never learns this instrument exists.
func debug_window_ticks_remaining() -> Array[Dictionary]:
	return [_running_window_ticks(p1.hero), _running_window_ticks(p2.hero)]


## The per-hero half of debug_window_ticks_remaining(). The TimingWindow objects are read and
## discarded INSIDE this function — only ints leave it.
static func _running_window_ticks(hero: HeroState) -> Dictionary:
	var out: Dictionary = {}
	var windows: Array = [
		[&"windup", hero.windup],
		[&"active", hero.active],
		[&"recovery", hero.recovery],
		[&"chain", hero.chain],
		[&"deflect", hero.deflect],
		[&"iframe", hero.roll_iframe],
		[&"roll", hero.roll_duration],
		[&"stun", hero.stun],
	]
	for entry: Array in windows:
		var window: TimingWindow = entry[1]
		if window.is_running:
			out[entry[0]] = window.remaining_ticks()
	return out


## Step-3 transition evaluation (story 1-3). EVALUATES HeroState.TRANSITION_TABLE — the
## table data lives on HeroState next to the enum; this is only the evaluator. Durations
## are read from balance_ticks.<field> inline at the moment a transition fires and passed
## into the window's start() (CONSTRAINT C: never cache the BalanceTicks object — a
## running window keeps its old duration across a reload; the next start() picks up the
## new one, guarded by test_balance_config.gd).
func _resolve_actions(player: PlayerState, intent: InputIntent, slot: int) -> void:
	# DEBT A deferral (story 1-3, deliberate): the runner never calls apply_balance() yet,
	# so in live play balance_ticks is null and actions are INERT until the follow-up
	# story wires apply_balance at match start + re-baselines the golden (both DEBT A
	# halves together). This is THE one guard — no scattered null checks below it.
	if balance_ticks == null:
		return
	var hero := player.hero
	# (a) Timer-driven progression/exits — windows were advanced in step 2; read results.
	match hero.action_state:
		HeroState.ActionState.ATTACKING:
			match hero.attack_phase():
				&"windup_done":
					hero.active.start(balance_ticks.attack_active_ticks)
				&"active_done":
					hero.recovery.start(balance_ticks.attack_recovery_ticks)
					hero.chain.start(balance_ticks.attack_chain_window_ticks)
				&"attack_done":
					hero.set_action_state(HeroState.ActionState.IDLE)
		HeroState.ActionState.ROLLING:
			if not hero.roll_duration.is_running:
				hero.set_action_state(HeroState.ActionState.IDLE)
		HeroState.ActionState.BLOCKING:
			if not intent.is_held(&"block"):
				hero.set_action_state(HeroState.ActionState.IDLE)
	# (b) Input-driven edges from the current table row. A press with no entry in the row
	# is dropped, never buffered (AC 5). Fixed INPUT_PRIORITY order = deterministic
	# same-tick tiebreak; at most one transition fires per tick.
	var row := hero.transition_row()
	if not HeroState.TRANSITION_TABLE.has(row):
		return
	var edges: Dictionary = HeroState.TRANSITION_TABLE[row]
	for action: StringName in HeroState.INPUT_PRIORITY:
		if intent.is_pressed(action) and edges.has(action) \
				and _try_transition(player, edges[action], intent, slot):
			return


## Fire one table edge. Returns false when a gated edge rejects — the chain cap (silent,
## story 1-3) or the roll stamina precondition (emits action_rejected, story 1-4) — so a
## lower-priority same-tick press may still be considered.
## intent/slot ride along for the ROLLING edge only (story 1-9): the entry-time roll
## direction is captured from the SAME press that fires the transition.
func _try_transition(player: PlayerState, target: HeroState.ActionState, intent: InputIntent,
		slot: int) -> bool:
	var hero := player.hero
	match target:
		HeroState.ActionState.ATTACKING:
			var chaining := hero.action_state == HeroState.ActionState.ATTACKING
			if chaining:
				# Chain edge: only inside the chain window and below the authored cap.
				# attack_chain_length is a COUNT, not a duration — it lives on balance,
				# not balance_ticks; read inline under the same no-caching rule.
				# FIRST, before the stamina seat below: a capped press is not an attempt
				# to attack, so it must not be charged (and stays SILENT, story 1-3).
				if not hero.chain.is_running or hero.chain_index + 1 >= balance.attack_chain_length:
					return false
			# The THIRD step-3 policy seat of the deduction MECHANISM (stamina-cost
			# corrective pass, E3-RG/R2; decision (d) RESOLVED at DP/R2 — the basic attack
			# costs stamina as an ANTI-SPAM lever, the 1-5 mana faucet is untouched).
			# Follows the ROLL precedent exactly, not deflect's: charged AT ENTRY per swing
			# (chain included), and unaffordable = the 1-4 FALLTHROUGH, never deflect's
			# degrade — there is no degraded attack to fall back to. Cost and delay read
			# inline (CONSTRAINT C). Nothing above this line mutated hero state, so a
			# rejected attack costs nothing, enters no state, and leaves chain_index alone.
			if not player.stamina.spend(
					balance.attack_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				hero.reject_action(&"attack", &"insufficient_stamina")
				return false
			if chaining:
				hero.chain_attack(balance_ticks.attack_windup_ticks)
			else:
				hero.enter_attack(balance_ticks.attack_windup_ticks)
		HeroState.ActionState.ROLLING:
			# A step-3 policy seat of the single deduction MECHANISM (StaminaPool.spend,
			# D4/story 1-4; R-D1 reconciliation). No longer the ONLY one: the basic attack
			# gained a cost in the E3-RG/R2 corrective pass and shares this seat's shape
			# (see the ATTACKING case above). BLOCKING entry stays free (block costs TIME
			# via the D6 regen suppression).
			# Deflect's policy seat is step 4 — spend at deflect LANDING, never at entry
			# (story 1-8, R-D1). Cost and delay are read inline at the moment of the
			# transition (CONSTRAINT C). Insufficient stamina is a PRECONDITION (D5): the
			# edge rejects and falls through per INPUT_PRIORITY, and the queued
			# action_rejected keeps the loss legible even if a lower-priority press fires.
			if not player.stamina.spend(
					balance.roll_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				hero.reject_action(&"roll", &"insufficient_stamina")
				return false
			hero.enter_roll(balance_ticks.roll_duration_ticks, balance_ticks.roll_iframe_ticks,
					_roll_world_direction(hero, intent.move_dir, slot))
		HeroState.ActionState.BLOCKING:
			# Story 1-8 (R-D1): affordability PRECONDITION only — no spend, no regen-delay
			# restart at entry; the spend happens at deflect LANDING (step 4). Unaffordable
			# = DEGRADE, not the 1-4 fallthrough: the block edge still fires as a plain
			# block, only the window is denied, and the queued rejection names "deflect"
			# because that is the thing denied. Cost read inline (CONSTRAINT C).
			var can_deflect := player.stamina.get_current() >= balance.deflect_stamina_cost
			hero.enter_block(balance_ticks.deflect_window_ticks, can_deflect)
			if not can_deflect:
				hero.reject_action(&"deflect", &"insufficient_stamina")
	return true


## Story 1-9 (1-9/R6): the entry-time roll direction — the same camera-rotated world
## mapping _resolve_movement uses (clamp, identity short-circuit, yaw-only rotation),
## NORMALIZED (constant roll speed needs a unit direction), with the hero's world-space
## facing as the fallback when the stick is neutral. Computed ONCE at the transition;
## the stored value is locked for the whole roll.
func _roll_world_direction(hero: HeroState, move_dir: Vector2, slot: int) -> Vector3:
	if move_dir.is_zero_approx():
		return Vector3(hero.facing.x, 0.0, hero.facing.y).normalized()
	var dir := move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()
	var world_dir: Vector3
	if _camera_bases[slot] == Basis.IDENTITY:
		world_dir = Vector3(dir.x, 0.0, dir.y)
	else:
		world_dir = _camera_relative_dir(dir, _camera_bases[slot])
	return world_dir.normalized()


## Step-4 contact resolution (story 1-5). Drains the queue in push order; for each fact,
## a DEAD target drops the fact outright (story 1-7, D-3 — dropped BEFORE resolution: no
## damage, no dedupe registration, no confirmed hit, so no step-5 mana; closes the
## corpse-mana-farming defect found at the 1-7 gate), then an open target iframe drops
## it the same way (story 1-9, 1-9/R1 — the second target-state drop; see the inline
## comment for the ladder position), then the attacker's dedupe decides
## acceptance (live record for the fact's attack_index + target not already hit this
## swing — stale, unknown, and duplicate facts are DROPPED). Story 1-8 (R-D4): dedupe
## registration happens for EVERY outcome — one resolution per swing per target, whether
## it lands full, blocked, or deflected; a resolved swing's later facts cannot
## re-resolve. Outcome ladder for an accepted fact (all balance reads inline,
## CONSTRAINT C): a BLOCKING target facing the attacker (the arc gate, R-D2/R-D3)
## either DEFLECTS — window open per the +1 grace read (R-N2) AND the deflect cost
## spends at LANDING (R-D1; a failed spend, the R-N7 multi-deflect edge, degrades this
## contact to a block) — fully negated: no damage, no hit_landed, NO step-5 mana, only
## the queued deflect_landed; or BLOCKS — damage x block_damage_multiplier, still a
## CONFIRMED hit (reduced hit_landed + full step-5 mana — block deliberately does not
## touch the attacker's economy in E1). Not facing (or not blocking) = full damage
## regardless of the window — no parry from behind. Returns the attacker slots of
## confirmed hits, in confirmation order, for step 5's mana seat. Pre-injection guard
## mirrors _resolve_actions: without balance the queue still drains (facts are
## per-tick, never carried) but nothing resolves.
func _resolve_contacts() -> Array[int]:
	var confirmed: Array[int] = []
	if _contact_queue.is_empty():
		return confirmed
	if balance == null:
		_contact_queue.clear()
		return confirmed
	for fact in _contact_queue:
		var attacker := p1 if int(fact["attacker"]) == 0 else p2
		var target := p1 if int(fact["target"]) == 0 else p2
		if target.hero.action_state == HeroState.ActionState.DEAD:
			continue
		# Story 2-3 (AC3, 2-3/R6): attacker-side DEAD FACT DROP — the same rung and the same
		# DEAD-drop family as the target drop above: PRE-DEDUPE, ahead of the iframe drop and
		# register_swing_hit. A dead attacker's fact delivers NOTHING (no damage, no
		# hit_landed, no mana, no deflect signal). Placed before register_swing_hit so the
		# corpse's fact never consumes the swing's one resolution; attack_index stays
		# untouched. The in-flight window is NOT stopped or shortened here — it keeps ticking
		# to expiry by design (1-9/R3 intact); it simply resolves to nothing.
		if attacker.hero.action_state == HeroState.ActionState.DEAD:
			continue
		# Story 1-9 (1-9/R1): iframe FACT DROP — not a resolution. Judged on the window
		# (+grace) ALONE, never on state == ROLLING (1-9/R3), and BEFORE dedupe
		# registration (the DEAD-drop family): a dropped fact never consumes the swing,
		# so if the i-frames expire inside the swing's active window the next gathered
		# fact resolves normally. No damage, no hit_landed, no mana, no signal (1-9/R5).
		if target.hero.is_iframe_open():
			continue
		if not attacker.hero.register_swing_hit(int(fact["attack_index"]), int(fact["target"])):
			continue
		var damage := balance.attack_damage_percent_of_max_hp / 100.0 * target.hero.get_max_hp()
		if target.hero.action_state == HeroState.ActionState.BLOCKING \
				and _is_facing(target.hero, fact["dir"]):
			if target.hero.is_deflect_window_open() and target.stamina.spend(
					balance.deflect_stamina_cost, balance_ticks.stamina_regen_delay_ticks):
				_queue.push(deflect_landed.emit.bind(int(fact["attacker"]), int(fact["target"])))
				continue
			damage *= balance.block_damage_multiplier
		target.hero.take_damage(damage)
		_queue.push(hit_landed.emit.bind(
			int(fact["attacker"]), int(fact["target"]), damage, target.hero.get_hp()))
		confirmed.append(int(fact["attacker"]))
	_contact_queue.clear()
	return confirmed


## Story 1-8 (R-D2/R-D3): the facing gate — pure state policy over the runner-reported
## direction fact. True iff the target-to-attacker direction lies within +/- half the
## authored arc of the target's world-space facing (angle_to is magnitude-independent,
## so neither vector needs normalizing; the arc is read inline, CONSTRAINT C). Exact
## float comparison, deliberately no epsilon: a direction at EXACTLY arc/2 lands on
## float rounding, which is fine — real directions are continuous, and the guarded
## behavior is both sides OF the arc, not the measure-zero boundary ray.
func _is_facing(hero: HeroState, target_to_attacker: Vector2) -> bool:
	return absf(hero.facing.angle_to(target_to_attacker)) \
			<= deg_to_rad(balance.block_facing_arc_degrees * 0.5)


## Step-5 mana generation (story 3-4, AC 1/AC 2) — the D6 EVALUATOR seat. The direct
## `balance.melee_hit_mana` grant story 1-5 shipped here is GONE, not kept behind a flag:
## the authored `melee_hit` rule now names that same field and the evaluator dereferences
## it, so this is a refactor of the one existing path and NOT a second call site.
## `melee_mana_generation` is still the off-switch, but it is DATA on the rule now
## (`required_flag`), so both flag configurations run through the same evaluator call —
## flag OFF simply resolves to 0.0 and ManaPool.add() no-ops. No flags injected reads the
## same way (graceful degradation, unchanged from 1-5).
## The live `balance` / `balance_ticks` / `flags` are passed IN on every call and never
## retained by the evaluator (CONSTRAINT C — it is static and stateless).
func _generate_mana(confirmed_hits: Array[int]) -> void:
	var rules := EconomyEvaluator.authored_rules()
	var per_hit := EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_MELEE_HIT,
			EconomyEvaluator.MANA, balance, balance_ticks, flags)
	for slot in confirmed_hits:
		var attacker := p1 if slot == 0 else p2
		attacker.mana.add(per_hit)
	# The PASSIVE rung (story 3-4, AC 4) — the second faucet, same step, same slot, fixed
	# P1 -> P2 order. Sealed semantics: no delay window, suppressed for DEAD only, NOT
	# suppressed for BLOCKING (mana building behind a block IS the flywheel's point, and
	# block already pays through the stamina suppression — it is not double-charged).
	# The round-over freeze needs NO guard here: step 1b returns before step 5 is reached,
	# so a frozen tick never runs this at all.
	var per_tick := EconomyEvaluator.amount_for(rules, EconomyEvaluator.SOURCE_PASSIVE_TICK,
			EconomyEvaluator.MANA, balance, balance_ticks, flags)
	_regen_mana(p1, per_tick)
	_regen_mana(p2, per_tick)


## Step-5 passive mana (story 3-4, AC 4) — the POLICY seat beside _regen_stamina's (D6).
## Mana's suppression set is deliberately NARROWER than stamina's: DEAD only. A corpse runs
## no economy (the standing 2-3/R5 doctrine), but a blocking hero keeps charging.
func _regen_mana(player: PlayerState, amount_per_tick: float) -> void:
	var suppressed := player.hero.action_state == HeroState.ActionState.DEAD
	player.mana.advance_regen(amount_per_tick, suppressed)


## Step-5 stamina regen (story 1-4). The per-tick amount is read inline from balance_ticks
## (CONSTRAINT C); the pool owns the mechanism (fixed add + post-spend delay window), THIS
## is the policy seat (D6): regen is suppressed while the hero is BLOCKING — block entry is
## free, so block must cost time or holding it would be free and P2 ("aggression is
## economy") unenforced; suppressed likewise while DEAD, since a corpse runs no economy
## (story 2-3). Every other action state regenerates.
func _regen_stamina(player: PlayerState) -> void:
	# Story 2-3 (AC2, 2-3/R5): a DEAD hero is skipped the SAME way a BLOCKING one already is
	# (the D6 suppression) — a corpse runs no economy. This extends the existing suppression
	# flag; it is a DIFFERENT function and step from the P2 movement gate (do not merge them).
	var state := player.hero.action_state
	var suppressed := state == HeroState.ActionState.BLOCKING \
			or state == HeroState.ActionState.DEAD
	player.stamina.advance_regen(balance_ticks.stamina_regen_per_tick, suppressed)


## Step-6 deck deal (story 3-3, AC 7/AC 9) — the ONE SEAT. Runs at most once per tick, and only
## when something armed it: the match-start injection or a debug reset ingested at step 1 this
## same tick. There is no round-start event in the game (round_started fires only FROM the debug
## reset, whose own comment calls it an operator affordance and not a gameplay path), so "round
## start" for the fill means exactly those two occasions and nothing else.
##
## Player order is fixed P1 -> P2 for determinism, and both piles are laid down from the SAME
## injected composition and shuffled against the SAME generator in turn — which is how the two
## players get different orders out of one seed without a second RNG ever existing.
##
## `balance == null` joins the pre-injection guard family (step 3's _resolve_actions, step 5's
## regen, step 4's twin): hand_size has no value to read yet. The latch is deliberately NOT
## cleared on that path, so a match that receives its deck before its balance still deals on the
## first tick after apply_balance() instead of silently never dealing.
func _deal_pending_decks() -> void:
	if not _deck_deal_pending or balance == null:
		return
	_deck_deal_pending = false
	_deal_player(p1)
	_deal_player(p2)


## The per-player half: full composition down, shuffle, hand emptied, then fill from the TOP.
##
## The debug-reset occasion RESTORES the full composition rather than returning cards from
## anywhere — there is nowhere to return them TO (no discard pile ships, AC 11) — and AC 9 pins
## the post-reset counts to the same hand_size / deck_size - hand_size pair as match start.
##
## hand_size is read INLINE at the moment of use (CONSTRAINT C): a snapshot-the-value read in
## the TimingWindow.start() shape, never a cached BalanceConfig reference, so a hot reload takes
## effect at the next deal instead of half-applying to one already in flight.
##
## The is_empty() stop is a FLOOR here too, but it is no longer the LAST word: story 3-5b gives
## the pile a way back (the lazy reshuffle at delivery time), and the authoring audit still keeps
## hand_size <= deck_size so this initial fill never reaches the floor.
func _deal_player(player: PlayerState) -> void:
	player.deck.set_contents(_deck_contents)
	_shuffle_deck(player.deck)
	# Story 4-0 (AC 1, `4-0/R2`): the WIDTH is established HERE, at the deal seat, and nowhere
	# else. `balance.hand_size` is read INLINE at the moment of use (CONSTRAINT C) and handed in;
	# `Hand` never learns of BalanceConfig, never holds a config reference and never names
	# hand_size. A Hand that has never been dealt to therefore has width 0, which is what keeps
	# the pre-deal `hand_size` snapshot reading 0 without a special case.
	player.hand.clear(balance.hand_size)
	# Story 3-5a: the discard is emptied HERE, beside the hand, because this is the seat that
	# re-lays the whole composition. Without it a debug reset would restore every card to the
	# deck AND leave the played ones in the discard, so "deck + hand + discard is a permutation
	# of the injected composition" — the property test_card_play.gd pins — would break on the
	# first reset after a cast. This is the reset's discard answer; the RESHUFFLE (returning the
	# discard to the deck mid-round) is 3-5b's and is deliberately not here.
	player.discard.clear()
	# Story 3-5b (AC 9): the debug reset KILLS a pending draw, and the owed card is NOT restored
	# — it is already back in the pile, because this seat re-lays the FULL injected composition
	# two lines above. Conservation is therefore restored by construction and 3-3's AC 9 post-reset
	# count pin needs no special case. start(0) is the kill: TimingWindow.start() sets is_running
	# from `duration_ticks > 0`, so a zero duration leaves the window stopped AND its snapshot at
	# all-zeros — no bespoke stop() path, which is what keeps AC 7's early-abort scan honest.
	player.pending_draw_owed.clear()
	player.pending_draw.start(0)
	# Story 4-0 (AC 5, `4-0/R4`): the fill loop is REWRITTEN, not merely reviewed. `hand.clear()`
	# now PRE-FILLS the authored width with markers (the width arriving from here, read inline per
	# CONSTRAINT C — `Hand` never names hand_size), so the old `hand.add()` append would have
	# written PAST that width and produced a 2 * hand_size array. An indexed in-place write is
	# mandatory, and `Hand.add` no longer exists precisely so this could not be got wrong quietly.
	#
	# The post-fill state is UNCHANGED from before this story for every case the authored balance
	# reaches: the authoring audit keeps hand_size <= deck_size, so the is_empty() floor below is
	# never hit and every slot holds a card with no hole left behind. The floor is retained anyway
	# — it is the same defensive stop the pre-4-0 loop carried, and a hand_size > deck_size
	# authoring would leave trailing HOLES rather than a short hand, which AC 3 then refuses per
	# slot instead of silently renumbering the rest.
	for slot_index in balance.hand_size:
		if player.deck.is_empty():
			break
		player.hand.fill_at(slot_index, player.deck.draw_top())
	# Story 3-6 (AC 2): the FIRST of the three announcement seats — one per seat that moves a
	# card, placed after the whole occasion completes rather than per container touched, so the
	# deal announces one settled payload instead of three intermediate ones.
	player.notify_cards_changed()


## Story 3-5a (AC 2/AC 9): the CARD-ACTION dispatch — a PRIVATE MatchState method called at
## step 6, deliberately not a free function and not a new class, because the mutation must stay
## inside advance()'s ordered dispatch (D2) where every other mutation lives. The architecture
## doc's Novel Pattern 6 sketch shows a free-standing `resolve()` with no owning class named;
## nothing of that shape existed in src/ and none is introduced here (the eighth
## architecture-amendment-queue member).
##
## FROZEN TICKS NEVER REACH THIS FUNCTION, and that is the whole frozen-tick contract: step 1b
## returns before step 2, so on a round-over tick no intent is ingested at all and a committed
## cast is DROPPED SILENTLY — no state change, no signal, not even a rejection. That is
## CONSISTENT with every other intent during the freeze (attack, block, roll and move are all
## dropped the same way, for the same structural reason) and it is why card intent is NOT read
## inside step 1b. Emitting a rejection for casts alone would require reading card intent there
## and would make a cast the ONE action with freeze feedback — a privilege nothing else has.
## This closes the readiness-gate finding that no contract existed for a cast on a frozen tick:
## the contract is silence, ruled and pinned (test_card_play.gd::test_cast_on_a_frozen_tick_is
## _dropped_silently), not an omission for a later gate to rediscover as a defect.
##
## The DEAD guard below is the LIVE-tick counterpart and is DEFENSE IN DEPTH, in the same family
## as the DEAD branches at step 3 (_resolve_movement), step 4 (_resolve_contacts) and step 5
## (_generate_mana): DEAD and _round_over are set TOGETHER by _end_round, and cleared together by
## the debug reset, so a DEAD player is always also frozen and this branch is unreachable in
## natural play. Its siblings are unreachable for the same reason and are guarded anyway; each is
## pinned by the same forced-DEAD test idiom (`set_action_state(DEAD)` with _round_over left
## FALSE), which is how this one is proven non-vacuous too. It returns SILENTLY, like every
## sibling — a corpse gets no rejection feedback.
##
## NO `balance == null` GUARD, deliberately unlike its step-3/4/5 neighbours: that family exists
## to stop reads of unset balance FIELDS, and this path reads none. Costs come from the injected
## map and values from the pools. A pre-injection match has an empty hand, so a commit there
## takes the empty-slot rejection, which is a true statement about that match rather than an
## inert-guard violation.
func _resolve_card_action(player: PlayerState, intent: InputIntent, slot: int) -> void:
	if not intent.card_commit:
		return
	if player.hero.action_state == HeroState.ActionState.DEAD:
		return
	# AC 2's guarded stubs. ONE mode resolves in E3; the other three are declared so they CAN be
	# guarded (see Enums.ModeKind) and are unreachable — the controller never produces them, and
	# reaching one is a programming error, not a player-facing refusal. Invariant.check is the
	# guard helper (`check_invariant` names no real symbol anywhere in this repo).
	match intent.card_mode:
		Enums.ModeKind.BASIC:
			_resolve_basic_cast(player, intent.card_slot, slot)
		_:
			Invariant.check(false,
				"card mode %d is a guarded stub and is unreachable in E3 (only BASIC resolves)"
						% int(intent.card_mode))


## Story 3-5a (AC 5): Mode ① resolution — mana spent, card out of the hand, card into the
## discard, effect signal queued.
##
## STORY 3-5b (AC 3) AMENDS THE LAST STEP: the replacement is no longer drawn here. 3-5a's
## instant refill is REPLACED by a debt plus a timer, delivered at the end of step 6 (see
## _deliver_pending_draw). Everything else about this function is unchanged, including the fact
## that the mana spend, the hand removal and the discard all still happen within this one tick.
##
## REJECTIONS RIDE THE SHIPPED SEAM (AC 7): HeroState.reject_action — the same queued
## action_rejected signal and the same per-slot observation seam that already carries the
## insufficient-stamina roll rejection to StateInspector. No new signal, no new seam, seam count
## unchanged. The action name is the prefix-free &"card_cast", matching the &"roll"/&"attack"
## vocabulary the existing rejections use.
##
## THE EVALUATOR COMPUTES, THE POOL APPLIES (AC 3): CastEvaluator returns a reason and touches
## nothing; the spend below goes through ManaPool.spend(), inside this ordered dispatch. The
## spend cannot fail after an ALLOWED verdict — the evaluator has just compared the same cost
## against the same live reading — so a false return is a programming error and says so.
func _resolve_basic_cast(player: PlayerState, hand_slot: int, slot: int) -> void:
	# Story 4-0 (AC 3): TWO paths to ONE reason. The bound check survives and is now a WIDTH bound;
	# the HOLE test joins it as a SECOND path to the SAME refusal, not a new one and not a
	# replacement for the first. `Hand.is_slot_empty` folds both together — it reports "holds no
	# card" for an out-of-range index too — so the two cases cannot drift apart into two reasons.
	#
	# NO SIBLING TOKEN SHIPS (`3-5b/R8`'s surviving clause): CastEvaluator.REASON_EMPTY_SLOT is
	# reused verbatim, riding the same shipped HeroState.reject_action / action_rejected seam and
	# the same per-slot observation seam 3-5a already ships. A hole IS an empty slot — inventing
	# REASON_HOLE would be naming the mechanism instead of the player-visible fact.
	#
	# `3-5b/R8`'s "a cast is not gated on a pending draw" SURVIVES NARROWED (`4-0/R5`): no cast is
	# gated on the DEBT — nothing here consults pending_draw_owed, and casting a DIFFERENT slot
	# with a draw in flight still resolves. What is refused is a cast against the slot whose OWN
	# replacement is in flight, which is a statement about that slot being empty, not about the
	# debt. "Mana stays the only throttle" is SUPERSEDED: mana remains the only ECONOMIC throttle,
	# and slot occupancy is now a second, structural, player-observable precondition.
	if player.hand.is_slot_empty(hand_slot):
		player.hero.reject_action(&"card_cast", CastEvaluator.REASON_EMPTY_SLOT)
		return
	# Story 4-0 (AC 7, second part): the ORDERING BELOW IS PINNED, not incidental. The hole is
	# refused at the guard directly above, BEFORE the cost map is ever consulted — so the empty
	# marker can never reach `_card_costs.get(id)` and can never be evaluated for affordability.
	# That is what makes "a hole is never rendered as an affordable card" true on the STATE side
	# by construction rather than by a lookup that happens to miss. Do not move the cost lookup
	# above the guard, and do not add a path that reaches it with an unvalidated slot.
	var id: StringName = player.hand.to_array()[hand_slot]
	var condition: CardCastCondition = _card_costs.get(id)
	var reason := CastEvaluator.refusal_reason(condition, player.mana.get_current(),
			player.orbs, flags)
	if reason != CastEvaluator.ALLOWED:
		player.hero.reject_action(&"card_cast", reason)
		return
	Invariant.check(player.mana.spend(condition.mana_cost),
		"an ALLOWED cast must be affordable — CastEvaluator and ManaPool disagree")
	var played := player.hand.remove_at(hand_slot)
	player.discard.add(played)
	# Story 3-5b (AC 3): the replacement is now OWED, not drawn. 3-5a's instant refill lived
	# exactly here; it is REPLACED, not kept behind a flag. The debt is incremented and the window
	# started, and the delivery happens at the end of this same step 6 — immediately if the
	# derived delay is zero ticks, `delay` ticks later otherwise.
	#
	# A CAST IS NOT GATED ON A PENDING DRAW (AC 3): no check above this line consults the debt, no
	# new rejection reason ships, and mana remains the only throttle. Casting again with a draw in
	# flight simply owes a second card.
	#
	# balance_ticks is read INLINE (CONSTRAINT C) and is non-null here by construction, which is
	# why this seat keeps its "NO balance == null guard" property: a hand can only be non-empty if
	# the step-6 deal ran, and the deal returns early while balance is null.
	#
	# STORY 4-0 (AC 4): the debt records WHICH SLOT. `hand_slot` is the slot just vacated one line
	# above, appended to the FIFO so the replacement lands back in it rather than at the end of the
	# hand. Two casts against two different slots each owe their own slot, and neither delivery can
	# ever land in the other's.
	player.pending_draw_owed.append(hand_slot)
	player.pending_draw.start(balance_ticks.draw_replacement_delay_ticks)
	# Story 3-6 (AC 2): the SECOND announcement seat. The hand is one short here and stays so
	# until the delivery announces again — which is a true statement about the match and exactly
	# what the HUD should render while a draw is in flight, not a gap to paper over.
	player.notify_cards_changed()
	_queue.push(card_cast_resolved.emit.bind(slot, played))


## Step-6 delivery of ONE owed replacement (story 3-5b, AC 3/AC 5/AC 7/AC 10). Seated after the
## cast dispatch; see the call site for why both halves of that ordering are load-bearing.
##
## The window is READ, never stopped: a delivery is due when the debt is non-zero and the window
## is not running, which is true both for a window that expired at step 2 and for one that was
## started with a zero duration this very tick. Exactly ONE card per expiry, then the window
## RESTARTS while the debt is still above zero, so four casts in flight deliver four cards one at
## a time rather than four at once.
##
## DEATH DROPS THE DELIVERY, NEVER THE WINDOW (AC 7). 1-9/R3 stays locked — no early-stop path
## ships anywhere in this file; a dead player's window ticks out normally and the CARD is simply
## discarded, the 1-9/R1 fact-drop idiom applied literally. The debt is still consumed, because a
## corpse that came back would otherwise be handed a backlog. Like its step-3/4/5/6 siblings this
## branch is UNREACHABLE in natural play (3-5/R6: DEAD and _round_over are set together and
## cleared together, so a DEAD player is always also frozen and step 1b returns before step 2) —
## it is defense in depth in exactly that family, and is proven non-vacuous the same way each of
## them is, by the forced-DEAD idiom (`set_action_state(DEAD)` with _round_over left FALSE).
func _deliver_pending_draw(player: PlayerState, slot: int) -> void:
	if player.pending_draw_owed.is_empty() or player.pending_draw.is_running:
		return
	# Story 4-0 (AC 4): the debt is popped as a SLOT, not decremented as a count. FIFO — the
	# oldest cast is served first, which is the tie-break the Deferred section leaves free and
	# requires only that no delivery ever land in a slot it wasn't owed to. The pop happens
	# BEFORE the DEAD branch, exactly as the decrement did: a corpse still consumes its debt, so
	# one that came back is not handed a backlog (AC 7, 3-5b).
	var owed_slot: int = player.pending_draw_owed.pop_front()
	if player.hero.action_state != HeroState.ActionState.DEAD:
		_draw_one_replacement(player, slot, owed_slot)
	if not player.pending_draw_owed.is_empty():
		player.pending_draw.start(balance_ticks.draw_replacement_delay_ticks)


## The draw itself, with the LAZY reshuffle in front of it (story 3-5b, AC 5/AC 10).
##
## LAZY, NOT EAGER: nothing happens at deck_size == 0: the pile is refilled at the moment a draw
## would otherwise find it empty, which is the only moment the state layer can observe the need.
##
## BOTH EMPTY IS A NO-OP DEGRADE, NEVER A CRASH (AC 10). No Invariant.check ships on this path,
## deliberately unlike the injection seams: reachability here depends on AUTHORED BALANCE NUMBERS
## (a small deck against a long delay drains both piles), and a crash path reachable from authored
## data is not acceptable. The owed card is consumed by the caller either way, the hand simply
## stays short — hand_size is permitted to reach 0 — and NO vulnerable window opens, because
## there was nothing to reshuffle.
## STORY 4-0 (AC 4/AC 8): the drawn card is written INTO THE OWED SLOT, never appended. That one
## substitution is what the whole story buys — the card in the slot the player cast is the exact
## card its replacement refills, rather than a rename of whichever card slid into that position.
##
## AC 8 RULES WHAT THE BOTH-EMPTY DEGRADE NOW MEANS, and it is design, not an observation. The
## debt is consumed by the caller either way; under this shape the consequence is that the HOLE
## PERSISTS and that slot refuses through AC 3 for the rest of the round. The same cards are lost
## as before this story — what changed is that the loss is addressed to a specific,
## permanently-refusing slot rather than to a shorter hand. "hand_size is permitted to reach 0"
## survives and now reads as occupied_count() reaching 0 against a still-full-width hand.
func _draw_one_replacement(player: PlayerState, slot: int, owed_slot: int) -> void:
	if player.deck.is_empty():
		if player.discard.is_empty():
			return
		_reshuffle_discard_into_deck(player, slot)
	player.hand.fill_at(owed_slot, player.deck.draw_top())
	# Story 3-6 (AC 2): the THIRD and last announcement seat. Seated AFTER the lazy reshuffle
	# above rather than inside it, so a delivery that had to refill the pile announces ONE
	# settled payload — the reshuffled deck count and the refilled hand together. The both-empty
	# degrade returns above without announcing, because it moved no card.
	player.notify_cards_changed()


## Story 3-5b (AC 5/AC 6): this player's discard folded back into this player's deck, inside the
## one existing step-6 RNG seat.
##
## NO NEW `Deck` OR `Hand` METHOD, and that is a delivered constraint rather than a style note:
## the whole operation is expressible with the containers' shipped surface (set_contents +
## the shared shuffle helper + clear), which is what keeps the Deck/Hand method-name fence green.
## A `Deck.reshuffle()` would kill that fence.
##
## THIS PLAYER'S OWN DISCARD ONLY. It never touches the opponent's piles and never re-derives a
## fresh composition from the injected content — a reshuffled pile is exactly the cards this
## player has played, which is what makes the four-term conservation property hold across it.
## `draw_top()` takes the LAST element (the fixed "top is the back" convention, 3-3), so the
## shuffle above decides what the reshuffled pile hands back first.
func _reshuffle_discard_into_deck(player: PlayerState, slot: int) -> void:
	player.deck.set_contents(player.discard.to_array())
	_shuffle_deck(player.deck)
	player.discard.clear()
	# AC 6: the window and its announcement, together and nowhere else. The window's duration is
	# read INLINE (CONSTRAINT C) so a mid-match reload takes effect at the next reshuffle while an
	# already-running window keeps its own. The signal is QUEUED (D5) and relayed by the runner.
	player.vulnerable_window.start(balance_ticks.reshuffle_vulnerable_window_ticks)
	_queue.push(reshuffle_vulnerable_window_opened.emit.bind(slot))


## INVARIANT F2, MACHINE-CHECKED (story 3-5b, AC 16 — `3-5b/R17` corrected by `3-5b/R18`).
##
## THE ONE SEEDED-SHUFFLE CALL SITE IN `src/`. Both shuffle OCCASIONS route through here — the
## match-start/debug-reset deal (_deal_player) and the lazy reshuffle above — so
## `shuffle_with_rng(` appears in exactly TWO places in the whole of `src/`: its definition in
## deck.gd and this one line. test_architecture_invariants.gd pins that count.
##
## Why a helper rather than two call sites: F2 ("the seeded RNG is consumed only inside
## advance()") has been cited as a contract by 3-3, 3-5a and 3-5b and was REVIEW-ENFORCED ONLY —
## the D3(b)/A2 scan bans GLOBAL RNG in src/state/, not a SECOND SEEDED SEAT, so nothing in the
## suite would have failed if `_rng` had grown a second consumer. This story is the first that
## could introduce one. Collapsing both occasions onto one line makes "one seat" literally true
## rather than approximately true, and makes it countable.
func _shuffle_deck(deck: Deck) -> void:
	deck.shuffle_with_rng(_rng)


func _resolve_movement(player: PlayerState, intent: InputIntent, slot: int) -> void:
	# Story 2-3 (AC2, 2-3/R5): a DEAD hero exhibits no live movement. ASYMMETRIC by
	# downstream consumption (see story Dev Notes): velocity is EXPLICITLY written to zero
	# EVERY tick — HeroActor.drive() reads hero_state.velocity straight into move_and_slide()
	# (hero.gd:26), so a SKIPPED write would leave the last live velocity in place and the
	# corpse would slide forever; facing is SKIPPED (this early return never reaches the
	# facing write below), so its last value persists unchanged — that persistence IS the
	# freeze, storing nothing new (hero.gd:34 only reads facing to derive a display yaw).
	# No new snapshot field: only velocity's VALUE on the DEAD branch changes.
	if player.hero.action_state == HeroState.ActionState.DEAD:
		player.hero.velocity = Vector3.ZERO
		return
	var dir := intent.move_dir
	if dir.length() > 1.0:
		dir = dir.normalized()  # analog safety; never speed up past move_speed
	# move_dir is CAMERA-space (story 1-2): rotated to world by the slot's pushed basis,
	# yaw only. Identity (nothing pushed — AC 4) short-circuits to the exact E0 planar
	# mapping (intent XY -> world XZ), a true no-op so headless tests and the determinism
	# golden are untouched. velocity stays the REAL world velocity the runner reads (D3);
	# the runner never rotates it afterwards (AC 6).
	var world_dir: Vector3
	if _camera_bases[slot] == Basis.IDENTITY:
		world_dir = Vector3(dir.x, 0.0, dir.y)
	else:
		world_dir = _camera_relative_dir(dir, _camera_bases[slot])
	# Story 1-5 (B6, operator decision): attack commitment — while ATTACKING the resolved
	# VELOCITY is scaled by an attack-phase multiplier (authored 0.0 = full root), read
	# inline at the moment of use (CONSTRAINT C). Velocity ONLY — the facing update below
	# is never scaled by the multiplier. ATTACKING is unreachable pre-injection (the step-3
	# balance_ticks guard), so `balance` is non-null on this branch.
	# Story 3-0b (AC5, DEBT E member 2): the multiplier is now PER PHASE — the single flat
	# field is gone and _attack_phase_multiplier() selects windup/active/recovery from
	# HeroState.attack_phase(). No new state: the phase is already derived from which
	# window is running.
	# Story 1-9 (1-9/R6): the ROLL half of the same coupling deferral — while ROLLING the
	# velocity is the entry-locked roll_direction at roll_distance / roll_duration_seconds
	# (the ruling's exact quotient; a SPEED derivation, not window timing — timing stays
	# balance_ticks), both read inline at the moment of use (CONSTRAINT C: a mid-roll
	# reload changes the speed next tick while in-flight windows keep their duration).
	# Live input steers nothing until the roll ends; the facing update below still runs
	# (the ATTACKING-commitment precedent: velocity-only, facing tracks input). ROLLING is
	# unreachable pre-injection too, and the authoring audit guarantees
	# roll_duration_seconds > 0.
	if player.hero.action_state == HeroState.ActionState.ROLLING:
		player.hero.velocity = player.hero.roll_direction \
				* (balance.roll_distance / balance.roll_duration_seconds)
	else:
		# Story 3-0b (AC6): the attack LUNGE, ADDED to the input-driven velocity rather than
		# replacing it — the phase multiplier keeps scaling what the player steers, and the
		# lunge is the separate committed push the swing itself carries. At the authored
		# multipliers (0.0 = full root) the lunge is therefore the whole of the attack's
		# velocity, which is the intended shape: input steers nothing mid-swing, the swing
		# still carries the hero forward.
		var speed := player.hero.move_speed
		var lunge := Vector3.ZERO
		if player.hero.action_state == HeroState.ActionState.ATTACKING:
			speed *= _attack_phase_multiplier(player.hero.attack_phase())
			lunge = _attack_lunge_velocity(player.hero)
		player.hero.velocity = world_dir * speed + lunge
	# Story 1-7 (review R1, operator decision): facing is WORLD-SPACE planar — the same
	# rotated direction the velocity uses, so actor-side consumers (the hitbox yaw) need
	# no basis knowledge. Under an identity basis world_dir == (dir.x, 0, dir.y), so
	# facing equals the raw intent direction bit-for-bit (golden-neutral). The zero-guard
	# is unchanged: facing freezes while there is no movement input.
	if not dir.is_zero_approx():
		player.hero.facing = Vector2(world_dir.x, world_dir.z)


## Story 3-0b (AC5): per-phase attack movement multiplier. Selects one of the three
## BalanceConfig fields from HeroState.attack_phase(), read inline at the moment of use
## (CONSTRAINT C).
##
## BOUNDARY VALUES: attack_phase() also returns windup_done/active_done/attack_done on a
## phase-boundary tick (step 2 stopped a window, step 3 has not yet started the next). Step
## 3(a) normally starts the successor BEFORE _resolve_movement runs, so an ATTACKING hero
## is on a running window here — but a degenerate 0-tick authored phase can leave a *_done
## value visible, so the mapping is TOTAL rather than relying on that. It groups the
## boundary values exactly the way HeroState.transition_row() already does (windup +
## windup_done together, active + active_done together), so the two phase consumers agree
## on where a boundary tick belongs instead of inventing a second grouping; attack_done
## falls to recovery as the last phase that ran.
func _attack_phase_multiplier(phase: StringName) -> float:
	match phase:
		&"windup", &"windup_done":
			return balance.attack_windup_move_speed_multiplier
		&"active", &"active_done":
			return balance.attack_active_move_speed_multiplier
		_:
			return balance.attack_recovery_move_speed_multiplier


## Story 3-0b (AC6): the attack lunge as a STATE-SIDE velocity term — the sanctioned form
## from the 1-7 close-out ("an authored lunge displacement in balance data, applied by the
## STATE layer as a velocity curve during the swing"). NEVER root motion: no AnimationPlayer
## sample reaches this function, so replay never depends on animation and DECISION A / the
## in-place rule stand untouched.
##
## Speed derivation follows the ROLL precedent verbatim (roll_distance /
## roll_duration_seconds, the neighbouring branch): the authored DISPLACEMENT divided by the
## span it is spent over. A *_seconds float is read here for the same reason the roll reads
## one — this is a SPEED derivation, not window timing; all timing stays on balance_ticks
## (CONSTRAINT C: both operands are read inline at the moment of use, so a mid-swing reload
## changes the speed next tick while in-flight windows keep their duration).
##
## PHASE SCOPE (ruled, story AC6): live during WINDUP and ACTIVE only. The lunge is the
## commitment forward INTO the swing; drifting through recovery is a different feel decision
## and is not this term's. Boundary values are grouped exactly as _attack_phase_multiplier()
## groups them, so the two consumers never disagree about which phase a boundary tick is in.
##
## Direction is HeroState.facing — world-space planar since 1-7/R1, so no basis knowledge is
## needed here and none of the camera mapping above applies to it. Facing is read LIVE
## rather than entry-locked (the roll's stored roll_direction shape), which keeps the lunge
## out of the snapshot entirely: no new state field, no snapshot-shape change. A hero that
## turns mid-swing therefore lunges along its new facing — the "velocity-only commitment,
## facing tracks input" rule this function already follows for the multiplier.
##
## Guards: a zero-or-negative span would divide to INF and poison the snapshot, and a
## zero facing has no direction to lunge along. Both yield no lunge. The authoring audit
## already keeps the shipped windup/active durations > 0; this guard covers in-test and
## pre-authoring configs, which the roll branch can skip only because ROLLING is
## unreachable before its own authored duration exists.
func _attack_lunge_velocity(hero: HeroState) -> Vector3:
	var phase := hero.attack_phase()
	var committed := phase == &"windup" or phase == &"windup_done" \
			or phase == &"active" or phase == &"active_done"
	if not committed:
		return Vector3.ZERO
	var span := balance.attack_windup_seconds + balance.attack_active_seconds
	if span <= 0.0 or hero.facing.is_zero_approx():
		return Vector3.ZERO
	var dir := hero.facing.normalized()
	return Vector3(dir.x, 0.0, dir.y) * (balance.attack_lunge_distance / span)


## Yaw-only camera-space -> world mapping (AC 3): the basis' right/back columns are
## flattened onto XZ and renormalized, so camera pitch mathematically cannot tilt or
## shrink movement. Degenerate columns (camera looking straight up/down) fall back to the
## world-space mapping rather than producing NaNs.
static func _camera_relative_dir(dir: Vector2, camera_basis: Basis) -> Vector3:
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z)
	var back := Vector3(camera_basis.z.x, 0.0, camera_basis.z.z)
	if right.is_zero_approx() or back.is_zero_approx():
		return Vector3(dir.x, 0.0, dir.y)
	return right.normalized() * dir.x + back.normalized() * dir.y


## Story 3-1 (AC 4, 3-1/R2): the PER-POOL reload contract. The three pools are deliberately
## NOT symmetric, and the asymmetry is the contract, not an oversight:
##   hp      — set_max_hp re-clamps the CURRENT value into the new bound and never raises it
##             (hero_state.gd), so a reload preserves the hp a player has fought down to.
##             That leaves match start with nothing to fill it, hence `first_injection`
##             below: without it a stat-less hero would sit at 0 hp and start the match dead
##             (3-1/R4, the finding that forced this seat to exist at all).
##   stamina — set_maximum + refill on EVERY injection (D9, story 1-4, UNCHANGED): stamina
##             is the moment-to-moment resource and a reload hands it back full.
##   mana    — set_maximum ONLY, on every injection including the first. NEVER refilled:
##             ManaPool's own contract is that mana starts empty and is built by the
##             flywheel (mana_pool.gd:4-5), so a reload-refill would hand a free full bar
##             mid-match and break the buildup P2 depends on. set_maximum re-clamps the
##             current value into the new bound (ManaPool.set_maximum -> add(0.0)), which is
##             all a rescale may do to a player's earned mana.
## Match start therefore yields FULL hp, FULL stamina, EMPTY mana.
func _apply_balance_to_player(player: PlayerState, config: BalanceConfig,
		first_injection: bool) -> void:
	player.hero.set_max_hp(config.max_hp)
	if first_injection:
		# The one match-start-only write. heal() clamps at the maximum set just above, so
		# this is "fill to the authored max" and nothing else — the _reset_player idiom.
		player.hero.heal(config.max_hp)
	player.hero.move_speed = config.move_speed
	player.stamina.set_maximum(config.max_stamina)
	# D9 (story 1-4): start FULL at the authored maximum — every apply_balance, reload
	# included (test_mid_match_reload_refills_stamina_to_max). Story 3-1 reconciled the
	# constructor/apply_balance double injection this comment used to defer: there is no
	# constructor seeding left to double-write.
	player.stamina.refill()
	player.mana.set_maximum(config.max_mana)


## Story 3-1 (AC 5, 3-1/R3): joins the `balance_ticks == null` gated family (step 3's
## _resolve_actions, step 5's regen/mana, step 4's `balance == null` twin). A pre-injection
## MatchState is stat-less as well as inert, so its heroes sit at 0 hp — unguarded, the
## FIRST tick of a never-injected match would resolve a round end against a hero that was
## never given any hp to lose. Read inline like every other guard (CONSTRAINT C).
func _check_resolution() -> void:
	if balance_ticks == null:
		return
	if _round_over:
		return
	if not p1.hero.is_alive():
		_end_round(p1, 0)
	elif not p2.hero.is_alive():
		_end_round(p2, 1)


## Story 1-7 (D-3): the ONLY entry into ActionState.DEAD — a step-8 resolution outcome,
## never a table edge (the table's dead row accepts nothing; exit is only the D-1 debug
## reset). Presentation learns of death through the same queued action_state_changed
## channel as every transition (the locked observation seam).
func _end_round(loser: PlayerState, loser_index: int) -> void:
	_round_over = true
	loser.hero.set_action_state(HeroState.ActionState.DEAD)
	_queue.push(round_ended.emit.bind(loser_index))


## Story 1-7 (D-1, operator decision): ROUND-SCOPED debug reset — every slot's HP back to
## max and the round latch cleared; NOTHING else (pools, dedupe records, in-flight
## windows, and actor-owned positions untouched — a live hero mid-swing swings on). A
## DEAD hero returns to IDLE (a "clear action state" entry), which NEVER touches
## attack_index (monotonic dedupe contract, pinned at the 1-6 gate). Deliberately NOT
## flag-gated: operator affordance, not a gameplay path (exception recorded in the
## decision log). Fixed P1 -> P2 order for determinism.
func _apply_debug_reset() -> void:
	_round_over = false
	_reset_player(p1)
	_reset_player(p2)
	# Story 3-3 (AC 9): RE-ARM the step-6 deal seat — the reshuffle and refill happen THERE,
	# inside this same advance(), never here. A reset that lands before any injection has no
	# composition to lay down, so the latch is left alone rather than armed against nothing.
	# The parked finding that MANA survives a reset stays PARKED with the first round-flow
	# story: this story only participates in this function beside the hp heal and introduces
	# no round lifecycle of its own.
	if not _deck_contents.is_empty():
		_deck_deal_pending = true
	# Story 2-6 (AC 1, 2-6/R5): announce the reset UNCONDITIONALLY on every debug reset — the
	# round lifecycle previously emitted only on END (round_ended), never on reset, which is the
	# 2-4 close-out MICRO-DECISION 1 gap (the round-over label survived a reset because nothing
	# signalled it). Queued (D5) like every state signal; the runner relays it post-drain.
	_queue.push(round_started.emit)


func _reset_player(player: PlayerState) -> void:
	var hero := player.hero
	if hero.action_state == HeroState.ActionState.DEAD:
		hero.set_action_state(HeroState.ActionState.IDLE)
	hero.heal(hero.get_max_hp())
