extends RefCounted
## Vật cản (design/obstacles.md, after Brotato's trees/rocks and Vampire Survivors' walled stages): each
## region scatters solid props (seeded, so a stage always looks the same) that block the player and the
## monsters, clear of the start; the marsh adds poison pools that hurt but do not block.

var failures: Array[String] = []

const DEF := {"solid": [{"sprite": "obstacle-rock", "radius": 13.0, "count": 40}],
	"pools": {"count": 10, "radius": 40.0, "dps": 4.0}, "clear_start": 220.0, "spacing": 90.0}


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_scatter_is_seeded_clear_of_the_start_and_spaced() -> void:
	var a := Obstacles.new(DEF, 1400.0, 5)
	var b := Obstacles.new(DEF, 1400.0, 5)
	_check(a.solids.size() >= 30, "most of 40 props placed, got %d" % a.solids.size())
	_check(a.solids.size() == b.solids.size() and a.solids[0]["p"] == b.solids[0]["p"], "same seed, same map")
	for i in a.solids.size():
		var p: Vector2 = a.solids[i]["p"]
		_check(p.length() >= 220.0, "a prop at %s, inside the clear start" % p)
		_check(absf(p.x) <= 1400.0 and absf(p.y) <= 1400.0, "a prop outside the arena")
		for j in range(i + 1, a.solids.size()):
			_check(p.distance_to(a.solids[j]["p"]) >= 90.0, "two props closer than the spacing")
	_check(a.pools.size() >= 5, "pools placed, got %d" % a.pools.size())


func test_push_out_moves_a_body_to_the_edge() -> void:
	var o := Obstacles.new({}, 1400.0, 1)
	o.add_solid(Vector2(100, 0), 13.0, "obstacle-rock")
	var p := o.push_out(Vector2(95, 2), 8.0)
	_check(p.distance_to(Vector2(100, 0)) >= 21.0 - 0.01, "pushed out to 13 + 8 px, got %.2f" % p.distance_to(Vector2(100, 0)))
	_check(o.push_out(Vector2(0, 0), 8.0) == Vector2(0, 0), "far away: untouched")
	var c := o.push_out(Vector2(100, 0), 8.0)
	_check(c.distance_to(Vector2(100, 0)) >= 21.0 - 0.01, "exactly on the centre: still pushed out")


func test_pools_hurt_but_do_not_block() -> void:
	var o := Obstacles.new({}, 1400.0, 1)
	o.add_pool(Vector2(-300, 0), 40.0)
	o.pool_dps = 4.0
	_check(o.in_pool(Vector2(-290, 10)), "inside the pool")
	_check(not o.in_pool(Vector2(-200, 0)), "outside the pool")
	_check(o.push_out(Vector2(-300, 0), 8.0) == Vector2(-300, 0), "a pool does not push")
