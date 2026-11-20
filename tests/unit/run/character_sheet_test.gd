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
	_check(is_equal_approx(float(cd["base"]), 1.0), "cooldown base x1.00 (a multiplier on every skill), got %s" % cd["base"])
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
	_check(is_equal_approx(float(whirl["cooldown"]), 6.4 * 0.8), "whirlwind 6.4 s * 0.8, got %s" % whirl["cooldown"])
	var srcs: Array = whirl["sources"].map(func(p: Dictionary) -> String: return p["id"])
	_check(srcs.has("haste") and srcs.has("sharpen"), "whirlwind lists the cards that change it, got %s" % [srcs])
	r.free()


func test_dash_cooldown_falls_with_its_card_and_haste() -> void:
	var r := _run({"blade_arc": 1, "dash": 3, "haste": 1})
	# 3.0 s base x (1 - 0.12 x 3) dash card x 0.9 haste
	_check(is_equal_approx(r.skill_cooldown("dash"), 3.0 * 0.64 * 0.9), "dash cooldown, got %s" % r.skill_cooldown("dash"))
	r.free()


func test_wave_and_column_counts_follow_the_level() -> void:
	var r := _run({"blade_arc": 1, "cleave_wave": 3, "holy_column": 5})
	var sk: Dictionary = r.pool["skills"]
	_check(r._skill_count("cleave_wave", sk["cleave_wave"]) == 2, "cleave wave 3: front + back")
	_check(r._skill_count("holy_column", sk["holy_column"]) == 4, "holy column 5: four columns (counts grow for dense hordes)")
	r.levels["cleave_wave"] = 1
	_check(r._skill_count("cleave_wave", sk["cleave_wave"]) == 1, "cleave wave 1: one wave")
	r.free()


func test_cooldown_stat_is_one_multiplier_for_every_skill() -> void:
	# user 2026-11-17: the cooldown stat speeds up ALL skills, not only the basic attack
	var r := _run({"blade_arc": 1, "whirlwind": 1, "earth_strike": 1, "haste": 2})
	_check(is_equal_approx(float(r.base_stats["cooldown"]), 1.0), "class cooldown stat is a x1.00 multiplier")
	_check(is_equal_approx(float(r.stats["cooldown"]), 0.8), "haste 2: x0.80, got %s" % r.stats["cooldown"])
	for sid in ["blade_arc", "whirlwind", "earth_strike"]:
		var own := float(r.pool["skills"][sid]["cooldown"])
		_check(is_equal_approx(r.skill_cooldown(sid), own * 0.8), "%s: own %.2f s x 0.8, got %.2f" % [sid, own, r.skill_cooldown(sid)])
	_check(r._fmt_stat("cooldown", 0.8) == "-20%", "shown as a percentage, got %s" % r._fmt_stat("cooldown", 0.8))
	r.free()
