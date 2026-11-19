extends RefCounted
## Mưa thiên thạch (design/events.md, after Risk of Rain 2's Glowing Meteorite): every meteor is marked
## on the ground `warn` seconds before it lands, near the player, never more than `max_marks` at once,
## for `duration` seconds; a mark only hurts what stands inside it when it lands.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _shower() -> MeteorShower:
	var m := MeteorShower.new()
	m.start({"duration": 6.0, "interval": 0.5, "warn": 1.2, "radius": 36.0, "spread": 150.0, "max_marks": 4})
	return m


func test_every_impact_was_marked_for_the_warning_time() -> void:
	var m := _shower()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}   # mark position -> time it appeared
	var t := 0.0
	var impacts := 0
	for k in 160:   # 6 s of marks + the last one's 1.2 s warning
		t += 0.05
		var hits := m.step(0.05, Vector2.ZERO, rng)
		for mk: Dictionary in m.marks:
			if not seen.has(mk["p"]):
				seen[mk["p"]] = t
		for p: Vector2 in hits:
			impacts += 1
			_check(seen.has(p), "an impact at %s was never marked" % p)
			if seen.has(p):
				_check(t - float(seen[p]) >= 1.2 - 0.06, "marked only %.2f s before landing" % (t - float(seen[p])))
		_check(m.marks.size() <= 4, "at most 4 marks at once, got %d" % m.marks.size())
	_check(impacts >= 6, "a 6 s shower drops several meteors, got %d" % impacts)
	_check(not m.active and m.marks.is_empty(), "over after its duration, every mark landed")


func test_marks_fall_near_the_player() -> void:
	var m := _shower()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var player := Vector2(400, -200)
	for k in 40:
		m.step(0.05, player, rng)
		for mk: Dictionary in m.marks:
			_check((mk["p"] as Vector2).distance_to(player) <= 150.0 + 0.01, "mark within spread of the player")


func test_hits_only_inside_the_mark() -> void:
	var m := _shower()
	_check(m.hits(Vector2(10, 0), Vector2(30, 0)), "20 px from the centre of a 36 px mark: hit")
	_check(not m.hits(Vector2(10, 0), Vector2(60, 0)), "50 px away: safe")


func test_marks_never_overlap() -> void:
	# a shot showed two marks drawn over each other: unreadable, and a double hit
	for seed in [1, 2, 3, 4, 5, 6, 7, 8]:
		var m := _shower()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for k in 160:
			m.step(0.05, Vector2.ZERO, rng)
			for i in m.marks.size():
				for j in range(i + 1, m.marks.size()):
					var d := (m.marks[i]["p"] as Vector2).distance_to(m.marks[j]["p"])
					_check(d >= m.radius * 2.0, "seed %d: two marks %.0f px apart (radius %.0f)" % [seed, d, m.radius])
