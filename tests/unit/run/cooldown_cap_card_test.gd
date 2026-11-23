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


## User 2026-11-23: the cap does not touch timed buffs: at the cap, Rune tốc độ (-25% for 8 s) still shortens casts.
func test_timed_buff_goes_past_the_cap() -> void:
	var r := _run("knight", "haste", 4)   # permanent -40%: at the cap
	r.buffs = Buffs.new(GameData.load_json("res://assets/data/items.json")["buffs"], r.cfg.get("buffs", {}), 1)
	r._recompute_stats()
	var capped: float = r.skill_cooldown("blade_arc")
	r.buffs.active["haste_rune"] = 8.0
	r._recompute_stats()
	var with_buff: float = r.skill_cooldown("blade_arc")
	if not is_equal_approx(with_buff, capped * 0.75):
		failures.append("with the rune %s, want %s (capped %s x 0.75)" % [with_buff, capped * 0.75, capped])
	var ids: Array = r.deck_pool().map(func(u: Dictionary) -> String: return String(u["id"]))
	if ids.has("haste"):
		failures.append("the rune made the capped card come back... it should stay gone")
	r.free()
