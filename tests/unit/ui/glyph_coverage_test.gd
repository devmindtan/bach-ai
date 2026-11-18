extends RefCounted
## Every character the game can show must exist in the UI font chain (the default
## font + UiFonts fallbacks). Desktop builds borrow missing glyphs from system
## fonts, the Web build cannot: "Chọn ải ▶" showed a box there (2026-11-18).

var failures: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _collect_gd(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect_gd(dir.path_join(d), out)


func _strings(v: Variant, out: Dictionary) -> void:
	if v is String:
		for c in String(v):
			out[c] = true
	elif v is Dictionary:
		for k: Variant in v:
			_strings(v[k], out)
	elif v is Array:
		for e: Variant in v:
			_strings(e, out)


func _covered(font: Font, ch: int) -> bool:
	if font.has_char(ch):
		return true
	for fb: Font in font.fallbacks:
		if _covered(fb, ch):
			return true
	return false


func test_every_shown_character_is_in_the_font_chain() -> void:
	UiFonts.install()
	var chars := {}
	# string literals in code (comments skipped: after a "#" outside quotes is rare
	# enough in this codebase that literals are taken from "..." spans only)
	var files: Array[String] = []
	_collect_gd("res://src", files)
	var re := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	for path in files:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for m in re.search_all(line):
				for c in m.get_string(1):
					chars[c] = true
	for f in DirAccess.get_files_at("res://assets/data"):
		if f.ends_with(".json"):
			_strings(GameData.load_json("res://assets/data/" + f), chars)
	var font := ThemeDB.fallback_font
	var missing: Array[String] = []
	for c: String in chars:
		var code := c.unicode_at(0)
		if code < 32 or c == " ":
			continue
		if not _covered(font, code):
			missing.append("%s (U+%04X)" % [c, code])
	_check(missing.is_empty(), "glyphs missing from the UI font chain: %s" % ", ".join(missing))
