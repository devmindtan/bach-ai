extends RefCounted
## Integration: every player-facing "name" in assets/data/*.json is Vietnamese
## (user 2026-11-17: skill names in the game are all Vietnamese; ids and file
## names stay English). A name must contain a Vietnamese letter with a mark;
## the few Vietnamese names written without marks are listed here on purpose.

const DATA := "res://assets/data/"
const NO_MARK_OK := ["Nhanh tay", "Tinh hoa", "Nhanh"]

var failures: Array[String] = []


func _walk(v: Variant, file: String, path: String) -> void:
	if v is Dictionary:
		for k: Variant in v:
			var x: Variant = v[k]
			if String(k) == "name" and x is String and not NO_MARK_OK.has(x):
				var marked := false
				for ch in String(x):
					if ch.unicode_at(0) > 127:
						marked = true
						break
				if not marked:
					failures.append("%s%s: name '%s' is not Vietnamese (use a Vietnamese name; ids stay English)" % [file, path, x])
			_walk(x, file, path + "." + String(k))
	elif v is Array:
		for i in v.size():
			_walk(v[i], file, "%s[%d]" % [path, i])


func test_every_name_in_data_is_vietnamese() -> void:
	for f in DirAccess.get_files_at(DATA):
		if f.ends_with(".json"):
			_walk(GameData.load_json(DATA + f), f, "")


func test_every_monster_has_a_name() -> void:
	# bug 2026-11-22: slime / bat / goblin had no "name" at all, so the stage panel and the dashboard showed the ids;
	# the check above only reads the names that exist
	var mons := GameData.load_json(DATA + "monsters.json")
	for id: String in mons:
		if mons[id] is Dictionary:
			if String(mons[id].get("name", "")) == "":
				failures.append("monster %s has no Vietnamese name" % id)
