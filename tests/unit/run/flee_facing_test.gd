extends RefCounted
## Bug 2026-11-22 (user): the gold goblin ran backwards: every monster faced the player, but a fleeing one
## runs away from it, so it must face its way of running.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_a_fleeing_monster_faces_away_from_the_player() -> void:
	var m: Dictionary = GameData.load_json("res://assets/data/monsters.json")["gold_goblin"].duplicate()
	var sheet := SpriteSheet.from_meta("gold-goblin", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 44.0],
		"body": {"anim": "default", "center": [24.0, 30.0], "radius": 8.0}})
	var e := Enemies.new({"gold_goblin": m}, {"max_enemies": 4, "separation": {"push": 0.0}}, {"gold-goblin": sheet}, 1)
	e.spawn("gold_goblin", Vector2(200, 0))   # right of the player: runs further right
	e.step(0.05, Vector2.ZERO, Vector2.ZERO)
	_check(e.pos[0].x > 200.0, "it runs away (right), x=%s" % e.pos[0].x)
	_check(e.flip[0] == 0, "faces right, its way of running (flip %d)" % e.flip[0])
