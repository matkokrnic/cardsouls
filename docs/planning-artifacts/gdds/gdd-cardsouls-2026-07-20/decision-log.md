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
