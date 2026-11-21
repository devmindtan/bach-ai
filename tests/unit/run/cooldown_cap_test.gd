extends RefCounted
## User 2026-11-20: cooldown reduction from every source together is capped at 40%
## (run_config player.cooldown_floor 0.6): no stack of cards, gear and tree makes a skill cast faster.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_cooldown_reduction_stops_at_40_percent() -> void:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	var base := float(r.pool["skills"]["whirlwind"]["cooldown"])
	_check(is_equal_approx(r.skill_cooldown("whirlwind", {"cooldown": 0.8}), base * 0.8), "-20%% stays -20%%")
	_check(is_equal_approx(r.skill_cooldown("whirlwind", {"cooldown": 0.3}), base * 0.6), "-70%% is cut to -40%%, got %.2f of %.2f" % [r.skill_cooldown("whirlwind", {"cooldown": 0.3}), base])
	_check(is_equal_approx(r.skill_cooldown("whirlwind", {"cooldown": 0.7, "skill_cd.whirlwind": 0.7}), base * 0.6), "card + stat together also capped")
	r.free()


func test_aoe_cooldowns_doubled_and_projectiles_raised() -> void:
	var k: Dictionary = GameData.load_json("res://assets/data/upgrades_knight.json")["skills"]
	var m: Dictionary = GameData.load_json("res://assets/data/upgrades_mage.json")["skills"]
	_check(is_equal_approx(float(k["whirlwind"]["cooldown"]), 6.4), "Lốc xoáy 3.2 -> 6.4 s")
	_check(is_equal_approx(float(m["meteor"]["cooldown"]), 10.0), "Mưa thiên thạch 5 -> 10 s")
	_check(is_equal_approx(float(m["fireball"]["cooldown"]), 3.25), "Cầu lửa 2.6 -> 3.25 s (x1.25)")
	_check(is_equal_approx(float(k["blade_arc"]["cooldown"]), 0.9) and is_equal_approx(float(m["arcane_bolt"]["cooldown"]), 1.0),
		"starting skills keep their cooldown")


func test_character_sheet_shows_the_capped_cooldown() -> void:
	# bug 2026-11-21: the sheet showed "Hồi chiêu -65%" while every cast was capped at -40%
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = {"cooldown": 1.0}
	r.levels = {"haste": 10}
	var bd: Dictionary = r.stat_breakdown()
	_check(float(bd["cooldown"]["final"]) >= float(r.cfg["player"]["cooldown_floor"]) - 0.001,
		"sheet cooldown capped, got %s" % bd["cooldown"]["final"])
	r.free()
