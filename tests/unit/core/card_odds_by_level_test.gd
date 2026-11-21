extends RefCounted
## User 2026-11-21: the higher the run level, the likelier rare-or-better cards (level 1: 70 / 20 / 7 / 3, shifting
## each level up to a cap); stat cards have no level cap, so a hand is never empty while stat cards remain.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_odds_shift_with_level_and_stop_at_the_caps() -> void:
	var rr := CardRarity.load_default()
	var w1: Array = rr.level_weights(1)
	_check(w1 == [70.0, 20.0, 7.0, 3.0], "level 1: 70/20/7/3, got %s" % [w1])
	var w10: Array = rr.level_weights(10)
	_check(float(w10[0]) < float(w1[0]) and float(w10[3]) > float(w1[3]), "level 10 has fewer commons, more legendaries: %s" % [w10])
	var w99: Array = rr.level_weights(99)
	_check(w99 == rr.level_weights(200), "the odds stop at their caps")
	var total := 0.0
	for x in w99:
		total += float(x)
	_check(is_equal_approx(total, 100.0), "the odds always add to 100, got %s" % total)


func test_stat_cards_are_unlimited_and_keep_the_hand_full() -> void:
	var ups: Array = GameData.load_json("res://assets/data/upgrades_knight.json")["upgrades"]
	var sharpen := {}
	for u: Dictionary in ups:
		if u["id"] == "sharpen":
			sharpen = u
	_check(UpgradeRoller.cap(sharpen) > 1000, "Mài kiếm has no level cap")
	var levels := {"sharpen": 40}
	for u: Dictionary in ups:   # every capped card maxed out
		if UpgradeRoller.cap(u) < 1000:
			levels[u["id"]] = UpgradeRoller.cap(u)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var hand: Array = CardRarity.load_default().roll(ups, levels, 3, rng, "level", 20)
	var fillers := hand.filter(func(id: String) -> bool: return id.begins_with("filler_"))
	_check(hand.size() == 3 and fillers.is_empty(), "with skills maxed the hand is still 3 real cards (stat cards), got %s" % [hand])
