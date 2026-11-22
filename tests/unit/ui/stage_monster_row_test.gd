extends RefCounted
## User 2026-11-22: the stage panel's monster row spilled past the panel; it shows at most MONSTER_ROW boxes.

const StageSelect := preload("res://src/front/stage_select.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_monster_row_is_capped() -> void:
	_check(StageSelect.MONSTER_ROW <= 5, "at most 5 boxes in the row")
	var mons := {"a": {}, "b": {}, "c": {}, "d": {}, "e": {}, "f": {}}
	var st := {"waves": [{"monster": "a"}, {"monster": "b@elite"}, {"monster": "a"}, {"monster": "c"}, {"monster": "d"},
		{"monster": "e"}, {"monster": "f"}, {"monster": "zz"}]}
	_check(StageSelect.stage_monsters(st, mons) == ["a", "b", "c", "d", "e", "f"], "first appearance order, known ids, no repeats")
