extends RefCounted
## Item icons come from gear-icons (user 2026-11-25: the knight's new item icons did not show). Older 16 px ui-icons
## frames share six item ids (steel_chest, wizard_hat...) and were found first, hiding the gear icon.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_every_item_icon_is_the_gear_icon() -> void:
	var eq: Dictionary = GameData.load_json("res://assets/data/items.json")["equipment"]
	var gear := UiIcons.gear()
	for id: String in eq:
		if id.begins_with("_"):
			continue
		var icon := String(eq[id].get("icon", id))
		var t := UiIcons.texture(icon) as AtlasTexture
		_check(t != null and gear != null and t.atlas == gear.texture, "%s: icon %s is not taken from gear-icons" % [id, icon])
