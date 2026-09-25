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
