extends RefCounted
## Zig-zag flyers (behaviour "zigzag", design 6A, Ma Trơi of Rừng Âm U): close in on
## the player on sharp alternating diagonals, hard to line up a straight shot on.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var m := {"sprite": "wisp", "behaviour": "zigzag", "hp": 10.0, "damage": 6.0, "speed": 100.0, "xp": 1.0,
		"zig_angle": 55.0, "zig_time": 0.5}
	var sheet := SpriteSheet.from_meta("wisp", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	return Enemies.new({"wisp": m}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"wisp": sheet}, 1)


func test_closes_in_on_alternating_diagonals() -> void:
	var e := _enemies()
	e.spawn("wisp", Vector2(400, 0))
	var player := Vector2.ZERO
	var sides: Array[float] = []
	for k in 45:   # 1.5 s, three legs of 0.5 s
		e.step(1.0 / 30.0, player, player)
		if k % 15 == 7:
			sides.append(e.pos[0].y)
	_check(e.pos[0].x < 340.0, "closes in on the player, x %.0f" % e.pos[0].x)
	_check(sides.size() == 3 and sides[0] * sides[1] < 0.0 or absf(sides[1] - sides[0]) > 10.0,
		"turns sharply between legs, y at mid-legs %s" % [sides])
	var spread := 0.0
	for y in sides:
		spread = maxf(spread, absf(y))
	_check(spread > 15.0, "leaves the straight line (|y| up to %.0f)" % spread)
