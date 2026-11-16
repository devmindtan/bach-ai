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
const MUTED := Color("b9b2a0")
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
	# xp: thin bar across the top, gem at its left end
	var frac := clampf(float(run.xp) / float(run.xp_needed()), 0.0, 1.0)
	draw_rect(Rect2(0, 0, w, 10), BACK)
	draw_rect(Rect2(28, 2, (w - 30) * frac, 6), XP_BAR)
	UiIcons.draw(self, "gem", Vector2(14, 6), 1.0)
	# level: star with the number on top
	UiIcons.draw(self, "star", Vector2(32, 44), 3.0)
	_centered(font, Vector2(32, 52), str(run.level), 20)
	# hp: heart + bar with the number inside
	var max_hp := float(run.stats["max_hp"])
	UiIcons.draw(self, "heart", Vector2(78, 44), 2.0)
	var bar := Rect2(96, 34, 200, 20)
	draw_rect(bar, BACK)
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * clampf(run.hp / max_hp, 0.0, 1.0), 16)), HP_BAR)
	_centered(font, Vector2(bar.get_center().x, bar.end.y - 4), "%d / %d" % [ceili(run.hp), roundi(max_hp)], 14)
	# clock: icon + elapsed, total smaller
	var t := int(run.clock)
	var total := int(run.duration)
	var clock := "%02d:%02d" % [t / 60, t % 60]
	var cw := font.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	UiIcons.draw(self, "clock", Vector2(w * 0.5 - cw * 0.5 - 22, 42), 2.0)
	_text(font, Vector2(w * 0.5 - cw * 0.5, 52), clock, 28)
	_text(font, Vector2(w * 0.5 + cw * 0.5 + 8, 52), "/ %02d:%02d" % [total / 60, total % 60], 16, MUTED)
	# kills and gold: icon + number, right-aligned pair
	var gold := str(run.gold)
	var kills := str(run.enemies.total_kills)
	var gw := font.get_string_size(gold, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var kw := font.get_string_size(kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var x := w - 16 - gw
	_text(font, Vector2(x, 52), gold, 22)
	UiIcons.draw(self, "coin", Vector2(x - 20, 44), 2.0)
	x -= 56 + kw
	_text(font, Vector2(x, 52), kills, 22)
	UiIcons.draw(self, "skull", Vector2(x - 20, 44), 2.0)


func _centered(font: Font, baseline_center: Vector2, s: String, sz: int) -> void:
	var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var p := baseline_center - Vector2(sw * 0.5, 0)
	draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, SHADOW)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, TEXT)


func _text(font: Font, p: Vector2, s: String, sz: int, col := TEXT) -> void:
	draw_string(font, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, SHADOW)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
