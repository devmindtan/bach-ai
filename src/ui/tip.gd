class_name Tip
extends RefCounted
## The game's own tooltips (design/ux/tooltip.md): a dark card framed in an accent
## colour with an optional icon, a title, a kind line and a text, placed next to
## its control (below, else above), kept on screen, shown after a short hover or
## at once on keyboard / pad focus, fading in. Replaces Godot's plain tooltip_text.
##
## Example:
##   Tip.attach(button, "Mũ rồng", "+4 giáp, +25 máu tối đa.", UiKit.RARE, "dragon_helm", "Sử thi · Đầu")
##
## Shots: --tip=<text> opens the first tooltip whose title contains <text>.

const DELAY := 0.2
const FADE := 0.12
const MAX_W := 320.0
const GAP := 8.0

static var _card: PanelContainer
static var _owner: Control
static var _timer: SceneTreeTimer
static var _forced := ""
static var _forced_done := false
static var _args_read := false


## Gives [param c] a tooltip. [param title] is required; the rest optional.
static func attach(c: Control, title: String, body := "", accent := UiKit.GOLD, icon := "", kind := "") -> void:
	c.tooltip_text = ""
	c.set_meta("tip", {"title": title, "body": body, "accent": accent, "icon": icon, "kind": kind,
		"since": Time.get_ticks_msec()})
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	if not c.mouse_entered.is_connected(_hover.bind(c)):
		c.mouse_entered.connect(_hover.bind(c))
		c.mouse_exited.connect(_leave.bind(c))
		c.focus_entered.connect(_focused.bind(c))
		c.focus_exited.connect(_leave.bind(c))
		c.tree_exiting.connect(_leave.bind(c))
	if not _args_read:
		_args_read = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--tip="):
				_forced = a.get_slice("=", 1)
	if _forced != "" and not _forced_done and title.contains(_forced):
		# a screen may rebuild and free this control first: the next one with the
		# same title then gets the tooltip (done only once one is shown)
		var tree := Engine.get_main_loop() as SceneTree   # c may not be in the tree yet
		(func() -> void:
			await tree.process_frame
			await tree.process_frame
			if not _forced_done and is_instance_valid(c) and c.is_inside_tree():
				_forced_done = true
				_show(c)).call_deferred()


## Focus shows the tooltip when the player moves to the control, not when a screen
## gives a control focus as it is built (that tooltip covered the paper doll).
static func _focused(c: Control) -> void:
	if not is_instance_valid(c) or not c.has_meta("tip"):
		return
	if Time.get_ticks_msec() - int(c.get_meta("tip").get("since", 0)) < 400:
		return
	_show(c)


static func _hover(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	_timer = c.get_tree().create_timer(DELAY)
	var t := _timer
	t.timeout.connect(func() -> void:
		if t == _timer and is_instance_valid(c) and c.is_inside_tree():
			_show(c))


static func _leave(c: Control) -> void:
	_timer = null
	if _owner == c:
		_hide()


static func _hide() -> void:
	_owner = null
	if is_instance_valid(_card):
		_card.get_parent().queue_free()   # its CanvasLayer
	_card = null


static func _show(target: Variant) -> void:
	if not is_instance_valid(target) or not (target as Control).is_inside_tree() or not (target as Control).has_meta("tip"):
		return
	var c: Control = target
	_hide()
	_owner = c
	var d: Dictionary = c.get_meta("tip")
	var layer := CanvasLayer.new()
	layer.layer = 128
	c.get_viewport().add_child(layer)
	var accent: Color = d["accent"]
	_card = PanelContainer.new()
	var sb := UiKit.style(Color(0.07, 0.06, 0.11, 0.97), 10, accent, 2)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	_card.add_theme_stylebox_override("panel", sb)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	layer.add_child(_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(h)
	if String(d["icon"]) != "" and UiIcons.texture(String(d["icon"])) != null:
		var box := UiKit.panel(UiKit.PANEL_DARK, 3, accent)
		box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(UiKit.icon(String(d["icon"]), 32.0))
		h.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := UiKit.label(String(d["title"]), 17, accent.lightened(0.15))
	v.add_child(t)
	if String(d["kind"]) != "":
		v.add_child(UiKit.label(String(d["kind"]), 13, UiKit.MUTED))
	if String(d["body"]) != "":
		var b := UiKit.label(String(d["body"]), 14, UiKit.TEXT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# wrap at MAX_W only when the text is long; short texts keep their width
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(String(d["body"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		b.custom_minimum_size.x = minf(w + 4.0, MAX_W - (52.0 if String(d["icon"]) != "" else 0.0))
		v.add_child(b)
	var card := _card
	# deferred: capture ids, not the nodes (a screen rebuilt in between freed c, and calling a lambda that
	# holds a freed node prints "Lambda capture ... was freed" before any check inside it can run)
	var card_id := card.get_instance_id()
	var c_id := c.get_instance_id()
	(func() -> void:
		var tc := instance_from_id(card_id) as Control
		var tt := instance_from_id(c_id) as Control
		if tc == null or tt == null or not tt.is_inside_tree():
			return
		var sz := tc.get_combined_minimum_size()
		tc.size = sz
		var vp := tt.get_viewport().get_visible_rect().size
		var r := tt.get_global_rect()
		var pos := Vector2(r.position.x, r.end.y + GAP)
		if pos.y + sz.y > vp.y - GAP:   # no room below: above
			pos.y = r.position.y - sz.y - GAP
		pos.x = clampf(pos.x, GAP, maxf(GAP, vp.x - sz.x - GAP))
		pos.y = clampf(pos.y, GAP, maxf(GAP, vp.y - sz.y - GAP))
		tc.position = pos
		tc.create_tween().tween_property(tc, "modulate:a", 1.0, FADE)).call_deferred()
