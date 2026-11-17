class_name SlotStore
extends RefCounted
## The character slots on disk (user://slots/<id>.json, design/progression.md):
## list, create, save, delete. A slot file that cannot be read is listed with
## its error and never stops the other slots from loading.
##
## Example:
##   var store := SlotStore.new(equipment_defs)
##   var s := store.create("An", "mage")
##   for e in store.list(): print(e["id"], " ", e["error"])

const DIR := "user://slots/"
const MAX := 4

var defs: Dictionary          # items.json "equipment"
var dir := DIR


func _init(p_defs: Dictionary, p_dir := DIR) -> void:
	defs = p_defs
	dir = p_dir


## Every slot file: [{id, slot (Slot or null), error ("" when it loaded)}], by id.
func list() -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var files := []
	for f in d.get_files():
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	for f: String in files:
		out.append(load_slot(f.get_basename()))
	return out


## {id, slot, error} for slot [param id].
func load_slot(id: String) -> Dictionary:
	var path := dir + id + ".json"
	if not FileAccess.file_exists(path):
		return {"id": id, "slot": null, "error": "không có file"}
	var json := JSON.new()   # not JSON.parse_string: a broken file is reported here, not logged as an engine error
	var data: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not data is Dictionary:
		return {"id": id, "slot": null, "error": "file hỏng"}
	var s := Slot.new(defs)
	var err := s.from_dict(data)
	if err != "":
		return {"id": id, "slot": null, "error": err}
	s.id = id
	return {"id": id, "slot": s, "error": ""}


func save(s: Slot) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + s.id + ".json", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(s.to_dict(), "  "))
	return true


func delete(id: String) -> void:
	var path := dir + id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)


## True when another slot can be created.
func has_room() -> bool:
	return list().size() < MAX


## A new slot (saved) with the starter items of its class worn; null when all
## MAX slots are taken.
func create(p_name: String, cls: String) -> Slot:
	var taken := {}
	for e: Dictionary in list():
		taken[e["id"]] = true
	if taken.size() >= MAX:
		return null
	var k := 1
	while taken.has("slot%d" % k):
		k += 1
	var s := new_slot(p_name, cls, defs)
	s.id = "slot%d" % k
	save(s)
	return s


## A slot in memory with the class's starter items (items.json "starter") worn.
static func new_slot(p_name: String, cls: String, p_defs: Dictionary) -> Slot:
	var s := Slot.new(p_defs)
	s.name = p_name
	s.cls = cls
	s.profile.given_starter = true
	for id: String in p_defs:
		var d: Dictionary = p_defs[id]
		if bool(d.get("starter", false)) and (not d.has("class") or String(d["class"]) == cls):
			s.profile.add(id)
			s.profile.equip(cls, id)
			s.profile.mark_seen(id)   # starter items are not news
	return s
