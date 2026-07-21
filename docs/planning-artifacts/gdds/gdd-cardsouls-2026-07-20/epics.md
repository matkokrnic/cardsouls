---
title: CardSouls — Development Epics
parent: gdd.md
created: 2026-07-20
updated: 2026-07-20
status: draft
---

# CardSouls — Development Epics (Demo Scope)

Detailed breakdown of the epic sequence summarized in `gdd.md`. High-level-story granularity; full stories are produced downstream (`gds-create-epics-and-stories` / `gds-create-story`). Every gameplay layer sits behind a `FeatureFlags` toggle and must **degrade gracefully** when off. All balance numbers are TBD-in-playtest and authored as `.tres`.

**Sequencing invariants:** (1) the controller abstraction lands in **E0** so dummy/PvP/bot are config swaps; (2) split-screen lands in **E2** as a *constraint* on the HUD (build every HUD element in its real half-width space) and as the only way to validate <0.5 s telegraph legibility at soulsborne camera distance; (3) the buildup→bluff→payoff loop is not whole until **E6**.

---

## E0 — Foundations

**Goal.** Establish the architecture skeleton and invariants so every later layer is a data/config addition, not a refactor.

**Key stories.**
- Folder structure: `src/state/`, `src/systems/`, `src/actors/`, `src/ui/`, `data/`, `test/` (per project-context).
- Autoloads: `EventBus`, `FeatureFlags` (loads one `FeatureFlags` `.tres` once at startup), `CardDatabase`, thin `MatchState` wrapper (match logic lives in `src/state/` as a plain testable object — no scene deps).
- **Controller abstraction:** interface + local-keyboard implementation; hero is driven by a controller, and nothing in hero/state branches on "is this a human."
- Hero base stats in a balance `Resource` (`.tres`); `HeroState` in `src/state/` (no scene/visual deps).
- GUT setup; first headless state test; a smoke test that loads every `.tres` in `data/` and asserts required fields.

**Exit criteria.** Hero moves in the arena via the keyboard controller; headless state tests green; `FeatureFlags` autoload loads a `.tres`.

**Risks.** Getting the state/visual seam and controller abstraction right up front — they are the invariants everything else depends on.

---

## E1 — Melee Combat + Training Dummy

**Goal.** Build the soulsborne combat heartbeat in the state + actor layers.

**Key stories.**
- `CharacterBody3D` hero movement (`move_and_slide`); pulled-back soulsborne camera.
- Basic attack chain — state-driven; hitbox *reports contact*, state applies chip damage and exposes a mana-generation hook (wired in E3).
- Block / Deflect — hold to block; precise-timing parry window; stamina cost.
- Roll — i-frame dodge in movement direction; stamina cost.
- Stamina economy — auto-regen; zero-stamina lockout of roll/deflect/unblockable.
- Hitbox → Hurtbox contact events → state decides damage; HP state; death at 0.
- Training dummy actor (HP, no retaliation).
- Headless tests: stamina economy, HP/damage, deflect window (driven by fixed `delta` steps).

**Exit criteria.** Timing-critical logic runs in `_physics_process`; state tests cover the economy; combat is exercisable against a dummy.

**Risks.** Souls-combat *feel* is the highest-risk unknown — but note feel is genuinely judged in **E2** (vs a moving opponent), not here (a dummy only tunes hitboxes).

---

## E2 — Local Split-Screen PvP

**Goal.** Make the build 2-player from week one; put the HUD in its real half-width space; enable combat-feel and telegraph-legibility validation.

**Key stories.**
- Two `SubViewport`s, per-player camera, split-screen layout.
- Per-player HUD root (bars) rendered at half width — every HUD element designed for its final real space from the start.
- P1/P2 input profiles; **gamepad controller implementation** (second controller-abstraction impl).
- Two hero instances, independent controllers, hidden per-player state.

**Exit criteria.** Two humans fight melee in split-screen; spacing/attack-weight/deflect feel is evaluable human-vs-human; the viewport size that later telegraphs must read in exists.

**Risks.** Two-profile input mapping; camera framing at half width.

**Note.** This is the **primary playtest tool.** Bluffing is *not* testable yet (needs E5/E6) and that is accepted — early PvP exists to validate combat feel and to keep the build playable with other people, both stated project goals.

---

## E3 — Card System + Mana Economy

**Goal.** The card-economy foundation and the aggression flywheel (P2).

**Key stories.**
- `CardData` Resource (color, Basic effect + cost, Pitch effect + cost, per-card copy cap); `CardDatabase` loads `.tres`.
- Deck (20), hand (4), draw at round start, draw-on-play (instant vs ~1 s delay — TBD), reshuffle + vulnerable window (~1.5–2 s TBD, flagged visually).
- **Card-mode selection UX** — real-time mode pick (radial / hold-modifier / per-mode bind — open, high P4 relevance); Basic mode (①) resolves (summon/spell hook; concrete actors in E4).
- Mana economy: passive auto-regen + melee-hit generation (wire the E1 hook). `FeatureFlag: melee-mana-gen` (off → passive only).
- HUD: 4-card hand display, mana bar + regen tick, deck/reshuffle indicators.

**Exit criteria.** Basic-mode cards playable at mana cost; melee hits fund mana; the flywheel is observable; both flag paths play.

**Risks.** Mode-select UX under real-time pressure must not become a parallel demand (P4).

---

## E4 — Minions & Totems

**Goal.** Board presence via cards.

**Key stories.**
- Minion actor + autonomous AI; priority types **data-defined** (Standard, Hero-Seeker, Tank, Bomber/AoE) — new types addable via `.tres`, no code.
- Object pooling for minions/projectiles/VFX; throttled targeting tick (~0.1–0.25 s) and/or `Area3D` overlap queries (no per-frame distance loops).
- Totem/ward subtypes: **Combat Totem** (ranged fire, destructible), **Mana Accelerator** (sustained mana-regen layer), **Stamina Accelerator** (stamina-regen boost). All small/wardstone-like.
- Wire Basic-mode summons to real actors. `FeatureFlags: minions, totems` (degrade gracefully).

**Exit criteria.** Cards summon functioning minions/totems; 60 FPS holds with many units; flags toggle cleanly.

**Risks.** Targeting performance; minion AI feel in the small arena (arena size interacts — iterate).

---

## E5 — Unblockable RPS + Orbs

**Goal.** The combat core of the vision — the RGB read exchange and its payout.

**Key stories.**
- Unblockable Initiation (Mode ②): chargeup + color telegraph (**shape + sound**, <0.5 s), stamina cost, generous auto-aim that does **not** absorb spacing (Reactor/Actor).
- Unblockable Defense (Mode ③): instant, color-match, within the chargeup window.
- **Three-tier outcome ladder** — no-answer/wrong-color → full dmg + attacker orb; dodge/leave-range → none; correct color → none + attacker stun ~1 s. Per-**color** fixed damage (balance `.tres`).
- Orb resource: acquisition on land, per-color storage (no cap), HUD counters, all-color-reset hook (spent in E6).
- Color-as-defense: Mode ③ requires a matching-color card in the 4-card hand.
- `FeatureFlags: unblockable, orbs` (degrade).
- Headless tests: RPS outcomes, orb grant, three-tier resolution, timing via fixed `delta`.

**Exit criteria.** The RGB read loop plays and pays orbs; the ladder reads as fair (playtest); determinism verified in tests.

**Risks.** Defense-window length is the fairness core; telegraph legibility must be judged in the E2 half-width viewport.

---

## E6 — Pitch Zone (Vision Complete)

**Goal.** Close the buildup→bluff→payoff loop; make the Design Touchstone playable.

**Key stories.**
- Pitch Zone slot; stage a card from hand; **public** cost + countdown timer (20 vs 30 s TBD) visible to the opponent.
- Exit paths: activate (cost met) / cancel (return to hand) / **fizzle** (timer expires → discard + draw, no refund of accumulated mana/orbs).
- Pitch Effect (Mode ④) resolution; **all-color orb reset on activation**.
- Affordability surfaced in HUD (read, not computed) — Reactor/Actor offload.
- Overlap handling: **lockout** (working assumption) — one staged card per player; cross-player staging locked out for N seconds. (Alternatives a/c logged.)
- Staged card still counts toward the hand of 4.
- `FeatureFlag: pitch-zone` (off → pitch modes unavailable; if orbs off, pitch cost is mana-only).

**Exit criteria.** The full touchstone is playable in split-screen; buildup→bluff→payoff exists end-to-end.

**Milestone.** **The vision is now testable.** The go/no-go validation playtests (and the playtester-composition instrumentation from Success Metrics) begin here.

---

## E7 — Scripted Bot

**Goal.** Solo iteration without a second human.

**Key stories.**
- Scripted AI controller **implementation** (a config swap on the E0 controller abstraction — no hero/state changes): approach/circle, interval basic attacks, occasional roll, fixed unblockable pattern.
- Tunable via data where practical.

**Exit criteria.** Solo-playable vs the bot; achieved purely as a controller implementation.

**Note.** This is **not** the bluffing AI (deferred). It cannot lie, stage unaffordable pitches, or fold — and therefore cannot test P3.

---

## E8 — Equipment

**Goal.** The equipment passive layer, toggleable.

**Key stories.**
- Four slots (head / chest / arms / legs); `EquipmentData` Resource with **data-defined** passive effects.
- Pre-match selection (placeholder stats; no on-hero visuals).
- Passive effect types applied via state: combat-timing, threshold-based, cooldown-immunity, resource modifiers, stat adjustments.
- `FeatureFlag: equipment` (off → none equipped).

**Exit criteria.** Equipment passives modify hero behavior; fully data-driven; flag toggles.

**Note.** Placeholder stats only; on-hero visual representation deferred (TDD §15).

---

## Deferred Epics (post-demo, if the demo validates)

- **Bluffing AI** — the hardest AI in the project; must decide when to lie, stage unaffordable cards, and fold. Its own epic; the only thing that truly tests P3 without a human.
- **Online netcode** — the state/visual separation and controller abstraction exist to make this an added layer, not a rewrite.
- **Best-of-3 + sideboard** — round format and between-round adaptation.
- **Equipment visuals** — on-hero representation (Elden Ring style).
- **Multiple arenas** — additional layouts.
