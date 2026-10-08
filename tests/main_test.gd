extends "res://tests/test_case.gd"


func run() -> void:
	var settings: Node = root.get_node("Settings")
	var original_sens: float = settings.mouse_sensitivity
	settings.config_path = "user://main_test_settings.cfg"

	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await frames(2)

	var panel: ControlsPanel = main.get_node("ControlsPanel")
	var fly: FlyCamera = main.get_node("FlyCamera")

	# panel hidden by default, fly camera active
	check(not panel.visible, "panel starts hidden")
	check(fly.enabled, "fly camera is enabled in FLY mode")

	# Q toggles the panel
	await press_action("toggle_panel")
	check(panel.visible, "Q shows the panel")
	await press_action("toggle_panel")
	check(not panel.visible, "Q hides it again")

	# switching to ORBIT disables the fly camera and enables orbit
	main.params.camera_mode = FractalParams.CameraMode.ORBIT
	await frames(1)
	check(not fly.enabled, "fly camera is disabled in ORBIT mode")
	var orbit = main.get_node_or_null("OrbitCamera")
	if orbit != null:
		check(orbit.enabled, "orbit camera is enabled in ORBIT mode")

	# (bug 5a) a left click in FLY mode with the panel open hides it and recaptures
	main.params.camera_mode = FractalParams.CameraMode.FLY
	await frames(1)
	main.panel.visible = true
	main._update_mouse()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(400, 300)
	main._unhandled_input(click)
	check(not main.panel.visible, "a click in fly mode hides the open panel")

	# (bug 5b) changing a non-mode param in orbit mode must not re-run enter()
	main.params.camera_mode = FractalParams.CameraMode.ORBIT
	await frames(1)
	var orbit2 = main.get_node_or_null("OrbitCamera")
	if orbit2 != null:
		orbit2.center = Vector3(9, 9, 9)   # sentinel
		main.params.scale = -3.0           # a non-mode change
		await frames(1)
		check(orbit2.center.is_equal_approx(Vector3(9, 9, 9)),
			"a slider change in orbit mode does not recenter")

	# save and load: the buttons open the panels; the real save path round-trips
	var files: WorkspaceFiles = main.workspace_files()
	check(files != null, "Main owns a WorkspaceFiles")
	check(main.panel.save_button.pressed.is_connected(files.prompt_save), "Save opens the save panel")
	check(main.panel.load_button.pressed.is_connected(files.prompt_load), "Load opens the open panel")
	check_eq(main.panel.file_label.text, "\u2014", "no file is current at startup")

	var tmp := "user://main_test_view.json"
	main.params.camera_mode = FractalParams.CameraMode.FLY
	main.params.fold_limit = 0.72
	main.camera.speed_factor = 2.0
	main.save_view_to(tmp)
	check_eq(files.current_path, tmp, "a save that worked becomes current")
	check_eq(main.panel.file_label.text, "main_test_view.json", "and the panel names it")
	main.params.fold_limit = 0.3
	main.camera.speed_factor = 1.0
	main.load_view_from(tmp)
	check_approx(main.params.fold_limit, 0.72, "loading restores the shape")
	check_approx(main.camera.speed_factor, 2.0, "and the camera")
	check(main.panel.status_label.text.begins_with("Loaded"), "the panel reports the load: %s" % main.panel.status_label.text)
	main.load_view_from("user://no_such_view.json")
	check_eq(files.current_path, tmp, "a failed load does not change the current file")
	check(main.panel.status_label.text.begins_with("Load failed"), "and says it failed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# mouse events reach Main through the real GUI pass: the full-window view
	# must not swallow them (it did, so captured mouse-look never turned the view)
	check_eq(main.view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the view ignores the mouse")
	main.params.camera_mode = FractalParams.CameraMode.ORBIT
	await frames(1)
	var fwd_before: Vector3 = main.camera.forward()
	var at := Vector2(root.size) * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	root.push_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = at + Vector2(5, 0)
	drag.relative = Vector2(5, 0)
	root.push_input(drag)
	var release := press.duplicate()
	release.pressed = false
	root.push_input(release)
	await frames(1)
	check(not main.camera.forward().is_equal_approx(fwd_before), "a drag over the view turns the camera")

	# the sensitivity follows Settings, and a loaded view does not override it
	settings.mouse_sensitivity = 0.33
	check_approx(main.params.mouse_sensitivity, 0.33, "params follow the Settings sensitivity")
	main.panel.sens_slider.value = 0.21
	check_approx(settings.mouse_sensitivity, 0.21, "the panel slider writes Settings")
	main.params.mouse_sensitivity = 0.4
	main.save_view_to(tmp)
	main.params.mouse_sensitivity = 0.21
	main.load_view_from(tmp)
	check_approx(settings.mouse_sensitivity, 0.21, "loading a view keeps the player's sensitivity")
	check_approx(main.params.mouse_sensitivity, 0.21, "in params too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# N opens the noise editor and frees the mouse; a click in Fly mode closes it
	main.params.camera_mode = FractalParams.CameraMode.FLY
	main.panel.visible = false
	main._update_mouse()
	await frames(1)
	var nw = main.noise_window()
	check(nw != null, "Main owns a NoiseWindow")
	check(not nw.visible, "the noise editor starts closed")
	await press_action("toggle_noise_editor")
	check(nw.visible, "N opens the noise editor")
	check_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "opening it frees the mouse")
	var nclick := InputEventMouseButton.new()
	nclick.button_index = MOUSE_BUTTON_LEFT
	nclick.pressed = true
	nclick.position = Vector2(400, 300)
	main._unhandled_input(nclick)
	check(not nw.visible, "a click in Fly mode closes the noise editor")
	await press_action("toggle_noise_editor")
	check(nw.visible, "N opens it again")
	await press_action("toggle_noise_editor")
	check(not nw.visible, "N closes it again")

	# a view save carries the noise graph, and loading restores it
	nw.editor().add_node_requested.emit(&"value_noise", Vector2(200, 200))
	await frames(1)
	var vn := &""
	for id in nw.graph().nodes:
		if nw.graph().node(id).type_id == &"value_noise":
			vn = id
	nw.graph().connect_ports(nw.graph().position_id(), 0, vn, 0)
	nw.graph().connect_ports(vn, 0, nw.graph().output_id(), 0)
	await frames(1)
	var ntmp := "user://main_noise_view.json"
	main.save_view_to(ntmp)
	var ndata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ntmp))
	check(ndata.has("noise"), "a view save embeds the noise graph under a 'noise' key")
	nw.editor().new_requested.emit()
	await frames(1)
	check_eq(nw.graph().nodes.size(), 2, "New reset the graph before the load")
	main.load_view_from(ntmp)
	await frames(1)
	check_eq(nw.graph().nodes.size(), 3, "loading the view restored the noise graph")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ntmp))

	# Escape pauses and opens the pause menu; Escape again resumes
	main.params.camera_mode = FractalParams.CameraMode.FLY
	await frames(1)
	var pause = main.pause_menu()   # untyped: see menus_test.gd
	check(not pause.visible, "the pause menu starts hidden")
	await press_action("pause")
	check(paused and pause.visible, "Escape pauses and opens the pause menu")
	check_eq(pause.menu_button.text, "Back to Menu", "it offers Back to Menu")
	pause.settings_button.pressed.emit()
	check(pause.settings_menu.visible, "and Settings")
	var tabs: TabContainer = pause.settings_menu.tabs
	check(not tabs.is_tab_disabled(1), "in game, the Renderer tab is enabled")
	var dark: float = pause.dim.color.a
	tabs.current_tab = 1
	check(pause.dim.color.a < dark, "the Renderer tab lightens the dim")
	var ro = pause.settings_menu.renderer
	ro.falloff_slider.value = 1.25
	check_approx(main.params.detail_falloff, 1.25, "its falloff slider edits the view's params")
	ro.steps_slider.value = 256
	check_eq(main.params.max_steps, 256, "and its step budget")
	main.params.detail = 3.0
	check_approx(ro.detail_slider.value, 3.0, "and it follows outside changes")
	ro.reset_button.pressed.emit()
	check(main.params.detail == 1.0 and main.params.detail_falloff == 0.0 and main.params.max_steps == 128,
		"Reset puts the renderer defaults back")
	check_eq(main.governor.process_mode, Node.PROCESS_MODE_ALWAYS,
		"the governor keeps running while paused, so edits get a final frame")
	tabs.current_tab = 0
	check_approx(pause.dim.color.a, dark, "back on Controls the dim returns")
	tabs.current_tab = 1
	await press_action("pause")
	check(paused and pause.visible and not pause.settings_menu.visible,
		"Escape in its settings goes back to the pause list")
	await press_action("pause")
	check(not paused and not pause.visible, "Escape again resumes")
	await press_action("pause")
	pause.resume_button.pressed.emit()
	check(not paused and not pause.visible, "so does Resume")

	# Back to Menu unpauses and swaps to the main menu
	await press_action("pause")
	pause.menu_button.pressed.emit()
	await frames(2)
	check(not paused, "Back to Menu unpauses")
	check(current_scene != null and current_scene.name == "MainMenu", "and loads the main menu")
	if current_scene:
		current_scene.queue_free()

	main.queue_free()
	await frames(1)
	settings.mouse_sensitivity = original_sens
	await frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://main_test_settings.cfg"))
