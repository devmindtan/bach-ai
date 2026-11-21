extends RefCounted
## User 2026-11-21: in-run challenges were too hard and too few. New kinds: Săn tinh anh (kill a marked elite in
## time) and Thu thập sao (pick every star in time); the ring is easier (run_config events.ring).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_collect_stars_done_when_all_picked_fail_when_late() -> void:
	var c := FieldChallenge.new()
	c.start_collect([Vector2(100, 0), Vector2(-100, 0)], 20.0, 24.0)
	_check(c.step(1.0, Vector2(100, 0), false) == "", "one star picked, one left")
	_check(c.stars.size() == 1, "the picked star is gone")
	_check(c.step(1.0, Vector2(-100, 0), false) == "done", "the last star completes it")
	c.start_collect([Vector2(500, 0)], 3.0, 24.0)
	_check(c.step(3.5, Vector2.ZERO, false) == "fail", "time out fails")


func test_hunt_done_when_the_mark_dies_fail_when_late() -> void:
	var c := FieldChallenge.new()
	c.start_hunt(25.0)
	_check(c.step(1.0, Vector2.ZERO, true) == "", "the marked elite still lives")
	_check(c.step(1.0, Vector2.ZERO, false) == "done", "it died: done")
	c.start_hunt(2.0)
	_check(c.step(2.5, Vector2.ZERO, true) == "fail", "still alive at the limit: fail")


func test_the_ring_is_easier_and_regions_have_several_kinds() -> void:
	var ring: Dictionary = GameData.load_json("res://assets/data/run_config.json")["events"]["ring"]
	_check(float(ring["radius"]) >= 100.0 and float(ring["need"]) <= 5.0 and float(ring["limit"]) >= 40.0, "ring easier: %s" % [ring])
	for r: Dictionary in GameData.load_json("res://assets/data/stages.json")["regions"]:
		var kinds := {}
		for e: Dictionary in r.get("events", []):
			kinds[e["kind"]] = true
		_check(kinds.size() >= 3, "%s has 3+ kinds of events, got %s" % [r["name"], kinds.keys()])
