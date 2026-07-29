extends TestCase

## Story 2-6 (AC 1, 2-6/R5/R6): the round-over label's two seats on HudRoot —
## on_round_ended is the single SET seat, on_round_started the single CLEAR seat. This pins
## the CLEAR seat NON-VACUOUSLY: it does NOT merely assert the label's untouched initial
## hidden state (which would pass even if on_round_started did nothing). It first drives the
## label VISIBLE through on_round_ended, THEN fires on_round_started and asserts it hides —
## so a no-op clear seat fails here.
##
## Unit-level: HudRoot is built detached (no frame, no autoload — the state-harness
## discipline). Only the round label is constructed (_build_round_label), so the test needs
## none of the vitals/hand/pitch machinery. The live EventBus -> on_round_started wiring is
## proven separately by the instrumentation integration test and the AC 8 live smoke.

func _hud_with_label() -> HudRoot:
	var hud := HudRoot.new()
	hud._build_round_label()  # only the label; avoids the full HUD build in a headless unit test
	return hud


## The CLEAR seat, proven non-vacuous by first driving the label VISIBLE via the SET seat.
## MUTATION PROOF: make on_round_started a no-op and this FAILS at the final assertion — the
## label, driven visible by round_ended, would stay visible.
func test_round_started_clears_the_round_over_label() -> void:
	var hud := _hud_with_label()
	assert_false(hud._round_label.visible, "label starts hidden (built visible=false, no prime-on-connect)")
	# SET seat: a round ended — the label must show.
	hud.on_round_ended(1, 0)  # loser_index 1, my_slot 0 -> "YOU WIN"
	assert_true(hud._round_label.visible, "on_round_ended SET the label visible")
	assert_eq(hud._round_label.text, "YOU WIN", "SET seat wrote the outcome text")
	# CLEAR seat: a debug reset fired round_started — the label must hide again.
	hud.on_round_started()
	assert_false(hud._round_label.visible,
		"on_round_started CLEARED the label (fails if the clear seat is a no-op)")
	hud.free()


## The SET seat's counterpart outcome (a symmetric guard so the SET text is not accidentally
## fixed): the losing viewport reads "YOU LOSE", and a subsequent reset still clears it.
func test_set_seat_lose_text_then_clear() -> void:
	var hud := _hud_with_label()
	hud.on_round_ended(0, 0)  # loser_index 0 == my_slot 0 -> "YOU LOSE"
	assert_true(hud._round_label.visible, "SET seat visible on a loss")
	assert_eq(hud._round_label.text, "YOU LOSE", "loser viewport reads YOU LOSE")
	hud.on_round_started()
	assert_false(hud._round_label.visible, "reset clears the loss label too")
	hud.free()
