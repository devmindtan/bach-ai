extends RefCounted
## design/species.md (roadmap E2): every monster names a known species, every skill a known element,
## and species name only known elements and statuses.

var failures: Array[String] = []


func test_monsters_species_and_skill_elements_are_valid() -> void:
	var sp := GameData.load_json("res://assets/data/species.json")
	var species: Dictionary = sp["species"]
	var elements: Dictionary = sp["elements"]
	var statuses: Dictionary = GameData.load_json("res://assets/data/statuses.json")["statuses"]
	for id: String in GameData.load_json("res://assets/data/monsters.json"):
		var m = GameData.load_json("res://assets/data/monsters.json")[id]
		if id.begins_with("_") or not m is Dictionary:
			continue
		if not species.has(String(m.get("species", ""))):
			failures.append("monster %s has no known species" % id)
	for f in ["knight", "mage"]:
		for u: Dictionary in GameData.load_json("res://assets/data/upgrades_%s.json" % f)["upgrades"]:
			if u.get("kind") == "skill" and not elements.has(String(u.get("element", ""))):
				failures.append("skill %s has no known element" % u["id"])
	for sid: String in species:
		var s: Dictionary = species[sid]
		for e in s.get("weak", []) + s.get("resist", []):
			if not elements.has(String(e)):
				failures.append("species %s names unknown element %s" % [sid, e])
		for st in s.get("immune_status", []):
			if not statuses.has(String(st)):
				failures.append("species %s names unknown status %s" % [sid, st])
