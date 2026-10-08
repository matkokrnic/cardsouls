class_name BalanceConfig
extends Resource

## E1 melee balance schema (story 1-1). Authored as data/balance/balance_config.tres and
## loaded by BalanceConfigService (X3 hot-reloadable). State receives this resource by
## INJECTION via MatchState.apply_balance() and never reads the service.
##
## Defaults are all zero ON PURPOSE: gameplay numbers are never hardcoded in code — the
## authored .tres carries the real values (first-guess placeholders, TBD-in-playtest).
##
## `*_seconds` fields are AUTHORING units only. They are converted to integer ticks exactly
## once per load / X3 reload by BalanceTicks (A1); no `*_seconds` float reaches advance().

@export_group("Hero")
@export var max_hp: float = 0.0
@export var move_speed: float = 0.0
## Story 6-7 (AC 1): the WALK gait's speed, the two-gait system's slower default. `move_speed`
## above is unrenamed and becomes "the run speed" (Dev Notes: the rename-avoidance reasoning).
@export var walk_speed: float = 0.0

@export_group("Stamina")
@export var max_stamina: float = 0.0
@export var stamina_regen_per_second: float = 0.0
@export var stamina_regen_delay_seconds: float = 0.0
@export var roll_stamina_cost: float = 0.0
@export var deflect_stamina_cost: float = 0.0
## Story 6-7 (AC 1): the RUN gait's per-second stamina cost while actually running (`6-7/R13`'s
## predicate). Converted once to `BalanceTicks.run_stamina_drain_per_tick` (AC 2), the
## `stamina_regen_per_tick` precedent verbatim.
@export var run_stamina_drain_per_second: float = 0.0
## Story 6-7 (AC 1/AC 5): the R6 hysteresis latch's resume threshold, 0-100 scale (the
## `attack_damage_percent_of_max_hp` convention). While the latch is set, RUN is refused until
## current stamina is `>=` this percent of `max_stamina`.
@export var run_resume_stamina_percent: float = 0.0
## Stamina-cost corrective pass (E3-RG/R2; OPEN decision (d) RESOLVED at DP/R2): the basic
## attack's per-swing cost — an ANTI-SPAM lever, not an economy constraint (melee stays the
## 1-5 mana faucet). Charged per SWING, so a chain of N costs N x this. Spent at the step-3
## transition on the roll precedent (entry-time spend, reject-and-fall-through), never at
## landing like deflect. Zero default like every other field: an unauthored cost is a free
## attack, which the authoring audit forbids for the shipped .tres.
@export var attack_stamina_cost: float = 0.0

@export_group("Attack")
@export var attack_windup_seconds: float = 0.0
@export var attack_active_seconds: float = 0.0
@export var attack_recovery_seconds: float = 0.0
@export var attack_chain_window_seconds: float = 0.0
@export var attack_chain_length: int = 0
@export var attack_damage_percent_of_max_hp: float = 0.0
## Story 3-0b (AC5, DEBT E member 2): the per-phase successors to the single flat
## attack_move_speed_multiplier that story 1-5 (B6) shipped "uniform across windup/active/
## recovery (per-phase multipliers wait for animations)". The rig landed in 3-0a, so the
## deferral is paid: each field scales the hero's resolved velocity while ATTACKING during
## ITS OWN phase, selected by HeroState.attack_phase() in _resolve_movement and read inline
## at the moment of use (CONSTRAINT C). The flat field is REMOVED, not kept alongside — a
## half-migration would leave two sources of truth for the same scalar.
## Scalars, NOT tick-domain — never on BalanceTicks. Authored 0.0 = full root (a design
## value, not a missing one — exempt from the >0 authoring audit with that reason); the
## Pass 2 migration authored all three at the flat field's 0.0 so live feel is unchanged
## by the seat itself, leaving the per-phase VALUES to this story's AC8 tuning verdict.
## Story 6-7 (review finding 6, advisory): ATTACKING is excluded from the "actually running"
## predicate (`6-7/R17`), so an attacking hero always takes the WALK branch in
## `_resolve_movement` — these three multipliers scale `walk_speed`, never `move_speed`, even
## when the hero was running the tick before the swing started. Inert today (all three are
## 0.0), but a future non-zero retune gets half the in-swing steering this scaled from run
## speed would imply. No AC rules it either way; named here so a retune reads the true base.
@export var attack_windup_move_speed_multiplier: float = 0.0
@export var attack_active_move_speed_multiplier: float = 0.0
@export var attack_recovery_move_speed_multiplier: float = 0.0
## Story 3-0b (AC6): authored forward lunge DISPLACEMENT for one swing — the sanctioned
## form from the 1-7 close-out ("an authored lunge displacement in balance data, applied by
## the STATE layer as a velocity curve during the swing"), NEVER AnimationPlayer root
## motion (DECISION A / the in-place rule). The state layer derives a speed from it exactly
## the way the roll does (roll_distance / roll_duration_seconds): this distance divided by
## the swing's committed span (windup + active seconds), applied along HeroState.facing
## during WINDUP and ACTIVE only — recovery drift is a separate feel decision and is not
## this field's. Units, NOT tick-domain — never on BalanceTicks.
@export var attack_lunge_distance: float = 0.0

@export_group("Mana")
## Story 3-1 (AC 2, 3-1/R1): the mana cap — authored here as of this story, so BalanceConfig
## is now the single source of truth for it exactly as it already was for max_hp,
## move_speed and max_stamina (AC 3). Re-injected on every apply_balance() with
## set_maximum ONLY: current mana is re-clamped, NEVER refilled (3-1/R2).
@export var max_mana: float = 0.0
## Story 1-5 (DEBT D resolved): mana per CONFIRMED melee hit, read inline at the moment
## the hit is confirmed (CONSTRAINT C), gated on the injected
## FeatureFlags.melee_mana_generation. Per-event amount, NOT tick-domain — never on
## BalanceTicks. The flag is the off-switch; a zero amount is a dead flywheel (audited >0).
## RE-AUTHORED by story 3-1 as part of the coherent mana set (3-1/R1): the shipped 8.0 was a
## placeholder against an 80 cap, and the BC/R2 damage halving (6 -> 3) had silently doubled
## mana earned per point of damage. 1.0 per confirmed hit against the 10.0 cap re-bases both
## together and keeps per-hit bar fill identical (8/80 == 1/10 == 10% of the bar).
@export var melee_hit_mana: float = 0.0
## Story 3-1 (AC 2, 3-1/R1): passive mana regeneration, the second faucet beside the melee
## one. AUTHORING UNITS ONLY in this story — N7/E3-RG/R8 place the derived
## `mana_regen_per_tick` seat on BalanceTicks and the matching rung in the advance() ladder
## in story 3-4, so NOTHING consumes this field yet and no BalanceTicks field lands here.
## Named `*_per_second` (a RATE, the stamina_regen_per_second precedent), not `*_seconds` —
## it is not a duration and does not enter the A1 seconds->ticks conversion.
@export var mana_regen_per_second: float = 0.0

@export_group("Cards")
## Story 3-3 (AC 6): how many cards one deck holds. A COUNT, not a duration — it lives here
## and never on BalanceTicks (the A1 conversion is for `*_seconds` fields only). Read INLINE at
## its point of use (CONSTRAINT C), which is the RUNNER: it walks CardDatabase's sorted ids
## taking up to each card's max_copies until this many are collected, and injects the plain
## StringName ids into MatchState (AC 2/AC 4). The state layer never reads this field — it
## receives the composition already sized.
## PROVISIONAL FIXTURE composition, not the deckbuilding seat: real deck selection is E4/E5 or
## later. Audited > 0 (test_balance_authoring.gd): a zero deck is a match with no cards.
@export var deck_size: int = 0
## Story 3-3 (AC 6): how many cards the hand is filled to. A COUNT, same reasoning as
## deck_size, but THIS one is read by the state layer — inline at the single step-6 deal seat
## (MatchState._deal_player), on both the match-start and the debug-reset occasion.
## The hand does NOT vary in this story's first version. OPEN decision (e) — "does the number
## of cards in a hand ever vary?" — is CARRIED, not resolved: no variable-size path is built
## speculatively. Audited > 0 and <= deck_size (a hand bigger than the deck cannot be dealt).
## The `draw_replacement_delay_seconds` reservation this comment used to carry is DISCHARGED
## directly below — story 3-5b is the "3-5 WITH its consumer" the note was waiting for.
@export var hand_size: int = 0
## Story 3-5b (AC 1): how long a played card's REPLACEMENT takes to arrive. The reservation the
## `hand_size` comment above carried since 3-3, now discharged WITH its consumer: 3-5a shipped
## the instant refill, and this field is what turns it into a debt that is paid `delay` later.
## A DURATION, so it converts to ticks exactly once at load (A1) — `BalanceTicks
## .draw_replacement_delay_ticks`, read INLINE at the cast seat (CONSTRAINT C).
##
## AUDITED > 0 (test_balance_authoring.gd), NOT merely non-negative, and the distinction is the
## whole point: `field in config` and `>= 0.0` both pass on this script's 0.0 default, which
## would ship the delay INVISIBLE in the build and recreate exactly the dead field the
## reservation comment existed to prevent. Zero ticks is a legal in-test value (it degrades to
## 3-5a's instant refill, which is how the golden isolates the seat from its content) — it is
## the AUTHORED value that must be positive.
@export var draw_replacement_delay_seconds: float = 0.0
## Story 3-5b (AC 2): how long the reshuffling player stays "vulnerable" after their discard is
## folded back into the deck. The GDD's "~1.5-2s TBD" range.
##
## AUTHORED AND AUDITED > 0 like its sibling above, for the identical reason. What is NOT
## decided here is what vulnerable COSTS: OPEN decision (b) stays open, and the mechanism that
## keeps it open is a NEGATIVE GUARD (test_deck_and_hand.gd) asserting that nothing under `src/`
## READS the window this value sizes — no damage path, no mitigation path, no action-state path.
## A TimingWindow cannot exist without a duration, so the field ships; if nothing consults it,
## nothing has priced it. The renderer is 3-6's.
@export var reshuffle_vulnerable_window_seconds: float = 0.0

@export_group("Minions")
## Story 4-2 (AC 7, `4-2/R5`(a)): how often a unit RE-EVALUATES its target. The project-context
## Performance Rule made authorable — "target-acquisition scans must NOT run every frame for every
## unit. Use a shared, throttled tick (e.g. re-target every ~0.1-0.25 s)" — so the cadence is a
## tuning value, not a magic number in `advance()`.
##
## A DURATION, so it converts to ticks exactly once at load (A1), on the
## `draw_replacement_delay_seconds` -> `_ticks` precedent directly above: `BalanceTicks
## .minion_retarget_interval_ticks`, read INLINE at the step-7 seat (CONSTRAINT C).
##
## ONE MATCH-WIDE CADENCE, NOT A PER-POOL OR PER-PLAYER VALUE. `MatchState.apply_balance` is
## deliberately NOT touched by this story (`4-2/R5`(b)): the per-pool reload contract (`3-1/R2`)
## governs POOL BOUNDS, and a shared tick cadence is not one — a dev pass must not invent a
## per-player injection seat for it.
##
## STORY 4-4 DELIBERATELY LEAVES THIS SHARED while converting eleven of its neighbours to per-kind
## data, and that is an OPERATOR RULING recorded in the story's Dev Notes rather than a dev-pass
## omission: "`minion_retarget_interval_seconds` STAYS shared, by operator ruling: no kind needs its
## own cadence yet; converts later when one does." A per-kind retarget cadence would also break the
## step-7 seat's single `_tick % interval` throttle into N throttles, which is the shared-scan
## property the Performance Rule actually asks for.
##
## THE DEGENERATE VALUE IS DEFINED RATHER THAN LEFT TO ROUNDING (`4-2/R5`(d)): the derived interval
## clamps to at least 1 tick ALWAYS, so an authored 0 means "every tick" instead of a modulo by zero.
## That makes 0 a legal in-test value, exactly as a 0 draw delay is. It is the AUTHORED value that
## is audited > 0 (test_balance_authoring.gd), for the `draw_replacement_delay_seconds` reason
## verbatim: a zero authored cadence would ship the whole THROTTLE invisible in the build — every
## unit re-scanning every frame is precisely the behaviour the Performance Rule forbids, and it
## would pass a `>= 0.0` existence check silently.
@export var minion_retarget_interval_seconds: float = 0.0

## ------------------------------------------------------------------------------------------
## STORY 4-4 (AC 6/AC 7/AC 9): THE PER-KIND CONVERSION. Eleven shared globals become this list.
## ------------------------------------------------------------------------------------------
## GONE FROM THIS FILE, and each was named in the story's Dev Notes inventory before the pass
## began. AC 6's four: `unit_move_speed`, `unit_stop_distance`, `unit_max_hp`,
## `unit_damage_per_hit`. The B5 correction's seven: `minion_attack_windup_seconds`,
## `minion_attack_active_seconds`, `minion_attack_recovery_seconds`,
## `minion_attack_reach_distance`, and `minion_attack_windup/active/recovery_move_speed_multiplier`.
##
## THEY ARE REMOVED, NOT KEPT ALONGSIDE, on the `attack_move_speed_multiplier` precedent this file
## already set at story 3-0b: "The flat field is REMOVED, not kept alongside — a half-migration
## would leave two sources of truth for the same scalar." Eleven half-migrations would be eleven.
##
## `unit_board.gd`'s HEADER AND `4-2/R17`(c) BOTH NAMED THIS STORY AS THE OWNER. The board's own
## comment says the shared maximum exists "because no unit differs from another yet" and names
## 4-3/4-4 as the stories allowed to change it; `4-3/R6` assigned the permission here and `4-4/R8`
## spends it. Units differ now.
##
## ORDER IS AUTHORED AND LOAD-BEARING. A unit record stores the plain INT INDEX of its kind in this
## array (never the StringName — `Array[StringName].sort()` orders by internal POINTER on this
## engine), so reordering the authored list renames every existing record's kind. The authoring
## audit pins the shipped order by name.
##
## READ INLINE AT POINT OF USE (CONSTRAINT C), through `kind_at()` below, off the live
## `MatchState.balance` handle the runner applied — never cached on a record, never on an actor,
## and never `BalanceConfigService` (which during a replay would read the AUTHORED values instead
## of the RECORDED ones, the divergence `3-0c`'s AC 4 exists to prevent).
@export var unit_kinds: Array[UnitKindProfile] = []
## Story 4-4 (AC 6/AC 9): the HERO half of the old `unit_damage_per_hit`, under a name that says
## whose damage it is — what one confirmed HERO swing takes off a unit.
##
## IT IS NOT A SURVIVING GLOBAL; IT IS THE OTHER HALF OF A FIELD THAT HAD TWO DIFFERENT READERS.
## `4-3a/R8` authored `unit_damage_per_hit` for the hero-versus-unit case; `4-3b`'s AC 17 then reused
## the same field for unit-versus-unit. AC 6 moves damage-per-hit PER KIND and AC 9 puts it on the
## attack RECORD — which is the ATTACKER's property — so the unit-attacker reader follows the kind
## and this one stays a hero property, where it always belonged. See
## `MatchState._damage_against_unit`.
##
## STILL FLAT, NOT A PERCENTAGE, and `4-3a/R8`'s reasoning is STRENGTHENED by the per-kind move
## rather than weakened: with `max_hp` now authored per kind, `attack_damage_percent_of_max_hp`
## against a unit would make hits-to-kill a CONSTANT for every authored kind, and every kind's
## authored maximum would decide nothing.
##
## AUDITED > 0 for the failure `unit_damage_per_hit` was audited against verbatim: a zero ships a
## unit that can be hit forever and never dies — the invulnerable box `4-3a` existed to replace.
@export var hero_damage_to_unit: float = 0.0

## Story 6-5b (AC 2, `6-5b/R2`): HOW LONG A CORPSE LASTS, in seconds. Default authored 20 s.
##
## IT REPLACES AN ACTOR CONSTANT, and that is the whole of the ruling: `UnitActor.LINGER_TICKS = 600`
## was a hardcoded 10 s on a presentation node, which `4-3d`'s own Non-Goals stated as deliberate
## ("a lifecycle mechanism, not a tuning pass"). 6-5b makes the corpse a piece of GAME STATE -- Grave
## Ward extends it, Raise Dead consumes it -- so its length is a gameplay number, and a gameplay
## number lives in balance (the project-context NEVER-hardcode rule).
##
## A PLAIN WINDOW DURATION, so `BalanceTicks` converts it with the unclamped `seconds_to_ticks`
## (round, >= 1 tick for any non-zero value) rather than the modulo-divisor clamp: it is a countdown,
## never a divisor. An authored 0.0 derives 0 ticks, which means every death leaves a corpse that is
## already expired -- i.e. no corpse at all. Defined rather than crashing, and the authoring audit is
## what keeps it out of the shipped `.tres`.
@export var corpse_lifetime_seconds: float = 0.0

@export_group("Totems")
## Story 4-4 (AC 20, `4-4/R13`): the Mana Accelerator totem's per-firing MANA AMOUNT — the field
## `data/economy/mana_accelerator.tres` names as its amount's home.
##
## THE RULE CANNOT CARRY THE NUMBER, and that is `ResourceGenerationRule`'s own header rule rather
## than a choice made here: "a rule `.tres` carries no gameplay number ... every gameplay number
## lives in BalanceConfig, hot-reloadable through the X3 seam". AC 20 restates it. So the faucet is
## authored as a rule naming this field, and the evaluator dereferences it against the live balance
## object on every call.
##
## A PER-EVENT AMOUNT, NOT A PER-TICK RATE — `melee_hit_mana`'s domain, not
## `mana_regen_per_tick`'s — because the accelerator fires on a CADENCE (below) rather than every
## tick. `amount_domain` on the authored rule is therefore `BALANCE`, not `BALANCE_TICKS`.
##
## DERIVED RELATIVE TO `passive_tick`, NOT PRINCIPLED (`4-4/R13`). See the authored `.tres` and the
## dev-pass measurement recorded in the Dev Agent Record for the arithmetic; the value is a working,
## playtest-tunable number.
##
## AUDITED > 0: a zero amount is a dead faucet, and the totem would ship visible but inert.
@export var mana_accelerator_mana: float = 0.0
## Story 4-4 (AC 20): how often a live Mana Accelerator totem produces that amount.
##
## A DURATION, so it converts once at load (A1) to `BalanceTicks.mana_accelerator_interval_ticks`,
## read INLINE at the third `_generate_mana` call site (CONSTRAINT C).
##
## A MODULO DIVISOR, so it takes `minion_retarget_interval_ticks`'s clamp rather than the plain
## `seconds_to_ticks()` every duration above uses: the derived value is clamped to at least 1 tick,
## which gives an authored 0 the DEFINED meaning "every tick" instead of a divide-by-zero on the
## tick ladder. Zero is therefore a legal in-test value; the AUTHORED value is audited > 0.
@export var mana_accelerator_interval_seconds: float = 0.0
## Story 5-1 (AC 7, `5-1/R1`), REPLACING story 4-4's multiplicative predecessor of this field: the
## PER-TOTEM ADDITIVE STEP each of a player's own live Stamina Accelerators contributes to that
## player's hero stamina regeneration. The regen seat applies `1 + N x step`, where `N` is the
## owner's own live count — LINEAR, not the `mult^N` this field's predecessor implied. Owner-only:
## the opposing hero's regen is untouched, which the seat makes structural rather than checked (the
## regen seat is already per-player and consults that player's OWN board).
##
## LINEAR BY RULING, NOT BY IMPLEMENTATION TASTE (`5-1/R1`): the player counts totems rather than
## exponents, and `mult^N` explodes at the third totem. The mana seat already stacks this way, so
## the two accelerators now read the same.
##
## A TERM IN A FACTOR ON THE DERIVED PER-TICK RATE, applied at the regen seat — NOT a second
## authored rate and NOT a per-pool bound. The `3-1/R2` per-pool reload contract governs POOL BOUNDS
## (stamina: `set_maximum` + `refill`), and a regen factor is not a bound; deriving a per-player
## rate at `apply_balance()` instead would make the accelerator's effect depend on when a reload
## happened rather than on whether the totem is alive right now.
##
## AUDITED > 0, replacing the predecessor's `> 1.0` — the bound moved because the SEMANTICS did, not
## because it was relaxed. Under `1 + N x step`, `step = 0` is the value that ships a totem doing
## nothing and `step < 0` the one that harms its owner; `> 0` is exactly where those two failures
## sit now, and `> 1.0` would forbid perfectly good authoring (today's shipped `0.5`).
##
## THE CLASS DEFAULT `0.0` IS THE IDENTITY-SAFE ONE, and that is what discharges `4-4` M2
## (`_44-review.md:330`). An unauthored config yields `1 + N x 0.0 = 1` at EVERY `N` — no boost, and
## crucially never a penalty. The predecessor's identical `0.0` default was the DANGEROUS value: as
## a direct multiplier it ZEROED the stamina regen of the one player who had actually summoned the
## totem. Same literal, opposite meaning, because the field is additive now.
##
## THE AUTHORED VALUE IS DERIVED, NOT PRINCIPLED (`5-1/R1`): `0.5`, solved from
## `1 + 1 x step = 1.5` so that ONE totem reproduces 4-4's shipped `1.5` factor byte-exactly and the
## first totem moves no balance. Two totems give `2.0`, three `2.5` — never `1.5^2 = 2.25`.
@export var stamina_accelerator_regen_step: float = 0.0

## Story 6-5e (S1, `6-5e/R28`, AC 37a): THE BOULDER SLOW -- the fraction of walk/run/block-walk speed one
## held Boulder takes away, stacking ADDITIVELY per Boulder. Authored 0.15; `0.0` DISABLES the slow
## entirely, which is the ruling's own switch rather than a neutral default that happens to be inert.
##
## IT LIVES ON `BalanceConfig`, NOT ON `CardEffect`, and the reason is whose property it is: the slow is a
## property of HOLDING Boulders, not of the effect that planted them -- a hero carrying two Boulders from
## two different Rockslings is slowed by the count, and there is no single effect to read it off. It is
## also a movement tuning number, which is what this resource is for.
##
## SCALAR, NOT TICK-DOMAIN -- never on `BalanceTicks` (the `block_facing_arc_degrees` classification): it is
## a multiplier per unit count, with no duration anywhere. See `MatchState._resolve_movement` for why it
## cannot ride `RULE_FROSTBITE_SLOW`'s timed seat.
##
## READ INLINE AT THE POINT OF USE (CONSTRAINT C), never cached, exactly as every other member here is.
@export var boulder_slow_per_boulder: float = 0.0

@export_group("Defense")
@export var block_damage_multiplier: float = 0.0
@export var deflect_window_seconds: float = 0.0
## Story 1-8 (R-D2): full width of the front arc within which a BLOCKING target counts as
## facing the attacker — the gate for BOTH block mitigation and deflect (R-D3). State
## compares the fact's target-to-attacker direction against HeroState.facing within
## +/- half this arc. Scalar degrees, NOT tick-domain — never on BalanceTicks.
@export var block_facing_arc_degrees: float = 0.0
## Story 5-6 (AC 2, `E5-P/R1`): what a DEFLECTED ATTACKER LOSES, and it is a DIFFERENT NUMBER from
## `deflect_stamina_cost` in the Stamina group above rather than a second name for it. That field is
## what the DEFENDER SPENDS to execute a deflect (an affordability-gated, voluntary cost, refused
## outright when unaffordable); this is what the ATTACKER is DRAINED BY as the deflect's consequence
## — punitive, always applied, floored at zero, and therefore taken through `StaminaPool.add(-x)`
## rather than `spend()` (AC 10). A stamina-starved attacker must not escape the penalty by being
## poor, which is exactly what `spend()`'s refusal would grant it.
##
## SEATED IN THE `Defense` GROUP rather than beside `deflect_stamina_cost` in `Stamina` (which AC 2's
## own text names as its neighbour — measured, that field lives in the Stamina group at line 23, not
## here): the two are grouped by WHICH MECHANIC OWNS THEM, and this number belongs to the deflect
## outcome that `deflect_window_seconds` and `block_damage_multiplier` directly above also describe.
@export var deflect_stamina_penalty: float = 0.0

@export_group("Roll")
@export var roll_iframe_seconds: float = 0.0
@export var roll_duration_seconds: float = 0.0
@export var roll_distance: float = 0.0

@export_group("Stun")
## Story 5-6 (AC 1/AC 9, `E5-P/R1`): what the ATTACKER holds after an ordinary MELEE swing is
## deflected (`_resolve_contacts`, AC 9) -- the LIGHTER of the two stuns that survive, and the only
## non-knockdown one left.
##
## STORY 6-6b POST-SMOKE (R-S6): its heavier sibling `color_counter_stun_seconds` IS RETIRED HERE,
## with `defense_window_seconds` and `counter_eligibility_seconds`, as the close-out orphan set. The
## colour counter stopped stunning the attacker when `6-6b` replaced the `5-5`/`5-6` landing rung
## with an attacker KNOCKDOWN (AC 4), so nothing in `src/` has read that field since; keeping it
## authored kept a dead number in the ladder audit and a dead rung in the three-way gradient. The
## gradient the audit still pins is `knockdown > deflect`, which is the whole of what ships.
@export var deflect_stun_seconds: float = 0.0
## Story 6-6a (AC 3/AC 4): the THIRD stun duration -- what the VICTIM of an UNANSWERED unblockable
## landing holds (the knockdown, `_apply_landing_packages`). Named on the two siblings' precedent
## above: once a third duration exists, the name says which rung it belongs to. The HEAVIEST of the
## three, and the order is asserted in TICKS (`test_balance_authoring.gd`, AC 4):
## `knockdown > deflect` (6-6b post-smoke: the middle rung retired with
## `color_counter_stun_seconds`). The ordering is also load-bearing beyond the ladder's
## gradient: `BalanceTicks.is_knockdown_stun` tells a knockdown from an ordinary stun by the running
## window's duration alone (no stored reason field), which is only sound while the three stay distinct.
@export var knockdown_stun_seconds: float = 0.0
## Story 6-6a (AC 8): the GET-UP IFRAMES -- opened on the ordinary timer-driven `STUNNED -> IDLE` exit
## from a knockdown and never on the debug reset (AC 9). Registers wherever `roll_iframe_seconds`
## does (`HeroState.is_iframe_open`, operator ruling R-IFRAME-UNBLOCKABLE). Authored from the
## measured length of the `get_up` clip (2.0333 s at the 6-6a dev pass); live smoke judges the felt
## window.
@export var get_up_iframe_seconds: float = 0.0
## Story 7-9 (AC 11, `7-9/R1`/`R11`): THE KNOCKDOWN BREATHER -- how long, from the close of the get-up
## iframes above, a hero is IMMUNE TO UNBLOCKABLES. An unblockable touching the hero inside it does
## nothing (no damage, no knockdown, no orb grant) and is not spent; melee, spells and every other source
## hit normally. Follows ANY knockdown (`7-9/R11`): the victim of a hit, or an attacker a counter dropped.
##
## IT CHAINS OFF THE GET-UP CLOSE, so with no get-up window authored there is no close tick and no
## immunity -- the get-up field above is this one's precondition, not a sibling. Crosses into the tick
## domain at the ONE boundary (`BalanceTicks.unblockable_immunity_ticks`); its `_seconds` suffix makes the
## reflective probe demand that twin. Zero default (`7-9/R16`): 0 = no immunity. TEMP 1.5 s (7-7 tunes).
@export var unblockable_immunity_seconds: float = 0.0

## Story 5-2 (AC 6/AC 10/AC 17/AC 18): mode ② — the unblockable INITIATION. Four numbers, and
## every one of them is global rather than per-card or per-colour, which is the GDD's own shape
## ("per-COLOR value, not per-card", card_data.gd's header) narrowed one step further by Ruling 2:
## this story ships ONE damage value for all three colours and `5-6`'s ladder is what splits it.
## Colour therefore selects the TELEGRAPH and nothing numeric — there is deliberately no
## `unblockable_*_red/blue/green` triplet here to become a second source of truth for a value the
## later story will author properly.
@export_group("Unblockable")
## What initiating mode ② costs, spent at the CAST (`5-2/R4`) — the FOURTH stamina seat, joining
## roll, attack and deflect. Passed to `StaminaPool.spend` with `stamina_regen_delay_ticks` exactly
## as the other three are, so the spend restarts the regen delay identically.
@export var unblockable_stamina_cost: float = 0.0
## Story 7-9 (AC 1/AC 2, `7-9/R2`/`R13`): what initiating mode (2) costs in MANA, charged at the click on
## top of the stamina above. Tested BEFORE the stamina spend and spent after it, so a refusal for either
## pool leaves both untouched; short of both, the reason is `insufficient_mana`. Never refunded -- a
## countered, missed, dodged or immunity-dropped attack keeps it spent. A cost, not a duration: no tick
## twin. Zero default (`7-9/R16`): 0 = free, the pre-7-9 shape. TEMP 1.0 (7-7 tunes).
@export var unblockable_mana_cost: float = 0.0
## How long the hero is rooted in `CHARGING` before the attack lands. Crosses into the tick domain
## at the ONE boundary (`BalanceTicks.unblockable_chargeup_ticks`, the D3 precedent) and is never
## compared against a raw float inside `advance()`.
@export var unblockable_chargeup_seconds: float = 0.0
## Story 6-1c (AC 5, Fact 8): THE HONEST REACH, PER COLOUR -- `5-2`'s single `unblockable_reach`
## circle is REMOVED, not kept alongside (the `3-0b` precedent: a half-migration would leave two
## sources of truth for one radius). Each is the authored hit radius that IS the boundary
## (`E5-P/R4`) for that colour's attack: planar (XZ) centre-to-centre distance between the two
## HEROES, measured on the LANDING tick (after the launch has carried the attacker). Lock-on aims
## direction only and never extends it. Read by the RUNNER, which owns positions -- the state layer
## receives the inside/outside KIND the comparison produces, never a distance and never a position.
##
## A TRIPLET, NOT A PROFILE RESOURCE, and Fact 8 is why: these ARE the per-colour numbers `5-2`'s
## Ruling 2 deferred to "the later story", and three flat fields per knob read and tune directly in
## the authored file and the inspector. One colour's attack is one row across the three triplets
## below (reach, launch distance, launch span; story 7-8 retired the arc, `7-8/R8`): RED the wide swipe, BLUE the narrow long
## thrust, GREEN the radial jump. FEEL KNOBS -- no test pins their authored values.
@export var unblockable_reach_red: float = 0.0
@export var unblockable_reach_blue: float = 0.0
@export var unblockable_reach_green: float = 0.0
## Story 6-1c (AC 4): how far the LAUNCH carries the attacker along its frozen direction -- a FIXED
## authored displacement, never adaptive to where the defender is. Applied by the STATE layer as a
## velocity over the launch span below (`MatchState._charge_launch_velocity`, the `3-0b`
## `attack_lunge_distance` shape), never root motion. Zero default: no travel, the pre-6-1c shape.
@export var unblockable_launch_distance_red: float = 0.0
@export var unblockable_launch_distance_blue: float = 0.0
@export var unblockable_launch_distance_green: float = 0.0
## Story 6-1c (AC 2/AC 4/AC 11): the LAUNCH SPAN -- how long the committed attack travels between
## the chargeup's close (the commit point) and the landing. Crosses into the tick domain at the ONE
## boundary (`BalanceTicks.unblockable_launch_ticks_for`) for timing; the float is read directly only
## as the divisor of the travel SPEED (the `roll_distance / roll_duration_seconds` precedent). Zero
## default: the landing resolves on the chargeup-close tick, exactly the pre-6-1c shape.
@export var unblockable_launch_seconds_red: float = 0.0
@export var unblockable_launch_seconds_blue: float = 0.0
@export var unblockable_launch_seconds_green: float = 0.0
## Story 7-9 (AC 4, `7-9/R3`/`R12`): THE STEERING AFTER LAUNCH, PER COLOUR -- how fast, in degrees per
## second, the committed attack keeps turning toward the defender on every flight tick, travel and facing
## both (the launch velocity reads the steered facing). GREEN turns most, BLUE least -- and that order
## comes from these three numbers, never from the code. A RATE, not a duration: it crosses into the tick
## domain once at load as a per-tick ANGLE (`BalanceTicks.unblockable_turn_radians_per_tick_for`, A1),
## and its name ends in the colour, not `_seconds`, so the reflective probe leaves it alone. Zero default
## (`7-9/R16`): 0 = no turning, the pre-7-9 frozen line. TEMP GREEN 240 / RED 150 / BLUE 90 (7-7 tunes).
@export var unblockable_turn_rate_degrees_per_second_red: float = 0.0
@export var unblockable_turn_rate_degrees_per_second_blue: float = 0.0
@export var unblockable_turn_rate_degrees_per_second_green: float = 0.0
## Story 6-1d (AC 8, `6-1d/R6`): THE SWING-AT-COMMIT KNOB -- the option `6-1c`'s code review
## (`6-1c/D1`, ruled `6-1c/R8`) offered forward to this story, BUILT here and left OFF.
##
## OFF (the default, and what ships): the charge clip's playhead runs LINEARLY over the whole
## commitment, chargeup plus launch, so the swing itself -- which begins at the clip's own `hold_end`
## knob -- is already partly played at the commit (measured at `6-1c`: RED ~64 %, BLUE ~49 %,
## GREEN ~31 % of the hold-to-strike swing gone before the attacker is committed).
##
## ON: the chargeup is mapped onto `[0, hold_end]` and the launch onto `[hold_end, 1]`, so the swing
## STARTS at the commit and the whole of it plays across the launch -- the blade's visible motion and
## the tick the chargeup window closes become the same moment (`6-9`: the attack was never
## feintable to begin with -- the press commits it).
##
## PRESENTATION ONLY, and that is why it is a plain bool with no tick-domain twin: it re-times a
## playhead and touches no window, no damage, no reach and no state. The script default stays OFF (what
## every in-test config inherits); STORY 7-8 (AC 13, `7-8/R4`) SHIPS IT ON in `balance_config.tres` --
## the Genichiro rhythm: the whole chargeup is wind-up and held anticipation, and the sweep starts at
## the commit and plays across the launch.
@export var unblockable_swing_at_commit: bool = false
## What a landed unblockable takes off the enemy hero, as a percentage of that hero's own maximum —
## the `attack_damage_percent_of_max_hp` convention verbatim, so the two hero-versus-hero damage
## numbers are read the same way and can be compared at a glance in the authored file.
@export var unblockable_damage_percent_of_max_hp: float = 0.0
## Story 5-4 (AC 3): what ONE landed unblockable pays its attacker, in orbs of the spent card's own
## colour. Per-EVENT amount, NOT tick-domain -- never on BalanceTicks. Named into the
## `unblockable_*` family because the EVENT is an unblockable landing; the CONTAINER's bound is a
## separate, generic field (`max_orbs_per_color` below), since `5-5`/`5-6` will clamp the same pool
## against events this family does not name.
##
## NO PER-COLOUR SCALING (Non-Goals): one value for RED, BLUE and GREEN alike, exactly as
## `unblockable_damage_percent_of_max_hp` directly above ships one damage value for all three
## (Ruling 2). `5-6`'s ladder is what splits both. There is deliberately no
## `unblockable_orb_grant_red/blue/green` triplet here to become a second source of truth.
##
## An INT, because OrbPool stores ints -- but `EconomyEvaluator.amount_for` returns a float (it sums
## over rules), so the conversion back happens ONCE, at the landing seat, via `roundi`. Zero default
## like every other field: an unauthored grant ships the story invisible, which is why this carries
## a BESPOKE authored `> 0` bound in test_balance_authoring.gd on top of the `>= 0` loop.
@export var unblockable_orb_grant: int = 0
## Story 5-5 (AC 6/AC 14): what initiating mode ③ costs, spent at the CAST -- the FIFTH stamina seat,
## joining roll, attack, deflect and unblockable. Passed to `StaminaPool.spend` with
## `stamina_regen_delay_ticks` exactly as the other four are, so the spend restarts the regen delay
## identically. PROVISIONAL and deliberately SMALLER than `unblockable_stamina_cost` (R-D): the
## defender is answering a commitment already made, not making one.
##
## SEATED IN THE `Unblockable` GROUP rather than a new `Defense` one, a dev-pass choice: mode ③
## exists only where an unblockable does (its layer gate IS `flags.unblockable`, AC 3), so a
## separate group would suggest an independence the flag gate denies.
##
## Zero default like every sibling, and therefore a BESPOKE authored `> 0` bound in
## test_balance_authoring.gd on top of the `>= 0.0` loop -- a free defense is the roll precedent
## again, on the fifth spend seat.
@export var defense_stamina_cost: float = 0.0
## Story 6-6b POST-SMOKE (R-S6): `defense_window_seconds` and `counter_eligibility_seconds` STOOD
## HERE and are RETIRED, with `color_counter_stun_seconds`, as the close-out orphan set.
##
## `defense_window_seconds` was the `5-5` 1.5 s PRE-ARM, superseded as the counter window by the
## three per-colour busy spans below and read by nothing in `src/` since. `counter_eligibility_
## seconds` was the short head of the busy span during which a commit or launch tick could still be
## answered -- the live smoke retired the idea itself: THE WHOLE BUSY SPAN IS THE COUNTER WINDOW
## ("as long as you initiate the defence before the attack touches you, it should defend"), so a
## counter lands iff the window is RUNNING at the judged tick and "too early" means the counter RAN
## OUT, never that the press was refused. One span, one number per colour, nothing to order against.
##
## Story 6-6b (AC 2): HOW LONG THE PRESSER IS BUSY, one authored value PER COLOUR -- the total length
## the one reused `defense_window` is started at, selected at the press from `defense_color`. Busy IS
## the window running: while it runs every input is refused and the hero is rooted (except BLUE's
## authored travel, AC 9), so this is the whole real cost of a missed counter beside the card and the
## stamina.
##
## THREE FIELDS AND NOT ONE, which is a measured decision rather than a preference. The three
## presentations are of wildly different lengths (RED is a two-clip jump-then-backflip sequence,
## GREEN a short throw), and one field sized to the longest would leave a GREEN counter rooted and
## silent for seconds after its clip ended -- three mechanically identical counters with wildly
## different real cost, which the story's Non-Goals refuse by name.
##
## THE PRESENTATION IS MAPPED INTO THESE, NEVER THE REVERSE (`6-1b`'s precedent): the per-colour cut
## ranges on `AnimationController._COUNTER_PRESENTATION` derive their playback rate from the busy
## span, so retuning a number here re-fits the clip with no presentation edit.
##
## THE `unblockable_launch_seconds_*` NAMING SHAPE verbatim -- a per-colour triplet whose names do
## NOT end in `_seconds`, so test_data_resources.gd's reflective stem probe leaves them alone exactly
## as it leaves that triplet alone; their tick twins are demanded by the bespoke audit instead.
## PROVISIONAL feel knobs, tuned at the live smoke and pinned by tests in ONE direction only:
## `busy > 0`, per colour. POST-SMOKE (R-S4) they were CUT -- RED 1.5 -> 1.0, BLUE 1.2 -> 0.8,
## GREEN 0.7 -> 0.5: every one of the three read as a hesitation the player was locked inside rather
## than as a counter. The cut tables re-fit BY CONSTRUCTION (the rate is derived from this span), so
## this stayed a `.tres` edit with no presentation edit, which is what AC 2 asks these numbers to be.
@export var counter_busy_seconds_red: float = 0.0
@export var counter_busy_seconds_blue: float = 0.0
@export var counter_busy_seconds_green: float = 0.0
## Story 7-9 (AC 6, `7-9/R4`/`R8`/`R9`): THE COUNTER WINDOW'S LEAD, PER COLOUR -- how long BEFORE the
## commit a matching colour defence may be pressed and still counter. The window is anchored at the commit
## (`7-9/R8`): it opens this long before it and stays open to the attack's first touch (or the flight's
## end). A press older than that is TOO EARLY: card spent, the hit lands. The busy span above stays the
## capture's precondition (`7-9/R9`), so the audit pins busy > lead per colour, and lead < chargeup.
##
## A THRESHOLD, NOT A RUNNING WINDOW: read inline at the judgement (CONSTRAINT C), so a mid-flight reload
## moves the judgement (accepted, gate notes). Named on the `counter_busy_seconds_*` shape (the suffix is
## the COLOUR), so the reflective probe leaves it alone and its tick twins are bespoke-audited. Zero
## default (`7-9/R16`): 0 = the window opens AT the commit. TEMP 0.25 s every colour (7-7 tunes).
@export var counter_lead_seconds_red: float = 0.0
@export var counter_lead_seconds_blue: float = 0.0
@export var counter_lead_seconds_green: float = 0.0
## Story 7-9 (AC 10, `7-9/R6`/`R14`): what a SUCCESSFUL colour counter pays its defender, in mana, at the
## counter landing -- clamped at the pool's maximum, so nothing when full. Nothing else pays it: a roll
## through, a miss and an immunity pass-through give nothing. A per-EVENT amount, not tick-domain.
##
## A KNOB RATHER THAN THE LITERAL `7-9/R14` writes (`mana.add(1.0)`), because AC 14 puts every new number
## in this file and project-context forbids a hardcoded economy value; the authored 1.0 IS R14's number.
## Zero default: 0 = no reward. TEMP 1.0 (7-7 tunes).
@export var counter_mana_reward: float = 0.0
## Story 6-6b (AC 9): HOW FAR A COUNTER CARRIES THE DEFENDER, in metres, spread over the colour's own
## busy span above -- the `1-9` `roll_distance` / `roll_duration_seconds` precedent exactly, including
## that the SPEED is derived at the movement seat as distance over duration and read inline there
## (CONSTRAINT C).
##
## POST-SMOKE (R-S1/R-S2) THIS IS A PER-COLOUR PAIR, not BLUE alone. The smoke found BOTH travel
## halves wrong in the same way -- nothing arrived:
##   * RED played its jump-and-backflip ON THE SPOT while the attacker stood a reach away, so the
##     "headstomp" landed on nothing. RED now travels FORWARD along the locked bearing for the jump's
##     share of the span and BACK by the same distance for the backflip's, net ZERO (`_resolve_
##     movement`'s counter-busy branch) -- it reaches the attacker's head and bounces back.
##   * BLUE's 1.5 m slide stopped short of an attacker that commits from up to its own reach away.
##
## PROVISIONAL = THE UNBLOCKABLE'S OWN REACH, PER COLOUR (`unblockable_reach_red` 4.0,
## `unblockable_reach_blue` 6.0). That is the operator's number and the only one with a reason behind
## it: reach is exactly how far away an attacker of that colour can be standing when it commits, so a
## counter authored shorter than it can be dodged by standing still. A feel knob, unpinned by value.
##
## GREEN HAS NO FIELD AND TRAVELS ZERO, which is the ruling rather than an omission: its counter is a
## THROW, and the dagger crosses the gap instead of the body. `counter_travel_distance_for` answers
## 0.0 for it and for the sentinel, `unblockable_reach_for`'s totality shape.
##
## DISTANCES, not durations, so they carry no `BalanceTicks` twin and no reflective-probe obligation
## -- only the `>= 0.0` loop and a bespoke authored `> 0` bound each, on `roll_distance`'s own
## footing: a zero would ship that colour's whole travel half invisible.
@export var counter_travel_distance_red: float = 0.0
@export var counter_travel_distance_blue: float = 0.0
## Story 6-6b POST-SMOKE (R-S1): WHERE RED'S TRAVEL TURNS AROUND -- the share of RED's busy span spent
## going FORWARD, the rest of it spent coming BACK. A fraction in (0, 1).
##
## IT EXISTS BECAUSE THE TURN HAS TO BE A STATE FACT AND THE CLIP JOIN IS A PRESENTATION ONE. RED's
## body travel is two steps (out on `counter_jump`, back on `counter_backflip`) and the state layer
## cannot read `AnimationController._COUNTER_PRESENTATION` to learn where one ends -- so the split is
## authored here, beside the distance it splits, instead of being duplicated as a state constant that
## silently disagrees with the cut table after the next retune.
##
## PROVISIONAL 0.305 = the jump's share of RED's measured cut total (0.8333 of 2.7333 s), so the body
## turns around on the frame the flip starts. Retuning the cut table means retuning this; nothing
## enforces the agreement, and that is stated rather than hidden. NET ZERO does not depend on it: the
## backward leg is derived from whatever is left of the span, so any fraction still returns the hero
## exactly where it started.
@export var counter_travel_forward_fraction_red: float = 0.0

@export_group("Orbs")
## Story 5-4 (AC 9): the per-colour CEILING on OrbPool, one value applied to each colour
## INDEPENDENTLY. A generic cap on the CONTAINER, in the `max_hp` / `max_stamina` / `max_mana`
## naming family rather than in the `unblockable_*` one, because the pool it bounds outlives the
## event that fills it: `5-5`/`5-6` read and clamp this same pool against their own events.
##
## Injected on EVERY apply_balance through `OrbPool.set_maximum` (the `mana.set_maximum` line's
## shape), which RE-CLAMPS the current counts into the new bound and NEVER refills -- orbs are
## earned, never handed out. Zero default, bespoke `> 0` bound: a 0 cap makes every grant a no-op
## and would ship the story invisible.
@export var max_orbs_per_color: int = 0

@export_group("Pitch")
## Story 6-2 (AC 9, `E6-P/R5` provisional 20 s): how long a staged card may wait in its owner's Pitch
## Zone before it FIZZLES to the discard. Crosses into the tick domain at the ONE boundary
## (`BalanceTicks.pitch_stage_timer_ticks`, the `unblockable_chargeup_seconds` shape) and is never compared
## against a raw float inside `advance()`.
##
## Zero default like every sibling duration, and therefore a BESPOKE authored `> 0` bound in
## test_balance_authoring.gd: a 0.0 derives 0 ticks, `TimingWindow.start(0)` never runs, and every
## staged card would fizzle on the tick it was staged -- the buildup half of the bluff shipped
## invisible.
@export var pitch_stage_timer_seconds: float = 0.0
## Story 6-3b (AC 5, operator ruling 2026-09-15: N = 30 ticks): how often a STAGED card's countdown
## and READY are re-pushed to the pitch HUD through `MatchState.pitch_changed` -- the `2-6/R7` rule
## that presentation gets no per-tick timing-window firehose. Its OWN field, never a reuse of
## `minion_retarget_interval_seconds`, which feeds three minion-AI seats: sharing it would let a
## minion retune silently re-pace the pitch bar, and the reverse.
##
## A DURATION, so it converts once at load (A1) to `BalanceTicks.pitch_countdown_push_interval_ticks`,
## read INLINE at the step-6 throttle seat (CONSTRAINT C).
##
## A MODULO DIVISOR, so it takes `minion_retarget_interval_ticks`'s clamp rather than the plain
## `seconds_to_ticks()` the countdown above uses: the derived value is clamped to at least 1 tick,
## which gives an authored 0 the DEFINED meaning "every tick" instead of a divide-by-zero on the
## tick ladder. Zero is therefore a legal in-test value; the AUTHORED value is audited > 0.
@export var pitch_countdown_push_interval_seconds: float = 0.0
## Story 6-2 (AC 12/AC 13): THE OPTIONAL ORB-CLEAR RULE -- "pitching clears, not the price clears".
## When ON, staging a card empties ALL THREE of the staging player's orb colours at the staging tick,
## BEFORE READY is first read, whatever the staged card's own orb price is (a zero-orb card included).
## OFF (the default, and what ships): orbs banked before staging count toward READY immediately.
##
## A RULE INSIDE A LIVE SYSTEM, so a BalanceConfig bool and not a FeatureFlags layer -- the
## `unblockable_swing_at_commit` precedent (`6-1d/R6`) for WHERE it lives, and deliberately NOT for how
## lightly it is treated: that knob is presentation-only, while this one decides HASHED state (whether
## orbs are zeroed at a mid-round call site), so both branches are test-covered. Deadline, recorded
## where it applies: the post-E6 playtest picks a branch, and the losing branch AND this bool are both
## deleted then.
##
## A BOOL, so it is invisible to test_data_resources.gd's float/int reflection and carries no
## `E1_BALANCE_FIELDS` entry (AC 17) -- its authored-off pin lives in test_balance_authoring.gd.
@export var pitch_stage_clears_orbs: bool = false


## Story 6-1c: the per-colour lookups over the unblockable triplets above -- the ONE place a
## `charge_color` int selects a field, so the runner and the state layer can never disagree about
## which colour owns which number. Read INLINE at point of use off the live config (CONSTRAINT C).
##
## A colour with no authored shape (`PlayerState.NO_TELEGRAPH_COLOR`, the degraded-cast sentinel
## `inject_card_colors`' totality check keeps out of live play) reads a ZERO reach, distance and span:
## no radius admits it in the runner, so a colourless chargeup never lands live. Never a substitute colour -- the `kind_at` refusal rule.
func unblockable_reach_for(color: int) -> float:
	return _unblockable_by_color(color, unblockable_reach_red, unblockable_reach_blue,
		unblockable_reach_green, 0.0)


## Story 6-6b POST-SMOKE (R-S1/R-S2): the per-colour lookup over the counter TRAVEL pair --
## `unblockable_reach_for`'s shape verbatim, including what it answers for a colour with no authored
## distance. GREEN and the sentinel read ZERO and travel nowhere, which is the ruling (GREEN throws a
## dagger across the gap instead of moving the body) and the degrade in one answer.
func counter_travel_distance_for(color: int) -> float:
	return _unblockable_by_color(color, counter_travel_distance_red, counter_travel_distance_blue,
		0.0, 0.0)


func unblockable_launch_distance_for(color: int) -> float:
	return _unblockable_by_color(color, unblockable_launch_distance_red,
		unblockable_launch_distance_blue, unblockable_launch_distance_green, 0.0)


## Story 6-1d (AC 7, P6 adopted): NO PRODUCTION CALLER DIVIDES BY THIS ANY MORE, and that is the
## point of P6 rather than an oversight. The launch SPAN is asked for in the tick domain
## (`BalanceTicks.unblockable_launch_ticks_for`), the same span the landing window counts, so a
## retune off the tick grid cannot make the travel and the timing disagree. The lookup is kept for
## the family's sake -- the four triplets are read through four matching functions and a missing one
## would invite a caller to reach past them into a per-colour field -- but a new divisor here would
## be re-opening the class P6 closed.
func unblockable_launch_seconds_for(color: int) -> float:
	return _unblockable_by_color(color, unblockable_launch_seconds_red,
		unblockable_launch_seconds_blue, unblockable_launch_seconds_green, 0.0)


static func _unblockable_by_color(color: int, red: float, blue: float, green: float,
		none: float) -> float:
	match color:
		Enums.CardColor.RED:
			return red
		Enums.CardColor.BLUE:
			return blue
		Enums.CardColor.GREEN:
			return green
	return none


## Story 4-4 (AC 1/AC 2): the sentinel a failed kind lookup returns. NOT -1 by coincidence — it is
## the same "no such thing" answer `TargetingService.NO_TARGET_SLOT` and `HERO_INDEX` use in the
## addressing space next door, and every reader tests against the NAME rather than against a bare
## -1 so the two spaces never get confused at a call site.
const NO_KIND_INDEX := -1


## The plain INT INDEX of the kind carrying `name`, or `NO_KIND_INDEX` when the authored list holds
## none. This is the ONE place a kind NAME becomes a kind INDEX, and the index is what crosses into
## the unit record and therefore into the determinism snapshot.
##
## NEVER A FALLBACK TO ANOTHER KIND, the `TargetingService.priority_named` contract verbatim:
## substituting a different kind for a missing one would change what the card summons without
## anything saying so. The miss reaches the cast seat as `NO_KIND_INDEX`, which resolves the cast
## successfully (mana spent, card discarded — `4-1/R3`'s "nothing below the verdict is conditional")
## while putting NO record on the board.
##
## FIRST MATCH IN AUTHORED ORDER, so a duplicated name resolves deterministically. Names are
## COMPARED as StringNames and never SORTED — `Array[StringName].sort()` orders by INTERNAL POINTER
## on this engine (player_state.gd:77, 206-207), so a name may be compared but must never decide an
## order.
func kind_index_of(name: StringName) -> int:
	for i in unit_kinds.size():
		var kind := unit_kinds[i]
		if kind != null and kind.kind_name == name:
			return i
	return NO_KIND_INDEX


## The kind profile at `index`, or NULL for a `NO_KIND_INDEX` / out-of-range index. The total-
## function shape `UnitKindProfile.attack_at` and `TargetingService.priority_named` both use: an
## out-of-range read here means a record was written under a different authored list than the one
## being read now (a mid-match X3 reload that shortened `unit_kinds`), and every seat handles a
## null kind as "this unit does nothing" rather than crashing the tick.
func kind_at(index: int) -> UnitKindProfile:
	if index < 0 or index >= unit_kinds.size():
		return null
	return unit_kinds[index]
