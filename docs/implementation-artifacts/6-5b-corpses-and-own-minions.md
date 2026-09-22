---
baseline_commit: e7842821ad1fb56a76a758e74f7b3e684cc57a36
---

# Story 6.5b: Corpses and Own-Minion Spells

Status: ready-for-dev

<!-- Tier A. Split from 6-5-spell-resolution by operator ruling (2026-09-22) into six sub-stories
(6-5a..6-5f); this is the second. Depends on 6-5a (done). Golden PREDICTED to move (corpse lifetime
enters state); FORMAT_VERSION 13 -> 14 (Drain's facing fact on the replay tap). Authored 2026-09-22 by
gds-create-story, main session only, no subagents, nothing committed. -->

## Story

As the operator (and later the friends playtest),
I want Grave Ward, Culling, Drain and Raise Dead working end-to-end, with a corpse becoming a real
piece of game state instead of a purely visual linger, and every hand card showing both its normal
and pitch prices,
so that the own-minion/corpse half of Deck 1 is playable and the Culling -> Raise Dead loop actually
works. (6-5f's undo is deferred entirely to 6-5f's own story — 6-5b adds no undo data.)

## Board note

`sprint-status.yaml` key `6-5b-corpses-and-own-minions`, promoted `backlog` -> `ready-for-dev` by the
readiness gate fix pass (2026-09-23; `decision-log.md` session "6-5b scope + readiness gate"). Depends
on `6-5a-spell-framework-and-buffs` (`done`). This story authors ONLY `6-5b`; the other four
sub-stories (`6-5c`, `6-5d`, `6-5e`, `6-5f`) are untouched.

## Repo-verified facts this story is authored against

- Effects are named `.tres` under `data/effects/`, referenced by cards via `ext_resource`; every
  effect number is a flat `@export` on `CardEffect` (`src/state/resources/card_effect.gd`); the
  resolver dispatches on the WHOLE `effect_id` (`src/state/economy/card_effect_resolver.gd`); the
  resolver COMPUTES, `MatchState.advance()`'s ordered dispatch APPLIES (D6).
- `card_effect_resolver.gd:183-198`: `culling`, `grave_ward`, `raise_dead`, `drain` currently resolve
  through `REASON_DECK1_NOT_YET_RESOLVED`, each pointing at this story's own board key
  (`DEFERRED_EFFECT_OWNERS`). This story replaces those four table rows with real outcomes; a unit
  test (`test_spell_framework.gd`) already asserts the deferred table has exactly nine entries and
  will need updating to five once these four are removed.
- `PlayerState` (`src/state/player_state.gd:259-386`) already owns a per-player timed-rule seat: six
  slots (`RULE_BLOODLUST=0` .. `RULE_FROSTBITE_SLOW=5`, `RULE_COUNT=6`), each one `TimingWindow` plus
  two magnitudes (`a`, `b`), one snapshot key `"timed_rules"`, one stop point per rule
  (`cancel_rule(kind)`), all cancelled by round end and debug reset. Grave Ward does NOT use this seat
  (`6-5b/R7` below): `start_rule()` cancels-then-starts, so the seat is refresh-by-construction and
  cannot hold "stack additively" (AC 12), and `clear_rules()` fires at round end while corpses must
  survive it (AC 5) — either contradiction alone rules this seat out for a per-corpse value.
- `UnitBoard` (`src/state/unit_board.gd`) is the existing per-player board: parallel arrays indexed by
  a stable board index, appended in cast order and NEVER reused (`4-1/R9` pinned since 4-3a — "a
  summon following a death lands at a NEW index — it NEVER fills a dead unit's hole"). A dead unit is
  a hole: `hp <= 0` at a stable index, never removed, no position field (position is actor-owned,
  F1). `UnitBoard.clear()` is called ONLY from `MatchState._reset_player` (debug reset), never round
  end (`4-1/R5`) — this is "wherever units are cleared today" for ruling `6-5b/R10` below.
- Today's corpse LINGER lives entirely on the actor (`src/actors/minions/unit_actor.gd:107-171`):
  `LINGER_TICKS := 600` (10 s at 60 Hz), a `_linger_ticks` field the runner advances one tick at a
  time from inside its `ticking` gate (`advance_corpse_linger()`), and `begin_corpse_linger()` is
  idempotent, called by `MatchRunner._free_dead_unit_actors` on first observing death. This is the
  mechanism ruling `6-5b/R2` below moves into state. Confirmed: it is NOT authored/`BalanceConfig` today (the
  4-3d story's own Non-Goals said so explicitly) — this story is what makes it authored.
- Contact facts are pushed into state from the runner, computed from actor positions, through
  `MatchState.push_contact` as the sole intake (`match_runner.gd:2093-2150`, `:82`) — the established
  pattern for "the runner computes a fact from positions and pushes it into state," which ruling
  `6-5b/R6` below reuses for Drain's target selection.
- `max_mana = 10.0` in `data/balance/balance_config.tres:107` — confirms the prompt's assumption for
  the Fireball deferred-decision amendment below.
- Deck 1 costs (verified in `docs/planning-artifacts/deck-1-spec.md`, "amendments merged 2026-09-22"):
  Grave Ward 2 mana / Raise Dead 6 mana + 2 red orbs; Drain 2 mana / Vampiric Aura 5 mana + 1 green +
  1 red orb; Vanguard 3 mana / Culling 3 mana + 1 green orb. Grave Ward's extension is already spec'd
  at `T[20]` s and Raise Dead at `T[100]%` max HP — both match this story's rulings below with no
  further amendment needed on those two numbers.
- Hand cards render ONLY the card id today (`src/ui/hud/hud_root.gd:330-352`, `_render_hand_row`):
  `label.text = str(id)`. No price of any kind is shown yet — the "both prices" clause is new
  presentation, not a change to an existing display.
- `CardData` (`src/state/resources/card_data.gd`) carries `cast_condition` (mode 1 cost) and
  `pitch_condition` (mode 4 cost), each a `CardCastCondition` with a `mana_cost` and `orb_costs` —
  the two resources this story's price text reads.

## Discrepancies found against the prompt (repo wins)

1. **Drain's target rule.** `deck-1-spec.md:23` says "Sacrifice your own minion **nearest to you**";
   the prompt's ruling (carried below) instead selects by smallest FACING angle, tie-broken by
   distance then index. This story follows the ruling, not the spec text, on the `6-5a/R2`
   precedent (Bloodhound Step's distance multiplier explicitly superseded the spec's number by
   operator ruling) — this is the same shape of deviation, named here rather than silently applied.
   `deck-1-spec.md` is NOT amended by this story for Drain (only the Grave Ward and Fireball
   amendments are); the facing rule is recorded as ruling `6-5b/R6` in the decision-log.
2. **Culling's "cap field T[99] (effectively no cap)" wording** (`deck-1-spec.md:16`) is resolved by
   gate ruling `6-5b/R15`: it names a real flat `@export kill_cap` on the Culling effect (default 99),
   the maximum number of the caster's own living minions one Culling kills and pays mana for. See AC 8.
3. **Grave Ward's model** (`deck-1-spec.md:19`, "per-player timed rule suspending corpse despawn") is
   SUPERSEDED by operator ruling `6-5b/R7`, on the same `6-5a/R2` precedent as Discrepancy 1 above.
   `deck-1-spec.md:19` IS amended by this story (unlike Discrepancy 1's Drain wording), in the same
   dated amendment section this story's Fireball amendment already added.
4. Everything else checked (deck costs, `max_mana`, `UnitBoard`/`PlayerState` shapes, the deferred
   no-op table, the hand-row render path) matched the prompt's framing with no discrepancy.

## Rulings (operator-ratified or Claude-ruled; carried as fixed inputs — numbered `6-5b/R1`..`6-5b/R17`
in `decision-log.md`, session "6-5b scope + readiness gate (2026-09-23)"; cited here where the story
names a specific ruling)

- **Corpse enters state without position** (`6-5b/R1`). State knows a corpse exists, whose it is (which player's
  board, which board index), and how long it has left. The linger timer moves from the actor into
  state; the actor only READS the remaining lifetime it is handed (to drive its own visual/collision
  lifecycle) and no longer owns the countdown. Position stays 100% actor-owned — F1 and the existing
  "position never enters state" rule are untouched; the corpse's location for Raise Dead/rendering
  purposes is read from the actor, not carried in state.
- **Corpse lifetime is a new tunable `.tres` field** (`6-5b/R2`), default 20 s, replacing today's
  `LINGER_TICKS = 600` actor constant. It converts seconds -> ticks the same way every other duration
  in this codebase does (round, clamp to a minimum of 1 tick).
- **One death path** (`6-5b/R3`; seat location and callers fixed by `6-5b/R13`, see AC 3). A step-4
  combat-hit death, a Culling kill, and a Drain sacrifice all route through the SAME death seat, and
  every minion death leaves a corpse — this is what makes Culling -> Raise Dead work by construction
  rather than needing its own corpse-creation code.
- **Culling and Drain KILL, they do not DAMAGE** (`6-5b/R4`). Neither passes through the damage funnel
  6-5a wired at the four damage seats (`match_state.gd:2028`, `:2362`, `:3890`, `:3961`) — Vampiric
  Aura does not heal from a Culling/Drain kill, Bloodlust does not double it. They set hp to 0 (or
  route directly to the death seat) without touching `apply_damage_at`'s multiplier-bearing call path.
- **Culling** (`6-5b/R5`; cap mechanism fixed by `6-5b/R15`, see AC 8): kills every one of the caster's
  own LIVING minions (totems excluded, per the standing 6-5a ruling that totems are never minions for
  any Deck 1 effect); grants mana per minion killed per the spec's authored number, up to the flat
  `kill_cap` export; mana above the pool's maximum is lost via the EXISTING pool clamp.
- **Drain** (`6-5b/R6`): sacrifices exactly ONE of the caster's own living minions — the one the caster's hero is
  FACING most directly (smallest angle between hero facing and the direction from hero to the
  minion); ties broken by smaller distance, then by lower board index. This is computed by the
  runner from actor positions (hero + every living minion actor of that board) and pushed into state
  as a fact, on the `push_contact` precedent — a runner-computed, position-derived fact entering
  state through one clearly named intake, so it lands on the replay tap and is not recomputed inside
  `advance()` from anything position-shaped. Heal amount is the spec's authored number, clamped at
  the caster's max HP.
- **Grave Ward** (`6-5b/R7`): at resolution, ADDS its authored extension to the remaining lifetime of
  each corpse the caster owns that exists at that instant. Nothing is stored on `PlayerState` — no
  `RULE_*` slot, no `RULE_COUNT` bump. Repeated casts add again to whatever remains (two casts add two
  extensions' worth of remaining time, not a refresh to one). A corpse created AFTER Grave Ward
  resolves is untouched by that cast. The tint marking an extended corpse (see Visuals below) lasts
  until that corpse is removed (expired or raised), not for a fixed window.
- **Raise Dead** (`6-5b/R8`): raises only the caster's OWN corpses. Each raised minion gets a NEW board index
  (holes are never recycled, unchanged from `4-1/R9`), enters at full HP, and appears at the corpse's
  own location — runner-side placement using the corpse's last known position, NOT the existing
  hero-relative summon placement Ruin Vanguard uses. The corpse is consumed (removed from state) by
  the raise. A minion raised this way that dies again leaves a brand-new corpse like any other death.
- **Refusal on nothing to act on** (`6-5b/R9`; mode-specific mechanics fixed by `6-5b/R14`, see AC 5/9/
  13/15/21). A card with nothing to act on is REFUSED and stays exactly where it is with nothing
  spent: Drain or Culling with no own living minion; Grave Ward or Raise Dead with no own corpse. This
  applies identically whether the card is being cast (mode 1) or pitch-activated (mode 4) — i.e.
  Culling (Vanguard's pitch) and Raise Dead (Grave Ward's pitch) get the same refusal test their
  normal-mode siblings do. Operator may revisit this after playtest; it is not a permanent design
  commitment.
- **Totems and heroes leave no corpse**, ever (`6-5b/R10`). Corpses are cleared at the same point
  units are cleared today: the debug reset (`MatchState._reset_player`), never at round end — matching
  `4-1/R5`'s standing rule that the board persists through round-over rather than blinking out.
- **Visuals** follow the 6-5a buff-visual pattern (grey placeholders, no operator-authored clips
  needed here). Grave Ward additionally tints the corpses it has extended (`6-5b/R7`), since an
  invisible per-corpse effect on an already-invisible corpse would be unobservable in the live smoke.

## Acceptance Criteria

### Corpse-in-state

1. A corpse is a fact in game state: which player owns it, which (now-dead) board index it is tied
   to, and its remaining lifetime in ticks. It carries no position. It is created at the moment a
   minion dies via the one shared death path (AC 3), for every minion death regardless of cause
   (combat hit, Culling, Drain), and NEVER for a totem or a hero death — totem exclusion is the same
   `kind_index_at` lookup (`unit_board.gd:505`, `NO_KIND_INDEX` discipline at `match_state.gd:2835`)
   already used at `match_state.gd:2866`, applied at the death seat.
2. Corpse lifetime is a new authored `.tres` field (`BalanceConfig` or an equivalent tunable
   resource), default 20 s, converted to ticks the same way every other authored duration in this
   codebase is (round, clamp to a minimum of 1 tick for a non-zero duration). The actor's
   `LINGER_TICKS = 600` constant and its self-owned `_linger_ticks` countdown are removed; the actor
   instead reads its remaining lifetime from state each tick it needs to (or is handed it once at
   the moment the runner observes death) and drives its own visual/collision lifecycle from that
   value alone — never re-deriving or re-counting a lifetime of its own.
3. One death seat is CREATED (`6-5b/R13`) — none exists today: `unit_board.gd:409-412`'s hp clamp
   inside `apply_damage_at` IS the death (`match_state.gd:2350-2352`); death today is a derived
   predicate, `is_alive_at`, not an event. This story adds that seat on `UnitBoard`, beside
   `apply_damage_at`, so the hp clamp and the corpse write cannot diverge. It has exactly three
   callers: the step-4 contact path, the Culling kill, and the Drain sacrifice — no cause-specific
   corpse-creation code exists anywhere else. The seat is idempotent for a unit already dead: a
   second hit on a corpse never creates a second corpse.
4. A corpse's remaining lifetime counts down one tick per `advance()`, exactly like every other
   tick-counted duration in this codebase (A1 — integer ticks, never a float accumulator, never an
   `Engine`/`OS`/`Time` read from `src/state/`). A corpse whose lifetime reaches zero is removed from
   state (it can no longer be extended, raised, or observed as existing).
5. Corpses are cleared at the exact point units are cleared today — the debug reset path only, never
   round end — so a corpse persists through round-over exactly as a dead unit's board record already
   does.

### Death-seat unification and the kill/damage split

6. A combat-hit death, a Culling kill, and a Drain sacrifice are indistinguishable in their aftermath:
   all three leave a corpse (AC 3), all three make the unit's board record dead (`hp <= 0`, its
   existing hole discipline), and none of the three differs in any other observable way traceable to
   which cause killed the unit.
7. Culling and Drain kill without dealing damage: neither passes through the 6-5a damage funnel.
   A test proves this directly — with an active Vampiric Aura and/or Bloodlust timed rule on the
   caster, a Culling kill or a Drain sacrifice produces NEITHER lifesteal NOR a doubled/halved
   effective amount, where the equivalent combat-hit kill under the same active rules would.

### Culling (pitch of Vanguard)

8. Casting Culling (mode 4 activation) kills up to `kill_cap` (`6-5b/R15`, a flat `@export` on the
   Culling effect, default 99) of the caster's own currently-living minions (not totems, excluded by
   the same `kind_index_at` lookup as AC 1), each leaving its own corpse (AC 1, AC 3), and grants the
   caster mana per minion killed at the spec's authored rate, clamped by the existing mana pool
   maximum. When living minions exceed `kill_cap`, Culling kills in board-index order (oldest first)
   and grants mana for exactly the ones killed; a cap below the living-minion count kills exactly
   `kill_cap` minions and pays for exactly `kill_cap`.
9. Culling with no own living minion is REFUSED (`6-5b/R14`, mode 4): the card stays staged and READY,
   its countdown keeps running toward the normal fizzle, nothing is spent, no kill happens, no mana is
   granted; the player can activate again once a target exists. With exactly one own living minion,
   the identical press kills it and pays for it.
10. Culling never affects the opponent's minions, totems of either player (the `kind_index_at`
    exclusion), or either hero — proven in one fixture with a totem plus a minion on the caster's own
    board and a minion on the opponent's board: the caster's own minion dies and drops a corpse while
    the totem and the opponent's minion are both untouched, asserted on both sides in the same test.

### Grave Ward (normal) and Raise Dead (pitch of Grave Ward)

11. Casting Grave Ward (mode 1) extends the remaining lifetime of every corpse the caster OWNS that
    exists at the moment of resolution, by the spec's authored duration. A corpse belonging to the
    caster that dies (is created) AFTER this resolution is unaffected by that cast.
12. Two Grave Ward casts against the same still-living corpse stack additively: the corpse's
    remaining lifetime after the second cast equals its value immediately before the second cast plus
    exactly one extension (`6-5b/R7`) — not a refresh to a single extension's value.
13. Grave Ward with no own corpse at all is REFUSED (`6-5b/R14`, mode 1, a board-aware pre-spend gate
    beside the existing insufficient-mana refusal, BEFORE the mana spend — this SUPERSEDES, for
    Culling/Grave Ward/Drain/Raise Dead only, 6-5a AC 5 and `4-1/R3`/`4-1/R10`'s "nothing below this
    line is conditional" rule): nothing is spent and no corpse lifetime changes. With exactly one own
    corpse, the identical cast extends it.
14. Casting Raise Dead (mode 4 activation, Grave Ward's pitch) converts every one of the caster's OWN
    corpses that exist at resolution into a live minion: full HP, a NEW board index (no hole is ever
    reused), placed at the location the corpse's own actor last occupied (not the hero-relative
    summon placement Ruin Vanguard uses). Every raised corpse is consumed (removed from state) by
    this resolution; the corpse's actor is freed on the same tick, after this placement read (AC 25).
15. Raise Dead with no own corpse is REFUSED (`6-5b/R14`, mode 4): the orb cost is not spent, the card
    stays staged and READY, its countdown keeps running toward the normal fizzle; the staging mana was
    already spent at staging (`match_state.gd:3350`) and stays spent (`match_state.gd:3444`); the
    player can activate again once a corpse exists. With exactly one own corpse, the identical
    activation raises it.
16. Raise Dead never raises the opponent's corpses — proven in the same fixture as AC 10's shape: with
    a corpse on both the caster's and the opponent's board, activation raises only the caster's.
17. A minion raised by Raise Dead that later dies again leaves a fresh corpse like any other minion
    (AC 1, AC 3) — it is not exempt from the death path just because it originated from a corpse.

### Drain (normal)

18. Casting Drain (mode 1) sacrifices exactly one of the caster's own currently-living minions: the
    one the caster's hero is facing most directly (smallest angle between hero facing and the
    hero-to-minion direction), ties broken by smaller distance then lower board index. This selection
    is computed by the runner from live actor positions and pushed into state as a fact (the
    `push_contact` intake pattern), so it appears on the replay tap and a replay reproduces the exact
    same sacrifice without recomputing anything from position at replay time.
19. The sacrificed minion dies through the shared death path (AC 3/AC 6) — no damage funnel
    involvement (AC 7) — and leaves a corpse like any other death.
20. The caster heals the spec's authored HP amount, clamped at the caster's own max HP (never
    overhealing).
21. Drain with no own living minion is REFUSED (`6-5b/R14`, mode 1, same pre-spend gate as AC 13):
    nothing is spent, no minion dies, no heal happens. With exactly one own living minion, the
    identical cast sacrifices it and heals.
22. With exactly one own living minion, that minion is always the one sacrificed (the angle/tie-break
    rule is trivially satisfied). With two or more, a test proves the angle rule picks correctly
    against at least one non-trivial tie-break case (equal angle, different distance) and one
    same-angle-and-distance case (lower index wins).

### Presentation

23. Every card shown in a player's own hand row displays BOTH its normal (mode 1) price and its pitch
    (mode 4) price, including any orb cost either mode carries — extending
    `HudRoot._render_hand_row` (`hud_root.gd:330-352`), which today shows only the card id, on a price
    map derived and pushed on the `card_colors` precedent (id -> [mode-1 mana, mode-1 orbs, mode-4
    mana, mode-4 orbs], `match_runner.gd:371-378`/`:419-422`). **Open for the gate, not decided here
    (a design choice — see Open Questions):** whether that map is derived load-once like colours or
    injected into state each cards-changed push, and, if it enters state, what it does to the
    record/`FORMAT_VERSION`. The exact layout/format is an implementation choice; both numbers (and
    any orb icon/count) must be visibly distinguishable as belonging to mode 1 vs. mode 4 for the
    operator smoke to judge legibility (`PROC/R8` — machine checks assert geometry only; the existing
    `test/integration/test_hud_viewports.gd` hand-row geometry test gains the new assertion; text fit
    stays a smoke judgment, item 12).
24. Grave Ward's extended corpses carry a per-corpse "was extended" visual mark (`6-5b/R7`, on the
    6-5a grey-placeholder buff-visual pattern) that lasts until that corpse is removed (expired or
    raised) — otherwise the effect is completely unobservable in play.

### New ACs from the readiness gate

25. The corpse's actor is freed exactly when the corpse leaves state, by either route (lifetime zero,
    or consumed by Raise Dead, AC 14): the runner reads state's corpse liveness and frees on the
    transition, keeping the existing `ticking`-gate seat so a paused tick never ages or frees a
    corpse (extends `MatchRunner._free_dead_unit_actors`, `match_runner.gd:1677-1694`).
26. `RecordFile.FORMAT_VERSION` moves 13 -> 14 (measured, not assumed — see Golden Prediction),
    hard-refusing v13, on the 6-5a/6-9 precedent, caused by Drain's new required intake record key
    and/or a new required corpse-list record key.

## Non-Goals

- Rocksling, Boom, Honed Bolt, Counterspell, Corpse Bomb — owned by 6-5c/6-5d/6-5e/6-5f.
- Counterspell's actual undo mechanism — owned by 6-5f. 6-5b adds no undo data of its own (see
  Deferred below).
- Real VFX/animation clips: grey placeholders only, matching 6-5a's posture.
- Any change to Bloodlust, Vampiric Aura, Bloodhound Step, or Frostbite beyond what AC 7 requires to
  prove Culling/Drain bypass their funnel.

## Deferred (recorded here AND as a dated amendment to `docs/planning-artifacts/deck-1-spec.md`)

- **Fireball** (operator's idea, accepted): an X-cost pitch spell that spends ALL of the caster's
  current mana (minimum 3, cap 10 — confirmed against the repo's `max_mana = 10.0`,
  `balance_config.tres:107`) plus 1 red orb; a homing projectile dealing damage per mana spent
  (starting value 1.5, tunable). It REPLACES Bloodlust as the pitch of Bloodhound Step. It is built in
  6-5d, sharing the hero-projectile machinery Rocksling also needs. Until 6-5d lands, Bloodhound Step
  stays paired with Bloodlust exactly as 6-5a shipped it, so the card is never left with an empty
  pitch. Bloodlust itself stays in code (it is not deleted) and simply leaves the Deck 1 card list
  once Fireball takes its slot.
- **Undo data for state-dependent effects** (`6-5b/R16`) — 6-5b records none. 6-5f owns undo data for
  ALL effects, 6-5a's `last_resolved_card` (`[id, mode]`) included.

## Golden Prediction (predictions to MEASURE, not claims)

**PREDICTED to MOVE.** Named causes, each to be measured (not assumed) by the dev pass, following the
6-5a precedent of separating causes:

1. Corpse lifetime moving from an actor constant into cross-tick per-player state on `UnitBoard`
   (`6-5b/R17`) is new per-player state that must survive a tick boundary — at least one new snapshot
   key (a parallel array keyed by board index, `UnitBoard`'s other per-record fields already work this
   way). The measurable is key-set presence, separable from content: the determinism fixture's summoned
   unit never dies (`test_determinism.gd:216`), so the corpse container enters the snapshot EMPTY —
   measure key count `+N` and contents `[]`, not a hash-content claim, for this cause.
2. The refusal path (AC 9/13/15/21, `6-5b/R14`) makes a previously-unconditional pressed action
   REFUSABLE. Under the standing `SC/R6` boundary, a change that adds a new refusable outcome to an
   existing seat moves BOTH the golden and the unit suite (unlike a pure authored-value retune, which
   moves neither) — measured as a named cause, not assumed.
3. Drain's facing-selection fact is new intake — a capture channel is required (the
   `test_intent_recorder.gd` derivation rule: any new public `MatchState` method taking a parameter
   counts as an intake and needs a channel or a named exemption).
4. The four newly-authored effect `.tres` numbers (culling/grave_ward/raise_dead/drain) plus Culling's
   fifth field (`kill_cap`). `BC/R3`'s standing isolation (authored `BalanceConfig` values are outside
   both the golden and the unit suite) does NOT cover this: the effect/card injection set the golden
   path DOES touch, unlike `BalanceConfig` — state explicitly whether this set's presence/values move
   the golden and predict accordingly, measured separately from causes 1-3.
5. `RecordFile.FORMAT_VERSION` is PREDICTED to move 13 -> 14 (AC 26), with hard refusal of v13 (the
   6-5a/6-9 precedent), because of Drain's new required record key (cause 3) and/or a new required
   corpse-list key (cause 1).

**Measure, do not assume**: full suite before any edit, full suite after, golden hash / key count /
`FORMAT_VERSION` in both runs, saved outside the repo, per this project's standing Tier A discipline.

## Expected smoke outcomes (predictions, not claims — record what actually happens)

- **R-D6 re-invocation requested at this gate.** R-D6's acceptance is spent on use and must be
  RE-INVOKED per story against a killable human-driven slot (`decision-log.md:456`, `:506`
  (`2-1/R2`), `:9709-9714` (`6-1c/R4`)). This story's Live Smoke is "operator, two pads" — two
  killable human-driven slots — so the standing rule fires; the binding editor-collateral revert
  procedure (`6-1c/R4`) is restated verbatim below and remains binding.
- Tier A: full gate + review + live smoke ritual, golden-clause reasoning (this story is Tier A on
  its own merits too — it touches `src/state/`, corpse lifecycle, and determinism directly).

## Live Smoke (operator, two pads, flip config `[3,3]` — matching 6-5a's; the operator may reset it
at the gate if a different config is wanted)

**BINDING COLLATERAL PROCEDURE (`6-1c/R4`, restated verbatim per the R-D6 re-invocation above; applies
to this smoke unchanged because two pads means two killable, human-driven slots):**

- Flip config edited TEXTUALLY with the editor closed.
- `git diff` immediately after adding the flip config, and again immediately after removing it.
- After any editor session, `git diff -- project.godot` and revert any collateral change:
  `git checkout -- src/main/main.tscn project.godot` (full paths, both files).
- Editor reload dialog: always "Reload from disk", never "Ignore external changes".
- Re-check `git status` + the collateral diff immediately before any commit chain begins — not
  earlier in the session.

1. **Grave Ward then a natural corpse.** Kill an own minion in combat, cast Grave Ward before its
   linger would have expired: the corpse visibly persists (and is tinted) well past 10 s (today's old
   linger), out to roughly 20 s past the extension.
2. **Grave Ward stacking.** Cast Grave Ward twice on the same corpse: it visibly lasts noticeably
   longer than a single cast.
3. **Grave Ward with no corpse.** Cast Grave Ward with no own corpse on the board: the card is
   refused (stays where it is, nothing spent).
4. **Raise Dead.** With at least one own corpse present, pitch-activate Raise Dead: a new minion
   appears exactly at the corpse's location, at full HP, and the corpse is gone.
5. **Raise Dead with no corpse.** Pitch-activate Raise Dead with no own corpse: refused.
6. **Culling.** With two or more own living minions, pitch-activate Culling: all die simultaneously,
   each leaves a corpse, caster's mana visibly increases (capped at the mana bar's max).
7. **Culling with no minions.** Pitch-activate Culling with no own minion: refused.
8. **Culling -> Raise Dead loop.** Summon minions, Culling them, then Raise Dead: the raised minions
   appear at the corpses' locations, proving the loop works end-to-end.
9. **Drain, facing choice.** With two or more own minions positioned so one is clearly more directly
   ahead of the hero than the other, cast Drain: the more-directly-faced minion dies and drops a
   corpse; the caster's HP visibly increases (or stays capped at max, if already full).
10. **Drain with no minions.** Cast Drain with no own minion: refused.
11. **Culling/Drain vs. Vampiric Aura and Bloodlust.** With Vampiric Aura and/or Bloodlust active on
    the caster, Culling and Drain visibly do NOT heal via lifesteal and are NOT doubled/halved —
    contrasted against a combat kill under the same active rules, which does show the funnel's
    effect.
12. **Hand prices.** Every card in the own hand row visibly shows both a normal-mode price and a
    pitch-mode price, including orb costs where authored.
13. **Regression.** Every 6-5a-shipped effect (Ruin Vanguard, Bloodlust, Vampiric Aura, Bloodhound
    Step, Frostbite) and every still-deferred Deck 1 effect (Rocksling, Boom, Honed Bolt,
    Counterspell, Corpse Bomb) still cast cleanly with no crash, no assert, no visible regression.

## Tasks / Subtasks

**Existing tests this story breaks (must be repaired as part of the task that removes their cause):**

| File | What breaks | Fix |
|---|---|---|
| `test/state/test_spell_framework.gd` | `:99-109` literal `owners` dict holds all nine deferred rows; `:110` asserts count `== 9`; `:111-114` loops it | Both the dict literal AND the count drop to five once culling/grave_ward/raise_dead/drain are removed from `DEFERRED_EFFECT_OWNERS` |
| `test/state/test_card_authoring.gd` | `:418` iterates `DEFERRED_EFFECT_OWNERS.keys()` asserting each deferred effect authors no numbers (N11); coverage of these four SILENTLY VANISHES when they leave the dict | Add new positive assertions for culling/grave_ward/raise_dead/drain's authored numbers, on the `:405-416` pattern |
| `test/integration/test_unit_corpse_linger_live.gd` | `:244` reads `corpse._linger_ticks`; `:311-312`/`:322` pin `UnitActor.LINGER_TICKS`; `:38` names 599 | Re-point the whole file at the authored lifetime (state-owned, AC 2) instead of the removed actor constant |
| `test/integration/test_unit_corpse_walkthrough_live.gd` | Runs the full linger; `MAX_FRAMES := 2000` (`:60`) | Confirm the 20 s (1200-tick) lifetime still fits the budget (see Dev Notes live-test-budgets bullet) |
| `test/integration/test_unit_combat_live.gd` | `:313-326` `corpse.is_lingering()`, comments citing "the 600-tick expiry" | Keep `is_lingering()`; correct the stale 600 narrative in comments |
| `test/perf/perf_20_units_live.gd:361`, `test/state/test_lock_on.gd:312` | Comments citing "600" / corpse linger | Comment hygiene only |

1. **Corpse-in-state** (AC 1-5): new `test/state/test_corpses.gd` — corpse fact shape (owner, dead
   index, remaining lifetime, no position), creation via the death seat, per-tick countdown and
   removal at zero, debug-reset-only clearing, never for totems/heroes.
2. **Death-seat unification and kill/damage split** (AC 6, 7, 25): extend `test_corpses.gd` — one
   death seat on `UnitBoard` beside `apply_damage_at` with three callers, idempotent on an
   already-dead unit; the Vampiric-Aura/Bloodlust-bypass test (AC 7); `match_runner.gd:1677-1694`'s
   actor-free extended to the corpse-leaves-state transition (AC 25), edited alongside a
   `match_runner`-level live/integration test.
3. **Culling** (AC 8-10): new own-minion-spells unit test file — kill-all-own-living-minions plus
   `kill_cap` behaviour (at/below/above the cap, including the exactly-one-minion positive case), the
   no-target refusal (AC 9) with its positive companion, and the totem/opponent exclusion fixture (AC
   10) shared with AC 16.
4. **Grave Ward / Raise Dead** (AC 11-17, 24): same file — per-corpse extension and additive stacking
   (AC 11/12), the no-corpse refusal with positive companion (AC 13), raise-and-consume with new board
   index and actor-location placement (AC 14), the no-corpse refusal with positive companion (AC 15),
   the totem/opponent exclusion fixture from task 3 (AC 16), raised-minion-dies-again (AC 17), and the
   per-corpse tint mark's lifetime (AC 24).
5. **Drain** (AC 18-22): same file — facing-angle selection computed in the runner and pushed as a
   fact (new intake, named per the Dev Notes naming-hazard bullet — NOT `drain_*`), the shared death
   path and no-funnel proof, the heal-and-clamp, the no-target refusal with positive companion (AC 21),
   and the angle/tie-break test matrix (AC 22).
6. **Presentation** (AC 23, 26): `hud_root.gd` both-prices rendering per the price-channel shape the
   gate leaves open (Open Questions); `test/integration/test_hud_viewports.gd` gains the hand-row
   geometry assertion; `record_file.gd`'s `FORMAT_VERSION` bump (AC 26) and its own test.
7. **Test repairs**: apply every row of the broken-test table above, one edit per row.
8. **Live-test budget check** (Dev Notes bullet): verify `MAX_FRAMES`/`PAUSE_AT_TICK` in
   `test_unit_corpse_linger_live.gd` and `test_unit_corpse_walkthrough_live.gd` still bound the run
   under the new 1200-tick default lifetime.

## Open Questions

1. **CLOSED at this gate — where corpse data structurally lives** (`6-5b/R17`): corpse lifetime lives
   on `UnitBoard`, at the dead unit's own board index (no separate container); a consumed or expired
   corpse is marked there.
2. **CLOSED at this gate — actor-reads-lifetime wiring**: this is the dev pass's call; the ACs do not
   depend on which shape it takes (either polling state every tick, mirroring the existing
   `is_alive_at` poll shape, or a one-shot value counted down independently for VISUAL purposes only)
   as long as the actor never re-derives or re-counts an authoritative lifetime (AC 2).

### Left open for the operator — not covered by a fixed ruling in this pass

3. **AC 23's price channel** (M2): whether the hand-row price map is derived load-once like
   `card_colors` or injected into state on each cards-changed push, and, if it enters state, what that
   does to the record/`FORMAT_VERSION`. This is a codebase-shape choice (data flow into a new HUD
   channel) under this project's autonomy rule — the dev pass does not pick it unprompted; the story
   states the requirement (AC 23) and both options, and leaves the choice for the gate/operator.

## Dev Notes

- **Where the change likely goes** (confirmed file locations; exact new-file names are the dev pass's
  choice): `src/state/economy/card_effect_resolver.gd` (four new outcome constants replacing four
  `DEFERRED_EFFECT_OWNERS` rows); `src/state/match_state.gd` (the death seat CREATED per AC 3/`6-5b/
  R13`, Culling/Drain apply seats, Grave Ward/Raise Dead apply seats, the new corpse-tick-down step
  inside `advance()`, the mode 1/mode 4 pre-spend refusal gates per `6-5b/R14`); `src/state/
  unit_board.gd` (corpse data, per `6-5b/R17` — extends `UnitBoard`, not a new sibling container);
  `src/actors/minions/unit_actor.gd` (remove `LINGER_TICKS`/`_linger_ticks`, read remaining lifetime
  from state instead); `src/main/match_runner.gd` (Drain's facing-fact computation and push, Raise
  Dead's corpse-location placement and actor-free ordering per AC 25, any new intake capture channel);
  `src/systems/intent_recorder.gd` / `src/systems/record_file.gd` (Drain's new intake channel,
  `FORMAT_VERSION` bump, AC 26); `data/effects/{culling,grave_ward,raise_dead,drain}.tres` (numbers
  already authored per 6-5a's AC 15 — this story only needs to give them their real resolver
  behaviour, per `6-5a` Dev Notes "the other nine resolve through a named no-op... numeric effect
  exports exist only for the five effects implemented [in 6-5a]. Deferred effects get their numbers in
  their own stories" — so this story authors Culling/Grave Ward/Raise Dead/Drain's numeric exports,
  PLUS a fifth field on Culling's effect resource: `kill_cap` (`@export`, default `99`, `6-5b/R15`));
  `src/ui/hud/hud_root.gd` (`_render_hand_row`, both-prices display, per AC 23 — channel shape open,
  see Open Questions).
- **Pure-function / D6 discipline**: the resolver COMPUTES, `advance()`'s ordered dispatch APPLIES —
  unchanged from 6-5a. Culling/Drain/Grave Ward/Raise Dead follow the identical split: the resolver
  returns a verdict, `MatchState` does the board/pool/corpse mutation.
- **F1 / D3(a) / D3(b) / A2** unchanged — no new `_physics_process`, no `Input.*` outside
  `src/controllers/`, no global RNG/`Time`/`OS`/`Engine` in `src/state/`. Drain's facing computation
  happens in the RUNNER (which may read positions), never in `src/state/` — the runner computes, state
  only ever receives the already-resolved fact, on the `push_contact` precedent.
- **Determinism**: any per-corpse value that survives a tick boundary and can affect play (a corpse's
  remaining lifetime including Grave Ward extensions, Drain's selected-target fact if it needs to
  survive past the tick it lands) must be hashed into the snapshot.
- **Replay trap**: keep every new effect number a flat `@export` on `CardEffect` (the 6-5a AC 2
  discipline) — no new nested resource class without adding it to `RecordFile._fresh_nested`
  (`record_file.gd:684`) in this same story.
- **Non-vacuity**: back up each file to the scratchpad with SHA256 before mutating; restore by copying
  back, never `git checkout` (this project's standing protocol, see memory `dev-pass-restore-from-out-of-repo-copy`).
- **Test harness constraint**: state tests run in `_initialize()` with no frame — a frame-dependent
  assertion is a leak tripwire.
- **Naming hazard**: `test/state/test_intent_recorder.gd:27` pins
  `EXEMPT_CARRIES_NO_DATA_INWARD := "drain_signals"` by exact string against `MatchState`'s public
  surface. Drain's new intake must NOT be named `drain_*` (recommend `push_drain_target`), or the
  derivation rule's exemption list becomes ambiguous to a reader.
- **Live-test budgets**: default corpse lifetime 20 s = 1200 ticks doubles today's 600. Verify
  `test_unit_corpse_linger_live.gd:61` `MAX_FRAMES := 3000` and
  `test_unit_corpse_walkthrough_live.gd:60` `MAX_FRAMES := 2000` still bound the run, and
  `PAUSE_AT_TICK := 120` still lands early in the linger, once the new lifetime is wired.
- **Stale citations already corrected in this pass**: the four `_funnel_damage` call sites are
  `match_state.gd:2028`, `:2362`, `:3890`, `:3961` (not `:1971`, `:3692`, `:3755`, `:2292`).
- Windows: run the suite via the Bash tool with `GODOT=/c/Godot/godot.exe bash test/run_all.sh` (WSL
  is broken); shell is PowerShell 5.1 for git (no `&&`); commit messages pure ASCII via
  `git commit -F <tempfile outside the repo>`; docs and code in separate commits; trailer per the
  session's commit attribution rule; validation worth proving is committed as a test, never
  written-then-deleted.

### Project Structure Notes

- No new top-level folder. New `.tres` numeric authoring lands in the already-existing `data/effects/`
  files for `culling`, `grave_ward`, `raise_dead`, `drain` (created empty-numbered by 6-5a). Corpse
  data extends `UnitBoard` (`6-5b/R17`, closed at this gate — no new sibling container, no new-shape
  flag needed).

### Project Context Rules

- HARD RULE — state/visual separation: corpse lifetime is now state-owned; the actor visual/collision
  lifecycle reacts to it, never decides it.
- HARD RULE — feature flags: Culling/Grave Ward/Raise Dead/Drain gate on the existing
  `FeatureFlags.spells` flag (already ON in `data/feature_flags.tres` since 6-5a) — no new flag is
  needed for this story.
- Authored data in `.tres` with a named default (corpse lifetime, 20 s); every gameplay layer
  independently toggleable.
- D6: evaluators compute, `MatchState.advance()`'s ordered dispatch applies.
- F1 / D3(a) / D3(b) / A2 machine-checked by `test/state/test_architecture_invariants.gd`.
- Commit conventions: docs and code never share a commit; validation worth proving is committed as a
  test; ASCII messages via `-F`; show the full diff before staging; `git add`/`git commit` separate,
  explicit paths only; never push until the log is confirmed in chat.
- Tier A: full gate + review + live smoke ritual (this story touches `src/state/`, corpse lifecycle,
  and determinism directly, independent of whether the golden clause alone would also force it).

### References

- `docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/decision-log.md`: `R-SPELL`; the 6-5 split
  ruling (session 2026-09-22, referenced by `6-5a`'s own board note).
- `docs/planning-artifacts/deck-1-spec.md` — card numbers; amended twice by this story (Fireball
  deferred decision, Grave Ward per-corpse model per `6-5b/R7`).
- `docs/implementation-artifacts/6-5a-spell-framework-and-buffs.md` — the framework, timed-rule seat,
  damage funnel, hashed record, and undo-shaping rulings (R6) this story builds directly on.
- `docs/game-architecture.md`, `docs/project-context.md` — F1, D3(a), D3(b)/A2, D6, the HARD RULES.
- `test/state/test_architecture_invariants.gd` — the machine-checked invariants.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## Change Log

- 2026-09-22: story authored (Status `authored`), baseline `e7842821ad1fb56a76a758e74f7b3e684cc57a36`.
  Not cleared for a dev pass.
- 2026-09-23: readiness gate round 1 (`C:\dev\_65b-gate.md`, report-only): NOT READY, 7 blocking / 7
  major / 8 minor. Fix pass applied every blocking item and every major/minor item not requiring an
  operator/design choice outside the rulings recorded in `decision-log.md` session "6-5b scope +
  readiness gate (2026-09-23)" (`6-5b/R1`-`6-5b/R17`); AC 23's price-channel shape (M2) is left open
  for the operator (see Open Questions). No second gate round run. Status -> `ready-for-dev`.
