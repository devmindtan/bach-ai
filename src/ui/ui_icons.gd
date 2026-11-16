class_name UiIcons
extends RefCounted
## The ui-icons sprite (Sprite Lab): heart, skull, coin, gem, star, clock,
## sword, boot. Draw one in _draw, or get a texture for a TextureRect.
##
## Example:
##   UiIcons.draw(self, "heart", Vector2(24, 40), 2.0)
##   rect.texture = UiIcons.texture("coin")

const DIR := "res://assets/sprites/custom/ui-icons"

static var _sheet: SpriteSheet
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


## The icon's frame as a texture (cached), for Controls.
static func texture(icon: String) -> Texture2D:
	if not _textures.has(icon):
		var s := sheet()
		if s == null or not s.has_animation(icon):
			return null
		var t := AtlasTexture.new()
		t.atlas = s.texture
		t.region = s.src_rect(int(s.animation(icon).get("start", 0)))
		_textures[icon] = t
	return _textures[icon]
