extends RefCounted
## Progressive lobby unlocks (design/ux/progressive-unlocks.md): a new slot sees only Trang bị; Bộ thẻ opens
## after stage 3, Gacha and Cây kỹ năng after stage 5.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_new_slot_sees_only_equipment() -> void:
	var u := Unlocks.load_default()
	var s := Slot.new({})
	s.best = 0
	_check(u.is_open(s, "equipment"), "Trang bị is locked for a new player")
	for f in ["deck", "gacha", "tree"]:
		_check(not u.is_open(s, f), "%s is open before any win" % f)


func test_milestones() -> void:
	var u := Unlocks.load_default()
	var s := Slot.new({})
	s.best = 3
	_check(u.is_open(s, "deck") and not u.is_open(s, "tree"), "stage 3 should open Bộ thẻ only")
	s.best = 5
	_check(u.is_open(s, "gacha") and u.is_open(s, "tree"), "stage 5 does not open Gacha and Cây kỹ năng")
	_check(u.need("deck") == 3 and u.need("tree") == 5, "unlocks.json milestones changed")
