class_name ObstacleView
extends RefCounted
## Draws the stage's solid props (rocks, trees; felled trees as stumps) on the run's canvas: their foot
## shadow and sprite, and again see-through over the hero when it walks behind one. Split out of run.gd
## (roadmap tech debt 6, 2026-11-22), like BossView.
##
## Example:
##   obstacle_view.run = self;  obstacle_view.draw(view, false)   # in _draw

var run   # the Run node (untyped, as BossView)


## Solid props: the foot's shadow first, then the sprite on its anchor. [param front]: only those whose
## foot is below the hero and that cover it, drawn see-through so the hero stays visible behind them.
func draw(view: Rect2, front: bool) -> void:
	if run.obstacles == null:
		return
	for s: Dictionary in run.obstacles.solids:
		var p: Vector2 = s["p"]
		if not view.has_point(p):
			continue
		var sh: SpriteSheet = run.sheets.get(String(s["sprite"]))
		if sh == null:
			continue
		if p in run.region_ev.trees.felled:   # Cây đổ: a stump where the tree stood (its trunk lies on the floor)
			if not front:
				run.draw_circle(p + Vector2(0, -4), 11.0, Color(0.22, 0.13, 0.07))
				run.draw_circle(p + Vector2(0, -6), 8.0, Color(0.55, 0.38, 0.2))
				run.draw_arc(p + Vector2(0, -6), 4.0, 0.0, TAU, 12, Color(0.4, 0.26, 0.12), 1.5)
			continue
		if front:
			var size: Vector2 = sh.frame_size * run._sprite_scale
			var behind: bool = run.player_pos.y < p.y and run.player_pos.y > p.y - size.y and absf(run.player_pos.x - p.x) < size.x * 0.45
			if not behind:
				continue
			sh.draw(run, "idle", 0.0, p, run._sprite_scale, false, Color(1, 1, 1, 0.5))
		else:
			sh.draw(run, "idle", 0.0, p, run._sprite_scale)
