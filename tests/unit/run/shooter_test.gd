extends RefCounted
## Shooters (behaviour "shoot", design 6A, Nấm Phun): keep their distance, wind up,
## fire a slow bolt that hits a player who stays and misses one who moves away.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var m: Dictionary = GameData.load_json("res://assets/data/monsters.json")["spore"].duplicate()
	m["speed"] = 60.0
	var sheet := SpriteSheet.from_meta("spore", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 23.0],
		"body": {"anim": "default", "center": [12.0, 17.0], "radius": 7.0}})
	return Enemies.new({"spore": m}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"spore": sheet}, 1)


func test_keeps_its_distance() -> void:
	var e := _enemies()
	e.spawn("spore", Vector2(60, 0))
	e.charge_cd[0] = 99.0   # no shooting: only movement
	for k in 120:
		e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	var d := e.pos[0].length()
	var keep := float(e.k_extra[0]["keep_range"])
	_check(absf(d - keep) < 50.0, "settles near keep_range %.0f, at %.0f" % [keep, d])


func test_fires_a_bolt_that_hits_a_player_standing_still() -> void:
	var e := _enemies()
	e.spawn("spore", Vector2(200, 0))
	var hit := 0.0
	for k in 240:
		hit = maxf(hit, e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO))
	_check(hit >= float(e.k_extra[0]["bolt_damage"]), "a bolt hit for its damage, got %s" % hit)
	_check(not e.bolt_pops.is_empty(), "the bolt burst")


func test_a_moving_player_dodges() -> void:
	var e := _enemies()
	e.spawn("spore", Vector2(250, 0))
	e.charge_cd[0] = 0.0
	var p := Vector2.ZERO
	var hit := 0.0
	for k in 60:   # one wind-up and the bolt's flight; the player walks up out of its line
		p.y -= 3.0
		hit = maxf(hit, e.step(1.0 / 30.0, p, p))
	_check(e.bolt_pos.size() + e.bolt_pops.size() > 0, "it fired")
	_check(hit == 0.0, "a player walking off the line is not hit, got %s" % hit)


func test_a_burst_monster_warns_then_hurts_only_a_player_inside() -> void:
	var m: Dictionary = GameData.load_json("res://assets/data/monsters.json")["ember_beetle"].duplicate()
	var sheet := SpriteSheet.from_meta("b", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 23.0],
		"body": {"anim": "default", "center": [12.0, 17.0], "radius": 7.0}})
	var e := Enemies.new({"b": m}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"b": sheet}, 1)
	e.spawn("b", Vector2(30, 0))
	e.spawn("b", Vector2(400, 0))
	e.step(0.0001, Vector2(0, 900), Vector2(0, 900))
	e.hit_circle(Vector2(30, 0), 20.0, 999.0)
	e.hit_circle(Vector2(400, 0), 20.0, 999.0)
	_check(e.blast_pos.size() == 2, "two warnings placed, got %d" % e.blast_pos.size())
	var at := e.blast_pos[0]
	var early := e.step(float(m["explode"]["delay"]) * 0.5, at, at)
	_check(early == 0.0, "nothing before the delay")
	var hit := e.step(float(m["explode"]["delay"]), at, at)
	_check(is_equal_approx(hit, float(m["explode"]["damage"])), "the blast hurts a player on it, got %s" % hit)
	_check(e.blast_pos.is_empty() and e.blasts_done.size() == 2, "both went off once")
