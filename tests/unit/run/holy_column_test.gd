extends RefCounted
## Cột thánh quang redesign (2026-11-22, user: ugly and weak): columns land on the thickest crowds
## ("cast": "crowd"), several columns on different crowds, instead of random monsters.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_columns_pick_the_thickest_crowds_apart() -> void:
	var pts: Array = [Vector2(500, 0)]   # a lone monster
	for k in 6:
		pts.append(Vector2(0, 0) + Vector2(k * 6, 0))      # a crowd of 6
	for k in 3:
		pts.append(Vector2(0, 300) + Vector2(k * 6, 0))    # a crowd of 3
	var pick: Array = Run.crowd_pick(pts, 40.0, 2)
	_check(pick.size() == 2, "two columns")
	_check((pts[pick[0]] as Vector2).y == 0.0 and (pts[pick[0]] as Vector2).x < 100.0, "first on the crowd of 6")
	_check((pts[pick[1]] as Vector2).y == 300.0, "second on the next crowd, not the same one")
	var ts: Dictionary = GameData.load_json("res://assets/data/upgrades_knight.json")["skills"]["holy_column"]
	_check(String(ts.get("cast", "")) == "crowd", "holy_column casts on crowds")
