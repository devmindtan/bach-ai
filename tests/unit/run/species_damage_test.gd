extends RefCounted
## design/species.md (roadmap E3.1): a hit of an element the species is weak to deals mul_weak, a resisted one
## mul_resist; bosses take boss_scale of the change; the hit is tagged for the number's colour.

var failures: Array[String] = []


func _enemies(species_id: String, boss: bool) -> Enemies:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 1000.0, "damage": 1.0, "speed": 0.0, "xp": 1.0,
		"scale": 2, "species": species_id, "boss": boss}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	var e := Enemies.new(monsters, {"max_enemies": 4, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	e.set_species(GameData.load_json("res://assets/data/species.json"), {"fireball": "fire", "blade_arc": "physical", "storm": "lightning"})
	e.spawn("blob", Vector2.ZERO)
	return e


func _hit(e: Enemies, source: String) -> float:
	var before := e.hp[0]
	e._damage(0, 100.0, Vector2.ZERO, source)
	return before - e.hp[0]


func test_ooze_weak_to_fire_resists_physical_neutral_to_lightning() -> void:
	var e := _enemies("ooze", false)
	var got := [_hit(e, "fireball"), _hit(e, "blade_arc"), _hit(e, "storm")]
	if not (is_equal_approx(got[0], 150.0) and is_equal_approx(got[1], 60.0) and is_equal_approx(got[2], 100.0)):
		failures.append("ooze fire/physical/lightning should be 150/60/100, got %s" % [got])
	if Array(e.hit_tag) != [1, 2, 0]:
		failures.append("hit tags should be weak/resisted/plain, got %s" % [Array(e.hit_tag)])


func test_boss_takes_half_the_species_change() -> void:
	var e := _enemies("ooze", true)
	var got := [_hit(e, "fireball"), _hit(e, "blade_arc")]
	if not (is_equal_approx(got[0], 125.0) and is_equal_approx(got[1], 80.0)):
		failures.append("boss ooze fire/physical should be 125/80, got %s" % [got])
