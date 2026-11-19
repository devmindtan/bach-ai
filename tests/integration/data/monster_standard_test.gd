extends RefCounted
## creature-v1 (sprite-lab/CREATURE_STANDARD.md, user 2026-11-19): every monster sprite has the
## required animations with enough frames, so none looks stiff. The slime stays as it is (user).
## LEGACY lists sprites still waiting for their upgrade (design/art/monster-upgrade.md): it may only shrink.

const EXEMPT := ["slime"]
const LEGACY := ["bat", "goblin", "spore", "ember-beetle", "wisp", "bog-spirit", "toad"]
const MIN := {"move": 6, "attack": 6, "hurt": 3, "death": 6}
const BOSS_MIN := {"move": 8, "attack": 8, "hurt": 4, "death": 8}   # user 2026-11-19: bosses get 8 frames

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_monsters_meet_creature_v1() -> void:
	var monsters := GameData.load_json("res://assets/data/monsters.json")
	var seen := {}
	for id: String in monsters:
		var m: Variant = monsters[id]
		if not m is Dictionary:
			continue
		var name := String(m.get("sprite", id))
		if name in EXEMPT or name in LEGACY or seen.has(name):
			continue
		seen[name] = true
		var meta := GameData.load_json("res://assets/sprites/custom/%s/%s.json" % [name, name])
		var frames := {}
		for a: Dictionary in meta.get("animations", []):
			frames[String(a.get("name", ""))] = int(a.get("frames", 0))
		var need: Dictionary = BOSS_MIN if bool(m.get("boss", false)) else MIN
		if bool(m.get("boss", false)):   # user 2026-11-19: a boss has at least one side of 48 px
			var fs: Array = meta.get("frame_size", [0, 0])
			_check(maxi(int(fs[0]), int(fs[1])) >= 48, "%s: boss frame %s needs one side >= 48 px" % [name, fs])
		for anim: String in need:
			_check(int(frames.get(anim, 0)) >= int(need[anim]),
				"%s: %s has %d frames, creature-v1 needs >= %d" % [name, anim, int(frames.get(anim, 0)), need[anim]])
