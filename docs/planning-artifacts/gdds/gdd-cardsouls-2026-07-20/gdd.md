---
title: CardSouls
game_type: Hybrid — Real-Time Action Combat + Real-Time Card Economy (1v1 PvP)
platforms: Windows desktop (Godot 4.6.3, Forward+ / D3D12)
scope: Local single-machine demo (single round, local PvP / vs-AI, no networking)
created: 2026-07-20
updated: 2026-07-21
status: draft-complete (v1.0)
---

# CardSouls - Game Design Document

**Author:** Matko
**Game Type:** Hybrid — Real-Time Action Combat + Real-Time Card Economy (1v1 PvP)
**Target Platform(s):** Windows desktop (Godot 4.6.3 stable, Forward+ / D3D12). Local demo, no networking.

---

## Executive Summary

### Core Concept

CardSouls is a 1v1, real-time game that fuses third-person soulsborne melee combat with a real-time card economy. Each player directly controls a hero — attacking, blocking, deflecting, rolling — while simultaneously managing a 4-card hand that summons units, casts spells, triggers a Red/Blue/Green unblockable rock-paper-scissors exchange, and stages powerful "Pitch" threats on a publicly visible countdown. Both layers are equally decisive.

**Vision — the feeling the game exists to deliver.** The satisfaction of **buildup, bluff, and payoff** — delivered through the *skill dynamics of soulsborne combat*, not through numbers or deck construction. If that trio is not present and felt in real-time play, CardSouls has failed regardless of how cleanly the economy balances. This is the bar every other decision answers to.

### Target Audience

The overlap of **souls / Sekiro players** (who want combat reads and execution) and **TCG / card players** (who want deckbuild and economy) — people who like *execution plus decision under pressure*. Deliberately **small and demanding**: CardSouls targets a high skill ceiling, not broad casual reach. This is an enthusiast audience by design; breadth is explicitly *not* a demo objective (see Goals). Note the distinction from *playtester* composition, which is deliberately broader as instrumentation — see Success Metrics.

### Unique Selling Points (USPs)

- **Two real-time layers, equally decisive.** Not a card game with combat flavor, nor an action game with a card gimmick — real-time soulsborne melee *and* a real-time card economy that must both be mastered (P1).
- **Aggression *is* your economy.** Landing melee hits funds your cards; the player winning the fight has the resources to escalate it (P2). A flywheel, not two separate meters.
- **Open-information bluffing (poker, not hidden-hand).** The Pitch Zone publishes *what* is coming, *how long*, and whether it is already READY to fire — but never the exact shortfall, nor intent to follow through (`6-3-split/R-INFO`). Threats are visible; delivery is uncertain (P3).
- **Your hand is your defense.** Color-as-defense makes your 4-card hand a live defensive toolkit and your deck's color ratio a defensive decision — deckbuild reaches directly into moment-to-moment combat.
- **The Sekiro-style read, weaponized by a resource.** The RGB unblockable RPS resolves through a sub-second telegraph read *and* pays out the orbs that fuel your biggest threats.

---

## Goals and Context

### Project Goals

CardSouls is an **enthusiast exploration and learning build — not a commercial vertical slice.** There is no revenue timeline.

- **Primary goal:** discover *which combination* of these mechanics yields the good game the designer believes is hiding in the souls + TCG fusion — i.e. prove the core loop (buildup → bluff → payoff, delivered through real-time soulsborne combat) is **interesting enough to keep exploring.**
- **The feature-flag architecture is the instrument.** Toggling layers (melee mana gen, unblockable, orbs, pitch, minions, totems, equipment) cheaply isolates which combination works and which introduces a *parallel-demand* overload (P4). Finding the overload threshold is a goal, not a side effect.
- **Secondary goal (explicit):** learning — Godot, the BMAD/GDS workflow, and game architecture.
- **Success is "the mechanical core is interesting enough to keep exploring"** — not retention, polish, or presentation.
- **Disposability is success, not failure.** Throwing away code after a playtest disproves a mechanic is a *win*; the feature-flag architecture exists precisely to make that cheap.
- **Explicit non-goals:** revenue; presentation/production quality; breadth of audience.

### Background and Rationale

The designer is a Sekiro and TCG player who believes a very good game hides in the *right* combination of real-time soulsborne combat and a real-time card economy — a space existing genres keep apart (card games are turn-based; action games rarely carry economy depth). CardSouls exists to test that fusion in practice rather than in theory.

The original intent was captured in a v0.3 TDD written for Unreal Engine 5 / C++ / online P2P (`docs/tdd-legacy-ue5.md`, now LEGACY REFERENCE — mechanics canon, engine/networking obsolete). The project has since migrated to **Godot 4.6.3 / GDScript / local single-machine** (`docs/project-context.md`). This GDD scopes the **local validation demo** of that migrated design.

---

## Core Gameplay

### Game Pillars

Four pillars, each game-defining and decision-steering. Any mechanic that serves none of them is scope creep.

**P1 — Dual mastery: combat and cards are equally decisive.**
Neither layer wins alone. A player cannot turtle-and-durdle to victory on cards, nor ignore the deck and win on melee. The deck and economy *set up stakes and supply tools*; the resolution and skill expression happen in real-time soulsborne combat — you win by out-*playing* with your toolkit, not by out-*listing* it in deckbuild. *Steering test:* any design that lets one layer be auto-piloted, or that makes deck construction rather than in-match execution the deciding factor, violates this pillar.

**P2 — Aggression is economy: the melee → mana → cards flywheel.**
Landing ordinary attacks generates mana; mana plays cards; cards escalate pressure. Forward play funds the game plan; turtling starves it. *Steering test:* economy and damage numbers must reward being in the opponent's face — any mechanic that makes passivity the optimal economy is a defect.

**P3 — Visible threat, uncertain delivery (open-information bluffing).**
The Pitch Zone publishes *what* is coming and *how long* the opponent has to react, and whether it is already READY to fire — but not the exact shortfall if it isn't, nor whether the attacker intends to follow through. Closer to poker than to hidden-hand card games: the read is on delivery and intent, not on hidden information. *Steering test:* telegraph the threat and the clock; keep the staged card's EXACT affordability (which colors, how many orbs short) and follow-through ambiguous — whether the zone is READY to fire right now is deliberately public (`6-3-split/R-INFO`). Fully revealing capability/intent designs bluff *out* of the game; hiding the threat entirely designs the reads *out* — both violate this pillar.

**P4 — One thing at a time: layers alternate, they do not stack.**
The enemy is *parallel* demands, not *difficult* ones. A high skill ceiling at Sekiro / TCG level is the **point** — P4 exists to protect *mastery*, not to cap difficulty, and must never be read as a mandate to simplify. The distinction: Sekiro is brutally demanding yet almost never asks the player to track two things in the same second — its load is **deep, not wide**. Two clocks running at once is not a higher ceiling, it is worse legibility; a player who loses because they missed a second timer feels that something *slipped past them*, not that they were outplayed. **Sequential demands can be mastered; parallel demands can only be endured.** During an unblockable chargeup, the color read is the only decision that exists. *Steering test:* every mechanic is measured on whether it adds a demand *in sequence* (good — masterable) or *in parallel* (bad — mere endurance) — **never on whether it is hard**. The single biggest risk to CardSouls is asking the player to track melee spacing, stamina, mana, a 4-card hand, a color telegraph, and a pitch timer *at the same instant*.

> **Reactor / Actor principle (binding constraint on P4).** Cognitive overload is dangerous *only under reaction pressure.* **P4 binds the reactor absolutely** — whoever is reacting (the defender in the half-second color read) must never carry more than one live decision; one extra track there is fatal. **The actor is offloaded only through information display, never through removing execution.** The attacker chooses at their own tempo — weighing orbs, timer, and bluff *is the buildup*, the first word of the vision, not load to be stripped.
> - **Allowed offload:** the HUD *surfaces* attacker state (orbs, pitch timer, stamina) so the player *reads* it rather than computing it.
> - **Forbidden offload:** removing positional/execution demand. Chargeup auto-aim is generous (no precise manual aiming) — but it must **not** absorb spacing. Closing the distance, keeping stamina to retreat afterward, and being punishable on a whiffed chargeup all remain in the player's hands.
> - **Vision guard:** if the payoff stops being delivered through soulsborne execution, the vision is violated even if every system still works. Symmetric single-tracking would strip the attacker's weighing of orbs/timer/bluff (the game itself); a deliberately harder attacker seat would punish aggression and starve the melee → mana economy (violating P2).

### Legibility Principle (companion to P4)

The game must be as **legible and intuitive as possible** — and legibility is *not* simplicity. Sekiro's perilous kanji is maximally legible and the game is brutal; **high ceiling and high legibility are complements, not a trade-off.** Legibility means the player always knows *what happened and why*; difficulty is whether they can *execute* it.

Concrete obligations this creates (binding on Art, Audio, and UI):
- The **color telegraph** must be recognizable in **under half a second, pre-verbally** — distinct *shape and sound*, not hue alone (this is also the colorblind path).
- The **outcome of every exchange** must be immediately obvious: did I gain an orb, is my opponent stunned, did my counter register.
- **Pitch affordability is read, not computed, for your OWN zone** (the Reactor/Actor offload, already locked); **the opponent's zone reads READY, never the shortfall** (`6-3-split/R-INFO`).

> **Interpretation rule (playtests):** a player may legitimately not know how to *win* — that is difficulty. A player must **never** not know why they *lost* — that is a legibility defect. (See Success Metrics for the full playtest-signal ruleset.)

### Design Touchstone

The canonical ten-second image of a match going right. Any mechanic that does not appear here, or that competes with this moment for the player's attention, needs justification.

> I stage a card in the Pitch Zone. My opponent sees its cost and the shared timer running down — and whether it's already READY to fire, but not how close I am if it isn't (`6-3-split/R-INFO`). He knows the only way I bank orbs at all is by landing an unblockable. So he has to choose: press me aggressively and deny me space, or back off and let the timer expire. I commit to a chargeup — red telegraph. He has half a second to decide whether that's the real cash-in or a feint. If he reads the color, I lose the card and the tempo. If he misses, the orb is mine and the pitch goes through — and all of this while my stamina is draining from the two rolls I had to spend just to get in range.

### Core Gameplay Loop

CardSouls runs a single continuous real-time loop — no turns. It is structured as the vision triad **buildup → bluff → payoff**, nested over an always-on soulsborne combat heartbeat.

**① BUILDUP — the aggression flywheel** *(continuous, at the player's own tempo).*
Close distance and win melee exchanges: ordinary hits deal chip damage **and** generate mana. Spend mana to play cards (minions / totems / spells) that build board pressure and economy. Bank **orbs** by landing unblockable attacks. The player is assembling both a threat and the resources to deliver it. *Serves P2 (aggression is economy) and P1 (both layers stay live).*

**② BLUFF — the public commitment** *(at the actor's tempo).*
Stage a card in the **Pitch Zone**; its cost and countdown timer become public. The player may be an orb short — and the only way to close the gap is landing an unblockable — so they commit a chargeup: **real cash-in or feint?** The opponent must read the color or eat the consequence. *Serves P3 (visible threat, uncertain delivery).*

**③ PAYOFF — delivered through soulsborne execution** *(the reactor's ≤~0.5s read).*
The color-read exchange resolves. Land it → orb + fixed damage, the pitch goes through, a big swing lands. Get read → stunned ~1s, card and tempo lost. The payoff is *always* felt through a combat execution moment, never a menu confirmation. *Serves the vision and P1.*

**↻ Reset & attrition.** Spacing resets, stamina recovers, HP damage persists. The loop repeats; a steady chip-damage clock runs underneath the spikes.

**Nesting.** ① is the continuous heartbeat (approach / basic attack / block-deflect-roll / manage stamina and spacing) that never stops. ② and ③ are the spikes that punctuate it. The heartbeat forces the decisions; the spikes resolve them.

**Pacing target.** A round should see roughly **2–4 full buildup→bluff→payoff cycles** — each pitch a real commitment worth building toward, not background noise (fast/frequent pitches cheapen the payoff and crowd toward parallel demands, fighting P4; a single climax risks dead air and swingy misreads, fighting P2). This is a *tuning target* realized through pitch cost, orb-acquisition rate, and the pitch timer length (20 s provisional, `E6-P`) — not a hardcoded value. Associated target: **~60–120s of active play per round**, against which timer and costs are tuned.

> **[NOTE FOR DESIGNER] Pitch overlap — RULED at E6 planning (`E6-P`), provisional.** The Pitch Zone is **per-player**: each player owns their own zone, **both zones are visible to both players**, and staging is **independent** — both players may hold a staged card at the same time. Candidates (a) global Pitch Zone (one staged card in the match) and (b) overlap-with-lockout (the prior working assumption) are **not taken**; free overlap is. The P4 cost is real and known — with both zones live a defender tracks two timers, a color telegraph, stamina and spacing at once — which is exactly why this is **provisional and judged at the post-E6 playtest**, not settled. Detailed in the Pitch Zone spec below.

### Win/Loss Conditions

A round ends when one hero's **HP reaches 0**; that player loses the round. **Demo scope: a single round.** (Full vision: Best of 3 — first to 2 round wins takes the match; deferred, see Out of Scope.)

**Kill-source balance rule (binding — protects P1).** Pitch payoffs and landed unblockables — the spikes — end *most* rounds; this is the vision (the payoff delivers the kill, chip and minions are the clock that forces the decision). **But chip must remain a credible finisher at low HP.** If only spikes can kill, ordinary melee degrades into a pure mana faucet and P1 (dual mastery) collapses — one of the two layers stops deciding matches. Concretely: an opponent below ~15–20% HP must still fear an ordinary attack chain, not only the pitch. Ordinary hits stay at ~5–8% HP each (per TDD §6) precisely so the threat of chip prevents a defender from ignoring the melee exchange to focus purely on color reads. Net: **spikes end most rounds, chip ends some, and the standing threat of chip keeps melee decisive.**

---

## Game Mechanics

### Primary Mechanics

The player-facing capabilities. Concrete tuning numbers live in **Hybrid Systems** and **Progression and Balance**; most are flagged TBD-in-balance and must be data-driven (`.tres`), never hardcoded.

**Hero resources.**
- **HP** — absolute value TBD (set relative to spell/minion damage in balance). No passive regeneration; healing only via cards. Ordinary melee hit deals ~5–8% HP (per kill-source rule, keeps chip a credible finisher).
- **Stamina** — regenerates automatically over time (souls-style). Consumed by: Run, Roll, Deflect, Unblockable Initiation, Unblockable Defense. At zero, the player cannot run, roll, deflect, or use Unblockable modes until it recovers. (Stamina is the resource that makes "I spent two rolls to get in range" cost something — see touchstone.)
- **Mana** — three stacking sources (passive auto-regen floor; melee-hit generation; Mana Accelerator totem). Spent on **Basic** and **Pitch Effect** card modes. Detailed in Hybrid Systems → Mana Economy.

**Hero combat actions.**
- **Move (Walk / Run)** — **two gaits.** Walking is the default: slower, free, always available. Running is a held button at the faster speed and **drains stamina** while held (Elden Ring reference), so closing distance competes with rolling and defending for the same bar. Walk speed and drain-per-second are authored balance values (TBD-in-playtest).
- **Basic Attack** — melee chain, no resource cost. Deals chip damage *and* generates mana on hit (the flywheel, P2).
- **Block / Deflect** — hold to block; a precise timing window triggers a **Deflect** (parry). Costs stamina.
- **Roll (Dodge)** — i-frame dodge in the movement direction. Costs stamina.
- **Unblockable Initiation** *(card Mode ②)* — hero begins a short chargeup with an audio+visual color telegraph, then the attack lands. Costs **stamina only** (no mana). Chargeup has generous auto-aim (no precise manual aiming) — but per the Reactor/Actor principle, auto-aim does **not** absorb spacing: closing distance, retaining stamina to retreat, and being punishable on a whiffed chargeup remain player skill.
- **Unblockable Defense** *(card Mode ③)* — instant on input, no chargeup; must fire during the attacker's chargeup window; color must match. Costs stamina.

**Card play — four modes per card.** Every card can be played four ways, chosen at play time: ① Basic (mana), ② Unblockable Initiation (stamina), ③ Unblockable Defense (stamina), ④ Pitch Effect (mana + orbs, staged publicly). Full spec in Hybrid Systems → Card System.

### Controls and Input

**Input architecture (binding invariant).** The hero is driven by a **controller abstraction** with three interchangeable implementations — **local keyboard, local gamepad, scripted AI**. Input source is *data, not code*: nothing in the hero or state layer may branch on "is this a human." This makes the opponent progression (training dummy → local PvP → scripted bot → deferred bluffing AI) a config swap rather than three rewrites, and is the same seam that keeps netcode addable later. Named actions are defined in the Godot Input Map — never raw keycodes.

**Local play.** The demo runs **local split-screen**: **per-player split viewports**, each with its own camera and HUD, so each player's hand stays private (only a shared single camera would leak it). Two input profiles (P1/P2) select their controller implementations independently. *(Technical means in Technical Specifications.)*

**Action set (to map in the Input Map):** move (walk by default), run (hold), basic attack, block/deflect (hold + release-timing for parry), roll/dodge (directional), play-card, stage-card-to-Pitch-Zone, activate/cancel Pitch, and card-mode selection.

> **[NOTE FOR DESIGNER] Card-mode selection UX — open, high P4 relevance.** Choosing one of a card's four modes *in real time under pressure* is a core input-feel problem (radial menu? hold-modifier + slot? per-mode bind?). It directly touches P4 (must not become a parallel demand mid-combat) and the touchstone (committing an unblockable / staging a pitch must feel immediate). Deferred to UX design (`gds-ux`); flagged here so it is not assumed trivial.

---

## Hybrid Systems: Card Economy + Real-Time Combat

This section merges the card-game and fighting genre conventions as **co-primary** — neither subordinate — scoped to the demo. It is the densest part of the GDD; numbers flagged *TBD* are tuned in playtest and must be data-driven (`.tres`), never hardcoded.

### A. Card System

**Card anatomy.** Every card carries: a **color** (Red / Blue / Green), a **Basic** effect + mana cost, and a **Pitch** effect + cost (mana + orb combination). Color is first-class — it determines which unblockable the card can initiate (Mode ②) and which it can defend (Mode ③).

**The four play modes** (chosen at play time; see TDD §5.5):

| Mode | Name | Effect | Cost | Consumes card? |
| --- | --- | --- | --- | --- |
| ① | Basic | Summon minion/totem/accelerator, or cast a lesser spell (per card) | Mana (per card) | Yes → discard, draw 1 |
| ② | Unblockable Initiation | Hero performs the unblockable attack of this card's color | Stamina only | Yes → discard, draw 1 |
| ③ | Unblockable Defense | Hero performs the counter of this card's color | Stamina only | Yes → discard, draw 1 |
| ④ | Pitch Effect | Powerful effect on the card, activated from the Pitch Zone | Mana (higher) + orbs (per card); only the priced orbs are spent, surplus remains (`6-3-split/R-SPEND`) | Yes (or fizzles) |

> **⚑ CORE DESIGN PILLAR — color-as-defense (confirmed, intended, core).** Because Mode ③ requires a card *of the incoming attack's color in hand*, a player's **4-card hand composition is their real-time defensive toolkit.** No Red card in hand ⇒ cannot *color-counter* a Red unblockable this instant (though it can still be dodged — see the three-tier ladder below). Consequences, all intended:
> - Hand management is a defensive skill, not just offensive economy; an attacker can **bait** — throw or feint a color the opponent likely can't answer, burning their colored cards before the real commit.
> - **It is occasional, not routine.** With a roughly color-balanced deck, the chance of holding ≥1 card of a given color in a 4-card hand is ~80%. Being caught off-color happens sometimes — enough to give the attacker a reason to *bluff* rather than a guaranteed win.
> - **Deck color ratio becomes a defensive decision.** A mono-color deck is strong on offense but helpless against two-thirds of unblockables. That is P1 (dual mastery) arriving for free — a deckbuild choice with direct real-time combat consequences.

**Card types** (TDD §5.3):
- **Spell** — active effect cast from the hero (damage, debuff, area denial, utility). Elden Ring-style ability feel; instant or short cast.
- **Minion** — summons an autonomous unit (Clash Royale / TFT-style AI). Targets per its **AI priority type**.
- **Totem / Ward** — small, unimposing static structure (wardstone, not tower), destructible. Three subtypes: **(a) Combat Totem** — fires at enemies in range; **(b) Mana Accelerator** — sustained passive mana regen layer; **(c) Stamina Accelerator** — raises stamina regen rate while alive.

**Minion AI priority types** — data-defined per card (new types addable without code, per project-context). Demo set: **Standard** (nearest enemy unit, hero if none), **Hero-Seeker** (always enemy hero), **Tank** (max threat; enemy minions redirect aggro to it), **Bomber/AoE** (prioritizes unit clumps).

**Deck & hand.**
- Deck **20 cards**; max copies per card **2–3**, configurable per card in data.
- Draw **4** at round start (full hand). On play, draw 1 replacement — *instant vs ~1s delay TBD* (affects strategic tension).
- Deck exhaustion → auto-reshuffle with a brief **vulnerable window** (~1.5–2s TBD, flagged visually to both).
- Hand size **4** at all times; cards private to the local player **except** the Pitch Zone card.
- **Sideboard: deferred** (demo is a single round; see Out of Scope).

**Worked example — Imp Summoner** (all four modes on one card; TDD §9):

| Mode | Name | Effect | Cost |
| --- | --- | --- | --- |
| ① Basic | Summon Imp | Summon 1 Imp minion, Standard priority (nearest enemy) | 3 Mana |
| ② Unblockable Init. | Red attack | Hero performs the Red unblockable (Swipe/Headstomp) | Stamina |
| ③ Unblockable Def. | Red counter | Hero performs the Red counter (Headstomp defense) | Stamina |
| ④ Pitch — *Hellburst* | Detonate Imps | All of this player's living Imps simultaneously explode, each dealing AoE damage at its position | 5 Mana + 2 Green orbs (only the 2 Green are spent; Red/Blue and any Green surplus above 2 remain — `6-3-split/R-SPEND`) |

Note how a *single Red card* is at once a summon, a Red attack, a Red defense, and — once enough Green orbs are banked — a board-wide detonation. This is the four-mode density every card carries, and why hand composition is simultaneously offense, defense (color-as-defense), and pitch potential.

### B. Mana Economy

Three stacking sources, each rewarding a different playstyle (TDD §6):

| Source | Behavior | Playstyle |
| --- | --- | --- |
| Passive auto-regen | Slow baseline tick, always on | Universal floor |
| Melee-hit generation | Landing ordinary attacks generates mana in bursts | Aggressive (the P2 flywheel) |
| Mana Accelerator totem | Sustained continuous regen layer; destructible | Economy / ramp |

Spent on **Basic** (Mode ①) and **Pitch Effect** (Mode ④). Baseline reference (TDD §16): Clash-Royale-like ~10 max, ~1/sec — adjust to card costs in balance.

### C. Unblockable RPS System (the combat "frame data")

Inspired by Sekiro's Perilous Attacks. A card's color determines which unblockable it initiates and defends. This is the fighting-genre "frame data / counter" layer.

| Color | Attack | Counter | Counter logic |
| --- | --- | --- | --- |
| **Red** | Swipe / Headstomp (wide sweep or downward stomp) | Headstomp (jump the sweep, stomp attacker) | Attacker is below mid-swing — exploit the dead angle above |
| **Blue** | Jump Attack (leaping overhead) | Pseudo-Suriken (midair intercept projectile) | Attacker committed and airborne — intercept before landing |
| **Green** | Thrust (lunging stab) | Pseudo-Mikiri (step inside effective range) | Thrust only works at distance — close the gap to nullify |

**Initiation (Mode ②):** short chargeup with audio+visual color telegraph → attack lands. Generous auto-aim (no precise aiming; does **not** absorb spacing). Stamina cost; greyed out if stamina insufficient.
**Defense (Mode ③):** instant on input, no chargeup; must fire during the attacker's chargeup window with the **matching color**. Wrong color or no input ⇒ attack lands normally.

**Outcomes — three-tier defensive ladder** (revises the TDD's binary §7.5). "Unblockable" means *not blockable*, **not** *undodgeable* — it behaves like a Sekiro perilous attack: usually it must be *answered*, but it can occasionally be *escaped*.

| Defender response | Damage | Orb to attacker | Attacker punished? |
| --- | --- | --- | --- |
| No answer / wrong color | **Full** (one damage value for all three colors, not per-card — shipped `5-2/R10`) | **Yes** (1 orb of color) | No |
| Dodge or leave range (~20% target) | None | No | No |
| **Correct color** (~30–40% target) | None | No | **Stun ~1s** |

Clean escalation: **survive → survive and deny → survive, deny, and punish.** Color counter is the *strongest* stopping answer — a full ~1s stun. A melee deflect also punishes the attacker now (a stamina penalty and a markedly shorter stun than the color counter's), so the ladder keeps its escalation gradient even though color is no longer the *only* response that stops the attacker rather than merely surviving them — color still never becomes optional, since it is the strongest answer. A well-timed roll/disengage is a real, if unreliable, out.

> **Do not engineer these percentages — let them emerge.** The ~20% dodge / ~30–40% counter figures are **playtest targets to check against, not values to hardcode.** Dodging emerges from spacing + timing against the generous auto-aim; a color counter requires reading the telegraph *and* holding the color (already ~20% failure from hand-math alone). Both responses stay live in the same window; skill moves the ratio.

> **Why unblockable spam is self-limiting (design rationale, not accident).** Mode ② **consumes the card from hand**, so every unblockable thrown *thins the thrower's own defensive color coverage*. Combined with the stamina cost and the ~1s stun on a correct read, aggression is priced **without an explicit cooldown** — the economy itself is the throttle.

> **Timing windows are the fairness core (TBD, playtest-critical).** Chargeup duration, the **defense input window**, stun duration (~1s), whether disengaging costs enough stamina to matter, and whether the **dodge window should be tighter than a normal roll** are the "frame data" of CardSouls. The defense-window length is the single most feel-and-fairness-sensitive number — too short punishes reaction unfairly, too long removes the read. Must be data-driven and **deterministic / framerate-independent** (the technical means live in Technical Specifications). Suggested unblockable damage ~15–20% HP (TDD §16).

### D. Orb Resource

- **Acquisition:** *exclusively* by landing an un-countered unblockable → 1 orb of the attack's color. (Orbs are the tangible reward for winning the RPS read — and the reason the touchstone attacker must land an unblockable to afford the pitch.)
- **Storage:** authored per-color cap, `max_orbs_per_color = 5` (provisional — shipped `5-4/R8`); per-color counts shown in HUD. **On Pitch activation, only the orbs that card's price required are spent** (not all three colors reset to 0 — TDD §8.2's all-reset framing is superseded, `6-3-split/R-SPEND`). Surplus orbs remain; the per-color cap is what bounds stockpiling, not a spend-time reset.
- **Usage:** *exclusively* to pay a Pitch Effect (Mode ④) cost. No other use.

### E. Pitch Zone (the signature bluff system — P3)

A single public card slot with a countdown timer (TDD §5.6).
- Drag a card from hand to stage it. Its **cost (mana + required orbs) and a countdown timer become visible to the opponent** on both screens.
- Timer **20 s, PROVISIONAL** (`E6-P`) — an authored balance field, not a constant. 20 = pressured/aggressive against 30 = strategic; the final verdict is the post-E6 playtest's.
- Staging does **not** reduce hand below 4 — the staged card still counts as in-hand until resolved.
- **Exit paths:** (a) player activates when cost is met; (b) player cancels → returns to hand; (c) **fizzle** — timer expires → card discarded + draw, and accumulated mana/orbs are **not** refunded; (d) opponent card removes it (*future content — out of demo scope*).
- **One card in a player's Pitch Zone at a time**, and the zone is **per-player** — both zones are visible to both players, and the two stage independently, so simultaneous pitches are legal (`E6-P`, provisional; judged at the post-E6 playtest). See Core Loop `[NOTE FOR DESIGNER]`.
- **Reactor/Actor offload:** the HUD surfaces whether the zone is READY (the player reads "it could go off now," never computes it) — not the exact shortfall; the opponent never reads "one orb short" (`6-3-split/R-INFO`).

> **Design intent — the timer is a shared deadline, not decoration (TDD §5.6).** The fizzle timer cuts *both* ways: the threatening player **cannot park a card indefinitely while farming orbs** (the clock forces commitment), and the defending player **knows exactly how long they must survive the threat**. That mutual, visible deadline is what turns the Pitch Zone into open-information bluffing (P3) rather than an untimed looming threat — and it is why 20 s (pressured) vs 30 s (strategic) is a genuine feel decision, not a cosmetic one.

### F. Real-Time Combat & Defensive Mechanics

The always-on soulsborne heartbeat (fighting-genre defensive layer). Defensive options: **Block**, **Deflect** (timing parry), **Roll** (i-frame dodge), and the **Unblockable Defenses** (Mode ③, §C). All defense except basic block draws on **stamina**, making stamina the currency of survival and the thing the touchstone's "two rolls to get in range" spends.

> **No traditional combo system.** Unlike the fighting-genre convention, CardSouls has **no links/juggles/cancels** — combat is souls-style attack *chains*, not a combo engine. Depth comes from spacing, stamina, deflect timing, and the unblockable reads, not execution combos. Combo-system convention = intentionally minimal.

**Arena / stage** is specified in Level Design Framework below.

### G. Equipment (pre-match loadout)

Each player equips **4 pieces** (Head / Chest / Arms / Legs) in the pre-match lobby alongside deck building. Design reference: **Flash and Blood** equipment — each piece is a **permanent passive** that modifies hero behavior or thresholds for the whole match. Equipment is **not consumed, is locked for the match's duration** (including between rounds in the full-vision Bo3), and **does not interact with the card economy directly** — it tunes the hero, not the deck.

Passive types are **data-defined** (`.tres`); examples (TDD §11.3): combat-timing (e.g. faster Red chargeup), threshold-based (e.g. damage reduction while 5+ friendly totems live), cooldown-immunity (e.g. one stun negated every 45 s), resource modifiers (e.g. +1 starting orb, higher mana regen), stat adjustments (e.g. larger stamina pool). Values are balance-critical — data, never hardcoded.

**Demo scope:** placeholder stats only, **no on-hero visual representation** (deferred, TDD §15); behind `FeatureFlag: equipment` (off → none equipped). This is the one system deliberately kept as a thin, late layer (E8) — it modifies the hero without touching the core loop.

### Conventions explicitly N/A or deferred for the demo

Merging two genre guides surfaces conventions that do **not** apply — named so they are not silently assumed:
- **Card collection / progression / currency / packs / crafting** — none. No meta-game (TDD §15).
- **Ranked / draft / arena game modes** — none. Demo "modes" are the opponent progression: training dummy → local split-screen PvP → scripted bot (bluffing AI deferred).
- **Character roster** — N/A (single shared hero; asymmetry via deck + equipment).
- **Netcode / rollback / matchmaking / spectator** — out of scope (local only).
- **Turn structure** — replaced by real-time simultaneous play; the "response windows" of a card game are the unblockable chargeup and the pitch timer.

---

## Progression and Balance

### Player Progression

**No meta-progression** — no unlocks, levels, currency, packs, crafting, or persistent player advancement (enthusiast demo; TDD §15). The only "progression" is **intra-match**: the economy ramp within a round — mana accrual, board development via cards, and orb-banking toward pitch payoffs. The full vision's between-round sideboard adaptation (Best-of-3) is the sole meta-layer and is **deferred** (see Out of Scope). Across demo iterations, the thing that "progresses" is the *designer's* mechanic-space exploration, not the player's account.

### Difficulty Curve

In a PvP demo, **difficulty is the opponent**, and the opponent build-order *is* the ramp:
- **Training dummy** — zero difficulty; feel/hitbox tuning.
- **Scripted bot** — low, fixed patterns (circles, interval attacks, occasional roll, fixed unblockable pattern); solo iteration.
- **Local PvP (human)** — unbounded; difficulty is whatever the opponent expresses.
- **Bluffing AI** — high; deferred.

There are **no single-player difficulty tiers** and the design does **not flatten difficulty** — a high skill ceiling is intended (P4 protects mastery, not ease). What must scale down for newcomers is *legibility support*, never depth.

### Economy and Resources

Four interlocking resources (full specs in Hybrid Systems); all values TBD-in-balance and data-driven:

| Resource | Role | Regen | Spent on |
| --- | --- | --- | --- |
| **HP** | Attrition clock | None (heal only via cards) | — (loss at 0) |
| **Stamina** | Defensive/aggression currency | Auto over time (souls-style) | Roll, Deflect, Unblockable init & defense |
| **Mana** | Card/offense currency | 3 sources (passive, melee-hit, accelerator) | Basic (①) + Pitch (④) |
| **Orbs** | RPS-won pitch fuel | Won only by landing unblockables | Pitch Effect cost (only the priced orbs are spent, surplus remains — `6-3-split/R-SPEND`) |

The interlinking *is* the game: **aggression → mana → cards** (P2); **unblockable reads → orbs → pitch** (P3 payoff); **stamina gates both defense and aggression** (the pressure valve). No resource is an isolated meter.

---

## Level Design Framework

### Arena Design

A **single arena**; content variety comes from *decks, not maps*.
- **Flat** — no elevation, obstacles, or corridors (TDD §3). Depth is combat and cards, not terrain.
- **Bounded** — boundary walls or an invisible kill plane prevent infinite kiting.
- **Size ~40×40 m starting point, TBD** — arena size directly governs how oppressive ranged minions and totems feel; **iterate early** (flagged in TDD as a first-order playtest variable).
- **Empty at start** — no pre-placed objects; *all* units, totems, and wards enter only through cards.
- **Camera (TDD §2):** third-person, **fixed distance (no zoom)**, pulled back *slightly further than Elden Ring's default* so the hero is fully visible with some terrain context; follows the player's own hero. The fixed, generous framing is a legibility choice — the color telegraph and opponent spacing must both read at this distance in a half-width split-screen viewport.
- **Split-screen aware** — each player renders their own camera (per Controls); the arena must read clearly at the pulled-back soulsborne camera distance in a half-width viewport.

**Level types / progression: N/A** — no levels, stages, or campaign. Multiple arena layouts are deferred (TDD §15).

---

## Art and Audio Direction

### Art Style

*(Proposal grounded in the Legibility Principle + TDD references — creative direction open for the designer to shape.)*

North star: **grounded dark-fantasy soulsborne**, per the TDD's Elden Ring references (camera pulled slightly further back than ER default; visible armor/weapon slots; ER-style ability attacks for spells). Totems/wards read as **small wardstones, not towers** — a deliberate readability choice so they don't visually dominate the small arena. Because presentation is a non-goal, **demo art is placeholder / grey-box first**; the only hard visual bar is telegraph and outcome legibility.

Non-negotiable (from the Legibility Principle): each unblockable color has a **distinct silhouette and animation pose** — Red wide sweep/stomp, Blue leaping overhead, Green lunging thrust — readable in <0.5 s, with a **colorblind-safe shape language** so recognition never depends on hue alone.

> **[NOTE FOR DESIGNER] Open aesthetic tension.** Elden Ring's muted, grounded palette pulls *against* the mandate for instant RGB telegraph legibility. The design partly resolves this by making shape + sound primary and hue secondary — but the overall tone is still a live choice: grimdark-ER vs. a more stylized/arcade-readable look that foregrounds the color language. Also open: the single hero's visual identity (who is he?). Refine in `gds-ux` / an art pass.

### Audio and Music

**Audio is mechanically critical, not decoration.** The color telegraph must be identifiable by **sound alone in <0.5 s** — Sekiro's perilous "ping" is the reference. Budget goes to *functional combat legibility first*:
- **Three distinct per-color chargeup stings** — ideally a per-color instrument/timbre identity for pre-verbal recognition (a real design lever, e.g. distinct registers/materials per color).
- **Outcome cues** — unambiguous audio for orb gained, counter-stun landed, and whiff.
- **Crisp signature deflect/parry** sound (souls/Sekiro feel), plus roll/hit SFX.
- **Music:** low priority for the demo (polish is a non-goal) — at most a tension/ambience bed; it must never mask the functional combat cues.

> **[NOTE FOR DESIGNER] Open.** Whether each color gets a leitmotif/instrument identity (and which) is an open, high-value legibility lever — decide during an audio pass.

---

## Technical Specifications

### Performance Requirements

- **60 FPS sustained** on a mid-range Windows desktop (~16.6 ms/frame). The arena is small and flat; the frame budget is dominated by **many autonomous minions + totem targeting + VFX**, not world rendering.
- **Combat determinism over frame smoothing** — timing-critical windows (hit windows, unblockable chargeup/defense) run in `_physics_process`, never gated on a variable `_process` delta.
- **Object pooling** for frequently spawned nodes (minions, projectiles, VFX, orb/damage popups) — no `instantiate()`/`queue_free()` in hot paths.
- **Throttled targeting** — minion/totem target acquisition on a shared ~0.1–0.25 s tick and/or `Area3D` overlap queries, never per-frame distance loops over all units.
- **No per-frame allocations** in hot paths; signal-driven HUD (no per-frame economy recompute).
- Split-screen renders two viewports — the 60 FPS target holds with both active.

### Platform-Specific Details

- **Engine:** Godot **4.6.3 stable** — Forward+ renderer, **Jolt** physics (3D), **D3D12** on Windows. **GDScript only** (no C#/Mono).
- **Platform:** **Windows desktop only.** No mobile/web targets; no renderer fallbacks or platform branches.
- **Local split-screen** via two `SubViewport`s (per-player camera + HUD). **No networking** (no `MultiplayerAPI`, RPCs, ENet).
- **Input** via the controller abstraction (keyboard / gamepad / scripted AI) reading named Input Map actions; P1/P2 profiles.
- Full engine conventions and hard rules: `docs/project-context.md` (the implementation source of truth).

### Asset Requirements

Deliberately **minimal — grey-box / placeholder-first.** Presentation quality is an explicit non-goal (see Goals); the *one* non-negotiable asset-quality bar is **legibility** (telegraphs and exchange outcomes), per the Legibility Principle.
- **Hero:** one model + animation set — basic attack chain, block/deflect, roll, 3 unblockable attacks (R/B/G), 3 counters, ~1 s stun, hit reactions.
- **Minions:** a few models covering the demo AI priority types.
- **Totems / wards:** small, wardstone-like models (3 subtypes: combat, mana accelerator, stamina accelerator) — intentionally unimposing.
- **VFX (legibility-critical):** per-color telegraph effects with distinct *shapes* (not hue alone), orb/damage popups, pitch stage/activate/fizzle effects, deflect spark.
- **Audio (legibility-critical):** three distinct per-color chargeup stings (recognizable <0.5 s), outcome cues (orb gained, counter-stun, whiff), deflect/roll/hit SFX.
- **UI/HUD:** per the HUD layout (HP/stamina/mana bars, 3 orb counters, 4-card hand, Pitch Zone slot + timer, deck/reshuffle/round indicators).
- **Content data:** cards, minion priorities, equipment passives, balance values, hero base stats — all authored as `.tres` Resources.
- **Equipment:** placeholder stats only; no on-hero visual representation in the demo (TDD §15).

---

## Development Epics

### Epic Structure

One-screen summary; full breakdown (goals, stories, exit criteria, dependencies, risks) in `epics.md`. Sequencing is driven by two invariants: the **feature-flag layers** (every gameplay layer independently toggleable, per project-context) and the **opponent build-order**. The controller abstraction lands in E0 so every opponent (dummy → PvP → bot) is a config swap, not a rewrite.

| # | Epic | Deliverable | Feature flag(s) |
|---|------|-------------|-----------------|
| **E0** | Foundations | Folder structure, autoloads (EventBus / FeatureFlags / CardDatabase / thin MatchState), state/visual seam, controller abstraction (keyboard), hero-stats balance `.tres`, GUT. Hero moves; headless state tests run. | — |
| **E1** | Melee combat + training dummy | Attack chain, block/deflect, roll, stamina, hitbox→state contact, HP, dummy actor. The souls heartbeat. | — |
| **E2** | Local split-screen PvP | Two `SubViewport`s, per-player camera + HUD in real half-width space, P1/P2 profiles, gamepad controller. **Combat-feel + telegraph-legibility validation starts here.** | — |
| **E3** | Card system + mana economy | CardData `.tres`, deck 20 / hand 4, draw/reshuffle, mode-select UX, Basic mode, mana (passive + melee-hit). | melee-mana-gen |
| **E4** | Minions & totems | Autonomous minion AI (data-defined priorities), pooling, throttled targeting, 3 totem subtypes. | minions, totems |
| **E5** | Unblockable RPS + orbs | Chargeup + telegraph (Mode ②), color defense (Mode ③), three-tier ladder, stun, per-color dmg, orbs, color-as-defense. | unblockable, orbs |
| **E6** | Pitch Zone | Stage / timer / cost, activate / cancel / fizzle, priced-orb spend (`6-3-split/R-SPEND`, not an all-orb reset), affordability read, Pitch effects (Mode ④), per-player zones with independent staging. Also E6 (`E6-P`): card-hand tint, hold-to-charge, the two-gait locomotion system, camera freedom, spell resolution. **← vision complete; touchstone playable; go/no-go playtests begin.** | pitch-zone |
| **E7** | Scripted bot | AI controller impl (circle / interval attack / occasional roll / fixed unblockable). Solo iteration. | — |
| **E8** | Equipment | 4 slots, data-defined passives, pre-match select (placeholder stats). | equipment |

**Sequence:** E0 → E1 → **E2 (split-screen early, as a HUD/legibility constraint)** → E3 → E4 → E5 → **E6 (loop whole)** → E7 → E8.

**Deferred to their own epics if the demo validates:** Bluffing AI, online netcode, Best-of-3 + sideboard, equipment visuals, multiple arenas.

---

## Success Metrics

### Technical Metrics

- **60 FPS sustained** on a mid-range Windows desktop (~16.6 ms/frame), measured over a full round with many autonomous minions + totem targeting + VFX active (per project-context performance rules).
- **Every gameplay layer toggles via `FeatureFlags` with no code edit** — the instrument for isolating overload works as designed.
- **State layer is fully unit-testable headless** (no scene, no visuals) — validates the state/visual separation HARD RULE; if a rule can't be tested without a running scene, that is a defect in the code, not the test.

### Gameplay Metrics

These are **playtest signals, not analytics** (no live product, no retention/DAU). The demo's job is validation, so the metrics are interpretive rules applied to observed play.

**Interpretation rules (the core instrument).**
- **"This is too hard" → not actionable.** Difficulty is intended (high ceiling is the point). Do not simplify in response.
- **"I didn't see that happen" → a P4 / legibility defect.** Fix it.
- **Loss legibility is mandatory:** a player may legitimately not know how to *win*, but must always be able to say *why they lost*. Inability = legibility defect.

**Deliberate playtester composition (instrumentation, not audience-broadening).**
- **Souls players who don't play card games** → is the *card layer legible*?
- **Card players who don't play souls** → is *execution learnable*?
- **The overlap (target audience)** → is the *ceiling high enough*?
- **One person who is neither** → diagnostic for what goes unnoticed.

**Feel checks (against locked targets).**
- Color-counter ~30–40% / dodge ~20% outcomes read as *fair, not cheap* — losing off-color feels like a read lost, not a dice roll.
- Rounds land near the **~60–120s** active-play target; **~2–4 pitch cycles** per round.
- Aggression is rewarded — turtling / durdling is not a dominant strategy (P2 holds).
- Both feature-flag paths (layer ON and OFF) play acceptably, with graceful degradation.

---

## Out of Scope

**Deferred — part of the full vision, revisited if the demo validates** (state/visual separation keeps these addable, not rewrites):
- **Online multiplayer / networking** — demo is local only.
- **Best-of-3 + sideboard** — demo is a single round.
- **Equipment visual representation on the hero** — placeholder stats only in demo.
- **Bluffing AI** — its own epic if the demo survives; scripted bot only for now.
- **Cards that remove the opponent's Pitch Zone card** — future content.

**Cut for the demo (not planned):**
- Minions/spells that **heal** the hero.
- More than **one arena layout**.
- **Spectator mode**.
- **Progression / unlocks / meta-game / collection / currency / packs / crafting.**
- **Presentation & production polish** — an explicit non-goal; grey-box is acceptable except where legibility demands otherwise.

*Nothing the designer explicitly included has been silently dropped; the above are deliberate, logged deferrals/cuts.*

---

## Assumptions and Dependencies

**Dependencies:**
- **Engine:** Godot 4.6.3 stable (Forward+, Jolt, D3D12), GDScript only.
- **Testing:** GUT (Godot Unit Test) addon; state layer tested headless.
- **Sources of truth:** mechanics = `docs/tdd-legacy-ue5.md` (v0.3, canon for *what*); implementation = `docs/project-context.md` (canon for *how* — wins on conflict).
- **All content and balance authored as `.tres` Resources:** cards, minion priorities, equipment passives, balance values, hero base stats.
- **Art/audio legibility** (telegraph shape + sound, colorblind path, outcome clarity) is a hard dependency, not optional polish.

**Assumptions:**
- **[ASSUMPTION]** The GDD scopes the **local demo** as the primary target (confirmed with the designer); the full online / Best-of-3 vision is deferred, not abandoned.
- **[ASSUMPTION]** Solo developer; learning (Godot, workflow, architecture) is an in-scope secondary goal.
- **All balance numbers are TBD-in-playtest** and must be tunable without recompiling: HP, stamina/mana totals & regen, unblockable damage, all timing windows, pitch timer (20 vs 30 s), arena size, draw delay, reshuffle window, per-card copy cap.

*Open questions and playtest-flagged items are consolidated in `decision-log.md`.*
