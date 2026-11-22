class_name LevelFlow
extends RefCounted
## The level-up flow of a run: opening the card panel (level or chest), Đổi / Loại / Bỏ qua, choosing a
## card and applying it, the level log, the panel views. Split out of run.gd (roadmap tech debt 6, 2026-11-22);
## run.gd keeps forwarders for what panels and tests call (choose, reroll, banish, skip_level, ...).

var run   # the Run node (untyped: its private helpers are reached by name, as BossView does)


## --log-levels: every source of a level-up pick, with the clock (diagnosis).
func log_level(what: String) -> void:
	if OS.get_cmdline_user_args().has("--log-levels"):
		printerr("LEVEL %6.1fs pending %d: %s" % [run.clock, run.pending_levels, what])


## Level-up panel title: where the pick comes from and how many more wait
## (user 2026-11-18: several picks in a row read as a bug without it).
func title(chest: bool) -> String:
	var head = "Rương vàng! Chọn một" if run._gold_left > 0 else ("Rương báu! Chọn một" if chest else "Lên cấp %d! Chọn một" % run.level)
	var left = run.pending_levels - 1
	return head + (" (còn %d lượt)" % left if left > 0 else "")


func open() -> void:
	# a milestone reached comes first: one of three rewards for the rest of the run
	if not run._ms_queue.is_empty() and run.milestones != null:
		run.ms_level = run._ms_queue.pop_front()
		run._ms_done.append(run.ms_level)
		var offers = run.milestones.offers(run.ms_level, run.class_id).filter(func(id: String) -> bool: return not run.rewards.has(id))
		if not offers.is_empty():
			run.choices.assign(offers)
			run.state = run.State.LEVEL_UP
			run._demo_pick_t = 0.0
			Sfx.play("milestone")
			run._panels.show_milestone_pick(run.ms_level, run.choices)
			return
		run.ms_level = 0
	run.ms_level = 0
	run.deal_hand()
	if not run.offer.is_empty():
		run.choices = run.offer.duplicate()
		run.offer.clear()
	if run.choices.is_empty():
		run.pending_levels = 0
		run.hp = float(run.stats["max_hp"])
		return
	run.state = run.State.LEVEL_UP
	run._demo_pick_t = 0.0
	if not run._chest_open:
		Sfx.play("level_up")
	run.level_view = "cards"
	run._panels.show_level_up(run.choices, title(run._chest_open))
	run._chest_open = false
	run._gold_left = maxi(0, run._gold_left - 1)
	if run._level_view_arg != "":
		run.toggle_level_view(run._level_view_arg)
		run._level_view_arg = ""


## Level-up views (design/ux/level-up.md): [param v] "character" or "hidden"
## opens that view; asking for the open one goes back to the cards. Only while
## choosing; the run stays paused in every view.
func toggle_view(v: String) -> void:
	if run.state != run.State.LEVEL_UP:
		return
	run.level_view = "cards" if run.level_view == v else v
	if run._panels == null:
		return
	match run.level_view:
		"character": run._panels.show_character()
		"hidden": run._panels.show_peek()
		_: run._panels.reshow()


## Charges of Đổi / Loại / Bỏ qua for a new run (run_config.json level_actions, 6C.3).
func reset_actions() -> void:
	var la: Dictionary = run.cfg.get("level_actions", {})
	run.rerolls = int(la.get("reroll", 0))
	run.banishes = int(la.get("banish", 0))
	run.skips = int(la.get("skip", 0))
	run.banished.clear()


## Đổi: a new hand for one charge; false (nothing changes) without one.
func reroll() -> bool:
	if run.rerolls <= 0 or not run._can_act():
		return false
	run.rerolls -= 1
	run.deal_hand()
	run._flip_reshow()
	return true


## Loại: card [param index] leaves the deck for the rest of the run, then a new hand.
func banish(index: int) -> bool:
	if run.banishes <= 0 or not run._can_act() or index < 0 or index >= run.choices.size():
		return false
	run.banishes -= 1
	run.banished.append(run.choices[index])
	run.deal_hand()
	run._flip_reshow()
	return true


## Bỏ qua: the level is used without a card, for skip_gold gold.
func skip_level() -> bool:
	if run.skips <= 0 or not run._can_act():
		return false
	run.skips -= 1
	run.gold += int(run.cfg.get("level_actions", {}).get("skip_gold", 0))
	Sfx.play("coin")
	log_level("skip -> +gold")
	run.pending_levels -= 1
	run.state = run.State.PLAYING
	if run._panels == null:
		return true
	run._panels.hide_all()
	if run.pending_levels > 0:
		open()
	return true


## Applies choice [param index] of the open level-up and continues the run.
func choose(index: int) -> void:
	if run.state != run.State.LEVEL_UP or index >= run.choices.size():
		return
	var id = run.choices[index]
	if id.begins_with("filler_"):   # Túi vàng / Linh đan: no level, a small gift
		var f = run.upgrade(id)
		run.gold += int(f.get("gold", 0))
		run.hp = minf(float(run.stats["max_hp"]), run.hp + float(run.stats["max_hp"]) * float(f.get("heal", 0.0)))
		run._after_pick()
		return
	if run.ms_level > 0:
		run.take_milestone(id)
		return
	if run.skill_pick > 0:   # the skill a count card goes on
		run.add_skill_extra(id, run.skill_pick)
		run.skill_pick = 0
		run._after_pick()
		return
	run.levels[id] = int(run.levels.get(id, 0)) + 1
	if run.upgrade(id).has("special"):   # a special card: the run's specials change (their timers restart)
		run.set_specials(run.card_specials())
	var n_pick = int(run.upgrade(id).get("pick_skill", 0))
	if n_pick > 0 and not run.skill_pick_ids().is_empty():
		# Thêm đòn / Thêm phép: the player now picks the one skill it adds to
		run.skill_pick = n_pick
		run.choices = run.skill_pick_ids()
		run._demo_pick_t = 0.0
		if run._panels != null:
			run._panels.show_skill_pick(String(run.upgrade(id).get("name", id)), run.choices)
		return
	run._after_pick()
