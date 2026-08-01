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

**OPEN DECISION (a) — Attacker consequence on basic-attack deflect.** A landed deflect negates damage, pays its stamina cost, and emits its cue (E1.S8). What happens to the **attacker** — stun, stagger, stamina penalty, or nothing — is undecided. E1 explicitly keeps the attacker's consequence out of scope (stories-manual-e1 E1.S8 item 3); no E1 code path may wire one. Note: story 1-1 authors a `stun_seconds` balance field as data only — its existence does **not** resolve this decision. Status: **OPEN**, no resolution recorded.

**OPEN DECISION (b) — Reshuffle vulnerable-window mechanical cost.** GDD fixes deck exhaustion → auto-reshuffle with a brief vulnerable window (~1.5–2s TBD, flagged visually to both players), and E3.S3 implements the window as a `TimingWindow` with an authored duration and a queued signal. What the window **costs mechanically** (what "vulnerable" does to the reshuffling player) is undecided and must not be invented at implementation time. Status: **OPEN**, no resolution recorded.

---

## Session 2026-07-22 — Story 1-1 close-out: deferred implementation debts & forward constraints

Recorded at 1-1 close-out (implementation + independent cross-model review both passed clean). These are **tracked implementation debts and forward constraints**, distinct from the OPEN design decisions above — nothing here is Matko's-to-decide design; each is an obligation that binds the story whose role matches its trigger. Triggers are deliberately described by role ("the first story that…"), not pinned to a story number.

**DEBT A — RETIRED 2026-07-24 (story 1-3b, both halves together — see Session 2026-07-24 — Story 1-3b close-out). Original entry kept below for the record.** Runner still on E0 placeholder constants; authored `.tres` is inert in the live game. `match_runner.gd` was intentionally NOT rewired in 1-1: it still uses its E0 placeholder constants and never calls `MatchState.apply_balance()`. Consequence: `data/balance/balance_config.tres` has NO effect on the live game — only the AC3 headless test drives `apply_balance`. Two placeholder sets (runner constants + the `.tres`) can drift out of sync until the runner is rewired.
The FIRST story that makes the runner inject balance at match start (equivalently, the first story that makes `advance()` read `balance_ticks`) MUST carry BOTH coupled obligations, landing together:
1. wire the runner to call `apply_balance(BalanceConfigService.get_config())` at match start — otherwise `advance()` reads null/default;
2. DELIBERATELY regenerate + review the determinism golden hash. The golden is currently protected by CALL-SITE ABSENCE (`apply_balance` is never invoked in the recorded determinism sequence), NOT by snapshot-shape immunity. The E0 golden was baked from constructor values, not from the `.tres`, so once `apply_balance` enters the determinism path the hash WILL move regardless of `.tres` authoring. The re-baseline must be explicit and reviewed, never silent.

**DEBT B — `reload()` returns a cached resource; on-disk hot-reload is a no-op without `CACHE_MODE_IGNORE`.** `BalanceConfigService.reload()` uses `load()`, which returns the cached resource if already in memory. A mid-session on-disk edit to the `.tres` would NOT be picked up — which defeats the entire purpose of `reload()` (X3 hot-reload from disk). Current tests do not catch this (no test edits the file mid-run). No runtime reload trigger exists in E1 yet, so it is harmless today.
The FIRST story that introduces a live mid-match reload trigger MUST land BOTH halves together:
1. `ResourceLoader.load(..., CACHE_MODE_IGNORE)` in `reload()` so the on-disk edit is actually re-read;
2. record the reload event into the intent stream (X5: replay = seed + intents + reload events — reconstructed from the stream, never re-read from disk at replay time).

**CONSTRAINT C — Downstream E1 stories must read `ms.balance_ticks` at `start()` time; never cache the `BalanceTicks` object.** `apply_balance()` swaps the whole `BalanceTicks` object on every reload. Any code that caches a reference to the old object (instead of reading `ms.balance_ticks.*` at the moment it calls `TimingWindow.start()`) would hold stale durations across a reload. Nothing does this today; it is the pattern later E1 stories must avoid.

---

## Session 2026-07-23 — Story 1-2 close-out

**DECISION A (locked) — hero ROOT must never be rotated while the camera is fixed (all of E1).** Body/facing rotation belongs on a child mesh node, never the root: the camera rig is a child of the hero root, so root rotation would fold into the pushed camera basis and break camera-relative "forward". The runner pushes the rig's **LOCAL** basis; guarded by `test/integration/test_root_rotation_isolation.gd`. A future story needing a rotating root must deliberately decouple the rig from hero rotation — **DECISION B, deferred**; nothing here resolves it. Detail: `docs/implementation-artifacts/1-2-camera-relative-movement-basis.md` (Dev Notes + Dev Agent Record).

---

## Session 2026-07-23 — Story 1-3 close-out

**DECISION (locked) — chain_index resets on ANY exit from ATTACKING, roll-cancel included; a cancelled chain never resumes.** Enforced in one place (`HeroState.set_action_state`) and test-pinned (`test_pin_roll_cancel_resets_chain_sequence`). Revisiting this is a deliberate playtest decision, never an incidental change.

**Implementation contract — attack phases are derived, not stored.** Windup/active/recovery are read off which window is currently running; phase-boundary ticks (all windows stopped) are disambiguated via `elapsed_ticks` with `start(0)`-cleared successor windows. The mechanism assumes every phase duration is >= 1 tick — a 0.0-authored phase duration is a config authoring error (audited in 1-3b).

**Pinned tick contracts (all test-pinned in `test_action_state.gd`):** transitions evaluate before `_resolve_movement` (a press on tick N acts on tick N); `INPUT_PRIORITY` is attack > roll > block with at most one transition per tick; a gated-rejected edge (chain at the cap) falls through to the lower-priority press the same tick.

**DEBT A status.** 1-3 took option (b): a single `balance_ticks == null` guard skips step-3 transition evaluation entirely, so live-play actions are inert while the runner still runs on E0 placeholders. Both DEBT A halves (runner `apply_balance` at match start + the coupled golden re-baseline) land together in the named follow-up story **`1-3b-live-balance-injection`**, scheduled before 1-4.

**Golden record.** `253ab157...c832` -> `d3f42def...bcf7`, cause **snapshot shape only** (window renames + 5 new windows + `chain_index`), proven by re-mapping the new snapshot to the old shape and reproducing the old golden exactly. The DEBT A re-baseline remains pending and distinct.

**1-5 scoping obligation.** Chain transition logic lives in 1-3; story 1-5 covers the remainder only — hitbox-active state data, damage application, per-swing contact dedupe, and the melee-hit mana hook. Do not re-implement the chain.

---

## Session 2026-07-24 — Story 1-3b close-out

**DEBT A RETIRED — both halves landed together, per the locked 1-1 obligation.** Half 1 (9ae10b7): the runner injects authored balance ONCE at match start — `apply_balance(BalanceConfigService.get_config())` in `_ready()`, before the first tick, with an `Invariant.check` on a null config. Half 2 (65811b3): the determinism golden path now calls `apply_balance` — with a FIXED in-test config, deliberately never the authored `.tres`, so playtest tuning cannot move the golden. The 1-3 `balance_ticks == null` guard is now a PERMANENT invariant: it never fires in a normally started match, and it stays.

**Golden record.** `d3f42def...bcf7` -> `40b5a804...d613`, TWO causes, each sufficient alone: (1) `apply_balance` enters the golden path (fixed in-test `_golden_config`); (2) the recorded intent sequence widened from 6 movement-only ticks to 24 ticks exercising attack, one chain, roll (as a recovery roll-cancel), and block — the golden now guards transition determinism. `test_recorded_sequence_exercises_all_transitions` pins the exact p1/p2 `action_state_changed` sequences, so the recorded sequence can never silently degrade back to guarding movement only.

**Authoring audit (permanent).** `test/state/test_balance_authoring.gd` (ca967b7) audits the REAL `data/balance/balance_config.tres`: every action `*_seconds` field (attack windup/active/recovery/chain window, deflect window, roll iframe/duration) must be > 0.0 — the 1-3 phase mechanism degenerates on 0-tick phases, so zero-authored values are defects, not tuning — and `attack_chain_length >= 1`. `stun_seconds` EXEMPT (data-only) until OPEN decision (a) resolves; the exemption is stated in the test.

**NEW OBSERVATION SEAM (locked) — `match_runner.connect_hero_action_state_changed(slot, callback)`.** THE sanctioned channel for observing hero action transitions from outside the state layer: the runner wires the subscription to the owning state object's D5 queued signal; consumers never hold a MatchState handle. HUD/visual stories (E2, 1-10) must consume this seam, not invent their own. Obligation for its FIRST consumer **[RETIRED 2026-07-24 — story 1-3c, d7d600c, via `Invariant.check`; see Session 2026-07-24 — Story 1-3c close-out]**: add an assert that `slot` is 0 or 1 — currently any slot != 0 silently maps to p2. Proven live by `test/integration/test_live_attack.gd`: simulated p1 attack press -> IDLE -> ATTACKING observed via the seam in the real scene.

**DEBT B status.** Still deferred, untouched by 1-3b: no mid-match reload trigger exists, so `reload()` keeps its cached-resource behavior. Both DEBT B halves (CACHE_MODE_IGNORE + reload event in the replay stream) still land together with the first story that introduces a live reload trigger.

---

## Session 2026-07-24 — Story 1-3c close-out

**Seam first-consumer obligation RETIRED.** The slot guard landed in `connect_hero_action_state_changed` via `Invariant.check` (X1 — export-surviving, deliberately not a bare `assert`; d7d600c). The debug state overlay is the seam's first live consumer, proven end to end by `test/integration/test_debug_overlay.gd` observing ONLY the overlay's `Label.text` — never state, never runner privates.

**FIRST HANDS-ON PLAYTEST of the project (2026-07-24, Matko).** All 1-3 transitions tracked correctly in live play: single attack (swing 0 -> IDLE), chain (swing 0 -> swing 1), recovery roll-cancel (ROLLING, counter reset), block on both slots independently with no cross-wiring. Timing at current authored values feels adequate — final judgment deferred until animations land.

**E2 fence restated.** The real HUD (E2) consumes the seam; the overlay is a THROWAWAY debug tool, deletable or replaceable when the HUD lands — E2 stories must never copy its internals.

---

## Session 2026-07-24/25 — Story 1-4 readiness gate (operator decisions)

Readiness gate on `1-4-stamina-economy.md` (authored 2026-07-22 in the original batch, before 1-3 / 1-3b / 1-3c landed) returned **NOT READY** — eight blocking findings, all resolved by operator decision (Matko, D1–D9) and applied to the story file. Recorded here: the entries that bind beyond 1-4.

**DEBT D — economy evaluator deferred.** Architecture D6 (data-driven `ResourceGenerationRule` + pure evaluator, game-architecture.md:360, :511, :754-760) is NOT implemented. 1-4 implements stamina spend/regen directly. Rationale: a rule schema shaped by a single continuous per-tick rule would be shaped by the least representative case; mana generation is event-driven (the `trigger` field exists for that reason) and orb generation is a third shape. TRIGGER: the first story introducing a SECOND resource rule — the mana hook in 1-5 — must decide whether to land the evaluator then or continue direct, and E3 (cards/mana) is the point where the full D6 form is expected. 1-5 and 3-4 currently reference the evaluator in their text; their gates must reconcile against this entry. D6 is deferred here, not abandoned.

**BalanceTicks widened (D3).** `BalanceTicks` is the home for load-time derived tick-domain values, not only duration→tick conversions — first instance: `stamina_regen_per_tick` (derived once per load from `stamina_regen_per_second` and `TimingWindow.TICK_HZ`), read inline via `ms.balance_ticks.stamina_regen_per_tick` per CONSTRAINT C, which forbids caching a reference to the `BalanceTicks` object, not storing derived values inside it. The `balance_ticks.gd:10-11` header comment is amended in 1-4 to state the widened role.

**`action_rejected` seam obligation (D5).** The signal is owned by `HeroState` (declared next to `action_state_changed`), emitted through the D5 queued mechanism; 1-4 builds NO runner seam — there is no consumer yet. The FIRST consumer (1-10) must receive a `connect_hero_action_rejected` seam mirroring `connect_hero_action_state_changed` (match_runner.gd:61-67), and must not reach through `_match_state`.

**Basic attack stays FREE (GDD-affirming).** A proposal to route attack through the stamina deduction path was raised at this gate and rejected: gdd.md:139 and the resource table at :319 list Roll, Deflect, Unblockable Initiation and Unblockable Defense as the stamina consumers, and 1-5's mana hook makes the free basic attack the generator — gating it would lock the poorest player out of their only income and invert P2. The GDD was not changed. Recorded so the proposal is not re-raised.

**Stamina playtest visibility deferred.** 1-4 ships with no stamina readout; the debug overlay is NOT extended to show it. Implementation is proven headless, and the player-facing readout is E2 HUD territory consuming the observation seam. Raised twice at this gate and deliberately deferred both times.

**apply_balance() refill on live reload (D9 consequence, 1-4 review round).** D9 sets current stamina to the authored maximum after every `apply_balance()`, and `apply_balance()` is BOTH the match-start injection and the X3 live-reload seam — so a mid-match balance reload resets both players' stamina to full, unlike in-flight timing windows, which survive a reload (the 1-1 reload principle). Accepted deliberately in 1-4 and pinned by `test_mid_match_reload_refills_stamina_to_max`; story 3-1, which separates match-start injection from reload injection, must reconcile this when it splits the seam.

---

## Session 2026-07-25 — Story 1-4 close-out

**What landed (d253efc).** Stamina regen: a fixed per-tick amount (`BalanceTicks.stamina_regen_per_tick`, derived once at load) plus a post-spend delay window, BOTH advancing in `advance()` step 2 — `StaminaPool.tick_timers()` runs alongside the hero windows, so an authored delay of N ticks suppresses exactly N ticks starting with the spend tick, and step 5 only reads the advanced result. ONE deduction path in the step-3 evaluation, roll only: basic attack is FREE (GDD-affirming, see the readiness-gate entry) and BLOCKING entry is free — block costs time via the D6 regen suppression, the only state-based suppression. Zero-stamina lockout is a PRECONDITION on the transition evaluation: the rejected edge returns false and falls through to the next `INPUT_PRIORITY` candidate in the same tick, with a queued `action_rejected(action, reason)` from `HeroState` even when a lower-priority press fires; the 1-3 capped-chain reject stays silent. D9 start-full: every `apply_balance()` sets stamina to the authored maximum — the live-reload consequence is already recorded above ("apply_balance() refill on live reload", 8814faa) and is not restated here.

**Golden record.** `40b5a804...d613` -> `871f8132...2a5c`, ONE re-baseline, TWO causes named separately, landed in d253efc: (1) SNAPSHOT SHAPE — `StaminaPool.to_snapshot()` gained the regen-delay window (a mid-count window excluded from the snapshot would be a determinism/replay hole, D8); (2) `_golden_config` now AUTHORS real stamina values (regen 60/s, delay 3 ticks, roll cost 15) so the golden sequence exercises spend, the delay window, and regen — the t17 roll leaves 25 of 40, the delay covers t17–t19, regen runs t20–t24 leaving 30.0, MID-REGEN at t24 so the hashed final state encodes both the spend and the regen. `test_golden_sequence_exercises_stamina_spend_and_regen` pins dip, rise, mid-regen, and the exact arithmetic.

**Obligation status after 1-4.**
- **DEBT D — LIVE.** The D6 economy evaluator stays deferred; 1-4 implemented spend/regen directly, as decided at the gate. TRIGGER unchanged: the 1-5 mana hook must decide evaluator vs continued direct implementation.
- **BalanceTicks widening — first instance now in code.** `stamina_regen_per_tick` exists in `balance_ticks.gd`, and the header states the widened role (load-time derived tick-domain values, not only duration→tick conversions).
- **`action_rejected` 1-10 seam — LIVE, not retired.** The signal exists and is emitted; there is still NO consumer and NO runner seam. 1-10 must add `connect_hero_action_rejected` mirroring `connect_hero_action_state_changed` and must not reach through `_match_state`.
- **CONSTRAINT C — intact.** Every 1-4 balance read (`roll_stamina_cost`, `stamina_regen_delay_ticks`, `stamina_regen_per_tick`) is inline at the moment of use; pinned by the reload test that swaps cost, rate, and delay in one `apply_balance()`.
- **DEBT B — untouched, still deferred.** No mid-match reload trigger exists yet; both halves (CACHE_MODE_IGNORE + the replay reload event) still land together with the first story that introduces one.

**PLAYTEST GAP.** Unlike 1-3c, 1-4 got NO hands-on validation: the story deliberately ships no stamina readout ("Stamina playtest visibility deferred", above — raised twice, deferred twice). The economy is proven headless only. The first FELT validation of regen rate, delay, and roll cost arrives with the E2 HUD consuming the observation seam; tuning judgments about whether the authored numbers feel right are therefore still unmade.

---

## Session 2026-07-25 — Story 1-5 readiness gate (operator decisions)

Readiness gate on `1-5-basic-attack-chain.md` (authored 2026-07-22 in the original Set B batch, before 1-3/1-3b/1-3c/1-4 landed) returned **NOT READY** — eight blocking findings (B1–B8) plus seven notes (N1–N7), all accepted and resolved by operator decision (Matko) and applied to the story file. Recorded here: the two entries that bind beyond 1-5.

**DEBT D — RESOLVED at its committed trigger: 1-5 implements mana accrual DIRECTLY; evaluator extraction deferred with E3 as the committed trigger.** The 1-4 gate entry made the 1-5 mana hook the decision point ("evaluator vs continued direct"); the decision is **direct** — one mana-generation path (the analog of 1-4's single stamina-deduction path), gated on the **injected** `FeatureFlags.melee_mana_generation` (state never reads the service; the runner injects once at match start — first flag consumer in state, so 1-5 builds the seam; injected flags are EXCLUDED from `to_snapshot()`, config-not-state, the 1-2 camera-basis analog), per-hit amount read inline as `ms.balance.melee_hit_mana` at the moment the hit is confirmed (CONSTRAINT C). Rationale unchanged from the 1-4 entry: a rule schema extracted before its representative cases exist would be shaped by the least representative one; E3 (cards/mana) is where the full D6 form is expected, and extraction from two landed direct implementations (1-4 stamina, 1-5 mana) is the committed E3 trigger — deferred, not abandoned. Consequences recorded: the 1-5 story text is cleaned of every evaluator reference (`stories-manual-e1.md` E1.S5 item 3's evaluator framing is superseded by this entry; the manual is not edited); story 3-4's evaluator references reconcile at its own gate, not now; ONE new `BalanceConfig` field `melee_hit_mana` (per-event amount, NOT tick-domain, so not on `BalanceTicks`); **no `max_mana`** — the mana cap stays the runner's constructor value until 3-1, as the runner comment records. The GDD epic table (`gdd.md:411`) places melee-hit mana under E3 — pulling the accrual forward into E1 **flag-gated** (flag default ON) is the deliberate resolution, noted so it reads as a decision, not an oversight; no GDD edit.

**DECISION (locked) — movement during attack: `attack_move_speed_multiplier`, first authored value 0.0 (full root).** Attacking constrains movement via a new `BalanceConfig` field `attack_move_speed_multiplier` (scalar, not tick-domain), applied to the hero's movement resolution in `_resolve_movement` while `action_state == ATTACKING`, **uniform across windup/active/recovery**, read inline at the moment of use; it scales the resolved velocity only — the facing update is untouched (facing remains raw intent-space, consumed by nothing in 1-5). Rationale: attack commitment is the core of the soulsborne half — a swing with no movement risk has no whiff-punish, and P2 ("aggression is economy") requires aggression to be priced; the knob-not-code shape lets playtest move between rooted / slowed / free purely in data. **Per-phase multipliers are explicitly out of scope until animations exist.** This resolves the **ATTACK half** of the 1-3 deferred action×movement coupling (`1-3-hero-action-state-machine.md:46`, `match_state.gd:75`); the **ROLL half remains assigned to 1-9** — the deferral is re-homed, not orphaned. Golden consequence, recorded ahead of the dev pass: if the recorded determinism sequence holds movement input during a swing (it currently does — the `MOVES` cycle is nonzero on swing ticks), movement-root is a **separately named re-baseline cause** alongside the 1-5 snapshot-shape and authored-values causes.

---

## Session 2026-07-25 — 1-5 close-out

**What landed (513c70e).** Implementation exactly as gated: **DEBT D resolved DIRECT at the 1-5 trigger** — ONE step-5 mana-generation path (`_generate_mana`, the `_regen_stamina` policy-seat analog), per-hit amount read inline as `ms.balance.melee_hit_mana` at the moment the hit is confirmed (CONSTRAINT C), gated on the **injected** `FeatureFlags.melee_mana_generation` (runner injects once at match start; state never reads the service; flags excluded from `to_snapshot()`); evaluator extraction **re-triggers at E3**. Contact intake seam `push_contact` (plain three-int facts, drained deterministically in step 4), per-swing dedupe keyed by a monotonic `attack_index` with the exactly-one-tick-past-active-close grace (both boundary sides pinned, snapshotted — the one snapshot delta), derived `is_hitbox_active`, B6 movement root applied in `_resolve_movement` (velocity only, uniform across phases, authored 0.0), balance +2 fields (`melee_hit_mana`, `attack_move_speed_multiplier`) with the authoring audits extended, authored damage lowered 10.0 → 6.0 (GDD band). Suite 85 → 102 state tests / 298 → 361 assertions + 5 integration, all green.

**Golden record.** `871f8132…2a5c` -> `39564e83…5353`, ONE re-baseline, **TWO** causes named separately, landed in 513c70e: (1) SNAPSHOT SHAPE — `HeroState.to_snapshot()` gained `swing_dedupe` (monotonic counter + live records; D8); (2) `_golden_config` now AUTHORS combat-economy values (damage 10% of max HP, `melee_hit_mana` 12) with in-test flags, and the sequence feeds ONE synthetic confirmed hit at t5 — P2 ends 108/120 HP, P1 ends 12 mana, pinned by `test_golden_sequence_exercises_hit_damage_and_mana`. **The gate-predicted cause (c) — movement root — was empirically verified a NON-CAUSE:** the sequence does hold nonzero movement input on ATTACKING ticks (1–4, 6–16) and the multiplier does root velocity on all of them, but the hash is identical with multiplier 0.0 vs 1.0 — the golden hashes only the FINAL (t24) snapshot, velocity is overwritten every tick, position is actor-owned (F1, never in state), and the run ends IDLE. The prediction did not survive measurement; the finding is recorded in the `test_determinism.gd` GOLDEN header and the story Dev Agent Record.

**Review R1.** `push_contact` now ENFORCES its documented programming-error stance via `Invariant.check` (a plain static class, no autoload): slots must be 0 or 1, and attacker ≠ target — a self-contact fact is malformed in 1v1 (**operator decision**; 1-7's gate revisits if real gathering ever needs otherwise). Before the fix the resolution ternary silently mapped every slot != 0 to p2.

**NAMED DECISION (previously unstated in the story) — step-4 damage ignores defenses that later stories own.** 1-5's contact resolution deliberately ignores `roll_iframe` i-frames and BLOCKING mitigation: the roll_iframe × contact interaction belongs to **1-9**, block mitigation (the `block_damage_multiplier` consumer) to **1-8**. Until those land, a confirmed contact damages a rolling or blocking target at full value. The 1-5 story text never named this exclusion (fence check at review confirmed zero mentions); recorded here so 1-8/1-9 inherit it as a decision, not an accident.

**Authored placeholder.** `melee_hit_mana = 8.0` — the story mandates the field and the >0 audit but names no number; first-guess placeholder (10 confirmed hits fill the 80 constructor cap), TBD in playtest like every 1-1 value.

**PLAYTEST GAP — continues (1-4 pattern) and WIDENS.** The contact layer has no live-play path until 1-7 lands runner gathering (nothing calls `push_contact` outside tests) and no readout until the E2 HUD — the combat economy (damage, dedupe, mana faucet, movement root) is proven headless only. Every feel judgment (damage band, mana rate, full root) is still unmade.

**1-7 obligations born here.** Real runner-gathered facts MUST enter through `push_contact` — the single path, never a second one — stamped with the attacker's `attack_index` at gather time; the `hit_landed` signal (with its presentation consumer) is 1-7's; X5 recording of contact facts alongside intents lands with the real runner feed.

**Process note.** The dev-pass commit was first authored as c51115d with code and the story record bundled; split into 513c70e (code+tests) + 9386f37 (story record) per CLAUDE.md "docs and code never share a commit" — operator path-list error, agent flag correct.

---

## Session 2026-07-25 — Story 1-6 readiness gate (operator decisions)

Readiness gate on `1-6-training-dummy-null-controller.md` (authored 2026-07-22 in the original Set B batch, before any E1 code existed) returned **NOT READY** — six blocking findings (B1–B6) plus seven notes (N1–N7), all accepted and resolved by operator decision (Matko) and applied to the story file. Recorded here: the entries that bind beyond 1-6.

**DECISION — debug reset RELOCATED from 1-6 to 1-7.** Rationale: until 1-7 lands the live `push_contact` feed, nothing in live play can damage the dummy — a 1-6 reset would be another headless-only artifact (the 1-4/1-5 playtest-gap pattern). Reset semantics AND its entry path (intent-carried event vs other — the questions the gate raised: a mutation outside `advance()` bypasses the D2 ordered dispatch; an unrecorded reset event is an X5 replay hole; `src/ui/debug/` is architecture-pinned to "no state mutation"; no `debug` flag carrier exists on FeatureFlags) are decided at the **1-7 gate** with the live damage loop in view — not invented at 1-6 dev time. The stories-manual E1.S7 item-4 wording ("the debug reset from E1.S6") is satisfied by 1-7 carrying its own reset; **the 1-7 gate must reconcile that wording** (the manual is not edited — 1-5 precedent).

**CONSTRAINT (pinned) — `attack_index` survives any future reset.** It is monotonic for the life of the match per the 1-5 dedupe contract (`hero_state.gd:72-76`): resetting it would let stale contact facts collide with reused dedupe keys. Any future reset story (1-7's or later) must leave it untouched; "clear action state" never includes it.

**AC5 split (B4).** The original "extend the determinism regression to two populated slots" was already satisfied — the golden has fed fixed intent lists to BOTH slots since E0/1-3b (`test_determinism.gd`: P1 attack/chain/roll-cancel, P2 block, movement pairs for both; key-order-independence guardrail present) — and as written invited a pointless sequence re-record. Split into: **(a)** the existing two-slot golden HOLDS, hash unchanged `39564e83…5353` — the golden path bypasses controllers, so 1-6 predicts NO movement; measured at dev time, never trusted (the 1-5 cause-(c) lesson); **(b)** a NEW non-golden headless test — N ticks of `NullController` intents leave the slot IDLE with velocity zero (position is actor-owned, F1). The golden sequence is NOT re-recorded.

**Label cleanup (B5).** The story's two "DECISION (a)" references are replaced by citing **amendment A3** (game-architecture.md v1.2, commit d6ab666) as the settled authority for dummy identity (a NullController-driven slot, not a type). Reason: the label predates the 1-2 rename of seam choices to SEAM CHOICE and now collides with locked **DECISION A** (the unrelated 1-2 root-rotation decision) — same-looking name, different decision. No new label invented. 2-1 ("DECISION (b)") and 2-3 ("DECISION (a)") carry the same stale labels; their own gates' business.

**Repo hygiene (B6).** `src/actors/dummy/.gitkeep` is still tracked in git — the vestigial folder A3 removed from the architecture Directory Tree persists in the repo. Deletion assigned to the **1-6 dev CODE commit** (docs and code never share a commit).

**Docs debt (minor).** The architecture Directory Tree lists keyboard/gamepad/scripted/replay controllers but not `null_controller.gd`, though A3's amendment text names `NullController` explicitly. A tree omission, not a conflict — fold into the next architecture amendment; no edit now.

**Default-swap note (N7).** 1-6 SWAPS a default rather than adding a slot: P2 has been a live `KeyboardController("p2")` slot since E0 (the 1-3c hands-on playtest exercised both slots), and after 1-6 the default scene is P1 human vs P2 dummy — two-human play returns only via the new config point until 2-3 realizes the swap-back. A deliberately chosen default, recorded so it reads as a swap, not an addition.

---

## Session 2026-07-25 — 1-6 close-out

**What landed (873f349 code + 9bb5ac8 story record).** Implementation exactly as gated: `NullController` (`src/controllers/null_controller.gd`, a trivial `Controller` subclass — `sample()` inherits the base fresh-empty-`InputIntent` null behavior, adding nothing on purpose); **THE single per-slot controller-kind config point** in `match_runner.gd` (`ControllerKind` enum + `slot_controller_kinds` export + the `_make_controller()` factory — the ONE place a kind becomes a concrete `Controller`, with a size `Invariant.check`), the seam **2-3** (swap slot 1 `NULL → KEYBOARD_P2`) and **E7** (scripted kind) consume as one-line changes; **P2 default = `NULL`** (the training dummy). The vestigial `src/actors/dummy/.gitkeep` was removed in the code commit (A3's folder). No new `PlayerState`/actor/rig/scene, no `src/state/` change — the second slot has existed and been driven since E0, so 1-6 SWAPS P2's driver, it does not add a slot.

**Golden — the gate's NONE prediction was CONFIRMED by measurement.** Hash unchanged `39564e83…5353`, `test_determinism.gd` untouched (no sequence re-record): the golden path feeds fixed intents straight to `advance()` and bypasses controllers, so the P2 default-swap cannot reach it. Contrast with the 1-5 cause-(c) lesson — predictions get MEASURED either way; this one held rather than dying. AC5b's new non-golden `test_null_controller.gd` proves the null-driven slot stays IDLE with zero velocity across 30 ticks (position is actor-owned, F1, never in state).

**Invariants + suite.** F1 (one `_physics_process`), D3(a) (`Input.*` only in controllers — `NullController` reads none), D3(b)/A2 (state purity) all green with `NullController` live; the 5 integration tests instantiate the runner scene, so they exercise the real config-point factory and the P2-dummy default (`test_live_attack`/`test_debug_overlay` confirm the swap doesn't break the live scene). Suite 102 → 104 state tests / 361 → 487 assertions + 5 integration, all green; the operator independently ran the state harness (direct `godot` invocation) and confirmed 104/487 PASS.

**R1 (story-record correction).** The record first cited a STATIC count ("12 assertions") for `test_null_controller.gd`, but its second test is loop-driven — 6 + 30×4 = **126 runtime assertions**, exactly the 487−361 suite delta. Corrected in both the File List line and the AC 5b note (commit 9bb5ac8). Lesson: report assertion counts from the harness output, not from reading the file.

**PLAYTEST GAP — unchanged in kind.** The dummy slot is inert BY CONSTRUCTION (empty intents) and proven headless only; its live-play meaning arrives with **1-7** (the live `push_contact` damage feed — something to actually hit the dummy with) and **E2** (the HUD readout). The default scene is now P1 human vs P2 dummy; two-human play returns via the config point at 2-3.

**Pointer.** Reset semantics + entry path remain a **1-7 gate** decision (relocated at the 1-6 gate); the `attack_index`-survives-reset CONSTRAINT stands (pinned in the 1-6 gate session above).

---

## Session 2026-07-25 — Story 1-7 readiness gate (operator decisions)

Readiness gate on `1-7-contact-pipeline-damage-hp-death.md` (authored 2026-07-22 in the original Set B batch, before `push_contact`, the dedupe layer, `_check_resolution`, and the 1-6 reset relocation existed) returned **NOT READY** — seven blocking findings (B1–B7) plus seven notes (N1–N7), all accepted and resolved by operator decision (Matko, rulings D-1..D-4 + the B5 affirmation) and applied to the story file the same day. Recorded here: the entries that bind beyond 1-7.

**DECISION D-1 (locked) — debug reset is ROUND-SCOPED.** The reset restores ALL slots' HP to max and clears the `_round_over` latch; **nothing else** — pools, dedupe records, running windows, and positions are untouched (position is actor-owned, F1; a live hero mid-swing swings on through a reset). A DEAD hero (see D-3) returns to IDLE on reset — a "clear action state" entry which, per the pinned 1-6 contract, **NEVER touches `attack_index`** (`hero_state.gd:72-76`; monotonic for the life of the match — restated, not reopened). The reset refills NO pool: any "refill to max" on mana would poke the constructor-owned cap, which is 3-1 territory and stays un-absorbed. **Consequence, deliberately accepted:** once the latch can clear, `round_ended` fires once **PER DEATH**, not once per match — the "exactly once" pin (`test_match_state.gd:36`) is extended accordingly in 1-7's test plan.

**DECISION D-2 (locked) — reset entry path is INTENT-CARRIED (option a).** `InputIntent` gains a `debug_reset` bool (default false); `KeyboardController` samples it from a prefix-mapped Input Map debug action (`p1_`/`p2_` symmetric); `advance()` applies the round-scoped reset when any slot's intent carries it. Rationale: the only option satisfying D2 (mutation inside `advance()`) AND X5 **by construction** — intents ARE the recorded stream, so the reset replays for free once the recorder exists; no new mutation surface, no second recorded-event class (no DEBT B widening), no `src/ui/debug/` involvement (that zone stays no-mutation). **DELIBERATE EXCEPTION, recorded so it reads as a decision:** the debug action is **NOT gated behind a FeatureFlags flag** — it is an operator affordance, not a gameplay path; a conscious exception to the 1-5 B2 "behind a flag" precedent. No `debug` field is added to `FeatureFlags`.

**DECISION D-3 (locked) — death terminal state is `ActionState.DEAD` (option a).** A new enum value with an **empty transition-table row** (accepts no table edges), entered ONLY by the step-8 resolution (a non-table path), exited ONLY by the D-1 reset. Presentation learns of death through the locked observation seam (`action_state_changed`). The STUNNED-style inbound-edge guard test is extended to DEAD. The post-death fact-drop gates on `target.action_state == DEAD` — facts on a dead target are dropped before resolution. **Defect discovered at this gate, closed by that drop:** `_resolve_contacts()` consults neither `_round_over` nor target liveness, so post-death confirmed hits still **generate mana for the attacker** (`match_state.gd:283-292` → `:300-305`) — corpse-farming the flywheel; live until 1-7 lands the drop. STUNNED itself stays data-only; OPEN decision (a) stays open.

**DECISION D-4 — X5 contact-fact recording RE-HOMED (moved, not dropped).** The 1-5 close-out obligation ("X5 recording of contact facts alongside intents lands with the real runner feed") cannot be satisfied in 1-7: no recorder exists (`src/systems/` has no `intent_recorder.gd`; the X5 path's first real exercise is scheduled at E2.S3, stories-manual-e2.md:114). The obligation **MOVES to the story that lands `IntentRecorder`** — E2.S3 or a dedicated X5 story, whichever lands the recorder; that story's gate must pick it up alongside the intent stream and the DEBT B reload events (all one stream contract). 1-7 owes only what is already true: contact facts remain plain recordable three-int data entering one seam (`push_contact`). The derived-not-recorded alternative (replay regenerating facts through physics) was rejected — it contradicts the recorded 1-5 decision (`match_state.gd:49-51`) and would hang replay soundness on Jolt bit-determinism.

**B5 AFFIRMED — the `push_contact` `attacker != target` invariant stays STRICT.** Both heroes instantiate the same `hero.tscn`, so naive gathering returns the attacker's own hurtbox and would crash the R1 invariant (`match_state.gd:150-151`). The runner **filters self-overlaps at gather via an identity check** (the overlapping area's owner != the attacker) — fact selection, not rule evaluation, so "actors report, state decides" holds. No per-slot layer reassignment. This closes the revisit clause the R1 entry reserved for this gate.

**E1.S7 item-4 reconciliation.** The stories-manual wording ("the debug reset from E1.S6") is satisfied by **1-7 carrying its own reset** (AC 5 of the rewritten story), per the relocation decided at the 1-6 gate. The manual is not edited (1-5 precedent).

**Scope corrections applied to the story (drift findings).** AC3 rescoped: the 1-5 step-4 resolution (damage/dedupe/mana) is fixed substrate — 1-7's delta is the MatchState-owned `hit_landed(attacker_slot, target_slot, damage, target_hp)` + a `connect_hit_landed` runner seam (the `connect_hero_action_state_changed` pattern) with the throwaway `DebugStateOverlay` as first consumer (E2 fence restated). AC4 rewritten to the three real deltas against the existing `_check_resolution` substrate: `ActionState.DEAD`, the post-death fact-drop, and declaring `round_ended` on `EventBus` with the RUNNER relaying `MatchState.round_ended` → EventBus (state never touches an autoload). AC2 names `push_contact` as the SOLE intake with the `attack_index` stamped AT GATHER time. The iframe/block fence (NAMED DECISION, 1-5 close-out) is now stated in the story — 1-7 edits step 4, so an unfenced dev pass risked resolving 1-8/1-9 scope by accident.

**Golden prediction: NONE — to be measured at dev time in both directions, never trusted** (1-5 cause-(c) / 1-6 NONE precedent). Signals are not hashed; the DEAD enum value adds no snapshot shape; fact-drop and reset never trigger in the recorded sequence; `InputIntent` is excluded from the snapshot, so `debug_reset` cannot move the hash; the golden path bypasses the runner, so gathering cannot reach it. No sequence re-record.

---

## Session 2026-07-26 — 1-7 close-out

**What landed (80e52f1 code+tests / 1090cd5 story record / 93ec2a9 project-context docs / 76e20b0 board+status).** Implementation exactly as gated — rulings D-1..D-4 and the B5 affirmation implemented as ruled, nothing reopened (see the readiness-gate session above for the rulings themselves): Hitbox/Hurtbox `Area3D` pair with the named `3d_physics` layers authored from zero; runner step-2 direct-query gathering (gather-time `attack_index` stamp, identity self-filter, `push_contact` the sole intake — the strict invariant untouched); MatchState-owned `hit_landed` + the `connect_hit_landed` seam with the throwaway overlay as first consumer; `ActionState.DEAD` (step-8 entry only, input-proof row, guard test extended) + the post-death fact-drop closing the corpse-mana-farming defect; `EventBus.round_ended` declared with the runner relay; the round-scoped intent-carried debug reset (no flag gate, per the recorded exception). Full detail in the story Dev Agent Record.

**Golden — the NONE prediction CONFIRMED by measurement, TWICE.** Hash unchanged `39564e83…5353` after the dev pass AND again after the R1 facing change; no re-baseline, no sequence re-record. The measure-both-directions discipline continues (contrast the 1-5 cause-(c) prediction, which died under measurement; this one held both times it was put to the test).

**Suite.** 104 → 115 state tests / 487 → 543 assertions, integration 5 → 6, all green; the operator independently ran the state harness and confirmed 115/543 PASS.

**NEW LOCKED CONTRACT (review R1, operator decision) — `HeroState.facing` is WORLD-SPACE planar.** It previously stored the raw camera-space intent while velocity was world-space; 1-7's hitbox yaw became the field's FIRST consumer and treats it as world-space — inert only while every rig basis is identity, a live defect the moment a camera rig carries yaw. `_resolve_movement` now assigns `Vector2(world_dir.x, world_dir.z)` under the unchanged zero-guard; `HeroActor.drive()` was NOT changed (its atan2 mapping was already correct for a world-space facing). Golden-neutral: the two expressions are bit-identical under an identity basis. This RESOLVES the 1-5 B6 parenthetical ("facing remains raw intent-space, consumed by nothing in 1-5") — the revisit trigger was the first consumer, it fired here, and it is closed. No document described facing's space before this entry, so this entry is the contract's canonical home; it joins `null_controller.gd`'s Directory Tree omission in the queue for the next architecture amendment (neither triggered one in 1-7).

**Coverage-shape lesson (named so it is not relearned).** The suite was green at every point and structurally could NOT have caught R1: the golden sequence and the live scene both run at an identity basis, so a camera-space/world-space mismatch is invisible to tests that only exercise the identity case. The defect was found by reading, not by running. The new yaw-basis facing pin (`test_camera_basis.gd`) and the integration AIM phase now exercise the non-identity case.

**Other review findings.** R3 (test-count miscount in the story record) and R4 (a vacuous assertion — the "all slots restored" HP check could not fail because that slot was never damaged) both fixed; R2 not fixed by design — see the named gap below.

**NAMED GAP — DEAD-slot residuals. Deliberately not fixed; TRIGGER: the first story in which a human-driven slot can die.** Two mirror-image residuals, both unreachable in E1 live play (only the NullController dummy can die, and it neither moves nor swings): (1) a DEAD hero's `_resolve_movement` still runs — a dead human-driven hero could walk; (2) a hero that dies mid-swing keeps its in-flight active window, so a live gather could still credit a corpse with damage and mana — the attacker-side mirror of the target-side corpse-farming defect this story closed. The triggering story owns both.

**PLAYTEST GAP CLOSES — first hands-on validation since 1-3c** (1-4, 1-5, and 1-6 all recorded proven-headless-only). Confirmed live: hits render on the throwaway overlay's HitLabel and chip exactly the authored damage; seventeen hits kill the dummy; the debug reset revives it at full HP and the round re-arms; a swing at nothing produces nothing. Two findings:

- **ATTACK COMMITMENT reads as paralysis — root-motion constraint named.** `attack_move_speed_multiplier` 0.0 (1-5 ruling B6) is correct and STAYS — commitment is the genre floor. What is missing is that soulslike characters still displace during a swing because the ANIMATION moves them (root motion), not the input. Constraint for whoever implements it: true root motion would have an `AnimationPlayer` move the `CharacterBody3D` — presentation deciding position, which breaks F1 and makes replay depend on animation sampling. The sanctioned form is an authored lunge displacement in balance data, applied by the STATE layer as a velocity curve during the swing, with the animation matching it visually. Deferred, not dropped.
- **FACING IS INVISIBLE.** The hero mesh is a symmetric box, the root never rotates (DECISION A), and nothing rotates the `Mesh` child — only the Hitbox is yawed, and it does not render. Melee reach is roughly 0.9 units in front of the body, so aim matters, yet the player has zero directional feedback; every combat playtest is compromised until this is fixed, and the manual facing check could not be performed at all (the automated integration AIM phase covers it). DECISION A already sanctions body rotation on the child mesh — no story has done it. Recommended: a small dedicated story on the 1-3c pattern (make the state observable so playtesting means something), ideally before 1-8 — block/deflect tests even worse without a visible facing.

**Docs.** The collision layer/mask convention is now in `project-context.md` (93ec2a9). One sentence in it is a CONVENTION, not a description, and binds future stories: "The next story that needs a layer starts at layer 4 and names it here."

**Pointer.** The X5 contact-fact recording obligation remains RE-HOMED (gate D-4) to the story that lands `IntentRecorder`, which takes it together with DEBT B's reload events as ONE stream contract.

---

## Session 2026-07-26 -- Story 1-7b authored + readiness gate

**Mandate.** The 1-7 close-out playtest finding (previous session): facing is INVISIBLE in live play -- the hero is a symmetric box, the root never rotates (DECISION A), nothing rotates the `Mesh` child, and the only yawed node (the Hitbox) does not render. Every combat playtest is compromised until it lands, and 1-8 (block/deflect) is the most aim-sensitive story yet. Story `1-7b-visible-facing` authored on the 1-3c make-state-visible model; UNLIKE 1-3c it is NOT throwaway -- DECISION A already names the child mesh as the permanent home for body rotation; only the marker geometry is placeholder.

**Operator pins (authored into the story as ACs, not re-derivable).** (1) SINGLE YAW SOURCE: the mesh uses the exact facing-to-yaw mapping the Hitbox already uses in `HeroActor.drive()` -- one computation, two assignments, never a second atan2; the visible mesh is the truthful display of hitbox yaw and cannot diverge from it. (2) A mandatory ASYMMETRIC MARKER as a child of the `Mesh` node (a rotated symmetric box is still invisible), authored directly in `hero.tscn`, no new assets. (3) PRESENTATION-ONLY with golden prediction NONE -- hash measured both directions, must be identical, never re-baselined; no `src/state/`, snapshot, Input Map, `project.godot`, or autoload changes. (4) DECISION A holds: the root never rotates; `test_root_rotation_isolation.gd` stays green; root rotation stays deferred DECISION B.

**Readiness gate (same session, report-only).** Verdict **READY** -- zero blocking findings, four advisories (N1 do not rotate Collision/Hurtbox; N2 integration test derives expected yaw from the pressed direction under the identity basis, mesh-yaw == hitbox-yaw is the primary pin; N3 .uid via editor scan for any new test file, verify the scan leaves `hero.tscn` alone; N4 below). All four story assumptions verified against `src/` by content; baseline measured live at gate time: 115 state tests / 543 assertions PASS, golden `39564e83...5353` confirmed. Promoted backlog -> ready-for-dev.

**N4 -- comment-hygiene queue entry.** `test/state/test_contact_resolution.gd` carries a stale pre-R1 comment ("facing updates from raw intent") -- only true under an identity basis since the world-space facing contract (1-7 review R1). The assertion is valid (the test runs at identity); the wording is stale. Queued for a future comment-hygiene pass; deliberately NOT touched in 1-7b (its fence keeps the state harness untouched).

---

## Session 2026-07-26 -- Story 1-7b close-out

**What landed (e125586 code+test / b2f4540 story record).** Implementation exactly as gated: `HeroActor.drive()` hoists the existing facing-to-yaw mapping into ONE local, assigned to BOTH `Hitbox` and `Mesh` -- one computation, two assignments, never a second atan2 (exactly one CODE occurrence of atan2 in `src/`, the hoisted `var yaw :=` line; the visible mesh is the truthful display of hitbox yaw and cannot diverge from it). `FacingMarker`: a `PrismMesh` sub-resource authored directly in `hero.tscn` as a child of `Mesh`, apex rotated onto local +Z (the hitbox reach direction) -- no new assets, no import pipeline. New integration pin `test/integration/test_visible_facing.gd` (+ editor-scan `.uid`): two real Input presses assert mesh yaw == hitbox yaw == the mapping of the pressed direction under the identity basis, root basis identity throughout, and yaw persistence after release. N1 respected (`Collision`/`Hurtbox` deliberately unrotated); DECISION A intact (`test_root_rotation_isolation.gd` green).

**Golden -- the NONE prediction CONFIRMED by measurement, both directions (the 1-6 rule: predictions are measured both ways, never trusted).** Hash `39564e83...5353` measured BEFORE the first edit and again AFTER the implementation -- identical; no re-baseline, no sequence re-record. State harness 115 tests / 543 assertions green both runs; all 7 integration tests green, run individually.

**Review: one finding, R1 (cosmetic, truth-in-record).** The story record's AC 1 grep claim overcounted -- corrected to exactly one CODE occurrence of atan2 in `src/`; the only other textual match is its own doc comment. No code change; the single-yaw-source contract holds.

**Operator smoke check PASSED -- the 1-7 "FACING IS INVISIBLE" finding CLOSES.** The marker visibly leads the body through all eight keyboard directions; orientation persists on stop; the dummy never turns; the marker is legible from the fixed camera. Live aim now governs damage -- facing away from the dummy in range deals nothing, facing it lands hits: the exact capability the story existed to create.

**360-degree facing is NOT a new obligation.** Eight-way facing is a KEYBOARD limitation, not a system one: facing is continuous (a world-space Vector2 through one atan2), and the state layer already accepts analog vectors (`test_analog_input_clamped_to_move_speed`). Full-360 facing arrives with analog input in story 2-2 (gamepad profiles). Nothing owed before then.

**Pointer.** The N4 comment-hygiene queue entry (previous session) remains OPEN -- deliberately untouched in 1-7b per its fence; still queued for a future comment-hygiene pass.

---

## Session 2026-07-26 — Story 1-8 readiness gate (operator decisions)

Readiness gate on `1-8-block-and-deflect.md` (authored 2026-07-22 in the original Set B batch, before any E1 code existed) returned **NOT READY** — five blocking findings: B1 (AC2/AC4 contradicted each other on WHEN deflect stamina is deducted, and the pay-at-entry reading priced block entry against the locked 1-4 ruling), B2 (the facing gate had neither a rule nor a data home), B3 (the contact-fact schema widening was unstated against the locked three-int `push_contact` contract), B4 (dedupe registration, mana, and `hit_landed` semantics for blocked/deflected outcomes were unspecified — and repeated per-tick gathering makes registration load-bearing), B5 (the hot-reload wording risked pulling DEBT B into scope). All resolved by operator decision (Matko, rulings R-D1..R-D7 + R-N2 + the R-B3/R-B5 pins) and applied to the story file the same day. Recorded here: the entries that bind beyond 1-8.

**R-D1 (locked) — deflect stamina: affordability PRECONDITION at block entry, SPEND at deflect landing; "one deduction path" reconciled.** At the BLOCKING transition, insufficient stamina means the deflect window never opens (`enter_block` gains a no-window path), `action_rejected(&"deflect", &"insufficient_stamina")` is queued, and block proceeds as plain block — **BLOCKING entry itself stays FREE; the locked 1-4 ruling is upheld** (block's cost remains regen suppression). The spend (`StaminaPool.spend()` with its delay stated explicitly) happens in step 4 when a contact resolves as a deflect. Reconciliation: `StaminaPool.spend()` is the single deduction MECHANISM; policy seats are per-consumer — roll in step 3, deflect in step 4. This is a NEW rejection shape — DEGRADE, not the 1-4 fallthrough: the block edge still fires, only the window is denied, and the rejection names `&"deflect"` because that is the thing denied. Soundness: stamina cannot change while BLOCKING (regen suppressed, no reachable spends), so the entry check guarantees the landing spend. The stale `match_state.gd` step-3 comment ("Deflect joins this path in 1-8") is amended at dev time.

**R-D2 / R-D3 (locked) — facing gate: `block_facing_arc_degrees`, gating BOTH outcomes.** New authored `BalanceConfig` field (Defense group), first authored value 180.0 (front half-plane), hot-tunable and audited. State compares the fact's world-space target-to-attacker direction against the target's own `HeroState.facing` (world-space since 1-7 R1) within +/- arc/2. Inside window AND facing -> deflect; outside window AND facing -> block (multiplier); NOT facing -> full damage regardless of window — no parry or block from behind. Tests gain a back-facing-inside-window case.

**R-D4 (locked) — outcome semantics.** Blocked AND deflected contacts BOTH register the swing-hit — one resolution per swing per target regardless of outcome; a resolved swing's later facts cannot re-resolve. A **blocked** hit is a CONFIRMED hit: reduced damage, `hit_landed` with the reduced amount, and the attacker earns full flat `melee_hit_mana` — **block deliberately does NOT touch the attacker's economy in E1**; the defender's economic counter is deflect only; economy tuning is E3 territory. A **deflected** contact is FULLY negated: no damage, no `hit_landed`, no mana. `deflect_landed(attacker_slot, target_slot)` is the only deflect signal — MatchState-owned (the `hit_landed` precedent), queued via D5, NO runner seam in 1-8: the first consumer is 1-10, which inherits the connect-seam obligation (the `action_rejected` precedent).

**R-D5 — OPEN decision (a) stays OPEN.** 1-8 ships deflect with NO attacker consequence: negation + mana denial + the `deflect_landed` cue hook. The STUNNED guard stays intact (zero inbound edges); `stun_seconds` stays data-only. The existing OPEN entry (Session 2026-07-22, "Attacker consequence on basic-attack deflect") satisfies the story's log-the-question task — the story REFERENCES it; nothing is duplicated and nothing is resolved.

**R-D6 — NAMED GAP trigger REINTERPRETED (cross-story contract from the 1-7 record, recorded now).** The DEAD-slot-residuals trigger "the first story in which a human-driven slot can die" is reinterpreted as **"the first story that SHIPS a human-driven-killable configuration" = story 2-3**. The live 1-8 block smoke check runs via a TEMPORARY flip of runner slot 1 to `KEYBOARD_P2` (exported array); the shipped default stays P2=NULL. The residuals (a dead hero can walk; a corpse mid-swing can be credited damage/mana) are explicitly ACCEPTED for supervised E1 smoke checks — this acceptance covers BOTH 1-8 and 1-9 (the roll playtest needs the same attacker on P1). Story 2-3 owns both fixes.

**R-D7 — architecture amendment queue stands untriggered.** 1-8 makes no architecture-doc edits; the queued items (world-space facing contract + `null_controller.gd` Directory Tree) remain queued. The four-field fact contract's canonical home is THIS decision log (D-4 supersession at close-out), not the architecture doc.

**R-N2 (locked) — deflect window judged at resolution WITH a +1 grace tick** (the dedupe-grace precedent, absorbing the same F1 one-tick fact lag): a contact physically inside the window's last tick, arriving one tick late, still deflects — authored `deflect_window_seconds` means what it says. Golden note (corrects the gate report): the recorded sequence's t5 fact models a t4 physics contact and the golden 4-tick window RUNS t1-t4, so under the grace tick that fact falls INSIDE and would resolve as a DEFLECT once the mechanics exist — not the report's "one tick outside / ordinary block".

**R-B3 pin — the contact fact widens to FOUR fields:** `[attacker_slot, target_slot, attack_index, world-space direction from target to attacker]`, computed by the runner FROM POSITIONS ONLY — the runner must NOT read `HeroState.facing` and must NOT compute a "relative angle" (policy stays in state; the arc comparison is step 4's). `push_contact` remains the SOLE intake; the new field is validated at the seam; the fact stays plain recordable data (X5), so the IntentRecorder story inherits four-field facts. **D-4's "three-int" wording is hereby noted as superseded; the full supersession is recorded at 1-8 close-out.**

**R-B5 pin — hot-reload meaning.** The deflect window's "tunable by hot-reload" means exactly: a mid-match `apply_balance()` call swaps `balance_ticks` and the NEXT `enter_block` picks up the new length; in-flight windows keep their duration (CONSTRAINT C / the 1-1 reload principle). Headless-proven via `apply_balance` (1-4 test precedent). NO live reload trigger, NO `CACHE_MODE_IGNORE`, NO recording changes — DEBT B stays re-homed to the IntentRecorder story.

**Audit deltas owed by 1-8 (R-N6).** Lift the `deflect_stamina_cost` exemption and assert > 0 (roll precedent — a free deflect unguards the economy); add `block_damage_multiplier` with bounds 0 < m < 1 (0.0 = free total negation that obsoletes deflect; >= 1.0 = no-op or self-harm); add `block_facing_arc_degrees` with bounds > 0 and <= 360. `deflect_window_seconds` is already covered.

**Golden prediction (R-N3): MOVES** — at most ONE re-baseline, separately named causes, measured in both directions, non-golden tests proven green first. Primary cause: exercised-path resolution change (the sequence already blocks t1-t5 with the fact at t5 — see the R-N2 golden note). The dev pass restructures the sequence DELIBERATELY (authors real defense values in `_golden_config`, adds an exercises-block-and-deflect pin test); exact boundary ticks live in dedicated non-golden tests. Snapshot shape predicted NONE — deflect-consumed state is DERIVED (dedupe registration + window state); any stored field is a separately named cause.

---

## Session 2026-07-26 — 1-8 close-out

**What landed (0eea3f1 code+tests / 9529a85 story record / e67abc5 board+status).** Implementation exactly as gated — rulings R-D1..R-D7, R-N2, and the R-B3/R-B5 pins implemented as ruled, nothing reopened (see the readiness-gate session above for the rulings themselves); full detail in the story Dev Agent Record. Recorded here: the entries that bind beyond 1-8.

**D-4 SUPERSESSION (full, as scheduled at the gate).** Contact facts are FOUR-field from 1-8 on: `[attacker_slot, target_slot, attack_index, world-space target-to-attacker direction]`, the direction computed by the runner FROM POSITIONS ONLY (never `HeroState.facing`, never a relative angle — the arc comparison is state policy) and validated non-zero at the seam. The original D-4 "plain recordable three-int data" wording is SUPERSEDED. `push_contact` remains the SOLE intake; the fact stays plain recordable data — the story that lands `IntentRecorder` inherits FOUR-field facts (together with DEBT B's reload events, one stream contract, unchanged).

**Golden record.** `39564e83...5353` -> `298c40f65d5f3191d2d7c2eacdccdd443c49fe24b0492d66e088318ed840f23f`, ONE re-baseline, measured in both directions, TWO causes named separately (landed in 0eea3f1): (1) EXERCISED-PATH RESOLUTION CHANGE — the recorded sequence's t5 fact (a t4 physics contact under the F1 lag) falls INSIDE the deflect window's +1 grace tick and now resolves as a DEFLECT. The step-2 empirical measurement (mechanics in, old sequence otherwise unchanged) moved the hash to intermediate `ca3dc15e...76ff5` with exactly the predicted outcome — P2 HP 120 not 108, P1 mana 0 not 12 — CONFIRMING the gate's corrected grace arithmetic. (2) DELIBERATE RESTRUCTURE — `_golden_config` authors the defense values (block_damage_multiplier 0.25, deflect_stamina_cost 20, block_facing_arc_degrees 180), P2 gained a second block span (t7-14), and a new t13 fact resolves as an ordinary BLOCK, so the sequence exercises BOTH outcomes, pinned by `test_golden_sequence_exercises_block_and_deflect`. SNAPSHOT SHAPE VERIFIED NOT A CAUSE: the R-N2 grace marker is a per-tick TRANSIENT (write-before-read inside `advance()`, excluded from `to_snapshot()` with the replay-soundness argument in its doc comment) and deflect-consumed state is DERIVED (dedupe registration + window state) — exactly the gate's prediction.

**Accepted dev decisions (recorded so they read as decisions).** (1) A DEGRADED block entry `start(0)`-clears any still-running deflect window from an earlier press — "window open = window armed" always holds; pinned by `test_degraded_entry_clears_a_stale_window_from_an_earlier_block`. (2) `_is_facing` uses EXACT float comparison, no epsilon; the boundary tests pin just-inside/just-outside the half-arc, and the measure-zero arc/2 ray is deliberately unpinned (`deg_to_rad(90)` and atan2's pi/2 differ by 1 ulp — the guarded behavior is both sides OF the arc, not the boundary ray).

**Suite.** 115 -> 130 state tests / 543 -> 600 assertions + 7 integration tests, all green (integration run individually); the live pipeline runs the four-field gather with unchanged outcomes (`test_contact_pipeline`: 19 hits, kill at 17 — the dummy never blocks).

**Operator smoke check PASSED (2026-07-26; temporary KEYBOARD_P2 flip on slot 1, reverted, never committed).** Blocked chip lands at 1.8 (6.0 x authored 0.3) while facing the attacker; a timed block press produces NO number — the deflect, observable only as the absence of hit_landed; a back-facing block takes the full 6.0. All three outcomes match the headless pins live. **FINDING (feeds 1-10):** the parry is HARD to time with no visual/audio feedback — the deflect has no cue until 1-10 CombatCues, by design; the operator succeeded repeatedly despite it. This confirms 1-10 as `deflect_landed`'s first consumer and its priority. The R-D6 acceptance was exercised once without incident and REMAINS IN FORCE for the 1-9 smoke check; the NAMED GAP trigger stays story 2-3.

**Obligation status after 1-8.**
- `deflect_landed` — LIVE, no consumer, no runner seam: 1-10 adds the connect seam alongside the owed `connect_hero_action_rejected` (the action_rejected precedent, unchanged).
- roll_iframe x contact — the 1-9 half of the fence is INTACT: step 4 still ignores roll i-frames; 1-8 dropped only the BLOCKING half, as scoped.
- STUNNED — still zero inbound edges (guard green); `stun_seconds` still data-only; OPEN decision (a) still OPEN, untouched.
- Architecture amendment queue (world-space facing contract + `null_controller.gd` Directory Tree) — stands, untriggered by 1-8; the four-field fact contract's canonical home is this log (per R-D7).
- N4 comment-hygiene queue — still open, untouched.
- DEBT B, DEBT D, and the X5 recording re-homing — unchanged.

---

## Session 2026-07-27 — Story 1-9 readiness gate (operator decisions)

Readiness gate on `1-9-roll-with-iframes.md` (authored 2026-07-22 in the original Set B batch, before stories 1-3..1-8 were implemented) returned **NOT READY** — five blocking findings: B1 (AC2's stored `is_invulnerable` flag contradicted the derived-window idiom — the `is_deflect_window_open` precedent — and the negation semantics were unspecified against the R-D4 one-resolution ladder), B2 (AC3's "three phases from balance" and "i-frame window may open on a later tick" contradicted the shipped shape: no `roll_recovery_seconds` field exists and `enter_roll` opens both windows at entry with no offset mechanism), B3 (the story presented the 1-3/1-4 substrate — ROLLING transition, stamina cost/rejection, cancellability table, all test-pinned — as new work, risking re-implementation), B4 (no golden prediction despite guaranteed snapshot-shape and exercised-path changes), B5 (no live-smoke section despite the R-D6 acceptance being in force for 1-9 by name). All resolved by operator decision (Matko, rulings 1-9/R1..1-9/R8) and applied to the story file the same day. Labels are story-scoped (1-9/R1, 1-9/N1) — bare R/N numbers stay reserved for the existing global entries (e.g. the N4 comment-hygiene queue, the 1-7 review R1). Recorded here: the entries that bind beyond 1-9.

**1-9/R1 (locked) — iframe semantics: FACT DROP, not a resolution.** An iframed contact is DROPPED in step 4 BEFORE dedupe registration — the same family as the existing DEAD-target drop, and slotted next to it. No damage, no `hit_landed`, no mana; the swing keeps its chance — if the i-frames expire while the swing's active window is still open, the next gathered fact resolves normally (the runner re-gathers every overlapping tick). The R-D4 ladder rule (one resolution per swing per target) is UNTOUCHED: a dropped fact never resolves. Ladder order from 1-9 on: DEAD drop -> iframe drop -> dedupe accept/register -> BLOCKING/facing (deflect -> block) -> full damage.

**1-9/R2 (locked) — the iframe window is judged at resolution with a +1 grace tick; the grace precedent EXTENDS to both edges.** Mechanism mirrors `_deflect_closed_this_tick`: a per-tick transient recomputed in `tick_timers()`, write-before-read inside `advance()`, EXCLUDED from `to_snapshot()` (replay recomputes it identically inside each tick — no determinism/replay hole). Entry-edge citation check, performed at recording time: the 1-8 grace ruling R-N2 litigated ONLY the close edge — "a contact physically inside the window's last tick, arriving one tick late, still deflects — authored `deflect_window_seconds` means what it says" — the entry edge was never litigated for deflect. THIS ruling therefore EXTENDS the precedent to both edges and is the canonical statement: under the F1 one-tick fact lag the judged span is the physical span shifted one tick — at the ENTRY edge a contact whose physics predate the roll press by one tick is negated; this is intentional and player-favorable; net coverage equals the authored tick count. (The same entry-edge shift has been implicit in the deflect window since 1-8; it is now stated once, here, for both.)

**1-9/R3 (locked) — negation judged on the window (+grace) ALONE, never on state == ROLLING; the supporting invariant becomes an obligation.** Guard: a NEW authoring-audit bound, `roll_iframe` ticks <= `roll_duration` ticks (`test_balance_authoring.gd`, the R-N6 defect-by-construction family — dev-pass work, listed in the story). The invariant that was gate evidence is now an OBLIGATION: both roll windows start only in `enter_roll` and no code path stops either before expiry; any future early-stop path must re-open this ruling. (Window-alone also keeps the grace tick alive when iframe close coincides with duration close — a state-AND-window check would clip exactly the physically-last-tick contact the grace exists to protect.)

**1-9/R4 — ladder position, recorded as VERIFIED.** ROLLING and BLOCKING are mutually exclusive by the single `action_state` enum — no ladder crossing is possible; the iframe check slots per 1-9/R1 (after the DEAD drop, before `register_swing_hit`).

**1-9/R5 — no dodge cue/signal ships in 1-9.** Under drop semantics there is no resolution to signal. If 1-10's combat-cues gate wants a dodge cue, it raises that itself and owns the cost of surfacing drops (the `deflect_landed` precedent holds: cues and their seams are 1-10's).

**1-9/R6 (locked) — roll displacement IN SCOPE; it is the story core.** Direction captured at ROLLING entry (world-space, camera-rotated `move_dir`; `facing` fallback when the stick is neutral) into a NEW snapshotted `HeroState` field; consumed by a NEW ROLLING branch in `_resolve_movement` overriding velocity at `roll_distance / roll_duration_seconds` — constant velocity, direction locked for the whole roll, the FIRST consumer of `roll_distance`, balance read inline (CONSTRAINT C). No curve, no steering during the roll — future tuning stories, not this one. Named player-facing change: pre-1-9 a rolling hero steers freely at full `move_speed` with live input. The parked 1-7 attack-lunge finding STAYS PARKED ("when animations exist"); roll displacement is the same sanctioned family — state-layer authored displacement via `velocity`, F1 intact — so the two are precedent-compatible; neither triggers the other.

**1-9/R7 — golden prediction: MOVES.** At most ONE re-baseline; THREE separately named causes: (1) SNAPSHOT SHAPE — the new stored roll-direction field in `to_snapshot()`; (2) EXERCISED PATH + AUTHORED VALUE — `_golden_config` gains `roll_distance` (gate finding 1-9/N1: currently unauthored there, defaulting 0.0 — without authoring it the hash encodes a zero-speed roll and the golden guards nothing about displacement) and t17-21 velocity becomes the locked roll override instead of live-input steering; (3) DELIBERATE RESTRUCTURE — P2 gains an attack timed so its active window overlaps P1's roll iframes; one fact negated during the iframes, a second fact one tick after close lands full damage, pinned by a new sequence-coverage test. Dev discipline: all non-golden tests green first; the intermediate empirical measurement (mechanics in, OLD sequence unchanged) isolates causes 1+2 from 3; both predictions measured in both directions, never trusted.

**1-9/R8 — live smoke: the R-D6 acceptance is IN FORCE for 1-9 (as recorded at the 1-8 close-out).** Three-part protocol on the throwaway HitLabel: (1) CONTROL — P1 stands in P2's swing, a number appears (proves range and aim); (2) DODGE — timed roll through the swing, NO number; (3) LATE ROLL — i-frames end inside the active window, a number appears. Part 3 is a live check of the 1-9/R1 drop ruling — under register semantics a same-swing post-iframe number is impossible. Collateral hazard restated: the editor save for the KEYBOARD_P2 flip re-normalizes BOTH `src/main/main.tscn` and `project.godot`; inspect `git diff project.godot` BEFORE reverting; revert both by full path (`git checkout -- src/main/main.tscn project.godot`).

---

## Session 2026-07-27 — 1-9 close-out

**What landed (2db0c83 code+tests / 21fcd33 story record / 6ca2a1f board+status).** Implementation exactly as gated — rulings 1-9/R1..1-9/R8 implemented as ruled, nothing reopened (see the readiness-gate session above for the rulings themselves); full detail in the story Dev Agent Record. Recorded here: the entries that bind beyond 1-9.

**Golden record.** `298c40f6...0f23f` -> `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, ONE re-baseline, measured in both directions, the gate's THREE predicted causes (1-9/R7) reconciled cause by cause: (1) SNAPSHOT SHAPE — `HeroState.to_snapshot()` gains `roll_direction` (P1's t17 roll stores `(-1, 0, 0)` via the neutral-stick facing fallback) — a MOVER, and the ENTIRE step-2 intermediate movement (`3138e35b...6874`). (2) EXERCISED PATH + AUTHORED VALUE — predicted a mover, MEASURED NON-MOVER; recorded as a measured both-directions finding, not an error: the isolation run (intermediate hash IDENTICAL with and without the `_golden_config` `roll_distance` line) proved per-tick roll velocities never reach the hashed final t24 snapshot — the 1-5 cause-(c) lesson holding a SECOND time; `roll_distance` stays authored for path coverage per gate finding 1-9/N1. (3) DELIBERATE RESTRUCTURE — a MOVER: P2 gains a t15 attack (block release and attack entry legally fire the same tick) whose active window (18-21) sits over P1's roll iframes; the t19 arrival DROPS on the grace tick and the t20 arrival from the SAME swing lands FULL damage (P1 120 -> 108, P2 mana 0 -> 12), pinned by `test_golden_sequence_exercises_iframe_negation`. Nothing moved that was not predicted.

**Suite.** 130 -> 141 state tests / 600 -> 640 assertions + 8 integration tests (7 -> 8, new `test_roll_displacement.gd`: dx exactly 3.0, straight, mid-roll velocity from state, full stop after), all green (integration run individually); the live contact pipeline is unchanged (`test_contact_pipeline`: 19 hits, kill at 17 — the dummy never rolls).

**1-9/R2 PRECISION AMENDMENT (behavior and code UNCHANGED; the total-count sentence corrected).** The iframe window opens in step 3 and step 4 of the SAME advance already sees it, so the entry-tick arrival (physics one tick before the press) is also negated. Precise statement, superseding 1-9/R2's "net coverage equals the authored tick count" sentence: the authored window is covered in full (shifted into arrival ticks, its last tick via the grace transient) PLUS one explicitly granted pre-entry arrival — authored+1 physical ticks in total. This applies identically to the deflect window since 1-8. The entry-edge grant was already explicit in 1-9/R2; only the total-count sentence is amended.

**Accepted dev decisions (recorded so they read as decisions).** (a) FACING STAYS LIVE during a roll — the override is velocity-only and facing keeps tracking input (the ATTACKING-commitment precedent); accepted as shipped. (b) `balance.roll_duration_seconds` is read inside `advance()` as the speed quotient `roll_distance / roll_duration_seconds` — the ruling's exact quotient; a SPEED derivation, not window timing (timing stays `balance_ticks`); accepted as shipped. (c) Known nuance, recorded with no action: the roll displacement equals `roll_distance` EXACTLY only when `roll_duration_seconds` is tick-aligned (the speed divides seconds while the duration runs in ticks); the current authored values are aligned.

**Operator smoke check PASSED (2026-07-27; temporary KEYBOARD_P2 flip on slot 1).** All three parts: CONTROL — the damage number appeared; DODGE — a timed roll through the swing produced NO number; LATE ROLL — the i-frames expired inside the active window and the number appeared — part 3 is the LIVE confirmation of the 1-9/R1 drop ruling (under register semantics a same-swing post-iframe number is impossible). **Cleanup was NOT fully clean — the 1-8 editor-save-collateral lesson REPEATED:** a second editor session left the KEYBOARD_P2 flip baked into `main.tscn` (`slot_controller_kinds = [0, 1]` serialized onto the Main node); it was caught at this chain's Step 0 baseline check and reverted by the operator by full path before anything was staged (`project.godot` was clean). PROCEDURAL CONSEQUENCE, binding on every future R-D6-style smoke: the revert step must be re-verified with `git status` + the collateral diff IMMEDIATELY before any commit chain begins, not earlier in the session.

**Obligation status after 1-9.**
- The 1-5 step-4 fence is now FULLY CLOSED: the BLOCKING half fell at 1-8, the roll_iframe half here — step 4 resolves both defensive layers; no story inherits a fence half.
- `roll_distance` gained its FIRST consumer (the `_resolve_movement` roll override) — no roll-group balance field is consumer-less.
- The 1-9/R3 invariant is now an audited obligation: both roll windows start only in `enter_roll` and no code path stops either before expiry (any future early-stop path re-opens the ruling); `roll_iframe <= roll_duration` audited in ticks (`test_authored_roll_iframe_within_roll_duration`).
- NO signal shipped (1-9/R5): 1-10 owns combat cues and any dodge-cue question, alongside the owed `deflect_landed` consumer/seam and `connect_hero_action_rejected` obligations — unchanged.
- R-D6 acceptance — exercised a SECOND time (with the collateral caught at Step 0, above) and now SPENT: its own text scopes the acceptance to "supervised E1 smoke checks" covering "BOTH 1-8 and 1-9", with story 2-3 owning the fixes. Both named uses are consumed; any later story wanting a live smoke against a killable human-driven slot must re-invoke the acceptance at its own gate rather than inherit it. The DEAD-slot residuals' fix trigger stays story 2-3, unchanged.
- Architecture amendment queue (world-space facing contract + `null_controller.gd` Directory Tree) — stands, untriggered by 1-9; the global N4 comment-hygiene queue — still open, untouched.
- DEBT B, DEBT D, the X5 recording re-homing, and the 3-1 config-object obligations — unchanged; the story that lands `IntentRecorder` still inherits the FOUR-field contact fact together with DEBT B's reload events (one stream contract).

---

## Session 2026-07-27 — Story 1-10 readiness gate (operator decisions)

Readiness gate on `1-10-telegraph-structure-combat-cues.md` (authored 2026-07-22 in the original Set B batch, before any E1 code existed) returned **NOT READY** — seven blocking findings: F1 (both owed seams — `connect_hero_action_rejected` and the `deflect_landed` consumer + `connect_deflect_landed` — absent from the story text despite this log naming 1-10 for both), F2 (AC3's "subscriber to the state signals" never named the locked observation seam, so a literal dev pass could connect to state objects directly), F3 (the 1-8 parry-visibility finding — the story's actual priority — nowhere in the story), F4 (no live-smoke section, and the R-D6 acceptance the smoke needs is SPENT), F5 (no golden prediction — the 1-9 B4 precedent), F6 (the `TelegraphProfile` schema file never tasked and nonexistent — `.tres` instances have no class to instance; the architecture pins its home at `src/state/resources/telegraph_profile.gd`), F7 (AC1's "referenced by the action" has no referent — `ActionState` is an enum in `src/state/enums.gd`; where the action -> profile mapping lives needed a ruling). Five notes: F8 (no bus layout or audio assets exist; default-path creation avoids any `project.godot` edit; the editor-collateral hazard binds), F9 (the AC5 static direction-check is feasible on the existing invariants-test scanner; the mechanism must be named, not left as "integration test or invariant test"), F10 (AC3's "signals from 1.3–1.9" stale — 1-9 deliberately shipped no signal, 1-9/R5), F11 (the E2 fence and the overlay fence unstated in the story), F12 (this log's line-number citation at the 1-4 gate entry — `match_runner.gd:61-67` for the seam now at :108-114 — is line-drifted with content intact; the log is historical and is never edited). **Zero new signals ruled in scope:** every cue rides an existing D5-queued channel (`action_state_changed`, `action_rejected`, `hit_landed`, `deflect_landed`, `EventBus.round_ended`); any dev-pass desire for a new signal is a SCOPE STOP, not an implementation decision. All resolved by operator decision (Matko, rulings 1-10/R1..1-10/R4) and applied to the story file the same day. Labels are story-scoped per the 1-9 convention. Recorded here: the entries that bind beyond 1-10.

**1-10/R1 (locked) — the `ActionState` -> `TelegraphProfile` mapping is CONTROLLER-OWNED (presentation side).** State is untouched; no state object ever references a `TelegraphProfile`. Binding for E5 reuse: in E5, state will own "which telegraph/color is active" as a gameplay fact (required for RPS resolution), but the fact -> profile translation stays presentation, same seam pattern as now.

**1-10/R2 — dodge cue DEFERRED.** 1-9/R5 stands — an iframe drop stays signal-less; no dodge cue in 1-10. Rationale: dodge already has legibility (visible roll displacement + absence of a damage number during an active input), unlike deflect-vs-block (identical defender pose, different outcome). Revisit at 2-6 with playtest evidence.

**1-10/R3 — smoke acceptance (single-use, re-invoking the spent R-D6), ratified WITH a precision correction to the gate's framing.** The rejection cue is self-triggerable (P1 rolls its own stamina below `deflect_stamina_cost`, then enters block — the degraded entry emits `action_rejected`, R-D1) and the hit-reaction cue is observable on the dummy (P1 swings, the dummy is the `hit_landed` target). The KEYBOARD_P2 flip is needed ONLY for the deflect spark and the block chip (the dummy never swings and never blocks). The protocol is therefore TWO-PHASE to minimize time in the flipped state: **Phase 1 (NO flip, shipped defaults)** — roll sting on entry; rejection cue via self-drain; hit-reaction cue on the dummy; first distinctness pass by ear. **Phase 2 (KEYBOARD_P2 flip on runner slot 1, exported `slot_controller_kinds`; shipped default stays P2 = NULL)** — deflect spark + sting (P2 swings, P1 timed block) clearly distinct from the block chip (reduced number via the throwaway HitLabel); a successful dodge produces NO cue (deliberate — absence is the correct observation); final distinctness check — every E1 action identifiable by ear alone on the `CombatCues` bus. Acceptance scope: exactly this story, consumed on use. The DEAD-slot residuals (a dead hero can walk; a corpse mid-swing can be credited damage/mana) are ACCEPTED for the supervised smoke only; the fix trigger remains story 2-3, unchanged. Binding procedure (1-9 close-out): after every smoke flip, revert BOTH collateral files by full path (`git checkout -- src/main/main.tscn project.godot`) with a look at the `project.godot` diff first, AND re-verify `git status` + the collateral diff IMMEDIATELY before any commit chain begins, not earlier in the session. Editor dialog: always "Reload from disk", never "Ignore external changes".

**1-10/R4 (ratified) — DEBT E - ANIMATION-GATED FEEL** (letter C deliberately skipped to avoid colliding with CONSTRAINT C): the register for feel/legibility work parked on real animation assets. Members: (1) the 1-3c final playtest timing judgment ("deferred until animations land"); (2) the 1-5 B6 per-phase movement multipliers ("out of scope until animations exist"); (3) the 1-7 attack-lunge root motion ("deferred, not dropped"); (4) the Legibility <0.5s shape+sound validation, including pose/silhouette distinctness and `pose_id` consumption. Trigger: the FIRST story that attaches a real animation rig (AnimationPlayer / character model) to `hero.tscn` inherits the whole register; the decision whether to author that story is taken no later than the E2 retrospective; story 2-6 (`2-6-legibility-feel-instrumentation` — slug verified by content on the board and against E2.S6 "Legibility and feel validation instrumentation" in the stories manual) is the forcing point.

**Golden prediction: NONE — conditional on 1-10/R1 (controller-owned mapping) and 1-10/R2 (no dodge cue); measured at dev time in both directions, never trusted** (1-6 / 1-7b precedents). Reasoning: no `advance()` path, snapshot field, signal, or authored gameplay number changes; `telegraph_profile.gd` is pure data vocabulary never referenced by state logic; the two new runner seams are subscription plumbing, and the golden path bypasses the runner. Baseline hash `33817201...21da2`; state harness green both runs; integration files run individually. The story also carries the F1-invariant hazard explicitly: the telegraph controller must not declare `_physics_process`.

**Promotion.** All fixes applied to the story file the same day; story Status and board promoted backlog -> ready-for-dev.

---

## Session 2026-07-27 — 1-10 close-out

**What landed (246e04e code+tests+assets / c4daf57 story record / 426f968 board+status).** Implementation exactly as gated — rulings 1-10/R1..1-10/R4 implemented as ruled, nothing reopened (see the readiness-gate session above for the rulings themselves); full detail in the story Dev Agent Record. Dev pass browser-reviewed: PASS. The two-phase live smoke per 1-10/R3 was executed and PASSED — **Phase 1** all cues confirmed, including the chain re-sting; **Phase 2** deflect spark with NO hit reaction, plus the block chip. ONE finding: **S1 — RollDisc occluded** (radius 0.45 < the hero box half-extent 0.5, entirely inside the body box); fixed (radius 0.8, y -0.95) and the disc re-smoked PASS. **1-10's smoke acceptance is now SPENT** (the R-D6 pattern: any future story wanting a live smoke against a killable human-driven slot re-invokes acceptance at its own gate rather than inherit it).

**RETIRED obligations.** (1) The 1-4 gate `action_rejected` seam obligation — `connect_hero_action_rejected` landed, first consumer = the telegraph controller. (2) The 1-8 R-D4 `deflect_landed` consumer + seam obligation — `connect_deflect_landed` landed, same first consumer.

**Delegated decision recorded — the cues-layer banned-token list (AC 6).** The list is the full public MUTATOR surface of `MatchState` + `HeroState` + the pools, plus the handle tokens `_match_state` / `MatchState.new`; reads stay legal (the guard is on writes — the D5 direction, not data access); the test carries an existence guard on `telegraph_controller.gd` so a rename cannot silently un-guard the layer. `TimingWindow.start(`/`tick(` deliberately excluded — unreachable without an already-banned handle token, and they would false-positive legitimate presentation timers.

**Confirmed live.** A chain re-emits ATTACKING -> ATTACKING, so every chained swing re-stings (the code comment verified in the smoke).

**Note.** The cue tween durations (0.12 hit flash / 0.18 spark) are hardcoded in the controller — presentation-side, acceptable for E1; candidate to fold into profile data when the DEBT E work lands. No new debt item.

**pose_id.** Authored in the profiles but consumer-less until the animation rig lands (DEBT E member 4, already registered).

**Golden record.** Prediction NONE measured and CONFIRMED in both directions — hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unchanged, no re-baseline, no sequence re-record. New committed suite baseline: 142 state tests / 645 assertions + 8 integration tests (run individually).

**Board.** 1-1..1-10 done — **epic E1 complete.**

---

## Session 2026-07-27 — Story 2-1 readiness gate (operator decisions)

Readiness gate on `2-1-split-screen-subviewports.md` (backlog since the Set B batch) returned **NOT READY** — six blocking findings: F1 (AC4 and Task 4 attributed camera framing to "balance-authored camera values" / "adjust balance values", but camera framing lives in `data/camera_config.tres`, a presentation config deliberately outside `BalanceConfig` and the X3 hot-reload path — the story named the wrong owner), F2 (AC1 and the Project Structure Notes described "two cameras on the hero scenes" with gameplay nodes implicitly reparented into the `SubViewport`s — no ruling existed for how a `SubViewport` renders a world it does not own, or for what happens to the existing `CameraRig` basis source), F3 (no golden prediction, despite this touching `main.tscn` and the camera-follow wiring — the 1-9/1-10 precedent), F4 (no live-smoke section, despite AC5 requiring a live perf measurement and AC1/AC4 requiring visual confirmation at half width — the R-D6 smoke acceptance is SPENT as of 1-10), F5 (Dev Notes cited "DECISION (b)" — a label the code has never used; the seam the code comments actually name is SEAM CHOICE 2, per the 1-2/1-9 handoff), F6 (AC3 as written implied the two-entry per-slot camera basis was NEW work for this story, when `match_runner.gd` already pushes `_p1_rig.basis` / `_p2_rig.basis` in step 2 and `_camera_bases` already holds two entries — the story would have re-implemented fixed substrate; relatedly, no task verified the integration-test node paths survive the scene restructure, and no AC named its own verification mechanism). Four notes: N1 (AC2's wording is compatible with the ruled topology once "camera follow" is read as "copy rig transform onto follower camera" — no ruling needed, just precision), N2 (the two-slot integration coverage belongs on the existing `test_camera_relative.gd`, not a new file), N3 (the existing `current = true` override on P1's `Camera3D` needs a disposition note now that a second, container-driven camera path exists), N4 (`stories-manual-e2.md` E2.S1 item 4 carries the same stale "balance-authored" camera wording as `stories-manual-e1.md#E1.S2`). All resolved by operator decision (Matko, rulings 2-1/R1, 2-1/R2) and applied to the story file the same day.

**2-1/R1 (locked) — camera topology.** Gameplay nodes (heroes, arena, lights) are never reparented; they stay under `Main` exactly as today. Two `SubViewportContainer` + `SubViewport` pairs sit side by side and render the shared root world; each `SubViewport` hosts only a follower `Camera3D`. `CameraRig` stays a child of each hero (`hero.tscn` unchanged) and remains the per-slot basis source the runner reads in step 2. In step 4 (drive phase) the runner copies each rig's global transform onto its follower camera — presentation-only, a deterministic function of the tick, snapshot-excluded. Engine world-sharing mechanics (how a `SubViewport` renders a world it does not own) are a dev-pass detail; the binding constraint is that no gameplay node moves. The existing `current = true` override on P1's `Camera3D` is left as a dev-pass disposition detail — the two containers cover the full window regardless.

**2-1/R2 (smoke) — R-D6 re-invoked, single-use.** The spent R-D6 acceptance is re-invoked for 2-1 only, consumed on use. The live smoke requires a temporary `KEYBOARD_P2` flip on runner slot 1 (live verification of the P2-side camera and AC5's full melee exchange), performed by TEXT-EDITING the `slot_controller_kinds` line in `src/main/main.tscn` with the Godot editor CLOSED for the entire smoke. Revert is a text edit back, or per-diff sorting; the blanket `git checkout -- src/main/main.tscn` is FORBIDDEN for this story — the file carries intentional changes (the split-screen restructure) — and any `project.godot` collateral is sorted per-diff, same rule. AC5 (sustained 60 fps, no perceptible drops, through a full melee exchange in split-screen) is pinned to this smoke.

**"DECISION (b)" retired.** Renamed to SEAM CHOICE 2 throughout the story, matching the label the code comments already use (`match_runner.gd` step-2 comment, `match_state.gd`), per the 1-9 B5 handoff and the 1-2 rename precedent. No new label invented.

**Golden prediction: NONE.** `_camera_bases` is excluded from `to_snapshot()`, camera framing lives entirely in `data/camera_config.tres`, and no `advance()` state math is touched. Hash `33817201...21da2` is expected unchanged; the dev pass measures both directions and treats any movement as a stop-and-report, never a re-baseline.

**INCIDENT (third baked flip).** After the 1-10 push, the E2 ground-truth pass found `main.tscn` and `project.godot` modified — `slot_controller_kinds = [0, 1]` (enum order `KEYBOARD_P1`, `KEYBOARD_P2`, `NULL`, so `[0, 1]` is the smoke flip) baked in by a lingering editor session; the third occurrence of the pattern (1-8, 1-9, now post-push). Reverted by the operator after reviewing the full diffs; the committed default `[0, 2]` was restored. Mitigation adopted for E2: config flips via text edit, editor closed during smokes, per-diff collateral sorting once `main.tscn` carries intentional changes (2-1/R2, above).

**New docs debt.** `stories-manual-e2.md` E2.S1 item 4 carries the same "balance-authored" camera wording error as `stories-manual-e1.md#E1.S2` — both sync on the next planning pass; manuals are not edited now.

**Promotion.** All fixes applied to the story file the same day; story Status and board promoted backlog -> ready-for-dev.

---

## Session 2026-07-27 — 2-1 close-out

**What landed (1c510c1 code+tests / ddaa908 docs+smoke / 55a5a5e board+status).** Implementation exactly as gated — rulings 2-1/R1 and 2-1/R2 implemented as ruled, nothing reopened (see the readiness-gate session above for the rulings themselves); full detail in the story Dev Agent Record. Dev pass browser review PASSED. Operator live smoke (2026-07-27) PASSED. Suite: 142 tests / 645 assertions + 8 integration tests, all green (integration run individually). Golden prediction NONE CONFIRMED in both directions — hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unchanged, no re-baseline.

**Micro-decision (accepted on review) — step-4b follow source.** The rig's CHILD camera (`CameraRig/Camera3D` global transform) is the follow source, not the rig root — a literal rig-root copy would drop the authored `camera_config` framing. `data/camera_config.tres` remains the single framing source for rig camera and follower alike.

**KAKO record.** `SubViewport`s inherit the root `World3D` (`own_world_3d` default — no scripted world wiring); `render_target_update_mode` ALWAYS. `current = true` moved to the two followers; the P1 rig-camera `current` override and the orphaned `[editable path="P1Hero"]` are removed — rig cameras are now pure basis/framing sources.

**Smoke.** Half-width framing PASS with no `camera_config.tres` change; no camera jitter; sustained 60 fps through a live melee exchange; the `KEYBOARD_P2` flip executed and reverted by text edit per 2-1/R2, editor closed throughout; the text-edit flip rule kept the smoke itself collateral-free, but a FOURTH editor collateral (`project.godot` only, same signature: line reorder + physics pin dropped) appeared in the pre-chain window from an editor touch outside the smoke procedure; it was caught by the binding Step-0 status+collateral check immediately before the chain and reverted solo after a full pasted diff. New standing rule adopted: before every commit chain's Step 0, verify no Godot editor process is running (`Get-Process *godot*`); a lingering editor session can re-save collateral at any moment.

**R-D6 acceptance.** The 2-1 re-invocation is CONSUMED — spent again. Any future story wanting a live smoke against a killable human slot must re-invoke on its own gate (2-2 is the likely next claimant).

**Live confirmation of NAMED GAP "DEAD-slot residuals" (1-7).** A DEAD hero still moves — first live sighting (E1 smokes ran a NULL dummy); fix trigger remains story 2-3, unchanged.

**Board.** 2-1 done.

---

## Session 2026-07-28 — Story 2-2 readiness gate (operator decisions)

Readiness gate on `2-2-gamepad-controller-input-profiles.md` (backlog since the Set B batch) returned **NOT READY** — six blocking findings: F1 (no golden prediction, despite the story touching `_resolve_movement`'s analog path and adding a runner config point — the 1-9/1-10/2-1 precedent), F2 (no live-smoke section, despite joypad axis reads being headless-blind for both the hardware-to-intent mapping and 360-degree facing), F3 (the runner wiring for the new controller — the A3 single config point — was unstated: no ruling named the `ControllerKind` enum edit or guarded the ordinals int-literal callers depend on), F4 (AC1 required completing P1/P2 Input Map action sets, including E3 actions, which conflicts with the E3 HOLD gate and — pending F5's ruling — may not be the correct mechanism for the gamepad at all), F5 (AC2's device-read mechanism was unspecified and the story's implicit assumption that per-device Input Map actions were the path was never checked against how Godot actually resolves device-filtered input; relatedly, AC3/AC5 as written were not provable on the dev machine's single physical pad), F6 (AC5 as written asserted a "synthetic gamepad-style intent" without naming what makes it source-agnostic, and AC3 did not distinguish provable single-pad behavior from unverifiable simultaneous two-pad isolation). Five questions raised: Q1 (can a joypad event be filtered by device in the Input Map at all?), Q2 (does the ordinal position of a new `ControllerKind` member matter to existing callers?), Q3–Q5 (what, precisely, is headless-testable about gamepad input, and what is not?). All resolved by operator decision (Matko, rulings 2-2/R1..2-2/R7) and applied to the story file the same day.

**2-2/R1 (locked) — Golden prediction: NONE.** 2-2 is controller-layer plus one runner config-point edit; no `HeroState` snapshot field is added and `advance()` ordering is unchanged; analog `move_dir` already traverses `_resolve_movement` (magnitude clamp `if dir.length() > 1.0`), pinned by `test_analog_input_clamped_to_move_speed`. Hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` is measured in BOTH directions at dev pass — before the first edit and after the last. A NO-MOVE prediction is confirmed only by an equal hash from an actual run, never by absence of failure (the cause-(c) lesson, paid twice). Any movement is stop-and-report, never a re-baseline. Precedents: 1-6, 1-7b, 1-10, 2-1.

**2-2/R2 (locked) — device reads.** The gamepad controller reads DEVICE-FILTERED joypad state (`Input.get_joy_axis(device, ...)`, `Input.is_joy_button_pressed(device, ...)`) inside `src/controllers/` only — D3(a) holds. Per-device Input Map actions are REJECTED as the mechanism, for the CORRECT reason (the claim that action reads cannot be device-filtered is FALSE and does not appear in the story): (1) joypad device indices are runtime-assigned and shift on replug; (2) with a single pad there is no way to route it to slot 1 via the Input Map; (3) it hardcodes a device index into `project.godot`, the most collateral-prone file in the repo; (4) it is asymmetric with the keyboard actions, authored device-agnostic (`device=-1`). Button/axis mapping and the deadzone are AUTHORED DATA in a single load-once, controller-owned profile resource (the `camera_config.tres` pattern — presentation/feel, load-once, outside `BalanceConfig` and the X3 hot-reload path); no raw joypad constants scattered inline, no `BalanceConfig` entry. The story names the resource path (`data/gamepad_profile.tres`) and its script path (`src/controllers/gamepad_profile.gd`) in Dev Notes and File List. This is a narrow, recorded exception to "named actions, never raw."

**2-2/R3 — `project.godot` is NOT touched** (supersedes the gate's partial F4 fix). Because the gamepad does not read named actions, no Input Map edit is required. AC1 is rewritten: the gamepad binding for every E1 action (move, attack, block, roll) is authored in the profile resource, one entry per action; no `project.godot` edit is in scope for 2-2. The E3 clause (play-card, stage-card, mode-select) is struck entirely — those actions have no consumer in 2-2, and E3 is under a HOLD gate pending the first E1/E2 playtest, so pre-authoring its bindings would violate the project's own revisit rule. The corresponding task line is removed.

**2-2/R4 — A3 wiring plus ordinal guard.** `match_runner.gd`'s `ControllerKind` enum gains one appended member: `{ KEYBOARD_P1, KEYBOARD_P2, NULL, GAMEPAD }` — appended so `NULL` stays ordinal 2; `_make_controller()` gains the `GAMEPAD` arm. This runner edit IS the A3 single config point and is the sanctioned exception to "no file outside `src/controllers/`"; no state, hero, or actor edit. NEW REQUIREMENT: 2-2 adds a guard test pinning the ordinals (`KEYBOARD_P1==0`, `KEYBOARD_P2==1`, `NULL==2`, `GAMEPAD==3`) — int-literal callers depend on these ordinals (`test_camera_relative.gd` uses `[0, 1]`; every smoke flip writes int literals), and that dependency was previously unwritten; a future reorder would silently change the default that ships. Same principle as the F1 invariant test: a dependency that exists must bite when broken. Device index is derived from `Input.get_connected_joypads()` at construction; no pad present → the controller yields a neutral intent through the same path as disconnect.

**2-2/R5 (new, operator finding) — analog magnitude: NORMALIZED, not merely clamped.** `_resolve_movement` clamps only ABOVE 1.0, so a partial stick deflection would pass through as a fraction of `move_speed`. 2-2 NORMALIZES the stick vector to unit length above the deadzone. Variable-magnitude movement is an unauthored gameplay lever arriving through hardware — it breaks parity in a local PvP match where one player is on a keyboard, there is no authored walk speed and no stamina coupling, and there is no walk animation to render it. Variable-magnitude movement is recorded as OPEN DECISION (c), forcing point 2-6; if it is ever adopted it inherits the DEBT E animation gate.

**2-2/R6 — AC3 narrowed, AC5 reworded.** The dev machine has exactly ONE pad, so simultaneous two-pad isolation cannot be smoke-verified. AC3 is rewritten to what is provable: (a) the single pad drives whichever slot it is assigned, proven by running BOTH smoke flips (2-2/R7); (b) with no pad connected the controller emits a neutral intent and nothing crashes or pauses — headless-testable, since `Input.get_connected_joypads()` is empty in the harness; (c) simultaneous two-device isolation is DEFERRED VERIFICATION, recorded explicitly in the story as unverifiable on current hardware, not silently dropped. AC5 is reworded to state what the headless test actually proves: an analog-shaped intent and the equivalent keyboard intent produce byte-identical `HeroState` snapshots over N ticks (the source-agnostic `advance()` contract); the hardware-to-intent mapping is verified in the live smoke, since joypad axes are not headless-samplable.

**2-2/R7 — Live Smoke section.** Modeled on the 2-1 record. `Input.*` joypad reads are headless-blind, so the hardware-to-intent mapping and 360-degree facing are LIVE-SMOKE: two flips (pad on slot 0, pad on slot 1) via the 2-1/R2 text-edit-only procedure (editor closed throughout), proving AC3(a); the no-pad half of AC3(b) is already headless-proven and needs no live step; AC3(c) is recorded as deferred, not smoked.

**Golden prediction: NONE — conditional on 2-2/R1, R4, R5 (no snapshot field, no `advance()` reorder, stick normalization stays entirely inside the controller before `move_dir` reaches state); measured at dev time in both directions, never trusted** (1-6/1-7b/1-10/2-1 precedents). Baseline hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`.

**Promotion.** All fixes applied to the story file the same day; story Status and board promoted backlog -> ready-for-dev.

### Addenda (same session, operator review of the fix pass)

**A1 — R-D6 is NOT re-invoked by 2-2.** Both 2-2 smoke flips run the gamepad against a NULL dummy, so no killable human slot is involved. R-D6 remains SPENT (consumed at 2-1) and available to story 2-3, which genuinely needs it (permanent `KEYBOARD_P2` flip plus the DEAD-slot residuals fix). The story's Live Smoke section now states this explicitly.

**A2 — Flip arrays pinned, verbatim, in the story's Live Smoke section.** Flip 1 — `slot_controller_kinds = Array[int]([3, 2])` (gamepad slot 0 vs. NULL dummy slot 1). Flip 2 — `slot_controller_kinds = Array[int]([2, 3])` (NULL dummy slot 0, gamepad slot 1) — the live proof that the device index comes from `Input.get_connected_joypads()` and NOT from the slot index. `Array[int]([0, 3])` (keyboard P1 vs. gamepad P2) is FORBIDDEN in 2-2: it would put a live killable human on both slots and thereby re-invoke R-D6, which A1 declines. Both flips are a TEXTUAL edit under the `Main` node's `script =` line in `main.tscn`, Godot editor CLOSED throughout, `git diff -- src/main/main.tscn` after every edit, never committed.

**A3 — correction: the live disconnect step was missing.** The headless no-pad case proves only "no pad at construction"; AC3(b)'s disconnect clause also covers a device vanishing MID-MATCH after its index was already assigned, a different path the fix pass had not covered. The story's AC3(b), Tasks, and Live Smoke section are corrected to cover both: the never-connected case stays headless-provable, and a new live step — unplug the pad mid-match (slot goes neutral, no crash/pause), replug and confirm control returns — covers the runtime case.

**A4 — correction of record: the gate raised SIX questions (Q1-Q6), not five, as this entry's summary paragraph states; that paraphrase stands uncorrected above (append-only) but is superseded by this line.** Separately: this entry's account of the gate's F5/Q1 finding is itself imprecise — the gate's actual text asserted that named-action reads CANNOT be device-filtered, which is false. The operator corrected this at the time; ruling 2-2/R2 rests on the four practical reasons recorded in that ruling (runtime-assigned indices, no routing path with a single pad, `project.godot` collateral risk, asymmetry with device-agnostic keyboard actions) — never on a claim of impossibility. Per the 1-9/2-1 precedent, the log is canonical and is corrected forward, never rewritten; the paragraphs above stand as originally written.

**A5 — two notes carried forward to the dev pass.**
- The gamepad profile script path named in the story (`src/controllers/gamepad_profile.gd`) is PROVISIONAL: the dev pass verifies where the `camera_config` resource's script actually lives (at gate time: `src/actors/hero/camera_config.gd`, actor-owned, not controller-owned) and places the new script consistently with whatever that precedent turns out to mean for a controller-owned resource.
- The Live Smoke revert wording inherited from 2-1 ("once the file carries this story's intentional changes") does not apply to 2-2 — 2-2 makes no committed `main.tscn` change; the standing per-diff revert rule governs regardless, and the story's Live Smoke section now says so.

**A6 — hardware precondition pinned.** The 2-2 live smoke runs on a Logitech F310 in X (XInput) mode; the mode is verified before the smoke and recorded in the result. The gamepad profile is authored against the SDL standard button/axis mapping, valid only in X mode — in D mode the same physical button reports a different index and the profile is silently wrong. This was ratified at gate time and dropped in the first fix pass; it is restored here because `gds-dev-story` may not edit the Live Smoke section.

**A7 — profile script path RATIFIED, no longer provisional; supersedes A5's first bullet.** Re-verified by content: `camera_config.tres`'s script is at `src/actors/hero/camera_config.gd` (actor-owned) and `feature_flags.gd` is at `src/state/resources/feature_flags.gd` (state-owned). The precedent is "a resource script lives in its owner's domain folder", which makes `src/controllers/gamepad_profile.gd` consistent, not deviant, for a controller-owned resource. The story's Dev Notes and Project Structure Notes now state the path as ratified. The dev pass implements the path as written and does not re-open it.

---

## Session 2026-07-28 — 2-2 close-out

**What landed (d4b489e code+tests / 52d945f docs+smoke / 7dfcbb1 board+status).** Implementation exactly as gated — rulings 2-2/R1..2-2/R7 and addenda A1-A7 implemented as ruled, nothing reopened (see the readiness-gate session above for the rulings themselves); full detail in the story Dev Agent Record.

**Golden.** Prediction NONE HELD (2-2/R1) — measured in both directions at the dev pass and re-measured at this chain; hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unchanged since 1-9. Suite 142/645 -> 151/690 state-harness assertions, plus 8 integration tests, all green (integration run individually).

**Review findings D1-D5, resolved.**
- D1: the first draft authored `block_button = 5`, which is `JOY_BUTTON_GUIDE` — a SYSTEM button, not RB. Fixed STRUCTURALLY, not by editing an integer: `gamepad_profile.gd`'s exports are typed with the engine `JoyButton`/`JoyAxis` enums and DEFAULT to named constants, plus a guard test that the three action buttons are pairwise distinct and none is GUIDE/START/BACK.
- D2: no Y inversion is needed, and one would have INTRODUCED the bug it was meant to prevent — both the keyboard's `get_vector` up-arg and `JOY_AXIS_LEFT_Y` put "up" at negative Y; pinned by a test comparing against the keyboard's ACTUAL output, not a chosen literal.
- D3: the first draft's mutable `_next_gamepad_ordinal` counter (order-dependent, non-idempotent) is REJECTED and replaced by a pure `_gamepad_ordinal_for_slot` derivation off `slot_controller_kinds` — the i-th GAMEPAD binds the i-th connected joypad regardless of wiring order — pinned by a two-slot test.
- D4: the tick-based pressed-edge derivation (no engine-tracked "just pressed" for raw joypad buttons) is promoted from prose to MICRO-DECISION 5 as a genuine behavioural asymmetry against the keyboard's frame-based edge, plus an operator watch-note to verify clean attack-chain linking during the live smoke — the one path headless cannot exercise.
- D5 RECONCILIATION: AC5's "integration test" wording is satisfied by a STATE-harness test, not the SceneTree integration harness. The property (analog-shaped intent vs. equivalent keyboard intent -> byte-identical `HeroState` snapshots) is frameless — pure `MatchState` + `InputIntent` — while all 8 SceneTree integration tests are scene-based (`main.tscn` + `_physics_process`); the repo's own placement rule (frameless -> state harness) puts it there. Recorded here as a reconciliation; the AC text is NOT rewritten — the log is canonical.

**Control scheme ratified.** Attack RB, block/deflect LB, dodge B — the Sekiro line (2-2 review D1 operator ruling), accepted live at the smoke. The mapping and deadzone stay authored data in `data/gamepad_profile.tres`, re-authorable without a code change.

**R-D6.** NOT re-invoked by 2-2 (both smoke flips ran the pad against a NULL dummy, per A1) — remains SPENT since 2-1 and available to story 2-3.

**AC3c.** Simultaneous two-pad isolation is DEFERRED VERIFICATION — unverifiable on the dev machine, which has exactly one physical pad. Recorded explicitly, not silently dropped; revisit if/when a second pad is available.

**OPEN DECISION (c) — carried, not resolved here.** Variable analog magnitude (walking at partial stick deflection) stays unauthored (2-2/R5: the controller normalizes to unit length above the deadzone instead). Forcing point remains story 2-6; whether it joins the DEBT E animation-gate registry is decided at the E2 retrospective.

**Live smoke — operator PASS.** Hardware: Logitech F310, X (XInput) mode, connected before launch. Construction log `[gamepad] slot ordinal 0 -> device 0 (XInput Controller)` confirms X mode by device name (2-2/A6) and, logged during Flip 2 while the pad sat on player slot 1, is the live proof of the D3 pure ordinal derivation (ordinal from the connected-joypad list, not the slot index). Flip 1 `Array[int]([3, 2])`: attack/block/roll all drive from the pad, no dropouts, facing continuous rather than 8-directional, RB/LB/B scheme accepted as-is. Flip 2 `Array[int]([2, 3])`: the same pad drives P2; a 2-3 hit attack chain links exactly as on the keyboard (the live check for MICRO-DECISION 5's pressed edge); unplug mid-match sends the slot neutral with no crash/pause, replug restores control. The forbidden flip `Array[int]([0, 3])` was NOT run (A1). NOT verified: simultaneous two-pad isolation (AC3c), fps/perf measurement, deadzone-edge jitter. Verdict: PASS for what is covered.

**Process notes.**
1. The blank-line residue after a Notepad flip edit recurred during this story's dev-pass window — the SECOND occurrence of the 2-1 lesson (1-9/1-8 editor-collateral pattern's docs-file cousin). `git diff` after every manual edit stays mandatory, no exception.
2. A suspected `unique_id` collateral on `main.tscn` was investigated and DISMISSED: `unique_id=` is normal, already-committed content on every node header in this repo's `.tscn` format (confirmed with `git show HEAD:src/main/main.tscn`), not an editor artifact. No fifth editor-collateral incident — `main.tscn` carries zero diff for this story (Step 0 verified).

**Board.** 2-2 done; E2 at 2 of 6.

### Correction to process note 1 (same session)

Process note 1 above places the blank-line residue "during this story's dev-pass window" and
calls it a cousin of the editor-collateral pattern. Both are corrected here; the paragraph
above stands as written (append-only, 1-9 / 2-1 / A4 precedent).
- WHEN: the residue occurred during the OPERATOR'S LIVE SMOKE, after the dev pass had
  finished, when the temporary `slot_controller_kinds` flip lines were removed from
  `src/main/main.tscn` by hand. Two blank lines were left behind and were caught by
  `git diff` before the chain, exactly as the rule intends.
- WHAT IT IS NOT: this is an artifact of a MANUAL TEXT EDIT in a scene file, not of a Godot
  editor session. It is NOT a member of the editor-collateral register, which stays at FOUR
  incidents with its own distinct signature (node reordering, deletion of engine-default
  pins such as `physics_ticks_per_second=60`, added `uid=` attributes, scene
  renormalization). Conflating the two would dilute the signature that the closed-editor
  rule exists to detect.
- The standing rule is unchanged and is what caught it: `git diff` after EVERY manual edit,
  no exception.

---

## Session 2026-07-28 — Story 2-3 readiness gate (operator decisions)

Readiness gate on `2-3-opponent-second-human.md` (authored 2026-07-22 in the original Set B batch, before any E1/E2 code existed) returned **NOT READY** — seven blocking findings, five notes, four questions, report-only against `a299bda`, suite measured green at 151/690 state-harness assertions + 8 integration tests. The story described a different story than the one 2-3 must carry: it never mentioned the DEAD-slot residuals fix (the named gap from 1-7, live-confirmed at the 2-1 smoke, whose committed trigger is 2-3) — the story's actual primary deliverable — and it pulled in three out-of-scope items (a match-setup selection scene/resource, per-player HUD subscription owned by 2-4, and a `ReplayController`/X5 replay path absent from `src/`), carried no Golden Hash or Live Smoke section, and carried a stale "DECISION (a)" label. Old AC1 and the A3 one-liner (`slot_controller_kinds` default `[0,2]` -> `[0,1]`) were verified correct as written and kept in substance. All findings resolved by operator decision (Matko, rulings 2-3/R1..2-3/R12) and applied to the story file the same session. Labels are story-scoped per the 1-9 convention.

**2-3/R1 (locked) — acceptance criteria rewritten; old AC2, AC3, AC4 excised.** The story is rebuilt around five ACs: the A3 config flip (old AC1, kept), the DEAD-slot state-gating fix, the DEAD-attacker step-4 ladder extension, guards + integration re-verification, and the live smoke. Old AC2 (match-setup selection scene/resource), old AC3 (per-player HUD subscription), and old AC4 (`ReplayController`/X5 replay) are removed from this story entirely — see 2-3/R2..R4.

**2-3/R2 — X5 / `ReplayController` REROUTED, not deleted.** The requirement is not dropped: it moves to the story that lands `IntentRecorder`, which already inherits the four-field contact fact (1-8 D-4 supersession) and the second half of DEBT B (reload events in the intent stream) — one stream contract, taken together. 2-3 does not build a recorder or a replay controller. A Dev Notes pointer states this in the story file.

**2-3/R3 — per-player HUD stays with 2-4.** Nothing in 2-3 enforces HUD subscription scope. "No HUD reads the opponent's `PlayerState`" is already covered by the locked observation seam (signals/payloads only, consumers never hold a state handle) — 2-3 has nothing further to enforce here.

**2-3/R4 — no match-setup selection scene or resource.** `slot_controller_kinds` is the ONLY configuration point (constraint A3); a selection affordance would be a second authoring surface. Deferred to its own story when E7 (scripted bot) is in view.

**2-3/R5 (locked) — DEAD-slot residual fix SEAT: state-gating inside `MatchState` step 3.** A dead slot gets zero velocity, FROZEN facing (frozen at the moment of death, not reset), and suppressed stamina regeneration. Intent-suppression in the controller is REJECTED — the state gates behaviour; controllers stay dumb (D3a).

**2-3/R6 (locked) — DEAD ATTACKER: negation seats on the step-4 ladder as an extension of the existing DEAD-drop rung to the attacker side.** It must NOT be implemented by stopping or clearing in-flight windows: an early-stop path re-opens the 1-9/R3 obligation ("both roll windows start only in `enter_roll` and no path closes them before expiry"). Consequence, deliberately accepted: windows on a dead hero KEEP TICKING to expiry — this is deliberate behaviour, not a residual — they simply deliver nothing (no damage, no `hit_landed`, no mana, no signal).

**2-3/R7 (locked) — LIVE SMOKE RUNS WITH NO FLIP LINE.** After the flip the script default IS `[0,1]`, so the smoke exercises the COMMITTED default with zero manual `.tscn` edits. This removes the blank-line-residue hazard (2-2 process note) and the baked-flip hazard (the recurring editor-collateral pattern, four prior incidents) entirely. Any additional run against a different configuration is OPTIONAL and only then requires the manual line, with the full ritual (editor closed, textual edit immediately below the `script =` line of the `Main` node with no blank line, `git diff` after the edit AND after the removal).

**2-3/R8 — R-D6 smoke acceptance RE-INVOKED by 2-3.** SPENT since 2-1; NOT re-invoked by 2-2 (both 2-2 flips ran against the NULL dummy, per 2-2's A1). A permanent `KEYBOARD_P2` default means two live, killable human slots — this is the true candidate the acceptance's own text was scoped for.

**2-3/R9 — label rename: "DECISION (a)" -> architecture amendment A3, matching the label the code comments already use** (`match_runner.gd` and `null_controller.gd`), per the 1-6 gate's B5 precedent (which already flagged 2-3's stale label for its own gate to resolve). **Disambiguation:** the story-local "(a)" was NOT the decision-log's OPEN decision (a) — "Attacker consequence on basic-attack deflect" (Session 2026-07-22, deflect consequence to the attacker / STUNNED) — which remains open, untouched by this story, with its forcing point at E5 (unblockable RPS+orbs, where an attacker-consequence mechanic would naturally land).

**2-3/R10 — NEW NAMED GAP: "post-round-over live match".** `MatchState.advance()` has no early return on `_round_over` (confirmed by content: no such guard exists in `advance()`, `match_state.gd:93` on) — the surviving hero keeps moving after the round ends. This will be VISIBLE on the first two-human smoke (a NULL dummy never exhibited it, since it never moves). NOT 2-3 scope. Named and parked; owner decided at the E2 retrospective.

**2-3/R11 — integration re-verification requirement.** The dev pass must RE-RUN all 8 integration tests INDIVIDUALLY AFTER the flip and report the results explicitly. Integration tests drive the real scene, so any that rely on the default slot config now get a live P2 keyboard slot instead of a NULL dummy. Headless probably yields a neutral intent for an unpressed keyboard slot, but that is an assumption to prove at dev time, not a fact to assume.

**2-3/R12 — Golden prediction: NONE, both directions.** The recorded determinism sequence never kills a hero (P1 ends 108 HP, P2 ends 117 HP, MAX_HP 120), so the DEAD branch is never entered; and `slot_controller_kinds` is runner-side config absent from `MatchState.to_snapshot()`, so the flip cannot touch the hash by construction. If the hash moves at all, that is a FINDING (the gating leaked into a live branch) and is investigated, never baselined away.

**Promotion.** All fixes applied to the story file the same session; story Status and board promoted backlog -> ready-for-dev.

---

## Session 2026-07-28 — 2-3 close-out

**What landed (843e33a code+tests / 96cd66f docs+smoke / fa2beb7 board+status).** Implementation exactly as gated — rulings 2-3/R1..2-3/R12 implemented as ruled, nothing reopened. Quoted by content from commit 843e33a, per acceptance criterion:

- **AC1** — "Flip `slot_controller_kinds` default to `[0, 1]` at the sole A3 config point."
- **AC2** — "Close the DEAD-slot residuals: zero a dead hero's velocity every tick and skip its facing write in `_resolve_movement`, suppress stamina regen for a dead hero in `_regen_stamina`" — "no new snapshot field."
- **AC3** — "drop contact facts sourced from a dead attacker at the pre-dedupe rung of the step-4 ladder" — "No in-flight window is stopped early."
- **AC4** — "Guards for each residual class plus the shipped default array." Five new tests total; all 8 integration tests re-run individually after the flip, all PASS.
- **AC5** — live two-human smoke, PASS, no findings (`docs/playtest-log.md`, 2026-07-28 entry).

**New rulings, continuing from 2-3/R12:**

**2-3/R13 — MICRO-DECISION (operator-accepted): a hero still moves on its FINAL LIVING TICK.** Movement resolves in step 3, DEAD is set in step 8 — so the corpse carries its last live velocity for exactly one tick before the first dead tick zeroes it. Accepted deliberately: zeroing at DEAD entry would spread the dead-movement decision across a third function. Not visible at 60 Hz in the live smoke. Pinned by `test_dead_hero_velocity_zeroed_every_tick`, which asserts the one-tick carry explicitly.

**2-3/R14 — the velocity/facing asymmetry and WHY.** `velocity` is written because `HeroActor.drive()` reads it into `move_and_slide()` every frame — a skipped write would leave the corpse sliding at its last live speed forever. `facing` is skipped because nothing re-derives it downstream (it is only ever read to compute a display yaw) — persistence of the last value IS the freeze, not a separately stored frozen copy. No new snapshot field: only `velocity`'s VALUE on the DEAD branch changes.

**2-3/R15 — attacker-side drop joins the EXISTING DEAD-drop family, no new rung.** The attacker-liveness check seats at the SAME pre-dedupe rung as the target-side drop, ahead of the iframe drop and `register_swing_hit`. No early-stop path was introduced, so the 1-9/R3 obligation ("both roll windows start only in `enter_roll`, no path closes them before expiry") stands untouched — windows on a dead hero keep ticking to expiry by design.

**2-3/R16 — Golden: NONE, both directions, prediction confirmed; guards proven load-bearing by the reverse run.** Hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unmoved since 1-9, measured in both directions (the reverse measurement temporarily disabled the DEAD gates and the file was restored byte-for-byte, SHA256-verified). The reverse run also showed all four behavioural guards FAIL without the gates — the load-bearing proof 2-3/R12 asked for is now empirical, not merely structural. Suite 151/690 -> 156/714 state-harness assertions.

**2-3/R17 — R-D6 RE-INVOKED and PASSED against two live killable human slots — SPENT again.** Any later story wanting a live smoke against a killable human-driven slot re-invokes it at its own gate.

**2-3/R18 — PROCESS: first smoke in this repo run with ZERO manual `.tscn` edits.** Because the flip became the committed default (2-3/R7), blank-line residue and baked-flip hazards were structurally absent rather than merely avoided. Zero editor collateral; the collateral registry stays at FOUR incidents.

**2-3/R19 — comment hygiene: three stale sites corrected in commit 843e33a.** The `_regen_stamina` docstring, the `match_runner.gd` export comment, and the `test_camera_relative.gd` header/inline comments. The explicit `[0, 1]` override in that test is RETAINED on purpose — a test must not depend on a default it does not itself set.

**2-3/R10 status.** The named gap "post-round-over live match" remains OPEN and unowned; owner decided at the E2 retrospective.

**Board.** 2-3 done; E2 now stands at 3/6.

---

## Session 2026-07-28 -- Story 2-4 readiness gate (operator decisions)

Readiness gate on `2-4-per-player-hud-half-width.md` (backlog since the Set B batch) returned **NOT READY** -- six blocking findings, seven notes, three questions (Q1-Q3). Two premise corrections against the browser brief: (1) the pool signals (`hp_changed`, `stamina_changed`, `mana_changed`) ARE emitted on every real change already -- the values were never signal-less, only unreachable through a runner seam; (2) `telegraph_controller.gd` lives in `src/actors/hero/`, not `src/ui/` -- `src/ui/` (bar `hud/.gitkeep` and `debug/.gitkeep`) is empty and 2-4 is the first file there. All findings resolved by operator decision (Matko, rulings 2-4/R1..2-4/R12) and applied to the story file the same session. Labels are story-scoped per the 1-9 convention.

**2-4/R1 (locked) -- THREE NEW PER-SLOT OBSERVATION SEAMS, an AMENDMENT to the locked seam family.** Resolves gate F1/Q1: the HUD's HP/stamina/mana values are event-signalled already, but no runner seam exposed them. Adopted: wrap the existing signals in three new per-slot connect seams on `match_runner.gd` -- `connect_hero_hp_changed(slot, cb)` wraps `player.hero.hp_changed`, `connect_stamina_changed(slot, cb)` wraps `player.stamina.stamina_changed`, `connect_mana_changed(slot, cb)` wraps `player.mana.mana_changed`. Payload for all three: `(current: float, maximum: float)`, payload-only, never a state handle. The `hero_` prefix appears only where the signal lives on `HeroState`; the asymmetry is intentional and matches the existing naming (`connect_hero_action_state_changed` vs. `connect_hit_landed`). Slot guard identical to the existing per-slot seams. The locked observation seam family goes from FOUR to SEVEN plus `EventBus.round_ended`. Rejected: a per-slot per-tick snapshot push (unnecessary since the signals exist; invites an opponent-read shape; risks a new state field and thus the golden), and any direct state read by the HUD (banned-token scan, no-handle rule). This is an AMENDMENT to a locked constraint -- this entry is CANONICAL. The `game-architecture.md` text edit is NOT made this session -- it folds into the standing arch amendment queue (world-space facing contract, `null_controller.gd` in the Directory Tree, A3 stale-label cleanup, the gamepad exception to "named actions, never raw").

**2-4/R2 (locked) -- PRIME ON CONNECT.** The three signals are edge-driven, so a consumer connecting in `_ready` receives nothing until the first change: the HP bar would render empty until first damage and `maximum` would never arrive. Each of the three new seams MUST emit the current value once, at connect time, to the callback being connected. Without this the smoke shows empty bars and it reads as a layout bug. Consistent in spirit with X3 hot-reload, which already re-signals through `set_maximum`.

**2-4/R3 (locked) -- DEBUG OVERLAY: DELETED, TEST REPLACED.** Resolves gate F3/Q2. 2-4 owns the retirement: delete `src/main/debug_state_overlay.gd`, remove its instantiation and seam wiring from `match_runner._ready`, delete `test/integration/test_debug_overlay.gd`, ADD an equivalent HUD integration test proving the same property in the live scene -- per-viewport HUD nodes exist under BOTH SubViewports. Integration baseline stays at 8, it does NOT drop to 7. Nothing is inherited from the overlay: its `action_state_changed` role is already covered by `TelegraphController`, its `hit_landed` HP readout is superseded by the HUD HP bar.

**2-4/R4 (locked) -- SEAM CONSUMPTION.** Resolves gate F2/Q3. 2-4 does NOT re-consume the four combat seams (`connect_hero_action_state_changed`, `connect_hero_action_rejected`, `connect_hit_landed`, `connect_deflect_landed`) -- those stay fully owned by `TelegraphController`; the standing obligation is that E2 HUD stories leave no seam dead, and they are not dead. 2-4 consumes: the three new economy seams (bars) + `EventBus.round_ended` (a minimal per-viewport round-over label). Double-consuming `hit_landed`/`deflect_landed` would recreate the retired overlay's job and blur the "telegraph owns combat events" line. The story carries a per-element -> channel table: every HUD element names its channel, every consumed channel names its element.

**2-4/R5 -- NAMED GAP 2-3/R10 BECOMES VISIBLE, IS NOT OWNED.** The round-over label makes the open "post-round-over live match" gap visible (label says the round ended while the survivor still moves). 2-4 does NOT take ownership -- owner is decided at the E2 retrospective. The Live Smoke section lists this as EXPECTED, PRE-KNOWN behaviour so it is not reported as a new finding.

**2-4/R6 (locked) -- CONSTRUCTION: CODE, ZERO `.tscn` EDITS.** The HUD root is a `Control` constructed in code and added as a child of each SubViewport (the pattern the retired overlay already used -- code construction, reparented to a per-viewport SubViewport instead of the runner root). NO edit to `main.tscn`. NO new `.tscn` file -- a new scene would need hand-written content plus uid injection and carries editor-collateral risk for no benefit here. If the dev pass wants a scene file, that is a deviation raised at review, never a silent choice. Adds no camera, reparents no gameplay node, does not touch `data/camera_config.tres` (the sole framing source). Any of those would violate the locked 2-1 topology.

**2-4/R7 (locked) -- NO-OPPONENT-READ IS STRUCTURAL.** The runner binds each HUD root only to its own slot's callbacks (telegraph precedent), so the HUD is handed only its own player's payloads and structurally cannot reach the opponent. Pinned by test: each HUD root is wired with only its slot's economy callbacks. A comment is not enforcement. This is the habit that protects the E3 private hand.

**2-4/R8 -- EXISTENCE GUARD for the HUD root file in the invariant scan**, mirroring the existing `telegraph_controller.gd` guard, so a rename or move out of `src/ui/` cannot silently un-guard it. The banned-token scan already covers new `src/ui/` files recursively; the existence assertion protects against a MOVE OUT of `src/ui/` specifically.

**2-4/R9 -- `_process` STAYS A STORY-LEVEL CONSTRAINT, NO NEW INVARIANT TEST.** F1 bans only `_physics_process`; `project-context.md` explicitly permits `_process` for UI. The HUD is event-driven, but that discipline is review-checked, NOT machine-enforced.

**2-4/R10 (locked) -- Golden prediction: NONE, measured in BOTH directions.** `src/ui/` files, runner-side seam wiring, and the overlay deletion touch no snapshot field. What would move it: any state-side drift -- a cached readout, a per-tick snapshot struct in state, a "round over" flag persisted into `to_snapshot()` (the 1-9 `roll_direction` precedent, and exactly why 2-3 implemented the facing-freeze by NOT writing). Baseline: golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, suite 156 state / 714 assertions + 8 integration (run INDIVIDUALLY). The dev pass measures in both directions; movement is stop-and-report, never a re-baseline.

**2-4/R11 -- LIVE SMOKE SECTION.** Runs on the shipped default `slot_controller_kinds = [0, 1]` (two live killable humans), so it needs NO flip line and NO manual `.tscn` edit of any kind. Measured in the HALF viewport, never full-width -- half-width legibility is the reason split-screen was pulled forward to E2. Must include an explicit legibility judgement, and the 2-4/R5 pre-known behaviour. R-D6 smoke acceptance is RE-INVOKED by this story (live smoke against killable human slots) and becomes SPENT again only on a pass.

**2-4/R12 -- MECHANICAL.** Playtest-log entry: `docs/playtest-log.md`, written BY THE OPERATOR'S OWN HAND, in Croatian, required by AC regardless of whether the smoke produced findings, written BEFORE the commit chain (chain Step 0 expects it) -- no agent writes it; this is an AC-level obligation. The missing Change Log section (story-format contract for `gds-dev-story`) is added. Scope fences: 2-5 owns all face-up/face-down hand logic (2-4 reserves footprint only); 2-6 owns the telegraph legibility protocol and the state inspector -- AC10 here is HUD-LAYOUT legibility and does NOT satisfy or partially satisfy DEBT E member 4; the centre "incoming telegraph" is a world-space cue, not a HUD element, and the pitch timer is E6 -- both positional placeholders only; E3 HOLD stands (no hand array read, no card widget, mana bar passive).

**Promotion.** All fixes applied to the story file the same session; story Status and board promoted backlog -> ready-for-dev.

---

## Session 2026-07-28 -- Story 2-4 corrective docs edit (mana bar premise)

**2-4/R13 -- CORRECTION: the mana bar is LIVE in E1, not passive.** The 2-4 story text (AC4, per-element table, R12's Scope-fences line) claimed the mana bar "sits at its passive value (0 / max) until E3 gives it sources." Verified false by content, this session: `MatchState._generate_mana` (story 1-5, step 5 of the intra-tick order, `src/state/match_state.gd`) grants `balance.melee_hit_mana` flat to the attacker for every slot in `_resolve_contacts`'s `confirmed` array, gated only on the injected `FeatureFlags.melee_mana_generation` (default `true`, shipped `data/feature_flags.tres` carries no override so the class default stands). `_resolve_contacts` appends a slot to `confirmed` for every CONFIRMED hit -- full damage AND block-multiplied damage both confirm (1-8 ruling: block reduces damage, it does not touch the attacker's economy); only a DEFLECT, an iframe drop, or a DEAD-attacker/DEAD-target drop withholds confirmation. So a BLOCKED hit still pays the attacker full melee-hit mana. `_maximum` finding: `ManaPool` is constructed with the runner's constructor-level `_MAX_MANA := 80.0` (`src/main/match_runner.gd`; `BalanceConfig` has no `max_mana` field until story 3-1, so the cap is NOT injected via `apply_balance`) -- non-zero, live, verified in the shipped path, so no guarded-denominator note was needed. `melee_hit_mana` itself is NOT a placeholder: the class default (`balance_config.gd`) is `0.0`, but the shipped authored resource `data/balance/balance_config.tres` overrides it to `8.0`, and that is the value the running match reads. AC4 and the per-element table row in `2-4-per-player-hud-half-width.md` were corrected this session to say the mana bar is LIVE from E1 and moves on every confirmed hit, blocked hits included, and that this is EXPECTED smoke behaviour, not a finding. R12's Scope-fences summary line ("mana bar passive") and the Dev Notes R12 prose block were left untouched -- out of scope for this corrective pass; a future pass should reconcile them. The missing `.uid`-generation task (AC7: after `hud_root.gd` / `test_hud_viewports.gd` exist, run `godot --headless --editor --quit --path .`, then a per-diff collateral check -- blanket revert stays RETIRED) was added to Tasks/Subtasks in the same edit.

---

## Session 2026-07-28 -- Story 2-4 close-out

**MICRO-DECISION 1 (accepted, live-confirmed) -- the round-over label survives a debug reset.** Verified by content this session: `MatchState._apply_debug_reset` (`src/state/match_state.gd`) sets `_round_over = false` and heals both players, but emits no signal -- there is nothing for the HUD's `on_round_ended` to bind to, so the label text and visibility set by the earlier `EventBus.round_ended` emission are never cleared. Explicitly NOT solved by hiding on a later economy signal: the match keeps running post-round-over (2-4/R5) and stamina keeps regenerating, so the label would erase itself instantly if hidden on the next stamina/HP/mana tick. Same family as the 2-3/R10 named gap: both are round-lifecycle facts the seam does not expose. Both go to the E2 retrospective TOGETHER, with ONE owner. 2-4 takes neither.

**Live smoke PASS (operator, second two-human smoke).** HUD confined to its own half in both viewports, nothing outside its frame; priming live (HP/stamina full, mana empty at start); mana rises on hits; win/lose labels work; fps fine; zero manual `.tscn` edits and zero collateral. Source: `docs/playtest-log.md`, 2026-07-28 entry, operator's own hand.

**Smoke finding S1 -- pitch zone sits awkwardly dead-centre in both halves.** Operator's candidate is moving it left of the bars, but the DECISION IS DEFERRED -- he wants to try both arrangements across development phases and compare; the instrument is 2-6. No code change in 2-4; the P4 centre placement stands for now with this note against it.

**Smoke finding S2 -- card slots look small for legibility.** Judgement deferred until real card art exists (E3); not a DEBT E member 4 item -- that is telegraph legibility, this is HUD layout.

**Confirmed intentional, not findings:** basic attack costs no stamina (see the NEW OPEN DECISION below -- confirmed as shipped, standing behaviour, reopened for the E2 retro anyway); the debug overlay no longer prints actions (2-4/R3 retirement -- the per-player state inspector is 2-6's); attack-vs-roll relative speed is DEBT E until real animations.

**NEW OPEN DECISION (d) -- does the basic attack cost stamina? -- RESOLVED 2026-07-31 (see Session 2026-07-31 -- Docs pass, below): YES, it costs stamina. Original entry kept below for the record.** The operator's own playtest-log conclusion this session reads "attack not costing stamina is intentional" -- reconfirming the 1-4 ruling as SHIPPED, standing behaviour; this is NOT a bug and not a new finding. The operator nonetheless wants the question reopened at the GDD/design level for the E2 retrospective -- the two are not in conflict (current behaviour stands as correct until a design session says otherwise). The "do not re-raise" rule still binds story GATES (a gate may not reopen design on its own), but it does not bind the operator at GDD level. Owner/decision at the E2 retrospective. Cost if adopted: a third `StaminaPool.spend()` policy seat plus an affordability precondition with fallthrough and `action_rejected` (the 1-4 pattern), a balance field, tests, and a CERTAIN golden re-baseline since stamina values are in the snapshot.

**Open question parked for E6 -- is the pitch zone shared or per-player?** Undecided anywhere; what is locked is only that the pitched card is the sole PUBLIC information (P3) while hands are private.

**R-D6 smoke acceptance was RE-INVOKED by 2-4 and PASSED -> SPENT again**, available to the next story with a live smoke against a killable human slot.

**Doc debt note (no action).** Surviving `debug_state_overlay` / `DebugStateOverlay` references live only in CLOSED story files (1-3c, 1-7, 1-10) and in this append-only log. Those are history and are NOT rewritten.

**Same-session verification note.** The commit-chain review pass (D1) confirmed the AC2 priming guard is not vacuous: `connect_hero_hp_changed` / `connect_stamina_changed` / `connect_mana_changed`'s priming calls were stripped from `match_runner.gd`, `test_hud_viewports.gd` was re-run and FAILED (`primed_ok=false`), and the file was restored via `git checkout` with its SHA256 verified byte-for-byte identical before and after. No further review findings surfaced this session.

**Promotion.** Story Status and board promoted ready-for-dev -> done.

---

## Session 2026-07-28 -- Story 2-5 readiness gate (operator decisions)

Readiness gate on `2-5-face-down-opponent-hand.md` (backlog since the Set B batch) returned **NOT READY**. All findings resolved by operator decision (Matko, rulings 2-5/R1..2-5/R9) and applied to the story file the same session. Labels are story-scoped per the 1-9 convention.

**2-5/R1 (locked) -- RENDERED CARD COUNT IS A PRESENTATION-LOCAL CONSTANT 4.** No read of `PlayerState.hand`, no read of a `hand_size` field, no write to `hand`, no card widget bound to card data. Authority for the constant is the GDD statement that hand size is 4 at all times. `src/state/player_state.gd` already declares `var hand: Array = []`, permanently empty until epic 3, and `to_snapshot()` already emits `"hand_size": hand.size()`, currently 0 -- a golden trap, since making the rendered count "real" by populating `hand` would move the golden hash AND breach the epic-3 hold. Epic 3 makes the count data-driven; recorded as a named follow-up in Dev Notes, not a passing remark.

**2-5/R2 (locked) -- RENDERING THE OPPONENT ROW IS NOT AN OPPONENT READ.** Hand size is PUBLIC AND SYMMETRIC: both hands always hold the same number of cards and that number is public by design, so a constant (and later a balance-authored value, still symmetric) carries zero bits of the opponent's state. The per-slot bind in `hud_root.gd` remains the mechanism that makes opponent reads structurally impossible. CONSEQUENCE for the acceptance criteria: the criterion that asked for a grep of the HUD layer for cross-player `PlayerState` access is REMOVED as a mechanism and replaced by the assertion that a HUD root never receives the opposing slot at all.

**2-5/R3 (locked) -- TWO HAND ROWS PER VIEWPORT.** The own hand renders face-up on the bottom-centre strip already reserved by 2-4 (that strip is not moved or resized). The opponent hand renders face-down TOP-CENTRE, above the Pitch Zone placeholder, between the deck indicator on the left and the orb counters on the right. Opponent panels may be smaller than own panels, because card backs carry nothing to read. Nothing else in the reserved layout moves: not the bars, not the orb counters, not the pitch placeholder, not the deck indicator, not the round-over label. Rationale: the architecture doc requires the opponent hand to be renderable face-down in each viewport, and a single-row variant would leave the rule unexercised until epic 3; the design pillar of visible threat with uncertain delivery depends on seeing that the opponent holds resources. Exact placement and sizing are PROVISIONAL -- the A/B comparison of HUD placement across development phases belongs to story 2-6, which owns the instrumentation.

**2-5/R4 (locked) -- REVEAL-OPPONENT-HAND TOGGLE DEFERRED TO EPIC 3.** The acceptance criterion requiring the toggle is removed from 2-5. Reasons: there are no card faces to reveal, so the toggle could only flip blank placeholders to other blank placeholders; a guard test over it could not be proven to fail without it, and this project's standing rule is that every new guard must be demonstrated to FAIL when the thing it protects is removed (temporarily remove, measure the failure, restore byte-for-byte and verify with SHA256); and no debug flag exists anywhere in code (`FeatureFlags` carries only gameplay-layer booleans), so gating it would mean adding the first non-gameplay member to a gameplay-layer flags resource, against the established precedent that presentation configuration lives in its own resource outside the gameplay/balance surface. CONDITION OF THE DEFERRAL: the face-down rule must live in ONE SEAT in 2-5 -- a single parameter or branch that decides back-styling versus front-styling -- so that the epic-3 toggle is a flip of that parameter and not a second rule. `src/ui/debug/` stays empty. Permanent constraint recorded for whoever builds the toggle later: the input-only-in-controllers invariant scan covers all of `src/` and skips only paths containing `/controllers/`, so an `Input.` read inside `src/ui/debug/` WOULD fail the scan -- the trigger must arrive through a controller or a flag, never a direct input read in the UI layer.

**2-5/R5 -- ZERO NEW FILES UNDER `src/ui/`.** Both rows are built by `src/ui/hud/hud_root.gd` through one private construction function parameterised by whether the row is the owning slot's. The existing existence guard for `hud_root.gd` and the recursive banned-token scan over `src/ui/` already cover it; no new guard wiring is required. Extracting a separate file would be premature -- if `hud_root.gd` becomes unwieldy during the dev pass, that is a review question, not a spec change.

**2-5/R6 -- ZERO NEW OBSERVATION SEAMS, ZERO `.tscn` EDITS, STATIC CONSTRUCTION.** The rows are built once during setup, with no `_process`, no `_physics_process`, and no signal consumption -- exactly like the reserved footprint that preceded them. The seam family stays at seven plus the round-ended relay. Any `.tscn` edit is out of scope and would be a blocking review finding, because the Godot GUI editor is banned for this project.

**2-5/R7 -- TESTS GO INTO THE EXISTING `test/integration/test_hud_viewports.gd`.** The integration baseline stays at 8 files. Assertions: each viewport contains both rows; the own row is front-styled and the opponent row is back-styled; the two stylings are genuinely different rather than two identical blank panels. The new assertion must be PROVEN to fail without the back-styling -- temporarily remove it, measure the failure, restore the file byte-for-byte and verify with SHA256 -- otherwise the guard is vacuous.

**2-5/R8 -- GOLDEN HASH AND LIVE SMOKE SECTIONS.** The smoke runs on the SHIPPED configuration and therefore contains NO flip line; the committed main scene has no `slot_controller_kinds` line and the script default already gives two live killable human slots. The story RE-INVOKES the standing smoke-acceptance allowance (spent by 2-4) because the criteria can only be satisfied by an operator's live look: whether both rows fit inside a half-width viewport without overlapping the bars, the pitch zone, the orb counters or the deck indicator; and whether backs are distinguishable from fronts at a glance. The operator writes the playtest-log entry by hand, in `docs/playtest-log.md`, BEFORE the commit chain -- no agent ever writes it on the operator's behalf. Golden prediction: NONE, measured in BOTH directions -- 2-5 is presentation-only under `src/ui/`, consuming no new seam and touching no state code; what would move the hash is any write to `hand` or any new state-side field added to back the count, both epic-3-hold violations and stop-and-report, never a re-baseline. Baseline: golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2`, suite 156 state tests / 715 assertions plus 8 integration files run INDIVIDUALLY.

**2-5/R9 -- PITCH ZONE CRITERION REPHRASED NEUTRALLY.** The acceptance criterion naming the Pitch Zone is rephrased NEUTRALLY: the card staged in a Pitch Zone is the only public card. Whether the pitch zone is shared between players or owned per player is an epic-6 decision, undecided anywhere, and out of 2-5 scope. Decision-log labels for this story are 2-5/R1..R9; the previous story's descriptively named close-out entries are NOT corrected retroactively.

**Promotion.** All fixes applied to the story file the same session; story Status and board promoted backlog -> ready-for-dev.

---

## Session 2026-07-28 -- Story 2-5 close-out

**Dev pass outcome.** Two files changed: `src/ui/hud/hud_root.gd` (both hand rows, single-seat `_build_hand_row(is_own)` construction function, `_make_card_face_style(is_own)` styling) and `test/integration/test_hud_viewports.gd` (extended row/styling assertions). Suite: 156 state tests / 715 assertions PASS, including the determinism test proving the golden hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unmoved; all 8 integration files run INDIVIDUALLY and PASS. The `hand_size` positive control (`PlayerState.to_snapshot()` emitting `hand.size()`) is still zero -- `hand` is declared `[]` and never mutated anywhere in `src/`, confirming no epic-3-hold breach. Zero collateral: `git status --porcelain --untracked-files=all` at the start of this session showed exactly the three expected paths (`hud_root.gd`, `test_hud_viewports.gd`, `docs/playtest-log.md`), no `.tscn`, no `project.godot`, no untracked stray.

**2-5/R10 -- REVIEW FINDING: the first styling assertion was NON-DIRECTIONAL, fixed to pin direction.** The original guard in `test_hud_viewports.gd` proved only that the own and opponent card stylings DIFFERED -- swapping the two branches (showing the player's own hand as a back and the opponent's hand as a face) would still have passed, which is exactly the information leak 2-5 exists to prevent. Fix: `_check_hand_rows` now additionally requires `back_is_heavier` -- the face-down opponent back's border is STRICTLY heavier than the face-up own card's. Non-vacuity was proven by SWAPPING the two branches of `_make_card_face_style`: the run showed the difference check still TRUE but the new direction check FALSE, i.e. the whole guard FAILED -- demonstrating the old (difference-only) assertion would have passed the inversion. The mutated file was restored from a copy taken OUTSIDE the repo (never `git checkout`) and verified byte-for-byte via SHA256 before the suite was re-run.

**2-5/R11 -- MICRO-DECISION: the HudRoot constructor takes no slot argument at all.** `HudRoot._init()` (`src/ui/hud/hud_root.gd`) sets only `name = "HudRoot"` -- no parameter of any kind. AC3 ("no HUD root instance is ever constructed with the opposing slot's index") is therefore satisfied STRUCTURALLY: the constructor makes passing any slot, own or opposing, impossible in the first place. The pre-existing asymmetry assertion (rolling P1 moves only P1's HUD stamina bar) proves a DIFFERENT and more useful property -- that the runner's per-slot wiring in `match_runner.gd` is uncrossed -- and must not be read as proof of the acceptance criterion itself.

**2-5/R12 -- LAYOUT SLACK, measured from source.** Opponent row (`OpponentHandStrip`): container 236 px wide (offset_right 118 minus offset_left -118), four 52x64 panels plus three 8 px separations = 232 px of content, 4 px slack. Own row (`HandStrip`): container 344 px wide (172 minus -172), four 74x84 panels plus separations = 320 px of content, 24 px slack. Recorded so a later sizing or separation change has a documented margin before it collides with either container edge.

**Live smoke PASS (operator, two-human default, no flip line, no manual `.tscn` edit).** Source: `docs/playtest-log.md`, 2026-07-28 "2-5" entry, operator's own hand (Croatian). All UI in place and not colliding with itself; both rows rendered as designed; no unwanted overlaps; everything from earlier stories stayed where it was; fps stable. NO findings.

**Not a new finding -- the round-over label still persists after the debug (R) reset.** Observed again in this smoke. This is the previously recorded 2-4 close-out micro-decision behaving exactly as documented: `MatchState._apply_debug_reset` clears `_round_over` and heals both players but emits no signal, so the HUD's `on_round_ended` label handler has nothing to hook and never clears the label. Not owned by 2-5. Stays parked with the 2-3/R10 named gap for the epic-2 retrospective, ONE owner for both.

**R-D6 smoke acceptance was RE-INVOKED by 2-5 and PASSED -> SPENT again**, available to the next story with a live smoke against killable human slots.

**PERMANENT RULE (canonical home -- an agent's own memory is not).** During an uncommitted dev pass, a mutation made to prove a guard non-vacuous is restored from a copy taken OUTSIDE the repo, NEVER with `git checkout -- <file>` -- checkout wipes the entire uncommitted pass, not just the mutation. This happened once already (2-4's AC2 priming-guard proof) and was survived only because the reapplied work happened to reproduce byte-for-byte; it is not a method to rely on twice.

**NEW OPEN DECISION (e), no owner yet -- does the number of cards in a hand ever vary?** The operator's stated intent for epic 3 is a first version where the hand is always four and refills the moment a card is played, with variants (non-automatic draw, conditional draw, timed refill up to a maximum) explored later. This matters concretely: if the count never varies, the opponent's face-down row carries no information and epic 3 should delete it. Recorded suggestion, not a ruling: implement the refill as a delay value in ticks defaulting to zero, at a single seat, so the variants become an authored number rather than a new mechanic; a timed refill running against the melee heartbeat is a risk to the "one thing at a time" pillar. Same owner as the open question about the cost of the reshuffle vulnerable window; forcing point is the epic-3 story that introduces the deck.

**Promotion.** Story Status and board promoted ready-for-dev -> done.

---

## Session 2026-07-29 -- Story 2-6 readiness gate (operator decisions)

Readiness gate on `2-6-legibility-feel-instrumentation.md` (authored 2026-07-22 in the original Set B batch, before any code existed) returned **NOT READY**. The story described a different story than the one 2-6 actually is: only old AC3 (per-player state inspector) survives intact; old AC5 (end-to-end record/replay via `IntentRecorder`/`ReplayController`, including mid-round balance hot-reload) requires two classes absent from `src/` and pulls a deferred debt forward. The real 2-6 is six real defects/gaps found in the shipped E1/E2 code. All findings resolved by operator decision (Matko, rulings 2-6/R1..2-6/R13) and applied to the story file the same session. Labels are story-scoped per the 1-9 convention.

**2-6/R1 (locked) -- scope is a merge, not a replacement.** Final 2-6 = six blocks (round lifecycle, per-player inspector, dodge cue, variable analog magnitude toggle, Pitch Zone A/B, comment hygiene) plus the per-player inspector (old AC3) and the telegraph legibility protocol (old AC4), both retained and narrowed. Old AC1 (FeatureFlags toggle overlay) is narrowed; old AC2 (deterministic step/pause) and old AC5 (record/replay) are re-homed out of the story entirely.

**2-6/R2 -- old AC5 (record/replay + mid-round balance hot-reload) REROUTED, not deleted.** It leaves 2-6 entirely and is re-homed to the future story that lands `IntentRecorder`, which already inherits the four-field contact-fact contract (1-8's D-4 supersession) and the second half of DEBT B (reload events recorded into the intent stream, per the Session 2026-07-22 Story 1-1 close-out entry) -- one stream contract, one owner. That story does not exist yet; no story file is created for it here. FORCING POINT: the E3 planning pass, where the `IntentRecorder` story takes a board slot alongside the `epics.md` story stubs -- an owner without a forcing point is how a debt goes quiet.

**2-6/R3 -- old AC2 (deterministic step/pause) REROUTED, not deleted.** Re-homed to the future rig story: it requires new `project.godot` Input Map actions (a reviewed project.godot edit), and its value as a debugging tool only arrives once real animations exist to step through.

**2-6/R4 (locked) -- old AC1 NARROWED into a presentation/controller-local instrument panel.** The instrument panel built for AC 4/5 (below) may flip ONLY presentation-local and controller-local switches -- never a `FeatureFlags` member. `FeatureFlags` stays load-once and runtime-immutable, unchanged from its 1-5 injection contract. Reason: flags appear in neither `MatchState.to_snapshot()` nor the recorded intent stream, so mutating one at runtime would be a silent replay hole.

**2-6/R5 (locked) -- reset visibility ships as `EventBus.round_started`, NOT a new runner connect seam, NOT `round_reset`.** The label's SET and its CLEAR must live at exactly one seat each (both on `HudRoot`); `round_ended` already travels over the bus this way; `round_started` also serves the real round lifecycle when best-of-three arrives, with no rename needed then. The signal takes NO prime-on-connect: the label starts hidden and a primed emission would let a guard pass even if the real hide-on-event wiring were never built -- the same vacuous-guard shape the 2-5/R10 styling-direction fix exists to warn against. Written into the AC as an explicit prohibition.

**2-6/R6 (locked) -- the guard sits as step 1b, AFTER the reset step, no hoist.** The reset stays step 1 and the documented `advance()` dispatch order is preserved. The tick counter still increments while the round is frozen, so a reset on tick N stays deterministic. MANDATORY AC: round over, then debug reset, then the match CONTINUES -- movement resolves again and the latch is clear, on the SAME tick as the reset. Both new guards (the early return, and the label clear) must be proven to FAIL without their fix; any mutation proof restores from a copy taken OUTSIDE the repo, never `git checkout --` (the 2-4/2-5 precedent, "PERMANENT RULE" above).

**2-6/R5+R6 STATUS -- the 2-3/R10 and 2-4-close-out MICRO-DECISION-1 named gaps are RETIRED by this story.** Both were parked for "the E2 retrospective, ONE owner" -- 2-6 is that owner. They close together because they share one root cause: nothing in the round lifecycle previously signalled a RESET, only an END.

**2-6/R7 (locked) -- NO EIGHTH SEAM.** The per-player inspector displays only what the seven existing observation seams already carry. The active-`TimingWindow` countdown from old AC3 is DEFERRED to the future rig story: streaming raw window ticks every tick would be a firehose through the D5 queued-drain path and would hand the state layer's internals to presentation. Old AC3 is rewritten to no longer promise a window countdown.

**2-6/R8 (locked) -- variable analog magnitude is an authored `GamepadProfile` field, NOT a `FeatureFlags` member.** Default `true` = today's normalize-to-unit-length behaviour, same seat that already owns the button mapping and the deadzone. Replay stays safe: the resulting magnitude lives inside the recorded `move_dir`, never a separately recorded flag. `src/state/` is untouched. NO verdict on whether variable magnitude feels right is rendered -- that judgement is animation-gated and belongs to the future rig story.

**2-6/R9 (locked) -- Pitch Zone A/B is placeholder geometry only; the toggle's shared shape decides nothing about the mechanic.** The pitch state carries no content until E6. The A/B must NOT anchor to `OpponentHandStrip` (2-5's face-down row), which is provisional and may be deleted in E3. The instrument-panel toggle is SHARED (one switch, both viewports) purely for A/B COMPARABILITY -- both viewports must show the same candidate placement at once for the comparison to mean anything. Whether the eventual Pitch Zone MECHANIC is shared between players or owned per-player remains OPEN, reserved for E6, and is NOT decided here. THE VERDICT IS NOT RENDERED IN 2-6 -- the AC delivers the toggle and the first reading, nothing more.

**2-6/R10 -- comment hygiene: exactly one line.** `test/state/test_contact_resolution.gd`'s `facing updates from raw intent` comment (on `test_authored_zero_multiplier_is_full_root_but_facing_untouched`) predates the 1-7 review R1 world-space-planar facing decision and is now imprecise -- facing derives from the runner's camera-rotated `world_dir`, not literally raw intent; the test's zero camera-rotation fixture just makes the two coincide. The other stale comments previously suspected at earlier gates were already fixed in commit `843e33a`; do not roam.

**2-6/R11 (locked) -- the legibility protocol goes into a SEPARATE new docs file, NEVER `docs/playtest-log.md`.** That log is written by hand by the operator alone; no agent writes into it. An AC may require an operator playtest-log entry; no AC may have an agent produce one.

**2-6/R12 -- live-smoke acceptance RE-INVOKED on 2-6; Golden prediction NONE for all six blocks, measured in BOTH directions.** Block 1's symptoms are live-only: the recorded determinism sequence never reaches a round-over (P1 ends 108/120 HP, P2 ends 117/120 HP), so the golden CANNOT prove Block 1 -- it rests entirely on the new dedicated tests plus the live smoke.

**2-6/R13 -- architecture amendment queue grows by one member -- SIXTH, not fifth.** The standing queue already carried FIVE members (per the 2-4/R1 entry): the 2-4 observation-seam amendment (the locked seam family grew from four to seven), the world-space facing contract, `null_controller.gd` in the Directory Tree, the A3 stale-label cleanup, and the gamepad exception to "named actions, never raw". It gains a SIXTH here: the new `EventBus.round_started` signal plus the seam-registry text documenting it. Queued; NOT edited into `docs/game-architecture.md` this session.

**Promotion.** All fixes applied to the story file the same session; story Status and board promoted backlog -> ready-for-dev.

---

## Session 2026-07-29 -- Story 2-6 close-out

**What landed (cf4d53d code+tests / 4a0dbc8 docs+smoke / aa35ad1 board+status).** Implementation exactly as gated -- rulings 2-6/R1..2-6/R13 implemented as ruled, nothing reopened. Suite: 164 state tests / 759 assertions PASS (up from the 156/715 baseline); golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unmoved, measured in BOTH directions. All 9 integration files (8 baseline + the new `test_debug_instruments.gd`) run INDIVIDUALLY and PASS.

**New rulings, continuing from 2-6/R13:**

**2-6/R14 -- OPERATOR MICRO-DECISION: the round-over freeze HALTS BOTH heroes, not just the loser.** Block 1's step-1b freeze skips `_resolve_movement`, so the 2-3/R14 every-tick corpse-velocity-zeroing no longer runs -- and the runner drives `velocity` into `move_and_slide()` every physics frame regardless of the early return, so a hero moving at the kill instant would otherwise slide forever. Resolution: step 1b zeroes BOTH heroes' velocity on every frozen tick (the 2-3/R14 reason honoured in step 1b instead of step 3) and skips facing (display-only, the standing asymmetry rule). The 2-3/R13 one-tick carry survives unchanged: the kill tick resolves movement at step 3 and DEAD is set at step 8, so the freeze only begins the NEXT tick -- the corpse still carries its final velocity for exactly that one tick before step 1b zeroes it. The `_end_round`-zeroing alternative (zeroing at the moment `_round_over` flips true, inside `_end_round` itself) was REJECTED -- it would erase the R13 carry by construction. Confirmed live at the smoke: a hero killed while moving does not slide.

**2-6/R15 -- the 2-3 DEAD-residual rulings are SUPERSEDED by the freeze; six tests annotated; removal vs retention DEFERRED.** Block 1 retires the "post-round-over live match" (2-6/R5+R6), so a DEAD hero always implies `_round_over` and step 1b returns before steps 2-8 run at all. Every 2-3 DEAD-residual branch is therefore UNREACHABLE via `advance()`: the `_resolve_movement` DEAD velocity-zero + facing-skip (2-3/R5/R13/R14), the `_regen_stamina` DEAD suppression (2-3/R5), and both fact drops in `_resolve_contacts` (DEAD-target 1-7, DEAD-attacker 2-3/R6). Their guarding tests now prove the FREEZE, not the DEAD branch, and are annotated `STORY 2-6 SUPERSESSION` in place rather than rewritten from scratch: `test_dead_hero_velocity_zeroed_every_tick`, `test_dead_hero_facing_frozen`, `test_dead_hero_stamina_does_not_regen`, `test_dead_attacker_in_flight_window_delivers_nothing`, `test_dead_hero_row_accepts_no_input`, and the rewritten `test_no_corpse_mana_farming_under_round_over_freeze`. The dead code itself is NOT touched by this story -- the branches are left in place as defensive dead code, and removal-vs-retention is deferred (see R16).

**2-6/R16 -- architecture amendment queue grows 6 -> SEVEN.** The queue already carried SIX members (per 2-6/R13): the 2-4 observation-seam amendment (the locked seam family, four -> seven), the world-space facing contract, `null_controller.gd` in the Directory Tree, the A3 stale-label cleanup, the gamepad exception to "named actions, never raw", and `EventBus.round_started` plus its seam-registry text. It gains a SEVENTH here, from R15 above: the 2-3 DEAD-residual branches (`_resolve_movement` DEAD velocity/facing, `_regen_stamina` DEAD suppression, both `_resolve_contacts` fact drops) are unreachable under the 2-6 round-over freeze -- decide removal vs retention. Forcing point for the whole queue: the E2 close-out docs commit (next). Queued; NOT edited into `docs/game-architecture.md` this session.

**2-6/R17 -- AC 3 (dodge cue) was MOOT; confirmed, not built.** The roll telegraph was ALREADY a distinct shape (`RollDisc`) and sting (`StingRoll`) as of story 1-10, so 1-10/R2's "distinct dodge cue" deferral had nothing left to defer. 2-6 only CONFIRMS and PINS the existing distinctness (`test_telegraph_profiles.gd`, proven to bite by mutation -- sharing attack's shape fails it); no code or data changed.

**2-6/R18 -- AC 4 (variable analog magnitude) is NOT smoke-verifiable, as anticipated by R12.** The shipped default is two KEYBOARD slots, so no `GamepadController` exists in the smoke to read `normalize_move_magnitude`, and there is no connected pad; exercising the toggle's gameplay EFFECT would require both a physical pad and a `.tscn` slot flip, which AC 8 forbids. The smoke confirmed only that the switch is present and toggles; the switch's WIRING (that the panel's `load()` and a controller's `_profile` are the same shared resource instance) is content-verified headlessly by `test_panel_and_controller_share_the_same_profile_instance`, not left an assumption. The gameplay-feel verdict stays deferred to the future rig story, same as R8 already said.

**2-6/R19 -- smoke findings, all non-blocking.** S4: the Pitch Zone at anchor B (left of the vitals bars) reads BETTER than dead-centre anchor A. This is a FIRST A/B reading only -- the verdict stays OPEN for E6 (R9 already reserved the mechanic-level shared-vs-per-player question, and this finding touches neither). S6: the instrument panel is readable and clear of the HUD after the S1/S2 placement fix, but visually ugly. Cosmetic, no owner. S8: the attack sting and the block sting are more similar to each other than either is to the roll sting -- all three cues still read correctly and in time in this rehearsal, but SHAPE carried the read more than sound did, so by ear alone attack-vs-block is a weak discrimination. Owner: the DEBT E "legibility under 0.5s" member on the future rig story.

**2-6/R20 -- AC 7 ran as a DRY RUN of the procedure only; the definitive verdict stays animation-gated.** The operator was solo for the live smoke, so the protocol's naive-observer requirement (step 3 of the procedure itself) was not met -- the deviation is recorded in the result table per the protocol's own deviation requirement, not silently absorbed. The definitive legibility verdict (identify-before-resolve, reliably, by someone who does not know the cue set) stays owned by the future rig story, DEBT E "legibility under 0.5s". The protocol file itself (`docs/legibility-protocol.md`) is delivered and pinned as the repeatable procedure, independent of this run's verdict.

**2-6/R21 -- R-D6 live-smoke acceptance RE-INVOKED on 2-6, PASSED (the FOURTH two-human smoke), SPENT again.** Available to the next story with a live smoke against killable human slots.

**2-6/R22 -- Golden unmoved, measured in both directions, the SIXTH consecutive story.** Hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unchanged since 1-9. As predicted by R12 (NONE, both directions), the golden cannot prove Block 1 -- the recorded fixture sequence never reaches a round-over.

**E2 COMPLETE at 6/6.** Stories 2-1 through 2-6 all done. Next: the E2 close-out docs commit (the seven-member architecture amendment queue gets resolved or explicitly carried forward), then the E3 planning pass.

**Promotion.** Story Status and board promoted ready-for-dev -> done.

---

## Session 2026-07-30 -- E2 close-out

**E2-CO/R1 -- arch amendment queue flushed into `docs/game-architecture.md`, commit `f80f90e`.** Seven amendments landed: (1) observation seam registry (D5) -- four combat seams plus three economy seams (2-4) that prime on connect; (2) world-space facing contract (Spatial Model) -- `HeroState.facing` is world-space planar, contact-fact direction computed from positions, single yaw source in `HeroActor.drive()`; (3) `null_controller.gd` added to the Directory Tree; (4) the stale A3 label fixed with the current `slot_controller_kinds` default; (5) the gamepad exception to the Input Map named-actions rule (Engine-Provided Architecture); (6) `EventBus.round_started` documented alongside `round_ended`, plus a "no eighth seam" note; (7) the `advance()` ladder marked current with the story 2-6 step-1b round-over freeze. Ledger entry A4 (v1.3, 2026-07-30) added to the Post-Completion Amendments section, and the frontmatter `version` bumped `1.2 -> 1.3`.

**E2-CO/R2 -- correction to the queue's own description.** Amendment 1 was carried through the queue (2-6/R16) as "seam family 4 -> 7," but verified by content this session: the document contained **no** seam-family text at all before `f80f90e` -- no `connect_hero_*` names, no seam count anywhere. It was a pure addition, not a count change. Recorded here so the queue's own history is not misread as an edit to existing text.

**E2-CO/R3 -- the ladder head was stale independently of the queue.** The doc claimed step 1 ingests each player's full `InputIntent`; the code applies **only** the debug reset at step 1 (intent-carried, story 1-7 / D-2, so the mutation stays inside the ordered dispatch and rides the recorded intent stream for free), while `move_dir` and attack/block/roll are read by `_resolve_actions` at step 3. Corrected in `f80f90e`. Steps 1-8 were **not** renumbered -- this log and the stories reference "step 3/4/5" throughout. There is no step 1a: the reset **is** step 1, and 1b sits immediately after it.

**E2-CO/R4 -- RULING, queue member 7 (the 2-3 DEAD-residual branches made unreachable by the story 2-6 step 1b freeze).** DECISION: the code is KEPT, unchanged, and RECLASSIFIED. It is no longer dead code awaiting deletion; it is the contract of the individual step functions (`_resolve_movement`, `_regen_stamina`, `_resolve_contacts`), not the contract of `advance()`. The branches remain reachable by calling those functions directly. Rationale: (1) unreachability is a property of the current two-slot configuration, not of the code -- a third slot, team play, or a victory-lap rule revives them; (2) the branches are the only EXECUTABLE record of the 2-3 asymmetry ruling (a field read downstream must be WRITTEN, a display-only field may be SKIPPED), which took two wrong spec versions to derive. REJECTED alternative: deleting them now -- irreversible, and resting on a one-day-old invariant. OPEN CONSEQUENCE WITH OWNER: the six tests annotated STORY 2-6 SUPERSESSION remain VACUOUS -- they pass because of step 1b, not because of the DEAD branches, and this repo has twice ruled a vacuous guard blocking (2-4/D1, 2-6/D1). Owner and scheduling = E3 planning pass. Intended fix: repoint those six tests from `advance()` to direct calls on the step functions with a hand-constructed state (hero DEAD, `_round_over` false), so that mutating the DEAD branch makes them FAIL again. Fallback if declined: delete the tests AND the code together -- never the code without the tests.

**E2-CO/R5 -- evidence for R4, verified by content.** `ActionState.DEAD` has exactly ONE assignment site, `match_state.gd:563` inside `_end_round()`, which sets `_round_over = true` immediately above at line 562; `_end_round` is called only from `_check_resolution` (step 8). DEAD therefore never exists without `_round_over` in the same `advance()` call, so "unreachable via `advance()`" needs no narrowing.

**E2-CO/R6 -- `DebugInstrumentPanel` micro-decision, promoted from the 2-6 story file (line 174) to canonical record.** It is the first window-global `Control` since the retired 1-3c debug overlay, parented to the runner root rather than to a `SubViewport`, and its placement is machine-locked by `test_debug_instruments.gd`, which asserts the panel's global rect lies inside the window rect and intersects neither `HudRoot` children nor `StateInspector` in either half.

**E2-CO/R7 -- board debt found during this flush.** `docs/implementation-artifacts/sprint-status.yaml` carries `epic-1: backlog` (line 39) and `epic-2: backlog` (line 55) while E1 and E2 are both complete. Both flip in a separate board commit.

**E2-CO/R8 -- state at close.** E2 complete 6/6. Suite: 164 state tests / 759 assertions, plus 9 integration files. Golden unmoved and measured in both directions, six times running.

**E2-CO/R9 -- process note.** Two browser-side claims were overturned by content this session (that the A3 amendment had not been applied -- it had, as an addendum to the existing A3 entry; and that the ladder carried a duplicated "Ingest intents" line -- it did not). Repo-content dispute score 10:0 for the CC side. Standing lesson: an Update/Write render is not a diff -- added-vs-replaced is judged only from `git diff`.

---

## Session 2026-07-30 -- E3 planning

**E3-P/R1 -- Pass scope.** Five items land in one docs commit: epics stubs (Committed obligations added to E3/E4/E5/E6 in `epics.md`); stories-manual sync (E1.S2 / E2.S1 item 4 camera wording corrected); `IntentRecorder` board slot; rig story split + board slots (`3-0a-rig-adoption`, `3-0b-feel-and-timing-tuning`); supersession de-vacuization schedule. The E3 revisit gate stays closed until all five are closed; this commit closes them, with two scheduled follow-ups that precede the gates they feed: the corrective pass (E3-P/R4) and Matko-authored rig story files (E3-P/R6).

**E3-P/R2 -- DEBT E split across two rig stories -- SCOPE NOTE ADDED 2026-07-31 (see Session 2026-07-31 -- E3 revisit gate (outcome), below, decision-log E3-RG/R7): the "land here and only here" Input Map wording below binds only 3-0b's step/pause actions — it was never meant to freeze the Input Map for the whole epic, and 3-5 may add its own card actions under the same discipline. Original entry kept below for the record.** ADOPTION (`3-0a-rig-adoption`): first models + AnimationPlayer in `hero.tscn`; DECISION A intact (hero root never rotates; `test_root_rotation_isolation.gd` must survive); formally triggers DEBT E inheritance but its ACs cover only the substrate + guards. TUNING (`3-0b-feel-and-timing-tuning`): the five DEBT E judgments (1-3c final playtest timing judgment; 1-5 B6 per-phase movement multipliers; 1-7 attack-lunge root motion; legibility <0.5s shape+sound validation incl. pose/silhouette distinctness, `pose_id` consumption, and smoke finding S8 -- attack and block stings too similar by ear; OPEN decision (c) variable analog magnitude judgment) + deterministic step/pause (2-6/R3; the new `project.godot` Input Map actions land here and only here) + window countdown (2-6/R7) + the real AC7 legibility run with a naive observer. Amendment to the DEBT E trigger rule (1-10/R4): inheritance is split exactly this way so the adoption story does not re-inherit all seven items.

**E3-P/R3 -- `IntentRecorder` story: board slot only** (`3-0c-intent-recorder`). The story FILE is deliberately not authored now (Set B staleness lesson -- story files written long before their dev pass go stale) and will be written just-in-time at its own creation pass. Its contract, by content: consumes the four-field contact fact `[attacker_slot, target_slot, attack_index, world-space direction target->attacker]` computed by the runner from positions (1-8 D-4 supersession); carries BOTH halves of DEBT B (`ResourceLoader` with `CACHE_MODE_IGNORE`; reload event in the intent stream; X5: replay = seed + intents + reload events, never re-read from disk); carries record/replay + mid-round reload per 2-6/R2.

**E3-P/R4 -- Supersession de-vacuization schedule (executes E2-CO/R4).** A lightweight test-only corrective pass runs immediately after this commit, BEFORE the rig adoption story. The six SUPERSESSION-annotated tests --
- `test/state/test_contact_pipeline.gd :: test_dead_hero_row_accepts_no_input`
- `test/state/test_contact_pipeline.gd :: test_no_corpse_mana_farming_under_round_over_freeze`
- `test/state/test_contact_resolution.gd :: test_dead_attacker_in_flight_window_delivers_nothing`
- `test/state/test_match_state.gd :: test_dead_hero_velocity_zeroed_every_tick`
- `test/state/test_match_state.gd :: test_dead_hero_facing_frozen`
- `test/state/test_stamina_economy.gd :: test_dead_hero_stamina_does_not_regen`

move from `advance()` to direct step-function calls on manually constructed state (DEAD hero, `_round_over` false); each test must be proven to FAIL under mutation of the branch it guards (restore from a copy outside the repo, SHA256-verified). Two commits: "test:" + a decision-log record. The full story ritual is waived: the ruling was already made at E2-CO/R4 and mutation proofs replace review. Fallback unchanged: delete tests AND code together, never code without tests.

**E3-P/R5 -- stories-manual sync executed.** Corrected lines:
- `stories-manual-e1.md` E1.S2 item 1: "Camera distance/height/pitch are authored in `data/camera_config.tres` -- presentation-side, load-once, outside `BalanceConfig` and outside the X3 hot-reload path (2-1 micro-decision, review-accepted) -- not literals in the scene script."
- `stories-manual-e2.md` E2.S1 item 4: "Adjust the camera values authored in `data/camera_config.tres` -- presentation-side, load-once, outside `BalanceConfig` and outside the X3 hot-reload path (2-1 micro-decision, review-accepted); if the pulled-back framing does not survive half width, that is a finding worth logging in `decision-log.md`, not silently zooming in."

**E3-P/R6 -- Rig story authorship.** Matko writes both story files himself -- adoption immediately after this commit as its own separate docs commit, tuning just-in-time before its turn. Both must include Golden Prediction and Live Smoke sections from the first draft (Set B files have lacked both sections six times running).

---

## Session 2026-07-30 -- Supersession de-vacuization (executes E3-P/R4)

**SDV/R1 -- Pass shape and sanction.** Test-only corrective pass, run outside the full story ritual per E2-CO/R4 and E3-P/R4 (ritual waived: the ruling was already made, mutation proofs replace review; unlike a dev pass, this pass DOES commit at the end). `src/` stayed byte-identical throughout -- both source files restored from an out-of-repo copy and SHA256-verified after every mutation, NEVER `git checkout --` (the standing 2-4/2-5 rule). Two commits: `3abb525` (test/, six tests repointed) and this decision-log record.

**SDV/R2 -- Test -> branch mapping (each of the six SUPERSESSION tests now pins its DEAD step-function branch by a DIRECT call).**
| Test | Step function | Guarded branch | Site |
| --- | --- | --- | --- |
| `test_dead_hero_velocity_zeroed_every_tick` | `_resolve_movement` | DEAD velocity-zero WRITE | `match_state.gd` 480 |
| `test_dead_hero_facing_frozen` | `_resolve_movement` | DEAD facing SKIP (early return) | `match_state.gd` 481 |
| `test_dead_hero_row_accepts_no_input` | `_resolve_actions` | empty `&"dead": {}` table row | `hero_state.gd` 66 |
| `test_dead_target_fact_dropped_no_corpse_mana` | `_resolve_contacts` | DEAD-target drop | `match_state.gd` 393-394 |
| `test_dead_attacker_in_flight_window_delivers_nothing` | `_resolve_contacts` | DEAD-attacker drop | `match_state.gd` 402-403 |
| `test_dead_hero_stamina_does_not_regen` | `_regen_stamina` | DEAD suppression clause | `match_state.gd` 465-466 |

Route in every case: force the hero DEAD via `set_action_state(DEAD)` (which never touches `_round_over`, so the state is DEAD-with-`_round_over`-false -- a combination `advance()` cannot produce, which is exactly the point), then call the step function directly. E2-CO/R5's single-write-site fact (`match_state.gd:563`, `_round_over = true` immediately above) underpins the "advance() cannot produce this" claim, re-verified this session.

**SDV/R3 -- Mutation evidence (the acceptance criterion; each branch mutated in isolation from an out-of-repo copy, mapped test proven to FAIL, src restored + SHA256-verified between mutations).**
- M1 (delete the velocity-zero write): `test_dead_hero_velocity_zeroed_every_tick` FAILS ("velocity EXPLICITLY written to zero..."); `test_dead_hero_facing_frozen` stays GREEN -- the write and the skip are independent halves of the 2-3 asymmetry.
- M2 (delete the DEAD-branch early `return`): `test_dead_hero_facing_frozen` FAILS ("facing write SKIPPED..."); the velocity test also trips (fall-through overwrites velocity), as expected.
- M3 (add `&"attack": ActionState.ATTACKING` to the `&"dead"` row): `test_dead_hero_row_accepts_no_input` FAILS (state got 1/ATTACKING, expected 6/DEAD; fired 1, expected 0); `test_action_state.gd`'s inbound-edge enumeration also caught it -- independent corroboration.
- M4 (delete the DEAD-target drop): `test_dead_target_fact_dropped_no_corpse_mana` FAILS (confirmed hit 1, P2 HP 0.0, hit_landed fired); the DEAD-attacker test stays GREEN.
- M5 (delete the DEAD-attacker drop): `test_dead_attacker_in_flight_window_delivers_nothing` FAILS (confirmed 1, HP 94.0, mana 8.0, hit_landed fired); the DEAD-target test stays GREEN -- the two contact drops isolate cleanly both ways.
- M6 (drop `or state == HeroState.ActionState.DEAD` from the regen suppression): `test_dead_hero_stamina_does_not_regen` FAILS (stamina 34.0 = 30 + 4 x 1.0/tick, expected 30.0).

**SDV/R4 -- Micro-decision: `test_no_corpse_mana_farming_under_round_over_freeze` was vacuous in a STRONGER sense than the other five, and is RENAMED, not merely repointed.** The E3-P/R4 caution flagged it as possibly a step-1b freeze test (round_over TRUE its point). Verified by content: post-kill it was DOUBLY BACKSTOPPED -- removing step 1b alone left the DEAD-target drop as backstop, and removing the DEAD-target drop alone left step 1b -- so NO single-branch mutation could make it fail. Separately, the step-1b freeze is ALREADY comprehensively guarded (both heroes' velocity zeroed, facing skip, press-ignored, tick-increment, with its own MUTATION PROOF A/B) by `test_round_over_freezes_resolution_until_reset`. Its honest, isolable, otherwise-unguarded branch is therefore the `_resolve_contacts` DEAD-target drop. Repointed there and RENAMED `test_dead_target_fact_dropped_no_corpse_mana` -- the `_under_round_over_freeze` name would lie about the mechanism. This is E2-CO/R4's directive applied thoughtfully, not blindly, and satisfies it for all six.

**SDV/R5 -- Micro-decision: the contact tests feed the step-4 result to the step-5 mana seat.** `_resolve_contacts` returns confirmed-hit slots; mana is added in `advance()` step 5 by `_generate_mana(confirmed)`, NOT inside `_resolve_contacts`. So each contact test calls `_resolve_contacts()` then `_generate_mana(confirmed)`, and asserts BOTH `confirmed.size() == 0` and mana unchanged -- otherwise a fact resolved under mutation would still show no mana growth (step 5 unreached) and the "no mana" assertion would not bite. Confirmed by M5: mana reached 8.0 under the DEAD-attacker mutation.

**SDV/R6 -- One test helper added (`test_match_state.gd::_move_intent`).** A one-line `InputIntent` builder carrying only `move_dir`, for the two direct `_resolve_movement` calls. Test-file-local; no `src/` or public-API change.

**SDV/R7 -- Final state.** `src/` byte-identical (`match_state.gd` SHA `9B13F7CA..7296`, `hero_state.gd` SHA `357C8951..FB9E`, both verified equal to the pre-pass value at close; `git status -- src/` empty). Suite GREEN: 164 state tests / 760 assertions (was 759; +1 net from the rewrites -- test COUNT unchanged, the rename is a repoint, not an add/remove), all 9 integration files individually PASS. Golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` UNMOVED and asserted green by `test_state_matches_golden`; NO re-baseline (`test_determinism.gd` never touched). No collateral: `project.godot`, `main.tscn`, and every `.tres` untouched.

---

## Session 2026-07-30 -- 3-0a gate rulings

The `3-0a-rig-adoption` story's readiness gate returned NOT READY with three blocking findings (B1-B3) and four notes (N1-N4). The gate also found a second integration test the story's first draft never named -- `test/integration/test_visible_facing.gd`, which pins mesh yaw == hitbox yaw and hard-wires `_mesh = _p1.get_node("Mesh")` typed `MeshInstance3D` -- a miss by the story's author, corrected below. Eight rulings resolve the gate; the story is promoted to `ready-for-dev` on this session's commit.

**3-0a/R1 -- resolves B1: the `Mesh` node SURVIVES; only its box geometry goes.** Verified by content: `test_visible_facing.gd:31` hard-wires `_mesh = _p1.get_node("Mesh")` typed `MeshInstance3D`, and `_check_phase` pins `mesh.rotation.y == hitbox.rotation.y`. Ruling: `hero.tscn` keeps a node named exactly `Mesh`, typed `MeshInstance3D`, in the same parent position, still the yaw sink `drive()` rotates -- only the `BoxMesh_6plks` resource assignment is removed, and the paladin is parented under that node. AC3 reworded: "deleted, not hidden" applies to the box geometry, not the node. AC5 names `test_visible_facing.gd` as a co-equal DECISION-A / single-yaw guard alongside `test_root_rotation_isolation.gd`. Neither that test, nor `hero.gd`'s `$Mesh` reference, nor `drive()`'s yaw logic is edited by this story; the Project Structure Notes line claiming the `$Mesh` reference "may need adjusting" is corrected -- under this ruling it does not, confirmed against the current repo state.

**3-0a/R2 -- resolves B2: the `run` clip is PUSHED from `drive()`, not polled or seam-fired.** The action-state seam only fires on a state transition; velocity crosses the run threshold with no transition, so the telegraph pattern cannot express this selection -- the story's claim that `run` selection follows that pattern was false at exactly this point, corrected in AC4. Ruling: `HeroActor.drive()` (`hero.gd:25`, called every tick from `match_runner.gd:337-338`) already runs every tick regardless of state; it passes the velocity magnitude to `animation_controller.gd` as a payload on that existing call -- no `_process`, no second `_physics_process` (F1 intact), no new seam, no state handle, a float, not a handle. `hero.gd` is in scope for this call only. The threshold value is not authored or tuned here (3-0b).

**3-0a/R3 -- resolves B3: the Godot editor is EXPLICITLY AUTHORIZED for this story.** The "editor closed" rule prevents unnoticed collateral, not the editor itself; assembling six clips into one `AnimationPlayer` is editor work. Ruling: the dev pass may open the editor for asset import and `AnimationPlayer` assembly, under a mandatory protocol: `git status`/`git diff` immediately after every editor session; `project.godot` restored if the `physics_ticks_per_second` pin or `config/features` ordering moved (the fifth recorded editor-collateral incident); the resulting `.tscn` diff reviewed node by node before staging; the assembly route actually used named in the Dev Agent Record; any `.res`/`.tres` animation files produced committed with the assets. AC3's "textually with the editor closed" clause still governs hand edits of `.tscn`/config files -- it no longer forbids the `AnimationPlayer` build specifically.

**3-0a/R4 -- resolves the "provable by neither" gap: AC3 gets a proof path.** The gate found AC3's six-clip count, loop matrix, and `mixamo_com` exclusion provable neither headlessly nor by the smoke, since the imported `.scn` is RSCC-compressed. Ruling: the dev pass adds a headless integration test (named per the `test/integration/` convention) that instantiates `hero.tscn` and asserts exactly six animations, the six expected names, each clip's loop flag, and the absence of a `mixamo_com` clip -- proven by mutation per the standing new-guard rule. Folded into AC3 as an AC-level requirement, not a task footnote.

**3-0a/R5 -- resolves N4: clip-end and mid-clip policy, at adoption level only.** A non-looping clip that ends while its state persists HOLDS its final pose; it does not auto-return to idle. A state transition arriving mid-clip wins immediately, with no blending. Written into AC4. Blending, cancel windows, and how any of this feels are 3-0b's.

**3-0a/R6 -- resolves N1: the asset size claim was wrong.** The gate measured the real total (7 FBX + 3 PNG source files) at ~20.3 MB against the story's stated 11.4 MB; verified by content (byte sum of the committed source files). AC1 corrected to ~20.3 MB. The no-LFS ruling STANDS at the corrected size -- settled here so it is not re-litigated.

**3-0a/R7 -- resolves N2: `FacingMarker` (a child of `Mesh`) survives the change, hidden.** The prism-nose directional marker from 1-7b is redundant once a real model is present. Ruling: keep the node, set `visible = false`, do not remove it. Recorded as a micro-decision in Dev Notes; confirmed by content search that no test references `FacingMarker`.

**3-0a/R8 -- resolves N3: `.gitattributes` gains explicit binary rules before the assets are committed.** `*.fbx binary` and `*.png binary`, added as a task; the `.gitattributes` edit itself lands with the asset/code chain, not this docs commit. Verified by content: the current `.gitattributes` declares only text-normalization rules (`*.gd`, `*.tres`, `*.tscn`, `*.import`, `*.uid`, `*.godot`, `*.cfg`), nothing binary.

---

## Session 2026-07-31 -- 3-0a fix pass (R9-R12)

Docs-only fix pass resolving the review's two blocking findings (B1: AC6's unsatisfiable zero-root-motion claim; B2: empty Dev Agent Record) via four rulings. No code, asset, or `.import` change; the dev pass working tree is untouched. Full detail lives in `docs/implementation-artifacts/3-0a-rig-adoption.md` (Change Log v0.3); this entry records the amendment-queue growth only.

**3-0a/R10 -- architecture amendment queue grows by two, plus the pre-existing item carried forward.** The queue was last flushed at E2-CO/R1 (commit `f80f90e`) and has not been re-flushed since. Verified by content this session: `docs/game-architecture.md`'s Directory Tree (`### Directory Tree`, line ~535) DOES list `assets/` as a top-level entry (line 585, unlike the earlier working assumption that it was absent outright) -- but unlike every sibling (`src/`, `data/`, `test/`), it is a single unexpanded line ("art · audio (feeds CombatCues bus) · models · materials") with no itemized children. That gap -- `assets/` not expanded into its actual subdirectory structure -- is the queue's pre-existing item, carried forward, now sharpened by content rather than assumed. It gains TWO new members from the 3-0a fix pass:
  1. **Import post-processing as a repo pattern** -- `assets/characters/paladin/strip_model_anim.gd`, an `EditorScenePostImport` `@tool` script substituted (3-0a/R10 in the story file) for the model import setting `animation/import=false`, which does not strip the embedded `mixamo_com` take in Godot 4.6.3 despite being set. First use of this import hook anywhere in the repo.
  2. **A new artifact type under `assets/`** -- an import-time `.gd` script living alongside its source asset (item 1), plus the `AnimationLibrary` `.res` (`paladin_anims.res`) as a committed assembly artifact, neither of which the current Directory Tree vocabulary (source assets only) accounts for.
  Queued; NOT edited into `docs/game-architecture.md` this session (docs-only fix pass, story-file scope). Forcing point: the next architecture amendment queue flush (pattern: E2-CO/R1).

---

## Session 2026-07-31 -- Story 3-0a close-out

**What landed (f9093ec code+tests+assets / 8140e38 dev record+playtest log / 6e97ca3 board+status; this decision-log commit itself carries the R9-R12 fix-pass session above and this close-out session).** Implementation exactly as gated and reviewed -- rulings 3-0a/R1..3-0a/R12 stand as ruled, nothing reopened. Suite: **164 state tests / 760 assertions / 0 failed**; golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` **unmoved, measured in BOTH directions**. Integration files: **9 -> 10** (the new `test_rig_clips.gd`, AC3's mutation-proven six-clip contract), all run **INDIVIDUALLY and PASS**. `src/state/` byte-identical, confirmed by `git status`/`git diff`, not by assertion.

**New rulings, continuing from 3-0a/R12:**

**3-0a/R13 -- live-smoke findings, all NON-BLOCKING, all handed to 3-0b.** The operator ran the smoke with a second human on the shipped default (`slot_controller_kinds = [0, 1]`, two live killable humans), two keyboards, no `.tscn` flip. PASS on every checked point: all six clips fire on the correct `ActionState`s; the corpse stays down (`death` holds, loop off); deflect visually borrows the block pose with no jerk (verified live -- one player held block while the other attacked into it); frame rate held with two skinned characters on screen. Three findings, none blocking:
  1. The roll telegraph ring reads as **beside** the hero, not under him. Diagnosis: the ring did NOT move -- it is drawn at the root where the hero actually is; the MESH moved. This is the measured `roll` Hips excursion (~1.09 units planar, Dev Notes table) become visible now that a body replaced the placeholder box. **Not a regression** introduced by adoption -- the excursion pre-existed and the box merely never showed it.
  2. The `roll` clip is cut well before it finishes -- the authored `roll_duration` is far shorter than the clip. Expected under the R5 clip-end/mid-clip policy; reconciling clip length against authored timing is 3-0b's.
  3. The `block` clip has no transition frames -- the hero pops into the guard pose and out of it, and deflect enters that same held pose instantly. Follows from choosing a held-pose clip; carries a real trade (the instant pop means zero visual lag between input and guard). Whether to soften it is a 3-0b judgment.

**3-0a/R14 -- ruling 3-0a/R12 CORRECTED: an In Place re-download does NOT pin the root.** R12 (Live Smoke, story file) claimed that if `roll` reads as detached, the fix is an In Place re-download of that clip -- the same category `roll` and `run` already used for AC6. That is **wrong**: `roll` was **already** downloaded In Place (R9). In Place yields net-zero *travel* across the clip but does not pin the root; the Hips still swing ~1.09 units planar mid-clip (Dev Notes measured table), which is exactly what reads as the body sitting beside the hero (R13 finding 1). The correct routes, both 3-0b's, are: (a) a different roll or dodge clip with a smaller Hips excursion, or (b) zero the XZ component of the Hips position track in the animation library while keeping Y (so the crouch survives) -- the same principle the `run` clip already relies on, where the legs cycle in place and state carries the body. Corrected in the story's Live Smoke note so the artifact carries no false fix route into 3-0b. No code or asset changed -- this is a documentation correction; the fix itself is 3-0b's.

**3-0a/R15 -- R-D6 live-smoke acceptance RE-INVOKED on 3-0a, PASSED (the FIFTH two-human smoke), SPENT again.** Available to the next story with a live smoke against killable human slots.

**3-0a/R16 -- Golden unmoved, measured in both directions, the SEVENTH consecutive story.** Hash `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unchanged since 1-9. As predicted (NONE, both directions): the rig touches no `src/state/` and adds no `MatchState.to_snapshot()` field, so no snapshot could move.

**E3 underway.** 3-0a is the first E3 story delivered; `epic-3` stays `backlog` (the card system proper is unbuilt). Next: 3-0b (feel-and-timing tuning, Matko-authored just-in-time), which inherits the DEBT E judgments plus the three R13 findings above.

**Promotion.** Story Status and board promoted ready-for-dev -> done.

---

## Session 2026-07-31 -- Melee damage balance corrective (6 -> 3)

**BC/R1 -- Pass shape and sanction.** A balance corrective pass, run OUTSIDE the full story ritual: the judgment was already made (melee is chip damage; BC/R2), so there is nothing for a gate to decide -- proof-by-measurement replaces review. One authored value changed, two commits: the `.tres` edit and this decision-log record (code and docs never share a commit). Prefix note: history has no precedent for a balance/data-tuning commit -- every prior `data/balance/balance_config.tres` value edit rode inside a `story`/`N-N` commit (`1c99268`, `513c70e`, `0eea3f1`). The general-purpose non-story types in use are `feat` (new systems) and `chore` (housekeeping); neither fits a tuning change cleanly. Chosen `chore(balance):` -- the existing `chore` type with the established scoped form (`chore(stories):`, `feat(state):`), not the invented top-level `balance:`.

**BC/R2 -- The change and its GDD rationale.** `attack_damage_percent_of_max_hp` 6.0 -> 3.0 in `data/balance/balance_config.tres`. At `max_hp` 100 this is 3.0 damage per melee hit (was 6.0; formula `match_state.gd:413` = `pct/100 * target max_hp`). Melee is chip damage, and the GDD binds chip to remain a credible finisher below roughly 15-20% of max HP. At 3% per hit that is five to seven hits to close the last fifth; at 2% it is eight to ten, too slow for the closing phase -- so 3, not 2. The card spikes that will carry most of the killing do not exist yet, a further reason not to cut melee harder now. Nothing else touched: class default (`balance_config.gd:31`) stays 0.0, `block_damage_multiplier` (0.3), `melee_hit_mana` (8.0), and `max_hp` (100) all untouched.

**BC/R3 -- Standing fact established this pass: authored balance is isolated from BOTH the determinism golden AND the unit suite.** Route traced by content: (a) the runner injects the authored `.tres` once, via `BalanceConfigService.get_config()` -> `apply_balance()` (`match_runner.gd:74-76`); the `MatchState` constructor (`match_runner.gd:66`) carries only SEED / HP / move / stamina / mana, so the damage value reaches state on a SINGLE route -- the `.tres`, never a constructor constant. (b) Every combat UNIT test constructs its own `MatchState` from an in-test `BalanceConfig` literal and never loads `data/balance/*.tres`: `test_contact_resolution.gd:30`, `test_block_deflect.gd:34`, `test_contact_pipeline.gd:16` (state), `test_roll_iframes.gd:34`, `test_match_state.gd:170`, `test_gamepad_controller.gd:45`, `test_null_controller.gd:29` all author `attack_damage_percent_of_max_hp = 6.0` in-test. (c) `test_determinism.gd` builds its fixture from `_golden_config()` with an in-test 10.0 (`:132`); its header states the principle verbatim -- "constructed IN-TEST on purpose, never loaded from data/balance/*.tres ... playtest edits to the authored .tres must never move this hash." (d) `test_balance_authoring.gd` audits the REAL `.tres` but asserts NO value on the damage field (only `> 0` / bounds guards on durations, stamina, melee-hit mana, defense pair, roll-iframe, move-speed-mult). (e) the only test that reads the authored `.tres` for damage, `test_contact_pipeline.gd` (integration), is fully PARAMETRIC (`_damage = pct/100 * max_hp`, `_kill_hits = ceil(max_hp/_damage)`, `:73-74`) and self-reschedules. Consequence for all future work: a balance tuning change is a one-line `.tres` edit with NO test consequence and NO re-baseline; the golden pins the DETERMINISM of the machinery, not the numbers being tuned.

**BC/R4 -- No test moved, no golden re-baseline.** Contrary to the pass's initial expectation (that a `94.0 = 100 - 6` would move), ZERO asserted numbers changed -- see BC/R3: the combat tests hold their own in-test 6.0 literals and are deliberately not coupled to the authored value (coupling them would make every future tuning change break the suite -- an isolation worth keeping, not a gap to close). The parametric integration test `test_contact_pipeline.gd` self-rescheduled its kill-hit count `ceil(100/6) = 17` -> `ceil(100/3) = 34` and still completed within `DEADLINE = 5000` frames -- a rescheduled behavior, not an edit. Golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` NOT re-baselined; `test_determinism.gd` never touched.

**BC/R5 -- Proof: before == after, in both directions.** Full suite BEFORE and AFTER the change, identical: 164 state tests / 760 assertions / 0 failed; all 10 integration files run INDIVIDUALLY and PASS; golden `338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` unchanged and asserted green by `test_state_matches_golden`. Before == after is the PROOF of the isolation (BC/R3), not merely its assertion. No collateral: `git diff -- project.godot src/main/main.tscn` empty, re-checked immediately before the code commit.

---

## Session 2026-07-31 -- Docs pass: camera lock-on decision, stamina-cost closure, E3 revisit-gate ruling

**DP/R1 -- NEW OPEN DECISION (f) — camera is ALWAYS locked on a target; the lock-on button RETARGETS, it does not toggle free rotation.** Current state, verified by content: the camera is fixed third-person; camera rotation input is OUT OF SCOPE for E1 (`1-2-camera-relative-movement-basis.md:44`: "The GDD Input Map defines no camera-look action and the camera orientation is fixed... When a later story introduces a look action, it MUST flow controller → `InputIntent.aim` → runner → rig"); framing values are authored in `data/camera_config.tres`, presentation-side, load-once, outside `BalanceConfig` and outside the X3 hot-reload path (2-1 micro-decision, review-accepted).

Decision: the camera stays ALWAYS locked on a target, with no free rotation at all. The button that would otherwise toggle lock-on instead RETARGETS — cycling to minions and totems once E4 adds them, with a fast route back to the enemy hero. This SUPERSEDES the free-rotation route named above rather than adding to it: if a look action ever lands, it drives target cycling, not camera yaw, but still flows controller → `InputIntent.aim` → runner → rig (D3(a) unchanged — the rig never reads `Input.*` directly). Forcing point: E4, when minions and totems make more than one target exist.

Two questions this decision does NOT answer, both E4's, neither settled now:
(i) Does facing follow the locked target? Souls-style lock-on faces the target regardless of movement direction — that is what makes strafing read correctly. `HeroState.facing` is currently derived from input, is world-space planar (1-7 review R1 contract), and IS a snapshot field (`hero_state.gd:403`) — moving its ownership to the target would move the golden, and would touch `block_facing_arc_degrees` and the facing check in the contact-resolution step (R-D2/R-D3, 1-8). Design consequence worth stating: if the hero always faces the locked target, that target can never strike from outside the block arc in a one-on-one, so orientation stops being a defensive dimension and blocking becomes purely a timing skill.
(ii) Locking onto a minion or totem lets the enemy hero leave the frame — directly in tension with the Legibility Principle, since the unblockable telegraph that must be read in under half a second is exactly what must not be missed.

Status: OPEN, no resolution recorded.

**DP/R2 -- DECISION (d) RESOLVED: the basic attack costs stamina.** The GDD/design-level question opened at the 2-4 close-out (decision-log:743, "does the basic attack cost stamina?") is decided: it does. Rationale: a stamina cost on the basic attack is an ANTI-SPAM lever, not an economy constraint — it does not starve the mana hook (melee stays the mana faucet; the 1-4-gate "Basic attack stays FREE, GDD-affirming" ruling and 1-5's melee-hit-mana generation are both about the ECONOMY and are untouched by this decision), it stops mashing. The original entry is edited in place at decision-log:743 with a RESOLVED pointer to this entry, per Matko's explicit instruction for this one factual/decision closure — a deliberate, noted exception to the standing "the log is canonical and is corrected forward, never rewritten" rule (2-2 addendum A4, the 1-9/2-1 precedent); nothing else in the log is rewritten under this exception.

**NEW OPEN DECISION (g) — basic attack stamina cost: value and owning story.** NOT decided by DP/R2: the cost value itself, and which story implements it. Known cost, recorded so the owner is not surprised: a third `StaminaPool.spend()` policy seat (alongside roll and deflect) plus an affordability precondition with fallthrough and `action_rejected` (the 1-4 pattern), a new balance field, tests, and a CERTAIN golden re-baseline, since stamina values are in the snapshot. Natural owner is the E3 economy-seam work — `epics.md:93-97` already names 3-1 as carrying the prior open question "as a seat if the E2 retro adopts it"; that text now points at a DECIDED item and is stale (it names the question, not the value/owner split this entry makes) — queued for the next docs pass touching `epics.md`, not edited this session. This entry does not assign an owning story; scheduling stays Matko's. Status: OPEN, no resolution recorded.

**DP/R3 -- E3 REVISIT GATE: precondition SATISFIED BY CONTENT, gate now RUNNABLE.** Operator ruling: no separate external playtest session will be held — the game is neither fun nor unfun yet with most core mechanics unbuilt, and it will be tested many times along the way regardless. What the gate wanted (`3-1-matchstate-config-object.md:5-9`, verbatim from `stories-manual-e3.md`: "reviewed after the first E1/E2 playtest... after the E2 playtest, re-read the E3 stories against `docs/playtest-log.md`...") was evidence from E1/E2 actually being played, and that evidence exists: five two-human live smokes, each an R-D6-acceptance "RE-INVOKED... PASSED" entry above — 2-3 (the first, `2-3/R17`), 2-4 (the second), 2-5 (the third), 2-6 ("the FOURTH two-human smoke", `2-6/R21`), and 3-0a ("the FIFTH two-human smoke", `3-0a/R15`) — the last of these being play on the real rig with a second human, all recorded in `docs/playtest-log.md`. The gate asked for evidence, not for an audience.

Scope, precisely: this ruling makes the revisit gate RUNNABLE. It does NOT promote any story and does NOT pre-judge any E3 story's content — the gate still has to run, and it is the gate's own re-read against `docs/playtest-log.md` that decides what each E3 story confirms, amends, or drops. `docs/implementation-artifacts/sprint-status.yaml`'s `story_notes` for 3-1 through 3-6 are rewritten in this commit so they no longer point at an event (a separate external playtest) that will never occur, while all six stories remain HELD until the gate has actually been run against them.

**DP/R4 -- Lettering unified into one chronological scheme; letters retrofitted onto three previously-unlettered OPEN entries.** The log carried two eras of OPEN-decision style: the earliest entries (2026-07-22) were written as bare `**OPEN — Title.**`, with no letter at all; letters first appear starting with `(c)` at the 2-2 close-out (2026-07-28) and continue with `(d)` at the 2-4 close-out. Three entries were unlettered — attacker consequence on deflect (2026-07-22), reshuffle vulnerable-window cost (2026-07-22), and whether hand size ever varies (2-5 close-out, 2026-07-28) — despite the first having been referred to as "decision (a)" in cross-references since the 1-8 gate. This pass makes it one scheme, by opening order: `(a)` attacker consequence on deflect, `(b)` reshuffle vulnerable-window cost, `(c)` variable analog magnitude, `(d)` basic attack costs stamina (RESOLVED today, DP/R2), `(e)` hand size ever varies, `(f)` camera always-lock-on (DP/R1 above — written as `(b)` in this session's first draft before the retrofit), `(g)` basic attack stamina cost value/owner (DP/R2 above — written as `(e)` in the same first draft). Only the three unlettered entries' headers were touched (letter added, nothing else in their text changed); DP/R1 and DP/R2's own letters were renumbered in place before this record was written, so no stale letter reaches the committed log. Anyone reading `(f)`/`(g)` as oddly high for a same-day pair: this is why — read it as a retrofit, not an error.

---

## Session 2026-07-31 -- E3 revisit gate (outcome)

This entry satisfies the epic's own exit criterion, verbatim from `stories-manual-e3.md:241` (Epic exit
criteria, item 6): **"The revisit gate has been executed and its outcome recorded in `decision-log.md`."**
DP/R3 (above) made the gate RUNNABLE by content; this session RUNS it — a read of the six E3 story files
(`docs/implementation-artifacts/3-1..3-6`) against `docs/playtest-log.md` and the shipped `src/` state, per
`stories-manual-e3.md`'s own instruction ("re-read this file against `docs/playtest-log.md` and either
confirm each story, amend it, or delete it").

**VERDICT: E3 proceeds AMENDED.** Five of six stories (3-1, 3-3, 3-4, 3-5, 3-6) need text corrections
before promotion to ready-for-dev; 3-2 is implementable as written apart from two cosmetic fixes. No
story is deleted. The epic's shape, sequence, and exit criteria (`stories-manual-e3.md:234-241`) survive
unchanged.

**Context bounding this gate — recounted precisely.** Thirteen readiness-gate sessions are logged for
stories explicitly described in-text as belonging to the Set B batch: seven in E1 (1-4, 1-5, 1-6, 1-7,
1-8, 1-9, 1-10) and six in E2 (2-1, 2-2, 2-3, 2-4, 2-5, 2-6) — verified by content, each one's own gate
session names it "the original Set B batch" or "backlog since the Set B batch." All thirteen return NOT
READY at first read. Two qualifications, stated so the claim is checkable rather than asserted: (1) 1-1,
1-2, and 1-3 never received a logged "readiness gate (operator decisions)" session at all — their
close-outs run directly from implementation with no gate session preceding them in this log — so they
belong in neither a seven-count nor a thirteen-count; a claim naming them would be unverifiable by
content. (2) every one of the thirteen sessions resolves its findings and promotes the story to
ready-for-dev within that SAME session ("Promotion. All fixes applied... promoted backlog ->
ready-for-dev"), so NOT READY is only a FIRST-PASS verdict — none of the thirteen stories exited its gate
session still NOT READY. A count of seven is defensible only if narrowed to the E1 gates alone; nothing
in the log itself states that narrower scope — 2-1 through 2-6 are each described as "the Set B batch"
with the same wording as the E1 stories — so thirteen is the number this log actually supports for "every
Set B story that has reached a readiness gate," with the first-pass/promoted-same-session caveat above.
The sole READY-on-first-pass gate anywhere in the log, 1-7b, was a freshly authored non-Set-B story, not a
counterexample to either count. This gate does NOT substitute for the six E3 stories' own readiness
gates — each still faces its own before its dev pass; `sprint-status.yaml`'s HOLD notes for 3-1 through
3-6 are rewritten in the companion commit to say the gate has now run, without changing HOLD itself (see
below).

**E3-RG/R1 -- MANA SCALE: the GDD's scale is canonical.** Verified by content: the GDD's own baseline
reference is "Clash-Royale-like ~10 max, ~1/sec — adjust to card costs in balance" (`gdd.md:220`), and its
worked example costs 3 Mana (Imp Summoner, Basic, `gdd.md:203`) and 5 Mana + 2 Green orbs (Hellburst,
Pitch, `gdd.md:206`) — both far smaller than the shipped numbers. The shipped mana cap is a runner
constant, not balance data: `const _MAX_MANA := 80.0` (`match_runner.gd:17`), injected only via the
constructor (`match_runner.gd:66`), because `BalanceConfig` has no `max_mana` field
(`balance_config.gd:43`: "NO max_mana here — the mana cap stays the runner's constructor value until story
3-1"). The shipped per-hit value, `melee_hit_mana = 8.0` (`data/balance/balance_config.tres:21`), was
recorded as a first-guess "Authored placeholder" at 1-5 close-out (decision-log:240), never revisited.
Ruling: all three mana numbers — the cap, the per-hit amount, and the passive regen — are authored
TOGETHER in 3-1 as one coherent set, and card costs in 3-2 are authored against that set, never
independently. The per-hit amount comes DOWN: at the GDD's ~10 cap, the shipped 8.0 fills the bar in two
hits (8, then clamped at 10) and the flywheel disappears. The authoring criterion to record: a round of
the GDD's stated length (~60-120s active play) funds the GDD's stated number of loop cycles (~2-4
buildup->bluff->payoff cycles per round, both `gdd.md` Core Gameplay Loop). Record also: the recent
melee-damage halving (BC/R2, decision-log:1015, `attack_damage_percent_of_max_hp` 6.0 -> 3.0) explicitly
left `melee_hit_mana` untouched ("class default... `melee_hit_mana` (8.0)... all untouched") — so mana
earned per point of damage dealt has doubled (8/6 ≈ 1.33 -> 8/3 ≈ 2.67 per hit-point). That is part of
what 3-1 reconciles.

**E3-RG/R2 -- THE BASIC ATTACK'S STAMINA COST: value and owning story.** The decision that the attack
costs stamina is already resolved (OPEN decision (d), RESOLVED at DP/R2, decision-log:1037); NEW OPEN
DECISION (g) (decision-log:1039) left the value and the owning story open, noting a "CERTAIN golden
re-baseline... since stamina values are in the snapshot." Ruling: it lands as a STANDALONE corrective
pass BEFORE 3-1, in the shape of the recent melee-damage corrective (BC/R1-R5, decision-log:1011-1022:
judgment already made, proof-by-measurement replaces review, one authored value + one decision-log
commit) — so that the certain golden re-baseline has exactly one named cause in its own commit, not
bundled into 3-1's own re-baseline-causing config-object refactor. The value is not chosen by taste: it
is authored so that a full attack chain is affordable from a full bar while the next attack past the
chain is gated by regen. Verified by content: authored `attack_chain_length = 3`
(`data/balance/balance_config.tres:18`), `max_stamina = 50.0` (:9), `stamina_regen_per_second = 15.0`
and `stamina_regen_delay_seconds = 0.8` (:10-11) — the corrective pass authors the per-attack cost
against these, not against a fresh guess.

**E3-RG/R3 -- THE PUBLIC-INFORMATION CHANNEL.** Two stories need the reshuffle vulnerable window visible
in BOTH viewports (`stories-manual-e3.md` E3.S3 item 4 and E3.S6 item 3: "flagged visually to both
players"/"clearly flagged in both viewports"), while the shipped HUD is bound per-slot and structurally
cannot receive anything about the opponent — verified by content: 2-4/R7 (decision-log:709) "NO-OPPONENT-
READ IS STRUCTURAL... the HUD is handed only its own player's payloads and structurally cannot reach the
opponent"; 2-5/R11 (decision-log:789) "`HudRoot._init()` takes no slot argument at all." Ruling: this
rides an OWNERLESS event on the existing `EventBus`, following the round-lifecycle precedent already in
use (`round_started`/`round_ended`, `game-architecture.md:484-489`: "`EventBus` autoload carries a small
fixed typed set only... `match_runner` relays `round_started`... same as `round_ended`"), carrying which
player is vulnerable as payload. This is NOT an eighth observation seam and does not amend the ruling
that froze that family: 2-6/R7 (decision-log:825, locked) "NO EIGHTH SEAM... per-tick timing-window
countdown streaming is deliberately deferred" froze the per-slot CONNECT-seam family (four combat seams
plus three economy seams, `2-4/R1`, decision-log:697) at seven; the seam family is per-slot observation,
and this is a match-wide public fact riding the SAME bus that already carries `round_started`/
`round_ended` — a different mechanism, not a member of the frozen family.

**E3-RG/R4 -- THE OPPONENT FACE-DOWN ROW IS DELETED.** Verified by content: three separate places forbid
anchoring to it. (1) `epics.md:110-111`, E3 committed obligations: "The opponent face-down top-centre row
(2-5/R3) is PROVISIONAL — nothing built in E3 may anchor to it; it may be deleted outright (2-6/R9)." (2)
decision-log 2-6/R9 (line 829): "The A/B must NOT anchor to `OpponentHandStrip` (2-5's face-down row),
which is provisional and may be deleted in E3." (3) the 2-6 story file itself, twice
(`docs/implementation-artifacts/2-6-legibility-feel-instrumentation.md:29,168`): "independent of
`OpponentHandStrip`," both the task line and the completion note. Story 3-6 AC1 nonetheless anchors to
it: "populated with real cards inside the existing per-viewport privacy rule from 2.5... the slot whose
privacy behaviour already works is used" — reusing the exact `HandStrip`/`OpponentHandStrip` nodes 2-5
built in `hud_root.gd`. Ruling: the row goes. Reasons to record: it carries no information while the hand
size is fixed (2-5/R1, decision-log:761: rendered count is a "presentation-local constant 4"); it
consumes space in an already-crowded half-width viewport (2-5/R12 measured slack, decision-log:791); and
decisively, it renders a count whose PUBLICITY was never decided — the GDD makes the pitched card the
only public information (2-5/R9, decision-log:777; `epics.md:181-182`: "the only lock: the pitched card
is the sole public information, hands stay private otherwise"). If a varying hand size ever lands (OPEN
decision (e), decision-log:801), whether the count is public becomes a separate design question at that
time.

**E3-RG/R5 -- THE REVEAL-OPPONENT-HAND TOGGLE** is owned by the card HUD story (3-6) as a named
acceptance criterion. Its trigger rides the presentation-local switch mechanism built by 2-6, the
instrumentation story: `DebugInstrumentPanel` (`src/ui/debug/debug_instrument_panel.gd`, per the 2-6 File
List, `2-6-legibility-feel-instrumentation.md:190`) — not a new Input Map action (no `Input.*` read
belongs in `src/ui/`, the standing constraint restated at 2-5/R4, decision-log:767), and not a feature
flag, which is load-once and runtime-immutable (2-6/R4, decision-log:817, locked: the panel "may flip
ONLY presentation-local and controller-local switches — never a `FeatureFlags` member"). Verified by
content: the single ownership seat is already `HudRoot._make_card_face_style(is_own)` — the face-down
rule was required to live in exactly ONE seat as the condition of 2-5's deferral (2-5/R4, decision-log:
767) and landed there (2-5 close-out, decision-log:785) — so the toggle is a flip of that one parameter,
not a second rule.

**E3-RG/R6 -- CARD SIZE.** The HUD story (3-6) owns the sizing and layout of the card strip and MAY grow
its footprint; 2-4 reserved the space, 3-6 finalizes it. Verified measured slack (2-5/R12, decision-log:
791): opponent row (`OpponentHandStrip`) 236px container, 232px content, 4px slack; own row (`HandStrip`)
344px container, 320px content, 24px slack — both flagged as too small for legibility (smoke finding S2,
2-4 close-out, decision-log:739, also cited at `epics.md:108-109`) and deliberately deferred until real
card art exists (E3). Card ART itself is scheduled in no story and stays unowned — it is decided when
there is something to draw.

**E3-RG/R7 -- INPUT MAP OWNERSHIP.** E3-P/R2 (decision-log:899) ruled that "the new `project.godot` Input
Map actions land here and only here" for 3-0b's deterministic step/pause actions. Per this log's
established corrected-forward convention (the 2-2/A4 precedent, decision-log:568, and the DP/R2 exception
noted there), this entry AMENDS E3-P/R2's wording in place, read as scoped: it binds only 3-0b's
step/pause actions, and was never meant to freeze the Input Map for the whole epic. 3-5 (the mode-select
story) may add its own card actions (play/stage/cancel, per-mode binds) under the same discipline already
established for controller-facing actions elsewhere: named actions, textual edit with the editor closed,
diff reviewed (the 2-1/R2 procedure, decision-log:506). This was never available to 2-2 because E3 sat
under a HOLD gate at the time (2-2/R3, decision-log:546: the E3 action clause was "struck entirely... E3
is under a HOLD gate pending the first E1/E2 playtest") — that HOLD is what DP/R3 (decision-log:1041)
lifted by making the revisit gate runnable; 3-5 is the first story positioned to use the now-open door.

**E3-RG/R8 -- THE ECONOMY EVALUATOR FULLY REPLACES the direct mana path rather than sitting behind it,
with a proof obligation: the mana amounts for the melee case must be unchanged, shown before and after.**
That makes it a provable refactor, not a rewrite — two paths for one rule is what rots. Verified by
content: `ResourceGenerationRule`, `CardCastCondition`, and `economy_evaluator.gd`/`EconomyEvaluator` do
not exist anywhere in `src/` (zero grep matches) — DEBT D (decision-log:189) stays LIVE (decision-log:
210: "DEBT D — LIVE. The D6 economy evaluator stays deferred"), committed to land at 3-4's own gate
(`epics.md:98-99`). The architecture document nonetheless describes them as already landed in several
places, with no "Planned (E3)" qualifier: the Directory Tree lists `economy/ economy_evaluator.gd # D6
pure evaluator` and `resources/... resource_generation_rule.gd . card_cast_condition.gd # D6`
(`game-architecture.md:548,553`), unlike the `MatchState` config object, which IS explicitly marked
"Planned (E3)" (`game-architecture.md:613`); the D6 capability table marks it "E0/E3 · Full"
(`game-architecture.md:107,190`); the Testable-without-engine-runtime table lists "the D6 evaluators
(`ResourceGenerationRule` / `CardCastCondition`)" as already testable (`game-architecture.md:511`); Novel
Pattern 5 (`game-architecture.md:788-806`) is written as existing code. Both facts (non-existence in
`src/`, and the doc's already-landed framing) go in 3-4's Dev Notes as first-class findings, not a
background assumption — constructing the evaluator and its rule resource become first-class acceptance
criteria. Separately verified: the melee-to-mana hook does NOT need wiring — it is already live and
shipped. `MatchState._generate_mana` grants `balance.melee_hit_mana` on every confirmed hit, gated on the
injected `FeatureFlags.melee_mana_generation` (2-4/R13, decision-log:727; traced end-to-end at BC/R3,
decision-log:1017: the authored `.tres` reaches state on a SINGLE route, `.tres` -> `apply_balance()` ->
state, never a constructor constant). 3-4 is therefore the REFACTOR (the evaluator replaces this direct
path, under the proof obligation above) PLUS the NEW passive-tick income — not new wiring of an existing
hook; its AC2 is reworded accordingly. The Dev Notes citation to `stories-manual-e1.md#E1.S5`
(evaluator framing) is superseded text: the 1-5 gate entry (decision-log:224) states "the 1-5 story text
is cleaned of every evaluator reference (`stories-manual-e1.md` E1.S5 item 3's evaluator framing is
superseded by this entry; the manual is not edited)" — 3-4 cites decision-log:224 in its place. What the
mana pool lacks that the stamina pool has: a `BalanceTicks`-derived per-tick regen value (stamina has
`stamina_regen_per_tick`, `src/state/timing/balance_ticks.gd:20`, derived once at load from
`stamina_regen_per_second`) and a seat in the `advance()` tick ladder (stamina ticks in step 2 via
`StaminaPool.tick_timers()`; `ManaPool`, `src/state/pools/mana_pool.gd`, has only `add`/`spend`/
`set_maximum` — no regen method and no ladder seat at all). A passive tick needs its own derived per-tick
value (e.g. `mana_regen_per_tick` on `BalanceTicks`) and its own seat in the ladder.

**E3-RG/R9 -- THE SEED LIVES OUTSIDE the hot-reloadable balance resource, in a separate match-scoped
params object injected once.** A reload that re-seeds mid-match is a determinism hole. Verified by
content: `const _SEED := 12345` (`match_runner.gd:13`) is currently a constructor-only positional float
(`MatchState.new(_SEED, ...)`, `match_runner.gd:66`), never touched by `apply_balance()`
(`match_state.gd:175-178`), which IS both the match-start injection path and the X3 live-reload seam (1-4
gate, decision-log:199). `_rng` is seeded exactly once in `_init` (`match_state.gd:92-93`) and is "the
ONLY randomness source in the state layer" (`match_state.gd:59`). The architecture doc's "Planned (E3)"
note (`game-architecture.md:613-617`) says to fold all five constructor floats "into a single injected
config/params object (the injected `BalanceConfig` or a small params struct)" — read literally, folding
`seed` into the SAME hot-reloadable `BalanceConfig` object `apply_balance()` consumes would let a
mid-match reload re-seed the RNG. 3-1 must say this explicitly rather than folding the seed in with the
tunables — a plain reading of the "Planned (E3)" note would get this wrong.

**E3-RG/R10 -- This gate's output lands as two docs commits: this one, and the story amendments** —
matching the established test-only/docs-only corrective-pass shape (SDV/R1, decision-log:923: "Two
commits: `test:`... and this decision-log record"; BC/R1, decision-log:1013: "two commits: the `.tres`
edit and this decision-log record").

**E3-RG/R11 -- EVERY amended story gains a Golden Prediction section and a Live Smoke section.** Not
negotiable: verified by content, none of the six current story files
(`docs/implementation-artifacts/3-1` through `3-6`) contains either section. E3-P/R6 (decision-log:917)
already flagged the pattern once: "Both must include Golden Prediction and Live Smoke sections from the
first draft (Set B files have lacked both sections six times running)" — required of 3-0a/3-0b as new
files specifically because Set B files kept failing this. This gate finds the identical defect, unrevised,
in the six E3 story stubs still carried over from the original Set B batch — the seventh occasion,
cumulatively, that a Set B-authored file reaches a gate without them. Separately, and by content: the
determinism golden hash `33817201...21da2` has been unmoved for SEVEN consecutive stories — stated
explicitly at 3-0a's own close-out (3-0a/R16, decision-log:1003: "Golden unmoved, measured in both
directions, the SEVENTH consecutive story"), continuing from 2-6 (2-6/R22, decision-log:865: "the SIXTH
consecutive story") back through 2-5, 2-4, 2-3, 2-2, 2-1, 1-10. E3 breaks that streak: the deck story
(3-3) draws from the seeded RNG inside `advance()` (`rng_state` is part of the hashed snapshot,
`match_state.gd:242`) AND populates `PlayerState.hand`, which already emits `"hand_size": hand.size()` in
`to_snapshot()` but is currently always zero (2-5/R1, decision-log:761: "`hand` is declared `[]` and never
mutated anywhere in `src/`... a golden trap"). 3-3 therefore moves the golden TWICE OVER, from RNG
consumption and from the hand-size field the snapshot already emits — two separately named causes in one
story, continuing the "measured in both directions, separately named causes" discipline this project has
followed since the 1-5 cause-(c) lesson.

**E3-RG/R12 -- NO FEATURE-FLAGS OVERLAY IN E3.** Verified by content, the ruling that keeps feature flags
load-once and runtime-immutable: 2-6/R4 (decision-log:817, locked) — "`FeatureFlags` stays load-once and
runtime-immutable... Reason: flags appear in neither `MatchState.to_snapshot()` nor the recorded intent
stream, so mutating one at runtime would be a silent replay hole." The overlay is therefore not merely
unowned but currently PROHIBITED, not merely deferred. `epics.md:104-107` currently reads "A real
`FeatureFlags` overlay does not exist yet... every other flag stays dormant until its own epic" as an item
inside E3's Committed-obligations list — presented as an E3-relevant bullet while committing E3 to
nothing and stating no prohibition. Ruling: remove it from `epics.md` as an E3 item; record instead that a
live `FeatureFlags` overlay is PROHIBITED pending the reload machinery — only once DEBT B's reload-event-
in-intent-stream half lands (re-homed to the `IntentRecorder`/3-0c story per 2-6/R2 and E3-P/R3,
decision-log:813,901) does a runtime flag mutation stop being a silent replay hole.

**ORDER, recorded as part of the outcome.** The stamina-cost corrective pass (E3-RG/R2) and the
feel-and-timing story (3-0b, operator-authored) come first — order between the two not fixed by this
gate — then 3-1, 3-4, 3-2, 3-3, 3-5, the `IntentRecorder` (3-0c), and the card HUD (3-6) last. Reasons to
record: 3-4 precedes 3-2 so the card-cast condition (`CardCastCondition` gating mana cost) is designed
against a working evaluator rather than a hypothetical one; 3-0c follows 3-5 so the intent shape (the new
card fields on `InputIntent`) is final before the stream contract is written; the feel-and-timing story
comes early because melee feel is not changed by cards, and its known roll defect (3-0a/R13 finding 1,
decision-log:995: the Hips-excursion / roll-ring-beside-the-hero defect) would otherwise contaminate
every remaining live smoke.

---

## Session 2026-08-01 -- Stamina-cost corrective pass: the basic attack costs 12

**SC/R1 -- Pass shape and sanction, both verified by content before relying on them.** A corrective
pass run OUTSIDE the full story ritual, in the shape BC/R1-R5 established: judgment already made, so
proof-by-measurement replaces review; two commits, code and docs never sharing one. Two rulings sanction
it. (1) DP/R2 (decision-log:1037) RESOLVED OPEN decision (d): the basic attack costs stamina, an
ANTI-SPAM lever and not an economy constraint -- the 1-4-gate "Basic attack stays FREE" ruling and 1-5's
melee-hit mana are about the ECONOMY and are untouched. (2) E3-RG/R2 (decision-log:1104) assigned the
value and the implementation to a STANDALONE pass landing BEFORE 3-1, "so that the certain golden
re-baseline has exactly one named cause in its own commit, not bundled into 3-1's own re-baseline-causing
config-object refactor." Unlike the melee-damage corrective, this pass DOES move the golden --
predicted by E3-RG/R2 and confirmed (SC/R8). COMMIT PREFIX, recorded because it deliberately DIFFERS
from the corrective pass immediately preceding it and the two should not read as inconsistent: the pass
SHAPE is shared with BC/R1, but the commit TYPE follows what the commit actually does.
`chore(balance):` is for TUNING AN AUTHORED VALUE -- BC's one-number `.tres` edit, housekeeping.
This pass adds a MECHANIC (a new balance field, a third spend seat in `match_state.gd`, five new tests,
a golden re-baseline), so it lands as `feat(state):` -- the scoped form already used three times in this
history for state-layer additions (`feat(state): E0 pools + HeroState + PlayerState` and siblings).
Someone searching in a month for when attacks began costing stamina looks under `feat`, not `chore`.

**SC/R2 -- THE VALUE: `attack_stamina_cost = 12.0`, authored against three criteria.** Authored against
the real shipped costs, not a guess: `roll_stamina_cost = 12.0`, `deflect_stamina_cost = 8.0`,
`max_stamina = 50.0`, `attack_chain_length = 3` (`data/balance/balance_config.tres:9,12,13,18`).
  (a) A full chain is affordable from a full bar: 3 x 12 = 36 <= 50.
  (b) A defensive action survives a full chain: 50 - 36 = 14, which affords the MORE EXPENSIVE of the
      two defensive actions (roll 12), not merely the cheaper deflect (8). Both remain available.
  (c) Two full chains back to back are impossible: 6 x 12 = 72 > 50.
Measured live under the authored config (attack pressed every tick for 400 ticks, headless probe):
swings fire at ticks 1, 25, 49 -- the full chain off a full bar -- then 94, 182, 278, 374, i.e. one swing
per ~96 ticks thereafter, with 211 presses rejected. The lever throttles mashing exactly as intended.

**SC/R3 -- RECORDED RULING: what "gated by regen" means, so it is unambiguous hereafter.** E3-RG/R2's
own wording ("a full attack chain is affordable from a full bar while the next attack past the chain is
gated by regen") was read during this pass as requiring a FOURTH attack to be UNAFFORDABLE. At 12 it is
not: the probe shows the fourth swing at t94 firing off the 14 left over, gated by the chain cap rather
than by stamina. Operator ruling, recorded here so a future reader does not re-derive a different value
from that sentence: the strict reading OVER-CONSTRAINS the criteria. Combined with criterion (b) at the
roll's 12.0 it admits only 12.5 < x <= 12.67 -- a window 0.17 wide, which breaks the first time the
roll's cost is tuned. "A value that survives only by two tenths is not precision, it is fragility."
The INTENDED reading: "gated by regen" means the regen MECHANISM throttles sustained attacking -- the
delay restarts on every swing, so continued attacking never self-funds -- NOT that a fourth attack must
be impossible. The lever makes spam EXPENSIVE, not forbidden: a player is free to swing into an empty
bar, and the punishment is being empty with no regen running. So criterion (c) is satisfied by the REGEN
GATE, not by unaffordability. At 12 the arithmetic is comfortable rather than knife-edge: a full chain
costs 36 of 50, leaving 14, which still affords the 12.0 roll; attacking on past the chain drains toward
empty with regen gated -- a self-punishing choice, not a wall. 12.6 was offered and explicitly REJECTED.
This entry corrects E3-RG/R2 FORWARD; that entry's text is not rewritten (the standing rule, 2-2/A4).

**SC/R4 -- THE SEAT: the third `StaminaPool.spend()` policy seat, on the ROLL precedent.** Seated in
`MatchState._try_transition`'s ATTACKING case (step 3). Roll was the better-fitting of the two existing
precedents and deflect was rejected by content: roll spends AT ENTRY and an unaffordable press REJECTS
and falls through per INPUT_PRIORITY (`match_state.gd:313-328`), whereas deflect holds a read-only
precondition at entry, spends at LANDING in step 4 (`:335`, `:416-417`), and treats unaffordable as a
DEGRADE -- the block still fires, only the window is denied. There is no degraded attack to fall back
to, so the degrade shape does not apply. Charged PER SWING, chain included. ORDERING, deliberate and
pinned by its own test: the 1-3 chain CAP is evaluated BEFORE the stamina seat, so a capped press is
refused for free and stays SILENT (a cap gate seated after the spend would charge for a swing that never
happens). Rejection reuses the existing vocabulary rather than inventing a variant --
`action_rejected(&"attack", &"insufficient_stamina")`, the reason StringName already used by roll and
deflect. A rejected attack costs nothing, enters no state, and advances neither `chain_index` nor the
monotonic `attack_index`.

**SC/R5 -- DESIGN CONSEQUENCE RAISED MID-PASS AND RULED: attacking now gates stamina regen for 0.8s.**
Following the roll precedent verbatim means passing `balance_ticks.stamina_regen_delay_ticks` to
`spend()`, so attack ENTRY restarts the post-spend regen-delay window. Neither DP/R2 nor E3-RG/R2
authorises that -- they decided a COST -- so the pass STOPPED and put the fork to the operator with both
branches measured: (A) roll precedent verbatim, versus (B) `spend(cost, 0)`, a cost that never gates
regen. Measured cost of each: (A) mash cadence ~96 ticks/swing, three state failures and one integration
failure, two of them structural; (B) ~2x faster cadence, and the ENTIRE suite structurally intact with
only the golden moving. Operator ruling: **(A)**. "Both existing consumers gate regen; an attack that did
not would be the only one that doesn't, and that asymmetry has no justification." Recorded as a real
mechanic, not an implementation detail: committing to offense now costs defensive readiness for 0.8s,
and this -- not the cost alone -- is what makes the throttle bite (SC/R3).

**SC/R6 -- BC/R3's standing fact SURVIVES, with one boundary now mapped.** BC/R3 established that
authored balance is isolated from both the golden and the unit suite. Nothing here contradicts it, and
the distinction is worth recording precisely: the `.tres` EDIT (`attack_stamina_cost = 12.0`) moved no
unit test -- every combat unit test still builds its own in-test `BalanceConfig`, where the new field
sits at its 0.0 default. What moved tests was the CODE (a new seat that fires in every config) and the
golden's OWN in-test coverage value, neither of which BC/R3 ever claimed isolation for. The one genuine
qualification: BC/R3 called `test_contact_pipeline.gd` (the only test reading the authored `.tres`)
"fully PARAMETRIC and self-reschedules". It did self-reschedule its timings, but it ALSO needed a
structural fix (SC/R7) -- parametric expectations do not survive a change that makes a pressed action
REFUSABLE. Record for future passes: "derived from the .tres" protects VALUES, not the assumption that
an input always produces an action.

**SC/R7 -- TESTS: five new pins, two adaptations, one audit, each with its arithmetic.** New, in
`test_stamina_economy.gd`: exact deduction at the transition (50 - 8 = 42); exactly-affordable spends to
empty; the rejected attack changes NOTHING (state stays IDLE, stamina 7.0 untouched, `chain_index` 0,
`attack_index` -1, and the queued rejection emitted); a chain swing is charged and an unaffordable chain
leaves the index alone; a CAPPED press is not charged and stays silent (the SC/R4 ordering pin). Audit:
`attack_stamina_cost > 0` added to `test_balance_authoring.gd`'s non-duration class, NOT exempt -- a zero
is a silently disarmed lever, the roll/deflect reasoning. ADAPTED, both flowing from SC/R5 and both named
rather than quietly rewritten: (1) `test_regen_runs_while_attacking` -- the D6 claim under test is
UNCHANGED (the ATTACKING *state* never suppressed regen); only the tick it becomes visible moved out from
under the 3-tick delay, so the test now reads 30.0 across t1-t3 and 31.0 at t4, still ATTACKING. (2)
`test_contact_pipeline.gd`'s reset phase -- its kill phase is now regen-paced (3295 frames / 34 swings
~= 96.9, matching the probe's 96), so it ends with P1 drained, and the 1-7/D-1 debug reset is ROUND-scoped
by design ("every slot's HP back to max ... NOTHING else (pools ... untouched)"). Its single
non-retrying press therefore landed on an empty bar and was refused; it now RE-PRESSES until the swing
fires, the same auto-swing shape the kill phase already used, with a `_attack_refill_ticks` allowance
derived from the `.tres`. This cannot livelock: a refused spend never restarts the delay window.

**SC/R8 -- PROOF: mutation, then ONE re-baseline measured in both directions.** MUTATION (non-vacuity of
the new guard): with the affordability precondition removed -- the spend left in place but its result
ignored -- `test_attack_at_cost_minus_one_rejected_and_changes_nothing` FAILS on the state (got
ATTACKING, expected IDLE) and on the swing counter (got 0, expected -1), and
`test_chain_swing_is_charged_and_unaffordable_chain_leaves_index_alone` FAILS on the index (got 1,
expected 0) and on the missing rejection. `src/state/match_state.gd` was backed up OUTSIDE the repo
before mutating and restored by copying back, never `git checkout` (which would have wiped the whole
uncommitted pass); SHA256 `a3d6cc44adb807db08f9aa770ec28ac25807e1aaaf36009ee157ba95d75d11e8` verified
byte-for-byte identical before and after. GOLDEN: every non-golden test was proven green FIRST (169
tests, 784 assertions, 1 failure -- the golden alone), then exactly ONE re-baseline,
`338172010a5409ab32684986bfff73b156f53bb828358e28f304ece440b21da2` ->
`7fbb4b7f589251d25a13d6b49138b416266031e124cdae1c07e99e0f4fc119d1`, cause named: the basic attack gained
a stamina cost. Two contributing halves measured APART, the 1-9 discipline: the intermediate
`d101980f315d43265325d68674dae79f67acc7210c0ecd8c092cc45df9581512` is the seat alone with
`_golden_config`'s cost still 0.0 (P2's t15 attack costs 3 regen ticks, 30.0 -> 27.0 -- the delay restart
of SC/R5 moves the hash even at zero cost), and toggling the authored 6.0 back off REPRODUCED it exactly.
REVERSE direction: with the seat removed the hash returns to `33817201...` exactly, so nothing else
contributed. Snapshot SHAPE is NOT a cause -- the seat adds no field, and the regen-delay window it
restarts was already snapshotted (D8). `_golden_config` authors 6.0, NOT the shipped 12.0
(coverage-not-feel, and chosen so neither attack spend is erased by a clamp at the 40.0 maximum).
FIGURES: suite BEFORE 164 tests / 760 assertions / 0 failed + 10 integration PASS; AFTER 169 tests / 784
assertions / 0 failed + 10 integration PASS. No collateral: `git diff -- project.godot
src/main/main.tscn` empty, re-checked immediately before each commit. NOT PUSHED -- both commits are
local pending the operator's confirmation of the log.

---

## Session 2026-08-01 -- Story 3-0b readiness gate (operator decisions)

Readiness gate on `3-0b-feel-and-timing-tuning.md` (authored earlier the same session, ACs 1-13
verbatim from the operator's own readiness-gate scope) returned **NOT READY**, four blocking
findings. (1) AC1's pause scope named only that pause "halts `advance()` ticking," leaving
unstated what else must freeze and how the step/pause input could be read at all without either
breaking D3(a) (`Input.*` confined to `src/controllers/`) or being wrongly modelled as an
`InputIntent`, which would enter the recorded intent stream and threaten determinism during a
pause. (2) AC2 left the standing objection that a per-tick countdown "hands the state layer's
internals to presentation" unanswered, and did not name the geometry regression
(`test/integration/test_debug_instruments.gd`) already guarding the panel's layout at roughly 4px
of slack -- the exact margin the new countdown rows are likely to eat. (3) AC5 was ambiguous
between "replaces" and "supplements" for the flat `attack_move_speed_multiplier` -- read
literally it could pass with both the flat field and the three per-phase fields present, which
the pinned `.tres` field-name registry in `test_data_resources.gd` would fail on a half-migration.
(4) AC11 and AC13 both asked for something the current evidence contradicts: AC11 asked for shape
and sound to be judged "separately," which is not how `docs/legibility-protocol.md`'s primary run
works (judged together, unmuted), and it dropped the S8 audio-discrimination finding entirely;
AC13 cited an unverified figure ("~1.725") with no measured record behind it, and did not account
for `BoxShape3D_qp0e8` being the SAME sub-resource shared by both `Collision` and
`HurtboxShape`, so a naive resize would silently change hurtbox volume too -- a gameplay change
riding in as a cosmetic one. All four resolved by operator ruling below, applied to the story
file the same session.

**3-0b/R1 -- AC1 pause scope, ruled.** While paused, three things freeze: `_match_state.advance()`,
both `HeroActor.drive()` calls, and `_gather_contact_facts`. Camera follow keeps running --
harmless presentation-only motion, and the operator must be able to look around during a pause.
A single step performs the normal per-tick order exactly once: gather -> advance -> drive.
Rationale for freezing gather specifically: contact facts are per-tick observations of the current
physical arrangement; accumulating a whole pause's worth and draining it into one step on resume
would corrupt the very tick the debug tool is trying to show.

**3-0b/R2 -- AC1: step/pause is a match-global DEBUG input, not an intent.** It never enters
`InputIntent`, never enters the recorded intent stream, and never passes through `advance()`. This
is a deliberate divergence from `debug_reset`, which IS intent-carried per its own ruling: pause
must survive the absence of ticking (nothing is advancing to consume an intent), which an intent --
by construction consumed only inside `advance()` -- cannot do.

**3-0b/R3 -- AC1 implementation constraint, sanctioned.** The reader is a NON-`Controller` class
under `src/controllers/` (suggested `src/controllers/debug_input_reader.gd`) -- it does not
implement `sample()`, does not return an `InputIntent`, and returns plain booleans the runner
polls. New shape for that folder: every existing member (`KeyboardController`,
`GamepadController`, `NullController`) is a `Controller` implementing `sample()`. Sanctioned
because it is the only routing that satisfies the machine-checked D3(a) invariant without
misrepresenting step/pause as an intent (R2 above). Architecture amendment queued:
`docs/game-architecture.md` gains a line documenting this new non-`Controller` `src/controllers/`
shape; not edited into the doc this session.

**3-0b/R4 -- AC2 gains the geometry regression to its must-stay-green list.**
`test/integration/test_debug_instruments.gd`'s assertion that `InstrumentBox` stays inside the
window and intersects no `HudRoot` child and no `StateInspector`, in both viewports, is now named
in AC2. Measured at this gate: the box sits at y[359,448] inside an empty band of y[354,452] --
roughly 4px of slack -- so adding per-slot countdown rows will very likely require re-fitting the
panel layout. Recorded as expected work, not a surprise to be discovered mid-implementation.

**3-0b/R5 -- AC2's ruled channel answers the standing objection.** A countdown does not "hand the
state layer's internals to presentation": the accessor returns COMPUTED PLAIN INTEGERS derived
from `TimingWindow.remaining_ticks()`, read-only, debug-only -- no state handle crosses the seam.
Presentation receives values, not internals, matching every other observation seam's discipline.
`to_snapshot()` is untouched, so the replay contract never learns the instrument exists.

**3-0b/R6 -- AC5: the flat `attack_move_speed_multiplier` is REMOVED, not kept alongside the three
new per-phase fields.** The `.tres` field-name registry in `test_data_resources.gd` is pinned; a
half-migration (old field retained beside the new ones) fails immediately. Ten files fan out from
the removal (grep-verified this session): `test_balance_authoring.gd` (header exemption + its
named test), `test_data_resources.gd`, `test_match_state.gd`, `test_contact_resolution.gd`,
`test_block_deflect.gd`, `test/state/test_contact_pipeline.gd` (distinct from the same-named
integration file, which does not author this field), `test_gamepad_controller.gd`,
`test_null_controller.gd`, `test_roll_iframes.gd`, `test_determinism.gd`. `test_match_state.gd`'s
deliberate non-zero `0.5` -- authored so a wrongful ATTACKING yields a distinguishable velocity --
must survive the migration, pinned on whichever phase that test drives.

**3-0b/R7 -- AC11 rewritten: two runs, not one.** The legibility protocol's primary run judges
shape and sting TOGETHER, unmuted -- that stays the primary run, and the story no longer asks for
"shape and sound judged separately," which was never how the protocol worked. S8 requires a
SECOND, separate pass: audio discrimination -- the naive observer, facing away from the screen,
hears a single sting and calls attack or block. AC11 requires BOTH runs, per
`docs/legibility-protocol.md` as amended this session (the audio-discrimination-pass commit, above
this one). AC11 still gates on AC9 being resolved first.

**3-0b/R8 -- AC13 rewritten: verdict on the BODY box; the shared sub-resource must split before any
resize.** `BoxShape3D_qp0e8` in `hero.tscn` is shared by both `Collision` and `HurtboxShape`, so a
naive resize would silently change the volume `_gather_contact_facts` detects -- a gameplay
change, not a cosmetic one. If the verdict is "resize," the sub-resource must FIRST be split into
separate shapes for `Collision` and `HurtboxShape`; hurtbox geometry stays at today's values unless
a separately logged decision changes it -- out of scope for this story under all circumstances.
The AC's stated figure "~1.725" is removed from the AC body -- unconfirmed, no measured record
behind it; the only measured repo value on record is "approximately 1.8" (3-0a's import check). A
remeasure is required before the verdict.

**3-0b/R9 -- Golden Prediction corrected, three ways.** (a) Citations: the isolation-runs
precedent is BC/R3 (melee-damage corrective pass) and the VALUES-only boundary it maps is SC/R6
(stamina-cost pass) -- every "BC/R3-R7" style citation is replaced with "BC/R3 + SC/R6." (b) The
"third re-baseline ever" ordinal is deleted entirely; the discipline is stated instead -- two named
causes, isolation runs between them, one re-baseline naming both separately -- with the actual
re-baseline count read off `test_determinism.gd`'s own record at the time of the change, not
asserted here in advance. (c) The phase is named: at the hashed tick, P1 is IDLE and P2 is in
attack RECOVERY, and the in-test golden config authors the multiplier `0.0` there -- so AC5's
coverage value must sit in the RECOVERY phase to be visible in the hash at all. For AC6, if the
lunge term is scoped to windup/active only, it is invisible at that same tick, and the prediction
legitimately forks to "MOVES from AC5 alone" -- a recorded, expected outcome, not a missed
prediction.

**Promotion.** All fixes applied to the story file the same session; story Status and board
promoted backlog -> ready-for-dev.
