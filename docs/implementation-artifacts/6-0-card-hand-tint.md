---
baseline_commit: 438198a9e84206f022add48d965e579cb3539d70
---

# Story 6.0: Card Hand Tint

Status: authored

> **Scope note.** FIRST story of E6 (`E5-C/R5`, `E6-P/R2` board order), promoted to this slot after a
> second consecutive live-smoke finding (5-4, 5-5) that the own-hand row renders uncoloured card ids
> with no colour tell. Tier B per `E4-P/R9` (CLAUDE.md's Story tiers section points here rather than
> restating it) — **contingent on a measured before/after showing the golden hash and the per-player
> snapshot key set unmoved.** Tier may be RAISED, never lowered, mid-story: if the dev pass finds it
> needs a `src/state/` change, a new observation seam, or either measurement moves, **STOP and
> escalate** — do not re-baseline, do not proceed as Tier B.

## Story

As a player reading my own hand mid-match,
I want each of my four hand cards' faces tinted with that card's colour (RED/BLUE/GREEN),
so that I can read my hand's colour composition at a glance instead of parsing four id strings —
closing the second consecutive live-smoke finding that the hand renders uncoloured (`5-5/R10`,
`E5-C/R5`).

## Acceptance Criteria

1. **Each of the four OWN-hand card panels renders tinted by its occupying card's
   `Enums.CardColor`** (`src/state/enums.gd:9`, `RED`/`BLUE`/`GREEN`). A panel holding no card
   (`Hand.EMPTY`, a permanent hole, or an in-flight replacement slot) renders with the existing
   UNTINTED face style (`_card_base_style`, `hud_root.gd:441`) — tint applies only to a slot that
   currently holds a real card id.
2. **The colour reaches `HudRoot` by riding the EXISTING `cards_changed` wrapper seam** in the
   runner (`src/main/match_runner.gd:395-398`, the `4-B1` precedent: `pending_draw_owed` already
   rides this same wrapper alongside `hand_ids`/`deck_count`/`discard_count`). Do **not** add a
   tenth `connect_*` observation seam — the family is machine-frozen at nine
   (`test/state/test_architecture_invariants.gd:291-332`,
   `test_runner_observation_seams_are_exactly_nine`) and a tenth is the operator's call, not this
   story's (`E6-P/R8` item 1 fixes the mechanism already — this AC is not a design choice).
3. **`HudRoot` never reads `CardDatabase`.** The runner is the ONE place allowed to read it
   (`3-3 AC 2`/`AC 8`, machine-checked); it must derive each hand id's colour and hand `HudRoot` a
   plain value (an `Enums.CardColor` int, or a small id→colour map), exactly as `_derive_card_colors()`
   already does for the state-injection channel (`match_runner.gd:603-610`, `5-2 AC 4`). Reuse that
   existing derivation — do not write a second CardDatabase-scanning function that duplicates it.
4. **No `src/state/` file changes, and no new snapshot key.** Colour reaching the HUD is a
   presentation-side enrichment of an existing PUSH channel, not a state read — `MatchState`
   already carries card colours internally (`_card_colors`, `match_state.gd:340`, injected at
   `5-2 AC 4` for the charge/defense telegraph) but `HudRoot` must not reach for that field or any
   new accessor onto it; the runner's own `_derive_card_colors()`/`CardDatabase` path is sufficient
   and keeps the state layer untouched.
5. **The armed-selection indicator (`set_card_selection`, `hud_root.gd:516-522`) is not broken by
   tinting.** Today it swaps the WHOLE panel style between two SHARED `StyleBoxFlat` instances
   (`_card_base_style` / `_card_armed_style`) on every call, for every panel. Tint must remain
   visible (or at minimum not silently reset to blank/wrong-colour) both when a slot is armed and
   when the armed slot changes. This is an implementation choice (which visual channel carries tint
   — panel fill, border accent, a small swatch, per-colour base/armed StyleBoxFlat pairs, etc. — see
   Dev Notes) but the interaction must be handled deliberately, not left to whichever style happens
   to apply last.
6. **No opponent-facing change of any kind.** The opponent card row was deleted at `3-6/R1`
   (`E3-RG/R4`) and stays deleted — this story does not revive it, read the opponent's hand, or
   touch `debug_hand_contents()`/the reveal toggle. Hands stay private; the pitched card remains the
   sole public information (GDD lock, `E6-P/R4`, unaffected by this story).
7. **Golden Prediction (Tier B escalation clause).** The golden hash and the 30-key per-player
   snapshot set (below) are measured BEFORE the dev pass and AFTER the diff. If either moves, STOP
   — do not re-baseline, report and escalate to Tier A per `E4-P/R9`.

## Golden Prediction (inverse form — the Tier B escalation clause)

**Prediction: the golden hash and the snapshot key set do NOT move.** Both are measured, not
assumed (`E4-P/R9`'s "golden clause is decisive" rule).

- **Golden hash, authoritative source:** `test/state/test_determinism.gd:891`,
  `const GOLDEN := "d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d"`. Measured
  today (2026-09-08), at HEAD `438198a9e84206f022add48d965e579cb3539d70`, as the BEFORE value —
  full suite run, `ALL TESTS PASSED`, state harness `720 tests, 0 failed, 5363 assertions`, all 55
  integration files PASS.
- **Snapshot key set, authoritative source:** `test/state/test_card_observation.gd:280-303`,
  `test_the_observation_channel_adds_no_snapshot_key`. Measured today as the BEFORE set, exactly
  THIRTY keys, sorted:
  `["deck_size", "defense", "discard_size", "hand_size", "hero", "lock_target", "mana", "orbs",
  "pending_draw", "pending_draw_owed", "projectile_alive", "projectile_flight_ticks",
  "projectile_homing", "projectile_kind", "projectile_source", "projectile_targets",
  "projectile_travelled", "stamina", "telegraph", "unit_attack_cooldown", "unit_attack_count",
  "unit_attack_dir", "unit_attack_phase", "unit_attack_ticks", "unit_count", "unit_hp",
  "unit_in_reach", "unit_kind", "unit_swing_dedupe", "unit_targets"]`.

**The escalation clause itself, as an AC:** run the full suite (`bash test/run_all.sh`) BEFORE
touching any file and AFTER the diff is complete; record both hash values and both key sets in the
Dev Agent Record. **If either value differs from the BEFORE value recorded here, STOP and
escalate** — this story's own design intent (a presentation-only enrichment of an existing push
channel, reading only already-loaded `CardDatabase` content) predicts no movement; if the
measurement disagrees, the disagreement is itself the signal to stop, not a call to re-baseline.

## Live Smoke

**One operator check**, exercising the AC 1 tint and the AC 5 selection interaction: play at least
one card of each colour across a session (or start a deck slice that guarantees colour variety) and
confirm each hand slot visibly carries its card's colour; arm/cycle the selection indicator across
tinted slots and confirm the armed tell (today's gold border/warm fill) is still legible alongside
the colour. Record in `docs/playtest-log.md` by the operator's own hand.

## Tasks / Subtasks

- [ ] Read `src/ui/hud/hud_root.gd` (hand-row construction and styling: `_build_hand_row`
      `hud_root.gd:427-472`; `_make_card_armed_style` `hud_root.gd:494-502`; `set_card_selection`
      `hud_root.gd:516-522`; `on_cards_changed` `hud_root.gd:223-232`) and
      `src/main/match_runner.gd` (the wrapper `:395-398`; `_derive_card_colors()` `:603-610`; the
      non-replay content-injection order `:301-333`) BEFORE touching either (AC: 2, 3, 4, 5)
- [ ] Extend the runner's `cards_changed` wrapper (or a sibling read the wrapper calls) to hand
      `HudRoot` each occupied slot's colour alongside `hand_ids`/`deck_count`/`discard_count`/
      `pending_draw_owed`, reusing `_derive_card_colors()`'s CardDatabase walk rather than a new
      one (AC: 2, 3, 4)
- [ ] Implement the tint render in `HudRoot`, deciding deliberately how tint composes with the
      existing base/armed StyleBoxFlat swap in `set_card_selection` (AC: 1, 5)
- [ ] Confirm no opponent-facing surface is touched: `debug_hand_contents()`, the reveal toggle, and
      the (already-deleted) opponent row stay untouched (AC: 6)
- [ ] Record BEFORE golden hash + snapshot key set (already captured in this file); re-run the full
      suite after the diff; record AFTER values; escalate per the Golden Prediction clause if either
      moved (AC: 7)
- [ ] Live Smoke per the script above, recorded in `docs/playtest-log.md` by the operator

## Dev Notes

- **`_derive_card_colors()` already exists and is exactly the derivation this story needs**
  (`match_runner.gd:587-610`, shipped by `5-2 AC 4`): it walks `CardDatabase.sorted_ids()` and
  returns `Dictionary[StringName, Enums.CardColor]`, TOTAL over the whole library (every `CardData`
  has a non-nullable `color`, `card_data.gd:30`, default `RED`). It is currently called ONCE per
  match start (non-replay branch only, `match_runner.gd:330-332`) to build the `_card_colors`
  injection MatchState consumes for the charge/defense telegraph. **This story does not touch that
  injection path.** It needs the SAME map (or a call to the same function) available to the
  `cards_changed` wrapper — either call `_derive_card_colors()` again where convenient (cheap: a
  single pass over ≤9 fixture cards, content that never changes mid-match) or hold the already-built
  map as a runner member set at the same call site, and read it inline from the wrapper. Either
  shape satisfies AC 3/AC 4; picking is an implementation decision.
- **This works identically under replay.** The wrapper's colour lookup source is `CardDatabase`
  content (static, load-once, identical in live play and replay), not the replay-recorded
  `_card_colors` injection that state consumes — so there is no live/replay divergence risk and no
  reason to route through `MatchState` at all.
- **The styling crux is AC 5, not AC 1.** `_build_hand_row` currently builds ONE shared
  `StyleBoxFlat` (`card_style`, `hud_root.gd:441`) applied via `add_theme_stylebox_override("panel",
  card_style)` to all four panels; `_card_base_style` and `_card_armed_style` are the two SHARED
  instances `set_card_selection` swaps between, rewriting the WHOLE panel style on every call
  (`hud_root.gd:516-522`, "every panel is written on every call, not just the armed one"). A
  same-shape defect to avoid: mutating a shared `StyleBoxFlat` in place would tint every panel at
  once (the exact bug `_make_card_armed_style`'s own docstring at `hud_root.gd:486-489` warns
  against for the armed style). Per-panel tint therefore needs either per-panel `StyleBoxFlat`
  instances (built or swapped per colour, base and armed variants both) or a tint channel outside
  the swapped stylebox (e.g. a border/swatch child control) that `set_card_selection` does not
  overwrite. Whichever shape is chosen, `set_card_selection`'s "every panel written every call"
  discipline must still hold for whatever it DOES own, and colour must survive an arm/disarm cycle.
- **Reuse the existing palette — do not author a new one.** `HudRoot.ORB_COLORS`
  (`hud_root.gd:83-87`) is presentation-local, already indexed `[RED, BLUE, GREEN]` matching
  `Enums.CardColor`'s declaration order, and is explicitly "the same three hues the charge telegraph
  uses, so the counter a player watches and the orb that flashed over the hero read as one colour"
  (`hud_root.gd:76-82`, `5-4 AC 18`). Card tint should read as the SAME three hues for the same
  reason — a player's hand colour, the orb counter, and the charge telegraph should all agree on
  what "red" looks like. Do not add `data/telegraphs/` or any other authored-resource read to
  `src/ui/` for this — the precedent is explicit that `src/ui/` owns its own hue constants.
- **Untinted states, exhaustively:** `Hand.EMPTY` (blank, `hud_root.gd:231`), the permanent hole
  (4-0 AC 8, also blank), and the in-flight `IN_FLIGHT_CAPTION` slot (`hud_root.gd:229`, `4-B1 AC
  1`) all currently share the base style. None of these three cases has a `CardData` to colour by —
  keep all three on the untinted base style; do not guess a colour for a slot with no card.

### Project Structure Notes

- `src/main/match_runner.gd`: the `cards_changed` wrapper (`:395-398`) is extended to also read/pass
  colour, reusing `_derive_card_colors()` (`:603-610`). No new `connect_*` method — the wrapper
  itself, and the `on_cards_changed` signature it calls, may grow another parameter (the `4-B1`
  precedent for `pending_draw_owed`: a defaulted trailing parameter keeps existing call sites
  back-compatible).
- `src/ui/hud/hud_root.gd`: `on_cards_changed` (`:223-232`) gains the colour data; `_build_hand_row`
  (`:427-472`) and `set_card_selection` (`:516-522`) are the two seats that need deliberate tint
  handling (AC 5).
- No `src/state/` file is expected to change. If the dev pass finds one must, that is itself
  escalation grounds under the Golden Prediction clause — stop and report before proceeding.
- No `data/` file changes expected (no new authored resource; `CardData.color` already exists on
  every fixture card).

### Project Context Rules

- **Signals over polling; direct subscription is the default** — colour must ride the existing
  signal-driven `cards_changed` seam, never a per-frame poll or a new `_process` read.
  [Source: project-context.md, "Signals over polling"]
- **CONSTRAINT C: never cache a reference that can go stale; read inline.** `CardDatabase` content
  is load-once and cannot go stale mid-match, so caching a derived colour map runner-side is safe —
  but read it, don't hold a `HudRoot`-side handle into runner or state internals.
  [Source: project-context.md, "Autoloads (singletons)"]
- **`src/state/` may never name `CardDatabase`** (AC 8 precedent, `3-3`/`3-2`) and this story adds no
  exception — colour is derived runner-side and handed to the HUD as plain data.
  [Source: project-context.md, "Code Organization Rules"; test_architecture_invariants.gd]
- **Guard mechanism over guard pattern** — the nine-seam family guard
  (`test_runner_observation_seams_are_exactly_nine`) must stay green, unamended, by this story; it is
  the mechanism proving AC 2.
  [Source: project-context.md, "Testing Rules"; test/state/test_architecture_invariants.gd:291-332]
- **Text fit is not machine-checkable; on-screen legibility goes to operator smoke.** Whatever tint
  treatment is chosen (fill, border, swatch) must be judged for legibility at the live smoke, not
  declared correct by a geometry assertion alone.
  [Source: project-context.md, "Testing Rules", `PROC/R8`]

### References

- [Source: docs/planning-artifacts/gdds/gdd-cardsouls-2026-07-20/epics.md:193-280 — E6 section,
  obligations block, `6-0` line :203-204]
- [Source: decision-log.md Session 2026-09-08 — E6 planning, `E6-P/R2` (:9301-9316), `E6-P/R8` item 1
  (:9355-9366)]
- [Source: decision-log.md Session 2026-09-07 — E5 close-out, `E5-C/R5` (:9082-9084), `E5-R/R8` item 1
  (:9225-9231)]
- [Source: sprint-status.yaml story_notes, `6-0-card-hand-tint` line]
- [Source: src/main/match_runner.gd:280-333 (content-injection order), :395-398 (the wrapper seam),
  :587-610 (`_derive_card_colors`)]
- [Source: src/ui/hud/hud_root.gd:75-137 (constants/palette), :223-232 (`on_cards_changed`),
  :427-472 (`_build_hand_row`), :494-522 (armed style / `set_card_selection`)]
- [Source: src/state/resources/card_data.gd:22-30 (`id`, `color`); src/state/enums.gd:6-9
  (`CardColor`); src/state/match_state.gd:340, :701-707 (`_card_colors`/`inject_card_colors`, read
  ONLY by charge/defense colour, untouched by this story)]
- [Source: test/state/test_determinism.gd:891 (`GOLDEN`); test/state/test_card_observation.gd:221-303
  (snapshot key-set pin); test/state/test_architecture_invariants.gd:267-332 (nine-seam family)]
- [Source: docs/implementation-artifacts/4-B1-card-hud-debt-discharge.md — the `cards_changed`
  wrapper precedent this story follows verbatim]

## Dev Agent Record

### Agent Model Used

### Debug Log References

**Golden Prediction BEFORE values, captured at authoring time (2026-09-08, HEAD
`438198a9e84206f022add48d965e579cb3539d70`), for the dev pass to compare against AFTER:**
- Golden hash: `d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d`
  (`test/state/test_determinism.gd:891`)
- Snapshot key set (30 keys): `["deck_size", "defense", "discard_size", "hand_size", "hero",
  "lock_target", "mana", "orbs", "pending_draw", "pending_draw_owed", "projectile_alive",
  "projectile_flight_ticks", "projectile_homing", "projectile_kind", "projectile_source",
  "projectile_targets", "projectile_travelled", "stamina", "telegraph", "unit_attack_cooldown",
  "unit_attack_count", "unit_attack_dir", "unit_attack_phase", "unit_attack_ticks", "unit_count",
  "unit_hp", "unit_in_reach", "unit_kind", "unit_swing_dedupe", "unit_targets"]`
  (`test/state/test_card_observation.gd:280-299`)
- Full suite: state harness `720 tests, 0 failed, 5363 assertions`; 55/55 integration files PASS;
  `bash test/run_all.sh` exit 0, `ALL TESTS PASSED`.

### Completion Notes List

### File List

## Change Log
