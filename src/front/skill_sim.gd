class_name SkillSim
extends Control
## The Album's skill preview (design/ux/album.md "mô phỏng"): the hero on the left casts the skill at a slime
## dummy on the right with the game's own sprites, looping; every loop shows the next tier's look (Bậc I..V)
## and the dummy flashes when the hit lands.
##
## Kinds, from the skill's data (upgrades_<class>.json "skills"):
##   "projectile" (has speed): flies hero -> dummy, then its impact sprite;
##   "self" (under_hero, or the dash): plays on the hero;
##   "melee" (blade_arc: offset): just in front of the hero, facing the dummy;
##   "target" (everything else): plays on the dummy.
##
## Example:
##   var s := SkillSim.new(); s.setup(skill_dict, "swordsman"); s.custom_minimum_size = Vector2(0, 190)

const TIERS := ["I", "II", "III", "IV", "V"]
const TRAVEL := 0.45      # s a projectile takes to the dummy
const GAP := 0.7          # s of rest between casts
const LOOP_MAX := 1.4     # s a looping effect (whirlwind) is shown

var skill: Dictionary = {}
var hero_sprite := "swordsman"
var t := 0.0
var _sheets := {}
var sprite_scale := 2.0   # run_config world.sprite_scale
var area_mul := 0.9       # run_config balance.player_area_mul
var slime_scale := 2.0    # monsters.json slime scale


## Kind of preview for skill data [param sp] (see the class doc).
static func kind_of(sp: Dictionary) -> String:
	if sp.has("speed"):
		return "projectile"
	if bool(sp.get("under_hero", false)) or sp.has("distance"):
		return "self"
	if sp.has("offset"):
		return "melee"
	return "target"


## Sprite of tier [param tier] (0-based): tier_sprites when there are any, else the base sprite.
static func tier_sprite(sp: Dictionary, tier: int) -> String:
	var ts: Array = sp.get("tier_sprites", [])
	return String(ts[clampi(tier, 0, ts.size() - 1)]) if not ts.is_empty() else String(sp.get("sprite", ""))


## Animation to play on [param sheet]: the data's "anim", else a right-facing one, else the first.
static func anim_of(sp: Dictionary, sheet: SpriteSheet) -> String:
	var names := sheet.animation_names()
	if sp.has("anim") and String(sp["anim"]) in names:
		return String(sp["anim"])
	for n in names:
		if n.ends_with("right"):
			return n
	return names[0] if not names.is_empty() else ""


func setup(sp: Dictionary, hero: String) -> void:
	var cfg := GameData.load_json("res://assets/data/run_config.json")
	sprite_scale = float(cfg.get("world", {}).get("sprite_scale", 2.0))
	area_mul = float(cfg.get("balance", {}).get("player_area_mul", 1.0))
	slime_scale = float(GameData.load_json("res://assets/data/monsters.json").get("slime", {}).get("scale", sprite_scale))
	skill = sp
	hero_sprite = hero
	t = 0.0


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _sheet(name: String) -> SpriteSheet:
	if name == "":
		return null
	if not _sheets.has(name):
		_sheets[name] = SpriteSheet.load_dir("res://assets/sprites/custom/" + name, name)
	return _sheets[name]


## Seconds one cast takes on screen (travel + effect + impact), before the rest gap.
func cast_time(tier: int) -> float:
	var sh := _sheet(tier_sprite(skill, tier))
	if sh == null:
		return 1.0
	var a := anim_of(skill, sh)
	var d := LOOP_MAX if bool(sh.animation(a).get("loop", false)) else sh.duration(a)
	if kind_of(skill) == "projectile":
		d = TRAVEL
		var imp := _impact(tier)
		if imp != null:
			d += imp.duration(imp.animation_names()[0])
	return d


## Draw scale of [param sh] at world scale [param sc]: x its px_scale, as Run._add_fx does (double-density
## effects are drawn at half: same size on screen).
static func _dens(sh: SpriteSheet, sc: float) -> float:
	return sc * float(sh.meta.get("px_scale", 1.0))


var _vis := {}


## Height of the opaque pixels over the whole strip (frames carry empty margins), cached by sprite name.
func _visible_h(sh: SpriteSheet) -> float:
	if not _vis.has(sh.name):
		var h := sh.frame_size.y
		if sh.texture != null:
			var img := sh.texture.get_image()
			img.decompress()
			var u := img.get_used_rect()
			if u.size.y > 0:
				h = float(u.size.y)
		_vis[sh.name] = h
	return float(_vis[sh.name])


func _impact(tier: int) -> SpriteSheet:
	var it: Array = skill.get("impact_tiers", [])
	return _sheet(String(it[clampi(tier, 0, it.size() - 1)])) if not it.is_empty() else null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d1218"))
	draw_line(Vector2(0, size.y - 34), Vector2(size.x, size.y - 34), Color("1f2733"), 2.0)
	if skill.is_empty():
		return
	# which loop / tier and the time inside it
	var tier := 0
	var local := t
	while true:
		var p := cast_time(tier) + GAP
		if local < p:
			break
		local -= p
		tier = (tier + 1) % TIERS.size()
	var ground := size.y - 34.0
	var kind := kind_of(skill)
	var sh := _sheet(tier_sprite(skill, tier))
	var hit := false
	# sizes as the run draws them (run.gd): hero and fx at world.sprite_scale, a skill's effect x its size_mul x
	# balance.player_area_mul, the slime at its monsters.json scale. A taller effect than the box (holy column)
	# halves the whole view instead of shrinking only the effect.
	var sc := sprite_scale * float(skill.get("size_mul", 1.0)) * area_mul
	var view := 1.0
	if sh != null:
		while _visible_h(sh) * _dens(sh, sc) * view > ground - 8.0 and view > 0.25:
			view *= 0.5
	draw_set_transform(Vector2(0, ground * (1.0 - view)), 0.0, Vector2(view, view))
	var w := size.x / view
	var gy := ground
	var hero := Vector2(w * 0.2, gy)
	var dummy := Vector2(w * 0.78, gy)
	if kind == "melee" or kind == "self":   # close skills only reach a monster beside the hero, as in a run
		dummy.x = hero.x + 56.0 * sprite_scale
	var hs := _sheet(hero_sprite)
	var body := Vector2(0, -16) * sprite_scale
	if hs != null:
		var b := SpriteHitbox.body(hs, Vector2.ZERO, sprite_scale, false)
		if b != null:
			body = b.center
	var ds := _sheet("slime")
	var target := dummy + Vector2(0, -8) * slime_scale
	if ds != null:
		var tb := SpriteHitbox.body(ds, Vector2.ZERO, slime_scale, true)
		if tb != null:
			target = dummy + tb.center
	if sh != null:
		var a := anim_of(skill, sh)
		var dur := cast_time(tier)
		match kind:
			"projectile":
				if local < TRAVEL:
					sh.draw(self, a, local, (hero + body).lerp(target, local / TRAVEL), _dens(sh, sc))
				elif local < dur:
					var imp := _impact(tier)
					if imp != null:
						imp.draw(self, imp.animation_names()[0], local - TRAVEL, target, _dens(imp, sc))
					hit = local < TRAVEL + 0.25
			"self":
				if local < dur and not skill.has("distance"):
					sh.draw(self, a, local, hero + body, _dens(sh, sc))
					hit = fposmod(local, 0.25) < 0.08   # the whirlwind ticks on the monster beside it
			"melee":
				if local < dur:
					var off := float(skill.get("offset", 30.0)) * sc / sprite_scale
					sh.draw(self, a, local, hero + body + Vector2(off, 0), _dens(sh, sc))
					hit = local > dur * 0.3 and local < dur * 0.7
			_:
				if local < dur:
					sh.draw(self, a, local, dummy, _dens(sh, sc))
					hit = local > dur * 0.35 and local < dur * 0.6
	var dashing := skill.has("distance") and local < cast_time(tier)
	if hs != null:
		if dashing and sh != null:   # the dash: the hero sprite's own dash animation, sliding toward the dummy
			var k := clampf(local / maxf(0.01, cast_time(tier)), 0.0, 1.0)
			sh.draw(self, anim_of(skill, sh), local, hero + Vector2(float(skill.get("distance", 120.0)) * k, 0), _dens(sh, sprite_scale))
		else:
			hs.draw(self, hs.animation_names()[0], t, hero, sprite_scale)
	if ds != null:
		ds.draw(self, ds.animation_names()[0], t, dummy, slime_scale, true, Color(1.0, 0.55, 0.55) if hit else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	var f := get_theme_default_font()
	draw_string(f, Vector2(12, 12 + f.get_ascent(18)), "Bậc " + TIERS[tier], HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color("e8c574"))
