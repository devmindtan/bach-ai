class_name Profile
extends RefCounted
## The player's lasting things between runs: the equipment bag and what each
## class wears (one item per slot: head, chest, arms, legs, weapon). Saved to
## user://profile.json. Equipment works like level-1 upgrades in PlayerStats.
##
## Example:
##   var p := Profile.load_or_new(items["equipment"])
##   p.add("iron_helm"); p.equip("knight", "iron_helm"); p.save()
##   PlayerStats.compute(base, pool + p.as_upgrades("knight"), levels.merged(p.levels("knight")))

const PATH := "user://profile.json"
const SLOTS := ["head", "chest", "arms", "legs", "weapon"]
const MAX_PLUS := 5          # Cường hoá: +1..+5 (design/equipment.md)
const PLUS_STEP := 0.2       # each level adds 20% of the item's own effects
const PLUS_COST := {"common": 30, "rare": 60, "epic": 120, "legendary": 200}   # gold for +1; x (level + 1)

var defs: Dictionary          # items.json "equipment"
var bag: Array = []           # item ids owned (one entry per copy)
var worn := {}                # class id -> {slot: item id}
var given_starter := false
var seen: Array = []          # item ids the player has looked at ("MỚI" badge until then)
var plus := {}                # item id -> enhancement level (Cường hoá), all copies of it share it


func _init(p_defs: Dictionary) -> void:
	defs = p_defs


## The profile on disk, or a new one; [param fixed] (tests, screenshots) never reads
## or writes the disk.
static func load_or_new(p_defs: Dictionary, fixed := false) -> Profile:
	var p := Profile.new(p_defs)
	if not fixed and FileAccess.file_exists(PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary:
			p.from_dict(data)
	return p


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(to_dict(), "  "))


## True while [param id] is owned and not looked at yet (the bag's "MỚI" badge).
func is_new(id: String) -> bool:
	return bag.has(id) and not seen.has(id)


func mark_seen(id: String) -> void:
	if not seen.has(id):
		seen.append(id)


func plus_of(id: String) -> int:
	return int(plus.get(id, 0))


## Gold the next enhancement of [param id] costs (0 at the top level).
func enhance_cost(id: String) -> int:
	if plus_of(id) >= MAX_PLUS or not defs.has(id):
		return 0
	return int(PLUS_COST.get(String(defs[id].get("rarity", "common")), 30)) * (plus_of(id) + 1)


## Raises [param id] one level, paying from [param gold] ({"v": amount}, written
## back by the caller); false when owned not, at the top or not enough gold.
func enhance(id: String, gold: Dictionary) -> bool:
	var cost := enhance_cost(id)
	if cost <= 0 or not bag.has(id) or int(gold.get("v", 0)) < cost:
		return false
	gold["v"] = int(gold["v"]) - cost
	plus[id] = plus_of(id) + 1
	return true


## The item's effects at its enhancement level.
func effects_of(id: String) -> Dictionary:
	var k := 1.0 + PLUS_STEP * plus_of(id)
	var out := {}
	var eff: Dictionary = defs.get(id, {}).get("effects", {})
	for stat: String in eff:
		var e: Dictionary = eff[stat].duplicate()
		for key in ["add", "mul"]:
			if e.has(key):
				e[key] = float(e[key]) * k
		out[stat] = e
	return out


func add(id: String) -> void:
	if defs.has(id):
		bag.append(id)


## Puts [param id] (from the bag) on class [param cls] in its slot; false when the
## item is not owned or is for another class.
func equip(cls: String, id: String) -> bool:
	if not bag.has(id) or not defs.has(id):
		return false
	var d: Dictionary = defs[id]
	if d.has("class") and String(d["class"]) != cls:
		return false
	if not worn.has(cls):
		worn[cls] = {}
	worn[cls][String(d.get("slot", ""))] = id
	return true


func unequip(cls: String, slot: String) -> void:
	if worn.has(cls):
		worn[cls].erase(slot)


## {slot: item id} worn by class [param cls].
func equipped(cls: String) -> Dictionary:
	return worn.get(cls, {})


## Owned items that fit [param slot] on class [param cls] (no duplicates).
func choices(cls: String, slot: String) -> Array:
	var out := []
	for id: String in bag:
		var d: Dictionary = defs.get(id, {})
		if String(d.get("slot", "")) == slot and (not d.has("class") or String(d["class"]) == cls) and not out.has(id):
			out.append(id)
	return out


## Worn items as upgrade entries ({id, name, kind "item", effects}) for PlayerStats.
func as_upgrades(cls: String) -> Array:
	var out := []
	for slot: String in equipped(cls):
		var id: String = equipped(cls)[slot]
		var d: Dictionary = defs.get(id, {})
		out.append({"id": id, "name": d.get("name", id), "kind": "item", "effects": effects_of(id)})
	return out


func levels(cls: String) -> Dictionary:
	var out := {}
	for slot: String in equipped(cls):
		out[equipped(cls)[slot]] = 1
	return out


func to_dict() -> Dictionary:
	return {"version": 1, "bag": bag, "worn": worn, "given_starter": given_starter, "seen": seen, "plus": plus}


func from_dict(d: Dictionary) -> void:
	bag = Array(d.get("bag", [])).filter(func(id: Variant) -> bool: return defs.has(String(id)))
	worn = d.get("worn", {})
	given_starter = bool(d.get("given_starter", false))
	# saves from before the badges: everything already owned counts as seen
	seen = Array(d.get("seen", bag.duplicate()))
	plus = d.get("plus", {})
