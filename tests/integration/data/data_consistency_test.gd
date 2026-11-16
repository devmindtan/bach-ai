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


func test_pickup_sprites_exist() -> void:
	for name in ["exp-gem", "gold-coin"]:
		_check(_sprite_ok(name), "pickup sprite %s missing" % name)
