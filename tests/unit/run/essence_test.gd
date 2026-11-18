extends RefCounted
## Tinh hoa (design/skill-tree.md): elites drop 1, bosses 10 (run_config.json
## "essence"); picked up like the other drops and counted for the slot.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_essence_is_picked_up_and_counted() -> void:
	var p := Pickups.new({"radius": 70.0, "magnet_speed": 520.0, "collect_radius": 14.0}, 10)
	p.drop(Pickups.ESSENCE, Vector2(2, 0), 3.0)
	var got := p.step(0.016, Vector2.ZERO, 1.0)
	_check(p.essence == 3, "3 Tinh hoa picked up, got %d" % p.essence)
	_check(is_zero_approx(got.x) and is_zero_approx(got.y), "not counted as xp or gold")


func test_elites_and_bosses_drop_the_configured_amount() -> void:
	var Run := load("res://src/run/run.gd")
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	_check(r.essence_drop(true, false) == 1, "an elite drops 1, got %d" % r.essence_drop(true, false))
	_check(r.essence_drop(false, true) == 10, "a boss drops 10, got %d" % r.essence_drop(false, true))
	_check(r.essence_drop(false, false) == 0, "a plain monster drops none")
	r.free()
