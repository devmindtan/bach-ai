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

var defs: Dictionary          # items.json "equipment"
var bag: Array = []           # item ids owned (one entry per copy)
var worn := {}                # class id -> {slot: item id}
var given_starter := false
var seen: Array = []          # item ids the player has looked at ("MỚI" badge until then)


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
		out.append({"id": id, "name": d.get("name", id), "kind": "item", "effects": d.get("effects", {})})
	return out


func levels(cls: String) -> Dictionary:
	var out := {}
	for slot: String in equipped(cls):
		out[equipped(cls)[slot]] = 1
	return out


func to_dict() -> Dictionary:
	return {"version": 1, "bag": bag, "worn": worn, "given_starter": given_starter, "seen": seen}


func from_dict(d: Dictionary) -> void:
	bag = Array(d.get("bag", [])).filter(func(id: Variant) -> bool: return defs.has(String(id)))
	worn = d.get("worn", {})
	given_starter = bool(d.get("given_starter", false))
	# saves from before the badges: everything already owned counts as seen
	seen = Array(d.get("seen", bag.duplicate()))
