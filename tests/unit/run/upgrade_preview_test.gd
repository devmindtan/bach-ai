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


# Regression (user 2026-11-18 screenshot): with lasting bonuses (skill tree,
# equipment, milestones, buffs) the "after" side was computed from the cards
# alone, so it showed a drop: Máu tối đa 105 -> 100, Hồi máu 2.0/s -> 0.5/s,
# Cầu lửa damage 59 -> 47. "After" must start from the same sources as "now".
func _run_with_tree(levels: Dictionary, nodes: Array) -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r.class_id = "knight"
	r.levels = levels
	var slot := Slot.new({})
	slot.cls = "knight"
	slot.tree.assign(nodes)
	r.tree_owner = slot
	r._recompute_stats()
	return r


func test_after_keeps_lasting_bonuses_for_stat_cards() -> void:
	var r := _run_with_tree({"blade_arc": 1}, ["k_root", "k_b2_1", "k_b2_2", "k_b2_3"])
	var hp_now := float(r.stats["max_hp"])
	var pv: Dictionary = r.upgrade_preview("vitality")
	_check(int(pv["lines"][0][1]) == roundi(hp_now), "now = current max hp %d, got %s" % [roundi(hp_now), pv["lines"][0]])
	_check(int(pv["lines"][0][2]) > int(pv["lines"][0][1]), "Sinh lực raises max hp, got %s" % [pv["lines"][0]])
	var rg: Dictionary = r.upgrade_preview("regen")
	var now_rg := float(String(rg["lines"][0][1]).trim_suffix("/s"))
	var next_rg := float(String(rg["lines"][0][2]).trim_suffix("/s"))
	_check(next_rg > now_rg, "Hồi phục raises regen, got %s" % [rg["lines"][0]])
	r.free()


func test_after_keeps_lasting_bonuses_for_skill_cards() -> void:
	var r := _run_with_tree({"blade_arc": 1, "earth_strike": 2}, ["k_root", "k_b0_1", "k_b0_2", "k_b0_3"])
	var pv: Dictionary = r.upgrade_preview("earth_strike")
	_check(pv["lines"][0][0] == "Sát thương" and int(pv["lines"][0][2]) >= int(pv["lines"][0][1]),
		"skill damage never drops on its own card, got %s" % [pv["lines"][0]])
	for line: Array in pv["lines"]:
		if line[0] == "Cỡ":
			_check(float(String(line[2]).trim_prefix("×")) >= float(String(line[1]).trim_prefix("×")), "size never drops, got %s" % [line])
	r.free()


func test_skill_card_shows_cooldown() -> void:
	var r := _run({"blade_arc": 1, "earth_strike": 1})
	var pv: Dictionary = r.upgrade_preview("earth_strike")
	var names: Array = pv["lines"].map(func(l: Array) -> String: return l[0])
	_check(names.has("Hồi chiêu"), "a skill card lists its cooldown, got %s" % [names])
	r.free()


# Regression (2026-11-20 screenshot): the level-up card said Sát thương 17 -> 20 (balance x0.85)
# while the Tab character sheet said 20: the sheet read PlayerStats.breakdown without the balance.
func test_character_sheet_uses_the_balanced_stats() -> void:
	var r := _run({"blade_arc": 1})
	r.cfg = {"balance": {"player_damage_mul": 0.85, "player_area_mul": 0.9}}
	r._recompute_stats()
	var bd: Dictionary = r.stat_breakdown()
	_check(is_equal_approx(float(bd["damage"]["final"]), float(r.stats["damage"])), "sheet damage %s = run damage %s" % [bd["damage"]["final"], r.stats["damage"]])
	_check(is_equal_approx(float(bd["area"]["final"]), float(r.stats["area"])), "sheet area %s = run area %s" % [bd["area"]["final"], r.stats["area"]])
	r.free()
