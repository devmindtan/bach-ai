extends RefCounted
## The whole meta loop in one go (user 2026-11-18: form the game first): a new
## character wins stages (gold, gems), picks up Tinh hoa, buys a skill-tree node,
## pulls the gacha, enhances and wears an item, wins a challenge (Tẩy Tủy Đan),
## resets the tree; everything survives a save and the run's stats see it.
## Uses its own folder under user:// and removes it.

const DIR := "user://test_loop/"

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _clean() -> void:
	var d := DirAccess.open(DIR)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func test_win_earn_spend_save_and_reload() -> void:
	_clean()
	var items := GameData.load_json("res://assets/data/items.json")
	var defs: Dictionary = items.get("equipment", {}).duplicate()
	defs.erase("_doc")
	var store := SlotStore.new(defs, DIR)
	var s := store.create("Vòng chơi", "knight")
	var stages := Stages.load_default()
	for n in range(1, 11):
		s.record_win(n, stages)
	_check(s.best == 10 and s.gold > 0 and s.gems >= 100, "10 stages: best 10, gold %d, gems %d" % [s.gold, s.gems])
	s.essence += 12   # elites / bosses picked up over those runs
	var tree := SkillTree.load_default()
	_check(tree.buy(s, "k_root"), "a skill-tree node bought with Tinh hoa")
	var g := Gacha.load_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var bag_before := s.profile.bag.size()
	var got := g.pull(s, "weapon", 10, rng)
	_check(got.size() == 10 and (s.profile.bag.size() > bag_before or s.gold > 0), "10 pulls: new items or gold")
	var weapon := ""
	for id: String in s.profile.bag:
		if String(defs[id].get("slot", "")) == "weapon":
			weapon = id
	_check(weapon != "" and s.profile.equip("knight", weapon), "a pulled weapon worn")
	s.gold += 1000
	var wallet := {"v": s.gold}
	_check(s.profile.enhance(weapon, wallet), "the weapon enhanced with gold")
	s.gold = int(wallet["v"])
	var ch := Challenges.load_default()
	ch.record_win(s, "bat_night")
	_check(s.pills == 2, "a challenge win gives Tẩy Tủy Đan")
	var spent := tree.spent(s)
	var ess := s.essence
	_check(tree.reset(s) and s.essence == ess + spent and s.pills == 1, "the tree reset refunds Tinh hoa, takes a pill")
	tree.buy(s, "k_root")
	store.save(s)
	var back: Slot = store.load_slot(s.id)["slot"]
	_check(back != null, "the slot loads back")
	if back == null:
		_clean()
		return
	_check(back.best == 10 and back.gems == s.gems and back.gold == s.gold and back.essence == s.essence and back.pills == 1,
		"progress and wallet saved")
	_check(back.tree == ["k_root"] and back.profile.plus_of(weapon) == 1 and back.profile.equipped("knight").get("weapon", "") == weapon,
		"tree, enhancement and worn weapon saved")
	# what a run of this character computes
	var base: Dictionary = GameData.load_json("res://assets/data/classes.json")["knight"]["stats"]
	var plain := PlayerStats.compute(base, [], {})
	var lasting := SkillTree.lasting(back)
	var full := PlayerStats.compute(base, lasting[0], lasting[1])
	_check(float(full["damage"]) > float(plain["damage"]), "the run sees the node and the weapon: damage %s > %s" % [full["damage"], plain["damage"]])
	_clean()
