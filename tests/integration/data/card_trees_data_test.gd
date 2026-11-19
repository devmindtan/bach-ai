extends RefCounted
## card_trees.json is consistent (design/skill-tree-v2.md): trees belong to real skill cards, every
## "requires" node exists, keystone exclusions are mutual, statuses exist, names are Vietnamese.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_card_trees_are_consistent() -> void:
	var d := GameData.load_json("res://assets/data/card_trees.json")
	var skills := {}
	for f in ["upgrades_knight.json", "upgrades_mage.json"]:
		for u: Dictionary in GameData.load_json("res://assets/data/" + f).get("upgrades", []):
			if String(u.get("kind", "")) == "skill":
				skills[String(u["id"])] = true
	var statuses: Dictionary = GameData.load_json("res://assets/data/statuses.json").get("statuses", {})
	for card: String in d.get("cards", {}):
		_check(skills.has(card), "%s: a tree for a card that is not a skill card" % card)
		var ids := {}
		for n: Dictionary in d["cards"][card].get("nodes", []):
			ids[String(n["id"])] = n
		for n: Dictionary in d["cards"][card].get("nodes", []):
			var id := String(n["id"])
			_check(String(n.get("name", "")) != "" and String(n.get("name", "")) != id, "%s.%s: needs a Vietnamese name" % [card, id])
			for r: String in n.get("requires", []):
				_check(ids.has(r), "%s.%s requires missing node %s" % [card, id, r])
			for ex: String in n.get("excludes", []):
				_check(ids.has(ex) and id in ids[ex].get("excludes", []), "%s.%s excludes %s but not back" % [card, id, ex])
			for oh: Dictionary in n.get("on_hit", []):
				_check(statuses.has(String(oh.get("status", ""))), "%s.%s: unknown status %s" % [card, id, oh.get("status")])
