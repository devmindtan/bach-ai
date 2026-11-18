extends RefCounted
## Mộc Yêu, boss of Rừng Âm U (behaviour "boss_tree", design/bosses.md): roots
## erupt under the player after a warning ring, it calls the forest (wolves,
## wisps), and below rage_at roots come more often and in more places.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _enemies() -> Enemies:
	var tree := {"sprite": "tree", "behaviour": "boss_tree", "boss": true, "hp": 1000.0, "damage": 10.0, "speed": 20.0,
		"xp": 200.0, "root_every": 1.0, "root_count": 3, "root_delay": 0.8, "root_radius": 30.0, "root_damage": 25.0,
		"root_spread": 90.0, "summon_every": 2.0, "summon": ["wolf"], "summon_count": 2,
		"rage_at": 0.5, "rage_root_every": 0.6, "rage_root_count": 5}
	var wolf := {"sprite": "tree", "behaviour": "chase", "hp": 10.0, "damage": 5.0, "speed": 50.0, "xp": 1.0}
	var sheet := SpriteSheet.from_meta("tree", {"frames": 1, "frame_size": [48, 48], "fps": 8.0, "anchor": [24.0, 47.0],
		"body": {"anim": "default", "center": [24.0, 30.0], "radius": 14.0}})
	return Enemies.new({"tree": tree, "wolf": wolf}, {"max_enemies": 40, "separation": {"push": 0.0}}, {"tree": sheet}, 1)


func _step(e: Enemies, seconds: float, player: Vector2) -> float:
	var hit := 0.0
	for k in roundi(seconds * 30.0):
		hit = maxf(hit, e.step(1.0 / 30.0, player, player))
	return hit


func test_roots_warn_then_hit_a_player_who_stays() -> void:
	var e := _enemies()
	e.spawn("tree", Vector2(300, 0))
	e.charge_cd[0] = 0.0
	e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	_check(e.blast_pos.size() == 3, "3 root warnings, got %d" % e.blast_pos.size())
	var under := false
	for p in e.blast_pos:
		under = under or p.distance_to(Vector2.ZERO) < 1.0
	_check(under, "one root aims at where the player stands")
	var hit := _step(e, 0.9, Vector2.ZERO)
	_check(hit >= 25.0, "a player who stays is hit by the root (%.0f)" % hit)
	_check(not e.roots_done.is_empty(), "the eruption is reported for drawing")


func test_calls_the_forest() -> void:
	var e := _enemies()
	e.spawn("tree", Vector2(300, 0))
	_step(e, 0.1, Vector2.ZERO)
	var wolves := 0
	for i in e.count:
		if e.kind_ids[e.kind[i]] == "wolf":
			wolves += 1
	_check(wolves == 2, "summons 2 wolves, got %d" % wolves)


func test_rage_brings_more_roots() -> void:
	var e := _enemies()
	e.spawn("tree", Vector2(300, 0))
	e.hp[0] = 400.0
	e.charge_cd[0] = 0.0
	e.step(1.0 / 30.0, Vector2.ZERO, Vector2.ZERO)
	_check(e.enraged(0), "enraged under 50%")
	_check(e.blast_pos.size() == 5, "5 roots when enraged, got %d" % e.blast_pos.size())
