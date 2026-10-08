extends "res://tests/test_case.gd"
## The console window builds both panes; a row edit lands in the table; the
## source dropdown lists the axes and updates on Keymap.changed; the readout
## follows set_resolved; the Movement pane adds, rebinds and removes an axis
## through the API and the key-capture button; a Ctrl tap emits toggle_requested.


func _ctrl(pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_CTRL
	ev.pressed = pressed
	ev.echo = false
	return ev


func run() -> void:
	var table := AttributeTable.new(MandelboxShape.specs())
	var km := Keymap.new()
	km.add_axis(&"a", "Axis A", 1.0, KEY_E, KEY_Q)
	var clock := Clock.new()
	root.add_child(clock)
	var console := ConsoleWindow.new()
	console.setup(table, km, clock, MandelboxShape.group_tooltips(), func() -> float: return 1.0)
	root.add_child(console)
	console.open()
	await frames(1)

	var inspector := console.inspector()
	var movement := console.movement_pane()

	# --- the Shape pane has one row per spec ---
	check_eq(inspector.row_count(), table.specs.size(), "one row per spec")

	# --- a row edit lands in the table ---
	inspector.row(&"box_scale").spin_box().value = 1.0
	check_approx(table.get_default(&"box_scale"), 1.0, "a spin edit writes the table")

	# --- the source dropdown lists None, Time, Axis A ---
	var src := inspector.row(&"box_scale").source_option()
	check_eq(src.item_count, 3, "source has None, Time, Axis A")
	check_eq(src.get_item_text(0), "None", "first is None")
	check_eq(src.get_item_text(1), "Time", "second is Time")
	check_eq(src.get_item_text(2), "Axis A", "third is Axis A")

	# --- adding an axis updates the dropdown (console refreshes on changed) ---
	km.add_axis(&"b", "Axis B", 1.0, KEY_NONE, KEY_NONE)
	await frames(1)
	check_eq(src.item_count, 4, "a new axis appears in the dropdown")
	check_eq(src.get_item_text(3), "Axis B", "named Axis B")

	# --- selecting a source writes the binding; the readout follows set_resolved ---
	src.select(2)                       # Axis A
	src.item_selected.emit(2)
	check_eq(table.binding(&"box_scale").source, &"a", "selecting a source writes the binding")
	console.set_resolved({&"box_scale": -1.59})
	await frames(1)
	check(inspector.row(&"box_scale").readout().visible, "an active binding shows a readout")
	check(inspector.row(&"box_scale").readout().text.contains("-1.59"), "the readout shows the resolved value")

	# --- Movement pane: Add axis grows the keymap ---
	var before := km.axes().list().size()
	movement.add_button().pressed.emit()
	await frames(1)
	check_eq(km.axes().list().size(), before + 1, "Add axis adds an axis to the keymap")

	# --- a key-capture button rebinds through the API ---
	var line := movement.axis_line(&"b")
	check(not line.is_empty(), "Axis B has a line")
	var pos_btn: KeyCaptureButton = line["pos"]
	pos_btn.pressed.emit()                 # begin capture
	pos_btn._capture(KEY_T)                 # press T
	await frames(1)
	check_eq(km.positive_key(&"b"), KEY_T, "the key-capture button rebinds the positive key")
	check(InputMap.action_get_events(&"axis_b_pos").size() == 1, "and the InputMap action followed")

	# --- the remove button drops the axis ---
	movement.axis_line(&"b")["remove"].pressed.emit()
	await frames(1)
	check(not km.axes().has(&"b"), "the remove button drops the axis")
	await frames(1)
	var texts: Array = []
	for i in src.item_count:
		texts.append(src.get_item_text(i))
	check(not texts.has("Axis B"), "and the dropdown drops it too (items: %s)" % [texts])

	# --- a Ctrl tap in the console emits toggle_requested ---
	var toggled := [false]
	console.toggle_requested.connect(func(): toggled[0] = true)
	console.feed_ctrl(_ctrl(true))
	console.feed_ctrl(_ctrl(false))
	check(toggled[0], "a Ctrl tap in the console emits toggle_requested")

	# clean up the runtime InputMap actions this test created
	for id in [&"a", &"ax1", &"ax2", &"ax3"]:
		if InputMap.has_action(StringName("axis_%s_pos" % id)):
			InputMap.erase_action(StringName("axis_%s_pos" % id))
		if InputMap.has_action(StringName("axis_%s_neg" % id)):
			InputMap.erase_action(StringName("axis_%s_neg" % id))
	console.queue_free()
	clock.queue_free()
	await frames(1)
