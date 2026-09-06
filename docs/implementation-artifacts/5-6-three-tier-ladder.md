---
baseline_commit: 47c4d7c523509075578256277863003a90c23760
---

# Story 5.6: Three-Tier Ladder

Status: done

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
     (`balance_config.gd:270`). **CORRECTED by the fix pass (review finding L2):** the field is NOT
     "beside `deflect_stamina_cost`" — that field lives in the `Stamina` group (`balance_config.gd:23`),
     a different group entirely, and this text's own two instructions ("joins Defense" / "beside
     deflect_stamina_cost") conflicted. The dev pass's placement (Defense, grouped by which mechanic
     OWNS the field, per the field's own comment at `balance_config.gd:286-289`) is correct and is kept
     unchanged — this is a docs-only correction, not a field move, since moving the field would be the
     larger true change for zero behavioural gain (`@export_group` is editor-display metadata only).
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

    **ADDENDUM (fix pass, review finding M1, ACCEPTED + PINNED):** the two `STUNNED` entry points
    root the hero on DIFFERENT ticks, and this is INTENTIONAL rather than a gap in the text above.
    The color-counter stun is written inside `_resolve_actions` (step 3), strictly BEFORE that
    player's own step-3 `_resolve_movement` call, so the hard root above takes effect the SAME tick
    the stun is entered. The melee-deflect stun (AC 9) is written inside `_resolve_contacts` (step
    4), which runs strictly AFTER both players' step-3 `_resolve_movement` calls for that tick — so a
    hero mid-swing keeps that tick's attack-lunge velocity for one full extra tick, and the hard root
    only takes effect on the FOLLOWING tick's `_resolve_movement`. Zeroing velocity at the step-4
    entry point would smear this decision into a third function and is invisible at 60 Hz; it is the
    SAME shape this codebase already accepts for `DEAD`'s one-tick carry (the `2-3/R13` precedent,
    `test_round_over_freezes_resolution_until_reset`). Pinned by
    `test_a_melee_deflect_stun_carries_one_ticks_residual_lunge_velocity_then_zeroes`
    (`test_block_deflect.gd`): nonzero velocity on the entry tick, a literal zero the tick after. The
    color-counter entry's same-tick rooting is the ASYMMETRIC sibling, and the asymmetry is in the
    ORDERING (which step writes the stun relative to that tick's own movement resolution), not in the
    rooting mechanism, which is identical for both.
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
    untouched (Non-Goals). **AMENDED by the fix pass (review finding H1):** `_unblockable_refusal_
    reason` is NOT untouched — it gains exactly one `STUNNED` arm returning `REASON_STUNNED`, carved
    out of this closing sentence and the matching Non-Goals line below. The review found that this
    function, unlike `_resolve_basic_cast` and `_resolve_defense_cast`, was never gated on `STUNNED`
    at all: a stunned hero could cast a fresh unblockable, and the successful-cast path's
    unconditional `set_action_state(CHARGING)` overwrote `STUNNED` outright, un-rooting the hero and
    escaping the punish this story exists to create. "Committed to an unblockable" does not describe
    a stunned caster, so the new arm returns `REASON_STUNNED`, not `REASON_UNBLOCKABLE_COMMITTED`.
    `_resolve_unblockable_cast` and `TRANSITION_TABLE` remain untouched — only the sibling reachability
    gate gained the one arm.

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
- **No `5-2` chargeup behaviour changes beyond AC 16.** `_resolve_unblockable_cast` and
  `TRANSITION_TABLE`'s absent `charging` row are untouched. **AMENDED by the fix pass (review
  finding H1):** `_unblockable_refusal_reason` is carved OUT of this line — it gains one `STUNNED`
  arm (`REASON_STUNNED`), the third card-cast seat AC 15's own "STUNNED forbids every action"
  opening sentence implied but the dev pass never gated. See AC 16's amended closing sentence for
  the full account.
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

Opus 5 (operator-stated).

### Debug Log References

**Suite cadence (PROC/R1) -- THREE full `test/run_all.sh` runs, not two, and the third is reported
rather than hidden.**

| Run | File | Timestamp | Result |
|-----|------|-----------|--------|
| Before-baseline | `C:\dev\_56-suite-before.txt` | 2026-09-06 23:35:27 | 685 tests / 5133 assertions / 0 failed; 55 integration PASS |
| Final (aborted) | `C:\dev\_56-suite-after.txt` (overwritten) | 2026-09-07 00:15:55 | 709 tests / 5273 assertions / **0 failed**, but `SOME TESTS FAILED` |
| Final | `C:\dev\_56-suite-after.txt` | 2026-09-07 00:20:06 | 709 tests / 5273 assertions / 0 failed; 55 integration PASS; `ALL TESTS PASSED` |

Machine time, from the two surviving instrument timestamps: **44 min 39 s** (23:35:27 -> 00:20:06).

WHY THERE WAS A THIRD RUN. The first final run reported ZERO failed assertions but still exited
nonzero: `run_all.sh` also fails the suite on any `^ERROR:` line, and two
`String formatting error: not all arguments converted` lines were emitted from a message string in
this story's OWN new two-slot boundary test -- `"... %d ..." + "..." % [slot]` binds the `%` to the
LAST fragment only, which has no format spec. The defect was test-message-only (no assertion
outcome changed), was found BY the final run, and was fixed by wrapping the concatenation in
parentheses. Re-running is what the final run is for; the alternative was shipping a suite that
exits nonzero. A repo-wide scan for the same binding pattern found two other sites
(`test_action_state.gd:143`, the pre-existing `test_record_file.gd:535`) and both bind correctly.

**Per-file iteration runs.** Development iterated on the STATE HARNESS ALONE
(`godot --headless --script res://test/run_state_tests.gd`), never `run_all.sh` -- the same
narrower-than-the-suite instrument `PROC/R1` sanctions for mutation proofs. Every mutation proof
below used it too.

**Golden attribution runs (AC 17), all state-harness-only.** Five isolation measurements; see the
re-baseline record in `test_determinism.gd` for the full write-up.

### Completion Notes List

**All 17 ACs delivered.** Golden re-baselined ONCE: `d9725092` -> `d5bcb7e6`. Suite 685/5133 ->
709/5273. `project.godot` byte-identical (`git diff -- project.godot` empty); the editor was never
opened, so there is NO editor session to record and no `.uid` scan was owed (no new `.gd` file was
created -- every test landed in an existing file).

1. **THE LADDER (AC 5 / AC 7 / AC 8), three tiers in one function.** `_resolve_charge_landing` now
   reads: colour match -> attacker STUNNED for `color_counter_stun_ticks`, window consumed, EARLY
   RETURN; else defender's iframe open at the step-3 observation point -> damage scaled by
   `dodged_unblockable_damage_multiplier`, `hit_landed` emitted ONLY at positive magnitude, no orb;
   else the unchanged full-damage + orb path. **The exit restructure took shape (a):** one early
   `return` for the negation, the trailing `IDLE` still covering the other three outcomes
   unduplicated -- so EVERY outcome takes exactly one `set_action_state`, and no shape relies on a
   second last-write-wins call. Pinned by the QUEUED TRANSITION LOG, not by final state:
   `test_each_landing_outcome_takes_exactly_one_action_state_write` asserts the emitted
   `[previous, current]` pairs, which is the only assertion that can see a phantom `IDLE`.

2. **AC 7's OBSERVATION POINT is a new two-element per-tick latch, `_iframe_open_at_step3`, NOT a
   resolution reorder** -- the dev-pass choice AC 7 leaves open, argued here. MEASURED: `advance()`
   runs `_resolve_actions(p1)` COMPLETELY (timer exits including the charge landing, then p1's
   presses) before `_resolve_actions(p2)`. A live `target.hero.is_iframe_open()` read is therefore
   SEAT-DEPENDENT: slot 0's landing resolves before the defender's same-tick roll press (no dodge),
   slot 1's resolves after it (dodge). The latch is written at the top of step 3 -- after step 2's
   ticks, so the `1-9/R2` grace transient is current, and before any press -- giving the contract
   AC 7 states: a same-tick roll dodges on NEITHER slot, a previous-tick roll on BOTH. The
   alternative shape (hoisting both landings ahead of every press) would reorder a step four
   stories' worth of timing claims rest on, to buy the same contract. **Mutation M4 proves the
   choice matters**: swapping the latch for the live read fails
   `test_the_dodge_boundary_is_identical_on_both_slots` on exactly the slot-1 case.
   `_iframe_open_at_step3` classifies **PER_TICK** in `test_replay_identity.gd` on
   `_deflect_closed_this_tick`'s exact write-before-read argument -- so no snapshot key, and
   `UNHASHED_CROSS_TICK_MEMBERS` STAYS AT THREE.

3. **THE MELEE TIER (AC 9 / AC 10 / AC 11).** Hero-only (`attacker_index == HERO_INDEX`), immediate
   interrupt (the story's recommended reading, shipped as written), punitive `add(-x)` drain. The
   `add()`-vs-`spend()` contract is pinned on BOTH observable points -- an unaffordable penalty still
   applies floored at zero, and the regen delay is NOT restarted -- because either alone passes
   against the wrong mechanism in some fixture. AC 11's widening of `is_hitbox_active()` is what
   makes the immediate interrupt safe rather than merely convenient, and it is stated as a property
   of `action_state` (not of `STUNNED`), so any future non-`ATTACKING` interrupt inherits the
   closure.

4. **A GAP FOUND AND CLOSED IN AC 9's OWN GUARD.** AC 9 names `test_block_deflect.gd:459-472`'s
   `4-3b/R7` negative guard as this story's regression proof that the hero-only gate holds. MEASURED,
   IT DOES NOT PROVE THAT: that guard asserts on the deflected MINION's rhythm, and a unit has no
   `ActionState` or `stun` field -- so it stays GREEN against an implementation that dropped the
   `HERO_INDEX` gate entirely, because such an implementation stuns the OWNING HERO instead
   (`attacker` is the `PlayerState` for a unit-sourced fact too). Two assertions were ADDED to that
   test (owner not stunned, owner's stamina unmoved). The guard is otherwise re-run unedited, and
   mutation M6 now falls on it.

5. **`STUNNED`'s LIFECYCLE (AC 12-16), all shipped.** Timer arm (natural expiry only, proven by
   comparison against an untouched control rather than by an absolute assertion); fifth reset
   exception; hard root as a literal zero with facing deliberately falling through; table-driven
   actions forbidden by the empty `stunned` row with the DROP-not-BUFFER half asserted; both cast
   seats refusing, sharing one `REASON_STUNNED` constant, with the basic-cast gate proven to sit
   AHEAD of the empty-slot gate (an empty-slot cast while CHARGING reports the commitment, not
   `REASON_EMPTY_SLOT`).

6. **AC 13's ACTION-STATE CLAUSE IS DEFENSIVE-IN-DEPTH, NOT LOAD-BEARING -- measured, reported.**
   Mutation M10 removed `STUNNED` from `_reset_player`'s action-state clear and the WHOLE SUITE
   STAYED GREEN. Traced: the reset runs at step 1, `_apply_debug_reset` clears `_round_over` so step
   1b does not return, and step 3's AC 12 timer arm then sees a stopped window and writes `IDLE` in
   the SAME tick -- the two implementations are indistinguishable through `advance()`, including in
   queued-signal order. The load-bearing half is `hero.stun.start(0)`, and mutation M10b DOES fall on
   it. BOTH halves are kept: AC 13 asks for both, they clear one fact in two parts exactly as the
   chargeup's three and the defense window's two do, and this codebase has a standing
   "written anyway, in the defense-in-depth family" precedent (`_resolve_charge_landing`'s own
   dead-enemy branch). Flagged rather than silently trimmed, and rather than claimed as proven.

7. **THE GOLDEN MOVED FOR TWO CAUSES, BOTH INSIDE AC 9, BOTH MEASURED SEPARATELY.** No new snapshot
   key -- `hero_state.stun` and `hero_state`'s stamina have been hashed since E1, so this is the
   `5-4` orbs shape and no key-set literal anywhere in the suite moves. Full write-up in
   `test_determinism.gd`'s re-baseline record. The five measurements:
   - **0b (degenerate-value proof, taken first):** both write sets SHIPPED, the two fixture coverage
     values UNAUTHORED -> hash reproduced the inherited `d9725092` BIT FOR BIT. Without authoring,
     both new paths would have measured a FALSE NON-MOVER.
   - **Cause 1, the stun + state pair:** staged out with the drain left in -> `57d3b5a9`.
   - **Cause 2, the stamina drain:** staged out with the pair left in -> `e3a26c4a`.
   - **AC 5 predicted and measured a NON-CONTRIBUTOR:** its complete write set staged out with AC 9's
     complete write set in -> `d5bcb7e6`, UNCHANGED from the shipped tree.
   - **The full reverse:** BOTH write sets staged out, everything else this story ships left in place
     -> the inherited `d9725092` EXACTLY. Every other member of the story is a measured non-mover.

8. **AC 17's ACCOUNTING BLOCK IS INCOMPLETE -- A SECOND LOST ITEM, MEASURED AND REPORTED.** AC 17
   names ONE unconditionally lost item (the t9 chain coverage). Measurement found a second, and it is
   a CONSEQUENCE of the first rather than independent: **the t13 ORDINARY-BLOCK coverage is also
   lost.** `CONTACTS[13]` carries `attack_index` 1, an index that only ever existed as P1's CHAINED
   swing; with the t9 press dropped by the `stunned` row, P1's `attack_index` never leaves 0, no
   dedupe record for swing 1 is opened, and the fact drops at `register_swing_hit` -- before damage,
   before `hit_landed`, before the mana confirmation. Consequences on the record: P2 finishes at
   120.0 HP (was 117.0) and P1's mana is the passive faucet alone (was passive + one 12.0 melee
   confirmation). AC 17's option (a) (accept the shift) is FOLLOWED AS WRITTEN -- the fixture tables
   were NOT reworked -- and the loss is now ASSERTED AS A LOSS in
   `test_golden_sequence_exercises_block_and_deflect` rather than deleted. Equivalent coverage for it
   already exists and is untouched by this story: the whole ordinary-block ladder in
   `test_block_deflect.gd`. **This is a correction to AC 17's text that measurement proves, flagged
   not forced.** A shorter fixture stun (<= 3 ticks) would have preserved it, but AC 17 locks the
   ~7-tick target and names the t9 drop itself as a GAIN, so the spec was followed.

9. **TWO PRE-EXISTING TESTS CHANGED THAT AC 17 / AC 11 IMPLY BUT DO NOT ENUMERATE**, both reported
   rather than quietly patched:
   - `test_contact_resolution.gd::test_dead_attacker_in_flight_window_delivers_nothing` asserted
     `is_hitbox_active()` TRUE after a forced death, to prove the in-flight window is not
     early-stopped (`1-9/R3`). AC 11 makes that predicate false for a non-`ATTACKING` hero. The
     SUBJECT was moved to `active.is_running` -- which states the `1-9/R3` claim directly, about the
     window rather than about a predicate that has since gained a conjunct -- and the new AC 11
     behaviour was asserted POSITIVELY beside it instead of inverting the old line silently.
   - `test_block_deflect.gd::test_second_swing_in_same_window_degrades_to_block_when_pool_short`
     needs its attacker to swing again at t9 after a t4 deflect. At the file's default 11-tick stun
     the press is dropped and the test measures nothing about `R-N7`. It now authors a local 2-tick
     stun, with the reason stated: `R-N7` is a claim about the DEFENDER's pool, and how fast the
     attacker recovers between swings is fixture scaffolding. Every asserted number is unchanged.
   - `test_unblockable_defense.gd::test_the_attacker_exits_charging_whether_negated_or_not` (5-5's,
     asserting the exit is UNCONDITIONAL) is SUPERSEDED by AC 5 and was rewritten, not deleted --
     see note 1.

10. **AC 2's FIELD PLACEMENT CORRECTED AGAINST THE CODE.** AC 2 says `deflect_stamina_penalty` joins
    the `Defense` `@export_group` (`balance_config.gd:270`) "beside `deflect_stamina_cost`". Those two
    instructions conflict: `deflect_stamina_cost` is measured at `balance_config.gd:23`, in the
    **Stamina** group, not Defense. The field was placed in the **Defense** group (the line AC 2
    actually cites), grouped by which mechanic owns it, and the discrepancy is noted at the field.

11. **THE STORY'S DEFERRED ITEM IS RESOLVED BY MEASUREMENT, AND PINNED.** An already-running
    `defense_window` cast before a stun landed is untouched: nothing in this story reads or writes
    `defense_window`/`defense_color` outside the negation branch, and AC 15 only prevents ARMING a
    new one. The story leaves it to the dev pass whether this warrants a test; it got one
    (`test_a_stun_does_not_disturb_an_already_running_defense_window`) -- the claim is cheap to pin
    and expensive to rediscover.

12. **NON-GOALS HELD.** `_resolve_unblockable_cast`, `_unblockable_refusal_reason` and
    `TRANSITION_TABLE` are untouched; `FORMAT_VERSION` stays 7; no new snapshot key, no new
    `InputIntent` or `FeatureFlags` field, no new observation seam (the family stays at nine), no new
    Input Map action, no `main.tscn` edit, no `game-architecture.md` edit.

13. **LIVE SMOKE NOT RUN** -- this is a dev pass; the smoke is the operator's, after review. Items
    1-6 of the Live Smoke list are all pinned headless as the story's blind-spot note requires:
    item 1 = `test_a_negation_stuns_the_attacker_and_only_the_attacker`; item 2 =
    `test_only_a_matching_colour_negates` (re-run unedited); item 3 =
    `test_an_open_iframe_dodges_the_landing_silently_at_the_shipped_multiplier`; item 4 =
    `test_a_deflected_hero_attacker_is_stunned_and_drained`; item 5 =
    `test_a_stunned_hero_refuses_every_table_action_and_buffers_none` +
    `test_a_stunned_hero_cannot_cast_basic` / `_defense`; item 6 =
    `test_a_charging_hero_cannot_cast_basic`. The CUT flip item's premise is discharged by
    `test_the_dodge_boundary_is_identical_on_both_slots`. Items 7-8 (regression by eye, FPS) and the
    qualitative "holds pose" read remain smoke-only.

### Fix Pass (post-review), Dev Agent Record — APPENDED, not replacing the notes above

Applied against the code review at `docs/implementation-artifacts/5-6-code-review.md`. No commits;
`Status` and the board are untouched; everything lands on top of the dev pass's uncommitted working
tree over `4e5f145`. The review report file stays untracked, unstaged.

14. **H1 FIXED — the third cast seat.** `_unblockable_refusal_reason` (`match_state.gd`) gains a
    `STUNNED` arm returning `REASON_STUNNED` (the SHARED constant AC 15 already defines, not a fourth
    reason) — the exact shape AC 15/AC 16's own two seats already take. Caught at review against BOTH
    the story's own Non-Goals lock ("`_unblockable_refusal_reason` ... untouched") and the dev pass's
    own instruction (AC 16's closing sentence, which the fix pass now amends alongside Non-Goals to
    carve out this one-arm addition). New headless test
    (`test_a_stunned_hero_cannot_cast_unblockable`, `test_unblockable_defense.gd`) asserts the refusal
    reason, that `action_state` stays `STUNNED` (a successful cast would have overwritten it with
    `CHARGING`), that the stun window keeps counting down untouched rather than left orphaned, and that
    no card/chargeup/stamina is spent. Mutation: the new arm removed → the new test FALLS (reproduced
    live, backed up outside the repo, SHA-256-verified byte-identical after restore — see the mutation
    table's M21).

15. **M1 ACCEPTED AND PINNED — the melee-deflect stun's one-tick residual lunge, on the `2-3/R13`
    DEAD-velocity precedent.** No code change: the asymmetry between the two `STUNNED` entry points
    (color-counter roots same-tick because it is written in step 3 ahead of that tick's own
    `_resolve_movement`; melee-deflect carries one tick because it is written in step 4, strictly
    after) is documented in AC 14 (an ADDENDUM naming the precedent) and pinned by a new test,
    `test_a_melee_deflect_stun_carries_one_ticks_residual_lunge_velocity_then_zeroes`
    (`test_block_deflect.gd`), which authors a LOCAL nonzero `attack_lunge_distance` (the shared
    `_config()` leaves it at 0.0, which is why no other test in the file could see this at all) and
    asserts nonzero velocity on the entry tick, a literal zero the tick after.

16. **M2 MEASURED — confirmed structurally unreachable, no guard added.** Investigated whether one
    hero attacker's swing can produce two deflected contact facts against the enemy hero in the same
    tick (which would double the AC 10 stamina drain). MEASURED unreachable: a hero owns exactly one
    `active` `TimingWindow` (`hero_state.gd:112`), so at most one hitbox is live for it at any instant
    and the match_runner can gather at most one contact fact from it per tick against a given target —
    there is no second swing available while the first is still `active` to produce a second fact. A
    duplicate fact naming the SAME `attack_index` against the same target would separately drop at
    `_register_attacker_hit`'s dedupe rung, which sits strictly BEFORE the deflect branch in the step-4
    ladder. A comment recording both halves of this argument is added at the penalty site
    (`match_state.gd`, immediately above the `attacker_index == HERO_INDEX` block) rather than a
    speculative per-tick guard, per the ruling: a guard would defend against a fact the ladder's own
    earlier rungs already make unreachable.

17. **L1 STRENGTHENED — the `_reset_player` `STUNNED` clause is live, not dead; the ORIGINAL test just
    could not see it.** The pre-existing `test_the_debug_reset_clears_a_stunned_hero_and_its_window`
    drives the reset through the public `advance()` path, whose step-3 AC-12 timer arm independently
    re-derives `IDLE` from the stopped window in the SAME tick — exactly what let mutation M10 (the
    action-state clause removed) leave the whole suite green. A new test,
    `test_the_reset_seat_itself_clears_a_stunned_hero_immediately`, applies the `2-3/R13` DEAD-branch
    DIRECT-CALL idiom (`test_match_state.gd`'s `ms._resolve_movement(...)` pattern) to `_reset_player`
    itself: it calls the reset seat directly and asserts `IDLE` immediately, before any `advance()` —
    including step 3 — has a chance to run. Re-running M10 against this new test: FALLS (see the
    mutation table's M10c). Both tests are kept: the original documents the full public-path behaviour
    (still correctly green), the new one documents the reset seat's OWN contract — post-reset state
    must not depend on a later step happening to run, unlike `DEAD`'s clear in the same `if`, which has
    no timer arm to fall back on at all.

18. **L2 RESOLVED — the smaller true change was the docs, not the field.** AC 2's text asked for
    `deflect_stamina_penalty` to join "the `Defense` group ... beside `deflect_stamina_cost`", but
    those two instructions conflict (`deflect_stamina_cost` lives in the `Stamina` group). The dev
    pass's actual placement (`Defense`, grouped by which mechanic owns the field, reasoned at the field
    itself) is correct and unchanged; AC 2's text is corrected instead, since moving the field would be
    the larger true change for zero behavioural difference (`@export_group` is editor-display metadata
    only — no `.tres` edit, no test, no consumer reads it).

19. **L3 ACKNOWLEDGED, NO ACTION.** `dodged_unblockable_damage_multiplier`'s runtime `if dodged > 0.0`
    guard failing safe against a negative authored value is incidental to the guard's actual purpose
    (suppressing a zero-magnitude emit), not a deliberate defense against a negative one — worth noting
    for a future refactor of that line, not a defect today. The authoring-time bound
    (`test_authored_dodge_multiplier_is_bounded_above`, `<= 1.0`) plus the generic non-negative
    reflection loop (`test_data_resources.gd`) already jointly close the authored-value gap; the repo's
    standing pattern is authoring-time bounds for tunables, not redundant runtime clamps, so no runtime
    guard is added.

20. **L4 ACKNOWLEDGED, NO ACTION.** The `_code_lines` comment-stripping helper's first-`#` truncation
    (reused from `test_replay_identity.gd`'s pre-existing idiom) would mis-strip a line whose code
    portion legitimately contains a `#` inside a string literal. No such line exists in any file this
    helper scans today, and it is a pre-existing idiom rather than new logic from this story — noted for
    completeness, no action needed.

**Suite (fix pass, state harness only — PROC/R1's narrower-than-the-suite instrument, exactly as the
dev pass used for its own iteration and mutation proofs):** 712 tests / 5291 assertions / 0 failed
(three new tests over the dev pass's 709/5273: `test_a_stunned_hero_cannot_cast_unblockable`,
`test_the_reset_seat_itself_clears_a_stunned_hero_immediately`,
`test_a_melee_deflect_stun_carries_one_ticks_residual_lunge_velocity_then_zeroes`). The golden constant
is UNCHANGED at `d5bcb7e6...` (addendum B's pin held — none of the three fixes touch a path the golden
fixture exercises): H1's new refusal branch is unexercised by the fixture (its one recorded cast is
`BASIC` at t22, with P1 `IDLE`); M1/M2 are comment/test-only; L1's new test calls `_reset_player`
directly and never runs through the golden's own `advance()` sequence at all.

**MUTATION TABLE -- every new guard proven to FAIL without the thing it protects.** All targets were
backed up OUTSIDE the repo and SHA-256-verified byte-identical after restoration; `git checkout --`
was never used (decision-log:799). Each row is one staged mutation plus one state-harness run.

| # | AC | Mutation | Guard that FALLS | Result |
|---|----|----------|------------------|--------|
| M1 | 5 | Colour-counter `stun.start` + `set_action_state(STUNNED)` + `return` removed | `test_a_negation_stuns_the_attacker_and_only_the_attacker` (+7 more incl. the AC 6 enumeration) | FALLS |
| M2 | 5 | Same writes kept but the `return` dropped, so the trailing `IDLE` also runs (last-write-wins) | `test_each_landing_outcome_takes_exactly_one_action_state_write` (+7) | FALLS |
| M3 | 7 | Dodge rung disabled (`if false`) | all three dodge tests | FALLS |
| M4 | 7 | Latch swapped for a LIVE `target.hero.is_iframe_open()` read | `test_the_dodge_boundary_is_identical_on_both_slots`, on the slot-1 case only | FALLS |
| M5 | 8 | Dodge CONSUMES the iframe window (`roll_iframe.start(0)`) | `test_a_dodge_neither_consumes_nor_shortens_the_iframe_window` | FALLS |
| M6 | 9 | Hero-only gate removed (`if true`) | `test_deflecting_a_minion_leaves_its_rhythm_...` (via note 4's added assertions) | FALLS |
| M7 | 10 | `add(-penalty)` replaced by `spend(penalty, delay)` | `test_the_deflect_penalty_is_a_punitive_drain_not_a_refusable_spend`, + the golden and its stamina pin | FALLS |
| M8 | 11 | `is_hitbox_active()` reverted to bare `active.is_running` | `test_a_stunned_attackers_orphaned_active_window_reports_no_hitbox` + `test_dead_attacker_in_flight_window_delivers_nothing` | FALLS |
| M9 | 12 | Step-3 `STUNNED` timer arm emptied | 2 lifecycle tests + 6 golden pins | FALLS |
| M10 | 13 | `STUNNED` removed from `_reset_player`'s action-state clear | *(none)* | **DOES NOT FALL -- see note 6** |
| M10b | 13 | `hero.stun.start(0)` removed from the reset | `test_the_debug_reset_clears_a_stunned_hero_and_its_window` | FALLS |
| M11 | 14 | `STUNNED` movement-root branch disabled | `test_a_stunned_hero_is_hard_rooted` | FALLS |
| M12 | 15 | Defense-cast `STUNNED` refusal removed | `test_a_stunned_hero_cannot_cast_defense` | FALLS |
| M13 | 16 | Basic-cast two-arm gate removed | all three AC 16 tests | FALLS |
| M14 | 6 | A THIRD `set_action_state(...STUNNED)` site added under `src/` | `test_stunned_has_exactly_two_authored_non_table_entry_points` | FALLS |
| M15 | 4 | Authored escalation gradient INVERTED in the `.tres` (0.4 / 1.0) | `test_authored_stun_values_are_positive_and_correctly_ordered` | FALLS |
| M16 | 1 | `.tres` left on the OLD `stun_seconds` key after the script field was renamed | same test (the field silently authors 0.0 -- the exact silent-drop hazard AC 1 names) | FALLS |
| M17 | 4 | `deflect_stamina_penalty` authored `0.0` | `test_authored_stamina_economy_values_are_positive` | FALLS |
| M18 | 4 | `dodged_unblockable_damage_multiplier` authored `1.5` | `test_authored_dodge_multiplier_is_bounded_above` | FALLS |
| M19 | 3 | `dodged_unblockable_damage_multiplier` dropped from `E1_BALANCE_FIELDS` | `test_balance_config_field_lists_are_complete_by_reflection` | FALLS |
| M20 | 1 | `deflect_stun_ticks` conversion replaced by a literal 0 | `test_conversion_covers_every_seconds_field` + 4 more | FALLS |
| M21 | 16 (fix pass, H1) | `STUNNED` arm removed from `_unblockable_refusal_reason` | `test_a_stunned_hero_cannot_cast_unblockable` | FALLS (reproduced live: backed up OUTSIDE the repo, SHA-256-verified byte-identical after restore) |
| M10c | 13 (fix pass, L1) | `STUNNED` removed from `_reset_player`'s action-state clear, re-run against the NEW direct-call test | `test_the_reset_seat_itself_clears_a_stunned_hero_immediately` | FALLS — unlike M10 (row above), which is UNCHANGED and still does NOT fall against the pre-existing public-path test; the direct call bypasses the step-3 timer arm that masks the missing clause (backed up OUTSIDE the repo, SHA-256-verified byte-identical after restore) |

**Board status (CFG/R2 / CFG/R5).** `development_status` was deliberately NOT written to
`in-progress` at Step 4 of the skill: the board lifecycle is locked to
`backlog -> ready-for-dev -> done`, and `in-progress` is not in that set -- the same reason the
team's `gds-dev-story` override corrects the Step-9 `review` write. The board stays `ready-for-dev`;
the story file's own `Status` is `review`, a story-file-only value.

### File List

Source (`src/`):
- `src/state/resources/balance_config.gd` -- `stun_seconds` renamed to `color_counter_stun_seconds`
  (AC 1); new `deflect_stun_seconds` (AC 1), `deflect_stamina_penalty` (AC 2),
  `dodged_unblockable_damage_multiplier` (AC 2); the DATA-ONLY comment corrected (AC 6).
- `src/state/timing/balance_ticks.gd` -- `stun_ticks` renamed to `color_counter_stun_ticks`, new
  `deflect_stun_ticks`, both conversions (AC 1); the stale DATA-ONLY comment corrected (AC 6).
- `src/state/hero_state.gd` -- `is_hitbox_active()` widened (AC 11); the two stale `STUNNED` comments
  corrected (AC 6). `TRANSITION_TABLE` UNTOUCHED.
- `src/state/match_state.gd` -- `_iframe_open_at_step3` field + its step-3 capture (AC 7);
  `_resolve_actions` `STUNNED` timer arm (AC 12); `_resolve_charge_landing` restructured with the
  colour-counter stun (AC 5) and the dodge rung (AC 7/AC 8), its stale NO-STUN comment corrected
  (AC 6); `_resolve_contacts` deflect stun + penalty (AC 9/AC 10); `_resolve_movement` `STUNNED`
  hard root (AC 14); `_reset_player` fifth exception + the stale ordinal header (AC 13);
  `REASON_STUNNED` (AC 15); `_resolve_defense_cast` `STUNNED` refusal (AC 15); `_resolve_basic_cast`
  two-arm gate (AC 16).

Data:
- `data/balance/balance_config.tres` -- `stun_seconds = 0.6` replaced by
  `color_counter_stun_seconds = 1.0` + `deflect_stun_seconds = 0.4`; new
  `deflect_stamina_penalty = 12.0` and `dodged_unblockable_damage_multiplier = 0.0`.

Tests (`test/state/`):
- `test_action_state.gd` -- stale doc-comment corrected (AC 6); NEW positive two-edge enumeration
  guard + its `_gd_files`/`_code_lines` helpers (AC 6); NEW `STUNNED` lifecycle tests (AC 12/14/15).
- `test_balance_authoring.gd` -- exemption removed from header and `ACTION_SECONDS_FIELDS`' note
  (AC 4); NEW `test_authored_stun_values_are_positive_and_correctly_ordered`; NEW
  `test_authored_dodge_multiplier_is_bounded_above`; sixth stamina-economy line (AC 4).
- `test_balance_config.gd` -- renamed literal + assertion, new `deflect_stun_ticks` assertion (AC 1).
- `test_block_deflect.gd` -- fixture authors the two new values; NEW AC 9/AC 10/AC 11 tests and an
  AC 11 control; two assertions ADDED to the `4-3b/R7` negative guard (note 4); one existing test
  given a local 2-tick stun (note 9).
- `test_contact_resolution.gd` -- the AC 11 assertion move (note 9).
- `test_data_resources.gd` -- `E1_BALANCE_FIELDS` gains/renames four entries (AC 3).
- `test_determinism.gd` -- `_golden_config()` authors the two coverage values; the re-baseline record;
  `GOLDEN` -> `d5bcb7e6`; five re-derived pins (AC 17).
- `test_replay_identity.gd` -- `_iframe_open_at_step3` classified PER_TICK (note 2).
- `test_unblockable_defense.gd` -- three new constants + three new config lines; NEW dodge/boundary,
  reset, cast-refusal and Deferred-item tests; `_make_match_with`, `_run_chargeup_dodging`,
  `_basic_intent`, `_collect_action_states` helpers; `test_a_negation_stuns_nobody` INVERTED and
  `test_the_attacker_exits_charging_whether_negated_or_not` superseded (AC 5).

NOT touched: `project.godot` (byte-identical), `main.tscn`, `hero.tscn`, `src/main/match_runner.gd`,
`src/systems/record_file.gd`, any `docs/` file other than this one.

### File List — Fix Pass Addendum (post-review)

- `src/state/match_state.gd` -- `_unblockable_refusal_reason` gains the `STUNNED` arm / `REASON_STUNNED`
  return (H1); a comment recording the M2 reachability argument added above the deflect-attacker
  penalty block in `_resolve_contacts`. No other function touched.
- `test/state/test_unblockable_defense.gd` -- NEW `test_a_stunned_hero_cannot_cast_unblockable` (H1);
  NEW `test_the_reset_seat_itself_clears_a_stunned_hero_immediately` (L1).
- `test/state/test_block_deflect.gd` -- NEW
  `test_a_melee_deflect_stun_carries_one_ticks_residual_lunge_velocity_then_zeroes` (M1).
- This story file -- AC 16's closing sentence and the matching Non-Goals line amended (H1 carve-out);
  AC 14 gains an addendum (M1); AC 2's text corrected (L2); Dev Agent Record notes 14-20 appended;
  mutation table rows M21/M10c appended; this addendum and the Change Log row below.

NOT touched by the fix pass: `data/balance/balance_config.tres`, `src/state/resources/balance_config.gd`,
`src/state/hero_state.gd`, `src/state/timing/balance_ticks.gd`, every other file in the dev pass's File
List above, `project.godot`. `docs/implementation-artifacts/5-6-code-review.md` stays untracked and is
not staged by this pass.

### Live Smoke Results

8/8 PASS, no defects, no flip needed (committed default `[0,1]`):

1. Colour counter stuns the attacker for ~1 s.
2. Wrong colour, or no answer, resolves as a full hit plus orb -- unchanged from the pre-story
   unblockable path.
3. A well-timed roll fully dodges an unblockable, even in range: no damage, no orb. A roll landing
   on the landing tick does not dodge (intended -- the AC 7/AC 8 observation point).
4. Deflect punishes with the stamina penalty plus a short stun.
5. A stunned hero can do nothing, including a fresh unblockable cast (H1 fix confirmed live).
6. Chargeup refuses mode (1) cards while charging.
7. Deflected minions do not freeze.
8. FPS stable.

Operator notes: the deflect stun's 0.4 s "possibly a touch short, not sure" is a tuning
observation for the retune block -- value unchanged. Stun legibility (pose-hold, no dedicated
clip) was not assessed.

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-09-06 | Story authored via gds-create-story, against baseline `47c4d7c` | Claude Sonnet 5 |
| 2026-09-07 | Dev pass (Opus 5): all 17 ACs. Golden re-baselined once `d9725092` -> `d5bcb7e6`, two causes both inside AC 9, each isolated and reproduced in both directions; AC 5 measured a non-contributor. Suite 685/5133 -> 709/5273, 55 integration PASS. 21-row mutation table, 20 falling; M10 reported NOT falling (AC 13's action-state clause is defensive-in-depth). Two AC-text corrections reported: AC 17's accounting block misses a second lost item (t13 block coverage), and AC 2 misplaces `deflect_stamina_cost`. `project.godot` byte-identical. | Claude Opus 5 |
| 2026-09-06 | Gate fixes + promote to ready-for-dev: American-spelling sweep, AC 6 exit restructure locked to shape (a), AC 8 emit-on-positive-damage, AC 17 reverse-measurement scope, AC 16 two-arm refusal, Live Smoke item 7 cut; golden fixture rewrite (AC 17), new hitbox-under-STUNNED AC, AC 8 dodge-rung observation-point correction + two-slot test, AC 6 test inversion, fifth reset exception AC, AC 5 reshape (bespoke function, not `ACTION_SECONDS_FIELDS`); AC merges (fields, AC 12 folded into AC 9); dangling-reference and stale-comment corrections throughout | Claude Sonnet 5 |
| 2026-09-07 | Fix pass against `docs/implementation-artifacts/5-6-code-review.md`: H1 fixed (`_unblockable_refusal_reason` gains a `STUNNED` arm, AC 16/Non-Goals amended to carve it out); M1 accepted + pinned (AC 14 addendum, the `2-3/R13` precedent, new residual-velocity test); M2 measured unreachable (comment at the penalty site, no guard); L1 strengthened (new direct-call test proves the `_reset_player` clause live, mutation M10c falls where M10 does not); L2 resolved by correcting AC 2's text (field placement kept, docs-only fix); L3/L4 acknowledged with no action. State harness 709/5273 -> 712/5291, 0 failed. Golden UNCHANGED at `d5bcb7e6...`. No commits; `Status`/board untouched. | Claude Sonnet 5 |
| 2026-09-07 | Close-out: live smoke 8/8 PASS, no defects, no flip needed; Live Smoke Results section added; `Status` review -> done. | Claude Sonnet 5 |
