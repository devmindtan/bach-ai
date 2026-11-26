extends Node2D
## The deck screen (design/ux/deck.md, rules in design/skill-tree-v2.md §2): three deck tabs; the
## class's cards in a grid (skills, then stats), cards in the deck framed gold with a tick, the starting
## skill locked; the viewed card on the right with add / remove and, for a skill card with a tree, its
## points and the "Cây thẻ" button; the deck counts and "Bộ mặc định" below. Changes save at once.
##
## Command line (after `--`), for shots: --deck-view=<card id>, --deck-odds (the odds table open).

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const TREE_SCENE := "res://src/front/card_tree.tscn"
const TILE := Vector2(72, 72)   # journal: sketch cells on the left page (design-web screen-deck-journal)
const LEFT_PAGE := Rect2(110, 74, 470, 572)
const RIGHT_PAGE := Rect2(660, 74, 470, 572)
const TIER_INK := {"common": Color("6a6a6a"), "rare": Color("3a6aaa"), "epic": Color("7a3ab8"), "legendary": Color("c0801a")}

var _slot: Slot
var _ups: Array = []
var _start: Array = []
var _cfg := {}
var _trees: CardTree
var _view := ""
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
	if "--deck-odds" in OS.get_cmdline_user_args():   # shots: the card odds table open
		_show_odds.call_deferred()


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


func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, Journal.BOOK)


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
	Journal.back_tab(root, func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))   # "Trở lại" (web .back-tab)
	var title := Journal.ink("Bộ thẻ", 44)
	title.position = LEFT_PAGE.position + Vector2(0, -8)
	root.add_child(title)
	var sub := Journal.ink("Lên cấp trong trận chỉ ra thẻ trong bộ", 18, Journal.INK_RED)
	sub.position = LEFT_PAGE.position + Vector2(2, 48)
	root.add_child(sub)
	var hint := Journal.ink("Chọn thẻ · Enter thêm / bỏ · Esc về sổ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	# right page top: the deck tabs and the shards
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.position = RIGHT_PAGE.position
	root.add_child(tabs)
	for i in _slot.decks.size():
		var on := i == _slot.deck_active
		var t := UiKit.button(String(_slot.decks[i].get("name", "Bộ %d" % (i + 1))), func() -> void:
			_slot.deck_active = i
			_save()
			_rebuild(), Vector2(104, 34), 17)
		if on:
			t.add_theme_stylebox_override("normal", UiKit.style(Color("3a3020"), 8, Color.WHITE, 3))   # chosen: ink after restyle
		tabs.add_child(t)
	var wallet := _shard_stat("%d Mảnh thẻ" % _slot.shards, "Mảnh thẻ: thắng ải, hạ boss, mở rương, gacha trùng; mở nút cây thẻ.", 18)
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(wallet)
	Journal.restyle(tabs)
	# collection grid: skills, then stats
	var y := 150.0
	for kind in ["skill", "stat"]:
		var head := Journal.ink("Chiêu" if kind == "skill" else "Chỉ số", 24, Journal.INK_SOFT)
		head.position = Vector2(LEFT_PAGE.position.x, y)
		root.add_child(head)
		y += 34.0
		var grid := GridContainer.new()
		var cols := 6
		var x0 := LEFT_PAGE.position.x
		if kind == "skill" and not _start.is_empty():
			# the starting skill: one big 2x2 tile of its own, always in the deck (user 2026-11-20)
			var big := _start_tile(_card(String(_start[0])))
			big.position = Vector2(x0, y)
			root.add_child(big)
			cols = 4
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
		if cols == 4:
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
	_sketch(b, Journal.INK_RED, on, true)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.offset_top = 10
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tag := Journal.ink("Chiêu khởi đầu", 15, Journal.GOLD if on else Journal.INK_RED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var ic := UiKit.card_icon(id, 64.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var nm := Journal.ink(String(u.get("name", id)), 19, Journal.PAPER if on else Journal.INK)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var lock := Journal.ink("Luôn trong bộ", 14, Journal.PAPER if on else Journal.INK_SOFT)
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
	_sketch(b, TIER_INK.get(tier, Journal.INK), on, in_deck)   # the frame's ink is the tier (design/card-rarity.md)
	var ic := UiKit.card_icon(id, 48.0)   # the name is in the tooltip and the detail (journal cells are icons)
	ic.position = (TILE - Vector2(48, 48)) * 0.5
	ic.size = Vector2(48, 48)
	var line_art := String(u.get("kind", "")) == "stat"   # stat icons are pale line art: drawn in ink on paper
	if line_art:
		ic.modulate = Journal.PAPER if on else (Journal.INK if in_deck else Journal.INK_SOFT)
	else:
		ic.modulate = Color.WHITE if in_deck or on else Color(0.55, 0.5, 0.45)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var pts := Deck.cost(u, _cfg)   # no gem on the small tile (user 2026-11-20): the frame is the tier, the
	if pts > 0:                     # detail shows the gem; only the deck cost stays, top left
		var pl := Journal.ink("%d" % pts, 14, Journal.GOLD if on else TIER_INK.get(tier, Journal.INK))
		pl.position = Vector2(5, 0)
		pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pl)
	Tip.attach(b, String(u.get("name", id)), String(u.get("desc", "")), UiKit.RARITY.get(tier, UiKit.TEXT), id,
		"%s · %d điểm bộ thẻ" % [UiKit.RARITY_NAME.get(tier, tier), pts])
	if in_deck:   # the tick, or a lock on the starting skill
		var badge := PanelContainer.new()   # a gold round badge: "in this deck" at a glance
		var bs := UiKit.style(Journal.SEAL, 0, Color("5a0c08"), 2)
		bs.set_corner_radius_all(10)
		badge.add_theme_stylebox_override("panel", bs)
		badge.custom_minimum_size = Vector2(20, 20)
		badge.position = Vector2(TILE.x - 22, 2)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := Journal.ink("✓", 13, Journal.PAPER)
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
	var w := RIGHT_PAGE.size.x + 40
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.position = RIGHT_PAGE.position + Vector2(0, 50)
	panel.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var u := _card(_view)
	if not u.is_empty():
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		v.add_child(head)
		var hic := UiKit.card_icon(_view, 48.0)
		if String(u.get("kind", "")) == "stat":
			hic.modulate = Journal.INK   # pale line art in ink on paper
		head.add_child(hic)
		var hv := VBoxContainer.new()
		head.add_child(hv)
		hv.add_child(Journal.ink(String(u.get("name", _view)), 32))
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
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	v.add_child(btns)
	btns.add_child(UiKit.button("Bộ mặc định", func() -> void:
		_set_cards(Deck.default_cards(_ups, _start, _cfg))
		_rebuild(), Vector2((w - 50) / 2.0, 40), 16))
	btns.add_child(UiKit.button("Tỉ lệ thẻ", func() -> void: _show_odds(), Vector2((w - 50) / 2.0, 40), 16))
	Journal.restyle(panel)


## The level-up card odds table (user 2026-11-21): how the chance of rare-or-better cards grows with the run level.
func _show_odds() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var p := UiKit.panel(UiKit.PANEL, 22)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UiKit.label("Tỉ lệ thẻ khi lên cấp", 24, UiKit.GOLD))
	v.add_child(UiKit.label("Cấp trong trận càng cao càng dễ ra thẻ hiếm trở lên. Rương báu và rương vàng có tỉ lệ riêng.", 14, UiKit.MUTED))
	v.add_child(UiKit.rarity_odds_table(CardRarity.load_default(), [1, 5, 10, 15, 20, 25, 30]))
	v.add_child(UiKit.label("Thẻ chỉ số không giới hạn cấp: hết thẻ chiêu để nâng thì vẫn luôn có thẻ chỉ số.", 14, UiKit.TEXT))
	var close := UiKit.button("Đóng", func() -> void:
		dim.queue_free()
		p.queue_free(), Vector2(0, 40), 16)
	v.add_child(close)
	Journal.restyle(p)
	var paper := StyleBoxFlat.new()   # a loose sheet of the journal
	paper.bg_color = Journal.PAPER
	paper.border_color = Journal.EDGE
	paper.set_border_width_all(4)
	paper.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", paper)
	_layer.add_child(p)
	p.position = (get_viewport_rect().size - p.get_combined_minimum_size()) / 2.0
	close.call_deferred("grab_focus")


## A sketch cell: paper (rose once [param filled]) with a [param frame] ink border; viewed/focused: ink, gold frame.
func _sketch(b: Button, frame: Color, on: bool, filled: bool) -> void:
	for st in ["normal", "hover", "focus", "pressed"]:
		var lit: bool = on or st != "normal"
		var sb := StyleBoxFlat.new()
		sb.bg_color = Journal.INK if on else (Color("d8a898") if filled else Journal.SKETCH)
		sb.border_color = Journal.GOLD if lit else frame
		sb.set_border_width_all(4 if lit else 3)
		b.add_theme_stylebox_override(st, sb)
	b.mouse_entered.connect(func() -> void: b.grab_focus())


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
