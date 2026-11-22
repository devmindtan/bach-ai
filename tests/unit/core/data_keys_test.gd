extends RefCounted
## Roadmap tech debt 5 (defaults): code reads data with `x.get("key", default)`, so a key renamed in the JSON
## (or misspelt) is silently ignored and the default is used. Every key of the monsters, skills and equipment
## entries must be read somewhere in src/ ("_doc"-style keys and the listed meta keys excepted).

const META := ["_doc", "name", "desc", "icon"]

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_files(dir + "/" + sub, out)


func _read_keys() -> Dictionary:
	var files: Array[String] = []
	_files("res://src", files)
	var re := RegEx.create_from_string("\"([a-z_][a-z_0-9]*)\"")
	var keys := {}
	for path in files:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			keys[m.get_string(1)] = true
	return keys


func _unread(entries: Dictionary, read: Dictionary, what: String) -> Array:
	var bad := []
	for id: String in entries:
		if not entries[id] is Dictionary:
			continue
		for k: String in entries[id]:
			if k.begins_with("_") or k in META or read.has(k):
				continue
			bad.append("%s %s.%s" % [what, id, k])
	return bad


func test_every_data_key_is_read_by_the_code() -> void:
	var read := _read_keys()
	var bad := []
	bad.append_array(_unread(GameData.load_json("res://assets/data/monsters.json"), read, "monsters"))
	for f in ["upgrades_knight.json", "upgrades_mage.json"]:
		bad.append_array(_unread(GameData.load_json("res://assets/data/" + f).get("skills", {}), read, f))
	bad.append_array(_unread(GameData.load_json("res://assets/data/items.json").get("equipment", {}), read, "items"))
	_check(bad.is_empty(), "keys no code reads (renamed or misspelt?): %s" % ", ".join(bad))
