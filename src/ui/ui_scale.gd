class_name UiScale
extends RefCounted
## Owns the one fact "how many pixels is a logical unit". The project leaves
## HiDPI on, so on a 2x screen (a Retina Mac, or a browser at devicePixelRatio
## 2) window sizes are physical pixels and, unscaled, every font, grip and
## dropdown came out half size. Each native window applies factor() as its
## content scale and sizes itself in px(); the main window is fitted once so it
## keeps its point size.
##
## An EMBEDDED window (the console and noise windows: the project embeds them,
## and headless and the web always do) is drawn inside its embedder's canvas and
## so already inherits the embedder's scale: it keeps factor 1 and is sized in
## logical units, or it would scale twice.

## Tests set this to stand in for the screen's scale; 0 means ask the display.
static var override := 0.0

## Set once fit_main_window() has resized the main window, so the title menu
## and the explorer (which both call it) fit it only the first time.
static var _fitted := false


## Pixels per logical unit: the override, else the screen's scale clamped into
## [1, 4]. Headless reports 1.
static func factor() -> float:
	if override > 0.0:
		return override
	return clampf(DisplayServer.screen_get_scale(), 1.0, 4.0)


## The content scale `window` should use: factor() when it is (or will be) a
## native window, 1 when it is embedded.
static func factor_for(window: Window) -> float:
	return 1.0 if _is_embedded(window) else factor()


## Give `window` its content scale. A window already using a stretch mode is
## left alone: someone else (the UI test driver's root) owns its scaling.
## Idempotent.
static func apply(window: Window) -> void:
	if window == null or window.content_scale_mode != Window.CONTENT_SCALE_MODE_DISABLED:
		return
	window.content_scale_factor = factor_for(window)


## `logical` in pixels: at factor() by default, or at the factor `window` uses.
static func px(logical: Vector2i, window: Window = null) -> Vector2i:
	var f := factor() if window == null else factor_for(window)
	return Vector2i(roundi(logical.x * f), roundi(logical.y * f))


## Once per process and never on the web (the canvas follows the page): if the
## main window is still at the project's default pixel size, resize it to
## px(logical) so it keeps its point size on a HiDPI screen, re-centred on where
## it was. A window the player already resized, or maximised, is left alone.
static func fit_main_window(window: Window, logical: Vector2i) -> void:
	if _fitted or window == null or OS.has_feature("web"):
		return
	if window.mode != Window.MODE_WINDOWED or window.size != _default_window_size():
		return
	_fitted = true
	var target := px(logical)   # the main window is never embedded
	if target == window.size:
		return
	var grown := target - window.size
	window.size = target
	window.position -= grown / 2
	if not _is_embedded(window):
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		if usable.has_area():
			window.position = window.position.max(usable.position)


## Put `window` over `parent_window`. Embedded: centred in the embedder's
## visible rect, never above its top-left (the title bar stays reachable).
## Native: centred over the parent window in screen pixels.
static func center_over(window: Window, parent_window: Window) -> void:
	if window.is_embedded():
		var embedder := _embedder(window)
		if embedder == null:
			return
		var rect := embedder.get_visible_rect()
		var top_left := Vector2i(rect.position) + (Vector2i(rect.size) - window.size) / 2
		var title := window.get_theme_constant(&"title_height")
		window.position = Vector2i(maxi(top_left.x, int(rect.position.x)),
			maxi(top_left.y, int(rect.position.y) + title))
	elif parent_window != null:
		window.position = parent_window.position + (parent_window.size - window.size) / 2


static func _default_window_size() -> Vector2i:
	return Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
		ProjectSettings.get_setting("display/window/size/viewport_height", 800))


## In the tree, ask the window. Not yet (ConsoleWindow sizes itself before Main
## adds it): it will be embedded exactly when the root embeds sub-windows, which
## Godot forces on headless and the web.
static func _is_embedded(window: Window) -> bool:
	if window.is_inside_tree():
		return window.is_embedded()
	var tree := Engine.get_main_loop() as SceneTree
	return tree != null and tree.root != null and tree.root.gui_embed_subwindows


## The viewport an embedded window is drawn in: the nearest viewport above it
## that embeds sub-windows. (Window.get_embedder() is not exposed to scripts.)
static func _embedder(window: Window) -> Viewport:
	var parent := window.get_parent()
	var vp: Viewport = parent.get_viewport() if parent != null else null
	while vp != null and not vp.gui_embed_subwindows:
		var above := vp.get_parent()
		vp = above.get_viewport() if above != null else null
	return vp
