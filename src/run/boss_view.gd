class_name BossView
extends RefCounted
## How boss and monster mechanics are drawn, out of run.gd (roadmap items 6-7, slice 3): Mộc Yêu root walls and
## tethers, poison pools, the toad's tongues, boss shockwaves and warnings, monster bolts. Called from Run._draw;
## it draws on the run's canvas (run.draw_*), which Godot allows while that canvas is drawing.
##
## Example (in Run._draw):
##   _boss_view.draw_root_walls()

var run: Node


func _init(p_run: Node) -> void:
	run = p_run


## Monster bolts (shooters, design 6A): each kind's bolt_sprite, "fly" looping.
func draw_bolts() -> void:
	var en: Enemies = run.enemies
	var clock: float = run.clock
	for b in en.bolt_pos.size():
		var sh: SpriteSheet = run.sheets.get(String(en.k_extra[en.bolt_kind[b]].get("bolt_sprite", "")))
		if sh != null:
			sh.draw(run, "fly", fmod(clock + b * 0.1, sh.duration("fly")), en.bolt_pos[b], run._sprite_scale)


## Poison pools left by Cóc Độc (design 6A): a toxic green puddle with bubbles,
## shrinking and fading as it dries up.
## Cổ Thụ Trụi Lá root walls: a red dashed line while warning, then a thick thorny root wall; and the
## root tethers pulling minions into the boss (Hấp thụ đệ), shown for 0.5 s.
func draw_root_walls() -> void:
	var en: Enemies = run.enemies
	var clock: float = run.clock
	for w in en.wall_a.size():
		var a := en.wall_a[w]
		var b := en.wall_b[w]
		var d: Dictionary = en.wall_def[w]
		var stand := float(d.get("time", 4.0))
		var th := float(d.get("thick", 14.0))
		if en.wall_t[w] > stand:   # warning: blinking red dashes across the path
			var on := int(clock * 8.0) % 2 == 0
			var n := 14
			for k in n:
				if k % 2 == 0:
					run.draw_line(a.lerp(b, k / float(n)), a.lerp(b, (k + 1) / float(n)), Color(1.0, 0.25, 0.2, 0.9 if on else 0.5), 4.0)
			continue
		var fade := clampf(en.wall_t[w] / 0.3, 0.0, 1.0)   # sinks in the last 0.3 s
		var dir := (b - a).normalized()
		var side := dir.orthogonal()
		run.draw_line(a, b, Color(0.12, 0.08, 0.05, fade), th + 4.0)
		run.draw_line(a, b, Color(0.42, 0.27, 0.15, fade), th)
		run.draw_line(a - side * th * 0.2, b - side * th * 0.2, Color(0.58, 0.4, 0.22, fade), 3.0)
		var len := a.distance_to(b)
		var k2 := 0.0
		while k2 < len:   # thorns both sides
			var q := a + dir * k2
			var sgn := 1.0 if int(k2 / 18.0) % 2 == 0 else -1.0
			run.draw_colored_polygon(PackedVector2Array([q - dir * 4.0 + side * sgn * th * 0.4, q + dir * 4.0 + side * sgn * th * 0.4,
				q + side * sgn * (th * 0.5 + 9.0)]), Color(0.75, 0.62, 0.4, fade))
			k2 += 18.0
	for ln: Array in en.absorb_lines:
		run._absorb_fx.append({"a": ln[0], "b": ln[1], "t": 0.5})
	en.absorb_lines.clear()
	for fx: Dictionary in run._absorb_fx:
		var u := float(fx["t"]) / 0.5
		run.draw_line(fx["a"], fx["b"], Color(0.35, 0.22, 0.1, u), 5.0)
		run.draw_line(fx["a"], fx["b"], Color(0.55, 0.9, 0.5, u), 2.0)


func draw_pools(view: Rect2) -> void:
	var en: Enemies = run.enemies
	var clock: float = run.clock
	for b in en.pool_pos.size():
		var p := en.pool_pos[b]
		if not view.grow(60.0).has_point(p):
			continue
		var left := clampf(en.pool_t[b] / maxf(0.01, en.pool_total[b]), 0.0, 1.0)
		var r := en.pool_r[b] * (0.75 + 0.25 * left)
		var a := 0.35 + 0.35 * minf(1.0, left * 3.0)
		var purple := b < en.pool_purple.size() and en.pool_purple[b] == 1   # Cóc Độc Bào Tử spores
		var c0 := Color(0.45, 0.18, 0.6, a) if purple else Color(0.35, 0.6, 0.12, a)
		var c1 := Color(0.7, 0.35, 0.9, a * 0.8) if purple else Color(0.55, 0.85, 0.2, a * 0.8)
		var c2 := Color(0.25, 0.08, 0.35, a + 0.2) if purple else Color(0.2, 0.35, 0.08, a + 0.2)
		var cb := Color(0.9, 0.6, 1.0) if purple else Color(0.75, 1.0, 0.4)
		run.draw_set_transform(p, 0.0, Vector2(1.0, 0.6))   # flat on the ground
		run.draw_circle(Vector2.ZERO, r, c0)
		run.draw_circle(Vector2(-r * 0.2, -r * 0.15), r * 0.6, c1)
		run.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c2, 2.0)
		run.draw_set_transform(Vector2.ZERO)
		for k in 3:   # bubbles pop in turn
			var ph := fmod(clock * 1.7 + k * 0.33 + float(b) * 0.21, 1.0)
			var q := p + Vector2(cos(k * 2.1 + b) * r * 0.5, sin(k * 2.1 + b) * r * 0.3)
			run.draw_circle(q, 1.5 + 2.0 * ph, Color(cb, a * (1.0 - ph)))
	draw_tongues()


## Cóc Độc Bào Tử's tongue: while it aims, a blinking red line along the aim; while it shoots, a pink
## tongue from the mouth with a round tip.
func draw_tongues() -> void:
	var en: Enemies = run.enemies
	var clock: float = run.clock
	for i in en.count:
		var t := en.tongue_t[i]
		if t == 0.0 or t == -999.0:
			continue
		var tg: Dictionary = en.k_extra[en.kind[i]].get("tongue", {})
		var a := en.center_of(i)
		var d := en.tongue_dir[i]
		if t > 0.0:
			var on := int(clock * 10.0) % 2 == 0
			run.draw_line(a, a + d * float(tg.get("length", 300.0)), Color(1.0, 0.2, 0.15, 0.85 if on else 0.4), 3.0)
			continue
		var b := a + d * en.tongue_len[i]
		run.draw_line(a, b, Color(0.35, 0.05, 0.12), float(tg.get("width", 10.0)) + 4.0)
		run.draw_line(a, b, Color(0.95, 0.45, 0.55), float(tg.get("width", 10.0)))
		run.draw_circle(b, float(tg.get("width", 10.0)) * 0.9, Color(0.95, 0.45, 0.55))


func draw_hazard_pools() -> void:
	var en: Enemies = run.enemies
	var clock: float = run.clock
	if run.obstacles == null:
		return
	for pl: Dictionary in run.obstacles.pools:
		var p: Vector2 = pl["p"]
		var r := float(pl["r"])
		run.draw_set_transform(p, 0.0, Vector2(1.0, 0.55))
		run.draw_circle(Vector2.ZERO, r, Color(0.35, 0.55, 0.1, 0.55))
		run.draw_circle(Vector2(-r * 0.2, -r * 0.15), r * 0.65, Color(0.55, 0.8, 0.15, 0.45))
		run.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.2, 0.3, 0.05, 0.9), 2.0)
		run.draw_set_transform(Vector2.ZERO)
		for k in 3:   # bubbles rising and popping
			var ph := fmod(clock * 1.3 + k * 0.37 + p.x * 0.01, 1.0)
			var q := p + Vector2(cos(k * 2.3 + p.y) * r * 0.5, sin(k * 2.3 + p.x) * r * 0.25)
			run.draw_circle(q, 1.5 + 2.5 * ph, Color(0.75, 1.0, 0.35, 0.8 * (1.0 - ph)))


## Red circles where a boss is about to land (its slam reach), filling up as the
## landing nears.
func draw_boss_waves() -> void:
	var en: Enemies = run.enemies
	var clock: float = run.clock
	for w in en.wave_pos.size():
		var r := en.wave_r[w]
		var p := en.wave_pos[w]
		var wd := float(en.wave_def[w].get("width", 12.0))
		var hot := en.wave_def[w].has("knock")   # Cóc Độc Bào Tử's knockback wave: red / orange
		run.draw_arc(p, r, 0.0, TAU, 72, Color(1.0, 0.35, 0.15, 0.4) if hot else Color(0.55, 0.95, 0.6, 0.35), wd)
		run.draw_arc(p, r, 0.0, TAU, 72, Color(1.0, 0.75, 0.35, 0.95) if hot else Color(0.85, 1.0, 0.75, 0.95), 3.0)
	var bi := en.boss_index()
	if bi >= 0 and run._rage_t > 0.0 and en.phase_name(bi) == "":   # a named phase is called across the screen instead
		var font := ThemeDB.fallback_font
		var pn: String = en.phase_name(bi)
		var name := String(en.k_extra[en.kind[bi]].get("name", "Boss")) + (" · %s!" % pn if pn != "" else " nổi giận!")
		var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var at := en.center_of(bi) - Vector2(tw * 0.5, en.k_radius[en.kind[bi]] * 2.0 + 20.0)
		run.draw_string_outline(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0.1, 0.02, 0.02))
		run.draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.4, 0.3))


func draw_boss_warnings() -> void:
	var en: Enemies = run.enemies
	var clock: float = run.clock
	for w in en.boss_telegraphs():
		var p: Vector2 = w[0]
		var r: float = w[1]
		run.draw_circle(p, r, Color(0.9, 0.1, 0.1, 0.16))
		run.draw_arc(p, r, 0.0, TAU, 48, Color(1.0, 0.3, 0.3, 0.8), 2.0)
	for b in en.blast_pos.size():   # Bọ Lửa: the ring fills up until it goes off
		var p := en.blast_pos[b]
		var r := en.blast_r[b]
		var k := 1.0 - en.blast_t[b] / maxf(0.01, en.blast_total[b])
		if en.blast_root[b] == 1:   # Mộc Yêu: cracked earth and root tips poking out
			run.draw_circle(p, r, Color(0.25, 0.16, 0.08, 0.25 + 0.2 * k))
			run.draw_arc(p, r, 0.0, TAU, 40, Color(0.55, 0.8, 0.3, 0.5 + 0.45 * k), 2.0)
			for t in 5:
				var q := p + Vector2.from_angle(t * TAU / 5.0 + float(b)) * r * 0.55
				run.draw_rect(Rect2(q - Vector2(1.5, 1.5 + 3.0 * k), Vector2(3.0, 3.0 + 3.0 * k)), Color(0.42, 0.27, 0.15))
			continue
		run.draw_circle(p, r * k, Color(1.0, 0.45, 0.1, 0.22))
		run.draw_arc(p, r, 0.0, TAU, 40, Color(1.0, 0.55, 0.2, 0.55 + 0.4 * k), 2.0)
