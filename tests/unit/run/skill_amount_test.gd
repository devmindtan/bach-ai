extends RefCounted
## Unit tests for skill amounts: counts per level, the "amount" stat card adding
## one to every skill, and Enemies.nearest_n for multi-target casts.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(cls: String, levels: Dictionary) -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes[cls]
	r.pool = GameData.load_json("res://assets/data/" + String(classes[cls]["upgrades"]))
	r.base_stats = classes[cls]["stats"]
	r.levels = levels
	r._recompute_stats()
	return r


func test_aoe_skills_cast_more_with_level() -> void:
	var r := _run("knight", {"earth_strike": 1})
	var sk: Dictionary = r.pool["skills"]
	var one: int = r._skill_count("earth_strike", sk["earth_strike"])
	r.levels["earth_strike"] = 5
	var five: int = r._skill_count("earth_strike", sk["earth_strike"])
	_check(one == 1 and five >= 3, "earth strike: 1 at level 1, >= 3 at level 5 (got %d, %d)" % [one, five])
	r.free()


func test_amount_card_adds_one_to_the_chosen_skill_only() -> void:
	# user 2026-11-17: Thêm phép / Thêm đòn give +1 to ONE skill the player picks;
	# only the rare Đa phép (level milestone) adds to every skill
	var r := _run("mage", {"arcane_bolt": 1, "fireball": 1})
	var sk: Dictionary = r.pool["skills"]
	var fb: int = r._skill_count("fireball", sk["fireball"])
	var ab: int = r._skill_count("arcane_bolt", sk["arcane_bolt"])
	r.levels["multicast"] = 1
	r._recompute_stats()
	_check(r._skill_count("fireball", sk["fireball"]) == fb, "taking the card alone adds nothing yet")
	r.add_skill_extra("fireball")
	_check(r._skill_count("fireball", sk["fireball"]) == fb + 1, "the chosen fireball: +1")
	_check(r._skill_count("arcane_bolt", sk["arcane_bolt"]) == ab, "the other skill unchanged")
	r.add_skill_extra("fireball")
	_check(r._skill_count("fireball", sk["fireball"]) == fb + 2, "it stacks on the same skill")
	r.free()


func test_amount_card_offers_owned_attacks_only() -> void:
	var r := _run("knight", {"blade_arc": 1, "earth_strike": 2, "dash": 1})
	var ids: Array = r.skill_pick_ids()
	_check(ids.has("blade_arc") and ids.has("earth_strike"), "owned attacks offered, got %s" % [ids])
	_check(not ids.has("dash") and not ids.has("whirlwind"), "no dash (player-cast), nothing not owned")
	r.free()


func test_only_milestone_rewards_add_to_every_skill() -> void:
	for cls in ["knight", "mage"]:
		var pool := GameData.load_json("res://assets/data/upgrades_%s.json" % cls)
		for u: Dictionary in pool.get("upgrades", []):
			_check(not u.get("effects", {}).has("amount"), "%s card %s must not add to every skill" % [cls, u["id"]])
	var ms := GameData.load_json("res://assets/data/milestones.json")
	_check(int(ms["rewards"]["twin_cast"].get("owned_skill_count", 0)) == 1 and ms["rewards"]["twin_cast"]["name"] == "Đa phép"
		and not ms["rewards"]["twin_cast"].get("effects", {}).has("amount"),
		"Đa phép adds +1 to the skills owned when picked (owned_skill_count), not a global amount (user 2026-11-20)")


func test_nearest_n_sorted() -> void:
	var monsters := {"blob": {"sprite": "blob", "behaviour": "chase", "hp": 10.0, "damage": 1.0, "speed": 0.0, "xp": 1.0, "scale": 2}}
	var blob := SpriteSheet.from_meta("blob", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 12.0],
		"body": {"anim": "default", "center": [12.0, 12.0], "radius": 6.0}})
	var e := Enemies.new(monsters, {"max_enemies": 10, "separation": {"push": 0.0}}, {"blob": blob}, 1)
	e.spawn("blob", Vector2(300, 0))
	e.spawn("blob", Vector2(100, 0))
	e.spawn("blob", Vector2(200, 0))
	var n := e.nearest_n(Vector2.ZERO, 2)
	_check(n.size() == 2 and n[0] == 1 and n[1] == 2, "two nearest, closest first, got %s" % [n])
