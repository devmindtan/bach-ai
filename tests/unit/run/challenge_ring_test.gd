extends RefCounted
## Vòng thử thách (design/events.md, after Risk of Rain 2's holdout zones): charges only while the player
## stands inside; done after `need` seconds inside; fails when the time limit runs out first.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(ring: ChallengeRing, seconds: float, player: Vector2) -> String:
	var out := ""
	for k in roundi(seconds * 10.0):
		var r := ring.step(0.1, player)
		if r != "":
			out = r
	return out


func test_charges_only_inside_and_completes() -> void:
	var ring := ChallengeRing.new()
	ring.start(Vector2(200, 0), 70.0, 8.0, 30.0)
	_check(_run(ring, 5.0, Vector2.ZERO) == "", "outside: nothing happens")
	_check(is_zero_approx(ring.progress()), "outside: no charge")
	_check(_run(ring, 4.0, Vector2(210, 10)) == "", "4 s inside: not yet")
	_check(absf(ring.progress() - 0.5) < 0.02, "half charged after 4 of 8 s, got %.2f" % ring.progress())
	_run(ring, 2.0, Vector2.ZERO)
	_check(absf(ring.progress() - 0.5) < 0.02, "leaving keeps the charge")
	_check(_run(ring, 4.2, Vector2(200, 0)) == "done", "completes after 8 s inside")
	_check(not ring.active, "a finished ring is gone")


func test_fails_when_time_runs_out() -> void:
	var ring := ChallengeRing.new()
	ring.start(Vector2(200, 0), 70.0, 8.0, 10.0)
	_check(_run(ring, 10.5, Vector2.ZERO) == "fail", "fails at the time limit")
	_check(not ring.active, "a failed ring is gone")


func test_ring_stays_inside_the_arena() -> void:
	# a ring opened near the arena edge was placed outside it, where the player could not reach it
	var ring := ChallengeRing.new()
	ring.start(Vector2(0, -1500), 70.0, 8.0, 30.0, 1400.0)
	_check(absf(ring.center.y) <= 1400.0 - 70.0, "ring centre kept inside the arena, got %s" % ring.center)
