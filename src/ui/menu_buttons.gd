class_name MenuButtons
extends RefCounted
## The plain text buttons both menus use: default font, no box, larger size.

const FONT_SIZE := 28


static func make(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	return b
