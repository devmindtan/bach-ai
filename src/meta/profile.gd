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
const SLOTS := ["head", "chest", "legs", "arms", "feet", "weapon"]   # Mũ, Áo, Quần, Tay, Giày, Vũ khí
const MAX_PLUS := 10         # the highest Cường hoá of any tier (legendary); max_plus(id) is the item's own
# user 2026-11-20: items carry no skills; a higher tier only reaches a higher level and opens more sub lines
const TIER_MAX_PLUS := {"common": 3, "rare": 5, "epic": 7, "legendary": 10}
const SUB_AT := [2, 4, 6]   # sub line k opens at Cường hoá SUB_AT[k]
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


## The highest Cường hoá of [param id]: by its tier (Thường +3 … Huyền thoại +10).
func max_plus(id: String) -> int:
	return int(TIER_MAX_PLUS.get(String(defs.get(id, {}).get("rarity", "common")), 3))


## The sub lines (Dòng phụ) of [param id], in opening order: "subs", or the older single "sub".
func subs_of(id: String) -> Array:
	var d: Dictionary = defs.get(id, {})
	if d.has("subs"):
		return d["subs"]
	return [d["sub"]] if d.has("sub") else []


## How many sub lines of [param id] are open at its Cường hoá level.
func open_subs(id: String) -> int:
	var n := 0
	for k in subs_of(id).size():
		if plus_of(id) >= int(SUB_AT[mini(k, SUB_AT.size() - 1)]):
			n += 1
	return n


## Gold the next enhancement of [param id] costs (0 at the top level).
func enhance_cost(id: String) -> int:
	if not defs.has(id) or plus_of(id) >= max_plus(id):
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
	var parts: Array = [defs.get(id, {}).get("effects", {})]
	var subs := subs_of(id)
	for n in open_subs(id):   # Dòng phụ: added once unlocked, enhanced like the main line
		parts.append(subs[n].get("effects", {}))
	for eff: Dictionary in parts:
		for stat: String in eff:
			var e: Dictionary = out.get(stat, {}).duplicate()
			for key in ["add", "mul"]:
				if eff[stat].has(key):
					e[key] = float(e.get(key, 0.0)) + float(eff[stat][key]) * k
			out[stat] = e
	return out


## Dòng phụ of [param id] is active: the item has one and its Cường hoá level
## reached the line's "at" (design/equipment.md).
func sub_open(id: String) -> bool:
	return open_subs(id) > 0


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


func from_dict(d: Dictionary, cls := "") -> void:
	var renamed: Dictionary = GameData.load_json("res://assets/data/items.json").get("equipment_renamed", {})
	bag = []
	for id: Variant in d.get("bag", []):
		var nid := _current(String(id), cls, renamed)
		if defs.has(nid):
			bag.append(nid)
	worn = {}
	var old_worn: Dictionary = d.get("worn", {})
	for c: String in old_worn:   # old ids, and boots that sat in the old "legs" slot, go to the new item's slot
		var w := {}
		for slot: String in old_worn[c]:
			var nid := _current(String(old_worn[c][slot]), c, renamed)
			if defs.has(nid) and defs[nid] is Dictionary:
				w[String(defs[nid].get("slot", slot))] = nid
		worn[c] = w
	given_starter = bool(d.get("given_starter", false))
	# saves from before the badges: everything already owned counts as seen
	seen = Array(d.get("seen", bag.duplicate())).map(func(id: Variant) -> String: return _current(String(id), cls, renamed))
	plus = {}
	var old_plus: Dictionary = d.get("plus", {})
	for id: String in old_plus:   # Cường hoá carries over to the renamed item
		var nid := _current(id, cls, renamed)
		plus[nid] = maxi(int(plus.get(nid, 0)), int(old_plus[id]))


## [param id] itself while the data still has it, else its renamed id.
func _current(id: String, cls: String, renamed: Dictionary) -> String:
	return id if defs.has(id) else renamed_id(id, cls, renamed)


## The current id of item [param id] from an older save (items.json
## "equipment_renamed": an id, or {class: id} for items both classes shared).
static func renamed_id(id: String, cls: String, renamed: Dictionary) -> String:
	if not renamed.has(id) or id.begins_with("_"):
		return id
	var to: Variant = renamed[id]
	if to is Dictionary:
		return String(to.get(cls, to.values()[0] if not to.is_empty() else id))
	return String(to)
