class_name UiFonts
extends RefCounted
## Bundled fallback fonts for the UI. The default font lacks some symbols the game
## shows (▶, ★, ◆, …); desktop builds borrowed them from system fonts but the Web
## build has none, so they rendered as boxes. install() appends the bundled fonts
## as fallbacks of the engine default font, the same on every platform.
## Test: tests/unit/ui/glyph_coverage_test.gd.

const FALLBACKS := ["res://assets/fonts/DejaVuSans.ttf"]   # Bitstream Vera licence: assets/credits/font-dejavu-sans.txt


## Adds the bundled fallbacks once (Prefs calls it at start).
static func install() -> void:
	var base := ThemeDB.fallback_font
	if base == null:
		return
	var list: Array[Font] = base.fallbacks.duplicate()
	for path: String in FALLBACKS:
		var f := load(path) as Font
		if f != null and not list.has(f):
			list.append(f)
	base.fallbacks = list
