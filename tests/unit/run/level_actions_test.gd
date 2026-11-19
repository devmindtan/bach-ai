extends RefCounted
## Đổi / Loại / Bỏ qua at level-up (6C.3, after Vampire Survivors' Reroll / Banish / Skip): limited
## charges a run (run_config.json level_actions); a reroll deals a new hand; a banished card never
## comes back this run; a skip spends the level for gold.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run() -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.class_data = classes["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r.levels = {"blade_arc": 1}
	r._recompute_stats()
	r.hp = float(r.stats["max_hp"])
	r.reset_level_actions()
	r.pending_levels = 1
	r.deal_hand()
	return r


func test_charges_come_from_the_config() -> void:
	var r := _run()
	var la: Dictionary = r.cfg["level_actions"]
	_check(r.rerolls == int(la["reroll"]) and r.banishes == int(la["banish"]) and r.skips == int(la["skip"]), "charges as configured")
	r.free()


func test_reroll_deals_a_hand_and_spends_a_charge() -> void:
	var r := _run()
	var before: int = r.rerolls
	_check(r.reroll(), "reroll works with a charge")
	_check(r.rerolls == before - 1 and r.choices.size() > 0 and r.state == Run.State.LEVEL_UP, "a charge spent, still choosing")
	r.rerolls = 0
	_check(not r.reroll(), "no charge: refused")
	r.free()


func test_a_banished_card_never_comes_back() -> void:
	var r := _run()
	var gone: String = r.choices[0]
	_check(r.banish(0), "banish the first card")
	_check(not r.choices.has(gone), "not in the new hand")
	for k in 30:
		r.rerolls = 9
		r.reroll()
		_check(not r.choices.has(gone), "rerolled hand %d still without it" % k)
	r.banishes = 0
	_check(not r.banish(0), "no charge: refused")
	r.free()


func test_skip_spends_the_level_for_gold() -> void:
	var r := _run()
	var gold_before: int = r.gold
	_check(r.skip_level(), "skip with a charge")
	_check(r.gold - gold_before == int(r.cfg["level_actions"]["skip_gold"]), "gold for the skip")
	_check(r.pending_levels == 0 and r.state != Run.State.LEVEL_UP, "the level is used, the panel closed")
	r.free()
