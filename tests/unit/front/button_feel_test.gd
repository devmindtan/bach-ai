extends RefCounted
## ButtonFeel (web screen-feel-journal): every button is hooked once, and its sounds exist.

var failures: Array[String] = []


func test_attach_once() -> void:
	var b := Button.new()
	var n := Node.new()
	ButtonFeel.attach(b, n)
	var c := b.focus_entered.get_connections().size()
	ButtonFeel.attach(b, n)
	if b.focus_entered.get_connections().size() != c:
		failures.append("attach hooked a button twice")
	b.free()
	n.free()


func test_feel_sounds_exist() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio.json"))
	for id in ["ui_tick", "ui_deny", "ui_click"]:
		if not cfg.get("sfx", {}).has(id):
			failures.append("audio.json lacks %s" % id)
		if not ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % id):
			failures.append("no %s.wav" % id)


func test_wide_rows_lift_a_few_pixels() -> void:
	var b := Button.new()
	b.size = Vector2(470, 80)
	var grow := (ButtonFeel.lift_of(b).x - 1.0) * b.size.x * 0.5
	if grow > ButtonFeel.LIFT_PX + 0.01:
		failures.append("a wide row grows %.1f px a side" % grow)
	b.size = Vector2(40, 40)
	if not is_equal_approx(ButtonFeel.lift_of(b).x, ButtonFeel.LIFT):
		failures.append("a small button lost its lift")
	b.free()


func test_only_a_loaded_scene_restarts_the_rise() -> void:
	var root := Node.new()
	var tip := CanvasLayer.new()
	root.add_child(tip)
	if ButtonFeel.is_screen(tip, root):
		failures.append("a tip layer counts as a new screen")
	var scene := Node2D.new()
	scene.scene_file_path = "res://src/front/stage_select.tscn"
	root.add_child(scene)
	if not ButtonFeel.is_screen(scene, root):
		failures.append("a loaded scene does not count as a new screen")
	root.free()
