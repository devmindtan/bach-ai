extends RefCounted
## Unit tests for elites ("<id>@elite" kinds), the chest pickup and the Vua Slime boss.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _sheet(name: String) -> SpriteSheet:
	return SpriteSheet.from_meta(name, {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})


func _enemies() -> Enemies:
	var monsters := {
		"blob": {"sprite": "blob", "behaviour": "chase", "hp": 20.0, "damage": 5.0, "speed": 0.0, "xp": 1.0, "scale": 2},
		"king": {"sprite": "blob", "behaviour": "boss_slime", "hp": 1000.0, "damage": 10.0, "speed": 0.0, "xp": 50.0,
			"scale": 4, "boss": true, "jump_every": 1.0, "windup": 0.5, "jump_time": 0.5, "slam_damage": 30.0,
			"split_at": [0.75, 0.5], "split_into": "blob", "split_count": 3},
	}
	var cfg := {"max_enemies": 50, "separation": {"push": 0.0},
		"elite": {"hp_mul": 10.0, "damage_mul": 1.5, "scale_mul": 1.5, "xp_mul": 8.0}}
	return Enemies.new(monsters, cfg, {"blob": _sheet("blob")}, 1)


func test_elite_kind_is_registered_with_multipliers() -> void:
	var e := _enemies()
	var k := e.kind_of("blob@elite")
	_check(k >= 0, "blob@elite registered")
	var b := e.kind_of("blob")
	_check(is_equal_approx(e.k_hp[k], 200.0) and is_equal_approx(e.k_damage[k], 7.5), "hp x10, damage x1.5")
	_check(is_equal_approx(e.k_radius[k], e.k_radius[b] * 1.5), "body grows with the scale")
	_check(e.k_elite[k] == 1 and e.k_elite[b] == 0, "elite flag")
	e.spawn("blob@elite", Vector2(30, 0))
	e.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	e.hit_circle(Vector2(30, 0), 40.0, 500.0)
	_check(e.kill_elite.size() == 1 and e.kill_elite[0] == 1, "its kill is marked elite (drops a chest)")


func test_boss_jumps_to_where_the_player_was_and_slams() -> void:
	var e := _enemies()
	e.spawn("king", Vector2(0, 0))
	var target := Vector2(200, 0)
	var slammed := false
	var t := 0.0
	while t < 2.2:
		var c := e.step(0.05, target, target)
		if c >= 30.0:
			slammed = true
		t += 0.05
	_check(slammed, "the landing hits a player standing on the target for slam_damage")
	_check(e.pos[0].distance_to(target) < 20.0, "it landed where the player stood, at %s" % e.pos[0])


func test_boss_splits_at_hp_thresholds() -> void:
	var e := _enemies()
	e.spawn("king", Vector2(0, 0))
	e.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	e.hit_circle(Vector2.ZERO, 60.0, 300.0)   # 1000 -> 700: crosses 75%
	_check(e.count == 4, "3 blobs split off at 75%%, count %d" % e.count)
	e.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	e.hit_circle(Vector2.ZERO, 30.0, 50.0)    # 700 -> 650: no threshold
	_check(e.count == 4, "no split between thresholds")


func test_chest_pickup_is_counted() -> void:
	var p := Pickups.new({"radius": 70.0, "collect_radius": 14.0}, 10)
	p.drop(Pickups.CHEST, Vector2(5, 0), 1.0)
	p.step(0.1, Vector2.ZERO, 1.0)
	_check(p.chests == 1, "one chest collected")
