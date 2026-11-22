extends RefCounted
## Special effects drawn at the hero (H6-H8, 2026-11-22): _item_fx drew them at scale 1 while the hero is
## drawn at world.sprite_scale (2), so the wind ribbons / shooting stars sat inside the hero's body.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_hero_effects_use_the_sprite_scale() -> void:
	var r: Node = Run.new()
	r._sprite_scale = 2.0
	r.sheets["ward-wind"] = SpriteSheet.load_dir("res://assets/sprites/custom/ward-wind", "ward-wind")
	r._item_fx({"fx": "ward-wind"})
	_check(r._fx.size() == 1, "one effect")
	if r._fx.size() == 1:
		# _add_fx folds px_scale (0.5) in: world scale = sprite_scale x px_scale
		_check(is_equal_approx(float(r._fx[0]["scale"]), 2.0 * 0.5), "scale %s, want 1.0 (2 x 0.5)" % r._fx[0]["scale"])
	r.free()
