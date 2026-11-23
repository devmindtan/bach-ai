extends RefCounted
## Cảm giác đánh (run_config hit_feel): every hit records its source beside its position, so the run can put a
## spark on physical hits; the config names an existing spark sprite.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_hit_records_source() -> void:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 100.0, "damage": 1.0, "speed": 30.0, "xp": 1.0, "scale": 2}}
	var cfg := {"world": {"spawn_ring": [700.0, 800.0], "despawn_distance": 1300.0, "arena_half": 1400.0},
		"separation": {"cell": 48.0, "push": 60.0}, "max_enemies": 50}
	var sheet := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 5.0}})
	var e := Enemies.new(monsters, cfg, {"blob": sheet}, 1)
	e.spawn("blob", Vector2(0, 0))
	e.step(0.0001, Vector2(0, 300), Vector2(0, 300))
	e.hit_circle(Vector2(0, 0), 40.0, 5.0, 0.0, "blade_arc")
	_check(e.hit_src.size() == e.hit_pos.size() and e.hit_src.size() > 0, "hit_src does not follow hit_pos")
	_check(e.hit_src.size() > 0 and e.hit_src[0] == "blade_arc", "the hit's source is not recorded")
	e.drain_hits()
	_check(e.hit_src.is_empty(), "drain_hits keeps old sources")


func test_spark_sprites_exist() -> void:
	var hf: Dictionary = GameData.load_json("res://assets/data/run_config.json").get("hit_feel", {})
	var name := String(hf.get("sprite", ""))
	var sh := SpriteSheet.load_dir("res://assets/sprites/custom/" + name, name)
	_check(sh != null and sh.has_animation("spark"), "hit_feel.sprite %s has no spark animation" % name)


func test_album_sim_scale_matches_run() -> void:
	# Run._add_fx multiplies the scale by the sprite's px_scale; the Album preview must too (lesson 2026-11-23)
	var sh := SpriteSheet.load_dir("res://assets/sprites/custom/fireball", "fireball")
	_check(is_equal_approx(SkillSim._dens(sh, 2.0), 2.0 * float(sh.meta.get("px_scale", 1.0))), "Album preview scale differs from the run")
