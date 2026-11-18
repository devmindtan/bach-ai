extends RefCounted
## Each region looks and sounds its own (design/regions.md, user 2026-11-18).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_regions_have_distinct_music_and_props() -> void:
	var stages := GameData.load_json("res://assets/data/stages.json")
	var audio := GameData.load_json("res://assets/data/audio.json")
	var musics := {}
	var props := {}
	for r: Dictionary in stages["regions"]:
		var m := String(r.get("music", ""))
		_check(m != "" and audio["music"].has(m), "%s: music '%s' must be in audio.json" % [r["id"], m])
		_check(FileAccess.file_exists("res://assets/audio/music/%s.wav" % m), "%s: music file %s.wav" % [r["id"], m])
		musics[m] = true
		var p: Array = r.get("ground", {}).get("props", [])
		_check(not p.is_empty(), "%s: ground.props must list its decorations" % r["id"])
		props[str(p)] = true
	_check(musics.size() == stages["regions"].size(), "every region has its own music")
	_check(props.size() == stages["regions"].size(), "every region has its own props")


func test_challenges_have_their_music() -> void:
	var c := GameData.load_json("res://assets/data/challenges.json")
	var audio := GameData.load_json("res://assets/data/audio.json")
	var m := String(c.get("music", ""))
	_check(m != "" and audio["music"].has(m), "challenges.json music '%s' must be in audio.json" % m)
