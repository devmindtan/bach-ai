extends RefCounted
## Gacha (design/gacha.md): gems pay for pulls, the published rates hold, the
## legendary pity triggers exactly on its pull, banners keep their own pity, a
## duplicate turns into gold, only items the class can wear come out.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _slot(cls := "knight") -> Slot:
	var items := GameData.load_json("res://assets/data/items.json")
	var defs: Dictionary = items.get("equipment", {}).duplicate()
	defs.erase("_doc")
	return SlotStore.new_slot("Thử", cls, defs)


func test_pulls_cost_gems() -> void:
	var g := Gacha.load_default()
	var s := _slot()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	s.gems = g.cost(1) - 1
	_check(g.pull(s, "weapon", 1, rng).is_empty() and s.gems == g.cost(1) - 1, "not enough gems: no pull, nothing taken")
	s.gems = g.cost(10)
	var r: Array = g.pull(s, "weapon", 10, rng)
	_check(r.size() == 10 and s.gems == 0, "10 pulls for cost(10)")


func test_rates_match_the_published_ones() -> void:
	var g := Gacha.load_default()
	var rates: Dictionary = g.data["rates"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 200000
	var count := {}
	for i in n:
		var r := g.roll_rarity(rng, 0)   # pity counter 0: the plain rates
		count[r] = int(count.get(r, 0)) + 1
	for r: String in rates:
		var got := float(count.get(r, 0)) / n
		_check(absf(got - float(rates[r])) < 0.01, "%s: %.3f vs published %.3f" % [r, got, float(rates[r])])


func test_pity_gives_a_legendary_on_its_pull_and_banners_are_separate() -> void:
	var g := Gacha.load_default()
	var s := _slot()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var pity := g.pity_at()
	s.pity["weapon"] = pity - 1
	s.gems = g.cost(1)
	var r: Array = g.pull(s, "weapon", 1, rng)
	_check(r.size() == 1 and String(r[0]["rarity"]) == "legendary", "pull %d is legendary" % pity)
	_check(int(s.pity["weapon"]) == 0, "pity reset after a legendary")
	_check(int(s.pity.get("armor", 0)) == 0, "the armour banner's pity untouched")


func test_only_wearable_items_and_duplicates_become_gold() -> void:
	var g := Gacha.load_default()
	var s := _slot("mage")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	s.gems = g.cost(10) * 10
	var dup_gold := 0
	for k in 10:
		for r: Dictionary in g.pull(s, "armor", 10, rng):
			var d: Dictionary = s.profile.defs.get(String(r["id"]), {})
			_check(not d.has("class") or String(d["class"]) == "mage", "%s wearable by a mage" % r["id"])
			_check(String(d.get("slot", "")) != "weapon", "armour banner: no weapon (%s)" % r["id"])
			if bool(r["dup"]):
				dup_gold += int(r["gold"])
	_check(dup_gold > 0, "100 pulls of a small pool give duplicates turned into gold")


func test_history_keeps_the_last_pulls_newest_first() -> void:
	var g := Gacha.load_default()
	var s := _slot_for_history()
	s.gems = 100000
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var a := g.pull(s, "weapon", 1, rng, 100.0)
	var b := g.pull(s, "weapon", 10, rng, 200.0)
	var h := Gacha.history(s, "weapon")
	_check(h.size() == 11, "11 pulls logged, got %d" % h.size())
	_check(is_equal_approx(float(h[0]["t"]), 200.0) and is_equal_approx(float(h[10]["t"]), 100.0), "newest first")
	_check(String(h[10]["id"]) == String(a[0]["id"]) and String(h[0]["id"]) == String(b[9]["id"]), "same items as the pulls")
	_check(Gacha.history(s, "armor").is_empty(), "each banner its own log")
	var keep := int(g.data.get("history_keep", 100))
	for k in 12:
		g.pull(s, "weapon", 10, rng, 300.0 + k)
	_check(Gacha.history(s, "weapon").size() == keep, "capped at history_keep %d" % keep)


func test_history_survives_save_and_load() -> void:
	var g := Gacha.load_default()
	var s := _slot_for_history()
	s.gems = 100
	var rng := RandomNumberGenerator.new()
	g.pull(s, "armor", 1, rng, 50.0)
	var copy := _slot_for_history()
	copy.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check(Gacha.history(copy, "armor").size() == 1, "log saved with the slot")


func _slot_for_history() -> Slot:
	var defs: Dictionary = GameData.load_json("res://assets/data/items.json")["equipment"].duplicate()
	defs.erase("_doc")
	var s := Slot.new(defs)
	s.cls = "knight"
	return s
