extends Node2D
## The deck screen (design/ux/deck.md, rules in design/skill-tree-v2.md §2): three deck tabs; the
## class's cards in a grid (skills, then stats), cards in the deck framed gold with a tick, the starting
## skill locked; the viewed card on the right with add / remove and, for a skill card with a tree, its
## points and the "Cây thẻ" button; the deck counts and "Bộ mặc định" below. Changes save at once.
##
## Command line (after `--`), for shots: --deck-view=<card id>.

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const TREE_SCENE := "res://src/front/card_tree.tscn"
const TILE := Vector2(104, 104)

var _slot: Slot
var _ups: Array = []
var _start: Array = []
var _cfg := {}
var _trees: CardTree
var _view := ""
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
	if _slot == null:
		get_tree().change_scene_to_file.call_deferred("res://src/front/characters.tscn")
		return
	var cls: Dictionary = GameData.load_json("res://assets/data/classes.json").get(_slot.cls, {})
	_ups = GameData.load_json("res://assets/data/" + String(cls.get("upgrades", ""))).get("upgrades", [])
	_start = cls.get("start_skills", {}).keys()
	_trees = CardTree.load_default()
	_cfg = _trees.data.get("deck", {"skills": 8, "stats": 6, "slots": 3})
	_ensure_decks()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--deck-view="):
			_view = a.get_slice("=", 1)
	if _view == "":
		_view = String(_start[0]) if not _start.is_empty() else ""
	_build()


## The slot always has cfg.slots decks; an empty one starts as the default deck.
func _ensure_decks() -> void:
	while _slot.decks.size() < int(_cfg.get("slots", 3)):
		_slot.decks.append({"name": "Bộ %d" % (_slot.decks.size() + 1), "cards": Deck.default_cards(_ups, _start, _cfg)})
	_slot.deck_active = clampi(_slot.deck_active, 0, _slot.decks.size() - 1)


func _cards() -> Array:
	return _slot.decks[_slot.deck_active].get("cards", [])


func _set_cards(cards: Array) -> void:
	_slot.decks[_slot.deck_active]["cards"] = cards
	_save()


func _process(delta: float) -> void:
	_scroll += Vector2(18.0, 6.0) * delta
	queue_redraw()


func _draw() -> void:
	FrontArt.backdrop(self, _scroll, get_viewport_rect().size)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _save() -> void:
	if not Prefs.current().is_fixed():
		Prefs.current().slot_store().save(_slot)


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_build()


func _card(id: String) -> Dictionary:
	for u: Dictionary in _ups:
		if String(u.get("id", "")) == id:
			return u
	return {}


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var title := UiKit.label("Bộ thẻ · %s" % _slot.name, 34, UiKit.GOLD)
	title.position = Vector2(40, 24)
	root.add_child(title)
	var wallet := _shard_stat("%d Mảnh thẻ" % _slot.shards, "Mảnh thẻ: thắng ải, hạ boss, mở rương, gacha trùng; mở nút cây thẻ.", 16)
	wallet.position = Vector2(42, 72)
	root.add_child(wallet)
	var back := UiKit.button("Quay lại  (Esc)", func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE), Vector2(180, 42), 17)
	back.position = Vector2(root.size.x - 40 - 180, 28)
	root.add_child(back)
	# deck tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.position = Vector2(40, 108)
	root.add_child(tabs)
	for i in _slot.decks.size():
		var on := i == _slot.deck_active
		var t := UiKit.button(String(_slot.decks[i].get("name", "Bộ %d" % (i + 1))), func() -> void:
			_slot.deck_active = i
			_save()
			_rebuild(), Vector2(120, 38), 17)
		if on:
			t.add_theme_stylebox_override("normal", UiKit.style(Color("3a3020"), 8, UiKit.GOLD, 3))
		tabs.add_child(t)
	# collection grid: skills, then stats
	var y := 160.0
	for kind in ["skill", "stat"]:
		var head := UiKit.label("Chiêu" if kind == "skill" else "Chỉ số", 20, UiKit.GOLD)
		head.position = Vector2(40, y)
		root.add_child(head)
		y += 30.0
		var grid := GridContainer.new()
		var cols := 7
		var x0 := 40.0
		if kind == "skill" and not _start.is_empty():
			# the starting skill: one big 2x2 tile of its own, always in the deck (user 2026-11-20)
			var big := _start_tile(_card(String(_start[0])))
			big.position = Vector2(40, y)
			root.add_child(big)
			cols = 5
			x0 += 2 * (TILE.x + 8)
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.position = Vector2(x0, y)
		root.add_child(grid)
		var n := 0
		for u: Dictionary in _ups:
			if String(u.get("kind", "")) == kind and Deck.is_deck_card(u) and not (kind == "skill" and _start.has(String(u["id"]))):
				grid.add_child(_tile(u))
				n += 1
		var rows := ceilf(n / float(cols))
		if cols == 5:
			rows = maxf(rows, 2.0)
		y += rows * (TILE.y + 8) + 12
	_detail(root)


## The starting skill's big tile: gold frame, a large icon, "Chiêu khởi đầu", a lock line; it is always in
## the deck and cannot be taken out, so pressing it only shows its detail.
func _start_tile(u: Dictionary) -> Button:
	var id := String(u.get("id", ""))
	var on := id == _view
	var b := Button.new()
	b.custom_minimum_size = TILE * 2 + Vector2(8, 8)
	b.size = b.custom_minimum_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", UiKit.style(Color("4a3a1c"), 8, Color.WHITE if on else UiKit.GOLD, 4))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.style(Color("5a4824"), 8, Color.WHITE, 4))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.offset_top = 10
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tag := UiKit.label("CHIÊU KHỞI ĐẦU", 13, UiKit.GOLD)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var ic := UiKit.icon(id, 96.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var nm := UiKit.label(String(u.get("name", id)), 20, UiKit.TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var lock := UiKit.label("Luôn trong bộ · 0 điểm", 12, UiKit.MUTED)
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lock)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Tip.attach(b, String(u.get("name", id)), String(u.get("desc", "")), UiKit.GOLD, id, "Chiêu khởi đầu · luôn trong bộ")
	b.pressed.connect(func() -> void:
		_view = id
		_rebuild())
	if on:
		b.call_deferred("grab_focus")
	return b


func _tile(u: Dictionary) -> Button:
	var id := String(u["id"])
	var in_deck := _cards().has(id)
	var on := id == _view
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_ALL
	var tier := String(u.get("rarity", "common"))   # design/card-rarity.md "Khung theo bậc": the frame is the tier
	b.add_theme_stylebox_override("normal", UiKit.rarity_style(tier, in_deck, on))
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, UiKit.rarity_style(tier, true, true))
	UiKit.rarity_corners(b, tier)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.offset_top = 8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := UiKit.icon(id, 48.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color.WHITE if in_deck else Color(0.5, 0.5, 0.55)
	v.add_child(ic)
	var nm := UiKit.label(String(u.get("name", id)), 13, UiKit.TEXT if in_deck else UiKit.MUTED)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size.x = TILE.x - 8
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var pts := Deck.cost(u, _cfg)   # no gem on the small tile (user 2026-11-20): the frame is the tier, the
	if pts > 0:                     # detail shows the gem; only the deck cost stays, top left
		var pl := UiKit.label("%d" % pts, 13, UiKit.RARITY.get(tier, UiKit.TEXT))
		pl.position = Vector2(8, 2)
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pl)
	Tip.attach(b, String(u.get("name", id)), String(u.get("desc", "")), UiKit.RARITY.get(tier, UiKit.TEXT), id,
		"%s · %d điểm bộ thẻ" % [UiKit.RARITY_NAME.get(tier, tier), pts])
	if in_deck:   # the tick, or a lock on the starting skill
		var badge := PanelContainer.new()   # a gold round badge: "in this deck" at a glance
		var bs := UiKit.style(UiKit.GOLD, 0, Color("1b1726"), 2)
		bs.set_corner_radius_all(11)
		badge.add_theme_stylebox_override("panel", bs)
		badge.custom_minimum_size = Vector2(22, 22)
		badge.position = Vector2(TILE.x - 26, 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := UiKit.label("✓", 14, Color("1b1726"))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(mark)
		b.add_child(badge)
	b.pressed.connect(func() -> void:
		_view = id
		_rebuild())
	if on:
		b.call_deferred("grab_focus")
	return b


func _detail(root: Control) -> void:
	var x := 40 + 7 * (TILE.x + 8) + 24
	var w := root.size.x - 40 - x
	var panel := UiKit.panel(Color(0.09, 0.08, 0.13, 0.94), 16)
	panel.position = Vector2(x, 160)
	panel.custom_minimum_size = Vector2(w, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var u := _card(_view)
	if not u.is_empty():
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		v.add_child(head)
		head.add_child(UiKit.icon(_view, 48.0))
		var hv := VBoxContainer.new()
		head.add_child(hv)
		hv.add_child(UiKit.label(String(u.get("name", _view)), 24, UiKit.GOLD))
		var tr := String(u.get("rarity", "common"))
		var sub := HBoxContainer.new()   # the tier's gem + name, then type and deck cost
		sub.add_theme_constant_override("separation", 8)
		sub.add_child(UiKit.rarity_badge(tr, 14))
		sub.add_child(UiKit.label("·  %s  ·  %d điểm bộ thẻ" % ["Chiêu" if String(u["kind"]) == "skill" else "Thẻ chỉ số",
			Deck.cost(u, _cfg)], 14, UiKit.MUTED))
		hv.add_child(sub)
		var d := UiKit.label(String(u.get("desc", "")), 15, UiKit.TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = w - 40
		v.add_child(d)
		var in_deck := _cards().has(_view)
		if _start.has(_view):   # the starting skill: a gold note, not a dead button with a red reason
			var sl := UiKit.label("★ Chiêu khởi đầu: luôn trong bộ, không tốn điểm", 15, UiKit.GOLD)
			sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(sl)
		var why := Deck.why_not_remove(_cards(), _view, _start) if in_deck else Deck.why_not_add(_cards(), _ups, _view, _cfg)
		var act := UiKit.button("Bỏ khỏi bộ" if in_deck else "Thêm vào bộ", func() -> void:
			_set_cards(Deck.remove(_cards(), _view, _start) if in_deck else _cards() + [_view])
			_rebuild(), Vector2(w - 40, 44), 18, UiKit.PRIMARY)
		act.disabled = why != ""
		if not _start.has(_view):
			v.add_child(act)
		if why != "" and not _start.has(_view):
			var wl := UiKit.label(why, 14, Color("ff9a8a"))
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(wl)
		if not _trees.tree(_view).is_empty():
			v.add_child(UiKit.label("Cây thẻ: %d / %d điểm" % [_trees.points(_slot, _view), int(_trees.tree(_view).get("max_points", 0))], 16, UiKit.TEXT))
			var card := _view
			v.add_child(UiKit.button("Cây thẻ  ▶", func() -> void:
				Prefs.current().card_target = card
				get_tree().change_scene_to_file(TREE_SCENE), Vector2(w - 40, 44), 18))
		elif String(u["kind"]) == "skill":
			v.add_child(UiKit.label("Cây thẻ: sắp có", 14, UiKit.MUTED))
	var sep := HSeparator.new()
	v.add_child(sep)
	v.add_child(UiKit.label("Chiêu %d/%d  ·  Chỉ số %d/%d" % [Deck.count(_cards(), _ups, "skill"), int(_cfg.get("skills", 8)),
		Deck.count(_cards(), _ups, "stat"), int(_cfg.get("stats", 6))], 18, UiKit.TEXT))
	var used := Deck.points(_cards(), _ups, _cfg)
	var budget := int(_cfg.get("budget", 0))
	v.add_child(UiKit.label("Điểm bộ thẻ %d / %d  (Hiếm 1 · Sử thi 2 · Huyền thoại 3)" % [used, budget], 15,
		Color("ff8a8a") if used >= budget else UiKit.GOLD))
	v.add_child(UiKit.button("Bộ mặc định", func() -> void:
		_set_cards(Deck.default_cards(_ups, _start, _cfg))
		_rebuild(), Vector2(w - 40, 40), 16))


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
