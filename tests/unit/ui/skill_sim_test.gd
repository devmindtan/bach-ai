extends RefCounted
## Album skill preview (design/ux/album.md): every skill gets a preview kind, a sprite for each tier that
## exists in the game, and an animation that its sheet has.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_kinds() -> void:
	_check(SkillSim.kind_of({"speed": 300.0}) == "projectile", "a skill with speed is not a projectile")
	_check(SkillSim.kind_of({"under_hero": true}) == "self", "under_hero is not on the hero")
	_check(SkillSim.kind_of({"offset": 30.0}) == "melee", "blade_arc's offset is not melee")
	_check(SkillSim.kind_of({"cast_range": 200.0}) == "target", "a cast skill is not on the dummy")


func test_every_album_skill_has_sprites() -> void:
	var album := preload("res://src/front/album.gd")
	for e: Dictionary in album.skill_entries():
		var sp: Dictionary = e["sp"]
		for tier in 5:
			var name := SkillSim.tier_sprite(sp, tier)
			var sh := SpriteSheet.load_dir("res://assets/sprites/custom/" + name, name)
			_check(sh != null, "%s tier %d: no sprite %s" % [e["id"], tier, name])
			if sh != null:
				_check(SkillSim.anim_of(sp, sh) in sh.animation_names(), "%s: no animation to play" % e["id"])


## User 2026-11-23 / 2026-11-26: the Album lists the skills of every class (it showed only Kiếm sĩ and Pháp sư), with
## the shared Lướt once.
func test_album_lists_every_class_and_one_dash() -> void:
	var album := preload("res://src/front/album.gd")
	var classes := GameData.load_json("res://assets/data/classes.json")
	var seen := {}
	var dashes := 0
	for e: Dictionary in album.skill_entries():
		seen[String(e["cls"])] = true
		if String(e["id"]) == "dash":
			dashes += 1
	for cid: String in classes:
		if not cid.begins_with("_"):
			_check(seen.has(String(classes[cid]["name"])), "%s has no skills in the Album" % classes[cid]["name"])
	_check(dashes == 1, "Lướt is listed once, got %d" % dashes)
