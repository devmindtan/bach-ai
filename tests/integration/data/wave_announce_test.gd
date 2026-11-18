extends RefCounted
## Big bursts, elites and bosses are called out before they arrive (design 6A
## wave pacing): every such wave has an "announce" banner text.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _needs_call(w: Dictionary) -> bool:
	var m := String(w.get("monster", ""))
	return int(w.get("burst", 0)) >= 10 or m.ends_with("@elite") or m == "king_slime"


func test_big_waves_are_announced() -> void:
	var dir := DirAccess.open("res://assets/data/waves")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var d := GameData.load_json("res://assets/data/waves/" + f)
		for w: Dictionary in d.get("waves", []):
			if _needs_call(w):
				_check(String(w.get("announce", "")) != "", "%s: %s at %ss needs \"announce\"" % [f, w.get("monster"), w.get("t_from")])
	var c := GameData.load_json("res://assets/data/challenges.json")
	for ch: Dictionary in c.get("challenges", []):
		for w: Dictionary in ch.get("add", []):
			if _needs_call(w):
				_check(String(w.get("announce", "")) != "", "challenge %s: %s at %ss needs \"announce\"" % [ch.get("id"), w.get("monster"), w.get("t_from")])
