extends "res://tests/ui_test_case.gd"
## The console driven like a player, in a scaled headless root: the wheel over a
## row label, a slider and an unfocused spin box scrolls the Shape list without
## changing any value; a trackpad pan scrolls; the Colour dropdown opens on a
## click and a click on "Blue" recolours; a Source dropdown binds Axis A; a
## click on a slider track and a drag of its grabber set the value; typing into
## a spin box and pressing Enter writes the table; and the Movement pane's Add
## axis, key capture, rename, zero and remove all work by clicks and keys.
##
## Two layout defects are recorded as known bugs (see `_layout_at_default_width`):
## at the console's default 1000 px width the Shape sliders collapse to their
## 16 px grabber and the Movement pane runs past the window's right edge. The
## slider and Movement checks therefore run after the player widens the window
## and drags the split handle, which is the workaround today.

var ui: UiDriver
var table: AttributeTable
var km: Keymap
var console: ConsoleWindow
var scroll: ScrollContainer


func run() -> void:
	ui = UiDriver.new(self)
	await ui.setup()
	table = AttributeTable.new(MandelboxShape.specs())
	km = Keymap.new()
	km.add_axis(&"a", "Axis A", 1.0, KEY_E, KEY_Q)
	var clock := Clock.new()
	root.add_child(clock)
	console = ConsoleWindow.new()
	console.setup(table, km, clock, MandelboxShape.group_tooltips(), func() -> float: return 1.0)
	root.add_child(console)
	# Shorter than the list, so there is real scroll range.
	console.size = Vector2i(1000, 400)
	console.open()
	await ui.frames(3)
	scroll = console.inspector().get_child(0) as ScrollContainer

	await _opens_on_screen()
	await _wheel_scrolls_without_editing()
	await _pan_scrolls()
	await _colour_dropdown()
	await _source_dropdown()
	await _spin_typing()
	await _layout_at_default_width()
	await _widen_and_drag_split()
	await _slider_click_and_drag()
	await _movement_pane()

	for action in InputMap.get_actions():
		if String(action).begins_with("axis_"):
			InputMap.erase_action(action)
	console.queue_free()
	clock.queue_free()
	await ui.frames(1)


func _opens_on_screen() -> void:
	check(console.visible and console.is_embedded(), "the console opens as a window embedded in the root")
	var surface := root.get_visible_rect()
	var rect := Rect2(Vector2(console.position), Vector2(console.size))
	check(surface.encloses(rect), "it opens wholly inside the main window (%s in %s)" % [rect, surface])
	check(scroll != null, "the Shape pane is a ScrollContainer")
	var bar := scroll.get_v_scroll_bar()
	check(bar.max_value > bar.page + 100.0,
		"the Shape list is taller than the window, so it can scroll (range %.0f, page %.0f)" % [bar.max_value, bar.page])


## The first row (in list order) of the given widget kind that is wholly inside
## the visible part of the list.
func _visible_widget(kind: String) -> Control:
	var view := ui.global_rect(scroll)
	for spec in table.specs:
		var row := console.inspector().row(spec.id)
		if row == null or not row.visible:
			continue
		var c: Control = null
		match kind:
			"label":
				c = row.get_child(0) as Control
			"slider":
				c = row.value_control() as HSlider
			"spin":
				c = row.spin_box()
		if c != null and c.is_visible_in_tree() and view.encloses(ui.global_rect(c)):
			return c
	return null


func _values() -> Dictionary:
	return table.defaults().duplicate()


func _wheel_scrolls_without_editing() -> void:
	check_eq(scroll.scroll_vertical, 0, "the list starts at the top")
	var before := _values()
	var label := _visible_widget("label")
	check(label is Label, "a row label is on screen")
	var at := scroll.scroll_vertical
	await ui.wheel(label, true, 2)
	check(scroll.scroll_vertical > at, "the wheel over a row label scrolls the list (%d -> %d)" % [at, scroll.scroll_vertical])

	var slider := _visible_widget("slider")
	check(slider is HSlider, "a slider is on screen")
	at = scroll.scroll_vertical
	await ui.wheel(slider, true, 2)
	check(scroll.scroll_vertical > at, "the wheel over a slider scrolls the list (%d -> %d)" % [at, scroll.scroll_vertical])

	var spin := _visible_widget("spin") as SpinBox
	check(spin != null, "a spin box is on screen")
	check(spin != null and not spin.get_line_edit().has_focus(), "…and it is not focused")
	at = scroll.scroll_vertical
	await ui.wheel(spin, true, 2)
	check(scroll.scroll_vertical > at, "the wheel over an unfocused spin box scrolls the list (%d -> %d)" % [at, scroll.scroll_vertical])
	check_eq(_values(), before, "and no wheel turn changed any value")

	at = scroll.scroll_vertical
	await ui.wheel(_visible_widget("label"), false, 1)
	check(scroll.scroll_vertical < at, "the wheel up scrolls back (%d -> %d)" % [at, scroll.scroll_vertical])


func _pan_scrolls() -> void:
	var at := scroll.scroll_vertical
	await ui.pan(_visible_widget("label"), Vector2(0, 1))
	check(scroll.scroll_vertical > at, "a trackpad pan down scrolls the list (%d -> %d)" % [at, scroll.scroll_vertical])
	at = scroll.scroll_vertical
	await ui.pan(_visible_widget("label"), Vector2(0, -1))
	check(scroll.scroll_vertical < at, "a pan up scrolls it back (%d -> %d)" % [at, scroll.scroll_vertical])


func _colour_dropdown() -> void:
	var option := console.inspector().row(&"color_mode").value_control() as OptionButton
	check(await ui.scroll_to(scroll, option), "the wheel brings the Colour row into view")
	await ui.click(option)
	var popup := option.get_popup()
	check(popup.visible, "a click on the Colour dropdown opens its list")
	check_eq(popup.item_count, FractalParams.COLOR_MODE_NAMES.size(), "the list has every colour mode")
	var popup_rect := Rect2(ui.window_origin(popup), Vector2(popup.size))
	check(root.get_visible_rect().encloses(popup_rect),
		"the open list fits inside the main window (%s)" % popup_rect)
	check(popup.size.y > popup.item_count * 16.0, "…at full size, %d px tall for %d items" % [popup.size.y, popup.item_count])
	var clicked := await ui.select_popup_item(popup, "Blue")
	check(clicked, "the mouse finds and clicks Blue")
	await ui.frames(1)
	check_eq(int(table.get_default(&"color_mode")), 5, "clicking Blue sets color_mode to Blue (5)")
	check_eq(option.get_item_text(option.selected), "Blue", "the dropdown now shows Blue")
	check(not popup.visible, "and the list closed")


func _source_dropdown() -> void:
	var row := console.inspector().row(&"box_scale")
	var src := row.source_option()
	check(await ui.scroll_to(scroll, src), "the wheel brings the Scale row back into view")
	check(await ui.select_option(src, "Axis A"), "the Source dropdown opens and Axis A is clicked")
	await ui.frames(1)
	var b := table.binding(&"box_scale")
	check(b != null and b.source == &"a", "selecting Axis A binds Scale to it")
	km.axes().set_value(&"a", 0.5)
	console.set_resolved(BindingResolver.resolve(table, km.axes().values(), 0.0))
	await ui.frames(1)
	check(row.readout().visible, "the row shows a readout of the value in use")
	check(row.readout().text.contains("-1.59"), "…default -2.09 plus gain 1 x 0.5 (%s)" % row.readout().text)
	km.axes().set_value(&"a", 0.0)


func _layout_at_default_width() -> void:
	console.size = Vector2i(ConsoleWindow.DEFAULT_SIZE.x, 400)
	await ui.frames(2)
	var slider := console.inspector().row(&"box_scale").value_control() as HSlider
	# BUG: the Shape rows' fixed widgets (label 140, spin 92, source/gain/wave/
	# period ~350) fill the inspector's 643 px minimum, and the HSplit never gives
	# the inspector more than that below ~1300 px, so every slider is squeezed to
	# its 16 px grabber at the default console width: it cannot be dragged.
	known_bug(slider.size.x >= 100.0,
		"at the default console width a Shape slider is wide enough to drag (%.0f px)" % slider.size.x,
		"AttributeRow sliders collapse to 16 px because the inspector is held at its 643 px minimum")
	var pane := console.movement_pane()
	var right := float(console.position.x + console.size.x)
	var remove := pane.axis_line(&"a")["remove"] as Control
	# BUG: inspector minimum (643) + split handle (12) + Movement pane minimum
	# (401) = 1056 px > the 1000 px default width (wrap_controls is off), so the
	# Movement pane runs 56 px past the window's right edge: the negative-key and
	# remove buttons of every axis line are drawn outside the window and cannot
	# be clicked.
	known_bug(ui.global_rect(pane).end.x <= right + 0.5,
		"at the default console width the Movement pane fits in the window (ends at %.0f, window %.0f)" % [ui.global_rect(pane).end.x, right],
		"content minimum width 1056 px exceeds ConsoleWindow.DEFAULT_SIZE.x 1000")
	known_bug(ui.global_rect(remove).end.x <= right,
		"at the default console width an axis's remove button is inside the window (x %.0f..%.0f, window right %.0f)" % [
			ui.global_rect(remove).position.x, ui.global_rect(remove).end.x, right],
		"the ✕ button lies past the console's right edge")


## The workaround a player has today: widen the console, then drag the split
## handle right so the Shape pane gets the room.
func _widen_and_drag_split() -> void:
	console.size = Vector2i(1260, 400)
	console.position = Vector2i(10, 200)
	await ui.frames(2)
	var inspector := console.inspector()
	var pane := console.movement_pane()
	var right := float(console.position.x + console.size.x)
	check(ui.global_rect(pane).end.x <= right + 0.5, "at 1260 px the Movement pane fits in the window")
	var before := inspector.size.x
	var handle := Vector2((ui.global_rect(inspector).end.x + ui.global_rect(pane).position.x) * 0.5,
		ui.global_rect(inspector).get_center().y)
	await ui.drag(handle, handle + Vector2(300, 0))
	await ui.frames(1)
	check(inspector.size.x > before + 100.0, "dragging the split handle right widens the Shape pane (%.0f -> %.0f)" % [before, inspector.size.x])
	var slider := inspector.row(&"fold_limit").value_control() as HSlider
	check(slider.size.x >= 100.0, "…and gives the sliders room (%.0f px)" % slider.size.x)


func _slider_click_and_drag() -> void:
	var row := console.inspector().row(&"fold_limit")
	var slider := row.value_control() as HSlider
	check(await ui.scroll_to(scroll, slider), "the Fold limit slider is in view")
	await ui.click_at(ui.global_point(slider, Vector2(0.75, 0.5)))
	var v := float(table.get_default(&"fold_limit"))
	check(v > 2.0 and v < 2.5, "a click three quarters along the slider sets Fold limit near 2.25 (%.3f)" % v)
	check_approx(row.spin_box().value, v, "the spin box follows the slider")
	var grab := ui.global_point(slider, Vector2(slider.value / slider.max_value, 0.5))
	await ui.drag(grab, ui.global_point(slider, Vector2(0.25, 0.5)))
	v = float(table.get_default(&"fold_limit"))
	check(v > 0.5 and v < 1.0, "dragging the grabber to a quarter sets it near 0.75 (%.3f)" % v)


func _spin_typing() -> void:
	var row := console.inspector().row(&"min_radius")
	var spin := row.spin_box()
	check(await ui.scroll_to(scroll, spin), "the Min radius spin box is in view")
	await ui.type_text(spin.get_line_edit(), "0.55")
	check_approx(float(table.get_default(&"min_radius")), 0.55, "typing 0.55 and Enter writes the table")
	check_approx((row.value_control() as HSlider).value, 0.55, "and the slider follows")
	spin.get_line_edit().release_focus()
	await ui.frames(1)


func _movement_pane() -> void:
	var pane := console.movement_pane()
	var before := km.axes().list().size()
	await ui.click(pane.add_button())
	await ui.frames(2)
	check_eq(km.axes().list().size(), before + 1, "a click on Add axis adds an axis")
	var id: StringName = &""
	for axis in km.axes().list():
		if axis.id != &"a":
			id = axis.id
	var line := pane.axis_line(id)
	check(not line.is_empty(), "…with its own line in the pane (%s)" % id)
	if line.is_empty():
		return

	# key capture: click the positive key button, then press T
	var pos: KeyCaptureButton = line["pos"]
	await ui.click(pos)
	check(pos.is_capturing(), "a click on the key button starts a capture")
	await ui.tap(KEY_T)
	check(not pos.is_capturing(), "pressing a key ends it")
	check_eq(km.positive_key(id), KEY_T, "and binds T as the axis's positive key")
	var events := InputMap.action_get_events(StringName("axis_%s_pos" % id))
	check(events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_T,
		"the InputMap action follows")

	# rename by typing into the label field
	var src := console.inspector().row(&"box_scale").source_option()
	await ui.type_text(line["label"], "Warp")
	await ui.frames(1)
	check_eq(km.axes().label(id), "Warp", "typing a new label and Enter renames the axis")
	var texts: Array = []
	for i in src.item_count:
		texts.append(src.get_item_text(i))
	check(texts.has("Warp"), "and the Source dropdowns list the new name (%s)" % [texts])
	(line["label"] as LineEdit).release_focus()

	# the 0 button zeroes the axis
	km.axes().set_value(id, 3.0)
	await ui.click(line["zero"])
	check_approx(km.axes().value(id), 0.0, "a click on 0 zeroes the axis")

	# the remove button drops it, and the dropdowns follow
	await ui.click(line["remove"])
	await ui.frames(2)
	check(not km.axes().has(id), "a click on ✕ removes the axis")
	texts.clear()
	for i in src.item_count:
		texts.append(src.get_item_text(i))
	check(not texts.has("Warp"), "and the Source dropdowns drop it (%s)" % [texts])
