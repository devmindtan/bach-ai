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
const ORIGIN := Vector2(195, 236)   # the nodes fill the journal's left page (design-web screen-cardtree-journal)
const STEP := Vector2(150, 110)
const NODE := 64.0
const KEY := 78.0
const RIGHT_PAGE := Rect2(660, 74, 470, 572)

var _slot: Slot
var _trees: CardTree
var _card := ""
var _card_def := {}
var _view := ""
var _reset_armed := false
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


func _save() -> void:
	if not Prefs.current().is_fixed():
		Prefs.current().slot_store().save(_slot)


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_build()


func _center(n: Dictionary) -> Vector2:
	return ORIGIN + Vector2(float(n.get("col", 0)) * STEP.x, float(n.get("row", 0)) * STEP.y)


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var title := Journal.ink("Cây thẻ", 44)
	title.position = Vector2(110, 66)
	root.add_child(title)
	var head := HBoxContainer.new()   # the card's icon and name, as the left page's subtitle
	head.add_theme_constant_override("separation", 8)
	head.position = Vector2(112, 120)
	root.add_child(head)
	head.add_child(UiKit.card_icon(_card, 32.0))
	var nm := Journal.ink(String(_card_def.get("name", _card)), 22, Journal.INK_RED)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(nm)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	bar.position = Vector2(112, 160)
	root.add_child(bar)
	bar.add_child(_shard_stat("%d Mảnh thẻ" % _slot.shards, "Mảnh thẻ: thắng ải, hạ boss, mở rương, gacha trùng.", 18))
	var mp := int(_trees.tree(_card).get("max_points", 0))
	bar.add_child(UiKit.label("· điểm đã dùng %d / %d" % [_trees.points(_slot, _card), mp], 18, UiKit.MUTED))
	Journal.restyle(bar)
	var hint := Journal.ink("←↑↓→ chọn nút · Enter nâng · Esc về Bộ thẻ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	# edges under the nodes
	var edges := Control.new()
	edges.size = root.size
	edges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(edges)
	edges.draw.connect(func() -> void:
		for n: Dictionary in _trees.tree(_card).get("nodes", []):
			for req: String in n.get("requires", []):
				var lit := _trees.rank(_slot, _card, req) > 0
				edges.draw_line(_center(_trees.node(_card, req)), _center(n),
					Journal.INK_RED if lit else Journal.DOTS, 4.0 if lit else 2.0))
	for n: Dictionary in _trees.tree(_card).get("nodes", []):
		root.add_child(_node_button(n))
	_detail(root)


func _node_button(n: Dictionary) -> Control:
	var id := String(n["id"])
	var r := _trees.rank(_slot, _card, id)
	var mx := int(n.get("max_rank", 1))
	var learnable := _trees.why_not(_slot, _card, id) == ""
	var key := bool(n.get("keystone", false))
	var side := KEY if key else NODE
	var holder := Control.new()
	holder.position = _center(n) - Vector2(side, side) / 2.0
	holder.size = Vector2(side, side + 22)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := Button.new()
	b.custom_minimum_size = Vector2(side, side)
	b.size = Vector2(side, side)
	b.focus_mode = Control.FOCUS_ALL
	# sketch squares like the skill tree: learned rose, maxed red ink, open paper, closed faded; viewed ink + gold
	var on := id == _view
	var bg := Journal.INK if on else (Journal.INK_RED if r >= mx else (Color("c88a7a") if r > 0 else (Journal.SKETCH if learnable else Color(Journal.SKETCH, 0.5))))
	var border := Journal.INK if (r > 0 or learnable) else Journal.DOTS
	for s in ["normal", "hover", "focus", "pressed"]:
		var lit: bool = on or s != "normal"
		var st := StyleBoxFlat.new()
		st.bg_color = bg
		st.border_color = Journal.GOLD if lit else border
		st.set_border_width_all(4 if lit or key else 3)
		b.add_theme_stylebox_override(s, st)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	holder.add_child(b)
	var ic := UiKit.card_icon(_card, side * 0.55)
	ic.position = (Vector2(side, side) - ic.custom_minimum_size) / 2.0
	ic.modulate = Color.WHITE if (r > 0 or on) else Color(0.6, 0.5, 0.42, 0.8 if learnable else 0.45)
	b.add_child(ic)
	var g := UiKit.icon(String(n.get("glyph", "damage")), 24.0)
	g.position = Vector2(side - 26, side - 26)
	b.add_child(g)
	var lv := Journal.ink("%d/%d" % [r, mx], 16, Journal.INK_RED if r >= mx else (Journal.INK if r > 0 else Journal.INK_SOFT))
	var tag := StyleBoxFlat.new()   # the edge passes under it
	tag.bg_color = Journal.PAPER
	tag.border_color = Journal.INK
	tag.set_border_width_all(2)
	lv.add_theme_stylebox_override("normal", tag)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.custom_minimum_size.x = 34
	lv.position = Vector2(side / 2.0 - 17, side + 2)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lv)
	b.pressed.connect(func() -> void:
		_view = id
		_reset_armed = false
		_rebuild())
	if id == _view:
		b.call_deferred("grab_focus")
	return holder


func _detail(root: Control) -> void:
	var w := RIGHT_PAGE.size.x + 40
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.position = RIGHT_PAGE.position
	panel.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var n := _trees.node(_card, _view)
	var r := _trees.rank(_slot, _card, _view)
	var mx := int(n.get("max_rank", 1))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(UiKit.card_icon(_card, 48.0))
	head.add_child(UiKit.icon(String(n.get("glyph", "damage")), 24.0))
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(Journal.ink(String(n.get("name", _view)), 32, Journal.INK_RED if r > 0 else Journal.INK))
	hv.add_child(UiKit.label(("Then chốt · " if bool(n.get("keystone", false)) else "") + "Cấp %d / %d" % [r, mx], 14, UiKit.MUTED))
	var d := UiKit.label(String(n.get("desc", "")), 16, UiKit.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = w - 40
	v.add_child(d)
	var reqs := []
	for q: String in n.get("requires", []):
		reqs.append(String(_trees.node(_card, q).get("name", q)))
	if not reqs.is_empty() or int(n.get("requires_points", 0)) > 0:
		var cond := "Cần: " + ", ".join(reqs)
		if int(n.get("requires_points", 0)) > 0:
			cond += ("; " if not reqs.is_empty() else "") + "đã dùng %d điểm" % int(n["requires_points"])
		var cl := UiKit.label(cond, 14, UiKit.MUTED)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cl)
	var why := _trees.why_not(_slot, _card, _view)
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 6)
	v.add_child(cost_row)
	if r < mx:
		cost_row.add_child(UiKit.label("Giá:", 16, UiKit.TEXT))
		cost_row.add_child(UiKit.icon("shard", 24.0))
		cost_row.add_child(UiKit.label(str(_trees.cost(_slot, _card)), 16, UiKit.TEXT if _slot.shards >= _trees.cost(_slot, _card) else Color("ff8a8a")))
	var learn := Journal.seal("Nâng ▶", Vector2(w - 40, 58), 24)
	learn.pressed.connect(func() -> void:
		if _trees.buy(_slot, _card, _view):
			Sfx.play("buy")
			_save()
		_rebuild())
	learn.disabled = why != ""
	v.add_child(learn)
	if why != "":
		var wl := UiKit.label(why, 14, Color("ff9a8a"))
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(wl)
	v.add_child(HSeparator.new())
	var refund := _trees.spent(_slot, _card)
	v.add_child(UiKit.label("Đặt lại thẻ: hoàn %d Mảnh thẻ" % refund, 15, UiKit.MUTED))
	var reset := UiKit.button("Bấm lần nữa để đặt lại" if _reset_armed else "Đặt lại thẻ", func() -> void:
		if _reset_armed:
			_trees.reset(_slot, _card)
			_save()
			_reset_armed = false
		else:
			_reset_armed = true
		_rebuild(), Vector2(w - 40, 40), 16, UiKit.DANGER if _reset_armed else UiKit.PANEL)
	reset.disabled = refund <= 0
	v.add_child(reset)
	Journal.restyle(panel)


## Mảnh thẻ in the wallet: the 12 px glyph drawn x2 (UiKit.stat would draw it at x1, too small).
func _shard_stat(text: String, tip: String, font := 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	Tip.attach(row, tip)
	row.add_child(UiKit.icon("shard", 24.0))
	var l := UiKit.label(text, font, UiKit.TEXT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row
