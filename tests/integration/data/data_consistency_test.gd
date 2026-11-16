extends RefCounted
## Integration: every reference between the data files in assets/data resolves
## (class -> upgrade pool, wave -> monster, skill/monster/class -> sprite).

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const BEHAVIOURS := ["chase", "swarm", "charge"]

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _sprite_ok(name: String) -> bool:
	return FileAccess.file_exists(SPRITES + name + "/" + name + ".json") \
		and ResourceLoader.exists(SPRITES + name + "/" + name + "_strip.png")


func test_classes_reference_existing_pools_and_sprites() -> void:
	var classes := GameData.load_json(DATA + "classes.json")
	_check(not classes.is_empty(), "classes.json is empty")
	for id: String in classes:
		if id.begins_with("_"):
			continue
		var c: Dictionary = classes[id]
		_check(_sprite_ok(String(c.get("sprite", ""))), "class %s: sprite missing" % id)
		var pool := GameData.load_json(DATA + String(c.get("upgrades", "")))
		_check(not pool.is_empty(), "class %s: upgrade file missing" % id)
		var ids := {}
		for u: Dictionary in pool.get("upgrades", []):
			ids[u["id"]] = u
		for s: String in c.get("start_skills", {}):
			_check(ids.has(s), "class %s: start skill %s not in pool" % [id, s])
		for u: Dictionary in pool.get("upgrades", []):
			if u.get("kind") == "skill":
				_check(pool.get("skills", {}).has(u["id"]), "upgrade %s is a skill without a skills entry" % u["id"])
		for sk: String in pool.get("skills", {}):
			_check(ids.has(sk), "skill %s has no upgrade entry (orphan)" % sk)
			_check(_sprite_ok(String(pool["skills"][sk].get("sprite", ""))), "skill %s: sprite missing" % sk)


func test_waves_reference_existing_monsters() -> void:
	var monsters := GameData.load_json(DATA + "monsters.json")
	var stage := GameData.load_json(DATA + "waves/stage_001.json")
	_check(float(stage.get("duration", 0)) > 0.0, "stage_001 has no duration")
	var used := {}
	for w: Dictionary in stage.get("waves", []):
		var m := String(w.get("monster", ""))
		used[m] = true
		_check(monsters.has(m), "wave monster %s not in monsters.json" % m)
	for m: String in monsters:
		if m.begins_with("_"):
			continue
		_check(used.has(m), "monster %s is never spawned (orphan)" % m)
		_check(_sprite_ok(String(monsters[m].get("sprite", ""))), "monster %s: sprite missing" % m)
		_check(BEHAVIOURS.has(monsters[m].get("behaviour", "")), "monster %s: unknown behaviour" % m)


func test_monster_sprites_have_move_and_death() -> void:
	var monsters := GameData.load_json(DATA + "monsters.json")
	for m: String in monsters:
		if m.begins_with("_"):
			continue
		var name := String(monsters[m]["sprite"])
		var sheet := SpriteSheet.load_dir(SPRITES + name, name)
		_check(sheet != null and sheet.has_animation("move") and sheet.has_animation("death"),
			"monster sprite %s needs move + death" % name)


func test_items_reference_existing_sprites() -> void:
	var items := GameData.load_json(DATA + "items.json")
	for id in ["xp_gem", "gold"]:   # the two pickups run.gd drops
		_check(items.get("pickups", {}).has(id), "items.json pickups.%s missing" % id)
	for group in ["pickups", "equipment"]:
		var d: Dictionary = items.get(group, {})
		for id: String in d:
			_check(String(d[id].get("name", "")) != "", "item %s has no name" % id)
			_check(_sprite_ok(String(d[id].get("sprite", ""))), "item %s: sprite missing" % id)


func test_skill_effects_have_pixel_hitboxes() -> void:
	# hit areas come from the sprite json (measured from pixels), never from data
	var classes := GameData.load_json(DATA + "classes.json")
	for id: String in classes:
		if id.begins_with("_"):
			continue
		var pool := GameData.load_json(DATA + String(classes[id].get("upgrades", "")))
		for sk: String in pool.get("skills", {}):
			var s: Dictionary = pool["skills"][sk]
			for banned in ["range", "radius", "half_angle_deg", "fx_radius"]:
				_check(not s.has(banned), "skill %s: '%s' is hand-typed geometry; use the sprite hitbox" % [sk, banned])
			var name := String(s.get("sprite", ""))
			var sheet := SpriteSheet.load_dir(SPRITES + name, name)
			if sheet == null:
				continue
			for anim in sheet.animation_names():
				_check(sheet.animation(anim).get("hitbox") is Dictionary,
					"skill sprite %s animation %s has no hitbox" % [name, anim])


func test_bodies_come_from_sprites_not_data() -> void:
	var monsters := GameData.load_json(DATA + "monsters.json")
	for m: String in monsters:
		if m.begins_with("_"):
			continue
		_check(not monsters[m].has("radius"), "monster %s: hand-typed radius; the body is the sprite json 'body'" % m)
		var name := String(monsters[m]["sprite"])
		var sheet := SpriteSheet.load_dir(SPRITES + name, name)
		_check(sheet != null and sheet.meta.get("body") is Dictionary, "monster sprite %s has no body" % name)
	var classes := GameData.load_json(DATA + "classes.json")
	for id: String in classes:
		if id.begins_with("_"):
			continue
		_check(not classes[id].has("hit_center_y"), "class %s: hand-typed hit_center_y" % id)
		var name := String(classes[id]["sprite"])
		var sheet := SpriteSheet.load_dir(SPRITES + name, name)
		_check(sheet != null and sheet.meta.get("body") is Dictionary, "class sprite %s has no body" % name)
	_check(not GameData.load_json(DATA + "run_config.json").get("player", {}).has("hit_radius"),
		"run_config player.hit_radius is hand-typed; use the class sprite body")


func test_class_sprites_are_layered_side_view_movers() -> void:
	# Bach Ai: heroes move left/right only, attacks are effect sprites, and the
	# body is layered so armour can replace parts (design/game-brief.md).
	var classes := GameData.load_json(DATA + "classes.json")
	for id: String in classes:
		if id.begins_with("_"):
			continue
		var name := String(classes[id]["sprite"])
		var sheet := SpriteSheet.load_dir(SPRITES + name, name)
		if sheet == null:
			_check(false, "class sprite %s missing" % name)
			continue
		for anim in ["idle", "run", "hurt", "death"]:
			_check(sheet.has_animation(anim), "class sprite %s needs %s" % [name, anim])
		_check(not sheet.layer_names().is_empty(), "class sprite %s must be layered (equipment)" % name)
		for n in sheet.layer_names():
			_check(ResourceLoader.exists(SPRITES + name + "/layers/" + n + "_strip.png"),
				"class sprite %s: layer %s missing (gamekit art promote)" % [name, n])


func test_every_upgrade_has_a_card_icon() -> void:
	# the level-up card draws the ui-icons animation named like the upgrade id
	var icons := SpriteSheet.load_dir(SPRITES + "ui-icons", "ui-icons")
	_check(icons != null, "ui-icons sprite missing")
	if icons == null:
		return
	var classes := GameData.load_json(DATA + "classes.json")
	for cid: String in classes:
		if cid.begins_with("_"):
			continue
		var pool := GameData.load_json(DATA + String(classes[cid].get("upgrades", "")))
		for u: Dictionary in pool.get("upgrades", []):
			_check(icons.has_animation(String(u["id"])), "upgrade %s has no icon in ui-icons (draw it in Sprite Lab)" % u["id"])
