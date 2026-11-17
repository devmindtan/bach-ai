extends RefCounted
## Unit tests for skill amounts: counts per level, the "amount" stat card adding
## one to every skill, and Enemies.nearest_n for multi-target casts.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(cls: String, levels: Dictionary) -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes[cls]
	r.pool = GameData.load_json("res://assets/data/" + String(classes[cls]["upgrades"]))
	r.base_stats = classes[cls]["stats"]
	r.levels = levels
	r._recompute_stats()
	return r


func test_aoe_skills_cast_more_with_level() -> void:
	var r := _run("knight", {"earth_strike": 1})
	var sk: Dictionary = r.pool["skills"]
	var one: int = r._skill_count("earth_strike", sk["earth_strike"])
	r.levels["earth_strike"] = 5
	var five: int = r._skill_count("earth_strike", sk["earth_strike"])
	_check(one == 1 and five >= 3, "earth strike: 1 at level 1, >= 3 at level 5 (got %d, %d)" % [one, five])
	r.free()


func test_amount_card_adds_one_to_every_skill() -> void:
	var r := _run("mage", {"arcane_bolt": 1, "fireball": 1})
	var sk: Dictionary = r.pool["skills"]
	var before: int = r._skill_count("fireball", sk["fireball"])
	r.levels["multicast"] = 2
	r._recompute_stats()
	_check(r._skill_count("fireball", sk["fireball"]) == before + 2, "multicast 2: +2 fireballs")
	_check(r._skill_count("arcane_bolt", sk["arcane_bolt"]) == 1 + 2, "and +2 bolts")
	r.free()


func test_nearest_n_sorted() -> void:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 10.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	var e := Enemies.new(monsters, {"max_enemies": 10, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	e.spawn("blob", Vector2(300, 0))
	e.spawn("blob", Vector2(100, 0))
	e.spawn("blob", Vector2(200, 0))
	var n := e.nearest_n(Vector2.ZERO, 2)
	_check(n.size() == 2 and n[0] == 1 and n[1] == 2, "two nearest, closest first, got %s" % [n])
