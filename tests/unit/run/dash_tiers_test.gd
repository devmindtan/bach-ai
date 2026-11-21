extends RefCounted
## The plan's last skill without its own look per level: Lướt (dash). Its afterimage trail grows with the
## level (skills.dash.trail_tiers): more ghosts, a tier colour, speed streaks from tier III.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_dash_trail_changes_with_each_level() -> void:
	for cls in ["knight", "mage"]:
		var r: Node = Run.new()
		r.pool = GameData.load_json("res://assets/data/upgrades_%s.json" % cls)
		var prev := {}
		for lv in range(1, 6):
			r.levels = {"dash": lv}
			var st: Dictionary = r.dash_trail_style()
			_check(int(st.get("count", 0)) >= 3, "%s lv%d: at least 3 ghosts" % [cls, lv])
			if not prev.is_empty():
				_check(int(st["count"]) >= int(prev["count"]), "%s lv%d: no fewer ghosts than before" % [cls, lv])
				_check(st["color"] != prev["color"] or int(st["count"]) > int(prev["count"]) or bool(st.get("streaks")) != bool(prev.get("streaks")),
					"%s lv%d: looks different from lv%d" % [cls, lv, lv - 1])
			prev = st
		_check(bool(prev.get("streaks", false)), "%s: speed streaks at the top tier" % cls)
		r.free()
