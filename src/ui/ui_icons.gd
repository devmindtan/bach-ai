class_name UiIcons
extends RefCounted
## The ui-icons sprite (Sprite Lab): heart, skull, coin, gem, star, clock,
## sword, boot, plus one icon per upgrade id (blade_arc, back_slash, whirlwind,
## sharpen, haste, reach, vitality, swift, magnet, regen, frost_nova, earth_strike).
## Draw one in _draw, or get a texture for a TextureRect.
##
## Example:
##   UiIcons.draw(self, "heart", Vector2(24, 40), 2.0)
##   rect.texture = UiIcons.texture("coin")

const DIR := "res://assets/sprites/custom/ui-icons"
const GEAR_DIR := "res://assets/sprites/custom/gear-icons"   # 24 px equipment icons (one per item id)

static var _sheet: SpriteSheet
static var _gear: SpriteSheet
static var _glyphs: SpriteSheet
static var _cards: SpriteSheet
const CARD_DIR := "res://assets/sprites/custom/card-icons"   # 24 px card icons (user 2026-11-20), first choice
const GLYPH_DIR := "res://assets/sprites/custom/card-glyphs"   # card tree change symbols + Mảnh thẻ
static var _textures := {}


static func sheet() -> SpriteSheet:
	if _sheet == null:
		_sheet = SpriteSheet.load_dir(DIR, "ui-icons")
	return _sheet


## Draws icon [param icon] centred on [param center] at [param scale] (whole pixels).
static func draw(canvas: CanvasItem, icon: String, center: Vector2, scale := 2.0) -> void:
	var s := sheet()
	if s != null and s.has_animation(icon):
		s.draw(canvas, icon, 0.0, center, scale)


## The equipment icon sheet (gear-icons).
static func gear() -> SpriteSheet:
	if _gear == null:
		_gear = SpriteSheet.load_dir(GEAR_DIR, "gear-icons")
	return _gear


## The icon's frame as a texture (cached), for Controls: card-icons first, then ui-icons, then
## gear-icons (item ids), then card-glyphs (card tree symbols, "shard").
static func texture(icon: String) -> Texture2D:
	if not _textures.has(icon):
		if _cards == null:
			_cards = SpriteSheet.load_dir(CARD_DIR, "card-icons")
		var s := _cards
		if s == null or not s.has_animation(icon):
			s = sheet()
		if s == null or not s.has_animation(icon):
			s = gear()
		if s == null or not s.has_animation(icon):
			if _glyphs == null:
				_glyphs = SpriteSheet.load_dir(GLYPH_DIR, "card-glyphs")
			s = _glyphs
		if s == null or not s.has_animation(icon):
			return null
		var t := AtlasTexture.new()
		t.atlas = s.texture
		t.region = s.src_rect(int(s.animation(icon).get("start", 0)))
		_textures[icon] = t
	return _textures[icon]


static var _vector_map: Dictionary = {}


## A card's icon: its vector icon when card_icons.json has one (stat cards, user 2026-11-21), else
## texture(). Only card views call this: card ids share names with stat icons ("magnet").
static func card_texture(id: String) -> Texture2D:
	var vec := _vector(id)
	return vec if vec != null else texture(id)


## Stat cards draw a vector icon (assets/data/card_icons.json, user 2026-11-21); null when [param id]
## has none, so the pixel sheets answer.
static func _vector(id: String) -> Texture2D:
	if _vector_map.is_empty():
		_vector_map = GameData.load_json("res://assets/data/card_icons.json")
	var name := String(_vector_map.get("vector", {}).get(id, ""))
	var path := "res://assets/icons/tree/%s.svg" % name
	if name == "" or not ResourceLoader.exists(path):
		return null
	return UiKit.vector_texture(path, int(_vector_map.get("px", 64)))
