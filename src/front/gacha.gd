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
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_H:   # the history in place of the last pull (web: H)
			_tab = "result" if _tab == "history" else "history"
			_rebuild()
		elif k == KEY_Q or k == KEY_E:   # the previous / next shelf
			var ids := _g.banners().map(func(b: Dictionary) -> String: return String(b["id"]))
			_open_banner(posmod(ids.find(_bid) + (1 if k == KEY_E else -1), ids.size()))


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
	var hint := Journal.ink("Q / E đổi kệ · ← → chọn số lần quay · Enter quay · H lịch sử · Esc về sổ", 15, Journal.PAPER)
	hint.position = Vector2(Journal.BOOK.position.x, Journal.BOOK.end.y + 14)
	root.add_child(hint)
	# the shelves are bookmark ribbons (web screen-gacha-journal)
	var banners := _g.banners()
	Journal.ribbons(root, banners.map(func(b: Dictionary) -> String: return String(b.get("name", ""))),
		[Color("8a3a3a"), Color("3a6a8a")], banners.map(func(b: Dictionary) -> String: return String(b["id"])).find(_bid), _open_banner)
	# left page: the shelf, the orb, the odds, the guaranteed legendary, the gems
	var left := VBoxContainer.new()
	left.position = LEFT_PAGE.position + Vector2(0, -8)
	left.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	left.add_theme_constant_override("separation", 0)
	root.add_child(left)
	left.add_child(Journal.ink("Quay đồ", 44))
	var cur := _g.banner(_bid)
	var sub := Journal.ink("Kệ %s: %s" % [String(cur.get("name", _bid)), String(cur.get("desc", ""))], 20, Journal.INK_RED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 0)
	left.add_child(sub)
	var orb := Control.new()
	orb.custom_minimum_size = Vector2(LEFT_PAGE.size.x, 236)
	orb.draw.connect(func() -> void:
		var box := Rect2((LEFT_PAGE.size.x - 220) * 0.5, 8, 220, 220)
		orb.draw_rect(box, Color("d8c498"))
		orb.draw_rect(box, Journal.EDGE, false, 4.0)
		var c := box.get_center()
		orb.draw_circle(c, 81, Color("c9a65a"))   # the gold ring
		orb.draw_circle(c, 75, Journal.INK)
		for k in 12:   # the purple sphere, lighter towards its top left (flat bands, like the web's gradient)
			var t := k / 11.0
			orb.draw_circle(c.lerp(c + Vector2(-22, -22), t), 71.0 * (1.0 - t * 0.85), Color("3a1660").lerp(Color("f0e0ff"), t * t)))
	left.add_child(orb)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	left.add_child(gap)
	var rates: Dictionary = _g.data.get("rates", {})
	for r in ["rare", "epic", "legendary"]:
		if rates.has(r):
			var row := Journal.ledger("", String(RNAME.get(r, r)), "%.0f%%" % (float(rates[r]) * 100.0), 20)
			((row.get_child(0) as HBoxContainer).get_child(0) as Label).add_theme_color_override("font_color", RAR_INK.get(r, Journal.INK))
			left.add_child(row)
	left.add_child(Journal.ledger("", "Bảo đảm Huyền thoại", "còn %d / %d lần" % [_g.pity_at() - int(_slot.pity.get(_bid, 0)), _g.pity_at()], 20))
	left.add_child(Journal.ledger("", "Đá đang có", str(_slot.gems), 20))
	# right page: the last pull (or the history, H), the note, the two seals
	var mv := VBoxContainer.new()
	mv.position = RIGHT_PAGE.position + Vector2(0, -8)
	mv.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 0)
	mv.add_theme_constant_override("separation", 8)
	root.add_child(mv)
	var h2 := Journal.ink("Lịch sử quay · %s" % String(cur.get("name", _bid)) if _tab == "history" else "Lần quay trước", 32)
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0, 0, 0, 0)
	under.border_color = Journal.INK
	under.border_width_bottom = 3
	h2.add_theme_stylebox_override("normal", under)
	mv.add_child(h2)
	if _tab == "history":
		_history(mv)
	else:
		if _last.is_empty():
			var none := Journal.ink("Chưa quay lần nào ở kệ này.", 20, Journal.INK_SOFT)
			mv.add_child(none)
		else:
			var grid := GridContainer.new()
			grid.columns = 5
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
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
		mv.add_child(Journal.ink("Trùng món đã có: đổi thành vàng và mảnh thẻ.", 18, Journal.INK_SOFT))
	var pulls := HBoxContainer.new()
	pulls.position = Vector2(RIGHT_PAGE.position.x, RIGHT_PAGE.end.y - 72)
	pulls.size = Vector2(RIGHT_PAGE.size.x, 72)
	pulls.add_theme_constant_override("separation", 16)
	root.add_child(pulls)
	for n in [1, 10]:
		var b := Journal.seal("Quay ×%d\n%d đá" % [n, _g.cost(n)], Vector2(0, 72), 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = _slot.gems < _g.cost(n)
		b.pressed.connect(func() -> void: _pull(n))
		pulls.add_child(b)
	var first := pulls.get_child(0) as Button
	if not first.disabled:
		first.call_deferred("grab_focus")


## Opens shelf [param i] (a ribbon press, or Q / E).
func _open_banner(i: int) -> void:
	var ids := _g.banners().map(func(b: Dictionary) -> String: return String(b["id"]))
	if i >= 0 and i < ids.size() and ids[i] != _bid:
		_bid = ids[i]
		_rebuild()


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
	p.custom_minimum_size = Vector2(76, 76)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var ic := UiKit.icon(String(d.get("icon", r["id"])), 48.0)   # icon only: the name and dup gold are in the tooltip
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	Tip.attach(p, String(d.get("name", r["id"])), String(d.get("desc", "")), col, String(d.get("icon", r["id"])), String(RNAME.get(String(r["rarity"]), "")) + ((" · trùng → +%d vàng" % int(r["gold"])) if bool(r["dup"]) else " · mới"))
	return p


## Lịch sử quay of the selected banner, newest first: time, item (rarity colour),
## rarity, new or the duplicate's gold. Scrolls; top-aligned.
func _history(mv: VBoxContainer) -> void:
	var rows := Gacha.history(_slot, _bid)
	if rows.is_empty():
		mv.add_child(Journal.ink("Chưa quay lượt nào ở kệ này.", 20, Journal.INK_SOFT))
	else:
		var scroll := ScrollContainer.new()   # newest first, one ledger line each: "#n item … rarity"
		scroll.custom_minimum_size = Vector2(RIGHT_PAGE.size.x, 400)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		mv.add_child(scroll)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 0)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		var total := rows.size()   # pulls kept in the history, oldest #1
		for k in rows.size():
			var r: Dictionary = rows[k]
			var d: Dictionary = _slot.profile.defs.get(String(r["id"]), {})
			var rar := String(r["rarity"])
			var row := Journal.ledger("", "#%d %s" % [total - k, String(d.get("name", r["id"]))], String(RNAME.get(rar, "")), 20, RAR_INK.get(rar, Journal.INK))
			row.tooltip_text = when(float(r.get("t", 0.0)))
			row.custom_minimum_size = Vector2(RIGHT_PAGE.size.x - 16, 0)
			list.add_child(row)
	mv.add_child(Journal.ink("Giữ %d lần quay gần nhất mỗi kệ. H: quay lại." % int(_g.data.get("history_keep", 100)), 18, Journal.INK_SOFT))


## "18/11 10:42" in local time for a unix time [param t]. Fixed mode (shots,
## tests) uses UTC so images do not depend on the machine's time zone.
static func when(t: float) -> String:
	var bias := 0 if Prefs.current() == null or Prefs.current().is_fixed() else int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(t) + bias * 60)
	return "%02d/%02d %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]
