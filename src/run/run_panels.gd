class_name RunPanels
extends Control
## Modal panels of a run: level-up (three upgrade cards, click or 1/2/3),
## pause, and the win / lose screen. Calls back into the run node.
##
## Example:
##   panels.show_level_up(["sharpen", "haste", "reach"])

const DIM := Color(0, 0, 0, 0.6)
# The journal palette (design-web screen-run-journal / screen-hud-journal, user 2026-11-27): ink on a paper sheet.
const CARD := Color("ddcca0")         # a sketch cell
const CARD_HOVER := Color("efe2bf")
const BORDER := Color("8a2a1a")       # red ink: titles, skill accents, frames
const TEXT := Color("3a2414")         # ink
const MUTED := Color("5a3a24")        # soft ink
const STAT_ACCENT := Color("3a6aaa")  # stat cards; skills use the red BORDER
const GAIN := Color("2a7a3a")         # the value after the pick
const MILESTONE := Color("c0801a")
const PIP_LOCKED := Color("c8b088")   # level not reached yet (paper dark, with a visible edge)
const PIP_EDGE := Color("a08060")

var banish_mode := false   # Loại armed: the next card clicked is banished
var _flipped: Array[String] = []   # the hand that already flipped in
var _flip_tweens: Array = []       # [tween, card, back] while cards flip
var _flip_shot := "--flip-shot" in OS.get_cmdline_user_args()   # shots: flip even in the fixed preview
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


## The level-up panel last shown (cards, skill pick or milestone), to come back to
## from the character sheet or the hidden view (design/ux/level-up.md).
var _reshow := Callable()


func reshow() -> void:
	if _reshow.is_valid():
		_reshow.call()


## Level-up with the cards hidden: only a strip on top, the field stays visible.
## The two level-up view buttons under the title (design/ux/level-up.md): hide
## the panel to see the field, open the character sheet. Not focusable, so the
## keys keep moving between the cards only.
func _view_buttons(root: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	for b: Array in [["Ẩn bảng" + UiKit.hint("H"), "hidden"], ["Nhân vật" + UiKit.hint("Tab"), "character"]]:
		var view: String = b[1]
		var btn := Journal.link(String(b[0]), 18)   # red underlined links, like the web sheet
		btn.pressed.connect(func() -> void: run.toggle_level_view(view))
		btn.focus_mode = Control.FOCUS_NONE
		row.add_child(btn)


func show_peek() -> void:
	hide_all()
	var strip := PanelContainer.new()
	var ps := Journal.sheet_style(12)
	ps.content_margin_left = 20
	ps.content_margin_right = 20
	ps.content_margin_top = 8
	ps.content_margin_bottom = 8
	strip.add_theme_stylebox_override("panel", ps)
	strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	strip.offset_top = 70
	add_child(strip)
	_box = strip
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	strip.add_child(row)
	var l := _label("Đang xem chiến trường", 18, TEXT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	# red links like the level-up sheet: the strip stays narrow, clear of the HUD slips (it touched the hp slip, 2026-11-27)
	var back_btn := Journal.link("Hiện thẻ" + UiKit.hint("H"), 18)
	back_btn.pressed.connect(func() -> void: run.toggle_level_view("hidden"))
	row.add_child(back_btn)
	var sheet := Journal.link("Nhân vật" + UiKit.hint("Tab"), 18)
	sheet.pressed.connect(func() -> void: run.toggle_level_view("character"))
	sheet.focus_mode = Control.FOCUS_NONE
	row.add_child(sheet)
	back_btn.call_deferred("grab_focus")


func hide_all() -> void:
	if _box != null:
		_box.queue_free()
		_box = null


## Level-up: three cards. Each shows the icon, kind and level, a row of level
## pips (owned / the one you get / still locked, milestones drawn as diamonds),
## the milestone reached by this pick, the real before -> after numbers, and the
## description. Content reads top-down from the top of the card.
func show_level_up(ids: Array[String], title := "Lên cấp! Chọn một") -> void:
	_reshow = func() -> void: show_level_up(ids, title)
	if ids != _flipped:
		banish_mode = false   # a new hand: Loại is not armed
	var root := _open(title, false)
	_view_buttons(root)
	if title.begins_with("Lên cấp") and run.rarity != null:   # this level's card odds (user 2026-11-21)
		var odds := UiKit.rarity_odds_row(run.rarity.level_weights(run.level), 13)
		Journal.restyle(odds)   # tier names in their ink on paper
		root.add_child(odds)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)
	for i in ids.size():
		row.add_child(_upgrade_card(i, ids[i]))
	_fit_cards.call_deferred(row)
	_action_buttons(root)
	if ids != _flipped:   # a new hand flips in; the same hand shown again (Tab, Ẩn bảng) does not
		_flipped = ids.duplicate()
		if not Prefs.current().is_fixed() or _flip_shot:
			_flip_in.call_deferred(row)


## Đổi / Loại / Bỏ qua under the cards (6C.3): each with its key and the charges left; a spent one is
## disabled. Loại arms banish mode: the cards turn red-framed and the next card clicked leaves the deck.
func _action_buttons(root: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	var gold := int(run.cfg.get("level_actions", {}).get("skip_gold", 0))
	var acts := [
		["Đổi%s  ×%d" % [UiKit.hint("R", "R-reroll"), run.rerolls], run.rerolls, func() -> void: run.reroll(), "Đổi cả 3 thẻ lấy 3 thẻ khác."],
		[("Chọn thẻ để loại…" if banish_mode else "Loại%s  ×%d" % [UiKit.hint("X"), run.banishes]), run.banishes, func() -> void: toggle_banish(), "Bỏ hẳn một thẻ khỏi bộ thẻ đến hết trận, rồi đổi thẻ."],
		["Bỏ qua  ×%d  · +%d vàng" % [run.skips, gold], run.skips, func() -> void: run.skip_level(), "Không lấy thẻ lần này, nhận vàng."]]
	for a: Array in acts:
		var btn := _button(String(a[0]), a[2])
		btn.custom_minimum_size = Vector2(230, 40)
		btn.focus_mode = Control.FOCUS_NONE
		btn.disabled = int(a[1]) <= 0
		Tip.attach(btn, String(a[0]).get_slice("  ", 0), String(a[3]))
		row.add_child(btn)


## Arms / disarms Loại (banish mode) and redraws the hand.
func toggle_banish() -> void:
	if run.banishes <= 0:
		return
	banish_mode = not banish_mode
	if _reshow.is_valid():
		_reshow.call()


## Level-up cards flip in from their backs one after another (6D.2, CardFlip); any press finishes them.
func _flip_in(row: HBoxContainer) -> void:
	CardFlip.finish(_flip_tweens)
	_flip_tweens = CardFlip.flip_in(row.get_children(), [], [], [])


## Ends every running card flip at once (the face up, full width).
func finish_flip() -> bool:
	return CardFlip.finish(_flip_tweens)


func _input(event: InputEvent) -> void:
	if _flip_tweens.is_empty():
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		if finish_flip():
			get_viewport().set_input_as_handled()   # this press only skips the flip, it picks nothing


## A filler card (Túi vàng / Linh đan): plain, muted, its gift in one line.
func _filler_card(i: int, id: String, u: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 180)
	b.focus_mode = Control.FOCUS_ALL
	var muted := Color("a08060")
	b.add_theme_stylebox_override("normal", _style(CARD, muted))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER, muted))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER, Journal.GOLD))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER, Journal.GOLD))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -12
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	b.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UiKit.icon(String(u.get("icon", "coin")), 48.0))
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(_label("%d. %s" % [i + 1, u.get("name", id)], 20, TEXT))
	names.add_child(_label("LẤP CHỖ  ·  bộ thẻ hết thẻ hợp", 13, muted))
	head.add_child(names)
	v.add_child(head)
	var d := _label(String(u.get("desc", "")), 14, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(270, 0)
	v.add_child(d)
	var idx := i
	b.pressed.connect(func() -> void: run.choose(idx))
	if i == 0:
		b.call_deferred("grab_focus")
	return b


## A count card (Thêm đòn / Thêm phép): pick the one skill that gets +1 count.
## Each card: the skill's icon, name, its count now -> after.
func show_skill_pick(card_name: String, ids: Array[String]) -> void:
	_reshow = func() -> void: show_skill_pick(card_name, ids)
	var root := _open("%s: chọn một chiêu để +1 số lượng" % card_name, false)
	_view_buttons(root)
	var sub := _label("Chỉ chiêu bạn chọn được thêm; các chiêu khác giữ nguyên.", 16, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 14)
	row.custom_minimum_size = Vector2(1100, 0)
	root.add_child(row)
	for i in ids.size():
		var b := _skill_pick_card(ids[i], func() -> void: run.choose(i))
		row.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")


## One skill in the count-card pick: its icon, name and level, and the count now -> after.
func _skill_pick_card(sid: String, pick: Callable) -> Button:
	var u: Dictionary = run.upgrade(sid)
	var now: int = run.skill_count_now(sid)
	var own := int(run.skill_extra.get(sid, 0))
	var b := Button.new()
	b.custom_minimum_size = Vector2(340, 100)
	b.add_theme_stylebox_override("normal", _style(CARD))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER, Journal.GOLD))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER, Journal.GOLD))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER, Journal.GOLD))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := _icon(String(u.get("icon", sid)), 56)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(_label(String(u.get("name", sid)), 20, MILESTONE))
	v.add_child(_label("Cấp %d%s" % [int(run.levels.get(sid, 0)), ("  ·  đã thêm +%d" % own) if own > 0 else ""], 13, MUTED))
	var num := HBoxContainer.new()
	num.add_theme_constant_override("separation", 8)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(num)
	num.add_child(_label("×%d" % now, 20, TEXT))
	num.add_child(_label("→", 20, MUTED))
	num.add_child(_label("×%d" % (now + 1), 20, GAIN))
	for c in num.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in v.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("sfx", "card_pick")   # Sfx: a card, not a plain click
	b.pressed.connect(pick)
	return b


## Level milestone (7/14/21): one of three rewards for the rest of this run only
## (design/progression.md). Keys 1-3 or a click pick, like a level-up.
func show_milestone_pick(level: int, ids: Array[String]) -> void:
	_reshow = func() -> void: show_milestone_pick(level, ids)
	var root := _open("Mốc cấp %d! Chọn một phần thưởng" % level, false)
	_view_buttons(root)
	var sub := _label("Chỉ có tác dụng trong trận này.", 16, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)
	for i in ids.size():
		var info: Dictionary = run.milestones.info(ids[i], run.pool.get("upgrades", []))
		var b := _milestone_choice(info, func() -> void: run.choose(i))
		row.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")


## A Button does not grow with its children: once laid out, give every card the
## height of the tallest content so no text runs past the frame and the row is even.
func _fit_cards(row: HBoxContainer) -> void:
	var h := 0.0
	for b in row.get_children():
		for v in b.get_children():   # the content box, wherever it sits (frame ornaments are children too)
			if v is VBoxContainer:
				var c := v as Control   # measured fresh (the combined size is cached until the next layout pass)
				h = maxf(h, maxf(c.get_minimum_size().y, c.custom_minimum_size.y) + 24.0)
	for b: Control in row.get_children():
		b.custom_minimum_size.y = maxf(180.0, h)


func _upgrade_card(i: int, id: String) -> Button:
	var u: Dictionary = run.upgrade(id)
	if String(u.get("kind", "")) == "filler":   # design/card-rarity.md: the deck had nothing for this slot
		return _filler_card(i, id, u)
	var pv: Dictionary = run.upgrade_preview(id)
	var skill: bool = u.get("kind") == "skill"
	var tier := String(u.get("rarity", "common"))
	# the rarity frames the card (design/card-rarity.md); commons keep the skill / stat colour
	var accent: Color = Color("6a6a6a") if tier == "common" else Journal.ink_of(UiKit.RARITY.get(tier, BORDER))   # commons plain, rarer cards in their colour
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 180)   # grown to the tallest card by _fit_cards
	b.focus_mode = Control.FOCUS_ALL
	# journal sketch card (design-web run-levelup-full): sketch paper framed in ink (rarer tiers in their ink); focused:
	# lighter paper, a gold frame
	b.add_theme_stylebox_override("normal", _style(CARD, TEXT if tier == "common" else accent))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER, TEXT if tier == "common" else accent))
	for st in ["focus", "pressed"]:
		var on := _style(CARD_HOVER, Journal.GOLD)
		on.set_border_width_all(5)
		b.add_theme_stylebox_override(st, on)
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
	var ts := _style(Color("e8d8b0"), accent)
	ts.set_content_margin_all(4)
	tile.add_theme_stylebox_override("panel", ts)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = run.icon_texture(id)
	if pale_icon(icon.texture):
		icon.modulate = INK_GLYPH
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
	var kind := ("CHIÊU" if skill else "CHỈ SỐ") + "  ·  " + String(UiKit.RARITY_NAME.get(tier, "")) + ("  ·  Mới" if lv == 0 else "")   # "Cấp n → n+1" has its own line: one line was wider than the card (2026-11-22)
	var kl := HBoxContainer.new()   # the tier's gem, then type · tier · level
	kl.add_theme_constant_override("separation", 5)
	kl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kl.add_child(UiKit.rarity_gem(tier, 16.0))
	var kt := _label(kind, 13, (BORDER if skill else STAT_ACCENT) if tier == "common" else accent)   # commons: the type colour
	kt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kl.add_child(kt)
	names.add_child(kl)
	if lv > 0:
		names.add_child(_label("Cấp %d → %d" % [lv, lv + 1], 13, MUTED))
	head.add_child(names)
	v.add_child(head)
	# level pips + the milestone this pick reaches
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(0, 18)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note := cap_note(u)
	pips.draw.connect(func() -> void: _draw_pips(pips, lv, int(pv["max"]), pv["milestones"], accent, true, note))
	v.add_child(pips)
	if String(pv["milestone"]) != "":
		v.add_child(_label("★ " + String(pv["milestone"]), 14, MILESTONE))
	# real numbers: before -> after; one row per stat, a long change on its own row under the name
	# ("-40% (tối đa) → -40% (tối đa)" ran past the card, 2026-11-28)
	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line: Array in pv["lines"]:
		var k := _label(String(line[0]), 15, MUTED)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var change := HBoxContainer.new()   # Labels report their width; an unwrapped RichTextLabel does not (ran past the card 2026-11-22)
		change.alignment = BoxContainer.ALIGNMENT_END
		change.add_theme_constant_override("separation", 6)
		change.mouse_filter = Control.MOUSE_FILTER_IGNORE
		change.add_child(_label(String(line[1]), 15, MUTED))
		change.add_child(_label("→", 15, MUTED))
		var after := _label(String(line[2]), 15, TEXT if line[1] == line[2] else GAIN)   # unchanged: not a gain
		change.add_child(after)
		if wide_change(String(line[1]), String(line[2])):
			grid.add_child(k)
			grid.add_child(change)
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(k)
			row.add_child(change)
			grid.add_child(row)
	v.add_child(grid)
	var d := _label(String(u.get("desc", "")), 14, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(270, 0)
	v.add_child(d)
	var idx := i
	b.set_meta("sfx", "card_pick")   # Sfx: a card, not a plain click
	b.pressed.connect(func() -> void:
		if banish_mode:   # Loại: this card leaves the deck instead of being taken
			banish_mode = false
			run.banish(idx)
		else:
			run.choose(idx))
	if banish_mode:
		b.add_theme_stylebox_override("normal", _style(CARD, Color("a01c1c")))
	if i == 0:
		b.call_deferred("grab_focus")
	return b


## "Cấp n/m", or "Cấp n · không giới hạn" for a card without a level cap.
## Segments in a card's level bar: one per level, none for a card without a cap
## (2^30 segments ran the pause screen out of memory, bug 2026-11-21).
## True when a "before → after" change is too long to share a card row with its stat name.
static func wide_change(before: String, after: String) -> bool:
	return before.length() + after.length() > 16


static func badge_segments(mx: int) -> int:
	return 0 if mx > 20 else mx


static func _lv_text(lv: int, mx: int) -> String:
	return "Cấp %d · không giới hạn" % lv if mx > 20 else "Cấp %d/%d" % [lv, mx]


## "không giới hạn" for a stat card without a level cap, "giới hạn −40%" for the cooldown cards (every
## reduction together stops at run_config player.cooldown_floor; user 2026-11-23).
func cap_note(u: Dictionary) -> String:
	var fx: Dictionary = u.get("effects", {})
	var fl := float(run.cfg.get("player", {}).get("cooldown_floor", 0.0)) if run != null else 0.0
	if fx.size() == 1 and fx.has("cooldown") and fl > 0.0:
		return "giới hạn −%d%%" % roundi((1.0 - fl) * 100.0)
	return "không giới hạn"


## One pip per level: owned = filled, the level this pick gives = bright with a
## ring, locked = dark; milestone levels (new tier look, last level) are diamonds.
func _draw_pips(c: Control, owned: int, max_level: int, milestones: Array, accent: Color, show_next := true, cap_note := "không giới hạn") -> void:
	if max_level > 20:   # a card without a level cap (stat cards, user 2026-11-21): text, not 2^30 pips
		var t := ("Cấp %d → %d · %s" % [owned, owned + 1, cap_note]) if show_next else ("Cấp %d · %s" % [owned, cap_note])
		c.draw_string(ThemeDB.fallback_font, Vector2(0, 14), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent)
		return
	var x := 0.0
	for l in range(1, max_level + 1):
		var nxt := show_next and l == owned + 1
		var col := accent if l <= owned else (Journal.GOLD if nxt else PIP_LOCKED)
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
	var go_on := _button("Tiếp tục" + UiKit.hint("Esc", "Start"), func() -> void: run.resume())
	actions.add_child(go_on)
	go_on.call_deferred("grab_focus")
	actions.add_child(_button("Nhân vật" + UiKit.hint("Tab"), func() -> void: show_character()))
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
	b.add_theme_stylebox_override("normal", _style(CARD, frame))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER, Journal.GOLD))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER, Journal.GOLD))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER, Journal.GOLD))
	var icon := TextureRect.new()
	icon.texture = run.icon_texture(String(o["id"]))
	if pale_icon(icon.texture):
		icon.modulate = INK_GLYPH
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
	Tip.attach(b, String(o["name"]), String(o.get("desc", "")), accent, String(o["id"]), _lv_text(lv, mx))
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
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Journal.GOLD if maxed else Journal.PAPER)
	# level bar: one segment per level along the bottom edge
	var x0 := 4.0
	var bw := OWNED_TILE - 8.0
	var n := badge_segments(mx)
	if n == 0:   # no level cap: one plain bar, the number above says the level
		c.draw_rect(Rect2(x0, OWNED_TILE - 7, bw, 3), accent)
		return
	var seg := bw / n
	for l in n:
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
	info.text = "[b][color=#%s]%s[/color][/b]  [color=#%s]%s[/color]\n[color=#%s]%s[/color]" % [
		TEXT.to_html(false), o["name"], accent.to_html(false), _lv_text(o["level"], o["max"]),
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
	var ps := Journal.sheet_style(24)
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
	var choosing: bool = run.state == run.State.LEVEL_UP
	var back := _button("Quay lại chọn thẻ" + UiKit.hint("Tab") if choosing else "Quay lại" + UiKit.hint("Esc"),
		func() -> void: run.toggle_level_view("character") if choosing else show_pause())
	back.custom_minimum_size = Vector2(260 if choosing else 200, 40)
	head.add_child(back)
	back.call_deferred("grab_focus")
	# three scrolling columns
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var stats_col := _column(body, "Chỉ số", 330.0, false)
	var pv: Dictionary = run.passive()
	if not pv.is_empty():
		var ph := HBoxContainer.new()
		ph.add_theme_constant_override("separation", 10)
		var pic := _icon(String(pv.get("id", "")), 32)
		pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ph.add_child(pic)
		var pvv := VBoxContainer.new()
		pvv.add_theme_constant_override("separation", 0)
		pvv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ph.add_child(pvv)
		var on: bool = run.passive_active() or not pv.has("hp_below")
		pvv.add_child(_label("Nội tại: %s%s" % [pv.get("name", ""), "  ·  đang bật" if on and pv.has("hp_below") else ""], 15,
			Color(String(run.class_data.get("color", "ffd36b"))).lightened(0.3)))
		var pd := _label(String(pv.get("desc", "")), 12, MUTED)
		pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pvv.add_child(pd)
		stats_col.add_child(ph)
	var bd: Dictionary = run.stat_breakdown()
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
	var rows: Array = run.milestone_rows()
	if not rows.is_empty():
		side.add_child(_label("Phần thưởng mốc cấp (trận này)", 18, BORDER))
		for r: Dictionary in rows:
			side.add_child(_milestone_row(r))
	side.add_child(_label("Thẻ chỉ số", 20, BORDER))
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
	v.add_child(_label("%s  ·  còn %d s" % [d.get("name", id), ceili(run.buffs.time_left(id))], 15, Journal.ink_of(Color(d.get("color", "f2ecd8")))))
	var desc := _label(String(d.get("desc", "")), 12, MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	return h


## A level milestone reward picked in this run: icon, kind and name, what it does.
func _milestone_row(r: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ic := _icon(String(r["icon"]), 28)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label("%s  ·  %s" % [r["name"], r["kind"]], 15, MILESTONE))
	var desc := _label(String(r["desc"]), 12, MUTED)
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
	v.add_child(_label("%s  ·  %s" % [o["name"], _lv_text(o["level"], o["max"])], 15, STAT_ACCENT))
	var t := _label(run.card_effect_text(String(o["id"])), 12, MUTED)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	return h


const CHARACTER_STATS := ["max_hp", "damage", "crit_chance", "crit_mul", "cooldown", "area", "amount", "move_speed", "regen",
	"magnet", "armor", "execute_below", "combo_per", "clone_time"]
## Icon for each stat (ui-icons), used on the sheet and in source chips.
const STAT_ICON := {"max_hp": "heart", "damage": "sword", "cooldown": "haste", "area": "reach",
	"move_speed": "boot", "regen": "regen", "magnet": "magnet", "armor": "shield", "amount": "extra_strike",
	"crit_chance": "keen_blades", "crit_mul": "shadow_strike", "execute_below": "execute", "combo_per": "combo",
	"clone_time": "shadow_clone"}
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
	var base_l := _label(("gốc %s" % run._fmt_stat(key, float(b["base"]))) + ("  · tối đa" if b.get("capped", false) else ""), 12, MUTED)
	base_l.custom_minimum_size = Vector2(34, 0)
	chips.add_child(_indent(base_l))
	for part: Dictionary in b["parts"]:
		var amount: String = ("%+d%%" % roundi(float(part["mul"]) * 100.0)) if part.has("mul") else run.signed(float(part["add"]))
		var who := String(part["name"]) if int(part["level"]) <= 0 or not run.buff_def(String(part["id"])).is_empty() else "%s cấp %d" % [part["name"], part["level"]]
		chips.add_child(_chip([String(part["id"])], amount, "%s: %s %s" % [who, run.STAT_LABEL.get(key, key), amount]))
	v.add_child(chips)
	return v


## Indents a chip row under the stat name (past the 24 px icon).
func _indent(c: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 34)
	m.add_child(c)
	return m


## One skill, kept readable however many cards touch it (user 2026-11-17: the
## per-card chips were a mess): icon, name and level pips; one line of the real
## numbers (damage, cooldown, size, amount; the class-only value on hover); one
## line of the total change per stat (each card's share on hover); its statuses.
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
	v.add_theme_constant_override("separation", 5)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(_label(String(si["name"]), 17, TEXT))
	var pips := Control.new()
	var lv: int = si["level"]
	var mx: int = si["max"]
	pips.custom_minimum_size = Vector2(24 * mx, 18)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Tip.attach(pips, "Cấp %d/%d" % [lv, mx], "Ô ◆ là mốc: hình mới hoặc thêm hiệu ứng.")
	pips.draw.connect(func() -> void: _draw_pips(pips, lv, mx, [mx], BORDER, false))
	head.add_child(pips)
	v.add_child(head)
	# the real numbers
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 20)
	nums.add_child(_chip(["sword"], "%d" % roundi(si["damage"]), "Sát thương (gốc %d)" % roundi(si["base_damage"]), TEXT, 16))
	nums.add_child(_chip(["haste"], "%.2f s" % si["cooldown"], "Hồi chiêu (gốc %.2f s)" % si["base_cooldown"], TEXT, 16))
	nums.add_child(_chip(["reach"], "×%.2f" % si["size"], "Vùng", TEXT, 16))
	if int(si.get("count", 1)) > 1:
		nums.add_child(_chip([], "×%d" % int(si["count"]), "Số lượng mỗi lần ra chiêu.\n" + String(si.get("count_parts", "")), MILESTONE, 16, "lần"))
	v.add_child(nums)
	# total change per stat; each card / buff on hover
	var tot := {}
	var tips := {}
	var other := []
	for p: Dictionary in si["sources"]:
		var w := String(p["what"])
		if w in ["Sát thương", "Hồi chiêu", "Vùng"]:
			tot[w] = float(tot.get(w, 0.0)) + float(p.get("pct", 0.0))
			tips[w] = String(tips.get(w, "")) + "%s %s: %s\n" % [p["name"], "" if not run.buff_def(String(p["id"])).is_empty() else "cấp %d" % p["level"], p["text"]]
		else:
			other.append("%s %s" % [w, p["text"]])
	if String(si.get("scale_text", "")) != "":   # skills that scale on armor / hp / speed say so
		v.add_child(_label(String(si["scale_text"]), 13, MILESTONE))
	if tot.has("Hồi chiêu") and float(si.get("base_cooldown", 0.0)) > 0.0:   # the real change, after the -40% cap
		tot["Hồi chiêu"] = (float(si["cooldown"]) / float(si["base_cooldown"]) - 1.0) * 100.0
	if not tot.is_empty() or not other.is_empty():
		var mods := HFlowContainer.new()
		mods.add_theme_constant_override("h_separation", 16)
		for w in ["Sát thương", "Hồi chiêu", "Vùng"]:
			if tot.has(w):
				var col := GAIN if (float(tot[w]) > 0.0) != (w == "Hồi chiêu") else Color("a01c1c")
				mods.add_child(_chip([String(WHAT_ICON[w])], "%s %+d%%" % [w, roundi(float(tot[w]))], String(tips[w]).strip_edges(), col, 13))
		for o: String in other:
			mods.add_child(_label(o, 13, MUTED))
		v.add_child(mods)
	if not si.get("statuses", []).is_empty():
		var st_row := HFlowContainer.new()
		st_row.add_theme_constant_override("h_separation", 12)
		for e: Dictionary in si["statuses"]:
			var sd: Dictionary = run.status_defs.get(String(e.get("status", "")), {})
			var secs := ("%.1f s" % float(e["time"])) if e.has("time") else ""
			st_row.add_child(_chip([String(e.get("status", ""))], "%s %s" % [sd.get("name", e.get("status", "")), secs], String(sd.get("desc", "")), Color("a04a1a"), 13))
		v.add_child(st_row)
	return card


## A small icon + text group with a tooltip. Icons after the first are drawn
## smaller (they say which stat the first one changes).
func _chip(icons: Array, text: String, tip: String, col := MUTED, sz := 12, note := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	if tip != "":
		Tip.attach(h, text, tip, col if col != MUTED else BORDER, String(icons[0]) if not icons.is_empty() else "")
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
	if pale_icon(t.texture):   # a white glyph made for the dark theme: in ink on the paper sheet
		t.modulate = INK_GLYPH
	return t


const INK_GLYPH := Color(0.42, 0.28, 0.18)
static var _pale := {}


## True for an icon drawn as a pale glyph (mean lightness of its opaque pixels over 0.8, little colour): it vanishes on
## paper, so the journal panels draw it in ink.
static func pale_icon(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var key := tex.get_rid()
	if _pale.has(key):
		return _pale[key]
	var img := tex.get_image()
	var pale := false
	if img != null:
		if img.is_compressed():
			img.decompress()
		var n := 0
		var lum := 0.0
		var sat := 0.0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					n += 1
					lum += c.get_luminance()
					sat += c.s
		pale = n > 0 and lum / n > 0.8 and sat / n < 0.25
	_pale[key] = pale
	return pale


func show_settings() -> void:
	var root := _open("")
	root.add_child(SettingsPanel.build(func() -> void: show_pause()))


## Win / lose: time, level, kills, gold; then the damage table (each skill's
## damage with its share as a bar, hits, kills, damage per second), damage taken
## and hp healed; the two buttons on one row.
func show_end(won: bool) -> void:
	var title := "Vượt ải!" if won else "Thất bại"
	var rr: Dictionary = run.run_result if "run_result" in run else {}
	if not rr.is_empty():
		title = "Vượt ải %d!" % int(rr.get("stage", 0)) if won else "Thất bại · Ải %d" % int(rr.get("stage", 0))
		if String(rr.get("challenge", "")) != "":   # a challenge: its name, not the base stage
			var cname := String(Challenges.load_default().get_def(String(rr["challenge"])).get("name", ""))
			title = ("Vượt thử thách: %s!" % cname) if won else ("Thất bại · %s" % cname)
		if bool(rr.get("endless", false)):   # Vô tận: how long and how many Vòng (design/endless.md)
			var et := int(rr.get("endless_time", 0.0))
			title = "Vô tận · %02d:%02d · Vòng %d" % [et / 60, et % 60, int(rr.get("endless_cycle", 1))]
	var root := _open(title)
	var t := int(run.clock)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	row.add_child(_icon_value("clock", "%02d:%02d" % [t / 60, t % 60]))
	row.add_child(_icon_value("star", str(run.level)))
	row.add_child(_icon_value("skull", str(run.enemies.total_kills)))
	row.add_child(_icon_value("coin", str(run.gold)))
	root.add_child(row)
	if not rr.is_empty():
		var parts := PackedStringArray()
		if won and String(rr.get("challenge", "")) != "":
			parts.append("Vàng +%d +%d (nhặt)" % [int(rr.get("stage_gold", 0)), int(rr.get("collected", 0))])
			parts.append("Tẩy Tủy Đan +%d%s" % [int(rr.get("pills", 0)), " (lần đầu)" if bool(rr.get("first", false)) else ""])
		elif won:
			parts.append("Vàng +%d (ải) +%d (nhặt)" % [int(rr.get("stage_gold", 0)), int(rr.get("collected", 0))])
			parts.append("Đá +%d%s" % [int(rr.get("gems", 0)), " (lần đầu)" if bool(rr.get("first", false)) else ""])
		else:
			parts.append("Giữ lại vàng nhặt: +%d" % int(rr.get("collected", 0)))
		if bool(rr.get("endless_record", false)):
			parts.insert(0, "Kỷ lục mới!")
		if int(rr.get("essence", 0)) > 0:
			parts.append("Tinh hoa +%d" % int(rr["essence"]))
		if int(rr.get("shards", 0)) > 0:   # design/skill-tree-v2.md §4
			parts.append("Mảnh thẻ +%d" % int(rr["shards"]))
		var reward_l := _label(" · ".join(parts), 17, BORDER if won else MUTED)
		reward_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(reward_l)
	var report: Array = run.damage_report()
	root.add_child(_end_tabs(report))
	var total := 0.0
	for r: Dictionary in report:
		total += float(r["damage"])
	if not run.won_items.is_empty():
		var got := HBoxContainer.new()
		got.alignment = BoxContainer.ALIGNMENT_CENTER
		got.add_theme_constant_override("separation", 14)
		got.add_child(_label("Trang bị nhận được:", 16, BORDER))
		for id: String in run.won_items:
			var d: Dictionary = run.profile.defs.get(id, {})
			got.add_child(_chip([String(d.get("icon", id))], String(d.get("name", id)), String(d.get("desc", "")), RARITY.get(String(d.get("rarity", "common")), TEXT), 16))
		root.add_child(got)
	var foot := _label("Tổng sát thương %d  ·  Sát thương nhận %d  ·  Máu đã hồi %d" % [
		roundi(total), roundi(run.damage_taken), roundi(run.healed)], 14, MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(foot)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	root.add_child(buttons)
	var again := _button("Chơi lại" + UiKit.hint("R"), func() -> void: run.restart())
	var lobby_b := _button("Về sảnh", func() -> void: run.to_lobby())
	var next_b: Button = null
	if won and bool(rr.get("next", false)):
		next_b = _button("Ải tiếp ▶", func() -> void: run.next_stage())
	buttons.add_child(again)
	if next_b != null:
		buttons.add_child(next_b)
	buttons.add_child(lobby_b)

	if next_b != null:
		next_b.call_deferred("grab_focus")
	else:
		again.call_deferred("grab_focus")


## The end report's three views (user 2026-11-22, roadmap B): Gây ra (the skill table + the passive's indirect
## damage), Nhận vào (taken / prevented by source), Hồi máu (healed by source). Tabs keep the panel one size.
func _end_tabs(report: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	box.add_child(tabs)
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(760, 210)
	box.add_child(holder)
	var views := {"dealt": "Gây ra", "taken": "Nhận vào", "heal": "Hồi máu"}
	var show := func(which: String) -> void:
		for ch in holder.get_children():
			ch.queue_free()
		holder.add_child(_end_view(which, report))
		for b: Button in tabs.get_children():
			b.modulate = Color.WHITE if b.get_meta("view") == which else Color(1, 1, 1, 0.55)
	for v: String in views:
		var b := _button(String(views[v]), func() -> void: show.call(v))
		b.set_meta("view", v)
		b.custom_minimum_size = Vector2(150, 34)
		tabs.add_child(b)
	show.call(String(run.end_tab) if String(run.end_tab) in views else "dealt")
	return box


func _end_view(which: String, report: Array) -> Control:
	if which == "dealt":
		var v := VBoxContainer.new()
		if not report.is_empty():
			v.add_child(_damage_table(report))
		for r: Dictionary in run.ledger_rows(run.enemies.bonus_by):   # the passive's indirect share
			var l := _label("Gián tiếp · %s: +%d sát thương" % [r["name"], roundi(float(r["value"]))], 14, BORDER)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
		return v
	if which == "taken":
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 40)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(_ledger_list("Sát thương nhận vào", run.ledger_rows(run.taken_by), Color("a01c1c")))
		h.add_child(_ledger_list("Sát thương được giảm", run.ledger_rows(run.reduced_by), Color("3a6aaa")))
		return h
	var c := CenterContainer.new()
	c.add_child(_ledger_list("Máu đã hồi", run.ledger_rows(run.heal_by), GAIN))
	return c


## A titled list of ledger rows: name, amount, share bar; "Chưa có" when empty.
func _ledger_list(title: String, rows: Array, col: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size = Vector2(340, 0)
	v.add_child(_label(title, 16, col))
	if rows.is_empty():
		v.add_child(_label("Chưa có", 14, MUTED))
	for r: Dictionary in rows.slice(0, 6):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var n := _label(String(r["name"]), 14, TEXT)
		n.custom_minimum_size = Vector2(170, 0)
		n.clip_text = true
		row.add_child(n)
		var bar := ColorRect.new()
		bar.color = col.darkened(0.25)
		bar.custom_minimum_size = Vector2(maxf(2.0, 90.0 * float(r["share"])), 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var num := _label("%d (%d%%)" % [roundi(float(r["value"])), roundi(100.0 * float(r["share"]))], 14, MUTED)
		row.add_child(num)
		v.add_child(row)
	return v


func _milestone_choice(info: Dictionary, pick: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(270, 210)
	b.add_theme_stylebox_override("normal", _style(CARD))
	b.add_theme_stylebox_override("hover", _style(CARD_HOVER))
	b.add_theme_stylebox_override("pressed", _style(CARD_HOVER))
	b.add_theme_stylebox_override("focus", _style(CARD_HOVER))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12
	vb.offset_top = 10
	vb.offset_right = -12
	vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var ic := _icon(String(info.get("icon", info.get("id", ""))), 40)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var nm := _label(String(info.get("name", "")), 18, MILESTONE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)
	var kinds: Dictionary = {"skill": "Chiêu độc nhất", "card": "Thẻ đặc biệt", "passive": "Nội tại", "rule": "Luật"}
	var kind := _label(String(kinds.get(String(info.get("kind", "")), "")), 13, MUTED)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(kind)
	var d := _label(String(info.get("desc", "")), 12, TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(246, 88)   # wrap inside the card instead of spilling out
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(d)
	b.set_meta("sfx", "card_pick")   # Sfx: a card, not a plain click
	b.pressed.connect(pick)
	return b


const DMG_BAR := 150.0
const RARITY := {"common": Color("3a2414"), "rare": Color("3a6aaa"), "epic": Color("7a3ab8"), "legendary": Color("c0801a")}   # ink on paper


func _damage_table(report: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 6
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # centred in the panel, not hugging its left edge
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
		icon.texture = run.icon_texture(String(r.get("icon", r["id"])))
		if pale_icon(icon.texture):
			icon.modulate = INK_GLYPH
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
	boxed = true   # every in-run panel is a journal sheet (user 2026-11-27, design-web screen-run-journal)
	if boxed:
		var panel := PanelContainer.new()
		var ps := Journal.sheet_style(24)   # the journal look (design-web screen-run-journal, user 2026-11-27): a paper sheet
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
	var on := _style(CARD_HOVER, Journal.GOLD)
	b.add_theme_stylebox_override("focus", on)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, TEXT)
	b.add_theme_color_override("font_focus_color", BORDER)
	b.add_theme_color_override("font_disabled_color", PIP_EDGE)
	b.pressed.connect(cb)
	return b


func _style(bg: Color, border := BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)   # journal: square sketch boxes in ink
	return s
