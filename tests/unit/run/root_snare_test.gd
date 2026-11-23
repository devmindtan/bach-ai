extends RefCounted
## Rễ trói (design/region-events-plan.md §4B, replaced Cây đổ 2026-11-23): lines from a tree toward the
## player, each bursts once after `warn`, hits what stands on it.

const CFG := {"waves": 4, "interval": 2.2, "warn": 1.0, "range": 320.0, "length": 220.0, "width": 28.0, "linger": 1.2}

var failures: Array[String] = []


func test_four_lines_burst_once_each_toward_the_player() -> void:
	var s := RootSnare.new()
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var feet := [Vector2(150, 0), Vector2(0, 160), Vector2(900, 0)]
	s.start(CFG)
	var burst := []
	for i in 300:   # 15 s
		burst.append_array(s.step(0.05, Vector2.ZERO, feet, r))
	if burst.size() != 4:
		failures.append("4 lines should burst, got %d" % burst.size())
	for ln: Dictionary in burst:
		if not s.hits(ln, Vector2.ZERO):
			failures.append("a line misses the spot the player stood on")
		if (ln["a"] as Vector2).distance_to(Vector2.ZERO) > 320.0:
			failures.append("roots came from a tree out of range")
	if not burst.is_empty() and s.hits(burst[0], Vector2(0, -400)):
		failures.append("far away is hit")
	if s.busy():
		failures.append("still busy after the last line sank")


func test_line_is_quiet_during_the_warning() -> void:
	var s := RootSnare.new()
	var r := RandomNumberGenerator.new()
	s.start(CFG)
	var early := s.step(0.5, Vector2.ZERO, [Vector2(150, 0)], r)
	early.append_array(s.step(0.4, Vector2.ZERO, [Vector2(150, 0)], r))
	if not early.is_empty():
		failures.append("roots burst before warn ended")
	if s.step(0.7, Vector2.ZERO, [Vector2(150, 0)], r).size() != 1:   # the line appeared at t 0 of the first step
		failures.append("roots did not burst after warn")
