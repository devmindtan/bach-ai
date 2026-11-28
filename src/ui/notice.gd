class_name Notice
extends RefCounted
## Confirm slips and corner notes (design-web screen-notices-journal, approved 2026-11-28; user: "xóa, thêm, cập nhật cần
## phải hiện thông báo (có thể cho phép bỏ qua cho lần sau)").
## - [method ask]: a slip pinned over the book with "Thôi (Esc)" and the red action "(Enter)"; with a [param key] it
##   offers "Không hỏi lại (Space)", remembered in Prefs.skip_confirm (Cài đặt › Hỏi trước khi làm turns it back on).
## - [method note]: a short note at the top right, gone after NOTE_S, at most NOTE_MAX, never takes the keys.
##
## Example:
##   Notice.ask("reset_tree", "Tẩy tuỷ cây kỹ năng?", "Bỏ hết các nút đã học.", "Tốn: 1 Tẩy Tủy Đan", "Tẩy tuỷ", do_reset)
##   Notice.note("Đã học Rèn thân · cấp 3", "−3 Tinh hoa · còn 21", UiIcons.texture("essence"))

const NOTE_S := 2.0
const NOTE_MAX := 3
const NOTE_W := 360.0
const OK_EDGE := Color("2a7a3a")

static var _notes: VBoxContainer


## Where the slips and notes go: the window's root (a note outlives a scene change); in a shot the screen sits in the
## capture's SubViewport instead, so they go there to be seen.
static func _host(tree: SceneTree) -> Node:
	if tree.current_scene != null:
		return tree.root
	for n in tree.root.get_children():
		if n is SubViewport:
			return n
	return tree.root


## A done action at the top right ([param warn]: a refusal, red edge).
static func note(title: String, sub := "", icon: Texture2D = null, warn := false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _notes == null or not is_instance_valid(_notes):
		var layer := CanvasLayer.new()
		layer.layer = 95
		_host(tree).add_child.call_deferred(layer)   # a screen may call it from _ready (parent busy)
		_notes = VBoxContainer.new()
		_notes.add_theme_constant_override("separation", 8)
		_notes.position = Vector2(1280 - 104 - NOTE_W, 20)
		_notes.custom_minimum_size = Vector2(NOTE_W, 0)
		_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_notes)
	while _notes.get_child_count() >= NOTE_MAX:
		var old := _notes.get_child(0)
		_notes.remove_child(old)
		old.queue_free()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Journal.PAPER
	sb.border_color = Journal.EDGE
	sb.set_border_width_all(3)
	sb.border_width_left = 8
	sb.border_color = Journal.EDGE
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := ColorRect.new()   # the coloured left edge (web .note border-left)
	edge.color = Journal.INK_RED if warn else OK_EDGE
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.custom_minimum_size = Vector2(32, 32)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var t := Journal.ink(title, 20)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if sub != "":
		var s := Journal.ink(sub, 16, Journal.INK_SOFT)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	_notes.add_child(p)
	p.draw.connect(func() -> void: p.draw_rect(Rect2(0, 0, 8, p.size.y), edge.color))
	var tw := p.create_tween()
	tw.tween_interval(NOTE_S)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


## Asks before [param on_yes] (a delete or a reset). With [param key] != "" the slip offers "Không hỏi lại", and once
## the player ticked it, [param on_yes] runs at once next time.
static func ask(key: String, title: String, text: String, cost: String, yes: String, on_yes: Callable) -> void:
	var prefs := Prefs.current()
	if key != "" and prefs.skip_confirm.has(key):
		on_yes.call()
		return
	var tree := Engine.get_main_loop() as SceneTree
	var layer := CanvasLayer.new()
	layer.layer = 96
	_host(tree).add_child.call_deferred(layer)
	var slip := AskSlip.new()
	slip.setup(key, title, text, cost, yes, on_yes)
	layer.add_child(slip)


## True when [param key]'s confirm is skipped (tests, the settings row).
static func skipped(key: String) -> bool:
	return Prefs.current().skip_confirm.has(key)
