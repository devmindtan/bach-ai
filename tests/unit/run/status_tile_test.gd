extends RefCounted
## Regression (user 2026-11-20): the burn effect was blurry on big monsters: one 32 px sprite blown up by
## radius / 8 (x5 on a boss, fractional like x1.6 on mid monsters). Tiled statuses (statuses.json "tile")
## are drawn as several flames at the game's whole sprite scale spread over the body.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_burn_on_a_big_body_is_many_flames_at_whole_scale() -> void:
	var r: Node = Run.new()
	r._sprite_scale = 2.0
	_check(bool(GameData.load_json("res://assets/data/statuses.json")["statuses"]["burn"].get("tile", false)), "burn is a tiled status")
	for radius in [9.5, 13.0, 26.0, 44.0]:
		var spots: Array = r.status_spots(radius, true)
		_check(not spots.is_empty(), "flames on radius %s" % radius)
		for s: Array in spots:
			var sc: float = s[1]
			_check(is_equal_approx(sc, roundf(sc)) and sc <= 2.0, "radius %s: whole scale <= sprite scale, got %s" % [radius, sc])
			_check((s[0] as Vector2).length() <= radius, "radius %s: flame inside the body" % radius)
	_check(r.status_spots(44.0, true).size() > r.status_spots(13.0, true).size(), "a bigger body burns with more flames")
	r.free()


# User 2026-11-20: every debuff is drawn crisp (whole scale, never a fraction) and see-through, so the
# monster under it stays visible (the solid burn hid it).
func test_every_status_is_whole_scale_and_see_through() -> void:
	var r: Node = Run.new()
	r._sprite_scale = 2.0
	var defs: Dictionary = GameData.load_json("res://assets/data/statuses.json")["statuses"]
	for id: String in defs:
		var d: Dictionary = defs[id]
		var a := float(d.get("alpha", 1.0))
		_check(a >= 0.4 and a <= 0.8, "%s: alpha %s lets the monster show through (0.4..0.8)" % [id, a])
		for radius in [9.5, 13.0, 26.0, 44.0]:
			for s: Array in r.status_spots(radius, bool(d.get("tile", false))):
				_check(is_equal_approx(float(s[1]), roundf(float(s[1]))), "%s on radius %s: whole scale, got %s" % [id, radius, s[1]])
	r.free()


# User 2026-11-20: the flames stood too tall and covered the monster; tiled flames sit along the lower
# half of the body (a row at the feet), never over its upper half.
func test_tiled_flames_sit_low_on_the_body() -> void:
	var r: Node = Run.new()
	r._sprite_scale = 2.0
	for radius in [26.0, 44.0]:
		for s: Array in r.status_spots(radius, true):
			_check((s[0] as Vector2).y >= radius * 0.2, "radius %s: flame at y %s is in the lower half" % [radius, (s[0] as Vector2).y])
	r.free()
