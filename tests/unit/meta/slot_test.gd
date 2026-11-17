extends RefCounted
## Tests for Slot and SlotStore (design/progression.md): save and load, schema
## version, a broken file not hiding the other slots, rewards on first and later
## wins, the milestone queue. Uses its own folder under user:// and removes it.

const DIR := "user://test_slots/"

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _defs() -> Dictionary:
	var items := GameData.load_json("res://assets/data/items.json")
	var d: Dictionary = items.get("equipment", {}).duplicate()
	d.erase("_doc")
	return d


func _clean() -> void:
	var d := DirAccess.open(DIR)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))


func test_create_save_and_load_back() -> void:
	_clean()
	var store := SlotStore.new(_defs(), DIR)
	var s := store.create("An", "mage")
	_check(s != null and s.id == "slot1", "first slot is slot1")
	s.record_win(1, Stages.load_default())
	s.gold += 7
	store.save(s)
	var back: Dictionary = store.load_slot("slot1")
	var b: Slot = back["slot"]
	_check(back["error"] == "" and b != null, "loads back")
	if b != null:
		_check(b.name == "An" and b.cls == "mage" and b.best == 1 and b.gold == s.gold, "same name, class, best, gold")
		_check(not b.profile.equipped("mage").is_empty(), "starter items worn")
	_clean()


func test_broken_file_does_not_hide_other_slots() -> void:
	_clean()
	var store := SlotStore.new(_defs(), DIR)
	store.create("An", "knight")
	store.create("Bình", "mage")
	var f := FileAccess.open(DIR + "slot1.json", FileAccess.WRITE)
	f.store_string("{ not json")
	f = null
	var newer := FileAccess.open(DIR + "slot3.json", FileAccess.WRITE)
	newer.store_string(JSON.stringify({"version": 99, "name": "X"}))
	newer = null
	var all := store.list()
	_check(all.size() == 3, "three files listed, got %d" % all.size())
	var ok := 0
	for e: Dictionary in all:
		if e["error"] == "":
			ok += 1
			_check((e["slot"] as Slot).name == "Bình", "the good slot is Bình")
		else:
			_check(e["slot"] == null, "a broken slot has no Slot")
	_check(ok == 1, "one slot still loads")
	_check(String(store.load_slot("slot3")["error"]).contains("mới hơn"), "a newer version is reported")
	_clean()


func test_max_slots() -> void:
	_clean()
	var store := SlotStore.new(_defs(), DIR)
	for k in SlotStore.MAX:
		store.create("S%d" % k, "knight")
	_check(store.create("Thêm", "knight") == null and not store.has_room(), "no fifth slot")
	store.delete("slot2")
	var s := store.create("Lại", "mage")
	_check(s != null and s.id == "slot2", "a deleted id is reused")
	_clean()


func test_rewards_and_milestone_queue() -> void:
	var stages := Stages.load_default()
	var s := SlotStore.new_slot("An", "knight", _defs())
	var first := s.record_win(10, stages)
	_check(bool(first["first"]) and int(first["milestone"]) == 10 and s.pending == [10], "first win of 10 queues its milestone")
	var again := s.record_win(10, stages)
	_check(not bool(again["first"]) and int(again["milestone"]) == 0 and int(again["gems"]) < int(first["gems"]), "a repeat gives less, no milestone")
	_check(s.unlocked(30) == 11, "stage 11 unlocked")
	_check(not s.choose_milestone(20, "x"), "cannot choose a milestone not won")
	_check(s.choose_milestone(10, "bloodthirst") and s.pending.is_empty() and s.rewards() == ["bloodthirst"], "milestone chosen")
	s.record_win(10, stages)
	_check(s.pending.is_empty(), "a chosen milestone is not queued again")
