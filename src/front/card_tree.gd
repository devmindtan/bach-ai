extends Node2D
## The card-tree screen (design/ux/card-tree.md, rules in design/skill-tree-v2.md §3, §5): the nodes of
## one skill card on a grid joined by edges (lit once the parent is learned); each node a round button
## with the card's icon and its change glyph in the corner, rank "r/max" below; learned nodes bright and
## gold, unlearned dark (Diablo IV contrast note); keystones bigger. The viewed node on the right: name,
## rank, text, why it cannot be learned yet, the Mảnh thẻ cost and "Học"; "Đặt lại thẻ" refunds all.
## Esc goes back to the deck screen.
##
## Command line (after `--`), for shots: --card=<id>, --node-view=<node id>.

const DECK_SCENE := "res://src/front/deck.tscn"
const RIGHT_PAGE := Rect2(660, 74, 470, 572)

var _slot: Slot
var _trees: CardTree
var _card := ""
var _card_def := {}
var _view := ""
var _reset_armed := false   # Đặt lại thẻ asks once more
var _layer: CanvasLayer


func _ready() -> void:
	Sfx.music("menu")
	var prefs := Prefs.current()
	if prefs.is_fixed():
		prefs.ensure_preview_slot()
	elif prefs.active_slot == null:
		prefs.ensure_slots()
	_slot = prefs.active_slot
	_trees = CardTree.load_default()
	_card = prefs.card_target
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--card="):
			_card = a.get_slice("=", 1)
		elif a.begins_with("--node-view="):
			_view = a.get_slice("=", 1)
	if _slot == null or _trees.tree(_card).is_empty():
		get_tree().change_scene_to_file.call_deferred(DECK_SCENE)
		return
	var cls: Dictionary = GameData.load_json("res://assets/data/classes.json").get(_slot.cls, {})
	for u: Dictionary in GameData.load_json("res://assets/data/" + String(cls.get("upgrades", ""))).get("upgrades", []):
		if String(u.get("id", "")) == _card:
			_card_def = u
	if _view == "":
		_view = String(_trees.tree(_card)["nodes"][0]["id"])
	_build()


func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, Journal.BOOK)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(DECK_SCENE)
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_R:
		_reset()


func _save() -> void:
	if not Prefs.current().is_fixed():
		Prefs.current().slot_store().save(_slot)


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_build()


var _cards_list: Array = []   # the class's skill cards with a tree: [{id, name}]


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	Journal.back_tab(root, func() -> void: get_tree().change_scene_to_file(DECK_SCENE))   # "Trở lại" (web .back-tab)
	var hint := Journal.ink("↑ ↓ chọn thẻ · ← → chọn nút · Enter nâng · Esc về Bộ thẻ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	if _cards_list.is_empty():
		var cls: Dictionary = GameData.load_json("res://assets/data/classes.json").get(_slot.cls, {})
		for u: Dictionary in GameData.load_json("res://assets/data/" + String(cls.get("upgrades", ""))).get("upgrades", []):
			if not _trees.tree(String(u.get("id", ""))).is_empty():
				_cards_list.append({"id": String(u["id"]), "name": String(u.get("name", u["id"]))})
	# left page (web screen-cardtree-journal): the title, its line, one row per card with a tree
	var left := VBoxContainer.new()
	left.position = Vector2(110, 66)
	left.custom_minimum_size = Vector2(470, 0)
	left.add_theme_constant_override("separation", 0)
	root.add_child(left)
	left.add_child(Journal.ink("Cây thẻ", 44))
	left.add_child(Journal.ink("Nâng từng thẻ chiêu bằng Mảnh thẻ", 20, Journal.INK_RED))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	left.add_child(gap)
	for c: Dictionary in _cards_list:
		left.add_child(_card_row(c))
	# right page: the card, points and shards, its nodes as named boxes joined by ink, the node's text and cost
	var t := _trees.tree(_card)
	var v := VBoxContainer.new()
	v.position = RIGHT_PAGE.position + Vector2(0, -8)
	v.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	v.add_theme_constant_override("separation", 2)
	root.add_child(v)
	var h2 := Journal.ink(String(_card_def.get("name", _card)), 32)
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Journal.INK
	under.border_width_bottom = 3
	h2.add_theme_stylebox_override("normal", under)
	v.add_child(h2)
	v.add_child(Journal.ink("Điểm đã dùng %d/%d · Mảnh thẻ %d" % [_trees.points(_slot, _card), int(t.get("max_points", 0)), _slot.shards], 20, Journal.INK_RED))
	var area := Control.new()
	area.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 318)   # rows 0..3 (86 px each) + the reset line above the seal
	v.add_child(area)
	var nodes: Array = t.get("nodes", [])
	var at := func(n: Dictionary) -> Vector2: return Vector2(10 + int(n.get("col", 0)) * 160, 4 + int(n.get("row", 0)) * 86)
	area.draw.connect(func() -> void:
		for n: Dictionary in nodes:
			for q: String in n.get("requires", []):
				var p: Vector2 = at.call(_trees.node(_card, q))
				var c: Vector2 = at.call(n)
				area.draw_line(p + Vector2(60, 58), c + Vector2(60, 0), Journal.INK, 3.0))
	for n: Dictionary in nodes:
		var b := _node_box(n)
		b.position = at.call(n)
		area.add_child(b)
	var n := _trees.node(_card, _view)
	var r := _trees.rank(_slot, _card, _view)
	var d := Journal.ink(String(n.get("desc", "")), 22)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	v.add_child(d)
	var mx := int(n.get("max_rank", 1))
	v.add_child(Journal.ledger("", "Giá cấp kế", ("%d Mảnh thẻ" % _trees.cost(_slot, _card)) if r < mx else "Đã tối đa", 20))
	var refund := _trees.spent(_slot, _card)   # web proposal approved 2026-11-26: Đặt lại thẻ (R), pressed twice
	var rs := Journal.link(("Chắc chắn đặt lại? Bấm lần nữa (R)" if _reset_armed else "Đặt lại thẻ ▸ (R) · hoàn %d Mảnh thẻ" % refund), 18)
	rs.disabled = refund <= 0
	rs.pressed.connect(_reset)
	v.add_child(rs)
	var why := _trees.why_not(_slot, _card, _view)
	var up := Journal.seal("Nâng ▶", Vector2(200, 60), 26)
	up.position = RIGHT_PAGE.end - Vector2(200, 60)
	up.focus_mode = Control.FOCUS_NONE
	up.disabled = why != ""
	up.tooltip_text = why
	up.pressed.connect(_learn)
	root.add_child(up)


func _reset() -> void:
	if _trees.spent(_slot, _card) <= 0:
		return
	if not _reset_armed:
		_reset_armed = true
		_rebuild()
		return
	_reset_armed = false
	_trees.reset(_slot, _card)
	_save()
	_rebuild()


func _learn() -> void:
	if _trees.buy(_slot, _card, _view):
		Sfx.play("buy")
		_save()
		_rebuild()


## A card row on the left page: its icon and name; the open card is ink. Focus / a click opens its tree.
func _card_row(c: Dictionary) -> Button:
	var on := String(c["id"]) == _card
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(470, 44)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Journal.INK if on else Color(0, 0, 0, 0)
	flat.border_color = Journal.DOTS
	flat.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", flat)
	var lit := flat.duplicate() as StyleBoxFlat
	lit.bg_color = Journal.INK
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, lit)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := UiKit.card_icon(String(c["id"]), 36.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := Journal.ink(String(c["name"]), 24, Journal.PAPER if on else Journal.INK)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	b.focus_entered.connect(func() -> void:
		l.add_theme_color_override("font_color", Journal.PAPER)
		_open_card(String(c["id"])))
	b.focus_exited.connect(func() -> void: l.add_theme_color_override("font_color", Journal.PAPER if String(c["id"]) == _card else Journal.INK))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	if on:
		b.call_deferred("grab_focus")
	return b


func _open_card(id: String) -> void:
	if id == _card:
		return
	_card = id
	Prefs.current().card_target = id
	for c: Dictionary in _cards_list:
		if String(c["id"]) == id:
			_card_def = {"id": id, "name": c["name"]}
	_view = String(_trees.tree(_card)["nodes"][0]["id"])
	_rebuild()


## A node as a named sketch box (web .cn): learned rose, the viewed one ink; "rank/max" under the name.
func _node_box(n: Dictionary) -> Button:
	var id := String(n["id"])
	var r := _trees.rank(_slot, _card, id)
	var on := id == _view
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE   # ← → move between nodes (the rows own the focus)
	b.custom_minimum_size = Vector2(120, 58)
	b.size = b.custom_minimum_size
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Journal.INK if on else (Color("c88a7a") if r > 0 else Journal.SKETCH)
		sb.border_color = Journal.GOLD if on else Journal.INK
		sb.set_border_width_all(4 if on else 3)
		b.add_theme_stylebox_override(st, sb)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	for t in [[String(n.get("name", id)), 17], ["%d/%d" % [r, int(n.get("max_rank", 1))], 14]]:
		var l := Journal.ink(t[0], t[1], Journal.PAPER if on else Journal.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	b.pressed.connect(func() -> void:
		if on:
			_learn()
		else:
			_view = id
			_rebuild())
	return b


## ← → walk the open card's nodes in order; Enter learns the viewed one.
func _input(event: InputEvent) -> void:
	var nodes: Array = _trees.tree(_card).get("nodes", []) if _trees != null else []
	if nodes.is_empty():
		return
	var ids := nodes.map(func(n: Dictionary) -> String: return String(n["id"]))
	var i := ids.find(_view)
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		_view = ids[posmod(i + (1 if event.is_action_pressed("ui_right") else -1), ids.size())]
		get_viewport().set_input_as_handled()
		_rebuild()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_learn()
