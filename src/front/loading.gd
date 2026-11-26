extends Node2D
## The light loading screen before a run (user 2026-11-26: "màn hình tải trận nhẹ khi vào trận";
## design-web/games/bach-ai/screen-loading.html): flat dusk colours, where the run goes (region + stage, Vô tận or the
## challenge), a dashed ink track with the hero running along it, one tip. It loads the run scene on a thread and
## opens it when loaded, after at least MIN_TIME s so the screen does not flash.

const RUN_SCENE := "res://src/run/run.tscn"
const MIN_TIME := 1.2
const TRACK := Rect2(340, 470, 600, 4)
const TIPS := ["Đứng yên một giây để Mắt ưng mở rộng tầm bắn.", "Quái mang dấu Yếu nhận thêm sát thương hệ đó.",
	"Space để lướt: không bị trúng đòn khi đang lướt.", "Mốc cấp 10 / 20 / 30 cho chọn thẻ đặc biệt.",
	"Bấm C ở sổ để xem đủ chỉ số."]

var _t := 0.0
var _hero: SpriteSheet
var _done := false


## [region line, big line] for a run of stage [param n] (endless / a challenge id when set).
static func heading(stages: Stages, n: int, endless: bool, challenge: String) -> Array:
	var region := String(stages.region(n).get("name", "")).to_upper()
	if challenge != "":
		for c: Dictionary in GameData.load_json("res://assets/data/challenges.json").get("challenges", []):
			if String(c.get("id", "")) == challenge:
				return ["THỬ THÁCH", String(c.get("name", challenge))]
	if endless:
		return [region, "Vô tận"]
	var boss := n % int(GameData.load_json("res://assets/data/stages.json").get("boss_every", 10)) == 0
	return [region, ("Trùm · Ải %d" if boss else "Ải %d") % n]


func _ready() -> void:
	var p := Prefs.current()
	var h := heading(Stages.load_default(), p.stage_target, p.endless_target, p.challenge_target)
	var classes := GameData.load_json("res://assets/data/classes.json")
	var cls: String = p.active_slot.cls if p.active_slot != null else p.hero
	_hero = FrontArt.hero_sheet(classes.get(cls, {}), p.active_slot.profile.equipped(cls).values() if p.active_slot != null else [])
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := UiKit.label(String(h[0]), 22, Color("ffb070"))
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.position = Vector2(0, 250)
	top.size = Vector2(1280, 30)
	layer.add_child(top)
	var big := UiKit.label(String(h[1]), 68, Color("fff0d0"))
	big.add_theme_color_override("font_shadow_color", Color("6a1a14"))
	big.add_theme_constant_override("shadow_offset_x", 0)
	big.add_theme_constant_override("shadow_offset_y", 4)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.position = Vector2(0, 280)
	big.size = Vector2(1280, 90)
	layer.add_child(big)
	var tip := UiKit.label("Mẹo: " + TIPS[int(Time.get_unix_time_from_system()) % TIPS.size()], 20, Color("c8a890"))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.position = Vector2(0, 530)
	tip.size = Vector2(1280, 30)
	layer.add_child(tip)
	ResourceLoader.load_threaded_request(RUN_SCENE)


func _progress() -> float:
	var arr := []
	var st := ResourceLoader.load_threaded_get_status(RUN_SCENE, arr)
	var loaded := 1.0 if st == ResourceLoader.THREAD_LOAD_LOADED else (float(arr[0]) if not arr.is_empty() else 0.0)
	return minf(loaded, _t / MIN_TIME)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _done or _progress() < 1.0 or OS.get_cmdline_user_args().has("--loading-hold"):   # --loading-hold: shots
		return
	_done = true
	var scene := ResourceLoader.load_threaded_get(RUN_SCENE) as PackedScene
	get_tree().change_scene_to_packed(scene)


func _draw() -> void:
	var size := get_viewport_rect().size
	for k in 18:   # flat dusk: a few bands, no images
		draw_rect(Rect2(0, size.y * k / 18.0, size.x, size.y / 18.0 + 1), Color("1a1030").lerp(Color("140a14"), minf(1.0, k / 11.0)))
	var x := TRACK.position.x
	while x < TRACK.end.x:   # the dashed ink track
		draw_rect(Rect2(x, TRACK.position.y, 10, 4), Color("8a6a4a"))
		x += 18.0
	var k := _progress() if not OS.get_cmdline_user_args().has("--loading-hold") else 0.55
	draw_rect(Rect2(TRACK.position, Vector2(TRACK.size.x * k, 4)), Color("ff7a3a"))
	if _hero != null:
		var anim := "run" if _hero.has_animation("run") else "idle"
		_hero.draw(self, anim, _t, TRACK.position + Vector2(TRACK.size.x * k, 0), FrontArt.scale_of(_hero, 2.0))
