extends RefCounted
## End-of-run damage table (6D.3): every row shows a Vietnamese name, never a raw id. Regression: the
## meteor shower event hit monsters as source "meteor" and the knight's table showed "meteor".

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run() -> Node:
	var Run := load("res://src/run/run.gd")
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.class_data = classes["knight"]
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.enemies = Enemies.new(GameData.load_json("res://assets/data/monsters.json"), r.cfg, {}, 1)
	return r


func test_event_and_unknown_sources_get_vietnamese_names() -> void:
	var r := _run()
	r.enemies.damage_by = {"blade_arc": 50.0, MeteorShower.SOURCE: 30.0, "zzz_unknown": 5.0}
	var names := {}
	for row: Dictionary in r.damage_report():
		names[row["id"]] = row["name"]
	_check(names.get(MeteorShower.SOURCE, "") == "Mưa thiên thạch", "the meteor shower row: %s" % names.get(MeteorShower.SOURCE))
	_check(names.get("zzz_unknown", "") == "Khác", "an unknown source reads Khác, got %s" % names.get("zzz_unknown"))
	for id: String in names:
		_check(names[id] != id, "row %s shows its raw id" % id)
	r.free()
