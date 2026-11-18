extends RefCounted
## Hiệu ứng đặc biệt of legendary items in a run (design/equipment.md): timed
## pulse / chain shock / shield / cooldown reset, Phản chấn on a hit taken, and
## the one-time revive.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run() -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r.levels = {"blade_arc": 1}
	var items := GameData.load_json("res://assets/data/items.json")
	r.buffs = Buffs.new(items.get("buffs", {}), {}, 1)
	r.profile = Profile.new(items["equipment"])
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 1000.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	r.enemies = Enemies.new(monsters, {"max_enemies": 20, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	r._recompute_stats()
	r.hp = float(r.stats["max_hp"])
	return r


func _spawn(r: Node, points: Array) -> void:
	for p: Vector2 in points:
		r.enemies.spawn("blob", p)
	r.enemies.step(0.0001, Vector2(0, 900), Vector2(0, 900))


func _special(id: String) -> Dictionary:
	var sp: Dictionary = GameData.load_json("res://assets/data/items.json")["equipment"][id]["special"].duplicate()
	sp["item"] = id
	return sp


func test_pulse_fires_every_n_seconds_around_the_hero() -> void:
	var r := _run()
	_spawn(r, [Vector2(60, 0), Vector2(500, 0)])
	var sp := _special("aegis_blade")
	r.set_specials([sp])
	r.step_specials(float(sp["every"]) - 0.1)
	_check(is_equal_approx(r.enemies.hp[0], 1000.0), "not yet")
	r.step_specials(0.2)
	_check(r.enemies.hp[0] < 1000.0, "near monster hit, hp %s" % r.enemies.hp[0])
	_check(is_equal_approx(r.enemies.hp[1], 1000.0), "far monster untouched")
	_check(r.damage_report()[0]["name"] == String(sp["name"]), "damage report names the special, got %s" % r.damage_report()[0]["name"])
	r.free()


func test_chain_shock_hits_the_nearest_ones() -> void:
	var r := _run()
	_spawn(r, [Vector2(40, 0), Vector2(80, 0), Vector2(600, 0)])
	var sp := _special("void_crown")
	sp["count"] = 2
	r.trigger_special(sp)
	_check(r.enemies.hp[0] < 1000.0 and r.enemies.hp[1] < 1000.0, "two nearest hit")
	_check(is_equal_approx(r.enemies.hp[2], 1000.0), "the far one is not")
	r.free()


func test_shield_makes_the_hero_invulnerable() -> void:
	var r := _run()
	r.trigger_special(_special("aegis_helm"))
	_check(r.buffs.invulnerable(), "Khiên từ active")
	r.free()


func test_reset_cd_readies_every_skill() -> void:
	var r := _run()
	r._blade_cd = 3.0
	r._tier_cd["earth_strike"] = 4.0
	r._dash_cd = 2.0
	r.trigger_special(_special("void_eternal"))
	_check(r._blade_cd <= 0.0 and float(r._tier_cd["earth_strike"]) <= 0.0 and r._dash_cd <= 0.0, "all cooldowns ready")
	r.free()


func test_retaliate_on_hit_with_a_cooldown() -> void:
	var r := _run()
	_spawn(r, [Vector2(50, 0)])
	r.set_specials([_special("aegis_chest")])
	r._take_hit(5.0)
	var after_first: float = r.enemies.hp[0]
	_check(after_first < 1000.0, "the hit sends a shockwave")
	r._take_hit(5.0)
	_check(is_equal_approx(r.enemies.hp[0], after_first), "on cooldown: no second wave")
	r.step_specials(2.5)
	r._take_hit(5.0)
	_check(r.enemies.hp[0] < after_first, "after the cooldown it fires again")
	r.free()


func test_item_revive_once_per_run() -> void:
	var r := _run()
	_check(not r.try_item_revive(), "no item: no revive")
	r.set_specials([_special("void_heart")])
	r.hp = -2.0
	_check(r.try_item_revive(), "revives")
	_check(is_equal_approx(r.hp, float(r.stats["max_hp"]) * 0.4), "with 40%% hp, got %s" % r.hp)
	r.hp = 0.0
	_check(not r.try_item_revive(), "only once")
	r.free()
