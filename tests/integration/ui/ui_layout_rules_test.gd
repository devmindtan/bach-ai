extends RefCounted
## Integration: layout rules for code-built UI, checked on the sources in src/.
##
## A Control given an anchor preset must not also get `.size =`: with full-rect
## anchors the size goes into the right/bottom offsets, so the control becomes
## twice the screen and its centred content lands in the bottom-right corner
## (lobby settings card, 2026-11-17).

const SRC := "res://src/"

var failures: Array[String] = []


func _scripts(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(d), out)


## "<path>:<line> <var>" for every `<var>.size =` after `<var>.set_anchors_preset(`
## in the same function.
static func anchored_and_sized(path: String, text: String) -> Array[String]:
	var out: Array[String] = []
	var anchored := {}
	var lines := text.split("\n")
	for i in lines.size():
		var l := lines[i].strip_edges()
		if lines[i].begins_with("func ") or lines[i].begins_with("static func "):
			anchored.clear()
		var p := l.find(".set_anchors_preset(")
		if p > 0:
			anchored[l.substr(0, p)] = true
		var s := l.find(".size = ")
		if s > 0 and anchored.has(l.substr(0, s)):
			out.append("%s:%d %s" % [path, i + 1, l.substr(0, s)])
	return out


func test_anchored_controls_are_not_sized() -> void:
	var paths: Array[String] = []
	_scripts(SRC, paths)
	for p in paths:
		for hit in anchored_and_sized(p, FileAccess.get_file_as_string(p)):
			failures.append("anchor preset + .size on the same control: " + hit)


func test_detector_finds_the_lobby_bug() -> void:
	var bad := "func f() -> void:\n\tvar c := CenterContainer.new()\n\tc.set_anchors_preset(Control.PRESET_FULL_RECT)\n\tc.size = root.size\n"
	if anchored_and_sized("x.gd", bad).size() != 1:
		failures.append("detector missed anchor preset + size")
	var ok := "func f() -> void:\n\tvar c := Control.new()\n\tc.size = Vector2(4, 4)\n"
	if not anchored_and_sized("x.gd", ok).is_empty():
		failures.append("detector flagged a plain sized control")
