extends RefCounted
## Bug 2026-11-22: "FX: sprite 'arcane-bolt-impact-iii' is not loaded for this run" — the gold goblin's escape
## puff was a sprite name typed in code, loaded only when the mage's bolt was in the run. Any sprite name typed in
## an _add_fx("...") call must be in the run's always-loaded list (run.gd: var names ... = [...]).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_literal_fx_sprites_are_always_loaded() -> void:
	var run_src := FileAccess.get_file_as_string("res://src/run/run.gd")
	var base := RegEx.create_from_string("var names: Array\\[String\\] = \\[([^\\]]*)\\]").search(run_src)
	_check(base != null, "the always-loaded list is found")
	if base == null:
		return
	var re := RegEx.create_from_string("_add_fx\\(\"([a-z0-9-]+)\"")
	var d := DirAccess.open("res://src/run")
	var files: Array[String] = []
	for f in d.get_files():
		if f.ends_with(".gd"):
			files.append("res://src/run/" + f)
	for path in files:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			_check(base.get_string(1).contains("\"%s\"" % m.get_string(1)), "%s: '%s' typed in code but not always loaded" % [path.get_file(), m.get_string(1)])
