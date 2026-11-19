extends RefCounted
## Yêu tinh vàng (behaviour "flee", design/events.md): runs from the player dropping a trail of gold,
## after flee_time opens a portal (channel s) and escapes; a hit interrupts the portal; killing it drops
## gold_drop coins and a chest.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var m := {"sprite": "g", "behaviour": "flee", "hp": 50.0, "damage": 0.0, "speed": 80.0, "xp": 5.0,
		"flee_time": 2.0, "channel": 1.0, "trail_every": 0.5, "gold_drop": 12, "chest_drop": true}
	var sheet := SpriteSheet.from_meta("g", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 23.0],
		"body": {"anim": "default", "center": [12.0, 17.0], "radius": 6.0}})
	return Enemies.new({"g": m}, {"max_enemies": 4, "separation": {"push": 0.0}}, {"g": sheet}, 1)


func _step(e: Enemies, seconds: float) -> float:
	var hit := 0.0
	for k in roundi(seconds * 30.0):
		hit = maxf(hit, e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO))
	return hit


func test_runs_away_dropping_gold_and_never_hurts() -> void:
	var e := _enemies()
	e.spawn("g", Vector2(100, 0))
	var hit := _step(e, 1.0)
	_check(e.pos[0].x > 150.0, "runs away from the player, x %.0f" % e.pos[0].x)
	_check(e.gold_trail.size() >= 1, "drops a trail of gold, got %d" % e.gold_trail.size())
	_check(hit == 0.0, "never deals damage")


func test_escapes_through_a_portal_unless_hit() -> void:
	var e := _enemies()
	e.spawn("g", Vector2(100, 0))
	_step(e, 2.5)   # flee 2 s, then channelling
	_check(e.state[0] == Enemies.WINDUP, "opens a portal after flee_time")
	e.hit_arc(e.pos[0], Vector2.RIGHT, 40.0, PI, 1.0, 0.0, "test")
	e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	_check(e.state[0] == Enemies.MOVE, "a hit interrupts the portal")
	_step(e, 4.0)
	_check(e.escaped.size() == 1, "escapes when the portal completes")
	_check(e.kill_pos.is_empty(), "escaping is not a kill")


func test_killing_it_drops_gold_and_a_chest() -> void:
	var e := _enemies()
	e.spawn("g", Vector2(100, 0))
	e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	e.hit_arc(e.pos[0], Vector2.RIGHT, 40.0, PI, 999.0, 0.0, "test")
	_check(e.kill_gold.size() == 1 and int(e.kill_gold[0]) == 12, "kill drops 12 gold")
	_check(e.kill_chest.size() == 1 and e.kill_chest[0] == 1, "kill drops a chest")
