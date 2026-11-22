extends RefCounted
## design/ux/stage-detail.md (roadmap D2): the Chi tiết table's data.

const StageSelect := preload("res://src/front/stage_select.gd")

var failures: Array[String] = []


func test_boss_stage_timeline_sorted_with_boss_and_region_events() -> void:
	var stages := Stages.load_default()
	var monsters := GameData.load_json("res://assets/data/monsters.json")
	var cfg: Dictionary = GameData.load_json("res://assets/data/run_config.json")["events"]
	var st := stages.load_stage(30)
	var marks := StageSelect.detail_timeline(st, monsters, stages.region(30).get("events", []), 30, int(cfg["min_stage"]), cfg)
	var last := -1.0
	var boss := false
	var event := false
	for mk: Array in marks:
		if float(mk[0]) < last:
			failures.append("marks not sorted at %s" % mk[1])
		last = float(mk[0])
		boss = boss or String(mk[1]).begins_with("BOSS")
		event = event or String(mk[1]).begins_with("Sự kiện")
	if not boss:
		failures.append("stage 30 timeline has no boss")
	if not event:
		failures.append("stage 30 timeline has no region event")


func test_early_stage_has_no_region_events() -> void:
	var stages := Stages.load_default()
	var monsters := GameData.load_json("res://assets/data/monsters.json")
	var cfg: Dictionary = GameData.load_json("res://assets/data/run_config.json")["events"]
	var marks := StageSelect.detail_timeline(stages.load_stage(1), monsters, stages.region(1).get("events", []), 1, int(cfg["min_stage"]), cfg)
	for mk: Array in marks:
		if String(mk[1]).begins_with("Sự kiện"):
			failures.append("stage 1 lists %s before min_stage" % mk[1])


func test_monsters_scaled_and_elites_marked() -> void:
	var monsters := GameData.load_json("res://assets/data/monsters.json")
	var st := {"waves": [{"monster": "slime", "t_from": 0}, {"monster": "slime@elite", "t_from": 40, "burst": 3}]}
	var rows := StageSelect.detail_monsters(st, monsters, 2.0, 3.0)
	if rows.size() != 1:
		failures.append("one monster row, got %d" % rows.size())
		return
	if not is_equal_approx(float(rows[0]["hp"]), float(monsters["slime"]["hp"]) * 2.0) or not bool(rows[0]["elite"]):
		failures.append("slime row wrong: %s" % rows[0])


func test_species_line_names_weak_and_resist() -> void:
	var sp := GameData.load_json("res://assets/data/species.json")
	var line := StageSelect.species_line("ooze", sp)
	if line != "Nhầy · yếu Lửa · kháng Vật lý":
		failures.append("ooze line: %s" % line)
	if StageSelect.species_line("goblinoid", sp) != "Yêu tinh":
		failures.append("goblin line: %s" % StageSelect.species_line("goblinoid", sp))
