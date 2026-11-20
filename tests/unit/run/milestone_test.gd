extends RefCounted
## Unit tests for the milestone rewards in a run (design/progression.md): each
## reward the slot owns has its effect — unique skills start at level 1, the
## passives (Khát máu / Hộ thể / Bất tử) and the rules (Song kích / Thêm lựa
## chọn / Bứt tốc), and levels 10/20/30 of a run queue the pick.

const Run := preload("res://src/run/run.gd")

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## A run set up the way _ready does, minus the scene: class pool, base stats and
## the milestone rewards the slot owns.
func _run(cls: String, levels: Dictionary, rewards: Array = []) -> Node:
	var r: Node = Run.new()
	var classes := GameData.load_json("res://assets/data/classes.json")
	r.class_data = classes[cls]
	r.pool = GameData.load_json("res://assets/data/" + String(classes[cls]["upgrades"]))
	r.base_stats = classes[cls]["stats"]
	r.levels = levels.duplicate()
	r.milestones = Milestones.load_default()
	for id: String in rewards:
		r.rewards.append(id)
	r.apply_rewards()
	r._recompute_stats()
	r.hp = float(r.stats["max_hp"])
	return r


func _buffs(r: Node) -> void:
	var items := GameData.load_json("res://assets/data/items.json")
	r.buffs = Buffs.new(items.get("buffs", {}), {}, 1)
	r._recompute_stats()


# --- special cards (the former item specials, user 2026-11-20) ---------------

func test_special_card_reward_works_at_once_with_one_level() -> void:
	var r := _run("mage", {}, ["sp_star_pants"])
	_check(int(r.levels.get("sp_star_pants", 0)) == 1, "Hoả y owned at its one level, got %s" % r.levels.get("sp_star_pants"))
	var kinds: Array = r.specials.map(func(sp: Dictionary) -> String: return String(sp.get("kind", "")))
	_check(kinds.has("burn_aura"), "its special runs from the start, got %s" % [kinds])
	var none := _run("mage", {}, [])
	_check(not none.levels.has("sp_star_pants"), "without the reward the card is not in the run")
	r.free()
	none.free()


func test_other_class_special_card_is_not_offered() -> void:
	var m := Milestones.load_default()
	_check(m.offers(10, "knight").has("sp_aegis_boots") and not m.offers(10, "knight").has("sp_star_pants"),
		"level 10 offers the knight its own cards only, got %s" % [m.offers(10, "knight")])


func test_legendary_skills_are_deck_cards_now() -> void:
	var r := _run("knight", {}, [])
	for u: Dictionary in r.pool.get("upgrades", []):
		if String(u["id"]) in ["earthquake", "solar_ray", "god_hammer"]:
			_check(not bool(u.get("unique", false)), "%s is a normal (legendary) card, not a milestone" % u["id"])
	r.free()


# --- passives ----------------------------------------------------------------

func test_bloodthirst_heals_on_elite_and_boss_kills() -> void:
	var plain := _run("knight", {"blade_arc": 1}, [])
	_check(is_zero_approx(plain.heal_on_kill()), "no reward: no heal")
	var r := _run("knight", {"blade_arc": 1}, ["bloodthirst"])
	_check(is_equal_approx(r.heal_on_kill(), 0.2), "Khát máu heals 20%%, got %s" % r.heal_on_kill())
	r.hp = float(r.stats["max_hp"]) * 0.5
	var healed: float = r.heal_max(r.heal_on_kill())
	_check(is_equal_approx(healed, float(r.stats["max_hp"]) * 0.2), "healed %s" % healed)
	_check(is_equal_approx(r.hp, float(r.stats["max_hp"]) * 0.7), "hp now 70%%, got %s" % r.hp)
	r.heal_max(0.9)
	_check(is_equal_approx(r.hp, float(r.stats["max_hp"])), "never over max hp")
	plain.free()
	r.free()


func test_guardian_gives_itself_the_shield_every_25_seconds() -> void:
	var r := _run("knight", {"blade_arc": 1}, ["guardian"])
	_buffs(r)
	r._step_guardian(24.0)
	_check(not r.buffs.is_active("magnetic_shield"), "not yet at 24 s")
	r._step_guardian(1.5)
	_check(r.buffs.is_active("magnetic_shield"), "shield at 25 s")
	_check(is_equal_approx(r.buffs.time_left("magnetic_shield"), 4.0), "for 4 s, got %s" % r.buffs.time_left("magnetic_shield"))
	_check(r.buffs.invulnerable(), "the shield makes the hero immune")
	r.buffs.step(4.5, Vector2.ZERO)
	_check(not r.buffs.is_active("magnetic_shield"), "then it runs out")
	r.free()


func test_undying_revives_once_per_run() -> void:
	var plain := _run("knight", {"blade_arc": 1}, [])
	plain.hp = 0.0
	_check(not plain.try_undying(), "no reward: no revive")
	var r := _run("knight", {"blade_arc": 1}, ["undying"])
	r.hp = -3.0
	_check(r.try_undying(), "Bất tử revives the hero")
	_check(is_equal_approx(r.hp, float(r.stats["max_hp"]) * 0.5), "with half hp, got %s" % r.hp)
	_check(is_equal_approx(r.invuln, 2.0), "and 2 s of immunity, got %s" % r.invuln)
	r.hp = 0.0
	_check(not r.try_undying(), "once per run only")
	_check(is_zero_approx(r.hp), "the second death is real")
	plain.free()
	r.free()


# --- rules -------------------------------------------------------------------

# User 2026-11-20: Đa phép adds one to the skills the hero has when it is picked, not to skills learnt later.
func test_twin_cast_adds_one_only_to_skills_owned_when_picked() -> void:
	var r := _run("mage", {"arcane_bolt": 1, "fireball": 1}, [])
	var fb: Dictionary = r.pool["skills"]["fireball"]
	var lt: Dictionary = r.pool["skills"]["lightning"]
	var before: int = r._skill_count("fireball", fb)
	r.levels["lightning"] = 1   # learnt later: measure its count without Đa phép first
	var lt_plain: int = r._skill_count("lightning", lt)
	r.levels.erase("lightning")
	r.take_milestone("twin_cast")
	_check(r._skill_count("fireball", fb) == before + 1, "owned fireball +1: %d -> %d" % [before, r._skill_count("fireball", fb)])
	r.levels["lightning"] = 1
	r.apply_rewards()   # runs again on later picks: must not add twice nor reach the new skill
	_check(r._skill_count("lightning", lt) == lt_plain, "lightning learnt later is not boosted: %d vs %d" % [r._skill_count("lightning", lt), lt_plain])
	_check(r._skill_count("fireball", fb) == before + 1, "fireball still +1 only, got %d" % r._skill_count("fireball", fb))
	r.free()


func test_wide_choice_offers_four_cards() -> void:
	var plain := _run("knight", {}, [])
	_check(plain.level_up_card_count() == 3, "normally 3 cards")
	var r := _run("knight", {}, ["wide_choice"])
	_check(r.level_up_card_count() == 4, "Thêm lựa chọn: 4 cards, got %d" % r.level_up_card_count())
	plain.free()
	r.free()


func test_head_start_gives_two_picks_at_once() -> void:
	var r := _run("knight", {}, [])
	r.pending_levels = 0
	r.take_milestone("head_start")
	_check(r.pending_levels == 2, "Bứt tốc: 2 card picks at once, got %d" % r.pending_levels)
	r.free()


# --- level milestones in a run ------------------------------------------------

func test_level_10_20_30_queue_their_pick_once() -> void:
	var r := _run("mage", {}, [])
	r._queue_milestones(8, 11)
	_check(r._ms_queue == [10], "passing level 10 queues it, got %s" % [r._ms_queue])
	r._queue_milestones(9, 10)
	_check(r._ms_queue == [10], "not twice")
	r._queue_milestones(19, 31)
	_check(r._ms_queue == [10, 20, 30], "a big jump queues each, got %s" % [r._ms_queue])
	r._queue_milestones(1, 9)
	_check(r._ms_queue.size() == 3, "levels below 10 queue nothing")
	r.free()


func test_take_milestone_starts_a_special_card_for_this_run() -> void:
	var r := _run("mage", {"arcane_bolt": 1}, [])
	_check(int(r.levels.get("sp_star_staff", 0)) == 0, "no special card before the pick")
	r.take_milestone("sp_star_staff")
	_check(int(r.levels.get("sp_star_staff", 0)) == 1 and r.rewards.has("sp_star_staff"), "Vĩnh cửu at level 1 after the pick")
	_check(r.specials.any(func(sp: Dictionary) -> bool: return sp.get("kind") == "reset_cd"), "its special runs right after the pick")
	r.free()


# --- the character sheet -----------------------------------------------------

func test_milestone_rows_describe_each_owned_reward() -> void:
	var r := _run("mage", {}, ["sp_star_hat", "wide_choice"])
	var rows: Array = r.milestone_rows()
	_check(rows.size() == 2, "two rows for two rewards, got %d" % rows.size())
	if rows.size() == 2:
		_check(rows[0]["name"] == "Lôi ấn" and rows[0]["kind"] == "Thẻ đặc biệt",
			"skill row: %s / %s" % [rows[0].get("name"), rows[0].get("kind")])
		_check(String(rows[0]["desc"]) != "" and String(rows[0]["icon"]) == "sp_star_hat", "card row needs its card text and icon")
		_check(rows[1]["name"] == "Thêm lựa chọn" and rows[1]["kind"] == "Luật", "rule row: %s" % rows[1].get("name"))
	_check(_run("knight", {}, []).milestone_rows().is_empty(), "no rewards: no rows")
	r.free()


# --- level-up panel title (user 2026-11-18: many picks in a row, source unclear) ---

func test_level_up_title_names_source_level_and_picks_left() -> void:
	var r := _run("mage", {})
	r.level = 12
	r.pending_levels = 3
	var t := String(r.level_up_title(false))
	_check(t.contains("12") and t.contains("còn 2"), "XP pick title names level 12 and 2 more, got '%s'" % t)
	r.pending_levels = 1
	t = String(r.level_up_title(false))
	_check(not t.contains("còn"), "last pick has no 'còn', got '%s'" % t)
	t = String(r.level_up_title(true))
	_check(t.contains("Rương"), "chest pick names the chest, got '%s'" % t)
	r.free()


# --- level-up views (user 2026-11-18: hide the cards or open the character sheet
# while choosing, to pick the right upgrade) ---

func test_level_up_view_toggles_between_cards_character_and_hidden() -> void:
	var r := _run("mage", {})
	r.state = r.State.LEVEL_UP
	_check(r.level_view == "cards", "the cards show first")
	r.toggle_level_view("character")
	_check(r.level_view == "character", "Tab opens the character sheet")
	r.toggle_level_view("character")
	_check(r.level_view == "cards", "Tab again goes back to the cards")
	r.toggle_level_view("hidden")
	_check(r.level_view == "hidden", "H hides the cards")
	r.toggle_level_view("character")
	_check(r.level_view == "character", "Tab from hidden opens the sheet")
	r.state = r.State.PLAYING
	r.level_view = "cards"
	r.toggle_level_view("hidden")
	_check(r.level_view == "cards", "no level-up view while playing")
	r.free()


func test_tab_reaches_the_level_up_before_gui_focus() -> void:
	# user 2026-11-18: Tab moved focus between the cards instead of opening the sheet
	# (GUI focus eats Tab before _unhandled_input), so run._input takes it first
	RunInput.register()
	var r := _run("mage", {})
	r.state = r.State.LEVEL_UP
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	_check(r.has_method("_input"), "run handles level-up keys in _input")
	if r.has_method("_input"):
		r._input(ev)
	_check(r.level_view == "character", "Tab opens the character sheet, got %s" % r.level_view)
	r.free()


func test_level_ups_offer_only_the_deck() -> void:
	# design/skill-tree-v2.md §2: a run offers only the active deck's cards (plus milestone uniques)
	var r := _run("knight", {})
	r.deck_cards = ["blade_arc", "sharpen"]
	var ids := []
	for u: Dictionary in r.deck_pool():
		ids.append(String(u["id"]))
	_check(ids.has("blade_arc") and ids.has("sharpen"), "deck cards are offered")
	_check(not ids.has("whirlwind") and not ids.has("haste"), "cards outside the deck are not, got %s" % [ids])
	r.free()


func test_card_tree_nodes_change_the_skill_in_the_run() -> void:
	# design/skill-tree-v2.md §3: bought nodes apply to the skill from the moment it is taken
	var r := _run("knight", {"blade_arc": 1})
	var s := Slot.new({})
	s.card_trees = {"blade_arc": {"keen": 3, "quick": 2, "twin": 1, "bleed": 1}}
	r.tree_owner = s
	r._recompute_stats()
	var plain := _run("knight", {"blade_arc": 1})
	_check(absf(r.skill_damage("blade_arc") / plain.skill_damage("blade_arc") - 1.5 / 1.2) < 0.01, "Lưỡi bén x3 adds +30%% to the card mul (1.2 -> 1.5)")
	_check(r.skill_count_now("blade_arc") == plain.skill_count_now("blade_arc") + 1, "Chém đôi adds a slash")
	var st := []
	for e: Dictionary in r.on_hit("blade_arc"):
		st.append(String(e["status"]))
	_check(st.has("bleed"), "Rỉ máu adds bleeding on hit, got %s" % [st])
	r.free()
	plain.free()
