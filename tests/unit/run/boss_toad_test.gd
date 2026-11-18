extends RefCounted
## Cóc Chúa, boss of Đầm Lầy Độc (boss_slime behaviour + "pool", design/bosses.md):
## every landing of its leap leaves a big poison pool.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_landing_leaves_a_big_pool() -> void:
	var boss := {"sprite": "b", "behaviour": "boss_slime", "boss": true, "hp": 1000.0, "damage": 10.0, "speed": 20.0,
		"xp": 200.0, "jump_every": 1.0, "windup": 0.3, "jump_time": 0.4, "slam_damage": 20.0, "slam_reach": 2.0,
		"pool": {"time": 4.0, "radius": 55.0, "damage": 12.0}}
	var sheet := SpriteSheet.from_meta("b", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 47.0],
		"body": {"anim": "default", "center": [24.0, 32.0], "radius": 16.0}})
	var e := Enemies.new({"b": boss}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"b": sheet}, 1)
	e.spawn("b", Vector2(200, 0))
	e.charge_cd[0] = 0.0
	for k in 30:   # windup 0.3 + jump 0.4
		e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	_check(e.pool_pos.size() == 1, "one pool where it landed, got %d" % e.pool_pos.size())
	if e.pool_pos.size() == 1:
		_check(is_equal_approx(e.pool_r[0], 55.0), "the boss pool is big (55), got %.0f" % e.pool_r[0])
