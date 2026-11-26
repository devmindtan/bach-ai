extends RefCounted
## LPC heroes (user 2026-11-23 trial, run_config hero_art "lpc"): every class's lpc_sprite exists as a side-view sheet
## with the animations the run plays, its anchor on the feet and a body circle.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_every_class_has_a_playable_lpc_sprite() -> void:
	var classes := GameData.load_json("res://assets/data/classes.json")
	for cid: String in classes:
		if cid.begins_with("_"):
			continue
		var name := String(classes[cid].get("lpc_sprite", ""))
		if name == "":   # user 2026-11-25: heroes are the user's drawings; LPC was a trial, a class may have none
			continue
		var sh := SpriteSheet.load_dir("res://assets/sprites/custom/" + name, name)
		_check(sh != null, "%s: no sheet %s (run gamekit sprites)" % [cid, name])
		if sh == null:
			continue
		for a in ["idle", "run", "hurt", "dash", "death"]:
			_check(sh.has_animation(a), "%s: %s has no %s" % [cid, name, a])
		_check(sh.meta.has("body"), "%s: %s has no body circle" % [cid, name])
		_check(float(sh.anchor.y) > 48.0, "%s: anchor %s is not at the feet" % [cid, sh.anchor])


## User 2026-11-23: the knight's shield vanished while standing still. LPC weapons and shields have no idle / run rows,
## so idle and dash frames taken from those rows lose them; they must come from rows every layer has (walk).
func test_idle_and_dash_keep_weapons_and_shields() -> void:
	var classes := GameData.load_json("res://assets/data/classes.json")
	for cid: String in classes:
		if cid.begins_with("_"):
			continue
		var name := String(classes[cid].get("lpc_sprite", ""))
		var sh := SpriteSheet.load_dir("res://assets/sprites/custom/" + name, name)
		if sh == null or sh.texture == null:
			continue
		var img := sh.texture.get_image()
		img.decompress()
		var walk := _opaque(img, sh.frame_index("run", 0.0))
		for a in ["idle", "hurt", "dash"]:
			var n := _opaque(img, sh.frame_index(a, 0.0))
			_check(n >= walk * 0.92, "%s: %s frame has %d opaque px vs %d walking (a weapon or shield is missing)" % [cid, a, n, walk])


func _opaque(img: Image, index: int) -> int:
	var n := 0
	for y in 64:
		for x in 64:
			if img.get_pixel(index * 64 + x, y).a > 0.0:
				n += 1
	return n
