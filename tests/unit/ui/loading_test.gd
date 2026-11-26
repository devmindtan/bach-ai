extends RefCounted
## The light loading screen between the stage map and the run (user 2026-11-26): it says where the run goes and the
## stage map opens it instead of the run.

const Loading := preload("res://src/front/loading.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_heading_names_the_stage_the_endless_run_or_the_challenge() -> void:
	var st := Stages.load_default()
	var h: Array = Loading.heading(st, 11, false, "")
	_check(String(h[1]) == "Ải 11" and String(h[0]) == String(st.region(11).get("name", "")).to_upper(), "stage 11: region + Ải 11, got %s" % [h])
	_check(String(Loading.heading(st, 10, false, "")[1]) == "Trùm · Ải 10", "a boss stage says so, got %s" % [Loading.heading(st, 10, false, "")])
	_check(String(Loading.heading(st, 5, true, "")[1]) == "Vô tận", "endless")
	_check(String(Loading.heading(st, 5, false, "bat_night")[1]) == "Đêm dơi", "a challenge by its name, got %s" % [Loading.heading(st, 5, false, "bat_night")])


func test_the_stage_map_starts_runs_through_the_loading_screen() -> void:
	var src := FileAccess.get_file_as_string("res://src/front/stage_select.gd")
	_check(src.contains("res://src/front/loading.tscn"), "stage_select opens the loading screen")
	_check(ResourceLoader.exists("res://src/front/loading.tscn"), "the loading scene exists")
