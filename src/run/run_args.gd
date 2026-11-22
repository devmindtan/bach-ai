class_name RunArgs
extends RefCounted
## Command-line flags of the run scene (shots, tests, bench: --demo, --seed, --stage, --skills,
## --event, --pause-at, ...), applied onto the Run node. Split out of run.gd (roadmap tech debt 6,
## 2026-11-21); the flag list stays documented at the top of run.gd.
##
## Example:
##   RunArgs.apply(self)   # first thing in Run._ready


static func apply(run) -> void:
	var seeded := false
	for a in OS.get_cmdline_user_args():
		if a == "--demo":
			run.demo = true
		elif a == "--level-now":   # shots: a level-up panel as the run starts (card flip)
			run._level_now = true
		elif a == "--gold-chest":   # shots: a Rương vàng on the ground beside the hero
			run._shot_gold_chest = true
		elif a.begins_with("--seed="):
			run.rng.seed = int(a.get_slice("=", 1))
			seeded = true
		elif a.begins_with("--buff="):
			# Debug/shots: start with these buffs active, e.g. --buff=magnetic_shield,power_orb
			for id in a.get_slice("=", 1).split(",", false):
				run._forced_buffs.append(id)
		elif a.begins_with("--buff-ground="):
			# Debug/shots: these buffs lie on the ground near the start
			for id in a.get_slice("=", 1).split(",", false):
				run._ground_buffs.append(id)
		elif a.begins_with("--status-all="):
			for st in a.get_slice("=", 1).split(",", false):
				run._status_all.append(st)
		elif a.begins_with("--show-special-fx="):   # shots: every special card's effect drawn once at T s (look only)
			run.show_special_fx_at = float(a.get_slice("=", 1))
		elif a.begins_with("--monster-hp="):
			run.monster_hp_mul = maxf(0.01, float(a.get_slice("=", 1)))
		elif a.begins_with("--boss-hp="):
			run._boss_hp_share = float(a.get_slice("=", 1))
		elif a.begins_with("--gear-plus="):
			run._gear_plus = int(a.get_slice("=", 1))
		elif a.begins_with("--gear="):
			for id in a.get_slice("=", 1).split(",", false):
				run._gear.append(id)
		elif a.begins_with("--stage="):
			run.stage_number = maxi(1, int(a.get_slice("=", 1)))
			run._stage_arg_set = true
		elif a.begins_with("--dash-at="):
			run.dash_at = float(a.get_slice("=", 1))
		elif a == "--god":
			run.god = true
		elif a.begins_with("--pause-view="):
			run.pause_view = a.get_slice("=", 1)
		elif a.begins_with("--pause-at="):
			run.pause_at = float(a.get_slice("=", 1))
		elif a.begins_with("--walk="):
			var xy := a.get_slice("=", 1).split(",")
			run.forced_walk = Vector2(float(xy[0]), float(xy[1])).normalized()
			run.demo = true
		elif a.begins_with("--skills="):
			# Debug/testing: force skill levels, e.g. --skills=frost_nova:5,earth_strike:5
			for pair in a.get_slice("=", 1).split(","):
				var kv := pair.split(":")
				if kv.size() == 2:
					run.levels[kv[0]] = int(kv[1])
			run.demo = true
		elif a.begins_with("--offer="):
			# Debug/shots: the first level-up offers these cards, e.g. --offer=earth_strike,haste,back_slash
			for id in a.get_slice("=", 1).split(",", false):
				run.offer.append(id)
		elif a.begins_with("--pick-card="):
			run._pick_card = a.get_slice("=", 1)
		elif a.begins_with("--spawn-only="):
			run._spawn_only = a.get_slice("=", 1)
		elif a.begins_with("--level-view="):
			run._level_view_arg = a.get_slice("=", 1)
		elif a.begins_with("--challenge="):
			run.challenge_id = a.get_slice("=", 1)
		elif a.begins_with("--milestone="):
			run._ms_queue.append(int(a.get_slice("=", 1)))
		elif a.begins_with("--rewards="):
			# Debug/shots/tests: milestone rewards the slot owns, e.g. --rewards=earthquake,bloodthirst
			run._rewards_arg = true
			for id in a.get_slice("=", 1).split(",", false):
				run.rewards.append(id)
		elif a == "--no-auto-pick":
			run.auto_pick = false
		elif a == "--hitboxes":
			run.show_hitboxes = true
		elif a.begins_with("--event="):   # shots: --event=hunt@3
			var spec := a.get_slice("=", 1)
			run._forced_events.append([float(spec.get_slice("@", 1)), spec.get_slice("@", 0)])
		elif a == "--pool-here":   # shots: a poison pool under the hero's start (poison look)
			run._pool_here = true
		elif a.begins_with("--vfx="):   # shots: the Cài đặt "Hiệu ứng" level 0..2
			Prefs.current().vfx = clampi(int(a.get_slice("=", 1)), 0, 2)
		elif a == "--debug-overlay":
			run.toggle_debug_overlay.call_deferred()
		elif a.begins_with("--sim-steps="):
			run.sim_steps = maxi(1, int(a.get_slice("=", 1)))
		elif a.begins_with("--bench="):
			run.bench = maxi(1, int(a.get_slice("=", 1)))
			run.demo = true
	if not seeded:
		run.rng.randomize()
