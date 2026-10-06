extends "res://tests/test_case.gd"


func run() -> void:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var panel: ControlsPanel = load("res://src/ui/controls_panel.tscn").instantiate()
	root.add_child(panel)
	panel.setup(params, cam)
	await frames(1)

	# --- each widget writes its field ---
	panel.scale_slider.value = -3.0
	check_approx(params.scale, -3.0, "scale slider writes scale")
	panel.inner_slider.value = 0.5
	check_approx(params.inner_radius, 0.5, "inner slider writes inner_radius")
	panel.fold_slider.value = 0.8
	check_approx(params.fold_limit, 0.8, "fold slider writes fold_limit")
	panel.outer_slider.value = 0.9
	check_approx(params.outer_radius, 0.9, "outer slider writes outer_radius")
	panel.color_option.select(2)             # dropdown index 2 -> id 2 (Borg)
	panel.color_option.item_selected.emit(2)
	check_eq(params.color_mode, 2, "colour dropdown writes the id")
	panel.sens_slider.value = 0.3
	check_approx(params.mouse_sensitivity, 0.3, "sensitivity slider writes it")
	panel.julia_check.button_pressed = true
	panel.julia_check.toggled.emit(true)
	check_eq(params.julia_enabled, true, "julia check writes julia_enabled")
	panel.fast_check.button_pressed = false
	panel.fast_check.toggled.emit(false)
	check_eq(params.fast_controls, false, "fast check writes fast_controls")
	panel.camera_option.select(1)
	panel.camera_option.item_selected.emit(1)
	check_eq(params.camera_mode, FractalParams.CameraMode.ORBIT, "camera dropdown writes the mode")

	# --- valid precision is applied on submit; invalid reverts ---
	panel.precision_edit.text = "0.0001"
	panel.precision_edit.text_submitted.emit("0.0001")
	check_approx(params.precision, 0.0001, "valid precision is applied", 1e-9)
	panel.precision_edit.text = "not a number"
	panel.precision_edit.text_submitted.emit("not a number")
	check_approx(params.precision, 0.0001, "invalid precision leaves the value", 1e-9)
	check_eq(panel.precision_edit.text, "0.0001", "and the field reverts its text")

	# --- external change updates the widget ---
	params.scale = -1.0
	await frames(1)
	check_approx(panel.scale_slider.value, -1.0, "external scale change updates the slider")
	params.julia_point = Vector3(1, 2, 3)
	await frames(1)
	check_approx(panel.julia_x.text.to_float(), 1.0, "external julia move updates the X field")

	panel.queue_free()
	await frames(1)
