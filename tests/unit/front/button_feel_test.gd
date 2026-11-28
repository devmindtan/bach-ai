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
