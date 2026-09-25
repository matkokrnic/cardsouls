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

## Story 4-6 (AC 2/AC 3, `CC/R2`): THE LOCK-ON TARGET -- what this player's hero is currently
## locked onto, as the `4-3a/R16` `[slot, index]` address whose home is
## `TargetingService.HERO_INDEX` (`index == -1` is that slot's hero).
##
## TWO PLAIN INTS RATHER THAN A PAIR, for the reason `UnitBoard` splits `_target_slots` /
## `_target_indices`: the read is per-tick and per-player and a pair allocates. They surface as
## ONE snapshot key (`lock_target`), the `unit_targets` fusion verbatim.
##
## THE RESTING VALUE is the OPPOSING HERO, set by `MatchState._init` and restored by
## `MatchState._apply_debug_reset` -- both know the slot, which this object deliberately does not (a
## PlayerState has never known its own index, and giving it one for this would be a new coupling
## for one field).
##
## Story 6-8 (AC 2, Open Question 1): THERE IS NOW AN UNLOCKED STATE, superseding `CC/R3`'s "No
## unlock state". It is a SENTINEL ADDRESS, `[UNLOCKED_SLOT, HERO_INDEX]`, held in these same two
## ints -- not a separate bool -- so the snapshot keeps ONE `lock_target` key with the same shape
## and the hashed key set does not move (Golden Prediction cause 1). See `UNLOCKED_SLOT` below.
##
## HASHED, not excluded: it CROSSES TICKS AND DECIDES AN OUTCOME (`4-3a/R17`) -- it decides where
## the hero faces, which decides the `_is_facing` block arc, so a replay whose heroes carried a
## different lock would diverge the moment one of them blocked.
var lock_target_slot: int = TargetingService.NO_TARGET_SLOT
var lock_target_index: int = TargetingService.HERO_INDEX

## Story 6-8 (AC 2, Open Question 1): the SLOT half of the unlocked sentinel address
## `[UNLOCKED_SLOT, TargetingService.HERO_INDEX]`.
##
## -2, NOT -1, and that is the measured reason the sentinel is distinguishable at all:
## `TargetingService.NO_TARGET_SLOT` and `HERO_INDEX` are both -1, so `[-1, -1]` is the
## pre-seed construction default and cannot also mean "unlocked" without making every
## unseeded PlayerState read as a deliberate player choice. No valid address has a slot outside
## {0, 1}, so -2 collides with nothing. The INDEX half is pinned to `HERO_INDEX` so `[-2, 0]` stays
## a malformed request the lock seat rejects (`5-1a` AC 1), not a second spelling of "unlock".
const UNLOCKED_SLOT := -2


## Story 6-8 (AC 2): TRUE unless this player has unlocked. A plain read of the two ints above, so
## the facing/roll rules in `MatchState` and the runner's camera and marker seats all ask the same
## question the same way.
func is_locked() -> bool:
	return lock_target_slot != UNLOCKED_SLOT

## Story 5-2 (AC 10/AC 21, `5-2/R9`): THE MODE ② CHARGEUP — the D4 window it runs on, and the
## COLOUR of the card that started it.
##
## SEATED HERE RATHER THAN ON `HeroState`, and that is a measured choice rather than a stylistic
## one. AC 21 requires the telegraph to ride the PINNED PER-PLAYER key set, because that is the set
## `5-2/R9`'s golden prediction is measured against; a window field on `HeroState` would move the
## golden through the hero sub-dictionary instead and the prediction would read as false while the
## story still appeared to pass. The chargeup is also a CARD-LAYER duration — it is started by a
## cast, not by a `TRANSITION_TABLE` edge (AC 7) — so it belongs beside `pending_draw`, the other
## window a cast starts, rather than beside the eight windows the melee table drives.
##
## THE WINDOW IS ADVANCED AT STEP 2 with every other D4 timer and READ at step 3(a) (AC 20), the
## `pending_draw` idiom verbatim: ticked in one place, consumed in another, never both.
var charge_window: TimingWindow
## The spent card's `Enums.CardColor` as a plain INT, or `NO_TELEGRAPH_COLOR` when nothing is
## charging. A plain int and never a `CardData`, a `StringName` or a colour name: the
## counts-and-indices rule every container key in this file follows, and the reason is the same one
## — `CanonicalHash` has no object branch and `Array[StringName].sort()` orders by internal POINTER
## on this engine.
##
## `1-10/R1` STAYS INTACT: this is a COLOUR, not a `TelegraphProfile`. The `ActionState ->
## TelegraphProfile` mapping remains controller-owned and nothing in `src/state/` names one.
var charge_color: int = NO_TELEGRAPH_COLOR
## Story 6-1c (AC 2/AC 4/AC 11): THE LANDING WINDOW -- counts the ticks from the cast to the LANDING,
## i.e. the chargeup PLUS this colour's launch span. Started at the cast in the same breath as
## `charge_window` above, and advanced beside it at step 2.
##
## TWO WINDOWS RUNNING TOGETHER, AND THAT IS THE WHOLE PHASE SHAPE. mode (2) stays ONE `ActionState`
## (`CHARGING`) from cast to landing; which half of it the hero is in is DERIVED from which window is
## running -- the `HeroState.attack_phase()` "phases are expressed by which window is running"
## precedent -- never stored as a flag:
##   * `charge_window` running          -> the CHARGEUP: rooted, tracking, and -- since `6-9` --
##                                        already committed, with nothing to release.
##   * `charge_window` stopped, this running -> THE LAUNCH: facing frozen, travelling along it.
##   * this stopped                     -> the LANDING, resolved at step 3(a) on that very tick.
## The LAUNCH point therefore exists BY CONSTRUCTION the instant the chargeup window closes: there
## is no "launched" bit an adversarial mutation could leave stale, and nothing can un-commit a hero
## because nothing restarts `charge_window` except a new cast. Since `6-9` the COMMITMENT is older
## still -- it is the PRESS (`_resolve_unblockable_cast`), and no input undoes it.
##
## STARTED AT THE CAST WITH ITS FULL DURATION rather than at the commit, so a mid-attack X3 reload
## cannot move the landing tick (the D4 rule: a window in flight keeps its duration) and so no
## "has the launch started yet" test is needed at the commit. It can never close BEFORE the chargeup
## window: both start on the same tick and its duration is the chargeup's plus a non-negative span.
##
## SEATED HERE, beside `charge_window`, for that window's stated reason: a card-layer duration a
## cast starts, riding the per-player key set.
var landing_window: TimingWindow

## Story 5-5 (AC 2): THE MODE ③ DEFENSE WINDOW — the reaction window a defense cast opens, and the
## COLOUR it can answer.
##
## SEATED HERE RATHER THAN ON `HeroState`, for the IDENTICAL reason `charge_window` directly above
## is: this is a CARD-LAYER duration started by a cast, not a `TRANSITION_TABLE` edge, so it belongs
## beside the other windows a cast starts rather than beside the eight windows the melee table
## drives. `HeroState` carries no `defense` window and gains none — its eight are `windup`,
## `active`, `recovery`, `chain`, `deflect`, `roll_iframe`, `roll_duration`, `stun`, and `deflect`
## there is `1-8`'s block-timing parry, a different mechanism entirely.
##
## THE WINDOW IS ADVANCED AT STEP 2 with every other D4 timer and READ at the LANDING (AC 9), the
## `charge_window` idiom verbatim: ticked in one place, consumed in another, never both.
##
## UNLIKE THE CHARGEUP IT OWNS NO `ActionState` (AC 5): casting mode ③ enters no state, roots
## nothing and slows nothing. The window is a pure data timer, exactly as `pending_draw` decides an
## outcome without owning an action state of its own.
var defense_window: TimingWindow
## The spent card's `Enums.CardColor` as a plain INT, or `NO_TELEGRAPH_COLOR` when no defense is
## armed. A plain int and never a `CardData`, a `StringName` or a colour name — `charge_color`'s own
## reasoning verbatim, for the same hash reason.
var defense_color: int = NO_TELEGRAPH_COLOR

## ------------------------------------------------------------------------------------------
## STORY 6-5c: THE CAST WINDOW AND THE IN-FLIGHT CAST'S IDENTITY (AC 1, AC 23).
## ------------------------------------------------------------------------------------------
## SEATED HERE RATHER THAN ON `HeroState`, for the IDENTICAL reason `charge_window` and
## `defense_window` above are: this is a CARD-LAYER duration started by a CAST, not by a
## `TRANSITION_TABLE` edge, so it belongs beside the other windows a cast starts rather than beside
## the nine windows the melee table drives.
##
## IT OWNS NO `ActionState` (`6-5c/R18`, the third application of the get-up / counter precedent):
## the commitment is derived from `is_casting()` below at all three lock seats, which is what keeps
## `test_unblockable_defense.gd::test_the_cast_introduces_no_action_state_of_its_own` green unedited.
##
## ADVANCED AT STEP 2 with every other D4 timer and READ at the step-6c strike seat -- the
## `charge_window` idiom verbatim: ticked in one place, consumed in another, never both.
var cast_window: TimingWindow

## WHICH CARD IS IN FLIGHT, as a String VALUE -- and the IN-FLIGHT FLAG itself: `""` means no cast.
##
## A `String`, NEVER A `StringName` AND NEVER A KEY, on `last_resolved_card_id`'s stated precedent and
## for its exact measured reason: `Array[StringName].sort()` orders by INTERNAL POINTER on this
## engine, so a StringName reaching the canonical hash is the failure mode every container key in
## this file exists to avoid. The strike seat converts back with `StringName()` to look the effect up
## in the injected map, which a replay reproduces from the record.
##
## THE IDENTITY IS ALSO THE FLAG, and that is deliberate rather than thrifty. "A cast is in flight"
## and "this is the card in flight" are one fact, and a separate bool could disagree with the id --
## the `telegraph` gate's own argument for deriving rather than storing. It also gives the right
## answer on the STRIKE TICK itself, where `cast_window` has already stopped at step 2 but the strike
## has not yet run at step 6c: the caster is still committed for that tick (AC 8's "from the press to
## the strike"), and `is_casting()` says so while `cast_window.is_running` would not.
##
## WHY AN ID AND NOT THE RESOLVED NUMBERS. Storing damage/stun/root at the press would make the
## framework name what a cast DOES, which is the resolver's job (D6) and would stop a later cast
## effect (6-5d/6-5e) from adopting the window without new fields here. An id plus a lookup keeps the
## framework total over every future cast outcome.
var cast_card_id: String = ""

## ------------------------------------------------------------------------------------------
## STORY 6-5c: THE ROOT (AC 17, AC 18).
## ------------------------------------------------------------------------------------------
## ONE WINDOW COVERING THE STUN AND THE ROOT TOGETHER, started at the strike with
## `stun_ticks + root_ticks` -- the `landing_window` shape verbatim (chargeup PLUS launch in one
## window, with WHICH phase you are in derived from the other window rather than stored). AC 17's
## "root starts when the stun ends" is therefore true BY CONSTRUCTION: on the tick the stun expires
## this window has exactly `root_ticks` left, and during the stun its blocks are redundant because
## `STUNNED` already hard-roots the body and refuses every press.
##
## THE ALTERNATIVE WAS A SECOND ARMING AT THE STUN'S EXIT, rejected because it needs the root's
## duration and both switches PARKED across the stun -- three more fields carrying a pending root --
## to express what one window already expresses.
##
## THE TWO SWITCHES ARE STORED, NOT RE-READ FROM THE EFFECT, because the effect is gone by then: the
## cast's identity is cleared at the strike, and a root outlives it by up to `root_seconds`. They are
## honest `bool`s rather than `rule_a`/`rule_b` floats on the timed-rule seat -- that seat documents
## its two slots as MAGNITUDES, and a bool punned into a float is a lie about the type the snapshot
## would then carry.
var root_window: TimingWindow
var root_blocks_run: bool = false
var root_blocks_roll: bool = false


## Story 6-5c (AC 8, `6-5c/R18`): IS THIS PLAYER COMMITTED TO A CAST RIGHT NOW? The ONE predicate all
## three commitment seats read -- the step-3 action lock, the step-6 card lock and the movement root
## -- so they cannot drift apart. `is_getting_up()`'s shape and role exactly.
func is_casting() -> bool:
	return cast_card_id != ""


## Story 6-5c (AC 1): ARM a cast. The duration is already in TICKS (converted once at the press, A1).
func start_cast(card_id: StringName, duration_ticks: int) -> void:
	cast_card_id = String(card_id)
	cast_window.start(duration_ticks)


## Story 6-5c (AC 5, AC 24): THE ONE STOP POINT for a cast -- the strike, every interrupt, the debug
## reset and round end all end it through here, `cancel_rule`'s single-stop-point discipline (R6)
## applied to the cast. Nothing is refunded here and nothing ever will be: the card and the mana were
## spent at the press (`6-5c/R3`), and a refund would have to live at a seat that knows what was paid.
func clear_cast() -> void:
	cast_card_id = ""
	cast_window.start(0)


## Story 6-5c (AC 17, AC 19): ARM (or RESTART, choice A) the root. `duration_ticks` is the stun plus
## the root, per `root_window`'s own comment. A non-positive duration clears the slot rather than
## leaving live switches on a stopped window -- `start_rule`'s N3 lesson applied verbatim.
func arm_root(duration_ticks: int, blocks_run: bool, blocks_roll: bool) -> void:
	if duration_ticks <= 0:
		clear_root()
		return
	root_window.start(duration_ticks)
	root_blocks_run = blocks_run
	root_blocks_roll = blocks_roll


## Story 6-5c (AC 18, AC 24): THE ONE STOP POINT for a root -- expiry aside, nothing else ends one.
func clear_root() -> void:
	root_window.start(0)
	root_blocks_run = false
	root_blocks_roll = false


## Story 6-5c (AC 17): the two INDEPENDENT switch reads, each asked at exactly one seat --
## `MatchState._resolve_movement`'s gait ladder and `_try_transition`'s ROLLING arm. Both are false
## whenever no root is running, so neither seat needs a second `is_running` test of its own.
func is_root_blocking_run() -> bool:
	return root_window.is_running and root_blocks_run


func is_root_blocking_roll() -> bool:
	return root_window.is_running and root_blocks_roll


## Story 6-5a (AC 8, OQ1): THE TIMED-RULE SEAT -- one rule shape for every per-player timed card effect,
## generalising the one-`TimingWindow`-per-rule precedent (`defense_window` above) into a FIXED ARRAY of
## rule slots indexed by `RULE_*`. Each slot is ONE window plus TWO magnitudes (`a`, `b`, meaning per
## kind below), so a rule is exactly one fact: whether it is running, how long it has left, and the
## numbers it applies -- all three hashed together under ONE snapshot key (`timed_rules`).
##
## A DURATION RULE AND AN ARMED TRIGGER ARE THE SAME SHAPE. For a buff the window is the buff; for a
## trigger (Bloodhound Step, Frostbite) the window is how long it stays armed, and CONSUMING it is
## cancelling it. That is what makes R6's "exactly one stop point per timed effect" structural: every
## rule ends through `cancel_rule(kind)` (or by its window expiring), and a future undo (6-5f) cancels
## through the same call.
##
## RE-APPLYING A RUNNING RULE REFRESHES IT (operator ruling N10): `start_rule` restarts the window at the
## full duration and overwrites the magnitudes -- it never stacks. Round end and the debug reset clear
## every rule (`clear_rules`).
##
## TICKS, NEVER SECONDS (A1): advanced at `MatchState.advance()` step 2 beside every other window,
## skipped on round-over ticks exactly as they are.
##
## THE KINDS, and what `a` / `b` hold for each:
##   RULE_BLOODLUST          buff on the CASTER: a = damage-dealt multiplier, b = damage-taken multiplier.
##   RULE_VAMPIRIC_AURA      buff on the CASTER: a = lifesteal fraction of hero damage actually removed.
##   RULE_BLOODHOUND_ARMED   trigger on the CASTER, consumed by its next roll that actually starts:
##                           a = roll distance multiplier, b = roll i-frame multiplier.
##   RULE_ROLL_BOOST         the boosted ROLL itself, started when the trigger above is consumed and
##                           running exactly as long as that roll: a = roll distance multiplier.
##   RULE_FROSTBITE_ARMED    trigger on the CASTER, consumed by its next confirmed hero melee hit on
##                           the enemy hero: a = slow speed multiplier, b = slow duration in TICKS.
##   RULE_FROSTBITE_SLOW     the slow, on the struck TARGET: a = movement speed multiplier.
const RULE_BLOODLUST := 0
const RULE_VAMPIRIC_AURA := 1
const RULE_BLOODHOUND_ARMED := 2
const RULE_ROLL_BOOST := 3
const RULE_FROSTBITE_ARMED := 4
const RULE_FROSTBITE_SLOW := 5
const RULE_COUNT := 6

var rule_windows: Array[TimingWindow] = []
var rule_a: Array[float] = []
var rule_b: Array[float] = []

## Story 6-5a (AC 10): THE LAST RESOLVED CARD -- which card this player last actually RESOLVED, and in
## which mode (`Enums.ModeKind.BASIC` or `Enums.ModeKind.PITCH`, the activation). Written at exactly the
## two APPLY seats that can carry a Deck 1 effect (`_resolve_basic_cast`, `_resolve_pitch_activate`);
## read by nothing in 6-5a -- it is 6-5f's Counterspell's target.
##
## PUBLIC, SO HASHED, on the `pitch_state.gd` staged-card precedent: a resolved card has already left
## the hand and been seen, so its identity is public exactly as a staged one is. The id is held and
## hashed as a String VALUE, never a key and never a StringName (the StringName-sort hazard,
## `pitch_state.gd:112-122`); the mode as its int ordinal. Resting value: `""` and `NO_RESOLVED_MODE`.
var last_resolved_card_id: String = ""
var last_resolved_card_mode: int = NO_RESOLVED_MODE

const NO_RESOLVED_MODE := -1

## Story 5-2 (AC 21): the resting value of `charge_color`, and it is a THIRD thing rather than a
## fourth colour — `Enums.CardColor` gets no `NONE` member, exactly as `TargetingService` answers
## "nothing" with a sentinel rather than by widening the address space. Readers test the NAME.
const NO_TELEGRAPH_COLOR := -1

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
	charge_window = TimingWindow.new()
	landing_window = TimingWindow.new()
	defense_window = TimingWindow.new()
	# Story 6-5c: the cast and root windows, built beside their card-layer siblings above.
	cast_window = TimingWindow.new()
	root_window = TimingWindow.new()
	for _kind in RULE_COUNT:
		rule_windows.append(TimingWindow.new())
		rule_a.append(0.0)
		rule_b.append(0.0)


## Story 6-5a (AC 8): START (or REFRESH, N10) one timed rule. A duration of zero ticks leaves it stopped,
## the `TimingWindow.start(0)` contract, so a zero-authored window applies nothing.
##
## 6-5a REVIEW N3: a non-positive duration CANCELS the slot rather than writing live magnitudes onto a
## stopped window. Through the dev pass the two assignments below ran unconditionally, which left
## `rule_a`/`rule_b` holding real numbers on a window `start(0)` had left stopped. That was unobservable
## -- every reader gates on `is_rule_active` and `_rules_snapshot` masks a stopped slot to
## `[0, 0.0, 0.0]` -- so the snapshot comment's "a stale magnitude is unrepresentable" was true of the
## HASH but not of the STATE. It becomes observable for 6-5f's undo, which cancels through this seat.
## Routing through `cancel_rule` makes the claim true of the state too, and keeps ONE stop point (R6).
func start_rule(kind: int, duration_ticks: int, a: float, b: float) -> void:
	if duration_ticks <= 0:
		cancel_rule(kind)
		return
	rule_windows[kind].start(duration_ticks)
	rule_a[kind] = a
	rule_b[kind] = b


## Story 6-5a (AC 8, R6): THE ONE STOP POINT for a rule of any kind -- expiry aside, nothing else ends
## one. Consuming an armed trigger is cancelling it; a future undo cancels through here too.
func cancel_rule(kind: int) -> void:
	rule_windows[kind].start(0)
	rule_a[kind] = 0.0
	rule_b[kind] = 0.0


func is_rule_active(kind: int) -> bool:
	return rule_windows[kind].is_running


## Story 6-5a (N10): round end and the debug reset clear every running rule and armed trigger.
func clear_rules() -> void:
	for kind in RULE_COUNT:
		cancel_rule(kind)


## Advanced at `MatchState.advance()` step 2, beside every other D4 window.
func tick_rules() -> void:
	for window: TimingWindow in rule_windows:
		window.tick()


## Story 6-5a (AC 10): the one writer of the last-resolved-card record.
func record_resolved_card(card_id: StringName, mode: int) -> void:
	last_resolved_card_id = String(card_id)
	last_resolved_card_mode = mode


## Story 6-5a (REVIEW B1, operator ruling): the last-resolved-card record is CLEARED by round end and by
## the debug reset, exactly as `clear_rules()` beside it -- the NINTH named reset exception. Without this
## the record was round-crossing hashed state that nothing cleared and no test pinned, so a reset match
## and a fresh match sat at different resting snapshots at the same point. Back to the resting pair.
func clear_resolved_card() -> void:
	last_resolved_card_id = ""
	last_resolved_card_mode = NO_RESOLVED_MODE


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


## Story 6-1d (AC 4): THE CONTACT WINDOW -- is this player's mode ② attack committed, i.e. may a
## geometric contact observed RIGHT NOW credit its landing?
##
## ONE DEFINITION, TWO CALLERS, and that is the whole reason this is a method on `PlayerState`
## rather than an expression written twice. The RUNNER reads it to decide whether to run the blade
## overlap query at all (the launch-phase gate `6-1d/R1` requires -- `is_hitbox_active()` is melee's
## and must not grow a CHARGING branch), and `MatchState.push_contact` reads THE SAME call to decide
## whether an arriving charge-reach fact may latch. Two layers agreeing by construction instead of
## by two expressions that could drift apart.
##
## READ FROM THE WINDOWS, never from a flag: the phase shape this file already describes above --
## `charge_window` running is the chargeup, stopped is the launch. `remaining_ticks() <= 1`
## rather than `not is_running` because both callers read it BEFORE `advance()` ticks the windows, so
## the tick that will CLOSE the chargeup still reports one tick left when they ask. That tick is
## already inside the launch for reach purposes (and since `6-9` no input ends a chargeup at all),
## and it is the ONLY evaluated tick when a colour authors no launch span at all -- excluding it
## would make every launch-less chargeup miss by construction.
##
## THE UPPER BOUND IS `landing_window`: once it has stopped the landing has resolved and nothing
## more may be credited. AC 4's "opens AT COMMIT and never earlier" is therefore a property of this
## expression, not of a caller remembering to check a phase.
func is_contact_window_open() -> bool:
	return landing_window.is_running and charge_window.remaining_ticks() <= 1


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
		# Story 5-5 (AC 16): the ONE new key this story adds -- the ARMED DEFENSE, as
		# `[colour, remaining_ticks]`. The `telegraph` FUSION verbatim and for the same reason: a
		# defense is ONE fact in two halves (what colour, how much longer), and splitting it would
		# let the halves drift into two keys that could disagree about whether a defense is armed at
		# all. Resting value `[-1, 0]` -- `NO_TELEGRAPH_COLOR` and a stopped window.
		#
		# THE UNIT IS TICKS, never seconds, for `telegraph`'s stated reason (A1).
		#
		# IT IS A KEY AT ALL FOR THE `pending_draw` REASON: the window CROSSES TICKS AND DECIDES AN
		# OUTCOME (whether an incoming unblockable lands at all), so it cannot be recomputed for free
		# inside the tick that reads it -- `4-3a/R17`'s test, passed. Remaining ticks alone is
		# determinism-complete on the identical argument: the duration is
		# `balance_ticks.counter_busy_ticks_for(defense_color)`, a load-time constant a replay
		# reproduces from the recorded balance, so `elapsed` is recoverable as `duration - remaining`.
		#
		# THE GATE IS `.is_running`, NOT AN ACTION STATE, AND THAT DIFFERENCE IS DELIBERATE. Its
		# `telegraph` sibling gates on `CHARGING` because that is the ONE state a chargeup ever
		# occupies, which makes a stale colour unrepresentable by construction. Mode ③ has NO
		# analogous state -- casting it never enters one (AC 5) -- so there is no action state to
		# gate on, and the window's own flag is the only honest gate. This is NOT a weaker
		# guarantee: the window goes non-running on EVERY path that ends it (natural expiry;
		# consumption by a successful defense, AC 10; the debug reset, AC 12), and the one remaining
		# path through the landing branch -- a DEAD defender -- never consults the window at all,
		# because the branch's own `is_alive()` gate precedes the colour check. A stale colour is
		# exactly as unrepresentable as the telegraph's, by a different mechanism because there is a
		# different shape underneath it. Do NOT copy the `CHARGING` gate onto a state that does not
		# exist.
		#
		# ONE GOLDEN CAUSE RIDES ON THIS KEY: its mere PRESENCE. This is the `5-2` shape and NOT the
		# `5-4` one -- `5-4`'s `orbs` key already existed, so adding a grant path behind it moved
		# nothing, while THIS key is genuinely new and its resting value changes the snapshot
		# dictionary's SHAPE on every tick of every match, cast or not.
		"defense": [defense_color, defense_window.remaining_ticks()] \
				if defense_window.is_running \
				else [NO_TELEGRAPH_COLOR, 0],
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
		# Story 4-6 (AC 2/AC 4): the ONE new key this story adds -- this player's LOCK-ON TARGET
		# as a `[slot, index]` pair, the `unit_targets` shape verbatim and the same
		# counts-and-indices rule (`4-2/R2`): two plain ints, no identity, no StringName, no
		# object and no position.
		#
		# IT IS A KEY AT ALL FOR THE `unit_targets` REASON EXACTLY. The lock persists between
		# ticks -- it changes only on a click, a flick, or the locked target's death -- so it
		# cannot be recomputed for free inside the tick that reads it, and a value that crosses
		# ticks and decides an outcome does not sit outside the hash (`4-3a/R17`). What it
		# decides is where the hero FACES, and facing decides the `_is_facing` block arc, so a
		# replay whose heroes carried a different lock would diverge the moment one blocked.
		#
		# THE DIRECTION IS NOT HERE, and deliberately so. The lock's TARGET is state; the
		# world-space DIRECTION to it is a runner-gathered spatial fact pushed through
		# `MatchState.set_lock_direction` (`4-6/R6`) and captured by its own record channel --
		# the `_camera_bases` classification, not this one. State learns a direction; it never
		# owns a position (`4-3/R2`).
		"lock_target": [lock_target_slot, lock_target_index],
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
		# Story 6-5b (AC 1/AC 14, `6-5b/R17`): THREE new board keys -- the per-record CORPSE COUNTDOWN,
		# the per-corpse GRAVE WARD MARK, and the RAISE SOURCE. One array -> one key apiece, on the
		# `unit_kind` / `unit_attack_cooldown` pair's own stated reason: three independent facts, and
		# fusing any of them would hide which moved.
		#
		# EVERY ONE CROSSES TICKS AND DECIDES AN OUTCOME (`4-3a/R17`): the countdown decides whether a
		# corpse can still be extended or raised, the mark decides what it renders as until it is
		# removed, and the source decides where a raised minion is placed. None is recomputable inside
		# the tick that reads it -- the death that created the corpse is ticks in the past.
		#
		# STILL COUNTS, VALUES AND INDICES, NEVER IDENTITIES, AND STILL NO POSITION. A raise source is a
		# board INDEX (the `unit_targets` class, `4-2/R2`); the corpse's LOCATION is actor-owned and
		# never enters state (`6-5b/R1`), so `4-3/R2` is untouched -- this is the one place a reader
		# might expect a `Vector3` and there is deliberately none.
		#
		# THE GOLDEN CAUSE THAT RIDES ON ALL THREE IS THEIR MERE PRESENCE, measured rather than
		# assumed: the determinism fixture's t22 summon never dies (`test_determinism.gd`), so the
		# countdown and the mark hash at their resting 0 / false and the source at its resting -1 on
		# every hashed tick. There is no behavioural cause to measure separately for them.
		"unit_corpse_ticks": units.corpse_ticks_snapshot(),
		"unit_corpse_extended": units.corpse_extended_snapshot(),
		"unit_raised_from": units.raised_from_snapshot(),
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
		# Story 5-2 (AC 21/AC 22, `5-2/R9`): the ONE new key this story adds -- the ACTIVE
		# TELEGRAPH, as `[colour, remaining_ticks]`. The `lock_target` FUSION verbatim and for the
		# same reason: a telegraph is ONE fact in two halves (what colour, how much longer), and
		# splitting it would let the halves drift into two keys that could disagree about whether a
		# telegraph is running at all. Resting value `[-1, 0]` -- `NO_TELEGRAPH_COLOR` and a stopped
		# window.
		#
		# THE UNIT IS TICKS, never seconds. Seconds would put a float derived from `TICK_HZ` into the
		# hash for a value the tick ladder already holds as an integer, and A1's whole point is that
		# gameplay-critical timing is counted in ticks.
		#
		# IT IS A KEY AT ALL FOR THE `pending_draw` REASON, not the `_deck_deal_pending` one: the
		# chargeup CROSSES TICKS AND DECIDES AN OUTCOME (when the landing check runs, and therefore
		# whether the hit lands at all), so it cannot be recomputed for free inside the tick that
		# reads it -- `4-3a/R17`'s test, passed.
		#
		# REMAINING TICKS ALONE IS DETERMINISM-COMPLETE, and that is reasoned rather than assumed: the
		# window's duration is `balance_ticks.unblockable_chargeup_ticks`, a load-time constant a
		# replay reproduces from the recorded balance, so `elapsed` is recoverable as
		# `duration - remaining` and two runs that agree on remaining cannot disagree on elapsed.
		#
		# IT IS A PER-PLAYER KEY, NOT A HERO ONE (AC 21 is explicit): seating it inside
		# `hero.to_snapshot()` would move the golden without moving THIS set, and the story's own
		# golden prediction is stated against THIS set.
		#
		# THE KEY IS GATED ON `CHARGING`, WHICH IS WHAT MAKES A STALE TELEGRAPH UNREPRESENTABLE
		# RATHER THAN MERELY UNLIKELY (the project's guard-mechanism-over-guard-pattern rule). The
		# fields below are written at the cast and, on the two paths that end a chargeup WITHOUT a
		# reset -- a hero that lands, and one killed mid-chargeup (AC 15) -- nothing clears them, so
		# either would otherwise carry its last colour forever. Deriving the key from the action state
		# instead means "the active telegraph" is true by construction, with no clear path to forget.
		#
		# STORY 5-3 (fix pass) NARROWS THAT LIST BY ONE: the DEBUG RESET now clears all three fields
		# explicitly (`MatchState._reset_player`, the second named exception to the reset's
		# "in-flight windows untouched" contract). That is not redundancy with the gate -- the gate
		# keeps the SNAPSHOT honest, while the reset has to stop the WINDOW itself, or a chargeup
		# frozen by the round-over freeze would land inside the next round.
		"telegraph": [charge_color, charge_window.remaining_ticks()] \
				if hero.action_state == HeroState.ActionState.CHARGING \
				else [NO_TELEGRAPH_COLOR, 0],
		# Story 6-1c (AC 2/AC 4): the ONE new key this story adds -- the LANDING WINDOW's remaining
		# ticks. It is a key at all for the `pending_draw` reason: the window CROSSES TICKS AND DECIDES
		# AN OUTCOME (when the attack commits, how long it travels, and on which tick it lands), so it
		# cannot be recomputed for free inside the tick that reads it -- `4-3a/R17`'s test, passed.
		#
		# REMAINING TICKS ALONE IS DETERMINISM-COMPLETE, on `telegraph`'s own argument: the duration is
		# `unblockable_chargeup_ticks + unblockable_launch_ticks_for(charge_color)`, load-time constants
		# a replay reproduces from the recorded balance, so `elapsed` is recoverable. Together with
		# `telegraph` it also pins the PHASE: chargeup remaining > 0 is the chargeup; chargeup 0 with
		# this > 0 is the launch.
		#
		# UNGATED, unlike `telegraph`, deliberately: there is no colour here to go stale, only a window
		# whose own remaining count is the truth on every path -- it reads 0 at rest, after a landing,
		# after a knockdown or counter abandonment and after a reset (each of those stops it), and a
		# hero killed mid-launch
		# carries the window's real count until it expires. Gating it on CHARGING would HIDE that
		# count from the hash rather than make anything unrepresentable.
		#
		# ONE GOLDEN CAUSE RIDES ON THIS KEY: its mere PRESENCE (the `5-2`/`5-5` shape). The golden
		# fixture never casts mode (2), so its VALUE is the resting 0 on every hashed tick.
		"landing": landing_window.remaining_ticks(),
		# Story 6-5c (AC 1/AC 23): the IN-FLIGHT CAST, as `[card id, remaining ticks]`. The `defense`
		# FUSION verbatim and for the same reason: a cast is ONE fact in two halves (which card, how
		# much longer), and splitting it would let the halves drift into two keys that could disagree
		# about whether a cast is in flight at all. Resting value `["", 0]`.
		#
		# THE GATE IS `is_casting()`, NOT `cast_window.is_running`, and the difference is load-bearing
		# on exactly one tick: the STRIKE tick, where step 2 has already stopped the window and step 6c
		# has not yet struck. The hero is still committed there, and the snapshot says so.
		#
		# IT IS A KEY AT ALL FOR THE `pending_draw` REASON: the cast CROSSES TICKS AND DECIDES AN
		# OUTCOME (when the strike lands, and therefore whether it lands at all), so it cannot be
		# recomputed for free inside the tick that reads it -- `4-3a/R17`'s test, passed. Remaining
		# ticks alone is determinism-complete: the duration is `seconds_to_ticks(effect.cast_seconds)`,
		# a load-time constant a replay reproduces from the recorded content, so elapsed is recoverable.
		"cast": [cast_card_id, cast_window.remaining_ticks()] \
				if is_casting() else ["", 0],
		# Story 6-5c (AC 17/AC 23): the ROOT, as `[remaining ticks, blocks run, blocks roll]` -- the
		# `timed_rules` per-slot fusion applied to one root: three halves of one fact, gated on the
		# window so a stopped root reads `[0, false, false]` whatever the switches last held and a
		# stale switch is unrepresentable in the hash. Resting `[0, false, false]`.
		#
		# EVERY HALF CROSSES TICKS AND DECIDES AN OUTCOME (`4-3a/R17`): the countdown decides how much
		# longer running and rolling are gone, and each switch decides WHICH of the two is. The window
		# spans the stun plus the root (see `root_window`), so the count is honest through both.
		"root": [root_window.remaining_ticks(), root_blocks_run, root_blocks_roll] \
				if root_window.is_running else [0, false, false],
		# Story 6-5a (AC 8): the TIMED-RULE SEAT, ONE key for all six rule slots, as
		# `[remaining_ticks, a, b]` per slot in `RULE_*` order. The `defense` fusion applied per slot: a
		# rule is one fact in three halves, gated on its window's `is_running` so a stopped rule reads
		# `[0, 0.0, 0.0]` whatever it last held -- a stale magnitude is unrepresentable in the hash. It
		# is a key at all for the `pending_draw` reason: every rule CROSSES TICKS AND DECIDES AN OUTCOME
		# (a multiplier, a heal, a roll's reach, a slow). Remaining ticks alone is determinism-complete:
		# the magnitudes ride beside it and nothing reads the elapsed count.
		#
		# ONE GOLDEN CAUSE RIDES ON THIS KEY in the golden fixture: its mere PRESENCE (the golden never
		# casts a buff, so every slot hashes at rest).
		"timed_rules": _rules_snapshot(),
		# Story 6-5a (AC 10): the LAST RESOLVED CARD, `[id, mode]` -- the `defense`-key two-element shape.
		# The id is a String VALUE (never a StringName, never a key); the mode an int ordinal. Resting
		# `["", -1]`. It is a key because it CROSSES TICKS and 6-5f's Counterspell will decide an outcome
		# from it. TWO GOLDEN CAUSES RIDE ON IT: its PRESENCE, and its VALUE moving from the golden
		# fixture's t22 basic cast onward.
		"last_resolved_card": [last_resolved_card_id, last_resolved_card_mode],
	}


func _rules_snapshot() -> Array:
	var out: Array = []
	for kind in RULE_COUNT:
		var window := rule_windows[kind]
		out.append([window.remaining_ticks(), rule_a[kind], rule_b[kind]] if window.is_running \
				else [0, 0.0, 0.0])
	return out
