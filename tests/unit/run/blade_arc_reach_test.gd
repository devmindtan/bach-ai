extends RefCounted
## User 2026-11-21: Chém kiếm lands farther out (not on top of the hero) and scales harder on base
## damage than the mage's basic spell (melee risk).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_slash_sits_ahead_and_hits_harder_than_the_bolt() -> void:
	var k: Dictionary = GameData.load_json("res://assets/data/upgrades_knight.json")["skills"]["blade_arc"]
	var m: Dictionary = GameData.load_json("res://assets/data/upgrades_mage.json")["skills"]["arcane_bolt"]
	_check(float(k.get("damage_mul", 1.0)) > float(m.get("damage_mul", 1.0)), "blade_arc mul above arcane_bolt")
	_check(float(k.get("offset", 0.0)) >= 24.0, "blade_arc pushed out from the hero")
	var r: Node = Run.new()
	var fx := {"follow": true, "offset": Vector2(30, 0)}
	_check(r._fx_pos(fx) == r.player_pos + r._hit_center + Vector2(30, 0), "a following fx keeps its offset")
	r.free()
