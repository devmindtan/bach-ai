extends RefCounted
## Roadmap item 5 (review 2026-11-21): code reads run_config.json with `cfg.get("key", default)`; a default that
## differs from the JSON value silently changes the game when the key is renamed or removed. A numeric default
## must equal the JSON value, or be neutral (0 / 1: the feature off) when that is its meaning.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_files(dir + "/" + sub, out)


func test_run_config_defaults_match_the_data() -> void:
	var cfg := GameData.load_json("res://assets/data/run_config.json")
	var re := RegEx.create_from_string("cfg\\.get\\(\"([a-z_]+)\",\\s*(?:\\{\\})\\)\\.get\\(\"([a-z_]+)\",\\s*(-?[0-9.]+)\\)|cfg\\.get\\(\"([a-z_]+)\",\\s*(-?[0-9.]+)\\)")
	var files: Array[String] = []
	_files("res://src", files)
	var n := 0
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			for m in re.search_all(lines[i]):
				n += 1
				var v: Variant
				var dv: float
				var key: String
				if m.get_string(1) != "":
					var sec: Variant = cfg.get(m.get_string(1))
					key = m.get_string(1) + "." + m.get_string(2)
					v = (sec as Dictionary).get(m.get_string(2)) if sec is Dictionary else null
					dv = float(m.get_string(3))
				else:
					key = m.get_string(4)
					v = cfg.get(key)
					dv = float(m.get_string(5))
				if (v is float or v is int) and not is_equal_approx(float(v), dv):
					_check(dv == 0.0 or dv == 1.0, "%s:%d default %s for %s differs from run_config %s" % [path.get_file(), i + 1, dv, key, v])
	_check(n > 20, "the scan found the config reads (%d)" % n)
