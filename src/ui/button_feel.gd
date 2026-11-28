class_name ButtonFeel
extends RefCounted
## Button feel for every button (design-web screen-feel-journal, approved 2026-11-28; user: "các thao tác button chưa
## mượt như các game khác, thiếu 1 cái gì đấy"). Wired once per button by [method attach] (Audio's node_added):
## - focus: a paper tick ("ui_tick"); in a vertical list a gold mark slides to the row (Hades-like);
## - press: the button squashes and bounces (Balatro-like), the press sound is Audio's "ui_click";
## - a disabled button clicked with the mouse shakes with a thud ("ui_deny");
## - the buttons of a newly opened screen rise in one after another.
## Motion is off at Cài đặt › Hiệu ứng ≥ 2 (like the page turn); the sounds stay.

const MARK_W := 10.0
const LIFT := 1.04
const LIFT_S := 0.12
const LIFT_PX := 4.0
const FRESH_MS := 120
const MARK_GAP := 10.0
const SLIDE_S := 0.11
const RISE_S := 0.16
const RISE_STEP := 0.03
const RISE_MAX := 6
const RISE_WINDOW_MS := 350

## Lists that show the sliding gold mark opt in with this meta (a chapter list, settings rows): on any VBox it also
## lit gear slots and region ribbons, where it read as misplaced (user 2026-11-28).
const MARK_META := &"feel_mark"

static var opened_ms := -100000   # when the current screen appeared (set by Audio on scene change)


## True when [param node] is a screen loaded under [param root] (a .tscn scene), not a tip, note or page-turn layer
## added there: those reset the rise clock, and a stage select rebuilt on each move then faded out and in (2026-11-28).
static func is_screen(node: Node, root: Node) -> bool:
	return node.get_parent() == root and node.scene_file_path != "" and not node is Window and not node is CanvasLayer


static func motion() -> bool:
	return Prefs.current().vfx < 2


## Lets the rows of [param box] carry the sliding gold mark.
static func mark_list(box: VBoxContainer) -> void:
	box.set_meta(MARK_META, true)


## Hooks [param b] up. [param audio] plays the sounds (Audio autoload).
static func attach(b: BaseButton, audio: Node) -> void:
	if b.has_meta("_feel"):
		return
	b.set_meta("_feel", true)
	b.tree_entered.connect(func() -> void: b.set_meta("_born", Time.get_ticks_msec()))
	b.focus_entered.connect(func() -> void: _on_focus(b, audio))
	b.focus_exited.connect(func() -> void: _settle(b))
	b.pressed.connect(func() -> void: bounce(b))
	b.gui_input.connect(func(e: InputEvent) -> void:
		var m := e as InputEventMouseButton
		if b.disabled and m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
			audio.call("play_id", "ui_deny")
			shake(b))
	if Time.get_ticks_msec() - opened_ms < RISE_WINDOW_MS and motion():
		b.ready.connect(func() -> void: _rise(b), CONNECT_ONE_SHOT)


static func _on_focus(b: BaseButton, audio: Node) -> void:
	if b.get_meta("sfx", "ui_click") != "":
		audio.call("play_id", "ui_tick")
	_lift(b)
	var box := b.get_parent() as VBoxContainer
	if box != null and box.has_meta(MARK_META):
		_slide_mark(b, box)


## The gold mark left of the focused row of a vertical list; it slides between rows.
static func _slide_mark(b: BaseButton, box: VBoxContainer) -> void:
	if not b.is_inside_tree():
		return
	if b.size.y <= 0.0 or not box.is_node_ready():   # focus grabbed in _ready: wait for the layout
		_slide_mark.call_deferred(b, box)
		return
	# drawn by the box itself (a child would be laid out as a row): meta "_mark" = Rect2 in the box
	var to := _mark_at(b)
	box.set_meta("_mark_row", b)
	if not box.has_meta("_mark"):
		box.set_meta("_mark", to)
		box.draw.connect(func() -> void:
			var r: Rect2 = box.get_meta("_mark")
			box.draw_rect(r.grow(2.0), Journal.INK)
			box.draw_rect(r, Journal.GOLD))
		box.sort_children.connect(func() -> void:   # the rows moved (first layout, a row grew): snap to the row
			var row: Variant = box.get_meta("_mark_row")
			if is_instance_valid(row):
				box.set_meta("_mark", _mark_at(row))
				box.queue_redraw())
		box.queue_redraw()
		return
	var from: Rect2 = box.get_meta("_mark")
	var put := func(r: Rect2) -> void:
		box.set_meta("_mark", r)
		box.queue_redraw()
	if not motion():
		put.call(to)
		return
	var tw := box.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(k: float) -> void:
		put.call(Rect2(from.position.lerp(to.position, k), from.size.lerp(to.size, k))), 0.0, 1.0, SLIDE_S)


static func _mark_at(b: Control) -> Rect2:
	return Rect2(-MARK_GAP - MARK_W, b.position.y, MARK_W, b.size.y)


## The focused button rises a little and its new colour fades in (web .row.on transition), not a hard swap.
static func _lift(b: Control) -> void:
	if not b.is_inside_tree():
		return
	b.pivot_offset = b.size * 0.5
	if not motion():
		return
	if fresh(b):   # a page rebuilt on focus (stage select, notebooks): its new button starts lifted, no flash
		b.scale = lift_of(b)
		return
	var tw := b.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.modulate = Color(1.35, 1.3, 1.15)
	tw.tween_property(b, "scale", lift_of(b), LIFT_S)
	tw.tween_property(b, "modulate", Color.WHITE, LIFT_S * 1.5)


## True for a button made in the last FRESH_MS: a screen that rebuilds itself on each move would replay the lift and
## flash every time, which read as flicker (stage select, 2026-11-28).
static func fresh(b: Control) -> bool:
	return Time.get_ticks_msec() - int(b.get_meta("_born", -100000)) < FRESH_MS


## The lifted scale: LIFT for small buttons, at most LIFT_PX wider on each side for wide rows (a 470 px row at 1.04
## crossed the page's dashed edge, 2026-11-28).
static func lift_of(c: Control) -> Vector2:
	var k := minf(LIFT, 1.0 + 2.0 * LIFT_PX / maxf(c.size.x, 1.0))
	return Vector2(k, k)


static func _settle(b: Control) -> void:
	if not b.is_inside_tree():
		return
	if not motion():
		b.scale = Vector2.ONE
		return
	b.create_tween().tween_property(b, "scale", Vector2.ONE, LIFT_S * 0.7)


## Squash then bounce back (web @keyframes press).
static func bounce(c: Control) -> void:
	if not motion() or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.93, 0.88), 0.05)
	tw.tween_property(c, "scale", Vector2(1.05, 1.06), 0.06)
	tw.tween_property(c, "scale", lift_of(c) if c.has_focus() else Vector2.ONE, 0.06)


## A short side shake: this one cannot be used.
static func shake(c: Control) -> void:
	if not motion() or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	for a in [-0.06, 0.06, -0.04, 0.03, 0.0]:
		tw.tween_property(c, "rotation", a, 0.04)


static func _rise(b: BaseButton) -> void:
	var i := mini(b.get_index(), RISE_MAX)
	b.modulate.a = 0.0
	var tw := b.create_tween()
	tw.tween_interval(i * RISE_STEP)
	tw.tween_property(b, "modulate:a", 1.0, RISE_S)
