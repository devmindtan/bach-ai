extends RefCounted
## Review 2026-11-21: late builds stack many effects and hide monster bolts and the hero. Cài đặt has a
## "Hiệu ứng" option (Đầy đủ / Giảm / Tối thiểu) that fades the player's effects; bolts and bodies stay full.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_vfx_levels_fade_effects() -> void:
	var p := Prefs.new()
	_check(is_equal_approx(p.vfx_alpha(), 1.0), "default: full effects")
	p.vfx = 1
	_check(p.vfx_alpha() < 1.0 and p.vfx_alpha() > 0.5, "Giảm: about 70%%, got %s" % p.vfx_alpha())
	p.vfx = 2
	_check(p.vfx_alpha() <= 0.5 and p.vfx_alpha() > 0.2, "Tối thiểu: faint but visible, got %s" % p.vfx_alpha())
	_check(Prefs.VFX_NAMES.size() == 3, "three named levels")
	p.free()
