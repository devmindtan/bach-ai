extends RefCounted
## Integration: every reference between the data files in assets/data resolves
## (class -> upgrade pool, wave -> monster, skill/monster/class -> sprite).

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const BEHAVIOURS := ["chase", "swarm", "charge", "boss_slime", "shoot", "zigzag", "boss_tree", "hop", "support"]

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
	var used := {}
	for f in DirAccess.get_files_at(DATA + "waves"):
		if not f.ends_with(".json"):
			continue
		var stage := GameData.load_json(DATA + "waves/" + f)
		_check(float(stage.get("duration", 0)) > 0.0, "%s has no duration" % f)
		for w: Dictionary in stage.get("waves", []):
			# "<id>@elite" spawns the elite of <id> (run_config.json elite)
			var m := String(w.get("monster", "")).trim_suffix("@elite")
			used[m] = true
			_check(monsters.has(m), "%s: wave monster %s not in monsters.json" % [f, m])
	for m: String in monsters:
		if m.begins_with("_"):
			continue
		_check(used.has(m), "monster %s is never spawned (orphan)" % m)
		_check(_sprite_ok(String(monsters[m].get("sprite", ""))), "monster %s: sprite missing" % m)
		_check(BEHAVIOURS.has(monsters[m].get("behaviour", "")), "monster %s: unknown behaviour" % m)
		if monsters[m].get("behaviour", "") == "shoot":   # a shooter needs its bolt sprite
			_check(_sprite_ok(String(monsters[m].get("bolt_sprite", ""))), "monster %s: bolt_sprite missing" % m)


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
	for id: String in items.get("pickups", {}):
		var d: Dictionary = items["pickups"][id]
		_check(String(d.get("name", "")) != "", "item %s has no name" % id)
		_check(_sprite_ok(String(d.get("sprite", ""))), "item %s: sprite missing" % id)
	# equipment: an icon in gear-icons, a known slot, one class, effects PlayerStats knows;
	# every class has exactly one item per slot and rarity (design/equipment.md)
	var icons := SpriteSheet.load_dir(SPRITES + "gear-icons", "gear-icons")
	var grid := {}
	var eq: Dictionary = items.get("equipment", {})
	for id: String in eq:
		if id.begins_with("_"):
			continue
		var d: Dictionary = eq[id]
		_check(String(d.get("name", "")) != "", "equipment %s has no name" % id)
		_check(Profile.SLOTS.has(String(d.get("slot", ""))), "equipment %s: unknown slot %s" % [id, d.get("slot")])
		_check(icons.has_animation(String(d.get("icon", id))), "equipment %s: icon %s not in gear-icons" % [id, d.get("icon", id)])
		_check(not Dictionary(d.get("effects", {})).is_empty(), "equipment %s has no effects" % id)
		_check(["knight", "mage"].has(String(d.get("class", ""))), "equipment %s: no class (every item fits one class)" % id)
		var key := "%s/%s/%s" % [d.get("class"), d.get("slot"), d.get("rarity")]
		_check(not grid.has(key), "two items for %s: %s and %s" % [key, grid.get(key), id])
		grid[key] = id
	for cls in ["knight", "mage"]:
		for slot: String in Profile.SLOTS:
			for r in ["common", "rare", "epic", "legendary"]:
				_check(grid.has("%s/%s/%s" % [cls, slot, r]), "no %s %s %s item" % [cls, slot, r])


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


## Level milestone rewards (design/progression.md): every level offers each class
## three things to pick from, and each one is real data — a unique skill in the
## class pool, a passive with its numbers, a rule that the run reads.
func test_milestones_offer_three_real_rewards_per_class() -> void:
	var m := GameData.load_json(DATA + "milestones.json")
	var icons := SpriteSheet.load_dir(SPRITES + "ui-icons", "ui-icons")
	var classes := GameData.load_json(DATA + "classes.json")
	var offered := {}       # unique skill id -> level
	for key: String in m.get("levels", {}):
		var n := int(key)
		for cid: String in classes:
			if cid.begins_with("_"):
				continue
			var ids: Array[String] = Milestones.new(m).offers(n, cid)
			_check(ids.size() == 3, "level %d offers %s %d rewards, want 1 of 3" % [n, cid, ids.size()])
			for id in ids:
				var r: Dictionary = m.get("rewards", {}).get(id, {})
				_check(not r.is_empty(), "level %d offers unknown reward %s" % [n, id])
				_check(["skill", "passive", "rule"].has(String(r.get("kind", ""))), "%s: unknown kind" % id)
				var shown := Milestones.new(m).info(id, [])
				if String(r.get("kind", "")) == "skill":
					# a skill reward shows its card's name and description
					var pool := GameData.load_json(DATA + String(classes[cid].get("upgrades", "")))
					shown = Milestones.new(m).info(id, pool.get("upgrades", []))
				_check(String(shown.get("name", "")) != "" and String(shown.get("desc", "")) != "",
					"%s: needs a Vietnamese name and a description" % id)
				var icon := String(r.get("icon", id))
				_check(icons != null and icons.has_animation(icon), "%s: icon %s not in ui-icons" % [id, icon])
				if String(r.get("kind", "")) == "skill":
					var sk := String(r.get("skill", id))
					var pool := GameData.load_json(DATA + String(classes[cid].get("upgrades", "")))
					var u := {}
					for up: Dictionary in pool.get("upgrades", []):
						if String(up.get("id", "")) == sk:
							u = up
					_check(not u.is_empty(), "%s: %s is not in the %s pool" % [id, sk, cid])
					_check(bool(u.get("unique", false)), "%s: %s must be marked unique (not a normal card)" % [id, sk])
					_check(int(u.get("max_level", 1)) > 1, "%s: a unique skill is levelled by cards" % id)
					_check(String(r.get("class", "")) == cid, "%s: skill reward must name its class" % id)
					_check(not offered.has(sk), "%s is already a reward of level %s" % [sk, offered.get(sk)])
					offered[sk] = n
				else:
					_check(not r.has("class"), "%s: only skill rewards belong to one class" % id)
					var has_key := false
					for k: String in r:
						has_key = has_key or (k != "kind" and k != "name" and k != "desc" and k != "icon")
					_check(has_key, "%s: needs numbers or effects the run can use" % id)
	# every unique skill in a pool is a milestone reward, so none is unreachable
	for cid: String in classes:
		if cid.begins_with("_"):
			continue
		var pool := GameData.load_json(DATA + String(classes[cid].get("upgrades", "")))
		for up: Dictionary in pool.get("upgrades", []):
			if bool(up.get("unique", false)):
				_check(offered.has(String(up["id"])), "unique skill %s is no milestone reward (unreachable)" % up["id"])


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
			# a card may borrow another card's icon with "icon"
			var icon_id := String(u.get("icon", u["id"]))
			_check(icons.has_animation(icon_id), "upgrade %s has no icon '%s' in ui-icons (draw it in Sprite Lab)" % [u["id"], icon_id])


## User 2026-11-17: as time passes the early monsters thin out and stronger ones
## take over. In every stage the weakest normal monster spawns, over the last 20%
## of the stage, at under 60% of its own peak rate, and the average hp of what
## spawns late is clearly higher than early.
func test_stages_shift_to_stronger_monsters_over_time() -> void:
	var monsters := GameData.load_json(DATA + "monsters.json")
	for f in DirAccess.get_files_at(DATA + "waves"):
		if not f.ends_with(".json"):
			continue
		var stage := GameData.load_json(DATA + "waves/" + f)
		var dur := float(stage.get("duration", 300.0))
		var waves: Array = stage.get("waves", [])
		var rates := func(t: float) -> Dictionary:
			var r := {}
			for w: Dictionary in waves:
				var id := String(w.get("monster", ""))
				if id.ends_with("@elite") or bool(monsters.get(id, {}).get("boss", false)):
					continue
				r[id] = float(r.get(id, 0.0)) + WaveScheduler.rate_at(w, t)
			return r
		var weakest := ""
		for id: String in rates.call(dur * 0.5):
			if weakest == "" or float(monsters[id]["hp"]) < float(monsters[weakest]["hp"]):
				weakest = id
		var peak := 0.0
		var late := 0.0
		for k in 101:
			var t := dur * k / 100.0
			var r: float = rates.call(t).get(weakest, 0.0)
			peak = maxf(peak, r)
			if t >= dur * 0.8:
				late = maxf(late, r)
		_check(late < peak * 0.6, "%s: weakest %s still spawns at %.2f/s late (peak %.2f/s); thin it out" % [f, weakest, late, peak])
		var avg_hp := func(t: float) -> float:
			var n := 0.0
			var hp := 0.0
			var r: Dictionary = rates.call(t)
			for id: String in r:
				n += float(r[id])
				hp += float(r[id]) * float(monsters[id]["hp"])
			return hp / maxf(0.001, n)
		_check(avg_hp.call(dur * 0.9) > avg_hp.call(dur * 0.25) * 1.3,
			"%s: late spawns are not stronger (avg hp %.1f early, %.1f late)" % [f, avg_hp.call(dur * 0.25), avg_hp.call(dur * 0.9)])


## A flying skill (cast wave / projectile) moves its sprite itself, so it must fly a
## sprite made for flight: "fly_" animations (the art holds still, a hitbox per
## direction), never a strike's "sweep_" / "slash_" ones, whose art moves inside the
## frame. (2026-11-17: Sóng kiếm flew the cleave-wave strike; the hitbox, one box
## over all frames, sat off the blade.)
func test_flying_skills_use_flight_animations() -> void:
	var classes := GameData.load_json(DATA + "classes.json")
	for cid: String in classes:
		if cid.begins_with("_"):
			continue
		var pool := GameData.load_json(DATA + String(classes[cid].get("upgrades", "")))
		for sk: String in pool.get("skills", {}):
			var p: Dictionary = pool["skills"][sk]
			if not ["wave", "projectile"].has(String(p.get("cast", ""))):
				continue
			var prefix := String(p.get("anim_prefix", "fly_"))
			_check(prefix == "fly_", "%s flies '%s' animations: a flying skill needs a flight sprite (fly_*)" % [sk, prefix])
			for n: Variant in p.get("tier_sprites", [p.get("sprite", "")]):
				var meta := GameData.load_json(SPRITES + String(n) + "/" + String(n) + ".json")
				var has_fly := false
				for a: Dictionary in meta.get("animations", []):
					has_fly = has_fly or String(a.get("name", "")).begins_with("fly_")
				_check(has_fly, "%s: sprite %s has no fly_ animations" % [sk, n])


## A self-cast skill plays an animation its sprite really has: "nearest" plays the
## anim_prefix direction toward its target, "self" and "random" play "anim"
## (default burst). god_hammer used to ask for "burst" while its sprite only had
## strike_*, so it drew nothing and hit nothing (2026-11-17).
func test_casts_play_an_animation_their_sprite_has() -> void:
	var classes := GameData.load_json(DATA + "classes.json")
	for cid: String in classes:
		if cid.begins_with("_"):
			continue
		var pool := GameData.load_json(DATA + String(classes[cid].get("upgrades", "")))
		for sk: String in pool.get("skills", {}):
			var p: Dictionary = pool["skills"][sk]
			var how := String(p.get("cast", ""))
			if not ["nearest", "self", "random"].has(how):
				continue
			var prefix := String(p.get("anim_prefix", ""))
			var anim := String(p.get("anim", "burst"))
			for n: Variant in p.get("tier_sprites", [p.get("sprite", "")]):
				var meta := GameData.load_json(SPRITES + String(n) + "/" + String(n) + ".json")
				var names: Array[String] = []
				for a: Dictionary in meta.get("animations", []):
					names.append(String(a.get("name", "")))
				if how == "nearest" and prefix != "":
					var has_dir := false
					for d in ["right", "left", "up", "down"]:
						has_dir = has_dir or names.has(prefix + d)
					_check(has_dir, "%s: sprite %s has no %s* direction animations for its nearest cast" % [sk, n, prefix])
				else:
					_check(names.has(anim), "%s: sprite %s has no '%s' animation (the %s cast draws nothing)" % [sk, n, anim, how])


## User 2026-11-18: a monster that jumps needs a jump animation (not a sliding sprite).
func test_jumping_monsters_have_crouch_and_jump_animations() -> void:
	var monsters := GameData.load_json("res://assets/data/monsters.json")
	for id: String in monsters:
		var m: Variant = monsters[id]
		# every leaper: hoppers and the jumping bosses; Vua Thạch Nhầy's sprite predates the rule (to redraw)
		if not m is Dictionary or id in ["king_slime"]:
			continue
		var leaps: bool = String(m.get("behaviour", "")) in ["hop", "boss_slime"] or m.has("hop_height")
		if not leaps:
			continue
		var name := String(m.get("sprite", id))
		var meta := GameData.load_json("res://assets/sprites/custom/%s/%s.json" % [name, name])
		var anims: Array = []
		for a: Dictionary in meta.get("animations", []):
			anims.append(String(a.get("name", "")))
		_check(anims.has("crouch") and anims.has("jump"), "%s (%s) jumps: needs crouch + jump animations, has %s" % [id, name, anims])
		_check(m.has("hop_height"), "%s jumps: needs hop_height so the sprite rises" % id)
