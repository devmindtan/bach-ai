extends RefCounted
## Unit tests for Run.upgrade_preview: the level-up card's before -> after numbers
## and milestones come from PlayerStats on the real data.

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


func test_stat_card_shows_now_and_next_value() -> void:
	var r := _run({"blade_arc": 1})
	var pv: Dictionary = r.upgrade_preview("sharpen")
	_check(pv["lines"].size() == 1, "sharpen changes one stat")
	_check(pv["lines"][0][1] == "20" and pv["lines"][0][2] == "23", "damage 20 -> 23 (+15%%), got %s" % [pv["lines"][0]])
	_check(pv["milestone"] == "", "level 1 of 5 is not a milestone")
	r.free()


func test_skill_card_damage_and_tier_milestone() -> void:
	var r := _run({"blade_arc": 1, "earth_strike": 1})
	var pv: Dictionary = r.upgrade_preview("earth_strike")
	_check(String(pv["milestone"]).begins_with("Bậc II"), "earth_strike 1 -> 2 reaches tier II, got '%s'" % pv["milestone"])
	_check(pv["lines"][0][0] == "Sát thương" and int(pv["lines"][0][2]) > int(pv["lines"][0][1]), "skill damage grows, got %s" % [pv["lines"][0]])
	r.free()


func test_last_level_is_a_milestone() -> void:
	var r := _run({"blade_arc": 1, "haste": 4})
	var pv: Dictionary = r.upgrade_preview("haste")
	_check(String(pv["milestone"]).ends_with("Cấp tối đa"), "haste 4 -> 5 is the last level, got '%s'" % pv["milestone"])
	_check(pv["milestones"].has(5), "level 5 marked as milestone")
	r.free()
