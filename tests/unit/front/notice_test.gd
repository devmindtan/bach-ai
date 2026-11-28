extends RefCounted
## Notice.ask (web screen-notices): a key the player ticked "Không hỏi lại" for runs the action at once.

var failures: Array[String] = []


func test_skipped_key_runs_action_without_slip() -> void:
	var prefs := Prefs.current()
	var before: Array = prefs.skip_confirm.duplicate()
	prefs.skip_confirm = ["reset_tree"]
	var ran := [false]
	Notice.ask("reset_tree", "t", "x", "", "Tẩy tuỷ", func() -> void: ran[0] = true)
	if not ran[0]:
		failures.append("a skipped confirm did not run its action")
	prefs.skip_confirm = before


func test_unknown_key_is_not_skipped() -> void:
	if Notice.skipped("no_such_key_for_test"):
		failures.append("an unticked key reads as skipped")


func test_tight_crops_empty_margin() -> void:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(6, 6, 4, 4), Color.RED)
	var a := AtlasTexture.new()
	a.atlas = ImageTexture.create_from_image(img)
	a.region = Rect2(0, 0, 16, 16)
	var t := Notice.tight(a) as AtlasTexture
	if t == null or t.region != Rect2(6, 6, 4, 4):
		failures.append("tight region %s" % [t.region if t else null])
