extends RefCounted
## Character tree v2 (design/skill-tree-v2.md §1): multi-rank nodes on a grid bought with Tinh hoa
## (row_cost), requires / requires_points / excludes, a reset needs Tẩy Tủy Đan + gold and refunds
## exactly what was spent, v1 nodes in old saves are refunded, ranks change stats like card levels.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _slot(cls := "knight") -> Slot:
	var items := GameData.load_json("res://assets/data/items.json")
	var defs: Dictionary = items.get("equipment", {}).duplicate()
	defs.erase("_doc")
	return SlotStore.new_slot("Thử", cls, defs)


func test_each_class_has_a_rooted_tree_with_exclusive_keystones() -> void:
	var t := SkillTree.load_default()
	for cls in ["knight", "mage"]:
		var nodes: Array = t.nodes(cls)
		_check(nodes.size() >= 10, "%s: >= 10 nodes, got %d" % [cls, nodes.size()])
		var icons := {}
		var keys := 0
		for n: Dictionary in nodes:
			icons[String(n.get("icon", ""))] = true
			if bool(n.get("keystone", false)):
				keys += 1
				_check(int(n.get("requires_points", 0)) > 0 and not n.get("excludes", []).is_empty(), "%s: keystone gated and exclusive" % n["id"])
			for q: String in n.get("requires", []):
				_check(not t.node(q).is_empty(), "%s requires a missing node %s" % [n["id"], q])
		_check(keys >= 2, "%s: >= 2 keystones" % cls)
		_check(icons.size() >= nodes.size() - 1, "%s: icons nearly all different (%d for %d nodes)" % [cls, icons.size(), nodes.size()])


func test_buy_ranks_need_essence_and_the_parent() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	_check(t.why_not(s, "k_root") != "", "no Tinh hoa: cannot buy")
	s.essence = 1000
	_check(t.why_not(s, "k_b0_1") != "", "child before the root: refused")
	var c := t.cost("k_root")
	_check(t.buy(s, "k_root") and s.essence == 1000 - c and t.rank(s, "k_root") == 1, "root rank 1, cost taken")
	_check(t.buy(s, "k_root") and t.buy(s, "k_root") and t.rank(s, "k_root") == 3, "root to rank 3")
	_check(not t.buy(s, "k_root"), "past max rank: refused")
	_check(t.buy(s, "k_b0_1"), "then the child")
	_check(not t.buy(s, "m_root"), "a mage node on a knight: refused")


func test_keystones_need_points_and_exclude_each_other() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	s.essence = 5000
	for id in ["k_root", "k_b0_1", "k_b0_2", "k_b0_3", "k_b1_1", "k_b1_2", "k_b1_3"]:
		t.buy(s, id)
	_check(t.points(s) < 12 and t.why_not(s, "k_key_0").contains("điểm"), "keystone before 12 points: refused (%d)" % t.points(s))
	while t.points(s) < 12:
		for id in ["k_root", "k_b0_1", "k_b0_2", "k_b0_3", "k_b1_1", "k_b1_2", "k_b1_3"]:
			if t.why_not(s, id) == "":
				t.buy(s, id)
				break
	_check(t.buy(s, "k_key_0"), "keystone at 12 points")
	_check(t.why_not(s, "k_key_1") != "", "a second keystone: refused")


func test_reset_needs_the_pill_and_gold_and_refunds_exactly() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	s.essence = 100
	t.buy(s, "k_root")
	t.buy(s, "k_root")
	t.buy(s, "k_b0_1")
	var cost := t.reset_cost(s)
	_check(int(cost["gold"]) >= 50, "reset costs gold")
	_check(not t.reset(s), "no Tẩy Tủy Đan: refused")
	s.pills = 1
	s.gold = int(cost["gold"]) - 1
	_check(not t.reset(s), "not enough gold: refused")
	s.gold = int(cost["gold"])
	_check(t.reset(s), "reset with the pill and the gold")
	_check(s.tree.is_empty() and s.essence == 100 and s.pills == 0 and s.gold == 0, "all refunded, pill and gold paid")
	_check(not t.reset(s), "a second reset with nothing bought does nothing")


func test_v1_nodes_in_an_old_save_are_refunded() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	s.tree = ["k_fury_1", "k_fury_2", "k_root"]
	s.essence = 0
	_check(t.migrate(s), "an old save migrates")
	_check(s.essence == 15 and s.tree == ["k_root"], "5 + 10 Tinh hoa back, v2 node kept: %d %s" % [s.essence, s.tree])
	_check(not t.migrate(s), "a second migrate does nothing")


func test_ranks_change_stats_and_survive_a_save() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	s.essence = 100
	var base: Dictionary = GameData.load_json("res://assets/data/classes.json")["knight"]["stats"]
	t.buy(s, "k_root")
	var one := PlayerStats.compute(base, t.as_upgrades(s), t.levels(s))
	t.buy(s, "k_root")
	var two := PlayerStats.compute(base, t.as_upgrades(s), t.levels(s))
	_check(float(two["max_hp"]) - float(one["max_hp"]) == 5.0, "rank 2 adds another 5 hp: %s -> %s" % [one["max_hp"], two["max_hp"]])
	var back := _slot()
	back.from_dict(s.to_dict())
	_check(t.rank(back, "k_root") == 2 and back.essence == s.essence, "ranks and Tinh hoa saved on the slot")


func test_the_tree_applies_in_a_run() -> void:
	var t := SkillTree.load_default()
	var s := _slot()
	s.essence = 100
	t.buy(s, "k_root")
	t.buy(s, "k_b0_1")
	var Run := load("res://src/run/run.gd")
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r._recompute_stats()
	var plain := float(r.stats["damage"])
	r.tree_owner = s
	r._recompute_stats()
	_check(float(r.stats["damage"]) > plain, "Lưỡi sắc raises damage in the run: %s -> %s" % [plain, r.stats["damage"]])
	r.free()
