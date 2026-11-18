extends RefCounted
## Integration: every skill in every class pool meets the "must" gameplay rules
## of assets/data/gameplay_rules.json (design/gameplay-rules.md). The studio
## dashboard (sprite-lab/build_games_manifest.py) grades with the same rules.

const DATA := "res://assets/data/"
const SPRITES := "res://assets/sprites/custom/"
const PLAY_PREF := ["slash_right", "spin", "fly", "burst", "spell", "attack"]
const DIRS := ["slash_right", "slash_left", "slash_up", "slash_down"]

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


## Animations the game plays for an effect sprite (all slash_* or the first preferred).
static func played(sheet: SpriteSheet) -> Array[String]:
	var out: Array[String] = []
	for n in sheet.animation_names():
		if n.begins_with("slash_"):
			out.append(n)
	if out.is_empty():
		for p in PLAY_PREF:
			if sheet.has_animation(p):
				out.append(p)
				break
	if out.is_empty() and not sheet.animation_names().is_empty():
		out.append(sheet.animation_names()[0])
	return out


func _skills() -> Array:
	# [skill_id, class_id, class dict, upgrade dict, skill params]
	var out := []
	var classes := GameData.load_json(DATA + "classes.json")
	for cid: String in classes:
		if cid.begins_with("_"):
			continue
		var pool := GameData.load_json(DATA + String(classes[cid].get("upgrades", "")))
		for u: Dictionary in pool.get("upgrades", []):
			if u.get("kind") == "skill" and pool.get("skills", {}).has(u["id"]):
				out.append([String(u["id"]), cid, classes[cid], u, pool["skills"][u["id"]]])
	return out


func _sheets(params: Dictionary, id: String) -> Array[SpriteSheet]:
	var names: Array = params.get("tier_sprites", [params.get("sprite", id)])
	var out: Array[SpriteSheet] = []
	for n: Variant in names:
		out.append(SpriteSheet.load_dir(SPRITES + String(n), String(n)))
	return out


func test_rules_file_lists_known_rules() -> void:
	var doc := GameData.load_json(DATA + "gameplay_rules.json")
	var known := ["auto", "hitbox", "screen", "snappy", "directional", "levels", "small", "class", "dps", "fx_craft"]
	for r: Dictionary in doc.get("rules", []):
		_check(known.has(r.get("id")), "unknown rule id %s (checks are code)" % r.get("id"))
		_check(["must", "should"].has(r.get("severity")), "rule %s: severity must|should" % r.get("id"))


func test_skills_meet_must_rules() -> void:
	var doc := GameData.load_json(DATA + "gameplay_rules.json")
	var lim: Dictionary = doc.get("limits", {})
	var scale := float(GameData.load_json(DATA + "run_config.json").get("world", {}).get("sprite_scale", 2))
	for entry: Array in _skills():
		var id: String = entry[0]
		var cls: Dictionary = entry[2]
		var up: Dictionary = entry[3]
		var p: Dictionary = entry[4]
		if String(p.get("cast", "")) == "active":
			continue   # player-triggered movement skill (dash): the rules grade auto attacks
		var stats: Dictionary = cls.get("stats", {})
		# auto: cooldown in range
		var cd := float(p["cooldown"]) if p.has("cooldown") else float(stats.get("cooldown", 1.0)) * float(p.get("cooldown_mul", 1.0))
		_check(cd >= float(lim["cooldown_min"]) and cd <= float(lim["cooldown_max"]), "%s [auto]: cooldown %.2f out of range" % [id, cd])
		# levels
		var n := int(up.get("max_level", 1))
		_check(n >= int(lim["levels_min"]) and n <= int(lim["levels_max"]), "%s [levels]: %d levels" % [id, n])
		var eff: Dictionary = up.get("effects", {})
		var grows := false
		for k: String in eff:
			if (k == "skill_damage." + id or k == "skill_area." + id) and float(eff[k].get("mul", 0.0)) > 0.0:
				grows = true
		_check(grows, "%s [levels]: no per-level damage or size growth" % id)
		if p.has("tier_sprites"):
			_check(p["tier_sprites"].size() == n, "%s [levels]: %d tier sprites for %d levels" % [id, p["tier_sprites"].size(), n])
		# sprite rules
		var area_mul := maxf(0.2, 1.0 + float(eff.get("skill_area." + id, {}).get("mul", 0.0)) * n)
		var size_max := float(stats.get("area", 1.0)) * float(p.get("size_mul", 1.0)) * area_mul
		var reach := 0.0
		var flies := false
		for sheet in _sheets(p, id):
			_check(sheet != null, "%s: sprite missing" % id)
			if sheet == null:
				continue
			# px_scale 0.5 (icefx): drawn at double density, the logical size is what counts
			var px := float(sheet.meta.get("px_scale", 1.0))
			var fw := sheet.frame_size.x
			var fh := sheet.frame_size.y
			var ok_w := fw * px <= float(lim["frame_max"]) and fw <= float(lim["frame_max_dense"])
			var ok_h := fh * px <= float(lim["frame_max_tall"]) and (px == 1.0 or fh <= 2.0 * float(lim["frame_max_tall"]))
			_check(ok_w and ok_h, "%s [small]: %s frame %s" % [id, sheet.name, sheet.frame_size])
			var names := sheet.animation_names()
			if Array(names).any(func(x: String) -> bool: return x.begins_with("slash_")):
				for d in DIRS:
					_check(sheet.has_animation(d), "%s [directional]: %s lacks %s" % [id, sheet.name, d])
			for an in played(sheet):
				var a := sheet.animation(an)
				var hb: Variant = a.get("hitbox")
				_check(hb is Dictionary, "%s [hitbox]: %s/%s has no hitbox" % [id, sheet.name, an])
				if not hb is Dictionary:
					continue
				flies = flies or an == "fly"
				var r := maxf(float(hb.get("half_w", 0)), float(hb.get("half_h", 0))) if hb.get("shape") == "rect" else float(hb.get("radius", 0))
				reach = maxf(reach, r * scale * size_max * px)
				if bool(a.get("loop", true)):
					_check(p.has("duration"), "%s [snappy]: %s loops but the skill has no duration" % [id, an])
				else:
					# the readable part (to the end of the hits) is short; an ending may follow (user 2026-11-18)
					var act: Array = hb.get("active", [0, 0])
					var hit_end := SpriteHitbox.frame_time(a, int(act[1]) + 1)
					_check(hit_end <= float(lim["oneshot_max"]), "%s [snappy]: %s hits until %.2fs" % [id, an, hit_end])
					_check(sheet.duration(an) - hit_end <= float(lim["outro_max"]), "%s [snappy]: %s ending lasts %.2fs" % [id, an, sheet.duration(an) - hit_end])
					var start := SpriteHitbox.frame_time(a, int(hb.get("active", [0])[0]))
					_check(start <= float(lim["active_start_max"]), "%s [snappy]: %s first hits at %.2fs" % [id, an, start])
		_check(reach <= float(lim["reach_max"]) and (flies or reach >= float(lim["reach_min"])), "%s [screen]: reach %.0f px" % [id, reach])
		_check(float(p.get("cast_range", 0.0)) <= float(lim["cast_range_max"]), "%s [screen]: cast_range %s" % [id, p.get("cast_range")])


## fx_craft (user 2026-11-18): every effect sprite drawn to the new standard (it has
## px_scale) must keep it: enough frames, a lead-in before the hits, an ending after
## them, double density. Older sprites only warn on the dashboard until redrawn.
func test_redrawn_effects_meet_fx_craft() -> void:
	var lim: Dictionary = GameData.load_json(DATA + "gameplay_rules.json").get("limits", {})
	var seen := {}
	for entry: Array in _skills():
		var p: Dictionary = entry[4]
		var names: Array = p.get("tier_sprites", [p.get("sprite", entry[0])]).duplicate()
		names.append_array(p.get("impact_tiers", []))
		for n: Variant in names:
			if seen.has(n):
				continue
			seen[n] = true
			var sh := SpriteSheet.load_dir(SPRITES + String(n), String(n))
			if sh == null or not sh.meta.has("px_scale"):
				continue
			_check(is_equal_approx(float(sh.meta["px_scale"]), float(lim["fx_px_scale"])), "%s [fx_craft]: px_scale %s" % [n, sh.meta["px_scale"]])
			for an in sh.animation_names():
				var a := sh.animation(an)
				if an.begins_with("fly") or an.begins_with("slash") or bool(a.get("loop", false)):
					continue
				var hb: Dictionary = a.get("hitbox", {})
				var act: Array = hb.get("active", [0, 0])
				_check(int(a.get("frames", 0)) >= int(lim["fx_frames_min"]), "%s/%s [fx_craft]: %d frames" % [n, an, int(a.get("frames", 0))])
				# the hit area is measured from a drawn hit mask, not the art: rays, debris and
				# bolts made areas 2x too big (user 2026-11-18)
				_check(bool(a.get("hit_mask", false)), "%s/%s [fx_craft]: hitbox not measured from a hit mask" % [n, an])
				_check(int(act[0]) >= int(lim["fx_lead_frames"]), "%s/%s [fx_craft]: no lead-in before the hit" % [n, an])
				var outro := sh.duration(an) - SpriteHitbox.frame_time(a, int(act[1]) + 1)
				_check(outro >= float(lim["fx_outro_min"]) - 0.001, "%s/%s [fx_craft]: ending only %.2fs" % [n, an, outro])
