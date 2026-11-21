class_name GameData
extends RefCounted
## Loads the data-driven JSON under res://assets/data/.
##
## Example:
##   var monsters := GameData.load_json("res://assets/data/monsters.json")


## Returns the parsed object, or an empty Dictionary (with an error logged)
## when the file is missing or is not a JSON object.
## Parsed files are cached by path and modified time (review 2026-11-21: 39 call sites re-parsed the same
## files); every call gets its own deep copy, so a caller may change what it receives.
static var _cache := {}   # path -> [modified_time, Dictionary]


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Data not found: %s" % path)
		return {}
	var mtime := FileAccess.get_modified_time(path)
	var hit: Variant = _cache.get(path)
	if hit != null and int(hit[0]) == mtime:
		return (hit[1] as Dictionary).duplicate(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_cache[path] = [mtime, parsed]
		return (parsed as Dictionary).duplicate(true)
	push_error("Data is not a JSON object: %s" % path)
	return {}


## Forgets every cached file (tests that rewrite data in place).
static func clear_cache() -> void:
	_cache.clear()
