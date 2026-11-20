extends RefCounted
## Cổ Thụ Trụi Lá, Mộc Yêu's phase 2 (design/bosses.md): a 360° leaf storm when it transforms; a root
## wall across the hero's path that blocks the hero and monsters for wall time s; minions it called that
## live absorb_after s are pulled into it, each healing heal_each of its max hp (at most heal_max a call).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var tree := {"sprite": "tree", "behaviour": "boss_tree", "boss": true, "hp": 1000.0, "damage": 10.0, "speed": 20.0,
		"xp": 1.0, "root_every": 99.0, "root_count": 0, "summon_every": 99.0, "summon": ["wolf"], "summon_count": 3,
		"rage_at": 0.5, "rage_root_every": 99.0, "rage_root_count": 0,
		"bolt_sprite": "tree", "bolt_speed": 90.0, "bolt_damage": 12.0, "bolt_range": 600.0, "bolt_radius": 6.0,
		"phase2": {"name": "Cổ Thụ Trụi Lá", "transition": 0.1, "push": 0.0},
		"leaf_storm": {"count": 24},
		"root_wall": {"every": 1.0, "length": 260.0, "ahead": 70.0, "warn": 0.6, "time": 4.0, "damage": 20.0, "thick": 14.0},
		"absorb": {"after": 6.0, "heal_each": 0.02, "heal_max": 0.1}}
	var wolf := {"sprite": "tree", "behaviour": "chase", "hp": 999.0, "damage": 1.0, "speed": 0.0, "xp": 1.0}
	var sheet := SpriteSheet.from_meta("tree", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 47.0],
		"body": {"anim": "default", "center": [24.0, 30.0], "radius": 14.0}})
	return Enemies.new({"tree": tree, "wolf": wolf}, {"max_enemies": 40, "separation": {"push": 0.0}}, {"tree": sheet}, 1)


func _to_phase2(e: Enemies) -> void:
	e.spawn("tree", Vector2.ZERO)
	e.hp[0] = 499.0
	e.step(1.0 / 30.0, Vector2(300, 0), Vector2(300, 0))


func test_transforming_sheds_a_ring_of_leaves() -> void:
	var e := _enemies()
	_to_phase2(e)
	_check(e.bolt_pos.size() == 24, "24 leaves, got %d" % e.bolt_pos.size())
	var dirs := {}
	for v in e.bolt_vel:
		dirs[snappedf(v.angle(), 0.1)] = true
	_check(dirs.size() >= 20, "they fly all round (%d directions)" % dirs.size())


func test_a_root_wall_crosses_the_path_warns_then_blocks() -> void:
	var e := _enemies()
	_to_phase2(e)
	for k in 40:
		e.step(1.0 / 30.0, Vector2(300, 0), Vector2(300, 0))
	_check(e.wall_a.size() >= 1, "a wall was raised")
	if e.wall_a.size() == 0:
		return
	var mid: Vector2 = (e.wall_a[0] + e.wall_b[0]) * 0.5
	_check(mid.x > 300.0, "it stands ahead of the hero (beyond, from the boss): %s" % mid)
	_check(absf((e.wall_b[0] - e.wall_a[0]).normalized().dot(Vector2.RIGHT)) < 0.1, "across the boss -> hero line")
	for k in 25:
		e.step(1.0 / 30.0, Vector2(300, 0), Vector2(300, 0))
	var through := e.push_out_walls(mid + Vector2(-3, 0), 8.0)
	_check(through.distance_to(mid) > 10.0, "a body on the wall is pushed out of it")


func test_minions_left_alive_are_absorbed_and_heal() -> void:
	var e := _enemies()
	_to_phase2(e)
	e.timer[0] = 99.0   # no call while waiting out the 0.1 s transition
	for k in 5:
		e.step(1.0 / 30.0, Vector2(300, 0), Vector2(300, 0))
	e.timer[0] = 0.0   # call now
	e.step(1.0 / 30.0, Vector2(300, 0), Vector2(300, 0))
	var wolves := 0
	for j in e.count:
		if e.kind_ids[e.kind[j]] == "wolf":
			wolves += 1
	_check(wolves == 3, "3 wolves called, got %d" % wolves)
	var hp0 := e.hp[0]
	for k in 200:   # > 6 s
		e.step(1.0 / 30.0, Vector2(300, 0), Vector2(300, 0))
	_check(absf(e.hp[0] - hp0 - 60.0) < 1.0, "3 x 2%% of 1000 = +60 hp, got %.0f" % (e.hp[0] - hp0))
	var alive := 0
	for j in e.count:
		if e.kind_ids[e.kind[j]] == "wolf" and e.state[j] != Enemies.DYING:
			alive += 1
	_check(alive == 0, "the absorbed wolves are gone")
