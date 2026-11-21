extends RefCounted
## Lốc cỏ (design/region-events-plan.md §4A, §8): telegraph -> running -> over; ticks; seeds; clean restart.

const CFG := {"telegraph": 1.5, "distance": 220.0, "speed": 170.0, "radius": 70.0, "duration": 9.0, "tick": 0.5, "seeds": 3}

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	return r


func test_telegraph_then_runs_through_the_player_then_ends() -> void:
	var t := Tornado.new()
	t.start(CFG, Vector2.ZERO, _rng())
	_check(is_equal_approx(t.pos.length(), 220.0), "starts 220 px away")
	_check(t.busy() and not t.hits(t.pos), "telegraph: busy, hurts nobody")
	var ticks := 0
	var passed_player := false
	for i in 29:   # the 1.5 s telegraph, at 0.05 s steps
		if t.step(0.05):
			ticks += 1
		if t.hits(Vector2.ZERO):
			passed_player = true
	_check(ticks == 0, "no tick during the 1.5 s telegraph (%d)" % ticks)
	for i in 400:
		if t.step(0.05):
			ticks += 1
		if t.hits(Vector2.ZERO):
			passed_player = true
	_check(passed_player, "it runs through where the player stood")
	_check(ticks >= 16 and ticks <= 19, "a tick every 0.5 s over 9 s (%d)" % ticks)
	_check(not t.busy(), "over after its duration")
	_check(t.seed_spots().size() == 3, "3 seeds along its path")


func test_restart_is_clean() -> void:
	var t := Tornado.new()
	var r := _rng()
	t.start(CFG, Vector2.ZERO, r)
	for i in 300:
		t.step(0.05)
	t.start(CFG, Vector2(500, 0), r)
	_check(t.path.size() == 1 and t.busy() and t.warn_left > 0.0, "second run starts fresh")
