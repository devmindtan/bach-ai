class_name RunPanels
extends Control
## Modal panels of a run: level-up (three upgrade cards, click or 1/2/3),
## pause, and the win / lose screen. Calls back into the run node.
##
## Example:
##   panels.show_level_up(["sharpen", "haste", "reach"])

const DIM := Color(0, 0, 0, 0.6)
const CARD := Color("2a2438")
const CARD_HOVER := Color("3b3352")
const BORDER := Color("c9a65a")
const TEXT := Color("f2ecd8")
const MUTED := Color("b9b2a0")
const STAT_ACCENT := Color("6aa6d8")   # stat cards; skills use the gold BORDER
const GAIN := Color("8ee08e")          # the value after the pick
const MILESTONE := Color("ffd36b")
const PIP_LOCKED := Color("1b1726")    # level not reached yet (dark, with a visible edge)
const PIP_EDGE := Color("6b6380")

var run: Node
var _box: Control


func _ready() -> void:
	# a Control under a CanvasLayer has no parent rect: size it to the viewport
	# (anchors alone left it 0x0, so panels and the HUD were laid out at the corner)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func hide_all() -> void:
	if _box != null:
		_box.queue_free()
		_box = null


## Level-up: three cards. Each shows the icon, kind and level, a row of level
## pips (owned / the one you get / still locked, milestones drawn as diamonds),
## the milestone reached by this pick, the real before -> after numbers, and the
## description. Content reads top-down from the top of the card.
func show_level_up(ids: Array[String]) -> void:
	var root := _open("Lên cấp! Chọn một", false)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)
	for i in ids.size():
		row.add_child(_upgrade_card(i, ids[i]))
	_fit_cards.call_deferred(row)


## A Button does not grow with its children: once laid out, give every card the
## height of the tallest content so no text runs past the frame and the row is even.
func _fit_cards(row: HBoxContainer) -> void:
	var h := 0.0
	for b in row.get_children():
		var v: Control = b.get_child(0)
		h = maxf(h, v.get_combined_minimum_size().y + 24.0)
	for b: Control in row.get_children():
		b.custom_minimum_size.y = maxf(180.0, h)


func _upgrade_card(i: int, id: String) -> Button:
	var u: Dictionary = run.upgrade(id)
	var pv: Dictionary = run.upgrade_preview(id)
	var skill: bool = u.get("kind") == "skill"
	var accent := BORDER if skill else STAT_ACCENT
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 180)   # grown to the tallest card by _fit_cards
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _style(CARD, accent))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER, accent))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER, Color.WHITE))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER, Color.WHITE))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	b.add_child(v)
	# header: icon tile | name, kind and level
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := PanelContainer.new()
	var ts := _style(Color("1d1828"), accent)
	ts.set_content_margin_all(4)
	tile.add_theme_stylebox_override("panel", ts)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon)
	head.add_child(tile)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_label("%d. %s" % [i + 1, u.get("name", id)], 20, TEXT))
	var lv: int = pv["level"]
	var kind := ("CHIÊU" if skill else "CHỈ SỐ") + "  ·  " + ("Mới" if lv == 0 else "Cấp %d → %d" % [lv, lv + 1])
	names.add_child(_label(kind, 13, accent))
	head.add_child(names)
	v.add_child(head)
	# level pips + the milestone this pick reaches
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(0, 18)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func() -> void: _draw_pips(pips, lv, int(pv["max"]), pv["milestones"], accent))
	v.add_child(pips)
	if String(pv["milestone"]) != "":
		v.add_child(_label("★ " + String(pv["milestone"]), 14, MILESTONE))
	# real numbers: before -> after
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line: Array in pv["lines"]:
		var k := _label(String(line[0]), 15, MUTED)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(k)
		var change := RichTextLabel.new()
		change.bbcode_enabled = true
		change.fit_content = true
		change.scroll_active = false
		change.autowrap_mode = TextServer.AUTOWRAP_OFF
		change.custom_minimum_size = Vector2(120, 0)
		change.add_theme_font_size_override("normal_font_size", 15)
		change.add_theme_font_size_override("bold_font_size", 15)
		change.mouse_filter = Control.MOUSE_FILTER_IGNORE
		change.text = "[right][color=#%s]%s[/color]  →  [b][color=#%s]%s[/color][/b][/right]" % [
			MUTED.to_html(false), line[1], GAIN.to_html(false), line[2]]
		grid.add_child(change)
	v.add_child(grid)
	var d := _label(String(u.get("desc", "")), 14, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(270, 0)
	v.add_child(d)
	var idx := i
	b.pressed.connect(func() -> void: run.choose(idx))
	if i == 0:
		b.call_deferred("grab_focus")
	return b


## One pip per level: owned = filled, the level this pick gives = bright with a
## ring, locked = dark; milestone levels (new tier look, last level) are diamonds.
func _draw_pips(c: Control, owned: int, max_level: int, milestones: Array, accent: Color, show_next := true) -> void:
	var x := 0.0
	for l in range(1, max_level + 1):
		var nxt := show_next and l == owned + 1
		var col := accent if l <= owned else (Color.WHITE if nxt else PIP_LOCKED)
		var cx := x + 9.0
		if milestones.has(l):
			var pts := PackedVector2Array([Vector2(cx, 0), Vector2(cx + 9, 9), Vector2(cx, 18), Vector2(cx - 9, 9)])
			c.draw_colored_polygon(pts, col)
			var ring := MILESTONE if nxt else PIP_EDGE
			c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), ring, 2.0)
		else:
			c.draw_rect(Rect2(x + 1, 4, 16, 10), col)
			c.draw_rect(Rect2(x + 1, 4, 16, 10), MILESTONE if nxt else PIP_EDGE, false, 2.0)
		x += 24.0


## Pause: actions on the left; on the right the cards taken this run as a compact
## icon grid (skills, then stats), so a build of dozens of cards still fits. Each
## tile shows its level as a badge and a bar; maxed cards get a gold frame. The
## line under the grid names the hovered / focused card with its level and text.
func show_pause() -> void:
	var root := _open("Tạm dừng")
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 32)
	root.add_child(body)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	actions.custom_minimum_size = Vector2(240, 0)
	body.add_child(actions)
	var go_on := _button("Tiếp tục (Esc)", func() -> void: run.resume())
	actions.add_child(go_on)
	go_on.call_deferred("grab_focus")
	actions.add_child(_button("Nhân vật (Tab)", func() -> void: show_character()))
	actions.add_child(_button("Cài đặt", func() -> void: show_settings()))
	actions.add_child(_button("Chơi lại", func() -> void: run.restart()))
	actions.add_child(_button("Về sảnh", func() -> void: run.to_lobby()))
	var owned: Array = run.owned_upgrades()
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	cards.custom_minimum_size = Vector2(OWNED_COLUMNS * (OWNED_TILE + 6) - 6, 0)
	body.add_child(cards)
	cards.add_child(_label("Thẻ đã chọn (%d)" % owned.size(), 18, BORDER))
	if owned.is_empty():
		cards.add_child(_label("Chưa chọn thẻ nào.", 15, MUTED))
		return
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.custom_minimum_size = Vector2(0, 44)
	info.add_theme_font_size_override("normal_font_size", 14)
	info.add_theme_font_size_override("bold_font_size", 16)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for group in [[true, "Chiêu"], [false, "Chỉ số"]]:
		var items := owned.filter(func(o: Dictionary) -> bool: return o["skill"] == group[0])
		if items.is_empty():
			continue
		var accent := BORDER if group[0] else STAT_ACCENT
		cards.add_child(_label("%s · %d" % [group[1], items.size()], 13, accent))
		var grid := GridContainer.new()
		grid.columns = OWNED_COLUMNS
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		cards.add_child(grid)
		for o: Dictionary in items:
			grid.add_child(_owned_tile(o, info))
	cards.add_child(info)
	_show_owned_info(info, owned[0])


const OWNED_TILE := 52
const OWNED_COLUMNS := 8


## One owned card as a square icon tile: level badge bottom-right, a level bar
## along the bottom edge, gold frame when maxed. Hover or focus fills the info line.
func _owned_tile(o: Dictionary, info: RichTextLabel) -> Button:
	var accent := BORDER if o["skill"] else STAT_ACCENT
	var lv: int = o["level"]
	var mx: int = o["max"]
	var maxed := lv >= mx
	var frame := MILESTONE if maxed else PIP_EDGE
	var b := Button.new()
	b.custom_minimum_size = Vector2(OWNED_TILE, OWNED_TILE)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _style(Color("1d1828"), frame))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER, Color.WHITE))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER, Color.WHITE))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER, Color.WHITE))
	var icon := TextureRect.new()
	icon.texture = UiIcons.texture(o["id"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(6, 4)
	icon.size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var over := Control.new()
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.draw.connect(func() -> void: _draw_owned_badge(over, lv, mx, accent, maxed))
	b.add_child(over)
	b.tooltip_text = "%s  %d/%d" % [o["name"], lv, mx]
	b.mouse_entered.connect(func() -> void: _show_owned_info(info, o))
	b.focus_entered.connect(func() -> void: _show_owned_info(info, o))
	return b


func _draw_owned_badge(c: Control, lv: int, mx: int, accent: Color, maxed: bool) -> void:
	var font := ThemeDB.fallback_font
	var sz := 13
	var s := str(lv)   # maxed: gold number and gold frame
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var r := Rect2(OWNED_TILE - w - 10, OWNED_TILE - 24, w + 8, 16)
	c.draw_rect(r, Color(0.05, 0.04, 0.08, 0.9))
	c.draw_string(font, Vector2(r.position.x + 4, roundf(r.get_center().y + sz * 0.36)), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, MILESTONE if maxed else TEXT)
	# level bar: one segment per level along the bottom edge
	var x0 := 4.0
	var bw := OWNED_TILE - 8.0
	var seg := bw / mx
	for l in mx:
		var col := (MILESTONE if maxed else accent) if l < lv else PIP_EDGE.darkened(0.45)
		c.draw_rect(Rect2(x0 + l * seg, OWNED_TILE - 7, maxf(1.0, seg - 1.0), 3), col)


func _show_owned_info(info: RichTextLabel, o: Dictionary) -> void:
	var accent := BORDER if o["skill"] else STAT_ACCENT
	var body := String(o.get("desc", ""))
	if o["skill"]:
		for si: Dictionary in run.skill_info():
			if si["id"] == o["id"]:
				body = "Sát thương %d · Hồi chiêu %.2f s · Vùng ×%.2f" % [roundi(si["damage"]), si["cooldown"], si["size"]]
	else:
		body = run.card_effect_text(o["id"])
	info.text = "[b][color=#%s]%s[/color][/b]  [color=#%s]Cấp %d/%d[/color]\n[color=#%s]%s[/color]" % [
		TEXT.to_html(false), o["name"], accent.to_html(false), o["level"], o["max"],
		MUTED.to_html(false), body]


## Character sheet: every stat with where it comes from (class base + each card),
## and every skill with its real damage / cooldown / size and the cards changing it.
## Character sheet over the whole screen (it was a small box that got crowded
## with many buffs, 2026-11-17): a header (title, class and level, back), then
## three columns that each scroll on their own: stats with their sources, skills
## with their real numbers, running buffs and the stat cards taken.
func show_character() -> void:
	hide_all()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_box = dim
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	var ps := _style(Color(0.09, 0.08, 0.13, 0.96))
	ps.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", ps)
	dim.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)
	# header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	root.add_child(head)
	var title := _label("Nhân vật", 32, BORDER)
	head.add_child(title)
	var sub := _label("%s · Cấp %d" % [run.class_data.get("name", ""), run.level], 18, TEXT)
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sub)
	var back := _button("Quay lại (Esc)", func() -> void: show_pause())
	back.custom_minimum_size = Vector2(200, 40)
	head.add_child(back)
	back.call_deferred("grab_focus")
	# three scrolling columns
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var stats_col := _column(body, "Chỉ số", 330.0, false)
	var bd: Dictionary = PlayerStats.breakdown(run.base_stats, run.effect_pool(), run.effect_levels())
	for key: String in CHARACTER_STATS:
		# a stat at 0 that no card touches (armour before equipment) is noise
		if bd.has(key) and (not bd[key]["parts"].is_empty() or not is_zero_approx(float(bd[key]["final"]))):
			stats_col.add_child(_stat_row(key, bd[key]))
	var skills_col := _column(body, "Chiêu thức", 0.0, true)
	for si: Dictionary in run.skill_info():
		skills_col.add_child(_skill_row(si))
	var side := _column(body, "Buff đang có", 300.0, false)
	if run.buffs.active.is_empty():
		side.add_child(_label("Không có buff nào.", 14, MUTED))
	for id: String in run.buffs.active:
		side.add_child(_buff_row(id))
	var cards_title := _label("Thẻ chỉ số", 20, BORDER)
	side.add_child(cards_title)
	var any := false
	for o: Dictionary in run.owned_upgrades():
		if not o["skill"]:
			side.add_child(_stat_card_row(o))
			any = true
	if not any:
		side.add_child(_label("Chưa chọn thẻ chỉ số nào.", 14, MUTED))


## A titled column inside a ScrollContainer (vertical scroll only); returns the
## VBox to fill. width 0 = take the remaining space.
func _column(parent: Container, title: String, width: float, expand: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	if width > 0.0:
		col.custom_minimum_size = Vector2(width, 0)
	if expand:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(_label(title, 20, BORDER))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	# room on the right so the scroll bar does not touch the cards
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", 14)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(inner)
	return inner


## A running buff: badge, name, seconds left, what it does.
func _buff_row(id: String) -> HBoxContainer:
	var d: Dictionary = run.buff_def(id)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ic := _icon(id, 28)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label("%s  ·  còn %d s" % [d.get("name", id), ceili(run.buffs.time_left(id))], 15, Color(d.get("color", "f2ecd8"))))
	var desc := _label(String(d.get("desc", "")), 12, MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	return h


## A stat card taken: icon, name and level, what it does now in numbers.
func _stat_card_row(o: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ic := _icon(String(o["id"]), 24)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label("%s  ·  %d/%d" % [o["name"], o["level"], o["max"]], 15, STAT_ACCENT))
	var t := _label(run.card_effect_text(String(o["id"])), 12, MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	return h


const CHARACTER_STATS := ["max_hp", "damage", "cooldown", "area", "move_speed", "regen", "magnet", "armor"]
## Icon for each stat (ui-icons), used on the sheet and in source chips.
const STAT_ICON := {"max_hp": "heart", "damage": "sword", "cooldown": "haste", "area": "reach",
	"move_speed": "boot", "regen": "regen", "magnet": "magnet", "armor": "shield"}
const WHAT_ICON := {"Sát thương": "sword", "Hồi chiêu": "haste", "Vùng": "reach", "Nhát sau": "back_slash"}


## One stat: icon, name, final value; under it the class base and one chip per
## card (card icon + amount, full text on hover).
func _stat_row(key: String, b: Dictionary) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_icon(String(STAT_ICON.get(key, "star")), 24))
	var name := _label(String(run.STAT_LABEL.get(key, key)), 16, TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name)
	var changed: bool = not b["parts"].is_empty()
	var val := _label(run._fmt_stat(key, float(b["final"])), 16, GAIN if changed else TEXT)
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(val)
	v.add_child(head)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 2)
	var base_l := _label("gốc %s" % run._fmt_stat(key, float(b["base"])), 12, MUTED)
	base_l.custom_minimum_size = Vector2(34, 0)
	chips.add_child(_indent(base_l))
	for part: Dictionary in b["parts"]:
		var amount: String = ("%+d%%" % roundi(float(part["mul"]) * 100.0)) if part.has("mul") else run.signed(float(part["add"]))
		var who := String(part["name"]) if not run.buff_def(String(part["id"])).is_empty() else "%s cấp %d" % [part["name"], part["level"]]
		chips.add_child(_chip([String(part["id"])], amount, "%s: %s %s" % [who, run.STAT_LABEL.get(key, key), amount]))
	v.add_child(chips)
	return v


## Indents a chip row under the stat name (past the 24 px icon).
func _indent(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 34)
	m.add_child(c)
	return m


## One skill: icon; name and level pips; damage / cooldown / size as icon chips
## (class-only value muted); the cards changing it as chips.
func _skill_row(si: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var st := _style(CARD, BORDER)
	st.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var icon := _icon(String(si["id"]), 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var nl := _label(String(si["name"]), 17, TEXT)
	head.add_child(nl)
	var pips := Control.new()
	var lv: int = si["level"]
	var mx: int = si["max"]
	pips.custom_minimum_size = Vector2(24 * mx, 18)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.tooltip_text = "Cấp %d/%d" % [lv, mx]
	pips.draw.connect(func() -> void: _draw_pips(pips, lv, mx, [mx], BORDER, false))
	head.add_child(pips)
	v.add_child(head)
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 18)
	nums.add_child(_chip(["sword"], "%d" % roundi(si["damage"]), "Sát thương (gốc %d)" % roundi(si["base_damage"]),
		GAIN if roundi(si["damage"]) != roundi(si["base_damage"]) else TEXT, 15, "gốc %d" % roundi(si["base_damage"])))
	nums.add_child(_chip(["haste"], "%.2f s" % si["cooldown"], "Hồi chiêu (gốc %.2f s)" % si["base_cooldown"],
		GAIN if not is_equal_approx(si["cooldown"], si["base_cooldown"]) else TEXT, 15, "gốc %.2f" % si["base_cooldown"]))
	nums.add_child(_chip(["reach"], "×%.2f" % si["size"], "Vùng", GAIN if not is_equal_approx(si["size"], 1.0) else TEXT, 15))
	v.add_child(nums)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 12)
	chips.add_theme_constant_override("v_separation", 2)
	for p: Dictionary in si["sources"]:
		# a stat card's icon already says which stat it changes; a skill card needs the second icon
		var icons := [String(p["id"])]
		if run.upgrade(String(p["id"])).get("kind") == "skill":
			icons.append(String(WHAT_ICON.get(p["what"], "star")))
		chips.add_child(_chip(icons, String(p["text"]),
			"%s cấp %d: %s %s" % [p["name"], p["level"], p["what"], p["text"]]))
	if not si["sources"].is_empty():
		v.add_child(chips)
	# statuses this skill puts on monsters now (statuses.json)
	if not si.get("statuses", []).is_empty():
		var st_row := HFlowContainer.new()
		st_row.add_theme_constant_override("h_separation", 12)
		for e: Dictionary in si["statuses"]:
			var sd: Dictionary = run.status_defs.get(String(e.get("status", "")), {})
			var secs := ""
			if e.has("time"):
				secs = "%.1f s" % float(e["time"])
			st_row.add_child(_chip([String(e.get("status", ""))], "%s %s" % [sd.get("name", e.get("status", "")), secs], String(sd.get("desc", "")), Color("ffb08a"), 13))
		v.add_child(st_row)
	return card


## A small icon + text group with a tooltip. Icons after the first are drawn
## smaller (they say which stat the first one changes).
func _chip(icons: Array, text: String, tip: String, col := MUTED, sz := 12, note := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in icons.size():
		var ic := _icon(String(icons[i]), 16 if i == 0 else 12)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var l := _label(text, sz, col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	if note != "":
		var n := _label(note, 12, MUTED)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(n)
	return h


func _icon(id: String, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = run.icon_texture(id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func show_settings() -> void:
	var root := _open("")
	root.add_child(SettingsPanel.build(func() -> void: show_pause()))


## Win / lose: time, level, kills, gold; then the damage table (each skill's
## damage with its share as a bar, hits, kills, damage per second), damage taken
## and hp healed; the two buttons on one row.
func show_end(won: bool) -> void:
	var root := _open("Vượt ải!" if won else "Thất bại")
	var t := int(run.clock)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.add_child(_icon_value("clock", "%02d:%02d" % [t / 60, t % 60]))
	row.add_child(_icon_value("star", str(run.level)))
	row.add_child(_icon_value("skull", str(run.enemies.total_kills)))
	row.add_child(_icon_value("coin", str(run.gold)))
	root.add_child(row)
	var report: Array = run.damage_report()
	if not report.is_empty():
		root.add_child(_damage_table(report))
	var total := 0.0
	for r: Dictionary in report:
		total += float(r["damage"])
	var foot := _label("Tổng sát thương %d  ·  Sát thương nhận %d  ·  Máu đã hồi %d" % [
		roundi(total), roundi(run.damage_taken), roundi(run.healed)], 14, MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(foot)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	root.add_child(buttons)
	var again := _button("Chơi lại (R)", func() -> void: run.restart())
	buttons.add_child(again)
	buttons.add_child(_button("Về sảnh", func() -> void: run.to_lobby()))
	again.call_deferred("grab_focus")


const DMG_BAR := 150.0


func _damage_table(report: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 6)
	for h in ["Chiêu", "Sát thương", "%", "Trúng", "Hạ", "DPS"]:
		var l := _label(h, 13, MUTED)
		if h != "Chiêu":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(l)
	var top := maxf(1.0, float(report[0]["damage"]))
	for r: Dictionary in report:
		var name := HBoxContainer.new()
		name.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = UiIcons.texture(r["id"])
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		name.add_child(icon)
		var nl := _label(String(r["name"]), 15, TEXT)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name.add_child(nl)
		g.add_child(name)
		# damage: bar scaled to the top row, number at its right
		var dmg := HBoxContainer.new()
		dmg.add_theme_constant_override("separation", 8)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(DMG_BAR, 24)
		var frac := float(r["damage"]) / top
		bar.draw.connect(func() -> void:
			bar.draw_rect(Rect2(0, 8, DMG_BAR, 8), PIP_LOCKED)
			bar.draw_rect(Rect2(0, 8, roundf(DMG_BAR * frac), 8), BORDER))
		dmg.add_child(bar)
		var dl := _label(_big(float(r["damage"])), 15, TEXT)
		dl.custom_minimum_size = Vector2(56, 0)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dmg.add_child(dl)
		g.add_child(dmg)
		for v in ["%d%%" % roundi(float(r["share"]) * 100.0), str(r["hits"]), str(r["kills"]), "%.1f" % float(r["dps"])]:
			var l := _label(v, 15, TEXT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			l.custom_minimum_size = Vector2(44, 0)
			g.add_child(l)
	return g


## 1234 -> "1234", 12345 -> "12.3k".
static func _big(v: float) -> String:
	return str(roundi(v)) if v < 10000.0 else "%.1fk" % (v / 1000.0)


func _icon_value(icon: String, value: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var tex := TextureRect.new()
	tex.texture = UiIcons.texture(icon)
	tex.custom_minimum_size = Vector2(32, 32)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(tex)
	h.add_child(_label(value, 24, TEXT))
	return h


## A modal: dimmed screen, centred column with the title. boxed puts the column
## on a panel so it stays readable over a crowded field (pause, win, lose).
func _open(title: String, boxed := true) -> VBoxContainer:
	hide_all()
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_box = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	if boxed:
		var panel := PanelContainer.new()
		var ps := _style(Color(0.09, 0.08, 0.13, 0.94))
		ps.content_margin_left = 40
		ps.content_margin_right = 40
		ps.content_margin_top = 24
		ps.content_margin_bottom = 28
		panel.add_theme_stylebox_override("panel", ps)
		center.add_child(panel)
		panel.add_child(root)
	else:
		center.add_child(root)
	if title != "":
		var l := _label(title, 40, BORDER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(l)
	return root


func _label(s: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(s: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(260, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", _style(CARD))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER))
	b.pressed.connect(cb)
	return b


func _style(bg: Color, border := BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s
