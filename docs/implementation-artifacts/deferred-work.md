# Deferred Work

## Deferred from: code review of 3-6-card-hud-hand-mana-deck (2026-08-06)

- **CLOSED by `3-6/R8`.** Hand row hard-coded to 4 slots with silent truncation.
  `HudRoot.on_cards_changed` (`src/ui/hud/hud_root.gd`) writes `_own_card_labels[i]` for
  exactly 4 indices and silently drops any `hand_ids` entries beyond index 3, with no
  `Invariant.check`. Pre-existing since 2-5/R1 fixed the row at the presentation-local
  constant 4 (hand size is 4 at all times per the GDD) — 3-6 populated the row with content
  but did not introduce or change this assumption. Real only if `BalanceConfig.hand_size` is
  ever authored above 4 — which is exactly the window the next (playtest-tuning) phase opens.
  Closed by adding a fourth bound to `test_balance_authoring.gd::test_authored_deck_and_hand_counts_are_sane`
  (`hand_size <= 4`), so an authored 5 fails the suite loudly instead of the HUD truncating
  silently. History kept here per instruction rather than deleted.
