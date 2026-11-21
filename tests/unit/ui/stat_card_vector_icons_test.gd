extends RefCounted
## User 2026-11-21: stat cards use vector icons (assets/data/card_icons.json), not pixel art.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_every_stat_card_has_a_vector_icon() -> void:
	var map: Dictionary = GameData.load_json("res://assets/data/card_icons.json")["vector"]
	for f in ["upgrades_knight.json", "upgrades_mage.json"]:
		for u: Dictionary in GameData.load_json("res://assets/data/" + f)["upgrades"]:
			if String(u.get("kind", "")) != "stat" or String(u["id"]).begins_with("sp_"):
				continue
			var id := String(u["id"])
			_check(map.has(id), id + " has a vector icon")
			_check(ResourceLoader.exists("res://assets/icons/tree/%s.svg" % map.get(id, "")), id + ": svg exists")
	var t := UiIcons.texture("haste")
	_check(t != null and t.get_size().x >= 48.0, "UiIcons.texture(haste) is the vector raster, not the 24 px pixel icon")
