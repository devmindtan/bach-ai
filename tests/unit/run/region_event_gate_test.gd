extends RefCounted
## design/region-events-plan.md §5: region events (every kind) start at stage 5;
## each region has one own event with config, a source name and an icon.

const Run := preload("res://src/run/run.gd")
const OWN := ["tornado", "falling_trees", "poison_tide"]

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_region_events_open_from_stage_5() -> void:
	var cfg := GameData.load_json("res://assets/data/run_config.json")
	_check(not Run.events_open(cfg, 1), "stage 1 quiet")
	_check(not Run.events_open(cfg, 4), "stage 4 quiet")
	_check(Run.events_open(cfg, 5), "stage 5 open")
	_check(Run.events_open(cfg, 6), "stage 6 open")
	_check(Run.events_open({}, 1), "no min_stage key: always open (old configs)")


func test_each_region_has_one_own_event_with_data() -> void:
	var cfg := GameData.load_json("res://assets/data/run_config.json")
	var ev: Dictionary = cfg["events"]
	var st := GameData.load_json("res://assets/data/stages.json")
	for r: Dictionary in st["regions"]:
		var own := 0
		for e: Dictionary in r.get("events", []):
			var k := String(e["kind"])
			_check(k != "meteor", "%s: meteor is replaced" % r["name"])
			if k in OWN:
				own += 1
		_check(own == 1, "%s: exactly one own event (got %d)" % [r["name"], own])
	for k: String in OWN:
		_check(ev.has(k), "config for " + k)
		_check(String(ev["source_names"].get("event." + k, "")).begins_with("Sự kiện: "), "source name for " + k)
		_check(UiIcons.texture(String(ev["source_icons"].get("event." + k, ""))) != null, "icon for " + k)
