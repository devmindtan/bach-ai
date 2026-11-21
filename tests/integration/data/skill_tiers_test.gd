extends RefCounted
## User 2026-11-17/20: every skill changes its look over its five levels. Every auto skill (all but the
## player-triggered dash) lists five tier_sprites, each an existing sprite (Chém kiếm and Lốc xoáy had one
## look for every level).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_every_auto_skill_has_five_existing_tier_sprites() -> void:
	for cls in ["knight", "mage"]:
		var skills: Dictionary = GameData.load_json("res://assets/data/upgrades_%s.json" % cls)["skills"]
		for id: String in skills:
			var d: Dictionary = skills[id]
			if String(d.get("cast", "")) == "active":
				continue
			var tiers: Array = d.get("tier_sprites", [])
			_check(tiers.size() == 5, "%s %s: 5 tier sprites, got %d" % [cls, id, tiers.size()])
			for t: Variant in tiers:
				_check(FileAccess.file_exists("res://assets/sprites/custom/%s/%s.json" % [t, t]), "%s: sprite %s exists" % [id, t])
