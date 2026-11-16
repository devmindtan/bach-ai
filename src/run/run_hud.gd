class_name RunHud
extends Control
## In-run HUD drawn from the run's state: xp bar across the top, level, clock,
## hp, kills and gold. Holds no state of its own.
##
## Example:
##   var hud := RunHud.new(); hud.run = run_node; canvas_layer.add_child(hud)

const XP_BAR := Color("4fa3e0")
const HP_BAR := Color("d9364a")
const BACK := Color(0.05, 0.05, 0.08, 0.85)
const TEXT := Color("f2ecd8")
const SHADOW := Color(0, 0, 0, 0.7)

var run: Node


func _ready() -> void:
	# a Control under a CanvasLayer has no parent rect: size it to the viewport
	# (anchors alone left it 0x0, so panels and the HUD were laid out at the corner)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _draw() -> void:
	if run == null:
		return
	var font := ThemeDB.fallback_font
	var w := size.x
	# xp
	var frac := clampf(float(run.xp) / float(run.xp_needed()), 0.0, 1.0)
	draw_rect(Rect2(0, 0, w, 14), BACK)
	draw_rect(Rect2(2, 2, (w - 4) * frac, 10), XP_BAR)
	_text(font, Vector2(12, 40), "Cấp %d" % run.level, 22)
	# hp
	var max_hp := float(run.stats["max_hp"])
	draw_rect(Rect2(12, 50, 220, 16), BACK)
	draw_rect(Rect2(14, 52, 216 * clampf(run.hp / max_hp, 0.0, 1.0), 12), HP_BAR)
	_text(font, Vector2(18, 64), "%d / %d" % [ceili(run.hp), roundi(max_hp)], 13)
	# clock
	var t := int(run.clock)
	var total := int(run.duration)
	var clock := "%02d:%02d / %02d:%02d" % [t / 60, t % 60, total / 60, total % 60]
	var cw := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_text(font, Vector2((w - cw) * 0.5, 44), clock, 26)
	# kills / gold
	var right := "Hạ: %d    Vàng: %d" % [run.enemies.total_kills, run.gold]
	var rw := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_text(font, Vector2(w - rw - 14, 40), right, 18)


func _text(font: Font, p: Vector2, s: String, sz: int) -> void:
	draw_string(font, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, SHADOW)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, TEXT)
