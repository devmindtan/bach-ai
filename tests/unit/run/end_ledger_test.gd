extends RefCounted
## End report detail (user 2026-11-22, roadmap B): the run records damage taken by source, damage prevented by
## source (armor, the class passive, the stone ward), heals by source, and the passive's indirect damage.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run() -> Node:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.stats = {"armor": 15.0, "max_hp": 100.0}
	r.hp = 100.0
	r._armor_k = 15.0
	return r


func test_a_hit_splits_into_taken_and_prevented() -> void:
	var r := _run()
	r._take_hit(40.0, "event.tornado")
	_check(is_equal_approx(float(r.taken_by.get("event.tornado", 0.0)), 20.0), "taken by the tornado: 20, got %s" % [r.taken_by])
	_check(is_equal_approx(float(r.reduced_by.get("armor", 0.0)), 20.0), "armor prevented 20, got %s" % [r.reduced_by])
	r._take_hit(10.0)
	_check(r.taken_by.has("monster"), "a plain hit counts as monster")
	r.free()


func test_heals_are_kept_by_source() -> void:
	var r := _run()
	r.hp = 50.0
	r.heal_max(0.1, "sp_aegis_gauntlets")
	_check(is_equal_approx(float(r.heal_by.get("sp_aegis_gauntlets", 0.0)), 10.0), "Huyết quyền healed 10, got %s" % [r.heal_by])
	r.free()


func test_the_passive_bonus_is_counted_as_indirect_damage() -> void:
	var m: Dictionary = GameData.load_json("res://assets/data/monsters.json")["spore"].duplicate()
	m["hp"] = 1000.0
	var sheet := SpriteSheet.from_meta("spore", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 23.0],
		"body": {"anim": "default", "center": [12.0, 17.0], "radius": 7.0}})
	var e := Enemies.new({"spore": m}, {"max_enemies": 4, "separation": {"push": 0.0}}, {"spore": sheet}, 1)
	e.spawn("spore", Vector2.ZERO)
	e.vs_status_mul = 0.2
	e.slow_t[0] = 1.0
	e.hit_circle(Vector2.ZERO, 30.0, 100.0, 0.0, "arcane_bolt")
	_check(is_equal_approx(float(e.bonus_by.get("vs_status", 0.0)), 20.0), "the passive added 20 on a slowed monster, got %s" % [e.bonus_by])


func test_ledger_rows_are_named_in_vietnamese() -> void:
	var r := _run()
	r.class_data = {"passive": {"name": "Bất khuất"}}
	var rows: Array = r.ledger_rows({"armor": 30.0, "passive": 10.0, "monster": 5.0})
	_check(rows.size() == 3 and rows[0]["name"] == "Giáp" and rows[1]["name"] == "Bất khuất", "names, largest first: %s" % [rows])
	_check(is_equal_approx(float(rows[0]["share"]), 30.0 / 45.0), "share of the total")
	r.free()
