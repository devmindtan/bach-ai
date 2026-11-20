extends RefCounted
## Decks (design/skill-tree-v2.md §2): up to 8 skill + 6 stat cards; the class's starting skill is always
## in; unique (milestone) skills are never deck cards; a run only offers the deck's cards.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _ups() -> Array:
	var out := []
	for i in 10:
		out.append({"id": "s%d" % i, "kind": "skill", "weight": 10 - i})
	for i in 9:
		out.append({"id": "t%d" % i, "kind": "stat", "weight": 9 - i})
	out.append({"id": "u0", "kind": "skill", "unique": true})
	return out


const CFG := {"skills": 8, "stats": 6, "slots": 3}


func test_default_deck_fills_both_parts_with_the_start_skill() -> void:
	var d := Deck.default_cards(_ups(), ["s5"], CFG)
	_check(d.has("s5"), "the starting skill is in")
	_check(Deck.count(d, _ups(), "skill") == 8 and Deck.count(d, _ups(), "stat") == 6, "8 skills + 6 stats, got %s" % [d])
	_check(not d.has("u0"), "unique skills are not deck cards")


func test_add_and_remove_respect_the_rules() -> void:
	var d := Deck.default_cards(_ups(), ["s5"], CFG)
	_check(Deck.why_not_add(d, _ups(), "s9", CFG) != "", "no 9th skill")
	_check(Deck.why_not_remove(d, "s5", ["s5"]) != "", "the starting skill cannot leave")
	d = Deck.remove(d, "s0", ["s5"])
	_check(Deck.why_not_add(d, _ups(), "s9", CFG) == "", "room for a skill again")
	_check(Deck.why_not_add(d, _ups(), "u0", CFG) != "", "a unique skill cannot be added")


func test_run_pool_keeps_only_deck_cards_and_uniques() -> void:
	var d := ["s5", "s1", "t2"]
	var ids := []
	for u: Dictionary in Deck.filter(_ups(), d):
		ids.append(String(u["id"]))
	_check(ids.has("s5") and ids.has("s1") and ids.has("t2"), "deck cards stay")
	_check(not ids.has("s0") and not ids.has("t0"), "cards outside the deck are gone")
	_check(ids.has("u0"), "unique milestone skills stay (they come from milestones)")


func test_active_deck_of_a_slot() -> void:
	var s := Slot.new({})
	_check(Deck.active(s, _ups(), ["s5"], CFG).size() == 14, "no saved deck: the default one")
	s.decks = [{"name": "Bộ 1", "cards": ["s5", "t1"]}]
	s.deck_active = 0
	_check(Deck.active(s, _ups(), ["s5"], CFG) == ["s5", "t1"], "the saved active deck")


const BCFG := {"skills": 8, "stats": 6, "slots": 3, "budget": 3, "cost": {"common": 0, "rare": 1, "epic": 2, "legendary": 3}}


func _rare_ups() -> Array:
	return [{"id": "c0", "kind": "skill", "rarity": "common"}, {"id": "c1", "kind": "skill", "rarity": "common"},
		{"id": "r0", "kind": "skill", "rarity": "rare"}, {"id": "e0", "kind": "skill", "rarity": "epic", "weight": 9},
		{"id": "e1", "kind": "stat", "rarity": "epic", "weight": 9}]


func test_the_deck_budget_caps_rare_cards() -> void:
	# design/card-rarity.md: a deck of only rare cards is held back by a point budget
	var ups := _rare_ups()
	var d := ["c0", "e0"]
	_check(Deck.points(d, ups, BCFG) == 2, "an epic costs 2")
	_check(Deck.why_not_add(d, ups, "r0", BCFG) == "", "a rare fits (3 / 3)")
	_check(Deck.why_not_add(d, ups, "e1", BCFG).contains("điểm"), "a second epic busts the budget")
	_check(Deck.why_not_add(d, ups, "c1", BCFG) == "", "commons are free")


func test_default_and_saved_decks_stay_within_the_budget() -> void:
	var ups := _rare_ups()
	var d := Deck.default_cards(ups, ["c0"], BCFG)
	_check(Deck.points(d, ups, BCFG) <= 3, "the default deck keeps the budget, got %s" % [d])
	_check(Deck.points(Deck.within_budget(["c0", "e0", "e1", "r0"], ups, ["c0"], BCFG), ups, BCFG) <= 3, "an old saved deck is trimmed")


func test_the_default_deck_spends_its_budget_on_skills_first() -> void:
	# regression: the default deck spent all 7 points on three special stat cards and held 2 skills
	var ups: Array = GameData.load_json("res://assets/data/upgrades_knight.json")["upgrades"]
	var cfg: Dictionary = GameData.load_json("res://assets/data/card_trees.json")["deck"]
	var d := Deck.default_cards(ups, ["blade_arc"], cfg)
	_check(Deck.count(d, ups, "skill") >= 5, "at least 5 skills, got %d: %s" % [Deck.count(d, ups, "skill"), d])
	_check(Deck.points(d, ups, cfg) <= int(cfg["budget"]), "within the budget")
