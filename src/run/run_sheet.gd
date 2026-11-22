class_name RunSheet
extends RefCounted
## What the character sheet and the level-up cards show, computed from the run's stats and cards:
## skill numbers (skill_info), card previews (upgrade_preview), card effect lines, stat breakdowns,
## "Scale theo" lines. Read-only over the run. Split out of run.gd (roadmap tech debt 6, 2026-11-22);
## run.gd keeps one-line forwarders so panels and tests call the run as before.

var run   # the Run node (untyped: its private helpers are reached by name, as BossView does)


func scale_text(id: String) -> String:
	var sc: Dictionary = run.pool.get("skills", {}).get(id, {}).get("scale", {})
	var parts = []
	for k: String in sc:
		parts.append("%s ×%s" % [String(run.STAT_LABEL.get(k, k)).to_lower(), str(sc[k])])
	return "" if parts.is_empty() else "Scale theo: " + " + ".join(parts)


func card_effect_text(id: String) -> String:
	var u = run.upgrade(id)
	var lv = int(run.levels.get(id, 0))
	var parts = []
	var owned_skills = run.skill_info().map(func(si: Dictionary) -> String: return String(si["name"]))
	for key: String in u.get("effects", {}):
		var e: Dictionary = u["effects"][key]
		if key == "back_slash":
			var ba: Dictionary = run.pool.get("skills", {}).get("blade_arc", {})
			var pct = float(ba.get("back_damage_mul", 0.5)) + float(ba.get("back_damage_per_level", 0.25)) * (lv - 1)
			parts.append("Nhát chém sau %d%% sát thương của Chém kiếm" % roundi(pct * 100.0))
			continue
		var amount: String = ("%+d%%" % roundi(float(e["mul"]) * lv * 100.0)) if e.has("mul") else run.signed(float(e["add"]) * lv)
		if key.begins_with("skill_damage.") or key.begins_with("skill_area."):
			parts.append("%s %s" % ["Sát thương" if key.begins_with("skill_damage.") else "Vùng", amount])
			continue
		var line = "%s %s (hiện %s)" % [run.STAT_LABEL.get(key, key), amount, run._fmt_stat(key, float(run.stats.get(key, 0.0)))]
		if key in ["damage", "cooldown", "area"] and not owned_skills.is_empty():
			line += " · áp lên: " + ", ".join(owned_skills)
		parts.append(line)
	return "\n".join(parts)


func skill_info() -> Array:
	var out = []
	var plain = PlayerStats.compute(run.base_stats, [], {})   # class stats, no cards
	for u: Dictionary in run.pool.get("upgrades", []):
		var id = String(u["id"])
		var lv = int(run.levels.get(id, 0))
		if u.get("kind") != "skill" or lv <= 0:
			continue
		var touches = {"damage": "Sát thương", "cooldown": "Hồi chiêu", "area": "Vùng",
			"skill_damage." + id: "Sát thương", "skill_area." + id: "Vùng", "skill_cd." + id: "Hồi chiêu"}
		var sources = []
		var lv_all = run.effect_levels()
		for v: Dictionary in run.effect_pool():
			var vl = int(lv_all.get(v["id"], 0))
			if vl <= 0:
				continue
			var effects: Dictionary = v.get("effects", {})
			for key: String in effects:
				var e: Dictionary = effects[key]
				if touches.has(key):
					var t: String = ("%+d%%" % roundi(float(e["mul"]) * vl * 100.0)) if e.has("mul") else run.signed(float(e["add"]) * vl)
					sources.append({"id": v["id"], "name": v.get("name", v["id"]), "level": vl, "what": touches[key], "text": t,
						"pct": float(e.get("mul", 0.0)) * vl * 100.0})
				elif key == "back_slash" and id == "blade_arc":
					var ba: Dictionary = run.pool.get("skills", {}).get("blade_arc", {})
					var pct = float(ba.get("back_damage_mul", 0.5)) + float(ba.get("back_damage_per_level", 0.25)) * (vl - 1)
					sources.append({"id": v["id"], "name": v.get("name", v["id"]), "level": vl, "what": "Nhát sau", "text": "%d%%" % roundi(pct * 100.0)})
		out.append({"id": id, "name": u.get("name", id), "level": lv, "max": UpgradeRoller.cap(u),
			"damage": run.skill_damage(id), "cooldown": run.skill_cooldown(id), "size": run.skill_size(id),
			"base_damage": run.skill_damage(id, plain), "base_cooldown": run.skill_cooldown(id, plain), "sources": sources,
			"scale_text": run.scale_text(id),
			"statuses": run.on_hit(id), "count": run.skill_count_now(id), "count_parts": run.count_parts(id)})
	return out


func upgrade_preview(id: String) -> Dictionary:
	var u = run.upgrade(id)
	var lv = int(run.levels.get(id, 0))
	var nxt = lv + 1
	var max_lv = UpgradeRoller.cap(u)
	# "after" is built from the same sources as the current stats (cards, milestones,
	# buffs, equipment, skill tree) plus this card one level up; built from the cards
	# alone it lost every lasting bonus and showed a drop (user 2026-11-18)
	var after_levels = run.effect_levels()
	after_levels[id] = nxt
	var after = run.compute_stats(after_levels)   # the same balance as the run (a raw compute showed 17 -> 23)
	var lines = []
	var skills: Dictionary = run.pool.get("skills", {})
	if u.get("kind") == "skill" and skills.has(id):
		var sp: Dictionary = skills[id]
		lines.append(["Sát thương", "—" if lv == 0 else str(roundi(run.skill_damage(id, run.stats))), str(roundi(run.skill_damage(id, after)))])
		if lv == 0 or not is_equal_approx(run.skill_size(id, run.stats), run.skill_size(id, after)):
			lines.append(["Cỡ", "—" if lv == 0 else "×%.2f" % run.skill_size(id, run.stats), "×%.2f" % run.skill_size(id, after)])
		if sp.has("cooldown"):
			var cd_now = "—" if lv == 0 else "%.1fs" % run.skill_cooldown(id, run.stats)
			lines.append(["Hồi chiêu", cd_now, "%.1fs" % run.skill_cooldown(id, after)])
		# more casts at this level (count grows for dense hordes)
		var now_n = 0 if lv == 0 else run._skill_count(id, sp)
		run.levels[id] = nxt
		var next_n = run._skill_count(id, sp)
		run.levels[id] = lv
		if lv == 0:
			run.levels.erase(id)
		if next_n != now_n and (lv > 0 or next_n > 1):
			lines.append(["Số lượng", "—" if lv == 0 else str(now_n), str(next_n)])
	else:
		for key: String in u.get("effects", {}):
			if key == "back_slash":
				var ba: Dictionary = skills.get("blade_arc", {})
				var pct = func(l: int) -> String:
					return "—" if l <= 0 else "%d%%" % roundi(100.0 * (float(ba.get("back_damage_mul", 0.5)) + float(ba.get("back_damage_per_level", 0.25)) * (l - 1)))
				lines.append(["Nhát chém sau", pct.call(lv), pct.call(nxt)])
			else:
				lines.append([run.STAT_LABEL.get(key, key), run._fmt_stat(key, float(run.stats.get(key, 0.0))), run._fmt_stat(key, float(after.get(key, 0.0)))])
	# milestones: a new look (tier sprite) at a level, and the last level
	var milestones = [max_lv]
	var tiers: Array = skills.get(id, {}).get("tier_sprites", [])
	for i in range(1, tiers.size()):
		if tiers[i] != tiers[i - 1]:
			milestones.append(i + 1)
	var text = ""
	if tiers.size() > 1 and nxt <= tiers.size() and (nxt == 1 or tiers[nxt - 1] != tiers[nxt - 2]):
		text = "Bậc %s · hình mới" % ["I", "II", "III", "IV", "V"][mini(nxt, 5) - 1]
	# a level that adds a status (on_hit "from") is a milestone too
	for e: Dictionary in skills.get(id, {}).get("on_hit", []):
		var f = int(e.get("from", 1))
		if not milestones.has(f):
			milestones.append(f)
		if f == nxt:
			text = (text + " · " if text != "" else "") + "Thêm: " + String(run.status_defs.get(String(e.get("status", "")), {}).get("name", e.get("status", "")))
	if nxt == max_lv:
		text = (text + " · " if text != "" else "") + "Cấp tối đa"
	return {"lines": lines, "milestones": milestones, "milestone": text, "level": lv, "max": max_lv}


func stat_breakdown() -> Dictionary:
	var bd = PlayerStats.breakdown(run.base_stats, run.effect_pool(), run.effect_levels())
	var bal: Dictionary = run.cfg.get("balance", {})
	for pair: Array in [["damage", "player_damage_mul"], ["area", "player_area_mul"]]:
		var m = float(bal.get(pair[1], 1.0))
		if bd.has(pair[0]) and not is_equal_approx(m, 1.0):
			bd[pair[0]]["final"] = float(bd[pair[0]]["final"]) * m
			bd[pair[0]]["parts"].append({"id": "skull", "name": "Độ khó", "level": 0, "mul": m - 1.0})
	# every cast is capped at player.cooldown_floor (skill_cooldown): the sheet shows the same number
	var cd_floor = float(run.cfg.get("player", {}).get("cooldown_floor", 0.0))
	if bd.has("cooldown") and float(bd["cooldown"]["final"]) < cd_floor:
		bd["cooldown"]["final"] = cd_floor
		bd["cooldown"]["capped"] = true
	return bd
	if run.enemies != null:   # Chí mạng: run_config.json crit + any crit_chance / crit_mul effects (6C.2)
		run.enemies.crit_chance = float(run.cfg.get("crit", {}).get("chance", 0.0)) + float(run.stats.get("crit_chance", 0.0))
		run.enemies.crit_mul = float(run.cfg.get("crit", {}).get("mul", 1.75)) + float(run.stats.get("crit_mul", 0.0))
