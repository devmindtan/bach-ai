extends RefCounted
## User 2026-11-26: "mở khóa dần là bắt buộc cho tất cả nhân vật". A class can be created once any character has
## won the stage unlocks.json lists for it (class_<id>); Kiếm sĩ is open from the start.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _slot(best: int) -> Slot:
	var s := Slot.new({})
	s.best = best
	return s


func test_every_class_but_the_first_has_an_unlock_stage() -> void:
	var u := Unlocks.load_default()
	var classes := GameData.load_json("res://assets/data/classes.json")
	_check(u.need("class_knight") == 0, "Kiếm sĩ is open from the start")
	for cid: String in classes:
		if cid.begins_with("_") or cid == "knight":
			continue
		_check(u.need("class_" + cid) > 0, "%s has no unlock stage in unlocks.json" % cid)


func test_a_class_opens_when_any_character_won_its_stage() -> void:
	var u := Unlocks.new({"class_assassin": 6})
	_check(not u.class_open([], "assassin"), "no character yet: locked")
	_check(not u.class_open([{"slot": _slot(5)}, {"slot": _slot(2)}], "assassin"), "best 5 < 6: locked")
	_check(u.class_open([{"slot": _slot(1)}, {"slot": _slot(6)}], "assassin"), "one character won stage 6: open")
	_check(u.class_open([{"slot": null}], "knight"), "a class with no gate is open; a broken file is skipped")
