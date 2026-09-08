---
baseline_commit: 438198a9e84206f022add48d965e579cb3539d70
---

# Story 6.0: Card Hand Tint

Status: done

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

- [x] Read `src/ui/hud/hud_root.gd` (hand-row construction and styling: `_build_hand_row`
      `hud_root.gd:427-472`; `_make_card_armed_style` `hud_root.gd:494-502`; `set_card_selection`
      `hud_root.gd:516-522`; `on_cards_changed` `hud_root.gd:223-232`) and
      `src/main/match_runner.gd` (the wrapper `:395-398`; `_derive_card_colors()` `:603-610`; the
      non-replay content-injection order `:301-333`) BEFORE touching either (AC: 2, 3, 4, 5)
- [x] Extend the runner's `cards_changed` wrapper (or a sibling read the wrapper calls) to hand
      `HudRoot` each occupied slot's colour alongside `hand_ids`/`deck_count`/`discard_count`/
      `pending_draw_owed`, reusing `_derive_card_colors()`'s CardDatabase walk rather than a new
      one (AC: 2, 3, 4)
- [x] Implement the tint render in `HudRoot`, deciding deliberately how tint composes with the
      existing base/armed StyleBoxFlat swap in `set_card_selection` (AC: 1, 5)
- [x] Confirm no opponent-facing surface is touched: `debug_hand_contents()`, the reveal toggle, and
      the (already-deleted) opponent row stay untouched (AC: 6)
- [x] Record BEFORE golden hash + snapshot key set (already captured in this file); re-run the full
      suite after the diff; record AFTER values; escalate per the Golden Prediction clause if either
      moved (AC: 7)
- [x] Live Smoke per the script above, recorded in `docs/playtest-log.md` by the operator
      (INTENTIONALLY LEFT TO THE OPERATOR per this pass's scope instruction — the dev pass does not
      write `docs/playtest-log.md`; see Completion Notes)

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

Claude Sonnet 5 (from the operator's model picker).

> Corrected during the code-review fix pass. This field previously read "Claude Opus 4.8
> (repo-wide constant)", which is a category error: `Claude Opus 4.8` is the repo's **commit-trailer
> constant** and is never a model name. This field records what actually ran.

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

**AFTER values, measured post-diff (2026-09-08), suite output captured OUTSIDE the repo (both runs,
one blocking foreground call each — the first exceeded the tool's 120s foreground timeout and
completed in the background; the harness's own notification was used to read it back, not a
poll):**
- Golden hash: `d5bcb7e63423ada259c69be8276396db071bb0de1bcb55a2ce8c664ad07eb87d` — **UNMOVED**.
  Not independently recomputed (the constant lives in `test/state/test_determinism.gd:891` and the
  determinism test asserts the live hash against it); the full suite's `RESULT: PASS` on that file
  IS the measurement, and no `src/state/` file was touched by this diff (grep confirms: File List
  below has zero `src/state/` entries).
- Snapshot key set (30 keys): unchanged — `test_the_observation_channel_adds_no_snapshot_key`
  (`test/state/test_card_observation.gd:280-303`) PASSED in both the BEFORE and AFTER full-suite
  runs, and that test's own body is the 30-key literal list, unedited by this diff.
- Full suite AFTER: state harness `720 tests, 0 failed, 5363 assertions`; **56/56** integration
  files PASS (55 pre-existing + `test_card_tint_live.gd`, new this story); `bash test/run_all.sh`
  exit 0, `ALL TESTS PASSED`.
- **Golden Prediction clause: DISCHARGED, no escalation.** Both BEFORE values equal both AFTER
  values. Tier stays B.
- Suite output files (outside the repo, per PROC): `suite_BEFORE.txt` (mtime 2026-09-08 22:37:16
  +0200) and `suite_AFTER.txt` (mtime 2026-09-08 22:45:05 +0200). Full-cycle delta ≈ 8 minutes,
  well inside the ~1h Tier B machine-time budget (`project-context.md` "Machine-time budget").
- Suite cadence: the full suite ran exactly TWICE (BEFORE / AFTER), per the default cadence — no
  extra full runs this pass. Targeted single-file runs (`test_card_hud.gd`, the state harness alone,
  and `test_card_tint_live.gd` itself, the last run three times across the mutation-proof cycle)
  do not count against that cadence.

**Mutation-proof table (MEASURED, not asserted):**

| Guard proven | Mutation applied | Restore method | Result |
|---|---|---|---|
| `test_card_tint_live.gd` actually catches a dropped per-panel colour (not vacuous) | `hud_root.gd`: `_set_swatch_color(i, card_colors.get(id, null))` → `_set_swatch_color(i, null)` (the colour lookup itself removed, simulating "the seam fires but the consumer swallows it") | Backup taken to a scratch path OUTSIDE the repo BEFORE mutating; SHA256 of the live file matched the backup both before mutating and after restoring (`801ba70d6b3c5509a35edec881e8780fa1759051267c1b63b42477746a3e2329` both times); restored by copying the backup back, never `git checkout --` | Mutated run: `card_tint_live: live_tint=false holed_payload=false armed_keeps=false disarmed_keeps=false ... RESULT: FAIL`. Post-restore run: `RESULT: PASS` (matches the pre-mutation baseline) |

> **Digest correction (code-review fix pass).** The table originally cited this SHA256 as
> `801ba70d...f468b804`. The prefix was right and the restore itself was real — the file was
> byte-identical to its pre-mutation state — but the quoted tail belonged to no file in this pass.
> The full digest above is the measured one. **It pins the file as of the DEV PASS.** The fix pass
> has since edited `hud_root.gd` (the geometry rework, F-3/F-4), so re-hashing the file today
> returns a different value by design; this digest documents the mutation cycle, not the file's
> current state.

### Completion Notes List

- AC 1/AC 3: colour reaches `HudRoot` as a plain `Dictionary[StringName, Enums.CardColor]`
  (`card_colors`, defaulted `{}`), the SAME map `_derive_card_colors()` produces for the
  state-injection channel (`match_runner.gd:330`) — reused via a second call at HUD-wiring time
  (`match_runner.gd:368`, `card_colors_by_id`), not a cached handle into that injection (CONSTRAINT
  C: the injected `_card_colors` is never read by this HUD path at all). `HudRoot` never names
  `CardDatabase` — confirmed by inspection of the diff and by AC 3's own precedent holding
  (`_derive_card_colors()` is the runner's one CardDatabase-reading function for colour; this story
  adds no second one).
- AC 2: rides the EXISTING `cards_changed` wrapper (`match_runner.gd:395-410`) as a 5th argument
  alongside `pending_draw_owed` — no new `connect_*` seam. `test_runner_observation_seams_are_exactly_nine`
  PASSED unedited in both suite runs, which is the machine proof.
- AC 4: no `src/state/` file changed (File List below has none) and no snapshot key added — proven
  by the unmoved 30-key set and the unmoved golden hash (see Golden Prediction AFTER values above).
- AC 5: implemented as a SEPARATE sibling control (`ColorSwatch`, a small `Panel` with its own
  UNSHARED `StyleBoxFlat` per panel) rather than folding tint into `_card_base_style`/
  `_card_armed_style`. `set_card_selection` (`hud_root.gd:516-522`) is UNCHANGED by this diff — it
  still rewrites the whole panel stylebox on every call, and because the swatch is a sibling it
  never touches, tint survives every arm/disarm cycle by construction, not by a combinatorial
  base/armed × three-colour stylebox table. Proven live by `test_card_tint_live.gd`'s
  armed/disarmed assertions (arm slot 0, confirm swatch still visible+correct colour; disarm,
  confirm again).
- AC 6: no edit anywhere near `debug_hand_contents()`, the reveal toggle, or an opponent row (there
  is none to touch — deleted at `3-6/R1`). Confirmed by `grep -n debug_hand_contents` across the
  diff's two touched source files returning nothing.
- AC 7 (Golden Prediction / Tier B escalation clause): discharged, no movement, no escalation — see
  the AFTER values block above. Tier stays B.
- Extra test requirement (beyond the story text, `3-0b/R34` runtime-composition class): satisfied by
  `test/integration/test_card_tint_live.gd`, new this story — per-panel colour assertion against a
  REAL live-dealt hand (not a hand-built payload alone), a mixed holed payload proving the three
  untinted cases (`Hand.EMPTY`, permanent hole, in-flight) stay untinted in the SAME call as two
  real tinted slots, and the armed/disarmed AC 5 interaction. Proven non-vacuous by the mutation
  table above.
- Live Smoke: left to the operator per this pass's own scope instruction — `docs/playtest-log.md`
  was not written by this dev pass. The one remaining unchecked Tasks/Subtasks item is that entry,
  deliberately.
- **Replay and the tint (operator disposition, code-review fix pass).** The code review confirmed
  that the HUD-wiring block — and therefore `_derive_card_colors()` at `match_runner.gd:368` — runs
  on BOTH the replay and the live path, unlike the state-injection call at `:330`, which `5-2`
  deliberately confines to the non-replay branch. That is accepted as designed: **presentation-side
  tint MAY read static `CardDatabase` content on the replay path**, on the same footing as the
  caption, which already renders recorded ids using today's presentation. The invariant that
  matters is narrower than the runner's old comment claimed, and the comment has been reworded to
  say it precisely: STATE and DETERMINISM never read `CardDatabase` under replay; presentation does,
  and under replay reflects TODAY's database. One consequence is accepted and documented rather
  than guarded — a recorded id absent from today's database has no colour entry, so its swatch
  stays hidden while the caption still shows the id. Nothing in the golden or the replay record
  depends on the tint, so this is not a determinism concern.

### File List

- `src/main/match_runner.gd` — modified: `_derive_card_colors()`'s existing map re-derived at
  HUD-wiring time (`card_colors_by_id`) and threaded through the `cards_changed` wrapper lambda as
  a 5th argument to `hud.on_cards_changed`.
- `src/ui/hud/hud_root.gd` — modified: `_own_card_swatches`/`_own_card_swatch_styles` fields added;
  `_build_hand_row()` builds one `ColorSwatch` sibling panel per card panel; `on_cards_changed()`
  gains a `card_colors` parameter (defaulted `{}`) and calls the new `_set_swatch_color()`; the
  three untinted cases (`Hand.EMPTY`, permanent hole via the `else` branch, in-flight) all route
  through `_set_swatch_color(i, null)`.
- `test/integration/test_card_tint_live.gd` — new: the story's extra per-panel HUD-side test
  requirement (see Completion Notes). Reworked by the fix pass — dynamic occupied-slot selection,
  a comparison counter, and a hard-coded palette pin (F-1, F-2, F-10).
- `docs/implementation-artifacts/deferred-work.md` — modified by the fix pass: one new entry under
  a `6-0-card-hand-tint` code-review heading, carrying F-9 (the `ORB_COLORS` upper-bound guard)
  forward to whichever story next touches the `CardColor` enum or the shared palette.

## Review Findings

Code review run 2026-09-08 against the dev-pass working tree at HEAD `f8b7a35`. Two parallel
adversarial layers plus an acceptance audit; twelve findings, dispositions below. Rulings are the
operator's and were given before this fix pass; the decision-log session for them does not exist
yet, so they are recorded here descriptively and the close-out chain will assign the numbers.

| # | Finding | Disposition |
|---|---|---|
| F-1 | `_live_tint_correct` was initialised `true` and falsified only inside a loop an all-EMPTY hand skips — a vacuous PASS was possible, and the mutation table did not cover it (the holed-payload half failed independently) | **FIXED** |
| F-2 | The test called `get_card()` on `Hand.to_array()` slots chosen blind; a hole in slot 0 or 2 returns null and `card0.color` raises SCRIPT ERROR, which `run_all.sh` treats as a failure of the WHOLE suite | **FIXED** |
| F-3 | Swatch overlapped the caption's text rect by 5 px, and the comment claiming it "never overlaps" was arithmetically false | **FIXED** |
| F-4 | Swatch occluded the top 2 px of the armed panel's inward 5 px gold bottom border across 86% of the panel width — degrading the armed tell precisely on tinted slots, the interaction AC 5 exists to protect | **FIXED** |
| F-5 | The unconditional HUD-wiring `_derive_card_colors()` call made `match_runner.gd:296`'s blanket "replay never reads CardDatabase" false | **ACCEPTED as designed**, comment reworded — see Completion Notes |
| F-6 | "Agent Model Used" recorded the commit-trailer constant instead of the model that ran | **FIXED** |
| F-7 | Mutation table cited a SHA256 whose tail matched no file in the pass (prefix was correct; the restore claim itself was true) | **FIXED** |
| F-8 | Duplicated empty `## Change Log` heading at EOF (Edit-tool residue) | **FIXED** |
| F-9 | `ORB_COLORS[color as int]` has no upper-bound guard — unreachable today (3 entries, 3 enum members), but an out-of-domain colour crashes mid-frame inside a signal handler while every other branch degrades gracefully | **DEFERRED** to `deferred-work.md`; owner = the first story touching the `CardColor` enum or the shared palette |
| F-10 | Every assertion computed its expectation with production's own `ORB_COLORS[card.color]` expression, so a permuted palette would have passed | **FIXED** |
| F-11 | Frame race: the manual refill at `OBSERVE_FRAME+1` can be overwritten by a real `cards_changed` before `OBSERVE_FRAME+2` reads it | **NOTED, NO ACTION.** The refill's colour map is now total over occupied slots (incidental to the F-2 rewrite), but the race itself stands — it is excluded only by "headless P1 has no input", not by construction. |
| F-12 | `_set_swatch_color` guards `index >= size` but not a negative index, asymmetrically | **NOTED, NO ACTION.** The sole caller iterates `for i in _own_card_labels.size()`, so `index >= 0` always; not a live defect. |

**Geometry, as reworked (F-3/F-4).** Computed against the panel's real 84x92 box, with the true
numbers now carried in `hud_root.gd`'s own comments rather than the false claim they replaced:

| element | before | after |
|---|---|---|
| caption text rect | y in [4, 88] | y in [4, 79] |
| colour swatch | y in [83, 89] | y in [80, 86] |
| armed border, bottom band (inward 5 px) | y in [87, 92] | y in [87, 92] |

The swatch now clears the caption above it and the armed tell below it by one pixel each;
horizontally x in [6, 78] already cleared the border's side bands. The caption's bottom inset gave
up the room (-4.0 to -13.0), costing it roughly one wrapped line at `font_size 12`; ellipsis
overrun was already configured. **Whether the bar reads at a glance remains the operator smoke's
call (`PROC/R8`)** — the arithmetic only proves nothing collides.

**No machine-side layout check exists for the hand row.** `test_hud_viewports.gd`,
`test_card_hud.gd` and `test_card_selection_indicator.gd` assert node presence and stylebox
properties, never rects, so there was no geometry test to run against this rework — the three were
run anyway as regression cover and all pass.

## Change Log

- 2026-09-08: Dev pass complete. AC 1-7 implemented; Golden Prediction clause discharged (both
  values unmoved); full suite 720/0/5363 state + 56/56 integration, both BEFORE and AFTER runs
  PASS; new integration test `test_card_tint_live.gd` added and proven non-vacuous by a verified
  mutation/restore cycle. Live Smoke intentionally left for the operator. Status -> review.
- 2026-09-08: Code-review fix pass. Twelve findings triaged (see Review Findings): seven fixed, one
  accepted-as-designed with the runner comment reworded, one deferred to `deferred-work.md`, two
  noted without action, one — F-5 — carrying an operator ruling. Code changes are presentation-only
  and confined to `hud_root.gd` (swatch/caption geometry) plus comment text in `match_runner.gd`;
  `test_card_tint_live.gd` was reworked to remove a crash class and a vacuity hole and to add a
  palette pin. **Targeted tests only, deliberately:** every edit is presentation-side or
  comment-only, no `src/state/` file is touched, and the golden and snapshot key set cannot move
  from a swatch offset — so the four affected integration files were run directly and the full
  suite is left to the commit chain, which runs it regardless. Status stays `review` pending the
  operator's live smoke.
