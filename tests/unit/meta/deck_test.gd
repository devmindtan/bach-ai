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
