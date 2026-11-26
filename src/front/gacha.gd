extends Node2D
## The gacha screen (design/ux/gacha.md, rules in design/gacha.md): banners with
## their own pity counter on the left, the last pull's results in the middle, the
## published rates, the pity rule, the price and the Quay 1 / Quay 10 buttons on
## the right. Pulls save at once. Esc goes back to the lobby.
##
## The middle column has two tabs: Kết quả (the last pull) and Lịch sử (this
## banner's pulls, newest first, like Genshin's wish history).
##
## Command line (after `--`), for shots: --gacha-demo (a 10-pull at the start),
## --gacha-tab=history (open on Lịch sử).

const LOBBY_SCENE := "res://src/lobby/lobby.tscn"
const RNAME := {"common": "Thường", "rare": "Hiếm", "epic": "Sử thi", "legendary": "Huyền thoại"}

var _reveal := false   # the next build flips the result cards in (a pull just happened)
var _flips: Array = []
var _reveal_shot := "--reveal-shot" in OS.get_cmdline_user_args()   # shots: reveal even in the fixed preview
var _slot: Slot
var _g: Gacha
var _bid := "weapon"
var _last: Array = []
var _rng := RandomNumberGenerator.new()
var _layer: CanvasLayer
var _tab := "result"                  # "result" | "history"


func _ready() -> void:
	Sfx.music("menu")
	var prefs := Prefs.current()
	if prefs.is_fixed():
		prefs.ensure_preview_slot()
		_rng.seed = 5
	else:
		prefs.ensure_slots()
		_rng.randomize()
	_slot = prefs.active_slot
	if _slot == null:
		get_tree().change_scene_to_file.call_deferred("res://src/front/characters.tscn")
		return
	_g = Gacha.load_default()
	if OS.get_cmdline_user_args().has("--gacha-demo"):
		_slot.gems = maxi(_slot.gems, _g.cost(10))
		_last = _g.pull(_slot, _bid, 10, _rng, 1763460000.0)   # a fixed time: shots stay identical
		_slot.gems = maxi(_slot.gems, _g.cost(10))
		_g.pull(_slot, _bid, 10, _rng, 1763463600.0)   # a second one, so Lịch sử has two times
	if OS.get_cmdline_user_args().has("--gacha-tab=history"):
		_tab = "history"
	_reveal = _reveal_shot and not _last.is_empty()   # --reveal-shot: flip the demo pull in
	_build()


func _draw() -> void:
	Journal.draw_desk(self, get_viewport_rect().size)
	Journal.draw_book(self, Journal.BOOK)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(LOBBY_SCENE)


func _rebuild() -> void:
	if _layer != null:
		_layer.queue_free()
	_build()


func _pull(n: int) -> void:
	var got := _g.pull(_slot, _bid, n, _rng)
	if got.is_empty():
		return
	_last = got
	_tab = "result"
	Daily.load_default().add(_slot, "gacha_pulls", n)
	Sfx.play("gacha_pull")
	var best := ""
	for r: Dictionary in got:
		if r["rarity"] == "legendary" or (r["rarity"] == "epic" and best == ""):
			best = String(r["rarity"])
	if best != "":
		Sfx.play("gacha_legend" if best == "legendary" else "gacha_epic")
	if not Prefs.current().is_fixed():
		Prefs.current().slot_store().save(_slot)
	_reveal = not Prefs.current().is_fixed() or _reveal_shot
	_rebuild()


const LEFT_PAGE := Rect2(110, 74, 470, 572)
const RIGHT_PAGE := Rect2(660, 74, 470, 572)
const RAR_INK := {"common": Color("6a6a6a"), "rare": Color("3a6aaa"), "epic": Color("7a3ab8"), "legendary": Color("c0801a")}


func _build() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	var root := Control.new()
	root.size = get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	Journal.back_tab(root, func() -> void: get_tree().change_scene_to_file(LOBBY_SCENE))   # "Trở lại" (web .back-tab)
	var hint := Journal.ink("Chọn kệ · Enter quay · Esc về sổ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	# left page: the shelves (banners, each with its own pity), the odds and the rule
	var left := VBoxContainer.new()
	left.position = LEFT_PAGE.position + Vector2(0, -8)
	left.size = LEFT_PAGE.size
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	left.add_child(Journal.ink("Quay đồ", 44))
	var cur := _g.banner(_bid)
	var sub := Journal.ink("Kệ %s: %s" % [String(cur.get("name", _bid)), String(cur.get("desc", ""))], 18, Journal.INK_RED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	left.add_child(sub)
	var shelves := HBoxContainer.new()
	shelves.add_theme_constant_override("separation", 8)
	left.add_child(shelves)
	for b: Dictionary in _g.banners():
		shelves.add_child(_banner_button(b))
	Journal.restyle(shelves)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	left.add_child(gap)
	var rates: Dictionary = _g.data.get("rates", {})
	for r in Gacha.ORDER:
		if rates.has(r):
			left.add_child(Journal.ledger("", String(RNAME.get(r, r)), "%.0f%%" % (float(rates[r]) * 100.0), 20, RAR_INK.get(r, Journal.INK)))
	left.add_child(Journal.ledger("", "Bảo đảm Huyền thoại", "còn %d / %d lần" % [_g.pity_at() - int(_slot.pity.get(_bid, 0)), _g.pity_at()], 20))
	left.add_child(Journal.ledger("gem", "Đá đang có", str(_slot.gems), 20))
	var rule := Journal.ink("Lượt thứ %d kể từ món huyền thoại gần nhất chắc chắn ra huyền thoại; mỗi kệ đếm riêng. Quay 1 và quay 10 cùng tỉ lệ. Chỉ ra đồ lớp này mặc được; món trùng đổi thành vàng." % _g.pity_at(), 16, Journal.INK_SOFT)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	left.add_child(rule)
	# right page: Kết quả / Lịch sử, then the two pulls at the bottom (×10 is the seal)
	var mv := VBoxContainer.new()
	mv.position = RIGHT_PAGE.position
	mv.size = Vector2(RIGHT_PAGE.size.x, RIGHT_PAGE.size.y - 76)
	mv.add_theme_constant_override("separation", 10)
	root.add_child(mv)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	mv.add_child(tabs)
	for t: Array in [["result", "Lần quay trước"], ["history", "Lịch sử"]]:
		var on: bool = _tab == t[0]
		var tb := UiKit.button(t[1], func() -> void:
			_tab = t[0]
			_rebuild(), Vector2(170, 34), 17)
		if on:
			tb.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL_HOVER, 8, Color.WHITE, 2))
		tabs.add_child(tb)
	Journal.restyle(tabs)
	if _tab == "history":
		_history(mv)
		for c in mv.get_children():
			if c != tabs:
				Journal.restyle(c)
	elif _last.is_empty():
		var none := Journal.ink("Chọn kệ rồi quay 1 hoặc 10 lần. Món mới vào túi đồ; món trùng đổi thành vàng.", 19, Journal.INK_SOFT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
		mv.add_child(none)
	else:
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		mv.add_child(grid)
		for r: Dictionary in _last:
			var card := _result_card(r)
			var holder := Control.new()   # a plain parent: a flip's back must cover the card, not sit inside its margins
			holder.custom_minimum_size = card.custom_minimum_size
			card.set_anchors_preset(Control.PRESET_FULL_RECT)
			holder.add_child(card)
			grid.add_child(holder)
		if _reveal:   # the pull just made flips in; rebuilding the same result later does not
			_reveal = false
			_reveal_cards.call_deferred(grid, _last)
	var pulls := HBoxContainer.new()
	pulls.position = Vector2(RIGHT_PAGE.position.x, RIGHT_PAGE.end.y - 62)
	pulls.size = Vector2(RIGHT_PAGE.size.x, 62)
	pulls.add_theme_constant_override("separation", 12)
	root.add_child(pulls)
	var one := UiKit.button("Quay ×1 · %d đá" % _g.cost(1), func() -> void: _pull(1), Vector2(0, 62), 19)
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	one.disabled = _slot.gems < _g.cost(1)
	pulls.add_child(one)
	Journal.restyle(one)
	var ten := Journal.seal("Quay ×10 · %d đá" % _g.cost(10), Vector2(0, 62), 22)
	ten.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ten.disabled = _slot.gems < _g.cost(10)
	ten.pressed.connect(func() -> void: _pull(10))
	pulls.add_child(ten)
	if not ten.disabled:
		ten.call_deferred("grab_focus")


func _banner_button(b: Dictionary) -> Button:
	var id := String(b["id"])
	var on := id == _bid
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(231, 62)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", UiKit.style(UiKit.PANEL_HOVER if on else UiKit.PANEL, 12, Color.WHITE if on else UiKit.GOLD, 3 if on else 2))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 6
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)
	for l in [UiKit.label("Kệ " + String(b.get("name", id)), 20, UiKit.TEXT),
			UiKit.label("%d/%d lượt tới huyền thoại" % [int(_slot.pity.get(id, 0)), _g.pity_at()], 14, UiKit.MUTED)]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	btn.pressed.connect(func() -> void:
		_bid = id
		_rebuild())
	return btn


## Pull reveal (6D.2, after Genshin / Star Rail colour-coded wishes): the cards flip in one by one;
## a back's border tells the rarity before the face (rare blue, epic purple, legendary gold), an epic
## waits a beat and a legendary longer, and both pop as they turn. Any press shows everything.
func _reveal_cards(grid: Control, got: Array) -> void:
	var borders := []
	var holds := []
	var pops := []
	for r: Dictionary in got:
		var rar := String(r["rarity"])
		borders.append(UiKit.RARITY.get(rar, UiKit.GOLD) if rar != "common" else Color("4a4458"))
		holds.append({"legendary": 0.45, "epic": 0.2}.get(rar, 0.0))
		pops.append(rar == "legendary" or rar == "epic")
	CardFlip.finish(_flips)
	_flips = CardFlip.flip_in(grid.get_children(), borders, holds, pops)


func _input(event: InputEvent) -> void:
	if _flips.is_empty():
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		if CardFlip.finish(_flips):
			get_viewport().set_input_as_handled()   # this press only skips the reveal


func _result_card(r: Dictionary) -> PanelContainer:
	var d: Dictionary = _slot.profile.defs.get(String(r["id"]), {})
	var col: Color = RAR_INK.get(String(r["rarity"]), Journal.INK)   # a sketch card on the page, framed in the tier's ink
	var p := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Journal.SKETCH
	ps.border_color = col
	ps.set_border_width_all(4)
	ps.set_content_margin_all(5)
	p.add_theme_stylebox_override("panel", ps)
	p.custom_minimum_size = Vector2(86, 132)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var ic := UiKit.icon(String(d.get("icon", r["id"])), 48.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var nm := Journal.ink(String(d.get("name", r["id"])), 14, col)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.custom_minimum_size.x = 74
	v.add_child(nm)
	var tag := Journal.ink(("+%d vàng" % int(r["gold"])) if bool(r["dup"]) else "Mới", 13, Journal.INK_SOFT if bool(r["dup"]) else Color("2a7a3a"))
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size.x = 74
	v.add_child(tag)
	Tip.attach(p, String(d.get("name", r["id"])), String(d.get("desc", "")), col, String(d.get("icon", r["id"])), String(RNAME.get(String(r["rarity"]), "")))
	return p


## Lịch sử quay of the selected banner, newest first: time, item (rarity colour),
## rarity, new or the duplicate's gold. Scrolls; top-aligned.
func _history(mv: VBoxContainer) -> void:
	var rows := Gacha.history(_slot, _bid)
	var banner_name := String(_g.banner(_bid).get("name", _bid))
	var head := UiKit.label("Banner %s · %d lượt gần nhất (giữ tối đa %d)" % [banner_name, rows.size(), int(_g.data.get("history_keep", 100))], 14, UiKit.MUTED)
	mv.add_child(head)
	if rows.is_empty():
		mv.add_child(UiKit.label("Chưa quay lượt nào ở banner này.", 15, UiKit.MUTED))
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mv.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()   # room for the scroll bar on the right
	pad.add_theme_constant_override("margin_right", 18)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	pad.add_child(grid)
	for h in ["Thời điểm", "Món", "Độ hiếm", ""]:
		grid.add_child(UiKit.label(h, 13, UiKit.GOLD))
	for r: Dictionary in rows:
		var d: Dictionary = _slot.profile.defs.get(String(r["id"]), {})
		var col: Color = UiKit.RARITY.get(String(r["rarity"]), UiKit.TEXT)
		grid.add_child(UiKit.label(when(float(r.get("t", 0.0))), 14, UiKit.MUTED))
		var nm := UiKit.label(String(d.get("name", r["id"])), 15, col)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(nm)
		grid.add_child(UiKit.label(String(RNAME.get(String(r["rarity"]), "")), 14, col))
		grid.add_child(UiKit.label(("+%d vàng" % int(r["gold"])) if bool(r.get("dup", false)) else "Mới", 14,
			UiKit.MUTED if bool(r.get("dup", false)) else Color("8fe08a")))


## "18/11 10:42" in local time for a unix time [param t]. Fixed mode (shots,
## tests) uses UTC so images do not depend on the machine's time zone.
static func when(t: float) -> String:
	var bias := 0 if Prefs.current() == null or Prefs.current().is_fixed() else int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(t) + bias * 60)
	return "%02d/%02d %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]
