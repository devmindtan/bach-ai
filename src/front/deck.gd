extends Node2D
## The deck screen (design/ux/deck.md, rules in design/skill-tree-v2.md §2): three deck tabs; the
## class's cards in a grid (skills, then stats), cards in the deck framed gold with a tick, the starting
## skill locked; the viewed card on the right with add / remove and, for a skill card with a tree, its
## points and the "Cây thẻ" button; the deck counts and "Bộ mặc định" below. Changes save at once.
##
## Command line (after `--`), for shots: --deck-view=<card id>, --deck-odds (the odds table open).

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const TREE_SCENE := "res://src/front/card_tree.tscn"
const TILE := Vector2(76, 76)   # journal: sketch cells on the left page (design-web screen-deck-journal)
const LEFT_PAGE := Rect2(110, 74, 470, 572)
const RIGHT_PAGE := Rect2(660, 74, 470, 572)
const TIER_INK := {"common": Color("3a2414"), "rare": Color("3a6aaa"), "epic": Color("7a3ab8"), "legendary": Color("c0801a")}

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
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_Q or k == KEY_E:
			_set_kind(1 - _kind)
		elif k == KEY_T:
			_open_tree(_view)
		elif k == KEY_R:
			_default_deck()
		elif k == KEY_O:
			_show_odds()


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


var _kind := 0   # the left page's tab: 0 Chiêu, 1 Chỉ số (Q / E)


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	Journal.back_tab(root, func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))   # "Trở lại" (web .back-tab)
	var hint := Journal.ink("←↑↓→ chọn thẻ · Q / E chiêu / chỉ số · Enter thêm / bỏ · T cây thẻ · Esc về sổ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	# the decks are bookmark ribbons (web screen-deck-journal)
	Journal.ribbons(root, _slot.decks.map(func(d: Dictionary) -> String: return String(d.get("name", "Bộ"))),
		[Color("8a3a3a"), Color("3a6a8a"), Color("6a8a3a")], _slot.deck_active, func(i: int) -> void:
		_slot.deck_active = i
		_save()
		_rebuild())
	# left page: the title, its line, the Chiêu / Chỉ số tabs, the cards
	var left := VBoxContainer.new()
	left.position = LEFT_PAGE.position + Vector2(0, -8)
	left.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	left.add_child(Journal.ink("Bộ thẻ", 44))
	var sub := Journal.ink("Thẻ mang vào trận: lên cấp trong trận chỉ ra thẻ trong bộ", 20, Journal.INK_RED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	left.add_child(sub)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	left.add_child(tabs)
	for i in 2:
		var t := Button.new()
		t.text = ["Chiêu", "Chỉ số"][i]
		t.focus_mode = Control.FOCUS_NONE
		t.add_theme_font_size_override("font_size", 18)
		for st in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Journal.INK if i == _kind else Color(0, 0, 0, 0)
			sb.border_color = Journal.INK
			sb.set_border_width_all(2)
			sb.content_margin_left = 8
			sb.content_margin_right = 8
			t.add_theme_stylebox_override(st, sb)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			t.add_theme_color_override(k, Journal.PAPER if i == _kind else Journal.INK)
		t.pressed.connect(func() -> void: _set_kind(i))
		tabs.add_child(t)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	var focus: Control = null
	for u: Dictionary in _list():
		var t := _tile(u)
		grid.add_child(t)
		if String(u["id"]) == _view:
			focus = t
	if focus == null and grid.get_child_count() > 0:
		focus = grid.get_child(0)
	if focus != null:
		focus.call_deferred("grab_focus")
	_deck_page(root)


## The cards of the tab: skills (the starting one first) or stats, the deck's kind only.
func _list() -> Array:
	var kind := "skill" if _kind == 0 else "stat"
	var out := []
	for u: Dictionary in _ups:
		if String(u.get("kind", "")) == kind and Deck.is_deck_card(u):
			if _start.has(String(u["id"])):
				out.push_front(u)
			else:
				out.append(u)
	return out


func _set_kind(i: int) -> void:
	if i != _kind:
		_kind = i
		_view = String(_list()[0]["id"]) if not _list().is_empty() else ""
		_rebuild()


## A card: its icon in a sketch cell framed in its tier's ink; in the deck: a green tick; viewed: ink + gold.
## Focus views it; Enter / a click adds or removes it.
func _tile(u: Dictionary) -> Button:
	var id := String(u["id"])
	var in_deck := _cards().has(id) or _start.has(id)
	var on := id == _view
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_ALL
	var tier := String(u.get("rarity", "common"))
	_sketch(b, TIER_INK.get(tier, Journal.INK), on, false)
	var ic := UiKit.card_icon(id, 52.0)
	ic.position = (TILE - Vector2(52, 52)) * 0.5
	ic.size = Vector2(52, 52)
	if String(u.get("kind", "")) == "stat":   # pale line art in ink on paper
		ic.modulate = Journal.PAPER if on else Journal.INK
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	if in_deck:
		var tick := Journal.ink("✓", 26, Color("2a7a3a"))
		tick.position = Vector2(TILE.x - 20, -10)
		b.add_child(tick)
	Tip.attach(b, String(u.get("name", id)), String(u.get("desc", "")), TIER_INK.get(tier, Journal.INK), id,
		"%s · %d điểm hiếm" % [UiKit.RARITY_NAME.get(tier, tier), Deck.cost(u, _cfg)])
	b.focus_entered.connect(func() -> void:
		if _view != id:
			_view = id
			_rebuild())
	b.pressed.connect(func() -> void:
		if _start.has(id):   # the starting skill is always in the deck
			return
		var has := _cards().has(id)
		var why := Deck.why_not_remove(_cards(), id, _start) if has else Deck.why_not_add(_cards(), _ups, id, _cfg)
		if why == "":
			_set_cards(Deck.remove(_cards(), id, _start) if has else _cards() + [id])
			_rebuild()
		else:
			_why = why
			_rebuild())
	return b


var _why := ""   # why the last add / remove did not happen (shown once under the card)


## The right page "Bộ đang dùng": the skill and stat slots, the rarity points and bar, the viewed card, the card
## tree line (T) and the seal "Dùng bộ này".
func _deck_page(root: Control) -> void:
	var v := VBoxContainer.new()
	v.position = RIGHT_PAGE.position + Vector2(0, -8)
	v.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	v.add_theme_constant_override("separation", 4)
	root.add_child(v)
	var h2 := Journal.ink("Bộ đang dùng", 32)
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Journal.INK
	under.border_width_bottom = 3
	h2.add_theme_stylebox_override("normal", under)
	v.add_child(h2)
	for kind in ["skill", "stat"]:
		var ids := []
		for u: Dictionary in _ups:
			var id := String(u["id"])
			if String(u.get("kind", "")) == kind and (_cards().has(id) or _start.has(id)) and not ids.has(id):
				ids.append(id)
		var n := int(_cfg.get("skills" if kind == "skill" else "stats", 8 if kind == "skill" else 6))
		v.add_child(Journal.ink("%s %d/%d" % ["Chiêu" if kind == "skill" else "Chỉ số", ids.size(), n], 20, Journal.INK_SOFT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		for k in n:
			var cell := Control.new()   # a dashed slot, the card's icon when filled
			cell.custom_minimum_size = Vector2(54, 54)
			cell.draw.connect(func() -> void:
				var r := Rect2(Vector2.ZERO, cell.custom_minimum_size)
				var x := 0.0
				while x < r.size.x:
					cell.draw_rect(Rect2(x, 0, 5, 2), Journal.INK)
					cell.draw_rect(Rect2(x, r.size.y - 2, 5, 2), Journal.INK)
					cell.draw_rect(Rect2(0, x, 2, 5), Journal.INK)
					cell.draw_rect(Rect2(r.size.x - 2, x, 2, 5), Journal.INK)
					x += 9.0)
			if k < ids.size():
				var ic := UiKit.card_icon(String(ids[k]), 44.0)
				ic.position = Vector2(5, 5)
				ic.size = Vector2(44, 44)
				if kind == "stat":
					ic.modulate = Journal.INK
				cell.add_child(ic)
			row.add_child(cell)
	var used := Deck.points(_cards(), _ups, _cfg)
	var budget := int(_cfg.get("budget", 0))
	v.add_child(Journal.ledger("", "Điểm hiếm", "%d/%d" % [used, budget], 20))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(300, 18)
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(0, 0, 300, 16), Journal.INK, false, 3.0)
		bar.draw_rect(Rect2(2, 2, 296.0 * clampf(float(used) / maxf(1.0, budget), 0.0, 1.0), 12), Journal.INK_RED))
	v.add_child(bar)
	var u := _card(_view)
	if not u.is_empty():
		v.add_child(Journal.note(String(u.get("name", _view)), String(u.get("desc", "")), 18))
		if _why != "":
			var w := Journal.ink(_why, 17, Journal.INK_RED)
			w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			w.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
			v.add_child(w)
			_why = ""
		if not _trees.tree(_view).is_empty():
			var card := _view
			var link := Button.new()
			link.text = "Cây thẻ ▸ nâng thẻ bằng Mảnh thẻ (phím T)"
			link.flat = true
			link.focus_mode = Control.FOCUS_NONE
			link.alignment = HORIZONTAL_ALIGNMENT_LEFT
			link.add_theme_font_size_override("font_size", 18)
			for k in ["font_color", "font_hover_color", "font_pressed_color"]:
				link.add_theme_color_override(k, Journal.INK if k == "font_color" else Journal.INK_RED)
			link.pressed.connect(func() -> void: _open_tree(card))
			v.add_child(link)
	var links := HBoxContainer.new()   # web proposal approved 2026-11-26: Bộ mặc định (R), Tỉ lệ thẻ (O)
	links.add_theme_constant_override("separation", 18)
	v.add_child(links)
	var dflt := Journal.link("Bộ mặc định ▸ (R)", 18)
	dflt.pressed.connect(_default_deck)
	links.add_child(dflt)
	var odds := Journal.link("Tỉ lệ thẻ ▸ (O)", 18)
	odds.pressed.connect(_show_odds)
	links.add_child(odds)
	var use := Journal.seal("Dùng bộ này ▶", Vector2(260, 62), 26)
	use.position = RIGHT_PAGE.end - Vector2(260, 62)
	use.focus_mode = Control.FOCUS_NONE   # the cards own the arrows; Enter on the seal is the mouse's
	use.pressed.connect(func() -> void:
		_save()   # the open deck is the one the runs use (deck_active); back to the journal
		get_tree().change_scene_to_file(LOBBY_SCENE))
	root.add_child(use)


func _default_deck() -> void:
	_set_cards(Deck.default_cards(_ups, _start, _cfg))
	_rebuild()


func _open_tree(card: String) -> void:
	if _trees.tree(card).is_empty():
		return
	Prefs.current().card_target = card
	get_tree().change_scene_to_file(TREE_SCENE)


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
