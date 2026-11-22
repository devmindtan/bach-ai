extends RefCounted
## User 2026-11-20: monsters grow stronger at each minute mark of a run (1:00, 2:00, ...): monsters
## spawned after a mark have more hp, and every monster hits harder (run_config time_scale).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_monster_stats_step_up_at_each_minute_mark() -> void:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.stage_number = 6   # growth starts at time_scale.min_stage (user 2026-11-22); no stages: the fallback rates
	var ts: Dictionary = r.cfg.get("time_scale", {})
	_check(float(ts.get("every", 0.0)) == 60.0, "a step every 60 s")
	var hp0: float = r.time_mul(0.0, "hp")
	_check(is_equal_approx(hp0, 1.0) and is_equal_approx(r.time_mul(59.9, "hp"), 1.0), "no change before 1:00")
	_check(is_equal_approx(r.time_mul(60.0, "hp"), 1.0 + float(ts["hp"])), "hp steps up at 1:00")
	_check(is_equal_approx(r.time_mul(125.0, "damage"), 1.0 + 2.0 * float(ts["damage"])), "damage two steps at 2:05")
	_check(r.time_mul(240.0, "hp") > r.time_mul(180.0, "hp"), "keeps growing each minute")
	r.free()


func test_spawned_monsters_take_the_hp_step_but_bosses_do_not() -> void:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 100.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2},
		"king": {"sprite": "blob", "behaviour": "chase", "hp": 1000.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2, "boss": true}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	var e := Enemies.new(monsters, {"max_enemies": 10, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	e.spawn_hp_mul = 1.3
	e.spawn("blob", Vector2(300, 0))
	e.spawn("king", Vector2(-300, 0))
	_check(is_equal_approx(e.hp[0], 130.0), "a plain monster spawned after a mark: 130 hp, got %s" % e.hp[0])
	_check(is_equal_approx(e.hp[1], 1000.0), "the boss keeps 1000 hp, got %s" % e.hp[1])
