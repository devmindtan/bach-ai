extends RefCounted
## User 2026-11-21: during the boss fight monsters keep coming, few but strong, and the boss's passive
## (monsters.json "aura") buffs every monster spawned while it lives (Mộc Yêu's phase 2 can feed on them).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 100.0, "damage": 10.0, "speed": 0.0, "xp": 1.0, "scale": 2},
		"king": {"sprite": "blob", "behaviour": "chase", "hp": 1000.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2, "boss": true}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	return Enemies.new(monsters, {"max_enemies": 10, "separation": {"push": 0.0}}, {"blob": blob}, 1)


func test_aura_buffs_monsters_spawned_while_the_boss_lives() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(300, 0))
	e.boss_aura = {"hp_mul": 1.5, "damage_mul": 0.3, "regen": 0.02}
	e.spawn("blob", Vector2(-300, 0))
	e.spawn("king", Vector2(0, 300))
	_check(e.buffed[0] == 0 and is_equal_approx(e.hp[0], 100.0), "spawned before the aura: plain")
	_check(e.buffed[1] == 1 and is_equal_approx(e.hp[1], 150.0), "spawned under the aura: +50%% hp, got %s" % e.hp[1])
	_check(e.buffed[2] == 0 and is_equal_approx(e.hp[2], 1000.0), "the boss itself is not buffed")
	_check(is_equal_approx(e.contact_damage(1), 13.0) and is_equal_approx(e.contact_damage(0), 10.0), "buffed monsters hit +30%%")


func test_boss_stages_keep_spawning_and_bosses_have_an_aura() -> void:
	var mons := GameData.load_json("res://assets/data/monsters.json")
	for b in ["king_slime", "tree_boss", "toad_king"]:
		var a: Dictionary = mons[b].get("aura", {})
		_check(String(a.get("name", "")) != "" and String(a.get("desc", "")) != "", "%s has a named aura" % b)
		_check(("%s: %s" % [a.get("name", ""), a.get("short", "")]).length() <= 40, "%s: the on-screen call fits (<= 40 chars)" % b)
	for n in ["010", "020", "030"]:
		var d := GameData.load_json("res://assets/data/waves/stage_%s.json" % n)
		var late := 0
		for w: Dictionary in d["waves"]:
			if float(w.get("t_to", 0)) > 300.0 and not String(w.get("monster", "")) in ["king_slime", "tree_boss", "toad_king"]:
				late += 1
		_check(late >= 2, "stage %s: escort waves after 5:00, got %d" % [n, late])
