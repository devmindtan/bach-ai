extends RefCounted
## Every menu screen has a UX spec built on references from similar games (user
## 2026-11-17: "đừng đoán mò, tham khảo các tựa game tương tự"). Screens in
## production/ui/screens.json of the front end (main scene, src/front/) and the
## lobby (src/lobby/) must name a "spec" in design/ux/ that has a "Tham khảo"
## section with at least one link.

const SCREENS := "res://production/ui/screens.json"

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _needs_spec(s: Dictionary) -> bool:
	var scene := String(s.get("scene", ""))
	return scene == "" or scene.begins_with("res://src/front/") or scene.begins_with("res://src/lobby/")


func test_menu_screens_have_a_referenced_ux_spec() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCREENS))
	_check(data is Dictionary, "screens.json readable")
	if not data is Dictionary:
		return
	for s: Dictionary in data.get("screens", []):
		var name := String(s.get("name", "?"))
		if not s.has("spec"):
			_check(not _needs_spec(s), "%s: a menu screen needs \"spec\" (design/ux/<screen>.md)" % name)
			continue
		var path := "res://" + String(s["spec"])
		_check(FileAccess.file_exists(path), "%s: spec %s exists" % [name, s["spec"]])
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		var at := text.find("## Tham khảo")
		_check(at >= 0, "%s: %s has a \"## Tham khảo\" section" % [name, s["spec"]])
		if at >= 0:
			var section := text.substr(at, maxi(0, text.find("\n## ", at + 5) - at) if text.find("\n## ", at + 5) > 0 else -1)
			_check(section.contains("http"), "%s: the references in %s link to their sources" % [name, s["spec"]])
