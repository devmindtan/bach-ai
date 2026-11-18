extends RefCounted
## Pixel icons are only ever drawn at whole multiples of their frame size: a 16 px
## icon stretched to 84 px (x5.25) drew pixels of uneven width, the "méo" look the
## user saw on the equipment screen (2026-11-18).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_icon_size_snaps_to_a_whole_multiple() -> void:
	for px: float in [18.0, 20.0, 36.0, 40.0, 52.0, 84.0]:
		var t := UiKit.icon("heart", px)
		var frame := t.texture.get_size().x
		var k := t.custom_minimum_size.x / frame
		_check(is_equal_approx(k, roundf(k)) and k >= 1.0, "%d px asked: drawn at x%.2f of a %d px frame" % [px, k, frame])
		_check(t.custom_minimum_size.x <= maxf(px, frame), "never bigger than asked (unless smaller than one frame)")
		t.free()


func test_snap_rule() -> void:
	_check(UiKit.snap_icon(84.0, 16.0) == 80.0, "84 -> 80")
	_check(UiKit.snap_icon(84.0, 24.0) == 72.0, "84 -> 72 for 24 px icons")
	_check(UiKit.snap_icon(10.0, 16.0) == 16.0, "below one frame -> one frame")
