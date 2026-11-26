class_name Journal
extends RefCounted
## The "Sổ hành trình" look every menu shares (design-web/games/bach-ai/journal.css, user 2026-11-26 approved the set):
## a leather journal open on a wooden desk, ink on paper, ruled ledgers, red-ink notes, a wax seal for the main action
## and bookmark ribbons on the book's edge.
##
## Example (in a Node2D's _draw / a Control builder):
##   Journal.draw_desk(self, size); Journal.draw_book(self, Journal.BOOK)
##   page.add_child(Journal.ink("Trang bị", 48)); page.add_child(Journal.ledger("heart", "Máu", "118"))

const BOOK := Rect2(70, 40, 1100, 640)   # the open book on a 1280 x 720 screen; each page is half of it
const INK := Color("3a2414")
const INK_RED := Color("8a2a1a")
const INK_SOFT := Color("5a3a24")
const PAPER := Color("e8d8b0")
const PAPER_DARK := Color("c8b088")
const SKETCH := Color("ddcca0")
const EDGE := Color("8a6a3a")
const DOTS := Color("a08060")
const GOLD := Color("ffd36b")
const SEAL := Color("a0281c")


## The desk: planks in two browns.
static func draw_desk(ci: CanvasItem, size: Vector2) -> void:
	for k in int(size.y / 6.0) + 1:
		ci.draw_rect(Rect2(0, k * 6.0, size.x, 6.0), Color("3a2414") if k % 2 == 0 else Color("42291a"))


## The open book: leather cover, two paper pages with a shaded gutter and a dashed inner frame.
static func draw_book(ci: CanvasItem, book: Rect2) -> void:
	ci.draw_rect(book.grow(14), Color("2a0c08"))
	ci.draw_rect(book.grow(10), Color("5a1a14"))
	ci.draw_rect(Rect2(book.position + Vector2(0, book.size.y + 10), Vector2(book.size.x, 10)), Color(0, 0, 0, 0.45))
	var half := book.size.x * 0.5
	for side in 2:
		draw_page(ci, Rect2(book.position + Vector2(half * side, 0), Vector2(half, book.size.y)), side)


## One paper page; [param gutter] 0 = left page (shade on its right), 1 = right page, -1 = a loose sheet.
static func draw_page(ci: CanvasItem, pg: Rect2, gutter := -1) -> void:
	ci.draw_rect(pg, PAPER)
	ci.draw_rect(pg, EDGE, false, 4.0)
	if gutter >= 0:
		var gx := pg.end.x - 12.0 if gutter == 0 else pg.position.x
		ci.draw_rect(Rect2(gx, pg.position.y + 4, 12, pg.size.y - 8), PAPER_DARK)
	var inner := pg.grow(-12)
	var dash := Color("b89a6a")
	var y := inner.position.y
	while y < inner.end.y:
		ci.draw_rect(Rect2(inner.position.x, y, 2, 6), dash)
		ci.draw_rect(Rect2(inner.end.x - 2, y, 2, 6), dash)
		y += 12.0
	var x := inner.position.x
	while x < inner.end.x:
		ci.draw_rect(Rect2(x, inner.position.y, 6, 2), dash)
		ci.draw_rect(Rect2(x, inner.end.y - 2, 6, 2), dash)
		x += 12.0


## A framed sketch box on the page (portraits, item cells).
static func draw_sketch(ci: CanvasItem, r: Rect2, on := false) -> void:
	ci.draw_rect(r, INK if on else SKETCH)
	ci.draw_rect(r, GOLD if on else INK, false, 4.0 if on else 3.0)


## Ink text (no outline: the page is light).
static func ink(s: String, sz: int, c: Color = INK) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A ruled ledger line: optional icon, name, value, a dotted rule under it.
static func ledger(icon: String, name: String, value: String, sz := 21, value_col: Color = INK) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if icon != "":
		var ic := TextureRect.new()
		ic.texture = UiIcons.texture(icon)
		ic.custom_minimum_size = Vector2(22, 22)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var n := ink(name, sz)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	row.add_child(ink(value, sz, value_col))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	v.add_child(dotted())
	return v


## A dotted rule (a ledger's underline, a contents leader).
static func dotted(sz := 10) -> Label:
	var dots := ink("·".repeat(200), sz, DOTS)
	dots.clip_text = true
	dots.custom_minimum_size = Vector2(10, 8)
	return dots


## A note: a red title in ink, then its text.
static func note(title: String, text: String, sz := 18) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", sz)
	l.add_theme_color_override("default_color", INK)
	l.text = "[color=#%s][font_size=%d]%s.[/font_size][/color] %s" % [INK_RED.to_html(false), sz + 3, title, text]
	return l


## The wax seal: the screen's main action.
static func seal(text: String, size := Vector2(260, 68), font := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", font)
	b.custom_minimum_size = size
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("d0402a") if st in ["hover", "focus", "pressed"] else (Color("6a4a3a") if st == "disabled" else SEAL)
		sb.border_color = GOLD if st in ["focus", "hover"] else Color("5a0c08")
		sb.set_border_width_all(4)
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_offset = Vector2(0, 4)
		b.add_theme_stylebox_override(st, sb)
	for k in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color("fff2d0") if k != "font_color" else Color("ffe0b0"))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


## A bookmark ribbon on the book's edge: an icon tab (assets/icons/lobby/<icon>.svg in paper colour); focus pulls it out.
static func ribbon(icon: String, col: Color, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(54, 52)
	b.tooltip_text = tip
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.12) if st != "normal" else col
		sb.border_color = GOLD if st in ["focus", "hover"] else Color(0, 0, 0, 0.4)
		sb.set_border_width_all(3)
		b.add_theme_stylebox_override(st, sb)
	b.icon = UiKit.vector_texture("res://assets/icons/lobby/%s.svg" % icon, 30)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("icon_normal_color", PAPER)
	b.add_theme_color_override("icon_focus_color", Color.WHITE)
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.focus_entered.connect(func() -> void:
		b.custom_minimum_size.x = 68
		b.size.x = 68)
	b.focus_exited.connect(func() -> void:
		b.custom_minimum_size.x = 54
		b.size.x = 54)
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


## Ink for a colour a dark-theme screen (UiKit) used on light text: light → ink, muted → soft ink, gold → red ink,
## greens/blues/purples keep their hue darkened so they read on paper.
static func ink_of(c: Color) -> Color:
	if c.a < 0.05:
		return c
	var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	if lum < 0.4:   # already ink (a Journal label inside the tree): keep it
		return c
	var sat := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
	if sat < 0.12:   # greys
		return INK if lum > 0.8 else (INK_SOFT if lum > 0.55 else DOTS)
	if c.g > c.r + 0.1 and c.g > c.b:
		return Color("2a7a3a")
	if c.b > c.r + 0.1:
		return Color("3a6aaa") if c.g > c.r else Color("7a3ab8")
	if c.r > 0.9 and c.g < 0.7:
		return INK_RED
	return INK_RED if lum > 0.55 else INK_SOFT


static func _flat(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## Turns a UiKit (dark) control tree into ink on paper, in place: labels in ink without shadows, panels as sketch
## boxes, buttons as sketch cells (a chosen one, drawn with a white frame by UiKit, ink-filled; the screen's red
## main action a wax seal). Example: Journal.restyle(my_panel) after building it with UiKit.
static func restyle(n: Node) -> void:
	if n is Label:
		var l := n as Label
		l.add_theme_color_override("font_color", ink_of(l.get_theme_color("font_color")))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		l.add_theme_constant_override("outline_size", 0)
	elif n is RichTextLabel:
		var r := n as RichTextLabel
		r.add_theme_color_override("default_color", INK)
	elif n is Button:
		var b := n as Button
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		var main := sb != null and sb.bg_color.r > sb.bg_color.g + 0.15 and sb.bg_color.r > 0.4
		var chosen := sb != null and sb.border_color.v > 0.95 and sb.border_color.s < 0.1
		for st in ["normal", "hover", "focus", "pressed", "disabled"]:
			var lit: bool = st in ["hover", "focus", "pressed"]
			var s2: StyleBoxFlat
			if main:
				s2 = _flat(Color("6a4a3a") if st == "disabled" else (Color("d0402a") if lit else SEAL), GOLD if lit else Color("5a0c08"), 4)
			else:
				s2 = _flat(INK if chosen else (Color(0, 0, 0, 0) if st == "disabled" else SKETCH), GOLD if (lit or chosen) else (DOTS if st == "disabled" else INK), 3 if (lit or chosen) else 2)
			b.add_theme_stylebox_override(st, s2)
		var fc := Color("ffe0b0") if main else (PAPER if chosen else INK)
		b.add_theme_color_override("font_color", fc)
		b.add_theme_color_override("font_focus_color", Color("fff2d0") if main else (GOLD if chosen else INK_RED))
		b.add_theme_color_override("font_hover_color", Color("fff2d0") if main else (GOLD if chosen else INK_RED))
		b.add_theme_color_override("font_pressed_color", Color("fff2d0") if main else INK_RED)
		b.add_theme_color_override("font_disabled_color", DOTS)
		b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		if chosen:   # its labels sit on ink: paper text
			for c in b.find_children("*", "Label", true, false):
				(c as Label).add_theme_color_override("font_color", PAPER)
				(c as Label).add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			return
	elif n is PanelContainer:
		var p := n as PanelContainer
		var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			var s2 := sb.duplicate() as StyleBoxFlat
			s2.bg_color = Color(SKETCH, 0.55)
			s2.border_color = ink_of(sb.border_color) if sb.border_color.s > 0.3 else INK
			s2.set_border_width_all(maxi(2, sb.border_width_left))
			s2.set_corner_radius_all(0)
			s2.shadow_size = 0
			p.add_theme_stylebox_override("panel", s2)
	elif n is LineEdit:
		var e := n as LineEdit
		var line := _flat(Color(0, 0, 0, 0), INK, 0)
		line.border_width_bottom = 3
		for st in ["normal", "focus"]:
			e.add_theme_stylebox_override(st, line)
		e.add_theme_color_override("font_color", INK)
		e.add_theme_color_override("font_placeholder_color", DOTS)
	for c in n.get_children():
		restyle(c)


## A loose sheet of the journal (overlays over a journal screen: settings, odds): paper, an edge, a margin.
static func sheet_style(margin := 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = EDGE
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_offset = Vector2(0, 8)
	sb.shadow_size = 2
	sb.set_content_margin_all(margin)
	return sb


## A text bookmark ribbon out of the book's right edge (journal.css .ribbon): vertical words on [param col];
## the open one wider with a gold outline. Its height fits the words (user 2026-11-26: a short word left a gap).
## [param lock_tip] != "": a locked ribbon (greyed, a padlock, not pressable; the tip says what opens it).
static func text_ribbon(text: String, col: Color, on: bool, lock_tip := "") -> Button:
	var locked := lock_tip != ""
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	b.disabled = locked
	b.tooltip_text = lock_tip
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var top := 30.0 if locked else 12.0   # room for the padlock
	b.custom_minimum_size = Vector2(74 if on else 52, ceilf(top + tw + 12.0))
	b.size = b.custom_minimum_size
	var c := Color(0.32, 0.27, 0.22) if locked else col
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c.lightened(0.15) if (on or st in ["hover", "focus", "pressed"]) else c
		sb.border_color = GOLD if (on or st in ["hover", "focus"]) else Color(0, 0, 0, 0.4)
		sb.set_border_width_all(3)
		b.add_theme_stylebox_override(st, sb)
	if locked:
		var ic := TextureRect.new()
		ic.texture = UiKit.vector_texture("res://assets/icons/lobby/nav_lock.svg", 18)
		ic.position = Vector2((b.custom_minimum_size.x - 18.0) * 0.5, 7)
		ic.size = Vector2(18, 18)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
	var l := ink(text, 20, Color("a89a88") if locked else Color("f3e6c8"))
	l.rotation = PI / 2.0   # vertical-rl: the words read top to bottom, centred across the ribbon
	l.position = Vector2(b.custom_minimum_size.x * 0.5 + font.get_height(20) * 0.5, top)
	b.add_child(l)
	if not locked:
		b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


## A column of text ribbons on the book's right edge, under the back tab; [param pick] is called with the pressed
## index. [param locks]: per ribbon, "" or the tip of a locked one.
static func ribbons(root: Control, names: Array, cols: Array, open: int, pick: Callable, locks: Array = []) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(BOOK.end.x + 14, BOOK.position.y + 118)   # out of the cover, under the back tab
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	for i in names.size():
		var r := text_ribbon(String(names[i]), cols[i % cols.size()], i == open, String(locks[i]) if i < locks.size() else "")
		r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		r.pressed.connect(func() -> void: pick.call(i))
		v.add_child(r)
	return v


## "Trở lại" (design-web journal.css .back-tab, user 2026-11-26): an icon tab like the lobby's corner tabs, at the top
## of the book's right edge; pressing it does what Esc does ([param back]). Text ribbons start under it.
static func back_tab(root: Control, back: Callable) -> Button:
	var b := ribbon("nav_back", Color("7a5a3a"), "Trở lại (Esc)")
	b.position = Vector2(1184, 96)
	b.focus_mode = Control.FOCUS_NONE   # the page owns the arrows; Esc and the mouse use it
	b.pressed.connect(back)
	root.add_child(b)
	return b
