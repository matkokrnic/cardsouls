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

@export_group("Stamina")
@export var max_stamina: float = 0.0
@export var stamina_regen_per_second: float = 0.0
@export var stamina_regen_delay_seconds: float = 0.0
@export var roll_stamina_cost: float = 0.0
@export var deflect_stamina_cost: float = 0.0
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
## Story 5-6 (AC 1/AC 6, `E5-P/R1`): NO LONGER A DATA-ONLY FIELD. OPEN decision (a) (attacker
## consequence on deflect) is RESOLVED, and this story is the resolution — `STUNNED` gains its first
## two inbound edges, both direct `set_action_state` calls from `MatchState` rather than
## `TRANSITION_TABLE` edges (the `DEAD`-entry precedent).
##
## RENAMED FROM `stun_seconds` (AC 1). Once TWO stun durations exist, a name that says neither which
## ladder tier it belongs to nor how it differs from its sibling is ambiguous by construction. THIS
## one is the COLOR-COUNTER stun: what the ATTACKER holds after a colour-matched defense negates its
## unblockable (`_resolve_charge_landing`, AC 5) — the heavier of the two, the GDD's own "~1s"
## (`gdd.md:241`).
@export var color_counter_stun_seconds: float = 0.0
## Story 5-6 (AC 1/AC 9, `E5-P/R1`): the LIGHTER sibling — what the ATTACKER holds after an ordinary
## MELEE swing is deflected (`_resolve_contacts`, AC 9). Deliberately SHORTER than
## `color_counter_stun_seconds` above, and the ORDER is asserted rather than merely intended
## (`test_balance_authoring.gd`): an authored pair that inverted the gradient would ship a broken
## three-tier ladder with every other audit green. Reading a colour is the harder read and pays the
## bigger punish; landing a deflect is E1 melee content available every swing.
@export var deflect_stun_seconds: float = 0.0

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
## the authored file and the inspector. One colour's attack is one row across the four triplets
## below (reach, arc, launch distance, launch span): RED the wide swipe, BLUE the narrow long
## thrust, GREEN the radial jump. FEEL KNOBS -- no test pins their authored values.
@export var unblockable_reach_red: float = 0.0
@export var unblockable_reach_blue: float = 0.0
@export var unblockable_reach_green: float = 0.0
## Story 6-1c (AC 5, `6-1c/R3`): each colour's hit ARC, in degrees, centred on the attack's FROZEN
## committed direction (AC 2). STATE policy, judged at the landing seat against the runner's planar
## direction fact -- the 1-8 `block_facing_arc_degrees` shape. 360 is radial: every direction inside
## the radius is hit.
##
## DEFAULT 360.0, NOT 0.0, and deliberately against the zero-default house rule: 360 is exactly the
## pre-6-1c behaviour (Fact 3 -- one circle, no angle), so an unauthored arc -- every in-test
## `BalanceConfig.new()` fixture -- degrades to what shipped rather than to an attack that can
## never land. The authoring audit bounds each to (0, 360].
@export var unblockable_arc_degrees_red: float = 360.0
@export var unblockable_arc_degrees_blue: float = 360.0
@export var unblockable_arc_degrees_green: float = 360.0
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
## What a landed unblockable takes off the enemy hero, as a percentage of that hero's own maximum —
## the `attack_damage_percent_of_max_hp` convention verbatim, so the two hero-versus-hero damage
## numbers are read the same way and can be compared at a glance in the authored file.
@export var unblockable_damage_percent_of_max_hp: float = 0.0
## Story 5-6 (AC 2, Ruling 1b): what a landed unblockable deals when the defender's ROLL IFRAME was
## open at the landing — the middle rung of the three-tier ladder, expressed as a MULTIPLIER on the
## full damage directly above rather than as a second damage value, so a retune of the full number
## carries the dodged one with it and the two can never drift into disagreeing about what a dodge is
## worth.
##
## AUTHORED 0.0, which is Ruling 1b's ratified starting point and NOT a placeholder: a clean dodge
## takes nothing. The multiply-and-emit-on-surviving-magnitude shape is the `block_damage_multiplier`
## precedent, and it is written that way so a future non-zero retune needs no code change — at 0.0
## the effective damage is exactly zero and the landing is SILENT (no `hit_landed`), which is a
## stronger statement than a zero-magnitude emit.
##
## THE GDD TABLE'S DAMAGE CELL READS "None" TODAY (`gdd.md:240`) and the shipped 0.0 keeps that claim
## true, so NO `docs(gdd)` amendment is owed now. A future non-zero retune of this field owes one at
## that time.
##
## BOUNDED `<= 1.0` in test_balance_authoring.gd, NOT in `block_damage_multiplier`'s strict-open
## interval: 0.0 is the authored value here, so the audit must pass at it on day one, and 1.0 is the
## boundary at which a dodge stops reducing anything relative to Ruling 1c's full hit. The `>= 0.0`
## half is already covered by test_data_resources.gd's `E1_BALANCE_FIELDS` non-negative loop.
@export var dodged_unblockable_damage_multiplier: float = 0.0
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
## Story 5-5 (AC 2/AC 14): how long the reaction window a defense cast opens stays open. Crosses into
## the tick domain at the ONE boundary (`BalanceTicks.defense_window_ticks`, the
## `unblockable_chargeup_ticks` precedent) and is never compared against a raw float inside
## `advance()`.
##
## PROVISIONAL, and deliberately LONGER than `unblockable_chargeup_seconds` (R-A): the defender must
## be able to pre-arm and still be covered when the chargeup lands. A 0.0 here derives 0 ticks,
## `TimingWindow.start(0)` never runs, and no cast could EVER negate anything -- the whole answer
## half of the read exchange ships invisible, which is why this carries a bespoke `> 0` bound too.
@export var defense_window_seconds: float = 0.0

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


## Story 6-1c: the per-colour lookups over the four unblockable triplets above -- the ONE place a
## `charge_color` int selects a field, so the runner and the state layer can never disagree about
## which colour owns which number. Read INLINE at point of use off the live config (CONSTRAINT C).
##
## A colour with no authored shape (`PlayerState.NO_TELEGRAPH_COLOR`, the degraded-cast sentinel
## `inject_card_colors`' totality check keeps out of live play) reads a ZERO reach, distance and span
## and a RADIAL arc: no radius admits it in the runner, so a colourless chargeup never lands live,
## while the arc half stays the pre-6-1c "no angle" so a headless fixture pushing the kind by hand
## resolves exactly as it always has. Never a substitute colour -- the `kind_at` refusal rule.
func unblockable_reach_for(color: int) -> float:
	return _unblockable_by_color(color, unblockable_reach_red, unblockable_reach_blue,
		unblockable_reach_green, 0.0)


func unblockable_arc_degrees_for(color: int) -> float:
	return _unblockable_by_color(color, unblockable_arc_degrees_red, unblockable_arc_degrees_blue,
		unblockable_arc_degrees_green, 360.0)


func unblockable_launch_distance_for(color: int) -> float:
	return _unblockable_by_color(color, unblockable_launch_distance_red,
		unblockable_launch_distance_blue, unblockable_launch_distance_green, 0.0)


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
