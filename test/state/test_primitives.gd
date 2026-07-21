extends TestCase

## Item 3(a) coverage: TimingWindow + SignalQueue + InputIntent + Enums.

func test_seconds_to_ticks_rounds() -> void:
	assert_eq(TimingWindow.seconds_to_ticks(0.1), 6, "0.1s * 60Hz = 6 ticks")


func test_seconds_to_ticks_min_one_clamp() -> void:
	assert_eq(TimingWindow.seconds_to_ticks(0.001), 1, "sub-tick non-zero still opens")
	assert_eq(TimingWindow.seconds_to_ticks(0.0), 0, "zero stays zero")


func test_timing_window_counts_ticks() -> void:
	var w := TimingWindow.new()
	w.start(3)
	w.tick()
	w.tick()
	assert_eq(w.remaining_ticks(), 1)
	assert_true(w.is_running, "running at 2/3")
	w.tick()
	assert_false(w.is_running, "stopped at 3/3")
	assert_eq(int(w.to_snapshot()["elapsed_ticks"]), 3)


func test_signal_queue_drains_in_push_order() -> void:
	var q := SignalQueue.new()
	var acc: Array[int] = []
	q.push(func() -> void: acc.append(1))
	q.push(func() -> void: acc.append(2))
	assert_false(q.is_empty())
	q.drain()
	assert_eq(acc, [1, 2] as Array[int])
	assert_true(q.is_empty(), "empty after drain")


func test_input_intent_fresh_and_isolated() -> void:
	var a := InputIntent.new()
	var b := InputIntent.new()
	assert_ne(a, b, "distinct instances")
	a.held[&"p1_move_up"] = true
	assert_true(a.is_held(&"p1_move_up"))
	assert_false(b.is_held(&"p1_move_up"), "no aliasing between fresh intents")


func test_enums_card_color() -> void:
	assert_eq(Enums.CardColor.RED, 0)
	assert_eq(Enums.CardColor.GREEN, 2)
