extends RefCounted
## User 2026-11-20: level-ups were too quick; plain monsters drop an XP gem only 80% of the time
## (run_config balance.xp_drop_chance). Elites and bosses always drop theirs.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_plain_monsters_drop_xp_about_80_percent_and_elites_always() -> void:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	_check(is_equal_approx(float(r.cfg["balance"].get("xp_drop_chance", 1.0)), 0.8), "run_config balance.xp_drop_chance is 0.8")
	r.seed_xp_drops(42)
	var n := 0
	for k in 2000:
		if r.drops_xp(false):
			n += 1
	_check(n > 1500 and n < 1700, "about 80%% of 2000 plain kills drop XP, got %d" % n)
	var all := true
	for k in 200:
		all = all and r.drops_xp(true)
	_check(all, "elites and bosses always drop XP")
	r.free()
