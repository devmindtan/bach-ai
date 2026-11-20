extends RefCounted
## A boss (or an event monster) spawns even when the monster cap is full: the farthest plain monster
## makes room. Regression: at stage 20 the demo run sat at 600/600 when Mộc Yêu was due and it never came.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_a_boss_spawns_even_when_the_monster_cap_is_full() -> void:
	# regression: at stage 20 the demo run had 600/600 monsters when Mộc Yêu was due; spawn() refused
	# and the boss never came (a boss stage could not be won)
	var boss := {"sprite": "tree", "behaviour": "chase", "boss": true, "hp": 100.0, "damage": 1.0, "speed": 1.0, "xp": 1.0}
	var mob := {"sprite": "tree", "behaviour": "chase", "hp": 5.0, "damage": 1.0, "speed": 1.0, "xp": 1.0}
	var sheet := SpriteSheet.from_meta("tree", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 47.0],
		"body": {"anim": "default", "center": [24.0, 30.0], "radius": 14.0}})
	var e := Enemies.new({"boss": boss, "mob": mob}, {"max_enemies": 5, "separation": {"push": 0.0}}, {"tree": sheet}, 1)
	for k in 5:
		e.spawn("mob", Vector2(k * 100.0, 0))
	_check(e.count == e.capacity, "full")
	_check(e.spawn("boss", Vector2(-50, 0)), "the boss spawns anyway")
	_check(e.boss_index() >= 0 and e.count == e.capacity, "a plain monster made room")
	_check(not e.spawn("mob", Vector2.ZERO), "a plain monster still waits for room")
