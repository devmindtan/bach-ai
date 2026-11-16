class_name GameData
extends RefCounted
## Loads the data-driven JSON under res://assets/data/.
##
## Example:
##   var monsters := GameData.load_json("res://assets/data/monsters.json")


## Returns the parsed object, or an empty Dictionary (with an error logged)
## when the file is missing or is not a JSON object.
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Data not found: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Data is not a JSON object: %s" % path)
	return {}
