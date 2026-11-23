class_name Unlocks
extends RefCounted
## Progressive lobby unlocks (design/ux/progressive-unlocks.md): which screen opens at which won stage, from
## assets/data/unlocks.json. A new player starts with Trang bị and Chọn ải only and meets one layer at a time.
##
## Example:
##   var u := Unlocks.load_default()
##   if not u.is_open(slot, "deck"): button.disabled = true   # "Qua ải %d" % u.need("deck")

var _need := {}


static func load_default() -> Unlocks:
	return Unlocks.new(GameData.load_json("res://assets/data/unlocks.json"))


func _init(data: Dictionary) -> void:
	for k: String in data:
		if not k.begins_with("_"):
			_need[k] = int(data[k])


## Stage that must be won to open [param feature]; 0 = always open (unknown features too).
func need(feature: String) -> int:
	return int(_need.get(feature, 0))


## True when [param slot] has opened [param feature]; no slot (title preview) counts as open.
func is_open(slot: Slot, feature: String) -> bool:
	return slot == null or slot.best >= need(feature)
