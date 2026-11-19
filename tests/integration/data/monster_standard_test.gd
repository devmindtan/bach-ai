extends RefCounted
## creature-v1 (sprite-lab/CREATURE_STANDARD.md, user 2026-11-19): every monster sprite has the
## required animations with enough frames, so none looks stiff. The slime stays as it is (user).
## LEGACY lists sprites still waiting for their upgrade (design/art/monster-upgrade.md): it may only shrink.

const EXEMPT := ["slime"]
const LEGACY := ["bat", "goblin", "spore", "ember-beetle", "wisp", "bog-spirit", "king-slime", "tree-boss", "toad", "toad-king"]
const MIN := {"move": 6, "attack": 6, "hurt": 3, "death": 6}

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
		for anim: String in MIN:
			_check(int(frames.get(anim, 0)) >= int(MIN[anim]),
				"%s: %s has %d frames, creature-v1 needs >= %d" % [name, anim, int(frames.get(anim, 0)), MIN[anim]])
