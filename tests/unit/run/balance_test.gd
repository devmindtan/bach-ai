extends RefCounted
## Global balance (run_config.json balance, user 2026-11-20: monsters too weak, hero too strong): the
## hero's damage and AoE size are scaled; cooldowns are not (the user kept them).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_hero_damage_and_area_scaled_cooldown_not() -> void:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r.cfg = {}
	r._recompute_stats()
	var plain: Dictionary = r.stats.duplicate()
	r.cfg = {"balance": {"player_damage_mul": 0.85, "player_area_mul": 0.9}}
	r._recompute_stats()
	_check(is_equal_approx(float(r.stats["damage"]), float(plain["damage"]) * 0.85), "damage x0.85")
	_check(is_equal_approx(float(r.stats["area"]), float(plain.get("area", 1.0)) * 0.9), "area x0.9")
	_check(is_equal_approx(float(r.stats.get("cooldown", 1.0)), float(plain.get("cooldown", 1.0))), "cooldown untouched")
	var b: Dictionary = GameData.load_json("res://assets/data/run_config.json")["balance"]
	_check(float(b["monster_hp_mul"]) > 1.0 and float(b["monster_damage_mul"]) > 1.0 and float(b["spawn_mul"]) < 1.0, "the shipped tuning makes fewer, stronger monsters")
	_check(not b.has("player_cooldown_mul"), "no cooldown knob: the user kept cooldowns")
	r.free()


func test_the_level_up_preview_uses_the_balanced_numbers() -> void:
	# regression: the card showed damage 17 -> 23 (the "after" skipped the balance multiplier)
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r.cfg = {"balance": {"player_damage_mul": 0.5}}
	r._recompute_stats()
	var pv: Dictionary = r.upgrade_preview("sharpen")
	var line: Array = pv["lines"][0]
	_check(float(line[2]) < float(r.base_stats["damage"]), "the next damage is balanced too, got %s" % [line])
	r.free()
