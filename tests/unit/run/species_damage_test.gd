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


func test_ooze_never_bleeds_but_burns() -> void:
	var e := _enemies("ooze", false)
	e.apply_status(0, "bleed", {"time": 2.0, "dps_mul": 0.2}, 10.0, "blade_arc")
	e.apply_status(0, "burn", {"time": 2.0, "dps_mul": 0.3}, 10.0, "fireball")
	if e.bleed_t[0] > 0.0:
		failures.append("ooze took bleed")
	if e.burn_t[0] <= 0.0:
		failures.append("ooze did not burn")


func test_spirit_passes_through_props_and_monsters() -> void:
	var e := _enemies("spirit", false)
	if not e.has_trait(0, "phase") or e.k_phase[0] != 1:
		failures.append("spirit kind not marked to phase")
	var o := _enemies("ooze", false)
	if o.k_phase[0] != 0:
		failures.append("ooze marked to phase")


func test_ooze_regens_after_calm_unless_burning() -> void:
	var e := _enemies("ooze", false)
	e._damage(0, 500.0, Vector2.ZERO, "storm")
	var low := e.hp[0]
	e._step_status(0, 1.0)
	if e.hp[0] != low:
		failures.append("ooze healed before 2 s calm")
	e._step_status(0, 1.5)
	if e.hp[0] <= low:
		failures.append("ooze did not heal after 2 s calm")
	var g := _enemies("goblinoid", false)
	g._damage(0, 500.0, Vector2.ZERO, "storm")
	var glow := g.hp[0]
	g._step_status(0, 3.0)
	if g.hp[0] != glow:
		failures.append("goblin healed")
	var b := _enemies("ooze", false)
	b._damage(0, 500.0, Vector2.ZERO, "storm")
	b.apply_status(0, "burn", {"time": 10.0, "dps_mul": 0.0}, 0.0, "fireball")
	var blow := b.hp[0]
	b._step_status(0, 3.0)
	if b.hp[0] > blow:
		failures.append("burning ooze healed")


func test_beast_enrages_below_threshold() -> void:
	var e := _enemies("beast", false)
	if e.enrage_mul(0) != 1.0:
		failures.append("full-hp beast enraged")
	e.hp[0] = e.hp_cap[0] * 0.2
	if not is_equal_approx(e.enrage_mul(0), 1.3):
		failures.append("beast at 20%% hp not enraged: %s" % e.enrage_mul(0))
	var o := _enemies("ooze", false)
	o.hp[0] = o.hp_cap[0] * 0.2
	if o.enrage_mul(0) != 1.0:
		failures.append("ooze enraged")


func test_beast_bite_marks_contact_bleed() -> void:
	var e := _enemies("beast", false)
	e.pos[0] = Vector2.ZERO
	e.step(0.016, Vector2.ZERO, Vector2.ZERO)
	if e.contact_bleed.is_empty():
		failures.append("beast contact did not mark a bleed")
	var o := _enemies("ooze", false)
	o.step(0.016, Vector2.ZERO, Vector2.ZERO)
	if not o.contact_bleed.is_empty():
		failures.append("ooze contact marked a bleed")


func test_insect_shell_halves_first_hit_only() -> void:
	var e := _enemies("insect", false)
	var got := [_hit(e, "storm"), _hit(e, "storm")]
	if not (is_equal_approx(got[0], 50.0) and is_equal_approx(got[1], 100.0)):
		failures.append("insect shell hits should be 50 then 100, got %s" % [got])


func test_insect_swarm_speeds_up_with_three_near() -> void:
	var e := _enemies("insect", false)
	if e.swarm_mul(0) != 1.0:
		failures.append("lone insect sped up")
	e.spawn("blob", Vector2(20, 0))
	e.spawn("blob", Vector2(0, 20))
	e.step(0.0, Vector2(500, 500), Vector2(500, 500))   # rebuilds the spatial hash
	if not is_equal_approx(e.swarm_mul(0), 1.2):
		failures.append("insect with 2 near did not speed up: %s" % e.swarm_mul(0))
