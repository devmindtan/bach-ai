extends RefCounted
## Regression (2026-11-20 screenshot): with the rarity frame the level-up cards got corner ornaments as
## their first children, _fit_cards read child 0 (a ColorRect) and the card stayed 180 px tall while its
## text ran out over the action buttons. Every card must be as tall as its content box.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_rarity_framed_cards_grow_to_their_content() -> void:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_knight.json")
	r.base_stats = classes["knight"]["stats"]
	r.levels = {"blade_arc": 1}
	r._recompute_stats()
	var p := RunPanels.new()
	p.run = r
	var row := HBoxContainer.new()
	for k in 2:
		row.add_child(p._upgrade_card(k, ["earthquake", "whirlwind"][k]))
	# the test runner has no scene tree (labels measure 0), so give each content box a known height
	for b: Control in row.get_children():
		for v in b.get_children():
			if v is VBoxContainer:
				(v as Control).custom_minimum_size.y = 400.0
	p._fit_cards(row)
	for b: Control in row.get_children():
		var content := 0.0
		for v in b.get_children():
			if v is VBoxContainer:
				content = (v as Control).custom_minimum_size.y
		_check(content > 0.0, "card has a content box")
		_check(b.custom_minimum_size.y >= content + 24.0, "card %.0f px tall holds content %.0f px" % [b.custom_minimum_size.y, content])
	row.free()
	p.free()
	r.free()
