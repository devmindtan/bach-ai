extends RefCounted
## Chargers with "telegraph" (design 6A, Sói Rừng) show the lane they will dash
## along while they wind up, so the player can step out of it.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies(telegraph: bool) -> Enemies:
	var m := {"sprite": "wolf", "behaviour": "charge", "hp": 26.0, "damage": 12.0, "speed": 80.0, "xp": 2.0,
		"charge_range": 240.0, "windup": 0.6, "dash_speed": 380.0, "dash_time": 0.4, "charge_cooldown": 2.5,
		"telegraph": telegraph}
	var sheet := SpriteSheet.from_meta("wolf", {"frames": 1, "frame_size": [32, 24], "fps": 8.0, "anchor": [16.0, 23.0],
		"body": {"anim": "default", "center": [16.0, 17.0], "radius": 7.0}})
	return Enemies.new({"wolf": m}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"wolf": sheet}, 1)


func test_winding_up_charger_shows_its_lane_toward_the_player() -> void:
	var e := _enemies(true)
	e.spawn("wolf", Vector2(200, 0))
	_check(e.charge_lane(0).is_empty(), "no lane while it just walks")
	e.charge_cd[0] = 0.0   # ready to charge (spawn cooldown is random)
	e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	var lane := e.charge_lane(0)
	_check(e.state[0] == Enemies.WINDUP, "within range it winds up")
	_check(lane.size() == 3, "a lane [from, to, width] while winding up")
	if lane.size() == 3:
		var from: Vector2 = lane[0]
		var to: Vector2 = lane[1]
		_check(absf(from.distance_to(to) - 380.0 * 0.4) < 2.0, "lane as long as the dash (152), got %.0f" % from.distance_to(to))
		_check(to.x < from.x, "the lane points at the player")


func test_no_lane_without_telegraph() -> void:
	var e := _enemies(false)
	e.spawn("wolf", Vector2(200, 0))
	e.charge_cd[0] = 0.0
	e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	_check(e.charge_lane(0).is_empty(), "plain chargers (goblin) keep the tint only")
