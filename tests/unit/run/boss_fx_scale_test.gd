extends RefCounted
## Review 2026-11-21: the boss slam / split effects were drawn at x1.8 and x1.44, so their 72 px art smeared
## (pixels of uneven size). Boss effects are drawn at a whole scale, like every other sprite.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_boss_effects_use_whole_scales() -> void:
	var src := FileAccess.get_file_as_string("res://src/run/boss_fx.gd")
	_check(is_equal_approx(BossFxNode.BOSS_SCALE, roundf(BossFxNode.BOSS_SCALE)), "BOSS_SCALE %s is whole" % BossFxNode.BOSS_SCALE)
	_check(is_equal_approx(BossFxNode.SPLIT_SCALE, roundf(BossFxNode.SPLIT_SCALE)), "SPLIT_SCALE %s is whole" % BossFxNode.SPLIT_SCALE)
	_check(not src.contains("BOSS_SCALE * 0."), "no fractional multiple of the boss scale")
