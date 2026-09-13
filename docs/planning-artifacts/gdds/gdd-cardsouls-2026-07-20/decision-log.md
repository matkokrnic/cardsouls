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

**Pointer -- E3-P/R3 AMENDED BY APPEND 2026-08-04 (see Session 2026-08-04 -- Story 3-0c readiness gate, below, decision-log `3-0c/R5`).** The entry above is untouched and stands as the record; its contract is now scoped across a PAIR of stories, not one. `3-0c-intent-recorder` keeps the stream contract and its proof and is entirely headless (all capture channels, the `ReplayController`, replay-side contact-fact injection, the record-then-replay identity test). A new sibling slot, `3-0d-replay-surface-and-live-reload`, takes the operator surface and the live half of the balance-reload debt (`CACHE_MODE_IGNORE`, a live mid-match reload trigger, `user://` persistence and the serialisation format, the start/stop/load control, the live smoke). DEBT B therefore divides along its own stated seam: its stream half closes in `3-0c`, its cache half in `3-0d`.

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

---

## Session 2026-08-02 -- Story 3-0b Pass 1 (rulings)

Pass 1 of the four-pass split delivers AC1 (deterministic step/pause) and AC2 (per-slot window
countdown). Full suite re-run before this commit chain: 182 state tests / 844 assertions / 0
failed, 11 integration files individually green (`test_step_pause.gd` added); golden
`7fbb4b7f589251d25a13d6b49138b416266031e124cdae1c07e99e0f4fc119d1` UNMOVED -- neither AC touches
`src/state/`'s golden-reachable surface.

**3-0b/R10 -- AC1 freeze list, as shipped: FOUR items, not three.** `_match_state.advance()`, both
`HeroActor.drive()` calls, `_gather_contact_facts`, AND `_match_state.set_camera_basis()` (both
per-slot pushes) all sit inside `match_runner.gd::_physics_process`'s single `ticking` gate. The
camera-basis push is provably INERT while paused -- the stepped tick re-pushes the live rig basis
before `advance()` next reads it, so freezing it changes no observable behaviour -- but 3-0b/R1
(readiness gate) named only three items, and the AC describes DELIVERED software: the list is
corrected to match what actually ships, not the minimal set that would have sufficed. Camera
FOLLOW (step 4b, the split-screen viewport mirror) stays outside the gate, unchanged from R1.

**3-0b/R11 -- input latching REFUSED.** Controller sampling (`_p1_controller.sample()` /
`_p2_controller.sample()`) is NOT one of the frozen four -- it runs every tick, paused or not, per
R1's original scope. Consequence: a just-pressed edge made during a pause decays (Godot's edges
are frame-scoped) before the match resumes, so its intent is discarded -- you cannot arm an action
while paused and have it fire on the next step. Raised and ruled at Pass 1: latching the discarded
edge for replay on the next tick is REFUSED. Reason: a latch would be an input buffer living
outside the recorded intent stream, which is exactly what step/pause must never become (the same
principle R2 already applied to keep step/pause itself out of `InputIntent`). Workaround: hold the
key across the step.

**3-0b/R12 -- the "no contact facts accumulate while paused" claim is accepted as
CONSTRUCTION-delivered, not independently asserted.** `_gather_contact_facts` sits inside the same
`ticking` gate as `advance()` and `drive()` (R1's own rationale for including it in the freeze), so
with `advance()` frozen the accumulated-and-drained case and the empty case are indistinguishable
downstream -- there is nothing left for a dedicated test to tell apart. Ruled a deliberate choice
over a vacuous test, recorded so a future gate does not misread the absence of a test here as a
coverage hole.

**3-0b/R13 -- the sanctioned non-`Controller` reader shape, as built.**
`src/controllers/debug_input_reader.gd` (`DebugInputReader`, `extends RefCounted`) matches R3's
sanction exactly: no `sample()`, no `InputIntent` return, two plain-boolean accessors
(`pause_pressed()`, `step_pressed()`) reading `debug_pause` / `debug_step` as edges. D3(a) satisfied
(the reader lives under `src/controllers/`, the only `Input.*` call site for these two actions).
`test/state/test_debug_step_pause.gd` pins the shape by content -- `get_script().get_base_script()`
is null (extends `RefCounted` directly, not `Controller`) and `has_method("sample")` is false --
so a future "tidy-up" into a `Controller` fails loudly here.

**3-0b/R14 -- the debug accessor channel, as built.** `MatchState.debug_window_ticks_remaining()`
returns `Array[Dictionary]`, one entry per slot, each a `StringName -> int` map of only the
currently-running windows (built fresh per call, per R5's "values not internals" answer). The
runner polls it once per tick, immediately after `advance()`, and pushes the payload into
`DebugInstrumentPanel.set_window_countdown()`. `to_snapshot()` is pinned untouched by
`test_snapshot_shape_is_untouched_by_the_instrument` (`test/state/test_debug_window_countdown.gd`)
-- it hashes the snapshot before and after a call to the accessor and asserts the hash and both the
top-level and per-hero key sets are unchanged, so the replay contract provably never learns the
instrument exists.

**3-0b/R15 -- F1/F2 chosen as the match-global Input Map keys, collision-pinned.** `debug_pause` ->
physical `F1`, `debug_step` -> physical `F2`, both actions carrying no `p1_`/`p2_` prefix (R2's
match-global framing). `test_debug_keys_collide_with_no_other_project_binding`
(`test/state/test_debug_step_pause.gd`) scans every other project action (excluding Godot's
built-in `ui_*` set, which already shares keys with gameplay actions by design) for a physical-key
collision with either debug key and asserts zero.

**3-0b/R16 -- the AC2 geometry assertion (R4's must-stay-green regression) FAILED once during
implementation, evidence it is load-bearing.** Adding the countdown as two more VBox rows inside
the existing 98px-tall band (2-6's box already used 89 of it) pushed `InstrumentBox` outside the
empty band and collided with the vitals bars in `test/integration/test_debug_instruments.gd`'s
geometry check -- the regression R4 flagged as "very likely" was observed, not hypothetical. Fixed
by re-fitting the box horizontally instead of vertically: 300 -> 600 wide, contents split into two
columns (switches | countdown), keeping content height at the original ~89px inside the same band.
Recorded because a guard that never fails invites the assumption it is decorative; this one caught
a real regression during this story's own implementation.

**3-0b/R17 -- architecture amendment queue grows by one, the pre-existing items carried
forward.** The queue was last flushed at E2-CO/R1 (commit `f80f90e`) and has not been re-flushed
since; it grew by two at 3-0a/R10 (the `assets/` Directory Tree gap, carried forward again here,
plus the import-post-processing pattern and the new `assets/`-artifact-type finding, both still
unflushed). It gains a THIRD member from this Pass 1 session:
  3. **A non-`Controller` class under `src/controllers/`** -- `src/controllers/debug_input_reader.gd`
     (`DebugInputReader`), sanctioned at the 3-0b readiness gate (3-0b/R3) and now BUILT (3-0b/R13,
     above): it does not implement `sample()` and does not return an `InputIntent`, unlike every
     other member of that folder (`KeyboardController`, `GamepadController`, `NullController`, all
     `Controller`s implementing `sample()`). `docs/game-architecture.md`'s `### Directory Tree` and
     `### D3 -- Controller Abstraction` sections both describe that folder as `Controller`-only; that
     description is now stale.
  Queued; NOT edited into `docs/game-architecture.md` this session (this commit is queue bookkeeping
  only, no architecture-doc-body edit). Forcing point: the next architecture amendment queue flush
  (pattern: E2-CO/R1).

## Session 2026-08-02 -- Story 3-0b Pass 2 (rulings)

Pass 2 of the four-pass split delivers AC5 (per-phase attack movement multipliers) and AC6
(attack lunge, state-side velocity). Full suite re-run before this commit chain: 188 state
tests / 874 assertions / 0 failed, 11 integration files individually green; golden
re-baselined once, `7fbb4b7f589251d25a13d6b49138b416266031e124cdae1c07e99e0f4fc119d1` ->
`96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b`.

**3-0b/R18 -- the neutral authored migration: the SEAT is Pass 2, the VALUES are AC8's.**
The three per-phase fields that replace `attack_move_speed_multiplier` are all authored at
the flat field's old value, `0.0`, in `data/balance/balance_config.tres`. This is deliberate:
Pass 2's obligation is AC5's structural obligation (the flat field REMOVED, three per-phase
fields in its place, `.tres` field-name registry pinned) -- it is not a tuning pass. Live feel
is therefore unchanged by this commit chain by construction; judging what the three values
should actually be is AC8's verdict, reserved for Pass 4 against live play.

**3-0b/R19 -- the lunge phase scope, ruled: WINDUP and ACTIVE only.** `_attack_lunge_velocity()`
returns a non-zero term only while `HeroState.attack_phase()` reports `windup`/`windup_done` or
`active`/`active_done`; RECOVERY carries none. Rationale: the lunge is the commitment forward
INTO the swing, matching the 1-7 close-out's sanctioned form ("applied by the STATE layer as a
velocity curve during the swing"). Whether the hero should keep drifting forward through
recovery is a separate feel question, not this AC's to answer -- if a future pass wants
recovery drift, it is a new, separately-ruled term, not an extension of this one's phase scope.

**3-0b/R20 -- four implementation choices accepted, as built.**
1. The lunge is ADDITIVE to the steered velocity (`world_dir * speed + lunge`), never a
   replacement. At the authored `0.0` multipliers the lunge is therefore the WHOLE of attack
   velocity today -- the intended shape: input steers nothing mid-swing, the swing itself
   carries the hero forward.
2. Speed is `attack_lunge_distance / (attack_windup_seconds + attack_active_seconds)` -- the
   roll's `roll_distance / roll_duration_seconds` precedent verbatim. This yields a flat
   (constant-speed) curve; an eased curve is a Pass 4 feel decision, not decided here.
3. Boundary-tick phases (`windup_done`, `active_done`) group with their un-suffixed sibling
   exactly as `HeroState.transition_row()` already groups them, in BOTH
   `_attack_phase_multiplier()` and `_attack_lunge_velocity()` -- so the two phase consumers
   this story adds can never disagree about which phase a boundary tick belongs to.
4. Lunge direction reads `HeroState.facing` LIVE, at the moment of use, rather than an
   entry-locked direction captured at swing start. This keeps the lunge out of the snapshot
   entirely -- no new state field, no snapshot-shape change -- which is the direct reason
   AC6 was a measured golden non-mover rather than a second snapshot-shape re-baseline.

**3-0b/R21 -- live facing accepted for Pass 2, WITH a named open question for AC8/Pass 4.**
Because facing updates every tick an intent is live (the existing velocity-only-commitment
rule), the lunge is steerable mid-swing: a hero turning while attacking lunges along the NEW
facing, not the facing it had when the swing started. This is in tension with the word
"commitment." Ruled acceptable for Pass 2 because the alternative -- entry-locking the lunge
direction, the `roll_direction` shape -- requires a new stored snapshot field and therefore a
SNAPSHOT SHAPE CHANGE with its own golden re-baseline, out of proportion for this pass's
structural obligation. If the Pass 4 playtest verdict (AC8) judges that steerable lunge
breaks commitment, the fix is entry-locking, and it gets its OWN pass with its own
re-baseline -- it must not be squeezed into Pass 4's tuning work.

**3-0b/R22 -- the re-baseline record: one re-baseline, two causes named separately, an
isolation probe proving the seat is hash-neutral.** `_golden_config()` in `test_determinism.gd`
authors the three per-phase fields as three DISTINCT non-neutral values (windup 0.25 / active
0.5 / recovery 0.75) and `attack_lunge_distance` at 2.0, for path coverage. Measured in three
points: baseline `7fbb4b7f...` (Pass 1 close) -> AC5 landed alone `96ac5f64...` (MOVED, as
predicted) -> AC5+AC6 `96ac5f64...` (bit-identical to the AC5-alone measurement -- AC6 a
measured NON-MOVER). AC6's prediction was a mover; the actual outcome is the fork the story's
Golden Prediction section named in advance as a legitimate, non-missed outcome, reason: at the
hashed tick P1 is IDLE and P2 is in RECOVERY, and the lunge (R19) carries no term in recovery.
The isolation probe: with the three per-phase fields in place, toggling ONLY the recovery
value back to `0.0` (windup 0.25 / active 0.5 left in place) reproduced the OLD golden
`7fbb4b7f...` exactly. This proves two things in one probe -- the per-phase SEAT itself is
hash-neutral when the visible phase still carries the old flat value, and the windup/active
coverage values are themselves measured non-movers at this fixture (their attack-tick
velocities are per-tick transients overwritten before the hashed tick, the same "1-9 cause 2"
shape recurring a third time). Independent confirmation of AC6's hash invisibility:
mutation-deleting the lunge term from `_resolve_movement` during implementation left
`test_state_matches_golden` passing -- observed directly, not inferred from the isolation
probe alone.

---

## Session 2026-08-02 -- Story 3-0b Pass 3 (rulings)

Pass 3 of the four-pass split delivers AC3 (clip/window reconciliation), AC4 (roll Hips
excursion fix), AC7 (block in-between-frames verdict), AC9 (sting distinctness), and AC10
(`pose_id` retirement). No `src/state/` change this pass -- golden untouched. Full suite
re-run before this commit chain: 188 state tests / 874 assertions / 0 failed, 12
integration files individually green (`test_clip_timing.gd` new).

**3-0b/R23 -- AC7 VERDICT: KEEP the instant block entry.** The deciding reason is NOT
generic latency: `enter_block()` opens the 9-tick (0.15s) deflect window on the entry tick,
so a 0.05s blend would cover a THIRD of that window (0.1s would cover TWO THIRDS) with a
"shield still rising" pose on screen while the deflect window is already live. That is a
legibility lie placed exactly where legibility is load-bearing, and it would corrupt
AC11's naive-observer read of the parry. Trade-off recorded honestly the other way: the
pop is a real visual artifact -- the least animated moment in the combat loop -- and the
cost of keeping it is purely aesthetic, while the cost of softening it would have been
mechanical (misrepresenting when the deflect window is actually open).

**3-0b/R24 -- AC7 follow-on, ruled: a blend on block EXIT is a genuinely different,
genuinely open case, NOT taken in this story.** Exit is instant to IDLE with nothing
mechanical live afterward -- no recovery window, and stamina-regen suppression lifts the
same tick -- so a blend on exit misrepresents nothing mechanical, unlike a blend on entry
(R23). Recorded as a named future option WITH its conditions already established, so a
future pass does not have to re-derive them: it must be scoped to block -> IDLE only
(block -> attack and block -> roll start real mechanical content immediately and must stay
instant), and it requires amending 3-0a's "a transition arriving mid-clip wins immediately
with NO blending" policy plus a conditional in `_play()` -- a policy amendment, not a
parameter tweak.

**3-0b/R25 -- AC10 EXPLICIT LOGGED RETIREMENT (this entry is the AC deliverable).**
`pose_id` is retired from `TelegraphProfile`, not wired to a consumer. Deciding asymmetry:
`shape_id` and `sting_id` name presentation nodes that actually exist (`Shapes/<shape_id>`
and the `<sting_id>` `AudioStreamPlayer`, both children of `TelegraphController`) --
`pose_id` names nothing. Wiring it would have required a SECOND copy of the
`ActionState -> TelegraphProfile` mapping (1-10/R1 rules that mapping is owned by
`TelegraphController` alone) plus a pose -> clip indirection layered on top of the
existing `AnimationController._CLIP` mapping, and would still have covered only the three
telegraphing states -- IDLE and DEAD have no telegraph profile and never will, so `_CLIP`
survives regardless of what `pose_id` does. That is two selection mechanisms replacing
one, split on a line (telegraphing vs not) that has nothing to do with animation. The
"authored now, consumed when the rig lands" bet (1-10, DEBT E member 4) already failed
once: the rig landed in 3-0a and no honest consumer emerged. Removed rather than carried a
second time; a future story that genuinely needs pose vocabulary can re-add one export
more cheaply than this dead contract was carried.

**3-0b/R26 -- AC3's direction lock made executable, and the tool that pays for it.**
`test/integration/test_clip_timing.gd` reads the `attack`/`roll` windows through
`BalanceTicks.from_config()` -- the same seconds->ticks boundary `advance()` uses -- rather
than hardcoding tick counts, so retuning any of `attack_windup_seconds`,
`attack_active_seconds`, `attack_recovery_seconds`, or `roll_duration_seconds` now
requires re-running `tools/retime_clips.gd` in the SAME pass, or the test fails.
`tools/retime_clips.gd` is promoted from this pass's throwaway retiming script to a
committed, parametric tool: it derives its target windows the same way the test does,
rather than encoding this pass's numbers, and is verified as a no-op against the
already-reconciled library. Recorded as an ACCEPTED NARROWING of the standing "a balance
tuning change is a one-line `.tres` edit with no test consequence" property (BC/R3), scoped
to exactly these four fields -- every other authored field keeps the full isolation BC/R3
established.

**3-0b/R27 -- AC4's route and threshold.** Route taken (of the two 3-0a/R14 named): zero
the roll clip's Hips X/Z position keys while preserving Y, not a clip swap. Measured:
planar excursion 1.0895 -> 0.0000, vertical dip 0.7213 preserved so the dive still reads as
a dive rather than an upright lateral glide. `test_clip_timing.gd` pins a regression
ceiling, `ROLL_HIPS_PLANAR_MAX = 0.25`, derived from geometry rather than picked
arbitrarily: the `RollDisc` telegraph (`CylinderMesh_tgdisc`, `hero.tscn`) has radius 0.8,
and the hero's body box (1x2x1) has half-width 0.5; at 0.25 the hips stay under a third of
the disc's radius and under half the body's own half-width, so the body cannot leave its
own footprint, let alone the disc. The delivered value sits far inside that ceiling by
design -- it is a regression ceiling with large headroom, not a value anyone tuned up to.

**3-0b/R28 -- AC9's delivery, with AC11 named as its verdict.** `sting_attack.wav` and
`sting_block.wav` are made audibly distinct on four orthogonal axes: duration (0.070s vs
0.220s), onset (instant vs soft), register (~1000-1180 Hz vs ~160-240 Hz), and glide
direction (rising vs falling) -- glide direction is the PRIMARY cue, since it needs no
reference pitch to judge, unlike the prior single-frequency difference (875 Hz vs 520 Hz)
that S8 (2-6/R19) found indiscriminable. Both stings stay normalized to the original peak
(0.60), so discrimination is timbral, not a loudness difference. This ruling records the
DELIVERY only -- the verdict on whether it actually reads as distinct belongs to AC11's
naive-observer audio-discrimination pass, reserved for Pass 4 (AC9 is a precondition of
AC11 per 3-0b/R7).

## Session 2026-08-02 -- Story 3-0b Pass 3b (rulings)

Pass 3b delivers AC4's VERTICAL half (Pass 3 delivered only the lateral half) and a
pre-existing chain-retrigger fix, both verified by the operator in live play. No
`src/state/` change this pass -- golden untouched. Full suite re-run before this commit
chain: 188 state tests / 874 assertions / 0 failed, 14 integration files individually
green (`test_chain_retrigger.gd`, `test_vertical_alignment.gd` new).

**3-0b/R29 -- the anchor convention, as measured, and that the suspected telegraph-height
contradiction did not exist.** Every presentation anchor in `hero.tscn` is a child of the
hero ROOT and keys off the collision box: root is the body CENTRE, `Collision`/
`HurtboxShape` span root y [-1,+1], and `main.tscn`'s spawn at y 1.0 puts the box floor
exactly on the ground's top surface. Measured at this gate: nine of ten anchors obeyed
that convention; the paladin model was the SOLE non-conformer, because its FBX origin is
at the feet and 3-0a instanced it with no transform, leaving the model floating exactly
1.0 above the box floor. Going in, the two authored telegraph heights (`+1.5` for
`AttackCone`/`BlockShield`, `-0.95` for `RollDisc`) looked like they might disagree with
each other; measured, they do not: `+1.5` is 0.5 above the box top exactly as `-0.95` is
0.05 above the box floor, both authored in story 1-10 against a box-only hero, before any
model existed. The apparent contradiction was an artifact of reading box-relative
authoring against a floating model, not a real inconsistency in the 1-10 authoring.

**3-0b/R30 -- operator ruling: the telegraphs travel WITH the model, not re-anchored
overhead.** `Mesh.position.y = -1.0` grounds the model on the box floor;
`AttackCone`/`BlockShield`/`DeflectSpark` drop by the same 1.0 (`+1.5 -> +0.5`,
`+1.5 -> +0.5`, `+1.3 -> +0.3`) rather than being re-anchored to read overhead against the
now-lower model. Reason: the cone was ALREADY intersecting the model's head before this
fix (world 2.5 against a measured head top of 2.7255), so dropping it by the same 1.0
preserves BIT-IDENTICALLY the composition that already passed the 2-6 and 3-0a live
smokes -- whereas re-anchoring overhead would have introduced an unreviewed composition
immediately before AC11's naive-observer run, the highest-stakes review this story has.
Accepted cost, named explicitly: the cone and shield now intersect the model's head and
shoulders and are partly occluded by it. That cost is deferred, not absorbed here -- AC11
judges with evidence whether it harms legibility, and the telegraphs move again only if
that verdict says so.

**3-0b/R31 -- the chain-retrigger cause, both suppressors, and why the seek is
load-bearing.** `attack_chain_length = 3` with a 30-tick chain window deliberately lets a
new swing begin before the previous one finishes, and the state layer was correct
throughout: `chain_attack()` explicitly re-emits ATTACKING -> ATTACKING on the
action-state seam precisely so presentation learns of a swing that changes no state
(pinned state-side by `test_action_state.gd`'s `[atk, atk]` sequence). Measured: the
consumer swallowed it via TWO INDEPENDENT suppressors, not one. First,
`AnimationController._play()`'s selector guarded on `current_animation != clip` -- a
chained swing's clip name is already `attack`, so the guard alone made it a no-op.
Second, and independently of that guard: `AnimationPlayer.play(name)` is itself a no-op
on playback POSITION when `name` is already the current, still-playing animation
(measured directly on Godot 4.6.3 -- play, advance to 0.30, play the same name again,
position is still 0.30). Because the second suppressor exists independently of the
first, removing only the name guard would not have fixed the defect; the fix's
`seek(0.0, true)` is therefore LOAD-BEARING, not belt-and-braces alongside the guard
removal.

**3-0b/R32 -- the rejected route: a swing index through `drive()`.** Pushing a chained-
swing index through `HeroActor.drive()` (the 3-0a run-speed precedent shape) was
considered and rejected. That precedent exists ONLY where the seam genuinely cannot
carry the event -- `run` has no `ActionState` behind it, so `drive()` is the only channel
locomotion has. A chained swing is different: it already has a dedicated, already-tested
emission on an existing seam (the ATTACKING -> ATTACKING self-transition). Routing a
parallel payload through `drive()` as well would have plumbed a second channel for an
event already arriving on the first, and left the action-state seam silently broken for
every future same-state transition a new state might introduce. NO EIGHTH SEAM was
added; the fix (`_restart()`) consumes the existing seam correctly instead.

**3-0b/R33 -- the defect predates Pass 3; Pass 3 made it legible, not present.** At the
pre-Pass-3 90-tick attack clip length, all three swings of a chain were suppressed
identically (one animation played for three swings), which reads as uniform enough to be
mistaken for an intentional held-pose chaining policy. Pass 3's AC3 retime to 45 ticks
changed the ratio: two of three swings now got a visible animation and one did not,
turning a uniform (and easily misread) behavior into a conspicuous gap. The defect itself
-- the two suppressors in `AnimationController` -- has been present since 3-0a shipped
that script; nothing about Pass 3's retime introduced it.

**3-0b/R34 -- SUITE BLIND SPOT, a standing lesson that outlives this story.** The suite
asserts authored data AT REST and never runtime COMPOSITION. Before Pass 3b, no test
anywhere referenced `AnimationController`, `current_animation`, or which clip is actually
playing. A relative measure (the Hips excursion in `test_clip_timing.gd`) is
mathematically blind to a constant offset; a clip inventory (`test_rig_clips.gd`) is
blind to selection and retrigger. The blind class this names: absolute placement, clip
selection, retrigger, layering, visibility, and every "the seam fires but the consumer
ignores it" failure -- precisely what a naive observer catches instantly and a green
suite never mentions. `test_vertical_alignment.gd` and `test_chain_retrigger.gd` attack
this hole from opposite sides: one asserts an absolute spatial relationship across two
packed scene files (hero-local and world-space, cross-checked against `main.tscn`'s spawn
and ground), the other drives the real `AnimationController` callback through a
three-swing chain and asserts the runtime selection/retrigger outcome. Recorded here as
its own ruling, separate from the AC4/chain-retrigger rulings above, because the lesson is
general: any future presentation seam with a runtime SELECTION or PLACEMENT decision
needs its own test asking "what actually happened at runtime", not only tests of the data
it was authored from -- a green suite is not evidence that a seam's consumer is doing
anything with what it receives.

## Session 2026-08-02 -- Story 3-0b Pass 4 (close-out)

Pass 4 delivers the four ACs left after Pass 3b (8, 11, 12, 13), closing every acceptance
criterion in the story. Both remaining verdicts are "keep" and AC8 mandates no `.tres`
edit, so no `src/state/` change lands this pass -- golden untouched. Full suite re-run
before this commit chain and again after the AC12 data edit: 188 state tests / 874
assertions / 0 failed, 14 integration files individually green, golden
`96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b` unmoved.

**3-0b/R35 -- AC8 VERDICT: NO CHANGE, closing DEBT E member 1.** No `.tres` edits, no
retime, therefore no golden question. The operator's Pass-1-era tempo observation ("the
attack is too fast but does not feel fast because the animation is too slow; the roll
feels too slow") is resolved by Pass 3's AC3 retime on its own merits -- the attack clip no
longer lags the authored window, so the attack now FEELS as fast as it already was. This
also answers the second of the "TWO NAMED INPUTS to AC8" recorded at Pass 3: the operator
judged hit registration to coincide with the sword's visual arrival, so the measured 55.5%
impact-peak offset (one to two ticks after the active window closes) is not visible in
play, and the piecewise per-phase retime that would close that gap is deliberately NOT
built. A verdict on the input, not an omission -- the finer instrument (`tools/
retime_clips.gd` does not do piecewise retiming today) stays on the shelf until a future
pass's playtest evidence actually calls for it.

**3-0b/R36 -- AC11 PASSED, both runs, every trial correct -- and the occlusion question it
resolves rather than assumes.** The primary run (shape and sting judged TOGETHER, unmuted,
half viewport, per `docs/legibility-protocol.md`) and the separate audio discrimination
pass (S8, observer facing away from the screen, sting alone) both passed with a genuine
naive observer, every trial correctly identified. This settles the question Pass 3b
explicitly deferred (3-0b/R29-R30): grounding the paladin model left the `AttackCone` and
`BlockShield` partly occluding the head/shoulders, an accepted cost at the time, ruled on
by AC11 rather than assumed away. The occlusion does NOT harm legibility -- observed, not
inferred -- so the telegraph anchors do not move. AC9/AC11 ordering (locked at the
readiness gate) was respected: the sting-distinctness pass (Pass 3) landed before this run.

**3-0b/R37 -- AC12 VERDICT: KEEP `normalize_move_magnitude = true`.** Deciding reason,
code-checkable and requiring no pad session: there is exactly one locomotion clip (`run`),
no walk clip and no blend space, and the minimum above-deadzone analog speed is 1.0 u/s
against a clip-selection threshold of 0.1 -- so with normalization off, a lightly deflected
stick would walk at speed 1.0 while the legs play the full-speed `run` clip authored for
5.0, foot-sliding across the entire lower half of the analog range with no threshold value
able to fix it. The verdict reopens if and when a walk clip or blend space exists. The
pad A/B session named in the story's Dev Notes was deliberately skipped -- the deciding
argument is code-checkable and confirming the shipped default costs no change. Landed as
`chore(data)`: the field is now authored explicitly in `data/gamepad_profile.tres` rather
than inheriting the script default silently.

**3-0b/R38 -- AC13 VERDICT: leave the collision box at height 2.0.** A remeasurement DID
run this pass -- Pass 4A CPU-skinned every vertex of every skinned surface (9835 vertices,
4 surfaces, 69 bones) in hero-root space and cross-checked the result two independent ways
(mesh-AABB against live node transforms, and the bone-origin Y span). Result: 1.7255 at
rest. Per clip: idle 1.6319, run 1.6151, attack 1.7942, block 1.4269, roll 1.9887, death
1.6563. The "~1.725" figure struck at the readiness gate (3-0b/R8) as unverified turns out
to have been correct; 3-0a's "~1.8" import-check value was the loose one.

The reason to keep 2.0 is not merely that the box is larger than the model. At Pass 4A the
box was correct but the model was misplaced -- floating 1.0 above the box floor -- and
resizing the box then would have tightened it around a model that was not where it
belonged, making things worse. Pass 3b fixed the placement instead. With grounding
delivered, the model now spans hero-root y [-1.0, +0.7255] inside a box spanning [-1, +1]:
the box floor sits exactly at the feet, with 0.2745 of headroom above the model, and the
attack clip's peak (1.7942 above the feet, i.e. +0.7942) still fits inside. 2.0 is the
correct height for the alignment that now exists, not a slack value tolerated.

A resize would still cost the same collateral as before: first splitting the shared
`BoxShape3D_qp0e8` sub-resource into separate `Collision`/`HurtboxShape` shapes (AC13's own
precondition, so a body-height change cannot silently move the hurtbox volume
`_gather_contact_facts` reads). Not worth the collateral for a cosmetic-only gain. Hurtbox
geometry is untouched, as it must be under all circumstances.

**Flagged observation, unverified, NOT a ruling:** the roll clip's measured minimum is
0.3404 below the rest feet plane, so after grounding the model may dip below the ground
plane mid-roll. This was measured before grounding landed and has not been checked by eye
since. Recorded for a future pass or live session to confirm or dismiss -- owned by nobody
yet.

**3-0b/R39 -- FOUR NAMED DEFERRALS, each given an owner so they are debts with an
address.** (a) the attack may be a touch too fast; (b) the roll may want to be slightly
slower; (c) the i-frames may want to run slightly longer; (d) the attack and the roll
should not cost the same stamina. All four are owned by a later tuning pass, once the full
gameplay loop exists to tune feel against -- the operator's stated priority is reaching
that loop first, not micro-tuning combat feel in isolation from the system it will
eventually sit inside (cards, mana, the rest of E3).

**3-0b/R40 -- live-smoke status, recorded per the TRUTHFULNESS RULE, no softening either
direction.** The Pass 4 `docs/playtest-log.md` entry (dated 2.8., six numbered
observations plus a sound-telegraph note) reads as a SOLO feel-judgment session -- the
operator judging attack speed, roll reaction timing, presence of all three animations,
hit-registration timing against the sword's arrival, i-frame duration, and invulnerability
feel, by eye, alone. Nothing in the entry places a second human on the other slot, and
nothing in it evidences either side being killed. It therefore does NOT evidence a
two-human match on the shipped default with both sides killable, and AC11's naive-observer
session (an observer WATCHING) is explicitly not read as satisfying it either -- watching
is not playing. **R-D6 is NOT re-invoked by 3-0b.** It remains AVAILABLE, last spent at
3-0a/R15 (the fifth two-human smoke), carried forward to the next story that ships
player-facing behaviour. This does not block the story's close-out -- only the record.

## Session 2026-08-02 -- Story 3-0b close-out

**What landed (f61ca54 chore(data) / 9959bd0 docs(playtest-log) / 4a6a6a4 docs(stories)
board+status; this decision-log commit itself carries the Pass 4 rulings above and this
close-out session).** All thirteen acceptance criteria delivered across four passes plus
one corrective pass. Pass 1 (3-0b/R10 onward) shipped deterministic step/pause and the
per-slot debug window countdown. Pass 2 (3-0b/R18 onward) replaced the flat attack-move
multiplier with three per-phase fields and added a state-side additive attack lunge,
re-baselining the golden once with both causes measured and named separately. Pass 3
(3-0b/R23 onward) reconciled the attack and roll clips to their authored tick windows,
fixed the roll's lateral Hips excursion, ruled to KEEP the block clip's instant pop, made
the attack and block stings audibly distinct, and explicitly retired `pose_id`. Pass 3b
(3-0b/R29 onward), an unplanned corrective pass, closed the vertical half of the roll fix
that Pass 3 had only half-delivered (the model floating a full unit above the box floor)
and fixed an unrelated chain-retrigger defect predating 3-0a, exposing and partly closing a
standing suite blind spot (authored data at rest vs. runtime composition) along the way.
Pass 4 (3-0b/R35 onward, this session) closed the remaining four judgment calls -- AC8 NO
CHANGE, AC11 PASSED, AC12 KEEP, AC13 leave as-is -- named four deferrals with an owner, and
recorded the live-smoke status truthfully rather than as hoped. Final state: golden
re-baselined exactly once across the whole story (`7fbb4b7f...` -> `96ac5f64...`); suite 188
state tests / 874 assertions / 0 failed, 14 integration files individually green
(`test_step_pause.gd`, `test_clip_timing.gd`, `test_vertical_alignment.gd`,
`test_chain_retrigger.gd` added across the five passes, several mutation-proven); R-D6
live-smoke acceptance NOT re-invoked, remains available. What E3 inherits: a melee loop
whose timing, movement, and legibility have been judged and tuned against the real rig,
with every DEBT E member and every 3-0a live-smoke finding closed, and four named,
owned tuning deferrals waiting on the full gameplay loop rather than blocking it.

---

## Session 2026-08-02 -- Story 3-1 readiness gate (operator decisions)

Readiness gate on `3-1-matchstate-config-object.md` (2.8, report-only, run against `8ba69b4`)
returned **NOT READY** on first read: seven blocking findings (B1-B7), eight notes (N1-N8), four
questions (Q1-Q4). This is the same first-pass verdict every Set B story's gate has returned --
all thirteen logged Set B gates return NOT READY at first read and are fixed and promoted within
the same session (recounted at the E3 revisit gate, above) -- and this gate is no exception in
either direction: fixed and promoted the same session, story Status and board `backlog ->
ready-for-dev`.

**What the gate found, in substance.** (B1) The Golden Prediction named baseline `33817201...`,
which predates TWO re-baselines -- the stamina-cost corrective pass and 3-0b Pass 2 -- so the
section's own anchor was dead text; it also predicted NONE without naming what the prediction was
conditional on, which is the one thing that makes a NONE prediction checkable. (B2) The ACs mixed
rationale into the contract, so several were not verifiable claims about shipped software.
(B3) AC2's field list was written before the consuming stories existed and committed 3-1 to
authoring five card/deck numbers nothing could yet be tuned against. (B4) AC3's tick-conversion
clause presupposed at least one new `*_seconds` field, which the scope strip removes entirely.
(B5) The BC/R2 reconciliation -- the melee damage halving having doubled mana per point of damage
-- was named in the E3 revisit gate but nowhere in the story, so the dev pass could have authored
the new cap without re-basing the per-hit value against it. (B6) Citations were stale: the story
pointed at `match_state.gd:539-545` for `_apply_balance_to_player` (now `:670-676`) and at
`balance_config.gd:44` / `.tres:21` for `melee_hit_mana` (now `:69` / `:25`) -- remembered line
numbers, not content. (B7) No pre-injection contract existed at all: with the constructor's stat
floats removed, a `MatchState` built without `apply_balance` becomes stat-less as well as inert,
and nothing in the story said what that state must be or which tests pin it.

**Notes recorded (N1-N8), the load-bearing ones.** N1: the story described the call-site fan-out
as "the small number of existing call sites"; grep-verified this session it is ONE `src/` call
site (`match_runner.gd:77`) plus 25 test call sites across 13 files, and the honest number belongs
in the story. N2/N3: the Dev Notes carried a stale complaint that `epics.md:96-97` still framed the
attack stamina cost as a possible 3-1 seat -- that text was SWEPT in the E3 revisit-gate amendment
commit `10b96a1`, and `epics.md:96-99` now reads correctly (decision (d) RESOLVED at DP/R2; the
value and its golden re-baseline explicitly not a 3-1 seat), so the note's evidence was corrected
rather than the disclaimer dropped. N4: the story still carried the verbatim E3 revisit-gate banner
telling the reader the gate had not run -- replaced with a scope note stating that it ran (31.7,
E3-RG/R1..R12), that DP/R3 waived the separate external playtest, and that this story then passed
its own gate. N5: the test-surface work (`E1_BALANCE_FIELDS`, the authoring audit, the determinism
fixture) was implied but never made an acceptance criterion. N7: `mana_regen_per_second` is an
authoring-unit field only in this story -- the derived `mana_regen_per_tick` seat on `BalanceTicks`
and the `advance()` ladder seat belong to 3-4 (E3-RG/R8), and no `BalanceTicks` field may land here.

**Q1 -- SCOPE STRIP, ruled.** `hand_size`, `deck_size`, `draw_replacement_delay_seconds`,
`reshuffle_vulnerable_window_seconds`, and `default_copies_per_card` are REMOVED from 3-1; each is
added just-in-time by its consuming story (3-2/3-3), where its value can be authored against
something real rather than guessed a story early. Two riders recorded:
`reshuffle_vulnerable_window_seconds` additionally PRICES OPEN decision (b), which is undecided --
it is authored nowhere until (b) is ruled, and (b) keeps its existing forcing point; and
`default_copies_per_card` is likely per-card data rather than a `BalanceConfig` field, which 3-2
judges. Consequence: 3-1 adds exactly TWO new `BalanceConfig` fields, neither a `*_seconds` field,
so no new tick conversion lands in this story at all (which resolves B4).

**Q2 -- resolved by Q1.** The question of how `reshuffle_vulnerable_window_seconds` should be
authored while OPEN decision (b) is undecided disappears with the field: it is not authored
anywhere in 3-1, and decision (b) stays open at its existing forcing point.

**Q3 -- R-D6 does not attach.** 3-1 ships no player-facing code path, so the two-human live-smoke
acceptance is not invoked by this story; it stays AVAILABLE (last spent at 3-0a/R15) for the next
story that ships player-facing behaviour. Recorded with the observation that makes it checkable:
the mana rescale keeps per-hit bar fill IDENTICAL -- `8/80 == 1/10 == 10%` of the bar -- and the
passive regen value has no consumer until 3-4, so nothing visibly changes until 3-4, whose smoke IS
required and is the first live observation of the new scale.

**Q4 -- confirmed.** `BalanceConfig` wins as the single source of truth for all four tunables
(`max_hp`, `move_speed`, `max_stamina`, `max_mana`); the constructor stops carrying them and the
runner's four tunable constants are deleted. The seed goes to a match-scoped `MatchParams` object
injected once at construction and never re-applied by `apply_balance()` (E3-RG/R9, locked) --
`_SEED` survives in the runner only as that object's source.

**3-1/R1 -- THE MANA SET, Matko's design call: `max_mana = 10.0`, `melee_hit_mana = 1.0`,
`mana_regen_per_second = 0.25`.** Authored together as one coherent set per E3-RG/R1, against the
GDD's canonical scale (~10 max, ~1/sec adjusted to card costs) and its worked card costs, 3 (Imp
Summoner, Basic) and 5 (Hellburst, Pitch). The criterion is recorded with the numbers so a later
tuning pass can check the same thing: one round of the GDD's stated length (~60-120 s of active
play) funds ~2-4 buildup->bluff->payoff cycles. Arithmetic for this set: passive 0.25/s is ~22 mana
over 90 s, melee income at 1.0 per confirmed hit adds the rest, which funds 3-5 cycles at 6-10 mana
per cycle -- slightly hot, inside the criterion, and cheaply retunable as a `chore(balance)` edit
that cannot move the golden. `melee_hit_mana` is RE-AUTHORED, not added: it is an existing shipped
field (`balance_config.gd:69`, `.tres:25`), and a second field of the same meaning would author a
duplicate. This also discharges BC/R2: the damage halving (6 -> 3) left `melee_hit_mana` at 8.0 and
so doubled mana per point of damage (8/6 ~= 1.33 -> 8/3 ~= 2.67); the new set re-bases both
together at 1.0 mana per hit against damage 3 (~0.33 per hit-point, 10% of the 10-mana bar). The
shipped 80 cap and 8.0 per-hit value are PLACEHOLDERS REPLACED here, not values to carry across.

**3-1/R2 -- THE PER-POOL RELOAD CONTRACT, Matko's design call.** On `apply_balance()` mid-match the
three pools are deliberately NOT symmetric. Stamina: `set_maximum` + `refill`, D9 unchanged, and
`test_mid_match_reload_refills_stamina_to_max` survives untouched. Mana: `set_maximum` ONLY --
current clamped to the new maximum, NEVER refilled, because `ManaPool`'s own contract is that mana
starts empty and is built by the flywheel (`mana_pool.gd:4-5`), and a reload-refill would hand a
free full bar mid-match. That never-refill rule is pinned by a NEW test that must be
mutation-proven to fail if a refill is added. HP: current preserved and clamped to the new maximum,
never refilled -- exactly what ships today. Match start yields full hp, full stamina, empty mana.
In-flight timing windows survive a reload (existing test untouched), and the hot-reload path stays
TEST-ONLY: DEBT B is untouched and no live mid-match reload trigger is introduced.

**3-1/R3 -- THE PRE-INJECTION CONTRACT (gate ruling, answering B7).** A `MatchState` constructed
without `apply_balance()` is inert AND stat-less: no stamina regen, no contact resolution, no round
end -- `_check_resolution()` joins the `balance_ticks == null` gated family it is currently outside
of. The three inertness tests (`test_action_state.gd::test_null_balance_ticks_guard_actions_inert`,
`test_stamina_economy.gd::test_no_regen_without_apply_balance`,
`test_contact_resolution.gd::test_contacts_inert_without_apply_balance`) currently assert
constructor-supplied fixed values (100.0 / 30.0) and are re-anchored to "unchanged from
construction," each mutation-proven to fail without the guard it pins.

**3-1/R4 -- THE `set_max_hp` FINDING, verified at this gate by code read, and what it forces.**
`HeroState._init(queue, max_hp, move_speed_value)` sets BOTH `_max_hp` and `_hp = max_hp`, so "full
hp at match start" comes from the CONSTRUCTOR today, not from `apply_balance()`.
`set_max_hp(maximum)` (`hero_state.gd:176-178`) sets `_max_hp` and then calls `_set_hp(_hp)`, which
CLAMPS the current value into `[0, new max]` and never raises it. One uniform `apply_balance` rule
therefore cannot produce both required outcomes: once the constructor stops carrying `max_hp`, a
stat-less hero sits at `_hp = 0.0` and `set_max_hp(100.0)` leaves it there -- a hero that starts the
match dead. Ruling: the story flags an explicit FIRST-INJECTION initialization as a dev-pass task,
with the outcomes of 3-1/R2 as its contract and the mechanism left to the dev pass. This is also the
independent reason `_check_resolution()` must be guarded (3-1/R3): unguarded, a 0-hp pre-injection
hero would end the round on the first tick.

**3-1/R5 -- GOLDEN PREDICTION re-derived (gate ruling, answering B1).** Baseline corrected to the
current `96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b`. Prediction: NONE,
conditional on two NAMED things, both measured rather than assumed. (1) `_golden_config()` must
author `max_mana = 90.0` exactly -- the value of the fixture's current in-test `MAX_MANA` constant;
any other value moves the hash, because `ManaPool.to_snapshot()` emits `{current, maximum}`. (2) The
double-injection reconciliation must change no value the golden run receives -- a field-by-field
diff of the golden's constructor constants against `_golden_config()`'s authored values, done BEFORE
implementing; expected a no-op, measured not assumed. A third candidate cause, a mana refill on
`apply_balance()`, is ELIMINATED by 3-1/R2's never-refill ruling. The fixture edit at the golden
test's `MatchState.new` call site is FORCED by AC1 regardless of the hash. Discipline unchanged:
measure in both directions, and any movement is stop-isolate-report, never a silent re-baseline (the
1-5 cause-(c) lesson). The authored `.tres` values (10.0 / 1.0 / 0.25) cannot move the golden --
`_golden_config()` builds its fixture in-test and never loads `data/balance/balance_config.tres`,
proven at BC/R3 and re-confirmed by SC/R6 and the 3-0b gate.

**Promotion.** All fixes applied to the story file the same session (`docs(stories)` commit,
immediately preceding this one); story Status and board promoted `backlog -> ready-for-dev`; dev
pass next. Docs-only pass -- no suite run, no code touched.

## Session 2026-08-02 -- 3-1 close-out

Continues this story's readiness-gate numbering with rulings 3-1/R6..R9, recorded after the dev
pass (2.8, Claude Opus 4.8) landed and the commit chain (Claude Sonnet 5) verified and shipped it.

**3-1/R6 -- AC5 PROVABILITY, and a PERMANENT addendum to the 3-0b/R34 blind-spot family.** AC5's
mutation clause originally claimed all three re-anchored inertness tests were mutation-proven
against each of the guards they touch. Measured this session: only the NEW `_check_resolution()`
guard is value-provable by those tests -- deleting it fails all three, because a stat-less 0-hp
hero ends the round on tick 1. The two PRE-EXISTING `balance_ticks == null` guards (step 3's
action-resolution gate, step 5's regen gate) are CRASH-guards, not value-guards: GDScript's
null-dereference semantic aborts only the function it occurs in, and the caller resumes on the
next line with exit code 0 and byte-identical state, so removing either guard is invisible to any
value assertion the suite can make. This was equally true before this story -- it is not a
regression 3-1 introduces -- and AC5 is amended in the story file to match the delivered software
rather than overclaim it (`docs(3-1)` commit, this chain). Recorded here as a PERMANENT addendum
to 3-0b/R34: the suite is blind not only to runtime composition it never asserts, but also to
guard-removals that degrade into an intra-function abort with an identical end state. Zero
`SCRIPT ERROR` lines in the harness's own output is currently the ONLY detector for this class, and
it is informal -- nothing fails the suite if a `SCRIPT ERROR` appears. OPEN, no owner: make the
harness FAIL on `SCRIPT ERROR` lines in its own output; ownership decided at the E3 retrospective.

**3-1/R7 -- `mana_regen_per_second` stays AUDITED > 0.** The 3-1/R1 funding criterion (~2-4
buildup->bluff->payoff cycles per round) explicitly counts the passive faucet (~22 mana over 90 s
at 0.25/s) as part of the arithmetic it was chosen against, so a silently zeroed passive would
break the criterion the values were authored to satisfy without any test noticing. Confirmed: this
field belongs in the audited-positive class alongside `stamina_regen_per_second`, not the exempt
class. A future tuning pass that deliberately wants a melee-only economy LIFTS this exemption the
way 1-8 lifted the `deflect_stamina_cost` exemption (R-N6) -- deliberately, with the reason recorded
at the point it happens, not silently.

**3-1/R8 -- class-cache hand-edit, sanctioned retroactively.** `MatchParams` was registered by hand
in `.godot/global_script_class_cache.cfg` during the dev pass rather than by opening the editor
mid-pass. That file is git-ignored, the hand-edit was disclosed in the dev pass record, and the
editor was never opened during the pass itself. This chain's own Phase 1 editor scan (the one
sanctioned editor invocation) generated `src/state/match_params.gd.uid` with `project.godot`
SHA256-identical before and after the scan
(`31033A50137C98DCB740B051B74EA0EBA99AA92DC993CA075BF8E466B71BCB1F`, measured both sides, this
chain) and produced exactly one new file beyond the dev-pass surface -- no other collateral. The
hand-edit is sanctioned on that basis.

**3-1/R9 -- surface honesty, confirmed.** File List is the story's named 13 plus 2:
`test/integration/test_hero_movement.gd` (a comment-only fix citing the deleted
`match_runner._MOVE_SPEED`) and `test/state/test_economy_and_hero.gd` (because `PlayerState` is
also constructed stat-less -- one production caller, `MatchState`, with the leaf-object
constructors, `HeroState`/`StaminaPool`/`ManaPool`, left untouched -- accepted at review as ruling
D4). `MatchState.new`'s fan-out was sized correctly at the readiness gate: 1 `src/` call site
(`match_runner.gd:77`) plus 25 test call sites across 13 files, confirmed unchanged by this pass's
own file list.

---

## Session 2026-08-02 -- Story 3-4 readiness gate

Readiness gate on `3-4-mana-economy-flywheel.md` (report-only, run against `71d4775`) returned
**NOT READY** on first read: nine blocking findings. This is the same first-pass verdict every Set B
story's gate has returned -- fourteen PRIOR Set B readiness-gate sessions (seven E1, six E2, plus 3-1
on 2026-08-02), all NOT READY on first read; 3-4 makes it **15/15** -- and this gate is no exception
in either direction: fixed and promoted the same session, story Status and board `backlog ->
ready-for-dev`.

**Two premise corrections, resolved before the blocking findings.** (1) The gate's own first-pass
framing treated the architecture amendment queue as if it held a single member (the E0/E3 evaluator
attribution this gate itself surfaces). Verified by content against the full decision-log history:
the queue currently holds FOUR members, none of them this gate's finding -- (a) the `assets/`
Directory Tree gap, a pre-existing item missed by the E2-CO/R1 flush and carried forward (3-0a/R10);
(b) import post-processing as a repo pattern, `strip_model_anim.gd` (3-0a/R10); (c) a new artifact
type under `assets/`, the import-time `.gd` script plus the committed `AnimationLibrary` `.res`
(3-0a/R10); (d) a non-`Controller` class under `src/controllers/`, `debug_input_reader.gd`
(3-0b/R17 Pass 1). This gate's own finding (the E0/E3 evaluator attribution + Novel Pattern 5) is a
FIFTH member, not the queue's only one -- see 3-4/R4 below. (2) The gate's first pass flagged
`sprint-status.yaml`'s board shape -- `epic-3: backlog` with every child story carrying a HOLD note
in `story_notes` -- as an apparent inconsistency. Verified by content: this is the STANDARD shape
this board has used since the E3 revisit gate, identically for 3-2, 3-3, 3-5, and 3-6 (each `backlog`
in `development_status` with its own HOLD note in `story_notes`, per the gate outcome recorded
2026-07-31); it is not a defect specific to 3-4.

**The nine blocking findings, resolved.**
- **B1 -- `CardCastCondition` had no business in this story's scope.** AC1 named
  `CardCastCondition` as constructed by 3-4 alongside `ResourceGenerationRule`/`EconomyEvaluator`.
  Ruling: STRIPPED to 3-2, designed there against the working evaluator this story delivers (ORDER
  ruling -- the evaluator must exist before a cast condition can be evaluated against it). AC1
  rewritten to exactly two rule instances, `melee_hit` and `passive_tick`; nothing in 3-4 gates card
  casts.
- **B2 -- the N7 obligation (3-1 gate, decision-log:2014-2016) was a Dev Note, not an AC.** The
  derived `mana_regen_per_tick` seat on `BalanceTicks` and the `advance()` ladder rung were an
  obligation recorded at 3-1's gate but never promoted to a verifiable claim in 3-4's own text.
  Promoted to AC4 in full, including the seat's exact location (step 5) and its suppression
  semantics (3-4/R2 below).
- **B3 -- the Golden Prediction's baseline was unnamed.** The original text read "whatever
  3-1/3-2/3-3 leave it at," unverifiable at the time it was written and now provably wrong in order
  (3-4 precedes 3-2/3-3, per `epics.md`'s own committed-obligations list). Corrected to the concrete,
  current baseline `96ac5f6467ee8de5866391b1886c112794b89ee24f0ed56e6a5597bb6a5d966b`, unmoved through
  3-1.
- **B4 -- fixture-blindness discovery.** The original prediction assumed the authored `.tres`
  `mana_regen_per_second` (0.25, 3-1/R1) would itself move the golden once non-zero. Verified by
  content: `_golden_config()` builds its fixture in-test and never loads
  `data/balance/balance_config.tres` (BC/R3, re-confirmed SC/R6 and the 3-0b gate) -- the authored
  value cannot reach the golden by any route. The actual, sole movement cause is a deliberate
  `_golden_config()` fixture coverage edit (precedent: `attack_stamina_cost` 6.0, `roll_distance` 3.0),
  named as such in the rewritten Golden Prediction section.
- **B5 -- false `BalanceTicks` cause removed.** The original text speculated the passive tick "adds
  a derived field" to `BalanceTicks` as a possible second golden-moving cause. `BalanceTicks` is
  load-time config, rebuilt from `BalanceConfig` and never part of `to_snapshot()` -- structurally
  incapable of moving the hash on its own, regardless of which fields it carries. Removed; the
  fixture coverage edit (B4) is the ONE named cause.
- **B6 -- the Live Smoke section contradicted itself.** The original text required smoke "at
  flag-matrix granularity, not full two-human," while separately naming the flywheel-vs-bookkeeping
  question as something only a real two-human exchange can answer. Resolved: REQUIRED, full
  two-human, flag ON, on the shipped default. R-D6 ATTACHES to this story and is SPENT -- 3-4 is the
  first player-facing story since 3-1, which shipped no player-facing code path (3-1/Q3) and left
  R-D6 available (last spent 3-0a/R15).
- **B7 -- the stale E3-revisit banner.** Lines 5-7 still told the reader the gate had not run.
  Replaced with a Scope note in the 3-1 pattern: the E3 revisit gate ran 2026-07-31 (E3-RG/R1..R12),
  this story's own gate ran 2026-08-02, and DP/R3 waived the separate external playtest.
- **B8 -- AC3/AC4 carried rationale instead of verifiable claims.** Old AC3's "with no error and no
  special-case path" and old AC4's HUD-wiring narrative mixed justification into the contract. Both
  rewritten to pure claims about shipped software (AC3, AC4 below); the rationale moved to Dev Notes.
- **B9 -- "with no error" is unassertable.** Old AC3 required flag-off degradation "with no error."
  GDScript's null-dereference semantic aborts only the function it occurs in and the caller resumes
  with exit code 0 and byte-identical state (the crash-guard-blind family, permanently recorded at
  3-1/R6) -- no test can distinguish "no error" from "an error the suite cannot see." Dropped; no new
  null guard in this story's scope is claimed mutation-proven on that basis.

**3-4/R1 -- AC set replaced with six verifiable claims (resolves B1/B2/B8/B9).** AC1 scope (two rule
instances, `CardCastCondition` excluded); AC2 replacement proof (the golden-unmoved measurement IS
the proof artifact); AC3 flag scope (both configurations run through the evaluator, no second path);
AC4 passive mechanism (regen method, `BalanceTicks` seat, step-5 rung, sealed suppression semantics);
AC5 behavior (flag matrix, clamp, source filtering, plus a DEAD-suppression proof); AC6 CONSTRAINT C
(new, below).

**3-4/R2 -- sealed design decisions, with reasoning.** No delay window on passive regen: unlike
stamina's `_regen_delay`, passive mana is dead machinery until the first mana spender lands (3-2/3-5),
so it arrives just-in-time then rather than being built speculatively now. DEAD suppressed, BLOCKING
NOT suppressed: DEAD follows the standing "a corpse runs no economy" doctrine already applied to
stamina (2-3/R5); BLOCKING is deliberately excluded from mana's suppression set because mana buildup
behind a block IS the flywheel's point, and block already pays its own cost through stamina
suppression -- mana does not need to double-charge it. The step-5 seat is not a new decision but the
documented ladder meaning: `advance()`'s own step-5 comment already reads "stamina regen (story 1-4)
then melee-hit mana (story 1-5)" -- the `passive_tick` rung joins the slot `_generate_mana` already
occupies. The round-over freeze needs no new guard: step 1b returns before step 2, so step 5 is
never reached on a frozen tick -- recorded as a no-action Dev Note, not an AC.

**3-4/R3 -- CONSTRAINT C promoted to AC6, with its proof.** The evaluator must read `ms.balance` /
`ms.balance_ticks` inline at point of use and never cache a reference, since `apply_balance` swaps the
whole `BalanceTicks` object on reload. Value-provable test: a mid-match `apply_balance` with a
different `mana_regen_per_second` must change the very next tick's regen rate -- this also exercises
the per-pool reload contract (mana `set_maximum` + clamp, no refill, pinned by
`test_mid_match_reload_sets_mana_maximum_but_never_refills`).

**3-4/R4 -- architecture amendment queue gains a FIFTH member.** The four pre-existing members stand
as enumerated in the premise correction above, unflushed since E2-CO/R1. This gate's own finding (the
evaluator non-existence + the doc's already-landed framing) is the fifth: `docs/game-architecture.md`
describes `ResourceGenerationRule`/`CardCastCondition`/`EconomyEvaluator` as already landed in the
Directory Tree (`:548,553`), the D6 capability table ("E0/E3 · Full", `:107,190`), the
Testable-without-engine-runtime table (`:511`), and Novel Pattern 5 (`:788-806`) -- unlike the
`MatchState` config object, explicitly marked "Planned (E3)" (`:613`). All four need reconciling
against the evaluator this story actually constructs, once it ships. Flush point unchanged: the next
architecture amendment queue flush (pattern: E2-CO/R1), not this story.

**Promotion.** All fixes applied to the story file the same session (`docs(stories)` commit,
immediately preceding this one); story Status and board promoted `backlog -> ready-for-dev`; dev
pass next. Docs-only pass -- no suite run, no code touched.

## Session 2026-08-02 -- 3-4 close-out

Continues this story's readiness-gate numbering with rulings 3-4/R5..R11, recorded after the dev
pass (Claude Opus 4.8) landed and the commit chain (Claude Sonnet 5) verified and shipped it.
Verification this session: HEAD started at `9f15a0f`, matching `origin/main`; no Godot process
running; the dev-pass surface matched the expected file list exactly, `project.godot` byte-for-byte
unchanged (empty diff); state harness 208 tests / 977 assertions / 0 failed, all 14 integration
files PASS individually, zero `SCRIPT ERROR` lines.

**3-4/R5 -- three-measurement golden discipline, re-baseline confirmed.** Per AC2's proof-artifact
requirement and the Golden Prediction section, three measurements were taken in order: (1) the
evaluator swap alone, both authored rules already present -- UNMOVED, `96ac5f64...`; (2) the passive
rung landed with `_golden_config`'s `mana_regen_per_second` still `0.0` -- UNMOVED, still
`96ac5f64...`, isolating the `BalanceTicks` seat (load-time config, never snapshotted, structurally
incapable of moving the hash alone) from the coverage value; (3) `_golden_config` authors
`mana_regen_per_second 75.0` (1.25/tick) -- MOVED, `96ac5f64...` -> `98d0c7eb...`. One named cause,
one re-baseline, confirmed in both directions exactly as predicted.

**3-4/R6 -- BC/R3 NARROWED, formal ruling.** BC/R3's standing property -- authored data cannot move
the determinism golden -- is henceforth read as applying to BALANCE/TUNING data only
(`data/balance/*.tres`, never read by `_golden_config`'s in-test fixture). `data/economy/*.tres` is
a DIFFERENT class: the rule set is loaded and read by the production code path the golden run
actually exercises (`EconomyEvaluator.authored_rules()` inside `_generate_mana`), so rule CONTENT is
load-bearing for the hash exactly like code. Proven by mutation M5 (below): renaming
`passive_tick.tres`'s named field to `stamina_regen_per_tick` moved the golden and failed 29 tests
across 6 files. A rule edit therefore carries golden discipline like a code change, not like a
balance-tuning edit -- this is a narrowing of BC/R3's scope, not a repeal of it.

**3-4/R7 -- rules have no reload path, BY DESIGN, not a DEBT B member.** `EconomyEvaluator.authored_rules()`
loads once (`_authored_loaded` static gate) and is never re-scanned mid-match, the FeatureFlags
load-once precedent. This is deliberately NOT filed as a DEBT B member: DEBT B is about a future
hot-reload capability for content that currently loads once by convention, and hot-reloadable rules
would be their own story carrying BOTH DEBT B halves (the reload trigger and the mid-match
consistency guarantee) -- neither of which any of AC1-AC6 asked for. A rule edit today needs a
restart, and that is the shipped contract, not a placeholder for one.

**3-4/R8 -- export-packing remap risk, named flag, no owner.** `EconomyEvaluator.load_rules()`
sources its rule set via `DirAccess.open(dir_path)` + `ends_with(".tres")` filtering over
`res://data/economy/` at runtime. This is fragile under export/packaging remap -- an exported build
that flattens or renames resource paths could silently return an empty or wrong rule set with no
error (the loader's own missing-directory guard degrades to an empty set, not a crash). Zero impact
today (the project has no export/packaging story yet); the risk activates on the first one. Recorded
here with no owner; not blocking for E1.

**3-4/R9 -- architecture amendment queue's FIFTH member, expanded.** The fifth member recorded at
3-4/R4 (the doc's already-landed framing for `ResourceGenerationRule`/`CardCastCondition`/
`EconomyEvaluator`) is expanded, now that the evaluator has actually shipped, to include four
concrete reconciliation points against `docs/game-architecture.md`: (a) rules name a balance FIELD
(`amount_field`) rather than carrying Novel Pattern 5's sketched amount float directly; (b) the
evaluator COMPUTES and the pool APPLIES (`amount_for()` returns a number, touches no pool), a
deliberate departure from Novel Pattern 5's sketch of the evaluator calling `player.mana.add()`
itself; (c) the loader mechanism (a sorted directory scan, first `load()` call in `src/state/`) has
no counterpart in the doc's description; (d) the new `data/economy/` directory is absent from the
Directory Tree, alongside the pre-existing `assets/` gap (3-0a/R10). Flush point unchanged: the next
architecture amendment queue flush (pattern: E2-CO/R1), not this story.

**3-4/R10 -- D2/D4 recorded as review rulings.** D2: the two pre-existing flat `12.0` mana pins in
`test_golden_sequence_exercises_block_and_deflect` (t13, t24) and
`test_golden_sequence_exercises_iframe_negation` (t20, t24) are rewritten as
`12.0 + N * PASSIVE_PER_TICK` -- both changes trace to 3-4/R5's measurement (3) alone, no second
cause. D4: three crash-guards are accepted as NOT mutation-proven -- `EconomyEvaluator._amount`'s
`home == null` guard and its dereferenced-value type check, and `load_rules`'s `dir == null` guard --
the same class of admission as 3-1/R6. The directory-scan claim rests on mutation M5 (3-4/R6 above)
plus the different-directory assertions in `test_rule_set_is_a_directory_scan_not_a_hardcoded_list`;
no dedicated preload-list mutation exists because there is no preload list to mutate.

**3-4/R11 -- live smoke PASSED, R-D6 spent, four findings parked, one waiver.** Two live runs on the
shipped default, flag ON, zero manual edits between them; run 1 confirmed passive creep on both mana
bars, an attacker-only jump on confirmed hits, and BLOCKING still filling; run 2 confirmed a kill,
round-over, and stable fps. R-D6 re-invoked and SPENT (first player-facing story since 3-1, which
left it available). Four findings parked, none blocking: S1 (passive rate possibly too fast) and S2
(`melee_hit_mana` at ~10% of the bar possibly too high, operator suggests 5% or less), both
PROVISIONAL TUNING parked to the 3-2 forcing point -- a round should finance 2-4 loop cycles, and
that criterion is unjudgeable before cards have costs, and the retune is golden-neutral since the
fixture authors its own coverage value; S3 (should a blocked hit pay reduced mana?), a NAMED OPEN
FINDING rather than tuning -- today's full-mana-on-block is the LOCKED 1-8 decision, and a reduction
would be a new mechanism (new balance field, golden mover), forcing point 3-2 / the tuning pass; S4
(reset appears to carry full mana), a NAMED OPEN DESIGN QUESTION with no owner -- verified against
`_reset_player` (`match_state.gd:777-781`), which heals hp and clears `DEAD` but never touches mana
or stamina, so the observation is leftover pre-death mana surviving the reset untouched, not a grant
-- forcing point the first real round-flow story or the tuning pass. The DEAD-freeze live
observation is WAIVED: headless-proven by `test_dead_hero_gains_no_passive_mana_on_its_one_dead_tick`
plus mutation M1, and visually indistinguishable in play since the mana clamp absorbs both the
suppressed and unsuppressed cases identically at cap.

**Close-out.** Commit chain: `story 3-4: economy evaluator + passive mana tick` (code, tests, data),
`docs(3-4): dev pass record + smoke record` (this story's Dev Pass Record and Smoke Record,
corrected once mid-chain to replace a fabricated mutation-table draft with the real M1-M6 data
above), `board: promote 3-4-mana-economy-flywheel to done (review passed)`, and this entry. No push
-- the operator reviews the log and pushes.

## Session 2026-08-03 -- Story 3-2 readiness gate

Readiness gate on `3-2-card-schemas-carddatabase.md` (report-only, run against `172fb09`) returned
**NOT READY** on first read: nine blocking findings. This is the same first-pass verdict every Set B
story's gate has returned -- fifteen PRIOR Set B readiness-gate sessions (seven E1, six E2, plus 3-1
and 3-4 on 2026-08-02), all NOT READY on first read -- 3-2 makes it **16/16** -- and this gate is no
exception in either direction: fixed and promoted the same session, story Status and board `backlog
-> ready-for-dev`.

**Why this gate matters beyond its own findings -- the CONFIRM proved shallow.** 3-2 is the one E3
story the revisit gate CONFIRMED rather than amended (E3-RG/R outcome, decision-log Session
2026-07-31: "3-2 is implementable as written apart from two cosmetic fixes"). The cleanest evidence
that a confirm is not the same guarantee an amendment is: the sibling card-play story (3-5) had its
invariant-helper name corrected at that same gate -- old text read `check_invariant`, corrected to
`Invariant.check` (`src/systems/invariant.gd`, verified by content: `static func check(condition:
bool, message: String) -> void`) -- while 3-2's own AC4 carried the identical wrong name,
`check_invariant`, untouched through the same commit (`10b96a1`), because it sat inside the "CONFIRMED
as written" two-cosmetic-fixes bucket rather than the amended one. Both spellings recorded here so the
finding is checkable without opening the commit: wrong = `check_invariant` (names no real symbol);
shipped = `Invariant.check`.

**Premise corrections, with content, resolved before the blocking findings.**
(i) The decision log records no per-story ruling enumerating VERIFIED CLAIMS for 3-2 -- the E3
revisit-gate entry states only that the story was "implementable as written apart from two cosmetic
fixes" (Session 2026-07-31, above). The per-claim framing this gate's own report used (treating each
old AC as independently verified) came from the gate report itself, not from anything the log had
actually recorded; the confirm was a summary verdict, not a claim-by-claim audit.
(ii) The GDD's second referenced card price -- Mode ④ Pitch, "Mana (higher) + orbs (per card); all
orbs reset to 0 on activation" (`gdd.md`, the four-mode table) -- is a MODE of the SAME card, not a
second card: "Card anatomy. Every card carries... a Basic effect + mana cost, and a Pitch effect +
cost" (`gdd.md`, Card System). That price is reserved for a later epic (E6) and is not authored live
by this story.
(iii) Four smoke findings from 3-4's live smoke are parked, not three (3-4/R11, above: S1, S2, S3,
S4) -- an earlier draft of this gate's own report undercounted them at three, dropping S4 (the
mana-survives-reset finding) silently.
(iv) The claim that authoring a hand-size `BalanceConfig` field would move the determinism golden is
FALSE. Verified by content: `PlayerState.to_snapshot()` emits `"hand_size": hand.size()` -- it reads
the hand ARRAY's own size, not a balance field -- and `test_determinism.gd`'s `_golden_config()`
builds its `BalanceConfig` in-test, never loading `data/balance/balance_config.tres` (BC/R3,
re-confirmed SC/R6, the 3-0b gate, and 3-4/R6's narrowing). A balance field is therefore hash-neutral
by construction; what actually moves the golden is POPULATING the hand array, which belongs to the
deck story (3-3), not to authoring a number. This is recorded as the gate's most valuable finding --
it heads off a wrong assumption before it reaches 3-3's own gate.

**The nine blocking findings, resolved.**
- **Banner residue plus a dangling cross-reference.** The story still opened with the verbatim
  pre-gate E3-REVISIT banner and a line pointing at 3-1 "for the full verbatim gate" -- 3-1's own
  banner was already replaced with a Scope note at its own fix pass, so the pointer dangled. Replaced
  with a Scope note in the 3-1/3-4 pattern (story file, above).
- **An unsatisfiable injection clause.** Old AC3 required `CardDatabase` to both preload cards AND for
  "the state layer" to receive them "by injection" in the same story, with no consumer anywhere in
  3-2's own scope to inject them INTO -- an AC that cannot be checked against shipped software until a
  later story exists. Resolved by AC2's explicit economy-evaluator exclusion and AC4's loader-only
  scope; `stories-manual-e3.md`'s E3.S2 exit criterion was corrected alongside (companion commit) to
  scope the injection clause to E3.S5.
- **An AC asserting a balance field that does not exist and belongs to a later epic.** Old AC4 named
  "per-colour unblockable damage... a fixed value per colour in balance" as something this story's
  guard protects -- but that balance field is not authored anywhere yet, and authoring it is not this
  story's business (it is gated behind `FeatureFlags.unblockable`, a later epic). Replaced by AC7,
  which carries ONLY the negative guard (a test fails if a per-card damage/unblockable field appears),
  asserting nothing about a field that doesn't exist.
- **The wrong invariant-helper name.** Discussed above -- dropped by rewording AC7 as a pure claim
  about test behaviour, with no mechanism name to get wrong.
- **A golden baseline stale across three intervening re-baselines.** The Golden Prediction section still
  cited `33817201...21da2`, which predates the stamina-cost corrective pass, 3-0b Pass 2, and the 3-4
  economy re-baseline. Corrected to the current baseline (the `GOLDEN` constant in
  `test_determinism.gd`) `98d0c7ebfdbe01a97622b185a7e3388428793cc87e323751c2ffb5b6f58f81ff`, prediction
  NONE measured in both directions, with the deliberate cards/rules asymmetry against 3-4/R6's BC/R3
  narrowing recorded explicitly (rules are load-bearing for the hash; cards are not, by design).
- **Undeclared inherited scope.** The copies-cap ruling assigned to this story by 3-1's own gate (Q1
  rider: "`default_copies_per_card` is likely per-card data rather than a `BalanceConfig` field, which
  3-2 judges") was nowhere named in 3-2's text -- a reader could not tell this story was discharging an
  obligation another story's gate created. Named in Dev Notes and discharged as AC3's `max_copies`
  export.
- **Unspecified card identity and iteration order.** Nothing in the story said whether a card's
  identity is its filename or a field, or whether the loaded set has any ordering contract -- both
  become load-bearing the moment the deck-shuffle story (3-3) makes deck order hash-visible. Ruled and
  recorded in Dev Notes: identity is a FIELD, filename mirroring it is convention only; any ordered
  exposure is explicitly sorted, dictionary iteration order is never a contract.
- **Two schema divergences from the architecture doc, undeclared.** Verified by content: the `CardData`
  sketch under "Novel Pattern 6 -- Four-Mode Card Resolution" lists four exports where this story ships
  six (`id`, `max_copies` added), and `CardEffect` appears in no schema list under "Schema vs Loader
  (class_name uniqueness)" and no Directory Tree line. Neither divergence was named anywhere in the
  story. Recorded as the SIXTH member of the architecture amendment queue (the queue held five per
  3-4/R4 and R9), alongside the already-queued fifth member's own staleness (Novel Pattern 5 still
  shows the pre-3-4 evaluator shape) -- no edit to the architecture doc itself, per the standing
  flush-point convention (E2-CO/R1).
- **Silence on the parked findings.** 3-4's four live-smoke findings (S1-S4) named this story as a
  forcing point for S1/S2, but nothing in 3-2's text acknowledged owning them, or explained why S3 and
  S4 do NOT land here. All four now have an explicit seat, recorded in Dev Notes and restated as
  rulings below.

**Rulings, restated from the story's Dev Notes.**
- **Schema-only, evaluator deferred.** `CardCastCondition` is a pure schema; no cast evaluator ships
  in `src/state/economy/` this story. Its first consumer is the card-play story (3-5), designed
  against the working `EconomyEvaluator` 3-4 already shipped -- the reason `CardCastCondition` was
  stripped out of 3-4's own scope back to this story ("STRIPPED to 3-2, designed there against the
  working evaluator this story delivers," 3-4's gate finding B1, above).
- **`mana_cost` is a literal float, never a balance-field name.** Deliberate break from the
  `ResourceGenerationRule.amount_field` mirror: every gameplay NUMBER shared across the game lives in
  balance, but a card's price is per-card CONTENT.
- **`id` is a field, never the filename.** Survives a rename; becomes a replay-relevant identity once
  3-3 makes deck order hash-visible.
- **The copies cap is per-card data, not a `BalanceConfig` field** -- discharging the obligation 3-1's
  gate assigned here.
- **Cards stay outside the hashed run, with the asymmetry against rules reasoned explicitly.** Rule
  content IS load-bearing for the golden (3-4/R6, narrowing BC/R3, proven by mutation M5's 29
  failures) because the rule set is two files and a fixed mechanism; card content is NOT, because cards
  are a growing content library and making them hash-bearing would mean every new card re-baselines
  the golden -- defeating the "new card = a `.tres`, no code" promise this story exists to deliver.
- **S1/S2 (tuning) get one seat here, discharged by pricing, not by retuning.** The retune itself is a
  separate, golden-neutral `chore(balance)` commit whose forcing point moves to the first live smoke in
  which a card can actually be cast -- the "2-4 cycles per round" criterion is unjudgeable before then.
- **S3 (blocked-hit mana) gets its OWN, separate seat.** It is a new mechanism (a new balance field, a
  certain golden mover) that would reverse the locked 1-8 decision that a block does not touch the
  attacker's economy -- not a tuning value, and not this story's to rule on.
- **S4 (mana survives a reset) is NOT inherited here.** It belongs to the first round-flow story;
  verified against `MatchState._reset_player()` (`src/state/match_state.gd`), which never touches mana
  or stamina, so the observation is leftover pre-death mana, not a grant.
- **The scan-helper deferral, with the extended remap flag.** A shared directory-scan helper between
  `CardDatabase._load_all()` and `EconomyEvaluator.load_rules()` is deferred to a third scan -- the two
  existing scans sit on opposite sides of the state/systems boundary and a shared helper has no honest
  home yet. The ownerless export-packaging remap risk named at 3-4/R8 is EXTENDED to cover
  `data/cards/` alongside `data/economy/`, rather than filed a second time.
- **The new integration test, and why the state harness cannot cover it.** The state harness
  instantiates no autoloads, so nothing in it ever exercises `CardDatabase._ready()`; only a real
  integration test proves the loader actually populates itself at boot, and a silently empty card
  dictionary would today be noticed by nothing else.

**Operator's sealed design decisions.**
- **The buildup->bluff->payoff cycle cost is taken as roughly 11 mana** (one 5-cost pitch plus two
  3-cost plays: 5 + 3 + 3), after a deck-throughput reading (a full pass through the 20-card deck) was
  considered and explicitly rejected -- the GDD's cycle is buildup -> bluff -> payoff, not a pass
  through the deck.
- **A nine-card starter set ships at three per colour**, one each at 2/3/5 mana, with a preference on
  record for four or five cards per colour LATER -- deferred because adding a card is a `.tres` with no
  code change, so there is no cost to shipping the smaller set now and growing it later.

**Note for the remaining epic stories.** The same stale E3-revisit banner residue found here is
present in 3-3, 3-5, and 3-6 -- their own gates should not spend a finding rediscovering it; the fix
is the same Scope-note replacement applied at 3-1, 3-4, and here.

**Promotion.** All fixes applied to the story file the same session (`docs(stories)` commit,
immediately preceding this one); story Status and board promoted `backlog -> ready-for-dev`; dev pass
next. Docs-only pass -- no suite run, no code touched.

## Session 2026-08-03 -- 3-2 close-out

Recorded after the dev pass (Claude Opus 4.8) landed and the commit chain (Claude Sonnet 5) verified
and shipped it. Verification this session: HEAD started at `20e9af7`, matching `origin/main`; the
dev-pass surface matched the expected file list exactly (14 files added, 3 modified); no Godot process
running; `project.godot` byte-for-byte unchanged before and after the editor scan
(`31033a50137c98dc...`); state harness 218 tests / 1103 assertions / 0 failed, all 15 integration
files PASS individually (a fifteenth, `test_card_database.gd`, added this story), zero `SCRIPT ERROR`
/ `Parse Error` / `INVARIANT VIOLATED` lines.

**What shipped, and what deliberately did not.** Three schemas (`CardData`, `CardEffect`,
`CardCastCondition`) land in `src/state/resources/`; nine fixture cards land in `data/cards/`;
`CardDatabase._load_all()` replaces its no-op body with a sorted, extension-filtered, single-directory
scan indexed by the `id` field, plus a `card_count()` read accessor; two new test surfaces
(`test/state/test_card_authoring.gd`, `test/integration/test_card_database.gd`); the AC5 state-layer
guard, mutation-proven. NO cast evaluator ships -- `src/state/economy/` carries only the comment-only
reciprocal cross-reference AC4 requires. The evaluator's first consumer is the card-play story (3-5),
under the contract this story records: pure, static, computes rather than applies -- `ManaPool.spend()`'s
shape (returns a bool, changes nothing when unaffordable) is the one the cast evaluator must mirror on
the spend side; pools apply the spend, the evaluator never does.

**The golden prediction held: NONE, measured before the first edit and after the last, unmoved
(`98d0c7eb...` throughout).** The standing consequence stays in force: card `.tres` content is NOT
load-bearing for the hash and must not become so -- if a later story needs cards inside the tick loop
they arrive by injection, and the golden fixture authors its own coverage value, exactly as
`_golden_config()` already does for balance and economy fields. This is the deliberate ASYMMETRY with
`data/economy/*.tres`, whose content IS load-bearing (3-4/R6, proven by mutation M5's 29 failures) --
the rule set is two files and a fixed mechanism, while cards are a growing content library, and making
card content hash-bearing would mean every new card re-baselines the golden, defeating the "new card =
a `.tres`, no code" promise this story exists to deliver.

**M3 is the session's most valuable measurement.** With the loader body dead (`if true: return` at the
top of `_load_all()`), the entire state harness stays green -- it instantiates no autoloads, and the
authoring test loads the `.tres` files itself -- and the integration test is the only thing in the repo
that bites (count=0 expected 9, all nine ids missing, RESULT: FAIL). That is exactly the claim that
justified requiring the integration test in the first place ("a silently empty card dictionary would
today be noticed by nothing," AC6/the gate's own finding), now demonstrated by mutation rather than
asserted.

**A NAMED OPEN WITH NO OWNER: `orb_costs` has ZERO coverage.** No card authors it (correctly -- orbs
are pitch-only by the GDD), and no test round-trips a populated typed dictionary through a `.tres`. So
that field's serialisation has never been exercised with content. No action taken deliberately:
authoring a fixture card just to test it would be authoring data with no consumer, the thing this
story exists to avoid. Forcing point: the first story that authors an orb cost, which is the pitch
epic (E6).

**The architecture amendment queue's SIXTH member, now concrete rather than predicted.** The `CardData`
schema ships six exports where the doc's "Novel Pattern 6 -- Four-Mode Card Resolution" sketch has
four (`id`, `max_copies` added); `CardEffect` appears in no schema list under "Schema vs Loader
(class_name uniqueness)" and no Directory Tree line. Flush at the epic close-out, per the standing
flush-point convention (E2-CO/R1); no edit to the architecture doc made here.

**The class-cache technique and the comment-only economy diff, recorded as rulings so neither is
re-litigated.** New `class_name` declarations cannot resolve without an editor scan, so the dev pass
hand-appended the three new entries (`CardData`, `CardEffect`, `CardCastCondition`) to the git-ignored
generated class cache in the exact format the editor writes, and this chain's editor scan regenerated
it correctly -- the second occurrence of this technique (the first was story 3-1), now the standing
division of labour. The `src/state/economy/economy_evaluator.gd` diff is docstring-only, zero code
lines -- sanctioned by AC4's explicit requirement for the reciprocal cross-reference, not a fence
breach against the "`src/state/economy/` is not touched" scope line.

**Board: done. Next story in the locked order: 3-3.**

**Close-out.** Commit chain: `story 3-2: card schemas, CardDatabase loader, starter set` (code, tests,
data), `docs(3-2): dev pass record` (this story's Dev Pass Record, Dev Notes additions, Dev Agent
Record, and Change Log), `board: promote 3-2-card-schemas-carddatabase to done`, and this entry. No
push -- the operator reviews the log and pushes.

## Session 2026-08-03 -- Story 3-3 readiness gate

Readiness gate on `3-3-deck-hand-draw-reshuffle.md` (docs-only, report-only) returned **NOT READY**
on first read. This is the same first-pass verdict every Set B story's gate has returned -- sixteen
PRIOR Set B readiness-gate sessions (seven E1, six E2, plus 3-1, 3-4, and 3-2, the last two on
2026-08-02 and 2026-08-03), all NOT READY on first read -- 3-3 makes it **17/17** -- and this gate is
no exception in either direction: fixed and promoted the same session, story Status and board `backlog
-> ready-for-dev`.

**Baseline measured green before the first edit** (docs-only pass; no code touched): state harness 218
tests / 1103 assertions / 0 failed; 15 integration files, each individually PASS; golden unmoved at
`98d0c7ebfdbe01a97622b185a7e3388428793cc87e323751c2ffb5b6f58f81ff`; `project.godot` SHA256 hash
unchanged (`31033a50137c98dc...`, matching the 3-2 close-out measurement -- this story adds no
autoload and touches no engine config);
engine 4.6.3.

**Premise corrections, with content, resolved before the blocking findings.**
(i) The pre-gate story text named exactly two Golden Prediction causes -- draw consuming the RNG (old
AC2) and `hand_size` becoming non-zero -- and both are, under the fixture's DEFAULT authored values,
NON-MOVERS: `_golden_config()` authors no `deck_size`/`hand_size` today, so a shuffle over an empty
deck consumes the RNG zero times and an empty deck fills no hand. Neither claimed cause moves the hash
unless the fixture is given a coverage value for `deck_size` (and, dependently, `hand_size`) -- a
fixture-authoring step the pre-gate text never named. A THIRD, unnamed cause moves the hash
unconditionally: `PlayerState.to_snapshot()` adding the `Deck`/`Hand` keys at all changes the snapshot
SHAPE even at every-size-zero, before any RNG is consumed. This is the gate's most valuable finding --
it turns a two-cause prediction into three, one of them unconditional, and makes explicit that the dev
pass must AUTHOR a `deck_size` (and `hand_size`) fixture coverage value or the predicted movers do not
move, silently invalidating the golden pin.
(ii) `Array.shuffle()` was measured directly on this engine (4.6.3): it draws from the GLOBAL RNG and
leaves a per-instance `RandomNumberGenerator` completely untouched. Verified against the shipped guard,
`test_state_layer_has_no_nondeterministic_source` (`test/state/test_architecture_invariants.gd`,
INVARIANT D3(b)/A2): its banned-token regex covers `randf`/`randi`/`randf_range`/`randi_range`/
`randfn`/`randomize` and `Time`/`OS`/`Engine`. It does not mention `shuffle`, `pick_random`, or `seed`
at all -- a `deck.shuffle()` written under `src/state/` today would pass the entire suite while
silently destroying replay determinism. AC7 (the explicit Fisher-Yates requirement) and AC8 (the guard
extension) exist because of this measurement, not as a precaution against a hypothetical.
(iii) Deck composition -- WHICH cards, in what quantity, fill a fixture deck -- was unowned by any
story: 3-2 authored the cards and `max_copies` but explicitly deferred real deck selection past E3;
the pre-gate 3-3 text named `deck_size` as a size with no rule for what fills it. Ruled here (AC4):
walk `CardDatabase`'s sorted ids, taking up to each card's `max_copies`, until `deck_size` is reached
-- deterministic, content-agnostic, and explicitly a FIXTURE rule, not the deckbuilding seat.
(iv) `CardDatabase` (`src/systems/card_database.gd`) could not be enumerated in any order before this
gate: `get_card`/`has_card`/`card_count` give no way to walk the loaded set, and its own comments
already anticipated this gap ("any later ordered read sorts explicitly"). AC3 adds exactly one sorted
ordered accessor, discharging that anticipation.
(v) Deck exhaustion is UNREACHABLE in this story as scoped: only one draw event exists here (the
initial fill, at match start and on debug reset) and nothing else removes cards from the deck, so a
20-card deck with a 4-card hand can never run out. Discard, reshuffle-on-exhaustion, and the vulnerable
window all require a play-triggered draw that does not exist until 3-5. Ruling: all four (discard,
reshuffle, vulnerable window, and the draw-on-play delay that would trigger them) move to 3-5 together
with their trigger -- not split from it.

**All twelve rulings, in the order they land in the story's AC list / Dev Notes.**
1. **AC1 -- pure `Deck`/`Hand`.** `RefCounted`, not `Resource` or `Node`; owned by `PlayerState`; no
   `CardDatabase`/`CARDS_DIR`/`data/cards` name, no global-RNG call. Reason: state-layer purity is the
   load-bearing invariant this whole epic is built to protect (D3(b)/A2).
2. **AC2 -- the injection seam.** Modelled directly on `MatchState.inject_feature_flags()`:
   once at match start, content-only, explicitly no reload path. Reason: deck CONTENT is like flags,
   not like balance -- it does not need live-tuning, and a reload path would invite a mid-match content
   swap with no defined semantics.
3. **AC3 -- one sorted `CardDatabase` accessor.** Discharges (iv) above. Reason: an ordered read must
   be an explicit, sorted contract, never dictionary iteration order (the same rule 3-2's gate already
   set for `get_card`/`has_card`).
4. **AC4 -- deterministic sorted-id fixture composition.** Discharges (iii) above. Reason: recorded so
   a later reader does not mistake this for the deckbuilding seat, which does not exist yet.
5. **AC5 -- `StringName` ids, counts-only snapshot.** Reason: a `CardData` reference reaching the
   snapshot would fail same-seed determinism outright -- the canonical hash has no object branch and
   falls through to a per-allocation instance-id string, which differs between two independently
   constructed matches even with identical content and seed.
6. **AC6 -- `deck_size`/`hand_size` on `BalanceConfig`, `draw_replacement_delay_seconds` excluded.**
   Reason: the delay field's only consumer (draw-on-play) is 3-5's; authoring it here would ship a
   dead `BalanceConfig` field, a dead `BalanceTicks` field, an `E1_BALANCE_FIELDS` entry, and an audit
   exemption for a consumer one story away -- the same reasoning 3-1's gate used to strip these very
   fields out of 3-1 itself.
7. **AC7 -- explicit Fisher-Yates, one seat.** Discharges (ii) above. Reason: `Array.shuffle()` is
   banned by construction, not merely by a guard that would catch it (that guard is AC8); one seat
   (called from both match start and debug reset) keeps "the RNG is consumed only inside `advance()`"
   true by inspection.
8. **AC8 -- the extended architecture-invariants guard.** Reason: closes the gap found at (ii); built
   non-vacuous in both of the ways the existing card guard already is (`test_state_layer_never_names_
   card_data`) -- the banned token must be real somewhere in the repo, and the file scan must be proven
   to visit files -- and mutation-proven, not merely asserted to work.
9. **AC9 -- hand fills to `hand_size` at match start and debug reset.** Reason: this is the only draw
   event this story ships; stating it precisely (from the TOP of the shuffled deck, remaining count
   `deck_size - hand_size`) makes the boundary with 3-5's draw-on-play unambiguous.
10. **AC10 -- `Invariant.check` against an empty injected deck.** Reason: gives the previously-filed,
    ownerless export-remap risk (an empty `data/cards/` under export packaging degrading silently) a
    DETECTOR at the injection seam, without resolving the flag itself, which stays open.
11. **AC11 -- the negative guard.** Reason: states precisely, as a checkable claim, everything (v)
    above rules out of scope -- discard, reshuffle, exhaustion, vulnerable window, draw delay,
    `EventBus`, card effect, cast evaluator, any `src/ui/` file, any Input Map entry, any observation
    seam.
12. **AC12 -- exactly one re-baseline, three causes.** Discharges (i) above. Reason: the permanent
    golden-baseline rule (below) exists because this pattern -- a stale baseline sitting uncorrected in
    story text -- was found at 3-2's gate earlier this same day and now again here; this AC forces the
    dev pass to PROVE the causes by measurement rather than assert them.

**New obligation recorded for the intent-recorder story (3-0c).** Deck order is not itself hash-visible
(the snapshot carries counts only), but it IS replay-relevant -- the same seed reproduces the same
shuffle only if the pre-shuffle composition is also known. The injected deck composition must enter the
replay record alongside seed, intents, and reload events, or a replay silently depends on the live
contents of `data/cards/`, which change without a trace whenever a card is added or edited. `3-0c`'s
board slot (file deliberately not yet authored, per E3-P/R3) is the right owner; this is a new line item
for when that story is written, not a claim that it is written now.

**PERMANENT RULE, newly recorded.** A story's Golden Prediction baseline is re-derived from the
`GOLDEN` constant in `test_determinism.gd` at gate time, and never copied forward from whatever the
story text already says. The baseline `33817201...21da2` that this story's pre-gate text carried was
NOT wrong when written -- it was the actual current golden on 2026-07-31, when the revisit-gate
amendment (`10b96a1`) added this story's Golden Prediction section. It went stale afterward, across
three re-baselines the story text was never revisited against (the stamina-cost corrective pass, 3-0b
Pass 2, the 3-4 economy re-baseline), and nothing caught it until this gate. 3-2's gate, earlier this
same day, found the identical pattern independently. Two consecutive stories reaching their own gate
with a stale baseline is what makes this a RULE rather than a one-off correction: the baseline is
re-derived at gate time, every time, regardless of what the story currently claims.

**ONE MORE THING -- a correction, not a new ruling.** The architecture amendment queue's forcing point
has been called "the E3 close-out" in working conversation, but no entry anywhere in this log actually
commits to that framing -- every prior member (3-4/R4, R9; the sixth member at 3-2's gate; the seventh
recorded in this story's own Dev Notes) says only "the next flush," citing the `E2-CO/R1` pattern
without naming when that next flush occurs. Recorded HERE, explicitly: the forcing point IS the E3
close-out (the same shape as `E2-CO/R1`, commit `f80f90e`, which flushed the E2-era queue at the E2
close-out, not mid-epic) -- so that this claim exists in the log instead of being asserted in
conversation and nowhere else.

**Note for the remaining epic stories.** 3-5 and 3-6 still carry the same stale E3-revisit banner
residue found at 3-2's gate and this one -- their own gates should not spend a finding rediscovering
it; the fix is the same Scope-note replacement applied at 3-1, 3-2, 3-4, and here. 3-5 additionally
inherits four scope items from this gate (discard, reshuffle-on-exhaustion, the vulnerable window, and
the draw-on-play delay) that its own gate should expect to find undeclared in its current text, exactly
as 3-2's gate found the copies-cap ruling undeclared after 3-1 assigned it there.

**Promotion.** All fixes applied to the story file the same session (`docs(stories)` commit,
immediately preceding this one); story Status and board promoted `backlog -> ready-for-dev`; dev pass
next. Docs-only pass -- suite run once for the baseline measurement above, no code touched.

## Session 2026-08-03 -- 3-3 close-out

Recorded after the dev pass (Claude Opus 4.8) landed and the commit chain (Claude Sonnet 5) verified
and shipped it. Verification this session: HEAD started at `f56b337`, matching `origin/main`; the
dev-pass surface matched the expected file list exactly (10 modified, 4 untracked, 4 `.uid` files
generated by one headless editor scan and nothing else); no Godot process running; `project.godot`
byte-for-byte unchanged before and after the editor scan (`31033a50137c98dc...`); state harness 246
tests / 1186 assertions / 0 failed, all 16 integration files PASS individually (a sixteenth,
`test_deck_injection.gd`, added this story), zero `SCRIPT ERROR` / `Parse Error` / `INVARIANT
VIOLATED` lines.

**What shipped, against all twelve ACs.** Pure `Deck`/`Hand` `RefCounted` classes under `src/state/`
(AC1), owned by `PlayerState`; `MatchState.inject_deck()`, the deck-content injection seam on the
`inject_feature_flags` precedent -- once at match start, content only, no reload path (AC2);
`CardDatabase.sorted_ids()`, the one explicitly-sorted ordered accessor, `get_card`/`has_card`/
`card_count` unchanged (AC3); the runner's provisional fixture composition, walking sorted ids up to
each card's `max_copies` until `deck_size` is reached (AC4); `StringName`-only deck elements, counts
only in `PlayerState.to_snapshot()`, proven by a two-independently-constructed-matches hash-identity
test (AC5); `deck_size`/`hand_size` on `BalanceConfig`, in `E1_BALANCE_FIELDS`, audited `> 0` and
`hand_size <= deck_size`, `draw_replacement_delay_seconds` deliberately absent (AC6); the explicit
in-place Fisher-Yates against `MatchState`'s seeded RNG, one seat inside `advance()` step 6 serving
both the match-start and debug-reset occasions (AC7); the extended architecture-invariants guard
banning implicit-global-RNG collection APIs and the `CardDatabase` token under `src/state/`,
non-vacuous both ways and mutation-proven (AC8); the hand fill to `hand_size` from the top of the
shuffled deck on both occasions, with the exact `deck_size - hand_size` remaining-count contract
(AC9); the `Invariant.check` rejecting an empty injected deck at the seam (AC10); the broad negative
guard proving no discard, reshuffle, exhaustion, vulnerable window, draw delay, `EventBus` signal,
card effect, cast evaluator, `src/ui/` file, Input Map entry, or observation-seam change shipped
(AC11); and the determinism golden re-baselined exactly once, three separately named and measured
causes, both reverse toggles reproduced exactly (AC12). Suite: 218 tests / 1103 assertions + 15
integration -> **246 tests / 1186 assertions + 16 integration**. Golden: `98d0c7eb...` ->
`ad42841e...`.

**THE GOLDEN PREDICTION HELD.** Three causes were predicted at the readiness gate -- snapshot shape
(unconditional), `deck_size` via RNG consumption (conditional on the fixture authoring a coverage
value), and `hand_size` via the fill (conditional and dependent on the second) -- and three were
measured, in the same order, each isolated by its own edit and reproduced in both directions (M0-M4
plus the two-step reverse). The gate's own finding that both originally-named causes were MEASURED
NON-MOVERS under the fixture's then-current defaults (an unauthored `deck_size`/`hand_size` shuffles
and fills nothing) is what turned "author a fixture coverage value" from a silent omission into an
explicit dev-pass step -- confirmed at M2b, which held the whole mechanism live but the fixture still
unauthored, and measured bit-identical to cause 1 alone. Without that gate finding, the dev pass would
have shipped a fixture that never exercised the shuffle or the fill, and the golden would have pinned
a value that proved nothing about either.

**PERMANENT LESSON.** `Array[StringName].sort()` orders by INTERNAL POINTER on this engine (4.6.3),
not lexicographically -- deterministic within one process, not across runs or builds. The first
`sorted_ids()` implementation hit this directly and returned `frost_dart, ember_lash, bramble_snare,
...`; the fix round-trips every element through `String` before sorting and back to `StringName`
after. A repo-wide `.sort()` audit found exactly one affected call site (`card_database.gd`) and no
others. **A NAMED LATENT RISK, no owner assigned:** `CanonicalHash` sorts dictionary keys for its
canonical form, and today that is safe only because every snapshot key reaching it is a `String`
literal (`"deck_size"`, `"hand_size"`, etc.) -- `String` sorts lexicographically and correctly. The
moment any snapshot ever carries a `StringName` as a dictionary KEY (not a value -- deck/hand
elements are values, inside an array, never keys), the same pointer-ordering non-determinism this
story found and fixed in `sorted_ids()` would silently reach the determinism hash itself, with no
guard anywhere in the suite today that would catch it. Recorded here so the next story that
considers a `StringName`-keyed snapshot dictionary finds this before shipping it, not after.

**Mutation summary, honest about both sideways rows.** Thirteen rows run (R1-R13); eleven measured
cleanly against an out-of-repo SHA256-verified backup. R3 was SIDEWAYS and abandoned before
measurement (a `get_node("/root/CardDatabase")` rewrite that kept the banned literal token, noticed
before running, redone as R4). R12 was SIDEWAYS in a different way: `hand.gd` is a new untracked file
with no git baseline, so the standard SHA256-backup restore protocol does not apply to it at all; the
plant (`discard_all()`) was additive and was reverted by the exact inverse edit, verified by a full
file read against the content authored earlier in the pass, with no SHA256 comparison possible and
none claimed. A later repo-wide sweep for `mutation_probe` / `shufffle` / `discard_all` returned zero
hits, which is the closest this row gets to an independent confirmation. **What stayed unproven by
mutation, recorded rather than silently accepted:** the three AC11 tests (cast evaluator / `EventBus`
/ Input Map), the balance authoring audit, the `E1_BALANCE_FIELDS` additions, the
copy-not-backing-array checks, the permutation and multiset tests (R8's identity permutation does not
fail them by construction), the empty/single-pile test, and -- the one BEHAVIOURAL claim still
unproven -- the sorted-order PREFIX property: R13 flipped `composition` (unknown-id and the
any-at-cap non-vacuity both fired) but left the prefix property untouched, because the stub's unknown
id hits the `card == null` path before the prefix walk can observe an out-of-order take.

**Three operator rulings, recorded by decision.**
1. `Deck.draw_top()` takes the LAST element of the backing array -- "top is the back" is confirmed as
   the convention, unobservable within this story and inherited by 3-5 as the fixed meaning of "top."
2. Both players are dealt from the SAME injected composition (one seam, one fixture composition) --
   accepted as a named consequence of the current seam shape, not an oversight to fix here. Asymmetric
   decks arrive with real deckbuilding (E4/E5), which restructures the injection seam anyway.
3. The `Array[StringName].sort()` pointer-ordering lesson above, and the `CanonicalHash`
   dictionary-key latent risk it surfaces, are recorded in this log by decision, not left as an
   unwritten finding in a session transcript.

**Architecture amendment queue gains a SEVENTH member**, queued at the E3 close-out per the standing
flush-point convention (E2-CO/R1), NOT edited into the architecture doc now: `Deck` and `Hand` need
Directory Tree lines and places in the state-layer inventories (the same gap `CardEffect` already has
as the sixth member); the doc states the banned nondeterminism surface as a concept rather than naming
the implicit-global-RNG collection APIs this story's guard actually bans; and, conditionally, if a
vulnerable-window signal lands with 3-5, the `EventBus` header and the seam registry both need
reconciling against the bus's enumerated signal set.

**What 3-5 inherits, explicitly.** Discard; refill-on-play (the consumer for
`draw_replacement_delay_seconds`, which this story deliberately left unauthored); deck exhaustion with
reshuffle; and the vulnerable window together with its ownerless `EventBus` event (channel ruled at
the E3 revisit gate, E3-RG/R3, on the `round_started`/`round_ended` precedent) -- each of these four
items arrives WITH the trigger that makes it reachable, per this story's own scope-narrowing ruling,
since none of them is reachable with only an initial fill drawing from the pile. Additionally, the
obligation recorded at this story's readiness gate for the intent-recorder story (3-0c): the injected
deck composition must enter the replay record alongside seed, intents, and reload events, or a replay
silently depends on the live contents of `data/cards/`.

**Live Smoke NOT REQUIRED**, honest reason unchanged from the gate: this story ships no player-facing
surface (no HUD, no input, no visible actor behaviour), and a shuffle's determinism is not observable
by a human at all. The runner-side injection seam's presence in the live boot path is proven headless
by `test_deck_injection.gd` (`test/integration/`), which reaches the live `MatchState` through the
booted scene tree and asserts the seam ran, the counts match the authored config, and the composition
honours `max_copies` on a sorted-order prefix. The smoke acceptance criterion (last spent at 3-4
against two live killable human slots) stays SPENT and is re-invoked by the card-play story, 3-5, not
by this one.

**Board: done. Next story in the locked order: 3-5, currently `backlog` pending its own readiness
gate (E3 revisit-gate outcome: VERDICT AMENDED, HOLD until that gate runs; 3-5 additionally inherits
the four scope items named above, undeclared in its current text).**

**Close-out.** Commit chain: `story 3-3: deck, hand, and seeded shuffle` (`d9fedc7`, code, tests,
data), `docs(3-3): dev pass record` (`b49d414`, this story's Dev Pass Record, Dev Notes additions, Dev
Agent Record, and Change Log), `board: promote 3-3-deck-hand-draw-reshuffle to done` (`c2e2de7`), and
this entry. No push -- the operator reviews the log and pushes.

## Session 2026-08-04 -- Story 3-5 readiness gate

Readiness gate on `3-5-card-mode-select-basic-resolution.md` (docs-only, report-only, run against
`8a7f7e2`) returned **NOT READY** on first read. This is the same first-pass verdict every Set B
story's gate has returned -- seventeen PRIOR Set B readiness-gate sessions (seven E1, six E2, plus
3-1 and 3-4 on 2026-08-02, plus 3-2 and 3-3 on 2026-08-03), all NOT READY on first read -- 3-3
itself recorded "makes it 17/17" at its own gate (verified by content against this log, matching
exactly; no discrepancy to report), and this session, run against 3-3's now-shipped code, makes it
**18/18** -- fixed and promoted the same session, no exception in either direction.

**Baseline measured green before the first edit** (docs-only pass; no code touched): state harness 246
tests / 1186 assertions / 0 failed; 16 integration files, each individually PASS; golden unmoved at
`ad42841edcd549660de44a9cf1b6c916b2a090a9c973ec44ec8ecd1960434f08`; `project.godot` SHA256 unchanged
(`31033a50137c98dc...`, matching the 3-3 gate's own measurement -- this pass adds no autoload and
touches no engine config); engine 4.6.3.

**The split, ruled first because everything below is scoped by it.** Story 3-5 as pre-gate-written
carried sixteen workstreams: two new balance fields, a new enum, a new evaluator, a new injection
seam, a new `EventBus` signal, and a multi-cause golden re-baseline. It splits at the seam between THE
TRIGGER (mode-select input, cast gating, Mode ① resolution) and WHAT THE TRIGGER MAKES REACHABLE (the
draw-replacement delay, deck exhaustion, the reshuffle, and the vulnerable window). The 3-3 gate ruled
that those four inherited items "move to 3-5 together with their trigger -- not split from it"
(Session 2026-08-03 -- Story 3-3 readiness gate, finding (v)). That ruling is HONOURED here, not
reopened: its purpose was that no mechanism ships before its trigger exists. `3-5a` delivers the
trigger; `3-5b` lands after it exists, as its own story rather than a `3-5a` task. Measured, not
assumed: with the shipped fixture (`deck_size` 20, `hand_size` 4), deck exhaustion needs SIXTEEN
successful casts inside one round before the pile runs dry -- reachable in principle (a fixed-`delta`
headless test can drive sixteen casts trivially) and unreachable as a realistic live-smoke event, which
is why `3-5b`'s Live Smoke is NOT REQUIRED with that measurement as the stated reason, distinct from
`3-3`'s NOT-REQUIRED reason (no player-facing surface at all).

**Ordering change.** The E3-RG `ORDER` ruling (Session 2026-07-31, E3 revisit gate (outcome)) fixed
3-1, 3-4, 3-2, 3-3, 3-5, `3-0c` (`IntentRecorder`), 3-6 last. With the split, that becomes **3-5a ->
3-5b -> 3-0c -> 3-6**. Reason: 3-6 renders the reshuffle vulnerable window in the HUD (E3.S6 item 3,
"clearly flagged in both viewports"), so it needs 3-5b -- which is what actually ships the window and
its `EventBus` event -- to exist first. `epics.md` and `stories-manual-e3.md` updated alongside (split
commit, `257e4d3`).

**Nine premise corrections, with content, resolved before the blocking findings.**

(i) The pre-gate story text's Tasks/Subtasks list said card actions are ingested at `advance()` step 1
    ("Ingest card actions step 1; dispatch via `resolve()` step 6"), four lines below an AC that
    already said the opposite ("Card actions are read directly at step 6 ... NOT ingested at step
    1"). The story instructed the dev pass to do what its own AC forbade. Corrected: the task line is
    deleted outright, not reworded -- AC2 is already the authoritative statement.

(ii) The stale pre-revisit-gate banner ("E3 REVISIT GATE applies ... provisional ... must be reviewed
     before implementation") was still at the top of the file, false since 2026-07-31: the epic
     revisit gate has RUN, and this story's own gate ran the same day as this entry. This is the fifth
     consecutive story carrying this residue (3-1, 3-2, 3-4, 3-3, now 3-5a), corrected to the same
     Scope-note shape used at all four. Note for `3-5b`: it is a brand-new file, authored after this
     gate, so it never carried the stale banner to begin with -- its own Scope note states its HOLD
     directly.

(iii) **3-5/R1 -- THE DECK-DRAW PREMISE IS FALSE, and it falsifies two things at once.** The pre-gate
     Golden Prediction claimed "a draw consumes the seeded gameplay RNG" as its second named cause.
     Measured against the shipped code: `Deck.draw_top()` (`src/state/deck.gd:54`) takes the LAST
     element of the backing array and removes it -- no `rng` argument, no call into `MatchState`'s
     `_rng`, nothing consumed. The ONLY RNG consumer anywhere in `Deck` is the Fisher-Yates shuffle
     (3-3, AC7), which runs once at match start / debug reset, not on a replacement draw. This
     falsifies the story's own second golden cause outright. It ALSO falsifies the general shape of
     claim the revisit gate's own R11 made about this project's determinism history (Session
     2026-07-31, E3-RG/R11: "the deck story (3-3) draws from the seeded RNG inside `advance()` ... AND
     populates `PlayerState.hand` ... 3-3 therefore moves the golden TWICE OVER, from RNG consumption
     and from the hand-size field") -- R11's claim is about 3-3's OWN initial-fill shuffle, which DOES
     consume RNG and was correctly measured as a golden mover at the 3-3 gate; but the pre-gate 3-5
     text extrapolated that same "a draw consumes RNG" shape onto a DIFFERENT draw (the replacement
     draw on cast) that shares no code path with the shuffle. No decision-log entry anywhere is found,
     by content search, making this specific extrapolated claim about the replacement draw under a
     citable label prior to this one -- the claim originates in the 3-5 story text itself, authored at
     the revisit gate per E3-RG/R11's blanket "every amended story gains a Golden Prediction section"
     mandate, and propagated unverified until measured here. Recorded as the general precedent this
     establishes: **the E3 revisit gate read six stories against the code as it stood on 2026-07-31,
     and per-story gates running after intervening stories can and now do overturn its findings -- a
     revisit-gate finding is evidence, not a fact, once code has moved under it.** (3-3 landed between
     the revisit gate and this one; this is the first time that movement has actually overturned
     something.)

(iv) The Golden Prediction's `rng_state` citation, `match_state.gd:242`, has rotted -- measured,
     `rng_state` is captured at `match_state.gd:292` today (three re-baselines and one story's worth of
     line churn since the revisit gate wrote that citation). Corrected to cite the symbol, not the
     line, per this project's standing citation discipline.

(v) `stories-manual-e3.md` and `docs/game-architecture.md`'s Novel Pattern 6 both still name the guard
    helper `check_invariant`, which names no real symbol anywhere in this repo (`grep -rn
    "check_invariant" src/` returns zero hits). The real static guard is `Invariant.check`
    (`src/systems/invariant.gd`). The 3-5 story's OWN AC2 was already corrected to the right name at
    the revisit gate (2026-07-31) -- the 3-2 gate (2026-08-03) found the identical wrong name in ITS
    OWN old AC4 and dropped it, citing this story ("the sibling 3-5 story had it corrected ... this story
    carried the wrong name through untouched because it was confirmed, not amended, the clearest
    evidence the confirm proved shallow" -- Session 2026-08-03, Story 3-2 readiness gate). This gate
    finds the SAME wrong name a third place: the architecture document itself, never corrected. Folded
    into the ruling below on the eighth architecture-amendment-queue member rather than logged twice.

(vi) Novel Pattern 6's `CardData` code sketch (`docs/game-architecture.md:812-818`) shows four
     `@export` fields; the shipped `CardData` (`src/state/resources/card_data.gd`) has SIX -- `id` and
     `max_copies` both load-bearing and both missing from the sketch. This is not a new finding: it was
     already recorded as the architecture-amendment-queue's SIXTH member at the 3-2 gate. Restated here
     only because it is one of three things wrong with the SAME doc section this gate is auditing, and
     folding it into a single eighth-member ruling (below) is more honest than pretending it is unowned
     by this gate.

(vii) Novel Pattern 6 (`docs/game-architecture.md:820-828`) presents a `ModeKind` enum and a free
      `resolve(player, card, mode)` function as though they already exist, with no owning class named.
      Verified by content: `grep -rn "ModeKind\|func resolve(" src/` returns zero hits. Neither exists
      anywhere in `src/` today. Ruled (AC9): the enum lands on `Enums` beside `CardColor`
      (`src/state/enums.gd`); the dispatch is a PRIVATE `MatchState` method called at step 6, matching
      the `_generate_mana`/`_resolve_actions`/`_deal_pending_decks` shape every other `advance()`
      mutation already uses -- not a free function, and not a new class, because the mutation must stay
      inside `advance()`'s ordered dispatch (D2).

(viii) The premise that one story could deliver mode-select input, cast gating, a new evaluator, a new
       injection seam, Basic-mode resolution, discard, the draw delay, deck exhaustion, reshuffle, AND
       the vulnerable window together was never coherent once measured against the dependency shape:
       WHAT THE TRIGGER MAKES REACHABLE cannot be built, let alone tested, before THE TRIGGER exists.
       This is the premise the split (above) corrects structurally rather than by editing prose.

(ix) The four items the 3-3 gate ruled move to "3-5" (discard, reshuffle-on-exhaustion, the vulnerable
     window, and the draw-on-play delay) named an undivided "3-5" as their destination, written before
     3-5 itself split. Corrected: their actual destination is `3-5b` specifically, not `3-5a` -- stated
     explicitly in `3-5b`'s own Scope note so a later reader does not go looking for them in the wrong
     file.

**Nine blocking findings, each resolved by the AC that closes it (3-5a).**

1. **No discard container existed anywhere**, and `Hand` (today: add/clear/size/is_empty/`to_array`,
   `to_array` returning a duplicate) exposed no removal path at all -- a card could enter a hand but
   never leave one through the type meant to hold it. Resolved by AC6: a discard pile ships as a third
   pure container on `PlayerState` alongside `Deck` and `Hand`, with a `Hand` removal method added; the
   snapshot gains exactly one new key, the discard COUNT, never ids.
2. **No seam existed for card costs to reach the state layer at all** -- `CardCastCondition.mana_cost`
   is per-card content (3-2), and nothing injects card content into `src/state/` today except the
   `inject_deck`/`inject_feature_flags` precedents, neither of which carries cost data. Resolved by
   AC4: a new one-shot injection seam on `MatchState`, on the deck-injection precedent -- once at match
   start, content only, no reload path, ONE match-wide map (both players use the same injected
   composition, per 3-3's locked ruling), validated at injection time with `Invariant.check` so an
   unknown id is unreachable at cast time rather than a new crash guard, and excluded from
   `to_snapshot()`.
3. **No evaluator existed to gate a cast, and its home was ambiguous** -- folding cost-evaluation logic
   into `EconomyEvaluator` would contradict that file's own header, which declares it "THE one place
   `ResourceGenerationRule`s are read," a generation-side identity. Resolved by AC3: a new pure static
   sibling, `src/state/economy/cast_evaluator.gd`, that COMPUTES (returns an empty-or-reason
   `StringName`) and does not APPLY -- the pool applies the spend inside `advance()`'s ordered dispatch,
   the same compute/apply split `EconomyEvaluator` already uses on the generation side.
4. **`Hand` had no removal method**, discharged together with finding 1 above (AC6) -- listed
   separately because it blocks even a card LEAVING a hand, independent of where it goes.
5. **No rejection path was defined for an unaffordable cast.** Resolved by AC7: reuse the SHIPPED
   `action_rejected` signal and the existing per-slot observation seam that already carries the
   insufficient-stamina rejections (`connect_hero_action_rejected`), with a card action name and a
   reason token -- no new signal, no new seam, seam count unchanged (still the seven frozen at 2-6/R7).
6. **No contract existed for a cast attempted by a DEAD player or on a frozen round-over tick.**
   Resolved by AC8: DEAD cannot cast; a cast on a frozen tick drops silently with no rejection signal,
   consistent with every other intent during the freeze (step 1b returns before step 2). Both pinned by
   tests. The second half carries a forward NOTE for `3-5b`: nothing in THIS story spans ticks, so
   there is nothing in flight to abort here, but `3-5b`'s delayed replacement draw must tick out and
   deliver nothing rather than being cancelled on a death -- an early-stop path would reopen the locked
   1-9 invariant obligation that windows on a dead hero run to expiry and simply deliver nothing.
7. **The mode enum had no defined home**, and Novel Pattern 6's sketch (finding (vii) above) is not a
   real location. Resolved by AC9: `Enums` (`src/state/enums.gd`), beside `CardColor`; dispatch as a
   private `MatchState` function at step 6.
8. **A selection indicator was unscoped**, risking overlap with 3-6's HUD work (card contents, sizing,
   layout). Resolved by AC10: a presentation-local indicator (armed slot, armed mode) added to the
   EXISTING placeholder card row -- no new seam, no read of `PlayerState.hand`, no resize, no card
   identity, no cost display, fenced explicitly against 3-6.
9. **A reserved pitch/stage action had no ruling on whether it ships**, and Input Map hygiene for the
   new card actions had no stated procedure. Resolved by AC11 (named actions, textual edit with the
   editor closed, `project.godot` SHA256 before/after, diff reviewed -- the 2-1/R2 procedure, per
   E3-RG/R7's scoping of the Input Map ownership ruling to allow this) and AC12 (the reserved
   pitch/stage action is DELETED outright, on the retired-`pose_id` precedent (3-0b, DEBT E member 4)
   -- a reserved action with no consumer does not ship, since the pitch zone is an E6 flag and is off).

**The eighth architecture-amendment-queue member**, combining findings (v), (vi) and (vii) above into
one entry rather than three: the Novel Pattern 6 section of `docs/game-architecture.md` is written as
if it were shipped code and is wrong three ways -- its card-data sketch omits the `id` and
`max_copies` fields, both load-bearing (already the sixth member, restated here because it lives in
the same section); it presents a mode enum and a `resolve()` function as existing with no owning class
named, neither of which exists anywhere in `src/`; and it names a guard helper, `check_invariant`,
that names no real symbol -- a defect already corrected in the story text (at the revisit gate) but
NOT in the architecture document. The seventh member's conditional clause (Session 2026-08-03, Story
3-3 readiness gate close-out: "if a vulnerable-window signal lands with 3-5, the `EventBus` header and
the seam registry both need reconciling") now attaches to `3-5b`, not `3-5a`, since the vulnerable
window is `3-5b`'s scope. Flush point unchanged: the E3 close-out (Session 2026-08-03, Story 3-3
readiness gate: "the forcing point IS the E3 close-out").

**Two previously unlisted inherited obligations**, named here because nowhere else names them: (1) 3-3
fixed the meaning of "top" as the back of the pile (`Deck.draw_top()` takes the LAST element) and
handed that meaning to this story -- a replacement draw reads the same "top." (2) Both players receive
the SAME injected composition through 3-3's one seam, which constrains the new cost-injection seam
(AC4) to a single match-wide map, not a per-player one, for the same reason.

**Operator's seals, recorded by decision.**
1. The split (3-5a / 3-5b, trigger vs. reachable) is SEALED. Not reopened; see the split ruling above.
2. The selection indicator (AC10) is SEALED to presentation-local, no hand read, no resize, fenced
   against 3-6.
3. The melee tuning retune is SEALED to land AFTER this story's live smoke, not before, as its own
   golden-neutral balance commit -- the criterion (a round should finance 2-4 loop cycles) is
   unjudgeable until cycles per round can actually be counted, which is exactly why its forcing point
   moved here.
4. That a DEAD player cannot cast (AC8, first half) is SEALED.

**The smoke cannot answer the mode-select-under-pressure question in E3, and that is recorded so a
PASS is never later misread.** Exactly one mode is reachable in E3; the rest are guarded stubs. The
real forcing point for whether mode-select is viable under real-time pressure at all moves to E5, when
the additional modes land -- this story's Live Smoke proves only that arming and committing a single
card mid-exchange does not read as stopping to use a menu, not that mode-selection itself scales.

**Epic-wide staleness, RECORDED not fixed -- out of scope for a 3-5 fix pass.** Two items, both
deferred with an explicit forcing point rather than corrected here:
1. `stories-manual-e3.md` still carries a file-level front-matter `status: provisional — revisit
   after the first E1/E2 playtest` (line 6), and every section still standing (E3.S1, E3.S2, E3.S3,
   E3.S4, E3.S6 -- five of the file's seven current sections) carries its own unamended `Revisit note`
   reading "Provisional — confirm or amend against `docs/playtest-log.md` before implementing," even
   though the revisit gate RAN on 2026-07-31 and four of the six original stories (3-1, 3-2, 3-3, 3-4)
   have since passed their own readiness gates -- only E3.S5a (this gate) and the new E3.S5b carry
   current Revisit notes.
2. `stories-manual-e3.md` E3.S2 item 4 (not E3.S3 -- verified by content; the referring correction
   text located it at E3.S3, which this entry does not repeat uncorrected) separately instructs
   authoring a card-damage guard as "Add a `check_invariant` or a test that fails if a per-card damage
   field ever appears" -- the same non-existent symbol corrected in E3.S5a above, standing unfixed in
   a section this pass does not own.

Both are epic-wide edits, not scoped to any single story's gate. Forcing point: the E3 close-out docs
flush, the same flush point already fixed for the architecture-amendment queue (Session 2026-08-03,
Story 3-3 readiness gate: "the forcing point IS the E3 close-out").

**The Change Log author-column question stays parked, second file now exhibiting it.** `3-5a`'s
Change Log reads `Claude Opus 4.8` for v0.2 (the revisit-gate amendment, authored before this fix
pass existed) and `Claude Sonnet 5` for v0.3 and v0.4 (the split and this gate's fix pass, both this
session). This is the SECOND story file carrying a mixed author column, after 3-2 (Session
2026-08-03, Story 3-2 readiness gate close-out), where whether that column records a repo-wide
constant or the literal authoring agent was parked for the E3 close-out flush. It stays parked here
too; the commit chain is not rebuilt to make the column uniform.

**Promotion.** All fixes applied to `3-5a` the same session (`docs(stories)` commit `b3a3481`,
immediately preceding this one); `3-5a`'s Status and board promoted `backlog -> ready-for-dev`. `3-5b`
stays `backlog`, HOLD, pending its own readiness gate -- not promoted, not gated, this session. Docs-only
pass -- suite run once for the baseline measurement above, no code touched.

---

## Session 2026-08-04 -- 3-5a close-out

Continues this story's label series (3-5/R1 above) with rulings 3-5/R2..R9, recorded after the dev
pass (Claude Opus 4.8) landed and the commit chain (Claude Sonnet 5) verified and shipped it.
Verification this session: `HEAD` started at `77d7f06`, matching `origin/main`, 0/0 divergence; a live
Godot process from the operator's own smoke build was found running at the start of the chain, flagged,
and confirmed closed by the operator before the editor scan ran; the working-tree surface matched the
expected 14-modified/6-untracked set exactly; the encoding repair on `test/state/test_determinism.gd`
held (0 CR bytes, 0 C3/C2 mojibake lead bytes, no BOM, byte-verified); one headless editor scan
generated SIX new `.uid` files, not the two originally anticipated -- two for the new `src/` scripts
and four for the new `test/` files, matching this repo's universal 1:1 `.gd` -> `.uid` convention
(verified: 41 tracked `test/**/*.gd` files, 41 tracked `test/**/*.uid` siblings) -- all six committed
alongside their scripts (commit 1), on the operator's decision. State harness 287 tests / 1297
assertions / 0 failed, all 17 integration files PASS individually (`test_card_selection_indicator.gd`
added), zero `SCRIPT ERROR` / `Parse Error` / `INVARIANT VIOLATED` lines, matching the dev pass's own
recorded numbers exactly -- nothing in the dev pass was re-derived or re-measured, only verified.

**What shipped, against all twelve ACs.** The controller-only mode-select scheme (AC1); card actions
read at step 6, never ingested at step 1 (AC2); `src/state/economy/cast_evaluator.gd` as a pure static
sibling of `EconomyEvaluator` (AC3); the one-shot match-wide card-cost injection seam on `MatchState`
(AC4); one-tick Basic-mode resolution with an instant refill, the resolved card's id emitted on
`card_cast_resolved` (AC5); the discard pile as a third pure container on `PlayerState`, `Hand` gains
`remove_at` (AC6); unaffordable-cast rejection through the shipped `action_rejected` signal and its
existing per-slot seam (AC7); the DEAD/frozen-tick cast contract (AC8); the mode enum on `Enums`
beside `CardColor`, dispatch as a private `MatchState` method at step 6 (AC9); a presentation-local
selection indicator (AC10); Input Map hygiene, both guards (AC11); the reserved pitch/stage action
confirmed a no-op deletion (AC12). Suite: 246 tests / 1186 assertions + 16 integration -> **287 tests
/ 1297 assertions + 17 integration**.

**3-5/R2 -- Golden re-baseline (the SIXTH), three causes plus two isolation results measured beyond
what was required.** `ad42841e...` -> `c4b9f897...`: cause 1 (`discard_size` key, all-zero values,
unconditional) moved the hash alone (M1); cause 2 (a landed cast's `deck_size`/`discard_size` change)
and cause 3 (mana spent) were separated by pricing the fixture cast at 0.0 first (M3, cause 2 alone)
then at 7.0 (M4, cause 3 added). Two results were measured beyond the minimum needed to ship: **M0**
confirms the bare `DiscardPile` addition with nothing snapshotted is UNMOVED -- the container's mere
existence cannot move the hash without a snapshot key reading it. **M2** confirms cast-cost content
injected but no cast committed reproduces M1's hash BIT-IDENTICALLY (`a079c111` both times) -- the
injection machinery itself cannot move the hash without a cast actually landing, isolating the SEAT
from its CONTENT the same way 3-4/the mana-flywheel isolated a `BalanceTicks` seat from its coverage
value. Both reverse toggles (R1, R2) reproduced their forward measurements exactly.

**3-5/R3 -- `rng_state` predicted and measured a non-mover, kept as a permanent test.** The Golden
Prediction named `rng_state` as a non-mover because `Deck.draw_top()` consumes no RNG (only the 3-3
shuffle does); measured, it did not move. Kept as `test_the_recorded_cast_consumes_no_rng` rather than
a comment, specifically because a PRIOR version of this same Golden Prediction (corrected at this
story's own readiness gate, 3-5/R1) claimed the opposite -- a claim that stood uncontradicted until
measured. A comment can rot silently the way that claim did; a test cannot.

**3-5/R4 -- SUPERSESSION of three 3-3 `AC 11` fences, formal ruling.** Three test fences authored by
the CLOSED story 3-3 named "story 3-5" as their owner and were NARROWED, not deleted, by this story's
dev pass: `discard` released from the banned-token scan, `reshuffle|exhaust|vulnerab|draw_replacement`
STAY banned -- the fence is now `3-5b`'s, since an instant refill still cannot exhaust a pile.
`CardCastCondition` released, `CardEffect` STAYS banned -- 3-5a resolves a cast and emits an id, never
an effect (AC5's accepted deviation, below), so the fence still has a real subject. Input Map `card`
released, `pitch|stage|play|draw|discard|hand` STAY banned. A POSITIVE Input Map guard was added
alongside the negative one, because the negative guard alone cannot distinguish "correctly added" from
"never added." All four narrowed/added forms are mutation-proven (the story's own mutation table, rows
9, 10, 13b, 14). The 3-3 story file itself is NOT edited -- this ruling is the formal record of the
supersession, per the standing rule that a closed story's file is not reopened to reflect a later
story narrowing its fences.

**3-5/R5 -- the frozen-tick cast contract is SILENCE, ruled and pinned in both halves.** A cast
committed on a round-over frozen tick is dropped silently: no state change, no signal, not even an
`action_rejected`. Structural reason: step 1b returns before step 2, so on a frozen tick NO intent is
ingested at all, and attack/block/roll/move are already dropped exactly this way; emitting for casts
alone would require reading card intent inside step 1b, which AC2 forbids. `action_rejected` remains
the rejection path for LIVE-tick refusals only (insufficient mana, empty slot). Pinned by
`test_cast_on_a_frozen_tick_is_dropped_silently` in both directions (nothing changes AND nothing is
emitted). **This closes the readiness-gate finding (blocking finding 6, Session 2026-08-04 -- Story
3-5 readiness gate) that no contract existed for a cast on a frozen tick** -- a later gate should read
this as a settled ruling, not rediscover it as a defect.

**3-5/R6 -- DEAD <=> frozen is a total coupling, measured.** `_end_round` sets `_round_over = true`
and the loser's `DEAD` together, and it is the ONLY entry into `DEAD`; the debug reset clears both. A
DEAD player is therefore always also frozen, and the step-6 DEAD-cannot-cast guard is UNREACHABLE in
natural play. It ships anyway as defense in depth, in the same family as the DEAD branches already
guarding steps 3, 4, and 5, each unreachable for the identical reason and guarded anyway. Pinned by
the repo's established forced-DEAD test idiom.

**3-5/R7 -- `project.godot` is no longer pinned at its old SHA.** The constant carried forward by
prior close-outs (`31033a50137c98dc...`) is superseded by `8879DE490EDDA78051595F189FB9BB6F2E75384FEBA
FF142C8958EC107970004`, measured additions-only both before and after this chain's own editor scan (60
insertions, 0 deletions, twelve new Input Map actions) -- no setting reorder, no deleted engine-default
pin, no `config/features` move, no uid churn.

**3-5/R8 -- OPEN DESIGN QUESTION, owner `3-5b`: does dying abort what a dying player started?**
The operator's stated intent is that anything a player started before dying is aborted. Honouring it
needs an EARLY-STOP path, and the standing invariant runs the other way (`match_state.gd`: an in-flight
window "is NOT stopped or shortened here ... it simply resolves to nothing," 1-9/R3 intact). **Vacuous
in 3-5a** -- nothing in this story spans ticks, so there is nothing in flight to abort. The first
card-side mechanism that actually spans ticks is `3-5b`'s delayed replacement draw, which is where
this question is forced and must be ruled EXPLICITLY. Recorded as an open question, not a decided
behaviour, and not a defect in 3-5a.

**3-5/R9 -- the architecture-amendment queue's EIGHTH member now has a concrete target.** Novel
Pattern 6 (`docs/game-architecture.md`) is written as shipped code and is wrong three ways: its
`CardData` sketch omits `id` and `max_copies` (already the sixth member); it shows `ModeKind` and a
free `resolve()` function as existing with no owning class named; and it names a guard helper,
`check_invariant`, that names no real symbol. `ModeKind` now DOES exist, on `Enums`, with `MatchState`
owning the step-6 dispatch (AC9) -- the amendment has a concrete target to correct against. Forcing
point stays the E3 close-out docs flush, unchanged.

**Mutation table, all sixteen rows confirmed** (recorded verbatim in the story's own Dev Pass Record).
Every target restored from an out-of-repo SHA256-verified copy, `git checkout --` never used. Two
mutation attempts were themselves defective and were redone rather than banked: MUT-12's first form was
invalid GDScript (hung Godot, inconclusive, killed and restored), MUT-13's first token was uppercase
against a case-sensitive regex (a false pass, redone as 13b). NOT claimed mutation-proven: both
`inject_card_costs` `Invariant.check` calls in the FIRING sense (`Invariant.check` routes through
`assert()`, which aborts the harness before a failure can be observed), and `CastEvaluator`'s
null-condition branch -- their PRESENCE is guarded by source scan, and that scan IS proven (row 15).

**Smoke Record.** Live smoke PASS, R-D6 re-invoked and SPENT. Confirmed in play: the selection
indicator behaves as tested; a confirm with no armed slot does nothing; while the opponent is dead a
card can still be ARMED but not cast; fps steady throughout. One WAIVER: deck shrinkage is not
smoke-visible (no HUD shows a deck count, that is `3-6`), resting instead on the headless proof
(deck-size assertions plus golden cause 2) -- same class as the earlier DEAD-bar-freeze waiver. Two
findings: **S5**, no feedback on a cast at all (no sound, nothing on screen, for either a successful
cast or a rejection) -- not a defect, `card_cast_resolved` deliberately has no listener and
`action_rejected` reaches only the debug inspector; named the leading candidate to inherit the seam
obligation, forcing point `3-6` for the visual half, audio separate. **S6**, a cast succeeds during a
roll and while blocking with no resistance -- no AC required an action-state gate and none was
invented; named open, forcing point E5, where a charge-up mode that spans time makes "may you cast
mid-roll" load-bearing. Recorded so a later reader does not file it as a bug: being able to ARM while
the round is frozen is intended, the indicator is pushed outside the ticking gate, exactly as camera
follow is during a debug pause.

**Board: done.** Next story in the locked order: `3-5b`, currently `backlog`/HOLD pending its own
readiness gate (this story's own gate: `3-5a -> 3-5b -> 3-0c -> 3-6`).

**Close-out.** Commit chain: `story 3-5a: card mode select + basic card resolution` (`f4cc806`, code,
tests, `project.godot`, six `.uid` siblings), `docs(3-5a): dev pass record + smoke record` (`d136e26`,
this story's Dev Pass Record, the AC5/Golden-Prediction/Agent-Model-Used corrections, the supersession
item, the Smoke Record, and the Change Log row), `board: promote 3-5a to done` (`3fc584c`), and this
entry. No push -- the operator reviews the log and pushes.

---

## Session 2026-08-04 -- Story 3-5b readiness gate

Readiness gate on `3-5b-draw-delay-exhaustion-reshuffle.md` (docs-only, report-only, run against
`2d944b6`) returned **NOT READY** on first read, with eight blocking findings. That makes
**19 of 19**: nineteen logged readiness-gate sessions in this log (seven E1, six E2, then 3-1, 3-4,
3-2, 3-3, 3-5a and now 3-5b), all nineteen NOT READY on first reading, all nineteen fixed and
promoted in the same session -- no exception in either direction. Eighteen rulings, `3-5b/R1`..
`3-5b/R18`, applied to the story file and the board the same session. `3-5b/R17` was ruled after the
report was delivered, closing the one gap the report named and declined to close on its own
authority; `3-5b/R18` was ruled after that, correcting R17. Both are folded into this entry rather
than appended as later sessions, because both belong to this gate.

**Baseline measured green before the first edit** (docs-only pass; no code touched): state harness
287 tests / 1297 assertions / 0 failed; 17 integration files, each individually PASS; golden unmoved
at `c4b9f897138a2b36dbce11f939b2892379919909c17df1696cde24a75c070e2e`; `project.godot` SHA256
`8879DE490EDDA78051595F189FB9BB6F2E75384FEBAFF142C8958EC107970004`, matching `3-5/R7`'s constant and
unchanged by this pass; `HEAD` `2d944b6`, clean tree, `0 0` divergence against `origin/main`, no
Godot process running at start or finish.

**Two premise corrections to the gate brief itself, recorded because the brief was wrong and the
repo won.** (i) The brief expected this file to lack a Golden Prediction and a Live Smoke section,
"reported on eight consecutive stories". It has BOTH; only the Golden Prediction's content was
deferred ("TBD at this story's own readiness gate"), correctly, under the permanent 3-3 rule that a
baseline is re-derived at gate time and never copied forward. (ii) The brief called this Set B
lineage. It is not: the file was authored 2026-08-04 at the 3-5 gate. It does, however, exhibit the
Set B failure mode one step removed -- it was written BEFORE 3-5a's dev pass landed later the same
day, so every claim it made about 3-5a was a forward prediction, and finding `3-5b/R1` below is one
of those predictions turning out false.

**`3-5b/R1` -- REFRAME: deck exhaustion is ALREADY REACHABLE in shipped code, and the story's central
premise was false.** Verified by content: `MatchState._resolve_basic_cast` draws a replacement on
EVERY cast (`if not player.deck.is_empty(): player.hand.add(player.deck.draw_top())`), so the pile
drains one card per cast regardless of any delay. With the authored config (`deck_size` 20,
`hand_size` 4) the deal leaves sixteen in the pile, and the SEVENTEENTH cast in a round hits the
`is_empty()` floor: no replacement is drawn, the hand shrinks below four permanently, and nothing
signals it. 3-5b therefore REPLACES a shipped, silent floor behaviour; it does not make exhaustion
reachable. The "sixteen casts" arithmetic the file carried is correct; the conclusion drawn from it
was not. 3-5a's own delivered code says so in two places -- `_resolve_basic_cast`: "with no reshuffle
in this story a pile CAN RUN DOWN", and `discard_pile.gd`: "the deck only ever shrinks within one
round". **SUPERSESSION, formal:** the fence rationale in `test/state/test_deck_and_hand.gd`
(`test_no_reshuffle_exhaustion_or_draw_delay_surface_ships`), which reads "3-5a draws the replacement
INSTANTLY, so a pile still cannot run out inside a round and exhaustion is still unreachable. The
delayed draw is what makes it reachable", is SUPERSEDED as of this entry. Per the standing rule
(`3-5/R4`) the closed story's file is not reopened; this entry is the record. The fence's mechanical
effect is unaffected and it stays green until 3-5b lands.

**`3-5b/R2` -- Death: the window TICKS OUT, the DELIVERY is dropped. `3-5/R8` is CLOSED.** No
early-stop path ships; 1-9/R3 stays locked ("the in-flight window is NOT stopped or shortened here --
it keeps ticking to expiry by design ... it simply resolves to nothing", `match_state.gd`). The
1-9/R1 fact-drop idiom is applied literally: the DEAD / round-over check happens at DELIVERY time and
discards the replacement. This satisfies BOTH the 3-5 gate's blocking finding 6 (which stated the
no-cancel outcome as a requirement) and the operator's sealed intent recorded in `3-5/R8` (which
recorded the same question as OPEN, owner 3-5b) -- the intent was about the OUTCOME, that a corpse is
not handed a card, not about the MECHANISM. The log's self-contradiction between those two entries is
resolved BY THIS RULING, not by editing either of them (append-only convention). `3-5/R8` is closed.
Honest note carried into the story: because DEAD and `_round_over` are a total coupling (`3-5/R6`)
and step 1b returns before step 2, a dead player's window never ticks and the delivery never runs, so
this guard is unreachable in natural play -- defense in depth in the same family as the DEAD branches
at steps 3, 4, 5 and 6, proven non-vacuous by the repo's forced-DEAD idiom.

**`3-5b/R3` -- the pending-draw timer ticks at STEP 2**, beside `hero.tick_timers()` /
`stamina.tick_timers()`, and therefore inherits "does not tick on a frozen tick" for free, because
step 1b (`if _round_over: ... return`) returns before step 2. This is made an EXPLICIT acceptance
criterion rather than silently inherited.

**`3-5b/R4` -- the debug reset KILLS a pending draw; the card is not restored.** `_apply_debug_reset`
/ `_deal_player` already re-lay the full injected composition and clear the discard, so conservation
is restored by construction and 3-3's AC 9 post-reset count pin stays green with no special case.

**`3-5b/R5` -- reshuffle is LAZY, at draw time.** The seat is the draw. An eager reshuffle at
`deck_size == 0` would open the vulnerable window on a cast that does not draw, and would introduce a
second trigger point.

**Interaction of `3-5b/R3` and `3-5b/R5`, resolved rather than left latent.** Ticking the window at
step 2 and reshuffling lazily "at draw time" would put RNG consumption at step 2 on a naive reading,
creating the second RNG seat `3-5b/R5` and F2 both forbid. Ruled: the window is ADVANCED at step 2;
the DELIVERY -- the draw, and therefore any reshuffle -- happens at STEP 6, inside the seat
`_deal_pending_decks()` already occupies. This is the shipped idiom, not a compromise:
`StaminaPool._regen_delay` is already ticked at step 2 and READ at step 5.

**`3-5b/R6` -- deck AND discard both empty is a NO-OP DEGRADE; NO `Invariant.check(false)` ships on
that path.** Reachability depends on authored balance numbers, and a crash path reachable from
authored data is not acceptable. The draw resolves to nothing, the owed count is consumed, the hand
stays short, the window does not open. Gets its own headless test constructing the case directly.

**`3-5b/R7` -- the vulnerable window SHIPS, with an authored duration and NO mechanical cost; open
decision (b) stays OPEN.** The pre-gate AC 5 offered a false dilemma -- author the price, or author
nothing. A `TimingWindow` cannot exist without a duration, and `stories-manual-e3.md` E3.S5b item 4
requires the window open "for the authored ticks", so the field is authored either way. Decision (b)
concerns the window's PRICE, not its existence. Authored value: `reshuffle_vulnerable_window_seconds
= 1.5` (the GDD's "~1.5-2s TBD" range). The mechanism that keeps (b) genuinely open is a NEGATIVE
GUARD required of the dev pass: nothing under `src/` may READ that window except the code that starts
it and the code that emits its event. If nothing reads it, nothing has priced it.

**`3-5b/R8` -- the snapshot gains EXACTLY TWO keys: `pending_draw` and `pending_draw_owed`.** One
timer plus a debt counter: on expiry it draws ONE card and restarts itself while `owed > 0`.
`hand_size` is permitted to reach 0. Both keys cross tick boundaries, which is why they are hashed --
the `_deck_deal_pending` exclusion precedent is available only to state consumed inside the same
`advance()` that armed it, and a pending draw that never crosses a tick is an instant draw; the live
precedent is `StaminaPool.to_snapshot()`'s `"regen_delay": _regen_delay.to_snapshot()`. **NO new
rejection reason:** a cast is not gated on a pending draw, mana stays the only throttle, and a second
throttle is not invented here.

**`3-5b/R9` -- the vulnerable window belongs to the RESHUFFLING PLAYER ONLY**, payload carries that
player's slot index, and it is mechanically inert while (b) stands -- so the block / roll / iframe
interaction question does not arise and must not be answered speculatively.

**`3-5b/R10` -- `draw_replacement_delay_seconds = 1.0`, authored, with a bespoke `> 0.0` bound.** The
value is an authored PLACEHOLDER; the feel judgement moves to E4/E5. The AC requires the AUTHORED
VALUE, not merely the field's existence, because `field in config` and the generic `>= 0.0` loop both
pass on the script default of `0.0` -- which would ship the story invisible in the build and recreate
exactly the dead field `balance_config.gd`'s reservation comment was written to prevent. Mechanism:
the field joins `E1_BALANCE_FIELDS` under the existing `>= 0.0` loop (no bespoke non-negativity audit
added), and a BESPOKE `> 0.0` authoring bound lands in `test_balance_authoring.gd`, the
`deck_size`/`hand_size` precedent. **Consequence stated openly:** that bound narrows the manual's
"zero means instant" out of the SHIPPED config until the E4/E5 feel pass, at which point relaxing it
is a one-line test edit. The MECHANISM must still handle a zero-tick delay correctly, proven against
an in-test `BalanceConfig`, never against the authored `.tres` -- so BC/R3's isolation of authored
balance from the unit suite is preserved. **The golden fixture must author a NONZERO value**, per the
standing lesson that a fixture which does not author its own content measures a false non-move.

**`3-5b/R11` -- Live Smoke NOT REQUIRED, reason CORRECTED; R-D6 not re-invoked; the S1/S2 asterisk
CARRIED FORWARD.** The story's stated reason (reaching exhaustion needs an unrealistic grind) is not
the binding one and rested on the premise `3-5b/R1` just corrected. The true reason is 3-3's: this
story ships NO player-facing surface. Verified by content: `hud_root.gd` renders the card row from
"the presentation-local constant 4 (2-5/R1) ... no read of `PlayerState.hand`", so a delayed
replacement is invisible; the deck readout is the literal placeholder
`_make_placeholder_panel("DeckIndicator", "DECK -- / RESH")`, wired to nothing; and the vulnerable
window's renderer is 3-6, which is exactly why the locked order is `3-5a -> 3-5b -> 3-0c -> 3-6`.
3-5a's smoke already recorded this as finding S5. **The R-D6 smoke acceptance is NOT re-invoked by
3-5b** -- it was re-invoked and SPENT at 3-5a and remains 3-6's. **Therefore the S1/S2 asterisk is
NOT spent on a smoke that will not happen:** the melee/mana retune was deliberately skipped (operator
ruling, 4 Aug) because the loop -- buildup -> bluff -> payoff -- does not yet exist; only buildup
does, there is no bluff (no hidden cards) and no payoff (effects do nothing, `card_cast_resolved` has
no listener, no `CardEffect` consumer exists in `src/`). The mana rate is known too fast and the melee
share known too large, both recorded in the operator's own playtest log. That asterisk is CARRIED
FORWARD to 3-6 and to the E4/E5 balance pass, and any future conclusion about exhaustion reachability
drawn from a LIVE session carries it -- casts per round is a direct function of mana income.

**`3-5b/R12` -- the story carries a FENCE INVENTORY TABLE with a per-guard verdict.** Under `src/`,
the `reshuffle` / `vulnerab` / `draw_replacement` bans DIE (3-5b is their legitimate owner) while
**`exhaust` REMAINS BANNED** -- exhaustion is expressible as `is_empty()`, which is already how 3-5a
expresses it. The `CardEffect` guard SURVIVES untouched, with a correction of record: `CardEffect` is
NOT banned from `src/` at all -- the class ships (`class_name CardEffect`) and `card_data.gd` exports
it twice; the fence bans a CONSUMER and explicitly excludes `card_effect.gd`,
`card_cast_condition.gd` and `card_data.gd`. The Input Map action-name ban and its positive twin both
SURVIVE (3-5b adds no actions and does not touch `project.godot`). **Two fences neither the story nor
the gate brief had named** are inventoried here: the `Deck`/`Hand` METHOD-NAME fence
(`test_hand_and_deck_expose_no_play_or_discard_path`, banning `discard`/`play`/`reshuffle`/`refill`/
`exhaust` as method names) STAYS GREEN via the no-new-method route -- `set_contents(discard.to_array())`
+ `shuffle_with_rng(_rng)` + `discard.clear()`; and
`test_event_bus_still_carries_exactly_the_two_declared_signals` is DELIBERATELY UPDATED from two
signals to three, that test existing precisely so this cannot happen quietly. Any narrowed guard must
RETAIN both its vacuity assertion (`scanned > 0`) and its regex self-test, so a typo cannot silently
disarm a fence that has just been narrowed.

**`3-5b/R13` -- new ACs for everything the gate found uncovered, plus a REFLECTIVE completeness
guard.** Uncovered and now covered: debug reset versus a pending draw; frozen-tick behaviour; death;
the reshuffle trigger point; the both-empty case; the conservation property gaining a FOURTH term
(in-flight); and a HEADLESS integration proof of exhaustion, reshuffle and both-empty -- required,
because live observation can reach none of it (`3-5b/R11`). Separately: today `E1_BALANCE_FIELDS` is
a literal `const Array[String]` and `test_balance_config.gd::test_conversion_covers_every_seconds_field`
is a literal dictionary of nine fields, so a `*_seconds` field added to `BalanceConfig` and forgotten
in either place fails NOTHING. A reflective guard over `BalanceConfig.get_property_list()` must land,
asserting every declared numeric property appears in `E1_BALANCE_FIELDS` and every `*_seconds`
property has a derived counterpart from `BalanceTicks.from_config()`. 3-5b adds two fields and is the
forcing point. Mutation-proven.

**`3-5b/R14` -- the 3-0c obligation is EXTENDED to the injected COST MAP.** The log previously
recorded only that the injected deck COMPOSITION must enter the replay record alongside seed, intents
and reload events (Session 2026-08-03, Story 3-3 readiness gate; restated at the 3-5 gate). The cost
map (`inject_card_costs`, 3-5a AC4) is in the identical position -- injected once at match start,
excluded from `to_snapshot()`, and outcome-changing -- so a replay against a re-priced card set
diverges silently, which is the exact failure the composition obligation exists to prevent. The
obligation now covers BOTH. The `3-0c` story file is deliberately NOT edited (it does not exist yet,
per E3-P/R3); this entry is the record its own gate picks up. Recorded alongside: 3-5b itself adds NO
further replay-relevant injected state -- its two new values are `BalanceConfig` fields, already
covered by DEBT B's reload-events-in-the-stream half.

**`3-5b/R15` -- Project Structure Notes corrected to `src/systems/event_bus.gd`.** The pre-gate text
named `src/main/event_bus.gd`, which does not exist; verified by content, `src/systems/event_bus.gd`
is the only `event_bus.gd` in the tree and is the path the fence test loads
(`load("res://src/systems/event_bus.gd")`). This mattered because Project Structure Notes is the one
section that tells a dev pass where new code goes, and this was its only new-file claim.

**`3-5b/R16` -- Golden Prediction: MOVES, ONE re-baseline, FOUR separately named causes**, replacing
"TBD at this story's own readiness gate". Baseline re-derived at write time from the `GOLDEN` constant
in `test/state/test_determinism.gd`: `c4b9f897138a2b36dbce11f939b2892379919909c17df1696cde24a75c070e2e`.
**C1**, the `pending_draw` snapshot key: MOVER, measured by adding the key alone, all-zero,
unconditional, no behaviour change, fixture delay 0.0 (the M1 shape from `3-5/R2`); reverse by
removing that key only and expecting the exact baseline back. **C2**, the vulnerable-window snapshot
key: MOVER, added on top of C1, still all-zero; reverse by removing only C2's key and expecting C1's
hash bit-identically -- ONE KEY AT A TIME is what separates C1 from C2. **C3**, the authored delay, in
two steps isolating the SEAT from its CONTENT (the M2 precedent): (a) fixture at 0.0 reproduces
C1+C2's hash BIT-IDENTICALLY, (b) fixture at a nonzero value still running at the hashed tick moves it
again, because that tick's `hand_size` is one LOWER and `deck_size` one HIGHER -- the fixture casts at
t22 and hashes at t24. **C4**, `rng_state`: NON-MOVER -- `_golden_config` authors `deck_size` 17 /
`hand_size` 9, leaving eight cards per pile against one recorded cast, so the fixture cannot reach
exhaustion, `shuffle_with_rng` is never re-entered, and `draw_top()` consumes no RNG whenever it
fires; forward half is keeping `test_the_recorded_cast_consumes_no_rng` green, and the REVERSE half is
required -- prove a reshuffle DOES move `rng_state` in a SEPARATE, NON-GOLDEN fixture driven to
exhaustion, without which C4 is a vacuous claim. **The golden sequence is NOT widened to reach
exhaustion**; exhaustion, reshuffle and both-empty are proven in dedicated headless tests instead.
Recorded for the dev pass because it is easy to miss: a nonzero fixture delay BREAKS three existing
non-golden assertions that pin the instant refill by name (`test_golden_sequence_exercises_the_recorded
_cast`'s "INSTANT refill: the hand is back to full" and its deck count, and the same two counts in
`test_golden_sequence_exercises_deck_shuffle_and_hand_fill`); those must be rewritten and green BEFORE
the re-baseline is taken.

**`3-5b/R17` -- F2 BECOMES MACHINE-CHECKED; the second-RNG-seat gap this session's own report named
is CLOSED.** The gate reported that AC 5's "no second RNG seat / F2 stays provable by inspection"
clause had NO machine guard, and deliberately did not invent one, because adding an architecture
invariant is a design decision. Operator ruling: **the guard SHIPS.** Shape -- a source scan over
`src/` asserting that `shuffle_with_rng(` appears in EXACTLY TWO places: its definition in
`src/state/deck.gd`, and exactly ONE call site, in `src/state/match_state.gd`. Measured at gate time,
those are precisely the two occurrences that exist (`deck.gd`: `func shuffle_with_rng(rng:
RandomNumberGenerator) -> void:`; `match_state.gd`, inside `_deal_player`:
`player.deck.shuffle_with_rng(_rng)`). Mutation-proven in the FALLING direction -- adding a second
call site anywhere under `src/` must make it FAIL -- because a guard that only confirms the current
count is one refactor away from vacuous; and carrying the same `scanned > 0` vacuity assertion the
other source scans carry. **Home:** `test/state/test_architecture_invariants.gd`. The repo makes that
choice obvious rather than free: that file already declares itself "executable guards for the
load-bearing architectural invariants (F1, D3a, D3b)" and already houses every later
architecture-invariant source scan (root-motion, `CardData`, implicit-global-RNG / `CardDatabase`,
the 3-5a mode-select scope). Its header enumeration is updated to name F2.

**Why 3-5b is F2's forcing point, recorded so the timing is not read as arbitrary.** F2 -- "the
seeded RNG is consumed only inside `advance()`" -- is cited as a binding contract by 3-3 (AC 7),
3-5a, and this story (AC 5), and has been enforced by REVIEW ONLY for all three. The nearest existing
guard, `test_state_layer_has_no_nondeterministic_source` (D3(b)/A2) plus its 3-3 extension, bans the
bare `randf`/`randi` family and the implicit-global-RNG collection APIs inside `src/state/` -- it says
nothing about a SECOND SEEDED SEAT, so nothing in the suite would fail today if `_rng` were consumed
from a second call site. Until now that was theoretical: only the one-shot deal consumed the
generator. 3-5b's lazy reshuffle (`3-5b/R5`) is the first mechanism that makes a second seat a
natural thing to reach for -- and `3-5b/R5`'s own step-2/step-6 split exists precisely because the
naive reading creates one. The story that makes an invariant breakable is the story that should
machine-check it. This ruling SUPERSEDES the "uncovered gap" finding recorded in this same session's
gate report; the report is not edited, this entry is the record.

**`3-5b/R18` -- `3-5b/R17`'s two-occurrence form was SELF-CONTRADICTORY; CORRECTED, not relaxed.**
R17 is left standing above exactly as ruled (append-only); this entry is its correction. **The
defect:** R17 measured `shuffle_with_rng(` at two occurrences under `src/` and pinned that number,
but the measurement was taken PRE-IMPLEMENTATION. `3-5b`'s own AC 5 specifies a reshuffle that
shuffles -- `set_contents(discard.to_array())` + a shuffle + `discard.clear()` -- so once this story
lands, `_deal_player`'s existing call plus the reshuffle's call make the count THREE. A guard pinned
at two would have FAILED ON ITS OWN STORY. Neither the ruling nor the gate that produced it caught
this; the count was measured against today's `src/` and pinned as-is, which is exactly the class of
error this project's "measure in both directions" discipline exists to catch, applied here to a
count instead of a hash.

**The correction, and why it is not simply "pin it at three."** Relaxing the number to three would
concede the SECOND SEAT the guard exists to prevent -- the guard would then permit precisely the
thing F2 forbids, while still passing. Ruled instead: **remove the second CALL SITE while keeping
both shuffle OCCASIONS.** `src/state/match_state.gd` gains ONE private shuffle helper; the
match-start/debug-reset deal (`_deal_player`) and AC 5's reshuffle both route through it, and it is
the only thing in `src/` that calls `Deck.shuffle_with_rng()`. The guard then stands as R17 wrote it
-- definition plus exactly ONE caller -- and "the seeded RNG is consumed in one seat" becomes
LITERALLY true rather than approximately true, which is a stronger property than the one R17 set out
to protect. The AC's count claim is restated as the POST-LANDING count, since the same scan passes
against today's `src/` for a different reason (one occasion, one call site) and so proves nothing if
run before the work starts.

**ESCAPE HATCH, ruled explicitly because a guard that forces bad code is worse than no guard.** If
the shared helper genuinely contorts the implementation -- if the two paths turn out to differ by
more than which array they shuffle -- the dev pass **STOPS AND ASKS** rather than quietly adding a
second call site and relaxing the AC. A second seeded seat is a DESIGN change and is the operator's
call, not an implementation detail. AC 5 and AC 16 both carry this in the story file, along with a
Dev Notes bullet recording the defect so a later reader does not rediscover it as a fresh finding.

**Architecture-amendment queue: the SEVENTH member's conditional clause FIRES on this story** -- "if a
vulnerable-window signal lands with 3-5, the `EventBus` header and the seam registry both need
reconciling against the bus's enumerated signal set" (Session 2026-08-03, Story 3-3 readiness gate
close-out; re-attached to `3-5b` at the 3-5 gate). `3-5b`'s AC 6 lands that signal. RECORDED, not
flushed: the flush point remains the E3 close-out, unchanged.

**Process note, recorded because it cost real time and is repeatable.** During the gate's baseline
measurement an integration invocation OMITTED `--script` (`godot --headless --path . <file>` instead
of `godot --headless --path . --script res://test/integration/<file>.gd`). Godot treated the argument
as a scene path and HUNG; the process ran about ten minutes before it was noticed, and the enclosing
loop kept respawning replacements as each was killed. Fixed by stopping the loop first, then the
processes, then rerunning with `--script` -- 17/17 PASS. `test/run_all.sh` has always used `--script`;
the error was in an ad-hoc PowerShell transcription of it. Any future gate running integration tests
individually must include `--script`.

**Promotion.** All eighteen rulings applied to `3-5b` the same session; Status and board promoted
`backlog` -> `ready-for-dev`, `sprint-status.yaml` updated alongside in the same commit. Docs-only
pass -- suite run once for the baseline measurement above, no code touched, `project.godot` untouched.
Next story in the locked order after 3-5b: `3-0c`, then `3-6`.

**Close-out.** Commit chain: `docs(stories): 3-5b gate fixes + promote to ready-for-dev` (the story
file and `sprint-status.yaml`) and this entry. No push -- the operator reviews the log and pushes.

---

## Session 2026-08-04 -- 3-5b close-out

Continues this story's label series (`3-5b/R1`..`R18` above) with rulings `3-5b/R19`..`R21`, recorded
after the dev pass (Claude Opus 5) landed and the commit chain (Claude Sonnet 5) verified and shipped
it. Verification this session: `HEAD` started at `f80cb05`, matching `origin/main`, 0/0 divergence; no
Godot process was found running before the chain touched anything; the working tree matched the dev
pass's expected 14-modified/2-untracked set exactly; `project.godot`'s diff was EMPTY and its SHA256
matched the carried constant `8879DE490EDDA78051595F189FB9BB6F2E75384FEBAFF142C8958EC107970004`
exactly, unchanged from the `3-5a` chain. State harness 310 tests / 1463 assertions / 0 failed, all
18 integration files PASS individually (each invocation including `--script`, per the process note two
sessions ago), zero `SCRIPT ERROR` / `Parse Error` / `INVARIANT VIOLATED` lines, matching the dev
pass's own recorded numbers exactly -- nothing was re-derived, only verified. One headless editor scan
generated exactly the two `.uid` files owed by the two new `.gd` files
(`test/state/test_draw_delay_and_reshuffle.gd.uid`, `test/integration/test_deck_reshuffle.gd.uid`) and
nothing else -- no `project.godot` reorder, no deleted engine-default setting, no stray uid attribute,
no scene renormalization.

**Suite: 287 tests / 1297 assertions + 17 integration -> 310 tests / 1463 assertions + 18 integration**
(`test_deck_reshuffle.gd` added). **Golden re-baselined the SEVENTH time**, `c4b9f897138a2b36dbce11f939
b2892379919909c17df1696cde24a75c070e2e` -> `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39
fa322`, four causes measured one edit at a time, each reproduced in both directions: **C1** (the
`pending_draw` snapshot key, added alone at all-zero, mechanism still inert) `c4b9f897` -> `9bcfcd7a`,
reverse by removing the key reproduced `c4b9f897` exactly; **C2** (the `pending_draw_owed` key, added
on top of C1, still all-zero) `9bcfcd7a` -> `b5b4da8d`, reverse by removing only C2's key reproduced
`9bcfcd7a` exactly; **C3(a)** (the mechanism -- step-2 tick, step-6 delivery, debt increment, lazy
reshuffle, vulnerable-window signal -- fully re-enabled with the fixture still priced `0.0`) MEASURED
UNMOVED, still `b5b4da8d`, bit-identical to C2, proving the mechanism structurally incapable of moving
the hash on its own; **C3(b)** (the fixture's `draw_replacement_delay_seconds` priced at a nonzero
coverage value, `DRAW_DELAY_TICKS` 11, so the t22 cast's replacement is still in flight at the t24
hash) `b5b4da8d` -> `40eb5554`, the ONE behavioural mover and the final value, reverse by re-pricing the
fixture delay back to `0.0` reproduced `b5b4da8d` exactly. **C4**, `rng_state`: predicted a non-mover,
measured a non-mover in BOTH directions -- forward, `test_the_recorded_cast_consumes_no_rng` stays
green because `draw_top()` consumes nothing whether it fires on the cast tick or eleven ticks later,
and `_golden_config` leaves eight cards per pile against one recorded cast so no reshuffle is reachable
on this fixture; reverse, a reshuffle DOES move `rng_state`, measured in two separate non-golden
fixtures driven to exhaustion (`test_draw_delay_and_reshuffle.gd`, and `test/integration
/test_deck_reshuffle.gd` on the AUTHORED `data/balance/balance_config.tres` values).

**`3-5b/R19` -- the Golden Prediction's C2 caption was WRONG and is corrected.** `3-5b/R16` captioned
C2 "the vulnerable-window snapshot key", but `3-5b/R8` and AC 4 rule the snapshot gains EXACTLY TWO
keys and name them both (`pending_draw`, `pending_draw_owed`), and AC 2 rules that nothing under `src/`
may READ the vulnerable window -- `to_snapshot()` is a read. C2's real subject is `pending_draw_owed`;
everything else in C2's text describes it exactly (added on top of C1, still all-zero, no behaviour
change, reversible to C1 bit-identically, "ONE KEY AT A TIME is what separates C1 from C2"), so all
four causes are real and measured; only the caption is wrong. The dev pass followed the ACs and
reported the discrepancy rather than resolving it silently, which is correct. **CARRIED CONSEQUENCE,
stated as a standing obligation rather than an observation:** the vulnerable window is CROSS-TICK STATE
THAT IS NOT HASHED. That is safe only because nothing reads it -- state no code consults cannot change
an outcome or desync a replay -- and AC 2's guard is what keeps that premise true. **The first story
that gives the window a mechanical cost MUST bring it into the snapshot in the same pass.**

**`3-5b/R20` -- named obligation for `3-6`.** The window is today WRITE-ONLY state: ticked, never read.
`3-6` must decide EXPLICITLY whether it renders from the `EventBus` event with its own
presentation-local timer (the window stays unread and AC 2's guard stays green) or starts reading state
-- the second automatically pulls the window into the snapshot and creates a new golden cause. This is
`3-6`'s to answer at its own gate, not to discover during implementation.

**`3-5b/R21` -- AC 10 is stronger than `3-5b/R6` claimed.** R6 said reachability of the both-empty case
depends on authored balance numbers. It does not: conservation makes it unreachable at ANY authored
numbers, since both piles empty would require the hand to hold the whole composition, which needs
successful draws to exceed casts. The no-op degrade therefore ships as DEFENSE IN DEPTH in the same
family as AC 7's DEAD check, constructed directly by its test rather than driven to. No code change;
the claim in the record is corrected.

**Two PRE-EXISTING defects found by AC 13's reflective guard on its first run**, recorded as their own
finding and NOT folded into `3-5b`'s scope: `attack_stamina_cost` (shipped by the stamina-cost
corrective pass) and `block_facing_arc_degrees` (shipped by `1-8`) had never been added to the
hand-maintained `E1_BALANCE_FIELDS`, so neither was covered by the non-negativity audit -- for four and
eleven stories respectively. Both repaired in this story's commit. This is the guard doing on its first
run exactly what it was ruled in for.

**A blind spot in this story's OWN AC 2 guard**, found by mutation M-J: the pattern was anchored on
`.vulnerable_window` (a leading dot), so it saw every read through a handle but NOT an unqualified
self-read inside `player_state.gd`, where the field is named bare. A second pattern banning
`vulnerable_window.(is_running|remaining_ticks|to_snapshot)` outright, dot or no dot, now closes it;
M-J was re-run and the strengthened guard falls correctly.

**A FOURTH assertion broken by the nonzero fixture delay**, beyond the three `3-5b/R16` named:
`test_two_matches_with_a_populated_deck_hash_identically` carried the same `DECK_SIZE - HAND_SIZE - 1`
sanity count as the other three and was rewritten alongside them, now reading `DECK_SIZE - HAND_SIZE`
("P1's t22 replacement is still owed, not yet drawn").

**Two test RENAMES**, old names recorded verbatim so the Fence Inventory stays greppable:
`test_no_reshuffle_exhaustion_or_draw_delay_surface_ships` -> `test_no_deck_exhaustion_surface_ships`
(the ban on `reshuffle`/`vulnerab`/`draw_replacement` dies, `exhaust` survives as the sole remaining
token); `test_event_bus_still_carries_exactly_the_two_declared_signals` ->
`test_event_bus_still_carries_exactly_the_three_declared_signals` (AC 6's third bus signal).

**Process note.** A SECOND Godot hang in this story's cycle, this one from `$ErrorActionPreference =
"Stop"` aborting on Godot's stderr inside the mutation harness (the first, two sessions ago, was an
omitted `--script` at the gate). Both were noticed and cleaned up by the agent; recorded so the pattern
is visible -- a future harness invocation should not set `-Stop` around a Godot subprocess call.

**Live Smoke NOT REQUIRED and R-D6 NOT re-invoked** -- both remain `3-6`'s, per the story's own
readiness-gate ruling (no player-facing surface). `docs/playtest-log.md` is untouched. The S1/S2
melee/mana asterisk (`3-4` close-out) is carried forward to `3-6` and the E4/E5 balance pass rather
than spent here.

**Board: done.** Next story in the locked order: `3-0c`, then `3-6`.

**Close-out.** Commit chain: `story 3-5b: draw-replacement delay, deck exhaustion, reshuffle,
vulnerable window` (`b9692c4`, code, tests, `data/balance/balance_config.tres`, two `.uid` siblings),
`docs(3-5b): dev pass record` (`434c9f2`, the story's own Dev Pass Record), `board: promote
3-5b-draw-delay-exhaustion-reshuffle to done (review passed)` (`18c9e9d`), and this entry. No push --
the operator reviews the log and pushes.

---

## Session 2026-08-04 -- Story 3-0c readiness gate

Readiness gate on `docs/implementation-artifacts/3-0c-intent-recorder.md` (authored earlier the same
day at its own creation pass, commit `290e4c9`, per `E3-P/R3`) returned **NOT READY** with **TEN
blocking findings**. All ten were resolved the same session by eleven operator rulings, applied to the
story file in this pass. This is the **TWENTIETH logged readiness-gate session; all twenty returned NOT
READY on first reading and all twenty were resolved the same session.** The gate report itself lives in
the browser session; this entry is the record of the OUTCOME and the RULINGS, not a transcription of
the findings.

**Verification before anything was edited.** `HEAD` `290e4c9`, working tree clean; `HEAD^` `ce30569`
matching `origin/main` (behind by one, no divergence); no Godot process running. Every ruling below
that rests on a fact about shipped code was RE-VERIFIED BY CONTENT in this pass rather than taken on
report -- four premises came back inaccurate and are corrected in place, each named as a correction
rather than silently applied. Docs-only pass: nothing under `src/`, `test/` or `project.godot` is
touched and the suite is deliberately NOT run.

**`3-0c/R1` -- REPLAY IS NOT A CONTROLLER SWAP ALONE.** Verified by content: contact facts originate in
the runner, not in any controller -- `_gather_contact_facts` (`match_runner.gd:388-410`) reads
`actor.hitbox.get_overlapping_areas()` and raw `global_position` deltas -- and `InputIntent` carries no
contact field. A swapped-in `ReplayController` is therefore STRUCTURALLY INCAPABLE of delivering them,
and regenerating them through physics on replay was rejected at 1-7's gate (D-4): it "would hang replay
soundness on Jolt bit-determinism." Ruled: **replay mode ALSO suppresses the runner's contact-fact
gathering and drains recorded facts into `push_contact`, keyed by tick index.** `MatchState`'s seam is
UNCHANGED -- `push_contact` already accepts facts from whoever pushes them, and headless tests have fed
synthetic facts through it since 1-5. Landed as the story's AC 9 with the reasoning in Dev Notes.
Recorded alongside, as its own Dev Note: **replay guarantees STATE identity, not VISUAL identity.**
Actor positions come from `move_and_slide` and may drift; that is tolerable precisely because the ONLY
physics-to-state channel is the contact fact, and the contact fact is recorded.

**`3-0c/R2` -- "EXACTLY FIVE CHANNELS" IS DEAD; THE CHANNEL LIST IS DERIVED.** No ruling anywhere
enumerates five, and the story's own AC list contradicted the number by naming seven things. Replaced:
the channel set is DERIVED from `MatchState`'s external intake surface by a SOURCE SCAN, so the guard
fails when a new intake seam ships without a channel. **The intake list supplied at the gate was
INCOMPLETE and is corrected here by content.** The surface is EIGHT members, not seven:
`advance(intents)`, `apply_balance(config)`, `inject_feature_flags(value)`, `inject_deck(contents)`,
`inject_card_costs(costs)`, `push_contact(...)`, **`set_camera_basis(slot, camera_basis)`**, and the
seed reaching `_init` via `MatchParams`. `set_camera_basis` (`match_state.gd:389`) is pushed by the
runner every ticking frame (`match_runner.gd:460-461`) and its value is READ during movement resolution
(`match_state.gd:567,975`), so it reaches `HeroState.velocity`, which IS hashed -- a replay that does
not restore it can diverge. It is today always identity in live play (`CameraRig` has no look input and
the rig's LOCAL basis is unaffected by the hero-root rotation DECISION A forbids) and
`_resolve_movement` short-circuits on identity, so the channel is cheap now and load-bearing the moment
a look action ships. `drain_signals()` is the one public method exempted, and the guard must name it
exempt IN THE ASSERTION with its reason (it carries no data inward); `to_snapshot()` and
`debug_window_ticks_remaining()` are egress, not intake. Landed as AC 1 and AC 8.

**`3-0c/R3` -- FEATURE FLAGS ARE A CHANNEL.** Injected flags have the identical three properties that
made deck composition and the cost map mandatory: match-start, content-only, absent from
`to_snapshot()`. A replay against a different flags resource diverges silently -- the same failure
`2-6/R4` names from the other direction ("flags appear in neither `MatchState.to_snapshot()` nor the
recorded intent stream, so mutating one at runtime would be a silent replay hole"). **Capture is NOT
runtime mutation:** the load-once, runtime-immutable ruling for `FeatureFlags` stands untouched, and the
story states both clauses in the same AC so this cannot be read as reopening it. Verified by content:
`FeatureFlagsService` still has no `reload()` method at all. Landed as AC 7.

**`3-0c/R4` -- THE INITIAL `apply_balance()` IS RELOAD EVENT #0.** It is captured as the first event on
the reload channel. This resolves the gate's finding that the AC pointed at a call site it had itself
declared out of scope: the single existing call site (`match_runner.gd:95`) is exactly the right source,
and reusing the reload channel's shape avoids inventing a sixth channel for it. On replay, balance
values come from the record and are never re-read from disk -- which is what makes a recording survive a
tuning pass. Landed as AC 4.

**`3-0c/R5` -- THE STORY SPLITS IN TWO.** `3-0c` keeps the contract and its proof and is **entirely
headless**: all capture channels, the `ReplayController`, replay-side fact injection, and the
record-then-replay identity test. No file I/O, no operator UI, no Input Map action, no live reload
trigger. A new sibling story takes the operator surface and the live half of the balance-reload debt:
`ResourceLoader` `CACHE_MODE_IGNORE`, a live mid-match reload trigger, `user://` persistence and the
serialisation format, the start/stop/load control folded into the existing `DebugInstrumentPanel`, and
the live smoke. **This divides DEBT B along its own stated seam** (`decision-log:171`: "Both DEBT B
halves (CACHE_MODE_IGNORE + reload event in the replay stream)"): its stream half closes in `3-0c`, its
cache half in the sibling. Board key created: **`3-0d-replay-surface-and-live-reload`**, added to
`sprint-status.yaml` as a BOARD SLOT ONLY -- key, `backlog`, `story_notes` -- with the story file
authored just-in-time at its own creation pass, the precedent `3-0a`/`3-0b`/`3-0c` all followed. Placed
between `3-0c-intent-recorder` and `3-1-matchstate-config-object` in both `development_status` and
`story_notes`, matching the board's numeric-within-epic ordering convention (verified by content against
the existing E3 block). `E3-P/R3` -- the planning ruling that assigned BOTH DEBT B halves plus
record/replay to a single story -- is **AMENDED BY APPEND**: its original text is left untouched and a
`**Pointer**` paragraph is added directly beneath it scoping the contract across the pair, the shape
this log already uses (`decision-log:331`) and the same append-only discipline `E3-P/R2` was amended
under at the E3 revisit gate.

**`3-0c/R6` -- THE IDENTITY TEST IS THE PRIMARY ACCEPTANCE.** The gate is right that a passive tap is
unfalsifiable by construction: BOTH of the story's hash-comparison ACs (run the golden sequence with
and without a recorder; assert no captured channel moves the hash) pass with `capture()` bodied as
`pass`. They are REPLACED by one AC that records a driven run and replays it **FROM THE RECORD ALONE**
to a bit-identical `CanonicalHash`. That test lives in its **OWN fixture** and never in the golden
sequence -- it must drive every channel, including a mid-run `apply_balance` and pushed contact facts,
which the golden fixture must NOT gain. Drop any channel and the test diverges; that is what makes every
capture AC falsifiable at once. Landed as AC 10, and the two replaced ACs do not ship.

**`3-0c/R7` -- THE FABRICATED QUOTATION IS DELETED, and this is also a PROCESS FINDING.** The story's
AC 2 attributed this sentence to `input_intent.gd`'s header: "3-5 -> 3-0c ordering existed precisely so
the contract is not written against a moving shape." **That sentence does not exist anywhere in the
repo** -- verified by reading the file in full. The quotation is removed; the AC's substance (the
eight-field shape is final and safe to lock) is kept and re-sourced to two things that do exist, both
quoted exactly: `input_intent.gd`'s real header -- "This is INPUT, not persistent state -- it is
captured separately in the X5 intent stream and is deliberately excluded from the to_snapshot()
determinism contract" -- and the E3 ordering ruling (Session 2026-07-31 -- E3 revisit gate (outcome),
"ORDER, recorded as part of the outcome") -- "3-0c follows 3-5 so the intent shape (the new card fields
on `InputIntent`) is final before the stream contract is written."

**PROCESS FINDING, recorded in its own right: a story-creation pass INVENTED A VERBATIM QUOTATION and
attributed it to a source file.** First occurrence of this class in this project. Recorded plainly here
so the class is visible to later passes; no further consequence is attached to it in this entry.

**`3-0c/R8` -- REPLAY EQUALITY IS HASH-ONLY, and the unhashed cross-tick set is THREE members, not
one.** The gate asked for an explicit assertion that the set is exactly
`{PlayerState.vulnerable_window}` and asked for it to be verified by content first. **It was, and it is
incomplete.** The set is: (a) `PlayerState.vulnerable_window` -- unhashed because nothing reads it, per
`3-5b/R19`, whose read decision is handed to `3-6` by `3-5b/R20`; (b) **the card containers' CONTENTS
and ORDER** in `Deck`/`Hand`/`DiscardPile` -- `PlayerState.to_snapshot()` ships `deck_size`,
`hand_size` and `discard_size` only, and the file says why in its own comment (`player_state.gd:84-87`):
"Deck ORDER is deliberately not hash-visible -- it stays derivable from seed plus injected
composition"; (c) **`MatchState._camera_bases`** -- cross-tick, externally pushed, never snapshotted.
(b) matters more than it first reads: its soundness argument is a REPLAY argument, and it holds only if
the seed, the composition, the injection ORDER and F2's single seeded seat all hold across the replay --
which is exactly what this story delivers, so the channels are what keep the existing exemption honest
rather than merely inherited. (c) is answered by `3-0c/R2`'s new channel rather than by a snapshot key.
Ruled: replay equality checks the canonical hash ONLY, plus one structural pin asserting the exclusion
set is exactly those three, each with its reason, so a fourth exclusion appearing later FAILS rather
than quietly weakening the equality claim. Landed as AC 11. The paraphrase-inside-quote-marks of
`3-5b/R19` that the story carried is replaced with the exact text.

**`3-0c/R9` -- RECORDER PLACEMENT IS CLOSED: `src/systems/`, runner-owned.** Not because the
architecture tree says so -- `3-0c/R10` strips the tree of that authority -- but because three live
guards in `test_architecture_invariants.gd`, each scanning EVERY `.gd` file under `src/state/`,
independently forbid the natural implementation of a state-resident recorder:
`test_state_layer_has_no_nondeterministic_source` (D3(b)/A2) bans `Time.`/`OS.`/`Engine.`, so a
recording header, a timestamp or any user-path lookup is illegal there;
`test_state_layer_never_names_card_data` bans `CARDS_DIR`/`data/cards`, so a recorder resolving its
captured composition against the card library by path is illegal there; and
`test_state_layer_never_uses_implicit_global_rng_or_card_database` bans the `CardDatabase` autoload --
the same reach through the other door -- plus a bare `seed(`, which is how a replay-side reseed would
naturally be written. **The argument's limit is stated in the story rather than glossed:** a
deliberately clock-free, content-blind, in-memory recorder placed under `src/state/` would trip none of
the four whole-directory scans, which is why the AC ships its own token scan instead of resting on the
guards alone.

**`3-0c/R10` -- THE ARCHITECTURE DOC'S X5 SECTION IS PRE-CODE TEXT.** Verified by content: the X5
directory-tree entries (`intent_recorder.gd`, `replay_controller.gd`) and the record/replay wiring trace
to `6ac94bc` (2026-07-21), revised once by `11fdd23` the same day. **The gate said a single docs commit;
it is two** -- but both precede `57038dc`, the first commit adding anything under `src/` (rev-counts 8
and 9 against 11), so the load-bearing property (pre-code) holds and the ruling stands. It is therefore
a source of CANDIDATE DESIGN, not authority -- the same class as the section that once claimed E0 had
landed the economy evaluator. Two consequences: **(1)** its scope line -- "record + replay only -- no
rewind, no scrubbing UI" -- is **RATIFIED NOW as a decision**, so it stops being aspirational; **(2)**
its controller-swap replay mechanism is DEMONSTRATED INSUFFICIENT by `3-0c/R1` and becomes a new
**architecture-amendment queue member -- the NINTH.** The queue held EIGHT (verified by content: five at
`3-4/R4`, a sixth at the 3-2 gate, a seventh at the 3-3 gate close-out, an eighth at `3-5/R9`; `3-5b`'s
gate fired the seventh member's conditional clause without adding a member).
`docs/game-architecture.md` is NOT edited this pass -- the queue flushes at the E3 close-out, forcing
point unchanged.

**`3-0c/R11` -- GUARD AND WORDING CORRECTIONS.** (i) The seven-`connect_*` count has NO test pinning it
today -- verified by content: `connect_` appears in `test/` only as usage, never as a count assertion,
so the frozen family (`2-6/R7`) has been review-enforced for eleven stories. This story creates that
guard, proven FALLING. (ii) The negative Input-Map scan dies as a standalone AC -- it is vacuous by the
repo's own labelled precedent (`test_deck_and_hand.gd:399-401`: "The negative guard above cannot tell
'correctly added' from 'never added', so the pair is what makes the Input Map edit checkable in both
directions"). It binds instead to an EXACT-EQUALITY pin of the project's action set, so an added action
fails as loudly as a removed one. **Correction of record:** there is no full-action-set positive pin
today -- the two existing positive pins are partial
(`test_card_scheme_input_actions_ship_for_both_players`,
`test_debug_pause_and_step_actions_exist_and_are_match_global`) and neither can fail on an ADDITION, so
the AC creates the exact-equality form rather than citing one. (iii) The fixture seed is parameterised.
**Correction of record:** `12345` is `match_runner.gd:20`'s `_SEED`; the state fixture's constant is
`test_determinism.gd:271`, `SEED := 1337`. The ruling's substance is unaffected -- a seed assertion
against any hardcoded constant proves nothing. (iv) "At the same tick it is injected" -> "at match
start, before the first tick" (both injections happen in `_ready()`, tick 0). (v) The record must carry
the deck-composition/cost-map injection ORDER and replay must apply them in that order; the cost seam's
totality check reads `_deck_contents` and passes vacuously against an empty one. (vi) Golden Prediction
stays NONE but now ARGUES both premises -- no snapshot key (nothing ships under `src/state/`; guarded)
AND no seeded-RNG consumer (F2's two-site `shuffle_with_rng(` guard must still read two) -- and states
that the identity test's fixture is separate so the golden cannot move. (vii) Live Smoke for `3-0c` is
**NOT REQUIRED, for this story's own reason and not a borrowed one**: nothing in it is live-observable
-- no operator control, no Input Map action, no HUD or debug-panel surface, no visual or audible change,
no altered live-play behaviour. The smoke belongs to `3-0d`. `R-D6` is not re-invoked and stays
AVAILABLE. (viii) Dev Notes corrections, all verified by content: `log.gd` does NOT exist in
`src/systems/` (contents are `pool/`, `balance_config_service.gd`, `card_database.gd`, `event_bus.gd`,
`feature_flags_service.gd`, `invariant.gd`) -- the architecture tree lists a file that was never built;
that same tree labels THREE entries `# autoload:`, not four (`event_bus.gd` carries a D5 caption
instead); and the `3-5b/R19` quotation was paraphrased inside quote marks and is now quoted exactly.
(ix) The Change Log author field is left alone.

**AC hygiene and Open Questions.** The AC set is replaced with **FOURTEEN** machine-checkable claims
about shipped software; reasoning, sourcing and trade-offs moved to Dev Notes, which were ADDED TO --
all twelve original bullets survive, three of them corrected exactly as `3-0c/R11(viii)` requires. The
**Open Questions section is REMOVED**: of its seven items, five are ruled here (scope by `3-0c/R5` and
`3-0c/R10`; the initial `apply_balance` by `3-0c/R4`; DEBT B's live trigger by `3-0c/R5`;
replay-equality strength by `3-0c/R8`; placement by `3-0c/R9`) and three -- storage path/format, the
recording trigger and lifetime, and the operator control -- are re-homed to `3-0d`'s board note.
Nothing was left unruled, so the section is gone rather than left empty.

**Promotion.** All eleven rulings applied to `3-0c` the same session; Status and board promoted
`backlog` -> `ready-for-dev`, `sprint-status.yaml` updated alongside in the same commit together with
the new `3-0d-replay-surface-and-live-reload` board slot. Docs-only pass -- no code, no tests, no
`project.godot`, suite not run. Next story in the locked order after `3-0c`: `3-6`, with `3-0d`
sequenced at its own creation pass.

**Close-out.** Commit chain: `docs(stories): 3-0c gate fixes + promote to ready-for-dev` (the story file
and `sprint-status.yaml`) and this entry. No push -- the operator reviews the log and pushes.

---

## Session 2026-08-04 -- 3-0c close-out

Continues this story's label series (`3-0c/R1`..`R11` above) with rulings `3-0c/R12`..`R18`, recorded
after the dev pass (Claude Opus 5) landed and the commit chain (Claude Sonnet 5) verified and shipped
it. (`Claude Opus 4.8` is this repo's commit-trailer constant, carried on every `Co-Authored-By` line
in this project's history regardless of which model wrote the commit -- it is not a model name, and an
earlier pass at this entry conflated the two.) Verification this session: `HEAD` started at `48225c5`, `origin/main` at `ce30569`, 3 ahead / 0
behind (zero divergence in the direction that matters); no Godot process was found running before the
chain touched anything; the working tree matched the dev pass's expected 3-modified/5-untracked-.gd/
2-untracked-.uid set exactly; `project.godot`'s diff was EMPTY and its SHA256 matched the carried
constant `8879DE490EDDA78051595F189FB9BB6F2E75384FEBAFF142C8958EC107970004` exactly; the golden constant
in `test/state/test_determinism.gd` matched
`40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322` exactly, unchanged from the readiness
gate. One headless editor scan generated exactly the three remaining `.uid` files owed by the three
`.gd` files the dev pass's own early scan had not covered
(`test/state/test_intent_recorder.gd.uid`, `test/state/test_replay_identity.gd.uid`,
`test/integration/test_replay_contacts.gd.uid`) -- five `.uid` total across the story, one per new
`.gd` file, and nothing else changed: `project.godot`'s diff stayed EMPTY after the scan and `git
status` showed zero collateral beyond the five `.uid` files themselves. State harness 310 tests / 1463
assertions / 0 failed -> **329 tests / 1715 assertions / 0 failed**, all 19 integration files PASS
individually (`test_replay_contacts.gd` added), zero `SCRIPT ERROR` / `Parse Error` / `INVARIANT
VIOLATED` lines, matching the dev pass's own recorded numbers exactly -- nothing was re-derived, only
verified. **Golden UNMOVED** across the whole story, measured identical before and after against the
same constant quoted above; both Golden Prediction premises held (no snapshot key reachable from
`src/systems/` or `src/controllers/`; F2's `shuffle_with_rng(` guard still reading exactly two sites).

**A gap this session's own predecessor session created and this session closes.** The dev pass reported
TEN mutation proofs verbally at hand-off, covering ACs 1, 4, 5/6, 6, 9, 11, 13, and 14 among others. NONE
of the ten left an artifact anywhere in the tree -- no mutation table, no restored-file record, nothing
the chain could check against the shipped code. The prior commit chain session ran its OWN ten mutations
instead and filed them under the story's "Dev Pass Record" heading as if the dev pass itself had produced
them -- a genuine measurement, but attributed to the wrong pass, and it left three ACs (9, 11, 14) with
NO recorded falling proof at all, because the chain's ten happened not to touch them. **A proof that
exists only in a chat report does not exist for this repo's purposes** -- the standing discipline (every
prior E1-E3 story's own mutation table) is that "this guard falls correctly" is a measurement, not a
report, and the previous session's silent substitution is exactly the failure that discipline exists to
catch. Fixed this session, by rebuilding rather than patching: the story's mutation table now carries a
PROVENANCE COLUMN and keeps two sets visibly separate rather than merged -- the dev pass's own ten as
reported (`REPORTED (dev pass; no tree artifact)`), and the chain's own ten as independently measured
(`MEASURED (chain)`). The three of the dev pass's ten that were the only reported proofs for AC 9, AC 11
and AC 14 were RE-RUN this session against the shipped code and now carry measured numbers
(`RE-DERIVED (chain)`): `player_state.gd` gaining an unclassified `_fourth_unhashed_thing` member falls
`test_unhashed_cross_tick_state_is_exactly_three_members` (1 failure, AC 11); replay mode no longer
suppressing `_gather_contact_facts` makes `test/integration/test_replay_contacts.gd` (run individually,
WITH `--script`) report `stripped_hits=1` in phase [C] where zero is required, while phase [B]'s
`far_hits == live_hits` check still holds (both measured `1`) -- `RESULT: FAIL` (AC 9); and
`InputMap.add_action(&"p1_replay_start")` called at runtime via a throwaway test-time probe, with
`project.godot` never touched, falls `test_shipped_input_map_action_set_is_exactly_pinned` (1 failure,
`project.godot` diff confirmed EMPTY, AC 14) -- all three matching the dev pass's report exactly. See the
Dev Pass Record for the full two-set table.

**`3-0c/R12` -- the D5 signal buffers are per-tick and the exclusion pin stands at THREE.**
`SignalQueue._pending` and the five `_queue: SignalQueue` references that hold it
(`match_state.gd`, `hero_state.gd`, `mana_pool.gd`, `orb_pool.gd`, `stamina_pool.gd`) were omitted from
the Dev Notes exclusion argument's list of per-tick transients; both are corrected into it in the Dev
Pass Record commit. The DRAIN CONTRACT is what keeps them per-tick rather than merely the fact that they
happen to be empty at snapshot time: the runner calls `MatchState.drain_signals()` after every
`advance()` (`match_runner.gd:589`), which drains `_queue` unconditionally every tick on the D5 timing
discipline, and no gameplay path reads `_pending` -- `drain()` is its only reader. `AC 11`'s pin
(`3-0c/R8`) is UNCHANGED by this addition: the D5 buffers were always per-tick, never a fourth
cross-tick exclusion: they just weren't NAMED in the prose. The pin stays at three
(`PlayerState.vulnerable_window`; the card containers' contents/order; `MatchState._camera_bases`), and
`test_unhashed_cross_tick_state_is_exactly_three_members` -- which classifies `signal_queue._pending`
and all five `_queue` members into the PER_TICK bucket by name -- was already correct; only the prose
in the story file lagged the test.

**`3-0c/R13` -- PERMANENT RITUAL CHANGE: a story that ships a new `class_name` cannot defer the editor
scan to the chain.** A new `class_name` (here, `IntentRecorder` and `ReplayController`) is unparseable
by other scripts until the global class cache registers it, so a dev pass that references its own new
class from a sibling file it also writes in the same pass needs the scan to run DURING the dev pass, not
after. That deviation from the prior "the chain runs the one editor scan" pattern is ACCEPTED and
becomes a PERMANENT RULE: the scan runs in the dev pass, with a MANDATORY COLLATERAL CHECK at that point
(`project.godot` SHA256 before/after, plus a per-diff classification of anything else the scan touched)
-- and the chain still runs its own scan afterward for whatever `.gd` files the dev pass added later in
the same pass. On this story the dev pass's early scan produced exactly TWO `.uid` files
(`src/systems/intent_recorder.gd.uid`, `src/controllers/replay_controller.gd.uid`) and ZERO collateral,
verified again independently by the chain's own scan this session (also zero collateral, `project.godot`
diff empty both times).

**`3-0c/R14` -- the intent tap's seat is RATIFIED AS DESIGN, not an implementation choice.** The seat
immediately before `advance()`, inside the ticking gate, is correct BECAUSE of 3-0b's pause-gate
reasoning: the pause gate samples every frame but advances only on ticking ones, so a tap at the "sample
step" (the seat the architecture doc's pre-code sketch draws, `3-0c/R10`) would record intents no tick
ever consumed and desync the stream from its own tick indices. The story text's Project Structure Notes
bullet named the wrong seat; corrected in the Dev Pass Record commit. The architecture doc's tick
pseudocode -- the same pre-code sketch `3-0c/R10` already stripped of authority -- becomes the
architecture-amendment queue's member, verified by content: the queue held NINE after `3-0c/R10`
(five at `3-4/R4`, a sixth at the 3-2 gate, a seventh at the 3-3 gate close-out, an eighth at `3-5/R9`,
a ninth at `3-0c/R10`), so this ruling appends the **TENTH**. `docs/game-architecture.md` is NOT edited
this pass -- the queue flushes at the E3 close-out, forcing point unchanged.

**`3-0c/R15` -- PERMANENT PRECEDENT: an `Invariant.check` guard is never proven by deliberately
triggering it.** A triggered `Invariant.check` prints `SCRIPT ERROR: Assertion failed` and the process
continues with exit 0 -- it routes through `assert()`, which is a no-op in a non-debug build and merely
logs in the harness's headless debug run -- and `run_all.sh` greps exactly those strings to detect a
genuine failure, so a deliberately triggered guard would either pollute the suite's output with a
false-looking failure or, worse, be silently indistinguishable from a real one. The ACCEPTED FORM,
already used by this story's own guards (`has_complete_match_start()`,
`test_a_record_missing_any_match_start_channel_is_malformed`) and now named as the standing pattern: a
PUBLIC PREDICATE tested in both directions (true when complete, false with each channel individually
missing, naming which) PLUS a source scan proving the predicate is actually wired into the seam
(`test_the_match_start_completeness_guard_is_wired_at_the_capture_seam`, which mutation c7 this session
proved falling).

**`3-0c/R16` -- the four story-text corrections landed in commit 2** (`docs(3-0c): dev pass record`):
the intent-tap seat (`3-0c/R14`); the D5 signal buffers omitted from the per-tick exclusion argument
(`3-0c/R12`); `HeroState.to_snapshot()`'s `TimingWindow` count corrected from "seven" to the eight
actually listed (`windup`/`active`/`recovery`/`chain`/`deflect`/`roll_iframe`/`roll_duration`/`stun`,
verified against `hero_state.gd:407-414`); and AC 2's non-default `card_mode` fixture value noted as
FIELD-SHAPE ONLY (`3-0c/R18` below). All four are ADDITIONS to existing Dev Notes / Project Structure
Notes prose -- every pre-existing bullet was checked line by line and survives.

**`3-0c/R17` -- AC 9's uncovered case is a NAMED LIMIT of the proof, not a debt.** The live-scene proof
(`test/integration/test_replay_contacts.gd`) establishes "the runner performed no overlap query" by its
only observable consequence -- a gathered fact reaching `push_contact` -- across three phases (live;
replayed out of reach; replayed in reach with the fact channel stripped). What that form does NOT cover:
a query whose result is discarded WITHOUT reaching `push_contact`. This is recorded as a named limit
because it is structurally unreachable in shipped code, not because it was deferred:
`_gather_contact_facts` is the sole caller of the overlap query and pushes everything it selects -- there
is no branch that computes a fact and drops it -- so the uncovered case could only ever waste a query's
time, never desync a replay by hiding a fact the live run acted on.

**`3-0c/R18` -- AC 2's non-default `card_mode` is field-shape only.** The round-trip fixture drives
`card_mode = Enums.ModeKind.PITCH` to prove the field captures and replays like every other field, not
as a sanction to resolve that mode. The non-`BASIC` `ModeKind` values remain guarded stubs, unreachable
in play, until E5; `cast_evaluator.gd`'s dispatch and `test_non_basic_modes_are_unreachable_in_e3`
(story 3-5a) are untouched by this story. Corrected into Dev Notes in commit 2.

**DEBT B's STREAM HALF IS NOW CLOSED.** The reload channel (AC 4) captures every `apply_balance()` call
by value and replay never reads `BalanceConfigService`, closing the half of DEBT B this story owed. The
CACHE half -- `ResourceLoader` `CACHE_MODE_IGNORE` and a live mid-match reload trigger -- remains open
and belongs to `3-0d`, per `3-0c/R5`; nothing in this story's shipped code narrows or widens that scope.

**Live Smoke NOT REQUIRED, and the reason is this story's own, not a borrowed one:** `3-0c` ships
nothing live-observable -- no operator control, no Input Map action, no HUD or debug-panel surface, no
visual or audible change, no altered live-play behaviour (the recorder is a passive tap; replay mode is
reachable only from a test). `R-D6` is not re-invoked and stays AVAILABLE. `docs/playtest-log.md` is
untouched.

**Board: done.** Next story in the locked order: `3-6`, with `3-0d-replay-surface-and-live-reload`
sequenced at its own creation pass, per `3-0c/R5`.

**Rebuild note.** This chain was REBUILT once, same session, same four commits, three defects fixed:
(1) the mutation table filed the chain's own ten mutations under the dev pass's heading as if the dev
pass had produced them, leaving AC 9/AC 11/AC 14 with no recorded falling proof at all -- fixed by the
two-set, provenance-tagged table described above, with those three re-derived and measured; (2) the
`Co-Authored-By` trailer used `Claude Sonnet 5` on two of the four commits where the repo-wide constant
`Claude Opus 4.8` belongs on every commit regardless of author, verified by content across this log's
own git history before applying it; (3) the dev pass model was misnamed `Claude Opus 4.8` -- the
trailer constant, not a model name -- and is corrected to `Claude Opus 5` throughout. The rebuild used
`git reset --soft` to the pre-3-0c-chain commit plus re-staging, never `rebase -i`. Old-vs-new diffing
confirmed commit 1 differs from its original by exactly the trailer line and commit 3 is byte-identical
in content to its original; commit 2 and this entry carry the substantive fixes.

**Close-out.** Commit chain: `story 3-0c: intent recorder -- the X5 record/replay stream contract`
(`1fc54a5`, code, tests, five `.uid` siblings -- `project.godot` untouched; content identical to the
superseded `8d6bdc6` except the trailer), `docs(3-0c): dev pass record` (`51c249c`, the story's own Dev
Pass Record with the provenance-tagged mutation table and the corrected dev pass model, plus the four
story-text corrections; supersedes `4a6b055`), `board: promote 3-0c-intent-recorder to done (review
passed)` (`083ec92`, content identical to the superseded `dc90a02`), and this entry (supersedes
`00f3853`). No push -- the operator reviews the log and pushes.

---

## Session 2026-08-05 -- Story 3-0d readiness gate

Readiness gate on `docs/implementation-artifacts/3-0d-replay-surface-and-live-reload.md` (authored the
previous day at its own creation pass, commit `db38a0e`, per `E3-P/R3` and `3-0c/R5`) returned **NOT
READY** with **FIVE blocking findings**. All five were resolved the same session by twelve operator
rulings, applied to the story file in this pass. This is the **TWENTY-FIRST logged readiness-gate
session; all twenty-one returned NOT READY on first reading and all twenty-one were resolved the same
session.** The gate report itself lives in the browser session; this entry is the record of the OUTCOME
and the RULINGS, not a transcription of the findings.

**Verification before anything was edited.** `HEAD` `db38a0e`, working tree clean; `origin/main`
`bb2a58c` (`db38a0e`'s parent -- behind by one, no divergence, no fetch and no push); no Godot process
running. Every ruling below that rests on a fact about shipped code was RE-VERIFIED BY CONTENT in this
pass rather than taken on report, and one premise came back inaccurate and is corrected in place
(`3-0d/R6`) rather than silently applied. One ruling's premise was additionally verified by MEASUREMENT
against the engine rather than by reading (`3-0d/R5`). Docs-only pass: nothing under `src/`, `test/` or
`project.godot` is touched and the suite is deliberately NOT run. **AC count 9 -> 11. Status promoted
`backlog` -> `ready-for-dev`.**

**`3-0d/R1` -- THERE IS NO START CONTROL; RECORDING IS ALWAYS-ON FROM TICK 0.** *The gate found:* ACs 5
and 6 contracted a mid-match "start recording" control that cannot ship.
`IntentRecorder.capture_advance()` asserts `has_complete_match_start()` on its first captured tick
(`intent_recorder.gd:161-166`), requiring five match-start channels -- seed, reload event #0, feature
flags, deck composition, cast costs -- all of which are captured only inside the runner's `_ready()`,
each behind `if not replaying` (`match_runner.gd:115, 132, 144, 165, 171`). A start that discards the
record mid-match leaves all five empty and trips the invariant on the very next tick. *Ruled:* recording
is IMPLICIT AND ALWAYS-ON from tick 0. Verified by content: the runner already calls
`_recorder.capture_advance(intents)` on every ticking frame in the non-replay (`else`) branch
(`match_runner.gd:566`), and `_recorder` is never reassigned. *Why, and this is the load-bearing half:*
even a start that somehow re-captured the five channels would be pointless, because **a replay is built
from `MatchState.new()` forward and no state-restore snapshot exists anywhere** -- a record beginning at
tick 500 has nothing to replay. **A mid-match start is not forbidden, it is meaningless.** AC 5 is
reformulated as new AC 6: the record covers the match from tick 0 and is never restarted mid-match, with
the SAVE control (`3-0d/R2`) explicitly not interrupting it.

**`3-0d/R2` -- LOAD IS NOT A LIVE CONTROL; THE PANEL GAINS EXACTLY ONE CONTROL, SAVE.** *The gate
found:* AC 6's "load" control has no correct runtime path, **and the story's stated reason for thinking
it harmless was itself false.** The story claimed `replay_record` is read only in `_ready()`. Verified by
content, it is read in TWO places: `_ready()` (lines 105-108, 113, 128, 140, 161) AND every tick in
`_physics_process`, at the `if replay_record != null` fork (lines 536-540), which drives
`replay_apply_reloads_before` / `replay_push_camera_bases` / `replay_push_contacts`. Assigning it
mid-session is therefore not inert: it **injects tick-1 recorded reloads, camera bases and contacts into
a live mid-match state while both controllers are still live keyboards**, and it **silently stops
recording**, because `capture_advance` lives in the `else` branch the fork now skips. The naive
implementation looks harmless and corrupts the running match. *Ruled:* the `DebugInstrumentPanel` gains
**EXACTLY ONE new control: SAVE** -- write the record so far to `user://`, recording continues
afterwards. A scene-reload mechanism was CONSIDERED AND REJECTED: it is new architecture, and it collides
with the scope line "record + replay only -- no rewind, no scrubbing UI" already ratified as a decision
by `3-0c/R10`. Landed as AC 7, with a structural test counting the panel's runner-reaching controls at
exactly one so a load control cannot be added back quietly.

**`3-0d/R3` -- THE PAYOFF MOVES TO A HEADLESS VERIFIER UNDER `test/`.** *Ruled:* a standalone script,
`test/tools/replay_file.gd`, runnable as `godot --headless --path . --script
res://test/tools/replay_file.gd -- <path>`, which loads a record from `user://` and replays it. The form
is the repo's own working pattern, verified by content: every standalone script in `test/integration/` is
`extends SceneTree` with an `_initialize()` entry point (`test_replay_contacts.gd:1,65`, its header
documenting the invocation at line 33), run by `test/run_all.sh:27` in exactly that shape. **Living in
test space is what legitimately gives it `CanonicalHash`.** *Consequence recorded:* the Input Map pin's
assertion message -- "replay reachable only from a test, never from a key"
(`test/state/test_deck_and_hand.gd:451-452`) -- **stays TRUE after this story**, so the non-blocking gate
finding about that message rotting is **DISSOLVED, not deferred**. Noted alongside: `run_all.sh:24` globs
`test/integration/test_*.gd`, so a file under `test/tools/` is deliberately not auto-run -- correct for
an operator tool whose input is a file the operator produced by playing, and the reason AC 8's
regression coverage is AC 4's in-suite round-trip test rather than the verifier itself. Landed as AC 8.

**`3-0d/R4` -- THE LIVE SMOKE'S PAYOFF IS REFORMULATED TO WHAT IS ACTUALLY PROVABLE.** *The gate found:*
the smoke's payoff step could not be performed. It depended on `3-0d/R2`'s rejected load control, and
`CanonicalHash` is `test/canonical_hash.gd` -- a test-harness class. Verified by content: **nothing under
`src/` computes or displays a canonical hash**; the only two `CanonicalHash` occurrences in `src/` are
prose inside comments (`discard_pile.gd:9`, `match_state.gd:137`). The old step asked an operator at the
game to confirm something the game does not and will not display. *Ruled:* the smoke payoff becomes what
AC 4 does NOT cover -- **a record produced by a REAL PLAYED ROUND (not a synthetic fixture) exists on
disk, is structurally complete, and replays headlessly to completion and TWICE to the same hash.** AC 4
proves round-trip FIDELITY on a fixture; the smoke proves the LIVE RUNNER emits a well-formed file.
Different claims; neither subsumes the other.

**`3-0d/R5` -- AC 1 PROVES THE CACHE BYPASS BY OBJECT IDENTITY, NOT BY MUTATING A TRACKED FILE.** *The
gate found:* AC 1 forced a permanent test to mutate `data/balance/balance_config.tres`. `CONFIG_PATH` is
a hardcoded `const` with no path seam (`balance_config_service.gd:13`), the file is tracked, and other
tests read it -- `test/integration/test_contact_pipeline.gd:73` and
`test/state/test_balance_authoring.gd:37` among them. That collides with the **PERMANENT RULE at
decision-log:799** ("a mutation made to prove a guard non-vacuous is restored from a copy taken OUTSIDE
the repo, NEVER with `git checkout -- <file>`") and is strictly worse than the case that rule was written
for: a permanently re-running test has no restore step at all. *Ruled:* the proof is REFERENCE IDENTITY
-- `CACHE_MODE_IGNORE` returns a fresh instance, plain `load()` returns the same cached one, so two
consecutive `reload()` calls must yield DIFFERENT references with EQUAL values. **Semantics MEASURED
against the engine before the AC was written**, per the ruling's own instruction (Godot 4.6.3, the
shipped `.tres`): plain `load()` twice -> same instance; `CACHE_MODE_IGNORE` twice -> different
instances, equal values; `CACHE_MODE_IGNORE` vs the cached instance -> different. The semantics hold.
Zero file mutation, zero new API on the autoload. **The test goes in the STATE harness, not
integration**: `test/state/test_balance_config.gd:88-89` already instantiates the service SCRIPT as a
plain `Node` and calls `reload()` on it, so no autoload is required. *Correction of record folded in
here:* the story's claim that "`reload()` has exactly ONE caller in the whole tree" is FALSE -- it has
two, its own `_ready()` and that same `test_balance_config.gd:89`. The claim was **inherited verbatim
from the CLOSED story file `3-0c-intent-recorder.md:174`**, where it is equally wrong. That file is
closed and is NOT edited; the inheritance is recorded in `3-0d`'s Dev Notes. The error was load-bearing:
it is what made the old AC 1 reach for a file mutation, on the false premise that the state harness
could not reach the service.

**`3-0d/R6` -- AC 9 GETS A REAL SOURCE-SCAN PIN, AND THE RULING'S OWN PHRASING IS CORRECTED.** *The gate
found:* AC 9 was a process promise with no falsifying mechanism. The tap seat is correctly described,
but no test pins it -- every `capture_advance` hit in `test/` drives a recorder directly
(`test_intent_recorder.gd:117`, `test_replay_identity.gd:359`, `test_replay_contacts.gd:118`), so moving
the runner's call would break nothing. The one existing wiring scan
(`test_the_match_start_completeness_guard_is_wired_at_the_capture_seam`, `test_intent_recorder.gd:230`)
targets `intent_recorder.gd`, not `match_runner.gd`. *Ruled:* a source scan asserting `capture_advance`
is called in `match_runner.gd` inside the ticking branch immediately before `advance(`, plus a scan of
`replay_record`'s assignment -- the single structural trace `3-0d/R2` leaves in the code. **Correction of
record, and the reason this ruling is not encoded verbatim:** the ruling as issued said the scan asserts
`replay_record` is "assigned ONLY in `_ready()`". The tree contradicts that -- there is no assignment in
`_ready()` at all; `_ready()` READS it. Measured by content, `replay_record` appears in `src/` only as
its declaration (`match_runner.gd:69`) and as reads, and its one assignment in the whole tree is external
and pre-tree (`test/integration/test_replay_contacts.gd:80`). The ruling's SUBSTANCE is unaffected and
the accurate scan is STRICTER: **`replay_record` is assigned NOWHERE in `src/`.** Landed in that form as
AC 11, with the correction stated in the AC itself.

**`3-0d/R7` -- THE ON-DISK FORMAT STAYS UNPINNED EXCEPT FOR A VERSION INT.** Closes the story's open
question (b) on whether the format should be pinned by an AC at all. *Ruled:* it stays unpinned --
freezing byte layout, key naming or extension would fix a shape with exactly one consumer today, and the
falsifiable claim worth having is the ROUND TRIP (AC 4). **One mandatory element: a format version int,
with a clear refusal on mismatch**, which is what makes schema evolution safe without pinning the schema.
Landed as new AC 5, falsifiable in both directions (a matching version loads; a rewritten one is refused
with a reason).

**`3-0d/R8` -- LOADING AN OLD RECORD AGAINST A CHANGED `CardDatabase` IS CLOSED BY CONSTRUCTION.** Closes
the story's open question (d). Verified against the code: a replay drives the INJECTED deck composition
and the INJECTED cost map and never reads `CardDatabase` -- the `_derive_*` helpers that touch the
autoload (`match_runner.gd:296-303` and its deck counterpart) sit inside the `else` (non-replaying)
branch of `_ready()` (lines 163-172), and `intent_recorder.gd`'s header states the recorder is
"CONTENT-BLIND BY CONSTRUCTION: ... no `CardDatabase`". A card re-priced or deleted after a recording
cannot change what the replay pays or draws. The version field (`3-0d/R7`) covers schema evolution.
Nothing further to detect or refuse.

**`3-0d/R9` -- A DEBUG RESET DOES NOT BOUND A RECORDING.** Closes the story's open question (a). Verified
by content: reset is ROUND-scoped, not match-scoped -- `_apply_debug_reset()`
(`match_state.gd:1166-1169`) clears `_round_over` and resets both players, reached from inside
`advance()` (`match_state.gd:175-176`) off the `debug_reset` field of an ordinary `InputIntent`, which is
one of the eight fields captured verbatim per tick (`intent_recorder.gd:336`). **A record spans a reset
intact**, as ordinary ticks -- no recording boundary, no special case, nothing for AC 6 to carve out.

**`3-0d/R10` -- THE VISIBLE STAMINA REFILL ON A LIVE RELOAD IS RATIFIED AS CORRECT.** Closes the story's
open question (e). It is the per-pool `apply_balance` contract -- stamina `set_maximum` **and**
unconditional `refill()` on every apply (`match_state.gd:1116-1130`, comment naming
`test_mid_match_reload_refills_stamina_to_max`) -- becoming live-observable for the first time, because
every prior reload was either match-start (stamina already full) or headless. **Not a bug.** The smoke
observes it as EXPECTED rather than naming it as a finding. Changing it would be a change to
`apply_balance` SEMANTICS and needs its own story; this one does not open that question. The carve-out
prose is moved out of AC 7 (now AC 9) into Dev Notes.

**`3-0d/R11` -- R-D6 IS RE-INVOKED AND IS SPENT ON THIS STORY'S SMOKE.** Closes the story's open question
(c). Status going in, corrected by the creation pass and re-checked here: AVAILABLE, last spent `3-5a`
(decision-log:3191), not `3-4`. *Ruled:* re-invoked and SPENT. The smoke is live against the shipped two
killable human slots (`slot_controller_kinds = [KEYBOARD_P1, KEYBOARD_P2]`, `match_runner.gd:31-34`) and
already involves combat, so the kill is nearly free. **Recorded in the Live Smoke section as a REQUIRED
observation**, not an optional one. After this story R-D6 is spent again and any later story wanting a
live smoke against a killable human-driven slot must re-invoke it at its own gate (the standing rule,
decision-log:456/530).

**`3-0d/R12` -- ARCHITECTURE-AMENDMENT QUEUE GAINS AN ELEVENTH MEMBER.**
`docs/game-architecture.md:578-579` annotates `src/ui/debug/` with "record/replay start-stop-load" while
this story ships SAVE-only, with no load control and no start control (`3-0d/R2`). That is a genuine
divergence between the doc and shipped code. **Queue size counted by content at this gate rather than
taken from the prompt:** it held TEN -- five at `3-4/R4`, a sixth at the 3-2 gate, a seventh at the 3-3
gate close-out, an eighth at `3-5/R9`, a ninth at `3-0c/R10`, a tenth at `3-0c/R14`
(decision-log:3767-3769 and 3910-3913) -- so this is the **ELEVENTH**. `docs/game-architecture.md` is NOT
edited this pass; the queue flushes at the E3 close-out, forcing point unchanged.

**Non-blocking corrections applied.** (i) The pinned Input Map action set: the story said 28 (13 `p1_*`,
13 `p2_*`); **MEASURED at this gate from `SHIPPED_INPUT_ACTIONS` itself (`test_deck_and_hand.gd:428-436`)
it is 30** -- 2 `debug_*` + 14 `p1_*` + 14 `p2_*`, each player's fourteen being `attack`, `block`,
`card_1..4`, `cast_confirm`, `cast_mode`, `debug_reset`, `move_down/left/right/up`, `roll`. The gate's
measurement was right and the story's was wrong. (ii) The "`reload()` has exactly ONE caller" claim
corrected, with its inheritance from the closed `3-0c` file recorded rather than that file edited -- see
`3-0d/R5`. (iii) Three ACs carried "not decided here" carve-out prose (the format, the debug reset, the
stamina refill); each is moved into Dev Notes, and `3-0d/R7`/`R9`/`R10` now answer all three anyway.
(iv) Two drifted line-number citations re-anchored by locating the content: `3-0c/R5` sits at
decision-log **3682**-3699 (the story cited 3685, which points into the middle of the paragraph), and the
architecture's X5 toggle annotation spans **578**-579 (the story cited 579 alone, the line carrying the
"start-stop-load" phrase but not the annotation's opening). (v) Citation form generally: **line numbers
are NOT re-anchored wholesale** -- non-blocking on the repo's own precedent, and the story carries the
content alongside nearly every citation. Left as they are.

**The Open Questions section is REMOVED**, the precedent set by `3-0c`'s own fix pass
(decision-log:3807). All six are ruled: (a) by `3-0d/R9`, (b) by `3-0d/R7`, (c) by `3-0d/R11`, (d) by
`3-0d/R8`, (e) by `3-0d/R10`, (f) by `3-0d/R2`. Each ruling's substance survives in the AC or the Dev
Note that now owns it; nothing that was open vanished silently.

**Dev Notes discipline held, and it was tested.** Dev Notes are ADDED TO, never replaced -- the standing
lesson from an earlier fix pass on this project that deleted two bullets while "updating" them. All
FOURTEEN pre-existing bullets survive this pass. The three that the rulings falsified are **CORRECTED IN
PLACE with the correction visible** (struck original, then the measured replacement), none deleted: the
`reload()` caller count (`3-0d/R5`), the 28-action count, and the `replay_record`-read-once structural
gap (`3-0d/R2`). Ten new bullets were appended, one per ruling that needed rationale space.

**Golden Prediction unchanged: NONE.** Both premises stand; premise 1 is widened to name `test/tools/`
alongside `src/systems/`, `src/ui/debug/` and `src/main/match_runner.gd` as this story's surface.
Baseline `40eb5554...fa322`, unchanged.

**Gate verdict and base rate.** VERDICT: **NOT READY on first reading**, resolved the same session, story
promoted to `ready-for-dev` with 11 ACs. **The base rate is now 21 gates, 21 NOT READY on first
reading**, all 21 resolved in the session that found them.

**Close-out.** Two commits, neither pushed: `docs(stories): 3-0d gate fixes + promote to ready-for-dev`
(the story file plus `sprint-status.yaml` -- status and `story_notes` both moved to the ruled scope), and
this entry. Docs and code never share a commit; these are two separate docs commits. No push -- the
operator reviews the log and pushes.

## Session 2026-08-05 -- Story 3-0d, `3-0d/R13` panel reload control

**Preconditions verified before anything was touched.** `HEAD` `dfebbb0` (the dev pass's docs record);
working tree clean; `origin/main` `d45db42` -- two commits behind `HEAD`, expected (the dev pass at
`f5da20c` and its own docs record at `dfebbb0` are both unpushed); no Godot process running.

**The conflict this pass resolves, raised and deliberately NOT resolved by the dev pass at `f5da20c`.**
AC 7 pinned `DebugInstrumentPanel` at EXACTLY ONE new runner-reaching control, SAVE, with a structural
test (`test_replay_surface_pins.gd::test_the_panel_has_exactly_one_runner_reaching_control`) counting
runner-reaching controls at one. The story's own Live Smoke section asks the operator to "trigger a live
mid-match balance reload from the panel" -- which needs a SECOND such control. `match_runner.gd::
trigger_live_balance_reload()` therefore shipped with tests and a source scan but NO operator surface,
and the dev pass recorded this in the story's Dev Agent Record rather than build past it: "AC 7 pins the
panel at EXACTLY ONE new control (SAVE)... while the Live Smoke asks the operator to trigger a live
mid-match balance reload from the panel... This needs an operator ruling before the smoke runs."

**`3-0d/R13` -- THE PANEL GAINS A SECOND CONTROL, RELOAD; AC 7 IS REFORMULATED FROM A COUNT INTO AN
EXACT SET.** *Ruled:* the panel ships a second runner-reaching control, RELOAD, wired to the existing
`trigger_live_balance_reload()` call site (no new runner-side trigger logic -- that call site shipped
already, exercised by `test/state/test_live_reload.gd` and pinned by its own source scan). *The
reasoning, which is the point of this ruling:* AC 7's original "exactly one" was never protecting a
COUNT -- it was protecting against a LOAD control (`3-0d/R2`, the readiness gate). What must stay
impossible is ENTERING REPLAY mid-session, and that is carried STRUCTURALLY by AC 11's second scan --
`replay_record` is assigned NOWHERE in `src/` -- which is stronger than counting buttons: it holds
regardless of how many buttons the panel carries, because a load control's defining, catchable property
is the assignment itself, not its presence as a third control. Without an operator-reachable reload
trigger the live path is unreachable code in the shipped game and the story's own premise -- tuning
balance without a restart -- does not land. AC 7 is therefore reformulated from a COUNT into an EXACT
SET, the same shape this repo already uses for the Input Map pin
(`test_shipped_input_map_action_set_is_exactly_pinned`): the panel's runner-reaching controls are EXACTLY
`{SaveRecord, ReloadBalance}` and nothing else. A third -- a load control in particular -- still fails
it, proven by mutation below.

**What was built.** `src/ui/debug/debug_instrument_panel.gd` gains a second runner-owned `Callable`,
`reload_balance`, the same shape as `save_record` (`3-0d/R2`'s "the panel receives a way to ASK, never a
state handle" precedent, generalised to two): a `Button` named `ReloadBalance`, stacked below
`SaveRecord` in the existing third column (`RecordControls`), wired `pressed.connect(_on_reload_pressed)`
which calls `reload_balance.call()` if valid. `src/main/match_runner.gd` hands the panel
`panel.reload_balance = trigger_live_balance_reload` alongside the existing `panel.save_record =
save_recorded_stream`, before `add_child`. No new Input Map action; both controls stay mouse-only.

**Layout measured, not assumed.** A throwaway script (`test/tools/measure_panel_layout_throwaway.gd`,
run once headlessly against `main.tscn` at the shipped 1152x648, then deleted) printed the box's actual
global rect and both columns' combined minimum sizes: box `global_rect=[P: (276, 356), S: (600, 94)]`
(unchanged from the 3-0b re-fit's x[276,876] y[356,450]), box `combined_minimum_size=(423, 89)` --
LESS than the box's actual size, so nothing overflowed -- `RecordControls` (now two stacked buttons)
`min_size=(126, 64)`, and `Switches` (the existing two-`CheckButton` column) `min_size=(272, 64)`: the
two columns land on the SAME 64px minimum height, well inside the 94px band. `test_debug_instruments.gd`'s
S1/S2 layout guard (the panel's global rect must lie inside the window and intersect no HUD/StateInspector
rect) passed UNMOVED, verifying the re-fit rather than assuming it.

**Tests amended.** `test/state/test_replay_surface_pins.gd`'s AC 7 pin
(`test_the_panel_has_exactly_one_runner_reaching_control` -> renamed
`test_the_panel_has_exactly_the_two_runner_reaching_controls`) now asserts the panel's Callable members
sort to EXACTLY `["reload_balance", "save_record"]`, NO signal at all, and its wired control handlers that
reach either Callable sort to EXACTLY `["_on_reload_pressed", "_on_save_pressed"]`. Its docstring states
in its own text that AC 11's `replay_record` scan, not this pin's control count, is what actually keeps a
load control out (`3-0d/R13`). AC 11 itself (`test_the_intent_tap_stays_seated_immediately_before_advance`,
`test_replay_record_is_assigned_nowhere_in_src`) required ZERO edits.
`test/integration/test_record_save_control.gd`'s scene-level control-set assertion is amended from the
three-name set to `["NormalizeMagnitude", "PitchZoneLeftOfBars", "ReloadBalance", "SaveRecord"]`, and
extended with a live proof that RELOAD reaches the trigger in the LIVE scene: a real roll
(`p1_move_up` + `p1_roll`) spends P1's stamina from 50 to 38 (`roll_stamina_cost` 12 off the authored
`max_stamina` 50), well inside `stamina_regen_delay_seconds` (0.8s / 48 ticks) so no natural regen can
explain what follows; pressing `ReloadBalance` via the panel's own real-signal test pattern (`button.
pressed.emit()`) is then observed, through the StateInspector's own primed `STAMValue` label (no runner-
private access), refilling to 50/50, and the runner's `recorded_stream().reload_event_count()` is
observed going 1 -> 2. Machine output: `reload control: stamina=38/50->50/50 reload_events=1->2`.

**Mutation proof (`3-0d/R13`'s own, distinct from the dev pass's six).** A third runner-reaching control
was added to `debug_instrument_panel.gd` -- a `load_record: Callable` member, a `LoadRecord` button, and
an `_on_load_pressed()` handler calling it: the rejected LOAD control, in the exact shape `3-0d/R2`
describes. Both guards went RED: `test_replay_surface_pins.gd::
test_the_panel_has_exactly_the_two_runner_reaching_controls` (`callables` grew to
`["load_record", "reload_balance", "save_record"]`, failing the exact-set equality) and
`test_record_save_control.gd`'s control-set check (`got ["LoadRecord", "NormalizeMagnitude",
"PitchZoneLeftOfBars", "ReloadBalance", "SaveRecord"]`). Restored from a copy taken OUTSIDE the repo
(the scratchpad, never `git checkout --`), verified identical by SHA-256 before and after:
`0f92fb59fc24c97d3152665134e6b671196bfcaf0aecc1c3f180d5af7153b49a`.

**Suite, before and after.** Baseline verified before any edit (working tree stashed to `dfebbb0`, run,
then restored): **344 state tests / 2197 assertions / 20 integration files, ALL PASSED.** After this
pass: **344 / 2198 / 20, ALL PASSED** -- +1 assertion (the AC 7 pin's handler-membership check grew from
one `assert_true` to a two-iteration loop), 0 new tests, 0 new integration files (an existing integration
file was amended, not added). The four inherited `3-0c` pins (`test_architecture_invariants.gd`,
`test_replay_identity.gd`, `test_intent_recorder.gd`, `test_deck_and_hand.gd`) required ZERO edits,
confirmed by `git status`. `project.godot` is BYTE-IDENTICAL, SHA-256
`8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004` both ends. The golden did not move:
`test_determinism.gd` is absent from `git status` and its `GOLDEN` constant is unchanged,
`40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`.

**Close-out.** Three commits, none pushed: `feat(x5): panel reload control (3-0d/R13)` (the panel
control, the runner wiring, the amended pins, the extended integration test -- code and tests only),
`docs(3-0d): AC 7 amended to an exact control set (3-0d/R13)` (the story file: AC 7 rewritten, Dev Agent
Record updated, a 0.4 Change Log row -- the raised conflict marked RESOLVED, not deleted), and this
entry, a PURE APPEND. Docs and code never share a commit. No push -- the operator reviews the log and
pushes.

## Session 2026-08-05 -- Story 3-0d post-review fix pass, `3-0d/R14`-`3-0d/R19`

**Preconditions verified before anything was touched.** `HEAD` `d433b41` (the `3-0d/R13` follow-up
pass's decision-log record); working tree clean; `origin/main` `d45db42` -- FIVE commits behind
`HEAD`, expected, none of the five pushed; no Godot process running. No fetch, no push.

**The verdict.** A code review of story 3-0d returned **CHANGES REQUIRED**: one BLOCKING finding and
five non-blocking. All six are ruled and closed here. The blocking one is the interesting one, and it
is not really about this story.

### B1, BLOCKING -- both of this story's new source scans could be evaded, and the mutation proofs that "proved" them caught nothing

`test/state/test_replay_surface_pins.gd` shipped two source scans, each with a self-check and each
with a mutation proof recorded in the story's Dev Agent Record. The review broke BOTH without either
going red.

The `replay_record` scan (AC 11 half (b)) matched `\breplay_record\s*=[^=]` -- an assignment is the
token followed by a bare `=`. Verified by the review: `set("replay_record", rec)`,
`set_deferred("replay_record", rec)` and `runner[&"replay_record"] = rec` ALL PASS, and worse, all
three were tallied as harmless READS. The panel Callable scan (AC 7) matched
`^var\s+\w+\s*:\s*Callable`, so `var load_record := Callable()` -- the idiomatic INFERRED form, the
one a developer is most likely to type -- did not match at all. A load control written in those forms
passed BOTH pins. The residue the review correctly noted: the scene-level Button-name set in
`test/integration/test_record_save_control.gd` still catches a third BUTTON (CheckButton subclasses
Button), so what actually got through is a load path that is not a button.

**`3-0d/R14` part 1 -- INVERT THE `replay_record` SCAN INTO A WHITELIST.** *Ruled and done.* Every
occurrence of the token in `src/` must now classify as one of an explicitly enumerated set of ALLOWED
READ FORMS -- the declaration, a null comparison, a member read, or a read passed as an argument --
and anything else is an offender, reported with its file, line and text. An assignment through
`set()`, `set_deferred()`, an indexed property write, or any form nobody has thought of yet fails
**by DEFAULT rather than by enumeration**. The classification is per-OCCURRENCE, not per-line, so a
line that both reads and writes cannot hide the write behind the read; an occurrence sitting inside a
string literal (which is what all three evasions are) is refused on that basis alone. The allowed set
is DERIVED from the shipped tree -- the test asserts each of the four forms actually occurs in
`src/`, so an allowed form nothing uses is caught as an unchecked hole -- and no line count is
hard-coded.

**`3-0d/R14` part 2 -- THE PANEL CALLABLE SCAN MATCHES ANY DECLARATION FORM.** *Ruled and done.* Not
two enumerated patterns: a member counts if its top-level `var` declaration CARRIES `Callable` at all
(annotated `: Callable`, inferred `:= Callable(`, untyped `= Callable()`, any combination) OR if the
file goes on to INVOKE it as a Callable, which closes the one remaining shape -- a member declared
with no type and assigned later, carrying the word `Callable` on no line at all.

**`3-0d/R14` part 3 -- THE PERMANENT LESSON, and it is the reason this ruling is in the log at all.**
**A pattern guard's non-vacuity check must be proven against THE FORMS AN ADVERSARY WOULD USE, not
only the form the author happened to write, and a mutation proof performed in the author's own syntax
proves ONLY that syntax.** Both scans here shipped with self-checks and with mutation proofs and both
were still evadable, and the cause was identical in both cases: the author broke the guard the way
the author was thinking about breaking it. A guard that enumerates what is FORBIDDEN is only ever as
good as the imagination of whoever wrote the enumeration; a guard that enumerates what is ALLOWED and
refuses the rest by default is bounded by the code it guards instead. **This binds every future
pattern guard in this repo, not just these two.** Concretely, from now on: (a) prefer a whitelist to a
blacklist wherever the allowed set is derivable from shipped code; (b) every pattern guard's
non-vacuity check must assert the EVASION FORMS ARE CAUGHT alongside the legitimate forms being
SPARED; (c) a mutation proof in the author's own syntax does not discharge a guard whose evasion
forms have not been tried.

**`3-0d/R14` part 4 -- REDO THE MUTATION PROOFS IN THE EVASION FORMS.** *Ruled and done.* Four
proofs, each applied, observed RED, then restored FROM A COPY TAKEN OUTSIDE THE REPO (the scratchpad
-- never `git checkout --`, the PERMANENT RULE at decision-log:799), SHA-256 verified identical
before and after: `match_runner.gd`
`cdc452aaf802529587d6449d7a64cccfad917f55a2e5a8f7f09e88f77e61cc5d`, `debug_instrument_panel.gd`
`0f92fb59fc24c97d3152665134e6b671196bfcaf0aecc1c3f180d5af7153b49a`; `git status` afterwards confirms
neither file is modified. (1) `set("replay_record", rec)` -> `test_replay_record_is_assigned_
nowhere_in_src` RED, `got 1, expected 0 ... res://src/main/match_runner.gd:661
set("replay_record", rec)`. (2) `set_deferred("replay_record", rec)` -> same test RED,
`... match_runner.gd:660`. (3) `runner[&"replay_record"] = rec` -> same test RED,
`... match_runner.gd:661`. (4) `var load_record := Callable()` plus a `LoadRecord` button and
`_on_load_pressed()` -> BOTH `test_the_panel_has_exactly_the_two_runner_reaching_controls`
(`got ["load_record", "reload_balance", "save_record"]`) AND `test_record_save_control.gd`'s
control-set check (`got ["LoadRecord", "NormalizeMagnitude", "PitchZoneLeftOfBars", "ReloadBalance",
"SaveRecord"]`) RED. Every one of 1-3 passed the OLD scan as a read; 4 passed the OLD panel scan
unseen. That contrast is the whole content of `R14`.

### The five non-blocking findings

**`3-0d/N2` / `3-0d/R15` -- A REFUSAL WITH NO REASON, CONTRADICTING THE CLASS'S OWN CONTRACT.**
`RecordFile.load_record` returned `{"record": null, "error": ""}` on a versioned-but-truncated file:
the version check passed, `_from_dictionary()` was reached, it failed inside on a missing key, and
the result came back with an EMPTY error -- which a caller testing `error != ""` reads as SUCCESS,
while the class's own docstring says the reason always travels with the failure. *Ruled:* validate
the required keys BEFORE rebuilding and return a reason NAMING what is missing. Done, as
`RecordFile.REQUIRED_KEYS`, checked after the version (the version is what decides which key set is
even expected, so a future version 2 is refused earlier and never reaches this). Tests added for the
truncated file AND for the previously untested no-version-key branch, plus a DERIVATION GUARD
asserting `REQUIRED_KEYS` equals the key set an actual saved file carries minus `format_version`, so
a channel added to the writer without being added here fails loudly instead of leaving the truncation
check silently blind to it.

**`3-0d/N3` / `3-0d/R16` -- THE `user://` CLAIM WAS TRUE OF `path_for()` AND OF NOTHING ELSE.**
`save_record` accepted any path, and the review proved it by writing a record into the repo root.
*Ruled:* a path that does not begin with `user://` is REFUSED with a reason. Done and tested,
including that nothing is written; proven again on the live class during this pass ("refusing to
write post_review.rec -- records go under user://, never into the project tree"), with the repo root
confirmed clean afterwards. This and `N2` are the same shape of defect and worth naming as one: **a
property asserted in prose and carried by a CONVENTION rather than by the API holds exactly until the
first caller that does not follow the convention.** Neither changes the on-disk format, so
`FORMAT_VERSION` stays at 1 -- these are refusal paths, not shape changes (`3-0d/R7` stands).

**`3-0d/N4` / `3-0d/R17` -- THE VERIFIER'S REPLAY ORDERING WAS A THIRD UNGUARDED TRANSCRIPTION.** The
replay drive order lived in three places -- the runner's live fork (`match_runner.gd:601-608`, the
original), AC 4's in-suite round-trip test, and AC 8's headless verifier -- and nothing guarded the
third: AC 4 proved the SAVE/LOAD path, never the verifier's ordering, so the verifier could have
drifted from the runner and printed a stable but WRONG hash indefinitely. *Ruled:* extract the drive
order into ONE helper under `test/`, used by both test-side callers, and correct the Dev Notes claim
that AC 4 already covered it. Done, as `test/replay_drive.gd` (`class_name ReplayDrive`, the one new
`class_name` this pass ships; editor scan run and `.uid` committed), a library beside
`test/canonical_hash.gd` and globbed by neither harness. **The runner's own fork is deliberately NOT
folded in and could not be** -- it is `src/` code inside `_physics_process` and `src/` cannot depend
on `test/` -- so it stays the ORIGINAL, named in the helper's docstring so a change there has
somewhere to point. **Neither caller was weakened:** the one thing that can legitimately go wrong (an
unsound recorded content order, `3-0c/R11`) travels back as a reason in a result Dictionary, the same
shape `RecordFile.load_record` uses; the test asserts on it, the operator tool prints `REFUSED:` and
exits 1, which replaces an `Invariant.check` crash and is strictly better for an operator tool. **A
finding this pass produced rather than received, worth its own line:** running the extracted verifier
for real caught a parse error (a shadowed `result` local) that the suite structurally CANNOT see,
because `test/tools/replay_file.gd` is deliberately not globbed by `run_all.sh`. **A tool that lives
outside the suite must be RUN as part of any pass that edits it.**

**`3-0d/N5` / `3-0d/R18` -- THE AC 8 HASH IS EXPLAINED, NOT A DEFECT.** The Dev Agent Record's
`5f465e7a...9d13` was not reproducible at the review, which measured `d2f77f3e...92d0` from
byte-identical record files across two sessions. *Ruled: this is an explanation, not a finding
against the code.* The dev pass's producer script PRESSED inputs (`p1_move_up`, `p1_attack`); the
review's pressed none. Different intents, different final `MatchState`, different `CanonicalHash` --
correctly. **AC 8's actual claim -- the same file replays to the same hash, twice -- HOLDS**, and was
re-measured holding at this pass (`74cbe99b...931f` twice from this pass's own producer, itself not
comparable to either earlier number). **Why the discrepancy was invisible, which is the part worth
recording:** the verifier's summary line prints ticks / reload_events / seed / deck / costs / order /
camera_pushes / contact_facts and NOTHING ABOUT THE INTENTS, so two records differing ONLY in what
was pressed print identical summaries and different hashes. The story record now says the hash is a
function of the run that produced it, not a repo constant, and says why.

**`3-0d/N1` / `3-0d/R19` -- TWO PASSAGES LEFT CONTRADICTING THE AMENDED AC 7.** The `3-0d/R13`
amendment reformulated AC 7 from a COUNT into an EXACT SET, but Project Structure Notes still said
the panel "gains EXACTLY ONE new control, SAVE", and a Dev Notes bullet still said the structural
test COUNTS runner-reaching controls and that this is what keeps a load control out. Both are false
about shipped code, and the second was already the exact error `3-0d/R13` ruled on -- a control count
was never what keeps a load control out; AC 11's `replay_record` scan is. *Ruled:* correct both in
place with the correction VISIBLE (struck through, not deleted -- the repo's standing discipline for
a falsified claim). Done. The 0.3 Change Log row is HISTORICAL and stays untouched.

**Suite, before and after.** Baseline verified at `HEAD` `d433b41` with a clean tree before any edit:
**344 state tests / 2198 assertions / 20 integration files, ALL PASSED.** After this pass: **348 /
2244 / 20, ALL PASSED** -- +4 state tests and +46 assertions, 0 new integration files. The +4 are
`R15`/`R16`'s new refusal tests (truncated file; no-version-key branch; save outside `user://`; the
`REQUIRED_KEYS` derivation guard); the assertions are those plus the two hardened scans' evasion-form
self-checks. Re-run green a third time after all four mutations were restored. `project.godot` is
BYTE-IDENTICAL, SHA-256 `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`, both
ends. The golden did not move: `test_determinism.gd` is absent from `git status` and its `GOLDEN`
constant still reads `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`. The four
inherited `3-0c` pins required ZERO edits. `src/main/match_runner.gd` and
`src/ui/debug/debug_instrument_panel.gd` are UNMODIFIED by this pass -- mutation targets only,
restored and hash-verified. The live smoke was NOT run: it is the operator's and carries the required
R-D6 kill (`3-0d/R11`).

**Close-out.** Three commits, none pushed: `fix(x5): harden the 3-0d source scans and record refusal
paths (3-0d/R14-R17)` (code and tests), `docs(3-0d): post-review corrections (3-0d/R14-R19)` (the
story file: the AC amendments, the two corrected passages, the extended Dev Agent Record with the
corrected AC 8 hash note, a 0.5 Change Log row), and this entry, a PURE APPEND -- no existing entry
edited. Docs and code never share a commit. The board is not touched. No push -- the operator reviews
the log and pushes.


## Session 2026-08-05 -- Story 3-0d structural fix pass, `3-0d/R20`-`3-0d/R24`

**Preconditions verified before anything was touched.** `HEAD` `a6582e8` (the post-review pass's
decision-log record); working tree clean; `origin/main` `d45db42` -- EIGHT commits behind `HEAD`,
expected, none of the eight pushed; no Godot process running. No fetch, no push. The stated suite
baseline was not taken on trust either: **348 state tests / 2244 assertions / 20 integration files,
ALL PASSED**, measured at that `HEAD` with a clean tree before the first edit.

**The verdict.** This is the THIRD round on the same two source scans, and it ends them.

### `3-0d/R20` -- A TEXT SCAN OVER SOURCE CANNOT CARRY A DESIGN INVARIANT, AND THIS PROJECT WILL STOP TRYING TO MAKE IT

Story 3-0d shipped two source scans meant to make a mid-session "load into replay" control
impossible. They have now been defeated by fresh eyes three times:

* **Round 1.** `set("replay_record", rec)`, `set_deferred(...)` and `runner[&"replay_record"] = rec`
  all reached the member and were tallied as harmless READS; `var load_record := Callable()`, the
  idiomatic inferred form, did not match the panel pattern at all.
* **Round 2** (after `3-0d/R14` rewrote them as a per-occurrence WHITELIST and a
  declaration-carrying-`Callable` match). **`(replay_record) = null` was classified BY THE WHITELIST
  as an "argument read"** -- a literal assignment certified as a read, because the character after
  the token is `)` and the whitelist's `^\s*[,)]` rule said that is a read. Six further panel
  declaration forms evaded the Callable scan: `static var`, `@onready`, an inner-class member, a
  `Callable` in an untyped `Dictionary`, one in an untyped `Array`, and an untyped member invoked
  through a local copy. The shared line reader truncated at the first `#` with NO string awareness,
  so a `#` inside a string literal deleted the rest of the line from BOTH scans. And both read `.gd`
  only, while GDScript embedded in a `.tscn` under `src/` is shipped, compiled, executing code. A
  complete, working, wired LOAD control shipped with the entire suite green.

**The ruling.** Each round hardened the PATTERN and each round a form outside the pattern was found.
The residue that is genuinely undecidable from source text is narrow -- a name built at runtime,
reflection over the property list -- but the PRACTICAL residue kept being wide, because the
classifier and its reader each keep having holes, and **a guard that is believed to hold and does
not is worse than no guard**: the belief is what stops anyone looking. The property is therefore made
STRUCTURALLY IMPOSSIBLE rather than DETECTABLE.

**`3-0d/R20` part 1 -- `replay_record` IS CONSUMED ONCE AND NEVER READ AGAIN.** *Ruled and done.*
`MatchRunner` reads the public `replay_record` exactly once, in `_ready()`, into a private
`_replay_record`; the per-tick fork in `_physics_process`, the live-reload refusal and every other
consumer read ONLY the private field. A mid-session assignment to the public member then has NO
EFFECT -- not because it is caught, but because nothing reads what it changed. The external pre-tree
assignment (`test/integration/test_replay_contacts.gd`) still works unchanged and was verified: that
test passes unmodified in the suite, which is what makes this a CONSUMPTION POINT rather than a
removal of the entry surface.

**`3-0d/R20` part 2 -- PROVE IT BEHAVIOURALLY.** *Ruled and done*, as
`test/integration/test_replay_entry_is_inert.gd`. It assigns `replay_record` mid-match on a
live-shaped runner -- the plainest bare assignment, the exact line the deleted scan hunted -- and
asserts the per-tick fork does NOT flip (live `max_hp` is still the authored value, not the poisoned
one a replayed tick 1 applies), recording CONTINUES (one recorder tick per ticking frame across the
assignment), and no recorded fact reaches live state. That test is the mechanism now. Its falsifying
change is obvious and real and was performed: restoring the per-tick read of the public member makes
it RED on both assertions.

**`3-0d/R20` part 3 -- DELETE THE `replay_record` SOURCE SCAN.** *Ruled and done.* Not kept as a
lint: keeping it would produce false confidence about a property now carried by construction, which
is the failure mode this whole ruling is about. The AC says why (AC 11, re-worded).

**`3-0d/R20` part 4 -- DELETE THE PANEL CALLABLE SOURCE SCAN.** *Ruled and done*, replaced by the
SCENE-LEVEL control-set check alone, which enumerates ACTUAL INSTANTIATED CONTROLS at runtime and is
therefore not evadable by declaration syntax. **Its known hole is fixed in the same ruling:** it
queried `Button`, so a `LinkButton` -- which extends `BaseButton`, NOT `Button` -- slipped past. The
query is `BaseButton`. **Verified by mutation BOTH WAYS, which is the part worth recording:** a
wired `LinkButton` load control fails the new query (`got ["LoadRecord", "NormalizeMagnitude",
"PitchZoneLeftOfBars", "ReloadBalance", "SaveRecord"]`), and **PASSES the old `Button` query, exit
0** -- so the hole was real rather than theoretical.

**`3-0d/R20` part 5 -- NO MECHANISM MAY BE DESCRIBED AS PROVING MORE THAN IT PROVES.** *Ruled and
done.* AC 11's claim that a source scan asserts `replay_record` is assigned nowhere in `src/` is
RETIRED; what replaces it is the structural consumption plus its behavioural test. AC 7 no longer
claims a source scan makes a load control impossible; it claims the panel's instantiated control set
is exactly the expected four names. **The residue is stated plainly in both**, and in the surviving
test's own docstring: AC 11 half (a), the tap-seat scan, SURVIVES, and that is not an inconsistency
-- a source scan is sound evidence for a question about CODE LAYOUT (where two statements sit
relative to each other inside one known function of one known file) and unsound for a question about
REACHABILITY (whether a behaviour can be provoked from anywhere in a tree). The two look alike and
are not alike. The tap-seat test now also states its own reader limit (not string-aware) rather than
leaving it implied.

**THE PERMANENT LESSON (`3-0d/R20`), which outlives this story and supersedes `3-0d/R14`'s narrower
one without contradicting it: PREFER MAKING A PROPERTY IMPOSSIBLE BY CONSTRUCTION OVER MAKING IT
DETECTABLE BY INSPECTION; AND WHEN A GUARD HAS BEEN EVADED TWICE, REPLACE THE MECHANISM RATHER THAN
THE PATTERN.** `3-0d/R14` drew the right narrower lesson -- enumerate what is ALLOWED, refuse the
rest by default -- and the whitelist built on it was evaded BY ITS OWN CLASSIFIER. That is the
moment the pattern-level remedy is exhausted: the guard's failures had stopped being about the
pattern and started being about the fact that it was reading text at all. This binds every future
guard in this repo. Concretely: (a) before writing a guard, ask whether the property can be made
INERT instead -- a consumed value, a private field, a narrowed API -- and prefer that; (b) a guard
that has been evaded twice is not to be widened a third time; (c) where a guard must be
behavioural, its MUTATION PROOF must be behavioural too, and must check that the RIGHT assertion
fires, not merely that the test goes red.

### The four gap-closing rulings

**`3-0d/R21` (closes the `3-0d/R15` gap) -- `has()` IS TRUE FOR `null`, SO PRESENCE IS NOT
VALIDATION.** `RecordFile.load_record` still returned `{"record": null, "error": ""}` for three
inputs: required keys present but carrying WRONG TYPES, `null` under `reload_events`, and `null`
under `intents`. `3-0d/R15` had validated PRESENCE, which closed the truncated-file path and left
these three reaching `_from_dictionary()`, dying inside it, and coming back with an EMPTY reason --
the same defect R15 was raised to close, on a narrower set of files. *Ruled:* validate each required
key's expected TYPE before rebuilding and refuse with a reason naming the key and what was found.
Done, as `REQUIRED_KEYS` becoming a key -> TYPE map; all three tested. **Proven by mutation:** with
the type check disabled the wrong-types file crashes inside the rebuild (`Invalid call. Nonexistent
'int' constructor`, `record_file.gd:292`) and returns an empty error -- the exact defect reproduced.

**`3-0d/R22` (closes the `3-0d/R16` gap) -- A PREFIX TEST ON A STRING THAT CAN CONTAIN `..` IS NOT A
CONTAINMENT TEST.** `save_record`'s guard was a bare `begins_with("user://")` with no normalisation,
and a `user://../../...` path was proven to write a record into the project root. *Ruled:* normalise
instead -- resolve the path and refuse anything that does not land inside the `user://` directory.
Done. **Engine semantics measured first:** `user://../../escape.rec` globalises to
`.../Roaming/Godot/escape.rec`, two directories above the app's user data; `user://sub/../ok.rec`
resolves back INSIDE, so the guard must be containment and not a ban on `..`; and
**`user://../CardSoulsEvil/escape.rec` resolves to `.../app_userdata/CardSoulsEvil/escape.rec`,
which has `.../app_userdata/CardSouls` as a STRING PREFIX and is a different directory** -- which is
why the comparison is against the resolved root PLUS its separator. Traversal forms tested; **nothing
lands in the repo, verified by running it** (a tree-wide search for `*.rec` outside `.godot/` returns
nothing). **Proven by mutation:** reverted to the bare prefix test, the traversals genuinely WRITE
files, which were removed by hand.

**`3-0d/R23` (`3-0d/N4`) -- MATCH THE RUNNER, DO NOT DOWNGRADE THE CLAIM.** `ReplayDrive` reordered
two statements relative to the runner's fork: the controllers were constructed later (the runner
builds them first, before it has a MatchState), and the intents were sampled after the recorded
pushes (the runner samples at the top of `_physics_process`, above the `ticking` gate). Both inert
today, and inert only because `ReplayController.sample()` reads the record and never MatchState.
*Ruled, and the choice is recorded because both options were live:* **MATCH the runner's order
statement for statement**, rather than dropping the docstring's claim to be a transcription of it.
The claim is the value -- the entire reason this helper exists (`3-0d/R17`) is that a silent drift
prints a stable, WRONG hash forever, and a transcription whose docstring admits it is only "a" replay
order guards nothing. Cost: two moved statements, no behaviour change, every hash in the suite
unmoved -- which is itself the evidence that both divergences were inert.

**`3-0d/R24` (`3-0d/N5`) -- THE PARSE BLIND SPOT, CLOSED BY BEHAVIOUR RATHER THAN BY SYNTAX.** A
parse error in `test/tools/replay_file.gd` was invisible to the suite, which is how one shipped last
pass. *Ruled:* the obvious guard is VACUOUS and must not be used -- **`load()` returns a NON-NULL
`GDScript` for a file that does not compile**, so a non-null assertion passes on a broken tool;
`can_instantiate()` is the working discriminator but proves only that the file COMPILES, which is
strictly weaker than AC 8's claim. Build the real one. Done, as
`test/integration/test_replay_verifier_tool.gd`: it writes a fixture record via `RecordFile`, runs
the verifier as a SUBPROCESS in a fresh headless Godot (`OS.execute` on `OS.get_executable_path()`,
so the same engine build), and asserts exit 0, `RESULT: PASS`, a completed replay, and **the same
`CanonicalHash` across two invocations** -- AC 8's claim stated exactly, compared run-to-run and
never against a literal (`3-0d/R18` stands). It also asserts a corrupted file is REFUSED with a
nonzero exit, so the PASS is a verdict the tool can withhold. **The subprocess launch worked on this
platform; NO fallback to `can_instantiate()` was needed.** **Proven by mutation:** the `3-0d/R17`
parse error reintroduced verbatim makes it RED with the engine's own message. AC 8 is self-verifying
now rather than operator-only, and this closes the process promise `3-0d/R17` left behind ("a tool
outside the suite must be RUN as part of any pass that edits it") -- a process promise is not a
mechanism, which is the same lesson as `3-0d/R6`.

### A defect this pass found in its OWN new test, recorded because the finding is the method

The first version of `test_replay_entry_is_inert.gd` took its only `max_hp` reading AFTER the live
reload trigger step -- and the trigger re-applies the AUTHORED balance, which scrubs the poisoned
value a flipped fork had already written. Under the mutation that restores the public-member read,
that assertion stayed SILENT while the fork was genuinely flipped; only the recording-frozen
assertion fired. A reading was added BEFORE the trigger, the mutation re-run, and both assertions
then fired. **A mutation proof that only checks "does the test go red at all" would have passed
this.** That is `3-0d/R14`'s lesson applied to a behavioural guard, and it is why `R20`'s part (c)
above says the mutation proof must check that the RIGHT assertion fires.

**Suite, before and after.** Baseline re-measured by this pass at `HEAD` `a6582e8` with a clean tree:
**348 state tests / 2244 assertions / 20 integration files, ALL PASSED.** After: **348 / 2264 / 22,
ALL PASSED** -- 0 net state tests, +20 assertions, +2 integration files -- and green a third time
after all five mutations were restored. **The flat state-test count is two opposite movements and is
stated rather than left to look like nothing changed:** `test_replay_surface_pins.gd` went 4 tests ->
2 (the two DELETED source scans -- the drop this ruling predicted), `test_record_file.gd` went 9 ->
11 (`R21`'s wrong-types refusal, `R22`'s traversal refusal). The assertion delta is the same story:
the deleted scans carried large evasion-form self-check loops, and what replaced them lives in the
two new INTEGRATION files, which the state count cannot see. `project.godot` is BYTE-IDENTICAL,
SHA-256 `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`, both ends. The golden did
not move: `test_determinism.gd` is absent from `git status` and `GOLDEN` still reads
`40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`. The four inherited `3-0c` pins
required ZERO edits. `test/tools/replay_file.gd` is UNMODIFIED -- a mutation target only, restored
from an out-of-repo copy and SHA-256 verified, absent from `git status`. The live smoke was NOT run:
it is the operator's, it carries the required R-D6 kill (`3-0d/R11`), and this pass was instructed
not to run it.

**Close-out.** Three commits, none pushed: `refactor(x5): make mid-session replay entry structurally
inert (3-0d/R20-R24)` (code and tests), `docs(3-0d): AC 7 and AC 11 re-worded to what the mechanisms
carry (3-0d/R20-R24)` (the story file), and this entry, a PURE APPEND -- no existing entry edited.
Docs and code never share a commit. The board is not touched. No push -- the operator reviews the log
and pushes.


## Session 2026-08-05 -- Story 3-0d closing fix pass, `3-0d/R25`-`3-0d/R29`

**Preconditions verified before anything was touched.** `HEAD` `2fe3eca` (the structural fix pass's
decision-log record); working tree clean; `origin/main` `d45db42` -- ELEVEN commits behind `HEAD`,
expected, none of the eleven pushed; no Godot process running. No fetch, no push. The stated suite
baseline was not taken on trust either: **348 state tests / 2264 assertions / 22 integration files,
ALL PASSED**, measured at that `HEAD` with a clean tree before the first edit.

### The verdict: the mechanism HELD, and the prose around it did not

A final verification pass attacked the `3-0d/R20` structural mechanism against a criterion declared
in advance. **CRITERION (a) HOLDS.** Eight attacks at six different moments: no mid-session
assignment to the public `replay_record` -- in any spelling, at any point in the match -- did
anything to the shipped runner. The consumption point installed at `3-0d/R20` part 1 is doing the
work it was ruled to do, and after three rounds of scans that were each walked around, that is the
result worth recording plainly.

**CRITERION (b) FAILED, on THREE sentences.** The story file and this log were required to be TRUE
of the shipped tree. Three sentences were not, and all three were descriptions of MECHANISMS --
which is precisely the failure `3-0d/R20` part 5 ruled against ("no mechanism may be described as
proving more than it proves"), reappearing within one pass of the ruling that named it. That is the
finding of this pass: **a correct mechanism does not keep its own description honest, and the
description is what the next reader acts on.**

### `3-0d/R25` -- AC 5's TOTALITY CLAIM IS FALSE; REDUCE IT TO WHAT THE CODE CARRIES AND STATE THE RESIDUE

AC 5's amendment header asserted **"REFUSED WITH A CLEAR REASON NOW HOLDS ON EVERY PATH"**. It does
not. **FIVE inputs still return `{"record": null, "error": ""}`** -- a refusal with an EMPTY reason,
which a caller testing `error != ""` reads as SUCCESS. Measured at this pass BEFORE the sentence was
rewritten (throwaway probe under `test/tools/`, deleted after the run; Godot 4.6.3), each one
mutating a single axis of a valid record read back as a raw Dictionary:

| Input | Engine error inside the rebuild | Returned |
|-------|--------------------------------|----------|
| `intents` as an Array of Dictionaries | `Invalid type in function '_intent_pair' ... Cannot convert argument 1 from Dictionary to Array` (`record_file.gd:311`) | `record=null error=''` |
| `intents` shorter than `tick_count` | `Out of bounds get index '1' (on base: 'Array')` (`record_file.gd:311`) | `record=null error=''` |
| `camera_pushes` values are ints | `Trying to assign value of type 'int' to a variable of type 'Array'` (`record_file.gd:307`) | `record=null error=''` |
| `contacts` values are Arrays of ints | `Trying to assign value of type 'int' to a variable of type 'Array'` (`record_file.gd:309`) | `record=null error=''` |
| `tick_count` inflated past intents | `Out of bounds get index '4' (on base: 'Array')` (`record_file.gd:311`) | `record=null error=''` |

`3-0d/R21` had corrected the Dev Notes and the class docstring for the three inputs IT found, and
**left the AC sentence standing** -- so the story's own acceptance criterion outlived the correction
of the text that explained it. That is how a totality claim survives being falsified twice.

*Ruled:* **the claim is REDUCED to what the code actually carries** -- each required key's TOP-LEVEL
TYPE is validated before the rebuild (`REQUIRED_KEYS`, a key -> type map) and a file failing that is
refused with a reason naming the key and what was found in it -- **and the RESIDUE is STATED:**
nested and cross-key consistency (element types inside the required containers, array lengths
measured against `tick_count`) is NOT validated, and a file failing those still refuses with an
empty reason. Corrected in AC 5 and in the identical sentence in `src/systems/record_file.gd`.

**NESTED VALIDATION IS DELIBERATELY NOT BUILT, and that is the ruling rather than an omission.** It
is a third round of the same widening for marginal benefit on a format with exactly one writer, and
the whole point of this ruling is that **the boundary gets WRITTEN DOWN instead of pretended away**.
The residue is closed for CALLERS instead, which is cheap and total: test `result["record"] == null`,
never `error != ""`. Measured -- all three shipped callers already do
(`test/tools/replay_file.gd:43`, `test/integration/test_record_save_control.gd:191`, and
`test/state/test_record_file.gd`, which asserts the record before it reads any reason).

### `3-0d/R26` -- THE MECHANISM TEST IS DESCRIBED WRONGLY IN THIS LOG AND IN THE PINS FILE

The `3-0d/R20` entry above (Session 2026-08-05, structural fix pass, part 2) says
`test/integration/test_replay_entry_is_inert.gd` asserts **"no recorded fact reaches live state"**.
**IT ASSERTS NO SUCH THING.** Its third assertion is that `reload_event_count()` goes 1 -> 2 after
the mid-session assignment -- i.e. that **THE LIVE RELOAD TRIGGER STILL FIRES**, which is how the
test reaches the OTHER consumer of the consumed record. Verified by reading the shipped assertions.
The same wrong sentence was mirrored in `test/state/test_replay_surface_pins.gd`'s header.

*Ruled:* correct both to what the test actually asserts. **The pins file is corrected in place with
the correction visible. THIS LOG IS APPEND-ONLY FOR ENTRIES, so the earlier entry is NOT edited --
this paragraph is the correction of record, and it names the sentence it corrects:** the clause "and
no recorded fact reaches live state" in `3-0d/R20` part 2 is FALSE of the shipped test and should be
read as "and the live reload trigger still fires". The rest of that part 2 paragraph is accurate.

### `3-0d/R27` -- AC 3 DESCRIBES A TEXT SCAN; THE SHIPPED TEST DOES REFLECTION

AC 3 said its test **"counts `func capture_` occurrences in `intent_recorder.gd`"**. The shipped
test (`test/state/test_live_reload.gd::test_the_recorder_still_ships_exactly_eight_capture_channels`)
reads `script.get_script_method_list()` and filters on the name prefix, and its OWN docstring says so
explicitly: "Counted from the SCRIPT's own method list rather than by grepping `func capture_`, so a
channel added by any means (including one inherited or defined out of the obvious form) is caught."
**The outcome claim -- exactly eight, a ninth fails -- is TRUE and unchanged.** Only the sentence
describing HOW was wrong.

*Ruled:* correct the AC's mechanism sentence to the shipped one. Worth recording why this one
matters despite changing no code: the false sentence described the WEAKER mechanism. It claimed a
text scan where the code does reflection over the engine's own method list -- which is not evadable
by declaration form. The story spent three rounds learning to distrust exactly the mechanism its own
AC falsely advertised, while the shipped test had already applied the lesson.

### `3-0d/R28` -- A VACUOUS ASSERTION IN THE FILE THAT *IS* THE MECHANISM

Two corrections to `test/integration/test_replay_entry_is_inert.gd`, one of them a removal.

**The `_after_max_hp` assertion at the final frame was VACUOUS.** With the fork flipped, `max_hp`
reads the poisoned value at `POISON_CHECK_FRAME` and the AUTHORED one at `MEASURE_FRAME`, because
`TRIGGER_FRAME` sits between them and the live reload trigger re-applies the authored balance,
scrubbing the poison. It is the **UN-FIXED TWIN** of the defect the previous pass found and fixed
for the earlier reading -- the same file, the same cause, caught once and missed once, because the
survivor LOOKS like reinforcement ("...and still is at the end of the run"). *Ruled: DELETE it*, and
say in the docstring why it was removed rather than kept. **A vacuous assertion in the file that IS
the mechanism is worse than one anywhere else**, because that file is what everyone now points at.
Measured before deleting, under the `3-0d/R20` falsifying mutation:
`max_hp authored=100.000000 before=100.000000 poisoned-check=1234.000000 after=100.000000` --
**TWO assertions fired, and `_after_max_hp` was not one of them.**

**The poisoned record's tripwire is ONE CHANNEL WIDE, and the docstring implied three.** Only the
reload event is observable. The recorded CONTACT FACT produces no hit -- `_resolve_contacts` calls
`register_swing_hit`, which returns false when the attacker has no registered swing
(`hero_state.gd:228-230`), and the poison record's attacker is idle, so the fact is DROPPED at
resolution. The recorded CAMERA BASIS is inert: a basis only rotates a non-zero `move_dir` and both
live keyboards press nothing in a headless run. *Ruled: correct the docstring to say that, and do
NOT try to make the other two observable* -- that would mean authoring a swinging attacker and
pressed intents into a test whose claim is about a FORK, for a second and third witness to something
one witness already proves loudly. Verify the claim, state it, move on.

### `3-0d/R29` -- TWO CLOSURES: THE WRONG-OBJECT HOLE, AND TWO LOAD-BEARING POINTERS

**The verifier subprocess test did not catch a verifier that hashes the WRONG OBJECT.** Its
determinism assertion compares the hash run-to-run and never against anything else, and run-to-run
equality is satisfied by ANY deterministic function of nothing in particular -- so a verifier
hashing a fresh `MatchState` instead of the replayed one passed every check in the file. *Ruled:
close it cheaply* -- add a SECOND fixture record that differs from the first and assert the two
produce DIFFERENT hashes; keep the existing equality assertion, this is an addition. Done. The two
fixtures share seed, balance, flags, deck, costs, camera bases, contact fact and tick count and
differ ONLY in their recorded intents, which is deliberate: that is exactly the difference a
wrongly-hashed object cannot see. **Proven by mutation, and the mutation landed on exactly the new
assertion** -- with the tool hashing a fresh `MatchState` built from the record's own injected
channels but never advanced, both fixtures printed
`ec631c0d9707ac9d1b6a3118f2654962302c23f44e8cbca3de59622d30eac137`, the run-to-run equality
assertion still PASSED, and the ONLY failure was the new one. That is `3-0d/R20` part (c) satisfied:
the RIGHT assertion fired, not merely some assertion.

**`match_runner.gd` line citations have drifted** -- the file grew 115 lines and the old pointers
land on the HUD card-selection push. *Ruled: wholesale re-anchoring is STILL not required* (the
standing carve-out holds), **but two of the stale pointers are the ones `3-0d/R17` and `3-0d/R23`
deliberately made LOAD-BEARING** -- `ReplayDrive`'s docstring and `test/tools/replay_file.gd`'s
comment, both pointing at the runner's fork "so a change there has somewhere to point". A
load-bearing pointer that points at the wrong thing is worse than none, since the whole reason those
two exist is that a silent drift from the runner prints a stable, WRONG hash forever. Both
re-anchored by LOCATING THE CONTENT: `match_runner.gd:601-608` -> **629-633**. One further stale
citation was verified and deliberately LEFT: the story file's own `3-0d/R17` Dev Note carries the
same pointer, is not one of the two made load-bearing, and stands under the carve-out.

### The residue `3-0d/R20` leaves, recorded as a named residue rather than fixed (`3-0d/R25` N2)

`3-0d/R20`'s guarantee is **"assigning `replay_record` does nothing to the shipped runner"**. It is
NOT "nothing can read it", and the difference is not academic. **A NEW PER-TICK CONSUMER OF THE
PUBLIC MEMBER STILL SLIPS THROUGH.** The concrete one was built and RUN at this pass: four lines at
the top of `_physics_process`, above the sample step, swapping BOTH live keyboard controllers for
`ReplayController`s the moment the public member is non-null -- handing the whole match over to a
recorded intent stream mid-play. **MEASURED, not argued: with that installed the ENTIRE SUITE IS
GREEN, 348 / 2264 / 22, ALL PASSED.** The behavioural test cannot see it and was never built to: it
watches `max_hp`, the recorder's tick count and the reload trigger, and a controller swap moves none
of the three. **THE DELETED SCAN WOULD HAVE FLAGGED IT.**

*Ruled: record this as a named residue, do not build a fix.* The story already stated the residue in
general terms; it is now CONCRETE in AC 11's residue paragraph, **because a residue nobody can
picture is not really stated.** And it makes `3-0d/R20`'s trade honest rather than triumphant: the
ruling did NOT strictly dominate the scan. It traded a guard that was *believed* to hold and did
not, for a guarantee that is *narrower and true*. That is still the right trade -- a false belief is
what stops anyone looking -- but it is a trade, and this log now says so.

**Suite, before and after.** Baseline re-measured by this pass at `HEAD` `2fe3eca` with a clean
tree: **348 state tests / 2264 assertions / 22 integration files, ALL PASSED.** After: **348 / 2264 /
22, ALL PASSED** -- ZERO movement in all three, and that flatness is explained rather than left to
look like nothing happened: **every assertion this pass touched lives in an INTEGRATION file, which
the state harness's 2264 cannot see.** Counted directly: `test_replay_entry_is_inert.gd` 10
assertions -> 9 (`R28`'s deletion), `test_replay_verifier_tool.gd` 12 -> 16 (`R29`'s second
fixture). **Net +3 integration assertions.** No new file, no new `class_name`, no editor scan
needed. `project.godot` is untouched and BYTE-IDENTICAL, SHA-256
`8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`. The golden did not move:
`test_determinism.gd` is absent from `git status` and `GOLDEN` still reads
`40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`. The four inherited `3-0c` pins
required ZERO edits. `src/main/match_runner.gd` is UNMODIFIED -- a mutation target TWICE this pass
(the `R28` vacuity proof and the `N2` residue measurement), restored from an out-of-repo copy and
SHA-256 verified `c2f58ccf...b478f66` identical both times, absent from `git status`.
`test/tools/replay_file.gd` was the `R29` mutation target, restored the same way, SHA-256
`7541d1a2...0a95eec2a`. The live smoke was NOT run: it is the operator's, it carries the required
R-D6 kill (`3-0d/R11`), and this pass was instructed not to run it.

**Close-out.** Three commits, none pushed: `fix(x5): record-file claim reduced to what it carries;
verifier hash guard (3-0d/R25, R28, R29)` (code and tests), `docs(3-0d): three false claims
corrected (3-0d/R25-R29)` (the story file and the pins file header), and this entry, a PURE APPEND --
no existing entry edited, with `R26`'s correction of the earlier entry's own wrong sentence recorded
HERE rather than by editing it. Docs and code never share a commit. The board is not touched. No
push -- the operator reviews the log and pushes.


## Session 2026-08-06 -- Story 3-0d close-out, `3-0d/R30`, and the story is DONE

**Preconditions verified before anything was touched.** `HEAD` `a68738d` (the `3-0d/R25`-`R29`
close-out commit); working tree clean; `git ls-remote origin main` `a68738d` -- HEAD and origin
MATCH, this pass's predecessor's push having landed; no Godot process running. No fetch, no push
performed by this pass. The stated suite baseline was not taken on trust: **348 state tests / 2264
assertions / 22 integration files, ALL PASSED**, measured at that `HEAD` with a clean tree before
the first edit.

This session closes two things: a defect the operator's own live smoke found while performing the
story's one remaining required observation, and the story itself.

### `3-0d/R30` -- SAVE OVERWRITES A PRIOR SESSION'S RECORD, BECAUSE THE INDEX THAT NAMES THE PATH HAS NO MEMORY OF ONE

**What happened, plainly.** `MatchRunner._save_index` starts at `0` in EVERY session -- it is
in-memory counter state, and a fresh process has none. `save_recorded_stream()` used it to name the
save path directly, `RecordFile.path_for(_save_index + 1)`, so a new session's FIRST press of SAVE
always computed `path_for(1)` -- the same path the operator's LAST session's first SAVE had already
written. `FileAccess.open(path, FileAccess.WRITE)` truncates and overwrites without asking. This was
not theorised: it happened live, mid-smoke, to the operator, and took with it the only recording in
which the contact channel had ever been exercised by a real human. Two of the four cumulative saves
this same smoke produced (ticks 2151 and 5333) are gone; only the third and fourth (5659 and 9630
ticks, 4.95 MB and 8.4 MB) survive on disk.

**The documentation was NOT false.** `RecordFile`'s own docstring said "two presses in ONE SESSION
leave two files side by side," and `_save_index`'s comment said "this session." Both claims were
correctly scoped -- neither claimed anything about a SECOND session. The defect is not a false
claim; it is that the class exists to produce an artefact and silently destroys the one it already
produced, and the story's own text never asked the question "what happens on the FIRST save of the
NEXT session."

**The fix, ruled small on purpose.** `RecordFile.first_free_index(start)` (`src/systems/
record_file.gd`) returns the first index `>= start` whose `path_for(index)` does not already exist
ON DISK -- the answer comes from the filesystem, never from counter state, which is what makes it
correct across sessions and after a crash, not merely within one. `save_recorded_stream()`
(`src/main/match_runner.gd`) asks it before writing instead of naming a path blind.
**Deliberately not built:** timestamps, rotation, a cap on record count, or any cleanup of old
files -- each is a new story, and this ruling is scoped to the one property that failed: SAVE must
never destroy an existing record.

**Test surface** (`test/state/test_record_file.gd`): three tests on the index arithmetic (an
untouched span returns its own start; a single occupied path is skipped; a GAP inside an occupied
span is returned, not one-past-the-last-occupied index) and one on THE PROPERTY ITSELF -- a marker
file (arbitrary bytes, not a real record) is written at the first free index, `save_recorded_stream`'s
own sequence (`first_free_index` then `save_record`) is driven, and the marker is asserted
BYTE-IDENTICAL afterwards. The marker test is the one that matters: the index tests could pass on a
function that computes the right number and still overwrites, if a caller ignored it; the marker
test proves the number is actually USED.

**Mutation proof.** `first_free_index` reverted to `return start` (the exact pre-fix behaviour),
backed up first to a copy taken OUTSIDE the repo, SHA-256
`3e76590091e90f73d43f8756ddf126e48dd2b5203ba15f3b11a9aa82ece70f76`. **THREE tests went RED**,
including the marker test, whose failure reproduces the ORIGINAL live defect's mechanism directly:
`assert_ne: both user://cardsouls_record_1.rec` (the computed save path collided with the occupied
one), then the marker's ten bytes found replaced by a full serialised record. Restored from the
out-of-repo copy, SHA-256 verified identical; suite green again.

**A near-miss inside this pass's OWN test-writing, recorded rather than quietly fixed, because it
is the same lesson `3-0d/R14` already named for source scans applied to test authorship.** The
first version of the gap test used a bare `first_free_index(1)` as its base index and touched
`base + 3` on the assumption that a single free result said something about its NEIGHBOURS. It did
not: this machine's real `user://` directory carries the operator's own live-smoke records
SPARSELY -- index 1 and 2 already lost to the defect this ruling fixes, index 3 and 4 surviving --
and `base + 3` landed on the live `cardsouls_record_4.rec` (8.4 MB). The touch overwrote it with a
1-byte marker before the test's own assertion failed and its cleanup calls never ran. **Recovered**
from an out-of-repo backup of all four records taken earlier in this same pass, SHA-256
`2790d90f6045c6d0309f2ecacc94872a15b06082cc8832a277b83012ac00ea6e` verified identical after copying
back; `cardsouls_record_3.rec` was never touched, SHA-256
`18374f9f638a9bdba49799a4e463011b96f667952c7dc41000ec1504409bc2f6` unchanged throughout. **Fixed by
`_free_run`**, which scans a whole CONTIGUOUS span for occupancy against the filesystem before any
test writes a byte, so this class of mistake cannot recur in this file. Worth stating plainly: a
pass whose entire purpose was fixing "SAVE destroys real data" nearly reproduced the same defect
against the same real data, by the same root cause -- checking one index and assuming its neighbours
follow. The guard that closes it (`_free_run`) is the same shape as the guard that closes `R30`
itself: ask the filesystem, not an assumption.

**Suite: baseline 348/2264/22 CONFIRMED BY THIS PASS at `HEAD` `a68738d`, after 352/2270/22, ALL
PASSED both ends** and green a third time after the mutation was restored. `project.godot`
BYTE-IDENTICAL, `8879de490edda78051595f189fb9bb6f2e75384febaff142c8958ec107970004`. Golden unmoved,
`GOLDEN` still `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`. The four
inherited `3-0c` pins required ZERO edits.

### The live smoke -- REQUIRED by the story, RUN for the first time at this close-out, and PASSED

Every prior pass on this story correctly deferred the Live Smoke section to the operator; this is
the first record of it actually happening. Measured facts:

- `ticks=2774`, `reload_events=16` (event #0 is match start, so FIFTEEN live RELOAD presses from the
  panel), `contact_facts=488`, `camera_pushes=5548`, `CanonicalHash
  bc1968d6d2e023ae36063cf2d70fb533eb7e2c3fb249250b8931a9e31f0a62ba`, `RESULT: PASS`, exit 0 -- and
  the SAME hash from a SECOND, separate verifier process on the same file. **The second run is not
  redundant confirmation of determinism in general: every prior determinism measurement on this
  story ran on a record with ZERO live reload events, so `replay_apply_reloads_before` actually
  firing MID-REPLAY against a REAL recorded reload was not covered by any measurement until this
  one.**
- **`R-D6` IS SPENT ON THIS STORY'S SMOKE** (`3-0d/R11`): the operator confirms a KILL occurred.
  R-D6 does not carry forward already spent; any later story wanting a live smoke against a killable
  human-driven slot must re-invoke it at its own gate.
- **AC 9 / `3-0d/R10` OBSERVED BY EYE:** the operator confirms the stamina bar visibly refills to
  max on RELOAD and recorded it as EXPECTED, per the ratification already on record, rather than as
  a defect.
- Cumulative SAVE proven live: four saves at 2151 / 5333 / 5659 / 9630 ticks, files growing 1.88 MB
  -> 8.4 MB -- the operator-visible half of AC 6/AC 7, monotonic growth confirming SAVE snapshots
  rather than stops or restarts the stream. (Two of the four files no longer exist on disk, for the
  reason this session's `R30` entry above records in full -- their EXISTENCE at those sizes, at the
  time, is what is being reported here, not their present survival.)
- The verifier's REFUSAL path was exercised live and by accident: a call against a non-existent path
  printed `REFUSED: no record file at ...` and `RESULT: FAIL`.
- **NOT PERFORMED, recorded as not-owed rather than omitted:** editing the authored `.tres`
  mid-session and observing the change land after RELOAD. The Live Smoke section never required it.
  Stated plainly: this leaves the story's headline claim -- tune balance without restarting -- proven
  by AC 1 (cache bypass, by object identity) and AC 2 (the trigger reaches state), but never once
  observed END TO END by a human. It is a one-line manual check available to any later pass; not
  scheduled here.
- **A record is ~52 KB/s** (`camera_pushes` runs two per tick and dominates the byte count): a
  three-minute round is ~8 MB, consistent with the fourth live save above. Not a defect and not in
  scope for this story -- recorded as an observation for a later story that starts sharing records.

### Two process rulings, recorded because they outlive this story

**The commit-hygiene exception.** The `3-0d/R25`-`R29` docs commit (`70288dc`) contains a
comment-only edit to `test/state/test_replay_surface_pins.gd`, a `.gd` file, which the standing rule
("docs and code never share a commit") forbids on its face. That pass flagged it honestly rather
than hiding it. *Ruled: not rebuilt.* Rewriting three commits to move one comment costs a full pass
for zero functional gain. Instead the rule gains ONE NAMED EXCEPTION, written down here rather than
left implicit: **a comment-only correction of PROSE inside a test file, where that prose is the
thing being corrected, may ride the docs commit.** The distinction that makes this safe: the edit
changes no behaviour and needs no test run to verify, which is the property "docs and code never
share a commit" actually protects (a docs-only commit that nobody needs to re-test). An unwritten
exception is worse than a written one, because the next pass that hits the same shape has nothing to
check itself against.

**The verification-loop lesson, this story's most expensive one, recorded beside `3-0d/R20`.** This
story took ELEVEN passes and THIRTY rulings end to end. The single largest cause was not any one
mechanism being wrong -- it was that adversarial verification ran, more than once, against an
UNDECLARED acceptance criterion. Without a criterion fixed in advance, every clever attack counted
as a defeat regardless of whether it attacked the property the mechanism was built to guarantee, and
each defeat spawned another pass to chase it. The one round that closed cleanly (`3-0d/R25`-`R29`)
is also the one round whose criterion was stated BEFORE the attack ran: "does a mid-session
assignment to `replay_record` do anything to the shipped runner" -- narrow, falsifiable, and
answerable in one pass. *Ruled, and binding on future adversarial passes in this repo:* **an
adversarial pass states what counts as FAILURE before it starts, not after; and a guard that has
been evaded TWICE gets its MECHANISM replaced, not its pattern widened a third time** -- the
`3-0d/R20` lesson, restated here because this story is the reason it had to be learned twice (once
for the mechanism, once for the process around testing it).

### Close-out

**Architecture-amendment queue confirmed at ELEVEN by content, not taken on trust.** No entry after
`3-0d/R12` in this log adds a twelfth member, and this close-out adds none either -- neither `R30`
nor the two process rulings above touch `docs/game-architecture.md` or diverge from it. The queue
is NOT flushed here; it flushes at the E3 close-out, per the standing forcing point.

**Story `3-0d-replay-surface-and-live-reload` is DONE.** Status promoted `ready-for-dev` -> `done`
in the story file and in `sprint-status.yaml`; `story_notes` reduced to what a future reader needs
(what shipped, the smoke outcome, R-D6 spent) rather than the amendment history, which stays in the
story file's own Change Log and in this log. Suite across the whole story, dev pass to this
close-out: 329/1715/19 -> 352/2270/22 (the 329/1715/19 baseline is `3-0c`'s close-out figure, the
tree this story's dev pass started from). `project.godot` byte-identical throughout; golden
UNMOVED, `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`; the four inherited
`3-0c` pins never edited by any pass of this story.

**Four commits, none pushed:** `fix(x5): SAVE never overwrites an existing record (3-0d/R30)` (code
and tests), `docs(3-0d): live smoke outcome + R30 (3-0d close-out)` (the story file), `board:
promote 3-0d-replay-surface-and-live-reload to done` (`sprint-status.yaml` only), and this entry, a
PURE APPEND -- no existing entry edited. Docs and code never share a commit, except where the named
exception above applies, which this session's own commits do not invoke. The operator reviews the
log and pushes.

---

## Session 2026-08-06 -- Story 3-6 readiness gate

Readiness gate on `docs/implementation-artifacts/3-6-card-hud-hand-mana-deck.md` (last touched by the
E3 revisit gate, `E3-RG/R1-R12`, 2026-07-31 -- VERDICT AMENDED, HOLD pending this story's own gate)
returned **NOT READY** with **SEVEN findings**, resolved by six operator rulings this session. This is
the **TWENTY-SECOND logged readiness-gate session; all twenty-two have now returned NOT READY on first
reading.** The gate report itself lives in the browser session; this entry is the record of the
OUTCOME and the RULINGS, not a transcription of the findings.

**Verification before anything was edited.** `HEAD` `3cf8efe`, working tree clean, `origin/main`
`3cf8efe` -- no divergence, no fetch and no push needed to check it. The gate's findings were checked
against the shipped tree, not assumed: no `connect_*` seam anywhere relays card identity or deck count
(`src/main/match_runner.gd` scanned by content); `PlayerState.to_snapshot()` exposes
`hand_size`/`discard_size` only, never ids or order; `CardData` has no display-name or art field;
`_make_card_face_style` is private by the repo's own naming convention (`project-context.md:117`);
`DebugInstrumentPanel`'s box is fixed-height with no stated slack for a fifth control, per its own
3-0b/3-0d comments; `EventBus.reshuffle_vulnerable_window_opened` fires on OPEN only, with no CLOSE
counterpart. All premises held.

**The headline finding: `E3-RG/R4` and `E3-RG/R5`, ruled in the same 2026-07-31 session, contradict
each other.** R4 deletes `OpponentHandStrip` outright ("the row goes"). R5 assumed the reveal toggle
could "flip" the existing `_make_card_face_style(is_own)` seat -- which has a caller left only for
`is_own == true` once R4's deletion lands. A toggle over a row that no longer exists renders nothing.
Neither ruling was wrong about its own premise; R5 simply did not survive R4 being applied literally.

**`3-6/R1` -- the reveal-opponent-hand toggle leaves this story.** `E3-RG/R4` stands. The toggle is
removed as an AC and recorded as a named deferral, not a cancellation: it is cheap once `3-6/R2`'s
seam ships (hand ids are already in hand at that point), owned by the first future story that touches
`src/ui/hud/` card rendering -- no story number assigned, not an E3 exit criterion. This also disposes
of three findings for free: the private-method call from `DebugInstrumentPanel`, the opponent row's
panels never being stored anywhere, and the panel box having no layout budget for a fifth control --
none of them matter once there is no toggle to build.

**`3-6/R2` -- one new observation seam, not three.** Hand card ids (in hand order), deck count, and
discard count ship together as ONE payload on the runner's eighth `connect_*` method, its own AC.
`test_runner_observation_seams_are_exactly_seven` (`2-6/R7`'s freeze, machine-checked by a content
scan of `src/main/`) becomes eight -- an explicit, reviewed exception, the same shape `3-5b` used to
raise the `EventBus` pin from two signals to three. Card container contents/order still never reach
`to_snapshot()` (the pinned 3-0c AC11 exclusion is untouched); this is a live push, never a state
read.

**`3-6/R3` -- the reshuffle window renders from the event, with a presentation-local timer, discharging
`3-5b/R20` explicitly.** `3-5b/R20` required this story to choose, in the open, between a
presentation-local timer (window stays unread, no golden move) and reading state directly (pulls the
window into the snapshot, a new golden cause). Ruling: the timer. The gate's own finding is the reason
the AC must say so in these terms: `reshuffle_vulnerable_window_opened` fires on OPEN only -- there is
no CLOSE signal -- so an indicator built on the event alone cannot turn itself off. The AC now names
the fix: the HUD receives `BalanceConfig.reshuffle_vulnerable_window_seconds` once at construction (the
`gamepad_profile`/`huds` static-handoff precedent) and runs its own countdown from the OPEN event.

**`3-6/R4` -- raw `CardData.id` as card text is accepted, recorded as a named deferral.** `CardData`
has no display-name field and Card ART is unowned by every scheduled story; a formatted title was
never authored anywhere in the pipeline. Rendering the raw snake_case id (e.g. `bramble_snare`) is a
lower legibility bar than a real title, and AC7's whole point is measuring legibility -- so the
deferral is recorded rather than silently assumed, and the live smoke's readability verdict is the
check on whether it was good enough.

**`3-6/R5` -- AC2 (mode-select) needed no new finding, only a task-list correction.**
`set_card_selection` has been wired end-to-end since `3-5a` (`match_runner.gd:621-622`). The story's
task list previously did not distinguish this from the genuinely unbuilt ACs; it now says so directly,
so a dev pass does not spend effort re-discovering or re-building an affordance that already ships.

**`3-6/R6` -- `R-D6` re-invoked.** Available since `3-5a` spent it; `3-5b`, `3-0c`, and `3-0d`
correctly did not re-invoke it, having shipped no player-facing surface. This story is the first
HUD-facing one since, so Live Smoke requires it again.

### Close-out

Story `3-6-card-hud-hand-mana-deck` promoted `backlog`/HOLD -> `ready-for-dev` in the story file and in
`sprint-status.yaml`; `story_notes` reduced to five lines (what the gate found and ruled), not the full
amendment history, which stays here and in the story file's own sections. No code changed this
session -- docs only. Golden and suite untouched (no implementation ran).

**Two commits, neither pushed:** `docs(stories): 3-6 gate fixes + promote to ready-for-dev` (the story
file and `sprint-status.yaml`), and this entry, a PURE APPEND -- no existing entry edited. The operator
reviews the log and pushes.

## Session 2026-08-06 -- Story 3-6 close-out

The live smoke ran and PASSED, operator's own hands, and its `docs/playtest-log.md` entry (`6.8`) is
already committed (`3cdf272`) -- untouched by this session. This closes the two ACs the dev pass left
to the operator (AC 3, AC 7) and the story itself.

**Smoke outcome.** Full two-human, half-width viewport. Hand contents readable during a live exchange;
the deleted opponent row leaves no gap; no collision between the grown card strip, the bars, the pitch
placeholder or the deck indicator; mana and deck count both live; the mode-select affordance (AC 3)
reads without a menu -- **P4 judgment PASSED**. **`R-D6` RE-INVOKED AND SPENT** (`3-6/R6`'s re-invocation
discharged): a kill occurred against a live killable slot, and the round-over label does not overlap
the card row. The reshuffle flag was NOT observed live -- it needs deck exhaustion, which this exchange
did not reach -- and stays proven headless by `test_card_hud.gd`; the debug-reset re-announce likewise.

**`3-6/R7` and `3-6/R8` are unaffected by the smoke and stand as ruled.** `3-6/R7` (own-slot-only
observation seam, reshuffle flag the sole public card fact) and `3-6/R8` (the hand_size<=4 audit bound
closing the deferred truncation finding) were both dev-pass-time rulings, checked against the shipped
tree at the readiness gate and unchanged by anything the smoke observed. Recorded here for the
close-out's own completeness, not because either moved.

**Two findings the operator recorded, neither blocking.**

Peripheral legibility of mana and deck count "could be better" -- DEFERRED BY THE OPERATOR until the
full loop is implemented. Not a defect to fix now; no ruling needed.

**The card-slot-shift finding, recorded as a NAMED OPEN DECISION, not built here and assigned no story
number.** Playing a card slides the remaining cards left and appends the replacement at the end, so
`card_slot` 1 changes meaning under the player's fingers after every cast. The operator wants the
replacement to refill the VACATED slot instead. This is a STATE-semantics change, not a HUD one: `Hand`
has no concept of a hole today, a card slot is either occupied or the array is simply shorter -- adding
one means (a) a "hole" representation in `Hand` distinct from "no card here because the hand is short",
(b) a cast rejected against an empty slot the way an unaffordable cast is rejected today (3-5a's
`action_rejected` seam, not a new one), and (c) `3-5b`'s delayed delivery filling a specific OWED index
rather than appending -- `PlayerState.pending_draw_owed` would need to carry which slot it owes, not
merely a count. It moves the golden: `hand` order becomes index-stable across a cast where it is not
today, which is exactly the kind of behavioural change `3-5a`'s cast-and-refill sequencing was measured
against. None of this is scoped by any shipped AC; it is new design surface, Matko's to decide, and
sits beside the E3 architecture-amendment queue rather than in it -- the queue is untouched this
session and flushes only at the E3 close-out.

### Close-out

Story `3-6-card-hud-hand-mana-deck` promoted `ready-for-dev` -> `done` in the story file and in
`sprint-status.yaml`; `story_notes` rewritten to the closed outcome, five lines. No code changed this
session -- docs only. Golden and suite untouched (no implementation ran); `R-D6` is spent and available
again only once re-invoked by a future HUD-facing or otherwise player-surfaced story, per the standing
rule (`3-0d/R11`, `3-6/R6`).

**Two commits, neither pushed:** `docs(stories): 3-6 close-out` (the story file and
`sprint-status.yaml`), then this entry, a PURE APPEND -- no existing entry edited. The
architecture-amendment queue is deliberately untouched; it flushes at the E3 close-out, a separate
pass. The operator reviews the log and pushes.

---

## Session 2026-08-06 -- E3 close-out

E3 is complete: stories `3-0a` through `3-6` are all `done`, pushed, `HEAD == origin/main` at
`ddd14ad`, suite 362/2305/23, golden `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`
unmoved. This session flushes the architecture-amendment queue that accumulated across E3, per the
standing forcing point set at `E2-CO/R1` and reaffirmed at every growth point since.

**Queue confirmed at ELEVEN by content, not taken on trust.** Found by searching the log itself for
every ruling that names the queue, cross-checked against the running counts each ruling states:
`3-0a/R10` (items 1-3, item 1 the pre-existing `assets/` gap sharpened, items 2-3 new), `3-0b/R17`
(item 4), `3-4/R4` (item 5), `3-4/R9` (item 5 expanded, not a new member), `3-2` readiness gate finding
/ `3-2` close-out (item 6), `3-3` readiness-gate close-out (item 7), `3-5` readiness-gate findings
(v)/(vi)/(vii) combined at the ruling below "the eighth architecture-amendment-queue member" (item 8),
`3-5/R9` (item 8 given a concrete target, not a new member), `3-0c/R10` (item 9), `3-0c/R14` (item 10),
`3-0d/R12` (item 11, explicitly counted against the prior ten by content). No entry after `3-0d/R12`
adds a twelfth. **Eleven confirmed, matching the count reported by every ruling that recorded a running
total.**

**All eleven landed in `docs/game-architecture.md`, commit `docs(architecture): E3 amendment queue
flush`, ledger entry A5 (v1.4).** Each amendment describes what SHIPPED and cites the ruling that made
it so:
1. `assets/` Directory Tree expanded from one unexpanded line into `characters/<name>/` (source
   assets + two new artifact kinds) alongside `audio/`/`art/`/`models`/`materials` (`3-0a/R10`).
2. Import post-processing (`EditorScenePostImport` `@tool` scripts, e.g. `strip_model_anim.gd`) named
   as a sanctioned repo pattern (`3-0a/R10`).
3. A new artifact type under `assets/` -- editor-assembled files (import-hook `.gd`, `AnimationLibrary`
   `.res`) committed alongside source assets (`3-0a/R10`).
4. `src/controllers/` documented as not exclusively `Controller`-typed: `DebugInputReader` lives there
   under D3(a)'s Input-confinement rule without implementing `sample()`/`InputIntent` (`3-0b/R17`).
5. D6 / Novel Pattern 5 rewritten to the shipped `EconomyEvaluator` shape: `amount_field` indirection,
   compute/apply split (evaluator never touches a pool), sorted-directory-scan loading of
   `data/economy/` (`3-4/R4`, `3-4/R9`).
6. `CardData`/`CardEffect` schema corrected: six exports (`id`, `max_copies` added), `CardEffect` added
   to Schema-vs-Loader and the Directory Tree (3-2 gate, `3-4/R9`).
7. `Deck`/`Hand` added to the Directory Tree; D3 INVARIANT (b) now names the actual banned APIs
   (`Array.shuffle()`, `Array.pick_random()`, bare `seed()`), not just the concept; the conditional
   EventBus/seam-registry reconciliation folded into the D5/Event System rewrite below (3-3 close-out).
8. Novel Pattern 6 corrected three ways: the `CardData` sketch (member 6); `ModeKind` moved onto
   `Enums` with dispatch as a private `MatchState` method at `advance()` step 6, not a free `resolve()`
   function; every `check_invariant` reference in the document renamed to the real symbol,
   `Invariant.check` (`3-5/R9`, folding findings first raised at the 3-2 and 3-5a gates).
9. The X5 section's scope line ratified as a decision; its controller-swap-only replay sketch replaced
   with the shipped runner-level fork (recorded camera bases, contact facts, and reload events applied
   directly against `MatchState`, not derived by a controller swap alone) (`3-0c/R10`).
10. The tick pseudocode's intent-tap seat corrected: immediately before `advance()`, inside the
    runner's ticking gate, not at the sample step (`3-0c/R14`).
11. `src/ui/debug/`'s Directory Tree annotation and Debug Tools item 5 corrected from
    "record/replay start-stop-load" to SAVE-only -- no load control, no start control (`3-0d/R12`).

Also updated as part of the same pass, not separately queued members: the D5 observation-seam
registry and Event System section now state the actual shipped counts (eight `connect_*` seams, three
`EventBus` signals including `reshuffle_vulnerable_window_opened`) -- these were always going to move
once member 7's conditional clause fired with `3-6/R2`, and fixing the count alongside the Deck/Hand
tree entry (member 7) was more honest than landing a stale count and re-opening it next epic.

**Ruling: the card-slot refill-in-place finding is a story now, not a deferral.** The finding recorded
at the `3-6` close-out (card_slot identity is not stable across a cast; the operator wants the
replacement to refill the VACATED slot) was left as a named open decision with no story number,
sitting "beside" the amendment queue rather than in it. **The operator RULES it is done NOW, not
deferred: it becomes `4-0-hand-slot-stability`, a preparatory story at the head of Epic 4, on the same
precedent `3-0a`..`3-0d` set for E3** -- a dedicated substrate story ahead of the epic's feature work,
rather than folding a state-semantics change (`Hand` needs a "hole" representation; a cast against an
empty slot rejects like an unaffordable one; `PlayerState.pending_draw_owed` needs to carry which slot
it owes) into the first E4 feature story. **No story file is authored and the board is not touched by
this ruling** -- this entry is the record of the decision only; the story is created at its own
just-in-time authoring pass, per the Set-B-staleness lesson (`E3-P/R3`).

**Two commits, neither pushed:** `docs(architecture): E3 amendment queue flush` (`docs/game-architecture.md`
only, ledger entry A5), then this entry, a PURE APPEND -- no existing entry edited. The operator
reviews the log and pushes.

---

## Session 2026-08-06 -- E3 retrospective ruled

The first retrospective ever held in this project. The retrospective itself is
`docs/implementation-artifacts/epic-3-retro-2026-08-06.md` (commit `docs(retro): epic 3
retrospective`); this entry records only what it RULED, per the standing separation between an
analysis artifact and the decisions it produces. `sprint-status.yaml` is deliberately NOT touched: it
carries no `epic-N-retrospective` key for any epic and its header locks the lifecycle to exactly
`backlog -> ready-for-dev -> done` ("No other states"), so recording a retrospective on the board
would mean inventing a fourth status. The retrospective says so in its own text.

**A correction the retrospective made to itself, recorded because the method is the finding.** Its
first draft claimed "E3 ran 0-for-11 on skills," measured by counting skill NAMES in story prose --
an artifact of what an author chose to write down, not a trace of what ran. The machine-checkable
trace is the `baseline_commit` front-matter key, written by `gds-dev-story`. Measured by content:
present in exactly THIRTEEN story files -- twelve in E1 (`1-1`, `1-2`, `1-3`, `1-3b`, `1-3c`, `1-4`,
`1-5`, `1-6`, `1-7`, `1-7b`, `1-8`, `1-9`) and `3-6`, whose value
`c6357be918bbd16ee7ed91879a15d74d2b40803b` resolves to `docs(decision-log): 3-6 readiness gate
outcome`, the commit immediately preceding its dev pass. The prose measure missed three files.
**Corrected: E3 ran 1 of 11 on the skills.** `3-6` ran end-to-end through `gds-create-story`,
`gds-dev-story` and `gds-code-review`; it caught two real patch-level defects (freed-`HudRoot` timer
callback; missing label overflow protection), both shipped in `fix(hud): 3-6 review patches`, and its
`[Review][Defer]` became `3-6/R8`. It verified the dev pass's mutation claim with an INDEPENDENT
mutation grep rather than trusting it. Its named failure mode: the Acceptance Auditor layer HUNG at
600s and the acceptance audit was done by hand -- so the substitution is proven at patch level and
UNPROVEN at exactly the layer where `3-0d` cost four review rounds. Permanent rule: **measure
provenance from machine-written keys, never from prose.**

**`E3-R/R1` -- OPEN DECISION (c), variable analog magnitude, is RESOLVED by shipped authoring, and is
RECORDED, NOT REOPENED.** Decision (c) was raised at `2-2/R5` (the controller normalizes the stick
vector to unit length above the deadzone rather than passing a fraction of `move_speed` through), with
its forcing point set at 2-6 and then at "the E2 retrospective." **No E2 retrospective was ever held**
-- verified by content, no `epic-*-retro-*.md` file existed in this repo before today -- so (c) waited
two epics while the shipped code answered it. `3-0b` AC12 made the answer explicit and authored:
VERDICT KEEP `normalize_move_magnitude = true`, now authored explicitly rather than surviving as an
unstated default. Ruling: that IS the resolution. Variable-magnitude movement stays unauthored and
unadopted; it does not join the DEBT E animation-gate registry (moot -- DEBT E is closed). Status:
**RESOLVED**, no further owner, no forcing point. This is a bookkeeping closure of a decision the code
settled, not a new design decision, and it is explicitly not an invitation to re-litigate walk speed.
Recorded as the clearest evidence in the log for why retrospectives get held: a decision parked at a
venue that never convenes stays parked.

**`E3-R/R2` -- THE `SCRIPT ERROR` HARNESS GAP: OWNER IS THE OPERATOR, AND IT RUNS AS ITS OWN TOOLING
PASS BEFORE `4-0-hand-slot-stability`.** This is the one item explicitly deferred to this
retrospective (3-1 close-out: "OPEN, no owner: make the harness FAIL on `SCRIPT ERROR` lines in its
own output; ownership decided at the E3 retrospective"). Re-verified by content this session:
`test/run_all.sh:28` pipes each integration run through
`grep -E "RESULT:|SCRIPT ERROR|Parse Error|INVARIANT VIOLATED"`, and the line below it sets `fail`
from `PIPESTATUS[0]` -- the Godot exit code -- so **a `SCRIPT ERROR` line is printed and ignored. The
grep is vacuous as a gate.** Every "zero SCRIPT ERROR lines" claim recorded across E3 was therefore a
claim about output a human read, never about a test that would have failed. Ruling: **owner is the
operator**, and it is scheduled as **its own tooling pass, BEFORE `4-0-hand-slot-stability`, not
folded into it** -- on the standing precedent that a corrective with one named cause gets its own
commit chain (BC/R1, SDV/R1, `E3-RG/R2`), and because folding a harness change into a story that also
moves the golden would confuse two independent proofs. Note for whoever runs it: turning this on may
surface pre-existing noise that has been printed and ignored for the whole project; that surfacing is
the point, and any resulting failures are findings, not regressions introduced by the pass.

**`E3-R/R3` -- THE MELEE RETUNE IS SCHEDULED, NOT RESOLVED, BECAUSE IT IS A FEEL CALL.** Owed since
the 3-5 gate, where the operator sealed it to land AFTER `3-5a`'s live smoke as its own golden-neutral
balance commit, against the criterion "a round should finance 2-4 loop cycles" (`E3-RG/R1`'s authoring
criterion, restated at the 3-5 gate seal 3). Verified by content: **no such commit exists** in the E3
range. The reason it was owed and not done is now the reason it still cannot be closed on paper --
the criterion was unjudgeable until cycles per round could actually be counted, which the full loop
only made possible at E3 close; and counting them is a LIVE PLAYTEST, not a headless measurement.
Ruling: it stays a scheduled obligation with its criterion intact and its shape fixed (one authored
`.tres` edit plus a decision-log record, golden-neutral by the BC/R3 isolation, no test edit), and it
is NOT resolved by this retrospective. It requires a live playtest to judge; the retrospective cannot
substitute for one. It re-invokes `R-D6` if run against killable human slots (`R-D6` is SPENT as of
`3-6`).

**`E3-R/R4` -- THE CHANGE LOG AUTHOR-COLUMN QUESTION, ANSWERED.** Parked twice (3-2 gate close-out,
3-5a gate close-out), both naming the E3 close-out as the forcing point, and **not discharged there**
-- the close-out flushed the eleven-member architecture queue and dropped this rider. Ruling: **the
Change Log author column carries the ACTUAL MODEL THAT DROVE THAT PASS, the same value as `Agent Model
Used` in the same file.** A mixed column is therefore CORRECT, not a defect to normalize: `3-5a` and
`3-2` reading `Claude Opus 4.8` for one row and `Claude Sonnet 5` for the next is those files
accurately recording that two different models did two different passes. No file is rewritten to make
a column uniform. **The commit trailer is unaffected and stays the repo-wide constant
`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`** (operator ruling, restated at `3-0d`
repeatedly, not reopened here). The two records answer different questions: the trailer names a repo
invariant, the column and `Agent Model Used` name what did the work.

**`E3-R/R5` -- WHAT E4 INHERITS, RECORDED AS A FACT ABOUT THE PLAN AND NOT AS A RULING ON IT.** Two
findings the retrospective measured, carried here so the next planning pass reads them before
authoring anything:
1. **`CardEffect` has NO consumer anywhere in `src/`.** `3-5a` shipped `card_cast_resolved` carrying a
   resolved card ID, not a `CardEffect` -- an accepted deviation, because the cost-injection seam
   injects costs only. E4's stated goal in `epics.md` is "wire Basic-mode summons to real actors,"
   which is precisely the missing consumer. E4 starts by building the thing the schema has been
   waiting for since 3-2.
2. **E4 enters with NO substrate stories and no architectural pre-work recorded.** `epics.md`'s E4
   Committed obligations add nothing beyond the GDD epic table. E3 entered with four substrate stories
   (`3-0a`..`3-0d`) plus a revisit gate. `4-0-hand-slot-stability` (ruled at the E3 close-out) is the
   first correction to that and is unlikely to be the only one needed -- object pooling, throttled
   targeting, and data-defined minion priority types are all named in `epics.md` with no decision
   recorded anywhere about how they are shaped.
No ruling is taken on E4's plan here. A retrospective records what the next planning pass must not
discover late; it does not do that pass's job.

**Also recorded, discharged by the companion commit rather than ruled.** `stories-manual-e3.md`'s
provisional front matter, its stale revisit-gate banner, its six `Revisit note` blocks (E3.S1, E3.S2,
E3.S3, E3.S4, E3.S5a, E3.S6) plus E3.S5b's unlabelled provisional sentence carrying the same stale
instruction, and the last live instance of the non-existent symbol `check_invariant` (E3.S2 item 4,
corrected to `Invariant.check`) -- all found by content, all deferred by the 3-5 gate to "the E3
close-out docs flush," all missed by that flush, all landed now in `docs(stories): E3 stories manual
hygiene`. `E3-RG/R11` had already flagged this class of failure as recurring "the seventh occasion
cumulatively"; left alone the file would have reseeded corrected defects at the next gate that read it.
Historical text is kept beneath each closure, unedited, per the standing rule that the log and its
companion artifacts are corrected forward and never rewritten.

**Three commits, none pushed:** `docs(retro): epic 3 retrospective` (the retrospective artifact only),
`docs(stories): E3 stories manual hygiene` (`stories-manual-e3.md` only), then this entry, a PURE
APPEND -- no existing entry edited. `sprint-status.yaml` untouched, deliberately (see above). No code
changed; suite and golden untouched, nothing ran. The operator reviews the log and pushes.

---

## Session 2026-08-07 -- harness gate fix recorded

**`E3-R/R2` -- DISCHARGED BY `e2872e2`, SCOPE CORRECTED BY MEASUREMENT.** The retrospective ruling
assumed all three grepped patterns (`SCRIPT ERROR`, `Parse Error`, `INVARIANT VIOLATED`) were equally
ungated by `test/run_all.sh`'s `PIPESTATUS[0]` check. Measured, not assumed, this session: a `Parse
Error` (script fails to load) makes Godot's own process exit nonzero, so that pattern was **already**
caught by the pre-existing exit-code check -- verified by dropping a throwaway syntax-error `.gd` into
`test/integration/` (deleted after) and observing `godot --headless --path . --script ...` exit 1 both
standalone and inside the full suite, no hang, well under a 30s / 240s timeout respectively. The one
real hole was a firing `Invariant.check`: it prints `ERROR: INVARIANT VIOLATED: ...` then `SCRIPT
ERROR: Assertion failed: ...` and **continues**, so Godot exits 0 and the old gate registered a pass.
`e2872e2` closes exactly that hole, no more: each test run's output is captured once (`out="$(godot
... 2>&1)"`), Godot's exit status is captured explicitly right after (`exit=$?`, not `PIPESTATUS`, per
the correction below), and the captured output is additionally grepped for all three patterns so a
misreported pass still fails the suite. Console output shape is unchanged. Proved by injecting a probe
integration test that fires `Invariant.check(false, ...)` and then prints `RESULT: PASS` -- the suite
failed it (`>>> FAILED: ...`, exit 1); probe deleted, suite passed clean at **362 state tests / 2305
assertions / 23 integration files**, matching the pre-existing baseline exactly (nothing else moved).

**`3-0c/R15` -- CONFIRMED BY DIRECT MEASUREMENT, not re-derived from its own text.** Fired
`Invariant.check(false, "probe firing")` from a throwaway script outside `test/` (deleted immediately
after), invoked exactly as the harness invokes any script (`godot --headless --path . --script ...`).
Observed: `push_error` prints the `ERROR: INVARIANT VIOLATED` line, `assert()` prints `SCRIPT ERROR:
Assertion failed`, and the script's next line (`print("AFTER")`) still ran before `quit()` -- exit
code 0. Print-and-continue, not abort, exactly as R15 already recorded. This does not violate R15's
own precedent (never prove a guard's FIRING inside a test): the probe measured harness behaviour once,
outside the suite, and was deleted, not committed as a test.

**A NEW open finding, unowned, not fixed this pass: a `SceneTree` script that never reaches `quit()`
never terminates.** Measured with a second throwaway probe (`test/integration/test_zzz_gate_probe.gd`,
deleted after) containing a null dereference before `quit()`: `x.get_name()` on `var x: Node = null`,
invoked identically to how `run_all.sh` invokes every integration test. Result: no output past the
Godot startup banner for the full 300s the process was allowed to run, confirmed via the background
task's own output file staying empty; the process was still alive and was killed by hand
(`TaskStop`) -- it was not observed to exit on its own at any point. `run_all.sh` has no timeout
anywhere in it, on any invocation. A test that hits this failure class -- an unhandled runtime error
in a `SceneTree` script before it reaches `quit()` -- does not fail the suite; it stalls it
indefinitely, and the grep gate is powerless against it because no output ever completes for the grep
to see. The only defense is a per-test timeout. This is a wider hole than the one `e2872e2` closes.
Recorded as open. **No owner assigned, no forcing point scheduled** -- per instruction, this session
records it and does not act on it.

**Companion correction, same session, different commit:** three test comments
(`test_card_play.gd:226`, `test_card_play.gd:300`, `test_deck_and_hand.gd:254`) justified never
calling `Invariant.check`'s stub directly by claiming assert() "ABORTS the harness." Measurement above
proves that false -- it prints and continues. The conclusion those comments reach (don't call the
guard directly; prove it by source scan / presence-at-seam instead) is unaffected and stands: a
deliberately triggered guard still pollutes the suite's output with a false-looking failure, and as of
`e2872e2` it now genuinely fails the suite, just for the wrong reason (a deliberate trigger, not a
real defect) -- which is itself still a reason not to do it. Only the stated MECHANISM was wrong and
is corrected; landed in `docs(test): correct assert() harness-abort claim in comments` (comment-only,
no assertion, test logic, or behaviour changed -- suite re-verified at 362/2305/23 after).

**Two commits, neither pushed:** `docs(decision-log): harness gate fix recorded` (this entry, a PURE
APPEND -- no existing entry edited), then `docs(test): correct assert() harness-abort claim in
comments` (`test/state/test_card_play.gd` and `test/state/test_deck_and_hand.gd`, comment-only). No
`src/` changed, no golden re-baseline, no story file. The operator reviews the log and pushes.

---

## Session 2026-08-07 -- Story 4-0 readiness gate outcome, `4-0/R1`-`4-0/R8`

Readiness gate on `docs/implementation-artifacts/4-0-hand-slot-stability.md` (authored 2026-08-07 at
its own just-in-time pass, commit `69726a5`, per `E3-P/R3`; HOLD carried in the file's own scope
note) returned **NOT READY** with **EIGHT blocking findings and THREE notes**, resolved by eight
operator rulings this session, two of them extended by the operator beyond the gate's proposal. This
is the **TWENTY-THIRD logged readiness-gate session; all twenty-three have now returned NOT READY on
first reading**, and all twenty-three were resolved in the session that found them. The gate report
itself lives in the browser session; this entry records the OUTCOME and the RULINGS.

**Preconditions verified before anything was read, and all held.** `HEAD` `69726a5`, `origin/main`
`69726a5` -- no divergence. Working tree clean. Full suite re-run from this session: `362 tests, 0
failed, 2305 assertions`, 23 integration files individually PASS, `run_all.sh` exit 0. `GOLDEN` at
`test_determinism.gd:269` reads `40eb5554796bfff98f16994a1fa721be9ce7a0b01880be17b7fd84e6d39fa322`,
matching. **The story's Dev Notes citation audit PASSED in full** -- every line number and symbol
claim was checked by content (`hand.gd:19/22/61-66`, `match_state.gd:839/840-842/892/918/839-872`,
`player_state.gd:65`, `hud_root.gd:157-159`) and not one failed. The story did not fail the gate on
citation; it failed on the eight findings below.

### The eight blocking findings

**B1 -- `Hand` has no way to learn its own width, so AC 1 and Task 1 were unimplementable as
written.** AC 1 said "fixed-width at `hand_size`"; Task 1 said `clear()` "fills every position." But
`PlayerState._init` builds `Hand.new()` with no arguments (`player_state.gd:104`) and `hand_size` is
read INLINE at the deal seat under CONSTRAINT C (`match_state.gd:735-737, 761`). `clear()` cannot
fill "every position" because it does not know how many there are, and every way of telling it
changes a public API.

**B2 -- `Hand.size()` semantics undefined, and four shipped conservation assertions invert on the
answer.** The story never said whether `size()` returns the container width (constant) or the
occupied count. Under width semantics the four-term identity `hand.size() + pending_draw_owed ==
hand_size` becomes `hand_size + owed == hand_size` -- FALSE whenever a draw is in flight. Four
shipped sites assert it: `test_card_play.gd:87`, `test_draw_delay_and_reshuffle.gd:564`,
`test_determinism.gd:801`, `test_deck_reshuffle.gd:230`. The same ambiguity decides B7 and whether
`match_state.gd:840` is still a bound check. The gate's largest gap, and design-shaped.

**B3 -- "HUD inherits this for free" is false unless the marker is `&""`, and no AC required that.**
`hud_root.gd:159` is `_own_card_labels[i].text = str(hand_ids[i]) if i < hand_ids.size() else ""`.
Against a fixed-width payload `hand_ids.size()` is always 4, the `else ""` branch is DEAD, and the
caption becomes `str(marker)` -- so any marker but the empty `StringName` renders visible garbage in
the vacated slot, the exact defect 3-6 AC 1 shipped to prevent. AC 1 constrained the marker's
EXISTENCE, never its VALUE, and the story carried no HUD AC at all.

**B4 -- 3-6's `vacated_cleared` proof goes vacuous.** `test_card_hud.gd:104-112` does not cast; it
hand-builds a THREE-element payload and asserts `after[3] == ""`. Under fixed width no shipped seat
can ever emit a short array, so that fixture stops testing anything the code can produce while still
passing. The story called this "re-pointing"; it is a vacuity, and it cannot be fixed before the
marker value is ruled.

**B5 -- `_deal_player`'s fill loop MUST be rewritten; Project Structure Notes said it might not need
to be.** `match_state.gd:761-764` fills via `player.hand.add(...)`. Against a `clear()` that
pre-fills the width, `add()` appends PAST the width and produces a `2 * hand_size` array. "Reviewed
against the new fixed-width container, not necessarily rewritten" was wrong by content.

**B6 -- `3-5b/R8`'s "a cast is not gated on a pending draw" is contradicted BEHAVIOURALLY, not
merely in scope.** The story's header said the no-new-rejection clause "survives in LETTER ... but
not in SCOPE." It is worse: `test_draw_delay_and_reshuffle.gd:118`
`test_a_cast_is_not_gated_on_a_pending_draw` casts **slot 0 twice** and asserts `rejections == []`.
Under the story's AC 2 the second cast targets a hole and rejects -- the test named for R8's own rule
FAILS. A scope note does not cover a failing test.

**B7 -- the Golden Prediction was missing a cause.** Cause 1 named only `pending_draw_owed`'s shape,
but `"hand_size": hand.size()` (`player_state.gd:135`) is also a hashed key whose value moves the
moment `size()` means width. The golden hashes at t24 with a cast at t22 against an 11-tick delay, so
a hole is LIVE at hash time: the key would read 9 where it reads 8 today. A second, independent
snapshot mover the prediction did not name -- the precise failure mode the isolation discipline
exists to catch. Also `test_determinism.gd:731` and `:780` assert `hand.size() == HAND_SIZE - 1`
inside the hashing fixture's own pins.

**B8 -- the exhaustion fixtures are mechanically destroyed, and the affected-file list was
incomplete.** `_cast()` (`test_draw_delay_and_reshuffle.gd:536-541`) always casts slot 0, with a
comment stating the exact premise this story deletes: "always slot 0, because the hand shrinks under
it and slot 0 is the one index guaranteed to exist while the hand is non-empty." Two fixtures loop it
`HAND_SIZE` times with no delivery between (`:96` `test_four_casts_in_flight_deliver_four_cards_one_per_expiry`;
`:409` `test_conservation_holds_across_the_both_empty_degrade`) -- casts 2..N now reject
and both collapse to a single cast. Separately, **`test_discard_pile.gd` was absent from Project
Structure Notes** while pinning shrink semantics head-on (`:64` "the hand shrank by exactly one";
`:73` `remove_at(hand.size() - 1)`), as were `test_card_observation.gd`, `test_card_hud.gd` and
`test_deck_reshuffle.gd`. Also unmentioned anywhere: `hand.gd:62`'s
`Invariant.check(index >= 0 and index < _cards.size())` exists to catch a bypassed step-6 guard, and
under fixed width every index is in range, so it goes SILENTLY VACUOUS unless re-pointed to
occupancy.

### The three notes

**N1 -- the Golden Prediction's cause 2, MEASURED rather than guessed, is a NON-MOVER.** The gate
read all three hashing fixtures by content. Each issues EXACTLY ONE cast: `test_determinism.gd`
(the golden) at `_play_sequence:879` `if cast and t == CAST_TICK`, `CAST_SLOT` 3 against `HAND_SIZE`
9; `test_record_file.gd:567` `if t == CAST_TICK`, slot 1 against hand 3; `test_replay_identity.gd:419`
`if t == CAST_TICK`, slot 1 against hand 3. **No golden fixture issues a second cast against any
slot, let alone the same slot, let alone before the first replacement lands.** Cause 2 is therefore a
measured non-mover, and `test_the_recorded_cast_consumes_no_rng:815` confirms the cast path is the
only card-shaped hash cause and that it fires once. **Recorded here so the dev pass never re-derives
it** (`4-0/R7`).

**N2 -- `3-6/R8`'s `hand_size <= 4` bound is unaffected and becomes MORE load-bearing.**
`test_balance_authoring.gd:148` bounds the AUTHORED `hand_size` against the HUD's four fixed slots.
Fixed width makes a width-5 hand emit a 5-element payload into a 4-label row, so the bound already
covers the new failure mode. No change needed.

**N3 -- the Deferred section contradicted 3-5b's AC 10 degrade.** It said "every owed slot is
eventually filled." Under the both-empty degrade (`match_state.gd:913-916`, proven at
`test_draw_delay_and_reshuffle.gd:409`) the debt is consumed and no card arrives, so the slot stays a
hole permanently and rejects forever. Only the no-misdelivery half of that clause is true.

### The rulings

**`4-0/R1` -- `Hand.size()` means WIDTH; a new `occupied_count()` carries what `size()` means
today.** The gate enumerated nine consumers of the hand's length and they split irreconcilably across
the two readings, so the split is made explicit rather than left implied. **The snapshot key
`hand_size` binds to `occupied_count()`**, which preserves its meaning unchanged, keeps 3-5b's
four-term conservation identity true, and keeps `3-5b/R8`'s "`hand_size` is permitted to reach 0"
meaningful. `Hand.is_empty()` likewise means "no OCCUPIED slots" -- the backing array is never empty
once dealt, so a bare `_cards.is_empty()` would be permanently false and silently wrong. Resolves B2;
makes cause 1 the only snapshot-shape mover.

**`4-0/R2` -- the width is established at the DEAL SEAT, never by `Hand` itself.** `clear()` takes
the width (or an explicit resize), called with `balance.hand_size` read INLINE per CONSTRAINT C.
`Hand` never learns of `BalanceConfig`, never holds a config reference and never names `hand_size`. A
never-dealt `Hand` has width 0, which is what keeps `test_economy_and_hero.gd:89`'s pre-deal
`snap["hand_size"] == 0` true with no special case. Resolves B1.

**`4-0/R3` -- the empty marker is the empty `StringName` (`&""`), ruled explicitly, WITH the
operator's extension.** Ruled so `hud_root.gd:159` renders a blank caption with no HUD change. A new
AC pins it, and `test_card_hud.gd`'s `vacated_cleared` / `refill_rewrote` is re-pointed to a
marker-bearing FULL-WIDTH payload rather than a hand-built short array. Resolves B3 and B4.

**Operator extension, and three premise corrections the fix pass found by content and did not
silently absorb:**
- The extension requires the marker/card-id collision be impossible BY CONSTRUCTION via an
  authoring-audit assertion that no authored `CardData.id` is the empty `StringName`. **That
  assertion ALREADY SHIPS**: `test/state/test_card_authoring.gd:66`
  `test_every_id_is_non_empty_and_unique` asserts `card.id != &""` over every authored card. It is
  therefore RE-POINTED as load-bearing for this story with a comment saying so, rather than
  duplicated. The collision was already impossible; the extension makes that fact load-bearing and
  unweakenable.
- The extension named `test_balance_authoring.gd` as the home for it. **By content that file loads
  only the `BalanceConfig`** (`load(CONFIG_PATH) as BalanceConfig`, ten sites) and cannot reach
  `data/cards/`. The audit stays in `test_card_authoring.gd`, where the authored cards actually are.
  A placement correction, not a scope change.
- The extension states the HUD's cost greying treats the marker as uncastable and never looks it up
  in the cost map. **There is no cost, affordability or greying rendering in `src/ui/` today** --
  verified by content; `_card_costs` is `MatchState`-private and no seam relays it. The AC therefore
  ships in two halves: the SHIPPED state-side half (the hole rejects at `match_state.gd:840`,
  returning at :842, BEFORE `_card_costs.get(id)` at :844, so a hole cannot reach the cost lookup at
  all -- the dev pass keeps and pins that ordering), and a FORWARD constraint binding any future
  affordability rendering. It requires no HUD code now, and the AC says so rather than implying a
  mechanism that does not exist.

**`4-0/R4` -- `_deal_player`'s fill loop is REWRITTEN to an indexed in-place write.** The Task line
"reviewed ... not necessarily rewritten" is corrected. Resolves B5.

**`4-0/R5` -- `3-5b/R8` is superseded CLAUSE BY CLAUSE, and the story carries the table.** Recorded
here as the authority so no later pass re-derives it:

| `3-5b/R8` clause | Verdict |
| --- | --- |
| The snapshot gains EXACTLY TWO new keys (`pending_draw`, `pending_draw_owed`) | SURVIVES as a key COUNT -- 4-0 adds no third key |
| `pending_draw_owed` is "a plain int COUNT and nothing more" | SUPERSEDED -- it must carry slot addresses |
| One timer plus a debt; ONE card per expiry; the window restarts while the debt is above zero | SURVIVES INTACT, and is load-bearing for `4-0/R6` |
| Both keys cross tick boundaries, which is why they are hashed | SURVIVES -- a shape change does not touch the rationale |
| "`hand_size` is permitted to reach 0" | SURVIVES, and only because `4-0/R1` binds the key to OCCUPANCY |
| "NO new rejection reason" (the constant itself) | SURVIVES IN FULL -- `REASON_EMPTY_SLOT` reused, no sibling token |
| "a cast is not gated on a pending draw" | SURVIVES NARROWED: no cast is gated on the DEBT; a cast against the slot whose OWN replacement is in flight is now refused |
| "mana stays the only throttle" | SUPERSEDED -- mana is the only ECONOMIC throttle; slot occupancy is now a second, structural, player-observable precondition |

`test_a_cast_is_not_gated_on_a_pending_draw` is re-pointed to two DIFFERENT slots, preserving the
rule it was written for. Resolves B6.

**`4-0/R6` -- the delivery shape is FORCED, not free; the story's Dev Notes are corrected.** The
pre-gate draft called the shared-`TimingWindow`-plus-owed-queue versus per-slot-window choice an open
implementation choice the dev pass would make. It was pre-decided at 3-5b, by two shipped
constraints: (a) `3-5b/R8`'s one-timer, one-delivery-per-expiry cadence, which the story's own
Deferred section preserves -- per-slot windows deliver simultaneously by construction; and (b)
`3-5b/R8`'s two-key snapshot bound, which 4-0 relaxes only for `pending_draw_owed`'s SHAPE, where
`hand_size` per-slot windows would put N `TimingWindow` dictionaries into the hash and make the
window count a hash cause every time `hand_size` is retuned. **ONE shared `TimingWindow` plus an
owed-slot queue ships.** Genuinely free: the queue's internal representation and the tie-break order,
and the tie-break is already Deferred.

**`4-0/R7` -- the Golden Prediction gains a THIRD cause and RECORDS cause 2 as measured.** Cause 3 is
the `hand_size` KEY VALUE, a non-mover if and only if `4-0/R1` is honoured, and the dev pass MEASURES
it rather than asserting it. Cause 2's measurement (N1 above) is recorded in the story and in this
entry so the dev pass never re-derives it; it re-measures only if it changes a fixture's cast count,
which nothing in this story requires. Resolves B7.

**`4-0/R8` -- the affected-test inventory is carried in the story, the vacuous invariant is
re-pointed, and the Deferred clause is corrected -- WITH the operator's extension.** Thirteen
shrink-pinning sites are listed individually in the story's Dev Notes because the gate found them by
content, not so the dev pass can re-derive them; `test_discard_pile.gd`, `test_card_observation.gd`,
`test_card_hud.gd`, `test_card_authoring.gd`, `test_determinism.gd` and `test_deck_reshuffle.gd` join
Project Structure Notes; `hand.gd:62`'s `Invariant.check` is re-pointed to OCCUPANCY with an explicit
non-vacuity note; and the Deferred section's "every owed slot is eventually filled" is replaced by
the no-misdelivery clause, which is the only part that is true. Resolves B8 and N3.

**Operator extension: the permanent hole at exhaustion is the RULED DESIGN, not an observation.**
When deck and discard are both empty, the owed slot's debt is consumed, **the hole PERSISTS, and that
slot rejects for the rest of the round. Slot stability extends to exhaustion.** This ships as its own
AC with its own test, not as a note on the degrade. The same cards are lost as today; what changes is
that the loss is now addressed to a specific, permanently-refusing slot rather than to a shorter
hand -- and the story states that as intent rather than leaving a reader to infer it from
`match_state.gd:913-916`.

### Close-out

Story `4-0-hand-slot-stability` promoted `backlog` -> `ready-for-dev` in the story file and in
`sprint-status.yaml`; the HOLD its scope note carried is DISCHARGED and the note rewritten to record
that the gate ran. **Six ACs became NINE** (the length split, the marker/no-affordable-hole AC, and
the exhaustion AC are new; the rest were amended in place). `story_notes` rewritten to the gate
outcome, one entry. No code changed this session -- docs only. Suite and golden untouched, and
re-verified unchanged at the start of the gate rather than assumed: 362/2305/23, `40eb5554...a322`.

**Base rate: 23 gates, 23 NOT READY on first reading, all 23 resolved in the session that found
them.**

**Two commits, neither pushed:** `docs(stories): 4-0 gate fixes + promote to ready-for-dev` (the
story file and `sprint-status.yaml`), then this entry, a PURE APPEND -- no existing entry edited. The
operator reviews the log and pushes.

---

## Session 2026-08-07 -- Story 4-0 close-out

AC 9 (live smoke) is discharged. It ran and PASSED, and the operator wrote the entry in
`docs/playtest-log.md` by his own hand (`7.8`), untouched by this session: casting from a
non-rightmost slot now leaves that slot empty for the 1s delivery window and the replacement lands
back in it, with no left-shift of the rest of the hand. That is the exact defect the 3-6 close-out
named and this story was authored to fix. This closes the one AC the dev pass left to the operator
and the story itself.

**Review outcome, recorded from the code-review commits, not re-derived.** `gds-code-review` ran
against `7510b5a..HEAD`. Blind Hunter and Acceptance Auditor both completed, zero AC violations. **0
decision-item findings.** Two patches, both fixed same session (`0584c5b`): `PlayerState.to_snapshot()`'s
`pending_draw_owed` key aliased the live `Array[int]` instead of returning a copy, unlike every
sibling container in the codebase (`Hand.to_array()`, `Deck.to_array()`); and `_draw_one_replacement`'s
two differently-scoped `slot` parameters, distinguished only by a prefix, renamed to `hand_slot` to
match `_resolve_basic_cast`'s existing convention. Golden confirmed UNMOVED after both patches,
`312522d8...fb3c`. One finding deferred, not fixed: AC 8's permanent post-exhaustion hole renders
identically to a slot mid-flight awaiting delivery, both a blank caption -- deferred because AC 7's
own forward constraint already scopes HUD affordability/greying rendering out of this pass, logged to
`deferred-work.md`.

**The Edge Case Hunter layer STALLED at 600s -- the SECOND stalled layer in two reviews running, and
NOT the same layer both times, which changes the diagnosis.** 3-6's review stalled the Acceptance
Auditor; 4-0's stalled the Edge Case Hunter. Two different layers, one stall each -- the suspect is
not a single fragile layer but the parallel-layer review infrastructure itself. Both times covered by
hand rather than left unrun: this session's three targeted checks were the mutation survivors X6/X8
re-proven falling against a fresh mutation, the width-vs-occupancy binding audited at every
re-pointed site across eight test files with none mismatched, and AC 7/AC 8's ordering and exhaustion
pins confirmed non-vacuous by swap/removal. Two occurrences is not yet a fix, but it is no longer a
coincidence either -- worth a look if a third review stalls a layer, any layer.

**What 4-0 leaves open.** The hole-vs-in-flight HUD distinction deferred above sits in
`deferred-work.md`, unscoped and unassigned -- no home story yet. The melee retune and the two-human
playtest remain scheduled, not resolved, per `E3-R/R3`: both wait until casts carry consequences,
which is E4 feature work this story only lays substrate for.

### Close-out

Story `4-0-hand-slot-stability` promoted `ready-for-dev` -> `done` in the story file and in
`sprint-status.yaml`; the story file's own Status field carries `done`; `story_notes` rewritten to
the closed outcome, one entry. No code changed this session -- docs only. Golden and suite untouched,
`373/2397/23`, `312522d8c597be8ba99f2beea56a8c7bdbfef48dd1f2eff1b8f6f49164c0fb3c`.

**Three commits, none pushed:** `docs(playtest-log): 4-0 slot stability smoke` (the operator's entry,
committed verbatim as found in the working tree), `docs(stories): 4-0 close-out` (the story file and
`sprint-status.yaml`), then this entry, a PURE APPEND -- no existing entry edited. The operator
reviews the log and pushes.

## Session 2026-08-07 -- E4 ratification, `E4-P/R1`-`E4-P/R11`

Planning report delivered report-only; operator ratified it with amendments below. Rulings recorded
here are the authority; CLAUDE.md's Story tiers section (E4-P/R9) points back to this entry rather
than restating it.

### Pre-write re-verification (claims checked against the repo, not taken on the prompt's word)

- **D9 sentence.** `docs/game-architecture.md` D9 (pre-fix) stated `PlayerState` "reserves a
  `units`/board collection." `player_state.gd` carries zero `units`/`board`/`Targeting`/`ObjectPool`
  tokens -- the sentence described unbuilt work as already reserved in code. `src/systems/pool/`,
  `src/actors/minions/`, `src/actors/totems/`, `src/actors/projectiles/`, and `data/minions/` all
  contain only `.gitkeep`; `object_pool.gd` and `minion_priority.gd` do not exist anywhere in the
  tree. Corrected in the same-session `docs(architecture)` commit (A6), naming the owning story per
  seam instead of a bare epic label.
- **Fixture spell/summon split.** Exactly 3 of 9 authored cards (`bramble_snare`, `ember_lash`,
  `frost_dart`) carry `spell_*` effect ids; the other 6 (`hellforge_totem`, `imp_summoner`,
  `storm_kite`, `thornback_guardian`, `tidal_wardstone`, `verdant_wardstone`) carry `summon_*`.
  Matches the prompt's premise exactly.
- **State-layer card-data guard.** `test_state_layer_never_names_card_data` bans exactly the regex
  `(CARDS_DIR|data/cards)`, scoped to `src/state/`, with its own non-vacuity pair (the tokens must
  appear in `card_database.gd`; the scan must visit files). R4/R10 rely on this guard staying green
  unedited -- confirmed it does not need touching for E4.

### R7 measurement -- where hero position lives (recorded per the obligation, not decided here)

`hero_state.gd:5` states outright: "Pure RefCounted -- no scene, no Input, no position (position is
actor-owned, F1)." State owns `velocity`, `facing`, `roll_direction` -- intent/derived quantities --
never a position. `match_runner.gd:_gather_contact_facts` (line 606) reads `actor.global_position`
directly off the scene node (`HeroActor`, line 624), computes the contact direction fact from it,
and pushes ONLY that derived fact into state via `push_contact` (1-7's channel). This is exactly the
1-8 contact-fact precedent R7 named in advance: position lives on the actor node, never in state;
the runner computes a fact FROM node positions and injects the fact, not the position. The premise
holds -- it does not contradict R7. Consequence for 4-1's gate: if minion position is put directly
into state (rather than living on the minion's actor node with the runner deriving facts from it,
same as the hero), that is a new architectural asymmetry against the hero precedent, not a forced
choice, and 4-1's gate must ask this explicitly rather than default to whichever seems more
convenient for `TargetingService`.

### The rulings (as ratified, one clause of reasoning each -- narrative lives in the planning report, not restated here)

`E4-P/R1` Story order: 4-0 (done) -> 4-0a (D9 reconciliation) -> 4-B1 (card-HUD debt discharge) ->
4-1 (basic-summon resolution) -> 4-2 (minion AI + throttled targeting) -> 4-3 (minion combat) -> 4-4
(totems, three subtypes) -> 4-5 (pooling + 60 FPS exit criterion). 4-B1 sits at position 2 because it
is Tier B, discharges an escaped E3 obligation, and exercises the Tier B lane before feature work
leans on it. Melee retune is not a story -- E3-R/R3 already fixed its shape; it runs once 4-3 gives
casts consequences. Naming: 4-0 keeps its pushed, unsuffixed name; further substrate takes 4-0a,
4-0b.

`E4-P/R2` The `PlayerState` board collection ships INSIDE 4-1, with its first consumer, not as a
standalone 4-0b -- `card_effect.gd`'s own precedent (reserved vocabulary authored ahead of its
consumer, carried unconsumed since 3-2) is the shape to avoid repeating without cause. NAMED BREAK
LINE: if 4-1's readiness gate returns more than 8 blocking findings, it splits into a state/board
half and an actor/spawn half via `gds-correct-course` -- named now so a split is planned, not a
rescue.

`E4-P/R3` 4-0a is a docs commit riding this pass, not a board story -- one false sentence plus
mislabeled empty seam directories carries no acceptance criteria (precedent: `6067d9e`). It lands
before E4's first gate reads D9, not deferred to a close-out flush (E3 retro lesson 4). Discharged
this session; see the pre-write re-verification above and the `docs(architecture)` commit.

`E4-P/R4` Card effects reach the state layer by one-shot injection at match start, keyed by
`effect_id` -- precedents `inject_deck` (3-3) and the one-shot cast-cost map (3-5a); the state layer
never names `CARDS_DIR`/`data/cards`, and `test_state_layer_never_names_card_data` stays green
UNEDITED. 4-1's gate does not relitigate this.

`E4-P/R5` Data-defined minion priorities need no new shape decision -- a `MinionPriority` `.tres`
naming a selection rule, resolved by a pure static evaluator in `src/state/`, is the D6 precedent
(`ResourceGenerationRule`/`EconomyEvaluator`, 3-4; `CastEvaluator`, 3-5a) applied unchanged. 4-2's
gate inherits this instead of rediscovering it.

`E4-P/R6` Any `.tres` injected into the state layer joins golden discipline, treated as code -- the
same narrowing of `BC/R3` that `3-4/R6` applied to `data/economy/`. Covers the card-effect map (R4)
and `data/minions/*.tres` (R5). Named here so no gate discovers it as a finding.

`E4-P/R7` Throttled targeting's shape is decided at 4-2's readiness gate, as rulings -- it is a
determinism decision, not a performance one: a shared throttled tick inside `advance()` at fixed
delta is hashable, `Area3D` overlap queries are physics-frame and live outside the state layer and
are not hashable, and `epics.md`'s "and/or" hides that these place the targeting fact on opposite
sides of the state/visual seam. OBLIGATION ON 4-1's GATE, discharged above: 4-1 must ask explicitly
where a unit's position lives, with the 1-8 contact-fact precedent in hand. Measurement recorded
above -- hero position is actor-owned, never state-owned; putting minion position directly in state
would be a new asymmetry, not a forced choice, and 4-1 must not settle it incidentally.

`E4-P/R8` Object pooling needs no shape decision now -- building a pool before one minion exists is
speculative machinery (architecture Binding Constraint #1; `3-0d/R20`). What it needs is a failure
criterion declared in advance: "many units" and "60 FPS holds" are numbers fixed at 4-5's gate before
any measurement is taken. 4-5's tier is assigned at 4-1's close-out, once the unit-ownership ruling
exists -- genuinely undecidable today.

`E4-P/R9` Story tier policy. Every story is assigned a tier at authoring, before its first pass.
Tier A -- touches `src/state/`, the golden, determinism, or replay: full ritual (readiness gate with
numbered rulings -> dev pass -> code review -> live smoke where R-D6 attaches -> close-out),
decision-log entry carries rulings and narrative. Tier B -- touches only HUD/presentation, data
authoring, tooling, or docs, AND a measured before/after shows the golden and the snapshot key set
unmoved: skill chain `gds-create-story` -> `gds-dev-story` -> `gds-code-review`, close-out folded
into one commit, decision-log entry capped at rulings, no narrative. THE GOLDEN CLAUSE IS DECISIVE --
a story that moves the golden is Tier A regardless of how much it feels like data authoring. Tier is
assigned at authoring and may be RAISED, never lowered, mid-story; a Tier B story found to move the
golden stops and is re-gated as Tier A.
AMENDMENT 1 (operator): Tier B removes the separate gate PASS, not the gate -- the
`gds-create-story` checklist plus operator review before promotion to ready-for-dev remains. Every
gate in project history returned NOT READY on first reading (22/22); Tier B buys back the pass cost,
not the correction point.
AMENDMENT 2 (operator): if a THIRD code-review layer stalls, Tier B is SUSPENDED rather than
hand-covered -- two consecutive reviews have stalled a different layer each time (3-6 Acceptance
Auditor, 4-0 Edge Case Hunter), and Tier B leans on that infrastructure harder than Tier A does. Part
of the policy text, not a footnote.
TIER ASSIGNMENTS: 4-0a B (docs commit) | 4-B1 B | 4-1 A | 4-2 A | 4-3 A | 4-4 A (arguable -- the two
accelerator totems are pure `.tres` authoring against a shipped evaluator seam, and it is Tier A only
because it moves the golden, which is exactly why the golden clause must be decisive rather than
intuition) | 4-5 UNDECIDED, assigned at 4-1 close-out (R8) | melee retune B by policy.
HOME: this ruling is the authority. Second home: `CLAUDE.md`'s "Story tiers" section, a pointer only
-- `project-context.md` is not touched, since CLAUDE.md describes it as derived from the GDD and
architecture doc, and a process policy is derived from neither.

`E4-P/R10` `spell_*` effect ids: 3 of 9 fixture cards carry them (confirmed above), and none of E4's
GDD commitment (minions, pooling, targeting, totems) is spells. A `spell_*` id reaching the resolver
is NOT a rejection case -- the cast already passed `CastEvaluator`, mana is spent, the discard is
recorded. RULING: spell cards stay castable, the resource is spent, and the resolver takes a NAMED
NO-OP with an explicit reason, never a silent swallow. Excluding spell cards from the E4 deal is
refused -- it would move the golden for no feature reason and drop three of nine cards from every
test. The no-op is proven in both directions (summon_* resolves; spell_* takes the named path) per
the non-vacuity doctrine. Spell resolution acquires an owner at the E4 close-out at the latest.

`E4-P/R11` Out of E4, named so scope cannot creep: all of E5 (modes 2/3, chargeup/color telegraph,
the three-tier ladder, per-color damage, orbs and their HUD, color-as-defense,
`ActionState.CHARGING`, open decision (a), S6); all of E6 (mode 4 pitch -- `pitch_effect` stays
UNAUTHORED on every card, even while touching cards for summons); E7 bot, E8 equipment; spell
resolution as a feature (R10); reshuffle vulnerable-window mechanical cost (`3-5b/R7`); whether hand
size ever varies (open, bounded <= 4 by `3-6/R8`); camera always-lock-on/retarget (no owner -- NOTE:
a board full of minions may hand this a forcing point during E4; if so, that is a
`gds-correct-course`, not silent adoption); S5 audio feedback on a successful cast (4-1 partially
discharges S5 by construction -- a successful cast puts a visible unit on the board -- the audio half
stays unhomed); peripheral mana/deck legibility (operator-deferred until the full loop exists at E6;
not folded into 4-B1); GDD-authority items (minion/spell healing, netcode, Best-of-3/sideboard,
multiple arenas, real minion/totem art -- grey-box, legibility is the only hard visual bar);
procedurally, no new board status for E4 and no E4 retrospective until E4 closes.

### Close-out

Docs-only pass, four commits, none pushed: `docs(architecture)` (D9 correction, A6), this entry
(`docs(decision-log)`), `docs(sprint-status)` (epic-4 section opened, R1 order, R9 tiers, 4-0
untouched), `docs(claude-md)` (Story tiers pointer section). No code changed, no golden or suite
touched. Operator reviews the log and pushes.

---

## Session 2026-08-08 — gds-create-story override

`CFG/R1` `gds-create-story` Step 5/6 sets a story's `Status` to `ready-for-dev` and flips its
sprint-status.yaml entry from `backlog` to `ready-for-dev` unconditionally. This project never
promotes a story straight from authoring to dev-ready -- a readiness gate (Tier A) or an operator
review (Tier B) always sits between. RULING: the mismatch is corrected via
`_bmad/custom/gds-create-story.toml`'s `on_complete`, which runs after Step 6's writes and reverts
them, rather than by editing the shared skill. — _decided by Matko._

`CFG/R2` The sprint-status.yaml board lifecycle stays locked at exactly `backlog` ->
`ready-for-dev` -> `done`, per its own STATUS DEFINITIONS. Not amended, not extended. — _decided by
Matko._

`CFG/R3` `authored` is introduced as a story-file-only `Status:` value, meaning "authored, awaiting
operator review" -- it is deliberately NOT added to sprint-status.yaml's STATUS DEFINITIONS; the
board entry for such a story reads `backlog`, with the finer-grained state carried in the story
file's own `Status:` field and echoed in `story_notes`. — _decided by Matko._

`CFG/R4` Promotion of a story to `ready-for-dev` is a human act, never a skill's. No workflow may
set that board value unconditionally on completion. — _decided by Matko._

`CFG/R5` `review` is the second story-file-only status ("implemented, awaiting review"), per the
CFG/R3 `authored` precedent; the board never carries it. — _decided by Matko._

---

## Session 2026-08-08 — 4-B1 review rulings

`4-B1/R1` The reveal-opponent-hand toggle lives on the DebugInstrumentPanel surface, NOT in
HudRoot. Data path: the runner hands the panel a read accessor for opponent hand contents through
the existing Callable-handoff pattern (the gamepad_profile/huds precedent, 3-0d AC 7) -- no new
observation seam; `test_runner_observation_seams_are_exactly_eight` is not amended. The
four-control pin in `test_record_save_control.gd` IS amended, as a reviewed, named exception per
the `3-6/R2` precedent. Panel geometry (fifth control: new column vs band resize) is an
implementation choice for the dev pass. — _decided by Matko._

`4-B1/R2` The toggle is debug-only. The GDD lock ("hands are private; the pitched card is the only
public information", 2-5/R9) stands untouched; the toggle must never be reachable in the shipped
default configuration. An authored gameplay reveal option remains a separate future design ruling
nobody has requested. — _decided by Matko._

---

## Session 2026-08-08 -- 4-B1 close-out

`4-B1/R3` The code review's D1 finding is fixed state-side, inside this story: `player.notify_cards_changed()`
added on both silent-pop paths (`_deliver_pending_draw`'s DEAD branch, `_draw_one_replacement`'s
both-empty degrade), a named, measured exception to "no `src/state/` change" -- golden and snapshot
keys measured UNMOVED. — _decided by Matko._

`4-B1/R4` Default-off is sufficient today; a build gate is a named deferral owned by the first story
with a distributable build, and must gate the whole panel. — _decided by Matko._

`4-B1/R5` Smoke scope: the in-flight half live; the both-empty half discharged by the
state-crossing integration test (unreachable in natural play, measured). — _decided by Matko._

`4-B1/R6` The 4-B1 review was the THIRD consecutive run with one stalled parallel layer; per the
ratified E4-P tier policy this SUSPENDS Tier B; un-suspension is owned by the upcoming
retrospective. — _decided by Matko._

`4-B1/R7` The reveal output's medium is the console; the on-screen label is removed (a band-locked
label cannot legibly carry two hands, both HUDs already render the hands on screen, and the console
gives the operator a copy-pasteable record). — _decided by Matko._

---

## Session 2026-08-08 -- process retrospective (Tier B pilot, workflow cost)

Ratifies the REPORT-ONLY process retrospective on story `4-B1`. Evidence, measurements and the
reasoning behind each ruling live in `docs/implementation-artifacts/process-retro-2026-08-08.md`;
this entry carries the rulings only. Not an epic-4 retrospective (`E4-P/R11` stands).

`PROC/R1` Suite cadence. The full suite runs EXACTLY TWICE per pass -- once at open, once at close.
Mutation proofs run ONLY the affected test file, never the full suite. Evidence: `4-B1`'s dev pass
ran the suite about six times where two would do, and the review's provenance audit found the Dev
Agent Record's "Full suite re-run green after every restore" unevidenced -- the mutation table's
four rows each name a single test run. The measured full-suite cost is 1m35s, so the surplus was
~6-7 min; the rule is adopted because it is nearly free and it removes an unevidenced claim class,
not because it is the main cost saving. Applies to both tiers. — _decided by Matko._

`PROC/R2` Review shape. `gds-code-review` runs TWO parallel adversarial layers. The Acceptance
Auditor's checks move INLINE into the main review session as a MANDATORY checklist -- the checks are
preserved, only the flaky parallel infrastructure is removed. The checklist explicitly includes the
DEV AGENT RECORD EVIDENCE AUDIT, the only check that audits the record rather than the code. When
that audit falsifies a claim in the record, the fix pass ANNOTATES THE CLAIM IN PLACE
("[corrected -- see Review Findings]") rather than leaving the correction only in a later section,
so a reader hitting the record first cannot read the wrong thing. Every review records a
LAYER-COMPLETION LINE naming each declared layer with its terminal state, on the shape `4-B1`'s
review already emits; a review missing that line COUNTS AS A STALL. Applies to both tiers.
— _decided by Matko._

`PROC/R3` Edit fallback. On the FIRST failed Edit-tool match against a file carrying em-dashes or
tabs, switch immediately to a python byte-replace. No repeated Edit attempts. The hazard is
structural rather than incidental: the decision-log, every story artifact and `deferred-work.md` are
dense with em-dashes and mix them with `--`, while every `.gd` source is tab-indented, so any
docs+code story meets both. Applies to both tiers. — _decided by Matko._

`PROC/R4` Tier B bookends. Browser touchpoints for a Tier B story are exactly three: STORY OPEN,
CROSS-STORY RULINGS, and CLOSE-OUT. Checkpoint questions arising mid-pass are put to the operator
DIRECTLY IN-SESSION -- precedent, the `4-B1` review, which put D1's tier question to the operator
inline and received `4-B1/R3` back without a browser round trip. THE CHANNEL CHANGES, THE AUTHORITY
DOES NOT: CLAUDE.md's agent-autonomy test still splits design from implementation, and a design
question is still the operator's regardless of which surface it is asked on. Tier B only.
— _decided by Matko._

`PROC/R5` Home split for standing rules. Tier POLICY stays where `E4-P/R9` put it -- the
decision-log as authority, `CLAUDE.md`'s "Story tiers" section as a pointer. Per-tier OPERATIONAL
rules (suite cadence, review shape, edit fallback, budget, text fit) live in `project-context.md`'s
Testing Rules, each ending in its ruling id. `E4-P/R9`'s clause "`project-context.md` is not
touched, since ... a process policy is derived from neither [GDD nor architecture]" is hereby
NARROWED to tier policy: it does not describe what that file already contains, since its Testing
Rules already carry three pure process rulings (`3-0d/R14` mutation-proof discipline, `3-0d/R20`
guard mechanism over guard pattern, and the adversarial-review failure criterion from the 3-0d
close-out). The operational precedent was already present; this ruling names it. — _decided by
Matko._

`PROC/R6` Tier B is UN-SUSPENDED, and the stall counter RESETS TO 0 at this ratification rather than
resuming at 3. `4-B1/R6` suspended Tier B under `E4-P/R9` AMENDMENT 2, whose stated predicate is the
PARALLEL-LAYER INFRASTRUCTURE ("Tier B leans on that infrastructure harder than Tier A does"), not
review quality and not Tier B's economics. `PROC/R2` deletes the stalling layer from the chain, so
the counted mechanism no longer exists and the count has no subject -- guard mechanism over guard
pattern, `3-0d/R20`, applied to a process counter. Under the new two-layer shape, THREE CONSECUTIVE
STALLS RE-SUSPEND, and a review missing its layer-completion line counts as a stall, so silence
cannot be mistaken for success. — _decided by Matko._

`PROC/R7` Tier B machine-time budget. A Tier B story of `4-B1`'s size (two ACs, one presentation
surface, no `src/state/`) costs AT MOST ~1 h, counted as dev pass plus code review agent-side wall
clock. EXCLUDED from the count: the operator's own live smoke, browser ruling turns, and close-out
doc and commit work -- none of which the session controls. A larger Tier B story STATES ITS OWN
BUDGET AT AUTHORING rather than inheriting this one. Sessions note their start time and compare
against the budget at full-suite boundaries (the two `PROC/R1` runs), which is where a natural
checkpoint already exists. TRIPWIRE: on crossing the budget, STOP AND REPORT the remaining work to
the operator -- never push through. Scaling the work down is the operator's call. Recorded honestly:
`PROC/R1`-`R4` together would have saved `4-B1` an estimated 25-35 of its ~113 min, landing it at
~80-90 min, still over this budget; the tripwire, not the four rulings, is what enforces it.
Tier B only. — _decided by Matko._

`PROC/R8` Text fit is not machine-checkable by the agent. Machine checks assert GEOMETRY ONLY -- a
rect's position and clearance, as `test_debug_instruments.gd`'s layout guard does. The agent NEVER
asserts on-screen text fit from character counts, font sizes or estimated metrics. Any AC hinging on
ON-SCREEN LEGIBILITY goes to OPERATOR SMOKE AT FIRST RENDER, before any further machine pass on that
surface. Evidence: `4-B1`'s two reveal-label passes each verified the rect (`panel_layout=true`, both
viewports) and never the text fit, and both were rejected on sight for the same reason; only the
third pass changed the medium (`4-B1/R7`, the console) instead of the font. A guard that cannot fail
for the reason the operator will reject the work is a vacuous guard, which this repo treats as worse
than none (`3-0d/R20`). This is the largest single cost sink `PROC/R1`-`R4` do not address. Applies
to both tiers. — _decided by Matko._

`PROC/R9` Board writes. `sprint-status.yaml` lifecycle writes made by skill `on_complete` hooks are
EXPECTED WORKING-TREE EFFECTS of running the skill, not authoring choices -- `gds-dev-story` Step 9
writes the board and `_bmad/custom/gds-dev-story.toml` reverts it (`CFG/R2`, commit `fceed8b`).
Commit separation is owned by the CLOSE-OUT CHAIN, which sorts such a write into the docs commit. A
dev pass whose working tree therefore shows `sprint-status.yaml` modified DOES NOT BREACH "docs and
code never share a commit" -- the convention binds what lands in a commit, not what a skill leaves
in the tree. `4-B1` raised the question by having the file in its diff and absent from its File
List; the File List omission was the real defect, and `PROC/R2`'s evidence audit is what catches it.
— _decided by Matko._

### Close-out

Docs-only pass, four commits, none pushed: `docs(retro)` (the retrospective record),
`docs(decision-log)` (this entry), `docs(config)` (five operational bullets appended to
`project-context.md`'s Testing Rules per `PROC/R5`, `rule_count` bumped), and `board` (the stale
`sprint-status.yaml` header comment corrected -- STATUS DEFINITIONS untouched, no status value
changed). `CLAUDE.md` is NOT touched: its Story tiers section is a pointer to `E4-P/R9`, and no tier
policy changed here. No code changed, no golden or suite touched. Operator reviews the log and
pushes.

---

## Session 2026-08-08 -- 4-1 readiness gate

Verdict: **NOT READY** on first read, 7 blocking findings -- `R1`/`R2`/`R3` counted as ONE work
package, below the `E4-P/R2` break line of 8, so NO SPLIT. Rulings applied in place to the story
file this same session; promotion to `ready-for-dev` follows.

`4-1/R1` (BLOCKING, accepted) The `IntentRecorder` scope was incomplete. The "one capture method +
two pins" task is replaced with the full content-channel package: `intent_recorder.gd` gains
`CHANNEL_EFFECTS`, a 3-element `SOUND_CONTENT_ORDER`, `_effect_values` storage, a
`missing_match_start_channels()` branch, `replay_card_effects()`, and a `replay_inject_content()`
branch. `record_file.gd` gains `REQUIRED_KEYS`, `_to_dictionary`/`_from_dictionary`'s content-order
match, and `FORMAT_VERSION` 1 -> 2; v1 records are REFUSED with a reason, no migration shim (records
are debug artifacts). Tests that MOVE, named as deliberate pin updates: `test_record_file.gd`
round-trip-carries-every-channel + its derived key-set test; `test_intent_recorder.gd`
`EXPECTED_INTAKE_SURFACE` + content-order tests; `test_live_reload.gd` THREE edits
(`SHIPPED_CAPTURE_CHANNELS` 8 -> 9, the literal eight-name array, and that test's name);
`test_replay_identity.gd`; `test_record_save_control.gd`; `test/replay_drive.gd`;
`test/tools/replay_file.gd`. -- _decided by Matko._

`4-1/R2` (BLOCKING, accepted) New AC -- replay parity. In replay mode, card effects arrive via
`_replay_record.replay_inject_content()` from the record, never re-derived from `CardDatabase`; the
replay identity coverage extends to it; unit spawn behaviour is identical live vs. replay.
-- _decided by Matko._

`4-1/R3` (BLOCKING, ruled -- option (a)) The refusal mechanism is RETURNED NAMED VALUES, with TWO
distinct named reasons: (i) missing-entry honest default (no injected entry for the cast id, the
`cast_evaluator.gd` null-branch precedent, reachable via an effects-less fixture, a DIRECTED test)
and (ii) unknown-prefix refusal (entry exists, `effect_id` is neither `summon_*` nor `spell_*`,
proven with a synthetic map entry in a unit test). NEVER an `Invariant.check` crash (`3-0c/R15`:
unprovable), NEVER `reject_action`. Injection is state-side OPTIONAL -- existing `MatchState`
fixtures stay untouched and their casts land on reason (i); record-side it is MANDATORY for v2
records (`missing_match_start_channels()` treats a missing effects channel as malformed). A guard
proves the LIVE runner path always injects (derive+inject pair present in the non-replay branch).
-- _decided by Matko._

`4-1/R4` (BLOCKING, accepted restatement) AC 3 must not claim a measurable golden move from a
`.tres` edit -- the gate measured the golden deck as synthetic with in-test costs, so no such
binding exists (standing `BC/R3` isolation). AC 3 restated: `effect_id` joins golden discipline BY
RULING (`E4-P/R6`) -- a determinism-relevant class of change carrying review burden -- plus the
machine half: an authoring test asserting every authored `basic_effect.effect_id` carries a
recognized prefix (`summon_` or `spell_`). -- _decided by Matko._

`4-1/R5` (BLOCKING, ruled) Units are cleared ONLY on the reset path (`_apply_debug_reset`);
`_end_round` stays untouched -- the board persists through the round-over freeze and does not blink
out at the instant of death. `_apply_debug_reset`'s "NOTHING else" contract comment gains a NAMED
exception for units; the parked mana-survives-reset finding stays parked. AC 8 amended accordingly.
-- _decided by Matko._

`4-1/R6` (BLOCKING, ruled) Golden Prediction cause 2 names the fixture decision: the golden fixture
INJECTS effects and the card cast at tick 22 carries a `summon_*` effect id -- the behavioural cause
is real and measurable (`unit_count` `0 -> 1` in the hashed snapshot) and the resolver sits inside
determinism coverage. -- _decided by Matko._

`4-1/R7` (non-blocking, accepted) Snapshot attribution corrected: the per-player snapshot and its
pinned key set live in `player_state.gd` / `test_card_observation.gd`, not `match_state.gd`'s
match-level dict. -- _decided by Matko._

`4-1/R8` (non-blocking, accepted) Injection order stated explicitly: deck -> costs -> effects (the
totality check reads `_deck_contents`; the `3-0c/R11` vacuous-pass trap applies verbatim to
effects), and `CHANNEL_EFFECTS` sits at the END of `SOUND_CONTENT_ORDER`. -- _decided by Matko._

`4-1/R9` (non-blocking, accepted) Folded into `R1`'s `test_live_reload.gd` package, recorded here
as its own ruling: the three named edits (channel count, literal array, test name) are a deliberate
pin update, not a widened regex. -- _decided by Matko._

`4-1/R10` (non-blocking, accepted) AC 5's stated reason is a RETURNED VALUE only, asserted in unit
tests, explicitly OFF the `reject_action` seam -- a spell no-op is a successful cast and must not
render a refusal to the player. -- _decided by Matko._

`4-1/R11` (non-blocking, accepted) Live Smoke amended -- `R-D6` is RE-INVOKED on this gate (measured
SPENT since 3-6; this is the next player-facing story with a live smoke). The smoke script includes
a kill and the `R-D6` acceptance ride-along. -- _decided by Matko._

`4-1/R12` (BLOCKING, ruled) The units record ships POSITIONLESS this story -- position stays
actor-owned, hero precedent unchanged; the real position-ownership decision is deferred to `4-2`'s
gate where a consumer exists. AC 9's wording is SCOPED to this story's snapshot key ("the key(s)
added by this story carry no unit identity, no effect id, no position"), explicitly NOT a standing
bound -- it must not foreclose the state-owned option at `4-2`. Both named futures (inward position
channel vs. state-owned floats in the hash) recorded in Dev Notes as `4-2` gate input.
-- _decided by Matko._

**Totem clause** (measured pass, ratified): the unit record carries NO type/kind field, stated
explicitly -- uniform `summon_*` treatment therefore does not pre-commit `4-4`'s totem/minion
differentiation. `4-4`'s second golden move is already ratified as its own Tier A reason
(`E4-P/R9`), independent of this story. -- _decided by Matko._

### Close-out

Docs-only pass, one commit, not pushed: the story file amended in place per `4-1/R1`-`4-1/R12` +
the totem clause (Change Log entry 0.2), this decision-log entry, and the board promotion
(`sprint-status.yaml` `4-1-basic-summon-resolution` `backlog` -> `ready-for-dev`, story Status
header `authored` -> `ready-for-dev`, `CFG/R4`). No code changed, no golden or suite touched.
Operator reviews the log and pushes.

---

## Session 2026-08-10 -- 4-1 close-out

Dev pass (Claude Opus 5, 2026-08-09) delivered all ten ACs; code review (`gds-code-review`) and
live smoke both discharged. Story promoted `review` -> `done`; board promoted `ready-for-dev` ->
`done`.

**Review outcome (OPERATOR-REPORTED).** Verdict PASS, zero patches. Blind Hunter: 12 findings
raised, 11 refuted on verification, 1 surviving LOW non-blocking -- the v1-refusal test rewrites
the record version to `FORMAT_VERSION + 41` rather than literally `1`, same code path
(`version != FORMAT_VERSION`), deliberately NOT patched since verification is not recursive. Edge
Case Hunter STALLED (600s watchdog, no layer-completion line); operator ruled accepted without
retry. `PROC/R6` stall counter now 1 -- the FOURTH consecutive review run carrying one failed
layer, flagged as input to the next process retrospective, not actioned here. Inline
acceptance-auditor checklist 10/10 PASS, including the Dev Agent Record evidence audit.
-- _decided by Matko._

**Live smoke outcome (OPERATOR-REPORTED), 2026-08-09.** PASS on the shipped default config, zero
`.tscn` edits: summon casts put a persistent grey-box unit on the board; spell casts resolve
normally (mana spent, discarded, replacement owed) with nothing appearing; units SURVIVE the kill
and the round-over freeze (`4-1/R5` confirmed live); a reset clears both boards; fps stable.
`R-D6` was re-invoked at this gate (`4-1/R11`) and is now CONSUMED again on a live kill against a
killable human slot. -- _decided by Matko._

`4-1/R13` (accepted) The dev pass's implementation decision -- summon resolution gated on
`FeatureFlags.minions`, with `data/feature_flags.tres` turning the flag ON -- is ACCEPTED. The
review's targeted check 1 verified the gate live; no alternative was proposed. -- _decided by
Matko._

**Golden chain, three hashes, two separately named causes (both isolated in the dev pass, ratified
here):** `312522d8...fb3c` (pre-story) -> `542a05c0...dcbda` (SNAPSHOT-SHAPE cause -- the
`unit_count` key entering the hash at an all-zero, no-op value before any summon is cast) ->
`78bd2b97...b0b5e5` (BEHAVIOUR cause -- the t22 `summon_*` cast measurably moving `unit_count`
`0 -> 1`, `4-1/R6`). `rng_state` confirmed a non-mover. `78bd2b97...b0b5e5` is the new `GOLDEN`.
-- _decided by Matko._

`E4-P/R8` (discharged) `4-5-pooling-60fps-exit` is assigned TIER B. `4-1` shipped units
actor-owned with counts-only state, so pooling is runner/presentation machinery, not a
state-layer concern; the ratified golden clause is the proof obligation (before/after golden AND
the snapshot key set unmoved). The "many units" / "60 FPS holds" numbers must be fixed in the
story before any measurement is taken. Tier may be raised later, never lowered mid-story.
`sprint-status.yaml`'s `4-5` comment updated from "Tier UNDECIDED" accordingly. -- _decided by
Matko._

**Deviations, reported not silently absorbed:**
1. The dev pass ran the full suite FOUR times, not the two `PROC/R1` allows (already recorded in
   the story's own Dev Agent Record). Run 2 (close) went RED because three integration tests
   (`test_replay_contacts.gd`, `test_replay_entry_is_inert.gd`, `test_replay_verifier_tool.gd`)
   hand-build `IntentRecorder` records and sit OUTSIDE the readiness gate's `4-1/R1`
   moving-tests enumeration; all three tripped the new malformed-record guard. This is a
   GATE-LIST GAP, not a dev error -- the gate's enumeration missed three existing consumers of
   the content-channel package it was itself expanding. Run 4 was avoidable waste (a recount, not
   a fix).
2. This close-out pass ran the full suite TWICE, exceeding its own "at most one" budget: run 1
   confirmed green pre-staging; the pre-commit collateral scan then found two new test files
   (`test_summon_actor_live.gd`, `test_card_effect_resolution.gd`) had shipped without their
   `.uid` siblings -- the dev pass's editor scan checked only the three new `class_name`s, not
   plain test scripts. The editor scan was re-run to generate them (`project.godot` SHA
   unchanged), and a second full-suite run confirmed nothing regressed. Another gate-list gap: no
   close-out precondition names a `.uid`-completeness scan for test files specifically.

### Close-out

Four commits, none pushed: `story 4-1: basic summon resolution` (all code/tests/scenes/data,
incl. the two `.uid` files this pass generated); `docs(4-1): dev pass record` (Review Findings
section, Live Smoke result, two Change Log rows, supplementing the dev pass's own record without
replacing it); `board: promote 4-1-basic-summon-resolution to done` (`sprint-status.yaml`
`ready-for-dev` -> `done`, story Status header `review` -> `done`, `4-5`'s comment `Tier
UNDECIDED` -> `Tier B`, `CFG/R4`); this decision-log entry. Suite green throughout (399 state /
2517 assertions + 24 integration). Operator reviews the log and pushes.

---

## Session 2026-08-10 -- 4-2 readiness gate

Docs-only ruling pass on the authored `4-2-minion-ai-throttled-targeting.md` (Status `authored`).
Sixteen rulings, all applied to the story in place. No code changed except two comment-only
ownership corrections, landed in their own separate commit per `4-2/R4`.

`4-2/R1` (BLOCKING, ruled) AC 4 restated on the `4-1/R4` template: it previously asserted a
measured golden dependency the Golden Prediction itself called conditional. `.tres` content under
`data/minions/` joins golden discipline BY RULING (`E4-P/R6`), plus a machine half -- an authoring
test asserting every `.tres` there loads as a `MinionPriority` with recognized parameters. The
"load-bearing for the hash" claim moves to the Golden Prediction, unconditional there because of
`R2`.

`4-2/R2` (BLOCKING, ruled) The applied target is a HASHED INDEX PAIR, `[slot, index]`, on the
`pending_draw_owed` precedent (`player_state.gd:94-95`) -- both plain ints, `index >= 0` a board
unit, `index == -1` that player's hero. No identity, no object, no `StringName` reaches the hash.
New AC 11 states this. -- _decided by Matko._

`4-2/R3` (BLOCKING, ruled) Candidates are the OPPOSING side only -- opposing hero plus opposing
board units; own-side units are never candidates. THE tie-break is slot ascending (fixed P1 -> P2,
`match_state.gd:177`) then board index ascending -- the "or an equivalent stable, authored
ordering" alternative is deleted. -- _decided by Matko._

`4-2/R4` (BLOCKING, ruled) Minion MOVEMENT is out of this story, owned by 4-3 -- without movement
a distance-based mechanic over the runner's decorative placement row would be fake. Deferred
section states this in those words; the two shipped comments naming 4-2 as movement owner
(`src/actors/minions/unit_actor.gd:16`, `src/main/match_runner.gd:130`) are re-pointed to 4-3 in
their own comment-only commit, separate from the docs commit. -- _decided by Matko._

`4-2/R5` (BLOCKING, ruled) AC 7's cadence, all four parts: (a) `minion_retarget_interval_seconds`
(`BalanceConfig`) plus derived `minion_retarget_interval_ticks` (`BalanceTicks`), on the
`draw_replacement_delay_seconds` precedent; (b) `apply_balance` untouched, a cadence is not a
per-pool bound (`3-1/R2`); (c) the counter is `_tick % interval`, no new state, no new hash key;
(d) the interval clamps to at least 1 tick, so an authored 0 means every tick. `_golden_config()`
must author a real cadence or the throttle measures a false non-move -- a task, not a hope.

`4-2/R6` (BLOCKING, ruled) Every AC gets a named falsifiable test on its task line. AC 6 needs the
positive direction (a target IS acquired against a populated candidate set); AC 7's throttle needs
a behavioural negative (the candidate set changes mid-interval, the target does not change until
the boundary tick, and does change at it) -- not instrumentation counting. A task also updates or
asserts the snapshot key-set pin (`test_card_observation.gd`).

`4-2/R7` (non-blocking, accepted) Discharged by `R14`, not by argument: no new recorded fact
channel, `FORMAT_VERSION` stays 2. A unit's board record and the directory-scanned
`MinionPriority` are DERIVED STATE and CONTENT, not record channels. Residual hazard named: a
replay reproduces a run only if `data/minions/` is unchanged, as `data/economy/` already requires.

`4-2/R8` (non-blocking, measured) AC 9's identity extension moves neither the key set nor the
golden on its own -- `UnitBoard` is a bare int, `unit_count` unchanged either way. Added to the
Golden Prediction as a predicted non-mover, confirmed by the key set holding at ten if no key
ships; the golden's two real movers this story are `R2`'s key and its behaviour.

`4-2/R9` (non-blocking, accepted) DEBT B is fully discharged; a new `data/minions/` `load()`
inherits nothing from it. `CACHE_MODE_IGNORE` exists only on `BalanceConfigService.reload()`,
only because balance has a live reload trigger -- the dev pass adds no reload path or cache mode
by analogy.

`4-2/R10` (non-blocking, accepted) Citation fix: the `Array[StringName].sort()` internal-pointer
hazard lives in code (`player_state.gd:77,206-207`; `test_determinism.gd:170`), not
`project-context.md`. The Dictionary sorted-key rule IS in `project-context.md` (Testing Rules).
The `3-0d/R21` gotcha (`Dictionary.has()` true for `null`) is live for any priority-parameter
lookup table.

`4-2/R11` (non-blocking, accepted) `game-architecture.md`'s own characterisation of the seam
("throttled shared-tick provider, story 4-2", `game-architecture.md:452`) added to References as
support for `R15`. Added measurement: the authored priority set must load NON-EMPTY under the
headless harness, since AC 3's graceful-degradation clause would otherwise let a silent load
failure pass as green.

`4-2/R12` (BLOCKING, ruled) `TargetingService` lives at `src/state/targeting/targeting_service.gd`,
NOT under `src/state/economy/` -- `economy/` holds three economy evaluators and targeting would
hand that name to every E4 story after this one. `MinionPriority` stays in
`src/state/resources/`. Tasks and Project Structure Notes corrected, including an earlier pass of
this same checklist that had firmed the path to `economy/`. -- _decided by Matko._

`4-2/R13` (non-blocking, accepted) Live Smoke rewritten: with movement out, "does not sit
permanently inert" is unfalsifiable, so the smoke gets a visible signal -- the grey box rotates to
face its target, purely presentational (runner reads node positions and the applied target off
the snapshot, no new observation seam). The script includes a kill; `R-D6` is re-invoked and
consumed normally (last spent 4-1's smoke, 2026-08-09).

`4-2/R14` (BLOCKING, ruled) Open Question 1 (unit position) is DEFERRED AGAIN, to 4-3, with
movement as the forcing point -- not a second can-kick: `4-1/R12` deferred because no consumer
existed; a `TargetingService` without movement is still not that consumer. `FORMAT_VERSION` stays
2, F1 untouched, and 4-2 targets over `R3`'s authored order, never over distance. -- _decided by
Matko._

`4-2/R15` (BLOCKING, ruled) Open Question 2: a shared throttled tick evaluated inside `advance()`.
`Area3D` overlap queries REJECTED by name -- physics-frame, outside `src/state/`, not hashable,
the `D-4` reasoning from 1-7. No fourth collision layer, no new observation seam;
`test_runner_observation_seams_are_exactly_eight`'s Dev Notes paragraph is MOOT, reasoning kept
rather than deleted. -- _decided by Matko._

`4-2/R16` (BLOCKING, ruled) AC 1's "zero code changes" claim is false -- selection policy IS code.
`MinionPriority` is PARAMETRIC, not type-name-keyed, on the `ResourceGenerationRule` `amount_field`
precedent. Exactly TWO `.tres` authored this story: `Standard` and `Hero-Seeker`. `Tank` (needs
HP, 4-3) and `Bomber`/AoE (needs position, 4-3/4-4) are named deferred, not authored. An
unrecognized or unauthored parameter falls to a named returned reason (AC 6's second reason).
-- _decided by Matko._

### Close-out

Two commits, neither pushed: `docs(4-2): record operator rulings and promote to ready-for-dev`
(story amendments per every ruling above, this decision-log entry, `sprint-status.yaml` promotion,
story Status `authored` -> `ready-for-dev`); `chore(4-3): re-point minion movement ownership
comments` (the two `R4` comment corrections, code only, no behaviour change). `baseline_commit`
untouched -- the dev pass owns it. No golden or suite touched, this is a docs-plus-comments pass.
Operator reviews the log and pushes.

---

## Session 2026-08-10 -- 4-2 close-out

Dev pass (Claude Opus 5) delivered all eleven ACs; code review (`gds-code-review`) and live smoke
both discharged. Story promoted `review` -> `done`; board promoted `ready-for-dev` -> `done`.

`4-2/R17` (operator, dev pass) `Standard` governs every unit, resolved by an EXPLICIT NAMED
CONSTANT from the sorted rule set, never "whatever sorts first"; a missing name falls to AC 6's
named no-target reason rather than a silent substitution. `Hero-Seeker` is authored but
TEST-ONLY -- `src/` may not name it -- because without a differing authored pair there is no way
to prove the evaluator is generic rather than a hardcoded branch. Per-unit priority CHOICE is a
named forcing point rather than staying open: the first story where units actually differ (4-3 or
4-4) is the only story allowed to add a priority field to the unit record. -- _decided by Matko._

`4-2/R18` (operator, review resolution) The step-7 seat comment overstated a guarantee: it claimed
a unit summoned by this tick's step-6 cast never acquires before the next throttle boundary, which
is false whenever the spawn tick IS a boundary (`_retarget_units()` has no this-tick exclusion).
RESOLVED as option (a): the comment was wrong, the behaviour is right. A same-tick acquisition when
the spawn tick is itself a boundary is MORE RESPONSIVE, and 4-3 builds movement/combat on this same
target; deferring it would add per-tick "added this tick" tracking with no gameplay reason behind
it -- machinery without a consumer. The comment was rewritten positively and a named pair of tests
was added driven through a REAL step-6 cast (`_match_for_cast`), covering both the same-tick-
boundary acquisition and the wait-for-next-boundary case. No behaviour change; golden asserted
unmoved at `73a86005`. -- _decided by Matko._

**Golden chain, ONE re-baseline, TWO MOVERS and TWO NON-MOVERS, all isolated separately (both
already recorded in `test_determinism.gd`'s header, ratified here):** `78bd2b97...b0b5e5`
(inherited) -> AC 9's identity extension ALONE, PREDICTED a non-mover (`4-2/R8`) and MEASURED one,
UNMOVED at `78bd2b97` -> the `unit_targets` snapshot-shape key ships before the step-7 tick is
wired, a MOVER isolated by construction: `78bd2b97` -> `23518ba4...ca922` -> the step-7 tick wired
with `RETARGET_INTERVAL_TICKS := 23` authored, so the t22-summoned unit acquires the opposing hero
at the t23 boundary and still holds it at the hashed t24, a MOVER: `23518ba4` ->
`73a86005...09d1b5`, the new `GOLDEN`. `rng_state` confirmed a non-mover against a non-vacuous
pair (`test_the_throttled_targeting_consumes_no_rng`, interval 23 vs. 7, acquired target differs
across the pair so the comparison cannot be vacuous). Snapshot key set TEN -> ELEVEN, moved
deliberately in both pins that carry it (`test_card_observation.gd`,
`test_draw_delay_and_reshuffle.gd`). -- _decided by Matko._

**Live smoke outcome (OPERATOR-REPORTED).** PASS on the shipped default: a summoned box faces the
opposing hero, follows by rotation when the enemy moves, the kill lands cleanly and `R` clears the
units, and the rotation is legible on the untextured box (`docs/playtest-log.md`, 10.8 entries).
`R-D6` was RE-INVOKED at this gate (`4-2/R13`) and is now CONSUMED again, on a live kill against a
killable human slot. The flag-off half of the smoke script was deliberately NOT smoked live -- it
is machine-covered at three levels (`test_targeting_service.gd`'s seat-level flag matrix, the
evaluator-level matrix, `test_unit_aim_live.gd`'s non-vacuity) and editing authored flags before a
commit chain is avoidable risk. -- _decided by Matko._

**`PROC/R6` stall counter RESETS TO 0.** Both review layers (Blind Hunter, Edge Case Hunter)
completed with layer-completion lines, no stall -- the first clean run after four consecutive runs
carrying one stalled layer (3-6, 4-B1, 4-0, 4-1, each recorded at its own close-out). This is what
un-suspends the reasoning `PROC/R6`'s three-consecutive-stall re-suspension trigger depends on; the
count had never actually reached three, but was climbing toward it, and this run breaks the streak
rather than extending it.

**Three things this story leaves live, each with a named owner.**
(a) Unit collision -- units are `Node3D` + `MeshInstance3D` with NO collision shape, so heroes pass
through them today (`docs/playtest-log.md`, 10.8: "vidjim da heroji mogu proralziti kroz te
pravokutnike"). OWNER: 4-3's gate. Filed to `deferred-work.md`.
(b) Per-unit priority choice -- forced at 4-3/4-4, the only story allowed to add a priority field
to the unit record (`4-2/R17` condition 3).
(c) Unit position ownership -- deferred AGAIN to 4-3, with movement named as the forcing point
(`4-2/R14`); not a second can-kick, since a `TargetingService` without movement was still not the
consumer `4-1/R12` waited for.

**The `.uid` rule, corrected.** The gap recorded at the 4-1 close-out ("the scan generates `.uid`
siblings only for `class_name` files, not for plain `.gd` test scripts") was an ORDERING artefact,
not a mechanism: measured this pass, a second scan run after every new `.gd` already existed
generated `.uid` siblings for all four new plain test scripts. The editor scan does NOT skip plain
test scripts. Practical rule: SCAN LAST, after every new `.gd` exists in the tree.

### Close-out

Five commits, none pushed: `story 4-2: minion AI and throttled targeting` (code, tests and data
only); `docs(4-2): dev pass record, review findings and resolution` (the story file, task
checklist, Review Findings, Dev Agent Record, Status `review` -> `done`); `board: promote
4-2-minion-ai-throttled-targeting to done` (`sprint-status.yaml`); this decision-log entry plus one
`deferred-work.md` entry; `chore(test): repair the truncated 4-0 re-baseline record in
test_determinism.gd` (comment-only, pre-existing, unrelated to this story's own work). Suite green
throughout (443 state / 3450 assertions + 26 integration). Operator reviews the log and pushes.

## Session 2026-08-10 -- 4-3 scope split

`4-3/R1` (BLOCKING, ruled) The boarded `4-3-minion-combat` carried six things at once. CUT into
`4-3-minion-approach-and-collision` (geometry, ships first) and a new `4-3a-minion-combat` (unit
HP, damage, death, board removal). The melee retune (`E3-R/R3`) anchors to `4-3a`, not to `4-3`.
-- _decided by Matko._

`4-3/R2` (BLOCKING, ruled) Unit position ownership, deferred by `4-1/R12` and `4-2/R14`, is now
CLOSED, not deferred again. The actor drives its own approach: `UnitActor` reads its acquired
target from the snapshot (`unit_targets`, key set 11, `[slot, index]`, index -1 = hero), looks up
that target's node, and moves toward it. State never owns unit position. `F1` holds literally
(position is actor-owned, as `hero_state.gd:5` already is for heroes); `push_contact` remains the
only inward intake (1-8); `FORMAT_VERSION` stays 2; no field is added to the unit record. Two
alternatives REJECTED by name: an inward direction-fact channel feeding a state-owned per-unit
velocity (pays a new intake, the stream contract, and `FORMAT_VERSION` 3), and state-owned
position floats (breaks `F1`, rejected a third time). -- _decided by Matko._

`4-3/R3` (ruled) Damage requires proximity, same as between two heroes, so combat runs through the
shipped 1-8 contact pipeline; the contact fact's addressing widens to `[slot, index]` per the
`4-2/R2` precedent. That is `4-3a`'s work -- `4-3` delivers no damage, no HP, no death.
-- _decided by Matko._

`4-3/R4` (ruled) Minions physically block heroes. Collision is presentation-only, so `4-2/R15`
(`Area3D` rejected for targeting -- physics frames are not hashable) is untouched, but "no state
decision reads physics" is a claim the story must make measurable, not assert. -- _decided by
Matko._

`4-3/R5` (ruled) `4-3` is Tier A even though it is predicted golden-neutral and would be Tier B
eligible under the ratified policy. Tier may be raised, never lowered, mid-story. -- _decided by
Matko._

`4-3/R6` (ruled) The per-unit priority field moves to `4-4` (three totem subtypes are the first
place units genuinely differ). The `4-2/R17(c)` permission to add a field to the unit record is
NOT spent by `4-3`; the `hp` field lands in `4-3a`. -- _decided by Matko._

### Close-out

One commit, not pushed: `docs(4-3): split minion combat into approach and combat halves`
(`sprint-status.yaml` board split, this decision-log entry, `deferred-work.md` collision item
annotated with its new owner). No code touched. Operator reviews the log and pushes.

## Session 2026-08-10 -- 4-3 readiness gate (rulings R7-R20)

`4-3/R7` (ruled) AC 4's collision claim is `4-2/R15`'s and no stronger: no code under `src/state/`
reads a physics API and no state decision branches on a collision result. NOT claimed: collision
has no effect on state -- blocking changes hero node positions, hero positions are the sole
geometric input to `_gather_contact_facts` (`match_runner.gd:776-804`), and the derived facts enter
state through `push_contact` (1-8). Hero-vs-hero collision already exercises this indirection on
layer 1; a unit on layer 1 joins it, it does not create it.
`4-3/R8` (BLOCKING, ruled) AC 1's literal wording ("`UnitActor` reads its acquired target from the
snapshot") contradicted `unit_actor.gd:15`, the project-context HARD RULE, the story's own Task
line, and `_target_world_position`'s docstring. Corrected: the RUNNER reads the throttled
`[slot, index]` pair through `unit_board.gd`'s non-allocating accessors, resolves it through
`_target_world_position` (`match_runner.gd:671`), and hands `UnitActor` a `Vector3` via
`approach(target_position, speed, stop_distance, delta)`. "Snapshot" leaves this AC.
`4-3/R9` (ruled) Two test files are load-bearing, not one: `test/state/test_data_resources.gd`
(`E1_BALANCE_FIELDS`, reflection-checked, fails until extended) and
`test/integration/test_unit_approach_live.gd`. Both added to Tasks and Project Structure Notes.
`4-3/R10` (ruled) The approach call seats at ONE line: the DRIVE phase, alongside the hero drive
call (`match_runner.gd` ~930-931), per `game-architecture.md:965-971`'s "drive actor movement
(move_and_slide)" phase. `_aim_unit_actors` STAYS at 3d. The loop-merge idea goes to
`deferred-work.md`, costed at one extra `_target_world_position` call/unit/frame, zero heap alloc.
`4-3/R11` (BLOCKING, ruled) The approach step reads the runner's own replay-aware config handle at
point of use -- the selection already made at `match_runner.gd:177-180`. Never
`BalanceConfigService.get_config()` directly (would move units at the authored speed instead of the
recorded one during replay, `3-0c`'s AC 4 divergence); never a copy cached in a `UnitActor` field.
CONSTRAINT C bars caching in a private field, not reading the runner-held config. -- _decided by
Matko._
`4-3/R12` (ruled) AC 6 demoted to a REGRESSION statement -- zero-information, since the golden
fixture instantiates no actor and no state code reads either field. `4-2/M1` does not transfer. The
positive control is a conjunction, all four required: live moved-then-stopped delta on a real
`UnitActor`; the fields read from the authored `.tres` at the live seat; the physics-token guard
under mutation; `E1_BALANCE_FIELDS` extended.
`4-3/R13` (ruled) AC 5's physics-token set is fixed exactly (`get_overlapping_areas`,
`move_and_slide`, `CollisionShape3D`, `PhysicsDirectSpaceState3D`), "or equivalent" removed. Add the
regex self-test pair (precedent `:333-338`) and the vacuity assert (precedent `:306`, `:348`) --
the guard is green today against a `src/state/` with no physics token at all.
`4-3/R14` (ruled) `R-D6` is NOT spent by this story. Collision is layer-based and slot-agnostic, so
AC 4 is falsifiable with P1's own hero walking into P1's own unit, shipped defaults -- no
`slot_controller_kinds` flip, no kill, no `project.godot`/`main.tscn` collateral. `R-D6` stays
AVAILABLE for `4-3a`, which ships death and has something to prove with it. -- _decided by Matko._
`4-3/R15` (ruled) Open Question 2 restated RULED AND DEFERRED: a presentation null-check, no state
consequence. `_target_world_position` already returns null for an out-of-range index or freed
instance and the caller already skips; approach does the same. This story cannot produce the
interesting case -- the only board-shrink path is the debug reset. Re-acquisition is `4-3a`'s.
`4-3/R16` (ruled) Open Question 3 ruled: recompute every frame through the non-allocating
accessors. `project-context.md:93` throttles ACQUISITION scans, not a fixed-pair node lookup.
Caching to the throttle boundary would lag up to `minion_retarget_interval_ticks` (12 at 0.2s).
`4-3/R17` (ruled) Open Question 4: `CharacterBody3D` + `move_and_slide()`, `collision_layer 1` /
`collision_mask 1` by default (matching `hero.tscn:49`), one `CollisionShape3D` sized to the
existing 0.6 x 1.2 x 0.6 box. No new layer, `project.godot` untouched. No hurtbox this story
(`4-3a`'s). Open Question 1: units DO collide with each other, free from the body type.
-- _decided by Matko._
`4-3/R18` (ruled) The `4-5` pooling criterion fixed in advance: required if the measured frame rate
drops below 60 fps at 16 concurrent units on the reference machine; above that,
instantiate/`queue_free()` stays shipped. Mirrored into the `4-5` board note. -- _decided by
Matko._
`4-3/R19` (ruled) Four corrections: (N1) `unit_actor.gd`'s header has TWO stale sites -- lines
16-17 AND line 32; (N2) AC 2's precedent corrected to `move_speed`/`stamina_regen_per_second`
(rate) and `attack_lunge_distance` (distance), `block_facing_arc_degrees` dropped; (N3)
`_golden_config()` must NOT author the two new fields -- no state code reads them, authoring them
is noise; (N4) replay-safety MEASURED: `intent_recorder.gd:401`'s `_resource_values()` is
reflective over `PROPERTY_USAGE_SCRIPT_VARIABLE`, both fields ride `apply_balance` automatically,
no `FORMAT_VERSION` change, no test pins that key set.
`4-3/R20` (ruled) The gate corrected its own carried premise: `4-2/R5(d)` did NOT produce a false
non-move from an unauthored cadence. `test_determinism.gd:38-43` records an unauthored cadence
deriving to 1 tick, hashing identically to the authored 23 (`73a86005` both ways) -- this CORRECTED
the story's prediction, it did not fail it. Recorded so the wrong lesson is not recycled.

### Close-out

One commit, not pushed: `docs(4-3): apply readiness gate rulings R7-R20` (story amended per each
ruling above, `sprint-status.yaml` promoted to ready-for-dev, this decision-log entry,
`deferred-work.md`'s aim/approach loop-merge item). No code touched, no test suite run (docs-only
pass). Operator reviews the log and pushes.

## Session 2026-08-10 -- 4-3 code review (rulings R21-R25)

`4-3/R21` (ruled) Finding 1 (MEDIUM): `unit_actor.gd`'s header and `unit_actor.tscn`'s
`editor_description` overclaimed "a unit blocks a hero (and another unit)" -- only hero-blocking
is measured (`test_unit_approach_live.gd`). Both narrowed to the measured claim; unit-vs-unit
blocking filed to `deferred-work.md`, owner `4-3a`, covering both the wedge/jitter risk and
`approach()`'s conflation of "reached `unit_stop_distance`" with "physically obstructed short of
it". Comment-only, no behaviour change.
`4-3/R22` (ruled) Finding 2 (MEDIUM): `test_unit_approach_live.gd`'s `MOVE_SAMPLE_FRAME`,
`STOP_SAMPLE_FRAME`, `WALK_START_FRAME`, `WALK_END_FRAME`, `STOP_BAND` were hand-derived literals,
brittle against the melee retune boarded for `4-3a`. Re-derived at runtime from `_speed`,
`_stop_distance`, `Engine.physics_ticks_per_second`, and the live spawn-to-target distance. WHAT is
measured is unchanged. Proven: mutation (speed/stop_distance = 0) still FAILS; retune (1.0 and 8.0
against authored 3.0) both PASS; `.tres` restored byte-identical.
`4-3/R23` (ruled) Finding 3 (LOW): the `4-3` story's Change Log author cell for the readiness-gate
pass reverts to "Claude Sonnet 5", the model the operator selected. The trailer-as-evidence
argument added at the dev pass is deleted rather than reworded: a value emitted regardless of who
did the work is not evidence of who did it. What stays true and useful: the `Co-Authored-By`
trailer is not reliable authorship evidence in general, and commits `b7b9c9c`/`654d436` shipped a
non-constant trailer against `project-context.md:149`.
`4-3/R24` (ruled) Finding 4 (LOW): the `4-5` tier note stands (correctly applies `E4-P/R8`, NOT
reverted). Recorded for the retrospective: `E4-P/R8`'s close-out claimed a sprint-status update
that never landed, leaving a stale "Tier UNDECIDED" on the board for two stories -- the second
instance of a close-out claiming a docs change that did not ship (first: the truncated `4-0`
re-baseline record, repaired at `46ace6e`). Not work to do now.
`4-3/R25` (ruled) Finding 5 (LOW): `test_architecture_invariants.gd`'s physics-token guard comment
called the token set "exact and closed" -- it is a substring match with no word-boundary
anchoring. Comment corrected to say so and to note the guard FAILS CLOSED (matches a superset of
the four forms, never a subset) and is therefore safe. Guard itself untouched -- the pattern
family is pre-existing and not this pass's to change.

### Close-out

Review PASS, 2 MEDIUM / 3 LOW, all five findings ruled, no blocking defects. Three commits, not
pushed: `docs(4-3): narrow the unit collision comments to what is measured` (R21, comment-only);
`test(4-3): derive approach live-test sampling from authored balance` (R22); `docs(4-3): record the
code review and rulings R21-R25` (this entry, `deferred-work.md`, the story's Review/Change Log,
`sprint-status.yaml`). Suite unmoved: 445 state tests / 3464 assertions / 0 failed, 27 integration,
GOLDEN `73a86005` unmoved, snapshot key set still eleven. Operator reviews the log and pushes.

## Session 2026-08-10 -- 4-3 close-out (ruling R26)

Live Smoke PASSED, operator's own hand, shipped defaults (`docs/playtest-log.md`, 10.8): a
summoned unit approaches on summon; the hero cannot walk through or shove it; several units on one
target show no jitter or mutual pushing, track normally, and do not pass through each other; the
authored `3.0` / `1.5` feel right. `R-D6` NOT spent (`4-3/R14`).

`4-3/R26` (ruled) FEEL FINDING, not a defect: minions currently read as homing projectiles rather
than as Elden Ring-style mobs, because approach is the only thing they do -- no attack windup, no
pause, no recovery. Correct for this story, which ships approach and nothing else. It is an
acceptance concern for `4-3a`, whose attack rhythm is what makes a unit read as a mob, and it
reinforces why the melee retune (`E3-R/R3`) is anchored to `4-3a` rather than here. Named as an
input to `4-3a`'s create pass. -- _decided by Matko._

What this story leaves live for `4-3a`:
- The unit-vs-unit machine coverage gap (`deferred-work.md`) -- observed clean by hand at this
  story's smoke, which lowers the risk read but does not close the item.
- `approach()` not distinguishing "reached `stop_distance`" from "physically obstructed short of
  it" (same deferred-work.md item).
- The aim/approach loop-merge item (`deferred-work.md`, unassigned owner).
- `R-D6`, unspent, available.
- The `4-3/R26` feel finding above.
- `4-3/R3`'s widening of the contact fact to `[slot, index]`, owned by `4-3a`.

Carried forward for the E4 retrospective, no work now:
- Two "close-out claimed a docs change that never shipped" instances (`4-3/R24`).
- Two consecutive review runs with all three layers completing and no stall (PROC/R6 counter
  stays 0).
- The twice-seen pattern of a session completing its commits, losing the transcript to
  compaction, and reporting a HEAD mismatch on the next prompt -- where the correct answer was
  review, never reset.

### Close-out

Story `4-3-minion-approach-and-collision` -> `done`. One commit, not pushed:
`docs(4-3): close out minion approach and collision` (story Status and Live Smoke, this
decision-log entry, `sprint-status.yaml`, `deferred-work.md`'s unit-vs-unit item annotated, not
closed). `docs/playtest-log.md` is the operator's own entry, not part of this commit. No code
touched, no test suite run (docs-only pass). Operator reviews the log and pushes.

## Session 2026-08-10 -- 4-3a scope split (rulings R1-R7)

`4-3a/R1` SCOPE SPLIT. `4-3a-minion-combat` is cut in two along the direction of damage.
`4-3a-minion-damage-and-death`: the unit as TARGET only (hp, damage, death, board removal,
contact-fact target addressing, unit hurtbox). `4-3b-minion-attack-rhythm`: the unit as ATTACKER
(windup/active/recovery, unit hitbox, unit-vs-unit damage). Rationale: the attacker half needs
per-unit action state and phase timers inside `advance()`, plus units entering
`_gather_contact_facts` which today enumerates heroes only -- on its own larger than all of
`4-3a`, landing in the step-4 ladder, the most sensitive shipped code. Ordering is
dependency-correct: both halves need the same widened contact fact, and the attacker half gets a
live victim to test against. Admitted cost: two golden re-baselines instead of one.
`4-3a/R2` Death removes a unit from the board by leaving a HOLE at a stable index, never by
compacting the array. Reason: `unit_targets` is `[slot, index]` under throttled retargeting, so
compaction would silently re-point a stale reference at a DIFFERENT live unit. Precedent:
`4-0-hand-slot-stability`. Converts `4-3/R15` (OQ2 ruled a presentational null-check because death
was future work) into a state-layer concern owned by `4-3a`.
`4-3a/R3` A confirmed hit against a unit generates NO mana. Reason: step 5 `_generate_mana` awards
`melee_hit_mana` on every confirmed hit, so without an explicit gate, killing minions becomes a
mana source. -- _decided by Matko._
`4-3a/R4` No friendly fire: a hero's hitbox does not damage units owned by that hero's own slot.
-- _decided by Matko._
`4-3a/R5` The melee retune (`E3-R/R3`) re-anchors from `4-3a` to `4-3b`. Reason: the melee-feel
half of the playtest checklist stays unanswerable until minions attack -- the same reason the
block was deferred on 2026-08-10. The economic half becomes measurable for the first time once
units can die. -- _decided by Matko._
`4-3a/R6` The permission granted by `4-2/R17(c)` to add a field to the unit record is SPENT in
`4-3a` on exactly one field: hp. Maximum HP is read from balance (all minions share the authored
maximum), so no per-unit max field. `4-3b` receives NO advance permission; it must obtain its own
at its own scope ruling. Reason: `R17(c)` exists so that record growth is a deliberate act, one
story at a time.
`4-3a/R7` `R-D6` is NOT spent in `4-3a`. The live smoke is "P1 summons, P2's hero kills it", and
the shipped default `slot_controller_kinds` is already `[0,1]` (two live killable human slots,
per `2-3`), so no temporary flip is required. Same reasoning as `4-3/R14`.

### Close-out

Docs-only, no code. One commit, not pushed: `docs(4-3a): split minion combat into damage and
rhythm halves` (`sprint-status.yaml`, `deferred-work.md`, this decision-log entry). Operator
reviews the log and pushes.

## Session 2026-08-10 -- 4-3a readiness gate (rulings R8-R21)

`4-3a/R8` (BLOCKING, ruled) AC 2 named one damage implementation, not two: a dedicated FLAT
damage-to-unit balance field, never `attack_damage_percent_of_max_hp` recomputed against a unit's
own authored maximum. Measured: that computation is a percentage of the TARGET's own maximum, so
reuse would make hits-to-kill a constant (34, at the authored 3.0%) for EVERY possible authored
unit maximum, and the authored unit HP field would be cosmetic. Authored provisionally: unit
maximum HP = 9.0, flat damage to a unit = 3.0, three swings to kill; both provisional, tuned by the
melee retune in `4-3b`. -- _decided by Matko._
`4-3a/R9` (ruled) A hole is NEVER reused. `UnitBoard.add()` stays an unconditional append; a summon
following a death lands at a NEW index, never the dead unit's hole. Reuse would silently re-point a
stale throttled `unit_targets` reference at a DIFFERENT live unit -- the exact aliasing the hole
discipline exists to prevent -- and pooling is precisely the change that would introduce a free
list "for free." AC 7 states this; a task pins it with a test.
`4-3a/R10` (ruled) `FORMAT_VERSION` goes to 3. The contact fact rides the replay tap
(`capture_push_contact`, the positional four-element array, `record_file`'s fixed-position
rebuild), so widening the target field changes the recorded payload's SHAPE. `record_file` refuses
a mismatched version with a reason and no migration path, by design (`4-1` precedent). The Golden
Prediction's stay-at-2 claim is REVERSED. No committed recording fixture exists to re-record.
`4-3a/R11` (BLOCKING, ruled) The unit hurtbox goes on the EXISTING layer 2 "hurtbox". Measured: the
hero Hitbox already declares `collision_layer = 4` / `collision_mask = 2`, and the repo holds
exactly four layer/mask declarations, all in `hero.tscn`. `project.godot` and `hero.tscn` both stay
BYTE-IDENTICAL. AC 4's "extend the hero Hitbox pairing" requirement is removed; `hero.tscn` leaves
Project Structure Notes; the layer Open Question closes with this answer. -- _decided by Matko._
`4-3a/R12` (BLOCKING, ruled) `hit_landed` is NOT emitted for a unit target -- the signal carries a
slot only and its shipped consumer would flash and sting the hero of that slot, an untouched hero
whose hp did not change. The legible event this story ships is DEATH. Live Smoke corrected: no
claim that a hero's attack "visibly reduces" a unit's HP; three swings kill and remove it, nothing
flashes or stings on the first two. Deferred item added, per-hit feedback on a damaged unit, OWNER
`4-3b`; rejected alternatives: a widened signal payload (more plumbing, same screen) and a new
observation seam (architecture amendment against the locked count of seven). -- _decided by Matko._
`4-3a/R13` (ruled) A dead unit's actor is freed. Measured: the actor spawn loop only grows and the
free path is reached from the debug reset alone, so without this a killed minion stays a visible
grey box forever. New AC 11: `queue_free()` on death (until `4-5`'s 60fps-at-16-units criterion
fails; not the pooling question), runner's per-slot actor array left holed to keep indices aligned.
`4-3a/R14` (ruled) Liveness gates at two NAMED seats: the retarget loop (`TargetingService`'s
candidate scan) and the approach loop (`match_runner.gd`'s DRIVE phase). Measured: both drive every
index unconditionally today, untouched by any task. AC 7 now names both seats rather than asserting
an outcome the code cannot yet give.
`4-3a/R15` (ruled) `TargetingService.target_for`/`reason_for` take an `Array[int]` of living
indices in place of `opposing_unit_count: int`. Measured: today's candidate set is three ints and a
bool, `target_for` always returns index 0, so it structurally CANNOT skip a dead unit's index -- a
hole at 0 hands back the corpse, and `REASON_NO_LIVING_CANDIDATE` tests a count a hole keeps
non-zero. An int array is still a plain fact, preserving "never a `PlayerState`". Its docstring
claiming a unit is always living is FALSIFIED by this story, corrected in the same pass.
`4-3a/R16` (ruled) The dedupe key widens to the full target address, `[attack_index, slot, index]`
-- today's `attack_index`-only key is an artefact of a hero-only world; under it one swing
overlapping a unit and the enemy hero would resolve only the first. A swing now cleaves through
multiple targets. That record is SNAPSHOTTED, so widening it is a SECOND golden cause (`R17`).
`4-3a/R17` (ruled) `hp` joins the snapshot -- a value that crosses ticks and decides an outcome does
not sit outside the hash, the dedupe record's own reasoning. Golden Prediction becomes a MOVER with
TWO named causes (the hp key; the widened dedupe key), measured both directions, one re-baseline.
The fixture is NOT extended to injure a unit -- a third cause, out of scope. BEFORE unchanged:
golden `73a86005`, snapshot key set eleven.
`4-3a/R18` (ruled) AC 10 gets a positive half: as written, three negative claims that would pass
against two units that never moved. Requires both units MOVED and CONVERGED within a bounded
distance of the SAME acquired pair, tolerances DERIVED AT RUNTIME from authored balance. The
existing live test's single-actor helper cannot be reused for two units.
`4-3a/R19` (ruled) AC 3's regression pin named: same damage value, dedupe outcome, confirmed-hit
membership, `hit_landed` payload for a hero target. Covers the shipped contact tests under
`test/state/` and `test/integration/` plus the determinism fixture's contact payloads, listed by
real path in AC 3.
`4-3a/R20` (ruled) The unit-target path SHARES the rungs a unit has (dead-attacker drop, dedupe)
and SKIPS what it lacks (iframe, deflect, block). Branch-or-helper is an implementation choice; rung
ORDER must match today's exactly.
`4-3a/R21` (ruled) (a) Death resolves in the contact step right after damage; the round-over freeze
precedes it and needs no special case AS A CLAIM TO BE MEASURED, not asserted. (b) AC 6 gains why
the friendly-fire filter sits at GATHER time: the contact seam asserts attacker/target slots
differ, so a same-slot fact reaching it would trip that invariant. (c) Citations fixed:
`unit_board.gd` is 147 lines not 143; `_generate_mana` runs to the passive rung
(`match_state.gd:733-750`), not line 739.

### Close-out

Docs-only, no code. Story promoted to `ready-for-dev`. One commit, not pushed: `docs(4-3a): apply
readiness gate rulings R8-R21` (story file, `sprint-status.yaml`, `deferred-work.md`, this
decision-log entry). Operator reviews the log and pushes.

## Session 2026-08-10 -- 4-3a close-out

`4-3a/R22` (ruled, fixed) `HeroState.register_swing_hit`'s hit list hashed an UNPINNED physics
ordering: this story is the first to let one swing append several entries (the cleave, `R16`), and
`_gather_contact_facts` receives overlaps from a query that pins no order. Fixed by sorting `hit` on
every insertion (canonical `[slot, index]` order). Golden measured UNMOVED both directions -- the
fixture's dedupe records are empty at its hash tick, nothing to hash there; not re-baselined.
`4-3a/R23` (ruled, fixed) `UnitBoard.is_alive_at`'s lenient out-of-range read cited an UNREACHABLE
runner/board desync (both named liveness seats already bound their loop first). Corrected to cite the
real caller: `_resolve_unit_contact`'s dead-target rung, which can receive a stale/malformed index.
`4-3a/R24` (ruled, recorded) The two-line dead-attacker check duplicated between the hero ladder and
`_resolve_unit_contact` is ACCEPTED, not refactored -- the unit branch's separateness is `R20`'s own
ruling, and one two-line condition does not earn a shared helper. Forward rule recorded at both
sites: a THIRD copy is the signal to replace the mechanism, not tighten the pattern further.
`4-3a/R25` (ruled, recorded) Minion-blocked-by-own-summoner ANNOTATES the existing deferred-work item
(`approach()` cannot distinguish "arrived" from "physically obstructed", owner `4-3b`) rather than
opening a new one -- the measured instance is `test_two_units_converge_live.gd`'s trailing unit
wedging against P1's own hero. Item stays OPEN.
`4-3a/R26` (rejected, false positive) The claimed "silent malformed-target fallback" in
`push_contact`'s ternary is dead code: `Invariant.check(target.size() == 2, ...)` on the line above
already halts loudly first, in every build this pipeline is ever exercised under. No code change.
`4-3a/R27` The Golden Prediction's SECOND named cause (the widened `[attack_index, slot, index]`
dedupe key, independently of the `hp` key) is FALSIFIED. Measured: at the golden fixture's hash tick
(t24) both heroes' `swing_dedupe.records` are EMPTY -- every record opened by t5/t13/t19/t20 has
expired -- so a widened key over an empty record set hashes nothing. The shape change IS proven,
just not there: `test_contact_resolution.gd`'s mid-swing dedupe pin moved `[1]` -> `[[1, -1]]`. Only
the `hp` key moved the golden (`73a86005` -> `35c38c0e`). Recorded so a future story does not recycle
the dead second-cause claim.
`4-3a/R28` Live smoke PASSED on every point, shipped defaults, operator's own hand: a summoned unit
dies in three swings with no flash or sting on the first two; hitting an enemy unit pays no mana
while hitting a hero does; no invisible wall where a dead unit stood; a hero's own units take
nothing; two units share a target without interfering and both take damage from one swing; three
swings to kill reads as a good standard.
`4-3a/R29` (decided by Matko) A minion body-blocked by its OWN summoner is ACCEPTED as shipped, not
fixed here. Operative reason: a fully implemented minion will move intelligently rather than like a
homing missile, so "wedged into the first thing in its path" may stop being its only outcome --
nothing may be left to fix. Secondary reason, cost: the alternative (a unit passing through its owner
while still blocking the enemy) needs per-slot hero collision layers and a `project.godot` edit,
which this epic has twice avoided paying. The cheaper fix has an owner: `4-3b` teaches `approach()`
to distinguish "arrived" from "physically obstructed", letting a blocked unit steer around the
obstacle. Forcing point: `4-3b`. The measured instance stays annotated on the existing deferred-work
item (`R25`) and stays OPEN.

### Close-out

Code and docs shipped across four commits (code+tests; dev pass docs; board promotion to `done`;
this decision-log entry). Golden moved once, `73a86005` -> `35c38c0e`, ONE measured cause. Suite
445/3464 + 27 -> 465/3621 + 29. Code review PASS, no blocking findings, review-stall counter stays
zero. Live smoke PASS. Operator reviews the log and pushes.

## Session 2026-08-10 -- 4-3b story authoring rulings

`4-3b/R1` (ruled) A minion's attack resolves through a real hitbox in the existing contact pipeline,
not abstractly against its acquired target. Reason: abstract resolution is an unavoidable hit, the
mob-feel finding from `4-3` repeating one layer up.
`4-3b/R2` (ruled) A minion swing cleaves, sliding through every target its hitbox touches, as a hero
swing does today. Consequence: cleave append order is hash-significant and rests on unpinned physics
query order, so the new attacker surface must sort canonically on insertion, following `4-3a`'s hero
dedupe-key precedent.
`4-3b/R3` (ruled) No friendly fire on the attacker side: a unit never damages the hero or units of its
own slot. Filtering happens on the resolution ladder by owner slot, never by collision layer.
`4-3b/R4` (ruled) A confirmed hit sourced from a unit generates ZERO mana for its owner. Reason:
otherwise summoning becomes a mana engine, and a blocked hit still confirms.
`4-3b/R5` (ruled) `hit_landed` IS emitted when a unit damages a hero -- the hero is really hurt, so
the telegraph flash is correct. Deliberate asymmetry against `4-3a`'s suppression of `hit_landed` for
unit TARGETS; recorded so a later gate does not re-litigate it.
`4-3b/R6` (ruled) The hero's existing defensive ladder applies to minion attacks unchanged: roll
iframes drop the fact, deflect fully negates, block applies its damage multiplier.
`4-3b/R7` (ruled) Deflecting a minion does NOT stun it, FOR NOW, with explicit intent to revisit if it
proves worthwhile. The stun field keeps zero inbound edges; the open decision on stun stays open.
`4-3b/R8` (ruled) Units pay no stamina and no resource to attack. Their only limiter is the attack
rhythm itself.
`4-3b/R9` (ruled) A unit's attack direction LOCKS when its windup begins; it does not keep tracking
the target until the strike. Reason: minions are summon-tier, not boss-tier, at this stage -- a swing
that misses when the target steps aside is the intended feel. Late-locking tracking belongs to
per-kind movesets later.
`4-3b/R10` (ruled) The attack trigger is pure distance to the acquired target, never an "arrived"
flag. This removes the reached-vs-obstructed distinction from the attack path entirely.
`4-3b/R11` (ruled) Units continue to collide with their own side; the measured case of a minion
getting stuck on its own summoner is accepted as-is for now and stays deferred with a new owner -- a
later story on richer minion behaviour. NOT discharged here.

## Session 2026-08-11 -- 4-3b readiness gate (rulings R12-R22, R17 split a/b)

`4-3b/R12` (BLOCKING, ruled) The unit's dedupe does NOT move off hero state, and the story does NOT
split a third time. Measured: a unit cannot share the hero's monotonic `attack_index` (it is
incremented only when a HERO starts a swing and it is snapshotted, so driving it from unit swings
would change hero-observed values -- an unnamed golden cause), and cannot share the hero's
`_swing_dedupe` records (their grace lifetime is driven by the HERO's own active window,
`hero_state.gd:134-144`, which has nothing to do with a unit's). Therefore the unit gets its own
counter and its own records, and the hero side is untouched. The split criterion named in advance
was "only if the hero dedupe must relocate"; measurement says it must not.
`4-3b/R13` (ruled) The gate's own proposed cut -- unit-attacks-hero in one story, unit-versus-unit
in another -- is REJECTED. Both reasons it gave (cross-attacker ordering, attacker killed mid-swing)
arise as soon as TWO minions attack one hero and as soon as a hero kills a minion mid-swing, so both
live in the first half regardless of where the cut falls. They become first-class acceptance
criteria instead.
`4-3b/R14` (BLOCKING, ruled; AMENDED at this same gate for `R17b`'s in-reach flag -- the grant is
FIVE fields, not four) FIELD PERMISSION GRANT for `4-3b` on the unit record, obtained at this story's
own scope ruling per `4-3a/R6`. FIVE SCALAR fields land as parallel arrays on the `hp` precedent:
phase state, tick countdown, locked attack direction, monotonic attack counter, and the IN-REACH FLAG
(`R17b`). The DEDUPE HIT LIST does NOT join them -- it goes in a separate unit-owned state class
beside the board. Reason: the board's own rule (`unit_board.gd:43-48`) forbids non-scalar per-record
fields, that rule exists to keep objects out of the hash, and per-kind state is coming in `4-4`
anyway. Cost accepted: one small new state class, and a snapshot key set that MOVES -- how far is a
dev-pass measurement, not a number this gate asserts, because the board's own precedent runs both
ways (one array -> one key for `unit_hp`; TWO arrays -> ONE key for `unit_targets`, which fuses
`_target_slots` and `_target_indices` into pairs). The amendment is recorded here rather than left to
disagree with the story, because the SIZE of the grant is the whole reason `4-3a/R6` made this story
ask for its own.
`4-3b/R15` (ruled) SIGNALS DO NOT WIDEN; the fact dictionary does. Measured from both consumers:
`hit_landed` and `deflect_landed` carry a typed bare int attacker (`match_state.gd:30, 37`) and both
shipped callbacks UNDERSCORE it and gate solely on the target slot
(`telegraph_controller.gd:93-95, 108-110`), so a minion damaging a hero already flashes the correct
hero with no change. Widening the payload would break two typed callbacks for no behavioural gain.
`4-3b/R16` (ruled) Friendly-fire filtering sits at GATHER time, by owner slot. `4-3b/R3`'s substance
stands unchanged; its LOCATION WORD ("on the resolution ladder") is corrected, because `push_contact`
asserts attacker and target slots differ and HALTS on violation (`match_state.gd:454-455`) -- so a
same-slot fact must never reach that seam, and a ladder-side check would be dead code behind a build
halt.
`4-3b/R17a` (BLOCKING, ruled) BEHAVIOUR: a minion begins its windup ONLY when its acquired target is
within REACH -- never on a free-running cycle, and never off an "arrived" flag. This supersedes
`4-3b/R10`'s "pure distance" wording at the level of what the game DOES. -- _decided by Matko._
`4-3b/R17b` (BLOCKING, ruled at this gate -- NOT an operator decision) MECHANISM for `R17a`, arrived
at by this gate's own measurement and recorded as its own ruling so the provenance is not confused
with the behavioural call above. The reach relation is carried on the EXISTING `push_contact` intake,
with a kind marker separating a REACH PROBE from a STRIKE, dropped at the TOP of `_resolve_contacts`
ahead of every rung, and gathered on the SAME THROTTLED CADENCE the minion retargeting already uses
(`minion_retarget_interval_ticks`, 12 at the authored 0.2 s) rather than every tick.
BASIS (the Part 0 measurement): `4-3/R2` rejected an inward direction-fact channel feeding a
state-owned per-unit VELOCITY, and rejected state-owned position floats, while AFFIRMING
`push_contact` as the only inward intake -- and that intake ALREADY carries position-DERIVED spatial
data (`match_runner.gd:895-904`, "FROM POSITIONS ONLY"); no other runner-to-state channel carries
anything spatial (the throttled targeting consumes a priority, a slot int, a bool, an `Array[int]` of
living indices and flags). So the probe adds no channel and delivers neither a position nor a
velocity: state learns a relation, not a location.
THE THROTTLE IS PART OF THE RULED MECHANISM, because the unthrottled cost is the largest this
mechanism introduces and it need not be paid: measured, an unthrottled probe is one row per tick per
in-range unit (up to 16 rows/tick, ~960 rows/second at `4-5`'s 16-unit criterion) against today's
sparse per-swing bursts; on the existing 12-tick interval that falls to ~1.33 rows/tick, ~80
rows/second. The existing interval FIELD is reused, so no new balance field and no new guard entry.
THE PROBE IS GATHERED REGARDLESS OF THE UNIT'S PHASE, NOT ONLY WHILE IT IS IDLE, and state keeps a
per-unit IN-REACH FLAG (the fifth granted field, `R14` amended): the flag is SET by a fact, a windup
START CONSUMES it, and a unit begins its windup when it is idle AND the flag is set. Reason -- the
idle-only variant this gate first wrote has a GAMEPLAY-VISIBLE artefact: a unit finishing recovery
would wait up to a full interval for the next probe, making the effective cycle
windup+active+recovery+up-to-one-interval, jittering with where the swing landed relative to the
cadence, so the authored durations would not describe the observed attack rate. A performance
decision must not silently retune combat. The stream volume is UNCHANGED by this: the throttle, not
the idle narrowing, is what buys the reduction.
THE FLAG IS SET BY ANY CONTACT FACT THIS UNIT SOURCES AGAINST ITS ACQUIRED TARGET, OF EITHER KIND --
PROBE OR STRIKE (operator amendment, closing a REFRESH HOLE this gate left open). The hole: gathering
through the swing is not sufficient on its own, because the fact's KIND is decided by PHASE -- while
the active window is open the same overlap produces a STRIKE, not a probe -- so a throttle tick
landing inside a unit's active window would refresh nothing, and after recovery the unit would wait
for the next probe. That is the very jitter the flag exists to remove, merely less often. A landed
strike is PROOF of reach, and stronger proof than a probe, since it is the same overlap test; so
counting it closes the hole with no new mechanism and no extra stream volume.
SCOPED TO THE ACQUIRED TARGET: only a fact whose TARGET ADDRESS is this unit's own acquired target
sets the flag. Reason -- cleave (`4-3b/R2`) makes a swing through a BYSTANDER reachable, and letting
that refresh "in reach" would keep a unit swinging at a target it has actually lost. Stated
explicitly because it does not follow from either ruling read alone: cleave deliberately lets a swing
touch what the unit never aimed at.
CONSEQUENCE FOR `4-3b/R9`'s DIRECTION LOCK, ruled here rather than left open (an AC permitting two
implementations of a player-visible behaviour is the defect that produced `4-3a`'s first blocking
finding): the locked direction has EXACTLY ONE legal source -- the `dir` of the fact that most
recently set the flag, NEGATED (the fact's field is target-to-attacker, `match_state.gd:463`).
Measured: no alternative exists, because the direction is needed by the windup-start decision inside
`advance()`, the runner learns a windup began only by polling AFTER `advance()` returns and this story
adds no earlier signal, and state cannot derive a direction itself with position actor-owned
(`4-3/R2`). So the locked direction is up to one throttle interval stale BY CONSTRUCTION -- the same
staleness (i) above names, not a second one.
TWO CONSEQUENCES NAMED HONESTLY. (i) The flag can be up to one interval stale, so a minion may begin
a windup against a target that has just left reach; that whiff is consistent with `4-3b/R9` and
`R18`, which already rule a summon-tier swing missing to be the intended feel. (ii) ABSENCE of
overlap is NOT a fact and CANNOT clear the flag -- consumption at windup start is the ONLY clearing
path. Stated explicitly so a dev pass does not go looking for a negative probe that does not exist.
If this mechanism is ever found to cost more than the gate measured, it is amendable without
reopening `R17a`.
`4-3b/R18` (ruled) A swing whose target dies or is retargeted mid-windup COMPLETES INTO EMPTY AIR.
Reason: summon-tier minions are placeholder behaviour, and a cancel path would add a second way a
swing can end, against the no-interruption non-goal. -- _decided by Matko._
`4-3b/R19` (ruled, recorded) The stamina drain from deflecting several minions in one window is an
ACCEPTED, NAMED consequence of `4-3b/R6` (the hero's defensive ladder applies unchanged): deflect
spends its cost PER FACT (`match_state.gd:739-742`), so later facts degrade to blocked damage once
the spend fails. Nobody CHOSE this number; it is recorded here rather than left to surface at live
smoke. Owner of the number: the melee retune block (`E3-R/R3`).
`4-3b/R20` (measured observation, no owner assigned) The runner has NO round-over gate at all: its
`_physics_process` gates only on the DEBUG pause (`match_runner.gd:951-953`), so `_aim_unit_actors`
and `_approach_unit_actors` keep running after a round ends and units keep walking. INHERITED from
`4-3`, not introduced by `4-3b` -- but this story makes it visibly odd (a frozen swing on a walking
body). Recorded without an owner rather than silently absorbed.
`4-3b/R21` (ruled) `RecordFile.FORMAT_VERSION` goes 3 -> 4, shape-only, with hard rejection of older
records and no shim (the `4-1` refusal-with-reason precedent). CONDITIONAL on the `R17b` measurement:
if the reach fact turns out to change the CHANNEL SET rather than the row shape, the required-key set
moves too and this ruling is amended at the dev pass rather than applied. Measured expectation: the
kind marker rides the existing row, so the channel set is unchanged.
`4-3b/R22` (ruled) The golden fixture is NOT extended. Measured: it runs `MatchState` alone with no
runner and no physics, its contact facts are hand-authored hero-attacker literals, and its single
unit is summoned two ticks before the hash -- so a unit attack is STRUCTURALLY unreachable there.
Extending it would mean giving the determinism fixture physics, which is what `D3(b)`/`A2` keep out
of `src/state/`. Reachability limits and the causes proven by unit/integration tests instead are
recorded in the story's Golden Prediction.

## Session 2026-08-12 -- 4-3b close-out

`4-3b/R23` (ruled) The locked attack direction FREEZES across WINDUP and ACTIVE but REFRESHES
during RECOVERY -- AC 12's literal "until the swing ends" wording, read strictly, would freeze it
forever and contradict AC 12's own bounded-staleness clause; the hitbox is shut during recovery so
refreshing changes no outcome. -- _decided by Matko._
`4-3b/R24` (ruled) LIVE SMOKE PASSED, `R-D6` SPENT. Operator killed by a minion -- the first hero
death not caused by a hero. Six points passed as written: minion closes and stops at reach; roll
takes no damage; block reduces; deflect fully negates without stun; telegraph flash fires on
minion-damages-hero; own-side minions cannot hurt each other or their summoner; a minion dies to a
minion in three hits, same as from a hero.
`4-3b/R25` (ruled, recorded) TWO SMOKE POINTS UNMEASURABLE, not failed: the attack has no visual
telegraph, so the operator could not see a swing begin or test evading it. Proven by test, invisible
to a human; not an AC of this story. Named as the reason the melee retune's feel half stays
unanswerable.
`4-3b/R26` (decided by Matko) The melee retune (`E3-R/R3`) is CUT, not opened in full: one balance
`.tres` edit lengthening the minion attack windup (enemy hits too fast the moment it closes),
optionally the reach too; rest of the feel checklist deferred until real models and animations
exist. An interim grey-box telegraph was declined.
`4-3b/R27` (ruled, recorded) The rig/model/animation work (DEBT E) and the attack selector that
would give minions movesets have NO OWNER AND NO SLOT -- the binding constraint on reaching
intended enemy behaviour. The rig story gets an owner and a slot at the E4 close-out, ahead of the
attack selector. -- _decided by Matko._
`4-3b/R28` (ruled, recorded) The review layer reads `git diff HEAD`, excluding new files -- this
story's new state class and both new test files were never seen by it. No
`_bmad/custom/gds-code-review.toml` override exists. Recorded as a STANDING LIMITATION future
review prompts must compensate for by hand, rather than building an override unprompted.
`4-3b/R29` (ruled, recorded) The general case of the harness leak (two live SceneTree tests fixed by
delaying `quit()` past their assertions) is unexamined elsewhere. OWNER: the next story/pass that
touches a live SceneTree test (`deferred-work.md`). The four inherited `.uid` sidecars are now
generated and committed, closing that gap.
`4-3b/R30` (ruled, recorded) Six of seventeen ACs were not independently derived at review, relying
on the green suite and mutation table; AC 14 rests entirely on two mutations from the same pass
that wrote the code. Accepted risk, not re-derived here.
`4-3b/R31` (ruled, recorded) The dev pass left an orphaned headless `godot` process running ~2
hours undetected, caught only because a precondition existed for this close-out. Any harness with a
subprocess timeout must kill the child and check for orphans at the end -- mandatory for every
future dev/review pass.
`4-3b/R32` (ruled, recorded) The deferred `hit_landed` per-hit-feedback item (`4-3a/R12`), owned by
`4-3b`, is confirmed NOT addressed -- the unit-damages-unit/unit-damages-hero asymmetry ships
unchanged. Item stays OPEN, reassigned to no owner (`deferred-work.md`).

**Leaves LIVE for successors:** the widened kind-agnostic attacker address (totems, hero-cast
projectiles named future users); the throttled reach probe and its shared cross-slot counter; the
five granted unit-record scalars plus `UnitSwingDedupe`; `FORMAT_VERSION` 4; minion attack
durations remain GLOBAL -- per-kind conversion is `4-4`'s opening act ("kind has a LIST of
attacks", not "kind has an attack").

### Close-out

Four commits (code+tests; story record; this entry; board `done`). Golden unmoved at
re-measurement, `4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf`. Snapshot key
set: eighteen. Suite 497/3878 + 30/30 integration, all PASS -- matches the story file's own
last-recorded figures. `FORMAT_VERSION` 4. `project.godot`/`hero.tscn` BYTE-IDENTICAL against
`3ea5bbb`. Code review PASS. Live smoke PASS, `R-D6` spent. Operator reviews the log and pushes.

---

## Session 2026-08-13 -- melee retune executed, CUT form (E3-R/R3)

**`E3-R/R3` -- DISCHARGED IN CUT FORM, PER THE SHAPE `4-3b/R26` FIXED.** `4-3b/R26` (decision-log
line 6861) ruled the retune CUT to one balance `.tres` edit rather than opened in full, because the
attack has no visual telegraph and the operator cannot judge tempo, evasion, or read against it, and
because he declined an interim grey-box telegraph, wanting real models and animations first
(`4-3b/R27`, DEBT E, still has no owner or slot). This entry executes that shape; it does not reopen
it.

**The one feel finding, from the operator's own 4-3b live smoke:** the minion hits too fast --
essentially the moment it closes to reach, giving the opponent no time to react.

**The one field changed:** `minion_attack_windup_seconds` in `data/balance/balance_config.tres`,
`0.5 -> 0.9`. Measured, not assumed: `TimingWindow.TICK_HZ = 60.0` and
`seconds_to_ticks() = round(seconds * TICK_HZ)` (`src/state/timing/timing_window.gd:10,23`), so this
is `30 -> 54` ticks. No other field, no code, no test, no story file touched.

**`minion_attack_active_seconds` / `minion_attack_recovery_seconds` -- operator's call, not taken
here.** Recovery is what leaves a mob open after a miss, so lengthening windup alone changes the
ratio of "time to react" against "time the mob stays vulnerable on a whiff" without touching the
latter. Whether that ratio still reads as a coherent rhythm is a feel judgment this pass does not
have standing to make -- flagged for the operator to rule on, not adjusted unilaterally.

**`minion_attack_reach_distance` -- untouched, no measured reason to move it.** The authoring audit
requires `reach >= unit_stop_distance`; authored values are `1.8 >= 1.5`, and lengthening the windup
alone does not change either bound, so this stays exactly where `4-3b/R26` left it optional and this
pass left it alone.

**Golden measured unmoved, both directions**, confirming the standing `BC/R3` isolation (the
determinism fixture builds its own in-test `BalanceConfig` and never loads the authored resource):
full suite before the edit, `497 tests, 0 failed, 3878 assertions`, 30/30 integration PASS, golden
`4a089063a8b3eff2274c0ca300dafe80e4eb4d3970ada352ca432a7e39844bdf` held (test_determinism.gd:458/796
passed); full suite after, byte-identical `497 tests, 0 failed, 3878 assertions`, 30/30 integration
PASS, same golden held. Both runs under the 4-3b-tightened harness gate (fails on any `^ERROR:`
line); neither produced one.

**No coupling to `tools/retime_clips.gd` -- confirmed by content.** That tool retimes HERO animation
clips; there are no minion animation clips to retime, and a content search of the tool for `minion`
returns no matches.

**The rest of the feel checklist stays DEFERRED, not resolved.** Per `4-3b/R25`, the attack has no
visual telegraph, so the operator cannot see a swing begin or judge evading it -- tempo, evasion, and
read all stay unmeasurable until the rig/model/animation work (`4-3b/R27`, still unowned) lands. An
interim grey-box telegraph was again not built; the operator wants real models and animations, not a
placeholder.

**Two commits, both shown as a diff and confirmed before staging, neither pushed:** the balance
`.tres` alone; then this entry plus the board note. `docs/playtest-log.md` untouched (operator's own
record). Suite and golden re-measured, not re-baselined -- no golden edit, no test edit. Operator
reviews the log and pushes.

## Session 2026-08-14 -- 4-3c readiness gate, fix pass

`4-3c/R1` (decided by Matko) THE RIG STORY RUNS NOW, AHEAD OF TOTEMS -- a new decision, not a
citation. `4-3b/R27` only DEFERRED this assignment to the E4 close-out and never made it (the log
still recorded it unowned as of yesterday's `E3-R/R3` entry); superseded by this ruling. Reason: he
cannot judge minion feel against a grey box, and the melee retune stays cut (`4-3b/R26`) until the
rig lands.
`4-3c/R2` (ruled, gate's finding, ratified) `4-3c` SPLITS: AC1-4 stay; AC5 (strike alignment) and
AC6 (corpse lifecycle) are CUT to new story `4-3d-minion-strike-alignment-and-corpse-lifecycle`,
`backlog`, ordered directly after `4-3c`, depending on its AC4 liveness gate (`R4` below). Reason:
AC5 is `3-0a`-deferred-to-`3-0b`-class feel/timing work; AC6 changes actor LIFETIME (four runner
loops, two invalidated comments, the intent-recorder tap, debug pause/reset), not presentation.
`4-3c/R3` (ruled) MODEL PARENTS UNDER THE ROOT, NOT `Mesh`. Measured: `Mesh` carries a `+0.6`
upward transform (root sits at the body's FEET); a feet-origin model under it would double-offset
and hover, mirroring the hero's pre-`3-0b` float. `3-0a`/R1's discipline does not transfer -- AC2's
discretionary framing pointed the wrong way. AC2 gains a mutation-proven minion counterpart of
`test_vertical_alignment.gd` (`3-0b`).
`4-3c/R4` (ruled) `_aim_unit_actors` GAINS A LIVENESS GATE, invisible today only because
`_free_dead_unit_actors` frees a corpse's actor the same tick. Belongs in `4-3c` regardless of
`4-3d`'s linger -- the seat is wrong on its own, and `4-3d` depends on it rather than adding it.
**Pointer -- `4-3c/R5` AMENDED BY APPEND 2026-08-16 (see Session 2026-08-16 -- 4-3c1 third readiness gate, fix pass, below, decision-log `4-3c1/R3`).**
`4-3c/R5` (ruled) IDLE/WALK VELOCITY SIGNAL CORRECTED. Several `_approach_unit_actors` paths
`continue` without calling `approach()`; `CharacterBody3D.velocity` persists across ticks, so a
unit losing its target keeps playing `walk` forever. Fix: zero velocity on every such skip path
reaching a live node.
`4-3c/R6` (ruled) AC4's clip selection gets a MUTATION-PROVEN TEST: liveness-below-phase is the
named falling mutation (killed-mid-swing must go red), on the standing every-guard-falls discipline.
`4-3c/R7` (ruled, corrected figures) Integration baseline 30 -> 31 files (`4-3b` added two, recorded
one). Asset total ~34 -> ~35 MB (measured, 36,707,750 bytes). Dev Notes line citation corrected,
`match_state.gd:753` not `755`.
`4-3c/R8` (ruled, recorded) `.gitattributes` DISCHARGED, not opened at dev -- `git check-attr -a`
confirms the existing bare extension wildcards (`*.fbx`/`*.png`) already cover the new directory.
`4-3c/R9` (ruled, recorded) Change Log section added to `4-3c` (authoring pass row one, this fix
pass row two) -- every story reaching `done` has one.

**Rulings travelling with AC5/AC6 into `4-3d`:**
`4-3d/R1` (ruled) Collision-disable covers ALL nodes (`Collision`/`Hurtbox`/`Hitbox`) -- a live
`Hurtbox` would pollute the intent RECORDING. Deferred to a seat outside any physics callback
(in-callback flag changes raise an engine error the `4-3b`-tightened harness fails on).
`4-3d/R2` (ruled) Linger is TICK-COUNTED, timer ON THE ACTOR, never a parallel runner array --
wall-clock breaks `3-0b`'s paused step-through; a parallel array survives the debug reset.
`4-3d/R3` (ruled) `death`'s net displacement is accepted, NOT on `3-0a`/R9's hero-specific
reasoning (round-over freeze). Correct reason: `_approach_unit_actors` already gates on
`is_alive_at`, so nothing ever drives a dead unit again -- `4-3c`'s citation is corrected.
`4-3d/R4` (ruled, recorded) Two shipped comments assert the broken invariant --
`match_state.gd:744-747` (inside `src/state/`) and `match_runner.gd:975-978` -- both named
collateral to correct; scope statement corrected to "no BEHAVIOURAL change under `src/state/`; one
comment corrected."
`4-3d/R5` (ruled, recorded) `attack.fbx`'s real length was never measured; `4-3d` measures it
first -- available alignment mechanisms depend on that figure.
**Pointer -- `4-3d/R5` SUPERSEDED 2026-08-26 (see Session 2026-08-26 -- 4-3d third readiness gate, fix pass, below, decision-log `4-3d/R18`).** The entry above is untouched and stands as the record; the length has since been measured (2.6667 s, 80 keys, `4-3c`'s own Dev Agent Record) and this ruling's premise no longer holds.
`4-3d/R6` (recorded, NOT decided) Three alignment-mechanism options (playback rate; partial range;
custom-speed offset) recorded as an OPEN QUESTION for `4-3d`'s own gate -- operator has not ruled.
**Pointer -- `4-3d/R6` SUPERSEDED 2026-08-26 (see Session 2026-08-26 -- 4-3d third readiness gate, fix pass, below, decision-log `4-3d/R11`).** The entry above is untouched and stands as the record; the operator has since ruled custom playback rate as THE mechanism.

### Close-out (fix pass)

Docs only, no code touched. `4-3c` split into `4-3c` (AC1-4, `authored`) and `4-3d` (AC5-6, new,
`authored`, `backlog`, after `4-3c`). `sprint-status.yaml` corrected to cite `4-3c/R1` rather than
`4-3b/R27`'s undischarged deferral. No golden/suite/`project.godot` measurement this pass. Operator
reviews the log.

## Session 2026-08-14 -- 4-3c/4-3d second readiness gate, fix pass

`4-3c/R15` (decided by Matko) CONTROLLER PUSHED BEFORE THE LIVENESS SKIP, NOT AFTER -- AC4's push
and liveness gate are ordered: push unconditionally first, aim-liveness check second. An early skip
ahead of the push would freeze `4-3d`'s lingering corpse mid-swing instead of playing `death`;
harmless in `4-3c` only because the actor is freed same-tick. `4-3d` states this dependency.
`4-3c/R10` (ruled) AC1's death-topple ACCEPTANCE struck -- measures and records only; acceptance is
`4-3d`'s (`4-3d/R3`). Dangling `AC 6 (below)` pointer and both stale citations removed.
**Pointer -- `4-3c/R12` AMENDED BY APPEND 2026-08-16 (see Session 2026-08-16 -- 4-3c1 third readiness gate, fix pass, below, decision-log `4-3c1/R3`).**
`4-3c/R12` (ruled) Velocity-zeroing path list REWRITTEN against measured code -- only
`match_runner.gd:776-777` and `:780` qualify; `balance == null` and the pre-node `has_index`/
`is_alive_at` continues have no live node yet.
`4-3c/R13` (ruled) AC2 cross-check re-specified against the spawn constant (`match_runner.gd:650-657`,
ground Y = 0.0) -- minions spawn from code, no spawn scene node.
`4-3c/R11` (recorded) Vertical-alignment test gets a NAMED mutation: re-parent under `Mesh`, or
restore `Mesh`'s offset onto the parent, must go red.
`4-3c/R14` (ruled) Unmeasurable corpse item removed from Live Smoke, not replaced -- `4-3d`'s to
smoke.
`4-3c/R16`/`R17` (non-blocking) Stale `AC 6` pointer corrected; Dev Note added -- push seat reads the
PREVIOUS tick's velocity, harmless for idle/walk.
`4-3d/R7` (recorded) Hold-final-pose cited ONCE, as `3-0a/R5`, matching the log.
`4-3d/R8` (recorded) The ~2.7s estimate restated as `4-3d`'s own UNVERIFIED figure, not quoted from a
line `4-3c`'s cut deleted.
**Pointer -- `4-3d/R8` SUPERSEDED 2026-08-26 (see Session 2026-08-26 -- 4-3d third readiness gate, fix pass, below, decision-log `4-3d/R18`).** The entry above is untouched and stands as the record; the length is now measured, not estimated.
`4-3d/R9` (recorded) Harness `^ERROR:` citation corrected to `test/run_all.sh` -- `4-3b/R31` is the
orphaned-process ruling, not this one.
`4-3d/R10` (recorded) `4-3d`'s corpse behaviour depends on `4-3c/R15`'s push ordering, stated in its
inherits section.

### Close-out (second fix pass)

Docs only, no code touched. Both stories stay `authored`/`backlog`. `sprint-status.yaml` story_notes
updated to reflect `4-3c/R10`-`R17` and `4-3d/R7`-`R10`. No golden/suite/`project.godot` measurement
this pass. Operator reviews the log.

## Session 2026-08-15 -- 4-3c live smoke, yaw convention and rooting-during-swing scope

`4-3c/R18` (ruled, recorded) Canonical yaw convention for models on a unit-family root: `hero.gd:40`
(`atan2(facing.x, facing.y)`, no `+PI`) is CANONICAL, matching a raw Mixamo import's native +Z front
-- `hero.tscn`'s Mesh/Paladin carry no compensating rotation. `unit_actor.gd:106`/`:120` (`aim_along`/
`aim_at`, `+PI`-shifted) is a non-canonical convention local to the UnitActor root. Any future model
mounted on a `+PI`-form root MUST carry its own compensating yaw on the MODEL INSTANCE node only
(yaw only, zero translation, never root/hitbox/hurtbox) and MUST ship a facing-vs-aim test in
`test_unit_model_facing.gd`'s shape (world-space forward vs aim direction, never a yaw-field
compare). Recorded because a backwards-mounted minion passed three readiness gates and a dev pass
undetected.

`4-3c/R19` (recorded, NO slot granted) Units are ROOTED during their own swing, mirroring the hero (operator's
decision; mechanism measured here, NOT implemented). Measured: neither `_approach_unit_actors`
(`match_runner.gd:795-856`) nor `unit_actor.gd:143-150`'s `approach()` reads `attack_phase_at`; max
speed on a non-IDLE tick measures the full authored `unit_move_speed` (3.0). The hero is already
rooted -- `match_state.gd:1712` scales speed by `_attack_phase_multiplier`, `balance_config.tres:
21-23` authors windup/active/recovery at 0.0, only `attack_lunge_distance` (:24) moves him. Minions
get the same full root; accepted cost: minions become KITEABLE. Also: a swing that leaves reach
mid-flight still COMPLETES (begins only in-reach at `match_state.gd:775-782`; the phase machine,
`:755-774`, advances on tick counters with no reach re-check) -- under a root rule this is the
correct commitment punishment, DELIBERATELY KEPT. This ruling TOUCHES `src/state/match_state.gd` and
MOVES THE GOLDEN -- it is NOT `4-3c` and NOT `4-3d`; it needs its own story and slot, NONE granted
here.

### Close-out

Docs only, no code touched. `4-3c` stays `review`. No golden/suite/`project.godot` measurement this
pass. Operator reviews the log.

## Session 2026-08-16 -- E4 forcing-point recording: projectiles (camera lock-on checked, already recorded)

Docs-only recording pass. Camera/lock-on was checked against this log first: `DP/R1` (Session
2026-07-31, above) and `E4-P/R11`'s "camera always-lock-on/retarget (no owner...)" line already carry
the LIGHT/FULL variant split, the `block_facing_arc_degrees`/orientation-as-defense conflict, the
off-screen-enemy-hero/Legibility Principle conflict, and the no-owner/no-slot/E4-forcing-point status
verbatim. Nothing added or duplicated for camera/lock-on.

`E4-P/R12` (recorded, NO owner, NO slot) PROJECTILES: operator ruling, 2026-08-10, previously
unrecorded. A projectile FLIES -- a real entity with a position that can be dodged, never an
abstract resolution over an acquired target. It is SHARED infrastructure, not a totem speciality:
its source may be a totem, a minion, or a hero spell card. Open addressing problem, recorded so it
is not rediscovered at implementation: a projectile OUTLIVES its source, so `[slot, index]` into the
unit board (the address form `4-3a/R16` widened the dedupe key to) cannot address it -- it needs its
own attacker identity and its own dedupe. This meets the `spell_*` forcing point already owed at E4
close-out (`E4-P/R10`, "spell resolution acquires an owner at the E4 close-out at the latest"), since
the projectile is those cards' delivery path -- the two open items converge on one owner, not two.
A cut is PROPOSED, not decided: accelerators in `4-4`, Combat Totem plus projectiles in a new
`4-4a`. This entry does not rule the cut; that stays the operator's. Forcing point: E4. No board
entry made -- placement is undecided.

### Close-out

Docs only, no code touched. No board entry added for either item (neither has an owner or a slot).
`sprint-status.yaml` untouched this pass. Operator reviews the log.

## Session 2026-08-16 -- 4-3c1 third readiness gate, fix pass (rulings R1-R3)

`4-3c1/R1` (ruled) THE SEAT. `unit_attack_phase_multiplier(phase)` is a pure function in
`src/state/match_state.gd`, read inline by the runner at `match_runner.gd:844-845` (CONSTRAINT C, no
caching). The hero precedent does NOT transfer directly: the hero's `velocity` IS hashed state
(`hero_state.gd:5-9`), so `match_state` both computes and applies it; a unit's velocity is
actor-owned (`unit_actor.gd:143-151`, no `Vector3` on `UnitBoard`), so `match_state` may only EXPOSE
the rule, never apply it -- the same shape as the contact fact, where a derived fact crosses the seam
and ownership does not.
`4-3c1/R2` (ruled) IDLE RETURNS 1.0. `attack_phase_at` is a FOUR-value enum (`match_state.gd:755-774`);
the hero's `_attack_phase_multiplier` (`:1738-1745`) matches a three-value StringName with an `_:`
catch-all. A literal mirror maps IDLE onto the recovery field (authored 0.0) and roots every unit
permanently, including units that have never attacked. No catch-all may fall through to a phase
field; IDLE and any other non-attacking phase return 1.0 explicitly.
`4-3c1/R3` (ruled) AMENDS `4-3c/R5` AND `4-3c/R12`. Their "exactly two velocity-zeroing paths" list is
a RULED list, not a comment convention. A third path now exists: decided at the
`_approach_unit_actors` call site (`match_runner.gd:844-845`) and written inside
`UnitActor.approach()` (`unit_actor.gd:143-151`), and unlike the two listed paths it DOES call
`move_and_slide()` (`:151`) even at zero velocity. The source comment block at
`match_runner.gd:817-838`/`:847-854` must be updated in the same pass that adds the third path -- a
ruled list that stops matching the code is the defect this project keeps correcting.

### Close-out

Docs only, no code touched. `4-3c1` stays `authored`, board stays `backlog`. No golden/suite/
`project.godot` measurement this pass. Operator reviews the log.

## Session 2026-08-17 -- 4-3c1 dev-pass findings, recorded (rulings R4-R6)

`4-3c1/R4` (recorded) the approach-test EXPECTED-FAILURE prediction was wrong, and the mechanism is
GEOMETRY-DEPENDENT, not a design property. `_push_reach_probe` fires only every
`minion_retarget_interval_ticks` (`match_runner.gd:1115`, 12 ticks / 0.6 units at the authored
speed) -- twice the 0.3-unit band between `unit_stop_distance` and `minion_attack_reach_distance`.
No probe lands in-band at the shipped geometry, so `test_unit_approach_live.gd:225` passes
untouched. A retune of speed, either distance, probe cadence, or spawn position can flip it red.
Not hardened; hardening is an untaken scope decision.
`4-3c1/R5` (recorded) `test_intent_recorder.gd`'s intake-derivation rule is WIDENED by a second
named exemption, `EXEMPT_PURE_QUERY`, for `unit_attack_phase_multiplier` -- a parameterised method
that is still not an intake because it is a pure function of its argument. Matched by NAME, not by
verified purity: a future method reusing the name, or a later edit making this one impure, passes
unchallenged. Deliberately not generalised to "any parameterised query" -- each exemption stays an
argued ruling.
`4-3c1/R6` (recorded) `4-3c/R12`'s cited coordinates (`match_runner.gd:776-777`/`:780`) are STALE,
measured at `:839`/`:855` before this story's edit and `:855`/`:884` after. Rulings must name the
construct first and the coordinates second -- line numbers decay, constructs don't.

### Close-out

Docs only. `4-3c1` stays `review`, board stays `ready-for-dev`. No golden/suite/`project.godot`
measurement this pass beyond item 1's own state-test verification (see story artifact). Operator
reviews the log.

## Session 2026-08-26 -- 4-3d third readiness gate, fix pass (rulings R11-R18)

`4-3d/R11` (ruled by Matko) MECHANISM DECIDED: custom `AnimationPlayer` playback rate is THE AC 1
alignment mechanism, superseding `4-3d/R6`'s open question. (b) a partial clip range and (c) a
`custom_speed`/start-offset play call are REJECTED -- both require playback to begin partway into
the clip to land the strike in the active window, which removes the front of the windup, the
anticipation the player reads to time a parry. Accepted consequence, in the operator's words: the
whole swing plays visibly faster than authored, complete and uncut, and that is accepted.
`4-3d/R12` (ruled) WITHDRAWN: a rate band (1.4035-1.5926) and a peak-time figure (1.4333 s) circulated
in conversation, derived from an input `4-3d/R13` shows unverifiable in this repo. Neither number is
stated anywhere in the story. Also withdrawn: the claim that one rate value fixes both the AC 1
strike alignment and the `4-3c`-observed ~0.767 s chained-swing truncation.
**Pointer -- `4-3d/R12` AMENDED BY APPEND 2026-08-26 (see Session 2026-08-26 -- 4-3d fifth readiness gate, fix pass, below, decision-log `4-3d/R21`).** The entry above is untouched and stands as the record; its clause "Neither number is stated anywhere in the story" is inaccurate as written -- both figures appear in the story, inside its own withdrawal paragraph -- and the accurate claim is that neither is stated as LOAD-BEARING.
`4-3d/R13` (ruled) The hips-displacement excursion peak is NOT accepted as a proxy for the strike
frame. The dev pass measures the STRIKE FRAME -- the frame at which the claw arrives, the thing the
player reads -- and the rate is derived FROM that measurement, not assumed ahead of it. The figure
"hips peak at t = 1.4333 s" is unverifiable: `1.4333 s` is `walk`'s clip length in `4-3c`'s own table
(`4-3c-minion-rig-adoption.md:608`), not a time-of-peak for `attack`.
`4-3d/R14` (ruled) REOPEN CONDITION added to AC 1: the rejection of (b)/(c) assumes the measured
strike frame sits in the back portion of the clip. If the measured strike frame is early enough that
a rate aligning it would leave the clip shorter than the 1.9 s cycle unachievable -- the arithmetic no
longer favours (a) -- the dev pass STOPS and returns the choice to the operator rather than
improvising. A stop condition, not a caveat.
**Pointer -- `4-3d/R14` AMENDED BY APPEND 2026-08-26 (see Session 2026-08-26 -- 4-3d fourth readiness gate, fix pass, below, decision-log `4-3d/R19`).** The entry above is untouched and stands as the record; its stated arithmetic was inverted and its trigger is corrected by the entry referenced below. The STOP mechanism itself -- return the mechanism choice to the operator rather than improvise -- is unchanged.
`4-3d/R15` (ruled) PRIORITY: alignment of the visible strike beats elimination of the truncation. If
the ruled rate still truncates chained swings, that is a Live Smoke watch item, not a blocker -- the
parry symptom is an observed live defect (`4-3c1`'s smoke); the truncation has never been judged by
eye.
`4-3d/R16` (ruled) AC 2 SPLITS into independently falsifiable criteria: AC 2 (retention +
walk-through), AC 3 (timer seat, tick-counting, debug pause and reset), AC 4 (collision disable
outside any physics callback), AC 5 (`death` clip holds final pose). The death-displacement
acceptance reasoning and the two shipped-comment corrections move out of AC numbering into Dev
Notes/collateral -- they are not independently falsifiable behaviour.
`4-3d/R17` (ruled) Every guard this story proposes asserts a VISIBLE EFFECT, not an identifier. For
AC 1 that is the clip's playback position at the moment the ACTIVE window opens -- not the rate
value, not the clip name, not source line order. `test_unit_clip_selection.gd` Part B's inherited
line-order/indentation guard is REPLACED, not extended, by a behavioural assertion in Part A's shape.
`4-3d/R18` (recorded) `attack.fbx`'s real length is measured: 2.6667 s, 80 keys (`4-3c`'s own Dev
Agent Record, Hips-track table, `4-3c-minion-rig-adoption.md:605-609`). Supersedes `4-3d/R5` (never
measured) and `4-3d/R8` (restated as an unverified ~2.7 s estimate) -- both premises no longer hold.

Also corrected this pass, not separate rulings: `match_runner.gd` coordinates re-cited from the
stale `975-978`/`770` (rotted ~80-100 lines since `4-3c`'s dev pass landed) to the current
`1083-1084` (`_gather_unit_facts`'s header, not the aim pass) and `795`/`811`
(`_approach_unit_actors`/its `is_alive_at` gate), each with its anchor text quoted so the next rot is
self-healing. AC 4's Hurtbox rationale corrected from "facts no tick consumes" to a
recording/replay-stream cleanliness argument, citing `match_state.gd:1101`'s dead-target drop as the
reason gameplay is not at risk; the per-node collision property corrected (`Hurtbox` needs
`monitorable`, `Hitbox` needs `monitoring`, `Collision` needs `disabled` -- not one property named for
all three). The debug-reset relay's Dev Note corrected from "must free a lingering corpse too" to a
confirmed no-op (`_free_unit_actors`, `match_runner.gd:912-918`, frees every entry unconditionally).
The `^ERROR:`-on-physics-callback claim split into its measured half (the harness,
`test/run_all.sh:18-19,32-33`) and its assumed half (the engine behaviour, to be confirmed live by
the dev pass). `baseline_commit` re-baselined `1ddff87` -> `f009dd5`. Golden hash named explicitly
(`4a089063...`) rather than left as an unanchored "both directions" prediction.

### Close-out

Docs only, no code touched, no `src/`/`test/`/`project.godot` edit, editor never opened. `4-3d`
stays `authored`, board stays `backlog` -- promotion is the operator's act. No golden/suite/
`project.godot` measurement this pass. Operator reviews the log.

## Session 2026-08-26 -- 4-3d fourth readiness gate, fix pass (second docs-only correction pass)

`4-3d/R19` (ruled) REOPEN CONDITION arithmetic corrected -- amends `4-3d/R14`'s stated trigger, not
its stop-condition mechanism. Let `T` = the measured strike frame's timestamp within the 2.6667 s
clip. Aligning the strike to the START of the ACTIVE window gives rate `r = T / 0.9`; effective clip
duration is then `L/r = 2.4 / T`. Break-even at `T = 1.263 s` (`r = 1.40`, duration exactly 1.90 s).
`T > 1.263 s`: duration falls BELOW the cycle -- the clip ends early and holds its final pose, no
truncation. `T < 1.263 s`: duration rises ABOVE the cycle -- chained swings still truncate, which
`4-3d/R15` already rules a Live Smoke watch item, NOT a stop condition -- it survives with the
alignment still achieved. `T < 0.9 s`: `r < 1.0`, the swing plays SLOWER than authored, contradicting
`4-3d/R11`'s accepted consequence. NEW STOP CONDITION, superseding `4-3d/R14`'s stated trigger: the
dev pass STOPS and returns the mechanism choice to the operator if the required rate `r` falls
OUTSIDE `[1.0, 2.0]` -- below 1.0 contradicts the accepted consequence, above 2.0 exceeds anything
the operator accepted. Within that band the dev pass proceeds and the operator's eye rules at Live
Smoke.

**Pointer -- `4-3d/R19` AMENDED BY APPEND 2026-08-26 (see Session 2026-08-26 -- 4-3d fifth readiness gate, fix pass, below, decision-log `4-3d/R20`).** The entry above is untouched and stands as the record; its upper stop bound (`r <= 2.0`) was supplied without derivation and is removed -- the stop condition is now `r < 1.0` only. The STOP mechanism itself -- return the mechanism choice to the operator rather than improvise -- is unchanged for the surviving trigger.

Also corrected this pass, not separate rulings: the `4-3b/R27` and `4-3b/R26` citations in AC 1
removed where they did not support their claim (`4-4` ordering is not authorised by `4-3b/R27`; the
windup `0.5 -> 0.9` figures now cited to the measured `.tres` only, the ruling attribution dropped).
AC 5 gains a named EFFECT guard (playback position pinned at the clip's end) where it previously had
none. `test_unit_clip_selection.gd` Part B's guard is now explicitly REPLACED, not extended, per
`4-3d/R17`'s literal text, with a task deleting the `push_line < gate_line` assertion; its
behavioural-replacement task's AC tag corrected from 1 to 5. `sprint-status.yaml`'s "Former AC6"
corrected to "Former AC 2", matching `4-3d/R16`. The runner-loop enumeration corrected from four to
five, adding `_gather_unit_facts` (`match_runner.gd:1083-1084`) as the loop whose shipped header
comment this story invalidates and whose corpse-bearing behaviour AC 4's collision-disable exists to
keep clean. Nine guards now each carry a named mutation that must turn them red, on this project's
standing mutation-table practice. `4-3c-minion-rig-adoption.md`'s stale inbound `4-3d` AC references
(`:622`, `:852`, `:890`) and `sprint-status.yaml:112` corrected to the current AC numbering.

### Close-out

Docs only, no code touched, no `src/`/`test/`/`project.godot` edit, editor never opened. `4-3d`
stays `authored`, board stays `backlog` -- promotion is the operator's act. No golden/suite/
`project.godot` measurement this pass. Operator reviews the log.

## Session 2026-08-26 -- 4-3d fifth readiness gate, fix pass (third docs-only correction pass)

`4-3d/R20` (ruled by Matko) STOP CONDITION upper bound REMOVED -- amends `4-3d/R19`'s stated trigger,
the same way `4-3d/R19` amended `4-3d/R14`'s; `4-3d/R19` is untouched and stands as the record.
`4-3d/R19`'s upper bound (`r <= 2.0`) was supplied without derivation and is struck. The dev pass
STOPS and returns the mechanism choice to the operator ONLY if the required rate `r < 1.0`
(equivalently `T < 0.9 s`, the variable actually measured) -- below 1.0 the swing plays SLOWER than
authored, contradicting `4-3d/R11`'s accepted consequence. No upper stop is derivable or needed: the
mechanism is self-bounding -- the latest possible strike frame is the clip's own end, `T = 2.6667 s`,
giving `r = 2.963` and an effective clip duration of `2.4 / 2.6667 = 0.9 s`. Admissible strike-frame
timestamps are simply `T >= 0.9 s`, no upper limit. Above `r = 1.0` the dev pass proceeds and records
the measured `T`, the derived `r`, the effective clip duration, and which artefact results
(truncation or held final pose, with its duration per cycle) in Dev Notes; the operator's eye rules at
Live Smoke.

`4-3d/R21` (recorded) **Correction (append) to `4-3d/R12` (above).** Authored by the fourth fix pass
as an unnumbered correction; NUMBERED by this fifth pass so `4-3d/R12` can carry a pointer to it, its
text and its location otherwise unchanged. The
clause in `4-3d/R12`, "Neither number is stated anywhere in the story," is inaccurate as written: both
figures appear in the story, inside the withdrawal paragraph itself. `4-3d/R12` is untouched; the
accurate claim is that neither figure is stated as LOAD-BEARING -- no surviving claim anywhere uses
either number to derive the ruled rate. (Relocated from the third-pass session block, where it was
originally misplaced; authored by the fourth fix pass, not this one.)

Also corrected this pass, not separate rulings: Live Smoke gains one bullet covering both branches of
the corrected arithmetic (truncation if `T < 1.263 s`, held final pose if `T > 1.263 s`), since which
occurs depends on a dev-pass measurement, citing `4-3c-minion-rig-adoption.md:853-857` (anchor
"CONSEQUENCE, stated plainly and NOT fixed here") and `:894` (the `2026-08-15` DEFECT B1 FIX PASS
Change Log row, anchor "the `_select` dedup held the finished clip's final pose for ~9.7s"); AC 1
`:98-99` no longer frames the held-pose branch as costless. The mutation table (Dev Notes) is now
labelled PROVISIONAL with an explicit obligation on the dev pass to re-derive every mutation against
the seat it actually picks. AC 5 gains an implementing task for its playback-pinned guard, with `N`
bound to AC 2/3's already-bound retention count (N+599). The walk-through observable moves from AC 2
to AC 4 (the mechanism that produces it, per `4-3d/R16`'s own independent-falsifiability standard);
AC 2 retains retention as its own independently falsifiable content; mutation 3 updated to serve AC 4.
Mutation 1 (AC 1) now states the tolerance that must fail it; mutation 6 (AC 4) marked dependent on
AC 4's own deferred per-node measurement. `4-3d/R14`'s pointer corrected ("referenced above" ->
"referenced below" -- it points to `4-3d/R19`, which sits below). `4-3d/R8`'s pointer now says "The
entry above", matching the canonical form, now that it sits immediately below its own entry. AC 1
`:129`'s withdrawal paragraph corrected: it no longer claims no rate figure is stated anywhere -- the
derived break-even `r = 1.40` is legitimately stated and is distinct from the WITHDRAWN circulated
band. `4-3c-minion-rig-adoption.md`'s `:628-629` and its `:894` Change Log row (the `2026-08-15`
DEFECT B1 FIX PASS row; cited as `:890` when written, before this pass's own annotation shifted the
file by +4) -- both edited beyond a
stale AC number by the fourth pass -- are REVERTED to original wording, with an appended annotation at
`:628-629` and a new Change Log row recording the revert; the closed story's record is not rewritten
backwards. `4-3c1-swing-commitment.md:347` and `:530` (stale `4-3d AC 5` references) corrected to
`AC 1`, completing the sweep `sprint-status.yaml:112` already had; a third stale `AC 5` instance found
in `sprint-status.yaml:112` itself, missed by that same sweep, is also corrected.

### Close-out

Docs only, no code touched, no `src/`/`test/`/`project.godot` edit, editor never opened. `4-3d` stays
`authored`, board stays `backlog` -- promotion is the operator's act. No golden/suite/
`project.godot` measurement this pass. Operator reviews the log.

## Session 2026-08-29 -- 4-4 readiness gate fix pass, rulings `4-4/R1`-`4-4/R12`

`4-4/R1` (ruled) 8 M FIRING RANGE. Working, playtest-tunable value; derived against the 40x40 m
arena (`main.tscn`) so the totem's threat radius stays well inside the arena rather than covering it.
`4-4/R2` (ruled) 60 M PROJECTILE TRAVEL BUDGET. Derived against the same arena: the 40x40 m Ground's
diagonal is ~56.57 m; 60 m rounds up so a corner-to-corner shot can complete before the budget
expires. Distinct from `4-4/R1` -- travel budget vs. firing permission govern different things.
`4-4/R3` (ruled) HOMING AND ACCELERATION ARE AUTHORED DATA. A live projectile's heading updates per
an authored homing profile and it accelerates per an authored acceleration profile; no code branch
selects between behaviors by kind.
`4-4/R4` (ruled) I-FRAME DROP ENDS HOMING. The existing i-frame drop rung (`1-9/R1`) also ends that
projectile's homing on the same tick: the projectile holds its last heading and flies straight for
the remainder of its flight budget.
`4-4/R5` (ruled) SPATIAL DODGING DOES NOT END HOMING. A target leaving the flight path with no
i-frame window open does not end homing. Only `4-4/R4` ends homing.
`4-4/R6` (ruled) BLOCK/DEFLECT CONSUME THE PROJECTILE. A contact fact resolving as a block or a
deflect consumes the projectile on that contact.
`4-4/R7` (ruled) EVERY KIND'S ATTACK CAPABILITY IS A LIST. Per the 4-3b close-out wording, a kind has
a LIST of attack records (length one acceptable this story), never a single flat attack.
`4-4/R8` (ruled) PER-KIND AUTHORED TARGETING PRIORITY, BY NAME. Each kind authors its targeting
priority as a reference to an existing `MinionPriority.priority_name`. Spends `4-2/R17`(c) and
`4-3/R6`. `_update_unit_targets`'s hardcoded `PRIORITY_STANDARD` lookup becomes a per-kind read; the
`REASON_NO_PRIORITY_DATA` missing-name contract and `hero_seeker`'s test-only status carry forward.
`4-4/R9` (ruled) SHIPPED COMBAT TOTEM AUTHORS A HERO-PREFERRING PRIORITY. A NEW shipped `.tres`
profile, a third alongside `standard` and the test-only `hero_seeker`. Minions keep `&"standard"`
unchanged. Rationale: projectile avoidance is designed for a target that can roll; a unit cannot.
`4-4/R10` (ruled) HOLD-FIRE OUT OF RANGE IS A POST-SELECTION GATE. The Combat totem acquires by its
authored priority (`4-4/R8`/`4-4/R9`) and holds fire while the acquired target is beyond `4-4/R1`'s
range; no re-selection by distance, no NEAREST `OrderingMode` -- that stays deferred work.
`4-4/R11` (ruled) STAMINA ACCELERATOR IS OWNER-ONLY. Only the summoning player's hero's stamina
regen is raised, by an authored factor, while the totem is alive; the opponent's regen is untouched.
Mechanism (per-player derived rate vs. multiplier at the regen seat vs. something else) stays a
dev-pass call within the `3-1/R2` per-pool reload contract.
`4-4/R12` (ruled) SPEED 0 FOR ALL THREE KINDS. Combat, Mana Accelerator, and Stamina Accelerator
totems are all authored with movement speed 0 and never leave spawn while alive -- not only the two
accelerators. Cites `gdd.md`'s "small, unimposing static structure."
`4-4/R13` (ruled) ACCELERATOR WORKING VALUES ARE DERIVED, NOT PRINCIPLED. The Mana Accelerator's
cadence/amount and the Stamina Accelerator's regen factor are derived relative to the existing
`passive_tick` rule and the non-accelerated `stamina_regen_per_second` baseline, respectively --
playtest-tunable working values, not a new mechanism. Exact figures are a dev-pass measurement
against the live `.tres`, recorded at dev time.

Also fixed this pass, not separate rulings: AC 3's collision pattern corrected to name the `Hurtbox`
member the damage path actually needs, and that no totem kind authors a `Hitbox`; AC 9's per-kind
conversion inventory widened from four `BalanceConfig` globals to eleven, naming the seven further
attack-timing/multiplier globals; AC 11 (test list) gains `test_balance_config.gd`; "shape" is
dropped from the attack record with no ruling to replace it; AC 18/19 (Mana/Stamina Accelerator, now
AC 20/21) corrected for the third `_generate_mana` call site and the owner-only wording; two Open
Questions closed by citation (`E4-P/R12` for projectile addressing's principle; `epics.md`'s
`FeatureFlags: minions, totems` commitment for the totems-flag gate); Dev Notes citations converted
from line numbers to symbol names per the standing citation discipline.

### Close-out

Docs only, no code touched, no `src/`/`test/`/`project.godot` edit. `4-4-totems` stays `authored`,
board stays `backlog` -- promotion is the operator's act. No golden/suite/`project.godot`
measurement this pass. Operator reviews the log.

## Session 2026-08-30 -- 4-4 review fix pass, rulings `4-4/R14`-`4-4/R15`

`4-4/R14` (ruled, operator) A REACH CONFIRMATION HAS A DERIVED SHELF LIFE. Review finding B2: this
story added the firing cadence as a third AND on the windup gate, which turned an in-reach flag that
was consumed on the next IDLE tick into one BANKED FOR A WHOLE COOLDOWN -- so a Combat totem fired a
homing shot at a target that had walked ~18 m away, twice its authored 8 m range, violating AC 13's
"never regardless of how long it remains in that state".

THE `4-3b` PROHIBITION STANDS: the reach probe remains SET-ONLY, and AC 13(ii)'s "absence of overlap
is not a fact" is untouched -- no negative probe was added and nothing outside the board clears the
flag. Instead the STATE treats a confirmation as FRESH only for a bounded window, and a unit may
BEGIN an attack only on a fresh confirmation. THE WINDOW IS DERIVED, NEVER A NEW AUTHORED FIELD: a
confirmation older than one probe cadence (`minion_retarget_interval_ticks`, plus the F1 one-tick
lag) can no longer be current, because the runner would have re-confirmed it by now if the target
were still in range. Mechanism was the dev pass's to choose; it chose a per-record countdown of fresh
ticks, re-seeded (not extended) by each confirmation, aged in `tick_attack_timers` beside the cadence
cooldown, and consumed by `begin_windup_at` exactly as the bool was.

THE COUNTDOWN IS HASHED STATE BY `4-3a/R17`, and that is the operator's explicit call rather than the
dev pass's: a value that crosses ticks and decides an outcome cannot sit outside the hash, and how
much freshness is left decides whether the next windup may begin. The cheaper option -- snapshot only
the boolean predicate, which keeps `d94337cd` unmoved -- was MEASURED and REFUSED by name, because it
would have made the remaining count a FOURTH unhashed cross-tick exclusion and put two genuinely
different states on one hash. GOLDEN RE-BASELINED `d94337cd` -> `a96b123e`, ONE CAUSE: the key SET
does not move (still 27 per player) and no behaviour in the fixture moves either (every fact it
pushes is hero-sourced, so the countdown sits empty all run) -- only `unit_in_reach`'s rendering,
`false` -> `0`. Measured both ways: projecting the count back to a bool reproduces `d94337cd`
exactly. `UNHASHED_CROSS_TICK_MEMBERS` STAYS AT THREE.

`4-4/R15` (ruled) `RecordFile.FORMAT_VERSION` GOES 4 -> 5, WITH NESTED RESOURCE SERIALISATION.
Review finding B1, and the fourth bump in this family -- but the first whose cause is the recorded
BALANCE CONFIG's shape rather than the contact row's. `4-4` gave `BalanceConfig` an
`Array[UnitKindProfile]`, and `_resource_values` was a one-level capture: it handed live `Resource`
references to `store_var`, which encodes each as an `EncodedObjectAsID` because `full_objects`
defaults to false, and assigning that untyped array into the typed property is REJECTED BY THE ENGINE
WITH NOTHING PRINTED. Measured against the shipped `.tres`: `rebuilt unit_kinds size = 0`. Every
replay from disk therefore ran with NO KINDS AT ALL -- no hp, speed, damage, attack or priority on
any summoned unit.

Two halves, both closed. (a) POST-4-4 RECORDS ROUND-TRIP: `_resource_values` / `_rebuilt` recurse
through Resource-valued properties and Resource-valued arrays, emitting a class-tagged dict per
nested resource, and typed containers are rebuilt with `Array.assign` / `Dictionary.assign` onto the
property's own container rather than `set()` (measured on Godot 4.6.3: `set()` with an untyped array
leaves size 0 even when every element is the right class). (b) PRE-4-4 RECORDS ARE REFUSED: a v4
record carries the retired flat keys and no `unit_kinds`, so replaying one diverges from the match it
claims to reproduce. HARD REJECTION WITH A REASON, NO SHIM, on `4-1/R1`'s standing reason.

RESIDUE, written down rather than chased, on `3-0d/R25`'s footing: the nested class tag is matched
against an explicit three-entry table, and an unknown tag rebuilds as `null` rather than as a named
refusal. A v5 file can only carry those three because this build's writer is the only thing that
writes v5; a file carrying a foreign tag is corrupt input of the same family as the five cases
`3-0d/R25` already records.

### Close-out

Four code commits (B1, B2, H2, and the nine orphan `.uid` files as a separate chore), plus this docs
commit. Suite `542/4211` -> `548/4270`, 0 failed, 43 integration files PASS, `bash test/run_all.sh`
exit 0 after every commit. Golden `d94337cd` -> `a96b123e`, one cause, re-baselined on the operator's
explicit go rather than on the dev pass's judgement. `project.godot` untouched. Review findings
M1-M9 and L1-L5 deliberately NOT actioned -- they are recorded in `_44-review.md` and are the
operator's to schedule. The Tier A live smoke remains unspent. Nothing pushed.

---

## Session 2026-08-30 -- gds-correct-course: camera/lock-on adopted into E4, DP/R1 resolved

Docs-only pass. `E4-P/R11`'s own forcing-point note ("a board full of minions may hand this a
forcing point during E4; if so, that is a `gds-correct-course`, not silent adoption") is now met --
`4-4-totems` is done, so the board carries minions and totems, i.e. more than one lock-on target
exists. Operator ruled (browser, 2026-08-30) to adopt camera/lock-on into epic 4 now, via this
`gds-correct-course` run, ordered before `4-5-pooling-60fps-exit`. Full Sprint Change Proposal:
`docs/planning-artifacts/sprint-change-proposal-2026-08-30.md`.

**CC/R1 -- `DP/R1` open decision (f) content is RESOLVED.** `DP/R1` (Session 2026-07-31, above)
opened two sub-questions and left the whole decision OPEN. Both are now answered, per operator
ruling:

(i) Facing follows the locked target -- FULL variant, not camera-only. The hero always faces the
locked target regardless of movement direction. `HeroState.facing` ownership moves from
input-derived to target-derived. Golden WILL move; snapshot is touched -- hard Tier A, accepted
with eyes open. Consequence, ruled deliberately: against the locked target, the 180-degree block
arc never misses, so block becomes pure timing (Sekiro-style); orientation-as-defense migrates into
target selection, since minions/totems can attack from outside the locked frame.

(ii) Off-frame targets are handled by the retarget model below (right-stick flick), not by keeping
the enemy hero pinned on-screen. The Legibility Principle's <0.5s telegraph-read requirement was
written assuming an on-screen target; an off-screen opposing-hero attack is read by sound only for
now. This is recorded as a NAMED PLAYTEST QUESTION -- does sound alone give adequate warning? --
not settled here and not story scope for `4-6-camera-lock-on`.

**CC/R2 -- Always lock-on confirmed; `InputIntent.aim` free-rotation route SUPERSEDED (not
supplemented), per `DP/R1`'s own original wording.** Never a free camera. Default and fallback
target: the opposing hero.

**CC/R3 -- Controls (DS/ER/Sekiro model).** Right-stick CLICK instantly re-locks onto the opposing
hero. Right-stick FLICK switches lock to the best on-screen candidate in that screen-space
direction (minions, totems, hero). No unlock state. Off-screen opposing hero is resolved by the
click.

**CC/R4 -- Live smokes run primarily on controller from now on.** The game targets controller feel;
the `2-2` pad-plugged-in-before-launch constraint stands.

**CC/R5 -- Delegated implementation direction, named not decided.** Retarget resolution follows the
contact-fact precedent (`1-8`/`4-1` R7 lineage): positions/screen space live outside `src/state/`;
the presentation side resolves a flick into a chosen target and pushes the RESULT (`[slot, index]`
or hero) as an input fact into the intent stream; replay records the outcome, not the stick.
Keyboard mapping is proposed in the story; controller is primary. Whether target-derived facing can
be computed without a live camera/scene query inside `src/state/` (D3(b)/A2) is confirmed, not
assumed, at the story's own readiness gate.

**CC/R6 -- Board mechanics, unchanged.** Story `4-6-camera-lock-on` enters the backlog only.
Lifecycle stays `backlog -> ready-for-dev -> done`; no promotion by this or any workflow
(`CFG/R2`/`R4`). Board-ordered BEFORE `4-5-pooling-60fps-exit` per operator instruction; the numeral
is historical/creation-order, not board order (precedent: `4-3a`..`4-3e` interleaving). Story spec
authoring is a separate `gds-create-story` run, not done by this pass.

### Close-out

Docs-only pass, one commit: this entry plus `epics.md` (E4 committed-obligations bullet),
`sprint-status.yaml` (one new backlog entry), and the Sprint Change Proposal artifact. No code
changed, no golden or suite touched, nothing pushed. Operator reviews the log and pushes.

---

## Session 2026-08-30 -- 4-6 readiness gate fix pass, rulings `4-6/R1`-`4-6/R6`

Docs-only pass on `docs/implementation-artifacts/4-6-camera-lock-on.md`, resolving the four
blocking findings (B1-B4) from the story's own readiness gate (`_46-gate.md`). All six rulings
below are the operator's, given in chat; this commit is their first durable record.

`4-6/R1` (ruled, gate B1) THE CAMERA HALF IS IN SCOPE. `DP/R1`'s headline sentence is the camera;
the FULL variant (`CC/R1`(i)) contains camera-only, it does not replace it. The story gains an AC
for a per-tick lock-on yaw on each slot's camera rig ROOT, framing that slot's own hero and its
locked target. Authored framing values (distance/height/pitch, `camera_config.tres`) and the
load-once pattern stay exactly as they are -- `apply_config()` writes only the CHILD camera's
`position`/`rotation_degrees` (unaffected); the new yaw is a separate write to the rig root. F1 is
unaffected: the yaw lands at the runner's existing per-tick seat (`match_runner.gd:1798`), not a
second `_physics_process`. Story Dev Notes' blanket "Camera rig / config, unaffected" and "this
story does not touch camera-relative movement" are DELETED (superseded by a corrected note); the
camera-config Non-Goal is reworded to protect only the framing VALUES and load-once pattern, not
the rig root.

`4-6/R2` (ruled, gate B1(b)/(c)) THE MOVEMENT-BASIS CONSEQUENCE IS A SECOND, SEPARATELY MEASURED
GOLDEN CAUSE. Rig yaw makes the pushed camera basis (`match_runner.gd:1857-1860` ->
`MatchState.set_camera_basis` -> `match_state.gd:2292-2296`) non-identity in live play for the
first time, changing `world_dir` and the HASHED `HeroState.velocity` -- exactly the divergence
`3-0c/R2` predicted. The golden-movers AC now names TWO causes (facing ownership; live camera
basis), each measured and re-baselined separately, per the `4-3a/R17` and `4-4` AC 12 multi-cause
precedent. `test_camera_relative.gd` and `test_root_rotation_isolation.gd` -- both fixtures assume
a fixed or only-programmatically-rotated rig, per their own headers -- are RE-EXAMINED (not
assumed clean) by the dev pass against the new yaw driver; the story does not decide their outcome.

`4-6/R3` (ruled, gate B2) EXISTING RULES WIN OVER "UNCONDITIONALLY EVERY TICK." The DEAD early
return (`2-3/R14`) and the round-over step-1b freeze (`2-6/R6`) keep skipping the facing write
unchanged: a dead hero does not turn toward the target, a frozen round-end does not move. The
facing AC's "unconditionally every tick" now carries an explicit carve-out naming both branches.
The gate's compounding observation -- facing now feeds `_is_facing`, so its "display-only"
classification is under tension -- is recorded as an inherited, PRE-EXISTING tension, not resolved
by this pass.

`4-6/R4` (ruled, gate B3) LOCKED-TARGET DEATH SNAPS THE LOCK IMMEDIATELY. When the locked minion or
totem dies, the lock moves to the opposing hero on the SAME TICK -- no corpse-hold window, despite
the corpse lingering on the board for several ticks after death (`4-3d`). This is now an explicit,
testable AC.

`4-6/R5` (ruled, gate B3 second hole) A DEAD OPPOSING HERO IS INERT UNDER THE STEP-1B FREEZE. When
the fallback target (the opposing hero) is itself dead, the round is over and `2-6/R6`'s freeze
makes nothing move or turn regardless of what the lock references -- one sentence added to the same
AC, citing `2-6/R6`.

`4-6/R6` (ruled, gate B4, confirmation made AT this gate per `CC/R5`) THE LOCKED TARGET'S DIRECTION
ENTERS `src/state/` AS A PER-TICK PUSHED FACT, through the same seam family as the camera basis
(`set_camera_basis`) and contact facts (`push_contact`) -- never a live scene/camera query inside
`src/state/`. Precedent already shipped: `_is_facing(hero, target_to_attacker)`
(`match_state.gd:1630-1632`) already consumes a runner-gathered `Vector2` direction fact this exact
way. The exact fact SHAPE (direction vector vs. position; field placement) REMAINS a dev-pass Open
Question; only the boundary MECHANISM is confirmed here.

Also fixed this pass, not separate rulings (notes N1-N10 from the gate): AC for the keyboard-binding
proposal reworded as a documentation deliverable, not a testable behavior claim, and cross-referenced
to its Open Question instead of duplicated (N1); the `FORMAT_VERSION` AC rewritten so the
MEASUREMENT, not either outcome, is the decided claim, same cross-reference fix (N2); the `aim`
retirement AC left as a retirement claim with disposition explicitly deferred, and its Open Question
re-read against `DP/R1`'s own "repurposed, still flowing through `aim`" lean without hard-ruling it
(N3); the AC 12 (now AC 12) line-span citation corrected (`gamepad_profile.gd` lines 24-28, not
24-29; line 29 is `deadzone`) (N4); the `4-3a/R16` attribution corrected to `TargetingService.
HERO_INDEX`'s convention, and the `TargetingService` Non-Goal narrowed to the evaluator/algorithm so
citing `HERO_INDEX` is not a tension (N5); `camera_rig.gd`'s stale D3(a)-route header comment flagged
for correction in the same dev pass, per `4-3a/R15` precedent (N6). File hygiene (N7) and the board
state (unchanged) needed no action. `Status: authored` (N8, cosmetic, no fixed vocabulary broken) is
left as-is. N9 (`_roll_world_direction`'s neutral-stick fallback meaning a new player-facing
behavior) is DESIGN-LEVEL, not a fix this pass can make: its Open Question is reworded to say
explicitly that it is the operator's call, still open, not defaulted by the dev pass. N10 (no silent
scope beyond `CC/R1`..`CC/R6`) needed no action.

### Close-out

Docs only, one commit: this entry plus the story file's ACs, Non-Goals, Dev Notes, and Open
Questions. No code touched, no `src/`/`test/`/`project.godot` edit, no golden/suite measurement this
pass. `4-6-camera-lock-on` stays `authored`, board stays `backlog` -- promotion and any further gate
pass are the operator's act. Operator reviews the log.

---

## Session 2026-08-30 -- 4-6 dev pass, operator ruling `4-6/R7`

The dev pass on `docs/implementation-artifacts/4-6-camera-lock-on.md` (`gds-dev-story`). One
operator ruling, given in chat before the pass began and recorded here as its first durable record;
everything else the pass decided is a dev-pass call and lives in the story's Dev Agent Record, not
here.

`4-6/R7` (ruled, chat, 2026-08-30) THE NEUTRAL-STICK ROLL BACKSTEPS AWAY FROM THE LOCKED TARGET.
Story 4-6 Open Question 4 -- reserved for the operator by `4-6`'s own gate note N9, because rolling
toward or away from the lock is a change to what the game IS and not an implementation detail.

WHEN THE LEFT STICK IS NEUTRAL AT ROLL ENTRY, the roll goes AWAY from the locked target -- the
INVERSE of the facing fallback, not toward it. This is the DS/ER locked-on neutral-dodge convention
(the backstep direction). It is delivered as the ORDINARY roll: same animation, same i-frames, same
distance and duration. No new move, no new mechanic, no second branch -- only the fallback
direction in `_roll_world_direction` (`match_state.gd:1063-1065`) inverts.

DIRECTED STICK INPUT IS UNCHANGED. A roll entered with the stick pushed follows the stick exactly
as it always has; the ruling touches the fallback and nothing else.

RATIONALE. Once facing became target-derived (`4-6` AC 2), the old fallback stopped meaning "the way
I was last heading" and started meaning "straight at the thing I am locked to" -- which is the one
direction a dodge must not default to. EXPLICITLY REVERSIBLE: one operator, revisited at playtest
if it feels wrong.

GOLDEN DISCIPLINE, discharged. The ruling required the inversion to be measured either way: a third
separately measured cause if any golden-fixture tick rolls with a neutral stick, a recorded
non-move if none does. ONE DOES -- `test_determinism.gd`'s t17 roll-cancel, whose move pair is
`MOVES[16 % 6] = (0, 0)`. So it is a real third cause, measured in isolation at the dev pass:
`9a71e68a` -> `aa3566d7`, with `roll_direction` moving `(-1, 0, 0)` -> `(-0.6, 0, -0.8)` on the
hashed record. The full four-cause ladder is in the story's Dev Agent Record.

### Close-out

Two commits, code and docs never sharing one: the implementation plus its tests, then this entry
with the story file's Dev Agent Record, File List, Change Log and `Status: review`. The story-file
`review` value is story-file-only (`CFG/R3` precedent, `CFG/R5`); the board stays `ready-for-dev`
-- promotion to `done` is the operator's chain commit after the live smoke (`CC/R4`: controller is
primary, and this pass has no pad). Nothing pushed. Operator reviews the log.

## Session 2026-08-31 -- 4-6a readiness gate, operator ruling `4-6a/R1`

The readiness gate on `docs/implementation-artifacts/4-6a-camera-feel.md` found no AC for a flick
whose cycling anchor -- the CURRENT target's screen position -- does not exist (gate finding B1).
Ruled in chat before the fix pass, recorded here as its first durable record.

`4-6a/R1` (ruled, chat, 2026-08-31) A NULL CYCLING ANCHOR MAKES THE FLICK A NO-OP. When the CURRENT
target has no screen position (`_screen_position`, `match_runner.gd:1904-1913`, returns `null` when
the target is behind the camera or outside the viewport rect), a horizontal flick is a no-op,
delivered the AC 2 way -- the standing lock is left unchanged, no retarget request sent. The flick
chooses among what the player SEES; with the anchor invisible the choice is meaningless. The
right-stick CLICK remains the only route back to an off-frame opposing hero -- exactly why `CC/R3`
gave it that job. This mirrors the already-coded guard for the hero anchor
(`match_runner.gd:1849-1851`, "this slot cannot see its own hero; there is no screen frame to flick
within"); the new current-target anchor gets the same treatment.

SUPERSESSION, recorded alongside (gate finding B9). `CC/R3`'s flick clause -- "switches lock to the
best on-screen candidate in that screen-space direction" -- is SUPERSEDED by `4-6a` AC 1's
adjacent-by-screen-X cycling. The CLICK clause is unaffected and stands. Forward-append only;
`CC/R3` itself is not edited.

### Close-out

One commit, docs only: the story file's B1-B10 fixes and this entry. No code, no board change, no
push. Operator reviews the log.

## Session 2026-09-01 -- 4-6a close-out, operator ruling `4-6a/R2`

Two post-review micro-fixes landed after code review APPROVE, driven by the live smoke on
2026-08-31 (pad on P2, flip [0,3]): the lock marker read too low on the minion (crotch height) and
needed to hide during the round-over freeze. Ruled in chat, recorded here as their first durable
record.

`4-6a/R2` (ruled, chat, 2026-09-01) THE LOCK MARKER SITS ON THE TARGET'S BODY AT ~3/4 OF ITS
MEASURED MODEL HEIGHT (souls chest standard), MEASURED FROM THE GROUND. For a unit (minion) actor
this is derived from the actual skinned-model AABB (`skeletonzombie.fbx`, real height ~2.062 m),
not the authored collision box -- `LOCK_MARK_UNIT_LIFT = 1.53`. Hero and totem markers are
unchanged: both already read correctly at the smoke on their existing (authored-box-derived)
lifts, and re-deriving a value that already reads right would be a regression, not a fix. The
marker is additionally HIDDEN during the round-over freeze, rather than left drawing on the dead
hero's body under the win/lose label.

### Close-out

One commit, docs only: this entry plus the story file's post-review micro-fixes subsection, AC 7's
ratified wording, and the board note. No code, no board status change beyond the operator's own
prior promotion (`59e6c0f`). Nothing pushed. Operator reviews the log.

## Session 2026-09-01 -- 4-5 dev pass, operator ruling `4-5/R1`

The ruling that fixed this story's pass/fail line, recorded here as its first durable record in the
decision log (it was stated by the operator on 2026-09-01 and carried in the story file and the
board's `story_notes` until now). It SUPERSEDES `4-3/R18`'s 16-unit figure BY CONTENT -- `4-3/R18`
read "required if the measured frame rate drops below 60 fps at 16 concurrent units on the
reference machine"; the population it names is raised to 20 and the counting rule is made explicit.

`4-5/R1` (operator, 2026-09-01) TWENTY CONCURRENT UNITS -- minions AND totems, BOTH PLAYERS
COMBINED. Projectiles are neither counted toward the 20 nor capped. There is no hard unit cap and
none is added: the economy (mana/stamina costs gating summons) is the only limit.

THE TWO MEASUREMENT FORMS ARE NOT PART OF THIS RULING and are not attributed to the operator. PASS
requires sustained frame time <= 16.67 ms (one 60 Hz frame) as BOTH average and p95 across a full
round, AND no single frame at a spawn or death event above ~33 ms; either failing is a FAIL. Those
two forms were PROPOSED by story `4-5-pooling-60fps-exit` at authoring (2026-09-01) and are
RATIFIED by the operator's promotion of that story to ready-for-dev -- story-proposed and ratified,
not ruled, and recorded that way so a later reader does not cite them as an operator ruling.

### The measurement this ruling was written for, and its outcome

Measured 2026-09-01 by `test/perf/perf_20_units_live.gd` over 3600 ticks (60 s at 60 Hz), 14483
rendered frames, both split-screen viewports live, vsync disabled at runtime, at a forced 1920x1080
on an i5-12500H / RTX 3050 Laptop (Godot 4.6.3, Forward+, D3D12). Population held at ~20 living
units (average 19.86) with combat totems firing, 64 spawn and 43 death events in the measured
stream.

**VERDICT: PASS, on both halves.** Sustained 4.14 ms average and 7.52 ms p95 against the 16.67 ms
budget; worst single frame at a spawn or death event 10.39 ms against the ~33 ms ceiling; no frame
in the whole round above 25.42 ms and only 4 of 14483 above 16.67 ms. Restricted to the
tick-carrying frames -- the only kind that exists at a vsync-locked 60 Hz -- the average is 7.15 ms
and the marginal cost of one full tick is 4.00 ms.

CONSEQUENCE, and it is the whole point of `E4-P/R8`: the E4 pooling obligation is DISCHARGED BY
MEASUREMENT WITHOUT POOLING CODE. `src/systems/pool/` stays empty, units remain plain
`instantiate()` / `queue_free()` nodes, and `unit_actor.gd`'s header now carries the numbers rather
than the open question. The GDD's E4-row "pooling" item is closed on this evidence. The result
belongs to this content at this population on this machine -- re-measure before treating it as
permanent.

Two observations were recorded and deliberately NOT fixed. Board growth (M4, the append-only
projectile/unit board, `4-3a/R9`): the unit board grew 21 -> 64 records across the round with a
frame-time trend of +0.3% (4.154 ms early quarter, 4.166 ms late), i.e. no measurable per-tick cost
at this scale; whether that becomes a line here at E4 close-out or its own Tier A story is the
operator's call from that number. The bunched-minion flicker: the evidence names OVERLAPPING-MESH
rendering rather than physics push jitter -- three live units were observed 0.1-0.2 m apart against
a 0.9 m spawn clearance radius with their velocities pinned at exactly 0.0 by `move_and_slide()`,
which is a static deep interpenetration, not the oscillation push jitter would produce.

### Close-out

Three commits, none pushed: two code (`feat(4-5)` the measurement harness and the AC 12 flags-off
check; `perf(4-5)` the comment-only header correction) and one docs (this entry, the story's Dev
Agent Record, and the board note). Code and docs never share a commit. Tier B held -- golden
`aa3566d7...` and the 28-key snapshot set both measured UNMOVED before and after, suite 566/4377/0
and 46 integration files, all PASS, unchanged either side. The story file's Status is `review`
(story-file-only, `CFG/R5`); the board stays `ready-for-dev` (`CFG/R2`), promotion is the
operator's chain commit. Operator reviews the log.

## 2026-09-01 -- 4-5 code review: measurement corrections (forward append, `4-5/R2`)

FORWARD APPEND, NOT AN EDIT. The `4-5` entry above stands as written; this note records what the
code review found wrong in it. The instrument was audited and the measurement reproduced.

**THE VERDICT IS UNCHANGED AND WAS NEVER IN DOUBT: PASS on both halves of `4-5/R1`.** AC 8's
disposition stands, `src/systems/pool/` stays empty, the E4 pooling obligation stays discharged.
Reproduced independently at the same forced 1920x1080 on the same machine: 5.31 ms average, 10.79
ms p95, worst event frame 19.34 ms, zero frames over 33.3 -- higher numbers than the authoritative
run, same verdict. The corrected instrument also computes the criterion's OWN population directly
rather than bounding it by argument: the tick-carrying subset's p95 is 8.40 ms against 16.67.

Four numbers in the entry above do not survive.

1. `worst single frame at a spawn or death event 10.39 ms` is VOID -- mis-attributed by one tick.
   A `SceneTree` subclass's `_physics_process` is the MainLoop callback, which the engine runs
   BEFORE node propagation, so the harness always polled the board before the runner stepped and
   read the previous tick's result. Events resolved on tick N were flagged onto the frame carrying
   tick N+1 -- the frame after the one that paid for `instantiate()` / `queue_free()`. So 10.39 ms
   is the worst frame ADJACENT to an event, not at one. Re-measured with the fix: 15.46 ms against
   the ~33 ms ceiling, still PASS by better than 2x.
2. `64 spawn and 43 death events in the measured stream` were LIFETIME totals including the build
   phase. In-window: 43 spawns and 42 deaths (21 build spawns + 43 = 64; 1 build death + 42 = 43).
3. The GPU cross-check ("an order of magnitude clear") measured the ROOT viewport, which only
   composites the two player `SubViewport` textures -- both `Camera3D`s are inside those
   SubViewports, so the number excluded essentially all the 3D work. WITHDRAWN. The CPU-bound
   conclusion survives on the wall/tick split, which never used it.
4. `+0.3% (4.154 early / 4.166 late)` is run-dependent: a re-run of the same window measured +6.7%,
   and the quarters are taken over all rendered frames, ~3/4 of which carry no tick, diluting a
   per-tick drift ~4x. AC 10's disposition is unaffected; the claim weakens to "no cost separable
   from run-to-run noise with this instrument".

**`4-5/R2` (review, 2026-09-01): the bunched-minion flicker cause returns to UNNAMED, superseding
the OVERLAPPING-MESH naming in the entry above.** The evidence that named it was read off a
diagnostic that could not tell a live minion from a corpse: it walked the OLDEST actor slots
filtered only on `is_instance_valid`, and a corpse stays a valid actor for 600 ticks with its
collision disabled and its velocity never driven. With a liveness tag added, the three coordinates
the entry cites -- `(1.4,-0.1)`, `(1.5,0.1)`, `(1.6,-0.0)` -- reproduce EXACTLY and print as DEAD.
Corpses overlap at 0.1-0.2 m because collision is off and sit at v0.0 because nothing moves them,
so deadness explains both halves of the argument without any depth-fight. Live bunched units sit
~0.5-0.7 m apart (inside the 0.9 m spawn clearance) at v0.00, which still argues against push
jitter but is not the deep interpenetration the conclusion rested on. A THIRD candidate the
corrected instrument made visible, not among the two the story offered: the 600-tick corpse itself,
collision-off and overlapping live bodies, as a depth-fight source at 20 units. Naming remains out
of scope (AC 11 forbids the fix and asked only for a name); this is a finding for the operator.

Also recorded: AC 2's "FULL ROUND" was discharged by a 60 s / 3600-tick PROXY, since the harness
heals both heroes every tick and no round ever ends. This is legitimate -- AC 1 explicitly
anticipates rounds ending too fast and delegates the mechanism to OQ 1 -- and the proxy is the
stronger measurement, since a real round would end at a moment chosen by the combat rather than by
the criterion. It is recorded as a proxy so "full round" is not read as a round that ran to its end.

Two code commits from the review, neither pushed: `chore(4-5)` tracking four `.uid` sidecars that
`4-6`/`4-6a` committed without them, and `fix(4-5)` correcting the harness (event attribution,
event scope, GPU seat, empty-event sentinel, corpse-blind diagnostic; plus a tick-subset p95, a
round-freeze guard, and the achieved tick count). Tier B still holds -- the review's own full-suite
run measured 566/4377/0, 46 integration, golden `aa3566d7...` and the 28-key set UNMOVED, and
`test/perf/` is outside `run_all.sh`'s glob. Story Status stays `review`; the board is untouched.

## 2026-09-01 -- 4-5 close-out (operator, `4-5/R2` ratified, `4-5/R3`)

**`4-5/R2` RATIFIED by the operator at close-out.** The review-authored correction above (10.39 ms
voided, 15.46 ms re-measured; AC 11's OVERLAPPING-MESH naming withdrawn, cause UNNAMED) stands as
the record.

**`4-5/R3` (operator, 2026-09-01) -- live smoke.** Setup, flags-off, and flicker surfaces (`PROC/R8`)
all closed per the story's Live Smoke Results section. AC 11's cause stays open and is deferred to
the playtest block. E4 exit criteria "60 FPS holds with many units" and "flags toggle cleanly" are
both discharged by this story; E4 close-out is next.

Two retro notes: Tier B log entries drifted into narrative form (`E4-P/R9` calls for rulings only).
The suite count line was lost to `tail` in two consecutive passes.

---

## Session 2026-09-01 -- E4 close-out

E4 is complete: all fifteen boarded epic-4 stories are `done`; suite 566/4377/0, 46 integration, golden
`aa3566d7...` (28-key snapshot set) unmoved. This session flushes the architecture-amendment queue,
records the review residue from four out-of-repo review files, and discharges or re-forces every
forcing point that named the E4 close-out.

**Architecture-amendment queue confirmed at ZERO by content, not taken on trust.** Every
"architect"-adjacent hit in this log after the A6 correction (`E4-P/R3`, Session 2026-08-07) was
checked: all are citations of `game-architecture.md` line numbers inside story rulings, or the same
A6 correction made and landed in-session. No entry after `E4-P/R3` uses the phrase "architecture
amendment queue," and no running count is cited. **The queue itself is empty. The doc is not
current anyway** -- E4 stopped queueing amendments after `E4-P/R3` established the "fix it
in-session" pattern, and 4-1, 4-4 and 4-5 each falsified a clause of D9's pooling claim without ever
re-opening a queue to catch it. Six stale locations corrected as ledger entry A7, `docs(architecture)`
commit `989eeaa`, version 1.5 -> 1.6: Project Context technical drivers (`:118`), the D9
decision-table row (`:193`), the Asset-loading line (`:196`), the D9 section itself (`:449-456`,
rewritten to name what shipped -- `TargetingService`, the `PlayerState` board, `src/actors/minions/`,
`src/actors/projectiles/`, `data/minions/`), the Directory Tree `pool/` entry (`:600`), and the
Entity-creation pattern row (`:950`). `src/systems/pool/` is confirmed empty of everything -- no
`.gitkeep`, not merely no `object_pool.gd`.

`R-M9` (operator, 2026-09-01) ACCELERATORS STACK. Each accelerator totem contributes its own
multiplier where it sits; two identical totems apply two multipliers, multiplicative (illustrative
`x1.05 * x1.05`, not authored numbers). This changes shipped behaviour: today the second identical
accelerator does nothing (4-4 review finding M9, `_44-review.md:444`, recorded in full in
`deferred-work.md`). Design ruling only; implementation touches the golden path, so it is Tier A.
Slot assigned at E5 planning.

`R-SPELL` (operator, 2026-09-01) SPELL RESOLUTION STAYS A NAMED NO-OP THROUGH E5 AND E6. New forcing
point: the E6 close-out, where spell resolution gets its own story -- and the melee-retune +
playtest block already deferred to after E5+E6 (Session 2026-08-30) runs AFTER that story, so the
playtest sees working spells rather than named no-ops. `E4-P/R10` ("spell resolution acquires an
owner at the E4 close-out at the latest") is therefore RE-FORCED, not discharged, to the E6
close-out. The 4-4 readiness gate's citation (`decision-log.md:7096-7100`) covers the projectile
INFRASTRUCTURE `E4-P/R10` also names -- a projectile with its own attacker identity and dedupe,
shared by totems, minions and future hero spell cards -- not card resolution itself, which is what
`R-SPELL` re-forces.

`E4-P/R12`'s proposed `4-4a` epic cut is SPENT. The operator rejected the cut on 2026-08-26 ("4-4
ships in one piece": accelerators + combat totem + projectile together), and 4-4 shipped that way
(`done` 2026-08-30, `35ed365`). This ruling was never recorded in the repo until now; it is recorded
as spent. `E4-P/R12`'s remaining half -- `spell_*` cards on the shared projectile infrastructure --
folds into `R-SPELL` above, since it names the same owner E4-P/R10 already did.

**DEBT E splits into a minion half (discharged) and a hero half (new, assigned).** The minion half
-- `4-3b/R27`'s "rig/model/animation work (DEBT E) ... NO OWNER AND NO SLOT" -- is discharged by
`4-3c-minion-rig-adoption`, `done` at `09ee13a`, assigned early at the 2026-08-14 session ("4-3c
readiness gate, fix pass," `4-3c/R1`) rather than at this close-out as `4-3b/R27` had deferred. Three
strings in the repo still read "the rig story gets an owner and a slot at the E4 close-out" as if
that assignment were still pending: `decision-log.md` (`4-3b/R27`, this file, ~line 6867),
`4-3c-minion-rig-adoption.md:17`, and `sprint-status.yaml`'s `4-3b-minion-attack-rhythm` story note.
None is rewritten -- decision-log entries are pure append, and story files keep their own historical
record -- but all three are hereby marked SUPERSEDED BY CONTENT: the assignment they describe as
future already happened, five days after `4-3b` closed and eleven days before this session.

The hero half is NEW, named at this close-out (operator decision, 2026-09-01): the hero's own
movement-animation gaps observed since `3-0b` -- no strafe/backpedal clips (only forward/idle/attack/
roll/block/death), the movement-direction blend against facing that produces the "floating" read
noted in the 4-6 live smoke, and hitboxes that do not follow bones -- get an owner and a slot as
E5 story `5-0a`, on the `3-0a`/`3-0b`/`4-3c` rig-story precedent. No story file is authored here.

**4-4 M4 (append-only projectile/unit board growth) is closed by measurement, log line only, no
story.** `4-5/R1`'s board-growth observation (21 -> 64 records, a +0.3% early-vs-late frame-time
trend) does not survive `4-5/R2`'s correction: a re-run measured +6.7%, and the quarters dilute
per-tick drift roughly 4x, weakening the claim to "no cost separable from run-to-run noise with this
instrument" (`:7781-7783`). Re-measure trigger: unit population above 20, or matches materially
longer than the 4-5 harness measured.

**The four gaps named without an owner across E4 all get one here**, recorded in full in
`deferred-work.md`: arena has no edge -> candidate for its own story at E5 planning; minions freeze
on an obstacle -> playtest block after E5+E6 (superseding the unslotted "later story on richer minion
behaviour" language); `standard` priority gives a dead arena at 10v10 -> playtest block, a design
lever on authored content; AC 11 flicker cause -> playtest block (`4-5/R3`'s own prior assignment,
unchanged).

**Review residue: 48 findings from four out-of-repo files, recorded in `deferred-work.md`.** 4-4
(`_44-review.md`): 14 open, M1-M9/L1-L5, previously recorded only as a block reference
(`:7432-7434`). 4-5 (`_45-review.md`): 9 open, D1-D9, previously recorded nowhere. 4-6
(`_46-review.md`): 16 open, M1-M5/L4-L14, previously recorded nowhere -- see below, 4-6 has no
close-out session at all. 4-6a (`_46a-review.md`): 9 of 14 still open (five discharged by
`854c0d4`/`3a2ecc4`/`c831ef9`, ratified `4-6a/R2`), previously recorded nowhere. Disposition is the
inventory's tag for each (a/b/c/d), except M9 (`R-M9` above) and M4 (above).

**Two of E4's four largest stories closed with no close-out decision-log session at all.** `4-6`
was promoted `done` and pushed at `eed4839`, with its sixteen open review findings recorded only in
`C:\dev\_46-review.md`, outside the repo, until this pass. `4-4`'s last decision-log entry is its
review fix pass (`:7374`); its live smoke and promotion (`35ed365`) are unrecorded there. Both are
named here with their close-out commit hashes and their review files as a retro input -- not
fabricated as retroactive sessions, per standing discipline.

**Art assignments, recorded not authored.** Hero rig DEBT E (hero half, above) + strafe/backpedal
clips -> `5-0a`. Totem and projectile models/VFX (currently grey-box) -> `5-0c`, a static mesh swap,
not a precondition for anything else. Both are E5 stories authored at the E5 planning pass; this
entry records the assignment only, no story files and no board keys are created here.

### E4 exit criteria discharged

| Criterion | Discharged where |
|---|---|
| Cards summon functioning minions | `4-1`, `4-3`/`4-3a`/`4-3b`; live smoke `docs/playtest-log.md` 10.8, 12.8 |
| Cards summon functioning totems | `4-4`; live smoke 6/6, `docs/playtest-log.md` 30.8 |
| **60 FPS holds with many units** | `4-5/R3` (`:7790-7793`): both E4 exit criteria discharged by this story. Evidence `4-5/R1` (`:7690-7700`), corrected by `4-5/R2` (`:7725-7783`) |
| **Flags toggle cleanly** | `4-5/R3`, same line; AC 12 measured both directions |
| Autonomous minion AI, data-defined priorities | `4-2`; `data/minions/{standard,hero_seeker,hero_preferring}.tres` |
| Throttled targeting | `4-2`, `E4-P/R7` |
| **Pooling** | `4-5/R1` -- DISCHARGED BY MEASUREMENT, no pooling code. This is the clause `game-architecture.md` had not caught up with; A7 (above) corrects it |
| 3 totem subtypes | `4-4`; live smoke point 6, `docs/playtest-log.md` 30.8 |
| Camera / lock-on (adopted into E4) | `4-6` plus `4-6a`, both `done` |

The E4 retrospective follows via `gds-retrospective`, now that this close-out has discharged
`E4-P/R11`'s standing prohibition on one before E4 closes. `docs/implementation-artifacts/
epic-3-retro-2026-08-06.md` is available to it as `previous_retrospective`.

### Close-out

Four commits, docs only, none pushed: `docs(architecture)` (`989eeaa`, A7), `docs(deferred-work)`
(`15fa409`, review residue + named gaps + playtest checklist), this entry plus one Change Log line
each in `4-4-totems.md` and `4-3c-minion-rig-adoption.md` pointing at this session
(`docs(decision-log)`), and `board:` (epic-4 `backlog` -> `done`, stale story notes corrected). No
code changed, no golden or suite touched, no test run. Operator reviews the log and pushes.

---

## Session 2026-09-01 -- E4 retrospective

The second retrospective held in this project, and the first to follow a close-out that discharged
its own prohibition (`E4-P/R11`). The retrospective itself is
`docs/implementation-artifacts/epic-4-retro-2026-09-01.md` (commit `docs(retro): epic 4
retrospective`); this entry records only what it RULED, per the standing separation between an
analysis artifact and the decisions it produces. `sprint-status.yaml` is deliberately NOT touched --
it carries no `epic-N-retrospective` key and its header locks the lifecycle to
`backlog -> ready-for-dev -> done`, so `gds-retrospective` step 11 is skipped on the E3 precedent.
Report delivered REPORT-ONLY; the operator ratified every proposal with two inputs, both folded into
the rulings below: the Tier B budget stays ~1 h for `4-B1`-sized work (NOT raised to the ~3 h two
stories helped themselves to), and the gate-round cap is adopted.

**THE STANDING META-RULE, recorded because it is the yardstick every process rule in this project is
now judged against (operator, 2026-09-01): a rule whose enforcement costs the operator more time --
in trivia, in formality -- than the failure it prevents is REJECTED.** It killed two candidates this
session (a per-story "is this architecture line still true" check, and a `story_note` length cap) and
it is why the two rules that survived cost one grep each. Cite it when proposing process.

`E4-R/R1` (decided by Matko) THE THREE E3 OPEN DECISIONS GET OWNERS, AND RE-FENCING WITHOUT ONE
STOPS. **Open decision (a), attacker consequence on basic-attack deflect: forcing point is the E5
PLANNING PASS.** `E4-P/R11` re-fenced it out of E4 (`:5779`) and nothing in the E4 range touched it
-- `STUNNED` still has zero inbound edges, `stun_seconds` is still data-only and still exempted in
`test_balance_authoring.gd`. **Open decisions (b), the reshuffle vulnerable window's mechanical cost,
and (e), whether hand size ever varies: BOTH go to the playtest-block checklist in
`deferred-work.md` as QUESTIONS TO ANSWER WITH A PAD IN HAND, owner the operator at playtest.** They
are not defects and are not implementation work; both are feel calls that cannot be judged headless,
the same reason `E3-R/R3` gave for the melee retune. (e) additionally got MORE expensive to change
during E4 -- `4-0/R1` bound the `hand_size` snapshot key to occupancy and its N2 finding records
`3-6/R8`'s `<= 4` audit bound becoming more load-bearing (`:5478-5479`) -- so the question is now
also a cost question. **RULE: no open decision is re-fenced again without an owner or a venue that
actually convenes.** Evidence for the rule rather than the disposition: (b) has now skipped two
epics exactly as decision (c) did, and (c) is the case `E3-R/R1` closed by pointing at code that had
already answered it. Decision (f) is the counter-example and shows what a good fence looks like --
`E4-P/R11` named a MECHANISM for adoption ("that is a `gds-correct-course`, not silent adoption",
`:5782-5784`) and the mechanism fired on 2026-08-30.

`E4-R/R2` (decided by Matko) `PROC/R2` AMENDED, `PROC/R6` RETIRED. **The layer-completion line
becomes a MANDATORY GREPPABLE LINE in the story's review section, on the fixed prefix
`LAYER-COMPLETION:`, naming each declared layer with its terminal state. A review report that does
not carry it is REJECTED in the browser and re-run.** This REPLACES `PROC/R2`'s "a review missing
that line COUNTS AS A STALL" definition, which eleven of fifteen E4 reviews falsified without a
single one being treated as a stall: the line is present in `4-0`, `4-B1`, `4-1` and `4-2` only, and
absent from `4-3`, `4-3a`, `4-3b`, `4-3c`, `4-3c1`, `4-3d`, `4-3e`, `4-4`, `4-5`, `4-6` and `4-6a`.
`4-3:321` uses the word "layers" for PASSES ("dev pass, code review, this fix pass"), and
`4-3e:426` records THREE layers including the Acceptance Auditor -- the layer `PROC/R2` deleted.
A definition that classifies eleven stories as stalls while nothing acts on it is not a rule; a fixed
prefix an operator can grep before accepting the report is. **`PROC/R6`'s stall counter is RETIRED,
not reset.** Two reasons, both by content: it counted hangs of parallel layers `PROC/R2` had already
removed from the chain, so the mechanism it measured no longer exists (the same
guard-mechanism-over-guard-pattern move `PROC/R6` itself made, `3-0d/R20`); and it lived in chat
rather than in the repo, so it simply stopped -- no `PROC/R6` mention exists anywhere after `:6510`,
nine stories back. **Tier B suspension is judged at retrospectives, on `PROC/R7` measurements**,
not by a running counter nobody maintains.

`E4-R/R3` (decided by Matko) `PROC/R7` GETS AN INSTRUMENT AND LOSES SELF-STATED BUDGETS. **The
instrument is the TIMESTAMPS OF THE SUITE-OUTPUT FILES** -- the before-baseline run and the final
run, both written outside the repo since 2026-09-01 -- **recorded in the story's close-out log entry
as start / end / delta.** No stopwatch, no estimate: two files that already exist, subtracted. This
discharges `PROC/R7`'s never-honoured clause "sessions note their start time and compare against the
budget at full-suite boundaries" (`:5929-5932`), which produced exactly ONE number in all of E4
(`4-B1`'s ~113 min at `:5933`) and that one predates the rule. **The budget is set by the OPERATOR at
the scope conversation. A story NEVER states its own budget.** `4-6a`'s and `4-5`'s self-stated ~3 h
(`4-6a:165-172`, `4-5:185-192`) are VOID -- a story setting its own budget at three times the
baseline and then recording no actual is an unfalsifiable budget. Default remains ~1 h for
`4-B1`-sized work (two ACs, one presentation surface, no `src/state/`), confirmed by the operator
2026-09-01 and deliberately not raised. **Operator-given figures for `4-5`, recorded now and marked
as operator-given because they appear in no repo file: ~34 min dev; the review went OVER the ~1 h
budget and was reported honestly.** The honest report is the tripwire behaving correctly and is
recorded as the first evidence that it works.

`E4-R/R4` (decided by Matko) GATE-ROUND CAP. **After a story's SECOND readiness gate returning NOT
READY, the third round is a SCOPE CONVERSATION in the browser -- operator and Claude -- not another
gate-and-fix round.** Evidence, all measured: the `4-3` family shipped SEVEN stories from one planned
slot (`E4-P/R1` planned one), 481.4 KB of artifact, 57% of the epic's total; `4-3d` took six gate
rounds (sessions `:7017`, `:7160`, `:7222`, `:7260` plus its first, 191 log lines, every one
docs-only) and `4-3e` five, and at least four of those rounds existed ONLY to delete specification an
earlier round had added. `4-3e`'s fifth gate says it outright: "THIS PASS REMOVED SPECIFICATION
RATHER THAN ADDING IT ... three of the fifth gate's four blocking findings existed only because AC 4
had been inflated into a full specification of cluster mechanics for N>1 -- mechanics the story
itself measures as UNREACHABLE THROUGH PLAY" (`4-3e:955`). `4-3d` ran the same shape on one
requirement: `R14` authored a REOPEN CONDITION, `R19` found its arithmetic inverted, `R20` found the
replacement's upper bound "invented, not derived; REMOVED". A third gate round is evidence the
STORY's scope is wrong, not that its text is; the cheapest correction is a person, not another pass.
**COROLLARY, and it is the actual defect the cap treats: the create pass writes BEHAVIOUR and
ACCEPTANCE, not MECHANISM -- except where a ruling already put the mechanism in.** Specification
inflation is `3-0d/R20`'s guard-pattern widening one layer up, in the story spec instead of the code.

`E4-R/R5` (decided by Matko) THE REPORT-ONLY-THEN-RATIFY SHAPE IS THE STANDING SHAPE for planning
passes and close-out passes: report-only inventory -> browser rulings -> docs pass. Two for two in
E4. **E4 planning:** its pre-write re-verification caught the D9 sentence describing `PlayerState` as
already reserving a `units` collection when `player_state.gd` carried zero such tokens
(`:5658-5674`), corrected in-session as A6; ratification then produced two operator AMENDMENTS to
`E4-P/R9` that a single-pass author would not have written. **E4 close-out:** its inventory INVERTED
the commissioning premise -- there was no amendment queue to flush, the real work being six stale
pooling claims nobody had queued -- and surfaced 48 review findings recorded nowhere in the repo plus
`epic-4: backlog` while all fifteen children were `done`. **Against single-pass:** the E3 close-out
flushed its queue correctly and dropped two riders on the same forcing point (`stories-manual-e3.md`'s
hygiene items and the twice-parked Change Log author-column question), both of which the E3
retrospective had to discharge a day later. Residual cost accepted and named: the report artifact
lives outside the repo, where no future reader can reach it.

`E4-R/R6` (decided by Matko) SUBAGENTS: THE 2026-09-01 READ-ONLY RULE STANDS, AND NOTHING IS ADDED TO
IT. It is cheap and it forecloses a class this project has not yet suffered -- a subagent committing,
pushing, or editing a story file mid-review. Recorded honestly: **it covers none of the six incidents
E4 actually had.** Layer stalls (`4-0` `:5625-5628`, `4-B1` `:5856`, `4-1` `:6076-6079`) are
indifferent to write permission; a review layer reading `git diff HEAD` and never seeing new files
(`4-3b/R28`, `:6869`) gets WORSE under read-only, since the layer cannot stage anything to bring
untracked files into view; a session losing its transcript to compaction and reporting a HEAD
mismatch (`:6512-6514`, the sixth incident, filed as retro carry-forward rather than as a subagent
event) is a main-session failure mode entirely. What catches the remaining class -- an agent
reporting a false claim about its own work, from the unevidenced full-suite re-run (`:5875`) to
`4-5`'s four withdrawn numbers (`:7737-7755`) -- is `PROC/R2`'s Dev Agent Record evidence audit,
which is exactly why `E4-R/R2` makes its layer-completion line an acceptance criterion instead of a
convention. No further subagent rule.

`E4-R/R7` (decided by Matko) `4-3e` HAS NO DECISION-LOG SESSION, AND THE RULE THAT EXPOSES. Measured:
the string `4-3e` appears ONCE in this log, at `:7487`, as an incidental citation about board
ordering -- while the story is the largest artifact in the epic (100.7 KB), took five readiness-gate
fix passes, and carries owner rulings that exist only as story-file prose with no ids. **NO
RETROACTIVE SESSION IS FABRICATED**, per standing discipline. Instead a dated INDEX below assigns ids
`4-3e/R1`..`4-3e/R15` to the rulings found BY CONTENT in
`docs/implementation-artifacts/4-3e-summon-spawn-placement.md`, each with its story-file line and its
original date. **The index makes ZERO new decisions**; every entry is a pointer to text that was
written and ratified on 2026-08-27. **RULE: board promotion of a story to `done` requires a
decision-log close-out session naming that story, and the promotion prompt GREPS for it before
flipping the status.** Would have caught three E4 stories: `4-3e` (no session at all), `4-6`
(promoted `done` and pushed at `eed4839` with sixteen open review findings living only in an
out-of-repo review file), and `4-4` (last entry its review fix pass `:7374`; live smoke and promotion
`35ed365` unrecorded). It also closes the review-residue leak by construction -- a story can no
longer close without a session in which to record its findings.

`E4-R/R8` (recorded, not ruled) WHAT E5 INHERITS, AS FACTS ABOUT THE PLAN AND NOT AS A RULING ON IT
-- the `E3-R/R5` template. Recorded at all because parts of it exist nowhere in the repo.
1. **E5 opens with THREE Tier B presentation stories, authored at the E5 planning pass** (operator
   decision, 2026-09-01). **`5-0a` hero locomotion**: strafe/backpedal clips, the movement-direction
   blend against facing that produces the "floating" read noted at the `4-6` live smoke, and the hero
   half of DEBT E (hitboxes that do not follow bones) -- already named at the E4 close-out
   (`:7856-7860`). **`5-0b` pad card input**, on the L3 scheme from `3-5a` Dev Notes: L3 HELD = cast
   mode; L1 / L2 / R1 / R2 = the four cards; A / B / X / Y = modes and confirm; RELEASING L3 exits.
   Basic mode ships immediately; modes 2 and 3 get their button with their own E5 story, mode 4 with
   E6. **MINUS R3, which `4-6` consumed for lock-on retarget and KEEPS** -- `3-5a:110` reasoned
   explicitly that "the right stick click and the face buttons need the same thumb," and E5 planning
   reconciles that sentence with what `4-6` shipped. `5-0b` exists nowhere in the repo before this
   entry. **`5-0c` totem and projectile models**, a static mesh swap, a precondition for nothing
   (`:7891-7893`). **`5-0a` and `5-0b` must be done before the playtest block.**
2. `R-SPELL` (E4 close-out, `:7829-7843`): spell resolution stays a named no-op through E5 and E6,
   forcing point the E6 close-out, with the playtest block AFTER it. Consequence for E5 planning: no
   E5 story may assume spell cards resolve -- three of nine fixture cards carry `spell_*` ids.
3. `R-M9` (E4 close-out, `:7822-7827`): accelerators STACK, multiplicatively, per totem. Changes
   shipped behaviour, touches the golden path, Tier A, SLOT ASSIGNED AT E5 PLANNING -- still unslotted.
4. **Arena edge: candidate for its own story at E5 planning.** `4-3e` consciously left it open in two
   steps -- its second gate took the bound out of AC 2 entirely and named the gap as a NON-GOAL with
   no owner (`4-3e/R6` below), and its third gate deleted the last requirement-shaped reference to a
   bound anywhere in the story (finding B3, Live Smoke point 4). "Candidate" is still the strongest
   language in the repo.
5. The playtest-block checklist in `deferred-work.md`, now carrying open decisions (b) and (e) as
   questions per `E4-R/R1`; and the thirteen (c)-tagged findings awaiting E5-planning judgment, of
   which `4-6` M3 (a malformed retarget address is logged and then ACTED ON, landing in a hashed key)
   and `4-6` L7/L8 (v6 record robustness, where `4-1/R1`'s hard-rejection doctrine is the home) are
   the determinism-adjacent ones and should be read first.
6. Open decision (a) is the E5 planning pass's, per `E4-R/R1`. S5's audio half remains unhomed; S6
   has forcing point E5.
No ruling is taken on E5's plan here. A retrospective records what the next planning pass must not
discover late; it does not do that pass's job.

### `4-3e` ruling index (`E4-R/R7`) -- pointers only, zero new decisions

Every entry below was written and ratified on **2026-08-27**, in
`docs/implementation-artifacts/4-3e-summon-spawn-placement.md`. Line numbers are that file's, at
`41f4665`. Gate attribution is the story's own wording. Nothing here is decided by this session.

| id | Story line | Gate | Ruling, by content |
|---|---|---|---|
| `4-3e/R1` | `:20-23` | first | Placement is HERO-RELATIVE: a summoned unit appears behind the summoning hero, on the side away from the opponent, at the hero's position AT CAST TIME -- not at a fixed scene coordinate authored in `main.tscn`. |
| `4-3e/R2` | `:45-48` | first | No fixed candidate budget and no "use the last one anyway" early exit; the outward walk continues and the FIRST FREE CANDIDATE WINS. The bounded-set shape was upstream error, not an owner ruling, and is dropped. |
| `4-3e/R3` | `:83-84` | first | NO MINIMUM DISTANCE FROM THE OPPONENT. A player may run up to the opponent and summon there deliberately; the story adds no proximity restriction of any kind. |
| `4-3e/R4` | `:100-102` | first | Batch members land NEAR ONE ANOTHER, reading as one group rather than a scatter distributed around the hero. |
| `4-3e/R5` | `:129-131` | first | A fresh unit keeps whatever heading it spawns with; no change to `_aim_unit_actors` or any facing computation. |
| `4-3e/R6` | Change Log `:958` | second | THE ARENA BOUND IS OUT OF AC 2 ENTIRELY -- it was the wrong termination device and was upstream error. AC 2 rewritten as an unbounded outward walk terminating on the finiteness of live units. NEW NAMED NON-GOAL: keeping anything inside the arena, hero included, recorded as a PRE-EXISTING GAP WITH NO OWNER. This is the origin of the arena-edge gap now carried in `deferred-work.md`. |
| `4-3e/R7` | Change Log `:958` | second | Extracting the placement helper is MANDATORY, not the dev agent's choice: a private, directly-callable `MatchRunner` helper that returns positions, reads no scene tree and holds no node reference. |
| `4-3e/R8` | `:50-51` | third | Termination is by FINITENESS PLUS AN UNBOUNDED RADIUS, and the second half is a REQUIREMENT ON THE SEARCH, not a consequence of the first -- a sequence that densifies inside a bounded region is FORBIDDEN. An acceptance criterion, not latitude. |
| `4-3e/R9` | `:86` | third | BOTH HEROES COUNT AS OCCUPANTS for the search, alongside the live unit actors of both slots -- because AC 3 blesses summoning while standing on the opponent, which is exactly when "behind me" lands inside a body. |
| `4-3e/R10` | `:173-174` | third | "GROUND-DERIVED" means the ground-level CONSTANT the runner already uses -- the literal `0.0` at `match_runner.gd:656` -- NOT a raycast and NOT any physics query, which would put a physics read inside a helper required to be pure. |
| `4-3e/R11` | `:25-26` | fourth | "BEHIND" WINS OVER PROXIMITY, and the property holds of the ACCEPTED CANDIDATE, not merely of the base spot: a ring is a rear ARC, and a crowded rear pushes the unit FURTHER BEHIND, never in front. |
| `4-3e/R12` | `:56-57` | fourth | THE RADIUS RULE IS PER RING, NOT PER CANDIDATE -- the third gate's per-candidate wording forbade the very ring the story elsewhere mandates. |
| `4-3e/R13` | `:104` | fourth | EVERY CLUSTER MEMBER IS CLEARED, NOT JUST THE FIRST: members are placed one at a time, each clearing every occupant in the caller's list AND every member of the same batch already placed in that call. |
| `4-3e/R14` | `:35-37` | fifth | THE DEGENERATE DIRECTION HAS A DEFINED ANSWER, AND IT IS A REQUIREMENT, NOT LATITUDE: when the hero-to-opponent direction is too short to be reliable, the rear arc's axis is the SLOT'S FIXED AWAY-FROM-CENTRE AXIS (P1 toward -x, P2 toward +x), for the arc and not merely for the base spot. |
| `4-3e/R15` | `:120-123`, Change Log `:955` | fifth | DO NOT SPECIFY, GUARD OR GATE BEHAVIOUR NOTHING CAN EXECUTE. AC 4 collapses to its two surviving claims; the named minimum/maximum in-batch separation bounds and the MANDATORY SYNTHETIC N=3 TEST are DELETED, and correctness for N>1 is carried by REVIEW with the story saying so rather than pretending otherwise. |

### Close-out

Docs-only pass, four commits, none pushed: `docs(retro)` (the retrospective artifact only,
`0b1ef07`), this entry (`docs(decision-log)`, a PURE APPEND -- no existing entry edited),
`docs(config)` (the operative half of `E4-R/R2`/`R3`/`R4`/`R7` appended to `project-context.md`'s
Testing Rules per `PROC/R5`, `rule_count` bumped), and `docs(deferred-work)` (open decisions (b) and
(e) added to the playtest-block checklist per `E4-R/R1`; the (d) tag legend corrected to read "open,
no owner"). `sprint-status.yaml` is NOT touched -- no retrospective key exists and `last_updated` is
already current. `CLAUDE.md` is NOT touched -- its Story tiers section is a pointer to `E4-P/R9` and
no tier policy changed here. No story Change Logs touched. No code changed, no golden or suite
touched, nothing ran. `E4-R/R1`, `R5`, `R6` and `R8` are log-only by design. The operator reviews the
log and pushes.

## Session 2026-09-01 -- E5 planning

The E5 planning report (`_e5-planning.md`, out-of-repo, REPORT ONLY per its own header) was
delivered against `9fe3d34` and ratified by the operator with the rulings below; where a ruling
goes beyond the report's recommendation, this entry is authoritative. Machine state at report time:
`git log --oneline -1` = `9fe3d34`, `HEAD == origin/main`, tree clean, `sprint-status.yaml:78`
`epic-4: done`, golden `aa3566d7077c07cc90630d155924b620cf5c54e14e6d0f3809d154d31ded7e4f`
(`test/state/test_determinism.gd:678`). Two corrections against the inputs, both by content: the
`(c)`-tagged residuum count is FOURTEEN, not thirteen as `E4-R/R8` item 5 said (the `(b)` count of
nine is right); and `epics.md`'s E5 section was stale against `E4-R/R8` before this pass's `docs(epics)`
commit. This session records only what was RULED; the report's own reasoning stays there and is not
restated here.

`E5-P/R1` (decided by Matko) OPEN DECISION (a), ATTACKER CONSEQUENCE ON BASIC-ATTACK DEFLECT: RESOLVED.
A deflected basic attack now carries BOTH consequences for the attacker -- a stamina penalty (new
authored balance field) AND a short stun. The colour-read counter keeps the full ~1 s stun; the
deflect stun MUST be authored markedly shorter than it, so the three-tier ladder keeps an escalation
gradient (colour read remains the strongest stopping answer) even though the colour counter is no
longer the ladder's *only* stopping answer. This is Shape 2 (`_e5-planning.md` Section 2) plus the
Shape 1 economic penalty folded in, not Shape 2 alone as recommended -- the operator's own
combination. Values are authored at `5-1`/`5-6`, not here. Consequences: `gdd.md:243` wording
amended this pass (`docs(gdd)` commit); the `test_balance_authoring.gd` stun exemption is removed at
`5-6`, which is also where `STUNNED` gets its first inbound edge. `R-D5` (`decision-log.md:373`, no
attacker consequence) is superseded.

`E5-P/R2` (decided by Matko) ARENA EDGE SLOTTED as `5-0d-arena-edge` (Tier B): a ring of static
collision in the scene (`main.tscn`), a hard wall the player slides along -- cornering is
intentional gameplay, not an accident to hide. No state clamp, no `src/state/` edit; golden immobile
by construction, confirmed by measurement at the story's own gate. Closes the gap `4-3e/R6` opened
with no owner (`deferred-work.md:305-309`) and removes it from the playtest checklist per
`deferred-work.md:334`'s own "unless E5 planning has already slotted it" clause.

`E5-P/R3` (decided by Matko) `R-M9` MANA SEAT RESOLVED: Reading A -- each mana accelerator pays its
own grant per cadence tick (two identical totems grant twice per tick); linear, player-countable,
matching "each totem contributes its own effect where it sits." Reading B (compounding cadence) is
rejected as superlinear and not what a player reading the board would expect. The stamina seat stays
literal `mult^N`, as already ruled by `R-M9` itself (`deferred-work.md:209-213`). Unblocks
`5-1-accelerator-stacking`.

`E5-P/R4` (decided by Matko) CHARGEUP REACH (the auto-aim question, `_e5-planning.md` Section 6,
"One design question `5-2` cannot be authored without"): the unblockable is a large committal attack
with a big authored hit radius (provisional ~8 m, new balance field); souls axe and grab register
within it. Being inside the radius when the chargeup lands forces the defender to REACT -- roll
i-frames, or the colour answer once `5-5`/`5-6` exist -- and spacing still matters because the
radius IS the boundary: being or getting outside it during the chargeup is the escape. Lock-on
(`4-6`) aims direction only and never extends reach; a chargeup thrown while locked is not thereby
guaranteed to land regardless of range, closing this session's read of the Reactor/Actor "forbidden
offload" risk the report raised. Unblocks `5-2-unblockable-initiation`.

`E5-P/R5` (decided by Matko) E5 STORY LIST, ORDER, AND TIERS RATIFIED, twelve stories (the report's
eleven plus `5-1a`, added by this ruling):
1. `5-0a-hero-locomotion` -- Tier B, at-risk (hero half of DEBT E: hitboxes that do not follow
   bones is a contact-geometry change; measure early).
2. `5-0b-pad-card-input` -- Tier B (the held-L3 scheme, `3-5a` Dev Notes; the two button
   collisions -- shoulders already attack/block, face buttons vs roll=B -- enter its acceptance
   criteria explicitly).
3. `5-0c-totem-projectile-models` -- Tier B (static mesh swap, precondition for nothing).
4. `5-0d-arena-edge` -- Tier B (`E5-P/R2`).
5. `5-1-accelerator-stacking` -- Tier A (both seats per `E5-P/R3`; carries `4-4` M2 and M7 as
   authoring-audit bounds; changes shipped behaviour and moves the golden, so it runs first of the
   Tier A stories, before any unblockable work, per the `4-6` re-baseline discipline of isolating
   one measured cause at a time).
6. `5-1a-intent-hardening` -- Tier A, small (`4-6` M3's hard-rejection of malformed retarget
   addresses per the `4-1/R1` doctrine, bundled with `4-6` L7/L8's v6-record robustness; own
   before/after golden measurement, not shared with `5-1`).
7. `5-2-unblockable-initiation` -- Tier A (`CHARGING`'s first inbound edge; the chargeup timer on
   the D4 primitive; per-colour damage; carries the S6 mid-roll/mid-block cast gate; reach per
   `E5-P/R4`).
8. `5-3-telegraph-presentation` -- Tier B (consumes the state-owned telegraph fact `5-2` produces;
   carries S5's unhomed audio half and the S8 attack/block-sting discrimination finding).
9. `5-4-orbs` -- Tier A (`OrbPool` enters `to_snapshot()`; carries the `4-5` D1 flag-matrix split;
   NO spend path -- Mode 4 is E6).
10. `5-5-unblockable-defense` -- Tier A (colour match negates damage and orb grant; no stun here).
11. `5-6-three-tier-ladder` -- Tier A (the dodge/leave-range rung, both stuns, and `E5-P/R1`'s
    stamina penalty; removes the `test_balance_authoring.gd` audit exemption).
12. `5-7-pad-modes-2-3` -- Tier B (waits for `5-5`; a mode button for an unresolvable mode is a
    no-op the operator cannot smoke).

Every Tier B above is a PREDICTION its own gate confirms by measurement, never a lowering, per
`E4-P/R9`. `5-2` is authored WHOLE; if its gate finds it oversized, the named break line is
auto-aim/acquisition (`5-2a` state vs `5-2b` actor-side), per `E4-R/R4`'s corollary that the create
pass writes behaviour, not mechanism. Tier B machine-time budget: operator default ~1 h per story,
per the E4 retrospective's ruling on `4-B1`-sized work (`decision-log.md:7934-7935`), not raised.

`E5-P/R6` (decided by Matko) THE FOURTEEN `(c)`-TAGGED RESIDUUM ITEMS DISPOSED:
- `4-4` M2, M7 -> `5-1-accelerator-stacking`, as authoring-audit bounds in
  `test_balance_authoring.gd` (same file, same pass that re-derives that line for stacking).
- `4-5` D1 -> `5-4-orbs`, forced by that story's own `unblockable`/`orbs` flag-matrix split.
- `4-6` M3, L7, L8 -> `5-1a-intent-hardening`, bundled together (same doctrine, same file, one
  golden measurement).
- `4-5` D9 RE-TAGGED `(c)` -> `(a)`, CLOSED as process: superseded by `E4-R/R2`'s
  `LAYER-COMPLETION:` mechanism, which already replaced the enforcement this finding was about; a
  register audit on log prose is exactly the kind of rule the standing meta-rule
  (`decision-log.md:7936-7940`) rejects.
- `4-4` M5 DEFERRED, no E5 slot. Owner: the next story touching `test_projectile_homing`-class
  coverage, realistically the E6 spell story.
- `4-4` M6 DEFERRED, owner the E6 close-out spell story (the next thing that adds a `unit_kinds`
  entry); keep the determinism-adjacent note (a live record re-pointing mid-match) attached.
- `4-5` D2, D3, D6 DEFERRED as a set, owner whoever next runs the `4-5` perf harness; its
  re-measure trigger is already written (`deferred-work.md:196-198`: unit population above 20, or
  materially longer matches).
- `4-6a` L6, L7 DEFERRED, owner the next story editing `src/actors/camera/`-class code or its
  tests.

`E5-P/R7` (decided by Matko) OUT OF E5, ratifying `_e5-planning.md` Section 7 as final: all of E6
(Pitch Zone, Mode 4, the all-colour reset call, affordability read, overlap lockout --
`pitch_effect` stays UNAUTHORED, `5-4` exposes `reset_all()` and never calls it); spell resolution
(`R-SPELL` -- no E5 story may assume a spell card resolves, and `5-5`'s hand-of-four math must
tolerate three unresolvable cards); the melee retune + playtest block, running after the E6
close-out spell story with all nine `(b)`-tagged findings; open decisions (b) and (e), owned at the
playtest block (note (e)'s interaction with `5-5`'s hand math, since colour-as-defense's
hand-of-four reasoning moves if (e) ever answers "yes"); the three remaining named gaps (minions
freeze on an obstacle; `standard` priority gives a dead arena at 10v10; the AC 11 flicker cause --
arena edge is `E5-P/R2`, not out); E7 and E8; peripheral mana/deck legibility, deferred until the
full loop exists at E6; and pooling code, re-measure trigger population > 20.

Docs-only pass, five commits, none pushed: `docs(gdd)` (`gdd.md:243` amended per `E5-P/R1`),
`docs(epics)` (E5 Committed obligations brought current against `E4-R/R8` and this session's
rulings), this entry (`docs(decision-log)`, a PURE APPEND -- no existing entry edited), `board`
(`sprint-status.yaml` epic-5 section, twelve keys per `E5-P/R5`'s order, all `backlog`), and
`docs(deferred-work)` (the fourteen `(c)` items re-tagged per `E5-P/R6`, the arena-edge checklist
line updated to "slotted as `5-0d`"). No code changed, no golden or suite touched, nothing ran. The
operator reviews the log and pushes.

## Session 2026-09-02 -- 5-0a close-out (Tier B)

Dev pass and code review (verdict PASS, one LOW deferred to the retune block) both landed before
this session; live smoke found one defect, fixed, and re-confirmed by the operator in this same
session. Four rulings recorded, close-out only.

`5-0a/R1` (ruled, live smoke, 2026-09-02) THE OPERATOR'S MIXAMO-PREVIEW STRAFE MAPPING WAS
OVERTURNED AT LIVE SMOKE — a mirror-class misread, not a code defect. The Mixamo preview camera
faces the character, so an identification made from that preview reads backwards once driven by
the hero's own facing in-engine: `strafe_left.fbx`/`strafe_right.fbx` played visually swapped on
the first live pass. Fixed by a **source-file content swap** (never a key remap in
`add_paladin_locomotion.gd`, which would have hidden the mismatch instead of correcting the truth
on disk), re-imported, re-measured (both clips remain net-zero, figures swapped), and re-verified
correct in-game. Standing lesson for future rig stories: **clip handedness read off an external
preview tool cannot be trusted — in-engine, driven by the actual facing, is the only judge.**

`5-0a/R2` (recorded, code review, pre-smoke) REVIEW LOW, DEFERRED TO THE RETUNE BLOCK: the
diagonal angle-band tie-break only ever resolves between `run` and `backpedal`, never `strafe_left`
or `strafe_right` — an untuned-by-design boundary (AC 2 Non-Goals), not a defect blocking this
story. Recorded here as retune-block input, alongside the four deferrals `3-0b` already handed
that block.

`5-0a/R3` (ruled, live smoke, 2026-09-02) SMOKE PASS ON ALL SIX WATCH ITEMS, the fix from `R1`
re-verified live: strafe reads correctly both directions, backpedal correct while locked, diagonal
boundary flicker not noticeable, locomotion crossfades cleanly while action-state clips stay
instant, attacks land normally on the bone-following hitbox with chained swings restarting
correctly, and FPS stable. `docs/playtest-log.md`'s 2026-09-02 entry is the operator's own hand-
written record.

`5-0a/R4` (confirmed by measurement) TIER B HOLDS. Golden `aa3566d7...` measured unmoved in both
directions across the whole story, `src/state/` byte-identical, `project.godot` byte-identical
across both editor sessions. Machine time 20m35s of the story's ~1h Tier B budget
(`E5-P/R5`'s note on `decision-log.md:8206-8207`).

### Close-out

Two commits. Commit 1, code + assets: the dev pass's `src/actors/hero/` changes, the four
integration tests, the two new `tools/` scripts, and `assets/characters/paladin/` (the three
clips post-`R1`-swap plus the assembled `paladin_anims.res`). Commit 2, docs only, folded per
`E4-P/R9`/`4-B1` precedent: this entry; the story file's Status -> `done`, Change Log row, and
Live Smoke Results section (all six items PASS after the `R1` fix); `docs/playtest-log.md`'s
operator-written entry (already present, verified before this commit); and the board
(`5-0a-hero-locomotion: ready-for-dev` -> `done`). Nothing pushed; the operator reviews the log.

## Session 2026-09-02 -- 5-0b close-out (Tier B)

Dev pass and code review (six findings, all applied) landed before this session; live smoke ran
clean, all nine watch items PASS. Rulings-only, close-out.

`5-0b/R1` (ruled, review) AC 3 RESTORED ON REVIEW — the pad never swallows a card commit; a fresh
Basic press always reaches state and an unarmed commit lands on the existing `empty_slot` refusal
(keyboard parity; `Hand.is_slot_empty` treats `index < 0` as empty, confirmed by reading before
any change).

`5-0b/R2` (ruled, review) THE NEUTRAL/REPLUG PATH PRIMES THE TRIGGER AND BASIC PREVS AS HELD — a
reconnected pad can never arm or spend without a fresh physical press.

`5-0b/R3` (recorded) SLOT MAPPING L2/L1/R1/R2 -> HAND SLOTS 0..3 (physical left-to-right, matching
the HUD row) and the L3/A button choices are PROVISIONAL authored values; the pad card UX question
stays open, revisit belongs to the retune/playtest block.

`5-0b/R4` (recorded) B/X/Y ARE NO-OPS BY OMISSION THIS STORY because state's
UNBLOCKABLE/DEFENSE/PITCH branches are deliberate `Invariant.check` crashes; each mode's wiring
ships with its own story (`5-7`, the E6 close-out).

Accepted-without-change review findings, recorded here: the X/Y source-scan guard catches only the
inline-literal regression form (profile-authored X is invisible to it; accepted — `5-7` wires
those buttons and its tests take over); the `sample()`<->`resolve_card_tick` dictionary boundary is
untested (accepted — a key typo crashes the first pad tick, caught deterministically by any live
smoke); commit does not disarm the slot (keyboard parity, accepted); no profile authoring
tripwires (accepted, deferred-work territory).

`5-0b/R5` (ruled, live smoke, 2026-09-02) SMOKE PASS ON ALL NINE WATCH ITEMS: held-L3 cast mode
works; L2/L1/R1/R2 arm slots matching the HUD card row left-to-right; a Basic cast with an armed
slot spends and resolves; a Basic press with nothing armed is refused state-side without a crash;
attack/block/roll are suppressed while L3 is held; release-L3-then-B rolls instantly; a button held
through L3's release fires nothing until freshly pressed; a held trigger arms once, no spam; R3
lock-on and flick retarget are unchanged in and out of cast mode; fps stable. `docs/playtest-log.md`'s
2026-09-02 entry is the operator's own hand-written record.

### Close-out

Two commits. Commit 1, code only: `src/controllers/gamepad_controller.gd`,
`src/controllers/gamepad_profile.gd`, `data/gamepad_profile.tres`,
`test/state/test_gamepad_controller.gd`. Commit 2, docs only: this entry; the story file's Status
-> `done`, Change Log row, and Live Smoke Results section (all nine items PASS);
`docs/playtest-log.md`'s operator-written entry (already present, verified before this commit);
and the board (`5-0b-pad-card-input: ready-for-dev` -> `done`). Nothing pushed; the operator
reviews the log.

## Session 2026-09-02 -- 5-0c close-out (Tier B)

Dev pass, one review-fix pass, and a same-day corrective fix from live smoke all landed before
this session; re-smoke ran clean. Rulings-only, close-out.

`5-0c/R1` (ruled, live smoke) TOTEMS NEVER ROTATE -- static structures, no visual tracking, the
Combat totem included; it still fires in all directions (state-side heading, rotation
presentational only, confirmed by reading the code before the fix). Overturns the `4-4` smoke's
"self-rotation accepted as shipped" verdict, which was passed on the grey-box placeholder.

`5-0c/R2` (ruled) per-kind tint colors are NAMED CONSTANTS in presentation code, no `data/*.tres`
-- a tint profile resource arrives only if per-kind totem model VARIANTS ever become real.

`5-0c/R3` (recorded, deferred) combat totem's red reads dim red-brown -- the measured mechanism is
`emission_operator = MULTIPLY` over a teal rune mask whose red channel is ~0.17, so red tints
crush; brighter red is wanted but not essential; fix routes (stronger constant, operator change,
or mask edit) belong to a polish/retune pass, not this story.

`5-0c/R4` (recorded, deferred) projectile stays the yellow emissive sphere (more noticeable,
two-observer verdict); the operator found the old grey ball read more three-dimensional -- flat
emissive kills depth cues; shading/depth polish deferred.

Accepted-without-change review findings, recorded here: the projectile glow ships without a
headless pin (static scene authoring, legibility is the smoke's); the tint dispatch is a
hardcoded name table (a fourth kind or a rename ships untinted with no test failure -- accepted
until kinds change); tint test coverage is p1-only (p2 path reasoned-sound).

### Close-out

Two commits. Commit 1, code + assets: `src/actors/minions/totem_actor.tscn`,
`src/actors/projectiles/projectile_actor.tscn`, `src/main/match_runner.gd`,
`test/integration/test_totem_tint_live.gd` (+ `.uid`),
`test/integration/test_totem_no_rotation_live.gd` (+ `.uid`), and `assets/props/totem/` (the
`.glb`, its `.import`, and every import-generated sibling). Commit 2, docs only: this entry; the
story file's Status -> `done`, Live Smoke Results section, and one Change Log row;
`docs/playtest-log.md`'s operator-written entry (already present, verified before this commit);
and the board (`5-0c-totem-projectile-models: ready-for-dev` -> `done`). Nothing pushed; the
operator reviews the log.

## Session 2026-09-03 -- 5-0d close-out (Tier B)

`5-0d/R1` AC 10 deviation accepted -- the live test drives a standalone `hero.tscn` probe body
instead of the Input-Map chain; measured justification (P1/P2 bodies collide at 6 units; the
forced-lock camera re-yaw arcs any held direction).

`5-0d/R2` Review F1 fixed in-story (operator-approved scope widening beyond the story's original
"measure, don't fix" AC 6 text): runner-side clamp of the accepted spawn candidate to `|19.6|`
(arena half-extent 20.0 minus the totem's 0.4 body half-extent), chosen over a candidate-level
search filter to preserve the 4-3e search's termination argument. Positions never enter
`src/state/`; golden unmoved. Noted and accepted: the containment test reads its bound from the
runner constant, so a loosened constant alone would not trip it -- the shipped form is
mutation-proven and that suffices.

`5-0d/R3` Review F2/F3 record corrections ratified: the AC 6 spawn note's crowding-only conclusion
replaced by the measured zero-occupant near-wall path; the corner-geometry sentence corrected to a
precise butt-joint resting on exact float alignment, not an overlap margin.

`5-0d/R4` Review F4 judgement ratified: West-only coverage insufficient -- test hardened to all
four faces + two opposite corners, per-frame center bound tightened to `19.5 + epsilon`, East-wall
mutation added (F4-F7 all applied).

`5-0d/R5` Review F8 RESOLVED IN-STORY, not deferred: the live smoke confirmed the forced-lock
camera exits the ring and an opaque wall occluded the hero. Operator ruled transparent walls the
right fix; applied as an approved AC 2 deviation (shared `StandardMaterial3D`, grey-blue, alpha
0.35, on the four wall meshes only; collision untouched, golden unmoved) and verified live. The
forced lock-on itself remains an open design question (no free camera control), deferred to the
post-E5+E6 playtest/retune block -- walls only, camera work not in scope here.

`5-0d/R6` Review F9 deferred: `PARKING_LOT (40, 0, 40)` now lies outside a closed ring -- the
"teleport far away, it walks back" idiom is one-way post-wall; harmless today, documented.

`5-0d/R7` Smoke PASS (pad flip [0,3]): sliding clean on all four walls; corners solid, no
snagging; near-wall summon lands inside the ring with an accepted cosmetic depenetration nudge on
the casting hero; projectile wall pass-through accepted by design; outer overhang accepted; perf
OK.

`5-0d/R8` Wall top-face rendering and the "too rectangular" feel when circling the arena are AC 2
untuned cosmetics, accepted as-is for a later art pass; judged acceptable after the transparency
change.

### Close-out

Two commits. Commit 1, code + tests: `src/main/main.tscn`, `src/main/match_runner.gd`,
`test/integration/test_arena_edge_live.gd` (+ `.uid`),
`test/integration/test_summon_spawn_containment_live.gd` (+ `.uid`). Commit 2, docs only: this
entry; the story file's fix-pass Change Log row F2/F3 label correction and Status -> `done`;
`docs/playtest-log.md`'s operator-written entry (already present, verified before this commit);
and the board (`5-0d-arena-edge: ready-for-dev` -> `done`). Nothing pushed; the operator reviews
the log.

## Session 2026-09-03 -- 5-1 readiness gate fix, operator ruling `5-1/R1`

The `5-1-accelerator-stacking` readiness gate found `5-1/R1` recorded only in the uncommitted story
file, unbacked by any decision-log entry, with `epics.md:180-183` still stating the superseded
multiplicative/`mult^N` reading (BLOCKING). This entry records the ruling by content, as already
written in the story file, so a dev pass reading `epics.md` or this log gets the same arithmetic the
story's ACs are written against.

`5-1/R1` (ruled by Matko) ACCELERATORS STACK LINEARLY, BOTH KINDS. Mana half keeps Reading A
unchanged (already linear -- each totem pays its own portion per cadence); `5-1` only removes the
bool gate that currently makes a second identical mana totem do nothing. Stamina seat changes from
`baseline x mult^N` to `baseline x (1 + N x step)`, step authored so that `N=1` is exactly identical
to today's shipped behaviour. Supersedes `E5-P/R3`'s stamina clause and the stamina half of `R-M9`.
Rationale: readability, balance (`mult^N` explodes at the third totem), symmetry with mana.
`E5-P/R3` (`decision-log.md:8159-8164`, Session 2026-09-01) is NOT rewritten -- it stands as the
superseded reading; its mana-seat resolution is unaffected.

One-line correction, recorded here rather than in `E5-P/R5` itself: `E5-P/R5`'s ordering premise for
`5-1` ("changes shipped behaviour and moves the golden, so it runs first ... per the `4-6`
re-baseline discipline of isolating one measured cause at a time") is contradicted by measurement --
the readiness gate found the hashed golden fixture authors exactly one unit kind (`&"minion"`), so
`kind_index_of` returns `NO_KIND_INDEX` for both accelerator kinds and the gate closes at the kind
lookup before the board is scanned; `N` is identically `0` for both players on every tick, and the
golden does not move on this story. The ORDERING stands (`5-1` still runs first of the Tier A
stories); only the golden-movement premise does not hold here -- recorded so nobody later reads the
story's absent re-baseline as a skipped step.

`epics.md:180-183` corrected this pass (`docs(epics)` commit) from "multiplicatively, per totem ...
stamina seat: literal `mult^N`" to the linear reading, pointing at `5-1/R1`. `docs/playtest-log.md`'s
`5-0d` entry point 4 also corrected this pass, unrelated to `5-1`: it still read the transparent-wall
camera finding as deferred, against `5-0d/R5`'s in-story resolution; aligned to match that ruling.

No `src/`, `test/`, or `data/` file touched; no code ran; no golden or suite touched. The operator
reviews the log and pushes.

## Session 2026-09-04 -- 5-1 close-out

`5-1-accelerator-stacking` close-out. `5-1/R1` (linear stacking, both seats, Session 2026-09-03)
stands as ruled; cited here, not restated.

`5-1/R2` The stamina field REPLACES its multiplicative predecessor everywhere in `src/`, `test/` and
`data/`: `stamina_accelerator_regen_multiplier` has zero surviving hits, grep-verified twice.

`5-1/R3` `4-4` M7 ("zero or negative derived projectile speed makes a shot immortal") is
DISCHARGED-AS-ALREADY-CLOSED, not DISCHARGED -- no real gap existed; what ships is a named
curve-walking regression guard, not a fix.

`5-1/R4` The golden is UNMOVED at all three isolation measurements, NO re-baseline. The prediction
is proven REACHED, not vacuous: dropping the stamina seat's identity term (`1.0 +`) fails
`test_state_matches_golden`, which measures that the golden fixture executes the new arithmetic on
every tick rather than skipping it.

`5-1/R5` `live_kind_count` keeps `has_live_kind`'s kind-lookup early-out; `has_live_kind` survives as
a one-line forward onto `live_kind_count(...) > 0`.

`5-1/R6` `live_kind_count` is the fifth named pure-query exemption in the intent-recorder intake
scan (`EXEMPT_PURE_QUERIES`), argued out with a written reason rather than by loosening the proxy.

Accepted without change, one line each: the M7 guard duplicates `_speed_at_flight_ticks` and can go
stale silently -- named failure mode, owner is whoever next touches that function. The double
null-balance guard at the stamina seat stays. Remaining review LOWs stand as reported.

`4-4` M9 ("accelerators do not stack; the second identical totem silently does nothing") and `4-4`
M2 (`stamina_accelerator_regen_multiplier` defaulting to `0.0` inverted AC 21 for an unauthored
config) are both DISCHARGED by this story.

Live smoke 2026-09-04, 6/6 PASS, no findings (`docs/playtest-log.md`). Board promoted to `done`.

## Session 2026-09-04 -- 5-1a rulings R1-R12

`5-1a-intent-hardening`'s readiness gate found operator rulings R1-R8 present only in the
uncommitted story file, unbacked by any decision-log entry -- the same class as `5-1/R1`'s
gate-found defect (Session 2026-09-03). This entry records them by content, as already written in
the story file, before the gate's fix pass claims any of them as authority.

`5-1a/R1` -- one job. A record that is not well-formed must be refused at LOAD, with a reason
naming the offending field, in the same shape as the existing `format_version` and `REQUIRED_KEYS`
refusals (`record_file.gd:250-294`). Nothing malformed reaches `advance()`.

`5-1a/R2` -- refusal is whole-record. Never skip a bad entry and replay the rest -- a partial
replay is worse than none.

`5-1a/R3` -- the live path (M3). A malformed retarget address is NOT applied; the lock target
keeps its previous value and nothing is written to the hashed `lock_target` key. This must hold in
a build where `assert` is stripped, so the guard cannot be an `assert`.

`5-1a/R4` -- `FORMAT_VERSION` is NOT bumped. The format is unchanged; only the reading is
stricter. Records that used to load and then crash are now refused with a reason -- that IS the
intended behaviour change, and it applies to malformed files only.

`5-1a/R5` -- Golden Prediction, inverse form. Golden `aa3566d7...` and the current snapshot key
set do NOT move, because the new branches are never executed by the hashed run (the fixture's
recorded intents and record file are already well-formed). Non-vacuity is therefore NOT proven by
golden movement -- every new refusal branch carries its own falsifiable test plus a mutation proof
that it goes RED when the branch is removed.

`5-1a/R6` -- scope is locked to the three findings (M3, L7, L8) plus one doctrine line: per-field
validation for fields that feed a hashed key or the rebuild loop. No general "validate everything"
sweep of `record_file.gd` or `match_state.gd`.

`5-1a/R7` -- `Invariant.check` being non-load-bearing in exported builds is a GENERAL condition,
not just M3's (`Invariant.check` is `push_error` + `assert`, and `assert` is stripped in exported
builds -- `src/systems/invariant.gd:1-15`). This story fixes it ONLY at the `_resolve_lock` seat
(M3). The general finding is a Non-Goal here and is recorded as a named unowned item at close-out
-- do not read the narrow fix as a repo-wide verdict.

`5-1a/R8` -- live smoke is a short REGRESSION check (lock, flick, retarget still behave as
before), not a feel smoke. Nothing player-visible ships.

`5-1a/R9` -- the `_resolve_lock` seat carries NO `Invariant.check` after this story. Keeping one
alongside the new branch is not an option: `test/run_all.sh:19-22,32-35` greps the state-harness
and integration output for `INVARIANT VIOLATED` and fails the whole suite on a hit, so AC 2's own
test and a retained `Invariant.check` cannot coexist in a green run. This settles what the story's
Open Question 3 left open. Five prior seats in this repo already record that an `Invariant.check`
cannot be proven by firing it: `src/state/unit_board.gd:315-318`, `test/state/test_card_play.gd:238-241`,
`test/state/test_discard_pile.gd:107-110`, `test/state/test_intent_recorder.gd:317-319`, and this
ruling itself as the fifth-plus-one.

`5-1a/R10` -- `lock_pushes` and per-intent field validation happens BEFORE `_from_dictionary` is
called. `_from_dictionary` (`record_file.gd:491`) returns an `IntentRecorder` and has no refusal
channel, and by the time its rebuild loop (`record_file.gd:511-528`) reaches a tick's
`lock_pushes`, the record under construction is already partially built -- refusing there would be
the partial refusal `5-1a/R2` forbids.

`5-1a/R11` -- a tick absent from the `lock_pushes` dictionary is NOT malformed. The writer
(`record_file.gd:362-366`) omits every empty tick by design, so sparseness is the only shape this
class ever produces, golden fixture included. Only a PRESENT entry of the wrong shape or type is
malformed. Finding L7's filed wording ("a sparse or truncated `lock_pushes` channel") is WRONG on
the word "sparse", corrected here by measurement of the write path -- the finding is not being
quietly reworded, the correction is recorded as its own ruling.

`5-1a/R12` -- AC 7's operative claim stands (no `FORMAT_VERSION` bump, no `REQUIRED_KEYS`
widening) but its justification was false: `retarget_slot`/`retarget_index` are per-intent fields
written inside each `intents` array element (`record_file.gd:399-400`, read back at `:555-556`),
not top-level required keys. `REQUIRED_KEYS` (`record_file.gd:178-197`) contains exactly twelve
entries; neither name is among them.

## Session 2026-09-04 -- 5-1a close-out

`5-1a-intent-hardening` close-out. `5-1a/R1`-`5-1a/R12` (Session 2026-09-04, above) stand as
ruled; cited here, not restated.

`5-1a/R13` -- the review's two LOW findings, accepted without change. (a) `replay_file.gd`'s
regression cover (`test_replay_verifier_tool.gd`) exercises the new validation only on the happy
path and is UNPINNED for the new refusal paths -- named owner: whoever next touches
`_contents_refusal` must check that tool by hand. (b) the pre-pass's extra O(n) walk before the
rebuild is recorded as a fact, not a debt.

`5-1a/R14` -- the general condition owed by AC 9 and `5-1a/R7`: `Invariant.check` is `push_error`
+ a stripped `assert` (`src/systems/invariant.gd:11-14`), so it is non-load-bearing in an exported
build EVERYWHERE it is called, not just at the `_resolve_lock` seat this story fixed. Recorded as
a named item owned by the FIRST story that adds an exported/distributable build. This story fixed
one seat only and this ruling must not be read as a repo-wide verdict.

`5-1a/R15` -- the `camera_pushes` twin (`record_file.gd:334`, `int(push[0])`, `push[1] as Basis`)
carries the identical unguarded dereference and was deliberately left open (`5-1a/R6`). Recorded
here so the asymmetry is on the record rather than accidental.

`5-1a/R16` -- three housekeeping corrections the re-gate found in the story file, each recorded
without a fix pass: (a) the "Operator rulings" section enumerates only R1-R8 while the story cites
R9-R12 inline; (b) the story cites "(F7)", a gate-document label the story itself does not carry;
(c) `5-1a/R9`'s text says "Five prior seats" and then lists four -- a miscount inherited from the
gate prompt.

`5-1a/R17` -- what the story delivered. The live seat now gates the retarget address instead of
reporting on it and carries no `Invariant.check`. Validation of `lock_pushes` entries and the two
retarget fields runs as a pre-pass in `load_record`, before `_from_dictionary`. Refusal is
whole-record. Sparseness is not malformedness. `FORMAT_VERSION` is unchanged at 6. Golden
`aa3566d7` and the 28-key snapshot set are unmoved, with non-vacuity carried by the five-row
mutation table rather than by the golden.

Review (Sonnet 5): PASS-with-findings, 0 HIGH / 0 MED / 2 LOW (`5-1a/R13`). Live smoke 2026-09-04,
5/5 PASS, no findings (`docs/playtest-log.md`). Board promoted to `done`.

## Session 2026-09-04 -- 5-2 gate rulings

`5-2/R1` -- Card colour reaches the state layer through a THIRD injection seam (card_id ->
Enums.CardColor), mirroring inject_card_costs and inject_card_effects exactly: load-once, injected
at the same point, same dictionary shape. `src/state/` still never reads a CardData. Closes F1.

`5-2/R2` -- No mana, orb or feature-flag evaluation runs on the unblockable path.
CastEvaluator.refusal_reason is NOT called. The empty-slot guard stays; stamina affordability is
the only cost refusal. Closes F2.

`5-2/R3` -- Death resolves the chargeup to nothing. Charging hero dies -> no landing, and it stays
DEAD (the timer exit must not return a corpse to IDLE). Enemy hero dies -> no landing. Card and
stamina stay spent in both cases. Closes F3.

`5-2/R4` -- The stamina spend restarts the regen delay like the three existing seats, AND stamina
regeneration is SUPPRESSED for the whole of CHARGING -- it joins BLOCKING and DEAD in
_regen_stamina. Closes F9 and F13.

`5-2/R5` -- Hard root during CHARGING. No new balance field for movement. AC 9's "dev's call" is
closed. Closes F4.

`5-2/R6` -- Reach is delivered by an UNTHROTTLED hero-to-hero fact pushed EVERY TICK while either
hero is CHARGING, carrying an explicit inside/outside value. Absence of a fact never means "outside
reach". A new contact kind and a widened push_contact guard are expected and in scope. State never
pulls from the runner mid-advance(). Closes F6.

`5-2/R7` -- CHARGING is entered by a direct state set at the cast seat. TRANSITION_TABLE gains NO
row. test_action_state.gd:82-95's zero-inbound assertion therefore STAYS INTACT and is re-proven,
not edited. Closes F7.

`5-2/R8` -- The one forced pin change is test_card_play.gd:246's src-wide ModeKind scan. It is
narrowed so it still fails on DEFENSE and PITCH. Named as the story's deliberate pin edit. Closes
F8.

`5-2/R9` -- The telegraph fact rides PlayerState.to_snapshot (the pinned 28-key set), not
HeroState. The golden prediction permits 28 -> 29 or 28 -> 30 with each key named as its own cause.
Closes F5 and F12.

`5-2/R10` -- Per-colour damage stays OUT of 5-2: one damage value for all three colours.
E5-P/R5's line assigning per-colour damage to 5-2 is superseded on that point by this operator
scope ruling; epics.md:150 already agrees. Closes F16.

`5-2/R11` -- S6 is answered in TWO halves, not one. BASIC casts stay UNGATED during ROLLING and
BLOCKING -- the card layer is deliberately parallel to melee and an instant summon interrupts
nothing, so the behaviour the operator observed at the 3-5a smoke is RATIFIED AS CORRECT, not a
defect. UNBLOCKABLE is gated precisely because it roots the hero for a second, which must not be
reachable out of a roll or from behind a raised shield. The distinction is DURATION, not layer --
which is exactly why the 3-5a record said an instant mode could not answer this question. S6 is
CLOSED by this ruling. Closes F15.

`5-2/R12` -- The story ships WHOLE. E5-P/R5's auto-aim cut is NOT taken: the gate measured
auto-aim as the cheapest AC in the story, one write beside the existing facing write. Closes gate
item 8.

`5-2/R13` -- AMENDS `5-2/R2`: THE FEATURE-FLAG HALF IS WITHDRAWN AS AN OPERATOR ERROR. `5-2/R2`'s
mana and orb exclusions STAND UNCHANGED -- `CastEvaluator.refusal_reason` is still never called on
the unblockable path, and no mana or orb reading is taken there. What is withdrawn is the clause
that also excluded FEATURE-FLAG evaluation. Mode (2) MUST consult the shipped `unblockable`
`FeatureFlags` toggle and degrade gracefully, per project-context's feature-flag HARD RULE: a
gameplay layer that cannot be switched off is the defect, and the overload-isolation instrument
only works if every layer is independently toggleable. What `5-2/R2` was actually protecting
against was ROUTING THE CHECK THROUGH `CastEvaluator`, and that protection is intact -- the flag is
read from the INJECTED resource at the cast seat, `CastEvaluator.REASON_FLAG_CLOSED` is borrowed as
a reason CONSTANT only, and `refusal_reason` is not called in any form.

MECHANISM, ruled rather than left to the dev pass: the flag check is the FIRST thing
`_resolve_unblockable_cast` does, AHEAD of the S6 gate -- "does this layer exist at all" is a prior
question to "may I use it right now", so a hero mid-roll in a build with E5 switched off hears that
the layer is closed rather than that it is busy. A closed flag refuses through the existing
`HeroState.reject_action` seam and spends NOTHING: no stamina, no card, no `CHARGING` entry, no
telegraph -- the insufficient-stamina fallthrough shape, since there is no degraded unblockable to
fall back to. `BASIC` casts are untouched: the `unblockable` toggle is mode (2)'s layer and closing
it must not disable mode (1).

RAISED BY THE DEV PASS, NOT BY A LATER GATE. The `5-2` dev pass implemented `5-2/R2` as written,
shipped the path flag-blind, and reported the contradiction with project-context rather than
resolving it in code -- which is the behaviour the "STOP and report" rule exists to produce. This
ruling is the answer to that report. The story's AC 5 text is corrected on the flag clause ONLY;
the record that the tension was raised stays in the story's Completion Notes.

OPEN, and deliberately not decided here: the AUTHORED `data/feature_flags.tres` still leaves
`unblockable` at its `false` default. Turning the layer ON in authored data is a separate design
call about when E5 goes live -- mode (2) is not reachable in live play until `5-7` wires the pad
anyway -- and no story ships it yet.

`5-2/R14` -- THE `unblockable` LAYER GOES ON IN AUTHORED DATA WITH THE STORY THAT BUILDS IT.
`data/feature_flags.tres` flips `unblockable` to `true`, closing the item `5-2/R13` left open. Two
reasons, and the second is the stronger one. FIRST, the `4-4` precedent: that story turned
`minions` on in the same authored file as it shipped the layer, and the same reading applies here.
SECOND, a flag left `false` is a SECOND CLOSED GATE that `5-7` would have to remember to open, and
the failure mode of forgetting it is the worst kind available -- the mechanic does nothing while
every test in the suite is green, because the tests inject their own `FeatureFlags` and never read
the authored file. There is no risk in flipping it now, and `5-2/R15` is why: nothing can currently
produce a mode (2) intent at all, so the layer being open changes no live behaviour.

MEASURED BEFORE FLIPPING, and recorded because the answer is what makes the flip safe: NO test pins
the authored flag VALUES. `test_data_resources.gd::test_feature_flags_tres_loads_with_all_layer_
fields` pins field PRESENCE only (`field in flags`), and `test_determinism.gd` records the authored
file as an explicit NON-cause of the golden -- `_golden_flags()` constructs its own `FeatureFlags`
in-test, so "flipping the authored minions flag cannot re-baseline this hash" and the same argument
covers this one. `test_intent_recorder.gd:382` sets `unblockable = true` on its OWN in-test
resource, not on the authored file.

`5-2/R15` -- MODE (2) HAS NO LIVE PRODUCER, AND THIS IS RECORDED RATHER THAN FIXED HERE. Wiring an
input for mode (2) is explicitly NOT in `5-2`'s scope.

MEASURED, not assumed: EVERY assignment to `InputIntent.card_mode` anywhere in `src/` hardcodes
`Enums.ModeKind.BASIC`. There are exactly two, and the story named only one of them --
`src/controllers/gamepad_controller.gd:172` (the pad, which `5-7` owns) AND
`src/controllers/keyboard_controller.gd:113` (which no story had named, and which is in the same
state). `InputIntent.card_mode` itself DEFAULTS to `BASIC`, the enum's zero value, so an unset
field is BASIC too. The only other places the field is written are pass-throughs that COPY an
existing value -- `IntentRecorder.copy_intent` and `RecordFile._intent_from_values` -- which can
carry only what a producer already put there; and `match_runner.gd:2229-2230` passes `BASIC` to the
HUD for DISPLAY, which is not an intent at all.

THE CONSEQUENCE FOR THE TIER A RITUAL: the live smoke for `5-2` is a REGRESSION SMOKE. It proves
that nothing already shipped broke -- movement, melee, blocking, rolling, mode (1) casting, the
draw delay, minions and totems -- and it CANNOT prove that the unblockable works, because no input
path can initiate one. The first real playtest of mode (2) is at `5-7`. A smoke report for this
story that claims to have observed a chargeup would be describing something that did not happen.

THE STATE-SIDE CHAIN IS NOT UNTESTED, and the distinction matters: it is covered end to end by
`test/state/test_unblockable_initiation.gd` against hand-driven intents, which is exactly the
coverage shape the state layer exists to make possible. What is missing is the INPUT EDGE, not the
mechanic.

`5-2/R16` -- CLOSE-OUT. Story 5-2 done: gate NOT READY 9 blocking -> fix -> re-gate all closed ->
dev pass (Opus) -> R13/R14/R15 follow-ups -> review (Sonnet) PASS 0 HIGH / 0 MED / 2 LOW ->
regression smoke 5/5. Golden re-baselined `aa3566d7` -> `dc2c9ffa`, one measured cause (the
telegraph snapshot key, 28 -> 29). `FORMAT_VERSION` 6 -> 7, forced by the fourth content channel
and not by the contact-kind widening. Suite 595/0/4644 -> 627/0/4788.

`5-2/R17` -- OPEN, forcing point 5-5. Casting a card while holding block DROPS the block on the
cast tick. Nothing ruled this and nothing tests it; it is a consequence of two layers overlapping
with no stated interaction. It does not matter today. It matters at `5-5`, where a card IS the
defensive answer to an incoming unblockable: a block that silently drops every time a card is
played is a gameplay consequence someone has to WANT. Recorded in the S6 shape -- named now, ruled
by the story that is forced to care.

## Session 2026-09-05 -- 5-3 close-out (Tier B)

Dev pass and review fix pass (4 fixes) both landed before this session; live smoke ran, 10/10
verdicts recorded, all findings non-blocking. Rulings-only, close-out.

`5-3/R1` -- S5 FULLY DISCHARGED. The success-cue half is wired in both modes this story
(`card_cast_resolved` -> `on_card_cast_resolved`). The rejection half was already live before this
story through the pre-existing `action_rejected` -> `TelegraphController` wiring (`1-10`, reused by
`3-5a`) -- zero new code, no seam widened.

`5-3/R2` -- the three charge clip speeds are named MEASURED native lengths divided by an authored
chargeup constant, the coupling guarded by `test_balance_authoring.gd` (the `4-3d/R9` branch --
an inline `BalanceConfigService` read was declined because a replay would then present the
authored duration instead of the one it recorded). Accepted consequence: retuning
`unblockable_chargeup_seconds` is no longer a pure one-line `.tres` edit; the suite goes RED and
names the re-derivation needed.

`5-3/R3` -- the debug reset now clears CHARGING, stops the charge window, and rests the colour --
the second named exception to the reset contract (`4-1/R5` is the first). Measured pre-fix defect:
a chargeup crossed the round boundary and landed in the next round (100.0 -> 90.0 hp). This
story's `src/state` Non-Goal was overridden by operator ruling for this one correction; golden
measured UNMOVED both directions, not re-baselined. The frozen round-over telegraph (a survivor
mid-chargeup at round end) is ruled COSMETIC, not fixed, and ends at the reset.

`5-3/R4` -- the `card_cast_resolved` direct connect is the FIRST presentation consumer wired
straight to a `MatchState` signal outside the eight-seam family. It STANDS (read-only, per-slot
guarded, dependency direction unchanged) and enters the ARCH AMENDMENT QUEUE as a new member:
"MatchState-signal direct-connect as a connection shape -- document or forbid before a third
instance exists."

`5-3/R5` -- TIER STAYS B despite the state touch. The touch was a corrective review finding, not
planned scope; golden unmoved; the proof burden actually carried (two-model review, mutation
proofs both directions, own regression guard) already exceeded the Tier A floor. A story that
PLANS to touch state gets Tier A up front -- this ruling is not a precedent for state edits riding
Tier B by default.

`5-3/R6` (smoke findings, all OUT of this story, owners named):
(a) hold-the-button chargeup -- the attacker holds the input for the window, giving the defender a
readable beat that something big is coming; Sekiro-parity is the stated design target, forcing
point `5-7` (the input half; the state semantics of hold-vs-commit are decided there or in a
sibling it names).
(b) the strike visually stabs air while damage lands at ~8 m -- attacker delivery (lunge/travel at
landing) is a design question for the post-E5/E6 playtest block; the generous range itself is BY
DESIGN and stays.
(c) charge audio is placeholder sine tones; discrimination judged marginal by the operator's ear
and deferred to a real audio pass, at which point Live Smoke item (c)'s naive-observer
discrimination is re-judged.
(d) general locomotion speed / walk-as-default / sprint-costs-stamina recorded for the retune
block.
Colour -> clip mapping recorded as a presentation choice: RED=swipe, BLUE=thrust,
GREEN=jump_attack.

Accepted without change (review findings, no ruling needed): the HUD dead-mode argument;
`_state` written before the CHARGING early return; fresh material applied per dispatch;
`telegraph[0]` read unchecked; `.playing` used as an assertion; the audio fade off-by-one.

### Close-out

Two commits. Commit 1, code + assets: the dev-pass and review-fix-pass `src/` changes, the two new
`tools/` scripts, the new/modified tests, the three new paladin clips + re-assembled
`paladin_anims.res`, the four new audio cues, the three new telegraph profiles, and the one
intentional `p1_cast_unblockable` Input Map addition to `project.godot`. Commit 2, docs only: this
entry; the story file's Status -> `done`, Live Smoke Results section (10/10, SMOKE PASS), and
Change Log row; `docs/playtest-log.md`'s operator-written "5-3 smoke" entry (already present,
verified before this commit); and the board (`5-3-telegraph-presentation: ready-for-dev` ->
`done`, `# Tier B` comment preserved). Nothing pushed; the operator reviews the log.

## Session 2026-09-06 -- 5-4 close-out (Tier A)

`5-4/R1` -- orbs are granted immediately at the landing, never dropped or picked up; a per-round
stake, cleared at the debug reset (the only round boundary) and NOT at `_end_round` -- clearing
there would delete the winner's orbs before the freeze displays them.

`5-4/R2` -- `OrbPool.to_snapshot()` stays `{red, blue, green}`; the authored maximum is config, not
state, and never enters the hash -- a deliberate divergence from `ManaPool`, proven falsifiable
(staging the key moved the golden to `4cc02623`).

`5-4/R3` -- a pre-injection `OrbPool` is UNBOUNDED via the `NO_MAXIMUM` (-1) sentinel, not bounded
at zero; `test_economy_and_hero.gd` and `test_cast_evaluator.gd` document that real behaviour and
were deliberately left unedited.

`5-4/R4` -- the observation-seam family moves EIGHT -> NINE (`connect_orbs_changed`, a clone of
`connect_mana_changed` with prime-on-connect). A second `MatchState` direct-connect was REFUSED
because `5-3/R4` left that form unresolved. The test moved in this story; the
`game-architecture.md` prose did NOT -- it is the SECOND member of the arch amendment queue,
forcing point E5 close-out.

`5-4/R5` -- `orb_pool._max` is classified INJECTED: every path to it runs through `apply_balance`,
which is unconditionally paired with `capture_apply_balance` at both runner call sites, so a
replay reconstructs it. `UNHASHED_CROSS_TICK_MEMBERS` stays at three.

`5-4/R6` -- a landing that KILLS its target still pays the grant; proven by a dedicated test whose
non-vacuity was shown by staging an `is_alive()` guard.

`5-4/R7` -- AC 16's named mutation was vacuous and was corrected to the form that falls (a cue
firing on any payload rather than on an increase); the vacuous form stays on record.

`5-4/R8` -- authored values are PROVISIONAL: `unblockable_orb_grant` 1, `max_orbs_per_color` 5.
Retune is a `.tres` edit with no test edit and no re-baseline.

Accepted without change (review findings, no ruling needed): none beyond the AC 16 mutation
correction folded into `5-4/R7`.

The close-out suite ran THREE times, not two: a real classification failure (`orb_pool._max`
landing in none of the four `test_replay_identity.gd` buckets) failed the first attempt; `PROC/R1`'s
run-budget was overrun by one full run and is reported here, not absorbed.

### Close-out

Four commits, in this order (reordered from the plan so the board promotion's grep for this entry
finds it): Commit 1, code + tests: the `src/` and `data/` changes, the two new test files
(`test_orbs_economy.gd`, `test_orb_cue_live.gd`) plus their `.uid` sidecars, and the five modified
test files. Commit 2, docs: the story file's Status -> `review`, Dev Agent Record, and Live Smoke
Results section (8/8, SMOKE PASS); `docs/playtest-log.md`'s operator-written "5-4" entry. Commit 3,
docs: this entry. Commit 4, board: `5-4-orbs: ready-for-dev` -> `done`, `# Tier A` comment
preserved. Nothing pushed; the operator reviews the log.

## Session 2026-09-06 -- 5-5 close-out (Tier A)

`5-5/R1` -- Mode 3 ships: same-colour negation inside an authored window (1.5 s provisional), card
always consumed, small stamina cost (10 provisional), defender never rooted by the cast; window
opens at cast, is consumed only by a successful negation, survives wrong-colour landings, expires
silently.

`5-5/R2` -- A negated landing pays NOTHING: no damage, no `hit_landed`, no orb grant -- the `5-4`
grant contract is "a landing pays", and a negation is not a landing.

`5-5/R3` -- EXACTLY ONE state-based refusal: `CHARGING`, reusing `REASON_UNBLOCKABLE_COMMITTED` --
a chargeup is a committal attack and a commitment coverable by a defense is not a commitment.
`ROLLING`/`BLOCKING`/`ATTACKING` remain castable. Measured inheritance: a `CHARGING` hero already
cannot swing/roll/block (no `TRANSITION_TABLE` row) but CAN cast a basic card -- inherited from
`5-2`, owner `5-6`, untouched here.

`5-5/R4` -- The cast interrupts what is HELD, not what is in flight: `BLOCKING` -> `IDLE`
(`5-2/R17` ratified, first real exercise); `ATTACKING`/`ROLLING` untouched -- the gate proved the
unconditional form was a live defect (orphaned mobile hitbox; silently voided chargeup).

`5-5/R5` -- New "defense" per-player snapshot key `[colour, remaining_ticks]`, key set 29 -> 30,
golden re-baselined ONCE `dc2c9ffa` -> `d9725092`, one cause measured in both directions;
`FORMAT_VERSION` stays 7; `defense_window`/`defense_color` classify HASHED.

`5-5/R6` -- Legibility rides the widened `deflect_landed` (third argument: answered colour; melee
sites pass the sentinel; spark tints to the answered colour). Seam family stays NINE -- the pin
counts `connect_*` wrappers, not arity. Privacy: the negation already reveals the colour
deductively; the tint only stops the cue lying.

`5-5/R7` -- Sentinel guard (review fix, MED): `defense_color != NO_TELEGRAPH_COLOR` added to the
negation guard -- the `inject_card_colors` totality check is `assert()`-backed and STRIPPED IN
EXPORTED BUILDS (`5-1a`), so "closed at the seam" was debug-only; two degraded colours must not
make a parry.

`5-5/R8` -- Keycode collision (operator's eye, HIGH): `p2_cast_defense` authored on `L` == P1's
roll key; Godot allows one physical key on two actions silently; moved to semicolon (keycode 59)
and the CLASS killed by a permanent project-wide uniqueness guard in `test_deck_and_hand.gd`
(generalising the debug-key scan). The gate had measured "L is free" against the card scheme only.

`5-5/R9` -- Temporary binding contract: `p2_cast_defense` + one branch arm + its field + its
action-string line = exactly what `5-7` deletes. Defense-above-confirm branch order is
unobservable today (no prefix carries both cast actions) -- becomes a real decision only if `5-7`
gives one prefix both.

`5-5/R10` -- Smoke findings with owners: cards in hand uncoloured -- SECOND consecutive smoke
(`5-4`, `5-5`), operator wants a provisional tint pending better UI -- decision seat E5 close-out
inventory, elevated signal; defense feel reads as "the defender did nothing" + chargeup unreadable
+ attack/defense windows unclear -> retune/polish block; per-attack-type counter ideas
(sweep/jump/thrust counters, ranges, auto-aim) -> `5-6` ladder scope talk. Basis works; "first make
things, then make them pretty" is the operating rule.

Accepted without change (review findings, no ruling needed): `deflect_landed` serving three
mechanisms is a NAMED trade-off; mutation-table row-4 provenance corrected (7+3, not 9+1).

### Close-out

Four commits, order C1 -> C2 -> C4 -> C3 (the decision-log commit precedes the board commit -- the
promotion grep requires the log to already name the story). Commit 1, code + tests: the `src/state/`
changes, `data/balance/balance_config.tres`, `src/actors/hero/telegraph_controller.gd`,
`src/controllers/keyboard_controller.gd`, `project.godot`, every modified `test/state/` file, and
the new `test_unblockable_defense.gd` + `.uid`. Commit 2, docs: the story file's Status -> `done`,
Live Smoke Results section (10/10, SMOKE PASS, zero fix rounds), Change Log row; `docs/
playtest-log.md`'s operator-written "5-5" entry (byte-identical, verified before this commit).
Commit 3, docs: this entry. Commit 4, board: `5-5-unblockable-defense: ready-for-dev` -> `done`,
`# Tier A` comment preserved. Nothing pushed; the operator reviews the log.

## Session 2026-09-07 -- 5-6 close-out (Tier A)

`5-6/R1` -- The three-tier ladder ships: colour counter = full negation + attacker stun; dodge =
roll iframe open at the landing, damage times the authored `dodged_unblockable_damage_multiplier`
(`0.0`) and zero orbs; unanswered = full damage + orbs unchanged. The GDD's ~20% is an
occurrence-rate target, the multiplier is a knob, and any non-zero retune owes a `docs(gdd)`
amendment.

`5-6/R2` -- Stun is ONE system resolving open decision (a): colour-counter `1.0` s, deflect `0.4` s
(direction colour > deflect pinned, not just positivity); deflect stamina penalty `12.0` via
`StaminaPool.add()` not `spend()` (punitive drain always applies, no regen-delay restart). All
values provisional.

`5-6/R3` -- `STUNNED` forbids ALL actions -- table-driven three by the empty row, all THREE cast
seats by explicit gates (the third, `_unblockable_refusal_reason`, added at review as finding H1
against the story's own Non-Goals lock -- the lock protected `5-2` scope, not a hole contradicting
the ratified ruling); hard root, literal zero; windows tick out, natural expiry only;
`REASON_STUNNED` one shared constant across all three seats.

`5-6/R4` -- The dodge rung's observation point is the START OF STEP 3 -- a roll pressed on the
landing tick dodges on NEITHER slot, a previous-tick roll on BOTH; seat symmetry pinned by the
four-case two-slot test, which also discharged the cut smoke flip item; the committed default
`[0,1]` needs no flip for two-keyboard smokes.

`5-6/R5` -- `is_hitbox_active()` gains "and `action_state == ATTACKING`" -- a stunned (or otherwise
interrupted) hero's orphaned active window stops being queried at the source; stated as a property
of `action_state`, closing future non-`ATTACKING` interrupts too.

`5-6/R6` -- Fifth named reset exception: stun window + `STUNNED` clear in `_reset_player`; the
reset seat's OWN contract (`IDLE` immediately, not via the next tick's timer arm) pinned by a
direct-call test -- the public-path mutation stayed green (masked), the direct-call one goes red.

`5-6/R7` -- Golden `d9725092` -> `d5bcb7e6`, ONE re-baseline; cause = AC 9's complete write set
(stun window + state + stamina drain, the two sub-causes isolated separately); fixture authors
coverage values (7-tick stun, 18.0 penalty); TWO lost coverage items accounted (t9 chain, and its
consequence the t13 block resolution), equivalents live in `test_action_state.gd` and
`test_block_deflect.gd`; gained: `STUNNED` in the hashed record; `FORMAT_VERSION` stays 7, key set
unchanged.

`5-6/R8` -- The melee-deflect stun carries ONE tick of residual lunge velocity (step 4 writes
after that tick's movement) -- intentional, the `2-3/R13` DEAD-velocity precedent, pinned; the
colour-counter entry roots same-tick.

`5-6/R9` -- A double deflect-penalty in one tick is structurally unreachable (one active window
per hero + the dedupe rung precedes the deflect branch) -- comment at the site, no speculative
guard.

`5-6/R10` -- Smoke findings with owners: PASS 8/8 no defects; deflect stun possibly a touch short
= tuning note, retune block owns it; stun legibility (pose-hold, no dedicated clip) not assessed =
retune/polish block.

Process: the 5-6 code review ran as a subagent of the dev session rather than a fresh session
(prompt defect, caught after the fact); findings were independently reproduced by hand and
accepted; future dev prompts end at the report with HALT.

### Close-out

Four commits, order C1 -> C2 -> C4 -> C3 (the decision-log commit precedes the board commit -- the
promotion grep requires the log to already name the story). Commit 1, code + tests: `src/state/
match_state.gd`, `src/state/hero_state.gd`, `src/state/resources/balance_config.gd`, `src/state/
timing/balance_ticks.gd`, `data/balance/balance_config.tres`, and the nine modified `test/state/`
files. Commit 2, docs: the story file's Status -> `done`, Live Smoke Results section (8/8 PASS, no
defects), Change Log row; `docs/playtest-log.md`'s operator-written "5-6" entry (verbatim). Commit
3, docs: this entry. Commit 4, board: `5-6-three-tier-ladder: ready-for-dev` -> `done`, `# Tier A`
comment preserved. Nothing pushed; the operator reviews the log.

## Session 2026-09-07 -- 5-7 close-out (Tier B)

`5-7/R1` -- B and X each commit on ONE dedicated `GamepadProfile` field of their own
(`cast_unblockable_button`, `cast_defense_button`), not a reuse of `roll_button`: `cast_basic_button`
is the precedent followed, a field carrying the CAST-MODE meaning distinct from any live-play
field, so re-authoring the dodge button cannot silently move the UNBLOCKABLE confirm with it.
Mapping is PROVISIONAL exactly as `5-0b/R3` left L3/A -- the card-mode-select UX is still the open
high-P4 GDD question, and this is one more working scheme, not a settled one.

`5-7/R2` -- The same-tick confirm chord (unreachable on real hardware, reachable from a test) ties
to the PHYSICAL left-to-right face-cluster order X -> A -> B, last write wins, so a triple resolves
to B / UNBLOCKABLE. One rule, shared verbatim with the four-slot arming chord's own tie-break
(`5-0b`'s), rather than a second differently-shaped rule someone has to remember separately.

`5-7/R3` -- Y is a no-op BY CONSTRUCTION, not by omission of a branch: no authored `GamepadProfile`
button field may carry `JOY_BUTTON_Y`, so a read of Y is not expressible through the controller's
one read route (`_profile.<x>_button`), and mode PITCH (a deliberate crash-on-reach stub) stays
structurally unreachable from the pad. PITCH remains reachable from nowhere until its own E6 story
revisits the guard.

`5-7/R4` -- Both TEMPORARY keyboard confirms are deleted: `F` (`p1_cast_unblockable`, 5-3) and `;`
(`p2_cast_defense`, 5-5), branch/field/action-string/Input-Map-action each, the four-part inventory
both stories named. The keyboard is Basic-only again; modes ②/③ are pad-only from this story on.

`5-7/R5` -- A B or X press with nothing armed still raises the commit carrying `card_slot == -1`,
reaching the state-side `empty_slot` refusal rather than being swallowed in the controller -- the
Basic review-fix precedent extended to both new confirms identically, not re-decided.

`5-7/R6` -- OPERATOR RULING, hold-to-charge (`5-3/R6` debt carried forward): the operator wants the
Sekiro hold-through-chargeup shape for mode ② -- hold the confirm through the telegraph rather than
a single press. Press-edge (this story's shape) ships as the interim. Hold-to-charge is
STATE-TOUCHING (an early release needs a `CHARGING` teardown `src/state/` does not have today) and
gets its own Tier A story; slot assigned at E5 close-out / E6 planning. Early-release semantics are
decided at that story's own scope conversation, not pre-empted here.

`5-7/R7` -- Accepted review findings, one line each: LOW-1/LOW-2 (the Y-guard's untested evasion
forms, and its blanket ban on any future Y binding) kept as-is until the E6 story that actually
wires Y forces the question; LOW-4 (5-6's closed-story smoke prose naming actions this story
deleted) is history and is not rewritten, per the standing rule that a closed story's record is
never edited to stay current; LOW-5 (`>= 8` vacuity floor doubling as a field-count pin) is
intentional, left as-is; LOW-3 (stale shipping-voice prose naming `p2_cast_defense` as still
shipped) fixed in commit 1, comment-only, state harness re-run confirmed identical counts
(720/5363/0).

`5-7/R8` -- Process note: a subagent incident recurred (create-pass forks wrote to tracked files
despite a read-only brief -- the second instance of this class of failure). Create and docs-only
passes now run with NO subagents at all, for any story; the mechanism is replaced, not tightened
further.

### Close-out

Two commits (Tier B precedent, no separate gate pass). Commit 1, code + tests + data: the seven
files -- `src/controllers/gamepad_controller.gd`, `src/controllers/gamepad_profile.gd`,
`data/gamepad_profile.tres`, `src/controllers/keyboard_controller.gd`, `project.godot`,
`test/state/test_gamepad_controller.gd`, `test/state/test_deck_and_hand.gd` -- including the
LOW-3 comment-only review fix, state harness re-run identical (720/5363/0). Commit 2, docs: the
story file's Status -> `done`, Live Smoke Results section transcribed from the operator's
playtest-log entry (six core items PASS, the optional two-pad exchange NOT RUN -- no second
physical pad); `docs/playtest-log.md`'s operator-written "5-7" entry, byte-identical; this entry;
board `5-7-pad-modes-2-3: ready-for-dev` -> `done`, `# Tier B` comment preserved. Nothing pushed;
the operator reviews the log.

## Session 2026-09-07 -- E5 close-out

`E5-C/R1` -- Epic-5 promotes `backlog` -> `done`, matching epic-0..4. All twelve E5 story keys
carry `Status: done` with zero drift between board and story files; `epic-5: backlog` was simply
the un-promoted pre-close-out state, not a standing precedent to leave.

`E5-C/R2` -- The `card_cast_resolved` MatchState-signal direct-connect (`5-3/R4`) is DOCUMENTED
as a named exception (Option A), not banned: it stands when read-only, per-slot guarded, no state
handle retained, and a one-shot cue with no priming semantics. Sole instance today is
`match_runner.gd:501`. A third instance (a second already exists nowhere; `connect_orbs_changed`
was built instead, `5-4/R4`) is the operator's call.

`E5-C/R3` -- The observation-seam family moves EIGHT -> NINE (`connect_orbs_changed`, `5-4/R4`).
Fourteen stale seam-count sites corrected (3 doc, 11 code comments), state harness re-run
identical (720/5363/0). Three close-out-inventory premises corrected in the same pass: the
epic-line precedent was PROMOTION, not "leave at backlog" (both prior instances read backwards);
the two named stale-comment suspects (`unit_board.gd:303`, `match_runner.gd:143-145`) were both
wrong sites -- the real trail led to a stale line reference at `deferred-work.md:21` (now fixed to
`:404-407`); and the `unit_board.gd:404-407` seam comment had already self-corrected before this
pass touched it.

`E5-C/R4` -- The 5-2 close-out has no separately-headed session, but is not a missing record: its
ruling lives as `5-2/R16` inside `Session 2026-09-04 -- 5-2 gate rulings` (`:8732`). Findability
defect only, no rewrite of a closed session (`5-7/R7`'s standing rule). Pointer recorded here
rather than editing that session.

`E5-C/R5` -- OPERATOR RULING: card-hand tint (uncoloured hand, second consecutive smoke finding
per `5-5/R10`) is slotted as the FIRST E6 story. No story key created now; the slot is assigned at
E6 planning.

`E5-C/R6` -- OPERATOR RULING: the hold-to-charge Tier A story (`5-7/R6`) gets its slot at E6
planning. Early-release (CHARGING teardown) semantics are decided at that story's own scope talk,
not pre-empted here. Operator veto on the shape stays open.

`E5-C/R7` -- Deferred-work and retune items given a durable home (`docs/implementation-artifacts/
deferred-work.md`, new `## E5 residue` section): five retune entries (deflect stun 0.4s vs the
colour-counter's ~1s, stun legibility, defense feel, chargeup readability, audio cast-vs-deflect
discrimination); `5-0a` diagonal-strafe LOW; `5-0c`'s two accepted tint findings; `5-3/R6(b)`
attacker delivery and `5-3/R6(d)` locomotion feel; `5-5/R10`'s per-attack-type counter ideas,
orphaned when the `5-6` ladder scope talk ruled on none of them -- re-homed as an E6-planning
input, nothing disappears silently. Playtest-block checklist gains the two-pad mode-2/mode-3
exchange NOT RUN in `5-7` (no second pad). `5-3/R2`'s correction to the `BC/R3` tuning-isolation
fact (`unblockable_chargeup_seconds` is no longer a one-line `.tres` edit) recorded as a named
standing exception.

`E5-C/R8` -- `gdd.md`/`epics.md` reconciled to shipped E5: per-colour damage claim (`gdd.md:239`)
corrected to one damage value for all three colours (`5-2/R10`); orb storage "no cap" (`gdd.md:254`,
`epics.md:151`) corrected to the authored cap `max_orbs_per_color = 5` (provisional, `5-4/R8`).
`epics.md`'s E5 section now names all twelve delivered story keys.

`E5-C/R9` -- Operator's E6-planning inputs recorded by content, not yet slotted: mode-2 chargeup
animation (crouch/leap, short mid-air hover, auto-aim toward a target in radius -- pairs with the
hold-to-charge story); defense animation and sound synced to the attack animation (today a click
with an ugly sound at an ugly point); walk/run with position and speed as a resource -- a NEW
gameplay system, operator ruling at E6 planning; walk and turn-in-place animations; additional
camera freedom (unspecified); smarter, more natural minions that never stop dead on an obstacle
(`approach()` still cannot tell "arrived" from "blocked" -- nav story candidate).

### Close-out

Next steps: E5 retrospective, then E6 planning.

## Session 2026-09-07 -- E5 retrospective

The third epic retrospective in this project. The retrospective itself is
`docs/implementation-artifacts/epic-5-retro-2026-09-07.md` (commit `docs(retro): epic 5
retrospective`); this entry records only what it RULED, per the standing separation between an
analysis artifact and the decisions it produces. `sprint-status.yaml` is deliberately NOT touched --
no `epic-N-retrospective` key exists and the header locks the lifecycle to
`backlog -> ready-for-dev -> done`, so `gds-retrospective` step 11 is skipped on the E3/E4
precedent. Report delivered REPORT-ONLY; the operator ratified EVERY proposal AS PROPOSED, blanket,
with no amendments. The standing meta-rule (`decision-log.md:7937-7941`) was the yardstick again:
the three rulings that change process cost one file write, one subtraction, and one word.

`E5-R/R1` (ratified) E4'S ACTION ITEMS: EIGHT FOR EIGHT, NONE DROPPED, AND THE (c)-RESIDUUM
CORRECTION RECORDED. `E4-R/R1` discharged open decision (a) at the venue it named (`E5-P/R1`) and
`5-6/R2` then shipped it; (b) and (e) sit on the playtest checklist with the operator as named
owner. `E4-R/R4` held without ever firing. `E4-R/R5` went two for two again, four for four
cumulative. `E4-R/R7` visibly shaped commit ORDER at `5-4`, `5-5` and `5-6`. `E4-R/R8`'s six
inherited items all landed, and two IMPROVED on the ruling that produced them -- `R-M9`'s
multiplicative reading was overturned by measurement at `5-1`'s gate (`5-1/R1`, linear), and (a) was
not merely owned but implemented. **CORRECTION OF RECORD: the `(c)`-tagged residuum was FOURTEEN
items, not the thirteen `E4-R/R8` item 5 stated.** First measured at the E5 planning pass
(`decision-log.md:8135`) and re-confirmed by content this pass; recorded here so the count in
`E4-R/R8` is not read forward. GENERALISATION, ratified as the lesson: **a forcing point discharges
a queue; a fence does not** -- the arch amendment queue (`5-3/R4`, `5-4/R4`) emptied itself at the
E5 close-out because that venue was named, where E4's queue had no venue and leaked six stale
claims.

`E5-R/R2` (ratified) `E4-R/R2` AMENDED: THE REPORT GETS AN ARTIFACT, THE LOG GETS THE LAYER STATES.
Measured: the string `LAYER-COMPLETION` appears in ZERO of the twelve E5 story files, and for ten of
twelve stories NO review report artifact exists anywhere -- not in the repo, not in `C:\dev`.
`5-6-three-tier-ladder.md:971` cites `docs/implementation-artifacts/5-6-code-review.md`, a path that
has never existed in git history. The two survivors are `_51a-review.md` (canonical four-line form)
and `_52-review.md` (eight lines naming topics rather than declared layers). The substance did NOT
leak -- every E5 close-out session carries an "Accepted without change (review findings, no ruling
needed)" block, so E4 finding B does not recur -- but the terminal state of each layer is
unauditable for ten stories. **RULE, three parts: (1) the review report is WRITTEN WITH THE WRITE
TOOL to `C:\dev\_<story>-review.md`, so the artifact survives the session that produced it; (2) the
story's CLOSE-OUT LOG SESSION carries ONE LINE naming each declared layer with its terminal state;
(3) the browser still REJECTS a report that does not carry its `LAYER-COMPLETION:` line, unchanged
from `E4-R/R2`.** Two writes, no new check.

`E5-R/R3` (ratified) `E4-R/R3` AMENDED: THE INTERVAL IS THE FULL STORY CYCLE, AND THE VENUE IS THE
LOG. E5 produced 41 suite-output files against E4's single number -- the instrument is real and cost
nothing. But every recorded delta stops at the DEV PASS, while `E4-R/R3`'s own words name "the
before-baseline run and the final run", and for `5-0b`/`5-0c`/`5-0d` the final run is the review-fix
run. **The measured interval is the FIRST before-baseline run to the LAST suite run of the WHOLE
story cycle, review fixes included. The venue is the CLOSE-OUT LOG ENTRY, as `E4-R/R3` already said
and only `5-0a` honoured. AN OVERRUN IS REPORTED, NEVER BLOCKING** -- the number is an instrument
for the operator at the scope conversation, not a gate. Measured record, five of six Tier B stories
instrumented: `5-0a` 20m35s (log venue, correct); `5-0b` recorded ~13 min, full cycle 39m26s; `5-0c`
recorded 13m18s, full cycle 35m05s plus a next-day fix run; **`5-0d` recorded 17m43s and described
as "well inside the ~1h budget", full cycle 16:44:15 -> 17:58:36 = ~74 MINUTES, OVER BUDGET**;
`5-3` no budget line at all; `5-7` no line and no suite files. `5-0d`'s overrun is **REPORTED, NOT
ACTIONED** -- the story is closed and pushed, its work is sound, and `E5-R/R7` forbids editing it.
Minor discrepancy also on record: `5-0c`'s stated start `13:21:12` matches no surviving file
(`_50c-suite-before.txt` is `13:24:20`).

`E5-R/R4` (ratified) `E4-R/R4` KEPT UNCHANGED. The gate-round cap never had to fire: the maximum in
E5 was TWO rounds (`5-1a` gate plus re-gate; `5-2` gate NOT READY with nine blocking findings, one
fix pass, re-gate all closed at `5-2/R16`), against `4-3d`'s six and `4-3e`'s five. Every story
carries exactly ONE `docs(5-x): gate fixes` commit. Zero docs-only rounds existed to delete
specification an earlier round had added -- E4's dominant sink, gone. `5-2` also DECLINED its own
pre-named break line, its gate measuring auto-aim as the cheapest AC in the story (`5-2/R12`), which
is `E4-R/R4`'s corollary (behaviour and acceptance, not mechanism) producing a measurement instead
of a split. A rule that shaped an epic without firing is working; widening it would cost the
operator time the failure no longer costs.

`E5-R/R5` (ratified) `PROC/R1` IS RECLASSIFIED AS A DISCLOSURE RULE, NOT A CAP. **Two runs stay the
default; more runs are legitimate WITH A STATED REASON; every run beyond the second is ALWAYS
REPORTED, NEVER ABSORBED.** This ratifies three epics of observed behaviour rather than changing it.
E5's two bends: `5-3`'s dev pass ran five (before plus four after, `5-3:559-574`), disclosed with
its cause -- a genuine RED on the first after-run; `5-4`'s close-out ran three, disclosed in the log
as "`PROC/R1`'s run-budget was overrun by one full run and is reported here, not absorbed"
(`:8848-8850`). Every bend on record across E3, E4 and E5 was already disclosed with its cause.
Treating an honest extra run as a violation is exactly the formality the meta-rule rejects.

`E5-R/R6` (ratified) SUBAGENTS: `5-7/R8` STANDS AS THE STANDING RULE, AND NOTHING FURTHER IS ADDED.
`E4-R/R6` called the write class "a class this project has not yet suffered" on 2026-09-01; the
project suffered it TWICE within six days -- create-pass forks writing to tracked files despite a
read-only brief (`5-7/R8`, `:9038-9041`). The response was to REPLACE the mechanism, not widen the
check: create and docs-only passes now run with NO subagents at all, for any story. That is
`3-0d/R20`'s move (a guard evaded twice gets its mechanism replaced, not its pattern widened a third
time) applied to process instead of code, and it costs the operator nothing because it removes a
capability rather than adding a rule to police. The dev-prompt correction from the third incident
stands with it: the `5-6` code review ran as a subagent OF THE DEV SESSION rather than as a fresh
session (`:8979-8981`), so a dev prompt ends at the report with HALT and the review runs fresh.
Recorded honestly: **the FIRST instance of the write class appears nowhere in the repo as its own
record** -- it is reachable only through `5-7/R8`'s phrase "the second instance", the same shape as
E4's sixth incident. Zero layer stalls in E5.

`E5-R/R7` (ratified) EVIDENCE CORRECTIONS TO A CLOSED, PUSHED STORY LIVE IN THE RETROSPECTIVE AND
THIS LOG, NEVER AS AN EDIT TO THE STORY FILE. This generalises `5-7/R7` ("a closed story's record is
never edited to stay current") from prose to evidence, and it is why `sprint-status.yaml` and all
twelve story files were untouched by this pass. TWO CORRECTIONS, both found by content:
1. **`5-0b-pad-card-input.md:418` names the wrong golden.** Its Change Log row states "Golden
   `7fbb4b7f...` CONFIRMED unmoved both directions". The golden at that story's own code commit was
   `aa3566d7...` (`git show 7d20317:test/state/test_determinism.gd`); `7fbb4b7f` is TWO
   re-baselines stale. The CLAIM (unmoved) is sound -- `test_state_matches_golden` would have failed
   otherwise -- and only the IDENTIFIER is wrong, in the exact place `PROC/R2`'s Dev Agent Record
   evidence audit exists to check.
2. **`5-6-three-tier-ladder.md:971` cites a review file that never existed.** It names
   `docs/implementation-artifacts/5-6-code-review.md` as the file its fix pass was applied against;
   `git log --all --` returns nothing for that path and it is not on disk.
Neither is repaired in place. Lesson ratified with them: a record can be TRUE and still be WRONG --
the suite catches a real drift, nothing catches a stale identifier in prose, and nothing needs to,
but a reader trusting the number would be misled.

`E5-R/R8` (recorded, not ruled) WHAT E6 INHERITS -- the `E3-R/R5` / `E4-R/R8` template. Recorded at
all because parts of it exist nowhere else. Full evidence in the retrospective, section 7.
1. Two Tier A stories pre-slotted and unauthored: **card-hand tint, the FIRST E6 story** (`E5-C/R5`,
   a second consecutive smoke finding across `5-4` and `5-5`), and **hold-to-charge** (`E5-C/R6`,
   `5-7/R6`) -- state-touching, since an early release needs a `CHARGING` teardown that does not
   exist; early-release semantics are decided at that story's own scope conversation, operator veto
   on the shape open.
2. `R-SPELL`'s forcing point is the E6 close-out, playtest block after it. Three of nine fixture
   cards still carry `spell_*` ids and take the named no-op path.
3. Mode 4 / Pitch Zone is E6's remaining loop: `5-4` exposes `reset_all()` and never calls it,
   `pitch_effect` is UNAUTHORED, and `5-7/R3` made mode PITCH structurally unreachable from the pad
   by construction -- the E6 pitch story must revisit that guard deliberately, not discover it.
4. The `## E5 residue` section (`deferred-work.md:329-366`, `E5-C/R7`) is the durable home for five
   retune entries and four unowned items, including `5-5/R10`'s per-attack-type counter ideas,
   orphaned when the `5-6` scope talk ruled on none of them.
5. Named standing exception to `BC/R3`: as of `5-3/R2`, retuning `unblockable_chargeup_seconds` is
   NO LONGER a one-line `.tres` edit.
6. `5-1a/R14` is owed by the first story that adds an exported build (`Invariant.check` is
   non-load-bearing there EVERYWHERE, not just the one seat `5-1a` fixed); `5-1a/R15` records the
   `camera_pushes` twin left deliberately open.
7. `5-2/R17` is live via `5-5/R4` -- a cast interrupts what is HELD, not what is in flight. A
   `CHARGING` hero still CAN cast a basic card: owner named as `5-6`, untouched there (`5-5/R3`).
   The one inherited item E5 gave an owner and did not discharge.
8. The playtest block gains the two-pad mode-2/mode-3 exchange, NOT RUN in `5-7` (no second pad).
9. `E5-C/R9`'s six operator inputs stay unslotted, of which **walk/run with position and speed as a
   resource is a NEW gameplay system needing an operator ruling at E6 planning**.
No ruling is taken on E6's plan here. A retrospective records what the next planning pass must not
discover late; it does not do that pass's job.

### Close-out

Docs-only pass, three commits, none pushed: `docs(retro)` (the retrospective artifact only), this
entry (`docs(decision-log)`, a PURE APPEND -- no existing entry edited), and `docs(config)` (the
operative half of `E5-R/R2`/`R3`/`R5` amended onto the three existing `project-context.md` Testing
Rules bullets per `PROC/R5`; no bullet added or removed, `rule_count` 71 -> 73 for the two NEW
obligations `E5-R/R2` introduces -- the surviving report artifact and the close-out layer-state
line -- and `Last Updated` moved to 2026-09-07).
`sprint-status.yaml` is NOT touched -- no retrospective key exists. No story file is touched, per
`E5-R/R7`. `CLAUDE.md` is NOT touched -- no tier policy changed here. No code changed, no golden or
suite touched, nothing ran. `E5-R/R1`, `R4`, `R6`, `R7` and `R8` are log-only by design.

Next steps: E6 planning pass, manual and report-only per `E4-R/R5`; card-hand tint is the first E6
story (`E5-C/R5`). The operator reviews the log and pushes.

## Session 2026-09-08 -- E6 planning

The planning pass ran MANUAL and REPORT-ONLY (`E4-R/R5`), with no subagents (`5-7/R8` / `E5-R/R6`),
against `gds-sprint-planning` (ruled unusable for report-only planning, 2026-09-01) and
`gds-investigate` (2026-09-04); their evidence grading and path:line citation discipline were
borrowed, their mechanisms were not. Report at `C:\dev\_e6-planning.md`, the artifact venue
`E5-R/R2` established. Every ruling below was ratified by the operator; where the report proposed
and the operator amended, the amendment is named as such.

`E6-P/R1` -- CORRECTIONS OF RECORD, five, each found by content against the planning prompt.
1. **The Pitch Zone shared-vs-per-player question was logged at `2-6/R9` (`:829`), NOT at the 2-4
   smoke.** The 2-6 smoke's contribution is a different item -- `2-6/R19` finding S4, the anchor
   A/B PLACEMENT reading (`:859`), which says in its own words that it "touches neither".
2. **Mode ④ PITCH on the pad is a no-op BY OMISSION, and the state side is not a stub at all.**
   `GamepadProfile` has no Y field (`src/controllers/gamepad_profile.gd:77`) and
   `GamepadController` reads Y on no line (`gamepad_controller.gd:170-175`, `:310-313`); reaching
   mode PITCH in state is a deliberate CRASH-ON-REACH, `Invariant.check(false, ...)` in
   `_resolve_card_action`'s `_` arm (`src/state/match_state.gd:2371-2374`). What IS a reserved stub
   is `PitchState`: one never-started `TimingWindow` plus `to_snapshot()`
   (`src/state/pitch/pitch_state.gd:8`, `:11-12`).
3. **The GDD did not read the ownership question as open.** `gdd.md:121` stated "Each player owns
   their own Pitch Zone" with a global zone as candidate (a), `gdd.md:264` stated "One card in a
   PLAYER'S Pitch Zone at a time", and the epic table stated "overlap-lockout" flatly, while
   `epics.md:212` called the whole question OPEN. Three confidences in two documents; reconciled by
   `E6-P/R4` rather than left to be discovered mid-story.
4. **Two E6-planning inputs COLLIDE with retune entries that were to stay out of E6** -- the
   chargeup animation against "chargeup unreadable", the defence animation/sound against "defense
   feel reads as the defender did nothing". Reported rather than silently reconciled; resolved by
   `E6-P/R8`(i).
5. **There is no authoring seat for a pitch cost** -- see `E6-P/R9`. Discovered by content, not
   inherited from any prior ruling.

`E6-P/R2` (ratified) THE E6 STORY LIST IS ELEVEN STORIES. Keys are creation order; the board order
is the ruled one and the two are not the same (the `4-3a`..`4-3e` precedent). Board order:
`6-0-card-hand-tint` (B), `6-1-hold-to-charge` (A), `6-1b-chargeup-presentation` (B),
`6-2-pitch-staging` (A), `6-3-pitch-hud` (B, at risk of A), `6-4-pitch-activation` (A),
`6-7-locomotion-gaits` (A), `6-7b-locomotion-presentation` (B), `6-8-camera-freedom` (B, at risk of
A), `6-6-defense-presentation` (B, at risk of A), `6-5-spell-resolution` (A). Tint is FIRST by
`E5-C/R5`; spell resolution is LAST because `R-SPELL`'s forcing point is the E6 close-out and the
playtest block runs after it. THREE stories are new at this pass, not carried from the report's
eight: `6-7`, `6-7b` and `6-8`, created by the operator's rulings `E6-P/R3` and `E6-P/R7`.
Hold-to-charge takes the SECOND slot -- it is independent of pitch, it discharges the one
undischarged inherited item (`E5-R/R8` item 7, the CHARGING-hero-can-cast question `5-6` was given
and did not take), its early-release scope talk is better had early, and its golden re-baseline
lands ahead of the pitch chain rather than interleaved with it. Golden movement PREDICTED at `6-1`,
`6-2`, `6-4`, `6-5`, `6-7` -- one named cause each, the `E3-RG/R2` discipline. `6-2`'s is certain by
construction: `MatchState.to_snapshot()` already carries the `"pitch"` key (`match_state.gd:864`),
so any field `PitchState` gains moves the hash.

`E6-P/R3` (operator ruling, Q1) LOCOMOTION IS TWO GAITS, AND WALK IS THE NEW DEFAULT. Walk is NEW,
slower, free, and the default gait; RUN is the CURRENT speed, a held button, and drains the SAME
stamina bar that attack, roll and deflect already spend (the Elden Ring reference the operator
named). Closing distance therefore competes with defending for one resource. Walk speed and
drain-per-second are AUTHORED AT `6-7`, not here. This SUPERSEDES the `5-3/R6(d)` retune entry
(locomotion speed / walk-as-default / sprint-costs-stamina) -- same ground, now ruled rather than
deferred. Of the report's three shapes the operator took the second (two gaits) over the
recommended first (sprint-costs-stamina on one speed); the momentum-as-a-resource shape is not
taken. Today's build has ONE `move_speed` (`src/state/resources/balance_config.gd:16`), so this is
a genuinely new system and Tier A by the golden clause, not a retune.

`E6-P/R4` (operator ruling, Q2) THE PITCH ZONE IS PER-PLAYER, BOTH ZONES VISIBLE TO BOTH PLAYERS,
STAGING INDEPENDENT -- PROVISIONAL. Both players may hold a staged card simultaneously. Candidate
(a) global zone and candidate (b) overlap-with-lockout (the standing working assumption since the
GDD was written) are NOT taken; the effect is candidate (c), free overlap. The P4 cost is known and
accepted for now -- with both zones live a defender tracks two timers, a colour telegraph, stamina
and spacing at once -- which is exactly why the ruling is PROVISIONAL and the post-E6 playtest is
named as its judge. LOCKED AND UNCHANGED: the pitched card is the ONLY public information; hands
stay private. `gdd.md` reconciled in the same pass (`E6-P/R1` item 3).

`E6-P/R5` (operator ruling, Q3) THE PITCH TIMER IS 20 s, PROVISIONAL, AS AN AUTHORED BALANCE FIELD.
Not a constant, not a hardcoded value; the 20-vs-30 verdict belongs to the post-E6 playtest. The
design-intent blockquote at `gdd.md` is deliberately NOT edited -- its argument (the timer is a
shared deadline and the choice is a feel decision) survives the number being provisionally set.

`E6-P/R6` (operator ruling, Q4) PER-ATTACK-TYPE COUNTER IDEAS GO TO THE POST-E6 PLAYTEST BLOCK,
JUDGED WITH A PAD. `5-5/R10`'s sweep/jump/thrust counters, their ranges and auto-aim were orphaned
when the `5-6` ladder scope talk ruled on none of them and were re-homed as an E6-planning input by
`E5-C/R7`. They expand the combat layer rather than close the loop, so they are OUT of E6 and now
have a named owner for the first time.

`E6-P/R7` (operator ruling, Q6) CAMERA FREEDOM IS SPECIFIED AND SEATED AT `6-8`. Two behaviours:
(a) lock-on cycling must reach ALL live targets INCLUDING those behind the hero -- full 360, not a
front arc; (b) the camera can be UNLOCKED and manually rotated when not locked on. Exact controls
are decided at that story's scope talk. This closes the report's objection that "additional camera
freedom (unspecified)" could not be scoped.

`E6-P/R8` (ratified, with two amendments) THE IMPLEMENTATION RULINGS CLAUDE TAKES. Items 1-8 of the
report's S5 block 1 stand as written: (1) card colour reaches the HUD by riding the EXISTING
`cards_changed` seam wrapper in the runner (`src/main/match_runner.gd:395-398`, the `4-B1`
precedent) -- the HUD never reads `CardDatabase`, which only the runner may (`:522`); (2) the pitch
HUD gets a NEW MEMBER of the observation-seam family (the `connect_orbs_changed` precedent,
`E5-C/R3`), never a second `MatchState` direct-connect -- `E5-C/R2`'s named exception stays at its
one instance (`match_runner.gd:501`) unless the operator rules otherwise; (3) the overlap rule is an
OBLIGATION on `6-2`, not its own story key; (4) keys `6-0`..`6-8`, creation order, not board order;
(5) the chargeup ANIMATION is its own Tier B story, separate from the state-side hold-to-charge --
the `5-2`/`5-3` state-then-presentation split applied again; (6) spell resolution is last, carrying
M5 and M6 (`deferred-work.md:232-233`); (7) tier assignments as tabled, every Tier B provisional on
its measured before/after; (8) the pitch-cost seat is FLAGGED, not taken -- see `E6-P/R9`.
**AMENDMENT (i), operator:** the two retune collisions of `E6-P/R1` item 4 are RESOLVED IN FAVOUR
OF THE E6 STORIES. `6-1b` and `6-6` stay in E6 and discharge "chargeup unreadable" and "defense feel
reads as the defender did nothing" IN PASSING. The standing rule that retune stays out of E6 bars
SLOTTING A RETUNE ENTRY AS A STORY; it does not forbid fixing one an E6 story lands on anyway.
**AMENDMENT (ii), operator:** walk and turn-in-place animations are not a deferred item awaiting the
locomotion ruling -- they are the PRESENTATION HALF of the locomotion system, seated at `6-7b`.

`E6-P/R9` (ratified) THE PITCH-COST AUTHORING SEAT IS A NAMED OBLIGATION ON THE `6-2` SCOPE TALK.
`CardData` carries ONE `cast_condition` shared across all four modes
(`src/state/resources/card_data.gd:40`), `pitch_effect` (`:37`) is UNAUTHORED on all nine fixture
cards (no `pitch` line in any `data/cards/*.tres`), and `CardCastCondition.orb_costs` is empty
everywhere BY DESIGN (`src/state/resources/card_cast_condition.gd:29-35`). So the GDD's Mode ④ cost
of "Mana (higher) + orbs" (`gdd.md:178`) has nowhere to live today. Adding a field is
codebase-shaping under CLAUDE.md's autonomy test, so it is DECIDED AT THAT SCOPE TALK and not by the
implementing pass. UNMEASURED and named as such: what authoring nine cards' worth of Mode-④ content
actually costs. This is the largest unpriced piece of E6.

`E6-P/R10` (operator, recorded) THE MIXAMO WALK CLIPS MUST PHYSICALLY BE IN THE REPO BEFORE THE
`6-7b` CREATE PASS. An operator-owned manual step, recorded because E3 learned it the hard way
(`3-0a`). No story may be created against an asset that is not yet on disk.

`E6-P/R11` (recorded, not ruled) WHAT E6 DOES NOT TAKE, and what still has no owner. The five E5
retune entries stay OUT as ENTRIES (`deferred-work.md` E5 residue), with the two `E6-P/R8`(i)
exceptions and the one `E6-P/R3` supersession. The playtest + melee retune block stays deferred
until AFTER E6; E6's exit feeds it. Already-owned gaps are unchanged: minions stalling on obstacles,
`standard` priority giving a dead arena at 10v10, the AC 11 flicker cause, and the two-pad
mode-2/mode-3 exchange NOT RUN at `5-7` -- all the playtest block's. The operator's "smarter, more
natural minions" input (`E5-C/R9`) is the SAME item as the stall gap and takes its existing owner
rather than a new story. Open decisions (b) reshuffle-window price and (e) hand-size variation stay
with the operator and a pad; (e) INTERACTS with pitch staging, since the staged card still counts
toward the hand of 4 (`gdd.md:262`, `src/state/cards/hand.gd:25`), but is not forced by it. Two
items reach E6 with NO E6 owner and are recorded so they are not read as discharged: `5-1a/R14`
(`Invariant.check` non-load-bearing in an exported build) is owed by the first story that adds an
exported build, and NO E6 story does; `5-1a/R15`'s `camera_pushes` twin stays deliberately open --
note `6-8` touches the camera but not that seat.

### Close-out

Docs-only pass, five commits, none pushed, no suite run, no subagents. `docs(gdd)` (pitch ownership,
timer, the two-gait locomotion seats, the epic-table E6 row); `docs(epics)` (the E6 section rewritten
to the eleven keyed stories plus the obligations block); this entry (`docs(decision-log)`, a PURE
APPEND -- no existing entry edited, per `E5-R/R7`); `board` (`sprint-status.yaml` gains `epic-6:
backlog` and the eleven story keys, lifecycle vocabulary untouched); `docs(deferred-work)` (re-tags
only, pointers not prose). The log commit PRECEDES the board commit, the `5-5` close-out ordering.
No story file is touched -- none exists yet. No code, no golden, no test.

Next steps: the `6-0-card-hand-tint` create pass. The operator reviews the log and pushes.

## Session 2026-09-08 -- 6-0-card-hand-tint close-out

`6-0/R1` (proposed by Claude, ratified) -- PRESENTATION-SIDE CARD TINT MAY READ CardDatabase ON
BOTH THE LIVE AND THE REPLAY PATH, narrower than the runner's old blanket comment claimed. The
HUD-wiring `_derive_card_colors()` call (`match_runner.gd:368`) runs unconditionally, unlike the
`5-2` state-injection call at `:330`, which stays non-replay-only. The invariant that actually
holds: STATE and DETERMINISM never read `CardDatabase` under replay; PRESENTATION does, on the same
footing as the caption, which already renders recorded ids with today's presentation. One
consequence is accepted and documented rather than guarded -- a recorded id absent from today's
database has no colour entry, so its swatch stays hidden while the caption still shows the id.
Nothing in the golden or the replay record depends on the tint, so this is not a determinism
concern. The runner comment at `match_runner.gd:292` is reworded to say this precisely (F-5).

`6-0/R2` -- TEST HARDENING, three findings closed as one ruling. `test_card_tint_live.gd`'s
`_live_tint_correct` flag was initialised `true` and only ever falsified inside a loop an all-EMPTY
hand skips, a vacuous-PASS shape the mutation table did not independently cover (F-1); the test
indexed `Hand.to_array()` slots blind, so a hole in slot 0 or 2 raised a SCRIPT ERROR that
`run_all.sh` reads as a whole-suite failure rather than a test failure (F-2); every assertion
computed its expectation from production's own `ORB_COLORS[card.color]` expression, so a permuted
palette would still pass (F-10). All three fixed in the code-review fix pass: dynamic occupied-slot
selection, a comparison counter, and a hard-coded palette pin, re-proven non-vacuous by the
measured mutation/restore cycle in the story's Dev Agent Record.

`6-0/R3` -- SWATCH GEOMETRY REWORKED against the panel's true 84x92 box; the dev pass's claim that
the swatch "never overlaps" the caption was arithmetically false by 5px (F-3), and the swatch
occluded the top 2px of the armed panel's inward 5px gold bottom border across 86% of panel width,
degrading the armed tell on exactly the slots AC 5 exists to protect (F-4). Both closed by moving
the caption's bottom inset from -4.0 to -13.0 (costing roughly one wrapped line at font_size 12,
ellipsis overrun already configured) and re-deriving the swatch band to y in [80, 86], clearing the
caption above and the armed border's bottom band below by one pixel each. Whether the resulting bar
reads at a glance stays the operator smoke's call (`PROC/R8`), not the arithmetic's.

`6-0/R4` -- DEFERRED: `ORB_COLORS[color as int]` has no upper-bound guard (F-9). Unreachable today
-- three palette entries, three `CardColor` members -- but the failure mode is asymmetric: a `null`
colour degrades gracefully to a hidden swatch, an out-of-domain colour raises index-out-of-bounds
mid-frame inside a signal handler. Recorded in `deferred-work.md`; OWNER is the first story that
touches the `CardColor` enum or the shared `ORB_COLORS` palette, not this one.

### Close-out

Two commits (Tier B precedent, no separate gate pass). Commit 1, code + tests:
`src/main/match_runner.gd`, `src/ui/hud/hud_root.gd`, `test/integration/test_card_tint_live.gd` (+
its `.uid`). Commit 2, docs: story file Status -> `done` (Live Smoke task box checked); board
`6-0-card-hand-tint: ready-for-dev` -> `done`, `# Tier B` comment preserved, `story_notes` updated;
this entry; `deferred-work.md` and `docs/playtest-log.md` (operator's own hand-written entry,
untouched by this pass) ride the docs commit as-is.

Budget interval: dev pass BEFORE suite run (2026-09-08 22:37:16 +0200) to this close-out chain's
suite run end (2026-09-08 23:32:57 +0200), delta 55m 41s. Suite: 720/0/5363 state + 56/56
integration, `ALL TESTS PASSED`, unmoved from the story's own BEFORE/AFTER measurement -- golden and
snapshot key set both confirmed unmoved again by this run.

Operator smoke: PASS 4/4 -- colours read per slot, empty states stay untinted, the armed tell stays
intact alongside tint, and card captions remain legible after the caption-inset rework. Recorded by
the operator's own hand in `docs/playtest-log.md`, 2026-09-08.

Story `6-0-card-hand-tint` is `done`. Nothing pushed; the operator reviews the log.

## Session 2026-09-09 -- 6-1 readiness gate

`6-1/R1` (operator, recorded) EARLY RELEASE BEFORE THE CHARGEUP ELAPSES IS A PAID FEINT. Card and
stamina stay spent; no landing/damage/orb/rung resolution; the telegraph clears; the hero returns to
IDLE and is fully controllable on the release tick. A tap is the identical feint, with no grace
window. No recovery window follows any release. Release after the chargeup completes is a no-op --
the landing resolves normally.

`6-1/R2` (operator, recorded) THE BASIC-WHILE-CHARGING GATE `5-6` SHIPPED STAYS. `5-6`'s own ruling
(`5-6/R3`, decision-log.md:8941-8945) closed the CHARGING-can-cast-BASIC hole; `E5-R/R8` item 7
(:9245-9247) and `E6-P/R2`'s repetition of the same claim (:9311-9313) are RECORD ERRORS, corrected
here without editing either pushed entry (standing meta-rule -- pushed/ratified text is never
edited). `match_state.gd:2426-2428` is not touched by `6-1`; `test_a_charging_hero_cannot_cast_basic`
stays green, unedited, and joins the standing guard list.

`6-1/R3` AUTHORED CHARGEUP IS 1.0s = 60 DERIVED TICKS (`balance_ticks.gd:142`), not 24. The story's
"24" was `test_unblockable_initiation.gd`'s own fixture constant, a deliberate `BC/R3` isolation
value, not the authored number.

`6-1/R4` `FORMAT_VERSION` BUMPS 7 -> 8, WITH HARD REJECTION OF v7 RECORDS. Not forced by the
serialization shape (a `held` key round-trips generically with no edits) but by the semantic
incompatibility: an existing v7 recording of a mode (2) cast would silently reinterpret under hold
semantics as an instant feint instead of the landing it originally produced. The dev pass verifies
the round-trip.

`6-1/R5` TEST BLAST RADIUS FOR THE CHARGING-DRIVING HELPERS IS EXACTLY THREE FILES, MEASURED:
`test_unblockable_initiation.gd`, `test_unblockable_defense.gd`, `test_orbs_economy.gd`. The
integration driver (direct `set_action_state`) and the keyboard path are out, by measurement --
`KeyboardController` cannot reach mode (2) at all.

`6-1/R6` MINIMUM OBSERVABLE FEINT IS ONE HELD TICK. A press+release inside one sample interval
produces no edge at all -- no commit, no spend, nothing happened. This is an input-sampling fact, not
a grace window.

`6-1/R7` A FEINT LEAVES AN ARMED MODE (3) DEFENSE WINDOW UNTOUCHED BY CONSTRUCTION. The window
self-expires (advanced unconditionally at `match_state.gd:441-442`) and is consumed only inside
`_resolve_charge_landing`, which a feint never calls. No window-clearing code may be added for the
feint path.

### Close-out

Docs-only pass against the readiness gate report (round 1 of 2, baseline `cf7489b`). Pure append, no
existing entry edited. Two commits: this entry (`docs(decision-log)`); the story fix pass
(`docs(6-1)`, story file corrected per the gate's F1-F10 findings, board `6-1-hold-to-charge`
promoted to `ready-for-dev`). No code, no test, no golden.

Next steps: dev pass on `6-1-hold-to-charge`.

## Session 2026-09-09 -- 6-1 close-out (Tier A)

`6-1/R8` RELEASE SIGNAL IS A HELD DICTIONARY KEY, `card_cast` -- the `BLOCKING` precedent
(`match_state.gd:944-946`), not a new typed field. `InputIntent` is unchanged, zero lines. The
token names no pad button; it is the codebase's own existing cast-refusal label
(`reject_action(&"card_cast", ...)`), so no new vocabulary enters the system.

`6-1/R9` THE L3 CHORD FORK: THE HOLD READS B ALONE, NEVER CONJOINED WITH L3. Releasing the arming
modifier (`cast_button`) never destroys an already-paid attack -- L3's whole job is `armed_slot`,
finished the instant the commit fires. Conjoining would let letting go of the modifier the player
has most reason to release destroy a paid chargeup. Pinned directly by
`test_resolve_card_tick_reports_the_unblockable_confirm_as_held`, mutation-proven against the
rejected fork (mutation D).

`6-1/R10` (ratified dev deviation) `test_charge_telegraph_dispatch_live.gd` IS INSIDE THE BLAST
RADIUS -- the story's finding 4 excluded it correctly at the rule but wrongly at the exclusion
list, applying "every call site that drives CHARGING past its first tick" to entry points only.
Fixed at the input seam with a `HoldingController` stand-in on P1 for the measured frames; P2 keeps
its real controller, so the file's cross-slot claim is untouched.

`6-1/R11` (ratified dev deviation) AC 6's "UNEDITED" CLAUSE IS AMENDED TO ASSERTIONS, NOT FIXTURES.
The gate at `match_state.gd:2426-2428` and every assertion in every affected test stay
byte-identical; three fixtures in `test_unblockable_defense.gd`
(`test_a_charging_hero_cannot_cast_basic`, `test_a_charging_hero_cannot_cast_defense`,
`test_the_basic_cast_state_gate_precedes_the_empty_slot_gate`) now state the hold on the commit
tick, because that is live-play truth -- B stays down while A or X is pressed.

`6-1/R12` (review MED-1, accepted as correct) A PAD DISCONNECT MID-CHARGEUP READS AS ALL-BUTTONS-
RELEASED AND FEINTS AT FULL COST. Consistent with `BLOCKING`'s own disconnect semantics; a replay
driven past its recorded end is the same class of case. No code.

`6-1/R13` (review MED-2, accepted as correct) SAME-TICK RELEASE + RECOMMIT OF ANOTHER MODE IS AC 4
WORKING AS RULED, NOT A BYPASS. The hero is free on the release tick, including for a cast; the
gate's own condition genuinely ended in step 3. No code.

`6-1/R14` `FORMAT_VERSION` BUMPS 7 -> 8, HARD REJECTION OF v7, EXECUTED PER `6-1/R4`. Both halves
measured: the shape forces no bump (a `held` key round-trips generically, zero serialization
edits) but a v7 recording of a landed mode (2) cast would replay as an instant feint under the new
semantics -- hard rejection, no migration shim, per the `4-1/R1` family reasoning.

`6-1/R15` (operator smoke) LIVE SMOKE 6/7 PASS ON ONE PAD; ITEM 5 NOT EYE-JUDGEABLE TODAY. The
release-on/after-the-landing-tick boundary is machine-pinned
(`test_a_release_on_the_landing_tick_itself_still_lands`, mutation B) and does not rest on the
smoke pass to prove it. The operator observed the chargeup ANIMATION finishing before the authored
1.0s window expires, so an apparently-late release is state-wise still early and feints correctly.
NAMED FINDING for `6-1b`: the chargeup clip under-runs the authored window.

LOW dispositions, one line each: the BEFORE-baseline integration count's "55" was a transcription
typo against its own cited file, corrected to 56 in the story file's dev pass; the v7-divergence
pair's "identical streams" phrasing was loose (the two tests differ in length) and is corrected to
"identical per-tick `card_slot`/`card_mode`/`card_commit` values"; the three-file helper-name
duplication (`_holding()` in each of `test_unblockable_initiation.gd`,
`test_unblockable_defense.gd`, `test_orbs_economy.gd`) is accepted per the sibling
`_unblockable_intent()`/`_run_chargeup()` precedent already duplicated the same way across those
same three files.

### Close-out

Four commits, order C1 -> C2 -> C3 -> C4 (docs precede board, per `E5-R/R3` -- the promotion grep
requires the log to already name the story). Commit 1, code + tests: `src/state/match_state.gd`,
`src/controllers/gamepad_controller.gd`, `src/systems/record_file.gd`, and the seven modified
`test/` files (one new, `test_unblockable_hold.gd`). Commit 2, docs: the story file's Status ->
`done`, Live Smoke Results section, two Dev Agent Record corrections against the review report.
Commit 3, docs: this entry. Commit 4, board: `6-1-hold-to-charge`: `ready-for-dev` -> `done`, `#
Tier A` comment preserved.

Budget interval per `E5-R/R3`: suite files 11:46:52 -> 12:08:49 (21m57s), plus the review run
(report at `C:\dev\_61-review.md`, outside the repo).

Suite: 735/0/5430 state + 56/56 integration, `ALL TESTS PASSED`. Golden `d5bcb7e6...` and the
30-key snapshot set both confirmed unmoved, per the story's own measured prediction.

Nothing pushed; the operator reviews the log.

Next steps: `6-1b-chargeup-presentation` (the named `6-1/R15` finding is its first item).


## Session 2026-09-09 -- 6-1b close-out (Tier B)

`6-1b/R1` (citing entry, corrects `6-1/R15` without editing the pushed log) THE `6-1/R15` FINDING
WAS READABILITY UNDER-RUN, NEVER A TICKING-RATE BUG. `6-1b`'s create pass measured the true cause:
uniform `custom_speed` compression front-loads the swing so the clip's own strike beat lands well
before the authored window expires, independent of tick timing. The state-side boundary `6-1/R15`
observed against was already correct; only the presentation under-ran.

`6-1b/R2` STRIKE-FRAME CRITERION = THE LAST MAJOR REACH MAXIMUM AFTER PEAK SWING SPEED, NOT GLOBAL
MAX REACH. Global max reach is the wrong proxy for a multi-phase clip: `jump_attack`'s global
maximum (1.0870 @ t=1.2375, 34% of the clip) is the sword at the airborne apex, not the ground-
impact swing, confirmed by the operator's round-1 finding (hold mid-air, never lands). Corrected
to the reach peak at t=2.1542 (0.7038 m), the first clear local maximum after the post-apex
descent. `swipe`/`thrust` are single-phase and unaffected by the correction (global max reach
already equals the impact criterion's answer for both).

`6-1b/R3` (operator ruling) AC 3 IS RATIFIED AS SHARED MECHANISM + PER-CLIP PARAMETERS. One pure
function, `charge_playhead_seconds`, satisfies "same mechanism, no per-clip special case"; only
its knob VALUES vary per colour (`_CHARGE_HOLD_KNOBS`). Promoting the fix pass's shared
`HOLD_START_PROGRESS`/`HOLD_END_PROGRESS`/`HOLD_PLAYHEAD_FRACTION` constants to a per-colour
dictionary is therefore still "the same mechanism" for AC 3, not a drift into per-clip special
casing.

`6-1b/R4` THE HELD BEAT HOLDS ON A SINGLE FRAME, NOT A SLOW CRAWL. Chosen for the simpler,
unambiguous "paused" read against the Open Questions' second option, whose crawl rate risked
reading as a stutter/glitch rather than a deliberate hold.

`6-1b/R5` THE COUPLING-TO-AUTHORED-DUTY IS DISCHARGED BY CONSTRUCTION, NOT REPLACED BY AN
EQUIVALENT GUARD. Retiring `CHARGE_CLIP_SPEED`/`CHARGE_ALIGNED_CHARGEUP_SECONDS` retired
`test_the_charge_clip_speeds_still_describe_the_authored_chargeup` with them (a guard over dead
constants is the vacuous-guard class this project rules out) rather than leaving it in place.
The new mapping takes unitless progress, never a duration, so no animation-side constant derives
from `unblockable_chargeup_seconds` any more; `test/integration/test_charge_playhead_live.gd`
proves the claim live, off the actual authored `unblockable_chargeup_ticks`, and keeps passing
across a chargeup retune instead of turning red and demanding a re-derivation.

`6-1b/R6` FINDING-4'S ORDERING HAZARD CLOSURE IS STRUCTURAL. `HeroState.set_action_state` flips
`action_state` synchronously inside `advance()`; the seam signal that fires
`AnimationController.on_action_state_changed`'s cut to `idle` is only queued there and drains
later the same frame. `_push_charge_progress` reads the synchronous field, so on the exact tick a
chargeup ends (landing or early release) it already sees the new state and pushes nothing for
that slot -- a stale push cannot reach `on_charge_progress` on that tick at all, triple-traced in
review (the seam ordering, the synchronous write, and the live regression pin).

`6-1b/R7` REVIEW'S 3 LOW FINDINGS ACCEPTED AS RECORDED NOTES, NO FIX TAKEN. Guard-scope test
coverage, the exact-1.0-vs-last-real-tick cosmetic gap at window end, and the `EPS 0.02` tolerance
choice are all accepted as-is; none change behaviour worth a code change against this story's
scope.

`6-1b/R8` (operator feel lesson, recorded for future retunes) A SMALL `hold_fraction` REQUIRES A
LOWER `hold_end` OR THE STRIKE READS AS BLUR. Observed converging round 2's final triples: RED and
BLUE both pair a low `hold_fraction` (0.15/0.17) with an early `hold_end` (0.45/0.55) so the fast
close from the held pose to the strike frame has a short enough span to read as a clean strike
rather than a smear.

`6-1b/R9` FEEL TUNING REOPENS ONLY WITH THE FULL GAMEPLAY LOOP. The round-2 hand-tuned triples are
this story's close, not a final ruling on feel in isolation -- retuning `_CHARGE_HOLD_KNOBS`
again is expected once the full gameplay loop (not solo charge-clip smoke) is playable, and is
scoped to a future retune-block pass, not this story reopening.

Named successor: `6-1c` (aim/reach/travel + reach VFX) -- scope talk next session.

### Close-out

Three commits, order C1 -> C2 -> C3 (docs precede board would be a fourth commit here, but board
flip rides this same C3 per the operator's compressed chain for this Tier B story). Commit 1,
code + tests: `src/actors/hero/animation_controller.gd`, `src/main/match_runner.gd`,
`test/state/test_balance_authoring.gd`, two new test files
(`test/state/test_charge_playhead_mapping.gd`, `test/integration/test_charge_playhead_live.gd`),
`tools/measure_charge_strike_frames.gd`. Commit 2, docs: the story file's Status -> `done`, round-2
Live Smoke Results, and the Dev Agent Record's final hand-tuned triples superseding the fix pass's
starting values. Commit 3, docs: this entry, `docs/playtest-log.md`'s 6-1b entry, and the board
flip.

Suite: 737/0/5553 state assertions, 0 failed; 57 integration suites listed, all PASS; `ALL TESTS
PASSED`. Golden and the 30-key snapshot set predicted unmoved (Tier B clause) -- not re-measured
in this close-out pass beyond the full-suite run above (no `src/state/` file touched, confirmed by
`git diff --stat -- src/state/` empty at C1).

Final tuned knob triples (operator hand-tuning, round 2, superseding the fix pass's starting
values): RED (swipe) `hold_start = 0.30`, `hold_end = 0.45`, `hold_fraction = 0.15`; BLUE (thrust)
`hold_start = 0.40`, `hold_end = 0.55`, `hold_fraction = 0.17`; GREEN (jump_attack)
`hold_start = 0.40`, `hold_end = 0.55`, `hold_fraction = 0.5744`.

Nothing pushed; the operator reviews the log.

Next steps: `6-1c` (aim/reach/travel + reach VFX) -- scope talk next session.

## Session 2026-09-10 -- 6-1c readiness gate

`6-1c/R1` (closes B1) AC 1 NAMED THE WRONG TARGET. Corrected to name the auto-aimed ENEMY HERO
(via `_charge_reach_dirs`), OVERRIDING this slot's general lock (`5-2` Ruling 3/Ruling 8) rather
than tracking "the locked target." The regression pin must cover the locked-onto-a-minion case,
since the hero-to-hero case alone cannot prove the override.

`6-1c/R2` (operator ruling; closes B2) THE VISIBLE STRIKE MUST LAND ON THE TICK DAMAGE ACTUALLY
RESOLVES, NEVER BEFORE. The strike swing plays DURING the launch: the chargeup window keeps
mapping to the pre-strike portion of the clip, and a new launch progress channel carries the
swing to the strike frame at resolution. `animation_controller.gd` is withdrawn from "NOT expected
to change" -- it is in scope. New AC 11 states the honesty rule as a verifiable claim; AC 9 and
Measured Fact 7 now cover the launch channel against the `6-1b/R6` tick-ordering contract. The
mechanism (whether travel plays under the strike swing or under a follow-through) stays a
dev-pass Open Question; the honesty rule itself is not.

`6-1c/R3` (closes B3) MODE (2) LANDING ADOPTS THE EXISTING 1-8 CONTACT-FACT SHAPE, UNCHANGED, FOR
BOTH ATTACK PATHS. The runner computes the per-colour radius KIND from positions and pushes the
planar direction fact from positions only -- it never reads `HeroState.facing`. The arc
comparison is STATE policy, performed against the frozen committed direction (AC 2) using the
per-colour authored arc field. No carve-out to the 1-8/R-B3 comment (`match_runner.gd:1680-1684`)
is needed. The committed-direction STORAGE question stays open for the dev pass.

`6-1c/R4` (closes B4) R-D6 SMOKE ACCEPTANCE RE-INVOKED AT THIS GATE. Flip `[0,3]` is
KEYBOARD_P1 + GAMEPAD on slot 1, a killable human-driven slot, so the standing rule
(decision-log.md:456) fires. The residual defects R-D6 originally accepted are fixed and shipped
since story 2-3 (`match_state.gd:3308-3310`), so the substantive acceptance is moot -- but the
binding editor-collateral revert procedure is restated verbatim in the story's Live Smoke section
and remains binding for this and every future killable-human-slot smoke.

`6-1c/R5` (closes B5) BOARD FORMATTING AND STORY-NOTE LENGTH CORRECTED TO MATCH NEIGHBOURS. Two
spaces before `# Tier A`; `story_note` trimmed from a four-sentence close-out-length note to the
one-sentence backlog house style.

### Close-out

Docs-only pass against the readiness gate report (round 1 of 2, baseline `c7676b3`). Pure append,
no existing entry edited. One commit: story file (AC/Fact/Live-Smoke/Dev-Notes corrections per
B1-B5 + N1-N5), `sprint-status.yaml` (board line + story_note), and this entry, together
(docs-only). No code, no test, no golden. Story Status stays `authored` -- promotion is a
separate later step.

Next steps: operator review of this fix pass; a second readiness-gate round if further findings
surface, else promotion to `ready-for-dev`.

## Session 2026-09-10 -- 6-1c re-gate round 2 fixes

`6-1c/R6` (citing entry; clarifies R2's trailing sentence) THE STRIKE-VS-FOLLOW-THROUGH BINARY IS
SETTLED BY R2'S HEADLINE, NOT OPEN. The strike swing plays during the launch, arriving at the
strike frame on the resolution tick -- that shape is ruled, not optional. Only the MECHANISM by
which the launch progress channel is extended past the chargeup window to land progress 1.0 on
that tick is the dev pass's to choose.

`6-1c/R7` Co-Authored-By TRAILER CONSTANT RE-RATIFIED AS "Claude Sonnet 5 <noreply@anthropic.com>".
This matches the shipped house pattern of the last several commits and supersedes the earlier
"Claude Opus 4.8" constant note from the round-2 re-gate. Pushed history is never rewritten to
match; this governs new commits only.

### Close-out

Docs-only pass against re-gate round 2 findings RO1/RO2. Pure append, no existing entry edited.
One commit: story file (Open Questions + Project Context Rules + AC 5 corrections) and this
entry, together (docs-only). No code, no test, no golden. Round 2 of the readiness gate is spent;
no third full gate is required for this micro-fix pass.

## Session 2026-09-12 -- 6-1c close-out

`6-1c/R8` (closes review finding D1) THE SWING/COMMIT PARTITION IS ACCEPTED AS-IS FOR THIS STORY,
COMMENT CORRECTED, NO MECHANISM CHANGE. The strike swing begins at the `hold_end` knob, which
falls inside the feintable chargeup for every authored colour (measured at the commit frame: RED
~64%, BLUE ~49%, GREEN ~31% of the swing already played) -- not at the chargeup/launch boundary
the code comment claimed. AC 11's verifiable claim (the strike frame never arrives before the
landing tick; no frozen glide) still holds regardless, so no mechanism change is owed here.
Anchoring the swing start to the commit (chargeup -> `[0, hold_end]`, launch -> `[hold_end, 1]`)
is offered as a SMOKE-TIME OPTION to the successor story (`6-1c/R10`), not built now.

`6-1c/R9` (closes review finding D2) THE R-A DEFENSE BOUND WIDENS TO CHARGEUP + THE LONGEST
AUTHORED LAUNCH SPAN. The landing is now chargeup + launch(colour), so a window that only
outlasts the chargeup can expire before a slower colour's launch lands even when opened on the
telegraph's first tick. `test_balance_authoring.gd`'s R-A assertion now reads
`defense_window_seconds > unblockable_chargeup_seconds + max(unblockable_launch_seconds_*)`,
pinning the relation against the authored triplet, not a literal (keeps `BC/R3` tuning
isolation). Authored values hold by the same 0.05 s margin as before (1.5 > 1.0 + 0.45).

`6-1c/R10` SUCCESSOR STORY OPENED: `6-1d-honest-hit-geometry`, Tier A, ordered BEFORE `6-2`.
Carries three items surfaced by live smoke and the code review, not fixed in this story: (a)
landing reach derived from MEASURED geometry at the strike frame (blade tip + target body radius)
instead of the authored centre-to-centre radius -- damage only on real model contact (smoke items
1/5/7, one defect); (b) GREEN's homing moved mostly into the airborne phase, travelling less on
landing, for a more natural read (operator, live smoke); (c) swing-start-at-commit (`6-1c/R8`,
deferred here) offered as a smoke-time option -- build the knob, operator rules at that story's
smoke. Reach and homing-speed numbers are NOT raised before (a) lands: widening reach on
centre-to-centre geometry would amplify the exact defect (a) removes.

`6-1c/R11` RETUNE-BLOCK OBSERVATIONS FROM LIVE SMOKE, NO OWNER YET. Operator, smoke 2026-09-11
(`docs/playtest-log.md`): dodge stamina cost should exceed unblockable initiation cost (dodge
currently reads too cheap relative to what it negates); dodge/roll coverage now reads generous;
per-colour reach and homing speed are to be raised only AFTER `6-1d` lands (see R10's closing
sentence -- raising them first would amplify the geometry defect that story removes).

`6-1c/R12` DEFERRED REVIEW FINDINGS, UNOWNED, CANDIDATES FOR A FUTURE E6 CLOSE-OUT. P6: launch
travel (`match_state.gd:3644-3649`, distance / seconds) is exact only because the authored spans
are tick-aligned; a retune to a non-tick-aligned span (e.g. 8.0 m over 0.41 s) would travel 8.13 m
and could fail the live test's `far` case, which is operator tuning requiring a suite edit against
the standing knob-isolation rule -- the unambiguous fix is deriving speed from the tick span
(`distance / (launch_ticks / TICK_HZ)`), a `src/state/` change belonging to a dev pass with its
own suite run, not a review fix. D3: launch distance and seconds are not audited as a pair --
distance > 0 with seconds 0 silently zeroes travel, seconds > 0 with distance 0 roots the hero for
a frozen pause of the launch span; only `>= 0` is checked today, and whether a zero launch stays a
legal authored shape is a tuning-semantics call for whoever picks this up.

### Close-out

Close-out pass after operator live smoke (`docs/playtest-log.md`, 2026-09-11 entry) and the
code-review report (`C:\dev\_61c-review.md`, review commit `2921b1e`). Two commits ahead of this
one: `test(6-1c)` (D2 bound widened, D1 comment corrected, suite 757/0/5993 + 58 re-run clean) and
this docs commit (story file Dev Agent Record / Live Smoke Results / Change Log sections, this
entry, `sprint-status.yaml`) -- pure append here, zero deletions. Promotion to `done` is a
separate, later commit.

## Session 2026-09-12 -- 6-1d readiness gate

`6-1d/R1` MECHANISM NARROWED. Melee has been bone-honest since 5-0a: the Hitbox shape is written
onto the sword bone every tick and melee resolves contact via `get_overlapping_areas()` against
the defender's Hurtbox. Mode (2) is the ONLY damage-crediting family still on an authored
centre-to-centre radius. The mechanism: let the EXISTING overlap query run during the committed
launch phase and derive the INSIDE/OUTSIDE kind from the overlap instead of
`planar.length() <= reach`. The A/B blade-source fork and the body-radius problem (old Open
Questions / old Fact 5) are STRUCK -- an authored blade curve is a second source of truth against
a shipped mechanism melee already trusts, and the Hurtbox box IS the body geometry, no derived
constant needed. Fact 4's "no shared seat between attack families" reasoning conflated GATHER
with RESOLUTION and is withdrawn (`6-1c/R3` and `1-8/R-B3` govern what crosses the seam, not who
measures); its valid residue stays: `is_hitbox_active()` is melee-owned and must not grow a
CHARGING branch, the launch-phase query needs its own gate. `_resolve_charge_landing` remains the
one landing seat, ladder unchanged. AC 4/AC 5 (per-tick evaluation, one resolution per swing per
target) are the real work and stay as authored.

`6-1d/R2` CONTACT WINDOW OPENS AT COMMIT, NEVER DURING THE FEINTABLE CHARGEUP, even though the
blade is visibly in motion there (measured at `6-1c`: commit-frame swing progress RED ~64%,
BLUE ~49%, GREEN ~31%). An attack the attacker can still cancel never credits damage -- a named
behavioural guarantee in the ACs, not a Dev Note.

`6-1d/R3` `6-1c` AC 3 IS SUPERSEDED, EXPLICITLY. Continuous contact means a dodge after commit is
no longer an automatic escape: the defender must clear the blade's path for the WHOLE flight, not
merely be outside an authored radius on the window-close tick. AC 6 stays (clearing the path every
evaluated tick still MISSES) as the surviving half of `6-1c`'s guarantee, reworded rather than
restated. This ratifies the design choice behind readiness-gate finding A1 (dodge-after-commit
semantics) rather than leaving it to the dev pass.

`6-1d/R4` AC 7 STRUCK; `6-1c/R10(b)` DELIVERED PROPERLY. Continuous sampling changes WHEN a hit
is detected, not how far the hero travels. (b) is delivered as a per-colour front-loaded travel
profile across the launch span (more distance covered early/mid-airborne, less on the landing
tick), GREEN the named subject. Since `_charge_launch_velocity` is being rewritten anyway, P6 is
ADOPTED in the same edit: derive launch speed from the TICK span, not
`launch_distance / launch_seconds`. HALT CONDITION: if the travel profile needs a new hashed
snapshot field or any change to `landing_window`'s tick contract, the dev pass halts and (b) is
deferred rather than grown.

`6-1d/R5` AC 2 NARROWED to `6-1c/R10`'s actual subject: per-colour REACH and HOMING SPEED only.
Arc, launch distance, and launch seconds are EXEMPT (R4 requires moving the latter two). AC 2
must be proven by a TEST -- a configuration geometrically reachable but outside authored
reach/homing speed MISSES -- not only a diff against `balance_config.tres`.

`6-1d/R6` SWING-AT-COMMIT KNOB gets its own AC, moved out of Non-Goals: the field exists, default
OFF, OFF reproduces today's behaviour. Live Smoke item 6 keeps the ON-vs-OFF verdict; the knob is
built, not decided, in this story.

`6-1d/R7` GATE FINDINGS S4 AND S5 REFUTED, ABSORBED. S4: contact facts are RECORDED and replay
supplies them from the record (`match_runner.gd:78-82`, `:1723-1726`) -- a clip swap affects live
play only, not a new determinism class; melee precedent 5-0a. Collapsed into one Dev Note; the
seek-determinism argument old Fact 2 carried is dropped as unneeded. S5:
`test_hitbox_follows_bone.gd` instantiates `hero.tscn` headless with real frames and measures
blade world position to 0.5 mm -- AC 1 is machine-provable, no smoke-only status.

### Gate disposition

Round 1 verdict NOT READY, four blockers (B1/S1 -> R1, B2/S2a + B3/S2b -> R4/R5, B4/S3+A1 ->
R6/R3), all closed by this pass. Notes: N1(S4)/N2(S5) folded into R7; N3 (Fact 2's overstated
"uniformly tick-fresh" claim) resolved by dropping the seek argument per R7; N4 (the existing
dedupe primitive fails on LIFECYCLE grounds -- no `_start_swing` call and no `active` window to
reap the grace record for a CHARGING landing, not the ladder reason originally named) and N5
(`swing_dedupe` is already a hashed key nested in the hero snapshot, so extending an existing
record moves no snapshot key) carried into the story's Open Questions and Golden Prediction; N6
(two mis-cites -- `register_swing_hit` is `hero_state.gd:291`, not `match_state.gd:1839-1845`;
`HurtboxShape` is `hero.tscn:100-101`, not `:103-104`) corrected in place; N7 (AC 11 is a process
statement) moved to Golden Prediction, ACs renumbered; N8 (AC 2 needs a test, not a diff) folded
into R5.

### Close-out

Docs-only pass, one commit: story file (rulings R1-R7 applied, ACs renumbered, Open Questions
narrowed, mis-cites fixed) and this entry, together. Story Status stays `authored` -- promotion
to `ready-for-dev` is a separate pass. No code, no test, no suite run.

## Session 2026-09-13 -- 6-1d review fix pass

Findings: `C:\dev\_61d-review.md` (code review of `e7afe21`/`d7f5b28`, verdict CHANGES REQUESTED).
Rulings ratified by the operator in the fix-pass prompt; recorded here so every label cited in code
and story comments has a home.

`6-1d/R8` THE ARC IS JUDGED AGAINST THE BEARING AT THE MOMENT OF CONTACT (closes HIGH-1). The dev
pass made the charge-reach verdict absorbing but left the arc reading the every-push direction, so
the landing ANDed a verdict from one tick with a bearing from another. The bearing is now latched in
the same `push_contact` arm that latches `INSIDE` (new unhashed per-slot store
`_charge_contact_dirs`, classified in `test_replay_identity.gd`'s `UNHASHED_CROSS_TICK`), and
`_is_in_charge_arc` reads it. `_charge_reach_dirs` keeps being written every push for the CHARGING
facing track, unchanged. The arc stays a conjunct that can only REMOVE a hit. Consequence: AC 6's
supersession is fully delivered in live play -- a defender touched mid-flight who then leaves a
narrow arc is hit; a touch taken outside the arc is not credited by drifting in. Proven both
directions on a narrow-arc colour.

`6-1d/R9` THE LATCH'S CLEARING IS OWNED, NOT EMERGENT (closes MEDIUM-1 and the round-over/reset
leak). The verdict and its bearing are cleared at the cast seat and in `_reset_player`; no
`chargeup_ticks >= 2` authoring assert. `_push_charge_reach_facts` pushes nothing during the
round-over freeze. The `C == 1` cross-arena free hit is proven dead by test.

`6-1d/R10` THE LAUNCH INDEX COMES FROM THE WINDOW (closes MEDIUM-3). Launch span and tick index are
derived from the running windows' snapshotted durations, not a live `balance_ticks` read, leaning
on `TimingWindow`'s hot-reload guarantee instead of adding a refusal. AC 7's arithmetic re-proven,
including across a mid-flight span retune.

`6-1d/R11` TEST-ONLY REPAIRS (closes MEDIUM-2 and LOW-2c). The live fixture heals P2 in `setup`;
the `clamp` case asserts `_contact_ticks > 0`.

`6-1d/R12` THE SEVEN LOWs. Apply the one-line correctness/comment fixes; give a one-line reason for
each not applied; no scope expansion. The `hitbox` null-deref LOW is inherited from
`_gather_contact_facts` and is OUT. Dispositions are in the story file's review-fix record.

### Dev notes against the rulings (for operator confirmation)

- R8's count: `UNHASHED_CROSS_TICK_MEMBERS` kept at 3. MEMBERS counts arguments (`4-6/R6`), and
  the new store joins argument (c) as `_charge_reach_dirs` did at 5-2.
- R8, several contact ticks: the bearing re-latches on every `INSIDE`, so the last contact's bearing
  is judged. First-contact latching was the alternative; it is a design seam, left for Matko.

### Close-out

Two commits: `story 6-1d: review fixes (rulings 6-1d/R8-R12)` (code + tests) and
`docs(6-1d): review fix record` (story file + this entry). Suite 769/0/6251+59 -> 774/0/6293+59.
Golden NOT MOVED (`9679fa80`). Story Status stays `review`; board untouched (CFG/R2). Not pushed.

### Review fix pass 2 (ruling `6-1d/R13`)

`6-1d/R13` AN IN-ARC CONTACT IS ABSORBING; A LATER OUT-OF-ARC CONTACT NEVER OVERWRITES IT (resolves
the R8 dev note above). Neither "first contact" nor "last contact" is the rule: if ANY contact tick
of the committed flight had a bearing inside the colour's authored arc, the landing is a HIT; the
arc can still only REMOVE a hit, so a flight whose contacts were ALL out of arc still misses. In
`push_contact`'s INSIDE arm the verdict and bearing are latched unless the verdict is already
`INSIDE` and the latched bearing already passes `_is_in_charge_arc`. The arc is only ever evaluated
for the bearing ALREADY latched, on a later tick, never for the push being latched -- the commit
tick has nothing latched (R9's cast-seat clear) and every later tick sees the frozen facing (6-1c).
No new store (`_charge_contact_dirs` reused); golden predicted and measured NOT MOVED.

Three 6-1c headless fixtures are R3-superseded, not collateral: they reported an INSIDE contact dead
ahead on the commit tick, which R3 makes a real in-arc touch. Each now pushes OUTSIDE through the
commit tick and INSIDE only from the sidestep on, keeping the claim that with the only contact off
the line the arc decides: `test_a_defender_who_leaves_the_frozen_line_after_the_commit_is_missed`,
`test_each_colour_judges_its_own_arc_against_the_committed_direction`,
`test_the_colour_counter_still_answers_through_the_one_landing_seat`.

Dev note (for operator confirmation): measured, the commit tick's push does not re-aim the facing
(step 2 closes the chargeup before `_resolve_movement`); the rule does not depend on it.

Two commits: `story 6-1d: in-arc contact is absorbing (6-1d/R13)` (code + tests) and
`docs(6-1d): R13 record` (story file + this entry). Suite 774/0/6293+59 -> 777/0/6305+59.
Story Status stays `review`; board untouched. Not pushed.

## Session 2026-09-13 -- 6-1d close-out

Review LOW touch-ups closed (`C:\dev\_61d-review2.md`, LOWs B/D/E), then a live smoke run against
the story's ACs on the operator's own pad. Findings and log: `docs/playtest-log.md` (13.9. entry).

`6-1d/R14` LIVE SMOKE PASS on the story's ACs. Items 1/2 PASS (damage only on real contact, the gap
defect is gone); 6/7 PASS (regressions clean, fps stable).

`6-1d/R15` SWING-AT-COMMIT KNOB STAYS OFF. ON had NO observable effect on GREEN. Cause CLASSIFIED,
not guessed: the knob is wired and non-degenerate (GREEN `hold_end 0.55` in
`_CHARGE_HOLD_KNOBS`), but GREEN's held pose sits at `hold_fraction 0.5744` of the clip -- already
airborne -- so re-timing WHEN the hold plays cannot move the takeoff out of the chargeup. The fix
is a clip knob (a held pose BEFORE the takeoff), owned by the retune block, not this story.
RED/BLUE under ON were not judged.

`6-1d/R16` RETUNE BLOCK, UNLOCKED. `6-1c/R10`'s hard constraint ("no reach or homing number before
(a) lands") is DISCHARGED -- (a) landed. Handed to the retune block (post-E6, per the 30.8.
ruling), no owner yet: (i) homing range reads small; reach and homing speed retune TOGETHER; (ii)
dodge after commit still escapes easily -- dodge stamina must cost more than initiating an
unblockable, unblockables want a little more reach (`6-1c/R11` restated with the smoke evidence);
(iii) GREEN should cover ~2/3 of its travel by the apex -- AC 7's front-loaded profile did not read
that way because the takeoff is in the chargeup (R15); needs the clip knob first, then the profile
re-judged.

`6-1d/R17` E6 CLOSE-OUT CANDIDATES, no owner: review2 LOW-A (arc hot-reload mid-flight), LOW-C
(`_charge_reach_dirs` never cleared; a one-tick chargeup has no aim tick -- predates 6-1d, no
config uses it, the real question is what aiming in zero ticks means), LOW-F (no replay test for
`_charge_contact_dirs`), C5 (runner's round-over gate deep-copies a snapshot to read one bool, and
`.get("round_over", false)` silently disables the gate on a key rename), and CLAUDE.md's trailer
line disagreeing with `6-1c/R7` (repo wins; align CLAUDE.md). D3 and F-9 remain deferred,
unchanged.

Also recorded: R-D6 SPENT again on this smoke; the suite counters from the LOW touch-up pass
(777/0/6305 + 59 integration, ALL TESTS PASSED, EXIT=0, golden `9679fa80` unmoved).

### Close-out

Three commits: `story 6-1d: review LOW touch-ups` (code + tests), `docs(6-1d): playtest-log +
close-out record` (playtest-log + story file + this entry), and `docs(6-1d): promote to done`
(status/board promotion). Suite unchanged in count by the docs commits (777/0/6305+59 stands).
Story Status `review` -> `done`; board -> `done  # Tier A`. Pushed to `origin/main` on operator
confirmation of the log.

## Session 2026-09-13 -- 6-2-pitch-staging readiness gate outcome

Docs-only gate-fix pass on `6-2-pitch-staging`, promoted `authored` -> `ready-for-dev`. No source or
test file touched -- the ACs below describe what the dev pass builds.

Hand ruling and its conservation consequence: staging vacates the hand slot through the SAME
`hand.remove_at()` hole a cast produces, but does NOT append to `pending_draw_owed` at staging --
the replacement is owed only when the card leaves the zone, which in this story is fizzle only. The
existing `occupied + owed == hand_size` identity grows a fifth term (`+ staged`), and no existing
test currently exercises it because none stages a card -- a new test closes that blind spot. A
consequence stated plainly: `hand_size` in the snapshot (which binds to `occupied_count()`) reads
ONE LOWER while a card is staged; `epics.md`'s "still counts toward the hand of 4" is satisfied
structurally (the slot is reserved, not dealt into), not by the snapshot number itself.

Mana is paid at staging, with no refund on fizzle -- a card that fizzles takes its mana with it.
READY is derived fresh every tick from live orb affordability, never latched: nothing can make READY
false again once mana is already spent at staging, so no stored flag is needed or authored.

The `pitch_zone` flag opens in `data/feature_flags.tres` THIS story (not `6-4`), per the `5-2/R14`
precedent measured before flipping `unblockable`: no test pins the authored file's values, only
presence, and the flag opening changes no live behaviour until `6-4` wires a reachable path. The
gate itself is MODE-LEVEL, in the pitch resolution arm, the shape modes 2 and 3 already use
(`flags == null or not flags.pitch_zone` -> refuse with the flag-closed reason) -- never delegated
to a per-card `required_flag`, which would make the layer non-toggleable.

Pitch costs are authored, provisionally, on all nine cards: mana equal to that card's own Mode ①
cost, 1 orb of the card's colour on the six 2/3-mana cards, 2 orbs on the three 5-mana totems. A
`.tres` edit alone can retune these; the post-E6 playtest judges the numbers. This removes the
null-cost case from shipped data, but the injection seam still does not `Invariant.check` totality
(a future card with no authored pitch entry stays legal) -- and reaching that case refuses through a
NEW reason constant, never `CastEvaluator.REASON_UNKNOWN_CARD`, whose own header documents it
unreachable by construction (a guarantee this story's injection deliberately does not make).

The new pitch-cost map is a new recorded channel: `FORMAT_VERSION` moves 8 -> 9, a v8 record refused
with a reason and no shim, the `6-1` shape repeated. The mode-reachability guard (narrowed at `5-2`
and `5-5`) is RETIRED rather than narrowed a third time, now that all four `Enums.ModeKind` values
are reachable -- its guard tests are renamed/re-valued, not deleted, the `5-5` renaming discipline.

The orb-clear optional rule (`BalanceConfig` bool, default OFF) is ruled "pitching clears, not the
price clears" -- staging always empties the pool when ON, even for a card whose own cost needs no
orbs, because the clear is keyed to the act of staging. Both branches are test-covered with a named
expected visible effect, and the deadline (post-E6 playtest; losing branch and the bool both
deleted) is recorded where it actually applies.

The cancel exit deferral (named, not silent, in the story's Scope note) is now also recorded as
`6-4`'s committed scope in `epics.md`'s `6-4` line, with a STRONGER reason than the story's own
framing: cancel needs a new `InputIntent` shape (nothing today expresses "abandon what is already
staged"), which is a recorded-input change touching `FORMAT_VERSION` and the replay machinery, not
merely a state transition with no player-triggered consumer yet.

Four gate-premise corrections, measured before ruling on them: `OrbPool.reset_all()` already has one
real caller (`MatchState._reset_player`, the round-boundary reset) and lives at
`src/state/pools/orb_pool.gd`, not `economy/` -- the story's optional rule is its SECOND caller, not
its first. The story's guarded-stub-test citation named a test that does not exist in the repo;
replaced with the three real reachability-guard test names in `test_card_play.gd`. Fact 9 and an
Open Question reopened an already-settled seam-ownership ruling (`E6-P/R8`(2): the pitch HUD gets a
NEW observation-seam member, never a second `MatchState` direct-connect) -- the reopening is
deleted, the Non-Goal stands, the seam-count prediction for this story alone stays at nine. The
Hellburst citation (`gdd.md:207`) was verified correct as authored.

**DOCS DEBT, recorded without fixing:**
- `gdd.md`'s "activates when cost is met" (Mode ④, the cast-condition table) and `epics.md`'s `6-4`
  line's "cost paid" phrasing are both superseded for the MANA half by this story's staging-time
  payment ruling -- neither is edited in this pass (docs and code never share a commit is not the
  reason; the ruling belongs to `6-2`, the wording lives in two OTHER documents this pass does not
  own).
- Three stale source headers, unchanged: `PitchState`'s own "nothing is staged" framing (Measured
  Facts 1/2 of the pre-gate-fix story draft, now false the moment `6-2` lands); the cast-condition
  schema's Mode ① wording ("what Mode ① costs," `card_data.gd:40`, now shares the schema with Mode
  ④ per AC 1); `OrbPool.reset_all()`'s own comment, "E6 resolution calls this," now describes its
  SECOND caller, not a still-future first one.
- The commit-trailer constant: measured, the repo's actual recent trailers read `Claude Sonnet 5`,
  matching this session's own attribution and the story's Dev Notes -- NO disagreement found this
  time. `6-1d/R17` already flagged a SEPARATE, still-open trailer disagreement (CLAUDE.md's own
  `Claude Opus 4.8` line vs. the repo's practice) as an E6 close-out candidate with no owner; not
  re-litigated here, only cross-referenced.

One commit: `docs(decision-log): 6-2 readiness gate outcome` (this entry). Story Status `authored` ->
`ready-for-dev`; board `backlog` -> `ready-for-dev  # Tier A`; `epics.md`'s `6-4` line gains the
cancel clause. Not pushed.
