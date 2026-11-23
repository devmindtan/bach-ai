extends RefCounted
## User 2026-11-23: the cooldown cards (Nhanh tay / Niệm nhanh) say their cap, and once the total reduction
## reaches it (run_config player.cooldown_floor) they are no longer offered.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _run(cls: String, card: String, lv: int) -> Node:
	var r: Node = Run.new()
	r.cfg = GameData.load_json("res://assets/data/run_config.json")
	r.pool = GameData.load_json("res://assets/data/upgrades_%s.json" % cls)
	r.base_stats = GameData.load_json("res://assets/data/classes.json")[cls]["stats"]
	r.levels = {card: lv}
	r._recompute_stats()
	return r


func test_cooldown_card_leaves_the_deck_at_the_cap() -> void:
	for pair in [["knight", "haste"], ["mage", "quick_cast"]]:
		var low := _run(pair[0], pair[1], 1)
		var ids: Array = low.deck_pool().map(func(u: Dictionary) -> String: return String(u["id"]))
		if not ids.has(pair[1]):
			failures.append("%s offered below the cap" % pair[1])
		low.free()
		var top := _run(pair[0], pair[1], 4)
		ids = top.deck_pool().map(func(u: Dictionary) -> String: return String(u["id"]))
		if ids.has(pair[1]):
			failures.append("%s still offered at the cap (cooldown x%s)" % [pair[1], top.stats.get("cooldown")])
		top.free()


func test_cooldown_card_text_names_the_cap() -> void:
	var floor_mul := float(GameData.load_json("res://assets/data/run_config.json")["player"]["cooldown_floor"])
	var want := "tối đa %d%%" % roundi((1.0 - floor_mul) * 100.0)
	for pair in [["knight", "haste"], ["mage", "quick_cast"]]:
		for u: Dictionary in GameData.load_json("res://assets/data/upgrades_%s.json" % pair[0])["upgrades"]:
			if u["id"] == pair[1] and not String(u["desc"]).contains(want):
				failures.append("%s desc should say '%s': %s" % [pair[1], want, u["desc"]])


## User 2026-11-23 screenshot: Niệm nhanh showed "-80% → -80%" while every cast stops at -40%.
func test_cooldown_shown_never_passes_the_cap() -> void:
	Run._cd_floor = 0.6
	var shown := Run._fmt_stat("cooldown", 0.2)
	var at_cap := Run._fmt_stat("cooldown", 0.6)
	var under := Run._fmt_stat("cooldown", 0.9)
	Run._cd_floor = 0.0
	if shown != "-40% (tối đa)" or at_cap != "-40% (tối đa)" or under != "-10%":
		failures.append("shown %s / %s / %s" % [shown, at_cap, under])
