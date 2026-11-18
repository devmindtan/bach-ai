extends RefCounted
## Challenge mode (design/challenge.md): challenges unlock by stage progress, are
## built from a stage with their own rules, and a win gives Tẩy Tủy Đan (2 the
## first time, then 1) without counting as stage progress.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _slot() -> Slot:
	var items := GameData.load_json("res://assets/data/items.json")
	var defs: Dictionary = items.get("equipment", {}).duplicate()
	defs.erase("_doc")
	return SlotStore.new_slot("Thử", "knight", defs)


func test_challenges_unlock_by_stage_progress() -> void:
	var c := Challenges.load_default()
	var s := _slot()
	_check(c.ids().size() >= 3, "three challenges")
	_check(not c.mode_open(s), "locked before stage 10")
	s.best = 10
	_check(c.mode_open(s) and c.is_open(s, "bat_night"), "stage 10 opens the mode and Đêm dơi")
	_check(not c.is_open(s, "king_return"), "Vua trở lại needs stage 20")


func test_a_challenge_is_its_stage_with_new_rules() -> void:
	var c := Challenges.load_default()
	var st := c.build("bat_night")
	_check(is_equal_approx(float(st["duration"]), 180.0), "3 minutes, got %s" % st.get("duration"))
	var bursts := 0
	for w: Dictionary in st["waves"]:
		if String(w.get("monster", "")) == "bat" and int(w.get("burst", 0)) >= 60:
			bursts += 1
	_check(bursts >= 2, "60-bat bursts added, got %d" % bursts)
	var king := c.build("king_return")
	var kings := 0
	for w: Dictionary in king["waves"]:
		if String(w.get("monster", "")) == "king_slime":
			kings += int(w.get("burst", 0))
	_check(kings == 2 and not bool(king.get("win_on_boss", true)), "two kings, the run goes to the end, got %d" % kings)


func test_a_win_gives_pills_not_stage_progress() -> void:
	var c := Challenges.load_default()
	var s := _slot()
	s.best = 10
	var r := c.record_win(s, "bat_night")
	_check(int(r["pills"]) == 2 and s.pills == 2, "first win: 2 Tẩy Tủy Đan")
	r = c.record_win(s, "bat_night")
	_check(int(r["pills"]) == 1 and s.pills == 3, "later wins: 1")
	_check(s.best == 10 and int(s.challenge_wins.get("bat_night", 0)) == 2, "best stage unchanged, 2 wins counted")
