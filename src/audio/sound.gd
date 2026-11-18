class_name Sfx
extends Node
## Sound effects and music (autoload "Audio"; design/audio.md). Which sound plays
## for an event, how many at once (voices) and how often (gap) come from
## assets/data/audio.json; the .wav files come from `gamekit audio`.
##
## Example:
##   Sfx.play("level_up")
##   Sfx.skill("fireball")      # the cast sound mapped to a skill id
##   Sfx.music("run")           # crossfades; the same id again does nothing
##
## A button plays "ui_click" when pressed; set_meta("sfx", "id") plays that sound
## instead, set_meta("sfx", "") keeps it silent (the screen plays its own).
## In fixed mode (screenshots, tests) the master bus is muted: nothing reaches
## the speakers, but the bookkeeping (played, voices, gaps) still runs.

const DATA := "res://assets/data/audio.json"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

var cfg: Dictionary = {}
var record := false                    # keep a log in played (tests; --sound-log)
var played: Array[String] = []        # sounds started while record is on
var now_ms := -1                       # tests set the clock; -1 = real time
var music_id := ""
var _streams := {}                     # id -> AudioStream (null when the file is missing)
var _players := {}                     # id -> Array of AudioStreamPlayer (one per voice, round robin)
var _next := {}                        # id -> next player index
var _ends := {}                        # id -> ms when each sounding voice ends
var _last := {}                        # id -> ms of the last start
var _rise := {}                        # id -> [pitch added, ms of the last start]
var _music: AudioStreamPlayer
var _music_old: AudioStreamPlayer


## The autoload, or null (a scene run without it, a unit test).
static func current() -> Sfx:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Audio") as Sfx


## Plays sound [param id] (assets/audio/sfx/<id>.wav) if the rules allow it now.
static func play(id: String) -> void:
	var s := current()
	if s != null:
		s.play_id(id)


## Plays the cast sound of skill [param sid] (audio.json "skills"); unmapped = none.
static func skill(sid: String) -> void:
	var s := current()
	if s != null and s.cfg.get("skills", {}).has(sid):
		s.play_id(String(s.cfg["skills"][sid]))


## Switches the music to [param id] ("" stops it).
static func music(id: String) -> void:
	var s := current()
	if s != null:
		s.play_music(id)


func _init() -> void:
	cfg = GameData.load_json(DATA)
	_music = _new_player(BUS_MUSIC)
	_music_old = _new_player(BUS_MUSIC)
	_music.finished.connect(_on_music_finished)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # menus over a paused run still click
	ensure_buses()
	get_tree().node_added.connect(_on_node_added)
	var prefs := Prefs.current()
	if prefs != null:
		prefs.changed.connect(apply_volume)
	apply_volume()
	record = record or _log_path() != ""


## --sound-log=<file>: at exit, how often each sound started, as JSON (a shot run
## filters stdout, so the log goes to a file).
static func _log_path() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sound-log="):
			return a.get_slice("=", 1)
	return ""


func _exit_tree() -> void:
	var path := _log_path()
	if record and path != "":
		var n := {}
		for id in played:
			n[id] = int(n.get(id, 0)) + 1
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(n, "  ", true))


## Creates the Music and SFX buses (sent to Master) when the project has none.
static func ensure_buses() -> void:
	for bus in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")


## Bus levels from Prefs (0..100 %; 0 mutes). Fixed mode mutes the master bus.
func apply_volume() -> void:
	var prefs := Prefs.current()
	var vol: Dictionary = cfg.get("volume", {})
	var m := int(vol.get("music", 60))
	var e := int(vol.get("sfx", 80))
	if prefs != null:
		m = prefs.music_volume
		e = prefs.sfx_volume
	_set_bus(BUS_MUSIC, m)
	_set_bus(BUS_SFX, e)
	AudioServer.set_bus_mute(0, prefs != null and prefs.is_fixed() and not OS.get_cmdline_user_args().has("--sound"))


static func _set_bus(bus: StringName, percent: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, percent <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(percent / 100.0, 0.001, 1.0)))


## The rules of sound [param id]: audio.json "default" overlaid by its own entry.
func rules(id: String) -> Dictionary:
	var r: Dictionary = cfg.get("default", {}).duplicate()
	r.merge(cfg.get("sfx", {}).get(id, {}), true)
	return r


func _now() -> int:
	return now_ms if now_ms >= 0 else Time.get_ticks_msec()


## Starts sound [param id] unless it played less than "gap" ago or all its
## "voices" are busy. Returns true when it started.
func play_id(id: String) -> bool:
	var stream := _stream(SFX_DIR, id)
	if stream == null:
		return false
	var r := rules(id)
	var t := _now()
	if _last.has(id) and t - int(_last[id]) < int(float(r.get("gap", 0.05)) * 1000.0):
		return false
	# voices: counted by when each start ends (stream length), so it does not depend
	# on the audio driver and tests can drive the clock (now_ms)
	var ends: Array = _ends.get(id, []).filter(func(e: int) -> bool: return e > t)
	if ends.size() >= int(r.get("voices", 2)):
		return false
	var pool: Array = _players.get(id, [])
	if pool.size() < int(r.get("voices", 2)):
		var np := _new_player(BUS_SFX)
		np.stream = stream
		pool.append(np)
		_players[id] = pool
	var free: AudioStreamPlayer = pool[int(_next.get(id, 0)) % pool.size()]
	_next[id] = int(_next.get(id, 0)) + 1
	_last[id] = t
	var pitch := 1.0 + randf_range(-1.0, 1.0) * float(r.get("jitter", 0.0))
	if r.has("rise"):   # quick repeats climb in pitch (gem pickups)
		var st: Array = _rise.get(id, [0.0, -100000])
		var add := 0.0
		if t - int(st[1]) <= int(float(r.get("rise_reset", 0.6)) * 1000.0):
			add = minf(float(r.get("rise_max", 0.5)), float(st[0]) + float(r["rise"]))
		_rise[id] = [add, t]
		pitch += add
	free.pitch_scale = maxf(0.1, pitch)
	ends.append(t + int(stream.get_length() / free.pitch_scale * 1000.0))
	_ends[id] = ends
	free.volume_db = float(r.get("db", 0.0))
	if free.is_inside_tree():
		free.play()
	if record:
		played.append(id)
	return true


## Number of voices of [param id] still sounding at the current clock.
func voices_busy(id: String) -> int:
	var t := _now()
	return _ends.get(id, []).filter(func(e: int) -> bool: return e > t).size()


func play_music(id: String) -> void:
	if id == music_id:
		return
	music_id = id
	var fade := float(cfg.get("music", {}).get("fade", 0.6))
	# the old song fades out on the spare player
	var old := _music
	_music = _music_old
	_music_old = old
	if _music_old.finished.is_connected(_on_music_finished):
		_music_old.finished.disconnect(_on_music_finished)
	_music.finished.connect(_on_music_finished)
	if _music_old.playing and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(_music_old, "volume_db", -40.0, fade)
		tw.tween_callback(_music_old.stop)
	else:
		_music_old.stop()
	var stream := _stream(MUSIC_DIR, id) if id != "" else null
	if stream == null:
		_music.stop()
		return
	var db := float(cfg.get("music", {}).get(id, {}).get("db", 0.0))
	_music.stream = stream
	_music.volume_db = -40.0 if is_inside_tree() else db
	if _music.is_inside_tree():
		_music.play()
		create_tween().tween_property(_music, "volume_db", db, fade)
	if record:
		played.append("music:" + id)


func _on_music_finished() -> void:   # a stream without a loop point: start again
	if music_id != "":
		_music.play()


func _stream(dir: String, id: String) -> AudioStream:
	var key := dir + id
	if not _streams.has(key):
		var path := dir + id + ".wav"
		_streams[key] = load(path) if ResourceLoader.exists(path) else null
	return _streams[key]


func _new_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		b.pressed.connect(func() -> void:
			var id := String(b.get_meta("sfx", "ui_click"))
			if id != "":
				play_id(id))
