class_name UiKit
extends RefCounted
## The front end's shared look (title, character select, lobby; design/ux/front-end.md):
## colours, labels with a drop shadow, framed buttons (one "primary" per screen),
## panels, a dark backdrop for modals, icon + value pairs.
##
## Example:
##   var b := UiKit.button("Chơi", func() -> void: start(), Vector2(420, 64), 26, UiKit.PRIMARY)
##   col.add_child(UiKit.label("Chọn nhân vật", 32, UiKit.GOLD))

const GOLD := Color("c9a65a")
const TEXT := Color("f2ecd8")
const MUTED := Color("b9b2a0")
const PANEL := Color("2a2438")
const PANEL_DARK := Color("1d1828")
const PANEL_HOVER := Color("3b3352")
const PRIMARY := Color("8a3a2e")        # the one dominant action of a screen
const PRIMARY_HOVER := Color("a8483a")
const DANGER := Color("4a2424")
const SHADOW := Color(0, 0, 0, 0.7)


static func style(bg: Color, pad: int, border := GOLD, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


## A framed button; [param bg] PRIMARY for the screen's main action. Focus and
## hover get a white frame so the keyboard / pad position is always visible.
static func button(text: String, cb: Callable, min_size := Vector2(0, 44), font := 18, bg := PANEL) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	var hover := PRIMARY_HOVER if bg == PRIMARY else PANEL_HOVER
	b.add_theme_stylebox_override("normal", style(bg, 8))
	b.add_theme_stylebox_override("hover", style(hover, 8, Color.WHITE))
	b.add_theme_stylebox_override("focus", style(hover, 8, Color.WHITE))
	b.add_theme_stylebox_override("pressed", style(hover, 8, Color.WHITE))
	b.add_theme_stylebox_override("disabled", style(PANEL_DARK, 8, Color("4a4458")))
	b.pressed.connect(cb)
	return b


static func panel(bg := PANEL, pad := 16, border := GOLD) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, pad, border))
	return p


## Darkens the screen behind a modal: the full-screen [param center] draws a dark
## rect before its children and stops clicks reaching what is behind.
static func dim(center: Control) -> void:
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	center.draw.connect(func() -> void: center.draw_rect(Rect2(Vector2.ZERO, center.size), Color(0, 0, 0, 0.6)))


## A ui-icons icon at [param px] pixels, crisp.
static func icon(id: String, px := 20.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiIcons.texture(id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Icon + value on one centre line; the tooltip names it.
static func stat(icon_id: String, value: String, tip: String, font := 17) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.tooltip_text = tip
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(icon(icon_id, 20.0))
	var l := label(value, font, TEXT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row
