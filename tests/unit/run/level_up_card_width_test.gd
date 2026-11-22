extends RefCounted
## Regression (2026-11-22 screenshot): the stat column of a level-up card was a RichTextLabel with
## autowrap off. Such a label reports no content width, so "79 → 90" and "Cấp 3 → 4" ran past the
## card's right edge. Every text in a card must report its width (Label), and the level goes on its own line.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _walk(n: Node, out: Array) -> void:
	for c in n.get_children():
		out.append(c)
		_walk(c, out)


func test_card_texts_report_width_level_on_own_line() -> void:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_mage.json")
	r.base_stats = classes["mage"]["stats"]
	r.levels = {"storm": 3}
	r._recompute_stats()
	var p := RunPanels.new()
	p.run = r
	var b: Control = p._upgrade_card(0, "storm")
	var all: Array = []
	_walk(b, all)
	for c in all:
		if c is RichTextLabel and (c as RichTextLabel).autowrap_mode == TextServer.AUTOWRAP_OFF:
			failures.append("unwrapped RichTextLabel '%s' reports no width" % (c as RichTextLabel).text)
		if c is Label and String((c as Label).text).contains("Huyền thoại") and String((c as Label).text).contains("Cấp"):
			failures.append("type · tier · level crowd one line: '%s'" % (c as Label).text)
	b.free()
	p.free()
	r.free()
