extends RefCounted
## Elite affixes (design 6A): every elite rolls one; Nhanh moves faster, Giáp takes
## less damage, Phân thân splits into plain monsters, Bùng nổ leaves a blast.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var cfg: Dictionary = GameData.load_json("res://assets/data/run_config.json").duplicate(true)
	cfg["max_enemies"] = 30
	cfg["separation"] = {"push": 0.0}
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 10.0, "damage": 5.0, "speed": 40.0, "xp": 1.0, "scale": 2}}
	var sheet := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	return Enemies.new(monsters, cfg, {"blob": sheet}, 1)


func _elite_with(e: Enemies, aid: String, p: Vector2) -> int:
	e.spawn("blob@elite", p)
	var i := e.count - 1
	e.affix[i] = e.affix_ids.find(aid)
	return i


func test_every_elite_rolls_an_affix_plain_monsters_none() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(50, 0))
	e.spawn("blob@elite", Vector2(-50, 0))
	_check(e.affix[0] == -1, "plain monster: no affix")
	_check(e.affix[1] >= 0 and e.affix_label(1)[0] != "", "elite: one named affix")


func test_fast_moves_faster() -> void:
	var e := _enemies()
	var a := _elite_with(e, "armored", Vector2(300, 0))
	var b := _elite_with(e, "fast", Vector2(-300, 0))
	e.step(0.5, Vector2.ZERO, Vector2.ZERO)
	var da := 300.0 - e.pos[a].length()
	var db := 300.0 - e.pos[b].length()
	_check(db > da * 1.4, "Nhanh covers more ground: %.1f vs %.1f" % [db, da])


func test_armored_takes_less_damage() -> void:
	var e := _enemies()
	var i := _elite_with(e, "armored", Vector2(40, 0))
	e.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	var before := e.hp[i]
	e.hit_circle(Vector2(40, 0), 30.0, 10.0, 0.0, "t")
	_check(is_equal_approx(before - e.hp[i], 5.5), "Giáp takes 55%%, lost %.2f" % (before - e.hp[i]))


func test_splitter_spawns_plain_monsters_and_explosive_leaves_a_blast() -> void:
	var e := _enemies()
	_elite_with(e, "splitter", Vector2(40, 0))
	_elite_with(e, "explosive", Vector2(-40, 0))
	e.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	e.hit_circle(Vector2.ZERO, 80.0, 9999.0, 0.0, "t")
	e.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	var plain := 0
	for k in e.count:
		if e.kind_ids[e.kind[k]] == "blob" and e.state[k] != Enemies.DYING:
			plain += 1
	_check(plain == 3, "Phân thân: 3 plain blobs, got %d" % plain)
	_check(e.blast_pos.size() == 1, "Bùng nổ: one warning ring, got %d" % e.blast_pos.size())
