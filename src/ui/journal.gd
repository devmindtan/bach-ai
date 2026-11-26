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
