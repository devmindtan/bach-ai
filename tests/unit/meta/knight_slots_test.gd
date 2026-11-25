extends RefCounted
## User 2026-11-25: the knight wears helmet, chest, boots, sword and shield (no gauntlets, no greaves). Old saves
## keep their items: knight gauntlets and greaves become the shield of the same tier.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_knight_and_mage_slots() -> void:
	_check(Profile.slots_for("knight") == ["head", "chest", "feet", "weapon", "shield"], "knight slots: %s" % [Profile.slots_for("knight")])
	_check(Profile.slots_for("mage") == ["head", "chest", "feet", "weapon"], "mage slots (no shield): %s" % [Profile.slots_for("mage")])


func test_old_gauntlets_and_greaves_become_shields() -> void:
	var defs: Dictionary = GameData.load_json("res://assets/data/items.json")["equipment"].duplicate()
	defs.erase("_doc")
	var p := Profile.new(defs)
	p.from_dict({"version": 1, "bag": ["iron_gauntlets", "dragon_greaves"], "worn": {"knight": {"arms": "steel_gauntlets"}}}, "knight")
	_check(p.bag.has("iron_shield") and p.bag.has("dragon_shield"), "bag not moved to shields: %s" % [p.bag])
	_check(String(p.equipped("knight").get("shield", "")) == "steel_shield", "worn gauntlets not worn as a shield: %s" % [p.equipped("knight")])


func test_old_mage_trousers_and_bracers_move_to_robe_and_staff() -> void:
	var defs: Dictionary = GameData.load_json("res://assets/data/items.json")["equipment"].duplicate()
	defs.erase("_doc")
	var p := Profile.new(defs)
	p.from_dict({"version": 1, "bag": ["cloth_pants", "void_bracer"], "worn": {"mage": {"legs": "mage_pants"}}}, "mage")
	_check(p.bag.has("cloth_robe") and p.bag.has("void_staff"), "bag not moved: %s" % [p.bag])
	_check(String(p.equipped("mage").get("chest", "")) == "mage_robe", "worn trousers not worn as the robe: %s" % [p.equipped("mage")])
