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
const ZOOM := 2.0          # view scale (world px -> screen px), the lab demo's close-up
const GAP := 0.7          # s of rest between casts
const LOOP_MAX := 1.4     # s a looping effect (whirlwind) is shown

var skill: Dictionary = {}
var hero_sprite := "swordsman"
var t := 0.0
var _sheets := {}


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
	var hero := Vector2(90, ground)
	var dummy := Vector2(size.x - 110, ground)
	var kind := kind_of(skill)
	var sh := _sheet(tier_sprite(skill, tier))
	var hit := false
	var zoom := ZOOM
	var dens := zoom
	if sh != null:
		# a tall effect (holy column) shrinks the whole view so it fits (sprite-lab demo rule "fitView")
		zoom = maxf(1.0, floorf(minf(ZOOM, (ground - 8.0) / maxf(1.0, sh.frame_size.y * float(sh.meta.get("px_scale", 1.0))))))   # whole steps: pixels stay square
		dens = zoom * float(sh.meta.get("px_scale", 1.0))
		var a := anim_of(skill, sh)
		var dur := cast_time(tier)
		var body := Vector2(0, -16) * zoom
		match kind:
			"projectile":
				if local < TRAVEL:
					sh.draw(self, a, local, (hero + body).lerp(dummy + body, local / TRAVEL), dens)
				elif local < dur:
					var imp := _impact(tier)
					if imp != null:
						imp.draw(self, imp.animation_names()[0], local - TRAVEL, dummy + body, dens)
					hit = local < TRAVEL + 0.25
			"self":
				if local < dur:
					sh.draw(self, a, local, hero, dens)   # around the hero: never reaches the dummy, no flash
			"melee":
				if local < dur:
					sh.draw(self, a, local, hero + body + Vector2(float(skill.get("offset", 30.0)) * zoom, 0), dens)
					hit = local > dur * 0.3 and local < dur * 0.7
			_:
				if local < dur:
					sh.draw(self, a, local, dummy, dens)
					hit = local > dur * 0.35 and local < dur * 0.6
	var hs := _sheet(hero_sprite)
	var dashing := skill.has("distance") and local < cast_time(tier)   # the dash sprite is the hero itself
	if hs != null and not dashing:
		hs.draw(self, hs.animation_names()[0], t, hero, zoom)
	var ds := _sheet("slime")   # monsters.json slime scale 2; hit tint as in the run
	if ds != null:
		ds.draw(self, ds.animation_names()[0], t, dummy, 2.0 * zoom, true, Color(1.0, 0.55, 0.55) if hit else Color.WHITE)
	var f := get_theme_default_font()
	draw_string(f, Vector2(12, 12 + f.get_ascent(18)), "Bậc " + TIERS[tier], HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color("e8c574"))
