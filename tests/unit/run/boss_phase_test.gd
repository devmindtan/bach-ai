extends RefCounted
## Boss phase 2 transition (design/bosses.md "Chuyển pha"): crossing rage_at starts a transition of
## phase2.transition s (invulnerable, standing still, a push on the player reported for the run);
## after it the phase 2 multipliers apply (speed, damage taken, contact damage, body radius).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var boss := {"sprite": "tree", "behaviour": "chase", "boss": true, "hp": 1000.0, "damage": 10.0, "speed": 20.0, "xp": 1.0,
		"rage_at": 0.5, "phase2": {"name": "Pha hai", "transition": 1.5, "push": 160.0, "speed_mul": 2.0,
		"damage_taken_mul": 1.5, "contact_mul": 1.2, "radius_mul": 0.5}}
	var sheet := SpriteSheet.from_meta("tree", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 47.0],
		"body": {"anim": "default", "center": [24.0, 30.0], "radius": 14.0}})
	return Enemies.new({"boss": boss}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"tree": sheet}, 1)


func _hit(e: Enemies, dmg: float) -> void:
	e.step(1.0 / 30.0, Vector2(400, 0), Vector2(400, 0))
	e.hit_circle(e.pos[0], 40.0, dmg, 0.0, "test")


func test_crossing_rage_starts_an_invulnerable_transition() -> void:
	var e := _enemies()
	e.spawn("boss", Vector2.ZERO)
	_hit(e, 600.0)
	_check(e.in_transition(0), "the transition started")
	_check(e.phase_push.size() == 1, "a push on the player is reported")
	_check(e.raged.has(0), "the run is told (announcement)")
	var hp_now := e.hp[0]
	_hit(e, 100.0)
	_check(is_equal_approx(e.hp[0], hp_now), "invulnerable during the transition: %.0f -> %.0f" % [hp_now, e.hp[0]])
	var p := e.pos[0]
	e.step(0.2, Vector2(400, 0), Vector2(400, 0))
	_check(e.pos[0].distance_to(p) < 0.5, "it stands still while transforming")
	for k in 50:
		e.step(1.0 / 30.0, Vector2(400, 0), Vector2(400, 0))
	_check(not e.in_transition(0), "the transition ends after 1.5 s")
	_check(e.phase_name(0) == "Pha hai", "phase name for the bar")


func test_phase_two_multipliers_apply_after_the_transition() -> void:
	var e := _enemies()
	e.spawn("boss", Vector2.ZERO)
	var r1 := e.k_radius[0]
	_hit(e, 600.0)
	for k in 50:
		e.step(1.0 / 30.0, Vector2(400, 0), Vector2(400, 0))
	var before := e.pos[0]
	e.step(1.0, Vector2(1000, 0), Vector2(1000, 0))   # within despawn_distance
	_check(absf(e.pos[0].x - before.x - 40.0) < 2.0, "speed x2: 40 px in 1 s, got %.1f" % (e.pos[0].x - before.x))
	var hp_now := e.hp[0]
	_hit(e, 10.0)
	_check(absf(hp_now - e.hp[0] - 15.0) < 0.01 or absf(hp_now - e.hp[0] - 15.0 * e.crit_mul) < 0.01, "damage taken x1.5")
	_check(absf(e.k_radius[0] - r1 * 0.5) < 0.01, "body radius x0.5: %.1f -> %.1f" % [r1, e.k_radius[0]])
	_check(is_equal_approx(e.contact_damage(0), 12.0), "contact x1.2 = 12, got %.1f" % e.contact_damage(0))



func test_the_transform_animation_plays_through_the_transition() -> void:
	# user 2026-11-20: the bosses lacked an animation for changing state
	var boss := {"sprite": "tree", "behaviour": "chase", "boss": true, "hp": 1000.0, "damage": 1.0, "speed": 1.0, "xp": 1.0,
		"rage_at": 0.5, "rage_sprite": "tree2", "phase2": {"transition": 1.5, "push": 0.0}}
	var body := {"anim": "default", "center": [24.0, 30.0], "radius": 14.0}
	var sheet := SpriteSheet.from_meta("tree", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 47.0], "body": body})
	var rage := SpriteSheet.from_meta("tree2", {"frame_size": [48, 48], "anchor": [24.0, 47.0], "body": body,
		"animations": [{"name": "move", "start": 0, "frames": 1, "fps": 8.0, "loop": true},
			{"name": "transform", "start": 1, "frames": 12, "fps": 8.0, "loop": false}]})
	var e := Enemies.new({"boss": boss}, {"max_enemies": 4, "separation": {"push": 0.0}}, {"tree": sheet, "tree2": rage}, 1)
	e.spawn("boss", Vector2.ZERO)
	e.hp[0] = 499.0
	e.step(0.01, Vector2(400, 0), Vector2(400, 0))
	_check(e.sheet_of(0) == rage, "the phase 2 sheet from the start of the transition (it holds the transform)")
	var a := e.anim_of(0)
	_check(a[0] == "transform" and float(a[1]) < 0.1, "transform from its first frame, got %s" % [a])
	for k in 20:   # 0.75 s
		e.step(0.0375, Vector2(400, 0), Vector2(400, 0))
	a = e.anim_of(0)
	_check(a[0] == "transform" and absf(float(a[1]) - rage.duration("transform") * 0.5) < 0.1, "halfway through at 0.75 s, got %s" % [a])
	for k in 30:
		e.step(0.05, Vector2(400, 0), Vector2(400, 0))
	_check(e.anim_of(0)[0] != "transform", "back to its own animations after the transition")
