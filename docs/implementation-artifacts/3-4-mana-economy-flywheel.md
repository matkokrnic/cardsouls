# Story 3.4: Mana economy and the melee→mana flywheel

Status: ready-for-dev

> **⚠ E3 REVISIT GATE applies (see 3.1 for the full verbatim gate).** These E3 stories are provisional and must be reviewed against `docs/playtest-log.md` after the first E1/E2 playtest, before implementation — confirm, amend, or delete, and record the outcome in `decision-log.md`.
>
> **Revisit note (this story).** Provisional — confirm or amend against `docs/playtest-log.md` before implementing. Whether melee-funded mana feels like a flywheel or like bookkeeping is precisely what the first playtest tells you.

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want melee hits to fund mana through an authored `.tres` rule with no new call site, and the `melee_mana_generation` flag to degrade gracefully,
so that the P2 aggression flywheel is observable in play and both flag paths remain playable.

## Acceptance Criteria

1. Mana sources are authored as `ResourceGenerationRule` `.tres`: `passive_tick` (a fixed per-tick amount converted once at load, never `rate × delta`) and `melee_hit` (a burst on a confirmed contact). The Mana Accelerator totem (E4) must be addable later as a third `.tres` with no code change.
2. The melee-hit rule wires into the hook 1.5 already calls on confirmed contact. No new call site, no new branch in combat code — the rule simply now exists where before there was none.
3. `FeatureFlag: melee_mana_generation` is graceful degradation: off → the passive rule alone applies and the game stays playable, with no error and no special-case path. The flags resource is injected into state; state never reads `FeatureFlagsService`.
4. `ManaPool` regen and bounds complete through the injected config, with a queued `mana_changed` signal connected to the mana bar the E2 HUD already renders.
5. Headless tests cover the flag matrix: with the flag on, N landed hits produce the authored mana; with it off, only passive accrues; the pool clamps at max; the evaluator applies exactly the rules matching a source and ignores the rest.

## Tasks / Subtasks

- [ ] Author `passive_tick` + `melee_hit` `ResourceGenerationRule` `.tres` (AC: 1)
- [ ] Attach the `melee_hit` rule to the existing 1.5 hook — no new call site/branch (AC: 2)
- [ ] Implement `melee_mana_generation` flag graceful degradation (off → passive only) (AC: 3)
- [ ] Complete `ManaPool` regen/bounds + queued `mana_changed`; connect to the E2 mana bar (AC: 4)
- [ ] Flag-matrix headless tests (on/off, clamp, source filtering) (AC: 5)

## Dev Notes

- The test of whether this story was done right: the Mana Accelerator totem (E4) is a **new `.tres`, no code change**. That is D6's economy-wide, data-defined scope. [Source: stories-manual-e3.md#E3.S4 item 1; docs/game-architecture.md#D6; #Novel Pattern 5]
- No new call site — 1.5 already lands the hook; E3 authors the rule. [Source: stories-manual-e1.md#E1.S5; stories-manual-e3.md#E3.S4 item 2]
- Fixed per-tick passive amount, never `rate × delta`. [Source: docs/game-architecture.md#D2 A1 follow-up]

### Project Structure Notes

- Rules `.tres` under `data/` (rules/balance); evaluator `src/state/economy/economy_evaluator.gd`; `ManaPool` in `src/state/pools/`.

### Project Context Rules

- **Feature flags / graceful degradation; state reads injected `FeatureFlags`, never the service.** [Source: docs/project-context.md#HARD RULE — Feature flags]
- **Flag matrix testing:** both ON and OFF paths asserted. [Source: docs/project-context.md#Testing Rules]

### References

- [Source: stories-manual-e3.md#E3.S4]
- [Source: gdd.md#B Mana Economy; #P2]
- [Source: docs/game-architecture.md#D6; #Novel Pattern 5]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
