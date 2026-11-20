extends RefCounted
## Cóc Độc Bào Tử, Cóc Chúa's phase 2 (design/bosses.md): three leaps in a row, the third landing a
## knockback shockwave; every landing a purple pool for rage_pool.time s; between chains the tongue
## (1 s red aim, then shoots along the aim) pulls a hero it touches to the boss; no spore volley.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var boss := {"sprite": "b", "behaviour": "boss_slime", "boss": true, "hp": 1000.0, "damage": 10.0, "speed": 20.0,
		"xp": 1.0, "jump_every": 1.0, "windup": 0.3, "jump_time": 0.4, "slam_damage": 20.0, "slam_reach": 2.0,
		"pool": {"time": 4.0, "radius": 55.0, "damage": 12.0}, "rage_at": 0.5, "rage_jump_every": 3.0, "rage_windup": 0.3,
		"volley": {"every": 0.5, "count": 5, "spread_deg": 50.0}, "bolt_sprite": "b",
		"shockwave": {"speed": 400.0, "max": 300.0, "width": 14.0, "damage": 24.0, "knock": 260.0},
		"phase2": {"name": "Cóc Độc Bào Tử", "transition": 0.1, "push": 0.0},
		"chain_hops": 3, "chain_windup": 0.3, "rage_pool": {"time": 7.0, "radius": 56.0, "damage": 16.0},
		"tongue": {"windup": 1.0, "length": 300.0, "speed": 900.0, "damage": 38.0, "width": 10.0}}
	var sheet := SpriteSheet.from_meta("b", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 47.0],
		"body": {"anim": "default", "center": [24.0, 32.0], "radius": 16.0}})
	var e := Enemies.new({"b": boss}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"b": sheet}, 1)
	e.spawn("b", Vector2(200, 0))
	e.hp[0] = 499.0
	for k in 5:   # past the 0.1 s transition
		e.step(1.0 / 30.0, Vector2(600, 0), Vector2(600, 0))
	return e


func test_three_leaps_in_a_row_the_third_sends_a_knockback_wave() -> void:
	var e := _enemies()
	e.charge_cd[0] = 0.0
	var lands := 0
	var waves := 0
	for k in 120:   # 4 s: 3 x (0.3 + 0.4)
		var before := e.pool_pos.size()
		e.step(1.0 / 30.0, Vector2(600, 0), Vector2(600, 0))
		lands += e.pool_pos.size() - before if e.pool_pos.size() > before else 0
		waves = maxi(waves, e.wave_pos.size())
	_check(lands == 3, "3 landings in one chain, got %d" % lands)
	_check(waves == 1, "one shockwave (the third), got %d" % waves)


func test_landings_leave_purple_pools_for_seven_seconds() -> void:
	var e := _enemies()
	e.charge_cd[0] = 0.0
	for k in 25:
		e.step(1.0 / 30.0, Vector2(600, 0), Vector2(600, 0))
	_check(e.pool_pos.size() >= 1, "a pool")
	if e.pool_pos.size() >= 1:
		_check(is_equal_approx(e.pool_total[0], 7.0) and e.pool_purple[0] == 1, "purple, 7 s")


func test_the_tongue_aims_then_pulls_a_hero_in_its_line() -> void:
	var e := _enemies()
	e.start_tongue(0)
	_check(e.tongue_t[0] > 0.0, "aiming")
	var hit := 0.0
	for k in 45:   # 1 s aim + the shot
		hit = maxf(hit, e.step(1.0 / 30.0, Vector2(400, 0), Vector2(400, 0)))
	_check(not e.tongue_pull.is_empty(), "the hero in line is pulled")
	if not e.tongue_pull.is_empty():   # the run reads [boss centre]: a bare Vector2 broke it once
		_check(e.tongue_pull[0] is Array and e.tongue_pull[0][0] is Vector2, "pull entry is [boss centre]")
	_check(hit >= 38.0, "and stomped (%.0f)" % hit)


func test_a_hero_off_the_line_dodges_the_tongue() -> void:
	var e := _enemies()
	e.start_tongue(0)
	e.step(1.0 / 30.0, Vector2(400, 0), Vector2(400, 0))   # aimed along +x
	for k in 45:
		e.step(1.0 / 30.0, Vector2(400, 150), Vector2(400, 150))   # ran off the line
	_check(e.tongue_pull.is_empty(), "no pull")


func test_no_spore_volley_in_phase_two() -> void:
	var e := _enemies()
	e.charge_cd[0] = 99.0
	for k in 60:
		e.step(1.0 / 30.0, Vector2(600, 0), Vector2(600, 0))
	_check(e.bolt_pos.is_empty(), "no spores, got %d" % e.bolt_pos.size())
