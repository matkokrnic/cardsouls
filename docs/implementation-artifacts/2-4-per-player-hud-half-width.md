# Story 2.4: Per-player HUD root in real half-width space

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a signal-driven HUD occupying its real half-width space with every E3–E6 element already reserved at its true footprint,
so that CardSouls discovers whether the full HUD fits the space at all, before those elements have content.

## Acceptance Criteria

1. One HUD root per viewport (`src/ui/hud/`) renders inside its own `SubViewport` at true half width. Every element is authored and evaluated at that size from the first commit — never designed full width with a resize planned later.
2. HP, stamina, and mana bars are **signal-driven** consumers of the queued state signals (`hp_changed`, `stamina_changed`, `mana_changed`). No `_process` polling, no per-frame economy recompute. The mana bar exists now and sits at its passive value until E3 gives it sources.
3. The regions E3–E6 will fill are reserved, sized, and laid out: the 4-card hand strip, three orb counters, the Pitch Zone slot with its timer, and deck/reshuffle indicators — empty placeholders occupying their real footprint.
4. P4 is applied to the layout: elements that matter under reaction pressure (stamina, incoming telegraph, pitch timer) sit near the centre of attention; elements consulted at the player's own tempo (deck count, orb totals) sit at the periphery. The rationale is written into the HUD scene as a comment.
5. Legibility is confirmed at real size: a screenshot at final resolution in which every reserved element is identifiable, plus a check that no element is clipped by the split boundary or the pulled-back camera's arena view.

## Tasks / Subtasks

- [ ] Build one HUD root per viewport at true half width (AC: 1)
- [ ] Implement HP/stamina/mana bars as signal-driven consumers; no polling (AC: 2)
- [ ] Reserve + lay out the 4-card hand, 3 orb counters, Pitch Zone slot+timer, deck/reshuffle placeholders (AC: 3)
- [ ] Apply the P4 centre/periphery layout; comment the rationale in the scene (AC: 4)
- [ ] Screenshot at final resolution; verify no clipping by split or camera (AC: 5)

## Dev Notes

- **Split-screen is a constraint, not a feature.** A HUD built full-width then squeezed is a HUD designed twice; every element gets its true half-width footprint now. [Source: stories-manual-e2.md#Epic goal; epics.md#Sequencing invariants]
- Reserving E3–E6 regions now is the point — this is the layer where CardSouls discovers whether the full HUD fits at all. This reserves footprint for E4 (orbs) and E6 (pitch) elements **without building those systems** — placeholders only. [Source: stories-manual-e2.md#E2.S4 item 3]
- HUD is signal-driven per D5: subscribes, never polls, never writes. [Source: docs/game-architecture.md#D5]

### Project Structure Notes

- `src/ui/hud/` one root per viewport; subscribes to queued state signals.

### Project Context Rules

- **Signal-driven HUD:** no per-frame economy recompute. [Source: docs/project-context.md#Signals over polling; #Performance Rules]
- **P4 / Reactor-Actor:** reaction-critical info central; own-tempo info peripheral. [Source: gdd.md#P4; #Reactor / Actor principle]

### References

- [Source: stories-manual-e2.md#E2.S4]
- [Source: gdd.md#Legibility Principle; #Asset Requirements — UI/HUD]
- [Source: docs/game-architecture.md#D5]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
