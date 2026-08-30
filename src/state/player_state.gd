class_name PlayerState
extends RefCounted

## D1 per-player composite: hero + economy pools + deck + hand. Pure RefCounted. All pools
## share the match SignalQueue so their signals drain together after advance() (D5).

## Story 3-6 (AC 2): the CARD OBSERVATION CHANNEL — this composite's own typed signal, and the
## first one PlayerState has ever owned (hp/stamina/mana each belong to the leaf that owns the
## value; the three card containers own no queue, so the composite that owns all three is where
## a payload spanning them belongs). Queued on the shared SignalQueue and drained by the runner
## after advance(), exactly like every signal in this layer (D5); the runner's EIGHTH connect_*
## seam is its only wiring, per slot.
##
## ONE PAYLOAD, THREE FACTS: the hand's CONTENTS in hand order, the deck COUNT, the discard
## COUNT. It exists because the HUD cannot get the hand any other way — contents and pile ORDER
## are excluded from to_snapshot() by 3-3 AC 5 / 3-5a AC 6 and pinned excluded by 3-0c AC 11
## (a StringName in the canonical hash orders by INTERNAL POINTER on this engine, deterministic
## within a process and not across runs). So this is a LIVE PUSH, not a state read, and adding
## it moves no snapshot key and no golden.
##
## `hand_ids` is a COPY (Hand.to_array()), so a consumer cannot reach the container through it.
## It is typed `Array[StringName]` on the wire; consumers may declare the parameter as a plain
## `Array` (Callable binding does not narrow), which is why the copy matters rather than the
## element type alone.
##
## OWN-SLOT FACTS ONLY (`3-6/R7`). Deck and discard COUNTS are private, exactly as the deleted
## opponent hand row's count was: the runner binds each consumer to ONE slot's channel (2-4/R7)
## and nothing here carries a slot index, so a consumer is structurally incapable of reading the
## opponent's. The one PUBLIC card fact in the game is the reshuffle window, and it travels the
## ownerless EventBus instead (3-5b AC 6) — not this channel.
signal cards_changed(hand_ids: Array[StringName], deck_count: int, discard_count: int)

var hero: HeroState
var stamina: StaminaPool
var mana: ManaPool
var orbs: OrbPool          # reserved / flag-off until E5

## Story 3-3 (AC 1): the card containers, owned HERE (the pools' precedent) and filled at
## MatchState's single step-6 deal seat — never by this constructor, which has no content to
## fill them with (deck content reaches the state layer ONLY through MatchState's injection
## seam, AC 2). `hand` replaces the reserved plain Array E0 left as a placeholder; `deck` is
## new. Both hold StringName ids and nothing else. Neither takes the SignalQueue: no card
## signal ships in this story (AC 11).
var deck: Deck
var hand: Hand

## Story 3-5a (AC 6): the THIRD card container, owned here on the Deck/Hand precedent directly
## above and filled from ONE seat only — MatchState's step-6 cast dispatch. Like its two
## siblings it takes no SignalQueue: the pile itself signals nothing.
var discard: DiscardPile

## Story 4-1 (AC 4): the BOARD — the FOURTH pure container, the collection
## docs/game-architecture.md D9 reserved for this story ("PlayerState will gain a `units`/board
## collection with its first consumer, story 4-1"; it carried no such reference before this
## line). Built to the Deck / Hand / DiscardPile shape exactly: RefCounted, no SignalQueue, no
## scene reference, filled from ONE seat only — MatchState's step-6 cast dispatch, through
## CardEffectResolver's verdict.
##
## NO `units_changed` SIGNAL SHIPS, and its absence is deliberate rather than pending. None of
## the three sibling containers carries a queue; PlayerState owns `cards_changed` only because
## that payload SPANS all three. Nothing in this story's scope needs the HUD or presentation to
## observe unit COUNT — the runner spawns and frees the grey-box actors off the snapshot count it
## already reads post-advance, so a signal would be authored ahead of its consumer, which is the
## `card_effect.gd` anti-precedent `E4-P/R2` names.
var units: UnitBoard

## Story 4-3b (AC 16, `4-3b/R14`): the unit-attacker SWING DEDUPE RECORDS, held BESIDE the board
## rather than on it. `unit_board.gd`'s own header rule forbids a non-scalar per-record field and a
## dedupe record is a list of target addresses, so this is the one piece of unit attack state the
## board structurally cannot carry — the cost `4-3b/R14` accepted by name.
##
## OWNED BY PlayerState LIKE THE BOARD, cleared in the same debug-reset seat, and reached from the
## same single writer family: `MatchState`'s step-4 contact resolution registers into it, and its
## step-3 unit seat opens and closes records. Nothing outside `advance()` mutates it, and nothing
## anywhere is handed a live record.
var unit_dedupe: UnitSwingDedupe

## Story 4-4 (AC 14-19, `E4-P/R12`): this player's LIVE PROJECTILES — the FIFTH pure container, owned
## exactly as `units` is, cleared in the same debug-reset seat, and written only from inside
## `advance()`'s ordered dispatch.
##
## A SEPARATE BOARD RATHER THAN A KIND OF UNIT, and the separation is `E4-P/R12`'s own ruling: a
## projectile "needs its own attacker identity and dedupe, not a `[slot, index]` unit-board address".
## It also has none of what a unit record carries — no hp, no attack rhythm, no acquired-target
## churn, no reach flag — and putting it on `UnitBoard` would mean eight fields that are meaningless
## for half the rows.
##
## PER-PLAYER, NOT MATCH-WIDE, so a shot's OWNER is structural rather than a stored field: the
## contact fact's attacker slot is the board it came from, and the self-contact invariant at
## `push_contact` therefore keeps a shot from ever hitting its own side without a filter that could
## be got wrong.
var projectiles: ProjectileBoard

## Story 3-5b (AC 3): the PENDING REPLACEMENT DRAW — a TimingWindow plus an owed COUNTER, the
## pair 3-5a's instant refill becomes once the replacement is a debt instead of an event. The
## window is advanced at MatchState.advance() step 2 beside the hero/pool timers; DELIVERY is
## step 6's, inside the one existing RNG seat. The counter is what makes several casts in flight
## expressible without a queue of cards: a delivery draws ONE card, decrements, and restarts the
## window while the counter is still above zero.
##
## NO CARD IDENTITY LIVES HERE, and that is deliberate rather than incidental: the card is drawn
## AT DELIVERY off whatever the pile then holds, so nothing is held in limbo and no StringName
## has to survive across ticks (a StringName reaching the snapshot is the failure mode Deck, Hand
## and DiscardPile all exist to avoid — Array[StringName].sort() orders by internal POINTER on
## this engine).
##
## STORY 4-0 (AC 4) CHANGES THE DEBT'S SHAPE, and `3-5b/R8`'s "a plain int COUNT and nothing more"
## is SUPERSEDED for exactly this reason: a count cannot say WHICH slot a replacement is owed to,
## and the whole story is that the replacement refills the slot its cast vacated. The debt is now
## a FIFO of owed SLOT INDICES — `pop_front()` at delivery, `append()` at cast, so the tie-break
## across simultaneously-owed slots is cast order (the Deferred section leaves that order free and
## requires only that no delivery ever lands in a slot it wasn't owed to).
##
## ONE SHARED WINDOW, NOT ONE PER SLOT (`4-0/R6` — FORCED, not chosen). Two shipped constraints
## close it: `3-5b/R8`'s one-timer, one-delivery-per-expiry cadence, which per-slot windows would
## break by construction (they deliver simultaneously); and `3-5b/R8`'s two-key snapshot bound,
## which this story relaxes only for this key's SHAPE — `hand_size` per-slot windows would put N
## TimingWindow dictionaries into the hash and make the window COUNT a hash cause every time
## `hand_size` is retuned.
##
## STILL NO IDENTITIES AND STILL NO NEW KEY (AC 6): these are slot INDICES, the counts-and-indices
## rule intact, and the key COUNT does not grow — `3-5b/R8`'s two-key bound survives as a count.
var pending_draw: TimingWindow
var pending_draw_owed: Array[int] = []

## Story 3-5b (AC 6): the RESHUFFLE VULNERABLE WINDOW — `pending_draw`'s sibling, started when
## this player's discard is folded back into their deck.
##
## NOTHING READS IT. That is not an omission, it is AC 2's mechanism for keeping OPEN decision
## (b) — what "vulnerable" COSTS — genuinely open rather than closed by construction: a
## TimingWindow cannot exist without a duration, so the duration is authored, but no damage,
## mitigation or action-state path consults the window, and a negative guard in
## test_deck_and_hand.gd fails if one ever does. The window's PUBLIC face is the match-wide
## EventBus event the reshuffle queues alongside it; 3-6 renders that.
##
## DELIBERATELY ABSENT FROM to_snapshot() (AC 4 pins the key set at exactly two new keys). It
## crosses tick boundaries, which normally forces a key — but the sibling rule cuts the other
## way here: state that NOTHING reads cannot change an outcome, so it cannot desync a replay
## either, and AC 2's guard is what keeps that premise true. Hashing it would also make the
## window's mere existence a hash cause every time its duration is retuned, which is precisely
## the coupling the counts-only snapshot discipline exists to avoid.
var vulnerable_window: TimingWindow

## Story 3-6 (AC 2): retained so notify_cards_changed() can enqueue. The three pools have each
## held the queue since E0 for the same reason; this composite needed none until it owned a
## signal of its own.
var _queue: SignalQueue


## Story 3-1 (AC 1/AC 3): constructed STAT-LESS. Every bound below now arrives by injection
## (MatchState._apply_balance_to_player, from the single-source-of-truth BalanceConfig), so
## this constructor carries no tunable and there is no second seeding path that could
## disagree with the injected one. The leaf objects keep their own explicit-bounds
## constructors — they are containers, and their unit tests build them with real bounds —
## but the one production caller hands them zeros and lets injection do the rest.
func _init(queue: SignalQueue) -> void:
	_queue = queue
	hero = HeroState.new(queue, 0.0, 0.0)
	stamina = StaminaPool.new(queue, 0.0, 0.0)  # filled by the D9 refill at first injection
	mana = ManaPool.new(queue, 0.0, 0.0)        # stays empty — the flywheel builds it
	orbs = OrbPool.new(queue)
	deck = Deck.new()
	hand = Hand.new()
	discard = DiscardPile.new()
	units = UnitBoard.new()
	unit_dedupe = UnitSwingDedupe.new()
	projectiles = ProjectileBoard.new()
	pending_draw = TimingWindow.new()
	vulnerable_window = TimingWindow.new()


## Story 3-6 (AC 2): QUEUE one card-observation payload (D5). Called from MatchState at the seats
## that move a card and NOWHERE ELSE — the deal, the cast, and the delayed replacement delivery —
## so a tick that moves no card announces nothing and the channel can never degrade into a
## per-tick push wearing a signal's clothes (AC 5's no-polling property, pinned by
## test_card_observation.gd::test_a_tick_that_moves_no_card_announces_nothing).
##
## The values are read and BOUND HERE, at push time, so the payload describes the containers as
## they were when the mutation completed. Two announcements in one tick (a cast whose replacement
## delivers on the same tick, the zero-delay degrade) therefore drain in order and the LAST one is
## the final state — never one stale payload overwriting a fresh one.
func notify_cards_changed() -> void:
	_queue.push(cards_changed.emit.bind(hand.to_array(), deck.size(), discard.size()))


func to_snapshot() -> Dictionary:
	return {
		"hero": hero.to_snapshot(),
		"stamina": stamina.to_snapshot(),
		"mana": mana.to_snapshot(),
		"orbs": orbs.to_snapshot(),
		# Story 3-3 (AC 5): COUNTS ONLY, never card identities. Deck ORDER is deliberately not
		# hash-visible — it stays derivable from seed plus injected composition — and a CardData
		# reference here would poison the hash outright (the canonical hash has no object branch
		# and would fall through to a per-allocation instance id).
		"deck_size": deck.size(),
		# Story 4-0 (AC 2, `4-0/R1`): bound to occupied_count(), NOT to size(). Hand.size() now
		# means WIDTH; occupied_count() is what size() meant when this key was written, so this
		# binding is what keeps the key's MEANING unchanged across the shape change — and it is
		# why cause 3 of this story's re-baseline is a non-mover (measured, not assumed: the
		# golden hashes at t24 with a cast at t22 against an 11-tick delay, so a hole is LIVE at
		# hash time and the width binding would read 9 where this reads 8).
		"hand_size": hand.occupied_count(),
		# Story 3-5a (AC 6): the ONE new snapshot key this story adds — the discard COUNT, on
		# the deck_size/hand_size precedent exactly. No ids, no per-card structure, no pile
		# ORDER: the same "counts only" rule, for the same reason (a StringName or a CardData
		# reaching the hash is the failure mode both siblings exist to avoid). This key moves
		# the golden BY ITSELF, at an all-zero value, before any cast behaviour runs — cause 1
		# of this story's re-baseline.
		"discard_size": discard.size(),
		# Story 3-5b (AC 4): the TWO new keys, and the reason they are keys at all is the rule
		# their siblings above are exempt from. `_deck_deal_pending` may be excluded because it is
		# consumed inside the same advance() that armed it; a pending draw is the opposite — a
		# pending draw that never crossed a tick would be an INSTANT draw, so crossing is the whole
		# feature. Both therefore enter the hash.
		#
		# The window rides as its own to_snapshot() dictionary, the shipped StaminaPool
		# `"regen_delay": _regen_delay.to_snapshot()` shape exactly; the debt rides as a plain int
		# COUNT, the deck_size/hand_size/discard_size shape exactly. Still no identities, still no
		# order — the counts-only rule is unbroken.
		#
		# STORY 4-0 (AC 4/AC 6) RESHAPES THE SECOND OF THE TWO: the debt is no longer a plain int
		# but the FIFO of owed SLOT INDICES (see the field's own comment for why a count cannot
		# express this story). Indices are not identities, so the counts-and-indices rule stands;
		# the key COUNT does not grow, so `3-5b/R8`'s two-key bound survives as a count. Unlike
		# its siblings above, this array's ORDER IS MEANINGFUL and CanonicalHash preserves it —
		# it is the delivery order, and two owed slots delivering in the wrong order is a real
		# divergence the hash should see.
		"pending_draw": pending_draw.to_snapshot(),
		"pending_draw_owed": pending_draw_owed.duplicate(),
		# Story 4-1 (AC 9): the ONE new key this story adds — the board COUNT, on the
		# deck_size / hand_size / discard_size precedent verbatim. NO unit identity, NO effect
		# id, NO position: the same counts-only rule, for the same measured reason (a StringName
		# or an object reaching the hash is the failure mode every card-container key in this
		# file exists to avoid — CanonicalHash has no object branch and Array[StringName].sort()
		# orders by internal POINTER on this engine).
		#
		# There is nothing else it COULD carry: `4-1/R12` ships the unit record positionless and
		# the ratified totem clause ships it type/kind-less, so UnitBoard holds a count and this
		# key is that count. See unit_board.gd's header.
		#
		# SCOPED, NOT A STANDING BOUND (`4-1/R12`). This wording binds THIS story's key only. It
		# must NOT be read as foreclosing state-owned unit position at `4-2`'s gate, which rules
		# between an inward position channel (the hero push_contact precedent) and state-owned
		# floats reaching the hash directly, once TargetingService exists as a real consumer.
		#
		# TWO SEPARATELY MEASURED GOLDEN CAUSES RIDE ON THIS ONE KEY: its mere PRESENCE at an
		# all-zero value (the snapshot-shape cause, the 3-5a `discard_size` / 4-0
		# `pending_draw_owed` pattern), and its VALUE moving 0 -> 1 from the golden fixture's t22
		# `summon_*` cast onward (the behavioural cause, confirmed at the gate as `4-1/R6`). Both
		# are measured and named separately in the Dev Agent Record.
		"unit_count": units.size(),
		# Story 4-2 (AC 11, `4-2/R2`): the ONE new key this story adds -- each unit's ACQUIRED
		# TARGET as a `[slot, index]` pair, in board-index order.
		#
		# IT IS A KEY AT ALL BECAUSE THE THROTTLE MAKES IT CROSS-TICK STATE, which is the same
		# argument `pending_draw` won on and the one `_deck_deal_pending` lost on: a target
		# re-evaluated only every N ticks CANNOT be recomputed for free every tick the way a
		# stateless per-frame scan could, so it persists between ticks and must be hashed or a
		# replay could silently diverge on it.
		#
		# STILL COUNTS AND INDICES, NEVER IDENTITIES (`4-2/R2`): both halves of every pair are
		# plain ints on the `pending_draw_owed` precedent ("these are slot INDICES, the
		# counts-and-indices rule intact", the field comment above). `index >= 0` addresses a unit
		# on the `slot`-identified player's board; `index == -1` addresses that player's hero; a
		# `slot` of -1 is TargetingService's no-target discriminator. No unit identity, no
		# StringName, no object and no position reaches the hash -- CanonicalHash has no object
		# branch and `Array[StringName].sort()` orders by internal POINTER on this engine.
		#
		# THE ORDER IS MEANINGFUL and CanonicalHash preserves it, exactly as it does for
		# `pending_draw_owed`: a target held by the wrong unit is a real divergence.
		#
		# TWO SEPARATELY MEASURED GOLDEN CAUSES RIDE ON THIS ONE KEY, and both are recorded in
		# the Dev Agent Record with their own intermediate hash: its mere PRESENCE at an
		# all-no-target value (the snapshot-shape cause, the 4-1 `unit_count` / 3-5a
		# `discard_size` pattern), and a unit ACTUALLY ACQUIRING a target at a throttle boundary
		# (the behavioural cause). AC 9's identity extension is NEITHER of them -- measured a
		# non-mover on its own (`4-2/R8`).
		"unit_targets": units.targets_snapshot(),
		# Story 4-3a (AC 9, `4-3a/R17`): the ONE new key this story adds -- each unit's HP, in
		# board-index order, on the `unit_targets` precedent verbatim.
		#
		# IT IS A KEY AT ALL FOR THE `pending_draw` REASON, NOT THE `_deck_deal_pending` ONE: hp
		# CROSSES TICKS and DECIDES AN OUTCOME (whether the next swing kills), so it cannot be
		# recomputed for free inside the tick that reads it. A value that crosses ticks and decides
		# an outcome does not sit outside the hash -- the same argument the swing-dedupe record's
		# own docstring makes for snapshotting mid-swing dedupe state.
		#
		# STILL COUNTS AND VALUES, NEVER IDENTITIES. A float per record is the same class of thing
		# as `hero.hp` two levels up; no unit identity, no StringName, no object and no position
		# joins the hash. CanonicalHash has no object branch, and `Array[StringName].sort()` orders
		# by internal POINTER on this engine -- the failure mode every container key in this file
		# exists to avoid.
		#
		# THE ORDER IS MEANINGFUL and CanonicalHash preserves it, exactly as for `unit_targets`: hp
		# held by the wrong unit is a real divergence. THIS KEY IS ALSO HOW A HOLE REACHES THE HASH
		# (AC 7) -- a dead unit is a 0.0 at a STABLE index, so the snapshot carries WHERE the hole
		# is, not merely that one exists. No separate hole key is authored, and that is deliberate:
		# liveness is derived from hp and stored nowhere, so a second key would be a second
		# expression of one fact.
		#
		# ONE GOLDEN CAUSE RIDES ON THIS KEY, not two: its mere PRESENCE at the authored maximum
		# from the golden fixture's t22 `summon_*` cast onward. The golden fixture is deliberately
		# NOT extended to INJURE a unit (that would be a third cause and is out of this story's
		# re-baseline scope) -- so there is no behavioural cause to measure separately here. The
		# story's SECOND named cause is elsewhere entirely: the widened swing-dedupe key shape.
		"unit_hp": units.hp_snapshot(),
		# Story 4-3b (AC 16): the unit ATTACK RHYTHM joins the hash — SIX new keys, and the count is a
		# DEV-PASS MEASUREMENT the story deliberately declined to assert, because the board's own
		# precedent runs both ways (one array -> one key for `unit_hp`, two arrays -> one FUSED key
		# for `unit_targets`). MEASURED HERE AS SIX: TWELVE -> EIGHTEEN.
		#
		# FIVE OF THE SIX ARE ONE-ARRAY-ONE-KEY, on the `unit_hp` side of that precedent, because
		# they are five INDEPENDENT facts rather than one fact expressed severally. `unit_targets`
		# fuses a slot and an index because a target IS one fact in two ints and splitting it would
		# let the halves drift into different keys; a phase and a countdown are not two halves of one
		# int pair, and fusing them would hide WHICH of them moved when the golden moves. The sixth is
		# the dedupe records, which are not on the board at all (see `unit_dedupe` above).
		#
		# EVERY ONE OF THEM CROSSES TICKS AND DECIDES AN OUTCOME, which is the `4-3a/R17` test for
		# whether a value may sit outside the hash: the phase and countdown decide when the hitbox
		# opens, the locked direction decides where the swing points, the counter keys the dedupe
		# records, the in-reach flag is the cross-tick carrier between a probe and the windup it
		# permits, and the dedupe records decide whether a second fact lands. None can be recomputed
		# for free inside the tick that reads it.
		#
		# STILL COUNTS AND VALUES, NEVER IDENTITIES. Ints, bools, `Vector2`s and arrays of ints —
		# every one of them a type `CanonicalHash` has an explicit branch for. No StringName (whose
		# `sort()` orders by internal POINTER on this engine), no object, and no position: the locked
		# DIRECTION is a normalised heading derived by the runner from two positions, the same class
		# of position-DERIVED datum the contact fact's `dir` has carried legally since 1-8, and
		# `4-3/R2` bans state OWNING a position, not learning a direction.
		"unit_attack_phase": units.attack_phase_snapshot(),
		"unit_attack_ticks": units.attack_ticks_snapshot(),
		"unit_attack_dir": units.attack_dir_snapshot(),
		"unit_attack_count": units.attack_count_snapshot(),
		"unit_in_reach": units.in_reach_snapshot(),
		"unit_swing_dedupe": unit_dedupe.snapshot(),
		# Story 4-4 (AC 1/AC 10): TWO new board keys — the per-record KIND INDEX and the per-record
		# firing-cadence COOLDOWN. One array -> one key apiece, on the `unit_hp` side of the
		# precedent this block's 4-3b note spells out, because a kind and a cooldown are two
		# independent facts and fusing them would hide which moved.
		#
		# STILL COUNTS AND INDICES, NEVER IDENTITIES. Both are plain ints: the kind is an INDEX into
		# the authored `BalanceConfig.unit_kinds` list, deliberately NOT the kind's StringName —
		# `Array[StringName].sort()` orders by internal POINTER on this engine, which is the failure
		# mode every container key in this file exists to avoid.
		#
		# ONE GOLDEN CAUSE RIDES ON THE PAIR, not two: their mere PRESENCE. The golden fixture's t22
		# cast summons a MINION, whose kind index is 0 and whose authored cadence is 0.0 — so both
		# keys hash at their zero values throughout the recorded sequence and neither has a
		# behavioural cause to measure separately. The named causes are recorded in the Dev Agent
		# Record.
		"unit_kind": units.kind_index_snapshot(),
		"unit_attack_cooldown": units.attack_cooldown_snapshot(),
		# Story 4-4 (AC 14-19): the PROJECTILE BOARD joins the hash — SEVEN keys, on the split
		# `UnitBoard` already established (the target FUSES its two ints because a target is one fact
		# in two halves; the rest are independent facts that fusing would hide).
		#
		# EVERY ONE OF THEM CROSSES TICKS AND DECIDES AN OUTCOME, which is `4-3a/R17`'s test: the
		# target decides where homing steers, the kind decides every authored number governing the
		# shot, liveness decides whether a later fact resolves at all (it IS the projectile's dedupe
		# — see `projectile_board.gd`'s header), the homing flag decides whether AC 16 has already
		# fired, the flight clock decides the current speed and the odometer decides the 60 m end.
		# None can be recomputed for free inside the tick that reads it.
		#
		# STILL COUNTS, INDICES AND VALUES, NEVER IDENTITIES. Ints, bools and floats only — no
		# StringName, no object, and no POSITION: `projectile_travelled` is a path LENGTH the state
		# layer integrates from the authored profile, not a coordinate anything pushed inward, so
		# `4-3/R2`'s position ownership and the single-intake rule are both untouched.
		"projectile_targets": projectiles.targets_snapshot(),
		"projectile_kind": projectiles.kind_index_snapshot(),
		"projectile_source": projectiles.source_index_snapshot(),
		"projectile_alive": projectiles.alive_snapshot(),
		"projectile_homing": projectiles.homing_snapshot(),
		"projectile_flight_ticks": projectiles.flight_ticks_snapshot(),
		"projectile_travelled": projectiles.travelled_snapshot(),
	}
