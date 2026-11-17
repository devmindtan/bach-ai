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
