extends RefCounted
## Hoppers (behaviour "hop", design 6A, Cóc Độc of Đầm Lầy Độc): crouch, leap to
## where the player stood, and leave a poison pool that hurts a player inside it
## for a while.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var m := {"sprite": "toad", "behaviour": "hop", "hp": 20.0, "damage": 6.0, "speed": 20.0, "xp": 2.0,
		"hop_range": 260.0, "hop_every": 2.0, "windup": 0.4, "hop_time": 0.5,
		"pool": {"time": 3.0, "radius": 28.0, "damage": 9.0}}
	var sheet := SpriteSheet.from_meta("toad", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 23.0],
		"body": {"anim": "default", "center": [12.0, 18.0], "radius": 7.0}})
	return Enemies.new({"toad": m}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"toad": sheet}, 1)


func _step(e: Enemies, seconds: float, player: Vector2) -> float:
	var hit := 0.0
	for k in roundi(seconds * 30.0):
		hit = maxf(hit, e.step(1.0 / 30.0, player, player))
	return hit


func test_leaps_to_the_player_and_leaves_a_pool() -> void:
	var e := _enemies()
	var player := Vector2(-150, 0)
	e.spawn("toad", Vector2(50, 0))
	e.charge_cd[0] = 0.0
	_step(e, 1.0, player)   # windup 0.4 + hop 0.5
	_check(e.pos[0].distance_to(player) < 30.0, "landed where the player stood, %.0f px off" % e.pos[0].distance_to(player))
	_check(e.pool_pos.size() == 1, "one poison pool at the landing, got %d" % e.pool_pos.size())


func test_pool_hurts_inside_then_dries_up() -> void:
	var e := _enemies()
	e.spawn("toad", Vector2(800, 0))   # far: no hop, no contact
	e.charge_cd[0] = 99.0
	e.add_pool(Vector2.ZERO, 3.0, 28.0, 9.0)
	_check(_step(e, 0.2, Vector2.ZERO) >= 9.0, "a player standing in the pool is hurt")
	_check(_step(e, 0.2, Vector2(200, 200)) == 0.0, "outside the pool: no harm")
	_step(e, 3.0, Vector2(200, 200))
	_check(e.pool_pos.is_empty(), "the pool dries up after its time")
