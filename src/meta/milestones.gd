class_name Milestones
extends RefCounted
## Level milestone rewards (assets/data/milestones.json, design/progression.md):
## what levels 7/14/21 of a run offer a class, each reward's name / description /
## icon, and the numbers of the rewards picked in this run (they end with it).
##
## Example:
##   var m := Milestones.load_default()
##   var ids := m.offers(7, "mage")              # ["sp_star_pants", "sp_star_shoes", "bloodthirst", "twin_cast"]
##   var heal := m.number(owned, "heal_frac")     # 0.2 when the run has Khát máu

const PATH := "res://assets/data/milestones.json"

var data: Dictionary


func _init(p_data: Dictionary) -> void:
	data = p_data


static func load_default() -> Milestones:
	return Milestones.new(GameData.load_json(PATH))


## Levels that give a reward, ascending.
func milestone_levels() -> Array[int]:
	var out: Array[int] = []
	for k: String in data.get("levels", {}):
		out.append(int(k))
	out.sort()
	return out


func reward(id: String) -> Dictionary:
	return data.get("rewards", {}).get(id, {})


## The rewards level [param n] offers class [param cls] (the other class's unique skill left out).
func offers(n: int, cls: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in data.get("levels", {}).get(str(n), []):
		var r := reward(id)
		if not r.has("class") or String(r["class"]) == cls:
			out.append(id)
	return out


## Rewards offered at a milestone (user 2026-11-22: shuffled across all milestones, not fixed per level):
## offer_count ids drawn from every level's rewards that fit class [param cls], minus [param owned].
func random_offers(cls: String, owned: Array, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for lv in milestone_levels():
		for id in offers(lv, cls):
			if not owned.has(id) and not pool.has(id):
				pool.append(id)
	for i in range(pool.size() - 1, 0, -1):   # Fisher-Yates with the run's rng (seeded runs stay repeatable)
		var j := rng.randi_range(0, i)
		var t := pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, mini(int(data.get("offer_count", 4)), pool.size()))


## {name, desc, kind, icon} of reward [param id]; a skill reward reads its card in
## [param upgrades] (upgrades_<class>.json "upgrades").
func info(id: String, upgrades: Array) -> Dictionary:
	var r := reward(id)
	var out := {"id": id, "kind": String(r.get("kind", "")), "icon": String(r.get("icon", id)),
		"name": String(r.get("name", id)), "desc": String(r.get("desc", ""))}
	if out["kind"] in ["skill", "card"]:
		var cid := String(r.get("skill", r.get("card", id)))
		for u: Dictionary in upgrades:
			if String(u.get("id", "")) == cid:
				out["icon"] = String(r.get("icon", u.get("icon", cid)))
				out["name"] = String(u.get("name", id))
				out["desc"] = String(u.get("desc", ""))
	return out


## Skill ids the owned rewards [param owned] start at level 1.
func skills(owned: Array) -> Array[String]:
	var out: Array[String] = []
	for id: String in owned:
		var r := reward(id)
		if String(r.get("kind", "")) == "skill":
			out.append(String(r.get("skill", id)))
		elif String(r.get("kind", "")) == "card":   # one-level special card (former item special, 2026-11-20)
			out.append(String(r.get("card", id)))
	return out


## Owned rewards with "effects" as upgrade entries for PlayerStats (level 1 each).
func as_upgrades(owned: Array) -> Array:
	var out := []
	for id: String in owned:
		var r := reward(id)
		if r.has("effects"):
			out.append({"id": "milestone." + id, "name": r.get("name", id), "kind": "milestone", "effects": r["effects"]})
	return out


func levels(owned: Array) -> Dictionary:
	var out := {}
	for u: Dictionary in as_upgrades(owned):
		out[u["id"]] = 1
	return out


## The reward among [param owned] that has [param key]; {} when none does.
func with_key(owned: Array, key: String) -> Dictionary:
	for id: String in owned:
		var r := reward(id)
		if r.has(key):
			return r
	return {}


## Number [param key] of the owned reward that has it, else [param fallback].
func number(owned: Array, key: String, fallback := 0.0) -> float:
	var r := with_key(owned, key)
	return float(r.get(key, fallback))
