# CardSouls -- Deck 1 card spec (2026-09-22, amendments merged)

Seven unique cards. Each card has a NORMAL effect (mode 1) and a PITCH effect (mode 4). Modes 2 and 3 (unblockable attack / colour defence) stay on every card as shipped.
Pitch flow is the shipped one (6-2/6-3a/6-4): orbs are earned by landing unblockables, never by pitching. A pitched card waits in the pitch zone until its cost is affordable; the pitch effect fires on activation.

## Authoring requirements
- every number (mana cost, orb cost, damage, heal, duration, multiplier, cap) is authored data (.tres), never a literal in src/;
- the pairing of a normal effect with a pitch effect is data; any effect can be moved to another card or swapped between roles by editing the card resource only;
- card colour is data;
- an effect is a named reusable definition; a card references effects by id;
- every effect may carry an optional visual id; state never reads it.
Deck: 20 cards = 6 uniques x 3 copies + 1 unique x 2 copies. T = tunable, default in brackets.

## 1. Vanguard / Culling -- GREEN
NORMAL Ruin Vanguard -- T[3] mana. Summon one basic melee minion (existing 4-1 system).
PITCH Culling -- T[3] mana + T[1] green orb. Kill all your own minions instantly; gain T[2] mana per minion killed; cap field T[99] (effectively no cap). Corpses drop normally. The orb cost is the brake on the Culling -> Raise Dead loop.

## 2. Grave Ward / Raise Dead -- GREEN
NORMAL Grave Ward -- T[2] mana. For the next T[20] s your corpses do not despawn. New: per-player timed rule suspending corpse despawn.
PITCH Raise Dead -- T[6] mana + T[2] red orbs. Every corpse of your own minions returns as a live minion at the corpse position at T[100]% max HP. Corpses are consumed.

## 3. Drain / Vampiric Aura -- GREEN
NORMAL Drain -- T[2] mana. Sacrifice your own minion nearest to you; heal T[10] HP; corpse drops normally. Fails if you have no minion.
PITCH Vampiric Aura -- T[5] mana + T[1] green orb + T[1] red orb. For T[15] s, T[50]% of all damage you deal (melee, unblockable, projectiles) heals you.

## 4. Rocksling / Boom -- RED
NORMAL Rocksling -- T[4] mana. Visible cast, then throw boulders_per_cast T[3] homing rocks, T[0.5] s apart, T[3] damage each, blockable/deflectable like any 4-4 projectile. EVERY rock that hits the enemy hero places a Boulder card into a free slot of their hand. Boulder does nothing; it costs T[2] mana to discard; while in hand it occupies the slot. No slow.
PITCH Boom -- T[3] mana + T[1] red orb. Every Boulder in the opponent's hand explodes: T[6] damage each to the enemy hero, Boulder removed. No Boulders -> no effect.

## 5. Bloodhound Step / Bloodlust -- RED
NORMAL Bloodhound Step -- T[2] mana. Your next roll within T[5] s has T[2]x i-frames and T[1.5]x distance.
PITCH Bloodlust -- T[4] mana + T[1] red orb. For T[10] s you AND your minions deal T[2]x damage and take T[2]x damage.

## 6. Honed Bolt / Counterspell -- BLUE
NORMAL Honed Bolt -- T[4] mana. Visible cast, then a near-instant lightning bolt on the locked target (Elden Ring honed bolt); only a precisely timed sideways roll avoids it. T[4] damage, then STUN stun_seconds T[0.4] (no actions), then ROOT root_seconds T[2.5] starting when stun ends: root_blocks_run T[true], root_blocks_roll T[true]; walk, block, deflect and colour counter still work. Purpose: root lets an unblockable chargeup (1.0 s) reach the target; the colour counter stays the answer.
PITCH Counterspell -- T[4] mana + T[1] blue orb. RETROACTIVE: undo the opponent's most recent card (normal or pitch). Exact undo semantics are decided in its own story.

## 7. Frostbite / Corpse Bomb -- BLUE
NORMAL Frostbite -- T[4] mana. Enemy hero hit by your next melee swing within T[6] s is slowed to T[50]% movement speed (walk and run) for T[4] s.
PITCH Corpse Bomb -- T[5] mana + T[1] blue orb. Every corpse of your minions becomes a homing skull projectile at the enemy hero, T[4] damage each, blockable/deflectable. Corpses consumed.

## Presentation
Attack spells (Rocksling, Honed Bolt, any hero-cast projectile) have a visible cast animation the opponent can react to. Buffs resolve instantly but get a visual. Animation clips (Mixamo) are supplied by the operator when the consuming story comes up.

## Balance risks to watch first
1. Culling + Raise Dead loop (orb cost is the brake).
2. Honed Bolt stun+root into unblockable.
3. Vampiric Aura %.
4. Three Boulders lock three of four hand slots (boulders_per_cast can drop to 1).

## Amendment (2026-09-22, recorded by 6-5b's authoring pass)

**Fireball** (operator's idea, accepted) REPLACES Bloodlust as the pitch of Bloodhound Step: an X-cost
pitch spell that spends ALL of the caster's current mana (minimum 3, cap 10) plus 1 red orb; a homing
projectile dealing damage per mana spent, T[1.5] per mana (tunable). Built in 6-5d, sharing the
hero-projectile machinery Rocksling needs. Until 6-5d lands, Bloodhound Step stays paired with
Bloodlust exactly as 6-5a shipped it, so the card is never left with an empty pitch. Bloodlust stays
in code and simply leaves the Deck 1 card list once Fireball takes its slot. (Recorded in
`docs/implementation-artifacts/6-5b-corpses-and-own-minions.md`'s Deferred section; owned by 6-5d.)

## Amendment (2026-09-23, recorded by 6-5b's readiness gate fix pass)

**Grave Ward** (line 19) is amended: "For the next T[20] s your corpses do not despawn... New:
per-player timed rule suspending corpse despawn" is SUPERSEDED by operator ruling `6-5b/R7`, on the
same `6-5a/R2` precedent as the Drain facing-rule supersession (`6-5b/R6`) above. Grave Ward does not
start a per-player timed rule; at resolution it ADDS T[20] s to the remaining lifetime of each corpse
the caster owns that exists at that instant, and repeated casts stack additively rather than
refreshing. A corpse created after resolution is unaffected. (Recorded in
`docs/implementation-artifacts/6-5b-corpses-and-own-minions.md`'s Discrepancies section.)

## Amendment (2026-09-25, 6-5c/R1)

**Honed Bolt** (section 6): "a near-instant lightning bolt on the locked target" is SUPERSEDED by
operator ruling `6-5c/R1`. The bolt's target is always the enemy hero, never a minion, regardless of
lock-on. (Recorded in `docs/implementation-artifacts/6-5c-hero-cast-honed-bolt.md`.)

## Amendment (2026-09-26, operator scope talk for 6-5d)

**Spell targeting** SUPERSEDES the 2026-09-25 amendment above ("target is always the enemy hero"),
returning the bolt to the spec's original "locked target" wording with these details. Honed Bolt AND
Fireball target the caster's current lock-on target (opposing hero, minion or totem); a caster who is
unlocked targets the opposing hero. The target is captured at cast start and the warning cone / alarm sits
on it. If the target dies before impact, Honed Bolt hits nothing (card and mana lost) and Fireball flies
straight and expires at its 60 m limit. Honed Bolt on a minion or totem is damage only (4, through the damage
funnel; no stun, no root); on a hero it is unchanged.

**Fireball** (section 5 amendment of 2026-09-22, refined): it is staged with ALL of the caster's current mana
X (minimum 3, cap 10 as authored data; max mana is 10 today, so the cap is currently inert; below 3 the
staging is refused and nothing is spent); X is spent and the damage is locked at staging; damage = 1.5 x X
(tunable, no rounding). It activates only by 1 red orb, then has a visible cast (the hero cast frame) and
launches a homing projectile at cast end. Block does not help; deflect negates and consumes it; roll and rise
i-frames drop the contact and end homing (it then flies straight to 60 m); non-target minions do not absorb
it; a minion or totem target has no defence. A hit is damage only. Bloodlust and Vampiric Aura apply to it as
to every spell. Built in `6-5d-fireball-and-spell-targeting`; Rocksling, Boom and Corpse Bomb move to
`6-5e-rocksling-boom-and-corpse-bomb`. (Recorded in
`docs/implementation-artifacts/6-5d-fireball-and-spell-targeting.md`.)

## Amendment (2026-09-28, operator ruling set for 6-5e)

**Rocksling** (section 4, NORMAL): the burst is `boulders_per_cast` (T[3]) homing stones, T[0.3] s apart,
T[3] damage each, fired from the caster's feet on the hero-projectile machinery `6-5d` built, targeting the
caster's lock-on target at cast start exactly as Fireball and Honed Bolt do (unlocked -> opposing hero;
non-target minions do not absorb a stone). **Defence is NOT "blockable/deflectable like any 4-4
projectile" as this file previously said** -- SUPERSEDED: a stone ignores block entirely (a blocking target
takes full damage, whether or not it faces the shot); only a deflect (blocking, facing, window open, stamina
paid) cancels a stone outright; roll and get-up i-frames strip its homing without consuming it, exactly as
Fireball's i-frame rule. Every stone that hits the opposing hero (a full-damage hit) places a Boulder card
in that player's hand: **the Boulder sits ON TOP of the slot's existing card, not in place of it** --
SUPERSEDED from this file's previous "Boulder does nothing; it costs T[2] mana to discard; while in hand it
occupies the slot" wording, which implied an ordinary card in an ordinary slot. The slot is chosen at random
by the match's seeded gameplay RNG, among slots of the STRUCK player's hand holding no Boulder and not the
originating hand slot of a card the STRUCK player has currently staged in their OWN pitch zone (`6-5e/R20`
-- corrected from an earlier "caster's own pitch zone" wording, the wrong party, and from "occupied by a
staged card", a predicate the repo cannot express since a staged card's hand slot is empty); the covered
card stays in the slot, unplayable, and reappears the instant its Boulder is
removed (played, detonated by Boom, or torn down at round end / a debug reset -- the same triggers the
Boulder paragraph below already covers, made consistent here). If the chosen slot is empty (a draw-delay hole), the Boulder
occupies it directly and the owed replacement lands underneath it when it arrives. A stone landing on a
minion or totem deals damage only, no Boulder. **Boom** (PITCH): on activation, every Boulder in the
opponent's hand AT THAT MOMENT deals T[6] damage each, instantly, to the opponent's hero -- not a
projectile, not avoidable by roll, block or deflect -- and is removed, uncovering its card. Zero Boulders at
activation -> the activation is refused (the card stays staged and counts to its own fizzle), per the
standing 6-5b no-target rule; staged mana is not refunded.

**Corpse Bomb** (section 7, PITCH): **"Every corpse of your minions becomes a homing skull" is SUPERSEDED**
-- Corpse Bomb does not consume existing corpses; on activation it KILLS every LIVING minion the caster
currently owns (totems excluded -- they are not minions for this or any other Deck 1 effect), each one
leaving a NORMAL corpse (standard duration, subject to Grave Ward, consumable by Raise Dead -- the
Culling/Raise Dead loop this enables is intended, braked only by Corpse Bomb's own cost), and from each
dying minion's position a homing skull launches at the caster's lock-on target captured at the activation
instant (unlocked -> opposing hero), dealing T[5] damage each (was T[4] in this file's prior wording --
SUPERSEDED) with the same defence as a Rocksling stone (block no help, deflect cancels, roll/get-up i-frames
strip homing, passes through non-target minions). No living own minions at activation -> refused, per the
6-5b no-target rule; staged mana is not refunded.

**Costs confirmed against the repo, no change:** Boom stages for T[3] mana + T[1] red orb; Corpse Bomb
stages for T[5] mana + T[1] blue orb activation -- both already authored in `rocksling.tres` /
`frostbite.tres` and matching this file's own numbers exactly.

**Boulder** (new card, referenced by sections 4 and this amendment): colourless (a new `CardColor` member,
`6-5e/R26`); its only action is playing it (Mode 1) for T[2] mana, which removes it and makes the card it
was covering immediately playable in the same slot, no draw delay; no pitch, no Mode 2/3; never enters any
deck, is never drawn or discarded; removed on round end and debug reset, restoring every covered card.
(Recorded in `docs/implementation-artifacts/6-5e-rocksling-boom-and-corpse-bomb.md`.)

## Amendment (2026-09-28, operator ruling S1, added after the readiness gate)

**Rocksling's section 4 "No slow" line is SUPERSEDED.** While a player holds one or more Boulders, that
player's walk and run speed (including walk-in-block) are slowed by `boulder_slow_per_boulder` (authored
`.tres`, default T[0.15]) per Boulder held, stacking additively; T[0.0] disables the slow entirely. Roll,
attack and stamina are untouched. It combines with Frostbite's slow MULTIPLICATIVELY. The slow tracks the
live Boulder count and updates on the same tick as every add/remove path (placing, clearing, Boom
detonation, round end, debug reset). The slow is observable to the opponent by design -- accepted, not a
`P3` breach (no hand content is revealed, only a speed effect). (Recorded in
`docs/implementation-artifacts/6-5e-rocksling-boom-and-corpse-bomb.md`, ruling `6-5e/R28`.)
