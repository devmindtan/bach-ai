extends RefCounted
## Unit tests for the character sheet numbers: PlayerStats.breakdown (where each
## stat comes from) and Run.skill_info (the real damage / cooldown / size of each
## skill, the same numbers the run uses when it casts).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(levels: Dictionary) -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r.levels = levels
	r._recompute_stats()
	return r


func test_breakdown_lists_each_source_and_matches_compute() -> void:
	var r := _run({"blade_arc": 1, "haste": 4, "sharpen": 2})
	var b: Dictionary = PlayerStats.breakdown(r.base_stats, r.pool["upgrades"], r.levels)
	var cd: Dictionary = b["cooldown"]
	_check(is_equal_approx(float(cd["base"]), 0.9), "cooldown base 0.9, got %s" % cd["base"])
	_check(is_equal_approx(float(cd["final"]), float(r.stats["cooldown"])), "final equals compute()")
	_check(cd["parts"].size() == 1 and cd["parts"][0]["id"] == "haste", "one source: haste, got %s" % [cd["parts"]])
	_check(is_equal_approx(float(cd["parts"][0]["mul"]), -0.4), "haste 4 = -40%%, got %s" % cd["parts"][0]["mul"])
	var dmg: Dictionary = b["damage"]
	_check(is_equal_approx(float(dmg["parts"][0]["mul"]), 0.3), "sharpen 2 = +30%%")
	_check(not b.has("skill_damage.whirlwind"), "unowned skill keys are absent")
	r.free()


func test_skill_info_uses_the_same_numbers_as_casting() -> void:
	var r := _run({"blade_arc": 2, "whirlwind": 1, "haste": 2, "sharpen": 1})
	var info: Array = r.skill_info()
	var ids := info.map(func(s: Dictionary) -> String: return s["id"])
	_check(ids == ["blade_arc", "whirlwind"], "owned skills in pool order, got %s" % [ids])
	var blade: Dictionary = info[0]
	# 20 base * 1.15 sharpen * 1.4 (blade_arc +20% per level, level 2)
	_check(is_equal_approx(float(blade["damage"]), 20.0 * 1.15 * 1.4), "blade damage, got %s" % blade["damage"])
	_check(is_equal_approx(float(blade["cooldown"]), r.skill_cooldown("blade_arc")), "cooldown from skill_cooldown")
	_check(is_equal_approx(float(blade["cooldown"]), 0.9 * 0.8), "haste 2: 0.9 s -> 0.72 s, got %s" % blade["cooldown"])
	var whirl: Dictionary = info[1]
	_check(is_equal_approx(float(whirl["cooldown"]), 3.2 * 0.8), "whirlwind 3.2 s * 0.8, got %s" % whirl["cooldown"])
	var srcs: Array = whirl["sources"].map(func(p: Dictionary) -> String: return p["id"])
	_check(srcs.has("haste") and srcs.has("sharpen"), "whirlwind lists the cards that change it, got %s" % [srcs])
	r.free()
