extends RefCounted
## Unit tests for monster statuses (Enemies.apply_status / hit_box effects):
## slow, stun, freeze, bleed and burn over time, shock chaining.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var monsters := {
		"blob": {"sprite": "blob", "behaviour": "chase", "hp": 100.0, "damage": 8.0, "speed": 40.0, "xp": 2.0, "scale": 2},
	}
	var cfg := {"world": {"spawn_ring": [700.0, 800.0], "despawn_distance": 1300.0, "arena_half": 1400.0},
		"separation": {"cell": 48.0, "push": 0.0}, "max_enemies": 50}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.5}})
	var e := Enemies.new(monsters, cfg, {"blob": blob}, 1)
	e.player_hit_radius = 14.0
	return e


func _run(e: Enemies, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		e.step(0.05, Vector2(0, 500), Vector2(0, 500))
		t += 0.05


func test_stun_stops_and_slow_halves_movement() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(0, 0))
	e.spawn("blob", Vector2(100, 0))
	e.spawn("blob", Vector2(200, 0))
	e.apply_status(0, "stun", {"time": 1.0}, 0.0, "x")
	e.apply_status(1, "slow", {"mul": 0.5, "time": 2.0}, 0.0, "x")
	var y0 := e.pos[0].y
	var y1 := e.pos[1].y
	var y2 := e.pos[2].y
	_run(e, 0.5)
	_check(is_equal_approx(e.pos[0].y, y0), "stunned monster did not move")
	var moved_slow := e.pos[1].y - y1
	var moved_free := e.pos[2].y - y2
	_check(absf(moved_slow - moved_free * 0.5) < 1.0, "slowed moves half as far: %.1f vs %.1f" % [moved_slow, moved_free])
	_check(e.statuses_of(0).has("stun") and e.statuses_of(1).has("slow"), "statuses_of lists them")
	_run(e, 0.6)
	_check(not e.statuses_of(0).has("stun"), "stun wears off after its time")


func test_bleed_ticks_damage_credited_to_its_skill() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(0, 0))
	# 20 dps (0.5 x 40 damage) for 2 s = 40 damage
	e.apply_status(0, "bleed", {"dps_mul": 0.5, "time": 2.0}, 40.0, "cleave_wave")
	_run(e, 2.1)
	_check(absf(e.hp[0] - 60.0) < 0.5, "bleed took 40 hp, hp now %.1f" % e.hp[0])
	_check(absf(float(e.damage_by.get("cleave_wave", 0.0)) - 40.0) < 0.5, "credited to cleave_wave")


func test_shock_marks_then_spreads_to_marked_monsters_under_half() -> void:
	# user 2026-11-18: a first shock hit only marks the monster; a later shock hit
	# arcs to every monster still marked for less than half the hit
	var e := _enemies()
	e.spawn("blob", Vector2(50, 0))
	e.spawn("blob", Vector2(110, 0))
	e.spawn("blob", Vector2(400, 0))
	e.step(0.0001, Vector2(0, 500), Vector2(0, 500))
	var sh := {"status": "shock", "mul": 0.5, "time": 3.0}
	e.apply_status(0, "shock", sh, 20.0, "bolt")
	_check(e.statuses_of(0).has("shock"), "the first shock hit marks the monster")
	_check(is_equal_approx(e.hp[1], 100.0) and is_equal_approx(e.hp[2], 100.0), "nothing spreads from the first mark")
	_check(e.shock_lines.is_empty(), "no arc with nobody else marked")
	e.apply_status(2, "shock", sh, 20.0, "bolt")
	_check(e.hp[0] < 100.0 and e.hp[0] > 90.0, "the marked monster took spread damage under half (10), hp %.1f" % e.hp[0])
	_check(is_equal_approx(e.hp[1], 100.0), "an unmarked monster takes no spread")
	_check(e.shock_lines.size() == 2, "one arc to the marked monster, got %d points" % e.shock_lines.size())
	_run(e, 3.2)
	_check(not e.statuses_of(0).has("shock"), "the mark wears off after its time")


func test_hit_box_applies_effects() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(50, 0))
	e.step(0.0001, Vector2(0, 500), Vector2(0, 500))
	var fx := [{"status": "shock", "mul": 0.5, "time": 3.0}, {"status": "slow", "mul": 0.5, "time": 1.0}]
	e.hit_arc(Vector2.ZERO, Vector2.RIGHT, 70.0, deg_to_rad(40.0), 20.0, 0.0, "bolt", fx)
	_check(e.hp[0] < 81.0, "the struck monster took the hit")
	_check(e.statuses_of(0).has("slow"), "slow applied by the hit")
	_check(e.statuses_of(0).has("shock"), "shock mark applied by the hit")
