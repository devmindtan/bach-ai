extends RefCounted
## Every item is drawn on its class's hero (user 2026-11-18: wearing armour must show,
## not the default look): sprite-lab hero-gear layers exist for it and change the
## composed hero.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_every_item_has_layers_on_its_hero_and_changes_it() -> void:
	var classes := GameData.load_json("res://assets/data/classes.json")
	var eq: Dictionary = GameData.load_json("res://assets/data/items.json")["equipment"]
	var bare := {}
	for id: String in eq:
		if id.begins_with("_"):
			continue
		var cls := String(eq[id].get("class", ""))
		var sprite := String(classes[cls].get("sprite", ""))
		var sh := SpriteSheet.load_dir("res://assets/sprites/custom/" + sprite, sprite)
		if not bare.has(cls):
			sh.compose_layers()
			bare[cls] = sh.texture.get_image()
		var over := sh.gear_overrides([id])
		_check(not over.is_empty(), "%s: no gear layers under %s/gear/%s" % [id, sprite, id])
		sh.compose_layers(over)
		var img := sh.texture.get_image()
		_check(img.get_data() != bare[cls].get_data(), "%s: wearing it does not change the %s" % [id, sprite])
		_check(sh.hires_texture == null, "%s: a stale hires copy would hide the gear" % sprite)

