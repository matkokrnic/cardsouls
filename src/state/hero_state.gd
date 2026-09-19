class_name HeroState
extends RefCounted

## D1 hero state: HP, action state, intended velocity, facing, and the D4 timing windows.
## Pure RefCounted — no scene, no Input, no position (position is actor-owned, F1).
##
## MOVEMENT SEAM (D3): `velocity` is the INTENDED velocity, computed in advance() from the
## player's InputIntent. The runner reads THIS field and calls move_and_slide — it must
## never read the intent's direction and move the actor directly (that would bypass D3).

signal hp_changed(current: float, maximum: float)
## Story 1-3 migration: was single-arg (state); now carries (previous, current) so the
## presentation layer (1-10) and HUD (E2) can react to edges, not just arrivals. This is
## the ONLY channel telling visuals what the hero is doing.
signal action_state_changed(previous: ActionState, current: ActionState)
## Story 1-4 loss legibility (D5): a press REJECTED by a transition precondition — in E1
## the stamina-gated roll ONLY. The 1-3 capped-chain reject stays silent; widening this
## signal to cover it is a separate decision, not an implementation detail. Emitted queued,
## even when a lower-priority action succeeds the same tick. NO runner seam until the first
## consumer (1-10 — seam obligation recorded in the decision-log).
signal action_rejected(action: StringName, reason: StringName)

## Souls action states — few and timing-gated, kept as a pure enum in the state layer so
## transitions stay in the deterministic tick and under headless test (chosen over a
## scene-coupled StateMachine node). DEAD (story 1-7, D-3) is APPENDED so the existing
## snapshot int values never shift.
enum ActionState { IDLE, ATTACKING, BLOCKING, ROLLING, STUNNED, CHARGING, DEAD }

## ---------------------------------------------------------------------------------------
## TRANSITION TABLE (story 1-3) — the single readable block. Cancellability is DATA here,
## never scattered ifs. Rows are the state/phase the hero is IN (ATTACKING is split into
## its three phases — windup/active/recovery — derived from which window is running, see
## attack_phase()); columns map an InputIntent press to the TARGET state of that edge.
## A press whose action has no entry in the current row is DROPPED, never buffered (AC 5).
##
## E1 convention (AC 3): windup and active are non-cancellable; recovery accepts attack
## (= chain, gated by the chain window + attack_chain_length) and roll (roll-cancel).
## BLOCKING/ROLLING exit on release/expiry, which are not input edges.
##
## STUNNED (story 5-6, AC 6): row PRESENT and REACHED — but STILL with zero inbound TABLE edges.
## STORY 6-6a (AC 3) adds a THIRD direct entry: the knockdown, `MatchState._apply_landing_packages`'s
## write on the VICTIM of an unanswered unblockable. The two-entry text below is 5-6's and is kept as
## that story's record; test_action_state.gd pins the count at three now.
## OPEN decision (a) (attacker consequence on deflect, decision-log Session 2026-07-22) is RESOLVED
## by `E5-P/R1`, and `5-6` is the resolution: `STUNNED` is entered by exactly TWO direct
## `MatchState.set_action_state` calls — the colour-counter negation inside `_resolve_charge_landing`
## and the melee-deflect branch inside `_resolve_contacts` — which is the DEAD-entry precedent
## exactly (a non-table path). The table itself is untouched, and the inbound-edge enumeration test
## in test_action_state.gd still guards it, joined there by a POSITIVE enumeration pinning the two
## authored non-table entry points at exactly two.
## CHARGING: reserved for E5 — no row, no inbound edge; deliberately absent, not stubbed.
## DEAD (story 1-7, D-3): row present, accepts nothing, zero inbound TABLE edges — entry
## is ONLY MatchState's step-8 resolution (a non-table path), exit is ONLY the D-1 debug
## reset. Guarded by the same inbound-edge enumeration test.
##
## MatchState step 3 EVALUATES this table (reading balance_ticks inline, CONSTRAINT C);
## the table data itself lives here, next to the enum, per the architecture decision.
const TRANSITION_TABLE: Dictionary = {
	&"idle": {
		&"attack": ActionState.ATTACKING,
		&"roll": ActionState.ROLLING,
		&"block": ActionState.BLOCKING,
	},
	&"attacking_windup": {},    # non-cancellable
	&"attacking_active": {},    # non-cancellable
	&"attacking_recovery": {
		&"attack": ActionState.ATTACKING,  # chain — gated by chain window + chain length
		&"roll": ActionState.ROLLING,      # roll-cancel
	},
	&"blocking": {},            # exits on block release, not via an input edge
	&"rolling": {},             # exits on roll_duration expiry
	&"stunned": {},             # accepts no input — and nothing may transition IN (E1)
	&"dead": {},                # accepts no input — enter via step-8 resolution, exit via reset ONLY
}

## Fixed evaluation order for same-tick simultaneous presses (deterministic tiebreak).
const INPUT_PRIORITY: Array[StringName] = [&"attack", &"roll", &"block"]

var action_state: ActionState = ActionState.IDLE
## 0-based swing index within the current attack sequence (story 1-3). Increments on a
## chain (ATTACKING -> ATTACKING); resets to 0 on ANY exit from ATTACKING to a
## non-ATTACKING state (roll-cancel included — a cancelled chain never resumes).
var chain_index: int = 0
## Story 1-5 (B7b): MONOTONIC swing counter — the dedupe key. Unlike chain_index it never
## resets: every swing (fresh or chained) gets a unique index for the life of the match,
## so a stale contact fact can never collide with a later swing's record. -1 = no swing
## yet. The runner (1-7) stamps gathered facts with this value.
var attack_index: int = -1
var velocity := Vector3.ZERO   # intended velocity; the runner reads this (D3), not the intent
## WORLD-SPACE planar facing (world x, z) — story 1-7 review R1: assigned from the same
## camera-rotated world direction the velocity uses, so actor-side consumers (the hitbox
## yaw in HeroActor.drive) need no basis knowledge. Under an identity basis it equals the
## raw intent direction. Freezes while movement input is zero.
var facing := Vector2.DOWN
## Story 1-9 (1-9/R6): WORLD-SPACE unit roll direction, captured ONCE at ROLLING entry
## (camera-rotated move_dir; facing fallback when the stick is neutral — MatchState
## computes, enter_roll stores). Locked for the whole roll: _resolve_movement reads THIS
## while ROLLING instead of live input. SNAPSHOTTED (the one 1-9 snapshot delta) — it is
## read across ticks, so excluding it would be a determinism/replay hole.
var roll_direction := Vector3.ZERO
var move_speed: float          # injected (balance .tres in E3); tunable, not hardcoded-in-place
## Story 6-7 (AC 5, the R6 hysteresis latch): set whenever a pursuing run key's own drain
## leaves stamina empty (`6-7/R16`: `is_zero_approx`) -- widened by the fix-pass review's
## finding 2 from the narrower "set when a held run key drains stamina to empty" reading:
## the set happens on the SAME tick the drain reaches empty, not merely on a later tick where
## the key is still held, and it fires from ANY source that empties the bar while a pursuing
## run key is held (a roll or attack spend, not only this story's own drain), matching AC 9's
## own text. While set, RUN is refused regardless of the run key, even at
## non-zero stamina, until current stamina is `>=` `run_resume_stamina_percent` of `max_stamina`
## (MatchState._regen_stamina clears it). CROSSES TICKS and DECIDES AN OUTCOME (whether running
## may resume) -- HASHED via the existing to_snapshot() chain, the `lock_target_slot`/
## `charge_window` precedent (test_replay_identity.gd:144-158) -- no `UNHASHED_CROSS_TICK_MEMBERS`
## bump needed.
var run_locked_out := false

## The eight per-action D4 windows (story 1-3). windup/active/recovery are the phases of
## one attack swing; chain is the input window for ATTACKING -> ATTACKING; deflect opens at
## BLOCKING entry when the deflect cost is affordable (R-D1, story 1-8) and is read by the
## step-4 resolution with a +1 grace tick (R-N2); roll_iframe/roll_duration at ROLLING
## entry (1-9).
## stun is owned and advanced here; story 5-6 (AC 5/AC 9) gives it its FIRST two start() sites —
## `MatchState._resolve_charge_landing`'s colour-counter negation and `_resolve_contacts`' melee
## deflect, both against the ATTACKER. Its exit is the step-3 timer arm (natural expiry only, no
## early-stop path anywhere) plus the debug reset's fifth named exception. See TRANSITION TABLE.
## Durations are always injected by MatchState from balance_ticks at start() time
## (CONSTRAINT C) — HeroState never sees a BalanceTicks object.
var windup := TimingWindow.new()
var active := TimingWindow.new()
var recovery := TimingWindow.new()
var chain := TimingWindow.new()
var deflect := TimingWindow.new()
var roll_iframe := TimingWindow.new()
var roll_duration := TimingWindow.new()
var stun := TimingWindow.new()
## Story 6-6a (AC 8): THE GET-UP IFRAMES -- the ninth D4 window, opened by `MatchState` on the ordinary
## timer-driven `STUNNED -> IDLE` exit from a KNOCKDOWN (never on the debug reset, AC 9, which stops it
## instead). The `roll_iframe` mechanism's shape reused rather than a second mechanism: it ticks in
## `tick_timers()` beside `roll_iframe`, carries the same one-tick close grace
## (`_get_up_iframe_closed_this_tick`), has no early-stop path, and registers WHEREVER `roll_iframe`
## does -- `is_iframe_open()` below -- so the step-4 fact drop AND the unblockable dodge rung both see it
## (operator ruling R-IFRAME-UNBLOCKABLE). OWNED HERE rather than on `PlayerState`: the `5-5`
## `defense_window` precedent put that window on the player because it belongs to the CARD layer (a
## cast arms it, a landing consumes it); this one belongs to the BODY -- it is armed by an action-state
## exit and read by the same predicate as the roll's iframes, both of which live on this object.
## HASHED through `to_snapshot()`'s `get_up_iframe` key: it crosses ticks and decides an outcome
## (whether a hit lands at all).
var get_up_iframe := TimingWindow.new()

var _hp: float
var _max_hp: float
var _queue: SignalQueue

## Story 1-8 (R-N2): TRANSIENT grace marker — true only on the single tick whose step-2
## advance closed the deflect window, so a contact that physically happened on the
## window's last running tick and arrives one tick late (the F1 fact lag) still deflects
## (the dedupe-grace precedent). Write-before-read within every advance(): step 2
## recomputes it, step 4 reads it, and nothing reads it across ticks — so it is
## deliberately EXCLUDED from to_snapshot(): no determinism/replay hole, because replay
## recomputes it identically inside each tick before any consumer runs.
var _deflect_closed_this_tick := false

## Story 1-9 (1-9/R2): TRANSIENT grace marker — true only on the single tick whose step-2
## advance closed the roll_iframe window (the _deflect_closed_this_tick mirror, absorbing
## the same F1 one-tick fact lag). Write-before-read within every advance(): step 2
## recomputes it, step 4 reads it, and nothing reads it across ticks — so it is
## deliberately EXCLUDED from to_snapshot(): no determinism/replay hole, because replay
## recomputes it identically inside each tick before any consumer runs.
var _roll_iframe_closed_this_tick := false

## Story 6-6a (AC 8): TRANSIENT grace marker for `get_up_iframe` -- the `_roll_iframe_closed_this_tick`
## mirror, for the identical reason and with the identical write-before-read, never-snapshotted
## contract.
var _get_up_iframe_closed_this_tick := false

## Story 1-5 (B7b/N2): per-swing dedupe records, keyed by attack_index. Each record is
## {"hit": Array of [slot, index] TARGET ADDRESSES already resolved this swing, "grace": int}.
##
## DEV PASS CORRECTION (story 4-3b): this line documented the hit list as "Array[int] of target
## slots" until now, which stopped being true when `4-3a` widened the key to full `[slot, index]`
## addresses (`4-3a/R16`) — and the neighbouring `register_swing_hit` docstring has stated the
## correct shape since that story ("THE HIT LIST THEREFORE HOLDS PAIRS, NOT INTS"). The two
## descriptions of one field disagreed for a whole story. Corrected here rather than left, because
## `4-3b` rewrites this mechanism for a SECOND attacker kind (`UnitSwingDedupe`), which makes this
## the right place: a reader building the unit twin from the wrong description would key it by slot
## and silently lose every cleave. grace
## semantics: -1 = the swing's active window has not closed yet (record alive); 1 = window
## closed, record lives exactly ONE more tick (absorbs the F1 one-tick fact lag — a
## contact gathered on the last active tick arrives the tick after close and is still
## legitimate); decremented in tick_timers(), erased at 0. A fact is accepted iff its
## attack_index has a record here AND its target is not already in that record's hit list.
## SNAPSHOTTED (D8): mid-swing dedupe state excluded from the snapshot would be a
## determinism/replay hole. Multiple records can be alive at once — a chain pressed on the
## first recovery tick starts a new swing while the old record is still in its grace tick.
var _swing_dedupe: Dictionary = {}


func _init(queue: SignalQueue, max_hp: float, move_speed_value: float) -> void:
	_queue = queue
	_max_hp = max_hp
	_hp = max_hp
	move_speed = move_speed_value


func take_damage(amount: float) -> void:
	_set_hp(_hp - amount)


func heal(amount: float) -> void:
	_set_hp(_hp + amount)


func is_alive() -> bool:
	return _hp > 0.0


func get_hp() -> float:
	return _hp


func get_max_hp() -> float:
	return _max_hp


## X3 hot-reload: re-inject the HP bound (set_maximum-style: re-clamp + re-signal if the
## max shrank) — same pattern as the economy pools.
func set_max_hp(maximum: float) -> void:
	_max_hp = maximum
	_set_hp(_hp)


func set_action_state(new_state: ActionState) -> void:
	if new_state == action_state:
		return
	var previous := action_state
	if previous == ActionState.ATTACKING:
		chain_index = 0  # any exit to a non-ATTACKING state ends the sequence for good
	action_state = new_state
	_queue.push(action_state_changed.emit.bind(previous, new_state))


## Queued action_rejected emission (story 1-4, D5). Called by MatchState's step-3
## evaluation when a gated edge rejects a press; the reason vocabulary is the call site's.
func reject_action(action: StringName, reason: StringName) -> void:
	_queue.push(action_rejected.emit.bind(action, reason))


## Story 1-5 (N3): DERIVED accessor, no stored flag — same "phases are derived, not
## stored" family as attack_phase(). Actor-side consumption (the runner gathering overlaps
## for state-flagged-active hitboxes) is 1-7 scope.
##
## STORY 5-6 (AC 11): WIDENED from bare `active.is_running`, and the added conjunct is what closes
## the ORPHANED-SWING hole. The old comment's claim — "the active window is running, which only
## happens during ATTACKING" — became FALSE the moment anything could interrupt a swing: AC 9 writes
## `STUNNED` over `ATTACKING` at the instant a swing is deflected, and the `active` window keeps
## ticking to its own expiry (the 1-9 discipline of never early-stopping a window). Between that
## write and the window's expiry a hitbox query would gather contact facts from a hero the game is
## simultaneously punishing for that very swing.
##
## STATED AS A PROPERTY OF `action_state`, NOT OF `STUNNED`, deliberately: the hitbox stops being
## queried the instant the hero is no longer ATTACKING, whatever the reason — so any FUTURE
## non-`ATTACKING` interrupt gets the same closure without a second edit here.
func is_hitbox_active() -> bool:
	return active.is_running and action_state == ActionState.ATTACKING


## Story 1-8 (R-N2): the deflect window as step-4 resolution judges it — running, OR
## closed by this very tick's step-2 advance (+1 grace tick). DERIVED from the window
## plus the per-tick transient; no stored deflect-consumed state exists (each deflect
## pays per landing, R-N7 — the window is never latched shut by a hit).
func is_deflect_window_open() -> bool:
	return deflect.is_running or _deflect_closed_this_tick


## Story 1-9 (1-9/R2/R3): the iframe window as step-4 resolution judges it — running, OR
## closed by this very tick's step-2 advance (+1 grace tick). Judged on the window ALONE,
## never on state == ROLLING (1-9/R3): the authoring audit bounds iframe <= duration and
## both roll windows start only in enter_roll with no early-stop path, so the window
## cannot legitimately outlive the roll — any future early-stop path must re-open that
## ruling.
##
## Story 6-6a (AC 8, R-IFRAME-UNBLOCKABLE): WIDENED to the get-up iframes. Every consumer of this
## predicate -- the step-4 fact drop and `MatchState._iframe_open_at_step3` (the unblockable dodge rung)
## -- therefore protects a hero getting up exactly as it protects a rolling one, with no second call
## site to keep in step. The same window-alone judgement: `get_up_iframe` starts only at the knockdown
## timer exit and has no early-stop path (the debug reset clears it outside normal play).
func is_iframe_open() -> bool:
	return roll_iframe.is_running or _roll_iframe_closed_this_tick \
			or get_up_iframe.is_running or _get_up_iframe_closed_this_tick


## Story 6-6a post-smoke ruling (pending `6-6a/R` number): THE GET-UP IS A LOCKED ACTION. Derived from
## the SAME `get_up_iframe` window `is_iframe_open()` above already reads -- one window, one source of
## truth, no second timer and no stored flag. While it is true, `MatchState` refuses every intent this
## hero presses (attack, unblockable initiation, roll, card mode select/cast, block) and roots it, the
## `STUNNED` register applied to the get-up: the hero is invulnerable AND unable to act, instead of
## teleporting to its feet straight into a swing.
##
## THE WINDOW ALONE, NOT `is_iframe_open()`: the +1 close grace those two transient markers carry exists
## so a CONTACT FACT gathered on the window's last running tick still drops a tick late (the F1 fact
## lag). An INTENT has no such lag -- it is read in the same tick it is pressed -- so reading the grace
## here would eat one extra tick of input for no reason. The tick after the window empties accepts
## input normally.
func is_getting_up() -> bool:
	return get_up_iframe.is_running


## Story 1-5 (B7b): dedupe acceptance + registration, called by MatchState's step-4
## contact resolution for THIS hero as the attacker. Returns true iff the fact's
## attack_index matches a live dedupe record AND this swing has not already damaged
## that TARGET ADDRESS — and then records the address, so a second same-swing contact
## returns false. A false return means the fact is DROPPED (stale, unknown, or duplicate).
##
## STORY 4-3a (AC 3, `4-3a/R16`): THE KEY WIDENS FROM `[attack_index, slot]` TO
## `[attack_index, slot, index]` — the full target address. Today's slot-only key is an
## ARTEFACT OF A WORLD WHERE ONLY HEROES EXISTED: one slot held exactly one hittable thing,
## so the slot WAS the address. With units on the board a slot holds a hero and N units, and
## under the old key ONE SWING OVERLAPPING A UNIT AND THE ENEMY HERO WOULD RESOLVE ONLY THE
## FIRST — the second contact would read as a duplicate of a target it never touched.
##
## SO A SWING CLEAVES. Overlapping three targets in one active window now produces three
## separate confirmations rather than one, and the dedupe still does its actual job: the same
## address cannot be hit twice by the same swing.
##
## `index == -1` addresses that slot's HERO and `>= 0` a board unit at that index — the
## `4-2/R2` convention the contact fact's target and a unit's acquired target now SHARE, so
## the two addressing schemes are one fact rather than two that could drift.
##
## THE HIT LIST THEREFORE HOLDS PAIRS, NOT INTS, and the snapshot follows it — the record is
## deep-copied into to_snapshot(). The story PREDICTED that shape change as a second golden cause;
## MEASURED, IT IS A NON-MOVER, and the mechanism is worth recording here rather than rediscovering:
## every dedupe record in the golden's fixture has EXPIRED AND BEEN ERASED by the hash tick (both
## heroes' `records` dictionaries are empty at t24), so the widened key has nothing to hash. It
## would become a real cause the moment a fixture hashes mid-swing — which is exactly what
## test_contact_resolution.gd's mid-swing snapshot pin measures instead.
## `Array.has()` compares by VALUE and Godot 4 Array equality is element-wise, so a pair
## already present is found by `in` exactly as a bare int was.
##
## CANONICAL ORDER (`4-3a/R22`): the hit list is kept sorted by target address, `[slot, index]`
## ascending, rather than left in APPEND order. A cleave (AC 3) lets one swing register several
## addresses in a single tick, and their arrival order here is whatever order
## `_gather_contact_facts` happened to receive from the runner's overlap query — a physics query
## that pins no ordering. This list is snapshotted and hashed (see the type comment above), so an
## unpinned arrival order would make the hash depend on physics-query ordering: a determinism hole
## the shipped golden cannot see, because its fixture never cleaves. Sorting on insertion (rather
## than at snapshot time) keeps the stored state itself canonical, which is the simpler invariant
## to hold. `Array.sort()` on an `Array[Array[int]]` compares element-wise, so it sorts lexically by
## `[slot, index]` for free.
func register_swing_hit(index: int, target_slot: int, target_index: int) -> bool:
	if not _swing_dedupe.has(index):
		return false
	var hit: Array = _swing_dedupe[index]["hit"]
	var address: Array[int] = [target_slot, target_index]
	if address in hit:
		return false
	hit.append(address)
	hit.sort()
	return true


## Derived attack phase. Phases are expressed by WHICH WINDOW IS RUNNING (AC 1) — no
## stored phase field, so the snapshot stays exactly the windows + chain_index. On a
## phase-boundary tick (step 2 stopped a window, step 3 has not yet started the next) all
## three are stopped; the *_done value tells the evaluator which phase just ended, derived
## from elapsed_ticks (each swing start(0)-clears its successors, so elapsed > 0 means
## "has run this swing"). Assumes phase durations >= 1 tick — seconds_to_ticks clamps any
## non-zero authored value; a 0.0-authored phase duration is a config authoring error.
func attack_phase() -> StringName:
	if windup.is_running:
		return &"windup"
	if active.is_running:
		return &"active"
	if recovery.is_running:
		return &"recovery"
	if _has_run(recovery):
		return &"attack_done"
	if _has_run(active):
		return &"active_done"
	return &"windup_done"


## Row key into TRANSITION_TABLE for the current state/phase.
func transition_row() -> StringName:
	match action_state:
		ActionState.ATTACKING:
			match attack_phase():
				&"windup", &"windup_done":
					return &"attacking_windup"
				&"active", &"active_done":
					return &"attacking_active"
				_:
					return &"attacking_recovery"
		ActionState.BLOCKING:
			return &"blocking"
		ActionState.ROLLING:
			return &"rolling"
		ActionState.STUNNED:
			return &"stunned"
		ActionState.DEAD:
			return &"dead"
		ActionState.CHARGING:
			return &"charging"  # no table row -> accepts nothing (reserved E5)
	return &"idle"


## --- Entry actions -------------------------------------------------------------------
## Tick counts are INJECTED by MatchState, read from balance_ticks at the moment of the
## transition (CONSTRAINT C) — HeroState never caches durations or a BalanceTicks ref.

## Fresh attack sequence from a non-ATTACKING state.
func enter_attack(windup_ticks: int) -> void:
	set_action_state(ActionState.ATTACKING)
	chain_index = 0
	_start_swing(windup_ticks)


## Chain: the ATTACKING -> ATTACKING table edge. A self-transition is still a transition
## and emits (AC 4) — set_action_state() no-ops on the same state, so the queued emit is
## explicit here.
func chain_attack(windup_ticks: int) -> void:
	chain_index += 1
	_start_swing(windup_ticks)
	_queue.push(action_state_changed.emit.bind(ActionState.ATTACKING, ActionState.ATTACKING))


## Story 1-9 (1-9/R6): `direction` is the entry-captured world-space unit roll direction
## (MatchState computes the camera rotation and the facing fallback — policy stays in the
## evaluator; this only stores). Both windows open here and ONLY here (1-9/R3 obligation).
func enter_roll(duration_ticks: int, iframe_ticks: int, direction: Vector3) -> void:
	set_action_state(ActionState.ROLLING)
	roll_direction = direction
	roll_duration.start(duration_ticks)
	roll_iframe.start(iframe_ticks)


## Story 1-8 (R-D1): open_deflect_window carries the entry-time affordability
## PRECONDITION result — MatchState checks (policy), this only acts. The degraded path
## start(0)-clears the window so a still-running window from an earlier block press can
## never arm a block the hero could not afford. Entry itself never spends (BLOCKING
## entry is FREE — the locked 1-4 ruling).
func enter_block(deflect_window_ticks: int, open_deflect_window: bool) -> void:
	set_action_state(ActionState.BLOCKING)
	if open_deflect_window:
		deflect.start(deflect_window_ticks)
	else:
		deflect.start(0)


## One swing: windup starts; successor windows are start(0)-cleared so attack_phase() can
## tell "not yet run this swing" (elapsed 0) from "finished" (elapsed > 0). Story 1-5:
## every swing also claims the next attack_index and opens its dedupe record.
func _start_swing(windup_ticks: int) -> void:
	attack_index += 1
	_swing_dedupe[attack_index] = {"hit": [], "grace": -1}
	windup.start(windup_ticks)
	active.start(0)
	recovery.start(0)
	chain.start(0)


## True if this window has run at all since its last start(). Reads via to_snapshot() so
## TimingWindow stays unchanged (story constraint); only called on phase-boundary ticks,
## so the tiny Dictionary is not a hot-path allocation.
static func _has_run(w: TimingWindow) -> bool:
	return int(w.to_snapshot()["elapsed_ticks"]) > 0


## Advance all D4 windows one tick (called from advance() step 2). ORDER CONTRACT (AC 2):
## timers advance FIRST (step 2), transitions read the advanced result (step 3) — never
## flip this order. Story 1-5: the dedupe lifetime rides the same step — expired graces
## are cleared FIRST (a grace set on tick N survives through tick N's step 4 and dies in
## tick N+1's step 2), then an active window that just closed puts the current swing's
## record into its 1-tick grace.
func tick_timers() -> void:
	var was_active := active.is_running
	var deflect_was_running := deflect.is_running
	var iframe_was_running := roll_iframe.is_running
	var get_up_iframe_was_running := get_up_iframe.is_running
	windup.tick()
	active.tick()
	recovery.tick()
	chain.tick()
	deflect.tick()
	# Story 1-8 (R-N2): recomputed EVERY tick — true only when THIS step-2 advance
	# closed the window (see the field's transient/no-snapshot contract).
	_deflect_closed_this_tick = deflect_was_running and not deflect.is_running
	roll_iframe.tick()
	# Story 1-9 (1-9/R2): recomputed EVERY tick — true only when THIS step-2 advance
	# closed the window (see the field's transient/no-snapshot contract).
	_roll_iframe_closed_this_tick = iframe_was_running and not roll_iframe.is_running
	roll_duration.tick()
	stun.tick()
	get_up_iframe.tick()
	# Story 6-6a (AC 8): recomputed EVERY tick, the `_roll_iframe_closed_this_tick` line's exact shape.
	_get_up_iframe_closed_this_tick = get_up_iframe_was_running and not get_up_iframe.is_running
	for index in _swing_dedupe.keys():
		var grace := int(_swing_dedupe[index]["grace"])
		if grace > 0:
			grace -= 1
			if grace == 0:
				_swing_dedupe.erase(index)
			else:
				_swing_dedupe[index]["grace"] = grace
	if was_active and not active.is_running:
		_swing_dedupe[attack_index]["grace"] = 1


func _set_hp(value: float) -> void:
	var v := clampf(value, 0.0, _max_hp)
	if is_equal_approx(v, _hp):
		return
	_hp = v
	_queue.push(hp_changed.emit.bind(_hp, _max_hp))


func to_snapshot() -> Dictionary:
	return {
		"hp": _hp,
		"max_hp": _max_hp,
		"action_state": int(action_state),
		"chain_index": chain_index,
		# Story 1-5: the ONE snapshot delta of the story (D8) — the monotonic swing
		# counter plus the live dedupe records (deep copy: the snapshot must be a value,
		# not a live handle into state).
		"swing_dedupe": {
			"attack_index": attack_index,
			"records": _swing_dedupe.duplicate(true),
		},
		"velocity": velocity,
		"facing": facing,
		# Story 1-9: the ONE snapshot delta of the story — the entry-locked roll direction.
		"roll_direction": roll_direction,
		"move_speed": move_speed,
		"run_locked_out": run_locked_out,
		"windup": windup.to_snapshot(),
		"active": active.to_snapshot(),
		"recovery": recovery.to_snapshot(),
		"chain": chain.to_snapshot(),
		"deflect": deflect.to_snapshot(),
		"roll_iframe": roll_iframe.to_snapshot(),
		"roll_duration": roll_duration.to_snapshot(),
		"stun": stun.to_snapshot(),
		# Story 6-6a (AC 8): the get-up iframes -- a NEW snapshot key, present (at rest) on every hero.
		"get_up_iframe": get_up_iframe.to_snapshot(),
	}
