extends RefCounted
## Integration tests for the phase-3 session (design/progression.md): the selected
## slot and stage must survive a restart, and the milestone choice in a run must
## be one-shot (the end screen must not offer it again). Uses temporary folders.

const Run := preload("res://src/run/run.gd")

const ROOT := "user://test_session/"
const SETTINGS := ROOT + "settings.cfg"
const SLOTS := ROOT + "slots/"

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _clean() -> void:
	var d := DirAccess.open(ROOT)
	if d != null:
		for f in d.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT + f))
		var sd := DirAccess.open(SLOTS)
		if sd != null:
			for f in sd.get_files():
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOTS + f))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOTS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT))


## A Prefs instance wired to the temporary folders (like the real autoload).
func _prefs() -> Prefs:
	var p := Prefs.new()
	p.settings_path = SETTINGS
	p.slot_store().dir = SLOTS
	return p


func test_slot_and_stage_survive_a_restart() -> void:
	_clean()
	var a := _prefs()
	a.ensure_slots()
	_check(a.active_slot != null and a.active_slot.id == "slot1", "first visit creates slot1")
	var second := SlotStore.new(a.slot_store().defs, SLOTS).create("Hai", "mage")
	_check(second != null, "a second slot can be created")
	second.best = 9   # stages 1-10 unlocked
	a.slot_store().save(second)
	_check(a.select_slot("slot2"), "select slot2")
	_check(a.hero == "mage", "the slot fixes the class")
	a.set_value("stage_target", 7)
	var b := _prefs()
	b._load()
	b.ensure_slots()
	_check(b.active_slot != null and b.active_slot.id == "slot2", "the chosen slot survives a restart, got %s" % (
		b.active_slot.id if b.active_slot != null else "null"))
	_check(b.stage_target == 7, "the chosen stage survives a restart, got %d" % b.stage_target)
	_check(b.hero == "mage", "the class follows the slot on restart")
	_clean()


func test_milestone_choice_is_one_shot() -> void:
	_clean()
	var p := _prefs()
	p.ensure_slots()
	var slot: Slot = p.active_slot
	slot.record_win(10, Stages.load_default())
	_check(slot.pending.has(10), "first win at stage 10 queues the reward")
	_check(not slot.record_win(10, Stages.load_default())["first"], "a repeat win does not queue it again")
	var r: Node = Run.new()
	r.class_data = GameData.load_json("res://assets/data/classes.json")["knight"]
	r.playing_slot = slot
	r.stages = Stages.load_default()
	r.stage_number = 10
	r.run_result = {"won": true, "stage": 10, "collected": 12, "milestone": 10, "pending": [10], "next": true}
	r._finish(true)
	_check(r.run_result["first"] == false, "a repeat win is not a first win")
	r.choose_milestone_reward(10, "earthquake")
	_check(int(r.run_result["milestone"]) == 0, "the end screen must not offer the reward again")
	_check(not r.run_result["pending"].has(10), "the pending reward is gone")
	_check(slot.rewards().has("earthquake"), "the reward is saved on the slot")
	p.slot_store().save(slot)
	var back: Dictionary = p.slot_store().load_slot("slot1")
	var loaded: Slot = back["slot"]
	_check(loaded != null and loaded.rewards().has("earthquake"), "the reward survives a reload")
	r.free()
	_clean()


func test_slot_rewards_reach_the_run() -> void:
	_clean()
	var p := _prefs()
	p.ensure_slots()
	var slot: Slot = p.active_slot
	slot.pending.append(10)
	slot.choose_milestone(10, "bloodthirst")
	var r: Node = Run.new()
	r.class_data = GameData.load_json("res://assets/data/classes.json")["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = r.class_data["stats"]
	r.milestones = Milestones.load_default()
	for id: String in slot.rewards():
		r.rewards.append(id)
	r.apply_rewards()
	_check(is_equal_approx(r.heal_on_kill(), 0.2), "the slot's Khát máu is applied to the run")
	r.free()
	_clean()
