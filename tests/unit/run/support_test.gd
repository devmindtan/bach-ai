extends RefCounted
## Supports (behaviour "support", design 6A, Hồn Đầm of Đầm Lầy Độc): keep their
## distance and every heal_every s heal the monsters around them (a pulse the
## run draws), so the player should take them out first.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var spirit := {"sprite": "s", "behaviour": "support", "hp": 18.0, "damage": 4.0, "speed": 50.0, "xp": 2.0,
		"keep_range": 220.0, "heal_every": 2.0, "heal_radius": 120.0, "heal_pct": 0.3}
	var grunt := {"sprite": "s", "behaviour": "chase", "hp": 100.0, "damage": 5.0, "speed": 0.0, "xp": 1.0}
	var sheet := SpriteSheet.from_meta("s", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 23.0],
		"body": {"anim": "default", "center": [12.0, 16.0], "radius": 6.0}})
	return Enemies.new({"spirit": spirit, "grunt": grunt}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"s": sheet}, 1)


func test_heals_monsters_nearby_not_far_ones() -> void:
	var e := _enemies()
	e.spawn("spirit", Vector2(300, 0))
	e.spawn("grunt", Vector2(340, 0))
	e.spawn("grunt", Vector2(700, 300))
	e.hp[1] = 40.0
	e.hp[2] = 40.0
	e.timer[0] = 0.0
	e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	_check(absf(e.hp[1] - 70.0) < 1.0, "the near grunt healed 30%% of max (40 -> 70), got %.0f" % e.hp[1])
	_check(is_equal_approx(e.hp[2], 40.0), "the far grunt is not healed")
	_check(e.heal_pulses.size() == 1, "one heal pulse to draw")


func test_keeps_its_distance() -> void:
	var e := _enemies()
	e.spawn("spirit", Vector2(80, 0))
	e.timer[0] = 99.0
	for k in 120:
		e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	_check(e.pos[0].length() > 180.0, "backs away to its keep_range, at %.0f" % e.pos[0].length())
