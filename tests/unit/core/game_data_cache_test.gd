extends RefCounted
## Review 2026-11-21: load_json re-parsed the same file at every call. It caches by path + modified time and
## hands out deep copies, so one caller's edits never leak into another's data.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_cached_data_is_a_private_copy_and_follows_file_changes() -> void:
	var a := GameData.load_json("res://assets/data/monsters.json")
	a["slime"]["hp"] = -1.0
	var b := GameData.load_json("res://assets/data/monsters.json")
	_check(float(b["slime"]["hp"]) > 0.0, "a caller's change does not leak into the next load")
	var path := "user://cache_test.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"v": 1}')
	f.close()
	_check(int(GameData.load_json(path)["v"]) == 1, "first version read")
	OS.delay_msec(1100)   # modified time has 1 s resolution
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"v": 2}')
	f.close()
	_check(int(GameData.load_json(path)["v"]) == 2, "a rewritten file is read again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
