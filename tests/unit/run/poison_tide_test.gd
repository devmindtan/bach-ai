extends RefCounted
## Nước độc dâng (design/region-events-plan.md §4C, §8): marsh pools first, telegraph safe, swell,
## hold, sink, gems; a way out stays open.

const CFG := {"pools": 3, "range": 280.0, "grow": 1.5, "radius": 110.0, "hold": 7.0, "dps": 6.0, "gems": 2}

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_rises_holds_sinks_and_drops_gems() -> void:
	var t := PoisonTide.new()
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var pools := [{"p": Vector2(100, 0), "r": 30.0}, {"p": Vector2(900, 0), "r": 30.0}]
	t.start(CFG, Vector2.ZERO, pools, r)
	_check(t.spots.size() == 3, "3 pools (%d)" % t.spots.size())
	_check(t.spots[0]["p"] == Vector2(100, 0), "the marsh's own pool in range comes first")
	_check(not t.inside(Vector2(100, 0)), "telegraph hurts nobody")
	for i in 60:   # 3 s: warn + grow
		t.step(0.05)
	_check(t.phase == "hold" and t.inside(Vector2(100, 100)), "risen to 110 px")
	_check(not t.inside(Vector2(-300, -300)), "a way out stays open")
	for i in 200:
		t.step(0.05)
	_check(not t.busy() and t.dropped.size() == 2, "sunk, 2 gems dropped")
