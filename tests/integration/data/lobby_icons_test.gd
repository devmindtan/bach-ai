extends RefCounted
## User 2026-11-21: the lobby buttons use real vector icons (game-icons.net, CC BY 3.0), not 24 px pixel art.
## Every icon the lobby asks for exists and is credited in assets/credits (the licence requires it).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_lobby_icons_exist_and_are_credited() -> void:
	var src := FileAccess.get_file_as_string("res://src/lobby/lobby.gd")
	var credits := FileAccess.get_file_as_string("res://assets/credits/icons-game-icons-net.txt")
	var re := RegEx.create_from_string("nav_[a-z]+")
	var seen := {}
	for m in re.search_all(src):
		seen[m.get_string()] = true
	_check(seen.size() >= 9, "the lobby uses its nine icons, found %d" % seen.size())
	for id: String in seen:
		_check(ResourceLoader.exists("res://assets/icons/lobby/%s.svg" % id), "%s.svg exists" % id)
		_check(credits.contains(id + ".svg"), "%s.svg is credited" % id)
