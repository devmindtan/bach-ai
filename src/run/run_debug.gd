class_name RunDebug
extends RefCounted
## The run's measuring tools, out of run.gd (roadmap items 6-7, slice 2): the --bench report (avg / p95 sim and
## frame time after 660 frames) and the F1 overlay (fps, sim ms, monsters, effects, floor redraws, missing FX).
##
## Example (in Run):
##   _debug = RunDebug.new(self)
##   _debug.add_tick(sim_us); _debug.bench_sample()    # every frame of a --bench run
##   _debug.toggle()                                    # F1

var run: Node
var label: Label
var sim_ms := 0.0
var frame_ms := 0.0     # wall clock between frames (the engine fps is fixed when recording shots)
var _last_us := 0
var _frames := 0
var _tick_us: PackedInt64Array = []
var _frame_us: PackedInt64Array = []
var _bench_last_us := 0


func _init(p_run: Node) -> void:
	run = p_run


## One --bench frame: records the frame time; after 660 frames prints the BENCH line and quits.
func bench_sample() -> void:
	var now := Time.get_ticks_usec()
	_frames += 1
	if _frames > 61:
		_frame_us.append(now - _bench_last_us)
	_bench_last_us = now
	if _frames < 660:
		return
	var tick := Array(_tick_us)
	var frame := Array(_frame_us)
	tick.sort()
	frame.sort()
	var avg_tick := 0.0
	for v: int in tick:
		avg_tick += v
	avg_tick /= maxf(1.0, tick.size())
	var avg_frame := 0.0
	for v: int in frame:
		avg_frame += v
	avg_frame /= maxf(1.0, frame.size())
	print("BENCH enemies=%d living=%d sim_ms avg=%.2f p95=%.2f frame_ms avg=%.2f p95=%.2f fps=%.0f" % [
		run.bench, run.enemies.living(), avg_tick / 1000.0, tick[int(tick.size() * 0.95)] / 1000.0,
		avg_frame / 1000.0, frame[int(frame.size() * 0.95)] / 1000.0, 1000000.0 / avg_frame])
	run.get_tree().quit()


## The sim time of one frame ([param us]): kept for the bench, shown on the overlay.
func add_tick(us: int) -> void:
	if run.bench > 0 and _frames > 60:
		_tick_us.append(us)
	if label != null:
		sim_ms = lerpf(sim_ms, us / 1000.0, 0.1)
		var now := Time.get_ticks_usec()
		if _last_us > 0:
			frame_ms = lerpf(frame_ms, (now - _last_us) / 1000.0, 0.1)
		_last_us = now
		if Engine.get_process_frames() % 10 == 0:
			label.text = overlay_text(sim_ms)


## Shows / hides the overlay.
func toggle() -> void:
	if label != null:
		label.get_parent().queue_free()
		label = null
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	run.add_child(layer)
	label = UiKit.label("", 14, Color("b8ffb0"))
	label.position = Vector2(12, 84)
	label.add_theme_stylebox_override("normal", UiKit.style(Color(0, 0, 0, 0.6), 6, Color(0, 0, 0, 0), 0))
	layer.add_child(label)


func overlay_text(p_sim_ms: float) -> String:
	var g: Variant = run.get("_ground")
	return "FPS %d · khung %.1f ms\nMô phỏng %.2f ms\nQuái %d / %d\nHiệu ứng %d · nền vẽ lại %d\nThiếu FX: %s" % [
		roundi(1000.0 / maxf(0.1, frame_ms)) if frame_ms > 0.0 else 0, frame_ms, p_sim_ms,
		run.enemies.living() if run.enemies != null else 0, int(run.cfg.get("max_enemies", 0)), run.get("_fx").size(),
		g.redraws if g != null else 0, "không" if run.missing_fx.is_empty() else ", ".join(run.missing_fx)]
