class_name TextFocus
extends RefCounted
## Is a text-entry control focused in any of the given viewports? The main
## window and the console are separate viewports (the console is a native
## Window), so both the axis controller and the fly camera ask about both:
## typing "e" into a spin box must never move an axis or the camera.


## True when a LineEdit or TextEdit holds keyboard focus in any viewport.
static func any(viewports: Array) -> bool:
	for vp in viewports:
		if vp == null:
			continue
		var owner := (vp as Viewport).gui_get_focus_owner()
		if owner is LineEdit or owner is TextEdit:
			return true
	return false
