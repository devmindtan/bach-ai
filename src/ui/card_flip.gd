class_name CardFlip
extends RefCounted
## Cards that flip in from their backs one after another (design/ux/level-up.md, design/ux/gacha.md, 6D.2):
## each card closes its width showing a back (dark, a gold star, the back's border colour), then opens
## on its face. A card may wait longer before turning (a rare gacha result builds suspense) and pop
## (grow and settle) once its face shows. finish() ends every flip at once, for "any key skips".
##
## Example:
##   _flips = CardFlip.flip_in(row.get_children(), [], [], [])   # plain: gold-bordered backs
##   ... on any press: if CardFlip.finish(_flips): get_viewport().set_input_as_handled()

const HALF := 0.09      # s per half turn
const STAGGER := 0.08   # s between cards
const BACK := Color("1d1828")


## Starts the flips; [param borders] (Color), [param holds] (extra s before turning) and [param pops]
## (bool) are per card and may be shorter than [param cards] (defaults: gold, 0, false).
## Returns the records finish() takes. Call once the cards are laid out (sizes known).
static func flip_in(cards: Array, borders: Array, holds: Array, pops: Array) -> Array:
	var out := []
	var wait := 0.0
	for k in cards.size():
		var b: Control = cards[k]
		var border: Color = borders[k] if k < borders.size() else UiKit.GOLD
		var hold: float = holds[k] if k < holds.size() else 0.0
		var pop: bool = pops[k] if k < pops.size() else false
		b.pivot_offset = b.size * 0.5
		var back := Panel.new()
		back.add_theme_stylebox_override("panel", UiKit.style(BACK, 0, border, 3))
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var star := UiKit.icon("star", 48.0)
		var hs := star.custom_minimum_size * 0.5   # centre anchors + explicit offsets: follows the card's size
		star.anchor_left = 0.5
		star.anchor_right = 0.5
		star.anchor_top = 0.5
		star.anchor_bottom = 0.5
		star.offset_left = -hs.x
		star.offset_right = hs.x
		star.offset_top = -hs.y
		star.offset_bottom = hs.y
		back.add_child(star)
		b.add_child(back)
		b.scale.x = 0.0
		var t := b.create_tween()
		t.tween_interval(wait)
		t.tween_property(b, "scale:x", 1.0, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if hold > 0.0:
			t.tween_interval(hold)
		t.tween_property(b, "scale:x", 0.0, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(back.queue_free)
		t.tween_property(b, "scale:x", 1.0, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if pop:
			t.tween_property(b, "scale", Vector2(1.15, 1.15), 0.08)
			t.tween_property(b, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		wait += STAGGER + hold
		out.append([t, b, back])
	return out


## Ends every running flip in [param records] (face up, full size); true when one was still running.
static func finish(records: Array) -> bool:
	var any := false
	for f: Array in records:
		var t: Tween = f[0]
		if t.is_valid() and t.is_running():
			any = true
			t.kill()
		if is_instance_valid(f[2]):
			f[2].queue_free()
		if is_instance_valid(f[1]):
			f[1].scale = Vector2.ONE
	records.clear()
	return any
