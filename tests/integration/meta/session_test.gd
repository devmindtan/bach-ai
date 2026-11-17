extends RefCounted
## Integration tests for the phase-3 session (design/progression.md): the selected
## slot and stage must survive a restart; level milestone rewards end with the
## run (nothing on the slot). Uses temporary folders.

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


func test_milestone_rewards_end_with_the_run() -> void:
	# a reward picked at level 10 is not saved on the slot and the next run starts without it
	_clean()
	var p := _prefs()
	p.ensure_slots()
	var slot: Slot = p.active_slot
	var r: Node = Run.new()
	r.class_data = GameData.load_json("res://assets/data/classes.json")["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = r.class_data["stats"]
	r.milestones = Milestones.load_default()
	r.playing_slot = slot
	r._recompute_stats()
	r.take_milestone("bloodthirst")
	_check(is_equal_approx(r.heal_on_kill(), 0.2), "Khát máu works in this run")
	p.slot_store().save(slot)
	var text := FileAccess.get_file_as_string(SLOTS + "slot1.json")
	_check(not text.contains("bloodthirst"), "the reward is not written to the slot file")
	var next: Node = Run.new()
	_check(next.rewards.is_empty(), "the next run starts without milestone rewards")
	r.free()
	next.free()
	_clean()
