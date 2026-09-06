---
baseline_commit: 47c4d7c523509075578256277863003a90c23760
---

# Story 5.6: Three-Tier Ladder

Status: ready-for-dev

## What this story supersedes / measures against the brief

The task brief carries several claims worth checking against the code before any AC is written.
Measured, not assumed:

1. **A `stun` `TimingWindow` and `STUNNED` `ActionState` ALREADY EXIST, since E1.** `HeroState`'s
   eight windows are `windup, active, recovery, chain, deflect, roll_iframe, roll_duration, stun`
   (`hero_state.gd:104-111`); `stun` is ticked every tick inside `tick_timers()` (`hero_state.gd:415`)
   and is already a `to_snapshot()` key (`hero_state.gd:461`). `ActionState.STUNNED` is already a row
   in `TRANSITION_TABLE` — present but **empty** (`&"stunned": {}`, `hero_state.gd:65`), and the row is
   already zero-inbound-edge, GUARDED by `test_action_state.gd:82-97`
   (`test_table_has_no_inbound_stunned_charging_or_dead_edges`). None of this is new plumbing to add —
   it is the E1 "reserved, unreached" shape this story is the one that reaches.
2. **A single `stun_seconds` `BalanceConfig` field already exists**, authored `0.6` in
   `data/balance/balance_config.tres:123` (`balance_config.gd:284-287`), explicitly commented DATA
   ONLY, and explicitly EXEMPT from `test_balance_authoring.gd`'s positive-duration audit
   (`test_balance_authoring.gd:9-11`). Ruling 2 (below) asks for TWO durations — this story therefore
   either repurposes this ONE field for one of the two stuns and adds a second, or replaces it
   outright. See AC 1 for the naming call.
3. **The `deflect_landed` signal has exactly ONE emit site today that is reachable from a HERO
   attacker**, inside the generic `_resolve_contacts()` melee/unit ladder (`match_state.gd:1433-1446`).
   A SECOND emit site exists, but it is `_resolve_charge_landing`'s color-counter negation
   (`match_state.gd:2687-2751`, specifically the emit at `match_state.gd:2735`), which 5-5 shipped as
   a NO-STUN path by explicit ruling ("no stun of any kind on either party ... `STUNNED` stays the
   zero-inbound-edge row it has been since E1", `match_state.gd:2710-2714`). Both of this story's two
   stun consequences attach to these two ALREADY-WIRED emit sites; neither needs a new signal or a
   tenth observation seam.
4. **An open roll iframe does NOTHING to an unblockable landing today.** `_resolve_charge_landing`'s
   own header is explicit that it consults "NO BLOCK, NO DEFLECT, NO ARC" (`match_state.gd:2667-2668`)
   — and, measured directly against the function body (`match_state.gd:2687-2751`), it also never
   calls `target.hero.is_iframe_open()` anywhere. Compare the GENERIC step-4 contact ladder, which DOES
   drop a fact outright on an open iframe, before dedupe, with no damage/hit_landed/mana/signal
   (`match_state.gd:1388-1393`, the `1-9/R1` rung). The unblockable's own path is a **structurally
   separate function** from that ladder (confirmed by the header's own enumeration of what it does NOT
   consult) — so the dodge rung (Ruling 1b) is **entirely new logic inside `_resolve_charge_landing`**,
   not a pre-existing behaviour to merely surface. Do not assume the generic ladder's iframe-drop
   applies here by osmosis; it does not, by construction.
5. **`_resolve_basic_cast` never reads `action_state` anywhere in its body**
   (`match_state.gd:2299-2382`, confirmed by grep — zero occurrences of `action_state` in the
   function). Its own AC 3 (5-5 story, referencing `match_state.gd:2436`) states the omission BY
   DESIGN for BLOCKING/ATTACKING/ROLLING ("an instant summon that interrupts nothing") — but the
   comment never mentions CHARGING, and 5-5's own Open Questions section names this exact gap as
   INHERITED FROM 5-2 and explicitly assigns it to `5-6` (`docs/implementation-artifacts/5-5-unblockable-defense.md:380-397`).
   `_resolve_defense_cast` (5-5, `match_state.gd:2592-2598`) already carries the EXACT idiom to mirror:
   a bare `if player.hero.action_state == HeroState.ActionState.CHARGING: reject_action(...,
   REASON_UNBLOCKABLE_COMMITTED); return` as the SECOND gate, after the flag check and before the
   empty-slot check. `REASON_UNBLOCKABLE_COMMITTED` (`match_state.gd:2412`) fits without qualification
   — reused a third time (mode ②'s own refusal, mode ③'s CHARGING refusal, now mode ①'s).
6. **The stun window's reset/freeze coverage is ALREADY FREE, inherited from `tick_timers()` being a
   generic per-hero call.** `stun.tick()` sits inside `HeroState.tick_timers()` (`hero_state.gd:415`)
   beside every other window, ticked from `match_state.gd`'s per-hero step 2 exactly like `windup`,
   `active`, `roll_iframe`, etc. — there is no per-field wiring in `match_state.gd`'s step 2 the way
   `charge_window`/`defense_window` needed (those live on `PlayerState`, a `5-2/R9` special case; `stun`
   lives on `HeroState` and rides the SAME generic tick call every other hero window already does).
   The round-over freeze (step 1b returns before step 2) already freezes `stun` for the identical
   reason it freezes `windup`/`active`/etc. — nothing new to wire for the FREEZE. **This claim is
   narrower than it reads, and is corrected by AC 13 below: the RESET is a separate mechanism from the
   freeze, and it is NOT already free** — `_reset_player`'s debug reset needs its own new named
   exception (AC 13) for the same reason `CHARGING` and the defense window already have one, or a
   stunned hero could carry a live `stun` window across a round boundary. This story's reset/freeze
   obligations are therefore two, not one: making sure the two new call sites that `start()` the window
   are the only ones during normal play, that `STUNNED`'s own timer-exit arm (AC 12) is what returns the
   hero to `IDLE` during normal play (mirroring `ROLLING`'s exact shape, `match_state.gd:895-897`,
   rather than inventing a new exit mechanism), AND that the debug reset clears a stunned hero
   (AC 13).
7. **No new `InputIntent` field, no `FeatureFlags` field, `FORMAT_VERSION` STAYS AT 7 (measured,
   `src/systems/record_file.gd:157`).** Every new gate this story adds is a READ of existing
   `action_state`/window state at existing resolution seats (`_resolve_charge_landing`,
   `_resolve_contacts`, `_resolve_actions`, `_resolve_basic_cast`) — no new intake surface, no new
   injection seam, no new contact kind. `flags.unblockable` (already read by modes ②/③) is the correct
   layer gate for the dodge rung and the color-counter stun (both live inside
   `_resolve_charge_landing`, which is already unreachable with the layer closed); the melee-deflect
   stun/penalty needs NO layer gate at all — melee deflect is E1 content with no `FeatureFlags` guard
   today (`is_deflect_window_open()`, `block_damage_multiplier` etc. are all ungated), and this story
   does not add one.

## Story

As the operator implementing the RGB read exchange's third and final rung,
I want an unblockable landing to resolve through all three tiers — color negation with attacker
stun, a roll-timed dodge with reduced damage and no orb, or an unanswered full hit — and a deflected
melee swing to cost its attacker a stamina penalty and a short stun,
so that every branch of the defensive ladder carries its own consequence, `STUNNED` stops being
E1-reserved data, and the CHARGING hole in basic-cast resolution closes before it becomes a live
exploit.

## Acceptance Criteria

**Balance authoring — two stun durations, a dodge multiplier, a deflect penalty (`balance_config.gd`,
`balance_ticks.gd`, `test_balance_authoring.gd`, `test_data_resources.gd`)**

1. **The existing `stun_seconds` field is RENAMED to `color_counter_stun_seconds`** and re-authored
   `1.0` (superseding the current `0.6` — the GDD's own "~1s", `gdd.md:241`), and a NEW sibling field
   `deflect_stun_seconds` is added, authored `0.4` (provisional, per Ruling 2). Renamed rather than
   left bare `stun_seconds` beside a new `deflect_stun_seconds`, because once TWO stun durations exist
   a name that says neither which ladder tier it belongs to nor how it differs from its sibling is
   ambiguous by construction — this is a naming call, not a values call (the VALUES are the operator's
   ratified starting points; the field NAME is this story's own to make legible). `balance_ticks.gd`'s
   `stun_ticks` (`balance_ticks.gd:76,122`) is renamed to `color_counter_stun_ticks` in lockstep, and a
   new `deflect_stun_ticks` conversion joins it, both via `TimingWindow.seconds_to_ticks` — the
   `unblockable_*` conversion family's exact idiom. `test_balance_config.gd:56,70`'s `stun_seconds`
   literal and `stun_ticks` assertion are renamed to match (mechanical, not a forced NEW obligation —
   the file's existing non-exhaustive-literal finding from 5-5 AC 14 is unaffected). **The rename
   ripples through THREE `src/` files** (`balance_config.gd`'s field, `balance_ticks.gd`'s field and
   conversion, `match_state.gd`'s AC 5 consumer) **plus `data/balance/balance_config.tres`** — this is
   not a tests-only rename. Godot silently DROPS an unknown `.tres` property rather than erroring on
   it, so the script field's new name and the `.tres` key must be renamed in the same breath; a
   `.tres` left on the old `stun_seconds` key after the script field becomes
   `color_counter_stun_seconds` would silently author `0.0` (the field's own declared default) with no
   load error to catch it.
2. **Two new fields, one per remaining tier of the ladder.**
   - **A NEW `deflect_stamina_penalty: float` field**, distinct from the EXISTING
     `deflect_stamina_cost` (`balance_config.gd:23`) — that field is what the DEFENDER spends to
     execute a deflect (`match_state.gd:1433-1434`); this is what the ATTACKER loses as the deflect's
     consequence, authored provisionally `12.0` (Ruling 2), joining the `Defense` `@export_group`
     (`balance_config.gd:270`) beside `deflect_stamina_cost`.
   - **A NEW `dodged_unblockable_damage_multiplier: float` field**, joining the `Unblockable`
     `@export_group` (`balance_config.gd:296`) beside `unblockable_damage_percent_of_max_hp`, authored
     `0.0` (Ruling 1b's ratified starting value). This generalises the GDD table's hardcoded "None"
     damage on a dodge (`gdd.md:240`) into an authored knob — the GDD's `~20%` figures elsewhere in
     the same table are OCCURRENCE-RATE playtest targets ("dodge or leave range (~20% target)",
     `gdd.md:240`, `decision-log.md:59-61`), not a damage percentage, so there is no live contradiction
     to resolve in code; this AC only makes a currently-implicit zero into an authored, tunable value.
     A one-line comment at the field notes the GDD table's Damage cell reads "None" today — a future
     non-zero retune of this field owes a `docs(gdd)` amendment at that time; no amendment is owed
     now, since the shipped value keeps the GDD's claim true.
3. **All four new/renamed fields join `E1_BALANCE_FIELDS`** (`test_data_resources.gd:97`, the
   reflective audit list) — `color_counter_stun_seconds`, `deflect_stun_seconds`,
   `deflect_stamina_penalty`, `dodged_unblockable_damage_multiplier`. The two `*_seconds` fields are
   independently caught by `test_data_resources.gd`'s `*_seconds` → `*_ticks` reflective probe
   regardless of this list (`5-5` AC 14's precedent), so their `BalanceTicks` twins (AC 1) are not
   optional.
4. **The `test_balance_authoring.gd` `stun_seconds` EXEMPTION IS REMOVED** (the header note at
   `test_balance_authoring.gd:9-11`, and its "deliberately absent" callout at
   `test_balance_authoring.gd:40-41`). **The two stun durations do NOT join `ACTION_SECONDS_FIELDS`**
   (`test_balance_authoring.gd:42-50`) — that list is explicitly scoped to "every action `*_seconds`
   duration the 1-3 machine consumes" (`test_balance_authoring.gd:39-41`), i.e. the ATTACKING phase
   machine; `stun` is not a 1-3 phase and neither later duration family (the mode ②/③ chargeup/defense
   pair, the `5-5`-precedent bespoke test below) joined that list either — both took their own bespoke
   function instead, and this story follows the SAME precedent rather than widening
   `ACTION_SECONDS_FIELDS`'s scope. A NEW
   `test_authored_stun_values_are_positive_and_correctly_ordered()`, on the `5-5`
   `test_authored_defense_values_are_positive_and_correctly_ordered()` template
   (`test_balance_authoring.gd:143-166` shape), asserts BOTH stun durations `> 0.0` in the same function
   ("0-tick stuns degenerate the mechanism" applies to both exactly as it would inside
   `ACTION_SECONDS_FIELDS`) PLUS the directional bound `color_counter_stun_seconds >
   deflect_stun_seconds` — the `5-5` "both directions asserted, not just `> 0`" precedent (there:
   `defense_window_seconds > unblockable_chargeup_seconds`, `defense_stamina_cost <
   unblockable_stamina_cost`) — because a bare positivity bound would pass on an authored pair that
   INVERTED the escalation gradient Ruling 2's own text requires ("the color counter's ~1s ... markedly
   shorter ... so the three-tier ladder keeps its escalation gradient", `decision-log.md:8142-8144`),
   shipping a broken ladder while every other audit stayed green. `deflect_stamina_penalty` joins
   `test_authored_stamina_economy_values_are_positive()` (`test_balance_authoring.gd:76-91`) as its
   SIXTH line, the same `attack_stamina_cost`/`unblockable_stamina_cost` `> 0.0` precedent — a zero
   penalty silently disarms `E5-P/R1`. `dodged_unblockable_damage_multiplier` keeps ONLY a bespoke
   `<= 1.0` upper bound (the `block_damage_multiplier` strict-open-interval class does NOT apply here —
   `0.0` is this story's own ratified starting point, so the audit must pass at the authored value on
   day one, and `1.0` is the boundary at which a dodge stops reducing anything relative to Ruling 1c);
   the `>= 0.0` half is NOT re-asserted here — it is ALREADY covered by `test_data_resources.gd`'s
   `E1_BALANCE_FIELDS` non-negative loop (`test_data_resources.gd:136-138`, the `attack_lunge_distance`
   "non-negative, zero is the authored value" class), since AC 3 puts this field in that list too; citing
   an existing guard rather than re-asserting it twice.

**Color-counter stun — the negation branch (`_resolve_charge_landing`, `match_state.gd:2730-2737`)**

5. **A color match now ALSO starts the ATTACKER's `stun` window and transitions the attacker to
   `STUNNED`**, added inside the existing negation branch, after the existing `deflect_landed` emit and
   window-consumption lines. The ATTACKER here is `player` (the caster whose chargeup just landed and
   was answered) — `_resolve_charge_landing(player, slot)`'s own parameter, not `target` (the
   defender who answered). `player.hero.stun.start(balance_ticks.color_counter_stun_ticks)` then
   `player.hero.set_action_state(HeroState.ActionState.STUNNED)`. The function's bottom carries one
   unconditional `player.hero.set_action_state(HeroState.ActionState.IDLE)` exit line
   (`match_state.gd:2751`) covering every outcome today; this AC REQUIRES the function be restructured
   so that line fires ONLY for the miss/full-damage/dodge outcomes, and the negation branch's own
   `STUNNED` write is the negation outcome's ONLY `set_action_state` call — **every
   `_resolve_charge_landing` outcome calls `set_action_state` EXACTLY ONCE, with no exception.** A
   second, unconditional write after the negation branch's own write is REJECTED as a shape (see Dev
   Notes for why: queued `action_state` signal consumers drain both writes, and a phantom `IDLE`
   observed through `connect_hero_action_state_changed` would be a state the hero never actually held).
   The restructure itself (an `if`/`elif`/early-return shape) is the dev pass's call which reads
   clearest. **`test_unblockable_defense.gd:409` INVERTS as this story's own regression fix**: `5-5`
   shipped `test_a_negation_stuns_nobody()` (`test_unblockable_defense.gd:405-412`) with P1's assertion
   reading `assert_false(ms.p1.hero.stun.is_running, "the ATTACKER is not stunned (that decision is
   \`5-6\`'s)")` — that decision is now made, so P1's stun/action-state assertions FLIP to a POSITIVE
   check (`stun.is_running` true, `action_state == STUNNED`) while P2's (the defender's) stay
   `assert_false`/`assert_ne` exactly as `5-5` shipped them, unchanged. Named here and in Project
   Structure Notes so the fix is not mistaken for a dropped regression.
6. **This is the FIRST inbound edge to `STUNNED` in the whole project.** `test_action_state.gd:82-97`
   (`test_table_has_no_inbound_stunned_charging_or_dead_edges`) is a `TRANSITION_TABLE` scan and stays
   GREEN, functionally unedited by construction — entering `STUNNED` here is a direct `set_action_state`
   call from inside `_resolve_charge_landing`, not a table edge, the exact `DEAD`-entry precedent
   (`hero_state.gd`'s own "DEAD is entered only by the step-8 resolution, a non-table path" comment,
   confirmed by `test_action_state.gd:80-81`). **What DOES need to change is stale prose, at FOUR named
   sites, none of them a functional edit**: `hero_state.gd:40-42`'s "STUNNED: row PRESENT but
   UNREACHABLE ... entering STUNNED would resolve OPEN decision (a) by accident" (now FALSE — this
   story IS the resolution); `hero_state.gd:101`'s "stun is owned and advanced but NEVER start()ed by
   any E1 path" (now false the moment AC 5/AC 9 start it, even though the field itself is untouched);
   `balance_ticks.gd:74-75`'s "Converted like every duration, but DATA ONLY in E1 — nothing starts a
   stun window until OPEN decision (a) resolves" (same falsehood, second location); and
   `match_state.gd:2710-2714`'s "NO STUN of any kind on either party ... STUNNED stays the
   zero-inbound-edge row it has been since E1" inside `_resolve_charge_landing`'s OWN negation-branch
   comment block — the negation branch's NO-STUN claim was true for the DEFENDER always and for the
   ATTACKER only until this story; it must be corrected to say the attacker now DOES stun (AC 5), the
   defender still never does. All four are rewritten to name this story as the resolution, on the `5-5`
   precedent of updating a forward-reference comment once it resolves (`match_state.gd:2670-2675`).
   `test_action_state.gd:76-77`'s own doc-comment above
   `test_table_has_no_inbound_stunned_charging_or_dead_edges` carries the same stale "would resolve OPEN
   decision (a) by accident" line — its fix is comment-only, so the function's "re-run unedited" claim
   is more precisely "functionally unedited (comment-only touch, stated)", not literally byte-identical.
   `test_balance_authoring.gd`'s own now-stale exemption comment is covered by AC 4. **A NEW positive
   guard replaces the OLD negative-only framing** (brief's own instruction: replace, do not delete) — a
   test asserting the TRANSITION_TABLE itself is STILL untouched (zero table edges, the existing scan
   stays green) PLUS a new enumeration of the exactly-two AUTHORED non-table entry points (this AC's
   `_resolve_charge_landing` call and AC 9's `_resolve_contacts` call). The guard scans ALL of `src/`
   (not just `match_state.gd` — the AC means "the whole project", and a future story could add a third
   call site anywhere under `src/`), via the comment-stripping `_code_lines` idiom
   (`test_replay_identity.gd:787-800`) so a comment merely mentioning the token (as `match_state.gd:2713`
   already does) is not miscounted as a call site, and asserts the total count of
   `set_action_state(HeroState.ActionState.STUNNED)` across live code is EXACTLY 2 — both call sites are
   written on ONE line each today, a detail worth stating since a future formatter split across lines
   would fail this guard safe (undercounting) rather than silently passing, which should not surprise a
   future reader. The same "positive enumeration, not just an absence" shape
   `OBSERVATION_SEAMS`/`SHIPPED_INPUT_ACTIONS` already use elsewhere in this codebase for a locked set.

**The dodge rung — NEW logic (`_resolve_charge_landing`, the `else` arm, `match_state.gd:2738-2746`)**

7. **Inside the existing `else` arm (color match failed), a NEW inner branch checks
   `target.hero.is_iframe_open()` BEFORE computing full damage.** Ladder order, per Ruling 1: (a)
   color match (AC 5, checked first, unchanged) → if false, (b) NEW: is the defender's roll iframe
   open (`is_iframe_open()`, `hero_state.gd:228-229` — covers both the running window AND its 1-tick
   grace, the SAME predicate the generic ladder reads at `match_state.gd:1393`) → if true, damage is
   `(balance.unblockable_damage_percent_of_max_hp / 100.0 * target.hero.get_max_hp()) *
   balance.dodged_unblockable_damage_multiplier`, and `hit_landed` emits ONLY when that effective
   damage is `> 0.0` — the multiply-and-emit-at-surviving-magnitude precedent
   (`block_damage_multiplier`, `match_state.gd:1447-1456`) applies whenever a retuned value makes the
   damage positive, but at the authored `dodged_unblockable_damage_multiplier = 0.0` the effective
   damage is exactly zero, so a clean dodge is SILENT: no `hit_landed`, no damage, the same full
   suppression the color-match tier gets, not merely a zero-magnitude emit. `_grant_landing_orbs` is
   SKIPPED either way (zero orbs, Ruling 1b) → if false (no iframe open either), (c) fall through to
   the EXISTING unchanged full-damage + orb-grant path (Ruling 1c, untouched).

   **CORRECTION — the observation point, not merely the predicate, is what makes this symmetric with
   the generic ladder.** An earlier framing of this AC claimed "same predicate, same observation as the
   generic ladder" — that is false as stated: the two ladders read `is_iframe_open()` at different
   points in the tick, and what actually needs to match across BOTH player slots is not the predicate
   alone but a DEFINED observation point. The contract: `_resolve_charge_landing` consults the
   defender's iframe state AS OF THE START OF STEP 3 — after step 2's ticks have advanced every window
   (including the grace-tick transient), but BEFORE any same-tick press is resolved. Consequently: a
   roll PRESSED on the very tick the charge lands dodges on NEITHER slot (the press hasn't been
   resolved into `roll_iframe`/the grace transient yet, from either seat's perspective); a roll from the
   PREVIOUS tick — including the `1-9/R2` grace-tick semantics — dodges on BOTH slots identically. The
   implementation shape that achieves this (a per-hero predicate captured before same-tick press
   resolution, vs. a restructure of resolution order) is the dev pass's own call, argued in Completion
   Notes either way. **NEW two-slot headless boundary test** (`test_unblockable_defense.gd`): both
   player slots crossed with {previous-tick roll = dodge, same-tick roll = no dodge} — four cases in one
   test — proving the boundary is identical regardless of which slot is charging and which is
   defending; this is also the test the Live Smoke section's cut flip-item now cites as its headless
   replacement.

   At the authored
   `dodged_unblockable_damage_multiplier = 0.0`, this reads identically to a full miss at the shipped
   value while remaining a genuine multiply-and-conditional-emit for whenever the value is retuned
   positive. **NO STUN of any kind on this branch** — Ruling 1b names no attacker consequence for a
   dodge, unlike 1a; do not add one by analogy with AC 5.
8. **`target.hero.is_iframe_open()` is read, `roll_iframe`/`_roll_iframe_closed_this_tick` are NOT
   consumed or cleared by this branch** — the SAME "read-only, drop-the-fact" idiom the generic ladder
   uses (`match_state.gd:1393`, which likewise only READS the predicate). A dodge against an
   unblockable does not end the iframe window early or extend it; the window runs its own course
   exactly as `1-9/R3` already requires for every OTHER contact.

**Melee-deflect stun + stamina penalty (`_resolve_contacts`, `match_state.gd:1433-1446`)**

9. **Inside the EXISTING melee/unit deflect branch, gated to HERO ATTACKERS ONLY** (`attacker_index
    == TargetingService.HERO_INDEX`, the `4-3b/R4` mana-gate precedent at `match_state.gd:1463`
    applied a second time to a second hero-only consequence), the ATTACKER's `stun` window starts
    (`attacker.hero.stun.start(balance_ticks.deflect_stun_ticks)`,
    `attacker.hero.set_action_state(HeroState.ActionState.STUNNED)`) and the ATTACKER's stamina is
    drained by `deflect_stamina_penalty`. **A UNIT attacker (a minion) is explicitly EXCLUDED — this is
    `4-3b/R7`'s standing ruling ("deflecting a minion does NOT stun it, for now") carried forward
    unchanged**, and structurally true regardless: a unit has no `ActionState`/`stun` field to enter
    (`4-3b/R20`'s own reasoning, `match_state.gd:1358-1365`) — the gate exists because a hero DOES have
    one, not merely as an extra guard. `test_block_deflect.gd:459-472`'s negative guard (no stun on a
    deflected minion) is RE-RUN UNEDITED as this story's own regression proof that the hero-only gate
    holds. This is the SECOND (and last) authored inbound edge to `STUNNED`, completing AC 6's positive
    enumeration (exactly 2 `set_action_state(HeroState.ActionState.STUNNED)` call sites in
    `match_state.gd`: this one and AC 5's).
10. **The stamina drain uses `attacker.stamina.add(-balance.deflect_stamina_penalty)`, NOT
    `.spend(...)`.** Measured against `StaminaPool` (`stamina_pool.gd:42-47`): `spend()` REFUSES
    outright (returns false, changes nothing) when the amount exceeds the current balance — the
    correct shape for a VOLUNTARY, affordability-gated cost (roll, attack, deflect-by-the-defender,
    every existing stamina spend in this codebase), where an unaffordable action simply does not
    happen. A PUNITIVE drain is the opposite contract: it must always apply, floored at zero, and
    never be silently skipped because the attacker happened to be poor — `.add(-amount)`
    (`stamina_pool.gd:28-33`) already clamps to `[0, maximum]` and is the mechanism `refill()` and the
    per-tick regen already use for an unconditional adjustment. Using `.spend()` here would let a
    stamina-starved attacker escape the penalty entirely, the opposite of `E5-P/R1`'s intent.
    `.add()` does NOT restart `_regen_delay` (only `.spend()` does) — the penalty affects the CURRENT
    balance only, not the regen cadence, which is the correct scope for a consequence rather than a
    cost.
11. **A stunned attacker's hitbox stops querying, closing the orphaned-swing hole the Open Questions
    section names.** `is_hitbox_active()` (`hero_state.gd:210-211`) currently returns bare
    `active.is_running`; it is WIDENED to `active.is_running and action_state == ActionState.ATTACKING`.
    Its single consumer is `match_runner.gd:1594`'s `_gather_contact_facts` — no other seat reads it,
    so this is a one-line, one-consumer change. AC 9's immediate-interrupt reading means an attacker
    whose swing gets deflected is `STUNNED` while `active` may still be running (the window ticks out
    orphaned, per the 1-9 discipline of never early-stopping a window) — before this AC, a hitbox query
    against that ORPHANED window would still gather contact facts from a hero no longer `ATTACKING`,
    landing a strike from a hero already being punished for one. After this AC, the hitbox simply stops
    being queried the instant `action_state` leaves `ATTACKING`, regardless of why (this closes the same
    hole for any future non-`ATTACKING` interrupt, not just this story's `STUNNED`). Headless test: a
    strike/contact fact sourced from a stunned attacker against a unit is dropped entirely, plus the
    existing same-target dedupe fact restated (a deflected fact already consumed the dedupe record, so
    there is nothing left for the orphaned window to re-report even without this fix — this AC's own
    test proves the fact is dropped at the SOURCE, not merely deduped downstream).

**`STUNNED`'s own lifecycle — timer exit, rooting, action refusal (`hero_state.gd`, `match_state.gd`)**

12. **A NEW `HeroState.ActionState.STUNNED:` arm joins the step-3 timer-driven exit `match`
    (`match_state.gd:885-915`), mirroring `ROLLING`'s exact shape**
    (`match_state.gd:895-897`): `if not hero.stun.is_running: hero.set_action_state(HeroState.ActionState.IDLE)`.
    Without this arm a stunned hero would never exit — `stun` ticks to zero and stays there forever,
    since nothing else in `_resolve_actions` reads it (measured: the function's `match` has no default
    arm, confirmed by reading it in full, `match_state.gd:876-926`). **This is a NATURAL-EXPIRY-ONLY
    exit — no early-stop path is introduced anywhere** (Ruling 3 / the `1-9` precedent this ruling
    explicitly reasserts): nothing in this story adds a way to cut a running `stun` window short, the
    same guarantee `ROLLING`'s own timer arm gives `roll_duration` and `CHARGING`'s gives
    `charge_window`.
13. **`STUNNED` joins the debug reset's "clear action state" entry, as the FIFTH named exception to
    `_reset_player`'s "nothing else / in-flight windows untouched" contract** (`match_state.gd:3411-3470`
    — `4-1/R5`'s unit board is the first, `5-3`'s chargeup the second, `5-4`'s orb pool the third,
    `5-5` AC 12's defense window the fourth). `hero.stun.start(0)` joins `charge_window.start(0)` in the
    same breath, and `STUNNED` joins the `DEAD or CHARGING` action-state clear:
    `if hero.action_state == HeroState.ActionState.DEAD or hero.action_state ==
    HeroState.ActionState.CHARGING or hero.action_state == HeroState.ActionState.STUNNED:
    hero.set_action_state(HeroState.ActionState.IDLE)`. **The defect this closes is traced, on the exact
    `5-3`/`5-5` shape**: step 1b returns BEFORE step 2's `stun.tick()`, so once `_round_over` latches a
    running `stun` window STOPS COUNTING but stays armed — without this exception, a hero stunned right
    before the other one died would come out of the reset still `STUNNED` with a live window, carrying
    the stun into the NEXT round exactly as an un-cleared chargeup or defense window would. **The
    round-over freeze itself is untouched**, the same "latched round-over freezes but does not disarm
    the window" property `5-3`/`5-5` already established — this is a RESET-time clear, not an
    `_end_round`-time one. The stale ordinal comments naming the prior exceptions "FOURTH" in
    `_reset_player`/`_apply_debug_reset` are updated to reflect this fifth addition. A test sits beside
    the `5-5` AC 12 sibling (`test_unblockable_defense.gd:568-587`) or in the stun tests' own home file
    — a stunned hero survives a debug reset `IDLE`, un-stunned, with the window stopped. **This also
    corrects this story's own earlier "reset/freeze coverage is already free" superseded-item claim
    (item 6, above)**: that claim is right about the per-tick FREEZE (nothing new to wire there,
    `tick_timers()` is generic) but wrong to imply the RESET needs nothing — the reset is a separate
    mechanism from the freeze, and `STUNNED` needs its own named exception there exactly as `CHARGING`
    and the defense window already do.
14. **`STUNNED` is added to the movement hard-root `elif` chain**
    (`match_state.gd:3078-3092`, the function `1-9/R6`/`5-2/R5` already established), as a THIRD
    sibling beside `ROLLING` and `CHARGING`: `elif player.hero.action_state ==
    HeroState.ActionState.STUNNED: player.hero.velocity = Vector3.ZERO` — the `5-2/R5` "literal zero,
    not a multiplier" reasoning applies identically (rooted must not be a tuning value a retune can
    quietly soften). Facing is DELIBERATELY left to fall through to the generic lock-direction branch
    below (`match_state.gd:3141-3147`) — Ruling 3 forbids ACTION and MOVEMENT, not the visual heading;
    this is the same fallthrough `ROLLING`/`ATTACKING` already get (facing tracks the lock while
    velocity is overridden), not a new carve-out.
15. **`STUNNED` forbids every action by construction, already, with NO new code**: `transition_row()`
    already maps `STUNNED` to `&"stunned"` (`hero_state.gd:321-322`), whose `TRANSITION_TABLE` row is
    already the empty dictionary (`hero_state.gd:65`) — a press with no entry in the row is dropped,
    never buffered (`match_state.gd:916-917`'s existing part-(b) contract). This covers attack, roll,
    and block (all table-driven edges) automatically. Basic cast and defense cast are NOT table-driven
    (they resolve through `_resolve_card_action`'s own dispatch, `match_state.gd:2222-2243`) and
    therefore need their OWN explicit `STUNNED` refusal, mirroring the existing `CHARGING` refusal
    shape each already has or gains: `_resolve_defense_cast` already refuses on `CHARGING`
    (`match_state.gd:2596-2598`) — extend that SAME check to `action_state == CHARGING or
    action_state == STUNNED` (both commitments the caster cannot answer from), reusing
    `REASON_UNBLOCKABLE_COMMITTED` for `CHARGING` and a NEW `const REASON_STUNNED := &"stunned"` for the
    `STUNNED` arm, since "an unblockable is committed" does not read true for a stunned caster.
    `REASON_STUNNED` lives on `MatchState` beside `REASON_UNBLOCKABLE_COMMITTED`
    (`match_state.gd:2412`) — the constant's own header rule ("named HERE rather than on
    `CastEvaluator`, because `CastEvaluator` is not consulted on this path at all", `match_state.gd:2407-2409`)
    applies identically to this second reason. The naming convention it borrows is narrower than
    "`CastEvaluator`'s `REASON_*` vocabulary" — `CastEvaluator` is never consulted on either refusal
    path, so what's actually borrowed is only the TOKEN convention (a lowercase `StringName` naming the
    player-visible fact, `REASON_EMPTY_SLOT`-style), the same distinction
    `REASON_UNBLOCKABLE_COMMITTED`'s own header already draws. `_resolve_basic_cast` gains the SAME
    two-state check as its own new CHARGING gate (AC 16) — one function, one `if`, both states, not two
    separate refusals, and **ONE SHARED `REASON_STUNNED` constant serves BOTH refusal seats**
    (`_resolve_defense_cast` and `_resolve_basic_cast`), the `REASON_EMPTY_SLOT` reuse precedent applied
    a second time — this closes the Deferred naming question below rather than leaving it open.
16. **The CHARGING hole closes**: `_resolve_basic_cast` gains a two-arm refusal — `if
    player.hero.action_state == HeroState.ActionState.CHARGING: player.hero.reject_action(&"card_cast",
    REASON_UNBLOCKABLE_COMMITTED); return` `elif player.hero.action_state ==
    HeroState.ActionState.STUNNED: player.hero.reject_action(&"card_cast", REASON_STUNNED); return`
    (`REASON_STUNNED`, the shared constant AC 15 defines) as
    its FIRST gate, before the existing `is_slot_empty` check (`match_state.gd:2316`) — mirroring
    `_resolve_defense_cast`'s exact ordering (state gate before slot gate,
    `match_state.gd:2592-2599`). `REASON_UNBLOCKABLE_COMMITTED` is reused verbatim for the `CHARGING`
    arm (it already reads true for "cannot cast because committed to an unblockable"); the `STUNNED`
    arm uses its own reason (AC 15) since "committed to an unblockable" does not describe a stunned
    caster. **No other `5-2` chargeup behaviour changes** — this AC touches only `_resolve_basic_cast`;
    `_resolve_unblockable_cast`, `_unblockable_refusal_reason`, and `TRANSITION_TABLE` are all
    untouched (Non-Goals).

**Golden Prediction — the machine contract**

17. **THE GOLDEN MOVES, and the cause is NOT a new key — measured, both directions.** `stun` is
    ALREADY a `to_snapshot()` key (`hero_state.gd:461`) and ALREADY `HASHED` in
    `test_replay_identity.gd:221` (`hero_state.stun`) — this story adds NO new snapshot key and NO new
    `HASHED`/`UNHASHED` classification obligation, unlike `5-2`'s `telegraph` or `5-5`'s `defense`. The
    move is a VALUE change, the `5-4` orbs shape ("the key already existed, a grant path behind it
    moved a resting value"), not the `5-2`/`5-5` shape. **The measured cause: `test_determinism.gd`'s
    fixture ALREADY carries a real melee deflect.** `CONTACTS[5]` (`test_determinism.gd:963`) is P1's
    swing landing on a front-facing, deflect-window-open P2 at t5, and DEFLECTS by design
    (`test_determinism.gd:951-954`'s own comment). P1 is the attacker and a HERO
    (`TargetingService.HERO_INDEX`) — AC 9's gate fires.

    The golden reads `_golden_config()` (`test_determinism.gd:997-1100`), NOT
    `data/balance/balance_config.tres` — that fixture authors NO stun and NO deflect penalty today, so
    without fixture edits both new paths are hash-neutral degenerates
    (`TimingWindow.seconds_to_ticks` maps `<= 0.0` to `0`). The dev pass MUST author both as coverage
    values in `_golden_config()`, distinct from AC 1/AC 2's production authoring (`BC/R3`'s standing
    isolation between authored balance and the golden/unit-suite fixtures holds unchanged — this is a
    fixture-only edit): a SHORT `deflect_stun_seconds` — target ~7 ticks, a count distinct from the
    fixture's own enumerated distinctness set (`test_determinism.gd:848-851`) — so the stun starting at
    t5 ends by ~t11 and leaves the t17 roll clear; and a nonzero `deflect_stamina_penalty` coverage
    value, which MOVES P1's hashed final stamina, so the fixture's stamina arithmetic comment
    (`test_determinism.gd:1005-1013`) must be RE-DERIVED, not merely re-baselined blind.

    At the ~7-tick coverage value, P1 is `STUNNED` from t5 to ~t11 — running, not `IDLE`, at the hash
    tick t24 would be FALSE at a 24-tick duration but the coverage value is deliberately short enough
    that P1 has RETURNED to `IDLE` well before t17; the moved hash key is `hero_state.stun`'s own
    resting value (no longer perpetually zero across the whole fixture the way an unauthored/degenerate
    fixture would read) plus the stamina delta, not a `STUNNED`-at-hash-tick read. **Collision
    resolution: option (a), coverage shift ACCEPTED**, with one unconditionally lost item named in an
    accounting block rather than silently absorbed: the t9 CHAINED-SWING coverage is lost regardless of
    stun length — `STUNNED` at t5 replaces `ATTACKING` immediately (the Open Questions
    immediate-interrupt reading), so `active_done` never fires and the chain window never opens for
    that swing; the t9 press is dropped by the empty `stunned` table row rather than exercised as a
    chain-attack accept. **Preserved by the short (~7-tick) stun**: the t17 roll-cancel press (P1 is
    back to `IDLE` well before t17, so this press fires exactly as before), the t19/t20 iframe
    grace-tick boundary (P1 is `ROLLING`, not `STUNNED`, at t19/t20 — the pre-existing coverage is
    intact), and `roll_direction` coverage. **Gained**: `STUNNED` now appears in the hashed record at
    all (a fixture that previously never exercised the state), plus a positive golden-level proof that
    the t9 press is dropped by the empty `stunned` row. **Equivalent coverage for the one lost item**
    (replacing this story's own earlier, incorrect `test_unit_attack_rhythm.gd` guess): chain-window
    timing is independently covered by `test_action_state.gd:180-240` (last-tick accept, post-close
    drop, cap, roll-cancel reset); the iframe grace boundary is independently covered by
    `test_roll_iframes.gd:88-150` (grace-then-full within the same swing, window-alone grace, a
    running-iframe drop) — both already exist and are unaffected by this story, so the t9 loss is a
    real but already-absorbed-elsewhere loss, not a coverage hole. **`color_counter_stun_seconds`
    contributes NOTHING to this golden**: the fixture's one
    recorded cast (`CAST_TICK := 22`, `test_determinism.gd:838`) is `ModeKind.BASIC`
    (`test_determinism.gd:1686`), never `UNBLOCKABLE` — `_resolve_charge_landing` is never reached, so
    AC 5/AC 7/AC 8 are all UNEXERCISED by the golden and must be proven by
    `test_unblockable_defense.gd`-sibling state tests alone, exactly as `5-5`'s `defense` key was
    proven. **AC 16's CHARGING/STUNNED basic-cast refusal is also UNEXERCISED**: at t22, P1 is
    measured `IDLE` (`test_determinism.gd:831`, "CAST_TICK 22 puts the cast on a tick where P1 is
    IDLE"), so the new refusal gate is never entered — the golden's basic-cast coverage
    (`test_determinism.gd:1684-1686`) stays a pass-through hit against the pre-existing ALLOWED path,
    proving nothing new either way; AC 16 needs its own direct state test. The dev pass owes the SAME
    two reverse measurements `5-2`/`5-4`/`5-5` all ran, each staging out the COMPLETE new write set per
    site — window start, state transition, AND (at AC 9's site) the stamina drain, not just the
    `set_action_state` lines, since `hero.stamina` is itself a HASHED snapshot field
    (`test_replay_identity.gd`) and the deflect penalty is its own hash-relevant delta independent of
    the state transition: (a) stage OUT both AC 5's and AC 9's full write sets — AC 5's
    `stun.start(...)` + `set_action_state(STUNNED)` pair, and AC 9's `stun.start(...)` +
    `set_action_state(STUNNED)` + `attacker.stamina.add(-balance.deflect_stamina_penalty)` triple — and
    confirm the hash reads the INHERITED value exactly; (b) with them IN, confirm the moved value is
    attributable to AC 9's full write set alone (P1's stun state AND its drained stamina at t24) by
    ALSO staging out AC 5's full write set alone and reconfirming the hash is unchanged from (b)
    baseline — proving the color-counter path contributes zero, as argued above, rather than assumed.

## Non-Goals

- **Per-attack-type counters** (sweep/jump/thrust ideas) and **auto-aim** — named explicitly as
  post-E6 material in `5-5`'s own live-smoke item 9, not this story's.
- **Hand-card tinting** — the two-smoke-consecutive finding (`5-4`, `5-5`), elevated to the E5
  close-out inventory; this story adds a third stun/penalty mechanic on top of an already-untinted
  hand and does not fix the legibility gap.
- **Pad scheme, hold-to-charge** — `5-7`'s, unaffected by this story's keyboard-only scope (no new
  Input Map action is needed — see Live Smoke; the existing `p1_attack`/`p1_cast_unblockable`/
  `p2_cast_defense`/`p2_roll` actions are sufficient).
- **Orb spend path** — mode ④ (Pitch) is `E6`'s; this story only decides who GETS orbs (Ruling 1),
  never how they are spent.
- **No `game-architecture.md` edit** — the ARCH AMENDMENT QUEUE flushes at the E5 close-out; this
  story adds no new observation seam (AC 5/AC 9 ride the two EXISTING `set_action_state`/
  `deflect_landed` mechanisms) and therefore no new queue member.
- **No presentation work beyond what already degrades gracefully.** `AnimationController.on_action_state_changed`'s
  own comment already documents `STUNNED` as "(still unmapped) holds the pose"
  (`animation_controller.gd:141`) — the hero visibly freezes on whatever pose it held, which is
  sufficient for the live smoke's "the hero is visibly stopped" check without a new clip. A dedicated
  stun clip/cue, if wanted, is a future presentation story's call, not this one's.
- **No `5-2` chargeup behaviour changes beyond AC 16.** `_resolve_unblockable_cast`,
  `_unblockable_refusal_reason`, and `TRANSITION_TABLE`'s absent `charging` row are all untouched.
- **No new `FeatureFlags` field, no new `InputIntent` field.**

## Deferred

- **Whether a `STUNNED` hero's in-flight `defense_window` (if any) survives or should be
  short-circuited** is not specified by any ruling above. Measured: nothing in this story touches
  `PlayerState.defense_window`/`defense_color` at all, and `_resolve_defense_cast`'s own new refusal
  (AC 15) only prevents ARMING a NEW defense window while `STUNNED` — an ALREADY-RUNNING window from a
  cast made before the stun landed is untouched by this story and continues ticking down at its
  ordinary step-2 rate, exactly like `5-5` AC 11's wrong-color survival. Left to the dev pass's
  judgment whether this interaction is worth a dedicated test or is adequately covered by "nothing
  touches these fields, therefore nothing to test" (the `5-5` referenced-not-edited discipline).

## Live Smoke

1. **A color-matched defense stuns the attacker.** P1 casts UNBLOCKABLE in a color, P2 casts DEFENSE
   in the SAME color before it lands: no damage (as `5-5` already shipped), AND P1 is now visibly
   frozen (holds pose, does not move, does not respond to input) for roughly a second before resuming
   normal control.
2. **An unanswered or wrong-color unblockable still lands full damage and pays an orb** — the
   unchanged Ruling 1c path, a regression check against `5-4`/`5-2`.
3. **A well-timed roll through an unblockable's landing takes little-to-no damage and pays no orb.**
   P2 rolls so its iframe (or grace tick) is open when P1's charge lands: at the shipped
   `dodged_unblockable_damage_multiplier = 0.0` this should read as a clean dodge — no visible damage,
   no orb counter increment for P1.
4. **A deflected melee swing visibly costs its attacker.** P1 attacks into P2's held block, timed for
   a deflect (not merely a block): P1's stamina bar visibly drops by more than the ordinary swing cost,
   and P1 freezes (holds pose) briefly — shorter than item 1's freeze.
5. **A stunned hero cannot act.** During either freeze (item 1 or item 4), pressing attack/roll/
   block/basic-cast/defense-cast on the stunned hero produces no visible effect until the freeze ends.
6. **CHARGING refuses a basic cast.** While a hero is mid-chargeup (CHARGING), pressing basic-cast
   (P1's `card_1`-`card_4` + `cast_confirm`, `flags.unblockable` closed is NOT required — the layer
   gate for basic cast is unrelated) does nothing observable — no card leaves the hand, no summon
   appears.
7. **Nothing else regresses.** Movement, ordinary block (non-deflect), ordinary melee, mode ① casting
   elsewhere in the match, minions, and totems all behave exactly as `5-5` shipped them — deflecting a
   MINION specifically must NOT visibly stun it (AC 9's negative guard), spot-checked if a minion is
   on board during the smoke.
8. **FPS** — no visible frame-rate impact from the two new `set_action_state`/window-start call sites
   or the new step-3 timer-exit arm.

**Item CUT: the flip/seat-symmetry check.** An earlier draft of this list asked the smoke to flip
`slot_controller_kinds` and repeat items 1 and 4 from the other seat, to prove the mechanism is
symmetric across P1/P2. That premise is now proven headless instead, by the AC 7-correction two-slot
boundary test (gate fix, `test_unblockable_defense.gd`): one test exercising BOTH players' slots
against the {previous-tick roll = dodge, same-tick roll = no dodge} boundary, which is exactly the
per-seat symmetry claim the flip smoke item existed to check — a live re-check would only be
confirming what the state suite already proves. It is dropped rather than renumbered-and-kept because
the committed default (`[0, 1]`, `match_runner.gd:31-34`, no `slot_controller_kinds` line in
`main.tscn`) needs no flip for any remaining item either — see the Project Structure Notes' seat note
for where a future flip would live if ever needed.

**Blind-spot note (headless-reachable, per the `test_totem_tint_live.gd` precedent):** items 1-6 are
ALL reachable and MUST be pinned as cheap headless state tests before the smoke, not left as
smoke-only claims — `_resolve_charge_landing`/`_resolve_contacts`/`_resolve_basic_cast` are pure state
functions with no scene dependency. Item 8 (FPS) and the qualitative "holds pose" visual read are the
ONLY genuinely smoke-only items; everything else the smoke merely CONFIRMS what the state suite
already proved.

## Open Questions (left to the gate / dev pass)

- **DOES THE MELEE-DEFLECT STUN INTERRUPT AN IN-PROGRESS SWING?** At the exact tick AC 9's branch
  fires, the attacker is necessarily `ATTACKING` with its `active` window running (a contact fact can
  only be gathered from an active hitbox) — `attacker.hero.set_action_state(STUNNED)` therefore
  REPLACES `ATTACKING` immediately, abandoning the swing's `active`/`recovery`/`chain` windows and
  `_swing_dedupe` record mid-flight rather than letting the swing finish first. Measured: this is safe
  by construction ONCE AC 11 SHIPS — the orphaned windows keep ticking to their own expiry (harmless;
  nothing reads `attack_phase()` while `action_state != ATTACKING`, and a chain-attack pressed after
  `STUNNED` exits to `IDLE` is read as a FRESH swing 0 since `_try_transition`'s `chaining` check tests
  `action_state == ATTACKING` at press time, `match_state.gd:939`, which will be false) — but WITHOUT
  AC 11, the orphaned `active` window would still read `is_hitbox_active()` true and could gather a
  contact fact from a hero the game is simultaneously punishing, which is exactly the gap AC 11 closes;
  the "harmless" half of this claim is true only because AC 11 makes it so, not an independent fact.
  This is
  a PLAYER-FACING BEHAVIOUR CHOICE (does getting deflected cut your swing's own recovery short, Sekiro
  punish-window style, or does the stun only apply once the swing naturally finishes?), not obviously
  locked by any ruling cited above. Ruling 2's text ("the attacker whose swing got deflected") reads
  most naturally as an immediate interrupt, and this document's AC 9 is written that way, but this is
  flagged explicitly rather than silently decided, per the operator's own instruction to stop and ask
  when a choice changes what the game IS. **Recommendation: ship the immediate-interrupt reading (as
  written in AC 9) unless the operator says otherwise before or during the dev pass** — reverting to
  a deferred-stun shape is a larger, more invasive change (STUNNED would need to queue behind
  ATTACKING, which nothing in this codebase's single-`action_state` model currently supports) that
  should not be discovered mid-implementation.
- **Golden re-baseline shape** — AC 17's fixture-collision finding (P1's existing t9/t17 presses and
  t19/t20 contacts get reinterpreted by the new stun) is measured but its RESOLUTION (accept the
  coverage shift vs. rework the fixture's tables to avoid the collision) is explicitly left to the dev
  pass, with the reasoning and both options laid out in AC 17 itself.
- **Whether `test_unblockable_defense.gd` gains this story's `_resolve_charge_landing` ACs (5, 7, 8)
  or a new sibling file is warranted**, the same call `5-5`'s own Open Questions left open for itself
  and answered by keeping everything in one file; likely the same answer here (color-counter stun and
  the dodge rung are both landing-branch content in the SAME function `test_unblockable_defense.gd`
  already covers), dev's to confirm. The melee-deflect stun/penalty (AC 9-10) more naturally joins
  `test_block_deflect.gd`, which already owns `4-3b/R7`'s negative guard this story's positive case
  sits beside.

## Dev Notes

- **The `_resolve_charge_landing` exit restructure (AC 5) is the one place this story asks for
  judgment on SHAPE, not content.** The function currently ends with one unconditional
  `player.hero.set_action_state(HeroState.ActionState.IDLE)` line covering every outcome
  (`match_state.gd:2751`). AC 5 needs the color-matched branch to end in `STUNNED` instead, and
  requires it get there via exactly one `set_action_state` call for that outcome: move the `STUNNED`
  transition INSIDE the negation `if` block and change the trailing line to only fire when NOT negated
  (an `if negated: ... else: ... ; if not negated: set IDLE` restructure, or an equivalent
  `if`/`elif`/early-return shape — the dev pass's call which reads clearest). A shape that instead
  leaves the trailing `IDLE` write unconditional and relies on a SECOND `set_action_state` call (to
  `STUNNED`, placed after it in source order, "last write wins") is REJECTED, not merely
  discouraged: `action_state` changes are observed through queued signals
  (`connect_hero_action_state_changed`), and a queued consumer draining both writes would see the hero
  pass through `IDLE` on a tick it was never actually `IDLE` on — a phantom transition reaching
  presentation code that then acts on a state that never existed. Exactly one `set_action_state` call
  per outcome, full stop.
- **Why AC 9's gate reuses `attacker_index == TargetingService.HERO_INDEX` rather than checking
  `attacker is PlayerState` or similar** — `attacker` (the `PlayerState`) is ALREADY resolved by this
  point in `_resolve_contacts` regardless of whether the attacker is the hero or one of that player's
  minions (`match_state.gd:1342`); `attacker_index` is the field that actually distinguishes "this
  fact's origin was the hero itself" from "this fact's origin was unit N on this player's board" — the
  EXACT and ONLY correct discriminant, matching the `4-3b/R4` mana-gate precedent this AC is explicitly
  modelled on.
- **Do not conflate AC 7's dodge multiplier with AC 5's color negation.** They are two SEPARATE rungs
  of the SAME `else` arm (color match failed) and must be named separately in Completion Notes, the
  `5-2/R8`/`5-4`/`5-5` "two findings, named separately" discipline applied a fourth time.
- **The stun window's `remaining_ticks()` already flows into `debug_window_ticks_remaining()`**
  (`match_state.gd:861`, the `3-0b` AC 2 debug instrument) with NO edit needed — `stun` was already
  named in that list since E1; a stunned hero's remaining time is already visible in the debug
  overlay for free.

### Project Structure Notes

- Touched files (dev pass to confirm exhaustively): `src/state/resources/balance_config.gd` (rename +
  three new fields, AC 1-2), `src/state/timing/balance_ticks.gd` (rename + one new conversion, AC 1;
  the stale `stun_ticks` DATA-ONLY comment at lines 74-75, corrected per AC 6 — no functional edit
  beyond the rename itself), `data/balance/balance_config.tres` (the renamed field's new value + three
  new authored values, AC 1-2), `src/state/hero_state.gd` (the stale `STUNNED`-unreachable comment at
  lines 40-42 AND the stale "never `start()`ed by any E1 path" comment at line 101, both corrected per
  AC 6 — no functional edit to `TRANSITION_TABLE` itself; `is_hitbox_active()` at lines 210-211 WIDENED
  per AC 11), `src/state/match_state.gd` (the `STUNNED` color-counter transition inside
  `_resolve_charge_landing` AC 5, including its stale "NO STUN of any kind" comment at lines 2710-2714
  corrected per AC 6; the `STUNNED` melee-deflect transition + stamina drain inside `_resolve_contacts`
  AC 9-10; the new `STUNNED` arm in `_resolve_actions`'s step-3 match AC 12; the FIFTH named reset
  exception inside `_reset_player` AC 13, including the stale "FOURTH" ordinal comments in
  `_reset_player`/`_apply_debug_reset`; the `STUNNED` sibling in the movement hard-root `elif` chain
  AC 14; the `STUNNED`/`CHARGING` refusal in `_resolve_defense_cast` AC 15; the new `REASON_STUNNED`
  constant AC 15; the new CHARGING/STUNNED gate in `_resolve_basic_cast` AC 16). No `main.tscn` edit —
  the committed default `slot_controller_kinds` (`match_runner.gd:31-34`) needs no flip for any Live
  Smoke item; that script default is the seat for any FUTURE flip, not `main.tscn` (see Live Smoke's
  cut-item note).
- Test files: `test/state/test_action_state.gd` (the positive two-edge enumeration AC 6 adds beside
  the functionally-unedited negative table scan — its own stale comment at lines 76-77 corrected,
  comment-only; likely also the new `STUNNED` timer-exit test AC 12, the `STUNNED`-forbids-all-actions
  coverage AC 15/AC 16, and the movement-root test AC 14 — dev's call whether these live here or
  beside their nearest sibling), `test/state/test_unblockable_defense.gd` (AC 5, 7, 8 — see Open
  Questions on file placement; ALSO `test_a_negation_stuns_nobody()`'s P1 assertion at line 409
  INVERTS per AC 5, and a new `STUNNED`-hitbox-drop test per AC 11 beside its sibling
  `test_unblockable_defense.gd:568-587`), `test/state/test_block_deflect.gd` (AC 9-10, new positive
  stun/penalty tests beside the existing `4-3b/R7` negative guard, re-run unedited), `test/state/test_balance_authoring.gd`
  (rename + the new bespoke ordered-stun function + the sixth stamina-economy line + the narrowed
  `dodged_unblockable_damage_multiplier` bound, AC 4), `test/state/test_data_resources.gd`
  (`E1_BALANCE_FIELDS` gains/renames four entries, AC 3), `test/state/test_balance_config.gd` (rename,
  AC 1), `test/state/test_determinism.gd` (golden re-baseline + fixture-authored coverage values +
  accounting block, AC 17 — and possibly `P1_PRESS`/`CONTACTS` table changes depending on the Open
  Questions resolution).
- No new top-level folder. No new `FeatureFlags` field, no new `InputIntent` field, no new observation
  seam, no new Input Map action.

### Project Context Rules

- **F1** — not implicated: no new `_physics_process`.
- **D3(a)** — not implicated: no `Input.*` reads change; the existing keyboard/gamepad bindings are
  reused verbatim (no new Input Map action, per the Live Smoke section's cut-item note).
- **D3(b)/A2** — not implicated: every new branch (AC 5, 7, 9, 11-16) is a pure state read/write over
  existing `action_state`/window/balance data, no RNG/Time/OS/Engine.
- Docs and code never share a commit; commits are pure ASCII via `git commit -F <tempfile outside the
  repo>`; shell is PowerShell 5.1 (no `&&`); trailer `Co-Authored-By: Claude Opus 4.8
  <noreply@anthropic.com>`.
- Story tier: Tier A — full gate + review + live smoke ritual (touches `src/state/`, the golden, and
  determinism; the golden clause applies regardless of how small the change feels, per
  `docs/project-context.md`'s Story tiers section — and AC 17 measures that this story's golden move is
  in fact large, not small).

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/gdd.md:235-247] — the three-tier
  ladder table (Ruling 1's authority) and the escalation-gradient rationale (Ruling 2's authority).
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:163-170] — the E5 Committed
  obligations entry naming this story as `E5-P/R1`'s implementation seat and the
  `test_balance_authoring.gd` exemption removal.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8140-8150] —
  `E5-P/R1` in full: the resolved attacker-consequence-on-deflect decision, the escalation-gradient
  directional constraint, and the explicit "STUNNED gets its first inbound edge at 5-6" statement.
- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md:8199-8201] — the E5
  story order entry naming this story's exact scope (dodge/leave-range rung, both stuns, the stamina
  penalty, the exemption removal).
- [Source: docs/implementation-artifacts/5-5-unblockable-defense.md:380-397] — the Open Questions
  section measuring what a CHARGING hero can and cannot do today, and explicitly assigning the
  basic-cast hole (Ruling 4 / this story's AC 16) here.
- [Source: src/state/match_state.gd:2687-2751] — `_resolve_charge_landing` in full, the seat AC 5/AC 7/AC 8
  intercept.
- [Source: src/state/hero_state.gd:27,40-42,65,101,104-111,210-211,218-229,321-322,398-425,436-462] —
  `ActionState`, the stale `STUNNED`-unreachable comment and the stale "never `start()`ed" comment
  (both AC 6), the empty `stunned` table row, the eight `TimingWindow` fields including `stun`
  (superseded item 1), `is_hitbox_active()` (AC 11), `is_iframe_open()` (AC 7-8), `transition_row()`,
  `tick_timers()` (superseded item 6), `to_snapshot()` (AC 17).
- [Source: src/state/match_state.gd:876-926] — `_resolve_actions`'s step-3 timer-driven match in full,
  the `ROLLING`/`CHARGING` precedent AC 12 mirrors and the confirmed absence of a default arm.
- [Source: src/state/match_state.gd:1332-1469] — `_resolve_contacts` in full: `attacker`/
  `attacker_index` resolution, the `HERO_INDEX` mana-gate precedent (AC 9), the existing melee
  deflect branch (AC 9-10's exact seat), the iframe-drop rung (superseded item 4's contrast).
- [Source: src/state/match_state.gd:2299-2382] — `_resolve_basic_cast` in full, confirmed to never
  read `action_state` (superseded item 5, AC 16's edit site).
  [Source: src/state/match_state.gd:2412] — `REASON_UNBLOCKABLE_COMMITTED`, reused a third time
  (AC 15-16).
- [Source: src/state/match_state.gd:2592-2599] — `_resolve_defense_cast`'s CHARGING refusal, the exact
  idiom AC 15/AC 16 mirror.
- [Source: src/state/match_state.gd:3411-3470] — `_reset_player`/`_apply_debug_reset`, the four
  pre-existing named reset exceptions AC 13 joins as the fifth.
- [Source: src/main/match_runner.gd:1585-1596] — `_gather_contact_facts`, the sole consumer of
  `is_hitbox_active()` AC 11 widens.
- [Source: src/state/resources/balance_config.gd:23,270-287,296-329] — `deflect_stamina_cost` (the
  DEFENDER'S cost, distinct from AC 2's new field), the `Defense`/`Stun`/`Unblockable` export groups
  AC 1-2 join.
- [Source: src/state/pools/stamina_pool.gd:28-47] — `add()` vs `spend()`, the exact contract AC 10
  measures and relies on.
- [Source: src/state/timing/balance_ticks.gd:74-76,122] — `stun_ticks` and its stale DATA-ONLY comment,
  renamed/joined/corrected per AC 1/AC 6.
- [Source: src/actors/hero/animation_controller.gd:139-168] — `on_action_state_changed`, confirming
  `STUNNED` already degrades to "holds the pose" with no new clip needed (Non-Goals).
- [Source: src/main/match_runner.gd:817] — `connect_hero_action_state_changed`, the existing seam
  `STUNNED`'s legibility rides with no new wrapper needed.
- [Source: test/state/test_action_state.gd:74-97] — the existing negative `TRANSITION_TABLE` guard,
  functionally unedited (AC 6), and the positive enumeration it is joined by, not replaced by.
- [Source: test/state/test_balance_authoring.gd:1-50] — the exemption header (AC 4's removal target),
  `ACTION_SECONDS_FIELDS`, and the `5-5` "both directions asserted" precedent AC 4 follows.
- [Source: test/state/test_block_deflect.gd:459-472] — the `4-3b/R7` negative stun guard on a deflected
  minion, re-run unedited as this story's own regression proof (AC 9).
- [Source: test/state/test_unblockable_defense.gd:405-412,568-587] — `test_a_negation_stuns_nobody()`'s
  P1 assertion, INVERTED per AC 5, and the `5-5` AC 12 sibling test AC 13's own new test sits beside.
- [Source: test/state/test_replay_identity.gd:216-221,787-800] — `hero_state.stun` already `HASHED`,
  confirming AC 17's "no new classification" finding; the `_code_lines` comment-stripping idiom AC 6's
  positive guard reuses.
- [Source: test/state/test_determinism.gd:838,848-851,893-967,997-1100,1005-1013,1684-1686] —
  `CAST_TICK`/`MOVES`/`P1_PRESS`/`CONTACTS`/the recorded `BASIC` cast, the fixture's own enumerated
  distinctness set, `_golden_config()`, and the stamina arithmetic comment AC 17 re-derives.
- [Source: test/state/test_action_state.gd:180-240] — the chain-window timing coverage (last-tick
  accept, post-close drop, cap, roll-cancel reset) AC 17 cites as equivalent coverage for the t9 loss.
- [Source: test/state/test_roll_iframes.gd:88-150] — the iframe grace-boundary coverage (grace-then-full
  within one swing, window-alone grace, a running-iframe drop) AC 17 cites as equivalent coverage.
- [Source: project.godot:47-182] — the existing `p1_attack`, `p1_roll`, `p2_roll`,
  `p1_cast_unblockable`, `p2_cast_defense` actions, confirming Live Smoke needs no new binding.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-09-06 | Story authored via gds-create-story, against baseline `47c4d7c` | Claude Sonnet 5 |
| 2026-09-06 | Gate fixes + promote to ready-for-dev: American-spelling sweep, AC 6 exit restructure locked to shape (a), AC 8 emit-on-positive-damage, AC 17 reverse-measurement scope, AC 16 two-arm refusal, Live Smoke item 7 cut; golden fixture rewrite (AC 17), new hitbox-under-STUNNED AC, AC 8 dodge-rung observation-point correction + two-slot test, AC 6 test inversion, fifth reset exception AC, AC 5 reshape (bespoke function, not `ACTION_SECONDS_FIELDS`); AC merges (fields, AC 12 folded into AC 9); dangling-reference and stale-comment corrections throughout | Claude Sonnet 5 |
