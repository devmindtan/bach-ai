extends RefCounted
## Unit tests for Profile: the bag, equipping by slot and class, and equipment
## turned into level-1 upgrades for PlayerStats.

var failures: Array[String] = []

const ITEMS := {
	"iron_helm": {"name": "Mũ sắt", "slot": "head", "rarity": "common", "effects": {"max_hp": {"add": 15.0}}},
	"steel_sword": {"name": "Kiếm thép", "slot": "weapon", "class": "knight", "rarity": "rare", "effects": {"damage": {"mul": 0.15}}},
	"crystal_staff": {"name": "Gậy pha lê", "slot": "weapon", "class": "mage", "rarity": "rare", "effects": {"damage": {"mul": 0.15}}},
}


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_equip_needs_the_item_in_the_bag_and_the_right_class() -> void:
	var p := Profile.new(ITEMS)
	_check(not p.equip("knight", "iron_helm"), "cannot equip what is not in the bag")
	p.add("iron_helm")
	p.add("crystal_staff")
	_check(p.equip("knight", "iron_helm"), "helm on the knight")
	_check(not p.equip("knight", "crystal_staff"), "a mage staff does not go on a knight")
	_check(p.equipped("knight").get("head", "") == "iron_helm", "head slot holds the helm")
	p.unequip("knight", "head")
	_check(not p.equipped("knight").has("head"), "unequipped")


func test_equipment_becomes_upgrades_for_player_stats() -> void:
	var p := Profile.new(ITEMS)
	p.add("iron_helm")
	p.add("steel_sword")
	p.equip("knight", "iron_helm")
	p.equip("knight", "steel_sword")
	var ups: Array = p.as_upgrades("knight")
	var s := PlayerStats.compute({"max_hp": 100.0, "damage": 20.0}, ups, p.levels("knight"))
	_check(is_equal_approx(s["max_hp"], 115.0) and is_equal_approx(s["damage"], 23.0), "helm +15 hp, sword +15%% damage, got %s" % s)


func test_round_trip_through_a_dictionary() -> void:
	var p := Profile.new(ITEMS)
	p.add("iron_helm")
	p.equip("mage", "iron_helm")
	var q := Profile.new(ITEMS)
	q.from_dict(p.to_dict())
	_check(q.bag == ["iron_helm"] and q.equipped("mage").get("head", "") == "iron_helm", "saved and loaded back")


func test_new_items_are_new_until_seen() -> void:
	# inventory "new" badges clear once the player has looked (design/ux/equipment.md)
	var p := Profile.new(ITEMS)
	p.add("iron_helm")
	_check(p.is_new("iron_helm"), "a freshly added item is new")
	p.mark_seen("iron_helm")
	_check(not p.is_new("iron_helm"), "seen: no longer new")
	p.add("steel_sword")
	var q := Profile.new(ITEMS)
	q.from_dict(p.to_dict())
	_check(not q.is_new("iron_helm") and q.is_new("steel_sword"), "seen state survives a save")


func test_saves_from_before_new_badges_count_everything_as_seen() -> void:
	var q := Profile.new(ITEMS)
	q.from_dict({"version": 1, "bag": ["iron_helm", "steel_sword"], "worn": {}})
	_check(not q.is_new("iron_helm") and not q.is_new("steel_sword"), "old bags do not light up as new")


func test_enhancing_costs_gold_and_raises_the_effects() -> void:
	# design/equipment.md "Cường hoá": +1..+5, each +20% of the item's effects, gold by rarity
	var p := Profile.new(ITEMS)
	p.add("iron_helm")
	p.equip("knight", "iron_helm")
	var base := float(p.as_upgrades("knight")[0]["effects"]["max_hp"]["add"])
	var cost: int = p.enhance_cost("iron_helm")
	_check(cost > 0, "enhancing costs gold")
	var gold := {"v": cost - 1}
	_check(not p.enhance("iron_helm", gold), "not enough gold: refused")
	gold["v"] = cost
	_check(p.enhance("iron_helm", gold) and gold["v"] == 0 and p.plus_of("iron_helm") == 1, "+1, gold paid")
	var now := float(p.as_upgrades("knight")[0]["effects"]["max_hp"]["add"])
	_check(is_equal_approx(now, base * 1.2), "+1 gives +20%%: %s -> %s" % [base, now])
	_check(p.enhance_cost("iron_helm") > cost, "the next level costs more")
	for k in 10:
		gold["v"] = 100000
		p.enhance("iron_helm", gold)
	_check(p.plus_of("iron_helm") == Profile.MAX_PLUS, "stops at +%d" % Profile.MAX_PLUS)
	var q := Profile.new(ITEMS)
	q.from_dict(p.to_dict())
	_check(q.plus_of("iron_helm") == Profile.MAX_PLUS, "the level is saved")


const LEGEND := {
	"crown": {"name": "Vương miện", "slot": "head", "rarity": "legendary", "effects": {"max_hp": {"add": 10.0}},
		"sub": {"at": 2, "effects": {"max_hp": {"add": 5.0}, "regen": {"add": 1.0}}, "desc": "x"},
		"special": {"at": 3, "kind": "pulse", "every": 6.0, "name": "Vòng", "desc": "y"}},
}


func test_sub_line_opens_at_its_enhancement_level() -> void:
	var p := Profile.new(LEGEND)
	p.add("crown")
	_check(not p.sub_open("crown") and not p.effects_of("crown").has("regen"), "+0: no dòng phụ")
	p.plus["crown"] = 2
	var e := p.effects_of("crown")
	_check(p.sub_open("crown"), "+2: dòng phụ open")
	_check(is_equal_approx(float(e["regen"]["add"]), 1.0 * 1.4), "sub enhanced like the main line (x1.4), got %s" % e["regen"])
	_check(is_equal_approx(float(e["max_hp"]["add"]), 15.0 * 1.4), "a stat in both lines adds up, got %s" % e["max_hp"])


func test_special_opens_at_its_level_and_only_when_worn() -> void:
	var p := Profile.new(LEGEND)
	p.add("crown")
	p.plus["crown"] = 3
	_check(p.specials("knight").is_empty(), "not worn: no special")
	p.equip("knight", "crown")
	var sp := p.specials("knight")
	_check(sp.size() == 1 and sp[0]["kind"] == "pulse" and sp[0]["item"] == "crown", "worn at +3: pulse from crown, got %s" % [sp])
	p.plus["crown"] = 2
	_check(p.specials("knight").is_empty(), "+2: still locked")


func test_every_legendary_has_a_known_special_and_every_epic_a_sub() -> void:
	var eq: Dictionary = GameData.load_json("res://assets/data/items.json")["equipment"]
	var kinds := ["shield", "retaliate", "pulse", "chain_shock", "revive", "reset_cd", "low_hp_buff", "kill_proc", "hit_buff", "burn_aura", "freeze_nova"]
	for id: String in eq:
		if not eq[id] is Dictionary:
			continue
		var r := String(eq[id].get("rarity", ""))
		if r == "legendary":
			_check(kinds.has(String(eq[id].get("special", {}).get("kind", ""))), "%s: special kind" % id)
		if r == "epic" or r == "legendary":
			_check(not eq[id].get("sub", {}).get("effects", {}).is_empty(), "%s: dòng phụ" % id)


func test_old_saves_move_to_the_new_items() -> void:
	var defs: Dictionary = GameData.load_json("res://assets/data/items.json")["equipment"].duplicate()
	defs.erase("_doc")
	var old := {"bag": ["iron_helm", "swift_boots", "void_crown", "steel_sword"],
		"worn": {"mage": {"head": "void_crown", "legs": "swift_boots"}}, "seen": ["iron_helm"],
		"plus": {"void_crown": 3}}
	var p := Profile.new(defs)
	p.from_dict(old, "mage")
	_check(p.bag.has("cloth_hat") and p.bag.has("cloth_shoes") and p.bag.has("star_hat"), "shared items go to the mage's own, got %s" % [p.bag])
	_check(p.bag.has("steel_sword"), "an id still in the data stays")
	_check(p.equipped("mage").get("head", "") == "star_hat", "worn head renamed")
	_check(p.equipped("mage").get("feet", "") == "cloth_shoes" and not p.equipped("mage").has("legs"), "boots move from the old legs slot to feet, got %s" % [p.equipped("mage")])
	_check(p.plus_of("star_hat") == 3, "Cường hoá carries over")
