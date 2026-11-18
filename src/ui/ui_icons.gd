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


## The icon's frame as a texture (cached), for Controls: ui-icons first, then
## gear-icons (item ids).
static func texture(icon: String) -> Texture2D:
	if not _textures.has(icon):
		var s := sheet()
		if s == null or not s.has_animation(icon):
			s = gear()
		if s == null or not s.has_animation(icon):
			return null
		var t := AtlasTexture.new()
		t.atlas = s.texture
		t.region = s.src_rect(int(s.animation(icon).get("start", 0)))
		_textures[icon] = t
	return _textures[icon]
