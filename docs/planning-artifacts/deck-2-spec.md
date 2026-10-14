# CardSouls -- Deck 2 card spec (2026-10-11, operator scope talk for 7-5)

**Identity:** unblockables and orbs matter, mana cheating, voltron duelist. Deck 1 goes wide (army, corpses).
Deck 2 goes tall: one hero loaded with buffs.

**Structure:** 8 unique cards, 4 at x3 + 4 at x2 = 20 (Deck 1 uses the same structure; see the 2026-10-11
amendment in `deck-1-spec.md`).

**Pitch rules are Deck 1's** (`deck-1-spec.md` and its 7-4 amendment): mana is paid on staging, orbs on activation.
An instant pays orbs from the bank. A sorcery needs a fresh orb earned while the card hangs in the pitch zone, and
spends that orb. 20 s fizzle.

**Hooks:** a landed unblockable is the trigger; held orbs are the scaling.

**Presentation:** every buff must be readable on the hero, and everything should be visually interesting (operator).

**Authoring requirements:** as `deck-1-spec.md`. Every number below is TEMP (a placeholder for the 7-7 tuning pass)
and lives in `.tres`: card pairings, colours, pitch speeds and copy counts included.

## Shared with Deck 1 (whole cards, pairings unchanged)

- Honed Bolt / Counterspell, blue, x3
- Bloodhound Step / Fireball, red, x2
- Rocksling / Boom, red, x3

## New cards (normal / pitch)

Delivery: cards marked [7-5b] are not built in `7-5a-deck-2-core`; their halves are refused as "not available yet"
until `7-5b-deck-2-bodies` ships.

1. **Setup / Execute** -- red, x3, pitch speed instant
   - **Setup** (normal, 2 mana): adds a charge. Your next unblockable press spends one charge, costs no mana and, if
     that attack lands, grants double orbs (1 becomes 2). Lasts until used. Several Setups stack as charges; a press
     refused for mana, stamina or state spends nothing.
   - **Execute** (pitch, 4 mana + 1 red orb): adds a charge. Your next weapon hit (melee or unblockable) that would
     damage the opposing hero spends one charge and deals triple damage. Lasts until used; hits on units do not consume
     it; a blocked hit does not consume it and is not tripled; a hit absorbed by Stoneskin does consume it. Execute
     grants NO orbs. Several stack as charges: one x3 per hit, never multiplied together.

2. **Healer / Stoneskin** -- green, x3, instant
   - **Healer** (normal, 3 mana) [7-5b]: summons a unit that heals you. Whenever your unblockable chargeup begins, each of your
     Healers fires a projectile at the opposing hero. Body and numbers are decided in the 7-5b scope talk.
   - **Stoneskin** (pitch, 2 mana + 1 green orb): absorbs the next damage instance you take, from any source. No timer.
     An unblockable still knocks you down and still grants the attacker its orbs; only the damage is absorbed. Stackable
     as charges, one instance each.

3. **Bloodmagic / Enrage** -- green, x2, instant
   - **Bloodmagic** (normal, 0 mana): pay 10 HP, gain 4 mana. Refused if your HP is at or below the price. The HP paid is
     not damage.
   - **Enrage** (pitch, 2 mana + 1 green orb): for 10 s, your weapon hits (melee and unblockable, not spells) deal +2
     damage. Duration +2 s per orb you hold at activation (before the activation orb is paid). The +2 is added before
     multipliers (block, Execute, Bloodlust). Enrages stack: +2 each, independent windows.

4. **Manablossom / Elemental Fury** -- blue, x2, sorcery
   - **Manablossom** (normal, 1 mana): the cards currently in your hand cost 1 less mana, or 2 less if you hold 3+ orbs
     when you cast it. Applies to both normal and pitch mana, minimum 0, until each card leaves your hand. Orb costs
     unchanged. Several Manablossoms stack additively. Fireball's staging minimum drops by the discount (3 becomes 2) and
     its damage stays per mana actually spent. A card under a Boulder takes the discount and shows it when uncovered.
     Boulder clearing and the unblockable's mana are never discounted.
   - **Elemental Fury** (pitch, 5 mana + 1 blue orb) [7-5b]: fires one projectile per orb still held after paying, each with its orb's
     colour effect: red = damage, blue = slow, green = heals you. The held orbs are not spent.

5. **Manapulation / Wrath of God** -- blue, x2, sorcery
   - **Manapulation** (normal, 1 mana): gain X mana, where X = how many times you have pitched (successfully staged a card
     into your own pitch zone) this round. Refused stagings and Boulder clears do not count.
   - **Wrath of God** (pitch, 6 mana + 1 blue orb) [7-5b]: Dark Souls style wave around you. Damage and knockback to the
     opposing hero and opposing units within a radius; the radius grows with orbs still held after paying. Your own units are
     unaffected.

## Deck list (TEMP copies)

x3: Honed Bolt / Counterspell, Rocksling / Boom, Setup / Execute, Healer / Stoneskin.
x2: Bloodhound Step / Fireball, Bloodmagic / Enrage, Manablossom / Elemental Fury, Manapulation / Wrath of God.

(Recorded in `docs/implementation-artifacts/7-5a-deck-2-core.md`.)
