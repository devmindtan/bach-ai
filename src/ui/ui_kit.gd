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
const RARITY := {"common": Color("e8e2d0"), "rare": Color("6fb7ff"), "epic": Color("c38df5"), "legendary": Color("f2b64a")}
const RARITY_ORDER := ["common", "rare", "epic", "legendary"]
const RARITY_NAME := {"common": "Thường", "rare": "Hiếm", "epic": "Sử thi", "legendary": "Huyền thoại"}


static func style(bg: Color, pad: int, border := GOLD, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(pad)
	return s


## Card / item frame of rarity [param tier] (design/card-rarity.md "Khung theo bậc", user 2026-11-20): every tier
## differs in more than colour: Thường thin grey, Hiếm blue 2 px, Sử thi purple 3 px with a soft glow,
## Huyền thoại gold 3 px with a strong warm glow and a gold-tinted face. [param lit] = in use / owned (dim
## otherwise); [param on] = selected (white border, glow kept).
##
## Example:
##   b.add_theme_stylebox_override("normal", UiKit.rarity_style("epic", true, false))
static func rarity_style(tier: String, lit := true, on := false, pad := 6) -> StyleBoxFlat:
	var t := RARITY_ORDER.find(tier)
	var col: Color = RARITY.get(tier, TEXT) if t > 0 else Color("8a8478")
	var s := StyleBoxFlat.new()
	s.bg_color = [Color("26222f"), Color("1c2638"), Color("2a1f3a"), Color("3a2c18")][maxi(0, t)]
	if not lit:
		s.bg_color = s.bg_color.darkened(0.35)
		col = col.darkened(0.45)
	s.border_color = Color.WHITE if on else col
	s.set_border_width_all([2, 2, 3, 3][maxi(0, t)] + (1 if on else 0))
	s.set_corner_radius_all([3, 4, 6, 8][maxi(0, t)])
	s.set_content_margin_all(pad)
	if t >= 2 and lit:
		s.shadow_color = Color(col, 0.45 if t == 2 else 0.6)
		s.shadow_size = 4 if t == 2 else 8
	return s


## The rarity gem icon (ui-icons rarity_<tier>: round / rhombus / pentagon / star), [param px] on screen.
static func rarity_gem(tier: String, px := 16.0) -> TextureRect:
	return icon("rarity_" + (tier if RARITY.has(tier) else "common"), px)


## Gem + tier name in its colour, for subtitles and tooltips ("◆ Hiếm").
static func rarity_badge(tier: String, size := 13) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rarity_gem(tier, 16.0))
	var l := label(String(RARITY_NAME.get(tier, tier)), size, RARITY.get(tier, TEXT))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


## Gold corner brackets for Huyền thoại (and purple ones for Sử thi) inside [param c], a frame ornament
## that commons and rares do not get. Anchored, so they follow c's size.
static func rarity_corners(c: Control, tier: String) -> void:
	var t := RARITY_ORDER.find(tier)
	if t < 2:
		return
	var col: Color = RARITY[tier].lightened(0.25)
	var arm := 10.0 if t == 3 else 7.0
	for corner in range(1, 4):   # no top-left bracket: the rarity gem sits there everywhere
		var right := corner % 2 == 1
		var bottom := corner >= 2
		for horiz in [true, false]:
			var r := ColorRect.new()
			r.color = col
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var w := arm if horiz else 2.0
			var h := 2.0 if horiz else arm
			r.anchor_left = 1.0 if right else 0.0
			r.anchor_right = r.anchor_left
			r.anchor_top = 1.0 if bottom else 0.0
			r.anchor_bottom = r.anchor_top
			var x0 := -4.0 - w if right else 4.0
			var y0 := -4.0 - h if bottom else 4.0
			r.offset_left = x0
			r.offset_right = x0 + w
			r.offset_top = y0
			r.offset_bottom = y0 + h
			c.add_child(r)


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


## Puts icon [param id] (whole-pixel [param scale], nearest) left of [param b]'s text (user 2026-11-20:
## the lobby buttons get their own icon set, card-icons nav_*).
##
## Example:
##   UiKit.with_icon(UiKit.button("Bộ thẻ", open_deck), "nav_deck")
static func with_icon(b: Button, id: String, scale := 1) -> Button:
	var t := UiIcons.texture(id)
	if t == null:
		return b
	var img := t.get_image()
	if scale > 1:
		img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	b.icon = ImageTexture.create_from_image(img)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_constant_override("h_separation", 8)
	return b


## Puts the vector icon res://assets/icons/lobby/<id>.svg (game-icons.net, CC BY 3.0, assets/credits) on
## [param b], [param px] wide, smooth-filtered (user 2026-11-21: the 24 px pixel icons looked fake on the
## lobby buttons; use real icon images there).
static func with_vector_icon(b: Button, id: String, px := 40) -> Button:
	var path := "res://assets/icons/lobby/%s.svg" % id
	if not ResourceLoader.exists(path):
		push_warning("UiKit: lobby icon %s missing" % path)
		return b
	b.icon = vector_texture(path, px)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.add_theme_constant_override("h_separation", 10)
	return b


static var _vector_cache := {}


## The SVG at [param path] rendered down to [param px] square (Lanczos, cached): a texture of the size it is
## shown at, so layouts treat it like the pixel icons (a 512 px SVG texture kept its own size in a Button).
static func vector_texture(path: String, px: int) -> Texture2D:
	var key := "%s@%d" % [path, px]
	if not _vector_cache.has(key):
		var img := (load(path) as Texture2D).get_image()
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_vector_cache[key] = ImageTexture.create_from_image(img)
	return _vector_cache[key]


## A node / tooltip icon: the vector icon res://assets/icons/<folder>/<vector>.svg when [param vector] is set
## (smooth, any size), else the pixel icon [param pixel] (user 2026-11-21: vector icons in the skill tree).
static func node_icon(vector: String, pixel: String, px: float, folder := "tree") -> TextureRect:
	var path := "res://assets/icons/%s/%s.svg" % [folder, vector]
	if vector == "" or not ResourceLoader.exists(path):
		return icon(pixel, px)
	var t := TextureRect.new()
	t.texture = vector_texture(path, int(px))
	t.custom_minimum_size = Vector2(px, px)
	t.size = t.custom_minimum_size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## One row of card odds: each tier's gem and its share ([param weights] in tier order, they add to 100).
static func rarity_odds_row(weights: Array, size := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in RARITY_ORDER.size():
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.add_child(rarity_gem(RARITY_ORDER[t], 16.0))
		var l := label("%s %s%%" % [RARITY_NAME[RARITY_ORDER[t]], _pct(float(weights[t]))], size, RARITY[RARITY_ORDER[t]])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(l)
		h.add_child(cell)
	return h


static func _pct(v: float) -> String:
	var r := snappedf(v, 0.1)   # one decimal at most; whole numbers without ",0"
	return str(roundi(r)) if absf(r - roundf(r)) < 0.05 else ("%.1f" % r).replace(".", ",")


## The level-up card odds table (user 2026-11-21): one row per run level in [param levels], a column per tier.
static func rarity_odds_table(rr: CardRarity, levels: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 1 + RARITY_ORDER.size()
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 6)
	g.add_child(label("Cấp", 14, MUTED))
	for t: String in RARITY_ORDER:
		var hd := HBoxContainer.new()
		hd.add_theme_constant_override("separation", 4)
		hd.add_child(rarity_gem(t, 16.0))
		hd.add_child(label(String(RARITY_NAME[t]), 14, RARITY[t]))
		g.add_child(hd)
	for lv: int in levels:
		g.add_child(label(str(lv), 15, TEXT))
		var w := rr.level_weights(lv)
		for t in RARITY_ORDER.size():
			var c := label("%s%%" % _pct(float(w[t])), 15, RARITY[RARITY_ORDER[t]])
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g.add_child(c)
	return g


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
## The largest whole multiple of [param frame] that fits in [param px] (at least
## one frame): pixel icons stretched by x5.25 drew pixels of uneven width ("méo").
static func snap_icon(px: float, frame: float) -> float:
	if frame <= 0.0:
		return px
	return maxf(1.0, floorf(px / frame)) * frame


## A card's icon (vector for stat cards, UiIcons.card_texture), smooth-filtered when vector.
static func card_icon(id: String, px := 20.0) -> TextureRect:
	var t := icon(id, px)
	var tex := UiIcons.card_texture(id)
	if tex != t.texture:
		t.texture = tex
		t.custom_minimum_size = Vector2(px, px)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return t


static func icon(id: String, px := 20.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiIcons.texture(id)
	var side := snap_icon(px, t.texture.get_size().x) if t.texture != null else px
	t.custom_minimum_size = Vector2(side, side)
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
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	Tip.attach(row, tip)
	row.add_child(icon(icon_id, 20.0))
	var l := label(value, font, TEXT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row


## The first visible, enabled Button under [param root] in tree order, or null: the control a screen focuses
## when it opens, so a gamepad (D-pad + A) can use it (roadmap J5, 2026-11-23).
static func first_enabled_button(root: Node) -> Button:
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b.visible and not b.disabled:
			return b
	return null
