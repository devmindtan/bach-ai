extends RefCounted
## Card trees (design/skill-tree-v2.md): every skill card has a free-branching tree of multi-rank nodes
## bought with Mảnh thẻ; edges need the node before; keystones need points spent in the card and exclude
## each other; max_points caps a card; reset refunds everything; ranks become effects for the run.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _tree() -> CardTree:
	return CardTree.new({
		"cost_base": 2, "cost_step": 1,
		"cards": {"cut": {"max_points": 6, "nodes": [
			{"id": "sharp", "max_rank": 3, "effects": {"skill_damage.cut": {"mul": 0.1}}},
			{"id": "wide", "max_rank": 2, "requires": ["sharp"], "effects": {"skill_area.cut": {"mul": 0.12}}},
			{"id": "twin", "max_rank": 1, "requires": ["wide"], "effects": {"skill_count.cut": {"add": 1}}},
			{"id": "fire", "max_rank": 1, "requires": ["sharp"], "requires_points": 4, "excludes": ["storm"],
				"on_hit": [{"status": "burn", "dps_mul": 0.3, "time": 2.0}]},
			{"id": "storm", "max_rank": 1, "requires": ["sharp"], "requires_points": 4, "excludes": ["fire"]},
		]}}})


func _slot(shards: int) -> Slot:
	var s := Slot.new({})
	s.shards = shards
	return s


func test_buying_costs_more_each_rank_and_respects_edges() -> void:
	var t := _tree()
	var s := _slot(100)
	_check(t.why_not(s, "cut", "wide") != "", "wide needs sharp first")
	_check(t.cost(s, "cut") == 2, "first point costs cost_base 2")
	_check(t.buy(s, "cut", "sharp"), "buy sharp 1")
	_check(t.cost(s, "cut") == 3, "second point costs 3")
	_check(t.buy(s, "cut", "sharp") and t.buy(s, "cut", "sharp"), "sharp to 3")
	_check(not t.buy(s, "cut", "sharp"), "sharp stops at max_rank 3")
	_check(t.rank(s, "cut", "sharp") == 3, "sharp rank 3")
	_check(s.shards == 100 - 2 - 3 - 4, "paid 2+3+4, shards %d" % s.shards)


func test_keystones_need_points_and_exclude_each_other() -> void:
	var t := _tree()
	var s := _slot(100)
	t.buy(s, "cut", "sharp")
	_check(t.why_not(s, "cut", "fire") != "", "fire needs 4 points in the card")
	t.buy(s, "cut", "sharp"); t.buy(s, "cut", "sharp"); t.buy(s, "cut", "wide")
	_check(t.buy(s, "cut", "fire"), "fire opens after 4 points")
	_check(t.why_not(s, "cut", "storm") != "", "storm is excluded by fire")


func test_max_points_caps_the_card() -> void:
	var t := _tree()
	var s := _slot(1000)
	for id in ["sharp", "sharp", "sharp", "wide", "wide", "twin"]:
		t.buy(s, "cut", id)
	_check(t.points(s, "cut") == 6, "6 points spent")
	_check(t.why_not(s, "cut", "fire") != "", "no point left past max_points 6")


func test_not_enough_shards() -> void:
	var t := _tree()
	var s := _slot(1)
	_check(not t.buy(s, "cut", "sharp") and s.shards == 1, "cannot buy without enough Mảnh thẻ")


func test_reset_refunds_every_shard() -> void:
	var t := _tree()
	var s := _slot(100)
	t.buy(s, "cut", "sharp"); t.buy(s, "cut", "sharp"); t.buy(s, "cut", "wide")
	t.reset(s, "cut")
	_check(s.shards == 100 and t.points(s, "cut") == 0, "reset refunds all, shards %d" % s.shards)


func test_ranks_become_effects_and_statuses() -> void:
	var t := _tree()
	var s := _slot(100)
	t.buy(s, "cut", "sharp"); t.buy(s, "cut", "sharp")
	t.buy(s, "cut", "sharp"); t.buy(s, "cut", "wide"); t.buy(s, "cut", "fire")
	var ups := t.as_upgrades(s)
	var lv := t.levels(s)
	var st := PlayerStats.compute({"damage": 10.0}, ups, lv)
	_check(absf(PlayerStats.skill_mul(st, "skill_damage.cut") - 1.3) < 0.001, "sharp 3 ranks: x1.3, got %.3f" % PlayerStats.skill_mul(st, "skill_damage.cut"))
	_check(t.on_hit(s, "cut").size() == 1 and String(t.on_hit(s, "cut")[0]["status"]) == "burn", "fire adds a burn on hit")


func test_slot_saves_shards_and_trees() -> void:
	var t := _tree()
	var s := _slot(50)
	t.buy(s, "cut", "sharp")
	var s2 := Slot.new({})
	s2.from_dict(s.to_dict())
	_check(s2.shards == 48 and int(s2.card_trees.get("cut", {}).get("sharp", 0)) == 1, "shards and card trees round-trip")
