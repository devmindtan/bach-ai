extends RefCounted
## Regression (2026-11-17, user: "Sóng kiếm xuyên qua quái mà không hề gây dame"): a
## flying effect plays a looping animation for longer than one loop (the sword wave
## lives 0.9 s, its fly loop is ~0.4 s). The hitbox must stay active on every loop,
## not only on the first one.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_looping_animation_hitbox_stays_active_after_first_loop() -> void:
	var sheet := SpriteSheet.load_dir("res://assets/sprites/custom/sword-wave", "sword-wave")
	_check(sheet != null and sheet.has_animation("fly_000"), "sword-wave has fly_000")
	if sheet == null:
		return
	var hb := SpriteHitbox.of(sheet, "fly_000", Vector2.ZERO, 2.0)
	var loop := sheet.duration("fly_000")
	_check(hb.is_active(0.05), "active in the first loop")
	_check(hb.is_active(loop + 0.05), "active in the second loop (t = %.2f, loop %.2f)" % [loop + 0.05, loop])
	_check(hb.is_active(0.85), "active near the end of the wave's 0.9 s life")


func test_one_shot_animation_hitbox_ends() -> void:
	var sheet := SpriteSheet.load_dir("res://assets/sprites/custom/sword-wave", "sword-wave")
	if sheet == null:
		return
	var hb := SpriteHitbox.of(sheet, "impact", Vector2.ZERO, 2.0)
	_check(not hb.is_active(sheet.duration("impact") + 0.5), "a one-shot (impact) hitbox stays off after its frames")


func test_sword_wave_hits_a_monster_beyond_its_first_loop() -> void:
	# a still monster 260 px away: the wave (300 px/s) reaches it after ~0.8 s, in its second fly loop
	var Run := load("res://src/run/run.gd")
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r.levels = {"cleave_wave": 1}
	r._recompute_stats()
	var ts: Dictionary = r.pool["skills"]["cleave_wave"]
	for n: String in ts["tier_sprites"]:
		r.sheets[n] = SpriteSheet.load_dir("res://assets/sprites/custom/" + n, n)
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 1000.0, "damage": 0.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	r.enemies = Enemies.new(monsters, {"max_enemies": 10, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	var dist := float(ts.get("speed", 300.0)) * 0.8
	r.enemies.spawn("blob", r._hit_center + Vector2(dist, 0))
	var hp0: float = r.enemies.hp[0]
	r._cast("cleave_wave", ts, "wave")
	_check(not r._fx.is_empty(), "the wave was cast")
	for _k in 60:
		r._step_fx(1.0 / 60.0)
	_check(r.enemies.hp[0] < hp0, "the wave hurt the monster %d px away (hp %.0f -> %.0f)" % [dist, hp0, r.enemies.hp[0]])
	r.free()
