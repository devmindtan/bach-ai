extends RefCounted
## Sóng kiếm (design/cleave-wave-redesign.md): a wave hits each monster once, whatever its index after
## swap-removes (uid), while it still hits monsters it meets later.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_a_hit_set_skips_monsters_already_hit() -> void:
	var m: Dictionary = GameData.load_json("res://assets/data/monsters.json")["spore"].duplicate()
	var sheet := SpriteSheet.from_meta("spore", {"frames": 1, "frame_size": [24, 24], "fps": 8.0, "anchor": [12.0, 23.0],
		"body": {"anim": "default", "center": [12.0, 17.0], "radius": 7.0}})
	var e := Enemies.new({"spore": m}, {"max_enemies": 10, "separation": {"push": 0.0}}, {"spore": sheet}, 1)
	e.spawn("spore", Vector2(0, 0))
	e.spawn("spore", Vector2(0, 0))
	_check(e.uid[0] != e.uid[1], "each monster has its own uid")
	var hb := SpriteHitbox.new()
	hb.shape = "circle"
	hb.center = Vector2.ZERO
	hb.radius = 40.0
	var seen := {}
	_check(e.hit_box(hb, 1.0, 0.0, "cleave_wave", [], seen) == 2, "first pass hits both")
	_check(e.hit_box(hb, 1.0, 0.0, "cleave_wave", [], seen) == 0, "second pass hits neither")
	e.spawn("spore", Vector2(0, 0))
	_check(e.hit_box(hb, 1.0, 0.0, "cleave_wave", [], seen) == 1, "a monster met later is still hit")
