extends RefCounted
## Nhiệm vụ ngày (design/missions.md).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _slot(id := "s1") -> Slot:
	var s := Slot.new({})
	s.id = id
	return s


func test_same_missions_all_day_new_ones_next_day() -> void:
	var d := Daily.load_default()
	var s := _slot()
	var a := d.ensure(s, "2026-11-18").duplicate()
	_check(a.size() == int(d.data["per_day"]), "per_day missions, got %d" % a.size())
	d.add(s, "kills", 10, "2026-11-18")
	_check(d.ensure(s, "2026-11-18") == a, "same list the same day")
	_check(int(s.daily["stats"]["kills"]) == 10, "progress kept the same day")
	d.ensure(s, "2026-11-19")
	_check(s.daily["stats"].is_empty(), "a new day resets progress")


func test_claim_pays_once_after_the_target_and_bonus_after_all() -> void:
	var d := Daily.load_default()
	var s := _slot()
	var ids := d.ensure(s, "2026-11-18")
	var first := String(ids[0])
	_check(not d.claim(s, first), "not finished: no pay")
	for id: String in ids:
		var m := d.mission(id)
		d.add(s, String(m["stat"]), int(m["target"]), "2026-11-18")
	_check(d.claim(s, first) and s.gems == int(d.mission(first)["gems"]), "paid its gems")
	_check(not d.claim(s, first), "only once")
	_check(not d.bonus_ready(s), "bonus waits for every claim")
	for id: String in ids:
		d.claim(s, id)
	var before := s.gems
	_check(d.claim_bonus(s) and s.gems == before + int(d.data["bonus_gems"]), "bonus paid")
	_check(not d.claim_bonus(s), "bonus once a day")


func test_daily_survives_save_and_load() -> void:
	var d := Daily.load_default()
	var s := _slot()
	d.ensure(s, "2026-11-18")
	d.add(s, "runs", 2, "2026-11-18")
	var c := _slot()
	c.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	_check(int(c.daily["stats"]["runs"]) == 2 and c.daily["ids"] == s.daily["ids"], "saved with the slot")
