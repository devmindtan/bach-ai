extends RefCounted
## Rương vàng (design/events.md, after Vampire Survivors' rarer chests and Diablo III's Resplendent
## Chest): a share of the chests that drop are gold; picking one up is counted apart from plain chests,
## and opening it gives several picks, gold and a sure item.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_chest_kind_follows_the_chance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var gold := 0
	for k in 2000:
		if Pickups.chest_kind(rng, 0.08) == Pickups.GOLD_CHEST:
			gold += 1
	_check(gold > 100 and gold < 220, "about 8%% of 2000 chests are gold, got %d" % gold)
	_check(Pickups.chest_kind(rng, 0.0) == Pickups.CHEST, "chance 0: always a plain chest")


func test_a_gold_chest_is_counted_apart() -> void:
	var p := Pickups.new({"radius": 70.0, "collect_radius": 14.0}, 10)
	p.drop(Pickups.GOLD_CHEST, Vector2(5, 0), 1.0)
	p.drop(Pickups.CHEST, Vector2(-5, 0), 1.0)
	p.step(0.1, Vector2.ZERO, 1.0)
	_check(p.gold_chests == 1 and p.chests == 1, "one gold, one plain: got %d gold, %d plain" % [p.gold_chests, p.chests])


func test_opening_a_gold_chest_gives_picks_gold_and_an_item() -> void:
	var Run := load("res://src/run/run.gd")
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	var g: Dictionary = r.cfg["events"]["gold_chest"]
	r.rng = RandomNumberGenerator.new()
	var before_gold := int(r.gold)
	r.open_gold_chest()
	_check(r.pending_levels == int(g["picks"]), "%d picks queued, got %d" % [int(g["picks"]), r.pending_levels])
	_check(int(r.gold) - before_gold == int(g["gold"]), "gold +%d" % int(g["gold"]))
	_check(r.chests_opened == int(g["counts_as"]), "counts as %d chests for Mảnh thẻ" % int(g["counts_as"]))
	_check(r.level_up_title(true).begins_with("Rương vàng"), "the panel says Rương vàng: %s" % r.level_up_title(true))
	r.free()
