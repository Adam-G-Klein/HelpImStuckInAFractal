extends "res://tests/test_case.gd"
## NoiseWindow: owns the graph, wires the editor to it and to the view, toggles
## open/closed, and saves/loads graph-only JSON in saves/noise/.

const TMP := "user://noise_window_test.json"


func run() -> void:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var view: FractalView = load("res://src/fractal/fractal_view.tscn").instantiate()
	root.add_child(view)
	await frames(1)
	view.setup(params, cam)
	await frames(1)

	var window := NoiseWindow.new()
	root.add_child(window)
	window.setup(view)
	await frames(2)

	# --- it starts closed, with the default graph wired to the view ---
	check(not window.visible, "the window starts hidden")
	var graph := window.graph()
	check(graph != null, "the window owns a graph")
	check_eq(graph.nodes.size(), 2, "the default graph is Position and Output")
	check(view.noise_graph() == graph, "the view was handed the same graph")
	check(window.editor() != null and not window.editor().is_empty(), "the editor shows it")

	# --- open and close ---
	check_eq(window.size, UiScale.px(NoiseWindow.DEFAULT_SIZE, window), "the window is sized by UiScale")
	check_approx(window.content_scale_factor, UiScale.factor_for(window), "and takes its content scale")
	window.open()
	check(window.visible, "open() shows it")
	check(window.position.y >= 0, "it opens inside the main window, title bar reachable")
	window.close()
	check(not window.visible, "close() hides it")
	window.toggle()
	check(window.visible, "toggle() shows it")
	window.toggle()
	check(not window.visible, "toggle() hides it")

	# --- an add request from the editor adds the node ---
	var before := graph.nodes.size()
	window.editor().add_node_requested.emit(&"value_noise", Vector2(200, 200))
	await frames(1)
	check_eq(graph.nodes.size(), before + 1, "an editor add request adds the node to the graph")

	# --- wiring it changes the view's shader (the graph drives the view live) ---
	var vn := &""
	for id in graph.nodes:
		if graph.node(id).type_id == &"value_noise":
			vn = id
	graph.connect_ports(graph.position_id(), 0, vn, 0)
	graph.connect_ports(vn, 0, graph.output_id(), 0)
	await frames(1)
	var names: Array = []
	for u in view.shader_uniform_names():
		names.append(String(u))
	check(names.has("n_%s_scale" % vn), "wiring in the window reaches the view's shader")

	# --- save to a graph-only file and read it back ---
	window.workspace_files().save_dialog().file_selected.emit(ProjectSettings.globalize_path(TMP))
	await frames(1)
	check(FileAccess.file_exists(TMP), "Save… writes a graph-only JSON file")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TMP))
	check_eq(int(data["version"]), Workspace.VERSION, "the file carries the workspace version")
	check(data.has("noise") and data["noise"].has("nodes"), "…and a noise section with the graph")

	# --- New resets to the default, then Load restores the saved graph ---
	window.editor().new_requested.emit()
	await frames(1)
	check_eq(window.graph().nodes.size(), 2, "New resets to the default graph")
	window.workspace_files().load_dialog().file_selected.emit(ProjectSettings.globalize_path(TMP))
	await frames(1)
	check_eq(window.graph().nodes.size(), 3, "Load restores the saved graph")
	check(view.noise_graph() == window.graph(), "…and the view follows the new graph object")

	# --- apply_dict / to_dict round trip (used by a view save) ---
	var dict := window.to_dict()
	check(dict.has("nodes") and dict.has("links"), "to_dict gives the graph dict for a view save")
	window.editor().new_requested.emit()
	await frames(1)
	var warnings := window.apply_dict(dict)
	await frames(1)
	check_eq(warnings.size(), 0, "apply_dict restores with no warnings")
	check_eq(window.graph().nodes.size(), 3, "…and the graph is back")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	window.queue_free()
	view.queue_free()
	await frames(1)
