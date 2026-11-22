class_name KillDrops
extends RefCounted
## What the monsters killed this step leave: xp gems, gold, chests, Tinh hoa, the gold goblin trail and
## escape, boss kill flags, Khát máu heals. Split out of run.gd (roadmap tech debt 6, 2026-11-22).

var run   # the Run node (untyped: its private helpers are reached by name, as BossView does)


func step() -> void:
	for p in run.enemies.gold_trail:   # Yêu tinh vàng drops coins as it runs (a trail to follow)
		run.pickups.drop(Pickups.COIN, p, 1.0)
	run.enemies.gold_trail.clear()
	if not run.enemies.escaped.is_empty():
		run.wave_call = "Yêu tinh vàng đã trốn mất!"
		run.wave_call_t = 2.5
		for p in run.enemies.escaped:
			run._add_fx("arcane-bolt-impact-iii", "impact", run._sprite_scale * 1.5, 0.0, -1.0, p)
		run.enemies.escaped.clear()
	if run.enemies.kill_pos.is_empty():
		return
	Sfx.play("kill")
	run.count_special_kills(run.enemies.kill_pos.size())
	var gold_chance = float(run.cfg.get("pickups", {}).get("gold_chance", 0.12))
	var heal_frac = run.heal_on_kill()   # Khát máu: elites and bosses feed the hero
	for i in run.enemies.kill_pos.size():
		if run.drops_xp(run.enemies.kill_elite[i] == 1 or run.enemies.kill_boss[i] == 1):
			run.pickups.drop(Pickups.GEM, run.enemies.kill_pos[i], run.enemies.kill_xp[i])
		if run.enemies.kill_elite[i] == 1 or run.enemies.kill_boss[i] == 1:
			run.elite_kills += 1
		if run.enemies.kill_elite[i] == 1:
			run._drop_chest(run.enemies.kill_pos[i] + Vector2(-10, 0))
		var ess = run.essence_drop(run.enemies.kill_elite[i] == 1, run.enemies.kill_boss[i] == 1)
		if ess > 0:   # Tinh hoa: the skill-tree material
			run.pickups.drop(Pickups.ESSENCE, run.enemies.kill_pos[i] + Vector2(0, -12), float(ess))
		if run.enemies.kill_boss[i] == 1:
			run._boss_dead = true
			run.bosses_killed += 1
		if heal_frac > 0.0 and (run.enemies.kill_elite[i] == 1 or run.enemies.kill_boss[i] == 1):
			run.heal_max(heal_frac)
		if run.rng.randf() < gold_chance:
			run.pickups.drop(Pickups.COIN, run.enemies.kill_pos[i] + Vector2(10, 0), 1.0)
		for g in int(run.enemies.kill_gold[i]):   # Yêu tinh vàng: a burst of coins
			run.pickups.drop(Pickups.COIN, run.enemies.kill_pos[i] + Vector2.from_angle(g * 2.4) * (10.0 + 3.0 * g), 1.0)
		if run.enemies.kill_chest[i] == 1 and run.enemies.kill_elite[i] == 0:
			run._drop_chest(run.enemies.kill_pos[i] + Vector2(0, -14))
	run.enemies.drain_kills()
