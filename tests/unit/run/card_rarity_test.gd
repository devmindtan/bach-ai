extends RefCounted
## Card rarity (design/card-rarity.md): each hand slot rolls a tier (60/30/9/1), then a card of that tier
## from the deck; missing tiers step down; nothing left gives a filler; a pity raises the epic odds;
## the gold chest has no commons.

var failures: Array[String] = []

const CFG := {"tiers": ["common", "rare", "epic", "legendary"],
	"weights": {"level": [60, 30, 9, 1], "chest": [20, 50, 25, 5], "gold_chest": [0, 50, 40, 10]},
	"pity_step": 1.0, "fillers": [{"id": "filler_gold", "kind": "filler"}]}


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _pool() -> Array:
	var p := []
	for k in 6:
		p.append({"id": "c%d" % k, "rarity": "common", "max_level": 5})
	for k in 4:
		p.append({"id": "r%d" % k, "rarity": "rare", "max_level": 5})
	for k in 3:
		p.append({"id": "e%d" % k, "rarity": "epic", "max_level": 5})
	return p


func _tier(id: String) -> String:
	return {"c": "common", "r": "rare", "e": "epic", "f": "filler"}.get(id.left(1), "?")


func test_tiers_come_at_their_odds() -> void:
	var rr := CardRarity.new(CFG)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var n := {"common": 0, "rare": 0, "epic": 0}
	for k in 3000:
		rr.pity = 0.0   # the pity is tested on its own
		for id in rr.roll(_pool(), {}, 1, rng, "level"):
			n[_tier(id)] = int(n.get(_tier(id), 0)) + 1
	_check(n["common"] > 1600 and n["common"] < 2000, "commons ~60%%, got %d / 3000" % n["common"])
	_check(n["epic"] > 180 and n["epic"] < 420, "epics ~9-10%% (the legendary slot steps down), got %d" % n["epic"])


func test_a_missing_tier_steps_down_then_gives_a_filler() -> void:
	var rr := CardRarity.new(CFG)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var only_epic := [{"id": "e0", "rarity": "epic", "max_level": 5}]
	var fillers := 0
	for k in 300:
		rr.pity = 0.0
		var hand := rr.roll(only_epic, {}, 1, rng, "level")
		if hand[0] == "filler_gold":
			fillers += 1
	_check(fillers > 240, "a deck of only epics gets fillers for its common / rare rolls, got %d / 300" % fillers)


func test_pity_raises_the_epic_odds_until_one_comes() -> void:
	var rr := CardRarity.new(CFG)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	rr.pity = 0.0
	var before := rr.chances("level")
	rr.note("common")
	rr.note("rare")
	var after := rr.chances("level")
	_check(after[2] > before[2] and after[0] < before[0], "two misses: epic up, common down")
	rr.note("epic")
	_check(is_zero_approx(rr.pity), "an epic resets the pity")


func test_the_gold_chest_never_gives_commons() -> void:
	var rr := CardRarity.new(CFG)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 200:
		for id in rr.roll(_pool(), {}, 3, rng, "gold_chest"):
			_check(_tier(id) != "common", "a common from the gold chest")


func test_a_hand_has_no_duplicates() -> void:
	var rr := CardRarity.new(CFG)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 100:
		var hand := rr.roll(_pool(), {}, 3, rng, "level")
		var seen := {}
		for id in hand:
			_check(not seen.has(id) or id.begins_with("filler"), "duplicate %s" % id)
			seen[id] = true
