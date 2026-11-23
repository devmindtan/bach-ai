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
		_check(name != "", "%s has no lpc_sprite" % cid)
		var sh := SpriteSheet.load_dir("res://assets/sprites/custom/" + name, name)
		_check(sh != null, "%s: no sheet %s (run gamekit sprites)" % [cid, name])
		if sh == null:
			continue
		for a in ["idle", "run", "hurt", "dash", "death"]:
			_check(sh.has_animation(a), "%s: %s has no %s" % [cid, name, a])
		_check(sh.meta.has("body"), "%s: %s has no body circle" % [cid, name])
		_check(float(sh.anchor.y) > 48.0, "%s: anchor %s is not at the feet" % [cid, sh.anchor])
