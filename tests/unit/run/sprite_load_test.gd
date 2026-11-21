extends RefCounted
## Roadmap item 3 (review 2026-11-21): a run loads the sprites of the skills it can use, not of every skill of
## the class. Every skill a level-up may offer must be among them (else its effect would not show).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_every_offerable_skill_is_in_the_run_and_not_more() -> void:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.deck_cards = ["blade_arc", "whirlwind", "earth_strike", "sharpen"]
	r.levels = {"blade_arc": 1, "god_hammer": 2}   # god_hammer forced (--skills)
	var run_skills: Dictionary = r.skills_in_run()
	for u: Dictionary in r.deck_pool():
		if String(u.get("kind", "")) == "skill":
			_check(run_skills.has(String(u["id"])), "offerable %s is loaded" % u["id"])
	_check(run_skills.has("god_hammer"), "a forced skill is loaded")
	_check(not run_skills.has("solar_ray"), "a skill outside the deck is not loaded")
	r.free()
