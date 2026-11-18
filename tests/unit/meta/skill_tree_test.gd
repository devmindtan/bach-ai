extends RefCounted
## Skill tree (design/skill-tree.md): nodes bought with Tinh hoa in tier order,
## a reset needs Tẩy Tủy Đan + gold and refunds exactly what was spent, bought
## nodes change stats like a card.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _slot(cls := "knight") -> Slot:
	var items := GameData.load_json("res://assets/data/items.json")
	var defs: Dictionary = items.get("equipment", {}).duplicate()
	defs.erase("_doc")
	return SlotStore.new_slot("Thử", cls, defs)


func test_each_class_has_three_branches_of_three_tiers() -> void:
	var t := SkillTree.load_default()
	for cls in ["knight", "mage"]:
		var br: Array = t.branches(cls)
		_check(br.size() == 3, "%s: 3 branches, got %d" % [cls, br.size()])
		for b: Dictionary in br:
			_check(b.get("nodes", []).size() == 3, "%s %s: 3 tiers" % [cls, b.get("id")])


func test_buy_needs_essence_and_the_tier_before() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	var first: String = t.branches("knight")[0]["nodes"][0]["id"]
	var second: String = t.branches("knight")[0]["nodes"][1]["id"]
	_check(t.why_not(s, first) != "", "no Tinh hoa: cannot buy")
	s.essence = 100
	_check(t.why_not(s, second) != "", "tier 2 before tier 1: refused")
	_check(t.buy(s, first) and s.essence == 100 - t.cost(first), "tier 1 bought, its cost taken")
	_check(not t.buy(s, first), "the same node twice: refused")
	_check(t.buy(s, second) and s.tree.has(second), "then tier 2")
	var mage_node: String = t.branches("mage")[0]["nodes"][0]["id"]
	_check(not t.buy(s, mage_node), "a mage node on a knight: refused")


func test_reset_needs_the_pill_and_gold_and_refunds_exactly() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	s.essence = 100
	var nodes: Array = t.branches("knight")[0]["nodes"]
	t.buy(s, String(nodes[0]["id"]))
	t.buy(s, String(nodes[1]["id"]))
	var spent := 100 - s.essence
	var cost := t.reset_cost(s)
	_check(int(cost["gold"]) >= 50, "reset costs gold")
	_check(not t.reset(s), "no Tẩy Tủy Đan: refused")
	s.pills = 1
	s.gold = int(cost["gold"]) - 1
	_check(not t.reset(s), "not enough gold: refused")
	s.gold = int(cost["gold"])
	_check(t.reset(s), "reset with the pill and the gold")
	_check(s.tree.is_empty() and s.essence == 100 and s.pills == 0 and s.gold == 0, "all %d refunded, pill and gold paid" % spent)
	_check(not t.reset(s), "a second reset with nothing bought does nothing")
	_check(s.essence == 100, "no essence made out of thin air")


func test_bought_nodes_change_stats_and_survive_a_save() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	s.essence = 100
	var base: Dictionary = GameData.load_json("res://assets/data/classes.json")["knight"]["stats"]
	var before := PlayerStats.compute(base, t.as_upgrades(s), t.levels(s))
	var dmg_node := ""
	for b: Dictionary in t.branches("knight"):
		for n: Dictionary in b["nodes"]:
			if dmg_node == "" and n.get("effects", {}).has("damage"):
				dmg_node = n["id"]
	_check(dmg_node != "" and t.buy(s, dmg_node), "a damage node bought")
	var after := PlayerStats.compute(base, t.as_upgrades(s), t.levels(s))
	_check(float(after["damage"]) > float(before["damage"]), "damage up: %s -> %s" % [before["damage"], after["damage"]])
	var back := _slot()
	back.from_dict(s.to_dict())
	_check(back.tree == s.tree and back.essence == s.essence, "tree and Tinh hoa saved on the slot")
