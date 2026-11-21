extends RefCounted
## User 2026-11-21: Mưa thiên thạch has nothing to do with the regions' content, so it is
## switched off (run_config events.meteor.enabled = false) until it is redesigned.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_meteor_event_is_off_others_stay_on() -> void:
	var cfg := GameData.load_json("res://assets/data/run_config.json")
	_check(not Run.event_enabled(cfg, "meteor"), "meteor shower is switched off")
	_check(Run.event_enabled(cfg, "ring"), "ring still runs")
	_check(Run.event_enabled(cfg, "collect"), "an event without the flag runs")
