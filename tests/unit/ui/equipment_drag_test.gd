extends RefCounted
## Túi đồ kéo thả (design/ux/equipment.md, user 2026-11-19): an item dragged from the bag onto the
## matching slot round the hero is worn; onto another slot it is refused; a worn item dragged from its
## slot back onto the bag is taken off. Bag cells show only the icon and "+n" when enhanced.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _screen() -> Node2D:
	var items := GameData.load_json("res://assets/data/items.json")
	var defs: Dictionary = items.get("equipment", {}).duplicate()
	defs.erase("_doc")
	var s := SlotStore.new_slot("Thử", "knight", defs)
	s.profile.add("steel_helm")
	s.profile.add("iron_chest")
	var scr: Node2D = load("res://src/front/equipment.gd").new()
	scr._slot_data = s
	scr._prof = s.profile
	scr._cls = "knight"
	return scr


func test_dropping_a_bag_item_on_its_slot_wears_it() -> void:
	var scr := _screen()
	var data: Dictionary = scr.bag_drag_data("steel_helm")
	_check(scr.can_drop_on_slot("head", data), "a helmet fits the head slot")
	_check(not scr.can_drop_on_slot("chest", data), "a helmet does not fit the chest slot")
	_check(scr.drop_on_slot("head", data), "dropped on the head slot")
	_check(scr._prof.equipped("knight").get("head", "") == "steel_helm", "the helmet is worn")
	_check(not scr.drop_on_slot("chest", scr.bag_drag_data("steel_helm")), "dropping on the wrong slot changes nothing")
	scr.free()


func test_dropping_a_worn_item_on_the_bag_takes_it_off() -> void:
	var scr := _screen()
	scr._prof.equip("knight", "iron_chest")
	var data: Dictionary = scr.slot_drag_data("chest")
	_check(not data.is_empty(), "a worn item can be dragged from its slot")
	_check(scr.slot_drag_data("legs").is_empty(), "an empty slot gives nothing to drag")
	_check(scr.can_drop_on_bag(data) and not scr.can_drop_on_bag(scr.bag_drag_data("steel_helm")), "the bag takes worn items only")
	_check(scr.drop_on_bag(data) and not scr._prof.equipped("knight").has("chest"), "taken off")
	scr.free()


func test_a_bag_cell_shows_plus_only_when_enhanced() -> void:
	var scr := _screen()
	_check(scr.plus_text("steel_helm") == "", "not enhanced: no corner mark")
	scr._prof.plus["steel_helm"] = 2
	_check(scr.plus_text("steel_helm") == "+2", "enhanced twice: +2, got '%s'" % scr.plus_text("steel_helm"))
	scr.free()
