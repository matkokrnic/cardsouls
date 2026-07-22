# CardSouls GDD — Decision Log

Chronological record of design decisions, changes, and version/state transitions. Every entry should be reflected in `gdd.md` / `epics.md` or explicitly set aside.

---

## Session 2026-07-20 — Create

### Setup & framing

- **Intent:** Create (no prior GDD existed). Inputs available: `docs/tdd-legacy-ue5.md` (v0.3, mechanics-canon, UE5/online — engine & networking details obsolete) and `docs/project-context.md` (Godot 4.6.3 / GDScript implementation rules).
- **Scope decision:** GDD scopes the **local single-machine demo** as the primary target — single round, local PvP / vs-AI, no networking, placeholder equipment stats. The fuller online / Best-of-3 / sideboard / equipment-visuals vision is captured under *Out of Scope / deferred*, not lost. (Aligns TDD §15 with project-context.) — _confirmed by Matko._
- **Genre lens:** **Equal hybrid** — merge card-game and fighting convention sets into one co-primary `Hybrid Systems` section, neither subordinate. — _chosen by Matko._
- **Working mode:** **Facilitative** — walk pillars, core loop, mechanics, and the hybrid section together before drafting; log decisions section-by-section. — _chosen by Matko._
- **Narrative flag:** none. Neither genre guide (card-game, fighting) carries a narrative-workflow flag; no dedicated narrative pass planned. Game has no story/campaign mode (TDD §15 cuts progression/meta).

### Design decisions

**Vision statement (locked).** The game exists to deliver buildup, bluff, and payoff — through soulsborne combat skill dynamics, not through numbers/deckbuilding. If that trio isn't felt in real-time play, the game has failed regardless of economy balance. This is the top-level bar. — _authored by Matko._

**Design Touchstone (locked).** The ten-second Pitch-Zone / orb-short / feint-or-cash-in image is the canonical touchstone. Rule: any mechanic that doesn't appear in it, or competes with it for attention, needs justification. — _authored by Matko._

**Game Pillars (locked — 4).**
- P1 Dual mastery — combat and cards equally decisive; deck/economy sets up stakes & tools, combat delivers the skill/resolution. (stands as originally proposed)
- P2 Aggression is economy — melee→mana→cards flywheel; pressure funds, turtling starves. (stands as originally proposed)
- P3 **Visible threat, uncertain delivery** — REVISED from "nothing decisive is hidden" (which designed bluffing out). Open-information bluffing, poker-not-hidden-hand: Pitch Zone shows *what* & *how long*, not affordability or intent. — _revised by Matko._
- P4 **One thing at a time — layers alternate, don't stack** — ADDED. Sequential not parallel cognitive demand; during chargeup the color read is the only decision. Every mechanic tested for parallel-vs-sequential demand. Named as the single biggest risk to the game. — _added by Matko._

**P4 attacker-load tension — RESOLVED into a binding constraint (Reactor/Actor principle).** Chosen: Option 1 (defender-guarantee; offload attacker) *with a constraint on the offload.* — _decided by Matko._
- Overload is dangerous only under reaction pressure. **P4 binds the reactor absolutely** (defender's ≤~0.5s color read carries exactly one live decision). The attacker chooses at own tempo — weighing orbs/timer/bluff *is the buildup* (first word of the vision), not load.
- **Actor offloaded through information display only, never by removing execution.** Allowed: HUD surfaces attacker orbs/timer/stamina (read, don't compute). Forbidden: auto-aim absorbing spacing. Generous chargeup auto-aim (no precise manual aim, per TDD §7.3) is fine, but closing distance, retaining stamina to retreat, and being punishable on a whiffed chargeup MUST remain.
- Rejected alternatives & why: symmetric single-tracking strips the attacker's orb/timer/bluff weighing (= the game); deliberately-harder attacker seat punishes aggression and starves melee→mana (violates P2).
- **Vision guard clause:** if payoff stops being delivered through soulsborne execution, the vision is violated even if systems work.
- Downstream bindings: HUD design (affordability surfaced, e.g. pitch cost glows affordable), auto-aim spec (aim-assist yes, spacing-absorb no), whiff-punish windows on chargeup.

**Core Gameplay Loop (locked).** Single continuous real-time loop (no turns), structured as the vision triad buildup→bluff→payoff over an always-on soulsborne combat heartbeat. ① Buildup = aggression flywheel (melee→mana→cards, bank orbs). ② Bluff = public Pitch Zone commitment, feint-or-cash. ③ Payoff = soulsborne color-read execution. ↻ reset; chip-damage clock underneath. Heartbeat (①) is continuous; ②③ are spikes. — _framed with Matko._

**Kill-source decision (locked) + binding balance rule.** Option 1: spikes (pitch payoffs + landed unblockables) end MOST rounds — the payoff delivers the kill; chip/minions are the clock. — _decided by Matko._
- **Constraint (protects P1):** chip must remain a credible finisher at low HP. If only spikes kill, melee becomes a pure mana faucet and dual-mastery collapses. Opponent below ~15–20% HP must still fear an ordinary attack chain. Ordinary hits stay ~5–8% HP (TDD §6). Net: spikes end most rounds, chip ends some, threat-of-chip keeps melee decisive and stops defenders turtling into pure color reads.

**Win/Loss (locked).** Round ends at HP 0. Demo = single round. Full vision Best-of-3 deferred to Out of Scope.

**Loop cadence (locked as tuning target).** Medium — **~2–4 full buildup→bluff→payoff cycles per round.** Each pitch a real commitment; fast/frequent cheapens payoff + crowds P4, single-climax risks dead air + fights P2. A tuning target realized via pitch cost / orb rate / timer length (20 vs 30s), not a hardcoded value. Round-length target **~60–120s active play**. — _decided by Matko._

**Demo opponent model + input architecture (locked).** — _decided by Matko; corrected the facilitator's vs-AI recommendation._
- Facilitator was **wrong** that local same-machine can't preserve hidden hands: split-screen via two Godot `SubViewport`s (per-player camera + HUD) keeps hands private and is cheap. Only a single shared camera would leak.
- **Decisive principle:** an AI that cannot bluff cannot test P3 (the whole game hinges on cash-in-vs-feint). Bluffing AI is the hardest thing in the project and arrives last — so the demo must NOT be built around it, or it tests everything except the vision.
- **Opponent build order (also seeds the epic sequence):** (1) **Training dummy** — stands, has HP, no retaliation; hitbox/attack-feel tuning; ~1h. (2) **Local split-screen PvP**, two input profiles — the PRIMARY playtest tool and first real test of bluffing; ~half a day. (3) **Scripted bot** — circles, attacks on intervals, occasional roll, fixed unblockable pattern; solo iteration; ~1 day. (4) **Bluffing AI** — DEFERRED, out of demo scope; becomes its own epic if the demo survives.
- **Constraint (architectural invariant): input source is data, not code.** The hero is driven by a controller abstraction with three interchangeable implementations — local keyboard, local gamepad, scripted AI. Nothing in the hero or state layer may branch on "is this a human." This makes dummy/PvP/bot a config swap, not three rewrites, and is the same seam that makes netcode addable later (consistent with project-context state/visual separation).

**Hero identity (locked).** Single shared hero; fighting "character roster" convention = N/A. All asymmetry from deck + equipment. — _agreed by Matko._
- **Constraint:** hero base stats live in a **balance `Resource` (`.tres`)**, not constants on the hero script — a roster later is authoring files, not a refactor. Demo testing advantage: both players mechanically identical except deck → playtests isolate the card layer cleanly.

**Color-as-defense (locked — core pillar of combat).** Mode 3 needs a matching-color card in the 4-card hand; hand composition = live defensive toolkit. Confirmed intended & kept. — _decided by Matko._
- ~80% chance of holding ≥1 card of a color in a 4-card hand (color-balanced deck) → off-color is occasional, not routine → gives the attacker a reason to bluff, not a free win.
- Deck color ratio is a defensive decision; mono-color = strong offense / helpless vs 2/3 of unblockables. P1 for free.

**Unblockable outcome — three-tier ladder (locked; revises TDD binary §7.5).** "Unblockable" = not-blockable, NOT undodgeable (Sekiro-perilous behavior). — _decided by Matko._
- no answer/wrong color → full dmg + attacker gains orb; dodge/leave-range (~20% target) → no dmg, no orb, no punish; correct color (~30–40% target) → no dmg, no orb, attacker stunned ~1s.
- Escalation: survive → survive+deny → survive+deny+punish. Color is the ONLY tier that stops (not merely survives) the attacker → color never optional.
- **Constraint (emergence, not hardcode):** the % targets are playtest checks, NOT values. Dodge emerges from spacing/timing vs generous auto-aim; counter needs telegraph read AND holding the color (~20% failure from hand-math). Both live in same window; skill moves the ratio.

**Unblockable spam self-limiting (recorded as design rationale).** Mode 2 consumes the card → every unblockable thrown thins the thrower's own defensive color coverage. + stamina cost + ~1s stun on correct read = aggression priced without an explicit cooldown; the economy is the throttle. — _articulated by Matko._

**OPEN (playtest) — new combat timing items.** Chargeup duration; defense input window length; whether disengaging costs enough stamina to matter; whether the dodge window should be tighter than a normal roll. (Added to the timing-windows fairness cluster.)

**Purpose & stakes (locked).** Enthusiast exploration + learning build; NOT a commercial vertical slice; no revenue timeline. Primary goal: find which mechanic combination makes the souls+TCG fusion great — prove the core loop is "interesting enough to keep exploring." Feature-flag architecture is the instrument for isolating overload. Secondary: learning Godot/workflow/architecture. **Disposability = success** (throwing away disproven mechanics is a win). Non-goals: revenue, presentation quality, audience breadth. — _stated by Matko._

**P4 REFRAMED (critical — propagated to the pillar).** P4 is about **PARALLEL demands, not DIFFICULT ones.** High skill ceiling (Sekiro/TCG level) is the POINT; P4 must NOT be read as a mandate to simplify. Sekiro's load is deep, not wide. Two simultaneous clocks = worse legibility, not higher ceiling; losing to an unnoticed timer feels like something slipped past, not being outplayed. **Sequential demands can be mastered; parallel can only be endured.** Measure mechanics on sequence-vs-parallel, NEVER on hardness. — _corrected by Matko._

**Legibility Principle (locked — companion to P4).** Legibility ≠ simplicity (Sekiro kanji = maximally legible AND brutal); high ceiling + high legibility are complements. Player always knows *what happened and why*; difficulty is whether they can execute. Binding obligations: color telegraph recognizable <0.5s pre-verbally via *shape + sound* (also colorblind path); every exchange outcome immediately obvious (orb? stun? counter registered?); pitch affordability read-not-computed. **Interpretation rule:** a player may not know how to *win* (difficulty); must never not know why they *lost* (legibility defect). — _added by Matko._

**Target audience (locked).** Overlap of souls/Sekiro + TCG players; execution + decision under pressure; small & demanding by design; breadth not a goal. — _confirmed by Matko._

**Playtester composition (locked as instrumentation, distinct from audience).** Deliberately broader than the audience — souls-not-cards (card legibility?), cards-not-souls (execution learnable?), overlap (ceiling high enough?), neither (what goes unnoticed?). Interpretation: "too hard" = not actionable; "didn't see that happen" = P4/legibility defect. — _defined by Matko._ (Written into Success Metrics.)

---

## Finalization — 2026-07-21 → v1.0 (draft complete)

**TDD reconciliation (qualitative-intent focus).** Walked all 16 TDD sections vs the draft; restored 3 flattened/dropped intents + added 1 example:
- Fizzle timer = *shared deadline* rationale (§5.6) — restored to Pitch Zone.
- Camera spec (§2, fixed-distance/no-zoom/ER-framing as legibility choice) — restored to Arena.
- Equipment (§11) — added Hybrid Systems §G with the "Flash and Blood" reference, match-long immutability, and "doesn't touch card economy" boundary.
- Imp Summoner worked example (§9) — added to Card System (all four modes on one card). — _requested by Matko._

**Validation (inline, full checklist).** Strong on traceability/measurability/epic-continuity/no-template-tokens. Findings:
- **D-1 engine leakage — RESOLVED (soften).** Granular engine-API names removed from *design* sections (`SubViewport`→"per-player split viewports"; `_physics_process`→"deterministic/framerate-independent"); concrete engine detail kept only in Technical Specs + epics.md. The 4 architectural invariants (input-is-data, state-has-no-scene-deps, every-layer-toggleable, content-as-`.tres`) kept as design-level. — _decided by Matko; reason: avoid repeating the UE5-coupling debt that got tdd-legacy quarantined; engine API names expire and don't read to collaborators/playtesters._
- **S-1 terminology — FIXED.** Card play modes standardized to circled "Mode ②" notation throughout gdd.md + epics.md.
- **G-1 nux — noted N/A** (no onboarding/tutorial; appropriate for a demanding-audience validation demo). D-3 (minor how-in-Technical from project-context) — left as-is. — _agreed by Matko._

**Art/Audio open calls — all deferred (non-blocking):** ER-muted-vs-stylized palette (decide when gameplay works), hero visual identity (art pass), per-color audio leitmotifs (kept flagged as high-value legibility lever, not decoration). — _deferred by Matko._

**Open items at finalization (none phase-blocking):** playtest-deferred — pitch overlap (working assumption: lockout), card-mode-select UX, defense-window length + timing cluster, full balance TBD set; aesthetic-deferred — the 3 Art/Audio calls. All logged above.

**Status: GDD draft complete.** Artifacts: `gdd.md`, `epics.md`, `decision-log.md`. Next: `gds-game-architecture`.

---

**Development Epics (locked).** 9 demo epics + deferred set. Sequencing driven by feature-flag layers + opponent build-order; controller abstraction in E0 makes opponents config swaps. Written to `epics.md` (detail) + `gdd.md` (summary). — _structured with Matko._
- **Split-screen moved to E2** (right after E1 melee+dummy, before cards) — _decided by Matko, overriding facilitator's E6 placement._ Rationale (rework argument inverted): split-screen is a *constraint* on the HUD, not an addition — building HUD full-width then halving = rebuild; build in real half-width space from the start. It's also a legibility dependency: <0.5s telegraph must be validated in a half-width viewport at soulsborne distance (the single most binding visual req). Melee feel needs a moving/threatening opponent (spacing), which a dummy is not; combat feel is the highest-risk unknown. Cheapest at E2 (HUD is 2 bars; ~half a day). Accepted trade-off: bluffing not testable until E5/E6 — fine, early PvP is for combat feel + keeping the build playable with others from week one (both stated goals).
- Final order: E0 foundations → E1 melee+dummy → E2 split-screen PvP → E3 cards+mana → E4 minions+totems → E5 unblockable RPS+orbs → E6 pitch zone (vision complete, go/no-go playtests begin) → E7 scripted bot → E8 equipment.
- Deferred epics: bluffing AI, online netcode, Bo3+sideboard, equipment visuals, multiple arenas.

**Art/Audio + remaining canon sections (drafted from TDD + project-context, pending review).** Progression/Balance, Arena, Technical, Out of Scope, Assumptions written as canon-derivable. Art/Audio written as a *proposal* (Elden Ring north star; grey-box-first since presentation is a non-goal; telegraph shape+sound+colorblind non-negotiable). Open aesthetic items flagged as `[NOTE FOR DESIGNER]`: ER-muted vs stylized-readable palette tension, hero visual identity, per-color audio leitmotifs. — _facilitator draft; awaiting Matko review._

**OPEN (playtest) — Pitch overlap / P4 edge case.** Each player owns a Pitch Zone → simultaneous pitches possible. Both staging at once forces the defender into parallel demands (own timer + opp timer + color telegraph + stamina + spacing) — a P4 violation. Cadence is also about *overlap*, not just frequency. Candidate resolutions: **(a)** global Pitch Zone — one staged card in the match at a time (cleanest for P4; kills bluff-vs-bluff); **(b)** overlap-with-lockout — staging locks the other player out for N seconds (**working assumption**); **(c)** free overlap — richest, highest cognitive load. Playtest decision, not design-time. Recorded in Core Loop as `[NOTE FOR DESIGNER]`; to be detailed in Pitch Zone spec. — _raised by Matko._

---

## Session 2026-07-22 — Implementation-readiness gate (Set B stories)

Two deliberately-open decisions were held open in the GDD/story set but had no OPEN entries here. Logged now per readiness-gate finding so no story or implementation pass resolves them by accident; both remain Matko's to decide.

**OPEN — Attacker consequence on basic-attack deflect.** A landed deflect negates damage, pays its stamina cost, and emits its cue (E1.S8). What happens to the **attacker** — stun, stagger, stamina penalty, or nothing — is undecided. E1 explicitly keeps the attacker's consequence out of scope (stories-manual-e1 E1.S8 item 3); no E1 code path may wire one. Note: story 1-1 authors a `stun_seconds` balance field as data only — its existence does **not** resolve this decision. Status: **OPEN**, no resolution recorded.

**OPEN — Reshuffle vulnerable-window mechanical cost.** GDD fixes deck exhaustion → auto-reshuffle with a brief vulnerable window (~1.5–2s TBD, flagged visually to both players), and E3.S3 implements the window as a `TimingWindow` with an authored duration and a queued signal. What the window **costs mechanically** (what "vulnerable" does to the reshuffling player) is undecided and must not be invented at implementation time. Status: **OPEN**, no resolution recorded.

---

## Session 2026-07-22 — Story 1-1 close-out: deferred implementation debts & forward constraints

Recorded at 1-1 close-out (implementation + independent cross-model review both passed clean). These are **tracked implementation debts and forward constraints**, distinct from the OPEN design decisions above — nothing here is Matko's-to-decide design; each is an obligation that binds the story whose role matches its trigger. Triggers are deliberately described by role ("the first story that…"), not pinned to a story number.

**DEBT A — Runner still on E0 placeholder constants; authored `.tres` is inert in the live game.** `match_runner.gd` was intentionally NOT rewired in 1-1: it still uses its E0 placeholder constants and never calls `MatchState.apply_balance()`. Consequence: `data/balance/balance_config.tres` has NO effect on the live game — only the AC3 headless test drives `apply_balance`. Two placeholder sets (runner constants + the `.tres`) can drift out of sync until the runner is rewired.
The FIRST story that makes the runner inject balance at match start (equivalently, the first story that makes `advance()` read `balance_ticks`) MUST carry BOTH coupled obligations, landing together:
1. wire the runner to call `apply_balance(BalanceConfigService.get_config())` at match start — otherwise `advance()` reads null/default;
2. DELIBERATELY regenerate + review the determinism golden hash. The golden is currently protected by CALL-SITE ABSENCE (`apply_balance` is never invoked in the recorded determinism sequence), NOT by snapshot-shape immunity. The E0 golden was baked from constructor values, not from the `.tres`, so once `apply_balance` enters the determinism path the hash WILL move regardless of `.tres` authoring. The re-baseline must be explicit and reviewed, never silent.

**DEBT B — `reload()` returns a cached resource; on-disk hot-reload is a no-op without `CACHE_MODE_IGNORE`.** `BalanceConfigService.reload()` uses `load()`, which returns the cached resource if already in memory. A mid-session on-disk edit to the `.tres` would NOT be picked up — which defeats the entire purpose of `reload()` (X3 hot-reload from disk). Current tests do not catch this (no test edits the file mid-run). No runtime reload trigger exists in E1 yet, so it is harmless today.
The FIRST story that introduces a live mid-match reload trigger MUST land BOTH halves together:
1. `ResourceLoader.load(..., CACHE_MODE_IGNORE)` in `reload()` so the on-disk edit is actually re-read;
2. record the reload event into the intent stream (X5: replay = seed + intents + reload events — reconstructed from the stream, never re-read from disk at replay time).

**CONSTRAINT C — Downstream E1 stories must read `ms.balance_ticks` at `start()` time; never cache the `BalanceTicks` object.** `apply_balance()` swaps the whole `BalanceTicks` object on every reload. Any code that caches a reference to the old object (instead of reading `ms.balance_ticks.*` at the moment it calls `TimingWindow.start()`) would hold stale durations across a reload. Nothing does this today; it is the pattern later E1 stories must avoid.
