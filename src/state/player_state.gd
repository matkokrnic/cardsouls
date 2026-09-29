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
## STORY 6-5d (AC 12/AC 13/AC 24/AC 30): WHAT ELSE THE CAST CARRIES -- the MODE it strikes in, the
## TARGET captured at cast start, and the DAMAGE locked before it.
## ------------------------------------------------------------------------------------------
## `cast_card_id` ALONE CANNOT ANSWER MODE, and that is the gap 6-5d had to close. The strike seat
## looks the effect up by card id, and Bloodhound Step's BASIC effect (the roll buff) and its PITCH
## effect (Fireball) are two different effects under ONE id -- so a pitch cast and a basic cast of the
## same card were indistinguishable. `cast_effect_mode` is the discriminator: an `Enums.ModeKind` ordinal, and
## `NO_CAST_EFFECT_MODE` while nothing is in flight. AC 12 ("a Bloodhound Step Fireball never arms a roll
## buff") is this member and nothing else.
##
## AN ORDINAL RATHER THAN THE EFFECT ID ITSELF, deliberately. Storing the effect id would put a second
## identity in flight that could disagree with `cast_card_id`, and it would still not say WHICH MAP the
## replay must look it up in -- the mode says both, and it is the same vocabulary
## `record_resolved_card` already snapshots one key away.
##
## SPELLED `cast_effect_mode`, NOT `cast_mode`, AND THAT IS AN INVARIANT RATHER THAN A PREFERENCE.
## `cast_mode` is a RESERVED CONTROLLER-SCHEME TOKEN -- the input binding that arms the cast modifier --
## banned outside `src/controllers/` by `test_architecture_invariants.gd::CARD_SCHEME_BANNED_TOKENS`
## (story 3-5a AC 1: "swapping the scheme touches one folder"). The first spelling of this member tripped
## that guard, which is the guard working: this is a WHICH-EFFECT discriminator, an entirely different
## fact from the press that produced it, and the name now says so.
const NO_CAST_EFFECT_MODE := -1
var cast_effect_mode: int = NO_CAST_EFFECT_MODE

## Story 6-5d (AC 24, `6-5d/R6`/`R7`/`R15`): THE CAPTURED TARGET, as the `[slot, index]` pair
## `lock_target` and `unit_targets` already use (`4-2/R2`'s convention). Captured ONCE at cast start
## and FIXED for the whole cast and the flight: a re-lock or an unlock after the press changes nothing,
## which is true BY CONSTRUCTION here because nothing but `start_cast` ever writes these.
##
## IT IS NOT `lock_target`, AND THAT DISTINCTION IS THE WHOLE OF `6-5d/R15`. `lock_target` is LIVE and
## snaps back to the opposing hero when a locked unit dies; this is a FROZEN COPY, so a bolt whose
## minion died mid-cast hits NOTHING rather than falling on the snap-back hero. Two members precisely
## because the two facts must be able to disagree.
##
## RESTING `[NO_TARGET_SLOT, HERO_INDEX]` -- `lock_target`'s own resting pair, so the resting snapshot
## carries the same neutral address the lock does rather than a second spelling of "nothing".
var cast_target_slot: int = TargetingService.NO_TARGET_SLOT
var cast_target_index: int = TargetingService.HERO_INDEX

## Story 6-5d (AC 7/AC 13/AC 14): THE DAMAGE THE STRIKE WILL DEAL, carried from the STAGING that froze
## it, through the cast, to the projectile record. Zero for every cast whose damage is authored on the
## effect instead (Honed Bolt reads `effect.damage_amount` at its landing and never reads this).
##
## IT RIDES THE CAST RATHER THAN BEING RE-READ, because by the strike tick the staged record is GONE:
## `pitch.clear(slot)` ran at the activation press, ticks earlier. This is the same reason
## `root_blocks_run`/`root_blocks_roll` are stored rather than re-read from the effect one family up.
var cast_damage: float = 0.0

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


## ------------------------------------------------------------------------------------------
## STORY 6-5e (AC 8/AC 11a, `6-5e/R18`/C2, `6-5e/R21`/G2): THE PENDING BURST.
## ------------------------------------------------------------------------------------------
## A Rocksling cast fires `boulders_per_cast` stones, one after another, an authored interval apart
## (ruling 2). The FIRST leaves at the strike; the rest are still owed, and what owes them is THIS record.
##
## IT IS SEPARATE FROM THE CAST, AND THAT SEPARATION IS RULING 6a/C2 ITSELF. The cast is CLEARED at the
## strike (`_resolve_cast_strikes` clears it before applying the outcome, so the strike can never observe
## its own caster as still casting), and from that instant the caster is FREE -- it moves and acts, a stun
## does not stop the remaining stones, and there is no lock and no root. Storing the burst on `cast_*`
## would have made "committed to a cast" and "still owed stones" the same fact, which is exactly the fact
## ruling 6a splits in two.
##
## IT IS HASHED CROSS-TICK STATE (`6-5e/R21`/G2, AC 38, Golden Prediction cause 1a) on `4-3a/R17`'s test,
## passed plainly: it CROSSES TICKS AND DECIDES OUTCOMES -- how many more shots exist, when each appears,
## what each one hits and for how much -- and none of it is recomputable inside the tick that reads it. The
## cast that armed it is gone.
##
## SIX MEMBERS, ONE SNAPSHOT KEY, on the `cast` key's own fusion precedent and for its reason: a burst is
## ONE fact in six halves, and six keys would let them drift into a schedule that disagrees with itself
## about whether a burst is pending at all.

## The effect the burst's remaining stones are authored by -- the flight profile, and the discriminator
## that makes each stone plant a Boulder. A `String`, NEVER a `StringName`, on `cast_card_id`'s stated and
## measured reason: this member reaches the canonical hash and `Array[StringName].sort()` orders by
## internal POINTER on this engine. `""` MEANS NO BURST IS PENDING and is the single discriminator
## (`has_pending_burst()`), the `cast_card_id` posture verbatim -- no sibling count could disagree with it.
var burst_effect_id: String = ""

## How many stones are STILL OWED, never how many the cast fired. Decremented as each leaves; reaching
## zero clears the whole record through the one stop point.
var burst_remaining: int = 0

## The interval clock. `TimingWindow`, ticked at step 2 beside every other D4 window, read by the step-6d
## burst seat -- the `cast_window` idiom verbatim (A1: integer ticks, one per `advance()`, never a float
## accumulator).
var burst_window: TimingWindow

## The address every stone in this burst is aimed at -- CAPTURED ONCE at the cast's press and copied off
## the cast at the strike (AC 9). A re-lock or an unlock changes nothing already scheduled, which is true
## by this being a copy rather than a live read.
var burst_target_slot: int = TargetingService.NO_TARGET_SLOT
var burst_target_index: int = TargetingService.HERO_INDEX

## The per-stone damage, copied off the effect at the strike so every stone in one burst deals the same
## figure even if `damage_amount` is retuned mid-flight -- `cast_damage`'s freeze, one seat later.
var burst_damage: float = 0.0


## IS A BURST STILL OWED? The ONE predicate the burst seat and both teardown paths read, so they cannot
## drift apart. `is_casting()`'s shape and role exactly.
func has_pending_burst() -> bool:
	return burst_effect_id != ""


## Story 6-5e (AC 8): ARM the burst. `interval_ticks` is already TICKS (converted once at the strike, A1)
## and `remaining` is what is owed AFTER the strike's own first stone has left.
##
## A NON-POSITIVE REMAINING CLEARS THE RECORD rather than leaving a live effect id on an empty schedule --
## `start_rule`'s N3 lesson and `start_root`'s application of it, verbatim. A one-stone Rocksling therefore
## leaves no burst pending at all, which is what keeps the resting snapshot honest for `boulders_per_cast
## = 1`.
func start_burst(effect_id: StringName, remaining: int, interval_ticks: int,
		target_slot: int, target_index: int, damage: float) -> void:
	if remaining <= 0:
		clear_burst()
		return
	burst_effect_id = String(effect_id)
	burst_remaining = remaining
	burst_window.start(interval_ticks)
	burst_target_slot = target_slot
	burst_target_index = target_index
	burst_damage = damage


## THE ONE STOP POINT for a burst (AC 11a) -- the last stone leaving, the caster's death, round end and the
## debug reset all end it through here, `clear_cast`'s single-stop-point discipline applied to the burst.
## Nothing is refunded and nothing ever will be: the card and the mana were spent a whole cast ago.
func clear_burst() -> void:
	burst_effect_id = ""
	burst_remaining = 0
	burst_window.start(0)
	burst_target_slot = TargetingService.NO_TARGET_SLOT
	burst_target_index = TargetingService.HERO_INDEX
	burst_damage = 0.0


## ------------------------------------------------------------------------------------------
## STORY 6-5e (ruling 14, AC 38/AC 40): CORPSE BOMB'S PER-ACTIVATION CONVERSION RECORD.
## ------------------------------------------------------------------------------------------
## `6-5f`'s Counterspell will need to know WHICH of this player's minions one Corpse Bomb activation turned
## into corpses and skulls (ruling 14). This story implements NO undo and decides NO Counterspell
## semantics; it only makes sure the fact is present in hashed state and readable back (AC 40).
##
## IT IS NOT A PURE FUNCTION OF THE CORPSE CONTAINER, MEASURED RATHER THAN ASSUMED (AC 38's allowance,
## declined with a reason). `UnitBoard`'s corpse fields are the remaining lifetime, the Grave-Ward
## extension flag and the raised-from index; a Corpse Bomb corpse is created through the SAME death seat
## every other kill uses (AC 30) and enters with the SAME full lifetime, so a corpse made by Corpse Bomb
## and one made by a melee kill on the same tick are bit-identical in that container. There is nothing
## there to derive the partition from, so the record is stored -- Golden Prediction cause 2, a real cause.
##
## ONE ACTIVATION'S WORTH, NOT A LOG. `last_resolved_card`'s scope exactly: the LAST one, overwritten by
## the next, cleared at round end and at the debug reset. A growing per-match log would be unbounded
## hashed state, and `6-5f` answers the card that just resolved -- which is the same tick this was written.
const NO_CORPSE_BOMB_TICK := -1

## The `_tick` the activation landed on, or `NO_CORPSE_BOMB_TICK`. The DISCRIMINATOR, `cast_card_id`'s
## posture: an empty index list with a live tick is a Corpse Bomb that converted nothing, which is
## unreachable (the board gate refuses a zero-minion activation, AC 33) and still representable honestly.
var corpse_bomb_tick: int = NO_CORPSE_BOMB_TICK

## The board indices this activation converted, ASCENDING (the seat walks `living_indices()`, which is
## ascending by construction). Plain ints -- the counts-and-indices rule, no identity and no position.
## ITS ORDER IS MEANINGFUL and `CanonicalHash` preserves it.
var corpse_bomb_indices: Array[int] = []


## Story 6-5e (AC 38/AC 40): RECORD one Corpse Bomb activation. The OWNER is implicit -- this is that
## player's own `PlayerState` and a `UnitBoard` belongs to exactly one player, so an owner field would be
## a third spelling of which object this is (`_apply_culling`'s "the opponent is unreachable, not
## filtered" argument).
##
## The array is COPIED IN, never aliased, on `4-0`'s own review patch: `pending_draw_owed`'s snapshot
## aliased the live array and had to be fixed, and the lesson applies at the write seat too.
func record_corpse_bomb(tick: int, indices: Array[int]) -> void:
	corpse_bomb_tick = tick
	corpse_bomb_indices = indices.duplicate()


## THE ONE STOP POINT, `clear_cast`'s discipline: round end and the debug reset both clear it, for
## `clear_resolved_card`'s reason verbatim (REVIEW B1, `6-5a`) -- it is round-crossing hashed state, and a
## round that has ended holds no activation `6-5f` could answer.
func clear_corpse_bomb() -> void:
	corpse_bomb_tick = NO_CORPSE_BOMB_TICK
	corpse_bomb_indices.clear()


## Story 6-5c (AC 8, `6-5c/R18`): IS THIS PLAYER COMMITTED TO A CAST RIGHT NOW? The ONE predicate all
## three commitment seats read -- the step-3 action lock, the step-6 card lock and the movement root
## -- so they cannot drift apart. `is_getting_up()`'s shape and role exactly.
func is_casting() -> bool:
	return cast_card_id != ""


## Story 6-5c (AC 1): ARM a cast. The duration is already in TICKS (converted once at the press, A1).
##
## STORY 6-5d (AC 12/AC 13/AC 24): FOUR MORE ARGUMENTS, and every one of them is CAPTURED HERE because
## here is the press -- the mode this cast strikes in, the target address it froze, and the damage the
## staging locked. Widened rather than split into a second `start_pitch_cast`, so there stays exactly
## ONE place a cast begins and the four facts cannot be armed without it.
func start_cast(card_id: StringName, duration_ticks: int, mode: int,
		target_slot: int, target_index: int, damage: float) -> void:
	cast_card_id = String(card_id)
	cast_window.start(duration_ticks)
	cast_effect_mode = mode
	cast_target_slot = target_slot
	cast_target_index = target_index
	cast_damage = damage


## Story 6-5c (AC 5, AC 24): THE ONE STOP POINT for a cast -- the strike, every interrupt, the debug
## reset and round end all end it through here, `cancel_rule`'s single-stop-point discipline (R6)
## applied to the cast. Nothing is refunded here and nothing ever will be: the card and the mana were
## spent at the press (`6-5c/R3`), and a refund would have to live at a seat that knows what was paid.
func clear_cast() -> void:
	cast_card_id = ""
	cast_window.start(0)
	# Story 6-5d: the four carried facts are cleared WITH the identity, at the one stop point, so a
	# finished cast can never leave a stale mode, target or damage behind for the next one to inherit --
	# `PitchState.clear`'s own reasoning, and what lets the snapshot key below be honest without a
	# second gate per element.
	cast_effect_mode = NO_CAST_EFFECT_MODE
	cast_target_slot = TargetingService.NO_TARGET_SLOT
	cast_target_index = TargetingService.HERO_INDEX
	cast_damage = 0.0


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

## Story 6-5f (AC 5, `6-5f/R31`): WHEN that card resolved -- the `MatchState._tick` the apply seat ran on,
## written by `record_resolved_card` beside the id and the mode and cleared by `clear_resolved_card` with
## them. The operator closed gate blocker B1 on exactly this shape: it rides the EXISTING
## `last_resolved_card` snapshot key as its THIRD member, so the per-player KEY COUNT does not move on this
## cause -- only the array's own arity (the `cast` key's 2 -> 6 extension, `6-5d`, is the standing precedent
## for widening a fused key rather than adding one).
##
## IT IS COUNTERSPELL'S WINDOW CLOCK AND NOTHING ELSE READS IT. `counter_window_seconds` is a MAXIMUM AGE
## (`6-5f/R4`), so the gate needs the resolution's own tick to subtract from the activation's; there is no
## `TimingWindow` for it because there is nothing running -- a window that counts down would have to be
## started per resolution and cancelled per overwrite, which is two mechanisms for one subtraction.
##
## A TICK NUMBER, NOT A COUNTDOWN, is therefore the deliberate shape, and it is the ONE place this project
## hashes an absolute tick rather than a remaining count -- `corpse_bomb_tick` is the precedent that made
## it acceptable (`6-5e` ruling 14), for the same reason: the fact is WHEN something happened, and a
## countdown would be a derived view of it that needs a clock of its own to stay true.
##
## RESTING `NO_RESOLVED_TICK`, which is `corpse_bomb_tick`'s own `-1` posture: not a valid tick, so it
## collides with no real resolution, and `last_resolved_card_id == ""` is the predicate readers actually
## test (see `has_resolved_card`).
var last_resolved_card_tick: int = NO_RESOLVED_TICK

const NO_RESOLVED_TICK := -1

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
	# Story 6-5e: the burst interval clock, built beside the cast window whose strike arms it.
	burst_window = TimingWindow.new()
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


## ------------------------------------------------------------------------------------------
## STORY 6-5f (AC 2/AC 28, OPEN QUESTION 1 RESOLVED): THE REVERSAL RECORD -- "what did this resolution
## actually do, in enough detail to undo it".
## ------------------------------------------------------------------------------------------
## THE SHAPE CHOSEN, AND WHY (the story left this mechanism-open and asked the dev pass to argue it):
## ONE PER-PLAYER PACKET, OVERWRITTEN IN LOCKSTEP WITH `last_resolved_card`, rather than a family of
## per-effect-id parallel fields. That is the story's own "deliberate leaning" tried first and found
## correct, and the argument it makes is the decisive one: `6-5f/R6` ("resolving ANY card overwrites the
## target") and `6-5f/R5` ("countering CLEARS the target") are then ONE overwrite semantic expressed at one
## seat, not two mechanisms that could drift into disagreeing about what the current target is. The
## alternative would have needed seven fields' worth of clearing rules kept in agreement with the id field
## that decides which of them is live, and the failure mode is silent: a stale Boom packet beside a fresh
## Culling id reverses the wrong resolution.
##
## `record_resolved_card` IS THEREFORE ALSO THE CLEAR, and the two apply seats CALL IT BEFORE THE EFFECT
## APPLIES (see `MatchState._resolve_basic_cast` / `_resolve_pitch_activate`, where the call moved above the
## cast fork for exactly this reason). The apply arms then fill the packet they know is empty. One write
## site, one overwrite, no ordering to remember at seven arms.
##
## IT IS ADDITIVE TO `hand_covered`, `burst` AND `corpse_bomb` AND REDEFINES NONE OF THEM (AC 2). Boom's
## reversal records WHICH SLOTS ITS OWN RESOLUTION UNCOVERED, which the per-slot cover mask structurally
## cannot answer ("is slot N covered now" is not "did THIS Boom uncover slot N"); the mask, the burst
## schedule and the conversion record are all read unchanged and written by nobody here.
##
## NO CARD ID AND NO EFFECT ID IS IN IT, deliberately, which is why `SNAPSHOT_ID_PATHS` gains no member:
## the KIND below is a small int enum, and Boom's restored Boulders are re-covered from
## `MatchState._boulder_card_id` -- the same single authored source `_place_boulder` plants from -- rather
## than from a `String` per slot that would be a second copy of one constant riding the hash.
##
## THE KINDS. `REVERSAL_NONE` is the resting value AND the whole of the no-target rule: a resolution this
## story cannot undo -- Counterspell itself (AC 9), any of the seven cards deferred to `6-5g` (AC 13's
## interim rule), a `spell_*` fixture no-op, a totem summon, a flag-closed cast -- leaves the packet at
## NONE and is refused by the ONE gate, with no per-case list anywhere. That is what makes AC 9's "no
## special-case code" and AC 13's "no new refusal reason" true by construction rather than by two branches.
const REVERSAL_NONE := 0
const REVERSAL_VANGUARD := 1
const REVERSAL_CULLING := 2
const REVERSAL_GRAVE_WARD := 3
const REVERSAL_RAISE_DEAD := 4
const REVERSAL_DRAIN := 5
const REVERSAL_BOOM := 6

var reversal_kind: int = REVERSAL_NONE

## THE PER-ELEMENT COLUMNS. FIVE PARALLEL ARRAYS, index-aligned, in the order the resolution touched
## things -- `UnitBoard`'s own parallel-array shape and `rule_a`/`rule_b`'s own GENERIC-COLUMN-WITH-A-
## PER-KIND-MEANING-TABLE convention (see `start_rule`), applied to a record instead of a rule. Generic
## columns beat seven differently-shaped arrays for the reason that seat already banked: every column is a
## plain int, float or bool, so nothing here can lose an element type, order a StringName by pointer, or
## depend on a Dictionary's iteration order.
##
## WHAT EACH COLUMN HOLDS, PER KIND (the `RULE_*` table's shape):
##   REVERSAL_VANGUARD     `indices` = [the summoned record's board index]. Nothing else.
##   REVERSAL_CULLING      `indices` = the board indices it killed, ascending.
##                         `amount`  = the mana it ACTUALLY added (post-clamp delta, AC 14).
##   REVERSAL_GRAVE_WARD   `indices` = the corpse indices it touched, ascending.
##                         `a`       = the ticks it added to each.
##                         `flags`   = whether THIS cast newly set that corpse's extended mark.
##   REVERSAL_RAISE_DEAD   `indices` = the corpse indices it CONSUMED, ascending.
##                         `a`       = each of those corpses' remaining ticks AT consumption.
##                         `b`       = the board index of the record raised from it, or `NO_RAISED_RECORD`.
##                         `flags`   = each of those corpses' extended mark at consumption.
##   REVERSAL_DRAIN        `indices` = [the board index it sacrificed].
##                         `amount`  = the hp it ACTUALLY healed (post-clamp delta, AC 14).
##   REVERSAL_BOOM         `indices` = the victim's hand slots it uncovered, ascending.
##                         `amount`  = the hp it ACTUALLY removed, summed over its hits (AC 14).
##
## `amount` IS THE ONE-SHOT SCALAR AND IS A SUM WHERE THE EFFECT HIT MORE THAN ONCE. Boom applies damage
## per Boulder and the refund is one heal of the total, which is the honest reversal: the clamp AC 15 binds
## is the caster's own max hp at the refund, not per hit. It is measured as the pool's own before-minus-after
## delta at every one of the three seats, NEVER as `_funnel_damage`'s pre-application return (AC 14).
var reversal_indices: Array[int] = []
var reversal_a: Array[int] = []
var reversal_b: Array[int] = []
var reversal_flags: Array[bool] = []
var reversal_amount: float = 0.0

## The resting value of `reversal_b` -- a consumed corpse that raised nothing (an unresolvable kind; see
## `MatchState._apply_raise_dead`). `-1`, `UnitBoard.NO_RAISE_SOURCE`'s own posture: not a valid board index,
## so it collides with no real record.
const NO_RAISED_RECORD := -1


## Story 6-5a (AC 10): the one writer of the last-resolved-card record.
## STORY 6-5f (AC 5/AC 28): it takes the RESOLUTION TICK (`6-5f/R31`) and it CLEARS THE REVERSAL PACKET --
## the single overwrite semantic argued at `reversal_kind`. Callers invoke it BEFORE the effect applies, so
## the arms below fill an empty packet.
func record_resolved_card(card_id: StringName, mode: int, tick: int) -> void:
	last_resolved_card_id = String(card_id)
	last_resolved_card_mode = mode
	last_resolved_card_tick = tick
	clear_reversal()


## Story 6-5f (AC 4/AC 11): has this player resolved a card at all? The predicate the target gate reads
## rather than re-testing the id against `""` at the seat -- `UnitBoard.has_index`'s discipline (one
## expression of a bound, wired to by every guard) applied to a record.
func has_resolved_card() -> bool:
	return last_resolved_card_id != ""


## Story 6-5f (AC 2): RECORD what the resolution just did. ONE writer for every arm, so a packet can never
## be half-written: the arm hands whole columns and the kind in one call, and the arity agreement between
## the columns is this function's own guard rather than six arms' discipline.
##
## THE COLUMNS ARE COPIED, never aliased -- `record_corpse_bomb`'s own 4-0 review patch, which found exactly
## this bug at exactly this kind of key. The apply arms build local lists and would otherwise keep mutating
## the packet's own arrays after the fact.
func record_reversal(kind: int, indices: Array[int], a: Array[int], b: Array[int],
		flags: Array[bool], amount: float) -> void:
	Invariant.check(kind != REVERSAL_NONE,
		"a reversal record must name a real kind -- REVERSAL_NONE is the CLEARED state, not a record")
	Invariant.check((a.is_empty() or a.size() == indices.size()) \
				and (b.is_empty() or b.size() == indices.size()) \
				and (flags.is_empty() or flags.size() == indices.size()),
		"reversal columns must be empty or index-aligned with %d indices (a=%d b=%d flags=%d)" \
				% [indices.size(), a.size(), b.size(), flags.size()])
	reversal_kind = kind
	reversal_indices = indices.duplicate()
	reversal_a = a.duplicate()
	reversal_b = b.duplicate()
	reversal_flags = flags.duplicate()
	reversal_amount = amount


## Story 6-5f (AC 10/AC 28, `6-5f/R5`): THE ONE STOP POINT for a reversal record -- `cancel_rule`'s own
## discipline applied to the packet. Reached from THREE places and nowhere else: `record_resolved_card`
## above (a new resolution overwrites the old target), `clear_resolved_card` below (both per-round teardown
## seats), and `MatchState._apply_counterspell` the instant it finishes reversing (which is the whole of
## AC 10 -- a countered card stops being a target, so a second copy reads NONE and is refused).
func clear_reversal() -> void:
	reversal_kind = REVERSAL_NONE
	reversal_indices.clear()
	reversal_a.clear()
	reversal_b.clear()
	reversal_flags.clear()
	reversal_amount = 0.0


## Story 6-5a (REVIEW B1, operator ruling): the last-resolved-card record is CLEARED by round end and by
## the debug reset, exactly as `clear_rules()` beside it -- the NINTH named reset exception. Without this
## the record was round-crossing hashed state that nothing cleared and no test pinned, so a reset match
## and a fresh match sat at different resting snapshots at the same point. Back to the resting pair.
## STORY 6-5f (AC 5/AC 28): the TICK and the REVERSAL PACKET clear here too, with the id and the mode and on
## the same tick -- which is how AC 28's "cleared at both existing teardown seats" is satisfied with NO new
## teardown line at either seat. The packet's whole meaning is "what the card named by this record did", so
## a record that is gone cannot leave one behind; folding the clear in here rather than adding
## `clear_reversal()` beside the twelve other clears is the same single-overwrite argument `reversal_kind`
## makes for the write side.
func clear_resolved_card() -> void:
	last_resolved_card_id = ""
	last_resolved_card_mode = NO_RESOLVED_MODE
	last_resolved_card_tick = NO_RESOLVED_TICK
	clear_reversal()


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
## STORY 6-5e (AC 24/AC 24a): THE PAYLOAD CARRIES THE VISIBLE LAYER, `hand.visible_array()` -- a Boulder
## on top of whatever card its slot holds, the card layer everywhere else. The channel, its arity, its
## types and its seats are UNCHANGED, which is AC 24 exactly: "the only channel is
## `PlayerState.cards_changed(hand_ids, ...)`, per-player, rendered only in the owning viewport's own hand
## row". No second payload element and no second seam ships, so nothing about a Boulder's presence, count
## or slot reaches any surface that did not already carry this player's own hand contents (`P3`, unbroken).
##
## THE HUD THEREFORE NEEDS NO NEW BRANCH ORDERING TO GET AC 24a RIGHT: `_render_hand_row`'s first branch
## renders whatever id a slot shows and its `pending_draw_owed` branch is an `elif`, so a covered slot
## shows the Boulder and takes precedence over the in-flight caption for free. See `Hand.visible_array`.
func notify_cards_changed() -> void:
	_queue.push(cards_changed.emit.bind(hand.visible_array(), deck.size(), discard.size()))


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


## ------------------------------------------------------------------------------------------
## STORY 6-5e: THE DECLARED SET OF ID-CARRYING SNAPSHOT PATHS -- a MECHANISM REPLACEMENT, not a widened
## allow-list, and it is the one `test_card_effect_resolution.gd` asked for BY NAME in advance.
## ------------------------------------------------------------------------------------------
## That file's counts-only scan walks every value at every depth of this snapshot and fails on any
## `String` / `StringName` / object, because a StringName reaching `CanonicalHash` orders by internal
## POINTER on this engine. Two paths were exempted by literal, and its own note fixed the trigger:
##
##   "A THIRD exemption is the signal to replace the mechanism rather than extend the list again -- at
##    that point the right shape is a declared set of id-carrying paths on `PlayerState` itself, not a
##    third literal here."
##
## THIS STORY IS THAT THIRD (the `burst` key carries the effect id its remaining stones are authored by),
## so the shape it named is built here rather than the list extended a third time -- `3-0d/R20` applied as
## instructed: a guard evaded (or outgrown) twice gets its mechanism replaced, never its pattern widened
## again.
##
## DECLARING IT HERE IS WHAT MAKES IT A MECHANISM. The allow-list now lives beside the snapshot it
## describes, so a future key that carries an id declares itself in the same file and the same edit -- and
## a key that carries one WITHOUT declaring it still fails the scan, unchanged. The scan is not weakened:
## it still visits every value at every depth, and it still asserts each declared path is a plain `String`
## and not a `StringName`.
##
## EVERY MEMBER IS A CARD OR EFFECT ID HELD AS A `String` VALUE, hashed BY CONTENT through
## `CanonicalHash`'s String branch. Card identity in the hash is ruled safe on the `pitch_state._card_ids`
## precedent (a resolved, staged or in-flight card is public information).
## A PATH ENDING IN `[]` IS A FAMILY: every element of the array at that path, however many there are.
## Needed because `projectile_effect` is one id PER LIVE SHOT, so its paths are `/projectile_effect[0]`,
## `[1]`, ... and no fixed list could name them. The reader (`test_card_effect_resolution.gd`) checks every
## PRESENT element of a family is a plain `String`, and does not require the family to be non-empty -- an
## empty board is the resting case. A SCALAR path is still required to be present, unchanged, which is what
## keeps a stale scalar declaration from rotting into a blanket permission.
const SNAPSHOT_ID_PATHS: Array[String] = [
	# Story 6-5a (AC 10): the last resolved card's id.
	"/last_resolved_card[0]",
	# Story 6-5c (AC 1/AC 23): the in-flight cast's card id.
	"/cast[0]",
	# Story 6-5e (AC 11a): the pending burst's EFFECT id -- the first member that is an effect id rather
	# than a card id, which is exactly why the literal list had run out of room. Same type, same branch,
	# same public-information argument: the effect a visible burst of stones is authored by.
	"/burst[0]",
	# Story 6-5d (AC 30), DECLARED AT THE 6-5e REVIEW FIX (MAJOR 1): the per-shot EFFECT id on the
	# projectile board. It has carried a `String` id since 6-5d and was never declared here -- not because
	# anyone argued it should not be, but because the scan that would have caught it was reading a fixture
	# with no live projectile in it. Making the scan non-vacuous (MAJOR 1) is what surfaced it, which is the
	# mechanism working: an id-carrying key must declare itself, and this one now does.
	#
	# THE FIRST FAMILY MEMBER, and the reason the `[]` convention above exists at all.
	"/projectile_effect[]",
]


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
		# Story 6-5e (AC 16-19/AC 38, Golden Prediction cause 1): THE PER-SLOT COVER MASK -- which of this
		# player's hand slots a Boulder currently sits on. A plain `Array[bool]`, width-long, in the
		# hand's own slot order, which `CanonicalHash` has an explicit branch for and whose ORDER IS
		# MEANINGFUL (a Boulder on the wrong slot is a real divergence).
		#
		# IT IS A KEY AT ALL FOR THE `pending_draw` REASON: a cover CROSSES TICKS AND DECIDES OUTCOMES --
		# which slots the next stone may choose (AC 16), which presses are refused (AC 17a), what Boom
		# detonates (AC 25), and how slow its holder walks (AC 37a) -- and none of that is recomputable
		# inside the tick that reads it.
		#
		# WHAT IS UNDERNEATH IS NOT HERE AND THAT IS ARGUED, NOT OMITTED -- see `Hand.covers_snapshot`:
		# the covered card never leaves `Hand._cards`, so "what id is underneath" is the hand's own
		# contents, already the THIRD member of `test_replay_identity.gd`'s unhashed-cross-tick exclusion
		# set. Hashing it here would move an existing excluded fact into the hash and poison it with a
		# StringName rather than add a fact.
		#
		# THE LIVE BOULDER COUNT IS NOT A SECOND KEY (Golden Prediction cause 5c, argued as a NON-cause):
		# the Boulder slow reads `hand.cover_count()`, which is a pure fold over exactly this array, so a
		# `boulder_count` sibling would be a derived duplicate that could disagree with it.
		#
		# RESTING VALUE: all-false, width-long -- `[]` before the first deal (the width arrives at
		# `Hand.clear`), `[false, false, false, false]` after it at the shipped `hand_size`.
		"hand_covered": hand.covers_snapshot(),
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
		# Story 6-5f (AC 23/AC 28, `6-5f/R32`): the FOURTH corpse key -- the hp each record held
		# IMMEDIATELY BEFORE it died. It sits HERE, beside the three corpse keys it belongs with, because
		# this literal is grouped BY STORY and not alphabetically (`unit_count` is 120 lines up); the
		# SORTED position the two key-set pins carry is between `unit_hp` and `unit_in_reach`. One array ->
		# one key, on the three keys above's own stated reason: an independent fact, and fusing it into
		# `unit_hp` would hide which of the two moved.
		#
		# IT CROSSES TICKS AND DECIDES AN OUTCOME (`4-3a/R17`), and it is the sharpest example of the rule
		# in the file: `kill_at` overwrites the living hp with zero, so a reversal that must put a minion
		# back at what it held "immediately before death" (`6-5f/R29`) has NO other source for the number.
		# See `UnitBoard._hp_at_death` for why it is not derivable and why it deliberately outlives the
		# corpse.
		#
		# THE OPERATOR NAMED IT A GOLDEN CAUSE IN ADVANCE (`6-5f/R32`, Golden Prediction cause 2's second
		# half) -- measured separately from the reversal record, not folded into it.
		"unit_hp_at_death": units.hp_at_death_snapshot(),
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
		# Story 6-5d (AC 30): TWO new projectile keys -- the EFFECT ID authoring a hero-sourced shot's
		# flight and its per-shot LOCKED DAMAGE. See `projectile_board.gd`'s `effect_id_snapshot` for why
		# they are two keys and not one, and `_effect_ids` for why the id rides as a `String`.
		#
		# BOTH CROSS TICKS AND DECIDE AN OUTCOME (`4-3a/R17`): the effect id decides every authored number
		# governing the shot AND whether the target-only, no-block, Bloodlust-inclusive rules apply to it
		# at all; the damage decides what it hits for and is not derivable from any config a replay could
		# re-read, because the staging that computed it is ticks in the past.
		#
		# THESE TWO ARE THE PER-PLAYER KEY-SET MOVE this story predicted (Golden Prediction cause 4):
		# 38 -> 40. The `cast` extension is a separate cause and moves no key (see that key).
		"projectile_effect": projectiles.effect_id_snapshot(),
		"projectile_damage": projectiles.damage_snapshot(),
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
		# STORY 6-5d (AC 30) EXTENDS THIS KEY TO SIX ELEMENTS RATHER THAN ADDING FOUR KEYS, and the
		# choice is the `defense`/`root`/`telegraph` fusion argument taken at face value: all six are
		# halves of ONE fact -- the cast in flight -- and splitting them would let them drift into keys
		# that could disagree about whether a cast is in flight at all. `root` is the standing precedent
		# for a THREE-element fusion of a countdown plus its carried switches; this is that shape with
		# three more carried facts.
		#
		# IT IS ALSO WHY THE PER-PLAYER KEY SET DOES NOT MOVE ON THIS CAUSE. The story's Golden
		# Prediction cause 2 allowed either shape and asked the dev pass to record which: extending the
		# key moves the hash (a six-element array is not a two-element one) and leaves
		# `EXPECTED_PLAYER_SNAPSHOT_KEYS` at its count, so cause 2 and the key-set move are cleanly
		# separated causes rather than one event with two symptoms.
		#
		# ORDER: card id, remaining ticks, mode, target slot, target index, locked damage. Resting
		# `["", 0, NO_CAST_EFFECT_MODE, NO_TARGET_SLOT, HERO_INDEX, 0.0]` -- each element's own resting value,
		# never a second spelling of "nothing". Still a String VALUE and plain ints and floats: no
		# StringName reaches the hash (`Array[StringName].sort()` orders by internal POINTER here).
		#
		# EVERY NEW ELEMENT CROSSES TICKS AND DECIDES AN OUTCOME (`4-3a/R17`): the mode decides WHICH
		# effect the strike resolves (AC 12), the target address decides where the bolt lands and where
		# the Fireball is aimed (AC 24), and the damage decides what it hits for (AC 7). None is
		# recomputable inside the tick that reads it -- the staging that froze the damage and the lock
		# reading that froze the target are both ticks in the past, and the lock itself may have moved.
		"cast": [cast_card_id, cast_window.remaining_ticks(), cast_effect_mode,
					cast_target_slot, cast_target_index, cast_damage] \
				if is_casting() \
				else ["", 0, NO_CAST_EFFECT_MODE, TargetingService.NO_TARGET_SLOT,
					TargetingService.HERO_INDEX, 0.0],
		# Story 6-5e (AC 11a/AC 38, `6-5e/R21`/G2, Golden Prediction cause 1a): THE PENDING BURST, as
		# `[effect id, stones remaining, remaining ticks, target slot, target index, per-stone damage]`.
		# The `cast` key's SIX-ELEMENT FUSION verbatim and for its reason: a burst is ONE fact in six
		# halves, and six keys would let them drift into a schedule that disagrees with itself about
		# whether a burst is pending at all. Resting
		# `["", 0, 0, NO_TARGET_SLOT, HERO_INDEX, 0.0]` -- each element's own resting value.
		#
		# THE GATE IS `has_pending_burst()`, NOT `burst_window.is_running`, and the difference is
		# load-bearing on exactly one tick for the `cast` key's reason: the LAUNCH tick, where step 2 has
		# already stopped the interval window and step 6d has not yet launched. A stone is still owed
		# there, and the snapshot says so. It is also the ONLY honest gate at a zero authored interval,
		# where the window is never running at all.
		#
		# IT IS A KEY AT ALL FOR THE `cast` REASON, ONE SEAT LATER: every half CROSSES TICKS AND DECIDES
		# AN OUTCOME -- the count decides how many shots still exist, the clock decides when each
		# appears, the address decides what each may hit (AC 9's freeze), the damage decides for how
		# much -- and NONE of it is recomputable inside the tick that reads it, because the cast that
		# armed it was cleared at the strike. Remaining ticks alone is determinism-complete on the
		# `cast` argument: the interval is `seconds_to_ticks(effect.boulder_interval_seconds)`, a
		# load-time constant a replay reproduces from the recorded content.
		#
		# IT IS WHAT RULING 6a/C2 IS DECIDED FROM, which is the plainest statement of why it is hashed:
		# the mid-burst stun case reads it and does nothing, and the caster-death, round-end and
		# debug-reset cases each read it and clear it (AC 11a).
		"burst": [burst_effect_id, burst_remaining, burst_window.remaining_ticks(),
					burst_target_slot, burst_target_index, burst_damage] \
				if has_pending_burst() \
				else ["", 0, 0, TargetingService.NO_TARGET_SLOT,
					TargetingService.HERO_INDEX, 0.0],
		# Story 6-5e (ruling 14, AC 38/AC 40, Golden Prediction cause 2): CORPSE BOMB'S LAST
		# CONVERSION, as `[activation tick, [converted board indices]]` -- the OWNER implicit in whose
		# snapshot this is (`record_corpse_bomb`'s own argument). Resting `[NO_CORPSE_BOMB_TICK, []]`.
		#
		# FUSED, on the `cast`/`burst` argument: the tick and the list are halves of one activation, and
		# an index list with no tick would not say WHEN, which is one of the three facts ruling 14 names.
		#
		# A REAL CAUSE, NOT A PURE FUNCTION -- see `corpse_bomb_tick` for the measurement: a Corpse Bomb
		# corpse and a melee-kill corpse made on the same tick are bit-identical in `UnitBoard`, so there
		# is nothing in the corpse container to derive this partition from.
		#
		# THE LIST IS COPIED, never aliased -- `pending_draw_owed`'s own 4-0 review patch, which found
		# exactly this bug at exactly this kind of key.
		"corpse_bomb": [corpse_bomb_tick, corpse_bomb_indices.duplicate()],
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
		# STORY 6-5f (AC 5, `6-5f/R31`, Golden Prediction cause 1): A THIRD MEMBER -- the RESOLUTION TICK.
		# The key count does NOT move on this cause and the array's arity does, which is the `cast` key's
		# 2 -> 6 extension precedent (`6-5d`) applied a second time and for its reason: the tick is a half
		# of the SAME fact ("which card resolved, in which mode, when"), and a `last_resolved_tick` key
		# beside this one could drift into naming a tick for a card this key no longer holds.
		#
		# IT CROSSES TICKS AND DECIDES AN OUTCOME (`4-3a/R17`): with a nonzero `counter_window_seconds` it
		# decides whether the card is counterable at all (AC 7), and it is not recomputable inside the tick
		# that reads it -- the resolution is by definition in the past. Resting `["", -1, -1]`, each
		# element's own resting value.
		"last_resolved_card": [last_resolved_card_id, last_resolved_card_mode,
					last_resolved_card_tick],
		# Story 6-5f (AC 2/AC 28, Open Question 1, Golden Prediction cause 2): THE REVERSAL RECORD, as
		# `[kind, indices, a, b, flags, amount]`. The `burst` key's SIX-ELEMENT FUSION verbatim and for its
		# reason: a reversal record is ONE fact in six columns, and six keys would let them drift into a
		# packet that disagrees with itself about which resolution it describes.
		#
		# MASKED TO RESTING WHEN THE KIND IS `REVERSAL_NONE`, which is the `timed_rules` / `root` /
		# `defense` gating discipline: a stale column is then unrepresentable in the hash, not merely
		# unread. `clear_reversal()` already empties every column, so the mask is belt-and-braces against
		# a future arm that sets a column without a kind -- and it is what makes the RESTING-EMPTY case
		# (Golden Prediction cause 2's own sub-cause) hash identically to a cleared one.
		#
		# EVERY COLUMN CROSSES TICKS AND DECIDES AN OUTCOME (`4-3a/R17`), and the packet is the sharpest
		# case in the file: it is written at one resolution and read, if ever, at a LATER activation by the
		# other player, so none of it is recomputable inside the tick that reads it -- the board has moved
		# on, corpses have aged and slots have been covered since. See `reversal_kind` for the per-kind
		# meaning of each column.
		#
		# COUNTS, VALUES AND INDICES ONLY -- no card id, no effect id, no position. `reversal_indices` holds
		# board indices or hand slots (the `unit_targets` / `corpse_bomb` class, `4-2/R2`), so
		# `SNAPSHOT_ID_PATHS` gains no member and `test_card_effect_resolution.gd`'s counts-only scan needs
		# no exemption. That is deliberate: see `reversal_kind` for why Boom's Boulder ids are read back
		# from `MatchState._boulder_card_id` instead of riding here.
		"reversal": [reversal_kind, reversal_indices.duplicate(), reversal_a.duplicate(),
					reversal_b.duplicate(), reversal_flags.duplicate(), reversal_amount] \
				if reversal_kind != REVERSAL_NONE \
				else [REVERSAL_NONE, [], [], [], [], 0.0],
	}


func _rules_snapshot() -> Array:
	var out: Array = []
	for kind in RULE_COUNT:
		var window := rule_windows[kind]
		out.append([window.remaining_ticks(), rule_a[kind], rule_b[kind]] if window.is_running \
				else [0, 0.0, 0.0])
	return out
