extends RefCounted
## Unit tests for Enemies: hits in an arc / circle, kills, movement and removal.
## Uses an in-test monster table and no sprites.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var monsters := {
		"blob": {"sprite": "blob", "behaviour": "chase", "hp": 18.0, "damage": 8.0, "speed": 40.0, "xp": 2.0, "scale": 2},
	}
	var cfg := {"world": {"spawn_ring": [700.0, 800.0], "despawn_distance": 1300.0, "arena_half": 1400.0},
		"separation": {"cell": 48.0, "push": 60.0}, "max_enemies": 50}
	# body centred on the anchor, radius 6.5 px x scale 2 = 13
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.5}})
	var e := Enemies.new(monsters, cfg, {"blob": blob}, 1)
	e.player_hit_radius = 14.0
	return e


func _settle(e: Enemies) -> void:
	# one tiny step builds the spatial hash without moving anything noticeably
	e.step(0.0001, Vector2(0, 300), Vector2(0, 300))


func test_arc_hits_monster_in_front() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(50, 0))
	_settle(e)
	var hits := e.hit_arc(Vector2.ZERO, Vector2.RIGHT, 70.0, deg_to_rad(70.0), 5.0)
	_check(hits == 1, "monster 50px in front should be hit, hits=%d" % hits)


func test_arc_misses_monster_behind() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(-50, 0))
	_settle(e)
	_check(e.hit_arc(Vector2.ZERO, Vector2.RIGHT, 70.0, deg_to_rad(70.0), 5.0) == 0, "monster behind must not be hit")


func test_arc_hits_monster_spawned_after_last_step() -> void:
	var e := _enemies()
	_settle(e)
	e.spawn("blob", Vector2(40, 0))
	_check(e.hit_arc(Vector2.ZERO, Vector2.RIGHT, 70.0, deg_to_rad(70.0), 5.0) == 1,
		"a monster spawned since the last step must still be hittable")


func test_kill_records_drop_and_dies_after_animation() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(30, 0))
	_settle(e)
	e.hit_circle(Vector2.ZERO, 60.0, 100.0)
	_check(e.total_kills == 1 and e.kill_pos.size() == 1 and is_equal_approx(e.kill_xp[0], 2.0),
		"kill should be recorded with xp 2")
	_check(e.living() == 0, "killed monster is not living")
	for i in 120:
		e.step(1.0 / 60.0, Vector2(0, 300), Vector2(0, 300))
	_check(e.count == 0, "dying monster should be removed after its death time")


func test_chase_moves_towards_player() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(300, 0))
	for i in 60:
		e.step(1.0 / 60.0, Vector2.ZERO, Vector2.ZERO)
	_check(e.pos[0].x < 300.0 - 30.0, "chaser should approach the player, x=%s" % e.pos[0].x)


func test_contact_damage_reported() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(5, 0))
	var contact := e.step(1.0 / 60.0, Vector2.ZERO, Vector2.ZERO)
	_check(is_equal_approx(contact, 8.0), "touching monster should deal 8, got %s" % contact)


func test_hits_still_find_monster_moved_by_removal() -> void:
	# A dies and finishes its death animation; B (last slot) is swap-moved into
	# A's slot during step. B must still be hittable right after that step.
	var e := _enemies()
	e.spawn("blob", Vector2(-200, 0))
	e.spawn("blob", Vector2(40, 0))
	_settle(e)
	e.hit_circle(Vector2(-200, 0), 30.0, 100.0)
	var guard := 0
	while e.count == 2 and guard < 120:   # stop right after the removing step
		e.step(1.0 / 60.0, Vector2(0, 300), Vector2(0, 300))
		guard += 1
	_check(e.count == 1, "dead monster should be gone, count=%d" % e.count)
	e.hit_arc(Vector2.ZERO, Vector2.RIGHT, 70.0, deg_to_rad(70.0), 1.0)
	_check(is_equal_approx(e.hp[0], 17.0),
		"the monster moved into the freed slot must take the hit (hp 18 -> 17), hp=%s" % e.hp[0])


func test_body_comes_from_sprite_and_mirrors() -> void:
	var monsters := {"gob": {"sprite": "gob", "behaviour": "chase", "hp": 10.0, "damage": 1.0, "speed": 40.0, "xp": 1.0, "scale": 2}}
	var cfg := {"max_enemies": 4}
	var gob := SpriteSheet.from_meta("gob", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 44.0],
		"body": {"anim": "default", "center": [26.0, 32.0], "radius": 9.5}})
	var e := Enemies.new(monsters, cfg, {"gob": gob}, 1)
	e.spawn("gob", Vector2(100, 0))
	_check(is_equal_approx(e.k_radius[0], 19.0), "radius 9.5 x2 = 19, got %s" % e.k_radius[0])
	e.step(0.0001, Vector2(400, 0), Vector2(400, 0))   # player to the right: facing right
	_check(e.center_of(0).distance_to(Vector2(104, -24)) < 0.1, "body (+4,-24) facing right, got %s" % e.center_of(0))
	e.step(0.0001, Vector2(-200, 0), Vector2(-200, 0))  # player to the left: mirrored
	_check(e.center_of(0).distance_to(Vector2(96, -24)) < 0.1, "body (-4,-24) mirrored, got %s" % e.center_of(0))


func test_hit_records_damage_number_and_shows_hp_bar_for_a_while() -> void:
	var e := _enemies()
	e.hp_bar_time = 2.0
	e.spawn("blob", Vector2(40, 0))
	_settle(e)
	_check(e.hp_show[0] == 0.0, "hp bar hidden before any hit")
	e.hit_circle(Vector2.ZERO, 60.0, 5.0)
	_check(e.hit_val.size() == 1 and is_equal_approx(e.hit_val[0], 5.0), "one damage number of 5")
	_check(is_equal_approx(e.hp_show[0], 2.0), "hp bar shown for 2 s after the hit")
	e.drain_hits()
	_check(e.hit_pos.is_empty(), "drain clears the hits")
	for i in 130:
		e.step(1.0 / 60.0, Vector2(0, 300), Vector2(0, 300))
	_check(e.hp_show[0] == 0.0, "hp bar hidden again after 2 s without hits")


func test_nearest_finds_far_monster_when_unbounded() -> void:
	var e := _enemies()
	e.spawn("blob", Vector2(600, 0))
	e.spawn("blob", Vector2(-400, 0))
	_settle(e)
	_check(e.nearest(Vector2.ZERO, INF) == 1, "the monster 400 px away is the nearest")
	_check(e.nearest(Vector2.ZERO, 100.0) == -1, "none within 100 px")
