extends RefCounted
## Sound (design/audio.md): every sound the game names exists, voices and gaps keep
## repeated sounds calm, gem pickups climb in pitch, volume steps, music loops.

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _sfx() -> Sfx:
	var s := Sfx.new()
	s.now_ms = 1000
	s.record = true
	return s


func test_every_mapped_sound_has_a_file() -> void:
	var cfg := GameData.load_json(Sfx.DATA)
	var ids: Array = cfg.get("sfx", {}).keys()
	ids.append_array(cfg.get("skills", {}).values())
	for id: String in ids:
		_check(ResourceLoader.exists(Sfx.SFX_DIR + id + ".wav"), "sfx %s has no wav (gamekit audio)" % id)
	for id: String in ["menu", "run", "boss"]:
		_check(ResourceLoader.exists(Sfx.MUSIC_DIR + id + ".wav"), "music %s has no wav" % id)


func test_every_skill_of_both_classes_has_a_cast_sound() -> void:
	var skills: Dictionary = GameData.load_json(Sfx.DATA).get("skills", {})
	for cls in ["knight", "mage"]:
		var pool := GameData.load_json("res://assets/data/upgrades_%s.json" % cls)
		for sid: String in pool.get("skills", {}).keys():
			_check(skills.has(sid), "%s skill %s has no cast sound in audio.json" % [cls, sid])


func test_the_ids_the_code_plays_are_in_audio_json() -> void:
	var known: Dictionary = GameData.load_json(Sfx.DATA).get("sfx", {})
	var re := RegEx.create_from_string("Sfx\\.play\\(\"([a-z_]+)\"\\)")
	for path in ["res://src/run/run.gd", "res://src/front/gacha.gd", "res://src/front/equipment.gd",
			"res://src/front/skill_tree.gd", "res://src/front/stage_select.gd"]:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			_check(known.has(m.get_string(1)), "%s plays %s, not in audio.json" % [path.get_file(), m.get_string(1)])


func test_gap_blocks_a_repeat_too_soon() -> void:
	var s := _sfx()
	var gap := int(float(s.rules("hit")["gap"]) * 1000.0)
	_check(s.play_id("hit"), "first hit plays")
	s.now_ms += gap - 1
	_check(not s.play_id("hit"), "a hit inside the gap is skipped")
	s.now_ms += 1
	_check(s.play_id("hit"), "a hit after the gap plays")
	s.free()


func test_voices_cap_how_many_sound_at_once() -> void:
	# quake (about 0.29 s) outlasts voices x gap, so the cap is what stops the third
	var s := _sfx()
	var r := s.rules("quake")
	var voices := int(r["voices"])
	var gap := int(float(r["gap"]) * 1000.0)
	_check(s._stream(Sfx.SFX_DIR, "quake").get_length() * 1000.0 > voices * gap, "fixture: quake outlasts the gaps")
	var started := 0
	for k in voices + 1:   # all inside the first one's length
		if s.play_id("quake"):
			started += 1
		s.now_ms += gap   # past the gap, but the earlier ones still sound
	_check(started == voices, "quake: %d started, cap %d" % [started, voices])
	_check(s.voices_busy("quake") <= voices, "never more than the cap sounding")
	s.now_ms += 5000
	_check(s.voices_busy("quake") == 0, "all voices free after they end")
	_check(s.play_id("quake"), "plays again once free")
	s.free()


func test_quick_gem_pickups_climb_in_pitch_then_reset() -> void:
	var s := _sfx()
	var r := s.rules("gem")
	var pitches: Array[float] = []
	for k in 4:
		s.play_id("gem")
		pitches.append(s._players["gem"][k % s._players["gem"].size()].pitch_scale)
		s.now_ms += 200
	_check(pitches[1] > pitches[0] and pitches[3] > pitches[1], "gem pitch rises: %s" % [pitches])
	s.now_ms += int(float(r["rise_reset"]) * 1000.0) + 500
	s._ends.clear()
	s.play_id("gem")
	var p: float = s._players["gem"][4 % s._players["gem"].size()].pitch_scale
	_check(is_equal_approx(p, 1.0), "after a pause gem pitch resets, got %.2f" % p)
	s.free()


func test_unknown_sound_is_ignored() -> void:
	var s := _sfx()
	_check(not s.play_id("no_such_sound"), "a missing sound does nothing")
	_check(s.played.is_empty(), "nothing logged")
	Sfx.play("hit")   # no autoload in tests: a no-op, no error
	s.free()


func test_volume_steps_wrap() -> void:
	_check(SettingsPanel.next_volume(0) == 20, "0 -> 20")
	_check(SettingsPanel.next_volume(80) == 100, "80 -> 100")
	_check(SettingsPanel.next_volume(100) == 0, "100 -> 0 (off)")
	_check(SettingsPanel.next_volume(50) == 60, "an odd value snaps to the next step")


func test_music_files_loop() -> void:
	for id: String in ["menu", "run", "boss"]:
		var st := load(Sfx.MUSIC_DIR + id + ".wav") as AudioStreamWAV
		_check(st != null and st.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music %s loops (smpl chunk)" % id)


func test_music_switch_is_idempotent() -> void:
	var s := _sfx()
	s.play_music("run")
	s.play_music("run")
	_check(s.played.count("music:run") == 1, "the same song twice starts once")
	s.play_music("boss")
	_check(s.music_id == "boss" and s.played.has("music:boss"), "switches to boss")
	s.free()
