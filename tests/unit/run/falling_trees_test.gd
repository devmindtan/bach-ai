extends RefCounted
## Cây đổ (design/region-events-plan.md §4B, §8): one hit per tree, falls toward the player, trunk walls.

const CFG := {"waves": 3, "interval": 2.5, "warn": 1.2, "range": 300.0, "length": 150.0, "width": 46.0, "linger": 4.0}

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_three_trees_fall_toward_the_player_once_each() -> void:
	var t := FallingTrees.new()
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var feet := [Vector2(100, 0), Vector2(0, 120), Vector2(-90, 0), Vector2(900, 0)]
	t.start(CFG)
	var landed := []
	for i in 200:   # 10 s
		landed.append_array(t.step(0.05, Vector2.ZERO, feet, r))
	_check(landed.size() == 3, "3 trees fell (%d)" % landed.size())
	for f: Dictionary in landed:
		_check(t.hits(f, Vector2.ZERO), "each falls over the player's spot")
		_check((f["a"] as Vector2).distance_to(Vector2.ZERO) <= 300.0, "only trees in range")
	_check(not t.hits(landed[0], Vector2(0, -400)), "far away is safe")


func test_trunk_is_a_wall_then_goes() -> void:
	var t := FallingTrees.new()
	t.start(CFG)
	t.logs.append({"a": Vector2.ZERO, "d": Vector2.RIGHT, "t": 4.0})
	var p := t.push_out(Vector2(60, 2), 10.0)
	_check(absf(p.y) >= 10.0, "a body on the trunk is pushed off sideways (%s)" % p)
	t.logs[0]["t"] = 0.01
	t.step(0.05, Vector2.ZERO, [], RandomNumberGenerator.new())
	_check(t.logs.is_empty(), "trunk gone after linger")
