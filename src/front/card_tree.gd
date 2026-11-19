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
const ORIGIN := Vector2(90, 190)
const STEP := Vector2(170, 128)
const NODE := 76.0
const KEY := 92.0

var _slot: Slot
var _trees: CardTree
var _card := ""
var _card_def := {}
var _view := ""
var _reset_armed := false
var _scroll := Vector2.ZERO
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


func _process(delta: float) -> void:
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	FrontArt.backdrop(self, _scroll, get_viewport_rect().size)


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
	var title := UiKit.label("Cây thẻ · %s" % String(_card_def.get("name", _card)), 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 22)
	bar.position = Vector2(42, 72)
	root.add_child(bar)
	bar.add_child(_shard_stat("%d Mảnh thẻ" % _slot.shards, "Mảnh thẻ: thắng ải, hạ boss, mở rương, gacha trùng.", 16))
	var mp := int(_trees.tree(_card).get("max_points", 0))
	bar.add_child(UiKit.label("Điểm đã dùng %d / %d" % [_trees.points(_slot, _card), mp], 16, UiKit.TEXT))
	var back := UiKit.button("Quay lại  (Esc)", func() -> void: get_tree().change_scene_to_file(DECK_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)
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
					UiKit.GOLD if lit else Color("3a3448"), 5.0 if lit else 3.0))
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
	var bg := Color("3a3020") if r >= mx else (Color("2c2838") if r > 0 else Color("16131e"))
	var border := UiKit.GOLD if r >= mx else (Color("c8d0e0") if r > 0 else (Color(UiKit.GOLD, 0.55) if learnable else Color("3a3448")))
	if id == _view:
		border = Color.WHITE
	var st := UiKit.style(bg, 4, border, 5 if key else 3)
	st.set_corner_radius_all(int(side / 2.0))
	b.add_theme_stylebox_override("normal", st)
	var hov := UiKit.style(UiKit.PANEL_HOVER, 4, Color.WHITE, 5 if key else 3)
	hov.set_corner_radius_all(int(side / 2.0))
	for s in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(s, hov)
	holder.add_child(b)
	var ic := UiKit.icon(_card, side * 0.55)
	ic.position = (Vector2(side, side) - ic.custom_minimum_size) / 2.0
	ic.modulate = Color.WHITE if r > 0 else Color(0.45, 0.45, 0.5)
	b.add_child(ic)
	var g := UiKit.icon(String(n.get("glyph", "damage")), 24.0)
	g.position = Vector2(side - 26, side - 26)
	b.add_child(g)
	var lv := UiKit.label("%d/%d" % [r, mx], 14, UiKit.GOLD if r >= mx else (UiKit.TEXT if r > 0 else UiKit.MUTED))
	lv.add_theme_stylebox_override("normal", UiKit.style(Color("100e16"), 3, Color(0, 0, 0, 0), 0))   # the edge passes under it
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
	var x := ORIGIN.x + 2 * STEP.x + KEY + 40
	var w := root.size.x - 40 - x
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	panel.position = Vector2(x, 120)
	panel.custom_minimum_size = Vector2(w, 0)
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
	head.add_child(UiKit.icon(_card, 48.0))
	head.add_child(UiKit.icon(String(n.get("glyph", "damage")), 24.0))
	var hv := VBoxContainer.new()
	head.add_child(hv)
	hv.add_child(UiKit.label(String(n.get("name", _view)), 24, UiKit.GOLD if r > 0 else UiKit.TEXT))
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
	var learn := UiKit.button("Học", func() -> void:
		if _trees.buy(_slot, _card, _view):
			Sfx.play("buy")
			_save()
		_rebuild(), Vector2(w - 40, 46), 20, UiKit.PRIMARY)
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
