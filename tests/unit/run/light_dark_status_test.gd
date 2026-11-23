extends RefCounted
## design/species.md E5/E6: Thánh ấn (Ánh sáng) and Ăn mòn (Bóng tối).

var failures: Array[String] = []


func _enemies(n: int) -> Enemies:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 1000.0, "damage": 10.0, "speed": 0.0, "xp": 1.0,
		"scale": 2, "species": "goblinoid"}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	var e := Enemies.new(monsters, {"max_enemies": 8, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	e.status_defs = GameData.load_json("res://assets/data/statuses.json")["statuses"]
	e.set_species(GameData.load_json("res://assets/data/species.json"), {})
	for k in n:
		e.spawn("blob", Vector2(k * 20, 0))
	e.step(0.0, Vector2(900, 900), Vector2(900, 900))   # builds the spatial hash
	return e


func test_holy_mark_softens_contact_and_bursts_when_it_ends() -> void:
	var e := _enemies(2)
	var plain := e.contact_damage(0)
	e.apply_status(0, "holy_mark", {}, 200.0, "holy_column")
	if not is_equal_approx(e.contact_damage(0), plain * 0.7):
		failures.append("marked contact %s, want %s" % [e.contact_damage(0), plain * 0.7])
	var hp1 := e.hp[1]
	e._step_status(0, 3.0)
	if e.holy_t[0] > 0.0 or e.status_fx.is_empty():
		failures.append("mark did not end in a burst")
	if not is_equal_approx(hp1 - e.hp[1], 20.0):
		failures.append("burst should deal 10%% of 200 to the neighbour, dealt %s" % (hp1 - e.hp[1]))


func test_corrode_stacks_raise_damage_taken_up_to_three() -> void:
	var e := _enemies(1)
	for k in 4:
		e.apply_status(0, "corrode", {}, 0.0, "void_orb")
	if e.corrode_n[0] != 3:
		failures.append("stacks %d, want 3" % e.corrode_n[0])
	var before := e.hp[0]
	e._damage(0, 100.0, Vector2.ZERO, "x")
	if not is_equal_approx(before - e.hp[0], 124.0):
		failures.append("3 stacks: 100 should deal 124, dealt %s" % (before - e.hp[0]))


func test_corroded_death_spreads_a_stack() -> void:
	var e := _enemies(2)
	e.apply_status(0, "corrode", {}, 0.0, "void_orb")
	e.apply_status(0, "corrode", {}, 0.0, "void_orb")
	e._damage(0, 5000.0, Vector2.ZERO, "x")
	if e.corrode_n[1] != 1 or e.status_fx.is_empty():
		failures.append("neighbour stacks %d after a 2-stack death, fx %d" % [e.corrode_n[1], e.status_fx.size()])
