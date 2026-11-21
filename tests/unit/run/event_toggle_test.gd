extends RefCounted
## run_config events.<kind>.enabled = false switches an event off (added 2026-11-21 to pause the
## meteor shower, since removed: design/region-events-plan.md step 6).

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_enabled_false_switches_an_event_off() -> void:
	var cfg := {"events": {"ring": {}, "tornado": {"enabled": false}}}
	_check(not Run.event_enabled(cfg, "tornado"), "enabled: false switches an event off")
	_check(Run.event_enabled(cfg, "ring"), "ring still runs")
	_check(Run.event_enabled(cfg, "collect"), "an event without the flag runs")
