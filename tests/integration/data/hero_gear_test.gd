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
		if String(classes[cls].get("gear_art", "")) == "pending":   # gear pictures still to be drawn (see the next test)
			continue
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


## Classes whose hero waits for gear pictures (classes.json gear_art "pending") are listed here so they are not
## forgotten: this test only allows the user's 2026-11-25 knight; any other pending class fails.
func test_pending_gear_art_is_only_the_new_knight() -> void:
	var classes := GameData.load_json("res://assets/data/classes.json")
	for cid: String in classes:
		if cid.begins_with("_"):
			continue
		if String(classes[cid].get("gear_art", "")) == "pending":
			_check(cid == "knight", "%s waits for gear pictures too (only the new knight may)" % cid)
